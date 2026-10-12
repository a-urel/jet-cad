# Brief: plan colours Slice 2, Task 2

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

### Task 2: The table colour component and the host API (PC-4, PC-11)

**Files:**
- Create: `packages/jet_cad_floor_plan/lib/src/tables/table_color_component.dart`
- Modify: `packages/jet_cad_floor_plan/lib/src/parametric/catalog.dart:44-58` (register beside `FloorPlanTableData`)
- Modify: `packages/jet_cad_floor_plan/lib/src/tables/table_index.dart` (`_keptColor`, the diagnostic, `TableDiagnosticCodes.invalidColor`)
- Modify: `packages/jet_cad_floor_plan/lib/src/host/table_detail.dart` (`color`; `tableDetailOf` / `tableDetailWithoutGeometry` gain `FloorPlanColor? color`)
- Modify: `packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart` (`_detailsOf` `:1496-1540`; `setTableData`/`setTablesData` `:1557-1597`)
- Create: `packages/jet_cad_floor_plan/test/host/table_color_test.dart`

**Interfaces:**
- Consumes: `FloorPlanColor`, `floorPlanColorNamed` (Slice 1, `lib/src/colors/plan_color.dart`).
- Produces:

```dart
// lib/src/tables/table_color_component.dart — no Flutter import.
final class FloorPlanTableColor implements Component {
  static const String componentTypeId = 'jetcad.table_color';
  static void register(ComponentRegistry registry);
  FloorPlanTableColor(FloorPlanColor color);       // stores color.name
  static FloorPlanTableColor fromJson(Map<String, Object?> json); // never throws
  final String? name;                // the stored name; null when kept
  final Map<String, Object?>? kept;  // the payload as read, when not {"color": String}
  bool get isKept;
  FloorPlanColor? get colorValue;    // null when kept or unknown
  Map<String, Object?> toJson();     // kept ?? {'color': name}
  // == and hashCode by the encoded payload, as FloorPlanTableData's
}
```

  `FloorPlanTableDetail.color` (`FloorPlanColor?`, default null), in `==`,
  `hashCode`, `toString`. `FloorPlanController.setTableColor(String number,
  FloorPlanColor? color) → bool`, `setTablesColor(Map<String,
  FloorPlanColor?> byNumber) → bool`. `TableDiagnosticCodes.invalidColor
  == 'table.invalid_color'`. `TableSurvey` gains `Set<Handle> _invalidColor`
  (kept or unknown) feeding the diagnostic.

