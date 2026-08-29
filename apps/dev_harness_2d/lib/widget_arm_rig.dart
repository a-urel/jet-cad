// THROWAWAY SPIKE CODE. Branch `spike/widget-per-entity`, 2026-08-29.
//
// Prices one RenderObject per entity against the single `CustomPainter` walk,
// at floor-plan scale, over a hold, a pan and a zoom.
//
// **The timing instrument is not reimplemented here.** `FrameTimingLog` in
// `measurement_rig.dart` carries the baseline drain and the backlog latch that
// Plan 3i needed two attempts to get right -- a `FrameTiming` arrives only
// after its frame rasterises, while `pumpFrame` completes at
// `SchedulerBinding.endOfFrame` before it, so a log that is not rebased names
// the wrong frame and says nothing about it. Anything that measures frames
// here goes through that class.
//
// ignore_for_file: avoid_print -- printing the numbers is what a rig is for.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'measurement_rig.dart';
import 'widget_arm.dart';

/// The three arms.
enum SpikeArm {
  /// Today's path: one `CustomPainter`, the whole document walked per frame.
  painter,

  /// The widget approach's ceiling: one render object per entity, the whole
  /// set behind a `RepaintBoundary`, the camera a `Transform` above it. No
  /// child repaints when the camera moves. **Draws the wrong line widths.**
  transformed,

  /// The honest widget arm: screen-space lineweight, so every child repaints
  /// when the camera scale changes.
  correctLineweight;

  String get label => switch (this) {
        SpikeArm.painter => 'A painter',
        SpikeArm.transformed => 'B widget+transform (WRONG lineweight)',
        SpikeArm.correctLineweight => 'C widget+correct lineweight',
      };
}

/// One phase's timings, in milliseconds.
class PhaseReport {
  PhaseReport(this.arm, this.phase, this.build, this.raster, this.painted);

  final SpikeArm arm;
  final String phase;
  final List<double> build;
  final List<double> raster;

  /// Children the layer actually painted after culling on the last frame.
  /// Zero on a widget arm means the phase measured an empty screen.
  final int painted;
}

