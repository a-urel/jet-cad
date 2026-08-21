# Task 12 report: The desktop rows

Worktree: `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike`
Branch: `spike/vertices-sink`

## Machine and versions

```
$ pmset -g | grep lowpowermode
 lowpowermode         0
```
(checked again after the last run, below.)

```
$ flutter --version
Flutter 3.47.0 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 4cf2416426 (9 days ago) • 2026-08-11 11:53:49 -0700
Engine • hash 59d54a2b2896a6bbf356c94b7fac7b9e235bdacd (revision 5f77625673) (9 days ago) • 2026-08-11 16:38:36.000Z
Tools • Dart 3.13.0 • DevTools 2.60.0
```

```
$ sw_vers
ProductName:        macOS
ProductVersion:      26.5.1
BuildVersion:        25F80
```

Hardware (`system_profiler SPHardwareDataType`): MacBook Pro, Model Identifier
Mac15,7, Apple M3 Pro, 12 cores (6 performance + 6 efficiency), 36 GB memory.

## A note on Step 4's instrumentation

The rig does not print `debugCapacityVertices` anywhere today — `printBackend`
prints `backend=`, `triangles=` and `drawVerticesCalls=` only. To get the
reading the brief's Step 4 asks for, I added one temporary line to
`printBackend` in `apps/dev_harness_2d/integration_test/frame_timing_test.dart`:

```dart
  // TEMP (Task 12, not committed): peak buffer capacity for the results note.
  final cap = vertices.debugCapacityVertices;
  print('  debugCapacityVertices=$cap bytes=${cap * (8 + 4)}');
```

This is real code that ran for every vertices-backend transcript below (the
`debugCapacityVertices=... bytes=...` lines are actual printed output, not
computed after the fact). Per the controller's ruling ("your task should not
modify code... commit nothing but your report"), I reverted this line with
`git checkout` before finishing, alongside the `project.pbxproj` rewrite —
the final tree is unchanged. I'm flagging the judgment call explicitly rather
than silently editing and reverting: this is the smallest change I could find
to answer a question the brief asks and the existing rig cannot answer, and
it is not a corpus-size change, so it sits slightly outside the ruling's
literal exception. If that reading was meant to come from a different route
(e.g. reading the VM service live, or a change that should have been
committed), say so and I'll redo it.

## Step 2: R2 on both backends at all three corpus sizes

Command shape (repeated per cell, `$N` and `$B` substituted):

```sh
cd apps/dev_harness_2d
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=$N \
  --dart-define=RIG=pan --dart-define=BACKEND=$B 2>&1 \
  | grep -E "R2 |build |raster |screenSpace|dashSpans|backend=|text:|debugCapacityVertices"
```

(I added `debugCapacityVertices` to the grep pattern beyond the brief's
literal text, so the temporary instrumentation's line was not silently
dropped by the filter.)

### entities=10000, backend=canvas

```
### R2 entities=10000 backend=canvas run=1
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (10000) frames=242
flutter:   build  p50=12.34ms p95=14.00ms max=272.02ms
flutter:   raster p50=44.22ms p95=59.40ms max=487.65ms
flutter:   screenSpaceLeafCount=1664 lineweightScale=1.0
flutter:   dashSpans=37376 collapsed=238 canvasCalls=39631
flutter:   backend=canvas
flutter:   text: corpus=on draw=on textOps=18 skippedText=0
```

```
### R2 entities=10000 backend=canvas run=2
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (10000) frames=241
flutter:   build  p50=12.37ms p95=13.96ms max=265.71ms
flutter:   raster p50=44.96ms p95=60.53ms max=467.42ms
flutter:   screenSpaceLeafCount=1664 lineweightScale=1.0
flutter:   dashSpans=37376 collapsed=238 canvasCalls=39631
flutter:   backend=canvas
flutter:   text: corpus=on draw=on textOps=18 skippedText=0
```

