# Brief: plan colours Slice 2, Task 3

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

### Task 3: The theme and the fill painter in both modes (PC-5, PC-6)

**Files:**
- Modify: `packages/jet_cad_floor_plan/lib/src/host/floor_plan_theme.dart` (every field list: constructor `:25-42`, fields, `copyWith` `:115-152`, `merge` `:155-180`, `lerp` `:205-241`, `==` `:278-296`, `hashCode` `:298-315`, debug map `:318-335`, `validateFloorPlanTheme` `:380`)
- Modify: `packages/jet_cad_floor_plan/lib/src/service/table_status_painter.dart` (`TableStatusPainter` `:106-143`, `_rebuild` `:175-260`, its doc `:79-105`)
- Modify: `packages/jet_cad_floor_plan/lib/src/host/service_view.dart:290-306` (pass `darkCanvas: () => _darkCanvas`)
- Modify: `packages/jet_cad_floor_plan/lib/src/planner_shell.dart` (notifiers for the paper and the theme; the painter; `PlannerView(underlay: ...)` at `:1464-1500`; `didChangeDependencies` `:366-375`; `_onPage` `:357-361`; `dispose`)
- Create: `packages/jet_cad_floor_plan/test/service/table_fill_test.dart`
- Modify (named exceptions only): `test/host/floor_plan_theme_test.dart`, `test/service/table_status_painter_test.dart`

**Interfaces:**
- Consumes: `FloorPlanTableColor.colorValue` (Task 2).
- Produces: `const double kTableColorOpacity = 0.35;` (in
  `floor_plan_theme.dart`, internal); `FloorPlanTheme.tableColorOpacity`
  (`double?`); `TableStatusPainter({..., bool Function()? darkCanvas})`.

