// Spec 09c D4, plan 09c-1 Task 6: a differential / property check of
// `attachToWall` and `WallFaces`, adopted from the Task 6 review. Over every
// scene of `wall_attach_fixture.dart` (free walls at 30°, −112.5° and 47.3°,
// every justification, plain, mirrored and scaled groups; Ls; Ts at 90° and
// 70°; the short-base fallback; an X), random pointers with a fixed seed are
// checked against an independent candidate set, ranking, snap and clamp
// written here, never the code under test. WP1 goes red on M-09c-b, -af and
// -i and on `|s|` ranked exactly (no tolerance); WP2 on M-09c-b and -h.
import 'dart:io';
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall_bands.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_box.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_component.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/symbols/wall_attach.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_attach_fixture.dart';

/// The camera scale (px per mm), never 1: the attach capture 80 mm, the
/// edge capture 50 mm, as in `wall_attach_test.dart`.
const double scale = 0.2;
const double cap = 16 / scale, edge = 10 / scale;

/// Random pointers per scene in WP1.
const int queriesPerScene = 100;

final SymbolLibrary library = SymbolLibrary.decode(
    File('assets/library/furniture.jetlib').readAsBytesSync());
final SymbolEntry toilet =
    library.entries.firstWhere((e) => e.key == 'bath.toilet');
final SymbolBox toiletBox = boxOfEntry(toilet)!;

/// A box with no side at 0 and its centre off the origin in both axes.
const SymbolBox offBox =
    SymbolBox(left: 37.5, right: 937.5, front: -120.25, back: 480.75);

Vector2 at(FaceRun r, double u, double s) =>
    Vector2(r.a.x + r.t.x * u + r.m.x * s, r.a.y + r.t.y * u + r.m.y * s);
double uOf(FaceRun r, Vector2 p) => (p - r.a).dot(r.t);
double sOf(FaceRun r, Vector2 p) => (p - r.a).dot(r.m);

/// Every scene, named.
List<(String, AttachScene)> scenes() {
  final out = <(String, AttachScene)>[];
  for (final deg in [...attachAngles, 47.3]) {
    for (final j in Justification.values) {
      for (final (mir, sc) in const [(false, 1.0), (true, 1.0), (false, 1.5)]) {
        out.add((
          'free $deg ${j.name} m$mir s$sc',
          freeWallScene(deg, j, mirrored: mir, scale: sc)
        ));
      }
      out.add(('L $deg ${j.name}', lScene(deg, 75, ja: j, jb: j)));
      out.add((
        'L mirrored scaled $deg ${j.name}',
        lScene(deg, -100, ja: j, mirrored: true, scale: 1.5)
      ));
    }
    for (final (mir, sc) in const [(false, 1.0), (true, 1.0), (true, 1.5)]) {
      out.add(
          ('T $deg m$mir s$sc', teeScene(deg, 90, mirrored: mir, scale: sc)));
      out.add(
          ('T70 $deg m$mir s$sc', teeScene(deg, 70, mirrored: mir, scale: sc)));
      out.add((
        'fallback $deg m$mir s$sc',
        shortBaseScene(deg, mirrored: mir, scale: sc)
      ));
    }
    out.add(('X $deg', crossScene(deg, 60)));
  }
  return out;
}

/// [b]'s four corners through [g]: back-left, back-right, front-right,
/// front-left (local).
List<Vector2> corners(Transform2 g, SymbolBox b) => [
      g.transformPoint(Vector2(b.left, b.back)),
      g.transformPoint(Vector2(b.right, b.back)),
      g.transformPoint(Vector2(b.right, b.front)),
      g.transformPoint(Vector2(b.left, b.front)),
    ];