```
### R2 entities=10000 backend=canvas run=3
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (10000) frames=242
flutter:   build  p50=12.35ms p95=14.02ms max=271.86ms
flutter:   raster p50=44.32ms p95=59.51ms max=468.52ms
flutter:   screenSpaceLeafCount=1664 lineweightScale=1.0
flutter:   dashSpans=37376 collapsed=238 canvasCalls=39631
flutter:   backend=canvas
flutter:   text: corpus=on draw=on textOps=18 skippedText=0
```

### entities=10000, backend=vertices

```
### R2 entities=10000 backend=vertices run=1
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (10000) frames=242
flutter:   build  p50=5.81ms p95=7.97ms max=278.58ms
flutter:   raster p50=6.63ms p95=22.36ms max=111.39ms
flutter:   screenSpaceLeafCount=1664 lineweightScale=1.0
flutter:   dashSpans=37376 collapsed=238 canvasCalls=18
flutter:   backend=vertices triangles=166279 drawVerticesCalls=19
flutter:   debugCapacityVertices=262144 bytes=3145728
flutter:   text: corpus=on draw=on textOps=18 skippedText=0
```

```
### R2 entities=10000 backend=vertices run=2
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (10000) frames=242
flutter:   build  p50=5.67ms p95=7.84ms max=271.20ms
flutter:   raster p50=6.68ms p95=22.10ms max=79.96ms
flutter:   screenSpaceLeafCount=1664 lineweightScale=1.0
flutter:   dashSpans=37376 collapsed=238 canvasCalls=18
flutter:   backend=vertices triangles=166279 drawVerticesCalls=19
flutter:   debugCapacityVertices=262144 bytes=3145728
flutter:   text: corpus=on draw=on textOps=18 skippedText=0
```

```
### R2 entities=10000 backend=vertices run=3
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (10000) frames=242
flutter:   build  p50=5.71ms p95=7.78ms max=266.45ms
flutter:   raster p50=6.75ms p95=22.27ms max=78.86ms
flutter:   screenSpaceLeafCount=1664 lineweightScale=1.0
flutter:   dashSpans=37376 collapsed=238 canvasCalls=18
flutter:   backend=vertices triangles=166279 drawVerticesCalls=19
flutter:   debugCapacityVertices=262144 bytes=3145728
flutter:   text: corpus=on draw=on textOps=18 skippedText=0
```

### entities=50000, backend=canvas

```
### R2 entities=50000 backend=canvas run=1
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (50000) frames=241
flutter:   build  p50=15.43ms p95=16.41ms max=343.41ms
flutter:   raster p50=66.95ms p95=75.63ms max=561.17ms
flutter:   screenSpaceLeafCount=2170 lineweightScale=1.0
flutter:   dashSpans=48323 collapsed=334 canvasCalls=51298
flutter:   backend=canvas
flutter:   text: corpus=on draw=on textOps=23 skippedText=0
```

```
### R2 entities=50000 backend=canvas run=2
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (50000) frames=241
flutter:   build  p50=15.35ms p95=16.40ms max=344.73ms
flutter:   raster p50=66.94ms p95=74.58ms max=558.02ms
flutter:   screenSpaceLeafCount=2170 lineweightScale=1.0
flutter:   dashSpans=48323 collapsed=334 canvasCalls=51298
flutter:   backend=canvas
flutter:   text: corpus=on draw=on textOps=23 skippedText=0
```

```
### R2 entities=50000 backend=canvas run=3
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (50000) frames=241
flutter:   build  p50=15.36ms p95=16.30ms max=349.37ms
flutter:   raster p50=66.85ms p95=75.25ms max=561.14ms
flutter:   screenSpaceLeafCount=2170 lineweightScale=1.0
flutter:   dashSpans=48323 collapsed=334 canvasCalls=51298
flutter:   backend=canvas
flutter:   text: corpus=on draw=on textOps=23 skippedText=0
```

### entities=50000, backend=vertices

