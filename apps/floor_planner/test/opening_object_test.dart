// Spec 08 D3, D4, D19 at the app level: an opening is its own object. It
// follows its host through the closure's referrer direction, two hops
// included; it is deleted with its host in the same edit; it saves and
// loads; and a plan regenerated from scratch agrees with the incremental
// one, exactly. Every wall is at the far origin in its own rotated group
// (`groupAt`), no host is axis-aligned, no opening is central, and some
// openings sit in their own rotated, translated groups. Expected symbols
// and cuts come from `support/opening_fixture.dart`'s oracles, which never
// call `opening_geometry.dart`.
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_grips.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart';
import 'support/wall_fixture.dart';
import 'support/wall_shell.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

const hA = Handle(1300), hB = Handle(2600), hC = Handle(2700);
const hD = Handle(4000), hW = Handle(4100), hG = Handle(4200);

const Map<String, int> noViolations = {
  'overlap': 0,
  'hole': 0,
  'pieceInGap': 0,
  'pieceOutside': 0,
  'gapOutside': 0,
};

/// Executes [c] and checks the differential oracle: nothing drifts.
void run(DraftDocument doc, DraftCommand c) {
  doc.commands.execute(c);
  expect(driftOf(doc), isEmpty, reason: 'drift after ${c.label}');
}

/// [m] followed by a turn of [rad] about [pivot]: a rotation of a root-level
/// group about a world point.
Transform2 rotatedAbout(Transform2 m, Vector2 pivot, double rad) =>
    Transform2.translation(pivot.x, pivot.y)
        .multiply(Transform2.rotation(rad))
        .multiply(Transform2.translation(-pivot.x, -pivot.y))
        .multiply(m);

/// Root-level group [h]'s own transform.
Transform2 nodeTransform(DraftDocument doc, Handle h) =>
    (doc.tree[h]! as GroupNode).transform;

/// Each of [hs]'s children, ascending: the handles undo must restore.
Map<Handle, List<Handle>> childrenOf(DraftDocument doc, List<Handle> hs) =>
    {for (final h in hs) h: kids(doc, h)};

/// The openings' symbols and the walls' pieces are on the oracles, and the
/// pieces tile the twin's stored uncut band.
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

/// OR1's wall: 5,000 mm, 200 left-justified, at 23° in its own group at the
/// far origin; a door at 1,400 (900, hinge `end`, swing `right`) and a
/// window at 3,600 (1,000): both non-central, three pieces.
DraftDocument hostWithTwo() {
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
          doc, hW, const OpeningParams(hA, 3600, 1000, OpeningKind.window)));
  return doc;
}

