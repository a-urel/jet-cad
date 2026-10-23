// 2b's unit editor fixture (jet_cad_2d_plan/test/support/unit_editor_fixture.dart), ported for the integration tests (3a Task 26) with today's startup flat restored (jet_cad_floor_plan/test/host/editor_fixture.dart): the stand-in lines for the north wall, its inner face, the column and the parquet hairline are gone, the flat draws them. Same world coordinates, same camera.
//
// The editor's selection helpers are 2b's units_only_select_test.dart's
// (:28-124), the selection read through `activeSelection`. The rig's
// helpers are never copied (R-P14): [screenOf] is the rig's `globalAt`
// and [click] canvas_rig.dart's `mouseClick`, under 2b's names.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey, ViewportTransform;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'canvas_rig.dart' show globalAt, mouseClick;
import 'plans.dart' show planWith;
import 'units.dart';

/// The window every editor test runs in.
const Size kEditorSurface = Size(2400, 1500);

const String kEmbeddingHidden = 'Hidden';
const String kEmbeddingLocked = 'Locked';

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

/// The column's south-west corner (the sample flat's column, x 23,500 -
/// 23,900, y 13,800 - 14,200; jet_cad_floor_plan's editor_fixture.dart:109).
final Vector2 editorColumnCorner = Vector2(23500, 13800);

/// The fixture's plan: the sample flat (C1.9's build, English words),
/// then 2b's units, group, free line, TEXT and chair, over
/// [architectureKit] and [fxKit].
String editorPlanJson() => planWith((doc) {
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
        if (t.label case final label?) labelUnit(doc, h, label);
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
      doc.commands.execute(addDrafted(doc, EntityKind.line,
          linePayload(editorFreeLine.$1, editorFreeLine.$2),
          layer: zero));
      doc.commands.execute(addDrafted(
          doc, EntityKind.text, textPayload(editorTextAt, editorTextHeight),
          layer: zero, text: editorTextWords));
      placeUnit(doc, editorChair, transform: editorChairPlacement);
    }, kits: [architectureKit, fxKit()], first: buildSampleFlat);

/// The camera every editor test runs under: 0.37 px/mm, y flipped, panned
/// so world (21,400, 17,070) is the canvas's top left.
ViewportTransform editorCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, -7918, 6315.9));

/// The editor over [json] ([editorPlanJson] by default) under
/// [permissions], in [kEditorSurface], under [editorCamera], its object
/// snap allowed unless [snapping] is false (`PlanEditor.snapping`; 3a Task
/// 28: today's `Caps.snapping`). The controller is disposed at tear-down.
Future<PlanController> mountEditor(WidgetTester tester,
    {PlanPermissions permissions = PlanPermissions.full,
    String? json,
    bool snapping = true,
    bool alignmentGuides = true}) async {
  final c = PlanController(
      kits: [architectureKit, fxKit()], json: json ?? editorPlanJson());
  addTearDown(c.dispose);
  c.permissions = permissions;
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: PlanEditor(
              controller: c,
              snapping: snapping,
              alignmentGuides: alignmentGuides))));
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

/// World [w] on the screen: the rig's [globalAt] under 2b's name.
Offset screenOf(WidgetTester tester, PlanController c, Vector2 w) =>
    globalAt(tester, c, w);

/// The world centre of table [n]'s box, by the fixture's own transform.
Vector2 centreOf(PlanController c, String n) {
  final node = c.document.tree[tableOf(c, n)]! as InstanceNode;
  return node.transform.transformPoint(Vector2(700, 100));
}

/// A mouse click at [at]: canvas_rig.dart's [mouseClick] under 2b's name.
Future<void> click(WidgetTester tester, Offset at) => mouseClick(tester, at);

/// The plan's kit set for a controller over [editorPlanJson].
List<PlanKit> editorKits() => [architectureKit, fxKit()];

