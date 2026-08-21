// A measurement harness, not a product.
//
// Pointer pan and scroll zoom go straight to `CameraController`. There is no
// tool architecture and no selection, because tools are Plan 4 and every line
// here is a line the rigs have to keep working.

// ignore_for_file: avoid_print — the RUN_R2 diagnostics below print by
// design; see `measurement_rig.dart`.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import 'measurement_rig.dart';

/// Entity count, so one binary serves both corpus sizes.
const int kEntities = int.fromEnvironment('ENTITIES', defaultValue: 50000);

/// Multiplies every stroke's device-pixel width at the sink.
///
/// **Measurement-only**, added for Task 4c's fill-rate experiment (B):
/// geometry, draw-call count and the walk are unchanged across a run at 1x,
/// 2x or 4x — only the number of shaded pixels changes. There is no
/// `double.fromEnvironment` in Dart, so this parses the string define at
/// startup rather than being a compile-time constant. Inert at its default
/// of 1.0.
final double kLineweightScale = double.tryParse(
      const String.fromEnvironment('LINEWEIGHT_SCALE', defaultValue: '1.0'),
    ) ??
    1.0;

/// Whether the corpus carries text, and whether the painter draws it.
///
/// Two defines, not one, because they answer different questions.
/// `TEXT=1` changes the *document* — it turns `labelFraction` and
/// `attributedInstanceFraction` on, which changes the entity mix, the extents
/// and therefore the camera, so an R2 run with it on is **not** comparable to
/// Plan 3b's baselines and must be reported as its own row.
/// `DRAW_TEXT=0` changes one branch in the painter and nothing else, which is
/// what makes the text-on/text-off delta readable as the cost of text rather
/// than as the difference between two drawings.
///
/// Both are inert at their defaults: with `TEXT` unset the document is
/// byte-for-byte the one Plan 3b measured, and `DRAW_TEXT` has nothing to act
/// on.
/// The fraction of entities carrying the dashed linetype.
///
/// The dash/leaf separation experiment: `dashSpans` and `screenSpaceLeafCount`
/// move together in this corpus (x1.293 against x1.304 from 10,000 to 50,000
/// entities), so no run so far can tell "cost per drawn leaf" from "cost per
/// dash span" apart. This define holds the geometry still and moves only the
/// linetype, which is the one thing that separates them.
///
/// It is sound as a control because `_Styling.linetypeFor` is a quota counter,
/// not a draw from the corpus's random stream: changing this fraction cannot
/// perturb a single coordinate, so extents, camera and leaf count are
/// unchanged. The one thing it does change is that `generateDocument` seeds
/// the dashed `LinetypeRecord` only when the fraction is positive, so at 0
/// every later handle shifts down by one -- relative draw order, and therefore
/// what is drawn, is the same. That the control held is *measured*, not
/// assumed: the two runs must report the same `screenSpaceLeafCount`.
///
/// There is no `double.fromEnvironment`, so this parses a string define the
/// same way [kLineweightScale] does. Inert at its default of 0.35, which is
/// the value every run before this one used.
final double kDashedFraction = double.tryParse(
      const String.fromEnvironment('DASHED', defaultValue: '0.35'),
    ) ??
    0.35;

const bool kTextCorpus = bool.fromEnvironment('TEXT');
const bool kDrawText = bool.fromEnvironment('DRAW_TEXT', defaultValue: true);

/// Which sink the harness draws through: `canvas`, `vertices`, or unset for
/// the platform's own choice.
///
/// **A `String.fromEnvironment`, and it stays one.** Plan 3c lost a full device
/// run to `bool.fromEnvironment('TEXT')` reading `--dart-define=TEXT=1` as
/// false while printing entirely plausible numbers; the only thing that caught
/// it was a line printing `corpus=on/off`. A string has no such hazard, and an
/// unrecognised value throws at startup rather than falling back to something
/// that looks fine.
final RenderBackend? kBackend =
    switch (const String.fromEnvironment('BACKEND', defaultValue: '')) {
  '' => null,
  'canvas' => RenderBackend.canvas,
  'vertices' => RenderBackend.vertices,
  final other =>
    throw StateError('BACKEND must be canvas, vertices or unset; got "$other"'),
};