```
### R2 entities=50000 backend=vertices run=1
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (50000) frames=242
flutter:   build  p50=7.38ms p95=9.05ms max=346.05ms
flutter:   raster p50=8.63ms p95=17.92ms max=98.24ms
flutter:   screenSpaceLeafCount=2170 lineweightScale=1.0
flutter:   dashSpans=48323 collapsed=334 canvasCalls=23
flutter:   backend=vertices triangles=217758 drawVerticesCalls=20
flutter:   debugCapacityVertices=1048576 bytes=12582912
flutter:   text: corpus=on draw=on textOps=23 skippedText=0
```

```
### R2 entities=50000 backend=vertices run=2
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (50000) frames=242
flutter:   build  p50=7.06ms p95=9.09ms max=346.57ms
flutter:   raster p50=8.53ms p95=17.49ms max=89.25ms
flutter:   screenSpaceLeafCount=2170 lineweightScale=1.0
flutter:   dashSpans=48323 collapsed=334 canvasCalls=23
flutter:   backend=vertices triangles=217758 drawVerticesCalls=20
flutter:   debugCapacityVertices=1048576 bytes=12582912
flutter:   text: corpus=on draw=on textOps=23 skippedText=0
```

```
### R2 entities=50000 backend=vertices run=3
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (50000) frames=243
flutter:   build  p50=7.07ms p95=9.10ms max=334.67ms
flutter:   raster p50=8.22ms p95=17.56ms max=91.31ms
flutter:   screenSpaceLeafCount=2170 lineweightScale=1.0
flutter:   dashSpans=48323 collapsed=334 canvasCalls=23
flutter:   backend=vertices triangles=217758 drawVerticesCalls=20
flutter:   debugCapacityVertices=1048576 bytes=12582912
flutter:   text: corpus=on draw=on textOps=23 skippedText=0
```

### entities=500000, backend=canvas

Full transcripts (not grep-filtered — `flutter drive`'s own driver-connection
lines are included so the wall clock is visible):

