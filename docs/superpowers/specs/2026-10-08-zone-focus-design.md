# Framing and focus by table number (zones) — design

**Date:** 2026-10-08. **Status:** design, **revision 1**, not yet
reviewed (see [Review](#review)).

**Asked for by** Monépro's spec 103 §10, which lists *"table placement,
zones and open/save in the editor"* among jet-cad's prerequisites for its
floor view; `STATUS.md`'s resume point leaves **zones** as the last one.

**The human's ruling, 2026-10-08** (asked and answered in the session;
paraphrased, not quoted): a zone lives in the **host's database**, as an
attribute of the table. jet-cad stores no zone: no schema change and no
zone entity in the plan. jet-cad lets a host:
- (a) **frame** a set of tables by number in one plan, such as a zone
  tab's tables;
- (b) optionally **fade** the tables outside a focus set.

Umbrella decision 12 (one plan per dining area) stays valid.

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `14616d9`
(release 0.2.0). **Size:** S–M. **Touched:** `jet_cad_floor_plan` (the
controller, `PlannerView`'s fit seam, the service view, a new painter,
the group painter), `apps/restaurant_demo`, `tool/ci/host_probe`, the
host guide, the CHANGELOG. The engine and the renderer are **untouched**.

## Facts (at `14616d9`)

- **F-1. Monépro's model** (spec 103, `develop @ 88c96e0`).
  - **D21** (`:239-242`): table identity lives in the database; the
    drawing is presentation, *"linked by an app component carrying the
    table's id"*. jet-cad's link is the table's **number**, read from its
    `TABLE` label (14a; `table_index.dart:58-66`); see Q-Z4.
  - **Appendix A** (`:835`): `pos_tables (id, location_id, code,
    capacity, zone, is_active)`.
  - **B.2** (`:886-890`): zone tabs and a "My tables" filter; phase 2
    puts the jet-cad view beside "unplaced tables".
  - **B.1** (`:879-882`): status *"as Flutter widgets positioned with
    `camera.worldToScreen`, not by recolouring geometry"*.
  - **§2** (`:149-157`) lists a *"runtime style-override channel"* as
    missing.
- **F-2. `fitToView`** (`floor_plan_controller.dart:866-869`) sets
  `_fitPending` and bumps `_fits`. A mounted `PlannerView` fits
  post-frame at its last size (`planner_view.dart:157-166`); with none
  mounted, the next view fits on its first frame, since
  `takeFitOnStart()` answers `_fitOnStart || _fitPending` (`:343-347`).
  `fitted()` clears the flag (`:351`; "review F-2", `:208-210`).
- **F-3. A fit** (`planner_view.dart:170-177`) is the page through
  `fitToPage` (`page_fit.dart:8-9`), else `ViewportTransform.fit(extents)`.
  `fit` gives `0.95 · min(W/w, H/h)`, flips y, and gives scale 1.0 to a
  box flat in either axis (`viewport_transform.dart:27-48`).
- **F-4. Zoom bounds:** `kMinScale = 0.001`, `kMaxScale = 100` px/mm
  (`startup_plan.dart:50-51`), given to the camera
  (`floor_plan_controller.dart:189-192`). Only `zoomAt` clamps
  (`camera_controller.dart:81-101`); a fit **assigns** `camera.value`
  (`planner_view.dart:173`), unclamped. At 100 px/mm a 700 mm table top
  spans 70,000 px.
- **F-5. When a fit happens.** `load` and `newPlan` set `_fitOnStart`
  (`floor_plan_controller.dart:618`). `setMode` never fits: it reframes
  by the difference of the canvases' origins (R-13 as amended,
  `:362-372, 643`), which `canvasMeasured` corrects after the first frame
  (`:380-385`). That callback is registered in `FloorPlanView.build`
  (`floor_plan_view.dart:100-109, 203`), before `PlannerView`'s layout
  registers its fit (`planner_view.dart:200-213`), so a first-frame fit
  lands after the correction.
