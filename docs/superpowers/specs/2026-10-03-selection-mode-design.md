# Selection-mode behaviour (14c) — design

**Date:** 2026-10-03. **Status:** design, **revision 2**: revision 1
(`b911cda`) reviewed independently, "Ready with fixes" (R-1 to R-14);
[Revision 2](#revision-2) is binding where it differs. **Sub-project:**
14 (restaurant embedding), slice **14c**.
**Umbrella:** [2026-10-03-restaurant-embedding-design.md](2026-10-03-restaurant-embedding-design.md)
(revision 3, approved): decisions 2, 8, 9, 10, 11 and D13–D16, D18,
M-14c, M-14d, M-14g, M-14h, M-14l are this spec's input. **14b-2's spec**
([2026-10-03-host-api-and-modes-design.md](2026-10-03-host-api-and-modes-design.md),
rev 2) moved the tap, status and layout callbacks here (A-2).
**Approval:** as 14b-2's — the human asked not to be asked unless needed
("Devam et", 2026-10-03); the umbrella's 14c decisions are approved; this
spec details them and is reviewed independently before its plan.
**Branch:** `claude/exciting-pasteur-9m22jv`; facts at `0f255be`.
**Size:** M. **Packages touched:** `jet_cad_floor_plan` only (the tool,
the status layer, the controller, the view, `PlannerView`'s underlay
slot); `apps/restaurant_demo`. Engine and render: untouched.

## What it delivers

In the selection mode, staff can **tap a table** to select it, **long
press** to add or remove one (decision 9; Shift- or Ctrl/⌘-click with a
mouse), **drag** a table — or the selected ones — to move them for the
service (decision 11), and **see each table's status as a colour** with
an optional short caption, set by the host (decision 2). A tap on empty
floor clears the selection; a drag on empty floor pans. The host hears
taps and layout changes by table number. Touch gestures beyond one finger
(pinch, two-finger pan) and the finger pick radius are 14t.

## Facts established (at `0f255be`)

- **F-1. The selection mode's tool is idle.** `ServiceView` gives the
  `InteractionLayer` an `IdleTool` (`host/service_view.dart`), whose every
  handler does nothing; 14b-2 H7 reserved the slot for this slice.
- **F-2. Pointer events reach the tool resolved.** `InteractionLayer._wrap`
  hands the tool the screen and world points, buttons and modifiers
  (`interaction_layer.dart:109-125`); a primary press (mouse button or a
  touch contact) starts a gesture, captured until its up or cancel
  (:129-176); the middle button belongs to the camera (:127). A tool may
  return a `selectionPreviewTransform`, which the overlay applies to the
  selection's outlines while it drags (`tool.dart:99`,
  `selection_overlay.dart:167`).
- **F-3. A table is a root-level instance of a servable definition**
  whose **first leaf is the served top** — a closed polyline or a circle
  (14s S4, 14a T1; `TableSurvey`). Instance-local space is definition
  space; the base point is the top's centre (14a F-6).
- **F-4. The controller resolves numbers.** `FloorPlanController` caches a
  `TableSurvey` per plan and state id, selects by number (visible,
  unlocked tables), keeps the selection across a switch, and moves
  `revision` on every change of the active plan (14b-2 H3, H13, R-7).
- **F-5. A translation of a table writes no label** (14a T12, M-14a-9),
  and the copy's dispatcher allows `transform` (`runtime`), so a move is
  one `TransformNodeCommand` per table, through the copy's own parametric
  and table systems (14b-2 R-4).
- **F-6. `PlannerView` stacks** the page chrome, the `DraftCanvas` and the
  selection overlay (`planner_view.dart:192-240`); there is no slot under
  the drafting.
- **F-7. The frame path's allocation bar** (`CLAUDE.md`): nothing per
  entity in steady state; the render package measures its painters by a
  structural read (`paint_allocation_test.dart:1-18`: a capacity that
  holds still), not by sampling.

## Decisions

### Picking a table

