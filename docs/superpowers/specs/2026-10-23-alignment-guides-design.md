# Alignment guides (smart guides) in both modes

**Date:** 2026-10-23. **Status:** revision 3, approved by the human ("onaylıyorum", 2026-10-23).
Revision 1 was reviewed through the OpenCode CLI (`github-copilot/gpt-6.1-sol`)
and revision 2 through the Copilot CLI, both at the human's request; their
findings are folded in (O-1 to O-12, C-1 to C-19, marked below; record in
`docs/superpowers/notes/2026-10-23-alignment-guides-spec-review.md`).
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
- **H8 — Reviews**: the spec is reviewed by the OpenCode CLI, then by the
  Copilot CLI (the human: *"opencode cli ile review ettir"*, *"copilot cli
  ile de review edilsin"*).

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
  `attachTo`) keeps its behaviour everywhere; object snap keeps it outside
  guide-eligible drags (see *Priority*).
- **Panel or bar churn.** Anything beyond one toggle per bar makes the
  shadcn branch's merge harder.
- **Degenerate fixtures.** Tests whose objects all sit unrotated at the
  origin.

## Behaviour

### The boxes (O-4, C-2, C-3, C-14, C-15, C-17)

- **References** are the root-level symbol instances of the document (the
  design document, or the service copy), whether or not they are units:
  tables, bar counters, fixed furniture, kit symbols (H2). A unit generated
  one level inside a root group counts too, as `UnitIndex` counts it.
  - The cache scans the document's root nodes itself; `UnitIndex.units`
    alone would miss non-unit furniture.
  - **Excluded:** seats (a unit of kind seat) and anything the moved
    objects carry with them (my call: a table must not snap to its own
    chairs, and a seat stays put when its table moves).
  - **Visibility:** an instance is skipped when its layer is off or its own
    `visible` flag is false.
  - **Validity:** it is also skipped when its transform is singular or
    non-finite, or its box is empty or non-finite.
- **A reference's box**: the definition's box, through the instance's
  transform, as a world axis-aligned bounding box (H3).
  - The definition's box is that of its own entities (direct leaves),
    attributes excluded, so a table's number label does not stretch it. This
    is `UnitIndex`'s rule and `boxOfEntry`'s, so a moved object and its ghost
    get the same box. Nested-instance geometry is not in a box (amended at
    plan review, P-2).
  - The builder picks the existing helper that gives exactly this, or adds
    one beside `definitionBounds`.
  - Mirrored and rotated instances take the AABB of the four transformed
    corners.
- **Moving box**: the union of the moved objects' boxes, by the same rule,
  at the drag's start, shifted by the delta under test. When placing, it is
  the ghost's box: `boxOfEntry(entry)` through `placementTransform`, the same
  rule applied to an entry not yet in the document.
  - An empty moving box (every member hidden or singular) means no guide.
- **Every reference counts**, on screen or off (C-3: tools have no viewport
  size; the scan is linear anyway). A guide line is clipped by the canvas.
  An empty reference set means no guide.
- In design mode guides apply only when every moved root node is a symbol
  instance; a selection that includes a wall, a room or a line moves as
  today (my call, from H2).

### The reference cache (O-5, O-8)

- One cache per document, keyed on the document's state and revision, as
  `UnitIndexCache` is. It is rebuilt lazily on the first solve after a
  change, so a placement, an undo, a redo, a load, a layer or definition
  change and a re-armed tool all see the current objects.
- A rebuild may allocate: an O(n) pass that fills a `Float64List` of four
  numbers per box, a handle list, and a per-definition box memo. A solve
  allocates nothing.
- The moving box is computed once per drag start, or once per ghost
  transform change while placing.

### The delta (O-2, C-6, C-7, C-9)

**Move** (design and service). The base `b` is today's:
- in design, the press point resolved through the chain without ortho
  (`SelectTool._moveBase`);
- in service, the raw press point.

Per event, with `p` the raw pointer and `c` the chain's resolved target:
- `dChain = c − b`: today's move (object snap, grid, ortho). In service
  there is no chain, so `c = p`.
- `dRaw = p − b`.
- Guides are solved on `moving box + dRaw`. Each axis gets either a captured
  offset `o` or nothing.
- The final delta per axis is `dRaw + o` when captured, else `dChain`.
- **Shift (ortho)**: the axis the chain pins takes no guide; it keeps
  `dChain`, so the ortho line stays exact. Only the free axis can capture.

