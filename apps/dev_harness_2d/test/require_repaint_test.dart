// What `requireRepaint` counts as evidence that the forced frame drew.
//
// **The defect this file exists for.** Every rig in `measurement_rig.dart`
// ends the same way: settle, reset the counters, force one repaint with
// `panBy(Offset.zero)`, and print that frame's numbers. `requireRepaint` is
// the guard that stands between "the forced frame did not happen" and a
// transcript of zeros -- and, in its own words, "a zero is the one wrong
// number nobody questions". Under `TILES=on` the two sink counters it was
// built on are both entitled to read zero on a perfectly healthy frame, so
// the guard was given a `tileCache` parameter and the cache's counters.
//
// Two things were wrong with that. The parameter was optional and `runR2Rig`
// -- the whole app-run script -- never passed it, so the guard threw on a
// frame that had drawn (observed 2026-08-29 at `TILES=on ENTITIES=5000
// RUN_R2=true`, clean on the same corpus with tiles off). And the counters it
// summed were `blitCount` and `liveDrawCount`, which are *both zero* on the
// two-regime frames Plan 3i introduced: a moving frame and the in-between
// frame at `_restGateSteps == 1` draw the carry-over composite and nothing
// else. `carryOverBlitCount` is the only counter that sees those.
//
// **The fixture is a real `TileCache` driven into that state, not a stub.**
// The claim is about what the cache actually leaves on its counters after a
// zoom frame, and a hand-set counter would assert the author's belief about
// that rather than the cache's behaviour. The rig below is the smallest thing
// that can reach it: bake a generation until the viewport is covered, then
// zoom in by a factor big enough that the magnified composite covers the
// viewport on its own and no live fallback is owed.
//
// `requireRepaint` and not `runR2Rig`: the rig opens with `refuseDebugMode()`
// -- correctly, since a debug frame time means nothing -- and `flutter test`
// is a debug build. What gates the *call site* is that `tileCache` is now a
// **required** named parameter, so `requireRepaint(sink, vertices)` no longer
// compiles; see this test's mutation log entries (M25, M26).

import 'dart:ui';

import 'package:dev_harness_2d/measurement_rig.dart';
import 'package:dev_harness_2d/seam_corpus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// Small enough that a viewport is many tiles, per the anti-degenerate rule:
/// at the production 256 the fixture below would fit in a handful and a
/// coverage claim would be one tile's claim.
const int _tilePx = 64;

const Size _viewport = Size(400, 300);
const double _dpr = 2.0;

/// One document, one cache, and a `Canvas` that goes nowhere.
///
/// Deliberately *not* `ViewportTransform.fit` and deliberately not at the
/// origin: `seamCorpus` sits six million world units out (`kDefaultOriginX`),
/// the scale is not 1, and the y axis is flipped, so no assertion below can
/// pass because the transform happened to be the identity.
class _Rig {
  _Rig() : measurer = FlutterTextMeasurer() {
    doc = seamCorpus(measurer: measurer);
    index = SpatialIndex(doc);
    sink = CanvasDrawSink(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        textStyleOf: doc.textStyleOf);
    painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    cache = TileCache(
      tileDevicePixels: _tilePx,
      // Generous: this fixture is about which counters move on a *moving*
      // frame, and a budget that made coverage take a hundred frames would
      // only make the warm-up slower.
      bakeBudgetDevicePixels: 1000 * _tilePx * _tilePx,
    );

    final e = doc.extents;
    const scale = 0.1;
    final cx = (e.minX + e.maxX) / 2;
    final cy = (e.minY + e.maxY) / 2;
    camera = ViewportTransform(
        worldToScreenMatrix: Transform2(
            scale,
            0,
            0,
            -scale,
            _viewport.width / 2 - scale * cx,
            _viewport.height / 2 + scale * cy));
  }

  final FlutterTextMeasurer measurer;
  late final DraftDocument doc;
  late final SpatialIndex index;
  late final CanvasDrawSink sink;
  late final DraftPainter painter;
  late final TileCache cache;
  late ViewportTransform camera;

