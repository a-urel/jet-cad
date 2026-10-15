// Ported from jet_cad_floor_plan/test/opening_symbol_test.dart (spec 3a C3.3, C7).
// Spec 08 D10-D12: the openings' symbols, through the real ParametricSystem
// (and, for OR8, the shell's select tool). Every wall is at the far origin
// in its own rotated group (`groupAt`), no host is axis-aligned, no opening
// is central, and OR7's openings sit in their own rotated, translated
// groups. Expected symbols come from `support/opening_fixture.dart`'s
// oracles (`OpeningOracle.door`, `OpeningOracle.lines`), which never call
// `opening_geometry.dart`: a frame written out from the host's stored
// parameters and its group's transform, over the oracle's own cut.

import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/opening_fixture.dart';
import '../support/wall_fixture.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

const hA = Handle(1300);
const hD = Handle(4000), hE = Handle(4050), hW = Handle(4100);
const hG = Handle(4200);

/// Executes [c] and checks the differential oracle: nothing drifts.
void run(DraftDocument doc, DraftCommand c) {
  doc.commands.execute(c);
  expect(driftOf(doc), isEmpty, reason: 'drift after ${c.label}');
}

/// World point [q]'s offset along [f]'s left normal.
double offsetOf(OracleFrame f, Vector2 q) =>
    (q.x - f.s.x) * f.n.x + (q.y - f.s.y) * f.n.y;

/// Wall [h]'s three children are 07's (fill, boundary, centreline), and
/// each payload is, bit for bit, what 07 stores for it in [uncutTwin].
void expectUncutLikeTwin(DraftDocument doc, Handle h, {String? reason}) {
  final twin = uncutTwin(doc);
  final mine = kids(doc, h), theirs = kids(twin, h);
  expect([
    for (final k in mine) kindOf(doc, k)
  ], [
    EntityKind.fill,
    EntityKind.polyline,
    EntityKind.polyline
  ], reason: reason);
  expect(mine, theirs, reason: reason);
  for (var i = 0; i < mine.length; i++) {
    expect(payloadOf(doc, mine[i]).coords, payloadOf(twin, theirs[i]).coords,
        reason: '$reason: child $i');
  }
}

