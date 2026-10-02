# Layer panel (12b) — design

**Date:** 2026-10-01. **Status:** design, **revision 3**. Revision 1
(`630a311`) was reviewed independently: "Not ready", 2 blocking, 9 major,
7 minor, 1 nit (R-1 to R-19), each applied below; see
[Revision 2](#revision-2). Its spot check (`c945986`): "Ready with
amendments" (S-1 to S-16), applied in [Revision 3](#revision-3).
**Approved by the human on 2026-10-01** ("onaylıyorum, devam et"), with
the two rulings made in writing: the opening tool's host (S-11) and the
ATTRIB style residual (S-2).
**Sub-project:** `roadmap/12-app-shell.md`, the second slice (12b) after
12a's document lifecycle. **Size:** M–L, one plan (the human's decision 9),
about ten tasks.
**Branch:** `spec-12b/layer-panel`, cut from `main` at `7330c7b`.
**Depends on:** 06 (the parametric system), 09 (symbols), 12a (the shell, the
command table, the save point).
**Brainstormed with the human on 2026-10-01**, on `main`, after a survey of
the layer table, the commands, the filter caches, the painter, the style
resolver, the parametric regeneration, the codec and the app's panels (the
facts below are from `main` at `7330c7b`).

**Inputs read:** `CLAUDE.md`; `STATUS.md`; `roadmap/12-app-shell.md`;
`packages/jet_cad_2d/lib/src/document/{tables,command,commands,undo,
doc_change,header,node,drafting,style_resolver,style_context,component,
draft_document}.dart`; `lib/src/index/{query_filter,spatial_index}.dart`;
`lib/src/parametric/{parametric_system,regeneration}.dart`;
`lib/src/codec/{json_codec,schema_version}.dart`;
`packages/jet_cad_2d_flutter/lib/src/{draft_canvas,draft_painter,
reference_walk,selection,select_tool,outline_cache}.dart` and
`lib/src/draw/{line_tool,text_tool,placement_tool}.dart`;
`apps/floor_planner/lib/{main,document_host,selection_panel,page_panel,
startup_plan}.dart`, `lib/parametric/{catalog,live_objects,box_tool,
wall_tool,opening_tool,separator_tool,room_tool,dimension_tool,
dimension_attach,wall}.dart`, `lib/symbols/{symbol_placer,symbol_library,
symbol_panel}.dart`.

## Decisions the human made on 2026-10-01

1. **The slice is the layer panel** (over the inspector, the menu bar, and
   autosave with recent files).
2. **The full set:** create, rename, colour, visibility, lock, a current
   layer that new drawing goes to, and moving the selection to a layer.
   Only an **empty** layer can be deleted.
3. **Every layer change is a command:** one undo step each, and each marks
   the document dirty. The current layer is stored in the document.
4. **A parametric object's layer is a component on its group**
   (`ObjectLayer`); the parametric system writes it onto every generated
   child after regeneration, centrally. No generator knows about it.
   Moving an object is one `SetComponentCommand`, one undo step. A new
   object takes the current layer.
5. **The panel is a collapsible "Layers" section in the right panel.** Each
   row: the current-layer mark, an eye, a lock, a colour swatch, the name;
   + and delete below. Moving the selection is a layer menu in the
   Selection section.
6. **Colour is chosen from ACI 1–9** (red, yellow, green, cyan, blue,
   magenta, the foreground 7, dark grey 8, light grey 9), stored as
   `IndexedColor`. A layer's linetype and lineweight are out of scope and
   kept as they are.
7. **The current layer cannot be hidden**, and a hidden layer cannot be
   made current. The current layer can be locked: what is drawn on it is
   drawn and not selectable. Objects on a layer that becomes hidden or
   locked leave the selection. Layer 0 cannot be deleted or renamed; the
   current layer cannot be deleted.
8. **Hiding and locking are view and selection only.** A hidden or locked
   wall still joins, still is cut by its openings, still bounds its rooms,
   and a neighbour's edit still regenerates it. A dimension still attaches
   only to what is drawn (11's rule, unchanged).
9. **A new document has layer 0 only; every tool draws on the current
   layer**, dimensions included. Roadmap 12's "a layer for dimensions"
   question closes as "the current layer".
10. **One plan.** Engine first, then the app.
11. (During writing, asked mid-turn.) **The layer list is its own widget**,
    `LayerPanel`, in its own file; the right panel only places it. Its rows
    are a `LayerRow` widget; the Selection section's menu is a
    `LayerPicker` widget.

## What this delivers

A user can make layers, name and colour them, hide and lock them, choose the
layer new drawing goes to, and move what is selected to another layer —
lines, text, symbols, walls, openings, rooms, dimensions alike — each step
undoable and each one making the document dirty. Hidden layers do not draw,
do not pick, do not snap and do not plot (13's export and print follow the
same filter). The file keeps the layers and the current layer.

## Non-goals

- A layer's linetype, lineweight, transparency or plot flag in the UI (the
  record keeps whatever it has; new layers get layer 0's).
- Freeze/thaw, layer states, layer filters or groups, per-viewport layers.
- Deleting a layer that is in use, or merging layers.
- Changing an object's colour, lineweight or linetype (the inspector, a
  later slice).
- `DraftPermissions` throughout the UI (a later slice); this slice gates
  only its own controls (D11).
- A layer order the user arranges (rows are sorted, D10).
- DXF anything (roadmap 13 trap; file 14 if wanted).

## Facts established (verified on main at 7330c7b)

**F1 — The record exists; no command touches it.** `LayerRecord`
(`document/tables.dart:139-200`) is `@immutable` with `name`, `color`,
`linetype`, `lineweight`, `transparency`, `visible`, `locked`, and no
`copyWith`. A table edit is remove-then-add on `TableSection`
(`tables.dart:73-136`), whose `add` throws on a duplicate handle or a
case-folded duplicate name (`:113-122`). No command in `commands.dart`
touches a table or the header, and `CommandTarget` (`command.dart:87-104`)
has no `header`.

**F2 — Table edits are invisible to the save point.** `CommandDispatcher`'s
`stateId` (`undo.dart:185`) moves only through the dispatcher, and the app's
`DocumentSession` is clean iff `stateId == _savedState`
(`apps/floor_planner/lib/document_host.dart:53-64, 113`). A direct
`TableSection` write fires `DocumentTables.changes` (which `DraftCanvas`
merges into its repaint, `draft_canvas.dart:53-84, 372, 394-400`) and
nothing else: no `DocChange`, no dirty mark, no panel refresh.

