# Task 6 report: the frame accounting invariants

## Controller correction applied

The brief's second test (`a repeated frame is a repeated frame`) built its
second `CanvasDrawSink` over `Canvas(PictureRecorder())` with the recorder
never bound to a local and never ended. Per the controller's instruction,
the recorder was bound to a local (`recorder`) and `recorder.endRecording().dispose()`
was called after the second `first.paint(...)`, mirroring what `paintOnce`
already does for the first frame. Everything else about that test matches
the brief verbatim.

## Step 1: file created

`packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart`,
per the brief, with the correction above. No import in the brief's list went
unused; the final file's imports are `dart:ui`, `flutter_test`, `jet_cad_2d`,
`jet_cad_2d_flutter`, and `../support/fixtures.dart` (the `vector_math_64`
import from the brief's snippet was dropped — nothing in the file references
it, and `unused_import` is an ERROR in this package).

## Step 2: run it (clean)

Command:

```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/frame_accounting_test.dart
```

Output:

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart
00:00 +0: text accounting closes: drawn + culled + skipped is every text leaf
00:00 +1: a repeated frame is a repeated frame
00:00 +2: the vertices backend loses no text on the way through its fallback
00:00 +3: All tests passed!
```

Three PASS, as expected.

## Step 3: mutants M15, M16, M17

Backups taken before any mutation:

```
cp lib/src/draft_painter.dart /tmp/dp.dart.bak
cp lib/src/vertices_draw_sink.dart /tmp/vds.dart.bak
```

### M15 — `draft_painter.dart`, `_drawText`: keep `_culledText++` but delete the `return`

Edit applied (`lib/src/draft_painter.dart`, around line 869):

```dart
    if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
      _culledText++;
      return;      // <- deleted
    }
```

became:

```dart
    if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
      _culledText++;
    }
```

Test run:

```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/frame_accounting_test.dart
```

Transcript:

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart
00:00 +0: text accounting closes: drawn + culled + skipped is every text leaf
00:00 +0 -1: text accounting closes: drawn + culled + skipped is every text leaf [E]
  Expected: <4>
    Actual: <5>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/invariants/frame_accounting_test.dart 109:5    main.<fn>

00:00 +0 -1: a repeated frame is a repeated frame
00:00 +1 -1: the vertices backend loses no text on the way through its fallback
00:00 +2 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart: text accounting closes: drawn + culled + skipped is every text leaf
```

**Result: reddened `text accounting closes` as required.** Without the
`return`, the culled leaf (GAMMA) falls through into the drawn/measured path
below and also gets counted as drawn, so `textOpCount + culledTextCount +
skippedTextCount` (5) exceeds `textLeafCount(doc)` (4).

Restored:

```
cp /tmp/dp.dart.bak lib/src/draft_painter.dart
diff lib/src/draft_painter.dart /tmp/dp.dart.bak   # -> no output, confirmed identical
```

### M16 — `draft_painter.dart`, `paint()`: delete `_textOps = 0;` from the top

Edit applied (`lib/src/draft_painter.dart`, top of `paint()`):

```dart
  void paint(DrawSink sink, ViewportTransform camera, Size viewport) {
    _skippedText = 0;
    _culledText = 0;
    _textOps = 0;      // <- deleted
    _skippedDeepInstances = 0;
```

became:

```dart
  void paint(DrawSink sink, ViewportTransform camera, Size viewport) {
    _skippedText = 0;
    _culledText = 0;
    _skippedDeepInstances = 0;
```

Test run:

```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/frame_accounting_test.dart
```

Transcript:

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart
00:00 +0: text accounting closes: drawn + culled + skipped is every text leaf
00:00 +1: a repeated frame is a repeated frame
00:00 +1 -1: a repeated frame is a repeated frame [E]
  Expected: (int, int, int, int):<(2, 1, 1, 0)>
    Actual: (int, int, int, int):<(4, 1, 1, 0)>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/invariants/frame_accounting_test.dart 148:5    main.<fn>

