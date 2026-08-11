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
}