  /// Paints one frame into a recorder whose picture is disposed -- a `Picture`
  /// holds native memory past the Dart object.
  void paintOnce() {
    final recorder = PictureRecorder();
    cache.paintFrame(
      canvas: Canvas(recorder),
      viewport: _viewport,
      devicePixelRatio: _dpr,
      camera: camera,
      painter: painter,
      sink: sink,
      vertices: null,
      tablesRevision: doc.tables.mutationRevision,
    );
    recorder.endRecording().dispose();
  }

  /// Scales about the viewport centre, the way a zoom gesture keeps the point
  /// under the cursor still. Scaling `a` and `d` alone would pin whatever
  /// world point sits at `(e, f)` -- outside this viewport -- and slide the
  /// composite off one edge, which would make the "no live fallback" reading
  /// below a fact about the rig instead of about the cache.
  void zoomBy(double factor) {
    final m = camera.worldToScreenMatrix;
    final cx = _viewport.width / 2;
    final cy = _viewport.height / 2;
    camera = ViewportTransform(
        worldToScreenMatrix: Transform2(
            m.a * factor,
            m.b * factor,
            m.c * factor,
            m.d * factor,
            cx + (m.e - cx) * factor,
            cy + (m.f - cy) * factor));
  }

  /// Paints until the generation covers the viewport, or gives up.
  void warmUntilCovered() {
    for (var i = 0; i < 60 && !cache.viewportCovered; i++) {
      paintOnce();
    }
  }

  void dispose() {
    cache.dispose();
    index.dispose();
    doc.dispose();
  }
}

void main() {
  test('a frame that never ran throws, on a warm cache', () {
    final rig = _Rig();
    addTearDown(rig.dispose);
    rig.warmUntilCovered();
    expect(rig.cache.viewportCovered, isTrue,
        reason: 'non-vacuity: the throw below must come from "no frame ran", '
            'not from a cache that never worked in the first place');

    // The state the rigs put themselves in immediately before their one
    // forced repaint. A cache fresh from its constructor would throw for a
    // reason no rig can reach; this one has baked, blitted and covered, and
    // the counters were zeroed after all of it.
    rig.sink.resetCounters();
    rig.cache.resetCounters();

    expect(() => requireRepaint(rig.sink, null, tileCache: rig.cache),
        throwsStateError,
        reason: 'no frame was pumped between the reset and the guard, so '
            'there is nothing to publish and the guard must say so');
  });

  test('a carry-over composite alone counts as a repaint', () {
    final rig = _Rig();
    addTearDown(rig.dispose);
    rig.warmUntilCovered();
    expect(rig.cache.viewportCovered, isTrue,
        reason: 'a composite is minted only from a generation that covered');

    rig.sink.resetCounters();
    rig.cache.resetCounters();

    // A moving frame: the scale changed, so the generation retires into one
    // composite, the fresh generation is empty, and nothing is baked while
    // the camera is moving. Zooming *in* by enough that the magnified
    // composite runs past all four edges is what leaves no ring for the live
    // fallback to owe.
    rig.zoomBy(1.4);
    rig.paintOnce();

    // The fixture's own claim, checked before the guard is asked anything.
    // Without these four lines this test would pass just as well on a frame
    // that blitted tiles, and the mutation that drops `carryOverBlitCount`
    // from the sum would survive.
    expect(rig.cache.carryOverBlitCount, greaterThan(0),
        reason: 'the composite is the only thing this frame drew');
    expect(rig.cache.blitCount, 0,
        reason: 'the incoming generation is empty: there is no tile to blit');
    expect(rig.cache.liveDrawCount, 0,
        reason: 'the composite covers all four edges, so no live walk is owed');
    expect(rig.sink.canvasCallCount, 0,
        reason: 'the painter was never called, which is the whole reason the '
            'sink counters cannot answer this question');

    // Nothing thrown: this frame drew.
    requireRepaint(rig.sink, null, tileCache: rig.cache);
  });
}
