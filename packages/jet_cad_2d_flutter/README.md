# jet_cad_2d_flutter

The Flutter rendering layer for the pure-Dart `jet_cad_2d` engine. It owns the
camera, coordinate rebasing, the paint seam and the viewport widget. The engine
package stays free of `dart:ui`.

## What is here

| Piece | Job |
|---|---|
| `ViewportTransform` | world → screen, and the visible world rectangle |
| `CameraController` | pan and zoom, and the frame's rebase origin |
| `DrawSink` | the paint seam: `RecordingDrawSink` for tests, `NullDrawSink` for query-only measurement, `CanvasDrawSink` for `dart:ui` |
| `DraftPainter` | walks the document and writes to a sink. **No cache of any kind** |
| `LeafOwnerMap` | owner → leaf slots, so a small container can be drawn whole |
| `DraftCanvas` | the widget, repainting on camera and document changes and nothing else |
| `referenceWalk` | an index-free second implementation, used as the differential oracle |

`DraftPainter` is not scaffolding for the cached painter Plan 3b adds — it is
the oracle that one will be tested against, in the same role brute-force
queries played for the spatial index.

## Tests

```bash
flutter test                          # the suite, including goldens
flutter test --exclude-tags golden    # anywhere that is not macOS
```

Golden files are bytes produced by one Skia build on one platform. They were
generated and reviewed on macOS; another platform will differ by antialiasing
alone.

## Rigs

Rigs **measure**; they do not assert. They are excluded from the default suite
so its result does not depend on machine load, which is why every command below
carries `--run-skipped`.

```bash
# R1 — paint microbench, and R3 — query-only, both from the same file.
cd packages/jet_cad_2d_flutter && flutter test --tags rig --run-skipped

# R2 — profile-mode frame timing on a device, from the harness app.
cd apps/dev_harness_2d && flutter run --profile -d macos

# R4a — pan and zoom under a held gesture, from the harness app.
cd apps/dev_harness_2d && flutter run --profile -d macos --dart-define=RIG=pan

# R4b — edit damage: repaint cost per command, from the harness app.
cd apps/dev_harness_2d && flutter run --profile -d macos --dart-define=RIG=edit

# The engine's own query throughput, for comparison against Plan 2's gate note.
cd packages/jet_cad_2d && dart run benchmark/query_throughput.dart
```

R1 runs under `flutter test`: debug JIT, and `PictureRecorder` records without
rasterising. **It is a relative regression signal only.** It is not comparable
to R2's profile-mode numbers and cannot see raster cost. Do not mix the two in
a results note.

R2, R4a and R4b need the harness app, which lands with Task 16.
