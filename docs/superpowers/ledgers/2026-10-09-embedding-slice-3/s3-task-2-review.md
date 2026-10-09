# Slice 3, Task 2: the selection colours, their width and the canvas (independent review)

- **Commit reviewed:** `58c4a60` (parent `620dabd`), branch `claude/exciting-pasteur-9m22jv`.
- **Where:** my own clones: `/home/user/review-s3t2` for the gates, `/home/user/review-s3t2-mut` for the mutants, and `/home/user/review-s3t2-probe` at `8fd7483` for the hover probe. Scratch files are in `scratchpad/rv-s3t2/`. Nothing was edited in `/home/user/jet-cad` except this file.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, with `CI=true`.

## Verdict

**Approved, with two test-only fixes to fold in (R-1, R-2).** Neither blocks Task 3.

- The code does what Task 2, S-8 and T-1's selection and canvas rows ask, in both modes.
- P-1 and P-6 hold structurally.
- Every gate is green, with the standing sets exact.
- Every named and task-local mutant is red.
- Of my 21 own mutants, three survive:
  - **R-1** is a real coverage gap, and a test that kills it is given below.
  - **R-2** is the untested assert.
  - **R-3** is pixel-equivalent; I record it and do not ask for a fix.

## 1. Scope and P-1

- **Files changed.** `git diff --name-status 620dabd 58c4a60` shows only the eight files the report lists:
  - two library files in `jet_cad_2d_flutter`;
  - four library files in the planner;
  - two new test files.
- **Tests.** No existing test was edited, and `paint_allocation_test` is untouched (S-1).
- **Engine.** Not touched.
- **`jet_cad_2d_flutter` is additive:**
  - `PaperPalette` gains one method, `withSelection`. No field, constructor, `==`, `hashCode` or `toString` changed. Equality still covers all twelve colours, and there is no new state to include.
  - `SelectionOverlayPainter` gains one named optional parameter whose default is `kSelectionStrokePixels`. The constructor was not `const` before, so the new initializer `assert` changes nothing for callers.
  - `shouldRepaint` widens from palette `!=` to palette `!=` or width `!=`.
  - The exports are unchanged. `canvas_palette.dart`, `selection_overlay.dart` and `selection_style.dart` are whole-file exports at `jet_cad_2d_flutter.dart:7, 62-63`.
- **The planner:**
  - `paperPaletteFor` is `@internal` in `floor_plan_theme.dart`. The barrel exports that file `show FloorPlanTheme` only, so the function does not leak.
  - `PlannerView.selectionStrokePixels` is optional.
- **The only readers.** `paper.selection` and `paper.hover` are read only in `selection_overlay.dart:134-135`. `kSelectionStrokePixels` is read only in the overlay and as the planner's defaults (grep over `packages/*/lib` and `apps/*/lib`). No tool overlay reads either.

## 2. P-6 (no theme)

- **Structural.** With no theme:
  - `paperPaletteFor(paper, null)` returns `PaperPalette.forPaper(paper)`, the identical `const` set;
  - the width is `kSelectionStrokePixels`;
  - `_canvasColour` is `scheme.surface`.

  So `_surfaceArgb`, `displayPaperFor`, the resolver key, `_paper` and the `ColoredBox` all take today's values. An ambient `FloorPlanTheme()` with every field null takes the same path. Mutant O-X10 in the implementer's run and the P-6 widget test (`identical(view.paper, PaperPalette.light)`) pin this.
- **Today's look, re-run.** These pass unedited inside the full runs below:
  - render: `painter_palette_test`, `selection_overlay_test` (`:299`, `:320`, `:592`), `selection_overlay_grips_test`, `tool_palette_test`, `dark_canvas_test`, `golden/*`, `paint_allocation_test`;
  - planner: `planner_palette_test`, `dark_canvas_test`, `view_palette_test`, `canvas_ui_test`, `widget_theme_test`, `status_caption_test`.
- **The hover is exactly today's.** `withSelection` sets `hover` to `selection.withValues(alpha: selection.a * 0x99 / 0xFF)`. For an opaque selection this is `153.0 / 255`, the same double that `Color(0x99……)` stores, so `light.withSelection(light.selection) == light`, and the same holds for `dark`. The render test pins this, and my O1 (a different ratio for the dark set only) is red there.
- **The 14d rule.**
  - `darkCanvasFor` keys on the theme's brightness and the page, never on `canvasBackground`.
  - A dark theme over a White page still shows `kDarkCanvasPaper` with `selectionOnDark`, and `canvasBackground` only colours the surround. The test "selectionOnDark on the dark canvas" covers this in both modes.
  - A page-less plan is never a dark canvas (`page != null`), so its paper is `canvasBackground`, and the ink and the palette set follow its RGB.
  - This is the spec's "the paper's own rules stay" (T-1). See R-4 for the one consequence worth a line in the guide.

