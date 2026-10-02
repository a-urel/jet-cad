# Wall-aware symbols and the Symbol section (09c) — design

**Date:** 2026-10-02. **Status:** design, **revision 1**, for independent
review.
**Sub-project:** `roadmap/09-symbol-library.md`, slice **09c** (09a, the
core, is merged at `b4e7cdd`; 09b, the palette, at `6f7b69a`). **Size:** L,
executed as **two plans** (decision 11): **09c-1** (wall attachment, the
placement tool, content, the debts) and **09c-2** (the Symbol section, the
Select tool's wall-aware move).
**Branch:** `spec-09c/wall-aware-symbols`, cut from `main` at `4d6b78f` (the
merge that records 12b). Plan branches: `plan-09c/<slug>` cut from it.
**Depends on:** 09a, 09b, 07 (walls), 08 (host frames), 12b (layers: usable
hosts). **Supersedes** nothing; it amends the 09 spec's D14 known limits
(two of them are fixed here, D10, D11) and the 09b spec's R-B6-3 and R-B9-2
(fixed, D12, D13).
**Brainstormed with the human on 2026-10-02**, on `main`, after reading the
09a and 09b results notes ("Found, not fixed"), the Selection panel, the
catalog, the placer, the placement tool, the Select tool's move path, the
wall bands and the host frame (facts below, from `main` at `4d6b78f`).

**Inputs read:** `CLAUDE.md`; `STATUS.md`; `roadmap/00-README.md`,
`roadmap/09-symbol-library.md`; the 09 and 09b specs; the 09a and 09b
results notes; `apps/floor_planner/lib/{main,selection_panel}.dart`,
`lib/symbols/*.dart`, `lib/parametric/{wall,wall_bands,wall_geometry,
opening_geometry,opening_tool,object_grips}.dart`;
`packages/jet_cad_2d_flutter/lib/src/{tool,select_tool,grip_drag,grip_cache,
draw/placement_tool}.dart`; `packages/jet_cad_2d/lib/src/document/
{commands,component,layer_commands,draft_document}.dart`,
`index/drag_snap.dart`.

## Decisions the human made on 2026-10-02

The 09 spec's decisions stand (static symbols, key + version identity,
select-then-click, free-standing instances); so do 09b's. New, in the order
they were asked:

1. **Scope: the Symbol section and wall-aware placement**, plus only the
   content those two need; user-made symbols (a symbol from a selection, an
   imported library) are a separate, larger slice and are **not** here.
2. **Attachment is automatic, for tagged symbols only.** A symbol the
   catalog marks as standing against a wall (a tag, no schema change)
   attaches when the **raw pointer** comes within a capture distance of a
   visible, unlocked wall's face: its back lies on the face, its front faces
   the room, it slides along the face with the pointer; away from a face it
   places freely as today. Off while object snap (F3) is off.
3. **Along the face, a side edge snaps** to the face's drawn end (an inside
   corner) and to the side of another symbol already against the same face
   (kitchen runs); the ghost stays within the face.
4. **Attachment is a placement aid only.** A placed symbol is a plain
   instance and does not remember its wall; moving the wall later leaves it
   where it is. No schema, codec or regeneration change.
5. **While attached, `M` mirrors; `R` and `Shift+R` wait:** they change the
   quarter-turn count, which applies again once the ghost leaves the face;
   the wall sets the angle, which need not be a quarter turn.
6. **The Symbol section** in the Selection panel: the name (read-only), the
   size `W × D` (read-only), a rotation in degrees about the insertion
   point, a Mirror button, and a **Size** menu listing the symbol's family
   (e.g. a double bed 1400 / 1600 / 1800); each change is one undo step; the
   section shows for exactly one selected symbol.
7. **Content:** six size families and two appliances, about 15 new
   symbols (D9); the existing keys stay, as one member of their family.
8. **Debts pulled in, all four:** the search text survives a tab switch
   (R-B9-2); the ghost follows a wheel zoom (R-B6-3); a definition whose
   leaves differ from the library's is not reused (09 D14); a removed
   definition's components are removed with it (R-T2-2).
9. **A size change keeps the back-left corner** (local `x` minimum, `y`
   maximum) where it was in the world: against a wall the back stays on
   the face and the left side against its neighbour; a wider size grows to
   the right (to the left when mirrored).
10. **The Select tool's move attaches too**: a single selected tagged
    symbol dragged by its body near a wall face attaches as in placement.
11. **One spec, two plans**, merged in order (09c-1, then 09c-2), each with
    its own look and merge.

