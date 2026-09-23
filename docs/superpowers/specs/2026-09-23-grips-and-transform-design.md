# Grips and transform — design

**Date:** 2026-09-23. **Status:** design, **revision 2**, not yet a plan.
Revision 1 (`b6bb508`) was reviewed the same day by two independent
reviewers (Codex CLI with `gpt-5.5`, an Opus subagent); every finding was
re-verified against the tree and is recorded, with its ruling, in
[2026-09-23-grips-and-transform-spec-review-r1.md](../notes/2026-09-23-grips-and-transform-spec-review-r1.md).
Revision 2 applies them. Three were blockers. **The root's transform is not
part of the world mapping.** The canvas, the index and the oracle all ignore
it, so revision 1's conjugation by it was wrong (D4 is the fix). **An undo
could land mid-drag** (D5 is the fix). **The selection box was taken from
`ui.Path.getBounds`**, which returns an arc's control-point bounds and
`Rect.zero` for a point (D6 is the fix).
**Sub-project:** `roadmap/03-grips-and-transform.md`. **Size:** M.
**Brainstormed with the human on 2026-09-23**, on `main` at `c1f9877`, the
day Plan 04's look closed its exit gate at 16 of 16.
**Depends on:** 02 (merged at `8c62db3`; `CompoundCommand` landed with
`fix/compound-delete`), 04 (merged at `e4e3f80`; `snapToGrid` and D6's
precedence rule). **Blocks:** 05 (drawing tools), 11 (dimensions).

**Evidence of record.** Every claim below about what exists was read from the
tree at `c1f9877` on 2026-09-23 and re-checked by both reviewers:

- `packages/jet_cad_2d/lib/src/document/commands.dart`:
  - `TransformNodeCommand` 278: capability `transform`; replaces a group's
    or an instance's `transform` wholesale; the inverse carries the previous
    transform; its label is always `Move`.
  - `SetEntityGeometryCommand` 441: capability `geometry`; rejects fills;
    the inverse carries a `read` copy of the previous payload; it
    re-triangulates dependent fills and puts them in `touched`; its label is
    always `Edit geometry`.
  - `CompoundCommand` 732: takes a `label`.
- `lib/src/index/snap.dart`:
  - `SnapKind` 23: declaration order is priority.
  - `SnapMask.cheap` 53: `0x1F`, endpoint..insertion.
  - `SnapResult` 77: caller-owned; its `point` is `final` and rewritten in
    place by every query.
- `lib/src/index/spatial_index.dart` `snapInto` 1466:
  - Its doc at 1405-1406 says **kind dominates unconditionally**: a far
    endpoint inside the radius beats a near midpoint.
  - Default filter `QueryFilter.rendering`, so locked geometry is snappable.
  - Intersections are root-level lines and polylines only.
  - It descends from the root with `Transform2.identity()` (1484), as do
    `pickInto`, `container_index.dart` 176 and `reference_walk.dart` 42-43.
- `lib/src/store/entity_store.dart` 34-36 and `document/node.dart` 12-13:
  a leaf's coordinates are in its owner's space; only containers carry a
  transform.
- `store/geometry_store.dart` 16: `GeometryPayload` has `coords` and
  `scalars`; `transformedBy` transforms the coords and copies the scalars.
- Payload layouts, from `_considerSnapLeaf` (`spatial_index.dart` 1685):
  - point: `[x, y]`.
  - line and polyline: `[x0, y0, …]`. A polyline is closed by repeating its
    first point as its last (`triangulate.dart` 5-8).
  - circle: coords `[cx, cy]`, scalars `[r]`.
  - arc: coords `[cx, cy]`, scalars `[r, startAngle, sweep]`, sweep signed.
  - text: scalars `[height, rotation, widthFactor, oblique]`, the last three
    optional (`text_scalars.dart` `scalarOr`; `text_geometry.dart` 190).
- `lib/src/geometry/transform2.dart`:
  - `multiply` 62 applies its argument **first**, so
    `parent.multiply(child)` is `parent ∘ child`.
  - There is no `operator ==` (123-126); `equals(other, tol)` exists.
- `lib/src/geometry/primitives.dart` 82: `arcBounds`.
- `lib/src/geometry/grid_scale.dart`: `snapToGrid` 149, `GridScale.pick` 80.
- `lib/src/document/command.dart` 57: `DraftPermissions.runtime` allows
  `transform` and denies `geometry`.
- `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`:
  - At 76, `if (_downHit) return;`: a press on an object that moves past
    the slop does nothing.
  - `_deleteSelection` preflights per key, skips refused keys, and runs the
    permitted commands as one `CompoundCommand`.
  - `onKey` ignores every key but Escape, Delete and Backspace (218-236).
- `lib/src/interaction_layer.dart`:
  - `kPickRadiusPixels = 6.0` (20); `pickRadiusWorld` (93).
  - `_onExit` returns while a pointer is captured (157-160; 02's amended
    rule, pinned by `interaction_layer_test.dart` 378-400).
  - `PointerCancelEvent` reaches the tool (138-143).
  - The `MouseRegion` (189) is built once and listens to nothing.
- `lib/src/outline_cache.dart`:
  - Keeps world records in doubles (`_Segments`, `_Arc`, `_Point`) and
    `ui.Path`s rebased by an origin (`pathFor` 103).
  - `worldPointOf` exists for point keys.
  - 151-157 measures `Path.getBounds` as wrong for arcs.
- `lib/src/selection_overlay.dart` 53-87: the overlay's matrix is
  `worldToScreen ∘ translate(origin)`.
- `apps/floor_planner/lib/main.dart`:
  - `PlannerShell` builds the document, camera, `ToolContext` (53) and
    `SelectTool` (59).
  - Undo is bound through `CallbackShortcuts` (102-105), and `_undo` does
    not look at the tool.
  - The top bar's `zoom-text` is at 126.

**A latent inconsistency this spec does not rely on.** `OutlineCache`
(`outline_cache.dart` 281-294) and `TileCache` (2096, 2127) place root-level
groups and instances through `tree.accumulatedTransform`, which includes the
root's transform. The canvas, the index and the oracle do not. Nothing
writes the root's transform today, so the two readings agree only because
it is the identity. This spec treats **world as root space** throughout and
never writes the root's transform. The disagreement is now closed by pinning
the root to the identity: `TransformNodeCommand` refuses the root handle
before it writes, and `validate()` reports a loaded root that is not the
identity as `tree.root_transform_not_identity` (Open questions).

---

## What this delivers

A selected object shows grips. Dragging a grip reshapes the object:
- a line's end or a polyline's vertex (a closed polyline's shared corner
  moves as one);
- a circle's radius;
- an arc's end or radius.

Three drags move or turn the whole selection:
- dragging a selected object's body moves it;
- dragging a circle's or arc's centre grip moves it;
- a rotation grip above the selection box rotates it.

While dragging:
- a live preview in the overlay;
- object snap, with markers;
- grid snap as the fallback;
- shift for ortho.

Releasing dispatches **exactly one** command, so one drag is one undo step.
Escape cancels with no document change. F3 toggles object snap.

## Non-goals

- **Scale.** Deferred (human). A non-uniform scale turns a circle into an
  ellipse the engine cannot store; a uniform scale has no floor-planner use
  yet.
