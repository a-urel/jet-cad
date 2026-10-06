# Task 3 report — the tool paint methods (D5 tools, R-1, R-12)

Start: branch head `2a439e0` (Task 2, approved). Status: **done**.

## Commit
- `31b5a43` feat(dark-theme): Task 3 — the tools take the paper set

## What was built (lib)
- `tool.dart`: `paintOverlay(Canvas, ViewportTransform, Size, PaperPalette paper)` (abstract) and `paintWorldOverlay(Canvas, Vector2, double, PaperPalette paper) {}`, each with a doc line saying colours come from `paper`.
- `selection_overlay.dart`: passes its own `paper` to both calls (:168 and :210).
- `draw/placement_tool.dart`: `bandPaint` and `_markerPaint` keep their fields, with no colour in the initialiser. `paintWorldOverlay` sets `bandPaint.color = paper.preview` before `paintRubberBand`. `paintOverlay` sets `_markerPaint.color = paper.snap`. None of the eleven subclasses changed except the two that override `paintOverlay` (DimensionTool, RoomTool). Separator, Wall, Opening, Line, Polyline, Text, Rectangle, Circle and Arc override only `paintRubberBand`, so they are untouched.
- `select_tool.dart`: `_guidePaint`, `_markerPaint` and `_previewPaint` have no colour in their initialisers. In `paintOverlay`'s drag branch, the guide gets `paper.preview` and the marker `paper.snap`. The band colour is `paper.crossingBand` / `paper.windowBand`. `paintWorldOverlay` sets `_previewPaint.color = paper.preview` after its early return.
- `symbol_place_tool.dart`: `_ghostPaint.color = paper.preview` in `paintWorldOverlay`, and `_markerPaint.color = paper.snap` in `paintOverlay`.
- `dimension_tool.dart`: `paintOverlay` calls `super.paintOverlay(..., paper)`, then sets `_ringPaint.color = paper.preview`.
- `room_tool.dart`, `table_select_tool.dart`: new signature, empty bodies.
- `chrome_style.dart` / `selection_style.dart`: all 16 colour constants removed, with sizes, widths and `kBandFillAlpha` kept. Both files lost their `dart:ui` import and gained a header line pointing to `canvas_palette.dart`.
- `canvas_palette_test.dart`: the transitional test `the old chrome and selection constants equal the .light fields` is deleted (R-C1-1).
- A grep for the 16 names over `packages/` and `apps/` (lib and test) is empty. `apps/dev_harness_2d` has no Tool subclass and no paint-method call (grep), so nothing changed there.

## Mechanical test updates (no expectation changed)
- **Tool subclasses get the `PaperPalette paper` parameter:** `IdleTool` (symbol_panel_test), `RecordingTool` (interaction_layer_touch_test), `_CountingTool` (tool_controller_test), `_CursorTool` (interaction_cursor_test).
- **Direct calls get `PaperPalette.light`:** room_tool_test (1), opening_tool_test (1), symbol_place_tool_test (13), dimension_tool_test (4), line_tool_test (1), placement_tool_test (5), select_tool_move_resolver_test (1), object_grips_test (1).
- **Removed constants become `.light` fields:** `PaperPalette.light.*` / `ChromePalette.light.*` in selection_overlay_test (5), selection_overlay_grips_test (10), ruler_painter_test (2), line_tool_test (1), draw_overlay_test (1), symbol_place_tool_test (1), dimension_tool_test (1, in `RingSpy`).
- **Imports:** `canvas_palette.dart` added where needed, and unused `selection_style.dart` imports removed (draw_overlay_test, line_tool_test).
- **painter_palette_test:** one reason string, `'not kRulerInk'` → `'not the light ink'`.
- **selection_overlay_test.dart Paint-identity block:** base `91d88e4` lines 317-345 against current 320-348 gives `diff` exit 0, byte-identical. The block shifted by +3: two lines from Task 2, plus one more because `dart format` wrapped the `PaperPalette.light.selection` line in the "stroke width is 2 px" test just above it. That test (base :314) is outside the protected range.

