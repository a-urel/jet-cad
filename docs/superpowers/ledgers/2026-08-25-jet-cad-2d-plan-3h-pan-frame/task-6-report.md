# Task 6 report: `PAN_STEP`

Commit: `fa1e408cf5f465ff0dd4a18dbd328f7f3b1f764e`

## Deviation from the brief's file list

The brief's "Files" section lists only `main.dart` and `measurement_rig.dart`.
Making `panStep` a `required` parameter of `runR2Rig` breaks compilation of
`integration_test/frame_timing_test.dart`, which also calls `runR2Rig` (this
is the file `flutter drive` actually runs for Steps 3 and 4). It was updated
to pass `panStep: kPanStep,` alongside the other named arguments — a
one-line, mechanical addition, not a design change. Included in the same
commit and in the `git add` below.

## Exact edits

### `apps/dev_harness_2d/lib/main.dart`

Added beside `_intDefine` (after its closing brace, before the
`harnessMeasurer` doc comment):

```dart
/// [_intDefine]'s sibling, for a define that is not an integer.
///
/// Same rule and the same reason: a silent default writes one run into the
/// table under a heading the command line claimed and the run did not use.
double _doubleDefine(String name, String raw, double fallback,
    {double? minimum}) {
  if (raw.isEmpty) return fallback;
  final value = double.tryParse(raw);
  if (value == null || !value.isFinite) {
    throw ArgumentError.value(raw, name, 'not a finite number');
  }
  if (minimum != null && value < minimum) {
    throw ArgumentError.value(raw, name, 'below $minimum');
  }
  return value;
}

/// The tile-pan phase's speed, in logical pixels per frame.
///
/// **A magnitude along the rig's existing direction, and unset means no
/// scaling at all.** The historical step is `Offset(-7, -3)`, magnitude
/// `sqrt(58)` = 7.615773; `PAN_STEP=7.6` would scale it by 0.99793 and make
/// the arm incomparable with every row already recorded at it. `NaN` is the
/// sentinel for unset because zero is a legal magnitude to ask about.
///
/// It reaches the **tile phase only**. R2's own pan keeps `Offset(-7, -3)`
/// unconditionally, or every prior plan's R2 row becomes incomparable.
final double kPanStep = _doubleDefine(
    'PAN_STEP', const String.fromEnvironment('PAN_STEP'), double.nan,
    minimum: 0);
```

And at the `runR2Rig(` call site inside `_driveR2` (was `:423`, now shifted
by the insertion above):

```dart
    tileCache: tileCache,
    pumpFrame: _pumpFrame,
    settle: _settle,
    panStep: kPanStep,
  );
```

### `apps/dev_harness_2d/lib/measurement_rig.dart`

`runR2Rig`'s parameter list gained `required double panStep,`, and its call
into `runTilePhases` gained `panStep: panStep,`.

`runTilePhases`'s parameter list gained `required double panStep,`. The
tile-pan call (was `:523`) was replaced with:

```dart
  await phase('tile hold', 60, Offset.zero);
  // `PAN_STEP` unset leaves the historical step untouched -- see `kPanStep`.
  const historical = Offset(-7, -3);
  final magnitude = historical.distance;
  final step = panStep.isNaN
      ? historical
      : Offset(historical.dx * panStep / magnitude,
          historical.dy * panStep / magnitude);
  print('  tile pan step: dx=${step.dx.toStringAsFixed(4)} '
      'dy=${step.dy.toStringAsFixed(4)} '
      'magnitude=${step.distance.toStringAsFixed(4)}');
  await phase('tile pan', 120, step);
  _probeBake(cache, camera, painter, sink, vertices);
```

`:357`'s `camera.panBy(const Offset(-7, -3));` inside `runR2Rig` (R2's own
pan) was **not touched** — confirmed by inspection and by the diff below,
which shows no change to that line.

### `apps/dev_harness_2d/integration_test/frame_timing_test.dart`

```dart
      pumpFrame: () => tester.pump(const Duration(milliseconds: 16)),
      settle: tester.pumpAndSettle,
      panStep: kPanStep,
    );
  });
```

### Full committed diff

