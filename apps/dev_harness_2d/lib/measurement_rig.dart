// The R2 measurement rig, shared between `integration_test/frame_timing_test.dart`
// and `main.dart`'s app-run mode (`RUN_R2=true`).
//
// Task 13 needed a web row and `flutter drive -d chrome` hangs in this
// environment before it ever reaches chromedriver (see the Task 13 report).
// `flutter run -d chrome --profile` forwards the app's own `print()` output
// instead, so the harness can drive itself. Lifting this code out of the
// widget test rather than reimplementing it for `main.dart` is the point:
// two independent copies of "pan 120, zoom 120, print the block" could drift
// and make the desktop and web rows describe two different measurements
// under one label. One copy, called two ways.
//
// The only thing that differs between the two call sites is *how a frame
// gets pumped*: a widget test advances a synthetic clock with
// `tester.pump(duration)`; a real running app has no synthetic clock and
// instead waits for the engine to actually render one, via
// `SchedulerBinding.instance.endOfFrame`. That is exactly the shape of the
// `pumpFrame` and `settle` parameters below — everything else, including the
// forced extra frame that makes `resetCounters()` meaningful and the guard
// against a silently-skipped repaint, is identical code for both platforms.

// ignore_for_file: avoid_print — printing the numbers is what a rig is for.

import 'dart:ui' as ui;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void refuseDebugMode() {
  var isDebug = false;
  assert(() {
    isDebug = true;
    return true;
  }());
  if (isDebug) {
    throw StateError('run with --profile; debug frame times mean nothing');
  }
}

/// p50, p95 and max of build, raster and total time, reported separately.
///
/// A build-bound frame and a raster-bound frame call for opposite fixes in
/// Plan 3b — one wants less walking, the other fewer or cheaper draw calls —
/// so a single "frame time" would hide the only thing the number is for.
///
/// **`totalSpan` is here because `build` and `raster` do not have to add up.**
/// The 2026-08-23 picture-cache spike rasterised 217,758 triangles into a
/// texture on every frame through `Picture.toImageSync` and *both* of those
/// columns stayed flat — raster read 0.87 ms, indistinguishable from a bare
/// blit — because `toImageSync` returns before the GPU work it schedules, and
/// that work lands outside either window. `totalSpan` runs vsync-start to
/// raster-finish and did see it, at 13.56 ms. Six plans have published numbers
/// from this rig with two of these three columns; a column that reads "free"
/// needs a second column that agrees.
void report(String rig, List<FrameTiming> timings) {
  if (timings.isEmpty) {
    print('$rig: no frames recorded');
    return;
  }
  String stats(List<double> ms) {
    // **The mean is here for a differencing measurement, not for taste.** A
    // pan frame either bakes a whole entering strip or bakes nothing, so the
    // per-tile bake cost is invisible to `p50` -- the median frame of a pan is
    // a pure blit -- and `p95` reads whatever the burst size happened to be at
    // that quantile. Only the mean satisfies
    // `mean = blit + bakesPerFrame * bakePerTile`, and `bakesPerFrame` is a
    // number the cache reports exactly.
    var sum = 0.0;
    for (final v in ms) {
      sum += v;
    }
    ms.sort();
    return 'p50=${ms[(ms.length * 0.5).floor()].toStringAsFixed(2)}ms '
        'p95=${ms[(ms.length * 0.95).floor()].toStringAsFixed(2)}ms '
        'max=${ms.last.toStringAsFixed(2)}ms '
        'mean=${(sum / ms.length).toStringAsFixed(2)}ms';
  }

  final build = [
    for (final t in timings) t.buildDuration.inMicroseconds / 1000.0
  ];
  final raster = [
    for (final t in timings) t.rasterDuration.inMicroseconds / 1000.0
  ];
  final total = [for (final t in timings) t.totalSpan.inMicroseconds / 1000.0];
  print('$rig frames=${timings.length}');
  print('  build  ${stats(build)}');
  print('  raster ${stats(raster)}');
  print('  total  ${stats(total)}');
}

/// Throws unless the forced frame actually drew, on whichever backend is
/// running.
///
/// `canvasCallCount` was the whole guard while `CanvasDrawSink` drew every
/// frame. Under the vertices backend that sink is the fallback: it takes text
/// and nothing else, so its counter counts *paragraphs*, and its four other
/// increment sites are unreachable. With no text corpus, or with
/// `DRAW_TEXT=0`, it reads zero for a perfectly healthy frame.
/// `totalFlushCount` is the vertices sink's own answer -- one `drawVertices`
/// per flush -- so summing them makes the guard say "something was drawn" on
/// either backend.
///
/// **And under `TILES=on` neither counter is the answer.** A frame whose
/// viewport is fully covered by live tiles blits and draws nothing at all --
/// that is the entire point of the cache -- so both counters read zero for the
/// healthiest frame the cache can produce. Measured, not reasoned: on
/// 2026-08-25 R4b at 500,000 entities with tiles on threw here, which means
/// **R4b had never once been measured with tiles on**; Plan 3g ran R2's tile
/// phases and never this configuration. [TileCache.blitCount] and
/// [TileCache.liveDrawCount] are the tiled path's evidence that a frame
/// happened, and the guard still bites: they are reset beside the sinks at
/// each call site, so a frame that never ran leaves all four at zero.
///
/// **And those two are still not the whole of "drew".** Plan 3i split the
/// tiled frame into two regimes. A *moving* frame, and the in-between frame at
/// `_restGateSteps == 1`, draw the carry-over composite and nothing else: no
/// tile blit, no live walk, no painter call. On such a frame `blitCount` and
/// `liveDrawCount` both read zero while the frame genuinely put pixels on
/// screen, and [TileCache.carryOverBlitCount] is the only counter that saw it.
/// That is not a rare state -- it is every frame of a zoom gesture, and it is
/// what the frame `panBy(Offset.zero)` forces can settle into after R2's zoom
/// phase. Measured, not reasoned: on 2026-08-29 a functional smoke run at
/// `TILES=on ENTITIES=5000 RUN_R2=true` threw here on a frame that had drawn
/// correctly.
///
/// **[tileCache] is required and nullable rather than optional**, and that is
/// the second half of the same defect. The parameter existed, was documented
/// as the tiled path's answer, and was fed by the integration test's two call
/// sites and by *nothing else*: `runR2Rig` -- the whole of the app-run script
/// -- called `requireRepaint(sink, vertices)` and got a guard that could only
/// ever see two counters that a tiled frame is entitled to leave at zero. An
/// optional parameter can be forgotten at a call site and the omission reads
/// as a deliberate "no cache here". A required one cannot: an untiled caller
/// has to write `tileCache: null` and say so.
///
/// Shared rather than copied, because copying it is how R4a and R4b came to
/// keep the canvas-only form after R2's was fixed.
void requireRepaint(CanvasDrawSink sink, VerticesDrawSink? vertices,
    {required TileCache? tileCache}) {
  // The counters above are read from a frame that has to actually have
  // happened. `panBy(Offset.zero)` forces one only because Transform2 has no
  // operator== for ValueNotifier to dedupe against -- a property these rigs
  // depend on and do not own. If that ever changes, a rig would print a
  // plausible-looking zero rather than fail, and a zero is the one wrong
  // number nobody questions.
  final drew = sink.canvasCallCount +
      (vertices?.totalFlushCount ?? 0) +
      (tileCache?.blitCount ?? 0) +
      (tileCache?.carryOverBlitCount ?? 0) +
      (tileCache?.liveDrawCount ?? 0);
  if (drew == 0) {
    throw StateError('no repaint happened: the forced frame did not draw');
  }
}

/// The frame's backend-independent fields.
///
/// These are what make a backend pair a comparison of two renderers rather
/// than of two drawings: at a fixed corpus size they must match exactly across
/// `BACKEND=canvas` and `BACKEND=vertices`. Printed by every rig, on one line,
/// so no rig can establish control for a corpus size that another rig then
/// reports without it -- which is what happened to R4a and R4b, whose
/// transcripts carried no `screenSpaceLeafCount` at all because only R2
/// printed it.
void printInvariants(DraftPainter painter, CanvasDrawSink sink,
    {TileCache? tileCache}) {
  // **`screenSpaceLeafCount`, `dashSpans` and `collapsed` are `DraftPainter`
  // fields that reset to zero at the top of every `paint()` call**
  // (`draft_painter.dart:334,342`), so they hold whatever the *last* call
  // wrote and nothing from any call before it. Untiled, there is exactly one
  // `paint()` call in the frame this line reports, so that is the frame.
  // **Under `TILES=on` it is not.** `TileCache.paintFrame` calls
  // `painter.paint` once per tile it bakes this frame and, if any tile stayed
  // uncovered, once more for the live fallback -- and whichever of those ran
  // last is all these three fields describe. A frame that bakes most of its
  // tiles and falls back for a small remainder prints a leaf count close to
  // that remainder, not the frame's true total: measured at `TILE_PX=512`
  // printing `screenSpaceLeafCount=1402` where a direct probe of the same
  // frame read 4612 (Task 11's report, section 7 finding 2). `canvasCalls`
  // and the vertices sink's own `triangles`/`drawVerticesCalls` counters
  // (`printBackend`) are unaffected -- both count since `resetCounters()`,
  // not since the last `paint()` call, so they sum correctly across every
  // bake in the frame.
  final tiledCaveat = tileCache == null
      ? ''
      : ' (screenSpaceLeafCount/dashSpans/collapsed: last paint() call only '
          'under TILES=on, not the frame total -- see the tile probe for a '
          'frame figure; canvasCalls is unaffected)';
  print('  screenSpaceLeafCount=${painter.screenSpaceLeafCount} '
      'dashSpans=${painter.dashSpanCount} '
      'collapsed=${painter.collapsedDashCount} '
      'canvasCalls=${sink.canvasCallCount}$tiledCaveat');
  // Task 16: `fillCount` and `skippedFillCount` are the same kind of
  // backend-independent field as the line above -- both must match exactly
  // across `BACKEND=canvas` and `BACKEND=vertices` at a fixed corpus.
  // `skippedFillCount` is a failable criterion of the exit gate: its
  // threshold on the rig corpus is zero.
  print('  fills=${painter.fillCount} '
      'skippedFills=${painter.skippedFillCount}');
  printTileCounters(tileCache);
}

/// The tile cache's counters, or `tiles=off` when the canvas built none.
///
/// **`tiles=off` is printed rather than the line being omitted**, for the
/// reason `printTextCounters` prints `corpus=off`: a transcript with no tile
/// line is indistinguishable from one whose `TILES` define never reached the
/// canvas, and the control arm of this sweep is exactly the run that must be
/// provably untiled.
///
/// `bakes`, `blits`, `carryOverBlits` and `liveDraws` are per-frame figures
/// -- they count since the last `resetCounters`, which every rig calls
/// immediately before the one forced repaint it reports. `evictions` and
/// `invalidations` are cache-lifetime totals by design and are labelled so.
///
/// **`bakeBudgetPx` and `bakeBudgetTiles` are printed together, and neither
/// alone.** Two runs at different tile sizes can carry the same device-pixel
/// budget and bake a different number of tiles, or the same tile-count
/// budget and spend a different number of device pixels -- the whole reason
/// [TileCache.bakeBudgetDevicePixels] stopped being a tile count. A
/// transcript that named only one of the two would let a reader compare two
/// runs that used different budgets without any line telling them so, which
/// is exactly the failure a rig configured by `dart-define` and mutated at
/// startup (`kTileBake` in `main.dart`) is one silent default change away
/// from. `bakeBudgetTiles` reads [TileCache.budgetedTilesPerFrame], the same
/// number [TileCache.paintFrame] itself bakes against -- not a second
/// computation of it here that could drift from the first.
void printTileCounters(TileCache? cache) {
  if (cache == null) {
    print('  tiles=off');
    return;
  }
  print('  tiles=on tilePx=${cache.tileDevicePixels} '
      'bakeBudgetPx=${cache.bakeBudgetDevicePixels} '
      'bakeBudgetTiles=${cache.budgetedTilesPerFrame} '
      'liveTiles=${cache.liveTileCount} '
      'generation=${cache.generation} '
      'carryOver=${cache.hasCarryOver}');
  print('  bakes=${cache.bakeCount} '
      'blits=${cache.blitCount} '
      'carryOverBlits=${cache.carryOverBlitCount} '
      'liveDraws=${cache.liveDrawCount} '
      'blitDests=${cache.blitDestinationCount} '
      'evictions=${cache.evictionCount}(life) '
      'invalidations=${cache.invalidationCount}(life) '
      'tileBytes=${cache.liveBytes}');
}

/// The backend actually used, and the vertices counters when it was that one.
///
/// The resolved value and not the define: a run that asked for `vertices` and
/// silently got `canvas` would otherwise report canvas numbers under a
/// vertices heading, which is the shape of the mistake Plan 3c's `TEXT` define
/// made.
void printBackend(RenderBackend backend, VerticesDrawSink? vertices) {
  if (vertices == null) {
    print('  backend=${backend.name}');
    return;
  }
  print('  backend=${backend.name} '
      'triangles=${vertices.frameTriangleCount} '
      'drawVerticesCalls=${vertices.totalFlushCount} '
      '${capacity(vertices)}');
}

