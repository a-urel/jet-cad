# Table groups (merging and splitting tables) — design

**Date:** 2026-10-04. **Status:** design, **revision 2**. Revision 1
(`50d1504`) was reviewed independently: "Ready with fixes", R-1 to R-18,
four of them blocking. All are applied **in place**; the
[Revision log](#revision-log) maps each to its change. **Sub-project:** a follow-on to 14 (restaurant
embedding); unnumbered until the human gives it a number.
**Approval:** revision 2 **approved** by the human ("Onaylıyorum, planı
yaz", 2026-10-04). Before that, the human chose this as the next POS need ("Masa birleştirme
/ ayırma", 2026-10-04) and approved every decision below in the
brainstorm:
- the merge is the POS's runtime state, outside the document;
- both the staff (a toolbar action) and the POS (the API) start a merge,
  and the POS decides;
- the link is logical only: no table moves by itself;
- a group is addressed by a **POS-given group id**;
- the look is a frame and one label;
- the planner's action is a button on the service toolbar;
- a group status is separate and overrides the members' own;
- a tap selects the whole group and reports both;
- the label is the POS's text, or else the numbers.

The human then said "Tamam, spec'i yaz".

**Branch:** `claude/dreamy-gates-2kgh4o`, restarted from `main` at
`4490cd9`. The facts below hold there.
**Size:** M. **Packages touched:** `jet_cad_floor_plan` (the controller,
the host types, `FloorPlanView`, `ServiceView`, `PlannerView`'s new
`overlay` slot, the table select tool, a new group painter) and
`apps/restaurant_demo`. The engine and the render
package are untouched.

## What it delivers

In the selection mode a host can **group tables**. Two or more numbered
tables then act as one:
- **Look:** a frame drawn around them, one label, and one status fill and
  caption.
- **Behaviour:** a tap on any member selects the whole group and reports
  the group id with the tapped number. A drag on any member moves the
  whole group.
- **Toolbar:** the service toolbar offers **Merge** when two or more
  tables are selected, and **Split** when exactly one group is selected.
  Each button only **asks** the host. The host owns the merge rules
  (bills, covers), sets the groups it accepts, and keeps them across
  restarts.

Groups are not saved in the plan, not undone, not printed and not shown in
the design mode, exactly as statuses are today.

## Facts established (at `4490cd9`)

- **F-1. Tables and numbers.**
  - A table is a live, root-level `InstanceNode` whose definition carries
    a `SeatingComponent`.
  - Its number is the text of its `TABLE` ATTRIB: table-identity spec T1
    and T2, `tables/table_index.dart:58-101`.
  - The host addresses tables only by number (umbrella D18).
  - `TableSurvey.withNumber(n)` returns every table with that number
    (`:104-110`).
  - A design-mode duplicate is refused at the field (T6); a duplicate from
    a file is a warning that addresses both tables.
- **F-2. Statuses.** Statuses are runtime state on the controller:
  - `_statuses` is a `ValueNotifier<Map<String, TableStatus>>`
    (`host/floor_plan_controller.dart:184-204`), set whole by
    `setTableStatus`, "Not document state -- no command, no undo, no
    [dirty], no [revision]";
  - they survive mode switches, `resetLayout` and `load` (selection-mode
    spec S6);
  - `TableStatus` caps its caption at 12 grapheme clusters
    (`host/floor_plan_types.dart:67-89`).
- **F-3. The status painter** (`service/table_status_painter.dart`):
  - it rebuilds on `stateId`, the table revision, the status map's
    identity and the paper (`:219-233`);
  - per status it fills the **top** (first leaf) of every visible table
    with that number, and places the caption below the table's number
    label;
  - per frame it only transforms and draws prebuilt objects
    (`debugAllocations`, 14c S7);
  - it is mounted as `PlannerView`'s `underlay` (`host/service_view.dart`,
    under the drafting).
- **F-4. Selection and moving** (`service/table_select_tool.dart`):
  - a tap replaces the selection with the hit table, or toggles it with
    Shift, Ctrl or ⌘ (`:154-170`);
  - a long press toggles it (`:189-196`);
  - a drag past the slop selects the hit table if it was unselected, then
    moves every root-level selected key in one
    `CompoundCommand(label: 'Move')` (`:103-124`, `:174-185`);
  - a locked table is picked and tapped, never selected or moved (14c
    R-1);
  - `onTableTap(number)` fires on a tap of a numbered table, locked ones
    included.
- **F-5. `SelectionController.toggle` flips each key on its own**
  (`jet_cad_2d_flutter/lib/src/selection.dart:131-142`). A group that is
  half selected would come out half selected the other way.
  - `replace` (`:122-129`) does no filtering. Keys on hidden or locked
    layers are pruned only at the next document change (`:168-196`), so
    any expansion must filter before it calls `replace`.
