# Drawing tools — design

**Date:** 2026-09-23. **Status:** design, **revision 2**, not yet a plan.
Revision 1 (`f71f469`) was reviewed the same day by two independent
reviewers, Codex CLI (`gpt-5.5`) and Copilot CLI. Every finding was
re-checked against the tree and is recorded, with its ruling, in
[2026-09-23-drawing-tools-spec-review-r1.md](../notes/2026-09-23-drawing-tools-spec-review-r1.md).
Revision 2 applies them all. Three were blockers:
- **Shell shortcuts above a `TextField` take its letters.** D9 now guards
  the field with `DoNothingAndStopPropagationTextIntent` and moves it out
  of the `InteractionLayer`.
- **A self-intersecting polyline triangulates to an *empty* list, not
  null.** D11 now treats an empty polyline triangulation as "cannot fill".
- **The text field's commit and cancel rules contradicted each other.** D9
  now owns the controller in the tool and fixes one rule.
**Sub-project:** `roadmap/05-drawing-tools.md`. **Size:** M.
**Brainstormed with the human on 2026-09-23**, on `main` at `703bffe`. By
then Plan 03 was merged at `c5173e0` and its look had closed 16 of 16. Its
three fix branches were merged at `59e3811`, `9212793` and `7c96e11`.
**Depends on:**
- 02 (merged at `8c62db3`): the tool API;
- 03 (merged at `c5173e0`): `resolveDragPoint`, the snap markers and
  shift-ortho.

**Blocks:** 09 (symbol library), 12 (app shell).

**Evidence of record.** Every claim below about what exists was read from
the tree at `703bffe` on 2026-09-23.

- `packages/jet_cad_2d_flutter/lib/src/tool.dart`:
  - `ToolPointerEvent` 18 has `screen`, `world`, `pointer`, `buttons`,
    `shift`, `control`, `meta`, `alt` and `pickRadiusWorld`. It has **no
    click count and no timestamp**.
  - `ToolContext` 43 has `document`, `index`, `camera` and `selection`. It
    also has an optional `page` (null means no grid snap), an optional
    `snap` at 63 (null means object snap on) and an optional `grips`.
    `execute` is at 69.
  - `Tool` 77 declares these members:
    - `onPointerDown/Move/Up` and `onPointerExit`;
    - `onKey`, which returns a `KeyEventResult`;
    - `cancel`;
    - `paintOverlay` (screen space, 86) and `paintWorldOverlay`
      (`world − origin`, 99);
    - `cursor` and `selectionPreviewTransform`.

    It has no activate/deactivate hook and no hover callback. A hover
    arrives as `onPointerMove` with `buttons == 0`.
  - `ToolController.activate` 114 cancels the outgoing tool, swaps and
    notifies once. It has no stack and no default tool.
- `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart`:
  - It is a raw `Listener` with one captured pointer, and only the primary
    button reaches the tool.
  - Keys arrive through `Focus(onKeyEvent: … _tool.onKey …)` (225-228). A
    key the tool reports as `ignored` bubbles up to the shell.
  - It has **no double-click detection**. Nothing in `packages/` or `apps/`
    measures click timing.
- `packages/jet_cad_2d/lib/src/index/drag_snap.dart`: `resolveDragPoint` 39
  resolves a point in three steps:
  1. ortho from `orthoBase` pins the minor axis;
  2. `index.snapInto` runs at the **raw** point, and a hit wins and
     overrides ortho;
  3. `snapToGrid` runs when the page snaps, re-pinning the ortho axis.

  `DragPoint` 17 is caller-owned and reused. `kSnapAperturePixels = 10.0`
  is at 14 and `dragGridStepMm` at 98.
- `packages/jet_cad_2d_flutter/lib/src/snap_marker.dart:10`:
  `drawSnapMarker` draws one shape per `SnapKind`, and `+` for the grid.
- `packages/jet_cad_2d/lib/src/document/commands.dart`:
  - **`AddEntityCommand` 35** takes a `record` and a `payload`, needs the
    `geometry` capability, and throws `DuplicateHandleError` on a used
    handle. It **does not allocate**: the caller calls
    `handleSeed.next()` (`core/handle.dart:61-83`).
  - **`AddRegionCommand` 505** creates a boundary and the fill beneath it
    as **one mutation**. `allocate` (529) takes the fill's handle first,
    so the fill draws under its boundary, and it lets the caller set the
    fill colour, fill transparency, boundary colour and boundary
    lineweight. It hard-codes the continuous linetype on both halves.
  - **`triangulationFor` 652** returns null, which `refusalReason`
    (602) refuses, for anything that is not a circle with `r > 0` or a
    **closed** polyline. For a closed polyline it returns
    `triangulateSimplePolygon`, which returns an **empty** list, never
    null, when the loop is self-intersecting or degenerate
    (`geometry/triangulate.dart:10-13, 39`). `AddRegionCommand` accepts
    that empty list, and the result is a region whose fill has no
    triangles. A circle's triangulation is **also** empty by design
    (`Int32List(0)`, 655).
- **Closedness is not a flag.** `isClosedPolyline`
  (`document/grips.dart:50`) calls a polyline closed when its first and
  last coordinate pairs are equal under `==`, with three or more points.
  `triangulationFor` applies the same test. `EntityFlags` has only
  `invisible`.
- **The arc's sweep is signed.** The payload is `[cx, cy]`; the scalars are
  `[r, start, sweep]` in radians, counter-clockwise when the sweep is
  positive (`geometry/primitives.dart:65-66`).
- **Text:**
  - The payload is the insertion point. The scalars are `[height, rotation,
    widthFactor, oblique]` (`document/text_geometry.dart:189-196`).
  - The string is `EntityRecord.text`.
  - `textStyle` defaults to `ReservedHandles.standardTextStyle` (5).
  - `textAttrs` is `packTextAttrs` (33), where 0 means left and baseline
    **with no override bits**. Scalars 2 and 3 (width factor and oblique)
    are read **only** when override bits 8 and 9 are set. Otherwise the
    style's `widthFactor` and `obliqueAngle` apply
    (`text_geometry.dart:191-196`).
  - **The height is in model units, as cap height.** The scale is
    `height / metrics.capHeight`, and `kCapHeightRatio = 0.7`
    (`text_metrics.dart:19`).
- **No current layer exists.** No identifier in `packages/` or `apps/`
  names one. `ReservedHandles` has `layerZero = 1` and
  `byLayerLinetype = 2`. Layer 0's colour is index 7, so a ByLayer fill
  would be solid black or white.
- `packages/jet_cad_2d/lib/src/document/page_component.dart`: "The model is
  millimetres regardless." `scaleDenominator` is at 86 and defaults to 50
  (100).
