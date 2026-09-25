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
import 'package:floor_planner/parametric/wall.dart';
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
    expect(sets, openings,
        reason: 'A\'s openings, then C\'s, ascending, after the walls');
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
}