- **F-6. The service copy** allows `transform` and `components` only
  (`DraftPermissions.runtime`). It is thrown away on `setMode(design)`,
  `resetLayout` and `load` (controller `:357-359`, `:376-377`, `:327`).
- **F-7. The service bar** is a 44 px `Row` keyed `service-bar`, with
  Undo, Redo, Export… and Print… buttons (`host/service_view.dart`, in
  `build`). `FloorPlanView` passes `onTableTap` and `onLayoutChanged` into
  `ServiceView` through `ServiceCallbacks`, which is read at every call
  (`floor_plan_view.dart:115-123`, `table_select_tool.dart:19-22`).
- **F-8. The host can read and select by number.**
  - `selectedTables` is a `ValueListenable<Set<String>>` of numbers
    (controller `:181`, `:219`).
  - `select(Set<String>)` replaces the selection with every live, visible,
    unlocked table carrying one of the numbers (`:456-476`).
- **F-10. The picker.**
  - Its candidates carry each table's `box`, the definition's bounding
    box covering "its chairs, the space between them". The box is cached
    per definition (`service/table_picker.dart:2-4`, `:117-119`,
    `:177-180`), defined for every candidate, and skipped for a singular
    transform.
  - A candidate's `top` may be null when the first leaf is not a top
    (`:94-95`).
  - Candidates are rebuilt on `stateId` and the table revision only
    (`:154-163`).
- **F-11. Draw order in `PlannerView`.** The `underlay` is painted
  **below** `DraftCanvas` (`planner_view.dart:244-252`), so anything in it
  is overdrawn by the drafting.
- **F-9. The architecture rule.** "Runtime state (occupied, reserved) is
  not in the document at all; it is supplied to the view layer"
  (`2026-07-27-jet-cad-2d-architecture-design.md:382-384`).
  - The umbrella spec puts "table merging as a document concept" out of
    scope, with no reason given.
  - Re-parenting tables under a `GroupNode` would make them non-tables
    (T1), and `runtime` refuses `structure` anyway.

## Decisions

### G1 — The API

The public barrel `lib/jet_cad_floor_plan.dart` exports one new type and
the controller gains these members.

- **`TableGroup`** (in `host/floor_plan_types.dart`):
  `@immutable final class TableGroup({required Set<String> members, String? label})`.
  - `members` is stored as an unmodifiable set of **trimmed** numbers.
  - `label` is cut to `TableGroup.maxLabel = 24` grapheme clusters, like
    `TableStatus`'s caption (R-12).
  - Equality is by value.
- **`FloorPlanController.setTableGroups(Map<String, TableGroup> groups)`.**
  It replaces every group at once, with trimmed group ids.
  - Like `setTableStatus`, it makes no command, no undo, no `dirty`, no
    `revision`.
  - It validates first and assigns nothing on failure (G2).
- **`ValueListenable<Map<String, TableGroup>> get tableGroups`.**
- **`FloorPlanController.setGroupStatus(Map<String, TableStatus> statuses)`**
  and **`ValueListenable<Map<String, TableStatus>> get groupStatuses`**,
  keyed by trimmed group id. They are kept apart from `tableStatuses`;
  neither map's keys are interpreted in the other.
- **`ValueListenable<String?> get selectedGroup`.** The id of the group
  the selection is **exactly**, by the rule of G5's Split, else null. It
  drives Split, and lets a host route a status to a group without
  re-deriving layer rules it cannot see (14c A-2).
- **`FloorPlanView`** gains three optional callbacks, passed through
  `ServiceCallbacks` like today's two (F-7):
  - `onGroupTap(String groupId, String number)`;
  - `onMergeRequested(Set<String> numbers)`;
  - `onSplitRequested(String groupId)`.

  The planner never creates, changes or removes a group itself; only
  `setTableGroups` does.
- **Lifetime.** Groups and group statuses survive `setMode`, `resetLayout`
  and `load`, like statuses (F-2). A host that loads another plan sets
  new groups.

### G2 — Validation

- **Overlapping membership.** `setTableGroups` throws `ArgumentError`,
  naming the number and both group ids, when a number appears in two
  groups after trimming (`'5'` and `' 5 '` overlap).
- **Unusable entries.** `setTableGroups` throws `ArgumentError` for:
  - an empty or blank group id;
  - two ids that collide after trimming (`'G1'` and `' G1 '`). Unlike
    `setTableStatus`, the last entry does not silently win;
  - a group whose `members` are empty **after trimming**. `TableGroup`
    drops blank members.
- **No partial effect.** Validation runs before any assignment. On a
  throw nothing is assigned and **no listener is notified**.
- **Labels.** `label` is trimmed. A blank or empty label means none.
- **Orphan group statuses.** A group status whose id has no group is kept
  and draws nothing. It applies again if a group with that id comes back.
- **Unknown numbers are kept, not dropped.** A member number with no live
  table is stored; it draws nothing and selects nothing until a table with
  that number exists. This is the same "addressed by number, resolved at
  draw time" rule as statuses.