- **F-6. A table's extent** is the picker's box: `definitionBounds` in
  definition space, cached per definition and tested through the inverse
  instance transform (`table_picker.dart:177-180`; 14c B-2); hidden-layer
  candidates are skipped (`:174`). `Aabb2.transformedBy` maps the four
  corners (`aabb2.dart:100-103`). The number label sits at the top's
  centre (14a F-6), inside the box.
- **F-7. What a table is.** `TableSurvey` counts live, **root-level**
  servable instances (`table_index.dart:78`), numbered by their `TABLE`
  ATTRIB's text (`:63`). A TEXT, a room name or a dimension reading "7"
  is no table. `withNumber` trims, then compares with exact `==`
  (`:103-109`).
- **F-8. The precedent for host state** is statuses and groups
  (`floor_plan_controller.dart:244-281`): kept by number or id for the
  controller's life, across `setMode`, `resetLayout` and `load`; not
  document state; `revision` untouched; drawn in the selection mode only.
- **F-9. The selection mode's layers**, bottom to top
  (`service_view.dart:408-434`, `planner_view.dart:240-284`): the page
  chrome; the **underlay** (group frames, then status fills and
  captions); the drafting; the **overlay** (group chips); the selection
  outlines.
- **F-10. No per-instance style override exists.** `StyleResolver`
  (`style_resolver.dart:45-54`) is a wrapping seam
  (`DarkCanvasStyleResolver`, `dark_canvas.dart:106`), but a definition's
  leaves are shared by its instances, so `styleFor(slot, ctx)` cannot
  tell two tables apart; only `contextFor(instance, …)` can
  (`draft_painter.dart:437`). The number label is a root leaf drawn with
  `StyleContext.documentRoot` (`:390-393`; 14a F-5). 14c drew statuses
  with a separate painter (D13, S7).
- **F-11. Drawing a region.** Group frames are world-space paths under
  the raw camera matrix, in one reused `Float64List(16)`
  (`table_group_painter.dart:392-410`). Nothing in the repository uses
  `Path.combine`.
- **F-12. The service view's state.** `ServiceView` keeps the paper's
  ARGB in `_paper` (`service_view.dart:171`), and the dark canvas changes
  it. Each change of the copy bumps `_changed` (`:178, 294`).
- **F-13. Who acts on a table.** `select` keeps visible, unlocked tables
  (`floor_plan_controller.dart:772-787`). The tool, the context click,
  the long press and Merge act on any picked table.
- **F-14. The guide check** finds each fenced `dart` block of the guide
  in the probe's `lib/main.dart`, white space collapsed
  (`tool/ci/lib/guide.dart:33-46`).
- **F-15. The demo.** The Salon
  (`apps/restaurant_demo/assets/plans/salon.json`): rectangular tables
  1–3 along the top, round 4–5 at the bottom left, booths 6–7 on the
  right, bar stools 8–11 at the bottom. The Teras: tables 1–6.
  `CHANGELOG.md:9-11`'s Unreleased reads "Nothing yet".

## Decisions

### The framing call

- **Z1. `bool fitToTables(Iterable<String> numbers)`** frames the
  **live, visible tables of the active plan** carrying one of [numbers]
  (trimmed, blanks dropped; a duplicated number frames both tables,
  umbrella D5; unknown numbers are ignored), and returns whether **at
  least one** such table exists **now**. **Both modes:** it moves only
  the camera, as `fitToView` does, and a manager editing a zone needs it
  as much as the floor does.
- **Z2. What is framed: the picker's box.** Each table contributes its
  `definitionBounds`, mapped by `transformedBy(node.transform)` (F-6);
  the framed box is their union: the one notion of a table's extent,
  shared with the pick (14c B-2) and the group frame (G3). The label is
  inside the box; Z3's margin covers any overhang. Hidden-layer tables
  are excluded (not drawn), locked ones included; unnumbered tables and
  servable instances inside a group (not tables, F-7) never match.