String stats(List<double> ms) {
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

void printPhase(PhaseReport r) {
  print('WSPIKE ${r.arm.label} | ${r.phase} | build  ${stats(r.build)}');
  print('WSPIKE ${r.arm.label} | ${r.phase} | raster ${stats(r.raster)}');
  if (r.arm != SpikeArm.painter && r.painted == 0) {
    print('WSPIKE WARNING ${r.arm.label} | ${r.phase} | painted=0 children -- '
        'this arm drew nothing and its numbers are the cost of an empty '
        'screen, not of the drawing');
  } else if (r.arm != SpikeArm.painter) {
    print('WSPIKE ${r.arm.label} | ${r.phase} | painted=${r.painted} children');
  }
}

/// The spike's root. Holds every arm and swaps between them on [arm].
class WidgetSpikeApp extends StatefulWidget {
  const WidgetSpikeApp({
    super.key,
    required this.document,
    required this.viewport,
    required this.lineweightScale,
    required this.onReady,
  });

  final DraftDocument document;
  final Size viewport;
  final double lineweightScale;
  final void Function(WidgetSpikeState state) onReady;

  @override
  State<WidgetSpikeApp> createState() => WidgetSpikeState();
}

class WidgetSpikeState extends State<WidgetSpikeApp> {
  late final SpatialIndex index = SpatialIndex(widget.document);
  late final CameraController camera = CameraController(
      ViewportTransform.fit(widget.document.extents, widget.viewport));
  final GlobalKey<DraftCanvasState> _canvasKey = GlobalKey<DraftCanvasState>();

  final ArmCamera armCamera = ArmCamera();
  final ValueNotifier<SpikeArm> arm = ValueNotifier(SpikeArm.painter);

  List<ArmPrimitive> primitives = const [];
  int droppedText = 0;
  int droppedResidual = 0;

  RenderEntityLayer? _layerFor(SpikeArm a) {
    final key = a == SpikeArm.transformed ? _bKey : _cKey;
    return key.currentContext?.findRenderObject() as RenderEntityLayer?;
  }

  int paintedFor(SpikeArm a) =>
      a == SpikeArm.painter ? -1 : (_layerFor(a)?.lastPainted ?? 0);

  final GlobalKey _bKey = GlobalKey();
  final GlobalKey _cKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final painter = _canvasKey.currentState!.painter;
      final extracted =
          extractPrimitives(painter, camera.value, widget.viewport);
      setState(() {
        primitives = extracted.primitives;
        droppedText = extracted.droppedText;
        droppedResidual = extracted.droppedResidual;
      });
      widget.onReady(this);
    });
  }

  @override
  void dispose() {
    index.dispose();
    camera.dispose();
    armCamera.dispose();
    arm.dispose();
    super.dispose();
  }

  Widget _widgetLayer(SpikeArm a) {
    final layer = WidgetEntityLayer(
      key: a == SpikeArm.transformed ? _bKey : _cKey,
      camera: armCamera,
      mode: a == SpikeArm.transformed
          ? WidgetArmMode.transformed
          : WidgetArmMode.correctLineweight,
      primitives: primitives,
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      lineweightScale: widget.lineweightScale,
    );
    if (a == SpikeArm.correctLineweight) return layer;
    // Arm B's whole claim: the camera is a transform layer **above** a
    // repaint boundary, so a camera change never reaches a child's `paint`.
    return AnimatedBuilder(
      animation: armCamera,
      builder: (context, child) =>
          Transform(transform: armCamera.matrix, child: child),
      child: RepaintBoundary(child: layer),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          body: ValueListenableBuilder<SpikeArm>(
            valueListenable: arm,
            builder: (context, a, _) => Stack(
              children: [
                // Arm A is always in the tree so that swapping arms does not
                // also measure building and disposing a `DraftCanvas`. It is
                // taken out of the paint path with `Offstage` when another arm
                // is live, which stops it painting without rebuilding it.
                Offstage(
                  offstage: a != SpikeArm.painter,
                  child: DraftCanvas(
                    key: _canvasKey,
                    document: widget.document,
                    index: index,
                    camera: camera,
                    lineweightScale: widget.lineweightScale,
                    tiles: false,
                  ),
                ),
                if (a != SpikeArm.painter && primitives.isNotEmpty)
                  Positioned.fill(child: _widgetLayer(a)),
              ],
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
/// **Interleaved and not blocked.** Plan 3h blocked its arms and the inert
/// control phase drifted by an order of magnitude between the two halves of
/// the session; Plan 3i interleaved and the same control drifted 9%. Three
/// arms measured one after another in one session is the only arrangement
/// whose ratios mean anything here.
Future<void> runWidgetSpike(
  WidgetSpikeState state, {
  required int entities,
  required int frames,
  required int repeats,
  required Size viewport,
}) async {
  refuseDebugMode();

  final baseCamera = state.camera.value;
  final baseScale = 1.0;
  final centre = Offset(viewport.width / 2, viewport.height / 2);

  print('WSPIKE run: entities=$entities primitives=${state.primitives.length} '
      'droppedText=${state.droppedText} '
      'droppedResidual=${state.droppedResidual} '
      'viewport=${viewport.width.toStringAsFixed(0)}x'
      '${viewport.height.toStringAsFixed(0)} '
      'frames=$frames repeats=$repeats');
  print('WSPIKE note: text ops are not drawn by arms B or C, and dash spans '
      'recorded at the fit camera are never re-split by either -- both cheats '
      'favour the widget arms.');

  final reports = <PhaseReport>[];

  Future<void> setArm(SpikeArm a) async {
    // Wall clock across the switch, reported because it is a real cost even
    // though it is paid once: building 5,000 widgets, elements and render
    // objects is what opening a drawing would cost on the widget path. The
    // first of the two frames carries the build and the layout; the second
    // leaves the pipeline quiet before anything is measured.
    final sw = Stopwatch()..start();
    state.arm.value = a;
    await _pumpFrame();
    final buildMs = sw.elapsedMicroseconds / 1000.0;
    await _pumpFrame();
    sw.stop();
    print('WSPIKE ${a.label} | arm switch | first frame '
        '${buildMs.toStringAsFixed(1)} ms wall clock, '
        'two frames ${(sw.elapsedMicroseconds / 1000.0).toStringAsFixed(1)} ms');
  }

  Future<PhaseReport> phase(
    SpikeArm a,
    String name,
    void Function(int i) step,
  ) async {
    // Reset both cameras to the same starting view for every phase.
    state.camera.value = baseCamera;
    state.armCamera.set(scale: baseScale, offset: Offset.zero);
    await _pumpFrame();

    final log = FrameTimingLog()..arm();
    try {
      await log.establishBaseline(_pumpFrame);
      for (var i = 0; i < frames; i++) {
        step(i);
        await log.pump(_pumpFrame);
      }
      await log.drain(_pumpFrame, upTo: frames);
      if (log.sawBacklog) {
        throw StateError('WSPIKE ${a.label}/$name: the timing stream ran a '
            'backlog after the baseline, so every ordinal is off by an '
            'unknown amount. No figure from this phase is reportable.');
      }
      final build = <double>[];
      final raster = <double>[];
      for (final t in log.debugTimings) {
        build.add(t.buildDuration.inMicroseconds / 1000.0);
        raster.add(t.rasterDuration.inMicroseconds / 1000.0);
      }
      return PhaseReport(a, name, build, raster, state.paintedFor(a));
    } finally {
      log.disarm();
    }
  }

  for (var r = 0; r < repeats; r++) {
    for (final a in SpikeArm.values) {
      await setArm(a);

      reports.add(await phase(a, 'hold', (i) {}));

      reports.add(await phase(a, 'pan', (i) {
        if (a == SpikeArm.painter) {
          state.camera.panBy(const Offset(4, 0));
        } else {
          state.armCamera.set(
              scale: state.armCamera.scale,
              offset: state.armCamera.offset + const Offset(4, 0));
        }
      }));

      reports.add(await phase(a, 'zoom', (i) {
        const factor = 1.02;
        if (a == SpikeArm.painter) {
          state.camera.zoomAt(centre, factor);
        } else {
          final s = state.armCamera.scale * factor;
          // Zoom about the viewport centre, the same point arm A zooms about.
          final o = (state.armCamera.offset - centre) * factor + centre;
          state.armCamera.set(scale: s, offset: o);
        }
      }));
    }
    print('WSPIKE --- repeat ${r + 1} of $repeats ---');
    for (final rep
        in reports.skip(reports.length - SpikeArm.values.length * 3)) {
      printPhase(rep);
    }
  }

  print('WSPIKE done: ${reports.length} phase reports above.');
}
