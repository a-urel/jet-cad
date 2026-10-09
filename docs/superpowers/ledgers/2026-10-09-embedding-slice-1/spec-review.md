# Spec review: 2026-10-09-host-embedding-api-design.md (revision 1)

Reviewer: independent. Spec at `5bdb823`. The code it cites is unchanged since
`v0.3.0`: `git diff --stat v0.3.0 HEAD -- packages apps tool` is empty, and
`packages/jet_cad_2d/lib` is unchanged since `v0.2.0`. So the HEAD probes below
are also 0.3.0 probes, and the 0.2.0 engine path is identical. Monépro was read at
`develop @ 88c96e0`. I edited nothing in the repository except this file.

## Verdict: **Approve with fixes**

The umbrella holds:
- The four-slice split and the principles fit the rulings.
- E-9's central claim is right: an unregistered `jetcad.table_data` survives
  decode/encode byte for byte, every 0.3.0 design edit, and the service copy.

Revision 2 must still fix nine Major findings before Slice 1's plan:
- **Decisions needed:** four of them need a decision, not an edit:
  - V-2: the geometry type;
  - V-4: the overlays' pointer and render model;
  - V-5: where `readOnly` lives;
  - V-8: the editor bar versus the toolbar ruling.
- **Code facts:** the rest are code facts the spec gets wrong:
  - V-1: delete does not drop component data;
  - V-3: `tables` does not notify;
  - V-6: `ExportChoice` is format+dpi;
  - V-7: the capability table misses edit paths;
  - V-9: a strict reader without a schema bump.

## What I ran (results of record)

**E1. Preserve-unknown probe.** A throw-away `flutter test` in a scratch clone of
`5bdb823`, deleted afterwards.
1. Read `apps/restaurant_demo/assets/plans/salon.json` and add
   `components["jetcad.table_data"] = {"29": {"data": {"id": "abc"}}}` (instance 29
   is table 1, label 30).
2. Decode with `registerAppComponents`:
   - The re-encode equals the input byte for byte, and a second round trip is
     stable.
3. Delete table 1 as `SelectTool` does (`select_tool.dart:707-714`: owned leaves,
   then `RemoveNodeCommand`):
   - The node is gone.
   - **The payload is still written**, on the dead handle 29.
   - The plan reloads, and `unknownOf(29)` returns `{typeId: jetcad.table_data,
     data: {id: abc}}`.

## Findings

### V-1 (Major) — E-6, E-9: deleting a table does **not** drop its data; the gate would pass for the wrong reason

**Evidence**
- `RemoveNodeCommand.apply` removes the tree node only. It does not touch
  components (`jet_cad_2d/.../commands.dart:410-432`).
- Only `RemoveDefinitionCommand` snapshots and detaches (`:552-553`). F-14 cites
  that command, but a table is a node.
- The editor's Delete is `RemoveNodeCommand` (`jet_cad_2d_flutter/.../select_tool.dart:707-714`).
  Nothing else calls `components.detach*` (grep).
- E1 confirms the result: after a delete, the payload stays in the file on a dead
  handle, in 0.3.0 and at HEAD.

**Consequences**
- E-6's "deleting the table drops it (undo restores it)" is false. So is E-9's
  "one that deletes the table drops it, as this slice does".
- A deleted table's host id stays in the plan forever.
- `withComponent<TableData>()` will list dead handles.
- E-9's second gate ("checks the payload survives" after delete) goes green
  however the slice behaves.

**Fix**
1. Slice 2 drops the data on delete inside `jet_cad_floor_plan`, with no engine
   change: `TableLabelSystem`'s expander (`tables/table_label_system.dart`,
   stacked on the parametric one) appends `SetComponentCommand<TableData>(h, null)`
   when a compound removes an instance carrying it. `SetComponentCommand` with
   `null` detaches (`commands.dart:595-596`), and undo restores it.
2. `FloorPlanTable.data` and every Slice 2 query read data only through
   `TableSurvey`'s live instances.
