# Changelog

The four packages a host depends on — `jet_cad_2d`, `jet_cad_2d_flutter`,
`jet_cad_floor_plan`, `jet_cad_restaurant_symbols` — are released
together, under one version and one git tag. None is published to
pub.dev: a host depends on them by git (see
[docs/host-guide.md](docs/host-guide.md)).

## Unreleased

On `main`, not yet released: the host embedding API's Slices 1 to 4, a
host's own widgets on the tables, then the selection mode's events and a
host's own data on a table, then the floor plan's look in a host's
theme, then the host's own chrome and keys (the bars, the editor's
capabilities, the keyboard and the focus). **Move every terminal that
shares stored plans together**: 0.3.0 and earlier refuse a plan this
version saves (schema 9), with or without table data. Service layouts
are the same as 0.3.0's; the look, the bars, the capabilities and the
keys are never stored, so Slices 3 and 4 change no stored format.
Nothing a 0.3.0 host calls changes its signature, and with no theme,
bar, capability or key argument every pixel and key is 0.3.0's (but for
the fix below); CI analyses the 0.3.0 host probe against every commit.

- **A table's place.** `FloorPlanTableDetail` (`table`, `center`,
  `size`, `rotation`, `mirrored`, `corners`, `layer`, `locked`, and
  `data`, the host's own, below) and `FloorPlanController.tableDetails`, the
  active plan's tables in the order of `tables`, cached; a table on a
  hidden layer or with corners that are not finite has no geometry.
  `tableAt(canvasPoint, {kind})`: the number of the table a tap there
  would hit, a finger's reach for `PointerDeviceKind.touch`.
- **The camera, public.** `FloorPlanCamera` (`scale`, `worldToCanvas`,
  `canvasToWorld`, `visibleWorld`, `==` by its matrix) and
  `FloorPlanController.camera`, a `ValueListenable` with a new value at
  every pan, zoom and fit. `canvasRect`, the view's drawing area in
  global coordinates (null with no view), and `worldToGlobal` /
  `globalToWorld`.
- **Camera commands and bounds.** `panBy(canvasDelta)` (an
  `ArgumentError` for a delta that is not finite), `zoomBy(factor,
  {focus})` (false, changing nothing, with no view, a factor that is not
  finite and above 0, or a focus that is not finite),
  `centerOn(world, {scale})` (queued like `fitToView()`, the last request
  wins; an `ArgumentError` for a point that is not finite or a scale that
  is not finite and above 0; asked without a scale before a plan's first
  fit, it takes the scale of that plan's page fit at the real canvas).
  The constructor's `minScale` and `maxScale` (0.001 and 100 px
  per mm, as before) bound the user's zoom, the commands and every fit;
  it throws an `ArgumentError` unless both are finite and
  `1e-6 <= minScale < maxScale`. A plan's own first fit, after the
  constructor, `load` or `newPlan()`, still happens after a `panBy` or
  `zoomBy` made before it; place the camera beforehand with `centerOn`.
- **Your widgets on the tables.** `FloorPlanView.tableOverlayBuilder`
  (`FloorPlanTableOverlayBuilder`), called with a
  `FloorPlanTableOverlay` (`detail`, `selected`, `focused`, the
  effective `status`, `detailLevel`) per numbered table with geometry:
  again for one table when its value changes and for every table when
  the host rebuilds the view, never on pan or zoom.
  `tableOverlayLayout` (`FloorPlanOverlayLayout`: `anchor`, `size` as
  `FloorPlanOverlaySize.natural` or `box`, `maxNaturalSize`,
  `hideBelowScale`, `detailBreakpoints`, `interactive`) and
  `tableOverlayModes` (the selection mode by default). The widgets paint
  above the plan, the focus veil and the number chips; a host fades them
  with `focused`. With `interactive: true` a pointer that goes down on a
  widget is the widget's alone (no selection, no table drag, no pan, not
  a finger of a pinch); the wheel over it still zooms the plan. The view
  throws an `ArgumentError` when it is built with a builder and a
  `FloorPlanOverlayLayout` whose `detailBreakpoints` are not finite,
  positive and strictly ascending, or whose `hideBelowScale` or
  `maxNaturalSize` is negative or not finite.
