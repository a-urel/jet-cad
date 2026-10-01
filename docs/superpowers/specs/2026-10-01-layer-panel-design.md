# Layer panel (12b) — design

**Date:** 2026-10-01. **Status:** design, **revision 1**, for independent
review.
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
`EntityFlags.invisible` (`:135`); it reads layers for style only (`:73-74`).

**F11 — The right panel.** `main.dart:946-975`: a 280-wide column of
`SelectionPanel` then `Expanded(PagePanel)`, inside `ShellShortcutGuard`.
`SelectionPanel` (`selection_panel.dart:775-899`) is not scrollable and
listens to `document.commands.changes`; it reads
`document.commands.permissions` itself (`:247-252`).

## Decisions

### D1 — Layer commands (engine)

New commands in `packages/jet_cad_2d/lib/src/document/layer_commands.dart`,
exported from the package:

| Command | Effect | Inverse | Capability |
|---|---|---|---|
| `AddLayerCommand(record)` | `tables.layers.add` | `RemoveLayerCommand` | `structure` |
| `RemoveLayerCommand(handle)` | removes an **empty** layer (D5) | `AddLayerCommand(old)` | `structure` |
| `SetLayerCommand(record)` | replaces the record with the same handle (remove, add) | `SetLayerCommand(old)` | `structure` |
| `SetCurrentLayerCommand(handle)` | `header.currentLayer = handle` | `SetCurrentLayerCommand(old)` | `structure` |
| `SetEntityLayerCommand(slotHandle, layer)` | `entities.replace(record.copyWith(layer:))` | the old layer | `components` |
| `SetInstanceLayerCommand(node, layer)` | replaces the `InstanceNode` with `copyWith(layer:)` | the old layer | `components` |

- `LayerRecord` gains `copyWith`.
- `CommandTarget` gains `DocumentHeader get header`; `DraftDocument`
  already has it.
- Every command's `touched` names the layer handle (the table commands) or
  the edited handle (the entity and instance commands).
- **Validation, before any mutation** (the `apply` contract: complete or
  untouched), throwing `ArgumentError` with the reason:
  - `SetLayerCommand` on layer 0 with a different `name`; with
    `visible: false` on the current layer (decision 7); on a missing handle.
  - `AddLayerCommand` with an invalid or duplicate name (D4).
  - `SetCurrentLayerCommand` on a missing or hidden layer (decision 7).
  - `SetEntityLayerCommand` / `SetInstanceLayerCommand` on a missing layer.
- **Why `structure`** for the table commands: the `runtime` preset (a
  point-of-sale user who may move and edit properties) must not reorganise
  the drawing's layers, and `readOnly` must refuse all of them. **Why
  `components`** for moving one thing: it is a property edit, which
  `runtime` allows, and `SetComponentCommand<ObjectLayer>` (D2) is
  `components` too, so moving a mixed selection needs one capability.
  F4 makes `components` safe for the index: a moved entity's layer is read
  live.

### D2 — `ObjectLayer` and the regeneration's stamp (engine)

- A new engine component `ObjectLayer(Handle layer)`, `typeId`
  `jet_cad.object_layer`, registered by `ComponentRegistry.registerBuiltIns`
  (so every document, the app's and a test's, decodes it).
- **Read by the parametric system only**, for a live object's group. Absent
  means layer 0, which is every object in every file written before this
  slice.
- **Added children:** `_recordOf` takes the object's layer; every added
  record, a region's fill and boundary both, is on it.
- **Matched children:** a new step in `_plan`, after the payload rewrite —
  a matched child whose stored layer differs (exact `==`) from the object's
  gets a `SetEntityLayerCommand` in the plan (both records of a matched
  region). This **amends 06 D11 / 10 D13 for one column**: the layer is now
  rewritten on a match; every other attribute is still written on add only.
  The amendment is recorded in the `Generated` class comment.
- Plan commands are not the edit's `touched`, so `_refused` does not reject
  them (F7).
- **Moving an object** is `SetComponentCommand<ObjectLayer>(group, …)`,
  which seeds its regeneration (F7): one `ParametricEdit`, one undo step,
  undone by `ParametricReplay` without regenerating.
