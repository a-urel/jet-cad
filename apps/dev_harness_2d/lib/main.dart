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

/// Routes the walk through `VerticesDrawSink` instead of `CanvasDrawSink`.
///
/// The spike for `2026-08-20-dash-leaf-separation.md`'s conclusion: the unit of
/// render cost is the canvas call, so batch the calls. Inert at its default of
/// `false`, which leaves the frame byte-identical to every earlier run.
const bool kVertices = bool.fromEnvironment('VERTICES');

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
  ///
  /// [vertices] is non-null only under [kVertices]; a rig reads its batch and
  /// flush counters the same way it reads the painter's.
  final void Function(
      CameraController camera,
      SpatialIndex index,
      DraftPainter painter,
      CanvasDrawSink sink,
      VerticesDrawSink? vertices)? onReady;

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
          canvasState.vertices);
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
                useVertices: kVertices),
          ),
        ),
      );
}
