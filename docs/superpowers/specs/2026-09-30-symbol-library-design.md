# The symbol library (09) — design

**Date:** 2026-09-30. **Status:** design, **revision 3**. Revision 1 (`fbf1e9a`) was reviewed
independently: "Ready with amendments", 0 blocking, 7 major, 3 minor and
1 nit (V-1 to V-11), each applied below; see [Revision 2](#revision-2). Its re-review: "Ready with one amendment" (R-1 to R-3), applied in [Revision 3](#revision-3).
Awaiting the human's approval.
**Sub-project:** `roadmap/09-symbol-library.md`. **Size:** L, sliced in two
(decision 7): **09a** the core (engine commands, the library, the placer),
**09b** the palette (gallery, thumbnails, search, the placement tool).
**Branch:** `spec-09/symbol-library`, cut from `main` at `5022e32`.
**Depends on:** 02, 05, 06, 08, 12a (merged). **Blocks:** nothing.
**Brainstormed with the human on 2026-09-30**, on `main`, after a survey of
the tree (the facts below are from `main` at `5022e32`, several of them
contradicting the roadmap file, which predates most of the app).

**Inputs read:** `CLAUDE.md`; `STATUS.md`; `roadmap/00-README.md`,
`roadmap/09-symbol-library.md`; specs 12a (form), and by reference 06, 08,
10, 11; `packages/jet_cad_2d/lib/src/document/{node,tree,commands,
component,validate,draft_document,undo}.dart`, `index/spatial_index.dart`,
`geometry/transform2.dart`; `packages/jet_cad_2d_flutter/lib/src/
{tool,draft_painter,select_tool}.dart`; `apps/floor_planner/lib/
{tool_palette,new_document,document_files,main}.dart`.

## Decisions the human made on 2026-09-30

1. **Content is generated in code**, a small set (about 24 symbols), by a
   deterministic Dart generator; no imported content, so no licence to
   check. Import is a later slice.
2. **One category per symbol, plus tags.** Search covers name, tags and
   category name.
3. **Undo through definition commands and a `CompoundCommand`**: the engine
   gains `AddDefinitionCommand` and `RemoveDefinitionCommand`; one placement
   is one undo step.
4. **A symbol's content uses only reserved handles** (layer 0, BYBLOCK /
   BYLAYER, STANDARD text style). Placing adds no table record.
5. **The library ships as a bundled asset, `.jetlib`** (the codec's bytes).
   Opening a user's own library is a later slice.
6. **Static symbols** in v1: no `attrib` labels, no parametric variants, no
   xref. A symbol is copied into the document.
7. **Two slices, 09a then 09b** (this spec designs both; the plan is
   written for 09a first).
8. **Key + version identity.** A definition's `SymbolComponent` carries a
   key and an integer version; the same key and version is reused, a
   different version is copied beside it.
9. **Placement is select-then-click**, one path for mouse, touch and web
   (press, drag, release places at the release point). No drag-and-drop from
   the palette in v1.
10. **Placed symbols are free-standing**: snap on placement, no hosting, no
    wall or room membership. Doors and windows stay 08's parametric
    openings and their tool.
11. **Thumbnails** render through `DraftPainter`, lazily, cached in memory by
    key.
12. **The gallery is a new widget in `jet_cad_2d_flutter`** (the human's
    suggestion, after the brainstorm): generic over its entries, beside
    `DraftCanvas` and `DraftPainter`; the app wires it (D1).

## What this delivers

- 09a: a library file (`assets/library/furniture.jetlib`) generated from
  Dart and loaded into a typed `SymbolLibrary`; `placeSymbol(...)` returns
  one command that copies the definition on first use and adds an instance
  at a chosen point, rotation and mirror; the engine commands that make that
  undoable and dirty-marking. Headless, fully tested.
- 09b: the left panel gains the gallery (search box, collapsible categories,
  thumbnails) under the tools, and a placement tool: pick a symbol, a ghost
  follows the pointer, release places, `R` rotates, `M` mirrors, `Esc`
  leaves.

## Non-goals

- Importing DXF / SVG or any third-party content; the user's own libraries
  (opening a `.jetlib`, saving a selection as a symbol).
- `attrib` labels, text or fills inside symbols; parametric symbols; xref
  (`isXref` stays preserved and unused).
- Drag-and-drop from the palette; hosting on walls; door and window entries
  in the gallery.
- A layer choice at placement (the instance goes on layer 0; the layer panel
  is a later 12 slice).
- Replacing a placed instance's definition with a newer library version
  ("update symbols"); nested instances inside definitions.

## Facts established (verified on `main`; the brief's and roadmap's claims
checked)