/// The vertex buffer's high-water mark, in vertices and in bytes.
///
/// **Owed to Plan 3h and never taken by Plan 3g.** Baking per tile flushes and
/// rewinds the buffer between tiles, so a tiled run's mark should fall to a
/// single tile's geometry -- and if it does, a tile budget *replaces* that
/// memory rather than adding to it, which is the difference between 3h
/// starting from 96 MiB and starting from 96 + 96.
///
/// **Read it as a run-to-run comparison and never as a within-run one.**
/// `VerticesDrawSink` never gives capacity back (`vertices_draw_sink.dart:163`
/// says so and `paint_allocation_test.dart` depends on it), so this number is
/// monotone for the life of the sink: one live walk anywhere -- a warm-up
/// frame, or the fallback drawing an uncovered strip -- pins it at the
/// full-frame figure for every later phase. It is printed at several points
/// below so that *when* it was reached is visible, but the answer to the
/// question above is `TILES=off` against `TILES=on` in two separate runs.
///
/// Twelve bytes a vertex: `_positions` is two `Float32`s and `_colors` one
/// `Int32`. The 96.00 MiB `STATUS.md` records is 8,388,608 vertices exactly.
String capacity(VerticesDrawSink? vertices) {
  if (vertices == null) return 'capacityVertices=n/a';
  final v = vertices.debugCapacityVertices;
  return 'capacityVertices=$v '
      'capacityMiB=${(v * 12 / (1024 * 1024)).toStringAsFixed(2)}';
}

/// The text counters, printed by every rig so the on/off delta is one define
/// apart on one corpus.
///
/// `newLayouts` is the row the exit gate is about: in a steady state — the
/// same strings visible frame after frame — a warm paragraph cache must lay
/// nothing out, and a non-zero reading here means the working set does not fit
/// under `kParagraphCacheLimit`. The counters are read after the same forced
/// repaint the dash counters come from, so all of them describe one frame.
///
/// `layouts` and `evictions` are running totals since the sink was built; the
/// per-frame figures are the deltas the caller passes in. A running total
/// printed beside two per-frame figures is the wrong comparison this file
/// already refuses to publish once.
void printTextCounters(DraftPainter painter, CanvasDrawSink sink,
    {required bool textCorpus,
    required bool drawText,
    required int layoutsBefore,
    required int paragraphEvictionsBefore,
    required int metricsEvictionsBefore}) {
  final m = sink.measurer;
  // `minTextCapPixels` is printed here, not just implied by which binary was
  // launched with which define: a device run comparing `LOD=true` against
  // `LOD=false` is otherwise indistinguishable from one that failed to wire
  // the define through at all whenever the camera's text happens to sit
  // above both thresholds — this line is the only place in either transcript
  // that shows the two runs actually differed in what they were given.
  print('  text: corpus=${textCorpus ? "on" : "off"} '
      'draw=${drawText ? "on" : "off"} '
      'minTextCapPixels=${painter.minTextCapPixels} '
      'textOps=${painter.textOpCount} '
      'skippedText=${painter.skippedTextCount} '
      'culledText=${painter.culledTextCount}');
  // Two eviction numbers, not one. A paragraph eviction released native glyph
  // memory and guarantees a future re-layout; a metrics eviction dropped four
  // doubles. Ruling 54: a blended number hides which half moved.
  print('  paragraphs: newLayouts=${m.layoutCount - layoutsBefore} '
      'newParagraphEvictions=${m.paragraphEvictionCount - paragraphEvictionsBefore} '
      'newMetricsEvictions=${m.metricsEvictionCount - metricsEvictionsBefore} '
      'liveParagraphs=${m.liveParagraphCount} '
      'liveMetrics=${m.liveMetricsCount}');
}

/// The screen point R2's own zoom step zooms about: the **centre of the
/// viewport it is given**.
///
/// This used to be a hardcoded `Offset(800, 600)`, written when the harness
/// was believed to run at the design spec's pinned 1600x1200 reference
/// viewport, of which it is the centre. The harness never created that
/// window (Ruling 20), so the constant was the centre of a viewport that
/// never existed: at 1400x900 it sits off-centre and low-right, and at the
/// nib default of 800x600 -- the size every figure this harness has ever
/// produced was actually taken at -- it is the bottom-right *corner*, where a
/// zoom drags the whole document across the screen instead of scaling about
/// what the operator is looking at.
///
/// A centre focus is deliberate here and is **not** the same choice as
/// [zoomFocusFor]'s: this is R2's general-purpose zoom phase, whose 240-frame
/// script six plans have published rows from, not the tile phase whose spec
/// pins an off-centre focus so the rebase residual is exercised.
Offset r2ZoomAnchorFor(Size viewport) =>
    Offset(viewport.width / 2, viewport.height / 2);

/// R2's zoom step: 120 frames alternating a 1.03 zoom in and a 0.97 zoom out
/// about [r2ZoomAnchorFor], one camera change per frame.
///
/// Lifted out of [runR2Rig] so the anchor can be tested at all. [runR2Rig]
/// opens with [refuseDebugMode] and `flutter test` is a debug build, so no
/// unit test can reach the loop while it lives inside the rig -- and an
/// anchor that is wrong by 500 logical pixels changes every number the zoom
/// phase reports without changing the shape of the transcript.
Future<void> runR2ZoomStep({
  required CameraController camera,
  required Size viewport,
  required Future<void> Function() pumpFrame,
}) async {
  final anchor = r2ZoomAnchorFor(viewport);
  for (var i = 0; i < 120; i++) {
    camera.zoomAt(anchor, i.isEven ? 1.03 : 0.97);
    await pumpFrame();
  }
}

/// The one line every `RUN_R2` run prints about the window it is running in,
/// **and the mismatch warning that belongs beside it**.
///
/// The two are emitted together, by one function, on purpose. The warning
/// used to live at the `tile zoom` call site inside `main.dart`'s
/// `ZOOM_ARMS > 0` branch, which is off by default: a plain `RUN_R2` run at
/// the wrong window printed its size and said nothing else, and the operator
/// had to know what size to expect in order to notice. R2's own pan and zoom
/// phases are just as viewport-dependent as the tile phase -- the anchor
/// [r2ZoomAnchorFor] derives is one of the things that moves -- so the check
/// belongs on every run, not on the arms.
///
/// Keeping the warning welded to the window line is what makes that hard to
/// undo: a caller cannot keep the line the transcript is read by and quietly
/// drop the warning.
void reportR2Window(Size real, Size pinned,
    {required double devicePixelRatio}) {
  print('R2 app-run: window=${real.width.toStringAsFixed(0)}x'
      '${real.height.toStringAsFixed(0)} dpr=$devicePixelRatio');
  warnIfZoomViewportMismatch(real, pinned);
}

/// R2: 120 frames of pan, then 120 of zoom across three scale bands, then one
/// forced repaint whose counters are the ones printed.
///
/// [pumpFrame] renders exactly one frame and completes after it —
/// `() => tester.pump(const Duration(milliseconds: 16))` in a widget test,
/// `() => SchedulerBinding.instance.endOfFrame` in a running app. [settle]
/// is the equivalent gap between `tester.pumpAndSettle()` (pump until
/// nothing is scheduled, or a timeout) and a running app's own approximation
/// of the same idea — there is no synthetic clock outside a test, so this is
/// where the two platforms' behaviour genuinely cannot be identical, not
/// just differently spelled.
///
/// The camera must already be fitted to the working set before this is
/// called — this function does not do that, so the fit's own frame is never
/// counted among the 240+1 this rig reports, on either platform.
Future<void> runR2Rig({
  required int entities,
  required double lineweightScale,
  required bool textCorpus,
  required bool drawText,
  required CameraController camera,
  required DraftPainter painter,
  required CanvasDrawSink sink,
  required VerticesDrawSink? vertices,
  required RenderBackend resolvedBackend,
  required TileCache? tileCache,
  required Future<void> Function() pumpFrame,
  required Future<void> Function() settle,
  required double panStep,
  required Size viewport,
}) async {
  refuseDebugMode();
  final timings = <FrameTiming>[];
  // The bucket the callback appends to, swapped between phases rather than
  // re-registered: `addTimingsCallback` reports a frame *after* it rasterised,
  // so removing and re-adding the callback around a phase boundary drops the
  // tail of one phase instead of moving it. A swapped bucket keeps every frame
  // and lands at most a frame or two of one phase in the next -- which is why
  // each phase below pumps two throwaway frames at its boundary.
  var bucket = timings;
  void collect(List<FrameTiming> t) => bucket.addAll(t);
  SchedulerBinding.instance.addTimingsCallback(collect);
  try {
    for (var i = 0; i < 120; i++) {
      camera.panBy(const Offset(-7, -3));
      await pumpFrame();
    }
    await runR2ZoomStep(
        camera: camera, viewport: viewport, pumpFrame: pumpFrame);
    await settle();
    // All three counters now mean the same thing: this frame. dashSpanCount
    // and collapsedDashCount reset themselves every paint; canvasCallCount
    // does not, because the sink outlives the frame. But settling leaves
    // nothing dirty, so a bare pumped frame would not repaint at all —
    // RenderCustomPaint only repaints when its `repaint` Listenable fires,
    // and nothing has changed since the last real frame. panBy(Offset.zero)
    // is a numeric no-op but still assigns a fresh ViewportTransform
    // (Transform2 and ViewportTransform both deliberately have no
    // operator==, so ValueNotifier's reference check always sees a
    // "change"), which fires the listener and forces the one real repaint
    // that makes resetCounters() meaningful. A running total beside two
    // per-frame figures is a wrong comparison waiting to be published.
    sink.resetCounters();
    vertices?.resetCounters();
    // **The tile counters reset here too, and without this line the guard
    // below cannot fail at all.** `bakes`, `blits`, `carryOverBlits` and
    // `liveDraws` count since the last `resetCounters` -- which, in this
    // script, had never been called before the forced frame: the 240 frames of
    // pan and zoom above had already driven every one of them into the
    // thousands, so `requireRepaint` would read "something drew" from a frame
    // that never ran, and `printTileCounters` would publish four
    // cache-lifetime totals under a heading that says per-frame. The
    // integration test's own call sites reset it here for exactly this reason.
    tileCache?.resetCounters();
    final layoutsBefore = sink.measurer.layoutCount;
    final paragraphEvictionsBefore = sink.measurer.paragraphEvictionCount;
    final metricsEvictionsBefore = sink.measurer.metricsEvictionCount;
    camera.panBy(Offset.zero);
    await pumpFrame();
    report('R2 ($entities)', timings);
    print('  lineweightScale=$lineweightScale');
    requireRepaint(sink, vertices, tileCache: tileCache);
    printInvariants(painter, sink, tileCache: tileCache);
    printBackend(resolvedBackend, vertices);
    printTextCounters(painter, sink,
        textCorpus: textCorpus,
        drawText: drawText,
        layoutsBefore: layoutsBefore,
        paragraphEvictionsBefore: paragraphEvictionsBefore,
        metricsEvictionsBefore: metricsEvictionsBefore);
    if (tileCache != null) {
      await runTilePhases(
        cache: tileCache,
        camera: camera,
        painter: painter,
        sink: sink,
        vertices: vertices,
        pumpFrame: pumpFrame,
        settle: settle,
        setBucket: (b) => bucket = b,
        panStep: panStep,
      );
    }
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(collect);
  }
}