- `FloorPlanView.userCamera` (default `true`): `false` switches off the
  user's pan, pinch and wheel zoom in that view; the commands still act.
- `jet_cad_2d_flutter`: `InputClaim` and `RenderInputClaim`, a marker
  whose pointers `InteractionLayer` and `CameraGestureDetector` leave
  alone.
- **Changes a host may notice.** Fits (`fitToView()`, `fitToTables`, the
  first fit) are now clamped to the zoom bounds; with the default bounds
  no real plan is affected. The `@internal` member
  `FloorPlanController.camera` (a `CameraController`) is renamed
  `cameraController`; `camera` is now the public `ValueListenable`. A
  class that `implements FloorPlanController` must add the new members.
- One `FloorPlanView` per controller at a time: a second one mounted
  beside the first throws a `StateError`, as it did before (now in the
  host guide).
- **Breaking for stored plans: schema 9.** The JSON codec writes schema 9
  for every plan, with or without table data. Nothing new is needed to
  read one: the bump exists so that no older terminal silently carries a
  table's host data it can neither see nor keep consistent (0.3.0 would
  keep it, and leave a deleted table's data behind). A schema-8 or
  schema-7 plan opens unchanged; **0.3.0 and earlier refuse a plan saved
  by this version**, and say why, so every terminal of a restaurant must
  move together. The bundled symbol libraries are re-encoded. The
  service layout's format is unchanged: it holds no table data.
