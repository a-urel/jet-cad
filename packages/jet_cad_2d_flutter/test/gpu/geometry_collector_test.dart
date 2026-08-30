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

    expect(c.instanceCount, 2);
    expect(c.data.sublist(1, 5), [0.0, 0.0, 1.0, 0.0]);
    expect(c.data.sublist(kFloatsPerInstance + 1, kFloatsPerInstance + 5),
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

    expect(c.instanceCount, 3);
    expect(c.data.sublist(1, 5), [0.0, 0.0, 1.0, 0.0]);
    expect(c.data.sublist(kFloatsPerInstance + 1, kFloatsPerInstance + 5),
        [1.0, 0.0, 1.0, 1.0]);
    expect(
        c.data.sublist(2 * kFloatsPerInstance + 1, 2 * kFloatsPerInstance + 5),
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
}
