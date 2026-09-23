# Grips and transform — design

**Date:** 2026-09-23. **Status:** design, **revision 1**, not yet a plan.
**Sub-project:** `roadmap/03-grips-and-transform.md`. **Size:** M.
**Brainstormed with the human on 2026-09-23**, on `main` at `c1f9877`, the
day Plan 04's look closed its exit gate at 16 of 16.
**Depends on:** 02 (merged at `8c62db3`; `CompoundCommand` landed with
`fix/compound-delete`), 04 (merged at `e4e3f80`; `snapToGrid` and D6's
precedence rule). **Blocks:** 05 (drawing tools), 11 (dimensions).

**Evidence of record.** Every claim below about what exists was read from the
tree at `c1f9877` on 2026-09-23:

- `packages/jet_cad_2d/lib/src/document/commands.dart` —
  `TransformNodeCommand` 278 (capability `transform`, replaces a group's or
  an instance's `transform` wholesale, inverse carries the previous one);
  `SetEntityGeometryCommand` 441 (capability `geometry`, rejects fills,
  inverse carries a `read` copy of the previous payload, re-triangulates
  dependent fills and puts them in `touched`); `CompoundCommand` 732.
- `lib/src/index/snap.dart` — `SnapKind` 23 (declaration order is priority);
  `SnapMask.cheap` 53 (`0x1F`, endpoint..insertion); `SnapResult` 77
  (caller-owned, its `point` rewritten in place by every query).
- `lib/src/index/spatial_index.dart` — `snapInto` 1466; its doc at 1404
  states **kind dominates unconditionally**: a far endpoint inside the
  radius beats a near midpoint. Default filter `QueryFilter.rendering`
  (locked geometry is snappable). Intersections are root-level lines and
  polylines only.
- `lib/src/store/geometry_store.dart` — `GeometryPayload` 16: `coords`
  (interleaved x, y in the owner's space) and `scalars`; `transformedBy`
  applies a `Transform2` to coords and copies scalars.
- Payload layouts, from `_considerSnapLeaf` (`spatial_index.dart` 1685):
  point `[x, y]`; line and polyline `[x0, y0, …]`, polyline open (no
  closing segment); circle coords `[cx, cy]`, scalars `[r]`; arc coords
  `[cx, cy]`, scalars `[r, startAngle, sweep]` (sweep signed). Text:
  scalars `[height, rotation, widthFactor, oblique]`, the trailing three
  optional (`text_scalars.dart` `scalarOr`, `text_geometry.dart` 190 reads
  rotation from `scalars[1]`).
- `lib/src/geometry/transform2.dart` — `multiply` 62: the argument is
  applied **first**, so `parent.multiply(child)` is `parent ∘ child`.
- `lib/src/document/node.dart` 12-13 — only containers carry a transform;
  leaves are in their owner's space. `tree.dart` 61 — the root is a
  `GroupNode`, so it has a `transform` like any other.
- `lib/src/geometry/grid_scale.dart` — `snapToGrid` 149, `GridScale.pick`
  80, `minorMm`/`majorMm` 20-23 (Plan 04, D6/D7).
- `packages/jet_cad_2d_flutter/lib/src/select_tool.dart` — a press on an
  object that moves past `kBandSlopPixels` does nothing (76:
  `if (_downHit) return;`); `_deleteSelection` builds one
  `CompoundCommand` after a whole-list permission preflight.
- `lib/src/tool.dart` — `ToolContext` 38 (document, index, camera,
  selection), `Tool` 59.
- `lib/src/interaction_layer.dart` — `kPickRadiusPixels = 6.0` 20;
  `pickRadiusWorld = kPickRadiusPixels / cam.scale` 93; the layer's
  `MouseRegion` 189.
- `lib/src/viewport_transform.dart` — the camera is a full `Transform2`
  (rotation is representable, 63), `scale` is `scaleMagnitude`.
- `lib/src/outline_cache.dart` — `pathFor(SelectionKey, Vector2 origin)`
  103: the selection's outlines, built at selection-change rate, rebased by
  the origin the painter's matrix carries.
- `apps/floor_planner/lib/main.dart` — the shell builds `ToolContext` at 53
  and `SelectTool` at 59, and binds undo through `CallbackShortcuts` at
  102-105; the top bar's `zoom-text` at 126.

---

## What this delivers

A selected object shows grips. Dragging a grip reshapes the object: a line's
end, a polyline's vertex, a circle's radius, an arc's end or radius.
Dragging a selected object's body, or a circle's or arc's centre grip, moves
the whole selection. A rotation grip above the selection box rotates it.
While dragging: a live preview in the overlay, object snap with markers,
grid snap as the fallback, and shift for ortho. Releasing dispatches
**exactly one** command, so one drag is one undo step. Escape cancels with
no document change. F3 toggles object snap.

## Non-goals

- **Scale.** Deferred (human). A non-uniform scale turns a circle into an
  ellipse the engine cannot store; a uniform one has no floor-planner use
  yet.
- **Polar tracking.** Shift-ortho only (human).
- **Grips on leaves inside a group or an instance.** Selection is root-level
  (02's D2); a group or an instance moves and rotates whole.
- **Vertex insertion or deletion** on polylines.
- **Grips as widgets.** Painted (D2); the accessibility argument is recorded
  as debt under Open questions.
- **Excluding the dragged objects from snapping.** They stay snappable at
  their original position, as in AutoCAD's MOVE (D8).
- **Typed input** (distance or angle entry during a drag).

---

## Decisions

### D1 — Scope: move, reshape, rotate; no scale (human)

Three operations, all rigid or single-coordinate:

- **Move**: a translation of every selected object.
- **Rotate**: a rotation of every selected object about one pivot.
- **Reshape**: one grip of one root-level leaf.

Every move and rotate is a **rigid** transform (`det = +1`, orthonormal), so
a circle stays a circle, an arc's sweep keeps its sign and a text's height
is untouched.

### D2 — Grips live in `SelectTool`, painted in the overlay

Grip editing is part of selection mode, as in AutoCAD, not a separate tool.
`SelectTool` gains a drag kind; the drag's state and its command building
live in a new `GripDrag` class so `select_tool.dart` does not absorb them.

Rejected: a `GripTool` swapped in whenever the selection is non-empty (every
click becomes a handoff, and 02's `activate` contract is pinned by tests);
grips as widgets (a grip still hit-tests in world space through the camera,
and the overlay already exists). The cursor change the widget option would
have given for free is one `MouseRegion.cursor` the tool feeds (D5).

**Press classification**, in this order, the first that hits wins:

1. the **rotation grip** (D6), when the selection is non-empty;
2. a **grip** of a selected object, within `kGripHitPixels = 7.0` screen
   pixels of its centre; among several, the nearest, then the greater
   handle, then the lower grip index;
3. the **body of a selected object** (the existing pick, `pickInto` with
   `QueryFilter.picking`, resolved to a root key);
4. the **body of an unselected object**;
5. **empty space** — the existing band.

A press that never moves `kBandSlopPixels` (4 px) is the existing click, for
every class: 1 and 2 do nothing on release, 3 and 4 select or toggle as
02 does. Past the slop, 1 starts a rotate, 2 a reshape (or a move, for a
centre grip — D3), 3 a move of the selection, 4 selects the object
(`replace`, or `toggle` into the selection with shift) and then moves the
selection, 5 a band.

### D3 — The grip set, per kind, in the engine

`packages/jet_cad_2d/lib/src/document/grips.dart`, pure Dart. Grips are
computed in the leaf's **own** (owner) space; the render layer maps them to
world through the owner's world transform.

| kind | grips | role |
|---|---|---|
| point | none | body drag moves it |
| line | vertex 0, vertex 1 | stretch |
| polyline | every vertex `i` | stretch |
| circle | centre | move |
| circle | quadrants 0..3 at `θ = q·π/2` | radius |
| arc | centre | move |
| arc | start (index 0), end (index 1) | stretch (angle) |
| arc | midpoint at `start + sweep/2` | radius |
| text, attrib, fill | none | text moves by body; attribs are never root-level; a fill follows its boundary |
| group, instance | none | body drag moves, rotation grip rotates |

```dart
enum GripRole { stretch, radius, move }

final class Grip {
  const Grip(this.role, this.index, this.x, this.y);
  final GripRole role;
  final int index;       // vertex index; quadrant 0..3; arc end 0/1; else 0
  final double x, y;     // owner space
}

List<Grip> leafGrips(EntityKind kind, GeometryPayload payload);
```

**Reshape.** `GeometryPayload? reshapeLeaf(EntityKind kind,
GeometryPayload payload, Grip grip, Vector2 localTarget)` returns a new
payload, or **null when the result is degenerate** (then the preview shows
the object unchanged and release dispatches nothing):

- **line / polyline, stretch `i`**: `coords[2i] = target.x`,
  `coords[2i+1] = target.y`. Every other coordinate and every scalar is
  **copied bit for bit** — never recomputed. Never degenerate (a
  zero-length segment is legal geometry).
- **circle, radius `q`**: `r = |target − centre|`; null when
  `r <= Tolerance.standard.linear`. Centre copied.
- **arc, stretch 0 (start)**: `s' = atan2(target − centre)`; the end angle
  `e = s + sweep` stays; `sweep' = wrap(e − s')` **in the same direction as
  `sweep`**: for `sweep > 0`, `sweep'` is the value in `(0, 2π)` congruent
  to `e − s'` mod `2π`; for `sweep < 0`, the value in `(−2π, 0)`. Null when
  `|sweep'|` is within `Tolerance.standard.angular` of `0` or of `2π`. Centre and
  radius copied.
- **arc, stretch 1 (end)**: `s` stays; `sweep' = wrap(atan2(target −
  centre) − s)`, same direction rule, same null rule.
- **arc, radius**: `r = |target − centre|`, the circle's null rule; the
  angles copied.
- **move grips** are not reshapes: `reshapeLeaf` throws `ArgumentError` for
  `GripRole.move`; the tool routes a centre grip to a move (D4).

**Rigid transform of a leaf.** `GeometryPayload rigidTransformLeaf(
EntityKind kind, GeometryPayload payload, Transform2 t)` — `t` in the leaf's
owner space. Throws `ArgumentError` unless `t` is rigid
(`|a·d − b·c − 1|` and the column-orthonormality residuals within
`Tolerance` — a decision, so `Tolerance`). With `θ = atan2(t.b, t.a)`:

- point, line, polyline: `payload.transformedBy(t)`.
- circle: centre transformed; scalars copied.
- arc: centre transformed; `startAngle + θ`; radius and sweep copied.
- text: insertion point transformed; `scalars[1] = rotation + θ`. A text
  stored with only its height (schema 3) gets `scalars[1]` written — a real
  edit of that entity, not padding on load, so `text_scalars.dart`'s
  no-padding rule is not broken.
- fill, attrib: throws `ArgumentError`.

A pure translation `(1, 0, 0, 1, dx, dy)` gives `x + dx` exactly for every
coordinate (`0·y` is `0` for finite `y`), so a move reproduces what a human
would compute.

### D4 — What release dispatches

Nothing is dispatched during a drag (roadmap decision 1). On release, one
command:

| drag | per selected key | command |
|---|---|---|
| reshape | the grabbed leaf only | `SetEntityGeometryCommand(h, reshapeLeaf(...))` |
| move / rotate, root leaf | `SetEntityGeometryCommand(h, rigidTransformLeaf(kind, p, L))` | |
| move / rotate, root group or instance | `TransformNodeCommand(h, T_root.multiply(node.transform))` | |

- `T` is the world-space transform of the drag: `translation(Δ)` for a move,
  `translation(p)·rotation(θ)·translation(−p)` for a rotate about pivot `p`.
- A root-level node's parent space is the root's space. **The root is a
  `GroupNode` with a `transform`** (`tree.dart` 61), so the world-space `T`
  is conjugated into root space: `T_root = R⁻¹ · T · R` where `R` is the
  root's transform, and a root leaf gets `L = T_root`. When `R` is the
  identity this is `T` itself; the fixture sets a non-identity `R` so an
  implementation that skips the conjugation goes red (M-03r). A root-level
  node's transform lives in the same root space, so it takes `T_root` too:
  its world transform `R·N` becomes `T·R·N = R·(T_root·N)`.
- **Group and instance: `T_root.multiply(node.transform)`** — the drag applied
  *after* the node's own transform, in the parent's space. The reverse
  order agrees only when the node's transform is a pure translation, so
  the fixture's group is rotated (M-03i).
- **One key → its command, unwrapped. Two or more → one
  `CompoundCommand`**, members in ascending `target` handle order, label
  `Move`, `Rotate` or (never compound) `Stretch`.
- **Fill keys are skipped** in a move or rotate: a fill follows its
  boundary through `SetEntityGeometryCommand`'s re-triangulation. A
  selection of fills only starts no drag.
- **Permissions: all or nothing.** Every command's `capabilities` is checked
  against `document.commands.permissions` before anything executes; if any
  is refused, the drag is cancelled whole and nothing is dispatched. This
  differs from Delete's skip-the-refused rule (02's D10) on purpose: a move
  that leaves some objects behind silently breaks the alignment the user
  was dragging for.
- **A drag that changes nothing dispatches nothing**: `Δ == (0, 0)` exactly,
  `θ == 0` exactly, a null reshape, or a reshape whose payload `==` the
  stored one. No empty undo entries.

### D5 — The interaction

- **Phases** stay `idle, pressed, dragging`; `dragging` gains a kind
  (`band, move, rotate, reshape`).
- **World from screen, every event.** The drag keeps its base point in
  **world** space and re-reads the pointer's world point from each event's
  `ToolPointerEvent.world` — never a screen delta scaled afterwards. A
  camera change mid-drag (a trackpad zoom) therefore keeps the object under
  the pointer (M-03a).
- **Escape** during a drag cancels it: preview gone, no command, document
  byte-identical (`DraftDocumentCodec` output equal before and after). A
  selection change made at drag start (class 4 of D2) stands; it is
  selection state, never undone. **Pointer exit** during a drag cancels too
  (02's rule for the band).
- **Cursor.** `Tool` gains `MouseCursor get cursor`, default
  `MouseCursor.defer`; `InteractionLayer`'s `MouseRegion` reads it and
  repaints on tool notification. `SelectTool` answers
  `SystemMouseCursors.precise` over a grip, `.grab` over the rotation grip,
  `.move` over a selected body and during a move, `.grabbing` during a
  rotate, `.defer` otherwise.
- **Hover** of a grip marks it (D6); object hover (02) is suppressed during
  a drag.

### D6 — Grip rendering and the selection box

`GripCache` (render layer), a `ChangeNotifier` built from the document and
the `SelectionController`, rebuilt at selection-change and document-change
rate like `OutlineCache`:

- the **world-space grips** of every selected root leaf, via `leafGrips`
  mapped through the root's transform;
- the **selection box**: the world-space AABB of the selection — the union
  of `OutlineCache.pathFor(key, origin).getBounds()` shifted back by
  `origin`, over the selected keys. `OutlineCache` already walks leaves,
  instances and nested groups through their transforms, so the box is the
  outline the user sees selected, and no second walk exists to drift from
  it. `GripCache` therefore takes the `OutlineCache` as a dependency, and
  **the shell, not `PlannerView`, owns both** — constructed after the
  `SelectionController`, keeping `OutlineCache`'s listener-order rule
  (`planner_view.dart` 41-43), and handed to `PlannerView` and to
  `ToolContext`;
- **cap**: when the selection's grip count exceeds `kMaxGrips = 400`, no
  leaf grips are shown (body move and rotation still work) — a drawn
  polyline with thousands of vertices must not turn the overlay into a
  per-vertex frame.

The overlay painter draws, in screen space, after the outlines:

- stretch and radius grips: filled squares, `kGripPixels = 8.0` side, in
  `kGripColor`; move grips: the same square, hollow;
- the hovered grip in `kGripHotColor`, and the grabbed one during a drag;
- the **rotation grip**: a circle of `8.0` px diameter, `kRotationGripOffset
  = 24.0` px above the top-centre of the **screen-space** bounding box of
  the selection box's four projected corners, joined to it by a 1 px line.
  Under a rotated camera "above" is screen-up; the pivot is always the
  **world** box's centre.

No `Paint` or `Path` is allocated per grip per frame; the grip positions are
the cache's, projected into a reused buffer.

### D7 — Preview

The canvas keeps drawing the original: nothing in the document changes
until release. The overlay draws the preview in `kPreviewColor` on top:

- **move / rotate**: the selection's cached outlines (`OutlineCache.pathFor`)
  drawn a second time through `matrix ∘ T`, where `T` is the drag's world
  transform. `Tool` gains `Transform2? get selectionPreviewTransform`,
  default null; the overlay painter reads it. No path is rebuilt: **zero
  allocation per frame** beyond what 02's overlay already does.
- **reshape**: one path built per frame from the preview payload of the one
  entity — a fixed cost per frame, independent of the document and of the
  selection size. Drawn by `SelectTool.paintOverlay`.
- a 1 px line from the base point to the (snapped) target, and the snap
  marker (D9) at the target.

### D8 — Snap during a drag: object, then ortho-overridden, then grid

`packages/jet_cad_2d/lib/src/index/drag_snap.dart`, pure Dart:

```dart
const SnapMask kDragSnapMask = SnapMask(0x9F); // cheap | intersection

final class DragPoint {            // caller-owned, reused, never held
  final Vector2 point = Vector2.zero();
  SnapKind? objectKind;            // non-null: an object snap won
  bool grid = false;               // the grid won
}

void resolveDragPoint({
  required Vector2 raw,            // the pointer, world
  required Vector2? orthoBase,     // non-null while shift is held
  required SpatialIndex index,
  required double apertureWorld,
  required bool objectSnap,        // F3
  required PageComponent? page,
  required double? gridStepMm,     // page.gridStepMm, else the adaptive minor ?? major
  required SnapResult scratch,
  required DragPoint out,
});
```

Resolution, in this order:

1. **Ortho.** With `orthoBase`, `c` is `raw` with the minor axis pinned to
   the base: `|raw.x − b.x| >= |raw.y − b.y|` keeps `x` free and sets
   `c.y = b.y`; otherwise the reverse. Without it, `c = raw`.
2. **Object snap** (when `objectSnap`): `index.snapInto(raw, apertureWorld,
   kDragSnapMask, scratch)` — queried at the **pointer**, not at `c`, since
   the marker the user aims at is under the pointer. A hit wins outright and
   **overrides ortho** (AutoCAD's rule): `out.point = scratch.point`, copied
   immediately — `scratch.point` is rewritten by the next query.
   `apertureWorld = kSnapAperturePixels / camera.scale`,
   `kSnapAperturePixels = 10.0`.
3. **Grid** (when `page != null && page.snapToGrid && gridStepMm != null`):
   `g = snapToGrid(c, gridStepMm, page)`; with ortho, the pinned axis is
   written back from the base **after** the grid snap, so a shift-drag from
   an off-grid base stays exactly on its line (M-03q).
4. Otherwise `c`.

Object snap within the aperture always beats the grid (Plan 04's D6, the
standard CAD rule), whatever their distances (M-03g). Between object snap
kinds the engine's kind-first order decides; this spec adds no rule of its
own there (M-03b fires against that order through a drag).

**Base point.** For a grip, the grip's own world point, exactly. For a body
drag, the press point resolved by step 2 alone (object snap, no grid, no
ortho), else the raw press point. The move's `Δ = target − base`.

**Exactness.** A stretch writes the resolved target into the grabbed
coordinate: released near an endpoint, it lands on that endpoint **exactly**
(`==`, root transform identity). A move computes `x + (t − b)` per
coordinate, which is `t` to within one rounding, not always bit-equal; the
spec does not promise more, and the test for moves compares with
`Tolerance` — a decision about where the geometry went, not a stored-value
round trip.

**Dragged objects stay snappable** at their stored position. The stored
geometry does not move until release, so snapping to it is snapping to what
the canvas still draws — AutoCAD's MOVE behaves the same.

**Rotate** uses no object or grid snap: `θ = atan2(pointer − p) −
atan2(press − p)`; with shift, `θ` rounds to the nearest multiple of `π/12`
(15°).

### D9 — Snap markers

Drawn in the overlay at the resolved target, screen space, 1.5 px stroke,
`kSnapMarkerColor`, `kSnapMarkerPixels = 10.0`:

| won by | marker |
|---|---|
| endpoint | square |
| midpoint | triangle, apex up |
| center | circle |
| quadrant | diamond |
| insertion | square with a cross inside |
| intersection | X |
| grid | small `+`, 6 px |

Nothing is drawn when the raw point won.

### D10 — `SnapSettings`, F3, and what `ToolContext` carries

`SnapSettings` (render layer): a `ChangeNotifier` with `bool objectSnap`
(default true) and `toggleObjectSnap()`. Owned by the shell.

`ToolContext` gains three **optional** named fields, so every 02 call site
still compiles: `PageNotifier? page`, `SnapSettings? snap`,
`GripCache? grips`. With `grips == null` the tool shows no grips and starts
no grip or rotation drag; with `snap == null` object snap is on; with
`page == null` there is no grid snap. 02's tests keep their meaning.

The shell binds **F3** in its existing `CallbackShortcuts` to
`snap.toggleObjectSnap()`, and shows `OSNAP` or `osnap off` in the top bar
(key `osnap-text`). Whether a browser also acts on F3 (Chrome's find-next)
is item of the look; if it does, the look's finding picks another key.

### D11 — Undo is exact

Undo of a drag restores every stored value with `==`: `SetEntityGeometryCommand`'s
inverse holds a `read` copy of the previous payload, `TransformNodeCommand`'s
the previous transform, and a `CompoundCommand` undoes its members in
reverse. The test compares with `==`; M-03e makes it compare with
`Tolerance` and must stay green, then a 1-ulp perturbation of one restored
coordinate must turn the `==` test red — proving `==` is what it enforces.

### D12 — What this changes in 02's behaviour

A press on an object followed by a drag used to do nothing
(`select_tool.dart` 76). It now moves the selection (D2, class 3 and 4). Any
02 test that pins the old no-op is updated in the task that changes it, with
the reason in its name.

---

## Architecture

### Files

| file | responsibility |
|---|---|
| `packages/jet_cad_2d/lib/src/document/grips.dart` (new) | `GripRole`, `Grip`, `leafGrips`, `reshapeLeaf`, `rigidTransformLeaf` |
| `packages/jet_cad_2d/lib/src/index/drag_snap.dart` (new) | `kDragSnapMask`, `DragPoint`, `resolveDragPoint`, `kSnapAperturePixels` |
| `packages/jet_cad_2d/lib/jet_cad_2d.dart` | exports |
| `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart` (new) | world grips and selection box, selection/doc-change rate |
| `packages/jet_cad_2d_flutter/lib/src/grip_drag.dart` (new) | one drag's state; base, target, `T` or preview payload; `commands()` |
| `packages/jet_cad_2d_flutter/lib/src/snap_settings.dart` (new) | `SnapSettings` |
| `packages/jet_cad_2d_flutter/lib/src/snap_marker.dart` (new) | `drawSnapMarker`, `drawGrip` |
| `packages/jet_cad_2d_flutter/lib/src/selection_style.dart` | grip, hot-grip, preview, marker colours and sizes |
| `packages/jet_cad_2d_flutter/lib/src/tool.dart` | `ToolContext` optional fields; `Tool.cursor`, `Tool.selectionPreviewTransform` |
| `packages/jet_cad_2d_flutter/lib/src/select_tool.dart` | press classes, drag kinds, Escape, cursor |
| `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart` | cursor from the tool |
| `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart` | grips, rotation grip, move/rotate preview |
| `apps/floor_planner/lib/main.dart` | owns `SnapSettings`, `OutlineCache` (moved from `PlannerView`) and `GripCache`; F3; `osnap-text`; `ToolContext` fields |
| `apps/floor_planner/lib/planner_view.dart` | takes `OutlineCache` and `GripCache` from the shell instead of owning the outline cache; `GripCache` joins the overlay's repaint merge |

### Invariants

1. **No command during a drag.** `document.commands.undoDepth` is unchanged
   from press to the last move event; release adds exactly one entry or
   none (D4's no-op rule).
2. **Escape and pointer exit leave the document byte-identical.**
3. **Undo restores with `==`** (D11).
4. **Draw order is untouched**: no handle is allocated or freed by a drag;
   `SetEntityGeometryCommand` and `TransformNodeCommand` keep handles.
5. **The frame path is unchanged**: `query_allocation_test.dart` and
   `paint_allocation_test.dart` pass unchanged. A drag's per-move cost is
   one `snapInto` (zero allocation per candidate, its own guarantee) and,
   for a reshape only, one preview path.
6. **No `SnapResult.point` is held** past the call that filled it.
7. **Stored-value comparisons use `==`; placement decisions use
   `Tolerance`** — the degenerate-reshape rule, the rigidity check, the move
   test's landing check.

---

## Testing

The fixture rule, stated once: **every tool and widget test runs under a
camera that is zoomed (scale ≠ 1), panned (translation ≠ 0) and rotated
(≠ 0, ≠ 90°)**, with a **non-identity root transform** where the test
touches root leaves, **a rotated group**, and **two instances of one
definition**. Arcs in fixtures have a non-zero start angle, and at least one
has a **negative sweep**. Coordinates sit away from the origin.

### Named mutants

| id | mutation | must go red |
|---|---|---|
| M-03a | the drag delta taken in screen space, scaled by `1/scale`, no inverse camera | the move test under the rotated camera |
| M-03b | `_considerSnapCandidate` orders by distance before kind | a drag near a midpoint with an endpoint also in the aperture lands on the endpoint |
| M-03c | an instance drag rewrites the definition's leaves instead of the instance node | the two-instance test: the second instance is unmoved |
| M-03d | a command dispatched on every move event | the one-undo-entry test |
| M-03e | the undo assertion compares with `Tolerance` | **stays green**; the 1-ulp perturbation then goes red under `==` (D11) |
| M-03f | ortho keeps the minor axis free instead of the major | the shift-drag test |
| M-03g | the grid beats an object snap when the grid point is closer | the precedence test with a grid point nearer than the endpoint |
| M-03h | `rigidTransformLeaf` leaves an arc's `startAngle` unchanged | rotate of an arc; the differential |
| M-03i | a node move composes `node.transform.multiply(T_root)` | the rotated-group move |
| M-03j | the rotation pivot is the world origin | rotate of a selection far from the origin |
| M-03k | a multi-move executes the permitted members when one is refused | nothing moves when geometry is refused and transform allowed, with a leaf and an instance selected |
| M-03l | Escape dispatches the pending command | the byte-identical cancel test |
| M-03m | `rigidTransformLeaf` leaves a text's rotation scalar unchanged | rotate of a text; the differential |
| M-03n | an arc end-grip stretch ignores the sweep's sign | the negative-sweep arc stretch |
| M-03o | a polyline stretch writes vertex `i + 1` | stretching a middle vertex moves it and nothing else |
| M-03p | release with `Δ == 0` still dispatches | the click-without-move test: undo depth unchanged |
| M-03q | ortho does not re-pin the locked axis after the grid snap | shift-drag from an off-grid base with grid snap on |
| M-03r | root leaves take the world `T` without conjugating by the root transform | the move test with a non-identity root transform |

Every mutant is fired by a `cp`-backed scratch script, restored, and `diff`ed;
the log is `docs/superpowers/notes/plan-03-mutation-log.md`.

### Differential check

`rigidTransformLeaf` against an oracle that shares no code with it: for
each kind (point, line, polyline, circle, arc, text), sample points on the
original curve **computed independently from the stored values** (the arc's
points from `centre + r·(cos, sin)` over its sweep; the text's baseline
direction from its rotation), transform them with `T`, and compare with the
same samples taken from the transformed payload, within `Tolerance`. Seed
`0x5EED0003`, 200 trials, rotations drawn from `(−2π, 2π)` excluding
multiples of `π/2`, translations up to `1e6`. The trial count, the seed and
the worst residual are pasted into the results note.

### Widget tests

The drag end to end through `InteractionLayer` in the app's own
`PlannerView` tree: press, move past the slop, move, release; then cmd+Z
through the shell's binding; then F3 and a drag that no longer snaps.

---

## Exit gate

1. `leafGrips` returns D3's set for every kind, in owner space.
2. A stretch moves the grabbed coordinate and nothing else (bit-equal
   elsewhere), for a line, a polyline's middle vertex, both arc ends
   (both sweep signs) and the radius grips.
3. `rigidTransformLeaf` passes the differential (seed, 200 trials).
4. A body drag moves the whole selection; a centre grip does the same.
5. A move of a rotated group and of an instance composes `T_root.multiply(node.transform)`;
   the definition and the other instance are untouched.
6. A rotation rotates about the selection box's centre; shift steps 15°.
7. One drag is one undo entry; a multi-object drag is one `CompoundCommand`;
   a drag that changes nothing adds none.
8. Undo restores with `==` (D11, M-03e's two halves).
9. Escape and pointer exit leave the document byte-identical.
10. Released near an endpoint, a stretch lands on it exactly; object snap
    beats the grid; ortho is overridden by an object snap and re-pinned
    after a grid snap.
11. Permissions are all or nothing across a multi-move.
12. The grip cap holds: above `kMaxGrips` no leaf grip is drawn.
13. Every named mutant M-03a…r fired and killed, or declared equivalent
    with a reason, in the mutation log.
14. The allocation invariants pass unchanged.
15. The four gate lines are green (`CI=true`), with only the five standing
    `text_ladder_golden_test.dart` failures, and both app builds succeed.
16. A human looked, on macOS, in Chrome and in Firefox from `build/web`.

## Open questions

- **F3 in a browser.** Chrome binds F3 to find-next. If the framework's
  handled key does not suppress it, the look picks another key.
- **Grips as widgets.** Painted grips give up screen-reader and keyboard
  access to grips that widgets would have had. Recorded as debt for 12 (the
  app shell), which owns accessibility.
- **Snapping to the dragged object's ghost.** Kept (D8). If the look finds
  it sticky, the fix is an exclusion set on `snapInto`, which is an engine
  query change with its own allocation argument, not a tweak here.
- **Move exactness.** A move lands within one rounding of the target, not
  bit-exact (D8). A snapped vertex that must coincide exactly with another
  object's vertex is a stretch, which is exact.
- **Grips inside groups.** Deferred until a "descend into group" selection
  exists.

## What this changes outside 03

- `Tool` gains two members with defaults; `ToolContext` three optional
  fields. No existing implementer or call site changes.
- `SelectTool`'s press-then-drag on an object changes from a no-op to a move
  (D12).
- 05 inherits `resolveDragPoint` for placing points while drawing; 11
  inherits `leafGrips` for dimension grips.
