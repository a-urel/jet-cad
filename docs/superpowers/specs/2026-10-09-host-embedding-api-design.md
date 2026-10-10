# The host embedding API (umbrella) — design

**Date:** 2026-10-09. **Status:** design, **revision 3**. Revision 1
(`5bdb823`) was reviewed independently: *Approve with fixes*, V-1 to V-22,
no redesign. Revision 2 (`6f90e0e`) folded in every fix and the
controller's rulings on the four that needed a decision (V-2, V-4, V-5,
V-8); see [Review](#review). Revision 3 records the human's answers to
Q-H1 (**schema 9**) and Q-H2 (**double tap without delay**).

**Asked for by the human, 2026-10-08:** *"Monépro entegrasyonuna geç. Önce
beyin fırtınası. Temel nokta, başka bir uygulamaya gömecek esnekliğe
sahip olması. property ve callback-functions ile program tarafından
tamamen özelleştirilebilmeli."* The planner must embed in **any** host
app, customisable entirely by properties and callbacks; Monépro is the
first host, not the only one.

**The human's rulings in the brainstorm (2026-10-09; asked and answered,
paraphrased):**

- **Scope:** all four areas: per-table host widgets; a look/theme object;
  the toolbars (the service bar, the editor's top bar, the dialogs) and
  the editor's capabilities; events and camera control.
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
  its state exposed so the host builds its own; a dialog hook (export).
- **The look:** a `ThemeExtension` (`FloorPlanTheme`) **plus** a view
  parameter that overrides it.
- **Events:** today's split continues: user gestures are **view
  callbacks**; state changes are **controller listenables or streams**;
  commands are controller methods.
- **Host data on a table:** **yes**, a table carries a host map (e.g. the
  database id) **stored in the plan**, at the price of **schema 9**.
  Asked again after revision 2 showed an older reader would keep the
  data (Q-H1), the human kept **schema 9** (2026-10-09): terminals move
  together, as at 0.2.0. See [E-9](#e-9-schema-9).
- **Double tap (Q-H2, 2026-10-09):** **without delay**: both taps report
  as taps, then the double tap.

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `85905bd`
(release 0.3.0 + its STATUS). **Size:** L in total; each slice S–M.
**Touched:** `jet_cad_floor_plan` above all; `jet_cad_2d_flutter` (Slice 1:
the overlay's input marker in `InteractionLayer` and
`CameraGestureDetector`; Slice 2: `ToolPointerEvent.timeStamp`; Slice 3:
the palette's colours as parameters; Slice 4: `SelectTool`'s gates);
`jet_cad_2d` (Slice 2: `kSchemaVersion` 9, E-9);
`apps/restaurant_demo`, `tool/ci/host_probe`, the host guide, the
CHANGELOG in every slice.

## Facts (at `85905bd`; verified by the review at `5bdb823`)

**Monépro** (`monepro-frontend`, `develop @ 88c96e0`, read only).

- **F-1. Spec 103 B.1** (`:879-882`): jet-cad is reached through one
  adapter; status is drawn *"as Flutter widgets positioned with
  `camera.worldToScreen`"*, not by recolouring the geometry. **D22**
  (`:243`): a table shows empty or occupied (guests, age) plus badges
  (unsent, sıra waiting, ready, bill printed, part-paid). **SH** (`:276`):
  several open tabs per table, aggregated. None of this fits one colour
  and a 12-character caption.
- **F-2. D21** (`:239-242`): identity lives in the database; the drawing is
  *"linked by an app component carrying the table's id"*. **App. A**
  (`:835`): `pos_tables (id, location_id, code, capacity, zone,
  is_active)`. jet-cad links by the number alone (Q-Z4).
- **F-3. B.2** (`:886-890`, `:913`): zone tabs, "My tables", a long-press
  menu, and in phase 2 "edit floor drawing", beside "unplaced tables";
  `PosShortcutsHost` owns the POS's keyboard (`:901`). §5.3 (`:401`): a
  waiter may claim, move, merge a table; editing the drawing is not
  covered (a manager's).
- **F-4. Monépro's UI** is shadcn_ui; feedback is `ShadToaster` /
  `ShadDialog`, never a Material `SnackBar` (`wiki/conventions/ui.md:26-45`);
  its Material `ThemeData` is built with `ColorScheme.fromSeed`
  (`lib/app.dart:149-190`). A **hand-built** `ColorScheme` in a local
  `Theme` around the view matches shadcn tokens exactly (review V-15).

**jet-cad** (paths under `packages/jet_cad_floor_plan/lib/src/` unless
named).

- **F-5. The host barrel** exports through `show` lists only;
  `test/host/barrel_test.dart` pins the exact name set and `toString`s
  (`:109-110`). `@internal` marks controller members only the views use;
  it is an analyzer warning, and `apps/restaurant_demo/test/demo_test.dart`
  ignores it to write `c.camera.value` (`:7, 312-318`).
- **F-6. `FloorPlanTable`** (`host/floor_plan_types.dart:20-56`) is a
  `final class` of `number`, `seats`, `symbolKey`, `visible`, with `==`;
  `controller_test.dart:87-90, 832-837` compare whole lists of it. It
  follows the **active** plan already (`host/floor_plan_controller.dart:827-838`)
  and is rebuilt at each read; it moves with `revision`, **not** with the
  controller's `ChangeNotifier`, which fires only on a plan replacement
  (`:614-616, 717-739, 1019-1024`; `docs/host-guide.md:316-333`).
- **F-7. The camera.** `FloorPlanController.camera` is an `@internal`
  `CameraController` (`:203-209`), a `ValueNotifier<ViewportTransform>`
  (`jet_cad_2d_flutter` `camera_controller.dart:44-56`) with **final**
  `minScale` / `maxScale` (`kMinScale = 0.001`, `kMaxScale = 100`,
  `startup_plan.dart:50-51`, not exported), `panBy` and `zoomAt`.
  `ViewportTransform.worldToScreen` / `screenToWorld` map **world
  millimetres, y up** to the **canvas's** local logical pixels and
  allocate a `Vector2` per call (`viewport_transform.dart:56-59`). The
  controller learns each mode's canvas **origin** (`canvasMeasured`,
  `:465-470`), not its size (`_PlannerViewState._size`). A fit is a
  post-frame callback that never re-checks whether it is still wanted
  (`planner_view.dart:156-177`), and fits assign the camera **without**
  the zoom bounds.
- **F-8. Table geometry** has one source: `TablePicker.candidatesOf`
  (`service/table_picker.dart:233-268`) yields `TableCandidate{transform,
  box, corners, worldBounds, locked}` (`:103-137`; corners always in the
  box's order, (min, min), (max, min), (max, max), (min, max) through the
  transform, never reordered: counter-clockwise unless the transform
  mirrors, clockwise when it does, `:119-122`, `:255-258`; G-1's detail
  reverses a mirrored table's); the fit, the veil and the group frames
  share it; a table with non-finite corners is no candidate.
  It costs a `TableSurvey` and a `leavesByOwner` scan, O(entities).
  `TablePicker.pick` answers "which table is here" (`:278-306`). The
  label's decomposition of a placement is `tableLabelStamp`
  (`tables/table_label.dart:55-64`): `phi = atan2(b, a)`, mirrored when
  `det < 0`.
- **F-9. Paint and input layers.** `PlannerView` has `underlay` and
  `overlay` widget slots (`planner_view.dart:97-107`), filled by the
  service view's `CustomPaint` stacks (`host/service_view.dart:420-462`);
  every painter counts its allocations (`debugAllocations`), tested. The
  canvas's input is raw `Listener`s with `HitTestBehavior.opaque`:
  `InteractionLayer` (`jet_cad_2d_flutter` `interaction_layer.dart:467-474`),
  `CameraGestureDetector` (`camera_gesture_detector.dart:195-196`) and the
  service view's secondary click (`service_view.dart:395-399`). Both modes
  take `autofocus` (`service_view.dart:349`; `interaction_layer.dart:454`).
  `ServiceView` is keyed by the service copy (`floor_plan_view.dart:206`),
  so a reset, restore, load or mode switch remounts it.
- **F-10. Fixed look.** Status caption 11 px, ink `0xFF202020` or white by
  the fill (`service/table_status_painter.dart:39`; `jet_cad_2d_flutter`
  `canvas_palette.dart:206-211`); group frame `PaperPalette.gripMove`,
  margin 150 mm, 2 px, chip 11 px (`service/table_group_painter.dart:21-52`);
  selection `PaperPalette.selection`, chosen **per paper** (light or dark,
  `canvas_palette.dart:131-156`), shared by both modes
  (`service_view.dart:413`; `planner_shell.dart:977`), 2 px (`selection_style.dart:9`);
  veil the paper at 0.6 (`service/table_focus_painter.dart:17`). The views
  read `colorScheme.surface`, `surfaceContainer`, `surfaceContainerLow`;
  a page-less plan's paper is `colorScheme.surface` (`displayPaperFor`,
  `service_view.dart:258-261`; `planner_shell.dart:211-214`).
- **F-11. Fixed chrome.** The service bar (`host/service_view.dart:352-390`)
  is 44 px of Undo, Redo, Merge, Split (only with their callbacks), Export
  (only with `onExport`), Print (always); its chords are always bound
  (`:333-341`). Export's dialog is a Material `AlertDialog`
  (`export/export_dialog.dart:41-62`); `ExportChoice` is `{format:
  ExportFormat, dpi: ExportDpi}` (`:15-37`), neither enum exported. The
  export and print flows read the view's `exportName` and `printer` and
  run one at a time (`host/page_flows.dart:16-92`). The editor
  (`planner_shell.dart`) has 15 tools (`:337-460`) with letter shortcuts,
  a 240 px left panel (Tools, Symbols), a 280 px right panel (Selection,
  Layer, Page), a top bar; `FloorPlanView` passes the editor's Export and
  Print through the shell's `fileCommands` (`floor_plan_view.dart:173-190,
  231`).
- **F-12. Permissions.** The design plan decodes with `DraftPermissions.all`
  in the constructor and `load` (`host/floor_plan_controller.dart:137,
  663`); a `CommandDispatcher`'s permissions are fixed at construction
  (`jet_cad_2d` `undo.dart:153-157`). `DraftPermissions.readOnly` exists
  (`document/command.dart:61`). **Placing a symbol is `structure`**, so
  "tables only" cannot be expressed by `DraftPermissions`.
- **F-13. Service callbacks and options** are records read at each call
  or press (`service/table_select_tool.dart:20-45`; R-5); the drag knows
  the moved handles (`:98-106, 410-421`). `ToolPointerEvent` carries no
  timestamp (`jet_cad_2d_flutter` `tool.dart:19-37`); a finger's down
  reaches the tool up to `kTouchHoldBack` (100 ms) late
  (`interaction_layer.dart:33, 199`).
- **F-14. Components.** A component is attached per handle. A reader that
  has **not registered** a type keeps its payload as preserve-unknown data
  and writes it back byte for byte (`jet_cad_2d` `document/component.dart:209-286`,
  spec 04 D9; the review ran it on `salon.json`). **Removing a node does
  not detach its components** (`document/commands.dart:410-432`); only
  `RemoveDefinitionCommand` snapshots and detaches (`:552-553`). The
  editor's Delete is `RemoveNodeCommand` (`jet_cad_2d_flutter`
  `select_tool.dart:707-714`). `SetComponentCommand` with `null` detaches,
  undoably (`commands.dart:595-596`). The planner has no copy, paste or
  duplicate command. Schema 7 bumped for a component because an older
  reader would have **drawn** the plan differently
  (`codec/schema_version.dart:25-31`).
- **F-15. The editor's edit paths** (review V-7): the 15 tools and their
  letters; the Symbols tab; in `SelectTool`, body drag (with wall attach),
  the rotation grip, **reshape grips** (`grip_cache.dart:367-389`), the
  rubber band, Delete/Backspace; the Selection panel's number, rotation
  field and ±90, **Mirror** (`selection_panel.dart:656-670`), **Change
  size** (`:674-690`), wall/opening/room/box fields, **the layer picker**
  (`layers/layer_picker.dart:105-151`); the Layer and Page panels; Undo
  and Redo; Export and Print; F3 (snap), F (fill). `SelectTool` lives in
  `jet_cad_2d_flutter` and has no gate seam. A table symbol is
  `SymbolEntry.seats != null` (`symbols/symbol_library.dart:47-49`).

## Principles (bind every slice)

- **P-1. Additive only.** No existing signature, `==`, `hashCode` or
  `toString` changes; every new parameter is named and optional; every
  default is today's behaviour. A 0.3.0 host compiles and behaves the same
  against every slice. New information arrives in **new types**, never by
  widening an existing value type (review V-2).
- **P-2. Numbers stay the identity** (spec 14 D18). Callbacks, queries and
  commands name tables by number. Host data ([E-6](#e-6-host-data-on-a-table))
  rides beside the number and never replaces it; an opaque handle is
  never exported.
- **P-3. Where things live.** A user **gesture** is a `FloorPlanView`
  callback; a **state change** is a controller `ValueListenable` (a current
  value) or a broadcast `Stream` (a sequence of changes); a **command** is
  a controller method. A view parameter is read at each build or press,
  never captured (R-5).
- **P-4. The frame path.** Pan and zoom rebuild **no widget beyond
  today's zoom read-out** (`planner_shell.dart:943-947`) and allocate
  nothing per table in the painters (CLAUDE.md); the overlay layer
  allocates nothing per table beyond one paint offset per overlay shown,
  measured (`PaintingContext.paintChild` takes an `Offset`: the
  framework's floor). Style values are read when a painter rebuilds, never
  per frame. Host overlay widgets are **repositioned** per camera change,
  not rebuilt; the per-frame cost is O(tables) of arithmetic and
  O(overlays on screen) of paint, measured
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
- **P-9. Names.** Every public type carries the `FloorPlan` prefix (a host
  imports the barrel whole and has its own `TableMoved`); value types are
  `final class` with `==` and `hashCode`.

## Slice 1 — geometry, camera, per-table widgets

Unblocks Monépro's B.1 and D22, closes Q-Z1.

### G-1. A table's detail

`FloorPlanTable` is **unchanged** (P-1). A new value type carries what it
lacks:

```dart
final class FloorPlanTableDetail {
  final FloorPlanTable table;      // number, seats, symbolKey, visible
  final Offset? center;            // world mm, y up: the box's centre
  final Size? size;                // mm: box width × |column 0|, height × |column 1|
  final double rotation;           // radians, counter-clockwise: atan2(b, a)
  final bool mirrored;             // det < 0: the local y axis flipped
  final List<Offset> corners;      // world mm, counter-clockwise; [] when not finite
  final String layer;              // the instance's layer name
  final bool locked;               // the layer is locked: picked, never moved
  final Map<String, String> data;  // Slice 2; empty until then
}
```

- **Decomposition:** the placement is `R(rotation) · diag(sx, sy)` with
  `sx > 0`; `mirrored` means `sy < 0`, the same reading as
  `tableLabelStamp` (F-8). `corners` are normalised counter-clockwise
  whatever the mirror.
- The geometry comes from `TablePicker.candidatesOf` (F-8), the numbers
  the fit, veil and frames use. A table that is no candidate (hidden
  layer, non-finite corners) has `center: null`, `size: null`,
  `corners: const []`, `rotation: 0`.
- `List<FloorPlanTableDetail> get tableDetails`, ascending by handle like
  `tables`, for **the plan the current mode shows** (a service move
  changes it). It moves with `revision`, as `tables` does (F-6), and is
  **cached** by (active document, `commands.stateId`,
  `tables.mutationRevision`), as `_tables` and `_groupLookup` are, so a
  read inside `build` costs nothing after the first.

### G-2. The camera, public

- `ValueListenable<FloorPlanCamera> get camera` replaces the `@internal`
  member of that name; the internal `CameraController` becomes
  `@internal cameraController`. The rename updates every internal and
  test use, and the demo test that writes it (F-5); the CHANGELOG names
  the rename for anyone who ignored `@internal`.
- `FloorPlanCamera` (`final class`, immutable) wraps a `ViewportTransform`:
  `double get scale` (logical pixels per millimetre),
  `Offset worldToCanvas(Offset world)`, `Offset canvasToWorld(Offset
  canvas)`, `Rect visibleWorld(Size canvas)` (world mm, y up). **Canvas**
  is the view's drawing area, origin top-left.
- `ValueListenable<Rect?> get canvasRect`: the drawing area of the last
  laid-out view in global coordinates (origin **and size**, both reported
  by the view after layout), null with none mounted; with it `Offset?
  worldToGlobal(Offset)` and `Offset? globalToWorld(Offset)`. A host
  overlay **outside** the view needs them; the builder of G-5 does not.

### G-3. Camera commands and bounds

- `FloorPlanController({…, double minScale = 0.001, double maxScale =
  100})`: the zoom bounds, in logical pixels per millimetre (today's
  values, now documented); `ArgumentError` unless `1e-6 ≤ minScale <
  maxScale`, both finite. The floor is the constructor's: the bounds are
  decided with the engine's absolute tolerance of 1e-9, which below 1e-6
  would be a sizeable part of the bound (Task 2 review R-6). **Fits clamp** to the bounds too (today they do
  not, F-7; with today's bounds no real plan is affected, and P-6 holds).
- `void panBy(Offset canvasDelta)`: always acts; it needs no canvas.
- `bool zoomBy(double factor, {Offset? focus})` (focus in canvas pixels,
  default the canvas centre) and `void centerOn(Offset world, {double?
  scale})`: clamped as `CameraController.zoomAt` is. `zoomBy` returns
  false, changing nothing, with no measured canvas or a non-finite or
  non-positive factor. **`centerOn` queues like a fit**: with no view
  mounted, the next view centres on its first frame (zone spec Z7's
  machinery); the last request wins.
- **A camera epoch** orders requests: every fit request, `fitToTables`,
  `centerOn`, `zoomBy` and `panBy` bumps it; the post-frame fit captures it
  and returns when it has moved. So a camera command after a fit request
  wins, and a fit after a command wins. **A plan's own first fit is not a
  request** (Task 2 review R-1): a `panBy` or `zoomBy` before a plan's
  first frame (after construction, `load` or `newPlan`, until a view has
  fitted it) acts at once and drops a pending request (a fit request,
  `fitToTables`, `centerOn`), but does not cancel that plan's own fit,
  which then overwrites it. A host places the camera before a view shows
  with `centerOn`. **A `centerOn` without `scale:` asked before a plan's
  first fit** (no view has measured its canvas for that plan yet) takes,
  when it is performed, the scale of the plan's own page fit at the real
  canvas size, not the camera's placeholder scale for a nominal 1440×900
  window (final review F-1); with `scale:` it takes that scale.
- `bool userCamera = true` on `FloorPlanView`: false locks the user's pan,
  pinch and wheel zoom in that view (a kiosk or wall display); the
  commands still act.

### G-4. A table at a point

`String? tableAt(Offset canvasPoint, {PointerDeviceKind kind =
PointerDeviceKind.mouse})`: the number of the table `TablePicker.pick`
answers there in the current mode (finger reach for touch), null for none
or for an unnumbered table. At call rate; no allocation bar.

### G-5. The per-table builder

`FloorPlanView` gains:

```dart
FloorPlanTableOverlayBuilder? tableOverlayBuilder; // null: no overlay layer at all
FloorPlanOverlayLayout tableOverlayLayout = const FloorPlanOverlayLayout();
Set<FloorPlanMode> tableOverlayModes = const {FloorPlanMode.selection};

typedef FloorPlanTableOverlayBuilder =
    Widget? Function(BuildContext context, FloorPlanTableOverlay table);
```

- `FloorPlanTableOverlay` (`final class`): `FloorPlanTableDetail detail`,
  `bool selected`, `bool focused` (in the focus, or no focus set),
  `TableStatus? status` — **the effective one drawn**: a group status
  over the table's own (table-groups G3) — and `int detailLevel` (G-7). It
  carries **no** screen position or scale: those change with the camera
  and would force a rebuild.
- **When it builds:** once per numbered, candidate table when the layer
  builds; again **for that table only** when its `FloorPlanTableOverlay`
  changes (plan revision, selection, focus, status, detail level); again
  for **every** table each time the host rebuilds the view, whatever the
  builder's identity (a closure written in `build` and a method tear-off
  behave the same, so a builder reading the host's own fields is never
  stale; Task 3 review R-1). Never on pan or zoom. Returning null shows
  nothing for that table. Live data inside the widget is the host's own
  state management (`BlocBuilder`, `ValueListenableBuilder`).
- **Lifetime:** the layer lives inside the keyed `ServiceView` (F-9), so a
  reset, restore, load or mode switch remounts every overlay; a host keeps
  state in its own blocs, not in an overlay's `State`. Elements are keyed
  by instance internally, so two tables sharing a number keep two
  overlays. During a service drag the overlays stay at the tables' last
  committed places and move on drop, as the drafting does
  (`selectionPreviewTransform` moves only the outline).
- **Where it sits:** a new `PlannerView` slot, `tableOverlays`, painted
  after the selection overlay and **inside** the canvas's input listeners;
  clipped to the canvas; below the service bar.
- **Pointers.** By default (`tableOverlayLayout.interactive = false`) the
  layer ignores pointers, so every gesture reaches the canvas. With
  `true`, an overlay child that hits a pointer down puts a **marker**
  render object on the hit path; `InteractionLayer`,
  `CameraGestureDetector` and the service view's secondary-click
  `Listener` ignore a pointer whose down carried the marker. So a tap on a
  badge is the badge's alone (no selection, no `onTableTap`, no drag), and
  pan and zoom still start anywhere off a badge.

### G-6. Placement

`FloorPlanOverlayLayout` (`final class`, `const`):

- `anchor: Alignment` (default `Alignment.center`): the point of the
  table's **screen bounding box** the widget is pinned to, and the
  widget's own alignment there (as `Align` places it).
- `size: FloorPlanOverlaySize.natural` (default): the widget keeps its own
  size at every zoom, laid out once with loose constraints up to
  `maxNaturalSize` (default 200×120). `FloorPlanOverlaySize.box`: sized to
  the table's screen bounding box (tight) and relaid out on each camera
  change: per frame, for each overlay on the canvas, a `Size`, a
  `BoxConstraints` and a layout and paint of the host's widget (Task 3
  review R-2).
- `hideBelowScale: double` (default 0): below this camera scale no overlay
  is laid out or painted.
- `detailBreakpoints` (G-7). `interactive` (G-5).
- Culling (Task 3 review R-7): a `box` overlay whose box is off the
  canvas is neither laid out nor painted; a `natural` overlay is culled
  by the widget's own rectangle (not painted when it misses the canvas,
  so a badge larger than a far-zoomed table does not pop while it still
  overlaps the canvas), and is laid out once wherever it is.

### G-7. Detail levels

`detailBreakpoints: List<double>` (default empty), ascending camera
scales; `ArgumentError` if not strictly ascending and positive.
`FloorPlanTableOverlay.detailLevel` is the number of breakpoints **at or
below** the current scale. Crossing a breakpoint rebuilds every overlay
once; nothing else about zoom rebuilds. A host shows a dot below 0.05
px/mm and the full badge above with one breakpoint.

### H-8. The overlays' cost

- **No builder:** no layer is built; every existing test reads as today.
- **The render object.** `RenderFloorPlanOverlays`, a `Flow`-like
  multi-child render box: each child behind a `RepaintBoundary`, its
  offset in its parent data, recomputed in the camera listener from a
  per-table **box cache** (rebuilt when the tables' geometry changes, at
  document or mode rate, not on a selection, focus, status or detail
  level; the per-frame pass is arithmetic into reused `Float64List`s, no
  `Vector2`).
  `paint`, `hitTestChildren` and `applyPaintTransform` (behind
  `localToGlobal`, `showMenu`, tooltips) all read that one offset; a
  camera change calls `markNeedsPaint` and `markNeedsSemanticsUpdate` for
  `natural` children (layout untouched) and `markNeedsLayout` for `box`
  children. It rebuilds nothing.
- **Measured:** a widget test counts builder calls across 50 camera
  changes (0) and across a detail crossing (one per table); a status
  change on one table (one call); the render object carries
  `debugAllocations`, read across 50 camera changes in steady state in
  both size modes (0 per table). Nothing per table in the painters; the
  overlay layer allocates nothing per table beyond one paint offset per
  overlay shown, measured apart (`debugPaintOffsets`, at most the painted
  count; Task 3 review R-2). `box` also lays out each overlay shown once
  per frame (`debugChildLayouts`).

### G-9. Today's fill and caption

`setTableStatus` keeps painting as today; a host that draws its own
status widgets does not set statuses, or sets a colour without a
caption. Documented, no new switch.

## Slice 2 — events and host data

Closes Q-Z4: D21's "component carrying the table's id" becomes real.

### E-1. Tables moved (selection mode)

`FloorPlanView.onTablesMoved: void Function(List<FloorPlanTableDetail>
moved)?`: after a service drag ends, every moved table (numbered or not,
ascending by handle) with its new geometry, once per drag, after
`onLayoutChanged`. Undo, Redo, reset and restore do not fire it (they fire
`serviceLayoutChanges`).

*Amended during Slice 2's implementation* (the Task 4 review's rulings,
ledger `s2-task-4-review.md`): it is **not called** when the host's
`onLayoutChanged` replaced the service copy (a `resetLayout()`, a `load`,
a mode switch): the moved tables are gone, and the new copy's details
would describe places the drag did not produce (ruling 3). The list a
host is handed is **unmodifiable**, as `tableDetails` is (R-4).

### E-2. Double tap

`onTableDoubleTap: void Function(String number)?`: a second tap on the
**same instance** within `kDoubleTapTimeout` of the first tap's **down**
and within `kDoubleTapSlop` of it, timed from the raw pointer events
(`ToolPointerEvent` gains `timeStamp`, F-13). A locked table reports it.
With a modifier held it is not a double tap (each click toggles).
**The single tap is not delayed** (the human, Q-H2): both taps report
`onTableTap` (and select) as today, then `onTableDoubleTap` fires.

### E-3. A tap on the floor

`onFloorTap: void Function(Offset world)?`: a tap that misses every table
in the selection mode, after today's behaviour (the selection clears, or
with a modifier held stays); it fires with or without a modifier (S-4).

### E-4. Hover

`onTableHover: void Function(String? number)?`: a mouse or stylus pointer
entering a numbered table, or leaving it (null); only on a change; never
for touch. A remount of the service view (a mode switch, reset, restore,
load) sends no null: the host clears its hover state then (S-5).

*Amended during Slice 2's implementation* (the Task 4 review's rulings,
ledger `s2-task-4-review.md`): a hover picks at the point **with no
reach**, a table's top or box only, never the mouse's or a finger's reach
(R-4); over an **interactive overlay** (G-5's input claim) the pointer is
off the canvas, so the hover reads **null** while it is on the host's
widget, `n → null → n` as it crosses it (ruling 2).

### E-5. Design changes

`Stream<FloorPlanDesignChange> get designChanges` on the controller
(broadcast): after every committed design edit, undo or redo, the
differences of the design's tables before and after, by instance (kept
internal; `AddNodeCommand` re-adds the same handle, so an undone delete
is not remove + add):

```dart
sealed class FloorPlanDesignChange {}
final class FloorPlanTableAdded   extends FloorPlanDesignChange { FloorPlanTableDetail table; }
final class FloorPlanTableRemoved extends FloorPlanDesignChange { FloorPlanTableDetail table; }
final class FloorPlanTableChanged extends FloorPlanDesignChange {
  FloorPlanTableDetail before, after; // number, geometry, layer, lock, visibility, data
}
final class FloorPlanPlanReplaced extends FloorPlanDesignChange {} // load, newPlan
```

- One edit can emit several changes, in ascending instance order.
- Computed by diffing two cached detail lists (G-1) at document-change
  rate, only while the stream has a listener (one scan per design edit
  then).
- Service moves never fire it. **`FloorPlanPlanReplaced` fires on any
  design replacement, in either mode** (a `load` in the selection mode
  replaces the design).

### E-6. Host data on a table

- A table carries `Map<String, String> data` (`FloorPlanTableDetail.data`,
  unmodifiable, empty by default), stored in the plan as a component
  `jetcad.table_data` on the **instance** node: `{"data": {key: value}}`,
  keys written sorted; an empty map is no component.
- **Limits, on write only** (`ArgumentError`): at most 32 keys; a key 1–64
  characters of `[a-z0-9_.-]`; a value at most 1024 UTF-16 units, no
  control characters (the table numbers' rule: U+0000–U+001F,
  U+007F–U+009F). **On read** a payload outside them is kept verbatim by
  the planner's own component (the engine's preserve-unknown store holds
  only unregistered types, S-2) and written back, reads as empty `data`,
  and is reported as the table diagnostic `table.invalid_data` (editor
  code's `tableDiagnostics`; no host channel in this slice, S-3); a plan
  is never refused for it (a later release may
  relax a limit without another schema bump).
- `bool setTableData(String number, Map<String, String> data)` and `bool
  setTablesData(Map<String, Map<String, String>> byNumber)` (one undo
  step, **all or nothing**): design edits (undoable, `dirty`, `revision`,
  `designChanges`). **They throw `StateError` in the selection mode**
  (P-5). They return false, changing nothing, when any number names no
  table **or more than one** (an ambiguous link is refused, not guessed).
  Numbers are trimmed as everywhere.
- **Delete drops it.** `RemoveNodeCommand` keeps components (F-14), so
  Slice 2's expander on `TableLabelSystem` (`tables/table_label_system.dart`)
  appends `SetComponentCommand<FloorPlanTableData>(h, null)` when a
  compound removes an instance carrying it; undo restores it. Data is read
  only through live instances.
- Renumbering keeps the data (it is the instance's). The service copy
  carries it, read only.

### E-7. Who edits the data in the editor

The host, through Slice 4's inspector slot ([C-6](#c-6-the-table-inspector-slot)),
or programmatically. jet-cad shows no data field of its own.

### E-8. The unplaced-tables recipe, by id

The guide's recipe gains the id form: a host that stores `id` in `data`
compares ids, not codes.

### E-9. Schema 9

- **The human's ruling (Q-H1):** `kSchemaVersion` moves from 8 to **9** with
  Slice 2. The codec writes 9 for **every** plan saved from then on, with
  or without table data; a 0.3.0 or 0.2.0 terminal refuses it
  (`SchemaVersionError`, which `load` turns into a `FormatException` that
  says why). **Every terminal that shares stored plans moves together**,
  as at 0.2.0; the CHANGELOG heads it *Breaking for stored plans*.
- **Migration 8 → 9 is empty:** an 8 plan has no `jetcad.table_data`, and
  its absence means empty data. A schema-8 (and 7) plan opens unchanged.
  `schema_version.dart`'s comment records 9 and why: not for the reader's
  drawing, as 6–8 were, but so that no terminal silently carries host
  links it cannot see or keep consistent (a 0.3.0 terminal would leave a
  deleted table's data orphaned, F-14).
- The service layout's format is unchanged (it holds no table data).
- The bundled symbol libraries are re-encoded at 9, as at 8.
- **Gates:** (1) an 8 plan loads and saves as 9, its drawing unchanged
  (the round-trip goldens re-encoded; the engine's two fingerprints are
  standing failures on Linux, macOS values not re-baselined since 7, so
  they shift and stay standing, a comment records it and the macOS
  re-baseline stays owed, S-1); (2) a 9 plan with table data round-trips byte for
  byte; (3) a delete through Slice 2's registry removes the component and
  undo restores it; (4) a 10 plan is refused.
- The orphaning on delete still happens to **every** other component of
  every deleted node (a wall's or room's parameters); that predates this
  spec and is its own task (O-8).

## Slice 3 — the look

### T-1. `FloorPlanTheme`

`final class FloorPlanTheme extends ThemeExtension<FloorPlanTheme>`, every
field nullable (null = today's value), with `copyWith`, `lerp` and
`merge`:

| Group | Fields | Reaches |
|---|---|---|
| status | `statusCaptionStyle` (`TextStyle`; a null `color` keeps today's automatic black or white ink by the fill; family see T-4), `statusFillOpacity` (multiplies the host colour's alpha once) | selection mode |
| groups | `groupFrameColor`, `groupFrameWidth` (px), `groupFrameMargin` (mm), `groupChipColor`, `groupChipTextStyle`, `groupChipRadius`, `groupChipPadding` | selection mode |
| selection | `selectionOnLight`, `selectionOnDark` (per paper, as `PaperPalette` chooses today; hover derives from it), `selectionWidth` (px) | **both modes** |
| focus | `focusVeilColor` (null: the paper's), `focusVeilOpacity` | selection mode |
| canvas | `canvasBackground`: the canvas around the page **and** a page-less plan's paper (`displayPaperFor`), so a page-less plan inks right on it | both modes |
| chrome | `serviceBarHeight` | selection mode |

- **Everything else of the chrome** (bar and panel colours, text,
  borders) follows the ambient Material `Theme`; the guide's recipe wraps
  the view in a local `Theme` with a hand-built `ColorScheme` (F-4).
- Light and dark: the host puts one `FloorPlanTheme` in each `ThemeData`;
  the paper's own rules (a light page on a dark canvas, 14d) stay.

### T-2. Resolution

`FloorPlanView(theme: FloorPlanTheme?)` overrides the ambient extension
**field by field** (`ambient.merge(view)`), then the defaults. The export
dialog and other routes on the root navigator read the ambient one.

### T-3. Paint-rate reading

The resolved theme is compared by `==` at build and joins each painter's
rebuild key; a painter rebuilds its paints only when it changes, as a
paper change recolours today. The painters' allocation tests
(`table_status_painter_test`, `table_group_painter_test`,
`table_focus_painter_test`, and the render package's
`selection_overlay_test` reuse test for the selection colours;
`paint_allocation_test` paints none of them and stays untouched, S-1)
also run with a non-default theme.

### T-4. Fonts

Painted text (captions, chips) keeps today's default: no family, the
platform's default font (making Roboto the default would move every
caption's glyphs and widths, against P-6; S-2). A `fontFamily` in the
theme's styles is honoured when the host has loaded it; the guide
recommends `'Roboto'` (registered by `ensureFloorPlanFonts`) so every
terminal draws the same; documented as the host's responsibility.

## Slice 4 — toolbars, keyboard, the editor

### C-1. The service bar

```dart
FloorPlanServiceBar serviceBar = const FloorPlanServiceBar();

final class FloorPlanServiceBar {
  const FloorPlanServiceBar({
    this.visible = true,
    this.actions = FloorPlanServiceAction.values, // order and subset
    this.leading = const [], this.trailing = const [], // host widgets
  });
}
enum FloorPlanServiceAction { undo, redo, merge, split, export, print }
```

Today's rules stay inside the subset: merge and split need their
callbacks, export needs `onExport`. With `visible: false` the bar is gone
and the canvas takes its height; the R-13 canvas-origin measurement
follows (no stale 44 px).

### C-2. The editor's bar

```dart
FloorPlanEditorBar editorBar = const FloorPlanEditorBar();

final class FloorPlanEditorBar {
  const FloorPlanEditorBar({
    this.visible = true,
    this.actions = FloorPlanEditorAction.values, // undo, redo, export, print, snap, zoom read-out
    this.leading = const [], this.trailing = const [],
  });
}
```

`visible: false` removes the top bar; the tools stay in the left panel
(or are hidden by C-4).

### C-3. What a host-built bar needs

- `canUndo`, `canRedo` are already `ValueListenable<bool>`; `undo()`,
  `redo()` exist. In the design mode they also wait for an idle tool, as
  the shell's buttons do.
- `ValueListenable<Set<String>?> mergeCandidate`: the numbers the Merge
  button would send, null when it would be disabled. (Split's candidate is
  `selectedGroup`, which exists.)
- `ValueListenable<FloorPlanTool> activeTool` and `bool
  selectTool(FloorPlanTool tool)` (false when not allowed by C-5): the
  editor's tool, for a host's own tool strip.
- `Future<FloorPlanExport?> exportPlan(FloorPlanExportChoice choice,
  {String name = 'plan'})` and `Future<bool> printPlan({PagePrinter?
  printer, String name = 'plan'})`: the flows without their dialogs, each
  with `page_flows.dart`'s one-at-a-time guard, settle and
  `identical(document, activeDocument)` checks. `FloorPlanExportChoice`
  (format, dpi) is today's `ExportChoice` made public, with
  `FloorPlanExportFormat` and `FloorPlanExportDpi`.
- `FloorPlanView.onPageFlowError: void Function(Object error)?`: an export
  or print that fails reports here (today it is lost).

### C-4. The dialog hook

`FloorPlanView.onExportDialog: Future<FloorPlanExportChoice?> Function(
BuildContext context, FloorPlanExportChoice initial)?`: when given,
**every** Export entry point (both bars, the shell's file commands, the
chords, both modes) calls it instead of the Material dialog, through
`PageFlows.export`; null from it cancels. Print has no dialog of
jet-cad's (the platform's).

### C-5. Editor capabilities

```dart
FloorPlanEditorCapabilities editorCapabilities = FloorPlanEditorCapabilities.full;

final class FloorPlanEditorCapabilities {
  static const full, tablesOnly, readOnly;
  final Set<FloorPlanTool> tools;      // select, wall, room, door, window, line,
                                       // polyline, rectangle, circle, arc, text,
                                       // dimension, symbol, …
  final bool symbolPalette;            // the Symbols tab
  final bool Function(FloorPlanSymbol symbol)? symbolFilter; // palette and search
  final bool selectionPanel, layerPanel, pagePanel;
  final bool editLayers, editPage;     // the panels' editing, apart from showing
  final bool selectTablesOnly;         // pick and rubber band reach tables only
  final bool move, rotate, mirror, reshape, delete, renumber, changeLayer;
  final bool undo, export, print;
  final bool rulers, grid, snapping;
  FloorPlanEditorCapabilities copyWith({…});
}
```

- `FloorPlanSymbol` (`final class`): `key`, `name`, `category`, `tags`,
  `seats` (null when not a table), from the library's `SymbolEntry`.
- **`full`** is today's editor. **`tablesOnly`**: tools `{select,
  symbol}`, the palette filtered to tables (`seats != null`), the
  Selection panel, `selectTablesOnly`, move, rotate, delete, renumber,
  undo; no mirror, reshape grips, change size, layer picker, layer or page
  panel, or drawing tool. **`readOnly`**: select (nothing edits), pan and
  zoom; every edit flag false.
- **Enforcement is the shell's and the select tool's**, for every path of
  F-15: tools, tabs, panels and panel fields, shortcuts, and `SelectTool`
  gates in `jet_cad_2d_flutter` (a pick filter, and move, rotate, reshape
  and delete gates). `DraftPermissions` is not used: it is fixed when a
  plan is decoded (F-12) and cannot express `tablesOnly`. A host's own
  `setTableData`, `undo()` and `load` calls are the host's and stay
  allowed under every profile.
- **Changing it at runtime** takes effect at the next build; a tool that
  is no longer allowed falls back to select; a hidden panel's state is
  kept.

### C-6. The table inspector slot

`FloorPlanView.tableInspectorBuilder: Widget? Function(BuildContext,
FloorPlanTableDetail table)?`: shown in the editor's Selection panel under
jet-cad's own fields when **exactly one numbered table** is selected.
Monépro links a drawn table to a `pos_tables` row here, with Slice 2's
`setTableData`. With it, `ValueListenable<Set<String>>
editorSelectedTables` (numbers selected in the design mode) lets a host
build its own side panel instead.

### C-7. Keyboard and focus

- `FloorPlanView.shortcuts: bool = true`: false unbinds jet-cad's chords
  and letters in **both** modes (service Undo, Redo, Export, Print; the
  editor's tool letters, F3, F, Delete), so a host's own
  (`PosShortcutsHost`, F-3) owns the keyboard; the commands stay callable.
- `FloorPlanView.autofocus: bool = true`: false stops both modes taking
  focus on mount, so a search field beside the plan keeps it.

### C-8. Material widgets inside the editor

The layer panel's menus and the editor's own controls stay Material and
follow the ambient `Theme`; a host that must not show them uses
`tablesOnly`, which hides them. Replacing them is out of scope (O-3).

## Invariants

1. **P-1:** the 0.3.0 host probe (`git show v0.3.0:tool/ci/host_probe/lib/main.dart`)
   is analysed against each slice in CI; it proves the API compiles;
   invariant 2 carries behaviour.
2. **P-6:** with no new parameter given, the goldens, the painted-output
   tests and `controller_test`'s and `barrel_test`'s existing expectations
   are unchanged.
3. Pan or zoom never calls a host builder (H-8).
4. The selection mode never changes the design: `setTableData` throws
   there; service moves never fire `designChanges`; overlays, statuses,
   the theme are never saved, exported or printed.
5. Every callback and query names tables by number; no handle crosses the
   barrel.
6. Table data round-trips through `designJson`/`load`; a delete drops it
   undoably; every plan saved after Slice 2 is schema 9 and an 8 plan
   opens unchanged (E-6, E-9).
7. The frame path: `query_allocation_test`, `paint_allocation_test`, the
   floor-plan painters' counter tests and `RenderFloorPlanOverlays`'
   counter test stay at their bars, the last three also with a theme and
   overlays shown.

## Testing and named mutants

Each slice's plan lists its tests; each named mutant must be seen red
(Ruling 49/50). The fixtures are **non-degenerate**: rotated, mirrored and
non-uniformly scaled tables away from the origin, a table definition whose
box is **off its base point**, a hidden and a locked layer, two tables
sharing a number, an unnumbered table, a camera not at identity.

**Slice 1**

- M-H1: `center` read from the box's corner, not its centre.
- M-H2: `rotation` sign flipped (killer: a 30° table).
- M-H3: `mirrored = a < 0` (killers: an unmirrored 180° table; a
  mirrored 90° table).
- M-H4: `tableDetails` reports the design in the selection mode (killer:
  a service move then read).
- M-H5: `worldToCanvas` omits the y flip.
- M-H6: `zoomBy` ignores the bounds; M-H6b: a fit ignores them.
- M-H7: the post-frame fit ignores the camera epoch (a command after a
  fit request loses).
- M-H8: the overlay rebuilds on a camera change (builder counter).
- M-H9: `detailLevel` counts breakpoints strictly below the scale
  (killer: a scale exactly on a breakpoint).
- M-H10: `box` sizing uses the unrotated box (killer: a 45° table).
- M-H11: the layer takes pointers when `interactive` is false.
- M-H12: off-canvas overlays still laid out (render counter).
- M-H13: `center` = the instance's translation (killer: the off-base box).
- M-H14: `size` ignores the instance's scale.
- M-H15: the detail cache key misses the tables' revision (killer: hide a
  layer, read `center == null` at the next `revision`).
- M-H16: an interactive overlay's tap also reaches the table tool.
- M-H17: an interactive overlay's `localToGlobal` is off by the pan
  (non-identity camera).
- M-H18: one table's status change rebuilds every overlay (per-table
  counter).
- M-H19: an overlay off its table after pan and zoom (`closeTo` 1e-6).
- M-H19b: overlays shown in the design mode by default; `tableAt` ignores
  the finger's reach; `canvasRect` stale after the view moves without
  relayout; `userCamera: false` still pans.

**Slice 2**

- M-H20: double tap fires on two different instances; M-H20b: after
  `kDoubleTapTimeout`; M-H20c: beyond `kDoubleTapSlop`.
- M-H21: `onTablesMoved` fires on Undo; M-H21b: two moved tables sharing a
  number, one lost.
- M-H22: `setTableData` on a duplicated number writes the first.
- M-H23: `setTableData` allowed in the selection mode.
- M-H24: keys written unsorted (killer: byte-exact golden JSON); M-H24b:
  an empty map leaves an empty component.
- M-H25: an undone delete reported as remove + add.
- M-H26: the codec still writes 8 (E-9 gate 1); an 8 plan refused
  (migration gate).
- M-H27: the expander does not detach on delete (E-9 gate 3).
- M-H28: an over-limit payload throws on load.
- M-H29: `setTablesData` writes part of a batch with one bad entry;
  `onTableHover` fires per move or for touch; service moves fire
  `designChanges`; `FloorPlanPlanReplaced` not fired by a `load` in the
  selection mode.

**Slice 3**

- M-H30: the view theme replaces the ambient one wholesale instead of
  merging (killer: one field each).
- M-H31: a theme read per frame (allocation counter).
- M-H32: `focusVeilColor: null` ignores the paper (killer: dark paper).
- M-H33: a theme change without a paper change does not repaint (painter
  key); `statusFillOpacity` applied twice; a null caption colour forces
  black (killer: a dark fill); `canvasBackground` not reaching a page-less
  plan's paper; the editor's selection not following `selectionOnLight`.

**Slice 4**

- M-H40: `actions` order ignored (both bars).
- M-H41: `tablesOnly` leaves the wall tool's letter active; M-H41b:
  `shortcuts: false` leaves a service chord bound.
- M-H42: the rubber band picks a wall under `selectTablesOnly`.
- M-H43: `tablesOnly` shows Mirror; M-H43b: shows the layer picker;
  M-H43c: reshape grips active.
- M-H44: `mergeCandidate` non-null for one table.
- M-H45: the inspector shows for two selected tables.
- M-H46: Ctrl+Shift+E opens the Material dialog when `onExportDialog` is
  given.
- M-H47: a capability change at runtime leaves a forbidden tool active;
  `symbolFilter` not applied to search results; `serviceBar.visible:
  false` leaves the 44 px seed in the R-13 measurement.

## Risks

- **R-1. API size.** About fifty public names over four slices (the
  export enums included). Each slice's review checks the barrel diff
  against this spec; nothing unnamed here enters without a revision.
- **R-2. Overlay performance on low-end tablets** with 100+ tables and
  `box` sizing: a relayout per camera frame. Mitigation: `natural` is the
  default; `hideBelowScale` and culling; a measured row in the slice's
  results (the web build).
- **R-3. Double tap without delay** (E-2, the human's choice) means a
  host that opens a tab on tap and something else on double tap does
  both. The guide says so.
- **R-4. `tablesOnly` holes.** F-15 lists every edit path known at
  `85905bd`; Slice 4's review re-enumerates them against the flags.
- **R-5. Host data and plan exchange.** A host can write ids into one
  location's plan and load that plan at another; jet-cad cannot know.
  Documented: data is the host's to validate.
- **R-6. Schema 9 splits fleets.** A restaurant that updates one
  terminal first can no longer open that terminal's plans elsewhere. The
  CHANGELOG and the guide say so in bold, as for 8; the release that
  carries Slice 2 is the human's to time.

## Open questions

- **Q-H1 (the human), answered 2026-10-09:** schema 9 (E-9).
- **Q-H2 (the human), answered 2026-10-09:** double tap without delay
  (E-2).
- **Q-H3 (Monépro):** which overlay sizes and detail levels phase 2 wants;
  whether the id goes in `data["id"]` (the guide will suggest it).
- **Q-Z1 and Q-Z4** (zone spec) are answered by Slices 1 and 2; Monépro's
  spec 103 B.1 and D21 should name `controller.camera` and
  `FloorPlanTableDetail.data`.

## Out of scope, recorded

- **O-1.** Custom table shapes beyond a symbol library (already the way).
- **O-2.** Host data on non-table objects (walls, rooms).
- **O-3.** Replacing the editor's inner Material widgets (layer menus,
  panel fields) with host widgets.
- **O-4.** Multi-select of tables by rubber band in the selection mode.
- **O-5.** Animation of camera commands.
- **O-6.** A per-table colour on the plan itself (status is not plan
  data).
- **O-7.** String overrides beyond subclassing a built-in language
  (today's way); a fourth built-in language.
- **O-8.** Components orphaned by node deletion in general (F-14): its own
  task.
- **O-9.** Accessibility semantics for tables beyond what the overlay
  widgets bring.
- **O-10.** An undone node removal re-appends the node at its parent's
  end: `AddNodeCommand`, a delete's inverse, links through
  `DocumentTree._link` (`jet_cad_2d/lib/src/document/tree.dart:557-570`),
  so after Delete then Undo `designJson()` differs in the order of the
  parent's `children` while `dirty` reads false. Nothing drawn changes
  (draw order is by handle). Pre-existing, independent of table data;
  found by Slice 2's Task 2 (M-H27's amended killer). Its own task
  (`AddNodeCommand` restoring the child's index), beside O-8.
  **Settled** (2026-10-10, plan
  [2026-10-10-undo-node-index.md](../plans/2026-10-10-undo-node-index.md)):
  `RemoveNodeCommand`'s inverse carries the node's index and
  `DocumentTree.addNode` inserts there, so Delete then Undo is byte-exact,
  for one node and for a compound; HD12, TD7b and TD10 compare the
  encoding whole.
- **O-11.** Selecting a table whose corners are not finite (the
  fixture's `9`, a hand-edited file) trips a NaN-offset debug assertion
  in `SelectionOverlayPainter._paintGrips`
  (`jet_cad_2d_flutter/lib/src/selection_overlay.dart`). Unreachable from
  the UI: the editor has no free scale for an instance. Found by Slice
  2's Task 2 (its review's R-4). Its own task (skip non-finite grips).
  A PDF of a plan holding such a table (Export and Print) trips the pdf
  package's `!value.isNaN` through the label's residual in
  `PdfDrawSink`; its PNG is written. **Closed on `fix/non-finite-corners`
  (2026-10-10), merged into `main` at `aed5c4d`:** `GripCache` keeps no non-finite bounds in its box and
  no non-finite grip, and a grip whose screen distance is NaN is out of
  every hit test's reach; `SelectionOverlayPainter` draws no rotation
  grip and no point cross at a non-finite screen position; `PdfDrawSink`
  draws nothing under a residual with an entry that is not finite.
  Named mutants M-O11a to M-O11i, each killed
  (`jet_cad_2d_flutter/test/non_finite_selection_test.dart`, the
  sink's O-11 tests; the planner's `test/host/non_finite_table_test.dart`
  on the whole fixture).

## Files (expected)

- `jet_cad_floor_plan/lib/src/host/`: `floor_plan_controller.dart`,
  `floor_plan_view.dart`, `floor_plan_types.dart`, `service_view.dart`,
  `page_flows.dart`; new `floor_plan_camera.dart`, `table_detail.dart`,
  `table_overlay.dart` (`RenderFloorPlanOverlays`), `floor_plan_theme.dart`,
  `editor_capabilities.dart`, `bars.dart`, `design_changes.dart`.
- `jet_cad_floor_plan/lib/src/tables/`: `table_data_component.dart`,
  `table_label_system.dart` (the delete expander), `table_index.dart`.
- `jet_cad_floor_plan/lib/src/service/`: the painters (theme), the select
  tool (events).
- `jet_cad_floor_plan/lib/src/planner_shell.dart`, `planner_view.dart`,
  `selection_panel.dart`, `export/export_dialog.dart`.
- `jet_cad_2d_flutter/lib/src/`: `interaction_layer.dart`,
  `camera_gesture_detector.dart` (the overlay marker), `tool.dart`
  (`timeStamp`), `canvas_palette.dart`, `selection_style.dart` (theme),
  `select_tool.dart` (gates).
- `jet_cad_floor_plan/lib/jet_cad_floor_plan.dart`,
  `test/host/barrel_test.dart`, `.github/workflows/ci.yml` (invariant 1).
- `apps/restaurant_demo`, `tool/ci/host_probe/lib/main.dart`,
  `docs/host-guide.md`, `CHANGELOG.md`.

## Review

Revision 1 (`5bdb823`) was reviewed by an independent reviewer:
**Approve with fixes**; the full review is in the ledger
(`.superpowers/sdd/2026-10-09-host-embedding-api/spec-review.md`,
archived on merge). Every fact but F-11 (`fileCommands`) and F-14 (node
deletion) held; both are corrected above. Dispositions:

| Finding | Disposition |
|---|---|
| V-1 delete keeps component data | Accepted: E-6's expander, E-9's gate 3, M-H27, O-8 |
| V-2 widening `FloorPlanTable.==` breaks | **Ruled (a):** `FloorPlanTableDetail`, a new type; `FloorPlanTable` unchanged; P-1 reworded |
| V-3 `tables` moves with `revision`; scan per read | Accepted: G-1's cache and wording; M-H15 |
| V-4 overlay pointers and render model | **Ruled:** a `Flow`-like render box with one per-child offset, a `PlannerView` slot inside the input listeners, an input marker for interactive overlays; M-H16, M-H17 |
| V-5 `readOnly` vs decode-time permissions | **Ruled (a):** enforcement in the shell and the select tool only; `DraftPermissions` unused; host calls stay allowed |
| V-6 `ExportChoice` is format+dpi | Accepted: C-3, C-4; public export enums; every entry point; M-H46 |
| V-7 capability table misses paths | Accepted: F-15, `mirror`, `reshape`, `changeLayer`, `FloorPlanSymbol`, `SelectTool` gates; M-H42, M-H43 |
| V-8 the editor bar | **Ruled: in scope** (the human's toolbar ruling named the editor's top bar): C-2 `FloorPlanEditorBar`, `activeTool`, `selectTool`; F-11 corrected |
| V-9 strict reader without a bump | Accepted: validate on write only; lenient read with a diagnostic; M-H28 (kept under schema 9: a later release may relax a limit within 9) |
| V-10 camera mechanics | Accepted: the epoch, the canvas size, fits clamp, `panBy` always, `centerOn` queues |
| V-11 decomposition, degenerate fixture | Accepted: G-1's decomposition, M-H3 rewritten, M-H13, M-H14 |
| V-12 design-change coverage | Accepted: `FloorPlanTableChanged(before, after)`, `FloorPlanPlanReplaced` in either mode |
| V-13 moved map loses tables | Accepted: a list |
| V-14 double-tap timing | Accepted: `timeStamp`, same instance, locked reports, modifiers excluded |
| V-15 theme reach | Accepted: per-paper selection in both modes, `canvasBackground` into the paper, automatic caption ink, chrome cut to `serviceBarHeight` plus the local-`Theme` recipe |
| V-16 generic-host gaps | Accepted: `shortcuts`, `autofocus`, `userCamera`, `onPageFlowError`; O-7, O-9 |
| V-17 overlay lifetime | Accepted and documented (G-5): remount on a new service copy, keyed by instance, the effective status, still during a drag |
| V-18 allocation gates | Accepted: the render object's counter, invariant 7 names the gates, P-4 reworded |
| V-19 cut `splitCandidate` | Accepted |
| V-20 naming | Accepted: P-9, prefixed events, `hideBelowScale`, `editorCapabilities`, `final class` |
| V-21 facts, invariant 1 | Accepted: F-12 line, the `@internal` rename note, invariant 1 by `git show v0.3.0:` |
| V-22 missing mutants | Accepted: added per slice |

**Amended during Slice 1's implementation** (the controller's rulings on
the task reviews, ledger `s1-task-2-review.md` and `s1-task-3-review.md`):
G-3's `minScale` floor (1e-6) and its rule for a command before a plan's
first fit (Task 2, R-6 and R-1); G-5's host rebuild, confirmed as written
and made explicit for a method tear-off (Task 3, R-1); P-4, G-6 and H-8's
paint offset and `box` cost (Task 3, R-2), G-6's culling of a `natural`
overlay (R-7) and H-8's box cache rate (R-9).

**Amended by Slice 1's final review** (the controller's ruling, ledger
`s1-final-review.md`): G-3's `centerOn` without a scale before a plan's
first fit takes the page fit's scale at the real canvas (F-1).

**Settled by Slice 2's plan** (`docs/superpowers/plans/2026-10-09-embedding-slice-2.md`,
its *Spec points to settle*; the controller's rulings, each the plan's
recommendation): S-1 the fingerprints stay standing (E-9 gate 1); S-2
the planner's component keeps an out-of-limit payload verbatim (E-6);
S-3 the diagnostic is `table.invalid_data` in the table survey, no host
channel yet (E-6); S-4 `onFloorTap` with a modifier too (E-3); S-5 no
hover null on a remount (E-4); S-6 the readings the plan pins (control
characters, an empty value, re-sorting, a no-op write, two keys trimming
to one number, hidden and locked tables take data, inclusive timeout and
slop between the two downs).

**Amended by Slice 2's reviews** (the controller's rulings, ledger
`s2-task-4-review.md` and `s2-final-review.md`), beyond S-1 to S-6: E-1's
`onTablesMoved` is not called when the host's `onLayoutChanged` replaced
the service copy, and the moved list is unmodifiable; E-4's hover has no
reach, and reads null over an interactive overlay; E-5's stream delivers
nothing after `dispose()`, not even a change reported before it and not
yet delivered (a `load` in the same step), then done (final review F-1);
E-6's id is read as it is written: a number on two tables names neither,
so the guide's `idOf` and the demo read no id for it, as `setTableData`
refuses the link (final review F-3).

**Settled by Slice 3's plan** (`docs/superpowers/plans/2026-10-09-embedding-slice-3.md`,
its *Spec points to settle*; the controller's rulings, each the plan's
recommendation): S-1 T-3 names `selection_overlay_test`, not
`paint_allocation_test`; S-2 T-4 keeps today's default font; S-3 the two
styles merge with `TextStyle.merge`; S-4 `lerp` snaps a field null on one
side at 0.5; S-5 the fields' types and ranges, checked at build; S-6 the
automatic ink follows the drawn colour; S-7 a null chip colour is the
resolved frame colour, a faded group takes the veil; S-8 `selectionWidth`
reaches the selection's strokes, the hover stays 1.5 px at the selection's
alpha × 0.6; S-9 a host veil colour's alpha is multiplied by the opacity;
S-10 the view re-measures the selection canvas after a bar-height change;
S-11 the theme is resolved in a scope just below `FloorPlanView`; S-12 the
readings the plan pins.
