# Alignment guides (smart guides) in both modes

**Date:** 2026-10-23. **Status:** revision 2, for the human's approval.
Revision 1 was reviewed through the OpenCode CLI (`github-copilot/gpt-6.1-sol`,
the human's request); its twelve findings are folded in (O-1 to O-12, marked
below).
**Packages:** `jet_cad_2d_plan` (0.9.0 on pub.dev), `jet_cad_2d_flutter`
(one generic seam on `SelectTool`, a palette colour);
`apps/restaurant_demo`, `docs/host-guide.md`, `tool/ci/host_probe`.
**Branch:** `claude/alignment-guides-50cacb`. A parallel session moves the
plan library's panels, bars and dialogs to `shadcn_ui`; this work keeps to
the canvas, the overlay, the snap and move logic and the controller and
editor API, and adds one plain bar toggle per bar.

## Intent

When tables are set side by side their edges do not line up: the pointer
snaps to object points and to the grid, never to the other tables' edges.
Alignment guides fix that. While an object is dragged or placed, a line
appears where its edges or centre line up with a nearby object, or where its
gap to a neighbour equals another gap, and the object snaps there. Tables,
bar counters and other objects then end up properly aligned. This lands
before 1.0, so its API is part of what 1.0 freezes.

## Decisions (the human's, 2026-10-23)

- **H1 — References.** Edges (left, right, top, bottom), centres
  (horizontal and vertical), and **equal spacing**.
- **H2 — Only movable objects count** as references and as moved objects:
  placed symbol instances (tables, bar counters, kit symbols, units). Walls,
  rooms and their boundaries do not; object snap (OSNAP) already serves them.
- **H3 — A rotated object** aligns by its axis-aligned world bounding box,
  never by its own slanted edges.
- **H4 — Both modes snap**: design mode (moving and placing) and service
  mode (a waiter dragging tables). Guides show and the object snaps.
- **H5 — On by default; the host can turn them off in code; the user turns
  them on and off with a bar button; on desktop, holding a key disables them
  for that drag.**
- **H6 — The look**: thin, solid, vivid lines (Figma style) in a colour of
  their own, set through the theme. Equal spacing shows small gap marks
  between the objects and writes no measurement.
- **H7 — Accepted from my playback** (the human: *"doğru, devam et"*): the
  capture distance is in screen pixels (zoom-independent); a guide beats the
  grid; a multi-selection aligns by the outer box of the group; the key is
  Alt (Option on macOS).

## Goals

- **G1** — Dragging a selection of movable objects in design mode shows
  guides and snaps the selection to them.
- **G2** — Placing a symbol (`PlanSymbolTool`'s ghost) does the same.
- **G3** — Dragging tables in service mode (`PlanServiceView`, and
  `PlanEditor` in `PlanMode.service`) does the same.
- **G4** — A host turns guides off with one option; the user toggles them
  from the bar; Alt suspends them for one drag.
- **G5** — The look is themable through `PlanTheme`.
- **G6** — Documented in `docs/host-guide.md` (every snippet in the host
  probe), shown in the restaurant demo, an "Unreleased" entry in each touched
  package's CHANGELOG.

## Non-goals

- Guides to walls, rooms, room boundaries, lines or the page edge (H2).
- Guides during rotate or reshape (grip) drags, or in kit placement tools
  (`PlacementTool`: walls, rooms, openings); they place no movable object.
- Writing measurements on guides or gap marks (H6).
- Saving the user's toggle in the plan file or across app runs; the file
  format and the schema do not change.
- A keyboard shortcut to toggle guides (my call; Alt-hold covers the
  desktop case, the bar button the rest).

## Anti-goals (a failure even if it works)

- **Per-entity allocation on the frame path.** A pointer move and an
  overlay paint allocate nothing per reference; the existing allocation
  invariants stay green and new ones cover guides.
- **Jitter.** A guide that flickers on and off while the pointer holds still,
  or an object that jumps between two guides on alternate events.
- **Fighting existing snaps.** Attachment (`PlanMoveResolver`, a symbol with
  `attachTo`) and an object-snap hit on the pointer keep their behaviour.
- **Panel or bar churn.** Anything beyond one toggle per bar makes the
  shadcn branch's merge harder.
- **Degenerate fixtures.** Tests whose objects all sit unrotated at the
  origin.

## Behaviour

### The boxes

- **Reference box** (O-4): a root-level symbol instance's world axis-aligned
  bounding box (H3), in document units: the four corners of
  `DraftDocument.definitionBounds(definition)` (the bounds the index and
  `UnitPicker` already use, nested instances included) through the
  instance's transform. Mirrored and rotated instances use the AABB of those
  corners. An instance is skipped when it is hidden (its layer off, or
  `visible` false), its transform is singular or non-finite, or its box is
  empty or non-finite: the same rules as `UnitPicker.candidatesOf`.
- **Moving box**: the union of the moved objects' reference boxes at the
  drag's start (when placing, the ghost's box at its current transform),
  shifted by the delta under test.
