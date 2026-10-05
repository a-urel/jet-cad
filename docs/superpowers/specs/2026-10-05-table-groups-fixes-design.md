# Table groups fixes (F-1 and the chip at low zoom) — design

**Date:** 2026-10-05. **Status:** design, **revision 2**. Revision 1
(`6a04783`) was reviewed independently: "Ready with fixes", R-1..R-12,
one of them blocking. All are applied **in place**; see the
[Revision log](#revision-log). **Sub-project:** a fix slice of the table groups work
([2026-10-04-table-groups-design.md](2026-10-04-table-groups-design.md),
merged in a-urel/jet-cad#8 at `3753ca4`); unnumbered.
**Approval:** revision 2 **approved** by the human ("Onaylıyorum, planı
yaz", 2026-10-05). Before that, in the brainstorm on 2026-10-05 the human chose this slice
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
  - `splitGroup` (`:148`) builds on it.
  - The controller keeps a cached lookup over the active plan's survey,
    groups and layer revision (`host/floor_plan_controller.dart:556-580`).
    It uses that lookup for `selectedGroup` (`:602-605`).
- **F-2. The demo's grow rule is "touches exactly one group".**
  `DemoHomeState.mergeGroups` (`apps/restaurant_demo/lib/main.dart:300-327`)
  checks `touched.length == 1` (`:305`). This is ruling R-C5-1:
  the host could not see locks or visibility.
- **F-3. The host cannot see layers.**
  - 14c A-2 (`2026-10-03-selection-mode-design.md:318-319`) gave
    `FloorPlanTable` no hidden flag: "a host that needs it reads its
    layers itself".
  - No API exposes layers. F-1 of the table groups spec records the gap.
- **F-4. The chip is centred on the frame's top-most point.**
  - The anchor is `(centre x, maxY + kGroupFrameMarginMm)`, in world
    space with y up (`service/table_group_painter.dart:339-340`).
  - Per frame it draws after
    `translate(sx - p.width / 2, sy - p.height / 2)` (`:416-422`). So
    half the chip lies inside the frame.
  - At the default fit (about 0.04 px/mm) the 150 mm margin is about
    6 px on screen, less than half the chip's height. The chip then
    covers the members' chair lines (table groups results, "Debt").
- **F-5b. A unit test pins the old placement.** TG-L7 asserts the chip's
  translation `dy == sy - p.height / 2`
  (`test/service/table_group_painter_test.dart:595-596`), over a scale
  loop at `:591`.
- **F-6. The query is always fresh.** `_groupLookup` is checked on every
  call against three keys:
  - the survey's identity, which changes with the active document or its
    `stateId` (`:476-486`): a mode switch, `resetLayout`, `load`, undo,
    redo;
  - the groups map's identity, new on every `setTableGroups` because
    `validateTableGroups` returns a fresh map (`:226-230`);
  - the layer table's `mutationRevision`, which raw layer edits move.
- **F-7. The camera.** It only pans and zooms with y flipped
  (`camera_controller.dart:60-101`, `viewport_transform.dart:38-46`:
  `b = c = 0`, `d < 0`). The largest world y is therefore the smallest
  screen y.
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
- **Fresh.** It is fresh at every call, right after `setTableGroups` and
  after a mode switch included (F-6), so it is fresher than
  `selectedGroup`.
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
`selectable(id)` is `controller.selectableMembers`. `selectable` answers
over the same groups as the `groups` argument; in `_merge` that holds,
because `groups` is `c.tableGroups.value` read just before (R-9):
- **Grow.** Exactly one group G satisfies both conditions:
  - `selectable(G)` is non-empty;
  - `numbers ⊇ selectable(G)`.

  Then G grows by the other numbers under its id and label. Those
  numbers leave any other group they were in, and a group so emptied is
  dropped with its group status (R-C5-2's rule, kept).
- **New group.** Otherwise the demo makes a new group, as today: the
  numbers leave every group, an emptied group goes with its status, and
  the id is `G<largest trailing digits + 1>`, as fixed at `8f56773`.
- **Edge cases.**
  - **Two or more groups fully requested** give a new group. D17's
    `11, 3` and D20 already pin this.
  - **A request equal to one group's selectable members and nothing
    else** cannot come from the toolbar, because `mergeQualifies` is
    false (`table_groups.dart:169-181`). From a host it is a no-op grow:
    the groups are re-set with the same content and the merge is logged.
  - **An empty request** is unreachable from the toolbar. From a host it
    would make a group with no members, which `setTableGroups` refuses
    (`:32-34`), so the demo returns without change for it.
  - **A grow that empties another group** (host-only) drops that group
    with its status, through `_merge`'s existing `gone` set
    (`main.dart:340-347`).
- **R-C5-1 is retired.** The spec's "Amended at execution" records the
  retirement.
- **No visible change in the UI.** A selection made under the current
  groups always holds all of a group's selectable members (review 5's
  trace), so the demo behaves as before. The two rules differ only when a
  host sets groups under a live selection, or when a group has no
  selectable member. Both are now handled by the spec's rule.

### X3 — The chip sits on the frame, outside it

- **Camera assumption.** As F-7: no rotation, y flipped. A host can set
  `camera.value` to anything; under a rotated camera the "top" is not the
  screen top, which is accepted (no UI rotates the camera).
- **Placement.**
  - The chip is centred horizontally on the frame **bounds'** centre x,
    as today (F-4).
  - Its rounded rectangle's **bottom edge** lies on the frame bounds'
    top line (`maxY + margin`) at that x.
  - It touches the frame only where the hull's highest vertex sits at
    the bounds' centre x. On a slanted frame (a diagonal group) the frame
    is lower there and the chip floats a little above it (Risks). The 2 px
    stroke is centred on the frame, so where they touch the chip also
    covers the stroke's outer 1 px.
  - In screen terms, it is drawn after
    `translate(sx - p.width / 2, sy - (p.height + kGroupChipPaddingY))`,
    so the rectangle spans `[sy - p.height - 2·padY, sy]` vertically.
- **No member is covered.** The frame encloses every member's box plus
  the margin, so a chip entirely above the frame bounds' top line cannot
  cover a member of its own group at any zoom. Another group's members
  higher up can still be covered, as before.
- **Non-members.** It may cover drafting outside the group, which it
  already could, since the chip is in the overlay above the drafting
  (F-11 of the table groups spec).
- **Hiding rule unchanged.** The chip is still skipped when the frame is
  narrower on screen than the chip.
- **Per-frame recipe unchanged.** The `RRect` and the paragraph are
  built at rebuild time in chip-local coordinates. Only the translate's
  constant changes, with no allocation (14c S7, R-3).
- **Deliberate test changes** under X3. These are not mechanical:
  - **TG-V2** needs its fixture moved, not only a new sample point.
    Table 20's chair line sits at the old anchor row, now exactly the
    chip's bottom edge and so only half covered (`look_test:93-94`). Move
    table 20 up by a whole number of pixels (8 px = 64 mm at
    0.125 px/mm), so its line falls on a pixel centre strictly inside the
    chip's rows. Keep a premise that the row is inside the chip's
    `RRect`, and update the header comment. The test still kills M-TG-22
    (chips in the underlay); TG-V3 computes `insideTop(20)` and is
    unaffected.
  - **TG-L7**'s expectation becomes `dy == sy - (p.height + kGroupChipPaddingY)`.
    Its scale loop gains 0.04 px/mm, so it carries M-TGF-8 and M-TGF-9.
- **Docs to amend.**
  - The parent spec's G3 Placement still says "centred on the top-most
    point" (`2026-10-04-table-groups-design.md:281-283`). Its "Amended at
    execution" gains an X3 bullet.
  - The painter's class doc (`table_group_painter.dart:195-198`) and the
    `_Group` anchor doc (`:172-174`) are updated to match.

### X4 — What does not change

- the group rules, the frames, the statuses and the toolbar;
- the document;
- the engine and the render package;
- every other existing test, which passes unedited. The exceptions are
  the two deliberate changes in X3: TG-V2 and TG-L7.

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
    (`selectableMembers`, a locked-duplicate variant);
  - `test/host/table_groups_look_test.dart` (TG-V2's fixture moved);
  - `test/service/table_group_painter_test.dart` (TG-L7's expectation
    and scale loop);
  - `apps/restaurant_demo/test/demo_test.dart` (the grow rule cases).
- **Docs:**
  - the table groups spec's "Amended at execution" (R-C5-1 retired, F-1
    closed, X3's placement);
  - the painter's doc comments;
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
- **M-TGF-3** — A number decided per number, not per table.
  - **Fixture:** a variant where table 5 is renamed `8`, so `8` is
    carried by an unlocked table (5's) and a locked one.
  - **Expected:** `8` is in the set.
  - **Kills** a mutant that decides each number by its first table, or by
    "every table carrying the number is selectable". A `Set` cannot list a
    number twice, so that is not a mutant.
- **M-TGF-4** — The demo grows on "touches one group" (R-C5-1).
  - **Fixture:** a host sets `G7 = {12, 3, 7}` while `{3, 20}` is
    selected, then presses Merge.
  - **Expected:** a **new** group `G8 = {3, 20}`, with `G7 = {12, 7}`
    kept.
  - **The R-C5-1 mutant** grows `G7` to `{12, 3, 7, 20}`.
- **M-TGF-5** — The demo never grows, grows only when every member
  (locked ones included) is requested, or drops the label. This is
  **D18** (`demo_test:767-788`): `G7 = {12, 3, 8, 9}` labelled `Window`
  grows with `20` and keeps its label. D18 is cited, not duplicated, and
  re-fired under the new rule.
- **M-TGF-6** — A group with no selectable member grows vacuously.
  - **Fixture:** `G9 = {8 locked, 9 hidden}`, and the request `{20, 5}`.
  - **Expected:** a new group; `G9` is not grown.
- **M-TGF-7** — The grow path keeps a number in its old group, or loses
  that group's label or status.
  - **How the request arrives:** select `12, 3, 5` with only
    `G7 = {12, 3}` set; then `setTableGroups` adds `G1 = {5, 11}` with
    label `Bar` and a group status; then press Merge. `mergeQualifies`
    sees two units (G7, G1), so Merge is enabled.
  - **Expected:** `G7` grows to `{12, 3, 5}`; `G1` becomes `{11}`,
    keeping its id, its label `Bar` and its group status.
  - **Red evidence:** the keep-5 mutant fails through the `ArgumentError`
    from `validateTableGroups` (`table_groups.dart:35-41`), since 5 would
    be in two groups.
- **M-TGF-8** — Chip still centred, so it covers members. Through the
  recording canvas (the GroupSpy seam: translations and `RRect`s), at
  cameras of 0.04 and 0.125 px/mm, the chip's translated rectangle bottom
  is at most the anchor's screen y, within 1e-6.
- **M-TGF-9** — Chip off the frame. In the same check, its bottom edge
  equals the anchor's screen y within 1e-6, as TG-L7 compares, so the
  chip does not float above the bounds' top line.
- **M-TGF-10** — `selectableMembers` stale.
  - **Fixture:** call it after `setTableGroups` with the same id and new
    members, and after `setMode(selection)` when a design layer was locked
    in between.
  - **Kills** a memo keyed by the id only, or by the survey only (without
    the groups or the layer revision).
- **TG-V2** still kills M-TG-22 at its new sample.

## Exit gate

1. The planner and demo green lines, `floor_planner`'s tests and
   analyze, and the render package re-run once (unchanged).
2. `flutter build web --release` for the demo.
3. M-TGF-1..10 are each killed (M-TGF-5 by D18), recorded in a results
   note.
4. A Chromium screenshot of the demo at the default fit with a group:
   the chip clear of the chairs. This is evidence only.
5. **The human's look:** owed and never simulated.

## Risks

- **A chip above the frame can leave the visible area.** A group at the
  top of the view puts its chip above the canvas's top edge, where it is
  clipped. This is accepted: panning shows it.
- **A chip floating on slanted frames.** On a diagonal group the frame
  at the bounds' centre x is below the bounds' top line, so the chip sits
  a little above the frame instead of on it. This is accepted: it still
  covers no member.
- **`selectableMembers` reads the active plan.** In the design mode it
  answers for the design document. Groups do not act there, so no UI
  depends on it.

## Revision log

Revision 2 applies the independent review of revision 1 (`6a04783`),
"Ready with fixes":

| Finding | Severity | Change |
|---|---|---|
| R-1 | blocking | TG-L7 listed as a deliberate expectation change; its scale loop gains 0.04; F-5b; X4 |
| R-2 | should-fix | TG-V2's table 20 moved up by 8 px, with a premise |
| R-3 | should-fix | X3 reworded to the bounds' top line; slanted-frame gap in Risks |
| R-4 | should-fix | The parent spec's G3 and the painter's docs are amended |
| R-5 | should-fix | M-TGF-3 uses a locked/unlocked duplicate |
| R-6 | should-fix | M-TGF-10 (freshness); F-6 |
| R-7 | should-fix | M-TGF-5 is D18; M-TGF-7 with a label, a status and how the request arrives |
| R-8 | nit | X2's edge cases |
| R-9 | nit | `selectable` answers over the same groups as `groups` |
| R-10 | nit | M-TGF-8/9 at 0.04 and 0.125 px/mm, within 1e-6 |
| R-11 | nit | X3's camera assumption; "no member of its own group" |
| R-12 | nit | Citations corrected |
