// ignore_for_file: avoid_print -- the GSPIKE diagnostics below print by
// design; see `measurement_rig.dart`.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'measurement_rig.dart';

// --- The GPU arm: painter vs. tiles vs. jet_cad_2d_flutter's resident-GPU
// backend, interleaved. -----------------------------------------------
//
// Formerly `gpu_arm.dart` and `gpu_arm_rig.dart` (branch
// `spike/flutter-gpu-backend`), which hand-rolled a collector and their own
// `flutter_gpu` plumbing to answer one question: can a pan or a zoom cost a
// uniform write instead of a document walk, and still draw sharp? Plan A
// (`docs/superpowers/plans/2026-08-29-gpu-backend-plan-a-seam-and-strokes.md`)
// answered it by building the collector, the upload and the frame path as
// real package code -- `GeometryCollector`, `ResidentGeometry.create`,
// `GpuDrawBackend`, all from `package:jet_cad_2d_flutter` -- and Task 9
// deleted the spike's two files in the same commit that pointed this arm at
// them. What remains here is harness-side glue only: the widget that hosts
// the backend and turns its output into a `ui.Image` on the canvas, and the
// three-arm phase rig `runGpuSpike` drives -- unchanged in shape from the
// spike, because interleaving three arms over a hold, a pan and a zoom is
// measurement methodology, not backend-specific.
//
// **What arm C (the resident backend) still does not draw, and why that is
// not a bug in this harness.** `GeometryCollector` implements `polyline`
// (with joins), `point`, `circle` and `arc` (flattened, seam join included
// on a closed sweep) -- Plan B's job, done -- since Plan C it also shades
// dash patterns per fragment, dashed arcs included, since Plan D it draws
// `fillPolygon` and `fillCircle` too: one pre-triangulated instance per
// triangle, or per fan slice at the outline's own step count, in the fill
// kind (`kKindFill`) the shader's third branch reads, and since Plan E it
// draws `text` too -- resident labels the vertex shader positions from a
// per-frame uniform, and any label a later stroke covers goes through a
// per-label "patch": a small offscreen render of just that label and the
// instances found to cover it (`classifyTextPatches`), composited back after
// the main pass so the covering geometry still wins. `DRAW_TEXT=false` is
// now the criterion-11 control -- see the `GSPIKE note` line below for how
// many patches this corpus carries. **What arm C still does not draw is
// nothing** -- every op `DraftPainter` emits, this collector turns into
// resident geometry. What remains unwired into this harness is
// `DraftCanvas`'s own tiled/blit path drawing *through* this backend rather
// than beside it, which is Plan F's job, not a gap in what the backend
// itself can draw.
//
// **Whether the harness corpus itself carries fills is a separate question
// from whether the collector can draw them, and `SPIKE_FILLS` is that
// switch.** `spikeDocument()` in `main.dart` calls `_addFillRegions` only
// when `SPIKE_FILLS=true`; at its default of `false` the corpus is exactly
// what it was before Plan D, so every number taken before this knob existed
// stays reproducible. On, it adds closed-polyline rooms in the same
// `kFillFraction` proportion `FILLS=true` already uses for the R2 corpus,
// roughly 40% of them filled and the rest boundary-only, so the picture shows
// both the fillable-and-filled and the fillable-but-not path.
//
// **The buffer is collected once, at the arm's starting camera, and never
// re-walked.** Since Plan C that costs less than it used to, and the reason
// is worth stating precisely, because the sentence this comment used to
// carry was wrong.
//
// It said baked dash spans "stretch under zoom". They do not, and neither
// does the reference: `DraftPainter._dashScale` folds in
// `toScreen.scaleMagnitude` and the points it dashes are already in screen
// space, so period and distance scale together and **the number of dashes
// along an entity does not move with the camera at all**. Dash patterns are
// anchored in world space. Plan C measured that three ways (see
// `docs/superpowers/notes/2026-08-31-plan-c-results.md`).
//
// What baking a dash pattern actually froze was the **collapse** decision.
// `kDashCollapsePx` is a screen-space threshold, so whether a pattern draws
// solid depends on the live camera; a buffer that decided it once at
// collection time drew dashes where the reference had collapsed to solid, or
// the reverse. Plan C moved that branch into the vertex shader, where it is
// re-decided every frame from one uniform.

