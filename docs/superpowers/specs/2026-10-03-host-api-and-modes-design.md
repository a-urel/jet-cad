# Host API and the two modes (14b-2) — design

**Date:** 2026-10-03. **Status:** design, **revision 2**: revision 1
(`efd013e`) reviewed independently, "Ready with fixes" (R-1 to R-15),
each applied in [Revision 2](#revision-2), which is binding where it
differs from the text above it. **Sub-project:**
14 (restaurant embedding), slice **14b-2**.
**Umbrella:** [2026-10-03-restaurant-embedding-design.md](2026-10-03-restaurant-embedding-design.md)
(revision 3, approved): decisions 1, 6, 7, 11, 12 and D8–D12, D19 are
this spec's input, **amended here** where marked (A-1 to A-3).
**Approval:** the human, 2026-10-03, while travelling: *"çok gerekmedikçe
benden onay isteme şimdilik"* (do not ask for approval unless really
needed). The umbrella's 14b-2 decisions were approved already; this spec
details them and is reviewed independently before its plan. Its
amendments are recorded for the human's later look, not blocking.
**Branch:** `claude/exciting-pasteur-9m22jv`; facts at `8e86bdb`.
**Size:** L. **Packages touched:** `jet_cad_floor_plan` (the host API,
the shell's seams, the export bytes), `apps/floor_planner` (the export
helpers move), new `apps/restaurant_demo`. Engine and render: untouched.

## What it delivers

A Flutter host embeds the planner with a **controller** and a **view**:

```dart
final plan = FloorPlanController(symbolSources: [
  furnitureSymbolSource, restaurantSymbolSource]);
plan.load(json);                       // the host's storage
FloorPlanView(controller: plan, onExport: (e) => save(e.bytes, e.fileName));
plan.setMode(FloorPlanMode.selection); // service
plan.select({'4', '12'});
plan.mode.value;  plan.selectedTables.value;  plan.tables;
plan.designJson();  plan.dirty.value;  plan.markSaved();
```

The **design mode** is today's editor (palette, tools, the Table
section, Export, Print). The **selection mode** is the canvas alone, under
`runtime` permissions, on a **service copy** of the plan: what happens
there never reaches the design, its Undo never reaches a design edit. A
demo app, `apps/restaurant_demo`, shows two dining areas, a Design /
Service toggle and the API's callbacks; it has every platform's runner.

Not here: table picking by tap, status colours, moves by drag in the
selection mode (14c); touch gestures (14t). The selection mode of 14b-2
shows the plan, follows `select(...)` with outlines, and pans and zooms
with today's gestures.

## Facts established (at `8e86bdb`)

- **F-1. The shell owns its document's world.** `PlannerShell` builds its
  page notifier, index, resolver, camera, selection, outlines, grips,
  tools and both systems from the document it is given
  (`planner_shell.dart:139-180, 344-382`), and is keyed by the document
  in the app (`document_host.dart:617-618`): a new document is a new
  shell. `snap` is the precedent for a host-owned object the shell uses
  and does not dispose (`planner_shell.dart:73-75, 170-171`).
- **F-2. Clean is a state id.** The app's `DocumentSession` is clean iff
  `commands.stateId` equals its save point, recomputed on every change
  (`document_host.dart:45-56, 105-109`); `stateId` moves only through the
  dispatcher (`undo.dart:163-180`).
- **F-3. One history per dispatcher, no floor.** `CommandDispatcher` has
  `clearHistory` (both stacks) and no undo floor or redo-only clear
  (`undo.dart:248-280`); a redo under `runtime` of a design edit throws
  `PermissionDeniedError` (umbrella F-14).
- **F-4. The codec round-trips a plan exactly**, handles included
  (`DraftDocumentCodec.encodeToString` / `decodeString` with
  `registerComponents: registerAppComponents`,
  `document_host.dart:437-441, 480-486`), so a decoded copy names every
  table, label and layer by the same handle.
- **F-5. Export and Print are the app's flows** over package pieces:
  `export_flow.dart` (app) holds `exportPageOf`, `exportOmitOwners`,
  `exportBytes`, `exportPdfBytes`, `printPageFormat` — no file access but
  `exportFileKind`/`exportFileName`, which name `FileKind`
  (`apps/floor_planner/lib/export/export_flow.dart:15-74`); the dialog
  (`export_dialog.dart:39-44`), the font (`export_font.dart`) and the
  printer (`page_printer.dart:10-30`) are already in the package.
- **F-6. The shell's commands** are `ShellCommand`s
  (`shell_commands.dart:70-130`); the host passes its file commands
  (`fileCommands`), and Export and Print take the shell's page condition
  (`kPageCommandIds`, :60).
