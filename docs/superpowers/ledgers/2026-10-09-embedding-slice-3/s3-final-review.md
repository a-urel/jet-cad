# Slice 3 (`FloorPlanTheme`): independent final review

- **Range:** `8fd7483..6fb7a6d` on `claude/exciting-pasteur-9m22jv` (11 commits: the plan, Tasks 1–4, the three review-fix commits `e111b28`, `fcace6b`, `6fb7a6d`, and `61ca42e`).
- **Where:** my own clones only.
  - `/home/user/review-s3-final` at `6fb7a6d`: the gates and the host probes.
  - `/home/user/review-s3-final-m` at `6fb7a6d`: the differential at the tip, the probes and the mutants.
  - `/home/user/review-s3-final-base` at `8fd7483`: the differential's base. It was deleted after use, to free disk.
- **Edits:** nothing was edited, committed or pushed in `/home/user/jet-cad` except this file.
- **Scratch:** `scratchpad/rv-s3-final/` holds:
  - the differential tests and their outputs: `zz_review_diff_test.dart`, `zz_review_demo_diff_test.dart`, `zz_review_empty_theme_test.dart`, `diff-*.txt`, `demo-*.txt`, `pdf-base/`, `pdf-tip/`;
  - the probes: `zz_review_probe_test.dart`, `zz_review_probe2_test.dart`;
  - the mutants: `mutants.py`, `mut.py`, `mut.log`, `mut2.log`;
  - the gate logs and JSON: `gates/`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`.
- **Incident:** the machine's disk filled during my first gate run: 214 MB were left, mostly by earlier reviews' clones under `/tmp` and `/home/user`.
  - The floor planner's first test run then aborted with "No space left on device".
  - I deleted only orphaned `/tmp/flutter_tools.*` directories, checked first to have no open file handles, and my own base clone, then re-ran that gate.
  - Other agents' clones are untouched.

## Verdict

**Approve with fixes.** Every fix is minor: two documentation items, test gaps and the exit paperwork the plan still owes. None is a code defect.

- **P-1 and invariant 1 hold.**
- **P-6 holds, in pixels:** 234 captures across both commits are byte-identical, and so are the exports.
- **Every gate is green.** The standing sets are exact, and the counts are real.
- **Where the tasks meet, the code is right:**
  - an animated switch validates on every frame;
  - each painter rebuilds at most once per frame;
  - equal themes rebuild nothing;
  - pans rebuild and allocate nothing;
  - the bar, `canvasRect` and R-13 agree.
- **Mutants:** 15 of my 20 are red under the committed suite. Of the other 5:
  - 4 are real test gaps, and probes that are green on `6fb7a6d` kill them (F-2);
  - 1 is equivalent in reach.

## 1. P-1 and invariant 1

- **v0.3.0's host probe.** `tool/ci/host_probe.sh file:///home/user/jet-cad 6fb7a6d7aa87623927328525aa36011b46af2d7d` exits 0:
  - the lock check reads "40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu";
  - `flutter analyze` reads "No issues found!";
  - the build reads "✓ Built build/web" and "host probe: no GPU renderer, no build hook; build/web is 42M".

  `tool/ci/old_host_probe.sh v0.3.0` then printed "No issues found!" and "old host probe: v0.3.0's main.dart analyses against 6fb7a6d7aa87623927328525aa36011b46af2d7d", exit 0. `main.dart` was put back, and the tree was clean afterwards.
- **The public surface, diffed against `8fd7483`:**
  - **The barrel** gains exactly `export 'src/host/floor_plan_theme.dart' show FloorPlanTheme;`. `paperPaletteFor`, `validateFloorPlanTheme`, `FloorPlanThemeScope` and `InheritedFloorPlanTheme` are `@internal` and not shown.
  - **`jet_cad_2d_flutter`'s exports** are unchanged. `PaperPalette` gains `withSelection`; its fields, constructor, `==`, `hashCode` and `toString` are untouched. `SelectionOverlayPainter` gains an optional named `selectionStrokePixels`; the constructor was not `const` before, so the new initializer assert breaks no caller, and `shouldRepaint` widens.
  - **`editor.dart`** exports `planner_view.dart` and `planner_shell.dart` whole. `PlannerView` gains an optional `selectionStrokePixels`, which is not in the CHANGELOG: see F-1. `PlannerShell` gains private state only. No `host/` or `service/` file is exported by `editor.dart`, so `kServiceBarHeight`, `focusVeilColour` and `paintedTextStyle` stay internal.
  - **No existing signature, `==`, `hashCode` or `toString` changed.** Every new parameter is named and optional, with today's value as its default.