- An object is a reference only when it is not moved and its box intersects
  the visible viewport (*nearby*, my call: what the user can see). An empty
  reference set means no guide.
- In design mode guides apply only when every moved root node is a symbol
  instance; a selection that includes a wall, a room or a line moves as
  today (my call, from H2).

### The reference cache (O-5, O-8)

- One cache per document (the design document, and the service copy). It is
  keyed on the document's state and revision, as `UnitIndexCache` is. It is
  rebuilt lazily on the first solve after a change, so a placement, an undo,
  a redo, a load, a layer or definition change and a re-armed tool all see
  the current objects.
- A rebuild may allocate: an O(n) pass that fills a `Float64List` of four
  numbers per box, a handle list, and a per-definition bounds memo. A solve
  allocates nothing.
- The moving box is computed once per drag start (or per ghost transform
  change while placing) from the same bounds.

### The delta (O-2)

The drag's base is today's: the press point resolved through the chain
without ortho (`SelectTool._moveBase`); in service it is the raw press point,
as today. Per event, with `p` the raw pointer, `c` the chain's resolved
target and `b` the base:

- `dChain = c − b`: today's move (object snap, grid, ortho);
- `dRaw = p − b`, with Shift's ortho pin applied to `dRaw` on the pinned axis
  exactly as the chain pins `c`;
- guides are solved on `moving box + dRaw`, giving per axis either a captured
  offset `o` or nothing;
- the final delta per axis is `dRaw + o` when captured, else `dChain`.

Both terms share the base `b`, so a capture switching on or off moves the
object by at most the aperture, never by the base's snap.

### Candidates on one axis (O-6, O-7)

Each axis is solved on its own: x aligns vertical lines, y aligns horizontal
ones. Let `M` be the moving box at `dRaw`, and `[lo, hi]` its interval on
the axis.

1. **Edges and centre.** `M`'s three positions on the axis (min, centre,
   max) are compared with every reference's three positions, nine pairs per
   reference. The offset is `reference − moving`.
2. **Equal spacing.** The *row* of `M` on axis x is the set of references
   whose y-interval overlaps `M`'s y-interval by more than
   `Tolerance.standard`; the same holds for y with the roles swapped.
   - **Left**: the row member with the largest `max ≤ lo` (ties: lower
     handle). Its gap is `gL = lo − L.max ≥ 0`.
   - **Right**: the row member with the smallest `min ≥ hi`. Its gap is
     `gR = R.min − hi ≥ 0`.
   - **Between**: with both present, the offset that makes `gL = gR` is
     `o = ((R.min + L.max) − (lo + hi)) / 2`. It is a candidate only when
     `R.min − L.max ≥ hi − lo`, i.e. the box fits.
   - **Continuing**: take a pair of row members `(A, B)` that are adjacent
     on the axis, meaning `B.min ≥ A.max` and no row member lies wholly
     between them, and whose own perpendicular intervals overlap. Its gap is
     `g = B.min − A.max`. With `L` the left neighbour, the candidate offset
     is `o = (L.max + g) − lo`; mirrored with `R`, it is `o = (R.min − g) −
     hi`. Pairs are limited to the 16 nearest to `M` on the axis, so a solve
     stays bounded.
3. A candidate is captured when `|o| ≤ aperture`, where
   `aperture = kGuideAperturePixels / camera.scale`. `kGuideAperturePixels`
   is 6 for a mouse and 10 for touch (my call, after `kPickRadiusPixels` and
   the touch reach).
4. **Total order**, so the same input always gives the same answer (no
   jitter): the smallest `|o|` wins. Ties are broken in this order:
   - edges, then centres, then between, then continuing;
   - the smaller pair index, in the order min, centre, max of the moving box
     and then of the reference;
   - the lower reference handle, then the lower second handle of a pair;
   - a negative `o` before a positive one.