- **F-7. `PlannerView` fits once**, after its first frame
  (`planner_view.dart:63, 85-104`), to the page or the extents.
- **F-8. The package's main barrel is empty** (14b-1 V-8); `editor.dart`
  exports every `src/` file for the app.
- **F-9. The selection follows the document.** `SelectionController`
  prunes keys a change removes (`selection.dart`), and a table's number
  is read through `TableSurvey` (14a T15).

## Decisions

### The two documents

- **H1. The design document and the service copy** (amends D12, **A-1**).
  The controller holds the **design document**: the one the host loads,
  saves and edits in the design mode, with its own history. Entering the
  selection mode decodes a **service copy** from the design's encoding
  (F-4) with `DraftPermissions.runtime`; the selection mode shows and
  edits only the copy; leaving it disposes the copy. So:
  - the selection mode's Undo and Redo reach only service edits: the
    copy's history starts empty (decision 7, M-14f, with no engine floor,
    F-3);
  - the design's own Undo and Redo are untouched by a visit to the
    selection mode, both stacks (the umbrella cleared redo; nothing needs
    that now);
  - service edits never touch the design: `designJson()`, `dirty` and the
    design's history ignore them (decision 11);
  - `resetLayout()` rebuilds the copy from the design (D12);
  - entering the design mode discards the copy (D12); the demo asks first
    when the copy has edits (`serviceEdited`).
  The umbrella's undo floor and redo clear were a way to keep one history
  honest across two modes; two documents make the barrier structural.
  Cost: one encode and one decode per entry into the selection mode and
  per `resetLayout`, at user rate.
- **H2. Handles are the copy's too** (F-4): a table's instance and label
  have the same handles in both documents, so a number resolves the same
  way in either.

### The controller

- **H3. `FloorPlanController`** (`ChangeNotifier`), in
  `src/host/floor_plan_controller.dart`:
  - `FloorPlanController({List<SymbolLibrarySource> symbolSources =
    const [furnitureSymbolSource], String? json})`: owns the symbol
    loader and thumbnails (one each, for its life), the design document
    (from [json], else `newDocument`) and its measurer.
  - `void load(String json)`: decodes a new design document (app
    components, F-4); on a decode error throws a `FormatException` and
    leaves everything as it was. On success: the old documents are
    disposed after the next frame (the app's rule,
    `document_host.dart:118-140`), the save point is the new state,
    `selectedTables` is cleared, and in the selection mode the service
    copy is rebuilt from it. Notifies.
  - `void newPlan()`: the same with `newDocument`.
  - `String designJson()`: the design document's encoding, whatever the
    mode (D9, H1).
  - `ValueListenable<bool> dirty`, `void markSaved()`: clean iff the
    design dispatcher's `stateId` is the save point (F-2).
  - `ValueListenable<FloorPlanMode> mode`; `void setMode(FloorPlanMode)`
    (H1); `bool get serviceEdited`: the copy's `undoDepth > 0`.
  - `void undo()`, `void redo()`, `ValueListenable<bool> canUndo`,
    `canRedo`: the **active** document's (design or copy).
  - `List<FloorPlanTable> get tables`: the active document's live tables
    (14a T15), each `(number, seats, symbolKey)`, unnumbered ones with a
    null number, ascending by handle; computed per document change, not
    per call (cached).
  - `ValueListenable<Set<String>> selectedTables`: the numbers of the
    tables selected in the active view; anything selected that is not a
    numbered table is not in it. `void select(Set<String> numbers)`:
    selects every live table carrying one of [numbers] (a duplicated
    number selects both, umbrella D5), replacing the selection; unknown
    numbers are ignored. Both modes.
  - `void fitToView()`: the active view fits as on its first frame (F-7);
    14t frames the tables instead (D17).
  - `void resetLayout()`: selection mode only (H1).
  - `void dispose()`.
  Callbacks carry numbers, never handles (D18).
- **H4. The active view's state is the controller's** where the API needs
  it: the controller owns one `SelectionController` per active document
  and passes it to the view, as `snap` is passed (F-1); the view never
  disposes it. `fitToView` is a request the view listens to.

### The view

- **H5. `FloorPlanView({required controller, onExport, printer})`**,
  in `src/host/floor_plan_view.dart`: builds, keyed by the active
  document,
  - in the **design mode**: `PlannerShell` with the controller's document,
    selection, symbol loader and thumbnails, and two file commands,
    **Export** and **Print** (decision 6, H6); no document name, no file
    dialogs (D9);
  - in the **selection mode**: `ServiceView` (H7).
