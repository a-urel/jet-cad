# Brief: plan colours Slice 2, Task 4

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

### Task 4: Export and print carry the colours (PC-7, floor plan)

**Files:**
- Create: `packages/jet_cad_floor_plan/lib/src/colors/table_color_underlay.dart`
- Modify: `packages/jet_cad_floor_plan/lib/src/export/export_bytes.dart` (`exportBytes`, `exportPdfBytes`)
- Modify: `packages/jet_cad_floor_plan/lib/src/host/page_flows.dart` (`exportOnce`, `printOnce`, `PageFlows`)
- Modify: `packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart:501-520` (`_flowsFor`)
- Modify: `packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart:1320-1355` (`exportPlan`, `printPlan`)
- Create: `packages/jet_cad_floor_plan/test/colors/table_color_export_test.dart`

**Interfaces:**
- Consumes: Task 1's `PageUnderlayFill`, `PageUnderlayPolygon`,
  `PageUnderlayCircle`, `underlay:`; Task 2's `FloorPlanTableColor`;
  Task 3's `kTableColorOpacity`, `FloorPlanTheme.tableColorOpacity`.
- Produces:

```dart
/// The underlay of [document]'s coloured tables (plan colours spec PC-7):
/// every live table on a visible layer whose colour this release knows,
/// its top in its definition's space (a polygon closed and triangulated,
/// skipped when it does not triangulate; or a circle), its instance's
/// transform, its hue at alpha `round(255 * opacity)`. Ascending by
/// instance handle. White paper: no tone.
List<PageUnderlayFill> tableColorUnderlay(DraftDocument document, double opacity);
```

  `exportBytes(..., {required fontBytes, double tableColorOpacity =
  kTableColorOpacity})`, `exportPdfBytes(..., {required fontBytes, double
  tableColorOpacity = kTableColorOpacity})`, `exportOnce(...,
  {..., double tableColorOpacity = kTableColorOpacity})`, `printOnce(...,
  {..., double tableColorOpacity = kTableColorOpacity})`, `PageFlows({...,
  double Function() tableColorOpacity = _defaultOpacity})`,
  `FloorPlanController.exportPlan(choice, {name, double?
  tableColorOpacity})`, `printPlan({printer, name, double?
  tableColorOpacity})` — a given opacity outside `[0, 1]` or not finite
  throws `ArgumentError` before anything runs.