- **F-1.** No command adds or removes a definition. `DocumentTree.
  addDefinition` / `removeDefinition` are direct and unguarded (`tree.dart:222,
  234`); the spatial index does not see them without an explicit rebuild
  (`spatial_index.dart:130`). Confirmed.
- **F-2.** `Definition.basePoint` is read nowhere outside `node.dart`, the
  codec and one generator (`Vector2.zero()`). The painter passes only
  `node.transform` (`draft_painter.dart:397`). **Insertion alignment is the
  placer's job** (D6); the roadmap's M-09a lives there. New.
- **F-3.** Handles are one document-wide space: a definition's leaves are
  ordinary entities with `owner` = the definition's handle (valid,
  `validate.dart:72`), found by owner, never through `children`. Copying a
  definition across documents means fresh handles for every leaf and the
  definition. `AddEntityCommand` does not check the owner and its duplicate
  check does not look at definitions; the new command does (D4). New.
- **F-4.** Table edits are not commands (`tables.dart`; 12a D3). D4 of the
  brainstorm (reserved handles only) avoids them. New.
- **F-5.** A `Component` attaches to any handle, a definition's included; no
  existence check (`component.dart`, `SetComponentCommand`). The codec
  saves all component stores by handle and preserves unknown types. `purge`
  does not clean components (plan task: verified, recorded). Confirmed.
- **F-6.** `Transform2` is a full 2×3 affine and supports mirrored
  instances: pick, snap and outlines flip arc sweeps when det < 0; text in
  a mirrored instance draws mirrored (v1 behaviour, so symbols carry no
  text). Helpers: `translation`, `rotation`, `scale` (negative allowed),
  `multiply` (the argument applies first).
- **F-7.** Tests exist for an instance at a non-identity transform through
  the index and through the painter, and for colour overrides, but **none
  combines transform, style override, painter and query**, and painter
  overrides are tested only under translation (`draft_painter_recursion_test`
  :185). The product app has never placed an instance. 09a's end-to-end test
  (D10) is the first to do it.
- **F-8.** The handle seed is not rolled back by undo; redo reuses the
  command's handles (`undo.dart:182`). A placement allocates its handles
  once, at construction.
- **F-9.** World units are millimetres (`header.units`, page 1:50); symbols
  are authored in mm.
- **F-10.** `Tool.isMidShape` and `_settlePendingInput()` exist (12a); a
  pressed placement counts as mid-shape (D11).
- **F-12.** `SnapKind.insertion` is emitted only for text and attrib
  (`spatial_index.dart:1955-1960`); an instance's insertion point is not a
  snap candidate, and symbols carry no text. New (V-1).