/// The three columns the tile-size sweep is for, measured in three regimes.
///
/// **Blit cost and bake cost move in opposite directions as the tile grows,
/// and that is the whole reason this reports more than one number.** A smaller
/// tile costs less memory and bakes a smaller area, but the slack a bake pads
/// its cull by is a *fixed* number of logical pixels, so the fraction of a
/// tile's bake that is overdraw grows without bound as the tile shrinks. A
/// sweep that read the blit column alone would recommend the smallest tile
/// available and lose the pan criterion, whose cost is the strip a pan frame
/// bakes.
///
/// The regimes:
///
/// * **hold** -- the camera does not move and the generation is full, so every
///   visible tile is a hit. Nothing bakes; the frame is blits and nothing
///   else. This is the blit column, and it is a *whole-frame* number:
///   `totalSpan`, not `rasterDuration`. The 2026-08-23 spike rasterised
///   217,758 triangles into a texture on every frame while `rasterDuration`
///   read 0.87 ms, because `Picture.toImageSync` returns before the GPU work
///   it schedules and that work lands outside the raster window entirely.
/// * **pan** -- the same scripted pan R2 runs, with the generation already
///   warm, so the only tiles baked are the strip entering the viewport. The
///   cache's own `bakeCount` over the phase gives bakes-per-frame exactly, so
///   `(pan - hold) / bakesPerFrame` is a bake cost per tile measured through
///   `totalSpan` and therefore inclusive of the GPU work `toImageSync` hides.
/// * **probe** -- one direct walk of the live viewport and one of every tile
///   covering it, reproducing [TileCache]'s own bake geometry (the same
///   [kTileSlack] pad, the same hard clip, the same frame-global rebase
///   origin, the same `toImageSync`). This is the overdraw column: the ratio
///   of leaves the tiles walk to the leaves one live frame walks, *measured*
///   rather than predicted from the area ratio -- the two differ whenever the
///   corpus is not uniformly dense, and the area ratio is printed beside it so
///   a reader can see by how much.
///
/// The Dart stopwatch around the probe's bake measures the walk and the
/// recording, **not** the rasterisation: `toImageSync` schedules that work and
/// returns. It is reported as `walkMs` for exactly that reason, and the pan
/// regime above is what carries the rasterisation.
Future<void> runTilePhases({
  required TileCache cache,
  required CameraController camera,
  required DraftPainter painter,
  required CanvasDrawSink sink,
  required VerticesDrawSink? vertices,
  required Future<void> Function() pumpFrame,
  required Future<void> Function() settle,
  required void Function(List<FrameTiming>) setBucket,
  required double panStep,
}) async {
  // Fill the generation the zoom phase left stale. Bounded, and the bound is
  // reported: a run that hit it never reached a warm cache and its hold
  // regime would be measuring a refill.
  const maxWarmFrames = 400;
  var warmFrames = 0;
  var lastBakes = -1;
  while (warmFrames < maxWarmFrames && cache.bakeCount != lastBakes) {
    lastBakes = cache.bakeCount;
    camera.panBy(Offset.zero);
    await pumpFrame();
    warmFrames++;
  }
  await settle();
  print('  tile warm: frames=$warmFrames '
      'liveTiles=${cache.liveTileCount} '
      'tileBytes=${cache.liveBytes} '
      'evictions=${cache.evictionCount}(life) '
      '${capacity(vertices)}');

  Future<void> phase(String name, int frames, Offset step) async {
    // Two throwaway frames, then the bucket swap: a `FrameTiming` is reported
    // after its frame rasterised, so the boundary needs slack the phase does
    // not count.
    for (var i = 0; i < 2; i++) {
      camera.panBy(Offset.zero);
      await pumpFrame();
    }
    final phaseTimings = <FrameTiming>[];
    setBucket(phaseTimings);
    cache.resetCounters();
    final evictionsBefore = cache.evictionCount;
    // A pan bakes in bursts -- a whole column of tiles enters at once -- so
    // the shape of the bake distribution decides whether the mean above is a
    // per-tile cost or an average over two different frames. Reported, not
    // assumed.
    var bakeFrames = 0;
    var maxBakesInAFrame = 0;
    var lastBakeCount = 0;
    for (var i = 0; i < frames; i++) {
      camera.panBy(step);
      await pumpFrame();
      final delta = cache.bakeCount - lastBakeCount;
      lastBakeCount = cache.bakeCount;
      if (delta > 0) bakeFrames++;
      if (delta > maxBakesInAFrame) maxBakesInAFrame = delta;
    }
    report('  $name', phaseTimings);
    print('    bakeFrames=$bakeFrames/$frames '
        'maxBakesInAFrame=$maxBakesInAFrame');
    print('    bakes=${cache.bakeCount} '
        'perFrame=${(cache.bakeCount / frames).toStringAsFixed(3)} '
        'blits=${cache.blitCount} '
        'carryOverBlits=${cache.carryOverBlitCount} '
        'liveDraws=${cache.liveDrawCount} '
        'newEvictions=${cache.evictionCount - evictionsBefore} '
        'liveTiles=${cache.liveTileCount} '
        'tileBytes=${cache.liveBytes}');
    // Monotone, so this reads "was more needed during this phase", never "is
    // this what the phase needs". See [capacity].
    print('    ${capacity(vertices)}');
  }

  await phase('tile hold', kTileHoldFrames, Offset.zero);
  final step = tilePanStep(panStep);
  print('  tile pan step: dx=${step.dx.toStringAsFixed(4)} '
      'dy=${step.dy.toStringAsFixed(4)} '
      'magnitude=${step.distance.toStringAsFixed(4)}');
  await phase('tile pan', kTilePanFrames, step);
  _probeBake(cache, camera, painter, sink, vertices);
}

/// Frames the `tile hold` regime holds the camera still for, in [runTilePhases]
/// and in one criterion-8 arm ([runTilePanArm]) alike.
///
/// The two must agree: criterion 8's control is only a control if it is the
/// same phase Plan 3h's `tile hold` figures were read off.
const int kTileHoldFrames = 60;

/// Frames the `tile pan` regime pans for, in [runTilePhases] and in one
/// criterion-8 arm ([runTilePanArm]) alike.
///
/// Criterion 8 is a ratio of `tile pan` p95 between two arms, and criterion 9
/// reads the same statistic out of [runTilePhases]' block against Plan 3h's
/// recorded figures. A pan arm of a different length would not be the same
/// measurement under the same name.
const int kTilePanFrames = 120;

/// The camera step one `tile pan` frame takes: `Offset(-7, -3)` unless
/// `PAN_STEP` asks for a different magnitude along the same direction.
///
/// **Extracted so the two callers cannot drift.** [runTilePhases] pans R2's
/// own block with this, and [runTilePanArm] pans criterion 8's arms with it;
/// two copies of the historical constant would eventually make the arm and the
/// block two different measurements printed under one name. See `kPanStep` in
/// `main.dart` for why a magnitude and not a pair, and why `NaN` is the
/// sentinel for unset.
Offset tilePanStep(double panStep) {
  const historical = Offset(-7, -3);
  final magnitude = historical.distance;
  return panStep.isNaN
      ? historical
      : Offset(historical.dx * panStep / magnitude,
          historical.dy * panStep / magnitude);
}

/// One live walk and one walk per covering tile, at the current camera.
///
/// Reproduces [TileCache]'s bake geometry rather than approximating it: the
/// grid is a real [TileGrid] anchored at [quantiseCamera]'s output, the bake
/// camera comes from [TileGrid.bakeCameraFor], the pad is [kTileSlack], the
/// clip is the same hard unantialiased square, and the rebase origin is
/// derived once for the frame the way `paintFrame` derives it. A probe that
/// invented its own lattice would measure a different overdraw than the one
/// the cache pays.
void _probeBake(TileCache cache, CameraController camera, DraftPainter painter,
    CanvasDrawSink sink, VerticesDrawSink? vertices) {
  final view = PlatformDispatcher.instance.views.first;
  final dpr = view.devicePixelRatio;
  final viewport = view.physicalSize / dpr;
  final quantised = quantiseCamera(camera.value, dpr);
  final grid = TileGrid(
      anchor: quantised,
      devicePixelRatio: dpr,
      tileDevicePixels: cache.tileDevicePixels);
  final origin = rebaseOriginFor(quantised.visibleWorld(viewport));

  int walk(ui.Canvas canvas, ViewportTransform camera, Size size) {
    painter.debugRebaseOrigin = origin;
    try {
      sink.canvas = canvas;
      if (vertices == null) {
        painter.paint(sink, camera, size);
      } else {
        vertices.canvas = canvas;
        painter.paint(vertices, camera, size);
        vertices.flush();
      }
    } finally {
      painter.debugRebaseOrigin = null;
    }
    return painter.screenSpaceLeafCount;
  }

  // The denominator: one live full-viewport frame, drawn the way the untiled
  // path draws it.
  final liveRecorder = ui.PictureRecorder();
  final liveWatch = Stopwatch()..start();
  final liveLeaves = walk(ui.Canvas(liveRecorder), quantised, viewport);
  liveWatch.stop();
  liveRecorder.endRecording().dispose();

  final side = cache.tileDevicePixels / dpr;
  const pad = kTileSlack;
  var tiles = 0;
  var tileLeaves = 0;
  final bakeWatch = Stopwatch();
  for (final key in grid.visibleKeys(quantised, viewport)) {
    tiles++;
    bakeWatch.start();
    final recorder = ui.PictureRecorder();
    final into = ui.Canvas(recorder);
    into.scale(dpr);
    into.clipRect(Rect.fromLTWH(0, 0, side, side), doAntiAlias: false);
    into.translate(-pad, -pad);
    final bake = grid.bakeCameraFor(key).worldToScreenMatrix;
    tileLeaves += walk(
        into,
        ViewportTransform(
            worldToScreenMatrix: Transform2(
                bake.a, bake.b, bake.c, bake.d, bake.e + pad, bake.f + pad)),
        Size(side + 2 * pad, side + 2 * pad));
    final picture = recorder.endRecording();
    final image =
        picture.toImageSync(cache.tileDevicePixels, cache.tileDevicePixels);
    picture.dispose();
    image.dispose();
    bakeWatch.stop();
  }

  // The area ratio the plan predicted, recomputed from what the tree does
  // today rather than quoted: `side` is the tile in *logical* pixels and the
  // pad is logical too, so this is the ratio a uniformly dense corpus would
  // produce. The measured leaf ratio beside it is what this corpus produces.
  final areaFactor = ((side + 2 * pad) * (side + 2 * pad)) / (side * side);
  final walkMs = bakeWatch.elapsedMicroseconds / 1000.0;
  print('  tile probe: tilePx=${cache.tileDevicePixels} dpr=$dpr '
      'viewport=${viewport.width.toStringAsFixed(0)}x'
      '${viewport.height.toStringAsFixed(0)} '
      'tileLogical=${side.toStringAsFixed(1)} pad=$pad');
  // G7: `overdraw` cannot see a change to the shipped clip in [TileCache._bake]
  // — this probe reimplements that geometry instead of calling it (see the
  // class doc above), so the column reads bit-identical under mutant M7,
  // which moved real triangle counts by 61%. Read it as a geometry sanity
  // check, not a mutation-killing gate.
  print('    tiles=$tiles '
      'liveLeaves=$liveLeaves '
      'tileLeaves=$tileLeaves '
      'overdraw=${(tileLeaves / liveLeaves).toStringAsFixed(3)} '
      'areaFactor=${areaFactor.toStringAsFixed(3)}');
  print(
      '    liveWalkMs=${(liveWatch.elapsedMicroseconds / 1000.0).toStringAsFixed(2)} '
      'tileWalkMsTotal=${walkMs.toStringAsFixed(2)} '
      'walkMsPerTile=${(walkMs / tiles).toStringAsFixed(3)} '
      'visibleSetBytes=${tiles * cache.tileDevicePixels * cache.tileDevicePixels * 4}');
}

/// Steps in each direction of the `tile zoom` phase's script. See Plan 3i's
/// Task 11 for why 40 and not fewer: `kZoomFactor ^ kZoomSteps` = 3.26x,
/// which cannot sit inside one power-of-two rebase step
/// ([rebaseOriginFor] in `camera_controller.dart`) -- a script that stays
/// inside one step never re-quantises and the anti-degenerate rule (clause
/// 3) is unmet.
///
/// Pinned by the spec, §5. Not the implementer's to adjust -- see the task
/// brief and the design spec before changing either constant.
const int kZoomSteps = 40;

/// Per-step zoom factor, matching what one trackpad update delivers. Pinned
/// alongside [kZoomSteps].
const double kZoomFactor = 1.03;

/// The `tile zoom` phase's focal point: deliberately off-centre, at 30%/70%
/// of the viewport.
///
/// A focal point at the viewport's centre is the degenerate case -- the
/// anchor would coincide with [rebaseOriginFor]'s own centre and half the
/// residual arithmetic the zoom exercises would never run (anti-degenerate
/// rule, clause 5).
///
/// [viewport] is the size the script's own numbers are priced against --
/// the pinned **1600x1200 logical at `devicePixelRatio` 2** reference
/// viewport (§5), not necessarily whatever the real window happens to be.
/// See [runTileZoomPhase]'s doc comment for what that means for a caller.
Offset zoomFocusFor(Size viewport) =>
    Offset(viewport.width * 0.30, viewport.height * 0.70);

/// Warns, loudly, when the window a measurement run is about to happen in is
/// not [pinned] -- the size every number the run produces is priced against.
///
/// **A warning, not a throw.** Every phase here accepts any finite viewport
/// and still produces a report -- refusing to run would trade a labelled
/// number for no number at all, which is worse for an operator mid-session
/// than a number they have to read the label on.
///
/// **Called from [reportR2Window], on every run.** It used to be called only
/// from `main.dart`'s `ZOOM_ARMS > 0` branch, which is off by default, so the
/// commonest run there is -- a plain `RUN_R2` -- printed its window size and
/// then said nothing about it being the wrong one. See [reportR2Window] for
/// why the warning and the window line are now emitted together.
void warnIfZoomViewportMismatch(Size real, Size pinned) {
  if (real == pinned) return;
  print('  !!! WARNING: measurement run at window='
      '${real.width.toStringAsFixed(0)}x${real.height.toStringAsFixed(0)}, '
      'not the pinned reference ${pinned.width.toStringAsFixed(0)}x'
      '${pinned.height.toStringAsFixed(0)} -- the numbers from this run are '
      'measured at the WRONG VIEWPORT and are not comparable to any run at '
      'the pinned size !!!');
}