## What this delivers

- **Placement against walls:** a bed, a wardrobe, a kitchen unit, a toilet
  dropped near a wall lands flush on its face, turned to it, its side
  against the corner or the previous unit when close.
- **A Symbol section** for a selected symbol: name, size, rotation, mirror,
  and a size menu that swaps a bed 1600 for an 1800 in place.
- **A wall-aware move:** dragging one such symbol along a wall keeps it on
  the face; dragging it to another wall turns it to that wall.
- **41 symbols** (27 today), with size families and a dishwasher and a
  washing machine.
- Four small debts closed.

## Non-goals

- A symbol that follows its wall (decision 4). Avoiding doors and windows:
  a symbol may attach in front of an opening (D10, known limits).
- Editable width or depth (a parametric symbol); a free scale of an
  instance. Sizes are discrete family members.
- Wall attachment for a multi-selection, for the move grip (an instance has
  none, F-10), for the rotation grip, or for a symbol inside a group.
- Attachment to a curved wall (none exist), to a room separator, or to a
  plain line.
- User-made symbols, library import, recent or favourite symbols.
- The two engine fingerprint tests (`generate_document_test.dart:66, :68,
  :251, :253`) and the Wall tool's hidden-layer join (STATUS, open to the
  human): not touched.

## Facts established (verified on `main` at `4d6b78f`)

- **F-1 The catalog's frame.** `furniture_catalog.dart:1-4`: every symbol is
  in millimetres, x to the right, y up the plan, **the front on `y = 0`**;
  the base point is the centre or the front-centre. Every symbol a wall
  would host (beds, wardrobe, kitchen units, sofa, TV unit, toilet,
  washbasin, tub, shower, desk, bookshelf) has its back at its largest `y`
  (the toilet's cistern at `y` 500–700, the washbasin's tap at `y` 410, the
  sofa's back at `y` 700–900, the bed's pillows at `y` 1680–1920).
- **F-2 Placement is quarter turns only.** `placementTransform`
  (`symbol_placer.dart:39`) is `translate(at)·rot(q·90°)·scale(±1, 1)·
  translate(−basePoint)` with exact cosines and sines and no `-0.0`;
  `GhostMatrix.update` (`symbol_ghost.dart`) recomputes `P` only when `at`,
  the base point, the turns or the mirror change.
- **F-3 Reuse.** `placeSymbol` (`symbol_placer.dart:65-145`) reuses the
  first definition (ascending handle) whose `SymbolComponent` has the
  entry's key and version and whose definition still exists; otherwise it
  copies the definition, named `key@version` with a `#n` suffix on a
  collision. It does not compare leaves (09 D14).
- **F-4 Components outlive definitions.** `RemoveDefinitionCommand`
  (`commands.dart:454-492`) never touches components; `purge()`
  (`draft_document.dart:193-211`) touches neither definitions nor
  components. `ComponentRegistry` (`component.dart`) has `attach`, `get`,
  `detach` per type, `withComponent<T>`, `unknownOf`; **no per-handle
  enumeration of the registered types** (`_stores` is private).
- **F-5 No command changes an instance's definition.**
  `InstanceNode.copyWith(definition:)` exists (`node.dart:208`);
  `tree.replaceNode` guards cycles (`tree.dart:196`). `TransformNodeCommand`
  (`commands.dart:285`) sets a node's transform outright (capability
  `transform`, label `Move`). `SetInstanceLayerCommand`
  (`layer_commands.dart:424`) is the pattern for a one-field instance edit.
- **F-6 Wall data.** `WallBands` (`wall_bands.dart`) caches, per live,
  non-degenerate wall, ascending by handle: world start and end, unit
  direction, length, left and right face offsets, thickness, handle;
  rebuilt only on a document change; a scan is O(walls) and allocates
  nothing. `hostAt` (`:82`) finds the wall whose **band** holds a point,
  with an `accept` filter. `isUsableHost` (`opening_tool.dart:447`): the
  wall's object layer is visible and unlocked (12b S-11).
- **F-7 Drawn faces.** `hostFrameOf` (`opening_geometry.dart:76`) gives a
  wall's `HostFrame` in its group-local space: `s`, `d`, `n`, the face
  offsets, and the **drawn caps** (`startCap` from the left face to the
  right face, `endCap` from the right face to the left), so a face's drawn
  run is from its start-cap point to its end-cap point; `Obstacle`s and
  `stretchesOf` give the intervals other walls occupy (a T).
  `wallsInDocument` (`:711`) is the document adapter.
