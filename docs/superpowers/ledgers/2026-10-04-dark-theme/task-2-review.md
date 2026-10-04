# Task 2 review — the painters (D5 painters, R-8, R-13, R-14)

Reviewer: independent. Diff `23314be..2a439e0`, detached worktree
`/home/user/jet-cad/.worktrees/dark-review` at `2a439e0`. Logs:
`scratchpad/review2/` (`gate-*.log`, `mut-*.log`, `mut-summary.txt`, `mut.py`).

## Verdict: Approved

No defect in lib. One minor test gap (finding 1) and three notes. Finding 1
does not block: it is a two-line test addition, and Task 3 or 4 can carry it.

## 1. Implementation against the spec and the plan

- **PageChromePainter.** The sheet edge comes from `chrome.sheetEdge` (D2).
  Minor grid, major grid and breaks come from `paper.*` (D3). All are
  assigned in `paint` after the `p == null || size.isEmpty` return and before
  the first draw. No Paint is used before its colour is set. Both palettes
  are required. `shouldRepaint` is `old.chrome != chrome || old.paper != paper`.
- **RulerPainter / RulerCornerPainter.** The bar, ink and marker are set at
  the top of `paint`. The corner box is set likewise. Each class has its own
  `late final TextStyle _labelStyle` built from `chrome.rulerInk` (R-8).
  `shouldRepaint` compares the chrome by value.
- **RulerFrame.** It takes a required `chrome` and reads `widget.chrome` in
  `build` for all three painters. Nothing is cached in state (the `late final`
  fields there are only the repaint listenables, as before).
- **SelectionOverlayPainter.** All seven Paints are recoloured from `paper`
  right after the `size.isEmpty` return. The stem stays on `grip`, as it was
  on `kGripColor`. The Paints remain distinct field objects.
  `shouldRepaint` is `oldDelegate.paper != paper`. The tool API is untouched
  (that is Task 3).
- **Old constants.** None of the four painter files reads one any more
  (grep). The constants themselves are untouched, per R-C1-1.
- **PlannerView behaviour is unchanged.** It passes `ChromePalette.light` to
  `RulerFrame` and `PageChromePainter`, and `PaperPalette.light` to
  `PageChromePainter` and `SelectionOverlayPainter`. Each carries a
  `// Task 4` comment. Task 1 pins the `.light` fields to the old constants
  (M-DT-19 plus the transitional test), so the planner canvas renders the
  same colours. See note C for how weakly this is guarded.
- **Light theme pixels.** Every `.light` field equals the constant it
  replaces, and draw order and geometry are unchanged. The goldens and
  pixel tests pass unedited.

## 2. Gates (rerun by me; Flutter at /home/user/flutter, `CI=true`)

| Package | test | analyze | format | Implementer |
|---|---|---|---|---|
| render `jet_cad_2d_flutter` | `+1291 ~1 -7` (the standing text_ladder rungs 1-5 and text_lod_ladder rungs 1-2, all RenderBackend.canvas) | No issues | 217 (0 changed) | same |
| planner `jet_cad_floor_plan` | `+1167` all passed | No issues | 193 (0 changed) | same |
| `jet_cad_restaurant_symbols` | `+94` all passed | No issues | 13 (0 changed) | same |
| `apps/floor_planner` | `+201` all passed | No issues | 44 (0 changed) | same |
| `apps/restaurant_demo` | `+17` all passed | No issues | 3 (0 changed) | same |
| `apps/dev_harness_2d` | `+82` all passed | No issues | 22 (0 changed) | same |

On its own, `test/painter_palette_test.dart` gives `+18: All tests passed!`.
All counts match the report.

## 3. Mutants (cp backup, exact-string edit, `flutter test test/painter_palette_test.dart`, cp back, `diff` = 0 every time)

**The named mutants, re-fired. All are red.**

| ID | Result | Evidence |
|---|---|---|
| M-DT-4 (minor and major from `PaperPalette.light`) | red `+16 -2` | `Expected: a value greater than <62.93…> Actual: <54.93…>`; grid Paint `Expected: <352321535> Actual: <335544320>` |
| M-DT-5 (breaks from `.light`) | red `+17 -1` | — |
| M-DT-6-bar / -ink / -label / -corner / -cornerlabel | red `+16 -2` each | label: `Expected: <4291348680> Actual: <4282664004>`, pixel `Actual: <68.0>` |
| M-DT-7 (edge from `ChromePalette.light`) | red `+17 -1` | `Expected: <4287269514> Actual: <4288585374>` |
| SR-chrome-nopaper, SR-ruler-false, SR-overlay-identity | red `+17 -1` each | — |

**My own mutants**

| ID | Mutation | Result |
|---|---|---|
| OWN-edge-from-paper | `_sheetEdge.color = identical(paper, PaperPalette.dark) ? dark.sheetEdge : light.sheetEdge` | **red** (M-DT-7, dark/White row) |
| OWN-grid-from-chrome | minor and major chosen by `identical(chrome, ChromePalette.dark)` | **red** `+16 -2` (M-DT-4 White-in-dark-chrome row; grid Paints test) |
| OWN-rulerframe-stale | `RulerFrameState` caches `late final _chrome = widget.chrome` and hands that to all three painters | **red** (the RulerFrame rebuild test) |
| OWN-overlay-hover-is-selection | `_hover.color = paper.selection` | **red** |
| OWN-ruler-marker-is-ink | `_marker.color = chrome.rulerInk` | **red** |
| OWN-breaks-from-chrome | `_breaks.color` chosen by `identical(chrome, ChromePalette.dark)` | **survives**, see finding 1 |
| OWN-overlay-sr-one-field | `shouldRepaint => oldDelegate.paper.selection != paper.selection` | **survives**, see note B |
| OWN-plannerview-dark | PlannerView passes `.dark` for both palettes (full planner suite) | **survives** `+1167`, see note C |

