# Task 3 review: the tool paint methods (D5 tools, R-1, R-12)

Reviewer: independent. Range: `2a439e0..31b5a43`. Review worktree: detached at `31b5a43`, `/home/user/jet-cad/.worktrees/dark-review`. Flutter 3.47.6, `CI=true`. Scratch files and logs are in `scratchpad/review3/`.

## Verdict: **Needs fixes**

There are 2 minor findings, both test-only. The lib is correct.

## 1. Implementation against the spec and plan

- **Signatures (D5, F-5).**
  - `Tool.paintOverlay(..., PaperPalette paper)` is abstract (`tool.dart:120`).
  - `Tool.paintWorldOverlay(..., PaperPalette paper) {}` is at `tool.dart:144`.
  - All four `paintWorldOverlay` declarations and all seven `paintOverlay` declarations take `paper`: Tool, PlacementTool, SelectTool, SymbolPlaceTool, DimensionTool, RoomTool and TableSelectTool.
  - `SelectionOverlayPainter` passes its own `paper` to both calls (`selection_overlay.dart:168`, `:210`).
  - A grep of `packages/*/lib` and `apps/*/lib` finds no other override and no other caller. No app declares a Tool or calls a paint method.
- **Every chrome colour comes from `paper`, in the method that draws it.**
  - **PlacementTool.** The band gets `paper.preview` in `paintWorldOverlay` (:299), before `paintRubberBand`. The marker gets `paper.snap` in `paintOverlay` (:285), after the `_hoverVisible` early return; that is the only place the marker is drawn.
  - **SelectTool.** The guide gets `preview` and the marker `snap`, in the drag branch only, which is where `_paintGuide` runs (:792-793). The bands get `crossingBand` / `windowBand` (:800). The reshape preview gets `preview` (:876), after the early return; both of its draw sites come after that line.
  - **SymbolPlaceTool.** The ghost gets `preview` in `paintWorldOverlay` (:490). The marker gets `snap` in `paintOverlay` (:459), and both of its draw sites come after that line.
  - **DimensionTool.** It forwards `paper` to super, then sets the ring to `preview` (:535-536).
  - **RoomTool and TableSelectTool.** Empty bodies.
  - **The eleven PlacementTool subclasses.** All are untouched. Every `paintRubberBand` (line, polyline, text, rectangle, circle, arc, separator, wall, opening, room, dimension) draws only with `bandPaint`.
  - **No colour left in a field initialiser.** A grep for `Color` / `.color` / `Paint()` in the tool files finds only palette assignments, plus SelectTool's pre-existing band Paints.
  - **The remaining `Color(0x…)` in render lib** are `vertices_draw_sink.dart:177` (the modulation white), `page_export.dart:121` (the export page, D7) and a `Colors.transparent` in `symbol_gallery.dart`. None is chrome.
- **The 16 constants are gone, along with R-C1-1's transitional test.**
  - A word-boundary grep for all 16 names over `packages/` and `apps/` (lib and test, `dev_harness_2d` included) is empty.
  - `chrome_style.dart` and `selection_style.dart` keep their sizes, widths and `kBandFillAlpha`.
  - The transitional test is deleted from `canvas_palette_test.dart`.
