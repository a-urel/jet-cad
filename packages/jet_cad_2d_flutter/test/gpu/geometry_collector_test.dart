import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

const _style = ResolvedStyle(
    argb: 0xFF203040,
    lineweightHundredths: 50,
    linetype: Handle.none,
    linetypeScale: 1);

const _hairlineStyle = ResolvedStyle(
    argb: 0xFF203040,
    lineweightHundredths: 0,
    linetype: Handle.none,
    linetypeScale: 1);

/// Reads the kind tag of instance [i].
double _kindAt(GeometryCollector c, int i) =>
    c.data[i * kFloatsPerInstance + InstanceFieldOffset.kind];

void main() {
  test('applies the residual, and a transposed one is not the same residual',
      () {
    final c = GeometryCollector(
        pixelsPerPaperMm: 4, devicePixelRatio: 2, lineweightScale: 1);

    // **Deliberately not the identity, not at the origin, not uniform, and
    // not diagonal.** b=0.5 and c=-1 differ from each other (and from the
    // 0 a diagonal residual would carry), and neither fixture point sits on
    // x == y — so swapping t.b for t.c in the residual application changes
    // the answer instead of leaving it invariant. That distinction matters
    // because a rotated or sheared DXF INSERT produces exactly this shape of
    // residual, not a diagonal one.
    //
    // px = a*x + c*y + e, py = b*x + d*y + f (`transform2.dart`'s own
    // convention — c multiplies y into x, b multiplies x into y):
    //   (1, 2) -> (2*1 + -1*2 + 10, 0.5*1 + 3*2 + 10) = (10, 16.5)
    //   (4, 3) -> (2*4 + -1*3 + 10, 0.5*4 + 3*3 + 10) = (15, 21)
    c.beginResidual(Transform2(2, 0.5, -1, 3, 10, 10));
    final pts = Float64List.fromList([1, 2, 4, 3]);
    c.polyline(pts, 2, _style, closed: false);
    c.endResidual();

    expect(c.instanceCount, 1);
    final r = c.data.sublist(0, kFloatsPerInstance);
    expect(r[0], kKindStroke);
    expect(r.sublist(1, 5), [10.0, 16.5, 15.0, 21.0]);
    // Pins `w / 2` **in device pixels**, not the raw logical width:
    // lineweightHundredths=50, pixelsPerPaperMm=4, lineweightScale=1 gives a
    // logical width of 50/100 * 4 * 1 = 2.0, which at devicePixelRatio=2 is
    // 2.0 * 2 = 4.0 device pixels -- above the floor of
    // kMinStrokeDevicePixels(1.0), so halfWidth = 4.0 / 2 = 2.0.
    expect(r[InstanceFieldOffset.halfWidth], 2.0);
  });

  test('emits one instance per segment, in walk order', () {
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.polyline(Float64List.fromList([0, 0, 1, 0, 1, 1]), 3, _style,
        closed: false);
    c.endResidual();

    // Stroke, join (at the corner), stroke -- three instances now that the
    // interior join is emitted between the two segments (Task 4); see 'an
    // open three-point run is join-before-segment, and nothing else'.
    expect(c.instanceCount, 3);
    expect(c.data[InstanceFieldOffset.kind], kKindStroke);
    expect(c.data.sublist(1, 5), [0.0, 0.0, 1.0, 0.0]);
    expect(c.data[kFloatsPerInstance + InstanceFieldOffset.kind], kKindJoin);
    expect(
        c.data[2 * kFloatsPerInstance + InstanceFieldOffset.kind], kKindStroke);
    expect(
        c.data.sublist(2 * kFloatsPerInstance + 1, 2 * kFloatsPerInstance + 5),
        [1.0, 0.0, 1.0, 1.0]);
  });

  test('closed: true emits a closing segment back to the first point', () {
    // `DraftPainter` never passes `closed: true` today (there is no
    // closed-polyline flag on the model yet), so nothing in the differential
    // gate (`test/gpu/collector_differential_test.dart`) can exercise this
    // branch through the real walk. This drives `GeometryCollector.polyline`
    // directly, the way the residual-transposition test above already does,
    // so the branch has a killable test regardless.
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.polyline(Float64List.fromList([0, 0, 1, 0, 1, 1]), 3, _style,
        closed: true);
    c.endResidual();

    // Stroke, join, stroke, join, closing stroke, seam join -- six
    // instances now that joins are interleaved (Task 4); see 'a closed run
    // emits the closing segment and then the seam join'. The three strokes
    // sit at instances 0, 2 and 4 -- the joins at 1, 3 and 5 shift every
    // later stroke's index, which is why this can no longer read
    // consecutive slots.
    expect(c.instanceCount, 6);
    expect(c.data.sublist(1, 5), [0.0, 0.0, 1.0, 0.0]);
    expect(
        c.data.sublist(2 * kFloatsPerInstance + 1, 2 * kFloatsPerInstance + 5),
        [1.0, 0.0, 1.0, 1.0]);
    expect(
        c.data.sublist(4 * kFloatsPerInstance + 1, 4 * kFloatsPerInstance + 5),
        [1.0, 1.0, 0.0, 0.0],
        reason: 'the closing segment must run from the last point back to '
            'the first');
  });

  test('drops a zero-length segment rather than handing the shader a NaN', () {
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.polyline(Float64List.fromList([5, 5, 5, 5]), 2, _style, closed: false);
    c.endResidual();
    expect(c.instanceCount, 0);
  });

  test('counts the ops Plan A does not draw instead of dropping them silently',
      () {
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.circle(0, 0, 5, _style);
    c.text('x', Handle.none, _style);
    c.endResidual();
    expect(c.instanceCount, 0);
    expect(c.skippedOps, 2);
  });

  test('clamps to the device-pixel floor at a hairline lineweight', () {
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.polyline(Float64List.fromList([0, 0, 1, 0]), 2, _hairlineStyle,
        closed: false);
    c.endResidual();

    expect(c.instanceCount, 1);
    // lineweightHundredths=0 gives a logical width of 0, which converts to
    // 0 device pixels either way -- not greater than the floor of
    // kMinStrokeDevicePixels(1.0), so the clamp takes over:
    // halfWidth = 1.0 / 2 = 0.5. A mutation that drops the clamp entirely
    // would emit halfWidth = 0.0 instead.
    expect(c.data[InstanceFieldOffset.halfWidth], 0.5);
  });

  test('lineweightScale multiplies the logical width before the clamp', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: 4, devicePixelRatio: 2, lineweightScale: 2);
    c.beginResidual(Transform2.identity());
    c.polyline(Float64List.fromList([0, 0, 1, 0]), 2, _style, closed: false);
    c.endResidual();

    expect(c.instanceCount, 1);
    // lineweightHundredths=50, pixelsPerPaperMm=4, lineweightScale=2 gives a
    // logical width of 50/100 * 4 * 2 = 4.0, which at devicePixelRatio=2 is
    // 4.0 * 2 = 8.0 device pixels -- above the floor of
    // kMinStrokeDevicePixels(1.0), so halfWidth = 8.0 / 2 = 4.0. At the
    // default scale of 1.0 this is 2.0 (the test above), so the multiply is
    // still pinned: a dropped `lineweightScale` factor would make this test
    // read 2.0 instead of 4.0.
    expect(c.data[InstanceFieldOffset.halfWidth], 4.0);
  });

  test('a sub-pixel stroke keeps its pixel and gives up alpha', () {
    // 0.05 mm at 3.7795275590551185 px/mm and dpr 1 is 0.189 device pixels --
    // under the one-pixel floor, so the reference fades it. The collector
    // must fade it by the same factor or the two arms disagree on colour on
    // every hairline layer, which is exactly what Task 9 rasterises.
    const dpr = 1.0;
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: dpr);
    const style = ResolvedStyle(
        argb: 0xFF204060,
        lineweightHundredths: 5,
        linetype: Handle.none,
        linetypeScale: 1);
    c.polyline(Float64List.fromList(<double>[0, 0, 40, 0]), 2, style,
        closed: false);

    final deviceWidth = 5 / 100.0 * kLogicalPixelsPerMm * dpr;
    expect(deviceWidth, lessThan(1.0),
        reason:
            'the fixture must actually be sub-pixel or this asserts nothing');
    final coverage = (deviceWidth * 2).clamp(0.0, 1.0);
    final expectedAlpha = (0xFF * coverage).round();

    final r = c.data;
    expect(r[InstanceFieldOffset.a] * 255.0, closeTo(expectedAlpha, 0.51));
    // The colour channels are untouched: `_coveredArgb` gives up alpha, it
    // does not darken. A implementation that multiplied the channels instead
    // would pass an alpha-only assertion.
    expect(r[InstanceFieldOffset.r] * 255.0, closeTo(0x20, 0.51));
    expect(r[InstanceFieldOffset.g] * 255.0, closeTo(0x40, 0.51));
    expect(r[InstanceFieldOffset.b] * 255.0, closeTo(0x60, 0.51));
    // And the width still floors at one device pixel: the fade replaces the
    // missing width, it does not accompany a thinner quad.
    expect(r[InstanceFieldOffset.halfWidth],
        closeTo(GeometryCollector.kMinStrokeDevicePixels / 2, 1e-6));
  });

  test('a stroke at or above one device pixel keeps full alpha', () {
    // The other side of the branch. Without this, deleting the
    // `deviceWidth >= kMinStrokeDevicePixels` guard -- fading *every* stroke
    // -- goes unnoticed.
    const dpr = 2.0;
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: dpr);
    const style = ResolvedStyle(
        argb: 0xC0204060,
        lineweightHundredths: 25,
        linetype: Handle.none,
        linetypeScale: 1);
    c.polyline(Float64List.fromList(<double>[0, 0, 40, 0]), 2, style,
        closed: false);
    final deviceWidth = 25 / 100.0 * kLogicalPixelsPerMm * dpr;
    expect(deviceWidth, greaterThan(1.0),
        reason: 'the fixture must actually be above the floor');
    expect(c.data[InstanceFieldOffset.a] * 255.0, closeTo(0xC0, 0.51));
  });

  test('a zero lineweight is the hairline case and keeps full alpha', () {
    // `_coveredArgb`'s first branch: `deviceWidth <= 0` returns argb
    // unchanged. That is deliberate in the reference -- "A width of exactly
    // zero is the hairline case and keeps full alpha -- that is the first
    // branch there, not an omission" -- and a collector that clamped
    // coverage from 0 would draw every hairline entity invisible.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0]),
        2,
        const ResolvedStyle(
            argb: 0xFF112233,
            lineweightHundredths: 0,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: false);
    expect(c.data[InstanceFieldOffset.a] * 255.0, closeTo(0xFF, 0.51));
  });

  test('an open three-point run is join-before-segment, and nothing else', () {
    // Three points, one corner. The reference emits: segment(0,1),
    // join(1), segment(1,2) -- in that order, with the join written before
    // the segment it precedes. Butt caps mean there is nothing at either
    // end (Ruling B2), so the count is exactly 3.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 40, 30]),
        3,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: false);
    expect(c.instanceCount, 3,
        reason: 'segment, join, segment -- no caps, no trailing join');
    expect(<double>[
      _kindAt(c, 0),
      _kindAt(c, 1),
      _kindAt(c, 2)
    ], <double>[
      kKindStroke,
      kKindJoin,
      kKindStroke
    ], reason: 'the join is written BEFORE the segment that follows it');
  });

  test('the join carries the corner and both its neighbours', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 40, 30]),
        3,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: false);
    final j = c.data.sublist(kFloatsPerInstance, 2 * kFloatsPerInstance);
    expect(j[InstanceFieldOffset.x0], 40, reason: 'the vertex');
    expect(j[InstanceFieldOffset.y0], 0);
    expect(j[InstanceFieldOffset.x1], 0, reason: 'the previous point');
    expect(j[InstanceFieldOffset.y1], 0);
    expect(j[InstanceFieldOffset.x2], 40, reason: 'the next point');
    expect(j[InstanceFieldOffset.y2], 30);
  });

  test('a closed run emits the closing segment and then the seam join', () {
    // A triangle: three points, closed. Segments 0-1, 1-2, 2-0 with a join
    // at vertices 1 and 2, then the seam join at vertex 0 -- LAST, after the
    // closing segment. Six instances, and the last one is the seam.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 60, 0, 30, 50]),
        3,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: true);
    expect(c.instanceCount, 6);
    expect(List<double>.generate(6, (i) => _kindAt(c, i)), <double>[
      kKindStroke, // 0 -> 1
      kKindJoin, //   at 1
      kKindStroke, // 1 -> 2
      kKindJoin, //   at 2
      kKindStroke, // 2 -> 0, the closing segment
      kKindJoin, //   the seam, at 0, LAST
    ]);
    final seam = c.data.sublist(5 * kFloatsPerInstance);
    expect(seam[InstanceFieldOffset.x0], 0,
        reason: 'the seam is at the first point');
    expect(seam[InstanceFieldOffset.y0], 0);
    expect(seam[InstanceFieldOffset.x1], 30,
        reason: 'incoming from the last point');
    expect(seam[InstanceFieldOffset.y1], 50);
    expect(seam[InstanceFieldOffset.x2], 60,
        reason: 'outgoing to the second point');
    expect(seam[InstanceFieldOffset.y2], 0);
  });

  test('a repeated point is spanned by the join, not turned into one', () {
    // The reference's `_runTo` skips a zero-length step and KEEPS the
    // previous direction, so a duplicated vertex produces the same corner a
    // clean polyline would. A collector that reset its direction on the
    // repeat would emit a join between two identical points and draw
    // nothing there.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 40, 0, 40, 30]),
        4,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: false);
    expect(c.instanceCount, 3, reason: 'the repeat adds no instance');
    final j = c.data.sublist(kFloatsPerInstance, 2 * kFloatsPerInstance);
    expect(j[InstanceFieldOffset.x1], 0,
        reason: 'the incoming neighbour is still the first point');
    expect(j[InstanceFieldOffset.y1], 0);
  });

  test('a two-point run has no join at all', () {
    // The degenerate case a join implementation gets wrong in the other
    // direction: emitting a join at the start or the end of an open run.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 30]),
        2,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: false);
    expect(c.instanceCount, 1);
    expect(_kindAt(c, 0), kKindStroke);
  });
}