## 3. Both modes

- **The selection follows the paper's set.** `paperPaletteFor` keys `selectionOnDark` / `selectionOnLight` on the set `forPaper` picks from the display paper, not on the theme's brightness.
  - A theme with only `selectionOnLight` leaves Blueprint on the identical `PaperPalette.dark`.
  - Both modes call it from `_paperArgb()` in `build`.
  - A runtime switch of the paper between light and dark rebuilds through `_onPage` when the resolver key moves, which happens exactly when `forPaper` flips. My O18 (the palette cached in `didChangeDependencies`) is killed by `planner_palette_test`'s M-DT-9.
- **The width reaches exactly S-8:**
  - the world outline (`selectionStrokePixels / scale`);
  - the screen-space selected stroke;
  - the selected cross's half-length (`3 ×`);
  - the preview cross's half-length (`3 ×`).

  The hover keeps 1.5 px in both its outline and its cross. The preview keeps its own stroke, and the grips are untouched. Each of these is pinned by a red mutant (T2-c, O4 to O7).
- **`canvasBackground`.**
  - It feeds `_surfaceArgb`, so the page-less paper, the resolver key, the palette set and `ServiceView._paper` all follow it.
  - The same `_canvasColour` paints the surround's `ColoredBox`.
  - This holds in both modes, and `didChangeDependencies` sets the theme before `_surfaceArgb`. My O13 and O14 reverse that order, and both are red.
  - In `ServiceView`, nothing listens to `_theme` yet (Task 3), so moving `_theme.value =` above `_surfaceArgb` cannot fire a listener before the `late` field is set.
- **A theme change repaints.**
  - A `FloorPlanThemeScope` change runs `didChangeDependencies`, then `build`, then a new `PlannerView` and a new `SelectionOverlayPainter`.
  - `shouldRepaint` compares the palette by value and the width by `!=`.
  - The planner's `selectionWidth: 4` test changes the view theme alone, with no camera move, and one pump draws the 4 px rows in both modes. T2-b and my O9 are red there.
- **P-4.**
  - The palette is derived in `build`, never in `paint`.
  - The overlay still assigns `paper.selection` and `paper.hover` to its own field `Paint`s per frame. That is a field load (S-12).
  - The themed reuse test proves that the same two `Paint` objects reach the canvas across a pan under a themed palette and width.

## 4. Gates (my runs, from the committed tree)

| Package | Test | Comparison (path form) | Analyze | Format |
|---|---|---|---|---|
| `packages/jet_cad_2d_flutter` | `flutter test`, exit 1 on the standing failures | "**1389 tests**; the standing failures and skips, exactly", exit 0 | No issues found | exit 0 |
| `packages/jet_cad_floor_plan` | `flutter test --enable-vmservice`, exit 0 | "**1643 tests**; … exactly", exit 0 | No issues found | exit 0 |
| `packages/jet_cad_2d_gpu` | `flutter test`, exit 0 | "**20 tests**; … exactly", exit 0 | No issues found | exit 0 |
| `packages/jet_cad_2d` | `dart test`, exit 1 on the 2 standing failures | "**1258 tests**; … exactly", exit 0 | — | — |
| `apps/restaurant_demo` | "+57: All tests passed!" | — | exit 0 | exit 0 |
| `apps/floor_planner` | "+212: All tests passed!" | — | exit 0 | exit 0 |

Every count matches the implementer's report.

## 5. Mutants

**How they were run.** The runner is `scratchpad/rv-s3t2/mut.py`. It asserts that each edit matches exactly once and restores the file in a `finally`. After the run, `md5sum -c` over the six library files was OK.

**The suites.**
- Render: `selection_theme_test`, `selection_overlay_test` and `painter_palette_test` (42 tests).
- Planner: `host/theme_canvas_test`, `planner_palette_test`, `dark_canvas_test` and `host/view_palette_test` (47 tests).
- The baseline was green in both: 42/42 and 47/47.

### Named and task-local mutants: all red

