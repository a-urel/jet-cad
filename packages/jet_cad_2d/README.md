# jet_cad_2d

A pure-Dart 2D CAD engine and document model. It has no Flutter dependency,
no FFI and no native build, and runs anywhere Dart runs: the VM, the web
(JavaScript and Wasm) and every Flutter platform.

## What it holds

- **A document**: a scene tree of groups, definitions and instances over
  columnar entity and geometry stores (points, lines, polylines, circles,
  arcs, text, attributes and fills), layers, linetypes and text styles, and
  typed components attached to nodes.
- **Commands with undo**: every edit is a command run through the document's
  dispatcher, undoable and redoable, compound commands included.
- **A spatial index** that follows each edit synchronously: rectangle
  queries, picking with the full path through nested instances, and object
  snapping. In steady state the frame-path queries allocate nothing per
  entity; a pick or a snap allocates a few objects per level of instance
  nesting, whatever the document's size.
- **A deterministic file format**: a JSON codec that writes a document back
  byte for byte. It keeps the fields and components it does not recognise
  (another application's components, for instance) and writes them back
  unchanged; a file with a newer schema version is refused with
  `SchemaVersionError`.
- **A parametric layer**: object types an application registers are
  regenerated inside the edit that changes them, in the same undo step.

## Example

The snippet uses `vector_math` for its points, so add both:
`dart pub add jet_cad_2d vector_math`.

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

void main() {
  final doc = DraftDocument.empty();
  final circle = addDrafted(
      doc, EntityKind.circle, circlePayload(Vector2(300, 250), 50),
      layer: ReservedHandles.layerZero);
  doc.commands.execute(circle);

  final index = SpatialIndex(doc);
  final hit = HitPath();
  if (index.pickInto(Vector2(300, 301), 2, const QueryFilter.picking(), hit)) {
    print(hit.entity == circle.record.handle); // true
  }

  doc.commands.undo(); // the circle is gone, and the index knows it
  print(DraftDocumentCodec.encodeToString(doc));
}
```

The full walk-through, which also saves and reloads the document, is in
[`example/jet_cad_2d_example.dart`](https://github.com/a-urel/jet-cad/blob/main/packages/jet_cad_2d/example/jet_cad_2d_example.dart).

## The API

`package:jet_cad_2d/jet_cad_2d.dart` is the API. Nothing under `src/` is.
`package:jet_cad_2d/testing.dart` generates benchmark documents for this
repository's own suites; it is not API and may change in any release.

While the version is `0.x`, a minor release (`0.8.0`) may break the API, and a
patch release (`0.7.3`) does not.

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
