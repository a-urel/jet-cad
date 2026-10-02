# Wall-aware symbols and the Symbol section (09c) — design

**Date:** 2026-10-02. **Status:** design, **revision 2**. Revision 1
(`24feacb`) was reviewed independently: "Ready with amendments", 2
blocking, 6 major, 7 minor, 1 nit (W-1 to W-17,
[the review](../notes/2026-10-02-wall-aware-symbols-spec-review-r1.md)),
each applied; see [Revision 2](#revision-2).
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
  right face, `endCap` from the right face to the left; a node owner's cap
  also has interior points on neither face). `obstaclesOf` gives the
  intervals other walls occupy, for a T **and for an X**, as
  `({a, b, wall})` **without the side** (it computes the near face at
  `opening_geometry.dart:144` and drops it); `stretchesOf` clips to the
  straight span `[uS, uE]`, not to a face's drawn extent.
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
| `WallBands.liveWalls`; `Obstacle`'s side (D3, D6) | app | `lib/parametric/wall_bands.dart`, `lib/parametric/opening_geometry.dart` |
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
against, in world space:
- `m`, the unit normal that points **out of the wall into the room**;
- **`t = (−m.y, m.x)`**, the unit direction along it: the right hand of a
  person in the room facing the wall, so a symbol's local `+x` (its right
  seen from its front) runs along `t`;
- `a`, the run's end with the smaller `(·)·t`, and `L`, its length;
- `w`, the wall's **world** thickness: the distance between its two faces
  mapped through the group transform (under a scaled group this is not
  `WorldWall.t`, which is unscaled, W-10).

The rule is stated in terms of `m` and `t` only; which of `±d` a face's `t`
is depends on the group's mirror and is never assumed.

- **Candidates:** the walls that pass `isUsableHost` (F-6) and are not
  degenerate, enumerated through a new public `WallBands.liveWalls(doc)`
  (D6). A wall gives its **left** face (offset `lOff` along `n`) and its
  **right** face (`rOff`, along `−n`), each mapped to world.
- **A face's drawn extent** (F-7, W-9): in the wall's `HostFrame`, the
  **left face runs from `startCap.first` to `endCap.last`**, the **right
  face from `startCap.last` to `endCap.first`** (the outline ring is
  `[...endCap, ...startCap]`; a node owner's cap has interior points on
  neither face, which are not used). An L corner's inside face is
  therefore shorter than its centreline, an outside face longer.