**F3 — The filter caches layer state and nothing invalidates it on an
edit.** `FilterEvaluator` (`index/query_filter.dart:77-180`) memoises
`_layerVisible`, `_layerLocked` and `_containerVisible`; its own comment
(`:67-76`) says the first command that can flip a layer's visibility or lock
must invalidate it. The long-lived one is `SpatialIndex._filters`
(`spatial_index.dart:272`), used by every query, including the painter's
two root queries (`draft_painter.dart:373, 385`). `invalidate()` is called
only from `rebuildAll()` (`spatial_index.dart:2446-2452`), and `_onChange`
returns early for a `Capability.components` change (`:2651-2669`).
**But** any other change goes to `_reconcile(touched)`, and a touched handle
that is neither an entity, a node nor a definition falls through
`_reconcileEntity` to `rebuildAll()` (`:2802-2827`): a command naming a layer
handle would rebuild the whole index, invalidating the cache as a side
effect (R-1).

**F4 — An entity's layer is read live.** `acceptsEntity` reads
`document.entities.layerAt(slot)` per call (`query_filter.dart:91-113`), and
`acceptsNode` reads an `InstanceNode`'s `layer` per call (`:115-137`); only
the per-layer *answer* is cached. Moving an entity to another layer
therefore needs no index work; changing a layer's `visible` or `locked`
needs the cache dropped.

**F5 — Layer-0 substitution exists for style, not for visibility.** The
resolver gives an entity on layer 0 the context's layer
(`style_resolver.dart:177-178`) and an instance on layer 0 its parent's
(`:104-105`). The filter applies no such substitution: inside an instance,
picking and snapping test each leaf's *stored* layer
(`spatial_index.dart:571, 865, 881`), while the painter draws a
definition's contents with no filter at all (`draft_painter.dart:440-523`).
The symbol library forces every symbol leaf onto layer 0
(`symbols/symbol_library.dart:213-217`). So hiding or locking layer 0 today
leaves every symbol drawn and makes it unpickable.

**F6 — Every new thing is on layer 0.** `draftRecord` hard-codes layer 0
(`document/drafting.dart:27-44`), and `addDrafted` / `addDraftedRegion` use
it (`:49-87`); the line, text, arc, circle, rectangle and polyline tools go
through them (`draw/line_tool.dart:44`, `draw/text_tool.dart:67`,
`draw/placement_tool.dart:250, 253`). The symbol placer writes layer 0 on
the `InstanceNode` (`symbols/symbol_placer.dart:128`). Each parametric tool
creates `CompoundCommand[AddNodeCommand(GroupNode), SetComponentCommand
<XParams>]` (`box_tool.dart:29-37`, `wall_tool.dart:223-228`,
`opening_tool.dart:248-253`, `separator_tool.dart:95-100`,
`room_tool.dart:202-207`, `dimension_tool.dart:300-305`); a `GroupNode` has
no layer, and `_recordOf` (`regeneration.dart:437-452`) builds every
generated child from `draftRecord`, so on layer 0.

**F7 — A generated child cannot be edited directly, and regeneration does
not rewrite its record.** `_refused` (`regeneration.dart:624-640`) rejects a
command that touches an existing generated child. A matched child's payload
(and a TEXT's string) is rewritten in place; "nothing else of the record is
read or rewritten" (`:578-592`; the rule is 06 D11 and 10 D13,
`parametric_system.dart:196-206`). A `SetComponentCommand` on an object's
group seeds that group's regeneration (`regeneration.dart:952-959`).

**F8 — The header is copied field by field.** `DocumentHeader`
(`document/header.dart:8-90`) writes a fixed key order and already reads
`globalLinetypeScale` as optional (`:61-62`); `_loadHeader`
(`codec/json_codec.dart:169-178`) copies each field by hand.
`kSchemaVersion` is 6 (`codec/schema_version.dart`), and the reader refuses
a newer version (`json_codec.dart:105-108`). An unregistered component
type is preserved verbatim and `get<T>` returns null
(`document/component.dart:65, 112-131`).

**F9 — The selection never drops a hidden key.** `SelectionController`
prunes only keys that no longer resolve (`selection.dart:160-173`); the band
filters with `QueryFilter.picking()` (`select_tool.dart:452-489`).

**F10 — The oracle has no layers.** `reference_walk.dart` skips only
`EntityFlags.invisible` (`:135`); it reads no layer at all, style comes
through `resolver.contextFor` (`:85-86`).

**F11 — The right panel.** `main.dart:946-975`: a 280-wide column of
`SelectionPanel` then `Expanded(PagePanel)`, inside `ShellShortcutGuard`.
`SelectionPanel` (`selection_panel.dart:775-899`) is not scrollable and
listens to `document.commands.changes`; it reads
`document.commands.permissions` itself (`:247-252`).

## Decisions

### D1 — Layer commands (engine)

New commands in `packages/jet_cad_2d/lib/src/document/layer_commands.dart`,
exported from the package:

| Command | Effect | Inverse | `capabilities` | `capability` |
|---|---|---|---|---|
| `AddLayerCommand(record)` | `tables.layers.add` | `RemoveLayerCommand` | `structure` | `structure` |
| `RemoveLayerCommand(handle)` | removes an **empty** layer (D5) | `AddLayerCommand(old)` | `structure` | `structure` |
| `SetLayerCommand(record)` | replaces the record with the same handle (remove, add) | `SetLayerCommand(old)` | `structure` | `structure` |
| `SetCurrentLayerCommand(handle)` | `header.currentLayer = handle` | `SetCurrentLayerCommand(old)` | `structure` | `structure` |
| `SetEntityLayerCommand(entity, layer)` | `entities.replace(record.copyWith(layer:))` | the old layer | `components` | `geometry` |
| `SetInstanceLayerCommand(node, layer)` | replaces the `InstanceNode` with `copyWith(layer:)` | the old layer | `components` | `geometry` |

- `entity` and `node` are `Handle`s (R-19).
- `LayerRecord` gains `copyWith`.
- `CommandTarget` gains `DocumentHeader get header`; `DraftDocument`
  already has it. The two test fakes (`commands_test.dart:7`,
  `command_test.dart:7`) gain it too.
- `touched` is never empty (an empty set makes `_reconcile` rebuild and
  `TileCache` drop everything, `spatial_index.dart:2683-2690`,
  `tile_cache.dart:1883-1888`): the layer handle for a table command,
  `{old, new}` for `SetCurrentLayerCommand`, the edited entity or node for
  a move.
