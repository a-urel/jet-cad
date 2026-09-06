import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

/// A label with a box and an index -- nothing else matters to the classifier.
ResidentTextRecord _label(
        {required double minX,
        required double minY,
        required double maxX,
        required double maxY,
        required int at}) =>
    ResidentTextRecord(
        text: 'L',
        style: const Handle(11),
        argb: 0xFF000000,
        a: 1,
        b: 0,
        c: 0,
        d: 1,
        e: 0,
        f: 0,
        boxMinX: minX,
        boxMinY: minY,
        boxMaxX: maxX,
        boxMaxY: maxY,
        instanceIndex: at);

/// A buffer built record by record through the real writers, so the
/// classifier is read against the layout the shader reads, not a hand-rolled
/// one.
class _Buf {
  final Float32List data = Float32List(kFloatsPerInstance * 32);
  int count = 0;
  void stroke(double x0, double y0, double x1, double y1, {double half = 1}) {
    writeStroke(data, count++,
        x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: 0xFF000000);
  }

  void join(double vx, double vy, double px, double py, double nx, double ny,
      {double half = 1}) {
    writeJoin(data, count++,
        vx: vx,
        vy: vy,
        prevX: px,
        prevY: py,
        nextX: nx,
        nextY: ny,
        halfWidth: half,
        argb: 0xFF000000);
  }

  void point(double x, double y, {double half = 1}) {
    writePoint(data, count++, x: x, y: y, halfWidth: half, argb: 0xFF000000);
  }

  void fill(double x0, double y0, double x1, double y1, double x2, double y2) {
    writeFill(data, count++,
        x0: x0, y0: y0, x1: x1, y1: y1, x2: x2, y2: y2, argb: 0xFF000000);
  }
}

