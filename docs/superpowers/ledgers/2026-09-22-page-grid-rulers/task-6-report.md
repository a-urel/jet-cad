# Task 6 report — `PageChromePainter`

Commit: `e786df4` — `feat(render): PageChromePainter — sheet, grid over the
visible intersection, page breaks`

## What I implemented

`packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart` — a
`CustomPainter` over a `CameraController` and a
`ValueListenable<PageComponent?>`:

- `paint` resets the three debug counters, returns on a null page or an empty
  size, then draws the sheet rectangle **fill first, edge second** (the fill
  `Paint`'s colour is set per paint from `PageComponent.background`).
- `_paintGrid` calls `GridScale.pick(p.displayUnit, cam.scale, floorMm:
  p.gridStepMm)`, intersects `cam.visibleWorld(size)` with `sheetWorldRect(p)`
  on **both** axes, returns when either intersection is empty, then
  `save`/`clipRect(sheetScreen)`, the minor pass, the major pass, `restore`.
- `_lines` walks the lattice anchored at the sheet origin, verticals then
  horizontals, into the reused `Float32List` and hands the canvas exactly
  `count * 4` numbers as a `Float32List.sublistView`. `skipEvery` drops the
  minor indices that coincide with a major (Ruling 04-3); Dart's int `%` is
  non-negative, so it holds for negative indices too.
- `_paintBreaks` returns under the `kBreaksMinSheetPixels` (16 px) guard on
  either sheet dimension, then tiles dashed lines outward from the sheet
  origin over `visibleWorld`, 6 px on / 4 px off, one `drawPath`.
- `shouldRepaint` is `false` — the `repaint` listenable drives it.

`packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` — added
`export 'src/page_chrome_painter.dart';` after `page_notifier.dart` and
before `reference_walk.dart`, as the task specified.

`packages/jet_cad_2d_flutter/test/page_chrome_painter_test.dart` — all nine
tests from the brief.

## Deviation from the brief's implementation (one, load-bearing)

The brief's `_paintGrid` runs both grid passes from index 0 of the single
`_buffer`. `drawRawPoints` takes the list **by reference** in `SpyCanvas`, so
the major pass overwrites the prefix of the list the minor pass already handed
over, and the recorded "minors" list comes back holding major coordinates in
its first `majorCount * 4` slots.

I gave `_lines` a `start` offset and pass `start: debugLastMinorCount * 4` for
the major pass, so the two passes of one paint write **disjoint spans** of the
one buffer. Still one buffer, still grown once, still a `sublistView` — the
global constraint is unchanged.

I verified the deviation is load-bearing rather than cosmetic. Backed the file
up with `cp` first (per the constraints), changed `start: debugLastMinorCount
* 4` to `start: 0`, ran the suite, restored from the copy:

```
00:00 +4: minors that coincide with a major are not drawn twice
00:00 +4 -1: minors that coincide with a major are not drawn twice [E]
  Expected: a value greater than <0.001>
    Actual: <0.0>
00:00 +8 -1: Some tests failed.
```

## Test-expectation corrections (two, with the arithmetic)

### 1. The oracle's intersection was one-dimensional

`oracleMajorXs` intersected only the x ranges; the painter (correctly, and as
the spec's "grid over `visibleWorld ∩ sheetWorldRect`" says) requires the
intersection to be non-empty on **both** axes. Trial 8 of the seeded sweep
lands exactly on the difference:

- scale `0.0841382790682523`, matrix `(s, 0, 0, -s, tx, ty)`.
- x: viewport spans world `[-tx/s, (800-tx)/s]`, which meets the sheet's
  `[7350, 22200]` on `[7350, ~13400]` → at major step 1000 mm
  (`1000 * 0.08414 = 84.1 ≥ 64`, and `500 * 0.08414 = 42.1 < 64`) that is
  `floor(6050/1000) - ceil(0/1000) + 1 = 7` lines.
- y: the viewport spans world `[(ty-600)/s, ty/s]`, which is entirely off the
  sheet's `[-1230, 9270]` — **no** y overlap.

So nothing is on screen and the painter draws nothing; the 1-D oracle still
claimed 7. First run: `Expected: <7> / Actual: <0> / trial 8, scale
0.0841382790682523`.

I enumerated the seed offline (`math.Random(0x5EED0004)`, same sequence) and
found exactly three such trials — 8, 15 and 47 — all of them "x overlaps, y
does not"; there is no trial where both axes overlap and the painter still
disagrees, and no trial where minors are drawn without majors. Fix: the oracle
now computes `minY`/`maxY` the same way and returns `const []` when either
range is empty. The oracle still carries the ladder as a literal table and
shares no code with `GridScale.pick`.

### 2. `Color` round-trips through `Paint` as float32

`expect(rects.first.color, const Color(0xFFFAF6EC))` failed with expected and
actual printing **identically**:

```
  Expected: Color:<Color(alpha: 1.0000, red: 0.9804, green: 0.9647, blue: 0.9255, colorSpace: ColorSpace.sRGB)>
    Actual: Color:<Color(alpha: 1.0000, red: 0.9804, green: 0.9647, blue: 0.9255, colorSpace: ColorSpace.sRGB)>
```

`Paint` (Flutter 3.47) stores a colour as four **float32** components, while
`Color(0xFFFAF6EC)` holds them as doubles: `0xF6/255 =
0.9647058823529412` as a double is not the float32 nearest it, and `Color ==`
compares the components exactly. The ARGB word survives the round trip, and it
is also the value `PageComponent.background` actually stores, so the
comparison is now `expect(rects.first.color?.toARGB32(), 0xFFFAF6EC)`. The
expected value is unchanged.

### Not a correction, but noted

The brief's comment on the bounded test said "At 0.001 px/mm the sheet is
14.85 px wide and pick is null: nothing." `pick` is **not** null there:
`100000 mm * 0.001 = 100 px ≥ 64`, so the major step is 100 000 mm and the
whole sheet spans one major cell (1 major column + 1 major row = 2 lines,
0 minors, since the single minor index 0 is a multiple of the divisor). The
assertions are `lessThanOrEqualTo` bounds and hold either way; I corrected the
comment's wording only. The 16 px page-break guard is what actually makes the
tiling vanish at that zoom, and the second half of the page-break test covers
it.

### One import removed

`flutter analyze` flagged `unnecessary_import` on the brief's `import
'dart:typed_data';` in the test — `package:flutter/foundation.dart` re-exports
it, and `Float32List` resolves through that. Removed, with a comment saying
why.

## TDD evidence

### RED — `CI=true flutter test test/page_chrome_painter_test.dart`

```
00:00 +0: loading .../test/page_chrome_painter_test.dart
test/page_chrome_painter_test.dart:49:2: Error: Type 'PageChromePainter' not found.
(PageChromePainter, ValueNotifier<PageComponent?>, CameraController) rig(
 ^^^^^^^^^^^^^^^^^
test/page_chrome_painter_test.dart:53:11: Error: Method not found: 'PageChromePainter'.
  return (PageChromePainter(camera: cam, page: n), n, cam);
          ^^^^^^^^^^^^^^^^^
test/page_chrome_painter_test.dart:186:21: Error: Method not found: 'PageChromePainter'.
    final painter = PageChromePainter(camera: standardCamera(), page: n);
                    ^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

### First run against the implementation (the two corrections above)

```
00:00 +0 -1: draws the sheet in its colour under everything [E]
00:00 +1 -2: differential: fifty seeded cameras agree with the literal-ladder oracle [E]
  Expected: <7>
    Actual: <0>
  trial 8, scale 0.0841382790682523
00:00 +7 -2: Some tests failed.
```

### GREEN — `CI=true flutter test test/page_chrome_painter_test.dart`

```
00:00 +0: draws the sheet in its colour under everything
00:00 +1: major lines sit where the oracle says, anchored at the sheet corner
00:00 +2: differential: fifty seeded cameras agree with the literal-ladder oracle
00:00 +3: the point list is exactly four numbers per line
00:00 +4: minors that coincide with a major are not drawn twice
00:00 +5: bounded at kMinScale, kMaxScale, and the intersection is the range
00:00 +6: page breaks tile outward and vanish under a 16 px sheet
00:00 +7: a chrome toggle through the log adds no entity and rebuilds no index
00:00 +8: null page and zero size paint nothing
00:00 +9: All tests passed!
```

## Gate line — `packages/jet_cad_2d_flutter`

### `CI=true flutter test` → exit 1

```
00:14 +786 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

`TEST_EXIT=1`. Exactly the five pre-existing `text_ladder_golden_test.dart`
failures and nothing else; `+786` is the branch point's `+777` plus this
task's nine.

### `flutter analyze` → exit 0

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```

### `dart format --output=none --set-exit-if-changed .` → exit 0

```
Formatted 144 files (0 changed) in 0.27 seconds.
FORMAT_EXIT=0
```

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart` (new)
- `packages/jet_cad_2d_flutter/test/page_chrome_painter_test.dart` (new)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (one export line)

`git status --short` before the commit showed only those three and no
`analysis_options.yaml` rewrite; the tree is clean after it. Commit trailer
check: `git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.

## Self-review

- **Completeness.** All nine brief tests present and green. Counters reset at
  the top of every `paint`. Sheet fill then edge, both before the grid, and
  `canvas.calls.first.name == 'drawRect'` pins the order. Grid over the 2-D
  intersection, with the clip as belt-and-braces. Two `drawRawPoints` calls,
  exact-length `sublistView`s. Page breaks behind the 16 px guard.
  `shouldRepaint` false. Export added.
- **Quality.** The `start` offset is the only structural change from the
  brief, and it is commented at both the field and the parameter. The
  `dart:ui`-facing coordinates are all screen coordinates (Invariant 5). No
  per-entity allocation: the buffer is grown once and the `Paint`s are fields.
- **Discipline.** No subagents. One targeted mutation, to justify the one
  deviation, backed up with `cp` and restored from the copy, not from git. No
  unrequested sweep. Engine package untouched, so its gate line was not run.
- **Pristine output.** `flutter analyze` clean, `dart format` clean, working
  tree clean, no stray files in the repo (the offline seed script lives in the
  session scratchpad).

## Concerns

1. **The seeded sweep's effective coverage is thinner than 50 trials.** With
   `tx, ty ∈ [-5000, 5000]` and the sheet at world `[7350, 22200] ×
   [-1230, 9270]`, the viewport can only reach the sheet at low scales:
   overlap needs `(800 - tx)/scale ≥ 7350`, i.e. `scale ≲ 0.79`. Of the 50
   trials, 24 miss the sheet on one axis or the other and assert
   `0 == 0`. The oracle agreement on the trials that *do* overlap is real, and
   the fixed-camera test plus the bounded test cover the rest, but a future
   sweep would get more out of translations drawn near the sheet.
2. **`onPaintForTest` is exposed but unused by any test in the brief.** I kept
   it because the brief's Interfaces section names it; if no later task uses
   it, it is public API with no caller.
3. The `bounded` test asserts only upper bounds, so it would still pass if the
   painter drew *nothing*. The differential test and the fixed-camera test are
   what pin the positive counts.

---

# Fix round 1

Verdict: Needs fixes. HEAD at the start of the round: `e786df4`.
Fix commit: `2a21fcd` — `fix(render): seeded sweep keeps the sheet on screen;
majors read from the counter`.

The reviewer is right and my round-1 concern understated the problem: I
enumerated the seed with a hand-written copy of the projection rather than
against the real engine types, and concluded 24 of 50 trials were vacuous. Run
against `sheetWorldRect` and `ViewportTransform` themselves, **all fifty**
trials had an empty intersection on at least one axis. Both sides of the
comparison were `[]` in every trial, so the sweep asserted `0 == 0` fifty
times and proved nothing. The painter itself is unchanged in this round except
for comments and annotations.

## What changed, per finding

1. **CRITICAL — camera construction (`test/page_chrome_painter_test.dart`).**
   Replaced the `tx`/`ty` draws with the reviewer's construction verbatim: a
   world point drawn uniformly inside `sheetWorldRect(standardPage())` and a
   screen point drawn uniformly inside `kChromeSize`, with the translation
   solved to map one onto the other — `tx = sx - scale * wx`,
   `ty = sy + scale * wy` (a plus, because the y axis is flipped). Draw order
   is `scale, wx, wy, sx, sy`; the seed stays `0x5EED0004`. That point is then
   in both `visibleWorld` and the sheet at every scale in `[1e-3, 1e2]`, so
   the intersection is non-empty in every trial.
2. **IMPORTANT — `majors` extraction.** Was `raw.isEmpty ? [] : …raw.last`,
   which is wrong whenever the major pass draws nothing: `_lines` skips
   `drawRawPoints` on zero lines, so `raw.last` is then the *minors'* list.
   Now gated on `painter.debugLastMajorCount == 0`, with the reviewer's
   comment.
3. **IMPORTANT — anti-vacuity guard.** `trialsWithMajors` is incremented on
   `expected.isNotEmpty` after the length assertion, and
   `expect(trialsWithMajors, 50, reason: 'a trial with no major line on screen
   asserts nothing')` closes the test. It passes, so every one of the fifty
   trials now compares a non-empty list of major positions. This is the guard
   that would have caught the original defect.
4. **Minor — buffer comment.** The `lib/` comment no longer says
   `drawRawPoints` "takes the list by reference"; `dart:ui` copies into the
   display list, and only the test double holds the view. It now says the
   painter keeps the two spans disjoint so each pass's list stays
   independently readable, and that a canvas holding rather than copying the
   list would otherwise see the wrong grid.
5. **Minor — `@visibleForTesting`.** The three `debugLast*` fields carry it,
   imported through the existing `package:flutter/foundation.dart` show
   clause (`show ValueListenable, visibleForTesting`), matching
   `tile_cache.dart` and `outline_cache.dart`.
6. **Minor — barrel order.** The block now reads `page_chrome_painter`,
   `page_fit`, `page_notifier`.

Nothing else was touched; `SpyCanvas` is untouched, as instructed.

## Covering test — `CI=true flutter test test/page_chrome_painter_test.dart`

Exit code `0`.

```
00:00 +0: loading .../test/page_chrome_painter_test.dart
00:00 +0: draws the sheet in its colour under everything
00:00 +1: major lines sit where the oracle says, anchored at the sheet corner
00:00 +2: differential: fifty seeded cameras agree with the literal-ladder oracle
00:00 +3: the point list is exactly four numbers per line
00:00 +4: minors that coincide with a major are not drawn twice
00:00 +5: bounded at kMinScale, kMaxScale, and the intersection is the range
00:00 +6: page breaks tile outward and vanish under a 16 px sheet
00:00 +7: a chrome toggle through the log adds no entity and rebuilds no index
00:00 +8: null page and zero size paint nothing
00:00 +9: All tests passed!
```

The sweep's `expect(trialsWithMajors, 50, …)` is inside that `+2`, so its
passing is the evidence that the sweep is no longer vacuous.

## Gate line — `packages/jet_cad_2d_flutter`

### `CI=true flutter test` → exit 1

```
00:13 +786 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

`TEST_EXIT=1`, the five pre-existing golden failures and nothing else; the
counter is unchanged at `+786 ~1 -5`.

### `flutter analyze` → exit 0

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.6s)
```

### `dart format --output=none --set-exit-if-changed .` → exit 0

```
Formatted 144 files (0 changed) in 0.31 seconds.
FORMAT_EXIT=0
```

## Files changed this round

- `packages/jet_cad_2d_flutter/test/page_chrome_painter_test.dart` (findings
  1–3)
- `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart` (findings 4,
  5 — comments and annotations only, no behaviour change)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (finding 6)

`git status --short` showed only those three before the commit, no
`analysis_options.yaml` rewrite to restore, and the tree is clean after it.
Trailer check: `git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.

## Concerns after this round

Concern 1 from round 1 is resolved and inverted into an assertion. Concerns 2
and 3 stand unchanged: `onPaintForTest` is public API with no caller in any
test, and the `bounded` test asserts only upper bounds (the sweep and the
fixed-camera test are what pin the positive counts).