- [ ] **Step 1: Write the failing tests** in
  `test/service/table_fill_test.dart`, painting `TableStatusPainter` into a
  `PictureRecorder` (read `table_status_painter_test.dart` for its rig:
  how it builds a document with tables, pumps statuses, and reads pixels or
  recorded ops) and through the shell (`PlannerShell`/`FloorPlanView`
  pumped as `test/host/theme_canvas_test.dart` does, reading canvas pixels
  with `tester.binding` / `RenderRepaintBoundary.toImage`). Fixture per the
  Global Constraints. Expected colours are written as literals and
  arithmetic in the test (`0x00897B` at `round(255 * 0.35) == 89`), never
  read from the code under test. Tests:
  - **TF1** design mode, default theme: a teal table's top centre-off-label
    pixel (sample at the image of a point inside the top, away from the
    number label, which sits at the top's centre) composites teal at alpha
    89 over the paper; an uncoloured table's is the paper.
  - **TF2** the chain (**M-C5**), selection mode: table A coloured teal and
    statused red (`TableStatus(color: Color(0xFFE53935))`) shows the
    status, not teal; table B coloured purple in a group with a group
    status shows the group status; table C coloured teal with no status
    shows teal; no caption is drawn for C (the painter's recorded
    paragraphs: none for C's instance).
  - **TF3** hidden and unknown (**M-C6**, **M-C21**): a coloured table on
    the hidden layer draws nothing; a table carrying `"magenta"` draws
    nothing.
  - **TF4** locked and unnumbered (**M-C20**, **M-C19**): both are filled.
  - **TF5** opacity (**M-C8**): with `FloorPlanTheme(tableColorOpacity:
    0.6, statusFillOpacity: 0.8)`, a coloured table's fill alpha is
    `round(255 * 0.6) == 153`, a statused table's is the status colour's
    alpha times 0.8 — each applied once.
  - **TF6** a status arriving and leaving (Review Focus 1): selection mode,
    table C teal; `setTableStatus({'C': red})` → red, no teal;
    `setTableStatus({})` → teal again; no document change in between
    (`stateId` unchanged).
  - **TF7** dark canvas (**M-C25**, Review Focus 5): the shell under a dark
    theme over a white page (the dark canvas, `darkCanvasFor` true): a
    teal table's fill pixel is `darkCanvasTone(0x00897B, kDarkCanvasPaper)`
    at alpha 89 over `kDarkCanvasPaper`, and equals (±2 per channel) a
    teal room's tint pixel recomputed for alpha 89 from the same tone —
    i.e. both go through `darkCanvasTone`; then switch the theme to light
    (pump a new `MaterialApp` theme) with no document change: the fill is
    plain teal over white.
  - **TF8** design mode repaint (**M-C24**, **M-C15**): with nothing else
    moving, `controller.setTableColor('1', teal)` → after one `pump` the
    fill is there; `controller.undo()` → after one `pump` it is gone;
    redo → back.
  - **TF9** the allocation bar, design mode: after the first frame, ten
    further frames (camera pans by `controller.camera`) leave
    `debugAllocations` and `debugRebuilds` unchanged; a colour change
    rebuilds once.
  - **TF10** the survey with no status (**M-C18**): a painter with empty
    statuses and groups (the design mount) and one coloured table has one
    fill after its first paint.

- [ ] **Step 2: Run; see them fail.**

- [ ] **Step 3: The theme field.** Add `this.tableColorOpacity` to the
  constructor after `statusFillOpacity`, the field with its doc

```dart
  /// Both modes' table colour fills (plan colours spec PC-6): the hue's
  /// alpha, in [0, 1]. Null: 0.35.
  final double? tableColorOpacity;
```

  and the same name in `copyWith`, `merge` (`other.tableColorOpacity ??
  tableColorOpacity`), `lerp` (`_lerp(tableColorOpacity,
  other.tableColorOpacity, t, _lerpBetween)`), `==`, `hashCode`, the debug
  map, and `validateFloorPlanTheme` (`opacity(theme.tableColorOpacity,
  'tableColorOpacity')`). Add `const double kTableColorOpacity = 0.35;`
  with a doc line. Re-pin the field-enumerating tests in
  `floor_plan_theme_test.dart` (named exception).

- [ ] **Step 4: The colour rung.** In `TableStatusPainter`: a new
  constructor parameter `this.darkCanvas` (`final bool Function()?
  darkCanvas;` documented "whether the canvas re-tones its colours (dark
  canvas K3): a table colour's hue is drawn through `darkCanvasTone` then,
  as a room's tint is; null: never"). In `_rebuild`:
  - the survey always runs (remove the `if (map.isNotEmpty ||
    groupMap.isNotEmpty)` guard and its comment; keep the body);
  - per table: `final number = t.number;` — the status rungs only when
    `number != null` (`final status = number == null ? null :
    (groupStatus ?? map[number])`), then

```dart
        final colour = status == null
            ? document.components.get<FloorPlanTableColor>(t.instance)?.colorValue
            : null;
        if (status == null && colour == null) continue;
```

  - a coloured table adds a fill whose paint is built from

```dart
        final rgb = (darkCanvas?.call() ?? false)
            ? darkCanvasTone(colour.rgb, paperArgb & 0xFFFFFF)
            : colour.rgb;
        final alpha = (255 * (look?.tableColorOpacity ?? kTableColorOpacity))
            .round();
        final drawn = Color((alpha << 24) | rgb);
```

    keyed in `_paints` by `drawn.toARGB32()` like a status's, with no
    caption (`caption: null`);
  - the visible-layer rule and the path cache are shared, unchanged.
  The record list `statused` becomes `(TableInfo, Path, Color drawn,
  TableStatus? status, String? group)`; captions only for a status. Update
  the class doc (the chain: group status, own status, colour) and `_rebuild`'s
  comment. Re-pin any test in `table_status_painter_test.dart` that pinned
  "no survey with no status" (named exception).

- [ ] **Step 5: The service mount** passes `darkCanvas: () => _darkCanvas`
  (`service_view.dart:290`).

- [ ] **Step 6: The design mount.** In `PlannerShellState`:

```dart
  // Plan colours spec PC-5: the table colour fills, under the drafting, in
  // the design mode: no statuses and no groups; they repaint on the camera,
  // every document change, the paper and the theme.
  final ValueNotifier<int> _fillPaper = ValueNotifier<int>(0xFFFFFFFF);
  final ValueNotifier<FloorPlanTheme?> _fillTheme =
      ValueNotifier<FloorPlanTheme?>(null);
  static final ValueNotifier<Map<String, TableStatus>> _noStatuses =
      ValueNotifier(const <String, TableStatus>{});
  static final ValueNotifier<Map<String, TableGroup>> _noGroups =
      ValueNotifier(const <String, TableGroup>{});
  late final TableStatusPainter _fillPainter = TableStatusPainter(
    document: _document,
    camera: _camera,
    statuses: _noStatuses,
    tableGroups: _noGroups,
    groupStatuses: _noStatuses,
    paper: _fillPaper,
    theme: _fillTheme,
    darkCanvas: () => _darkCanvas,
    repaint: Listenable.merge(
        [_camera, _documentChanged, _fillPaper, _fillTheme]),
  );
```

  Static notifiers are never disposed (they never change); `_fillPaper`
  and `_fillTheme` are disposed in `dispose`. Set `_fillTheme.value =
  _floorTheme; _fillPaper.value = _paperArgb();` at the end of
  `didChangeDependencies`, and `_fillPaper.value = _paperArgb();` at the
  top of `_onPage` (before its early return: a page change that keeps the
  resolver's key still changes the paper). Pass `PlannerView(underlay:
  RepaintBoundary(child: CustomPaint(key: const Key('table-colour-layer'),
  painter: _fillPainter, size: Size.infinite)), ...)`. Check first that
  the shell is not itself the selection mode's canvas (the service view
  builds its own `PlannerView` with its own `underlay`; the design shell's
  mount must not reach it) — read `service_view.dart`'s build.

- [ ] **Step 7: Run; pass**; then the planner (`--enable-vmservice`, the
  allocation tests included), `apps/floor_planner`, `apps/restaurant_demo`;
  analyze; format.

- [ ] **Step 8: The mutants:**
  - **M-C5** — the colour above the status (`colour` read first). Killer: TF2.
  - **M-C6** — the visible-layer check skipped for colours. Killer: TF3.
  - **M-C8** — `tableColorOpacity` applied twice (`alpha * o`) or ignored
    (`alpha = 255`). Killer: TF5.
  - **M-C15** — the rebuild key misses the document (`_state` check
    removed). Killer: TF8's undo.
  - **M-C18** — the survey guard kept. Killer: TF10, TF1.
  - **M-C19** — the number required for colours (`if (number == null)
    continue;` restored at the loop's top). Killer: TF4.
  - **M-C20** — a locked layer skipped. Killer: TF4.
  - **M-C21** — an unknown name drawn (`colorValue ?? FloorPlanColor.grey`).
    Killer: TF3.
  - **M-C24** — the design mount's repaint misses `_documentChanged`.
    Killer: TF8.
  - **M-C25** — `darkCanvas` ignored (always raw `rgb`). Killer: TF7.
  - **M-PC6** — `tableColorOpacity` dropped from `merge` (or `lerp`).
    Killer: the re-pinned theme tests.

- [ ] **Step 9: Commit** — `feat(floor-plan): a table's colour drawn under
  its drafting in both modes` (PC-5, PC-6).
