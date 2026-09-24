import 'dart:convert';
import 'dart:math' as math;

import 'package:floor_planner/parametric/box.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/wall_fixture.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

/// The plan's rotation for relational fixtures: never 0° or 90°.
const double rot = 23;

/// Chosen so that [addL]'s joint is off by rounding in both x and y (with
/// 1000 and 2000 it happens to meet bitwise), and [far]'s axis-aligned A is
/// exactly horizontal.
const Handle hA = Handle(1300), hB = Handle(2600), hC = Handle(3000);

/// Load -> save identity is byte identity (spec 07 D13): a stored value,
/// compared exactly. M-07e compares within a tolerance here; WR6's
/// perturbed control catches it.
bool sameSave(String a, String b) => a == b;

/// [w]'s rectangle between its face offsets [lo] and [ro], from the
/// fixture's explicit faces at its own endpoints.
List<Vector2> rectOf(WorldWall w, double lo, double ro) {
  final (a, b) = face(w, lo);
  final (c, d) = face(w, ro);
  return [a, b, c, d];
}

/// [v] turned [deg] degrees anticlockwise.
Vector2 turned(Vector2 v, double deg) {
  final r = deg * math.pi / 180;
  final c = math.cos(r), s = math.sin(r);
  return Vector2(v.x * c - v.y * s, v.x * s + v.y * c);
}

/// Executes [c] and checks the differential oracle: nothing drifts.
void run(DraftDocument doc, DraftCommand c) {
  doc.commands.execute(c);
  expect(driftOf(doc), isEmpty, reason: 'drift after ${c.label}');
}

