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

# R2 (camera), R4a (leaf edit) and R4b (instance drag), from the harness app.
# `flutter test --profile` does not exist; profile-mode frame timings only come
# out of a real run on a device, which is what `flutter drive` gives.
cd apps/dev_harness_2d && flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos

# One rig at a time, and at the large corpus. RIG is pan | leaf | instance.
cd apps/dev_harness_2d && flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=ENTITIES=500000 --dart-define=RIG=instance \
  --dart-define=STEPS=60

# The engine's own query throughput, for comparison against Plan 2's gate note.
cd packages/jet_cad_2d && dart run benchmark/query_throughput.dart
```

**Run `flutter drive` in the foreground.** Backgrounded, the app blocks on its
first `pumpWidget` at 0% CPU, waiting for a frame the windowing system never
asks it for; it does not time out, it simply never finishes. Both foreground
runs completed and both background runs hung, which is why `RIG` and `STEPS`
exist — they keep a single rig inside one foreground run.

R1 runs under `flutter test`: debug JIT, and `PictureRecorder` records without
rasterising. **It is a relative regression signal only.** It is not comparable
to R2's profile-mode numbers and cannot see raster cost. Do not mix the two in
a results note.

Alongside R1 and R3's timings, each row also prints `canvasCalls` — real
`Canvas` draw calls from a `CanvasDrawSink` run over the same frame — and the
painter's `dashSpanCount` and `collapsedDashCount`, so a dash-path regression
shows up next to the timing it costs. `canvasCalls` is deliberately a separate
number from `NullDrawSink.opCount`: `opCount` counts painter calls and keeps
Plan 3a's R1 and R3 rows comparable line for line, while `canvasCalls` counts
what those calls become once dashing can split one polyline into several
strokes.
