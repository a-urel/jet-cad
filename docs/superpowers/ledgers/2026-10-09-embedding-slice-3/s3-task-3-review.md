# Slice 3, Task 3: the selection mode's painters and bar (independent review)

- **Commit reviewed:** `74024d7`, parent `fcace6b`, on `claude/exciting-pasteur-9m22jv`.
- **Clones:**
  - `/home/user/review-s3t3` ran the gates.
  - `/home/user/review-s3t3-mut` ran the mutants.
  - `/home/user/review-s3t3-probe` ran the reviewer's probe tests.
  - All three are at `74024d7`. Nothing was edited, committed or pushed in `/home/user/jet-cad`; only this file was written there.
- **Scratch:** `scratchpad/rv-s3t3/`, holding:
  - the runner and mutant definitions: `mut.py`, `defs.py`;
  - the log: `mut.log`;
  - the probe tests: `review_s3t3_test.dart`, `review_s3t3_killers_test.dart`;
  - the gate logs: `planner.log`, `planner_cmp.log`, `*.json`.
- **Flutter:** 3.47.6 at `/root/sdk/flutter/bin`, run with `CI=true`.

## Verdict

**Approved with minor fixes.** I found no blocking defect.
- With no theme, every path is today's, structurally.
- No style value is derived per frame.
- Every named and task-local mutant is red.
- The gates are green, and the counts match the report.

Four minor findings remain:
- two small correctness gaps on non-default values (R-1, R-2);
- five test gaps, each of which I showed to hide a live mutant (R-3);
- one note on R-13 (R-4), which is a confirmation, not a defect.

I recommend fixing R-1 to R-3 before Task 4. Each is a few lines.

## Scope, P-1, P-6, invariant 7 (verified)

**What changed.** `git diff --stat fcace6b 74024d7`:
- five planner `lib` files: the three painters, `service_view.dart` and `floor_plan_view.dart`;
- two new test files.

Nothing else changed:
- no existing test was edited;
- no golden was touched;
- no render, gpu or engine file was touched;
- no `analysis_options.yaml` was committed.

**Every new parameter is optional and named.** `theme` on each painter, and `onCanvasMoved` on `ServiceView`. `shouldRepaint` gains a theme term. No `==`, `hashCode` or `toString` changes.

**With a null theme, every path is today's (read line by line):**
- **Status.** `drawn` is the identical `status.color`, so the paint cache's key is unchanged. The ink is `statusCaptionInk(status.color, paper)`. The paragraph is today's two-line constructor.
- **Groups:**
  - frame and chip colour: `gripMove`;
  - faded frame: `gripMove` at α × 0.4;
  - veiled chip: `focusVeilColour(paper, null)`, which is `Color(paper).withValues(alpha: 0.6)`, today's expression;
  - ink: `foregroundFor(gripMove)`;
  - rect: `(-5, -2, w + 5, h + 2)`, radius 4;
  - anchor: `sy - (h + 2)`.
- **Veil.** Today's colour.
- **Bar.** 44, and the callback is never scheduled, because the height never changes.

**The unedited counter tests and goldens are green inside the planner run:**
- SP1 to SP12, TG-L1 to L11, TG-Z1, TG-Z2, RX1, FP1 to FP7;
- `status_caption_test`, `table_groups_look_test`, `table_groups_toolbar_test`, `view_test`, `view_events_test`;
- TO2, TO10 and TO21 in `table_overlay_test`;
- PA1 to PA3 in `pick_allocation_test`.

**The themed siblings are added beside them:**
- SP1 themed, TG-L9 themed and FP3 themed;
- TO10 themed and TO21 themed, with a full theme and overlays shown.

## Field by field (verified)

**Status opacity.**
- It is applied once, at rebuild: `status.color.a * opacity`, then a paint keyed by the drawn ARGB.
- It cannot compound, because `drawn` is always derived from `status.color`, never from a cached paint.
- An already translucent Bill `0x99…` at 0.5 gives `0x4D`.
- This is pinned by the M-H33(opacity twice) test, including 0.25 → 0.5.