5. **No alternation.** Both axes are solved once each, on `M` at `dRaw`.
   After the final delta is formed, a captured spacing candidate is
   re-checked against the final box. If its row overlap no longer holds
   (the other axis moved), that axis takes its best non-spacing candidate
   from the same pass, or `dChain` if it has none. Nothing is solved again.
6. After the snap, every candidate on a captured axis whose offset is now
   zero within `Tolerance` is drawn: other references on the same line, and
   both gaps of an equal pair.

### Priority against the existing chain (O-1)

The order, per event:

1. today's chain resolves `c` (`resolveDragPoint`);
2. today's attachment runs as it does now, after the chain and even after an
   object-snap hit (`SelectTool._retarget`, `PlanSymbolTool`). A captured
   attachment wins: no guides for that event;
3. otherwise an **object-snap hit on the pointer** wins: no guides for that
   event (my call: exact geometry is a stronger intent);
4. otherwise guides apply as in *The delta*.

The behaviour of attachment and of object snap is unchanged.

### Modes

- **Design, move**: `SelectTool` body drags of movable objects.
- **Design, place**: `PlanSymbolTool`'s ghost, while hovering and while
  dragging, before attachment. The moving box is recomputed when the ghost's
  transform changes (a rotation, a mirror, a new symbol).
- **Service**: `ServiceTool`'s drag of units and whole groups. References
  are the service document's other symbol instances (other tables, bar
  counters, fixed furniture). Service has no grid; an axis without a guide
  keeps `dRaw`.
