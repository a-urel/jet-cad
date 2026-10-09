# The host embedding API (umbrella) — design

**Date:** 2026-10-09. **Status:** design, **revision 1**, for independent
review.

**Asked for by the human, 2026-10-08:** *"Monépro entegrasyonuna geç. Önce
beyin fırtınası. Temel nokta, başka bir uygulamaya gömecek esnekliğe
sahip olması. property ve callback-functions ile program tarafından
tamamen özelleştirilebilmeli."* The planner must embed in **any** host
app, customisable entirely by properties and callbacks; Monépro is the
first host, not the only one.

**The human's rulings in the brainstorm (2026-10-09; asked and answered,
paraphrased):**

- **Scope:** all four areas: per-table host widgets; a look/theme object;
  the toolbars and the editor's capabilities; events and camera control.
- **Shape:** one umbrella spec (this one: shared principles and the API
  shape of all four areas), implemented as **four slices**, each its own
  plan, review and merge, in the order below.
- **Per-table content:** a **builder** (the host's widget per table,
  positioned by jet-cad, not rebuilt by pan or zoom) **plus** a geometry
  API (world↔screen, table boxes, a camera listenable) for a host that
  builds its own overlay. Today's painted fill and caption stay, optional.
- **Zoom behaviour of that widget:** the host chooses; the default is a
  fixed size pinned to the table's centre.
- **The editor's restriction:** capability **flags plus ready profiles**
  (`full`, `tablesOnly`, `readOnly`), adjusted with `copyWith`.
- **Toolbars:** **both** roads: jet-cad's bar with host items added or
  built-ins hidden, **and** the bar switched off with every command and
  its `canX` exposed so the host builds its own; a dialog hook (export).
- **The look:** a `ThemeExtension` (`FloorPlanTheme`) **plus** a view
  parameter that overrides it.
- **Events:** today's split continues: user gestures are **view
  callbacks**; state changes are **controller listenables or streams**;
  commands are controller methods.