- **F-13.** The index learns of a change through `onAfterMutate` and the
  command's `touched` (`_onChange` → `_reconcile`, `spatial_index.dart:
  2648-2740`): a touched handle that resolves to a definition is
  structural and rebuilds every container. `invalidateDerived` only
  clears the extents cache (`draft_document.dart:149`). New (V-2).
- **F-14.** `ReservedHandles`: layer 0 = 1 (`layerZero`), BYLAYER
  linetype = 2, BYBLOCK linetype = 3, CONTINUOUS = 4, STANDARD text style =
  5, DASHED = 6 (app-written, absent from a default table); colour is a
  `DraftColor`, not a handle (`style.dart:104-121`). New (V-4).
- **F-11.** `forEachInRect` does not descend into instances (it reports
  root-level leaves); `forEachInstanceInRect` reports instances by their
  definition's bounds. Nothing in 09 relies on the former.

## Decisions

### D1 — Where the pieces live

- **Engine** (`packages/jet_cad_2d`): `AddDefinitionCommand`,
  `RemoveDefinitionCommand` (D4) in `document/commands.dart`, exported.
  Nothing else.
- **Render layer** (`packages/jet_cad_2d_flutter`), 09b:
  `src/symbol_gallery.dart` (the widget), `src/symbol_thumbnails.dart` (the
  cache). Generic: they know `GallerySymbol`, never `SymbolComponent`.
- **App** (`apps/floor_planner/lib/symbols/`):
  - `symbol_component.dart` — `SymbolComponent` (D3), registered by
    `registerAppComponents`;
  - `symbol_library.dart` — `SymbolLibrary` and `SymbolEntry` (D5);
  - `symbol_placer.dart` — `placeSymbol` and `placementTransform` (D6);
  - `symbol_search.dart` — the pure search and grouping (D8);
  - `furniture_catalog.dart` — the symbol data; `build_library.dart` — the
    document builder; `apps/floor_planner/tool/generate_furniture_library.
    dart` — writes the asset (D2);
  - 09b: `symbol_place_tool.dart` (Flutter, `Tool`), `symbol_panel.dart`
    (the wiring), `library_asset.dart` (`rootBundle` load).
  The pure files import no Flutter (as `live_objects.dart` does).
- `assets/library/furniture.jetlib` (new asset, `pubspec.yaml`).
- `SymbolComponent` is **not** a parametric type: it is not in
  `parametricCatalog`, so the live-object rule and 06's regeneration never
  see it (plan test: a document holding definitions with it reports no
  diagnostics and survives `regenerate`).

### D2 — The library file, and how it ships

- A library is a `DraftDocument` whose definitions are the masters
  (roadmap decision 1, kept): the codec's bytes, extension **`.jetlib`**
  (the roadmap's `.json` and the brief's `.jetplan` reconciled: `.jetplan`
  is a plan the person edits; `.jetlib` is the same bytes holding only
  definitions, so a file opener never offers it as a plan).
- **Shipping:** a Flutter asset read through `rootBundle`. macOS and web use
  the same path; `DocumentFiles` is untouched.
- **Generated, committed, verified.** `furniture_catalog.dart` holds each
  symbol as data; `buildFurnitureLibrary()` builds the document; the tool
  writes `encodeToString` bytes to the asset. A test builds the library and
  asserts `==` the committed asset's bytes, so the generator and the asset
  cannot drift and the output is deterministic.
- **The library document** has the app's components registered
  (`registerAppComponents`) and units mm; no page, no root children, no
  instances.
- A decoded library is **not** trusted (D5).

### D3 — `SymbolComponent`

Attached to a **definition's handle**: `key` (a stable id, lower-case
dotted, e.g. `bed.double`), `name` (display), `category` (display string),
`tags` (`List<String>`, lower-case), `version` (int ≥ 1). Registered under
its own type id through `registerAppComponents`; value equality over all
fields with `tags` compared in order; `toJson` in fixed key order. A
definition's own `Definition.name` is `"$key@$version"` (unique by
construction), so a DXF-style name table would never collide.

Copied with the definition: the placer attaches the same component to the
new definition (D6), so a saved plan knows where each definition came from
and search, reuse and "what version is this" need no side table.

### D4 — Engine: definition commands

- `AddDefinitionCommand(Definition)`: capability `structure`. Throws
  `DuplicateHandleError` if the handle names a definition, a node or an
  entity; requires `definition.children` empty (a v1 definition lists no
  nodes; the cycle trap of `addDefinition` is closed by refusing to write
  edges through it); `tree.addDefinition`, `handleSeed.raiseTo`, `invalidateDerived` (the
  extents cache, F-13); `touched` names the definition handle, which is
  what makes the spatial index rebuild its containers (F-1, F-13); the
  class comment of `SpatialIndex` (lines 128-136, which says a definition
  command "removes this caveat") is updated by the plan;
  inverse `RemoveDefinitionCommand(handle)`.
- `RemoveDefinitionCommand(handle)`: throws if the handle is not a
  definition, **or if any node or entity still names it** (an instance's
  `definition`, a leaf's `owner`): removal is the last step of a compound
  that has already removed them, so nothing is left dangling (F-6 of the
  brainstorm survey). Inverse `AddDefinitionCommand(value)`.
- Both are `Capability.structure`, so a read-only document refuses them.
  `touched` names the handle. Each placement and each undo costs one `rebuildAll`, like any
  `AddNode` (F-13): off the frame path. The two add commands' duplicate
  checks still ignore definitions (`commands.dart:54, 353`); seed-allocated
  handles never collide with one, and the placer never hands them any other
  (known limit, D14).

### D5 — `SymbolLibrary`: the loader validates

`SymbolLibrary.decode(bytes)` decodes through the codec, then validates and
**throws `SymbolLibraryError` (naming the key or handle)** on any of:

- a definition without a `SymbolComponent`, or two with the same
  `(key, version)`;
- a definition whose `children` names anything (nodes, **leaf handles**
  included: the trap of `childNodesOf`), or any node or instance in the
  document other than the root;
- a leaf whose owner is not a definition, or whose kind is `text`, `fill`
  or `attrib`;
- a leaf whose style is not on the **allow-list** (decision 4, F-14):
  `layer == layerZero`; `linetype` ∈ {BYLAYER, BYBLOCK, CONTINUOUS}; text
  style (if any) = STANDARD; `color` ∈ {`ByBlockColor`, `ByLayerColor`};
  `lineweight` and `transparency` ∈ {`kByBlock`, `kByLayer`}; `flags` with
  neither invisible nor unpickable; `linetypeScale` finite. (DASHED, 6, is
  refused: a default document has no such record.)
- a leaf of kind `point`, or degenerate geometry: a coordinate that is
  non-finite or beyond ±1e6, a zero-length line, a polyline under two
  vertices or with a non-finite bulge, a radius ≤ 0, a zero sweep;
- an invalid `basePoint` (non-finite).

The "leaf handle in `children`" case needs hand-built JSON: the codec
strips leaf handles on encode (`json_codec.dart:56`) (V-9).

It never relies on the tree to reject a malformed library (the roadmap's
trap). The result is `List<SymbolEntry>` in definition-handle order
(`key`, `name`, `category`, `tags`, `version`, `definition`, and a snapshot
of its leaves: `(EntityRecord, GeometryPayload)` ascending by handle, so
draw order is preserved, D6). Categories appear in first-appearance order.

### D6 — Placement

`placeSymbol(DraftDocument doc, SymbolEntry entry, {required Vector2 at,
int quarterTurns = 0, bool mirrored = false, InstanceStyle style})` returns
**one `CompoundCommand`** labelled `Place <name>`. It allocates every handle
it needs from `doc.handleSeed` at construction (F-8) and does not execute.

1. **Find.** `doc.components.withComponent<SymbolComponent>()` (or a scan of
   `doc.tree.definitions`) for `key == entry.key && version ==
   entry.version`; once per placement, never per frame. A found definition
   is reused even if a person edited its leaves (known limit, D14).
2. **Copy on first use** (none found): fresh handles for the definition and
   every leaf; the commands, in order: `AddDefinitionCommand` (name
   `"$key@$version"`, suffixed `#2`, `#3`… while a definition of that name exists: only a
   foreign or non-symbol definition can hold it, since a symbol's own is
   found in step 1), `SetComponentCommand<
   SymbolComponent>` on it, then one `AddEntityCommand` per leaf, ascending
   (the library's order, so draw order is stable, non-negotiable 2), with
   `owner` the new definition. A found definition contributes no commands.
3. **The instance:** `AddNodeCommand(InstanceNode(handle: fresh, parent:
   doc.rootHandle, definition, layer: ReservedHandles.layerZero,
   transform: placementTransform(...), color/lineweight/transparency/
   linetype/linetypeScale from style))`. `style` defaults to the instance
   defaults (BYBLOCK); it exists so 09's tests and later sub-projects can
   place a coloured instance, and the placer passes every field through.
4. **`placementTransform(at, basePoint, quarterTurns, mirrored)`** `=
   translation(at) · rotation(q·90°) · scale(mirrored ? -1 : 1, 1) ·
   translation(−basePoint)`: the definition's base point lands on `at`
   (F-2). Mirror flips the **local** x axis whatever the turns. Quarter turns use
   exact cosine and sine (0, ±1, never `6e-17`), and the stored matrix has
   `-0.0` normalised to `0.0`, so a placement at a quarter turn stores
   clean numbers in the file's bytes. A free angle is not
   offered in 09; the Select tool's rotation grip turns a placed instance
   (plan verifies its grips handle an `InstanceNode`, F-7).

Undo removes the instance, the leaves, the component and the definition in
one step (the compound's inverse reverses the order); redo restores them
with the same handles. Placing twice yields **two instances, one
definition** (assert the count). Nothing here writes a table or touches
`DraftDocument.purge`.

### D7 — The content

About 24 symbols in six categories, authored in mm around a **non-origin
base point** (the insertion point is the front-centre or the centre, and
the local frame's origin is a corner, so `basePoint != (0, 0)` for every
symbol; a library test asserts it, degenerate fixture avoided by
construction):

- **Dining Room:** dining table 4 and 6 seats, round table, dining chair,
  bench. **Kitchen:** base unit 600, sink unit, hob, fridge, island.
  **Bed Room:** double bed, single bed, nightstand, wardrobe.
  **Living Room:** three-seat sofa, armchair, coffee table, TV unit.
  **Bathroom:** toilet, washbasin, bathtub, shower tray.
  **Office:** desk, office chair, bookshelf.
- Geometry only: lines, polylines, arcs, circles on layer 0, BYBLOCK style
  (the instance colours them). The list is the plan's to fix; the rules are
  the spec's.
- Every symbol has a `key`, `category`, at least two tags and `version: 1`.

### D8 — Search and grouping

`searchSymbols(List<SymbolEntry>, String query)` (pure): the query is split
on white space, lower-cased; a symbol matches when **every** term is a
substring of its name, any tag or its category (case-insensitive); empty
query matches all. Groups keep the library's category order and symbol order.
No fuzzy match.

### D9 — The gallery widget (09b, render layer)

`SymbolGallery` takes `List<GalleryCategory>` (each: `name`, `List<
GallerySymbol>`), a search `String`, `onSelect(String id)`, the selected
id. A `GallerySymbol`: `id`, `label`, `tags`, `thumbnailKey` (a value),
`DraftDocument Function() thumbnailDocument`, `Aabb2 bounds`. Collapsible
category headers (state in the widget, collapsed state not persisted);
rows with a thumbnail and the name. The widget cannot import the app's
`PanelFieldFocusNode`: it takes an injected `searchFocusNode`,
`onSubmitted` and `onTapOutside`, and the app passes the node its
`_settlePendingInput` hands back (V-7). `chrome-left` is not inside
`ShellShortcutGuard` (only the right panel is, `main.dart:784`), so the
field wears its own guard. A row never takes focus
(`ExcludeFocus`, like the tool palette, Ruling 05-6). The search **field**
does take focus: it follows the page panel's pattern (`panel_focus.dart`,
`shortcut_guard.dart`) so typing never fires a shell shortcut and
Escape/Enter hand focus back.

**Thumbnails** (`SymbolThumbnails`): rendered through `DraftPainter` into a
`ui.Image` at the row's pixel size × devicePixelRatio, from a scratch
document the app supplies (`thumbnailDocument`: the placer's own output at
`at = basePoint`, quarter turns 0, so a thumbnail is what a placement
makes). Lazily, when a row first builds; an in-memory LRU (64) keyed by
`(thumbnailKey, pixelSize, devicePixelRatio, brightness)`; evicted images
are disposed; nothing persists on disk; a key change invalidates, no other
trigger is needed because the library is immutable in a session. There is no
second render path.

### D10 — Interaction with the existing machinery (09a proves it)

The 09a end-to-end test places a symbol in a **rotated, mirrored** placement
with a **distinct colour and lineweight on the instance**, far from the
origin, through `DocumentHost`'s document and the real dispatcher, then
checks in one test: the painter's recorded stroke colours and widths (F-7),
a pick at the instance's world position, a snap onto a **named leaf
endpoint** whose world position the test computes independently from the
leaf's local coordinates and the expected transform (within `Tolerance`;
the insertion point is not a candidate, F-12), the extents, `validate()` empty,
and save → load byte identity. Whatever breaks is fixed in 09a (engine or
render), inside the spec's bounds, or recorded as a ruling.

