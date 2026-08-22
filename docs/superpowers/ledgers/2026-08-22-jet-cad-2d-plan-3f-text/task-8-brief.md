## Task 8: the harness measures LOD, and the threshold ladder

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart` — the `LOD` define, forwarded to `DraftCanvas`
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart:145-159` — `culledText=`
- Modify: `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart` — the measured distinct-key count into `kMetricsCacheLimit`'s doc comment

**Interfaces:**
- Consumes: `DraftCanvas.minTextCapPixels`, `DraftPainter.culledTextCount`, `FlutterTextMeasurer.liveMetricsCount`.
- Produces: the threshold ladder table, for the results note.

- [ ] **Step 1: Add the define**

In `apps/dev_harness_2d/lib/main.dart`, beside `kFillsEnabled`:

```dart
/// Whether the painter culls text too small to read.
///
/// **A `String.fromEnvironment`, and it stays one.** `bool.fromEnvironment`
/// reads `--dart-define=LOD=1` as **false**, and Plan 3c lost a full device run
/// to exactly that with `TEXT=1`. An unrecognised value throws at startup rather
/// than falling back to something that looks fine.
final double kMinTextCap =
    switch (const String.fromEnvironment('LOD', defaultValue: 'true')) {
  'true' => kMinTextCapPixels,
  'false' => 0.0,
  final other => throw ArgumentError.value(
      other, 'LOD', 'expected "true" or "false"'),
};
```

and forward it at the `DraftCanvas(...)` construction:

```dart
                drawText: kDrawText,
                minTextCapPixels: kMinTextCap,
                backend: kBackend),
```

- [ ] **Step 2: Print the counter**

In `printTextCounters`, add `culledText` to the first line:

```dart
  print('  text: corpus=${textCorpus ? "on" : "off"} '
      'draw=${drawText ? "on" : "off"} '
      'textOps=${painter.textOpCount} '
      'skippedText=${painter.skippedTextCount} '
      'culledText=${painter.culledTextCount}');
```

**The guard stays where it is.** Any rig guard belongs before the first print or nowhere — R4a and R4b printed three lines and threw, for months, and the numbers looked complete because the missing lines were the ones nobody expects to read.

- [ ] **Step 3: Check Low Power Mode before measuring anything**

Run:

```bash
pmset -g | grep lowpowermode
```

Record the value in the report. **Every timing taken in this task carries that mark.** No failable criterion is a timing, but the results note must state it.

- [ ] **Step 4: Measure the threshold ladder**

Run the widget-level rig at thresholds `0.0`, `1.0`, `2.0`, `3.0`, `4.0`, `6.0`, `10.0`, at both the working-set and whole-drawing cameras, on the 50,000-entity corpus:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test --tags rig --run-skipped \
  test/rig/paint_microbench_test.dart --plain-name "text paint at 50000"
```

extended by the implementer to loop the threshold. Record, per threshold and per camera: **layouts, paragraph evictions, metrics evictions, `culledTextCount`, and the distinct surviving key count in each map** (`liveParagraphCount`, `liveMetricsCount`).

The last column is the number that says whether 3.0 is feasible or whether Ruling 4's single raise finally gets spent.

**Expect a step, not a curve.** `generate_document.dart:676` gives every attribute a fixed height of `80.0` and attributes are 4,000 of the roughly 4,020 distinct pairs, so one threshold makes 4,000 keys vanish at once. Write the ladder up as a step-locator and say where the step is.

- [ ] **Step 5: Write the measured count into the constant**

Replace the "derived from the corpus generator, not yet measured" sentence in `kMetricsCacheLimit`'s doc comment with the measured distinct `(text, styleHandle)` count from Step 4, and the camera it was measured at.

- [ ] **Step 6: Run the device rig both ways**

```bash
cd apps/dev_harness_2d
flutter drive --profile -d macos --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=TEXT=true --dart-define=DRAW_TEXT=true --dart-define=LOD=true
flutter drive --profile -d macos --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=TEXT=true --dart-define=DRAW_TEXT=true --dart-define=LOD=false
```

**`flutter drive` rewrites `macos/Runner.xcodeproj/project.pbxproj`.** Revert it, do not commit it:

```bash
git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj
```

That is the one sanctioned `git checkout` of a file in this repo, and it applies to this file only.

- [ ] **Step 7: Commit**

```bash
git add apps/dev_harness_2d/lib packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart
git commit -m "feat: the harness measures with and without level of detail"
```

---

