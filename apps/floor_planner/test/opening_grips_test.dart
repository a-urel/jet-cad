// Spec 08 D16, D15: an opening's slide grip, the composite provider, and
// no select-tool move or rotate for an opening. Every wall is at the far
// origin in its own rotated group, the plan is turned 23 degrees, the camera
// is rotated, and the door's own group is off the identity. Expected
// positions come from `support/opening_fixture.dart`'s oracles, which never
// call `opening_geometry.dart`.
import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/object_grips.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/opening_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart';
import 'support/wall_fixture.dart';

SelectionKey k(Handle h) => SelectionKey.root(h);

/// The door's own group: off the identity, so nothing may read the grip
/// through it.
final Transform2 doorGroup = Transform2.translation(ox + 120, oy - 80)
    .multiply(Transform2.rotation(0.9));

/// The fixture: A (6,000, 200, centred) with a 115 stem at 80° ending on its
/// centreline at 2,000 (a T obstacle on A's left), a 900 door stored at
/// `o2 + 300` so that it is drawn clamped at `[o2, o2 + 900]` (hinge start,
/// swing right, away from the stem), and a 4,500 window that fits nowhere.
/// Built through the parametric system [build] installs, with no history.
({Handle a, Handle door, Handle nofit, double o1, double o2}) addClampedDoor(
    DraftDocument doc) {
  final a = doc.handleSeed.next();
  doc.commands.execute(
      addWall(doc, a, plan(0, 0), plan(6000, 0), 200, Justification.centre));
  final foot = oracleAt(oracleFrameOf(doc, a), 2000, 0);
  final stem = doc.handleSeed.next();
  doc.commands.execute(addWall(
      doc, stem, polar(foot, 23 + 80, 1800), foot, 115, Justification.left));
  final [(o1, o2)] = OpeningOracle(doc).obstacles(a);
  final door = doc.handleSeed.next();
  doc.commands.execute(addOpening(doc, door,
      OpeningParams(a, o2 + 300, 900, OpeningKind.door, swing: SwingSide.right),
      at: doorGroup));
  final nofit = doc.handleSeed.next();
  doc.commands.execute(
      addOpening(doc, nofit, OpeningParams(a, 4000, 4500, OpeningKind.window)));
  doc.commands.clearHistory();
  return (a: a, door: door, nofit: nofit, o1: o1, o2: o2);
}

OpeningParams paramsOf(DraftDocument doc, Handle h) =>
    doc.components.get<OpeningParams>(h)!;

// ---------------------------------------------------------------------------
// The shell, as `wall_grips_test.dart` drives it.

/// The camera's scale in pixels per mm: the snap aperture is ~67 mm.
const double _scale = 0.15;

/// The page's fixed grid step.
const double _gridStep = 10;

/// A 1:20 page near the far origin with grid snap on at [_gridStep], and
/// what [build] adds, with no undo history.
DraftDocument shellDoc(
    FlutterTextMeasurer m, void Function(DraftDocument doc) build) {
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: ox - 2000,
          originY: oy - 2000,
          gridStepMm: _gridStep)));
  // The shell installs the parametric system itself; the objects are added
  // through a temporary one, which regenerates them as they are created.
  final system = installParametric(doc);
  build(doc);
  system.dispose();
  doc.commands.clearHistory();
  return doc;
}

/// Pumps the shell, then sets a rotated, non-reflecting camera centred on
/// [centre].
Future<PlannerView> pumpShell(
    WidgetTester tester, DraftDocument doc, Vector2 centre) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(_scale, _scale));
  final mid = linear.transformPoint(centre);
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

