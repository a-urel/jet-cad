// The alignment-guide solver (alignment guides spec, "Candidates on one
// axis"). Pure Dart: no widget rig. Every fixture coordinate is shifted by
// (_ox, _oy) so no box sits at the origin.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;
import 'package:jet_cad_2d_plan/src/guides/guide_solver.dart';

const double _ox = 5000;
const double _oy = -3200;

/// A box [x0..x1] x [y0..y1] in fixture coordinates.
List<double> _box(double x0, double x1, double y0, double y1) =>
    [x0 + _ox, y0 + _oy, x1 + _ox, y1 + _oy];

GuideReferences _refs(List<List<double>> boxes, [List<int>? handles]) {
  final f = Float64List(4 * boxes.length);
  for (var i = 0; i < boxes.length; i++) {
    for (var k = 0; k < 4; k++) {
      f[4 * i + k] = boxes[i][k];
    }
  }
  return GuideReferences(f, [
    for (var i = 0; i < boxes.length; i++)
      Handle(handles == null ? i + 1 : handles[i]),
  ]);
}

GuideSolution _solve(
  GuideReferences refs,
  List<double> mover, {
  double aperture = 3.0,
  bool freeX = true,
  bool freeY = true,
  double fallbackDx = 0.75,
  double fallbackDy = -0.25,
  Set<Handle> moving = const {},
}) {
  final out = GuideSolution();
  solveGuides(refs,
      minX: mover[0],
      minY: mover[1],
      maxX: mover[2],
      maxY: mover[3],
      aperture: aperture,
      freeX: freeX,
      freeY: freeY,
      fallbackDx: fallbackDx,
      fallbackDy: fallbackDy,
      moving: moving,
      out: out);
  return out;
}

/// The lines as [axis, coord, from, to] rows.
List<List<double>> _lines(GuideSolution s) => [
      for (var i = 0; i < s.lineCount; i++)
        [for (var k = 0; k < 4; k++) s.lines[4 * i + k]],
    ];

List<List<double>> _marks(GuideSolution s) => [
      for (var i = 0; i < s.markCount; i++)
        [for (var k = 0; k < 4; k++) s.marks[4 * i + k]],
    ];

Matcher _near(double v) => closeTo(v, 1e-9);

void _expectRow(List<double> row, List<double> want) {
  expect(row.length, want.length);
  for (var i = 0; i < want.length; i++) {
    expect(row[i], _near(want[i]), reason: 'column $i of $row');
  }
}

// Mover y range that captures nothing against the y ranges used below.
final _quietY = (25.0, 44.0);