- **F-8 The placement tool.** `SymbolPlaceTool` (`symbol_place_tool.dart`)
  resolves the pointer through `resolveDragPoint` (object snap at
  `kSnapAperturePixels / scale`, `kSnapAperturePixels = 10.0`,
  `drag_snap.dart:14`; the grid; the raw point); places on release; `R`,
  `Shift+R`, `M`, `Esc`; has **no camera listener** (R-B6-3). The drawing
  tools' `PlacementTool` re-resolves from the last screen point on a camera
  change (`draw/placement_tool.dart:258-279`): the pattern to copy.
- **F-9 The search text.** `SymbolPanel` owns its `TextEditingController`
  (`symbol_panel.dart:105`); the shell builds the panel only on the Symbols
  tab (`main.dart:809`), so a tab switch disposes it (R-B9-2).
  `searchSymbols` matches every term as a substring of the name, a tag or
  the category (`symbol_search.dart`).
- **F-10 The Select tool's move.** `SelectTool`
  (`jet_cad_2d_flutter/lib/src/select_tool.dart:36`, constructed bare at
  `main.dart:320`) moves by a **body drag** (`GripDrag.move`, `:219`) or a
  move grip; **an `InstanceNode` has no grips** (`GripCache` asks the
  provider only for a root-level `GroupNode`, `grip_cache.dart:350-359`),
  so a symbol moves by its body only. Each move event: `_retarget`
  (`:347`) resolves the pointer through `resolveDragPoint` and calls
  `GripDrag.moveTo` (`grip_drag.dart:225`), **translation only**. The
  preview is `selectionPreviewTransform` (`:100`), a delta applied to the
  cached outlines; the commit is one `CompoundCommand` of
  `TransformNodeCommand(h, t·node.transform)` (`grip_drag.dart:269-330`),
  after `ctx.grips?.carry(t)`. A camera change re-targets (`_onCamera`).
  **No seam lets the app change a body move**: `ObjectGripProvider`
  (`grip_cache.dart:29`) covers reshape grips of a root-level group only.
- **F-11 The Selection panel.** `_selected<T>()`
  (`selection_panel.dart`) is the one selected, chain-free key when it is a
  live `T`; a selection with no type section shows only the layer picker
  (12b D12). Every section is read-only under runtime permissions.

## Decisions

### D1 — Where the pieces live

| Piece | Package | File |
|---|---|---|
| `RemoveDefinitionCommand` takes the handle's components with it; `ComponentRegistry` gains the per-handle snapshot (D11) | engine | `component.dart`, `commands.dart` |
| `SetInstanceDefinitionCommand` (D7) | engine | `commands.dart`, `jet_cad_2d.dart` |
| `MoveResolver` seam on `SelectTool`; `GripDrag` takes a full move transform (D8) | render | `select_tool.dart`, `grip_drag.dart`, `jet_cad_2d_flutter.dart` |
| The symbol's local box, the wall faces, `attachToWall` (D2, D3, D4) | app | `lib/symbols/wall_attach.dart` (new), `lib/symbols/symbol_box.dart` (new) |
| `placementTransform` generalised; `GhostMatrix` keyed on the transform (D5) | app | `symbol_placer.dart`, `symbol_ghost.dart` |
| The placement tool attaches; camera listener (D6, D12) | app | `symbol_place_tool.dart` |
| The Symbol section (D7) | app | `selection_panel.dart`, `lib/symbols/symbol_section.dart` (new) |
| The app's `MoveResolver` (D8) | app | `lib/symbols/symbol_move.dart` (new), `main.dart` |
| Families, the wall tag, new content (D9) | app | `furniture_catalog.dart`, `assets/library/furniture.jetlib`, `symbol_library.dart` |
| Leaf-equal reuse (D10) | app | `symbol_placer.dart` |
| The search text kept (D13) | app | `main.dart`, `symbol_panel.dart` |

`wall_attach.dart` and `symbol_box.dart` are Dart over `package:jet_cad_2d`
and the app's parametric files only: no Flutter, no `dart:ui`.

### D2 — The symbol's local box and its tags

- **The local box** of a definition is the axis-aligned bounds of its
  leaves in the definition's coordinates: a line's and a polyline's
  vertices, a circle's and an arc's **true** extents (an arc's bounds
  include an axis crossing only when its sweep passes it). `left = minX`,
  `right = maxX`, `front = minY`, **`back = maxY`** (F-1). `W = right −
  left`, `D = back − front`.
