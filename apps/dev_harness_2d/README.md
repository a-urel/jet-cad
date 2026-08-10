# dev_harness_2d

A measurement harness for the `jet_cad_2d` render path. **Not a product.** It
exists so R2, R4a and R4b run on a real device in profile mode, where frame
timings mean something.

`lib/main.dart` is a `DraftCanvas` with pointer pan and scroll zoom wired
straight to `CameraController`. No tool architecture, no selection: tools are
Plan 4, and every line here is a line the rigs have to keep working.

## Running it by hand

```bash
flutter run --profile -d macos
flutter run --profile -d macos --dart-define=ENTITIES=500000
flutter run --profile -d macos --dart-define=BATCH=openBucket
```

Drag to pan, scroll to zoom.

`BATCH` selects the `CanvasDrawSink`'s `BatchMode`: `off` | `openBucket` |
`bucketMap` | `bucketMapBakedCurves`, defaulting to `bucketMap`. One profile
run measures one mode — this is how Plan 3b's Task 4 spike compared them.

## The rigs

`flutter test --profile` does not exist; profile-mode frame timings only come
out of a real run on a device, which is what `flutter drive` gives.

```bash
# R2, R4a and R4b at 50,000 entities
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos

# one rig at a time at 500,000. RIG is pan (R2) | leaf (R4a) | instance (R4b).
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=ENTITIES=500000 --dart-define=RIG=instance \
  --dart-define=STEPS=60

# one BatchMode at a time, for the Task 4 spike.
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=ENTITIES=500000 --dart-define=RIG=pan \
  --dart-define=BATCH=bucketMap
```

**Run these in the foreground.** Backgrounded, the app blocks on its first
`pumpWidget` at 0% CPU, waiting for a frame the windowing system never asks it
for — it does not time out, it never finishes. Both foreground runs completed
and both background runs hung. `RIG` and `STEPS` exist to keep a single rig
inside one foreground run: R4b costs a full index rebuild per step, which is
about a second each at 500,000 entities.

This is not only a risk from an explicit background flag: any driver
process that runs long enough for its caller to move it to a background
poll — a shell job control switch, an orchestrator's own timeout — can hit
the same 0% CPU stall after the switch, even if it was launched in the
foreground. During Task 4's 500k runs this happened once, mid-run, on a
`flutter drive` invocation that had been given a generous but still
finite timeout; killing the stuck `.app` process and rerunning the
identical command immediately succeeded. Treat a stalled run as a
process to kill and retry, not a number to wait out.

The file refuses to run in debug mode rather than print numbers nobody should
read.

Each rig reports `buildDuration` and `rasterDuration` separately — a
build-bound frame and a raster-bound frame call for opposite fixes, so a single
"frame time" hides the only thing the number is for.

R4a and R4b also report the **command's own wall clock**. A command runs
synchronously in the gesture handler, before the frame it causes, so the index
invalidation it triggers lands outside `buildDuration` entirely. Without that
line the rig prints "200 full index rebuilds" and "build p50 5.4 ms" side by
side, which reads as "rebuilds are free".
