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
```

Drag to pan, scroll to zoom.

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

**Task 12 found the plain kill-and-retry insufficient at 500k.** All three
500k rigs (`RIG=pan`, `RIG=leaf`, `RIG=instance`) stalled on a plain
`flutter drive` invocation; `RIG=pan` alone stalled four times in a row —
`pkill -9 -f dev_harness_2d.app` plus an identical retry did not clear it,
where it had cleared a single Task 4 stall immediately. What worked was
prefixing the command with `caffeinate -dimsu`, which kept every subsequent
500k run (all three rigs) from stalling at all, on the first attempt each
time:

```bash
caffeinate -dimsu flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=ENTITIES=500000 --dart-define=RIG=pan --dart-define=STEPS=60
```

Plain kill-and-retry is still the right first move — it is cheap and it is
what worked for the shorter runs this file was originally written against.
If it doesn't clear a stall within a couple of attempts on a run long
enough to approach your environment's own synchronous-execution ceiling
(not necessarily this project's 500k — whatever is slow enough to run long),
reach for `caffeinate -dimsu` next rather than continuing to retry the bare
command. See `docs/superpowers/notes/2026-08-11-plan-3b-results.md` for the
full investigation, including a Low Power Mode finding that (separately)
elevated the 500k build/raster figures `caffeinate` did not fix.

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

R2 also prints `screenSpaceLeafCount` (the drawn-leaf count, from
`DraftPainter`) and `lineweightScale` alongside its timings.

## Isolating per-leaf cost from per-pixel cost

Two `--dart-define`s support the controlled-experiment method Task 4c used
to separate per-leaf raster cost from per-pixel raster cost, ahead of
reaching for a profiler — see
`docs/superpowers/notes/2026-08-11-plan-3b-raster-profile.md` for the full
results.

```bash
# A: vary ENTITIES, same camera, same command otherwise — compare
# screenSpaceLeafCount and raster p50 between runs.
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=ENTITIES=500000 --dart-define=RIG=pan

# B: vary LINEWEIGHT_SCALE, everything else fixed. Multiplies every stroke's
# device-pixel width at the sink (CanvasDrawSink._widthFor) and nowhere
# else, so geometry, draw-call count and the walk stay identical — only the
# shaded pixel count changes. Inert at its default of 1.0.
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=ENTITIES=500000 --dart-define=RIG=pan \
  --dart-define=LINEWEIGHT_SCALE=4.0
```

## GPU attribution with Instruments

`flutter drive --trace-to-file=<path>` is silently inert for this app on
macOS (accepted, no error, no file — see the profiling note above). What
worked instead: build and run the *interactive* app directly (not the
integration-test rig, which is a `flutter_driver`-controlled process rather
than a normal one), attach Xcode's `xctrace` to the already-running process,
and drive it with real OS-level input.

```bash
flutter build macos --profile --dart-define=ENTITIES=500000
open build/macos/Build/Products/Profile/dev_harness_2d.app

# `--launch` leaves the target stopped and captures nothing; attach to an
# already-running instance instead. Pan by hand during the recording, or
# script it with `cliclick` (dd:/dm:/du: for drag-down/move/up).
xcrun xctrace record --template "Metal System Trace" --time-limit 15s \
  --no-prompt --output metal-trace.trace --attach dev_harness_2d

xcrun xctrace export --input metal-trace.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="metal-gpu-intervals"]' \
  --output gpu-intervals.xml
```

The exported XML interns repeated values (`<tag ref="id"/>` points back at
an earlier `<tag id="id" fmt="...">`), so summing by `gpu-channel-name` and
`process` needs a small script to resolve refs before aggregating — see the
profiling note for the approach.