- **H6. Export and Print, both modes** (decision 6, D9). The pure export
  helpers move from the app to the package (`src/export/export_bytes.dart`:
  `exportPageOf`, `exportOmitOwners`, `exportBytes`, `exportPdfBytes`,
  `printPageFormat`; the app keeps `exportFileKind`/`exportFileName` and
  imports the rest). Export asks the existing dialog, then hands
  `FloorPlanExport(bytes, fileName, mimeType)` to `onExport`; the file
  name is `plan.pdf` / `plan.png` unless the host passes `exportName`.
  Print hands the PDF to `printer` (default `PrintingPagePrinter`). In
  the selection mode both plot the **service copy** (what is on screen);
  status colours never plot (14c D13). With no `onExport`, Export is not
  offered.
- **H7. `ServiceView`** (`src/host/service_view.dart`): the canvas alone —
  rulers, page chrome, `DraftCanvas`, the selection outlines — through
  `PlannerView` with a tool controller whose only tool is an **idle tool**
  (no pick, no band, no grips, no keys; 14c replaces it with
  `TableSelectTool`), a top bar with Undo, Redo, Export, Print, and the
  keyboard's Undo/Redo chords. No palette, no panels, no affordance that
  needs `geometry` or `structure` (D11, M-12a); grips are not shown.
- **H8. The shell's seams** (`planner_shell.dart`): optional `selection`
  (the host's, not disposed; the shell's own otherwise) and optional
  `fitRequests` (`Listenable`; each notification refits). A bare shell
  and the app's shell are unchanged.

### The public barrel

- **H9. `package:jet_cad_floor_plan/jet_cad_floor_plan.dart`** exports
  exactly: `FloorPlanController`, `FloorPlanView`, `FloorPlanMode`,
  `FloorPlanTable`, `FloorPlanExport`, `ensureFloorPlanFonts`,
  `SymbolLibrarySource`, `furnitureSymbolSource`, `PagePrinter`,
  `PrintingPagePrinter`. Nothing else of `src/` (D8): a host that needs
  more is a finding for the API, not a reason to import `editor.dart`.

### The demo

- **H10. `apps/restaurant_demo`** (D19): every runner (Android, iOS,
  macOS, Windows, Linux, web; `flutter create --platforms ...`), the bare
  `Roboto` family declared (14b-1 V-11a), both symbol sources. Two dining
  areas (**Salon**, **Teras**), each a controller and an in-memory JSON
  string (decision 12), a segmented Design / Service toggle (asks before
  discarding service edits), a number field and a Select button driving
  `select`, a small log of `selectedTables`, `mode`, `dirty` and exports.
  Example and integration surface, not a product; its widget tests drive
  the API end to end.

## Amendments to the umbrella

- **A-1 (D12).** The barrier is a separate service document (H1), not an
  undo floor with a cleared redo; the design's redo survives a visit.
- **A-2 (D8).** `setTableStatus`, `TableStatus`, `onTableTap`,
  `onLayoutChanged` and `onSelectionChanged` come with 14c, where taps,
  statuses and moves exist; 14b-2's `selectedTables` is the listenable
  that a callback would wrap. `tables` carries no `hidden` flag until 14c
  (D14).
- **A-3 (D9).** Export and Print in the selection mode plot the service
  copy, the layout on screen.

## Files

- New: `packages/jet_cad_floor_plan/lib/src/host/{floor_plan_controller,
  floor_plan_view,service_view,floor_plan_types}.dart`,
  `lib/src/export/export_bytes.dart`; the barrel
  `lib/jet_cad_floor_plan.dart`.
- Changed: `lib/src/planner_shell.dart` (H8), `lib/editor.dart`;
  `apps/floor_planner/lib/export/export_flow.dart` (helpers moved),
  its importers.
- New app: `apps/restaurant_demo/` (pubspec in the workspace; runners;
  `lib/main.dart`; `test/`).
- Tests: `packages/jet_cad_floor_plan/test/host/{controller_test,
  barrier_test,view_test,barrel_test}.dart`;
  `apps/restaurant_demo/test/demo_test.dart`.

## Invariants

- `designJson()` after any number of selection-mode edits, undos and
  redos equals `designJson()` before entering it, byte for byte; `dirty`
  is unchanged.
- In the selection mode, Undo never changes the design document, and no
  sequence of Undo/Redo there applies a design-mode command.
- Leaving and re-entering the selection mode shows the design's layout
  (service edits discarded); the design's undo and redo stacks are the
  same length before and after.
