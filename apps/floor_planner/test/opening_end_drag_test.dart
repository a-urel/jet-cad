// Spec 08 D13: where an opening goes when its host changes. An end grip
// drag (`WallGrips.drag`) that moves a wall's stored `start` and not its
// `end` rewrites each of that wall's openings to `p′ = L′ − (L − p)` in the
// same compound, so it keeps its distance from the end that did not move;
// a drag of the end alone keeps the positions, and so do a whole-wall move
// and rotate. Every wall is at the far origin in its own rotated group, no
// host is axis-aligned, no opening is central, and some openings sit in
// their own rotated, translated groups. Expected symbols come from
// `support/opening_fixture.dart`'s oracles, which never call
// `opening_geometry.dart`.
import 'dart:math' as math;

import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/opening_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:floor_planner/parametric/wall_grips.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart';
import 'support/wall_fixture.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

const hA = Handle(1300), hB = Handle(2600), hC = Handle(2700);
const hD = Handle(4000), hW = Handle(4100), hE = Handle(4200);
const hF = Handle(4300);

const Map<String, int> noViolations = {
  'overlap': 0,
  'hole': 0,
  'pieceInGap': 0,
  'pieceOutside': 0,
  'gapOutside': 0,
};

/// An opening's own group, rotated and translated off the identity.
final Transform2 ownGroup = Transform2.translation(ox + 1234, oy - 4321)
    .multiply(Transform2.rotation(1.1));

/// Executes [c] and checks the differential oracle: nothing drifts.
void run(DraftDocument doc, DraftCommand c) {
  doc.commands.execute(c);
  expect(driftOf(doc), isEmpty, reason: 'drift after ${c.label}');
}

/// The centreline's group-local length of [p], written out.
double localLength(WallParams p) {
  final dx = p.ex - p.sx, dy = p.ey - p.sy;
  return math.sqrt(dx * dx + dy * dy);
}

/// Opening [o]'s stored position.
double positionOf(DraftDocument doc, Handle o) =>
    doc.components.get<OpeningParams>(o)!.position;

/// Opening [o]'s stored centre in world, by the oracle frame of its host.
Vector2 worldCentre(DraftDocument doc, Handle o) {
  final p = doc.components.get<OpeningParams>(o)!;
  return oracleAt(oracleFrameOf(doc, p.host), p.position, 0);
}

/// Each opening's symbol and each wall's pieces are on the oracles.
void expectOnOracles(DraftDocument doc, String when) {
  final oracle = OpeningOracle(doc);
  for (final o in doc.components.withComponent<OpeningParams>()) {
    if (doc.components.get<OpeningParams>(o)!.kind == OpeningKind.door) {
      expectDoorOnOracle(doc, o, oracle: oracle, reason: '$when: door $o');
    } else {
      expectLinesOnOracle(doc, o, oracle: oracle, reason: '$when: $o');
    }
  }
  for (final w in doc.components.withComponent<WallParams>()) {
    expect(oracle.tilingOf(w), noViolations, reason: '$when: wall $w');
  }
}

/// [a] and [b] agree number for number within [tol].
void expectClose(List<double> a, List<double> b, double tol, String why) {
  expect(a, hasLength(b.length), reason: why);
  for (var i = 0; i < a.length; i++) {
    expect(a[i], closeTo(b[i], tol), reason: '$why: [$i]');
  }
}

/// [c]'s members that set an opening's parameters.
List<SetComponentCommand<OpeningParams>> openingSets(DraftCommand c) => [
      for (final m in (c as CompoundCommand).children)
        if (m is SetComponentCommand<OpeningParams>) m
    ];

/// Opening [o]'s children, each as its handle, kind and payload numbers.
List<Object> childBytes(DraftDocument doc, Handle o) => [
      for (final k in kids(doc, o))
        [
          k.value,
          kindOf(doc, k).name,
          ...payloadOf(doc, k).coords,
          ...payloadOf(doc, k).scalars,
        ],
    ];