/// Every `FrameTiming` reported while this log is armed, in delivery order,
/// attributed to the frames a phase pumped **by ordinal**.
///
/// **Why an ordinal and not an arrival window.** `addTimingsCallback` reports
/// a frame only *after* it has rasterised, and a `pumpFrame` completes at
/// `SchedulerBinding.endOfFrame` -- the frame's post-frame phase, *before* its
/// scene rasterises. So the timings that arrive while frame *i* is being
/// pumped are frame *i-1*'s, or none at all: reading "whatever arrived during
/// this frame" names the wrong frame systematically rather than occasionally,
/// and re-registering a callback around a phase boundary drops the tail of one
/// phase instead of moving it. That is the hazard [runR2Rig] states at its own
/// registration, and the reason this type exists.
///
/// **The rule.** One registration spans every frame the phase pumps; delivery
/// order is pump order; frame *i*'s timing is the *i*-th one delivered. Frames
/// pumped before [arm] are therefore poison -- their timings arrive *after*
/// registration and would take the ordinals of frames that came later -- so a
/// phase arms this log before its own warm-up frames and excludes the warm-up
/// ordinals from its sample, rather than arming after them.
///
/// **[arm] is not enough on its own, and a phase must call
/// [establishBaseline] straight after it.** Arming does not empty the engine's
/// queue: a caller's own pump just before the phase, and whatever the engine
/// had not yet batched, both report *after* registration and take ordinals
/// that belong to frames pumped later. [establishBaseline] is what drains
/// them; [sawBacklog] is the invariant that says it failed to.
///
/// The last frames' timings are still in flight when the last pump returns,
/// which is what [drain] is for.
class FrameTimingLog {
  final List<FrameTiming> _reported = <FrameTiming>[];
  int _pumped = 0;
  bool _armed = false;

  /// The `frameNumber` of the last frame known to belong to the *pre-baseline*
  /// stream, or null before [establishBaseline] has run. Every timing at or
  /// below it is dropped rather than appended: a straggler from before the
  /// baseline must not take an ordinal that belongs to a frame pumped after
  /// it. See [establishBaseline].
  int? _baselineFrameNumber;
  bool _baselineEstablished = false;

  /// Latched when [reportedFrames] exceeds [pumpedFrames] *after* the
  /// baseline. See [sawBacklog].
  bool _sawBacklog = false;
  int _worstExcess = 0;

  void _collect(List<FrameTiming> timings) {
    final baseline = _baselineFrameNumber;
    for (final timing in timings) {
      if (baseline != null && timing.frameNumber <= baseline) continue;
      _reported.add(timing);
    }
    // The invariant: a frame reports only after it has rasterised, and it
    // cannot rasterise before it was pumped, so at most one timing per pumped
    // frame can ever have arrived. More than that means timings this log did
    // not pump are in the stream -- which is exactly a backlog, and exactly
    // the thing that shifts every ordinal by an amount nothing else measures.
    // Before the baseline a backlog is *expected* (it is what the baseline
    // drains), so this only latches once the baseline is in place.
    if (_baselineEstablished && _reported.length > _pumped) {
      _sawBacklog = true;
      final excess = _reported.length - _pumped;
      if (excess > _worstExcess) _worstExcess = excess;
    }
  }

  /// Registers the one callback that spans the whole phase.
  void arm() {
    if (_armed) {
      throw StateError('FrameTimingLog.arm() twice: one registration spans '
          'the phase, and a second would double every timing');
    }
    SchedulerBinding.instance.addTimingsCallback(_collect);
    _armed = true;
  }

  /// Unregisters the callback. Safe to call when never armed, so a caller can
  /// put it in a `finally`.
  void disarm() {
    if (!_armed) return;
    SchedulerBinding.instance.removeTimingsCallback(_collect);
    _armed = false;
  }

  /// How many frames have been pumped through [pump] and [drain]. Also the
  /// ordinal the next pumped frame will take.
  int get pumpedFrames => _pumped;

  /// How many timings have been reported so far, across every pumped frame.
  int get reportedFrames => _reported.length;

  /// Whether [establishBaseline] has run and left this log with a known-empty
  /// backlog.
  bool get baselineEstablished => _baselineEstablished;

  /// Whether [reportedFrames] has ever exceeded [pumpedFrames] since the
  /// baseline was established -- the invariant that says every ordinal in this
  /// log is off by an unknown amount.
  ///
  /// Reading a figure out of such a log throws; this getter is how a caller
  /// (or a test) asks without throwing.
  bool get sawBacklog => _sawBacklog;

  /// Pumps one frame and gives it the next ordinal.
  Future<void> pump(Future<void> Function() pumpFrame) async {
    _pumped++;
    await pumpFrame();
  }

  /// Drains whatever the engine still owes from before [arm], then rebases
  /// this log so ordinal 0 is genuinely the next frame pumped.
  ///
  /// **Why any of this is needed.** Ordinals index [_reported] directly, so
  /// ordinal *k* is pumped frame *k* only if `_reported[0]` is the first frame
  /// pumped after [arm]. Two things break that on a device and neither is
  /// rare:
  ///
  /// 1. *A guaranteed shift of one.* A caller that pumps a frame just before
  ///    the phase -- `main.dart`'s `runArm` resets the camera and pumps --
  ///    completes that pump at `SchedulerBinding.endOfFrame`, **before** the
  ///    frame rasterises. Its `FrameTiming` therefore arrives *after* [arm]
  ///    and lands at `_reported[0]`, pushing every ordinal along by one. The
  ///    published "covering frame" then names the in-between composite blit
  ///    that drew nothing, and the gesture window is padded at the head with
  ///    the cheapest frame in the phase and truncated at the tail.
  /// 2. *Engine batching.* `FrameTiming`s are delivered in batches
  ///    (approximately once a second in release, once every ~100 ms in debug
  ///    and profile), and `SchedulerBinding.initInstances` registers its own
  ///    timings callback in `!kReleaseMode` -- so reporting neither starts nor
  ///    stops at [arm]. Every frame still unflushed at that moment shifts the
  ///    stream further: 0-6 of them at a 100 ms batch and 60 Hz.
  ///
  /// Nothing downstream can see either one. `framesMissing` looks for holes
  /// *inside* a window, and a shifted-but-full window has none.
  ///
  /// **What this does.** Rounds of "pump [framesPerRound] frames back to back,
  /// then stop pumping and wait a [batchWindow]" until the reported stream
  /// stops growing while nothing is being pumped -- which is what "the engine
  /// owes this log nothing" looks like from here -- and then drops [_reported]
  /// and resets [_pumped] **in the same synchronous step**, so the two cannot
  /// disagree. The last frame number seen becomes [_baselineFrameNumber], so a
  /// straggler that arrives after the reset is dropped instead of stealing
  /// ordinal 0.
  ///
  /// **Pumping is continuous inside a round** so that no frame the app
  /// schedules for itself (`DraftCanvasState`'s settle notifier does) can
  /// slip in unpumped; the wait that follows is what lets the batch flush.
  ///
  /// **[waitForBatch] is injectable so this is testable at all.** The default
  /// is a real `Future.delayed`; a test drives a fake stream and hands in a
  /// callback that flushes it instead of sleeping.
  ///
  /// Throws when the stream never goes quiet inside [maxRounds]. That is a
  /// throw and not a warning because every figure the phase would go on to
  /// publish is an ordinal read out of a stream whose offset is unknown: there
  /// is no number to salvage, only a wrong one to print.
  Future<void> establishBaseline(
    Future<void> Function() pumpFrame, {
    int framesPerRound = kBaselineFramesPerRound,
    Duration batchWindow = kTimingBatchWindow,
    int maxRounds = kBaselineMaxRounds,
    Future<void> Function(Duration)? waitForBatch,
  }) async {
    if (!_armed) {
      throw StateError('FrameTimingLog.establishBaseline() before arm(): '
          'there is no stream to drain until the callback is registered');
    }
    if (_baselineEstablished) {
      throw StateError('FrameTimingLog.establishBaseline() twice: the second '
          'call would throw away a phase that is already being measured');
    }
    final wait = waitForBatch ?? (Duration d) => Future<void>.delayed(d);
    for (var round = 0; round < maxRounds; round++) {
      for (var i = 0; i < framesPerRound; i++) {
        await pump(pumpFrame);
      }
      await wait(batchWindow);
      final settledCount = _reported.length;
      // A second window with nothing pumped into it. If the stream grew, the
      // engine still owed timings a moment ago and may still owe more.
      await wait(batchWindow);
      if (_reported.length != settledCount || _reported.isEmpty) continue;
      // Quiet, and non-empty: everything the engine owed has landed. Rebase.
      //
      // The maximum, not `.last` -- this rig's governing decision (see fix
      // wave C) is to build attribution only on properties it can observe,
      // and delivery order is not one of them: nothing here verifies that a
      // drained batch reports in `frameNumber` order. A `.last` that assumed
      // it would be the same unverified-assumption class one line deep --
      // silently rebasing below the true maximum and admitting a
      // pre-baseline straggler above it, undetected because the
      // `reportedFrames <= pumpedFrames` latch only trips once the count
      // actually runs ahead.
      _baselineFrameNumber = _reported.fold<int>(0,
          (max, timing) => timing.frameNumber > max ? timing.frameNumber : max);
      _reported.clear();
      _pumped = 0;
      _sawBacklog = false;
      _worstExcess = 0;
      _baselineEstablished = true;
      return;
    }
    throw StateError('FrameTimingLog.establishBaseline(): the timing stream '
        'never went quiet in $maxRounds rounds of $framesPerRound frames and '
        '$batchWindow -- $reportedFrames timing(s) across $pumpedFrames '
        'pumped frames. Every ordinal below would be offset by an unknown '
        'amount, so there is no figure to publish.');
  }

  /// Throws when this log has seen a backlog since its baseline.
  void _refuseShiftedStream() {
    if (!_sawBacklog) return;
    throw StateError('FrameTimingLog: the reported stream ran ahead of the '
        'pumped one by up to $_worstExcess frame(s) after the baseline. '
        'reportedFrames <= pumpedFrames is what makes ordinal k the k-th '
        'frame pumped; with a backlog every figure read out of this log names '
        'the wrong frame, and by an amount nothing here can recover.');
  }

  /// Pumps bare frames until the frames with ordinals below [upTo] have all
  /// reported, or until [maxExtraFrames] have been pumped without getting
  /// there.
  ///
  /// **This is the "one extra frame at the end" the attribution needs.** The
  /// last frame of a phase cannot have reported by the time its own pump
  /// returns; without a drain its timing is not late, it is *absent*, and the
  /// phase's last sample would silently read as missing. The drained frames
  /// take ordinals of their own, so a later phase sharing this log stays
  /// aligned. It is a bound and not a wait loop: on a device that stops
  /// reporting altogether this returns rather than hanging, and the shortfall
  /// shows up as a missing sample the report prints.
  ///
  /// Returns how many extra frames it pumped.
  Future<int> drain(
    Future<void> Function() pumpFrame, {
    required int upTo,
    int maxExtraFrames = 4,
  }) async {
    var extra = 0;
    while (_reported.length < upTo && extra < maxExtraFrames) {
      await pump(pumpFrame);
      extra++;
    }
    return extra;
  }

  /// `totalSpan` of the frame at [ordinal] in milliseconds, or null when no
  /// timing was ever reported for it.
  ///
  /// Null rather than `0.0`: a frame that reported nothing is a hole in the
  /// sample, and zero is a *fast frame*. Publishing one as the other is how a
  /// composite blit that drew nothing gets read as a settle.
  double? msAt(int ordinal) {
    _refuseShiftedStream();
    return ordinal >= 0 && ordinal < _reported.length
        ? _reported[ordinal].totalSpan.inMicroseconds / 1000.0
        : null;
  }

  /// [msAt] over the half-open ordinal range `[start, end)`, holes included.
  List<double?> msRange(int start, int end) =>
      <double?>[for (var i = start; i < end; i++) msAt(i)];

  /// **Added by the throwaway `spike/widget-per-entity` branch.** The raw
  /// timings, for a caller that needs the build/raster split rather than the
  /// `totalSpan` [msAt] returns. Goes through the same shifted-stream refusal,
  /// so it cannot hand back ordinals the log has already disowned.
  List<FrameTiming> get debugTimings {
    _refuseShiftedStream();
    return List<FrameTiming>.unmodifiable(_reported);
  }