### D11 — The placement tool (09b, app)

`SymbolPlaceTool extends Tool`, armed with one `SymbolEntry`:

- **States:** armed-idle, hovering (mouse: ghost at the pointer), pressed
  (a press, with or without drag; the ghost follows). **Release places at
  the release point** (touch has no hover: the ghost appears on press).
  After a placement the tool stays armed.
- **Keys:** `R` rotates one quarter turn, Shift+R the other way, `M`
  mirrors. **While armed the tool consumes R and M**, which are the shell's
  Rectangle and Room shortcuts: a tool is chosen by letter again after
  `Esc` (cost if wrong: one key press; the alternative keys would be
  invented). Like the drawing tools, it swallows every other key mid-press
  and lets F and F3 bubble (`placement_tool.dart:196-215`). `Esc` idle
  reaches the shell's `_escape` (the Select tool comes back); `Esc`
  mid-press cancels the press only.
- **Snap:** through `resolveDragPoint` with a `DragPoint` and `SnapResult`
  scratch, as the drawing tools do (`placement_tool.dart:114-125`): object
  snap per F3 at `kSnapAperturePixels / scale`, else grid snap, else the raw
  point; the snapped point is the placement's `at`.
- **The ghost:** the symbol's bounds, transformed by `placementTransform`,
  as an outline plus a cross at `at`, through `paintWorldOverlay`: no
  geometry is drawn through a second path.