void main() {
  test(
      'EP1 (M-08p, M-08p2, X8-first) A and C collinear, back to back, sharing '
      'their starts at N; N dragged 700 mm along the line: every opening on '
      'both walls stays put in world within 1e-6 (centre and symbol), the '
      'stored positions are L′ − (L − p), one undo step, undo exact', () {
    final doc = wallDoc();
    final n = plan(300, -200);
    // A runs from N along the plan's +x (23° in world), C from N the other
    // way: a straight node, each wall in its own rotated group at N.
    run(doc, addSpoke(doc, hA, n, 23, 5000, 200, left, fromHub: true));
    run(doc, addSpoke(doc, hC, n, 203, 4000, 115, right, fromHub: true));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 1300, 900, OpeningKind.door,
                hinge: HingeEnd.end, swing: SwingSide.right)));
    run(
        doc,
        addOpening(
            doc, hW, const OpeningParams(hA, 3100, 1200, OpeningKind.window)));
    run(
        doc,
        addOpening(
            doc,
            hE,
            const OpeningParams(hC, 900, 800, OpeningKind.door,
                swing: SwingSide.left),
            at: ownGroup));
    final openings = [hD, hW, hE];
    expect(diagnosticsOf(doc), isEmpty, reason: 'nothing clamped');
    expectOnOracles(doc, 'placed');

    final grips = WallGrips();
    final g = grips.gripsOf(doc, hA)[0];
    expect((Vector2(g.x, g.y) - n).length, lessThan(1e-6), reason: 'at N');
    final oldA = doc.components.get<WallParams>(hA)!;
    final oldC = doc.components.get<WallParams>(hC)!;
    final centres = {for (final o in openings) o: worldCentre(doc, o)};
    final symbols = {for (final o in openings) o: worldSymbol(doc, o)};
    final old = {for (final o in openings) o: positionOf(doc, o)};
    final before = canon(doc);
    final depth = doc.commands.undoDepth;

    final c = grips.drag(doc, hA, g, polar(n, 23, 700))!;
    final sets = [for (final m in openingSets(c)) m.handle];
    run(doc, c);
    expect(doc.commands.undoDepth, depth + 1);
    final newA = doc.components.get<WallParams>(hA)!;
    final newC = doc.components.get<WallParams>(hC)!;
    expect(newA.end, oldA.end, reason: 'A\'s end did not move');
    expect(newC.end, oldC.end, reason: 'C\'s end did not move');
    expect(localLength(newA), closeTo(4300, 1e-6));
    expect(localLength(newC), closeTo(4700, 1e-6));
    for (final (o, was, now) in [
      (hD, oldA, newA),
      (hW, oldA, newA),
      (hE, oldC, newC),
    ]) {
      expect((worldCentre(doc, o) - centres[o]!).length, lessThan(1e-6),
          reason: 'opening $o: its centre stays put');
      expectClose(worldSymbol(doc, o), symbols[o]!, 1e-6,
          'opening $o: its symbol stays put');
      expect(
          positionOf(doc, o), localLength(now) - (localLength(was) - old[o]!),
          reason: 'opening $o: L′ − (L − p)');
    }
    expect(sets, openings, reason: 'A\'s openings, then C\'s, ascending');
    expect(diagnosticsOf(doc), isEmpty, reason: 'still nothing clamped');
    expectOnOracles(doc, 'dragged');
    final after = canon(doc);

    doc.commands.undo();
    expect(canon(doc), before);
    expect(driftOf(doc), isEmpty);
    doc.commands.redo();
    expect(canon(doc), after);
    expect(driftOf(doc), isEmpty);
  });

  test(
      'EP2 (M-08p2) the end of a lone wall with two openings dragged off its '
      'line: the stored positions are unchanged, exactly, and the compound '
      'holds no SetComponentCommand<OpeningParams>', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-2500, 0), plan(2500, 0), 200, right));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 1400.5, 900, OpeningKind.door,
                hinge: HingeEnd.end),
            at: ownGroup));
    run(
        doc,
        addOpening(
            doc, hW, const OpeningParams(hA, 3600, 1000, OpeningKind.window)));
    final old = {
      for (final o in [hD, hW]) o: positionOf(doc, o)
    };
    final oldA = doc.components.get<WallParams>(hA)!;
    final depth = doc.commands.undoDepth;

    final grips = WallGrips();
    final c = grips.drag(doc, hA, grips.gripsOf(doc, hA)[1], plan(2100, 350))!;
    expect((c as CompoundCommand).children, hasLength(1));
    expect(openingSets(c), isEmpty);
    run(doc, c);
    expect(doc.commands.undoDepth, depth + 1);
    final newA = doc.components.get<WallParams>(hA)!;
    expect(newA.start, oldA.start, reason: 'the start did not move');
    expect(newA.end == oldA.end, isFalse, reason: 'the end moved');
    for (final o in [hD, hW]) {
      expect(positionOf(doc, o), old[o], reason: 'opening $o');
    }
    expect(diagnosticsOf(doc), isEmpty);
    expectOnOracles(doc, 'dragged');
  });

  test(
      'EP3 (M-08p2) an L whose corner is A\'s start and B\'s end, dragged off '
      'the line so both walls swing: A\'s positions are L′ − (L − p) within '
      '1e-9 and keep their world distance from A\'s unmoved end; B\'s are '
      'unchanged, exactly', () {
    final doc = wallDoc();
    final k = plan(-400, 900);
    run(doc, addSpoke(doc, hA, k, 23, 4600, 200, left, fromHub: true));
    run(doc, addSpoke(doc, hB, k, 23 + 100, 3800, 115, right, fromHub: false));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 1500, 900, OpeningKind.door,
                swing: SwingSide.right)));
    run(
        doc,
        addOpening(
            doc, hW, const OpeningParams(hA, 3200, 1000, OpeningKind.window),
            at: ownGroup));
    run(
        doc,
        addOpening(
            doc,
            hE,
            const OpeningParams(hB, 1800, 800, OpeningKind.door,
                hinge: HingeEnd.end)));
    run(
        doc,
        addOpening(
            doc, hF, const OpeningParams(hB, 2900, 600, OpeningKind.gap)));
    expect(diagnosticsOf(doc), isEmpty);
    final oldA = doc.components.get<WallParams>(hA)!;
    final oldB = doc.components.get<WallParams>(hB)!;
    final old = {
      for (final o in [hD, hW, hE, hF]) o: positionOf(doc, o)
    };
    final aEnd = oracleEnd(oracleFrameOf(doc, hA), 1);
    final fromEnd = {
      for (final o in [hD, hW]) o: (worldCentre(doc, o) - aEnd).length
    };
    final depth = doc.commands.undoDepth;

    final grips = WallGrips();
    run(
        doc,
        grips.drag(
            doc,
            hA,
            grips.gripsOf(doc, hA)[0],
            k +
                polar(Vector2.zero(), 23 + 90, 380) +
                polar(Vector2.zero(), 23, 250))!);
    expect(doc.commands.undoDepth, depth + 1);
    final newA = doc.components.get<WallParams>(hA)!;
    final newB = doc.components.get<WallParams>(hB)!;
    expect(newA.end, oldA.end);
    expect(newB.start, oldB.start);
    expect(newA.start == oldA.start || newB.end == oldB.end, isFalse,
        reason: 'the corner moved on both walls');
    expect(
        oracleFrameOf(doc, hA).d.dot(Vector2(
            math.cos(23 * math.pi / 180), math.sin(23 * math.pi / 180))),
        lessThan(1 - 1e-4),
        reason: 'A swung');
    for (final o in [hD, hW]) {
      expect(positionOf(doc, o),
          closeTo(localLength(newA) - (localLength(oldA) - old[o]!), 1e-9),
          reason: 'A\'s opening $o');
      expect((worldCentre(doc, o) - aEnd).length, closeTo(fromEnd[o]!, 1e-6),
          reason: 'A\'s opening $o keeps its distance from A\'s end');
    }
    for (final o in [hE, hF]) {
      expect(positionOf(doc, o), old[o], reason: 'B\'s opening $o');
    }
    expect(diagnosticsOf(doc), isEmpty);
    expectOnOracles(doc, 'swung');
  });

  test(
      'EP4 a whole-wall move and a rotate, as the select tool issues them '
      '(GripDrag): the stored positions are unchanged, exactly; the symbols '
      'move by the vector, then stay on the oracle; each is one undo step', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-2500, 0), plan(2500, 0), 200, left));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 1400, 900, OpeningKind.door,
                hinge: HingeEnd.end, swing: SwingSide.right),
            at: ownGroup));
    run(
        doc,
        addOpening(
            doc, hW, const OpeningParams(hA, 3600, 1000, OpeningKind.window)));
    final old = {
      for (final o in [hD, hW]) o: positionOf(doc, o)
    };
    final lines = {
      for (final o in [hD, hW]) o: worldLines(doc, o)
    };
    final arc = worldArc(doc, hD);
    final key = [SelectionKey.root(hA)];

    // The move.
    final depth = doc.commands.undoDepth;
    final from = plan(0, 60), v = Vector2(1800, -700);
    final move = GripDrag.move(doc, key)!
      ..base.setFrom(from)
      ..moveTo(from + v);
    run(doc, move.command(DraftPermissions.all)!);
    expect(doc.commands.undoDepth, depth + 1);
    for (final o in [hD, hW]) {
      expect(positionOf(doc, o), old[o], reason: 'moved: opening $o');
      final now = worldLines(doc, o);
      expect(now, hasLength(lines[o]!.length));
      for (final (i, (a, b)) in lines[o]!.indexed) {
        expect((now[i].$1 - (a + v)).length, lessThan(1e-6),
            reason: 'moved: opening $o line $i from');
        expect((now[i].$2 - (b + v)).length, lessThan(1e-6),
            reason: 'moved: opening $o line $i to');
      }
    }
    final movedArc = worldArc(doc, hD);
    for (final (got, want) in [
      (movedArc.centre, arc.centre),
      (movedArc.from, arc.from),
      (movedArc.to, arc.to),
    ]) {
      expect((got - (want + v)).length, lessThan(1e-6), reason: 'moved: arc');
    }
    expect(movedArc.radius, closeTo(arc.radius, 1e-6));
    expect(movedArc.sweep, arc.sweep);
    expectOnOracles(doc, 'moved');

    // The rotate, about a point off the wall.
    final hinge = worldLines(doc, hD).single.$1;
    final pivot = plan(700, 2600);
    final rotate = GripDrag.rotate(doc, key, pivot, pivot + Vector2(1000, 0))!
      ..rotateTo(pivot + Vector2(math.cos(0.61), math.sin(0.61)) * 1000,
          step: false);
    run(doc, rotate.command(DraftPermissions.all)!);
    expect(doc.commands.undoDepth, depth + 2);
    for (final o in [hD, hW]) {
      expect(positionOf(doc, o), old[o], reason: 'rotated: opening $o');
    }
    expect((worldLines(doc, hD).single.$1 - hinge).length, greaterThan(100),
        reason: 'the door turned with its host');
    expectOnOracles(doc, 'rotated');
  });

  test(
      'EP5 (X8-refuse) an end drag that shortens a wall past its door keeps '
      'the stored position: nothing is refused, the door is clamped, then '
      'no-fit, and diagnosed; dragging the end back restores its children '
      'byte for byte', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-2500, 0), plan(2500, 0), 200, centre));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 4000.25, 900, OpeningKind.door,
                swing: SwingSide.right),
            at: ownGroup));
    expect(diagnosticsOf(doc), isEmpty);
    final grips = WallGrips();
    final children = childBytes(doc, hD);
    final wall = doc.components.get<WallParams>(hA)!;
    final depth = doc.commands.undoDepth;

    // Shortened to 3,700: the door's stored interval runs past the end, and
    // it is drawn clamped against the square end.
    final shorter =
        grips.drag(doc, hA, grips.gripsOf(doc, hA)[1], plan(-2500 + 3700, 0));
    expect(shorter, isNotNull, reason: 'nothing is refused');
    run(doc, shorter!);
    expect(positionOf(doc, hD), 4000.25);
    expect(
        localLength(doc.components.get<WallParams>(hA)!), closeTo(3700, 1e-6));
    final cut = OpeningOracle(doc).cut(doc.components.get<OpeningParams>(hD)!)!;
    expect(cut.clamped, isTrue);
    expect(cut.b, closeTo(3700, 1e-6));
    expect([for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'],
        ['opening.clamped [$hD]']);
    expectOnOracles(doc, 'clamped');

    // Shortened to 700: no stretch holds 900, so the door is no-fit.
    final tiny =
        grips.drag(doc, hA, grips.gripsOf(doc, hA)[1], plan(-2500 + 700, 0));
    expect(tiny, isNotNull, reason: 'nothing is refused');
    run(doc, tiny!);
    expect(positionOf(doc, hD), 4000.25);
    expect(
        OpeningOracle(doc).cut(doc.components.get<OpeningParams>(hD)!), isNull);
    expect([for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'],
        ['opening.nofit [$hD]']);
    expectOnOracles(doc, 'no-fit');
    expect(doc.commands.undoDepth, depth + 2);

    // Back to the world point the wall was drawn to: the grip takes it into
    // the wall's group as `addWall` did, so the stored end comes back
    // bitwise (the grip's own world point would not: world to local and
    // back loses ulps at the far origin).
    run(doc, grips.drag(doc, hA, grips.gripsOf(doc, hA)[1], plan(2500, 0))!);
    expect(doc.components.get<WallParams>(hA), wall,
        reason: 'the stored end comes back exactly');
    expect(doc.commands.undoDepth, depth + 3);
    expect(positionOf(doc, hD), 4000.25);
    expect(childBytes(doc, hD), children);
    expect(diagnosticsOf(doc), isEmpty);
  });
  test(
      'EP5 (start) a 5,000 wall shortened from its start to 1,500, with a door '
      'at 600.5 and a window at 3,900: nothing is refused, the positions are '
      'L′ − (L − p) (the door\'s negative: legal, D6), both are clamped and '
      'overlap, the wall keeps a piece; dragging the start back restores the '
      'positions and the wall exactly (Task 8 review m2)', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-2500, 0), plan(2500, 0), 200, centre));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 600.5, 900, OpeningKind.door,
                hinge: HingeEnd.end),
            at: ownGroup));
    run(
        doc,
        addOpening(
            doc, hW, const OpeningParams(hA, 3900, 1200, OpeningKind.window)));
    expect(diagnosticsOf(doc), isEmpty);
    final wall = doc.components.get<WallParams>(hA)!;
    final l = localLength(wall);
    final depth = doc.commands.undoDepth;
    final grips = WallGrips();

    final shorter =
        grips.drag(doc, hA, grips.gripsOf(doc, hA)[0], plan(2500 - 1500, 0));
    expect(shorter, isNotNull, reason: 'nothing is refused');
    run(doc, shorter!);
    expect(doc.commands.undoDepth, depth + 1);
    final now = doc.components.get<WallParams>(hA)!;
    expect(now.end, wall.end, reason: 'the end did not move');
    final l2 = localLength(now);
    expect(l2, closeTo(1500, 1e-6));
    expect(positionOf(doc, hD), l2 - (l - 600.5));
    expect(positionOf(doc, hW), l2 - (l - 3900));
    expect(positionOf(doc, hD), lessThan(0), reason: 'before the start');
    expect([
      for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'
    ], [
      'opening.clamped [$hD]',
      'opening.overlap [$hD, $hW]',
      'opening.clamped [$hW]',
    ]);
    expect(centrelineHandles(doc, hA), isNotEmpty, reason: 'a piece is kept');
    expectOnOracles(doc, 'shortened from the start');

    // Back to the world point the wall was drawn from (see EP5).
    run(doc, grips.drag(doc, hA, grips.gripsOf(doc, hA)[0], plan(-2500, 0))!);
    expect(doc.commands.undoDepth, depth + 2);
    expect(doc.components.get<WallParams>(hA), wall,
        reason: 'the stored start comes back exactly');
    expect(positionOf(doc, hD), 600.5);
    expect(positionOf(doc, hW), 3900.0);
    expect(diagnosticsOf(doc), isEmpty);
    expectOnOracles(doc, 'dragged back');
  });

  test(
      'EP6 (rv8-noLive) a start drag rewrites only live openings: a stray '
      'OpeningParams naming the wall on a group nested under a plain root '
      'group, and one on a handle with no node, are left alone (Task 8 '
      'review m1)', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-2500, 0), plan(2500, 0), 200, left));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 1400.5, 900, OpeningKind.door,
                hinge: HingeEnd.end)));
    // Built by hand: no tool or file path makes these.
    const plain = Handle(5000), nested = Handle(5100), bare = Handle(5200);
    const stray = OpeningParams(hA, 2600.25, 700, OpeningKind.window);
    const loose = OpeningParams(hA, 3300.75, 600, OpeningKind.gap);
    run(
        doc,
        CompoundCommand([
          AddNodeCommand(GroupNode(
              handle: plain,
              parent: doc.rootHandle,
              transform: Transform2.identity(),
              children: const [])),
          AddNodeCommand(GroupNode(
              handle: nested,
              parent: plain,
              transform: Transform2.identity(),
              children: const [])),
          SetComponentCommand<OpeningParams>(nested, stray),
          SetComponentCommand<OpeningParams>(bare, loose),
        ], label: 'Add strays'));
    expect(doc.tree[nested], isA<GroupNode>());
    expect(doc.tree[bare], isNull, reason: 'no node');
    expect(doc.components.get<OpeningParams>(nested), stray);
    expect(doc.components.get<OpeningParams>(bare), loose);
    final old = positionOf(doc, hD);
    final l = localLength(doc.components.get<WallParams>(hA)!);

    final grips = WallGrips();
    final c = grips.drag(doc, hA, grips.gripsOf(doc, hA)[0], plan(-2000, 0))!;
    expect([for (final m in openingSets(c)) m.handle], [hD],
        reason: 'the live door only');
    run(doc, c);
    final l2 = localLength(doc.components.get<WallParams>(hA)!);
    expect(positionOf(doc, hD), l2 - (l - old));
    expect(doc.components.get<OpeningParams>(nested), stray,
        reason: 'the nested stray is unchanged');
    expect(doc.components.get<OpeningParams>(bare), loose,
        reason: 'the node-less stray is unchanged');
  });

  test(
      'EP7 (t12-keptOld) 200 free walls, each with a door flush against its '
      'far end (stored with storedCentreOf, undiagnosed), each start grip '
      'dragged once: no door is left opening.clamped; a re-seated door is '
      'within wallJoin.linear of L′ − (L − p), which would have been '
      'clamped (Task 11 review I1)', () {
    final doc = wallDoc();
    final grips = WallGrips();
    final hosts = <Handle>[], doors = <Handle>[];
    for (var i = 0; i < 200; i++) {
      final a = doc.handleSeed.next();
      final len = 3000 + 13.37 * i, deg = 0.9 * (i % 7);
      final s = plan(311.5 * (i % 3), 1000.0 * i);
      run(doc, addWall(doc, a, s, polar(s, 23 + deg, len), 200, left));
      final door = doc.handleSeed.next();
      final w = 700 + 3.3 * i;
      final stretches = layoutInDocument(doc, a)!.stretches;
      final (_, end) = stretches.last;
      final c =
          storedCentreOf(stretches, (a: end - w, b: end, clamped: true), w);
      run(
          doc,
          addOpening(doc, door,
              OpeningParams(a, c, w, OpeningKind.door, hinge: HingeEnd.end),
              at: i.isEven ? ownGroup : null));
      hosts.add(a);
      doors.add(door);
    }
    expect(diagnosticsOf(doc), isEmpty, reason: 'placed flush, unclamped');

    final oldRule = <Handle, double>{};
    for (final (i, a) in hosts.indexed) {
      final f = oracleFrameOf(doc, a);
      final was = doc.components.get<WallParams>(a)!;
      final p = positionOf(doc, doors[i]);
      // Lengthened or shortened along the line, and off it on odd walls.
      final u = i.isEven ? -417.3 - 3.1 * i : 211.7 + 2.9 * i;
      final g = grips.gripsOf(doc, a)[0];
      run(doc, grips.drag(doc, a, g, oracleAt(f, u, i.isEven ? 0 : 37.5))!);
      final now = doc.components.get<WallParams>(a)!;
      oldRule[doors[i]] = localLength(now) - (localLength(was) - p);
    }
    final clamped = [
      for (final d in diagnosticsOf(doc))
        if (d.code == 'opening.clamped') d,
    ];
    expect(clamped, hasLength(0), reason: 'no door left clamped by rounding');

    var reseated = 0;
    for (final door in doors) {
      final kept = positionOf(doc, door), old = oldRule[door]!;
      expect(kept, closeTo(old, wallJoin.linear),
          reason: 'door $door: L′ − (L − p)');
      if (kept == old) continue;
      reseated++;
      // The old rule's value is clamped: it was re-seated for a reason.
      final params = doc.components.get<OpeningParams>(door)!;
      run(
          doc,
          SetComponentCommand<OpeningParams>(
              door, params.copyWith(position: old)));
      expect(
          diagnosticsOf(doc).where(
              (d) => d.code == 'opening.clamped' && d.handles.contains(door)),
          isNotEmpty,
          reason: 'door $door: L′ − (L − p) is clamped');
      doc.commands.undo();
    }
    // ignore: avoid_print
    print('EP7: $reseated of ${doors.length} doors re-seated');
    expect(reseated, greaterThan(20), reason: 'the fixture is not degenerate');
  });

  test(
      'EP8 (rv12-seatWide) a door flush against its wall\'s START stretch '
      'end, the start dragged 0.5 mm inward along the line, on 12 walls: '
      'L′ − (L − p) clamps the door by 0.5 mm, far more than rounding, so '
      'it is kept there exactly and diagnosed opening.clamped, not '
      're-seated (Task 12 review P5)', () {
    final grips = WallGrips();
    for (var i = 0; i < 12; i++) {
      final doc = wallDoc();
      final a = doc.handleSeed.next();
      final len = 3000 + 13.37 * i, deg = 23 + 0.9 * (i % 7);
      final s = plan(311.5 * (i % 3), 1000.0 * i);
      run(
          doc,
          addWall(doc, a, s, polar(s, deg, len), 200 - 7.5 * i,
              [left, centre, right][i % 3]));
      final w = 700 + 3.3 * i;
      final stretches = layoutInDocument(doc, a)!.stretches;
      final (start, _) = stretches.first;
      final door = doc.handleSeed.next();
      run(
          doc,
          addOpening(
              doc,
              door,
              OpeningParams(
                  a,
                  storedCentreOf(
                      stretches, (a: start, b: start + w, clamped: true), w),
                  w,
                  OpeningKind.door,
                  swing: i.isEven ? SwingSide.left : SwingSide.right),
              at: i.isEven ? ownGroup : null));
      expect(diagnosticsOf(doc), isEmpty, reason: 'wall $i: flush, unclamped');
      final was = doc.components.get<WallParams>(a)!;
      final p = positionOf(doc, door);
      final f = oracleFrameOf(doc, a);

      run(doc,
          grips.drag(doc, a, grips.gripsOf(doc, a)[0], oracleAt(f, 0.5, 0))!);
      final now = doc.components.get<WallParams>(a)!;
      expect(now.end, was.end, reason: 'wall $i: the end did not move');
      expect(localLength(now), closeTo(localLength(was) - 0.5, 1e-6));
      final kept = localLength(now) - (localLength(was) - p);
      expect(positionOf(doc, door), kept,
          reason: 'wall $i: L′ − (L − p), exactly: not re-seated');
      final cut =
          OpeningOracle(doc).cut(doc.components.get<OpeningParams>(door)!)!;
      expect(cut.clamped, isTrue);
      expect(cut.a - (kept - w / 2), closeTo(0.5, 1e-6),
          reason: 'wall $i: clamped by the half millimetre');
      expect([
        for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'
      ], [
        'opening.clamped [$door]'
      ], reason: 'wall $i');
    }
  });

  test(
      'EP9 (rv12-movedHostOnly) 24 Ls whose corner is A\'s start and B\'s '
      'end, A\'s door flush against the corner (stored with storedCentreOf, '
      'undiagnosed), the corner dragged out along A\'s line: every door is '
      'kept at L′ − (L − p) exactly and undiagnosed. The re-seat reads A\'s '
      'stretches with B\'s NEW end, joined at the new corner; B\'s old end '
      'would be a T in A\'s lengthened band whose far edge is the door\'s, '
      'give or take rounding, and would re-seat some (Task 12 review m1)', () {
    final grips = WallGrips();
    var wouldReseat = 0;
    for (var i = 0; i < 24; i++) {
      final doc = wallDoc();
      final k = plan(-400 + 97.3 * i, 900 - 41.1 * i);
      final deg = 23 + 0.9 * (i % 7);
      final js = [left, centre, right];
      run(doc, addSpoke(doc, hA, k, deg, 4600, 200, js[i % 3], fromHub: true));
      run(
          doc,
          addSpoke(
              doc, hB, k, deg + 95 + 2.5 * (i % 5), 3800, 115, js[(i ~/ 3) % 3],
              fromHub: false));
      final stretches = layoutInDocument(doc, hA)!.stretches;
      final (start, _) = stretches.first;
      final w = 700 + 3.3 * i;
      run(
          doc,
          addOpening(
              doc,
              hD,
              OpeningParams(
                  hA,
                  storedCentreOf(
                      stretches, (a: start, b: start + w, clamped: true), w),
                  w,
                  OpeningKind.door,
                  hinge: HingeEnd.start,
                  swing: i.isEven ? SwingSide.right : SwingSide.left),
              at: i.isEven ? ownGroup : null));
      expect(diagnosticsOf(doc), isEmpty, reason: 'L $i: flush, unclamped');
      final oldA = doc.components.get<WallParams>(hA)!;
      final oldB = doc.components.get<WallParams>(hB)!;
      final p = positionOf(doc, hD);
      final g = grips.gripsOf(doc, hA)[0];
      final to = polar(k, deg + 180, 300 + 7.3 * i);

      // A's stretches as B's old end would make them, from the drag's own
      // walls: a T in A's lengthened band, clamping the door by rounding
      // when its start falls below the T's far edge.
      final c = grips.drag(doc, hA, g, to)!;
      final newA = (c as CompoundCommand)
          .children
          .whereType<SetComponentCommand<WallParams>>()
          .firstWhere((m) => m.handle == hA)
          .value!;
      final hostOnly = layoutInDocument(doc, hA, moved: {
        hA: WorldWall(hA, newA, doc.tree.accumulatedTransform(hA)),
      })!
          .stretches;
      expect(hostOnly, hasLength(2), reason: 'L $i: B\'s old end, a T in A');
      final kept = localLength(newA) - (localLength(oldA) - p);
      final wrong = placeCut(hostOnly, kept, w)!;
      expect((wrong.a - (kept - w / 2)).abs(), lessThan(wallJoin.linear),
          reason: 'L $i: flush against the T\'s far edge');
      if (wrong.clamped) wouldReseat++;

      expect([for (final m in openingSets(c)) m.handle], [hD]);
      run(doc, c);
      final newB = doc.components.get<WallParams>(hB)!;
      expect(newB.start, oldB.start, reason: 'L $i');
      expect(newB.end == oldB.end, isFalse, reason: 'L $i: B\'s end moved');
      expect(layoutInDocument(doc, hA)!.stretches, hasLength(1),
          reason: 'L $i: B joins A at the new corner');
      expect(positionOf(doc, hD), kept,
          reason: 'L $i: L′ − (L − p), exactly: not re-seated');
      expect(diagnosticsOf(doc), isEmpty, reason: 'L $i');
      expectOnOracles(doc, 'L $i dragged');
    }
    // ignore: avoid_print
    print('EP9: $wouldReseat of 24 doors clamped by B\'s old end');
    expect(wouldReseat, greaterThan(3),
        reason: 'the fixture is not degenerate');
  });
}
