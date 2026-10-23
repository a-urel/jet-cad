## Unreleased

- **Alignment guides** (smart guides), in both modes. While a movable object
  is dragged or placed, lines show where its edges or its centre line up with
  a nearby object, or where its gap equals another gap (small gap marks, no
  measurement), and the object snaps there. Movable objects are placed symbol
  instances (tables, bar counters, kit symbols, units); walls, rooms and
  lines are not references, and a table's own seats are not either. A rotated
  or mirrored object aligns by its axis-aligned bounding box, a multi-selection
  by the outer box of the group. They work in design mode (moving a selection
  of symbols and placing a symbol with `PlanSymbolTool`) and in service mode
  (a waiter dragging tables or a group). The capture distance is 6 screen
  pixels (10 for touch), at any zoom. Holding Alt (Option on macOS) suspends
  them for the drag. Draw order, the file format, undo (one command per drag)
  and the host events are unchanged apart from the snapped positions.
- Options: `PlanEditor.alignmentGuides`, `PlanServiceView.alignmentGuides` and
  `PlanCanvas.alignmentGuides` (all `bool`, default true). False hides the
  bar's button and turns guides off in that view. Two standalone views over
  one controller with different values: the one mounted last wins.
- `PlanController.alignmentGuides` is a `PlanGuideSettings` (exported, a
  `ChangeNotifier`): `on` (allowed and the user's choice), `userOn`,
  `allowed` and `toggle()`. The user's choice lives in memory for the
  controller's life and is not saved in the plan.
- **Behaviour changes for existing hosts.**
  - Guides are on by default, so a drag near a neighbour now lands aligned. A
    test that pins an exact landing needs `controller.alignmentGuides.toggle()`
    or `alignmentGuides: false`.
  - `PlanEditorAction` and `PlanServiceAction` have a new value, `guides`
    (after `redo`; keys `toolbar-guides` and `service-guides`). A host that
    switches exhaustively over either enum adds the case; a host whose
    `actions` equal `values` now gets the toggle; a host with an explicit
    list lists `guides` where it wants the button.
  - A guide beats a pointer object-snap hit in a guide-eligible drag (spec
    C-8), so the dragged object does not swap positions when the pointer
    passes a wall's endpoint. An axis no guide captures keeps object snap and
    the grid. An attachment (a symbol that clings to a wall) still wins, and
    object snap is unchanged outside guide-eligible drags (grips, rotate,
    walls, rooms, mixed selections, Alt held, guides off).
- `PlanTheme.guideOnLight`, `guideOnDark` (the guide colour on a light and on
  a dark paper) and `guideWidth` (logical pixels, default 1).
- Depends on `jet_cad_2d_flutter`'s new `SelectTool.moveAdjuster` and
  `PaperPalette.guide`; see its CHANGELOG for the release order.
- The editor's right column follows the selection: with anything selected it
  shows the property panel and the host's inspectors only; with nothing
  selected, the Layers and Page sections too, on every layout.
  `PlanEditor.contextualPanels: false` keeps 0.9.0's column.

## 0.9.0

- Depends on `jet_cad_2d_kit: ^0.1.1`.

- A touch double tap on the canvas ends a pending chain (a wall or polyline
  chain) as Enter does: the first tap of the pair is the chain's last point,
  the second adds nothing. A mouse is unchanged.
- `PlanController.sectionDetails` lists every object of a kit type that
  declares an area, in draw order, with or without host data. A type object's
  `PlanObjectDetail.label` is its own name when the kit's type declares one
  (a room's name), else its title word as before.
- `PlanEditor` lays its design mode out by its own width: phone below 600
  logical pixels, tablet below 1000, desktop from 1000 (as before).
  `PlanEditor.breakpoints` (`PlanLayoutBreakpoints`) moves the limits and
  `PlanEditor.layout` (`PlanEditorLayout`) forces one. On a phone the tools
  and symbols and the properties, layers and page open as drawers over the
  plan from buttons in the bar; a tablet docks an icon-only tool strip, with
  the symbols as a drawer and the right panel behind the bar's button. One
  drawer at a time; a tap on the plan, the same button or Escape closes it;
  opening one never moves the camera. Behaviour change for existing hosts: a
  `PlanEditor` narrower than 1000 px now gets the tablet or phone layout
  unless `layout: PlanEditorLayout.desktop` is passed.
- The service mode on phones and tablets: `PlanEditor.serviceSidePanel` (and
  the same parameter, with `breakpoints` and `layout`, on `PlanServiceView`)
  takes the host's panel (orders, a table's detail). On a desktop layout it
  is docked on the right, 320 logical pixels wide; on a phone or a tablet it
  opens as a drawer over the plan from the service bar's last button
  (`Key('service-right-button')`). Without a panel there is no button and no
  column. The service bar scrolls instead of overflowing on a narrow screen.
- Host data on any placed object, not only units: `PlanController.
  objectDetails`, `objectDetailOf`, `setObjectData` and `setObjectsData`,
  naming an object by the opaque `PlanObjectRef` (`PlanObjectDetail`,
  `PlanObjectKind`). A unit's data is the same data either way; plans saved
  by 0.8.1 open unchanged. A `PlanObjectRef` is valid for the plan it was
  read from (and that plan saved and loaded again); after `newPlan` or a
  load of another plan, read the references again.
- A unit's section: `PlanUnitDetail.section`, the smallest area object (a
  kit type that declares an area, such as a room) whose outline contains the
  unit's centre, the boundary counting as inside; and
  `PlanController.sectionChanges`, one `PlanSectionChange` (labels and their
  new sections) whenever units' sections change, in design and after a
  layout move in service. `unitChanges` is unchanged: a section change alone
  is not a `PlanUnitChanged`.