- **A new object** gets `ObjectLayer(current)` in the creation compound of
  every parametric tool (F6's six), whatever the current layer is,
  layer 0 included. A file written by this build therefore always carries
  it for a new object.

### D3 — The current layer (engine, codec)

- `DocumentHeader.currentLayer`, a `Handle`, default
  `ReservedHandles.layerZero`.
- `toJson` writes it after `globalLinetypeScale`; `fromJson` reads it as
  optional, defaulting to layer 0; `_loadHeader` copies it (F8).
- **`kSchemaVersion` becomes 7**, with the paragraph the file's pattern
  asks for: v6→v7 adds `header.currentLayer` (absent ⇒ layer 0) and the
  `jet_cad.object_layer` component; the bump exists so a v6 build refuses a
  v7 file instead of dropping the current layer and every object's layer.
- **A stored `currentLayer` naming no layer, or a hidden one** loads as
  stored (stored values round-trip exactly); `validate.dart` reports it as a
  warning diagnostic; the tools treat it as layer 0 (D7), and the panel
  marks layer 0 as current until the user picks one.
- `DraftDocument.empty` and `DocumentTables.standard()` are unchanged:
  a new document has layer 0 only (decision 9).

### D4 — Names

- A name is valid when, trimmed, it is non-empty, at most 255 characters,
  contains none of the DXF-forbidden characters `<`, `>`, `/`, `\`, `"`, `:`, `;`, `?`, `*`, `|`, `=` and the backtick, and is not a case-folded
  duplicate of another layer's (`TableSection` already refuses the
  duplicate; the command checks first so it can say why).
- The name is stored trimmed.
- A new layer from the panel's + is named `Layer N`, the smallest `N ≥ 1`
  not taken (case-folded), colour ACI 7, and layer 0's linetype, lineweight
  and transparency; visible and unlocked. Its handle is the next from the
  document's `handleSeed`.

### D5 — Empty

A layer is **empty** when no entity record, no `InstanceNode` and no
`ObjectLayer` component names it, and it is not the current layer and not
layer 0. `RemoveLayerCommand` checks this with one pass over the entity
store, the tree and the `ObjectLayer` components (O(n), on a delete only).
A definition's leaves count: a block that draws on a layer keeps it alive.

### D6 — Visibility and lock reach the frame (engine, render)

- **`SpatialIndex` drops its filter cache when the tables change.** It
  keeps the `mutationRevision` it last saw; every query compares it with
  `document.tables.mutationRevision` (one int compare per query, not per
  entity) and calls `_filters.invalidate()` when it moved. This covers the
  commands, their undo and redo, and a direct table write alike, and does
  not rebuild the index (no geometry moved).
- The repaint already happens: `DraftCanvas` merges `tables.changes` into
  its repaint (F2). It is asserted, not assumed (M-12e).
- **Layer-0 substitution for visibility and lock inside an instance.**
  A leaf inside a definition is tested against its *effective* layer: its
  own, or the instance's when its own is layer 0 — the resolver's rule
  (F5). Applied where picking and snapping test instance leaves
  (`spatial_index.dart:571, 865, 881`). The painter's definition walk stays
  unfiltered: the instance's own layer (already tested by `acceptsNode`)
  decides whether a symbol draws, and with substitution a symbol's layer-0
  leaves can never be hidden independently of it. **Residual, recorded:** a
  definition leaf on a non-zero hidden layer still draws; the library
  refuses such a symbol, so only a hand-written file reaches it.
- **The oracle learns layers.** `reference_walk` skips a root-level leaf
  whose layer is hidden and an instance whose layer is hidden, with the
  same substitution, so the differential test covers hiding (F10).
- **Export and print** use their own `SpatialIndex` (13) and therefore the
  same filter: a hidden layer does not plot. Asserted by a test, no code
  change expected.

### D7 — Tools draw on the current layer

- `draftRecord`, `addDrafted` and `addDraftedRegion` gain a required
  `layer` parameter (no default, so no caller silently keeps layer 0).
- The drawing tools pass `document.header.currentLayer`, through one helper
  `drawingLayer(document)` that returns layer 0 when the stored current
  layer names no layer or a hidden one (D3).
- The symbol placer writes `drawingLayer` on the `InstanceNode`; the
  definition's leaves stay on layer 0 (the library's rule) and follow the
  instance by substitution.
- Parametric tools: D2's `ObjectLayer(drawingLayer(document))`.
- The sample document (`startup_plan.dart`) stays on layer 0, unchanged.

### D8 — Selection follows hiding and locking (render)

`SelectionController`, on every `DocChange`, also drops a key that picking
could no longer select: a key whose effective layer — the entity's (with
substitution through its instance chain), an instance's, or a parametric
object's `ObjectLayer` — is hidden or locked. O(selection) per change, no
per-entity work. A selection made before the change and a layer turned off
leave no outline and no grip behind (the outline cache re-walks on the same
change).

### D9 — `LayerPanel` (app)