- **Z3. Margin and cap.** In `src/host/table_fit.dart`, a pure function
  `frameTables(Aabb2 box, Size viewport)`:
  1. grows the box by **`kTableFitMarginMm = 500`** on every side: an
     aisle, enough for the group frame (150 mm) and its chip;
  2. grows it about its centre to at least
     **`kTableFitMinSpanMm = 3000`** on each axis;
  3. applies `ViewportTransform.fit`, with its 5 %;
  4. **clamps** the scale to `[kMinScale, kMaxScale]` about the box's
     centre (F-4).

  The minimum span is the cap: one table is shown in place, with at least
  3 m of floor, never as a poster. A span reads the same on a phone and
  on a terminal, where a cap in px/mm would not, and it makes F-3's flat
  box unreachable. Values: Q-Z3.
- **Z4. None found.** `fitToTables` returns **false** and changes
  **nothing**: no request, no pending fit, the camera stays, and an
  earlier pending request stays as it was. Why: an empty zone is normal
  (the database holds tables not yet drawn, Z18); a silent page fit would
  pass for a framing of the zone; a throw would make the normal case an
  error. The host decides: keep the view, call `fitToView()`, or say so.
- **Z5. `fitToView`'s machinery.** The controller keeps a **fit target**:
  null for the page, or the trimmed number set. A `fitToTables` that
  finds a table sets it, sets `_fitPending` and bumps `_fits`;
  `fitToView()` sets it to null and does the same. **The last request
  wins.** With no view mounted, the next view performs the framing on its
  first frame (F-2); `fitted()` clears the flag.
- **Z6. Resolved when performed.** The numbers resolve against the
  active plan at that moment. So a `restoreServiceLayout`, an Undo or a
  mode switch between the call and the frame is followed. If nothing
  matches then, the view fits the page: a view that must fit has to fit
  something. Z1's result reports the call's moment.
- **Z7. The seam.** The controller gains `@internal ViewportTransform?
  framingFor(Size viewport)`: null for the page target or when nothing
  matches, Z3's camera otherwise. `PlannerView` gains an optional
  `framing` of that type; on the first frame and on each request, `_fit`
  uses `widget.framing?.call(size) ?? (today's fit)`. `PlannerShell`
  forwards it beside `fitRequests` (14b-2 H8), and `ServiceView` passes
  it. A bare shell and `apps/floor_planner`'s pass none, unchanged.
- **Z8. The other calls.**
  - **`load` and `newPlan`** reset the target to the page, beside
    `_fitOnStart`. An earlier framing is dropped because its numbers
    named the old plan. To load and frame, a host calls `fitToTables`
    after `load`.
  - **`setMode`** neither fits nor clears the target.
    - A performed framing stays in place on the screen (R-13's
      reframing).
    - A pending framing is performed by the new mode's first view, after
      `canvasMeasured`'s correction (F-5), so it lands exactly.
  - **`resetLayout` and `restoreServiceLayout`** leave the target alone.
- **Z9. Not document state:** no command, no undo step, no move of
  `dirty`, `revision` or `serviceLayoutChanges`, no `notifyListeners`.
  No settle (H11): a camera call must not commit a half-typed value as an
  undo step; `fitToView` has none either.

### The focus

- **Z10. `void setTableFocus(Set<String>? numbers)` and
  `ValueListenable<Set<String>?> tableFocus`.** Null means no focus;
  **an empty set is a focus with no table** (every table fades); numbers
  trimmed, blanks dropped, stored unmodifiable. Kept by number for the
  controller's life, across `setMode`, `load`, `newPlan`, `resetLayout`
  and `restoreServiceLayout`, resolved against the active plan as it
  changes (F-8). Never saved, exported, printed, put in the service
  layout or undone; `revision` and `dirty` untouched.
- **Z11. Drawn in the selection mode only**, as statuses are: in the
  editor, a faded table would read as a property of the plan.