3. E-9 states the 0.3.0 fact: a 0.3.0 terminal that deletes a table leaves its
   data orphaned (harmless, never surfaced). The guide says so.
4. Rewrite the gate's delete case:
   - after a delete through 0.3.0's registry, the payload is on a dead handle and
     `tables` does not show it;
   - after a delete through Slice 2's registry, the component is gone, and undo
     brings it back.
5. Add mutant M-H27: the expander does not detach.

Pre-existing, out of this spec: the same orphaning happens to every component of
every deleted node, including a wall's or room's parameters on its group handle.
It is worth its own task.

### V-2 (Major) — G-1, P-1, P-6: widening `FloorPlanTable.==` is a break, not an addition

**Evidence**
- `controller_test.dart:87-90` does `expect(c.tables, const [FloorPlanTable(number:
  '1', seats: 2, symbolKey: 'test.table'), …])`, and `:832-837` does the same with
  `visible: false`.
- `barrel_test.dart:109-110` pins `toString`.
- After G-1, real tables carry `center`, `size`, `layer` and the rest, so all of
  these go red, and any host test written the same way does too. That breaks P-1
  ("behaves the same") and P-6 ("tests stay unchanged").
- With geometry in `==`, every service move also changes `tables`' equality, so a
  host that diffs lists rebuilds more.

**Fix (pick one, and say which)**
- **(a) Recommended:** keep `FloorPlanTable`'s fields, `==` and `toString` as they
  are. Add an immutable `FloorPlanTablePlacement` with the geometry fields plus
  `number`, from a new `List<FloorPlanTablePlacement> get tablePlacements`, or
  carry it on `FloorPlanTableOverlay`. `data` (Slice 2) may still join
  `FloorPlanTable`, but that is the same break, so (a) puts it on the new type too
  or names it.
- **(b)** Declare the widening a breaking change in the CHANGELOG. Rewrite P-1 as
  "source-compatible, `==` widened", and list the tests that change.

### V-3 (Major) — G-1: `tables` does not notify through the `ChangeNotifier`, and the geometry costs a scan per read

**Evidence**
- The controller's `notifyListeners` fires only on a plan replacement:
  - mode switch, `load`, `newPlan`, `resetLayout`, `restoreServiceLayout`
    (`floor_plan_controller.dart:614-616, 717-721, 735-739`);
  - edits and service moves move `revision` (`:1019-1024`).
- The host guide already says so: "re-read on `revision`" (`docs/host-guide.md:316-317, 333`).
- `tables` already follows the active plan (`:827-838`, `_active`). The new part
  is only the geometry.
- `tables` builds a fresh list at each call. Adding `TablePicker.candidatesOf`
  adds a `TableSurvey.of` and a `leavesByOwner` scan per read, O(entities)
  (`table_picker.dart:233-268`), in a getter that hosts read inside `build`.

**Fix**
- G-1: "`tables` moves with `revision`", not the `ChangeNotifier`.
- Cache the geometry, or the placements of V-2a, keyed by (document, `stateId`,
  `tables.mutationRevision`), as `_tables` and `_groupLookup` already are.
- Mutant: the cache key misses the layers' revision. Killer: hide a layer and
  read `center == null` at the next `revision`.

### V-4 (Major) — G-5, G-6, H-8: the overlays' pointer and render model does not fit Flutter's and is not specified

**Pointers.** The canvas's input is raw `Listener`s with
`HitTestBehavior.opaque`:
- `InteractionLayer` (`interaction_layer.dart:467-474`);
- `CameraGestureDetector` (`camera_gesture_detector.dart:195-196`);
- `ServiceView`'s secondary-click `Listener` (`service_view.dart:395-399`).

The overlay layer can sit in one of two places, and both fail:
- **Inside them** (a `PlannerView` slot, as `underlay`/`overlay` are): an
  ancestor `Listener` always joins the hit path. A tap on an `interactive`
  overlay also reaches `TableSelectTool`, which selects, reports `onTableTap` and
  may start a drag. That contradicts "the table under it gets nothing there".