- For a library entry it is computed once per `SymbolEntry` (an `Expando`,
  like the ghost path). For a definition in a document (D7, D8) it is
  computed from the definition's live leaves and memoised per definition
  handle, cleared on every document change (the panel's memo pattern,
  F-11).
- **Two tags carry the behaviour** (decision 2), lower-case per the
  loader's R03c:
  - `against-wall`: the symbol attaches (D3, D6, D8);
  - `family:<id>` (e.g. `family:bed-double`): the symbol's size family
    (D7, D9). At most one per symbol; a library with two is refused (a new
    loader rule, R03d).
- **The tags are read from the library**, by the instance's key (the
  document's `SymbolComponent` supplies the key): a plan placed before 09c
  attaches on a move and offers its family as soon as the library is
  ready. Before the library is ready (loading, failure), a placed symbol
  has neither behaviour; nothing else changes.
- **A tag-only change does not bump a symbol's version** (a ruling of this
  spec): `version` identifies the definition's geometry, which reuse
  (D10) compares. 09c adds tags to existing symbols at `version: 1`.
- Search is unchanged: `against-wall` and `family:` tags match a query as
  any tag does (the cost: "wall" lists the wall-standing furniture).

### D3 — The wall faces

A **face run** is a straight piece of a wall face a symbol can stand
against, in world space: the unit normal `m` that points **out of the wall
into the room**; the unit direction **`t = (−m.y, m.x)`** along it, which
is the right hand of a person in the room facing the wall (so a symbol's
local `+x`, its right seen from its front, runs along `t`); the start point
`a`, the run's end with the smaller `(· )·t`; the length `L`; and the
wall's thickness `w`. For a left face `t = −d`, for a right face `t = d`.

- **Candidates:** the walls of `WallBands` (F-6) that pass `isUsableHost`
  (F-6) and are not degenerate. A wall gives its **left** face (offset
  `lOff` along `n`, `m = n`) and its **right** face (`rOff`, `m = −n`).
- **A face's run** is its drawn extent: along the face, from the start cap's
  point on that face to the end cap's point on that face (F-7), in the
  wall's `HostFrame`, then taken to world through the wall's group
  transform. An L corner's inside face is therefore shorter than its
  centreline; an outside face longer.
- **A T splits a run.** An `Obstacle` of another wall (F-7) whose body lies
  on this face's side cuts the run at the obstacle's `[a, b]`; the pieces
  shorter than `wallJoin.linear` are dropped. An obstacle on the other side
  leaves this face whole.
- **Openings do not split a run** (non-goal): a wardrobe may stand in front
  of a door.
- **Cost:** faces are computed per wall from `wallsInDocument` and cached
  with `WallBands.generation` (the opening tool's frame-cache rule, 08
  Ruling 08-13): recomputed only when the document changes. A pointer move
  over a cached set is O(runs) and allocates nothing.

### D4 — `attachToWall`: the one rule

`attachToWall(runs, box, pointer, captureWorld, {mirrored, neighbours,
edgeCaptureWorld})` returns the attached transform, or null. Pure, in
`wall_attach.dart`; the placement tool (D6) and the move resolver (D8) call
it, and only through it.

1. **The face.** For each run, `s = (p − a)·m` (the pointer's signed
   distance from the face, positive in the room) and `u = (p − a)·t`. A
   run is a candidate when `−w/2 ≤ s ≤ captureWorld` and `−captureWorld ≤
   u ≤ L + captureWorld`: a pointer in the room near the face, or inside
   the wall's body on this face's half of the band (the door-swing rule of
   08 D14, so the two faces of one wall never both qualify, except on the
   midline, where the tie rule decides). The smallest `|s|` wins; a tie
   goes to the lower wall handle, then the left face, then the lower `a`
   along `t`. None: null.
2. **The run must hold the symbol:** `W ≤ L` (a decision, compared with
   `Tolerance.linear` slack). A shorter run: null (the ghost stays free).
3. **The orientation** is the proper rotation `R` that takes local `+y`
   (towards the back) to `−m` (into the wall), hence local `+x` to `t`:
   `cos = t.x = −m.y`, `sin = t.y = m.x`, exactly those doubles, `-0.0`
   normalised to `0.0` as F-2 does. The mirror, when set, is `scale(−1, 1)` about the
   box's centre `x` (so the footprint does not move).
