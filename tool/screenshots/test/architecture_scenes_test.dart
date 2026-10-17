// The architecture kit's scenes (package READMEs spec D5, umbrella A11): the
// kit's sample flat, and one drawing of each of its parametric types, on the
// renderer's own DraftCanvas (the kit depends on the renderer, never on the
// plan library). Written to
// jet_cad_2d_kit_architecture/doc/screenshots/ under UPDATE_SCREENSHOTS=1.
import 'dart:ui' show Locale;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show KitNamesWords, KitWords, registerKitComponents;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

import 'support/draft_stage.dart';
import 'support/shots.dart';

const _package = 'jet_cad_2d_kit_architecture';

/// A document over the kit's own engine catalog and parametric system,
/// exactly as the kit's own sample test builds one: the kit's components
/// registered, its `prepare` (the DASHED record) run, the system installed,
/// then [build] filled in the kit's English words.
DraftDocument _document(void Function(DraftDocument, KitWords) build) {
  final catalog = ParametricCatalog();
  for (final type in architectureKit.types) {
    type.registerInto(catalog);
  }
  final measurer = FlutterTextMeasurer();
  final doc = DraftDocument.empty(measurer: measurer);
  PageComponent.register(doc.components);
  registerKitComponents(doc.components);
  catalog.registerComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  architectureKit.prepare!(doc);
  final system = ParametricSystem(doc, catalog)..install();
  build(doc, KitNamesWords(architectureKit.names, () => const Locale('en')));
  doc.commands.clearHistory();
  addTearDown(() async {
    system.dispose();
    await doc.dispose();
    measurer.clear();
  });
  return doc;
}

/// One of each type the kit gives (spec 3a C3.1-C3.7): walls enclosing a
/// room, a door, a window and a gap in them, a separator splitting it into
/// two named rooms, a dimension below, and two overlapping boxes -- whose
/// outlines lose what lies strictly inside one another (C3.1).
void _types(DraftDocument doc, KitWords words) {
  final p = _Pen(doc);
  final south = p.wall(0, 0, 6000, 0, 250);
  final east = p.wall(6000, 0, 6000, 5000, 250);
  final north = p.wall(6000, 5000, 0, 5000, 250);
  p.wall(0, 5000, 0, 0, 250);
  p.opening(OpeningParams(south, 1500, 900, OpeningKind.door));
  p.opening(OpeningParams(north, 3000, 1200, OpeningKind.window));
  p.opening(OpeningParams(east, 2500, 1200, OpeningKind.gap));
  p.separator(0, 2500, 6000, 2500);
  p.room(1500, 1250, 'Room A');
  p.room(3000, 3750, 'Room B');
  p.dimension(AttachedEnd(south, 0, WallSide.right),
      AttachedEnd(south, 1, WallSide.right), DimKind.horizontal, -1200);
  p.box(8000, 800, 2000, 2000);
  p.box(9000, 1800, 2000, 2000);
}

/// Adds the kit's parametric objects, each in its own root-level group at
/// the identity (a box, the one exception, at its lower-left corner), as the
/// kit's own tools add them.
class _Pen {
  _Pen(this.doc);

  final DraftDocument doc;

  Handle _group(Component c, String label) {
    final h = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [])),
      switch (c) {
        final WallParams w => SetComponentCommand<WallParams>(h, w),
        final OpeningParams o => SetComponentCommand<OpeningParams>(h, o),
        final SeparatorParams s => SetComponentCommand<SeparatorParams>(h, s),
        final RoomParams r => SetComponentCommand<RoomParams>(h, r),
        final DimensionParams d => SetComponentCommand<DimensionParams>(h, d),
        _ => throw ArgumentError.value(c),
      },
    ], label: label));
    return h;
  }

  Handle wall(double sx, double sy, double ex, double ey, double t) =>
      _group(WallParams(sx, sy, ex, ey, t, Justification.centre), 'Add wall');

  void opening(OpeningParams o) => _group(o, 'Add ${o.kind.name}');

  void separator(double sx, double sy, double ex, double ey) =>
      _group(SeparatorParams(sx, sy, ex, ey), 'Add separator');

  void room(double x, double y, String name) =>
      _group(RoomParams(x, y, name), 'Add room');

  void dimension(DimEnd a, DimEnd b, DimKind kind, double offset) =>
      _group(DimensionParams(a, b, kind, offset), 'Add dimension');

  void box(double x, double y, double w, double h) {
    final handle = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: handle,
          parent: doc.rootHandle,
          transform: Transform2.translation(x, y),
          children: const [])),
      SetComponentCommand<BoxParams>(handle, BoxParams(w, h)),
    ], label: 'Add box'));
  }
}

void main() {
  setUpAll(loadManifestFonts);

  testWidgets('AR1 architecture_flat.png: the kit\'s sample flat',
      (tester) async {
    // The kit's sample flat (spec 3a C3.7): walls, openings, floor finishes,
    // furniture, rooms and dimensions, every one a type the kit gives.
    final doc = _document(buildSampleFlat);
    await pumpScene(tester, DraftStage(document: doc, size: kWide));
    await settle(tester);
    await shoot(tester, package: _package, file: 'architecture_flat.png');
  });

  testWidgets('AR2 architecture_types.png: one of each of the kit\'s types',
      (tester) async {
    final doc = _document(_types);
    await pumpScene(tester, DraftStage(document: doc, size: kWide));
    await settle(tester);
    await shoot(tester, package: _package, file: 'architecture_types.png');
  });
}
