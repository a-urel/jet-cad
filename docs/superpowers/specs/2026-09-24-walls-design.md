# Walls — design

**Date:** 2026-09-24. **Status:** design, **revision 1**, not yet reviewed.
**Sub-project:** `roadmap/07-walls.md`. **Size:** L.
**Depends on:** 06 (merged at `a6837d0`): the parametric layer. 07 is its
first real client.
**Blocks:** 08 (openings), 10 (rooms and area).
**Brainstormed with the human on 2026-09-24**, on `main` at `22957d1`,
followed by a throwaway spike whose findings are the evidence for most
decisions below:
[2026-09-24-walls-spike-findings.md](../notes/2026-09-24-walls-spike-findings.md)
(branch `spike/07-walls` at `45aecb6`, never merged).

**Decisions the human made on 2026-09-24:**

| Question | Answer |
|---|---|
| What one wall object is | **One straight segment.** The tool chains clicks into several objects |
| The wall body | **Poché:** a closed outline with a fill |
| The band's look | **A solid band**, fill and outline in one colour; exactly three children per wall |
| Two or more wall ends at one point | **Angular neighbours:** corners where adjacent faces meet |
| A corner that cannot be built cleanly | **Mitre limit 4, then a bevel**; a parallel pair steps; a wall shorter than its corners squares its own ends |
| What a wall stores | **Both endpoints in group-local space**, thickness and justification; the group starts at the identity |
| When two endpoints are joined | **A named wall `Tolerance`, linear 1e-6**, absolute |
| Connectivity | **Derived in `generate`, never cached** — amends roadmap decision 4 |
| Curved walls | **Not in v1**, recorded |
| The Wall tool | **W, chained, one undo step per wall** |
| The panel | **Thickness and Justification**; each field pins its commit target when it gains focus |
| Endpoint edits | **End grips; joined ends follow.** A whole-wall move or rotate detaches |
| 06 debt taken | **The neighbour-search cost** and **the `_run` loop comment** |
| Further fields (height, colour, layer, material) | **None in v1** |
| Spike first? | **Yes**, geometry plus one end-to-end run |
| The 0.78% hole (spike) | **Accept it, and report it through `diagnostics()`** |
| Delivery | **Git bundles; never push** |

**Evidence of record.** Every claim about what exists was read from the tree
at `22957d1` on 2026-09-24. Each item gives its file and line.

- **06's planner** (`packages/jet_cad_2d/lib/src/parametric/regeneration.dart`):
  - `_survey` (36-72) computes every object's `reach` and **every pairwise
    overlap**, O(n²), and `_run` calls it **twice** per edit (181, 200),
    whenever any parametric component exists (`parametric_system.dart`
    `_expand`, 159-169);
  - `_plan` (101-136) matches children by `(kind, ordinal)`, rewrites a
    changed payload with `SetEntityGeometryCommand`, reserves added handles
    above the seed without advancing it, and removes surplus children;
  - `Generated` refuses `EntityKind.fill` (`parametric_system.dart:37-47`).
- **Fills** (`packages/jet_cad_2d/lib/src/document/commands.dart`):
  - a fill's payload is **one scalar, its boundary's handle** (622-625);
  - `SetEntityGeometryCommand` on a boundary **re-triangulates its fills**
    and refuses a fill itself (452-497);
  - `AddRegionCommand` adds a fill and its boundary as one mutation, **fill
    handle lower**, same owner, fillable boundary (505-643);
  - removing a boundary **removes its fill in the same mutation** (159-201);
  - `triangulationFor` returns an **empty** list for a closed polyline that
    crosses or touches itself; the painter then skips the fill
    (`triangulate.dart:27-82`, `commands.dart:652-669`).
- **The select tool's group delete** skips a fill whose boundary is also
  being removed (`jet_cad_2d_flutter/lib/src/select_tool.dart:652-681`).
- **Grips** are built only for root-owned leaves
  (`jet_cad_2d_flutter/lib/src/grip_cache.dart:263`); `GripDrag.command`
  reshapes only a leaf (`grip_drag.dart:188-229`). A group gets the box and
  the rotation grip.
- **Snap** offers `endpoint` and `nearest` among its nine kinds
  (`packages/jet_cad_2d/lib/src/index/snap.dart:23-33`).