4. **Along the face**, `u = (p − a)·t` is the pointer's projection; the
   symbol's centre goes at `u`, then:
   - **edge snaps** (each within `edgeCaptureWorld` of the side it moves):
     the left side to the run's start (`0`), the right side to its end
     (`L`), the left side to a neighbour's right side, the right side to a
     neighbour's left side; the nearest wins, ties to the lower value;
   - **clamp:** the centre is clamped to `[W/2, L − W/2]` (decision 3).
5. **The transform** is `translate(q)·R·M·translate(−c)`, `c = ((left +
   right)/2, back)` the local back-centre, `q = a + u·t` the world point on
   the face. So the symbol's back edge lies on the face line, its front in
   the room.

**Neighbours** (decision 3) are the placed symbols standing against the
same run: root-level instances whose definition carries a
`SymbolComponent` and whose transformed local back edge has both ends on
the run's line (distance at most `wallJoin.linear`) with their front on the
room side; each gives its `[uLeft, uRight]` along the run. They are found
through the spatial index over the run's strip, once per run per cache
generation; the instance being moved (D8) is excluded.

`captureWorld` is `kWallAttachPixels / scale`, `kWallAttachPixels = 16.0`
(larger than the snap aperture: the pointer is often the symbol's centre,
far from its back); `edgeCaptureWorld` is `kSnapAperturePixels / scale`.

### D5 — The placement transform, generalised

- `placementTransform` gains a rotation given as a unit vector `(cos,
  sin)`; the quarter-turn form stays and calls it with the exact table.
  Both normalise `-0.0`.
- `GhostMatrix.update(placement: Transform2)` compares the six doubles of
  the new transform with the last ones exactly and recomputes nothing when
  they are equal; its `computations` count stays (09b's tests move to the
  new signature). The paint path is unchanged: no allocation per paint.

### D6 — The placement tool attaches

- After `_resolve` (F-8), when the armed entry carries `against-wall`,
  object snap is on, and `attachToWall` (D4) with the **raw** pointer
  returns a transform, the ghost and the release use **that** transform;
  otherwise today's `placementTransform(at, turns, mirror)`.
- **Keys while attached** (decision 5): `M` toggles the mirror, which D4
  applies; `R` and `Shift+R` change the turn count only.
- **The marker:** while attached the snap marker is drawn at `q` (D4), the
  point on the face, as the opening tool draws its marker on the centreline
  (08 Ruling 08-14).
- **The commit:** `placeSymbol` takes an optional `transform`, used instead
  of `placementTransform` when given. Still one compound, one undo step,
  the permissions checked before allocation (09b D6).
- The tool asks the shell's `WallBands` (the one the Wall and Opening tools
  share) for the walls; the face cache (D3) lives in the tool.

### D7 — The Symbol section and the size menu (09c-2)

