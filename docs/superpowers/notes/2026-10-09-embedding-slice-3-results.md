# Host embedding API, Slice 3: results

**Asked by the human:** *"tamam, Dilim 3 ile devam et"* (2026-10-09),
after Slice 2 merged; the merge on *"evet, main'e merge et"*.

**Spec:** [2026-10-09-host-embedding-api-design.md](../specs/2026-10-09-host-embedding-api-design.md),
revision 3, as amended: the plan's points S-1 to S-12, ruled as it
recommended (T-3 names the selection overlay's reuse test; **T-4 keeps
today's default font**, against P-6 otherwise; the merge, lerp, ranges,
ink, defaults, widths, veil, the bar's re-measure and the resolution's
seat). The Review section lists them.

**Plan:** [2026-10-09-embedding-slice-3.md](../plans/2026-10-09-embedding-slice-3.md).

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `8fd7483`
(Slice 2 merged). **Merged** into `main` at `d26c9fe` on the human's
*"evet, main'e merge et"*.

**Process.** Each of Tasks 1–3 had a fresh implementer, then an
independent reviewer in its own clone, then its fixes. Task 4 (the demo,
the guide, the probe, the CHANGELOG, the gates) was delegated by the
controller and gated by it. An independent review of the whole range
closes the slice.

## What a host gets