- `packages/jet_cad_2d/lib/src/core/tolerance.dart:23`:
  `Tolerance.standard` is `linear 1e-9`, `angular 1e-9`.
- `apps/floor_planner/lib/main.dart`:
  - `ToolController(initial: SelectTool(), …)`.
  - The `chrome-left` panel is an empty 240 px container.
  - `CallbackShortcuts` (136) binds meta+Z and ctrl+Z (undo; there is no
    redo) and F3.
  - The top bar shows the active tool's `name`.
  - **No tool other than `SelectTool` exists.**
- **Flutter** (SDK 3.27.3, `widgets/editable_text.dart:726-737`):
  "Shortcuts prevent text input fields from receiving their keystrokes as
  text input." A raw key goes to the focused node and then bubbles to its
  ancestors before it is offered as text input. The shell's
  `CallbackShortcuts`, an ancestor of anything in the planner view, would
  therefore take a bound letter from a focused `TextField`. The documented
  remedy is a nearer `Shortcuts` that maps the letter to
  `DoNothingAndStopPropagationTextIntent`
  (`default_text_editing_shortcuts.dart:328`).
- `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart:129-131`: a
  primary pointer-down anywhere in the layer's subtree calls
  `_focus.requestFocus()` and then forwards the event to the tool. A focus
  change is applied later, not synchronously.
- `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart`: the
  overlay paints the selection outlines, then the tool's
  `paintWorldOverlay`, the grips, and the tool's `paintOverlay`, **for
  whichever tool is active**.