**When:** exactly one selected key, chain-free, whose target is a
root-level `InstanceNode` whose definition carries a `SymbolComponent`
(F-11's rule, for a symbol). The layer picker stays below it.

**Rows:**
- **Name** (read-only): the component's `name`.
- **Size** (read-only): `W × D` of the local box (D2), in mm, the panel's
  number format.
- **Rotation** (editable, degrees, `[0, 360)`): `θ = atan2(−c, d)` of the
  instance transform `(a, b, c, d, e, f)` (the local `y` column, so a
  mirror does not add 180°). A commit sets `θ'` about the **insertion
  point** (the image of the definition's base point), keeping the mirror;
  a multiple of 90° uses the exact table (F-2). Any finite number is
  accepted and taken modulo 360; anything else reverts.
- **Mirror** (a button): flips the local `x` about the box's centre `x`,
  in place (D4's mirror).
- **Size menu**: the family's members (D9), labelled by their `W × D`,
  sorted by `W` then `D`; the current one checked. Hidden when the
  instance's key has no family or the library is not ready.

**A size change** (decision 9): the chosen entry's definition (reused or
copied, D10, the placer's own reuse-or-copy path) replaces the instance's,
and the transform is recomputed so that the new box's back-left corner
`(left', back')` lands where the old `(left, back)` was, with the same
rotation and mirror. One `CompoundCommand` labelled `Change size`: the
copy's commands when needed, then **`SetInstanceDefinitionCommand(handle,
definition)`** (new, engine: refuses a missing node, a node that is not an
instance, a missing definition, and a cycle through `tree.replaceNode`;
capability `structure`; inverse restores the previous definition;
`touched: {handle}`), then `TransformNodeCommand`. The old definition
stays in the document (unused, as in CAD).

Rotation and Mirror commit one `TransformNodeCommand`, labelled `Rotate`
and `Mirror`. Every row is read-only when the permissions deny the commit's
capabilities (F-11).

### D8 — The wall-aware move (09c-2)

**The seam (render layer).** `SelectTool({MoveResolver? moveResolver})`.

```dart
abstract interface class MoveResolver {
  /// For a body drag of exactly one root-level node, the transform the
  /// node should take instead of `delta · node.transform`, or null to keep
  /// the plain move. Called on every retarget, with the raw pointer and
  /// the camera scale; never for a rotation, a reshape or a multi-key drag.
  Transform2? resolveMove(DraftDocument document, Handle node,
      Vector2 rawPointer, Transform2 delta, double scale);
}
```

- `GripDrag` gains `moveToTransform(Transform2 delta)`: the drag's
  transform is set outright (a translation-only `moveTo` is unchanged). The
  tool hands the resolver's result as `delta = T' · node.transform⁻¹`, so
  the preview (`selectionPreviewTransform`) and `ctx.grips?.carry(t)` stay
  delta-based (F-10) and the commit stays `TransformNodeCommand(h, delta ·
  node.transform) = T'`.
- Without a resolver, or when it returns null, every path is today's
  bit for bit.

**The app's resolver** (`symbol_move.dart`): for a root-level instance
whose key's library entry carries `against-wall`, with object snap on and
the library ready, it calls `attachToWall` (D4) with the raw pointer, the
instance's local box, **its current mirror** (the sign of `ad − bc`), and
the neighbours less itself; else null.

### D9 — Content

Code-drawn, in the catalog's style (`_rect`, `_inset`, lines, circles,
arcs); no imported content, no licence question. New keys:

| Family tag | Members (key: W × D mm) | New |
|---|---|---|
| `family:bed-double` | `bed.double.1400` 1400 × 2000, `bed.double` 1600 × 2000, `bed.double.1800` 1800 × 2000 | 2 |
| `family:bed-single` | `bed.single.800` 800 × 2000, `bed.single` 900 × 2000, `bed.single.1000` 1000 × 2000 | 2 |
| `family:wardrobe` | `bed.wardrobe.1200` 1200 × 600, `bed.wardrobe` 1800 × 600, `bed.wardrobe.2400` 2400 × 600 | 2 |
| `family:kitchen-base` | `kitchen.base.300`, `.400`, `kitchen.base.600`, `.800`: W × 600 | 3 |
| `family:desk` | `office.desk.1200` 1200 × 700, `office.desk` 1400 × 700, `office.desk.1600` 1600 × 700 | 2 |
| `family:sofa` | `sofa.two` 1500 × 900, `sofa.three` 2000 × 900 | 1 |
| — | `kitchen.dishwasher` 600 × 600, `kitchen.washer` 600 × 600 (Kitchen) | 2 |

**14 new, 41 in all.** A family's members share depth and front/back
convention, so a size change against a wall keeps the back on the face.
Each new symbol's base point is off the origin (09a's rule).

**`against-wall`** goes on: every bed, the nightstand, every wardrobe,
every kitchen base unit, the sink, the hob, the fridge, the dishwasher, the
washer, both sofas, the TV unit, the toilet, the washbasin, the tub, the
shower tray, every desk, the bookshelf. Not on: the dining tables, chairs
and bench, the island, the armchair, the coffee table, the office chair.

The asset is regenerated by the generator (09a); "the committed bytes
equal the built library" stays the gate.

### D10 — Leaf-equal reuse (09 D14, debt)

A definition found by key and version (F-3) is reused only when it is
**leaf-equal** to the entry: the same base point, the same number of live
leaves, and pairwise (ascending handle on both sides) the same kind, the
same payload coordinates and scalars, and the same style fields (layer,
linetype, colour, lineweight, transparency, flags, linetype scale), all
compared with exact `==` (stored values). A definition that is not
leaf-equal is passed over (the search goes on to the next handle); when
none qualifies, the entry is copied beside it under the `#n` name rule.
The placement and the size change (D7) both go through this.

### D11 — A removed definition takes its components (R-T2-2, debt)

- `ComponentRegistry` gains `snapshotOf(Handle h)` (every registered
  component on `h` and every unknown payload, in type-id order) and
  `restore(Handle h, snapshot)`.
