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
/// Shared rather than copied, because copying it is how R4a and R4b came to
/// keep the canvas-only form after R2's was fixed.
void requireRepaint(CanvasDrawSink sink, VerticesDrawSink? vertices,
    {TileCache? tileCache}) {
  // The counters above are read from a frame that has to actually have
  // happened. `panBy(Offset.zero)` forces one only because Transform2 has no
  // operator== for ValueNotifier to dedupe against -- a property these rigs
  // depend on and do not own. If that ever changes, a rig would print a
  // plausible-looking zero rather than fail, and a zero is the one wrong
  // number nobody questions.
  final drew = sink.canvasCallCount +
      (vertices?.totalFlushCount ?? 0) +
      (tileCache?.blitCount ?? 0) +
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
    for (var i = 0; i < 120; i++) {
      camera.zoomAt(const Offset(800, 600), i.isEven ? 1.03 : 0.97);
      await pumpFrame();
    }
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
    final layoutsBefore = sink.measurer.layoutCount;
    final paragraphEvictionsBefore = sink.measurer.paragraphEvictionCount;
    final metricsEvictionsBefore = sink.measurer.metricsEvictionCount;
    camera.panBy(Offset.zero);
    await pumpFrame();
    report('R2 ($entities)', timings);
    print('  lineweightScale=$lineweightScale');
    requireRepaint(sink, vertices);
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

  await phase('tile hold', 60, Offset.zero);
  // `PAN_STEP` unset leaves the historical step untouched -- see `kPanStep`.
  const historical = Offset(-7, -3);
  final magnitude = historical.distance;
  final step = panStep.isNaN
      ? historical
      : Offset(historical.dx * panStep / magnitude,
          historical.dy * panStep / magnitude);
  print('  tile pan step: dx=${step.dx.toStringAsFixed(4)} '
      'dy=${step.dy.toStringAsFixed(4)} '
      'magnitude=${step.distance.toStringAsFixed(4)}');
  await phase('tile pan', 120, step);
  _probeBake(cache, camera, painter, sink, vertices);
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

/// Warns, loudly, when the window a caller is about to run [runTileZoomPhase]
/// against is not [pinned] -- the 1600x1200 logical reference every number in
/// design spec §5, and every figure in this plan's measurement notes, is
/// priced against.
///
/// **A warning, not a throw.** [runTileZoomPhase] accepts any finite viewport
/// and still produces a report -- refusing to run would trade a labelled
/// number for no number at all, which is worse for an operator mid-session
/// than a number they have to read the label on. Before this check, the only
/// way to notice a mismatch was the unrelated `R2 app-run: window=...` print
/// upstream -- easy to have scrolled past by the time the zoom arm's numbers
/// print. This check sits at the call site itself, so the warning lands right
/// next to the numbers it is warning about.
void warnIfZoomViewportMismatch(Size real, Size pinned) {
  if (real == pinned) return;
  print('  !!! WARNING: tile zoom phase run at window='
      '${real.width.toStringAsFixed(0)}x${real.height.toStringAsFixed(0)}, '
      'not the pinned reference ${pinned.width.toStringAsFixed(0)}x'
      '${pinned.height.toStringAsFixed(0)} -- the numbers below are measured '
      'at the WRONG VIEWPORT and are not comparable to design spec §5 or to '
      'any run at the pinned size !!!');
}

/// What [runTileZoomPhase] reports: the gesture's frame times and the
/// cache's counters over it, then the settle that follows.
class ZoomReport {
  ZoomReport({
    required this.gestureFrameMs,
    required this.gestureBakes,
    required this.gestureLiveDraws,
    required this.settleMs,
    required this.settleFrames,
  });

  /// `totalSpan`, one entry per gesture frame -- 80 entries at the pinned
  /// script (`2 * kZoomSteps`). p95 over this list is criterion 2.
  final List<double> gestureFrameMs;

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

  /// `totalSpan` of the one idle frame at which [TileCache.viewportCovered]
  /// first became true, or of the last idle frame pumped if 30 idle frames
  /// never reached coverage. Criterion 3 reads this.
  final double settleMs;

  /// How many idle frames elapsed before [TileCache.viewportCovered] first
  /// read true (1 if the very first idle frame after the gesture already
  /// covers, which is what criterion 3 asserts), or 30 if coverage was never
  /// reached within the pinned idle-frame budget.
  final int settleFrames;
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
/// it into a screen-space anchor the same way `runR2Rig`'s own zoom step
/// anchors at the fixed `Offset(800, 600)` (that phase's viewport centre)
/// regardless of what window the app is actually running in. A caller on a
/// real window of a different size gets a phase that still runs -- `zoomAt`
/// accepts any finite, positive factor at any screen point -- but the
/// focal point then sits at a different fraction of the *real* viewport than
/// 30%/70%, and comparing its numbers against another run's figures, or
/// against the design spec's priced predictions, is only sound once the
/// window is confirmed to actually be the reference size. `main.dart`'s
/// `RUN_R2` mode prints the real window size for exactly this reason; a
/// caller of this phase should do the same.
///
/// The idle frames drive no camera change at all -- unlike the forced
/// no-op `panBy(Offset.zero)` this file's other phases use to force a final
/// repaint once nothing is dirty, an idle frame here is a bare [pumpFrame]
/// call. `DraftCanvasState`'s own settle notifier
/// (`draft_canvas.dart:_requestSettleFrame`) is what keeps requesting a real
/// frame for as long as the cache owes tiles; forcing one artificially would
/// measure a phase this rig does not actually drive on a real trackpad
/// gesture's tail.
Future<ZoomReport> runTileZoomPhase({
  required CameraController camera,
  required TileCache cache,
  required Future<void> Function() pumpFrame,
  required Size viewport,
}) async {
  refuseDebugMode();
  final focus = zoomFocusFor(viewport);

  // Two throwaway frames before the counters reset, the same boundary slack
  // `runTilePhases`'s own `phase()` helper takes: a `FrameTiming` is reported
  // after its frame rasterises, so the phase boundary needs a frame or two of
  // slack the gesture itself must not be charged for.
  for (var i = 0; i < 2; i++) {
    camera.panBy(Offset.zero);
    await pumpFrame();
  }

  final gestureTimings = <FrameTiming>[];
  void collectGesture(List<FrameTiming> t) => gestureTimings.addAll(t);
  SchedulerBinding.instance.addTimingsCallback(collectGesture);
  // Warm-up excluded: reset only after the fitted camera has settled (the
  // two throwaway frames above), per §5.
  cache.resetCounters();
  try {
    for (var i = 0; i < kZoomSteps; i++) {
      camera.zoomAt(focus, kZoomFactor);
      await pumpFrame();
    }
    for (var i = 0; i < kZoomSteps; i++) {
      camera.zoomAt(focus, 1 / kZoomFactor);
      await pumpFrame();
    }
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(collectGesture);
  }
  final gestureBakes = cache.bakeCount;
  final gestureLiveDraws = cache.liveDrawCount;
  final gestureFrameMs = [
    for (final t in gestureTimings) t.totalSpan.inMicroseconds / 1000.0
  ];

  // 30 idle frames. No camera nudge -- see the doc comment above for why a
  // bare pumpFrame is the honest idle frame here. Tracks the first frame at
  // which the viewport becomes covered, which is what criterion 3 reads;
  // still pumps the full 30 so a cache that keeps asking for frames after
  // coverage (which it must not) is exercised the same way a real trackpad
  // gesture's tail would exercise it.
  const idleFrames = 30;
  var settleFrames = idleFrames;
  var settleMs = 0.0;
  var covered = false;
  for (var i = 0; i < idleFrames; i++) {
    final idleTimings = <FrameTiming>[];
    void collectIdle(List<FrameTiming> t) => idleTimings.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(collectIdle);
    try {
      await pumpFrame();
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(collectIdle);
    }
    final frameMs = idleTimings.isEmpty
        ? 0.0
        : idleTimings.last.totalSpan.inMicroseconds / 1000.0;
    if (!covered && cache.viewportCovered) {
      covered = true;
      settleFrames = i + 1;
      settleMs = frameMs;
    } else if (!covered) {
      // Not yet covered: keep the running "last frame pumped" figure, so a
      // script that never reaches coverage within the idle budget still
      // reports something rather than 0.0.
      settleMs = frameMs;
    }
  }

  return ZoomReport(
    gestureFrameMs: gestureFrameMs,
    gestureBakes: gestureBakes,
    gestureLiveDraws: gestureLiveDraws,
    settleMs: settleMs,
    settleFrames: settleFrames,
  );
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
  print('  gestureBakes=${r.gestureBakes}(tiles, budgeted path) '
      'gestureLiveDraws=${r.gestureLiveDraws}');
  print('  settleFrames=${r.settleFrames} '
      'settleMs=${r.settleMs.toStringAsFixed(2)}');
}