void main() {
  group('edges', () {
    final ref = _refs([_box(100, 200, 0, 50)]);

    test('x edge within the aperture captures, with a vertical line', () {
      final s = _solve(ref, _box(202.5, 302.5, 1000, 1040));
      expect(s.capturedX, isTrue);
      expect(s.dx, _near(-2.5));
      expect(s.kindX, GuideKind.edge);
      expect(s.refX, const Handle(1));
      expect(s.capturedY, isFalse);
      expect(s.dy, -0.25);
      expect(s.kindY, isNull);
      expect(s.refY, isNull);
      expect(s.lineCount, 1);
      // From the reference's top (y 0) to the moving box's bottom (y 1040,
      // shifted by y's fallback, which is the box the guide is drawn for).
      _expectRow(_lines(s).single, [0, 200 + _ox, 0 + _oy, 1039.75 + _oy]);
      expect(s.markCount, 0);
    });

    test('just outside the aperture does not capture', () {
      final s = _solve(ref, _box(203.5, 303.5, 1000, 1040));
      expect(s.capturedX, isFalse);
      expect(s.dx, 0.75);
      expect(s.lineCount, 0);
    });

    test('an offset exactly on the aperture captures (<=, not <)', () {
      final s = _solve(ref, _box(203, 303, 1000, 1040));
      expect(s.capturedX, isTrue);
      expect(s.dx, _near(-3));
    });

    test('centre on y captures with a horizontal line', () {
      final r = _refs([_box(0, 40, 0, 100)]);
      final s = _solve(r, _box(900, 960, 41, 61));
      expect(s.capturedY, isTrue);
      expect(s.dy, _near(-1));
      expect(s.kindY, GuideKind.centre);
      expect(s.capturedX, isFalse);
      final lines = _lines(s);
      expect(lines.length, 1);
      _expectRow(lines.single, [1, 50 + _oy, 0 + _ox, 960.75 + _ox]);
    });

    test('a reference in the moving set is skipped', () {
      final s = _solve(ref, _box(202.5, 302.5, 1000, 1040),
          moving: {const Handle(1)});
      expect(s.capturedX, isFalse);
      expect(s.dx, 0.75);
      expect(s.lineCount, 0);
    });

    test('a non-free axis never captures and draws nothing', () {
      final s = _solve(ref, _box(202.5, 302.5, 1000, 1040), freeX: false);
      expect(s.capturedX, isFalse);
      expect(s.dx, 0.75);
      expect(s.lineCount, 0);
      final y = _solve(_refs([_box(0, 40, 0, 100)]), _box(900, 960, 41, 61),
          freeY: false);
      expect(y.capturedY, isFalse);
      expect(y.dy, -0.25);
      expect(y.lineCount, 0);
    });
  });

  group('ties', () {
    test('an edge beats a centre pair of equal offset', () {
      // Edge: mover max 199 -> ref max 200 (o = +1, pair 8). Centre pair:
      // mover min 151 -> ref centre 150 (o = -1, pair 1). Pair order and the
      // sign rule would both prefer the centre pair; only the kind rank
      // makes the edge win.
      final r = _refs([_box(100, 200, 0, 50)]);
      final s = _solve(r, _box(151, 199, 1000, 1040));
      expect(s.kindX, GuideKind.edge);
      expect(s.dx, _near(1));
    });

    test('two references at one position: lower handle, one merged line', () {
      final r = _refs([
        _box(100, 200, 0, 50),
        _box(100, 200, 300, 350),
      ], [
        7,
        3
      ]);
      final s = _solve(r, _box(202.5, 302.5, 1000, 1040));
      expect(s.refX, const Handle(3));
      expect(s.lineCount, 1);
      // The merged extent runs to the farthest aligned reference.
      _expectRow(_lines(s).single, [0, 200 + _ox, 0 + _oy, 1039.75 + _oy]);
    });

    test('the smaller offset wins over a larger one', () {
      final r = _refs([_box(100, 200, 0, 50), _box(190, 201.5, 300, 350)]);
      final s = _solve(r, _box(203, 303, 1000, 1040));
      // 201.5 is 1.5 away; 200 is 3 away.
      expect(s.dx, _near(-1.5));
      expect(s.refX, const Handle(2));
    });
  });

  group('equal spacing', () {
    final (qy0, qy1) = _quietY;

    test('between: centres the box in the gap, two marks', () {
      final r = _refs([_box(0, 100, 0, 60), _box(300, 400, 0, 60)]);
      final s = _solve(r, _box(149, 249, qy0, qy1));
      expect(s.capturedX, isTrue);
      expect(s.dx, _near(1));
      expect(s.kindX, GuideKind.between);
      expect(s.refX, const Handle(1));
      expect(s.capturedY, isFalse);
      expect(s.lineCount, 0);
      final m = _marks(s);
      expect(m.length, 2);
      // The box ends up at [150..250]; each gap is 50 long.
      _expectRow(m[0], [0, 100 + _ox, 150 + _ox, 34.25 + _oy]);
      _expectRow(m[1], [0, 250 + _ox, 300 + _ox, 34.25 + _oy]);
    });

    test('between is refused when the box does not fit the gap', () {
      final r = _refs([_box(0, 100, 0, 60), _box(300, 400, 0, 60)]);
      final s = _solve(r, _box(20, 270, qy0, qy1));
      expect(s.capturedX, isFalse);
      expect(s.dx, 0.75);
      expect(s.markCount, 0);
    });

    test('between is refused when a gap would be <= epsilon', () {
      // A box exactly as wide as the gap: both gaps are zero.
      final r = _refs([_box(0, 100, 0, 60), _box(300, 400, 0, 60)]);
      final s = _solve(r, _box(100, 300, qy0, qy1));
      expect(s.kindX, GuideKind.edge);
      expect(s.markCount, 0);
    });

    test('continuing: repeats the gap beyond the neighbour', () {
      final r = _refs([_box(0, 100, 0, 60), _box(150, 250, 10, 50)]);
      final s = _solve(r, _box(302, 402, qy0, qy1));
      expect(s.capturedX, isTrue);
      expect(s.dx, _near(-2));
      expect(s.kindX, GuideKind.continuing);
      // The lower handle of the pair (A = 1, L = 2).
      expect(s.refX, const Handle(1));
      final m = _marks(s);
      expect(m.length, 2);
      _expectRow(m[0], [0, 100 + _ox, 150 + _ox, 30 + _oy]);
      _expectRow(m[1], [0, 250 + _ox, 300 + _ox, 34.25 + _oy]);
    });

    test('continuing on the right mirrors the left', () {
      final r = _refs([_box(300, 400, 10, 50), _box(450, 550, 0, 60)]);
      final s = _solve(r, _box(148, 248, qy0, qy1));
      // L is absent; R = [300..400], R2 = [450..550], gap 50: the box's
      // max should be 250.
      expect(s.kindX, GuideKind.continuing);
      expect(s.dx, _near(2));
      final m = _marks(s);
      expect(m.length, 2);
      _expectRow(m[0], [0, 250 + _ox, 300 + _ox, 34.25 + _oy]);
      _expectRow(m[1], [0, 400 + _ox, 450 + _ox, 30 + _oy]);
    });

    test('touching neighbours never give a continuing capture or a mark', () {
      final r = _refs([_box(0, 100, 0, 60), _box(100, 200, 10, 50)]);
      final s = _solve(r, _box(200.5, 300.5, qy0, qy1));
      expect(s.kindX, GuideKind.edge);
      expect(s.dx, _near(-0.5));
      expect(s.markCount, 0);
    });

    test('a spacing capture whose row is lost after y snaps falls back', () {
      // x: between L and R would give +1. y: the mover's bottom is 1 above
      // the refs' top edge row, so y snaps an edge (+1), which leaves the
      // row at zero overlap. x falls back to its best edge candidate (E,
      // +2.5) from the same pass.
      final r = _refs([
        _box(0, 100, 0, 61),
        _box(300, 400, 0, 61),
        _box(251.5, 260, 1000, 1100),
      ]);
      final s = _solve(r, _box(149, 249, 60, 80));
      expect(s.capturedY, isTrue);
      expect(s.kindY, GuideKind.edge);
      expect(s.dy, _near(1));
      expect(s.capturedX, isTrue);
      expect(s.kindX, GuideKind.edge);
      expect(s.refX, const Handle(3));
      expect(s.dx, _near(2.5));
      expect(s.markCount, 0);
      // The y lines of L and R merge into one, spanning both.
      final ys = _lines(s).where((l) => l[0] == 1).toList();
      expect(ys.length, 1);
      _expectRow(ys.single, [1, 61 + _oy, 0 + _ox, 400 + _ox]);
    });

    test('a spacing capture with no other candidate falls to the fallback', () {
      final r = _refs([_box(0, 100, 0, 61), _box(300, 400, 0, 61)]);
      final s = _solve(r, _box(149, 249, 60, 80));
      expect(s.capturedY, isTrue);
      expect(s.dy, _near(1));
      expect(s.capturedX, isFalse);
      expect(s.dx, 0.75);
      expect(s.markCount, 0);
    });
  });

  group('limits', () {
    test('far zoomed out, many references: lines merge, buffers hold', () {
      // 40 references stacked on the line x = 200, aperture 6 / 0.05.
      final boxes = [
        for (var i = 0; i < 40; i++) _box(100, 200, i * 300.0, i * 300.0 + 50),
      ];
      final s = _solve(_refs(boxes), _box(201, 301, 5, 55), aperture: 120);
      expect(s.capturedX, isTrue);
      expect(s.dx, _near(-1));
      final xs = _lines(s).where((l) => l[0] == 0).toList();
      expect(xs.length, 1);
      _expectRow(xs.single, [0, 200 + _ox, 0 + _oy, (39 * 300 + 50) + _oy]);
      expect(s.lineCount, lessThanOrEqualTo(kGuideCapacity));
      expect(s.markCount, lessThanOrEqualTo(kGuideCapacity));
    });

    test('a solve resets a reused solution', () {
      final r = _refs([_box(100, 200, 0, 50)]);
      final out = GuideSolution();
      void run(List<double> m) => solveGuides(r,
          minX: m[0],
          minY: m[1],
          maxX: m[2],
          maxY: m[3],
          aperture: 3,
          freeX: true,
          freeY: true,
          fallbackDx: 0,
          fallbackDy: 0,
          moving: const {},
          out: out);
      run(_box(202.5, 302.5, 1000, 1040));
      expect(out.capturedX, isTrue);
      run(_box(500, 600, 1000, 1040));
      expect(out.capturedX, isFalse);
      expect(out.lineCount, 0);
      expect(out.refX, isNull);
      expect(out.kindX, isNull);
    });
  });
}