- A number resolves to the same table in both documents (H2).
- The service view offers nothing that needs `geometry` or `structure`;
  a dispatcher spy sees no refused command from the UI (M-12a).
- The app (`apps/floor_planner`) behaves as before; its tests pass
  unchanged but for imports.
- Engine and render packages untouched; the allocation invariants
  untouched; no golden PNG changes.

## Testing and named mutants

Fixtures: plans with tables placed off the origin, turned and mirrored,
two tables sharing a number (from a hand-edited JSON), a wall.

- **M-14f (umbrella):** the service copy is the design document itself —
  a selection-mode `TransformNodeCommand` on a table changes
  `designJson()`; selection-mode Undo after a service move, repeated,
  never undoes the wall placed in the design mode; Redo never redoes it.
- **M-14b2-1:** `dirty` follows the active document — a service move sets
  `dirty`.
- **M-14b2-2:** leaving the selection mode keeps the copy — re-entering
  shows the moved table.
- **M-14b2-3:** `load` keeps the old selection or the old copy —
  `selectedTables` empty after `load`; in the selection mode, the copy is
  the new plan's.
- **M-14b2-4:** `select` resolves one table per number — a duplicated
  number selects both.
- **M-14b2-5 (umbrella M-14e):** `selectedTables` carries handles, or a
  stale number after a renumber — renumbering a selected table updates
  `selectedTables`.
- **M-14b2-6:** the service copy decoded with `all` permissions — a
  `geometry` command through the copy's dispatcher is refused.
- **M-14b2-7:** Export in the selection mode plots the design — a PDF
  exported after a service move differs from one exported before it
  (byte compare), and equals the design's after `resetLayout`.
- **M-14b2-8:** `load` of a bad string replaces the document — the old
  plan, mode and selection stay; a `FormatException` is thrown.
- **M-14b2-9:** the barrel leaks `src/` — a test lists the barrel's
  exported names (analyzer over the file) and compares them with H9's.
- **M-14b2-10:** the shell disposes a host selection — the controller's
  selection survives a shell swap (mode change) and keeps listening.

## Risks

- **Two documents in memory** in the selection mode: a floor plan is
  500–5,000 entities; one more copy is a few MB at most.
- **The demo's runners** add many generated files; they are generated by
  `flutter create` and reviewed only for their identifiers
  (`com.jetcad.restaurant_demo`).
- **The shell's two seams** (H8) touch the most-tested widget; every
  shell and app test runs unchanged.
- **14c's moves** run on the copy and are lost on leaving the selection
  mode or on `load`; a host that wants service moves to outlive a
  restart needs a later `serviceJson()` (not in v1; decision 11 says
  "for the service or until undone").

## Revision 2

Applied from the independent review of revision 1. The review found the
three amendments sound and the facts accurate (F-6's line is :61; F-8:
`editor.dart` does not export `src/tables/table_rotate.dart`; F-9: the
selection also prunes keys on hidden or locked layers,
`selection.dart:174-196`).

- **R-1 → H11, the settle.** `FloorPlanView` passes the shell the
  existing `onSettle` registrar (`planner_shell.dart:107, 569`); the
  controller keeps the registered settle and calls it, synchronously,
  first in `designJson`, `setMode`, `load`, `newPlan`, `undo`, `redo`,
  `markSaved`, `resetLayout`, `select` and before Export and Print read
  the document. `undo`/`redo` re-read `canUndo`/`canRedo` after it, as
  the shell's own do (`planner_shell.dart:463-476`). Mutant **M-14b2-11**:
  `setMode` without the settle — a value typed in the Selection panel is
  in the copy, and `designJson()` before the switch equals the one after
  the panel unmounts.
- **R-2 → H12, dropping a document.** One rule for every document the
  controller lets go (the copy on `setMode(design)`, on `resetLayout`, on
  `load`/`newPlan`; the old design on `load`/`newPlan`): its
  subscriptions are cancelled at once; the document, its measurer and its
  `SelectionController` are disposed in a post-frame callback with
  `ensureVisualUpdate` (`document_host.dart:118-140`); `dispose()`
  disposes any still pending at once. Controller tests run under the
  widgets binding. Mutant **M-14b2-12**: the copy disposed synchronously —
  `setMode(design)` then a pump throws.
- **R-3 → M-14b2-7 restated.** A PDF carries a random `/ID`; the export
  comparison uses **PNG bytes** (deterministic) or the content operators
  through `export_testing.dart`'s `PdfContent`, on a table off the origin
  and turned.