- **`isMidShape`** is true while a press is down (F-10). A placement is not
  executed while pending input is unsettled; the shell's settle runs first
  (`_settlePendingInput()`).
- **Permissions before handles** (Ruling 05-3, `placement_tool.dart:236`): the
  tool checks `needs = {structure, geometry, components}` (the compound's
  union) **before** it calls `placeSymbol`, which allocates; the gallery
  rows are disabled while any is denied.
- **Why not `PlacementTool`** (`draw/placement_tool.dart`, click by click):
  a symbol is placed by press, drag and release at the release point, and
  the name is taken; this one is `SymbolPlaceTool`, extending `Tool`.
- The armed symbol should not survive a document swap (12a's keyed rebuild builds a new shell, spec 12a D2, R-1); the plan verifies it.
- The placed instance is not selected; the tool stays armed.

### D12 — The panel

The `chrome-left` slot keeps the tool palette and gains the gallery below it,
with the search box above the categories. Selecting a row goes through the shell's `_activate` (`main.dart:535-541`,
the palette's `onSelect`), **not** `ToolController.activate` directly: it
refuses a drawing tool while geometry is denied and clears the selection,
whose outlines and grips the overlay paints under any tool. Selecting a tool
clears the gallery's highlighted row. The exact layout is the human's look (exit gate).

### D14 — Known limits

- A found definition is reused even if a person edited its leaves.
- `AddEntityCommand` / `AddNodeCommand` duplicate checks ignore definitions.
- Each placement and undo rebuilds the index containers (off the frame
  path).
- Text in a mirrored instance draws mirrored (F-6); symbols carry none.
- `purge` does not clean components on a definition (the plan records what
  it does).
- R and M are consumed while the placement tool is armed (D11).

## Architecture

### Files

| File | Change |
|---|---|
| `packages/jet_cad_2d/lib/src/document/commands.dart`, `jet_cad_2d.dart` | D4 |
| `packages/jet_cad_2d/lib/src/index/spatial_index.dart` | class comment only (D4) |
| `packages/jet_cad_2d/test/document/definition_commands_test.dart` (new) | D4 |
| `apps/floor_planner/lib/symbols/*.dart`, `tool/generate_furniture_library.dart`, `assets/library/furniture.jetlib`, `pubspec.yaml` | D1–D8 |
| `apps/floor_planner/lib/parametric/catalog.dart` | `registerAppComponents` gains `SymbolComponent` |
| `packages/jet_cad_2d_flutter/lib/src/symbol_{gallery,thumbnails}.dart`, `jet_cad_2d_flutter.dart` | D9 (09b) |
| `apps/floor_planner/lib/{main,tool_palette}.dart` | D12 (09b) |
| `roadmap/09-symbol-library.md`, `roadmap/00-README.md` | status; `.json` → `.jetlib`; "drag" → "place" (at the spec commit, not at execution) |

### Invariants

- The frame path untouched: no per-frame work is added; the allocation
  invariants stay unedited and green.
- Draw order ascending handle, stable across undo, save, load and purge: the
  leaves are added in the library's ascending order with handles ascending.
- Geometric decisions use `Tolerance` (the snap test), stored values `==`
  (the placed transform, the component, the byte identity).
- Placing writes no table record and no handle seed rollback is relied on.

## Testing

Every fixture avoids the three degenerate cases: a `basePoint` off the
origin, an instance at a non-identity (rotated, mirrored, off-origin)
transform, style overrides unequal to the defaults. Every test is owed a
named mutant that turns it red, fired by the implementer and again by the
reviewer.

### Tests by area

- **Engine (D4):** add, undo, redo of a definition; duplicate handle
  against a definition, a node and an entity; non-empty `children`
  refused; removal refused while an instance or a leaf names it; read-only
  permission refuses; `stateId` moves; a pick finds an instance of an added
  definition **without any rebuild call**, and a stale pick after undo
  finds nothing; the document's extents follow the placement and its undo.
- **Library (D2, D5):** the generated bytes `==` the asset; decode lists
  every definition; each rejection of D5 has its own case (a leaf handle in
  `children`, a nested instance, a non-reserved layer, a text leaf, a
  duplicate key, a missing component, a non-finite base point); every
  symbol's `basePoint != (0, 0)`; every symbol has a category and two tags.
- **Placement (D6):** the base point lands on `at` (distinct `basePoint`,
  off-origin `at`, rotated, mirrored); placing twice gives one definition
  and two instances with distinct handles; style fields reach the
  instance; undo is one step and removes instance, leaves, component and
  definition, redo restores the same handles; a document holding another
  definition at a handle the library also uses (handles collide across
  documents) places without a duplicate-handle error; a stored older
  version is left alone and the new version is copied beside it, names
  distinct; quarter-turn matrices are exactly 0 / ±1; save → load is
  byte-identical with instances and definitions; the dirty state follows
  `stateId`.
- **End to end (D10):** the single test described there.
- **Search (D8):** name, tag and category each alone find a symbol; two
  terms both required; case; empty.
- **Gallery and thumbnails (D9, 09b):** a category collapses; a row's tap
  calls `onSelect`; the thumbnail image differs between two symbols and
  between two versions of one key (cache key), is disposed on eviction, is
  not regenerated for a repeated build; typing in the search field fires no
  shell shortcut.
- **Placement tool (D11, 09b):** release places at the snapped point;
  `R`/`M`/`Esc`; `isMidShape` true between press and release; stays armed;
  one undo per placement; touch (a press with no prior hover).

## Named mutants

| Id | Mutation | Red test |
|---|---|---|
| M-09a | the placer ignores `basePoint` (no `translation(−basePoint)`) | base point lands on `at` |
| M-09b | the placer copies the definition on every placement | two placements, one definition |
| M-09c | the placer drops rotation or mirror from the transform | rotated and mirrored placement; end to end |
| M-09d | the placer drops the style fields | style reaches the instance; painter colours |
| M-09e | the placer omits `AddDefinitionCommand` | save → load; `validate()` |
| M-09f | the compound's undo leaves the definition | undo removes everything in one step |
| M-09g | `AddDefinitionCommand` skips `invalidateDerived` | **equivalent**: a bare definition changes no extents, and the compound's `AddEntity` / `AddNode` invalidate anyway; the call stays (correct), the gate does not claim the mutant red |
| M-09p | `AddDefinitionCommand`'s `touched` omits the handle | **equivalent**: every alternative falls back to `rebuildAll` (`spatial_index.dart:2686, 2829`); recorded, not chased |
| M-09h | the lookup ignores `version` | older version left alone, new copied |
| M-09i | leaves keep the library's handles | cross-document handle collision |
| M-09j | the loader drops a D5 rule (one mutant per rule) | its rejection case |
| M-09k | the thumbnail key ignores the version | version change regenerates |
| M-09l | search ignores tags | tag alone finds a symbol |
| M-09m | `isMidShape` stays false during a press | mid-press commands disabled |
| M-09n | quarter turns use `rotation(rad)` | exact 0 / ±1 |
| M-09o | leaf handles allocated in descending library order | draw order after undo, save, load (handle-distinct fixtures) |
| M-09q | `RemoveDefinitionCommand` drops its "named by" guard | refusal while an instance or a leaf names it |
| M-09r | `AddDefinitionCommand` drops the non-empty-`children` or definition-duplicate check | its refusal cases |
| M-09s | search `every` becomes `any`; search ignores the category | two terms; category alone |
| M-09t | the `#2` suffix dropped | a foreign definition with the name |
| M-09u | `SymbolComponent` equality or `toJson` ignores tag order | equality, byte determinism |
| M-09v | the transform composes `R·T·S` | base point lands on `at`; the fixture has a non-zero turn, an off-origin `at` **and** an off-origin `basePoint` (at zero turns `R·T·S` = `T·R·S`) |
| M-09w | the tool skips the `components` capability | denied `components` refuses, allocates nothing |
| M-09x | the thumbnail key ignores pixel size, DPR or brightness | one case each |

## Exit gate

- **09a:** engine, render layer and app standing gates green with `CI=true`
  (engine 2 and render 7 + 1 skip standing failures unchanged); app
  `flutter build web --release` builds; the two allocation invariant tests
  unedited and green; every named mutant of 09a fired red, recorded in the
  results note; `.jetlib` generated bytes equal the asset.
- **09b:** the same gates; M-09k..m fired; the human's look.
- **The human's look (never marked done for them), macOS and web (Chrome,
  Firefox):** the gallery's look in light and dark; category collapse; the
  search box takes focus and typing fires no shortcut, `Esc` returns focus
  to the canvas; thumbnails are sharp on a Retina display; the ghost follows
  the pointer and snaps; a press-drag-release places (and on a touch screen
  or a simulated touch); `R`, `M`, `Esc`; two placements, then undo twice
  and redo; saving and reopening a plan with symbols; an older-version plan
  opens and its symbols stay.