- **Two capabilities, as `ParametricEdit` already splits them (R-8).**
  `capabilities` is what the dispatcher checks against permissions;
  `capability` is what a listener reads as "what moved". A layer move
  changes pixels (ByLayer colour, visibility), so it must not be skipped by
  the listeners that skip `components` (`SpatialIndex._onChange`,
  `TileCache.applyChange`, `tile_cache.dart:1882`). A `CompoundCommand`'s
  and a `ParametricReplay`'s `capability` is its highest-ranked child's, so
  the undo of an object move (a replay containing `SetEntityLayerCommand`s)
  reports `geometry` too.
- **Why `structure`** for the table commands: the `runtime` preset (a
  point-of-sale user who may move and edit properties) must not reorganise
  the drawing's layers, and `readOnly` must refuse all of them. **Why
  `components`** for moving one thing: it is a property edit, which
  `runtime` allows, and `SetComponentCommand<ObjectLayer>` (D2) is
  `components` too, so moving a mixed selection needs one permission.

**Validation (R-2, R-3).** Every command has two constructors:

- **The user form** (the panel, the picker, the tools) checks the user rules
  before any mutation and throws `ArgumentError` with the reason:
  - D4 names, for `AddLayerCommand` and for `SetLayerCommand` (the record
    itself excluded from the duplicate check, so a case-only rename works).
    An untrimmed name is refused; the UI trims.
  - Layer 0's name cannot change.
  - Decision 7, against the **effective** current layer (D3):
    `SetLayerCommand(visible: false)` on it is refused, and
    `SetCurrentLayerCommand` on a hidden layer is refused.
  - A missing target layer is refused.
- **The restore form** (`.restore`), which every inverse and every
  regeneration plan command uses, checks integrity only (the handle exists
  where the operation needs it: the record to replace, the entity, the node)
  and restores the stored value exactly, whatever it is. So undo and redo
  never throw on a state a file can hold: a dangling or hidden current
  layer, a loaded name that fails D4, an entity on a missing layer.
- `SetLayerCommand` checks everything before its `remove`, so the
  remove-then-add cannot lose the record ("complete or untouched").

### D2 — `ObjectLayer` and the regeneration's stamp (engine)

- A new engine component `ObjectLayer(Handle layer)`, `typeId`
  `jet_cad.object_layer`, registered by `ComponentRegistry.registerBuiltIns`
  (so every document, the app's and a test's, decodes it), **not**
  `internal` (S-16): it is document content a future DXF export writes.
- `objectLayer`, `drawingLayer` and `layerNameError` take a `CommandTarget`
  (which now carries `header`), so the commands and `_plan` can call them;
  a `DraftDocument` is one (S-12).
- **The stamp is the parametric system's.** D5, D8, D12 and
  `dimension_attach` read the component too (R-19); none writes it but a
  `SetComponentCommand`.