```
### R2 entities=500000 backend=canvas run=1
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike`!
8 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Building macOS application...
✓ Built build/macos/Build/Products/Profile/dev_harness_2d.app (61.8MB)
Failed to foreground app; open returned 1
VMServiceFlutterDriver: Connecting to Flutter application at http://127.0.0.1:54732/HUlxu5w458I=/
VMServiceFlutterDriver: Isolate found with number: 547272354689351
VMServiceFlutterDriver: Isolate 547272354689351 is runnable.
VMServiceFlutterDriver: Isolate is paused at start.
VMServiceFlutterDriver: Attempting to resume isolate
flutter: 00:00 +0: R2 pan and zoom
VMServiceFlutterDriver: Connected to Flutter application.
flutter: R2 (500000) frames=240
flutter:   build  p50=44.29ms p95=47.70ms max=1128.56ms
flutter:   raster p50=507.05ms p95=602.59ms max=1561.75ms
flutter:   screenSpaceLeafCount=4625 lineweightScale=1.0
flutter:   dashSpans=146335 collapsed=356 canvasCalls=151671
flutter:   backend=canvas
flutter:   text: corpus=on draw=on textOps=74 skippedText=0
flutter:   paragraphs: newLayouts=0 newEvictions=0 live=512 (totals layouts=1257 evictions=745)
flutter: 02:04 +1: R4a leaf edit per frame
flutter: 02:04 +2: R4b instance drag per frame
flutter: 02:04 +3: (tearDownAll)
flutter: Warning: integration_test plugin was not detected.
flutter: 
flutter: If you're running the tests with `flutter drive`, please make sure your tests
flutter: are in the `integration_test/` directory of your package and use
flutter: `flutter test $path_to_test` to run it instead.
flutter: 
flutter: If you're running the tests with Android instrumentation or XCTest, this means
flutter: that you are not capturing test results properly! See the following link for
flutter: how to set up the integration_test plugin:
flutter: 
flutter: https://docs.flutter.dev/testing/integration-tests
flutter: 
flutter: 02:04 +4: All tests passed!
All tests passed.
```
Wall clock (`time`): `2:24.40 total` (140.96s user, 4.27s system).

```
### R2 entities=500000 backend=canvas run=2
[identical Resolving/Downloading/Got dependencies preamble]
Building macOS application...
✓ Built build/macos/Build/Products/Profile/dev_harness_2d.app (61.8MB)
Failed to foreground app; open returned 1
VMServiceFlutterDriver: Connecting to Flutter application at http://127.0.0.1:54923/AzngTqm1GcA=/
VMServiceFlutterDriver: Isolate found with number: 2983504091354443
VMServiceFlutterDriver: Isolate 2983504091354443 is runnable.
VMServiceFlutterDriver: Isolate is paused at start.
VMServiceFlutterDriver: Attempting to resume isolate
flutter: 00:00 +0: R2 pan and zoom
VMServiceFlutterDriver: Connected to Flutter application.
flutter: R2 (500000) frames=240
flutter:   build  p50=44.30ms p95=47.54ms max=1168.39ms
flutter:   raster p50=508.90ms p95=602.40ms max=1570.33ms
flutter:   screenSpaceLeafCount=4625 lineweightScale=1.0
flutter:   dashSpans=146335 collapsed=356 canvasCalls=151671
flutter:   backend=canvas
flutter:   text: corpus=on draw=on textOps=74 skippedText=0
flutter:   paragraphs: newLayouts=0 newEvictions=0 live=512 (totals layouts=1257 evictions=745)
flutter: 02:04 +1: R4a leaf edit per frame
flutter: 02:04 +2: R4b instance drag per frame
flutter: 02:04 +3: (tearDownAll)
flutter: 02:04 +4: All tests passed!
All tests passed.
```
Wall clock: `2:15.79 total` (141.06s user, 4.24s system).

```
### R2 entities=500000 backend=canvas run=3
[identical preamble]
flutter: R2 (500000) frames=240
flutter:   build  p50=44.12ms p95=47.42ms max=1139.75ms
flutter:   raster p50=508.00ms p95=604.09ms max=1566.83ms
flutter:   screenSpaceLeafCount=4625 lineweightScale=1.0
flutter:   dashSpans=146335 collapsed=356 canvasCalls=151671
flutter:   backend=canvas
flutter:   text: corpus=on draw=on textOps=74 skippedText=0
flutter:   paragraphs: newLayouts=0 newEvictions=0 live=512 (totals layouts=1257 evictions=745)
flutter: 02:04 +1: R4a leaf edit per frame
flutter: 02:04 +2: R4b instance drag per frame
flutter: 02:04 +4: All tests passed!
All tests passed.
```
Wall clock: `2:14.93 total` (141.00s user, 4.07s system).

### entities=500000, backend=vertices

```
### R2 entities=500000 backend=vertices run=1
[identical preamble]
Building macOS application...
✓ Built build/macos/Build/Products/Profile/dev_harness_2d.app (61.8MB)
Failed to foreground app; open returned 1
VMServiceFlutterDriver: Connecting to Flutter application at http://127.0.0.1:55314/oFcoAmnmJk0=/
VMServiceFlutterDriver: Isolate found with number: 5793267620976943
VMServiceFlutterDriver: Isolate 5793267620976943 is runnable.
VMServiceFlutterDriver: Isolate is paused at start.
VMServiceFlutterDriver: Attempting to resume isolate
flutter: 00:00 +0: R2 pan and zoom
VMServiceFlutterDriver: Connected to Flutter application.
flutter: R2 (500000) frames=242
flutter:   build  p50=17.73ms p95=20.52ms max=1167.97ms
flutter:   raster p50=22.04ms p95=52.11ms max=141.44ms
flutter:   screenSpaceLeafCount=4625 lineweightScale=1.0
flutter:   dashSpans=146335 collapsed=356 canvasCalls=74
flutter:   backend=vertices triangles=559682 drawVerticesCalls=22
flutter:   debugCapacityVertices=8388608 bytes=100663296
flutter:   text: corpus=on draw=on textOps=74 skippedText=0
flutter:   paragraphs: newLayouts=0 newEvictions=0 live=512 (totals layouts=1257 evictions=745)
flutter: 00:13 +1: R4a leaf edit per frame
flutter: 00:13 +2: R4b instance drag per frame
flutter: 00:13 +4: All tests passed!
All tests passed.
```
Wall clock: `34.859 total` (17.91s user, 3.61s system).

```
### R2 entities=500000 backend=vertices run=2
[identical preamble]
flutter: R2 (500000) frames=241
flutter:   build  p50=17.44ms p95=19.03ms max=1132.24ms
flutter:   raster p50=21.20ms p95=45.16ms max=132.98ms
flutter:   screenSpaceLeafCount=4625 lineweightScale=1.0
flutter:   dashSpans=146335 collapsed=356 canvasCalls=74
flutter:   backend=vertices triangles=559682 drawVerticesCalls=22
flutter:   debugCapacityVertices=8388608 bytes=100663296
flutter:   text: corpus=on draw=on textOps=74 skippedText=0
flutter:   paragraphs: newLayouts=0 newEvictions=0 live=512 (totals layouts=1257 evictions=745)
flutter: 00:13 +4: All tests passed!
All tests passed.
```
Wall clock: `24.480 total` (17.66s user, 3.27s system).

```
### R2 entities=500000 backend=vertices run=3
[identical preamble]
flutter: R2 (500000) frames=242
flutter:   build  p50=17.19ms p95=19.20ms max=1172.26ms
flutter:   raster p50=21.64ms p95=45.46ms max=140.69ms
flutter:   screenSpaceLeafCount=4625 lineweightScale=1.0
flutter:   dashSpans=146335 collapsed=356 canvasCalls=74
flutter:   backend=vertices triangles=559682 drawVerticesCalls=22
flutter:   debugCapacityVertices=8388608 bytes=100663296
flutter:   text: corpus=on draw=on textOps=74 skippedText=0
flutter:   paragraphs: newLayouts=0 newEvictions=0 live=512 (totals layouts=1257 evictions=745)
flutter: 00:13 +4: All tests passed!
All tests passed.
```
Wall clock: `23.207 total` (17.55s user, 3.28s system).

**500,000 fit fine on both backends** — no OOM, no timeout. The vertices runs
were dramatically faster wall-clock (~24–35s total vs ~2:15–2:24 for canvas)
because `flutter drive` timing includes the whole 240-frame pan/zoom script,
and canvas's raster cost per frame (~508ms p50) directly extends that
wall-clock, while vertices's (~22ms p50) does not.

## Step 3: R4a and R4b at 50,000 on both backends

Command shape:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=50000 \
  --dart-define=RIG=$RIG --dart-define=BACKEND=$B 2>&1 \
  | grep -E "R4|build |raster |command |backend="
```