- **The Selection panel** commits a field on its own focus loss to the box
  selected **at that moment** (`apps/floor_planner/lib/selection_panel.dart:69-73`)
  — 06's parked defect.
- **Tolerance.standard** is `linear: 1e-9` absolute
  (`packages/jet_cad_2d/lib/src/core/tolerance.dart:23`). At the measurement
  corpus's far origin (`generate_document.dart:29,34`: x = 4,500,000,
  y = 1,200,000) one ulp is about 9.3e-10.
- **The app** installs one system over `boxCatalog`
  (`apps/floor_planner/lib/main.dart:221`, `parametric/box.dart:127-133`).
  Tool keys V L P R B C A T are taken; **W is free** (`main.dart:83-133`).

## What this delivers

1. **Walls in the floor planner.** A wall is a straight centreline with a
   thickness and a justification, drawn as a solid band that **cleans up
   where it meets other walls**: mitred at an L, however thick and however
   justified; butted at a T; crossed at an X; a clean star at three or more
   ends. Moving or deleting a wall regenerates its neighbours in the same
   undo step.
2. **A Wall tool (W)** that draws a chained run, one wall per click.
3. **End grips** on a selected wall; dragging one moves every wall end
   joined to it.
4. **A Wall section in the right panel:** Thickness and Justification.
5. **Two changes to 06's engine mechanism:** generated **regions** (a fill
   and its boundary), and a **neighbour search** that no longer costs
   O(n²) twice per edit.

## Non-goals

- **Curved walls.** Straight only. An arc centreline would be a new
  parametric type later, not a change to this one.
- **Height, colour, layer, material.** None in v1. A later field arrives as
  an optional JSON key with a default.
- **Openings, rooms, dimensions:** 08, 10, 11.
- **Stretching joined neighbours on a whole-wall move or rotate.** That is
  03's group gesture and it detaches the wall.
- **Filling the 0.78% hole** (D6): reported, not repaired.
- **A spatial broad phase** for the neighbour search. D10 makes the cost
  O(k·n) per edit; a broad phase is only needed past thousands of walls.