  /// **Added by the throwaway `spike/flutter-gpu-backend` branch, for the web
  /// arm and nothing else.** The timings without the shifted-stream refusal.
  ///
  /// On the web the stream shifts as a matter of course: the backlog latch
  /// fires on the *plain painter* arm, before any GPU code runs, so the
  /// refusal is not reporting a defect in what is being measured -- it is
  /// reporting that ordinal alignment, which this log was built to guarantee
  /// on native, does not hold there.
  ///
  /// **What this changes about the measurement, stated because it is not a
  /// free pass.** With alignment, a figure is "the i-th frame this phase
  /// pumped". Without it, a figure is "a frame reported inside this phase's
  /// window", which may include a straggler from the phase before and may
  /// miss one that lands after. That is sound for a *distribution* over tens
  /// of frames and unsound for any statement about a particular frame. Every
  /// caller of this getter must say so where it prints, and must report
  /// [debugWorstExcess] beside the numbers.
  ///
  /// Wall-clock timing was considered first and rejected: `pumpFrame` waits
  /// for vsync, so every frame cheaper than the refresh interval reads as the
  /// refresh interval, and the whole question here is the difference between
  /// half a millisecond and three.
  List<FrameTiming> get debugTimingsUnaligned =>
      List<FrameTiming>.unmodifiable(_reported);

  /// The largest excess of reported frames over pumped frames seen after the
  /// baseline. Zero means the stream never shifted.
  int get debugWorstExcess => _worstExcess;
}

/// How long [FrameTimingLog.establishBaseline] waits for the engine to flush a
/// batch of `FrameTiming`s.
///
/// The framework's own figure is "approximately once every 100ms in debug and
/// profile builds"; this is that with margin, and the baseline waits two of
/// them per round.
const Duration kTimingBatchWindow = Duration(milliseconds: 150);

/// How many frames [FrameTimingLog.establishBaseline] pumps per round, back to
/// back, before it stops and waits.
const int kBaselineFramesPerRound = 4;

/// How many rounds [FrameTimingLog.establishBaseline] gives the stream to go
/// quiet before it refuses to produce a baseline at all.
const int kBaselineMaxRounds = 8;

/// What [runSettlePhase] measured: the idle settle after a gesture.
class SettleReport {
  SettleReport({
    required this.frames,
    required this.covered,
    required this.coveringFrameMs,
    required this.wallMs,
    required this.framesMissing,
  });

  /// How many idle frames elapsed before [TileCache.viewportCovered] first
  /// read true, or the whole idle budget when it never did (see [covered]).
  final int frames;

  /// Whether coverage was reached at all inside the idle budget.
  final bool covered;

  /// `totalSpan` of the single frame at which coverage was first read -- **one
  /// frame, not the settle**. See [ZoomReport.settleCoveringFrameMs].
  ///
  /// **Null when that frame reported no timing at all**, which is the hole
  /// [FrameTimingLog.msAt] takes such care to distinguish from a zero: zero is
  /// a *fast frame*, and publishing a hole as one is how a composite blit that
  /// drew nothing gets read as a settle. The type carries it, so a reader who
  /// takes this field without also reading [framesMissing] still cannot get a
  /// number where there was none.
  final double? coveringFrameMs;

  /// Wall clock across [frames], summed. See [ZoomReport.settleWallMs].
  final double wallMs;

  /// How many of those [frames] never reported a timing. Nonzero means both
  /// figures above are over a short sample and must not be published as they
  /// stand.
  final int framesMissing;
}

/// Idle frames pumped after the gesture, pinned by design spec §5.
const int kIdleFrames = 30;

/// Throwaway frames pumped at the phase boundary, before the gesture's
/// counters are reset. Their ordinals are excluded from every published
/// window -- see [runTileZoomPhase].
const int kZoomWarmUpFrames = 2;

/// The idle settle that follows the gesture: [idleFrames] bare frames, the
/// first frame at which [covered] reads true, and the two time figures
/// criteria 3 and 4 are read off.
///
/// **The idle frames drive no camera change at all** -- unlike the forced
/// no-op `panBy(Offset.zero)` this file's other phases use to force a repaint
/// once nothing is dirty, an idle frame here is a bare [pumpFrame] call.
/// `DraftCanvasState`'s own settle notifier
/// (`draft_canvas.dart:_requestSettleFrame`) is what keeps requesting a real
/// frame for as long as the cache owes tiles; forcing one artificially would
/// measure a phase this rig does not drive on a real trackpad gesture's tail.
///
/// It pumps the full [idleFrames] even after coverage, so a cache that keeps
/// asking for frames after covering (which it must not) is exercised the same
/// way a real gesture's tail would exercise it.
///
/// **[covered] is a predicate and not the cache itself** so that this
/// attribution can be tested at all: [runTileZoomPhase] refuses to run outside
/// a profile build, and a `TileCache` cannot be made to cover a viewport
/// without a painted widget. The production call site passes
/// `() => cache.viewportCovered`.
Future<SettleReport> runSettlePhase({
  required FrameTimingLog log,
  required Future<void> Function() pumpFrame,
  required bool Function() covered,
  int idleFrames = kIdleFrames,
}) async {
  final firstOrdinal = log.pumpedFrames;
  var frames = idleFrames;
  var everCovered = false;
  for (var i = 0; i < idleFrames; i++) {
    await log.pump(pumpFrame);
    // Coverage is read straight after the pump because it is *cache state*,
    // written during the frame that just ran -- it is only the frame's
    // *timing* that arrives late, and that is what the ordinal below is for.
    if (!everCovered && covered()) {
      everCovered = true;
      frames = i + 1;
    }
  }
  await log.drain(pumpFrame, upTo: firstOrdinal + idleFrames);

  final ms = log.msRange(firstOrdinal, firstOrdinal + frames);
  var wallMs = 0.0;
  var missing = 0;
  for (final v in ms) {
    if (v == null) {
      missing++;
    } else {
      wallMs += v;
    }
  }
  return SettleReport(
    frames: frames,
    covered: everCovered,
    // `ms.last` already carries the hole as null; there is nothing to
    // substitute for it. An empty window (`frames` of zero, which only a zero
    // idle budget produces) is the same absence.
    coveringFrameMs: ms.isEmpty ? null : ms.last,
    wallMs: wallMs,
    framesMissing: missing,
  );
}

/// What [runTileZoomPhase] reports: the gesture's frame times and the
/// cache's counters over it, then the settle that follows.
class ZoomReport {
  ZoomReport({
    required this.gestureFrameMs,
    required this.gestureFramesMissing,
    required this.gestureBakes,
    required this.gestureLiveDraws,
    required this.settleCoveringFrameMs,
    required this.settleWallMs,
    required this.settleFrames,
    required this.settleCovered,
    required this.settleFramesMissing,
  });

  /// Builds a report from a gesture window and the [SettleReport] that
  /// followed it.
  factory ZoomReport.from({
    required List<double?> gestureMs,
    required int gestureBakes,
    required int gestureLiveDraws,
    required SettleReport settle,
  }) {
    final frames = <double>[];
    var missing = 0;
    for (final v in gestureMs) {
      if (v == null) {
        missing++;
      } else {
        frames.add(v);
      }
    }
    return ZoomReport(
      gestureFrameMs: frames,
      gestureFramesMissing: missing,
      gestureBakes: gestureBakes,
      gestureLiveDraws: gestureLiveDraws,
      settleCoveringFrameMs: settle.coveringFrameMs,
      settleWallMs: settle.wallMs,
      settleFrames: settle.frames,
      settleCovered: settle.covered,
      settleFramesMissing: settle.framesMissing,
    );
  }

  /// `totalSpan`, one entry per gesture frame whose timing was actually
  /// reported. p95 over this list is criterion 2.
  ///
  /// **The 80-entry claim is enforced, not asserted.** The window is the
  /// ordinal range of the `2 * kZoomSteps` frames the script pumped, so
  /// `gestureFrameMs.length + gestureFramesMissing == 2 * kZoomSteps` always
  /// holds, and a short sample shows up as [gestureFramesMissing] rather than
  /// as a p95 over a silently truncated list. Before the ordinal window, the
  /// count was 80 by coincidence: the callback was registered after the two
  /// warm-up frames -- which rasterise before registration and are reported
  /// after it -- and removed the instant the last frame was pumped, so the
  /// sample was padded at the head with the two cheapest frames in the phase
  /// and truncated at the tail by however many timings were still in flight.
  /// Both errors push p95 down, which is the direction that makes criterion 2
  /// pass.
  final List<double> gestureFrameMs;

  /// How many of the `2 * kZoomSteps` gesture frames never reported a timing,
  /// even after [FrameTimingLog.drain]. Zero on a healthy run; anything else
  /// means [gestureFrameMs] is short and its p95 is not the criterion's.
  final int gestureFramesMissing;

  /// [TileCache.bakeCount] since the counters were reset at the start of the
  /// gesture, read at the gesture's end.
  ///
  /// **This is the budgeted path's unit: once per tile, not once per band.**
  /// Every frame in the 80-frame gesture is a *moving* frame -- the camera
  /// changes every frame by construction -- so [TileCache.paintFrame]'s rest
  /// branch (`_restBake`, counted once per band) never runs during the
  /// gesture; only the ordinary budgeted tile loop could contribute here.
  /// Criterion 1 expects this at zero. A reader comparing this figure
  /// against a settle-phase bake count (band-counted) would be comparing two
  /// different units -- see `TileCache.bakeCount`'s own doc comment.
  final int gestureBakes;

  /// [TileCache.liveDrawCount] over the same window as [gestureBakes].
  /// Criterion 1 expects this at zero too.
  final int gestureLiveDraws;

  /// `totalSpan` of the **one** idle frame at which [TileCache.viewportCovered]
  /// first became true, or of the last idle frame pumped if [kIdleFrames]
  /// never reached coverage. Criterion 3 reads this, and criterion 3 only.
  ///
  /// **One frame, and never the settle's duration.** Criterion 4 is wall clock
  /// across the whole settle and is [settleWallMs]; on the rest-bake arm the
  /// settle is ~1 baking frame and the two nearly coincide, but on the
  /// denominator arm the settle is many frames and this figure is the last of
  /// them alone. A ratio formed from this field compares one frame against one
  /// frame -- the "two readings straddling the gate" design spec §4 exists to
  /// prevent.
  ///
  /// **Null is a hole, not a fast frame.** See
  /// [SettleReport.coveringFrameMs]: when the frame criterion 3 names reported
  /// no timing at all there is no number, and this field says so in its type
  /// rather than handing back a `0.0` that reads as the fastest frame in the
  /// run.
  final double? settleCoveringFrameMs;

  /// Criterion 4's numerator or denominator, quoting the criterion: **"wall
  /// clock to a covered viewport, from the first frame after the gesture ends
  /// to the frame that covers it"**.
  ///
  /// The sum of `totalSpan` over idle frames 1..[settleFrames] inclusive --
  /// the frame that covers the viewport included, the idle frames after it
  /// excluded. This is the only figure criterion 4's ratio may be formed
  /// from; see [settleCoveringFrameMs] for why the per-frame figure is not.
  final double settleWallMs;

  /// How many idle frames elapsed before [TileCache.viewportCovered] first
  /// read true, or [kIdleFrames] if coverage was never reached inside the
  /// pinned idle-frame budget (which [settleCovered] distinguishes).
  ///
  /// **Correct code reads 2, not 1** (Ruling 15 in Plan 3i's ledger). The
  /// arithmetic: `kRestGateFrames` is 2, so a bake needs two consecutive
  /// frames on the same camera; the last gesture frame changed the camera, so
  /// idle frame 1 can only reach `_restGateSteps == 1` and takes
  /// `paintFrame`'s moving-frame early return; idle frame 2 is the first that
  /// can bake. Criterion 3's stated "one frame" and the separately pinned
  /// `kRestGateFrames = 2` cannot both hold, and 1 here is a value only broken
  /// code produces. `tile_zoom_warmth_test.dart` pins `settleFrames == 2` in
  /// the other package.
  final int settleFrames;

  /// Whether coverage was reached at all within [kIdleFrames]. False makes
  /// [settleFrames] a floor rather than a measurement, and both time figures
  /// meaningless.
  final bool settleCovered;

  /// How many of the [settleFrames] never reported a timing. See
  /// [gestureFramesMissing].
  final int settleFramesMissing;
}