- **Duplicate numbers.** A member number carried by several tables (a file
  duplicate, F-1) makes all of them members, as `withNumber` returns them
  all.
- **Which tables count.**
  - The group's **visible members** are the live tables its member
    numbers resolve to that lie on a visible layer. This is the same rule
    the picker and status painter use.
  - Its **selectable members** are the visible members that are also
    unlocked (14c R-1).
  - A member on a hidden layer counts for neither. A **locked** visible
    member counts as visible, not selectable.
- **A group with fewer than two visible members** draws no frame (G3).
  - Its status still fills the one visible member.
  - Tap and drag on that member behave as for a group of one: the group
    id is still reported (G4).

### G3 — The look (selection mode only)

A new `TableGroupPainter` (`service/table_group_painter.dart`) draws in
two layers:
- the **frames**, in `PlannerView`'s `underlay`, in one `Stack` under the
  status fills (frames below, statuses above, the status layer keeping its
  key `table-status-layer`; the group layer keyed `table-group-layer`);
- the **label chips**, in a new optional **`overlay`** slot of
  `PlannerView`, painted **above** `DraftCanvas` and below the selection
  overlay. That way the chairs' lines do not paint over the chip (F-11).
  `PlannerView` lives in `jet_cad_floor_plan`, so neither the render
  package nor the engine is touched.

- **The frame.** Each group with two or more visible members gets one
  closed, rounded outline around them.
  - **Geometry.** The outline is the convex hull of the four corners of
    each visible member's **`definitionBounds` box** (the picker's `box`,
    F-10), transformed to world space. That box includes the chairs and
    is defined for every table, circles and tables without a top
    included.
  - **Offset.** The hull is offset outwards by `kGroupFrameMarginMm = 150`
    world millimetres with **round joins of radius equal to the margin**.
    Members with a singular transform or an empty box are skipped, as the
    picker skips them.
  - **No fill.** A table that is not a member can lie inside the hull
    (Risks), and a tint would make it read as grouped.
  - **Colour.** It is stroked `kGroupFrameStrokePixels = 2` screen pixels
    wide in **`paper.gripMove`**, from the paper set (dark theme D3). That
    is purple, distinct from `paper.selection` (the selected outline).
    Grips never show in the selection mode, so it means only "group"
    there. It has at least 5:1 on every swatch (light `0xFF7A3FD1`, dark
    `0xFFC4A0FF`).
  - **Draw order.** Frames are drawn in ascending order of each group's
    lowest member handle (the draw-order non-negotiable).
  - **Rebuild.** The frame is rebuilt only when the groups map, the
    document's `stateId`, the table revision or the paper changes.
- **The per-frame recipe** (14c S7, R-3: no allocation, no `Offset` per
  frame):
  - one reused `Paint` per painter, its `strokeWidth` set in place to
    `kGroupFrameStrokePixels / scale` each frame;
  - prebuilt world-space `Path`s drawn under one reused camera matrix;
  - each chip's `RRect` and `Paragraph` built at rebuild time in
    chip-local coordinates, its world anchor computed at rebuild time,
    then drawn after `canvas.translate` to the anchor's screen point.
- **The status.** The status painter changes how it resolves:
  - **Iteration.** It iterates the survey's visible tables, not the
    status map, and resolves each table's **effective status**: its
    group's status if the group has one, else its own table status. The
    early return on an empty table-status map goes.
  - **Rebuild key.** The identities of `tableGroups` and `groupStatuses`
    join the rebuild key, `ServiceView`'s repaint merge and
    `shouldRepaint`.
  - **Fill.** A group status fills every visible member's top, like a
    table status.
  - **Overrides.** It **overrides** each member's own `tableStatuses`
    entry, so a member's own status is not drawn while the group has a
    status. A member's own status shows again when the group has none or
    the member leaves the group.
  - **Caption.** The group's caption is drawn **once**, under the **lead**
    member's number label.
  - **Lead order.** The lead is the visible member **that has a top**
    whose number sorts lowest:
    - numeric order when every such member's number is all digits,
      compared as (length after stripping leading zeros, then string),
      never `int.parse`;
    - else plain string order;
    - ties, as duplicate numbers give, go to the lowest handle, so the
      caption is drawn exactly once.
  - **Ink.** The caption ink follows dark theme D6c: the lead's composite
    of status over paper.
- **The label.** One label per group: `label` if given, else the visible
  members' **distinct** numbers joined by `+` in lead order (e.g. `5+6+7`,
  never `5+5+6`).
  - **Placement.** It is drawn in screen space, centred on the frame's
    **top-most point**: the frame bounds' centre x at its maximum world y,
    computed at rebuild time.
  - **Style.** It uses the status caption's text size, on a chip filled
    `paper.gripMove` with `kStatusCaptionOnDark`/`OnLight` ink by the
    same `foregroundFor` rule.
  - **Layout.** The paragraph is laid out at the label's intrinsic width,
    on one line with no wrap, so a 24-character label never breaks.
  - **Hiding.** It is skipped when the frame is narrower on screen than
    the chip.
  - **Cache.** The paragraph is built at rebuild time and cached by
    `(text, ink)`, never per frame.