| Mutant | Red in |
|---|---|
| M-H33(canvasBackground), shell `_surfaceArgb` on `surface` | `M-H33(canvasBackground) (design)`, `a bare PlannerShell…` |
| M-H33(canvasBackground), `ServiceView` | `M-H33(canvasBackground) (selection)` |
| M-H33(editor's selection), shell `forPaper` | 5: `M-H33(the editor's selection) (design)`, `selectionOnDark on the dark canvas (design)`, `only selectionOnLight (design)`, `T2-a…`, `bare PlannerShell` |
| M-H33(editor's selection), `ServiceView` `forPaper` | 3, the selection-mode siblings |
| M-H33(editor's selection), the sets swapped in `paperPaletteFor` | 9, including `paperPaletteFor: today's const sets…` |
| T2-a, hover not derived | render 4 (`T2-a…`, `translucent…`, `at 4 px … rotated…`, `Paints reused…`); planner 2 (`T2-a: a hovered line…`, `bare PlannerShell`) |
| T2-b, `shouldRepaint` ignores the width | render `shouldRepaint … (T2-b)`; planner `selectionWidth: 4` in both modes |
| T2-c, the width on the hover outline | render 3, including the pre-existing `hover on a selected key draws once` |
| T2-d, shell `ColoredBox` on `surface` | 3: `T2-d (design)`, `M-H33(canvasBackground) (design)`, `bare PlannerShell` |
| T2-d, `ServiceView` `ColoredBox` | 2: `T2-d (selection)`, `M-H33(canvasBackground) (selection)` |

### My own mutants

