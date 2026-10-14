// The editor fixture of jet_cad_floor_plan (test/host/editor_fixture.dart),
// ported for the units-only selection tests (2b Task 8; Task 10's
// inspector tests reuse it): the embedding fixture's hand-made table (its
// box off its base point, an asymmetric top) placed as `1` (turned 30
// degrees) and `2` (mirrored at exactly 90 degrees) beside the north wall,
// `7` and ` 7 ` sharing a label, an unlabelled table, `5` on a hidden and `L`
// on a locked layer; a root-level group of two lines, turned and off the
// origin; a free line; a TEXT; and a chair, a symbol that is no unit.
// The startup flat (sub-project 3's walls and rooms) is not ported: two
// root-level lines stand for the north wall and its inner face, a closed
// square for the column, and a line through table 1's top for the parquet
// hairline (fixture changes, A12). Same world coordinates, same camera
// (0.37 px/mm, y up, panned): never the identity.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform;
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogPolyline, CatalogSymbol, CatalogUnit;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit, UnitKinds;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart' show LockSet;
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'harness.dart' show planText;
import 'unit_fixtures.dart';

/// The window every editor test runs in.
const Size kEditorSurface = Size(2400, 1500);

const String kEmbeddingHidden = 'Hidden';
const String kEmbeddingLocked = 'Locked';

/// The embedding fixture's table (four seats): its top an asymmetric
/// quadrilateral; its base point the definition's origin, outside its box.
const CatalogSymbol embeddingTable = CatalogSymbol(
  key: 'fx.embedding.four',
  name: 'Test embedding table',
  category: 'Tests',
  tags: ['table', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 4),
  base: (0, 0),
  shapes: [
    CatalogPolyline([(300, -200), (1100, -200), (900, 400), (300, 250)],
        closed: true),
  ],
);

/// [embeddingTable]'s box in definition space: its centre (700, 100) is not
/// its base point (0, 0).
const Aabb2 embeddingBox = Aabb2.raw(300, -200, 1100, 400);

/// A chair: no unit, its base point (0, 0) off its seat.
const CatalogSymbol editorChair = CatalogSymbol(
  key: 'fx.chair.plain',
  name: 'Test chair',
  category: 'Tests',
  tags: ['chair', 'test'],
  base: (0, 0),
  shapes: [
    CatalogPolyline([(50, 50), (500, 50), (500, 430), (50, 430)], closed: true),
    CatalogPolyline([(50, 430), (500, 430), (500, 500), (50, 500)],
        closed: true),
  ],
);

/// `translate(x, y) · R(theta) · diag(sx, sy)`, written out.
Transform2 embeddingPlacement(double x, double y, double degrees,
    {double sx = 1, double sy = 1}) {
  final t = degrees * math.pi / 180;
  final cos = math.cos(t), sin = math.sin(t);
  return Transform2(sx * cos, sx * sin, -sy * sin, sy * cos, x, y);
}

/// One table of the fixture, as the test knows it.
final class EditorTable {
  const EditorTable(this.label, this.transform, {this.layer = '0'});

  /// The label written, or null for an unlabelled table.
  final String? label;
  final Transform2 transform;
  final String layer;
}

/// The fixture's tables in placement order (ascending by handle), as
/// today's `editorTables` (editor_fixture.dart:75-87).
final List<EditorTable> editorTables = [
  EditorTable('1', embeddingPlacement(21650, 15800, 30)),
  const EditorTable('2', Transform2(0, 1, 1, 0, 23100, 15600)),
  EditorTable('7', embeddingPlacement(22900, 14550, 60)),
  EditorTable(' 7 ', embeddingPlacement(25000, 15250, -150, sy: -1)),
  EditorTable(null, embeddingPlacement(21550, 14800, 15)),
  EditorTable('5', embeddingPlacement(24600, 13350, 45),
      layer: kEmbeddingHidden),
  EditorTable('L', embeddingPlacement(25200, 15500, 120, sy: -1),
      layer: kEmbeddingLocked),
];

final Transform2 editorChairPlacement = embeddingPlacement(23800, 16100, 10);
final Transform2 editorGroupPlacement = embeddingPlacement(21600, 13450, 20);
final (Vector2, Vector2) editorFreeLine =
    (Vector2(22700, 13400), Vector2(23300, 14300));
final Vector2 editorTextAt = Vector2(21700, 14250);
const double editorTextHeight = 200;
const String editorTextWords = 'Bar';

/// The north wall's stand-in, its inner face's, and the parquet hairline
/// through table 1's top (local (500, 0) of `1` is (22,083, 16,050)).
final (Vector2, Vector2) editorNorthWall =
    (Vector2(21400, 16850), Vector2(26400, 16850));
final (Vector2, Vector2) editorInnerFace =
    (Vector2(21400, 16750), Vector2(26400, 16750));
final (Vector2, Vector2) editorHairline =
    (Vector2(21900, 16050), Vector2(22300, 16050));

