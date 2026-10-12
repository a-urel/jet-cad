# Brief: plan colours Slice 2, Task 5

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

### Task 5: Tables in the Colour row (PC-9 tables) and the tool-mode pin

**Files:**
- Modify: `packages/jet_cad_floor_plan/lib/src/colors/color_picker.dart` (`_rooms`, `pickedColors`, `recolorCommand`, `colorPickerBlocked`, the file comment)
- Modify: `packages/jet_cad_floor_plan/lib/src/selection_panel.dart` (the `colors` flag's comment: "a room or a table")
- Modify: `packages/jet_cad_floor_plan/test/colors/color_picker_test.dart` (CP1's Wall-tool leg, the named exception; CP7–CP10)

**Interfaces:**
- Consumes: Task 2's `FloorPlanTableColor` (`name`, `isKept`).
- Produces: `pickedColors` lists rooms then tables (key order within
  each); a table's entry is its stored name (`null` for none, the kept
  payload's marker `'\u0001'` — never a swatch name — for a kept one);
  `recolorCommand` adds one `SetComponentCommand<FloorPlanTableColor>` per
  selected table not already at the colour.

- [ ] **Step 1: Write the failing tests**, in `color_picker_test.dart`,
  with a plan holding rooms **and** tables (extend the file's fixture or
  build one from `test/host/embedding_fixture.dart` plus Slice 1's
  `roomsPlan`; read both), pumped through `FloorPlanView` so
  `controller.select` is available:
  - **CP7** a selection of two tables and a room (**M-C12** tables): a tap
    on `teal` colours all three in one undo step labelled `Colour`; the
    tables' `tableDetails` read teal.
  - **CP8** marking: two teal tables mark `teal`; a teal table and a
    purple room mark nothing; a table with a kept payload marks nothing.
  - **CP9** `tablesOnly`: under `FloorPlanEditorCapabilities.tablesOnly`
    the row shows for a selected table and acts; under
    `tablesOnly.copyWith(recolor: false)` it shows read-only.
  - **CP10** permissions: under a permission set without `components` the
    row is read-only for a table selection (tooltip `readOnlyDocument`).
  - **CP1's Wall-tool leg (the carried pin, named exception)**: activate
    the Wall tool (press `W`, as CP1 does), **then** `controller.select({'1'})`;
    premises: the selection is non-empty and the active tool is still the
    wall (`controller.activeTool` or the palette's state — read what the
    controller exposes); the Colour row is absent. With the
    `!_toolMode && _openingToolMode == null` conjuncts dropped from the
    panel's `colors` flag, it shows (the mutant **M-PC9-tool** goes red).
    If `controller.select` clears or cancels the tool, use whatever host
    or shell path leaves a table selected under an active drawing tool,
    and if none exists, say so in the report: the conjuncts are then
    unreachable and the mutant equivalent, as Slice 1 recorded.

- [ ] **Step 2: Run; see them fail.**

- [ ] **Step 3: Implement.** In `color_picker.dart`:

```dart
/// The tables among [keys], in key order, each once: a key whose target is
/// a live table's instance (TableSurvey's tables: root-level).
List<Handle> _tables(DraftDocument doc, Iterable<SelectionKey> keys) {
  final tables = {for (final t in tablesOf(doc)) t.instance};
  return [
    for (final h in {for (final k in keys) k.target})
      if (tables.contains(h)) h,
  ];
}

/// What [pickedColors] lists for a table whose payload is kept: equal to no
/// swatch's name, so it marks nothing and differs from every name.
const String _keptMarker = '\u0001';
```

  `pickedColors` appends, after the rooms, `for (final h in _tables(doc,
  keys)) switch (doc.components.get<FloorPlanTableColor>(h)) { null =>
  null, final c when c.isKept => _keptMarker, final c => c.name }`;
  `recolorCommand` appends, after the rooms' commands, for each table
  whose component is not equal to the wanted one (`color == null ? null :
  FloorPlanTableColor(color)`), `SetComponentCommand<FloorPlanTableColor>(h,
  wanted)`. `colorPickerBlocked` is unchanged for tables (they need
  `components`, already checked). Update the file comment ("every selected
  room and table").

- [ ] **Step 4: Run; pass**; then the planner (`--enable-vmservice`);
  analyze; format.

- [ ] **Step 5: The mutants:**
  - **M-C12** (tables) — tables left out of `recolorCommand`. Killer: CP7.
  - **M-PC9-t** — a kept payload listed as `null`. Killer: CP8 (it would
    mark `none` beside an uncoloured table).
  - **M-PC9-tool** — the tool-mode conjuncts dropped. Killer: CP1's
    rewritten leg (or recorded equivalent, with the reason).

- [ ] **Step 6: Commit** — `feat(floor-plan): the Colour row colours
  tables` (PC-9).