- **Z12. What fades:** every visible table (a picker candidate, F-6)
  whose number is not in the focus. **Unnumbered tables fade**, since no
  focus names them; locked tables fade like the others; hidden tables and
  unknown numbers draw nothing.
- **Z13. A veil, not a style override** (F-10).
  - A new `TableFocusPainter` (`src/service/table_focus_painter.dart`)
    paints the **paper colour** (`_paper`, F-12) at
    **`kTableFocusVeilAlpha = 0.6`**.
  - It sits in the overlay slot, above the drafting and **under** the
    group chips and the selection outlines (F-9). `ServiceView`'s overlay
    becomes a `Stack` of the veil, then the chips.
  - **Its region is the union of the faded tables' boxes minus the union
    of the focused tables' boxes**, so a focused table is never veiled
    where a neighbour's box overlaps it.
    - Every box is emitted counter-clockwise whatever the mirror (by the
      sign of the determinant), in world coordinates.
    - Both unions are non-zero fills.
    - One `Path.combine(PathOperation.difference, …)` per rebuild.
  - **Rejected:** a wrapping `StyleResolver`. It misses the number label
    (a root leaf), cannot tell instances apart in `styleFor`, and would
    touch the render path and its allocation gate.
- **Z14. Composition.**
  - **A faded table's lines, number, status fill and caption** lie under
    the veil and fade toward the paper. The status painter is unchanged:
    a status still reads as its hue, paler.
  - **A group with a focused visible member** is drawn as today. Only its
    members outside the focus are veiled, and its frame ring stands
    outside their boxes.
  - **A group with no focused member** has its frame and chip drawn at
    `alpha × (1 − kTableFocusVeilAlpha)`: `TableGroupPainter`'s two layers
    take `tableFocus`, set a flag per group at rebuild, and keep two
    prebuilt frame `Paint`s and chips keyed by (label, ink, faded).
  - A group status's caption stays under its lead (G3), veiled when the
    lead is outside the focus. The selection outlines are above the veil:
    a selected faded table shows plainly.
- **Z15. Interaction is unchanged; the focus is presentation.** A faded
  table can be tapped, context-clicked or long-pressed (reported by
  number), selected by `select`, dragged as a service move, merged and
  split; `selectedTables` keeps it when a focus is set. Why: an "inert"
  rule would reach five places (the picker, the tool, `select`, groups
  straddling the focus, Merge). The host gets the same effect with one
  line in `onTableTap`:
  `if (focus != null && !focus.contains(n)) return;`. See Q-Z2.
- **Z16. The frame path's bar** (`CLAUDE.md`). The veil painter
  **rebuilds** when the picker's candidates (state id, layer revision),
  the focus's identity or the paper move. Per frame it writes the camera
  into **one reused** `Float64List(16)` and makes one
  `save/transform/drawPath/restore` with the **same** `Path` and `Paint`:
  nothing per entity, O(1) per frame. With a null focus it draws and
  builds nothing. It repaints on a merge of the camera, `tableFocus`,
  `_changed` and `_paper`, and counts every `Path`, `Paint` and buffer it
  makes in `debugAllocations`. The group painter's faded paints are built
  at rebuild rate.
- **Z17. Precision.** The veil is a coarse world-space region under the
  raw camera matrix, as the group frames are (F-11). An error below a
  pixel at 1e6 mm is accepted, as 14c accepts it for its fills.

### What stays the host's

- **Z18. Unplaced tables** are the database's tables minus every
  controller's `tables` numbers; jet-cad adds no API, and the guide shows
  the set difference. With several plans per location (decision 12),
  take the union. `tables` includes hidden-layer tables (14c R-11, A-2),
  which count as placed. Numbers compare trimmed and case-sensitively
  (14a D2a); the host normalises its codes to match.
- **Z19. Zone tabs and "My tables"** are the host's queries. **A zone
  tab:** `fitToTables(codes)`, optionally `setTableFocus(codes)`; on
  false the host falls back, e.g. to `fitToView()`. **"All":**
  `fitToView()` and `setTableFocus(null)`. **"My tables":**
  `setTableFocus(the waiter's codes)`, set again when they change; with a
  zone tab, the intersection. A zone spread over several plans is framed
  in each plan that holds part of it.