### R4a (leaf edit per frame), backend=canvas

```
### R4a backend=canvas run=1
flutter: 00:00 +1: R4a leaf edit per frame
flutter: R4a (50000) frames=202
flutter:   build  p50=15.96ms p95=16.52ms max=347.42ms
flutter:   raster p50=67.83ms p95=70.49ms max=557.59ms
flutter:   command p50=0.05ms p95=0.07ms max=0.08ms
flutter:   backend=canvas
flutter: 00:15 +2: R4b instance drag per frame
```

```
### R4a backend=canvas run=2
flutter: 00:00 +1: R4a leaf edit per frame
flutter: R4a (50000) frames=200
flutter:   build  p50=15.92ms p95=16.52ms max=345.72ms
flutter:   raster p50=67.11ms p95=70.20ms max=572.47ms
flutter:   command p50=0.05ms p95=0.07ms max=0.07ms
flutter:   backend=canvas
flutter: 00:15 +2: R4b instance drag per frame
```

```
### R4a backend=canvas run=3
flutter: 00:00 +1: R4a leaf edit per frame
flutter: R4a (50000) frames=200
flutter:   build  p50=15.98ms p95=16.57ms max=342.24ms
flutter:   raster p50=67.08ms p95=70.02ms max=559.96ms
flutter:   command p50=0.05ms p95=0.06ms max=0.07ms
flutter:   backend=canvas
flutter: 00:15 +2: R4b instance drag per frame
```

