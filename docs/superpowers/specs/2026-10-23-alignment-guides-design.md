# Alignment guides (smart guides) in both modes

**Date:** 2026-10-23. **Status:** draft, for the human's approval.
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

- **Reference box**: a root-level symbol instance's world axis-aligned
  bounding box (H3), in document units. Mirrored and rotated instances use
  the AABB of their transformed definition box.
- **Moving box**: the union of the moved objects' reference boxes, taken at
  the start of the drag (or, when placing, the ghost's box at its current
  transform), shifted by the drag's delta.
- An object is a reference only when it is not moved and its box intersects
  the visible viewport (*nearby*, my call: what the user can see).
- In design mode guides apply only when every moved root node is a symbol
  instance; a selection that includes a wall, a room or a line moves as
  today (my call, from H2).

### Candidates on one axis

Each axis (x, then y) is solved on its own; the x axis aligns vertical
lines, the y axis horizontal ones.

1. **Edges and centre.** The moving box's three positions (min, centre, max)
   against every reference's three positions: nine pairs per reference. The
   offset is `reference − moving`.
2. **Equal spacing.** Among references that overlap the moving box on the
   *other* axis (its row or column):
   - *between*: the nearest neighbour before and the nearest after, with the
     moving box centred so the two gaps are equal (only when it fits);
   - *continuing*: a gap between two adjacent references in that row, matched
     by the moving box's gap to its nearest neighbour on either side.
3. A candidate is captured when `|offset| ≤ aperture`, where
   `aperture = kGuideAperturePixels / camera.scale` with
   `kGuideAperturePixels = 6` for a mouse and 10 for touch (my call, after
   `kPickRadiusPixels` and the touch reach).
4. The smallest `|offset|` wins. On a tie, edges beat centres and centres beat
   spacing, then the lower handle wins (a stable order: no jitter).
5. After the snap, every candidate whose offset is now zero within
   `Tolerance` is drawn. That covers the other references on the same line
   and both gaps of an equal pair.

### Priority against the existing chain (H7)

The pointer is first resolved by today's chain (`resolveDragPoint`):

- **an object-snap hit on the pointer wins**: no guides for that event (my
  call: exact geometry is a stronger intent);
- **an attachment** (`PlanMoveResolver`) wins: no guides;
- otherwise guides are solved on the **raw** (unsnapped) delta. An axis a
  guide captures takes the guide's position. An axis without a guide keeps
  the chain's result, the grid's when grid snap is on. So a table can align
  to a neighbour's edge on x while staying on the grid on y.
- Shift's ortho move still applies first. Guides then act only on the free
  axis.

### Modes

- **Design, move**: `SelectTool` body drags of movable objects.
- **Design, place**: `PlanSymbolTool`'s ghost, before attachment. A captured
  attachment turns guides off, as in a move.
- **Service**: `ServiceTool`'s drag of units and whole groups. References are
  the service document's other symbol instances (moving tables, bar counters,
  fixed furniture). Service has no grid. An axis without a guide keeps the
  raw delta.
- The release commits exactly what the preview showed. It is still one
  command (one undo step), and `onUnitsMoved` and `onLayoutChanged` fire as
  today with the snapped positions.

### Turning them off (H5)

- **Host:** `PlanEditor.alignmentGuides`, `PlanServiceView.alignmentGuides`
  and `PlanCanvas.alignmentGuides` are `bool`s that default to true and work
  the way `snapping` already does. False hides the bar button and turns
  guides off in that view.
