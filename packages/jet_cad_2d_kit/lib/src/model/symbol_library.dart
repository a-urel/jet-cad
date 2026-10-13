// The library format (spec K3): bytes in, typed and validated entries out.
// A decoded library is not trusted: every rule is checked here, none is left
// to the tree or the codec. Ported from jet_cad_floor_plan's
// symbol_library.dart, with the contract's components and K3's fifteen
// rules, each refusal carrying its rule number.
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'kit_ids.dart';
import 'library_component.dart';
import 'register.dart';
import 'symbol_component.dart';
import 'unit_component.dart';

/// A leaf of a symbol: its record (the library's handles and `geomIndex`)
/// and its geometry.
typedef SymbolLeaf = ({EntityRecord record, GeometryPayload payload});

/// A library the decoder refuses: [rule] is the spec's K3 rule (1-15),
/// [message] names the offending key or handle.
final class SymbolLibraryError implements Exception {
  const SymbolLibraryError(this.rule, this.message);

  final int rule;
  final String message;

  @override
  String toString() => 'SymbolLibraryError (rule $rule): $message';
}

/// One symbol of a library: its identity, its unit or null, its definition
/// and its leaves, ascending by handle (draw order).
final class SymbolEntry {
  SymbolEntry({
    required this.symbol,
    required this.unit,
    required this.definition,
    required List<SymbolLeaf> leaves,
  }) : leaves = List.unmodifiable(leaves);

  final SymbolComponent symbol;
  final UnitComponent? unit;
  final Definition definition;
  final List<SymbolLeaf> leaves;

  /// `key@version`.
  String get id => symbol.id;

  @override
  String toString() => 'SymbolEntry($id, ${leaves.length} leaves)';
}

/// A validated library: its kit and its entries in definition-handle order.
final class SymbolLibrary {
  SymbolLibrary._(List<String> kits, List<SymbolEntry> entries)
      : kits = List.unmodifiable(kits),
        entries = List.unmodifiable(entries);

  /// A coordinate beyond this (mm) is refused: no symbol is a kilometre
  /// wide, and a huge coordinate poisons every bound computed from it.
  static const double maxCoordinate = 1e6;

  /// The library format this build reads.
  static const int format = 1;

  /// The kits whose symbols this holds: one for a decoded library, several
  /// for a merged one, in first-appearance order.
  final List<String> kits;

  final List<SymbolEntry> entries;

  /// Category names in first-appearance order over [entries].
  List<String> get categories {
    final seen = <String>{};
    return [
      for (final e in entries)
        if (seen.add(e.symbol.category)) e.symbol.category,
    ];
  }

  /// Decodes [bytes] (UTF-8 of the codec's JSON), registering only the kit
  /// components, and validates the result. Throws [SymbolLibraryError] on
  /// every fault of spec K3; nothing else escapes.
  static SymbolLibrary decode(Uint8List bytes) {
    final diagnostics = <Diagnostic>[];
    final DraftDocument doc;
    try {
      doc = DraftDocumentCodec.decodeString(
        utf8.decode(bytes),
        diagnostics: diagnostics,
        registerComponents: (registry) =>
            registerKitComponentsWrapped(registry, _guarded),
      );
    } on SymbolLibraryError {
      rethrow;
    } catch (e) {
      // FormatException, SchemaVersionError, a TypeError from a mistyped
      // field, a DuplicateHandleError: all mean "not a readable library".
      throw SymbolLibraryError(1, 'not a readable library: $e');
    }
    try {
      return _validate(doc, diagnostics);
    } finally {
      unawaited(doc.dispose());
    }
  }

  /// Reads a component, turning its constructor's refusal into the K3 rule
  /// the field belongs to.
  static T _guarded<T extends Component>(String typeId,
      Map<String, Object?> json, T Function(Map<String, Object?> json) read) {
    final named = switch (json['key'] ?? json['kit']) {
      final String s => '"$s"',
      _ => '',
    };
    try {
      return read(json);
    } on ArgumentError catch (e) {
      throw SymbolLibraryError(_ruleOf(typeId, e.name), '$typeId $named: $e');
    } on FormatException catch (e) {
      final rule = typeId == LibraryComponent.componentTypeId ? 2 : 1;
      throw SymbolLibraryError(rule, '$typeId $named: ${e.message}');
    }
  }

  static int _ruleOf(String typeId, String? field) => switch ((typeId, field)) {
        (LibraryComponent.componentTypeId, _) => 2,
        (SymbolComponent.componentTypeId, 'key') => 5,
        (SymbolComponent.componentTypeId, 'tags' || 'attachTo' || 'family') =>
          8,
        (UnitComponent.componentTypeId, 'kind') => 8,
        _ => 1,
      };