- **Service and the camera (O-3)**: service gains what design has. While a
  drag lives, it listens to the camera and re-targets from the last screen
  point, the last device kind and the last Alt state. It stops listening on
  release, on cancel (including the second finger's cancel) and on dispose.
- The release commits exactly what the preview showed. It is still one
  command (one undo step), and `onUnitsMoved` and `onLayoutChanged` fire as
  today with the snapped positions.

### Turning them off (H5, O-10, O-11)

- **Host:** `PlanEditor.alignmentGuides`, `PlanServiceView.alignmentGuides`
  and `PlanCanvas.alignmentGuides` are `bool`s that default to true and work
  the way `snapping` already does. False hides the bar button and turns
  guides off in that view.
- **Controller:** `PlanController.alignmentGuides` is of a new, exported
  type, `PlanGuideSettings extends ChangeNotifier`. It has:
  - `bool get on`: the effective value (allowed and the user's);
  - `bool get userOn` and `void toggle()`: the user's choice;
  - `bool get allowed`: set by the views through
    `PlanController.alignmentGuidesAllowed`, like `snappingAllowed`.
  It notifies on a change of either value. An allowance change is delivered
  frame-safe, as `snappingAllowed`'s is (never during a build).
  - The user's choice lives in memory for the controller's life. It is
    shared by both modes and survives a mode switch.
  - Turning guides off mid-drag clears them at once (a repaint). The next
    retarget, or a camera-driven one, resolves without them.
- **User:** a new `PlanEditorAction.guides` and `PlanServiceAction.guides`.
  - Each is a plain toggle button (an icon button with a selected state),
    listed by default, so the shadcn session can restyle it.
  - It sits after Snap in the editor's edit group, and after Redo in the
    service bar's undo group.
  - Its tooltip and semantics label are localised (en, de, tr).
  - Both of `PlanServiceView`'s exhaustive switches over the action (button
    and grouping), and the editor's switches, list the new value.
  - The CHANGELOG tells hosts that switch exhaustively over either enum to
    add the case.
- **Alt held** (`ToolPointerEvent.alt`) at any pointer event of the drag
  suspends guides for that event. The final delta is then `dChain`, and no
  guide is drawn. Releasing Alt brings them back on the next event.

### The look (H6, O-9)

- **Lines**: a guide runs in screen space through the shared coordinate. It
  spans from the moving box to the farthest aligned reference, plus 8 px
  past each end. It is solid and `guideWidth` logical pixels wide, in the
  guide colour.
- **Gap marks**: one per equal gap, drawn at the middle of the perpendicular
  overlap of the two boxes on either side of the gap. Each is a segment
  across the gap with a short perpendicular tick (4 px) at both ends, in the
  same colour. Nothing is written.
- **Colour**: `PaperPalette` gains `guide`, an optional constructor argument
  defaulting to a vivid magenta: light `0xFFE0218A`, dark `0xFFFF5CB0` (my
  call, checked against both canvases). Existing callers compile unchanged,
  and `withSelection` and every copy carry the new field.
  - `PlanTheme` gains `guideOnLight`, `guideOnDark` and `guideWidth`
    (default 1, range like `selectionWidth`'s). They are validated like the
    selection fields.
  - The colour reaches the painters through `planPaperPaletteFor`.
  - **The width** reaches them through a plan-internal guide style. The
    views resolve the theme in `didChangeDependencies` and write a plain
    double into the session. The three guide painters (the design seam's
    plan implementation, `PlanSymbolTool` and `ServiceTool`) read it at
    paint; nothing reads Flutter theme state while painting.
- Guides are drawn above the selection preview and below the snap marker,
  in the tool's screen-space overlay.

## Architecture

- **Solver** (pure Dart, no Flutter import): `lib/src/guides/` in
  `jet_cad_2d_plan`.
  - It solves one moving box against the reference cache.
  - The answer goes into a caller-owned result: the per-axis offsets, and
    fixed-capacity buffers of lines and gap marks (16 each; past capacity,
    the extra guides are simply not drawn).
  - It allocates nothing per call once warmed. It is unit-tested by itself.
- **Design-mode seam** in `jet_cad_2d_flutter`: `SelectTool` gains an
  optional generic hook beside `MoveResolver`. It knows no plan types.
  - It is told when a move drag starts (the moved handles), and on every
    retarget it may replace the delta. That runs after the chain and the
    attachment, with the raw point, the base, the chain's point, whether
    object snap hit, whether attachment captured, and Alt.
  - It paints into `paintOverlay`, and is told when the drag ends or is
    cancelled.
  - Its exact name and signature are the builder's, as long as it stays
    generic, null by default, and leaves today's behaviour untouched when
    absent.
  - The plan library implements it and passes it in `buildGenericTools`.
- **Placement**: `PlanSymbolTool._resolve` applies the solver to the ghost's
  box and paints the guides in its `paintOverlay`.
- **Service**: `ServiceTool._drag` (and its new camera re-target) applies
  the solver to `_dx/_dy` and paints the guides in its `paintOverlay`
  beside the band.
- **Camera moves mid-drag** re-solve with the new scale, in every mode.

## Constraints

- The frame path allocates nothing per entity in steady state and is O(1)
  per flush. `query_allocation_test`, `paint_allocation_test` and the plan's
  `canvas_paint_allocation_test` stay green.
- **O-12**: a new invariant measures warmed, end-to-end re-targets in all
  three tools (move, place, service), pointer-driven and camera-driven, at
  two reference counts (e.g. 10 and 200) and two selection sizes. Its
  per-event allocation budget is zero, watching for `_Double`, `Aabb2`,
  `Transform2`, records, closures and collections. The measurement uses the
  VM `AllocationMeter`, as `pick_allocation_test` does, and the guide paint
  is measured the same way. Each budget has a named mutation that breaks it.
- Geometric decisions use `Tolerance`; the capture aperture is an
  interaction tolerance in screen pixels converted per zoom, as
  `kSnapAperturePixels` is.
- No colour literal in plan `lib` outside what `theme_colours_test` allows;
  the default colours live in `PaperPalette`.
- Draw order, the file format, undo and the host events are unchanged apart
  from the snapped positions.
- `jet_cad_2d_flutter`'s seam and palette field are additive; its CHANGELOG
  gets an Unreleased entry.

## Testing bar

A test lands only if a named mutation turns it red. Fixtures are rotated
(30°, 90°), mirrored and off the origin, at a camera scale other than 1. Each
mode is tested through its real tool and event path, not only through the
solver. At minimum:

- each candidate kind is captured and drawn, and refused just outside the
  aperture, at two zooms;
- tie order and stability: the same pointer gives the same guide;
- per-axis mixing with grid snap, and an off-grid press whose snapped base
  differs from the raw press (O-2);
- a spacing capture dropped when the other axis moves the row (O-7);
- the reference cache rebuilt after a placement and after an undo (O-8);
- a service camera change with no pointer move (O-3);
- object snap and attachment win;
- Alt, the host option, the bar toggle and its hidden state;
- the committed command equals the preview, with one undo step;
- `onUnitsMoved` carries the snapped centre;
- the allocation invariant.

## What is left to the builder

- The seam's name and signature, the solver's internal layout, and the task
  split.
- The icon for the toggle (a Material icon that reads as "guides", e.g.
  `Icons.straighten` or `Icons.border_vertical`), and the exact l10n strings.
- How the restaurant demo shows guides. At least: they are on in both modes,
  and the bar toggle is visible.