- `PlanEditor.objectInspectorBuilder`: the host's widget in the property pane
  for any one selected object (a unit, a placed symbol, an object of a kit's
  type such as a room), built with its `PlanObjectDetail`. With
  `unitInspectorBuilder` also given, units keep going to that one.

## 0.8.1

- A unit status caption is clamped clear of the unit's symbol box — its
  chairs included — so it never lands on a chair, whatever the unit's
  rotation.
- The caption's ink is taken against the paper it lies on
  (`foregroundFor(paper)`), as the plan's other on-paper text, not against
  the status colour over that paper: a dark status on a light paper no
  longer draws an invisible white caption. A group chip's text, which lies
  on the chip, keeps the fill's ink (`chipInk`). (P7's amendments to
  dark-theme spec D6c.)

## 0.8.0

The plan library of jet_cad_2d, in design mode (sub-project 2a).

- `PlanController`: one plan and every system over it; `newPlan`, `load`,
  `save`, `dirty`, `markSaved`; undo and redo (waiting while a tool is
  part-way through a shape); tools by id; `deleteSelection`; the camera;
  a `Stream<PlanChange>`; diagnostics; `missingKits`, `locked`, `damaged`.
- Kits: the kit set validated as a whole; the plan manifest
  (`jetcad.manifest`) written and checked; a missing kit's objects opened,
  drawn, locked and saved unchanged; a kit hook that fails contained by the
  guarding adapter, its objects frozen and locked.
- `PlanPermissions` (`full`, `readOnly`, per-tool and per-action flags),
  enforced at the select gates, the palette, the panels and the bar.
- Symbol libraries loaded asynchronously by `PlanSymbolLoader`, shareable
  across controllers; the gallery.
- Attachment of symbols through the kits' providers; `plan.symbol`.
- Export and import registries: `plan.pdf` and `plan.png` built in, a
  host's own beside them; printing.
- The widgets: `PlanCanvas`, `PlanToolPalette`, `PlanSymbolGallery`,
  `PlanPropertyPanel`, `PlanLayerPanel`, `PlanPagePanel`, `PlanShortcuts`,
  and `PlanEditor` with `PlanEditorBar`.