- **Outside them** (a sibling above `PlannerView`): the `Stack` stops at the
  first hit. Pan, pinch, wheel zoom and drag fail wherever an overlay sits.

The spec does not say which it is.

**Render.** "`markNeedsPaint` for `natural` children (layout untouched)" moves
children at paint time. Then:
- Default hit testing reads `parentData.offset`.
- `applyPaintTransform` (behind `localToGlobal`, `showMenu` and tooltip
  anchoring inside a badge) reads the same offset.
- Semantics rects also go stale.

All three must use the same per-child transform.

Smaller points:
- "Box cache rebuilt at … camera rate, reused per frame" contradicts itself:
  camera rate *is* per frame.
- P-4's "O(overlays on screen)" cannot hold if culling scans all tables. It is
  O(tables) of arithmetic per frame. That is fine, but say so.

**Fix**
1. Name the structure. A `RenderFlow`-like multi-child box:
   - each child behind a `RepaintBoundary`;
   - a per-child offset in its parentData, recomputed in the camera listener;
   - `paint`, `hitTestChildren` and `applyPaintTransform` all reading that
     offset;
   - `markNeedsSemanticsUpdate` with `markNeedsPaint`.

   `Flow` itself fits `natural` and is a known-good precedent. `box` needs
   relayout, as the spec says.
2. Place the layer in a new `PlannerView` slot after the selection overlay, so it
   is inside `InteractionLayer`.
3. For `interactive: true`, have `InteractionLayer`, `CameraGestureDetector` and
   the secondary `Listener` ignore a pointer whose down hit an overlay child,
   through a marker render object on the hit path. Pan and zoom then start
   anywhere off a badge.
4. Clip the layer to the canvas.
5. Add mutants:
   - an interactive overlay's tap also reaches the table tool;
   - an interactive overlay's `localToGlobal` is off by the pan (killer: a
     non-identity camera).

### V-5 (Major) — C-4: `readOnly` is a view parameter, but the engine's permissions are fixed when the plan is decoded

**Evidence**
- The design plan is decoded with `DraftPermissions.all` in the controller's
  constructor and `load` (`floor_plan_controller.dart:137, 663`), before any view
  exists.
- `CommandDispatcher.permissions` is set at construction (`jet_cad_2d/.../undo.dart:153-157`).
- `editor` is a `FloorPlanView` parameter that "takes effect at the next build"
  (C-4). One controller can serve several views over its life.

So "the design plan opens with `DraftPermissions.readOnly`" cannot follow a
runtime change without re-decoding the plan, which loses undo and the selection.
It is also unclear whether `setTableData` and `controller.undo()` are refused
under a read-only view.

**Fix (pick one)**
- **(a)** Enforce `readOnly` in the shell only, like `tablesOnly`, and drop the
  engine sentence.
- **(b)** Make engine read-only a controller setting:
  - `FloorPlanController(designPermissions: …)`, applied at decode, or a
    `setDesignReadOnly(bool)` that re-decodes and says what it loses;
  - say what `setTableData`, `undo` and `load` do under it.

M-H43 follows whichever is chosen.

### V-6 (Major) — C-2, C-3: `ExportChoice` is (format, dpi); the dialog-free flows need the view's settings

**Evidence**
- `ExportChoice{format: ExportFormat, dpi: ExportDpi}` (`export/export_dialog.dart:15-37`).
  There is no "scale" and no "area".
- `ExportDpi` comes from `jet_cad_2d_flutter`. Neither enum is in the barrel.
- The flows read `exportName` (the file name) and `printer` from the view at
  call time (`host/page_flows.dart:16-20, 61-63, 76-77`).
- They run one at a time through `ready` (`:34, 82-92`).
- Export runs from the shell's `fileCommands`, its chords, the service bar and
  the service chords (`floor_plan_view.dart:173-190`; `service_view.dart:333-341, 372-378`).