- **During a drag** the frames, fills and chips stay where they are and
  jump on release, as status fills do today. Only the outlines follow the
  drag preview.
- **Not plotted.** Groups are never exported or printed (statuses are
  not; host spec A-3).
- **Design mode.** Nothing about groups is drawn in the design mode.

### G4 — Selecting, tapping and moving

The select tool takes `ValueListenable<Map<String, TableGroup>> groups` and
gains a group lookup:
- **Where it lives.** The lookup sits in the Flutter-free
  `service/table_groups.dart`.
- **What it holds.** A number-to-group-id map, plus per group its
  selectable member keys and whether it has a locked visible member. The
  member keys come from the picker's candidates that are not `locked`.
- **When it rebuilds.** On the picker's key (`stateId`, table revision)
  **and** the identity of the groups map, so a `setTableGroups` alone
  refreshes it.

**A tap on a member**
- **Plain tap:** replaces the selection with **all** the group's
  selectable members.
- **With Shift, Ctrl or ⌘:** if the tapped member is selected, removes
  every member; otherwise adds every member. This is computed as one
  `replace` over the resulting set, never `toggle` (F-5).
- **Callbacks:** `onTableTap(number)` fires as today, then
  `onGroupTap(groupId, number)`. A tapped **locked** member reports both
  and selects nothing (R-1).

**A long press on a member** adds or removes the whole group by the same
rule as a modifier tap, through one `replace` (never `toggle`). It reports
nothing, as today.

**A drag** (on any selected table, member or not)
- **Starting:** an unselected member's group replaces the selection, as
  a single table does today.
- **What moves:** at drag start, `_moving` is the root-level selected
  keys **expanded to the selectable members of every group that has a
  member among them**. So a half-selected group (one selected before the
  groups changed) moves whole. The existing one-compound `Move` and
  `onLayoutChanged` stay as they are.
- **Locked members:** if any group so involved has a **locked visible**
  member, the drag is spent and nothing moves.
  - This holds whether the drag started on that group's member or on
    another selected table.
  - It is checked when the drag would start, the same moment a locked
    single table spends it today.
  - A spent drag leaves the selection as it was before the press, so it
    does not replace it.
  - A locked member on a **hidden** layer does not count; the picker
    cannot see it.
  - Groups are logical, so moving part of one would silently break the
    arrangement the staff see.

**Selecting by number.** The expansion happens inside the controller's
`_select`, which `select`, `setMode` and `resetLayout` all use, **in the
selection mode only**. Groups do not exist in the design mode (G3).
- Each number expands to its group's member numbers.
- The result then goes through the existing visible, unlocked, live
  filter, so a locked or hidden member is never selected.
- `selectedTables` keeps reporting numbers, now including every selected
  member.

Tables in no group behave exactly as today.

### G5 — The toolbar

`ServiceView`'s service bar gains two buttons after Redo, separated by a
gap:
- **Merge** (`service-merge`, icon `Icons.merge_type`).
  - **Units.** A **unit** is a group, or a selected number in no group.
  - **Enabled** when the selected numbers span **two or more units**. So
    exactly one whole group is disabled, and two tables sharing one
    duplicate number are disabled.
  - **On press:** `onMergeRequested(selectedTables.value)`, exactly the
    selected numbers. The host decides what a selection spanning a group
    means, e.g. "grow the group".
- **Split** (`service-split`, icon `Icons.call_split`).
  - **Enabled** when `selectedGroup` is non-null, i.e. when:
    - the set of selected numbers equals the numbers of exactly one
      group's **selectable** members;
    - that set is not empty;
    - no unnumbered table is selected.

    A group with a locked visible member therefore qualifies, since its
    locked member is never selected (14c R-1). A group with one visible
    member qualifies too.
  - **On press:** `onSplitRequested(selectedGroup.value!)`.
- **Freshness.** Both flags follow the selection **and** `tableGroups`:
  a `setTableGroups` with the selection unchanged updates them.

Both buttons are **hidden** when the host passed no callback for them.
They are disabled, not hidden, when the selection does not qualify. Unnumbered tables
cannot be merged (they have no number to report) and do not count towards
"two or more".

### G6 — The demo (`apps/restaurant_demo`)

- **Merge.** `onMergeRequested(numbers)` accepts any request.
  - **Grow.** If the numbers include all the selectable members of
    exactly one existing group, it grows that group under its id with the
    other numbers.
  - **New group.** Otherwise it drops the numbers from any group they are
    in and makes a new group `G<n>`, where n is the largest existing
    numeric suffix plus one.
  - **After.** It sets the groups and logs `Merged {numbers} as G<n>`.