/// The three arms.
enum GpuSpikeArm {
  /// Today's untiled path: the whole document walked per frame into one
  /// `drawVertices`.
  painter,

  /// Today's *gesture* path, and the one that matters: Plan 3i's tile cache,
  /// which answers a moving frame by blitting the previous generation's
  /// composite, magnified. Cheap and blurry.
  tiled,

  /// `jet_cad_2d_flutter`'s resident-GPU backend: the geometry uploaded once,
  /// the camera a per-frame uniform, one instanced draw call. Sharp, and the
  /// question is what it costs -- and, on a device for the first time here,
  /// whether it draws the right picture at all.
  gpu;

  String get label => switch (this) {
        GpuSpikeArm.painter => 'A painter (untiled)',
        GpuSpikeArm.tiled => 'B tiles (blit)',
        GpuSpikeArm.gpu => 'C residentGpu (jet_cad_2d_flutter)',
      };
}

/// One phase's timings, in milliseconds.
class GpuPhaseReport {
  GpuPhaseReport(this.arm, this.phase, this.build, this.raster, this.submits,
      {this.unalignedExcess = 0,
      this.patchesRendered = 0,
      this.patchesClipped = 0,
      this.patchesOffscreen = 0});

  final GpuSpikeArm arm;
  final String phase;
  final List<double> build;
  final List<double> raster;

  /// GPU frames arm C submitted during the phase. Zero on a hold is the arm
  /// working: nothing changed, so nothing was re-rendered.
  final int submits;

  /// Web only: how far the reported-frame count ran ahead of the pumped count.
  /// Zero means the stream never shifted and the figures are aligned after
  /// all. Anything else is the size of the ordinal ambiguity.
  final int unalignedExcess;

  /// [GpuDrawBackend.patchesRendered]/`patchesClipped`/`patchesOffscreen`,
  /// read right after the phase -- so these describe the phase's **last
  /// frame only**, not a sum or an average over it, the same way `submits`
  /// is the only per-phase figure that is a genuine total. Zero on every arm
  /// but `gpu`, and zero on arm `gpu` too whenever `SPIKE_TEXT` is off or the
  /// corpus's labels are not covered by anything at this phase's camera.
  final int patchesRendered;
  final int patchesClipped;
  final int patchesOffscreen;
}

/// Every line the rig prints, kept so the run can also *show* them.
///
/// **This exists because `print` is not readable on the web.** A dart2js
/// profile build sends `print` to the browser console, which `flutter run`
/// does not forward to its stdout, so a web run posts its numbers where no
/// terminal can see them. Rendering the report into the widget tree makes one
/// screenshot the readable artefact on every platform, which is also what the
/// native runs already had for free. Not this task's platform -- Plan G owns
/// web -- but harmless to keep, and it doubles as the on-screen readout a
/// macOS run's screenshot can show alongside the picture.
final ValueNotifier<List<String>> gpuReportLines =
    ValueNotifier<List<String>>(const <String>[]);

void gpuReport(String line) {
  print(line);
  gpuReportLines.value = <String>[...gpuReportLines.value, line];
}

String gpuStats(List<double> ms) {
  if (ms.isEmpty) return 'NO FRAMES';
  final sorted = [...ms]..sort();
  var sum = 0.0;
  for (final v in sorted) {
    sum += v;
  }
  return 'p50=${sorted[(sorted.length * 0.5).floor()].toStringAsFixed(2)} '
      'p95=${sorted[(sorted.length * 0.95).floor()].toStringAsFixed(2)} '
      'max=${sorted.last.toStringAsFixed(2)} '
      'mean=${(sum / sorted.length).toStringAsFixed(2)} (ms, n=${ms.length})';
}

/// Draws a [GpuDrawBackend] into the widget tree, once per frame, through the
/// image its `render` returns.
///
/// **The render happens in `paint`, not in a callback that schedules another
/// frame.** A two-frame arrangement would put the GPU submit in one frame's
/// numbers and the composite in the next, and neither figure would be the
/// cost of a gesture frame. Here `FrameTiming.buildDuration` covers the
/// uniform write and the submit, and `rasterDuration` covers the composite --
/// the same split every other arm in this harness is read with.
class GpuArmPainter extends CustomPainter {
  GpuArmPainter({
    required this.backend,
    required this.camera,
    required this.devicePixelRatio,
  }) : super(repaint: camera);

