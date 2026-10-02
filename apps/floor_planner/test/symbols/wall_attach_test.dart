// Spec 09c D4, plan 09c-1 Task 6: `attachToWall`, its neighbours and the
// shell-owned `WallFaces`. Every scene is `wall_attach_fixture.dart`'s
// (plan P-2, P-3): walls at 30° and −112.5°, each in its own rotated group
// near (1e5, −7e4), plain, mirrored and scaled; the toilet (its back the
// cistern, its front the bowl's arc) and an off-centre box (no side at 0);
// the symbol mirrored and not. The one exception is WA9's axis-aligned wall
// (M-09c-n can only go red there). The expected points are hand arithmetic
// along each run's own `a`, `t` and `m` (D3, pinned by
// `wall_faces_test.dart`), never the code under test.
import 'dart:io';
import 'dart:math' as math;

import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_bands.dart';
import 'package:floor_planner/symbols/symbol_box.dart';
import 'package:floor_planner/symbols/symbol_component.dart';
import 'package:floor_planner/symbols/symbol_library.dart';
import 'package:floor_planner/symbols/symbol_placer.dart';
import 'package:floor_planner/symbols/wall_attach.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_attach_fixture.dart';
import '../support/wall_fixture.dart';

/// The camera scale of these tests (px per mm), never 1: one pixel is 5 mm,
/// the attach capture (`kWallAttachPixels = 16`) 80 mm, the edge capture
/// (`kSnapAperturePixels = 10`) 50 mm.
const double scale = 0.2;
const double px = 1 / scale, cap = 16 / scale, edge = 10 / scale;

final SymbolLibrary library = SymbolLibrary.decode(
    File('assets/library/furniture.jetlib').readAsBytesSync());

SymbolEntry entryOf(String key) =>
    library.entries.firstWhere((e) => e.key == key);

final SymbolEntry toilet = entryOf('bath.toilet');

/// The toilet's box: `(0, 400, 0, 700)` (`symbol_box_test.dart`).
final SymbolBox toiletBox = boxOfEntry(toilet)!;

/// A box with no side at 0 and its centre off the origin in both axes.
const SymbolBox offBox =
    SymbolBox(left: 37.5, right: 937.5, front: -120.25, back: 480.75);

/// The point `a + t·u + m·s` of run [r].
Vector2 at(FaceRun r, double u, double s) =>
    Vector2(r.a.x + r.t.x * u + r.m.x * s, r.a.y + r.t.y * u + r.m.y * s);

double uOf(FaceRun r, Vector2 p) => (p - r.a).dot(r.t);
double sOf(FaceRun r, Vector2 p) => (p - r.a).dot(r.m);

List<List<FaceNeighbour>> none(List<FaceRun> runs) =>
    [for (final _ in runs) const <FaceNeighbour>[]];

WallAttachment? attach(List<FaceRun> runs, SymbolBox box, Vector2 p,
        {bool mirrored = false,
        double capture = cap,
        List<List<FaceNeighbour>>? neighbours}) =>
    attachToWall(runs, box, p, capture,
        mirrored: mirrored,
        neighbours: neighbours ?? none(runs),
        edgeCaptureWorld: edge);

/// [att] stands [box] flush on run [r] with its centre at [u]: the back
/// edge's two ends within 1e-9 of the face line, the front `D` into the
/// room, the back-centre on `q = a + t·u`, local `+x` along `t` (along
/// `−t` when [mirrored]) and local `+y` along `−m` exactly, and the local
/// back-left corner at `u ∓ W/2`.
void expectFlush(WallAttachment? att, FaceRun r, SymbolBox box, double u,
    bool mirrored, String why) {
  expect(att, isNotNull, reason: why);
  expect(identical(att!.run, r), isTrue,
      reason: '$why: run ${att.run}, want $r');
  final g = att.transform;
  for (final x in [box.left, box.right]) {
    expect(sOf(r, g.transformPoint(Vector2(x, box.back))).abs(),
        lessThanOrEqualTo(1e-9),
        reason: '$why: back end $x on the face');
  }
  final cx = (box.left + box.right) / 2;
  expect(sOf(r, g.transformPoint(Vector2(cx, box.front))),
      closeTo(box.depth, 1e-9),
      reason: '$why: the front in the room');
  expect(sOf(r, att.q).abs(), lessThanOrEqualTo(1e-9), reason: '$why: q');
  expect(uOf(r, att.q), closeTo(u, 1e-9), reason: '$why: u');
  expect(
      (g.transformPoint(Vector2(cx, box.back)) - att.q).length, lessThan(1e-9),
      reason: '$why: the back-centre on q');
  final sx = mirrored ? -1.0 : 1.0;
  expect([g.a, g.b, g.c, g.d], [sx * r.t.x, sx * r.t.y, -r.t.y, r.t.x],
      reason: '$why: the linear part');
  expect(uOf(r, g.transformPoint(Vector2(box.left, box.back))),
      closeTo(u + (mirrored ? 1 : -1) * box.width / 2, 1e-9),
      reason: '$why: the local left side');
}

/// The scene's document with [SymbolComponent] registered, so symbols can
/// be placed in it.
DraftDocument withSymbols(DraftDocument doc) {
  SymbolComponent.register(doc.components);
  return doc;
}