- **Host data on a table:** **yes**, a table carries a host map (e.g. the
  database id) **stored in the plan**. The human accepted schema 9 as its
  price; [E-9](#e-9-the-schema-stays-8) finds the price is not owed and
  asks for confirmation (Q-H1).

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `85905bd`
(release 0.3.0 + its STATUS). **Size:** L in total; each slice S–M.
**Touched:** `jet_cad_floor_plan` above all; `jet_cad_2d_flutter` (the
palette's colours become parameters, Slice 3; the camera's bounds,
Slice 1); `jet_cad_2d` only if [E-9](#e-9-the-schema-stays-8) is
overturned; `apps/restaurant_demo`, `tool/ci/host_probe`, the host
guide, the CHANGELOG in every slice.

## Facts (at `85905bd`)

**Monépro** (`monepro-frontend`, `develop @ 88c96e0`, read only).

- **F-1. Spec 103 B.1** (`:879-882`): jet-cad is reached through one
  adapter; status is drawn *"as Flutter widgets positioned with
  `camera.worldToScreen`"*, not by recolouring the geometry. **D22**
  (`:243`): a table shows empty or occupied (guests, age) plus badges
  (unsent, sıra waiting, ready, bill printed, part-paid). **SH** (`:276`):
  several open tabs per table, aggregated. None of this fits one colour
  and a 12-character caption.
- **F-2. D21** (`:239`): identity lives in the database; the drawing is
  *"linked by an app component carrying the table's id"*. **App. A**
  (`:835`): `pos_tables (id, location_id, code, capacity, zone,
  is_active)`. jet-cad links by the number alone (Q-Z4).
- **F-3. B.2** (`:886-890`, `:913`): zone tabs, "My tables", a long-press
  menu, and in phase 2 "edit floor drawing", beside "unplaced tables".
  §5.3 (`:401`): a waiter may claim, move, merge a table; editing the
  drawing is not covered (a manager's).
- **F-4. Monépro's UI** is shadcn_ui; feedback is `ShadToaster` /
  `ShadDialog`, never a Material `SnackBar` (`wiki/conventions/ui.md:26-45`);
  its Material `ThemeData` is built from the Shad theme with
  `ColorScheme.fromSeed` (`lib/app.dart:149-190`), so a planner that reads
  only `ColorScheme` cannot match shadcn tokens exactly.

**jet-cad** (paths under `packages/jet_cad_floor_plan/lib/src/` unless
named).

- **F-5. The host barrel** exports through `show` lists only;
  `test/host/barrel_test.dart` pins the exact name set. `@internal` marks
  controller members only the views use.
- **F-6. `FloorPlanTable`** (`host/floor_plan_types.dart:20-60`) is a
  `final class` of `number`, `seats`, `symbolKey`, `visible`; no position,
  size, rotation, layer, lock or host data. `TableInfo` and `TableSurvey`
  (`tables/table_index.dart`) read tables at document-change rate.
- **F-7. The camera.** `FloorPlanController.camera` is an `@internal`
  `CameraController` (`host/floor_plan_controller.dart:205-209`), a
  `ValueNotifier<ViewportTransform>` (`jet_cad_2d_flutter`
  `camera_controller.dart:44`) with **final** `minScale` / `maxScale`
  (here `kMinScale = 0.001`, `kMaxScale = 100`, `startup_plan.dart:50-51`),
  `panBy` and `zoomAt`. `ViewportTransform.worldToScreen` / `screenToWorld`
  exist (`viewport_transform.dart:56-59`) and map **world millimetres,
  y up** to the **canvas's** local logical pixels (the drawing area,
  without the editor's panels and rulers). The controller records each
  mode's canvas origin (`canvasMeasured`, `:464-470`, R-13).
- **F-8. Table geometry** has one source: `TablePicker.candidatesOf`
  (`service/table_picker.dart:233`) yields `TableCandidate{transform, box,
  corners, worldBounds, locked}` (`:103-137`); the fit, the veil and the
  group frames share it; a table with non-finite corners is no candidate.
  `TablePicker.pick` answers "which table is here" (top, then box, then
  finger reach; `:270-306`).
- **F-9. Paint slots.** `PlannerView` has `underlay` and `overlay` widget
  slots (`planner_view.dart:100-110`); the service view fills them with
  `CustomPaint` stacks (`host/service_view.dart:423-460`). Every painter
  prebuilds its paths at status, group or plan rate and counts its
  allocations (`debugAllocations`), tested.
- **F-10. Fixed look.** Status caption 11 px, ink `0xFF202020` or white
  (`service/table_status_painter.dart:39-43`; `jet_cad_2d_flutter`
  `canvas_palette.dart:206-210`); group frame `PaperPalette.gripMove`,
  margin 150 mm, 2 px, chip 11 px (`service/table_group_painter.dart:21-52`);
  selection `PaperPalette.selection`, 2 px (`selection_style.dart:9`);
  veil the paper at 0.6 (`service/table_focus_painter.dart:17`). The views
  read `colorScheme.surface`, `surfaceContainer`, `surfaceContainerLow`
  (`host/service_view.dart:291-394`; `planner_shell.dart:902-989`).
- **F-11. Fixed chrome.** The service bar (`host/service_view.dart:352-390`)
  is 44 px of Undo, Redo, Merge, Split (shown only with their callbacks),
  Export (only with `onExport`), Print (always). Export's dialog is a
  Material `AlertDialog` (`export/export_dialog.dart:43-63`). The editor
  (`planner_shell.dart`) has 15 tools (`:354-460`) with letter shortcuts,
  a 240 px left panel (Tools, Symbols), a 280 px right panel (Selection,
  Layer, Page), a top bar; its unused parameters include `fileCommands`,
  `documentName`, `snap`, `initialCamera` (`:74-157`).
- **F-12. Permissions.** The design plan always decodes with
  `DraftPermissions.all` (`host/floor_plan_controller.dart:137, 663`); the
  service copy with `runtime`. `DraftPermissions.readOnly` exists
  (`jet_cad_2d` `document/command.dart:56`); the shell already refuses
  drawing tools without `geometry` (`planner_shell.dart:638-648`).
  **Placing a symbol is `structure`** (it adds a node), so "tables only"
  cannot be expressed by `DraftPermissions` alone.
- **F-13. Service callbacks and options** are records read at each call
  or press (`service/table_select_tool.dart:20-45`; R-5); the drag knows
  the moved handles and the offset (`:101-106`). There is no double tap,
  hover, floor tap or which-table-moved event; `onLayoutChanged` carries
  nothing.
- **F-14. Components and unknown data.** A component is attached per
  handle (`doc.components.get<T>(handle)`); a reader that has **not
  registered** a type keeps its payload as preserve-unknown data
  (`jet_cad_2d` `document/component.dart:209-286`, spec 04 D9) and writes
  it back; `RemoveDefinition`/`AddDefinition` snapshot and restore every
  component, unknown ones included (`document/commands.dart:490, 552`).
  The planner has no copy, paste or duplicate command. Schema 7 bumped for
  a component (`jet_cad.object_layer`) because an older reader would have
  **drawn** the plan differently (`codec/schema_version.dart:25-31`).

## Principles (bind every slice)

- **P-1. Additive only.** No existing signature changes; every new
  parameter is named and optional; every default is today's behaviour.
  A 0.3.0 host compiles and behaves the same against every slice. The one
  semantic widening, `FloorPlanTable`'s `==` over new fields, is listed in
  the CHANGELOG.
- **P-2. Numbers stay the identity** (spec 14 D18). Callbacks, queries
  and commands name tables by number. Host data ([E-6](#e-6-host-data-on-a-table))
  rides beside the number and never replaces it; an opaque handle is
  never exported.
- **P-3. Where things live.** A user **gesture** is a `FloorPlanView`
  callback; a **state change** is a controller `ValueListenable` (for a
  current value) or `Stream` (for a sequence of changes); a **command** is
  a controller method. A view parameter is read at each build or press,
  never captured (R-5).
- **P-4. The frame path.** Pan and zoom rebuild **no widget** and allocate
  nothing per table in the painters (CLAUDE.md). Style values are read
  when a painter rebuilds, never per frame. Host overlay widgets are
  **repositioned** per camera change, not rebuilt; the cost per camera
  frame is O(overlays on screen) and is measured
  ([H-8](#h-8-the-overlays-cost)).
- **P-5. The service copy** (14b D11, D12). Nothing done in the selection
  mode reaches the design. Statuses, focus, overlays and the theme are
  never saved, exported, printed or undone.
- **P-6. Defaults are today's look.** With no theme, no builder and no
  capabilities, every pixel is what 0.3.0 draws: the golden and widget
  tests that pin today's look stay unchanged and green in every slice.
- **P-7. Every public addition is proven from outside.** It enters the
  barrel's `show` list and `barrel_test.dart`; the host guide documents
  it with a snippet that is also in `tool/ci/host_probe/lib/main.dart`
  (`check_guide`); the demo uses it.
- **P-8. One slice, one release.** Each slice ends merged on the human's
  word; whether it is released (0.4.0, 0.5.0, …) is the human's call. The
  CHANGELOG's *Unreleased* carries it until then.

## Slice 1 — geometry, camera, per-table widgets

Unblocks Monépro's B.1 and D22, closes Q-Z1.

### G-1. A table's geometry

`FloorPlanTable` gains, all named and defaulted so P-1 holds:

| Field | Type | Meaning |
|---|---|---|
| `center` | `Offset?` | the definition box's centre in **world millimetres, y up** |
| `size` | `Size?` | the box's width and height in millimetres, the instance's scale applied |
| `rotation` | `double` | radians, counter-clockwise in world space, 0 when `center` is null |
| `mirrored` | `bool` | the transform's determinant is negative |
| `corners` | `List<Offset>` | the four world corners, counter-clockwise; empty when not finite |
| `layer` | `String` | the instance's layer name |
| `locked` | `bool` | the layer is locked (it is picked, never moved) |

- The geometry is read from `TablePicker.candidatesOf`'s transform and
  box (F-8), the same numbers the fit, veil and frames use. A table that
  is no candidate (hidden layer, non-finite corners) has `center: null`,
  `size: null`, `corners: const []`.
- `tables` reports the plan **the current mode shows**: in the selection
  mode a service move changes `center` and `rotation`. `tables`
  notifies (through the controller's `ChangeNotifier`) when they change,
  at document-change rate.
- `==`, `hashCode` and `toString` cover the new fields.

### G-2. The camera, public

- `ValueListenable<FloorPlanCamera> get camera` replaces the `@internal`
  member of that name (the internal `CameraController` becomes
  `@internal cameraController`; no host could reach it).
- `FloorPlanCamera` (immutable, public) wraps a `ViewportTransform`:
  `double get scale` (logical pixels per millimetre),
  `Offset worldToCanvas(Offset world)`, `Offset canvasToWorld(Offset
  canvas)`, `Rect visibleWorld(Size canvas)` (y-up, world mm). **Canvas**
  is the view's drawing area, origin top-left.
- `Rect? get canvasRect` on the controller: the drawing area of the last
  laid-out view, in that view's global coordinates, null with none
  mounted; with it `Offset? worldToGlobal(Offset)` and `Offset?
  globalToWorld(Offset)`. A host overlay **outside** the view needs them;
  the builder of G-5 does not.

### G-3. Camera commands and bounds

- `FloorPlanController({…, double minScale = kMinScale, double maxScale =
  kMaxScale})`: the zoom bounds, in logical pixels per millimetre;
  `ArgumentError` unless `0 < minScale < maxScale`, both finite.
- `bool panBy(Offset canvasDelta)`, `bool zoomBy(double factor, {Offset?
  focus})` (focus in canvas pixels, default the canvas centre), `bool
  centerOn(Offset world, {double? scale})`. Each clamps to the bounds as
  `CameraController.zoomAt` does, and returns false, changing nothing,
  when no canvas has been measured (a view must have laid out once) or an
  argument is not finite. A camera command cancels a pending
  `fitToView` / `fitToTables` (the last request wins, as zone spec Z7).
- Pan and zoom by the user keep working; the commands are additions.

### G-4. A table at a point

`String? tableAt(Offset canvasPoint, {PointerDeviceKind kind =
PointerDeviceKind.mouse})`: the number of the table `TablePicker.pick`
answers there in the current mode (finger reach for touch), null for none
or for an unnumbered table. At call rate; no allocation bar.

### G-5. The per-table builder

`FloorPlanView` gains:

```dart
FloorPlanTableOverlayBuilder? tableOverlayBuilder; // null: no overlay at all
FloorPlanOverlayLayout tableOverlayLayout = const FloorPlanOverlayLayout();
Set<FloorPlanMode> tableOverlayModes = const {FloorPlanMode.selection};

typedef FloorPlanTableOverlayBuilder =
    Widget? Function(BuildContext context, FloorPlanTableOverlay table);
```

- `FloorPlanTableOverlay` (immutable): `FloorPlanTable table` (number,
  data from Slice 2, geometry), `bool selected`, `bool focused` (in the
  focus, or no focus set), `TableStatus? status`, `int detail` (G-7). It
  carries **no** screen position or scale: those change with the camera
  and would force a rebuild.
- The builder runs once per numbered, candidate table when the view
  builds, and again for a table when its `FloorPlanTableOverlay` changes
  (plan revision, selection, focus, status, detail band) or the host
  rebuilds the view. It never runs on pan or zoom. Returning null shows
  nothing for that table. A host that wants live data inside the widget
  uses its own state management there (`BlocBuilder`, `ValueListenableBuilder`).
- The overlays live in one layer above the canvas's painted layers (fills,
  drafting, veil, chips, selection) and below the service bar.
- **Pointers:** by default the layer ignores pointers, so taps reach the
  tables (`tableOverlayLayout.interactive = false`). With `true`, an
  overlay widget's own hit area takes the pointer and the table under it
  gets nothing there.

### G-6. Placement

`FloorPlanOverlayLayout` (immutable, `const`):

- `anchor: Alignment` (default `Alignment.center`): the point of the
  table's **screen bounding box** the widget is pinned to, and the
  widget's own alignment there (as `Align` would place it).
- `size: FloorPlanOverlaySize.natural` (default): the widget keeps its own
  size at every zoom, laid out once with loose constraints (max
  `maxNaturalSize`, default 200×120). `FloorPlanOverlaySize.box`: the
  widget is sized to the table's screen bounding box (tight constraints)
  and relaid out on each camera change.
- `minScale: double` (default 0): below this camera scale no overlay is
  shown (laid out or painted); the host's other way is G-7.
- Off-canvas overlays are neither laid out (for `box`) nor painted.

### G-7. Detail bands

`detailBreakpoints: List<double>` on `FloorPlanOverlayLayout` (default
empty), ascending camera scales. `FloorPlanTableOverlay.detail` is the
number of breakpoints at or below the current scale. Crossing a
breakpoint rebuilds every overlay once; nothing else about zoom rebuilds.
A host shows a dot below 0.05 px/mm and the full badge above with one
breakpoint.

### H-8. The overlays' cost

- No builder: no overlay layer is built; the paint allocation tests read
  exactly as today.
- With a builder: one render object (`RenderFloorPlanOverlays`, a
  multi-child render object) listens to the camera. A camera change
  `markNeedsPaint` for `natural` children (layout untouched) and
  `markNeedsLayout` for `box` children; it rebuilds nothing. A widget test
  counts builder calls across 50 camera changes (must be 0) and across a
  detail crossing (exactly one per table); the render object's positions
  come from a per-table box cache rebuilt at document, mode or camera
  rate, reused per frame.

### G-9. Today's fill and caption

`setTableStatus` keeps painting as today; a host that draws its own
status widgets simply does not set statuses (or sets a colour without a
caption). Documented, no new switch.

## Slice 2 — events and host data

Closes Q-Z4: D21's "component carrying the table's id" becomes real.

### E-1. Tables moved (selection mode)

`FloorPlanView.onTablesMoved: void Function(Map<String, FloorPlanTable>
moved)?`: after a service drag ends, the moved numbered tables with their
new geometry (G-1), fired once per drag, after `onLayoutChanged`. Undo,
Redo, reset and restore do not fire it (they fire
`serviceLayoutChanges`).

### E-2. Double tap

`onTableDoubleTap: void Function(String number)?`: a second tap on the
same table within `kDoubleTapTimeout` and `kDoubleTapSlop`. **The single
tap is not delayed**: both taps report `onTableTap` (and select) as
today, then `onTableDoubleTap` fires. Q-H2.

### E-3. A tap on the floor

`onFloorTap: void Function(Offset world)?`: a tap that misses every table
in the selection mode, after today's behaviour (the selection clears).

### E-4. Hover

`onTableHover: void Function(String? number)?`: a mouse or stylus pointer
entering a numbered table, or leaving it (null); only on a change; never
for touch.

### E-5. Design changes

`Stream<FloorPlanDesignChange> get designChanges` on the controller
(broadcast): after every committed design edit, undo or redo, the
differences of the design's tables before and after, by instance (kept
internal):

```dart
sealed class FloorPlanDesignChange {}
final class TableAdded       extends FloorPlanDesignChange { FloorPlanTable table; }
final class TableRemoved     extends FloorPlanDesignChange { FloorPlanTable table; }
final class TableRenumbered  extends FloorPlanDesignChange { String? from; FloorPlanTable table; }
final class TableMoved       extends FloorPlanDesignChange { FloorPlanTable table; }
final class TableDataChanged extends FloorPlanDesignChange { Map<String, String> from; FloorPlanTable table; }
final class PlanReplaced     extends FloorPlanDesignChange {} // load, newPlan
```

- One edit can emit several changes, in ascending instance order. Seats
  changing is `TableMoved`'s sibling only if a later slice needs it; not
  in v1 (seats come from the definition and cannot change in a plan).
- Computed by diffing two `TableSurvey`s at document-change rate, only
  while the stream has a listener. Never fired by the selection mode.

### E-6. Host data on a table

- A table carries `Map<String, String> data` (`FloorPlanTable.data`,
  unmodifiable, empty by default), stored in the plan as a component
  `jetcad.table_data` on the **instance** node: `{"data": {key: value}}`,
  keys written sorted.
- **Limits** (`ArgumentError` on write, `FormatException` on read):
  at most 32 keys; a key 1–64 characters of `[a-z0-9_.-]`; a value at most
  1024 UTF-16 units, no control characters. An empty map removes the
  component.
- `bool setTableData(String number, Map<String, String> data)` and
  `bool setTablesData(Map<String, Map<String, String>> byNumber)` (one
  undo step): design-mode edits (undoable, `dirty`, `revision`,
  `designChanges`). **They throw `StateError` in the selection mode**
  (P-5: the service copy never edits the design). They return false,
  changing nothing, when a number names no table **or more than one**
  (an ambiguous link is refused, not guessed). Numbers are trimmed as
  everywhere.
- The data travels with the instance: deleting the table drops it
  (undo restores it); renumbering keeps it; the service copy carries it,
  read-only.

### E-7. Who edits the data in the editor

The host, through Slice 4's inspector slot ([C-6](#c-6-the-table-inspector-slot)),
or programmatically. jet-cad shows no data field of its own.

### E-8. The unplaced-tables recipe, by id

The guide's recipe gains the id form: a host that stores `id` in `data`
compares ids, not codes.

### E-9. The schema stays 8

- A 0.3.0 reader has not registered `jetcad.table_data`, so it keeps the
  payload as unknown data and writes it back byte for byte (F-14); it
  draws nothing differently, because nothing it draws reads the data. The
  rule that made 7 bump (an older reader **drawing** the plan
  differently) does not apply; no 0.3.0 command copies an instance.
- So **`kSchemaVersion` stays 8**: 0.2.0, 0.3.0 and this slice's
  terminals keep sharing plans. A 0.3.0 terminal that renumbers a table
  keeps the data on it (it is the instance's); one that deletes the table
  drops it, as this slice does.
- **Gate:** a test decodes a plan carrying table data **without
  registering the type**, re-encodes it, and compares the bytes; a second
  test applies 0.3.0's design edits (move, rotate, renumber, delete,
  undo) through a registry without the type and checks the payload
  survives. If either cannot pass, the slice bumps to 9 instead, with the
  migration and a CHANGELOG line, and says so.
- **Q-H1:** the human accepted 9; this is better news, but it is a
  change from the brainstorm answer, so it is confirmed before Slice 2's
  plan.

## Slice 3 — the look

### T-1. `FloorPlanTheme`

`final class FloorPlanTheme extends ThemeExtension<FloorPlanTheme>`, every
field nullable (null = today's value), `copyWith` and `lerp`:

| Group | Fields |
|---|---|
| status | `statusCaptionStyle` (`TextStyle`: size, weight, colour; family see T-4), `statusFillOpacity` (`double?`, multiplies the host colour's alpha) |
| groups | `groupFrameColor`, `groupFrameWidth` (px), `groupFrameMargin` (mm), `groupChipColor`, `groupChipTextStyle`, `groupChipRadius`, `groupChipPadding` |
| selection | `selectionColor`, `selectionWidth` (px) |
| focus | `focusVeilColor` (null: the paper's), `focusVeilOpacity` |
| chrome | `serviceBarColor`, `serviceBarHeight`, `serviceBarForeground`, `canvasBackground`, `panelColor`, `panelBorderColor`, `panelForeground` |

- Light and dark: the host puts one `FloorPlanTheme` in each `ThemeData`;
  the paper's own brightness rules (light page on a dark canvas, 14d)
  stay: a theme colour that is `null` falls back to the paper palette.

### T-2. Resolution

`FloorPlanView(theme: FloorPlanTheme?)` overrides the ambient extension
field by field (`ambient.merge(view)`); then defaults. The export
dialog and other routes on the root navigator read the ambient one.

### T-3. Paint-rate reading

The resolved theme is compared by `==` at build; a painter rebuilds its
paints only when it changes (as a paper change recolours today). The
paint allocation tests run with a non-default theme too.

### T-4. Fonts

Painted text (captions, chips) uses the bundled Roboto by default, as the
plan does, so a terminal without the host's fonts draws the same. A
`fontFamily` in the theme's styles is honoured when the host has loaded
it; documented as the host's responsibility.

## Slice 4 — toolbars and the editor

### C-1. The service bar's items

```dart
FloorPlanServiceBar serviceBar = const FloorPlanServiceBar();

class FloorPlanServiceBar {
  const FloorPlanServiceBar({
    this.visible = true,
    this.actions = FloorPlanServiceAction.values, // order and subset
    this.leading = const [], this.trailing = const [], // host widgets
  });
}
enum FloorPlanServiceAction { undo, redo, merge, split, export, print }
```

Today's rules stay inside the subset: merge and split need their
callbacks, export needs `onExport`.

### C-2. Building your own bar

With `visible: false` the bar is gone and the canvas takes its height.
The controller exposes what a bar needs:

- `ValueListenable<bool> canUndo`, `canRedo` (the existing getters stay);
  `undo()`, `redo()` exist.
- `ValueListenable<Set<String>?> mergeCandidate`: the numbers the Merge
  button would send, null when it would be disabled;
  `ValueListenable<String?> splitCandidate`: the group id Split would send.
- `Future<FloorPlanExport?> exportPlan(FloorPlanExportChoice choice)` and
  `Future<bool> printPlan({PagePrinter? printer})`: the export and print
  flows without their dialogs (the controller already holds the font cache
  and the last choice, R-9). `FloorPlanExportChoice` is today's internal
  `ExportChoice` made public (format, scale, area).

### C-3. The dialog hook

`FloorPlanView.onExportDialog: Future<FloorPlanExportChoice?> Function(
BuildContext context, FloorPlanExportChoice initial)?`: when given, the
bar's Export (in both modes) calls it instead of the Material dialog; null
from it cancels. Print has no dialog of jet-cad's (the platform's).

### C-4. Editor capabilities

```dart
FloorPlanEditorCapabilities editor = FloorPlanEditorCapabilities.full;

final class FloorPlanEditorCapabilities {
  static const full, tablesOnly, readOnly;
  final Set<FloorPlanTool> tools;      // select, wall, room, door, window,
                                       // line, polyline, rectangle, circle,
                                       // arc, text, dimension, symbol, …
  final bool symbolPalette;            // the Symbols tab
  final bool Function(FloorPlanSymbol symbol)? symbolFilter; // which symbols
  final bool selectionPanel, layerPanel, pagePanel;
  final bool editLayers, editPage;     // the panels' editing, apart from showing
  final bool selectTablesOnly;         // the select tool picks tables only
  final bool move, rotate, delete, renumber;
  final bool undo, export, print;
  final bool rulers, grid, snapping, keyboardShortcuts;
  FloorPlanEditorCapabilities copyWith({…});
}
```

- **`full`** is today's editor. **`tablesOnly`**: tools `{select,
  symbol}`, the palette filtered to tables (servable symbols), the
  Selection panel, `selectTablesOnly`, move, rotate, delete, renumber,
  undo; no layer or page panel, no drawing tools. **`readOnly`**: select
  (no edit), pan and zoom; the design plan opens with
  `DraftPermissions.readOnly`.
- **Enforcement** is the shell's: tools, tabs, panels, shortcuts and the
  select tool's filter. `DraftPermissions` alone cannot express
  `tablesOnly` (F-12); `readOnly` is also enforced by the engine.
- **Changing it at runtime** takes effect at the next build; a tool that
  is no longer allowed falls back to select; a hidden panel's state is
  kept.

### C-5. The editor's bars

`FloorPlanView.editorActions: List<Widget>` (leading, trailing) in the
editor's top bar, as the service bar's `leading`/`trailing`. The shell's
unused `fileCommands` is not exposed: a host's Save or Open is one of
these actions.

### C-6. The table inspector slot

`FloorPlanView.tableInspectorBuilder: Widget? Function(BuildContext,
FloorPlanTable table)?`: shown in the editor's Selection panel under
jet-cad's own fields when **exactly one numbered table** is selected.
Monépro links a drawn table to a `pos_tables` row here, with Slice 2's
`setTableData`. With it, the controller exposes
`ValueListenable<Set<String>> editorSelectedTables` (numbers selected in
the design mode), so a host can also build its own side panel.

### C-7. Material widgets inside the editor

The layer panel's menus and the editor's own controls stay Material and
follow `ThemeData` plus `FloorPlanTheme`'s chrome colours; a host that
must not show them uses `tablesOnly`, which hides them. Replacing them
is out of scope (O-3).

## Invariants

1. **P-1:** the 0.3.0 host probe's source compiles unchanged against
   every slice (the probe keeps a frozen 0.3.0 copy of its `main.dart`
   for this, built in CI).
2. **P-6:** with no new parameter given, the goldens and the
   painted-output tests are unchanged.
3. Pan or zoom never calls a host builder (H-8).
4. The selection mode never changes the design: `setTableData` throws
   there; `designChanges` never fires from it; overlays, statuses, the
   theme are never saved, exported or printed.
5. Every callback and query names tables by number; no handle crosses the
   barrel.
6. `FloorPlanTable.data` round-trips through `designJson`/`load`; a
   reader without the type preserves it (E-9).
7. The frame path: the paint and query allocation gates stay green, run
   also with a theme and with overlays shown.

## Testing and named mutants

Each slice's plan lists its tests; each named mutant must be seen red
(Ruling 49/50). The fixtures are **non-degenerate**: rotated, mirrored,
scaled tables away from the origin, a hidden and a locked layer, two
tables sharing a number, an unnumbered table, a camera not at identity.

**Slice 1**

- M-H1: `center` read from the box's corner, not its centre.
- M-H2: `rotation` sign flipped (killer: a 30° table, not 0° or 180°).
- M-H3: `mirrored` from `scale.x < 0` only (killer: a table mirrored in
  y).
- M-H4: `tables` reports the design in the selection mode (killer: a
  service move then `tables`).
- M-H5: `worldToCanvas` omits the y flip.
- M-H6: `zoomBy` ignores the bounds.
- M-H7: a camera command does not cancel a pending fit.
- M-H8: the overlay rebuilds on a camera change (builder counter).
- M-H9: `detail` counts breakpoints strictly below the scale (killer: a
  scale exactly on a breakpoint).
- M-H10: `box` sizing uses the unrotated box (killer: a 45° table).
- M-H11: the overlay layer takes pointers when `interactive` is false.
- M-H12: off-canvas overlays still laid out (render counter).

**Slice 2**

- M-H20: double tap fires on two different tables.
- M-H21: `onTablesMoved` fires on Undo.
- M-H22: `setTableData` on a duplicated number writes the first.
- M-H23: `setTableData` allowed in the selection mode.
- M-H24: keys written unsorted (killer: byte-exact golden JSON).
- M-H25: `designChanges` reports a renumber as remove + add.
- M-H26: an unknown-type round-trip drops the payload (E-9's gate).

**Slice 3**

- M-H30: the view theme replaces the ambient one wholesale instead of
  merging (killer: one field each).
- M-H31: a theme read per frame (allocation counter).
- M-H32: `focusVeilColor: null` ignores the paper (killer: dark paper).

**Slice 4**

- M-H40: `actions` order ignored.
- M-H41: `tablesOnly` leaves the wall tool's shortcut active.
- M-H42: `selectTablesOnly` still picks a wall.
- M-H43: `readOnly` opens the design with `DraftPermissions.all`.
- M-H44: `mergeCandidate` non-null for one table.
- M-H45: the inspector shows for two selected tables.

## Risks

- **R-1. API size.** Four slices add roughly forty public names. Each
  slice's review checks the barrel diff against this spec; nothing
  unnamed here enters without a revision.
- **R-2. Overlay performance on low-end tablets** with 100+ tables and
  `box` sizing: a relayout per camera frame. Mitigation: `natural` is the
  default; `minScale` and culling; a measured row in the slice's results
  (the dev harness on the web build).
- **R-3. Double tap without delay** (E-2) means a host that opens a tab on
  tap and something else on double tap does both. Documented; Q-H2.
- **R-4. `tablesOnly` holes.** The editor has paths besides tools
  (keyboard delete, grips, the selection panel's fields). The slice's
  review enumerates every edit path in `planner_shell.dart` against the
  capability table.
- **R-5. Host data and plan exchange.** A host can write ids into one
  location's plan and load that plan at another location; jet-cad cannot
  know. Documented: data is the host's to validate.
- **R-6. E-9 rests on preserve-unknown** staying true in 0.2.0 and 0.3.0;
  the gate tests the current code's path, and the release review repeats
  the cross-tree round trip with the real 0.3.0 tree.

## Open questions

- **Q-H1 (the human):** the schema stays 8 for host data (E-9) instead
  of the 9 you accepted. Confirm.
- **Q-H2 (the human):** double tap reports both single taps first (no
  delay). Or delay single taps on tables when a double-tap callback is
  given?
- **Q-H3 (Monépro):** which overlay sizes and detail bands phase 2 wants;
  whether the id goes in `data["id"]` (the guide will suggest it).
- **Q-Z1 and Q-Z4** (zone spec) are answered by Slices 1 and 2; Monépro's
  spec 103 B.1 and D21 should name `controller.camera` and
  `FloorPlanTable.data`.

## Out of scope, recorded

- **O-1.** Custom table shapes beyond a symbol library (already the way).
- **O-2.** Host data on non-table objects (walls, rooms).
- **O-3.** Replacing the editor's inner Material widgets (layer menus,
  panel fields) with host widgets.
- **O-4.** Multi-select of tables by rubber band in the selection mode.
- **O-5.** Animation of camera commands.
- **O-6.** A per-table colour on the plan itself (status is not plan
  data).

## Files (expected)

- `jet_cad_floor_plan/lib/src/host/`: `floor_plan_controller.dart`,
  `floor_plan_view.dart`, `floor_plan_types.dart`, `service_view.dart`;
  new `floor_plan_camera.dart`, `table_overlay.dart`
  (`RenderFloorPlanOverlays`), `floor_plan_theme.dart`,
  `editor_capabilities.dart`, `service_bar.dart`, `design_changes.dart`.
- `jet_cad_floor_plan/lib/src/tables/`: `table_data_component.dart`,
  `table_index.dart` (data, geometry).
- `jet_cad_floor_plan/lib/src/service/`: the painters (theme), the select
  tool (events).
- `jet_cad_floor_plan/lib/src/planner_shell.dart`, `planner_view.dart`
  (capabilities, inspector slot, bars).
- `jet_cad_2d_flutter/lib/src/canvas_palette.dart`, `selection_style.dart`
  (theme parameters).
- `jet_cad_floor_plan/lib/jet_cad_floor_plan.dart`,
  `test/host/barrel_test.dart`.
- `apps/restaurant_demo`, `tool/ci/host_probe/lib/main.dart`,
  `docs/host-guide.md`, `CHANGELOG.md`.

## Review

To be filled by the independent review of revision 1.
