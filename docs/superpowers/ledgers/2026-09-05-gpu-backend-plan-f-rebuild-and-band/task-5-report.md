# Task 5 report: The classification gets a grid, and the brute force stays as the oracle

## Fix round 1 (controller's ruling F7-a)

Round-1 review found the plan's named M-F10 mutation
(`.floor()` -> `.round()` on the cell range) is EQUIVALENT, not a witness:
`cellX`/`cellY` are one closure pair used by both binning and lookup, so a
monotone shift of the whole grid stays conservative and the differential
stays green under it. Fixed per the controller's ruling:

1. Rewrote the MUTATION comment in
   `test/gpu/classify_grid_test.dart` to name the real witness (bin by the
   min corner only) and record `.floor()` -> `.round()` as equivalent.
2. Fired both mutations by hand against
   `/Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart`,
   with `cp` backups/restores, running
   `flutter test test/gpu/classify_grid_test.dart` each time.
3. Added the reciprocal warning to `_reaches`'s doc comment, pointing at
   `_expandedBox`.
4. Re-ran the targeted tests and the three gates; committed as `ca6bda2`.

### Mutation (a): `.floor()` -> `.round()` (must stay GREEN — the equivalence record)

Backup: `cp lib/src/gpu/text_patches.dart /tmp/text_patches.dart.orig`

Change:
```
-  int cellX(double x) => ((x - uMinX) / cellW).floor().clamp(0, nx - 1);
-  int cellY(double y) => ((y - uMinY) / cellH).floor().clamp(0, ny - 1);
+  int cellX(double x) => ((x - uMinX) / cellW).round().clamp(0, nx - 1);
+  int cellY(double y) => ((y - uMinY) / cellH).round().clamp(0, ny - 1);
```

Command: `flutter test test/gpu/classify_grid_test.dart`

Output:
```
00:00 +0: loading .../test/gpu/classify_grid_test.dart
00:00 +0: grid and brute force agree byte for byte on the text-overlap fixture
00:00 +1: ... and on a generated corpus with hundreds of labels, overflow included
CLASSIFY grid=15.527 ms brute=29.072 ms instances=46550 labels=160 binned=45275 overflow=1 skipped=1274 tested=30965 cells=18x12
00:00 +2: no labels: an empty list, no grid built
00:00 +3: All tests passed!
EXIT=0
```
GREEN as predicted — confirms the mutation is equivalent (note
`tested=30965` here vs `tested=34455` in the original run: `round()` shifts
which instances fall in-range of a label's own cell span versus the
overflow list, but every patch's final membership is unchanged, so
`expectSamePatches` still passes).

Restore: `cp /tmp/text_patches.dart.orig lib/src/gpu/text_patches.dart`,
verified with `diff` — identical, no diff output.

### Mutation (b): bin by the min corner only (must go RED — the real witness)

