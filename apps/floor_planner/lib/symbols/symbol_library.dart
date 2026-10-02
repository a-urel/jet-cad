// The symbol library's loader (spec 09 D5): bytes in, typed and validated
// entries out. A decoded library is **not** trusted: every rule below is
// checked here, none is left to the tree or the codec to reject.
//
// No Flutter import and no `dart:io`: this file is Dart over
// `package:jet_cad_2d` only.
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../parametric/catalog.dart';
import 'symbol_component.dart';

/// The tag a symbol stands against a wall by (spec 09c D2): it attaches to a
/// wall's face when placed near one.
const String againstWallTag = 'against-wall';

/// The prefix of a symbol's size-family tag, `family:<id>` (spec 09c D2,
/// D9). A symbol carries one at most (R03d).
const String familyTagPrefix = 'family:';

/// A library the loader refuses. The message names the offending key or
/// handle and the rule it broke.
class SymbolLibraryError implements Exception {
  final String message;
  const SymbolLibraryError(this.message);

  @override
  String toString() => 'SymbolLibraryError: $message';
}

/// One symbol of a library: its identity (the [SymbolComponent] fields), its
/// [definition] and a snapshot of its [leaves], **ascending by handle** so
/// draw order is preserved when a placement copies them (spec D6).
///
/// The leaves' records keep the library document's handles and `geomIndex`;
/// a placement gives every one of them fresh values.
final class SymbolEntry {
  final String key;
  final String name;
  final String category;
  final List<String> tags;
  final int version;
  final Definition definition;
  final List<({EntityRecord record, GeometryPayload payload})> leaves;

  SymbolEntry({
    required this.key,
    required this.name,
    required this.category,
    required List<String> tags,
    required this.version,
    required this.definition,
    required List<({EntityRecord record, GeometryPayload payload})> leaves,
  })  : tags = List.unmodifiable(tags),
        leaves = List.unmodifiable(leaves);

  @override
  String toString() => 'SymbolEntry($key@$version, ${leaves.length} leaves)';
}

/// A validated set of [SymbolEntry]s, in definition-handle order.
final class SymbolLibrary {
  /// A coordinate beyond this (mm) is refused: no furniture is a kilometre
  /// wide, and a huge coordinate poisons every bound computed from it.
  static const double maxCoordinate = 1e6;

  final List<SymbolEntry> entries;

  SymbolLibrary._(List<SymbolEntry> entries)
      : entries = List.unmodifiable(entries);

  /// Category names in first-appearance order over [entries].
  List<String> get categories {
    final seen = <String>{};
    return [
      for (final e in entries)
        if (seen.add(e.category)) e.category,
    ];
  }

  /// Decodes [bytes] (UTF-8 of the codec's JSON) and validates the result.
  /// Throws [SymbolLibraryError] on anything the spec's D5 names, on a
  /// document the codec itself repaired (a definition cycle it dropped an
  /// instance for) and on bytes the codec cannot read at all.
  static SymbolLibrary decode(Uint8List bytes) {
    final diagnostics = <Diagnostic>[];
    final DraftDocument doc;
    try {
      doc = DraftDocumentCodec.decodeString(
        utf8.decode(bytes),
        diagnostics: diagnostics,
        registerComponents: registerAppComponents,
      );
    } catch (e) {
      // FormatException, SchemaVersionError, a TypeError from a mistyped
      // field, a DuplicateHandleError: all mean "not a readable library".
      throw SymbolLibraryError('not a readable library: $e');
    }
    return SymbolLibrary._(_validate(doc, diagnostics));
  }