/// The transform that stands [box] flush on [r] with its centre at [u],
/// built by hand from D4 step 5 (not through `attachToWall`).
Transform2 standing(FaceRun r, SymbolBox box, double u,
        {bool mirrored = false}) =>
    placementTransform(
        at: Vector2(r.a.x + r.t.x * u, r.a.y + r.t.y * u),
        basePoint: Vector2((box.left + box.right) / 2, box.back),
        rotation: (r.t.x, r.t.y),
        mirrored: mirrored);

/// Places the toilet in [doc] with transform [g]; returns its instance.
Handle placeToilet(DraftDocument doc, Transform2 g) {
  final cmd = placeSymbol(doc, toilet, at: farAt(0, 0), transform: g);
  doc.commands.execute(cmd);
  return (cmd.children.last as AddNodeCommand).node.handle;
}

/// The scene's group variants (P-2): plain, mirrored, scaled.
const List<(bool, double)> groups = [(false, 1), (true, 1), (false, 1.5)];

String groupName((bool, double) g) =>
    g.$1 ? 'mirrored group' : (g.$2 != 1 ? 'scaled group' : 'plain group');

void main() {
  test(
      'WA1 a symbol near a face stands flush on it: back on the face line, '
      'front in the room, turned to the wall (local +y along −m), its centre '
      'at the pointer\'s u; each face, every justification, at 30° and '
      '−112.5°, plain, mirrored and scaled groups, the toilet and an '
      'off-centre box, mirrored and not', () {
    var n = 0;
    for (final deg in attachAngles) {
      for (final j in Justification.values) {
        for (final grp in groups) {
          final sc = freeWallScene(deg, j, mirrored: grp.$1, scale: grp.$2);
          final runs = faceRunsOf(sc.doc, sc.walls.single);
          expect(runs, hasLength(2));
          for (final r in runs) {
            for (final box in [toiletBox, offBox]) {
              for (final mirrored in const [false, true]) {
                final why = '$deg° ${j.name} ${groupName(grp)} '
                    '${r.side.name} W ${box.width}'
                    '${mirrored ? ' mirrored' : ''}';
                final p = at(r, 1500.25, 30);
                expectFlush(attach(runs, box, p, mirrored: mirrored), r, box,
                    1500.25, mirrored, why);
                n++;
              }
            }
          }
        }
      }
    }
    expect(n, 144);
  });

  test(
      'WA2 a pointer inside the wall\'s body attaches to the face of its own '
      'half of the band (split at the midline for every justification)', () {
    for (final deg in attachAngles) {
      for (final j in Justification.values) {
        for (final grp in groups) {
          final sc = freeWallScene(deg, j, mirrored: grp.$1, scale: grp.$2);
          final runs = faceRunsOf(sc.doc, sc.walls.single);
          for (final r in runs) {
            final other = runs.firstWhere((x) => !identical(x, r));
            final why = '$deg° ${j.name} ${groupName(grp)} ${r.side.name}';
            final w = r.thickness;
            // 5 mm short of the midline: this face's half.
            expectFlush(attach(runs, toiletBox, at(r, 1200, -(w / 2 - 5))), r,
                toiletBox, 1200, false, '$why near half');
            // 5 mm past the midline: the other face's half (its t runs the
            // other way, so the same place is at L − 1200 along it).
            expectFlush(attach(runs, toiletBox, at(r, 1200, -(w / 2 + 5))),
                other, toiletBox, other.length - 1200, false, '$why far half');
          }
        }
      }
    }
  });

  test(
      'WA3 capture: a pointer within captureWorld of the face and of the '
      'run\'s ends attaches, one just beyond does not', () {
    for (final deg in attachAngles) {
      final sc = freeWallScene(deg, Justification.left);
      final runs = faceRunsOf(sc.doc, sc.walls.single);
      for (final r in runs) {
        final why = '$deg° ${r.side.name}';
        final l = r.length;
        expect(attach(runs, toiletBox, at(r, 1500, cap - 1)), isNotNull,
            reason: why);
        expect(attach(runs, toiletBox, at(r, 1500, cap + 1)), isNull,
            reason: why);
        expect(attach(runs, toiletBox, at(r, -cap + 1, 10)), isNotNull,
            reason: why);
        expect(attach(runs, toiletBox, at(r, -cap - 1, 10)), isNull,
            reason: why);
        expect(attach(runs, toiletBox, at(r, l + cap - 1, 10)), isNotNull,
            reason: why);
        expect(attach(runs, toiletBox, at(r, l + cap + 1, 10)), isNull,
            reason: why);
      }
    }
  });

  test(
      'WA4 the T tie (W-3, T-6): the pointer 1 px right of a 60 mm stem '
      '(narrower than captureWorld − 1 px), nearer the host face than the '
      'stem\'s own face: both host pieces are candidates at the same |s|, '
      'and the piece the pointer is over wins', () {
    var n = 0;
    for (final deg in attachAngles) {
      for (final turn in const [90.0, -90.0, 70.0]) {
        final sc = teeScene(deg, turn, stemThickness: 60);
        final host = faceRunsOf(sc.doc, sc.walls[0]);
        final stem = faceRunsOf(sc.doc, sc.walls[1]);
        final runs = [...host, ...stem];
        final butted = [
          for (final side in FaceSide.values)
            if (host.where((r) => r.side == side).length == 2) side
        ].single;
        final pieces = host.where((r) => r.side == butted).toList()
          ..sort((x, y) => x.a.dot(x.t).compareTo(y.a.dot(y.t)));
        final (lower, upper) = (pieces[0], pieces[1]);
        final why = '$deg° stem $turn ${butted.name}';
        final p = at(upper, px, 2);
        // Premises: the lower piece is a candidate too (its u within
        // L + captureWorld), at the same |s|; the stem's face is further
        // from p than the host face.
        expect(uOf(lower, p), lessThan(lower.length + cap), reason: why);
        expect(uOf(lower, p), greaterThan(lower.length + px), reason: why);
        expect((sOf(lower, p) - 2).abs(), lessThan(1e-9), reason: why);
        final nearestStem =
            stem.map((r) => sOf(r, p).abs()).reduce((x, y) => x < y ? x : y);
        expect(nearestStem, greaterThan(2 + 1), reason: why);
        expectFlush(attach(runs, toiletBox, p), upper, toiletBox,
            toiletBox.width / 2, false, why);
        // In the middle of the cut, both pieces are as far: the lower a·t
        // wins (the last key).
        final gapEnd = uOf(lower, upper.a);
        final mid = at(lower, (lower.length + gapEnd) / 2, 2);
        expect(uOf(lower, mid) - lower.length, closeTo(-uOf(upper, mid), 1e-9),
            reason: why);
        expect(identical(attach(runs, toiletBox, mid)!.run, lower), isTrue,
            reason: '$why: the middle of the cut');
        n++;
      }
    }
    expect(n, 6);
  });

  test(
      'WA5 the band\'s half is −w/2, not −w (M-09c-ah, S-9, T-6): a pointer '
      'inside the host\'s body on the half of a 300 mm stem\'s face, where '
      'that face has no run within capture, attaches to the stem\'s own '
      'face, not to the host\'s other face', () {
    const capW = 100.0; // 0.16 px/mm: 2·captureWorld < 300 mm.
    var n = 0;
    for (final deg in attachAngles) {
      for (final turn in const [90.0, -90.0]) {
        final sc = teeScene(deg, turn, stemThickness: 300);
        final host = faceRunsOf(sc.doc, sc.walls[0]);
        final stem = faceRunsOf(sc.doc, sc.walls[1]);
        final runs = [...host, ...stem];
        final butted = [
          for (final side in FaceSide.values)
            if (host.where((r) => r.side == side).length == 2) side
        ].single;
        final pieces = host.where((r) => r.side == butted).toList()
          ..sort((x, y) => x.a.dot(x.t).compareTo(y.a.dot(y.t)));
        final far = host.singleWhere((r) => r.side != butted);
        final w = far.thickness;
        // The middle of the stem's cut, 10 mm along t; 90 mm into the body
        // from the butted face (10 mm short of the midline).
        final mid = (pieces[0].length + uOf(pieces[0], pieces[1].a)) / 2;
        final p = at(pieces[0], mid + 10, -(w / 2 - 10));
        final why = '$deg° stem $turn';
        // Premises: the far face is within −w but not −w/2; the butted
        // face's pieces are out of the u window; exactly one stem face is a
        // candidate.
        expect(sOf(far, p), inInclusiveRange(-w, -w / 2 - 5), reason: why);
        expect(uOf(far, p), inInclusiveRange(0, far.length), reason: why);
        expect(uOf(pieces[0], p), greaterThan(pieces[0].length + capW),
            reason: why);
        expect(uOf(pieces[1], p), lessThan(-capW), reason: why);
        bool candidate(FaceRun r) {
          final s = sOf(r, p), u = uOf(r, p);
          return s >= -r.thickness / 2 &&
              s <= capW &&
              u >= -capW &&
              u <= r.length + capW;
        }

        final own = stem.where(candidate).toList();
        expect(own, hasLength(1), reason: why);
        expect(sOf(own.single, p).abs(), greaterThan(-sOf(far, p)),
            reason: '$why: the far face would win under −w');
        final att = attach(runs, toiletBox, p, capture: capW);
        expect(att, isNotNull, reason: why);
        expect(identical(att!.run, own.single), isTrue,
            reason: '$why: ${att.run}');
        n++;
      }
    }
    expect(n, 4);
  });

  test(
      'WA6 edge snaps to the run\'s ends: a side within edgeCaptureWorld of '
      'the run\'s start or end goes onto it; beyond it, the centre stays at '
      'the pointer\'s u (an inside corner of an L)', () {
    for (final deg in attachAngles) {
      final sc = lScene(deg, 75, ja: Justification.left);
      final runs = [
        ...faceRunsOf(sc.doc, sc.walls[0]),
        ...faceRunsOf(sc.doc, sc.walls[1]),
      ];
      final inside = runs
          .singleWhere((r) => r.wall == sc.walls[1] && r.side == FaceSide.left);
      final l = inside.length, half = offBox.width / 2;
      for (final mirrored in const [false, true]) {
        final why = '$deg°${mirrored ? ' mirrored' : ''}';
        expectFlush(
            attach(runs, offBox, at(inside, half + 30, 20), mirrored: mirrored),
            inside,
            offBox,
            half,
            mirrored,
            '$why start');
        expectFlush(
            attach(runs, offBox, at(inside, l - half - 40, 20),
                mirrored: mirrored),
            inside,
            offBox,
            l - half,
            mirrored,
            '$why end');
        expectFlush(
            attach(runs, offBox, at(inside, half + edge + 10, 20),
                mirrored: mirrored),
            inside,
            offBox,
            half + edge + 10,
            mirrored,
            '$why beyond');
      }
    }
  });

  group('neighbours', () {
    late WallBands bands;
    setUp(() => bands = WallBands());
    tearDown(() => bands.dispose());

    test(
        'WA7 edge snaps to a neighbour mirrored on the face (its local left '
        'at its world right, W-14): either side, the smallest shift wins, '
        'and the excluded instance is passed over', () async {
      for (final deg in attachAngles) {
        final sc = freeWallScene(deg, Justification.right);
        final doc = withSymbols(sc.doc);
        final r0 = faceRunsOf(doc, sc.walls.single).first;
        final n =
            placeToilet(doc, standing(r0, toiletBox, 2000, mirrored: true));
        final corner = placeToilet(doc, standing(r0, toiletBox, -160));
        await pumpEventQueue();
        final faces = WallFaces(bands);
        final runs = faces.runsOf(doc);
        final r = runs.singleWhere((x) => x.side == r0.side);
        final i = runs.indexOf(r);
        final list = faces.neighboursOf(doc)[i];
        final why = '$deg°';
        expect([for (final x in list) x.instance], unorderedEquals([n, corner]),
            reason: why);
        final nb = list.singleWhere((x) => x.instance == n);
        expect(nb.lo, closeTo(1800, 1e-7), reason: why);
        expect(nb.hi, closeTo(2200, 1e-7), reason: why);
        final half = offBox.width / 2;
        for (final mirrored in const [false, true]) {
          WallAttachment? go(double u, {Handle? exclude}) =>
              faces.attach(doc, offBox, at(r, u, 25), cap,
                  mirrored: mirrored, edgeCaptureWorld: edge, exclude: exclude);
          final w = '$why${mirrored ? ' mirrored' : ''}';
          // The left side 35 mm right of the neighbour's right end.
          expectFlush(go(2200 + half + 35), r, offBox, 2200 + half, mirrored,
              '$w left side');
          // The right side 25 mm left of the neighbour's left end.
          expectFlush(go(1800 - half - 25), r, offBox, 1800 - half, mirrored,
              '$w right side');
          // Excluded: the centre stays at the pointer.
          expectFlush(go(2200 + half + 35, exclude: n), r, offBox,
              2200 + half + 35, mirrored, '$w excluded');
          // The corner toilet's right end at 40: the left side at 25 is
          // 25 from the run's start and 15 from it; 15 wins.
          expectFlush(go(half + 25), r, offBox, half + 40, mirrored,
              '$w smallest shift');
        }
      }
    });

    test(
        'WA8 who is a neighbour: a toilet flush on the face is; on the '
        'other piece of a T (outside [0, L], W-14), back to back on the '
        'opposite face, turned to face the wall, 300 mm into the room, on '
        'a hidden or a locked layer, scaled, turned 10° about a back corner '
        '(one back end off the line), sheared with unit columns, nested in a '
        'group, or a plain block, it is not', () async {
      for (final deg in attachAngles) {
        final sc = teeScene(deg, 90);
        final doc = withSymbols(sc.doc);
        final hidden = addLayer(doc, 'hidden', visible: false);
        final locked = addLayer(doc, 'locked', locked: true);
        final host = faceRunsOf(doc, sc.walls[0]);
        final butted = [
          for (final side in FaceSide.values)
            if (host.where((r) => r.side == side).length == 2) side
        ].single;
        final pieces = host.where((r) => r.side == butted).toList()
          ..sort((x, y) => x.a.dot(x.t).compareTo(y.a.dot(y.t)));
        final r = pieces[0], beyond = pieces[1];
        final far = host.singleWhere((x) => x.side != butted);
        final ok = placeToilet(doc, standing(r, toiletBox, 600));
        final other = placeToilet(doc, standing(beyond, toiletBox, 900));
        // The opposite face's u for the same place along the wall.
        final back =
            placeToilet(doc, standing(far, toiletBox, uOf(far, at(r, 600, 0))));
        // Turned: local +y along +m, its back edge on the face line, its
        // front in the wall.
        final q = at(r, 1000, 0);
        placeToilet(
            doc,
            placementTransform(
                at: q,
                basePoint: toiletBox.backCentre,
                rotation: (-r.t.x, -r.t.y)));
        // 300 mm into the room.
        final off = standing(r, toiletBox, 1300);
        placeToilet(doc,
            Transform2.translation(r.m.x * 300, r.m.y * 300).multiply(off));
        doc.commands.execute(SetInstanceLayerCommand(
            placeToilet(doc, standing(r, toiletBox, 200)), hidden));
        doc.commands.execute(SetInstanceLayerCommand(
            placeToilet(doc, standing(r, toiletBox, 1500)), locked));
        // Scaled 1.25 about its back-centre: the back edge stays on the
        // face line.
        final c = toiletBox.backCentre;
        placeToilet(
            doc,
            Transform2.translation(r.a.x + r.t.x * 800, r.a.y + r.t.y * 800)
                .multiply(Transform2(r.t.x, r.t.y, -r.t.y, r.t.x, 0, 0))
                .multiply(Transform2.scale(1.25, 1.25))
                .multiply(Transform2.translation(-c.x, -c.y)));
        nestedToilet(doc, standing(r, toiletBox, 400));
        plainBlock(doc, standing(r, toiletBox, 1100));
        // Turned 10° about one back corner (local back-left, then local
        // back-right): that corner stays on the face line, the other back
        // end lifts ~69 mm into the room, the front stays in the room.
        // Orthonormal, overlapping [0, L]: only "both ends on the line"
        // refuses it.
        final front =
            Vector2((toiletBox.left + toiletBox.right) / 2, toiletBox.front);
        final flush = standing(r, toiletBox, 700);
        for (final (x, turn) in [
          (toiletBox.left, -10.0),
          (toiletBox.right, 10.0),
        ]) {
          final pivot = flush.transformPoint(Vector2(x, toiletBox.back));
          final g = Transform2.translation(pivot.x, pivot.y)
              .multiply(Transform2.rotation(turn * math.pi / 180))
              .multiply(Transform2.translation(-pivot.x, -pivot.y))
              .multiply(flush);
          final ends = [
            for (final e in [toiletBox.left, toiletBox.right])
              sOf(r, g.transformPoint(Vector2(e, toiletBox.back)))
          ];
          final why = '$deg° turned about $x';
          // Premises by hand: orthonormal (a proper rotation), one back end
          // on the face line, the other off it, the front in the room.
          expect((g.a * g.a + g.b * g.b - 1).abs(), lessThan(1e-12));
          expect((g.c * g.c + g.d * g.d - 1).abs(), lessThan(1e-12));
          expect((g.a * g.c + g.b * g.d).abs(), lessThan(1e-12));
          expect(ends.map((s) => s.abs()).reduce(math.min), lessThan(1e-9),
              reason: '$why: the pivot on the face');
          expect(ends.reduce(math.max), greaterThan(60),
              reason: '$why: lifted');
          expect(sOf(r, g.transformPoint(front)), greaterThan(500),
              reason: '$why: the front in the room');
          placeToilet(doc, g);
        }
        // Sheared: its columns unit length (the first t, the second −m
        // turned 20°) but not orthogonal, its back edge flush on the face
        // line, its front in the room. Only `|ac + bd|` refuses it.
        final c20 = math.cos(20 * math.pi / 180),
            s20 = math.sin(20 * math.pi / 180);
        final ym =
            Vector2(-r.m.x * c20 + r.m.y * s20, -r.m.x * s20 - r.m.y * c20);
        final shearQ = at(r, 1200, 0);
        final shear = Transform2.translation(shearQ.x, shearQ.y)
            .multiply(Transform2(r.t.x, r.t.y, ym.x, ym.y, 0, 0))
            .multiply(Transform2.translation(-c.x, -c.y));
        // Premises by hand: unit columns, not orthogonal (`ac + bd` is
        // sin 20°), the back edge on the face line, the front in the room.
        expect((shear.a * shear.c + shear.b * shear.d).abs(), greaterThan(0.3),
            reason: '$deg° shear');
        expect(
            (shear.a * shear.a + shear.b * shear.b - 1).abs(), lessThan(1e-12));
        expect(
            (shear.c * shear.c + shear.d * shear.d - 1).abs(), lessThan(1e-12));
        for (final e in [toiletBox.left, toiletBox.right]) {
          expect(sOf(r, shear.transformPoint(Vector2(e, toiletBox.back))).abs(),
              lessThan(1e-9),
              reason: '$deg° shear: back end $e on the face');
        }
        expect(sOf(r, shear.transformPoint(front)), greaterThan(500),
            reason: '$deg° shear: the front in the room');
        placeToilet(doc, shear);
        await pumpEventQueue();

        final faces = WallFaces(bands);
        final runs = faces.runsOf(doc);
        final all = faces.neighboursOf(doc);
        List<Handle> of(FaceRun x) {
          final i = runs.indexWhere((y) =>
              y.wall == x.wall &&
              y.side == x.side &&
              (y.a - x.a).length < 1e-9);
          return [for (final nb in all[i]) nb.instance];
        }

        final why = '$deg°';
        expect(of(r), [ok], reason: '$why: the lower piece');
        expect(of(beyond), [other], reason: '$why: the upper piece');
        expect(of(far), [back], reason: '$why: the opposite face');
      }
    });

    test(
        'WA9 WallFaces is keyed on the bands\' generation: queries over a '
        'cached set rebuild nothing; a change, an invalidate or another '
        'document rebuilds the runs, the neighbours and the boxes', () async {
      final sc = freeWallScene(30, Justification.centre);
      final doc = withSymbols(sc.doc);
      final faces = WallFaces(bands);
      final runs = faces.runsOf(doc);
      expect(runs, hasLength(2));
      expect(faces.builds, 1);
      final r = runs.first;
      for (var k = 0; k < 5; k++) {
        expect(
            faces.attach(doc, toiletBox, at(r, 900.0 + k, 10), cap,
                mirrored: false, edgeCaptureWorld: edge),
            isNotNull);
      }
      expect(identical(faces.runsOf(doc), runs), isTrue);
      expect(
          identical(faces.neighboursOf(doc), faces.neighboursOf(doc)), isTrue);
      expect(faces.builds, 1);

      // A second wall: seen once the change is delivered.
      final h2 = doc.handleSeed.next();
      final s2 = farAt(-2400.5, -1800.25);
      doc.commands.execute(addWall(
          doc, h2, s2, polar(s2, -112.5, 2500), 120, Justification.left,
          at: attachGroup(h2.value)));
      await pumpEventQueue();
      expect(faces.runsOf(doc), hasLength(4));
      expect(faces.builds, 2);

      // A symbol placed on the first face: a neighbour once delivered.
      final n = placeToilet(doc, standing(r, toiletBox, 1000));
      await pumpEventQueue();
      final i = faces
          .runsOf(doc)
          .indexWhere((x) => x.wall == r.wall && x.side == r.side);
      expect([for (final x in faces.neighboursOf(doc)[i]) x.instance], [n]);
      expect(faces.builds, 3);

      // The box of a document definition: memoised, then cleared on a
      // change (the cistern removed: the back falls from 700 to 500).
      final def = (doc.tree[n]! as InstanceNode).definition;
      final box = faces.boxOf(doc, def);
      expect(box, toiletBox);
      expect(identical(faces.boxOf(doc, def), box), isTrue);
      final cistern = [
        for (final slot in doc.entities.liveSlots)
          if (doc.entities.ownerAt(slot) == def &&
              doc.entities.kindAt(slot) == EntityKind.polyline)
            doc.entities.handleAt(slot)
      ].first;
      doc.commands.execute(RemoveEntityCommand(cistern));
      await pumpEventQueue();
      expect(faces.boxOf(doc, def)!.back, 500);
      expect(faces.builds, 4);

      // An invalidate (a tool's own commit, D6) rebuilds at once.
      bands.invalidate();
      faces.runsOf(doc);
      expect(faces.builds, 5);

      // Another document rebuilds.
      final other = freeWallScene(-112.5, Justification.right).doc;
      expect(faces.runsOf(other), hasLength(2));
      expect(faces.builds, 6);
    });

    test('WA10 WallFaces asks the host predicate: a refused wall has no runs',
        () {
      final sc = attachScene([
        (farAt(0, 0), polar(farAt(0, 0), 30, 3000), 150, Justification.left),
        (
          farAt(-500, -2500),
          polar(farAt(-500, -2500), -112.5, 2000),
          200,
          Justification.right
        ),
      ]);
      final asked = <Handle>[];
      final faces = WallFaces(bands, accept: (doc, h) {
        asked.add(h);
        return h != sc.walls[0];
      });
      final runs = faces.runsOf(sc.doc);
      expect(asked, sc.walls);
      expect([for (final r in runs) r.wall], [sc.walls[1], sc.walls[1]]);
    });
  });

  test(
      'WA11 the run must hold the symbol (D4 step 2): a wall shorter than '
      'the symbol does not attach it; a symbol that fits does', () {
    for (final deg in attachAngles) {
      final s = farAt(812.5, -431.25);
      final sc =
          attachScene([(s, polar(s, deg, 700), 150, Justification.left)]);
      final runs = faceRunsOf(sc.doc, sc.walls.single);
      for (final r in runs) {
        final why = '$deg° ${r.side.name}';
        expect(r.length, closeTo(700, 1e-9), reason: why);
        expect(attach(runs, offBox, at(r, 350, 10)), isNull, reason: why);
        expectFlush(attach(runs, toiletBox, at(r, 350, 10)), r, toiletBox, 350,
            false, why);
      }
    }
  });

  test(
      'WA12 the niche (S-4, T-6): a run 2e-10 shorter than the symbol holds '
      'it within wallJoin.linear and centres it at exactly L/2; 2e-6 '
      'shorter does not hold it', () {
    for (final deg in attachAngles) {
      final sc = freeWallScene(deg, Justification.centre);
      for (final r0 in faceRunsOf(sc.doc, sc.walls.single)) {
        FaceRun cut(double l) => FaceRun(
            a: r0.a,
            t: r0.t,
            m: r0.m,
            length: l,
            thickness: r0.thickness,
            wall: r0.wall,
            side: r0.side);
        final w = offBox.width;
        final r = cut(w - 2e-10);
        final why = '$deg° ${r.side.name}';
        expect(r.length < w, isTrue, reason: why);
        for (final mirrored in const [false, true]) {
          for (final u in [-30.0, r.length * 0.3, r.length + 20]) {
            final att = attach([r], offBox, at(r, u, 15), mirrored: mirrored);
            expect(att, isNotNull, reason: '$why u $u');
            final half = r.length / 2;
            expect([
              att!.q.x,
              att.q.y
            ], [
              r.a.x + r.t.x * half,
              r.a.y + r.t.y * half
            ], reason: '$why u $u: q at exactly L/2');
          }
        }
        final short = cut(w - 2e-6);
        expect(attach([short], offBox, at(short, 400, 15)), isNull,
            reason: why);
      }
    }
  });

  test(
      'WA13 the clamp (D4 step 4): a pointer near a run\'s end, beyond the '
      'edge capture, keeps the symbol within the run', () {
    for (final deg in attachAngles) {
      final sc = freeWallScene(deg, Justification.left, mirrored: true);
      final runs = faceRunsOf(sc.doc, sc.walls.single);
      for (final r in runs) {
        final half = offBox.width / 2, l = r.length;
        final why = '$deg° ${r.side.name}';
        expectFlush(attach(runs, offBox, at(r, half - edge - 20, 10)), r,
            offBox, half, false, '$why start');
        expectFlush(attach(runs, offBox, at(r, -60, 10)), r, offBox, half,
            false, '$why before the start');
        expectFlush(attach(runs, offBox, at(r, l - half + edge + 20, 10)), r,
            offBox, l - half, false, '$why end');
      }
    }
  });

  test(
      'WA14 M-09c-n\'s exception: on an axis-aligned wall (its group not '
      'turned) no component of the attached transform is -0.0', () {
    var zeros = 0;
    for (final dir in [
      Vector2(3600, 0),
      Vector2(0, 3600),
      Vector2(-3600, 0),
      Vector2(0, -3600)
    ]) {
      final s = farAt(1234.5, 678.25);
      final sc = attachScene([(s, s + dir, 150, Justification.centre)],
          rotations: [0]);
      final runs = faceRunsOf(sc.doc, sc.walls.single);
      for (final r in runs) {
        if (r.t.x == 0 || r.t.y == 0) zeros++;
        for (final mirrored in const [false, true]) {
          final att =
              attach(runs, toiletBox, at(r, 1500, 10), mirrored: mirrored);
          final g = att!.transform;
          final why = '$dir ${r.side.name} t ${r.t}';
          for (final v in [g.a, g.b, g.c, g.d, g.e, g.f]) {
            expect(v == 0 && v.isNegative, isFalse, reason: '$why: $g');
          }
        }
      }
    }
    // Premise: every run is axis-aligned (a zero in t).
    expect(zeros, 8);
  });

  test(
      'WA15 the tie at a straight joint (D4 step 1): two collinear walls '
      'meet; at the joint both faces\' runs have the same |s| and the same '
      'distance to [0, L], and the lower wall handle wins', () {
    for (final deg in attachAngles) {
      final s = farAt(-640.5, 1210.25), j = polar(s, deg, 2500);
      final sc = attachScene([
        (j, polar(j, deg, 1800), 150, Justification.left),
        (s, j, 150, Justification.left),
      ]);
      final (hb, ha) = (sc.walls[0], sc.walls[1]);
      final runs = [
        ...faceRunsOf(sc.doc, ha),
        ...faceRunsOf(sc.doc, hb),
      ];
      for (final side in FaceSide.values) {
        final ra = runs.singleWhere((r) => r.wall == ha && r.side == side);
        final rb = runs.singleWhere((r) => r.wall == hb && r.side == side);
        final why = '$deg° ${side.name}';
        // Premise: the runs meet at the joint, on one line: A's end there
        // is B's start, or B's end is A's start (t depends on the face).
        final uj = uOf(ra, j) < ra.length / 2 ? 0.0 : ra.length;
        final joint = at(ra, uj, 0);
        final onB = uOf(rb, joint);
        expect(sOf(rb, joint).abs(), lessThan(1e-9), reason: why);
        expect(onB.abs() < 1e-7 || (onB - rb.length).abs() < 1e-7, isTrue,
            reason: '$why: u on B $onB');
        final p = Vector2(joint.x + ra.m.x * 20, joint.y + ra.m.y * 20);
        expect(hb.value < ha.value, isTrue, reason: why);
        final att = attach(runs, toiletBox, p);
        expect(att, isNotNull, reason: why);
        expect(identical(att!.run, rb), isTrue,
            reason: '$why: the lower handle (${hb.value}) wins, got '
                '${att.run.wall.value}');
      }
    }
  });

  test(
      'WA16 the face tie (D4 step 1): a pointer on the midline of a band '
      'whose two faces are both candidates there (each run widened by 1e-7 '
      'so the midline is inside both halves): the left face wins', () {
    for (final deg in attachAngles) {
      for (final grp in groups) {
        final sc = freeWallScene(deg, Justification.right,
            mirrored: grp.$1, scale: grp.$2);
        final runs = [
          for (final r in faceRunsOf(sc.doc, sc.walls.single))
            FaceRun(
                a: r.a,
                t: r.t,
                m: r.m,
                length: r.length,
                thickness: r.thickness + 1e-7,
                wall: r.wall,
                side: r.side),
        ];
        final left = runs.singleWhere((r) => r.side == FaceSide.left);
        final right = runs.singleWhere((r) => r.side == FaceSide.right);
        final p = at(left, 1700, -left.thickness / 2 + 0.5e-7);
        final why = '$deg° ${groupName(grp)}';
        expect((sOf(left, p).abs() - sOf(right, p).abs()).abs(), lessThan(1e-6),
            reason: why);
        expect(identical(attach(runs, toiletBox, p)!.run, left), isTrue,
            reason: why);
        expect(
            identical(attach(runs.reversed.toList(), toiletBox, p)!.run, left),
            isTrue,
            reason: '$why: in either order');
      }
    }
  });

  test(
      'WA17 the edge-snap tie (D4 step 4): two neighbours whose snaps shift '
      'u by exactly −16 and +16: the smaller resulting u wins, in either '
      'order', () {
    for (final deg in attachAngles) {
      for (final grp in groups.take(2)) {
        final sc = freeWallScene(deg, Justification.left, mirrored: grp.$1);
        final runs = faceRunsOf(sc.doc, sc.walls.single);
        for (final r in runs) {
          final p = at(r, 1500.25, 20);
          // The u the code computes: `(p − a)·t` in the same arithmetic,
          // bitwise.
          final u0 = uOf(r, p);
          final half = toiletBox.width / 2;
          // Every value below lies in [1024, 2048), one binade with u0, so
          // each sum and difference is exact.
          final hi = u0 - 16 - half, lo = u0 + 16 + half;
          final why = '$deg° ${groupName(grp)} ${r.side.name}';
          expect((hi + half) - u0, -16, reason: '$why: the left snap');
          expect((lo - half) - u0, 16, reason: '$why: the right snap');
          // Premise: the run's ends are beyond the edge capture.
          expect(u0 - half, greaterThan(edge), reason: why);
          expect(r.length - half - u0, greaterThan(edge), reason: why);
          final left = (lo: hi - 400, hi: hi, instance: Handle(9001));
          final right = (lo: lo, hi: lo + 400, instance: Handle(9002));
          for (final order in [
            [left, right],
            [right, left],
          ]) {
            for (final mirrored in const [false, true]) {
              final att = attachToWall([r], toiletBox, p, cap,
                  mirrored: mirrored,
                  neighbours: [order],
                  edgeCaptureWorld: edge);
              expectFlush(
                  att,
                  r,
                  toiletBox,
                  u0 - 16,
                  mirrored,
                  '$why ${order.first == left ? 'left first' : 'right first'}'
                  '${mirrored ? ' mirrored' : ''}');
            }
          }
        }
      }
    }
  });

  test(
      'WA18 orthonormal (W-8): a rotation and a mirror are; a scale and a '
      'shear with unit-length columns are not', () {
    final c = math.cos(20 * math.pi / 180), s = math.sin(20 * math.pi / 180);
    expect(isOrthonormal(Transform2(c, s, -s, c, 1e5, -7e4)), isTrue);
    expect(isOrthonormal(Transform2(-c, -s, -s, c, 1e5, -7e4)), isTrue);
    expect(isOrthonormal(Transform2(1, 0, s, c, 1e5, -7e4)), isFalse);
    expect(isOrthonormal(Transform2(c, s, 0, 1, 0, 0)), isFalse);
    expect(isOrthonormal(Transform2(1.5 * c, 1.5 * s, -s, c, 0, 0)), isFalse);
    expect(isOrthonormal(Transform2(c, s, -1.5 * s, 1.5 * c, 0, 0)), isFalse);
  });
}

