# jet_cad_2d_flutter

Flutter rendering and interaction for the pure-Dart
[`jet_cad_2d`](https://pub.dev/packages/jet_cad_2d) engine. It draws a
`DraftDocument` on a canvas, with a camera, rulers, selection and snapping,
and writes a page of it out as a vector PDF or a PNG. The engine stays free
of `dart:ui`; everything that needs Flutter is here.

## What it holds

- **`DraftCanvas`**: the widget that paints a document and repaints on camera
  and document changes and on nothing else.
- **`CameraController` and `ViewportTransform`**: pan, zoom and the
  world-to-screen transform, with zoom-to-fit.
- **`RulerFrame`**: rulers around a canvas.
- **`InteractionLayer` and `ToolController`**: the pointer layer over a
  canvas, which routes mouse, touch and keyboard input to the active `Tool`:
  `SelectTool` (selection and grips) or one of the drawing tools
  (`LineTool`, `PolylineTool`, `RectangleTool`, `CircleTool`, `ArcTool`,
  `TextTool`). Object snapping is configured with `SnapSettings` and drawn
  by `drawSnapMarker`.
- **PDF and PNG export**: `exportPagePdf` and `exportPagePng` write a page of
  a document to bytes.

## Example

`DraftCanvas` borrows its document, its spatial index and its camera: the
application creates them and disposes of them. The document must carry a
`FlutterTextMeasurer`, which is how its text is measured.

```dart
final document = DraftDocument.empty(measurer: FlutterTextMeasurer());
final index = SpatialIndex(document);
final camera = CameraController(
    ViewportTransform.fit(document.extents.expandedBy(20), size));

DraftCanvas(document: document, index: index, camera: camera)
```

A complete app, which draws a line and a circle and frames them, is
[`example/lib/main.dart`](https://github.com/a-urel/jet-cad/blob/main/packages/jet_cad_2d_flutter/example/lib/main.dart).
Run it from the package directory with `flutter run -t example/lib/main.dart`.

## The API

`package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` is the API. Nothing under
`src/` is. `package:jet_cad_2d_flutter/export_testing.dart` is a test
instrument for this repository's own suites; it is not API and may change in
any release.

While the version is `0.x`, a minor release (`0.8.0`) may break the API, and a
patch release (`0.7.2`) does not.

## Where it comes from

This package is the rendering layer of
[jet-cad](https://github.com/a-urel/jet-cad), a parametric floor planner;
`jet_cad_floor_plan` builds on it.

## License

Apache License 2.0. See [LICENSE](LICENSE).