- **Split.** `onSplitRequested` removes the group and its group status,
  and logs `Split G<n>`.
- **Status.** The status buttons apply to a group through `setGroupStatus`
  when `selectedGroup` is non-null, and to the selected tables otherwise.
- **Display.** The tables list shows the groups, and `onGroupTap` is
  logged.

### G7 — What does not change

- **Data:** the document, the file format, the design mode, the engine and
  the render package.
- **Service-copy edits** are still only `TransformNodeCommand` moves (F-6).
- **Existing callbacks:** `onTableTap` and `onLayoutChanged`, and their
  payloads.
- **Statuses:** `setTableStatus` and `tableStatuses` mean exactly what
  they mean today.
- **No groups:** a plan with no groups behaves pixel- and
  event-identically to today.

## Not in scope

- **Persistence.** Saving groups across restarts is the host's job (G1).
- **Arrangement.** Moving tables next to each other, or snapping them
  together.
- **Design-time combinations.** Preset combinations saved in the design
  (a document concept).
- **Bill rules.** Adding up covers, or any POS-side rule.
- **Sync.** Live sync between terminals.
- **Nesting.** A group of groups, or a table in two groups (refused, G2).
- **Gestures.** Drag-onto-table to merge.

## Files

- **New:**
  - `packages/jet_cad_floor_plan/lib/src/service/table_group_painter.dart`
    (the frame, the label, the group lookup shared with the tool);
  - `packages/jet_cad_floor_plan/lib/src/service/table_groups.dart`
    (Flutter-free: validation, the number-to-group lookup, selectable
    members, the lead order, the Merge/Split rules).
- **Changed, `jet_cad_floor_plan`:**
  - `host/floor_plan_types.dart` (`TableGroup`);
  - `host/floor_plan_controller.dart` (`setTableGroups`, `tableGroups`,
    `setGroupStatus`, `groupStatuses`, `select` expansion, disposal);
  - `host/floor_plan_view.dart` (three callbacks);
  - `host/service_view.dart` (the bar buttons, the underlay `Stack`, the
    overlay, `ServiceCallbacks`, the repaint merge);
  - `planner_view.dart` (the optional `overlay` slot above `DraftCanvas`);
  - `service/table_select_tool.dart` (G4);
  - `service/table_status_painter.dart` (group status override and the
    single caption);
  - `lib/jet_cad_floor_plan.dart` (export `TableGroup`).
- **App:** `apps/restaurant_demo/lib/main.dart` and its test.
- **Tests:** new files under `packages/jet_cad_floor_plan/test/service/`
  and `test/host/`.

## Invariants

1. **The frame path allocates nothing per entity in steady state** (14c
   S7). The group painter and the status painter build at rebuild rate
   only, measured by their `debugAllocations`.
2. **No group, no change** (G7). The existing selection-mode, status and
   demo suites pass unedited, except for mechanical changes:
   - tests that construct `ServiceCallbacks`, `TableStatusPainter` or
     `TableSelectTool` (`table_select_tool_test.dart:65`) gain a
     parameter;
   - the barrel test (`test/host/barrel_test.dart:28-43`, B1) gains
     `TableGroup`.
3. **Groups never reach the document.** `designJson()` and the service
   copy are byte-identical with and without groups.
4. **The planner only asks.** No group changes without a
   `setTableGroups` call.

## Testing and named mutants

**Fixtures.**
- The camera is off the origin at a non-unit scale.
- Tables are turned and mirrored, not axis-aligned at the origin.
- Group ids and numbers are deliberately non-sorted (e.g. `G7` holding
  `12, 3, 7`).
- One fixture has a duplicate number from a file, and one has a locked
  member.
- Pixels are read through the real `ServiceView` under the floor planner's
  seed (the dark theme palette fixture), in both themes.

**Named mutants.**
- **M-TG-1** — Overlap accepted. `setTableGroups` with `5` and `' 5 '` in
  two groups must throw. The old map is kept and no listener is notified.
- **M-TG-2** — Untrimmed keys. `' G1 '` and `' 5 '` resolve as `G1` and
  `5`.
- **M-TG-3** — Unknown numbers dropped. A group naming `99` before table
  99 exists draws its frame once a table numbered `99` is added through
  the design and the mode is switched back.
- **M-TG-4** — Plain tap selects one member only. A tap on `12` selects
  `3, 7, 12`.
- **M-TG-5** — Modifier tap via `toggle`.
  - **Fixture:** `controller.select({'3', '20'})` **before**
    `setTableGroups` makes `G7 = {12, 3, 7}`. The group is then half
    selected.
  - **Expected:** a modifier tap on `7` gives `{3, 7, 12, 20}`. The
    toggle mutant gives `{7, 12, 20}`.
- **M-TG-5b** — Long press via `toggle`. The same fixture and expectation,
  with a long press on `7`.
- **M-TG-6** — `onGroupTap` missing or with the wrong number.
  - A tap on `7` reports `onTableTap('7')`, then `onGroupTap('G7', '7')`.
  - A tap on a **locked** member reports both and selects nothing.
