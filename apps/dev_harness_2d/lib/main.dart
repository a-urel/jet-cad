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

/// Which [BatchMode] the harness renders with, so one profile run measures one
/// mode. `off` | `openBucket` | `bucketMap` | `bucketMapBakedCurves`.
const String kBatch =
    String.fromEnvironment('BATCH', defaultValue: 'bucketMap');

BatchMode get batchMode => BatchMode.values.firstWhere((m) => m.name == kBatch);

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

  /// Handed the pieces a rig needs to drive: the camera it scripts, and the
  /// index whose rebuild count it reports.
  final void Function(CameraController camera, SpatialIndex index)? onReady;

  @override
  State<HarnessApp> createState() => _HarnessAppState();
}

class _HarnessAppState extends State<HarnessApp> {
  late final SpatialIndex index = SpatialIndex(widget.document);
  late final CameraController camera = CameraController(
      ViewportTransform.fit(widget.document.extents, const Size(1600, 1200)));

  @override
  void initState() {
    super.initState();
    widget.onReady?.call(camera, index);
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
                document: widget.document,
                index: index,
                camera: camera,
                batchMode: batchMode),
          ),
        ),
      );
}
