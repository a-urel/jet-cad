// Ported from jet_cad_floor_plan/test/opening_grips_test.dart (spec 3a C3.3, C7).
// Spec 08 D16, D15: an opening's slide grip, the composite provider, and
// no select-tool move or rotate for an opening. Every wall is at the far
// origin in its own rotated group, the plan is turned 23 degrees, the camera
// is rotated, and the door's own group is off the identity. Expected
// positions come from `support/opening_fixture.dart`'s oracles, which never
// call `opening_geometry.dart`.
import 'package:jet_cad_2d_kit_architecture/src/box/box.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/live.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_grips.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_geometry.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_grips.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/opening_fixture.dart';
import '../support/wall_fixture.dart';

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

/// Whether [h] is diagnosed `opening.clamped`.
bool clamped(DraftDocument doc, Handle h) => diagnosticsOf(doc)
    .any((d) => d.code == 'opening.clamped' && d.handles.contains(h));

/// SG6's composite (R14-7): the plan library's grip dispatch (spec 2a E1)
/// over the kit's two providers, by the type id that names the group. A
/// group no provider takes (a box: it has no grips) is movable, as today's
/// composite's default (`object_grips.dart:102-104`).
final class _Dispatch implements ObjectGripProvider {
  _Dispatch(DraftDocument doc)
      : _live = liveOf(doc),
        _openings = OpeningGrips(live: liveOf(doc)),
        _walls = WallGrips(live: liveOf(doc));

  final LiveTypeOf _live;
  final OpeningGrips _openings;
  final WallGrips _walls;

  ObjectGripProvider? _of(Handle group) => switch (_live(group)) {
        ArchitectureTypes.opening => _openings,
        ArchitectureTypes.wall => _walls,
        _ => null,
      };

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) =>
      _of(group)?.gripsOf(d, group) ?? const [];

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      _of(group)?.drag(d, group, grip, world);

  @override
  List<(EntityKind, GeometryPayload)> preview(
          DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      _of(group)?.preview(d, group, grip, world) ?? const [];

  @override
  bool movable(DraftDocument d, Handle group) =>
      _of(group)?.movable(d, group) ?? true;
}