Change, right after
`final cx0 = cellX(box[0]), cx1 = cellX(box[2]);` in the binning loop:
```
-    final cx0 = cellX(box[0]), cx1 = cellX(box[2]);
+    final cx0 = cellX(box[0]);
+    var cx1 = cellX(box[2]);
+    cx1 = cx0;
     final cy0 = cellY(box[1]), cy1 = cellY(box[3]);
```
(`cx1` had to be declared `var` rather than `final` to accept the
reassignment the ruling specified; the semantic effect — "bin by the min
corner only" — is exactly as named.)

Command: `flutter test test/gpu/classify_grid_test.dart`

Output:
```
00:00 +0: loading .../test/gpu/classify_grid_test.dart
00:00 +0: grid and brute force agree byte for byte on the text-overlap fixture
00:00 +1: ... and on a generated corpus with hundreds of labels, overflow included
00:00 +1 -1: ... and on a generated corpus with hundreds of labels, overflow included [E]
  Expected: <160>
    Actual: <80>
  patch count

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/classify_grid_test.dart 35:3               expectSamePatches
  test/gpu/classify_grid_test.dart 109:5              main.<fn>

00:00 +1 -1: no labels: an empty list, no grid built
00:00 +2 -1: Some tests failed.
EXIT=1
```
RED as required — the grid's patch count (80) diverges from the oracle's
(160): a multi-cell instance, binned into only its min corner's cell, is
invisible to labels overlapping its other cells.

Restore: `cp /tmp/text_patches.dart.orig lib/src/gpu/text_patches.dart`,
verified with `diff` — identical, no diff output.

### Re-run after the real fix (comment rewrite + `_reaches` doc line)

Command: `flutter test test/gpu/classify_grid_test.dart test/gpu/text_patches_test.dart`

Output (tail):
```
CLASSIFY grid=15.527 ms brute=29.79 ms instances=46550 labels=160 binned=45275 overflow=1 skipped=1274 tested=34455 cells=18x12
00:00 +21: .../classify_grid_test.dart: no labels: an empty list, no grid built
00:00 +22: All tests passed!
EXIT=0
```

### The three gates, after the fix

`flutter test`:
```
00:07 +651: All tests passed!
EXIT=0
```

`flutter analyze`:
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
EXIT=0
```

`dart format --output=none --set-exit-if-changed .`:
```
Formatted 109 files (0 changed) in 0.16 seconds.
EXIT=0
```

`git status --short` before the commit showed only:
```
 M packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart
 M packages/jet_cad_2d_flutter/test/gpu/classify_grid_test.dart
```
No `analysis_options.yaml`.

### Commit

`ca6bda2` — `test(gpu): M-F10 is equivalent; the cell arithmetic's witness bins by the min corner`

---

## What was implemented (Task 5, original)

`packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart`:

- Added `import 'dart:math' as math;` and `import 'package:meta/meta.dart';`.
- Added `const int kClassifyOverflowCells = 16;` beside `kBandLowerScale`/`kBandUpperScale`.
- Added `class ClassifyStats` (`cellsX`, `cellsY`, `binned`, `overflow`, `skipped`,
  `candidatesTested`), all zero-initialized.
- Renamed Plan E's existing loop to `classifyTextPatchesBruteForce`, marked
  `@visibleForTesting`, body left word for word unchanged; added the one doc
  paragraph the brief specifies ("**The oracle.** ...").
- Added the new `classifyTextPatches` under the SAME call shape plus one
  optional `ClassifyStats? stats` parameter: builds a uniform grid over the
  labels' union (cell size = the largest label box, capped at 256 cells a
  side), bins each instance's reach-expanded box into every cell it touches
  or into an overflow list past `kClassifyOverflowCells` cells, then tests
  each label only against the instances in the cells its own box touches
  (deduplicated with a stamp array) plus the overflow list. Hit indices are
  sorted (never the buffer) before the sub-buffer is built, so the sub-buffer
  stays a subsequence of the main buffer in main-buffer order.
- Added private helper `_expandedBox` — the same points-per-kind/reach-per-kind
  logic as `_reaches`, written out separately (not shared) so `_reaches` stays
  Plan E's oracle word for word, per the brief.

`packages/jet_cad_2d_flutter/test/gpu/classify_grid_test.dart`: new file,
the brief's three tests verbatim (formatted by `dart format` afterward —
purely line-wrap changes, no semantic edits).

## TDD evidence

### RED

Command: `flutter test test/gpu/classify_grid_test.dart`

Output (excerpt):
```
test/gpu/classify_grid_test.dart:57:19: Error: Method not found: 'ClassifyStats'.
      final stats = ClassifyStats();
                    ^^^^^^^^^^^^^
test/gpu/classify_grid_test.dart:59:32: Error: No named parameter with the name 'stats'.
test/gpu/classify_grid_test.dart:61:9: Error: Method not found: 'classifyTextPatchesBruteForce'.
...
00:00 +0 -1: Some tests failed.
```
Fails exactly as expected: `ClassifyStats` and `classifyTextPatchesBruteForce`
undefined, `stats` not a named parameter of `classifyTextPatches`.

### GREEN

Command: `flutter test test/gpu/classify_grid_test.dart test/gpu/text_patches_test.dart test/gpu/text_order_test.dart`

