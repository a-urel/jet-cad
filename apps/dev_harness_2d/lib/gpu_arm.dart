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
// on a closed sweep) -- Plan B's job, done -- and since Plan C it also
// shades dash patterns per fragment, dashed arcs included. `fillPolygon`,
// `fillCircle` and `text` are the only ops that still fall through to its
// `skippedOps` counter: fills are Plan D's, text is Plan E's. A corpus with
// fills or text will show visibly less on arm C than on arm A or B --
// `skippedOps` in the `GSPIKE collect+upload` line says how much, so a thin
// picture reads as a number instead of as a silent gap.
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
      {this.unalignedExcess = 0});

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
    // **Ownership of `image`, spelled out.** `backend.render` returns a
    // fresh `ui.Image` wrapper on every call, over the *same* GPU texture
    // (`GpuDrawBackend._target`, reused across frames and only recreated on
    // resize) -- so this is a new Dart-side handle each frame, not a new
    // texture. `drawImageRect` below records that handle into the `Picture`
    // this `paint` call builds; the picture is what needs the image to stay
    // alive, for as long as the raster thread takes to consume it, which
    // outlives this function returning. This method deliberately does not
    // call `image.dispose()` -- doing so here, before the picture rasterises,
    // would race the very thing that still needs it. Not disposing leaves
    // the handle to the same lifetime the engine already manages for any
    // image recorded into a picture: it is reclaimed once Dart's GC collects
    // this `ui.Image` wrapper, no earlier than the frame that recorded it has
    // rasterised. Over this harness's measured run that is up to 270
    // short-lived per-frame handles (one per `render` call with a camera
    // change); that is a real, accepted GC-pressure cost of a measurement
    // widget creating one `ui.Image` per frame, not a leak, and not a claim
    // about the package's own frame-path allocation budget (CLAUDE.md's
    // non-negotiable governs `jet_cad_2d_flutter`'s frame path, which this
    // ad hoc harness `CustomPainter` is not part of).
    final image = backend.render(camera.value, size, devicePixelRatio);
    if (image == null) return;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.none,
    );
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
    required this.onReady,
    required this.onFailed,
  });

  final DraftDocument document;
  final Size viewport;
  final double lineweightScale;
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
      // Text is not drawn by this arm -- `GeometryCollector.text()` only
      // counts it -- but `drawText: true` still asks the painter to *emit*
      // text ops rather than suppress them. Suppressing them here would
      // make the collector's `skippedOps` undercount: it can only count an
      // op it is actually handed, so what keeps the count honest about what
      // a later plan's backend would still owe is the painter emitting
      // every op and the collector being the one that drops it.
      drawText: true,
    );
    final collector = GeometryCollector(
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      lineweightScale: widget.lineweightScale,
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

    final geometry =
        await ResidentGeometry.create(collector.data, collector.instanceCount);
    stopwatch.stop();

    setState(() {
      instanceCount = collector.instanceCount;
      skippedOps = collector.skippedOps;
      backend =
          geometry == null ? null : GpuDrawBackend(geometry, collectionCamera);
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
        'skippedOps=$skippedOps');
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
      'circles, arcs and shaded dashes -- ${state.skippedOps} op(s) this '
      'walk did not draw (fills, text: later plans\' job, see the section '
      'comment above this rig). Butt caps only -- Plan B emits no cap '
      'geometry. No antialiasing. Dash patterns are evaluated per fragment '
      'against the live camera since Plan C, collapse rule included, so '
      'nothing about them is baked. Every remaining gap favours arm C on a '
      'timing comparison, which is why the picture matters as much as the '
      'numbers here.');

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
      return GpuPhaseReport(
          a, name, build, raster, (state.backend?.frames ?? 0) - framesAtStart,
          unalignedExcess: unalignedExcess);
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
      }
    }
  }

  gpuReport('GSPIKE done: ${reports.length} phase reports above.');
}