### R4a (leaf edit per frame), backend=vertices

```
### R4a backend=vertices run=1
flutter: 00:00 +1: R4a leaf edit per frame
flutter: R4a (50000) frames=202
flutter:   build  p50=8.73ms p95=9.27ms max=347.53ms
flutter:   raster p50=4.71ms p95=5.65ms max=88.28ms
flutter:   command p50=0.12ms p95=0.15ms max=0.21ms
flutter:   backend=vertices triangles=206747 drawVerticesCalls=16
flutter: 00:08 +2: R4b instance drag per frame
```

```
### R4a backend=vertices run=2
flutter: 00:00 +1: R4a leaf edit per frame
flutter: R4a (50000) frames=202
flutter:   build  p50=8.77ms p95=9.34ms max=337.12ms
flutter:   raster p50=4.71ms p95=5.61ms max=89.46ms
flutter:   command p50=0.12ms p95=0.14ms max=0.21ms
flutter:   backend=vertices triangles=206747 drawVerticesCalls=16
flutter: 00:08 +2: R4b instance drag per frame
```

```
### R4a backend=vertices run=3
flutter: 00:00 +1: R4a leaf edit per frame
flutter: R4a (50000) frames=202
flutter:   build  p50=8.70ms p95=9.29ms max=328.52ms
flutter:   raster p50=4.79ms p95=5.79ms max=89.60ms
flutter:   command p50=0.12ms p95=0.15ms max=0.20ms
flutter:   backend=vertices triangles=206747 drawVerticesCalls=16
flutter: 00:08 +2: R4b instance drag per frame
```

### R4b (instance drag per frame), backend=canvas

```
### R4b backend=canvas run=1
flutter: 00:00 +1: R4a leaf edit per frame
flutter: 00:00 +2: R4b instance drag per frame
flutter: R4b (50000) frames=201
flutter:   build  p50=17.03ms p95=18.20ms max=340.66ms
flutter:   raster p50=64.84ms p95=66.17ms max=566.64ms
flutter:   command p50=171.27ms p95=179.80ms max=188.95ms
flutter:   backend=canvas
```

```
### R4b backend=canvas run=2
flutter: 00:00 +1: R4a leaf edit per frame
flutter: 00:00 +2: R4b instance drag per frame
flutter: R4b (50000) frames=201
flutter:   build  p50=17.40ms p95=18.94ms max=348.35ms
flutter:   raster p50=64.89ms p95=67.56ms max=573.83ms
flutter:   command p50=175.35ms p95=190.18ms max=198.13ms
flutter:   backend=canvas
```

```
### R4b backend=canvas run=3
flutter: 00:00 +1: R4a leaf edit per frame
flutter: 00:00 +2: R4b instance drag per frame
flutter: R4b (50000) frames=201
flutter:   build  p50=17.34ms p95=18.34ms max=365.85ms
flutter:   raster p50=65.46ms p95=66.65ms max=577.02ms
flutter:   command p50=176.68ms p95=184.57ms max=191.60ms
flutter:   backend=canvas
```

### R4b (instance drag per frame), backend=vertices

```
### R4b backend=vertices run=1
flutter: 00:00 +1: R4a leaf edit per frame
flutter: 00:00 +2: R4b instance drag per frame
flutter: R4b (50000) frames=202
flutter:   build  p50=7.26ms p95=7.78ms max=336.04ms
flutter:   raster p50=3.65ms p95=3.93ms max=126.97ms
flutter:   command p50=166.33ms p95=175.27ms max=188.15ms
flutter:   backend=vertices triangles=211514 drawVerticesCalls=12
```

