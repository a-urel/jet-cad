# Framing and focus by table number (zones) — design

**Date:** 2026-10-08. **Status:** design, **revision 2**. Revision 1
(`0cfc87e`) was reviewed independently: *Approve with fixes*, V-1 to
V-19, no redesign. This text folds in the fixes and the controller's
rulings on them (Q-Z2, Q-Z6, V-2, V-3, V-9); see [Review](#review).

**Asked for by** Monépro's spec 103 §10 (*"table placement, zones and
open/save in the editor"*); `STATUS.md` leaves **zones** last. **The
human's ruling, 2026-10-08** (asked and answered; paraphrased): a zone
is the table's attribute in the **host's database**; jet-cad stores no
zone (no schema change, no zone entity) and lets a host (a) **frame** a
set of tables by number in one plan and (b) optionally **fade** the
tables outside a focus set. Decision 12 (one plan per area) stays.

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `14616d9`
(release 0.2.0). **Size:** S–M. **Touched:** `jet_cad_floor_plan`,
`apps/restaurant_demo`, `tool/ci/host_probe`, the host guide, the
CHANGELOG; the engine and the renderer are **untouched**.

## Facts (at `14616d9`; the cited code is unchanged at `0cfc87e`)

- **F-1. Monépro** (spec 103, `develop @ 88c96e0`). **D21** (`:239-242`):
  identity lives in the database; the drawing is presentation, *"linked
  by an app component carrying the table's id"*; jet-cad's link is the
  **number** of the `TABLE` label (14a; `table_index.dart:58-66`), Q-Z4.
  **App. A** (`:835`): `pos_tables (id, location_id, code, capacity,
  zone, is_active)`. **B.2** (`:886-890`): zone tabs, "My tables"; phase
  2 puts the view beside "unplaced tables". **B.1** (`:879-882`): status
  *"as Flutter widgets positioned with `camera.worldToScreen`"*. **§2**
  (`:148-155`): a *"runtime style-override channel"* is missing.
- **F-2. `fitToView`** (`floor_plan_controller.dart:866-869`) sets
  `_fitPending` and bumps `_fits`. A mounted `PlannerView` posts
  `_fit(size)` with the size **captured at the request**
  (`planner_view.dart:157-166`); with none mounted, the next view fits on
  its first frame, as `takeFitOnStart()` answers
  `_fitOnStart || _fitPending` (`:343-347`). `fitted()` clears the flag
  and accepts any view's call (`:351`; "review F-2", `:208-210`).
- **F-3. A fit** (`planner_view.dart:170-177`) is `fitToPage`
  (`page_fit.dart:8-9`), else `ViewportTransform.fit(extents)`: scale
  `0.95 · min(W/w, H/h)`, y flipped, 1.0 for a box flat in either axis
  (`viewport_transform.dart:27-48`). `_fit` returns on `!mounted`
  (`:171`), so an old view's posted fit calls no `fitted()`.
- **F-4. Zoom bounds** `kMinScale = 0.001`, `kMaxScale = 100` px/mm
  (`startup_plan.dart:50-51`; camera at
  `floor_plan_controller.dart:189-192`). Only `zoomAt` clamps
  (`camera_controller.dart:81-101`); a fit (`planner_view.dart:173`) and
  `_placeNominally` (`floor_plan_controller.dart:156-165`) assign
  `camera.value` unclamped. At 100 px/mm a 700 mm top spans 70,000 px.
- **F-5. When a fit happens.** `load`/`newPlan` set `_fitOnStart`
  (`floor_plan_controller.dart:618`). `setMode` never fits: it reframes
  by the canvases' origin difference (R-13 amended, `:362-372, 643`),
  which `canvasMeasured` corrects after the first frame (`:380-385`). Its
  callback is registered in `FloorPlanView.build`
  (`floor_plan_view.dart:100-109, 203`), before `PlannerView`'s layout
  registers its fit (`planner_view.dart:200-213`); post-frame callbacks
  run in order, so a first-frame fit lands after the correction.
- **F-6. Candidates and boxes.** The picker's candidates are the survey's
  tables on a visible layer, with a finite non-zero determinant and a
  non-empty `definitionBounds`, cached per definition
  (`table_picker.dart:170-181`); nothing skips a non-finite translation.
  The pick tests the box through the inverse transform (`:209-213`; 14c
  B-2: "its world bounds are never used"); the group frame hulls its
  **four transformed corners** (`table_group_painter.dart:290-306`);
  `Aabb2.transformedBy` is their axis-aligned bound
  (`aabb2.dart:100-108`). The label sits inside the box (14a F-6).
- **F-7. A table** is a live, **root-level** servable instance
  (`table_index.dart:77`), numbered by its `TABLE` ATTRIB (`:63`),
  whatever its layer (`:72-98`); a TEXT or a room named "7" is none.
  `withNumber` trims and compares with `==` (`:103-109`). A number has at
  most 8 UTF-16 units and no control character (14a T4).
- **F-8. Precedent:** statuses and groups
  (`floor_plan_controller.dart:244-281`) are kept across `setMode`,
  `resetLayout`, `load`; always replaced and notified; not document
  state; drawn in the selection mode only.
- **F-9. Selection-mode layers**, bottom up (`service_view.dart:408-434`,
  `planner_view.dart:240-284`): page chrome; **underlay** (group frames,
  status fills and captions); drafting; **overlay** (group chips);
  selection outlines. Off the sheet the canvas is `scheme.surface`
  (`service_view.dart:379-380`).
- **F-10. The style resolver** (`style_resolver.dart:45-54`) is a wrapping
  seam (`dark_canvas.dart:106`). `contextFor` runs once per instance
  (`draft_painter.dart:437`); `StyleContext.transparency` reaches BYBLOCK
  leaves (`style_context.dart:30-31`, `style_resolver.dart:196-199`). A
  new resolver rebuilds `DraftCanvas`'s painter (`planner_view.dart:46-49`).
  Status fills, captions and chips are separate painters (14c D13; G3).
- **F-11. Regions.** Group frames are world-space paths under the raw
  camera matrix in one reused `Float64List(16)`
  (`table_group_painter.dart:392-410`). `Path.combine` is unused here; it
  is Skia PathOps on CanvasKit and skwasm, Flutter 3.47's only web
  renderers, and throws a `StateError` on a NaN path (review E1, E2).
- **F-12. Service view state.** `_paper` holds the paper's ARGB
  (`service_view.dart:171`); each change of the copy bumps `_changed`
  (`:178, 294`). The group painter rebuilds on state, tables revision,
  groups, paper (`table_group_painter.dart:378-387`) and repaints on
  camera, groups, `_changed`, `_paper` (`service_view.dart:200-201`).
- **F-13. Acting on a table.** A tap **selects first**, then calls
  `onTableTap` (`table_select_tool.dart:275-290`); a context click selects
  (`contextSelect`, `:56-62`), a long press toggles (`:369-392`), a drag
  selects and moves (`:203-231`). A **locked** table is picked and
  reported, never selected or moved (`:180-185, 276`, `:58`). `select`
  keeps visible, unlocked tables (`floor_plan_controller.dart:772-787`).
- **F-14. Host API.** `FloorPlanTable(number, seats, symbolKey)` has no
  visibility (`floor_plan_types.dart:20-44`) and the barrel no layers, so
  14c A-2's "a host reads its layers itself" has no API. The guide check
  finds each fenced `dart` block in the probe (`tool/ci/lib/guide.dart:33-46`).
- **F-15. The demo.** Salon (`apps/restaurant_demo/assets/plans/salon.json`):
  tables 1–3 along the top, round 4–5 bottom left, booths 6–7 right, bar
  stools 8–11 bottom; Teras: 1–6. `CHANGELOG.md:9-11`: "Nothing yet".

## Decisions

### Candidates and framing

- **Z0. One candidate rule for both modes** (V-11). The picker's rule is
  extracted to a static `TablePicker.candidatesOf(document, {boxes,
  leaves})`: a survey table on a visible layer, finite non-zero
  determinant, non-empty box, **and four finite transformed corners**
  (V-6). The picker, `framingFor` and the veil use it. The design mode
  has no picker: `framingFor` calls it with a fresh box cache, one
  `leavesByOwner` scan per call, at call rate.
- **Z1. `bool fitToTables(Set<String> numbers)`** (a `Set`, as `select`
  takes) frames Z0's candidates of the active plan carrying one of
  [numbers] (trimmed, blanks dropped; a duplicated number frames both,
  umbrella D5; unknown numbers ignored) and returns whether **at least
  one** exists **now**. **Both modes:** it moves only the camera, as
  `fitToView` does, and a manager editing a zone needs it as much as the
  floor. Hidden-layer tables are excluded (not drawn), locked ones
  included; unnumbered tables and grouped servable instances (F-7) never
  match.
- **Z2. What is framed** (V-2): the union of each table's axis-aligned
  bound of its **four transformed corners**, the corners the veil and the
  group frame use; a camera needs a rectangle, and this one is
  conservative. The label lies inside; Z3's margin covers any overhang.
- **Z3. Margin and cap.** A pure `frameTables(Aabb2 box, Size viewport)`
  in `src/host/table_fit.dart` (1) grows the box by
  **`kTableFitMarginMm = 500`** per side, an aisle of floor and the group
  frame (150 mm) at any zoom, the screen-sized chip above about
  0.1 px/mm (below, the 5 % fit margin holds it, V-14); (2) grows it about
  its centre to at least **`kTableFitMinSpanMm = 3000`** per axis; (3)
  applies `ViewportTransform.fit`; (4) **clamps** the scale to
  `[kMinScale, kMaxScale]` about the centre (F-4), dead in practice (a
  316,000 px view or a 950 m box) and harmless. The minimum span is the
  cap (3 m of floor round one table, never a poster; the same on a phone
  and a terminal, unlike px/mm; F-3's flat box unreachable). Q-Z3.
- **Z4. None found:** `false`, and **nothing** changes — no request, no
  target, no pending flag, the camera stays, an earlier pending request
  stays. An empty zone is normal (tables not drawn yet, Z18); a silent
  page fit would pass for the zone's framing; a throw would make the
  normal case an error. The host decides: keep the view, `fitToView()`,
  or say so.
- **Z5. `fitToView`'s machinery.** The controller keeps a **fit target**,
  null for the page or the trimmed number set. A finding `fitToTables`
  sets it, sets `_fitPending`, bumps `_fits`; `fitToView()` sets it to
  null and does the same. **The last request wins.** With no view
  mounted, the next view frames on its first frame (F-2); `fitted()`
  clears the flag.
- **Z6. Resolved when performed**, against the active plan then: a
  restore, an Undo or a mode switch in between is followed. If nothing
  matches then, the view fits the page and calls `fitted()`. Z1's result
  reports the call's moment.
- **Z7. The seam.** `@internal ViewportTransform? framingFor(Size)` on
  the controller: null for the page target or no match, Z3's camera
  otherwise. `PlannerView` gains an optional `framing`; `_fit` uses
  `widget.framing?.call(size) ?? (today's fit)`. **A request reads
  `_size` when its post-frame callback runs**, after this frame's layout
  (V-7): a zone tab that also toggles a side panel frames at the new
  size. `PlannerShell` forwards `framing` beside `fitRequests` (14b-2
  H8); `ServiceView` passes it; a bare shell and `apps/floor_planner`'s
  pass none. **One `FloorPlanView` per controller is assumed** (V-12), as
  the shared camera already assumes.
- **Z8. The other calls.** **`load`/`newPlan`** reset the target to the
  page beside `_fitOnStart`: the numbers named the old plan; a host frames
  after `load`. **`setMode`** neither fits nor clears: a performed
  framing stays in place (R-13's reframing); a pending one is performed
  by the new mode's first view after `canvasMeasured`'s correction (F-5),
  the old view's posted fit returning on `!mounted` without `fitted()`
  (F-3). **`resetLayout`/`restoreServiceLayout`** leave the target alone.
- **Z9. Not document state:** no command, undo step, `dirty`, `revision`,
  `serviceLayoutChanges` or `notifyListeners`. No settle (H11): a camera
  call must not commit a half-typed value; `fitToView` has none either.

### The focus

- **Z10. `void setTableFocus(Set<String>? numbers)` and
  `ValueListenable<Set<String>?> tableFocus`.** Null: no focus. **An
  empty set is a focus with no table** (all fade), and so is `{''}`, since
  blanks are dropped (V-16). Numbers are trimmed and copied into an
  unmodifiable set, never aliasing the host's. Each call replaces and
  notifies, an equal set included (F-8). Kept by number for the
  controller's life, across `setMode`, `load`, `newPlan`, `resetLayout`
  and `restoreServiceLayout`; never saved, exported, printed, put in the
  service layout or undone; `revision` and `dirty` untouched.
- **Z11. Drawn in the selection mode only**, as statuses (in the editor a
  faded table would read as the plan's). **Z12. What fades:** every Z0
  candidate whose number is not in the focus. **Unnumbered tables fade**
  (no focus names them); locked ones fade too; hidden tables and unknown
  numbers draw nothing.
- **Z13. A veil, not a style override.** A new `TableFocusPainter`
  (`src/service/table_focus_painter.dart`) paints the **paper's RGB**
  (`_paper`, its alpha ignored, as `over` does) at
  **`kTableFocusVeilAlpha = 0.6`**, in the overlay slot: above the
  drafting, **under** the chips and the selection outlines (F-9);
  `ServiceView`'s overlay becomes a `Stack` of the veil, then the chips.
  - **Each table contributes its quad** (V-2): the four transformed
    corners of its definition box in world coordinates, reversed when the
    determinant is negative so every quad winds counter-clockwise (E1: a
    mirrored quad otherwise cancels an overlap). **The region is the
    union of faded quads minus the union of focused quads** — two
    non-zero paths, one `Path.combine(PathOperation.difference, …)` per
    rebuild — so a focused table is never veiled where a neighbour
    overlaps it.
  - **Rejected: a wrapping `StyleResolver`** (V-5, F-10): it never
    reaches status fills, captions or chips; a resolver per focus change
    rebuilds `DraftCanvas`'s painter and adds a per-instance lookup to the
    gated frame path; alpha fades toward what lies beneath, not the
    paper; leaves with their own transparency ignore the context.
- **Z14. Composition.** A faded table's lines, number, status fill and
  caption lie under the veil and fade toward the paper (equal to the
  paint at 0.4 over the paper); the status painter is unchanged. **A group
  with a focused visible member** draws as today, its outside members
  veiled; its status caption stays under its lead (G3), veiled when the
  lead is outside while focused members show the status — accepted, the
  lead rule unchanged (V-18). **A group with no focused member** draws its
  frame with one prebuilt faded `Paint` (alpha × 0.4), and its chip as
  today, then the chip's `RRect` again with the veil's paint (V-18).
  **The group painter follows the focus** (V-4): both layers take
  `tableFocus`, its identity joins the rebuild key
  (`table_group_painter.dart:378-387`), and it joins `_groupRepaint`
  (`service_view.dart:200-201`). Selection outlines stay above the veil.
- **Z15. Interaction is unchanged; the focus is presentation** (ruling on
  Q-Z2, V-1). A faded table can be tapped, context-clicked,
  long-pressed, selected by `select`, dragged, merged and split;
  `selectedTables` keeps it. Why: a waiter under "My tables" still acts
  on a colleague's table (transfer, merge, a covering shift), and an
  inert box would be a dead zone where a tap clears the selection or
  pans. **A host that wants a faded table inert handles it
  in its own callbacks** — `onTableTap`, `onTableContextMenu` and its
  `selectedTables` listener, checked against `controller.tableFocus.value`
  — and passes `serviceMoves: false` for no moves. **The table is already
  selected when `onTableTap` fires** (F-13); jet-cad gates none of
  selection, drags or Merge.
- **Z16. The frame path's bar** (`CLAUDE.md`). The veil **rebuilds its
  path** when Z0's candidates (state id, layer revision) or the focus's
  identity move; a paper change only recolours the `Paint` (V-19). Per
  frame: the camera into **one reused** `Float64List(16)`, one
  `save/transform/drawPath/restore` with the **same** `Path` and `Paint`
  — nothing per entity, O(1) per frame. A null focus draws and builds
  nothing. Repaint merges the camera, `tableFocus`, `_changed`, `_paper`;
  `debugAllocations` counts every `Path`, `Paint` and buffer. The gate is
  14c R-3's structural recording canvas
  (`table_status_painter_test.dart:145`); `paint_allocation_test`
  measures `DraftPainter` and is untouched. **Z17.** Precision as the
  group frames' (F-11): sub-pixel error at 1e6 mm accepted.

### What stays the host's, and what jet-cad adds for it

- **Z18. Unplaced tables** are the database's tables minus those a plan
  draws; the guide shows the set difference, over every plan of the
  location (decision 12). **A table on a hidden layer is not drawn, so the
  recipe counts it as unplaced** (Z24). Numbers compare trimmed and
  case-sensitively (14a T4, umbrella D2a): the host normalises its codes,
  and a code over 8 UTF-16 units or with a control character can never be
  a number.
- **Z19. Zone tabs and "My tables"** are the host's queries. **Zone tab:**
  `fitToTables(codes)`, optionally `setTableFocus(codes)`; on false, a
  fallback such as `fitToView()`. **"All":** `fitToView()`,
  `setTableFocus(null)`. **"My tables":** `setTableFocus(the waiter's
  codes)`, reset as they change; with a zone, the intersection. A framing
  frames only the numbers given: a group straddling zones is cut unless
  the host adds its members (V-17). A zone over several plans is framed
  in each.
- **Z24. `FloorPlanTable.visible`** (ruling on V-9): a named
  `bool visible = true`, so a host constructing one does not break; in
  `==`, `hashCode`, `toString`; false for a table on a hidden layer.
  `controller.tables` keeps listing hidden tables, so `numberingWarnings`
  stay as they are.

### Docs, demo, CHANGELOG, l10n

- **Z20. The host guide:** **"### Zones: framing and focus"** ends § 7
  (no anchor moves): Z1, Z4, Z5, Z8's `load` rule, Z10–Z12, Z15 (the
  inert recipe in prose, V-17), Z18, Z19, Z24, *Unreleased*; § 4's
  sentence on what fits again gains `fitToTables`.
- **Z21. The host probe** holds every fenced guide block (F-14): these
  three methods of `_FloorScreenState`, called from app-bar actions, and
  no other:

```dart
  void showZone(Set<String> numbers, {required bool fadeOthers}) {
    if (!controller.fitToTables(numbers)) controller.fitToView();
    controller.setTableFocus(fadeOthers ? numbers : null);
  }

  void showAllZones() {
    controller.fitToView();
    controller.setTableFocus(null);
  }

  /// The tables the POS knows that this floor does not draw: a table on
  /// a hidden layer is not drawn, so it counts as unplaced.
  Set<String> unplacedTables(Set<String> codes) => codes.difference({
        for (final table in controller.tables)
          if (table.visible && table.number != null) table.number!,
      });
```

- **Z22. The demo, at its smallest.** The Salon gains demo zones, host
  data, untranslated: **A** = 1–5, **B** = 6–7, **C** = 8–11 (F-15). An
  area with zones (not the Teras) gets a zone `SegmentedButton` (*All*,
  A, B, C) and a **"Fade the others"** switch; a zone calls `showZone`,
  *All* `showAllZones`, both kept per `Area`. Three demo strings:
  `zones` (*Zones / Bereiche / Bölgeler*), `allZones` (*All / Alle /
  Tümü*), `fadeOthers` (*Fade the others / Andere abblenden /
  Diğerlerini soldur*), joining the native reads owed to the human.
- **Z23. The CHANGELOG** (Unreleased): **Added** `fitToTables` (margin,
  3 m minimum span, its result, pending with no view); **Added**
  `setTableFocus`/`tableFocus` (the selection mode fades tables outside
  the focus; not saved; kept across loads and mode switches); **Added**
  `FloorPlanTable.visible` (false on a hidden layer, default true); no
  schema change. **l10n: no planner string; `lib/src/l10n/` untouched.**

## Invariants

- **I-1.** Engine and renderer untouched; both allocation invariant tests
  and every golden unchanged and green.
- **I-2.** Neither call executes a command: no sequence of `fitToTables`
  and `setTableFocus` moves `designJson()`, `dirty`, either plan's undo
  depth, `revision` or `serviceLayoutChanges`.
- **I-3.** Draw order unchanged: the veil is one region in one call.
- **I-4.** The design mode draws as before whatever the focus; the
  selection mode as before while the focus is null.
- **I-5.** Export and Print never show the veil (14b-2 A-3).
- **I-6.** Existing tests pass unedited; the new parameters of
  `PlannerView`, `PlannerShell` and `FloorPlanTable` are optional (the
  plan checks that no test compares a hidden table's `FloorPlanTable`).

## Testing and named mutants

**Fixtures** (the testing bar; 14c R-2): a hand-made servable definition
with an **asymmetric** top, turned 37°, one copy mirrored, **40 m off the
origin**; tables on a **hidden** and a **locked** layer (`L`); a
duplicated number, `B4`, an unnumbered table; a **non-identity camera**
(panned, 0.37 px/mm) before every call; **look-alikes**: a TEXT and a
room named `7` far from table 7, a table numbered ` 7 ` asked for as `7`.
Expectations are computed **in the test** by the forward transform;
doubles compare with `closeTo`, relative 1e-12 (V-15). Each entry is
*mutant — killing test*.

**Framing:**
- **M-Z1.** Frame by any text — the framed world excludes the TEXT and
  the room `7`.
- **M-Z2.** Hidden tables framed — `{'5'}` (hidden) returns false;
  `{'5', '3'}` frames 3 alone.
- **M-Z3.** The box at the identity or the translation — for the turned,
  mirrored, off-origin table, `framingFor` equals Z3 on the test's own
  four-corner bound.
- **M-Z4.** No minimum span, or no clamp — a 380 mm stool in 1000 × 700
  gives `0.95 · 700 / 3000`; a 1e7 px viewport gives `kMaxScale`, a
  1e9 mm box `kMinScale`.
- **M-Z5.** Margin dropped or doubled — two tables 10 m apart in x, in a
  viewport where x binds (y's span is under 3 m, so the minimum applies
  there); the scale includes 2 × 500 mm.
- **M-Z6.** Centre or y flip wrong — from the prior camera, the union's
  centre maps to the canvas centre and the upper table is drawn above.
- **M-Z7.** Requesting when none is found — false, the camera identical,
  `fitRequests` silent, `takeFitOnStart()` unchanged.
- **M-Z8.** No pending framing — call with no view, mount: framed.
  **M-Z9.** `load` keeps the target — `fitToTables`, `load`, mount: page.
- **M-Z10.** Resolved at call time — selection mode, no view,
  `fitToTables({'3'})`, a restore moving 3, mount: framed at 3's restored
  place.
- **M-Z11, M-Z27.** Framing or focus counted as state — I-2's listener
  counters and undo depths.
- **M-Z12.** First request wins — `fitToTables` then `fitToView` in one
  frame fits the page; the reverse frames the tables. **M-Z13.** One
  table per number — the duplicate frames both tables.
- **M-Z14.** Pending framing shifted by the correction (F-5's order
  reversed) — no view, `setMode(selection)`, `fitToTables`, mount with a
  measured origin unlike the seed: centred within 1e-6 px. **M-Z15.**
  Design mode not wired — framing through `PlannerShell`'s `framing`.
- **M-Z30** (V-3a). A failed call resets the target or flag — no view,
  `fitToTables({'3'})`, then `{'nope'}` → false; mount: 3 framed.
- **M-Z31** (V-3b). No page fallback (`framingFor` null and no fit, the
  old camera, or no `fitted()`) — design mode, no view,
  `fitToTables({'3'})`, undo 3's placement (separately: hide its layer);
  mount: the page fitted, `takeFitOnStart()` then false.
- **M-Z32** (V-3c). `newPlan` keeps the target — M-Z9 with `newPlan`.
  **M-Z40** (V-3k). Locked tables not framed — `{'L'}` → true, framed.
- **M-Z33** (V-3d). `!mounted` guard removed from `PlannerView._fit`, or
  the measurement registered after the fit — a mounted design view;
  `fitToTables` then `setMode(selection)` in one step; pump twice:
  centred in the selection canvas within 1e-6 px.
- **M-Z34** (V-3e). Request not trimmed — `fitToTables({' 3 ', ''})`
  frames 3; `setTableFocus({' 7 '})` focuses 7; `{''}` and `{}` veil
  all (**M-Z26**: empty read as null).
- **M-Z41** (V-7). Size captured at the request — the host narrows the
  mounted view and calls `fitToTables` in one step: centred in the new
  canvas.
- **M-Z43** (V-6, V-11). Non-finite corners kept — a NaN translation and
  a singular transform, both modes: framing, veil and pick skip them;
  nothing throws.

**Focus:**
- **M-Z16.** Drawn in the design mode — no veil layer (by key); pixels
  over a faded table unchanged.
- **M-Z17** (V-2). No subtraction, or axis-aligned subtraction — the
  **turned** focused table overlapping a faded one: a pixel in the
  overlap inside the focused quad is unveiled; a faded pixel outside the
  focused quad but inside its axis-aligned bound is veiled.
- **M-Z18** (V-2). Veil at a wrong box — pixels read back
  (`PictureRecorder` under `runAsync`, 14c R-10) on the turned, mirrored,
  off-origin table: inside the quad only, veiled; inside the
  untransformed box only, not; **a corner triangle inside the world
  axis-aligned bound but outside the quad, not**; the mirrored quad is
  veiled, not cancelled.
- **M-Z19, M-Z39** (V-3j). Unnumbered, locked or hidden wrong — the
  unnumbered and the locked table veiled, the hidden table's box not.
- **M-Z20.** Focus kept by handle, or cleared — across `setMode`,
  `resetLayout` and a `load` where `7` is another instance, the set is
  kept and the veil follows the number.
- **M-Z21.** Allocation per frame — a recording canvas, N = 60 tables,
  half focused; three warm frames, a pan, a zoom: the same `Path`,
  `Paint` and buffer every frame, `debugAllocations` steady (14c R-3).
- **M-Z22.** Interaction gated — with 4 outside the focus: a tap fires
  `onTableTap('4')` and selects it; `select({'4'})` selects it;
  `selectedTables` keeps it; a drag moves it; Merge offers it.
- **M-Z23.** Veil under the status layer — an unfocused statused pixel is
  the status over the paper, then the paper at 0.6 over it; a focused
  one's is the status alone.
- **M-Z24.** Group fading wrong — no focused member: faded frame paint,
  chip pixels veiled; a straddling group: normal frame, unveiled chip.
- **M-Z25.** Paper ignored, or its alpha used — on a dark canvas the
  veil is `kDarkCanvasPaper`'s RGB at 0.6; a paper change recolours with
  no path rebuild (`debugAllocations` unchanged).
- **M-Z35** (V-3f). The host's set aliased — mutating it after the call
  changes neither `tableFocus.value` nor the veil.
- **M-Z36** (V-3g). `tableFocus` missing from the merge — the painter's
  listener count (as view test V17): a `setTableFocus` repaints.
- **M-Z37** (V-3h). Rebuild keyed on the focus only — move a faded table:
  the veil follows; undo: it follows back; a hidden layer: no veil there.
- **M-Z38** (V-3i, V-4). Group painter deaf to the focus (rebuild key or
  `_groupRepaint`) — a focus set after the first paint switches to the
  faded frame and veils the chip.
- **M-Z42** (V-9). `visible` hard-coded true, or read from another layer
  — the hidden table's `visible` is false, others' true; showing its layer
  flips it once `revision` moves; `numberingWarnings` unchanged by hiding;
  the probe's `unplacedTables` counts the hidden table.

**Docs and demo:**
- **M-Z28.** Guide drift — `check_guide.dart` exits 1 once the probe's
  `showZone` is edited.
- **M-Z29.** Demo zone ignored — `demo_test`: zone B frames 6–7 (their
  boxes visible, table 1's not); "Fade the others" sets `tableFocus` to
  {6, 7}; *All* clears it and fits the page.

Each killer is a hypothesis until seen red (Ruling 49/50).

## Risks

- **R-1. The web.** `Path.combine` is supported on both web renderers
  (F-11); the exit gate carries a **web smoke check** (the demo on the
  web, a zone with "Fade the others", seen in a browser). Z0 keeps NaN
  out of `combine`.
- **R-2.** The veil pales wall lines crossing a faded quad: accepted, the
  quad is the table's own floor (B-2). **R-3.** Where quads overlap, the
  faded neighbour loses the overlap; the focused table stays whole.
  **R-4.** 500 mm, 3 m and 0.6 are guesses (Q-Z3).
- **R-5. Captions leave the quad** (V-8): a status caption sits in screen
  space below the label, checked against the top's width only
  (`table_status_painter.dart:327-340`); at low zoom a faded table's may
  stick out unveiled, a focused one's fall into a faded neighbour's quad.
  Part of Q-Z3; if it shows, the status painter skips faded captions.
- **R-6. Off the sheet** (V-19): the canvas there is the theme's surface
  (F-9), so a faded table there gets a paper-coloured patch.

## Open questions

- **Q-Z1 (Monépro).** B.1 wants status as widgets placed with
  `camera.worldToScreen`; jet-cad colours and captions tables itself
  (14c; 12-character captions) and the camera is `@internal`
  (`floor_plan_controller.dart:188`). D22's badges will likely need table
  screen rectangles: a public mapping belongs in Monépro's phase-2 spec.
- **Q-Z3 (the human, a look).** Margin, minimum span and veil on a tablet
  and a terminal, light and dark, with R-5's captions and Z3's chip room
  at low zoom.
- **Q-Z4 (Monépro).** D21 names *"an app component carrying the table's
  id"*; under the ruling jet-cad stores no database id, and the link is
  the number = `pos_tables.code`, under 14a T4 (trimmed, non-empty, at
  most 8 UTF-16 units, no control character, exact `==`). Monépro's spec
  should say so.

## Out of scope, recorded

Zone regions in the editor (no zone data); table positions or
`worldToScreen` for overlays (Q-Z1); a focus in the design mode (Z11); a
schema change, zone component or zone-aware numbering; removing decision
12; clamping `fitToView`'s page fit (no sheet reaches the bounds);
animating a framing (it jumps, as `fitToView`); inert faded tables (Z15).

## Files

In `packages/jet_cad_floor_plan`: **new** `lib/src/host/table_fit.dart`,
`lib/src/service/table_focus_painter.dart` and their tests; **changed**
`lib/src/host/{floor_plan_controller,floor_plan_types}.dart`,
`lib/src/host/{floor_plan_view,service_view}.dart`,
`lib/src/{planner_view,planner_shell}.dart`,
`lib/src/service/{table_picker,table_group_painter}.dart`, tests
`test/host/{controller,view,seams}_test.dart`,
`test/service/{table_picker,table_group_painter}_test.dart`. Elsewhere:
`apps/restaurant_demo/{lib/main,lib/demo_strings,test/demo_test}.dart`,
`tool/ci/host_probe/lib/main.dart`, `docs/host-guide.md`, `CHANGELOG.md`.

## Review

Revision 1 (`0cfc87e`): *Approve with fixes*; E1 and E2 are in F-11 and
Z13. Every finding was checked against the code and accepted.

| # | Finding | Disposition |
|---|---|---|
| V-1 important | Z15's one-liner does not make a faded table inert: a tap selects before `onTableTap`; context click, long press, drag and Merge stay. | Accepted. Ruling on Q-Z2: faded tables stay interactive. Z15 rewritten on F-13's facts, with the host's own gating and "selected before `onTableTap`"; Q-Z2 closed. |
| V-2 important | The veil's box is unstated; `transformedBy` is an axis-aligned bound, not the pick's or the frame's; M-Z18 cannot tell them apart. | Accepted (ruling). Veil: the four-corner quad (Z13); framing: its axis-aligned bound (Z2). Corner-triangle killer in M-Z18; M-Z17 on the turned table. |
| V-3 important | About a dozen requirements have no named mutant (a–k). | Accepted (ruling). M-Z30–M-Z40 and M-Z24's chip. |
| V-4 minor | The group painter's rebuild key and repaint do not include the focus. | Accepted. Z14 states both; M-Z38. |
| V-5 minor | The style override is rejected on wrong grounds. | Accepted. F-10 corrected; Z13 argues the real grounds; the decision stands. |
| V-6 minor | `Path.combine` works on both web renderers; native throws on NaN. | Accepted (ruling on Q-Z6). R-1 is a web smoke check in the exit gate, no first-task spike; Z0 skips non-finite corners; M-Z43. Q-Z6 closed. |
| V-7 minor | A fit uses the size captured at the request. | Accepted. Z7: `_size` read when the callback runs; M-Z41. |
| V-8 minor | Captions can leave the box. | Accepted. R-5, and part of Q-Z3. |
| V-9 minor | Hidden-layer tables are "placed" yet invisible, with no API to tell. | Accepted (ruling). Z24 `FloorPlanTable.visible`, named, default true; `tables` still lists hidden tables; the guide's recipe counts them unplaced (Z21); CHANGELOG (Z23); M-Z42. Q-Z8 not needed. |
| V-10 minor | 14a T4's number rules constrain the codes. | Accepted. Z18, Q-Z4 and the guide (Z20); citation is 14a T4. |
| V-11 minor | One candidate rule for both modes. | Accepted. Z0 `TablePicker.candidatesOf`; the design mode's scan at call rate stated. |
| V-12 nit | `fitted()` and `framingFor` assume the performing view is the active one. | Accepted as an assumption: one `FloorPlanView` per controller (Z7), as the shared camera already requires. |
| V-13 nit | F-7 `:77`, F-13 locked tables, F-4 `_placeNominally`, F-6 `:100-108`, F-1 §2 `:148-155`. | Accepted; facts corrected. |
| V-14 nit | The margin holds the chip only above about 0.1 px/mm. | Accepted. Z3's rationale reworded; part of Q-Z3. |
| V-15 nit | "Exactly" off the origin; M-Z5's binding axis. | Accepted. `closeTo` relative 1e-12; M-Z5 makes x bind. |
| V-16 nit | Parameter types differ; `{''}`; notifying on an equal set. | Accepted. `fitToTables(Set<String>)`; `{''}` is the empty focus; every call replaces and notifies (Z10). |
| V-17 nit | A fenced gating line would have to be in the probe; groups straddling zones are cut. | Accepted. The inert recipe is prose (Z20); Z21 is the only fenced code; the straddling note joins Z19. |
| V-18 nit | A simpler faded chip; a group caption under a faded lead. | Accepted. Chip redrawn under a veil `RRect`, one faded frame `Paint`; the caption case accepted explicitly (Z14). |
| V-19 nit | Off-sheet patch; the paper's alpha; a paper change needs no path rebuild. | Accepted. R-6; Z13 uses the paper's RGB; Z16 recolours only; M-Z25. |
