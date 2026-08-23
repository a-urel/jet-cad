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

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
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
    ms.sort();
    return 'p50=${ms[(ms.length * 0.5).floor()].toStringAsFixed(2)}ms '
        'p95=${ms[(ms.length * 0.95).floor()].toStringAsFixed(2)}ms '
        'max=${ms.last.toStringAsFixed(2)}ms';
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
void printInvariants(DraftPainter painter, CanvasDrawSink sink) {
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
  required Future<void> Function() pumpFrame,
  required Future<void> Function() settle,
}) async {
  refuseDebugMode();
  final timings = <FrameTiming>[];
  void collect(List<FrameTiming> t) => timings.addAll(t);
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
    printInvariants(painter, sink);
    printBackend(resolvedBackend, vertices);
    printTextCounters(painter, sink,
        textCorpus: textCorpus,
        drawText: drawText,
        layoutsBefore: layoutsBefore,
        paragraphEvictionsBefore: paragraphEvictionsBefore,
        metricsEvictionsBefore: metricsEvictionsBefore);
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(collect);
  }
}