| # | Mutant | Result | Killer |
|---|---|---|---|
| O1 | hover alpha × 0.5 for the dark set only | red | `the derivation is today's hover…`, `T2-a…`, `Paints reused…` |
| O2 | hover at a fixed alpha `0x99` (ignores the selection's alpha) | red | `a translucent selection…` |
| O3 | hover alpha rounded to 8 bits | red | `a translucent selection…` |
| O4 | selected cross half-length reads the const | red | `at 4 px a selected point's cross…` |
| O5 | screen-space selected stroke reads the const (width not reaching the point cross) | red | the same |
| O6 | preview cross half-length reads the const | red | `the move preview's point cross…` |
| O7 | hover cross half-length takes the selection width | red | `at 4 px a selected point's cross … hovered … 4.5 px` |
| O8 | `shouldRepaint` compares the palette by identity (would repaint on every rebuild with a themed palette) | red (render only) | `shouldRepaint … (T2-b)`, `shouldRepaint: true exactly when the paper set differs, by value` |
| O9 | `shouldRepaint` only when the width shrinks | red | render `(T2-b)`; planner `selectionWidth: 4` in both modes |
| **O10** | **`canvasBackground` honoured only under a light Material theme, both modes** | **survived** (whole planner suite: only `theme_canvas_test` and Task 1's non-painting `floor_plan_theme_test` mention the field) | none; see **R-1** |
| O11 | `selectionOnDark` used on light paper when set | red | `paperPaletteFor…`, `M-H33(the editor's selection)` in both modes |
| O12 | shell palette keyed on `_surfaceArgb`, not the display paper | red | 6, including M-DT-1/2, M-DT-9, M-DT-11, `T2-d (design)` |
| O13 | `ServiceView` reads the theme after `_surfaceArgb` (stale by one) | red | `M-H33(canvasBackground) (selection)` |
| O14 | the same in the shell | red | `M-H33(canvasBackground) (design)`, `bare PlannerShell` |
| O15 | shell width from the ambient extension only (ignores the view's `theme:`) | red | `selectionWidth: 4 (design)`, `invariant 4 (design)` |
| **O16** | **the overlay derives the hover in `paint` from `paper.selection`** (per-frame derivation and a `Color` allocation, P-4) | **survived** (render and planner) | none; see **R-3** |
| **O17** | **the width's assert removed** | **survived** | none; see **R-2** |
| O18 | shell palette cached in `didChangeDependencies` (paper switch not followed) | red | `M-DT-9` (`planner_palette_test`) |
| O19 | `withSelection` takes `preview` from the selection | red | `the derivation is today's hover…`, `the ten other colours…` |
| O20 | `ServiceView` passes the const width | red | `selectionWidth: 4 (selection)`, `invariant 4 (selection)` |
| O21 | `PlannerView` drops the width to the overlay | red | 5, both modes plus the bare shell |

**Totals.** 10 named and task-local mutants, all red. 21 of mine, 18 red and 3 survived (O10, O16, O17).

## Findings

### R-1 (minor; test gap, a surviving mutant). `canvasBackground` is never tested under the dark Material theme

- **The gap.** Every `canvasBackground` fixture runs under `ThemeMode.light`:
  - `M-H33(canvasBackground)`;
  - `T2-d`;
  - `invariant 4`;
  - the bare shell.
- **What survives.** O10, which honours `canvasBackground` only under a light theme in both modes, survives the whole planner suite.
- **Why it matters.** T-1 says a host puts one `FloorPlanTheme` in each `ThemeData`, so a dark-theme `canvasBackground` is the ordinary case, not an edge case. The plan's fixture list has the reverse disagreement (a dark canvas under the light theme) but not this one.
- **Fix.** Add the reverse disagreement to `test/host/theme_canvas_test.dart`, in both modes: a page-less plan under `ThemeMode.dark` with a light `canvasBackground` (`0xFFFFF3E0`, which inks black) and `selectionOnLight: onLight, selectionOnDark: onDark`. Expect:
  - the surround to be `0xFFF3E0`;
  - `expectDarkInk`;
  - the selection `onLight`, because the paper is light although the theme is dark.

  I wrote exactly this test in my clone (`scratchpad/rv-s3t2/proposed-tests.diff`). It passes on `58c4a60`, 2/2, and under O10 it is red in both modes, 0/2.

### R-2 (nit; untested contract). The overlay's width assert is never exercised

- **The gap.** The plan says "asserted finite and above 0", and O17 (the assert removed) survives.
- **How much it matters.** The planner path is guarded by Task 1's `validateFloorPlanTheme`. But `SelectionOverlayPainter` is a public render-package class with its own contract: a 0 width is Skia's hairline, which is exactly what S-5 refuses.
- **Fix.** Add a render test in `selection_theme_test.dart`: `0.0`, `-1.0`, `double.infinity` and `double.nan` each `throwsAssertionError`, and `0.25` is accepted. I ran it in my clone: green on `58c4a60`, red under O17.

### R-3 (observation; no fix asked). A per-frame derivation in the overlay is invisible to every test

- **What survives.** O16 replaces `_hover.color = paper.hover` with a derivation from `paper.selection` in `paint`. It is pixel-identical for every palette, because the derivation is the same formula, and it allocates one `Color` per frame, which is O(1) per flush. CLAUDE.md's bar allows that, but P-4 and S-12 forbid it.
- **Why nothing catches it.** No counter test covers the overlay's allocations, and `paint_allocation_test` does not paint it (S-1). The themed reuse test pins the `Paint` objects, not the colours.
- **Ruling.** It is a review-only guard, as it was before this task. It is not this task's to fix. If Task 3 adds a counter seam for the selection-mode painters, the overlay could share it later.

### R-4 (observation; guide note for Task 4). A light `canvasBackground` under a dark theme over a light page

- **What happens.** The sheet shows `kDarkCanvasPaper` (14d, K1), while the surround shows the host's light colour.
- **Ruling.** This follows the spec ("the paper's own rules … stay", T-1), and the code is right. A host that wants a light surround in its dark theme will see a dark sheet on it. The guide's `FloorPlanTheme` section should say so in one line: `canvasBackground` does not decide the dark canvas, the theme's brightness does.

## Rulings on the implementer's findings

1. **The shared scratchpad incident.** Noted. My gates and mutants ran in my own clones and directories, and their results agree with the report's re-run mutant for mutant, where we overlap: every named mutant, T2-a to T2-d, and X1 to X6, which I reproduced as O4, O5, O6, O20 and O21.
2. **The crash when a design view is removed during a hover: confirmed pre-existing, out of scope.**
   - **The probe.** I wrote my own probe at `8fd7483` (main before Slice 3): a design-mode `FloorPlanView` on the palette fixture, `setHover`, then `pumpWidget(SizedBox())`.
   - **Result.** It fails with "setState() or markNeedsBuild() called during build" through `_InteractionLayerState.deactivate` → `_release` → `SelectionController.setHover(null)` → `_SelectionPanelState._sync` → `setState` (`selection_panel.dart:955`). The control without a hover passes.
   - **The workaround.** The T2-a test clears the hover before teardown. That is legitimate, and its comment says why.
   - **What to do.** It should be filed separately (a host removing the view under the pointer will hit it). Candidate fixes:
     - `_SelectionPanelState._sync` defers its `setState` when `SchedulerBinding.instance.schedulerPhase` is in the build or persistent-callback phase;
     - or the interaction layer releases the hover in `dispose` only, or after the frame.
3. **The selected colour is read as RGB within 3.** Accepted. The theme colours are opaque, and the composite T2-a test computes its expectation itself.
4. **`withSelection(set.selection)` is an equal copy, not the const set.** Accepted. Identity is `paperPaletteFor`'s job, and it is pinned (X10 in the report; the P-6 test asserts `identical`).
5. **`paint_allocation_test` is untouched (S-1).** Confirmed by the diff.
6. **One palette allocated per rebuild: accepted, no cache.**
   - Neither mode rebuilds on pan or zoom. The shell's only `setState`s are a resolver-key change and the left-tab switch, and `ServiceView`'s only one is a resolver-key change. Otherwise they rebuild on dependencies or a host rebuild.
   - Each rebuild allocates one `PaperPalette` only when the theme has a colour for the paper's set.
   - `PageChromePainter` and the overlay compare the palette by value, so an equal palette does not repaint. My O8, which compares by identity, is red. The cost is one object per build and nothing per frame, which is P-4's "when a painter rebuilds".