  static List<SymbolEntry> _validate(
      DraftDocument doc, List<Diagnostic> diagnostics) {
    // The codec repairs a definition cycle by dropping the instance that
    // closes it, so a nested instance of that kind never reaches the node
    // check below; its report is the only trace. Any repair is a refusal.
    if (diagnostics.isNotEmpty) {
      throw SymbolLibraryError(
          'the codec repaired the library: ${diagnostics.first.message}');
    }

    // Nodes: the root only. An instance or a group is a nesting a v1
    // definition does not have.
    for (final node in doc.tree.nodes) {
      if (node.handle == doc.rootHandle) continue;
      switch (node) {
        case InstanceNode():
          throw SymbolLibraryError(
              'instance ${node.handle.toHex()} in the library: a symbol '
              'holds leaves only');
        case GroupNode():
          throw SymbolLibraryError('group ${node.handle.toHex()} in the '
              'library: a symbol holds leaves only');
      }
    }

    // Definitions, ascending by handle.
    final byHandle = <Handle, SymbolEntry>{};
    final leavesOf =
        <Handle, List<({EntityRecord record, GeometryPayload payload})>>{};
    final seenKeys = <String>{};
    final drafts = <(Definition, SymbolComponent)>[];
    for (final definition in doc.tree.definitions) {
      final at = 'definition ${definition.handle.toHex()}';
      final component = doc.components.get<SymbolComponent>(definition.handle);
      if (component == null) {
        throw SymbolLibraryError('$at has no symbol component');
      }
      final who = '$at (${component.key}@${component.version})';
      if (!seenKeys.add('${component.key}@${component.version}')) {
        throw SymbolLibraryError(
            '$who repeats the key and version of an earlier definition');
      }
      if (component.key != component.key.toLowerCase() ||
          component.key.contains(RegExp(r'\s'))) {
        throw SymbolLibraryError(
            '$who: the key must be lower-case without white space');
      }
      for (final tag in component.tags) {
        if (tag != tag.toLowerCase()) {
          throw SymbolLibraryError('$who: the tag "$tag" is not lower-case');
        }
      }
      // R03d (spec 09c D2): a symbol is in one size family at most.
      final families = [
        for (final tag in component.tags)
          if (tag.startsWith(familyTagPrefix)) tag,
      ];
      if (families.length > 1) {
        throw SymbolLibraryError('$who has ${families.length} family tags '
            '(${families.map((t) => '"$t"').join(', ')}): a symbol is in one '
            'size family at most');
      }
      if (definition.children.isNotEmpty) {
        throw SymbolLibraryError('$who lists children '
            '(${definition.children.map((h) => h.toHex()).join(', ')}): a '
            'symbol\'s leaves are found by owner and its children stay empty');
      }
      if (!definition.basePoint.x.isFinite ||
          !definition.basePoint.y.isFinite) {
        throw SymbolLibraryError('$who has a non-finite base point');
      }
      drafts.add((definition, component));
      leavesOf[definition.handle] = [];
    }

    // Leaves.
    final entities = doc.entities;
    for (final slot in entities.liveSlots) {
      final record = entities.read(slot);
      final at = 'leaf ${record.handle.toHex()}';
      final owned = leavesOf[record.owner];
      if (owned == null) {
        throw SymbolLibraryError(
            '$at is owned by ${record.owner.toHex()}, which is not a '
            'definition');
      }
      final who = '$at of ${record.owner.toHex()}';
      switch (record.kind) {
        case EntityKind.text:
        case EntityKind.fill:
        case EntityKind.attrib:
          throw SymbolLibraryError(
              '$who is a ${record.kind.name}: a symbol holds no text, fill '
              'or attribute');
        case EntityKind.point:
          throw SymbolLibraryError('$who is a point: not allowed in a symbol');
        case EntityKind.line:
        case EntityKind.polyline:
        case EntityKind.circle:
        case EntityKind.arc:
          break;
      }
      _checkStyle(record, who);
      final payload = doc.geometry.read(entities.geomIndexAt(slot));
      _checkGeometry(record.kind, payload, who);
      owned.add((record: record, payload: payload));
    }

    for (final (definition, component) in drafts) {
      final leaves = leavesOf[definition.handle]!
        ..sort(
            (a, b) => a.record.handle.value.compareTo(b.record.handle.value));
      byHandle[definition.handle] = SymbolEntry(
        key: component.key,
        name: component.name,
        category: component.category,
        tags: component.tags,
        version: component.version,
        definition: definition,
        leaves: leaves,
      );
    }
    return byHandle.values.toList();
  }

