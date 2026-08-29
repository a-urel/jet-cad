// THROWAWAY SPIKE CODE. Branch `spike/flutter-gpu-backend`, 2026-08-29.
//
// Three arms over a hold, a pan and a zoom, interleaved.
//
// **The timing instrument is not reimplemented here.** `FrameTimingLog` in
// `measurement_rig.dart` carries the baseline drain and the backlog latch that
// Plan 3i needed two attempts to get right. Anything that measures frames here
// goes through that class.
//
// ignore_for_file: avoid_print -- printing the numbers is what a rig is for.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'gpu_arm.dart';
import 'measurement_rig.dart';

/// The three arms.
enum GpuSpikeArm {
  /// Today's untiled path: the whole document walked per frame into one
  /// `drawVertices`.
  painter,

  /// Today's *gesture* path, and the one that matters: Plan 3i's tile cache,
  /// which answers a moving frame by blitting the previous generation's
  /// composite, magnified. Cheap and blurry.
  tiled,

  /// The geometry uploaded once, the camera a uniform. Sharp, and the
  /// question is what it costs.
  gpu;

  String get label => switch (this) {
        GpuSpikeArm.painter => 'A painter (untiled)',
        GpuSpikeArm.tiled => 'B tiles (blit)',
        GpuSpikeArm.gpu => 'C flutter_gpu (resident)',
      };
}

/// One phase's timings, in milliseconds.
class GpuPhaseReport {
  GpuPhaseReport(this.arm, this.phase, this.build, this.raster, this.submits);

  final GpuSpikeArm arm;
  final String phase;
  final List<double> build;
  final List<double> raster;

  /// GPU frames arm C submitted during the phase. Zero on a hold is the arm
  /// working: nothing changed, so nothing was re-rendered.
  final int submits;
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

/// The spike's root. Holds every arm and swaps between them on [arm].
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

  GpuLineRenderer? renderer;
  GpuSegments? segments;

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

  /// Walks the document once, uploads the result, and never walks it again.
  Future<void> _buildResidentGeometry() async {
    final stopwatch = Stopwatch()..start();
    final painter = DraftPainter(
      document: widget.document,
      index: index,
      resolver: DocumentStyleResolver(widget.document),
      // Text is not drawn by this arm; asking the painter not to emit it keeps
      // the collector's skipped-text count honest about what a real backend
      // would still owe.
      drawText: true,
    );
    final collector = SegmentCollector(
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      lineweightScale: widget.lineweightScale,
    );
    // **Collected under the fit camera, not an identity one.** See
    // `GpuSegments`: the painter folds the camera into its residuals and its
    // level-of-detail decisions read the camera's scale.
    final collectionCamera = camera.value;
    painter.paint(collector, collectionCamera, widget.viewport);
    final collected = collector.finish(collectionCamera);
    final walkMs = stopwatch.elapsedMicroseconds / 1000.0;

    final built = await GpuLineRenderer.create(collected);
    stopwatch.stop();

    setState(() {
      segments = collected;
      renderer = built;
      uploadMs = stopwatch.elapsedMicroseconds / 1000.0;
    });
    print('GSPIKE collect+upload: walk ${walkMs.toStringAsFixed(1)} ms, '
        'total ${uploadMs.toStringAsFixed(1)} ms, '
        'segments=${collected.count}, '
        'buffer=${(collected.byteLength / (1024 * 1024)).toStringAsFixed(2)} MB, '
        'skippedFills=${collected.skippedFills}, '
        'skippedText=${collected.skippedText}');
  }

  @override
  void dispose() {
    index.dispose();
    camera.dispose();
    arm.dispose();
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
                final built = renderer;
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
                        child: GpuArmView(renderer: built, camera: camera),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}

Future<void> _pumpFrame() {
  SchedulerBinding.instance.scheduleFrame();
  return SchedulerBinding.instance.endOfFrame;
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
  final resident = state.segments!;

  print('GSPIKE run: entities=$entities segments=${resident.count} '
      'viewport=${viewport.width.toStringAsFixed(0)}x'
      '${viewport.height.toStringAsFixed(0)} '
      'frames=$frames repeats=$repeats');
  print('GSPIKE note: arm C draws no joins, no caps, no antialiasing, no '
      'fills and no text, and its dash spans are baked at the fit camera. '
      'Every one of those favours arm C.');

  final reports = <GpuPhaseReport>[];

  Future<void> setArm(GpuSpikeArm a) async {
    final before = state.renderer?.frames ?? 0;
    state.arm.value = a;
    await _pumpFrame();
    await _pumpFrame();
    // **The `painted=0` check belongs here, not in a phase.** Arm C renders
    // only when the camera changes, so a hold legitimately submits nothing --
    // that is the arm working, and the first smoke run's guard called it a
    // defect. What would be a real defect is the arm never painting at all,
    // and switching to it is exactly when that shows.
    if (a == GpuSpikeArm.gpu && (state.renderer?.frames ?? 0) == before) {
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
    await _pumpFrame();

    final framesAtStart = state.renderer?.frames ?? 0;
    final log = FrameTimingLog()..arm();
    try {
      await log.establishBaseline(_pumpFrame);
      for (var i = 0; i < frames; i++) {
        step(i);
        await log.pump(_pumpFrame);
      }
      await log.drain(_pumpFrame, upTo: frames);
      if (log.sawBacklog) {
        throw StateError('GSPIKE ${a.label}/$name: the timing stream ran a '
            'backlog after the baseline, so every ordinal is off by an '
            'unknown amount. No figure from this phase is reportable.');
      }
      final build = <double>[];
      final raster = <double>[];
      for (final t in log.debugTimings) {
        build.add(t.buildDuration.inMicroseconds / 1000.0);
        raster.add(t.rasterDuration.inMicroseconds / 1000.0);
      }
      return GpuPhaseReport(a, name, build, raster,
          (state.renderer?.frames ?? 0) - framesAtStart);
    } finally {
      log.disarm();
    }
  }

  for (var r = 0; r < repeats; r++) {
    for (final a in GpuSpikeArm.values) {
      await setArm(a);
      reports.add(await phase(a, 'hold', (i) {}));
      reports.add(await phase(
          a, 'pan', (i) => state.camera.panBy(const Offset(4, 0))));
      reports.add(await phase(
          a, 'zoom', (i) => state.camera.zoomAt(centre, 1.02)));
    }
    print('GSPIKE --- repeat ${r + 1} of $repeats ---');
    for (final rep
        in reports.skip(reports.length - GpuSpikeArm.values.length * 3)) {
      print('GSPIKE ${rep.arm.label} | ${rep.phase} | build  '
          '${gpuStats(rep.build)}');
      print('GSPIKE ${rep.arm.label} | ${rep.phase} | raster '
          '${gpuStats(rep.raster)}');
      if (rep.arm == GpuSpikeArm.gpu) {
        print('GSPIKE ${rep.arm.label} | ${rep.phase} | '
            'gpu submits=${rep.submits} of $frames frames');
      }
    }
  }

  print('GSPIKE done: ${reports.length} phase reports above.');
}
