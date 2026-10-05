# Dark canvas — results

**Decision note:** [2026-10-05-dark-canvas-design.md](../specs/2026-10-05-dark-canvas-design.md),
approved ("Onaylıyorum, başla", 2026-10-05), with "Amended at execution".
**Process:** the fast one the human chose. There was one implementation
(`118d707`), one independent review, and review fixes (`4543dd6`). The
screenshots were shown to the human before any merge.
**Branch:** `claude/dreamy-gates-2kgh4o`, on top of the unmerged table groups
fixes (`402a775`). The note is at `deaadca`.

## What landed

- **`jet_cad_2d_flutter/lib/src/dark_canvas.dart`**, new and exported:
  - `darkCanvasFor`, the K1 condition;
  - `displayPaperFor`, the paper the canvas shows;
  - `canvasResolverFor`;
  - `darkCanvasTone`, the K3 rule: the WCAG contrast mirror at the OKLab
    hue, gamut-mapped by chroma, with a neutral-to-coloured blend from 0.09
    to 0.15 chroma, and white shown as the paper;
  - `DarkCanvasStyleResolver`, with a style cache over an RGB cache.
- **`kDarkCanvasPaper = 0xFF1E1F22`**, in `canvas_palette.dart`.
- **`PageChromePainter.sheetArgb`.** A null value fills the sheet with the
  page's background, as before. `shouldRepaint` compares it.
  `PlannerView.sheetArgb` passes it through.
- **`PlannerShell` and `ServiceView`:**
  - `_paperArgb()` returns the display paper;
  - the resolver key is `(_foreground, _darkCanvas)` and the resolver is
    replaced only when the key changes;
  - `_brightness` is read in `didChangeDependencies`;
  - `LayerPanel` takes `_foreground`, the canvas ink.
- **Unchanged:** export (`page_export.dart`), the engine, the document and
  the schema.

## Superseded tests (K1)

Ten existing tests asserted dark theme spec D4's "the paper decides, not
the theme" on a White page. Each was moved to K1, and nothing else in it
changed:

- `planner_palette_test` M-DT-1/2 (the dark/White crossing) and M-DT-9;
- `widget_theme_test` M-DT-18 (the swatch shows the canvas ink);
- `canvas_ui_test` M-DT-12 (the premise pixel is `kDarkCanvasPaper`);
- `table_groups_look_test` M-TG-21 (a White/light crossing was added);
- `view_palette_test` M-DT-11 (now under the light theme, where White and
  Blueprint still separate), the ServiceView crossings and the theme
  switch;
- `status_caption_test` D6c (now light theme, then dark theme, then
  Blueprint in the light theme).

The light theme on Blueprint still separates the paper from the theme
everywhere it did before.

## Gates

Flutter 3.47.6, Linux.

| Package | At `118d707` | At `4543dd6` |
|---|---|---|
| render | +1328 ~1 −7 | +1333 ~1 −7 |
| planner | +1291 (+8 on +1283) | +1293 |
| restaurant symbols | +94 | — |
| app | +201 | — |
| demo | +28 | — |
| dev harness | +82 | — |
| engine | +1241 −2 | — |

- **Standing failures.** Render's −7 are the standing text-ladder goldens;
  the engine's −2 are the standing `generate_document_test` pair. Neither
  package's failing code changed.
- **At `4543dd6`** only the render and planner packages changed, and their
  analyze and format are clean.
- **Web builds.** `flutter build web --release` ✓ for both apps, plus the
  `--no-web-resources-cdn` builds that the smoke used.

## Named mutants

Each was a scratch edit, reverted, run by `scratchpad/dc/mutate.py`.
"Planner" is `packages/jet_cad_floor_plan`; the file is
`test/dark_canvas_test.dart` unless named.

