# Plan colours, Slice 2: a table's colour — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A table takes a colour from the plan's palette — in the editor's
Colour row and through the host API — saved with the plan, drawn as a fill
under its drafting in both modes (a service status covers it), exported and
printed.

**Architecture:** The render package's page export gains an underlay of
filled shapes drawn before the document. The floor planner stores a
table's colour as a `jetcad.table_color` component on its instance (the
twin of `FloorPlanTableData`), draws it as the lowest rung of the existing
`TableStatusPainter` chain (now mounted in the design mode too, toned on a
dark canvas like a room's tint), builds the export underlay from the same
tops, and lists tables in the Colour row beside rooms.

**Tech stack:** Dart 3 / Flutter (`flutter`, `dart` on `PATH`), `package:test`,
`flutter_test`, the `pdf` package (already a dependency of
`jet_cad_2d_flutter`).

**Spec:** [2026-10-12-plan-colors-design.md](../specs/2026-10-12-plan-colors-design.md),
revision 2, approved 2026-10-12. **Slice 2** = PC-4, PC-5, PC-6, PC-7,
PC-9 (tables), PC-11, PC-12's Slice 2 part; facts F-3 to F-7, F-10, F-11,
F-14, F-16, F-17; mutants M-C1 (tables), M-C2, M-C5 to M-C9, M-C11,
M-C12 (tables), M-C14, M-C15, M-C18 to M-C21, M-C23 to M-C25. Slice 1
(the palette, schema 10, rooms, `recolor`, the Colour row) is merged at
`ce0a4f9`; its ledger is
`docs/superpowers/ledgers/2026-10-12-plan-colors-slice-1/`.

**Started** on the human's *"Dilim 2 ile devam et"* (2026-10-12).
**Branch:** `feat/plan-colors-slice-2` (worktree
`.claude/worktrees/plan-colors-2`), from `main` at `c429735`. **Ledger:**
`.superpowers/sdd/2026-10-12-plan-colors-slice-2/`, archived to
`docs/superpowers/ledgers/2026-10-12-plan-colors-slice-2/` as the branch's
last commit. **Release 0.6.0** follows this slice's merge, as its own
step (as 0.5.1 was).

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

## File structure

| File | Responsibility | Task |
|---|---|---|
| `packages/jet_cad_2d_flutter/lib/src/export/page_underlay.dart` | `PageUnderlayFill`, `PageUnderlayPolygon`, `PageUnderlayCircle`, `drawPageUnderlay` | 1 |
| `packages/jet_cad_2d_flutter/lib/src/export/page_export.dart` | `underlay` on `exportPagePdf` / `exportPagePng` | 1 |
| `packages/jet_cad_2d_flutter/test/export/page_underlay_test.dart` | PU1–PU5 | 1 |
| `packages/jet_cad_floor_plan/lib/src/tables/table_color_component.dart` | `FloorPlanTableColor` | 2 |
| `packages/jet_cad_floor_plan/lib/src/tables/table_index.dart` | `table.invalid_color` | 2 |
| `packages/jet_cad_floor_plan/lib/src/parametric/catalog.dart` | registration | 2 |
| `packages/jet_cad_floor_plan/lib/src/host/table_detail.dart` | `FloorPlanTableDetail.color` | 2 |
| `packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart` | `setTableColor`, `setTablesColor`, the shared path; `_detailsOf` | 2 |
| `packages/jet_cad_floor_plan/test/host/table_color_test.dart` | TC1–TC9 | 2 |
| `packages/jet_cad_floor_plan/lib/src/host/floor_plan_theme.dart` | `tableColorOpacity`, `kTableColorOpacity` | 3 |
| `packages/jet_cad_floor_plan/lib/src/service/table_status_painter.dart` | the colour rung, the survey always, `darkCanvas` | 3 |
| `packages/jet_cad_floor_plan/lib/src/host/service_view.dart` | passes `darkCanvas` | 3 |
| `packages/jet_cad_floor_plan/lib/src/planner_shell.dart` | the design-mode mount | 3 |
| `packages/jet_cad_floor_plan/test/service/table_fill_test.dart` | TF1–TF9 | 3 |
| `packages/jet_cad_floor_plan/lib/src/colors/table_color_underlay.dart` | `tableColorUnderlay` | 4 |
| `packages/jet_cad_floor_plan/lib/src/export/export_bytes.dart`, `host/page_flows.dart`, `host/floor_plan_view.dart`, `host/floor_plan_controller.dart` | the opacity threaded through | 4 |
| `packages/jet_cad_floor_plan/test/colors/table_color_export_test.dart` | EX1–EX5 | 4 |
| `packages/jet_cad_floor_plan/lib/src/colors/color_picker.dart` | tables in the row | 5 |
| `packages/jet_cad_floor_plan/test/colors/color_picker_test.dart` | CP7–CP10; CP1's Wall-tool leg | 5 |
| `docs/host-guide.md`, `tool/ci/host_probe/lib/main.dart`, `CHANGELOG.md`, `STATUS.md` | PC-12's Slice 2 part | 6 |

---

### Task 1: The page export's underlay (PC-7, render package)

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/export/page_underlay.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/export/page_export.dart` (`exportPagePdf` `:34-77`, `exportPagePng` `:104-150`)
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (export the new file)
- Create: `packages/jet_cad_2d_flutter/test/export/page_underlay_test.dart`

**Interfaces:**
- Produces (public, exported from `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`):

```dart
/// A fill under a page export's drawing (plan colours spec PC-7): a closed
/// shape in its own space, placed in world by [placement], in [argb]
/// (0xAARRGGBB, drawn as given).
@immutable
sealed class PageUnderlayFill {
  const PageUnderlayFill({required this.placement, required this.argb});
  final Transform2 placement;
  final int argb;
}

/// A closed polygon: [xy] interleaved x, y with the first point repeated as
/// the last; [count] the point count including that duplicate;
/// [triangles] its triangulation (`triangulateSimplePolygon`), never empty.
final class PageUnderlayPolygon extends PageUnderlayFill {
  PageUnderlayPolygon(
      {required super.placement, required super.argb,
       required this.xy, required this.count, required this.triangles});
  final Float64List xy;
  final int count;
  final Int32List triangles;
}

/// A circle of radius [r] about ([cx], [cy]).
final class PageUnderlayCircle extends PageUnderlayFill {
  const PageUnderlayCircle(
      {required super.placement, required super.argb,
       required this.cx, required this.cy, required this.r});
  final double cx, cy, r;
}

/// Draws [fills] in order through [sink] under [camera]: each under the
/// residual `camera.worldToScreenMatrix · placement`, as `DraftPainter`
/// draws a leaf.
void drawPageUnderlay(DrawSink sink, ViewportTransform camera,
    List<PageUnderlayFill> fills);
```

  `exportPagePdf({..., List<PageUnderlayFill> underlay = const []})` and
  `exportPagePng({..., List<PageUnderlayFill> underlay = const []})`.

- [ ] **Step 1: Write the failing tests** in
  `test/export/page_underlay_test.dart`. Read `test/export/export_png_test.dart`
  (`:40-70`) for how a PNG is decoded to RGBA and a pixel read, and
  `test/export/pdf_content_test.dart` / `lib/src/export/testing/pdf_content.dart`
  for `PdfContent.parse(bytes, inflate: zlib.decode)` and its `paths`
  (`fills`, `subpaths[].vertices`, `state.fillRgb`, `state.ctm`). Fixture:
  an empty `DraftDocument` with a `PageComponent` (A4 landscape, 1:50,
  white) and one LINE drawn across the polygon (so draw order is visible);
  the placement `T = translation(4000.5, 2500.25) · rotation(0.7) ·
  scale(1, -1)` (turned and mirrored); a polygon off-centre and
  asymmetric in its own space — the L-shape `(200,100) (900,100)
  (900,300) (450,300) (450,700) (200,700)` closed — and a circle
  `(600.5, -350.25, r 180)`; `argb` `0x9900897B` (teal at alpha 153) and
  `0x998E24AA` (purple). Tests:
  - **PU1** PNG: the pixel at the image of the L's local point `(300, 600)`
    (inside its tall arm, away from the line; compute it forward:
    `T.transformPoint`, then the page camera's `worldToScreenMatrix` —
    `pageCamera(page, dpi/25.4).camera`) is teal over white, per channel
    `round(153/255·s + (1−153/255)·255)` within ±2; the pixel at the image
    of `(800, 600)` (outside the L, inside its bounding box) is white; the
    pixel at the image of the circle's centre is purple over white; a
    pixel on the LINE where it crosses the L is the line's black (the
    underlay is under the drawing).
  - **PU2** PDF: `PdfContent.parse(...)`'s fill paths: the first two
    fills precede every stroke (`operatorIndex`), the first's vertices
    mapped through its `state.ctm` equal the PNG's device points of the
    L's six corners at 72/25.4 per mm (`closeTo` 1e-6 pt) in order, its
    `fillRgb` is teal's `[0, 0x89/255, 0x7B/255]`; the circle's path has
    cubic segments (`isCubic`), not a polygon.
  - **PU3** an empty `underlay` writes exactly the bytes the export wrote
    without the parameter (PDF with `compress: false`; PNG), for the same
    document.
  - **PU4** `PageUnderlayPolygon` with empty `triangles`, or `count * 2 >
    xy.length`, throws `ArgumentError` at construction.
  - **PU5** `drawPageUnderlay` on a `RecordingDrawSink` (from
    `package:jet_cad_2d_flutter/...` — read how `draft_painter_order_test`
    records ops) emits, per fill, `beginResidual(camera ·
    placement)`, then `fillPolygon(xy, count, triangles, style)` or
    `fillCircle(cx, cy, r, style)` with `style.argb == argb`, then
    `endResidual`, in the fills' order.

- [ ] **Step 2: Run them; see them fail** (`flutter test
  test/export/page_underlay_test.dart` in `packages/jet_cad_2d_flutter`):
  compile errors, the names do not exist.

- [ ] **Step 3: Implement `page_underlay.dart`** with the interface above.
  `drawPageUnderlay`:

```dart
void drawPageUnderlay(DrawSink sink, ViewportTransform camera,
    List<PageUnderlayFill> fills) {
  final world = camera.worldToScreenMatrix;
  for (final f in fills) {
    final style = ResolvedStyle(
        argb: f.argb,
        lineweightHundredths: 0,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1);
    sink.beginResidual(world.multiply(f.placement));
    switch (f) {
      case PageUnderlayPolygon(:final xy, :final count, :final triangles):
        sink.fillPolygon(xy, count, triangles, style);
      case PageUnderlayCircle(:final cx, :final cy, :final r):
        sink.fillCircle(cx, cy, r, style);
    }
    sink.endResidual();
  }
}
```

  `PageUnderlayPolygon`'s constructor throws `ArgumentError` for empty
  `triangles` or `count < 4` or `count * 2 > xy.length`. In
  `page_export.dart`, after the ground (PNG: after `drawPaint`; PDF: before
  `DraftPainter(...).paint`), inside `_withExportIndex`'s callback, call
  `drawPageUnderlay(sink, camera.camera, underlay)` when `underlay` is not
  empty, then the painter. Each function's doc gains a bullet: "[underlay]
  is drawn after the ground and before the document (plan colours spec
  PC-7); empty, the bytes are today's."

- [ ] **Step 4: Run; see them pass**; then the render package through the
  standing comparison, `flutter analyze`, format; `jet_cad_2d_gpu` and
  `jet_cad_floor_plan` (`--enable-vmservice`) green (they read the export).

- [ ] **Step 5: The mutants:**
  - **M-C7a** — the placement ignored (`sink.beginResidual(world)`).
    Killer: PU1, PU2, PU5.
  - **M-C7b** — the linear part ignored (`world.multiply(
    Transform2.translation(f.placement.e, f.placement.f))`). Killer: PU1
    (the L's arm is mirrored/turned away), PU2.
  - **M-PU-a** — the underlay drawn after the document. Killer: PU1's line
    pixel; PU2's operator order.
  - **M-PU-b** — the circle tessellated (`fillPolygon` of 64 points).
    Killer: PU2's `isCubic`.
  - **M-PU-c** — an empty underlay still touches the sink (`beginResidual`
    and `endResidual` always). Killer: PU3.

- [ ] **Step 6: Commit** — `feat(2d_flutter): a page export's underlay of
  fills under the drawing` (plan colours spec PC-7).

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

---

## Mutants per task

| Task | Mutants | Count |
|---|---|---|
| 1 | M-C7a, M-C7b, M-PU-a, M-PU-b, M-PU-c | 5 |
| 2 | M-C1 (tables), M-C2, M-C9, M-C11, M-C14, M-PC11-a, M-PC11-b | 7 |
| 3 | M-C5, M-C6, M-C8, M-C15, M-C18, M-C19, M-C20, M-C21, M-C24, M-C25, M-PC6 | 11 |
| 4 | M-C7 (floor plan), M-C8 (export), M-C23, M-PC7-a, M-PC7-b | 5 |
| 5 | M-C12 (tables), M-PC9-t, M-PC9-tool | 3 |
| 6 | — (`check_guide` covers the probe) | 0 |

## Exit gate

- Task 6's step 4 green: every gate, the standing sets exact, the host
  probe and the three old-host probes.
- Every named mutant above seen red and recorded (or, for M-C11 and
  M-PC9-tool, recorded with the reason it cannot be reached here).
- A whole-branch independent review, its fixes applied.
- The ledger archived to
  `docs/superpowers/ledgers/2026-10-12-plan-colors-slice-2/`.
- **Owed to the human:** a look at coloured tables (design and selection
  modes, light and dark canvas, an export and a print); the German and
  Turkish read already owed from Slice 1; the macOS fingerprint
  re-baseline.
- **The merge into `main` happens on the human's word**; release 0.6.0 is
  its own step after it.
