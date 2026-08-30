import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/gpu/geometry_collector.dart';
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
}