**Fix**
- Make `FloorPlanExportChoice` (format, dpi) public with `FloorPlanExportFormat`
  and `FloorPlanExportDpi`, or re-export `ExportDpi`. List them in R-1's count.
- Signatures:
  - `Future<FloorPlanExport?> exportPlan(FloorPlanExportChoice choice, {String name = 'plan'})`;
  - `Future<bool> printPlan({PagePrinter? printer, String name = 'plan'})`;
  - each with its own one-at-a-time guard, the controller's `settle`, and the
    `identical(document, activeDocument)` checks of `page_flows.dart`.
- C-3: the hook replaces the dialog at **every** Export entry point (buttons and
  chords, both modes). Put it in `PageFlows.export`.
- Mutant: Ctrl+Shift+E (`kExportChords`) still opens the Material dialog when a
  hook is given.

### V-7 (Major) — C-4, R-4: the capability table misses edit paths, and its select-tool flags need hooks in `jet_cad_2d_flutter`

Every edit path in the editor, with what covers it. Paths marked **✗** have no
flag.

| Path | Code | Covered by |
|---|---|---|
| 15 palette tools and their letters | `planner_shell.dart:337-460, 870-872`; `shortcut_guard.dart:8-23` | `tools`, `keyboardShortcuts` |
| Symbols tab and gallery arming | `:782-795`, `_armSymbol :655-658` | `symbolPalette`, `symbolFilter` |
| Body drag, with wall attach | `select_tool.dart` `MoveResolver` | `move` (needs a hook) |
| Rotation grip | `select_tool.dart:326-336` | `rotate` (needs a hook) |
| **Reshape grips** (walls, openings, rooms, dimensions, separators, leaves) | `grip_cache.dart:367-389`; `select_tool.dart:300-323` | **✗** under `full` with `move: false` |
| Rubber band | `select_tool.dart` | must honour `selectTablesOnly` |
| Delete / Backspace | `select_tool.dart:659-660` | `delete` (needs a hook) |
| Selection panel: number | `selection_panel.dart:616-632` | `renumber` |
| Selection panel: rotation field, ±90 | `:561-565, 637-650` | `rotate` |
| Selection panel: **Mirror** | `:656-670` | **✗** |
| Selection panel: **Change size** | `:674-690` | **✗** (not for tables) |
| Selection panel: wall, opening, room, box fields | `:555-610` | only `selectTablesOnly` |
| Selection panel: **layer picker, move to layer** | `:1199`; `layers/layer_picker.dart:105-151` | **✗**; in `tablesOnly` a waiter can move a table onto a hidden or locked layer |
| Layer panel | `layers/layer_panel.dart:176-278` | `editLayers` |
| Page panel | | `editPage` |
| Undo / Redo, buttons and chords | | `undo` |
| Export / Print, `fileCommands` and chords | `floor_plan_view.dart:173-190` | `export`, `print` |
| F3 | | `snapping` |
| F (fill) | | drawing tools only; harmless |

Two more problems:
- `move`, `rotate`, `delete` and `selectTablesOnly` act inside `SelectTool`,
  which is in `jet_cad_2d_flutter` and has no such seam. The spec's "Touched"
  line does not list that change.