**Place** (design). There is no press and no base. The ghost's anchor `at`
is today's chain result on the pointer.
- The raw anchor is the pointer itself.
- Guides are solved on the ghost's box at the raw anchor.
- Per axis, the final anchor is `raw + o` when captured, else `at`.
- Attachment is still evaluated on the unguided `_free()` transform, as
  today.

**What a capture switching costs**: the object moves by at most the
aperture with no grid. With grid snap on, it moves by at most half a grid
step plus the aperture, because the uncaptured axis is grid-snapped and the
captured one is not. A test pins both bounds.

### Candidates on one axis (O-6, O-7, C-10, C-11)

Each axis is solved on its own: x aligns vertical lines, y aligns horizontal
ones. Let `M` be the moving box at the raw delta, `[lo, hi]` its interval on
the axis, and `ε = Tolerance.standard.linear`.

1. **Edges and centre.** `M`'s three positions on the axis (min, centre,
   max) are compared with every reference's three positions, nine pairs per
   reference. The offset is `reference − moving`.
2. **Equal spacing.** The *row* of `M` on axis x is the set of references
   whose y-interval overlaps `M`'s by more than `ε`; on y, swap the axes.
   - **Neighbours.** `L` is the row member with the largest `max ≤ lo + ε`.
     `R` is the row member with the smallest `min ≥ hi − ε`. Ties go to the
     lower handle.
   - **Between**: with both `L` and `R` present, `o = ((R.min + L.max) −
     (lo + hi)) / 2`. It is a candidate only when the box fits, i.e.
     `R.min − L.max ≥ hi − lo`, and each resulting gap is `> ε`.
   - **Continuing on the left**: let `A` be `L`'s own left neighbour in `L`'s
     row: the reference with the largest `max ≤ L.min + ε` whose
     perpendicular interval overlaps `L`'s by more than `ε`. With
     `g = L.min − A.max > ε`, `o = (L.max + g) − lo`. Continuing on the right
     mirrors it with `R` and `R`'s right neighbour. Only the neighbour pairs
     of `L` and of `R` are considered. There are no "16 nearest" and no
     ranking buffer, so the work is O(n) per axis with fixed scratch.
   - A gap `≤ ε` (touching objects) is never a spacing candidate and never
     gets a mark.
3. A candidate is captured when `|o| ≤ aperture`, where
   `aperture = kGuideAperturePixels / camera.scale`. `kGuideAperturePixels`
   is 6 for a mouse and 10 for touch (my call, after `kPickRadiusPixels` and
   the touch reach). The pointer kind is the drag's last event's.
4. **Total order**, so the same input always gives the same answer (no
   jitter): the smallest `|o|` wins. Ties are broken in this order:
   - edges, then centres, then between, then continuing;
   - the smaller pair index, in the order min, centre, max of the moving box
     and then of the reference;
   - the lower reference handle, then the lower second handle of a pair;
   - a negative `o` before a positive one.
5. **No alternation; rechecks are simultaneous.** Both axes are solved once,
   on `M` at the raw delta. That gives a provisional final delta. Each axis
   whose capture is a spacing candidate is then re-checked against the box
   at the provisional delta: does its row overlap still hold?
   - A failed axis takes its best non-spacing candidate from the same pass,
     or the uncaptured value.
   - Both rechecks read the same provisional delta, so their order does not
     matter.
   - Nothing is solved again.
6. After the snap, every candidate on a captured axis whose offset is now
   zero within `ε` is drawn: other references on the same line, and both
   gaps of an equal pair.

### Priority against the existing chain (O-1, C-5, C-8)

The order, per event:

1. today's chain resolves `c` (`resolveDragPoint`);
2. guides are solved as in *The delta*. In `SelectTool` they run between
   `_resolve` and `drag.moveTo`, so the guided target is the one moved to
   (one `moveTo` per event, as today);
3. today's attachment runs after that, as now. A captured attachment wins,
   and its transform replaces the guided one, as it replaces the plain move
   today. No guide is drawn for that event.

**Guides beat a pointer object-snap hit** (C-8, my call, reversing
revision 2). Revision 2 let the hit win, but in a guide-eligible drag the
pointer often comes within 10 px of some wall endpoint, so guides would blink
and the object would swap positions. That is the jitter anti-goal. Now:

- an axis a guide captures takes the guide's position even when the chain's
  `c` came from object snap;
- an axis no guide captures keeps `dChain`, object snap included.