/// The corpus the rigs measure on: the same shape as R1's, so the two sets of
/// numbers describe one drawing.
///
/// With [kTextCorpus] on this is `textRigCorpus`'s shape, and the measurer
/// stops being a detail: `DraftDocument`'s default is the zero-metrics
/// `InsertionPointMeasurer`, which collapses every glyph box to a point and
/// every text transform to a singular matrix. A text corpus built on it looks
/// like a text corpus and draws nothing measurable.
DraftDocument harnessDocument([int? entityCount]) => generateDocument(
      entityCount ?? kEntities,
      definitionCount: 200,
      instanceCount: 20000,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 50,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: kDashedFraction,
      labelFraction: kTextCorpus ? 0.02 : 0,
      attributedInstanceFraction: kTextCorpus ? 0.2 : 0,
      measurer:
          kTextCorpus ? FlutterTextMeasurer() : const InsertionPointMeasurer(),
    );

/// Whether `main()` drives R2 itself on startup and prints its block,
/// instead of waiting to be driven by `integration_test`.
///
/// Task 13's web row needed `flutter drive -d chrome`, and that hangs in
/// this environment before it ever reaches chromedriver — see the Task 13
/// report. `flutter run -d chrome` forwards the app's own `print()` output
/// to the terminal once its debug service links, so this mode drives the
/// rig itself and gets the same block without any driver.
///
/// **Caveat found while measuring, not assumed**: in this environment,
/// `flutter run -d chrome --profile` never printed "Waiting for connection
/// from debug service on Chrome..." and never linked one, so this mode's own
/// `print()` output never reached the terminal in profile mode — only debug
/// mode linked reliably, and debug numbers are exactly what
/// `refuseDebugMode()` inside `runR2Rig` refuses to record. The Task 13
/// report used the Chrome DevTools Protocol directly (reading a value the
/// app wrote to `window.localStorage`, a temporary addition not part of this
/// commit) to get profile-mode numbers out despite that gap; that retrieval
/// path is not shipped here because it is investigation plumbing for one
/// environment's limitation, not shared measurement code. A future
/// environment where profile mode links normally would use this mode as
/// written, watching the terminal directly.
///
/// Same footgun as [kTextCorpus], same rule: a `bool.fromEnvironment` reads
/// anything other than exactly `"true"` as false, so `--dart-define=RUN_R2=1`
/// silently runs the ordinary interactive harness instead. Always pass
/// `=true`.
///
/// Inert at its default of `false`: an ordinary `flutter run`/`flutter
/// drive` harness invocation is unaffected.
const bool kRunR2 = bool.fromEnvironment('RUN_R2');

void main() {
  final doc = harnessDocument();
  if (!kRunR2) {
    runApp(HarnessApp(document: doc));
    return;
  }
  runApp(HarnessApp(
    document: doc,
    onReady: (camera, index, painter, sink, vertices, resolvedBackend) {
      unawaited(
          _driveR2(doc, camera, painter, sink, vertices, resolvedBackend));
    },
  ));
}

/// Fits the camera to the same working-set window `boot()` in
/// `integration_test/frame_timing_test.dart` uses — not the widget's own
/// full-extents fit, which would measure a frame nobody renders — then runs
/// [runR2Rig] the same way the widget test does, driven by real frames
/// instead of a synthetic test clock.
///
/// The viewport this fits *into* is whatever logical size the browser window
/// actually is when this runs, unlike the widget test's fixed synthetic
/// view. That size is printed so a reader can judge comparability against
/// the desktop rows rather than assume it.
Future<void> _driveR2(
  DraftDocument doc,
  CameraController camera,
  DraftPainter painter,
  CanvasDrawSink sink,
  VerticesDrawSink? vertices,
  RenderBackend resolvedBackend,
) async {
  print('R2 app-run: driving started');
  final e = doc.extents;
  final cx = (e.minX + e.maxX) / 2;
  final cy = (e.minY + e.maxY) / 2;
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final viewport = view.physicalSize / view.devicePixelRatio;
  camera.value = ViewportTransform.fit(
      Aabb2(Vector2(cx - 1500, cy - 1125), Vector2(cx + 1500, cy + 1125)),
      viewport);
  await _pumpFrame();

  print('R2 app-run: window=${viewport.width.toStringAsFixed(0)}x'
      '${viewport.height.toStringAsFixed(0)} dpr=${view.devicePixelRatio}');

  await runR2Rig(
    entities: kEntities,
    lineweightScale: kLineweightScale,
    textCorpus: kTextCorpus,
    drawText: kDrawText,
    camera: camera,
    painter: painter,
    sink: sink,
    vertices: vertices,
    resolvedBackend: resolvedBackend,
    pumpFrame: _pumpFrame,
    settle: _settle,
  );
  print('R2 app-run: done');
}