void main() {
  test(
      'OR1 (M-08r, M-08r2, M-08h) the host\'s group moved 75 m, its reach '
      'disjoint before and after: the door\'s leaf moves by exactly that '
      'vector, door and window stay on the oracle, three pieces tile; one '
      'undo step; undo and redo exact; drift() empty; then a rotate about a '
      'point off the wall keeps the symbols on the oracle', () {
    final doc = hostWithTwo();
    final f = oracleFrameOf(doc, hA);
    expect((1400 - f.len / 2).abs(), greaterThan(1000), reason: 'off centre');
    expect(worldPieces(doc, hA), hasLength(3));
    expectOnOracles(doc, 'placed');
    final leaf = worldLines(doc, hD).single;
    final window = worldLines(doc, hW);
    final box = Aabb2.fromPoints(worldPieces(doc, hA).expand((r) => r));
    final handles = childrenOf(doc, [hA, hD, hW]);

    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    final v = Vector2(60000, -45000);
    run(
        doc,
        TransformNodeCommand(hA,
            Transform2.translation(v.x, v.y).multiply(nodeTransform(doc, hA))));
    expect(doc.commands.undoDepth, depth + 1);
    expect(
        box.intersects(Aabb2.fromPoints(worldPieces(doc, hA).expand((r) => r))),
        isFalse,
        reason: 'the reaches before and after are disjoint');
    final moved = worldLines(doc, hD).single;
    expect((moved.$1 - (leaf.$1 + v)).length, lessThan(1e-6), reason: 'hinge');
    expect((moved.$2 - (leaf.$2 + v)).length, lessThan(1e-6), reason: 'tip');
    final movedWindow = worldLines(doc, hW);
    for (var i = 0; i < 3; i++) {
      expect((movedWindow[i].$1 - (window[i].$1 + v)).length, lessThan(1e-6));
      expect((movedWindow[i].$2 - (window[i].$2 + v)).length, lessThan(1e-6));
    }
    expect(worldPieces(doc, hA), hasLength(3));
    expectOnOracles(doc, 'moved');
    expect(childrenOf(doc, [hA, hD, hW]), handles);
    final after = canon(doc);

    doc.commands.undo();
    expect(canon(doc), before);
    expect(driftOf(doc), isEmpty);
    doc.commands.redo();
    expect(canon(doc), after);
    expect(driftOf(doc), isEmpty);

    // A rotate of the host's group about a point off the wall.
    final pivot = plan(60000 + 700, -45000 + 2600);
    expect(nearestIn(worldPieces(doc, hA).expand((r) => r).toList(), pivot),
        greaterThan(1000));
    run(
        doc,
        TransformNodeCommand(
            hA, rotatedAbout(nodeTransform(doc, hA), pivot, 0.61)));
    expect(doc.commands.undoDepth, depth + 2);
    expect((worldLines(doc, hD).single.$1 - moved.$1).length, greaterThan(100),
        reason: 'the door turned with its host');
    expect(worldPieces(doc, hA), hasLength(3));
    expectOnOracles(doc, 'rotated');
  });

  test(
      'OR2 (X7-json) save → load → save is byte-identical; each typed '
      'OpeningParams compares equal; drift() is empty after the load; the '
      'same two edits (slide the door, move the wall) on the original and on '
      'the reload give identical bytes', () {
    final doc = hostWithTwo();
    run(
        doc,
        addOpening(doc, hG, const OpeningParams(hA, 2600, 500, OpeningKind.gap),
            at: Transform2.translation(ox + 1234, oy - 4321)
                .multiply(Transform2.rotation(1.1))));
    expect(worldPieces(doc, hA), hasLength(4));
    final saved = enc(doc);
    final loaded = reload(saved);
    expect(enc(loaded), saved);
    for (final h in [hD, hW, hG]) {
      final o = loaded.components.get<OpeningParams>(h);
      expect(o, isA<OpeningParams>(), reason: h.toHex());
      expect(o, doc.components.get<OpeningParams>(h), reason: h.toHex());
    }
    expect(loaded.components.get<OpeningParams>(hD)!.host, hA);
    expect(driftOf(loaded), isEmpty);
    expectOnOracles(doc, 'placed');
    expectOnOracles(loaded, 'loaded');

    List<DraftCommand> edits(DraftDocument d) => [
          SetComponentCommand<OpeningParams>(hD,
              d.components.get<OpeningParams>(hD)!.copyWith(position: 1100)),
          TransformNodeCommand(
              hA,
              Transform2.translation(60000, -45000)
                  .multiply(nodeTransform(d, hA))),
        ];
    final a = edits(doc), b = edits(loaded);
    for (var i = 0; i < a.length; i++) {
      run(doc, a[i]);
      run(loaded, b[i]);
      expect(enc(loaded), enc(doc), reason: 'after ${a[i].label}');
    }
    expectOnOracles(loaded, 'edited');
  });

  test(
      'OR4 (M-08t, M-08r2, X7-dirty) the two-hop shape: A 200 centre into a '
      'node, B 115 left out of it at 67°, a door in A stored at 2,700 and '
      'drawn clamped at A\'s mitre; swinging B\'s far end to 40° moves the '
      'door\'s leaf by more than 1 mm, on the oracle, and drift() is empty',
      () {
    final doc = wallDoc();
    final hub = plan(0, 0);
    run(doc, addWall(doc, hA, plan(-3000, 0), hub, 200, centre));
    run(doc, addWall(doc, hB, hub, polar(hub, 180 - 67 + 23, 2500), 115, left));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 2700, 900, OpeningKind.door,
                swing: SwingSide.right)));
    final oracle = OpeningOracle(doc);
    final (_, uE) = oracle.span(hA);
    final cut = oracle.cut(doc.components.get<OpeningParams>(hD)!)!;
    expect(cut.clamped, isTrue);
    expect(cut.b, closeTo(uE, 1e-6), reason: 'clamped at the mitre');
    expect(uE, lessThan(3000 - 1));
    expect([for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'],
        ['opening.clamped [$hD]']);
    expectDoorOnOracle(doc, hD);
    // The door is neither B's referent nor B's referrer.
    expect(doc.components.get<OpeningParams>(hD)!.host, hA);
    final leaf = worldLines(doc, hD).single;

    final depth = doc.commands.undoDepth;
    final p = doc.components.get<WallParams>(hB)!;
    final end = doc.tree
        .accumulatedTransform(hB)
        .invert()
        .transformPoint(polar(hub, 180 - 40 + 23, 2500));
    run(doc, SetComponentCommand<WallParams>(hB, p.copyWith(end: end)));
    expect(doc.commands.undoDepth, depth + 1);
    final now = worldLines(doc, hD).single;
    expect((now.$1 - leaf.$1).length, greaterThan(1), reason: 'the hinge');
    expect((now.$2 - leaf.$2).length, greaterThan(1), reason: 'the tip');
    final (_, uE2) = OpeningOracle(doc).span(hA);
    expect(uE2, lessThan(uE - 1), reason: 'A\'s mitre moved back');
    expectOnOracles(doc, 'swung');
  });

  test(
      'OR5 (M-08f, M-08f0, M-08f2) deleting wall A, which carries a door and '
      'a window and is joined to C at 110°, with the select tool\'s compound: '
      'A, the door and the window go (nodes, components, children); C\'s end '
      'is square; one undo step; undo restores the state and every child '
      'handle of all four objects; redo; undo then purge(); drift() empty '
      'throughout', () async {
    final doc = wallDoc();
    final hub = plan(500, -800);
    run(doc, addWall(doc, hA, plan(-3500, -800), hub, 200, centre));
    run(doc,
        addWall(doc, hC, hub, polar(hub, 180 - 110 + 23, 2600), 150, right));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 1100, 800, OpeningKind.door,
                hinge: HingeEnd.end)));
    run(
        doc,
        addOpening(
            doc, hW, const OpeningParams(hA, 2300, 900, OpeningKind.window)));
    // A and C mitre (A read uncut, in the twin): C's end is not square yet.
    expectMitre(uncutTwin(doc), hA, hC);
    expect(worldPieces(doc, hA), hasLength(3));
    expect(diagnosticsOf(doc), isEmpty);
    expectOnOracles(doc, 'placed');
    final all = [hA, hC, hD, hW];
    final handles = childrenOf(doc, all);
    for (final h in all) {
      expect(handles[h], isNotEmpty, reason: h.toHex());
    }
    final before = canon(doc, sortNodes: true);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(deleteLikeSelectTool(doc, hA));
    // A listener-driven cascade would run here.
    await pumpEventQueue();
    for (final h in [hA, hD, hW]) {
      expect(doc.tree[h], isNull, reason: h.toHex());
      expect(doc.components.get<WallParams>(h), isNull, reason: h.toHex());
      expect(doc.components.get<OpeningParams>(h), isNull, reason: h.toHex());
      for (final k in handles[h]!) {
        expect(doc.entities.slotOf(k), isNull, reason: '${h.toHex()} $k');
      }
    }
    expectSquare(doc, hC);
    expect(doc.commands.undoDepth, depth + 1);
    expect(driftOf(doc), isEmpty);
    final after = canon(doc, sortNodes: true);

    doc.commands.undo();
    expect(canon(doc, sortNodes: true), before);
    expect(childrenOf(doc, all), handles);
    expect(driftOf(doc), isEmpty);
    expectOnOracles(doc, 'undone');
    doc.commands.redo();
    expect(canon(doc, sortNodes: true), after);
    expect(driftOf(doc), isEmpty);
    doc.commands.undo();
    doc.purge();
    expect(canon(doc, sortNodes: true), before);
    expect(childrenOf(doc, all), handles);
    expect(driftOf(doc), isEmpty);
  });

  test(
      'DF1 (X7-dirty) a 24-wall plan with every opening kind, T and X '
      'obstacles, clamped, no-fit and overlapping openings, built one command '
      'at a time and edited (a wall move, a thickness change, an end drag, '
      'an opening slide): a document built from the final parameters in '
      'reverse order holds the same world pieces and world symbols, '
      'exactly; drift() is empty in both', () {
    const rot = 23.0;
    final walls = <(Handle, Vector2, Vector2, double, Justification)>[];
    void wall(Vector2 s, Vector2 e, double t, Justification j) =>
        walls.add((Handle(1000 + 100 * walls.length), s, e, t, j));

    // 0-3: a room of four Ls at unequal angles; 4: a stem teed at both ends.
    final p0 = plan(0, 0), p1 = plan(4000, 300);
    final p2 = plan(3600, 3100), p3 = plan(-200, 2700);
    wall(p0, p1, 200, centre);
    wall(p1, p2, 115, left);
    wall(p2, p3, 150, right);
    wall(p3, p0, 200, centre);
    wall(p0 + (p1 - p0) * 0.4, p2 + (p3 - p2) * 0.55, 100, centre);
    // 5-6: an X; 7: a stem teed onto 6.
    final x2s = plan(8000, 800), x2e = plan(10200, -700);
    wall(plan(8000, -1000), plan(10000, 900), 150, centre);
    wall(x2s, x2e, 240, left);
    final q = x2s + (x2e - x2s) * 0.75;
    wall(polar(q, rot - 100, 2400), q, 115, centre);
    // 8-10: a three-way node.
    final n3 = plan(0, 9000);
    wall(n3, polar(n3, 10 + rot, 3000), 200, centre);
    wall(polar(n3, 50 + rot, 2000), n3, 115, left);
    wall(n3, polar(n3, 200 + rot, 2500), 150, right);
    // 11-14: a four-way cross.
    final n4 = plan(9000, 9000);
    wall(n4, polar(n4, 0 + rot, 3000), 200, centre);
    wall(polar(n4, 180 + rot, 3000), n4, 200, centre);
    wall(n4, polar(n4, 90 + rot, 2500), 115, left);
    wall(polar(n4, 270 + rot, 2500), n4, 115, left);
    // 15-16: a collinear step.
    wall(plan(15000, 0), plan(18000, 0), 200, centre);
    wall(plan(18000, 0), plan(21000, 0), 115, left);
    // 17-18: the 67° L of spike Q1d.
    final l67 = plan(15000, 9000);
    wall(plan(12000, 9000), l67, 200, centre);
    wall(l67, polar(l67, 180 - 67 + rot, 2500), 115, left);
    // 19-20: a 20° L, its outer wedge bevelled.
    final l20 = plan(9000, 18000);
    wall(plan(6000, 18000), l20, 200, centre);
    wall(l20, polar(l20, 180 - 20 + rot, 2500), 200, centre);
    // 21-23: free walls.
    wall(plan(17000, 17000), plan(19500, 18200), 300, right);
    wall(plan(0, 18000), plan(4600, 19100), 200, left);
    wall(plan(0, 24000), plan(3000, 23000), 250, centre);
    expect(walls, hasLength(24));
    Handle w(int i) => walls[i].$1;

    final own = Transform2.translation(ox + 1234, oy - 4321)
        .multiply(Transform2.rotation(1.1));
    final openings = <(Handle, OpeningParams, Transform2?)>[];
    void opening(int i, double c, double width, OpeningKind k,
            {HingeEnd hinge = HingeEnd.start,
            SwingSide swing = SwingSide.left,
            Transform2? at}) =>
        openings.add((
          Handle(5000 + 10 * openings.length),
          OpeningParams(w(i), c, width, k, hinge: hinge, swing: swing),
          at,
        ));
    // Over stem 4's butt: clamped by a T.
    opening(0, 1604, 800, OpeningKind.door, swing: SwingSide.right);
    opening(0, 3000, 700, OpeningKind.window);
    opening(1, 900, 600, OpeningKind.gap);
    // Over stem 4's other butt: clamped by a T.
    opening(2, 2102, 1000, OpeningKind.window);
    opening(3, 800, 700, OpeningKind.door, hinge: HingeEnd.end);
    // Over the crossing: clamped by an X.
    opening(5, 1521, 700, OpeningKind.window);
    // Over stem 7's butt: clamped by a T until stem 7 moves off.
    opening(6, 1950, 500, OpeningKind.door);
    opening(8, 1800, 900, OpeningKind.gap);
    opening(11, 1900, 800, OpeningKind.door,
        hinge: HingeEnd.end, swing: SwingSide.right);
    opening(13, 1400, 600, OpeningKind.window);
    opening(15, 1000, 700, OpeningKind.gap);
    opening(16, 2000, 900, OpeningKind.door);
    // Past the node: clamped at the mitre.
    opening(17, 2700, 900, OpeningKind.door, swing: SwingSide.right);
    opening(18, 1600, 1000, OpeningKind.window);
    opening(19, 2600, 800, OpeningKind.door, hinge: HingeEnd.end);
    // No-fit, and an overlapping pair.
    opening(21, 1400, 3500, OpeningKind.window);
    opening(21, 900, 800, OpeningKind.window);
    opening(21, 1200, 700, OpeningKind.door, hinge: HingeEnd.end);
    // Every hinge × swing.
    for (final (i, c) in [700.0, 1700.0, 2800.0, 3900.0].indexed) {
      opening(22, c, 700, OpeningKind.door,
          hinge: HingeEnd.values[i ~/ 2], swing: SwingSide.values[i % 2]);
    }
    // In their own rotated, translated groups.
    opening(23, 1100, 500, OpeningKind.gap, at: own);
    opening(23, 2300, 800, OpeningKind.window, at: own);

    final doc = wallDoc();
    for (final (h, s, e, t, j) in walls) {
      run(doc, addWall(doc, h, s, e, t, j));
    }
    for (final (h, o, at) in openings) {
      run(doc, addOpening(doc, h, o, at: at));
    }
    final handles = [for (final (h, _, _) in openings) h];

    // The plan holds what DF1 needs.
    final oracle = OpeningOracle(doc);
    for (final i in [0, 2, 5, 6]) {
      expect(oracle.obstacles(w(i)), isNotEmpty, reason: 'wall $i');
    }
    expect(oracle.obstacles(w(6)), hasLength(2), reason: 'the X and the T');
    final report = [
      for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}',
    ];
    for (final want in [
      'opening.clamped [${handles[0]}, ${w(4)}]',
      'opening.clamped [${handles[3]}, ${w(4)}]',
      'opening.clamped [${handles[5]}, ${w(6)}]',
      'opening.clamped [${handles[6]}, ${w(7)}]',
      'opening.clamped [${handles[12]}]',
      'opening.nofit [${handles[15]}]',
      'opening.overlap [${handles[16]}, ${handles[17]}]',
    ]) {
      expect(report, contains(want), reason: '$report');
    }
    expectOnOracles(doc, 'built');

    // The edits: a wall move (stem 7 off its T), a thickness change (room
    // wall 0), an end drag (B of the 67° L swung to 40°) and an opening
    // slide (the second door of wall 22 onto the third).
    // Stem 7 backs 300 mm away from wall 6 along its own line.
    final back = polar(Vector2.zero(), rot - 100, 300);
    run(
        doc,
        TransformNodeCommand(
            w(7),
            Transform2.translation(back.x, back.y)
                .multiply(nodeTransform(doc, w(7)))));
    run(
        doc,
        SetComponentCommand<WallParams>(w(0),
            doc.components.get<WallParams>(w(0))!.copyWith(thickness: 260)));
    expect(OpeningOracle(doc).obstacles(w(6)), hasLength(1),
        reason: 'stem 7 moved off wall 6');
    expect(
        OpeningOracle(doc)
            .cut(doc.components.get<OpeningParams>(handles[6])!)!
            .clamped,
        isFalse,
        reason: 'the door over its butt is drawn where it is stored');
    final grips = WallGrips();
    final end = grips.gripsOf(doc, w(18))[1];
    final swungFrom = worldLines(doc, handles[12]).first.$1;
    run(doc, grips.drag(doc, w(18), end, polar(l67, 180 - 40 + rot, 2300))!);
    expect((worldLines(doc, handles[12]).first.$1 - swungFrom).length,
        greaterThan(1),
        reason: 'the end drag moved the door clamped at the 67° mitre');
    final slid = handles[19];
    run(
        doc,
        SetComponentCommand<OpeningParams>(slid,
            doc.components.get<OpeningParams>(slid)!.copyWith(position: 2300)));
    expect([for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'],
        contains('opening.overlap [$slid, ${handles[20]}]'));
    expectOnOracles(doc, 'edited');

    // From scratch, from the final parameters: the walls in reverse order,
    // then the openings in reverse order (an opening needs its host).
    final fresh = wallDoc();
    for (final (h, _, _, _, _) in walls.reversed) {
      run(
          fresh,
          addWallLocal(fresh, h, doc.components.get<WallParams>(h)!,
              nodeTransform(doc, h)));
    }
    for (final h in handles.reversed) {
      run(
          fresh,
          addOpening(fresh, h, doc.components.get<OpeningParams>(h)!,
              at: nodeTransform(doc, h)));
    }
    expect(driftOf(doc), isEmpty);
    expect(driftOf(fresh), isEmpty);

    // Exact: every piece and every symbol is a function of the parameters
    // alone, so the build order and the edit history leave no trace.
    for (final (h, _, _, _, _) in walls) {
      final a = worldPieces(doc, h), b = worldPieces(fresh, h);
      expect(a, hasLength(b.length), reason: 'wall $h');
      for (var i = 0; i < a.length; i++) {
        expect([
          for (final p in a[i]) ...[p.x, p.y]
        ], [
          for (final p in b[i]) ...[p.x, p.y]
        ], reason: 'wall $h piece $i');
      }
      final ca = worldCentrelines(doc, h), cb = worldCentrelines(fresh, h);
      expect([
        for (final l in ca)
          [
            for (final p in l) ...[p.x, p.y]
          ]
      ], [
        for (final l in cb)
          [
            for (final p in l) ...[p.x, p.y]
          ]
      ], reason: 'wall $h centrelines');
    }
    for (final h in handles) {
      expect([
        for (final k in kids(doc, h)) kindOf(doc, k)
      ], [
        for (final k in kids(fresh, h)) kindOf(fresh, k)
      ], reason: 'opening $h');
      expect(worldSymbol(doc, h), worldSymbol(fresh, h), reason: 'opening $h');
    }
    String summary(DraftDocument d) => [
          for (final x in diagnosticsOf(d)) '${x.code} ${x.handles}',
        ].join('\n');
    expect(summary(fresh), summary(doc));
  });
}