- **Edited pre-existing tests.** `git diff --stat 8fd7483 6fb7a6d -- '**/test/**'` lists 8 files: 6 new, and 2 edits, both of which the plan allows:
  - `test/host/barrel_test.dart` +1: `'FloorPlanTheme'` in B1 (Task 1).
  - `test/invariants/theme_colours_test.dart` +3: the whole-file allowance for `apps/restaurant_demo/lib/demo_theme.dart`, with a comment (Task 4).

  No golden changed, and the engine and `jet_cad_2d_gpu` have no diff.

## 2. P-6 differential (no theme): identical

Each capture is a full-window `RenderRepaintBoundary.toImage` in raw RGBA at device pixel ratio 1, hashed with FNV-1a 64. The same test file ran unchanged on `8fd7483` and on `6fb7a6d`, using only APIs both commits have.

**The planner: 216 captures.** Six plans, each in the light and the dark theme, in design and selection, under 4 cameras:

- **The plans:**
  - the palette fixture on a White page, a Blueprint page, and no page;
  - Slice 1's embedding fixture (turned, mirrored, scaled, off origin, hidden and locked layers);
  - the zone fixture (page-less), with a framing camera at 0.04 px/mm (`zoneCamera()` is the pre-fit seed, off screen);
  - the groups look fixture (White).
- **The cameras:**
  - the fixture's own;
  - the same rebuilt;
  - turned +33° and zoomed ×1.3;
  - turned −120° and zoomed ×0.5.