- **The object's layer**, `objectLayer(target, group)`: the component's
  layer when that layer exists, else layer 0. Absent means layer 0, which
  is every object in every file written before this slice. A component
  naming a missing layer is kept as stored (a stored value) and is
  diagnosed (D3's validation), never refused (R-9).
- **Added children:** `_recordOf` takes the object's layer; every added
  record, a region's fill and boundary both, and a TEXT, is on it.
- **Matched children:** a new step in `_plan`, after the payload rewrite —
  a matched child whose stored layer differs (exact `==`) from the object's
  gets a `SetEntityLayerCommand.restore` in the plan; a matched region gets
  one for its fill and one for its boundary, each only if it differs. This
  **amends 06 D11 / 10 D13 for one column**: the layer is now rewritten on a
  match; every other attribute is still written on add only. The amendment
  is recorded in the `Generated` class comment.
- **The `!=` guard is load-bearing (R-15):** without it every regeneration
  plans commands, and `ParametricEdit.capability` becomes `geometry` for
  every edit (`parametric_system.dart:701-704`). Gated by M-LP-6.
- Plan commands are not the edit's `touched`, so `_refused` does not reject
  them (F7).
- **Moving an object** is `SetComponentCommand<ObjectLayer>(group, …)`,
  which seeds its regeneration (F7): one `ParametricEdit`, one undo step,
  undone by `ParametricReplay` without regenerating.
- **Deleting an object detaches its `ObjectLayer` (R-4).** `RemoveNodeCommand`
  does not detach components, and 06 D8's cleanup and 10 D15's dissolve
  detach only the registered type's. Both now also plan
  `SetComponentCommand<ObjectLayer>(h, null)` when the object carries one,
  so undo replays it and no dead handle keeps a layer alive.
- **A new object** gets `ObjectLayer(drawingLayer(document))` in the
  creation compound of every parametric tool (F6's six), layer 0 included.

### D3 — The current layer (engine, codec)

- `DocumentHeader.currentLayer`, a `Handle`, default
  `ReservedHandles.layerZero`.
- `toJson` writes it after `globalLinetypeScale`; `fromJson` reads it as
  optional, defaulting to layer 0; `_loadHeader` copies it (F8).
- **`kSchemaVersion` becomes 7**, with the paragraph the file's pattern
  asks for: v6→v7 adds `header.currentLayer` (absent ⇒ layer 0) and the
  `jet_cad.object_layer` component; the bump exists so a v6 build refuses a
  v7 file instead of dropping the current layer and every object's layer.
- **One engine function, `drawingLayer(target)` (R-10):** the stored
  current layer when it names an existing, visible layer, else layer 0.
  It is the **effective** current layer, and every decision that says
  "current" uses it: decision 7's checks (D1), D5's emptiness, the tools
  (D7), the panel's mark and its disabled eye (D9). So with a stored hidden
  current layer H, H behaves as an ordinary layer (it can be shown, renamed,
  recoloured, deleted when empty) and layer 0 is the effective current
  layer. **Showing H makes it current again**: the stored value was never
  changed, and `drawingLayer` follows it (S-5).
- The stored value round-trips exactly (a stored value), dangling or not.
- **Validation (R-16):** `lib/src/document/validate.dart` gains two codes in
  `ValidationCodes`, `header.current_layer_unusable` (the stored current
  layer names no layer or a hidden one) and `component.object_layer_missing`
  (an `ObjectLayer`, on any handle, live or dead, names no layer), both **warnings** (`validate.dart` gains
  a `warning()` helper next to `error()`). Nothing in the app displays
  diagnostics yet (the diagnostics surface is a later slice); the tests read
  them.
- `DraftDocument.empty` and `DocumentTables.standard()` are unchanged:
  a new document has layer 0 only (decision 9).

### D4 — Names

- A name is valid when it is non-empty, equal to itself trimmed, at most 255
  UTF-16 code units (`String.length`), contains none of the DXF-forbidden
  characters `<`, `>`, `/`, `\`, `"`, `:`, `;`, `?`, `*`, `|`, `=` and the
  backtick, and is not a duplicate of another layer's under `toLowerCase()`
  (`TableSection`'s own folding, `tables.dart:113-122`).
- One function, `layerNameError(target, name, {Handle? self})`, returns
  the reason or null; the command and the UI both call it.
- A new layer from the panel's + is named `Layer N`, the smallest `N ≥ 1`
  not taken, colour ACI 7, and layer 0's linetype, lineweight and
  transparency; visible and unlocked. Its handle is the next from the
  document's `handleSeed`.

### D5 — Empty

A layer is **empty** when no entity record (root or inside a definition),
no `InstanceNode`, and no `ObjectLayer` component **on a live node** names
it, and it is not `drawingLayer(document)` and not layer 0. One pass over
the entity store, the tree and the `ObjectLayer` components, O(n), computed
only on a delete and for the panel's one selected row (D9), never per
rebuild of the whole list.

### D6 — Visibility and lock reach the frame (engine, render)

- **A layer edit does not rebuild the index (R-1).** `_reconcile` skips a
  touched handle that names a record in `tables.layers` (a hash lookup per
  touched handle) before it reaches `_reconcileEntity`'s rebuild fallback.
  A hide, show, lock, unlock, rename or recolour therefore costs the index
  nothing but D6's invalidation. **A handle no longer in the table** (a
  `RemoveLayerCommand`, the undo of an `AddLayerCommand`, a current layer
  naming a dangling handle) still falls through to one rebuild; that is
  rare and harmless, and is left as it is (S-4). Gated by a `rebuildCount`
  assertion across hide, show, lock, rename and recolour (M-LP-2).
- **`SpatialIndex` drops its filter cache when the tables change.** It keeps
  the `mutationRevision` it last saw; `_beginQuery()`, which all six query
  entry points call (`spatial_index.dart:301, 329, 380, 435, 756, 1479`),
  compares it with `document.tables.mutationRevision` (one int compare per
  query, not per entity) and calls `_filters.invalidate()` when it moved;
  `rebuildAll` records the revision too. This covers the commands, their
  undo and redo, and a direct table write alike.
- The repaint already happens: a command's `DocChange` and
  `tables.changes` both reach `DraftCanvas`'s repaint (F2).
- **The effective layer (layer-0 substitution) for visibility and lock,
  recursive (R-11).** A leaf on layer 0 inside an instance is tested against
  the instance's effective layer, which is itself its own layer or, when
  that is layer 0, its parent instance's — the resolver's rule
  (`style_resolver.dart:104-105, 177-178`).
  Applied everywhere a contained
  leaf or nested instance is filtered:
  - picking, band selection and snapping of leaves inside instances
    (`spatial_index.dart:571, 865, 881`);
  - nested instances inside a definition, tested by `acceptsNode`
    (`spatial_index.dart:587, 909`) (S-7);
  - `OutlineCache`'s instance walk (`outline_cache.dart:330-377`);
  - **an ATTRIB (S-2).** Its owner is the `InstanceNode` (`node.dart:148-151`)
    and it is a root-index leaf, drawn by the painter's root
    `forEachInRect` pass (`draft_painter.dart:385-395`). So its rule lives
    in `FilterEvaluator.acceptsEntity`: when `ownerAt(slot)` is an
    `InstanceNode` and the leaf is on layer 0, it is tested against the
    owner's effective layer, memoised per owner as `_containerVisible` is
    (no allocation in steady state). This covers rendering, picking,
    snapping and the band at the root. An ATTRIB's **style** stays as today
    (the root context, not substituted): a residual, recorded, out of
    scope.

  The effective layer is carried down the walk in a **preallocated
  per-depth array**, as `_containerPath` is, because pick and snap run on
  the hover path: no allocation per entity or per query.
- The painter's definition walk stays unfiltered: the instance's own layer
  (tested by `acceptsNode`) decides whether a symbol draws, and with
  substitution a symbol's layer-0 leaves cannot be hidden apart from it.
  **Residual, recorded:** a definition leaf on a non-zero hidden layer still
  draws; the library refuses such a symbol, so only a hand-written file
  reaches it.
- **The oracle learns layers.** `reference_walk` skips a root-level leaf
  whose layer is hidden (an ATTRIB by its owner's effective layer, as
  above) and an instance whose effective layer is hidden, so the
  differential test covers hiding (F10).
- **Export and print** build their own `SpatialIndex` per export
  (`page_export.dart:222-240`) and therefore the same filter: a hidden layer
  does not plot. Asserted by a test, no code change expected.
- **`dimension_attach` (R-7).** A host wall is kept only when
  `acceptsNode(host, rendering())` holds **and** `objectLayer(host)` is
  visible. The file's residual (`dimension_attach.dart:68-80`), which a
  command can now reach (a wall on a hidden layer whose opening is on a
  visible one), is closed for objects; its doc comment is updated.
- **The opening tool's host (S-11).** The tool picks its host wall by band
  geometry over every wall, unfiltered (`opening_tool.dart:50-56`). A tool
  acting on a wall under the pointer is selection-like, so the host must
  have a visible and unlocked `objectLayer`; a door cannot be placed on a
  wall the user cannot see or select. (Decision 8 is unaffected: a hidden
  wall's existing openings still cut it.)

### D7 — Tools draw on the current layer

- `draftRecord`, `addDrafted` and `addDraftedRegion` gain a required
  `layer` parameter (no default, so no caller silently keeps layer 0).
- The drawing tools pass `drawingLayer(document)` (D3).
- The symbol placer writes `drawingLayer` on the `InstanceNode`; the
  definition's leaves stay on layer 0 (the library's rule) and follow the
  instance by substitution.
- Parametric tools: D2's `ObjectLayer(drawingLayer(document))`.
- `_recordOf` passes the object's layer (D2).
- The sample document (`startup_plan.dart`) passes layer 0 explicitly; its
  content is unchanged (R-13).
- **Blast radius (R-13), for the plan:** about 55 call lines outside
  `drafting.dart` gain `layer:` — the engine's `drafting_test` and
  `json_codec_test`, `expander_test`, and the parametric tests (`cascade`,
  `diagnose`, `guards`, `live_object_rule`, `misplaced`, `neighbour_cost`,
  `neighbourhood`, `place`, `references`, `regeneration`, `regions`); the
  app's `dimension_object`, `dimension_tool`, `opening_cost`,
  `opening_tool`, `planner_draw`, `room_cost`, `room_grips`, `room_panel`,
  `room_tool`, `selection_panel`, `separator_tool`,
  `symbols/symbol_place_tool` and `wall_tool` tests. `dev_harness_2d` has no
  caller. These edits pass `layer: ReservedHandles.layerZero` and change
  nothing else.

### D8 — Selection follows hiding and locking (render)

`SelectionController`, on every `DocChange`, also drops a key (and the
hover, if it names one, R-14) that picking could no longer select: its
target's effective layer — a root entity's own (a drafted region's is its
boundary's, D12), an instance's, or a parametric object's `objectLayer` —
is hidden or locked. Keys are root keys (`selection.dart:49-75`), so this
is O(selection) per change with no per-entity work. The outline cache
re-walks on the same change, so no outline or grip is left behind.

### D9 — `LayerPanel` (app)

- `apps/floor_planner/lib/layers/layer_panel.dart`: `LayerPanel(document)`,
  a stateful widget that keeps **no copy of the layers**: it rebuilds from
  `document.tables.layers` and `drawingLayer(document)` on
  `document.commands.changes` (every edit is a command) and on
  `tables.changes` (for a direct table write, which no shipped code makes
  but the engine allows; the subscription is removed on dispose). Open
  replaces the `DraftDocument` and the shell (S-15); if the panel is ever
  reused across documents, `didUpdateWidget` re-subscribes. Permissions are read from `document.commands.permissions`,
  as `SelectionPanel` does (R-17).
- **Placement:** the right panel's column becomes `SelectionPanel`,
  `LayerPanel`, `Expanded(PagePanel)`; the right panel only places it.
- **Collapsible**, with a "Layers" header that toggles it; open by default.
  The open state is per session, not stored.
- The list is scrollable with a height cap (about six rows), so the page
  panel keeps its room.
- **`LayerRow`** (`layer_row.dart`), one per layer:
  - a current-layer mark (a radio-style button; tapping makes the row
    current, disabled on a hidden layer);
  - an eye (visible/hidden; the **hide** direction is disabled on the
    effective current layer, with a tooltip saying why; showing is always
    enabled, so a file with a hidden layer 0 and no usable current layer is
    not a dead end, S-6 — in that state the tools draw on the hidden
    layer 0 until it is shown);
  - a lock;
  - a colour swatch opening a menu of the nine ACI colours (7 drawn in the
    paper's foreground, as the resolver draws it);
  - the name; a double-click opens an inline text field (layer 0 excepted).
    Enter commits a valid name; an invalid name on Enter keeps the field
    open with the reason under it; Esc, and focus loss with an invalid name,
    revert and dispatch nothing (R-17). The field is guarded like the
    symbol search (no shell shortcut fires while typing).
  - A tap on the row body selects the row (for delete) and is otherwise
    inert.
- **Below the list:** + (adds a layer per D4, selects it and opens its name
  field) and a delete button, enabled only when the selected row's layer is
  empty (D5), with a tooltip saying why when it is not.
- **Each user action is exactly one command** through
  `document.commands.execute`; a rename is one `SetLayerCommand` at commit,
  never per keystroke (`UndoStack.limit` trap).

### D10 — Row order

Layer 0 first, then the others by name under `toLowerCase()`, ties by
handle. Stable across undo, save and load, and independent of creation
order.

### D11 — Permissions, for this slice's controls only

- `LayerPanel` disables every control when
  `!permissions.allows(Capability.structure)`; it still shows the list.
- `LayerPicker` is disabled when `!permissions.allows(Capability.components)`.
- The UI does not rely on the dispatcher throwing: a disabled control
  dispatches nothing (M-12a).

### D12 — `LayerPicker` (app)

- `apps/floor_planner/lib/layers/layer_picker.dart`.
- **Placement (R-5):** `SelectionPanel` renders the picker whenever the
  selection is non-empty and no tool-settings section shows (the panel's
  own tool mode, `selection_panel.dart:190`, S-13), **including** when no type
  section shows (a line, a text, a symbol, a multi-selection); today it
  returns `SizedBox.shrink()` in those cases (`selection_panel.dart:304-310,
  776-786`).
- It shows the selection's common layer, or "Mixed".
- Choosing a layer dispatches **one** command for the whole selection, per
  key:
  - a root entity: `SetEntityLayerCommand`; **a drafted region (R-6, S-8)**
    — fill or boundary, whichever was picked — moves every record of it:
    from a fill, its boundary (`boundaryHandleOf(payload)`) and every fill
    naming that boundary; from a boundary, every fill in
    `document.fills.fillsOf(boundary)`. So a region never splits across
    layers; its layer is its boundary's;
  - **an ATTRIB key** (a root key whose owner is an instance, S-14) is
    mapped to its owning instance and moves it (duplicates collapse);
  - a root `InstanceNode`: `SetInstanceLayerCommand`;
  - a parametric object: `SetComponentCommand<ObjectLayer>`.
  A member already on the target layer is skipped; if all are, nothing is
  dispatched; one remaining member is its command alone, more are a
  `CompoundCommand`. One undo step.
- **A plain (non-parametric) `GroupNode` key (R-14)** disables the picker,
  with a tooltip; no tool makes one today, only a file.
- Moving to a hidden or locked layer is allowed; the moved things then
  leave the selection (D8).

### D13 — Changes to roadmap 12 and STATUS

At the merge: roadmap 12's status line gains 12b; its "layer for
dimensions" question closes as decision 9; STATUS records the merge.

## Architecture

### Files

Engine (`packages/jet_cad_2d`):
- `lib/src/document/layer_commands.dart` (new) — D1, `layerNameError`,
  `drawingLayer`, `objectLayer`.
- `lib/src/document/object_layer.dart` (new) — D2's component.
- `lib/src/document/{tables,command,header,drafting,component,validate}.dart`
  — `copyWith`, `header` on the target, `currentLayer`, the `layer`
  parameter, the registration, the warnings.
- `lib/src/parametric/{parametric_system,regeneration}.dart` — the stamp,
  the detach.
- `lib/src/index/{query_filter,spatial_index}.dart` — the revision check,
  the reconcile skip, the effective layer.
- `lib/src/codec/{json_codec,schema_version}.dart` — v7.

Render (`packages/jet_cad_2d_flutter`):
- `lib/src/selection.dart` — D8.
- `lib/src/outline_cache.dart` — D6's effective layer.
- `lib/src/reference_walk.dart` — D6's oracle.
- `lib/src/draw/{line_tool,text_tool,placement_tool}.dart` — D7.

App (`apps/floor_planner`):
- `lib/layers/{layer_panel,layer_row,layer_picker}.dart` (new).
- `lib/main.dart` — placement.
- `lib/selection_panel.dart` — the picker.
- `lib/parametric/*_tool.dart` (six), `lib/parametric/dimension_attach.dart`,
  `lib/symbols/symbol_placer.dart`, `lib/startup_plan.dart` — D7, D6.

### Invariants

- The frame path allocates nothing per entity; the two allocation
  invariant tests stay unedited and green. D6's revision check is an int
  compare per query; the effective layer rides a preallocated array.
- Draw order stays ascending handle; no command here reorders anything.
- A layer's state is compared with exact `==` (stored values).
- Every layer change goes through the dispatcher (so `stateId` moves and the
  document turns dirty, F2); no widget writes a `TableSection` or the header.
- Undo and redo of every command here succeed on any state a file can hold
  (D1's restore form).
- A save → open round trip of a document with layers, a current layer and
  moved objects is byte-identical.
- No pre-existing golden PNG is regenerated.

## Testing

Engine:
- Each D1 command: apply, inverse, re-apply; the record or column equals
  the expected value exactly; each user-form refusal leaves the document
  unchanged (encoded bytes equal before and after), including a rename to a
  case-folded duplicate and to an invalid name (the record is not lost).
- **Restore form (R-2):** undo succeeds after (a) picking a current layer
  while the stored one is dangling, (b) showing a loaded hidden current
  layer, (c) deleting a loaded layer whose name fails D4, (d) moving an
  entity off a missing layer.
- D2 on a wall, an opening (which cuts a wall on another layer), a room
  (its region and its TEXT) and a dimension: move, then edit a parameter
  (the regeneration must keep the layer on **matched** children, not only
  on added ones); a neighbour edit on a moved wall; undo and redo of each;
  an object with no `ObjectLayer` keeps layer 0; an `ObjectLayer` naming a
  missing layer regenerates on layer 0 and is diagnosed; an edit that
  leaves layers alone plans no layer command: the top undo entry's
  `ParametricReplay.replay` holds no `SetEntityLayerCommand`, and a
  components edit whose regeneration output is unchanged reports
  `capability == components` (S-10).
- D2's detach: delete the last wall on L; then
  `components.get<ObjectLayer>(wall)` is null and `validate()` reports no
  `component.object_layer_missing` after L is deleted; undo restores the
  component (S-1).
- D3: round trip with a non-zero current layer; a v6 file loads with
  layer 0 current; a file with `schemaVersion: kSchemaVersion + 1` is
  refused; a dangling and a hidden current layer round-trip, are diagnosed,
  and `drawingLayer` gives layer 0.
- D5: each kind of user (root entity, definition leaf, instance, live
  `ObjectLayer`) keeps a layer non-empty; a dead node's does not.
- D6: a layer hidden after the index has answered a query — through a
  command **and** through a direct table write — the next query excludes
  its entities (rendering, picking, snapping), and showing it brings them
  back; the same through undo; `rebuildCount` does not move across a hide.
  Substitution: an instance on a non-zero layer stays drawn, pickable,
  band-selectable, snappable and outlined with layer 0 hidden; a nested
  instance on layer 0 inside one on L follows L; an instance's ATTRIB on
  layer 0 follows the instance; hiding the instance's layer hides and
  unpicks it.
- `dimension_attach`: a wall on a hidden layer with its opening on a visible
  one attaches through neither query.
- Showing a loaded hidden stored current layer makes it `drawingLayer`
  again (S-5).
- The opening tool finds no host on a wall whose layer is hidden, nor on
  one whose layer is locked (S-11).
- An instance's ATTRIB on layer 0 is not drawn, picked or snapped when the
  instance's effective layer is hidden, and is with layer 0 hidden and the
  instance on a visible L (S-2).

Render:
- The canvas repaints after a `SetLayerCommand` that hides a layer, and the
  painted sink receives none of its entities (M-12e).
- The differential walk agrees with the painter with a hidden layer, a
  hidden instance layer and a non-ACI-7 layer colour (no degenerate
  fixture: the hidden layer is not layer 0 and its entities are not at the
  origin), **and** the hidden layer's handles are absent from both sinks
  (an absolute assertion, R-18).
- A tile-cached canvas redraws after a layer move and after its undo (R-8).
- `SelectionController` drops a key and the hover whose layer is hidden or
  locked, keeps one whose layer is not.
- Each drawing tool draws on a non-zero current layer.
- An export of a page with a hidden layer omits it.

App:
- `LayerPanel`: each control dispatches exactly one command (count the undo
  stack), the document becomes dirty, undo restores, and the row list
  follows undo and open with no extra event.
- The eye of the effective current layer and the current mark of a hidden
  layer are disabled; delete is disabled on a non-empty layer, layer 0 and
  the effective current layer.
- Rename: one command at Enter; Esc and focus loss with an invalid name
  dispatch none; an invalid name on Enter shows the reason; no shell
  shortcut fires while typing.
- `LayerPicker`: shown for a line-only selection; a mixed selection (a
  line, a drafted region picked on its fill, a symbol, a wall) moves in one
  undo step and the region's two records both move; "Mixed" is shown for
  mixed layers; a selection already on the target dispatches nothing.
- Read-only: no control dispatches (M-12a).
- Each parametric tool and the symbol placer create on a non-zero current
  layer.

## Named mutants

Named `M-LP-n` (R-19), so they do not collide with roadmap 12's M-12b.

- **M-LP-1:** drop D6's revision check. The hide-after-query test (the
  direct-write case) must go red.
- **M-LP-2:** drop D6's reconcile skip. The `rebuildCount` test must go red.
- **M-LP-3:** stamp the layer on added children only. The move-then-edit
  test must go red.
- **M-LP-4:** skip a matched region's boundary in the stamp; separately,
  skip its fill. Each must go red.
- **M-LP-5:** the picker moves only the picked record of a drafted region.
  Red.
- **M-LP-6:** drop the stamp's `!=` guard. The no-layer-command test must go
  red.
- **M-LP-7:** inverses use the user form. The restore-form tests must go
  red.
- **M-LP-8:** `SetLayerCommand` skips D4. The rename-to-duplicate test must
  go red (the record survives).
- **M-LP-9:** the user form allows hiding the effective current layer. Red.
- **M-LP-10:** `RemoveLayerCommand` ignores `ObjectLayer`; separately,
  ignores definition leaves; separately, counts a dead node's
  `ObjectLayer`. Each red.
- **M-LP-11:** the cleanup does not detach `ObjectLayer`. The
  delete-last-wall test must go red.
- **M-LP-12:** `_loadHeader` does not copy `currentLayer`. The round trip
  must go red.
- **M-LP-13:** `kSchemaVersion` stays 6. The version test must go red.
- **M-LP-14:** drop the substitution in picking; in snapping; in the band;
  in the outline walk; make it one level instead of recursive. Each red.
- **M-LP-15:** `SelectionController` does not prune. Red.
- **M-LP-16:** a drawing tool keeps layer 0 (one per family: drafting,
  symbol, parametric). Red.
- **M-LP-17:** `LayerPicker` dispatches one command per key. The one-step
  test must go red.
- **M-LP-18:** rename dispatches per keystroke. Red.
- **M-LP-19:** the layer-move commands report `capability: components`. The
  tile-cache test must go red.
- **M-LP-20:** `dimension_attach` ignores the host's `ObjectLayer`. Red.
- **M-LP-21:** `drawingLayer` returns the stored layer unchecked. The
  dangling-current tests must go red.
- **M-12a (roadmap):** `LayerPanel` ignores permissions while the
  dispatcher still enforces them. The read-only test must go red without
  any `PermissionDeniedError` being caught.
- **M-12e (roadmap):** a layer toggle that writes the table without
  notifying (bypass `TableSection`'s `onMutated`). The canvas test must go
  red.
- **M-LP-22:** the oracle ignores layer visibility. The absolute assertion
  must go red.
- **M-LP-23:** no ATTRIB substitution in `acceptsEntity`. The ATTRIB test
  must go red.
- **M-LP-24:** no substitution for nested instances in `acceptsNode`. The
  nested-instance test must go red.
- **M-LP-25:** the opening tool ignores its host's layer. Red.
- **M-LP-26:** the eye disables showing on the effective current layer too.
  The hidden-layer-0 file test must go red.

## Exit gate

- Engine, render and app suites green; `dart analyze` / `flutter analyze`
  clean; `dart format` clean; web build passes; `dev_harness_2d` analyze
  clean.
- The two allocation invariant tests unedited and green.
- No golden PNG regenerated.
- Every named mutant fired red by the implementer and re-fired by the
  reviewer.

### The look (the human's, macOS and web)

Listed in the results note; the human does it and reports. Never marked
done on their behalf. At least: the Layers section's layout at 280 px with
long names; the eye, lock, current mark and colour menu; inline rename;
+ and delete with their tooltips; hiding a layer with walls, a symbol and a
dimension on it; the picker on a line, on a mixed selection and its
"Mixed"; undo of each; the dirty mark; export with a hidden layer.

## Risks

- **The stamp touches regeneration**, the most delicate code here. The
  amendment is one column, exact `==`, guarded; the existing regeneration
  suite stays green, edited only to pass `layer:` (D7's blast radius).
- **Schema 7** makes files written by this build unreadable by older
  builds; that is the purpose of the bump. Pinned tests move with it
  (R-12): `json_codec_test.dart:513, 579` and
  `instance_style_codec_test.dart:80` pin 6 (and
  `json_codec_test.dart:580`); `json_codec_test.dart:519` decodes
  `schemaVersion: 7` as the refused future version and moves to
  `kSchemaVersion + 1` (S-9);
  `instance_style_codec_test.dart:191` uses 7 as the refused future version
  and moves to `kSchemaVersion + 1`; `generate_document_test.dart:59-62,
  243-246` fingerprints are re-baselined with a comment naming the header
  key and the version, as earlier plans did.
- **The right panel's height**: Selection, Layers and Page share the
  window's height; the Layers list's cap keeps Page usable.
- **The effective layer on the hover path** must not allocate; the
  allocation invariant tests and a probe in the plan guard it.

## Revision 2

Revision 1 (`630a311`), reviewed independently: "Not ready". Applied:

- **R-1 (blocking)** — D6: the reconcile skip; the check in `_beginQuery`;
  `rebuildCount` test; M-LP-1 covers a direct write; M-LP-2. F3 amended.
- **R-2 (blocking)** — D1's restore form; four tests; M-LP-7.
- **R-3** — D1: D4 checked before the remove, self excluded; untrimmed
  refused; M-LP-8.
- **R-4** — D2's detach; D5 counts live nodes only; M-LP-10, M-LP-11.
- **R-5** — D12's placement in `SelectionPanel`.
- **R-6** — D12 moves a drafted region's two records; D8 uses the
  boundary's; M-LP-4 (both halves), M-LP-5.
- **R-7** — D6's `dimension_attach` rule; M-LP-20.
- **R-8** — D1's capability split; tile-cache test; M-LP-19.
- **R-9** — D2's `objectLayer` never refuses; D3's warning.
- **R-10** — D3's `drawingLayer` as the one effective current layer;
  M-LP-21.
- **R-11** — D6's recursive substitution in band, snap, outline and ATTRIB,
  on a preallocated array; M-LP-14.
- **R-12** — Risks lists the pinned tests.
- **R-13** — D7's blast radius; `startup_plan` passes layer 0; Risks
  reworded.
- **R-14** — D12's plain group, skipped no-ops; D8 prunes the hover.
- **R-15** — D2's guard; M-LP-6.
- **R-16** — D3's codes and the `warning()` helper.
- **R-17** — D9's focus loss, per-row emptiness, dispose, permissions read
  from the document.
- **R-18** — the absolute assertion; M-LP-22.
- **R-19** — `M-LP-n`; `Handle` parameters; D2's wording; D4's UTF-16 and
  `toLowerCase()`.
- F10's reference corrected.

## Revision 3

Revision 2 (`c945986`), spot-checked independently: "Ready with
amendments". Applied:

- **S-1 (major)** — the detach test reads the component and the warning;
  D3's warning covers dead handles.
- **S-2 (major)** — the ATTRIB rule in `acceptsEntity`, memoised per owner;
  the oracle mirrors it; ATTRIB style recorded as a residual; M-LP-23.
- **S-3** — `touched` never empty; `{old, new}` for the current layer.
- **S-4** — a removed or dangling handle still rebuilds once; M-LP-2's
  scope.
- **S-5** — showing a stored hidden current layer makes it current again;
  a test.
- **S-6** — only the hide direction of the eye is disabled; M-LP-26.
- **S-7** — nested instances through `acceptsNode`; M-LP-24.
- **S-8** — both region directions; every fill of the boundary.
- **S-9** — `json_codec_test.dart:519, 580` listed.
- **S-10** — M-LP-6's observation named.
- **S-11** — the opening tool's host must be visible and unlocked (a ruling
  made in writing, for the human's approval with the spec); M-LP-25.
- **S-12** — the helpers take a `CommandTarget`.
- **S-13** — "no tool-settings section shows".
- **S-14** — an ATTRIB key moves its instance.
- **S-15** — `tables.changes`'s reason; `didUpdateWidget`.
- **S-16** — `ObjectLayer` is not `internal`.

## Amended at execution (Plan 12b)

Where execution made this spec precise or departed from it, each with the
ruling or review that decided it (the plan's ledger,
`ledgers/2026-10-01-plan-12b/progress.md`, archived by a later commit;
results: [2026-10-01-plan-12b-results.md](../notes/2026-10-01-plan-12b-results.md)).
This section rewrites nothing above it.

- **Risks, P-7: the fingerprints were not re-baselined (R-12b-1, Task 1).**
  `generate_document_test.dart`'s two fingerprint tests are the engine's two
  standing Linux failures; their constants are macOS values (Ruling 07-7),
  which a Linux container cannot compute. The constants stay, with a
  comment; the re-baseline is owed on macOS (the results note's look list
  has the step). Until then both tests fail on macOS too.
- **D3, schema 7: the committed furniture library moves with it (R-12b-2,
  Task 1).** `apps/floor_planner/assets/library/furniture.jetlib` is codec
  output pinned byte for byte; it was regenerated (schema 7 and the
  header's `currentLayer`, nothing else).
- **D1, decision 7: refuse only a *hide* of the effective current layer
  (R-12b-4, Task 2).** The user form refuses `SetLayerCommand` when it
  turns `visible` from true to false on `drawingLayer`; a recolour or lock
  of an already-hidden effective current layer 0 (S-6's file state) is
  allowed, as D9's enabled lock and swatch require.
- **D1: integrity failures are `StateError` in both forms (Task 2).** A
  missing entity or node throws `StateError`, as every command in
  `commands.dart` does; `ArgumentError` is kept for the user rules (a
  missing *target layer* included). `AddLayerCommand`'s user form also
  refuses a handle naming a node, definition or entity.
- **D6, P-4: the ATTRIB rule lives in the shared leaf path (Task 3).**
  `FilterEvaluator.acceptsEntityOnLayer(slot, filter, context)` applies
  "own layer if non-zero, else the owning instance's if non-zero, else the
  context"; `acceptsEntity` is it in the root context. So an ATTRIB of a
  nested instance follows its owner too.
- **D6: the reconcile skip names a handle that is purely a layer (Task 3
  review finding 1, `540f9cf`).** It skips a touched handle only when it
  names a layer record and no entity (live or last known), node or
  definition; a malformed file where a layer shares an entity's handle
  otherwise left the index stale.
- **D6, Invariants: the allocation probe uses budgets (R-12b-5).** It
  asserts `query_allocation_test.dart`'s per-call budgets, not literal zero
  (`_descend` already allocates per level; `_Uint32List` cannot be
  watched).
- **D6: the oracle filters only at the root (R-12b-7, Task 6 review,
  `a4d85f0`).** `reference_walk` skips a hidden root leaf, a root ATTRIB by
  its instance's effective layer and a hidden root instance, and nothing
  below the root, exactly as the painter draws; a test pins painter ==
  oracle in the residual state. The outline and picking do filter below
  the root (the outline's root instance key is gated by its own layer).
- **D8: a plain group counts by `objectLayer` (R-12b-8, Task 6).** The
  render package cannot tell a parametric group from a plain one, so every
  group key reads `objectLayer` (absent: layer 0). A layer-0 ATTRIB key uses
  its instance's layer (S-2); a fill key uses its boundary's.
- **D2, D7: the creation compound's `ObjectLayer` is its last child
  (Task 8).** One `ParametricEdit`, one regeneration.
- **D6, S-11: the overlap rule for the opening tool's host (R-12b-9,
  Task 8).** A wall that may not host (its `objectLayer` hidden or locked)
  is passed over in the band scan, so the next band in handle order hosts;
  the rule lives in `WallBands.hostAt(…, accept:)`. The Wall tool's band
  join stays unfiltered (decision 8) — an open question for the human's
  look. The tool's scan memo also keys on `tables.mutationRevision`.
- **D9: `LayerPanel(document, {foreground})` (Task 9).** ACI 7's swatch is
  drawn in the paper's foreground, which the panel cannot see; `main`
  passes the resolver's.
- **D9: a blur with a valid name commits it** (one `SetLayerCommand`), as
  the panel's number fields commit on blur; the spec ruled only the
  invalid case (Task 9).
- **D9: the current mark is disabled on the layer that is already both
  stored and effective current** (a tap would be a no-op undo step); with a
  dangling or hidden stored current layer, layer 0's mark stays enabled
  (Task 9).
- **D9: each row control reads the live record at dispatch (Task 9 review
  finding 1, `8eef675`),** so a rename committed on blur by the same
  pointer sequence is not reverted by a stale copy.
- **D11: the disabled delete's tooltip reads "Layers cannot be changed in
  this document"** (Task 10 review info 6, `c3ab7ca`), not "Read-only":
  under `runtime` the picker still moves things.
- **D12: the picker shows by key and moves by record (Task 10).** The label
  is per key (an ATTRIB its instance's layer, a fill its boundary's, an
  object its `objectLayer`); the no-op skip is per record on the stored
  value with exact `==` (an absent `ObjectLayer` is layer 0; a dangling one
  is not, so moving it to layer 0 rewrites it). A file-split region shows
  its boundary's layer, and choosing that layer repairs it.
- **D12: `isParametricObject` is the app's list of its six types** (the
  engine has no "any registered type" query, and the engine was frozen);
  the catalog and the predicate name each other (`c3ab7ca`).
- **D12: a refused move is caught (Task 10 review info 5, `c3ab7ca`):**
  `_choose` catches `ArgumentError` and `StateError` like the Selection
  section's other commits; the dispatcher has rolled it back.
- **Named mutants, M-12e: built in the product (Task 7).** The layers
  `TableSection` constructed without `onMutated` (`tables.dart:562`), not
  a test-side copy of the edit. The `add`-only bypass is equivalent for the
  canvas test (remove-then-add still bumps once) and is killed by the
  engine's `tables_revision_test.dart`.
- **Testing, the end-to-end order (Task 11a).** "Make it current, draw,
  hide it" cannot be done literally: the current layer cannot be hidden
  (decision 7). The test makes layer 0 current before the hide and asserts
  the disabled eye as a premise.
- **Known limitations recorded at execution** (none changes a decision):
  R-12b-3 (a dangling stored current layer does not raise the handle seed);
  an ATTRIB on its own non-zero layer (picker vs prune); `ObjectLayer` on a
  nested group inert and left behind; the index ignores a definition's base
  point (pre-existing). See the results note.