- **M-TG-7** — Drag moves only the hit table. A drag on `3` moves all
  three members by the same delta in one `Move` compound.
- **M-TG-8** — Locked member moved. A drag on an unlocked member of a
  group with a locked member moves nothing.
- **M-TG-8b** — Locked group moved through another table. With such a
  group selected and a non-member added by a modifier, a drag on the
  non-member moves nothing.
- **M-TG-8c** — Half-selected group moved in part. With M-TG-5's fixture,
  a drag on `3` moves `3`, `7`, `12` and `20`.
- **M-TG-9** — `select` not expanded. `controller.select({'3'})` selects
  the whole group.
- **M-TG-9b** — Expansion unfiltered. With a member on a locked layer and
  one on a hidden layer, `selectedTables` after `select({'3'})` reports
  neither.
- **M-TG-10** — Group status not overriding. A member with its own
  `Ordered` and a group `Bill` fills `Bill`. Clearing the group status
  shows `Ordered` again.
  - The pixels are read after `setGroupStatus` with **no camera or
    document change**, so a missing repaint listener is killed.
- **M-TG-11** — Caption repeated. The group caption appears under the
  lead only. The lead of `{12, 3, 7}` is `3` (numeric order, not string
  order).
- **M-TG-11b** — Caption under every duplicate. With the lead's number
  duplicated by a file, the caption is drawn once, under the lower handle.
- **M-TG-12** — Frame missing or covering the wrong members.
  - **Fixture:** members have an asymmetric, mirrored definition
    (selection spec R-2).
  - **Expected:**
    - the frame's path contains every member's `definitionBounds`
      corners, each pushed outwards by the margin;
    - it excludes a non-member table placed **beside** the members,
      outside the hull plus margin.
- **M-TG-13** — Frame for a single visible member. A group whose second
  member is on a hidden layer draws no frame and still fills the visible
  member.
- **M-TG-14** — Label text. With no `label` it reads `3+7+12`; with a
  label it reads the label, cut to 24 characters.
- **M-TG-15** — Per-frame allocation. Ten steady frames leave both
  painters' `debugAllocations` unchanged. A groups change rebuilds once.
- **M-TG-16** — Merge enabled wrongly.
  - **Disabled** for one table, for two unnumbered tables, for two tables
    sharing one duplicate number, and for exactly one whole group.
  - **Enabled** for two numbered tables. It reports exactly
    `selectedTables`.
- **M-TG-17** — Split enabled wrongly.
  - **Disabled** for a group plus one table, for part of a group, and for
    a group plus an unnumbered table.
  - **Enabled** for exactly one group's selectable members, including a
    group whose third member is on a locked layer.
  - It reports the id.
- **M-TG-17b** — Flags stale. With the selection unchanged, a
  `setTableGroups` that groups the selected tables flips Merge off and
  Split on.
- **M-TG-17c** — Lookup stale in the tool. Tap, then `setTableGroups`,
  then tap again: the new grouping applies.
- **M-TG-18** — Buttons shown without callbacks. With no merge or split
  callback, the buttons are absent.
- **M-TG-19** — Groups leak into the document. `designJson()` with and
  without groups is byte-identical. This is an **invariant check**, not
  a counted kill: nothing realistic writes groups into the document.
- **M-TG-20** — Groups lost on a mode switch, `resetLayout` or `load`.
  They are still drawn after design→selection, after `resetLayout`, and
  after `load` of the same plan.
