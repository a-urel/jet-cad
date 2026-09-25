// SPIKE 08 -- throwaway. Q1 (references in the closure) and Q2 (cascade
// delete) on the real ParametricSystem, at the far origin, walls in rotated
// groups.
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';
import 'support.dart';

const hA = Handle(1300), hB = Handle(2600), hC = Handle(3000);
const hD = Handle(4000), hW = Handle(4100);

void run(DraftDocument doc, DraftCommand c) {
  doc.commands.execute(c);
  expect(driftOf(doc), isEmpty, reason: 'drift after ${c.label}');
}

DraftCommand deleteLikeSelectTool(DraftDocument doc, Handle g) =>
    CompoundCommand([
      for (final k in kids(doc, g))
        if (kindOf(doc, k) != EntityKind.fill) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

DraftCommand moveBy(DraftDocument doc, Handle h, double dx, double dy) =>
    TransformNodeCommand(
        h,
        Transform2.translation(dx, dy)
            .multiply(doc.tree.accumulatedTransform(h)));

bool overlaps(Aabb2 a, Aabb2 b) =>
    a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY;

/// A 5,000 mm wall, 200 left-justified, in its own rotated group at the
/// far origin, carrying a door at 1,400 (non-central, 900 wide, hinged at
/// the end, swinging right) and a window at 3,600 (1,200 wide).
DraftDocument doorWall() {
  final doc = wallDoc();
  run(doc, addWall(doc, hA, plan(-2500, 0), plan(2500, 0), 200, left));
  run(
      doc,
      addOpening(
          doc,
          hD,
          const OpeningParams(hA, 1400, 900, OpeningKind.door,
              hinge: HingeEnd.end, swing: SwingSide.right)));
  run(
      doc,
      addOpening(
          doc, hW, const OpeningParams(hA, 3600, 1200, OpeningKind.window)));
  return doc;
}

/// The door's hinge, leaf tip and arc centre, world, by an independent
/// oracle from the host's stored parameters.
({Vector2 hinge, Vector2 tip}) doorOracle(
    DraftDocument doc, Handle wall, OpeningParams o) {
  final f = oracleFrame(doc, wall);
  final uh = o.hinge == HingeEnd.start
      ? o.position - o.width / 2
      : o.position + o.width / 2;
  final (off, sgn) = o.swing == SwingSide.left ? (f.lo, 1.0) : (f.ro, -1.0);
  final hinge = f.s + f.d * uh + f.n * off;
  return (hinge: hinge, tip: hinge + f.n * (sgn * o.width));
}

void expectDoorAt(DraftDocument doc, Handle door, {String? reason}) {
  final o = doc.components.get<OpeningParams>(door)!;
  final want = doorOracle(doc, o.host, o);
  final leaf = worldPoints(doc, door, EntityKind.line).single;
  expect((leaf[0] - want.hinge).length, lessThan(1e-6), reason: reason);
  expect((leaf[1] - want.tip).length, lessThan(1e-6), reason: reason);
  final arc = worldPoints(doc, door, EntityKind.arc).single;
  expect((arc[0] - want.hinge).length, lessThan(1e-6), reason: reason);
}

void expectCut(DraftDocument doc, Handle wall, List<(double, double)> gaps,
    {String? reason}) {
  final pieces = worldPieces(doc, wall);
  expect(pieces, hasLength(gaps.length + 1), reason: reason);
  final v = tiling(uncutOutline(doc, wall), pieces,
      [for (final (a, b) in gaps) gapRect(doc, wall, a, b)]);
  expect(
      v,
      {
        'overlap': 0,
        'hole': 0,
        'pieceInGap': 0,
        'pieceOutside': 0,
        'gapOutside': 0
      },
      reason: reason);
}

void main() {
  test('Q1a moving the wall FAR moves its door and window, one undo step', () {
    final doc = doorWall();
    expectDoorAt(doc, hD, reason: 'before');
    expectCut(doc, hA, [(950, 1850), (3000, 4200)], reason: 'before');
    final beforeReach = const WallType().reach(
        doc.components.get<WallParams>(hA)!, doc.tree.accumulatedTransform(hA));
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    final leaf0 = worldPoints(doc, hD, EntityKind.line).single;

    run(doc, moveBy(doc, hA, 60000, -45000));
    final afterReach = const WallType().reach(
        doc.components.get<WallParams>(hA)!, doc.tree.accumulatedTransform(hA));
    expect(overlaps(beforeReach, afterReach), isFalse);
    expect(doc.commands.undoDepth, depth + 1);
    expectDoorAt(doc, hD, reason: 'after');
    expectCut(doc, hA, [(950, 1850), (3000, 4200)], reason: 'after');
    final leaf1 = worldPoints(doc, hD, EntityKind.line).single;
    expect(
        (leaf1[0] - leaf0[0] - Vector2(60000, -45000)).length, lessThan(1e-6));
    final after = canon(doc);

    doc.commands.undo();
    expect(canon(doc), before);
    expect(driftOf(doc), isEmpty);
    doc.commands.redo();
    expect(canon(doc), after);
    expect(driftOf(doc), isEmpty);
  });

  test(
      'Q1b save -> load -> save is byte-identical; the same edit on the '
      'original and on its reload gives the same bytes', () {
    final doc = doorWall();
    final s = enc(doc);
    final back = reload(s);
    expect(enc(back), s);
    expect(back.components.get<OpeningParams>(hD),
        doc.components.get<OpeningParams>(hD));
    expect(driftOf(back), isEmpty);
    for (final d in [doc, back]) {
      run(d, moveBy(d, hA, 1234.5, -77));
      run(
          d,
          SetComponentCommand<OpeningParams>(hD,
              d.components.get<OpeningParams>(hD)!.copyWith(position: 2111)));
    }
    expect(enc(back), enc(doc));
  });

  test('Q1c editing the door regenerates its wall (M-08d)', () {
    final doc = doorWall();
    final o = doc.components.get<OpeningParams>(hD)!;
    run(doc,
        SetComponentCommand<OpeningParams>(hD, o.copyWith(position: 2000)));
    expectDoorAt(doc, hD);
    expectCut(doc, hA, [(1550, 2450), (3000, 4200)]);
    doc.commands.undo();
    expectCut(doc, hA, [(950, 1850), (3000, 4200)], reason: 'undo');
  });

  test(
      'Q1d the two-hop case: B joined to A moves; A\'s door, clamped at '
      'A\'s mitre, follows', () {
    final doc = wallDoc();
    // A 200 centre into the node, B 115 left out of it at 67°.
    final hub = plan(0, 0);
    run(doc, addWall(doc, hA, plan(-3000, 0), hub, 200, centre));
    run(doc, addWall(doc, hB, hub, polar(hub, 180 - 67 + 23, 2500), 115, left));
    // Stored at 2,700: cut [2,300, 3,100], past the node; drawn clamped.
    run(
        doc,
        addOpening(
            doc, hD, const OpeningParams(hA, 2700, 800, OpeningKind.door)));
    final clamped =
        diagnosticsOf(doc).where((d) => d.code == 'opening.clamped');
    expect(clamped.single.handles, [hD]);
    final leaf0 = worldPoints(doc, hD, EntityKind.line).single;
    // Swing B's far end: the mitre on A moves, so does the clamp.
    final pb = doc.components.get<WallParams>(hB)!;
    final toLocal = doc.tree.accumulatedTransform(hB).invert();
    final newEnd = toLocal.transformPoint(polar(hub, 180 - 40 + 23, 2500));
    doc.commands
        .execute(SetComponentCommand<WallParams>(hB, pb.copyWith(end: newEnd)));
    expect(driftOf(doc), isEmpty, reason: 'the door is two hops from B');
    final leaf1 = worldPoints(doc, hD, EntityKind.line).single;
    expect((leaf1[0] - leaf0[0]).length, greaterThan(1),
        reason: 'the clamp moved');
  });

  test(
      'Q1e the two-hop case the other way: A\'s door edited; B (joined to '
      'A) need not regenerate', () {
    final doc = wallDoc();
    final hub = plan(0, 0);
    run(doc, addWall(doc, hA, plan(-3000, 0), hub, 200, centre));
    run(doc, addWall(doc, hB, hub, polar(hub, 180 - 67 + 23, 2500), 115, left));
    run(
        doc,
        addOpening(
            doc, hD, const OpeningParams(hA, 1100, 800, OpeningKind.door)));
    final bKids = [for (final k in kids(doc, hB)) enc2(doc, k)];
    run(
        doc,
        SetComponentCommand<OpeningParams>(hD,
            doc.components.get<OpeningParams>(hD)!.copyWith(position: 2600)));
    expect([for (final k in kids(doc, hB)) enc2(doc, k)], bKids);
    expect(driftOf(doc), isEmpty);
  });

  test(
      'Q2a deleting the wall (select-tool compound) deletes its openings, '
      'one undo step; undo restores both with the same handles; redo; purge',
      () async {
    final doc = doorWall();
    // A neighbour, so a regrow is part of the same step: C joined to A's
    // end at 110°.
    final end = worldWallOf(doc, hA).e;
    run(doc, addWall(doc, hC, end, polar(end, 23 + 110, 2000), 150, right));
    final before = canon(doc, sortNodes: true);
    final kidsBefore = {
      for (final h in [hA, hC, hD, hW]) h: kids(doc, h)
    };
    final depth = doc.commands.undoDepth;

    doc.commands.execute(deleteLikeSelectTool(doc, hA));
    await Future<void>.delayed(Duration.zero);
    for (final h in [hA, hD, hW]) {
      expect(doc.tree[h], isNull, reason: '$h');
      expect(kids(doc, h), isEmpty, reason: '$h');
    }
    expect(doc.components.get<OpeningParams>(hD), isNull);
    expect(doc.components.get<OpeningParams>(hW), isNull);
    expect(doc.components.get<WallParams>(hA), isNull);
    expect(driftOf(doc), isEmpty);
    expect(worldOutline(doc, hC), hasLength(4), reason: 'C regrew a free cap');
    expect(doc.commands.undoDepth, depth + 1);
    final after = canon(doc, sortNodes: true);

    doc.commands.undo();
    expect(canon(doc, sortNodes: true), before);
    for (final e in kidsBefore.entries) {
      expect(kids(doc, e.key), e.value, reason: '${e.key}');
    }
    expect(driftOf(doc), isEmpty);
    doc.commands.redo();
    expect(canon(doc, sortNodes: true), after);
    doc.commands.undo();
    doc.purge();
    expect(canon(doc, sortNodes: true), before);
    for (final e in kidsBefore.entries) {
      expect(kids(doc, e.key), e.value, reason: 'purge ${e.key}');
    }
    expect(driftOf(doc), isEmpty);
  });

  test('Q2b deleting only the door regenerates the wall whole again', () {
    final doc = doorWall();
    run(doc, deleteLikeSelectTool(doc, hD));
    expect(doc.tree[hA], isNotNull);
    expectCut(doc, hA, [(3000, 4200)]);
    doc.commands.undo();
    expectCut(doc, hA, [(950, 1850), (3000, 4200)]);
  });

  test('Q2c a bare RemoveNodeCommand of the wall node (children left)', () {
    final doc = doorWall();
    doc.commands.execute(RemoveNodeCommand(hA));
    // ignore: avoid_print
    print('Q2c after a bare RemoveNodeCommand(A): A node ${doc.tree[hA]}, '
        'A children ${kids(doc, hA)}, D node ${doc.tree[hD]}, '
        'W node ${doc.tree[hW]}, A params '
        '${doc.components.get<WallParams>(hA)}, drift ${driftOf(doc)}');
    doc.commands.undo();
    expect(driftOf(doc), isEmpty);
    expect(doc.tree[hD], isNotNull);
  });
}

String enc2(DraftDocument doc, Handle k) =>
    '${kindOf(doc, k)} ${payloadOf(doc, k).coords} ${payloadOf(doc, k).scalars}';