/// A layer added to [doc], visible or [locked] as asked.
Handle addLayer(DraftDocument doc, String name,
    {bool visible = true, bool locked = false}) {
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final h = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
    handle: h,
    name: name,
    color: const IndexedColor(3),
    linetype: zero.linetype,
    lineweight: zero.lineweight,
    transparency: zero.transparency,
    visible: visible,
    locked: locked,
  )));
  return h;
}

/// A toilet instance with transform [g] inside a group at the identity
/// under the root: not root-level.
void nestedToilet(DraftDocument doc, Transform2 g) {
  final placed = placeToilet(doc, Transform2.identity());
  final def = (doc.tree[placed]! as InstanceNode).definition;
  final group = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [])),
    AddNodeCommand(InstanceNode(
        handle: doc.handleSeed.next(),
        parent: group,
        definition: def,
        layer: ReservedHandles.layerZero,
        transform: g)),
  ], label: 'Nested toilet'));
}

/// A plain block (no [SymbolComponent]) with the toilet's cistern line
/// and front, placed with transform [g] at the root.
void plainBlock(DraftDocument doc, Transform2 g) {
  final def = doc.handleSeed.next();
  EntityRecord leaf() => EntityRecord(
        handle: doc.handleSeed.next(),
        owner: def,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byBlockLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByBlockColor(),
        lineweight: kByBlock,
        transparency: kByBlock,
        flags: 0,
      );
  doc.commands.execute(CompoundCommand([
    AddDefinitionCommand(Definition(
        handle: def,
        name: 'plain',
        basePoint: Vector2(200, 0),
        children: const [])),
    AddEntityCommand(
        record: leaf(),
        payload: linePayload(Vector2(0, 700), Vector2(400, 700))),
    AddEntityCommand(
        record: leaf(), payload: linePayload(Vector2(0, 0), Vector2(400, 0))),
    AddNodeCommand(InstanceNode(
        handle: doc.handleSeed.next(),
        parent: doc.rootHandle,
        definition: def,
        layer: ReservedHandles.layerZero,
        transform: g)),
  ], label: 'Plain block'));
}