/// Renders exactly one frame and completes after it.
///
/// This is called from inside `_HarnessAppState`'s own post-frame callback —
/// [SchedulerBinding.instance.schedulerPhase] is `postFrameCallbacks`, not
/// `idle`, at that point, and [SchedulerBinding.endOfFrame] only calls
/// [SchedulerBinding.scheduleFrame] for you when the phase is idle. Relying
/// on `camera.value = ...`'s listener chain to schedule the next frame as a
/// side effect worked on the first call by chance and hung on every one
/// after it, once the phase genuinely was idle and nothing else nearby
/// happened to call `scheduleFrame`. Calling it explicitly first removes the
/// dependency on that side effect entirely.
Future<void> _pumpFrame() {
  SchedulerBinding.instance.scheduleFrame();
  return SchedulerBinding.instance.endOfFrame;
}

/// A running app has no synthetic clock to advance, so there is no exact
/// equivalent of `tester.pumpAndSettle()`. This pumps frames while one is
/// still scheduled, bounded, which is the same loop `pumpAndSettle` runs
/// internally minus its own timeout — the closest honest approximation
/// available outside a test.
Future<void> _settle() async {
  const maxIdlePumps = 10;
  for (var i = 0; i < maxIdlePumps; i++) {
    if (!SchedulerBinding.instance.hasScheduledFrame) return;
    await _pumpFrame();
  }
}

class HarnessApp extends StatefulWidget {
  const HarnessApp({super.key, required this.document, this.onReady});

  final DraftDocument document;

  /// Handed the pieces a rig needs to drive: the camera it scripts, the
  /// index whose rebuild count it reports, and the painter and sink whose
  /// counters it reads.
  ///
  /// Fired after the first frame, not from `initState` — the painter and
  /// sink belong to `DraftCanvasState`, a descendant whose own `initState`
  /// has not run yet when this widget's has.
  ///
  /// [vertices] is non-null only when [resolvedBackend] is
  /// `RenderBackend.vertices`; a rig reads its batch and flush counters the
  /// same way it reads the painter's. [resolvedBackend] is what
  /// `DraftCanvasState` actually built, not what [kBackend] asked for.
  final void Function(
      CameraController camera,
      SpatialIndex index,
      DraftPainter painter,
      CanvasDrawSink sink,
      VerticesDrawSink? vertices,
      RenderBackend resolvedBackend)? onReady;

  @override
  State<HarnessApp> createState() => _HarnessAppState();
}

class _HarnessAppState extends State<HarnessApp> {
  late final SpatialIndex index = SpatialIndex(widget.document);
  late final CameraController camera = CameraController(
      ViewportTransform.fit(widget.document.extents, const Size(1600, 1200)));
  final GlobalKey<DraftCanvasState> _canvasKey = GlobalKey<DraftCanvasState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final canvasState = _canvasKey.currentState!;
      widget.onReady?.call(camera, index, canvasState.painter, canvasState.sink,
          canvasState.vertices, canvasState.resolvedBackend);
    });
  }

  @override
  void dispose() {
    index.dispose();
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Listener(
            onPointerMove: (event) {
              if (event.buttons != 0) camera.panBy(event.delta);
            },
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent) return;
              // 1.1 per notch, in the direction the wheel turned. Scroll up is
              // negative dy on every platform Flutter reports.
              camera.zoomAt(event.localPosition,
                  event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
            },
            child: DraftCanvas(
                key: _canvasKey,
                document: widget.document,
                index: index,
                camera: camera,
                lineweightScale: kLineweightScale,
                drawText: kDrawText,
                backend: kBackend),
          ),
        ),
      );
}