Object snap is unchanged outside guide-eligible drags: grips, rotate, walls,
rooms, mixed selections, Alt held, guides off. Attachment is unchanged
everywhere.

### Modes

- **Design, move**: `SelectTool` body drags of movable objects.
- **Design, place** (C-9): `PlanSymbolTool`'s ghost, while hovering and
  while dragging. The guide solve is hooked wherever the ghost is
  re-resolved:
  - the pointer events;
  - the R (rotate) and M (mirror) key handlers, which today call
    `_syncAttachment` and `_syncPlacement` without `_update`;
  - a camera change.

  `_track` also stores the last Alt state and the pointer kind. The moving
  box is recomputed when the ghost's transform changes.
- **Service**: `ServiceTool`'s drag of units and whole groups. References
  follow *The boxes*. Service has no grid, so an axis without a guide keeps
  `dRaw`.
- **Camera mid-drag, every mode** (O-3): `SelectTool` already re-targets. It
  and the seam now also keep the last pointer kind and Alt state (C-19).
  - Service gains the same: while a drag lives, it listens to the camera and
    re-targets from the last screen point, kind and Alt state.
  - Service stops listening on release, on cancel (including the second
    finger's cancel) and on dispose.
- **Alt pressed or released with no pointer move** (C-16): the key handler
  re-targets at once in every mode, so the preview never shows a stale state.
- The release commits exactly what the preview showed. It is still one
  command (one undo step), and `onUnitsMoved` and `onLayoutChanged` fire as
  today with the snapped positions.

### Turning them off (H5, O-10, O-11, C-1, C-12, C-13)

**Host.** `PlanEditor.alignmentGuides`, `PlanServiceView.alignmentGuides` and
`PlanCanvas.alignmentGuides` are `bool`s, default true. False hides that
bar's button and turns guides off in that view.
- **Allowance has one owner per mounted view.** Each of `PlanCanvas` and
  `PlanServiceView` writes the controller's allowance:
  - when it mounts, and when its widget's value changes;
  - and, on a controller swap, resets the old controller's to true, as
    `PlanCanvas` does for `snappingAllowed` today. `PlanServiceView` has no
    `snapping` option, so this is new for it. A dispose does not reset
    (amended at plan review, P-1): a view replaced by another in one frame,
    as `PlanEditor`'s mode switch does, must not undo the new view's value.
- `PlanEditor` hands its one value to whichever of the two it mounts, so
  they never disagree. A host mounting both standalone views over one
  controller with different values gets last-mounted-wins (documented).

**Controller.** `PlanController.alignmentGuides` is a new, exported type,
`PlanGuideSettings extends ChangeNotifier`. It has:
- `bool get on`: the effective value (allowed and the user's);
- `bool get userOn` and `void toggle()`: the user's choice;
- `bool get allowed`.

Its setter `PlanController.alignmentGuidesAllowed` is `@internal`, like
`snappingAllowed`.
- It notifies on a change of either value. An allowance change is delivered
  frame-safe, as `snappingAllowed`'s is (never during a build).
- The user's choice lives in memory for the controller's life. It is shared
  by both modes and survives a mode switch.
- Turning guides off mid-drag clears them at once (a repaint) and re-targets
  without them.

Naming (my call, C-13): `alignmentGuides` on both the widgets and the
controller. `guides` alone could later clash with CAD construction guides.
Snap's `snapping`/`snap` split is not copied.

**User.** A new `PlanEditorAction.guides` and `PlanServiceAction.guides`.
- **The editor bar** (C-1): Snap and Zoom there are text read-outs, not
  buttons, and the default `actions` path builds the toolbar from the
  `file` and `edit` lists without consulting the action switch.
  - The toggle is therefore a command in the `edit` list, after Redo, so it
    shows on the default path. On an explicit `actions` list it shows where
    `guides` is listed.
  - Every editor switch over the action handles `guides` explicitly; a
    `_ =>` fallback does not count.
  - A test pins the button under the default `actions` and under an
    explicit list, and its absence when `alignmentGuides` is false.
- **The service bar**: the toggle goes after Redo in the undo group. Both of
  `PlanServiceView`'s exhaustive switches (button and grouping) list it.
- **Both bars**: a plain toggle button (an icon button with a selected
  state), so the shadcn session can restyle it. Its tooltip and semantics
  label are localised (en, de, tr).
- **The CHANGELOG** tells hosts two things: to add the case if they switch
  exhaustively over either enum; and that a host whose `actions` equal
  `values` now also gets the toggle.

**Alt held** (`ToolPointerEvent.alt`, or the key handler's state)
suspends guides. The final delta is then `dChain`, and no guide is drawn.

### The look (H6, O-9, C-18)

- **Lines**: a guide runs in screen space through the shared coordinate. It
  spans from the moving box to the farthest aligned reference, plus 8 px
  past each end. It is solid and `guideWidth` logical pixels wide, in the
  guide colour.
- **Gap marks**: one per equal gap, drawn at the middle of the perpendicular
  overlap of the two boxes on either side of the gap. Each is a segment
  across the gap with a short perpendicular tick (4 px) at both ends, in the
  same colour. Nothing is written.
- **Colour**: `PaperPalette` gains a nullable `guide`, an optional
  constructor argument, so existing callers compile unchanged.
  - Null means the built-in magenta matching the palette's paper, light or
    dark: light `0xFFE0218A`, dark `0xFFFF5CB0` (my call, checked against
    both canvases). The built-in light and dark palettes set it explicitly.
  - Its doc separates it from `preview`, whose comment already says "guide
    lines". `preview` is the move's base-to-target line, `guide` the
    alignment guides.
  - `PaperPalette` gains `withGuide`. `withSelection`, `==`, `hashCode` and
    every copy carry the field.
- **Theme**: `PlanTheme` gains `guideOnLight`, `guideOnDark` and
  `guideWidth`. `guideWidth` defaults to 1, with a range like
  `selectionWidth`'s.
  - The new fields are carried by validation, `copyWith`, `merge`, `lerp`,
    `==`, `hashCode` and `debugFillProperties`, like the selection fields.
  - `planPaperPaletteFor` applies `withGuide` after `withSelection`.
- **The width** reaches the painters through a plan-internal guide style.
  The views resolve the theme in `didChangeDependencies` and write a plain
  double into the session. The three guide painters (the design seam's plan
  implementation, `PlanSymbolTool` and `ServiceTool`) read it at paint.
  Nothing reads Flutter theme state while painting.
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
  - It is told when a move drag starts (the moved handles), and when it ends
    or is cancelled.
  - On every retarget, between `_resolve` and `moveTo`, it may replace the
    target point. Its inputs are the raw point, the base, the chain's point,
    whether the chain pinned an axis (ortho), the pointer kind and Alt.
  - It paints into `paintOverlay`.
  - Its exact name and signature are the builder's, as long as it stays
    generic, null by default, and leaves today's behaviour (and today's
    allocations) untouched when absent.
  - The plan library implements it and passes it in `buildGenericTools`.
- **Placement**: `PlanSymbolTool` applies the solver where *Modes* says,
  and paints the guides in its `paintOverlay`.
- **Service**: `ServiceTool._drag` and its new camera re-target apply the
  solver to `_dx/_dy`. It paints the guides in its `paintOverlay` beside the
  band.

## Constraints

- The frame path allocates nothing per entity in steady state and is O(1)
  per flush. `query_allocation_test`, `paint_allocation_test` and the plan's
  `canvas_paint_allocation_test` stay green.
- **Guides add no allocation over today's baseline (O-12, C-4).** Today's
  tools already allocate a few objects per event, independent of the number
  of entities. Examples: `GripDrag.moveTo`'s `Transform2`,
  `SelectTool._onCamera`'s `Vector2`, `PlanSymbolTool._free()` and its
  attachment query, and `ServiceTool`'s preview `Transform2`. Those are the
  baseline, not this work's to remove.
  - A new invariant measures warmed, end-to-end re-targets in all three
    tools (move, place, service), pointer-driven and camera-driven, with
    guides on and with guides off, at two reference counts (10 and 200) and
    two selection sizes.
  - Guides on minus guides off must be zero per event, and must not grow
    with the reference count. The measurement watches for `_Double`, `Aabb2`,
    `Transform2`, records, closures and collections.
  - It uses the VM `AllocationMeter`, as `pick_allocation_test` does. The
    guide paint is measured the same way.
  - Each budget has a named mutation that breaks it.
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
  differs from the raw press (O-2), with the switching bounds of *The delta*
  (C-7);
- Shift pins an axis and that axis never captures (C-6);
- a guide beats a wall endpoint under the pointer, with no blinking (C-8);
- seats and the moved objects' own carried children are not references
  (C-14); a number label does not stretch a box (C-15);
- placement guides after R and M with no pointer move (C-9), and Alt with no
  pointer move (C-16);
- the editor toggle under default and explicit `actions` (C-1);
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