  static SymbolLibrary _validate(
      DraftDocument doc, List<Diagnostic> diagnostics) {
    // Rule 1: the codec repairs a definition cycle by dropping the instance
    // that closes it; its report is the only trace. Any repair is a refusal.
    if (diagnostics.isNotEmpty) {
      throw SymbolLibraryError(
          1, 'the codec repaired the library: ${diagnostics.first.message}');
    }

    // Rule 2: the root's library component, the format, the units.
    if (doc.header.units != DrawingUnits.millimeters) {
      throw SymbolLibraryError(
          2, 'the library is in ${doc.header.units.name}, not in millimeters');
    }
    final library = doc.components.get<LibraryComponent>(doc.rootHandle);
    if (library == null) {
      throw const SymbolLibraryError(
          2, 'the root carries no library component');
    }
    if (library.format != format) {
      throw SymbolLibraryError(2,
          'the library is of format ${library.format}; this build reads $format');
    }
    for (final h in doc.components.withComponent<LibraryComponent>()) {
      if (h != doc.rootHandle) {
        throw SymbolLibraryError(
            2, 'a library component on ${h.toHex()}, which is not the root');
      }
    }

    // Rule 3: the root is the only node.
    for (final node in doc.tree.nodes) {
      if (node.handle == doc.rootHandle) continue;
      final what = switch (node) {
        InstanceNode() => 'instance',
        GroupNode() => 'group',
      };
      throw SymbolLibraryError(3,
          '$what ${node.handle.toHex()} in the library: it holds definitions only');
    }

    // Rules 4-9 and 12: definitions, ascending by handle.
    final leavesOf = <Handle, List<SymbolLeaf>>{};
    final seen = <String>{};
    final drafts = <(Definition, SymbolComponent, UnitComponent?)>[];
    for (final definition in doc.tree.definitions) {
      final at = 'definition ${definition.handle.toHex()}';
      final symbol = doc.components.get<SymbolComponent>(definition.handle);
      if (symbol == null) {
        throw SymbolLibraryError(4, '$at has no symbol component');
      }
      final who = '$at (${symbol.id})';
      if (definition.isXref) {
        throw SymbolLibraryError(4, '$who is an external reference');
      }
      if (definition.children.isNotEmpty) {
        throw SymbolLibraryError(
            4,
            '$who lists children '
            '(${definition.children.map((h) => h.toHex()).join(', ')}): a '
            "symbol's leaves are found by owner");
      }
      if (kitOfKey(symbol.key) != library.kit) {
        throw SymbolLibraryError(
            5, '$who is not under the library\'s kit "${library.kit}"');
      }
      if (!seen.add(symbol.id)) {
        throw SymbolLibraryError(
            6, '$who repeats the key and version of an earlier definition');
      }
      if (definition.name != symbol.id) {
        throw SymbolLibraryError(
            7, '$who is named "${definition.name}", not "${symbol.id}"');
      }
      final unit = doc.components.get<UnitComponent>(definition.handle);
      if (unit != null && symbol.family != null) {
        throw SymbolLibraryError(9,
            '$who is a unit in the size family "${symbol.family}": a unit is in no family');
      }
      final base = definition.basePoint;
      if (!base.x.isFinite || !base.y.isFinite) {
        throw SymbolLibraryError(12, '$who has a non-finite base point');
      }
      drafts.add((definition, symbol, unit));
      leavesOf[definition.handle] = [];
    }

    // Rules 4 and 10: a symbol or a unit component off a definition.
    for (final h in doc.components.withComponent<SymbolComponent>()) {
      if (!leavesOf.containsKey(h)) {
        throw SymbolLibraryError(
            4, 'a symbol component on ${h.toHex()}, which is not a definition');
      }
    }
    for (final h in doc.components.withComponent<UnitComponent>()) {
      if (!leavesOf.containsKey(h)) {
        throw SymbolLibraryError(10,
            "a unit component on ${h.toHex()}, which is not a symbol's definition");
      }
    }

    // Rules 13-15: leaves.
    final entities = doc.entities;
    for (final slot in entities.liveSlots) {
      final record = entities.read(slot);
      final at = 'leaf ${record.handle.toHex()}';
      final owned = leavesOf[record.owner];
      if (owned == null) {
        throw SymbolLibraryError(13,
            '$at is owned by ${record.owner.toHex()}, which is not a definition');
      }
      final who = '$at of ${record.owner.toHex()}';
      switch (record.kind) {
        case EntityKind.line:
        case EntityKind.polyline:
        case EntityKind.circle:
        case EntityKind.arc:
          break;
        case EntityKind.point:
        case EntityKind.text:
        case EntityKind.attrib:
        case EntityKind.fill:
          throw SymbolLibraryError(
              13,
              '$who is a ${record.kind.name}: a symbol holds lines, '
              'polylines, circles and arcs only');
      }
      _checkStyle(record, who);
      final payload = doc.geometry.read(entities.geomIndexAt(slot));
      _checkGeometry(record.kind, payload, who);
      owned.add((record: record, payload: payload));
    }

    // Rules 4 and 11, per definition: at least one leaf, a unit's outline.
    final entries = <SymbolEntry>[];
    for (final (definition, symbol, unit) in drafts) {
      final who = 'definition ${definition.handle.toHex()} (${symbol.id})';
      final leaves = leavesOf[definition.handle]!
        ..sort(
            (a, b) => a.record.handle.value.compareTo(b.record.handle.value));
      if (leaves.isEmpty) {
        throw SymbolLibraryError(4, '$who has no leaf');
      }
      if (unit != null) {
        final first = leaves.first;
        final closed = first.record.kind == EntityKind.circle ||
            (first.record.kind == EntityKind.polyline &&
                isClosedPolyline(first.payload));
        if (!closed) {
          throw SymbolLibraryError(
              11,
              '$who is a unit whose first leaf, '
              '${first.record.handle.toHex()}, is not a closed polyline or a '
              'circle');
        }
      }
      entries.add(SymbolEntry(
          symbol: symbol, unit: unit, definition: definition, leaves: leaves));
    }
    return SymbolLibrary._([library.kit], entries);
  }