- **Other walls cut a face** (W-4), from `obstaclesOf`'s data directly and
  **never through `stretchesOf`** (which clips to the straight span
  `[uS, uE]`, not to the drawn face):
  - **a T** (an end `k` of wall B strictly inside the host) cuts only the
    face it butts: the **left** face when `End(B, k).a · n > 0` (B's body
    lies on the host's left), else the right face;
  - **an X** (a crossing) cuts **both** faces.
  `Obstacle` gains a side field (`left`, `right` or `both`), set where
  `obstaclesOf` already computes the near face (`opening_geometry.dart:144`)
  and ignored by 08's existing call sites; a cut removes `[a, b]` from the
  face's extent, and pieces no longer than `wallJoin.linear` are dropped.
- **Openings do not cut a face** (non-goal): a wardrobe may stand in front
  of a door.
- **Cost:** the runs are computed per wall from `wallsInDocument` and
  cached against `WallBands.generation`, which `liveWalls` keeps current
  (D6): recomputed only when the document changes. A pointer move over a
  cached set is O(runs) and allocates nothing.

### D4 — `attachToWall`: the one rule

`attachToWall(runs, box, p, captureWorld, {mirrored, neighbours,
edgeCaptureWorld})` returns the attached transform and the face point `q`,
or null. Pure, in `wall_attach.dart`; the placement tool (D6) and the move
resolver (D8) call it, and only through it. `p` is the **anchor point**: the
pointer in placement (D6), the plain-moved insertion point in a move (D8).

1. **The face.** For each run, `s = (p − a)·m` (the signed distance from
   the face, positive in the room) and `u = (p − a)·t`. A run is a
   candidate when `−w/2 ≤ s ≤ captureWorld` and `−captureWorld ≤ u ≤ L +
   captureWorld`: `p` in the room near the face, or inside the wall's body
   on this face's half of the band. This splits at the band's **midline**
   for every justification (the door-swing rule, 08 Ruling 08-23). The
   winner, in order (W-3): the smallest `|s|`; then the smallest distance
   from `u` to `[0, L]` (0 inside the run), so at a T or a straight joint
   the piece `p` is over wins; then the lower wall handle; then the left
   face; then the lower `a·t`. None: null.
2. **The run must hold the symbol:** `W ≤ L + wallJoin.linear`. A shorter
   run: null (the ghost stays free).
3. **The orientation** is the proper rotation `R` that takes local `+y`
   (towards the back) to `−m` (into the wall), hence local `+x` to `t`:
   `cos = t.x = −m.y`, `sin = t.y = m.x`, exactly those doubles, `-0.0`
   normalised to `0.0` as F-2 does.
4. **Along the face**, the symbol's centre goes at `u`, then:
   - **edge snaps**, each when the side it moves is within
     `edgeCaptureWorld` of its target: the left side (`u − W/2`) to the
     run's start `0`; the right side (`u + W/2`) to its end `L`; the left
     side to a neighbour's right end; the right side to a neighbour's left
     end. The candidate needing the smallest shift of `u` wins; a tie goes
     to the smaller resulting `u`;
   - **clamp:** the centre is then clamped to `[W/2, L − W/2]`.
5. **The transform** is `translate(q)·R·S·translate(−c)` with `S =
   scale(−1, 1)` when mirrored (plain, **no pivot of its own**: after
   `translate(−c)` the box is centred on local `x = 0`, so the mirror
   pivots about the box's centre `x` and the footprint does not move, W-7),
   `c = ((left + right)/2, back)` the local back-centre, `q = a + u·t`. It
   is exactly `placementTransform(at: q, basePoint: c, rotation: (cos,
   sin), mirrored)` of D5. The back edge lies on the face line, the front
   in the room. Note that this mirror pivot (the box centre) differs from
   free placement's (the base point, F-2); every catalog symbol's base
   point is on its box's centre `x` (verified by a catalog test), so the
   two agree on today's content.

**Neighbours** (decision 3) are the placed symbols standing against the
same run: root-level instances on a visible, unlocked layer (the picking
rule) whose definition carries a `SymbolComponent`, whose transform is
orthonormal (W-8), whose transformed local back edge has both ends on the
run's line (distance at most `wallJoin.linear`) with their front on the
room side, and whose interval `[uLeft, uRight]` along `t` (the projection
of both back-edge ends, in whichever order a rotation or a mirror leaves
them) **overlaps `[0, L]`** (W-14). They are found from the root instances
once per run per cache generation (D6); the instance being moved (D8) is
excluded.

`captureWorld` is `kWallAttachPixels / scale`, `kWallAttachPixels = 16.0`
(larger than the snap aperture: in placement the pointer is often the
symbol's centre, far from its back); `edgeCaptureWorld` is
`kSnapAperturePixels / scale`.

### D5 — The placement transform, generalised

- `placementTransform` gains a rotation given as a unit vector `(cos,
  sin)`; the quarter-turn form stays and calls it with the exact table.
  Both normalise `-0.0`.
- The placement tool computes the ghost's transform on pointer, key and
  camera events and keeps it in a field (W-15); `paintWorldOverlay` passes
  the stored value. `GhostMatrix.update(placement: Transform2)` compares
  its six doubles with the last ones exactly and recomputes nothing when
  they are equal; its `computations` count stays (09b's tests move to the
  new signature). No `Transform2` is built in a paint.

### D6 — The placement tool attaches

- After `_resolve` (F-8), when the armed entry carries `against-wall`,
  object snap is on, and `attachToWall` (D4) with `p` = the **raw**
  pointer returns a result, the ghost and the release use **that**
  transform; otherwise today's `placementTransform(at, turns, mirror)`.
- **Keys while attached** (decision 5): `M` toggles the mirror, which D4
  applies; `R` and `Shift+R` change the turn count only.
- **The marker:** while attached the snap marker is drawn at `q` (D4), the
  point on the face, as the opening tool draws its marker on the centreline
  (08 Ruling 08-14).
- **The commit:** `placeSymbol` takes an optional `transform`, used instead
  of `placementTransform` when given. Still one compound, one undo step,
  the permissions checked before allocation (09b D6).
- **The walls** (W-5): the tool reads the shell's `WallBands` (the one the
  Wall and Opening tools share) through a new public
  `WallBands.liveWalls(doc)`, which runs the private refresh (and so starts
  the document subscription) and returns the live walls' handles in
  ascending order; it is called on each pointer event, so a session that
  never used the Wall or Opening tools still sees current walls. The tool
  calls `bands.invalidate()` after its own commit (Ruling 08-13's "and at
  every click"), so the next unit of a kitchen run sees the previous one at
  once, before the change stream delivers. The face and neighbour cache
  (D3, D4) lives in the tool and is keyed on `bands.generation`.

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
  mirror does not add 180°). A commit **composes**: the linear part `A` of
  the transform becomes `R(θ' − θ)·A`, about the **insertion point** (the
  image of the definition's base point), so a mirror and any scale from a
  file are kept (W-8); when the result is orthonormal and `θ'` is a
  multiple of 90°, the exact table (F-2) is used. Any finite number is
  accepted and taken modulo 360; anything else reverts.
- **Mirror** (a button): composes `scale(−1, 1)` in the **local** frame
  about the box's centre `x` (`T·translate(cx, 0)·scale(−1, 1)·
  translate(−cx, 0)`), so the footprint does not move and a scale is kept.
- **Size menu**: the family's members (D9), labelled by their `W × D`,
  sorted by `W` then `D`; the current one checked. Hidden when the
  instance's key has no family or the library is not ready.

**A size change** (decision 9): the chosen entry's definition (reused or
copied, D10, the placer's own reuse-or-copy path) replaces the instance's,
and the transform is recomputed so that the new box's back-left corner
`(left', back')` lands where the old `(left, back)` was, with the same
linear part. One `CompoundCommand` labelled `Change size`: the copy's
commands when needed, then **`SetInstanceDefinitionCommand(handle,
definition)`** (new, engine: refuses a missing node, a node that is not an
instance, a missing definition, and a cycle through `tree.replaceNode`;
capability `structure`; inverse restores the previous definition;
`touched: {handle}`), then `TransformNodeCommand`. The old definition
stays in the document (unused, as in CAD).

**Permissions** (W-12). Rotation and Mirror commit one
`TransformNodeCommand` (labels `Rotate` and `Mirror`), which needs
`transform`; the runtime permissions allow it (`command.dart:56-57`), so
**these two rows stay editable under runtime permissions**, unlike the
parametric sections (F-11), which commit components. The Size menu is
enabled only when the worst case is allowed: `{structure, geometry,
components, transform}` (a copy), as the placement tool checks its needs
before allocating (09b D6). Read-only otherwise.

**The caches** (W-13): no command has changed an instance's definition
before (F-5). A render-layer test pins that after a size change, its undo
and its redo, the outline bounds, the pick and the painted tile follow the
new definition, and that a later edit to the new definition's leaves
propagates.

### D8 — The wall-aware move (09c-2)

**The seam (render layer).** `SelectTool({MoveResolver? moveResolver})`.

```dart
abstract interface class MoveResolver {
  /// For a body drag of exactly one root-level node, the transform the
  /// node should take instead of `delta · node.transform`, and the point
  /// to mark, or null to keep the plain move.
  ({Transform2 transform, Vector2 marker})? resolveMove(
      ToolContext ctx, Handle node, Transform2 delta);
}
```

- **When it is asked** (W-6): only during a drag that began from
  `PressClass.selectedBody` or `unselectedBody` (never a grip, a rotation
  or a reshape), when `GripDrag.singleNode` (new: the node handle when the
  drag captured exactly one `_NodeCapture` and nothing else, else null) is
  non-null, and when Shift is up. With Shift down the plain, ortho move
  applies. It receives the whole `ToolContext` (document, index, camera,
  snap settings) and the plain move's delta (the translation the snap
  chain gave).
- **The commit is exact** (W-2): `GripDrag.moveToTransform(Transform2
  delta, Transform2 exact)` stores `exact` (`T'`) for the single capture
  and sets the drag's transform to `delta = T' · node.transform⁻¹` for the
  preview (`selectionPreviewTransform`) and for `ctx.grips?.carry`.
  `command()` then emits `TransformNodeCommand(h, T')` **verbatim**, and is
  a no-op only when `T' == node.transform` (exact), not when the target
  equals the base: an attached drag released at its press point still
  turns the symbol. `_revalidate` and the camera retarget are unchanged.
- **The guide and the marker:** while attached the snap marker is drawn at
  the resolver's `marker` and the guide runs from the base to it.
- Without a resolver, or when it returns null, every path is today's
  bit for bit (a test compares the command, the bytes and the preview).

**The app's resolver** (`symbol_move.dart`): for a root-level instance
whose key's library entry carries `against-wall`, with
`ctx.snap?.objectSnap` on and the library ready, and whose transform's
linear part is **orthonormal within `Tolerance`** (else null: a scaled
instance from a file is never attached, so its scale is never dropped,
W-8), it calls `attachToWall` (D4) with `p` = **the plain-moved insertion
point** `delta · node.transform · basePoint` (W-6: a sofa grabbed at one
end does not jump to put its centre under the cursor; in placement the
pointer **is** the insertion point, so this is "as in placement"), the
instance's local box, its current mirror (the sign of `ad − bc`), and the
neighbours less itself; its `marker` is D4's `q`.

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
equal the built library" stays the gate. Catalog tests pin that every
member of a family shares `D`, `front` and `back` (W-16), that each
`against-wall` symbol is in the list above, and that every symbol's base
point lies on its box's centre `x` (D4 step 5).

### D10 — Leaf-equal reuse (09 D14, debt)

A definition found by key and version (F-3) is reused only when it is
**leaf-equal** to the entry (W-11): the same base point; no child nodes;
the same number of live leaves; and pairwise, ascending handle on both
sides, **every `EntityRecord` field except `handle`, `owner` and
`geomIndex`** (the placer rewrites the first two, `AddEntityCommand` the
third: kind, layer, linetype, colour, lineweight, transparency, flags,
linetype scale, text, tag, text style, text attributes), and the same
payload coordinates and scalars. All compared with exact `==` (stored
values; `==` equates `-0.0` and `0.0`, which is accepted). A definition
that is not leaf-equal is passed over (the search goes on to the next
handle); when none qualifies, the entry is copied beside it under the `#n`
name rule. The placement and the size change (D7) both go through this.

### D11 — A removed definition takes its components (R-T2-2, debt)

- `ComponentRegistry` gains `snapshotOf(Handle h)` (every registered
  component on `h` and every unknown payload, in type-id order) and
  `restore(Handle h, snapshot)`.
- `RemoveDefinitionCommand` takes the snapshot, detaches every component on
  the handle, removes the definition; its inverse re-adds the definition
  and restores the snapshot, byte-identically (`toJson` before the remove
  equals `toJson` after the undo).
- **Capabilities are static** (W-1): the dispatcher checks a command's
  `capabilities` before `apply` (`undo.dart:187-193`, `:287-291`), when the
  snapshot is not yet known. So the forward command declares
  `{structure, components}`; its summary `capability` (what `SpatialIndex`
  reads) stays `structure`. The inverse is built after the snapshot is
  taken and declares `{structure}`, plus `components` when its snapshot is
  not empty.
- The placer is unaffected under every permission set: its forward
  compound already needs `components` (P17 still refuses before anything
  applies) and its inverse already holds the `SetComponentCommand(null)`
  inverse, so the definition's snapshot is empty by then.
- **SC12** (`symbol_component_test.dart:257-274`) asserts today's
  behaviour (the component survives the command) and is rewritten to the
  new one; the engine's `capability == structure` assertions
  (`definition_commands_test.dart:165-184`) stay valid.
- An orphan already in a file is left alone (no load-time repair);
  `validate()` is unchanged.

### D12 — The ghost follows a wheel zoom (R-B6-3, debt)

The placement tool keeps the last pointer's **screen** point and, while
the ghost is visible, listens to the camera; a camera change re-resolves
from that screen point the snap, the grid **and the wall attachment** (D6,
whose capture is in screen pixels), as `PlacementTool` does (F-8). The
listener is removed when the ghost hides, on `cancel`, on a disarm and on
`dispose`.

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
- A scaled instance from a file shows its unscaled size in the Size row
  and is never attached by a move (D8's orthonormal test); Rotation and
  Mirror keep its scale (D7).
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
- **No schema change.** A file written by 09c opens in 12b's build: the
  new keys are ordinary definitions and the tags are strings in
  `SymbolComponent`'s existing fields. D11 changes what a save writes
  after a definition is removed (no orphan component), not the format.

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
- **A rotated, translated group** hides a mirror- or scale-dependent face
  rule (W-10): the attachment fixtures also put walls in a **mirrored**
  group and a **scaled** group (`w` then differs from `WorldWall.t`).
- **One wall at a time** hides the tie rule and the neighbour overlap: a T
  fixture with the pointer 1 px right of the stem (W-3), a neighbour
  rotated 180°, and a back-to-back symbol on the opposite face (W-14).
- **A fresh shell** hides the stale wall cache (W-5): a test places two
  units in a shell where no Wall or Opening tool ran; the second snaps to
  the first.
- **The exact-commit and `-0.0` rules** (D4 step 3, D8): M-09c-n can only
  go red on an **axis-aligned** wall (`cos = −m.y = −0.0`), so its test is
  the one named exception to the 30° rule; the exact-commit test (M-09c-ad)
  is at 30° far from the origin, comparing bytes.

Test groups: `wall_attach_test.dart` (D3, D4: faces, runs, T split,
capture, side, orientation, edge snaps, clamp, null cases), `symbol_box_test`
(D2, arcs' true bounds), placer (D5, D10), the tool (D6, D12), the panel
(D13), the catalog and loader (D9, R03d), the engine
(`definition_commands_test.dart`: D11; `instance_definition_test.dart`:
D7's command), the render caches after a size change (D7, W-13), the render seam (`select_tool_move_resolver_test.dart`: D8,
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
| M-09c-g1 | a T obstacle ignored |
| M-09c-g2 | a T obstacle applied to both faces |
| M-09c-g3 | an X obstacle applied to one face only |
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
| M-09c-ad | the move commits `delta · node.transform` instead of `T'` verbatim (W-2) |
| M-09c-ae | an attached move released at its press point commits nothing (the old `target == base` no-op) |
| M-09c-af | the face tie rule without the distance-to-`[0, L]` key (W-3) |
| M-09c-ag | a face's extent from the wrong cap end (`startCap.last` for the left face) (W-9) |
| M-09c-ah | `s ≥ −w` / `s ≥ 0` in place of `s ≥ −w/2` (each) |
| M-09c-ai | arc bounds from the end points only (the toilet's front) |
| M-09c-aj | `RemoveDefinitionCommand`'s forward capabilities without `components` (W-1) |
| M-09c-ak | the wheel-zoom re-resolve skips the wall attachment |
| M-09c-al | the Rotation row's commit drops the mirror / the scale (each) |
| M-09c-am | a scaled instance attaches on a move (W-8) |
| M-09c-an | the move resolver anchors on the raw pointer instead of the plain-moved insertion point (W-6) |
| M-09c-ao | the resolver consulted with Shift down, or for a grip drag (each) |
| M-09c-ap | the tool does not `invalidate()` the bands after its commit (W-5) |
| M-09c-aq | a neighbour outside `[0, L]` counted (W-14) |
| M-09c-ar | a family member with a different depth (the catalog test, W-16) |

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

## Revision 2

Every finding of the
[revision 1 review](../notes/2026-10-02-wall-aware-symbols-spec-review-r1.md)
is applied; no decision of the human's was reopened.

- **W-1 (blocking):** D11's capabilities are static: the forward command
  `{structure, components}`, the inverse from its snapshot; SC12 is
  rewritten.
- **W-2 (blocking):** D8 commits `T'` verbatim through
  `GripDrag.moveToTransform(delta, exact)`; the no-op test is `T' ==
  node.transform`. M-09c-ad, M-09c-ae.
- **W-3:** D4 step 1 ranks by the distance from `u` to `[0, L]` after
  `|s|`. M-09c-af.
- **W-4:** D3 cuts faces from `obstaclesOf` directly, with a new side field;
  an X cuts both faces; `stretchesOf` is not used; F-7 corrected. M-09c-g
  split in three.
- **W-5:** `WallBands.liveWalls(doc)` and the tool's `invalidate()` after a
  commit (D6); a fresh-shell test. M-09c-ap.
- **W-6:** D8's resolver anchors on the plain-moved insertion point, takes
  the `ToolContext`, is consulted only for a single-node body drag with
  Shift up (`GripDrag.singleNode`), and names the marker and the guide.
  M-09c-an, M-09c-ao.
- **W-7:** D4 step 5's `S` is a plain `scale(−1, 1)`; the pivot difference
  from free placement is stated and pinned by a catalog test.
- **W-8:** a non-orthonormal instance never attaches; Rotation and Mirror
  compose with the existing linear part (D7, D8, D14). M-09c-al, M-09c-am.
- **W-9:** the face extents name their cap points (D3). M-09c-ag.
- **W-10:** D3 defines `w` as the world thickness and drops the `t = ±d`
  claim; mirrored and scaled group fixtures (Testing).
- **W-11:** D10's equality covers every record field but `handle`, `owner`
  and `geomIndex`, and no child nodes.
- **W-12:** D7 states that Rotation and Mirror stay editable under runtime
  permissions and gates the Size menu on the worst case.
- **W-13:** D7 requires the render-cache test after a size change.
- **W-14:** D4's neighbours overlap `[0, L]`, follow the picking filter;
  the 180° and back-to-back fixtures. M-09c-aq.
- **W-15:** D5 computes the transform on events, never in a paint.
- **W-16:** the missing mutants are added (M-09c-ad to M-09c-ar); the
  axis-aligned exception for M-09c-n is named; the family-depth catalog
  test is in D9.
- **W-17:** the invariant sentence rewritten; D4 step 2 names
  `wallJoin.linear`; the edge-snap tie is stated; D12 also removes the
  listener on a disarm.
