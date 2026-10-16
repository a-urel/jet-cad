// Spec 09c D8: the wall-aware move's resolver, alone and through the
// Select tool. A free 3600 mm wall at 30 degrees in a turned group near
// (1e5, −7e4); a 1600 x 2000 bed tagged against-wall, its base point at its
// box's centre, 1000 mm from its back; the camera at 0.1 px/mm, so the
// 16 px capture is 160 mm: the back-centre within it, the insertion point
// far outside.
//
// Ported to jet_cad_2d_integration (3a Task 28, D-01; rulings IA-R1,
// IA-R2, IA-R3): the plan's move resolver is internal, so each case is the
// same move dragged on the canvas through plan.select (a press on the
// symbol's body, eight moves, the release) and its assertion is read on
// the committed instance: MV4 pins that the drop commits the resolver's
// answer verbatim, so the committed transform is the answer, and a plain
// move `delta · T` where the answer was null. The symbols are the fixture
// kit's (C7 classes 1 and 2: `fx.test.*`, the tag `against-wall` is
// `attachTo: ['wall-face']`); the scene's attachment is the kit's provider
// asked through the contract at the plan's own captures (IA-R1: the edge
// capture is 100 mm, today's 60; a box centred mid-run snaps at neither).
// Fixture changes: the plan's page has `snapToGrid: false` (today's scene
// had no page, so no grid moved the drag); the press is the body point
// `(0, depth / 2)` of the symbol's left edge, MV4's point for the bed, and
// `(0, 120)` for the 600 mm unit, whose mid-edge drag would land 30 mm from
// its own old right edge's midpoint and object-snap there (the select
// tool's drag snaps; today's MV6 called the resolver directly).
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform;
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogPolyline, CatalogSymbol;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_plans.dart';
import '../support/canvas_rig.dart'
    show focusCanvas, globalAt, pressKey, pumpPlanEditor;
import '../support/editor_fixture.dart' show drag;
import '../support/units.dart';

CatalogSymbol rect(String key, double w, double d, List<String> attachTo) =>
    CatalogSymbol(
      key: key,
      name: key,
      category: 'Tests',
      tags: const [],
      attachTo: attachTo,
      base: (w / 2, d / 2),
      shapes: [
        CatalogPolyline([(0, 0), (w, 0), (w, d), (0, d)], closed: true),
      ],
    );

final List<CatalogSymbol> library = [
  rect('fx.test.bed', 1600, 2000, ['wall-face']),
  rect('fx.test.island', 1600, 2000, []),
  rect('fx.test.unit', 600, 600, ['wall-face']),
];
CatalogSymbol symbol(String key) => library.singleWhere((s) => s.key == key);
SymbolEntry entry(String key) => entryOf(symbol(key));

/// Today's `Scene` as a pumped editor: the plan file, the controller, the
/// face run, the box, the attachment and the instance.
final class Scene {
  Scene(this.c, this.run, this.box, this.attachedAt, this.off, this.instance);

  final PlanController c;
  final FaceLine run;
  final SymbolBox box;
  final Transform2 attachedAt;
  final Vector2 off;
  final Handle instance;

  DraftDocument get doc => c.document;

  Transform2 get transform => (doc.tree[instance]! as InstanceNode).transform;
}