/// The `tile zoom` phase, pinned by the design spec (§5) and not the
/// implementer's to choose: [kZoomSteps] frames zooming in at [kZoomFactor]
/// about [zoomFocusFor], then [kZoomSteps] zooming back out at
/// `1 / kZoomFactor` about the same point -- one camera change per frame,
/// matching what a trackpad delivers -- then 30 idle frames, where the
/// settle is read.
///
/// **[camera] must already be at R2's fitted camera** (the same
/// `ViewportTransform.fit` the caller's R2 rig used, before that rig's own
/// scripted motion), so the zoom arm and Plan 3h's tile-pan arm are
/// comparable measurements of the same starting state, not of two different
/// cameras.
///
/// **[viewport] is the pinned reference size, 1600x1200 logical at
/// `devicePixelRatio` 2 -- not necessarily the real window.** Every number
/// in the design spec's §5 is priced against that size; [zoomFocusFor] turns
/// it into a screen-space anchor, the same shape of derivation `runR2Rig`'s
/// own zoom step makes through [r2ZoomAnchorFor] -- except that this phase's
/// anchor comes from the size the spec priced, and R2's comes from the window
/// actually in use. A caller on a
/// real window of a different size gets a phase that still runs -- `zoomAt`
/// accepts any finite, positive factor at any screen point -- but the
/// focal point then sits at a different fraction of the *real* viewport than
/// 30%/70%, and comparing its numbers against another run's figures, or
/// against the design spec's priced predictions, is only sound once the
/// window is confirmed to actually be the reference size. `main.dart`'s
/// `RUN_R2` mode prints the real window size for exactly this reason; a
/// caller of this phase should do the same.
///
/// The idle settle after the gesture is [runSettlePhase]'s, and its doc
/// comment carries why an idle frame here is a bare [pumpFrame] call.
///
/// **Every frame this phase pumps goes through one [FrameTimingLog].** The
/// warm-up frames are pumped *after* the log is armed and then excluded by
/// ordinal, rather than pumped before registration and silently charged to the
/// gesture; the gesture window is an ordinal range rather than "whatever
/// arrived between two registrations"; the engine's backlog at arming time is
/// drained and the ordinals rebased before the first warm-up frame, so
/// ordinal 0 is a frame this phase pumped; and the settle's last frames are
/// drained rather than dropped. See [FrameTimingLog] for why every one of
/// those is the same bug.
Future<ZoomReport> runTileZoomPhase({
  required CameraController camera,
  required TileCache cache,
  required Future<void> Function() pumpFrame,
  required Size viewport,
}) async {
  refuseDebugMode();
  final focus = zoomFocusFor(viewport);
  final log = FrameTimingLog()..arm();
  try {
    // Arming registers a callback; it does not empty the engine's queue. The
    // caller's own pump just before this phase (`main.dart`'s `runArm` resets
    // the camera and pumps one frame) rasterises *after* its pump returns, so
    // its timing is guaranteed to arrive here, and whatever else the engine
    // had not batched arrives with it. Both would take ordinals belonging to
    // frames pumped later, and nothing downstream can see it: a window shifted
    // whole has no holes for `framesMissing` to find. This drains them and
    // rebases the ordinals; see [FrameTimingLog.establishBaseline].
    await log.establishBaseline(pumpFrame);

    // Two throwaway frames before the counters reset, the same boundary slack
    // `runTilePhases`'s own `phase()` helper takes -- but pumped *after* the
    // log is armed, so their timings land on ordinals 0 and 1 and are excluded
    // by the gesture window below. Pumped before arming, they would rasterise
    // before registration, be reported after it, and take the first two
    // gesture ordinals: a no-op repaint of a covered generation is the
    // cheapest frame in the phase, and two of them at the head of the sample
    // push p95 down.
    for (var i = 0; i < kZoomWarmUpFrames; i++) {
      camera.panBy(Offset.zero);
      await log.pump(pumpFrame);
    }

    // Warm-up excluded: reset only after the fitted camera has settled (the
    // two throwaway frames above), per §5.
    final gestureStart = log.pumpedFrames;
    cache.resetCounters();
    for (var i = 0; i < kZoomSteps; i++) {
      camera.zoomAt(focus, kZoomFactor);
      await log.pump(pumpFrame);
    }
    for (var i = 0; i < kZoomSteps; i++) {
      camera.zoomAt(focus, 1 / kZoomFactor);
      await log.pump(pumpFrame);
    }
    // Read before the settle: the settle bakes, and these two counters are
    // the gesture's.
    final gestureBakes = cache.bakeCount;
    final gestureLiveDraws = cache.liveDrawCount;

    final settle = await runSettlePhase(
      log: log,
      pumpFrame: pumpFrame,
      covered: () => cache.viewportCovered,
    );

    // The gesture window, read only now: the settle's own drain is what
    // brought the last gesture frames' timings in.
    return ZoomReport.from(
      gestureMs: log.msRange(gestureStart, gestureStart + 2 * kZoomSteps),
      gestureBakes: gestureBakes,
      gestureLiveDraws: gestureLiveDraws,
      settle: settle,
    );
  } finally {
    log.disarm();
  }
}

/// Prints a [ZoomReport] the way [report] prints a plain frame-timing list,
/// plus the counters [report] alone cannot see.
///
/// **`gestureBakes` is the budgeted, per-tile unit of [TileCache.bakeCount],
/// not the per-band unit the rest bake counts in.** See [ZoomReport
/// .gestureBakes]'s own doc comment for why: every gesture frame is moving,
/// so the rest path never contributes to it. A reader comparing this figure
/// against a Plan 3g or 3h transcript, where `bakeCount` always meant tiles,
/// is comparing like with like here -- but comparing it against this same
/// cache's post-settle `bakeCount` would not be, because a rest bake (if one
/// fired during the idle frames this report also covers) counts bands.
/// **Every line carries [label].** An interleaved run prints two arms per
/// repeat and the arms differ only in which flag was flipped; a continuation
/// line indented under the wrong heading is a number attributed to the wrong
/// arm, which is the failure mode of this whole measurement.
void printZoomReport(String label, ZoomReport r) {
  if (r.gestureFrameMs.isEmpty) {
    print('$label: no gesture frames recorded');
  } else {
    final sorted = [...r.gestureFrameMs]..sort();
    var sum = 0.0;
    for (final v in sorted) {
      sum += v;
    }
    print('$label gestureFrames=${sorted.length} '
        'p50=${sorted[(sorted.length * 0.5).floor()].toStringAsFixed(2)}ms '
        'p95=${sorted[(sorted.length * 0.95).floor()].toStringAsFixed(2)}ms '
        'max=${sorted.last.toStringAsFixed(2)}ms '
        'mean=${(sum / sorted.length).toStringAsFixed(2)}ms');
  }
  print('$label   gestureBakes=${r.gestureBakes}(tiles, budgeted path) '
      'gestureLiveDraws=${r.gestureLiveDraws}');
  // Two time figures, never one. `settleWallMs` is criterion 4's wall clock
  // across the settle; `coveringFrameMs` is criterion 3's single frame. They
  // coincide only when the settle is one frame long, which is the arm the
  // ratio's numerator comes from and not the arm its denominator comes from.
  print('$label   settleFrames=${r.settleFrames} '
      'covered=${r.settleCovered} '
      'settleWallMs=${r.settleWallMs.toStringAsFixed(2)}(criterion 4, '
      'wall clock over the settle) '
      // A hole prints as a hole. `0.00` here would be the fastest frame of the
      // run, and criterion 3 would be read off a frame that never reported.
      'coveringFrameMs='
      '${r.settleCoveringFrameMs?.toStringAsFixed(2) ?? "NONE"}'
      '(criterion 3, that one frame)');
  if (r.settleCoveringFrameMs == null) {
    print('$label   !!! WARNING: criterion 3 has NO figure -- the frame that '
        'coverage was read at reported no FrameTiming at all. That is a hole '
        'in the sample and not a fast frame !!!');
  }
  if (!r.settleCovered) {
    print('$label   !!! WARNING: the viewport never covered within '
        '$kIdleFrames idle frames -- settleFrames is a floor, and neither '
        'time figure above is a settle !!!');
  }
  final missing = r.gestureFramesMissing + r.settleFramesMissing;
  if (missing > 0) {
    print('$label   !!! WARNING: $missing frame(s) reported no FrameTiming '
        '(gesture ${r.gestureFramesMissing} of ${2 * kZoomSteps}, settle '
        '${r.settleFramesMissing} of ${r.settleFrames}) -- the figures above '
        'are over a SHORT SAMPLE and are not comparable !!!');
  }
}

/// Runs [rest] and [tiled] alternately — `rest, tiled, rest, tiled, …` — for
/// [arms] repeats of each, awaiting every callback before starting the next.
///
/// **The interleaved unit is one whole arm, not one frame.** An arm is a
/// complete phase — a zoom script, its settle and its report — and splitting
/// it finer would interleave two half-measured caches into each other's
/// generations. What is refused here is the *blocked* ordering: all of one arm
/// and then all of the other.
///
/// **Why it matters, in this repository's own numbers.** A measurement session
/// drifts: the machine warms, other processes come and go, the shader cache
/// fills. Under a blocked ordering every bit of that drift lands on whichever
/// arm ran last, and the ratio reports the drift as if it were the effect.
/// `docs/superpowers/notes/2026-08-25-plan-3h-results.md` records exactly that
/// happening — its M4 arm ran last, in a visibly noisier session, on a phase
/// M4 is inert on, so the ordering and not the mutation moved the numbers.
/// Alternating puts the same drift on both arms, where a ratio divides it out.
///
/// It reports nothing itself and holds no state: each callback owns its own
/// configuration and its own printing, so the two arms of criterion 4 (the
/// rest bake against `TileCache.debugRestBakeDisabled`) and the two arms of
/// criterion 8 (the narrowed query against `TileCache.debugFullViewportQuery`)
/// can share this one driver without it knowing which switch it is driving.
///
/// `arms: 0` calls neither, rather than running one of each — the count is a
/// number of repeats, and an off-by-one here would silently publish an n=1
/// row under an n=0 heading.
Future<void> runInterleaved({
  required int arms,
  required Future<void> Function() rest,
  required Future<void> Function() tiled,
}) async {
  for (var i = 0; i < arms; i++) {
    await rest();
    await tiled();
  }
}

/// One arm of an interleaved zoom measurement: which criterion it belongs to,
/// which side of that criterion's ratio it is, and the runtime flag that makes
/// it that side.
///
/// **An arm is a whole configuration, not a flag.** [applyTo] writes *both*
/// measurement flags on every arm, so an arm's label describes the cache
/// completely and no leftover from a previous criterion's run can sit under a
/// label that does not mention it.
enum ZoomArm {
  /// Criterion 4's numerator: the rest bake this plan added.
  restBakeOn(
    criterion: 4,
    side: 'A',
    flag: 'debugRestBakeDisabled=false',
    description: "rest bake ON -- criterion 4's numerator",
  ),

  /// Criterion 4's denominator: "today's behaviour with the rest bake
  /// disabled", which is the tiled fill the rest bake replaces.
  restBakeOff(
    criterion: 4,
    side: 'B',
    flag: 'debugRestBakeDisabled=true',
    description: "rest bake OFF -- criterion 4's denominator, the tiled fill",
  ),

  /// Criterion 8's numerator: the narrowed band query.
  narrowQuery(
    criterion: 8,
    side: 'A',
    flag: 'debugFullViewportQuery=false',
    description: "narrow band query -- criterion 8's numerator",
  ),

  /// Criterion 8's denominator, which is **Plan 3h's M4** and not this plan's:
  /// mutant numbering is per-plan and M4/M5 collide between the two logs, so
  /// the label says whose M4 it is.
  fullViewportQuery(
    criterion: 8,
    side: 'B',
    flag: 'debugFullViewportQuery=true',
    description: "full-viewport query (Plan 3h's M4) -- criterion 8's "
        'denominator',
  );

  const ZoomArm({
    required this.criterion,
    required this.side,
    required this.flag,
    required this.description,
  });

  /// Which numbered criterion in design spec §4 this arm belongs to.
  final int criterion;

  /// `A` for the criterion's numerator, `B` for its denominator.
  final String side;

  /// The flag state that defines this arm, printed verbatim in its label so a
  /// reader never has to infer which switch was flipped.
  final String flag;

  /// What the arm is, in the criterion's own words.
  final String description;

  /// Puts [cache] into this arm's configuration.
  ///
  /// **No generation reset, deliberately.** A zoom round trip leaves no warm
  /// tiles: the excursion's first zoom frame already fails
  /// `TileGrid.matchesScale`, the generation is retired and its tiles disposed,
  /// and the trip lands on scale `1.4000000000000017` rather than `1.4`. That
  /// was settled by test rather than by argument -- see
  /// `tile_zoom_warmth_test.dart` in `jet_cad_2d_flutter` -- so each arm
  /// genuinely re-bakes and neither arm's settle is trivially covered. Only
  /// the flags are written here.
  void applyTo(TileCache cache) {
    cache.debugRestBakeDisabled = this == ZoomArm.restBakeOff;
    cache.debugFullViewportQuery = this == ZoomArm.fullViewportQuery;
  }
}

/// A criterion measured as a ratio between two interleaved [ZoomArm]s.
enum ZoomCriterion {
  /// Criterion 4: rest-bake wall clock against the tiled fill it replaces.
  four(numerator: ZoomArm.restBakeOn, denominator: ZoomArm.restBakeOff),

  /// Criterion 8: Plan 3h's criterion 3, re-measured at n=7-9 interleaved.
  eight(numerator: ZoomArm.narrowQuery, denominator: ZoomArm.fullViewportQuery);

  const ZoomCriterion({required this.numerator, required this.denominator});

  final ZoomArm numerator;
  final ZoomArm denominator;
}

