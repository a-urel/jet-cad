# Task 3: `_coveredArgb` — the hairline fade

Branch: `plan-b/joins-and-hairlines`. Base: `24923f9`. Commit landed:
`5d5ba07` — "feat(gpu): the collector fades sub-pixel strokes the way the
reference does".

## Files touched

- `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart`
- `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart`

`packages/jet_cad_2d` was not touched. `analysis_options.yaml` did not appear
in `git status` at any point and was not committed.

## Defects found in the brief's sample code

The brief warned the previous plan's sample code carried four real defects,
all found by running it rather than reading it. Running this brief's sample
surfaced two:

1. **`ResolvedStyle(argb: ..., lineweightHundredths: ...)` does not
   compile.** `packages/jet_cad_2d/lib/src/document/resolved_style.dart:8-13`
   declares all four constructor parameters `required`:
   `argb`, `lineweightHundredths`, `linetype`, `linetypeScale`. The brief's
   three new test bodies construct `ResolvedStyle` with only the first two,
   which the analyzer rejects (`error - missing required arguments`). Fixed by
   adding `linetype: Handle.none, linetypeScale: 1` to all three literals —
   the same two fields the file's existing `_style`/`_hairlineStyle`
   constants already carry.

2. **`kLogicalPixelsPerMm` needed an import the brief didn't name
   precisely.** It's declared in
   `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:21` and reaches the
   package barrel `jet_cad_2d_flutter.dart` via that file's `export`. The
   brief said "from the package barrel," which is correct but the existing
   test file imported only `src/gpu/geometry_collector.dart` and
   `src/gpu/instance_record.dart` directly — neither exposes it. Added
   `import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';` and, since
   the barrel already re-exports `geometry_collector.dart`, dropped the
   now-redundant direct import of that file (the IDE flagged it as an unused
   duplicate import; `instance_record.dart` stays as a direct import since
   the barrel deliberately does not export it).

**A third, non-code finding in Step 6:** the brief says the
`kMinStrokeDevicePixels` doc comment on `GeometryCollector` calls
`VerticesDrawSink.kMinStrokeDevicePixels` "a private implementation detail"
and asks to fix that sentence. It doesn't, at this branch's base (`24923f9`):

```
$ git show HEAD:packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart | grep -in private
(no output)
```