## Tests added
**C-1** (`packages/jet_cad_2d_flutter/test/painter_palette_test.dart`): `C-1: the page breaks follow the paper, not the chrome: White in the dark chrome, Blueprint in the light`.
- It uses M-DT-5's camera, with the edge at x = 300.5.
- For each case it checks the break `Paint.color` and the pixel at (300, 13). White in `ChromePalette.dark` should give `0xFF3366CC`; Blueprint in `ChromePalette.light` should give `0xFF8AB4F8`.

**M-DT-8, render** (new `packages/jet_cad_2d_flutter/test/tool_palette_test.dart`, 9 tests):
- **Fixture.**
  - The document carries a Blueprint page: 1:20, origin (7000, 3000), `snapToGrid: false`.
  - The paper set is `PaperPalette.forPaper(page.background)`, read from the document.
  - The camera is `gripCamera`: zoomed, rotated, y-flipped, rebase origin non-zero.
  - Every frame goes through `SelectionOverlayPainter`.
  - Each test repeats with `PaperPalette.light` on the same tool instance, as the White control.
  - Every frame also asserts that **no call carries a colour of the other set** (`expectOnlySet`).
- **Tests:**
  - `premise: the Blueprint page takes the dark set, White the light`
  - `M-DT-8: SelectTool the window band (paintOverlay): stroke 0x7FB2FF, fill at the band alpha, on Blueprint; the light set on White`
  - `... the window band in pixels on Blueprint: the stroke is 0x7FB2FF`. This is the **pixel check**. The band corners sit on half pixels (20.5, 20.5)-(200.5, 120.5), so the 1 px stroke covers columns 20 and 200 exactly. It checks the stroke pixel at 0x7FB2FF ±3, the fill pixel at 0x7FB2FF over Blueprint at alpha 0x22 ±3, and the bare paper outside.
  - `... the crossing band (paintOverlay): dashes 0x5FD68F, fill at the band alpha, ...`
  - `... a stretch: the guide (paintOverlay) is 0xFFC857 and the snap marker 0x5FD68F on Blueprint; ...`. The guide is identified by geometry (the line that starts at the grabbed vertex), because the rotation grip's stem is also a line.
  - `... a stretch: the reshape preview (paintWorldOverlay) is 0xFFC857 on Blueprint; ...`. It checks that the preview is drawn under the world matrix, before `restore`.
  - `... its guide, marker and preview Paints are fields: the same objects on the next frame, recoloured`
  - `M-DT-8: the line tool (PlacementTool) the rubber band (paintWorldOverlay) is 0xFFC857 and the snap marker (paintOverlay) 0x5FD68F on Blueprint; ...`
  - `... its band and marker Paints are fields: the same objects on the next frame, recoloured`

**M-DT-8, planner:**
- `packages/jet_cad_floor_plan/test/symbols/symbol_place_tool_test.dart`, group `the paper set (dark theme M-DT-8)`. The rig's page is recoloured to Blueprint, and the paper set is read from the document's page. Tests:
  - `on Blueprint the ghost (paintWorldOverlay) is 0xFFC857 and the marker (paintOverlay) 0x5FD68F; on White the light set`. It checks the outline plus both cross lines, and the endpoint square.
  - `its marker Paint is a field: the same object on the next frame`
- `packages/jet_cad_floor_plan/test/dimension_tool_test.dart`: `M-DT-8: the attach ring is 0xFFC857 on Blueprint, the light set on White`. The fixture is `c2Walls` under `corpusGroups` (far, turned, own groups), with a Blueprint page and `snapToGrid: false`. The hover goes onto the outer corner. The test checks the ring colour per paper and that the ring Paint is the same object on both frames. It adds a `CircleSpy` that reads each colour at call time.

## Mutant table
Method: `scratchpad/task3/mut.py`. For each mutant it copies the file to scratch, applies an exact-string edit, runs `CI=true flutter test <file>`, copies the backup back, and runs `diff -q`. Every run printed `restored diff=0`. Logs are in `scratchpad/task3/<id>.log`, and the summary is in `mut-summary.txt`. **All 20 are red.** Line numbers are pre-commit working-copy lines; the lib in the commit is identical.