- `RemoveDefinitionCommand` takes the snapshot, detaches every component on
  the handle, removes the definition; its inverse re-adds the definition
  and restores the snapshot, byte-identically (`toJson` before remove ==
  after undo). Capability: `structure` plus `components` when the
  snapshot is not empty (the placer's undo needs nothing new: it already
  clears the component first, F-3).
- An orphan already in a file is left alone (no load-time repair);
  `validate()` is unchanged.

### D12 — The ghost follows a wheel zoom (R-B6-3, debt)

The placement tool keeps the last pointer's **screen** point and, while
the ghost is visible, listens to the camera; a camera change re-resolves
from that screen point (the snap, the grid and the wall attachment, D6),
as `PlacementTool` does (F-8). The listener is removed when the ghost
hides, on `cancel` and on `dispose`.

### D13 — The search text survives a tab switch (R-B9-2, debt)

The shell owns the search field's `TextEditingController` and hands it to
`SymbolPanel`, which no longer creates or disposes it. The panel is still
removed on the Tools tab (no hidden rebuilds, R-B9-2's cost). The text
survives a tab switch and a document change; a new app starts empty.

### D14 — Known limits

- A symbol attaches in front of a door or a window (D3).
- A placed symbol does not follow its wall (decision 4).
- A run shorter than the symbol does not attach it (D4 step 2), even when
  the user would accept an overhang.
- A scaled instance from a file shows its unscaled size and is not
  attached by a move (`ad − bc` is used for the mirror only).
- An unused definition stays after a size change, as after any undo of a
  placement's instance alone; purge does not remove definitions.
- The tags are read from the library: before it is ready, a placed symbol
  neither attaches on a move nor offers sizes.

## Architecture

### Files

| File | Plan | Change |
|---|---|---|
| `packages/jet_cad_2d/lib/src/document/{component,commands}.dart`, `jet_cad_2d.dart` | 09c-1: D11; 09c-2: D7's command | engine |
| `packages/jet_cad_2d_flutter/lib/src/{select_tool,grip_drag}.dart`, `jet_cad_2d_flutter.dart` | 09c-2 | D8's seam |
| `apps/floor_planner/lib/symbols/{symbol_box,wall_attach}.dart` (new) | 09c-1 | D2–D4 |
| `apps/floor_planner/lib/symbols/{symbol_placer,symbol_ghost,symbol_place_tool,symbol_library,symbol_panel,furniture_catalog}.dart`, `assets/library/furniture.jetlib` | 09c-1 | D5, D6, D9, D10, D12, D13 |
| `apps/floor_planner/lib/main.dart` | both | D6 (bands to the tool), D13; 09c-2: D8 wiring |
| `apps/floor_planner/lib/symbols/{symbol_section,symbol_move}.dart` (new), `selection_panel.dart` | 09c-2 | D7, D8 |
| `roadmap/09-symbol-library.md`, `roadmap/00-README.md` | at merge | status rows |

### Invariants

- **No per-entity allocation on the frame path:** the ghost paints through
  the reused matrix (D5); the face cache and the neighbour lists are built
  on a document change, not on a paint. The two allocation invariant tests
  stay unedited and green.
- **Draw order is ascending handle:** a copy's leaves keep the library's
  ascending order (09a); a size change adds no leaf to an existing
  definition.
- **Tolerance for decisions, exact `==` for stored values:** capture, the
  run's length test, edge snaps and the neighbour test use the
  tolerances named in D3 and D4; leaf-equality (D10), the ghost's
  recompute test (D5) and the snapshot's round trip (D11) are exact.
- **No schema change.** Files written by 09c open in 12b's build except
  for definitions of the new keys, which 12b also reads (a definition is a
  definition).

## Testing

The degenerate fixtures this feature invites, and what replaces them:

- **An axis-aligned wall** (cos, sin ∈ {0, ±1}) hides a wrong rotation: the
  attachment fixtures use a wall at **30°** and one at **−112.5°**, inside a
  group with a non-identity transform, far from the origin
  (`(1e5, −7e4)`).
- **A centre-justified wall** hides a swapped face offset: every
  justification, and both faces.
- **A symbol symmetric front-to-back** hides `back = minY`: the fixtures
  use the toilet (cistern at the back) and a test symbol whose base point
  is off-centre in both axes.
- **An unmirrored instance** hides a mirror lost on attach, on a move and
  on a size change: each is tested mirrored and not.
- **An L corner of equal thicknesses** hides "centreline end" for "drawn
  face end": the corner fixtures use 100 and 240 mm walls.
- **A size change at the identity** hides a wrong anchor: tested at 30°,
  mirrored.

Test groups: `wall_attach_test.dart` (D3, D4: faces, runs, T split,
capture, side, orientation, edge snaps, clamp, null cases), `symbol_box_test`
(D2, arcs' true bounds), placer (D5, D10), the tool (D6, D12), the panel
(D13), the catalog and loader (D9, R03d), the engine
(`definition_commands_test.dart`: D11; `instance_definition_test.dart`:
D7's command), the render seam (`select_tool_move_resolver_test.dart`: D8,
including "no resolver: bytes and commands identical"), the section
(D7), the resolver (D8), and one end-to-end test per plan (place against
a 30° wall, save, load, bytes equal; 09c-2: move to another wall, change
the size, rotate, mirror, undo four times, redo).

## Named mutants

Each must go red; the plan names the red test.

| Id | Mutant |
|---|---|
| M-09c-a | attachment ignores the `against-wall` tag (an island attaches) |
| M-09c-b | the back is `minY` (`front`) instead of `maxY` |
| M-09c-c | the rotation keeps the quarter turns instead of the wall's `t` |
| M-09c-d | always the left face (the pointer's side ignored) |
| M-09c-e | `isUsableHost` dropped (a hidden or locked wall hosts) |
| M-09c-f | the run is the centreline `[0, len]`, not the drawn caps |
| M-09c-g | a T obstacle ignored, or applied to both faces |
| M-09c-h | no neighbour edge snap |
| M-09c-i | no clamp to `[W/2, L − W/2]` |
| M-09c-j | the mirror dropped while attached |
| M-09c-k | `R` turns the attached ghost |
| M-09c-l | attachment with object snap off |
| M-09c-m | `W ≤ L` test dropped |
| M-09c-n | `-0.0` not normalised in the generalised transform |
| M-09c-o | `GhostMatrix` recomputes on every update (count) |
| M-09c-p | leaf-equality ignores a payload scalar / a style field / the base point (each) |
| M-09c-q | `RemoveDefinitionCommand` does not restore the snapshot on undo |
| M-09c-r | the snapshot skips unknown payloads |
| M-09c-s | the camera listener not added (wheel zoom) / not removed (dispose) |
| M-09c-t | the panel creates its own controller again |
| M-09c-u | a size change anchors the base point instead of the back-left corner |
| M-09c-v | a size change copies the definition when one is reusable |
| M-09c-w | `SetInstanceDefinitionCommand` undo keeps the new definition |
| M-09c-x | the rotation row reads `atan2(b, a)` (mirror adds 180°) |
| M-09c-y | Rotate pivots about the box centre / the origin |
| M-09c-z | the resolver applied to a multi-key drag |
| M-09c-aa | the preview uses `T'` instead of the delta |
| M-09c-ab | the resolver's own instance counted as its neighbour |
| M-09c-ac | a second `family:` tag accepted by the loader |

## Exit gate

Each plan ends green on the CLAUDE.md gates (engine, render, app tests,
analyze, format; `flutter build web --release`; `dev_harness_2d` analyze),
with `CI=true`, the two allocation invariant tests unedited, no
`analysis_options.yaml` staged, every named mutant of the plan red with its
file restored (`diff` exit 0), a results note in `docs/superpowers/notes/`
and the ledger archived as the branch's last commit.

**The human's look (never marked done for them), macOS and web (Chrome,
Firefox), light theme:**

09c-1:
- a bed, a wardrobe, a kitchen unit, a toilet dropped near a wall face lands
  flush, turned to it, on both faces, on a wall at an angle;
- an inside corner and an outside corner; a T; a run of kitchen units
  started at a corner, each snapping to the previous one;
- the ghost stays within the face; leaving the face frees it;
- `M` while attached; `R` while attached does nothing visible, then applies
  off the wall; F3 off disables attachment;
- a symbol not tagged (a dining table, the island) does not attach;
- a wheel zoom with the ghost visible: the ghost stays under the pointer;
- the search text kept across a tab switch;
- the 14 new symbols' thumbnails and drawings (the hob's 520 mm depth is
  shorter than the 600 mm units: a content point to judge);
- a plan saved before 09c opens, its symbols unchanged.

09c-2:
- the Symbol section for one symbol: name, size, rotation, mirror, size
  menu; hidden for two;
- a size change against a wall keeps the back and the left side; mirrored;
- rotation typed (45, 90, 370, −90); mirror in place;
- dragging one tagged symbol along a wall, then to another wall; a
  multi-selection drag does not attach;
- every change one undo step.