### Docs, demo, CHANGELOG, l10n

- **Z20. The host guide** gains **"### Zones: framing and focus"** at the
  end of § 7, after "Table groups", so no number or anchor moves: Z1, Z4,
  Z5's last-request rule, Z8's `load` rule, Z10–Z12, Z15 and Z18–Z19,
  marked *Unreleased*. § 4's sentence on what fits again gains
  `fitToTables`.
- **Z21. The host probe.** Each new guide block is in
  `tool/ci/host_probe/lib/main.dart` (F-14), as methods of
  `_FloorScreenState` called from app-bar actions:

```dart
  void showZone(Set<String> numbers, {required bool fadeOthers}) {
    if (!controller.fitToTables(numbers)) controller.fitToView();
    controller.setTableFocus(fadeOthers ? numbers : null);
  }

  void showAllZones() {
    controller.fitToView();
    controller.setTableFocus(null);
  }

  /// The tables the POS knows that this floor does not draw.
  Set<String> unplacedTables(Set<String> codes) => codes.difference({
        for (final table in controller.tables)
          if (table.number case final number?) number,
      });
```

- **Z22. The demo, at its smallest.** The Salon gains demo zones, a
  host's data, untranslated: **A** = 1–5, **B** = 6–7, **C** = 8–11
  (F-15). For an area with zones (the Teras has none) the side panel
  gains a zone `SegmentedButton` (*All*, A, B, C) and a **"Fade the
  others"** switch; a zone calls Z21's `showZone`, *All* calls
  `showAllZones`, both kept per `Area`.
  - Three demo strings join `demo_strings.dart`: `zones` (*Zones /
    Bereiche / Bölgeler*), `allZones` (*All / Alle / Tümü*), `fadeOthers`
    (*Fade the others / Andere abblenden / Diğerlerini soldur*); they join
    the native reads owed to the human.
- **Z23. The CHANGELOG** (Unreleased): **Added** `fitToTables` (margin,
  3 m minimum span, its result, pending with no view); **Added**
  `setTableFocus` and `tableFocus` (the selection mode fades tables
  outside the focus; not saved; kept across loads and mode switches); no
  schema change. **l10n: no planner string is added; `lib/src/l10n/` is
  untouched.**

## Invariants

- **I-1.** The engine and the renderer are untouched. Both allocation
  invariant tests and every golden stay as they are, and green.
- **I-2.** Neither call executes a command. No sequence of `fitToTables`
  and `setTableFocus` moves `designJson()`, `dirty`, either plan's undo
  depth, `revision` or `serviceLayoutChanges`.
- **I-3.** Draw order is unchanged: the veil is one region, drawn in one
  call.
- **I-4.** The design mode draws as before whatever the focus. The
  selection mode draws as before while the focus is null.
- **I-5.** Export and Print never show the veil (14b-2 A-3).
- **I-6.** Every existing test passes unedited. The new parameters of
  `PlannerView` and `PlannerShell` are optional.

## Testing and named mutants

**Fixtures** (the testing bar; 14c R-2): a hand-made servable definition
with an **asymmetric** top, turned 37°, one copy mirrored, **40 m off the
origin**; tables on a **hidden** and a **locked** layer; a duplicated
number, `B4`, an unnumbered table; a **non-identity camera** (panned, at
0.37 px/mm) before every call; **look-alikes**: a TEXT and a room named
`7` far from table 7, and a table numbered ` 7 ` asked for as `7`.
Expected boxes and screen points are computed **in the test**, by the
forward transform.

**Framing:**
- **M-Z1. Frame by any text.** Killed by: the framed world excludes the
  TEXT and the room `7`.
- **M-Z2. Hidden tables framed.** Killed by: `{'5'}` (hidden) returns
  false, and `{'5', '3'}` frames 3 alone.