## Spec rulings

- **R-1 (D4):** `AddDefinitionCommand` refuses non-empty `children`, over
  guarding the cycle in `addDefinition`: v1 definitions hold leaves only, and
  no edge is written through an unguarded API. Cost if wrong: a later slice
  that nests symbols extends the command with the cycle guard.
- **R-2 (D3):** the component is on the definition's handle, over a side
  table: one source of truth, saved and reloaded with the plan.
- **R-3 (D6):** the definition name is `"$key@$version"`, over the display
  name: unique by construction.
- **R-4 (D11):** the ghost is an outline of the bounds, over a drawn
  preview: no second render path.
- **R-5 (D7):** symbols hold no text and no fill: a mirrored text draws
  mirrored (F-6), and a fill's boundary reference would need handle remapping
  of a second kind. Cost if wrong: flat outlines; a later slice adds both.

## Revision 2

Applies the review of revision 1 (V-1 to V-11), all inside the human's
decisions: V-1 the snap assertion names a leaf endpoint (D10, F-12); V-2
M-09g retargeted to extents, M-09p recorded equivalent, the index comment
in the files table (D4, F-13); V-3 M-09o made observable; V-4 the allow-list
and geometry rules (D5, F-14), `layerZero` (D6); V-5 `_activate` (D12); V-6
permissions before handles, `resolveDragPoint`, key handling (D11); V-7 R/M
consumed while armed, the focus node injected, the field's own guard (D9,
D11); V-8 the D6 details; V-9 the codec note and the `rebuildAll` cost (D4,
D5); V-10 nine mutants; V-11 D14 and the tool's naming (D11).

## Revision 3

Applies the re-review of revision 2 ("Ready with one amendment"): R-1
M-09g recorded equivalent (the `invalidateDerived` call stays); R-2 M-09v's
fixture named; R-3 the document-swap claim cited to 12a D2 and left to the
plan to verify.