| ID | file:line | change | red test(s) | real excerpt |
|---|---|---|---|---|
| C1-breaks-from-chrome | page_chrome_painter.dart:96 | `_breaks.color = identical(chrome, ChromePalette.dark) ? PaperPalette.dark.pageBreak : PaperPalette.light.pageBreak` | C-1 | `Expected: <4281558732> Actual: <4287280376>` (0xFF3366CC vs 0xFF8AB4F8); `+18 -1` |
| C1-breaks-from-chrome-eq | :96 | `chrome == ChromePalette.light ? light.pageBreak : dark.pageBreak` (by value) | C-1 | same; `+18 -1` |
| M-DT-8-sel-window | select_tool.dart:800 | `crossing ? paper.crossingBand : PaperPalette.light.windowBand` | window band (recording); window band pixels | `Expected: <578794239> Actual: <572420072>`; `Expected: within 3 of (127, 178, 255)`; `+7 -2` |
| M-DT-8-sel-crossing | :800 | `crossing ? PaperPalette.light.crossingBand : paper.windowBand` | crossing band | `Expected: <576706191> Actual: <573480539>`; `+8 -1` |
| M-DT-8-sel-guide | :792 | `_guidePaint.color = PaperPalette.light.preview` | stretch guide; reshape (its `expectOnlySet` sees the guide) | `Expected: <4294953047> Actual: <4293435678>` (0xFFFFC857 vs 0xFFE8A11E); `+7 -2` |
| M-DT-8-sel-marker | :793 | `_markerPaint.color = PaperPalette.light.snap` | stretch guide/marker | `Expected: <4284470927> Actual: <4281245275>` (0xFF5FD68F vs 0xFF2E9E5B); `+8 -1` |
| M-DT-8-sel-reshape | :876 | `_previewPaint.color = PaperPalette.light.preview` | reshape; stretch | `Expected: empty Actual: ['drawPath 0xffe8a11e']`; `+7 -2` |
| sel-reshape-initialiser (the "removed constant" form) | :107 | `..color = PaperPalette.light.preview` back in the field initialiser, and the assignment in `paintWorldOverlay` deleted | reshape; stretch | `Actual: ['drawPath 0xffe8a11e']`; `+7 -2` |
| sel-guide-once | :792 | guide colour assigned only while the Paint is still black (first frame only) | stretch (the White control after Blueprint); reshape | `Expected: <4293435678> Actual: <4294953047>`; `+7 -2` |
| sel-guide-perframe | :858 | guide drawn with a fresh `Paint()` per frame | `its guide, marker and preview Paints are fields` | `Expected: true Actual: <false>`; `+8 -1` |
| M-DT-8-line-band | placement_tool.dart:299 | `bandPaint.color = PaperPalette.light.preview` | line tool band/marker | `Expected: <4294953047> Actual: <4293435678>`; `+8 -1` |
| line-band-unset | :299 | assignment deleted (no colour at all) | line tool | `Expected: <4294953047> Actual: <4278190080>`; `+8 -1` |
| pt-marker | :285 | `_markerPaint.color = PaperPalette.light.snap` | line tool | `Expected: <4284470927> Actual: <4281245275>`; `+8 -1` |
| OV-world-light | selection_overlay.dart:168 | `tool.paintWorldOverlay(canvas, origin, scale, PaperPalette.light)` | stretch guide, reshape, line tool | `Actual: ['drawPath 0xffe8a11e']`; `+6 -3` |
| OV-screen-light | :210 | `tool.paintOverlay(canvas, cam, size, PaperPalette.light)` | window band, its pixels, crossing band, stretch, reshape, line tool | `Expected: <578794239> Actual: <572420072>`; `+3 -6` |
| M-DT-8-sym-ghost | symbol_place_tool.dart:490 | `_ghostPaint.color = PaperPalette.light.preview` | symbol ghost/marker | `Expected: [4294953047, 4294953047, 4294953047] Actual: [4293435678, ...]`; `+55 -1` |
| M-DT-8-sym-marker | :459 | `_markerPaint.color = PaperPalette.light.snap` | symbol ghost/marker | `Expected: <4284470927> Actual: <4281245275>`; `+55 -1` |
| sym-marker-perframe | :471 | marker drawn with a fresh `ui.Paint()` | `its marker Paint is a field` | `Expected: true Actual: <false>`; `+55 -1` |
| M-DT-8-dim-ring | dimension_tool.dart:536 | `_ringPaint.color = PaperPalette.light.preview` | dimension M-DT-8 | `Expected: <4294953047> Actual: <4293435678>`; `+16 -1` |
| dim-ring-perframe | :540 | ring drawn with a fresh `Paint()` | dimension M-DT-8 | `Expected: true Actual: <false>`; `+16 -1` |

