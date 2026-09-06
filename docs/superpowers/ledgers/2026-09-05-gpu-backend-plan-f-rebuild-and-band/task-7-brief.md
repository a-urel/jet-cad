### Task 7: The band is measured (criterion 2), and both zoom defects are reproduced on tiles and absent on the resident arm (criterion 12)

**Files:**
- Modify: `test/support/gpu_comparison.dart` (`CompositedAgreement.uncovered`, `collectionViewport:`)
- Create: `test/support/resident_zoom_rig.dart`
- Test: `test/gpu/band_sweep_test.dart`, `test/gpu/zoom_defect_test.dart`
- Possibly modify: `lib/src/gpu/text_patches.dart` (the two band constants, per Ruling F6 — only if Step 4's rows say so)

**Interfaces:**
- Consumes: `measureCompositedAgreement` (Plan E), `collectionFrameFor`
  (Task 1), `zoomedAbout` (Task 2), `TileRig`, `measureTiledAgreement`,
  `InkReport` (`tile_comparison.dart`), `crossingGrid`, `tileCamera`,
  `kTileViewport`, `kTileDpr` (`tile_fixture.dart`).
- Produces: `CompositedAgreement.uncovered`; `ResidentZoomRig`; the reported
  band; the band constants' final values.

- [ ] **Step 1: The instrument grows an `uncovered` count and a collection viewport**

In `test/support/gpu_comparison.dart`:

```dart
class CompositedAgreement {
  const CompositedAgreement(this.union, this.withinTwo, this.overEight,
      this.referenceInk, this.patchCount, this.uncovered);
  final int union, withinTwo, overEight, referenceInk, patchCount;

  /// Reference ink the resident arm left blank -- the zoom-out defect's own
  /// unit (`InkReport.uncoveredPixels` on the tiled arm).
  final int uncovered;
  double get agreement => union == 0 ? 1.0 : withinTwo / union;

  @override
  String toString() => 'CompositedAgreement(agreement=${agreement.toStringAsFixed(5)} '
      'withinTwo=$withinTwo union=$union overEight=$overEight '
      'uncovered=$uncovered referenceInk=$referenceInk patches=$patchCount)';
}
```

`measureCompositedAgreement` gains `Size? collectionViewport` (doc: *"the
viewport the collector walks under -- `collectionFrameFor(...).viewport` for
a rebuild's arrangement; defaults to `size`, Plan E's arrangement"*), and
uses it: `painter.paint(collector, collectionCamera, collectionViewport ??
size);`. In the pixel loop, after `final inkA = ..., inkB = ...;` add `var
uncovered = 0;` outside and `if (inkA && !inkB) uncovered++;` inside, and
pass it as the sixth argument.

- [ ] **Step 2: The resident rig**

`test/support/resident_zoom_rig.dart`:

```dart
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'gpu_comparison.dart';
import 'tile_fixture.dart';

/// The resident arm as a rig (Ruling F13): the collection frame a rebuild
/// would take at the gesture's start, re-collected whenever a frame's ratio
/// leaves the band -- `ResidentRebuilder`'s policy applied in-rig -- and
/// every frame compared against a live reference at the same camera.
///
/// **A frame out of band is drawn from the collection the rig has**, counted
/// in [staleFrames], and the re-collection lands for the NEXT frame, exactly
/// as the rebuilder's post-frame callback would order it.
class ResidentZoomRig {
  ResidentZoomRig(this.doc, this.measurer, ViewportTransform start,
      {this.bandLowerScale = kBandLowerScale,
      this.bandUpperScale = kBandUpperScale,
      this.size = kTileViewport,
      this.dpr = kTileDpr}) {
    _collectAt(start);
  }

  final DraftDocument doc;
  final FlutterTextMeasurer measurer;
  final double bandLowerScale, bandUpperScale;
  final Size size;
  final double dpr;

  late CollectionFrame collectionFrame;
  int rebuilds = 0;
  int staleFrames = 0;

  void _collectAt(ViewportTransform live) {
    collectionFrame = collectionFrameFor(live, doc.extents);
  }

  bool inBand(ViewportTransform live) {
    final ratio = live.scale / collectionFrame.camera.scale;
    return ratio >= bandLowerScale && ratio <= bandUpperScale;
  }

  Future<CompositedAgreement> frame(ViewportTransform live) async {
    final m = await measureCompositedAgreement(doc,
        collectionCamera: collectionFrame.camera,
        collectionViewport: collectionFrame.viewport,
        liveCamera: live,
        size: size,
        devicePixelRatio: dpr,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer);
    if (!inBand(live)) {
      staleFrames++;
      _collectAt(live);
      rebuilds++;
    }
    return m;
  }
}
```

- [ ] **Step 3: The band sweep**

`test/gpu/band_sweep_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/gpu_comparison.dart';
import '../support/recording_frame_painter.dart';

/// Live-over-collection ratios, the band's two provisional edges among them.
const List<double> kRatios = [0.25, 0.35, 0.5, 0.7, 1.0, 1.4, 2.0, 2.8, 4.0];
const Size _size = Size(800, 600);
const Offset _centre = Offset(400, 300);
const double _dpr = 1.0;

/// Criterion 1, literally: per-channel <= 2 on >= 99.5% of the union, <= 8
/// on the rest, and differing pixels below 1% of live ink.
bool criterionOne(CompositedAgreement m) =>
    m.union > 0 &&
    m.withinTwo / m.union >= 0.995 &&
    m.overEight == 0 &&
    (m.union - m.withinTwo) < 0.01 * m.referenceInk;

Future<Map<double, CompositedAgreement>> sweep(
  DraftDocument doc,
  FlutterTextMeasurer measurer, {
  required String name,
  required ViewportTransform collection,
  required double minTextCapPixels,
}) async {
  final frame = collectionFrameFor(collection, doc.extents);
  final rows = <double, CompositedAgreement>{};
  for (final r in kRatios) {
    final m = await measureCompositedAgreement(doc,
        collectionCamera: frame.camera,
        collectionViewport: frame.viewport,
        liveCamera: zoomedAbout(collection, _centre, r),
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        minTextCapPixels: minTextCapPixels);
    rows[r] = m;
    // ignore: avoid_print
    print('BAND $name ratio=$r ${criterionOne(m) ? "PASS" : "FAIL"} $m');
  }
  return rows;
}

/// The widest contiguous run of passing ratios containing 1.0.
(double, double) passingRun(Map<double, CompositedAgreement> rows) {
  var lo = 1.0, hi = 1.0;
  final i1 = kRatios.indexOf(1.0);
  for (var i = i1 - 1; i >= 0 && criterionOne(rows[kRatios[i]]!); i--) {
    lo = kRatios[i];
  }
  for (var i = i1 + 1; i < kRatios.length && criterionOne(rows[kRatios[i]]!); i++) {
    hi = kRatios[i];
  }
  return (lo, hi);
}

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  test("solid curves: criterion 1 holds at the band's edges and at 1.0, and "
      'the divergence past the band is real', () async {
    final doc = differentialFixture(measurer: measurer);
    final fit = ViewportTransform.fit(doc.extents, _size);
    final rows = await sweep(doc, measurer,
        name: 'curves@fit', collection: fit, minTextCapPixels: 0);
    for (final r in [kBandLowerScale, 1.0, kBandUpperScale]) {
      expect(criterionOne(rows[r]!), isTrue, reason: 'ratio $r: ${rows[r]}');
    }
    expect(rows[1.0]!.referenceInk, greaterThan(5000));
    // Anti-vacuity: the frozen chord count is a real divergence at 4x, so
    // this instrument is not comparing the resident arm to itself.
    expect(rows[4.0]!.agreement, lessThan(rows[1.0]!.agreement));
    final (lo, hi) = passingRun(rows);
    // ignore: avoid_print
    print('BAND curves@fit run=[$lo, $hi] = ${(hi / lo).toStringAsFixed(2)}x');
  });

  test('solid curves at a working zoom: Float32 at 8x the fit scale holds '
      "criterion 1 at the band's edges", () async {
    final doc = differentialFixture(measurer: measurer);
    final working = zoomedAbout(ViewportTransform.fit(doc.extents, _size), _centre, 8.0);
    final rows = await sweep(doc, measurer,
        name: 'curves@8x', collection: working, minTextCapPixels: 0);
    for (final r in [kBandLowerScale, 1.0, kBandUpperScale]) {
      expect(criterionOne(rows[r]!), isTrue, reason: 'ratio $r: ${rows[r]}');
    }
    expect(rows[1.0]!.referenceInk, greaterThan(5000));
  });

  test("text with level of detail on: criterion 1 holds at the band's edges "
      'and at 1.0', () async {
    final doc = textOverlapFixture(measurer);
    final fit = ViewportTransform.fit(doc.extents, _size);
    final rows = await sweep(doc, measurer,
        name: 'text-lod@fit', collection: fit, minTextCapPixels: kMinTextCapPixels);
    for (final r in [kBandLowerScale, 1.0, kBandUpperScale]) {
      expect(criterionOne(rows[r]!), isTrue, reason: 'ratio $r: ${rows[r]}');
    }
    expect(rows[1.0]!.patchCount, greaterThanOrEqualTo(1));
    final (lo, hi) = passingRun(rows);
    // ignore: avoid_print
    print('BAND text-lod@fit run=[$lo, $hi] = ${(hi / lo).toStringAsFixed(2)}x');
  });
}
```

- [ ] **Step 4: Run it, read the rows, and apply Ruling F6**

Run: `flutter test test/gpu/band_sweep_test.dart`

Three outcomes, each with a fixed response:

1. **Every assertion green.** The constants stay `0.5` / `2.0`. Record the
   three printed runs and their intersection in the report as *the reported
   band*.
2. **An edge assertion is red** (a row at `0.5` or `2.0` fails criterion 1).
   Move that constant in `text_patches.dart` to the nearest passing grid
   ratio toward 1.0 (`0.5 → 0.7`, or `2.0 → 1.4`). Re-run this file, then
   `text_patches_test.dart`, `text_order_test.dart`, `resident_rebuilder_test.dart`
   and `draft_canvas_resident_test.dart` — Plan E's *"the band constants and
   the pad are what the spec says"* test and this plan's `2.01`/`1.9` band
   probes name the old values and must be updated to the new ones, and only
   to the new ones. Ledger the change with the failing row pasted.
3. **The intersection of the runs is narrower than 2×** (`hi / lo < 2`).
   Outcome 2 applies to the constants, and the results note records
   criterion 2 as **the design failure the spec names**, with the rows.

The `4.0 < 1.0` anti-vacuity assertion failing is a different thing: it says
the instrument cannot see the chord divergence at all, and that is a Task 7
defect to fix (check `collectionViewport` reached the collector), not a
band result.

- [ ] **Step 5: The zoom defects**

`test/gpu/zoom_defect_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

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
    test('the tiled arm leaves ink uncovered during the gesture and one frame '
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
      Future<void> frame() async {
        final m = await rig.frame(camera);
        expect(m.referenceInk, greaterThan(1000), reason: 'anti-vacuity: $m');
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
          'stale=${rig.staleFrames}');
      // MUTATION (M-F5): collect under the live camera and kTileViewport ->
      // the first zoom-out step reveals uncovered ink at the viewport's rim.
      expect(uncovered, everyElement(0));
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

    test('the resident arm matches the reference at every frame, with no '
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
        expect(m.agreement, greaterThanOrEqualTo(0.995), reason: 'frame $i: $m');
      }
      expect(rig.rebuilds, 0, reason: '1.02^12 = 1.27 stays inside the band');
    });
  });
}
```

`TileRig.dispose` is whatever `tile_fixture.dart` exposes for teardown; if
the rig has none, tear down its `measurer.clear()` and `index.dispose()`
directly, as `tile_cache_test.dart` does.

- [ ] **Step 6: Run; expect PASS. Record the printed rows**

Run: `flutter test test/gpu/zoom_defect_test.dart test/gpu/text_order_test.dart test/gpu/resident_pixel_differential_test.dart`

- [ ] **Step 7: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add test/support/gpu_comparison.dart test/support/resident_zoom_rig.dart test/gpu/band_sweep_test.dart test/gpu/zoom_defect_test.dart lib/src/gpu/text_patches.dart
git commit -m "test(gpu): the band is measured, and both zoom defects reproduce on tiles and vanish on the resident arm"
```

---

