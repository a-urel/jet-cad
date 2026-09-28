// SPIKE 11 -- throwaway. Q3: how the Dimension tool learns that a snapped
// point is wall W's (k, side) point. The real SpatialIndex snap over the
// sample plan (nine walls, fifteen openings), then two ways to match:
// (A) the snap's root wall only, (B) every wall whose stored geometry's box
// holds the point (an index rect query). Both re-derive from the point.
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support.dart';

/// The root-level group a snap hit: `chain[0]` when the hit is inside a
/// block instance, else the owner of the hit entity. `SnapResult.chain` is
/// the **instance** path only: for a wall's child (owned by the wall's
/// root-level group, no instance above it) `chainLength` is 0.
Handle rootOf(DraftDocument doc, SnapResult res) => res.chainLength > 0
    ? Handle(res.chain[0])
    : doc.entities.ownerAt(doc.entities.slotOf(res.entity)!);

/// One snap near [target] (offset by [jitter] mm): the snapped world point,
/// its kind, its chain length and its root-level group ([rootOf]).
({Vector2 point, SnapKind kind, Handle root, int chainLength})? snapNear(
    DraftDocument doc, SpatialIndex index, Vector2 target, Vector2 jitter,
    {double aperture = 50}) {
  final res = SnapResult();
  index.snapInto(target + jitter, aperture, kDragSnapMask, res);
  if (!res.found) return null;
  return (
    point: Vector2.copy(res.point),
    kind: res.kind,
    root: rootOf(doc, res),
    chainLength: res.chainLength,
  );
}

/// (A): the snap's root wall only.
List<WorldWall> chainOnly(DraftDocument doc, Handle root) => [
      for (final w in allWorldWalls(doc))
        if (w.handle == root) w,
    ];

/// (B): every wall with a stored child whose box holds [q] within [tol].
List<WorldWall> byIndex(
    DraftDocument doc, SpatialIndex index, Vector2 q, double tol) {
  final owners = <int>{};
  index.forEachInRect(
      Aabb2.raw(q.x - tol, q.y - tol, q.x + tol, q.y + tol),
      const QueryFilter.rendering(),
      (slot) => owners.add(doc.entities.ownerAt(slot).value));
  return [
    for (final w in allWorldWalls(doc))
      if (owners.contains(w.handle.value)) w,
  ];
}