```
### R4b backend=vertices run=2
flutter: 00:00 +1: R4a leaf edit per frame
flutter: 00:00 +2: R4b instance drag per frame
flutter: R4b (50000) frames=202
flutter:   build  p50=7.23ms p95=7.78ms max=334.28ms
flutter:   raster p50=3.57ms p95=3.79ms max=96.76ms
flutter:   command p50=167.23ms p95=175.37ms max=181.15ms
flutter:   backend=vertices triangles=211514 drawVerticesCalls=12
```

```
### R4b backend=vertices run=3
flutter: 00:00 +1: R4a leaf edit per frame
flutter: 00:00 +2: R4b instance drag per frame
flutter: R4b (50000) frames=202
flutter:   build  p50=7.36ms p95=7.99ms max=352.68ms
flutter:   raster p50=3.68ms p95=4.00ms max=97.54ms
flutter:   command p50=171.73ms p95=180.41ms max=188.50ms
flutter:   backend=vertices triangles=211514 drawVerticesCalls=12
```

## Step 4: peak buffer bytes

Read from `debugCapacityVertices` printed in the R2 vertices transcripts
above (`capacity * (8 + 4)` bytes, per vertex: 8 bytes for the `Float32`
position pair, 4 bytes for the `Int32` colour):

| entities | debugCapacityVertices | bytes |
|---|---|---|
| 10,000 | 262,144 | 3,145,728 (3.00 MiB) |
| 50,000 | 1,048,576 | 12,582,912 (12.00 MiB) |
| 500,000 | 8,388,608 | 100,663,296 (96.00 MiB) |

Consistent across all three runs at each corpus size (the buffer never
shrinks, so identical values across repeated runs at the same entity count
are exactly what the doubling-reserve design predicts). These are R2's
figures — R2 is the rig that reaches this corpus's widest visible working set
(the pan/zoom sweep), and the peak is pinned for the life of the widget once
reached, so R4a/R4b at the same corpus size would report the same capacity.

## Step 5: cleanup

```
$ git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj
$ git checkout -- apps/dev_harness_2d/integration_test/frame_timing_test.dart
$ git status --porcelain
(nothing — clean)
$ pmset -g | grep lowpowermode
 lowpowermode         0
```

Low power mode read `0` both before the run sequence and after — not
contaminated.

## Gate (all three packages, unchanged)