- **`FloorPlanTheme`**, a `ThemeExtension` of sixteen optional fields
  (null is today's value): the status caption's style and the fill's
  opacity; the group frame's colour, width and margin and the chip's
  colour, style, radius and padding; the selection's colour per paper
  (`selectionOnLight`, `selectionOnDark`) and width, in **both modes**;
  the focus veil's colour and opacity; `canvasBackground` (the surround
  and a page-less plan's paper, both modes); `serviceBarHeight`.
- **Resolution:** one extension in each `ThemeData` (light and dark), and
  `FloorPlanView(theme:)` merged over it field by field (text styles by
  `TextStyle.merge`), compared by `==`, resolved just below the view so a
  theme switch reruns no host overlay builder. `lerp` clamps, keeps equal
  themes equal and switches a field (or a style whose colour is null on
  one side) whole at 0.5, so an animated switch never yields an invalid
  theme. Out-of-range values throw an `ArgumentError` naming the field.
- **Chrome** otherwise follows the ambient Material `Theme`; the guide's
  recipe wraps the view in a local `Theme` with a hand-built
  `ColorScheme`. The export dialog follows that local `Theme`, never the
  view's `theme:`.
- **Paint rate:** the theme joins each painter's repaint merge and
  rebuild key; nothing is derived per frame (the painters' counters, with
  and without a theme, and a VM-profiler pan measurement: the same counts).
- **`jet_cad_2d_flutter`:** `PaperPalette.withSelection` and
  `SelectionOverlayPainter.selectionStrokePixels` (additive).
- **The demo:** a *Standard / POS* look switch; the POS look's
  shadcn-like zinc tokens are a proposal, not Monépro's; the view
  overrides one field (`selectionWidth: 3`) to show the merge.
- **The guide:** § 9 "Themes"; every block in the host probe (37).
- **No stored format changes** (schema 9 stays).

## The tasks

| Task | Commit | Review | Fixes |
|---|---|---|---|
| 1, `FloorPlanTheme` and its resolution (T-1's type, T-2) | `620dabd` | **Changes required**, small: an overshooting animation curve lerped two valid themes into an invalid one; equal themes lerped unequal; a style colour faded in from transparent; a bare shell unvalidated | `e111b28`: lerp clamps, keeps equal themes, switches styles whole; the bare shell validated; `Object.hash` |
| 2, selection colours, width, canvas | `58c4a60` | **Approve**, two tests to add (`canvasBackground` under the dark theme; the width's assert) | `fcace6b` |
| 3, the selection mode's painters and bar | `74024d7` | **Approve with fixes**: the chip box off-centre with uneven padding; the chip's ink ignored its alpha; five behaviours unpinned | `6fb7a6d`: the chip centred, its ink on the chip as drawn, K12–K17 and RV5 |
| 4, demo, guide, probe, CHANGELOG | `a5c9fdc`, `28b10b3`, `accc153`, `61ca42e` | gated by the controller | `61ca42e`: the POS look's veil keeps the paper's colour (found by the smoke check) |
| the range `8fd7483..6fb7a6d` | — | **Independent review: Approve with fixes**; no code defect; **with no theme, 216 planner captures and 18 demo captures byte-identical to `8fd7483`**, PNG exports identical, PDFs identical but for their date and id | `237a28e` F-2/F-3 tests (a theme's removal, a shrinking bar, a translucent canvas, an animated switch), `9eb8434` F-1/F-4 docs |

Per-task reports, reviews and fixes are archived in
[docs/superpowers/ledgers/2026-10-09-embedding-slice-3/](../ledgers/2026-10-09-embedding-slice-3/).

## Named mutants

Every named mutant of the plan went red, each with its killer recorded in
the task's report: Task 1's M-H30 (and its reversed form) with T1-a to
T1-c; Task 2's M-H33(canvasBackground) and M-H33(the editor's selection),
each in both modes, with T2-a to T2-d; Task 3's M-H31 (every painter),
M-H32, M-H33(repaint), M-H33(opacity twice), M-H33(null caption colour)
with T3-a to T3-e; Task 4's probe mutant (`check_guide` exits 1). The
reviews ran about 90 mutants of their own; every survivor is now red or
recorded as equivalent.

## Gates (at `9eb8434`)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | 1258 tests; the standing failures and skips, exactly. |
| render `packages/jet_cad_2d_flutter` | 1390 tests (1379 at `8fd7483`); the standing set exactly. Both allocation invariants green. |
| gpu | 20 tests; exactly. |
| planner `packages/jet_cad_floor_plan` | **1692 passed** (1599 at `8fd7483`), with `--enable-vmservice`; analyze and format clean. |
| restaurant symbols | 97 passed. |
| demo `apps/restaurant_demo` | **60 passed** (57). |
| app `apps/floor_planner` | 212 passed. |
| `tool/ci` | 63 passed; `check_guide`: all 37 code blocks are in the host probe. |
| host probe | exit 0 at the tip by `file://`; v0.3.0's probe analyses against it. |
| web builds | both 42M from a clean `build/`, no `flutter_scene` assets. |

**Smoke check** (Chromium, Playwright, `en-US`, light and dark): the
Standard look is 0 pixels from a build of `74024d7` in every shot; the POS
look shows the 52 px zinc bar, the surround in `canvasBackground`, the
3 px orange selection per paper in both modes, the group frame and chip
in the primary with automatic ink, the heavier veil, bold Roboto
captions; no console error.

## Found, not fixed

- **Removing a design view while a pointer hovers a line throws**
  ("setState() or markNeedsBuild() called during build", the selection
  panel through the interaction layer's `deactivate`); it predates the
  slice (reproduced at `620dabd` and `8fd7483`). Its own task.
- **The PDF export of a table with non-finite corners asserts NaN**
  (also at `8fd7483`); a hand-edited plan could reach it; beside O-11.
- **The first switch into the selection mode with a bar height other
  than 44 shows one frame 8 px off**; later switches are exact.
- **A `focusVeilColor` unlike the paper** shows a tinted box over each
  faded table, as S-9 says; the guide warns.

## Owed

- **To the human:** a look at the POS look on a tablet and a terminal,
  light and dark; a native read of de "Aussehen / Kasse" and tr
  "Görünüm / Standart / Kasa".
- **To Monépro:** the real shadcn tokens for its `FloorPlanTheme` and
  local `Theme` (the demo's are a proposal).
- **A release** carrying Slices 1–3 is the human's call; until then it
  is CHANGELOG *Unreleased*.
