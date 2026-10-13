// A document shown in a DraftCanvas: a line and a circle, framed whole.
//
// Run from the package directory with `flutter run -t example/lib/main.dart`.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

void main() => runApp(const DraftExampleApp());

/// A line and a circle, measured by the Flutter text measurer that
/// [DraftCanvas] requires.
DraftDocument buildExampleDocument() {
  final doc = DraftDocument.empty(measurer: FlutterTextMeasurer());
  doc.commands
    ..execute(addDrafted(
        doc, EntityKind.line, linePayload(Vector2(100, 100), Vector2(500, 100)),
        layer: ReservedHandles.layerZero))
    ..execute(addDrafted(
        doc, EntityKind.circle, circlePayload(Vector2(300, 250), 50),
        layer: ReservedHandles.layerZero));
  return doc;
}

class DraftExampleApp extends StatefulWidget {
  const DraftExampleApp({super.key});

  @override
  State<DraftExampleApp> createState() => _DraftExampleAppState();
}

class _DraftExampleAppState extends State<DraftExampleApp> {
  final DraftDocument document = buildExampleDocument();
  late final SpatialIndex index = SpatialIndex(document);
  CameraController? camera;

  @override
  void dispose() {
    camera?.dispose();
    index.dispose();
    document.dispose();
    (document.textMeasurer as FlutterTextMeasurer).clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(builder: (context, constraints) {
          // Framed once, at the first layout: the drawing's extents with a
          // margin, fitted to the space the canvas gets.
          camera ??= CameraController(ViewportTransform.fit(
              document.extents.expandedBy(20), constraints.biggest));
          return DraftCanvas(document: document, index: index, camera: camera!);
        }),
      );
}
