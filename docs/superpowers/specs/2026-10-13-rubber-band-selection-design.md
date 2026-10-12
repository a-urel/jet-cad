# Rubber-band selection in the selection mode — design

**Date:** 2026-10-13. **Status:** revision 2, awaiting the human's review
of the written spec. Revision 1 (`fa1da0d`) was reviewed independently
(an Opus reviewer, read-only): **Approve with fixes**, V-1 to V-16, one
blocker (V-1); revision 2 folds in every fix, and the two the human was
asked about (V-4, V-12) as the human answered (see [Review](#review)).

**Asked for by the human, 2026-10-13:** "O-4 ile devam et" — the host
embedding API spec's out-of-scope item O-4, "multi-select of tables by
rubber band in the selection mode".

**Branch:** `feat/rubber-band`, from `main` at `1e53de1` (release 0.6.0,
tag `v0.6.0` → `3bf64a7`). **Size:** S–M, one slice. **Touched:**
`jet_cad_2d_flutter` (the band's painting, shared), `jet_cad_floor_plan`
(the selection tool, the view's option, the host barrel), the restaurant
demo, the host guide, the CHANGELOG, four specs' notes. **Release:**
0.7.0, on the human's word. **No host's code breaks** (P-1); **one
gesture changes under the defaults** (RB-1: a modifier mouse drag on the
floor draws a band where it panned).

## Purpose

A host serving a restaurant selects several tables at once — to merge
them, colour them (`setTablesColor`), or act on a section. Today the
selection mode selects many tables only one at a time: a Shift, Ctrl or
Cmd click, or a long press (touch). A rubber band, as the design mode
has, selects a region in one gesture.

## Decisions taken in the brainstorm (the human, 2026-10-13)

1. **The host chooses what a drag on the empty floor does**:
   `FloorPlanView(floorDrag:)`, `pan` (today's, the default) or `band`.
   Under `pan`, a mouse or stylus drag with Shift, Ctrl or Cmd held opens
   the band as well; a touch drag never does (a finger has no modifier).
2. **Inclusion by direction**, the design mode's CAD rule: left to right
   is a window (only tables wholly inside; a solid outline), right to
   left a crossing (every table touched; a dashed outline).
3. **Combining**: a plain band replaces the selection; a band with
   Shift, Ctrl or Cmd adds to it (a union: a selected table inside is
   never dropped). Under `pan` a band always has a modifier, so it
   always adds; the floor tap clears.
4. **Approach A**: the band is a state of the selection mode's tool;
   what it takes is decided by the design mode's band query on the
   spatial index (`forEachInstanceInBand`), kept to the selection mode's
   own candidates; the band's look is the design mode's, painted by one
   shared painter.
5. Sections 1 to 4 approved as presented, with: no auto-scroll at the
   canvas edge, no live highlight during the band, release 0.7.0.
6. **After the review** (the human, 2026-10-13): under `band`, a finger
   press that reached a table **by the reach only** starts a band when
   dragged (V-4); **the modifier is read at the down** (V-12, R-1).

## Facts (at `1e53de1`)

- **F-1. The tool.** `TableSelectTool`
  (`jet_cad_floor_plan/lib/src/service/table_select_tool.dart`) has
  `_Gesture { none, pressed, dragging, panning, spent }`, mapped to
  `ToolPhase` by `phase` (`:189-193`); `selectionPreviewTransform` reads
  `dragging` only (`:195`). A down takes the primary button only and only
  while `_gesture == none` (`:199`), picks with `TablePicker.pick` (a
  finger's reach 24 px, 14t R-11), reads `_toggle = e.shift || e.control
  || e.meta`, `options()` and `userCamera()`. Past `kTouchSlop` (every
  pointer kind, 14c R-7) `_lastTap` is cleared for every branch
  (`:241`); then a press on no table — or on any table when
  `serviceMoves` is false (14d S5) — pans, or is spent when `userCamera`
  is false (G-3); with moves on, a locked table is spent and an unlocked
  one drags (`_startDrag`). The up taps (`_tap`), moves (`_move`) or does
  nothing. `paintOverlay` is empty. Escape clears the selection only
  while idle and `idleKeys()` (`:525-535`).
- **F-2. Groups.** `_groupLookup()` resolves the host's table groups
  against `picker.candidates`; `_memberKeys(lookup, id)` is a group's
  selectable members; a tap on a member replaces the selection with
  them, a modifier tap adds or removes the group whole (table-groups G4).
- **F-3. Candidates and the pick.** `TablePicker.candidates` lists the
  live, root-level, servable tables on visible layers with finite
  corners and a non-empty box (zone spec Z0's one candidate rule), each
  with `locked` (its layer locked). A locked table is picked and
  reported, never selected or moved (14c R-1, A-1). `pick(world, reach)`
  tries a table's top, then its box (chairs included), then — a finger
  only — the nearest box within the reach (`table_picker.dart:346-362`).
- **F-4. The design band.** `SelectTool`
  (`jet_cad_2d_flutter/lib/src/select_tool.dart`) starts a band from an
  empty press past its slop (`kBandSlopPixels` 4 for a mouse,
  `kTouchSlop` for a finger), sets `BandMode.window` when
  `_end.dx >= _start.dx` else `crossing`, live (`:239`, `:307`). At the
  up `_bandKeys` converts **both screen corners at release** under the
  camera then (spec D8, `:567-572`), queries `forEachLeafInBand` and
  `forEachInstanceInBand` (`jet_cad_2d/lib/src/index/spatial_index.dart:445`):
  window passes an instance whose every member leaf is enclosed (at
  least one), crossing one with a member leaf touched; an instance is
  never taken by its bounding box alone. It reads Shift **at the up**
  (`:524`): Shift toggles, else replaces. Escape cancels a drag whatever
  the gates say, and every key is taken while dragging (`:707-715`,
  Ruling 03-8). `paintOverlay` (`:876-912`) fills the screen rect with
  the band colour at `kBandFillAlpha` and strokes it 1 px, solid for a
  window, 6-on/4-off dashed for a crossing, with
  `PaperPalette.windowBand` / `crossingBand`.
- **F-5. The filter.** `forEachInstanceInBand` keeps a root instance
  only if `acceptsNode(node, filter)` (`spatial_index.dart:462-463`);
  `QueryFilter.picking()` excludes a locked layer's instance
  (`query_filter.dart:36-39`, `:179-183`); `QueryFilter.snapping()` is
  visible and pickable, a locked layer included (`:44-47`).
- **F-6. The view.** `FloorPlanView` takes `serviceMoves`, `longPress`
  and `userCamera`; `ServiceView` builds the tool with `options` (the
  `ServiceOptions` record: `serviceMoves`, `longPress`,
  `onTableContextMenu`) read at each press, and its own `SpatialIndex`
  in the `ToolContext`. `ServiceOptions` is internal (no barrel exports
  it); its record literals are at `floor_plan_view.dart:698` and in
  `service_options_test.dart`, `table_groups_context_test.dart`,
  `table_overlay_test.dart`. A secondary click acts only while the
  tool's phase is idle (`service_view.dart:205`). The selection overlay
  paints below the host's table overlays (`planner_view.dart:430-448`).
- **F-7. Touch.** `InteractionLayer` holds a first finger back 100 ms
  (14t T3); a second finger goes to the camera (pinch, two-finger pan)
  and cancels the tool **when its phase is not idle**
  (`interaction_layer.dart:237`); in a multi-finger session the routed
  finger's up never reaches the tool (`:295`).
- **F-8. The camera** pans and zooms only (`camera_controller.dart`);
  its matrix is y-flipped (`ViewportTransform.fit`). It never rotates.
- **F-9. `selectedTables`** notifies only when its set of numbers
  changes (`floor_plan_controller.dart:1929`); a `SelectionController.
  replace` with the same keys is silent (`selection.dart:124`) and does
  not filter locked keys (pruning runs on a document change, `:174`).
- **F-10. Binding text this changes.** Selection-mode spec S3 ("no
  band, no grips, no rotation"; "a drag on empty floor pans"),
  restaurant-embedding D11 ("no band") and D17 (one-finger pan), touch
  spec T6 ("one finger on the floor still pans"), and host embedding
  API O-4 (out of scope). `FloorPlanLongPress.contextMenu`'s doc says a
  touch screen then has no multiple selection.

## Design

### RB-1. The option

```dart
/// What a one-pointer drag on the empty floor does in the selection
/// mode. The design mode is unaffected.
enum FloorPlanFloorDrag {
  /// Pans the camera (today's). With Shift, Ctrl or Cmd held at the
  /// press, a mouse or stylus drag draws a band that adds to the
  /// selection.
  pan,

  /// Draws a band that selects tables; the camera pans with two
  /// fingers, the wheel or trackpad, and the middle button.
  band,
}
```

In `floor_plan_types.dart`, added to the host barrel's `show` list
(`jet_cad_floor_plan.dart:30-40`).
`FloorPlanView({FloorPlanFloorDrag floorDrag = FloorPlanFloorDrag.pan})`,
named and optional: no host's code changes (P-1). `ServiceOptions` gains
a `floorDrag` field and `kDefaultServiceOptions` sets `pan`; the view
fills it from `widget.floorDrag`, read at each press as the other
options are; F-6's record literals gain the field.

**A behaviour change under the defaults.** Today a Shift, Ctrl or Cmd
mouse drag on the floor pans (or is spent under `userCamera: false`);
under `pan` it now draws a band. The CHANGELOG and the guide say so.

### RB-2. When a band starts

At the press (a primary down, F-1), as today; the down also notes
whether a finger's hit came **by the reach only**: a touch press whose
`pick(world, reach: r)` found a table while `pick(world, reach: 0)`
finds none (one extra pick, a finger's down only; nothing allocated,
`pick_allocation_test`). Past `kTouchSlop` the tool decides, in this
order:

1. A press **on a table** — by its top or its box, or by the reach
   under `pan` — behaves as today: with `serviceMoves` true an unlocked
   table moves and a locked one is spent; with it false the drag pans
   (14d S5), or is spent under `userCamera: false`.
2. A press **on the floor**, or a finger's press on a table by the
   reach only under `band`, starts a band when `floorDrag` is `band`
   (any pointer kind), or when `floorDrag` is `pan`, the press held a
   modifier and the pointer is not a finger.
3. Otherwise today's floor rule: pan, or spent under `userCamera: false`.

A tap keeps the reach: a finger tapping near a table still selects it
(14t R-11), under either option. A band starts whatever `userCamera`
says: G-3 locks the camera, not the selection. The slop stays
`kTouchSlop` for every pointer (14c R-7), not the design mode's 4 px.
The long-press timer never runs on the floor (F-1); a reach-only press
under `band` starts the timer as a table press does, and the slop
cancels it before the band starts, as for every drag. `_lastTap` is
cleared at the slop, as for every drag.

**The modifier is read once, at the down** (`_toggle`, F-1), for both
the start and the combining (RB-4): a band's meaning is fixed from its
first frame, as a tap's is. The design mode reads Shift at the up
(F-4); the guide states the difference (R-1).

**The band's phase is `ToolPhase.dragging`**: a second finger cancels
it (F-7), and a secondary click during a band does nothing (F-6).
`selectionPreviewTransform` stays null during a band.

### RB-3. What a band takes

The tool keeps the press's screen point and the pointer's latest. The
mode is `bandModeFor(start, end)`: window when `end.dx >= start.dx`,
else crossing, re-evaluated at every move. The band ends at the
pointer's up wherever it lands — the pointer is captured, so off the
canvas too, as in the design mode.

At the up, both screen corners are converted to the world **under the
camera at the up** (F-4's rule; a wheel zoom during a band is honoured).
Then:

1. `ctx.index.forEachInstanceInBand(world, mode,
   const QueryFilter.snapping(), …)` gives the passing root instances —
   **`snapping`, not `picking`**: a locked layer's table must reach step
   3's window rule (F-5).
2. **Kept**: those that are among `picker.candidates` (F-3: a table, on
   a visible layer, finite, non-empty). Not a table — a plant, a bar, a
   wall's instance — is never kept. Call this set *P*; it holds locked
   tables.
3. **Groups** (G4; the tool's `_groupLookup()`):
   - **Crossing**: a group is taken when some **unlocked** member is in
     *P*.
   - **Window**: a group is taken when **every visible member** is in
     *P*, locked members included: a group half outside the window is
     not taken; a group wholly inside with a locked member is.
   - A taken group contributes its selectable members (`_memberKeys`);
     a member of a group not taken contributes nothing.
4. **Lone tables**: each unlocked table in *P* with no group
   contributes itself.
5. The union of 3 and 4 is the band's keys *K*, ascending by handle.

A locked table is never in *K*, and this filter is the only guard:
`replace` does not drop locked keys (F-9). An unnumbered table may be in
*K* and selected; it is absent from `selectedTables` as always (14c S4).
A zone's veil changes nothing (Z15).

### RB-4. What a band does to the selection

- **Plain** (no modifier at the down; only under `band`):
  `selection.replace(K)`. An empty *K* clears the selection: a band
  selects what it holds (R-2).
- **With a modifier**: `selection.replace(selection.keys ∪ K)` — one
  call, a union; a selected table inside stays selected, never toggled.
  An empty *K* changes nothing.

One `replace` per band: the selection notifies once when *K* changes
its set, and `selectedTables` at most once (F-9). No view event fires
for a band: not `onFloorTap`, `onTableTap`, `onGroupTap`, a double tap
nor `onTableHover` (the pointer's moves carry a button). No new
callback: a host listens to `selectedTables` (YAGNI).

### RB-5. Cancelling

A band ends with nothing changed when:

- the tool's `cancel` runs — a second finger (F-7), a pointer cancel, a
  mode switch, a new tool;
- **Escape** is pressed while it is live: always, whatever `idleKeys()`
  says (that governs only the idle Escape, C-7 and S-16), and the key is
  `handled`, as the design mode's drag does (F-4). Every other key down
  during a band is `handled` too, so no host or view shortcut (an undo)
  lands in the middle of it.

After a cancel the tool is idle: the next press, a tap, acts.

### RB-6. Painting

`jet_cad_2d_flutter` gains, exported (the floor planner cannot import
its `src/`, so the painter is public):

```dart
/// The band's mode by its drag direction (interaction-core D1): left to
/// right is a window, right to left a crossing.
BandMode bandModeFor(Offset start, Offset end);

/// Paints a selection band over [rect], in screen pixels: the band
/// colour at kBandFillAlpha, a 1 px outline, solid for a window, dashed
/// 6 on and 4 off for a crossing.
final class SelectionBandPainter {
  SelectionBandPainter();
  void paint(Canvas canvas, Rect rect, BandMode mode, PaperPalette paper);
}
```

The painter keeps its two `Paint`s and its `Path` and resets them per
call: no `Paint` or `Path` per frame; the rest is O(1) per frame, nothing
per table. `SelectTool` uses both (a pure refactor: the design band's
colours and dashes are unchanged, pinned by `tool_palette_test.dart:
200-238`). `TableSelectTool.paintOverlay` paints the band only while one
is live, from the press's screen point to the pointer's latest. The band
paints below the host's table overlays (F-6), as the selection outlines
do.

### RB-7. The demo, the guide, the CHANGELOG, the specs

- **Restaurant demo**: a "Floor drag" switch, *Pan / Select* (de
  *Ziehen auf dem Boden: Verschieben / Auswählen*, tr *Zeminde sürükle:
  Kaydır / Seç*), passed as `floorDrag`.
- **Host guide**: a "Selecting with a band" section — the option, the
  two triggers, the direction rule, groups and locks, the camera under
  `band`, the reach-only press, the modifier read at the press (unlike
  the design mode); its code blocks in the host probe (`check_guide`).
- **CHANGELOG** (Unreleased): the option; the behaviour change under
  the defaults (a modifier mouse drag on the floor bands); `bandModeFor`
  and `SelectionBandPainter` in `jet_cad_2d_flutter`.
- **Specs**: host embedding O-4 "Taken up" with a link; selection-mode
  S3, restaurant-embedding D11 and D17, touch T6 each get a dated note:
  "except under `floorDrag: band` (rubber-band spec RB-2)";
  `FloorPlanLongPress.contextMenu`'s doc names `floorDrag: band` as a
  touch screen's multiple selection.

### Rulings

- **R-1.** The modifier is read at the down (RB-2), the human's answer
  to V-12: one reading for the start and the combining, as a tap reads
  it. Costs, if wrong: one field read at the up instead.
- **R-2.** A plain band over nothing clears (RB-4), as a plain tap on
  the floor clears. Costs, if wrong: an `if (K.isEmpty) return`.
- **R-3.** Under `serviceMoves: false` a drag from a table (by its top
  or box) still pans (14d S5), even under `band`. Costs, if wrong: one
  branch in RB-2.
- **R-4.** A reach-only finger press under `band` bands when dragged and
  still selects when tapped, the human's answer to V-4. Costs, if wrong:
  the flag and its branch.

## Testing

Every test is worth landing only if a named mutation turns it red.
Fixtures are never degenerate: the camera is y-flipped, scaled ≠ 1 and
off the origin (it never rotates, F-8); tables are rotated and one is
mirrored; one table is L-shaped and rotated 37°; the plan holds a group
of three, a table on a locked layer, a group with a locked member, an
unnumbered table, a table on a hidden layer and a non-table symbol.

| # | Test | Mutation killed |
|---|---|---|
| RB1 | `pan`: a plain floor drag pans, the selection unchanged | M-RB1: the band starts without the modifier check |
| RB2 | `pan`: a Shift mouse drag bands and adds; a Shift *touch* drag pans | M-RB2: the `!isTouch` check dropped |
| RB3 | `band`: one finger and the mouse band; two fingers pan (the camera moved, the band cancelled), and after the fingers lift the next tap selects | M-RB3: `floorDrag` ignored; M-RB3b: the band mapped to `ToolPhase.idle` |
| RB4 | `band` with `userCamera: false`: the band works | M-RB4: the band gated on `_pans` |
| RB5 | under `band`, a drag from an unlocked table moves it, from a locked one is spent; with `serviceMoves: false` it pans | M-RB5: a band started on a table |
| RB5b | under `band`, a finger pressed 10 px outside a table's box bands when dragged and selects that table when tapped | M-RB5b: the reach-only flag ignored (the drag moves the table) |
| RB6 | window: the rotated L-shaped table, every leaf enclosed while its box's empty-quadrant corner lies outside the band, is taken | M-RB6: the instance's bounding box used |
| RB7 | crossing takes a touched table; a crossing over only the L's empty quadrant takes nothing; direction flipped mid-drag changes the mode | M-RB7: the mode fixed at the start; M-RB7b: the box used for crossing |
| RB8 | a wheel zoom about a point away from the band's start, during the band: the corners converted under the camera at the up | M-RB8: the press's world point used |
| RB9 | hidden and non-table instances are never selected; the unnumbered one is selected and absent from `selectedTables` | M-RB9: the candidate filter dropped |
| RB10 | a lone locked table inside a window is not selected; a window round a whole group with a locked member selects its unlocked members; crossing one member takes the group whole; a window with one member outside takes none of it | M-RB10: the lock filter dropped; M-RB10b: `picking()` kept; M-RB11: no group expansion; M-RB12: the window's every-member rule dropped |
| RB11 | plain replaces; modifier adds and keeps a selected table inside | M-RB13: `toggle` instead of union |
| RB12 | a plain empty band clears; a modifier empty band changes nothing | M-RB14: the empty rule inverted |
| RB13 | `selectedTables` notifies once for a band that changes it; no `onFloorTap`, `onTableTap`, `onGroupTap`, `onTableHover`; a band ending over a table after an earlier tap on it reports no tap and no double tap | M-RB15: a per-key add; M-RB16: the up falls into `_tap` |
| RB14 | Escape (also under `shortcuts: false`), a second finger, a mode switch and a secondary click: the band cancelled or untouched, the selection unchanged; a key during a band is handled | M-RB17: Escape gated on `idleKeys`; M-RB17b: keys not handled mid-band |
| RB15 | the band painted at the screen rect, solid for a window, dashed for a crossing (recording canvas) | M-RB18: the mode's stroke swapped |
| RB16 | no `Paint` or `Path` built per frame while a band is live (the VM `AllocationMeter`, `--enable-vmservice`, as `pick_allocation_test`) | M-RB19: a `Paint` built per call |
| RB17 | the design band's colours and dashes unchanged (`tool_palette_test.dart:200-238`) | (the refactor's pin) |
| RB18 | under zone focus a veiled table is taken (Z15) | M-RB20: candidates filtered by the focus |
| RB19 | `longPress: contextMenu`, touch, under `band`: a long press on a table opens the menu; a floor drag bands | M-RB21: the band start gated on `longPress` |
| RB20 | the host probe builds with `floorDrag: band`; the 0.3.0, 0.4.0, 0.5.1 and 0.6.0 probes stay green | (P-1) |

## Out of scope, recorded

- Auto-scroll when a band reaches the canvas edge.
- A live highlight of the tables a band would take.
- A band in the selection mode under `pan` by touch (no modifier exists).
- A lasso (free-form) selection.

## Risks

- **A host that turns on `band` loses one-finger pan.** Stated in the
  option's doc and the guide; two fingers, the wheel and the middle
  button still pan.
- **Window on a table with chairs.** Where a table's symbol draws its
  chairs, they are its leaves, so a window must hold the chairs too;
  this is the design mode's rule and the brainstorm chose it.
- **The reach-only press moves no table under `band`.** To move a
  table by touch, a finger starts on the table itself.

## Review

Revision 1 (`fa1da0d`), an independent Opus reviewer: **Approve with
fixes**.

| # | Finding | Severity | Revision 2 |
|---|---|---|---|
| V-1 | `picking()` drops locked-layer tables before the window rule | Blocker | F-5; RB-3 step 1 queries `snapping()`; RB10 and M-RB10b |
| V-2 | the band's `ToolPhase` unspecified (a second finger, a secondary click) | Important | RB-2's last paragraph; RB3, RB14 |
| V-3 | Escape gated on `idleKeys` contradicts the design mode and C-7/S-16 | Important | RB-5; RB14, M-RB17 and M-RB17b |
| V-4 | a finger's 24 px reach leaves little floor to band from | Important | the human: a reach-only press bands (R-4); RB-2; RB5b |
| V-5 | RB6's mutation not killable as worded | Important | RB6 and RB7 rewritten |
| V-6 | RB16's rig measures sink buffers, and the code allocates per frame | Important | RB-6 reworded; RB16 on the VM meter |
| V-7 | a rotated camera does not exist | Important | F-8; the fixture paragraph |
| V-8 | a modifier drag changes under the defaults | Important | the header, RB-1, RB-7 |
| V-9 | RB-5's third bullet is no cancellation | Minor | moved to RB-3 |
| V-10 | "notifies exactly once" overstated | Minor | F-9; RB-4; RB13 |
| V-11 | citations (S9, S5, locked under moves off, `_lastTap`, spec count) | Minor | F-1, F-3, R-3, RB-2, the header |
| V-12 | R-1 overrode the approved section 2 | Minor | the human: at the down (R-1) |
| V-13 | missing tests | Minor | RB8, RB13, RB18, RB19 |
| V-14 | the files the field touches | Minor | F-6; RB-1 |
| V-15 | the band paints under host overlays | Minor | F-6; RB-6 |
| V-16 | the painter's surface | Minor | RB-6 (`final class`, no-argument constructor; RB17's pin) |