The doc comment already reads "that constant is public
(`vertices_draw_sink.dart:527`), so this is not a visibility workaround" —
i.e. this half of Step 6 was already true before this task started (most
likely folded into Task 2's changes). No edit was made to that sentence; I
tried one, then reverted it once I confirmed there was nothing to fix, to
keep the diff to only real changes. The `skippedOps` half of Step 6 (see
below) *was* stale and was fixed.

## TDD evidence

### Red — before implementation

Appended the three tests from the brief (Step 1, with the two fixes above)
to `test/gpu/geometry_collector_test.dart`, then ran:

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +1: emits one instance per segment, in walk order
00:00 +2: closed: true emits a closing segment back to the first point
00:00 +3: drops a zero-length segment rather than handing the shader a NaN
00:00 +4: counts the ops Plan A does not draw instead of dropping them silently
00:00 +5: clamps to the device-pixel floor at a hairline lineweight
00:00 +6: lineweightScale multiplies the logical width before the clamp
00:00 +7: a sub-pixel stroke keeps its pixel and gives up alpha
00:00 +7 -1: a sub-pixel stroke keeps its pixel and gives up alpha [E]
  Expected: a numeric value within <0.51> of <96>
    Actual: <255.0>
     Which:  differs by <159.0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 168:5         main.<fn>
  
00:00 +7 -1: a stroke at or above one device pixel keeps full alpha
00:00 +8 -1: a zero lineweight is the hairline case and keeps full alpha
00:00 +9 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a sub-pixel stroke keeps its pixel and gives up alpha
exit=1
```

Exactly as the brief predicted: only the sub-pixel-fade test fails (255
instead of the faded 96), and the two guard-branch tests already pass because
the collector wrote full alpha unconditionally before this task.

### Green — after implementation

Implemented `_coveredArgb` (directly under `_halfWidthFor`) and hoisted
`argb = _coveredArgb(style.argb, style.lineweightHundredths)` once in
`polyline`, used at both `_emit` call sites (per the plan's Resolution 1),
then re-ran:

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +1: emits one instance per segment, in walk order
00:00 +2: closed: true emits a closing segment back to the first point
00:00 +3: drops a zero-length segment rather than handing the shader a NaN
00:00 +4: counts the ops Plan A does not draw instead of dropping them silently
00:00 +5: clamps to the device-pixel floor at a hairline lineweight
00:00 +6: lineweightScale multiplies the logical width before the clamp
00:00 +7: a sub-pixel stroke keeps its pixel and gives up alpha
00:00 +8: a stroke at or above one device pixel keeps full alpha
00:00 +9: a zero lineweight is the hairline case and keeps full alpha
00:00 +10: All tests passed!
exit=0
```

## M-B1 mutation transcript (Step 5)

Backed up the implementation file first:

```
$ cd packages/jet_cad_2d_flutter
$ cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak
```

Mutation applied — in `polyline`, replaced the hoisted `argb` computed via
`_coveredArgb` with the raw `style.argb`, dropping the fade from strokes
entirely:

```diff
-    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
+    final argb = style.argb; // M-B1: drop _coveredArgb from strokes.
```

Ran the test suite against the mutated file:

```
$ flutter test test/gpu/geometry_collector_test.dart
```

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +1: emits one instance per segment, in walk order
00:00 +2: closed: true emits a closing segment back to the first point
00:00 +3: drops a zero-length segment rather than handing the shader a NaN
00:00 +4: counts the ops Plan A does not draw instead of dropping them silently
00:00 +5: clamps to the device-pixel floor at a hairline lineweight
00:00 +6: lineweightScale multiplies the logical width before the clamp
00:00 +7: a sub-pixel stroke keeps its pixel and gives up alpha
00:00 +7 -1: a sub-pixel stroke keeps its pixel and gives up alpha [E]
  Expected: a numeric value within <0.51> of <96>
    Actual: <255.0>
     Which:  differs by <159.0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 168:5         main.<fn>
  
00:00 +7 -1: a stroke at or above one device pixel keeps full alpha
00:00 +8 -1: a zero lineweight is the hairline case and keeps full alpha
00:00 +9 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: a sub-pixel stroke keeps its pixel and gives up alpha
exit=1
```

The mutation was caught: red on exactly `a sub-pixel stroke keeps its pixel
and gives up alpha`, the same test and the same failure text as the
pre-implementation red run.

Restored from the `cp` backup (never `git checkout --`, per this task's
constraint):

```
$ cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart
```

Proof of restoration — the restored file is byte-identical to the backup:

```
$ diff /tmp/gc.bak lib/src/gpu/geometry_collector.dart
(no output — files identical)

$ shasum -a 256 /tmp/gc.bak lib/src/gpu/geometry_collector.dart
d96020f2abd7f427d5ea08347e29568b11ea3bd5a222061235728c5eec285e1  /tmp/gc.bak
d96020f2abd7f427d5ea08347e29568b11ea3bd5a222061235728c5eec285e1  lib/src/gpu/geometry_collector.dart
```

`git diff --stat` against `HEAD` at that point (the Step 3 implementation was
still uncommitted, so this is not empty — it shows only the legitimate,
pre-mutation Step 3 change, with no trace of the M-B1 mutation surviving):

```
$ git diff --stat -- lib/src/gpu/geometry_collector.dart
 .../lib/src/gpu/geometry_collector.dart            | 38 ++++++++++++++++++++--
 1 file changed, 36 insertions(+), 2 deletions(-)
```

Re-ran the test suite immediately after restoring to confirm the mutation
left no residue functionally, not just byte-wise:

```
$ flutter test test/gpu/geometry_collector_test.dart
...
00:00 +10: All tests passed!
exit=0
```

## Step 6: doc fixes

- `kMinStrokeDevicePixels` doc: already correct at this branch's base (see
  "Defects found" above) — no edit needed or made.
- `skippedOps` doc: was stale (`"arcs, circles, fills, text, points"`).
  Rewritten to the post-Plan-B set (`fillPolygon`, `fillCircle`, `text`),
  with a note that `circle`/`arc` still count today and stop in Task 5, and
  `point` stops in Task 6, which also lands the test that verifies the
  sentence:

```dart
  /// Ops this plan does not draw yet — `fillPolygon`, `fillCircle` and
  /// `text`. Counted rather than ignored so a corpus that needs Plan B
  /// through E is visible as a number instead of as a missing picture.
  ///
  /// This is the post-Plan-B set, landing ahead of the code that makes it
  /// true: `circle` and `arc` still count here today and stop counting in
  /// Task 5, `point` stops counting in Task 6. Task 6 is also where the test
  /// verifying this sentence lands.
  int get skippedOps => _skipped;
```

## Gate output (Step 7)

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:06 +449 ~1: All tests passed!
TEST_EXIT=0
```

(`~1` is one skipped test pre-existing in the suite, unrelated to this task;
not a failure.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
ANALYZE_EXIT=0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 85 files (0 changed) in 0.15 seconds.
FORMAT_EXIT=0
```

Note: the first `dart format` run, before I ran `dart format
test/gpu/geometry_collector_test.dart` in place, printed `Changed
test/gpu/geometry_collector_test.dart` / `Formatted 85 files (1 changed)` and
exited 1 — a real formatting defect in my own added test code (long
`reason:` string wasn't wrapped the way `dart format` wants). Fixed by
running `dart format` on that file, then re-verified the exit-code-checking
run above came back clean.

```
$ git status
On branch plan-b/joins-and-hairlines
nothing to commit, working tree clean
```

No `analysis_options.yaml` ever appeared in `git status` during this task.

## Commit

```
$ git add packages/jet_cad_2d_flutter
$ git commit -m "feat(gpu): the collector fades sub-pixel strokes the way the reference does"
[plan-b/joins-and-hairlines 5d5ba07] feat(gpu): the collector fades sub-pixel strokes the way the reference does
 2 files changed, 122 insertions(+), 6 deletions(-)
```