`dart format` later re-wrapped `tool_palette_test.dart`, so I re-fired OV-world-light, M-DT-8-sel-window and M-DT-8-line-band against the committed file. All three were red again.

## Gates (this container, Flutter 3.47.6, `CI=true`; logs `scratchpad/task3/gate-*.log`)

| Package | flutter test | analyze | format |
|---|---|---|---|
| render `jet_cad_2d_flutter` | `+1300 ~1 -7` (see note 1) | No issues found! | 218 files (0 changed), after one re-format of the new file (note 2) |
| planner `jet_cad_floor_plan` | `+1170: All tests passed!` (1167 + 3 new) | No issues found! | 193 (0 changed) |
| `jet_cad_restaurant_symbols` | `+94: All tests passed!` | No issues found! | 13 (0 changed) |
| app `floor_planner` | `+201: All tests passed!` | No issues found! | 44 (0 changed) |
| demo `restaurant_demo` | `+17: All tests passed!` | No issues found! | 3 (0 changed) |
| `apps/dev_harness_2d` | `+82: All tests passed!` | No issues found! | 22 (0 changed) |

Notes:
1. **Render count.** Task 2 had +1291. This task deletes the transitional test (−1) and adds C-1 (+1) and the 9 tests in tool_palette_test, giving 1300. The 7 failures are exactly the standing set: `text_ladder_golden_test` rungs 1-5 and `text_lod_ladder_golden_test` rungs 1-2, all RenderBackend.canvas.
2. **Render format.** The first gate run reported `Changed test/tool_palette_test.dart`. I formatted that file, reran it (`+9: All tests passed!`), and the final check gives `Formatted 218 files (0 changed)`, exit 0.
3. **Untouched.** The engine was neither edited nor run. `git diff --stat` on `packages/jet_cad_2d`, `*golden*`, `*invariants*` and `*analysis_options*` is empty, and `analysis_options.yaml` is unmodified in this container.

## Proposed rulings
- **R-C3-1: `expectOnlySet`.** Each Blueprint/White frame in tool_palette_test also asserts that no call carries a colour of the other paper set. This is stronger than the spec asks, and it makes several mutants redden two tests at once: the reshape test sees the guide, and the guide test sees the preview. Cost if wrong: none (it only adds failures).
- **R-C3-2: Paint identity for the tools.** I added identity tests for the tools' Paints (guide, marker and reshape preview in SelectTool; band and marker in PlacementTool; marker in SymbolPlaceTool; ring in DimensionTool), each killed by a per-frame-Paint mutant. The ghost Paint already had one (`a second paint reuses the path, the matrix storage and the paint`). Cost if wrong: none.

## Found, not fixed
- **SelectTool band Paints.** `SelectTool.paintOverlay` still allocates two `Paint`s per band frame (the fill and the stroke). This is pre-existing and outside invariant 1's measured path. The brief's "Paints stay fields" covers the existing fields, and making these fields would be a frame-path refactor beyond D5. I changed only the colour source (`paper.windowBand` / `paper.crossingBand`). The `.withAlpha(kBandFillAlpha)` Color is also per frame, also pre-existing.
- **DimensionTool's `ring` closure.** It is a local closure per `paintOverlay` call. This is pre-existing and untouched.