/// The column: a 400 x 400 square, its west edge through (23,500, 14,000).
const List<(double, double)> editorColumn = [
  (23500, 13800),
  (23900, 13800),
  (23900, 14200),
  (23500, 14200),
];

/// The fixture's plan, as a plan file over [fxKit].
String unitEditorPlanJson() => planText([fxKit()], (doc) {
      final zero = ReservedHandles.layerZero;
      final hidden = addLayer(doc, kEmbeddingHidden, visible: false);
      final locked = addLayer(doc, kEmbeddingLocked, locked: true);
      for (final t in editorTables) {
        final h = placeUnit(doc, embeddingTable,
            transform: t.transform,
            layer: switch (t.layer) {
              kEmbeddingHidden => hidden,
              kEmbeddingLocked => locked,
              _ => zero,
            });
        if (t.label case final label?) addUnitLabel(doc, h, label);
      }
      final group = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(GroupNode(
          handle: group,
          parent: doc.rootHandle,
          transform: editorGroupPlacement,
          children: const [])));
      for (final (a, b) in [
        (Vector2(100, 100), Vector2(900, 400)),
        (Vector2(100, 400), Vector2(900, 100)),
      ]) {
        doc.commands.execute(AddEntityCommand(
            record: draftRecord(doc.handleSeed.next(), group, EntityKind.line,
                layer: zero),
            payload: linePayload(a, b)));
      }
      for (final (a, b) in [
        editorFreeLine,
        editorNorthWall,
        editorInnerFace,
        editorHairline,
      ]) {
        doc.commands.execute(
            addDrafted(doc, EntityKind.line, linePayload(a, b), layer: zero));
      }
      doc.commands.execute(addDrafted(
          doc,
          EntityKind.polyline,
          polylinePayload([for (final (x, y) in editorColumn) Vector2(x, y)],
              closed: true),
          layer: zero));
      doc.commands.execute(addDrafted(
          doc, EntityKind.text, textPayload(editorTextAt, editorTextHeight),
          layer: zero, text: editorTextWords));
      placeUnit(doc, editorChair, transform: editorChairPlacement);
      doc.commands.clearHistory();
    });

/// The camera every editor test runs under: 0.37 px/mm, y flipped, panned
/// so world (21,400, 17,070) is the canvas's top left.
ViewportTransform editorCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, -7918, 6315.9));

/// The editor over [unitEditorPlanJson] under [permissions], in
/// [kEditorSurface], under [editorCamera]. The controller is disposed at
/// tear-down.
Future<PlanController> mountUnitEditor(WidgetTester tester,
    {PlanPermissions permissions = PlanPermissions.full}) async {
  final c = PlanController(kits: [fxKit()], json: unitEditorPlanJson());
  addTearDown(c.dispose);
  c.permissions = permissions;
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester
      .pumpWidget(MaterialApp(home: Scaffold(body: PlanEditor(controller: c))));
  await tester.pump();
  await tester.pump();
  c.camera.value = editorCamera();
  await tester.pump();
  return c;
}

/// Today's `setCaps`: the permissions changed at runtime, one pump.
Future<void> setPermissions(
    WidgetTester tester, PlanController c, PlanPermissions p) async {
  c.permissions = p;
  await tester.pump();
}

Offset canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer));

/// World [w] on the screen, by the camera's forward transform.
Offset screenOf(WidgetTester tester, PlanController c, Vector2 w) {
  final m = c.camera.value.worldToScreenMatrix;
  return canvasOrigin(tester) +
      Offset(m.a * w.x + m.c * w.y + m.e, m.b * w.x + m.d * w.y + m.f);
}

/// The plan's units, read now (the fixture kit loaded: nothing locked by a
/// missing kit).
UnitIndex unitsIn(PlanController c) => UnitIndex.of(c.document,
    catalog: c.catalog,
    locks: LockSet.scan(c.document, (kit) => c.kits.kitOf(kit) != null));

/// Table [n]'s instance; ` 7 ` is the later of the two sevens, null the
/// unlabelled one.
Handle tableOf(PlanController c, String? n) {
  final index = unitsIn(c);
  if (n == null) return index.units.singleWhere((u) => u.text == null).instance;
  return index.withLabel(n)[n == ' 7 ' ? 1 : 0].instance;
}

/// The world centre of table [n]'s box, by the fixture's own transform.
Vector2 centreOf(PlanController c, String n) {
  final node = c.document.tree[tableOf(c, n)]! as InstanceNode;
  return node.transform.transformPoint(Vector2(700, 100));
}

Future<void> click(WidgetTester tester, Offset at) async {
  final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await g.addPointer(location: at - const Offset(3, 3));
  await g.moveTo(at);
  await tester.pump();
  await g.down(at);
  await tester.pump();
  await g.up();
  await tester.pump();
  await g.removePointer();
  await tester.pump();
}

Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

/// The plan's kit set for a controller over [unitEditorPlanJson].
List<PlanKit> editorKits() => [fxKit()];