- `FloorPlanSymbol` (`symbolFilter`'s type) does not exist. The barrel has no
  symbol type; `SymbolEntry` is internal.

`tablesOnly`'s "palette filtered to tables" is expressible as `SymbolEntry.seats != null`
(`symbols/symbol_library.dart:47-49`).

**Fix**
- Add `mirror`, `reshape` (grips) and `changeLayer` flags.
- Define `FloorPlanSymbol` (key, name, category, tags, seats) or type the filter
  on `String key`.
- Name the `SelectTool` hooks: a pick filter, and move/rotate/delete/grip gates,
  in Slice 4's touched packages.
- Mutants:
  - `tablesOnly` shows Mirror;
  - `tablesOnly` shows the layer picker;
  - the rubber band picks a wall under `selectTablesOnly`.

### V-8 (Major) — C-5, F-11: the toolbar ruling is met for the service bar only; `fileCommands` is used

**Evidence**
- The ruling covers both roads: add or hide items, *or* switch the bar off and
  expose every command with its `canX`.
- C-1 and C-2 do this for the service bar.
- The editor gets only `editorActions` (C-5): no `visible: false`, no hidden
  built-ins, no exposed tool commands.
- F-11 and C-5 call `fileCommands` "unused". `FloorPlanView` passes Export and
  Print through it (`floor_plan_view.dart:173-190, 231`). Those are the editor's
  Export and Print.

**Fix**
- Either add a `FloorPlanEditorBar(visible, actions, leading, trailing)`, with
  `ValueListenable<FloorPlanTool> activeTool` and `bool selectTool(FloorPlanTool)`
  on the controller,
- or record the editor bar as out of scope (O-7) and confirm that with the human
  (a new Q-H4).
- Correct F-11 and C-5. `editorActions: List<Widget>` cannot express both
  "leading" and "trailing": use the service bar's shape.

### V-9 (Major) — E-6: refusing a plan for bad host data, with no schema bump, is a compatibility trap

**Evidence**
- "`FormatException` on read" inside a component factory propagates out of
  `ComponentRegistry.loadJson` (`component.dart:274-292`) and `decode`. The whole
  plan becomes "Not a floor plan" (`floor_plan_controller.dart:661-668`).
- Because E-9 keeps schema 8, a later release that relaxes a limit (say 64 keys)
  writes plans this slice refuses outright. Versioning exists to prevent that.

**Fix**
- Validate on write only.
- On read, a payload outside the limits is kept as unknown data, written back,
  reads as empty `data`, and is reported as a `Diagnostic`.
- Mutant: an over-limit payload throws on load.

### V-10 (Minor) — G-3: the camera commands' mechanics

**Problems**
- **Cancelling a fit.** The view's fit is a post-frame callback that does not
  check whether it is still wanted (`planner_view.dart:156-177`). Clearing
  `_fitPending` cannot cancel it.
- **Canvas size.** `zoomBy` and `centerOn` need the canvas size, which only
  `_PlannerViewState._size` knows. The controller learns the origin only
  (`canvasMeasured`, `floor_plan_controller.dart:465-470`).
- **Fits ignore the bounds.** `fitToPage`, `frameTables` and `ViewportTransform.fit`
  assign `camera.value` directly. A fit can land outside a host's
  `[minScale, maxScale]`, after which `zoomAt` refuses the inward direction
  (`camera_controller.dart:78-86`).
- **`panBy`** needs no canvas at all.
- **Before a mount.** `centerOn` before the first mount returns false, while
  `fitToTables` queues. That asymmetry makes a host's common "open centred on
  table 7" fail.

**Fix**
- A camera epoch: each fit request and command bumps it, and `_fit` returns when
  the epoch it captured has moved.
- Report the canvas size with the origin.
- Say whether fits clamp. I recommend they do.
- `panBy` always acts.
- `centerOn` either queues like a fit or the asymmetry is documented.
- `kMinScale` and `kMaxScale` are not public. Give their values in the
  documentation.

### V-11 (Minor) — G-1: definitions, and degenerate fixtures behind M-H1 and M-H3

**Definitions**
- `rotation` and `mirrored` need one decomposition. The label already uses one
  (`tables/table_label.dart` `tableLabelStamp`: `phi = atan2(b, a)`, mirror read
  from `det < 0`). Under it the mirror is always the local y axis.
- M-H3's "`scale.x < 0`" therefore has no meaning. A real mutant is
  `mirrored = a < 0`. Its killers:
  - an unmirrored 180° table;
  - a mirrored 90° table.
- `size` with a non-uniform scale: say "box width × |column 0|, height × |column 1|".
- `corners`: "counter-clockwise" holds only unmirrored (`table_picker.dart:113-116`).
  Say "in the box's order, reversed when mirrored", or normalise.

**Degenerate fixture.** Library tables are drawn about their base point. So
"`center` = the instance's translation `(e, f)`" passes every centred fixture.

**Fix**
- Add M-H13, centre = translation, killed by a definition whose box is off its
  base point.
- Add M-H14: `size` ignores the instance's scale.

### V-12 (Minor) — E-5: what the diff reports

**Problems**
- Layer changes are invisible: hide, lock, move to layer
  (`SetInstanceLayerCommand`). Yet `FloorPlanTable` gains `layer`, `locked` and a
  `center` that goes null on a hidden layer.
- In the selection mode, `load` and `newPlan` replace the design (`:661-690`).
  "Never fired by the selection mode" and `PlanReplaced` disagree there.
- `TableMoved` needs geometry, which is V-3's scan per design edit while anyone
  listens. Acceptable, but state it.

**Fix**
- Report a `TableChanged(before, after)` for any field change, replacing
  `TableMoved`, or add a layer event.
- Fire `PlanReplaced` on a design replacement in either mode.
- Mutant: an undone delete reads as remove+add. Identity by handle holds:
  `AddNodeCommand(node)` re-adds the same handle (`commands.dart:410-432`).

### V-13 (Minor) — E-1: a map by number loses tables

**Evidence**
- `Map<String, FloorPlanTable>` collapses two moved tables that share a number.
- It drops unnumbered ones.
- The drag already knows the moved handles (`table_select_tool.dart:98-106, 410-421`).

**Fix**
- `List<FloorPlanTable>` (or placements, V-2), ascending.
- Mutant: two moved tables share a number, and one is lost.

### V-14 (Minor) — E-2: double-tap timing

**Problems**
- `ToolPointerEvent` has no timestamp (`jet_cad_2d_flutter/.../tool.dart:19-37`).
- A finger's down reaches the tool up to `kTouchHoldBack` (100 ms) late
  (`interaction_layer.dart:33, 199`). A timer started at the first up therefore
  gives touch about 200 ms.
- Undefined cases:
  - two tables sharing a number ("same table": by instance, or by number?);
  - a locked table;
  - a modifier-held double click, which toggles twice and leaves the selection
    as it was.

**Fix**
- Time from the raw pointer events, by adding `timeStamp` to `ToolPointerEvent`.
  That touches `jet_cad_2d_flutter` and goes in the Touched line.
- "Same table" means the same instance.
- A locked table reports double taps.
- Mutants: the second tap comes after `kDoubleTapTimeout`; the downs are more
  than `kDoubleTapSlop` apart.

### V-15 (Minor) — Slice 3: what the theme must reach

**`selectionColor`**
- It feeds `PaperPalette`. Both `ServiceView` and `PlannerShell` pass that into
  `PlannerView` (`service_view.dart:413`; `planner_shell.dart:977`).
- T-1 does not say whether the editor's selection follows it.
- `PaperPalette` picks the selection colour by the paper (light or dark,
  `canvas_palette.dart:131-156`), so one colour cannot follow a dark canvas.
- `hover` derives from it, and the stroke width is a `const`
  (`selection_style.dart:9`).

**`canvasBackground`**
- It must also replace `colorScheme.surface` inside `displayPaperFor`
  (`service_view.dart:258-261`; `planner_shell.dart:211-214`). Otherwise a
  page-less plan inks black on a dark background.

**`statusCaptionStyle.color`**
- Null must keep today's automatic black or white ink (`canvas_palette.dart:206-211`).

**The chrome group**
- `panelColor`, `panelForeground`, `panelBorderColor`, `serviceBarColor`,
  `canvasBackground` restate what a host already sets by wrapping the view in a
  local `Theme` with an exact `ColorScheme`.
- F-4's "cannot match shadcn tokens exactly" is true only of `fromSeed`. A
  hand-built `ColorScheme` matches exactly.

**Fix**
- State the modes T-1 reaches.
- Selection colours per paper (`selectionOnLight` / `selectionOnDark`), or a
  documented single colour.
- Cut the chrome group to what `Theme` cannot express (`serviceBarHeight`), and
  document the local-`Theme` recipe.

### V-16 (Minor) — Gaps for a generic host

The spec should cover these, or put them out of scope:
- **Service-mode shortcuts.** Undo, Redo, Export and Print chords are always
  bound (`service_view.dart:333-341`). This collides with a host's own (Monépro's
  `PosShortcutsHost`, spec 103 B.2 `:901`). Add `serviceShortcuts: bool`.