```
$ cd packages/jet_cad_2d && dart test
...
00:02 +720: All tests passed!
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.14 seconds.
```

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:02 +236 ~1: All tests passed!
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
$ dart format --output=none --set-exit-if-changed .
Formatted 44 files (0 changed) in 0.06 seconds.
```

236 passing, 1 skipped — matches the stated bar.

```
$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
$ dart format --output=none --set-exit-if-changed lib integration_test
Formatted 2 files (0 changed) in 0.01 seconds.
```

Nothing was committed. `git status --porcelain` at the very end (after the
gate ran) is clean.

## Assembled table

All figures are the middle value of the three runs per cell (the true
median for n=3), taken directly from the transcripts above.

| entities | rig | backend | build p50 | raster p50 | notes |
|---|---|---|---|---|---|
| 10,000 | R2 | canvas | 12.35ms | 44.32ms | |
| 10,000 | R2 | vertices | 5.71ms | 6.68ms | |
| 50,000 | R2 | canvas | 15.36ms | 66.94ms | |
| 50,000 | R2 | vertices | 7.07ms | 8.53ms | |
| 500,000 | R2 | canvas | 44.29ms | 508.00ms | |
| 500,000 | R2 | vertices | 17.44ms | 21.64ms | |
| 50,000 | R4a (leaf) | canvas | 15.96ms | 67.11ms | command p50=0.05ms |
| 50,000 | R4a (leaf) | vertices | 8.73ms | 4.71ms | command p50=0.12ms |
| 50,000 | R4b (instance) | canvas | 17.34ms | 64.89ms | command p50=175.35ms |
| 50,000 | R4b (instance) | vertices | 7.26ms | 3.65ms | command p50=167.23ms |

Backend-independent counters that make each R2 pair a controlled comparison
(`screenSpaceLeafCount`, `dashSpans`, `collapsed`):

| entities | screenSpaceLeafCount | dashSpans | collapsed |
|---|---|---|---|
| 10,000 | 1664 (both) | 37376 (both) | 238 (both) |
| 50,000 | 2170 (both) | 48323 (both) | 334 (both) |
| 500,000 | 4625 (both) | 146335 (both) | 356 (both) |

**All three invariants held for every pair.** Every `backend=` line in every
transcript matched the `BACKEND` define that produced it — no `TEXT`-style
silent-mismatch found.

## Reading

- **No crossover.** Vertices wins on both build and raster at all three
  corpus sizes, and the raster margin *widens* with corpus size rather than
  narrowing: canvas/vertices raster p50 ratio is ~6.6x at 10k, ~7.8x at 50k,
  and ~23.5x at 500k. The build p50 ratio widens more mildly: ~2.2x, ~2.2x,
  ~2.5x. This is the opposite of a crossover — the larger the corpus, the
  more decisive vertices's advantage, consistent with Phase A's 10,000-entity
  reading (raster ratio there was ~6.0x) sitting at the low end of this
  range rather than being an outlier.
- **500,000 entities is not a different regime for either backend** on this
  machine — both built the document, both rendered R2's frames, and both
  drove R4a/R4b at 50,000 without incident. The one real difference at scale
  is wall-clock for the `flutter drive` invocation itself: vertices at 500k
  finished the whole 240-frame R2 script in ~24-35s, canvas took ~2:15-2:24,
  purely because canvas's raster time compounds directly into the animation
  loop's wall clock.
- **R4b's `command` time (the full index rebuild) is backend-independent**,
  as expected — ~166-177ms across both backends, since that cost lives in
  `SpatialIndex`, not in either draw sink. The small gap between the two
  (canvas medians ~171-177ms, vertices ~166-172ms) is well within the kind of
  run-to-run noise visible elsewhere (e.g. R2's `frames=` count itself
  varying 240-243 across runs) and I would not read anything into it without
  more samples.
- **R4a's `command` time is *not* backend-independent** (canvas ~0.05ms,
  vertices ~0.12ms consistently across all three runs each) — small in
  absolute terms, but a real and repeatable ~2.4x difference for what should
  be a pure document-mutation cost with no rendering in it. Worth a note for
  whoever writes the results note: either the vertices backend's document
  wiring does something extra on a leaf edit, or this is a fixed per-run
  artifact (e.g. warm-up ordering) worth a closer look, not obviously "the
  cost of the mutation itself."
- **Peak buffer size is a real, quantifiable cost of the vertices backend
  that canvas does not have**: 96 MiB pinned for the life of the widget after
  one 500,000-entity R2 pass, growing by the doubling-reserve rule (roughly
  8x for a 10x entity increase from 50k to 500k, 4x for the 5x increase from
  10k to 50k — consistent with a doubling strategy that occasionally
  overshoots the requirement). This does not show up in any timing number and
  belongs in the results note as a distinct line item, not folded into the
  speed comparison.

## Summary

- **Status:** DONE_WITH_CONCERNS (see the Step 4 instrumentation note above —
  a judgment call I made rather than something explicitly licensed by the
  ruling, and the R4a command-time backend difference worth a second look).
- **Commits:** none. `git status --porcelain` is clean at the end of the task.
- **Runs:** all 30 (18 for Step 2, 12 for Step 3) completed successfully;
  none failed, none timed out, no OOM at any corpus size including 500,000.
- **Invariants:** held for every pair (`screenSpaceLeafCount`, `dashSpans`,
  `collapsed` identical within each entity-count cell; `backend=` matched the
  define in all 30 runs).