- **M-Z3. The box at the identity, or at the translation only.** Killed
  by: for the turned, mirrored, off-origin table, `framingFor` equals Z3
  applied to the test's own transformed-corner box (`closeTo`).
- **M-Z4. No minimum span, or no clamp.** Killed by: one 380 mm stool in
  1000 × 700 gives exactly `0.95 · 700 / 3000`; `frameTables` with a
  1e7 px viewport gives `kMaxScale`, and a 1e9 mm box `kMinScale`.
- **M-Z5. Margin dropped or doubled.** Killed by: two tables 10 m apart,
  with an expected scale that includes 2 × 500 mm.
- **M-Z6. Centre or y flip wrong.** Killed by: from the non-identity
  prior camera, the union's centre maps to the canvas centre and the upper
  table is drawn above.
- **M-Z7. Requesting when none is found.** Killed by: false returned,
  the camera identical, `fitRequests` silent, `takeFitOnStart()`
  unchanged.
- **M-Z8. No pending framing.** Killed by: call with no view, then mount:
  the first frame is framed.
- **M-Z9. `load` keeps the target.** Killed by: `fitToTables`, `load`,
  then mount: the page is fitted.
- **M-Z10. Resolved at call time.** Killed by: in the selection mode with
  no view, `fitToTables({'3'})`, then `restoreServiceLayout` moving 3,
  then mount: the frame is at 3's restored place.
- **M-Z11. Counted as state.** Killed by: I-2's listener counters and
  undo depths.
- **M-Z12. The first request wins.** Killed by: `fitToTables` then
  `fitToView` in one frame fits the page; the reverse fits the tables.
- **M-Z13. One table per number.** Killed by: the duplicated number
  frames both tables.
- **M-Z14. A pending framing shifted by the correction** (F-5's order
  reversed). Killed by: with no view, `setMode(selection)` then
  `fitToTables`, then mount with a measured origin unlike the seed: the
  box is centred to within 1e-6 px.
- **M-Z15. The design mode not wired.** Killed by: the framing performs
  through `PlannerShell`'s forwarded `framing`.

**Focus:**
- **M-Z16. Drawn in the design mode.** Killed by: no veil layer (found
  by key), and the pixels over a faded table are unchanged.
- **M-Z17. No subtraction.** Killed by: two overlapping boxes, one
  focused; a pixel in the overlap, inside the focused box, is unveiled.
- **M-Z18. The veil at the untransformed box.** Killed by: pixels read
  back (`PictureRecorder` under `runAsync`, 14c R-10) on the turned,
  mirrored, off-origin table under the non-identity camera: a point
  inside the transformed box only is veiled, one inside the untransformed
  box only is not, and the mirrored box is veiled, not cancelled
  (winding normalised).
- **M-Z19. Unnumbered or hidden tables wrong.** Killed by: the
  unnumbered table is veiled; the hidden table's box is not.
- **M-Z20. The focus kept by handle, or cleared.** Killed by: across
  `setMode`, `resetLayout` and a `load` in which `7` is another instance,
  the set is kept and the veil follows the number.
- **M-Z21. Allocation per frame.** Killed by: a recording canvas over
  N = 60 tables, half of them focused; three warm frames, then a pan and
  a zoom; the same `Path`, `Paint` and buffer every frame, and
  `debugAllocations` steady (14c R-3).
- **M-Z22. Interaction gated by the focus.** Killed by: with 4 outside
  the focus, a tap fires `onTableTap('4')` and selects it, `select({'4'})`
  selects it, `selectedTables` keeps it when the focus is set, a drag
  moves it, and Merge offers it.
- **M-Z23. The veil under the status layer.** Killed by: an unfocused
  statused table's pixel is the status over the paper, then the paper at
  0.6 over that; a focused one's is the status alone.
- **M-Z24. Group fading wrong.** Killed by: a group with no focused
  member uses the faded frame paint; a straddling group uses the normal
  one.
