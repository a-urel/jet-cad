// A measurement harness, not a product.
//
// Pointer pan and scroll zoom go straight to `CameraController`. There is no
// tool architecture and no selection, because tools are Plan 4 and every line
// here is a line the rigs have to keep working.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

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

/// The corpus the rigs measure on: the same shape as R1's, so the two sets of
/// numbers describe one drawing.
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
      dashedFraction: 0.35,
    );

void main() => runApp(HarnessApp(document: harnessDocument()));

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
  final void Function(CameraController camera, SpatialIndex index,
      DraftPainter painter, CanvasDrawSink sink)? onReady;

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
      widget.onReady
          ?.call(camera, index, canvasState.painter, canvasState.sink);
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
                lineweightScale: kLineweightScale),
          ),
        ),
      );
}