void main() {
  test(
      'WP1 property: the winner ranks first among an independent candidate '
      'set (null only when none, or every first-ranked run is too short); '
      'the symbol stands flush, its front in the room, within its run; the '
      'linear part is exactly ±t, −m; the mirror leaves the footprint; u '
      'matches an independent snap and clamp', () {
    final rnd = math.Random(60601);
    var tried = 0, attached = 0, nulls = 0;
    final all = scenes();
    expect(all, hasLength(75));
    for (final (name, sc) in all) {
      final runs = [for (final h in sc.walls) ...faceRunsOf(sc.doc, h)];
      expect(runs, isNotEmpty, reason: name);
      final none = [for (final _ in runs) const <FaceNeighbour>[]];
      for (var k = 0; k < queriesPerScene; k++) {
        final r0 = runs[rnd.nextInt(runs.length)];
        final u0 = -cap * 1.2 + rnd.nextDouble() * (r0.length + 2.4 * cap);
        final s0 = -r0.thickness * 0.6 +
            rnd.nextDouble() * (r0.thickness * 0.6 + cap * 1.2);
        final p = at(r0, u0, s0);
        final box = rnd.nextBool() ? toiletBox : offBox;
        final mirrored = rnd.nextBool();
        tried++;
        final att = attachToWall(runs, box, p, cap,
            mirrored: mirrored, neighbours: none, edgeCaptureWorld: edge);
        final cands = [
          for (final r in runs)
            if (sOf(r, p) >= -r.thickness / 2 &&
                sOf(r, p) <= cap &&
                uOf(r, p) >= -cap &&
                uOf(r, p) <= r.length + cap)
              r
        ];
        final why = '$name k$k p$p';
        if (cands.isEmpty) {
          expect(att, isNull, reason: why);
          nulls++;
          continue;
        }
        double gap(FaceRun r) {
          final u = uOf(r, p);
          return u < 0 ? -u : (u > r.length ? u - r.length : 0.0);
        }

        final minS = cands.map((r) => sOf(r, p).abs()).reduce(math.min);
        final first =
            cands.where((r) => sOf(r, p).abs() <= minS + 1e-6).toList();
        final minG = first.map(gap).reduce(math.min);
        final tied = first.where((r) => gap(r) <= minG + 1e-6).toList();
        final w = box.right - box.left;
        if (att == null) {
          nulls++;
          expect(tied.any((r) => w <= r.length + 1e-6), isFalse, reason: why);
          continue;
        }
        attached++;
        final r = att.run;
        expect(tied.any((x) => identical(x, r)), isTrue,
            reason: '$why: winner $r not first-ranked; tied $tied');
        expect(w <= r.length + 1e-6, isTrue, reason: why);
        final g = att.transform;
        final mag = math.max(p.x.abs(), p.y.abs());
        for (final x in [box.left, box.right]) {
          expect(sOf(r, g.transformPoint(Vector2(x, box.back))).abs(),
              lessThanOrEqualTo(1e-9 * mag),
              reason: '$why: back end $x on the face');
        }
        expect(
            sOf(
                r,
                g.transformPoint(
                    Vector2((box.left + box.right) / 2, box.front))),
            closeTo(box.back - box.front, 1e-8),
            reason: '$why: the front in the room');
        for (final c in corners(g, box)) {
          final u = uOf(r, c);
          expect(u, greaterThanOrEqualTo(-1e-6), reason: '$why: in the run');
          expect(u, lessThanOrEqualTo(r.length + 1e-6),
              reason: '$why: in the run');
          expect(sOf(r, c), greaterThanOrEqualTo(-1e-8),
              reason: '$why: in the room');
        }
        final sx = mirrored ? -1.0 : 1.0;
        expect([
          g.a,
          g.b,
          g.c,
          g.d
        ], [
          sx * r.t.x + 0.0,
          sx * r.t.y + 0.0,
          -r.t.y + 0.0,
          r.t.x + 0.0
        ], reason: '$why: the linear part');
        // The mirror does not move the footprint: the corners swap pairwise.
        final other = attachToWall(runs, box, p, cap,
            mirrored: !mirrored, neighbours: none, edgeCaptureWorld: edge)!;
        expect(identical(other.run, r), isTrue, reason: why);
        final a1 = corners(g, box), a2 = corners(other.transform, box);
        for (final (i, j) in const [(0, 1), (1, 0), (2, 3), (3, 2)]) {
          expect((a1[i] - a2[j]).length, lessThan(1e-8),
              reason: '$why: the mirror');
        }
        // An independent u: the snap to the run's ends, then the clamp.
        var u = uOf(r, p);
        double? best;
        for (final target in [w / 2, r.length - w / 2]) {
          final d = target - u;
          if (d.abs() <= edge &&
              (best == null ||
                  d.abs() < best.abs() ||
                  (d.abs() == best.abs() && d < best))) {
            best = d;
          }
        }
        if (best != null) u += best;
        u = w < r.length ? u.clamp(w / 2, r.length - w / 2) : r.length / 2;
        expect(uOf(r, att.q), closeTo(u, 1e-7), reason: '$why: u');
        expect(sOf(r, att.q).abs(), lessThan(1e-8), reason: '$why: q');
      }
    }
    expect(tried, 75 * queriesPerScene);
    // Both outcomes are exercised in bulk.
    expect(attached, greaterThan(tried * 3 ~/ 4));
    expect(nulls, greaterThan(tried ~/ 20));
  });

  test(
      'WP2 loop closure: a toilet placed with attachToWall\'s transform is a '
      'neighbour of its own run in WallFaces, [u − W/2, u + W/2]; a second '
      'symbol 30 mm past it snaps flush to it, and stays at the pointer '
      'when the first is excluded', () async {
    final rnd = math.Random(60602);
    var closed = 0;
    for (final (name, sc) in scenes()) {
      final doc = sc.doc;
      SymbolComponent.register(doc.components);
      final bands = WallBands();
      addTearDown(bands.dispose);
      final faces = WallFaces(bands);
      final runs = faces.runsOf(doc);
      final long = [
        for (final r in runs)
          if (r.length > 2000) r
      ];
      if (long.isEmpty) continue;
      final r = long[rnd.nextInt(long.length)];
      final mirrored = rnd.nextBool();
      final u0 = r.length / 2 + (rnd.nextDouble() - 0.5) * 200;
      final att = faces.attach(doc, toiletBox, at(r, u0, 20), cap,
          mirrored: mirrored, edgeCaptureWorld: edge);
      expect(att, isNotNull, reason: name);
      if (!identical(att!.run, r)) continue;
      final cmd = placeSymbol(doc, toilet,
          at: Vector2.zero(), transform: att.transform);
      doc.commands.execute(cmd);
      final inst = (cmd.children.last as AddNodeCommand).node.handle;
      await pumpEventQueue();
      final runs2 = faces.runsOf(doc);
      final i = runs2.indexWhere((x) =>
          x.wall == r.wall && x.side == r.side && (x.a - r.a).length < 1e-9);
      expect(i, greaterThanOrEqualTo(0), reason: name);
      final nb = faces.neighboursOf(doc)[i];
      expect([for (final n in nb) n.instance], contains(inst),
          reason: '$name m$mirrored: the placed symbol is not a neighbour');
      final me = nb.singleWhere((n) => n.instance == inst);
      final uq = uOf(r, att.q);
      expect(me.lo, closeTo(uq - toiletBox.width / 2, 1e-6), reason: name);
      expect(me.hi, closeTo(uq + toiletBox.width / 2, 1e-6), reason: name);
      // A second symbol (offBox) 30 mm right of it snaps to touch it.
      final half = offBox.width / 2;
      final mir2 = rnd.nextBool();
      final p2 = at(r, me.hi + half + 30, 15);
      final att2 = faces.attach(doc, offBox, p2, cap,
          mirrored: mir2, edgeCaptureWorld: edge);
      expect(att2, isNotNull, reason: name);
      // Unless the run's end is the nearer snap.
      if (me.hi + offBox.width + 60 < r.length) {
        expect(uOf(r, att2!.q), closeTo(me.hi + half, 1e-6),
            reason: '$name: the second snaps');
      }
      // Excluded, the second does not snap.
      final att3 = faces.attach(doc, offBox, p2, cap,
          mirrored: mir2, edgeCaptureWorld: edge, exclude: inst);
      if (me.hi + offBox.width + 30 + edge < r.length) {
        expect(uOf(r, att3!.q), closeTo(me.hi + half + 30, 1e-6),
            reason: '$name: excluded');
      }
      closed++;
    }
    expect(closed, greaterThan(20));
  });
}