- **M-Z25. Paper ignored.** Killed by: on a dark canvas the veil is
  `kDarkCanvasPaper` at 0.6.
- **M-Z26. Empty set read as null.** Killed by: `setTableFocus({})`
  veils every visible table.
- **M-Z27. The focus counted as state.** Killed by: I-2's counters.

**Docs and demo:**
- **M-Z28. Guide drift.** Killed by: `check_guide.dart` exits 1 once the
  probe's `showZone` is edited.
- **M-Z29. Demo zone ignored.** Killed by `demo_test`: zone B frames
  6–7 (their boxes visible, table 1's not); "Fade the others" sets
  `tableFocus` to {6, 7}; *All* clears it and fits the page.

Each killer is a hypothesis until it has been seen to go red (Ruling
49/50). The plan runs every one and records the result.

## Risks

- **R-1. `Path.combine` on the web** (CanvasKit, skwasm) is untried here
  (F-11). The plan's first task checks it in a web build. The fallback,
  still O(1) per frame with nothing per entity: `saveLayer`, the faded
  boxes, the focused boxes with `BlendMode.clear`, `restore`.
- **R-2.** The veil also pales wall lines crossing a faded box. This is
  accepted, because the box is the table's own floor (B-2).
- **R-3.** Where boxes overlap, the faded neighbour loses the overlap,
  and the focused table stays whole (Z13).
- **R-4.** The values 500 mm, 3 m and 0.6 are guesses (Q-Z3).

## Open questions

- **Q-Z1 (Monépro).** B.1 wants status as Flutter widgets placed with
  `camera.worldToScreen`. jet-cad colours and captions tables itself
  (14c), and the camera is `@internal`. Does Monépro need a public
  world-to-screen mapping or table positions for its overlays, or do
  jet-cad's statuses, captions and groups suffice? This is out of scope
  here and goes to Monépro's phase-2 spec.
- **Q-Z2 (the human).** Should faded tables be inert? Z15 says no; the
  other answer costs rules in five places.
- **Q-Z3 (the human, a look).** The margin, the minimum span and the
  veil, on a tablet and a terminal, in light and dark.
- **Q-Z4 (Monépro).** D21 names *"an app component carrying the table's
  id"*. Under the ruling, jet-cad stores no database id: the link is the
  number, which is `pos_tables.code`. Monépro's spec should say so.
- **Q-Z5.** Should `fitToView`'s page fit be clamped too (F-4)? No real
  sheet reaches the bounds; it is not changed here.
- **Q-Z6.** Is the plan's first task the right place for R-1's check,
  which decides between Z13 and R-1's fallback?
- **Q-Z7.** Should a framing animate? Not here: it jumps, as `fitToView`
  does.

## Out of scope, recorded

Zone regions drawn in the editor (the ruling: no zone data); table
positions or `worldToScreen` for host overlays (Q-Z1); a focus in the
design mode (Z11); a schema change, a zone component or zone-aware
numbering; removing decision 12.

## Files

- **New** (`packages/jet_cad_floor_plan`): `lib/src/host/table_fit.dart`,
  `lib/src/service/table_focus_painter.dart`; tests
  `test/host/table_fit_test.dart`, `test/service/table_focus_painter_test.dart`.
- **Changed** (same package):
  `lib/src/host/{floor_plan_controller,floor_plan_view,service_view}.dart`,
  `lib/src/{planner_view,planner_shell}.dart`,
  `lib/src/service/table_group_painter.dart`; tests
  `test/host/{controller,view,seams}_test.dart`,
  `test/service/table_group_painter_test.dart`.
- **Changed elsewhere:** `apps/restaurant_demo/lib/{main,demo_strings}.dart`,
  `apps/restaurant_demo/test/demo_test.dart`,
  `tool/ci/host_probe/lib/main.dart`, `docs/host-guide.md`, `CHANGELOG.md`.

## Review

Revision 1, not yet reviewed.

| # | Finding | Disposition |
|---|---|---|
