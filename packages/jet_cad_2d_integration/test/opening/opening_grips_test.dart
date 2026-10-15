// Ported from jet_cad_floor_plan/test/opening_grips_test.dart (spec 3a C6, C7):
// SG1 (shell), SG2 and SG4 over architectureController in PlanEditor.
// ignore_for_file: invalid_use_of_internal_member
// Spec 08 D16, D15: an opening's slide grip, the composite provider, and
// no select-tool move or rotate for an opening. Every wall is at the far
// origin in its own rotated group, the plan is turned 23 degrees, the camera
// is rotated, and the door's own group is off the identity. Expected
// positions come from `support/opening_fixture.dart`'s oracles, which never
// call `opening_geometry.dart`.
import 'dart:typed_data';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/opening_support.dart';

SelectionKey k(Handle h) => SelectionKey.root(h);

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

void main() {
  testWidgets(
      'SG1 (shell) the slide grip is shown at the drawn centre; a drag '
      'edge-snaps while object snap is on and is one undo step; with F3 off '
      'it stores the grid point projected; under runtime permissions the '
      'grip is not hit', (tester) async {
    late ({Handle a, Handle door, Handle nofit, double o1, double o2}) s;
    final c = openingController(
        openingPlanText(shellPage, (d) => s = addClampedDoor(d)));
    final doc = c.document;
    final f = oracleFrameOf(doc, s.a);
    await pumpEditor(tester, c, centre: plan(2000, 0), scale: 0.15);
    final cut = OpeningOracle(doc).cut(paramsOf(doc, s.door))!;
    final stored = paramsOf(doc, s.door);

    // Select the door: a click on its leaf, on the right, away from the
    // stem.
    await tapWorld(tester, c, oracleAt(f, cut.a, f.ro - 450));
    expect(c.selection.keys, [k(s.door)]);
    final g = objectGripsOf(c, s.door).single;
    expect((Vector2(g.x, g.y) - oracleAt(f, cut.a + 450, 0)).length,
        lessThan(1e-6),
        reason: 'at the cut\'s centre');

    // F3 on: the right edge released ~25 mm short of the obstacle's near
    // edge snaps onto it (the aperture is ~67 mm).
    final target = oracleAt(f, s.o1 - 450 - 25, 30);
    await dragWorld(tester, c, Vector2(g.x, g.y), target);
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
    final g2 = objectGripsOf(c, s.door).single;
    await dragWorld(tester, c, Vector2(g2.x, g2.y), target);
    await tester.pump();
    expect(doc.commands.undoDepth, 1);
    expect(paramsOf(doc, s.door).position,
        closeTo(oracleU(f, gridOf(doc, target)), 1e-6));
    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.pump();

    // Runtime: the grip is not hit.
    final g3 = objectGripsOf(c, s.door).single;
    final m = cameraOf(c).value.worldToScreenMatrix;
    final at = cameraOf(c).value.worldToScreen(Vector2(g3.x, g3.y));
    expect(c.grips.hitTest(Offset(at.x, at.y), m), isNot(-1));
    doc.commands.permissions = DraftPermissions.runtime;
    expect(c.grips.hitTest(Offset(at.x, at.y), m), -1);
  });

  testWidgets(
      'SG2 (M-08i) a body drag on a selected door starts nothing and adds '
      'nothing to the history, and no rotation grip is drawn for it; a wall '
      'selected with its door moves, and the door follows through '
      'regeneration with its stored position unchanged', (tester) async {
    late Handle a, door, win;
    final c = openingController(openingPlanText(shellPage, (d) {
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
    }));
    final doc = c.document;
    final f = oracleFrameOf(doc, a);
    await pumpEditor(tester, c, centre: plan(2500, 0), scale: 0.15);
    final before = enc(doc);
    final params = {door: paramsOf(doc, door), win: paramsOf(doc, win)};
    final nodes = {door: doc.tree[door], win: doc.tree[win]};

    // The door alone: its leaf runs from the hinge (the cut's end, on the
    // right face) 900 away from the band.
    final leaf = oracleAt(f, 1730 + 450, f.ro - 450);
    await tapWorld(tester, c, leaf);
    expect(c.selection.keys, [k(door)]);
    expect(c.grips.box, isNotNull);
    expect(c.grips.rotatable, isFalse, reason: 'no rotation grip');
    await dragWorld(tester, c, leaf, leaf + (plan(700, 300) - plan(0, 0)));
    await tester.pump();
    expect(doc.commands.undoDepth, 0, reason: 'nothing in the history');
    expect(enc(doc), before, reason: 'nothing moved');
    expect(c.selection.keys, [k(door)], reason: 'still a click');

    // The wall and its door: the wall moves, the door follows.
    final body = oracleAt(f, 800, -100);
    await tapWorld(tester, c, body, shift: true);
    expect(c.selection.keys.toSet(), {k(door), k(a)});
    expect(c.grips.rotatable, isTrue);
    final t0 = doc.tree.accumulatedTransform(a);
    final lines = {
      for (final o in [door, win]) o: worldLines(doc, o)
    };
    await dragWorld(tester, c, body, body + (plan(640, -410) - plan(0, 0)));
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

  testWidgets(
      'SG4 (rv11-fillMovable) a root fill and a door selected together draw '
      'no rotation grip: a fill has no outline, so it is not the movable key '
      'the grip needs; a fill and a wall do (Task 11 review m2)',
      (tester) async {
    late Handle a, door, fill;
    final c = openingController(openingPlanText(shellPage, (d) {
      a = d.handleSeed.next();
      d.commands.execute(
          addWall(d, a, plan(0, 0), plan(5000, 0), 200, Justification.right));
      door = d.handleSeed.next();
      d.commands.execute(addOpening(
          d, door, OpeningParams(a, 1730, 900, OpeningKind.door),
          at: doorGroup));
      final ring = [plan(0, 2000), plan(900, 2000), plan(900, 2700)];
      final region = AddRegionCommand.allocate(
          seed: d.handleSeed,
          owner: d.rootHandle,
          boundaryKind: EntityKind.polyline,
          boundaryPayload: GeometryPayload(
              coords: Float64List.fromList([
                for (final q in [...ring, ring.first]) ...[q.x, q.y]
              ]),
              scalars: Float64List(0)),
          layer: ReservedHandles.layerZero,
          fillColor: const ByLayerColor(),
          boundaryColor: const ByLayerColor());
      fill = region.fill.handle;
      d.commands.execute(region);
    }));
    await pumpEditor(tester, c, centre: plan(2500, 0), scale: 0.15);
    c.selection.replace([k(fill), k(door)]);
    await tester.pump();
    expect(c.grips.box, isNotNull, reason: 'the door has an outline');
    expect(c.grips.rotatable, isFalse, reason: 'a fill and a door');
    c.selection.replace([k(fill), k(a)]);
    await tester.pump();
    expect(c.grips.rotatable, isTrue, reason: 'the control: a fill and a wall');
  });
}