/// The select tool's group delete (`select_tool.dart` `_groupCascade`):
/// every leaf except a fill whose boundary goes too, then the node.
DraftCommand deleteLikeSelectTool(DraftDocument doc, Handle g) =>
    CompoundCommand([
      for (final k in kids(doc, g))
        if (kindOf(doc, k) != EntityKind.fill) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

/// Moves object [h] by `(dx, dy)` in world: 03's whole-object gesture.
DraftCommand moveBy(DraftDocument doc, Handle h, double dx, double dy) =>
    TransformNodeCommand(
        h,
        Transform2.translation(dx, dy)
            .multiply(doc.tree.accumulatedTransform(h)));

/// The 67° L of WG2 at the far origin, each wall in its own group: A 200
/// centre into the node, B 115 left out of it.
void addL(DraftDocument doc) {
  for (final c in lWalls(doc)) {
    run(doc, c);
  }
}

/// [addL]'s two creation commands, A's then B's.
List<DraftCommand> lWalls(DraftDocument doc) {
  final h = plan(0, 0);
  return [
    addWall(doc, hA, plan(-3000, 0), h, 200, centre),
    addWall(doc, hB, h, polar(h, 180 - 67 + rot, 2500), 115, left),
  ];
}

/// A's and B's two shared corners in world, each against the Cramer oracle
/// of the faces that meet there.
void expectMitre(DraftDocument doc,
    {required double bThickness, String? reason}) {
  final a = worldWallOf(doc, hA), b = worldWallOf(doc, hB);
  final ra = worldOutline(doc, hA), rb = worldOutline(doc, hB);
  expect(ra, hasLength(4), reason: reason);
  expect(rb, hasLength(4), reason: reason);
  final shared = sharedNear(ra, rb);
  expect(shared, hasLength(2), reason: reason);
  final (al1, al2) = face(a, 100);
  final (ar1, ar2) = face(a, -100);
  final (bl1, bl2) = face(b, bThickness);
  final (br1, br2) = face(b, 0);
  expect(nearestIn(shared, oracleMeet(al1, al2, bl1, bl2)), lessThan(1e-6),
      reason: reason);
  expect(nearestIn(shared, oracleMeet(ar1, ar2, br1, br2)), lessThan(1e-6),
      reason: reason);
}

/// Spec 07 D6's short wall A (150 long, 400 thick, centre) between two
/// nodes at plan `(x, y)`, handles [base], `base + 100`, `base + 200`. Its
/// neighbours, as thick, are L (out of the first node at 130°) and R (out
/// of the second at 50°): A's two mitres run 93 mm along its faces and
/// cross inside it, so A squares both ends; L and R splay apart, so their
/// reaches do not overlap and only A links them.
({Handle a, Handle l, Handle r}) addShortWall(
    DraftDocument doc, double x, double y, int base) {
  final s0 = plan(x, y), s1 = plan(x + 150, y);
  final a = Handle(base), l = Handle(base + 100), r = Handle(base + 200);
  // One command: all three regenerate together, so a later edit of one of
  // them is the only thing under test.
  run(
      doc,
      CompoundCommand([
        addWall(doc, l, polar(s0, 130 + rot, 2000), s0, 400, centre),
        addWall(doc, a, s0, s1, 400, centre),
        addWall(doc, r, s1, polar(s1, 50 + rot, 2000), 400, centre),
      ], label: 'Add short wall'));
  return (a: a, l: l, r: r);
}

/// A node of spike Q5b's generator (seed 7707, trial 161) that drops a
/// crossing lobe: `(angle, length, thickness, justification, from hub)`.
const holeNode = [
  (331.4, 4005.0, 250.0, left, false),
  (294.6, 2843.0, 115.0, centre, false),
  (115.5, 2117.0, 150.0, centre, true),
];

/// Adds [holeNode] at plan `(x, y)`, turned by [rot], handles [base],
/// `base + 100`, `base + 200`.
List<Handle> addHoleNode(DraftDocument doc, double x, double y, int base) {
  final hub = plan(x, y);
  return [
    for (final (i, (deg, len, t, j, fromHub)) in holeNode.indexed)
      () {
        final h = Handle(base + 100 * i);
        final tip = polar(hub, deg + rot, len);
        run(
            doc,
            fromHub
                ? addWall(doc, h, hub, tip, t, j)
                : addWall(doc, h, tip, hub, t, j));
        return h;
      }(),
  ];
}

/// Each diagnostic as its code and the values of its handles.
List<String> summary(List<Diagnostic> ds) => [
      for (final d in ds)
        [d.code, for (final h in d.handles) h.value].join(' '),
    ];

bool overlaps(Aabb2 a, Aabb2 b) =>
    a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY;

Aabb2 wallReach(DraftDocument doc, Handle h) => const WallType().reach(
    doc.components.get<WallParams>(h)!, doc.tree.accumulatedTransform(h));

void main() {
  test(
      'WR1 one wall: fill < outline < centreline; the fill names the closed '
      'outline; the centreline is start -> end', () {
    final doc = wallDoc();
    final s = plan(-1200, 300), e = plan(2300, 1150);
    run(doc, addWall(doc, hA, s, e, 200, left));
    final ks = kids(doc, hA);
    expect([for (final k in ks) k.value],
        [hA.value + 1, hA.value + 2, hA.value + 3]);
    expect([for (final k in ks) kindOf(doc, k)],
        [EntityKind.fill, EntityKind.polyline, EntityKind.polyline]);
    final [fill, outline, centreline] = ks;
    expect(payloadOf(doc, fill).scalars, [outline.value.toDouble()]);
    expect(doc.fills.fillsOf(outline), [fill]);
    final c = payloadOf(doc, outline).coords;
    expect(c, hasLength(10), reason: 'four points, closed');
    expect([c[8], c[9]], [c[0], c[1]]);
    final p = doc.components.get<WallParams>(hA)!;
    expect(payloadOf(doc, centreline).coords, [p.sx, p.sy, p.ex, p.ey]);
    expect(payloadOf(doc, centreline).scalars, isEmpty);
    // Left-justified: the body lies between offsets 200 and 0 along the left
    // normal of s -> e, taken from the plan points themselves.
    final dx = e.x - s.x, dy = e.y - s.y;
    final len = math.sqrt(dx * dx + dy * dy);
    final n = Vector2(-dy / len, dx / len);
    final ring = worldOutline(doc, hA);
    expect(isRectNear(ring, [s + n * 200, e + n * 200, s, e]), isTrue,
        reason: '$ring');
    expect(signedArea(ring), greaterThan(0), reason: 'anticlockwise');
    expect(diagnosticsOf(doc), isEmpty);
  });

  test(
      'WR2 the 67° L, each wall in its own group: two corners shared in '
      'world, each equal to the oracle; also with a joint one ulp apart '
      '(M-07h, M-07d)', () {
    // Exactly one ulp apart in x: each group sits on its own hub end.
    final one = wallDoc();
    final hub = far(0, 0);
    final ulp = Vector2(nextUp(hub.x), hub.y);
    run(one,
        addSpoke(one, hA, hub, 180 + rot, 3000, 200, centre, fromHub: false));
    run(one,
        addSpoke(one, hB, ulp, 180 - 67 + rot, 2500, 115, left, fromHub: true));
    final a1 = worldWallOf(one, hA), b1 = worldWallOf(one, hB);
    expect(b1.s.x - a1.e.x, nextUp(hub.x) - hub.x);
    expect(b1.s.x, isNot(a1.e.x));
    expect(b1.s.y, a1.e.y);
    expectMitre(one, bThickness: 115, reason: 'one ulp apart');

    // Joined within rounding: two generic rotated groups.
    final doc = wallDoc();
    addL(doc);
    final a = worldWallOf(doc, hA), b = worldWallOf(doc, hB);
    expect(a.e.x == b.s.x && a.e.y == b.s.y, isFalse);
    expect((a.e - b.s).length, lessThan(wallJoin.linear));
    expectMitre(doc, bThickness: 115, reason: 'rounding apart');
    expect(diagnosticsOf(doc), isEmpty);
  });

  test(
      'WR3 moving B off A is one undo step: A\'s end squares, by '
      'coordinates; undo and redo are exact (M-07g)', () {
    final doc = wallDoc();
    // Both walls in one command: A's mitre is built by the creation itself,
    // not by B's creation regenerating A, so only the move is under test.
    run(doc, CompoundCommand(lWalls(doc), label: 'Add L'));
    expectMitre(doc, bThickness: 115);
    final aKids = kids(doc, hA), bKids = kids(doc, hB);
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    doc.commands.execute(moveBy(doc, hB, 6000, 5500));
    expect(doc.commands.undoDepth, depth + 1);
    final a = worldWallOf(doc, hA), b = worldWallOf(doc, hB);
    expect(isRectNear(worldOutline(doc, hA), rectOf(a, 100, -100)), isTrue,
        reason: 'A is free at both ends');
    expect(isRectNear(worldOutline(doc, hB), rectOf(b, 115, 0)), isTrue,
        reason: 'B is free at both ends');
    expect(driftOf(doc), isEmpty);
    expect(kids(doc, hA), aKids);
    expect(kids(doc, hB), bKids);
    final after = canon(doc);
    doc.commands.undo();
    expect(canon(doc), before);
    expect(driftOf(doc), isEmpty);
    doc.commands.redo();
    expect(canon(doc), after);
    expect(driftOf(doc), isEmpty);
  });

  test('WR4 a thickness edit on B moves A\'s corners, in one step', () {
    final doc = wallDoc();
    addL(doc);
    final ringA = worldOutline(doc, hA);
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    final p = doc.components.get<WallParams>(hB)!;
    run(doc, SetComponentCommand<WallParams>(hB, p.copyWith(thickness: 180)));
    expect(doc.commands.undoDepth, depth + 1);
    expectMitre(doc, bThickness: 180);
    // B is left-justified: its face at offset 0 stays put, so A's corner
    // on it and A's far end do not move; the corner on B's thicker face
    // does.
    expect(sharedNear(worldOutline(doc, hA), ringA), hasLength(3));
    doc.commands.undo();
    expect(canon(doc), before);
    expectMitre(doc, bThickness: 115);
  });

  test(
      'WR5 an X stays two rectangles; a T onto one of them butts its near '
      'face', () {
    final doc = wallDoc();
    run(doc,
        addWall(doc, hA, plan(-1000, -1000), plan(1000, 900), 150, centre));
    run(doc, addWall(doc, hB, plan(-1000, 800), plan(1200, -700), 240, left));
    final x1 = worldWallOf(doc, hA), x2 = worldWallOf(doc, hB);
    expect(isRectNear(worldOutline(doc, hA), rectOf(x1, 75, -75)), isTrue);
    expect(isRectNear(worldOutline(doc, hB), rectOf(x2, 240, 0)), isTrue);
    // The stem ends on B's centreline, three quarters along, and leaves it at
    // 58° on B's left: B's near face is its left face (offset 240), not its
    // centreline.
    final p = x2.s + (x2.e - x2.s) * 0.75;
    final dir = turned((x2.e - x2.s).normalized(), 58);
    run(doc, addWall(doc, hC, p + dir * 2400, p, 115, centre));
    final stem = worldOutline(doc, hC);
    final capPoints = [
      for (final q in stem)
        if ((q - p).length < 500) q
    ];
    expect(capPoints, hasLength(2));
    final (n1, n2) = face(x2, 240);
    final (f1, f2) = face(x2, 0);
    for (final q in capPoints) {
      expect(distToLine(q, n1, n2), lessThan(1e-6));
      expect(distToLine(q, f1, f2), greaterThan(100));
    }
    expect(isRectNear(worldOutline(doc, hA), rectOf(x1, 75, -75)), isTrue);
    expect(isRectNear(worldOutline(doc, hB), rectOf(x2, 240, 0)), isTrue);
    expect(diagnosticsOf(doc), isEmpty);
  });

  test(
      'WR6 load -> save is byte-identical, drift() is empty after reload, '
      'typed components equal; a one-ulp perturbed outline is not (M-07e)', () {
    final doc = wallDoc();
    addL(doc);
    final saved = enc(doc);
    final back = reload(saved);
    expect(sameSave(enc(back), saved), isTrue);
    expect(driftOf(back), isEmpty);
    for (final h in [hA, hB]) {
      expect(back.components.get<WallParams>(h),
          doc.components.get<WallParams>(h));
      expect(back.components.get<WallParams>(h), isA<WallParams>());
    }
    // The control: one stored outline coordinate of A, one ulp off. Load
    // trusts geometry (06 D10), so the reload keeps it and saves it.
    final j = jsonDecode(saved) as Map<String, Object?>;
    final boundary = kids(doc, hA)[1];
    final entity = (j['entities']! as List)
        .cast<Map<String, Object?>>()
        .firstWhere((e) => (e['record']! as Map)['handle'] == boundary.value);
    final coords = (entity['geometry']! as Map)['coords']! as List;
    final was = (coords[2] as num).toDouble();
    coords[2] = nextUp(was);
    expect(coords[2], isNot(was));
    final perturbed = jsonEncode(j);
    final off = reload(perturbed);
    expect(sameSave(enc(off), saved), isFalse);
    expect(sameSave(enc(off), perturbed), isTrue);
    expect(driftOf(off), [hA]);
  });

  test(
      'WR7 deleting A with the select tool\'s cascade detaches it and squares '
      'B\'s end; undo restores A\'s three children and the mitre', () {
    final doc = wallDoc();
    addL(doc);
    final aKids = kids(doc, hA);
    final before = canon(doc, sortNodes: true);
    run(doc, deleteLikeSelectTool(doc, hA));
    expect(doc.components.get<WallParams>(hA), isNull);
    expect(doc.tree[hA], isNull);
    expect(kids(doc, hA), isEmpty);
    final b = worldWallOf(doc, hB);
    expect(isRectNear(worldOutline(doc, hB), rectOf(b, 115, 0)), isTrue);
    doc.commands.undo();
    expect(kids(doc, hA), aKids);
    expect(canon(doc, sortNodes: true), before);
    expectMitre(doc, bThickness: 115);
    expect(driftOf(doc), isEmpty);
  });

  test(
      'WR8 a short wall between two nodes: moving the far neighbour of one '
      'node leaves nothing drifted (M-07l)', () {
    final doc = wallDoc();
    final (:a, :l, :r) = addShortWall(doc, 0, 0, 1000);
    // L and R are not neighbours: only the short wall links them.
    expect(overlaps(wallReach(doc, l), wallReach(doc, r)), isFalse);
    expect(
        isRectNear(
            worldOutline(doc, a), rectOf(worldWallOf(doc, a), 200, -200)),
        isTrue,
        reason: 'the short wall squares both its ends');
    expect(summary(diagnosticsOf(doc)), ['wall.fallback ${a.value}']);
    final ringL = worldOutline(doc, l);
    run(doc, moveBy(doc, r, 5000, -6000));
    expect(diagnosticsOf(doc), isEmpty, reason: 'A mitres at L again');
    // L's outline never depended on R.
    expect(worldOutline(doc, l), ringL);
    expect(sharedNear(worldOutline(doc, a), ringL), hasLength(2));
  });

  test(
      'WR9 diagnostics() names a hole node once, a fallback wall and a '
      'degenerate wall; the sample plan and a clean L report none', () {
    final doc = wallDoc();
    final node = addHoleNode(doc, -9000, 9000, 1000);
    final (:a, l: _, r: _) = addShortWall(doc, 9000, 9000, 2000);
    const zeroLength = Handle(3000), zeroThick = Handle(3100);
    final z = plan(0, -9000);
    run(doc, addWall(doc, zeroLength, z, z, 200, centre));
    run(doc,
        addWall(doc, zeroThick, plan(-500, -9000), plan(500, -9000), 0, left));
    expect(kids(doc, zeroLength).map((k) => kindOf(doc, k)),
        [EntityKind.polyline]);
    expect(
        kids(doc, zeroThick).map((k) => kindOf(doc, k)), [EntityKind.polyline]);
    final ds = diagnosticsOf(doc);
    expect(summary(ds), [
      'wall.hole ${node.map((h) => h.value).join(' ')}',
      'wall.fallback ${a.value}',
      'wall.degenerate ${zeroLength.value}',
      'wall.degenerate ${zeroThick.value}',
    ]);
    expect(ds.every((d) => d.severity == DiagnosticSeverity.warning), isTrue);
    for (final d in ds) {
      for (final h in d.handles) {
        expect(d.message, contains(h.toHex()));
      }
    }
    // Every wall of the hole node still has a sound outline.
    for (final h in node) {
      expect(isSimpleCcw(worldOutline(doc, h)), isTrue);
    }

    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final sample = startupPlan(measurer);
    installParametric(sample);
    expect(diagnosticsOf(sample), isEmpty);
    final clean = wallDoc();
    addL(clean);
    expect(diagnosticsOf(clean), isEmpty);
  });

  test(
      'WR10 a box overlapping a wall: each regenerates on its own; the wall '
      'ignores the box and the box ignores the wall', () {
    final doc = wallDoc();
    const box = Handle(5000);
    final boxAt = Transform2.translation(ox - 400, oy - 300)
        .multiply(Transform2.rotation(0.61));
    run(
        doc,
        CompoundCommand([
          AddNodeCommand(GroupNode(
              handle: box,
              parent: doc.rootHandle,
              transform: boxAt,
              children: const [])),
          SetComponentCommand<BoxParams>(box, const BoxParams(1500, 900)),
        ], label: 'Add box'));
    run(doc, addWall(doc, hA, plan(-2000, 100), plan(2500, 400), 200, right));
    expect(
        overlaps(
            wallReach(doc, hA),
            const BoxType().reach(doc.components.get<BoxParams>(box)!,
                doc.tree.accumulatedTransform(box))),
        isTrue,
        reason: 'they are neighbours');

    void expectIndependent() {
      final w = worldWallOf(doc, hA);
      // Right-justified: the body lies between offsets 0 and -t.
      expect(isRectNear(worldOutline(doc, hA), rectOf(w, 0, -w.t)), isTrue);
      final p = doc.components.get<BoxParams>(box)!;
      final m = doc.tree.accumulatedTransform(box);
      final corners = [
        Vector2(0, 0),
        Vector2(p.width, 0),
        Vector2(p.width, p.height),
        Vector2(0, p.height),
      ];
      final lines = kids(doc, box);
      expect([for (final k in lines) kindOf(doc, k)],
          List.filled(4, EntityKind.line));
      for (final (i, k) in lines.indexed) {
        expect(payloadOf(doc, k).coords, [
          corners[i].x,
          corners[i].y,
          corners[(i + 1) % 4].x,
          corners[(i + 1) % 4].y,
        ]);
      }
      // The wall's centreline runs through the box.
      final quad = [for (final c in corners) m.transformPoint(c)];
      expect([
        for (var i = 0; i <= 20; i++)
          if (insideRing(w.s + (w.e - w.s) * (i / 20), quad)) i
      ], isNotEmpty);
    }

    expectIndependent();
    final wallRing = payloadOf(doc, kids(doc, hA)[1]).coords.toList();
    run(doc, SetComponentCommand<BoxParams>(box, const BoxParams(1800, 1100)));
    expect(payloadOf(doc, kids(doc, hA)[1]).coords, wallRing);
    expectIndependent();
    final p = doc.components.get<WallParams>(hA)!;
    run(doc, SetComponentCommand<WallParams>(hA, p.copyWith(thickness: 320)));
    expectIndependent();
    expect(
        isRectNear(
            worldOutline(doc, hA), rectOf(worldWallOf(doc, hA), 0, -320)),
        isTrue);
  });

  test(
      'WR11 an axis-aligned L (0° and 90° in world) is a pair of neighbours '
      'and mitres (M-07s)', () {
    final doc = wallDoc();
    final h = far(0, 0);
    run(doc, addWall(doc, hA, far(-3000, 0), h, 200, centre));
    run(doc, addWall(doc, hB, h, far(0, 2500), 115, left));
    expectMitre(doc, bThickness: 115);
    expect(diagnosticsOf(doc), isEmpty);
  });

  test(
      'WR12 a 26-wall plan with every joint kind: the incremental document '
      'and one built in reverse order hold the same world outlines', () {
    final specs = <(Handle, Vector2, Vector2, double, Justification)>[];
    var next = 1000;
    void wall(Vector2 s, Vector2 e, double t, Justification j) {
      specs.add((Handle(next), s, e, t, j));
      next += 100;
    }

    // A room of four Ls at unequal angles, and a stem teed at both ends.
    final p0 = plan(0, 0), p1 = plan(4000, 300);
    final p2 = plan(3600, 3100), p3 = plan(-200, 2700);
    wall(p0, p1, 200, centre);
    wall(p1, p2, 115, left);
    wall(p2, p3, 150, right);
    wall(p3, p0, 200, centre);
    wall(p0 + (p1 - p0) * 0.4, p2 + (p3 - p2) * 0.55, 100, centre);
    // An X, and a stem teed onto one of its walls.
    final x1s = plan(8000, -1000), x1e = plan(10000, 900);
    final x2s = plan(8000, 800), x2e = plan(10200, -700);
    wall(x1s, x1e, 150, centre);
    wall(x2s, x2e, 240, left);
    final q = x2s + (x2e - x2s) * 0.75;
    wall(q + turned((x2e - x2s).normalized(), 58) * 2400, q, 115, centre);
    // A three-way node.
    final n3 = plan(0, 9000);
    wall(n3, polar(n3, 10 + rot, 3000), 200, centre);
    wall(polar(n3, 50 + rot, 2000), n3, 115, left);
    wall(n3, polar(n3, 200 + rot, 2500), 150, right);
    // A four-way cross.
    final n4 = plan(9000, 9000);
    wall(n4, polar(n4, 0 + rot, 3000), 200, centre);
    wall(polar(n4, 180 + rot, 3000), n4, 200, centre);
    wall(n4, polar(n4, 90 + rot, 2500), 115, left);
    wall(polar(n4, 270 + rot, 2500), n4, 115, left);
    // A collinear step.
    wall(plan(15000, 0), plan(18000, 0), 200, centre);
    wall(plan(18000, 0), plan(21000, 0), 115, left);
    // A short wall that falls back, between two nodes.
    final s0 = plan(18000, 9000), s1 = plan(18150, 9000);
    wall(polar(s0, 130 + rot, 2000), s0, 400, centre);
    wall(s0, s1, 400, centre);
    wall(s1, polar(s1, 50 + rot, 2000), 400, centre);
    // A node that leaves a hole.
    final hub = plan(0, 18000);
    for (final (deg, len, t, j, fromHub) in holeNode) {
      final tip = polar(hub, deg + rot, len);
      fromHub ? wall(hub, tip, t, j) : wall(tip, hub, t, j);
    }
    // A 20° L, whose outer wedge is bevelled.
    final n2 = plan(9000, 18000);
    wall(plan(6000, 18000), n2, 200, centre);
    wall(n2, polar(n2, 180 - 20 + rot, 2500), 200, centre);
    // A free wall.
    wall(plan(17000, 17000), plan(19500, 18200), 300, right);
    expect(specs.length, greaterThanOrEqualTo(20));

    DraftDocument build(Iterable<int> order) {
      final doc = wallDoc();
      for (final i in order) {
        final (h, s, e, t, j) = specs[i];
        run(doc, addWall(doc, h, s, e, t, j));
      }
      return doc;
    }

    final n = specs.length;
    final incremental = build([for (var i = 0; i < n; i++) i]);
    final fresh = build([for (var i = n - 1; i >= 0; i--) i]);

    // The plan holds every joint kind.
    final world = [for (final s in specs) worldWallOf(incremental, s.$1)];
    Joint jointOf(int i, int k) => classify(world[i], k, world);
    expect(jointOf(0, 1), isA<NodeJoint>(), reason: 'L');
    expect(jointOf(4, 0), isA<Tee>(), reason: 'T');
    expect(jointOf(4, 1), isA<Tee>(), reason: 'T');
    expect(jointOf(5, 0), isA<Free>(), reason: 'X: nothing at the ends');
    expect(jointOf(7, 1), isA<Tee>(), reason: 'T onto the X');
    expect((jointOf(8, 0) as NodeJoint).ends, hasLength(3));
    expect((jointOf(11, 0) as NodeJoint).ends, hasLength(4));
    expect((jointOf(15, 1) as NodeJoint).ends, hasLength(2), reason: 'step');
    expect([for (final d in diagnosticsOf(incremental)) d.code],
        ['wall.fallback', 'wall.hole']);
    expect(diagnosticsOf(fresh), diagnosticsOf(incremental));

    for (final (h, _, _, _, _) in specs) {
      final a = worldOutline(incremental, h), b = worldOutline(fresh, h);
      expect(a, hasLength(b.length), reason: h.toHex());
      expect(a.length, greaterThanOrEqualTo(4), reason: h.toHex());
      for (var i = 0; i < a.length; i++) {
        expect((a[i] - b[i]).length, lessThan(1e-6), reason: '${h.toHex()} $i');
      }
    }
  });
}
