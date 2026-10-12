# Brief: plan colours Slice 2, Task 6

Plan: docs/superpowers/plans/2026-10-12-plan-colors-slice-2.md
Spec: docs/superpowers/specs/2026-10-12-plan-colors-design.md

## Global Constraints

- `CLAUDE.md`'s non-negotiables. **The frame path allocates nothing per
  entity in steady state**: `query_allocation_test` and
  `paint_allocation_test` stay untouched and green; the fill painter's own
  allocation bar (`test/service/table_status_painter_test.dart`) is
  extended to the design mode's mount (Task 3), never loosened.
- **Draw order is ascending handle value**; the fills keep it (they are
  sorted by instance handle, as today).
- **Stored values compare with exact `==`**; geometric decisions use
  `Tolerance`.
- **`jet_cad_2d` is not edited in this slice.** `jet_cad_2d_flutter` is
  edited **only in Task 1** (the page export's underlay).
- **No existing signature, `==`, `hashCode` or `toString` changes**, except
  `FloorPlanTableDetail`'s (Task 2: `color` joins all four),
  `FloorPlanTheme`'s (Task 3: `tableColorOpacity` joins every field list)
  and `TableStatusPainter`'s constructor (Task 3: a new optional
  parameter). Every new parameter is named and optional with today's
  behaviour as its default. **Existing tests pass unedited**, with these
  named exceptions only:
  - **Task 3:** `test/host/floor_plan_theme_test.dart` — the tests that
    enumerate every field (`copyWith`, `merge`, `lerp`, `==`, the debug
    map, the range check) gain `tableColorOpacity`; any test in
    `test/service/table_status_painter_test.dart` that pins "no survey
    when no status is set" (the `:185` skip, removed by PC-5) is re-pinned
    to the new rule.
  - **Task 5:** `test/colors/color_picker_test.dart` CP1's Wall-tool leg
    (the vacuous one, Slice 1's ledger) is rewritten to the pinned form.
  Any other test that has to change is a finding for the task's report.
- **The standing sets stay exactly as they are**
  (`tool/ci/standing_failures.txt`, `standing_skips.txt`), compared from
  the repo root with `dart run tool/ci/expect_failures.dart --package
  packages/<pkg> --root packages/<pkg> <run.json>` (runs made with
  `--file-reporter json:<run.json>`). On macOS the render package's
  `text_lod_ladder` rungs 1–2 pass: the recorded standing difference, not a
  finding. The engine's `dart test` exits 1 for its two fingerprints while
  `expect_failures` exits 0.
- **Every task ends green** in every package it touches and every package
  that reads what it changed. The planner runs with `flutter test
  --enable-vmservice`. `flutter analyze` / `dart analyze`, and `dart format
  --output=none --set-exit-if-changed .`, clean.
- **Fixtures** (CLAUDE.md's testing bar; the spec's testing section): every
  drawing test places a table **turned and mirrored**, away from the
  origin, whose top is **off-centre in its definition and asymmetric**
  (a circle or a centred rectangle is invariant under a turn and a mirror
  about its centre), beside a **circular** top that is also off-centre;
  status, group status and colour on **different tables of one plan**; one
  coloured table inside a coloured room; one coloured table **unnumbered**;
  one on a **locked** layer; one on a **hidden** layer. Hues `teal` and
  `purple`, and the unknown name `"magenta"`. A non-default
  `tableColorOpacity` (0.6) beside a different `statusFillOpacity` (0.8)
  wherever an opacity is asserted.
- **Each named mutant is applied, seen red and reverted**, its killer named
  in the report.
- **Never `git checkout` a file to revert it**; copy it aside or `git show
  HEAD:path > path`. **Never commit an `analysis_options.yaml`.** **Never
  synthesize test output.** Code, comments and commits in English; commit
  trailers name the model that wrote the commit.
- No component type and no handle crosses the host barrel
  (`FloorPlanTableColor` stays internal, as `FloorPlanTableData` does).
- **The worktree guard:** this session's shell refuses `$VAR` in argument
  position, `bash <script>` and git-mixing pipelines inside the worktree;
  use plain commands and literal paths/SHAs.


## Review Focus

The situations a person meets that the tasks' own assertions would
otherwise not reach, each pinned by a test in the task named:

1. **A status arriving and leaving on a coloured table** in the selection
   mode: the table shows its colour, then the status (no colour visible),
   then its colour again when the host clears the status — with no
   document change in between. Task 3, TF6.
2. **Delete then Undo of a coloured table** in the editor: the colour is
   back on screen at the next frame and in `tableDetails`, and
   `designChanges` reports the table re-added with its colour. Task 2,
   TC8; Task 3, TF8.
3. **`controller.exportPlan` with no view mounted**: coloured tables are in
   the PNG at 0.35 (the default), and at a given `tableColorOpacity`.
   Task 4, EX3.
4. **A coloured table on a locked layer**: it is filled on screen and in
   the export, the API recolours it, and the editor cannot select it (the
   picker never reaches it). Task 2, TC5; Task 3, TF4; Task 4, EX2.
5. **A theme switch light ↔ dark while the editor is up**: the table fills
   re-tone with no document change, matching a room tint of the same hue.
   Task 3, TF7.

---


---

### Task 6: The guide, the CHANGELOG, STATUS and the exit (PC-12, Slice 2)

**Files:**
- Modify: `docs/host-guide.md` (a new "Colours on the plan" subsection under §7 Tables, statuses and selection, before "### Table groups"; the theme section's field list; §11 if a statement there moves)
- Modify: `tool/ci/host_probe/lib/main.dart` (every new code block of the guide, as `check_guide` requires)
- Modify: `CHANGELOG.md` (`## Unreleased`)
- Modify: `STATUS.md`

- [ ] **Step 1: The guide.** The subsection, in the guide's voice, with
  code blocks that compile in the host probe:
  - the palette (`FloorPlanColor`, eight hues, stored by name; an unknown
    name from a later release reads null and is saved back);
  - reading a colour (`detail.color` in `controller.tableDetails`) and
    setting one (`controller.setTableColor('12', FloorPlanColor.teal)`,
    `setTablesColor({...})`), with `setTableData`'s rules restated in
    brief (design mode only, ambiguous numbers refused, one undo step
    labelled "Table colour", hidden or locked tables take one, null
    removes);
  - a status covers a colour in the selection mode; clearing the status
    shows the colour again;
  - the dark canvas tones it as it tones a room's tint;
  - `FloorPlanTheme.tableColorOpacity` (null 0.35), in the theme section's
    field list too;
  - export and print carry the colours: the view's at its theme's
    opacity, `exportPlan` / `printPlan` at 0.35 or a given
    `tableColorOpacity`;
  - `designChanges` reports a colour change as `FloorPlanTableChanged`.
  Add each block to `tool/ci/host_probe/lib/main.dart` the way the
  existing blocks are (read the probe's structure first). Run, from the
  repo root, `dart run tool/ci/check_guide.dart`: it passes.

- [ ] **Step 2: The CHANGELOG** — `## Unreleased` gains, after Slice 1's
  bullets: "**A table can take a colour**, one of the eight
  `FloorPlanColor` hues: in the Selection panel's Colour row (beside
  rooms), or by `controller.setTableColor` / `setTablesColor`; read back
  as `FloorPlanTableDetail.color`. It is drawn as a fill under the table's
  drafting in both modes, exported and printed; in the selection mode a
  status covers it. `FloorPlanTheme.tableColorOpacity` (default 0.35) sets
  its strength; `exportPlan` and `printPlan` take an optional
  `tableColorOpacity`." and, for `jet_cad_2d_flutter`: "`exportPagePdf`
  and `exportPagePng` take an optional `underlay` of `PageUnderlayFill`s
  drawn under the drawing."

- [ ] **Step 3: STATUS** — "In flight" and "Resume here": Slice 2
  implemented on `feat/plan-colors-slice-2`, reviewed, awaiting the human's
  merge word, then release 0.6.0. "Owed to the human": a look at coloured
  tables in both modes, light and dark, and in an export; the earlier
  owed items stay.

- [ ] **Step 4: The exit gate, whole.** Every package and app through its
  gate (the comparison for the engine, render and GPU; `flutter test`,
  analyze and format for the rest, the planner with `--enable-vmservice`),
  `tool/ci` (`dart test`, analyze, format, `check_guide`), the host probe
  (`tool/ci/host_probe.sh file:///<absolute worktree path> <full HEAD
  sha>`) and the three old-host probes (`tool/ci/old_host_probe.sh
  v0.3.0`, `v0.4.0`, `v0.5.1`). Paste each command's last lines into the
  report.

- [ ] **Step 5: Commit** — `docs: plan colours Slice 2 in the guide, the
  CHANGELOG and STATUS`.