- **Existing tests change mechanically only.** I read the whole diff outside the four files with new tests. Every hunk is one of:
  - the new `PaperPalette paper` parameter on a test Tool subclass;
  - a `PaperPalette.light` argument;
  - a removed constant replaced by its equal `.light` field (all 16 were pinned equal by Task 1's M-DT-19);
  - an import change;
  - a reason string (`painter_palette_test`).

  No expectation changed.
- **The Paint-identity block** in `selection_overlay_test.dart`, `91d88e4`:317-345 against `31b5a43`:320-348, gives `diff` exit 0: it is byte-identical. The +3 shift is the two lines from Task 2 plus one line at :316-317, where `kSelectionColor` became `PaperPalette.light.selection` and `dart format` wrapped the `expect(` that got too long. That change is mechanical plus format, and it sits outside the protected block.
- **Frame path.** At `2a439e0`, `SelectTool.paintOverlay` (:799-803) already did `Paint()..color = color.withAlpha(...)` plus `final stroke = Paint()` per band frame. At `31b5a43` the code is the same; only the source of `color` changed. That allocation is pre-existing and not made worse. Every other colour change is a `Color` field read assigned to an existing `Paint` field. No new allocation.
- **`git diff 2a439e0..31b5a43 --stat`** shows no engine, golden, `invariants/` or `analysis_options.yaml` change, and `91d88e4..31b5a43` shows none either. The only working-tree change is `packages/jet_cad/analysis_options.yaml`, which `pub get` rewrote. It is not committed.

## 2. Gates (re-run by me; logs `scratchpad/review3/gate-*.log`)

| Package | flutter test | analyze | format |
|---|---|---|---|
| `jet_cad_2d_flutter` | `+1300 ~1 -7` (the 7 standing text-ladder / text-lod-ladder canvas goldens only) | No issues found! | 218 files (0 changed) |
| `jet_cad_floor_plan` | `+1170: All tests passed!` | No issues found! | 193 (0 changed) |
| `jet_cad_restaurant_symbols` | `+94: All tests passed!` | No issues found! | 13 (0 changed) |
| `apps/floor_planner` | `+201: All tests passed!` | No issues found! | 44 (0 changed) |
| `apps/restaurant_demo` | `+17: All tests passed!` | No issues found! | 3 (0 changed) |
| `apps/dev_harness_2d` | `+82: All tests passed!` | No issues found! | 22 (0 changed) |

Every count matches the implementer's.

## 3. Mutants (cp backup → edit → `flutter test` → cp back → `diff -q` exit 0, every run)

Scripts: `scratchpad/review3/mut.py` and `mut2.py`. There is one log per mutant.

**Named mutants, re-fired: all red.**

| Mutant | Edit | Result |
|---|---|---|
| sel-window | `select_tool.dart:800` window → `PaperPalette.light.windowBand` | red `+7 -2` (window band; window band pixels), `Expected: <578794239> Actual: <572420072>` |
| sel-crossing | :800 crossing → light | red `+8 -1` |
| sel-guide | :792 → light | red `+7 -2` (stretch; reshape via `expectOnlySet`) |
| sel-reshape | :876 → light | red `+7 -2`, `Actual: ['drawPath 0xffe8a11e']` |
| line-band | `placement_tool.dart:299` → light | red `+8 -1` |
| ov-world-light | `selection_overlay.dart:168` passes `PaperPalette.light` | red `+6 -3` |
| ov-screen-light | :210 passes `PaperPalette.light` | red `+3 -6` |
| sym-ghost | `symbol_place_tool.dart:490` → light | red `+55 -1` |
| dim-ring | `dimension_tool.dart:536` → light | red `+16 -1` |
| C-1 breaks-from-chrome | `page_chrome_painter.dart:96`, `chrome == dark ? dark.pageBreak : light.pageBreak` | red `+18 -1` (C-1), `Expected: <4281558732> Actual: <4287280376>` |

**Invented mutants.**

| Mutant | Edit | Result |
|---|---|---|
| own-pt-band-late | The band coloured in `paintOverlay` (before the hover return), not in `paintWorldOverlay`, so it is one frame late | red `+8 -1`, `Actual: <4278190080>` (black on the first frame) |
| own-sym-ghost-selection | ghost from `paper.selection` | red `+54 -2` |
| own-sym-ghost-late | ghost coloured in `paintOverlay` | red `+54 -2` (also the pre-existing ghost test: black) |
| own-sel-band-swap | window / crossing swapped | red `+6 -3` |
| own-sel-marker-preview | SelectTool marker from `paper.preview` | red `+8 -1` |
| **own-dim-super-light** | `dimension_tool.dart:535`, `super.paintOverlay(..., PaperPalette.light)` | **survives.** `dimension_tool_test` `+17`, and the **whole planner suite `+1170: All tests passed!`**. See F-1. |
| **own-sel-guide-in-world** | The guide's colour moved from `paintOverlay` into `paintWorldOverlay` after its reshape early return. A move or rotate guide is then never coloured. | **survives**: the whole render suite gives `+1300 ~1 -7`, only the standing 7. See F-2. |

## 4. Fixtures

- **tool_palette_test.** Blueprint page (1:20, origin (7000, 3000)). The palette comes from `forPaper(page.background)`. The camera is `gripCamera` (rotated, flipped, panned) for both the grip rig and the draw rig. Every frame goes through `SelectionOverlayPainter`. White is a control on the same instance. The pixel check works on the band; the recording-canvas checks take colours at call time (`SpyCanvas` copies `paint.color`).
- **The symbol and dimension tests** call the tool directly, which is acceptable because the render mutants already prove the overlay forwards `paper`.
  - The symbol test reads the tool's Paint after each call and before the next, which is correct.
  - The dimension test uses the far, turned `corpusGroups` placement on Blueprint.
- **No degenerate fixture** apart from the gaps below.

## 5. Rulings

- **R-C3-1 (`expectOnlySet`): accepted.** The two sets share no ARGB value, so "no colour of the other set" is sound. It only adds failures. Cost if wrong: none.
- **R-C3-2 (tool Paint identity): accepted.** I confirmed the identity tests are killed by per-frame-Paint mutants: sel-guide-perframe, sym-marker-perframe and dim-ring-perframe were red in the implementer's table. My own late-colour mutants show the tests also catch a stale colour. Cost if wrong: none.

## Findings

**F-1 (minor): DimensionTool's snap marker on Blueprint is unpinned, so `super.paintOverlay` can drop `paper`.**
- **Where:** `packages/jet_cad_floor_plan/lib/src/parametric/dimension_tool.dart:535` and `packages/jet_cad_floor_plan/test/dimension_tool_test.dart` (the M-DT-8 test, about :1603-1636).
- **Evidence:**
  - Forwarding `PaperPalette.light` to super survives the whole planner suite (`+1170`).
  - The M-DT-8 test's `CircleSpy` records only `drawCircle`, so the marker square it draws in that very frame goes unseen.
  - A scratch probe (reverted, `diff` 0) shows the frame draws `[drawRect 0xff5fd68f, drawCircle 0xffffc857]` on Blueprint. Under the mutant it draws `drawRect 0xff2e9e5b`.
- **Why it matters:** M-DT-8 is "a tool ignores `paper` in either paint method". DimensionTool's override of `paintOverlay` is the one place where a dropped forward lands, and its marker is the only part not pinned.
- **Fix:** in that test, record the `drawRect` (marker) colour too and expect `0xFF5FD68F` on Blueprint and `0xFF2E9E5B` on White. My probe assertion of exactly that turned the mutant red: `Expected: every element(contains '5fd68f') Actual: ['Symbol("drawRect") 0xff2e9e5b']`.

**F-2 (minor): SelectTool's guide colour is pinned only for a reshape drag.**
- **Where:** `packages/jet_cad_2d_flutter/test/tool_palette_test.dart:259-284` and `:312-334`, guarding `select_tool.dart:792`.
- **Evidence:**
  - Every guide test drags a stretch grip. In that case `paintWorldOverlay` and `paintOverlay` both run in the same frame, so the guide colour can sit in either one.
  - Moving the guide colour into `paintWorldOverlay` (after its reshape early return) survives the whole render suite. Under that mutant the guide of a move or rotate drag is drawn black (`0xFF000000`) on every paper, which also breaks invariant 2 for the light theme.
  - A scratch probe (reverted, `diff` 0) catches it: press the selected line's midpoint (7070, 3040), which is the move grip, drag to a `DragKind.move`, then check `guideOf(spy, mid)` for `0xFFFFC857` on dark and `0xFFE8A11E` on light. It passes on `31b5a43`, and under the mutant fails with `Expected: <4294953047> Actual: <4278190080>`.
- **Fix:** add that move-drag guide assertion to the SelectTool group, on Blueprint with the White control.

**Note 1 (no action this task):** SelectTool's per-band-frame `Paint()` × 2 and `withAlpha` are pre-existing at `2a439e0` and unchanged. The implementer reported them correctly. They are outside invariant 1's measured path. They could be made fields in a later frame-path cleanup.

**Note 2:** the window-band pixel test depends on the half-pixel band corners. It is backed by the recording-canvas assertion, as the implementer says.