void main() {
  // dpr 1, band floor 1: reach in collection units == reach in device pixels,
  // so every number below is readable without a conversion. Tests that are
  // ABOUT the conversion pass their own floor.
  const dpr = 1.0;
  const floor = 1.0;

  test('an instance emitted after the label and crossing its box is a patch',
      () {
    final b = _Buf()
      ..stroke(0, 0, 10, 0) // index 0: before the label
      ..stroke(0, 50, 100, 50); // index 1: after, crosses the box
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 1)];
    final patches = classifyTextPatches(b.data, b.count, texts,
        devicePixelRatio: dpr, bandLowerScale: floor);
    expect(patches, hasLength(1));
    expect(patches.single.textIndex, 0);
    expect(patches.single.instanceCount, 1);
    // The sub-buffer is a verbatim copy of record 1, all sixteen floats.
    final sub = patches.single.instances;
    for (var i = 0; i < kFloatsPerInstance; i++) {
      expect(sub[i], b.data[kFloatsPerInstance + i], reason: 'float $i');
    }
  });

  test('an instance emitted BEFORE the label never enters its patch', () {
    final b = _Buf()
      ..stroke(0, 50, 100, 50) // crosses the box, but index 0 < 1
      ..stroke(0, 0, 10, 0);
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 1)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        isEmpty,
        reason: 'the reference draws it under the label; so must we');
  });

  test('a label nothing reaches has no patch, and one that is reached does',
      () {
    final b = _Buf()..stroke(0, 50, 100, 50); // index 0
    final texts = [
      _label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0), // reached
      _label(minX: 40, minY: 400, maxX: 60, maxY: 420, at: 0), // not
    ];
    final patches = classifyTextPatches(b.data, b.count, texts,
        devicePixelRatio: dpr, bandLowerScale: floor);
    expect(patches.map((p) => p.textIndex), [0]);
  });

  test(
      'a stroke whose centerline misses the box but whose width reaches it '
      'is a patch', () {
    // Centerline at y = 65, box top at 60, half-width 6: the stroke's lower
    // edge is at 59, inside the box. A classifier that tested the centerline
    // (reach 0) would miss it.
    final b = _Buf()..stroke(0, 65, 100, 65, half: 6);
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        hasLength(1));
    // And with half-width 4 (edge at 61) it is not.
    final n = _Buf()..stroke(0, 65, 100, 65, half: 4);
    expect(
        classifyTextPatches(n.data, n.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        isEmpty);
  });

  test("a join's reach is the miter bound, 4 x half-width", () {
    // Vertex at (50, 70), box top at 60: distance 10. Half-width 3 reaches
    // 12 with the miter bound (in), and 3 without it (out).
    final b = _Buf()..join(50, 70, 0, 70, 100, 70, half: 3);
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        hasLength(1),
        reason: 'reach = half * kMiterLimit = 12 >= 10');
    final far = _Buf()..join(50, 73, 0, 73, 100, 73, half: 3);
    expect(
        classifyTextPatches(far.data, far.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        isEmpty,
        reason: '12 < 13');
  });

  test('a fill has no reach: its corners are the whole of it', () {
    final b = _Buf()..fill(0, 61, 100, 61, 50, 90); // 1 unit above the box
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        isEmpty);
  });

  test("a point's box is its one point -- never the origin (Ruling E4)", () {
    // The point is far from the label; the label sits AT the origin, where
    // `writePoint`'s zeroed x1, y1, x2, y2 would land if they were read.
    final b = _Buf()..point(500, 500, half: 2);
    final texts = [_label(minX: -5, minY: -5, maxX: 5, maxY: 5, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        isEmpty);
    final near = _Buf()..point(6, 0, half: 2);
    expect(
        classifyTextPatches(near.data, near.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        hasLength(1));
  });

  test('the reach is expanded at the band floor, in collection units', () {
    // Half-width 4 device px; dpr 2; floor 0.5: reach = 4 / (2 * 0.5) = 4.0
    // collection units. Centerline 3.5 above the box: in at the floor, out
    // if expanded at the reference scale (4 / 2 = 2.0).
    final b = _Buf()..stroke(0, 63.5, 100, 63.5, half: 4);
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: 2.0, bandLowerScale: 0.5),
        hasLength(1));
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: 2.0, bandLowerScale: 1.0),
        isEmpty,
        reason: 'expanding at the reference scale is the named mutation');
  });

  test('a sub-buffer keeps main-buffer order and skips non-reaching instances',
      () {
    final b = _Buf()
      ..stroke(0, 50, 100, 50) // 0 in
      ..stroke(0, 500, 100, 500) // 1 out
      ..stroke(50, 0, 50, 100) // 2 in
      ..stroke(0, 45, 100, 45); // 3 in
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    final p = classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor)
        .single;
    expect(p.instanceCount, 3);
    double y0(int k) =>
        p.instances[k * kFloatsPerInstance + InstanceFieldOffset.y0];
    expect([y0(0), y0(1), y0(2)], [50, 0, 45],
        reason: 'emission order, not sorted, not reversed');
  });

  test('patches come back in ascending text index, one per covered label', () {
    final b = _Buf()
      ..stroke(0, 50, 100, 50) // 0
      ..stroke(0, 250, 100, 250); // 1
    final texts = [
      _label(minX: 40, minY: 240, maxX: 60, maxY: 260, at: 0), // hit by 1
      _label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0), // hit by 0
    ];
    final patches = classifyTextPatches(b.data, b.count, texts,
        devicePixelRatio: dpr, bandLowerScale: floor);
    expect(patches.map((p) => p.textIndex), [0, 1]);
  });

  test('a dashed stroke is a candidate over its whole segment, gaps included',
      () {
    final b = _Buf();
    writeStroke(b.data, b.count++,
        x0: 0,
        y0: 50,
        x1: 100,
        y1: 50,
        halfWidth: 1,
        argb: 0xFF000000,
        dashPeriod: -20,
        dashPhase: 0,
        dashFracStart: 0.0,
        dashFracEnd: 0.1);
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        hasLength(1),
        reason: 'the record carries the segment; over-inclusion is correct');
  });

  group('patchRegionFor', () {
    // A label whose collection box is (10, 20) .. (50, 40); the camera maps
    // collection to device by scale 2 and a translation, so on screen the
    // box is (120, 240) .. (200, 280).
    final t = _label(minX: 10, minY: 20, maxX: 50, maxY: 40, at: 0);
    const cam = Transform2(2, 0, 0, 2, 100, 200);

    test('is the box under the camera, rounded outward, on screen', () {
      final r =
          patchRegionFor(t, cam, 800, 600, maxWidth: 800, maxHeight: 600)!;
      expect([r.x, r.y, r.width, r.height], [120, 240, 80, 40]);
    });

    test('rounds outward, never inward', () {
      const cam2 = Transform2(2, 0, 0, 2, 100.4, 200.6);
      final r =
          patchRegionFor(t, cam2, 800, 600, maxWidth: 800, maxHeight: 600)!;
      // 120.4 -> 120, 240.6 -> 240, right edge 200.4 -> 201, bottom 280.6 -> 281
      expect([r.x, r.y, r.width, r.height], [120, 240, 81, 41]);
    });

    test('a label partly off the top-left edge is clamped, not negative', () {
      // `Viewport` and `Scissor` throw on a negative origin. Box on screen:
      // (-40, -20) .. (40, 20) -> the visible part is (0, 0) .. (40, 20).
      const cam3 = Transform2(2, 0, 0, 2, -60, -60);
      final r =
          patchRegionFor(t, cam3, 800, 600, maxWidth: 800, maxHeight: 600)!;
      expect([r.x, r.y, r.width, r.height], [0, 0, 40, 20]);
      // Box on screen: (-280, -360) .. (-200, -320) -> entirely off: null.
      const cam4 = Transform2(2, 0, 0, 2, -300, -400);
      expect(patchRegionFor(t, cam4, 800, 600, maxWidth: 800, maxHeight: 600),
          isNull);
    });

    test('a region larger than the target is clamped to the target', () {
      final r = patchRegionFor(t, cam, 800, 600, maxWidth: 30, maxHeight: 30)!;
      expect([r.width, r.height], [30, 30]);
    });

    test('a rotated camera bounds all four corners', () {
      // 90-degree rotation: the 40x20 box becomes 20x40 on screen; a region
      // built from two corners only would have a negative size.
      final rot = Transform2.translation(300, 300)
          .multiply(Transform2.rotation(3.141592653589793 / 2));
      final r =
          patchRegionFor(t, rot, 800, 600, maxWidth: 800, maxHeight: 600)!;
      expect(r.width, 20);
      expect(r.height, 40);
    });

    test('patchRegionFor writes into `out` and leaves it alone when off screen',
        () {
      final t = ResidentTextRecord(
          text: 'X',
          style: const Handle(11),
          argb: 0xFF000000,
          a: 1,
          b: 0,
          c: 0,
          d: -1,
          e: 0,
          f: 0,
          boxMinX: 10,
          boxMinY: 20,
          boxMaxX: 50,
          boxMaxY: 40,
          instanceIndex: 0);
      final out = PatchRegion(7, 7, 7, 7);
      final onScreen = patchRegionFor(t, Transform2.scale(2, 2), 800, 600,
          maxWidth: 4096, maxHeight: 4096, out: out);
      expect(identical(onScreen, out), isTrue);
      expect((out.x, out.y, out.width, out.height), (20, 40, 80, 40));
      final offScreen = patchRegionFor(
          t, Transform2.translation(-1000, 0), 800, 600,
          maxWidth: 4096, maxHeight: 4096, out: out);
      expect(offScreen, isNull);
      expect((out.x, out.y, out.width, out.height), (20, 40, 80, 40),
          reason: 'an off-screen answer must not scribble on the pool entry');
    });
  });

  group('patchTargetSizeFor', () {
    final t = _label(minX: 10, minY: 20, maxX: 50, maxY: 40, at: 0);
    test('is the box at the band ceiling, in device pixels, rounded up', () {
      // 40x20 collection units * dpr 2 * ceiling 2 = 160x80.
      expect(patchTargetSizeFor(t, 2.0, maxWidth: 4000, maxHeight: 4000),
          (160, 80));
    });
    test('is clamped to the viewport', () {
      expect(
          patchTargetSizeFor(t, 2.0, maxWidth: 100, maxHeight: 50), (100, 50));
    });
    test('is never zero', () {
      final thin = _label(minX: 10, minY: 20, maxX: 10, maxY: 20, at: 0);
      expect(
          patchTargetSizeFor(thin, 1.0, maxWidth: 100, maxHeight: 100), (1, 1));
    });
  });
}