- **S1. `TablePicker`** (`src/service/table_picker.dart`): the candidates
  are the active plan's **tables** (F-3) on **visible** layers, each with
  its instance transform and its definition's **top**: a closed polyline
  (its vertices) or a circle (centre, radius), cached per definition and
  rebuilt only when the plan or its state id moves (F-4's key), never per
  pointer event. A world point is taken through each candidate's
  **inverse** instance transform into definition space and tested **inside
  the top** (decision 8): even-odd for a polygon, distance for a circle,
  with `Tolerance(linear: 1e-6 mm)` on the boundary (a point on the edge
  is inside). Among hits, the **highest instance handle** wins (draw
  order). Walls, chairs, labels and anything else are never picked
  (M-14c). Tables on locked layers are picked (D14).
- **S2. Not tables:** a servable instance inside a group (14a T1) and a
  table on a hidden layer are never picked.

### The tool

- **S3. `TableSelectTool`** (`src/service/table_select_tool.dart`)
  replaces `IdleTool` in `ServiceView`. With `kSlopPixels = 4` (the select
  tool's band slop) and `kLongPress = 500 ms`:
  - **down** on a table: remember it; start the long-press timer.
  - **move** past the slop before the timer: the timer is cancelled; a
    **drag** starts — on a selected table, the selection's **movable**
    tables move; on an unselected one, it is selected alone and moves
    (D16). Movable: the table is on an unlocked layer (M-14l). While
    dragging, the tool's `selectionPreviewTransform` is the translation
    (the outlines follow); nothing is executed.
  - **up** after a drag: **one** `CompoundCommand` of one
    `TransformNodeCommand` per moved table, labelled `Move`, translation
    only, no snapping (D16); nothing when the translation is zero or no
    table is movable. `onLayoutChanged` fires once (S8).
  - **up** without a drag, before the timer: a **tap** — the table alone
    is selected, or, with Shift or Ctrl/⌘ held, toggled in or out (mouse
    multi-select); `onTableTap(number)` fires (S8). A tap on empty floor
    clears the selection.
  - **the timer fires** (still within the slop): a **long press** —
    the table is toggled in or out of the selection (decision 9); the up
    that follows does nothing. On empty floor, nothing.
  - **down on empty floor, then a drag:** pans the camera by the screen
    delta (one finger or the primary button); 14t adds pinch and
    two-finger pan.
  - **cancel** (pointer cancel, a mode switch): any drag is dropped,
    nothing executed; the timer is cancelled.
  - **keys:** Escape clears the selection. No other key (D11).
  - No band, no grips, no rotation (decision 10), no keyboard shortcuts
    but the view's Undo/Redo (14b-2).
- **S4. An unnumbered table** is picked, selected and moved like any
  other; it is absent from `selectedTables` (14b-2 H3) and its tap
  reports no number (S8).

### The status layer

- **S5. `TableStatus`** (public, `host/floor_plan_types.dart`):
  `TableStatus({required Color color, String? caption})`, value-equal; a
  caption is at most 12 characters (longer is cut, no error).
- **S6. `controller.setTableStatus(Map<String, TableStatus> statuses)`**
  replaces every status at once (D13); `tableStatuses` reads them back.
  **Not document state:** no command, no undo, no `dirty`, not saved, not
  exported, not printed (D13; M-14d). Statuses are kept **by number** for
  the controller's life — across mode switches, `resetLayout` and `load`
  — and resolved against the active plan whenever it or its state moves:
  a number that names two tables colours both (umbrella D5); a number no
  table carries is kept and shows nothing. They are drawn **in the
  selection mode only**.
- **S7. `TableStatusPainter`** (`src/service/table_status_painter.dart`),
  in a new optional **underlay** slot of `PlannerView` between the page
  chrome and the `DraftCanvas` (F-6), its own `CustomPaint` and
  `RepaintBoundary`, so the fill is under the drafting (D13):
  - one cached **local** `Path` per definition top (F-3), built when the
    plan or its state moves, never per frame;
  - per frame, per statused, visible table: the composed matrix
    `camera · instance` written into **one reused** `Float64List(16)`,
    `canvas.save/transform/drawPath/restore` with **one reused** `Paint`
    per colour change (its colour set in place);
  - captions: one cached `Paragraph` per (caption, colour), built at
    status-change rate, drawn at the table's centre in screen space below
    the number, upright, at a fixed 11 px; skipped when the table is
    smaller on screen than the caption;
  - repaints on the camera, a status change and a plan change.
  **The allocation invariant is extended to it (F-7):** the painter
  counts every `Path`, `Paint`, `Paragraph` and matrix it creates
  (`debugAllocations`); a test paints a plan of **N = 60** statused
  tables (turned, mirrored, off the origin) three times, then pans and
  zooms, and the counter holds still across the later frames.

### The host's callbacks

- **S8. `FloorPlanView`** gains `onTableTap(String number)` and
  `onLayoutChanged()`; selection changes are `selectedTables` (14b-2),
  which a host listens to. Callbacks carry numbers, never handles (D18).
  `onLayoutChanged` fires once per executed move (not for undo or redo,
  which `revision` reports).

### Hidden and locked tables (D14)

- **S9.** Hidden-layer tables: not drawn (as today), not picked, no
  status painted, still in `tables` (with their numbers). Locked-layer
  tables: picked, selected, statused, **not moved** (a drag of one moves
  nothing; in a mixed selection, the others move).

### The demo

- **S10.** `apps/restaurant_demo` gains a **status** row per area: a
  number field and four status buttons (Free — no status, Ordered,
  Eating, Bill), a "Random statuses" button that colours every table, and
  the log lines for taps and layout changes.

## Files

- New: `packages/jet_cad_floor_plan/lib/src/service/{table_picker,
  table_select_tool,table_status_painter}.dart`.
- Changed: `lib/src/host/{floor_plan_types,floor_plan_controller,
  floor_plan_view,service_view}.dart`, `lib/src/planner_view.dart` (the
  underlay slot), `lib/jet_cad_floor_plan.dart` (`TableStatus`),
  `apps/restaurant_demo/lib/main.dart`.
- Tests: `test/service/{table_picker_test,table_select_tool_test,
  table_status_painter_test,status_allocation_test}.dart`,
  `test/host/{controller_test,view_test,barrel_test}.dart`,
  `apps/restaurant_demo/test/demo_test.dart`.

## Invariants

- The selection mode executes only `TransformNodeCommand`s, in one
  compound per drag, on the service copy (14b-2 H1): `designJson()` and
  `dirty` never move.
- A tap inside a table's top selects that table, whatever else lies over
  it; a tap on a chair, outside the top, does not.
- Statuses change no document, no history and no `dirty`.
- The status painter's steady-state frames create nothing (S7).
- Engine and render untouched; the two allocation invariants untouched.

## Testing and named mutants

Fixtures: tables off the origin, turned by 37° and mirrored, on a
non-default layer, a wall crossing a table, a duplicated number, a locked
and a hidden layer.

- **M-14c (umbrella):** pick the topmost anything — a tap on a table's top
  under a wall line still picks the table.
- **M-14h:** pick without the inverse instance transform — a tap inside a
  turned, mirrored table's top, outside its untransformed box, picks it.
- **M-14c2-1:** pick on the definition's box, not the top — a tap on a
  chair (inside the box, outside the top) picks nothing.
- **M-14c2-2:** the lowest handle wins — two overlapping tables: the
  higher handle is picked.
- **M-14l:** a locked-layer table moves — dragging it changes nothing; in
  a mixed selection only the unlocked ones move.
- **M-14c2-3:** a drag executes per move event — one undo step per drag.
- **M-14c2-4:** a drag rotates or snaps — the moved transform's linear
  part is exactly the old one, and the translation is the drag's delta
  (world), unsnapped.
- **M-14c2-5:** a long press acts as a tap — it toggles (adds to a
  selection of one, removes from it), and its up does nothing.
- **M-14c2-6:** a slop-crossing press still long-presses — a press that
  drags before 500 ms never toggles.
- **M-14d (umbrella):** statuses as document state — `setTableStatus`
  leaves `revision`, `dirty`, the undo depth and `designJson()` alone.
- **M-14g (umbrella):** statuses tested at the identity only — the
  painter's fill for a turned, mirrored, off-origin table covers the top's
  centre on screen and not a point of a chair (pixels read back from a
  rendered image).
- **M-14c2-7:** statuses kept by handle — a renumber moves the colour with
  the number; a `load` of another plan re-resolves.
- **M-14c2-8:** the painter allocates per frame — the counter test (S7).
- **M-14c2-9:** `onTableTap` with a handle, or on a drag — taps report
  the number; a drag reports none; `onLayoutChanged` once per drag.
- **M-14c2-10:** a hidden table picked or painted.

## Risks

- **Mouse and touch share the tool.** A touch contact is a primary press
  (F-2), so one-finger taps, long presses, drags and pans work on a
  tablet now; pinch and the finger pick radius wait for 14t.
- **Float precision** of the composed matrix for the fills far from the
  origin: the drafting rebases (`DraftPainter`), the status layer does
  not. A fill is a coarse shape; an error below a pixel at 1e6 mm is
  accepted, and the M-14g fixture sits 40 m off the origin.
- **The preview moves outlines only**: during a drag the drafting and the
  status fill stay until release (as the design mode's move does).

## Revision 2

Applied from the independent review of revision 1. Facts confirmed, with
citations: the top comes from the lowest-handle leaf
(`tables/table_label.dart:157`, `firstLeafOf`); a closed polyline repeats
its first point (`drafting.dart:104-116`); `PlannerView`'s Stack is at
`planner_view.dart:192-226`.

- **R-1 → S9 replaced (A-1).** The selection prunes keys on locked or
  hidden layers at every document change (`selection.dart:168-196`), and
  the controller already refuses to select them (14b-2 R-6); keeping a
  locked table selected would need a render change. So a **locked** table
  is **picked** (a tap fires `onTableTap` with its number) and
  **statused**, but **never selected, toggled or moved**; a drag that
  starts on one does nothing (no move, no pan). **M-14l** becomes:
  dragging a locked table changes no transform and no selection; a long
  press does not toggle it.
- **R-2 → the asymmetric fixture.** Every catalog top is symmetric about
  its base point, so a mirror cannot be seen on it. M-14h, M-14g and the
  allocation corpus use a **hand-made servable definition with an
  asymmetric top** (an off-centre trapezoid, a `SeatingComponent`), turned
  37°, mirrored, 40 m off the origin; inside and outside points are
  computed in the test with the forward transform, near the edges. New
  mutant **M-14c2-11**: the inverse ignores the mirror.
- **R-3 → S7's measurement.** The paint loop is an **indexed loop over a
  list prebuilt** when the statuses or the plan's state change (instance,
  path, colour, paragraph, the top's local centre): no map iteration, no
  closure, no `Offset` per frame — captions are drawn with
  `canvas.translate(x, y)` and `drawParagraph(p, Offset.zero)`, inside the
  save/restore. The invariant is measured **structurally**: a recording
  canvas asserts that, after warm-up, every frame passes the **identical**
  `Path`, `Paint` and `Paragraph` objects and the identical matrix buffer;
  the counter stays as a second check.
- **R-4 → S6, S7 detailed.** The painter repaints on the camera, on the
  statuses and on **every document change** of the plan it shows (a
  move, an undo, a redo), through a listener it disposes. Statuses are a
  `ValueListenable<Map<String, TableStatus>> tableStatuses` of the
  controller (`Map.unmodifiable`, keys trimmed); `setTableStatus` does not
  notify the controller and does not move `revision` (M-14d). The
  controller resolves numbers to instances in an `@internal` view keyed by
  (document, state id, statuses).
- **R-5 → the wiring.** `FloorPlanView` passes `ServiceView` a settings
  reader, as `PageFlows` reads its own: the tool reads `onTableTap` and
  `onLayoutChanged` at call time. The picker and the tool live per
  `ServiceView` (one per copy); `ServiceView` disposes the tool. The tool
  uses a `dart:async` `Timer`, cancelled in `cancel` and `dispose`;
  `InteractionLayer._release` cancels the tool on deactivate
  (`interaction_layer.dart:200-218`), so a `resetLayout`, a `load` or a
  switch mid-gesture drops the drag and the timer (tested).
- **R-6 → S3's gaps.** After a long press the gesture is **spent**: moves
  and the up do nothing; a long press fires **no** `onTableTap`. A
  Shift/Ctrl tap on empty floor keeps the selection. An up after a pan
  changes no selection. Hover moves (no button) are ignored. At release
  the delta is applied to each table's transform **as it is then**, and a
  table no longer live is skipped (an Undo can land mid-drag). The long
  press is Flutter's `kLongPressTimeout`.
- **R-7 → one slop, the touch one.** The selection mode is mostly used by
  finger; `ToolPointerEvent` carries no pointer kind (`tool.dart:17-38`),
  so the slop is Flutter's **`kTouchSlop` (18 px)** for every pointer;
  14t may split it by kind.
- **R-8 → the picker.** Candidates with a singular transform are skipped
  (`invert` throws); a definition whose first leaf is neither a closed
  polyline nor a circle is never picked and never filled. Tops are cached
  **per definition** for the picker's life (under `runtime` definitions
  cannot change); inverses per state id.
- **R-9 → M-14c's fixture.** The wall has a **higher** handle than the
  table and the tap lies within 6 px of the wall line, inside the top.
- **R-10 → M-14g.** Rendered through a `PictureRecorder` with the painter
  alone (no caption, no label), read back under `runAsync`
  (`room_paint_test.dart:140` is the precedent).
- **R-11 → amendments.** (A-2) `tables` gains no hidden flag in v1: a host
  that needs it reads its layers itself — recorded, not built.
  `onSelectionChanged` is `selectedTables` (14b-2). (A-3) `fitToView`
  still fits the page (14b-2), not the visible tables' extents (D17, 14t).
- **R-12.** A caption is cut to 12 **characters** (grapheme clusters).
- **R-13.** The demo's "Random statuses" takes a seeded `Random`.
- **R-14.** The matrix is composed in doubles (camera · instance) before
  it reaches the canvas; no world-coordinate translate: precise as the
  drafting's rebase for tops with ordinary local coordinates. The risk is
  restated accordingly.