Future<Scene> scene(WidgetTester tester,
    {String key = 'fx.test.bed',
    bool objectSnap = true,
    bool mirrored = false,
    bool atFace = false}) async {
  late FaceLine run;
  late Transform2 attachedAt;
  late Vector2 off;
  late Handle instance;
  final box = boxOfEntry(entry(key))!;
  final plan = freeWallPlan(30, Justification.centre, extra: (doc) {
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, page.copyWith(snapToGrid: false)));
    final wall = doc.components.withComponent<WallParams>().single;
    run = faceLineOf(doc, wall, left: true);
    // The attachment at the run's middle, then moved 800 mm into the room
    // and 300 along: a free bed whose back faces the wall.
    final mid = run.a + run.t * (run.length / 2);
    final base = entry(key).definition.basePoint;
    attachedAt = attachOf(
            doc,
            entry(key),
            mid,
            placementTransform(at: mid, basePoint: base, mirrored: mirrored),
            0.1,
            mirrored: mirrored)!
        .transform;
    off = atFace ? Vector2.zero() : run.m * 800 + run.t * 300;
    instance = placeUnit(doc, symbol(key),
        transform: placementTransform(at: Vector2.zero(), basePoint: base));
    doc.commands.execute(TransformNodeCommand(
        instance, Transform2.translation(off.x, off.y).multiply(attachedAt)));
  });
  final c = PlanController(
      kits: [architectureKit, fxKit(library: library)], json: plan.json);
  addTearDown(c.dispose);
  await pumpPlanEditor(tester, c);
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, -9600, -6600));
  await tester.pump();
  if (!objectSnap) {
    await focusCanvas(tester);
    expect(await pressKey(tester, LogicalKeyboardKey.f3), isTrue,
        reason: 'premise: F3 toggled object snap off');
  }
  return Scene(c, run, box, attachedAt, off, instance);
}

/// The plain move that brings the back-centre [into] mm from the face.
Transform2 backTo(Scene s, double into) {
  final v = s.run.m * into - s.off;
  return Transform2.translation(v.x, v.y);
}

double faceS(Scene s, Vector2 p) => (p - s.run.a).dot(s.run.m);

/// The body point a drag presses: on the symbol's left edge, its middle
/// for the bed (MV4's `(0, 1000)`), 120 mm from its front for the unit.
Vector2 pressOf(Scene s) => s.transform
    .transformPoint(Vector2(0, s.box.depth == 2000 ? s.box.depth / 2 : 120));

/// Today's `resolveMove(ctx, instance, delta)` on the canvas (IA-R2): the
/// instance's body dragged from [pressOf] by [delta] through plan.select.
Future<void> moveBy(WidgetTester tester, Scene s, Transform2 delta) async {
  final press = pressOf(s);
  final from = globalAt(tester, s.c, press);
  final to = globalAt(tester, s.c, delta.transformPoint(press));
  final canvas = tester.getRect(find.byType(InteractionLayer));
  expect(canvas.contains(from) && canvas.contains(to), isTrue,
      reason: 'premise: the drag is on the canvas');
  await drag(tester, from, to);
}

/// The plain move `delta · before` (the resolver's null), within 1e-9.
void expectPlain(
    Transform2 got, Transform2 delta, Transform2 before, String reason) {
  final want = partsOf(delta.multiply(before));
  final parts = partsOf(got);
  for (var i = 0; i < 6; i++) {
    expect(parts[i], closeTo(want[i], 1e-9), reason: '$reason [$i]');
  }
}