00:00 +1 -1: the vertices backend loses no text on the way through its fallback
00:00 +2 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart: a repeated frame is a repeated frame
```

**Result: reddened `a repeated frame is a repeated frame` as required, and
only that test.** With `_textOps` never reset, the second identical frame
accumulates on top of the first: `textOpCount` reads 4 (2 + 2) instead of the
expected 2, while `culledTextCount`, `skippedTextCount` and
`screenSpaceLeafCount` — all correctly reset elsewhere in `paint()` — stay
unchanged at (1, 1, 0).

Restored:

```
cp /tmp/dp.dart.bak lib/src/draft_painter.dart
diff lib/src/draft_painter.dart /tmp/dp.dart.bak   # -> no output, confirmed identical
```

### M17 — `vertices_draw_sink.dart`, `text()`: guard the delegation so one op is dropped

Added a counter field (removed with the restore) and guarded the
delegation call in `VerticesDrawSink.text`:

```dart
  int _frameTriangles = 0;
  int _frameTextOps = 0; // M17 mutation counter
```

```dart
  @override
  void text(String text, Handle style, ResolvedStyle resolved) {
    _flushBeforeUnbatchable();
    if (_frameTextOps++ != 0) _fallback?.text(text, style, resolved);
  }
```

(was `_fallback?.text(text, style, resolved);` unconditionally.)

Test run:

```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/frame_accounting_test.dart
```

Transcript:

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart
00:00 +0: text accounting closes: drawn + culled + skipped is every text leaf
00:00 +1: a repeated frame is a repeated frame
00:00 +2: the vertices backend loses no text on the way through its fallback
00:00 +2 -1: the vertices backend loses no text on the way through its fallback [E]
  Expected: <2>
    Actual: <1>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/invariants/frame_accounting_test.dart 176:5    main.<fn>

00:00 +2 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart: the vertices backend loses no text on the way through its fallback
```

**Result: reddened `the vertices backend loses no text on the way through its
fallback` as required, and only that test.** The fixture draws two text ops
(ALPHA, BETA); the guard drops the first `_fallback.text(...)` call (the
`!= 0` check fails on the sink's first invocation), so `canvasCallCount`
reads 1 while `textOpCount` reads 2.

Restored:

```
cp /tmp/vds.dart.bak lib/src/vertices_draw_sink.dart
diff lib/src/vertices_draw_sink.dart /tmp/vds.dart.bak   # -> no output, confirmed identical
diff lib/src/draft_painter.dart /tmp/dp.dart.bak         # -> no output, confirmed identical
```

## Step 4: full suite, analyze, format — all green

```
cd packages/jet_cad_2d_flutter && CI=true flutter test
```

Tail of transcript:

```
00:05 +300 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon closes the path
00:05 +301 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon with fewer than 3 points draws nothing
00:05 +302 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle draws a filled circle
00:05 +303 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle leaves the paint on stroke afterwards
00:05 +304 ~1: All tests passed!
```

304 tests passed, 1 skipped (the `rig`-tagged microbench, untouched by this
task, as intended).

```
flutter analyze
```

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
```

```
dart format --output=none --set-exit-if-changed .
```

First run flagged the new file (`Changed test/invariants/frame_accounting_test.dart`);
`dart format test/invariants/frame_accounting_test.dart` was applied
(collapsed a multi-line record-literal `expect(...)` call onto fewer lines
per the formatter's own style), and the check re-run clean:

```
Formatted 54 files (0 changed) in 0.10 seconds.
```

`git status` before commit showed only the new test file as untracked;
`analysis_options.yaml` was not modified in any of the three packages, so
nothing was left unstaged on that account.

## Commit

```
git add packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart
git commit -m "test: three frame-accounting identities the rig only printed ..."
```

Result: commit `b1e9ec1` on `main`, 1 file changed, 176 insertions.

## Summary

- Step 1: file created with the controller's recorder-lifecycle correction
  applied to the second test.
- Step 2: three tests pass clean.
- Step 3: M15, M16, M17 each reddened exactly the test the brief names and
  no other test; all mutations restored and confirmed byte-identical to the
  pre-mutation backups via `diff`.
- Step 4: full suite (304 passed, 1 skipped/rig), `flutter analyze` clean,
  `dart format --set-exit-if-changed .` clean, committed as `b1e9ec1`.