## 4. Degenerate fixtures

- **Grid and sheet edge: good.** They are tested with chrome and paper
  crossed (dark chrome on White, light chrome on Blueprint), and on the
  off-origin page under the panned 0.137 px/mm camera.
- **Overlay: good.** It uses the rotated, flipped GripRig camera, the
  off-origin scene and the dark set, so no assertion holds by default.
- **Page breaks: degenerate.** Both the pixel check and the Paint check use
  only dark chrome with Blueprint/dark paper. The theme's choice and the
  paper's choice coincide there. The file header claims this never happens,
  but it does here (finding 1).

## 5. Unedited material and the frame path

- **Unedited material.** `git diff 23314be..2a439e0 --stat` on
  `*analysis_options*`, `packages/jet_cad_2d` (the engine), `*golden*` and
  `*invariants*` is empty. `analysis_options.yaml` shows as modified in the
  worktree only because of `pub get`; it is not committed.
- **Paint-identity tests.** I compared base lines 300-360 with SHA lines
  302-362 of `selection_overlay_test.dart`: `diff` exit 0, byte-identical.
  The shift is **+2**, not +1 as the report says, because the `Rig.overlay()`
  `paper:` line also sits above the block. The only hunks are at :9 (the
  import), :61 (the Rig) and :678 (the direct construction).
- **Every other existing-test change is mechanical.** Each adds a
  `chrome: ChromePalette.light` / `paper: PaperPalette.light` argument or a
  `canvas_palette.dart` import. No expectation changed.
- **Frame path: no new per-frame allocation.**
  - The colour assignments are `Color` field reads into existing Paints.
  - `_labelStyle` is built once, lazily, per painter instance; the "same
    TextStyle every frame" test and the LABEL-perframe mutant prove it.
  - The `TextSpan` per label per frame is **pre-existing**: base `23314be`
    had `_text.text = TextSpan(text: text, style: const TextStyle(...))` in
    `_label`, and the same in the corner. It now passes `style: _labelStyle`.
    That is the same single allocation, and since the style is identical
    across frames, `TextPainter`'s span comparison is no worse.
  - `final ticks = <...>[]` is pre-existing too.
  - A new painter instance (one per ancestor rebuild) builds at most one
    TextStyle, on its first paint.

## 6. Rulings

- **R-C2-1 (`@visibleForTesting TextSpan? get debugLastLabel` on both ruler
  painters): accepted.**
  - Spec M-DT-6 names "the painter's `TextPainter`" as a permitted route.
  - `SpyCanvas` only sees an opaque `Paragraph`.
  - The getter follows the existing `debugLastTicks` / `debugLastSymbol`
    seams.
  - The `as TextSpan?` cast is safe: only `TextSpan`s are ever assigned.
  - A pixel test backs it up independently.
- **R-C2-2 (M-DT-5 camera puts the sheet's left edge at x = 300.5):
  accepted.**
  - I confirmed in `_paintBreaks` that the breaks tile at
    `originX + i*w` / `originY + j*h`. On the sheet, therefore, the only
    breaks are its own edges, and sampling one is the only way to sample a
    break over paper.
  - At x = 300.5 the opaque 1 px break covers column 300 completely, so the
    pixel is the exact break colour. The mutant read `(51,102,204)`, which is
    exactly `0x3366CC`.
  - Side effect: the test also pins "breaks drawn after the edge". That
    matches the code and is harmless.
  - The Paint-colour assertion keeps the test meaningful if AA ever shifts.

## Findings

1. **minor:** `painter_palette_test.dart:224-257`, the M-DT-5 test.
   - **Evidence.** OWN-breaks-from-chrome survives (`+18: All tests passed!`,
     `mut-OWN-breaks-from-chrome.log`). The breaks are only ever checked in
     dark chrome on Blueprint, where the chrome-keyed and paper-keyed
     choices agree. It is the one paper-following element whose fixture is
     degenerate, despite the file header's claim.
   - **Realistic risk: low.** `ChromePalette` has no `pageBreak` field, so a
     plain `chrome.` slip cannot compile.
   - **Fix.** Add one crossed case. Either assert that
     `argbOf(spy.named('drawPath').single)` is `0xFF3366CC` for White paper
     under `ChromePalette.dark`, or that it is `0xFF8AB4F8` for Blueprint
     under `ChromePalette.light` (a loop like M-DT-7's).

## Notes

- **A.** In the report, the Paint-identity block moved by +2 lines, not +1.
  The text is byte-identical either way.
- **B.** OWN-overlay-sr-one-field survives because `.light` and `.dark`
  differ in every field. This is acceptable: the painter delegates to
  `PaperPalette ==`, which Task 1 pins field by field
  (`canvas_palette_test.dart:302/316`). A per-field `shouldRepaint` test
  would be redundant.
- **C. For Task 4.** OWN-plannerview-dark survives the whole planner suite
  (`+1167`): no planner test pins which palettes `PlannerView` hands down,
  and the goldens cover only drafting. Invariant 2 for the planner canvas
  currently rests on the `.light` literal wiring alone. Task 4, which
  replaces that wiring, should include a light-theme / light-paper planner
  assertion (for example, the selection or ruler colour under the light
  theme on White) alongside M-DT-1/M-DT-2, so a palette mis-chosen in the
  shell goes red.
- **D.** The full named-mutant table in the report (31 entries) was not
  re-fired in full. I re-fired 11 of them, covering every family, and
  confirmed their red status. The rest follow the same lines, and the
  equivalent OWN mutants also went red.