  /// The allow-list of spec D5 / F-14: reserved handles only, inherited
  /// colour, weight and transparency, no flag.
  static void _checkStyle(EntityRecord r, String who) {
    if (r.layer != ReservedHandles.layerZero) {
      throw SymbolLibraryError('$who is on layer ${r.layer.toHex()}, not '
          'layer 0');
    }
    if (r.linetype != ReservedHandles.byLayerLinetype &&
        r.linetype != ReservedHandles.byBlockLinetype &&
        r.linetype != ReservedHandles.continuousLinetype) {
      throw SymbolLibraryError('$who has linetype ${r.linetype.toHex()}, not '
          'BYLAYER, BYBLOCK or CONTINUOUS');
    }
    if (r.textStyle != ReservedHandles.standardTextStyle) {
      throw SymbolLibraryError(
          '$who has text style ${r.textStyle.toHex()}, not STANDARD');
    }
    if (r.color is! ByBlockColor && r.color is! ByLayerColor) {
      throw SymbolLibraryError('$who has a concrete colour, not BYBLOCK or '
          'BYLAYER');
    }
    if (r.lineweight != kByBlock && r.lineweight != kByLayer) {
      throw SymbolLibraryError('$who has lineweight ${r.lineweight}, not '
          'BYBLOCK or BYLAYER');
    }
    if (r.transparency != kByBlock && r.transparency != kByLayer) {
      throw SymbolLibraryError('$who has transparency ${r.transparency}, not '
          'BYBLOCK or BYLAYER');
    }
    if (r.flags != 0) {
      throw SymbolLibraryError('$who has flags ${r.flags} (invisible or '
          'unpickable): a symbol is drawn and picked');
    }
    if (!r.linetypeScale.isFinite) {
      throw SymbolLibraryError('$who has a non-finite linetype scale');
    }
  }

  static void _checkGeometry(EntityKind kind, GeometryPayload p, String who) {
    final (int? coords, int scalars) = switch (kind) {
      EntityKind.line => (4, 0),
      EntityKind.circle => (2, 1),
      EntityKind.arc => (2, 3),
      _ => (null, 0), // a polyline: any even count of coordinates, no scalars
    };
    if (p.coords.length.isOdd ||
        (coords != null && p.coords.length != coords) ||
        p.scalars.length != scalars) {
      throw SymbolLibraryError('$who has a malformed ${kind.name} payload '
          '(${p.coords.length} coordinates, ${p.scalars.length} scalars)');
    }
    for (final c in p.coords) {
      if (!c.isFinite || c.abs() > maxCoordinate) {
        throw SymbolLibraryError('$who has a coordinate ($c) that is not '
            'finite or is beyond ±${maxCoordinate.toInt()}');
      }
    }
    for (final s in p.scalars) {
      if (!s.isFinite) {
        throw SymbolLibraryError('$who has a non-finite scalar');
      }
    }
    switch (kind) {
      case EntityKind.line:
        if (isDegenerateSegment(p.pointAt(0), p.pointAt(1))) {
          throw SymbolLibraryError('$who is a zero-length line');
        }
      case EntityKind.polyline:
        if (p.pointCount < 2) {
          throw SymbolLibraryError('$who is a polyline of ${p.pointCount} '
              'vertices');
        }
      case EntityKind.circle:
        if (p.scalars[0] <= Tolerance.standard.linear) {
          throw SymbolLibraryError('$who has radius ${p.scalars[0]}');
        }
      case EntityKind.arc:
        if (p.scalars[0] <= Tolerance.standard.linear) {
          throw SymbolLibraryError('$who has radius ${p.scalars[0]}');
        }
        if (p.scalars[2].abs() <= Tolerance.standard.angular) {
          throw SymbolLibraryError('$who has a zero sweep');
        }
      default:
        break;
    }
  }
}