Output (tail):
```
00:00 +21: .../text_order_test.dart: the composited picture matches the reference at scale 0.5
00:00 +22: .../text_order_test.dart: the composited picture matches the reference at scale 0.8
00:00 +23: .../text_order_test.dart: the composited picture matches the reference at scale 1.25
00:00 +24: .../text_order_test.dart: the composited picture matches the reference at scale 2.0
00:00 +25: .../text_order_test.dart: with level of detail on, both arms cull TINY the same way at scale 1
00:00 +26: .../text_order_test.dart: drawing all text in one pass -- no patches -- changes the picture
00:00 +27: .../text_order_test.dart: the label nothing later reaches is not a patch, and still matches
00:00 +28: All tests passed!
```
(A second full run with `--reporter expanded` confirmed all three files' tests
ran and passed — 29/29 assertions, exit 0; `text_patches_test.dart`'s 11 tests
are interleaved with the other two files' shards under the compact/expanded
reporters and don't each print a distinct line, but the total count and exit
code confirm they ran and passed.)

### The printed CLASSIFY line (criterion 7's number)

```
CLASSIFY grid=16.844 ms brute=31.571 ms instances=46550 labels=160 binned=45275 overflow=1 skipped=1274 tested=34455 cells=18x12
```

The differential (`expectSamePatches`) passed on both corpora: the
text-overlap fixture (2 patches, COVERED and GRAZED) and the generated
3000-entity corpus with the diagonal line added (46550 instances, 160 labels,
`stats.overflow == 1 > 0`, `stats.binned == 45275 > 1000`,
`stats.candidatesTested == 34455 < texts.length * count ~/ 2 == 3,724,000`).
No disagreement between grid and brute force was observed at any point —
the grid's output matched the oracle byte for byte on every patch, on both
corpora, on the first implementation.

## The three gates (Step 5)

### `flutter test`
```
$ flutter test
...
00:09 +651: All tests passed!
EXIT=0
```
(651 tests passed, 1 pre-existing skip unrelated to this task.)

### `flutter analyze`
```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
EXIT=0
```

### `dart format --output=none --set-exit-if-changed .`
First run caught line-wrap issues in the new test file (copied from the
brief) and in `text_patches.dart`:
```
$ dart format --output=none --set-exit-if-changed .
Changed test/gpu/classify_grid_test.dart
Formatted 109 files (1 changed) in 0.20 seconds.
EXIT=1
```
Fixed with `dart format test/gpu/classify_grid_test.dart lib/src/gpu/text_patches.dart`
(1 file changed, purely whitespace-wrap, no semantic edits — diff verified).
Re-run:
```
$ dart format --output=none --set-exit-if-changed .
Formatted 109 files (0 changed) in 0.16 seconds.
EXIT=0
```

## Files changed

- Modified: `packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart`
- New: `packages/jet_cad_2d_flutter/test/gpu/classify_grid_test.dart`

`git status --short` before commit showed exactly these two paths;
`analysis_options.yaml` was not touched.

## Self-review

- The brute-force function body is byte-identical to Plan E's shipped loop —
  the diff shows only doc-comment additions and `@visibleForTesting` above
  the renamed signature; not a single line inside the body changed.
- `hits.sort()` sorts the index list only; the main buffer (`data`) is never
  reordered, and neither is any patch's sub-buffer after it is built (built
  once, in sorted-index order, and never touched again).
- `classifyTextPatches`'s call shape is unchanged except for the one added
  optional `ClassifyStats? stats` parameter — every existing call site
  (`text_patches_test.dart`'s 11 tests, `text_order_test.dart`) compiles and
  passes unchanged, proving the grid reproduces Plan E's box-test semantics
  exactly, including the `instanceIndex` floor, the per-kind reach, and
  ascending textIndex order.
- `packages/jet_cad_2d`, `vertices_draw_sink.dart`, `canvas_draw_sink.dart`
  are untouched; no shader was touched.
- `kClassifyOverflowCells`, `ClassifyStats`, and `classifyTextPatchesBruteForce`
  are all reachable from `test/gpu/classify_grid_test.dart`'s
  `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` import, since
  `text_patches.dart` is exported by the barrel and `@visibleForTesting`
  only affects analyzer warnings at non-test call sites, not visibility.
- Both differential tests' `expectSamePatches` passed without needing any
  correction to the grid logic — the grid brief's algorithm, implemented as
  given, matched the oracle on the first try on both corpora.

## Concerns

None. All three gates are green, the differential agrees byte for byte on
both corpora including the overflow path, and no production file outside
`text_patches.dart` was touched.