- **Your data on a table.** `FloorPlanController.setTableData(number,
  data)` and `setTablesData(byNumber)` store a map of strings on a table
  (an id of the POS's, say), read back as `FloorPlanTableDetail.data` in
  either mode: design edits, undoable (`setTablesData` one step, all or
  nothing), `dirty`, `revision`; false, changing nothing, for a number
  that names no table or more than one; a `StateError` in the selection
  mode; an `ArgumentError` outside the limits (at most 32 keys, a key of
  1 to 64 of `[a-z0-9_.-]`, a value of at most 1024 UTF-16 code units
  with no control character). A hidden or locked table takes data. The
  plan stores it as the component `jetcad.table_data` on the table's
  placement, keys sorted. Deleting a table in the editor drops its data
  in the same step, and undo brings it back; renumbering keeps it. A
  stored map outside the limits reads as empty data and is kept as read
  (re-encoded); editor code sees it as the table diagnostic
  `table.invalid_data`.
- **The design's changes.** `FloorPlanController.designChanges`, a
  broadcast stream of the sealed `FloorPlanDesignChange`:
  `FloorPlanTableAdded(table)`, `FloorPlanTableRemoved(table)`,
  `FloorPlanTableChanged(before, after)` and `FloorPlanPlanReplaced()`
  (for `load` and `newPlan()`, in either mode), each with `==`,
  `hashCode` and `toString`. A table is followed as itself, never by its
  number: an undone delete is one `FloorPlanTableAdded`. Delivered
  asynchronously, one report per synchronous step; nothing on listen;
  nothing for the selection mode's moves; the tables compared only while
  someone listens; closed by `dispose()`, after which nothing is
  delivered, not even a change reported before it.
- **The selection mode's events**, four new `FloorPlanView` callbacks:
  `onTablesMoved(moved)` after a drag, with the moved tables' details,
  once, after `onLayoutChanged` (never on Undo, Redo, `resetLayout()` or
  a restore); `onTableDoubleTap(number)`, a second tap on the same table
  within 300 ms and 100 logical pixels of the first one's down, a locked
  table included, none with Shift, Ctrl or Cmd held. **The single tap is
  not delayed**: both taps report `onTableTap` first, so a tap's action
  runs on each tap of a double tap. `onFloorTap(world)` for a tap that
  misses every table, after the selection logic, modifier or not, in
  world millimetres; `onTableHover(number)` for the mouse or a stylus
  over a numbered table, null off it, only on a change, never for a
  finger, and no null when the view is built afresh.
- `jet_cad_2d_flutter`: `ToolPointerEvent.timeStamp` (default
  `Duration.zero`), the raw pointer event's time; `InteractionLayer`
  passes it, and a finger held back keeps its down's.
- `jet_cad_floor_plan`'s `editor.dart`: `isControlCodeUnit`, the table
  numbers' control-character rule, now shared with the table data's
  limits; `TableDiagnosticCodes.invalidData`.
- **The look.** `FloorPlanTheme`, a `ThemeExtension` a host puts in each
  of its `ThemeData`s (a light and a dark one), with sixteen optional
  fields, null being today's: `statusCaptionStyle` and
  `statusFillOpacity` (multiplies a status colour's alpha once);
  `groupFrameColor`, `groupFrameWidth`, `groupFrameMargin`,
  `groupChipColor` (null: the frame's), `groupChipTextStyle`,
  `groupChipRadius`, `groupChipPadding`; `selectionOnLight`,
  `selectionOnDark` (chosen by the paper; the hover follows at 60 % of
  the alpha) and `selectionWidth` (the hover stays 1.5 px), in both
  modes; `focusVeilColor` and `focusVeilOpacity` (the colour's alpha
  multiplied by it; no colour: the paper's, as today);
  `canvasBackground`, the canvas around the page and a page-less plan's
  paper, in both modes (it does not decide the dark canvas: the theme's
  brightness does); `serviceBarHeight`, the canvas moving with it when
  it changes. `copyWith`, `merge`, `lerp` (each number clamped between
  its ends; a field set on one side only switches at halfway), `==`,
  `hashCode`, `toString`. `FloorPlanView.theme` overrides the ambient
  extension field by field, the two text styles by `TextStyle.merge`;
  the view throws an `ArgumentError` naming the field for a resolved
  look out of range (an opacity outside [0, 1], a width or the bar's
  height not finite and above 0, a margin, radius or padding side
  negative or not finite, a `fontSize` not finite and above 0). The rest
  of the chrome, and the Export dialog, follow the ambient Material
  theme: the host guide's recipe wraps the view in a local `Theme` with
  a hand-built `ColorScheme`; the view's `theme:` reaches no dialog.
  Captions and chips keep the platform's default font unless a style
  names a family; `fontFamily: 'Roboto'`, registered by
  `ensureFloorPlanFonts`, draws them alike on every terminal. The look
  is read when a painter rebuilds, never per frame, and is never saved,
  exported or printed.
- `jet_cad_2d_flutter`: `PaperPalette.withSelection(colour)`, a copy
  with that selection and its hover (the colour at 60 % of its alpha),
  so `light.withSelection(light.selection) == light`; and
  `SelectionOverlayPainter.selectionStrokePixels` (default
  `kSelectionStrokePixels`, 2), the selection's outline and its point
  crosses, asserted finite and above 0, repainting when it changes.
- `jet_cad_floor_plan`'s `editor.dart`: `PlannerView.selectionStrokePixels`
  (default `kSelectionStrokePixels`); and a `PlannerShell` with no
  `FloorPlanView` above it follows the ambient `FloorPlanTheme`'s
  `selectionOnLight`, `selectionOnDark`, `selectionWidth` and
  `canvasBackground`, and throws an `ArgumentError` naming the field for
  an ambient look out of range.

- **The bars.** `FloorPlanView.serviceBar` (`FloorPlanServiceBar`) and
  `editorBar` (`FloorPlanEditorBar`), each with `visible`, `actions` (a
  list of `FloorPlanServiceAction` `undo`, `redo`, `merge`, `split`,
  `export`, `print`, or of `FloorPlanEditorAction` `export`, `print`,
  `undo`, `redo`, `snap`, `zoom`: each enum in today's left-to-right
  order, the default all of it, shown in the order given with today's
  gaps and rules), `leading` and `trailing` (the host's widgets in the
  bar's row); `==`, `hashCode`, `toString`; an `ArgumentError` naming
  `actions` for an action listed twice. A hidden bar gives the canvas
  its height, the plan kept in place from the first frame. `actions`
  shapes the bar only: the chords stay bound. A host field in a bar
  keeps Undo, Redo (and in the editor the tool letters and Escape); the
  file chords (and F3) still reach the plan.
- **A bar of the host's own.** `FloorPlanController.mergeCandidate`
  (`ValueListenable<Set<String>?>`: what Merge would send, null when it
  would be disabled and in the design mode), `exportPlan(choice,
  {name})` and `printPlan({printer, name})` (Export and Print without a
  dialog, no view needed; one export or print at a time per controller,
  the view's own included, a busy, page-less, replaced or disposed case
  answering null or false; an error completes the `Future`; allowed
  under every capability), and `FloorPlanExportChoice` (`format`, `dpi`,
  `initial` PDF at 150 dpi, `copyWith`, `==`, `hashCode`, `toString`)
  with `FloorPlanExportFormat` (`pdf`, `png`) and `FloorPlanExportDpi`
  (`d96`, `d150`, `d300`, `value`). `FloorPlanView.onExportDialog(context,
  initial)`: the host's export dialog at every Export entry point of
  both modes (the bars, the editor's file commands, Cmd+E and Ctrl+E),
  its answer remembered as the next `initial`, null cancelling.
  `FloorPlanView.onPageFlowError(error)`: an export or a print the view
  started that failed, once; without it the error propagates as before.
- **The editor's capabilities.** `FloorPlanView.editorCapabilities`
  (`FloorPlanEditorCapabilities`, default `full`, today's editor):
  `tools` (a set of `FloorPlanTool`, the palette's fifteen then
  `symbol`; it must hold `select`, else an `ArgumentError` naming
  `tools`), `symbolPalette`, `symbolFilter` (over `FloorPlanSymbol`:
  `key`, `name`, `category`, `tags`, `seats`), `selectionPanel`,
  `layerPanel`, `pagePanel`, `editLayers`, `editPage`,
  `selectTablesOnly`, `move`, `rotate`, `mirror`, `reshape`, `delete`,
  `renumber`, `changeLayer`, `undo`, `export`, `print`, `rulers`,
  `grid`, `snapping`; the profiles `full`, `tablesOnly` (Select and the
  tables of the Symbols tab, tables-only selection, move, rotate,
  delete, renumber, undo; no Layer or Page panel, mirror, reshape or
  layer change) and `readOnly` (select, pan and zoom, the panels read
  only); `copyWith` (null keeps a field, the filter included), `==`
  (the filter by `==`), `hashCode`, `toString`. Enforced on every edit
  path of the editor: the palette and its letters, the Fill row, the
  Symbols tab and its search, the symbol tool's R and M and its
  placement's turn and mirror, the select tool's pick, band, drags,
  grips and keys, every Selection panel field and button, the layer
  picker, the Layer and Page panels, the bar and its chords, F3 and
  object snap. A run-time change applies at the next build: a refused
  tool falls back to select, a hidden panel keeps its state, a drag
  whose flag closes before its up executes nothing, a change to
  `selectTablesOnly` keeps only the selection's tables. The selection
  mode is not governed by it. `FloorPlanController.activeTool`
  (`ValueListenable<FloorPlanTool>`) and `selectTool(tool)` for a host's
  own tool strip.
- **The table inspector.** `FloorPlanView.tableInspectorBuilder(context,
  table)`: the host's widget in the editor's Selection panel while
  exactly one root-level table is selected and no other table has its
  number, called with its
  `FloorPlanTableDetail`, at each selection or plan change and host
  rebuild, never on pan or zoom. `FloorPlanController.editorSelectedTables`
  (`ValueListenable<Set<String>>`), the numbers selected in the editor,
  empty in the selection mode.
- **Keyboard and focus.** `FloorPlanView.shortcuts` (default `true`):
  `false` unbinds, in both modes, every key the planner binds while no
  gesture runs (the chords, the tool letters, F3, F, Escape, the select
  tool's Delete and Backspace, the selection mode's Escape); a gesture's
  own keys stay. `FloorPlanController.deleteSelection()` deletes the
  editor's selection as the Delete key does, in one undo step, and
  answers whether it deleted (false in the selection mode, with no
  editor, nothing selected, `delete` refused, or a gesture part-way).
  `FloorPlanView.autofocus` (default `true`): `false` stops either mode
  taking the focus when it is mounted; read at each mount. A text field
  inside the view (a panel's, the Symbols search, a layer's rename, a
  host field in a bar or the inspector) keeps its keys from the host's
  own bindings above the view, in both modes.
- **A fix a 0.3.0 host may notice.** In the design mode
  `FloorPlanController.undo()` and `redo()` now do nothing while the
  editor's tool is part-way through a shape, as the editor's own Undo
  button and key already did; in 0.3.0 a host calling `undo()` then
  undid a step beneath the pending shape. `canUndo` and `canRedo` keep
  their meaning (the history), so a host button enabled by them may be
  pressed then, to no effect. The view's Export and Print now share one
  guard per controller with `exportPlan` and `printPlan`, and a flow
  reads the view's `exportName` and `printer` when it starts rather than
  after the bytes are made.
- `jet_cad_2d_flutter`: `SelectGates` (`all`; `restrictsPick` and
  `pick`, `bandAccepts`, `move`, `rotate`, `reshape`, `delete`,
  `idleKeys`, every one allowing by default and read live, never
  captured), `SelectTool.gates` and `SelectTool.deleteSelection(ctx)`
  (the idle Delete as a call, gated by `delete`); `GripCache(gates:)`
  with `moveGripsLive`, `stretchGripsLive` and `gatesChanged()` (give
  the tool and the cache the same gates object); the selection overlay
  draws a closed role's grips not at all; `InteractionLayer.autofocus`
  (default `true`).
- `jet_cad_floor_plan`'s `editor.dart`: `PlannerShell`'s `editorBar`,
  `capabilities`, `shortcuts`, `autofocus`, `tableInspector`, `onIdle`,
  `onTools`, `onToolChanged` and `onDelete` (with the typedefs
  `ShellIdleRegistrar`, `ShellToolRegistrar`, `ShellTableInspector`,
  `ShellDeleteRegistrar`); `PlannerView.autofocus`;
  `DocumentToolbar.groups`; `ToolPalette.showFill` and `toolChanges`;
  `SymbolPanel.filter`, `placeable` and `toolChanges`;
  `SymbolPlaceTool.canRotate`, `canMirror` and `gatesChanged()`;
  `SelectionPanel.capabilities` and `selectionChanges`;
  `LayerPanel.editable`; `PagePanel.editable`. Every one optional, its
  default today's behaviour.

**Known limits.** The badges' look and the smoothness of pan and zoom
with them have not been checked on a tablet or a terminal, nor have the
demo's double tap, pointer line and Link tables; the demo's new German
and Turkish strings have not been read by native speakers; nor has the
demo's POS look (captions, frames, chips, veil, bar, selection) been
seen on a tablet or a terminal, its colours being a proposal from
shadcn's published tokens; nor have the demo's three editor profiles and
its own service bar. While a symbol is armed, a refused R or M reaches
the next binding (under a value that allows the Rectangle or the Room
tool, it switches to it; no profile does). `selectTool(FloorPlanTool.symbol)`
only re-arms the symbol last armed from the Symbols tab: a host cannot
choose a symbol. Turning the rulers on or off at run time cancels a
shape part-way drawn. A Material `TextField` beside the plan loses the
focus on a mouse press outside it, after the canvas asked for it, so one
press on the plan right after typing leaves the focus with neither (the
host guide's `onTapOutside`). Capabilities are not a security boundary:
a host's own calls stay allowed under every value. `canvasRect`
ignores an ancestor that scales or turns the view. The planner checks a
table's data for shape, never for meaning: a plan saved at one location
and loaded at another carries the first location's ids.

## 0.3.0

Zones: a host frames a set of tables and fades the others. Nothing is
stored: **plans and service layouts are the same as 0.2.0's** (schema 8),
so 0.2.0 and 0.3.0 terminals can share them, and a restaurant may move
its terminals one at a time. Nothing a 0.2.0 host calls changes its
signature. The packages need Flutter 3.44 or later, as 0.2.0 did; 0.3.0
was built and tested with Flutter 3.47.6.

- **Zones: framing and focus.** A zone stays the host's (the table's
  attribute in its database); the plan stores none and the schema is
  unchanged.
  - `FloorPlanController.fitToTables(numbers)` frames the tables
    carrying those numbers, in either mode, with a 500 mm margin and at
    least 3 m per axis. It returns `false` and changes nothing when no
    table matches; with no view shown, the next view frames on its
    first frame, as `fitToView()` does.
  - `setTableFocus(numbers)` and `tableFocus`: the selection mode fades
    the tables outside the focus under a veil of the paper's colour.
    Faded tables still work. The focus is not saved, and is kept across
    loads and mode switches.
  - `FloorPlanTable.visible` (named, default `true`): false for a table
    on a hidden layer. `tables` still lists such tables. It joins `==`,
    `hashCode` and `toString`, whose text gains `visible`.
  - Two small changes a host may notice: `fitToView()` now reads the
    view's size when the fit is performed, not when it is requested; and
    a table whose corners are not finite (a hand-edited file) is no
    longer picked, framed or counted in a group's frame.
  - A class that `implements FloorPlanController` (a hand-written test
    double, not a mock) must add the new members.
- `jet_cad_floor_plan`'s `editor.dart`: `PlannerShell` and `PlannerView`
  take an optional `framing:`, the camera a fit sets at the drawing
  area's size (null fits the page, as before).

**Known limits.**

- The focus's look (the margin, the 3 m minimum span, the veil's 0.6) has
  not been checked on a tablet or a terminal, in light or dark.
- A host has no public world-to-screen mapping: it colours tables
  through `setTableStatus` and `setGroupStatus`, and cannot place its
  own widgets over them (Monépro's Q-Z1 is open). A table is linked to
  the POS by its number (Q-Z4).
- A new plan's separator still follows the UI language by assumption
  (Q2, as in 0.2.0).
- The German and Turkish text has not been read by native speakers.
- `jet_cad_2d_gpu` (the harness's GPU renderer), `packages/jet_cad` (the
  dormant OCCT 3D line) and the apps are not part of the release.

## 0.2.0

The second release a point-of-sale application can pin: the plan's own
decimal separator, and a host graph without the GPU renderer.
**Move every terminal that shares stored plans together**: 0.1.0
refuses a plan 0.2.0 saves (schema 8). The packages need Flutter 3.44 or
later; 0.2.0 was built and tested with Flutter 3.47.6.

- **A mode switch keeps the plan in place** (R-13, amended): switching
  between design and selection no longer moves the plan on the screen by
  the editor's panels and rulers. `setMode` reframes the camera by the
  difference of the two canvases' origins, its zoom kept, also when no
  view is shown; `fitToView`, `load` and `newPlan` still fit. The
  camera's numbers are no longer kept across a switch.
- **The plan's decimal separator** (Q0): a plan carries its own decimal
  separator, `.` or `,`, chosen on the Page panel (*Decimal separator*).
  Dimension text, room areas and the rulers print with it, and so do the
  PDF and PNG; the change is one undo step. A new plan takes the UI
  language's separator (`,` in German and Turkish); an empty plan a
  `FloorPlanController` creates takes the language of the first
  `FloorPlanView` that shows it (read with `designJson()` or edited
  before any view shows it, it keeps `.`), and `newPlan()` takes the
  language a view last showed. The language's separator is
  `FloorPlanStrings.decimalSeparator`, so a host's own strings class
  decides it for its new plans. A plan that exists keeps its own.
- **Breaking for stored plans: schema 8.** The JSON codec writes schema 8 (the page's
  `decimalSeparator`). A schema-7 plan opens unchanged, as `.`; **0.1.0
  refuses a plan saved by this version**, and says why, so every terminal
  of a restaurant must move together. The bundled symbol libraries are
  re-encoded.
- **Breaking for a host's own strings:** `FloorPlanStrings` gains the
  abstract `pageDecimalSeparator`; a class that implements or directly
  extends `FloorPlanStrings` must add it (a subclass of a built-in
  language inherits it).
- `jet_cad_2d`: `PageComponent.decimalSeparator`, `DecimalSeparator`,
  and `formatLength(…, decimalSeparator:)`.
- `jet_cad_floor_plan`'s `editor.dart`: `documentSeparatorFor`, and a
  `decimalSeparator:` parameter on `newDocument`, `defaultPage`,
  `startupPage`, `formatArea` and `formatDimension`.
- **The GPU renderer moves to its own package, `jet_cad_2d_gpu`.**
  `jet_cad_2d_flutter` no longer depends on `flutter_scene`, so a host's
  graph holds no `flutter_scene`, `flutter_gpu`, `flutter_gpu_shaders`
  or `scene`, and runs no build hook: no shader compiler at build time,
  and about 12 MB less in a web build. **The host's Flutter floor falls
  from 3.47 back to 3.44**, as the host guide says (measured by
  `flutter pub downgrade`). `jet_cad_2d_gpu` is not a host package: it is
  the dev harness's, and a host never depends on it. Nothing a host
  draws changes: the GPU path was only ever chosen by the harness.
- **Breaking for code that imported the GPU types** from
  `jet_cad_2d_flutter`'s barrel (no host did): `GpuDrawBackend`,
  `ResidentGeometry`, `ResidentPatch`, `debugSetGpuAvailable` and
  `uploadResidentCollection` now come from
  `package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart`, which also exports
  `installResidentGpu`, `gpuAvailable`, `debugSetGpuFactory` and
  `GpuContextFactory`; the GPU is used only after `installResidentGpu()`.
  `ResidentGeometry`'s four layout statics stay in `jet_cad_2d_flutter`,
  as `ResidentLayout`.
- `jet_cad_2d_flutter` gains the GPU registry (`ResidentGpu`,
  `registerResidentGpu`, `registeredResidentGpu`), `ResidentLayout`,
  `kFloatsPerInstance` and `InstanceFieldOffset`.

**Known limits.**

- A new plan's separator follows the UI language by assumption: the
  human's ruling on it (Q2) is still owed. If it becomes "`.` always", a
  later release changes only new plans; stored plans keep theirs.
- The German and Turkish text has not been read by native speakers.
- `jet_cad_2d_gpu` (the harness's GPU renderer), `packages/jet_cad` (the
  dormant OCCT 3D line) and `apps/dev_harness` are not part of the
  release.

## 0.1.0

The first release a point-of-sale application can pin.

**The 2D engine (`jet_cad_2d`) and its renderer (`jet_cad_2d_flutter`).**
A document model of entities, blocks, layers and styles; commands with
undo and redo; a spatial index, hit-testing and snapping; a
deterministic, versioned JSON codec (schema 7); rendering with a tile
cache, text, dashes and fills; selection, grips and the drawing tools;
the parametric layer that walls, openings, rooms and dimensions are
built on.

**The floor planner (`jet_cad_floor_plan`)**, sub-projects 01–13 and
09c: the app shell, its panels and tools; page, grid and rulers; walls
with cleaned-up junctions, doors and windows that cut them, rooms with
their area, associative dimensions; the symbol library with its palette
and wall-aware symbols; layers; the document lifecycle; PDF and PNG
export and printing.

**The restaurant embedding**, sub-project 14 and slice 14d:

- `FloorPlanController` and `FloorPlanView`: a **design** mode (the
  editor) and a **selection** mode (service) on a copy of the plan, which
  service moves never change;
- tables identified by their numbers; statuses with a colour and a
  caption; selection by number; tap and context-menu callbacks (a
  secondary click, or a long press when the host chooses); numbering
  warnings as values;
- table groups: merged and split by the host, framed and labelled, a
  member selecting and moving its whole group, group statuses;
- the service layout saved and restored as JSON; a view that forbids
  moves; touch;
- a dark theme: the planner follows the host's theme, and a light page
  is shown on a dark canvas;
- English, German and Turkish built in, chosen by the host's locale;
- `jet_cad_restaurant_symbols`: 69 restaurant symbols with German and
  Turkish names.

**Known limits.**

- The plan's own text (dimensions, room areas, the rulers, the PDF and
  PNG) keeps `.` as its decimal separator in every language.
- The German and Turkish text has not been read by native speakers.
- `packages/jet_cad` (the dormant OCCT 3D line) and `apps/dev_harness`
  are not part of the release.