- [ ] **Step 1: Write the failing tests** in
  `test/host/table_color_test.dart`. Reuse
  `test/host/embedding_fixture.dart` (`embeddingPlanJson`,
  `embeddingTables`: tables turned 30°, mirrored, scaled, 40 m off the
  origin; `5` hidden, `L` locked; `7` and ` 7 ` sharing a number; an
  unnumbered table) and `test/host/table_data_test.dart`'s helpers (read
  them: the controller fixture, `dataSection`). Tests:
  - **TC1** the component: `FloorPlanTableColor(FloorPlanColor.teal).toJson()`
    is `{"color":"teal"}`; `fromJson({"color":"teal"})` equals it;
    `fromJson({"color":"magenta"})` keeps `name == 'magenta'`,
    `colorValue == null`, `isKept == false`, re-encodes `"magenta"`;
    `fromJson({"color": 7})` and `fromJson({"hue":"teal"})` and
    `fromJson({"color":"teal","x":1})` are kept verbatim (`isKept`,
    `toJson()` equals the input), never throw (**M-C1** tables).
  - **TC2** `setTableColor('1', FloorPlanColor.teal)` → true; one undo step
    labelled `Table colour` (read the label from `doc.commands.changes`'
    `CommandApplied.label`, as Slice 1's CP2 does); `dirty`, `canUndo`,
    `revision` moved; `tableDetails` for `1` has `color ==
    FloorPlanColor.teal`; `designJson()` holds
    `"jetcad.table_color"` with `{"color":"teal"}` on table 1's instance;
    undo → no component, `color` null; redo → teal.
  - **TC3** `setTablesColor({'1': teal, ' 2 ': purple, 'L': null})` → one
    undo step; `setTablesColor({'1': teal, '7': purple})` (7 shared) →
    false, nothing changed, `canUndo` false after a `clearHistory`
    (**M-C9**); `{'1': teal, ' 1 ': purple}` → false; an unknown number →
    false.
  - **TC4** equal skip: setting teal twice → the second returns true with
    no edit (`undoDepth` unchanged); `setTableColor('1', null)` on a table
    with none → true, no edit.
  - **TC5** a table on the hidden layer (`5`) and the locked one (`L`)
    takes a colour (Review Focus 4).
  - **TC6** the selection mode refuses: `setTableColor` throws
    `StateError`; `tableDetails` there (the service copy) reads the
    design's colour.
  - **TC7** a kept payload: a plan whose table 1 carries
    `{"color": 7}` (edit `embeddingPlanJson`'s JSON map before load)
    opens; `tableDetails` reads `color == null`; `diagnostics` (the table
    survey's: read how `table_data_test` reaches `table.invalid_data`)
    names `table.invalid_color` for it; saved, the payload is written back
    verbatim (**M-C2**); `setTableColor('1', null)` removes it (an edit,
    `dirty`) and `designChanges` reports **no** `FloorPlanTableChanged`
    for it (color null before and after).
  - **TC8** delete and undo (Review Focus 2): with `designChanges`
    listened, colour table 1 teal, then delete it in the editor (as
    `table_data_test`'s delete test does: the select tool's delete, or
    `controller.deleteSelection` — read it) → the component store has no
    entry for the instance; `FloorPlanTableRemoved` carries
    `color == teal`; undo → the component is back and
    `FloorPlanTableAdded` carries teal (**M-C11**).
  - **TC9** `designChanges` on a recolour: one `FloorPlanTableChanged`
    whose `before.color` is null and `after.color` teal (**M-C14**); a
    renumber of a coloured table keeps the colour; Change size (the
    Symbol section's Size menu, F-17: `SetInstanceDefinitionCommand` —
    read `symbols/symbol_section.dart:196-222`) keeps the component on the
    instance.

- [ ] **Step 2: Run; see them fail** (compile errors).

- [ ] **Step 3: Implement the component**, modelled line for line on
  `FloorPlanTableData` (`tables/table_data_component.dart`): a private
  constructor `_(this.name, this.kept)` with `_encoded = jsonEncode(kept ??
  {'color': name})` for `==`/`hashCode`; `fromJson` returns the name when
  `json.length == 1 && json['color'] is String`, else `_keep(json)` with
  the same `_frozen` deep copy. Register it in `registerAppComponents`
  after `FloorPlanTableData.register(r)`. In `TableSurvey.of`, beside
  `kept.add(...)` for data: `final c = doc.components.get<FloorPlanTableColor>(node.handle); if (c != null && c.colorValue == null) invalidColor.add(node.handle);`
  and in `diagnostics` a warning `TableDiagnosticCodes.invalidColor`,
  message `'Table ${t.instance.toHex()} carries a colour this release cannot read; it is kept as read and drawn as none'`.

- [ ] **Step 4: Implement the API.** `FloorPlanTableDetail` gains
  `this.color` (named, optional, null); `==` adds `other.color == color`,
  `hashCode` adds `color`, `toString` adds `color: $color`. `tableDetailOf`
  and `tableDetailWithoutGeometry` take `FloorPlanColor? color` and pass it.
  `_detailsOf` reads
  `d.components.get<FloorPlanTableColor>(t.instance)?.colorValue`. In the
  controller, extract the body of `setTablesData` into

```dart
  /// The one path of the table-data and table-colour setters (plan colours
  /// spec PC-11): the numbers trimmed and resolved to one table each, an
  /// unknown, shared or repeated number refusing all, entries equal to the
  /// stored component skipped, the rest one [CompoundCommand] labelled
  /// [label]. A [StateError] in the selection mode.
  bool _setTableComponents<T extends Component>(
      Map<String, T?> wanted, String label, String who) { ... }
```

  with `setTablesData` validating its maps first (as today) and calling
  `_setTableComponents<FloorPlanTableData>(wanted, 'Table data',
  'setTableData')`, and

```dart
  bool setTableColor(String number, FloorPlanColor? color) =>
      setTablesColor({number: color});

  bool setTablesColor(Map<String, FloorPlanColor?> byNumber) =>
      _setTableComponents<FloorPlanTableColor>({
        for (final MapEntry(key: n, value: c) in byNumber.entries)
          n: c == null ? null : FloorPlanTableColor(c),
      }, 'Table colour', 'setTableColor');
```

  The `StateError`'s message keeps today's for data
  (`'setTableData needs the design mode (P-5)'`) and reads `'setTableColor
  needs the design mode (P-5)'` for colour. Each setter's doc follows
  `setTableData`'s, naming the label and the colour rules (a hidden or
  locked layer's table takes a colour; null removes the component and
  replaces a kept or unknown one; that replacement makes the plan dirty
  but reports no `FloorPlanTableChanged`).

- [ ] **Step 5: Run; pass**; then the planner (`--enable-vmservice`),
  `apps/floor_planner`, `apps/restaurant_demo`; analyze; format. The
  existing table-data tests pass unedited (the shared path keeps their
  behaviour).

- [ ] **Step 6: The mutants:**
  - **M-C1** (tables) — `fromJson` throws on an unknown or ill-typed
    payload. Killer: TC1, TC7.
  - **M-C2** — a kept payload saved canonicalised (`toJson` returns
    `{'color': name}` always). Killer: TC1, TC7's save.
  - **M-C9** — `_setTableComponents` executes entries before checking the
    rest (build and execute in one loop). Killer: TC3.
  - **M-C11** — owned by the engine, not this task: a delete drops every
    component of the node through `RemoveNodeCommand` (node-components
    D-1, 0.5.0), whose own mutants pin it. No mutant of this task's code
    reaches the rule; record TC8 as M-C11's witness for the table colour
    and say so in the report.
  - **M-C14** — `FloorPlanTableDetail.==` ignores `color`. Killer: TC9.
  - **M-PC11-a** — the selection mode allowed (the `_service != null`
    check removed from the shared path). Killer: TC6.
  - **M-PC11-b** — `colorValue` read as `floorPlanColorNamed(name)!` (an
    unknown name crashes `tableDetails`). Killer: TC7 with `"magenta"` as
    a second case.

- [ ] **Step 7: Commit** — `feat(floor-plan): a table's colour in the plan
  and setTableColor` (PC-4, PC-11).
