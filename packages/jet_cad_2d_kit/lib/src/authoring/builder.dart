// The library builder (spec K6): a catalog in, a library document out, one
// definition per symbol named key@version, in one compound command. Ported
// from jet_cad_floor_plan's build_library.dart.
//
// The document is DraftDocument.empty, the kit components and millimetre
// units, nothing else (not prepareDocument: its DASHED linetype is not in
// K3's list).
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../model/library_component.dart';
import '../model/register.dart';
import '../model/symbol_component.dart';
import '../model/symbol_library.dart';
import '../model/unit_component.dart';
import 'catalog.dart';

/// The library document of [catalog]. Deterministic: handles ascend in
/// catalog order (a definition, its leaves, the next definition). Every leaf
/// is on layer 0 with BYBLOCK linetype, colour, lineweight and transparency
/// and no flag (K3 rule 14). The caller disposes the document.
///
/// Throws a component's [ArgumentError] for a value spec K2 refuses, and
/// whatever a shape's payload throws (the document is then disposed).
DraftDocument buildLibraryDocument(Catalog catalog) {
  // Every component is constructed, and so validated, before the document
  // exists: a value K2 refuses throws here and leaves nothing to dispose.
  final library = LibraryComponent(kit: catalog.kit);
  final symbols = [
    for (final s in catalog.symbols)
      SymbolComponent(
        key: s.key,
        version: s.version,
        name: s.name,
        category: s.category,
        tags: s.tags,
        attachTo: s.attachTo,
        family: s.family,
      ),
  ];
  final units = [
    for (final s in catalog.symbols)
      if (s.unit case final unit?)
        UnitComponent(
            kind: unit.kind, capacity: unit.capacity, labelling: unit.labelling)
      else
        null,
  ];
  final doc = DraftDocument.empty();
  // A payload can still throw once the document exists (an empty closed
  // polyline has no first point): the document is disposed, the error
  // goes on.
  try {
    registerKitComponents(doc.components);
    doc.header.units = DrawingUnits.millimeters;
    final commands = <DraftCommand>[
      SetComponentCommand<LibraryComponent>(doc.rootHandle, library),
    ];
    for (var i = 0; i < catalog.symbols.length; i++) {
      final s = catalog.symbols[i];
      final def = doc.handleSeed.next();
      commands
        ..add(AddDefinitionCommand(Definition(
          handle: def,
          name: s.id,
          basePoint: Vector2(s.base.$1, s.base.$2),
          children: const [],
        )))
        ..add(SetComponentCommand<SymbolComponent>(def, symbols[i]));
      final unit = units[i];
      if (unit != null) {
        commands.add(SetComponentCommand<UnitComponent>(def, unit));
      }
      for (final shape in s.shapes) {
        commands.add(AddEntityCommand(
          record: EntityRecord(
            handle: doc.handleSeed.next(),
            owner: def,
            kind: _kindOf(shape),
            layer: ReservedHandles.layerZero,
            linetype: ReservedHandles.byBlockLinetype,
            linetypeScale: 1.0,
            geomIndex: 0,
            color: const ByBlockColor(),
            lineweight: kByBlock,
            transparency: kByBlock,
            flags: 0,
          ),
          payload: _payloadOf(shape),
        ));
      }
    }
    doc.commands.execute(CompoundCommand(commands, label: 'Symbol library'));
    doc.commands.clearHistory();
    return doc;
  } catch (_) {
    unawaited(doc.dispose());
    rethrow;
  }
}

/// The `.jetlib` bytes of [catalog]: the codec's JSON of
/// [buildLibraryDocument], UTF-8. The same catalog gives the same bytes.
///
/// Decodes its own output: throws the [SymbolLibraryError] of a catalog the
/// format refuses, so a generator never writes such a library.
Uint8List encodeLibrary(Catalog catalog) {
  final doc = buildLibraryDocument(catalog);
  try {
    final bytes =
        Uint8List.fromList(utf8.encode(DraftDocumentCodec.encodeToString(doc)));
    SymbolLibrary.decode(bytes);
    return bytes;
  } finally {
    unawaited(doc.dispose());
  }
}

EntityKind _kindOf(CatalogShape shape) => switch (shape) {
      CatalogLine() => EntityKind.line,
      CatalogPolyline() => EntityKind.polyline,
      CatalogCircle() => EntityKind.circle,
      CatalogArc() => EntityKind.arc,
    };

Vector2 _v(CatalogPoint p) => Vector2(p.$1, p.$2);

GeometryPayload _payloadOf(CatalogShape shape) => switch (shape) {
      CatalogLine(:final from, :final to) => linePayload(_v(from), _v(to)),
      CatalogPolyline(:final points, :final closed) =>
        polylinePayload([for (final p in points) _v(p)], closed: closed),
      CatalogCircle(:final center, :final radius) =>
        circlePayload(_v(center), radius),
      CatalogArc(:final center, :final radius, :final start, :final sweep) =>
        arcPayload(_v(center), radius, start, sweep),
    };
