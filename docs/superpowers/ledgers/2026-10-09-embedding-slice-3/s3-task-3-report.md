# Slice 3, Task 3: the selection mode's painters and bar (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `e111b28`.
- **Commits:**
  - `fcace6b`: Task 2's review fixes R-1 and R-2. Tests only. The "## Fixes" section of `s3-task-2-report.md` describes it.
  - `74024d7`: Task 3.
  - Both are pushed as `e111b28..74024d7`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, with `CI=true`.
- **Working files:** every scratch file and mutant runner is in `scratchpad/s3t3-impl/`. The runner is `mut.py`, the definitions are `defs_t2fix.py` and `defs_t3.py`, and the logs are `t2fix.log` and `final.log`.
- **`analysis_options.yaml`:** none was touched or committed. Before each commit, `git status` showed only the task's files.
- **Scope.** Only the planner was edited:
  - five library files and two new test files;
  - no existing test was edited;
  - no golden was touched;
  - nothing in `jet_cad_2d_flutter`, the engine or the gpu package (no render edit).

## Files (Task 3)

| File | What |
|---|---|
| `lib/src/service/table_focus_painter.dart` | New `focusVeilColour(paper, theme)`. With a `focusVeilColor`, the result is that colour with its alpha × the opacity (S-9). Otherwise it is the paper's RGB at the opacity, which replaces the paper's own alpha. The opacity is `focusVeilOpacity ?? 0.6`. With no theme the result is exactly today's veil. The painter gains an optional `ValueListenable<FloorPlanTheme?>? theme`, which joins the **recolour** key only (`!identical`). A new `@visibleForTesting debugRecolours` counter is added (finding 1). `shouldRepaint` also compares the theme. |
| `lib/src/service/table_status_painter.dart` | New `paintedTextStyle(style, ink)`: the style's `copyWith` with colour `style.color ?? ink` and `fontSize ?? 11`. The family and weight stay as given. Optional `theme`, which joins the rebuild key. At rebuild the drawn colour is the status colour with alpha × `statusFillOpacity`, applied **once**. The paint cache is keyed by the drawn ARGB. The caption ink is `style.color ?? statusCaptionInk(drawn, paper)` (S-6). The caption cache is keyed by (caption, drawn ARGB, ink, style) (T3-a). With no style, the paragraph uses today's constructors. With a style it uses `getParagraphStyle(textAlign: center)` and `getTextStyle()`. The "below" rule reads `_captionSize`, which is set at rebuild. |
| `lib/src/service/table_group_painter.dart` | Optional `theme`, which joins the rebuild key. All of the following are set at rebuild: frame colour `groupFrameColor ?? gripMove`; chip colour `groupChipColor ??` the resolved frame colour (S-7); margin (path, bounds' width, anchor); `_frameWidth` (divided by the scale per frame, as the constant was); radius; asymmetric padding (rect `(-left, -top, w + right, h + bottom)`, anchor `sy - (h + _chipBottom)`); faded frame = frame colour at alpha × (1 − veil opacity); veiled chip = `focusVeilColour` (S-9). The chip ink is `style.color ??` the automatic ink on the chip colour. The chip cache is keyed by (text, ink, style). With no theme, the paragraph and every value are today's. |
| `lib/src/host/service_view.dart` | Passes `_theme` to the four painters and adds it to the three repaint merges. New `kServiceBarHeight = 44`. The bar is `_barHeightNow()`: `theme?.serviceBarHeight ?? 44`. When a build lays out a height different from the last build's, one post-frame callback calls the new optional `onCanvasMoved` (S-10). |
| `lib/src/host/floor_plan_view.dart` | Passes `onCanvasMoved: _serviceCanvasMoved`. In the selection mode, that method calls `controller.canvasMeasured(selection, _canvasOrigin())` again. |
| `test/service/table_theme_painter_test.dart` (new, 19 tests) | Painter level; see Tests. |
| `test/host/theme_service_test.dart` (new, 9 tests) | Through `FloorPlanView`; see Tests. |

**P-6 (structural).** With a null theme:
- `look` is null, so every `??` takes today's constant;
- the paragraphs are built by today's two-line constructors;
- `focusVeilColour(paper, null)` is `Color(paper).withValues(alpha: 0.6)`, which a test pins exactly;
- the bar is 44, and no `onCanvasMoved` call happens because the height never changes.

## Tests

### `test/service/table_theme_painter_test.dart`

The fixtures are the painter tests' own:
- `rowOfTables` (turned 37°, mirrored, 40 m off the origin);
- `groupedPlan` ({12, 3, 7} out of handle order, one mirrored);
- the zone fixture for the veil;
- cameras off identity.

The expected colours are composited by the test.

**Invariant 7 with a theme (M-H31)**
- **SP1 themed.** 60 tables under `fullTheme`, after warm-up and ten frames that pan and zoom. The same objects reach the canvas, and `debugAllocations` and `debugRebuilds` are unchanged. A premise checks that the opacity of 0.5 is in force.
- **TG-L9 themed.** Frames, chips and status under `fullTheme`, with a focus on 20 so that G7 is faded and its chip veiled, over ten frames. The camera is 0.1 px/mm, not 0.06 (finding 4).
- **FP3 themed.** 60 tables, half focused, under a host veil. The same matrix, path and paint reach the canvas. Allocations, rebuilds and **recolours** are unchanged.

**Status**
- **M-H33(opacity twice).** Bill at 0.5 has paint alpha `0x4D` and RGB `0xE53935`. Three pixels over White match the test's composite at 0.3 within 1. An equal theme followed by a second status leaves both paints at `0x4D`, and so does 0.25 followed by 0.5.
- **M-H33(null caption colour).** `TextStyle(fontSize: 14)` with no colour. On `0xFF1B1B1B` the brightest pixel of the caption box is `0xFFFFFF`. On `0xFFFFE082` the darkest is `0x202020`. A premise checks that every pixel of the box is the fill when there is no caption.
- **T3-c.** `0xFF303030` at 0.2 gives dark glyphs, and at 1.0 white glyphs. A premise checks that `foregroundFor` disagrees between the dimmed and the undimmed colour.
- **Caption colour, size and weight.** A teal caption colour beats the automatic ink: it is the darkest glyph pixel. A 14 px bold caption has the height and intrinsic width of the test's own 14 px bold paragraph and more glyph rows than 11 px. Its summed ink exceeds that of 14 px regular, because the engine's fake bold inks more.
- **The "below" rule.** At 0.05 px/mm, where both sizes clamp, the themed caption sits 14 − 11 px lower.
- **T-4 / S-2.** Roboto's bytes are registered by a `FontLoader` under `ThemeTestFace`. A caption with that `fontFamily` measures as that face, and with none it measures as the default. The chip honours its own style's family too.
- **T3-a.** Changing the caption style from 11 to 16 px, and nothing else, gives a taller paragraph. The chip's paragraph does the same.

**Groups**
- **Frame width.** 3 px, so the stroke is `3/scale` at 0.125 and at 0.04, in `0xFF00897B`. With no theme it is 2 px in `0xFF7A3FD1`.
- **Margin 300 mm (TG-L4's geometry).** Every corner pushed out by 0.95 × 300 in eight directions is inside the frame. Each of the 4 extremes pushed out by 1.1 × 300 is outside.
- **The skip width follows the margin.** At a zoom where the 150 mm frame is narrower than the chip and the 300 mm one wider, the chip is drawn only under the theme.
- **T3-e.** The rect is `(-7, -3, w + 9, h + 4)` with radius 8. Its bottom lies on the frame's top line (margin 300) at 0.125 and 0.04 px/mm, with the label centred on x. The fill is `0xFF3949AB`.
- **T3-b / S-7.** With `groupFrameColor` alone, the chip is that colour. A `groupChipColor` wins over it.
- **Chip text.**
  - 13 px is the test's 13 px paragraph.
  - White glyphs on `0x3949AB`, and dark glyphs on a light chip colour.
  - A style colour is honoured.
- **Z14 under a themed veil.**
  - The faded frame is `0x00897B` at alpha 0.65, while GB straddles the focus at full alpha.
  - The chip's veil is `0x6D4C41` at 0.35, and the padding pixel matches the test's composite.
  - With no veil colour, on a paper of alpha `0x80`, the veil is the paper's RGB at 0.35 (its alpha replaced), and the faded frame is the dark set's `gripMove` at 0.65. The pixel is read back.

**Veil**
- The host colour `0x806D4C41` at 0.5 gives alpha `0x80/255 × 0.5`. More than 2000 pixels inside 7 match the composite.
- Then each of these is read back over those pixels: 0.35 with no colour gives the paper's RGB; a paper of alpha `0x40` has its alpha replaced; no theme gives 0.6.
- The same paint and path are drawn, rebuilds are unchanged, and recolours are +3.
- `focusVeilColour` with no theme or an empty theme is exactly today's colour for three papers.

### `test/host/theme_service_test.dart`

The fixtures:
- the groups look fixture (`lookController(white)`, `lookCamera()`), with Bill on 3, an opaque green on 20, G7 = {12, 3, 7}, and the focus on {12, 3, 7};
- the zone fixture for the veil;
- the embedding fixture for the overlays.

The host theme is a notifier that rebuilds the host on every assignment, an equal one included.

- **M-H33(repaint).** The camera, the document, the statuses, the groups and the focus stay still. A change of `statusFillOpacity` alone, then `groupFrameColor`, then `groupChipColor`, then `focusVeilOpacity` is each followed by **one pump**. After each one, that layer's pixel shows the new value:
  - the status: inside 3;
  - the frame: its left-most point;
  - the chip: its padding;
  - the veil: inside 20, over 20's status, against a reference taken without the focus.
- **M-H31 through the view.**
  - After ten pans, each of the four layers' rebuilds, allocations and veil recolours are unchanged.
  - A host rebuild with an equal, non-identical theme leaves them unchanged.
  - A different theme rebuilds the status, frames and chips once each, and recolours the veil once.
- **M-H32, in two tests.** Each pumps `FloorPlanTheme(focusVeilOpacity: 0.35)`, focuses on 3, and checks more than 2000 pixels inside 7 against Blueprint at 0.35 over the unveiled shot. The fixture of each:
  - the zone fixture on a Blueprint page under the light theme;
  - the page-less zone fixture with `canvasBackground: 0xFF263238` under the light theme.
- **The bar at 60.**
  - The bar is 60 px, and the canvas is at `(0, 60)` in the view.
  - The controller measured it there: `setMode(design)`, before any frame, reframes by the design seed − `(0, 60)`.
- **T3-d.**
  - Control at 44: design and back keeps 3's global position.
  - Then the host sets 60, and the plan moves 16 px with the canvas.
  - Design and then selection keep the new position to 1e-9.
- **Invariant 4, in the selection mode.** Statuses, a group status, groups and the focus are shown, and one service move is made.
  - `designJson()`, `serviceLayoutJson()` (non-null, by premise) and the 96 dpi PNG export are each identical with no theme and with `fullTheme`.
  - The bar is 60, by premise.
- **TO10 themed and TO21 themed.** The embedding fixture under the ambient `fullTheme` (bar 60, premise), with a status, a group and a focus, and the overlays shown, over 50 pans and zooms.
  - Both: `RenderFloorPlanOverlays` allocates nothing, hands out at most one paint offset per painted overlay, and the four painters' counters are unchanged.
  - TO10 (natural): no relayout.
  - TO21 (box): one layout per shown overlay per frame.

## Mutants

Every mutant was applied by `mut.py`. Each file is copied aside, mutated with exactly one match asserted, and restored from the copy, with a `cmp` check. `md5sum -c` over the eight touched library files was OK after every run.

The results below come from the final full run (`final.log`) on the committed tests. The suite there is the two new files plus `table_status_painter_test`, `table_group_painter_test` and `table_focus_painter_test`, 63 tests in all. The baseline is 63/63 green.

### Task 2's fixes (before the first commit)

| Mutant | Killer |
|---|---|
| O10 | "R-1 (design)…", "R-1 (selection)…" |
| O17 | "the width is asserted finite and above 0; 0.25 is accepted (R-2)" |

### Named mutants: all red

| Mutant | Killers (test names) |
|---|---|
| M-H31, status key compares a per-frame `copyWith()` | SP1 themed; TG-L9 themed; M-H31 through the view; TO10 themed; TO21 themed |
| M-H31, group key, the same | TG-L9 themed; M-H31 through the view; TO10 themed; TO21 themed |
| M-H31, veil key, the same | FP3 themed; M-H31 through the view; TO10 themed; TO21 themed |
| M-H31, chip `RRect` built from the theme per frame | TG-L9 themed (plus the existing TG-L9 and TG-Z2) |
| M-H31, caption paragraph built from the theme per frame | SP1 themed; TG-L9 themed; M-H31 through the view; TO10 and TO21 themed; and 3 status tests |
| M-H32, a null veil colour reads a fixed White | both M-H32 view tests; the painter veil tests; Z14 themed; and the existing FP1, FP2, FP5 to FP7 and TG-Z1 |
| M-H33(repaint), merge form: status merge without the theme | M-H33(repaint); M-H31 through the view |
| … the group merge | the same two |
| … frames only | the same two |
| … chips only | the same two |
| … the veil merge | the same two |
| M-H33(repaint), key form: status | M-H33(repaint); M-H31 through the view; T3-a |
| … frames only | M-H33(repaint); M-H31 through the view; "the frame strokes 3 screen px…" |
| … chips only | M-H33(repaint); M-H31 through the view; T3-a; T3-b; the chip text test; the skip width test |
| … the veil recolour key | M-H33(repaint); M-H31 through the view; "a host veil colour's alpha is multiplied…" |
| M-H33(opacity twice), at rebuild | M-H33(opacity twice); T3-c; SP1 themed; M-H33(repaint) |
| M-H33(opacity twice), again when drawing (compounding through the cached paint) | the same four |
| M-H33(null caption colour), at the ink | M-H33(null caption colour) |
| M-H33(null caption colour), in `paintedTextStyle` | M-H33(null caption colour); the chip text test |

### Task-local mutants: all red

| Mutant | Killer |
|---|---|
| T3-a, caption cache without the style | T3-a |
| T3-a, chip cache without the style | T3-a |
| T3-b, chip default `gripMove` | T3-b |
| T3-c, ink from the undimmed colour | T3-c |
| T3-d in the view: `onCanvasMoved` not passed | T3-d |
| T3-d in `ServiceView`: the callback never called | T3-d |
| T3-e, right padding read as left | T3-e |
| T3-e, bottom padding read as top | T3-e |

### My own mutants: 17, of which 16 are red

| Mutant | Killer |
|---|---|
| X1, frame width const | "the frame strokes 3 screen px…" |
| X2, margin const in the path | "the margin 300 mm…" |
| X3, margin const in the anchor | T3-e |
| X3b, margin const in the skip width | "the margin widens the frame a chip is measured against…" |
| X4, radius const | T3-e |
| X5, faded frame at a const opacity | Z14 themed |
| X6, chip veil ignores the theme | Z14 themed |
| X7, veil alpha replaced, not multiplied | the painter veil test |
| X8, "below" const | the "below" test |
| X9, family dropped | T-4, S-2 |
| X10, bar const | 5 tests: the bar at 60; T3-d; invariant 4; TO10 and TO21 themed |
| X11, `_theme.value =` dropped in `ServiceView` (Task 1's finding 2, for what this task paints) | 9 tests, including M-H33(repaint), both M-H32 tests and the bar |
| X13, paint cache keyed by the status ARGB | M-H33(repaint) |
| X14, caption size ignored | 3 tests: the caption colour/size/weight test, T3-a and the chip text test |
| X15, frame colour ignored | 5 tests |
| X16, veil opacity ignored | 5 tests |
| X18, weight forced to w400 | the caption colour/size/weight test |
| **X12, the chip ink ignores the style's colour** | **survived: equivalent**. `paintedTextStyle` applies `style.color` anyway, so only the cache key changes (finding 2). |

**Totals:** 18 named mutants (as forms), 8 task-local and 17 of my own. One survived, and it is equivalent.

**How the earlier runs changed the tests:**
- **First run.** M-H31 on the veil key and M-H33(repaint) on the veil's merge survived. Finding 1 explains the first; findings 1 and 3 give both fixes. Both are red in the final run.
- **Second run.** X3b survived, so the skip-width test was added. X18 survived because the bold check counted pixels against the wrong fill, so it was fixed to sum the ink. All of these are in the final run above.

## Gates (real results, on the committed tree)

| Gate | Result |
|---|---|
| `packages/jet_cad_floor_plan` | `flutter test --enable-vmservice --file-reporter json:…` gives "+1679: All tests passed!", exit 0. Comparison: "packages/jet_cad_floor_plan: 1679 tests; the standing failures and skips, exactly", exit 0. `flutter analyze`: "No issues found!". Format: "Formatted 264 files (0 changed)", exit 0. 1679 = 1649 + 2 (R-1) + 19 + 9. |
| `apps/restaurant_demo` | "+57: All tests passed!". Analyze: no issues. Format: 0 changed. |
| `apps/floor_planner` | "+212: All tests passed!". Analyze: no issues. Format: 0 changed. |
| `packages/jet_cad_2d_flutter` | `flutter test` exits 1 on the standing failures. Comparison: "1390 tests; the standing failures and skips, exactly", exit 0. 1390 = 1389 + R-2. |
| `packages/jet_cad_2d_gpu` | Exit 0. Comparison: "20 tests; … exactly", exit 0. |
| `packages/jet_cad_2d` | `dart test` exits 1 on the 2 standing failures. Comparison: "1258 tests; … exactly", exit 0. |

The unedited P-6 / invariant 7 files the plan names are green inside the 1679:
- `table_status_painter_test`, `table_group_painter_test`, `table_focus_painter_test`;
- `status_caption_test`, `table_groups_look_test`, `table_groups_toolbar_test`;
- `view_test`, `view_events_test`, `table_overlay_test`, `pick_allocation_test`;
- and Tasks 1 and 2's theme tests.

They were also run together before the tests were written: 276 passed.

## Findings

1. **The veil painter gains a `debugRecolours` counter.**
   - A per-frame recolour (a key that compares a per-frame copy of the theme) allocates one `Color` per frame. Nothing counted can see it: the `Paint`, the path and the matrix are the same objects, and `debugAllocations` counts none of them. So M-H31's veil form survived the first run.
   - The counter is incremented where the colour is derived. FP3 themed and the view's M-H31 test pin it.
   - It is test-only (`@visibleForTesting`) in an internal class. FP3 itself is untouched.
2. **X12 is equivalent.** `paintedTextStyle` applies the style's colour, so `style?.color ??` in the ink matters only for the caches' key. It keeps a paper flip from building a second identical paragraph when the host fixed the colour. I kept it for that.
3. **The veil is the paper's colour, so it is invisible over the plain paper.**
   - My first M-H33(repaint) fixture read the veil over White paper inside table 20. A white veil over white reads the same at any opacity, so the veil-merge mutant survived. That was a degenerate fixture.
   - The fix: table 20 carries an opaque status, and the reference "under" is shot at the status step's opacity.
4. **TG-L9's themed sibling runs at 0.1 px/mm, not 0.06.**
   - At 0.06 the 14 px bold "Bill" is wider than its table, so it is skipped.
   - The sibling would then pass one status paragraph where TG-L9 passes two.
5. **T-4 in the test font.** `flutter_test`'s default face draws every glyph 1 em wide, so the loaded Roboto measures **narrower**, not wider as the plan's wording has it. The test therefore asserts that the caption "measures as the loaded family, not as the default", with a premise that the two faces differ.
6. **Asymmetric padding.** The label stays centred on the anchor's x, as today. The rect is `(-left, …, w + right, …)`, so its centre is `(right − left)/2` off the anchor. The plan specifies the rect and the y anchor only. T3-e asserts both of those and the label's centring.
7. **The chip's automatic ink is taken on the chip colour's RGB**, as on `gripMove` today (S-6's wording). A translucent `groupChipColor` is not composited over the paper, unlike a status caption. This is an observation only.
8. **S-10's trigger is the built height**, not a read-back of the laid-out bar. The two are the same, since the `Container` in a `Column` takes its height. Several changes within one frame give one callback.
9. **New internal top-level names:**
   - `kServiceBarHeight` (`service_view.dart`);
   - `focusVeilColour` (`table_focus_painter.dart`);
   - `paintedTextStyle` (`table_status_painter.dart`).

   None is in a barrel.

## Fixes

The review (`s3-task-3-review.md`) R-1 to R-4, all accepted by the controller. One commit on top of `61ca42e`. Scratch: `scratchpad/s3t3-fix/` (`defs.py`, `mut.py`, `mut.log`, `gates.sh`, `gates.out`, the run JSONs and logs).

**Library (planner only).**

| Finding | Change |
|---|---|
| R-1 | `table_group_painter.dart`: `_chipShiftX = (padRight - padLeft) / 2`, set at rebuild; the chip translates by `sx - p.width / 2 - _chipShiftX`. The **box** is centred on the frame bounds' centre x (table-groups fixes F-4); an uneven padding moves the label inside it. Symmetric padding (today's 5/5) gives a shift of `0.0`, and `x - 0.0 == x`, so today's chips draw byte-identical (P-6). No per-frame derivation: one field load. |
| R-2 | `table_group_painter.dart`: the automatic chip ink is `chipStyle?.color ?? statusCaptionInk(chipColour, paperArgb)`, the chip colour composited over the paper, as for a status caption (S-6). `over()` of an opaque colour is its own RGB, and `gripMove` is opaque in both palettes, so today's ink is unchanged (P-6). The chip cache key is unchanged (text, ink, style); the paper is already in the rebuild key. |
| R-4 nit | `floor_plan_controller.dart`: the selection seed is `Offset(0, kServiceBarHeight)` (imported with `show` from `service_view.dart`). |

**Tests.** Only Task 3's own two files were touched; no other test was edited.

- `table_theme_painter_test.dart`:
  - **T3-e strengthened (R-1):** asserts `t.dx + (r.left + r.right) / 2 == sx` at 0.125 and 0.04 px/mm, with a premise that the label's centre sits `-(9 - 7)/2` from it (so the fixture tells the two apart).
  - **New, R-2:** `0x40FFFFFF` on Blueprint. Premises: `foregroundFor(0xFFFFFF)` is black, the drawn chip `composite(0x40FFFFFF, Blueprint)` takes white, and the left-padding pixel is that composite within 1. The brightest glyph pixel is `0xFFFFFF` as `groupChipColor`, and again as a `groupFrameColor` the chip falls back to (S-7). With no theme, the ink is `foregroundFor(gripMove)` on Blueprint as today (premise: `gripMove` opaque).
  - **K12:** `0xFFFFE082` at `statusFillOpacity: 0.3` on Blueprint: white caption ink; premises that the drawn colour is dark over Blueprint and light over White.
  - **K14:** for no theme and a 14 px style, the glyphs' midpoint (`getBoxesForRange(0, 4)`) is the paragraph's middle within 0.5; premise that the paragraph is wider than its text by more than 2.
  - **K16:** `statusCaptionStyle: 16 px` alone leaves the chip paragraph's height and width at today's; premise that a 16 px chip style is taller.
  - **K17:** `groupChipTextStyle: 16 px` alone leaves the caption's height and intrinsic width at today's; premise likewise.
  - **K13:** `focusVeilColour(white, FloorPlanTheme(focusVeilColor: c))` with no opacity has alpha `c.a × 0.6` and `c`'s RGB, for an opaque and a `0x80` colour.
- `theme_service_test.dart`:
  - **RV5:** 44 → 60 → 72 within one selection view (premise: the plan moved `(0, 28)` with the canvas), then design: table 3 keeps its global position to 1e-9.
  - RV1 and RV3 (optional in the review) were not landed.

**Guide.** `docs/host-guide.md` § 9, "Captions and chip text": the chip's automatic ink is taken on the chip's colour as drawn over the paper; a chip's box is centred on its frame, an uneven `groupChipPadding` moving the label inside it. Prose only, no code block moved: `check_guide` gives "all 37 code blocks are in the host probe"; `tool/ci` `dart test` "+63: All tests passed!".

**Mutants** (`mut.py`, adapted from the reviewer's: each file copied aside, the edit applied with exactly one match asserted, restored from the copy and checked with `cmp`; `md5sum -c` over the touched library files OK afterwards). Suite: the two Task 3 files plus `table_status_painter_test`, `table_group_painter_test`, `table_focus_painter_test`, 70 tests, all green on the baseline.

| Mutant | Result | Killer |
|---|---|---|
| R09 `_canvasMoveDue` never reset | red (1) | RV5 |
| R12 themed ink composited on White | red (1) | K12 |
| R13 host veil colour with no opacity at 1 | red (1) | K13 |
| R14 themed caption not centred | red (1) | K14 |
| R16 chip style falls back to the caption style | red (1) | K16 |
| R17 caption style falls back to the chip style | red (1) | K17 |
| F1a R-1 undone (label centred) | red (1) | T3-e |
| F1b R-1's shift sign flipped | red (1) | T3-e |
| F2a R-2 undone (ink on the chip's RGB) | red (1) | the R-2 test |
| F2b chip ink composited over White | red (1) | the R-2 test |

**Gates** (on the fixed tree; a comment-only reflow in `floor_plan_controller.dart` landed during the planner run, before its analyze and format):

| Gate | Result |
|---|---|
| `packages/jet_cad_floor_plan` | `flutter test --enable-vmservice --file-reporter json:…`: "+1686: All tests passed!", exit 0 (1686 = 1679 + 7). Comparison: "packages/jet_cad_floor_plan: 1686 tests; the standing failures and skips, exactly", exit 0. Analyze: "No issues found!". Format: "Formatted 264 files (0 changed)". |
| `apps/restaurant_demo` | "+60: All tests passed!"; analyze no issues; format 8 files, 0 changed. |
| `apps/floor_planner` | "+212: All tests passed!"; analyze no issues; format 47 files, 0 changed. |
| `packages/jet_cad_2d_flutter` | exit 1 (standing); comparison "1390 tests; the standing failures and skips, exactly", exit 0. |
| `packages/jet_cad_2d_gpu` | "+20: All tests passed!"; comparison "20 tests; … exactly", exit 0. |
| `packages/jet_cad_2d` | exit 1 (standing); comparison "1258 tests; … exactly", exit 0. |
| `tool/ci` | `dart test` "+63: All tests passed!"; `check_guide` "all 37 code blocks are in the host probe". |