```
diff --git a/apps/dev_harness_2d/integration_test/frame_timing_test.dart b/apps/dev_harness_2d/integration_test/frame_timing_test.dart
index 56304f6..42a88bc 100644
--- a/apps/dev_harness_2d/integration_test/frame_timing_test.dart
+++ b/apps/dev_harness_2d/integration_test/frame_timing_test.dart
@@ -213,6 +213,7 @@ void main() {
       tileCache: app.tileCache,
       pumpFrame: () => tester.pump(const Duration(milliseconds: 16)),
       settle: tester.pumpAndSettle,
+      panStep: kPanStep,
     );
   });
 
diff --git a/apps/dev_harness_2d/lib/main.dart b/apps/dev_harness_2d/lib/main.dart
index 9677bc0..9e7c7f4 100644
--- a/apps/dev_harness_2d/lib/main.dart
+++ b/apps/dev_harness_2d/lib/main.dart
@@ -207,6 +207,37 @@ int _intDefine(String name, String raw, int fallback, {required int minimum}) {
   return value;
 }
 
+/// [_intDefine]'s sibling, for a define that is not an integer.
+///
+/// Same rule and the same reason: a silent default writes one run into the
+/// table under a heading the command line claimed and the run did not use.
+double _doubleDefine(String name, String raw, double fallback,
+    {double? minimum}) {
+  if (raw.isEmpty) return fallback;
+  final value = double.tryParse(raw);
+  if (value == null || !value.isFinite) {
+    throw ArgumentError.value(raw, name, 'not a finite number');
+  }
+  if (minimum != null && value < minimum) {
+    throw ArgumentError.value(raw, name, 'below $minimum');
+  }
+  return value;
+}
+
+/// The tile-pan phase's speed, in logical pixels per frame.
+///
+/// **A magnitude along the rig's existing direction, and unset means no
+/// scaling at all.** The historical step is `Offset(-7, -3)`, magnitude
+/// `sqrt(58)` = 7.615773; `PAN_STEP=7.6` would scale it by 0.99793 and make
+/// the arm incomparable with every row already recorded at it. `NaN` is the
+/// sentinel for unset because zero is a legal magnitude to ask about.
+///
+/// It reaches the **tile phase only**. R2's own pan keeps `Offset(-7, -3)`
+/// unconditionally, or every prior plan's R2 row becomes incomparable.
+final double kPanStep = _doubleDefine(
+    'PAN_STEP', const String.fromEnvironment('PAN_STEP'), double.nan,
+    minimum: 0);
+
 /// The one measurer the harness document is built with, reachable from
 /// `_HarnessState.dispose` so the native paragraphs it holds are released.
 ///
@@ -433,6 +464,7 @@ Future<void> _driveR2(
     tileCache: tileCache,
     pumpFrame: _pumpFrame,
     settle: _settle,
+    panStep: kPanStep,
   );
   print('R2 app-run: done');
 }
diff --git a/apps/dev_harness_2d/lib/measurement_rig.dart b/apps/dev_harness_2d/lib/measurement_rig.dart
index ea2fa63..b982709 100644
--- a/apps/dev_harness_2d/lib/measurement_rig.dart
+++ b/apps/dev_harness_2d/lib/measurement_rig.dart
@@ -340,6 +340,7 @@ Future<void> runR2Rig({
   required TileCache? tileCache,
   required Future<void> Function() pumpFrame,
   required Future<void> Function() settle,
+  required double panStep,
 }) async {
   refuseDebugMode();
   final timings = <FrameTiming>[];
@@ -402,6 +403,7 @@ Future<void> runR2Rig({
         pumpFrame: pumpFrame,
         settle: settle,
         setBucket: (b) => bucket = b,
+        panStep: panStep,
       );
     }
   } finally {
@@ -456,6 +458,7 @@ Future<void> runTilePhases({
   required Future<void> Function() pumpFrame,
   required Future<void> Function() settle,
   required void Function(List<FrameTiming>) setBucket,
+  required double panStep,
 }) async {
   // Fill the generation the zoom phase left stale. Bounded, and the bound is
   // reported: a run that hit it never reached a warm cache and its hold
@@ -520,7 +523,17 @@ Future<void> runTilePhases({
   }
 
   await phase('tile hold', 60, Offset.zero);
-  await phase('tile pan', 120, const Offset(-7, -3));
+  // `PAN_STEP` unset leaves the historical step untouched -- see `kPanStep`.
+  const historical = Offset(-7, -3);
+  final magnitude = historical.distance;
+  final step = panStep.isNaN
+      ? historical
+      : Offset(historical.dx * panStep / magnitude,
+          historical.dy * panStep / magnitude);
+  print('  tile pan step: dx=${step.dx.toStringAsFixed(4)} '
+      'dy=${step.dy.toStringAsFixed(4)} '
+      'magnitude=${step.distance.toStringAsFixed(4)}');
+  await phase('tile pan', 120, step);
   _probeBake(cache, camera, painter, sink, vertices);
 }
```

## Step 3: verify the default changes nothing

Machine note: Low Power Mode was ON for this run. That does not invalidate
this step — the assertion is on the printed step vector, not on timing. No
timing figure from this run is reported or should be read as meaningful.

Command run (output redirected to a file, then grepped as a separate
command, per the operational warning about non-tty pipe buffering):

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d
caffeinate -dimsu flutter drive --profile -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=ENTITIES=50000 --dart-define=TILES=on > /tmp/step3_run.log 2>&1
```

Verbatim `tile pan step:` line, from `grep "tile pan step" /tmp/step3_run.log`:

```
flutter:   tile pan step: dx=-7.0000 dy=-3.0000 magnitude=7.6158
```

This is exactly the expected `dx=-7.0000 dy=-3.0000 magnitude=7.6158`. The
`isNaN` sentinel correctly leaves the historical step untouched when
`PAN_STEP` is unset.

Run tail, showing the suite finished clean:

```
flutter: 00:51 +3: (tearDownAll)
flutter: Warning: integration_test plugin was not detected.
...
flutter: 00:51 +4: All tests passed!
All tests passed.
```

(Exit code of the `flutter drive` process was 0.)

## Step 4: verify a bad value throws

Command run:

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d
caffeinate -dimsu flutter drive --profile -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=ENTITIES=50000 --dart-define=TILES=on \
  --dart-define=PAN_STEP=30px > /tmp/step4_run.log 2>&1
```

