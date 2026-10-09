# Plan — host embedding API, Slice 4: the bars, the keyboard, the editor

**Spec:** [2026-10-09-host-embedding-api-design.md](../specs/2026-10-09-host-embedding-api-design.md),
revision 3 (`4f5c8fc`) as amended during Slices 1 to 3: the principles
P-1 to P-9 (above all **P-1**, *additive only*, **P-6**, *defaults are
today's look*, and P-4's frame path), the facts F-3, F-9, F-11, F-12 and
**F-15**, **Slice 4** (C-1 to C-8), the Invariants (1, 2, 5 and 7 above
all), the named mutants M-H40 to M-H47 with every sub-mutant inside
M-H41, M-H43 and M-H47, the Risks (**R-1**, **R-4**), the Review's rulings
V-5, V-6, V-7 and V-8, and Slice 3's S-10 (the selection canvas
re-measured after a bar-height change). The points this plan found the
code to contradict, or to leave open, are under
[Spec points to settle](#spec-points-to-settle); none changes the design
silently.

**Started** on the human's *"tamam, Dilim 4 ile devam et"* (2026-10-09),
after Slice 3 merged into `main`. Slice 4 is the chrome a host may keep,
reorder, extend or replace: jet-cad's two bars with host items added or
built-ins hidden; every command and its state on the controller for a
host that builds its own bar; the export dialog as a hook; the editor's
capabilities (`full`, `tablesOnly`, `readOnly`), enforced on **every**
edit path; a table inspector slot; and the keyboard and focus given back
to the host.

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `4e3ed91`
(Slice 3 merged at `d26c9fe`, plus its docs commit), plus this plan's
commit. Verified against `6fb7a6d`; Slice 3's final fixes after it
(`237a28e`, `9eb8434`) touched tests and docs only, so the *Verified*
lines hold; a task that finds one moved re-reads it and says so.

**Ledger:** `.superpowers/sdd/2026-10-09-host-embedding-api/`: this
slice's briefs, reports and reviews as `s4-task-<n>-report.md` /
`s4-task-<n>-review.md`, beside Slices 1 to 3's.

**No schema change.** Nothing of Slice 4 is stored: plans, service
layouts, the codec and the bundled encodings are untouched; capabilities,
bars, shortcuts and the remembered export choice never reach
`designJson`, the service layout, an export or a print (P-5, invariant 4).

**Seven tasks, not six.** The suggested split put the capabilities type
and the shell's enforcement in one task and the select tool's gates in
another. The code shows a better seam on each side: (1) the select tool's
gates, the grip cache's and the canvas's `autofocus` are the slice's only
edits of `jet_cad_2d_flutter`, a generic seam with its own killers at the
render level, so they land first and alone (Task 3, as Slice 3's Task 2
held every render edit); (2) the editor's enforcement then splits along
the shell's own seam: the **tools** (palette rows, letters, Fill, the
symbol tool and its keys, the Symbols tab and its filter, the bar's
items, `activeTool` / `selectTool`, the left column, the runtime
fallback; Task 4) and the **select tool and the panels** (the gates wired
to `selectTablesOnly`, move, rotate, reshape, delete; every Selection
panel field, the layer picker, the Layer and Page panels, the right
column, C-8; Task 5). One task for both would touch fourteen files and
carry nine named mutants. And the export types sit with the export flows
(Task 1), not with the bars: `exportPlan`, `printPlan`,
`onPageFlowError` and `onExportDialog` all live in `page_flows.dart`'s
one body.

## Global constraints

- `CLAUDE.md`'s non-negotiables. **The two allocation invariants**
  (`query_allocation_test`, `paint_allocation_test`), the floor-plan
  painters' counter tests (`table_status_painter_test` SP1,
  `table_group_painter_test` TG-L9, `table_focus_painter_test` FP3 and
  their themed siblings in `table_theme_painter_test`),
  `RenderFloorPlanOverlays`' counter tests (`table_overlay_test` TO2,
  TO10, TO21), the pick's allocation test (`invariants/pick_allocation_test`
  PA1–PA3), the selection overlay's reuse tests (`selection_overlay_test.dart:320`;
  `selection_overlay_grips_test.dart:91, :185`, one `drawRawPoints` per
  colour and the stretch buffer reallocated only on a count change)
  **and every image golden stay untouched** (invariant 7). The engine
  (`jet_cad_2d`) is **not edited**; `jet_cad_2d_flutter` is edited **only**
  in Task 3 (`SelectGates`, `SelectTool.gates`, `GripCache.gates`,
  `InteractionLayer.autofocus`).
- **P-1 and P-6:** no existing signature, `==`, `hashCode` or `toString`
  changes; every new parameter is named and optional with today's
  behaviour as its default. **With no new parameter, every code path is
  today's, structurally**: the bars are built from today's widgets in
  today's order, `editorCapabilities` is `full` and every gate reads
  *allowed*, `shortcuts` and `autofocus` are true. **Existing tests pass
  unedited**, with these named exceptions and nothing else:
  - **Tasks 1, 2 and 4:** `test/host/barrel_test.dart`'s B1 (`:29-72`)
    gains the task's new names (3, 4 and 3), as Slices 1 to 3's tasks
    did.

  Any other test that has to change is a finding for the task's report.
  The tests that read today's chrome or behaviour, and must therefore pass
  unedited, are named in each task.