/// The label every line of an arm's report is printed under.
///
/// It names the phase, the criterion, the repeat, the side of the ratio, the
/// exact flag state and the entity count -- everything a reader needs to
/// attribute the numbers without reading the source that produced them. A
/// transcript a reader cannot attribute is the failure mode this measurement
/// has already been bitten by: nine repetitions of one arm, printed as
/// `arm 0..8`, with nothing naming which arm was which and every ratio reading
/// 1.00.
///
/// **[phase] is required and has no default, because the phase an arm ran on
/// is exactly what Ruling 21 turned on.** Criterion 4 alternates around the
/// `tile zoom` phase; criterion 8 alternates around `tile pan`, because
/// `debugFullViewportQuery` modifies the live fallback and the zoom phase --
/// this plan having removed its live walk, and criterion 1 having scored that
/// as a PASS in the same session -- never runs one. A transcript that named
/// the wrong phase would look exactly like the eighteen arms that measured
/// nothing, so a default here would be a default on the load-bearing word.
String zoomArmLabel(
  ZoomArm arm, {
  required int repeat,
  required int repeats,
  required int entities,
  required String phase,
}) =>
    'R2 $phase c${arm.criterion} repeat ${repeat + 1}/$repeats '
    'arm ${arm.side} [${arm.flag}] ${arm.description} ($entities)';

/// The label a repeat of the **plain** zoom mode prints under: one
/// configuration, repeated, with no measurement flag flipped.
///
/// **It must not be mistakable for [zoomArmLabel]'s output.** The word "arm"
/// appears only in the phrase that denies it, both flag states are printed
/// even though neither was flipped, and the criterion named is 2. What this
/// replaces printed `R2 tile zoom arm 0..8` -- the shape and the labelling of
/// the n=9 interleaved transcript criteria 4 and 8 call for, produced by a run
/// in which no flag was ever flipped and every ratio would read 1.00.
String zoomPlainLabel({
  required int repeat,
  required int repeats,
  required int entities,
}) =>
    'R2 tile zoom plain repeat ${repeat + 1}/$repeats '
    '[debugRestBakeDisabled=false debugFullViewportQuery=false] '
    'criterion 2 only, NOT an interleaved arm ($entities)';

/// Drives [criterion]'s two arms, [repeats] times, alternating them and
/// flipping the flag that makes each arm the arm its label names.
///
/// This is the *arrangement* design spec §4 pins as part of criterion 4 and
/// criterion 8: same session, interleaved, never blocked, and every arm's
/// number reported rather than only the aggregate. [runInterleaved] owns the
/// ordering; this owns the configuration and the labelling.
///
/// **[R] is the arm's report type, and it differs between the two criteria
/// because the two criteria are measured on different phases.** Criterion 4's
/// arm is a [ZoomReport] from [runTileZoomPhase]; criterion 8's is a
/// [PanArmReport] from [runTilePanArm], because Plan 3h's criterion 3 -- which
/// criterion 8 re-measures at n=7-9 interleaved -- was read off the `tile pan`
/// phase, and `debugFullViewportQuery` has no effect anywhere else. See
/// Ruling 21, and [runTilePanArm]'s doc comment.
///
/// [runArm] runs one whole phase and returns its report -- it is responsible
/// for restoring the camera to the fitted state first, because the arms of a
/// ratio must start from the same camera. [emit] prints in production and
/// records in tests. [phase] is the phase name every one of that arm's lines
/// is labelled with; see [zoomArmLabel] for why it has no default.
///
/// The flags are restored to their defaults when the run ends, however it
/// ends: a later phase in the same session must not inherit a measurement
/// switch. The cache's *generations* are deliberately left alone -- see
/// [ZoomArm.applyTo].
Future<void> runCriterionArms<R>({
  required ZoomCriterion criterion,
  required int repeats,
  required int entities,
  required TileCache cache,
  required String phase,
  required Future<R> Function() runArm,
  required void Function(String label, R report) emit,
}) async {
  var repeat = 0;
  try {
    await runInterleaved(
      arms: repeats,
      rest: () async {
        final arm = criterion.numerator;
        arm.applyTo(cache);
        final label = zoomArmLabel(arm,
            repeat: repeat, repeats: repeats, entities: entities, phase: phase);
        emit(label, await runArm());
      },
      tiled: () async {
        final arm = criterion.denominator;
        arm.applyTo(cache);
        final label = zoomArmLabel(arm,
            repeat: repeat, repeats: repeats, entities: entities, phase: phase);
        emit(label, await runArm());
        repeat++;
      },
    );
  } finally {
    cache.debugRestBakeDisabled = false;
    cache.debugFullViewportQuery = false;
  }
}

/// [runCriterionArms] around the `tile zoom` phase, which is criterion 4's.
///
/// Kept as its own entry point rather than folded into the generic call:
/// criterion 4's numbers are already taken (four repeats at each of 50,000 and
/// 500,000, recorded in Plan 3i's ledger) and its transcript has to stay
/// reproducible line for line, so its phase name and its default [emit] are
/// pinned here where a later edit to criterion 8 cannot reach them.
Future<void> runZoomCriterionArms({
  required ZoomCriterion criterion,
  required int repeats,
  required int entities,
  required TileCache cache,
  required Future<ZoomReport> Function() runArm,
  void Function(String label, ZoomReport report) emit = printZoomReport,
}) =>
    runCriterionArms<ZoomReport>(
      criterion: criterion,
      repeats: repeats,
      entities: entities,
      cache: cache,
      phase: 'tile zoom',
      runArm: runArm,
      emit: emit,
    );

/// The bound on the warm loop [runTilePanArm] opens with. A run that hits it
/// never reached a warm cache and its `tile hold` regime would be measuring a
/// refill; the figure is reported per arm so that shows up rather than hides.
const int kPanArmWarmMaxFrames = 400;

/// Consecutive non-baking frames, on a covered viewport, that [runTilePanArm]
/// takes as the end of its warm.
///
/// Three and not one: the frame straight after a camera change can never bake
/// (`kRestGateFrames` is 2 -- Ruling 15's arithmetic), so a single non-baking
/// frame is the normal state of the *first* frame of a warm and says nothing
/// about whether the cache is full.
const int kPanArmWarmIdleFrames = 3;

/// The zoom factor [runTilePanArm]'s purge takes an excursion to, and back
/// from, before it warms.
///
/// Any factor that cannot be mistaken for the current scale does; 2 is far
/// outside `TileGrid.matchesScale`'s tolerance in a way no reader has to check
/// the tolerance to be sure of.
const double kPanArmPurgeZoom = 2.0;

/// How many extra frames [runTilePanArm] pumps after its pan, waiting for the
/// last pan frames' timings to arrive.
///
/// [FrameTimingLog.drain]'s default of 4 is 66 ms at 60 Hz and a profile build
/// batches `FrameTiming`s about every 100 ms, so the default cannot span one
/// batch: the first check run lost three to five pan frames in every arm. This
/// is half a second of bare frames, which is cheap and is a bound, not a wait
/// loop.
const int kPanArmDrainFrames = 30;

/// What [runTilePanArm] measured: the state the arm's pan began from, the
/// `tile hold` control, and the `tile pan` window criterion 8's statistic is
/// read off.
///
/// **Two phases and not one, deliberately.** `tile hold` is a phase Plan 3h's
/// M4 -- the mutation `TileCache.debugFullViewportQuery` reproduces at runtime
/// -- **cannot** touch: the camera does not move, every visible tile is a hit,
/// the live fallback never runs, and the flag modifies nothing else. A
/// systematic difference between the two arms' hold figures is therefore pure
/// session drift, and it is the control that exposed Plan 3h's own ordering
/// bias (its M4 arm ran last, in a visibly noisier session, and read an order
/// of magnitude higher on `tile hold`). It costs [kTileHoldFrames] frames of
/// almost pure blit, which is cheap enough to keep in every arm.
class PanArmReport {
  PanArmReport({
    required this.warmFrames,
    required this.warmBakes,
    required this.tilesAfterPurge,
    required List<double?> holdMs,
    required this.holdBakes,
    required this.holdLiveDraws,
    required List<double?> panMs,
    required this.panBakes,
    required this.panBakeFrames,
    required this.panMaxBakesInAFrame,
    required this.panBlits,
    required this.panCarryOverBlits,
    required this.panLiveDraws,
    required this.panNewEvictions,
    required this.liveTiles,
    required this.tileBytes,
  })  : holdFrameMs = _present(holdMs),
        holdFramesMissing = _missing(holdMs),
        panFrameMs = _present(panMs),
        panFramesMissing = _missing(panMs);

  /// Frames the warm loop took to drive [TileCache.bakeCount] to a standstill
  /// at the arm's starting camera, and the bakes it paid for getting there.
  ///
  /// **These are what say the arms started comparable, and they are reported
  /// rather than assumed.** Every arm purges the generation, resets the camera
  /// to R2's fitted camera and warms to a standstill before it holds or pans,
  /// so the pan of every arm starts at the same camera with a generation built
  /// from cold. A [warmBakes] of zero is the symptom of the failure the purge
  /// exists to remove -- an arm that found the tiles already there -- and it is
  /// visible in the transcript rather than left to trust.
  final int warmFrames;
  final int warmBakes;

  /// [TileCache.liveTileCount] immediately after the purge and before the warm
  /// loop. **Zero is what a working purge looks like**; anything else means the
  /// generation the previous arm left behind survived into this one, and this
  /// arm's pan is blitting rather than baking. See [runTilePanArm].
  final int tilesAfterPurge;

  /// `totalSpan` per `tile hold` frame that reported a timing, and how many
  /// did not. The control regime -- see the class doc.
  final List<double> holdFrameMs;
  final int holdFramesMissing;

  /// [TileCache.bakeCount] and [TileCache.liveDrawCount] over the hold window.
  /// Both are expected at zero: a hold that bakes is a hold that was not warm,
  /// and a hold that draws live is not the control this arm thinks it is.
  final int holdBakes;
  final int holdLiveDraws;

  /// `totalSpan` per `tile pan` frame that reported a timing. **p95 over this
  /// list is criterion 8's statistic**, on both sides of the ratio, and it is
  /// the same statistic Plan 3h's criterion 3 was scored on.
  final List<double> panFrameMs;

  /// How many of the [kTilePanFrames] pan frames never reported a timing.
  /// Anything but zero means [panFrameMs] is short and its p95 is not the
  /// criterion's.
  final int panFramesMissing;

  /// The cache's own counters over the pan window. [panLiveDraws] is the one
  /// that says whether this arm measured anything at all: see
  /// [printPanArmReport].
  final int panBakes;
  final int panBakeFrames;
  final int panMaxBakesInAFrame;
  final int panBlits;
  final int panCarryOverBlits;
  final int panLiveDraws;
  final int panNewEvictions;

  /// The generation at the end of the pan, for the same reason
  /// [runTilePhases]' block prints them: a pan that quietly evicted its way
  /// through the phase is not the pan the figure claims.
  final int liveTiles;
  final int tileBytes;

  /// p95 of [panFrameMs], or null when the pan reported nothing at all.
  ///
  /// **The quantile is `(n * 0.95).floor()`, matching [report]'s**, so a pan
  /// arm's figure and an R2 `tile pan` block's figure are the same statistic
  /// and can be read against each other. Criterion 9 reads the block; criterion
  /// 8 reads these arms.
  double? get panP95Ms {
    if (panFrameMs.isEmpty) return null;
    final sorted = [...panFrameMs]..sort();
    return sorted[(sorted.length * 0.95).floor()];
  }

  static List<double> _present(List<double?> ms) => <double>[
        for (final v in ms)
          if (v != null) v
      ];

  static int _missing(List<double?> ms) {
    var n = 0;
    for (final v in ms) {
      if (v == null) n++;
    }
    return n;
  }
}