Verbatim relevant section of `/tmp/step4_run.log`:

```
flutter: 00:00 +0: R2 pan and zoom
VMServiceFlutterDriver: Connected to Flutter application.
flutter: Invalid argument (PAN_STEP): not a finite number: "30px"
flutter: #0      _doubleDefine (package:dev_harness_2d/main.dart:219)
flutter: #1      kPanStep (package:dev_harness_2d/main.dart:237)
flutter: #2      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/integration_test/frame_timing_test.dart)
flutter: <asynchronous suspension>
flutter: #3      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192)
flutter: <asynchronous suspension>
flutter: #4      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953)
flutter: <asynchronous suspension>
flutter: #5      TestWidgetsFlutterBinding._createTestCompletionHandler.<anonymous closure> (package:flutter_test/src/binding.dart:1707)
flutter: <asynchronous suspension>
flutter: 00:02 +0: R2 pan and zoom [E]
flutter:   Test failed. See exception logs above.
  The test description was: R2 pan and zoom
flutter:   
flutter: 00:02 +0 -1: R4a leaf edit per frame
```

Later in the same log:

```
flutter: 00:38 +2 -1: (tearDownAll)
...
flutter: 00:38 +3 -1: Some tests failed.
Failure Details:
Failure in method: R2 pan and zoom
Instance of 'FlutterErrorDetails'
end of failure 1
```

`ArgumentError.value(raw, name, 'not a finite number')` prints as
`Invalid argument (PAN_STEP): not a finite number: "30px"` — this is the
`ArgumentError` from `_doubleDefine`, thrown on first read of `kPanStep`
(triggered by `frame_timing_test.dart`'s `runR2Rig(..., panStep: kPanStep)`
call in the `R2 pan and zoom` test), naming `PAN_STEP` exactly as expected.
The `R2 pan and zoom` test fails as a result — this failure is the correct,
intended outcome of Step 4, not a defect. The other three tests in the file
(`R4a`, `R4b`, and presumably a fourth) proceed normally since they do not
read `kPanStep`.

## `flutter analyze` output

```
Analyzing dev_harness_2d...
No issues found! (ran in 1.5s)
```

## `dart format --output=none --set-exit-if-changed .` output

```
Formatted 4 files (0 changed) in 0.07 seconds.
```
Exit code: 0.

## `git status --porcelain` before staging

Before staging (after all edits, before `git add`):

```
 M apps/dev_harness_2d/integration_test/frame_timing_test.dart
 M apps/dev_harness_2d/lib/main.dart
 M apps/dev_harness_2d/lib/measurement_rig.dart
```

`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` did **not**
appear in `git status --porcelain` after either `flutter drive` run in this
session — the working tree stayed clean of it throughout. Seen, and left
alone regardless (it was not staged either way, since it never showed up
as modified).

## Commit

```
commit fa1e408cf5f465ff0dd4a18dbd328f7f3b1f764e
Author: Ahmet Urel <a-urel@hotmail.com>

    feat(rig): PAN_STEP, a magnitude along the rig's existing direction

    Criteria 4 and 5 read a band of pan speeds, and the band has to meet the tile
    lattice at one angle: an axis-aligned fast pan would measure a different
    interaction than the diagonal one every prior number was taken on.

    Unset means no scaling at all, not PAN_STEP=7.6 -- 7.6 / sqrt(58) is 0.99793
    and would rescale the historical step. It reaches the tile phase only; R2's
    own pan is untouched, or every prior plan's R2 row becomes incomparable. The
    parse throws, for _intDefine's reason.

    Also updates frame_timing_test.dart's runR2Rig call site, which the brief's
    file list omitted: panStep became a required parameter of runR2Rig, and this
    is the test Steps 3 and 4 actually drive.

 .../integration_test/frame_timing_test.dart        |  1 +
 apps/dev_harness_2d/lib/main.dart                  | 32 ++++++++++++++++++++++
 apps/dev_harness_2d/lib/measurement_rig.dart       | 15 +++++++++-
 3 files changed, 47 insertions(+), 1 deletion(-)
```

`git status --porcelain` after the commit: empty (clean working tree).

## Concerns

None substantive. The one deviation from the brief — updating
`frame_timing_test.dart`'s `runR2Rig` call site — was a compile-time
necessity once `panStep` became a required parameter, not a design choice;
it is mechanical (one added named argument) and included transparently in
the commit and this report.