void main() {
  test(
      'SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a '
      'clamped door\'s grip '
      'sits at its cut\'s centre, a no-fit\'s at its stored centre; a drag '
      'projects, edge-snaps to an obstacle edge, and stores the placed '
      'centre, the clamped one where it is drawn and a no-fit one clamped '
      'to the wall; with no aperture there is no edge snap; a drag back to '
      'the start is null; a 30 mm nudge inside the aperture moves it', () {
    final doc = wallDoc();
    final (:a, :door, :nofit, :o1, :o2) = addClampedDoor(doc);
    final f = oracleFrameOf(doc, a);
    final oracle = OpeningOracle(doc);
    final cut = oracle.cut(paramsOf(doc, door))!;
    expect(cut.clamped, isTrue);
    expect(cut.a, closeTo(o2, 1e-6), reason: 'drawn from the obstacle');
    expect(oracle.cut(paramsOf(doc, nofit)), isNull);
    // What the wall draws: the stretch end the grip snaps to, exactly.
    final [(_, e0), (s1, _)] = layoutInDocument(doc, a, liveOf(doc))!.stretches;
    expect(e0, closeTo(o1, 1e-6));
    expect(s1, closeTo(o2, 1e-6));

    double? aperture = 20;
    final objects =
        OpeningGrips(live: liveOf(doc), edgeAperture: () => aperture);
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

    // A 30 mm nudge inside the aperture moves the door: its own edges are
    // never candidates (Task 11 review m1).
    doc.commands.execute(SetComponentCommand<OpeningParams>(
        door, paramsOf(doc, door).copyWith(position: 1000)));
    aperture = 67;
    final at1000 = objects.gripsOf(doc, door).single;
    final nudge = objects.drag(doc, door, at1000, oracleAt(f, 1030, 20));
    expect(nudge, isNotNull, reason: 'the nudge moves it');
    doc.commands.execute(nudge!);
    expect(paramsOf(doc, door).position, closeTo(1030, 1e-6));
  });

  test(
      'SG1 (t11-apertureDir, the grip\'s site) on a host scaled '
      'non-uniformly the slide grip\'s aperture is measured along its '
      'centreline: an edge 19.9 mm (in world) from a neighbour\'s edge '
      'snaps onto it, one 20.1 mm away does not (Task 14 F1)', () {
    final doc = wallDoc();
    final h = doc.handleSeed.next();
    doc.commands.execute(addWall(
        doc, h, plan(0, 0), plan(4000, 0), 200, Justification.centre,
        at: groupAt(h.value).multiply(Transform2.scale(2, 0.5))));
    final p = doc.components.get<WallParams>(h)!;
    final local = (Vector2(p.ex, p.ey) - Vector2(p.sx, p.sy)).length;
    final f = oracleFrameOf(doc, h);
    // World mm per local unit along the centreline: far from the group's
    // geometric mean scale, 1, so √|det| would be the wrong divisor.
    final k = f.len / local;
    expect((k - 1).abs(), greaterThan(0.2), reason: 'k = $k');
    // A 600 (local) window, unclamped, 60% along: its left edge is the
    // only candidate near the door; the door, 600 (local) wide, starts 20%
    // along, and its own cut is never a candidate.
    final wc = 0.6 * local;
    final door = doc.handleSeed.next();
    doc.commands.execute(addOpening(
        doc, door, OpeningParams(h, 0.2 * local, 600, OpeningKind.door),
        at: doorGroup));
    doc.commands.execute(addOpening(doc, doc.handleSeed.next(),
        OpeningParams(h, wc, 600, OpeningKind.window)));
    doc.commands.clearHistory();
    expect(diagnosticsOf(doc), isEmpty);

    // A 20 mm aperture in world. The door dragged, on the centreline (the
    // group does not keep right angles, so a point off it would project
    // elsewhere in local space), to where its right edge is `world` mm (in
    // world) short of the window's left edge.
    final objects = OpeningGrips(live: liveOf(doc), edgeAperture: () => 20);
    final g = objects.gripsOf(doc, door).single;
    for (final (world, snaps) in [(19.9, true), (20.1, false)]) {
      final u = wc - 300 - 300 - world / k;
      doc.commands.execute(objects.drag(doc, door, g, oracleAt(f, u * k, 0))!);
      expect(paramsOf(doc, door).position, closeTo(snaps ? wc - 600 : u, 1e-6),
          reason: '$world mm in world');
      doc.commands.undo();
    }
  });

  test(
      'SG5 (rv12-gripNoFit) a no-fit window dragged to within '
      'wallJoin.linear of its stored centre, either side, edge snaps on and '
      'off: no command, since no-fit is not drawn clamped; 2e-6 away it '
      'moves (Task 12 review m4)', () {
    final doc = wallDoc();
    final (:a, :door, :nofit, :o1, :o2) = addClampedDoor(doc);
    final f = oracleFrameOf(doc, a);
    expect(OpeningOracle(doc).cut(paramsOf(doc, nofit)), isNull);
    expect(paramsOf(doc, nofit).position, 4000);
    double? aperture;
    final objects =
        OpeningGrips(live: liveOf(doc), edgeAperture: () => aperture);
    final g = objects.gripsOf(doc, nofit).single;
    for (final ap in [null, 20.0]) {
      aperture = ap;
      for (final du in [5e-7, -5e-7]) {
        expect(objects.drag(doc, nofit, g, oracleAt(f, 4000 + du, 30)), isNull,
            reason: 'aperture $ap, $du off');
      }
    }
    aperture = null;
    final c = objects.drag(doc, nofit, g, oracleAt(f, 4000 + 2e-6, 30));
    expect(c, isNotNull, reason: 'beyond the tolerance it moves');
    doc.commands.execute(c!);
    expect(paramsOf(doc, nofit).position, closeTo(4000 + 2e-6, 1e-8));
  });

  test(
      'SG3 (t12-gripOld) a door drawn clamped by 1e-7 (by hand) is re-seated '
      'by a drag onto its own edge: after it, it is stored where it is drawn '
      'and not diagnosed (Task 11 review I1)', () {
    // By hand: 1e-7 below the obstacle's far edge, which it is drawn on.
    final doc = wallDoc();
    final (:a, :door, :nofit, :o1, :o2) = addClampedDoor(doc);
    final f = oracleFrameOf(doc, a);
    final edge = layoutInDocument(doc, a, liveOf(doc))!.stretches[1].$1;
    expect(edge, closeTo(o2, 1e-6));
    doc.commands.execute(SetComponentCommand<OpeningParams>(
        door, paramsOf(doc, door).copyWith(position: edge + 450 - 1e-7)));
    doc.commands.clearHistory();
    expect(clamped(doc, door), isTrue, reason: 'clamped by 1e-7');
    final objects = OpeningGrips(live: liveOf(doc), edgeAperture: () => 20);
    final g = objects.gripsOf(doc, door).single;
    final c = objects.drag(doc, door, g, oracleAt(f, edge + 450 + 5, 30));
    expect(c, isNotNull, reason: 'the drag re-seats it');
    doc.commands.execute(c!);
    expect(doc.commands.undoDepth, 1);
    expect(clamped(doc, door), isFalse, reason: 'stored where it is drawn');
    expect(paramsOf(doc, door).position, closeTo(edge + 450, 1e-9));
  });

  test(
      'SG3 (t12-gripOld, old D13) a door left an ulp outside its stretch by '
      'the old D13 rewrite L′ − (L − p) is re-seated by a drag onto its own '
      'edge: after it, it is stored where it is drawn and not diagnosed '
      '(Task 11 review I1)', () {
    // The old D13 rewrite: a door flush against a free wall's far end, the
    // start dragged, and the door stored at L′ − (L − p), as a file saved
    // before the fix holds it. The first wall where that is clamped.
    for (var i = 0; i < 40; i++) {
      final doc = wallDoc();
      final objects = OpeningGrips(live: liveOf(doc), edgeAperture: () => 20);
      final a = doc.handleSeed.next();
      final s = plan(0, 0);
      final len = 3000 + 13.37 * i, w = 700 + 3.3 * i;
      doc.commands.execute(addWall(doc, a, s, polar(s, 23 + 0.9 * (i % 7), len),
          200, Justification.left));
      final stretches = layoutInDocument(doc, a, liveOf(doc))!.stretches;
      final (_, end) = stretches.last;
      final door = doc.handleSeed.next();
      doc.commands.execute(addOpening(
          doc,
          door,
          OpeningParams(
              a,
              storedCentreOf(stretches, (a: end - w, b: end, clamped: true), w),
              w,
              OpeningKind.door),
          at: doorGroup));
      final was = doc.components.get<WallParams>(a)!;
      final p = paramsOf(doc, door).position;
      final walls = WallGrips(live: liveOf(doc));
      doc.commands.execute(walls.drag(doc, a, walls.gripsOf(doc, a)[0],
          oracleAt(oracleFrameOf(doc, a), -417.3 - 3.1 * i, 0))!);
      final now = doc.components.get<WallParams>(a)!;
      final old =
          (now.end - now.start).length - ((was.end - was.start).length - p);
      doc.commands.execute(SetComponentCommand<OpeningParams>(
          door, paramsOf(doc, door).copyWith(position: old)));
      doc.commands.clearHistory();
      if (!clamped(doc, door)) continue;

      // Onto its own right edge, 3 mm along from where it is drawn.
      final f = oracleFrameOf(doc, a);
      final g = objects.gripsOf(doc, door).single;
      final u = oracleU(f, Vector2(g.x, g.y));
      final c = objects.drag(doc, door, g, oracleAt(f, u + 3, -40));
      expect(c, isNotNull, reason: 'wall $i: the drag re-seats it');
      doc.commands.execute(c!);
      expect(clamped(doc, door), isFalse, reason: 'wall $i: re-seated');
      expect(paramsOf(doc, door).position, closeTo(old, wallJoin.linear));
      expect(paramsOf(doc, door).position, isNot(old));
      return;
    }
    fail('no wall of the 40 is left clamped by L′ − (L − p)');
  });

  test(
      'SG6 (own-defaultMovable) a 06 box is movable through the composite: '
      'selected with a door, a move takes the box and skips the door, and a '
      'rotate is offered; a wall is movable, a door is not (Task 14 review '
      'Minor 1)', () {
    final doc = wallDoc();
    final a = doc.handleSeed.next();
    doc.commands.execute(
        addWall(doc, a, plan(0, 0), plan(5000, 0), 200, Justification.right));
    final door = doc.handleSeed.next();
    doc.commands.execute(addOpening(
        doc, door, OpeningParams(a, 1730, 900, OpeningKind.door),
        at: doorGroup));
    final box = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: box,
          parent: doc.rootHandle,
          transform: groupAt(box.value),
          children: const [])),
      SetComponentCommand<BoxParams>(box, const BoxParams(1200, 800)),
    ], label: 'Add box'));
    doc.commands.clearHistory();
    final objects = _Dispatch(doc);

    expect(objects.movable(doc, box), isTrue, reason: 'a box');
    expect(objects.movable(doc, a), isTrue, reason: 'a wall');
    expect(objects.movable(doc, door), isFalse, reason: 'a door');

    final t0 = doc.tree.accumulatedTransform(box);
    final keys = [k(box), k(door)];
    final from = plan(1000, 1500), v = Vector2(730, -410);
    final move = GripDrag.move(doc, keys, objects: objects);
    expect(move, isNotNull, reason: 'the box is left to move');
    move!
      ..base.setFrom(from)
      ..moveTo(from + v);
    final doorBefore = paramsOf(doc, door);
    final doorNode = doc.tree[door];
    doc.commands.execute(move.command(DraftPermissions.all)!);
    final t1 = doc.tree.accumulatedTransform(box);
    expect(t1.e - t0.e, closeTo(v.x, 1e-6), reason: 'the box moved');
    expect(t1.f - t0.f, closeTo(v.y, 1e-6), reason: 'the box moved');
    expect(paramsOf(doc, door), doorBefore, reason: 'the door is skipped');
    expect(doc.tree[door], doorNode, reason: 'its group untouched');
    expect(
        GripDrag.rotate(doc, keys, from, from + v, objects: objects), isNotNull,
        reason: 'the box can be rotated');
    expect(driftOf(doc), isEmpty);
  });

  test(
      'SG7 (fr-X8) the slide grip reads the host\'s admission: of two '
      'windows that together cover a free 2,000 wall, the higher-handle one '
      'yields (keep-a-piece) and is no-fit; its grip sits at its stored '
      'centre, not where it would be drawn alone, and a drag within the '
      'tolerance of it issues nothing', () {
    final doc = wallDoc();
    final a = doc.handleSeed.next();
    doc.commands.execute(addWall(doc, a, plan(-1000, 2600), plan(1000, 2600),
        200, Justification.centre));
    final kept = doc.handleSeed.next();
    doc.commands.execute(addOpening(
        doc, kept, OpeningParams(a, 450, 900, OpeningKind.window),
        at: doorGroup));
    final yielded = doc.handleSeed.next();
    doc.commands.execute(addOpening(
        doc, yielded, OpeningParams(a, 1650, 1100, OpeningKind.window)));
    final f = oracleFrameOf(doc, a);
    expect(f.len, closeTo(2000, 1e-6));
    final oracle = OpeningOracle(doc);
    final alone = oracle.cut(paramsOf(doc, yielded))!;
    expect(alone.a, closeTo(900, 1e-6), reason: 'alone: clamped to the end');
    expect([for (final (h, c) in oracle.cutsOn(a)) (h, c != null)],
        [(kept, true), (yielded, false)]);
    expect(
        diagnosticsOf(doc).any(
            (d) => d.code == 'opening.nofit' && d.handles.contains(yielded)),
        isTrue);

    final grips = OpeningGrips(live: liveOf(doc), edgeAperture: () => null);
    final gk = grips.gripsOf(doc, kept).single;
    expect((Vector2(gk.x, gk.y) - oracleAt(f, 450, 0)).length, lessThan(1e-6));
    final g = grips.gripsOf(doc, yielded).single;
    expect((Vector2(g.x, g.y) - oracleAt(f, 1650, 0)).length, lessThan(1e-6),
        reason: 'at the stored centre, not ${(alone.a + alone.b) / 2}');
    for (final du in [5e-7, -5e-7]) {
      expect(grips.drag(doc, yielded, g, oracleAt(f, 1650 + du, 30)), isNull,
          reason: 'no-fit is not drawn clamped: $du');
    }
  });

  test(
      'OT-grips (spec 3a C3.3, R14-4) the type\'s grip factory reads the '
      'services: with object snap on the slide grip edge-snaps within the '
      'snap aperture at the camera\'s scale (10 px at 0.5 px/mm: 20 mm), '
      'with it off it does not; the door is not movable', () {
    final doc = wallDoc();
    final s = addClampedDoor(doc);
    final (a, door, o1) = (s.a, s.door, s.o1);
    final f = oracleFrameOf(doc, a);
    final [(_, e0), _] = layoutInDocument(doc, a, liveOf(doc))!.stretches;
    final on =
        FakePlanServices(document: doc, catalog: testCatalog(), scale: 0.5);
    addTearDown(on.dispose);
    final off = FakePlanServices(
        document: doc, catalog: testCatalog(), scale: 0.5, objectSnap: false);
    addTearDown(off.dispose);
    final snapping = openingPlanType.gripsFor(on)!;
    final plain = openingPlanType.gripsFor(off)!;
    expect(snapping.movable(doc, door), isFalse);
    expect(snapping.movable(doc, a), isTrue, reason: 'control');
    final g = snapping.gripsOf(doc, door).single;
    // The right edge released 15 mm short of the obstacle's near edge:
    // inside 20 mm, so it snaps; 25 mm short: outside, the projection.
    final near = oracleAt(f, o1 - 450 - 15, 40);
    doc.commands.execute(snapping.drag(doc, door, g, near)!);
    expect(paramsOf(doc, door).position + 450, closeTo(e0, 1e-9),
        reason: 'snapped');
    doc.commands.undo();
    doc.commands.execute(plain.drag(doc, door, g, near)!);
    expect(paramsOf(doc, door).position, closeTo(o1 - 465, 1e-6),
        reason: 'object snap off: the projection');
    doc.commands.undo();
    doc.commands
        .execute(snapping.drag(doc, door, g, oracleAt(f, o1 - 450 - 25, 40))!);
    expect(paramsOf(doc, door).position, closeTo(o1 - 475, 1e-6),
        reason: '25 mm: beyond the aperture');
  });
}