**Caption ink (S-6).** `statusCaptionInk(drawn, paper)` composites the **drawn** colour over the paper. That is correct. It is tested only on White; see R-3.

**Caption style.**
- `paintedTextStyle` is `copyWith`, so it merges:
  - the colour (or the automatic ink) and the size (or 11) fill only the null properties;
  - the weight and family are kept.
- A style with a `foreground` keeps it: `copyWith` drops the `color` when there is a foreground.
- The default font is unchanged: no family with no style (S-2). The `FontLoader` test shows a given family is honoured.

**Groups.**
- frame colour, width (divided by the scale per frame, as the constant was) and margin (in the path, the bounds' width and the anchor);
- chip colour, which defaults to the **resolved** frame colour (S-7);
- radius;
- padding: rect `(-left, -top, w + right, h + bottom)` and anchor `sy - (h + bottom)`;
- faded frame: the frame colour at α × (1 − veil opacity);
- veiled chip: `focusVeilColour` (S-9).

All of these are correct, except for the horizontal placement under asymmetric padding (R-1).

**Veil (S-9).**
- A host colour's alpha is **multiplied** by the opacity.
- With no host colour, the paper's RGB at the opacity, with the paper's alpha replaced.
- Pinned on Blueprint and on a page-less dark `canvasBackground` (M-H32).
- A host colour with **no** opacity is untested; see R-3.

**`serviceBarHeight` and S-10.**
- `_theme.value` is set in `didChangeDependencies` before `build`, so `_barHeightNow()` reads the current theme.
- One post-frame callback runs per change. `_serviceCanvasMoved` measures again in the selection mode only.

My probes `review_s3t3_test.dart` (all green on `74024d7`) confirm R-13 and the Slice 1 interplay:
- **RV1:** the bar is changed while the **design** mode is shown, then the host switches to the selection. The table keeps its global position, to 1e-9. The existing assumed/measured correction handles this; no S-10 callback is involved.
- **RV2:** 44 → 60 → 72 → 50, each followed by design and back. The position is kept each time.
- **RV5:** 44 → 60 → 72 within **one** selection view, then design. The position is kept.
- **RV3:** `canvasRect` and the overlays follow a runtime bar change. After 44 → 60:
  - `controller.canvasRect.topLeft` equals the `InteractionLayer`'s new global top left (+16 px);
  - an overlay badge moves exactly (0, 16) with the canvas;
  - `worldToGlobal(detail.center)` moves (0, 16) with it.

  `PlannerView` checks its rect after every frame (`planner_view.dart:295-321`), so this needs nothing new.

**Invariant 4.** `designJson`, `serviceLayoutJson` and the PNG export are identical with and without `fullTheme` (the test was read and runs green).

## Frame path (P-4, M-H31; verified)

- **No painter derives anything from the theme in `paint`.** The theme is read as `theme?.value` (a field load, S-12) and compared by `identical`. Every derivation happens in `_rebuild`, or, for the veil, inside the recolour branch.
- **The per-frame values are fields set at rebuild:** `_captionSize`, `_frameWidth` and `_chipBottom`.
- **The notifier passes an equal theme through as the same object.** `ValueNotifier` keeps the old instance on `==`, so `identical` is the correct key. The view test also pins that an equal, non-identical host theme rebuilds nothing.
- **Pan and zoom with a theme allocate no more than without one.** SP1, TG-L9 and FP3 themed, the view's M-H31 test, and TO10 and TO21 themed are all green, and the M-H31 mutants turn them red (below).
- **`debugRecolours` (finding 1)** is a plain `int` field with `@visibleForTesting`, the same pattern as the existing `debugAllocations` and `debugRebuilds`.
  - It is not stripped in release.
  - It costs one increment per **recolour** (a paper or theme change), never per frame.
  - I accept it as test-only in effect, and "free" on the frame path.

## Gates (run by the reviewer on `74024d7`)

| Package | Result |
|---|---|
| `packages/jet_cad_floor_plan` | `flutter test --enable-vmservice --file-reporter json:…` gives "+1679: All tests passed!", exit 0. Comparison: "packages/jet_cad_floor_plan: 1679 tests; the standing failures and skips, exactly", exit 0. `flutter analyze`: "No issues found!". `dart format`: "Formatted 264 files (0 changed)". |
| `apps/restaurant_demo` | "+57: All tests passed!". Analyze: no issues. Format: 6 files, 0 changed. |
| `apps/floor_planner` | "+212: All tests passed!". Analyze: no issues. Format: 47 files, 0 changed. |
| `packages/jet_cad_2d_flutter` | `flutter test` exits 1 (the standing failures). Comparison: "1390 tests; the standing failures and skips, exactly", exit 0. |
| `packages/jet_cad_2d_gpu` | "+20: All tests passed!", exit 0. Comparison: "20 tests; … exactly", exit 0. |
| `packages/jet_cad_2d` | `dart test` exits 1 (the 2 standing failures). Comparison: "1258 tests; … exactly", exit 0. |

## Mutants

**How they were run.**
- `mut.py` applies each edit with exactly one match asserted, runs the five files, and restores from an in-memory copy.
- The five files: the two new test files plus `table_status_painter_test`, `table_group_painter_test` and `table_focus_painter_test`, 63 tests on the baseline.
- After every run, `git diff --stat` in the mutant clone was empty.
- Pass 2 and pass 3 added my probe files for the survivors.

### Named (Task 3's M-H31, M-H32, M-H33 forms): all red

| Mutant | Red tests (count) |
|---|---|
| M-H31 status key compares `look?.copyWith()` | 5 (SP1 themed, TG-L9 themed, M-H31 through the view, TO10 and TO21 themed) |
| M-H31 group key, the same | 4 |
| M-H31 veil key, the same | 4 (FP3 themed, …) |
| M-H31 chip `RRect` rebuilt per frame from the theme's radius | 3 |
| M-H31 caption paragraph built per frame | 12 |
| M-H32 a null veil colour is a fixed White | 11 |
| M-H33(repaint), merge form: status | 2 |
| … merge form: group | 2 |
| … merge form: veil | 2 |
| M-H33(repaint), key form: status | 3 |
| … key form: group | 7 |
| … key form: veil | 3 |
| M-H33(opacity twice) at rebuild (`* opacity * opacity`) | 4 |
| M-H33(opacity twice) compounding through the cached paint | 4 |
| M-H33(null caption colour) at the ink (black when a style is set) | 1 |
| M-H33(null caption colour) in `paintedTextStyle` | 2 |

### Task-local: all red

| Mutant | Red tests |
|---|---|
| T3-a, caption cache without the style | 1 |
| T3-a, chip cache without the style | 1 |
| T3-b, chip default `gripMove` | 1 |
| T3-c, ink from the undimmed colour | 1 |
| T3-d, `onCanvasMoved` not passed | 1 |
| T3-d, callback never called | 1 |
| T3-e, right padding read as left | 1 |
| T3-e, bottom padding read as top | 1 |

### The reviewer's own (24)

| # | Mutant | Result |
|---|---|---|
| R01 | host veil alpha replaced, not multiplied | red (1) |
| R02 | chip ink on `gripMove`, not on the chip colour | red (1) |
| R03 | faded frame at the constant 0.6 | red (1) |
| R04 | faded frame from `gripMove`, not the frame colour | red (2) |
| R05 | veiled chip ignores the host veil colour | red (1) |
| R06 | caption style replaced (`TextStyle(...)`), not merged (`copyWith`) | red (2) |
| R07 | default size 14, not 11 | red (1) |
| R08 | re-measure called synchronously in `build` (stale layout) | red (2) |
| R09 | `_canvasMoveDue` never reset: only the first change in a view is re-measured | **survived** the task's tests; **red** under my RV5 |
| R10 | the status painter's `shouldRepaint` without the theme | survived: **equivalent** (the painters are `late final`, never replaced) |
| R11 | rect top from the bottom padding | red (1) |
| R12 | under a theme, the caption ink ignores the paper (composited on White) | **survived** the task's tests; **red** under my K12 |
| R13 | a host veil colour with no opacity at 1, not 0.6 | **survived** the task's tests; **red** under my K13 |
| R14 | the themed caption not centred (`getParagraphStyle()` without `textAlign: center`) | **survived** the task's tests; **red** under my K14 |
| R15 | frame paint takes the chip colour | red (2) |
| R16 | chip style falls back to the caption style | **survived** the task's tests; **red** under my K16/K17 |
| R17 | caption style falls back to the chip style | **survived** the task's tests; **red** under my K16/K17 |
| R18 | "below" rule constant | red (1) |
| R19 | re-measure recorded for the design mode | red (1) |
| R20 | opacity never applied to the fill | red (4) |
| R21 | margin left out of the chip's skip width | red (1) |
| R22 | veil recolour drops the theme | red (5) |
| R23 | paper veil's alpha multiplied, not replaced | red (5) |
| R24 | callback also on the first build | survived: **equivalent** (it measures what `_measureAfterFrame` measures after the same frame) |

**Survivors under the committed tests:** R09, R12, R13, R14, R16 and R17 are real; R10 and R24 are equivalent. Each real survivor goes red under a probe that is green on `74024d7` (R-3).

## Findings

### R-1 (minor): with asymmetric padding, the chip box is off the frame's centre

`table_group_painter.dart:511` translates by `sx - p.width / 2`, which centres the **label** on the anchor. The rect is `(-left, …, w + right, …)`, so the **box's** centre sits `(right − left)/2` right of the frame bounds' centre x: 1 px for the fixture's `(7, 3, 9, 4)`.

The table-groups fixes spec F-4 places the **chip**, not its text, "centred horizontally on the frame bounds' centre x" (`2026-10-05-table-groups-fixes-design.md:155`). Padding semantics (`EdgeInsets` in a centred box) agree: asymmetry moves the content inside a centred box.

T3-e currently asserts the label's centring (`t.dx + p.width / 2 == sx`), which pins the deviation.

**Fix:**
1. Store `_chipShiftX = (padRight - padLeft) / 2` at rebuild.
2. Translate by `sx - p.width / 2 - _chipShiftX`.
3. Change T3-e to assert `t.dx + (rrect.left + rrect.right) / 2 == sx` at both zooms.

This is unchanged with no theme, where the shift is 0.

### R-2 (minor): the chip's automatic ink ignores the chip colour's alpha (finding 7)

`table_group_painter.dart:356-359` takes `foregroundFor(chipColour RGB)`. A translucent `groupChipColor` (or, by S-7, a translucent `groupFrameColor` the chip defaults to) is drawn over the paper but inked as if opaque.

Probe RV4: `0x40FFFFFF` on Blueprint.
- The code picks **black** ink (`foregroundFor(0xFFFFFF) = 0`).
- The drawn chip is `0x576B87`, for which `foregroundFor` and `statusCaptionInk(chip, blueprint)` give **white**.

The status caption already does this right (S-6, "what it sits on").

**Fix:** `chipStyle?.color ?? statusCaptionInk(chipColour, paperArgb)`. `over()` of an opaque colour is its RGB, so `gripMove` (opaque in both palettes, `canvas_palette.dart:141, 157`) inks as today, and P-6 holds. Add the RV4 case as a test (dark glyphs before the fix, white after).

### R-3 (minor): five behaviours are untested, each hiding a live mutant

| Gap | Survivor | Killer (green on `74024d7`, red under the mutant) |
|---|---|---|
| S-6 under a theme on a **dark** paper (every caption test renders on White) | R12 | **K12**: `0xFFFFE082` at `statusFillOpacity: 0.3` on Blueprint. The drawn colour is dark, so the brightest glyph pixel in the caption box is `0xFFFFFF`. |
| A host `focusVeilColor` with **no** `focusVeilOpacity` | R13 | **K13**: `focusVeilColour(white, FloorPlanTheme(focusVeilColor: 0xFF6D4C41)).a == 0.6` (or read back in pixels in the veil test). |
| The themed caption's horizontal centring | R14 | **K14**: for no theme and for `TextStyle(fontSize: 14)`, the midpoint of `getBoxesForRange(0, 4)` is `p.width / 2`, within 0.5. |
| Field independence: a caption style must not reach the chip, nor a chip style the caption | R16, R17 | **K16/K17**: `statusCaptionStyle: 16 px` alone leaves the chip paragraph's height at today's; `groupChipTextStyle: 16 px` alone leaves the caption's. |
| A second bar change inside one selection view | R09 | **RV5**: 44 → 60 → 72 in one view, then design. The table keeps its global position (T3-d changes the bar once per view). |

**Fix:** land these five killers (from `scratchpad/rv-s3t3/review_s3t3_killers_test.dart` and `review_s3t3_test.dart`'s RV5, adapted to the new test files) and record them in the report.

**Optional:** add RV1 (the bar changed in the design mode) and RV3 (`canvasRect` and the overlays follow the bar). They are green and kill nothing I tried, but they pin the S-10/R-13 and Slice 1 interplay the plan asks about.

### R-4 (note): S-10 and R-13 hold, including the cases the plan does not name

A bar change made while the design mode is shown is corrected by the existing assumed/measured machinery on the next switch (RV1). Repeated changes are re-measured each time (RV2, RV5). `canvasRect` and the overlays follow (RV3).

As the plan accepts, a runtime change moves the plan 16 px on screen with the canvas, and the first switch into the selection under a non-44 bar shows one frame at the seed's origin before the correction. That is the pre-existing machinery.

**Nit:** `floorPlanCanvasSeeds`' `Offset(0, 44)` (`floor_plan_controller.dart:47`) could name `kServiceBarHeight`, so the two cannot drift. Optional.

## Rulings on the implementer's findings

1. **`debugRecolours`: accepted.** Without it, a per-frame `Color` derivation in the veil is invisible to every counter, which is why M-H31's veil form survived the first run. It is the existing counters' pattern, costs nothing per frame, and FP3 is untouched.
2. **X12 is equivalent: accepted.** `paintedTextStyle` applies `style.color` anyway, so the `style?.color ??` in the ink only shapes the cache key. Keeping it avoids a second identical paragraph on a paper flip. With R-2's fix, the same holds for the chip.
3. **The veil over the plain paper is invisible: accepted.** This is a real degenerate-fixture catch. The fix (an opaque status on 20, a reference shot at the matching fill opacity) is sound, and MH33rep-merge-veil and MH33rep-key-veil are red under it.
4. **TG-L9 themed at 0.1 px/mm: accepted.** It is a sibling, not an edit of TG-L9. At 0.06 the 14 px bold caption is skipped, which would change the objects compared, not the property under test.
5. **The test font measures Roboto narrower: accepted.** The plan's "wider" is a fact about the platform default, not about `flutter_test`'s fixed-advance face. "Measures as the loaded family, with the faces premised apart" is the right invariant, and R06 (the family dropped through a replaced style) is red under it.
6. **The asymmetric padding centres the label: not accepted as is.** See R-1. The chip box should be centred (table-groups fixes F-4). Move the label by `(left − right)/2`, and assert the box's centre in T3-e.
7. **The chip ink is taken on the chip colour's RGB: confirmed as a defect** for translucent chip or frame colours. See R-2, with the one-line fix that keeps P-6.
8. **S-10's trigger is the built height: accepted.** The `Container` in the `Column` takes exactly that height. RV2, RV3 and RV5 confirm it, and several changes in one frame give one callback.
9. **New internal top-level names: accepted.** `kServiceBarHeight`, `focusVeilColour` and `paintedTextStyle` are not in the barrel (`lib/jet_cad_floor_plan.dart` grep: none).