  final GpuDrawBackend backend;
  final CameraController camera;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    // **Ownership of the images `backend.paint` records, spelled out.**
    // `GpuDrawBackend.paint` calls `render` for the main image, exactly as
    // this method used to call it directly, and -- since Plan E -- builds one
    // more `ui.Image` per covered label from that frame's patch textures. All
    // of them are fresh Dart-side handles over GPU textures the backend
    // itself owns and reuses across frames (the main render target, and each
    // patch's own, resized only when the geometry that needs it changes);
    // none of these calls allocate a new texture. Every handle is recorded
    // into the `Picture` this `paint` call builds -- the compositor's own
    // `drawImageRect` calls, one per image -- so the picture is what needs
    // each one to stay alive, for as long as the raster thread takes to
    // consume it, which outlives this function returning. Neither this
    // method nor `GpuDrawBackend.paint` disposes any of them -- doing so here,
    // before the picture rasterises, would race the very thing that still
    // needs them (**Controller ruling R6-2**, in force). Not disposing leaves
    // each handle to the same lifetime the engine already manages for any
    // image recorded into a picture: it is reclaimed once Dart's GC collects
    // that `ui.Image` wrapper, no earlier than the frame that recorded it has
    // rasterised. Over this harness's measured run that is now up to `1 + P`
    // short-lived per-frame handles per camera-changed frame, where `P` is
    // this frame's patch count, instead of one -- that is a real, accepted
    // GC-pressure cost of a measurement widget creating these images per
    // frame, not a leak, and not a claim about the package's own frame-path
    // allocation budget (CLAUDE.md's non-negotiable governs
    // `jet_cad_2d_flutter`'s frame path, which this ad hoc harness
    // `CustomPainter` is not part of). Task 9 measures the churn this adds.
    backend.paint(canvas, camera.value, size, devicePixelRatio);
  }

  @override
  bool shouldRepaint(GpuArmPainter oldDelegate) =>
      oldDelegate.backend != backend ||
      oldDelegate.camera != camera ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}

/// The GPU arm as a widget: one `CustomPaint` over a repaint boundary.
class GpuArmView extends StatelessWidget {
  const GpuArmView({
    super.key,
    required this.backend,
    required this.camera,
  });

  final GpuDrawBackend backend;
  final CameraController camera;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: GpuArmPainter(
            backend: backend,
            camera: camera,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      );
}

/// The GPU arm's root. Holds every arm and swaps between them on [arm].
class GpuSpikeApp extends StatefulWidget {
  const GpuSpikeApp({
    super.key,
    required this.document,
    required this.viewport,
    required this.lineweightScale,
    required this.drawText,
    required this.onReady,
    required this.onFailed,
  });

  final DraftDocument document;
  final Size viewport;
  final double lineweightScale;

  /// Whether the painter emits text ops for arm C to draw, and arm C's own
  /// backend to composite -- criterion 11's control. See `main.dart`'s
  /// `kDrawText` doc comment: with text drawn by this arm since Plan E,
  /// `DRAW_TEXT=false` isolates the cost of drawing it rather than merely
  /// undercounting what the painter walk emits.
  final bool drawText;
  final void Function(GpuSpikeState state) onReady;
  final void Function(Object error, StackTrace stack) onFailed;

  @override
  State<GpuSpikeApp> createState() => GpuSpikeState();
}

class GpuSpikeState extends State<GpuSpikeApp> {
  late final SpatialIndex index = SpatialIndex(widget.document);
  late final CameraController camera = CameraController(
      ViewportTransform.fit(widget.document.extents, widget.viewport));

  final ValueNotifier<GpuSpikeArm> arm = ValueNotifier(GpuSpikeArm.painter);

  /// Null until [_buildResidentGeometry] finishes, and possibly still null
  /// after that -- see the doc comment there. Arm C draws through this, when
  /// it is not null.
  GpuDrawBackend? backend;
  int instanceCount = 0;
  int skippedOps = 0;

  /// Text ops the walk emitted -- `collector.texts.length`, one per resident
  /// label. Zero unless `SPIKE_TEXT=true` put labels in the corpus.
  int textOps = 0;

