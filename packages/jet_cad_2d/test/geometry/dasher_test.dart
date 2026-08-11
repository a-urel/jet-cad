import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// 12 on, 6 off, cycle 18 — the corpus's dashed linetype.
const DashPattern kDashed =
    DashPattern(dashes: [12.0, -6.0], totalLength: 18.0);
const DashPattern kSolid = DashPattern(dashes: [], totalLength: 0);

final Aabb2 kOpen = Aabb2(Vector2(-1e9, -1e9), Vector2(1e9, 1e9));

List<List<double>> collect(
    Dasher dasher, List<double> pts, DashPattern pattern, double scale,
    {Aabb2? clip}) {
  final out = <List<double>>[];
  final buffer = Float64List.fromList(pts);
  dasher.dashPolyline(buffer, pts.length ~/ 2, pattern, scale, clip ?? kOpen,
      (x0, y0, x1, y1) => out.add([x0, y0, x1, y1]));
  return out;
}

void main() {
  test('a 36-long segment under a 12/6 pattern draws three spans', () {
    final spans = collect(Dasher(), [0, 0, 36, 0], kDashed, 1.0);
    expect(
        spans,
        [
          [0.0, 0.0, 12.0, 0.0],
          [18.0, 0.0, 30.0, 0.0],
          [36.0, 0.0, 36.0, 0.0],
        ].sublist(0, 2));
  });

  test('the phase is carried from the true start when the clip cuts in', () {
    // x in [20, 100]. At 20 the pattern is 2 units into its second on-run,
    // which ends at 30. A phase reset at the clip entry would draw 20..32.
    final spans = collect(Dasher(), [0, 0, 36, 0], kDashed, 1.0,
        clip: Aabb2(Vector2(20, -5), Vector2(100, 5)));
    expect(spans.first[0], closeTo(20.0, 1e-9));
    expect(spans.first[2], closeTo(30.0, 1e-9));
  });

  test('the pattern restarts at every vertex', () {
    // Two 12-long segments. DXF's default without LWPOLYLINE flag 128 is a
    // restart per vertex, so each draws one full 12-long dash rather than the
    // second continuing into the gap.
    final spans = collect(Dasher(), [0, 0, 12, 0, 12, 12], kDashed, 1.0);
    expect(spans.length, 2);
    expect(spans[0], [0.0, 0.0, 12.0, 0.0]);
    expect(spans[1], [12.0, 0.0, 12.0, 12.0]);
  });

  test('scale multiplies the pattern, not the geometry', () {
    final spans = collect(Dasher(), [0, 0, 72, 0], kDashed, 2.0);
    expect(spans.first[2], closeTo(24.0, 1e-9));
  });

  test('a period below the floor collapses to solid and is counted', () {
    final dasher = Dasher(collapsePx: 3.0);
    // period = 18 * 0.1 = 1.8, under 3.
    final spans = collect(dasher, [0, 0, 100, 0], kDashed, 0.1);
    expect(spans, isEmpty, reason: 'the caller draws the geometry unchanged');
    expect(dasher.collapsedCount, 1);
  });

  test('an empty pattern is solid and is not counted as a collapse', () {
    final dasher = Dasher();
    expect(collect(dasher, [0, 0, 100, 0], kSolid, 1.0), isEmpty);
    expect(dasher.collapsedCount, 0,
        reason: 'a continuous linetype was never dashed; counting it as a '
            'collapse would inflate the number the results note reports');
  });

  test('a segment entirely outside the clip emits nothing', () {
    final spans = collect(Dasher(), [0, 0, 36, 0], kDashed, 1.0,
        clip: Aabb2(Vector2(500, 500), Vector2(600, 600)));
    expect(spans, isEmpty);
  });

  test('returns true when it emitted, false when the caller must draw solid',
      () {
    final dasher = Dasher();
    final buffer = Float64List.fromList([0, 0, 36, 0]);
    expect(
        dasher.dashPolyline(
            buffer, 2, kDashed, 1.0, kOpen, (_, __, ___, ____) {}),
        isTrue);
    expect(
        dasher.dashPolyline(
            buffer, 2, kSolid, 1.0, kOpen, (_, __, ___, ____) {}),
        isFalse);
  });

  test(
      'a totalLength that disagrees with the dashes does not change the '
      'output', () {
    // The cycle comes from the array, not from the declared total. Nothing
    // validates DashPattern, and a DXF importer is exactly what would build
    // an inconsistent one.
    const honest = DashPattern(dashes: [12.0, -6.0], totalLength: 18.0);
    const lying = DashPattern(dashes: [12.0, -6.0], totalLength: 10.0);
    final clip = Aabb2(Vector2(40, -5), Vector2(200, 5));
    expect(collect(Dasher(), [0, 0, 200, 0], lying, 1.0, clip: clip),
        collect(Dasher(), [0, 0, 200, 0], honest, 1.0, clip: clip));
  });

  test('a zero-length pattern terminates instead of looping', () {
    // dashes:[0.0] with a totalLength above the collapse floor once ran for
    // 445 million iterations covering 0.45 of a 100-unit segment.
    const bad = DashPattern(dashes: [0.0], totalLength: 100.0);
    final dasher = Dasher();
    expect(collect(dasher, [0, 0, 100, 0], bad, 1.0), isEmpty);
    expect(dasher.collapsedCount, 0,
        reason: 'a pattern with no length was never dashed, so it did not '
            'collapse');
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('a long segment clipped to a small window costs few pattern steps', () {
    // Without the cycle skip this walks from zero: 32,000 units at an
    // 18-unit period is about 1,800 iterations to reach a window that needs
    // three. The skip is invisible to any output assertion, so this bounds
    // the work instead.
    final dasher = Dasher();
    collect(dasher, [0, 0, 32000, 0], kDashed, 1.0,
        clip: Aabb2(Vector2(31900, -5), Vector2(32000, 5)));
    expect(dasher.patternStepCount, lessThan(20));
  });

  group('dashArc', () {
    List<List<double>> arcs(Dasher dasher, double cx, double cy, double r,
        double start, double sweep, double scale,
        {Aabb2? clip}) {
      final out = <List<double>>[];
      dasher.dashArc(cx, cy, r, start, sweep, kDashed, scale, clip ?? kOpen,
          (a, s) => out.add([a, s]));
      return out;
    }

    test('a full circle is walked by arc length', () {
      // r = 18/(2*pi) makes the circumference exactly 18: one full cycle, so
      // one 12-long span, which is 12/18 of a turn.
      final r = 18 / (2 * math.pi);
      final spans = arcs(Dasher(), 0, 0, r, 0, 2 * math.pi, 1.0);
      expect(spans.length, 1);
      expect(spans.first[0], closeTo(0.0, 1e-9));
      expect(spans.first[1], closeTo(2 * math.pi * 12 / 18, 1e-9));
    });

    test('a period below the floor collapses and is counted', () {
      final dasher = Dasher(collapsePx: 3.0);
      expect(arcs(dasher, 0, 0, 100, 0, 2 * math.pi, 0.1), isEmpty);
      expect(dasher.collapsedCount, 1);
    });

    test('only the angular window inside the clip is generated', () {
      // A large circle whose centre is far left: a narrow window crosses the
      // clip. Every emitted span must lie inside that window.
      final clip = Aabb2(Vector2(0, -10), Vector2(20, 10));
      final spans =
          arcs(Dasher(), -1000, 0, 1005, 0, 2 * math.pi, 1.0, clip: clip);
      expect(spans, isNotEmpty);
      for (final s in spans) {
        final mid = s[0] + s[1] / 2;
        final x = -1000 + 1005 * math.cos(mid);
        final y = 1005 * math.sin(mid);
        expect(x, greaterThanOrEqualTo(clip.minX - 1));
        expect(x, lessThanOrEqualTo(clip.maxX + 1));
        expect(y, greaterThanOrEqualTo(clip.minY - 1));
        expect(y, lessThanOrEqualTo(clip.maxY + 1));
      }
    });

    test('a circle wholly outside the clip emits nothing', () {
      final spans = arcs(Dasher(), 0, 0, 10, 0, 2 * math.pi, 1.0,
          clip: Aabb2(Vector2(500, 500), Vector2(600, 600)));
      expect(spans, isEmpty);
    });

    test('a large circle clipped to a small window costs few pattern steps',
        () {
      // Window near the bottom of the circle (angle 3*pi/2), far from where
      // the arc begins (angle 0). Without the cycle skip this walks from
      // zero: the along-distance to reach the window is r * 3*pi/2, about
      // 23,562 units at an 18-unit period is roughly 1,309 iterations.
      // Measured with the skip: 3.
      final dasher = Dasher();
      final r = 5000.0;
      final clip = Aabb2(Vector2(-5, -r - 5), Vector2(5, -r + 5));
      arcs(dasher, 0, 0, r, 0, 2 * math.pi, 1.0, clip: clip);
      expect(dasher.patternStepCount, lessThan(15));
    });

    test(
        'a circle wholly inside the clip emits the same spans as the same '
        'circle whose windows were computed the long way', () {
      // `start` (angle 0) sits exactly where this clip's right edge grazes
      // the circle, so the razor-thin sliver excluded there straddles the
      // arc's own wrap point (angle 0 == angle 2*pi) rather than falling
      // inside the visible span. That is the one placement where a single
      // circleClipWindows window maps onto a single contiguous
      // [from, to] without needing to split — the same shape of window the
      // sentinel's synthetic "-pi..3pi" range collapses to. Shrinking the
      // excluded sliver toward zero must shrink the disagreement with the
      // sentinel path toward zero, too.
      final r = 18 / (2 * math.pi);
      final wholeCircle = arcs(Dasher(), 0, 0, r, 0, 2 * math.pi, 1.0,
          clip: Aabb2(Vector2(-r - 1, -r - 1), Vector2(r + 1, r + 1)));
      final longWay = arcs(Dasher(), 0, 0, r, 0, 2 * math.pi, 1.0,
          clip: Aabb2(Vector2(-r - 1, -r - 1), Vector2(r - 1e-9, r + 1)));
      expect(longWay, isNotEmpty);
      expect(longWay.length, wholeCircle.length);
      for (var i = 0; i < wholeCircle.length; i++) {
        expect(longWay[i][0], closeTo(wholeCircle[i][0], 1e-3));
        expect(longWay[i][1], closeTo(wholeCircle[i][1], 1e-3));
      }
    });
  });
}