- **No widened record, no required parameter.** `PageFlowSettings`
  (`host/page_flows.dart:17-21`) is built by literal in view_test V11
  (`test/host/view_test.dart:595-598`); `ServiceCallbacks`,
  `ServiceOptions` and `ServiceEvents` are built by literal in their own
  tests (Slice 2's rule). New view inputs travel in **new** internal
  records or parameters behind optional constructor parameters. Every new
  parameter of an internal widget, tool or cache is **optional**, because
  tests build them directly (`grep -rln -F` at `6fb7a6d`): `PlannerShell(`
  38 files (and `apps/floor_planner/lib/document_host.dart:684`),
  `SelectTool(` 27, `GripCache(` 8, `InteractionLayer(` 9,
  `SelectionPanel(` 6, `PagePanel(` 4, `LayerPanel(` 3, `SymbolPanel(` 3,
  `PlannerView(` 3, `ToolPalette(` 2, `DocumentToolbar(` 2,
  `ServiceView(` 2.
- **The standing sets stay exactly as they are:** engine 2, render 7 plus
  1 skip (`tool/ci/standing_failures.txt`, `standing_skips.txt`), compared
  by the path form, as CI does (`.github/workflows/ci.yml:69-73`):
  `dart run tool/ci/expect_failures.dart --package packages/<pkg> --root packages/<pkg> <run.json>`,
  the run from `test --file-reporter json:<run.json>`. **The planner runs
  as CI runs it**, `flutter test --enable-vmservice` (`ci.yml:43-49, 68`;
  the Slice 2 results note), so the pick's allocation test runs; a plain
  `flutter test` there shows its three skips, which the comparison reads
  as red.
- **Every task ends green** in every package it touches and every package
  whose tests read what it changed:
  - `packages/jet_cad_floor_plan` (with `--enable-vmservice`, through the
    standing comparison), `apps/restaurant_demo`, `apps/floor_planner`:
    `flutter test`, `flutter analyze`, format;
  - `packages/jet_cad_2d_flutter` (`flutter test` through the standing
    comparison, `flutter analyze`, format) and `packages/jet_cad_2d_gpu`
    (`flutter test` through the standing comparison, analyze) in Task 3;
  - `packages/jet_cad_2d` through the standing comparison at the exit;
  - `tool/ci`: `dart test`, analyze, format and `check_guide` whenever the
    guide or the probe moves (Task 7).
- **Flutter** is `/root/sdk/flutter/bin` (3.47.6, not on `PATH`), run with
  `CI=true`. **Scratch runners** (a mutant's copy, a characterization
  script, a JSON run) live in a per-agent directory under the agent's own
  scratchpad, never in the worktree.
- **Fixtures** (spec's testing rule; CLAUDE.md's testing bar):
  - Slice 1's `test/host/embedding_fixture.dart` (turned, mirrored,
    non-uniformly scaled tables 40 m off the origin, the off-base box, `5`
    on a hidden and `L` on a locked layer, `7` and ` 7 ` sharing a number,
    an unnumbered table, `9` with no finite corner, `embeddingCamera()` at
    0.37 px/mm, panned) for the bars, the flows and the selection mode;
  - **the editor fixture**, `test/host/editor_fixture.dart`, built in Task
    4 and read by Tasks 4 to 6: the startup flat (`startupPlan`: walls,
    openings, a separator, rooms with their labels, dimensions, a page);
    inside its living room two tables `1` (turned 30°) and `2` (mirrored
    at 90°) beside a wall, and the embedding fixture's `7` / ` 7 `, the
    unnumbered table, `5` (hidden layer) and `L` (locked layer); a
    root-level **group** of two lines; a free line; a TEXT; a **chair**, a
    non-table furniture symbol; and `editorCamera()`, panned so the flat is
    on screen at 0.37 px/mm, y up, never the identity. Tests compute screen
    points by the camera's forward transform (`canvasOf`'s form), never
    from the code under test;
  - **both modes** wherever a feature reaches both (the bars, the flows,
    the dialog hook, `shortcuts`, `autofocus`), and a check that what is
    the editor's alone (capabilities, the inspector) leaves the selection
    mode as it is;
  - **values that are not the default shape:** action lists in an order
    that is not the enum's and with a gap (`[print, undo]`, `[redo, undo,
    zoom, snap]`), leading and trailing widgets of different widths, an
    export choice that is not the initial one (PNG at 300 dpi; PNG at 96),
    a capabilities value that is not a profile (`full.copyWith(reshape:
    false)`, `full.copyWith(export: false, undo: false)`), a symbol filter
    that is not the tables' (one key).
- **Each named mutant is applied, seen red and reverted**, its killer
  named in the report (Ruling 49/50). Every Slice 4 mutant below belongs
  to exactly one task; the task-local mutants (T*n*-x) are this plan's
  own, listed so a review can hold the killers to them.
- **Never `git checkout` a file to revert it.** Copy it aside, or use
  `git show HEAD:path > path`.
- **Never commit an `analysis_options.yaml`.** Check `git status` before
  each commit.
- New public names enter `lib/jet_cad_floor_plan.dart`'s `show` lists and
  `test/host/barrel_test.dart` in the task that adds them; P-9's prefix,
  `final class` with `==`/`hashCode`/`toString` for value types. Slice 4
  adds ten host names: `FloorPlanExportChoice`, `FloorPlanExportFormat`,
  `FloorPlanExportDpi` (Task 1); `FloorPlanServiceBar`,
  `FloorPlanServiceAction`, `FloorPlanEditorBar`, `FloorPlanEditorAction`
  (Task 2); `FloorPlanEditorCapabilities`, `FloorPlanSymbol`,
  `FloorPlanTool` (Task 4). Eight view parameters (`onExportDialog`,
  `onPageFlowError`, `serviceBar`, `editorBar`, `editorCapabilities`,
  `tableInspectorBuilder`, `shortcuts`, `autofocus`) and six controller
  members (`exportPlan`, `printPlan`, `mergeCandidate`, `activeTool`,
  `selectTool`, `editorSelectedTables`). Nothing else enters (R-1). No
  colour literal enters a scanned `lib` (`theme_colours_test`).

## Tasks

### Task 1 — the page flows without their dialogs (C-3's export and print, C-4, `onPageFlowError`)

**Verified:**
- `ExportChoice` is `{format: ExportFormat, dpi: ExportDpi}`
  (`export/export_dialog.dart:10, 15-37`, `initial` PDF 150 at `:19`);
  `ExportDpi` is the render package's (`jet_cad_2d_flutter`
  `export/page_export.dart:72-83`). Both reach editor code through
  `lib/editor.dart:9` and `apps/floor_planner` uses them
  (`lib/document_host.dart:295, 587`; `lib/export/export_flow.dart:20-28`;
  `test/export/export_flow_test.dart:224-255, 479-486`): neither may
  change (P-1), so the public types are **new** and mapped internally
  (V-6).
- `PageFlows` (`host/page_flows.dart:25-95`): `export` (`:42-63`) asks
  `showExportDialog` (`:48`), remembers the answer in
  `controller.exportChoice` (`:50`; `floor_plan_controller.dart:313`),
  checks `identical(document, controller.activeDocument)` after each
  await (`:51, :54`); `print` (`:65-77`); `_run` (`:79-89`) is the
  one-at-a-time guard (`_ready`), settles first and has a `try/finally`
  with **no `catch`**: a failure is an error of a `Future` every caller
  drops (`ShellCommand.invoke`'s `unawaited`, `shell_commands.dart:115-118`;
  the service bar's and chords' closures, `service_view.dart:475-477,
  :512, :519`). The host never hears it (C-3's "lost").
- **Every Export entry point of a `FloorPlanView`**, all through
  `PageFlows.export`: the service bar's button (`service_view.dart:507-513`),
  the service chords (`:475-476`), and the design mode's file command the
  view builds (`floor_plan_view.dart:319-327`), which the shell shows
  (`planner_shell.dart:932-933`) and binds (`:901-902`). No other
  (`grep -rn "flows.export\|showExportDialog" lib`).
- Export's chord is **Cmd/Ctrl+E** (`shell_commands.dart:31`); no
  Ctrl+Shift+E is bound anywhere: see [S-1](#spec-points-to-settle).
- `PageFlowSettings` is a three-field record that view_test V11 builds by
  literal (`test/host/view_test.dart:595-598`).
- The bytes: `exportPageOf`, `exportBytes`, `exportPdfBytes`,
  `printPageFormat` (`export/export_bytes.dart:19, 32-50, 52, 63`); the
  font through `controller.exportFont` (`floor_plan_controller.dart:311`).
- The view makes one `PageFlows` per controller (`floor_plan_view.dart:197,
  256-263, 275-282`).

**Builds:**
- `host/floor_plan_types.dart`, beside `FloorPlanExport`:
  `enum FloorPlanExportFormat { pdf, png }`; `enum FloorPlanExportDpi {
  d96, d150, d300 }` with `int get value`; `final class
  FloorPlanExportChoice` (`const` constructor of `format` and `dpi`,
  `static const initial` PDF at 150 dpi, `copyWith`, `==`, `hashCode`,
  `toString` `FloorPlanExportChoice(pdf, 150 dpi)`), documented as
  today's dialog's answer made public.
- `host/page_flows.dart`:
  - internal `toExportChoice` / `fromExportChoice`, exhaustive `switch`es
    (never by index);
  - **one body per flow**, `exportOnce(controller, choice, name)` →
    `FloorPlanExport?` and `printOnce(controller, printer, name)` → `bool`:
    the page, the bytes, the two `identical` checks; `PageFlows` and the
    controller both call them;
  - `PageFlows({…, this.hooks = _noHooks, ValueNotifier<bool>? ready})`:
    `hooks` returns an internal record `PageFlowHooks = ({exportDialog,
    onError})`, read at each call; `ready`, when given, is the guard
    (the controller's, S-7), else the flows' own (V11's construction);
  - `export`: `hooks().exportDialog` when given, else today's
    `showExportDialog`, either way from `controller.exportChoice` and
    remembered into it; null cancels;
  - `_run`: with `hooks().onError`, an error of the flow (the hook's
    included) is reported there and the flow ends normally; without one
    it propagates as today (S-8). The guard is restored either way.
- `FloorPlanController`: an internal `pageFlowReady` guard; `Future<
  FloorPlanExport?> exportPlan(FloorPlanExportChoice choice, {String name =
  'plan'})` and `Future<bool> printPlan({PagePrinter? printer, String name
  = 'plan'})` (default `PrintingPagePrinter`): the guard, `settle()`, the
  bodies; null / false when a flow runs, with no page, when the plan
  shown was replaced meanwhile, or after `dispose()`; an error completes
  the `Future` with it (the host's call, S-7); `exportChoice` untouched;
  allowed under every capability (V-5).
- `FloorPlanView`: `onExportDialog: Future<FloorPlanExportChoice?>
  Function(BuildContext context, FloorPlanExportChoice initial)?` and
  `onPageFlowError: void Function(Object error)?`, documented with C-4's
  and C-3's sentences; `_flowsFor` passes `hooks` reading the current
  widget (R-5) and the controller's guard.
- Barrel: the three names; B1 gains them.

**Tests** (`test/host/page_flows_test.dart`, on `embeddingPlanJson` under
`embeddingCamera()`, both modes; a recording hook; `FakePrinter`
(`test/support/fake_page_printer.dart`) and a printer that throws):
**M-H46**, **T1-a** to **T1-f** (below). Plain:
- the three types through the barrel alone; `==`, `hashCode`, `copyWith`
  and `toString` (each field changed alone makes `!=`);
  `FloorPlanExportDpi.values.map((d) => d.value)` is `[96, 150, 300]`;
- `exportPlan(png at 96)` in each mode: `image/png`, `plan.png`, the
  pixel size of the page at 96 dpi computed by the test
  (`round(effW / 25.4 · 96)`); in the selection mode the copy's moved
  table is in the bytes (V5's reading); `exportPlan` with a plan without
  a page → null; `printPlan` → the printer's one call with `name` and the
  page's format;
- `exportPlan` and `printPlan` with no view mounted act (they need no
  context);
- without `onExportDialog` the Material dialog still opens from every
  entry point (V1, V5, V11 unedited, and a check of the design chord).

**Unedited and green (P-1, P-6):** `test/host/view_test.dart` (V1, V2,
V5, V9–V11, V13), `test/host/floor_plan_theme_test.dart` (the dialog
under a local `Theme`), `test/widget_theme_test.dart`,
`test/l10n/leak_test.dart`, `test/host/theme_canvas_test.dart`;
`apps/floor_planner`'s `test/export/export_flow_test.dart`,
`print_flow_test.dart`, `export_end_to_end_test.dart`; the demo's tests.

**Gates:** planner (`--enable-vmservice`, standing comparison, analyze,
format), demo, floor planner.

### Task 2 — the two bars, `mergeCandidate`, an idle Undo, and the canvas re-measured (C-1, C-2, C-3's merge and Undo)

**Verified:**
- **The service bar** (`host/service_view.dart:483-522`): `service-bar`,
  `_barHeightNow()` (`:333-353`, S-10), Undo, Redo, 8 px, Merge and Split
  only with their callbacks (`:498-503`), 8 px when either shows
  (`:504-506`), Export only with `onExport` (`:507-513`), Print
  (`:514-519`); buttons keyed `service-<id>`. Its chords are always bound
  (`:471-478`).
- **The editor's top bar** (`planner_shell.dart:918-988`): 44 px
  `chrome-top`; `DocumentToolbar` (`:932-933`; `document_toolbar.dart:41-48`):
  the file commands in the order given (the view's Export, Print), a 12 px
  `groupGap` (`:32`), Undo, Redo; 16 px; the document name (null under a
  view) and the status line `status-text` (`:947-965`); OSNAP `osnap-text`
  (`:971-978`); 16 px; the zoom read-out `zoom-text` (`:980-984`), the one
  widget pan and zoom rebuild (P-4). **Today's left-to-right order is
  export, print, undo, redo, snap, zoom**: see [S-2](#spec-points-to-settle).
- **The shell's file commands are fixed at its creation**
  (`planner_shell.dart:580-602`): a command the view leaves out of the
  first build never shows. So the bar may *hide* a command at the
  shell's build; it must never be done by the view omitting it.
- **R-13:** the seeds (`floor_plan_controller.dart:45-49`: the editor's
  `(240 + ruler, 44 + ruler)`, the service's `(0, 44)`), each plan
  measured once after its first frame (`floor_plan_view.dart:205-214`),
  S-10's re-measure for the service bar's height only (`:220-225`;
  `service_view.dart:333-353`); `canvasMeasured` stores a re-measured
  origin and corrects only an assumed one (`floor_plan_controller.dart:724-730`).
  A runtime change of either bar's visibility, with the plan unchanged,
  is measured by nothing today.
- **Merge:** the button's flag is `mergeQualifies(selectedTables,
  tableGroups)` (`service_view.dart:371-372`; `service/table_groups.dart:165-181`:
  one table, two tables sharing a number and exactly one group do not
  qualify) and it sends `selectedTables` (`service_view.dart:615-616`).
  The controller refreshes `selectedGroup` after `selectedTables`
  (`floor_plan_controller.dart:1510-1536`) and on `setTableGroups`
  (`:501-505`).
- **Undo:** `undo()` / `redo()` settle and act (`floor_plan_controller.dart:1047-1059`);
  the shell's buttons wait for an idle tool (`planner_shell.dart:562,
  568-571`); the controller does not: see [S-4](#spec-points-to-settle).
  The controller already registers the shell's settle (`:804-814`).
- A host widget in the editor's bar would sit under the shell's
  `CallbackShortcuts` (`planner_shell.dart:897-915`), which take a text
  field's keystrokes; `ShellShortcutGuard` (`shortcut_guard.dart:47-63`)
  is the existing answer. The service's chords likewise.

**Builds:**
- `lib/src/host/bars.dart`: `enum FloorPlanServiceAction { undo, redo,
  merge, split, export, print }` and `enum FloorPlanEditorAction { export,
  print, undo, redo, snap, zoom }`, each declared in **today's
  left-to-right order** (S-2); `final class FloorPlanServiceBar` and
  `final class FloorPlanEditorBar` as C-1 and C-2 write them (`visible =
  true`, `actions = …values`, `leading`, `trailing = const []`), `==` and
  `hashCode` (`listEquals` of the actions and of the widgets), `toString`
  naming what differs from the default; an internal `validateBars`
  (an `ArgumentError` naming `actions` for a repeated action), called at
  build as `validateOverlayLayout` is (`floor_plan_view.dart:350-352`).
- **The service bar** (`ServiceView`, an optional `bar`): none with
  `visible: false` (the canvas takes the height); else `leading`, the
  actions in the given order under today's rules (merge and split need
  their callbacks, export needs `onExport`), **8 px between two shown
  actions of different groups** (history: undo, redo; groups: merge,
  split; page: export, print), `trailing`. The default reproduces today's
  row exactly. The bar's height logic (`_barHeightNow`, S-10) runs only
  while it is visible.
- **The editor's bar** (`PlannerShell`, an optional `editorBar`): none
  with `visible: false`; else `leading`, the **buttons** in the given
  order (a bare shell's other file commands, New to Save As, first, as
  today), **12 px between a file button and an edit button**, 16 px, the
  status line (flexible, today's), the **read-outs** (`snap`, `zoom`) in
  the given order with today's 16 px, `trailing` (S-2). `DocumentToolbar`
  takes an optional list of groups in place of its two lists (today's
  call is two groups).
- **Host widgets** in either bar sit inside a `ShellShortcutGuard`, never
  inside the toolbar's `ExcludeFocus`, so a host field takes focus and
  its keystrokes (S-19).
- **The chords stay** whatever `actions` says: they follow `shortcuts`
  (Task 6) and the capabilities (Task 4), never the bar (S-20).
- **R-13, generalized:** `FloorPlanView` keeps the chrome inputs it last
  built with (now `serviceBar.visible`, `editorBar.visible`; Task 4 adds
  the capabilities' rulers and left column) and, after the first frame
  built with different ones, re-measures the **shown** mode's canvas
  (S-10's `_serviceCanvasMoved` becomes `_canvasMoved()` for either
  mode). S-10's own trigger (the theme's bar height) stays.
- **`mergeCandidate`** (`ValueListenable<Set<String>?>`): in the
  selection mode an unmodifiable copy of `selectedTables` when
  `mergeQualifies`, else null; null in the design mode (S-5); set in
  `_refreshSelectedGroup`, so a selection change and `setTableGroups`
  both move it; notifies only on a change. The service bar's Merge flag
  reads it: one source.
- **An idle Undo:** the shell registers an idle probe with the controller
  beside its settle (`registerIdle`, internal); in the design mode
  `undo()` and `redo()` do nothing while the editor's tool is part-way
  through a shape; `canUndo` / `canRedo` keep their meaning (S-4).
- `FloorPlanView`: `serviceBar`, `editorBar`, documented; passed to the
  two modes. Barrel: the four names; B1 gains them.

**Tests** (`test/host/bars_test.dart`, on `embeddingPlanJson` under
`embeddingCamera()`, both modes): **M-H40, M-H44, M-H47(serviceBar)**,
**T2-a** to **T2-f** (below). Plain:
- a **characterization test written first and run green on the base**:
  with no bar given, every button's and read-out's left edge in both bars,
  with and without `onExport`, with and without Merge and Split; then
  green unchanged after the task;
- `visible: false` in each mode: no bar; the canvas origin is the view's
  top; the editor's tools stay in the left panel;
- `leading` and `trailing` in both bars: their widgets present, in place,
  at the bar's height; both bars' widgets reach the host's own state;
- the three types' `==`, `hashCode`, `toString`; a repeated action is an
  `ArgumentError` naming `actions`;
- `mergeCandidate` through the barrel, its notifications counted (one per
  change, none for an equal set).

**Unedited and green (P-6):** `test/host/view_test.dart` (V1, V6, V7a–V7h,
V8, V13, V18), `test/host/table_groups_toolbar_test.dart`,
`test/host/theme_service_test.dart` (the 60 px bar, T3-d),
`test/host/view_events_test.dart` (`:408`), `test/host/floor_plan_theme_test.dart`,
`test/planner_shell_test.dart`, `test/dimension_shell_test.dart`,
`test/planner_draw_test.dart`, `test/planner_grips_test.dart`,
`test/room_grips_test.dart`, `test/wall_tool_test.dart`,
`test/l10n/shell_words_test.dart`, `overflow_test.dart`, `leak_test.dart`,
`test/host/controller_test.dart`, `test/host/table_groups_controller_test.dart`,
`test/host/camera_test.dart`; `apps/floor_planner`'s
`document_host_test.dart`, `document_commands_test.dart`,
`document_open_test.dart`, `document_exit_test.dart`, `app_words_test.dart`;
the demo's tests.

**Gates:** planner (`--enable-vmservice`, standing comparison, analyze,
format), demo, floor planner.

### Task 3 — the select tool's gates and the canvas's `autofocus` (`jet_cad_2d_flutter`)

**Verified:**
- **`SelectTool` has no gate seam** (F-15): the pick
  (`select_tool.dart:139-148`) is the index's topmost hit
  (`jet_cad_2d` `spatial_index.dart:793`) resolved to a key; the press
  classes (`:165-202`); the hover and its cursors (`:229-257`, the move
  cursor by `movableKey`, `:246-250`); the drags at the slop
  (`:261-343`): a body (selected or not) moves, a **`GripRole.move`
  (centre) grip moves the whole selection** (`:311-312`, Ruling 03-9),
  any other grip reshapes, through an object provider or a leaf
  (`:313-316`), the rotation grip rotates (`:325-341`); each refused only
  by `DraftPermissions` (`_permitted`, `:365-366`); the up executes one
  command (`:470-496`); the band's keys (`:510-542`); the idle keys,
  Escape clearing the selection (`:655-658`) and Delete/Backspace
  (`:659-664`, `_deleteSelection` `:673-735`); every key during a drag is
  the drag's (`:643-652`).
- **`GripCache`** (`grip_cache.dart`): leaf grips live under `geometry`
  (`leafGripsLive`, `:276-277`), read live, "a permission change is not
  notified" (Ruling 03-5); `hitTest` (`:285-313`); `rotatable`
  (`:257`), `hitsRotationGrip` and `rotationGripDistance` (`:317-326`); a
  table instance has no grip but the rotation grip (`:367-383`). The
  overlay paints them per frame from `leafGripsLive`, the role and
  `rotatable` (`selection_overlay.dart:257-302`) into buffers sized by
  `stretchCount` / `moveCount` (`:261-266`); the cache is in the overlay's
  repaint merge (`planner_view.dart:178-184`).
- **`InteractionLayer`**'s `Focus` is `autofocus: true`, hard-coded
  (`interaction_layer.dart:482-485`); it requests focus on a pointer down
  (`:244, :307, :373, :397`), never on a tool change. Its constructor takes
  `tools` and `child` only (`:81-85`). F-9 reads otherwise: see
  [S-21](#spec-points-to-settle).

**Builds** (render package only):
- `lib/src/select_gates.dart`, exported by the barrel: `class SelectGates`
  with a `const` constructor and `static const SelectGates all`, every
  member allowing by default, **read at each press, hover, key and frame,
  never captured**:
  - `bool get restrictsPick` (false) and `SelectionKey? pick(ToolPointerEvent
    e, ToolContext ctx)`: when `restrictsPick`, the tool's pick for
    presses **and** hovers;
  - `bool bandAccepts(DraftDocument d, SelectionKey key)` (true): a band
    selects only the keys it accepts;
  - `bool get move`, `rotate`, `reshape`, `delete` (true);
  - `bool get idleKeys` (true): whether the tool's own keys act while no
    gesture runs (Escape, Delete, Backspace; S-16).
- `SelectTool({this.moveResolver, this.gates})`: the pick through the
  gates; the move cursor only under `move`; at the slop a body or centre
  grip drag needs `move`, another grip `reshape`, the rotation grip
  `rotate`, else the press stays a click (`_clickOnly`, as a refused
  permission does); **at the up the drag's gate is read again**, and a
  drag whose gate closed meanwhile is cancelled, no command (S-9h);
  `_bandKeys` filtered by `bandAccepts`; idle Escape and Delete/Backspace
  return `ignored` without `idleKeys`, Delete/Backspace also without
  `delete`; a drag's keys unchanged.
- `GripCache(…, {this.objects, this.gates})`: `hitTest` skips a grip whose
  role's gate is closed (`move` for `GripRole.move`, `reshape` for the
  others); `rotatable` also needs `rotate`; two getters `moveGripsLive`
  and `stretchGripsLive`, which the overlay's `_paintGrips` reads to skip
  a closed role's points **without reallocating its buffer** (and the hot
  grip only when its role is live); `gatesChanged()` resets `hot` and
  notifies, for a host's runtime change.
- `InteractionLayer({…, this.autofocus = true})`, passed to its `Focus`;
  the pointer-down requests unchanged.

**Tests** (render `test/select_gates_test.dart`, on `support/selection_fixture.dart`
and `support/grip_fixture.dart`: a line, an arc, a root group and two
instances off the origin, under the rotated, non-uniform camera of
`selection_overlay_test.dart:413`; a test gates class with mutable
fields): **T3-a** to **T3-j** (below). Plain:
- `SelectGates.all` and a null `gates` behave as today across a press, a
  band, every drag kind, Escape and Delete (the existing suites unedited
  already say so; one test runs a band and each drag kind under `all`
  and under `null` and compares the documents byte for byte);
- a gate change is read at the next press with no rebuild of anything.

**Unedited and green:** render `test/select_tool_test.dart`,
`select_tool_drag_test.dart`, `select_tool_touch_test.dart`,
`select_tool_move_resolver_test.dart`, `grip_cache_test.dart`,
`grip_drag_test.dart`, `object_grips_test.dart`,
`selection_overlay_test.dart`, `selection_overlay_grips_test.dart`,
`selection_theme_test.dart`, `interaction_layer_test.dart`,
`interaction_layer_touch_test.dart`, `interaction_layer_time_stamp_test.dart`,
`interaction_cursor_test.dart`, `input_claim_test.dart`,
`tool_controller_test.dart`, `test/draw/*`, `test/invariants/*`,
`test/golden/*`; planner `test/planner_grips_test.dart`,
`wall_grips_test.dart`, `room_grips_test.dart`, `dimension_grips_test.dart`,
`opening_grips_test.dart`, `symbols/symbol_move_test.dart`,
`symbols/wall_attach_test.dart`, `touch_tools_test.dart`, `layers/*`.

**Gates:** **`jet_cad_2d_flutter` in full** (`flutter test` through the
standing comparison, `flutter analyze`, format); `jet_cad_2d_gpu`
(`flutter test` through the standing comparison, analyze); planner
(`--enable-vmservice`, standing comparison, analyze, format); demo;
floor planner.

### Task 4 — capabilities I: the type, the tools and the Symbols tab (C-5's tools, palette and filter; C-3's `activeTool` / `selectTool`; the bar's flags; a runtime change)

**Verified:**
- **The tools** (`planner_shell.dart:390-496`): fifteen palette entries,
  each with a letter (Select V, Line L, Polyline P, Rectangle R, Box B,
  Wall W, Door D, Window N, Gap G, Room M, Separator S, Dimension I,
  Circle C, Arc A, Text T), and the symbol placement tool, armed by the
  Symbols tab, with no letter (`:359-370`, `:692-695`). **One choke
  point**, `_activate` (`:682-687`), for a palette tap
  (`tool_palette.dart:65-73`), a letter (`planner_shell.dart:907-909`) and
  an arming; Escape back to select (`:698-700`, `:914`). Every letter is
  bound whatever is allowed; the guard's letter list
  (`shortcut_guard.dart:7-24`).
- **Fill** is shared by Polyline, Rectangle and Circle
  (`planner_shell.dart:327-328, :355`): the row `tool-fill`
  (`tool_palette.dart:75-83`) and F (`planner_shell.dart:910-913`).
- **The symbol tool's own keys:** R and Shift+R turn and M mirrors the
  next placement while armed (`symbols/symbol_place_tool.dart:384-399`),
  an edit path F-15 does not list: [S-9](#spec-points-to-settle) (b).
- **The Symbols tab** (`planner_shell.dart:842-888`), present with a
  loader, which a view always gives (`floor_plan_view.dart:416`): the
  panel searches `library.entries` (`symbol_panel.dart:217`) and resolves
  a tap by id over every entry (`:174-182`); enabled by the placement's
  permissions (`:192`). `SymbolEntry` carries `key`, `name`, `category`,
  `tags`, `seats` (`symbol_library.dart:40-67`).
- **The bar's commands:** the view's Export and Print, fixed at the
  shell's creation (`:580-602`, Task 2's note); Undo and Redo the shell's
  own (`:609-626`), bound with the file chords (`:901-902`).
- **Rulers and grid:** `PlannerView(rulers:, grid:)` (`planner_view.dart:135-140,
  :329, :401`); the design canvas's origin includes the rulers
  (`floor_plan_controller.dart:45-47`).
- **Snap:** `SnapSettings` (`jet_cad_2d_flutter` `snap_settings.dart:5-15`,
  a concrete `ChangeNotifier`), the shell's own under a view
  (`planner_shell.dart:742-743`); F3 (`:904-905`); OSNAP (`:971-978`); the
  tools read `ctx.snap?.objectSnap` (`select_tool.dart:431`).
- **No controller seam for the editor's tool:** the tools are the
  shell's, and the shell is keyed by the document
  (`floor_plan_view.dart:401-419`).
- **F-12:** `CommandDispatcher.permissions` is a **mutable** field
  (`jet_cad_2d` `undo.dart:107`), not fixed at construction; V-5's ruling
  stands on its other ground: see [S-24](#spec-points-to-settle).

**Builds:**
- `lib/src/host/editor_capabilities.dart`:
  - `enum FloorPlanTool { select, line, polyline, rectangle, box, wall,
    door, window, gap, room, separator, dimension, circle, arc, text,
    symbol }`: the palette's order, then the symbol tool (S-6);
  - `final class FloorPlanSymbol` (`key`, `name` — the library's, S-23 —
    `category`, `tags` unmodifiable, `seats`; `const` constructor; `==`,
    `hashCode`, `toString`), and internally `FloorPlanSymbol.of(SymbolEntry)`;
  - `final class FloorPlanEditorCapabilities`: C-5's twenty-two fields;
    a `const` constructor whose defaults are `full`; `static const full,
    tablesOnly, readOnly` with every field as [S-12](#spec-points-to-settle)
    lists; `copyWith` (a null argument keeps the field); `==` and
    `hashCode` over every field (`symbolFilter` by `==`, a closure's
    identity, a method tear-off's receiver and name); `toString` naming
    the fields that differ from `full`;
  - internal `validateEditorCapabilities`: `tools` must hold `select`, an
    `ArgumentError` naming `tools`, at build.
- `PlannerShell`, an optional `capabilities` (`full`):
  - `_activate` refuses a tool outside `tools` (returns false); the
    palette shows only the allowed rows; **only the allowed letters are
    bound** (a refused letter bubbles); the Fill row and F only while
    Polyline, Rectangle or Circle is allowed (S-9 f);
  - the symbol tool needs `symbol` in `tools` **and** `symbolPalette`;
    the Symbols tab only with `symbolPalette`; `SymbolPanel` gains an
    optional `filter` (`bool Function(SymbolEntry)`), applied before
    `searchSymbols` and to the id lookup; the view's `symbolFilter` reaches
    it through `FloorPlanSymbol.of`;
  - `SymbolPlaceTool` gains optional gates read at each key: R and
    Shift+R need `rotate`, M needs `mirror` (a refused key bubbles);
  - the bar (Task 2): Undo and Redo only with `undo`, Export with
    `export`, Print with `print`, the snap read-out with `snapping` —
    shown **and** bound by the same flag, decided at the shell's build
    from the commands it was created with;
  - `snapping: false`: F3 unbound, the read-out gone, and object snap off
    for the editor's tools and drags (a `SnapSettings` subclass whose
    `objectSnap` reads the user's setting **and** the flag; the user's
    setting is kept for when the flag returns; S-14); `rulers` and `grid`
    to `PlannerView`;
  - **the left column** is built only while it holds more than the Select
    row or the Symbols tab (S-13); the view's chrome inputs (Task 2's
    re-measure) gain the capabilities;
  - **a runtime change** (`didUpdateWidget`, the old value `!=` the new):
    a tool no longer allowed, or the symbol tool whose armed entry the
    palette or the filter now refuses, falls back to select (which
    cancels a pending shape); the tab and the search text, the shell's,
    are kept (C-5).
- `FloorPlanController`: `ValueListenable<FloorPlanTool> activeTool`
  (select with no editor mounted and in the selection mode) and `bool
  selectTool(FloorPlanTool tool)` (false in the selection mode, with no
  editor mounted, for a tool the capabilities refuse, and for `symbol`
  unless an armed entry is still allowed, which it re-activates; S-6),
  through an internal bridge the shell registers as it registers its
  settle; the shell sets `activeTool` on every tool change, so a letter,
  a palette tap, Escape and a fallback all reach it.
- `FloorPlanView`: `editorCapabilities`, validated at build, passed to the
  shell. Barrel: the three names; B1 gains them.
- **The editor fixture** (`test/host/editor_fixture.dart`, Global
  constraints) and `editorCamera()`.

**Tests** (`test/host/editor_capabilities_test.dart` for the type;
`test/host/editor_tools_test.dart` through `FloorPlanView` on the editor
fixture under `editorCamera()`): **M-H41, M-H47(runtime tool),
M-H47(symbolFilter)**, **T4-a** to **T4-j** (below). Plain:
- the three profiles field by field as S-12 lists; `copyWith` of each
  field; `==`, `hashCode`, `toString`; `FloorPlanSymbol.of` of a bundled
  table and of a chair (`seats` null);
- `full` is today's editor: every palette row, every letter, the Fill
  row, the Symbols tab with every symbol, OSNAP, rulers and grid (the
  existing suites unedited say so; one test reads them through the view);
- `tablesOnly`: the Tools tab shows Select alone; a table armed from the
  Symbols tab places a numbered table; `readOnly`: no Symbols tab;
- `editorCapabilities` leaves the selection mode as it is: under
  `readOnly` a service drag still moves a table and Undo still undoes it.

**Unedited and green (P-6):** `test/planner_shell_test.dart`,
`test/symbols/symbol_panel_test.dart`, `symbol_search_test.dart`,
`symbol_place_tool_test.dart`, `symbol_end_to_end_test.dart`,
`symbol_ghost_test.dart`, `test/l10n/shell_words_test.dart`,
`panel_words_test.dart`, `symbol_words_test.dart`, `overflow_test.dart`,
`test/layers/tools_layer_test.dart`, `test/touch_tools_test.dart`,
`test/wall_tool_test.dart`, `room_tool_test.dart`,
`dimension_tool_test.dart`, `opening_tool_test.dart`,
`test/planner_draw_test.dart`, `test/canvas_ui_test.dart`,
`test/intersection_snap_test.dart`, `test/host/view_test.dart`,
`test/host/theme_canvas_test.dart`; `apps/floor_planner`'s tests; the
demo's tests.

**Gates:** planner (`--enable-vmservice`, standing comparison, analyze,
format), demo, floor planner.

### Task 5 — capabilities II: the select tool and the panels (C-5's `selectTablesOnly` to `changeLayer`, the panels and their editing; C-8)

**Verified:**
- **The Selection panel's edits** (`selection_panel.dart`), gated today by
  permissions alone (`_editable` `:326`, `_turnable` `:433-441`,
  `_resizable` `:445-451`, `_rotatable` `:693-698`): box width and height,
  wall thickness and justification (`:962`), opening width and position,
  a door's Flip hinge and Flip swing (`:986`), room name, dimension kind
  (`:834`) (`build`, `:1194-1358`); the Symbol section's Rotation field,
  **Mirror** and Size menu (**Change size**) (`:1072-1135`; `_mirrorSymbol`
  `:655-667`, `_changeSize` `:671-689`); the Table section's number and
  ±90 (`:1137-1192`; `_rotateTable` `:638`); **the layer picker**
  (`:1349-1352`; `layers/layer_picker.dart:105-151, 167-257`). A
  **table's Mirror shows today** (a servable instance's `_turnable` is
  `_rotatable`, `:436-441`); its Size menu does not (`:1078-1081`).
- **The Layer panel** disables every control without `structure`
  (`layers/layer_panel.dart:150`, `:269`, `:278` make current, `:313-327`
  add and delete; `layer_row.dart:215-241` current, visibility, lock,
  colour, `:296` rename); **the Page panel** has no gate
  (`page_panel.dart:14, :116`; preset, orientation, scale, unit,
  separator, grid, snap, page breaks, swatches `:157-288`).
- The right column (`planner_shell.dart:1034-1069`).
- **A table** is a root-level servable instance (`tables/table_index.dart:49-53,
  77-83`, T1: a servable instance in a group is no table;
  `symbols/symbol_section.dart:29-33`). `TablePicker` is cached by the
  document's state and its tables' revision (`service/table_picker.dart:190-230`)
  and picks a table's top, else its box, else within a reach
  (`:314-353`); its candidates exclude hidden layers and carry `locked`.
- The engine's pick returns **one** topmost hit
  (`jet_cad_2d` `spatial_index.dart:793`): a filter applied after it
  loses a table under a wall line or a room's edge (S-15).

**Builds:**
- `PlannerShell`: an internal `SelectGates` subclass reading
  `widget.capabilities` live: `restrictsPick` = `selectTablesOnly`, its
  `pick` a `TablePicker` over the shell's document (a finger's reach for
  touch; a locked table skipped, as `QueryFilter.picking` skips a locked
  layer), `bandAccepts` a table key under `selectTablesOnly`; `move`,
  `rotate`, `reshape`, `delete` the flags; `idleKeys` true (Task 6 reads
  `shortcuts` into it). The select tool and the grip cache are built with
  it; a capability change calls `gatesChanged()`, and a change **to**
  `selectTablesOnly` drops every non-table key from the design selection
  (S-9 g).
- `SelectionPanel`, an optional internal capabilities input, ANDed with
  today's permissions: the number with `renumber`; the Rotation field and
  ±90 with `rotate`; Mirror with `mirror`; the Size menu and the object
  fields (box, wall, opening, room, dimension, and a door's flips) with
  `reshape` (S-10). **A button or a menu whose flag is false is not
  shown** (Mirror, ±90, the flips, the Size menu, the layer picker); **a
  value field or a segmented value is shown read-only** (S-11). The layer
  picker with `changeLayer`.
- `LayerPanel` and `PagePanel`, an optional `editable` (true), ANDed with
  today's permission (the Page panel has none): with `editLayers` /
  `editPage` false every control is disabled, the list and the values
  shown.
- The right column: the Selection, Layer and Page panels each shown by
  `selectionPanel`, `layerPanel`, `pagePanel`, a hidden one **kept
  offstage** (`Visibility(maintainState: true)`, focus excluded) so its
  state is kept (C-5); the column itself not built when all three are
  hidden.
- C-8: nothing to build; the test below pins it.

**Tests** (`test/host/editor_select_test.dart`, `test/host/editor_panels_test.dart`,
on the editor fixture under `editorCamera()`): **M-H42, M-H43, M-H43b,
M-H43c**, **T5-a** to **T5-h** (below). Plain:
- `tablesOnly`, a table selected: the Table section (number editable,
  ±90), the Symbol section's Rotation field; a body drag moves it, the
  rotation grip turns it, Delete removes it **and its data** (Slice 2's
  expander), Undo restores both;
- `readOnly`: a table, a wall, a room and a dimension each selectable,
  their sections shown read-only; no command reaches the document from
  any pointer path or key (the document byte-identical after a scripted
  run of a body drag, every grip drag, the rotation grip, ±90, Mirror,
  the layer picker, Delete);
- the tables on the hidden and the locked layers are never selected;
- under `full` every control is today's (the panels' suites unedited say
  so).

**Unedited and green (P-6):** `test/selection_panel_test.dart`,
`test/tables/table_section_test.dart`, `test/symbols/symbol_section_test.dart`,
`test/layers/*`, `test/page_panel_test.dart`, `test/opening_panel_test.dart`,
`test/room_panel_test.dart`, `test/dimension_panel_test.dart`,
`test/planner_grips_test.dart`, `wall_grips_test.dart`,
`room_grips_test.dart`, `dimension_grips_test.dart`, `opening_grips_test.dart`,
`test/symbols/symbol_move_test.dart`, `wall_attach_test.dart`,
`test/l10n/panel_words_test.dart`, `value_words_test.dart`,
`stale_error_test.dart`, `test/tables/table_data_test.dart`,
`test/host/table_data_test.dart`, `test/host/design_changes_test.dart`,
`test/host/view_test.dart` (V4).

**Gates:** planner (`--enable-vmservice`, standing comparison, analyze,
format), demo, floor planner.

### Task 6 — keyboard, focus and the inspector (C-6, C-7)

**Verified:**
- **The service's keys:** its `CallbackShortcuts` (`service_view.dart:471-478`),
  its `Focus(autofocus: true)` (`:479-480`), and the table tool's idle
  Escape, which clears the selection (`service/table_select_tool.dart:529-536`).
- **The editor's keys:** the shell's `CallbackShortcuts` (`planner_shell.dart:897-915`:
  the command chords, F3, the letters, F, Escape) and the select tool's
  idle keys (Task 3's `idleKeys`); its canvas's `Focus` through
  `PlannerView` (`planner_view.dart:391`) and `InteractionLayer` (Task 3).
- **Autofocus in Flutter** applies only while the scope has no focused
  node, in the order the requests arrive: the view steals the focus from
  a host field that asks after it in the same frame, or from none; a host
  field focused earlier keeps it. The killer's layout is chosen so the
  mutant is red (verified, named in the report).
- `selectedTables` is the active plan's (`floor_plan_controller.dart:587-589,
  1510-1521`); `tableDetails` and `tableDetailInstances`, index for index
  (`:1131-1161`).
- The inspector's place: under the Selection panel in the right column
  (`planner_shell.dart:1049-1057`).

**Builds:**
- `FloorPlanView`: `shortcuts = true`, `autofocus = true`,
  `tableInspectorBuilder: Widget? Function(BuildContext context,
  FloorPlanTableDetail table)?`, each documented with C-6's and C-7's
  sentences; read at each build.
- **`shortcuts: false`** (S-16): the service view binds nothing and its
  table tool's idle Escape bubbles (an optional read of the flag); the
  shell binds nothing (chords, letters, F3, F, Escape); the editor's gates
  read `idleKeys` false (Delete, Backspace and the select tool's idle
  Escape bubble). A gesture's keys stay (a drag's Escape and Shift, a
  drawing tool's Escape and Enter, the symbol tool's R and M). The
  commands stay callable (`undo()`, `redo()`, `exportPlan`, `printPlan`,
  `selectTool`).
- **`autofocus: false`:** the service view's `Focus` and, through a new
  optional `PlannerView.autofocus`, the canvas's `InteractionLayer`, in
  both modes; a tap on the canvas still takes the focus.
- **The inspector:** the shell takes an optional builder by instance and
  shows it under the Selection panel (and with it: `selectionPanel`) when
  the selection holds **exactly one key, a numbered root-level table**
  (S-18), in a builder listening to the selection and the document's
  changes; the view's adapter hands the host that instance's
  `FloorPlanTableDetail` from `tableDetails`. Never rebuilt by pan or zoom
  (P-4).
- **`editorSelectedTables`** (`ValueListenable<Set<String>>`): in the
  design mode `selectedTables`' value, in the selection mode empty
  (S-17); set in `_refreshSelected`; notifies only on a change.

**Tests** (`test/host/keyboard_focus_test.dart` both modes on
`embeddingPlanJson`, the editor's keys on the editor fixture;
`test/host/inspector_test.dart` on the editor fixture): **M-H41b, M-H45**,
**T6-a** to **T6-g** (below). Plain:
- `shortcuts: true` (the default) binds today's every key (the existing
  suites unedited say so: view_test V8, planner_shell_test);
- with `shortcuts: false` the controller's `undo()` and `exportPlan`
  still act in both modes;
- the inspector reaches the host's state: a field in it calls
  `setTableData`, and the inspector shows the new data after the
  `revision` it causes; `editorSelectedTables` through the barrel, its
  notifications counted.

**Unedited and green (P-6):** `test/host/view_test.dart` (V8, V15),
`test/planner_shell_test.dart`, `test/selection_panel_test.dart`,
`test/service/table_select_tool_test.dart`, `service_events_test.dart`,
`service_options_test.dart`, `test/host/view_events_test.dart`,
`test/host/controller_test.dart`, `test/host/table_groups_gesture_test.dart`,
`table_groups_context_test.dart`; render `interaction_layer_test.dart`
and its siblings.

**Gates:** planner (`--enable-vmservice`, standing comparison, analyze,
format), demo, floor planner.

### Task 7 — the demo, docs, CI and the exit (the controller's)

- **Demo** (`apps/restaurant_demo`), the smallest real use of every
  addition (P-7); strings in en, de, tr (`lib/demo_strings.dart`):
  - in the design mode an **Editor** switch, *Full* (the default),
    *Tables* and *Read only* (`editorCapabilities`); under *Tables* the
    Selection panel shows the demo's **table inspector**, a "POS id" field
    writing `setTableData(number, {'id': …})` (E-7, the guide's
    `data["id"]` suggestion);
  - in the selection mode an **Own bar** switch: `serviceBar:
    FloorPlanServiceBar(visible: false)` and the demo's own row built from
    `canUndo` / `undo()`, `canRedo` / `redo()`, `mergeCandidate` (Merge),
    `selectedGroup` (Split), `exportPlan` and `printPlan`; off, jet-cad's
    bar with the area's name as `leading`;
  - `onExportDialog`: the demo's own dialog (format and resolution) in
    place of the Material one, from every entry point; `onPageFlowError`
    to the event log;
  - a search field in the app bar beside the plan, with the view's
    `autofocus: false`, and a **Keys** switch (`shortcuts`), so the demo
    shows the host owning the keyboard.
  - With every switch at its default the demo is today's: the existing
    demo tests (`demo_test.dart`, `badges_test.dart`, `events_test.dart`,
    `look_test.dart`, `sample_plans_test.dart`) pass unedited. Demo tests
    for each switch: *Tables* hides the wall tool and the layer panel and
    the inspector writes the id; *Read only* moves nothing; *Own bar*'s
    Merge sends what jet-cad's would; the demo's dialog exports a PNG at
    its resolution; the search field keeps the focus across a mode switch.
- **Host guide** (`docs/host-guide.md`), marked *Unreleased*: § 8 gains
  three subsections, **The bars** (C-1 to C-4: `serviceBar`, `editorBar`,
  their order and gaps, host items, a host-built bar with the controller's
  listenables and commands, `exportPlan` / `printPlan`, `onExportDialog`
  at every entry point, `onPageFlowError`), **The editor's capabilities**
  (C-5, C-6, C-8: the three profiles field by field, `copyWith`,
  `symbolFilter`, a runtime change, the inspector and
  `editorSelectedTables`, Material inside the editor), **Keyboard and
  focus** (C-7, what `shortcuts: false` leaves to a gesture, `autofocus`);
  § 4's `FloorPlanView` parameter list names the eight parameters; § 11
  gains two bullets: **capabilities are not a security boundary** (a
  host's own calls stay allowed, V-5) and **with `shortcuts: false`
  nothing deletes in the editor** (S-16).
- **Host probe:** the guide's new snippets (each bar with items, a
  host-built bar, `onExportDialog`, a capabilities value with `copyWith`
  and a `symbolFilter`, the inspector, `shortcuts` and `autofocus`) in
  `tool/ci/host_probe/lib/main.dart`; `check_guide` green; one mutant: an
  edited probe snippet makes `check_guide` exit 1.
- **CI, invariant 1:** unchanged: the host-probe job analyses v0.3.0's
  probe against the commit under test (`.github/workflows/ci.yml:166`,
  `tool/ci/old_host_probe.sh`); both probes analyse locally at the tip.
- **CHANGELOG** *Unreleased* (`CHANGELOG.md:9`): the intro names Slice
  4; bullets **The bars**, **The editor's capabilities**, **Keyboard and
  focus**; for `jet_cad_2d_flutter`, `SelectGates`, `SelectTool.gates`,
  `GripCache.gates` and `gatesChanged`, `InteractionLayer.autofocus`;
  stored formats unchanged.
- **Results note** `docs/superpowers/notes/2026-10-09-embedding-slice-4-results.md`
  (with R-4's re-enumeration, path by path, against the flags: [S-9](#spec-points-to-settle)'s
  table); **STATUS**; **the roadmap's row 14** (`roadmap/00-README.md:267`);
  the spec's Review section records the rulings on S-1 to S-24, and C-2,
  C-3, C-5, C-7, F-9, F-12, F-15 and M-H46 are amended as ruled.
- **Every gate**, `tool/ci` and the engine included, with the standing
  comparison; both web builds; the host probe locally at the full SHA.
- **Web smoke check** in Chromium (Playwright, `locale: 'en-US'`): the
  demo's Salon: Service with jet-cad's bar and the area's name; *Own bar*:
  undo a move, Merge two tables, Export through the demo's dialog; Design
  under *Full*, *Tables* (a table placed, numbered, turned, renumbered,
  its id written; no wall tool, no layer panel) and *Read only* (nothing
  moves); the search field keeps the focus across a mode switch; *Keys*
  off: Ctrl+Z reaches the demo, not the plan; no console error.

Then an independent code review of the whole range, its fixes, and the
merge on the human's word.

## Mutants per task

| Task | Mutants | Count |
|---|---|---|
| 1 | M-H46; T1-a to T1-f | 1 + 6 |
| 2 | M-H40, M-H44, M-H47(serviceBar); T2-a to T2-f | 3 + 6 |
| 3 | T3-a to T3-j | 0 + 10 |
| 4 | M-H41, M-H47(runtime tool), M-H47(symbolFilter); T4-a to T4-j | 3 + 10 |
| 5 | M-H42, M-H43, M-H43b, M-H43c; T5-a to T5-h | 4 + 8 |
| 6 | M-H41b, M-H45; T6-a to T6-g | 2 + 7 |
| 7 | the probe snippet (check_guide) | 1 |

Every spec mutant of Slice 4 is here once: M-H40 (Task 2), M-H41 (Task 4),
M-H41b (Task 6), M-H42 (Task 5), M-H43, M-H43b, M-H43c (Task 5), M-H44
(Task 2), M-H45 (Task 6), M-H46 (Task 1), and M-H47's three: *a capability
change at runtime leaves a forbidden tool active* (Task 4), *`symbolFilter`
not applied to search results* (Task 4), *`serviceBar.visible: false`
leaves the 44 px seed in the R-13 measurement* (Task 2).

Each mutant and its killer:

**Task 1**

- **M-H46:** an Export entry point opens the Material dialog when
  `onExportDialog` is given. Applied three times, one entry point each:
  the shell's file command (button and chord), the service bar's button,
  the service chord. Killer: with a recording hook answering PNG at 300
  dpi: Cmd+E and Ctrl+E in the design mode, Ctrl+E in the selection mode,
  `toolbar-export` and `service-export` → the hook called once each with
  the remembered choice as `initial`, `export-dialog` never found, and
  `onExport` given a `<exportName>.png` whose pixel size is the page's at
  300 dpi (computed by the test). The spec's Ctrl+Shift+E is bound
  nowhere (S-1).
- **T1-a:** `exportPlan` / `printPlan` without the one-at-a-time guard.
  Killer: two `exportPlan` calls in one synchronous step → the second
  completes null; `printPlan` while the bar's Print awaits a printer that
  has not answered → false; after it ends → true.
- **T1-b:** `exportPlan` without the `identical(document,
  activeDocument)` check. Killer: `exportPlan` then `setMode` before its
  bytes → null; then `load` the same way → null.
- **T1-c:** a flow's error swallowed, or `onPageFlowError` not called.
  Killer: a printer throwing `StateError('jam')`: with the callback → it
  receives that error once and the bar's Print is enabled again; without
  it → the error still surfaces as today (S-8; the form the base shows,
  pinned first on the base).
- **T1-d:** the hook's null read as the initial choice. Killer: a hook
  answering null → nothing exported, `exportChoice` unchanged.
- **T1-e:** the public-to-internal mapping swapped (d96 ↔ d300, or by
  index after a reorder). Killer: each of the six choices through
  `exportPlan` gives the bytes the same choice gives through the base's
  dialog (PNG pixel sizes per dpi, the PDF's magic and page size).
- **T1-f:** the hook's answer not remembered. Killer: the second Export
  passes the first's answer as `initial`; `exportPlan` leaves it as it
  was (S-7).

**Task 2**

- **M-H40:** `actions` read as a set in the enum's order (both bars).
  Killer: `FloorPlanServiceBar(actions: [print, undo])` with Merge and
  Split callbacks given → only `service-print` and `service-undo`, print's
  left edge left of undo's; `FloorPlanEditorBar(actions: [redo, undo,
  zoom, snap])` → `toolbar-redo` left of `toolbar-undo`, `zoom-text` left
  of `osnap-text`, no `toolbar-export` or `toolbar-print`. Seen red in each
  bar.
- **M-H44:** `mergeCandidate` non-null for one table (`selectedTables`
  when not empty). Killer, in the selection mode: `1` alone → null; `7`
  and ` 7 ` (two tables, one number) → null; one whole group → null; `1`
  and `2` → `{1, 2}`, equal to what Merge sends; a group and a table
  outside it → their numbers; in the design mode `1` and `2` → null.
- **M-H47(serviceBar):** `serviceBar.visible: false` leaves the 44 px
  seed in the R-13 measurement (the re-measure keyed on the theme's bar
  height alone, or a 44 px box kept). Killer: with the bar hidden from the
  start, the controller's measured selection origin is the view's top
  after the first frame, and a table's global position is kept across
  design → selection → design at the **first** switch (the seed
  corrected); then, the plan unchanged, `visible` toggled at runtime and
  the switch repeated → kept again.
- **T2-a:** the gap rule off by a group (a gap after every action, or
  none). Killer: the characterization test (every left edge of both
  default bars, with and without `onExport`, Merge and Split).
- **T2-b:** host widgets inside the toolbar's `ExcludeFocus`, or outside a
  guard. Killer: a `TextField` in the editor bar's `trailing`: tapped, it
  takes the focus, and typing `w` writes `w` with the active tool still
  select; in the service bar's `leading`, Ctrl+Z in it does not undo the
  plan.
- **T2-c:** `undo()` acts mid-shape. Killer: the Polyline tool with two
  points placed (a shape part-way), `controller.undo()` → the document's
  state unchanged and the shape still pending; after Escape → it undoes.
- **T2-d:** `mergeCandidate` not refreshed by `setTableGroups`. Killer:
  `1` and `2` selected (`{1, 2}`), then a group `{1, 2}` set with no
  selection change → null; the group removed → `{1, 2}`.
- **T2-e:** a bar's `actions` unbinding a chord. Killer:
  `FloorPlanEditorBar(actions: [export, print])` and
  `FloorPlanServiceBar(actions: [print])` → Ctrl+Z still undoes, in each
  mode.
- **T2-f:** the editor bar's runtime visibility not re-measured. Killer:
  in the design mode `editorBar.visible` toggled with the plan unchanged,
  then design → selection → design → a table's global position kept.

**Task 3** (render level; a test gates class)

- **T3-a:** `_bandKeys` ignores `bandAccepts`. Killer: a window and a
  crossing band over the line, the group and both instances under a gate
  accepting instance keys only → exactly the two instance keys.
- **T3-b:** the pick override used for presses but not hovers (or the
  reverse). Killer: the topmost hit at a point is the line, the override
  answers instance B → a press selects B and a hover sets B; an override
  answering null over the line → neither selects nor hovers.
- **T3-c:** the centre (move-role) grip escapes `move`. Killer: under
  `move: false` a drag of a line's centre grip and a body drag both leave
  the document unchanged (no command) and show no move cursor; under
  `move: true` both move it.
- **T3-d:** the rotation grip drawn or hit under `rotate: false`. Killer:
  the overlay's recorded calls hold no rotation disc; a press at its place
  is not `rotationGrip`; no command.
- **T3-e:** a stretch grip drawn or hit under `reshape: false`. Killer:
  no `drawRawPoints` with the stretch paint; `hitTest` at an end grip is
  -1; a drag from it is a band or a click, never a reshape; the centre
  grips still drawn under `move: true`.
- **T3-f:** Delete under `delete: false`. Killer: Delete and Backspace
  remove nothing and return `ignored`.
- **T3-g:** idle keys under `idleKeys: false`. Killer: idle Escape and
  Delete return `ignored`, the selection kept; a drag's Escape still
  cancels it (`handled`).
- **T3-h:** a gate closed mid-drag still commits. Killer: `move` true at
  the slop, false before the up → no command, the document byte-identical
  (`DraftDocumentCodec`'s encoding equal).
- **T3-i:** `InteractionLayer.autofocus` not passed to its `Focus`.
  Killer: `InteractionLayer(autofocus: false)` and a host
  `TextField(autofocus: true)` in the layout the test pins red → the
  field has the primary focus.
- **T3-j:** a closed role's buffer reallocated or filled. Killer: the
  sibling of `selection_overlay_grips_test.dart:185`: `reshape` toggled
  false, true, false across frames → the stretch buffer is the same
  object throughout; `paint_allocation_test` untouched.

**Task 4**

- **M-H41:** `tablesOnly` leaves the wall tool's letter active (the
  letters bound for every entry). Killer: under `tablesOnly`, the canvas
  focused, a host `CallbackShortcuts` above the view binding W → W reaches
  the host and `activeTool` stays select; the same for L, P, R, B, D, N,
  G, M, S, I, C, A, T; V still selects. Its second form (bound, but
  `_activate` refusing) is red by the host's W.
- **M-H47(runtime tool):** a capability change at runtime leaves a
  forbidden tool active. Killer: `full`, W, one click (a wall part-way) →
  the host switches to `tablesOnly` → after one pump `activeTool` is
  select, the status line reads the Select tool's words, the pending wall
  is gone (a further click adds nothing), the wall row gone.
- **M-H47(symbolFilter):** the filter not applied to search results.
  Killer: `tablesOnly`, the Symbols tab, a query the bundled libraries
  answer with at least one table and one non-table (verified on the base
  and named in the report) → only tables' cells; a query answering only
  non-tables → the no-match line; `full.copyWith(symbolFilter: (s) =>
  s.key == k)` with no query → that one cell.
- **T4-a:** a refused tool's palette row shown. Killer: `tablesOnly` →
  no `tool-wall`, one `tool-select`; `readOnly` → no `tool-fill`.
- **T4-b:** `selectTool` true for a refused tool. Killer: `tablesOnly`:
  `selectTool(wall)` false, `activeTool` select; `full`: true, wall; in
  the selection mode: false; no editor mounted: false.
- **T4-c:** an armed symbol survives a change that refuses it. Killer:
  `full`, a chair armed (symbol tool active) → `tablesOnly` → `activeTool`
  select, a click places nothing.
- **T4-d:** the symbol tool's M under `mirror: false`. Killer:
  `tablesOnly`, a table armed, M then a click → the placed instance's
  determinant is positive; R then a click → turned 90° (rotate allowed).
- **T4-e:** the bar's flags decided where the shell cannot see them (the
  view omitting the command). Killer: `full.copyWith(export: false, undo:
  false)` → no `toolbar-export`, no `toolbar-undo`, Ctrl+E and Ctrl+Z
  reach a host binding; switched to `full` at runtime → both shown and
  bound.
- **T4-f:** `snapping: false` hides the read-out but snaps. Killer: no
  `osnap-text`, F3 reaches a host binding, and a line drawn from within
  the aperture of a wall's end starts at the raw point; under `full` it
  starts at the end.
- **T4-g:** `rulers` or `grid` not reaching the view, or a runtime rulers
  change not re-measured. Killer: no `RulerFrame`, no grid pixel at a
  grid line's place; `rulers` toggled at runtime, then a mode round trip
  → a table's global position kept.
- **T4-h:** `activeTool` stale. Killer: W → wall (one notification);
  Escape → select; a palette tap → its tool; a mode switch → select.
- **T4-i:** capabilities without select accepted. Killer: `tools: {wall}`
  → an `ArgumentError` naming `tools` at build.
- **T4-j:** the left column built with nothing in it. Killer: `readOnly`
  → no `chrome-left`, the canvas origin re-measured (a mode round trip
  keeps a table's place); `tablesOnly` → present.

**Task 5**

- **M-H42:** the rubber band picks a wall under `selectTablesOnly`.
  Applied in two forms: the shell's `bandAccepts` true; the tool's band
  filter removed. Killer: `tablesOnly`, a window band and a crossing band
  each over a wall, the free line, the group, a room's edge, a
  dimension, the TEXT, the chair and tables `1` and `2` → the design
  selection is exactly `1`'s and `2`'s root keys; a click on a wall line
  selects nothing; a click inside `1`'s box away from its lines selects
  `1`.
- **M-H43:** `tablesOnly` shows Mirror. Killer: `1` selected → no
  `symbol-mirror` under `tablesOnly`; present under `full` (same fixture,
  same selection).
- **M-H43b:** `tablesOnly` shows the layer picker. Killer: `1` selected →
  no `layer-picker` under `tablesOnly` or `readOnly`; present under
  `full`.
- **M-H43c:** reshape grips active (the shell's gate `reshape` reading
  true). Killer: under `full.copyWith(reshape: false)`: the free line
  selected → no stretch point drawn and a drag from its end grip leaves
  the document unchanged; a wall selected → its end grip's drag changes
  nothing; under `full` both reshape.
- **T5-a:** `move` not wired. Killer: `readOnly`, a body drag of `1` → no
  command; `tablesOnly` → it moves.
- **T5-b:** `rotate` not wired. Killer: `readOnly`, `1` selected → no
  rotation grip, no ±90, the Rotation field read-only (a typed value does
  not commit); `tablesOnly` → the grip turns it.
- **T5-c:** `delete` not wired. Killer: `readOnly`, Delete → nothing
  removed; `tablesOnly` → `1` removed with its data, Undo restores both.
- **T5-d:** the selection not pruned on a change to `selectTablesOnly`.
  Killer: `full`, a wall and `1` selected → `tablesOnly` → the selection
  holds `1` alone; Delete removes `1` only.
- **T5-e:** `renumber` not wired. Killer: `readOnly`, the number field
  read-only, a typed `12` not committed; `tablesOnly` → committed.
- **T5-f:** the object fields under `reshape: false` (S-10). Killer: a
  wall's thickness read-only; a door's flips absent; the dimension kind
  disabled.
- **T5-g:** the panels' show and edit flags. Killer: `layerPanel: false`
  → no `layers-panel`; `pagePanel: false` → no `page-preset`;
  `editLayers: false` → `layers-add` and a row's visibility toggle
  disabled; `editPage: false` → the page controls disabled; the Layers
  section's open state kept across hide and show.
- **T5-h:** C-8. Killer: `tablesOnly`, `1` selected: no `DropdownButton`,
  `PopupMenuButton` or `MenuAnchor` under the editor; under a local
  `Theme` with a hand-built `ColorScheme`, the ±90 buttons' foreground is
  that scheme's `primary`.

**Task 6**

- **M-H41b:** `shortcuts: false` leaves a service chord bound. Applied once
  per chord group (undo, redo, export, print). Killer: the selection mode,
  the canvas focused, a host `CallbackShortcuts` above the view binding
  Ctrl+Z, Ctrl+Y, Ctrl+Shift+Z, Ctrl+E and Ctrl+P (and their Cmd forms)
  → each reaches the host; a service move stays; nothing exported or
  printed.
- **M-H45:** the inspector shows for two selected tables (the rule read as
  `selectedTables.length == 1`). Killer: `1` and `2` → none; `7` and ` 7 `
  (one number, two tables) → none; `1` and a wall → none; the unnumbered
  table alone → none; `1` alone → the host's widget with `1`'s detail
  (its centre equal to the test's forward transform of the box's centre,
  its data).
- **T6-a:** `autofocus: false` honoured in one mode only. Killer: in each
  mode, and after `setMode`, `resetLayout` and `load`, the host's field
  keeps the primary focus.
- **T6-b:** `shortcuts: false` leaves an editor key bound. Killer: W, F3,
  F, Escape and Ctrl+Z each reach a host binding in the design mode.
- **T6-c:** Delete under `shortcuts: false`. Killer: `tablesOnly`, `1`
  selected, Delete → nothing removed, the host's Delete binding fires.
- **T6-d:** the inspector rebuilt by the camera. Killer: a counting
  builder: 0 calls across 50 pans and zooms; one per selection change.
- **T6-e:** `editorSelectedTables` filled in the selection mode. Killer:
  `1` selected, then the selection mode → empty; back → `{1}`.
- **T6-f:** the inspector shown with `selectionPanel: false`. Killer:
  `full.copyWith(selectionPanel: false)`, `1` selected → no inspector.
- **T6-g:** the table tool's idle Escape under `shortcuts: false`.
  Killer: the selection mode, `1` selected, Escape → the selection kept,
  the host's Escape binding fires.

**Task 7**

- **The probe snippet:** an edited probe snippet makes `check_guide` exit
  1.

## Exit gate

- Task 7 green: every gate, the standing sets exact, both web builds, the
  smoke check, the probe and v0.3.0's probe locally and in CI.
- Every named mutant above seen red and recorded.
- R-4's re-enumeration recorded in the results note: every edit path of
  F-15 and of [S-9](#spec-points-to-settle), each with its flag, its
  enforcing code and its killing test.
- The independent review applied (V-7's and R-4's holes re-enumerated
  against the flags by the reviewer, not only by this plan).
- **Owed to the human:** a look at the demo's three editor profiles and
  its own bar on a tablet and a terminal; the German and Turkish read of
  the demo's new strings; the rulings on S-1 to S-24 if any differs from
  the recommendation.
- **Owed to Monépro:** spec 103 can name `tablesOnly` for phase 2's "edit
  floor drawing" (F-3), `shortcuts: false` beside `PosShortcutsHost`,
  `onExportDialog` for a `ShadDialog` (F-4), and the inspector for linking
  `pos_tables` rows (C-6).
- **The merge into `main` happens on the human's word**; a release is the
  human's call (P-8).

## Spec points to settle

Found while verifying the spec against the code at `6fb7a6d`. Each has a
recommended resolution; the plan is written to the recommendation.
**The controller ruled each as recommended, but S-16** (below); the spec
records them.

- **S-1. M-H46 names Ctrl+Shift+E, which is bound nowhere.** Export's
  chord is Cmd/Ctrl+E (`shell_commands.dart:31`; spec 13 D8); no
  Shift+E exists in the planner or the floor planner. *Recommended:* the
  killer uses Cmd+E and Ctrl+E, in both modes; M-H46 amended so.
- **S-2. C-2's default order contradicts P-6.** C-2's comment lists
  "undo, redo, export, print, snap, zoom read-out", but today's bar reads
  export, print, undo, redo, OSNAP, zoom (`document_toolbar.dart:44-47`,
  `planner_shell.dart:932-984`), and `actions = values` in the listed
  order would reorder every editor's bar. And the bar holds a status line
  between the buttons and the read-outs, which no action names.
  *Recommended:* `FloorPlanEditorAction` is declared `export, print, undo,
  redo, snap, zoom` (and `FloorPlanServiceAction` `undo, redo, merge,
  split, export, print`, today's order); the editor's buttons lie at the
  left in the given order, the status line keeps the flexible middle, the
  read-outs lie at the right in the given order; a 12 px gap between a
  file and an edit button (editor), 8 px between two actions of different
  groups (service), which reproduce today's bars exactly; a bare shell's
  other file commands (New to Save As) come first, as today. The name of
  the zoom read-out's action is `zoom`.
- **S-3. C-2 says the tools "are hidden by C-4"**: C-4 is the dialog
  hook. *Recommended:* read C-5; amended.
- **S-4. C-3: "In the design mode they also wait for an idle tool, as the
  shell's buttons do."** They do not: `undo()` / `redo()` settle and act
  (`floor_plan_controller.dart:1047-1059`); only the shell's flags wait
  (`planner_shell.dart:562, 568-571`). *Recommended:* make it true for the
  commands: the shell registers an idle probe beside its settle, and in
  the design mode `undo()` / `redo()` do nothing while the editor's tool
  is part-way through a shape; `canUndo` / `canRedo` keep their documented
  meaning (the history), so a host bar enabled by them may press while a
  shape is pending and nothing happens, as the shell's key does today
  (the tool swallows it). A 0.3.0 host calling `undo()` mid-shape today
  undoes a step beneath a pending shape; the change is a fix, named in the
  CHANGELOG.
- **S-5. `mergeCandidate` in the design mode, and without
  `onMergeRequested`.** Merge is the selection mode's. *Recommended:*
  null in the design mode; in the selection mode it does not depend on
  whether the host passed `onMergeRequested` (it is what the button
  *would* send).
- **S-6. `FloorPlanTool`, `activeTool` and `selectTool` where there is no
  editor.** C-5's list ends with "…". *Recommended:* sixteen values, the
  palette's order then `symbol`; `activeTool` reads select in the
  selection mode and with no editor mounted; `selectTool` answers false
  there (no queue), for a refused tool, and for `symbol` unless an armed
  entry is still allowed (it re-activates it: a host cannot choose a
  symbol in this slice, recorded as a limit).
- **S-7. The guard and the errors of `exportPlan` / `printPlan`.** C-3
  names "`page_flows.dart`'s one-at-a-time guard", which is per view
  today. *Recommended:* one guard per controller, shared by the view's
  flows and the two commands (a host's `exportPlan` while the bar's Print
  runs answers null); the commands' errors complete their `Future` (the
  host awaits them), `onPageFlowError` reports the flows the view starts;
  `exportPlan` leaves the dialog's remembered choice as it is; the
  commands are allowed under every capability (V-5's "the host's calls").
- **S-8. `onPageFlowError` absent.** *Recommended:* today's behaviour,
  exactly: the error propagates out of the flow's `Future`, which the
  caller drops (an uncaught async error, as today); only with the callback
  is it caught.
- **S-9. R-4: the edit paths F-15 does not list** (re-enumerated at
  `6fb7a6d`; nothing was added since `85905bd`: `git log 85905bd..6fb7a6d`
  on the shell, the panels, the symbols, the select tool and the grip
  cache shows the theme and the overlay only). *Recommended* flags:
  (a) the **centre (move) grip** of a leaf moves the whole selection
  (`select_tool.dart:311-312`) → `move`; (b) the **symbol tool's R,
  Shift+R and M** turn and mirror the next placement
  (`symbol_place_tool.dart:384-399`) → `rotate`, `mirror`; (c) an **armed
  symbol** the palette or filter newly refuses → the fallback to select;
  (d) a door's **Flip hinge / Flip swing**, a wall's **justification**,
  the **dimension kind** (`selection_panel.dart:986, :962, :834`) → S-10;
  (e) the Layer panel's **make current, visibility, lock, colour, rename,
  add, delete** and the Page panel's **preset, orientation, scale, unit,
  separator, grid, snap, page breaks, swatches** → `editLayers`,
  `editPage`; (f) the **Fill row** beside F → shown and bound only while
  a fill-capable tool (Polyline, Rectangle, Circle) is allowed; (g) a
  **selection held across a change** to `selectTablesOnly` → pruned to
  tables; (h) a **drag in progress across a change** → its gate re-read
  at the up, a closed one cancels. The results note carries the full
  table, F-15's paths included, each with its flag and killer.
- **S-10. Which flag governs the object fields and Change size.** C-5
  names none for a box's, wall's, opening's, room's or dimension's own
  fields, nor for the Size menu. *Recommended:* `reshape` (an object's own
  shape and parameters, as its grips; false in `tablesOnly` and
  `readOnly`).
- **S-11. Hidden or disabled, and "a hidden panel's state is kept".**
  *Recommended:* a palette row, a button or a menu whose flag is false is
  not shown; a value field or a segmented value is shown read-only; a
  hidden right-column panel is kept offstage (`Visibility(maintainState:
  true)`, focus excluded), so its state survives; the shell's own state
  (the left tab, the search text, the tools' settings) is kept as it is
  today.
- **S-12. The profiles' unstated fields, `tools` without select, and
  `copyWith`'s null.** *Recommended:* **`full`**: every tool, every flag
  true, `symbolFilter` null. **`tablesOnly`**: tools `{select, symbol}`;
  `symbolPalette` true, `symbolFilter` the tables (`seats != null`, a
  static tear-off so the value stays `const`); `selectionPanel` true;
  `layerPanel`, `pagePanel`, `editLayers`, `editPage` false;
  `selectTablesOnly` true; `move`, `rotate`, `delete`, `renumber`, `undo`
  true; `mirror`, `reshape`, `changeLayer` false; `export`, `print`,
  `rulers`, `grid`, `snapping` true. **`readOnly`**: tools `{select}`;
  `symbolPalette` false; `selectionPanel`, `layerPanel`, `pagePanel` true
  (read-only); `editLayers`, `editPage`, `selectTablesOnly`, `move`,
  `rotate`, `mirror`, `reshape`, `delete`, `renumber`, `changeLayer`,
  `undo` false; `export`, `print`, `rulers`, `grid`, `snapping` true
  (none is an edit). A `tools` set without `select` is an `ArgumentError`
  at build. `copyWith(symbolFilter: null)` keeps the filter (Flutter's
  convention); a host clears it by starting from `full`. `==` compares
  `symbolFilter` by `==`: a closure written in `build` makes each build a
  change, which re-applies (cheap); the guide recommends a static function
  or a method tear-off.
- **S-13. The left column under `readOnly`.** It would hold the Select
  row alone. *Recommended:* the column is built only while it holds more
  than the Select row or the Symbols tab; the canvas then starts at the
  rulers, and the view re-measures it (Task 2's mechanism).
- **S-14. What `snapping` turns off.** *Recommended:* the user's control
  (F3, the OSNAP read-out) **and** object snap itself for the editor's
  tools and drags while false; the user's setting is kept and returns
  with the flag. Grid snap stays the page's setting (`editPage` governs
  it).
- **S-15. `selectTablesOnly`'s pick.** The engine's pick returns the
  topmost hit only (`spatial_index.dart:793`); filtering it would miss a
  table under a wall line, a room's edge or a dimension. *Recommended:*
  under `selectTablesOnly` the select tool picks by the table picker (a
  table's top, else its box, a finger's reach for touch), skipping locked
  layers as `QueryFilter.picking` does, and a band keeps tables only; a
  servable instance inside a group is no table (T1) and is unreachable.
- **S-16. What `shortcuts: false` unbinds, and Delete.** C-7 lists the
  service's chords and the editor's letters, F3, F and Delete.
  *Recommended:* every key jet-cad binds while no gesture runs: both
  modes' chords, the letters, F3, F, the shell's Escape, the select
  tool's idle Delete, Backspace and Escape, the table tool's idle Escape;
  a gesture's own keys stay (a drag's Escape and Shift, a drawing tool's
  Escape and Enter, the symbol tool's R and M while armed). Delete has no
  other path and the API no delete command, so under `shortcuts: false`
  nothing deletes in the editor: recorded as a limit in the guide (R-1
  forbids adding one here).
  **Ruled otherwise by the controller:** a host that owns the keyboard
  (Monépro's `PosShortcutsHost`, F-3) must still be able to delete, so
  the controller gains `bool deleteSelection()` (P-3: a command is a
  controller method): in the design mode, with an editor mounted and
  `delete` allowed, it deletes the editor's selection exactly as the
  select tool's idle Delete does (one undo step, the same compound, the
  table-data expander), and answers true; false otherwise (the selection
  mode, no editor, nothing selected, `delete` refused, a gesture part-way).
  The spec's C-3 is amended to name it (R-1's revision). It belongs to
  Task 6 with its own killers: under `shortcuts: false` the Delete key
  deletes nothing while `deleteSelection()` deletes and undo restores;
  under `readOnly` it answers false.
- **S-17. `editorSelectedTables` beside `selectedTables`.** In the design
  mode they are equal. *Recommended:* keep it (C-6 names it) as the
  design's numbers in the design mode and empty in the selection mode, so
  a host side panel needs one listenable.
- **S-18. "Exactly one numbered table".** *Recommended:* the selection
  holds exactly one key, and it is a numbered root-level table (two
  tables sharing a number, or a table with a wall, show none); the
  inspector belongs to the Selection panel (hidden with
  `selectionPanel: false`); it is built at each selection or document
  change and each host rebuild, never on pan or zoom.
- **S-19. Host widgets in the bars.** *Recommended:* placed as given,
  outside the toolbar's `ExcludeFocus`, inside a `ShellShortcutGuard` so a
  host field takes its keystrokes; laid out at the bar's height.
- **S-20. A bar's `actions` and the chords.** *Recommended:* `actions`
  shapes the bar only; a chord follows the capabilities and `shortcuts`
  (a host that hides the bar's Undo keeps Ctrl+Z).
- **S-21. F-9: "Both modes take `autofocus` (`service_view.dart:349`;
  `interaction_layer.dart:454`)".** Both are hard-coded `autofocus: true`
  (`service_view.dart:480`, `interaction_layer.dart:484`), and in the
  selection mode both `Focus` nodes autofocus. `InteractionLayer` takes no
  such parameter. *Recommended:* a new optional
  `InteractionLayer.autofocus` (Task 3) and `PlannerView.autofocus` (Task
  6); F-9 amended. F-11's and F-15's line references moved since
  `85905bd` (the bar `:352-390` → `:483-522`, its chords `:333-341` →
  `:471-478`; `selection_panel.dart`'s Mirror `:656-670` → `:1109-1114`
  and `_mirrorSymbol` `:655-667`, Change size `:674-690` → `:1115-1133`
  and `_changeSize` `:671-689`); F-14's Delete
  (`select_tool.dart:707-714`) is now `:705-715`. Nothing else in them.
- **S-22. `editorCapabilities` in the selection mode.** *Recommended:*
  none: the capabilities are the editor's; the selection mode is
  governed by `serviceBar`, `serviceMoves` and the rest, as today.
- **S-23. `FloorPlanSymbol.name`.** *Recommended:* the library's stored
  (English) name, stable for a filter; the palette shows the UI's words,
  as today.
- **S-24. F-12: "a `CommandDispatcher`'s permissions are fixed at
  construction".** The field is mutable (`jet_cad_2d` `undo.dart:107`);
  nothing in `lib` assigns it after construction. *Recommended:* F-12
  amended; V-5's ruling stands on its other grounds (a host's own
  `setTableData`, `undo()` and `load` go through the dispatcher and must
  stay allowed under every profile, and placing a symbol is `structure`,
  so `DraftPermissions` cannot express `tablesOnly`).
