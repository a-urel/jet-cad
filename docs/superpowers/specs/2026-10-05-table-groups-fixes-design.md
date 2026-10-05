# Table groups fixes (F-1 and the chip at low zoom) — design

**Date:** 2026-10-05. **Status:** design, **revision 1**, awaiting an
independent review. **Sub-project:** a fix slice of the table groups work
([2026-10-04-table-groups-design.md](2026-10-04-table-groups-design.md),
merged in a-urel/jet-cad#8 at `3753ca4`); unnumbered.
**Approval:** in the brainstorm on 2026-10-05 the human chose this slice
("Masa gruplarının borcu (fix/)") and its two decisions:
- `controller.selectableMembers(id)` closes F-1;
- the label chip moves outside the frame.

The human then approved the draft below ("Tamam, spec'i yaz").

**Branch:** `claude/dreamy-gates-2kgh4o`, restarted from `main` at
`3753ca4`. The facts below hold there.
**Size:** S. **Packages touched:** `jet_cad_floor_plan` (the controller,
the group painter) and `apps/restaurant_demo`. The engine and the render
package are untouched.

## What it delivers

1. **The POS can ask a group's selectable members.**
   `FloorPlanController.selectableMembers(groupId)` gives the numbers of
   the group's visible, unlocked, live members in the active plan, by the
   same rule Merge and Split use. That closes F-1 (table groups "Amended
   at execution").
2. **The demo grows a group by G6's literal rule.** It grows when the
   request includes all of exactly one group's selectable members. That
   retires ruling R-C5-1.
3. **The chip sits outside the frame.** The label chip's bottom edge
   rests on the frame's top edge. The chip can then never cover a
   member's chairs at any zoom (the debt the table groups smoke found at
   the default fit).

## Facts established (at `3753ca4`)

- **F-1. The rule already exists.**
  - `TableGroupLookup.selectableMembers(String id) → List<GroupTable>`
    (`service/table_groups.dart:137`) gives a group's visible, unlocked
    members.
  - `splitGroup` (`:155`) builds on it.
  - The controller keeps a cached lookup over the active plan's survey,
    groups and layer revision (`host/floor_plan_controller.dart:556-575`).
    It uses that lookup for `selectedGroup` (`:602-605`).
- **F-2. The demo's grow rule is "touches exactly one group".**
  `DemoHomeState.mergeGroups` checks `touched.length == 1`
  (`apps/restaurant_demo/lib/main.dart:302-308`). This is ruling R-C5-1:
  the host could not see locks or visibility.
- **F-3. The host cannot see layers.**
  - 14c A-2 (`2026-10-03-selection-mode-design.md:318-319`) gave
    `FloorPlanTable` no hidden flag: "a host that needs it reads its
    layers itself".
  - No API exposes layers. F-1 of the table groups spec records the gap.
- **F-4. The chip is centred on the frame's top-most point.**
  - The anchor is `(centre x, maxY + kGroupFrameMarginMm)`, in world
    space with y up (`service/table_group_painter.dart:336-340`).
  - Per frame it draws after
    `translate(sx - p.width / 2, sy - p.height / 2)` (`:416-422`). So
    half the chip lies inside the frame.
  - At the default fit (about 0.04 px/mm) the 150 mm margin is about
    6 px on screen, less than half the chip's height. The chip then
    covers the members' chair lines (table groups results, "Debt").
- **F-5. The chip test samples the old place.** TG-V2 (M-TG-22,
  `test/host/table_groups_look_test.dart:219`) reads a chip pixel over a
  neighbour's chair line where the centred chip used to be.

## Decisions

### X1 — `selectableMembers`

- **Signature.** `Set<String> FloorPlanController.selectableMembers(String groupId)`.
  It returns the trimmed numbers of the group's selectable members (live,
  visible, unlocked) in the **active** plan, from the cached
  `_groupLookup` (F-1).
- **Edge cases.**
  - The id is trimmed.
  - An unknown id, or a group with no selectable member, gives an empty
    set.
  - A number carried by two tables (a file duplicate) appears once.
  - The result is an unmodifiable set.
- **Both modes.** It is a pure query, valid in both modes. It reads the
  active plan, which is the design in the design mode, where groups do
  not act (G4) but the rule is still well defined.
- **Not a listenable.** A host calls it when it needs it, at merge time,
  so there is no new notifier.
- **A-2 stands.** 14c's decision holds: `FloorPlanTable` gains no flag,
  and this one method is the whole API change. It is reached through the
  existing export of `FloorPlanController`, so there is no new type.

### X2 — The demo uses G6's literal grow rule

`DemoHomeState.mergeGroups(groups, numbers, selectable)`, where
`selectable(id)` is `controller.selectableMembers`:
- **Grow.** Exactly one group G satisfies both conditions:
  - `selectable(G)` is non-empty;
  - `numbers ⊇ selectable(G)`.

  Then G grows by the other numbers under its id and label. Those
  numbers leave any other group they were in, and a group so emptied is
  dropped with its group status (R-C5-2's rule, kept).
- **New group.** Otherwise the demo makes a new group, as today: the
  numbers leave every group, an emptied group goes with its status, and
  the id is `G<largest trailing digits + 1>`, as fixed at `8f56773`.
- **R-C5-1 is retired.** The spec's "Amended at execution" records the
  retirement.
- **No visible change in the UI.** A selection made under the current
  groups always holds all of a group's selectable members (review 5's
  trace), so the demo behaves as before. The two rules differ only when a
  host sets groups under a live selection, or when a group has no
  selectable member. Both are now handled by the spec's rule.

### X3 — The chip sits on the frame, outside it