  /// Labels [classifyTextPatches] found at least one covering instance for,
  /// at this arm's collection camera. The number criterion 11 measures the
  /// cost of drawing.
  int patches = 0;

  /// `geometry.byteLength - ResidentGeometry.byteLengthFor(instanceCount)` --
  /// the device memory every patch's sub-buffer of instances occupies, beside
  /// the main buffer [ResidentGeometry.byteLength] already counts.
  int subBufferBytes = 0;

  /// `geometry.patchTargetBytes` -- the device memory every patch's own
  /// render target occupies, a cost with no analogue before Plan E.
  int patchTargetBytes = 0;

  /// Wall-clock cost of [classifyTextPatches], in milliseconds -- read
  /// against criterion 7's rebuild budget, beside [uploadMs].
  double classifyMs = 0;

  /// Wall-clock cost of the one-time collection and upload, in milliseconds.
  double uploadMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _buildResidentGeometry();
        widget.onReady(this);
      } catch (error, stack) {
        widget.onFailed(error, stack);
      }
    });
  }

  /// Walks the document once, through `GeometryCollector`, and uploads the
  /// result through `ResidentGeometry.create` -- and never walks it again.
  ///
  /// **`ResidentGeometry.create` does not throw.** It returns `null` for two
  /// different reasons -- no GPU on this platform, or a real upload failure,
  /// the latter already reported through `FlutterError.reportError` by the
  /// package itself (`resident_geometry.dart`'s own doc comment) -- so this
  /// method does not need to distinguish them to stay safe; it only needs to
  /// leave [backend] null and say so, which is exactly what makes
  /// `runGpuSpike`'s "arm C submitted no GPU frame" guard fire instead of the
  /// run silently measuring an empty screen.
  Future<void> _buildResidentGeometry() async {
    final stopwatch = Stopwatch()..start();
    final painter = DraftPainter(
      document: widget.document,
      index: index,
      resolver: DocumentStyleResolver(widget.document),
      // `widget.drawText`, not a hard-coded `true`: with text drawn by this
      // arm since Plan E, this is now criterion 11's control, not a way to
      // undercount what the painter walk emits. At `DRAW_TEXT=false` the
      // painter suppresses text ops entirely -- `collector.texts` is empty,
      // no patch is ever classified, and the difference against a
      // `DRAW_TEXT=true` run at the same corpus is the cost of drawing text.
      drawText: widget.drawText,
    );
    // Read once, beside the collector's own read below: both this and
    // `ResidentGeometry.create`'s `maxPatchWidth`/`maxPatchHeight` need the
    // same device pixel ratio, and reading it twice from `MediaQuery` would
    // invite the two to drift if a future edit changed one call site and not
    // the other.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final collector = GeometryCollector(
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      devicePixelRatio: dpr,
      lineweightScale: widget.lineweightScale,
      // The document's own measurer, not a harness global -- `GeometryCollector`
      // takes the abstract `TextMeasurer?`, so no cast is needed here.
      measurer: widget.document.textMeasurer,
      textStyleOf: widget.document.textStyleOf,
    );
    // **Collected under the fit camera, not an identity one.** `DraftPainter`
    // folds the camera into the residuals it hands a sink, and its
    // level-of-detail decisions read the camera's scale. Collecting under an
    // identity camera would give world coordinates and the *wrong* level of
    // detail. Collecting under the fit camera gives the level of detail a
    // fitted view would draw, and the buffer's space is then that camera's
    // screen space -- which is also the space `collectionCamera` below tells
    // `GpuDrawBackend` to map back out of every frame.
    final collectionCamera = camera.value;
    painter.paint(collector, collectionCamera, widget.viewport);
    final walkMs = stopwatch.elapsedMicroseconds / 1000.0;

    // Classified once, at rebuild, exactly like the collection walk above --
    // not re-run per frame. `patches` says how many of this corpus's labels
    // a later stroke covers; at `SPIKE_TEXT=true` that includes every one of
    // `_addPatchedLabels`'s deliberate patches, by construction.
    final classifyWatch = Stopwatch()..start();
    final patchList = classifyTextPatches(
        collector.data, collector.instanceCount, collector.texts,
        devicePixelRatio: dpr);
    classifyWatch.stop();

    final geometry = await ResidentGeometry.create(
        collector.data, collector.instanceCount,
        texts: collector.texts,
        patches: patchList,
        devicePixelRatio: dpr,
        maxPatchWidth: (widget.viewport.width * dpr).round(),
        maxPatchHeight: (widget.viewport.height * dpr).round());
    stopwatch.stop();

    setState(() {
      instanceCount = collector.instanceCount;
      skippedOps = collector.skippedOps;
      textOps = collector.texts.length;
      patches = patchList.length;
      classifyMs = classifyWatch.elapsedMicroseconds / 1000.0;
      backend = geometry == null
          ? null
          // The cast is safe by construction: every document this harness
          // hands `GpuSpikeApp` -- `spikeDocument()` -- is built on
          // `harnessMeasurer`, a `FlutterTextMeasurer`, which is exactly what
          // `GpuDrawBackend` requires for its own `measurer:`.
          : GpuDrawBackend(geometry, collectionCamera,
              measurer: widget.document.textMeasurer as FlutterTextMeasurer,
              textStyleOf: widget.document.textStyleOf);
      subBufferBytes = geometry == null
          ? 0
          : geometry.byteLength - ResidentGeometry.byteLengthFor(instanceCount);
      patchTargetBytes = geometry?.patchTargetBytes ?? 0;
      uploadMs = stopwatch.elapsedMicroseconds / 1000.0;
    });

    if (geometry == null) {
      gpuReport(
          'GSPIKE collect+upload: walk ${walkMs.toStringAsFixed(1)} ms -- '
          'ResidentGeometry.create returned null (no GPU on this platform, or '
          'the upload failed -- check for a FlutterError above this line if '
          'so). instances=$instanceCount, skippedOps=$skippedOps. Arm C will '
          'submit no GPU frames and the rig aborts when it switches to it.');
      return;
    }
    gpuReport('GSPIKE collect+upload: walk ${walkMs.toStringAsFixed(1)} ms, '
        'total ${uploadMs.toStringAsFixed(1)} ms, '
        'instances=$instanceCount, '
        'buffer=${(geometry.byteLength / (1024 * 1024)).toStringAsFixed(2)} MB, '
        'skippedOps=$skippedOps, textOps=$textOps patches=$patches '
        'subBuffer=${(subBufferBytes / (1024 * 1024)).toStringAsFixed(2)} MB '
        'patchTargets=${(patchTargetBytes / (1024 * 1024)).toStringAsFixed(2)} MB '
        'classify=${classifyMs.toStringAsFixed(1)} ms');
  }

  @override
  void dispose() {
    index.dispose();
    camera.dispose();
    arm.dispose();
    backend?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          // `SizedBox.expand` for the reason the widget spike's rig records:
          // a `Stack` sizes itself to its non-positioned children, and an
          // `Offstage` arm is zero-sized exactly when another arm is live.
          body: SizedBox.expand(
            child: ValueListenableBuilder<GpuSpikeArm>(
              valueListenable: arm,
              builder: (context, a, _) {
                final built = backend;
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Offstage(
                      offstage: a != GpuSpikeArm.painter,
                      child: DraftCanvas(
                        document: widget.document,
                        index: index,
                        camera: camera,
                        lineweightScale: widget.lineweightScale,
                        tiles: false,
                      ),
                    ),
                    Offstage(
                      offstage: a != GpuSpikeArm.tiled,
                      child: DraftCanvas(
                        document: widget.document,
                        index: index,
                        camera: camera,
                        lineweightScale: widget.lineweightScale,
                        tiles: true,
                      ),
                    ),
                    if (a == GpuSpikeArm.gpu && built != null)
                      Positioned.fill(
                        child: GpuArmView(backend: built, camera: camera),
                      ),
                    // **Only after the last phase, and that is not cosmetic.**
                    // An overlay in the tree while a phase is running would be
                    // laid out and painted inside the frames being measured.
                    // It appears when the run is over and the numbers are
                    // already taken.
                    Positioned.fill(
                      child: ValueListenableBuilder<List<String>>(
                        valueListenable: gpuReportLines,
                        builder: (context, lines, _) {
                          if (lines.isEmpty ||
                              !lines.last.contains('GSPIKE done')) {
                            return const SizedBox.shrink();
                          }
                          return ColoredBox(
                            color: const Color(0xF2FFFFFF),
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  lines.join('\n'),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    height: 1.25,
                                    color: Color(0xFF000000),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}

/// Runs every arm over every phase, interleaved, [repeats] times.
///
/// **Interleaved and not blocked**, for the reason Plan 3i recorded: blocked
/// arms let session drift land entirely on one of them.
Future<void> runGpuSpike(
  GpuSpikeState state, {
  required int entities,
  required int frames,
  required int repeats,
  required Size viewport,
}) async {
  refuseDebugMode();

  final baseCamera = state.camera.value;
  final centre = Offset(viewport.width / 2, viewport.height / 2);

  gpuReport('GSPIKE run: entities=$entities instances=${state.instanceCount} '
      'viewport=${viewport.width.toStringAsFixed(0)}x'
      '${viewport.height.toStringAsFixed(0)} '
      'frames=$frames repeats=$repeats');
  gpuReport('GSPIKE note: arm C (residentGpu) draws strokes, joins, points, '
      'circles, arcs, shaded dashes, (since Plan D) fills and (since Plan E) '
      'text -- ${state.skippedOps} op(s) this walk did not draw. Text is '
      'drawn through the compositor: resident labels position from a '
      'per-frame uniform, and this corpus has ${state.textOps} label(s), of '
      'which ${state.patches} are patches -- a label a later stroke covers, '
      'redrawn into its own small offscreen target and composited back after '
      'the main pass so the covering geometry still wins. Only present when '
      'SPIKE_TEXT=true; at its default the corpus carries no text and both '
      'counts are 0. DRAW_TEXT=false is criterion 11\'s control: it asks the '
      'painter to suppress every text op, so a run at DRAW_TEXT=false against '
      'the same SPIKE_TEXT=true corpus isolates the cost of drawing text as a '
      'difference between the two runs, not a single number read alone. '
      'Fills are only in this corpus when SPIKE_FILLS=true; at its default '
      'the corpus carries none and skippedOps is 0 on this account '
      'regardless. Butt caps only -- Plan B emits no cap geometry. No '
      'antialiasing. Dash patterns are evaluated per fragment against the '
      'live camera since Plan C, collapse rule included, so nothing about '
      'them is baked. Every remaining gap favours arm C on a timing '
      'comparison, which is why the picture matters as much as the numbers '
      'here.');

  final reports = <GpuPhaseReport>[];

  Future<void> setArm(GpuSpikeArm a) async {
    final before = state.backend?.frames ?? 0;
    state.arm.value = a;
    await pumpFrame();
    await pumpFrame();
    // **The `painted=0` check belongs here, not in a phase.** Arm C renders
    // only when the camera changes, so a hold legitimately submits nothing --
    // that is the arm working, and the first smoke run's guard called it a
    // defect. What would be a real defect is the arm never painting at all,
    // and switching to it is exactly when that shows. It also fires when
    // [GpuSpikeState.backend] never got built (`ResidentGeometry.create`
    // returned null): `state.backend?.frames` reads `null ?? 0` on every
    // frame, so `before` and the post-switch count are equal either way.
    if (a == GpuSpikeArm.gpu && (state.backend?.frames ?? 0) == before) {
      throw StateError('GSPIKE ${a.label}: switching to this arm submitted no '
          'GPU frame, so it is not in the paint path at all. Every number it '
          'would post is the cost of an empty screen.');
    }
  }

  Future<GpuPhaseReport> phase(
    GpuSpikeArm a,
    String name,
    void Function(int i) step,
  ) async {
    state.camera.value = baseCamera;
    await pumpFrame();

    final framesAtStart = state.backend?.frames ?? 0;
    var unalignedExcess = 0;
    final log = FrameTimingLog()..arm();
    try {
      await log.establishBaseline(pumpFrame);
      for (var i = 0; i < frames; i++) {
        step(i);
        await log.pump(pumpFrame);
      }
      await log.drain(pumpFrame, upTo: frames);
      // **The refusal stands on native and is relaxed on web, deliberately
      // and only there.** On the web the latch fires on arm A -- the plain
      // painter, no GPU code anywhere near it -- so it is not reporting a
      // defect in what is being measured. It is reporting that ordinal
      // alignment does not hold on that platform. See
      // `FrameTimingLog.debugTimingsUnaligned` for what is given up: these
      // become a distribution over the phase window rather than a statement
      // about the i-th pumped frame, and the excess is printed beside them.
      // Not this task's platform -- Plan G owns web -- kept because it is
      // cheap and this rig outlives the spike it was written for.
      if (!kIsWeb && log.sawBacklog) {
        throw StateError('GSPIKE ${a.label}/$name: the timing stream ran a '
            'backlog after the baseline, so every ordinal is off by an '
            'unknown amount. No figure from this phase is reportable.');
      }
      final timings = kIsWeb ? log.debugTimingsUnaligned : log.debugTimings;
      final build = <double>[];
      final raster = <double>[];
      for (final t in timings) {
        build.add(t.buildDuration.inMicroseconds / 1000.0);
        raster.add(t.rasterDuration.inMicroseconds / 1000.0);
      }
      if (kIsWeb) unalignedExcess = log.debugWorstExcess;
      // Read right after the phase's last frame, not summed or averaged over
      // it -- `GpuDrawBackend` resets these three at the top of every
      // `render`, so they already describe one frame and not the phase as a
      // whole. `state.backend` is only non-null on arm `gpu`; the other two
      // arms report zero, which [GpuPhaseReport]'s own doc comment explains.
      final b = state.backend;
      return GpuPhaseReport(
          a, name, build, raster, (state.backend?.frames ?? 0) - framesAtStart,
          unalignedExcess: unalignedExcess,
          patchesRendered: b?.patchesRendered ?? 0,
          patchesClipped: b?.patchesClipped ?? 0,
          patchesOffscreen: b?.patchesOffscreen ?? 0);
    } finally {
      log.disarm();
    }
  }

  for (var r = 0; r < repeats; r++) {
    for (final a in GpuSpikeArm.values) {
      await setArm(a);
      reports.add(await phase(a, 'hold', (i) {}));
      reports.add(
          await phase(a, 'pan', (i) => state.camera.panBy(const Offset(4, 0))));
      reports.add(
          await phase(a, 'zoom', (i) => state.camera.zoomAt(centre, 1.02)));
    }
    gpuReport('GSPIKE --- repeat ${r + 1} of $repeats ---');
    for (final rep
        in reports.skip(reports.length - GpuSpikeArm.values.length * 3)) {
      gpuReport('GSPIKE ${rep.arm.label} | ${rep.phase} | build  '
          '${gpuStats(rep.build)}');
      gpuReport('GSPIKE ${rep.arm.label} | ${rep.phase} | raster '
          '${gpuStats(rep.raster)}');
      if (kIsWeb) {
        gpuReport('GSPIKE ${rep.arm.label} | ${rep.phase} | UNALIGNED '
            '(distribution over the phase window, not per pumped frame); '
            'worst excess=${rep.unalignedExcess} frame(s)');
      }
      if (rep.arm == GpuSpikeArm.gpu) {
        gpuReport('GSPIKE ${rep.arm.label} | ${rep.phase} | '
            'gpu submits=${rep.submits} of $frames frames');
        // The counters this phase's *last* frame left behind, not a sum or
        // an average over it -- see [GpuPhaseReport.patchesRendered]'s doc
        // comment for why a per-phase total would be the wrong statistic
        // here.
        gpuReport('GSPIKE ${rep.arm.label} | ${rep.phase} | patches '
            'rendered=${rep.patchesRendered} clipped=${rep.patchesClipped} '
            'offscreen=${rep.patchesOffscreen}');
      }
    }
  }

  // Ruling E2's discipline, surfaced here too: a backend built without a
  // measurer drops every label silently, and `textsDropped` is that "so" as
  // a number rather than a missing picture. This harness always builds
  // `state.backend` WITH a measurer (`_buildResidentGeometry` above), so the
  // count is always 0 here -- printed only when it is not, for a future
  // caller that omits the measurer.
  final textsDropped = state.backend?.textsDropped ?? 0;
  if (textsDropped > 0) {
    gpuReport('GSPIKE note: textsDropped=$textsDropped -- labels the last '
        'frame drew nothing for, no compositor wired in.');
  }
  gpuReport('GSPIKE done: ${reports.length} phase reports above.');
}