- Words in English, German and Turkish; `PlanTheme`; the bundled Roboto.
- For hosts that wrap the editor: `showPlanExportDialog` (the built-in export
  dialog) and `kFileChords` (the file commands' chords).

The service mode (sub-project 2b).

- Units: a placed symbol instance whose definition carries `jetcad.unit`,
  or one a kit's parametric type generates (a seat in a row); identified
  by its label (the `UNIT` attribute), numbered on placement when the
  unit is `numbered`; `units`, `unitDetails`, `unitAt`, `select`,
  `fitToUnits`, `labelWarnings`, `unitChanges`; host data and colour
  (`setUnitData`, `setUnitColour`, `setUnitLabel` and their plural forms).
- `PlanMode` and `setMode`: the service mode works on a copy of the design
  with its own systems, lock and failure boundary; `undo`, `redo`,
  `export`, `print` act on the active document.
- Service state by label: `unitStatuses`, `unitGroups`, `groupStatuses`,
  `unitFocus`, `selectedUnits`, `selectedGroup`, `mergeCandidate`; the
  service record `jet_cad.service` (`serviceJson`, `restoreService`,
  `resetService`, `serviceEdited`, `serviceChanges`).
- `PlanServiceView` with `PlanServiceBar`, the events (`onUnitTap`,
  `onUnitDoubleTap`, `onUnitContextMenu`, `onGroupTap`, `onUnitHover`,
  `onUnitsMoved`, `onFloorTap`, `onMergeRequested`, `onSplitRequested`,
  `onLayoutChanged`), unit overlays (`PlanUnitOverlay`,
  `PlanOverlayLayout`); `PlanEditor` shows it in service and keeps the
  plan in place across a switch.
- `PlanPermissions`: `relabel`, `selectUnitsOnly`, `serviceMove`,
  `serviceMerge`, the `unitsOnly` profile. `PlanTheme`: the service and
  colour fields. Words for units and the service mode in English, German
  and Turkish; a host's own words (`PlanController(words:)`).
- In design, a generated unit stands for its object: a click on a seat
  selects its row. A window band over a row of seats alone selects
  nothing (a known limit).
- Unit types: `PlanUnit`, `PlanUnitDetail`, the `PlanUnitChange` events
  (`PlanUnitAdded`, `PlanUnitChanged`, `PlanUnitRemoved`,
  `PlanUnitsReplaced`), `UnitLabelProblem`, and the label warnings
  (`UnitLabelWarning`, `UnitProblem`, `Unlabelled`, `DuplicateLabel`,
  `BadLabel`); `UnitStatus`, `UnitGroup` and `ServiceRestore`;
  `PlanServiceAction`, `PlanLongPress`, `PlanFloorDrag`, `PlanOverlaySize`
  and `PlanUnitOverlayBuilder`.
- The camera for a host: `cameraValue` (a `PlanCamera` per pan, zoom and
  fit), `worldToGlobal` and `globalToWorld`.
- The unit colours in output: `export` and `print` take
  `unitColourOpacity` (default `kUnitColourOpacity`, 0.35), and
  `PlanExportRequest.unitColourOpacity` carries it to every exporter. All
  three refuse an opacity not finite or outside [0, 1] (`ArgumentError`).
- The unit section in `PlanPropertyPanel` (the label, its duplicate
  warning, the capacity, a quarter turn either way);
  `PlanEditor(unitInspectorBuilder:)` builds a host's inspector under the
  panel for one selected placed unit.
- `isUnitSymbol`, the gallery filter for the `unitsOnly` profile.
- `PlanController.symbolsState` is now typed `SymbolsState`, moved to
  `jet_cad_2d_kit` and re-exported here; 2a's `PlanSymbolsState` is removed.
- While the plan is in service the design document is read-only: a
  `PlanCanvas` or a kit tool still mounted cannot edit it. Leaving service
  gives it the permissions' engine permissions again.
- Sub-project 3a: a kit tool's notice on the status line, put into words
  when read (`PlanController.toolNotice`, `textOf`).
- Sub-project 3a: a plan built in code (`PlanController(build:)`,
  `newPlan(build:)`) and every kit's `prepare` run on a plan the library
  makes, never on one it loads or imports.
- Sub-project 3a: the property panel's `TextDisplay` row, hidden fields
  and the object view.
- Sub-project 3a: the words' decimal separator from the UI language.
- Sub-project 3a: numbered names over the contract's `numberedNameIndex`.
- Sub-project 3a: a grip refusal during a drag (`ArgumentError`) gives no
  move and no diagnostic, and plan.select's drop is refused by the rule
  `execute` uses (no edit, no exception; a `StateError` still escapes).
- Sub-project 3a: a frozen object's live references locked.
- Sub-project 3a: a choice row hands the focus back to the canvas once a
  choice is made.
- Sub-project 3a: `PlanShortcuts` remounted on the same controller: the
  last one mounted speaks for its keys.
- Sub-project 3a: the symbol box family now the contract's.
- Sub-project 4a: `PlanToolIds` is exported, so
  `PlanPermissions(tools: {PlanToolIds.select, ...})` needs no id strings.
- Sub-project 4a: a host's own symbols are a small kit,
  `PlanKit(id: '<host>', symbols: [...])`, loaded beside any other kit's
  (pinned, no new API).
- Sub-project 4a: several `PlanServiceView`s may show one controller; the
  canvas placed last drives `canvasRect` and the zoom focus, and the one
  placed before it takes over when it goes (documented and pinned).
- Sub-project 4a: `userCamera: false` pinned: no pan, pinch or wheel moves
  the camera; the host's `centerOn` still does.