- **Placement.**
  - The chip is centred horizontally on the frame's top-most point (F-4)
    as today.
  - Its rounded rectangle's **bottom edge** lies on the frame's top edge
    at that point.
  - In screen terms, it is drawn after
    `translate(sx - p.width / 2, sy - (p.height + kGroupChipPaddingY))`,
    so the rectangle spans `[sy - p.height - 2·padY, sy]` vertically.
- **No member is covered.** The frame encloses every member's box plus
  the margin, so a chip entirely above the frame's top-most point cannot
  cover a member at any zoom.
- **Non-members.** It may cover drafting outside the group, which it
  already could, since the chip is in the overlay above the drafting
  (F-11 of the table groups spec).
- **Hiding rule unchanged.** The chip is still skipped when the frame is
  narrower on screen than the chip.
- **Per-frame recipe unchanged.** The `RRect` and the paragraph are
  built at rebuild time in chip-local coordinates. Only the translate's
  constant changes, with no allocation (14c S7, R-3).
- **TG-V2.** It moves its sample to the chip's new place: a neighbour's
  chair line that now runs under the moved chip. This is a **deliberate
  expectation change** under X3, not a mechanical one. The test still
  kills M-TG-22 (chips in the underlay).

### X4 — What does not change

- the group rules, the frames, the statuses and the toolbar;
- the document;
- the engine and the render package;
- every other existing test, which passes unedited.

## Not in scope

- A layer API for hosts (A-2 stands).
- Moving the frame or the status caption.
- Any other table groups debt: frames jumping on release, or a hull
  enclosing non-members.

## Files

- **Changed:**
  - `packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart`
    (`selectableMembers`);
  - `packages/jet_cad_floor_plan/lib/src/service/table_group_painter.dart`
    (the chip's translate);
  - `apps/restaurant_demo/lib/main.dart` (the grow rule).
- **Tests:**
  - `packages/jet_cad_floor_plan/test/host/table_groups_controller_test.dart`
    (`selectableMembers`);
  - `test/host/table_groups_look_test.dart` (TG-V2 moved, and a new
    low-zoom chip test);
  - `apps/restaurant_demo/test/demo_test.dart` (the grow rule cases).
- **Docs:**
  - the table groups spec's "Amended at execution" (R-C5-1 retired, F-1
    closed);
  - a results note;
  - STATUS.

## Invariants

1. The frame path allocates nothing per entity in steady state. The group
   painter's `debugAllocations` and `debugRebuilds` behave as before.
2. Groups never reach the document.
3. With no groups, behaviour is unchanged.

## Testing and named mutants

**Fixtures** are the table groups fixtures: the off-origin, non-unit
camera; turned and mirrored tables; non-sorted numbers; a locked member
and a hidden member; a file duplicate number.

- **M-TGF-1** — `selectableMembers` includes a locked or a hidden member.
  For `G7 = {12, 3, 8 locked, 9 hidden}` it returns exactly `{12, 3}`.
- **M-TGF-2** — An untrimmed id. `' G7 '` gives the same set; an unknown
  id gives the empty set.
- **M-TGF-3** — A duplicate listed twice. A member number carried by two
  tables (a file duplicate) appears once in the set.
- **M-TGF-4** — The demo grows on "touches one group" (R-C5-1).
  - **Fixture:** a host sets `G7 = {12, 3, 7}` while `{3, 20}` is
    selected, then presses Merge.
  - **Expected:** a **new** group `G8 = {3, 20}`, with `G7 = {12, 7}`
    kept.
  - **The R-C5-1 mutant** grows `G7` to `{12, 3, 7, 20}`.
- **M-TGF-5** — The demo never grows, or grows only when every member
  (locked ones included) is requested.
  - **Fixture:** `G7 = {12, 3, 8 locked}`, with the request `{12, 3, 20}`.
  - **Expected:** `G7` grows to `{12, 3, 8, 20}` under its id and label,
    since its selectable members `{12, 3}` are all requested.
- **M-TGF-6** — A group with no selectable member grows vacuously.
  - **Fixture:** `G9 = {8 locked, 9 hidden}`, and the request `{20, 5}`.
  - **Expected:** a new group; `G9` is not grown.
- **M-TGF-7** — The grow path keeps a number in its old group.
  - **Fixture:** `G1 = {5, 11}` and `G7 = {12, 3}`, with the request
    `{12, 3, 5}` (all of G7's selectable members, and part of G1).
  - **Expected:** `G7` grows to `{12, 3, 5}`, and `G1` becomes `{11}`,
    keeping its id and label.
- **M-TGF-8** — Chip still centred, so it covers members. At the default
  fit (about 0.04 px/mm) and at a close zoom, no chip pixel lies below
  the frame's top-most screen row, inside the frame. This is read through
  the recording canvas: the chip's translated rectangle bottom is at most
  the anchor's screen y.
- **M-TGF-9** — Chip off the frame. Its bottom edge is within 0.5 px of
  the anchor's screen y, so it touches the frame and does not float.
- **TG-V2** still kills M-TG-22 at its new sample.

## Exit gate

1. The planner and demo green lines, `floor_planner`'s tests and
   analyze, and the render package re-run once (unchanged).
2. `flutter build web --release` for the demo.
3. M-TGF-1..9 are each killed, recorded in a results note.
4. A Chromium screenshot of the demo at the default fit with a group:
   the chip clear of the chairs. This is evidence only.
5. **The human's look:** owed and never simulated.

## Risks

- **A chip above the frame can leave the visible area.** A group at the
  top of the view puts its chip above the canvas's top edge, where it is
  clipped. This is accepted: panning shows it.
- **`selectableMembers` reads the active plan.** In the design mode it
  answers for the design document. Groups do not act there, so no UI
  depends on it.