- **Focus.** Both modes take `autofocus` (`service_view.dart:349`;
  `interaction_layer.dart:454`). They steal focus from a host's search field
  beside the plan ("unplaced tables"). Add `autofocus: bool`.
- **Camera lock.** No way to lock user pan and zoom in the selection mode (a
  kiosk or wall display).
- Export or print failures have no error callback.
- Out of scope, stated: string overrides beyond the three languages;
  accessibility of tables.

### V-17 (Minor) — G-5: overlay lifetime and look

**Evidence**
- `ServiceView` is keyed by the copy (`floor_plan_view.dart:206`). Every
  `resetLayout`, `restoreServiceLayout`, `load` and mode switch remounts every
  host overlay, so its State (animations, Bloc subscriptions) is lost.
- A service drag moves only the selection outline (`selectionPreviewTransform`,
  `table_select_tool.dart:135-136`). The drafting and the overlays move on drop.
- Undefined:
  - which `status` the overlay gets when a group status overrides the table's
    (G3);
  - the element key with duplicate numbers.

**Fix**
- Document both behaviours, or hoist the layer above the keyed subtree.
- Key elements by instance internally.
- Define `status` as the effective (drawn) one.

### V-18 (Minor) — P-4, invariant 7: the allocation gates named do not see the new code