- **Controller:** `PlanController.alignmentGuides` is a `Listenable`
  setting with `bool get on` (the effective value: allowed and the user's)
  and `void toggle()`, beside `controller.snap`. It also has
  `alignmentGuidesAllowed`, which the views set, like `snappingAllowed`. The
  user's choice lives in memory for the controller's life. It is shared by
  both modes and survives a mode switch.
- **User:** a new `PlanEditorAction.guides` and `PlanServiceAction.guides`.
  Each is a plain toggle button (an icon button with a selected state) in
  that bar's existing button group, listed by default, so the shadcn session
  can restyle it. Its tooltip and semantics label are localised (en, de,
  tr).
- **Alt held** (`ToolPointerEvent.alt`) at any pointer event of the drag
  suspends guides for that event. Releasing Alt brings them back. No guide is
  drawn while it is held.

### The look (H6)

- **Lines**: a guide runs in screen space through the shared coordinate. It
  spans from the moving box to the farthest aligned reference, plus 8 px
  past each end. It is solid, `guideWidth` logical pixels wide (default 1),
  in the guide colour.
- **Gap marks**: one per equal gap, drawn at the middle of the overlap of
  the two boxes on the other axis. Each is a segment across the gap with a
  short perpendicular tick (4 px) at both ends, in the same colour. Nothing
  is written.
- **Colour**: a new `PaperPalette.guide`: a vivid magenta, light
  `0xFFE0218A` and dark `0xFFFF5CB0` (my call, checked against both
  canvases). It also gets new `PlanTheme.guideOnLight`, `guideOnDark` and
  `guideWidth` fields, validated like the selection fields and applied by
  `planPaperPaletteFor`. `withSelection` and every palette copy carry the new
  field.
- Guides are drawn above the selection preview and below the snap marker,
  in the tool's screen-space overlay.

## Architecture

- **Solver** (pure Dart, no Flutter import): `lib/src/guides/` in
  `jet_cad_2d_plan`.
  - It solves one moving box against a reference set, held in a
    `Float64List` (four numbers per box) plus a handle list.
  - The answer goes into a caller-owned result: the per-axis offsets, and
    fixed-capacity buffers of lines and gap marks (16 each; past capacity,
    the extra guides are simply not drawn).
  - It allocates nothing per call once warmed. It is unit-tested by itself.
- **Reference cache**: built once per drag start from the document's
  root-level instances.
  - Each box comes from `boxOfDefinition` (memoised per definition, as
    `PlanMoveResolver` does) through the instance's transform.
  - In service it may reuse `UnitPicker.candidates`' world corners for units.
  - Allocating at drag start is allowed. Per-event work is a linear scan with
    a viewport test.
- **Design-mode seam** in `jet_cad_2d_flutter`: `SelectTool` gains an
  optional generic hook beside `MoveResolver`. It knows no plan types.
  - It is told when a move drag starts (the moved handles), and on every
    retarget it may replace the delta. That runs after the chain, with the raw
    point, the snapped point and whether object snap hit.
  - It paints into `paintOverlay`, and is told when the drag ends or is
    cancelled.
  - Its exact name and signature are the builder's, as long as it stays
    generic, null by default, and leaves today's behaviour untouched when
    absent.
  - The plan library implements it and passes it in `buildGenericTools`.
- **Placement**: `PlanSymbolTool._resolve` applies the solver to the ghost's
  box and paints the guides in its `paintOverlay`.
- **Service**: `ServiceTool._drag` applies the solver to `_dx/_dy` and paints
  the guides in its `paintOverlay` beside the band.
- **Camera moves mid-drag** (trackpad zoom, pan) re-solve with the new scale,
  as `_onCamera` re-targets today.

## Constraints

- The frame path allocates nothing per entity in steady state and is O(1)
  per flush. `query_allocation_test`, `paint_allocation_test` and the plan's
  `canvas_paint_allocation_test` stay green. A new invariant measures the
  solver and the guide paint over a warmed drag (VM `AllocationMeter`, as
  `pick_allocation_test` does).
- Geometric decisions use `Tolerance`; the capture aperture is an
  interaction tolerance in screen pixels converted per zoom, as
  `kSnapAperturePixels` is.
- No colour literal in plan `lib` outside what `theme_colours_test` allows;
  the default colours live in `PaperPalette`.
- Draw order, the file format, undo and the host events are unchanged apart
  from the snapped positions.
- `jet_cad_2d_flutter`'s seam is additive; its CHANGELOG gets an Unreleased
  entry.

## Testing bar

A test lands only if a named mutation turns it red. Fixtures are rotated
(30°, 90°), mirrored and off the origin, at a camera scale other than 1. Each
mode is tested through its real tool and event path, not only through the
solver. At minimum:

- each candidate kind is captured and drawn, and refused just outside the
  aperture, at two zooms;
- tie order and stability: the same pointer gives the same guide;
- per-axis mixing with grid snap;
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
