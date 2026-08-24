# Task 3 report: `TileKey`, `TileGrid`, `quantiseCamera`

Status: complete, with one deviation from the brief (a degenerate test fixed
per the brief's own instructions). All arithmetic — including the mutant
under test — matches hand-computed values exactly.

Commit: `9f5bd0e` on `main` (worked directly on `main`, per this task's
instructions; no worktree).

## Files

- Created: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Created: `packages/jet_cad_2d_flutter/test/tile_grid_test.dart`
- Modified: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`
  (added `export 'src/tile_cache.dart';` in alphabetical position, between
  `render_backend.dart` and `viewport_transform.dart`)

`tile_cache.dart` was written verbatim from the brief's Step 3 code block,
minus the `import 'dart:math' as math;` line (unused — `unused_import` is an
error in this package, and the brief says not to import it until Task 10
needs it).

## Step 2: the failing run (before `tile_cache.dart` existed)

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart
test/tile_grid_test.dart:30:17: Error: Method not found: 'quantiseCamera'.
      final q = quantiseCamera(awkwardCamera(), kDpr);
                ^^^^^^^^^^^^^^
test/tile_grid_test.dart:46:24: Error: Method not found: 'quantiseCamera'.
      expect(identical(quantiseCamera(already, kDpr), already), isTrue,
                       ^^^^^^^^^^^^^^
test/tile_grid_test.dart:52:17: Error: Method not found: 'quantiseCamera'.
      final q = quantiseCamera(awkwardCamera(), 1.0);
                ^^^^^^^^^^^^^^
test/tile_grid_test.dart:59:5: Error: 'TileGrid' isn't a type.
    TileGrid gridAt(ViewportTransform anchor) => TileGrid(
    ^^^^^^^^
test/tile_grid_test.dart:60:17: Error: Method not found: 'quantiseCamera'.
        anchor: quantiseCamera(anchor, kDpr),
                ^^^^^^^^^^^^^^
test/tile_grid_test.dart:59:50: Error: Method not found: 'TileGrid'.
    TileGrid gridAt(ViewportTransform anchor) => TileGrid(
                                                 ^^^^^^^^
test/tile_grid_test.dart:85:18: Error: Method not found: 'quantiseCamera'.
        camera = quantiseCamera(
                 ^^^^^^^^^^^^^^
test/tile_grid_test.dart:105:40: Error: Couldn't find constructor 'TileKey'.
      final a = grid.destRectFor(const TileKey(3, 5), camera);
                                       ^^^^^^^
test/tile_grid_test.dart:106:44: Error: Couldn't find constructor 'TileKey'.
      final right = grid.destRectFor(const TileKey(4, 5), camera);
                                           ^^^^^^^
test/tile_grid_test.dart:107:44: Error: Couldn't find constructor 'TileKey'.
      final below = grid.destRectFor(const TileKey(3, 6), camera);
                                           ^^^^^^^
test/tile_grid_test.dart:115:19: Error: Method not found: 'TileKey'.
      const key = TileKey(3, 5);
                  ^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart: [errors repeated]
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart
```

Compile failure, as expected — `tile_cache.dart` did not exist yet.

## Step 5: the passing run (brief's test verbatim, `tile_cache.dart` written)

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart
00:00 +0: quantiseCamera snaps the translation to whole device pixels and nothing else
00:00 +1: quantiseCamera returns the same instance when already quantised
00:00 +2: quantiseCamera a dpr of 1 still quantises
00:00 +3: TileGrid the visible key count matches ceil(extent / tile) + 1 per axis
00:00 +4: TileGrid every destination is a whole device pixel, at every panned camera
00:00 +5: TileGrid adjacent tiles abut exactly, with no gap and no overlap
00:00 +6: TileGrid the bake camera puts a tile top-left at the logical origin
00:00 +7: TileGrid matchesScale is exact, not tolerant
00:00 +8: All tests passed!
```

Before this: hand-verified the brief's `17.31 -> 17.5` and `409.77 -> 410.0`
comment against the code. `17.31 * 2 = 34.62`, round-half-away-from-zero
gives `35`, `/2 = 17.5`. `409.77 * 2 = 819.54`, round gives `820`, `/2 =
410.0`. Both match the brief exactly — no expectation was wrong here.

## Step 6: mutant 1 — delete the rounding in `quantiseCamera`

Mutation applied by hand: `final e = m.e;` (rounding deleted; `f` left
correct). Backed up `tile_cache.dart` first, mutated in place, restored from
the backup afterward — never `git checkout`.

**Red run:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +0: quantiseCamera snaps the translation to whole device pixels and nothing else
00:00 +0 -1: quantiseCamera snaps the translation to whole device pixels and nothing else [E]
  Expected: <0.0>
    Actual: <0.6199999999999974>
  e is a whole device pixel

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_grid_test.dart 36:7                       main.<fn>.<fn>

00:00 +0 -1: quantiseCamera returns the same instance when already quantised
00:00 +1 -1: quantiseCamera a dpr of 1 still quantises
00:00 +1 -2: quantiseCamera a dpr of 1 still quantises [E]
  Expected: <17.0>
    Actual: <17.31>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_grid_test.dart 53:7                       main.<fn>.<fn>

00:00 +1 -2: TileGrid the visible key count matches ceil(extent / tile) + 1 per axis
00:00 +2 -2: TileGrid every destination is a whole device pixel, at every panned camera
00:00 +3 -2: TileGrid adjacent tiles abut exactly, with no gap and no overlap
00:00 +4 -2: TileGrid the bake camera puts a tile top-left at the logical origin
00:00 +5 -2: TileGrid matchesScale is exact, not tolerant
00:00 +6 -2: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart: quantiseCamera a dpr of 1 still quantises
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart: quantiseCamera snaps the translation to whole device pixels and nothing else
```

2 of 8 tests go red, as required.

**Restored, green:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +8: All tests passed!
```

(File compared byte-for-byte against the pre-mutation backup with `diff` —
identical, confirmed before rerunning.)

## Step 6: mutant 2 — `_floorDiv` -> `~/` — the brief's test as written is degenerate

Applied the mutation exactly as specified: `static int _floorDiv(int a, int
b) => a ~/ b;`.

**Red run attempt against the brief's test verbatim:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +0: quantiseCamera snaps the translation to whole device pixels and nothing else
00:00 +1: quantiseCamera returns the same instance when already quantised
00:00 +2: quantiseCamera a dpr of 1 still quantises
00:00 +3: TileGrid the visible key count matches ceil(extent / tile) + 1 per axis
00:00 +4: TileGrid every destination is a whole device pixel, at every panned camera
00:00 +5: TileGrid adjacent tiles abut exactly, with no gap and no overlap
00:00 +6: TileGrid the bake camera puts a tile top-left at the logical origin
00:00 +7: TileGrid matchesScale is exact, not tolerant
00:00 +8: All tests passed!
```

**All 8 tests passed. The mutant did not redden — the brief's own test as
written is degenerate.** Per the brief's explicit instruction ("If they do
not, the pan step is too small to reach a negative key and the test is
degenerate — fix the test, not the mutant"), this is the required response,
and the fix is below.

### Why it's degenerate (arithmetic written out)

**The "abut exactly" test cannot detect this mutant under any pan or key
choice, full stop** — not because of pan magnitude. `TileGrid.destRectFor`
never calls `_floorDiv`:

```dart
Rect destRectFor(TileKey key, ViewportTransform camera) {
  final (dx, dy) = deviceDeltaFrom(camera);
  return Rect.fromLTWH(
    (key.x * tileDevicePixels + dx) / devicePixelRatio,
    (key.y * tileDevicePixels + dy) / devicePixelRatio,
    _tileLogical,
    _tileLogical,
  );
}
```

`_floorDiv` is called only inside `visibleKeys`, to compute the `x0/x1/y0/y1`
bounds of the loop that *generates* keys. The "abut exactly" test calls
`destRectFor` directly with three hardcoded, already-positive `TileKey`
values — it never goes through `visibleKeys`, so it is structurally incapable
of exercising `_floorDiv` regardless of the keys chosen or whether the
camera has panned. The brief's claim that this test "must go red" under
this mutant does not hold against the actual code path; this is not a
step-size problem for that test, it is a code-path problem, so nothing about
that test needed to (or could usefully) change.

**The panned-destination test *is* wired to `_floorDiv` (via `visibleKeys`),
but its pan direction never reaches a negative numerator.** The brief's pan
step is:

```dart
camera = quantiseCamera(
    ViewportTransform(worldToScreenMatrix: Transform2(
        m.a, m.b, m.c, m.d, m.e - 7.37, m.f - 3.19)),
    kDpr);
```

`deviceDeltaFrom(camera)` returns `dx = round((camera.e - anchor.e) *
dpr)`. Because every step *subtracts* from `e`, `camera.e` only ever
decreases below `anchor.e`, so `dx` only ever becomes more negative.
`visibleKeys` sets `left = -dx`, so `left` only ever grows more *positive* as
the pan continues — receding from zero, never crossing it. `x0 =
_floorDiv(left, 64)` is therefore always `>= 0` for every one of the 23
iterations, no matter how many more iterations are added: `_floorDiv` is
called with an ever-larger *non-negative* numerator, never a negative one.
Same reasoning for `f`/`top`/`y0`. This is a **direction** bug in the test,
not a magnitude one — no number of additional pans of this shape would ever
reach a negative key.

### The fix (test only, `tile_grid_test.dart`)

Two changes to the "every destination is a whole device pixel, at every
panned camera" test:

1. Flipped the pan step's sign (`m.e + 7.37, m.f + 3.19` instead of `-`), so
   `camera.e > anchor.e`, `dx > 0`, `left < 0` — reaching the negative-key
   branch of `_floorDiv` from the very first iteration.
2. Added an assertion that the minimal `x`/`y` key returned by
   `grid.visibleKeys(...)` matches a floor computed independently in the
   test (`(-dx / kTestTile).floor()`), because the mutant's effect is
   invisible to the existing per-key alignment checks: a truncating
   `_floorDiv` produces an `x0` that is too large (closer to zero), which
   silently *drops* the tile that should cover the viewport's leading edge —
   the tiles that *are* still returned remain perfectly pixel-aligned (since
   `destRectFor` doesn't call `_floorDiv`), so only a coverage/boundary
   check, not an alignment check, can see the bug.

Hand-verified arithmetic for iteration `i = 0`:

- `anchor.e = 17.5`, `anchor.f = 410.0` (from `quantiseCamera` above).
- `camera.e` before quantise: `17.5 + 7.37 = 24.87`. Quantise: `24.87 * 2 =
  49.74`, round `= 50`, `/2 = 25.0`.
- `camera.f` before quantise: `410.0 + 3.19 = 413.19`. Quantise: `413.19 * 2
  = 826.38`, round `= 826`, `/2 = 413.0`.
- `dx = round((25.0 - 17.5) * 2) = round(15.0) = 15`. `left = -15`.
  `expectedX0 = floor(-15 / 64) = floor(-0.234375) = -1`.
- `dy = round((413.0 - 410.0) * 2) = round(6.0) = 6`. `top = -6`.
  `expectedY0 = floor(-6 / 64) = floor(-0.09375) = -1`.
- Correct `_floorDiv(-15, 64) = (-15/64).floor() = -1` — matches.
- Mutant `_floorDiv(-15, 64) = -15 ~/ 64 = 0` (Dart's `~/` truncates toward
  zero) — mismatch, caught immediately.

This matches the empirical red run below exactly (`Expected: <-1>, Actual:
<0>`, at `pan 0`).

**Green run, fixed test, correct implementation:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +8: All tests passed!
```

**Red run, fixed test, mutant 2 (`_floorDiv` -> `~/`) reapplied:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +3: TileGrid the visible key count matches ceil(extent / tile) + 1 per axis
00:00 +4: TileGrid every destination is a whole device pixel, at every panned camera
00:00 +4 -1: TileGrid every destination is a whole device pixel, at every panned camera [E]
  Expected: <-1>
    Actual: <0>
  pan 0 leftmost column: floor division toward negative infinity, not truncation toward zero

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_grid_test.dart 106:9                      main.<fn>.<fn>

00:00 +4 -1: TileGrid adjacent tiles abut exactly, with no gap and no overlap
00:00 +5 -1: TileGrid the bake camera puts a tile top-left at the logical origin
00:00 +6 -1: TileGrid matchesScale is exact, not tolerant
00:00 +7 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart: TileGrid every destination is a whole device pixel, at every panned camera
```

Reddened exactly at `pan 0`, exactly the hand-computed value
(`Expected: <-1>, Actual: <0>`), confirming both the fix and the arithmetic.

**Restored, final green (byte-identical restore confirmed by `diff` against
the pre-mutation backup before rerunning):**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +8: All tests passed!
```

Mutant 1 (`quantiseCamera` rounding) was re-verified once more against this
final test file (unaffected by the panned-test edit) and still reddens the
same 2 tests the same way; transcript identical in substance to the one
above.

## Full package gate (final, after all restores and the `dart format` fixup)

`dart format` initially reported 1 file changed (`tile_grid_test.dart`, from
my edits); ran `dart format` to fix it in place, then reran the exit-gate
format check clean.

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:04 +314 ~1: All tests passed!
```

(314 passed, 1 pre-existing skip unrelated to this task — grepped the
transcript for `[E]`: zero matches.)

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
```

```
$ cd packages/jet_cad_2d_flutter && CI=true dart format --output=none --set-exit-if-changed .
Formatted 57 files (0 changed) in 0.10 seconds.
```

`jet_cad_2d` (unaffected by this task, checked per CLAUDE.md's "every task
ends green"):

```
$ cd packages/jet_cad_2d && CI=true dart test
...
00:03 +797: All tests passed!
$ cd packages/jet_cad_2d && CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!
$ cd packages/jet_cad_2d && CI=true dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.19 seconds.
```

## `git status` before staging (confirming no `analysis_options.yaml` leakage)

```
$ git status --short
 M packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart
?? packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
?? packages/jet_cad_2d_flutter/test/tile_grid_test.dart
```

Staged exactly these three paths by name (no `git add -A`), then committed.

## Deviations from the brief

1. **The `_floorDiv -> ~/` mutant did not redden the brief's test as
   written.** Root-caused and fixed per the report above — the pan direction
   was reversed (subtract -> add) and a coverage assertion was added against
   an independently-computed floor value, since the alignment checks alone
   are blind to this mutant (see arithmetic above). This is the response the
   brief itself prescribes for a degenerate mutant result.
2. **The brief's claim that the "abut exactly" test must also redden under
   this mutant does not hold.** `destRectFor` never calls `_floorDiv` — only
   `visibleKeys` does — so that test cannot be made sensitive to this mutant
   by any choice of pan or keys. No change was made to that test; it is
   correct as written and tests a real, distinct property (abutment).
3. No other deviations. The `17.31 -> 17.5`, `409.77 -> 410.0` hand-computed
   expectations in the brief's quantiseCamera test are correct as given —
   verified independently above — so nothing there needed fixing.