- **M-TG-21** — Frame colour from the theme instead of the paper. On
  Blueprint under the light theme the frame stroke is `0xFFC4A0FF` (the
  dark set's `gripMove`), not the light `0xFF7A3FD1`.
- **M-TG-22** — Chip under the drafting. The chip's pixels over a chair
  line show the chip, so it is in the overlay, not the underlay.

## Exit gate

1. Every package's green line (CLAUDE.md), and the apps' `flutter test`
   and `flutter analyze`. Render and engine are unchanged and re-run
   once.
2. `flutter build web --release` for `apps/restaurant_demo` and
   `apps/floor_planner`.
3. M-TG-1..22 (with their b/c variants) are each killed, except the
   invariant check M-TG-19, recorded in a results note.
4. A Chromium smoke of the demo: merge two tables, give the group a
   status, drag the group, split it. Screenshots are evidence for the
   human.
5. **The human's look** on macOS and web, and touch on a tablet: owed and
   never simulated.

## Risks

- **A hull across empty floor.** Members far apart give a frame that
  spans the floor between them. It may enclose tables that are not
  members.
  - This is accepted for a logical link (the human's choice).
  - The frame has no fill, so an enclosed non-member is not tinted. The
    label and the shared status fill carry the meaning.
- **Lead order.** Numbers are free text (T4). "Numeric when all digits,
  else string" is a rule the host may not expect for mixed numbers like
  `5A`. It only decides where the caption sits.
- **The frame colour.** Purple `gripMove` was chosen so an unselected
  group does not read as selected. Grips never show in the selection mode
  (14c S3), so the colour has no other meaning there.
- **Two status maps.** A host could set a table status and a group status
  for the same member and expect both. The override (G3) is documented
  on `setGroupStatus`.
- **Touch.** The long press and the drag now act on a group. 14t's
  hold-back and finger targets are unchanged, but the look on a tablet is
  owed.

## Amended at execution

Recorded at the plan's exit (Task 6). Each was a proposed ruling, accepted
by that task's independent review; the ledger is
`.superpowers/sdd/2026-10-04-table-groups/progress.md`. Where a bullet and
the text above disagree, the bullet holds.

- **R-C5-1 — the demo's grow rule** (`eecc823`, pinned by D18; M1 and
  M8 red). **Retired** by the table groups fixes
  ([2026-10-05-table-groups-fixes-design.md](2026-10-05-table-groups-fixes-design.md),
  X2): with `FloorPlanController.selectableMembers` (X1) the demo applies
  G6's literal rule, and this bullet stands as history only. G6's "the
  numbers include all the selectable members of exactly one existing
  group" was implemented as **"exactly one existing group has a member
  among the numbers"**.
  - A host cannot see which members are selectable (F-1 below). Applying
    the literal rule over the plan's numbers is lock-blind: a group with a
    locked or hidden member could never grow.
  - The two rules differ only for a **half-selected** group. No
    selection-mode UI path makes one: a tap, a modifier tap, a long
    press, `select`, `setMode` and `resetLayout` all expand to whole
    groups, and the demo's own `setTableGroups` calls keep the selection
    whole. The one way in is a host calling `setTableGroups` under a live
    selection (M-TG-5's fixture); the touched group then grows whole.
  - This is the reading G4 already takes: a half-selected group moves
    whole on a drag.
- **F-1 — API finding, closed** by the table groups fixes
  ([2026-10-05-table-groups-fixes-design.md](2026-10-05-table-groups-fixes-design.md),
  X1): `FloorPlanController.selectableMembers(groupId)` gives a group's
  selectable members' numbers, and `FloorPlanTable` stays flagless (A-2).
  The text below is the finding as it stood. The host API cannot answer
  "which members of group X are selectable": `FloorPlanTable` carries no lock or
  visibility flag, and no call exposes `TableGroupLookup.selectableMembers`.
  A `selectableMembers(groupId)` on the controller, or `locked` / `visible`
  on `FloorPlanTable`, would close it and allow G6's literal rule. One
  consequence: a group left holding only locked or hidden members (a
  new-group merge's remainder, R-C5-4) cannot be split or merged from the
  demo's UI; only the POS can clear it.
- **X3 — the chip sits outside the frame**, by the table groups fixes
  ([2026-10-05-table-groups-fixes-design.md](2026-10-05-table-groups-fixes-design.md),
  X3). G3's Placement, "centred on the top-most point", is **superseded**:
  the chip is still centred horizontally on the frame bounds' centre x,
  but its rounded rectangle's **bottom edge** lies on the frame bounds'
  top line (maximum y plus the margin) at that x. Per frame it is drawn
  after `translate(sx - width / 2, sy - (height + kGroupChipPaddingY))`.
  A chip entirely above the bounds then covers no member of its own group
  at any zoom (the centred chip covered the chair lines at the default
  fit). On a slanted frame the chip floats a little above it. The hiding
  rule and the per-frame recipe are unchanged. TG-L7 and TG-V2 carry the
  new placement.
- **R-C5-2 — a merge that empties a group removes its group status**
  (`eecc823`, M7 red in D17). G6 says so only for Split. Without it a stale
  status reattaches when a later merge reuses the id.
- **R-C5-4 — a new-group merge's remainder keeps its id and label**, even
  with one member (`eecc823`, pinned by D20 at `9c09121`).
- **R-C3-2 — the group painters take the paper ARGB notifier**
  (`b464204`). `ServiceView` passes `_paper` (the notifier the status
  painter reads, D6c) and each painter calls `PaperPalette.forPaper`
  itself, not a built `PaperPalette`. The painters are built once
  (`late final`), so a palette passed by value would go stale on a paper
  change; the notifier is also in their repaint merge. M-TG-21b kills the
  theme surface passed as the paper.
- **R-C3-5 — round joins are exact `Path.arcTo` arcs** (`b464204`), not a
  fixed segment count. The chip's anchor and the chip-hiding width come
  from the hull grown by the margin, the exact bounds of a round offset,
  not from `Path.getBounds` (whose arcs' control points reach further).
- **R-C3-1 — frames, the two-member count and the label use the picker's
  candidates** (`b464204`): visible tables, minus singular transforms and
  empty boxes. One number on two tables (a file duplicate) is two visible
  members and gets a frame.
- **R-C3-3 — the status painter skips its survey only when both status
  maps are empty** (`b464204`). G3's "the early return on an empty
  table-status map goes" holds; the both-empty skip saves a survey per
  document change when nothing can fill (M-TG-10d keeps it honest).
- **R-C3-6 — chip padding 5 × 2 px, radius 4 px** (`b464204`;
  `kGroupChipPaddingX/Y`, `kGroupChipRadius`). G3 fixed only the text size
  and the colours.
- **`debugRebuilds` on `TableStatusPainter`** (`b464204`), a test seam
  beside `debugAllocations`. Without it M-TG-15b (the status painter
  rebuilt every frame) survived: the painter caches every object, so a
  per-frame rebuild allocated nothing countable.
- **R-C2-1 — a half-selected group's drag grows the moved set, not the
  selection** (`c5eb454`). G4's `_moving` expansion is applied to
  `_moving` only; after the drag the group is still half selected.
  Moved-but-unselected members show no preview outline during the drag
  and jump on release (G3's "only the outlines follow" covers selected
  tables only).
- **R-C2-4 — the tool's members come from the picker's candidates**
  (`c5eb454`). A member with a singular transform or an empty box is
  neither tapped into the selection nor moved, while `controller.select`
  (from the survey) still selects it by number: the divergence the picker
  already has for such tables.
- **R-C1-2 — `selectedGroup` is always null in the design mode**
  (`638048b`). G1 defines it by G5's Split rule; G4 says groups do not
  exist in the design mode. Killed by M-TG-17-design (TG-C9).
- **R-C1-3 — numeric lead ties** (`638048b`). G3's "(length after
  stripping leading zeros, then string)" compares the **stripped** string,
  then the original string, then the handle: `'07'` and `'7'` order
  totally, and only true duplicates fall to the lowest handle.
- **R-C1-1 — `service/table_groups.dart` has no Flutter import of its
  own** (`638048b`), but depends on Flutter through `TableGroup`, which G1
  places in `host/floor_plan_types.dart`. G4's "Flutter-free" reads that
  way.
- **Notification order** (`f98532f`, documented on `selectedGroup`).
  `selectedGroup` updates **after** `selectedTables` / `tableGroups`
  notify, so a listener to only one of those reads the old
  `selectedGroup` for that callback. G5's "both flags follow the selection
  and `tableGroups`" is met by listening to all three (Task 4's flags).
- **R-C4-1 — Merge and Split sit between two 8 px gaps** (`5261b9c`,
  pinned by TB6 at `cda29b7`). The second gap, before Export / Print, is
  built only when at least one of the two buttons is shown, so a host
  without the callbacks gets today's bar to the pixel (G7).
- **R-C4-2 — Split's press null-guards** `selectedGroup.value` instead of
  G5's `!` (`5261b9c`). Same behaviour; the button is disabled whenever it
  is null.

## Revision log

Revision 2 applies the independent review of revision 1 (`50d1504`),
"Ready with fixes":

| Finding | Severity | Change |
|---|---|---|
| R-1 | blocking | M-TG-12's non-member placed beside, outside the hull; the frame fill dropped; Risks |
| R-2 | blocking | M-TG-5's half-selected fixture: `select` before `setTableGroups` |
| R-3 | blocking | Split on **selectable** members; locked-member group qualifies; unnumbered blocks |
| R-4 | blocking | Drag expands to every involved group; spent on any locked visible member; M-TG-8b/8c |
| R-5 | should-fix | Hull from `definitionBounds` corners; round joins; picker's skips; F-10 |
| R-6 | should-fix | Chip in a new `PlannerView.overlay` slot above `DraftCanvas`; F-11; M-TG-22 |
| R-7 | should-fix | Per-frame recipe; top-most point; intrinsic one-line layout; draw order |
| R-8 | should-fix | Status painter iterates tables; rebuild key, merge, `shouldRepaint`; lead rule; M-TG-11b |
| R-9 | should-fix | Tool takes `groups`, keys on its identity; lookup in `table_groups.dart`; M-TG-17c |
| R-10 | should-fix | Merge on two or more units; payload `selectedTables`; demo grow rule |
| R-11 | should-fix | `selectedGroup` listenable drives Split and the demo |
| R-12 | should-fix | G2 trims before checks, id collisions throw, no notification on throw, orphan statuses |
| R-13 | should-fix | Expansion in `_select`, selection mode only, filtered; M-TG-9b |
| R-14 | should-fix | M-TG-5b, locked tap, M-TG-17b, M-TG-9b; M-TG-19 as invariant; M-TG-20 adds `load` |
| R-15 | nit | Barrel test and `TableSelectTool` in invariant 2's list; layer keys |
| R-16 | nit | Frame and chip in `gripMove` (purple), not `selection`; Risks |
| R-17 | nit | Frames jump on release during a drag (G3) |
| R-18 | nit | Distinct numbers in the joined label; `label` trimmed |
