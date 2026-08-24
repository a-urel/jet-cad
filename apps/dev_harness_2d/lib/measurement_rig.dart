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
/// Shared rather than copied, because copying it is how R4a and R4b came to
/// keep the canvas-only form after R2's was fixed.
void requireRepaint(CanvasDrawSink sink, VerticesDrawSink? vertices) {
  // The counters above are read from a frame that has to actually have
  // happened. `panBy(Offset.zero)` forces one only because Transform2 has no
  // operator== for ValueNotifier to dedupe against -- a property these rigs
  // depend on and do not own. If that ever changes, a rig would print a
  // plausible-looking zero rather than fail, and a zero is the one wrong
  // number nobody questions.
  if (sink.canvasCallCount + (vertices?.totalFlushCount ?? 0) == 0) {
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
  print('  screenSpaceLeafCount=${painter.screenSpaceLeafCount} '
      'dashSpans=${painter.dashSpanCount} '
      'collapsed=${painter.collapsedDashCount} '
      'canvasCalls=${sink.canvasCallCount}');
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
void printTileCounters(TileCache? cache) {
  if (cache == null) {
    print('  tiles=off');
    return;
  }
  print('  tiles=on tilePx=${cache.tileDevicePixels} '
      'bakePerFrame=${cache.tilesBakedPerFrame} '
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
      'drawVerticesCalls=${vertices.totalFlushCount}');
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
      'evictions=${cache.evictionCount}(life)');

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
  }

  await phase('tile hold', 60, Offset.zero);
  await phase('tile pan', 120, const Offset(-7, -3));
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