## For the reviewer
- **The window-band pixel test.** It depends on the band corners at half pixels. If AA changes, ±3 may need widening; the recording-canvas assertions back it.
- **The dimension M-DT-8 test** adds a Blueprint page with `snapToGrid: false` to a `buildPlan` doc (`PageComponent.register` first). The premise that the hover lands on the corner is asserted.
- **The symbol M-DT-8 tests** read the paper from `document.components`, not from `rig.pages`. `PageNotifier` had not seen the synchronous `SetComponentCommand` yet (my first run read White), so the document is the source of truth here.
- **The Paint-identity block** in selection_overlay_test.dart is byte-identical at its new offset (+3).

## Task 3b — review 3's findings F-1 and F-2 (on top of `31b5a43`)

**Commit:** `test(dark-theme): Task 3b — the dimension marker and the move guide take the paper set` (SHA in the reply / `git log`). Test-only; no lib change.

- **F-1** (`packages/jet_cad_floor_plan/test/dimension_tool_test.dart`). The M-DT-8 test is renamed `M-DT-8: the attach ring is 0xFFC857 and the snap marker 0x5FD68F on Blueprint, the light set on White`.
  - `CircleSpy` now also records each `drawRect` colour at call time.
  - Each frame expects `spy.rects == [snap]`: `0xFF5FD68F` on Blueprint and `0xFF2E9E5B` on White. That rect is the endpoint square, drawn by `PlacementTool.paintOverlay` through the override's `super` call.
- **F-2** (`packages/jet_cad_2d_flutter/test/tool_palette_test.dart`). New test: `M-DT-8: SelectTool a move: the guide (paintOverlay) is 0xFFC857 on Blueprint; the light set on White`.
  - It presses the selected line's move grip, the midpoint (7070, 3040), and drags by (30, -20). The premise check is `DragKind.move`.
  - It expects `guideOf(spy, mid)` to be `0xFFFFC857` on Blueprint and `0xFFE8A11E` on White, plus `expectOnlySet` on each frame.

### Mutants (same `mut.py`: cp backup, edit, test, cp back, `diff -q` exit 0 each)

| ID | file:line | change | red test | real excerpt |
|---|---|---|---|---|
| F1-dim-super-light | dimension_tool.dart:535 | `super.paintOverlay(canvas, camera, viewport, PaperPalette.light)` | the M-DT-8 ring/marker test | `Expected: [4284470927] Actual: [4281245275]` (0xFF5FD68F vs 0xFF2E9E5B); `+16 -1` |
| F2-sel-guide-in-world | select_tool.dart:792 | guide colour removed from `paintOverlay`, added in `paintWorldOverlay` after the reshape early return | `a move: the guide ...` | `Expected: <4294953047> Actual: <4278190080>` (0xFFFFC857 vs black); `+9 -1` |
| M-DT-8-dim-ring (re-fired) | dimension_tool.dart:536 | ring → `PaperPalette.light.preview` | the M-DT-8 ring/marker test | red |
| M-DT-8-sel-guide (re-fired) | select_tool.dart:792 | guide → `PaperPalette.light.preview` | move guide, stretch guide, reshape | red |

### Gates (logs `scratchpad/task3/gate3b-*.log`)

| Package | flutter test | analyze | format |
|---|---|---|---|
| render `jet_cad_2d_flutter` | `+1301 ~1 -7` (1300 + the move test; the 7 are the standing text_ladder rungs 1-5 and text_lod_ladder rungs 1-2, canvas) | No issues found! | 218 (0 changed) |
| planner `jet_cad_floor_plan` | `+1170: All tests passed!` (F-1 extends an existing test) | No issues found! | 193 (0 changed) |
| `jet_cad_restaurant_symbols`, `apps/floor_planner`, `apps/restaurant_demo`, `apps/dev_harness_2d` | not rerun (test-only change in two other packages) | No issues found! (each) | — |