void main() {
  test(
      'OG7 (M-08u, X6-nofitdoor) no-fit, per kind, on a rotated 200 '
      'left-justified 800 wall: the wall is 07\'s, bit for bit the twin\'s; '
      'the window\'s lines lie at lOff + t, lOff + t/2 and lOff over the '
      'stored interval, the gap\'s at lOff + t/2 inset by m, the doors\' on '
      'their swing sides; nothing is strictly inside the band; a door made '
      'no-fit by shortening its host keeps its two child handles', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-400, -1200), plan(400, -1200), 200, left));
    final openings = {
      hW: const OpeningParams(hA, 330, 1000, OpeningKind.window),
      hG: const OpeningParams(hA, 520, 900, OpeningKind.gap),
      hD: const OpeningParams(hA, 300, 950, OpeningKind.door,
          hinge: HingeEnd.end, swing: SwingSide.right),
      hE: const OpeningParams(hA, 450, 1000, OpeningKind.door),
    };
    for (final MapEntry(key: h, value: o) in openings.entries) {
      run(doc, addOpening(doc, h, o));
    }
    final f = oracleFrameOf(doc, hA);
    expect(f.len, closeTo(800, 1e-6));
    const t = 200.0;
    expect((f.lo, f.ro), (t, 0.0));
    final oracle = OpeningOracle(doc);
    for (final h in openings.keys) {
      expect(oracle.drawn(h).fits, isFalse, reason: 'no-fit ${h.toHex()}');
      // Not degenerate: no opening is centred on the wall.
      expect((openings[h]!.position - f.len / 2).abs(), greaterThan(40));
    }
    expect([
      for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'
    ], [
      for (final h
          in openings.keys.toList()..sort((x, y) => x.value.compareTo(y.value)))
        'opening.nofit [$h]'
    ]);

    // The wall is uncut: 07's three children, the twin's bytes.
    expectUncutLikeTwin(doc, hA, reason: 'uncut');

    // The window: three lines, by coordinates, over the stored interval
    // [−170, 830], outside the band against its left face.
    expectLinesOnOracle(doc, hW);
    final window = worldLines(doc, hW);
    expect(window, hasLength(3));
    for (final (i, off) in [(0, t + t), (1, t + t / 2), (2, t)]) {
      final (a, b) = window[i];
      expect(offsetOf(f, a), closeTo(off, 1e-6), reason: 'window line $i');
      expect(offsetOf(f, b), closeTo(off, 1e-6), reason: 'window line $i');
      expect(oracleU(f, a), closeTo(-170, 1e-6), reason: 'window line $i');
      expect(oracleU(f, b), closeTo(830, 1e-6), reason: 'window line $i');
    }

    // The gap: one line at lOff + t/2, over [70, 970] inset by
    // m = min(t/4, w/4) = 50.
    expectLinesOnOracle(doc, hG);
    final [(ga, gb)] = worldLines(doc, hG);
    expect(offsetOf(f, ga), closeTo(t + t / 2, 1e-6));
    expect(offsetOf(f, gb), closeTo(t + t / 2, 1e-6));
    expect(oracleU(f, ga), closeTo(70 + 50, 1e-6));
    expect(oracleU(f, gb), closeTo(970 - 50, 1e-6));

    // The doors: D10's symbol over the stored interval, on the swing side:
    // off the right face (offset 0) for hD, off the left face (t) for hE.
    for (final (h, side) in [(hD, -1), (hE, 1)]) {
      expectDoorOnOracle(doc, h);
      for (final q in symbolSamples(doc, h)) {
        final v = offsetOf(f, q);
        expect(side < 0 ? v <= 1e-6 : v >= t - 1e-6, isTrue,
            reason: '${h.toHex()}: $v off the swing side');
      }
    }

    // Nothing of any symbol lies strictly inside the uncut band.
    final band = worldOutline(doc, hA);
    for (final h in openings.keys) {
      final inside = [
        for (final q in symbolSamples(doc, h))
          if (strictlyInsideRing(q, band)) q
      ];
      expect(inside, isEmpty, reason: '${h.toHex()} inside the band');
    }

    // A fitting door made no-fit by shortening its host keeps its two child
    // handles (D10: the child count is fixed by the kind).
    final doc2 = wallDoc();
    run(doc2,
        addWall(doc2, hA, plan(-1500, 1300), plan(1500, 1300), 200, left));
    run(
        doc2,
        addOpening(
            doc2,
            hD,
            const OpeningParams(hA, 1100, 900, OpeningKind.door,
                swing: SwingSide.right)));
    expect(OpeningOracle(doc2).drawn(hD).fits, isTrue);
    expectDoorOnOracle(doc2, hD, reason: 'fitting');
    final before = kids(doc2, hD);
    expect(before, hasLength(2));
    final p = doc2.components.get<WallParams>(hA)!;
    final depth = doc2.commands.undoDepth;
    run(
        doc2,
        SetComponentCommand<WallParams>(
            hA, p.copyWith(end: p.start + (p.end - p.start) * (700 / 3000))));
    expect(doc2.commands.undoDepth, depth + 1);
    expect(oracleFrameOf(doc2, hA).len, closeTo(700, 1e-6));
    expect(OpeningOracle(doc2).drawn(hD).fits, isFalse);
    expect(kids(doc2, hD), before, reason: 'the same two handles');
    expectDoorOnOracle(doc2, hD, reason: 'no-fit');
    expectUncutLikeTwin(doc2, hA, reason: 'shortened');
    doc2.commands.undo();
    expect(kids(doc2, hD), before);
    expectDoorOnOracle(doc2, hD, reason: 'undone');
    expect(driftOf(doc2), isEmpty);
  });

  test(
      'OG10 (X6-hinge, X6-face, X6-sweep) four non-central 700 doors on a '
      'right-justified 200 wall at the far origin, one per hinge × swing: '
      'the hinge is the swing-face jamb corner; the leaf is perpendicular, '
      'off the band, of length w; the arc is centred on the hinge, of radius '
      'w, +π/2 anticlockwise between the tip and the shut jamb; the '
      'children are [LINE, ARC], ascending, ByLayer; a host move keeps both '
      'child handles', () {
    final doc = wallDoc();
    run(doc,
        addWall(doc, hA, plan(-2100, -1500), plan(2100, -1500), 200, right));
    final doors = {
      hD: const OpeningParams(hA, 650, 700, OpeningKind.door),
      hE: const OpeningParams(hA, 1550, 700, OpeningKind.door,
          swing: SwingSide.right),
      hW: const OpeningParams(hA, 2700, 700, OpeningKind.door,
          hinge: HingeEnd.end),
      hG: const OpeningParams(hA, 3550, 700, OpeningKind.door,
          hinge: HingeEnd.end, swing: SwingSide.right),
    };
    for (final MapEntry(key: h, value: o) in doors.entries) {
      run(doc, addOpening(doc, h, o));
    }
    void check(String when) {
      final f = oracleFrameOf(doc, hA);
      expect(f.len, closeTo(4200, 1e-6));
      expect((f.lo, f.ro), (0.0, -200.0));
      final pieces = worldPieces(doc, hA);
      expect(pieces, hasLength(5), reason: when);
      for (final MapEntry(key: h, value: o) in doors.entries) {
        final why = '$when ${o.hinge.name}/${o.swing.name}';
        expect((o.position - f.len / 2).abs(), greaterThan(400), reason: why);
        expectDoorOnOracle(doc, h, reason: why);
        final c = OpeningOracle(doc).cut(o)!;
        expect(c.clamped, isFalse, reason: why);
        final face = o.swing == SwingSide.left ? f.lo : f.ro;
        final (from, to) = worldLines(doc, h).single;
        // The hinge: the jamb corner on the swing side's face, at x₁ for
        // hinge start and x₂ for hinge end, a corner of a piece.
        final uh = o.hinge == HingeEnd.start ? c.a : c.b;
        expect((from - oracleAt(f, uh, face)).length, lessThan(1e-6),
            reason: why);
        expect(pieces.any((p) => nearestIn(p, from) < 1e-6), isTrue,
            reason: '$why: the hinge is a piece\'s corner');
        // The leaf: perpendicular to the wall, w long, off the band.
        final leaf = to - from;
        expect(leaf.dot(f.d).abs(), lessThan(1e-6), reason: why);
        expect(leaf.length, closeTo(700, 1e-6), reason: why);
        final v = offsetOf(f, to);
        expect(
            v, closeTo(face + (o.swing == SwingSide.left ? 700 : -700), 1e-6),
            reason: why);
        expect(v > f.lo || v < f.ro, isTrue, reason: '$why: off the band');
        // The arc: about the hinge, from the tip or the shut jamb, +π/2.
        final arc = worldArc(doc, h);
        final shut = oracleAt(f, o.hinge == HingeEnd.start ? c.b : c.a, face);
        final u = arc.from - arc.centre, w = arc.to - arc.centre;
        expect(u.x * w.y - u.y * w.x, greaterThan(0), reason: '$why: ccw');
        bool at(Vector2 p, Vector2 q) => (p - q).length < 1e-6;
        expect(
            (at(arc.from, to) && at(arc.to, shut)) ||
                (at(arc.from, shut) && at(arc.to, to)),
            isTrue,
            reason: '$why: between the tip and the shut jamb');
        // [LINE, ARC], ascending, ByLayer.
        final ks = kids(doc, h);
        expect(ks[0].value < ks[1].value, isTrue, reason: why);
        expect([
          for (final k in ks) kindOf(doc, k)
        ], [
          EntityKind.line,
          EntityKind.arc
        ], reason: why);
        expect([
          for (final k in ks) doc.entities.colorAt(doc.entities.slotOf(k)!)
        ], [
          kByLayer,
          kByLayer
        ], reason: why);
      }
    }

    check('placed');
    final handles = {for (final h in doors.keys) h: kids(doc, h)};
    // The host moved far and turned: the doors follow, their children kept.
    final m = doc.tree.accumulatedTransform(hA);
    final depth = doc.commands.undoDepth;
    run(
        doc,
        TransformNodeCommand(
            hA,
            Transform2.translation(61000, -43000)
                .multiply(Transform2.rotation(0.4))
                .multiply(m)));
    expect(doc.commands.undoDepth, depth + 1);
    check('moved');
    for (final h in doors.keys) {
      expect(kids(doc, h), handles[h], reason: 'moved: ${h.toHex()}');
    }
    doc.commands.undo();
    check('undone');
    for (final h in doors.keys) {
      expect(kids(doc, h), handles[h], reason: 'undone: ${h.toHex()}');
    }
  });

  test(
      'OR7 (M-08g, M-08h) the openings\' own groups rotated and translated, '
      'the host in another rotated group: the world symbols are the '
      'oracle\'s; a TransformNodeCommand on the door\'s group leaves its '
      'world symbol unchanged, is one undo step, and drift() is empty', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-2000, 900), plan(2500, 900), 200, centre));
    final atD = Transform2.translation(ox + 2345, oy - 876)
        .multiply(Transform2.rotation(2.2));
    final atW = Transform2.translation(ox - 777, oy + 3210)
        .multiply(Transform2.rotation(-0.9));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 1300, 850, OpeningKind.door,
                hinge: HingeEnd.end),
            at: atD));
    run(
        doc,
        addOpening(
            doc, hW, const OpeningParams(hA, 3100, 1000, OpeningKind.window),
            at: atW));
    expect(doc.tree.accumulatedTransform(hD).isIdentity, isFalse);
    final f = oracleFrameOf(doc, hA);
    expect((1300 - f.len / 2).abs(), greaterThan(900));
    expectDoorOnOracle(doc, hD);
    expectLinesOnOracle(doc, hW);

    final door = worldSymbol(doc, hD);
    final stored = [for (final k in kids(doc, hD)) payloadOf(doc, k).coords];
    final handles = kids(doc, hD);
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    run(
        doc,
        TransformNodeCommand(
            hD,
            Transform2.translation(-3100, 1750)
                .multiply(Transform2.rotation(-1.3))
                .multiply(atD)));
    expect(doc.commands.undoDepth, depth + 1);
    expect(kids(doc, hD), handles);
    // Its own group moved: the stored symbol changed, the world one did not.
    expect([for (final k in kids(doc, hD)) payloadOf(doc, k).coords],
        isNot(stored));
    final moved = worldSymbol(doc, hD);
    expect(moved, hasLength(door.length));
    for (var i = 0; i < door.length; i++) {
      expect((moved[i] - door[i]).abs(), lessThan(1e-6), reason: 'value $i');
    }
    expectDoorOnOracle(doc, hD, reason: 'after the group moved');
    expectLinesOnOracle(doc, hW, reason: 'after the door\'s group moved');

    doc.commands.undo();
    expect(canon(doc), before);
    expect(driftOf(doc), isEmpty);
    expectDoorOnOracle(doc, hD, reason: 'undone');
  });
}