- `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
  constructs only `DraftPainter` and `VerticesDrawSink` (140, 147). **It
  does not exercise `SelectionOverlayPainter`**, and so none of a tool's
  overlay.
- `apps/floor_planner/lib/startup_plan.dart`:
  - **Furniture (114-132):** seven rectangles, each drawn as four separate
    lines (the two kitchen counters overlap to form an L), and two
    circles. The outline colour is `_furnitureColor = TrueColor(0x8A6D3B)`
    at lineweight 25. There are no fills and no polylines.
  - **The furniture is emitted before the floor finishes (134-).** Draw
    order is ascending handle, so the tile and parquet lines draw over
    anything the furniture section creates.
- **03's spec** decided "shift for ortho" (:122), "Polar tracking.
  Shift-ortho only (human)" (:132), "no distance or angle entry during a
  drag" (:140), and "05 inherits `resolveDragPoint` for placing points
  while drawing" (:1087).

---

## What this delivers

A user can pick a drawing tool from a palette or with a one-key shortcut,
and place:
- a **line**, chained as in AutoCAD's LINE;
- a **polyline**, open or closed;
- a **rectangle**, which is a closed polyline;
- a **circle**: the centre, then the radius;
- an **arc**: the centre, the start, then the end, with the direction
  following the pointer;
- a single-line **text**, typed into an inline field.

With **Fill** on, a rectangle, a circle or a closed polyline is committed as
a filled region instead.

Every tool:
- shows a live rubber band;
- snaps each point through its own placed points first, then through 03's
  `resolveDragPoint`, exactly as it stands. D4 gives the order.
- shows the snap marker while hovering;
- commits exactly one command per finished shape;
- stays armed for the next shape.

Escape drops a shape in progress without touching the document. With
nothing in progress, it returns to Select.

**The sample plan's furniture** becomes filled regions drawn over the floor
finishes.

## Non-goals

- **Polar tracking.** Shift-ortho only, as 03 decided.
- **Typed lengths and angles** (numeric entry). It is a whole subsystem, so
  it is not in v1.
- **Text beyond placement**: multi-line text, editing a text after it is
  placed, and choosing a style, height, justification or rotation.
  Placement uses the defaults in D9, and editing belongs to 12's property
  panel.
- **A current layer, a colour or linetype picker, and a choice of fill
  colour.** New entities take the defaults in D2 and D13. Choosing belongs
  to 12.
- **Filling an existing shape after the fact.**
- **Three-point arcs, and a mode toggle between arc methods.**
- **Double-click.** The polyline and the line chain finish by clicking the
  last point again, which needs no click timing (D6).
- **Removing the last vertex with Backspace**, and undoing a vertex
  mid-shape.
- **Walls.** 07's walls are parametric and do not go through these tools.
  The sample plan's walls, doors, windows and floor finishes stay as they
  are.

## Decisions

### D1 — Each tool is a `Tool`; 02's API is unchanged (roadmap)

The six tools are `Tool` subclasses, switched by `ToolController.activate`.
They share an abstract `PlacementTool` (D3).

Nothing in `tool.dart`, `interaction_layer.dart` or `ToolController`
changes:
- **Returning to Select** needs no new hook. An idle drawing tool leaves
  Escape `ignored`, and the shell catches it (D5).
- **The Fill toggle** reaches a tool through its constructor, not through
  `ToolContext` (D13).

### D2 — What a new entity is (roadmap, human)

**The record.** A new unfilled entity is a root-level `EntityRecord` with:
- `owner`: the document's root handle;
- `layer`: `ReservedHandles.layerZero`;
- `linetype`: `ReservedHandles.byLayerLinetype`;
- `linetypeScale`: 1.0;
- `color`: `ByLayerColor()`;
- `lineweight` and `transparency`: `kByLayer`;
- `flags`: 0.

A text also gets `textStyle: ReservedHandles.standardTextStyle` and
`textAttrs: 0`: left and baseline, with no override bits. It therefore
**inherits** the width factor and the oblique angle from its style (D9).

**The handle** comes from `doc.handleSeed.next()` at the moment the command
is built, when the shape finishes:
- **An abandoned shape** consumes no handle.
- **Redo** re-executes the same command object, so the handle is stable
  across undo and redo.
- **Draw order** stays ascending handle, so a new entity draws above
  everything older.

**One finished shape is one command,** executed through
`ToolContext.execute`, so it is one undo step:
- an unfilled shape is an `AddEntityCommand`;
- a filled one is an `AddRegionCommand` (D13).

The line chain commits each segment as its own command.

**Amended by fix/post-07:** drafting stays ByLayer on layer 0, and layer 0
is ACI 7, which `aciToRgb(7)` makes `0xFFFFFF`: every drafted shape (and
06's boxes) painted white on white paper. AutoCAD's rule is now the
engine's: ACI 7 is the **foreground**, black on a light background and
white on a dark one, and only the host knows the background, so the host
gives it. `DocumentStyleResolver` takes an optional `foreground`
(`0xRRGGBB`, default `0xFFFFFF`, so nothing that does not pass one moves)
and draws ACI 7 in it by every route: the entity's own colour, ByLayer,
ByBlock, the document root. `TrueColor(0xFFFFFF)` stays white; `aciToRgb`
is unchanged. Beside it, `foregroundFor(argb)` picks black or white for a
background, whichever has the higher WCAG contrast ratio (relative
luminance, sRGB linearised; alpha ignored; a tie goes to black). The floor
planner's shell derives the foreground from the page's `background`: at
startup, and again whenever the page changes (a swatch, its undo or redo,
a load), building a new resolver only when the chosen foreground changes.
Drafting is black on White, Ivory and Grey and white on Blueprint; a
document without a page counts as white paper. Walls are not drafting:
they keep `kWallColor`, concrete black (07 D3). Pinned by the `ACI 7 is the
foreground` and `foregroundFor` groups in `style_resolver_test` and by
`A17`, `A20`, `A21` and `A22` in `planner_draw_test`.

### D3 — `PlacementTool`: the shared base

`packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`, `abstract
class PlacementTool extends Tool`.

**It owns:**
- `points`, the placed points: exact world `Vector2`s;
- a reused `DragPoint` for the hover and a reused `SnapResult` scratch;
- the last screen point;
- a flag for whether the hover is visible;
- a camera listener, attached only while a shape is pending. On a pan or
  zoom it re-resolves the hover from the last screen point, as
  `SelectTool._onCamera` does.

**Pointer handling:**
- `onPointerMove` (buttons 0 or primary) resolves a hover (D4) and
  notifies.
- `onPointerDown` (primary) resolves the point (D4) and calls
  `accept(point, ctx)`.
- `onPointerUp` does nothing.
- `onPointerExit` hides the hover marker and keeps the pending shape:
  placement is click by click, not a drag.

**Key handling (`onKey`):**
- **Escape:** mid-shape it calls `cancel` and returns `handled`. When idle
  it returns `ignored`, so it bubbles up to the shell (D5).
- **Enter:** goes to the subclass's `finish(ctx)`, which the line and
  polyline tools act on. It is `handled` mid-shape and `ignored` when idle.
- **Shift, down or up:** re-resolves the hover at once from the last screen
  point.
- **Every other key-down or repeat:** `handled` mid-shape, so undo and redo
  never land mid-shape (as 03 D5 does during a drag). `ignored` when idle.

**Other behaviour:**
- `cancel(ctx)` clears the points, detaches the camera listener and
  notifies. It never touches the document.
- `paintOverlay` (screen space) draws the hover snap marker with
  `drawSnapMarker` when the hover is visible.
- `paintWorldOverlay(canvas, origin, scale)` calls the subclass's
  `paintRubberBand` with `world − origin` coordinates (03's Ruling 03-3).
- `cursor` is `SystemMouseCursors.precise`.
- `phase` stays `ToolPhase.idle`; a tool's "pending" state is its own.

**Subclass hooks:**
- `Vector2? orthoBase` (D4);
- `Vector2? selfSnap(Vector2 raw, double apertureWorld)`, null by default
  (D6);
- `void accept(Vector2 point, ToolContext ctx)`;
- `void finish(ToolContext ctx)`;
- `void paintRubberBand(Canvas, Vector2 origin, double scale)`.

**Committing** goes through `commit(ctx, DraftCommand)`:
1. If `ctx.document.commands.permissions.allows(Capability.geometry)` is
   false, the shape is dropped and nothing is dispatched.
2. Otherwise the command goes to `ctx.execute`.

**Amended at execution (Plan 05, final review):** Ruling F-2. A key-down
of `LogicalKeyboardKey.f3` or `LogicalKeyboardKey.keyF`, with no control,
meta or alt modifier held (`HardwareKeyboard.instance`), returns
`KeyEventResult.ignored` even while a shape is pending, instead of the
`handled` this section's "every other key-down" rule would otherwise give
it. Both bubble to the shell, which toggles object snap (F3) or Fill (F);
neither ever touches the document, so the reason the rule swallows every
other key-down — keeping undo and redo off a half-placed shape — does not
apply to them. Without this, F3 (the only object-snap toggle) was
unreachable while a polyline was pending. Every other key-down mid-shape,
and both undo keys, stay swallowed exactly as this section says.

**Confirmed by the human's look (2026-09-24):** kept.

### D4 — Resolving a point

A raw world point `raw` from a `ToolPointerEvent` resolves **in exactly
this order**. The first step that produces a point wins.
1. **`selfSnap`.** Call `selfSnap(raw, kSnapAperturePixels /
   camera.scale)`. A non-null result is a stored placed point, returned
   itself. **It beats object snap**, even when an existing entity's
   endpoint is also inside the aperture and nearer. It carries **no marker
   kind**; the tool paints its own endpoint square for it.
2. **Otherwise, `resolveDragPoint`, unchanged**, exactly as
   `SelectTool._resolve` calls it. Its own order is:
   - ortho pins the minor axis from `orthoBase`;
   - `snapInto` at the **raw** point wins and overrides ortho;
   - otherwise the grid snap re-pins the ortho axis.

   The call is:

   ```
   resolveDragPoint(raw: raw, orthoBase: shift ? orthoBase : null,
       index: ctx.index, apertureWorld: kSnapAperturePixels / camera.scale,
       objectSnap: ctx.snap?.objectSnap ?? true, page: ctx.page?.value,
       gridStepMm: dragGridStepMm(ctx.page?.value, camera.scale),
       scratch: …, out: …)
   ```

   Its `point` is copied into the tool's storage and never re-derived from
   the screen.

**`orthoBase`, per tool:**
- line and polyline: the previous vertex;
- rectangle: the first corner;
- circle and arc: the centre;
- text: none;
- **any tool with no placed point yet: none.**

**The raw point is `ToolPointerEvent.world`,** which `InteractionLayer`
has already resolved through the inverse camera. **A tool never makes a
point from `event.screen`** (M-05a). It keeps the screen point only to
re-resolve a hover.

**Amended at execution (Plan 05):** Ruling 05-2. A self-snap's hover
marker is drawn through `drawSnapMarker(..., SnapKind.endpoint, ...)`,
the same function object snap itself uses, rather than a bespoke square
painted by the tool. The engine's own endpoint marker *is* the "own
endpoint square" this section calls for, so the base sets
`_hover.objectKind = SnapKind.endpoint` for a self-snap and draws through
the one marker function.

### D5 — Palette, shortcuts, and returning to Select (human)

**The palette** is `apps/floor_planner/lib/tool_palette.dart`, in the
existing `chrome-left` panel:
- A vertical list of seven buttons, keyed `tool-select`, `tool-line`,
  `tool-polyline`, `tool-rectangle`, `tool-circle`, `tool-arc` and
  `tool-text`, each labelled with its shortcut letter.
- Below them sits the Fill checkbox (D13), keyed `tool-fill`.
- The active tool is highlighted.
- The six drawing tools and Fill are **disabled** while the document's
  permissions deny `Capability.geometry`. The palette reads this when it
  builds. A permission change is not notified (the same limitation as 03's
  Ruling 03-5), so D3's commit check is the backstop.

**Shortcuts:** `V`, `L`, `P`, `R`, `C`, `A`, `T` and `F` (Fill), added to
the shell's `CallbackShortcuts` with `includeRepeats: false`.
- **A shell shortcut would win over a focused `TextField`** (see the
  evidence). The text field therefore carries its own guard (D9), so these
  letters reach the field as text.
- **The widget test must drive the field with real key events**
  (`sendKeyEvent` / `sendKeyDownEvent`), not `enterText`, which bypasses
  key dispatch and would hide the defect (M-05v).

**The shell owns the seven tool instances** for its lifetime. **Every
activation goes through one shell method, `_activate(Tool)`**: the palette,
the shortcuts and the Escape binding all call it, and nothing else calls
`tools.activate`. Activating a drawing tool does three things:
1. it clears the selection. `SelectionOverlayPainter` paints the selection
   outlines and grips for whichever tool is active, so this step is what
   keeps grips from showing while drawing;
2. it calls `tools.activate(tool)`;
3. it puts focus back on the canvas.

The render-layer tool tests don't depend on selection: their fixture
starts with an empty selection.

**Escape returns to Select.** An idle drawing tool leaves Escape as
`ignored`. It bubbles up to a shell-level `SingleActivator(escape)` binding,
which activates Select when a drawing tool is active. Select's own idle
Escape (clear the selection) is handled inside `SelectTool` and never
reaches the shell.

**The top bar** already shows `tools.active.name`: `Select`, `Line`,
`Polyline`, `Rectangle`, `Circle`, `Arc` or `Text`.

**Tools stay armed after each shape (human).** Finishing a shape re-arms
the same tool with no points placed.

**Amended at execution (Plan 05):** Ruling 05-6 (the palette and the Fill
checkbox are wrapped in `ExcludeFocus` and never take focus at all, rather
than acting on `InteractionLayer`'s focus node, which is private —
"focus stays on the canvas" holds because the canvas is `autofocus: true`
and re-takes focus on every pointer-down) and Ruling 05-8 (the shortcut
guard also wraps the page panel's scale field, and it also maps meta+Z
and ctrl+Z, so cmd+Z typed into either field never reaches the document).
Two findings from Task 7's fix round narrow this section further:
**Ruling T7-a**, spec D3 wins over this plan's own Review Focus 2 — every
key-down mid-shape is swallowed, so a tool shortcut does not switch tools
mid-polyline; switching mid-shape needs Escape first, or the palette, and
`ToolController.activate` cancels byte-identically either way. **Ruling
T7-c**, Escape joins the shortcut guard's map alongside the letters and
the undo keys, exactly as "Escape … as the shell binds them" requires —
without it, Escape typed into a focused field (the page-scale field, or
the text field of D9) dropped a pending shape at the shell instead of
being handled by the field itself.

### D6 — Line and polyline (human)

**Line** (`line_tool.dart`):
- **Clicks:** the first click places the start. Each further click places
  an end and commits one line `[start, end]`. That end becomes the next
  segment's start: **the same stored `Vector2` values, not re-resolved**
  (M-05k).
- **Clicking the current start again ends the chain, but only once the
  chain has committed at least one segment.**
  - `selfSnap` returns the current start when the pointer is within the
    aperture of it **and** the chain has committed at least one segment.
    `accept` treats receiving it as "finish".
  - **Before the first segment**, `selfSnap` returns null, so a second
    click on the start is resolved normally. It lands within
    `Tolerance.standard.linear` of the start, becomes a zero-length
    segment, and is **refused**; the tool keeps waiting. A first-point
    double-click therefore never exits the tool.
- **Enter or Escape** also ends the chain. Segments already committed
  stay; only the rubber band is dropped.
- **Any other zero-length segment** (length `<= Tolerance.standard.linear`)
  is refused, and the tool keeps waiting.
- **Fill** does not apply.

**Polyline** (`polyline_tool.dart`):
- **Each click** appends a vertex.
- **`selfSnap`** runs its checks in this order:
  1. the **first** vertex, when the pointer is within the aperture of it
     and at least three vertices are placed;
  2. otherwise the **last** vertex, when the pointer is within the aperture
     of it and at least two vertices are placed;
  3. otherwise null.

  So with one vertex placed, a second click on it is resolved normally. It
  is **ignored** as coincident (below), not a finish.
- **Receiving the first vertex closes the polyline.** It commits with the
  first point appended again: **the stored `Vector2` itself**, so
  `isClosedPolyline` holds under `==` (M-05i).
  - **With Fill on,** a closed polyline commits as a region (D13).
  - **When the fill is impossible,** meaning `addDraftedRegion` returns
    null because the loop self-intersects (D11), it commits as a plain
    closed polyline instead, and the tool paints nothing extra.
- **Receiving the last vertex (from `selfSnap`), or Enter with at least two
  vertices,** finishes it open. Enter with fewer is ignored. An open
  polyline ignores Fill.
- **A resolved click within `Tolerance.standard.linear` of the previous
  vertex** is ignored. `selfSnap` has already turned the "last vertex
  again" case into a finish before this check runs.
- **The rubber band** is the placed vertices plus a segment to the hover
  point, drawn as **one `Path`** with no `close()`.

### D7 — Rectangle and circle

**Rectangle** (`rectangle_tool.dart`):
- **Two clicks** set the opposite corners `c1` and `c2`.
- **The rectangle is axis-aligned in world (root) space.** Under a rotated
  camera it draws rotated on screen. No product camera rotates today; the
  tests do.
- **It commits a polyline** `[c1.x, c1.y, c2.x, c1.y, c2.x, c2.y, c1.x,
  c2.y, c1.x, c1.y]`. Every value is copied from `c1` or `c2`, so the
  closing pair `==` the first (M-05b). With Fill on, it commits as a region
  (D13).
- **It is refused** when `|c2.x − c1.x|` or `|c2.y − c1.y|` is
  `<= Tolerance.standard.linear`.
- **The rubber band** is the same outline drawn to the hover point.

**Circle** (`circle_tool.dart`):
- **The centre click, then a point on the circle.**
- **It commits a circle** `[cx, cy]` with scalars `[r]`, where `r` is the
  distance from the centre to the second point. With Fill on, it commits as
  a region (D13).
- **It is refused** when `r <= Tolerance.standard.linear`.
- **The rubber band** is the circle through the hover point, plus a 1 px
  radius line.

### D8 — Arc: centre, start, end, with the sweep following the pointer (human)

**The clicks** (`arc_tool.dart`):
1. **The centre `c`.**
2. **The start `s`,** which sets `r = |s − c|` and `start = atan2(s.y − c.y,
   s.x − c.x)`. It is refused when `r <= Tolerance.standard.linear`.
3. **The end `e`,** which only sets `end = atan2(e.y − c.y, e.x − c.x)`.
   The end point need not lie on the circle.

**`SweepTracker`** lives in the engine, in pure Dart (`drafting.dart`):
- `begin(double start)` resets the accumulated travel `τ` to 0 and sets the
  previous angle to `start`.
- `track(double a)` adds `wrap(a − previous)` to `τ` and sets
  `previous = a`:
  - `wrap` maps into `(−π, π]`, so no single step jumps the ±π seam;
  - `τ` is clamped to `[−2π + ε, 2π − ε]` with
    `ε = Tolerance.standard.angular`.
- `sweepTo(double end)` computes `δ = (end − start)` normalised into
  `[0, 2π)`:
  - if `δ` is 0 (under `Tolerance.standard.angular`), it returns **0**, and
    the caller refuses the arc;
  - if `τ >= 0`, it returns `δ`, counter-clockwise;
  - otherwise it returns `δ − 2π`, clockwise.

  The magnitude is always in `(0, 2π)`, and the sign is the direction
  travelled.
- **The tie-breaks are decisions, not accidents:**
  - **`τ == 0` exactly is counter-clockwise.** That covers an end click
    with no hover recorded after the start, and an out-and-back that
    cancels exactly. This matches AutoCAD's default direction. The sign
    comes from the **cumulative** `τ`, never from the last movement.
  - **A full circle is not an arc.** An end angle equal to the start
    gives `δ == 0`, and the arc is refused; the circle tool exists for
    that.
  - Both cases get **deterministic tests** of their own, because the
    differential check skips the travel near multiples of 2π.

**How the tool feeds it:**
- after the start click, `track` receives the **raw** pointer angle on
  every hover;
- the end click calls `sweepTo` with the **resolved** end angle;
- moving back past the start reverses the direction.

A zero sweep is refused, and the tool keeps waiting for another end click.

**The commit** is an arc `[c.x, c.y]` with scalars `[r, start, sweep]`,
start first (M-05e). **Fill does not apply.**

**The rubber band:**
- after the centre, a line from the centre to the hover point;
- after the start, the arc from `start` through `sweepTo(hover angle)`,
  plus two 1 px radius lines.

**Amended at execution (Plan 05):** Ruling 05-1. `SweepTracker`'s
accumulated travel `τ` is never clamped — only its sign is read, and
`sweepTo`'s magnitude already comes from `δ ∈ (0, 2π)`, never from `τ`, so
a clamp would bound nothing that needs bounding while losing the winding
(a clamped `τ` flips the sign on an out-and-back beyond a full turn: wind
`+3π`, the clamp holds `τ ≈ 2π`; come back `−2π`, `τ ≈ 0⁻`, reading
clockwise, when the true travel is `+π`, counter-clockwise). The
differential's skip rule follows from this: a trial is skipped when its
true travel is within `1e-6` of 0, or when `δ` is within `1e-6` of 0 or of
`2π` — the only cases where the sign or the zero-sweep refusal is a tie.

### D9 — Text: an inline field, 2.5 paper mm (human)

**`TextTool`** (`text_tool.dart`, extends `PlacementTool`):
- **The click** resolves the insertion point `p`, with no ortho, and sets
  `pending`, a `ValueListenable<TextPlacement?>`, to
  `TextPlacement(p, heightMm)`.
- **`heightMm`** is `textHeightMm(ctx.page?.value)`: `2.5 ×
  scaleDenominator` with a page, and 2.5 with none.
- **The tool owns the text.** `TextTool` holds `final
  TextEditingController controller`, created once for the tool's lifetime
  and cleared whenever `pending` is set or cleared. The field (below)
  edits this controller; it does not own it.
- **While `pending` is set,** the tool paints a small insertion cross at
  `p`.
- **A canvas click while `pending` is set commits.** `onPointerDown` calls
  `commitText(controller.text, ctx)` **synchronously**. It runs before the
  `InteractionLayer`'s `requestFocus` takes effect, because a focus change
  is applied later. The click does **not** start a new text.
- **`commitText(String s, ctx)`:** an empty `s` cancels. Otherwise it
  commits one text:
  - `text: s`, stored exactly as typed with no trimming;
  - `textStyle: standardTextStyle`, `textAttrs: 0`;
  - payload `[p.x, p.y]`, scalars `[heightMm, 0, 1, 0]`.

  Either way it clears `pending`.
- **Scalars 2 and 3 are padding.** With `textAttrs: 0` the width factor and
  the oblique angle come from the style, not from the payload (see the
  evidence). The `1` and `0` are written only so that the four-scalar
  layout is complete for a later editor. A test with a Standard style
  whose `widthFactor` is 0.8 proves the inheritance (M-05t).
- **`cancelText(ctx)`** clears `pending`, and so do `cancel` and a tool
  switch.
- **Fill** does not apply.

**The rule, stated once.** **Enter or a canvas click commits** a non-empty
string. **Escape, a tool switch, or any other loss of focus cancels.** The
field's blur handler cancels only when `pending` is still set. After a
canvas-click commit it is already clear, so the later blur finds nothing to
cancel.

**The stored height is a plain model height and the cap height.** Changing
the page scale later does not resize existing text; annotation scaling is
out of scope. It is the cap height, as DXF defines it (M-05c).

**The field** is `apps/floor_planner/lib/text_entry_overlay.dart`.
- **It sits outside the `InteractionLayer`.** The planner view's root
  becomes `Stack[CameraGestureDetector(… InteractionLayer …),
  TextEntryOverlay]`. So a click on the field is not a canvas click, and
  it never calls the layer's `requestFocus`.
- **It listens** to the text tool's `pending` and to the camera.
- **While `pending` is set,** it shows a single-line `TextField`, keyed
  `text-entry`, with autofocus, bound to `TextTool.controller`.
  - **Its baseline-left sits at `camera.value.worldToScreen(p)`** (M-05n).
  - **It is a stable `Positioned` child.** On a pan or zoom only its
    `left` and `top` are recomputed. The `TextField` element (its own
    `FocusNode`, its composing state) is **never rebuilt** by a camera
    change (M-05u).
- **The shortcut guard.** The field is wrapped in `Shortcuts` that maps
  every shell letter (`V L P R C A T F`, and Escape and Enter as the shell
  binds them) to `DoNothingAndStopPropagationTextIntent`. The letters stop
  there and reach the field as text input; they never reach the shell's
  `CallbackShortcuts` (M-05v).
- **Enter** (`onSubmitted`) calls `commitText(controller.text)`.
- **Escape**, from an `Actions`/`CallbackShortcuts` on the field, calls
  `cancelText`.
- **On blur** it calls `cancelText` if `pending` is still set.
- **Afterwards,** focus returns to the canvas.

**Amended at execution (Plan 05):** Ruling 05-8 (the shortcut guard above
also covers the text field, so cmd+Z / ctrl+Z typed there never reaches
the document — it maps to `DoNothingAndStopPropagationTextIntent`, which
only `EditableText` registers an action for) and Ruling 05-11 (the field
is 240×32 logical px, and "baseline-left" is approximated by the field's
bottom-left, which sits at the insertion point's screen position within
0.5 px). Two findings from Task 7's fix round narrow "any other loss of
focus cancels" above: **Ruling T7-b**, that phrase means a loss of focus
*inside* the app — while the app is not `resumed` the field ignores its
blur, and the focus manager restores it on resume with the text intact; a
`null` `WidgetsBinding.instance.lifecycleState` (its value before the
first lifecycle message arrives, and what `flutter_test` resets it to
before every test) counts as resumed, not as a cancelling loss of focus.
**Ruling T7-d**, the planner view's root is a `Flow`, not the `Stack`
named above (`Stack[CameraGestureDetector(… InteractionLayer …),
TextEntryOverlay]`) — with a literal `Stack`, removing the text overlay
mid-build while a text was pending raised "markNeedsBuild() called during
build"; a `Flow` orders the overlay's deactivation first, at the same
paint and hit order (`RenderFlow` hit-tests in reverse child order like
`Stack`, and is a repaint boundary that clips to its bounds the same
way).

### D10 — Escape, tool switches and edge cases

- **Leaving a shape unfinished never touches the document.** Escape,
  `ToolController.activate` (which calls `cancel`),
  `InteractionLayer.deactivate` and `dispose` all drop the pending shape
  and leave the document **byte-identical** by the codec snapshot.
- **Undo and redo mid-shape** are swallowed (D3). With nothing pending,
  they bubble up to the shell.
- **A pan or zoom mid-shape** re-resolves the hover. Placed points are
  world points and do not move.
- **Permissions** are checked at commit (D3), and the palette disables the
  tools (D5).
- **Stored values are copies.** The only arithmetic on placed points is
  inside the builders: the radius, the angles, and `2.5 ×
  scaleDenominator`. Every coordinate a payload stores is copied from a
  resolved `Vector2`.

### D11 — The engine builders

`packages/jet_cad_2d/lib/src/document/drafting.dart`, exported from
`jet_cad_2d.dart`:
- **`EntityRecord draftRecord(Handle handle, Handle owner, EntityKind kind,
  {String text = ''})`:** the defaults in D2.
- **`AddEntityCommand addDrafted(DraftDocument doc, EntityKind kind,
  GeometryPayload payload, {String text = ''})`:** allocates
  `doc.handleSeed.next()` and returns the command. It does not execute it.
- **`AddRegionCommand? addDraftedRegion(DraftDocument doc, EntityKind
  boundaryKind, GeometryPayload boundaryPayload, {DraftColor fillColor =
  kDraftFillColor, DraftColor boundaryColor = const ByLayerColor(), int
  boundaryLineweight = kLineweightDefault})`:**
  - It returns **null**, and allocates nothing, when **either** of these
    holds:
    - `triangulationFor(boundaryKind, boundaryPayload)` is null;
    - `boundaryKind` is `polyline` **and** that triangulation is
      **empty**, meaning the loop self-intersects or is degenerate (see
      the evidence).

    A circle's empty triangulation is its normal case and is **not** a
    refusal.
  - Otherwise it returns `AddRegionCommand.allocate(seed: doc.handleSeed,
    owner: root, layer: layerZero, fillTransparency: 0, …)`.
  - The sample plan passes its own boundary colour and lineweight (D14).
- **`const DraftColor kDraftFillColor = TrueColor(0xE6E1D8)`**, an opaque
  light warm grey (D13).
- **The payload builders:**
  - `GeometryPayload linePayload(Vector2 a, Vector2 b)`;
  - `polylinePayload(List<Vector2> points, {bool closed = false})`;
  - `rectanglePayload(Vector2 c1, Vector2 c2)`;
  - `circlePayload(Vector2 c, double r)`;
  - `arcPayload(Vector2 c, double r, double start, double sweep)`;
  - `textPayload(Vector2 p, double heightMm)`.
- **`final class SweepTracker`** (D8).
- **`double textHeightMm(PageComponent? page)`** (D9).
- **The degeneracy predicates,** each under `Tolerance.standard`.

Every builder copies its input coordinates and never transforms them. None
holds an `EntityRecord`, which is a view.

### D12 — The frame path

- **The rubber band** is **at most one `Path` per frame**, built from the
  handful of placed points, whatever the size of the document.
- **The hover marker and the insertion cross** use the reused buffers and
  `Paint`s of 03's `drawSnapMarker` idiom.
- **Nothing is allocated per entity.** `query_allocation_test.dart` and
  `paint_allocation_test.dart` stay **unedited and green**. They do **not**
  cover the overlay (see the evidence), so the overlay has its own
  structural gate:
  - **the same calls regardless of document size:** a tool's overlay draw
    calls (their names, in order) are identical for a 10-entity and a
    1,000-entity document with the same pending shape;
  - **one rubber-band path:** a 5-vertex pending polyline is exactly **one**
    `drawPath` in the preview colour.

  That is 03's invariant-6 pattern, and M-05s must turn it red.

### D13 — Fill: one toggle, one colour, one region command (human)

**The toggle:**
- **What it is:** a `ValueNotifier<bool> fill`, owned by the shell. It is
  **off** at startup.
- **How it is reached:** the Fill checkbox in the palette and the `F`
  shortcut.
- **Which tools read it:** the rectangle, circle and polyline tools. The
  shell passes the notifier into their constructors, so `ToolContext` is
  unchanged (D1).
- **The rubber band** does not show the fill; the preview is the outline
  only.

**When a tool commits with `fill.value` true** (a rectangle, a circle, or a
**closed** polyline):
1. The tool builds the boundary payload as usual.
2. It asks `addDraftedRegion(doc, kind, payload)`:
   - **A command:** commit that **one `AddRegionCommand`**. That is one undo
     step, and undo removes both halves.
   - **Null** (a closed polyline whose triangulation is empty, because it
     self-intersects or is degenerate): commit the plain `addDrafted`
     boundary instead. **The shape is never lost** because the fill is
     impossible.

**What a region is:**
- the fill carries `kDraftFillColor` (`TrueColor(0xE6E1D8)`), opaque;
- the boundary has a `ByLayer` colour, `kLineweightDefault`, and the
  continuous linetype that `AddRegionCommand.allocate` hard-codes;
- both are on layer 0 and owned by the root.

**The fill's handle is below its boundary's** (by `allocate`), so the fill
draws under its outline. It draws over everything created earlier.

**Choosing a fill colour** belongs to 12's property panel.

### D14 — The sample plan's furniture becomes filled regions (human)

In `apps/floor_planner/lib/startup_plan.dart`:
- **Each furniture piece is rebuilt as one region** through
  `addDraftedRegion`:
  - **the fill** is `kDraftFillColor`;
  - **the boundary** keeps today's look: colour `_furnitureColor`
    (`0x8A6D3B`) at lineweight 25.
- **The pieces:**
  - the beds, the sofa, the table and the bath are **rectangles**
    (`rectanglePayload`);
  - the two overlapping counter rectangles become **one L-shaped closed
    polyline** with six vertices, so the fill has no seam;
  - the lamp and the basin stay **circles**.
- **The furniture section moves after the floor finishes**, so its handles
  are higher and its fills cover the tile and parquet lines beneath. The
  lamp is emitted after the table it sits on.
- **Nothing else changes**: the walls, doors, windows and finishes keep
  their current order and look.

**Amended after the look (2026-09-24, `fix/counter-doorway`, Ruling F-8).**
The human's look agreed that the counter's north leg blocked the
kitchen/living doorway, at 350 mm. The fix:
- The counter is now an L on the kitchen's **south and east** walls.
- Bed 1 is now a **1400 mm double**. At 1800 mm it left 340 mm before the
  bedroom-1/2 doorway, which the new test caught.
- `startup_plan_test.dart` gains `SP4`: every doorway keeps a zone clear of
  furniture 900 mm deep on **both** sides of the wall's centreline, across
  the full opening.

**What `startup_plan_test.dart` checks:**
- **Unchanged:**
  - the extents are still the outer rectangle;
  - the plan is still off-origin;
  - the live count is still inside `[500, 1000]` (the rebuild lowers it by
    14: 30 entities become 8 regions of 2);
  - `canUndo` is false.
- **New:**
  - every furniture boundary is linked to a fill (`doc.fills`);
  - every fill's handle is above every finish line's handle.

## Architecture

### Files

- `packages/jet_cad_2d/lib/src/document/drafting.dart` (new), and its
  export in `jet_cad_2d.dart`.
- `packages/jet_cad_2d/test/document/drafting_test.dart` (new): the
  builders, `addDraftedRegion`, `SweepTracker` and the differential check.
- New in `packages/jet_cad_2d_flutter/lib/src/draw/`, all exported from
  `jet_cad_2d_flutter.dart`:
  - `placement_tool.dart`;
  - `line_tool.dart`, `polyline_tool.dart`, `rectangle_tool.dart`;
  - `circle_tool.dart`, `arc_tool.dart`, `text_tool.dart`.
- `packages/jet_cad_2d_flutter/test/draw/*_test.dart` (new), and
  `test/support/draw_fixture.dart` (new): a rig built on 03's `gripScene`,
  `gripCamera` and `pointerAt`, with a `fill` notifier.
- `apps/floor_planner/lib/tool_palette.dart` and `text_entry_overlay.dart`
  (new).
- `apps/floor_planner/lib/main.dart` (edited): the tools, the fill
  notifier, `_activate`, the shortcuts, and the palette in `chrome-left`.
- `apps/floor_planner/lib/planner_view.dart` (edited): the root becomes a
  `Stack` with the `CameraGestureDetector` subtree plus a
  `TextEntryOverlay` outside the `InteractionLayer` (D9).
- `apps/floor_planner/lib/startup_plan.dart` (edited, D14).
- `apps/floor_planner/test/planner_draw_test.dart` (new) and
  `startup_plan_test.dart` (extended).

### Invariants

1. **Exactness.** Every coordinate a tool stores `==` the resolved point it
   came from. A snapped start `==` the snapped entity's stored point.
2. **One shape, one command, one undo step.** Redo restores the same
   handle, or both handles for a region.
3. **Nothing pending touches the document.** Every cancel path leaves it
   byte-identical.
4. **02's API is unchanged:** `tool.dart`, `interaction_layer.dart` and
   `ToolController`.
5. **The frame path is O(1) per frame and allocates nothing per entity.**
   The overlay's part of it is gated by D12's structural test, not by the
   allocation tests.
6. **A fill never draws over its own boundary.** Its handle is lower.

## Testing

**The fixtures are chosen against degeneracy:**
- every tool test runs under `gripCamera` with **both `flipY: true` and
  `flipY: false`**;
- the geometry sits around x ≈ 7000, y ≈ 3000;
- the page scale is **1:20**, not the default 1:50;
- the arcs are asymmetric: one counter-clockwise, one clockwise, and one
  whose travel crosses the ±π seam;
- text uses `MetricModelMeasurer`;
- every fill test runs with Fill both **on** and **off**.

**Every command-level test compares the codec snapshot** (`snapshot(doc)`),
not a spot field.

**Mutants are fired with a `cp` backup,** then restored, and the `diff` is
checked clean. **Never `git checkout --` a `.dart` file.**

### Named mutants

| ID | Mutation | Must go red |
|---|---|---|
| M-05a | a tool makes its point from `event.screen` instead of `event.world` | every tool's geometry test, under the non-identity camera |
| M-05b | `rectanglePayload` drops the closing pair | the rectangle's codec round trip as closed: `isClosedPolyline`, and the coordinates `==` |
| M-05c | `textPayload` stores `heightMm * kCapHeightRatio` | placed text renders at the requested cap height: `text_geometry` scale × `metrics.capHeight` equals `heightMm` within 1e-9 |
| M-05d | `addDrafted` derives the handle from `doc.entities.length + firstFree` instead of `handleSeed.next()` | draw A, undo, draw B: B's handle is not A's, because handles are never reissued. (The redo-stability test belongs to exit criterion 2. It cannot tell this mutant apart, because a baked handle replays either way.) |
| M-05e | the arc commits `[r, end, −sweep]`: start and end swapped | the asymmetric arc's stored start and sweep |
| M-05f | `SweepTracker.track` adds `a − previous` unwrapped | the seam-crossing arc |
| M-05g | `sweepTo` ignores the sign of `τ` and always returns `δ` | the clockwise arc |
| M-05h | the polyline's `orthoBase` is the first vertex, not the last | a third vertex placed with shift lies on the ortho line through the second |
| M-05i | closing appends the raw pointer, not the stored first vertex | the closed polyline's last pair `==` its first |
| M-05j | `textHeightMm` uses 50, not `scaleDenominator` | the 1:20 fixture's height |
| M-05k | the line chain re-resolves the next start from the click | the shared endpoint of two chained segments is `==` |
| M-05l | Escape mid-shape commits the pending shape | the snapshot is byte-identical after Escape |
| M-05m | an idle drawing tool returns `handled` for Escape | the shell test: Escape activates Select |
| M-05n | `TextEntryOverlay` treats `p` as screen coordinates, without the camera | the overlay widget test under the non-identity camera |
| M-05o | the rectangle tool ignores `fill` and always commits `addDrafted` | with Fill on: one fill linked to the new boundary, and its colour `kDraftFillColor` |
| M-05p | a filled shape commits as two commands, `AddEntityCommand` for the boundary then one for the fill | with Fill on: one undo removes both halves; `undoDepth` is 1 |
| M-05q | `addDraftedRegion` drops the empty-polyline-triangulation refusal (null only when `triangulationFor` is null) | with Fill on, a bow-tie closed polyline commits as a **plain** boundary: no fill is linked, and `doc.fills` is unchanged |
| M-05r | `startup_plan.dart` emits the furniture before the finishes | `startup_plan_test`: every fill's handle is above every finish line's |
| M-05s | the polyline rubber band draws one `drawLine` per placed segment instead of one `Path` | the overlay structural test: a 5-vertex pending polyline is one `drawPath` |
| M-05t | `commitText` sets the width-factor and oblique override bits | with a Standard style of `widthFactor` 0.8, the placed text's `text_geometry` width factor is 0.8 |
| M-05u | the overlay keys the `TextField` by the camera value, so it rebuilds on a pan | a widget test pans mid-typing: the field keeps focus and the typed string |
| M-05v | the field's `Shortcuts` guard is removed | a widget test types `l`, `a`, `t` and `e` into the field with real key events: the field reads "late" and the active tool is still Text |
| M-05w | `selfSnap` runs after `resolveDragPoint` instead of before | a polyline closed where its first vertex has an existing entity's endpoint nearer inside the aperture: the last pair `==` the polyline's own first vertex |
| M-05x | the line's `selfSnap` returns the start before any segment is committed | a second click on the start keeps the line tool pending: no command, and the tool is still Line |
| M-05y | a canvas click while text is pending cancels instead of committing | tool test: type into `controller`, click the canvas, and one text exists with the string |
| M-05z | `sweepTo` uses `τ > 0` for counter-clockwise (so `τ == 0` goes clockwise) | the no-hover arc test: centre, start, and an end click with no hover in between commit a positive sweep |

### Differential check

`SweepTracker` is checked against a brute-force reference:
- **The reference** sums `atan2` steps at 64 sub-samples per step, over
  seeded random pointer paths around a random centre.
- **The run** uses seed `0x5EED0005` and 500 trials.
- **The sign** must match exactly, and the **magnitude** must match within
  `Tolerance.standard.angular`.
- **A trial whose true travel is within 1e-6 of a multiple of 2π** is
  skipped and counted, never dropped silently.

### Widget tests

- **The palette:** each button and each shortcut activates its tool, and
  the top bar shows the tool's name.
- **Escape:** an idle Escape returns to Select.
- **Shortcuts and the text field:** every shell letter, typed into the
  focused field with **real key events** (`sendKeyEvent`, never
  `enterText`), arrives as text, and the active tool does not change
  (M-05v).
- **A pan and a zoom mid-typing** keep the field's focus and its string
  (M-05u).
- **Activation:** activating a drawing tool from the palette or a shortcut
  clears the selection.
- **Fill:** `F` and the checkbox toggle it.
- **The text flow end to end:** `T`, click, type with key events, Enter,
  and exactly one text exists with the string and the height. The same
  flow ending in Escape, and one ending in a click on the palette, each
  leave the snapshot byte-identical. The flow ending in a canvas click
  commits.
- **Permissions:** under `DraftPermissions.runtime`, the drawing tools and
  Fill are disabled.

**Amended at execution (Plan 05):** Ruling 05-9. `flutter_test` does not
turn a raw key event into `EditableText` input, so "the field reads late"
above cannot itself be observed under `sendKeyEvent`; M-05v's test instead
asserts that the key event returns `false` (not consumed by the shell) and
that the active tool is unchanged, which is what the guard actually
guarantees and is what lets the platform, outside a test harness, deliver
the key to the field as text. Three widget tests were added in Task 7's
fix round for the D5/D9 findings above: **A13**, a window switch with a
text pending (`inactive` then `resumed`): the field, its controller and
its typed string all survive, and a shell shortcut works again afterward;
**A14**, Escape typed into the page-scale field reaches the field's own
handling rather than the shell's guard dropping a pending shape; and
**A15**, an ordinary in-app blur (the null-lifecycle case excluded) still
cancels a pending text, per D9's original rule.

## Exit gate

1. Each tool creates the documented entity with the documented geometry
   (D6–D9), under both cameras.
2. One finished shape is exactly one undo step. Undo removes it, and redo
   restores it with the **same handle**, or both handles for a region.
3. With snapping on, a line started near an existing endpoint begins
   **exactly** on it (`==`).
4. Escape mid-shape, a tool switch and `dispose` each leave the document
   byte-identical.
5. A rectangle round-trips through the codec as a closed polyline, both
   plain and as a region.
6. Placed text renders at the requested cap height, verified against
   `kCapHeightRatio`.
7. The palette and the shortcuts reach all seven tools and Fill, and an
   idle Escape returns to Select.
8. The arc's direction follows the pointer, across the seam too, and the
   differential check is green.
9. **Fill:**
   - with Fill on, a rectangle, a circle and a closed polyline each commit
     one region, with the fill under its boundary;
   - a self-intersecting closed polyline falls back to a plain boundary;
   - the line, the open polyline, the arc and the text ignore Fill.
10. The sample plan's furniture is filled regions, drawn over the floor
    finishes (D14), and `startup_plan_test` is green.
11. Every named mutant, M-05a…z, is fired, killed and logged in
    `docs/superpowers/notes/plan-05-mutation-log.md`.
12. The allocation invariants pass unedited, and the overlay's structural
    test (D12) is green.
13. The four gate lines are green with `CI=true`:
    - the render layer shows only the five standing
      `text_ladder_golden_test.dart` failures;
    - `analysis_options.yaml` is untouched;
    - both release builds succeed.
14. **The human's look,** on macOS, in Chrome and in Firefox from
    `build/web`, covering:
    - every tool, and Fill on and off;
    - snapping onto the sample plan;
    - Escape and undo;
    - the text field;
    - the filled furniture;
    - whether a browser also takes the single-letter shortcuts.

## Open questions

- **Browser shortcuts.** A single letter should not collide with a browser
  binding. Item 14 of the look checks it; a collision is a finding.
- **The text field's font.** The field shows plain Flutter text, not the
  rendered entity. If the look finds the jump on commit jarring, a later
  sub-project can style the field like the entity.
- **The fill preview.** The rubber band shows only the outline. If the look
  wants the fill previewed, it is one more path per frame.