  /// Rule 14: exactly the style the builder writes.
  static void _checkStyle(EntityRecord r, String who) {
    Never refuse(String what) => throw SymbolLibraryError(14, '$who $what');
    if (r.layer != ReservedHandles.layerZero) {
      refuse('is on layer ${r.layer.toHex()}, not layer 0');
    }
    if (r.linetype != ReservedHandles.byBlockLinetype) {
      refuse('has linetype ${r.linetype.toHex()}, not BYBLOCK');
    }
    if (r.linetypeScale != 1.0) {
      refuse('has linetype scale ${r.linetypeScale}, not 1');
    }
    if (r.color is! ByBlockColor) {
      refuse('has a colour other than BYBLOCK');
    }
    if (r.lineweight != kByBlock) {
      refuse('has lineweight ${r.lineweight}, not BYBLOCK');
    }
    if (r.transparency != kByBlock) {
      refuse('has transparency ${r.transparency}, not BYBLOCK');
    }
    if (r.flags != 0) {
      refuse('has flags ${r.flags}: a symbol is drawn and picked');
    }
    if (r.textStyle != ReservedHandles.standardTextStyle) {
      refuse('has text style ${r.textStyle.toHex()}, not STANDARD');
    }
    if (r.text.isNotEmpty) refuse('carries text');
    if (r.tag.isNotEmpty) refuse('carries a tag');
    if (r.textAttrs != 0) refuse('has text attributes ${r.textAttrs}');
  }

  /// Rule 15: counts, finiteness, bounds, degeneracy against [Tolerance].
  static void _checkGeometry(EntityKind kind, GeometryPayload p, String who) {
    final (int? coords, int scalars) = switch (kind) {
      EntityKind.line => (4, 0),
      EntityKind.circle => (2, 1),
      EntityKind.arc => (2, 3),
      _ => (null, 0), // a polyline: any even count, no scalar
    };
    if (p.coords.length.isOdd ||
        (coords != null && p.coords.length != coords) ||
        p.scalars.length != scalars) {
      throw SymbolLibraryError(
          15,
          '$who has a malformed ${kind.name} payload '
          '(${p.coords.length} coordinates, ${p.scalars.length} scalars)');
    }
    for (final c in p.coords) {
      if (!c.isFinite || c.abs() > maxCoordinate) {
        throw SymbolLibraryError(
            15,
            '$who has a coordinate ($c) that is not finite or is beyond '
            '±${maxCoordinate.toInt()}');
      }
    }
    for (final s in p.scalars) {
      if (!s.isFinite) {
        throw SymbolLibraryError(15, '$who has a non-finite scalar');
      }
    }
    switch (kind) {
      case EntityKind.line:
        if (isDegenerateSegment(p.pointAt(0), p.pointAt(1))) {
          throw SymbolLibraryError(15, '$who is a zero-length line');
        }
      case EntityKind.polyline:
        if (p.pointCount < 2) {
          throw SymbolLibraryError(
              15, '$who is a polyline of ${p.pointCount} vertices');
        }
      case EntityKind.circle:
      case EntityKind.arc:
        if (p.scalars[0] <= Tolerance.standard.linear) {
          throw SymbolLibraryError(15, '$who has radius ${p.scalars[0]}');
        }
        if (kind == EntityKind.arc &&
            p.scalars[2].abs() <= Tolerance.standard.angular) {
          throw SymbolLibraryError(15, '$who has a zero sweep');
        }
      default:
        break;
    }
  }
}