Offset globalOf(WidgetTester tester, PlannerView view, Vector2 p) {
  final s = view.camera.value.worldToScreen(p);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

Future<void> tapWorld(WidgetTester tester, PlannerView view, Vector2 p,
    {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.tapAt(globalOf(tester, view, p));
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

/// A mouse drag from world [from] to world [to], past the slop at once.
Future<void> dragWorld(
    WidgetTester tester, PlannerView view, Vector2 from, Vector2 to) async {
  final a = globalOf(tester, view, from), b = globalOf(tester, view, to);
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(a);
  await gesture.moveTo(a + const Offset(12, 0));
  await gesture.moveTo(b);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

Future<void> undoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

/// The page's grid point nearest [p]: where a drag released near [p] lands
/// when no object snap is near.
Vector2 gridOf(DraftDocument doc, Vector2 p) => snapToGrid(
    p, _gridStep, doc.components.get<PageComponent>(doc.rootHandle)!);

/// The shown object grips of [h].
List<Grip> objectGripsOf(PlannerView view, Handle h) => [
      for (final r in view.grips.grips)
        if (r.object && r.key == k(h)) r.grip,
    ];

void main() {
  test(
      'SG1 (X11-stored, M-08sn, M-08b) the provider: a clamped door\'s grip '
      'sits at its cut\'s centre, a no-fit\'s at its stored centre; a drag '
      'projects, edge-snaps to an obstacle edge, and stores the placed '
      'centre, the clamped one where it is drawn and a no-fit one clamped '
      'to the wall; with no aperture there is no edge snap; a drag back to '
      'the start is null', () {
    final doc = wallDoc();
    final (:a, :door, :nofit, :o1, :o2) = addClampedDoor(doc);
    final f = oracleFrameOf(doc, a);
    final oracle = OpeningOracle(doc);
    final cut = oracle.cut(paramsOf(doc, door))!;
    expect(cut.clamped, isTrue);
    expect(cut.a, closeTo(o2, 1e-6), reason: 'drawn from the obstacle');
    expect(oracle.cut(paramsOf(doc, nofit)), isNull);
    // What the wall draws: the stretch end the grip snaps to, exactly.
    final [(_, e0), (s1, _)] = layoutInDocument(doc, a)!.stretches;
    expect(e0, closeTo(o1, 1e-6));
    expect(s1, closeTo(o2, 1e-6));

    double? aperture = 20;
    final objects = ObjectGrips(edgeAperture: () => aperture);
    expect(objects.movable(doc, door), isFalse);
    expect(objects.movable(doc, a), isTrue);

    // The grips.
    final g = objects.gripsOf(doc, door).single;
    expect(g.role, GripRole.stretch);
    final drawn = oracleAt(f, cut.a + 450, 0);
    expect((Vector2(g.x, g.y) - drawn).length, lessThan(1e-6),
        reason: 'at the cut\'s centre');
    expect(
        (Vector2(g.x, g.y) - oracleAt(f, o2 + 300, 0)).length, greaterThan(100),
        reason: 'not at the stored centre');
    final n = objects.gripsOf(doc, nofit).single;
    expect((Vector2(n.x, n.y) - oracleAt(f, 4000, 0)).length, lessThan(1e-6),
        reason: 'a no-fit opening\'s at its stored centre');

    // A drag whose right edge ends 9 mm short of the obstacle's near edge:
    // it snaps onto it, 60 mm off the centreline.
    final target = oracleAt(f, o1 - 450 - 9, 60);
    final command = objects.drag(doc, door, g, target)!;
    final preview = objects.preview(doc, door, g, target);
    expect(preview, hasLength(2), reason: 'the would-be cut\'s jambs');
    for (final (i, u) in [(0, o1 - 900), (1, o1)]) {
      final (kind, l) = preview[i];
      expect(kind, EntityKind.line);
      expect((l.pointAt(0) - oracleAt(f, u, f.lo)).length, lessThan(1e-6),
          reason: 'jamb $i, left face');
      expect((l.pointAt(1) - oracleAt(f, u, f.ro)).length, lessThan(1e-6),
          reason: 'jamb $i, right face');
    }
    doc.commands.execute(command);
    final p1 = paramsOf(doc, door);
    expect(p1.position + 450, closeTo(e0, 1e-9), reason: 'the edge snapped');
    expect(
        p1,
        OpeningParams(a, p1.position, 900, OpeningKind.door,
            swing: SwingSide.right),
        reason: 'only the position is written');
    expect(
        diagnosticsOf(doc).where((d) => d.code == 'opening.clamped'), isEmpty,
        reason: 'stored where it is drawn');

    // Back to the start: nothing, with the edge snap and without.
    final back = objects.gripsOf(doc, door).single;
    expect((Vector2(back.x, back.y) - oracleAt(f, o1 - 450, 0)).length,
        lessThan(1e-6));
    expect(objects.drag(doc, door, back, Vector2(back.x, back.y)), isNull);
    aperture = null;
    expect(objects.drag(doc, door, back, Vector2(back.x, back.y)), isNull);

    // No aperture: no edge snap, the projection itself.
    final plain = objects.drag(doc, door, back, target)!;
    doc.commands.execute(plain);
    expect(paramsOf(doc, door).position, closeTo(o1 - 459, 1e-6));
    doc.commands.undo();

    // Into the obstacle, 250 mm past both of its edges' aperture: stored
    // at the clamped centre, where it is drawn, and not diagnosed.
    aperture = 20;
    doc.commands
        .execute(objects.drag(doc, door, back, oracleAt(f, o2 + 200, -30))!);
    final p2 = paramsOf(doc, door).position;
    expect(p2, closeTo(o2 + 450, 1e-6));
    final c2 = OpeningOracle(doc).cut(paramsOf(doc, door))!;
    expect(c2.clamped, isFalse, reason: 'stored where it is drawn');
    expect(c2.a, closeTo(o2, 1e-6));

    // The no-fit window: the projection, clamped to [0, L].
    for (final (u, want) in [
      (1234.5, 1234.5),
      (f.len + 700, f.len),
      (-300.0, 0.0),
    ]) {
      final c = objects.drag(doc, nofit, n, oracleAt(f, u, 40))!;
      doc.commands.execute(c);
      expect(paramsOf(doc, nofit).position, closeTo(want, 1e-6),
          reason: 'no-fit at $u');
      doc.commands.undo();
    }
  });

  testWidgets(
      'SG1 (shell) the slide grip is shown at the drawn centre; a drag '
      'edge-snaps while object snap is on and is one undo step; with F3 off '
      'it stores the grid point projected; under runtime permissions the '
      'grip is not hit', (tester) async {
    late ({Handle a, Handle door, Handle nofit, double o1, double o2}) s;
    final doc = shellDoc(FlutterTextMeasurer(), (d) => s = addClampedDoor(d));
    final f = oracleFrameOf(doc, s.a);
    final view = await pumpShell(tester, doc, plan(2000, 0));
    final cut = OpeningOracle(doc).cut(paramsOf(doc, s.door))!;
    final stored = paramsOf(doc, s.door);

    // Select the door: a click on its leaf, on the right, away from the
    // stem.
    await tapWorld(tester, view, oracleAt(f, cut.a, f.ro - 450));
    expect(view.selection.keys, [k(s.door)]);
    final g = objectGripsOf(view, s.door).single;
    expect((Vector2(g.x, g.y) - oracleAt(f, cut.a + 450, 0)).length,
        lessThan(1e-6),
        reason: 'at the cut\'s centre');

    // F3 on: the right edge released ~25 mm short of the obstacle's near
    // edge snaps onto it (the aperture is ~67 mm).
    final target = oracleAt(f, s.o1 - 450 - 25, 30);
    await dragWorld(tester, view, Vector2(g.x, g.y), target);
    await tester.pump();
    expect(doc.commands.undoDepth, 1, reason: 'one undo step');
    expect(paramsOf(doc, s.door).position + 450, closeTo(s.o1, 1e-6));
    expect(paramsOf(doc, s.door).position,
        isNot(closeTo(oracleU(f, gridOf(doc, target)), 1)),
        reason: 'not the chain\'s point');
    await undoKey(tester);
    expect(paramsOf(doc, s.door), stored, reason: 'undone, exactly');
    expect(doc.commands.undoDepth, 0);

    // F3 off: the grid point projected, no edge snap.
    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.pump();
    final g2 = objectGripsOf(view, s.door).single;
    await dragWorld(tester, view, Vector2(g2.x, g2.y), target);
    await tester.pump();
    expect(doc.commands.undoDepth, 1);
    expect(paramsOf(doc, s.door).position,
        closeTo(oracleU(f, gridOf(doc, target)), 1e-6));
    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.pump();

    // Runtime: the grip is not hit.
    final g3 = objectGripsOf(view, s.door).single;
    final m = view.camera.value.worldToScreenMatrix;
    final at = view.camera.value.worldToScreen(Vector2(g3.x, g3.y));
    expect(view.grips.hitTest(Offset(at.x, at.y), m), isNot(-1));
    doc.commands.permissions = DraftPermissions.runtime;
    expect(view.grips.hitTest(Offset(at.x, at.y), m), -1);
  });

  testWidgets(
      'SG2 (M-08i) a body drag on a selected door starts nothing and adds '
      'nothing to the history, and no rotation grip is drawn for it; a wall '
      'selected with its door moves, and the door follows through '
      'regeneration with its stored position unchanged', (tester) async {
    late Handle a, door, win;
    final doc = shellDoc(FlutterTextMeasurer(), (d) {
      a = d.handleSeed.next();
      d.commands.execute(
          addWall(d, a, plan(0, 0), plan(5000, 0), 200, Justification.right));
      door = d.handleSeed.next();
      d.commands.execute(addOpening(
          d,
          door,
          OpeningParams(a, 1730, 900, OpeningKind.door,
              hinge: HingeEnd.end, swing: SwingSide.right),
          at: doorGroup));
      win = d.handleSeed.next();
      d.commands.execute(
          addOpening(d, win, OpeningParams(a, 3650, 1200, OpeningKind.window)));
    });
    final f = oracleFrameOf(doc, a);
    final view = await pumpShell(tester, doc, plan(2500, 0));
    final before = enc(doc);
    final params = {door: paramsOf(doc, door), win: paramsOf(doc, win)};
    final nodes = {door: doc.tree[door], win: doc.tree[win]};

    // The door alone: its leaf runs from the hinge (the cut's end, on the
    // right face) 900 away from the band.
    final leaf = oracleAt(f, 1730 + 450, f.ro - 450);
    await tapWorld(tester, view, leaf);
    expect(view.selection.keys, [k(door)]);
    expect(view.grips.box, isNotNull);
    expect(view.grips.rotatable, isFalse, reason: 'no rotation grip');
    await dragWorld(tester, view, leaf, leaf + (plan(700, 300) - plan(0, 0)));
    await tester.pump();
    expect(doc.commands.undoDepth, 0, reason: 'nothing in the history');
    expect(enc(doc), before, reason: 'nothing moved');
    expect(view.selection.keys, [k(door)], reason: 'still a click');

    // The wall and its door: the wall moves, the door follows.
    final body = oracleAt(f, 800, -100);
    await tapWorld(tester, view, body, shift: true);
    expect(view.selection.keys.toSet(), {k(door), k(a)});
    expect(view.grips.rotatable, isTrue);
    final t0 = doc.tree.accumulatedTransform(a);
    final lines = {
      for (final o in [door, win]) o: worldLines(doc, o)
    };
    await dragWorld(tester, view, body, body + (plan(640, -410) - plan(0, 0)));
    await tester.pump();
    expect(doc.commands.undoDepth, 1, reason: 'one step');
    final t1 = doc.tree.accumulatedTransform(a);
    final v = Vector2(t1.e - t0.e, t1.f - t0.f);
    expect(v.length, greaterThan(500), reason: 'the wall moved');
    expect([t1.a, t1.b, t1.c, t1.d], [t0.a, t0.b, t0.c, t0.d]);
    for (final o in [door, win]) {
      expect(paramsOf(doc, o), params[o], reason: 'stored, exactly: $o');
      expect(doc.tree[o], nodes[o], reason: 'its group untouched: $o');
      final now = worldLines(doc, o);
      expect(now, hasLength(lines[o]!.length));
      for (final (i, (p, q)) in lines[o]!.indexed) {
        expect((now[i].$1 - (p + v)).length, lessThan(1e-6),
            reason: 'followed: $o line $i');
        expect((now[i].$2 - (q + v)).length, lessThan(1e-6),
            reason: 'followed: $o line $i');
      }
    }
    expect(driftOf(doc), isEmpty);
  });
}