- **Polar tracking.** Shift-ortho only (human).
- **Grips on leaves inside a group or an instance.** Selection is root-level
  (02's D2); a group or an instance moves and rotates as a whole.
- **Vertex insertion or deletion** on polylines.
- **Grips as widgets.** They are painted (D2); the accessibility cost is
  recorded as debt.
- **Excluding the dragged objects from snapping.** They stay snappable at
  their original position, as in AutoCAD's MOVE (D8).
- **Typed input**: no distance or angle entry during a drag.
- **Moving a shared grip as a joint.** When two selected objects have
  coincident grips, one wins (D2) and the other stays. A joint-aware stretch
  belongs to walls (07).

---

## Decisions

### D1 — Scope: move, reshape, rotate; no scale (human)

- **Move**: a translation of every selected object.
- **Rotate**: a rotation of every selected object about one pivot.
- **Reshape**: one grip of one root-level leaf.

Every move and rotate is a **rigid** transform (`det = +1`, orthonormal). A
circle stays a circle, an arc's sweep keeps its sign, and a text's height is
untouched.

### D2 — Grips live in `SelectTool`, painted in the overlay

Grip editing is part of selection mode, as in AutoCAD, not a separate tool.
`SelectTool` gains drag kinds. One drag's state and its command building
live in a new `GripDrag` class, so `select_tool.dart` does not absorb them.

Two options were rejected:
- **A `GripTool` swapped in whenever the selection is non-empty.** Every
  click would become a handoff between tools, and 02's `activate` contract
  is pinned by tests.
- **Grips as widgets.** A grip still has to hit-test in world space through
  the camera, and the painted overlay already exists. The cursor change
  widgets would have given for free costs one `ListenableBuilder` (D5).

**Press classification.** The first class that hits wins:

1. The **rotation grip** (D6), within `kGripHitPixels = 7.0` screen pixels
   of its centre, when it is drawn.
2. A **grip** of a selected object, within `kGripHitPixels` of its centre.
   Among several: the nearest, then the greater handle, then the lower grip
   index. **Coincident grips of two selected objects** (two walls meeting at
   a corner) resolve by that order: the greater handle's grip moves and the
   other object stays. This is v1's rule; a joint-aware stretch belongs to
   07.
3. The **pick**: the existing `pickInto` with `QueryFilter.picking`,
   resolved to a root key. **The single pick decides.** If it resolves to a
   selected key, the press is class 3a (a selected body). Otherwise it is
   class 3b (an unselected body). No second pass over the selection is
   made: an unselected object drawn above a selected one wins the press,
   exactly as it wins a click in 02.
4. **Empty space**: the existing band.

**A press that never moves `kBandSlopPixels` (4 px) is a click:**
- class 1 or 2: nothing happens on release;
- class 3a or 3b: selects or toggles as in 02;
- class 4: clears, as in 02.

**Past the slop:**
- class 1 starts a rotate;
- class 2 starts a reshape, or a move for a centre grip (D3);
- class 3a moves the selection;
- class 3b selects the object (`replace`, or `toggle` into the selection
  with shift) and then moves the selection;
- class 4 starts a band.

**Shift has two meanings at two times.** At the press it toggles (class 3b).
During the drag it means ortho, read per event. So a shift-press-drag on an
unselected object adds it to the selection and moves the selection
ortho-constrained from the first event. That is intended and tested.

**A drag needs its capability, checked at press.** A reshape, or a move or
rotate of a root leaf, needs `geometry`. A move or rotate of a group or an
instance needs `transform`. When `document.commands.permissions` denies it:
- leaf grips are not drawn and class 2 cannot occur;
- a move whose selection holds a leaf the permission refuses does not start
  (the press stays a click).

Under `DraftPermissions.runtime` a table instance can still be moved while a
wall cannot.

**Amended at execution (Plan 03, 2026-09-23):** two rulings.

**(1) Ruling 03-6.** The capability check "at press" runs when the press
crosses the slop, before any drag starts.
- For class 3b, the selection the drag would move is only known at that
  point: the current selection plus the key under a shift press, or that
  key alone.
- A refused check makes the press click-only. Later moves do nothing, and
  release acts as the 02 click.
- For class 3b, the selection is **not** changed at the slop crossing when
  the check refuses. The toggle runs once, at release, as the click.
- The rotation grip is drawn and hit under any permissions; this decision
  hides only leaf grips. A refused rotate simply never starts.

Permissions cannot change between a press and a 4 px move except by a test,
and D4's release check covers that case.

**(2) Ruling 03-9.** A centre grip moves the **whole selection**, not only
its own object. This follows exit criterion 4 ("a centre grip does the
same" as a body drag) rather than "What this delivers". The base is the
grip's own world point, exactly (D8), never the resolved press point.

### D3 — The grip set, per kind, in the engine

The grip set is defined in `packages/jet_cad_2d/lib/src/document/grips.dart`,
pure Dart. Grips are computed in the leaf's owner space. For a root-level
leaf that is root space, which is world (the preamble's note).

| kind | grips | role |
|---|---|---|
| point | none | body drag moves it |
| line | vertex 0, vertex 1 | stretch |
| polyline | every vertex `i`; for a **closed** polyline, the last vertex is omitted and vertex 0 stands for both | stretch |
| circle | centre | move |
| circle | quadrants 0..3 at `θ = q·π/2` | radius |
| arc | centre | move |
| arc | start (index 0), end (index 1) | stretch (angle) |
| arc | midpoint at `start + sweep/2` | radius |
| text, attrib, fill | none | text moves by body; attribs are never root-level; a fill follows its boundary |
| group, instance | none | body drag moves it; the rotation grip rotates it |

A polyline is **closed** when it has at least 3 points and its first and
last coordinate pairs are equal. That is a stored-value test, so it uses
`==`.

```dart
enum GripRole { stretch, radius, move }

final class Grip {
  const Grip(this.role, this.index, this.x, this.y);
  final GripRole role;
  final int index;       // vertex index; quadrant 0..3; arc end 0/1; else 0
  final double x, y;     // owner space
}

List<Grip> leafGrips(EntityKind kind, GeometryPayload payload);
bool isClosedPolyline(GeometryPayload payload);
```

**Reshape.** `GeometryPayload? reshapeLeaf(EntityKind kind,
GeometryPayload payload, Grip grip, Vector2 localTarget)` returns a new
payload. It returns **null when the result is degenerate**; the preview then
shows the object unchanged and release dispatches nothing.

- **Line or polyline, stretch `i`.** Writes `coords[2i] = target.x` and
  `coords[2i+1] = target.y`. On a closed polyline, `i == 0` also writes the
  last pair to the same values, so the loop stays closed. Every other
  coordinate and every scalar is **copied bit for bit**, never recomputed.
  Never degenerate: a zero-length segment is legal geometry. If the stretch
  makes a closed boundary unfillable, `SetEntityGeometryCommand` already
  drops its triangles and the painter counts a skip. The preview draws the
  outline only, so it cannot show that. Recorded for the look.
- **Circle, radius `q`.** `r = |target − centre|`. Null when
  `r <= Tolerance.standard.linear`. The centre is copied.
- **Arc, stretch 0 (start).**
  - `s' = atan2(target − centre)`. The end angle `e = s + sweep` stays.
  - `sweep' = wrap(e − s')`, **in the same direction as `sweep`**. For
    `sweep > 0`, `sweep'` is the value in `(0, 2π)` congruent to `e − s'`
    mod `2π`; for `sweep < 0`, the value in `(−2π, 0)`.
  - Null when `|sweep'|` is within `Tolerance.standard.angular` of `0` or of
    `2π`.
  - The centre and radius are copied bit for bit. The untouched end angle
    `s' + sweep'` equals the old `s + sweep` **within `Tolerance`**, not
    bit for bit, because it is derived.
- **Arc, stretch 1 (end).** `s` stays bit for bit. `sweep' = wrap(atan2(target
  − centre) − s)`, with the same direction and null rules.
- **Arc, radius.** `r = |target − centre|`, with the circle's null rule. The
  angles are copied.
- **Move grips are not reshapes.** `reshapeLeaf` throws `ArgumentError` for
  `GripRole.move`; the tool routes a centre grip to a move (D4).

**Rigid transform of a leaf.** `GeometryPayload rigidTransformLeaf(
EntityKind kind, GeometryPayload payload, Transform2 t)` takes `t` in the
leaf's owner space. It throws `ArgumentError` unless `t` is rigid: `|a·d −
b·c − 1|` and the column-orthonormality residuals must be within
`Tolerance.standard`. That is a decision, so it uses `Tolerance`. With
`θ = atan2(t.b, t.a)`:

- **point, line, polyline**: `payload.transformedBy(t)`.
- **circle**: the centre is transformed; the scalars are copied.
- **arc**: the centre is transformed; `startAngle + θ`; the radius and sweep
  are copied.
- **text**: the insertion point is transformed; `scalars[1] = rotation + θ`.
  A text stored with only its height (schema 3) gets `scalars[1]` written.
  That is a real edit of that entity, not padding on load, so
  `text_scalars.dart`'s no-padding rule is not broken.
- **fill, attrib**: throws `ArgumentError`.

A pure translation `(1, 0, 0, 1, dx, dy)` gives `x + dx` exactly for every
coordinate, since `0·y` is `0` for any finite `y`.

**Amended at execution (Plan 03, 2026-09-23):** an arc's derived end angle
is compared **modulo 2π** (Ruling 03-1). "`s' + sweep'` equals the old `s +
sweep` within `Tolerance`" cannot hold literally. `s' = atan2(…)` lies in
`(−π, π]`, and a stored `s` need not. For example, with `s = 4.0` and `sweep
= 1.0`, dragged to the direction `4.1`:
- `s' = 4.1 − 2π`;
- `sweep' = 0.9`;
- so `s' + sweep' = 5.0 − 2π`.

That is the same angle, but not the same double within 1e-9. The tests
therefore compare the `cos` and `sin` of the two angles within
`Tolerance.standard.angular`, and `grips_test.dart` carries this example.
Exit criterion 2's "an arc's derived end angle is equal within `Tolerance`"
means the same: the untouched end keeps its **direction**, which is what
"the end stays" means geometrically.

### D4 — What release dispatches

Nothing is dispatched during a drag (roadmap decision 1). On release, **one
`CompoundCommand`**, always, even for a single member, so the undo label is
right. An unwrapped `TransformNodeCommand` reads `Move` even for a rotate,
and an unwrapped `SetEntityGeometryCommand` reads `Edit geometry`. The
compound's label is `Move`, `Rotate` or `Stretch`.

| drag | per selected key | member command |
|---|---|---|
| reshape | the grabbed leaf only | `SetEntityGeometryCommand(h, reshapeLeaf(...))` |
| move / rotate, root leaf | each | `SetEntityGeometryCommand(h, rigidTransformLeaf(kind, p, T))` |
| move / rotate, root group or instance | each | `TransformNodeCommand(h, T.multiply(node.transform))` |

- **`T` is the drag's world transform**: `translation(Δ)` for a move, and
  `translation(p)·rotation(θ)·translation(−p)` for a rotate about pivot `p`.
- **World is root space** (the preamble). A root leaf's coordinates and a
  root-level node's `transform` are both already in it, so `T` applies to
  both directly. There is no conjugation.
- **Group and instance: `T.multiply(node.transform)`.** The drag is applied
  *after* the node's own transform. The reverse order agrees only when the
  node's transform is a pure translation, so the fixture's group is rotated
  (M-03i).
- **Members are ordered** by ascending `target` handle.
- **Fill keys are skipped** in a move or rotate. A fill follows its boundary
  through `SetEntityGeometryCommand`'s re-triangulation. A selection of
  fills only starts no drag and shows no rotation grip.
- **Permissions, again at release.** Every member's `capabilities` is
  checked against `document.commands.permissions` before anything executes.
  If any member is refused, the drag is cancelled whole and nothing is
  dispatched. This differs from Delete's rule (02's D10) on purpose: a move
  that leaves some objects behind silently breaks the alignment the user was
  dragging for. The press check (D2) makes this rare. This check covers a
  permission change mid-drag.
- **Revalidation at release.** At press, `GripDrag` captures what it will
  rewrite:
  - each leaf's stored payload (a `read` copy);
  - each node's `Node` value (`GroupNode`/`InstanceNode` `==` is exact
    component equality, `node.dart` 127-135).

  At release it re-reads them. If any target is gone or not `==` to its
  capture, the drag is cancelled and nothing is dispatched. This is the
  backstop for any document change mid-drag, whatever its source (D5).
- **A drag that changes nothing dispatches nothing.** That means any of:
  - `Δ == (0, 0)` exactly;
  - `θ == 0` exactly;
  - a null reshape;
  - a reshape whose payload is `==` the stored one.

  No empty undo entries are made.

### D5 — The interaction

- **Phases** stay `idle, pressed, dragging`. `dragging` gains a kind:
  `band`, `move`, `rotate` or `reshape`.
- **World from screen, every event.** The drag keeps its base point in
  **world** space and re-reads the pointer's world point from each event's
  `ToolPointerEvent.world`. It never scales a screen delta afterwards
  (M-03a).
- **Camera changes mid-drag.** A trackpad zoom or a middle-button pan
  produces no `ToolPointerEvent`. While a move, rotate or reshape drag is
  live, `SelectTool` therefore listens to `ctx.camera`. On each camera
  notification it re-resolves the target from the **last screen point**
  through the new camera, and it removes the listener when the drag ends.
  The object stays under the pointer through a zoom.
- **Cancel paths:**
  - Escape;
  - `PointerCancelEvent`;
  - `ToolController.activate` (which calls `cancel`);
  - `InteractionLayer` deactivate or dispose;
  - the release revalidation (D4).

  Each leaves the document byte-identical: the codec's output is equal
  before and after. **Pointer exit is not a cancel path.** `InteractionLayer`
  never forwards an exit while a pointer is captured (02's amended rule,
  pinned by its test), so a drag past the canvas edge continues. A
  selection change made at drag start (class 3b) stands after a cancel,
  because it is selection state, which is never undone.
- **Keys during a drag.** `SelectTool.onKey` returns
  `KeyEventResult.handled` for **every** key-down while
  `phase == dragging`, and cancels on Escape. The shell's cmd/ctrl+Z
  therefore never fires mid-drag, since the event stops at the layer. The
  release revalidation (D4) still guards against changes that do not come
  from a key.
- **Cursor.**
  - `Tool` gains `MouseCursor get cursor`, default `MouseCursor.defer`.
  - `InteractionLayer` wraps its `MouseRegion` in a `ListenableBuilder` on
    the `ToolController` and passes `cursor: tools.active.cursor`. That
    rebuilds only the `MouseRegion`, and only when the tool notifies.
  - `SelectTool`'s answers:
    - over a grip: `SystemMouseCursors.precise`;
    - over the rotation grip: `.grab`;
    - over a selected body, or during a move: `.move`;
    - during a rotate: `.grabbing`;
    - otherwise: `.defer`.
  - The idle hover already re-picks per move. The cursor value is cached,
    and the tool notifies only when it changes.
- **Hover** of a grip marks it (D6). Object hover (02) is suppressed during
  a drag.

**Amended at execution (Plan 03, 2026-09-23):** three changes to this
decision.

**(1) Ruling 03-8: `KeyRepeatEvent` is consumed during a drag too.**
"Every key-down" includes key repeats.
- A held cmd+Z auto-repeats as `KeyRepeatEvent`s, which are not
  `KeyDownEvent`s.
- The shell's `SingleActivator(keyZ, meta: true)` keeps the default
  `includeRepeats: true`, so a repeat that was not consumed would bubble up
  and undo mid-drag.
- Key-ups pass through: no shortcut acts on them.

**(2) The cursor is a mirror, not a builder on the `ToolController`**
(Task 7's fix round).
- `InteractionLayer` keeps a `ValueNotifier<MouseCursor>` that mirrors
  `tools.active.cursor`. A `ValueListenableBuilder<MouseCursor>` around only
  the `MouseRegion` renders it.
- **Why:** the layer's `deactivate` cancels a live drag, and the cancel makes
  the tool notify. A `ListenableBuilder` on the `ToolController` then asked
  for a rebuild of a subtree that was leaving the tree, and Flutter asserted
  (`markNeedsBuild` during build) when the layer was removed mid-drag.
- The mirror **goes quiet while the layer leaves the tree**: `deactivate`
  and `dispose` set a leaving flag, and `activate` clears it and re-reads
  the cursor. `didUpdateWidget` moves the listener when the
  `ToolController` instance changes.
- It still rebuilds only the `MouseRegion`, and only when the cursor value
  changes, as this decision intends.

**(3) The press-time grip is found again at the slop** (Task 7's fix
round).
- The press records a `GripRef` (key, grip, ordinal), not a list index.
- When the press crosses the slop, the grip is looked up again in the
  current `GripCache`. It matches only on the same key, the same ordinal and
  an equal `Grip` (exact `==`).
- For a rotation-grip press, a null box counts as no match.
- If there is no match, the press becomes a click. An undo inside the slop
  can remove or change the grabbed object, and a stale index would then name
  another object's grip or throw a `RangeError`. With this rule the press
  does nothing: no throw, no drag, no command.

### D6 — Grip rendering and the selection box

`GripCache` (render layer) is a `ChangeNotifier` built from the document,
the `SelectionController` and the `OutlineCache`. It is rebuilt at
selection-change and document-change rate. It holds:

- **The world grips** of every selected root leaf, from `leafGrips`, in
  doubles.
- **The selection box**: the world AABB of the selection, in doubles.
  - `OutlineCache` gains `Aabb2? worldBoundsOf(SelectionKey)`, computed from
    its world records, never from a `ui.Path`:
    - `_Segments`: the min and max of their coordinates;
    - `_Arc`: `arcBounds` from `primitives.dart`;
    - `_Point`: its position.
  - The box is the union over the selected keys.
  - `OutlineCache` already walks leaves, instances and nested groups through
    their transforms, so the box is the outline the user sees selected.
  - The cache is rebuilt at selection-change rate, independent of any paint
    origin.
- **A cap.** When the selection's grip count exceeds `kMaxGrips = 400`, no
  leaf grips are shown; body move and rotate still work. A polyline with
  thousands of vertices must not turn the overlay into a per-vertex frame.

**The shell owns `OutlineCache` and `GripCache`**, moved from
`PlannerView`. They are constructed after the `SelectionController`, keeping
`OutlineCache`'s listener-order rule (`planner_view.dart` 43-44), and handed
to `PlannerView` and to `ToolContext`.

The overlay painter draws, in screen space, after the outlines:

- **Stretch and radius grips**: squares with side `kGripPixels = 8.0` in
  `kGripColor`. Move grips are the same squares in `kGripMoveColor`.
  - Both are drawn with **`Canvas.drawRawPoints(PointMode.points, …)`**,
    with a square stroke cap and `strokeWidth = kGripPixels`.
  - The points come from a `Float32List` owned by the painter and reused,
    grown only when the grip count grows. Each is projected in doubles and
    rebased by the frame origin before narrowing.
  - That is one draw call per colour, **independent of the grip count**,
    and no `Rect` or `Offset` per grip.
- **The hot grip**: the hovered grip, and the grabbed one during a drag, in
  `kGripHotColor`. One more `drawRawPoints` of one point.
- **The rotation grip.**
  - A circle of `8.0` px diameter, `kRotationGripOffset = 24.0` px above
    the top-centre of the **screen-space** bounding box of the selection
    box's four projected corners, joined to it by a 1 px line.
  - Under a rotated camera, "above" means screen-up. The pivot is always
    the **world** box's centre.
  - Drawn only when `ctx.grips` is non-null and the selection holds at
    least one non-fill key.

**Amended at execution (Plan 03, 2026-09-23):** two rulings.

**(1) Ruling 03-10: the grip point buffers are sized exactly** and are
reallocated only when the count changes. "Grown only when the grip count
grows" is superseded.
- `drawRawPoints` draws its whole list. A capacity-grown buffer would need a
  `sublistView` per frame, which is one allocation per draw call. It would
  also draw stale grips if it were used whole.
- Exact sizing reallocates only at selection-change rate, so steady frames
  allocate nothing.
- "Rebased by the frame origin before narrowing" is met differently: grips
  are projected world → screen in doubles, and only the screen coordinates,
  which are small, are narrowed to float32. No world coordinate reaches
  float32, and that is the property the sentence protects.

**(2) Ruling 03-15: `GripCache.rotatable` is `box != null`.**
- A fill has no outline of its own (`OutlineCache._addLeaf` returns for a
  fill), so a fills-only selection has no box.
- "At least one non-fill key" is therefore implied by a non-null box.
- A separate non-fill flag would be an equivalent, unkillable mutant.

### D7 — Preview

The canvas keeps drawing the original, because nothing in the document
changes until release. The overlay draws the preview in `kPreviewColor` on
top:

- **Move or rotate.**
  - `Tool` gains `Transform2? get selectionPreviewTransform`, default null.
  - The overlay painter draws the selection's cached outlines a second time
    through **`worldToScreen ∘ T ∘ translate(origin)`**, composed in doubles
    into a second reused `Float64List`. The paths hold `world − origin`, so
    `T` must sit between the camera and the rebase. The reviewers' `matrix ∘
    T` would rotate about the rebase origin (M-03u).
  - A selected `point` has no path. Its cross is drawn at
    `T(worldPointOf(key))`.
  - No path is rebuilt. The preview allocates nothing per frame beyond what
    02's overlay already does.
- **Reshape.** One `ui.Path` is built per frame from the preview payload of
  the one entity, **in rebased world coordinates**. It is drawn under the
  overlay's existing matrix, so arc angles go in unchanged: the camera's
  y-flip and rotation are the matrix's business. This is a fixed cost per
  frame, independent of the document and the selection size. It is drawn by
  `SelectTool.paintOverlay`, which receives the origin through the painter.
- A 1 px line from the base point to the snapped target, and the snap
  marker (D9) at the target.

**Amended at execution (Plan 03, 2026-09-23):** the reshape preview is drawn
through a new hook, **`Tool.paintWorldOverlay(Canvas canvas, Vector2 origin,
double scale)`**, with a no-op default (Ruling 03-3).
- "`SelectTool.paintOverlay`, which receives the origin through the
  painter" could not be built. `paintOverlay(Canvas, ViewportTransform,
  Size)` has no origin parameter, and `tool_controller_test.dart`'s
  `_CountingTool` implements that exact signature.
- The overlay calls the new hook inside its existing `save … transform(_matrix)
  … restore` block, and hands it the frame's origin and scale.
- `SelectTool` builds the path in `world − origin` under the overlay's own
  matrix, as this decision intends.

No existing implementer changes.

### D8 — Snap during a drag: object, then ortho-overridden, then grid

Pure Dart, in `packages/jet_cad_2d/lib/src/index/drag_snap.dart`:

```dart
const SnapMask kDragSnapMask = SnapMask(0x9F); // cheap | intersection
const double kSnapAperturePixels = 10.0;

final class DragPoint {            // caller-owned, reused, never held
  final Vector2 point = Vector2.zero();
  SnapKind? objectKind;            // non-null: an object snap won
  bool grid = false;               // the grid won
}

void resolveDragPoint({
  required Vector2 raw,            // the pointer, world
  required Vector2? orthoBase,     // non-null while shift is held
  required SpatialIndex index,
  required double apertureWorld,   // kSnapAperturePixels / camera.scale
  required bool objectSnap,        // F3
  required PageComponent? page,
  required double? gridStepMm,     // page.gridStepMm, else the adaptive minor ?? major
  required SnapResult scratch,
  required DragPoint out,
});
```

Resolution, in order:

1. **Ortho, in world axes.** With `orthoBase = b`, `c` is `raw` with the
   minor axis pinned to the base. If `|raw.x − b.x| >= |raw.y − b.y|`, `x`
   stays free and `c.y = b.y`; otherwise the reverse. Without it, `c = raw`.
   Under a rotated camera, world-axis ortho looks diagonal on screen. That
   is deliberate: the drawing's axes are the world's, not the view's.
2. **Object snap**, when `objectSnap` is on:
   `index.snapInto(raw, apertureWorld, kDragSnapMask, scratch)`.
   - It queries at the **pointer**, not at `c`, since the marker the user
     aims at is under the pointer.
   - A hit wins outright and **overrides ortho** (AutoCAD's rule):
     `out.point.setFrom(scratch.point)`. It copies at once, because the next
     query rewrites `scratch.point`.
3. **Grid**, when `page != null && page.snapToGrid && gridStepMm != null`:
   `out.point.setFrom(snapToGrid(c, gridStepMm, page))`. With ortho, the
   pinned axis is then written back from the base **after** the grid snap,
   so a shift-drag from an off-grid base stays exactly on its line (M-03q).
4. Otherwise `out.point.setFrom(c)`.

**Precedence.**
- An object snap within the aperture always beats the grid, whatever the
  two distances. That is Plan 04's D6, the standard CAD rule (M-03g).
- Between object snap kinds, the engine's kind-first order decides; this
  spec adds no rule of its own (M-03b fires against that order through a
  drag).

**Base point.**
- For a **grip**, the base is the grip's own world point, exactly.
- For a **body drag**, the press point is resolved by the same chain
  **without ortho**: an object snap, else the grid, else raw. With grid snap
  on, a body move from an on-grid object therefore moves by a lattice
  vector, `Δ = grid − grid`, and on-grid geometry stays on the grid (M-03s).

The move's `Δ = target − base`.

**Exactness.**
- **A stretch** writes the resolved target into the grabbed coordinate.
  Released near an endpoint, it lands on that endpoint **exactly** (`==`),
  since world is root space.
- **A move** computes `x + (t − b)` per coordinate. That is `t` to within
  one rounding, not always bit-equal, and the spec promises no more. The
  move test compares with `Tolerance`: it is a decision about where the
  geometry went, not a stored-value round trip.

**Dragged objects stay snappable** at their stored position. The stored
geometry does not move until release, so snapping to it means snapping to
what the canvas still draws. AutoCAD's MOVE behaves the same way.

**Rotate** uses no object or grid snap: `θ = atan2(pointer − p) −
atan2(press − p)`. With shift, `θ` rounds to the nearest multiple of `π/12`
(15°).

**Grid step when `gridStepMm` is set** (inherited from 04's D6). The drag
snaps to `gridStepMm` exactly, while the drawn grid's minor lines sit at a
fifth or a quarter of it. The snap therefore skips minor lines. That is
04's rule, kept, and recorded as an item for the look.

**Amended at execution (Plan 03, 2026-09-23):** the step has one home
(Ruling 03-11). `double? dragGridStepMm(PageComponent? page, double
pxPerWorldMm)` lives in `drag_snap.dart`, next to `resolveDragPoint`.
- It returns `page.gridStepMm` **exactly** when that is set.
- Otherwise it returns the adaptive `GridScale.pick(...)`'s `minorMm ??
  majorMm` at the current zoom.

That is 04's D6 rule, stated once. `resolveDragPoint`'s `gridStepMm`
parameter is fed from it, and sub-project 05 inherits both together.

### D9 — Snap markers

The marker is drawn in the overlay at the resolved target, in screen space,
with a 1.5 px stroke in `kSnapMarkerColor`. Its size is
`kSnapMarkerPixels = 10.0`. A fixed, small number of draw calls per frame.

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

- **`SnapSettings`** (render layer): a `ChangeNotifier` with
  `bool objectSnap` (default true) and `toggleObjectSnap()`. The shell owns
  it.
- **`ToolContext`** gains three **optional** named fields, so every 02 call
  site still compiles: `PageNotifier? page`, `SnapSettings? snap`,
  `GripCache? grips`.
  - With `grips == null`, no grip or rotation grip is drawn or hit.
  - With `snap == null`, object snap is on.
  - With `page == null`, there is no grid snap.

  02's tests keep their meaning.
- **F3.** The shell binds F3 in its existing `CallbackShortcuts` as
  `SingleActivator(LogicalKeyboardKey.f3, includeRepeats: false)`, calling
  `snap.toggleObjectSnap()`. The top bar shows `OSNAP` or `osnap off`
  (key `osnap-text`).
- **F3 in a browser.** Chrome binds F3 to find-next. Whether a browser still
  acts on it is an item for the look; if it does, the look's finding picks
  another key. A key-down that arrives mid-drag never reaches the shell
  (D5), so F3 cannot toggle during a drag.

### D11 — Undo is exact

Undo of a drag restores every stored value with `==`:
- `SetEntityGeometryCommand`'s inverse holds a `read` copy of the previous
  payload;
- `TransformNodeCommand`'s inverse holds the previous transform;
- a `CompoundCommand` undoes its members in reverse.

The test compares **payloads** with `GeometryPayload ==` (exact per double),
and **nodes** with `GroupNode`/`InstanceNode ==`. It never compares
`Transform2` with `==`, which is object identity (`transform2.dart`
123-126) and would pass for the wrong reason.

**M-03e** makes the payload comparison use `Tolerance`. That is expected to
**stay green**, and is recorded as the designed survivor. Its companion
check then perturbs one restored coordinate by 1 ulp: the `==` test must go
red and the `Tolerance` one must stay green. That proves `==` is what the
test enforces.

### D12 — What this changes in 02's behaviour

- A press on an object followed by a drag used to do nothing
  (`select_tool.dart` 76). It now moves the selection (D2, classes 3a and
  3b).
- A click within `kGripHitPixels` of a selected object's grip used to
  replace-select or shift-toggle that object. It now does nothing (D2,
  class 2).
- Every key-down during a drag is now consumed by the tool (D5).

Any 02 test that pins the old behaviour is updated in the task that changes
it, with the reason in the test's name.

---

## Architecture

### Files

| file | responsibility |
|---|---|
| `packages/jet_cad_2d/lib/src/document/grips.dart` (new) | `GripRole`, `Grip`, `leafGrips`, `isClosedPolyline`, `reshapeLeaf`, `rigidTransformLeaf` |
| `packages/jet_cad_2d/lib/src/index/drag_snap.dart` (new) | `kDragSnapMask`, `kSnapAperturePixels`, `DragPoint`, `resolveDragPoint` |
| `packages/jet_cad_2d/lib/jet_cad_2d.dart` | exports |
| `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart` | `worldBoundsOf(key)` from the world records |
| `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart` (new) | world grips and the selection box, at selection- and doc-change rate; the cap |
| `packages/jet_cad_2d_flutter/lib/src/grip_drag.dart` (new) | one drag's state: base, target, `T` or preview payload, the press-time captures, `command()` |
| `packages/jet_cad_2d_flutter/lib/src/snap_settings.dart` (new) | `SnapSettings` |
| `packages/jet_cad_2d_flutter/lib/src/snap_marker.dart` (new) | `drawSnapMarker` |
| `packages/jet_cad_2d_flutter/lib/src/selection_style.dart` | grip, move-grip, hot-grip, preview and marker colours and sizes |
| `packages/jet_cad_2d_flutter/lib/src/tool.dart` | `ToolContext` optional fields; `Tool.cursor`, `Tool.selectionPreviewTransform` |
| `packages/jet_cad_2d_flutter/lib/src/select_tool.dart` | press classes, drag kinds, the camera listener, keys during a drag, cursor |
| `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart` | `ListenableBuilder` around the `MouseRegion` for the cursor |
| `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart` | grips via `drawRawPoints`, the rotation grip, the move/rotate preview matrix |
| `apps/floor_planner/lib/main.dart` | owns `SnapSettings`, `OutlineCache` (moved from `PlannerView`) and `GripCache`; F3; `osnap-text`; `ToolContext` fields; a test seam (below) |
| `apps/floor_planner/lib/planner_view.dart` | takes `OutlineCache` and `GripCache` from the shell; `GripCache` joins the overlay's repaint merge |

**Test seam.** `PlannerShell` gains optional constructor parameters
`DraftDocument? document` and `ViewportTransform? initialCamera` (defaults:
`startupPlan`, the nominal fit). `PlannerView` fits the camera once, after
its first frame (Ruling 04-16). A widget test therefore sets its rotated
camera **after the first `pump`**, and the test says so in a comment.

### Invariants

1. **No command during a drag.** `document.commands.undoDepth` is unchanged
   from the press to the last move event. Release adds exactly one entry, or
   none (D4's no-op, revalidation and permission rules).
2. **Every cancel path leaves the document byte-identical** (D5).
3. **Undo restores with `==`** (D11).
4. **Draw order is untouched.** No handle is allocated or freed by a drag;
   `SetEntityGeometryCommand` and `TransformNodeCommand` keep handles.
5. **The frame path is unchanged.** `query_allocation_test.dart` and
   `paint_allocation_test.dart` pass unchanged. A drag's per-move cost is one
   `snapInto` (zero allocation per candidate, by its own guarantee) and, for
   a reshape only, one preview path.
6. **The overlay's grip drawing is O(1) draw calls per frame**, independent
   of the grip count (D6). A spy-canvas test counts them.
7. **No `SnapResult.point` is held** past the call that filled it.
8. **Stored-value comparisons use `==`; placement decisions use
   `Tolerance`.** The decisions are: the degenerate-reshape rule, the
   rigidity check, the move test's landing check, and the arc's derived end
   angle.

**Amended at execution (Plan 03, 2026-09-23), invariant 5:** the per-move
cost names three more O(1) allocations (Ruling 03-12).
- `snapToGrid` returns a fresh `Vector2`.
- `GridScale.pick`, reached through `dragGridStepMm`, returns a fresh
  `GridScale`.
- The camera listener's `screenToWorld` returns a fresh `Vector2`.

All three happen once per pointer event or camera notification, never per
entity. The frame path (paint) of a move or rotate preview allocates nothing
beyond 02's overlay, and a reshape frame builds its one preview `Path`. So
"one `snapInto` … and, for a reshape only, one preview path" reads: one
`snapInto`, at most these three O(1) objects, and, for a reshape only, one
preview path. `query_allocation_test.dart` and `paint_allocation_test.dart`
pass unchanged.

---

## Testing

The fixture rules, stated once:

- **The camera.** Every tool and widget test runs under a camera that is
  zoomed (scale ≠ 1), panned (translation ≠ 0) and rotated (not 0, not
  90°).
- **Groups and instances.** A group whose own transform is a **rotation**,
  and **two instances of one definition**.
- **Arcs.** A non-zero start angle, and at least one with a **negative
  sweep**.
- **Polylines.** A **closed** one: a room, first point repeated as last.
- **Position.** Coordinates sit away from the origin, so the rebase origin
  is non-zero.
- **The root's transform stays the identity** everywhere (the preamble's
  note).

### Named mutants

| id | mutation | must go red |
|---|---|---|
| M-03a | the drag delta taken in screen space and scaled by `1/scale`, with no inverse camera | the move test under the rotated camera |
| M-03b | `_considerSnapCandidate` orders by distance before kind | a drag near a midpoint, with an endpoint also in the aperture, lands on the endpoint |
| M-03c | an instance drag rewrites the definition's leaves instead of the instance node | the two-instance test: the second instance is unmoved |
| M-03d | a command dispatched on every move event | the one-undo-entry test |
| M-03e | the undo assertion compares payloads with `Tolerance` | **the designed survivor**: stays green; its 1-ulp companion check goes red under `==` (D11) |
| M-03f | ortho keeps the minor axis free instead of the major | the shift-drag test |
| M-03g | the grid beats an object snap when the grid point is closer | the precedence test, with a grid point nearer than the endpoint |
| M-03h | `rigidTransformLeaf` leaves an arc's `startAngle` unchanged | rotate of an arc; the differential |
| M-03i | a node move composes `node.transform.multiply(T)` | the rotated-group move |
| M-03j | the rotation pivot is the world origin | rotate of a selection far from the origin |
| M-03k | a multi-move executes the permitted members when one is refused | a leaf and an instance selected, geometry refused at release, transform allowed: nothing moves |
| M-03l | Escape dispatches the pending command | the byte-identical cancel test |
| M-03m | `rigidTransformLeaf` leaves a text's rotation scalar unchanged | rotate of a text; the differential |
| M-03n | an arc end-grip stretch ignores the sweep's sign | the negative-sweep arc stretch |
| M-03o | a polyline stretch writes vertex `i + 1` | stretching a middle vertex moves it and nothing else |
| M-03p | release with `Δ == 0` still dispatches | a drag past the slop and back to the press pixel under an unchanged camera (the same pixel gives a bit-identical world point, so `Δ == 0`), and a body drag whose target snaps back onto its base: undo depth unchanged in both |
| M-03q | ortho does not re-pin the locked axis after the grid snap | a shift-drag from an off-grid base with grid snap on |
| M-03r | a closed polyline's corner stretch writes vertex 0 only | the room corner test: first and last pairs still `==` |
| M-03s | a body drag's base point skips the grid | the on-grid move test: every moved coordinate is still on the lattice |
| M-03t | release skips the revalidation | a command executed on the document mid-drag (the test calls `commands.execute` directly): release dispatches nothing |
| M-03u | the preview draws through `matrix ∘ T` | the recorded canvas transform under a rotation and a non-zero rebase origin |
| M-03v | the grips are drawn with one `drawRect` per grip | the spy-canvas draw-call count at 10 grips and at 300 grips is equal |
| M-03w | shift rounds the rotation to `π/6` | the 15° step test |
| M-03x | `objectSnap == false` still calls `snapInto` | with F3 off, a drag released near an endpoint lands on the grid, not on the endpoint |
| M-03y | `leafGrips` omits quadrant 3 | the grip-set test |
| M-03z | the cap compares with `>=` | exactly `kMaxGrips` grips are drawn; `kMaxGrips + 1` draws none |
| M-03aa | a key-down other than Escape is not consumed during a drag | cmd+Z pressed mid-drag through the shell: undo depth unchanged, the drag still live |

Every mutant is fired by a `cp`-backed scratch script, then restored and
checked with `diff`. The log is
`docs/superpowers/notes/plan-03-mutation-log.md`.

**Amended at execution (Plan 03, 2026-09-23):** two tables join the one
above.

**The plan's mutants, M-03ab…M-03ax (Ruling 03-17).** `CLAUDE.md` lands a
test only if a named mutation turns it red. Twenty-three tests guard spec
behaviour that the table above names no mutant for, so the plan named one
for each. M-03ah fires twice (`ah′`). The test ids are the plan's. The
render layer's files are relative to `packages/jet_cad_2d_flutter`, and the
engine's and the app's are marked. All were killed. M-03ai's ordinal clause,
dropped on its own, is **equivalent** by construction: the candidates are
built in ascending ordinal within each key, so the clause can never be true
where it is tested. The log records it as such.

| id | mutation | must go red |
|---|---|---|
| M-03ab | the cursor rendered straight off the tool, with no rebuild seam (re-expressed against D5's amended mirror: `MouseRegion(cursor: _tool.cursor, …)` with no `ValueListenableBuilder`) | `test/interaction_cursor_test.dart` I1: the `MouseRegion` follows the tool's cursor |
| M-03ac | `_enter` never adds the camera listener | `test/select_tool_drag_test.dart` T14: a camera change mid-drag re-resolves the target |
| M-03ad | `leafGripsLive` always true | `test/grip_cache_test.dart` C5; `test/select_tool_drag_test.dart` T13; `test/selection_overlay_grips_test.dart` P4 |
| M-03ae | the point cross ignores the preview transform | `test/selection_overlay_grips_test.dart` P5: the cross sits at `T(p)` |
| M-03af | F3 bound without `includeRepeats: false` | app `test/planner_grips_test.dart` A3: F3 held down toggles once |
| M-03ag | the endpoint and midpoint markers swap shapes | `test/snap_marker_test.dart` K1 |
| M-03ah | `worldBoundsOf`'s arc uses the full circle's square, not `arcBounds` | `test/outline_cache_test.dart` O1 (C2 compares against the same mutated `worldBoundsOf` and stays green) |
| M-03ah′ | `worldBoundsOf`'s point case contributes nothing | `test/outline_cache_test.dart` O1; `test/grip_cache_test.dart` C2 |
| M-03ai | the coincident-grip tie picks the lesser handle | `test/grip_cache_test.dart` C6; `test/select_tool_drag_test.dart` T10 |
| M-03aj | the reshape preview path built in absolute world, not rebased | `test/selection_overlay_grips_test.dart` P6 |
| M-03ak | the rotation grip hangs below the box | `test/grip_cache_test.dart` C7 |
| M-03al | `GripCache` never listens to the `OutlineCache` | `test/grip_cache_test.dart` C3 |
| M-03am | a fill is captured in a move | `test/grip_drag_test.dart` D9 |
| M-03an | the members keep the selection's order, not ascending handle | `test/grip_drag_test.dart` D1 |
| M-03ao | `cancel` dispatches the pending command | `test/select_tool_drag_test.dart` T16, W1, W3 (and T15) |
| M-03ap | a pointer exit cancels a captured drag | `test/select_tool_drag_test.dart` W2; 02's `interaction_layer_test.dart` "a drag that leaves the box keeps its captured pointer" |
| M-03aq | the hot grip is never drawn | `test/selection_overlay_grips_test.dart` P2 |
| M-03ar | the snap marker drawn at the last screen point, not the target | `test/selection_overlay_grips_test.dart` P8 |
| M-03as | a grip hit is recorded but the class falls through to the pick (re-expressed against the `GripRef` of D5's amendment) | `test/select_tool_drag_test.dart` T1 |
| M-03at | a centre grip moves only its own object | `test/select_tool_drag_test.dart` T8 |
| M-03au | a reshape ignores the snap and takes the raw point | `test/select_tool_drag_test.dart` T9; app `test/planner_grips_test.dart` A1 |
| M-03av | a drag starts without its capability check | `test/select_tool_drag_test.dart` T13 |
| M-03aw | `dragGridStepMm` ignores the page's fixed step | engine `test/index/drag_snap_test.dart` S8 |
| M-03ax | `rigidTransformLeaf` applies a non-rigid transform | engine `test/document/rigid_transform_test.dart` R5 |

**The controller's mutants, M-03ay…M-03bg, from the task reviews.** Each
review finding that named an unguarded behaviour got a mutant. Seven new
tests landed for them, each in its own commit. M-03bc and M-03bd were
already guarded. All were killed.

| id | mutation | must go red |
|---|---|---|
| M-03ay | `_degenerateSweep` drops its near-2π branch | engine `test/document/grips_test.dart`: an arc end stretch landing within tolerance of a full turn is degenerate (new) |
| M-03az | `resolveDragPoint` no longer resets `objectKind` and `grid` | engine `test/index/drag_snap_test.dart`: a reused `DragPoint` clears them between calls (new) |
| M-03ba | `GripCache` rebuilds on a hover-only selection notification | `test/grip_cache_test.dart`: a hover change does not reset `hot` (new; Ruling 03-19) |
| M-03bb | `hitTest` keeps the farther grip (`d > bestDistance`) | `test/grip_cache_test.dart`: `hitTest` picks the nearer object (new) |
| M-03bc | `_endDrag` never removes the camera listener | `test/select_tool_drag_test.dart` T14, extended: one camera listener per live drag (Ruling 03-7) |
| M-03bd | a centre grip's base is the resolved press point, not the grip | `test/select_tool_drag_test.dart` T8, pressed 5 px off the grip |
| M-03be | class 3b toggles the selection before the capability check | `test/select_tool_drag_test.dart`: a refused 3b move toggles once, at release (new; Ruling 03-6) |
| M-03bf | the grip buffer is reallocated every frame | `test/selection_overlay_grips_test.dart`: the buffer is reallocated only when the count changes (new; Ruling 03-10) |
| M-03bf′ | the grip buffer only grows (`<` for `!=`) | the same test: 300 grips then 10 draws 10, not 300 stale points |
| M-03bg | the arc reshape preview drops the origin from its centre | `test/selection_overlay_grips_test.dart`: an arc reshape preview is rebased too (new) |

**Amended at execution (Plan 03, 2026-09-23), final fix wave:** the final
whole-branch review found five more unguarded behaviours, M-03bh…M-03bl.
All five were killed. M-03bl guards a production fix: a shift key-down or
key-up mid-drag now re-targets from the last screen point at once, where it
used to wait for the next pointer move. `GripDrag._capture`'s `read` →
`peek` was fired too and is **equivalent** by construction:
`GeometryStore.replace` installs fresh buffers, so a captured view never
sees a later edit. The tally is 68 exercised: 65 killed, M-03e the designed
survivor, and 2 equivalent.

A y-flipped rotation is a reflection, so `gripCamera`'s matrix has `b == c`
bit for bit, and an `m.b`/`m.c` transposition cannot be seen under it.
M-03bh's test therefore also runs under `gripCamera(flipY: false)`.

| id | mutation | must go red |
|---|---|---|
| M-03bh | `_paintGrips` projects x with `m.b` for `m.c` | `test/selection_overlay_grips_test.dart` P2, extended: every drawn grip pair equals its grip's screen point, under both cameras |
| M-03bi | the rotation disc is drawn at its anchor, not its centre | `test/selection_overlay_grips_test.dart` P4, extended: the disc's centre and 4 px radius |
| M-03bj | the circle reshape preview drops the origin from its centre | `test/selection_overlay_grips_test.dart`: a circle reshape preview is rebased too (new) |
| M-03bk | a hover from grip to grip of one object does not notify | `test/select_tool_drag_test.dart`: grip-to-grip hover repaints once (new) |
| M-03bl | a shift key mid-drag sets `_lastShift` but does not re-target | `test/select_tool_drag_test.dart`: shift pressed or released mid-drag re-targets at once (new) |

### Differential check

`rigidTransformLeaf` is checked against an oracle that shares no code with
it:
- For each kind (point, line, polyline, circle, arc, text), sample points on
  the original curve, **computed independently from the stored values**:
  the arc's points from `centre + r·(cos, sin)` over its sweep, the text's
  baseline direction from its rotation.
- Transform them with `T`, and compare them with the same samples taken from
  the transformed payload.
- The tolerance is scaled to magnitude:
  `|a − b| <= max(1e-12, 256 · 2⁻⁵² · max(|a|, |b|))`. At the trial range's
  2e6 that is about 1.1e-7, well under anything visible, and it cannot hide
  an angle error, which moves a point by `r · Δθ`.
- Seed `0x5EED0003`, 200 trials, rotations drawn from `(−2π, 2π)` excluding
  multiples of `π/2`, translations up to `1e6`.

The trial count, the seed and the worst residual per kind are pasted into
the results note.

**Amended at execution (Plan 03, 2026-09-23):** the tolerance's scale is
**`max(2e6, |a|, |b|)`**, not `max(|a|, |b|)` (Ruling 03-16). The bound is
`|a − b| <= max(1e-12, 256 · 2⁻⁵² · max(2e6, |a|, |b|))`.
- A rotated sample can land near zero while its operands sit near 2e6.
  Cancellation then leaves about 1e-10 of absolute error against a 1e-12
  floor, and at 200 trials that failed spuriously a few times per run.
- `2e6` is the trial range this section already names, so the bound becomes
  the "about 1.1e-7" stated above everywhere.
- It still cannot hide an angle error: the smallest mutated error is `r·θ ≥
  1 × 1.5e-3`.

The run recorded worst residuals of 0.0 (point), 2.9e-10 (line) and 4.7e-10
(polyline, circle, arc, text) in the Plan 03 results note.

### Widget tests

The drag is tested end to end through `PlannerShell` (via the test seam):
1. press, move past the slop, move, release;
2. cmd+Z through the shell's binding;
3. F3, then a drag that no longer object-snaps;
4. cmd+Z pressed mid-drag (M-03aa).

The camera is set after the first `pump`.

---

## Exit gate

1. `leafGrips` returns D3's set for every kind, in owner space, including
   the closed-polyline rule.
2. A stretch moves the grabbed coordinate and nothing else. Coordinates and
   scalars are bit-equal elsewhere, and an arc's derived end angle is equal
   within `Tolerance`. This covers a line, a polyline's middle vertex, a
   closed room's corner, both arc ends (both sweep signs) and the radius
   grips.
3. `rigidTransformLeaf` passes the differential (the seed, 200 trials, the
   scaled tolerance).
4. A body drag moves the whole selection; a centre grip does the same. With
   grid snap on, on-grid geometry stays on the grid.
5. A move of a rotated group and of an instance composes
   `T.multiply(node.transform)`. The definition and the other instance are
   untouched.
6. A rotation turns about the selection box's centre, the box computed in
   doubles (arcs by `arcBounds`, points by position). Shift steps 15°.
7. One drag is one undo entry, always a `CompoundCommand` labelled `Move`,
   `Rotate` or `Stretch`. A drag that changes nothing adds none.
8. Undo restores with `==` (D11, including M-03e's survivor audit and its
   1-ulp check).
9. Escape, pointer-cancel, tool activation and release revalidation each
   leave the document byte-identical. A drag past the canvas edge continues.
10. Released near an endpoint, a stretch lands on it exactly. Object snap
    beats the grid. Ortho is overridden by an object snap and re-pinned
    after a grid snap. F3 off disables object snap.
11. Permissions are checked at press (no grips, no drag) and all-or-nothing
    at release.
12. The overlay draws grips in O(1) draw calls, and the cap holds at
    `kMaxGrips`.
13. Every named mutant M-03a…aa is fired and killed, except M-03e, which is
    recorded as the designed survivor with its 1-ulp check red. All are in
    the mutation log.
14. The allocation invariants pass unchanged.
15. The four gate lines are green (`CI=true`), with only the five standing
    `text_ladder_golden_test.dart` failures, and both app builds succeed.
16. A human looked, on macOS, in Chrome and in Firefox from `build/web`.

## Open questions

- **The root's transform (debt, pre-existing) — resolved, pinned to the
  identity.** `OutlineCache` and `TileCache` apply it to root-level nodes,
  while the canvas, the index and the oracle do not. Fixed on its own
  branch, `fix/root-transform-identity`, not by this plan: the rule is that
  the root's transform is the identity, enforced at both places a node
  transform can be written — `TransformNodeCommand` throws `StateError` on
  the root handle before any write, and `validate()` reports a loaded
  document whose root is not a bit-exact identity
  (`ValidationCodes.rootTransformNotIdentity`). Making every walk apply it
  was rejected: it widens the hot path for a transform nothing needs. See
  [the note](../notes/2026-09-23-root-transform-pinned.md).
- **F3 in a browser.** Chrome binds F3 to find-next. If the framework's
  handled key does not suppress it, the look picks another key.
- **Grips as widgets.** Painted grips give up screen-reader and keyboard
  access that widgets would have had. Recorded as debt for 12 (the app
  shell), which owns accessibility.
- **Snapping to the dragged object's ghost.** Kept (D8). If the look finds
  it sticky, the fix is an exclusion set on `snapInto`. That is an engine
  query change with its own allocation argument, not a tweak here.
- **Move exactness.** A move lands within one rounding of the target, not
  bit-exact (D8). When a snapped vertex must coincide exactly with another
  object's vertex, stretch it instead; a stretch is exact.
- **The preview of an unfillable room** shows the outline, not the lost
  fill (D3). An item for the look.
- **Grid snap with a fixed `gridStepMm`** skips the drawn minor lines (D8).
  An item for the look.

## What this changes outside 03

- `Tool` gains two members with defaults, and `ToolContext` three optional
  fields. No existing implementer or call site changes.
- `OutlineCache` gains `worldBoundsOf` and moves from `PlannerView` to the
  shell.
- `PlannerShell` gains a test seam (two optional parameters).
- `SelectTool`'s press behaviour changes as D12 lists.
- 05 inherits `resolveDragPoint` for placing points while drawing. 11
  inherits `leafGrips` for dimension grips.
