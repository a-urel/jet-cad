# Rubber-band selection in the selection mode — design

**Date:** 2026-10-13. **Status:** revision 1, sections approved by the
human in the brainstorm; written spec awaiting review.

**Asked for by the human, 2026-10-13:** "O-4 ile devam et" — the host
embedding API spec's out-of-scope item O-4, "multi-select of tables by
rubber band in the selection mode".

**Branch:** `feat/rubber-band`, from `main` at `1e53de1` (release 0.6.0,
tag `v0.6.0` → `3bf64a7`). **Size:** S–M, one slice. **Touched:**
`jet_cad_2d_flutter` (the band's painting, shared), `jet_cad_floor_plan`
(the selection tool, the view's option, the host barrel), the restaurant
demo, the host guide, the CHANGELOG, three specs' notes. **Release:**
0.7.0 (a new host option; nothing breaks), on the human's word.

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
   shared function.
5. Sections 1 to 4 approved as presented, with: no auto-scroll at the
   canvas edge, no live highlight during the band, release 0.7.0.

## Facts (at `1e53de1`)

- **F-1. The tool.** `TableSelectTool`
  (`jet_cad_floor_plan/lib/src/service/table_select_tool.dart`) has
  `_Gesture { none, pressed, dragging, panning, spent }`. A down takes
  the primary button only, picks with `TablePicker.pick` (a finger's
  reach 24 px, R-11), reads `_toggle = e.shift || e.control || e.meta`,
  `options()` and `userCamera()`. Past `kTouchSlop` (every pointer kind,
  14c R-7) a press on no table — or on any table when `serviceMoves` is
  false (14d S5) — pans, or is spent when `userCamera` is false (G-3); a
  locked table is spent; an unlocked one drags (`_startDrag`). The up
  taps (`_tap`), moves (`_move`) or does nothing. `paintOverlay` is
  empty. Escape clears the selection only while idle and `idleKeys()`.
- **F-2. Groups.** `_groupLookup()` resolves the host's table groups
  against `picker.candidates`; `_memberKeys(lookup, id)` is a group's
  selectable members; a tap on a member replaces the selection with
  them, a modifier tap adds or removes the group whole (table-groups G4).
- **F-3. Candidates.** `TablePicker.candidates` lists the live,
  root-level, servable tables on visible layers with finite corners and
  a non-empty box (zone spec Z0's one candidate rule), each with
  `locked`. A locked table is picked and reported, never selected or
  moved (14c S9).
- **F-4. The design band.** `SelectTool`
  (`jet_cad_2d_flutter/lib/src/select_tool.dart`) starts a band from an
  empty press past its slop (`kBandSlopPixels` 4 for a mouse,
  `kTouchSlop` for a finger), sets `BandMode.window` when
  `_end.dx >= _start.dx` else `crossing`, live. At the up `_bandKeys`
  converts **both screen corners at release** under the camera then
  (spec D8), queries `forEachLeafInBand` and
  `forEachInstanceInBand(band, mode, QueryFilter.picking(), …)`
  (`jet_cad_2d/lib/src/index/spatial_index.dart:445`): window passes an
  instance whose every member leaf is enclosed (at least one), crossing
  one with a member leaf touched; an instance is never taken by its
  bounding box alone. Shift toggles, else replaces. `paintOverlay` fills
  the screen rect with the band colour at `kBandFillAlpha` and strokes it
  1 px, solid for a window, 6-on/4-off dashed for a crossing, with
  `PaperPalette.windowBand` / `crossingBand`; it allocates two `Paint`s
  and a `Path` per frame while a band is live.
- **F-5. The view.** `FloorPlanView` takes `serviceMoves`, `longPress`
  and `userCamera`; `ServiceView` builds the tool with `options` (the
  `ServiceOptions` record: `serviceMoves`, `longPress`,
  `onTableContextMenu`) read at each press, and its own `SpatialIndex`
  in the `ToolContext`. `ServiceOptions` is internal (no barrel exports
  it).
- **F-6. Touch.** `InteractionLayer` holds a first finger back 100 ms
  (14t T3); a second finger goes to the camera (pinch, two-finger pan)
  and cancels a tool that is not idle (T6).
- **F-7. Binding text this changes.** Selection-mode spec S3 ("no
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
  /// Pans the camera (today's). With Shift, Ctrl or Cmd held, a mouse or
  /// stylus drag draws a band that adds to the selection.
  pan,

  /// Draws a band that selects tables; the camera pans with two
  /// fingers, the wheel or trackpad, and the middle button.
  band,
}
```

In `floor_plan_types.dart`, exported by the host barrel.
`FloorPlanView({FloorPlanFloorDrag floorDrag = FloorPlanFloorDrag.pan})`,
named and optional: no host's code changes (P-1). `ServiceOptions` gains
a `floorDrag` field and `kDefaultServiceOptions` sets `pan`; the view
fills it from `widget.floorDrag`, read at each press as the other
options are.

### RB-2. When a band starts

At the press (a primary down, F-1), as today. Past `kTouchSlop` the
tool decides, in this order:

1. A press **on a table** behaves as today: a drag of an unlocked
   table moves it (or, with `serviceMoves` false, pans as S5 says); a
   locked one is spent. A band never starts on a table.
2. A press **on the floor** starts a band when `floorDrag` is `band`
   (any pointer kind), or when `floorDrag` is `pan`, the press held a
   modifier and the pointer is not a finger.
3. Otherwise today's floor rule: pan, or spent under `userCamera: false`.

A band starts whatever `userCamera` says: G-3 locks the camera, not the
selection. The slop stays `kTouchSlop` for every pointer (14c R-7), not
the design mode's 4 px. The long-press timer never runs on the floor
(F-1), so nothing races the band. Starting a band clears `_lastTap`: a
band is no tap (E-2).

**The modifier is read once, at the down** (`_toggle`, F-1), for both
the start and the combining (RB-4). (The brainstorm's section 2 said
"at the release"; reading at the down matches the tap's rule and makes
a band's meaning fixed from its first frame. Ruling R-1 below.)

### RB-3. What a band takes

The tool keeps the press's screen point and the pointer's latest. The
mode is `bandModeFor(start, end)`: window when `end.dx >= start.dx`,
else crossing, re-evaluated at every move.

At the up, both screen corners are converted to the world **under the
camera at the up** (F-4's rule; a wheel zoom during a band is honoured).
Then:

1. `ctx.index.forEachInstanceInBand(world, mode,
   const QueryFilter.picking(), …)` gives the passing root instances.
2. **Kept**: those that are among `picker.candidates` (F-3: a table, on
   a visible layer, finite, non-empty). Not a table — a plant, a bar, a
   wall's instance — is never kept. Call this set *P* (it may hold
   locked tables).
3. **Groups** (G4; the tool's `_groupLookup()`):
   - **Crossing**: a group is taken when some **unlocked** member is in
     *P*.
   - **Window**: a group is taken when **every visible member** is in
     *P* (locked members included: a group half outside the window is
     not taken).
   - A taken group contributes its selectable members (`_memberKeys`);
     a member of a group not taken contributes nothing.
4. **Lone tables**: each unlocked table in *P* with no group
   contributes itself.
5. The union of 3 and 4 is the band's keys *K*, ascending by handle.

A locked table is never selected (S9). An unnumbered table may be in *K*
and selected; it is absent from `selectedTables` as always (S4). A
zone's veil changes nothing (Z15).

### RB-4. What a band does to the selection

- **Plain** (no modifier at the down; only under `band`):
  `selection.replace(K)`. An empty *K* clears the selection: a band
  selects what it holds.
- **With a modifier**: `selection.replace(selection.keys ∪ K)` — one
  call, a union; a selected table inside stays selected, never toggled.
  An empty *K* changes nothing.

One `replace` per band, so `selectedTables` notifies at most once. No
view event fires for a band: not `onFloorTap`, `onTableTap`,
`onGroupTap` nor a double tap. No new callback: a host listens to
`selectedTables` (YAGNI).

### RB-5. Cancelling

A band ends with nothing changed when:

- the tool's `cancel` runs — a second finger (T6), a pointer cancel, a
  mode switch, a new tool;
- **Escape** is pressed while it is live and `idleKeys()` is true (under
  `shortcuts: false` Escape is the host's, C-7; the band then ends at
  its up or a cancel);
- the pointer's primary button is released elsewhere: the up is the
  band's end wherever it lands on the canvas.

### RB-6. Painting

`jet_cad_2d_flutter` gains, exported:

```dart
/// The band's mode by its drag direction (interaction-core D1): left to
/// right is a window, right to left a crossing.
BandMode bandModeFor(Offset start, Offset end);

/// Paints a selection band over [rect], in screen pixels: the band
/// colour at kBandFillAlpha, a 1 px outline, solid for a window, dashed
/// 6 on and 4 off for a crossing.
final class SelectionBandPainter {
  void paint(Canvas canvas, Rect rect, BandMode mode, PaperPalette paper);
}
```

The painter keeps its two `Paint`s and its `Path` and resets them per
call, so a live band allocates nothing per frame. `SelectTool` uses both
(a pure refactor: the design band's pixels and recorded draw calls are
unchanged). `TableSelectTool.paintOverlay` paints the band only while
one is live, from the press's screen point to the pointer's latest; O(1)
per frame, nothing per table.

### RB-7. The demo, the guide, the CHANGELOG, the specs

- **Restaurant demo**: a "Floor drag" switch, *Pan / Select* (de
  *Ziehen auf dem Boden: Verschieben / Auswählen*, tr *Zeminde sürükle:
  Kaydır / Seç*), passed as `floorDrag`.
- **Host guide**: a "Selecting with a band" section — the option, the
  two triggers, the direction rule, groups and locks, the camera under
  `band`; its code blocks in the host probe (`check_guide`).
- **CHANGELOG** (Unreleased): the option, the modifier band under `pan`,
  `bandModeFor` and `SelectionBandPainter` in `jet_cad_2d_flutter`.
- **Specs**: host embedding O-4 "Taken up" with a link; selection-mode
  S3, restaurant-embedding D11 and D17, touch T6 each get a dated note:
  "except under `floorDrag: band` (rubber-band spec RB-2)";
  `FloorPlanLongPress.contextMenu`'s doc names `floorDrag: band` as a
  touch screen's multiple selection.

### Rulings

- **R-1.** The modifier is read at the down, not at the release (RB-2):
  one reading for the start and the combining, as a tap reads it. Costs,
  if wrong: one field read at the up instead.
- **R-2.** A plain band over nothing clears (RB-4), as a plain tap on
  the floor clears. Costs, if wrong: an `if (K.isEmpty) return`.
- **R-3.** Under `serviceMoves: false` a drag from a table still pans
  (S5), even under `band`: a band starts from the floor only. Costs, if
  wrong: one branch in RB-2.

## Testing

Every test is worth landing only if a named mutation turns it red.
Fixtures are never degenerate: the camera is rotated, scaled and off the
origin; tables are rotated; one table is L-shaped (its bounding box
inside a band whose leaves miss it); the plan holds a group of three, a
table on a locked layer, an unnumbered table, a table on a hidden layer
and a non-table symbol.

| # | Test | Mutation killed |
|---|---|---|
| RB1 | `pan`: a plain floor drag pans, the selection unchanged | M-RB1: the band starts without the modifier check |
| RB2 | `pan`: a Shift mouse drag bands and adds; a Shift *touch* drag pans | M-RB2: the `!isTouch` check dropped |
| RB3 | `band`: one finger and the mouse band; two fingers pan (the camera moved, the tool cancelled) | M-RB3: `floorDrag` ignored |
| RB4 | `band` with `userCamera: false`: the band works | M-RB4: the band gated on `_pans` |
| RB5 | a drag from an unlocked table moves it, from a locked table is spent, under `band` | M-RB5: a band started on a table |
| RB6 | window takes only wholly enclosed tables; the L-shaped table is not taken | M-RB6: the instance's bounding box used |
| RB7 | crossing takes a touched table; direction flipped mid-drag changes the mode | M-RB7: the mode fixed at the start |
| RB8 | the corners converted under the camera at the up (a zoom during the band) | M-RB8: the press's world point used |
| RB9 | locked, hidden and non-table instances are never selected; the unnumbered one is selected and absent from `selectedTables` | M-RB9: the candidate filter dropped; M-RB10: the lock filter dropped |
| RB10 | crossing one member takes the group whole; a window with one member outside takes none of it | M-RB11: no group expansion; M-RB12: the window's every-member rule dropped |
| RB11 | plain replaces; modifier adds and keeps a selected table inside | M-RB13: `toggle` instead of union |
| RB12 | a plain empty band clears; a modifier empty band changes nothing | M-RB14: the empty rule inverted |
| RB13 | `selectedTables` notifies exactly once per band; no `onFloorTap`, `onTableTap`, `onGroupTap` | M-RB15: a per-key `replace`; M-RB16: the up falls into `_tap` |
| RB14 | Escape, a second finger and a mode switch cancel; the selection unchanged | M-RB17: Escape ignored mid-band |
| RB15 | the band painted at the screen rect, solid for a window, dashed for a crossing (recording canvas) | M-RB18: the mode's stroke swapped |
| RB16 | a live band allocates nothing per frame (the paint allocation rig) | M-RB19: a `Paint` built per call |
| RB17 | the design mode's band draws the same calls before and after the refactor | (the refactor's pin) |
| RB18 | the host probe builds with `floorDrag: band`; the 0.3.0, 0.4.0, 0.5.1 and 0.6.0 probes stay green | (P-1) |

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