- **Picking a zero-child box** (06's "ghost box") and **the fast path's
  store-length check.** Both stay recorded debt: walls never have zero
  children, and the fast path is off the frame path.

## Decisions

### D1 — Where walls live

- **The wall type is application code**, like 06's Box
  (`apps/floor_planner/lib/parametric/`), because a wall is product
  behaviour and the engine stays generic (`component.dart:12`).
- **Files:**
  - `wall.dart`: `WallParams`, `Justification`, `WallType`, `wallJoin`;
  - `wall_geometry.dart`: pure functions, **no Flutter import** — world
    walls, ends, joint classification, corners, outlines;
  - `wall_tool.dart`, `wall_grips.dart`;
  - `catalog.dart`: one `ParametricCatalog` holding both the Box and the
    Wall, and `installParametric(doc)`, replacing `installBoxes`.
- **Walls and boxes coexist.** They can be neighbours, which costs time
  only: each type's `generate` ignores the other's parameters.

### D2 — `WallParams`

- **Fields:** `start` and `end` (group-local, two doubles each),
  `thickness` (> 0), `justification` (`left`, `centre`, `right`).
- **`typeId`:** `floor_planner.wall`.
- **`toJson` key order:** `start`, `end`, `thickness`, `justification`.
  `start` and `end` are `[x, y]` lists; `justification` is its enum name.
- **Value-equal**, exact `==` on the doubles (a stored value).
- **Justification** says which side of the centreline the body lies on,
  looking from `start` to `end`: `left` puts the whole thickness on the
  left, `right` on the right, `centre` half each. The face offsets along the
  left normal are therefore `(t/2, −t/2)`, `(t, 0)` and `(0, −t)`.
- **`editCapability = geometry`**, as the Box.
- **A degenerate wall** — length ≤ `wallJoin.linear` or thickness ≤ 0 — is
  never produced by the tool or the panel, but `fromJson` accepts anything.
  Its `generate` emits the centreline only, and `diagnostics()` names it
  (D12).

### D3 — Generated children: three, fixed at creation

- **Every wall generates, in this order:**
  1. **a region** — a closed POLYLINE outline and a FILL that names it;
  2. **the centreline**, an open two-point POLYLINE from `start` to `end`.
- **All on layer 0, ByLayer** (06's `draftRecord`): a black band on white
  paper. The centreline is drawn in the same colour, so it is invisible
  inside the band but pickable and snappable.
- **Handles at creation** are fill < outline < centreline, reserved in
  generation order. **Regeneration only ever rewrites the outline** (and the
  centreline when an endpoint moves), in place, so a wall's handles and its
  draw order never change after creation. **06 D12's cost does not arise
  for walls.**
- **Picking** works through the centreline and the fill, which always exist
  (except for D2's degenerate wall). **06's "ghost" problem does not arise
  for walls.**
- **Roadmap decision 2 is kept in substance and changed in form.** The
  centreline is a real entity — snappable, pickable, indexable — but it is
  **generated** from `WallParams`, because 06's planner treats every child
  of a parametric group as generated and would remove any other.

### D4 — Joints, derived in `generate`

Amends **roadmap decision 4**: connectivity is geometric, as decided, but
**not cached**. 06 already hands `generate` exactly the neighbours it needs,
from one survey, so nothing re-queries the world; a cache would be derived
state in the file that can drift and must be undone.

- **World walls.** `generate` reads its own and each neighbour's
  `WallParams` and `toWorld`, and builds every world wall through **one
  function** of `(params, toWorld)`. Two walls computing the same neighbour
  therefore get the same bits. All joint geometry is computed in world
  space; the outline is then taken to group-local space through
  `toWorld(self).invert()`.
- **Classification**, per end, in this order:
  1. **T:** the end lies within `wallJoin.linear` of another wall's
     centreline, strictly inside it (more than `wallJoin.linear` from both
     of its ends). Several: the lowest handle.
  2. **Node:** at least one other wall end lies within `wallJoin.linear` of
     this end. **Membership is measured from the node's lowest-handle
     endpoint**, so every member computes the same set (spike finding 5).
  3. **Free** otherwise.
- **X** needs nothing: two walls whose centrelines cross in their interiors
  overlap, and the solid band hides it. Both stay rectangles.
- **`reach`** is the centreline's world AABB expanded by `wallJoin.linear`.
  Every joint is a centreline relation, so this is exactly what neighbour
  detection needs. It replaces 06's per-axis placeholder (06 D3, review
  m3). A long diagonal wall still has a large AABB: spurious neighbours cost
  time, never correctness.

### D5 — The node rule (spike: "the node rule that survived")

1. **Ends at a node** are sorted anticlockwise by the angle of their
   outgoing direction (pointing away from the node, along the wall). Ties:
   handle, then end index. Two ends in exactly one direction are two
   overlapping walls: each keeps a free cap.
2. **Each wedge** between consecutive ends *x → y* has **one corner**:
   *x*'s outgoing-left face ∩ *y*'s outgoing-right face. It is computed once
   per wedge, in that argument order, so both walls hold the same bits.
3. **Every wall's cap is the straight segment** between its right corner
   (the wedge before it) and its left corner (the wedge after it). **The
   node point is never an outline vertex** (spike: routing caps through it
   cut into bodies whenever a face runs through the node).
4. **Two ends** — the L — are done: the two caps are the same segment, the
   mitre, asymmetric in thickness and justification alike.
5. **Three or more ends** enclose a **central polygon**, the corners in
   anticlockwise order. It is split at exactly repeated vertices into lobes.
   Each lobe is owned by the **lowest-handle end whose cap is one of its
   edges**; the owner's cap walks the lobe from its left corner to its right
   corner instead of the straight segment. Every other wall's cap is one of
   the lobe's edges, so the band is watertight by construction.
6. **A lobe that is folded** (signed area ≤ 0) **or crosses itself** is
   dropped: every wall keeps its straight cap. A folded lobe means the caps
   already meet. A crossing lobe with positive area leaves a hole — D6.

### D6 — Clamps, and what is accepted

- **The mitre limit is 4**: a wedge's corner is too far when it lies more
  than `4 × ½ × the thicker wall's thickness` from the node point.
- **A wedge narrower than 90° is never clamped.** Its long inner mitre is
  real geometry, and clamping it produced overlap in the spike.
- **A wedge of 90° or more** whose corner is too far, or whose faces are
  parallel, is **clamped**: the corner is replaced by two **feet** — the
  left face's point at the node for *x*, the right face's point for *y*.
  The central polygon carries the bevel (a reflex wedge) or the step (a
  near-straight pair of different thickness or justification).
- **A T whose corners are too far** (a stem at a shallow angle) ends square
  at its own endpoint, inside the through wall's body.
- **A short wall.** If a wall's own outline is not simple and
  anticlockwise, **that wall alone** squares both ends at its own
  endpoints. Squaring its neighbours too would make B depend on C through a
  short A, a two-hop dependency that 06's one-hop closure does not
  regenerate (spike finding 1).
- **Outline simplification.** Consecutive exactly equal vertices and
  zero-width spikes (`a, b, a`) are removed before the outline is stored.
  Stored-value comparisons, so exact; zero area, so tiling is unchanged.
  Without it the triangulator refuses a pinched outline (spike: 485
  refusals before, 0 after).
- **The invariant:** every stored outline is a simple, anticlockwise,
  triangulable polygon. **The fill is never dropped.**
- **Accepted, measured, reported** (human, 2026-09-24):
  - **Holes:** 0.78% of plausible random 3–4-way nodes (spike Q5b) drop a
    crossing lobe and leave a visible hole. None of the 216 common plan
    nodes of spike Q2c does. `diagnostics()` names every such node (D12).
  - **Overlap:** clamped wide wedges and fallbacks overlap neighbouring
    bands, invisibly in an opaque one-colour band. Recorded for 08: a
    neighbour's fill can cover an opening cut near a joint.

### D7 — The join tolerance

- **`const wallJoin = Tolerance(linear: 1e-6, angular: 1e-9)`**, in
  `wall.dart`, absolute, as `Tolerance`'s own doc comment prescribes. It
  answers every "do these join" decision: endpoint coincidence, a point on
  a centreline, parallel faces.
- **Why not `Tolerance.standard`:** at the far origin one ulp is ~9.3e-10,
  and the spike's two rotated groups left a joint **4.656612873077393e-10**
  apart. 1e-6 is about a thousand ulps there and still far below anything a
  user draws on purpose. Snapping is what makes a user's endpoints meet.
- **Stored values stay exact:** `WallParams ==`, the planner's payload
  comparison, D6's simplification, and every round-trip assertion.

### D8 — The planner learns regions (engine)

- **`Generated.region(GeometryPayload boundary)`**: a closed POLYLINE and the
  FILL that names it. `Generated(kind, …)` still refuses `EntityKind.fill`.
- **`_plan`**, per object:
  - a fill child's boundary (its payload's one scalar) is matched **through
    the fill**, never as a plain POLYLINE;
  - the *i*-th generated region goes to the *i*-th fill child, ascending;
    a changed boundary is one `SetEntityGeometryCommand` on the boundary,
    which re-triangulates the fill; **the fill record is never rewritten**;
  - a missing region is one `AddRegionCommand` with two reserved handles,
    **fill first** (the command's own lower-handle rule);
  - a surplus region is removed **through its boundary**, whose removal
    takes the fill with it (removing the fill alone would orphan the
    boundary).
- **D6 (06) is unchanged** and covers both halves: fill and boundary are
  both children in G.
- **D11 (06) holds:** a changed outline is rewritten in place, no slot
  freed or reused.

### D9 — Draw order

- **Ascending handle value, unchanged.** Within a wall: fill, outline,
  centreline. Between walls: creation order. With one colour everywhere,
  no wall-over-wall order is visible.
- **No per-object draw pass** (06 D12's question): not needed, since a
  wall's children never change after creation (D3).

### D10 — Neighbour search: O(k·n) per edit (06 debt, engine)

- **`_survey` stops computing neighbours.** It computes the objects, each
  object's `reach` (one call per object), the children and G — O(n + E).
- **Neighbours are computed on demand**, per handle, against that survey's
  reach snapshot, and memoised in the survey: for the seeds (before and
  after) and for each closure member's `view.neighbours`. An edit with no
  seeds and no cleanup computes **no neighbours at all**. That covers a
  plain line drawn in a plan full of walls.
- **`drift()`** still asks for every object's neighbours: O(n²), off the
  edit path, unchanged in behaviour.
- **Measured before and after** at 100, 300 and 600 walls, for a plain line
  draw and a wall move, and recorded in the results note. 06's final review
  measured 0.7 / 4.3 / 16 ms before (JIT).
- **Pinned** by a test that counts overlap tests through a
  `@visibleForTesting` counter: a line draw among 300 walls performs 0;
  a wall move performs O(k·n), asserted as < 10 × n.
- **The `_run` loop gains its comment** (06 debt): it duplicates
  `CompoundCommand`'s rollback because it must tell its own rollback
  failure apart from a child's `StateError`.

### D11 — Tool, grips and panel (app and render layer)

**The Wall tool (W).**
- A `PlacementTool`. The first click sets a start; **each later click
  commits one wall** from the previous point, `Compound([AddNodeCommand(group
  at identity), SetComponentCommand<WallParams>(world start, world end,
  thickness, justification)])`, through `commit(ctx, …, needs:
  {structure, components, geometry})`. One undo step per wall.
- **Stored endpoints are the snapped points themselves**, so a chained run
  meets bit for bit.
- **Snapping** onto a centreline's `endpoint` makes a node, and onto its
  `nearest` point makes a T.
- **Enter, Esc or a double click** ends the chain. **A click on the chain's
  first point** commits the closing wall and ends the chain. A click that
  would make a wall shorter than `wallJoin.linear` is ignored.
- **Undo mid-chain** removes the last wall; the chain continues from that
  wall's start.
- **Thickness and justification** come from the tool's current settings,
  200 mm and centre by default, set in the panel (below).
- W joins `kShellLetterKeys` and the palette.

**End grips.**
- **A render-layer seam:** `GripCache` gains an optional
  `ObjectGripProvider`, consulted for a selected **root-level group**:
  `List<Grip> gripsOf(DraftDocument, Handle group)` and
  `DraftCommand? drag(DraftDocument, Handle group, Grip grip, Vector2 world)`.
  `GripDrag`'s reshape of such a grip builds its command through `drag`.
  With no provider, behaviour is exactly today's.
- **The app's `WallGrips`** returns two `stretch` grips at the world
  endpoints. `drag` returns **one `CompoundCommand` of
  `SetComponentCommand<WallParams>`**: the dragged wall's end, plus **every
  wall end within `wallJoin.linear` of the dragged end** (world), each
  written back in its own group's local space. One undo step; joined runs
  stay joined.
- The drag preview draws the moved centrelines; the band regenerates on
  release.
- **A whole-wall move or rotate** stays 03's group gesture
  (`TransformNodeCommand`) and **detaches** the wall; its old neighbours
  regrow free caps in the same step.

**The Wall section.**
- Shows when **exactly one** selected key is a root-level group carrying
  `WallParams`, or when the Wall tool is active (then it edits the tool's
  settings).
- **Thickness** (mm, > 0; ≤ 0 or unparseable reverts) and **Justification**
  (three-way toggle). Each commit is one `SetComponentCommand<WallParams>`,
  one undo step. Read-only under runtime permissions (`editCapability`).
- **The commit target is pinned when a field gains focus**, for the Wall
  section and the Box section alike: a field records the selected handle on
  focus gain and commits to that handle on focus loss, if it is still a live
  object of the same type. **This fixes 06's parked defect.** A test changes
  the selection without taking focus, then blurs: the value lands on the
  pinned wall.
- Guarded by `shortcut_guard.dart`, so typing "W" in a field does not switch
  tools.

### D12 — Diagnostics

- **`ParametricType` gains `List<Diagnostic> diagnose(ParametricView view,
  Handle self)`**, default empty. `ParametricSystem.diagnostics()` appends
  every object's.
- **`WallType.diagnose`** reports, one each, codes:
  - `wall.hole` — a node where a crossing lobe was dropped (D5.6), naming
    every member wall;
  - `wall.fallback` — a wall squared by D6's short-wall rule;
  - `wall.degenerate` — D2's degenerate wall.
- **Deterministic:** one entry per node, reported once, by its owner.

### D13 — Load, save, determinism

- **06 D10 and D11 hold unchanged:** on load geometry is trusted; load →
  save is byte-identical; the same state plus the same edit gives the same
  bytes; undo then redo restores the post-edit state.
- **Platform.** A byte hash of trig-dependent output differs between macOS
  and Linux (spike finding 7). **07's tests compare two documents built in
  the same run; none pins a literal hash of rotated geometry.**

## What 06 asked 07 to decide

| 06's item | Answer |
|---|---|
| `Generated` rejects fill (06 review m4) | D8: a region form; the fill record is never rewritten |
| Draw order of added children (06 D12) | D3, D9: walls never add children after creation |
| The O(n²) survey, twice per edit | D10: O(k·n), zero for an edit that touches no object |
| `reach` is an AABB placeholder (06 D3, m3) | D4: the centreline AABB expanded by the join tolerance |
| A zero-child object cannot be picked (06 N14) | D3: a wall always has children. The box stays debt |
| The panel commits to the wrong box (parked) | D11: the target is pinned at focus gain |
| `found[h]`, one registration per handle | Unchanged debt: no handle carries both a box and a wall |
| `_run`'s hand-rolled loop | D10: commented |
| The normalising helpers in `guards_test.dart` | Promoted to `support/fixture.dart` only if 07's tests reuse them |
| Undo re-links a removed node at the end; the seed never moves back | Unchanged; 07's delete tests normalise root order and the seed, as 06's do |

## Architecture

### Files

- **Engine, `packages/jet_cad_2d`:**
  - `lib/src/parametric/parametric_system.dart`: `Generated.region`,
    `ParametricType.diagnose`;
  - `lib/src/parametric/regeneration.dart`: regions in `_plan` (D8), the
    on-demand neighbour search (D10), the `_run` comment;
  - `test/parametric/`: region planning, neighbour-count and diagnostics
    tests with a test-only region client.
- **Render layer, `packages/jet_cad_2d_flutter`:** `ObjectGripProvider`
  and its use in `grip_cache.dart` and `grip_drag.dart` (D11).
- **App, `apps/floor_planner`:** D1's files; `selection_panel.dart` (the
  Wall section, the pinned target); `main.dart` (the catalog, the tool, the
  grip provider); `shortcut_guard.dart` (W); tests.

### Invariants

- **The frame path allocates nothing new.** Regeneration, grips and the
  panel run on edits and gestures. `query_allocation_test.dart` and
  `paint_allocation_test.dart` stay green, unchanged.
- **Draw order is ascending handle value** (D9).
- **Decisions use `wallJoin`; stored values use `==`** (D7).
- **Every stored outline triangulates** (D6).
- **No query walk is open during a regeneration** (06, unchanged).
- **`packages/jet_cad_2d` stays pure Dart;** `wall_geometry.dart` imports no
  Flutter.

## Testing

CLAUDE.md's bar: a test lands only if a named mutant turns it red. **The 90°
equal-thickness centre-justified fixture is this feature's degenerate
fixture** — bisector and average coincide, symmetric and asymmetric mitres
coincide, left and centre differ only in a direction it never exercises.

**Required fixture properties**, each carried by at least one relational
test:
- a joint at a **non-right, non-45° angle** (the spike's 67°);
- two walls of **different thickness** (200 and 115);
- at least one **T**, one **X** and one **three-way node**;
- a **non-centre justification**;
- the whole plan at the **far origin** (4,500,000, 1,200,000);
- relational fixtures **rotated**, each wall in its **own** group transform
  (06's M-06o lesson);
- a joint whose endpoints differ by a **deliberate ulp** (M-07d).

**Oracles, not counts alone** (spike finding 2): an L's outline has four
points mitred or square. Relational tests assert **coordinates**: shared
corners against an independent Cramer's-rule oracle, and the count of
corners two outlines share. Counts are still asserted, as 06 requires.

**"Inside a strip but uncovered" is not a gap oracle** (spike finding 3).
Overlap is checked by sampling; watertightness by shared corners and lobe
edges.

### Named mutants

| Mutant | What it breaks | Must be killed by |
|---|---|---|
| M-07a | the corner computed along the average of the two directions at the symmetric distance | the 67° L of 200 centre against 115 left: shared corners against the oracle (spike: 278 mm off) |
| M-07b | one wall's half-thickness for both sides | the same L (spike: 109 mm) |
| M-07c | every joint treated as a node (no T) | the T test: the stem's cap lies on the near face |
| M-07d | endpoints compared with `==` | a joint one ulp apart still shares two corners |
| M-07e | round-trip compared within `Tolerance` | load → save byte-identity, with a 1-ulp-perturbed control that must go red |
| M-07f | justification ignored (always centred) | the L's corners with B left-justified |
| M-07g | only the moved wall regenerates (closure = seeds) | move B off A: A's end becomes square, asserted by coordinates |
| M-07h | the group transform dropped in `generate` | the rotated L, each wall in its own group (spike: shared corners 2 → 0) |
| M-07i | the node point used as a cap vertex | the 67° L (a notch) and a three-way node under mixed justification |
| M-07j | acute wedges clamped too | a 20° L: no overlap between the two bands |
| M-07k | the lobe owner not the lowest handle (two owners or none) | a three-way node: the central polygon covered exactly once |
| M-07l | the short-wall fallback also applied to neighbours | a short wall between two nodes: `drift()` stays empty after moving a far neighbour |
| M-07m | a surplus region removed through its fill | a region client whose region count drops: no boundary survives its fill |
| M-07n | outline simplification removed | a pinched three-way node: the outline triangulates |
| M-07o | neighbours computed for every object | the overlap-test counter: a line draw among 300 walls performs 0 |
| M-07p | the panel's target read at focus loss | select wall A, focus Thickness, select B without focus, blur: A changes, B does not |
| M-07q | an end drag moves only the dragged wall | drag a node's shared end: every member's end follows, one undo step |
| M-07r | the T's far face chosen | the T test's cap-on-near-face assertion |
| M-07s | `reach` not expanded (an axis-aligned wall has a zero-height box) | an axis-aligned L: the two walls are neighbours and mitre |

### Differential check

- **`drift()` is empty** after every edit in every relational test.
- **A full regeneration from scratch agrees with the incremental one** on a
  plan of at least twenty walls with every joint kind.
- **Property test:** thousands of random nodes (2–5 ends, any angle,
  thickness 50–400, every justification, at the far origin): every outline
  is simple and triangulates, and shared corners are bitwise equal.

### App tests

- **The Wall tool:** three clicks and Enter make two walls, joined at the
  middle click, each one undo step; a closing click closes the loop; undo
  mid-chain continues from the removed wall's start.
- **End grips:** a node's end dragged; a free end dragged; the joined ends
  follow in one step.
- **The Wall section:** shows for one wall; hides otherwise; commits one
  step; reverts an invalid value; read-only under runtime; W in a field
  does not switch tools; the pinned-target test (M-07p).
- **The sample plan:** `drift()` and `diagnostics()` are empty.

## Exit gate

1. The four gate lines are green with `CI=true` on the human's macOS
   machine: engine, render layer (only the five standing
   `text_ladder_golden_test.dart` failures), harness, app; both release
   builds `✓ Built`.
2. A single wall generates the documented outline for each justification.
3. An L mitres, asymmetrically, at a non-right angle; a T butts; an X
   crosses; a three-way node closes — each verified by coordinates.
4. Moving or deleting a joined wall regenerates its neighbours in **one**
   undo step; undo and redo restore it exactly.
5. Load → save is byte-identical; `drift()` is empty after load.
6. Every stored outline triangulates (the property test).
7. `diagnostics()` names D6's accepted cases, and only those.
8. The neighbour search is O(k·n) per edit, measured and pinned (D10).
9. The allocation invariants pass unchanged.
10. Draw order stays ascending; a wall's children keep their handles.
11. The pinned panel target holds (M-07p).
12. Every named mutant is killed, logged in `plan-07-mutation-log.md`.
13. **The human's look:** the Wall tool, joints, end grips and the Wall
    section, on macOS, in Chrome and in Firefox.

## Open questions

None blocking. Recorded:

- **The 0.78% hole** (D6) is accepted; option 2 or 3 of the spike note is
  the path if real plans hit it.
- **08:** an opening near a joint may be covered by a neighbour's
  overlapping fill.
- **10:** rooms should derive from faces and centrelines, not from these
  polygons.
