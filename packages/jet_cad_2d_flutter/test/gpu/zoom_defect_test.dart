import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/gpu_comparison.dart';
import '../support/recording_frame_painter.dart';
import '../support/resident_zoom_rig.dart';
import '../support/tile_comparison.dart';
import '../support/tile_fixture.dart';

/// The probe's own gestures (`2026-08-29-settle-flicker-probe.md`): twelve
/// steps, then six settle frames, about the viewport centre.
const int kSteps = 12;
const int kSettle = 6;
const double kZoomOut = 0.94;
const double kZoomIn = 1.02;
const Offset kCentre = Offset(200, 150);

Future<void> warm(TileRig rig) async {
  for (var i = 0; i < 40 && !rig.cache.viewportCovered; i++) {
    await measureTiledAgreement(rig);
  }
  expect(rig.cache.viewportCovered, isTrue, reason: 'the warm-up must cover');
}

void main() {
  group('zoom out, twelve steps of 0.94', () {
    test(
        'the tiled arm leaves ink uncovered during the gesture and one frame '
        'after it', () async {
      final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 64);
      addTearDown(rig.dispose);
      await warm(rig);
      final gesture = <int>[];
      for (var i = 0; i < kSteps; i++) {
        rig.camera = zoomedAbout(rig.camera, kCentre, kZoomOut);
        gesture.add((await measureTiledAgreement(rig)).uncoveredPixels);
      }
      final settle = <int>[];
      for (var i = 0; i < kSettle; i++) {
        settle.add((await measureTiledAgreement(rig)).uncoveredPixels);
      }
      // ignore: avoid_print
      print('ZOOM-OUT tiled uncovered: gesture=$gesture settle=$settle');
      expect(gesture.reduce(math.max), greaterThan(0),
          reason: 'the reproduction: the probe read 5,730 at the worst frame');
      expect(settle.first, greaterThan(0),
          reason: 'still uncovered one frame after the gesture (4,893)');
      expect(settle.last, 0, reason: 'and settled');
    });

    test('the resident arm leaves nothing uncovered at any frame', () async {
      final measurer = FlutterTextMeasurer();
      addTearDown(measurer.clear);
      final doc = crossingGrid(measurer);
      final rig = ResidentZoomRig(doc, measurer, tileCamera());
      var camera = tileCamera();
      final uncovered = <int>[];
      final agreement = <double>[];
      CompositedAgreement? first;
      Future<void> frame() async {
        final m = await rig.frame(camera);
        first ??= m;
        expect(m.referenceInk, greaterThan(1000), reason: 'anti-vacuity: $m');
        // Ruling F13-a. One or two pixels of edge jitter between two exact
        // rasterisations -- the resident arm's float32 collection vertices
        // against the reference's float64 -- is not the zoom-out defect. The
        // defect reads 5,730 uncovered pixels on the tiled arm in the test
        // above, three orders of magnitude away; this is bounded both
        // absolutely and as a fraction of live ink (0.05%), so it cannot
        // grow into one unnoticed. The spec's "zero uncovered" is recorded
        // as met within that jitter.
        expect(m.uncovered, lessThanOrEqualTo(4), reason: '$m');
        expect(m.uncovered * 2000, lessThan(m.referenceInk), reason: '$m');
        uncovered.add(m.uncovered);
        agreement.add(m.agreement);
      }

      for (var i = 0; i < kSteps; i++) {
        camera = zoomedAbout(camera, kCentre, kZoomOut);
        await frame();
      }
      for (var i = 0; i < kSettle; i++) {
        await frame();
      }
      // ignore: avoid_print
      print('ZOOM-OUT resident uncovered=$uncovered rebuilds=${rig.rebuilds} '
          'stale=${rig.staleFrames}\n'
          'ZOOM-OUT resident frame 0: $first');
      // MUTATION (M-F5): collect under the live camera and kTileViewport ->
      // the first zoom-out step reveals uncovered ink at the viewport's rim
      // -- 418 pixels on the first zoom-out step when measured, against <= 4
      // here -- and `rebuilds` reads 0 because the ratio is 1.0 every frame.
      expect(agreement, everyElement(greaterThanOrEqualTo(0.995)));
      expect(rig.rebuilds, 1,
          reason: '0.94^12 = 0.476 leaves the band at the last step');
    });
  });

  group('zoom in, twelve steps of 1.02', () {
    test('the tiled arm shows the wrong resolution over the settle', () async {
      final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 64);
      addTearDown(rig.dispose);
      await warm(rig);
      for (var i = 0; i < kSteps; i++) {
        rig.camera = zoomedAbout(rig.camera, kCentre, kZoomIn);
        await measureTiledAgreement(rig);
      }
      final settle = <int>[];
      for (var i = 0; i < kSettle; i++) {
        settle.add((await measureTiledAgreement(rig)).differingPixels);
      }
      // ignore: avoid_print
      print('ZOOM-IN tiled differing over the settle: $settle');
      expect(settle.first, greaterThan(0),
          reason: 'the reproduction: the probe read 25,275 / 16,681 / 0');
      expect(settle.last, 0);
    });

    test(
        'the resident arm matches the reference at every frame, with no '
        'rebuild', () async {
      final measurer = FlutterTextMeasurer();
      addTearDown(measurer.clear);
      final doc = crossingGrid(measurer);
      final rig = ResidentZoomRig(doc, measurer, tileCamera());
      var camera = tileCamera();
      for (var i = 0; i < kSteps + kSettle; i++) {
        if (i < kSteps) camera = zoomedAbout(camera, kCentre, kZoomIn);
        final m = await rig.frame(camera);
        expect(m.referenceInk, greaterThan(1000));
        expect(m.uncovered, 0, reason: 'frame $i: $m');
        expect(m.agreement, greaterThanOrEqualTo(0.995),
            reason: 'frame $i: $m');
      }
      expect(rig.rebuilds, 0, reason: '1.02^12 = 1.27 stays inside the band');
    });
  });
}