- [ ] **Step 1: Write the failing tests** in
  `test/colors/table_color_export_test.dart` (read Slice 1's RC8 in
  `test/room_color_test.dart` for how a PNG is exported through
  `exportBytes` and a pixel located from the page's numbers). Fixture per
  the Global Constraints (an off-centre asymmetric top, turned and
  mirrored; a circular one; a coloured table inside a coloured room; one on
  a locked layer; one on a hidden layer; one `"magenta"`). Tests:
  - **EX1** `tableColorUnderlay(doc, 0.35)`: one fill per visible coloured
    table with a known colour, in ascending instance order; each polygon's
    `xy` is the top's ring closed (first point repeated), `count` its
    points, `triangles` non-empty; each `placement` the instance's
    transform; `argb` `(89 << 24) | rgb`; nothing for the hidden, the
    unknown or an uncoloured table.
  - **EX2** PNG through `exportBytes` (96 dpi): a pixel inside the
    asymmetric top's off-centre arm is teal at alpha 89 over white; a
    pixel inside the locked table's top is its colour (Review Focus 4); the
    coloured table inside the coloured room composites the table's fill
    under the room's 20 % tint (expected: teal at 89 over white, then the
    room's hue at 51 over that); a pixel in the hidden table's place is
    white (**M-C7** floor-plan side, with the turned and mirrored table).
  - **EX3** `controller.exportPlan(png)` with no view mounted (Review
    Focus 3): the same pixel at 0.35; with `tableColorOpacity: 0.6` at
    alpha 153; `tableColorOpacity: 1.5` throws `ArgumentError` and no flow
    runs (`pageFlowReady` stays true).
  - **EX4** the view's Export at a non-default theme (**M-C23**): a
    `FloorPlanView` with `theme: FloorPlanTheme(tableColorOpacity: 0.6)`
    and an `onExport` collecting the bytes; drive its Export (as
    `test/host/page_flows_test.dart` drives it, with the dialog answered
    PNG): the pixel is at alpha 153.
  - **EX5** the differential (spec's testing section): one plan, drawn on
    the design canvas (white page, light theme) and exported as a PNG at
    the default opacity: each coloured table's sampled point (off its
    number label) composites to the same colour within one unit per
    channel.

- [ ] **Step 2: Run; see them fail.**

- [ ] **Step 3: Implement `tableColorUnderlay`**:

```dart
List<PageUnderlayFill> tableColorUnderlay(
    DraftDocument document, double opacity) {
  final alpha = (255 * opacity).round();
  final layers = document.tables.layers;
  final out = <PageUnderlayFill>[];
  for (final t in TableSurvey.of(document).tables) {
    final colour =
        document.components.get<FloorPlanTableColor>(t.instance)?.colorValue;
    if (colour == null) continue;
    final node = document.tree[t.instance];
    if (node is! InstanceNode) continue;
    if (layers[node.layer] case final l? when !l.visible) continue;
    final argb = (alpha << 24) | colour.rgb;
    switch (tableTopOf(document, t.definition)) {
      case PolygonTop(:final xy):
        final n = xy.length ~/ 2;
        final closed = Float64List(2 * (n + 1))
          ..setRange(0, 2 * n, xy)
          ..[2 * n] = xy[0]
          ..[2 * n + 1] = xy[1];
        final triangles = triangulateSimplePolygon(closed, n + 1);
        if (triangles.isEmpty) continue;
        out.add(PageUnderlayPolygon(
            placement: node.transform, argb: argb,
            xy: closed, count: n + 1, triangles: triangles));
      case CircleTop(:final cx, :final cy, :final r):
        out.add(PageUnderlayCircle(
            placement: node.transform, argb: argb, cx: cx, cy: cy, r: r));
      case null:
        break;
    }
  }
  return out;
}
```

  (Tables are root-level, `TableSurvey`'s rule, so `node.transform` is the
  world transform; the fill painter reads the same and calls `tableTopOf`
  the same way, `table_picker.dart:92`.)

- [ ] **Step 4: Thread the opacity.** `exportBytes` and `exportPdfBytes`
  pass `underlay: tableColorUnderlay(document, tableColorOpacity)` to
  `exportPagePdf` / `exportPagePng`; `exportOnce` and `printOnce` take
  `tableColorOpacity` and pass it on; `PageFlows` gains `final double
  Function() tableColorOpacity;` (default `() => kTableColorOpacity`, a
  top-level `_defaultOpacity`) and passes `tableColorOpacity()` in
  `export` and `print`; `_flowsFor` passes

```dart
        tableColorOpacity: () =>
            (Theme.of(context).extension<FloorPlanTheme>()?.merge(widget.theme) ??
                    widget.theme)
                ?.tableColorOpacity ??
            kTableColorOpacity,
```

  (the scope's own resolution, `FloorPlanThemeScope.build`, read at the
  call); `exportPlan` and `printPlan` validate a given opacity (finite,
  `0..1`, else `ArgumentError.value(opacity, 'tableColorOpacity', 'must
  be in [0, 1]')`) before `_pageFlow`, and pass `tableColorOpacity ??
  kTableColorOpacity`. Docs: each says where its opacity comes from.

- [ ] **Step 5: Run; pass**; then the planner (`--enable-vmservice`),
  `apps/floor_planner`, `apps/restaurant_demo`; analyze; format.

- [ ] **Step 6: The mutants:**
  - **M-C7** (floor plan) — the underlay's placement the identity
    (`placement: Transform2.identity()`). Killer: EX2.
  - **M-C8** (export) — the opacity ignored in the underlay (`alpha =
    255`). Killer: EX2, EX3.
  - **M-C23** — the view's Export passes the default
    (`tableColorOpacity()` not called; the constant passed). Killer: EX4.
  - **M-PC7-a** — a hidden table exported (the layer check removed).
    Killer: EX1, EX2.
  - **M-PC7-b** — `exportPlan` ignores its parameter. Killer: EX3.

- [ ] **Step 7: Commit** — `feat(floor-plan): export and print carry the
  table colours` (PC-7).