| Mutant | Scratch edit | Killed by |
|---|---|---|
| M-DC-1 | sheet fill `Color(p.background)` | render `page_chrome_painter_test`; planner |
| M-DC-2 | `darkCanvasFor` drops the light-paper check | render; planner |
| M-DC-3 | shell `_paperArgb()` → `page.background` | planner + `planner_palette_test` |
| M-DC-3b | the same in `ServiceView` | planner + `host/view_palette_test` |
| M-DC-4 | `canvasResolverFor` never wraps | planner |
| M-DC-5 | neutral → `max(L, target)` | render |
| M-DC-6 | coloured → target | render |
| M-DC-7 | target 4.5 | render |
| M-DC-8 | style cache skipped | render |
| M-DC-9 | export wraps in the dark resolver | the existing render `export/export_pdf_test` (6 red) |
| M-DC-10 | `darkCanvasFor` ignores brightness | render; planner + `planner_palette_test` |
| R-1 | `_retone` scale 1.0 | render |
| R-1b | `contextFor` returns `inherited` | render |
| R-2 | gamut by clipping | render (the hue test) |
| R-3a | neutral chroma 0.03 | render (the pale tints) |
| R-3b | coloured chroma 0.30 | render (ACI 4) |
| R-5 | RGB cache skipped | render |
| R-6 | no white-is-paper | render |
| R-8 | shell: a dark key always rebuilds | planner (White to Ivory) |
| R-8b | the same in `ServiceView` | planner |

- **M-DC-9 has no new test.** The export cannot reach the display resolver
  without an API change, so the mutant had to be a source edit inside
  `page_export.dart`. The existing export suites catch it.
- **Allocation.** `paint_allocation_test` and `query_allocation_test` pass
  unedited, but they measure buffer growth with a `DocumentStyleResolver`,
  so they say nothing about the new resolver. Its steady state is pinned by
  M-DC-8: zero re-tones over 10 frames, and the kept object is returned.

## Review

One independent review gave "Approved with findings" and found nothing
blocking.

- **Re-fired by the reviewer:** M-DC-2, M-DC-4, M-DC-5 and M-DC-8, all red.
- **Fixed in `4543dd6`:**
  - 1–3: three surviving mutants (scale and linetype pass-through with
    `contextFor`, clipping, the blend constant);
  - 4: pale tints became heavy mid-tones on the dark sheet (`e0ffe0`
    reached contrast 6.8). This drove the blend amendment;
  - 5: the RGB cache from the note;
  - 6: the white mask is the paper;
  - 8: a dark-theme page change that keeps the key keeps the painter.
- **Recorded, not changed:**
  - 7: M-DC-9 is killed by the existing export suites (above);
  - 9: brightness is not strictly monotonic in lightness after chroma
    reduction. The worst shortfall the reviewer found in 200k colours was
    0.097 of contrast, inside the tested 0.1.

## Screenshots

Chromium (Playwright, `/opt/pw-browsers`), 1440×900 at DPR 1. `colorScheme`
is `'dark'` except for the light control. The builds are the
`--no-web-resources-cdn` builds at `4543dd6`. The files are in
[2026-10-05-dark-canvas/](2026-10-05-dark-canvas/); colours were sampled
from the PNGs.

- **`planner_dark_white.png`.** The floor planner's sample plan on a White
  page:
  - the sheet is `#1E1F22`;
  - walls and the column are `#FFFFFF`;
  - the hall floor is `#47484A`, its texture lines a lighter grey;
  - the furniture fill is `#4A4741`, with light brown edges;
  - doors, room names and dimensions are white;
  - the selection-free canvas reads like AutoCAD's dark model space.
- **`planner_light_white.png`.** The same plan in the light theme, the
  control: walls `#000000`, hall floor `#D1D1D1`, furniture `#CFCAC2`. It
  is the same view as before this change.
- **`planner_dark_blueprint.png`.** Blueprint in the dark theme is
  unchanged: black walls on Blueprint (K1).
- **`service_dark_white.png`.** The restaurant demo's service view with
  random statuses, `1,2` merged as G1 and given Bill. White table lines,
  the purple group frame and its `1+2` chip, red Bill fills with white
  captions.
- **`demo_design_dark_white.png`.** The demo's design mode on the dark
  sheet.

The human looked at the first set of screenshots, at `118d707`, and said
"tamam iyi görünüyor" (2026-10-05). The set above, at `4543dd6`, differs
only in the furniture fill, which is darker after the blend amendment
(`#4A4741`, was `#625E58`).

## Debt

- **Blueprint and similar dark papers.** In the dark theme, black walls
  stay black on Blueprint and read poorly. This is by K1; re-toning dark
  papers too would be a separate decision.
- **Status captions.** "Bill" captions overlap chair lines on some tables
  in the service view. This predates the change.
- **Furniture and floor fills.** Pale fills and floors land close together
  on the dark sheet (`#4A4741` against `#47484A`), as they do on white
  (`#CFCAC2` against `#D1D1D1`). The furniture's edges carry the
  distinction.
- **Owed:** the human's look on macOS and a tablet, never simulated.
