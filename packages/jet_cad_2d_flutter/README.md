# jet_cad_2d_flutter

Flutter rendering and interaction for the pure-Dart
[`jet_cad_2d`](https://pub.dev/packages/jet_cad_2d) engine. It draws a
`DraftDocument` on a canvas, with a camera, rulers, selection and snapping,
and writes a page of it out as a vector PDF or a PNG. The engine stays free
of `dart:ui`; everything that needs Flutter is here.

![A drawing on its sheet with rulers, drawn by DraftCanvas on the light canvas](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_flutter-v0.7.2/packages/jet_cad_2d_flutter/doc/screenshots/canvas_light.png)


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
`FlutterTextMeasurer`, which is how its text is measured. The snippet uses
both packages, so add both: `dart pub add jet_cad_2d jet_cad_2d_flutter`.

```dart
final document = DraftDocument.empty(measurer: FlutterTextMeasurer());
final index = SpatialIndex(document);
final camera = CameraController(
    ViewportTransform.fit(document.extents.expandedBy(20), size));

final canvas = DraftCanvas(document: document, index: index, camera: camera);
```

A complete app, which draws a line and a circle and frames them, is
[`example/lib/main.dart`](https://github.com/a-urel/jet-cad/blob/main/packages/jet_cad_2d_flutter/example/lib/main.dart).
Run it from the package directory with `flutter run -t example/lib/main.dart`.

## Screenshots

![The same drawing on the dark canvas](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_flutter-v0.7.2/packages/jet_cad_2d_flutter/doc/screenshots/canvas_dark.png)

The same drawing on the dark canvas: `canvasResolverFor` and `ChromePalette.dark` re-tone the colours for a dark theme.

![A selection with its grips, and one entity highlighted under the pointer](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_flutter-v0.7.2/packages/jet_cad_2d_flutter/doc/screenshots/selection_grips.png)

A few entities selected, each with its grips, and one entity highlighted under the pointer.

![A crossing selection band, dragged right to left](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_flutter-v0.7.2/packages/jet_cad_2d_flutter/doc/screenshots/selection_band.png)

A crossing band, dragged right to left, mid-drag: it selects what it touches, not only what it encloses.

![SymbolGallery with the Bathroom category open](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_flutter-v0.7.2/packages/jet_cad_2d_flutter/doc/screenshots/symbol_gallery.png)

`SymbolGallery`: a furniture library in collapsible categories of thumbnails, the Bathroom category open.

These pictures are made by `tool/screenshots` in the repository, with the app's own theme.

## The API

`package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` is the API. Nothing under
`src/` is. `package:jet_cad_2d_flutter/export_testing.dart` is a test
instrument for this repository's own suites; it is not API and may change in
any release.

While the version is `0.x`, a minor release (`0.8.0`) may break the API, and a
patch release (`0.7.2`) does not.

## The jet-cad packages

| Package | What it is | Depends on |
|---|---|---|
| [`jet_cad_floor_plan`](https://pub.dev/packages/jet_cad_floor_plan) | The embeddable floor planner and its host API | the renderer and the engine |
| [`jet_cad_2d_flutter`](https://pub.dev/packages/jet_cad_2d_flutter) | Flutter rendering and interaction | the engine |
| [`jet_cad_2d`](https://pub.dev/packages/jet_cad_2d) | The pure-Dart engine and document model | nothing of jet-cad |

A host that embeds the planner adds only `jet_cad_floor_plan`; the other two
come with it, and a host should not also depend on them directly unless it
uses their API itself.

Embedding the floor planner in an app is walked through in the
[host guide](https://github.com/a-urel/jet-cad/blob/main/docs/host-guide.md).

## Support

If jet-cad is useful to you, you can support its development through
[GitHub Sponsors](https://github.com/sponsors/a-urel) or
[Buy Me a Coffee](https://buymeacoffee.com/yazemo).

## License

Apache License 2.0. See [LICENSE](LICENSE).