**Evidence**
- `query_allocation_test` (`jet_cad_2d`) and `paint_allocation_test` (`jet_cad_2d_flutter`)
  never build a floor-plan overlay or theme.
- `ViewportTransform.worldToScreen` allocates a `Vector2` per call
  (`viewport_transform.dart:56-59`). A naive per-table, per-frame position is one
  allocation per table per frame.
- P-4's "rebuild no widget" is already untrue in the design mode: the zoom
  read-out rebuilds per camera change (`planner_shell.dart:943-947`).

**Fix**
- Give `RenderFloorPlanOverlays` a `debugAllocations` counter with its own
  steady-state test (0 per table per camera change).
- Name the floor-plan painters' counter tests in invariant 7.
- Reword P-4: "no widget beyond today's zoom read-out".

### V-19 (Nit) — Over-engineering to cut

- `splitCandidate` is `selectedGroup` (`floor_plan_controller.dart:343`).
- `canUndo` and `canRedo` are already `ValueListenable<bool>` (`:370-371`). C-2's
  first bullet adds nothing, but note that the shell's buttons also wait for an
  idle tool (`planner_shell.dart:531-534`).

### V-20 (Nit) — Naming

- **Unprefixed event names.** `TableAdded`, `TableMoved`, `PlanReplaced` and the
  rest are unprefixed in a barrel hosts import whole. Monépro's floor module has
  table moves of its own (spec 103 §5.3). Use `FloorPlanTableMoved`… or nest
  them.
- **Two `minScale`s.** `minScale` means the camera bound (G-3) and an overlay
  cutoff (G-6). Rename the second `hideBelowScale`.
- **`editor`.** Rename to `editorCapabilities`.
- **Class modifiers.** `FloorPlanServiceBar` is a plain `class`. Make it
  `final class` with `==`, like the other value types.

### V-21 (Nit) — Facts and invariant 1