/// The plan's encoding under 2b's key tests' name (plan_shortcuts_test.dart:
/// 141-142): [encoded].
String encodedPlan(PlanController c) => encoded(c);

/// The design's encoding: byte-identical means no edit.
String encoded(PlanController c) =>
    DraftDocumentCodec.encodeToString(c.document);

/// Table [n]'s root key.
SelectionKey keyOf(PlanController c, String n) =>
    SelectionKey.root(tableOf(c, n));

/// Table [n]'s transform.
Transform2 transformOf(PlanController c, String n) =>
    (c.document.tree[tableOf(c, n)]! as InstanceNode).transform;

/// [local], in table [n]'s definition space, in the world.
Vector2 onTable(PlanController c, String n, double x, double y) =>
    transformOf(c, n).transformPoint(Vector2(x, y));

/// A point inside table [n]'s top, away from its lines (the top is the
/// quadrilateral (300, -200), (1100, -200), (900, 400), (300, 250)).
Vector2 topOf(PlanController c, String n) => onTable(c, n, 500, 0);

/// A point inside table [n]'s box, off its top: beyond the top's slanted
/// edge from (1100, -200) to (900, 400).
Vector2 boxOf(PlanController c, String n) => onTable(c, n, 1050, 350);

/// A point on table [n]'s top's bottom edge: where the index's own pick
/// (no `selectUnitsOnly`) finds the table, over the parquet.
Vector2 edgeOf(PlanController c, String n) => onTable(c, n, 700, -200);

/// [line]'s first point in the world (a root-level line).
Vector2 startOf(DraftDocument d, Handle line) {
  final p =
      d.geometry.read(d.entities.geomIndexAt(d.entities.slotOf(line)!)).coords;
  return Vector2(p[0], p[1]);
}

/// Whether [h] is a live line entity (today's wall).
bool isLine(DraftDocument d, Handle h) {
  final slot = d.entities.slotOf(h);
  return slot != null && d.entities.kindAt(slot) == EntityKind.line;
}

/// The selection's keys.
Set<SelectionKey> selected(PlanController c) => {...c.activeSelection.keys};

/// A mouse drag from [from] to [to] in eight steps; [before] runs after
/// the last move and before the up.
Future<void> drag(WidgetTester tester, Offset from, Offset to,
    {Future<void> Function()? before}) async {
  final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await g.addPointer(location: from - const Offset(2, 2));
  await g.moveTo(from);
  await tester.pump();
  await g.down(from);
  await tester.pump();
  for (var i = 1; i <= 8; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 8)!);
    await tester.pump();
  }
  if (before != null) await before();
  await g.up();
  await tester.pump();
  await g.removePointer();
  await tester.pump();
}

/// A finger's tap at [at]: down, held past the touch hold-back, up.
Future<void> fingerTap(WidgetTester tester, Offset at) async {
  final g = await tester.startGesture(at,
      pointer: 41, kind: ui.PointerDeviceKind.touch);
  await tester.pump(const Duration(milliseconds: 150));
  await g.up();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The rotation grip of table [n]: 24 px above its top's screen box.
Offset rotationGripOf(WidgetTester tester, PlanController c, String n) {
  final corners = [
    for (final (x, y) in const [
      (300, -200),
      (1100, -200),
      (900, 400),
      (300, 250)
    ])
      screenOf(tester, c, onTable(c, n, x.toDouble(), y.toDouble())),
  ];
  final minX = corners.map((p) => p.dx).reduce(math.min);
  final maxX = corners.map((p) => p.dx).reduce(math.max);
  final minY = corners.map((p) => p.dy).reduce(math.min);
  return Offset((minX + maxX) / 2, minY - 24);
}

/// The turn of [m], in degrees.
double degreesOf(Transform2 m) => math.atan2(m.b, m.a) * 180 / math.pi;

/// The bands' corners: the whole canvas, inset 4 px.
Rect canvasRect(WidgetTester tester) =>
    tester.getRect(find.byType(InteractionLayer)).deflate(4);