void main() {
  moreTests();
  testWidgets(
      'MV1 the back-centre brought near the face attaches: the back on the '
      'face, the marker its face point; the insertion point is far '
      '(M-09c-an)', (tester) async {
    final s = await scene(tester);
    final delta = backTo(s, 40);
    final insertion = delta
        .multiply(s.transform)
        .transformPoint(entry('fx.test.bed').definition.basePoint);
    expect(faceS(s, insertion), greaterThan(160),
        reason: 'premise: the insertion point is outside the capture');
    await moveBy(tester, s, delta);
    final r = (transform: s.transform);
    final back = r.transform.transformPoint(s.box.backCentre);
    expect(faceS(s, back), closeTo(0, 1e-6), reason: 'flush');
    // Not ported (ruling IA-R3): expect((back - r.marker).length,
    // lessThan(1e-6)); the marker is a painted overlay with no public read.
    for (final (got, want) in [
      (r.transform.a, s.attachedAt.a),
      (r.transform.b, s.attachedAt.b),
      (r.transform.c, s.attachedAt.c),
      (r.transform.d, s.attachedAt.d),
    ]) {
      expect(got, closeTo(want, 1e-12), reason: 'turned to the wall');
    }
  });

  testWidgets('MV2 far from the face, nothing', (tester) async {
    final s = await scene(tester);
    final before = s.transform;
    final delta = backTo(s, 400);
    await moveBy(tester, s, delta);
    expectPlain(s.transform, delta, before, 'nothing: the plain move');
  });

  testWidgets(
      'MV3 no attachment for an untagged symbol, with F3 off, before the '
      'library is ready, or for a scaled instance (M-09c-az, M-09c-am)',
      (tester) async {
    // One editor per clause, mounted in turn.
    for (final (why, key, objectSnap) in const [
      ('untagged', 'fx.test.island', true),
      ('F3 off', 'fx.test.bed', false),
    ]) {
      final s = await scene(tester, key: key, objectSnap: objectSnap);
      final before = s.transform;
      final delta = backTo(s, 40);
      await moveBy(tester, s, delta);
      expectPlain(s.transform, delta, before, why);
    }
    // Not ported (ruling IA-R3): the "no library" clause, scene(ready:
    // false): the plan's resolver reads the placed definition's own
    // SymbolComponent, never a library (premise impossible, C7).
    final s = await scene(tester);
    // Scaled by 1.001 about its back-centre: still at 40 mm, not orthonormal.
    final c = s.transform.transformPoint(s.box.backCentre);
    s.doc.commands.execute(TransformNodeCommand(
        s.instance,
        Transform2.translation(c.x, c.y)
            .multiply(Transform2.scale(1.001, 1.001))
            .multiply(Transform2.translation(-c.x, -c.y))
            .multiply(s.transform)));
    await tester.pump();
    final before = s.transform;
    final delta = backTo(s, 40);
    await moveBy(tester, s, delta);
    expectPlain(s.transform, delta, before, 'scaled');
  });

  testWidgets(
      'MV4 through the Select tool: a drag towards the wall commits the '
      'attachment verbatim, one step', (tester) async {
    final s = await scene(tester);
    // Press on the bed's left edge, halfway along: a point of the body.
    final press = s.transform.transformPoint(Vector2(0, 1000));
    expect(pressOf(s), press, reason: 'premise: MV4\'s press point');
    final delta = backTo(s, 40);
    final depth = s.doc.commands.undoDepth;
    await moveBy(tester, s, delta);
    expect(s.doc.commands.undoDepth, depth + 1);
    final back = s.transform.transformPoint(s.box.backCentre);
    expect(faceS(s, back), closeTo(0, 1e-6));
  });
}

void moreTests() {
  testWidgets('MV5 a mirrored symbol attaches mirrored (D4)', (tester) async {
    final s = await scene(tester, mirrored: true);
    expect(s.transform.determinant, lessThan(0), reason: 'premise');
    await moveBy(tester, s, backTo(s, 40));
    final r = (transform: s.transform);
    expect(r.transform.determinant, lessThan(0));
    expect(faceS(s, r.transform.transformPoint(s.box.backCentre)),
        closeTo(0, 1e-6));
  });

  testWidgets(
      'MV6 a unit dragged along its face by nearly its width does not snap '
      'to where it was: its own instance is no neighbour (M-09c-ab)',
      (tester) async {
    final s = await scene(tester, key: 'fx.test.unit', atFace: true);
    // The bands hear the placement's change event; the faces rebuild.
    await tester.pump(Duration.zero);
    final u0 =
        (s.transform.transformPoint(s.box.backCentre) - s.run.a).dot(s.run.t);
    final v = s.run.t * 570;
    await moveBy(tester, s, Transform2.translation(v.x, v.y));
    final r = (transform: s.transform);
    final u =
        (r.transform.transformPoint(s.box.backCentre) - s.run.a).dot(s.run.t);
    expect(u - u0, closeTo(570, 1e-6),
        reason: 'not snapped on to its own old right side');
  });
}