void main() {
  for (final place in [origin, corpusGroups, km1000Groups]) {
    test('Q3a every wall end point of the sample plan, snapped, $place', () {
      final plan =
          buildPlan(sampleWalls(), openings: sampleOpenings, place: place);
      final doc = plan.doc;
      final index = SpatialIndex(doc);
      final all = allWorldWalls(doc);
      final rnd = math.Random(3);
      var worst = 0.0;
      final tallyA = <String, int>{}, tallyB = <String, int>{};
      final kinds = <SnapKind, int>{};
      for (final w in all) {
        for (final (k, side, p) in wallEndPoints(w, othersOf(w, all))) {
          final a = rnd.nextDouble() * 2 * math.pi;
          final jitter = Vector2(math.cos(a), math.sin(a)) * 5;
          final s = snapNear(doc, index, p, jitter)!;
          kinds[s.kind] = (kinds[s.kind] ?? 0) + 1;
          expect(s.chainLength, 0);
          worst = math.max(worst, (s.point - p).length);
          final want = AttachedEnd(w.handle, k, side);
          // The canonical choice among every coincident wall end point.
          final canonical = attachAt(p, all, all)!;
          final coincident = [
            for (final (e, _) in attachMatches(p, all, all)) e
          ];
          String outcome(AttachedEnd? got) => got == null
              ? 'fixed'
              : got == want
                  ? 'same (wall, k, side)'
                  : got == canonical
                      ? 'a coincident point, canonical'
                      : coincident.contains(got)
                          ? 'a coincident point, not canonical'
                          : 'other: $got for $want';
          final ga = attachAt(s.point, chainOnly(doc, s.root), all);
          final gb = attachAt(
              s.point, byIndex(doc, index, s.point, kAttachTolerance), all);
          tallyA[outcome(ga)] = (tallyA[outcome(ga)] ?? 0) + 1;
          tallyB[outcome(gb)] = (tallyB[outcome(gb)] ?? 0) + 1;
          expect(gb, canonical, reason: '$want snapped at ${s.point}');
        }
      }
      index.dispose();
      // ignore: avoid_print
      print('Q3a $place: ${all.length * 6} points; snap kinds $kinds; '
          'worst |snapped - computed| $worst mm\n'
          '  (A) chain only: $tallyA\n  (B) index rect: $tallyB');
      expect(worst, lessThan(kAttachTolerance));
    });
  }

  test('Q3b a jamb corner (a piece vertex, none of the six) is fixed', () {
    for (final place in [origin, corpusGroups]) {
      final plan =
          buildPlan(sampleWalls(), openings: sampleOpenings, place: place);
      final doc = plan.doc;
      final index = SpatialIndex(doc);
      final all = allWorldWalls(doc);
      // The front door in E1 (position 6375, width 1000): its jambs at
      // u = 5875 and 6875 from E1's start x = 12,125, so x = 18,000 and
      // 19,000; E1's inner face y = 8,125 + 125 = 8,250.
      final jamb = place.at(18000, 8250);
      final s = snapNear(doc, index, jamb, Vector2(3, -2))!;
      expect((s.point - jamb).length, lessThan(1e-5));
      expect(attachAt(s.point, chainOnly(doc, s.root), all), isNull);
      expect(
          attachAt(s.point, byIndex(doc, index, s.point, 1e-5), all), isNull);
      // ignore: avoid_print
      print('Q3b $place: jamb snapped ${s.kind.name}, root ${s.root.value} '
          '(${doc.components.get<WallParams>(s.root) != null ? 'a wall' : 'not a wall'}): '
          'fixed under (A) and (B)');
      index.dispose();
    }
  });

  test('Q3c an X crossing is an intersection snap, fixed', () {
    final plan = buildPlan(
        const [W(0, 0, 4000, 0, 200), W(2000, -2000, 2000, 2000, 200)],
        place: corpusGroups);
    final doc = plan.doc;
    final index = SpatialIndex(doc);
    final all = allWorldWalls(doc);
    // The crossing of A's left face and B's left face: (1900, 100). No
    // vertex there, and the engine's intersection snap considers
    // root-level entities only (`_considerIntersections`), so a wall's
    // children never produce one: nothing snaps, the click is a raw (or
    // grid) point, fixed. Even an exact click there matches nothing.
    final q = plan.at(1900, 100);
    final s = snapNear(doc, index, q, Vector2(2, 2));
    // ignore: avoid_print
    print(
        'Q3c X crossing: snap ${s == null ? 'none' : '${s.kind.name} at ${s.point}'}');
    expect(s, isNull);
    expect(attachAt(q, all, all), isNull);
    index.dispose();
  });

  test(
      'Q3d the Y lobe vertex and the T butt: chain-only depends on '
      'which entity the snap reported', () {
    // The Y (corner_test C7): A 0°, B 120°, C 240°; (-115.470, 0) is on
    // A's ring (A owns the lobe) but is B/0/left and C/0/right.
    final y = buildPlan([
      const W(0, 0, 3000, 0, 200),
      W(0, 0, 3000 * math.cos(2 * math.pi / 3),
          3000 * math.sin(2 * math.pi / 3), 200),
      W(0, 0, 3000 * math.cos(4 * math.pi / 3),
          3000 * math.sin(4 * math.pi / 3), 200),
    ], place: corpusGroups);
    final all = allWorldWalls(y.doc);
    final q = y.at(-200 / math.sqrt(3), 0);
    final [a, b, c] = y.walls;
    String show(AttachedEnd? e) => e == null ? 'fixed' : '$e';
    final lines = <String>[];
    for (final root in [a, b, c]) {
      lines.add('root ${root.value}: '
          '${show(attachAt(q, chainOnly(y.doc, root), all))}');
    }
    final index = SpatialIndex(y.doc);
    final s = snapNear(y.doc, index, q, Vector2(1, 1))!;
    final viaIndex =
        attachAt(s.point, byIndex(y.doc, index, s.point, 1e-5), all);
    index.dispose();
    lines.add('snap reported ${s.root.value} (${s.kind.name}); (B): '
        '${show(viaIndex)}');
    expect(attachAt(q, chainOnly(y.doc, a), all), isNull);
    expect(attachAt(q, chainOnly(y.doc, b), all),
        AttachedEnd(b, 0, WallSide.left));
    expect(viaIndex, AttachedEnd(b, 0, WallSide.left));

    // The T (C5): the butt corner (2450, 100) is the stem's S/0/left; it is
    // not a vertex of the through wall's ring.
    final t = buildPlan(
        const [W(0, 0, 6000, 0, 200), W(2500, 0, 2500, 3000, 100)],
        place: corpusGroups);
    final tall = allWorldWalls(t.doc);
    final [cw, sw] = t.walls;
    final butt = t.at(2450, 100);
    final ringC = outline(tall[0], [tall[1]]).ring;
    expect(ringC.every((p) => (p - butt).length > 1), isTrue);
    final ti = SpatialIndex(t.doc);
    final ts = snapNear(t.doc, ti, butt, Vector2(-2, 3))!;
    lines.add('T butt: snap reported ${ts.root.value} (${ts.kind.name}); '
        'root C: ${show(attachAt(butt, chainOnly(t.doc, cw), tall))}; '
        'root S: ${show(attachAt(butt, chainOnly(t.doc, sw), tall))}; (B): '
        '${show(attachAt(ts.point, byIndex(t.doc, ti, ts.point, 1e-5), tall))}');
    ti.dispose();
    expect(attachAt(butt, chainOnly(t.doc, cw), tall), isNull);
    expect(attachAt(butt, chainOnly(t.doc, sw), tall),
        AttachedEnd(sw, 0, WallSide.left));
    // ignore: avoid_print
    print('Q3d\n  ${lines.join('\n  ')}');
  });

  test(
      'Q3e an L corner: both walls hold it; the stored wall matters only '
      'once the joint breaks or a wall is deleted', () {
    final plan = buildPlan(
        const [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)],
        place: corpusGroups);
    final doc = plan.doc;
    attachPage(
        doc, PageComponent().copyWith(displayUnit: DisplayUnit.millimeters));
    final [a, b] = plan.walls;
    final all = allWorldWalls(doc);
    final corner = plan.at(3900, 100);
    expect(attachAt(corner, all, all), AttachedEnd(a, 1, WallSide.left));
    // Two dimensions from A's free start (0, 100) to the corner, one
    // stored on A/1/left, one on B/0/left.
    final onA = addDimension(doc, AttachedEnd(a, 0, WallSide.left),
        AttachedEnd(a, 1, WallSide.left));
    final onB = addDimension(doc, AttachedEnd(a, 0, WallSide.left),
        AttachedEnd(b, 0, WallSide.left));
    expect([dimText(doc, onA), dimText(doc, onB)], ['3900', '3900']);
    // B moved 500 mm east, off A's end: the joint breaks. A's end is free,
    // (4000, 100): 4000; B's start is free, B's left face x = 4400,
    // y = 0: from (0, 100), sqrt(4400² + 100²) = 4401.136...
    final bp = doc.components.get<WallParams>(b)!;
    final inv = doc.tree.accumulatedTransform(b).invert();
    final s = inv.transformPoint(plan.at(4500, 0));
    final e = inv.transformPoint(plan.at(4500, 3000));
    doc.commands.execute(
        SetComponentCommand<WallParams>(b, bp.copyWith(start: s, end: e)));
    expect(dimText(doc, onA), '4000');
    expect(dimText(doc, onB), '4401');
    expect(math.sqrt(4400 * 4400 + 100 * 100), closeTo(4401.136, 1e-3));
    // Deleting B deletes onB only.
    doc.commands.execute(deleteObject(doc, b));
    expect(doc.tree[onB], isNull);
    expect(doc.tree[onA], isNotNull);
  });

  test('Q3f resolveDragPoint leaves the hit in the caller\'s scratch', () {
    final plan = buildPlan(
        const [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)],
        place: corpusGroups);
    final index = SpatialIndex(plan.doc);
    final scratch = SnapResult();
    final out = DragPoint();
    resolveDragPoint(
        raw: plan.at(3903, 98),
        orthoBase: null,
        index: index,
        apertureWorld: 50,
        objectSnap: true,
        page: null,
        gridStepMm: null,
        scratch: scratch,
        out: out);
    expect(out.objectKind, SnapKind.endpoint);
    expect(scratch.found, isTrue);
    expect(scratch.chainLength, 0);
    expect(plan.walls, contains(rootOf(plan.doc, scratch)));
    // ignore: avoid_print
    print('Q3f DragPoint ${out.point} (${out.objectKind!.name}); the scratch '
        'still holds entity ${scratch.entity.value} (chain length '
        '${scratch.chainLength}), owned by wall ${rootOf(plan.doc, scratch).value}');
    index.dispose();
  });

  test('Q3g cost of (B) on the sample plan', () {
    final plan =
        buildPlan(sampleWalls(), openings: sampleOpenings, place: corpusGroups);
    final doc = plan.doc;
    final index = SpatialIndex(doc);
    final q = plan.at(12250, 8250); // E1/E4's inner corner
    final sw = Stopwatch()..start();
    const runs = 2000;
    for (var i = 0; i < runs; i++) {
      final all = allWorldWalls(doc);
      attachAt(q, byIndex(doc, index, q, 1e-5), all);
    }
    sw.stop();
    // ignore: avoid_print
    print('Q3g (B) per click, 9 walls, 15 openings: '
        '${(sw.elapsedMicroseconds / runs).toStringAsFixed(2)} us (JIT)');
    index.dispose();
  });
}