- **F-12:** `DraftPermissions.readOnly` is at `command.dart:61`, not `:56`.
- **F-11 / C-5:** see V-8.
- **G-2, "no host could reach it":**
  - `@internal` is an analyzer warning, not a compile error;
  - `apps/restaurant_demo/test/demo_test.dart:7` ignores it and *writes*
    `c.camera.value = ViewportTransform(…)` (`:312-318`);
  - the rename must update it (and ~300 internal and test uses).
- **Invariant 1:** rather than a hand-kept frozen copy, run
  `git show v0.3.0:tool/ci/host_probe/lib/main.dart` into the probe and
  `flutter analyze` it. It needs no upkeep. `flutter build web` builds only
  `main.dart`, so "built" means analysed. It proves compilation, not behaviour;
  invariant 2 carries behaviour.

### V-22 (Minor) — Named mutants: what is missing

Beyond those named above (M-H13, M-H14, M-H27, V-4, V-6, V-7, V-9, V-12, V-13,
V-14):
- **Slice 1:**
  - the builder runs for every table when one table's status changes (per-table
    counter);
  - an overlay off its table after pan and zoom (non-identity camera,
    `closeTo` 1e-6);
  - overlays shown in the design mode by default;
  - `tableAt` ignores the finger's reach;
  - `canvasRect` stale after the view moves without relayout.
- **Slice 2:**
  - `onTableHover` fires per move, or for touch;
  - `setTablesData` writes part of a batch with one bad entry (atomicity is
    unstated);
  - an empty map leaves an empty component (byte golden);
  - `designChanges` fires from the selection mode.
- **Slice 3:**
  - a theme change without a paper change does not repaint (painter key);
  - `statusFillOpacity` applied twice.
- **Slice 4:**
  - a capability change at runtime leaves a forbidden tool active;
  - `symbolFilter` not applied to search results;
  - `serviceBar.visible: false` leaves the 44 px seed uncorrected (R-13
    measurement).

## Facts verified (at `5bdb823`)

| Fact | Verdict | Evidence |
|---|---|---|
| F-1 | Correct | spec 103 `:241-244` (D21, D22), `:276` (SH), `:879-882` (B.1) |
| F-2 | Correct | `:241-242`, `:835` |
| F-3 | Correct | `:886-890`, `:913`, `:401` |
| F-4 | Correct as cited; the inference is too strong (V-15) | `wiki/conventions/ui.md:26-45`; `lib/app.dart:149-190` |
| F-5 | Correct | barrel `show` lists; `barrel_test.dart:11-30` |
| F-6 | Correct | `floor_plan_types.dart:20-56`; `tables/table_index.dart:13, 45` |
| F-7 | Correct | `floor_plan_controller.dart:203-209`; `camera_controller.dart:44-56`; `startup_plan.dart:50-51`; `viewport_transform.dart:56-59`; `:465-470` |
| F-8 | Correct | `table_picker.dart:103-137`, `:233-268`, `:278-306` |
| F-9 | Correct | `planner_view.dart:97-107`; `service_view.dart:420-462`; `debugAllocations` in `table_focus_painter.dart:76`, `table_status_painter.dart:134` |
| F-10 | Correct | `table_status_painter.dart:39`; `canvas_palette.dart:207, 211`; `table_group_painter.dart:21-30`; `selection_style.dart:9`; `table_focus_painter.dart:17` |
| F-11 | **Partly wrong** | `fileCommands` is used (`floor_plan_view.dart:173-190, 231`); the rest is correct (`service_view.dart:352-390`, `export_dialog.dart:41-62`, `planner_shell.dart:337-460`) |
| F-12 | Correct, line nit | `command.dart:61` (not `:56`); `planner_shell.dart:636-648` |
| F-13 | Correct | `table_select_tool.dart:20-45, 98-106` |
| F-14 | **Partly wrong in consequence** | preserve-unknown `component.dart:209-286` (E1: byte-exact); `commands.dart:490, 552` correct; but node removal keeps components (V-1); `schema_version.dart:25-31` correct |