- `apps/floor_planner/lib/layers/layer_panel.dart`: `LayerPanel(document,
  permissions)`, a stateful widget that keeps **no copy of the layers**: it
  rebuilds from `document.tables.layers` and `document.header.currentLayer`
  on `tables.changes` and on `document.commands.changes`. So undo, redo and
  open reach it with no extra wiring.
- **Placement:** the right panel's column becomes `SelectionPanel`,
  `LayerPanel`, `Expanded(PagePanel)`; the right panel only places it.
- **Collapsible**, with a "Layers" header that toggles it; open by default.
  The open state is per session, not stored.
- The list is scrollable with a height cap (about six rows), so the page
  panel keeps its room.
- **`LayerRow`** (`layer_row.dart`), one per layer:
  - a current-layer mark (a radio-style button; tapping makes the row
    current, disabled on a hidden layer);
  - an eye (visible/hidden; disabled on the current layer, with a tooltip
    saying why);
  - a lock;
  - a colour swatch opening a menu of the nine ACI colours (7 drawn in the
    paper's foreground, as the resolver draws it);
  - the name; a double-click opens an inline text field (layer 0 excepted).
    Enter or focus loss commits, Esc cancels; an invalid name keeps the
    field open with the reason under it. The field is guarded like the
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

Layer 0 first, then the others by case-folded name, ties by handle. Stable
across undo, save and load, and independent of creation order.

### D11 — Permissions, for this slice's controls only

- `LayerPanel` disables every control when
  `!permissions.allows(Capability.structure)`; it still shows the list.
- `LayerPicker` is disabled when `!permissions.allows(Capability.components)`.
- The UI does not rely on the dispatcher throwing: a disabled control
  dispatches nothing (M-12a).

### D12 — `LayerPicker` (app)

- `apps/floor_planner/lib/layers/layer_picker.dart`, shown in the Selection
  section when the selection is non-empty.
- It shows the selection's common layer, or "Mixed".
- Choosing a layer dispatches **one** command for the whole selection: a
  `CompoundCommand` of, per key, `SetEntityLayerCommand` (a drafted entity),
  `SetInstanceLayerCommand` (a symbol) or `SetComponentCommand<ObjectLayer>`
  (a parametric object); a single key is that command alone. One undo step
  (M-12c's spirit).
- Moving to a hidden or locked layer is allowed; the moved things then
  leave the selection (D8).
- A key the picker cannot move (a leaf inside an instance, a generated
  child selected on its own if the selection allows it) disables the
  picker, with a tooltip.

### D13 — Changes to roadmap 12 and STATUS

At the merge: roadmap 12's status line gains 12b; its "layer for
dimensions" question closes as decision 9; STATUS records the merge.

## Architecture

### Files

Engine (`packages/jet_cad_2d`):
- `lib/src/document/layer_commands.dart` (new) — D1.
- `lib/src/document/object_layer.dart` (new) — D2's component.
- `lib/src/document/{tables,command,header,drafting,component}.dart` —
  `copyWith`, `header` on the target, `currentLayer`, the `layer`
  parameter, the registration.
- `lib/src/parametric/{parametric_system,regeneration}.dart` — the stamp.
- `lib/src/index/{query_filter,spatial_index}.dart` — the revision check,
  the substitution.
- `lib/src/codec/{json_codec,schema_version}.dart` — v7.
- `lib/src/validate.dart` (or where diagnostics live) — D3's warning.

Render (`packages/jet_cad_2d_flutter`):
- `lib/src/selection.dart` — D8.
- `lib/src/reference_walk.dart` — D6's oracle.
- `lib/src/draw/{line_tool,text_tool,placement_tool}.dart` — D7.

App (`apps/floor_planner`):
- `lib/layers/{layer_panel,layer_row,layer_picker,layer_names}.dart` (new).
- `lib/main.dart` — placement.
- `lib/selection_panel.dart` — the picker.
- `lib/parametric/*_tool.dart` (six) and `lib/symbols/symbol_placer.dart` —
  D7.

### Invariants

- The frame path allocates nothing per entity; the two allocation
  invariant tests stay unedited and green. D6's revision check is an int
  compare per query.
- Draw order stays ascending handle; no command here reorders anything.
- A layer's state is compared with exact `==` (stored values).
- Every layer change goes through the dispatcher (so `stateId` moves and the
  document turns dirty, F2); no widget writes a `TableSection` or the header.
- A save → open round trip of a document with layers, a current layer and
  moved objects is byte-identical.
- No pre-existing golden PNG is regenerated.

## Testing

Engine:
- Each D1 command: apply, inverse, re-apply; the record or column equals
  the expected value exactly; each refusal leaves the document unchanged
  (encoded bytes equal before and after).
- D2 on a wall, an opening (which cuts a wall on another layer), a room
  and a dimension: move, then edit a parameter (the regeneration must keep
  the layer on **matched** children, not only on added ones); a neighbour
  edit on a moved wall; undo and redo of each; an object with no
  `ObjectLayer` keeps layer 0.
- D3: round trip with a non-zero current layer; a v6 file loads with
  layer 0 current; a v7 file is refused by a reader built at v6 (the
  version check); a dangling current layer round-trips and is diagnosed.
- D5: each kind of user (entity, instance, `ObjectLayer`, a definition
  leaf) keeps a layer non-empty.
- D6: a layer hidden after the index has answered a query — the next query
  excludes its entities (rendering, picking, snapping), and showing it
  brings them back; the same through undo. Substitution: an instance on a
  non-zero layer stays drawn and pickable with layer 0 hidden; hiding the
  instance's layer hides and unpicks it.

Render:
- The canvas repaints after a `SetLayerCommand` that hides a layer, and the
  painted sink receives none of its entities (M-12e).
- The differential walk agrees with the painter with a hidden layer, a
  hidden instance layer and a non-ACI-7 layer colour (no degenerate
  fixture: the hidden layer is not layer 0 and its entities are not at the
  origin).
- `SelectionController` drops a key whose layer is hidden or locked, keeps
  one whose layer is not.
- Each drawing tool draws on a non-zero current layer.
- An export of a page with a hidden layer omits it.

App:
- `LayerPanel`: each control dispatches exactly one command (count the undo
  stack), the document becomes dirty, undo restores, and the row list
  follows undo and open with no extra event.
- The eye of the current layer and the current mark of a hidden layer are
  disabled; delete is disabled on a non-empty layer, layer 0 and the
  current layer.
- Rename: one command at commit; Esc dispatches none; an invalid name
  dispatches none and shows the reason; no shell shortcut fires while
  typing.
- `LayerPicker`: a mixed selection (a line, a symbol, a wall) moves in one
  undo step; "Mixed" is shown for mixed layers.
- Read-only: no control dispatches (M-12a).
- Each parametric tool and the symbol placer create on a non-zero current
  layer.

## Named mutants

- **M-12b-1:** drop D6's revision check. The hide-after-query test must go
  red.
- **M-12b-2:** stamp the layer on added children only. The
  move-then-edit test must go red.
- **M-12b-3:** skip the region's boundary in the stamp. A wall's or room's
  boundary must go red.
- **M-12b-4:** `SetLayerCommand` allows hiding the current layer. Red.
- **M-12b-5:** `RemoveLayerCommand` ignores `ObjectLayer` (and, separately,
  definition leaves) in D5. Red.
- **M-12b-6:** `_loadHeader` does not copy `currentLayer`. The round trip
  must go red.
- **M-12b-7:** `kSchemaVersion` stays 6. The version test must go red.
- **M-12b-8:** drop the layer-0 substitution in picking. The symbol-pick
  test must go red.
- **M-12b-9:** `SelectionController` does not prune. Red.
- **M-12b-10:** a drawing tool keeps layer 0 (one per tool family:
  drafting, symbol, parametric). Red.
- **M-12b-11:** `LayerPicker` dispatches one command per key. The one-step
  test must go red.
- **M-12b-12:** rename dispatches per keystroke. Red.
- **M-12a (roadmap):** `LayerPanel` ignores permissions while the
  dispatcher still enforces them. The read-only test must go red without
  any `PermissionDeniedError` being caught.
- **M-12e (roadmap):** a layer toggle that writes the table without
  notifying (bypass `TableSection`'s `onMutated`). The canvas test must go
  red.
- **M-12b-13:** the oracle ignores layer visibility. The differential test
  must go red against a painter that also ignores it (fired as a pair).

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
dimension on it; the picker's "Mixed"; undo of each; the dirty mark; export
with a hidden layer.

## Risks

- **The stamp touches regeneration**, the most delicate code here. The
  amendment is one column, exact `==`, and the existing regeneration suite
  must stay green unedited.
- **The index's instance entries** must not cache an instance's layer
  (F4 says `acceptsNode` reads it live); the plan verifies this before
  relying on `components` for `SetInstanceLayerCommand`.
- **Schema 7** makes files written by this build unreadable by older
  builds; that is the purpose of the bump.
- **The right panel's height**: Selection, Layers and Page share 280 px of
  width and the window's height; the Layers list's cap keeps Page usable.