- **R-4 → H1 detailed.** The copy is decoded with a `FlutterTextMeasurer`
  of its own, `registerAppComponents`, `permissions: runtime` and
  `diagnostics: []`. The **ServiceView** installs `installParametric` then
  `TableLabelSystem` on it, and disposes them in reverse (as the shell
  does, `planner_shell.dart:566-567, 610-614`), so 14c's moves behave as
  in the design mode; under `runtime` a `TransformNodeCommand` stays
  `transform` through both wrappers (`table_label_system.dart:69,
  104-107`).
- **R-5 → H7, H8 detailed.** `PlannerView` (added to Files) gains an
  optional `fitRequests` (it keeps its last size and fits post-frame on
  each notification) and makes `grips` and `textTool` optional (no grips
  when null: `ToolContext.grips` stays null, `tool.dart:65-67`;
  `selection_overlay.dart:193-204`). The shell forwards `fitRequests`.
  The ServiceView's Export/Print take the page condition
  (`kPageCommandIds`).
- **R-6 → H13, selection.** `select` selects the live, numbered tables
  carrying the numbers **that the selection can hold** — visible and on
  an unlocked layer; others are ignored, documented (14c revisits locked
  tables for statuses, D14). The selection **survives** a mode switch
  and `resetLayout` (the same numbers are re-selected in the new
  document; handles are equal, H2). The controller subscribes to a
  document after constructing its selection, so pruning runs first
  (`planner_shell.dart:341-343`).
- **R-7 → H3 `tables`.** Cached by (document identity,
  `commands.stateId`), recomputed lazily on read. Mutant **M-14b2-13**: a
  renumber executed, then `tables` read in the same synchronous block,
  shows the new number.
- **R-8 → H3 `markSaved`.** `markSaved()` marks the state captured by the
  **last `designJson()`** (the app's S-2 rule, `document_host.dart:480-486,
  515-520`): an edit that lands while the host writes stays dirty.
  Mutant **M-14b2-14**: `designJson()`, an edit, `markSaved()` — `dirty`
  stays true.
- **R-9 → H6 guarded.** Export and Print keep a busy flag of the view's
  (a second press does nothing), check `mounted` before the dialog, and
  after every await go on only if the document is still `identical` to
  the controller's active one. The export font cache and the last
  `ExportChoice` are the controller's, for its life.
- **R-10 → H5, H9 detailed.** `FloorPlanView({required controller,
  onExport, printer, exportName = 'plan'})`. The barrel adds
  `registerFontLicences`; `PagePrinter.print` names `PdfPageFormat`, so a
  host implementing its own printer depends on `pdf` (documented). Every
  barrel export uses `show`; M-14b2-9's test reads the `show` lists as
  text (no `analyzer` dependency) and a compile test uses each name
  through the barrel alone.
- **R-11 → H3 symbols.** The controller takes optional shared `symbols:`
  (a `SymbolLibraryLoader`) and `thumbnails:` (not owned when passed, as
  `snap`); otherwise it builds its own with `symbolSources` and a
  thumbnail capacity of **128** (the app's, `main.dart:22`). The loader's
  `load()` is called when the design view first mounts (the binding
  exists then), once. The demo shares one loader and one cache between
  its two controllers.
- **R-12 → H10 detailed.** `flutter create --no-pub --org com.jetcad
  --project-name restaurant_demo
  --platforms=android,ios,macos,windows,linux,web`; the pubspec set to
  `resolution: workspace`, `sdk: ^3.5.0`, `flutter: ">=3.44.0"`, path
  dependencies on both packages; added to the root `workspace:` list
  (Changed); the generated counter app and its test deleted; macOS
  `com.apple.security.print` in both entitlements (as the app's); its
  initial `analysis_options.yaml` committed once (14b-1's rule); the demo
  joins the gate.
- **R-13 → H14, the camera; the demo's diagnostics.** The controller keeps
  the active view's last camera (`ViewportTransform`) and hands it to the
  next view as `initialCamera`, so a mode switch or `resetLayout` keeps
  pan and zoom; `fitToView` and `load` reset it. The demo shows
  `TableSurvey`-style numbering diagnostics through a controller getter,
  `List<String> numberingWarnings` (duplicate and unnumbered tables, as
  text), umbrella D5.
- **R-14 → M-14b2-8's fixtures.** Valid JSON with a broken structure (a
  `TypeError` inside the decoder) and an unsupported `schemaVersion`
  (`SchemaVersionError`) are both rethrown as `FormatException`; the
  state before is the selection mode with a non-empty selection and a
  moved copy, and all three survive.
- **R-15 → M-14b2-3's fixture.** The loaded plan is the same JSON with
  one table moved (same handles, same numbers): `selectedTables` is empty
  after `load`, and the copy's moved table has the new plan's transform.