/// One arm of criterion 8: warm the cache at the arm's starting camera, hold
/// [kTileHoldFrames] frames, then pan [kTilePanFrames] frames at [panStep].
///
/// **Why the pan phase and not the zoom phase (Ruling 21).** Criterion 8
/// re-measures Plan **3h**'s criterion 3 at n=7-9 interleaved, and 3h measured
/// that criterion on the `tile pan` phase -- see
/// `docs/superpowers/notes/2026-08-25-plan-3h-results.md`, whose tables report
/// it as narrowed `tile pan` p95 against M4 `tile pan` p95. The arm this
/// replaces alternated `TileCache.debugFullViewportQuery` around
/// [runTileZoomPhase] instead. That flag modifies exactly one thing, the live
/// fallback's query extent in `TileCache.paintFrame`, and every frame of the
/// zoom phase is a *moving* frame, which blits the carry-over composite and
/// returns before the fallback can run. A full n=9 interleaved run at 500,000
/// entities completed cleanly, printed `gestureLiveDraws=0` in all eighteen
/// arms, and measured nothing. The irony is worth keeping: the zoom phase has
/// no live walk *because this plan removed it*, and criterion 1 scored exactly
/// that as a PASS in the same session.
///
/// **[camera] must already be at the arm's starting camera** -- in production,
/// R2's fitted camera, restored by the caller before every arm, because the
/// arms of a ratio must start from the same camera and this phase does not own
/// it.
///
/// **One arm is: purge, warm, hold, pan.** The purge is a two-frame scale
/// excursion that makes `TileCache.paintFrame` retire the generation and
/// dispose its tiles; the warm loop then rebuilds it from cold at the arm's own
/// camera. Both halves are necessary and the second alone is not enough: the
/// fitted camera and the pan path are identical in every arm by construction,
/// nothing evicts, and without the purge every arm after the first pans over
/// the tiles the previous arm's pan baked. The 2026-08-29 check run showed
/// exactly that -- `bakes=14 liveDraws=10` in the first arm and `bakes=0
/// liveDraws=0 blits=1600` in all three after it. `tilesAfterPurge` and
/// `warmBakes` are reported per arm so a reader can see which of the two an
/// arm actually got.
///
/// **No `_probeBake`, unlike [runTilePhases].** The probe reimplements the bake
/// geometry rather than calling `paintFrame`, so it cannot see
/// `debugFullViewportQuery` at all -- it would read bit-identical on both arms
/// while costing a full live walk, a walk per tile and a `toImageSync` per tile
/// in each of eighteen arms.
///
/// **No `settle()` either, and that is not an oversight.** Every frame this
/// phase pumps goes through one [FrameTimingLog], and a frame pumped outside
/// the log runs the reported stream ahead of the pumped one -- which is
/// precisely the shifted-ordinal condition [FrameTimingLog] refuses to publish
/// a figure from. The warm loop's own termination condition (a frame that
/// baked nothing) is the settle it would have been asking for.
Future<PanArmReport> runTilePanArm({
  required CameraController camera,
  required TileCache cache,
  required Future<void> Function() pumpFrame,
  required Offset panStep,
  int holdFrames = kTileHoldFrames,
  int panFrames = kTilePanFrames,
}) async {
  refuseDebugMode();
  final log = FrameTimingLog()..arm();
  try {
    // The caller's own pump just before this phase rasterises after its pump
    // returns, so its timing lands here and would take ordinal 0. See
    // [FrameTimingLog.establishBaseline].
    await log.establishBaseline(pumpFrame);

    // **The purge, and the first run without it proves it is load-bearing.**
    // Two frames at a scale the current generation cannot match, then back to
    // the arm's exact starting camera. `TileCache.paintFrame` retires a
    // generation whose grid fails `TileGrid.matchesScale` and disposes its
    // tiles, and there is no public way to ask it to do that directly.
    //
    // Without this, every arm after the first pans over tiles the *previous*
    // arm's pan baked: the fitted camera and the pan path are identical in
    // every arm by construction, the cache is nowhere near its capacity, so
    // nothing evicts and the second arm onwards bakes nothing at all. The
    // 2026-08-29 check run at 50,000 read `bakes=14 liveDraws=10 p95=14.01ms`
    // in the first arm and `bakes=0 liveDraws=0 blits=1600` -- a pure blit
    // parade -- in all three after it. That is the "one arm inherits the
    // previous arm's warm generation" failure exactly, and it makes the pan
    // measure the wrong thing in a way no test can see.
    //
    // The camera is restored by assignment to the value captured on entry, so
    // it is bit-identical to the arm's starting camera and not merely a zoom
    // round trip's `1.0000000000000018` away from it.
    final start = camera.value;
    cache.resetCounters();
    camera.zoomAt(Offset.zero, kPanArmPurgeZoom);
    await log.pump(pumpFrame);
    camera.value = start;
    await log.pump(pumpFrame);
    final tilesAfterPurge = cache.liveTileCount;

    // Warm: pump until the viewport is covered and nothing more bakes.
    // Bounded, and the bound is reported.
    //
    // **One frame that baked nothing is not a standstill, and reading it as
    // one stops the warm before it starts.** `kRestGateFrames` is 2, so a bake
    // needs two consecutive frames on the same camera; the purge's last frame
    // changed the camera, so the very first warm frame can only reach
    // `_restGateSteps == 1` and cannot bake whatever the cache holds. That is
    // Ruling 15's arithmetic, and the first version of this loop -- exit as
    // soon as `bakeCount` stops changing -- exited on exactly that frame,
    // reported `warmFrames=1 warmBakes=0` in all four arms of the 2026-08-29
    // re-check, and left the two boundary frames below to do the warming
    // where no counter attributes it. Coverage plus
    // [kPanArmWarmIdleFrames] consecutive non-baking frames is the condition
    // that cannot be met by a frame that was never allowed to bake.
    cache.resetCounters();
    var warmFrames = 0;
    var idleFrames = 0;
    while (warmFrames < kPanArmWarmMaxFrames) {
      final bakesBefore = cache.bakeCount;
      camera.panBy(Offset.zero);
      await log.pump(pumpFrame);
      warmFrames++;
      idleFrames = cache.bakeCount == bakesBefore ? idleFrames + 1 : 0;
      if (cache.viewportCovered && idleFrames >= kPanArmWarmIdleFrames) break;
    }
    final warmBakes = cache.bakeCount;

    /// Two throwaway frames at a phase boundary, pumped *inside* the log and
    /// excluded by ordinal: the same slack [runTilePhases]' own `phase()`
    /// helper takes, for the same reason -- a `FrameTiming` is reported after
    /// its frame rasterised, so the boundary needs frames the window does not
    /// count.
    Future<void> boundary() async {
      for (var i = 0; i < kZoomWarmUpFrames; i++) {
        camera.panBy(Offset.zero);
        await log.pump(pumpFrame);
      }
    }

    await boundary();
    final holdStart = log.pumpedFrames;
    cache.resetCounters();
    for (var i = 0; i < holdFrames; i++) {
      camera.panBy(Offset.zero);
      await log.pump(pumpFrame);
    }
    final holdBakes = cache.bakeCount;
    final holdLiveDraws = cache.liveDrawCount;

    await boundary();
    final panStart = log.pumpedFrames;
    cache.resetCounters();
    final evictionsBefore = cache.evictionCount;
    // A pan bakes in bursts -- a whole column of tiles enters at once -- so the
    // shape of the bake distribution decides whether a mean is a per-tile cost
    // or an average over two different frames. Reported, not assumed.
    var bakeFrames = 0;
    var maxBakesInAFrame = 0;
    var lastBakeCount = 0;
    for (var i = 0; i < panFrames; i++) {
      camera.panBy(panStep);
      await log.pump(pumpFrame);
      final delta = cache.bakeCount - lastBakeCount;
      lastBakeCount = cache.bakeCount;
      if (delta > 0) bakeFrames++;
      if (delta > maxBakesInAFrame) maxBakesInAFrame = delta;
    }
    // **Read before the drain, not after it.** The drain's frames are pumped
    // and they paint: a bare frame straight after a pan is a *non-moving*
    // frame, which is precisely the frame shape that runs the live fallback,
    // so counting it would add the drain's own live draws to a figure labelled
    // "over the pan" — and `liveDraws` is the counter that decides whether
    // this arm measured anything at all.
    final panBakes = cache.bakeCount;
    final panBlits = cache.blitCount;
    final panCarryOverBlits = cache.carryOverBlitCount;
    final panLiveDraws = cache.liveDrawCount;
    final panNewEvictions = cache.evictionCount - evictionsBefore;
    final liveTiles = cache.liveTileCount;
    final tileBytes = cache.liveBytes;

    // The last pan frames cannot have reported by the time their own pump
    // returned; without this their timings are absent, not late.
    //
    // **[kPanArmDrainFrames] and not [FrameTimingLog.drain]'s default of 4.**
    // `FrameTiming`s are delivered about every 100 ms in a profile build and
    // four frames at 60 Hz is 66 ms, so the default cannot span one batch: the
    // check run lost three to five pan frames in every arm and shouted SHORT
    // SAMPLE on all four. The zoom phase never saw this because its 30 idle
    // settle frames are its drain.
    await log.drain(pumpFrame,
        upTo: panStart + panFrames, maxExtraFrames: kPanArmDrainFrames);

    return PanArmReport(
      warmFrames: warmFrames,
      warmBakes: warmBakes,
      tilesAfterPurge: tilesAfterPurge,
      holdMs: log.msRange(holdStart, holdStart + holdFrames),
      holdBakes: holdBakes,
      holdLiveDraws: holdLiveDraws,
      panMs: log.msRange(panStart, panStart + panFrames),
      panBakes: panBakes,
      panBakeFrames: bakeFrames,
      panMaxBakesInAFrame: maxBakesInAFrame,
      panBlits: panBlits,
      panCarryOverBlits: panCarryOverBlits,
      panLiveDraws: panLiveDraws,
      panNewEvictions: panNewEvictions,
      liveTiles: liveTiles,
      tileBytes: tileBytes,
    );
  } finally {
    log.disarm();
  }
}

/// p50, p95, max and mean of a list of frame times, in [report]'s own format
/// and at [report]'s own quantiles.
String _msStats(List<double> ms) {
  var sum = 0.0;
  for (final v in ms) {
    sum += v;
  }
  final sorted = [...ms]..sort();
  return 'p50=${sorted[(sorted.length * 0.5).floor()].toStringAsFixed(2)}ms '
      'p95=${sorted[(sorted.length * 0.95).floor()].toStringAsFixed(2)}ms '
      'max=${sorted.last.toStringAsFixed(2)}ms '
      'mean=${(sum / sorted.length).toStringAsFixed(2)}ms';
}

/// Prints a [PanArmReport] under [label].
///
/// **Every line carries [label].** An interleaved run prints two arms per
/// repeat, the arms differ only in which flag was flipped, and a continuation
/// line indented under the wrong heading is a number attributed to the wrong
/// arm. That is the failure mode this whole measurement has already been
/// bitten by.
///
/// **The `liveDraws=0` warning is Ruling 21 caught by the instrument itself.**
/// `debugFullViewportQuery` widens the live fallback's query and nothing else,
/// so an arm whose pan never ran the fallback ran byte-identical code to its
/// counterpart whatever its label said, and any ratio formed from the pair is
/// 1.00 by construction. The eighteen arms of the degenerate run would have
/// said so on every line.
void printPanArmReport(String label, PanArmReport r) {
  print('$label arm start: tilesAfterPurge=${r.tilesAfterPurge} '
      'warmFrames=${r.warmFrames} warmBakes=${r.warmBakes} '
      '(the camera and generation this arm holds and pans from; a working '
      'purge reads 0 tiles and then warms from cold)');
  if (r.tilesAfterPurge > 0 || r.warmBakes == 0) {
    print('$label   !!! WARNING: this arm did not start from a purged cache '
        '(tilesAfterPurge=${r.tilesAfterPurge}, warmBakes=${r.warmBakes}). It '
        "is panning over tiles an earlier arm baked, so its pan blits where "
        'the measurement expects it to bake, and its figures are not '
        "comparable with an arm that started cold !!!");
  }

  if (r.holdFrameMs.isEmpty) {
    print('$label tile hold: no frames recorded');
  } else {
    print('$label tile hold frames=${r.holdFrameMs.length} '
        '${_msStats(r.holdFrameMs)} '
        "(CONTROL: Plan 3h's M4 cannot touch a phase with no live fallback, "
        'so a systematic arm-to-arm difference here is session drift)');
  }
  print('$label   hold bakes=${r.holdBakes} liveDraws=${r.holdLiveDraws}');

  if (r.panFrameMs.isEmpty) {
    print('$label tile pan: no frames recorded');
  } else {
    print('$label tile pan frames=${r.panFrameMs.length} '
        '${_msStats(r.panFrameMs)} '
        "(criterion 8's statistic is this p95, the same statistic Plan 3h's "
        'criterion 3 was scored on)');
  }
  print(
      '$label   pan bakeFrames=${r.panBakeFrames}/${r.panFrameMs.length + r.panFramesMissing} '
      'maxBakesInAFrame=${r.panMaxBakesInAFrame} '
      'bakes=${r.panBakes} '
      'blits=${r.panBlits} '
      'carryOverBlits=${r.panCarryOverBlits} '
      'liveDraws=${r.panLiveDraws} '
      'newEvictions=${r.panNewEvictions} '
      'liveTiles=${r.liveTiles} '
      'tileBytes=${r.tileBytes}');

  if (r.panLiveDraws == 0) {
    print('$label   !!! WARNING: liveDraws=0 over the pan. '
        'debugFullViewportQuery modifies the live fallback\'s query extent and '
        'NOTHING else, so an arm whose pan never ran the fallback measured the '
        'same code as its counterpart and any ratio formed from the pair is '
        '1.00 by construction. This is Ruling 21, and this arm is DEGENERATE '
        '!!!');
  }
  final missing = r.holdFramesMissing + r.panFramesMissing;
  if (missing > 0) {
    print('$label   !!! WARNING: $missing frame(s) reported no FrameTiming '
        '(hold ${r.holdFramesMissing}, pan ${r.panFramesMissing}) -- the '
        'figures above are over a SHORT SAMPLE and are not comparable !!!');
  }
}