- **The states, per camera:**
  - plain;
  - a selection (a table, or the palette's line);
  - in the selection mode, the statuses: the translucent Bill `0x99E53935`, a dark `0xFF1B1B1B` and a light `0xFFFFE082`, with captions;
  - a group, labelled or not;
  - then a focus that fades a group or its members.

**Result: all 216 identical.** None of the cases is degenerate: within each case, plain, selected and focused differ, and the turned cameras differ from the base one. 159 hashes are distinct.

**The demo: 18 captures**, on the Salon sample at 1600×1000, light and dark platform brightness, with the default (Standard) look:

- design at its fit, 7 selected, and a turned camera;
- service at its fit;
- Bill, a dark and a light status with captions; G1 = {8, 9} labelled and G2 = {5, 6};
- a focus on {1, 2, 3, 6};
- turned −40° ×0.7 and zoomed ×2.2;
- design again.

The region compared is the `FloorPlanView`, (0, 56)–(1300, 1000). The app bar is excluded because it gains the Look switch, by design. **All 18 identical**, and all 18 hashes distinct.

**Exports:**
- **PNG:** 8 of 8 byte-identical (`cmp`): palette White and Blueprint, embedding, look fixture, each in both modes.
- **PDF:** 6 of 6 equal once `/CreationDate`, `/ModDate` and `/ID` are masked. The raw PDF bytes differ between two runs of the same commit too (`diff-base.txt` against `diff-base2.txt`). The embedding fixture's PDF is excluded: it asserts NaN at `8fd7483` already (note N-3).

**An empty `FloorPlanTheme()`.** At the tip, the same 224 planner captures and PNG exports were re-run with `const FloorPlanTheme()` both as the ambient extension and as the view's `theme:`. They are identical to the tip with no theme. This was run on the clean tree after the mutants, and it confirms the guide's sentence "`const FloorPlanTheme()` changes nothing".

## 3. Where the tasks meet (probes; all green on `6fb7a6d`)

| Probe | What it shows | Result |
|---|---|---|
| P1 | An animated switch through `MaterialApp(themeAnimationCurve: Curves.easeOutBack)` between two full themes, every field different, light to dark and back, on the look fixture in the selection mode with statuses, a group and a focus. Checked: `takeException()` on each of 30 frames of 10 ms; each of the four layers' `debugRebuilds` and `debugRecolours` per frame; ten pans afterwards; a counting `tableOverlayBuilder`. | No frame throws. Every layer rebuilds at most once per frame: the status layer on 20 of 30 frames, which is the 200 ms switch. The pans rebuild nothing. The overlay builder is called 0 times (G-5). |
| P2 | An animated switch between two light `ThemeData` with different seeds, both carrying an equal `fullTheme`. Run on a paged plan, and on the page-less zone plan on `canvasBackground`. | Every counter unchanged on both plans (T-3, R-2 through the painters). |
| P3 | `serviceBarHeight` 52 → 60 by an animated theme switch. | No exception. Afterwards the bar is 60, `canvasRect.top` is 60 (Slice 1), the table has moved +8 with the canvas, and a design round trip keeps it in place to 1e-9 (R-13). |
| P4 | 100 pans under no theme against 100 under a colour-only theme with the same geometry, interleaved three times, read with the VM allocation profiler (`--enable-vmservice`, the route the pick test uses). | Totals are within the JIT's noise: 2.29M, 2.32M, 2.31M, 2.32M, 2.29M, 2.27M. `Paint`, `RRect`, path, `FloorPlanTheme` and `PaperPalette` counts are equal across runs. `PaperPalette` is 3 against 2: one extra per build, none per frame. Indicative, not a gate: its whole-heap threshold went red once under unrelated CPU load. |
| P5 | A runtime bar that **shrinks**, 60 → 44, then design. | The table keeps its global position. Kills F06. |
| P6, Q1 | A full view theme removed at runtime restores today's pixels exactly: the capture is compared with a fresh view's that never had a theme, at the look camera and at 0.32× its scale. | 0 pixels differ. Kills F03 and F05. |
| P7, Q2 | The guide's claim that a translucent `canvasBackground` (`0x40000000`) has its ink chosen on its RGB, in each mode. | Both modes take the dark set. Q2 kills F15. |

Seams read in the code and confirmed:
- **Task 2's selection × Slice 1's overlays.** The selection overlay is unchanged in structure. TO10 and TO21 themed are green, and P1 shows a theme switch builds no overlay.
- **The theme × the zone veil × groups.** The chips' veil is `focusVeilColour(paper, look)`, the same function the veil uses, and the faded frame takes the frame colour at α × (1 − opacity). My F16 is red in three tests.
- **The demo's POS look in both brightnesses through a mode switch.** DL1 and DL2 are green in the demo gate (60 tests).
- **The export dialog under a local `Theme`.** The S-12 test is green inside the planner gate.

## 4. Frame path

- **The two allocation invariants are green inside the gates:**
  - engine `query_allocation_test`: 6 of 6 passed, none skipped;
  - render `paint_allocation_test`: 2 of 2 passed, none skipped.
- **The planner's counter tests** are green, in their untouched and themed forms:
  - SP1, TG-L9, FP3 and their themed siblings;
  - TO2, TO10, TO21 and the themed TO10 and TO21;
  - PA1–PA3 with `--enable-vmservice`: 3 of 3 passed, none skipped.
- **Nothing is derived per frame.** In `paint`, the theme is read as `theme?.value` and compared by `identical`. The derived values (`_captionSize`, `_frameWidth`, `_chipBottom`, `_chipShiftX`, the paints, paragraphs and `RRect`s) are set only in `_rebuild`, and the veil's colour only in the recolour branch. P1 and P4 confirm this.

## 5. Docs against code

Every claim in guide § 9 (the table, the snippets, "Light and dark", "What each field does, exactly") was checked against the code, and so were the § 3 and § 4 edits and the CHANGELOG's Slice 3 text. The checks covered:
- fields and units;
- the modes each field reaches;
- defaults: 11 px, the platform font, 2 px, 150 mm, 4 px, 5 and 2 px of padding, 0.6, 44, `ColorScheme.surface`, and the violet `gripMove`;
- merge by `TextStyle.merge`;
- lerp: clamped, a one-sided field or style colour switching at 0.5, and an extension present on one side only (Flutter's `_lerpThemeExtensions`);
- the ranges and the `ArgumentError`;
- the ink on the drawn colour, and on the chip as drawn;
- the chip box centred;
- the veil multiplied, or the paper's colour;
- the hover at 1.5 px and 60 %;
- the bar and R-13;
- the canvas: translucent, ink on its RGB, and not deciding the dark canvas;
- fonts: Roboto via `ensureFloorPlanFonts`, regular face only;
- the export dialog follows a local `Theme` and never the view's `theme:`;
- never stored.

`check_guide`: "docs/host-guide.md: all 37 code blocks are in the host probe", exit 0. Discrepancies are under F-1 and F-4.

## 6. Gates at `6fb7a6d` (my runs; logs in `gates/`)

| Package | Tests | Standing comparison (path form) | Analyze | Format |
|---|---|---|---|---|
| `packages/jet_cad_2d` | `dart test`: "00:24 +1256 -2: Some tests failed." | "packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly" | `dart analyze --fatal-infos`: No issues found! | 170 files (0 changed) |
| `packages/jet_cad_2d_flutter` | "01:27 +1382 ~1 -7: Some tests failed." | "packages/jet_cad_2d_flutter: 1390 tests; … exactly" | No issues found! | 225 files (0 changed) |
| `packages/jet_cad_2d_gpu` | "+20: All tests passed!" | "packages/jet_cad_2d_gpu: 20 tests; … exactly" | No issues found! | 10 files (0 changed) |
| `packages/jet_cad_floor_plan` | `flutter test --enable-vmservice`: "05:30 +1686: All tests passed!" | "packages/jet_cad_floor_plan: 1686 tests; … exactly" | No issues found! | 264 files (0 changed) |
| `packages/jet_cad_restaurant_symbols` | "+97: All tests passed!" | "97 tests; … exactly" | No issues found! | 15 files (0 changed) |
| `apps/restaurant_demo` | "+60: All tests passed!" | "60 tests; … exactly" | No issues found! | 8 files (0 changed) |
| `apps/floor_planner` | "+212: All tests passed!" (after the disk incident's aborted run) | "212 tests; … exactly" | No issues found! | 47 files (0 changed) |
| `tool/ci` | `dart test` "+63: All tests passed!"; `check_guide` exit 0 (37 blocks) | — | `--fatal-infos` over CI's list: No issues found! | CI's list with `host_probe/lib`: 11 files (0 changed) |
| host probe | `host_probe.sh` at the full SHA, exit 0 (§ 1) | — | — | — |
| v0.3.0 probe | `old_host_probe.sh v0.3.0`, exit 0 (§ 1) | — | — | — |

- The planner's 1686 is Task 4's 1679 plus the 7 killers `6fb7a6d` added after Task 4's gates ran. Task 4's gates therefore never ran on the tip; these do.
- `git status` in the gate clone was clean afterwards: no `analysis_options.yaml` drift.
- I did not repeat the web builds or the Playwright smoke check.

## 7. Mutants (mine, 20)

**Method.** Each mutant was applied in `review-s3-final-m` by script (`mut.py`), which asserts exactly one match and restores the file from memory. It was run against the committed suite:
- the slice's 4 test files (`floor_plan_theme_test`, `theme_canvas_test`, `theme_service_test`, `table_theme_painter_test`);
- 7 untouched files (the status, group and focus painter tests, `status_caption_test`, `table_groups_look_test`, `view_test`, `table_overlay_test`);
- 217 tests, with `--enable-vmservice`.

A survivor was then run against my probes. `git diff` was empty after every run.

| # | Mutant (seam) | Committed suite | Probes |
|---|---|---|---|
| F01 | Chip ink taken on the frame colour, not the chip colour (S-6 × S-7) | **red** (2) | |
| F02 | Chip box shift sign flipped (`6fb7a6d` R-1) | **red** (T3-e) | |
| F03 | `_captionSize` sticky after the theme is removed | survived | **red**: Q1 at 0.32× (at 1× the number's own height dominates the "below" rule) |
| F04 | `_frameWidth` sticky after the theme is removed | **red** (1) | |
| F05 | `_chipBottom` sticky after the theme is removed | survived | **red**: P6, Q1 at both zooms |
| F06 | The bar re-measured only when it grows (S-10) | survived | **red**: P5 |
| F07 | Status paint cache keyed by the undimmed colour (opacity × cache) | **red** (M-H33(repaint)) | |
| F08 | Lerp: a style's `fontSize` not clamped | **red** (2) | |
| F09 | Lerp: a one-sided style colour switches one way only | **red** (R-3) | |
| F10 | Lerp: padding's right side not clamped | **red** (2) | |
| F11 | Lerp: a field equal on both sides re-lerped | **red** (R-2) | |
| F12 | Chip ink on the RGB, translucency ignored (revert of `6fb7a6d` R-2) | **red** (1) | |
| F13 | Chip anchor ignores the themed margin | **red** (T3-e) | |
| F14 | The scope resolves an empty theme where there is none (P-6, structural) | **red** (2) | |
| F15 | Selection mode: a translucent `canvasBackground` composited over `surface` before the ink | survived | **red**: Q2 |
| F16 | The veil recolours only when a theme appears or goes | **red** (3) | |
| F17 | A bare shell's ambient left unvalidated (revert of `e111b28` R-4) | **red** (1) | |
| F18 | Lerp: the bar height not clamped | **red** (2) | |
| F19 | Caption ink composited on White whatever the paper | **red** (5) | |
| F20 | `_serviceCanvasMoved` without its mode check | survived | survived. Equivalent in reach: the callback runs after the frame the bar changed in, and only a host call between that frame and the callback could change the mode. |

**Totals:** 15 red under the committed suite, 4 more red under my probes, and 1 equivalent.

## Findings

### F-1 (Minor, docs). The CHANGELOG misses an `editor.dart` addition and the bare shell's theme

- **What is missing.** `PlannerView` is public through `editor.dart:50` and gains `selectionStrokePixels`. A bare `PlannerShell`, the floor planner app's case, now reads the ambient `FloorPlanTheme`: the selection colours and width and `canvasBackground`. It throws `ArgumentError` for one out of range (`e111b28` R-4).
- **Why it matters.** The CHANGELOG's convention lists `editor.dart` additions: `framing:` (`CHANGELOG.md:211`) and `isControlCodeUnit` (`:130`).
- **Fix.** Add one bullet: "`jet_cad_floor_plan`'s `editor.dart`: `PlannerView.selectionStrokePixels` (default `kSelectionStrokePixels`); a `PlannerShell` with no `FloorPlanView` above it follows the ambient `FloorPlanTheme`'s selection and canvas fields and refuses one out of range."

### F-2 (Minor, tests). Four behaviours that matter to a host are unpinned

Each hides a live mutant, and each has a killer that is green on `6fb7a6d`:

| Gap | Mutant | Killer |
|---|---|---|
| Removing a theme at runtime restores today's look (a value set at rebuild outliving the theme) | F03, F05 | Q1, P6: a capture after `theme` goes from `fullTheme` to null equals a fresh view's, at 1× and 0.32× the look camera's scale |
| S-10 when the bar **shrinks** | F06 | P5: 60 → 44, then design: the table keeps its global position |
| The guide's "a translucent `canvasBackground`: the ink is chosen on its RGB", in either mode | F15 | Q2: `0x40000000` page-less under the light theme takes `PaperPalette.dark` in the selection mode (no committed test uses a translucent `canvasBackground`; P7 is the design-mode sibling) |

**Fix:** land Q1 (both zooms), P5, Q2 and P7 in `theme_service_test.dart` and `theme_canvas_test.dart`, from `scratchpad/rv-s3-final/zz_review_probe*_test.dart`, and record the four mutants (F03, F05, F06, F15) with them.

### F-3 (Minor, tests; optional). No committed test drives an animated switch through Task 3's painters

- **The gap.** Task 1's R-1 and R-2 tests animate the scope only. The guide's sentence "the selection mode's painters rebuild at most once per frame of the switch" and the lerp × painters seam are pinned only by my P1 to P3, which are green.
- **Mutants.** I found no single-site mutant that only P1 to P3 kill: the existing tests guard the parts. I record this as optional, under the testing bar.
- **Fix.** If landed, land P1, the per-frame bound with easeOutBack, as the guide's evidence.

### F-4 (Nit, docs). "An extension only the new theme has applies at once" is one frame late

- **What happens.** The frame after the switch is `t = 0`, and `Tween.transform` returns the old `ThemeData`, so the extension applies from the second frame. This is the Task 4 report's finding 3.
- **Fix.** "applies from the switch's first frames", or leave it.

### F-5 (Minor, process). The plan's exit paperwork is not yet written

- **The plan's list.** Task 4 lists the results note `docs/superpowers/notes/2026-10-09-embedding-slice-3-results.md`, STATUS and the roadmap's row 14 (`roadmap/00-README.md:267`).
- **The state at the tip.** None of the three is written. STATUS still says "**Resume point:** Task 1".
- **Fix.** The controller writes them, with this review's figures, before the merge. The spec's Review section is already done.

## Notes (no action asked)

- **N-1. A one-frame jump on the first switch into the selection mode under a non-44 bar.** The selection mode's seed origin is `(0, kServiceBarHeight)`. The demo's POS bar is 52 px, so the first switch per controller shows one frame 8 px off before the existing assumed/measured correction. Task 3 review R-4 noted this; it is pre-existing machinery, and later switches are exact.
- **N-2. P4 is a measurement, not a gate.** The whole heap, about 2.3M instances per 100 pans in a widget test, varies about 1–2 % from run to run.
- **N-3. Pre-existing, outside the slice.** The PDF export of Slice 1's embedding fixture asserts `!value.isNaN` (`pdf/format/num.dart:32`, from `PdfDrawSink.text` → `setTransform`) at `8fd7483` as well as at the tip. The cause is table 9's 1e306 × 1e-306 placement. A hand-edited plan with a non-finite table therefore crashes the PDF export in debug, and probably writes NaN in release. Worth its own task: skip non-finite transforms in the PDF sink, as the pick and fit already do.
- **N-4. The earlier rulings hold at the tip.** These include:
  - Task 4's DM7, an equivalent mutant;
  - the guide's veil sentence after `61ca42e`;
  - the local-`Theme` recipe dropping the app's other theme settings (Task 4 finding 4).
