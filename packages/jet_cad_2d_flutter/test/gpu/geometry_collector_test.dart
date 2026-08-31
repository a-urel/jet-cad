import 'dart:math' as math;
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

/// Counts instances of kind [kind] in [c]'s buffer.
int _countKind(GeometryCollector c, double kind) {
  final data = c.data;
  var n = 0;
  for (var i = 0; i < c.instanceCount; i++) {
    if (data[i * kFloatsPerInstance + InstanceFieldOffset.kind] == kind) n++;
  }
  return n;
}

int _joinCount(GeometryCollector c) => _countKind(c, kKindJoin);
int _strokeCount(GeometryCollector c) => _countKind(c, kKindStroke);

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
    expect(r[InstanceFieldOffset.kind], kKindStroke);
    expect(r.sublist(InstanceFieldOffset.x0, InstanceFieldOffset.x0 + 4),
        [10.0, 16.5, 15.0, 21.0]);
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
    expect(c.data.sublist(InstanceFieldOffset.x0, InstanceFieldOffset.x0 + 4),
        [0.0, 0.0, 1.0, 0.0]);
    expect(c.data[kFloatsPerInstance + InstanceFieldOffset.kind], kKindJoin);
    expect(
        c.data[2 * kFloatsPerInstance + InstanceFieldOffset.kind], kKindStroke);
    expect(
        c.data.sublist(2 * kFloatsPerInstance + InstanceFieldOffset.x0,
            2 * kFloatsPerInstance + InstanceFieldOffset.x0 + 4),
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
    expect(c.data.sublist(InstanceFieldOffset.x0, InstanceFieldOffset.x0 + 4),
        [0.0, 0.0, 1.0, 0.0]);
    expect(
        c.data.sublist(2 * kFloatsPerInstance + InstanceFieldOffset.x0,
            2 * kFloatsPerInstance + InstanceFieldOffset.x0 + 4),
        [1.0, 0.0, 1.0, 1.0]);
    expect(
        c.data.sublist(4 * kFloatsPerInstance + InstanceFieldOffset.x0,
            4 * kFloatsPerInstance + InstanceFieldOffset.x0 + 4),
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

  test('counts the ops it does not draw instead of dropping them silently', () {
    // **This test used `circle` until Task 5.** A circle is drawn now, so the
    // two ops here are `fillCircle` and `text` -- chosen because they stay
    // skipped for the whole of Plan B (fills are Plan D, text is Plan E), so
    // this assertion does not have to be rewritten again at Task 6 the way it
    // was rewritten here. Both assertions are kept: an op that starts being
    // drawn without being taken off the skipped list would move
    // `instanceCount`, and an op silently dropped would leave `skippedOps`
    // short.
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.fillCircle(0, 0, 5, _style);
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

  test(
      'a closed run whose last point already repeats the first still finds '
      'the last DISTINCT point for the seam', () {
    // M-B11. `_endRun`'s seam join must read its incoming neighbour from
    // `_runBack` AFTER the closing `_runTo` call, not from `_runPrev` as it
    // stood BEFORE that call. The two coincide whenever the closing step
    // actually moves -- `_runTo` sets `_runBack` to the pre-call `_runPrev`
    // on its way through -- so nothing distinguishes them until the raw
    // point list's last point already equals the first: then the closing
    // `_runTo` is a zero-length skip that leaves `_runBack` untouched at
    // the last DISTINCT point (30, 50), while `_runPrev` at that same
    // moment already reads (0, 0) -- the vertex itself. A mutation that
    // captured the "before" value instead of reading `_runBack` after the
    // call would hand the seam a zero-length incoming direction, which the
    // shader would turn into a NaN.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 60, 0, 30, 50, 0, 0]),
        4,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: true);
    expect(c.instanceCount, 6,
        reason: 'the explicit trailing repeat of the first point adds no '
            'instance of its own');
    final seam = c.data.sublist(5 * kFloatsPerInstance);
    expect(seam[InstanceFieldOffset.kind], kKindJoin);
    expect(seam[InstanceFieldOffset.x0], 0,
        reason: 'the seam is at the first point');
    expect(seam[InstanceFieldOffset.y0], 0);
    expect(seam[InstanceFieldOffset.x1], 30,
        reason: 'incoming from the last DISTINCT point, not the repeat');
    expect(seam[InstanceFieldOffset.y1], 50);
    expect(seam[InstanceFieldOffset.x2], 60,
        reason: 'outgoing to the second point');
    expect(seam[InstanceFieldOffset.y2], 0);
  });

  test('a circle is a closed run: N chords, N joins, seam last', () {
    // The chord count comes from the reference's own formula, recomputed
    // here rather than hardcoded, so the test tracks a tolerance change
    // instead of pinning today's number.
    const r = 50.0;
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    c.circle(
        0,
        0,
        r,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));

    final steps =
        (2 * math.pi * math.sqrt(r / (8 * VerticesDrawSink.kFlattenTolerance)))
            .ceil()
            .clamp(1, VerticesDrawSink.kMaxFlattenSegments);
    // A closed run of `steps` chords: `steps` segments, `steps - 1` interior
    // joins, and the seam. 2 * steps instances.
    expect(c.instanceCount, 2 * steps);
    expect(c.skippedOps, 0, reason: 'a circle is no longer skipped');
    expect(
        c.data[(2 * steps - 1) * kFloatsPerInstance + InstanceFieldOffset.kind],
        kKindJoin,
        reason: 'the seam join is the last instance');
  });

  test('an arc is an open run and has no seam', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    c.arc(
        0,
        0,
        50,
        0,
        math.pi / 2,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));
    // An open run of `steps` chords is `steps` segments and `steps - 1`
    // joins: odd, and ending on a segment.
    expect(c.instanceCount.isOdd, isTrue);
    expect(
        c.data[(c.instanceCount - 1) * kFloatsPerInstance +
            InstanceFieldOffset.kind],
        kKindStroke,
        reason: 'an open run ends on a segment -- butt caps, no seam');
  });

  test('a non-uniform residual makes an ellipse, not a scaled circle', () {
    // The degenerate-fixture guard for this op. Under `scale(3, 1)` a circle
    // of radius 10 spans 60 in x and 20 in y; a collector that flattened in
    // device space and transformed the CENTRE only would give a circle of
    // some single radius, and every x-extent assertion below would fail.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(const Transform2(3, 0, 0, 1, 0, 0));
    c.circle(
        0,
        0,
        10,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    // Hoisted: `data` copies the whole buffer on every access
    // (`geometry_collector.dart`'s own doc says so), and reading it inside
    // the loop would make ~190 copies. The differential test hoists it for
    // the same reason.
    final data = c.data;
    for (var i = 0; i < c.instanceCount; i++) {
      final o = i * kFloatsPerInstance;
      if (data[o + InstanceFieldOffset.kind] != kKindStroke) continue;
      final x = data[o + InstanceFieldOffset.x0];
      final y = data[o + InstanceFieldOffset.y0];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    // The window is 1.0, not 0.5: a 19-chord polygon's own sagitta already
    // eats ~0.4 of the extent, so a tighter window would be measuring the
    // chord count rather than the flattening space. M-B4 misses by 25.6, so
    // 1.0 still kills it by a wide margin.
    expect(maxX - minX, closeTo(60, 1.0));
    expect(maxY - minY, closeTo(20, 1.0));
  });

  test('a negative sweep runs clockwise, not mirrored', () {
    // **The sign of the sweep is not covered by anything else.** Every arc
    // in the corpus sweeps positive -- the fixture's arc 703 is +1.9, and
    // the two tests above use 2*pi and pi/2 -- so `sweep / steps` could be
    // written `sweep.abs() / steps` and no gate in this plan would notice.
    // `draft_painter.dart` passes the sweep through unnormalised, so a
    // clockwise arc is representable, and under that mutation it would be
    // drawn mirrored across the start ray while the reference drew it
    // correctly.
    //
    // Starting at angle 0 -- the point (50, 0) -- and sweeping -pi/2 must
    // end at (0, -50), the FOURTH quadrant. Under `sweep.abs()` it would end
    // at (0, +50) instead.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    c.arc(
        0,
        0,
        50,
        0,
        -math.pi / 2,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));

    final data = c.data;
    final lastStroke = (c.instanceCount - 1) * kFloatsPerInstance;
    expect(data[lastStroke + InstanceFieldOffset.kind], kKindStroke,
        reason: 'an open run ends on a segment');
    expect(data[lastStroke + InstanceFieldOffset.x1], closeTo(0, 1e-3));
    expect(data[lastStroke + InstanceFieldOffset.y1], closeTo(-50, 1e-3),
        reason: 'a negative sweep ends in the fourth quadrant; `sweep.abs()` '
            'would put it at +50');
  });

  test('a zero or negative radius draws nothing', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    const style = ResolvedStyle(
        argb: 0xFF000000,
        lineweightHundredths: 25,
        linetype: Handle.none,
        linetypeScale: 1);
    c.circle(0, 0, 0, style);
    c.circle(0, 0, -5, style);
    c.arc(0, 0, 10, 0, 0, style);
    c.arc(0, 0, -10, 0, 1, style);
    expect(c.instanceCount, 0);
  });

  test('a point is one instance of its own kind, at the transformed position',
      () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    // A general residual, so a collector that dropped the off-diagonal terms
    // lands somewhere else: (2*4 + 0.5*(-1) + 10, ...) is not (2*4 + 10, ...).
    c.beginResidual(const Transform2(2, 0.5, -1, 3, 10, 10));
    c.point(
        4,
        -1,
        const ResolvedStyle(
            argb: 0xFF336699,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));
    expect(c.instanceCount, 1);
    expect(c.skippedOps, 0);
    final r = c.data;
    expect(r[InstanceFieldOffset.kind], kKindPoint);
    // x = a*4 + c*(-1) + e = 8 + 1 + 10 = 19
    // y = b*4 + d*(-1) + f = 2 - 3 + 10 = 9
    expect(r[InstanceFieldOffset.x0], closeTo(19, 1e-4));
    expect(r[InstanceFieldOffset.y0], closeTo(9, 1e-4));
    // The unused slots stay zero: a point that reused x1/y1 as a second
    // endpoint would be a stroke wearing the wrong tag.
    expect(r[InstanceFieldOffset.x1], 0);
    expect(r[InstanceFieldOffset.y1], 0);
    expect(r[InstanceFieldOffset.x2], 0);
    expect(r[InstanceFieldOffset.y2], 0);
  });

  test('a point takes the hairline fade like a stroke', () {
    // `point()` routes through `_coveredArgb` in the reference. A dot on a
    // hairline layer fades with everything else on it.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 1.0);
    c.point(
        0,
        0,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 5,
            linetype: Handle.none,
            linetypeScale: 1));
    expect(c.data[InstanceFieldOffset.a] * 255.0, lessThan(0xFF));
  });

  test(
      'debugCollinearJoins counts a straight-through vertex and not a '
      'right-angle corner', () {
    final corner = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    corner.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 40, 30]),
        3,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: false);
    expect(corner.debugCollinearJoins, 0,
        reason: 'a right-angle turn has a nonzero cross product');

    final straight = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    straight.polyline(
        Float64List.fromList(<double>[0, 0, 20, 0, 40, 0]),
        3,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: false);
    expect(straight.debugCollinearJoins, 1,
        reason: 'the middle vertex sits exactly on the line -- cross_z == '
            '0, the same predicate the shader collapses to two zero-area '
            'triangles for, but the collector still WRITES the instance');
    expect(straight.instanceCount, 3,
        reason: 'Ruling B4 keeps the decision in the shader, so the '
            'counter above never changes what this collector emits');
  });

  test('debugCollinearJoins counts an exact reversal too', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 0, 0]),
        3,
        const ResolvedStyle(
            argb: 0xFF000000,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: false);
    expect(c.debugCollinearJoins, 1,
        reason: 'a straight there-and-back also has cross_z == 0, the same '
            'branch the shader\'s degenerate test takes');
  });

  test('after Plan B, only fills and text are skipped', () {
    // The sentence in `skippedOps`' doc, asserted. It goes red the day
    // another op is silently dropped -- or the day Plan D lands and forgets
    // to update the doc.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    const style = ResolvedStyle(
        argb: 0xFF000000,
        lineweightHundredths: 25,
        linetype: Handle.none,
        linetypeScale: 1);
    c.polyline(Float64List.fromList(<double>[0, 0, 10, 10]), 2, style,
        closed: false);
    c.circle(0, 0, 20, style);
    c.arc(0, 0, 20, 0, 1, style);
    c.point(1, 1, style);
    expect(c.skippedOps, 0, reason: 'four ops Plan B draws');
    c.fillPolygon(Float64List.fromList(<double>[0, 0, 1, 0, 0, 1]), 3,
        Int32List.fromList(<int>[0, 1, 2]), style);
    c.fillCircle(0, 0, 5, style);
    c.text('x', Handle.none, style);
    expect(c.skippedOps, 3, reason: 'three ops Plans D and E draw');
  });

  // --- dashed polylines (Task 5) -------------------------------------------

  const dashed = DashPattern(dashes: [12.0, -6.0], totalLength: 18.0);
  const dashDot =
      DashPattern(dashes: [12.0, -3.0, 0.5, -3.0], totalLength: 18.5);
  const allGap = DashPattern(dashes: [-4.0], totalLength: 4.0);
  const dashStyle = ResolvedStyle(
      argb: 0xFF112233,
      lineweightHundredths: 25,
      linetype: Handle(900),
      linetypeScale: 1.0);

  test(
      'a dashed polyline emits one instance per segment per drawn element, '
      'and no joins at all', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(dashed, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, dashStyle,
        closed: false);
    c.endDash();
    c.endResidual();

    // Two segments, one drawn element, no joins.
    expect(c.instanceCount, 2);
    for (var i = 0; i < 2; i++) {
      expect(c.data[i * kFloatsPerInstance + InstanceFieldOffset.kind],
          kKindStroke,
          reason: 'a dashed run has no joins: the reference gives every span '
              'its own polyline op and therefore its own run');
    }
  });

  test(
      'the same polyline undashed keeps its join -- so the assertion above '
      'is about dashes, not about the fixture', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, dashStyle,
        closed: false);
    c.endResidual();
    expect(c.instanceCount, 3); // segment, join, segment
  });

  test(
      'a two-element pattern doubles the instances and the two elements '
      'tile the cycle without overlapping', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(dashDot, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0]), 2, dashStyle,
        closed: false);
    c.endDash();
    c.endResidual();

    expect(c.instanceCount, 2);
    final e0Start = c.data[InstanceFieldOffset.dashFracStart];
    final e0End = c.data[InstanceFieldOffset.dashFracEnd];
    final e1Start =
        c.data[kFloatsPerInstance + InstanceFieldOffset.dashFracStart];
    final e1End = c.data[kFloatsPerInstance + InstanceFieldOffset.dashFracEnd];
    expect(e0Start, 0.0);
    expect(e0End, closeTo(12.0 / 18.5, 1e-6));
    expect(e1Start, closeTo(15.0 / 18.5, 1e-6));
    expect(e1End, closeTo(15.5 / 18.5, 1e-6));
    expect(e0End, lessThan(e1Start), reason: 'the gap between them is a gap');
  });

  test('the period is the cycle times the scale, in collection units', () {
    // cycle 18, patternToLocal 2.0, residual a translation -> factor 1.
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(dashed, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0]), 2, dashStyle,
        closed: false);
    c.endDash();
    c.endResidual();
    expect(c.data[InstanceFieldOffset.dashPeriod].abs(), closeTo(36.0, 1e-6));
  });

  test(
      'a scaled residual scales the period, because the pattern is measured '
      'in the space the points are in', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.scale(3.0, 3.0));
    c.beginDash(dashed, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0]), 2, dashStyle,
        closed: false);
    c.endDash();
    c.endResidual();
    expect(c.data[InstanceFieldOffset.dashPeriod].abs(), closeTo(108.0, 1e-4),
        reason: '18 x 2.0 x 3.0');
  });

  test('exactly one instance per primitive is the collapse representative', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(dashDot, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0]), 2, dashStyle,
        closed: false);
    c.endDash();
    c.endResidual();

    expect(c.instanceCount, 2, reason: 'dashDot has D == 2 drawn elements');
    final periods = <double>[
      c.data[InstanceFieldOffset.dashPeriod],
      c.data[kFloatsPerInstance + InstanceFieldOffset.dashPeriod],
    ];
    expect(periods.where((p) => p < 0), hasLength(1),
        reason: 'two representatives would draw the collapsed line twice, '
            'and with blending on that is darker, not merely wasteful');
    expect(periods.first, lessThan(0), reason: 'the first drawn element');
  });

  test(
      'a pattern with no drawn element still emits one instance, so the '
      'collapse case has something to draw', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(allGap, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0]), 2, dashStyle,
        closed: false);
    c.endDash();
    c.endResidual();

    expect(c.instanceCount, 1);
    expect(c.data[InstanceFieldOffset.dashPeriod], lessThan(0));
    expect(c.data[InstanceFieldOffset.dashFracStart],
        c.data[InstanceFieldOffset.dashFracEnd],
        reason: 'an empty extent draws nothing until the pattern collapses, '
            'and the reference draws the whole line solid when it does');
  });

  test('endDash restores solid emission', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(dashed, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0]), 2, dashStyle,
        closed: false);
    c.endDash();
    c.polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, dashStyle,
        closed: false);
    c.endResidual();
    // The first polyline is one dashed segment with D == 1: one instance.
    // The second polyline is a plain two-segment run: two segments, one join.
    expect(c.instanceCount, 1 + 3);
  });

  test('a zero-cycle pattern is solid, matching dashPolyline returning false',
      () {
    const degenerate = DashPattern(dashes: [0.0], totalLength: 0.0);
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(degenerate, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0]), 2, dashStyle,
        closed: false);
    c.endDash();
    c.endResidual();
    expect(c.instanceCount, 1);
    expect(c.data[InstanceFieldOffset.dashPeriod], 0.0);
  });

  test(
      'the cycle comes from summing the dashes, never from a dishonest '
      'totalLength', () {
    // totalLength (99.0) deliberately disagrees with the summed dashes
    // (12.0 + 6.0 = 18.0) -- exactly the disagreement `dasher.dart` warns a
    // DXF importer could hand this class. Every other fixture in this file
    // keeps an honest totalLength, so reading `.totalLength` instead of
    // summing `pattern.dashes` would still pass every other test here; it
    // would answer only this one wrong, with a period of 198.0 (99.0 x
    // patternToLocal 2.0) instead of the correct 36.0 (18.0 x 2.0).
    const dishonestTotal = DashPattern(dashes: [12.0, -6.0], totalLength: 99.0);
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(dishonestTotal, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0]), 2, dashStyle,
        closed: false);
    c.endDash();
    c.endResidual();
    expect(c.data[InstanceFieldOffset.dashPeriod].abs(), closeTo(36.0, 1e-6),
        reason: 'summed dashes (12 + 6) x patternToLocal 2.0 = 36.0, not '
            '99.0 x 2.0 = 198.0 from the dishonest totalLength');
  });

  test(
      'an anisotropic residual scales each segment by its OWN axis, not by '
      'scaleMagnitude', () {
    // `_residual.scaleMagnitude` is one number for the whole transform --
    // under `scale(2, 5)` it is sqrt(2 * 5) regardless of a segment's own
    // direction, so a collector that used it for every segment would give
    // the x-running segment and the y-running segment the SAME period. The
    // correct factor is per-segment: the x-segment's collection length grows
    // by 2x, the y-segment's by 5x, so their periods must come back in a 2:5
    // ratio. Asserting the ratio (not two magic numbers) fails loudly under
    // the `scaleMagnitude` mutation, which collapses the ratio to 1.0, and
    // survives an unrelated change to the pattern itself.
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.scale(2.0, 5.0));
    c.beginDash(dashed, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, dashStyle,
        closed: false);
    c.endDash();
    c.endResidual();

    expect(c.instanceCount, 2,
        reason: 'two segments, one drawn element each, no joins');
    final xPeriod = c.data[InstanceFieldOffset.dashPeriod].abs();
    final yPeriod =
        c.data[kFloatsPerInstance + InstanceFieldOffset.dashPeriod].abs();
    expect(yPeriod / xPeriod, closeTo(5.0 / 2.0, 1e-6),
        reason: 'the x-running segment scales by 2, the y-running segment '
            'by 5 -- scaleMagnitude would give both sqrt(10) and a ratio '
            'of 1.0');
  });

  test(
      'the phase of every polyline segment is zero -- the pattern restarts '
      'at each vertex, which is dasher.dart:94-96', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(dashed, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]), 4, dashStyle,
        closed: false);
    c.endDash();
    c.endResidual();
    expect(c.instanceCount, 3, reason: 'three segments, D == 1 each, no joins');
    for (var i = 0; i < c.instanceCount; i++) {
      expect(
          c.data[i * kFloatsPerInstance + InstanceFieldOffset.dashPhase], 0.0);
    }
  });

  // --- dashed circles and arcs (Task 6) ------------------------------------

  test(
      'a dashed arc carries a running phase, and consecutive chords advance '
      'it by one chord of arc length', () {
    const r = 40.0;
    const sweep = 1.2;
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(5, 7));
    c.beginDash(dashed, 0.5);
    c.arc(0, 0, r, 0, sweep, dashStyle);
    c.endDash();
    c.endResidual();

    // Read the phases off the stroke instances in order.
    final data = c.data;
    final phases = <double>[
      for (var i = 0; i < c.instanceCount; i++)
        if (data[i * kFloatsPerInstance + InstanceFieldOffset.kind] ==
            kKindStroke)
          data[i * kFloatsPerInstance + InstanceFieldOffset.dashPhase]
    ];
    expect(phases.first, 0.0);

    // Each step advances by one chord's own local-arc length, scaled by that
    // chord's own factor (chord/arc) -- the SAME factor and the SAME step for
    // every chord here, because a residual that is a pure translation
    // (scaleMagnitude == 1) leaves collection-space chord length equal to
    // local chord length, and every chord of a circular arc flattened at a
    // constant angular step has the same chord length. Recomputed from the
    // reference's own flattening formula, not hardcoded, so the test tracks
    // a tolerance change instead of pinning today's step count.
    final steps =
        (sweep.abs() * math.sqrt(r / (8 * VerticesDrawSink.kFlattenTolerance)))
            .ceil()
            .clamp(1, VerticesDrawSink.kMaxFlattenSegments);
    final step = sweep / steps;
    final arcStep = r * step.abs();
    final chordLen = 2 * r * math.sin(step.abs() / 2);
    final expectedAdvance = chordLen; // arcStep * (chordLen / arcStep)
    // Ruling C4's own bound: the disagreement between arc and chord stays
    // inside one chord, under a tenth of a pixel at this flattener's 0.25 px
    // sagitta.
    expect(arcStep - chordLen, lessThan(0.1));

    final period = data[InstanceFieldOffset.dashPeriod].abs();
    for (var i = 1; i < phases.length; i++) {
      final delta = (phases[i] - phases[i - 1] + period) % period;
      expect(delta, closeTo(expectedAdvance, 1e-3),
          reason: 'a constant advance is what "running" means; a phase that '
              'restarts per chord is dasher.dart\'s polyline rule applied '
              'to a curve, which is the spec\'s own named mutation');
    }
  });

  test(
      'a dashed circle carries a running phase all the way through its '
      'closing chord -- the pair the loop never assigns', () {
    // The open-arc version of this test (above) cannot reach the closing
    // chord at all: `_endRun` returns early for an open run, so the seam
    // this defect lives in never exists there. A CLOSED sweep is the only
    // fixture that exercises `_endRun`'s own `_runTo` call, which draws the
    // chord from the loop's last point back to the first.
    //
    // The wrap from the CLOSING chord back to chord one is deliberately not
    // asserted here: the circle's true circumference is not, in general, an
    // exact multiple of the dash period, so that one seam has a genuine,
    // expected discontinuity. Every OTHER adjacency -- including the pair
    // this defect corrupts, chord `steps - 1` to the closing chord `steps`
    // -- must not.
    const r = 65.0;
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(5, 7));
    c.beginDash(dashed, 1.7);
    c.circle(0, 0, r, dashStyle);
    c.endDash();
    c.endResidual();

    final data = c.data;
    final phases = <double>[
      for (var i = 0; i < c.instanceCount; i++)
        if (data[i * kFloatsPerInstance + InstanceFieldOffset.kind] ==
            kKindStroke)
          data[i * kFloatsPerInstance + InstanceFieldOffset.dashPhase]
    ];

    final steps =
        (2 * math.pi * math.sqrt(r / (8 * VerticesDrawSink.kFlattenTolerance)))
            .ceil()
            .clamp(1, VerticesDrawSink.kMaxFlattenSegments);
    expect(phases.length, steps,
        reason: 'one stroke per chord -- `dashed` has D == 1');
    final step = (2 * math.pi) / steps;
    final chordLen = 2 * r * math.sin(step.abs() / 2);
    final expectedAdvance = chordLen; // same law as the open-arc test above

    final period = data[InstanceFieldOffset.dashPeriod].abs();
    for (var i = 0; i < phases.length - 1; i++) {
      final delta = (phases[i + 1] - phases[i] + period) % period;
      expect(delta, closeTo(expectedAdvance, 1e-3),
          reason: 'chord $i to chord ${i + 1} must advance by the same '
              'one-chord step everywhere, including into the closing '
              'chord at the very end of this list; a stale phase left '
              'behind on the closing chord shows up as a near-zero (or '
              'doubled) delta at exactly that one pair');
    }
  });

  test('a dashed circle emits no seam join', () {
    const r = 40.0;
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    c.beginDash(dashed, 0.5);
    c.circle(0, 0, r, dashStyle);
    c.endDash();
    c.endResidual();

    final solid =
        GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    solid.beginResidual(Transform2.identity());
    solid.circle(0, 0, r, dashStyle);
    solid.endResidual();

    // The solid circle's join count is chords; the dashed one's is chords - 1
    // (interior joins only, no seam).
    expect(_joinCount(c), _joinCount(solid) - 1);
  });

  test(
      'a solid circle still has its seam join -- the assertion above is '
      'about dashes', () {
    // Guards against "no joins at all" passing the test above.
    final solid =
        GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    solid.beginResidual(Transform2.identity());
    solid.circle(0, 0, 40, dashStyle);
    solid.endResidual();
    expect(_joinCount(solid), greaterThan(0));
  });

  test('the chord count does not change when a dash bracket is open', () {
    // Flattening is a scale decision, not a linetype one. A dashed arc that
    // chorded differently from a solid one would put the two arms' geometry
    // in different places for a reason that has nothing to do with the
    // pattern. dashDot has D == 2 drawn elements, so the dashed arm writes
    // exactly two strokes per chord.
    const r = 40.0;
    const sweep = 1.2;
    final dashedC =
        GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    dashedC.beginResidual(Transform2.identity());
    dashedC.beginDash(dashDot, 0.5);
    dashedC.arc(0, 0, r, 0, sweep, dashStyle);
    dashedC.endDash();
    dashedC.endResidual();

    final solidC =
        GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    solidC.beginResidual(Transform2.identity());
    solidC.arc(0, 0, r, 0, sweep, dashStyle);
    solidC.endResidual();

    expect(_strokeCount(dashedC) ~/ 2, _strokeCount(solidC));
  });

  test(
      'an anisotropic residual scales each chord\'s period by that chord\'s '
      'own ratio, not by one number for the whole arc', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.scale(3.0, 1.0)); // a circle becomes an ellipse
    c.beginDash(dashed, 0.5);
    c.arc(0, 0, 40, 0, math.pi, dashStyle);
    c.endDash();
    c.endResidual();
    final data = c.data;
    final periods = <double>[
      for (var i = 0; i < c.instanceCount; i++)
        if (data[i * kFloatsPerInstance + InstanceFieldOffset.kind] ==
            kKindStroke)
          data[i * kFloatsPerInstance + InstanceFieldOffset.dashPeriod].abs()
    ];
    expect(
        periods.reduce(math.max) / periods.reduce(math.min), closeTo(3.0, 0.1),
        reason: 'a chord along x is stretched 3x and a chord along y is not; '
            'one period for the whole arc would read 1.0 here and would be '
            'the scaleMagnitude approximation this fixture exists to reject');
  });

  test('the phase is reduced into [0, period) at collection', () {
    // A long arc accumulates many periods; leaving them in the record spends
    // float32 precision the fragment stage needs for `fract`. A full circle
    // at period 9.0 (cycle 18.0 x patternToLocal 0.5) against a ~251-unit
    // circumference wraps roughly 28 times, so an unreduced phase would run
    // into the hundreds.
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    c.beginDash(dashed, 0.5);
    c.circle(0, 0, 40, dashStyle);
    c.endDash();
    c.endResidual();

    final data = c.data;
    var sawStroke = false;
    for (var i = 0; i < c.instanceCount; i++) {
      final o = i * kFloatsPerInstance;
      if (data[o + InstanceFieldOffset.kind] != kKindStroke) continue;
      sawStroke = true;
      final phase = data[o + InstanceFieldOffset.dashPhase];
      final period = data[o + InstanceFieldOffset.dashPeriod].abs();
      expect(phase, greaterThanOrEqualTo(0.0));
      expect(phase, lessThan(period));
    }
    expect(sawStroke, isTrue);
  });
}
