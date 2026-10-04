# Table groups (merging and splitting tables) — design

**Date:** 2026-10-04. **Status:** design, **revision 1**, awaiting an
independent review. **Sub-project:** a follow-on to 14 (restaurant
embedding); unnumbered until the human gives it a number.
**Approval:** the human chose this as the next POS need ("Masa birleştirme
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
the host types, `FloorPlanView`, `ServiceView`, the table select tool, a new
group painter) and `apps/restaurant_demo`. The engine and the render
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
  groups after trimming. Nothing is assigned on a throw.
- **Unusable entries.**
  - An empty or blank group id, or an empty `members`, throws
    `ArgumentError`.
  - A blank member is dropped when `TableGroup` trims its members.
- **Unknown numbers are kept, not dropped.** A member number with no live
  table is stored; it draws nothing and selects nothing until a table with
  that number exists. This is the same "addressed by number, resolved at
  draw time" rule as statuses.
- **Duplicate numbers.** A member number carried by several tables (a file
  duplicate, F-1) makes all of them members, as `withNumber` returns them
  all.
- **Which tables count.** The group's **visible members** are the visible
  live tables its member numbers resolve to. "Visible" means on a visible
  layer, the same rule the picker and status painter use.
- **A group with fewer than two visible members** draws no frame (G3).
  - Its status still fills the one visible member.
  - Tap and drag on that member behave as for a group of one: the group
    id is still reported (G4).

### G3 — The look (selection mode only)

A new `TableGroupPainter` (`service/table_group_painter.dart`) draws, under
the status fills. It is mounted with the status painter as `PlannerView`'s
underlay, in one `Stack`, with groups below and statuses above.

- **The frame.** Each group with two or more visible members gets one
  closed, rounded outline around them.
  - The outline is the convex hull of the members' **top** corners in
    world space (each member's first leaf's local box, transformed),
    offset outwards by `kGroupFrameMarginMm = 150` world millimetres,
    with rounded corners.
  - It is stroked `kGroupFrameStrokePixels = 2` screen pixels wide in
    `paper.selection`, the paper set (dark theme D3), so it reads on
    every paper.
  - The fill under it is `paper.selection` at alpha `0x18`.
  - **Rebuild.** The frame is rebuilt only when the groups map, the
    document's `stateId`, the table revision or the paper changes, so the
    per-frame cost is one transform and one prebuilt path per group (14c
    S7).
- **The status.**
  - **Fill.** A group status fills every visible member's top, like a
    table status.
  - **Overrides.** It **overrides** each member's own `tableStatuses`
    entry, so a member's own status is not drawn while the group has a
    status. A member's own status shows again when the group has none or
    the member leaves the group.
  - **Caption.** The group's caption is drawn **once**, under the **lead**
    member's number label. The lead is the visible member whose number
    sorts lowest: numeric order when every member number is all digits,
    else plain string order.
  - **Ink.** The caption ink follows dark theme D6c: the lead's composite
    of status over paper.
- **The label.** One label per group: `label` if given, else the visible
  members' numbers joined by `+` in lead order (e.g. `5+6+7`).
  - It is drawn in screen space at the frame's top edge, centred on the
    frame's top-most point.
  - It uses the status caption's text size, on a chip filled
    `paper.selection` with `kStatusCaptionOnDark`/`OnLight` ink by the
    same `foregroundFor` rule.
  - It is skipped when the frame is narrower on screen than the chip.
  - The chip's paragraph is built at rebuild time and cached by `(text,
    ink)`, never per frame.
- **Not plotted.** Groups are never exported or printed (statuses are
  not; host spec A-3).
- **Design mode.** Nothing about groups is drawn in the design mode.

### G4 — Selecting, tapping and moving

The select tool gains a group lookup:
- a number-to-group-id map built from `tableGroups` and the survey at the
  same rate as the picker's candidates;
- `groupOf(table)` gives the group id and its selectable member keys
  (visible, unlocked, live).

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
rule as a modifier tap. It reports nothing, as today.

**A drag on a member**
- **Starting:** an unselected member's group replaces the selection, as
  a single table does today.
- **What moves:** every root-level selected key, which now includes the
  whole group. The existing one-compound `Move` and `onLayoutChanged`
  stay as they are.
- **Locked members:** if the group has a **locked** member, the drag is
  spent and nothing moves.
  - This is checked when the drag would start, the same moment a locked
    single table spends it today.
  - Groups are logical, so moving part of one would silently break the
    arrangement the staff see.

**`FloorPlanController.select(numbers)`** expands each number to its whole
group (every selectable member) before replacing the selection.
`selectedTables` keeps reporting numbers, now including every selected
member.

Tables in no group behave exactly as today.

### G5 — The toolbar

`ServiceView`'s service bar gains two buttons after Redo, separated by a
gap:
- **Merge** (`service-merge`, icon `Icons.merge_type`).
  - **Enabled** when the selection holds tables carrying **two or more
    distinct numbers**.
  - **On press:** `onMergeRequested(numbers)`, the selected tables'
    numbers.
  - **A selection that already includes a group** sends all of its
    numbers. The host decides whether that means "grow the group".
- **Split** (`service-split`, icon `Icons.call_split`).
  - **Enabled** when the selected tables' numbers are **exactly one
    group's** visible members (no more, no less).
  - **On press:** `onSplitRequested(groupId)`.

Both buttons are **hidden** when the host passed no callback for them.
They are disabled, not hidden, when the selection does not qualify. Unnumbered tables
cannot be merged (they have no number to report) and do not count towards
"two or more".

### G6 — The demo (`apps/restaurant_demo`)

- **Merge.** `onMergeRequested` accepts any request. It drops the numbers
  from any group they are in and makes a new group `G<n>`, the next
  integer.
  - It sets the groups and logs `Merged {numbers} as G<n>`.
  - When the selection already held one whole group plus more tables, it
    grows that group under its id instead.
- **Split.** `onSplitRequested` removes the group and its group status,
  and logs `Split G<n>`.
- **Status.** The status buttons apply to a selected **group** through
  `setGroupStatus` when the selection is exactly one group, and to tables
  otherwise.
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
    (`resolveGroups`: the validated number-to-group map, the lead order).
- **Changed, `jet_cad_floor_plan`:**
  - `host/floor_plan_types.dart` (`TableGroup`);
  - `host/floor_plan_controller.dart` (`setTableGroups`, `tableGroups`,
    `setGroupStatus`, `groupStatuses`, `select` expansion, disposal);
  - `host/floor_plan_view.dart` (three callbacks);
  - `host/service_view.dart` (the bar buttons, the underlay `Stack`,
    `ServiceCallbacks`);
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
   demo suites pass unedited, except tests that construct
   `ServiceCallbacks` or `TableStatusPainter` and gain a parameter
   mechanically.
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
- **M-TG-1** — Overlap accepted. `setTableGroups` with `5` in two groups
  must throw, and the old map must be kept.
- **M-TG-2** — Untrimmed keys. `' G1 '` and `' 5 '` resolve as `G1` and
  `5`.
- **M-TG-3** — Unknown numbers dropped. A group naming `99` before table
  99 exists draws its frame once a table numbered `99` is added through
  the design and the mode is switched back.
- **M-TG-4** — Plain tap selects one member only. A tap on `12` selects
  `3, 7, 12`.
- **M-TG-5** — Modifier tap via `toggle`. With the group half selected (by
  `controller.select` of a member and one unrelated table), a modifier tap
  on an unselected member selects all three members and keeps the
  unrelated one.
- **M-TG-6** — `onGroupTap` missing or with the wrong number. A tap on `7`
  reports `onTableTap('7')`, then `onGroupTap('G7', '7')`.
- **M-TG-7** — Drag moves only the hit table. A drag on `3` moves all
  three members by the same delta in one `Move` compound.
- **M-TG-8** — Locked member moved. A drag on an unlocked member of a
  group with a locked member moves nothing.
- **M-TG-9** — `select` not expanded. `controller.select({'3'})` selects
  the whole group.
- **M-TG-10** — Group status not overriding. A member with its own
  `Ordered` and a group `Bill` fills `Bill`. Clearing the group status
  shows `Ordered` again.
- **M-TG-11** — Caption repeated. The group caption appears under the
  lead only. The lead of `{12, 3, 7}` is `3` (numeric order, not string
  order).
- **M-TG-12** — Frame missing or covering the wrong members. The frame's
  path contains every member's top corners plus the margin, and excludes
  a non-member table between them.
- **M-TG-13** — Frame for a single visible member. A group whose second
  member is on a hidden layer draws no frame and still fills the visible
  member.
- **M-TG-14** — Label text. With no `label` it reads `3+7+12`; with a
  label it reads the label, cut to 24 characters.
- **M-TG-15** — Per-frame allocation. Ten steady frames leave both
  painters' `debugAllocations` unchanged. A groups change rebuilds once.
- **M-TG-16** — Merge enabled wrongly. Merge is disabled for one table and
  for two unnumbered tables, and enabled for two numbered ones. It
  reports the numbers.
- **M-TG-17** — Split enabled wrongly. Split is disabled when the
  selection is a group plus one table, or part of a group, and enabled
  for exactly one group's visible members. It reports the id.
- **M-TG-18** — Buttons shown without callbacks. With no merge or split
  callback, the buttons are absent.
- **M-TG-19** — Groups leak into the document. `designJson()` with and
  without groups is byte-identical.
- **M-TG-20** — Groups lost on a mode switch or `resetLayout`. They are
  still drawn after design→selection and after `resetLayout`.
- **M-TG-21** — Frame colour from the theme instead of the paper. On
  Blueprint under the light theme the frame stroke is `paper.selection`
  of the dark set.

## Exit gate

1. Every package's green line (CLAUDE.md), and the apps' `flutter test`
   and `flutter analyze`. Render and engine are unchanged and re-run
   once.
2. `flutter build web --release` for `apps/restaurant_demo` and
   `apps/floor_planner`.
3. M-TG-1..21 are each killed, recorded in a results note.
4. A Chromium smoke of the demo: merge two tables, give the group a
   status, drag the group, split it. Screenshots are evidence for the
   human.
5. **The human's look** on macOS and web, and touch on a tablet: owed and
   never simulated.

## Risks

- **A hull across empty floor.** Members far apart give a frame that
  spans the floor between them. This is accepted for a logical link (the
  human's choice); the label and the shared fill carry the meaning.
- **Lead order.** Numbers are free text (T4). "Numeric when all digits,
  else string" is a rule the host may not expect for mixed numbers like
  `5A`. It only decides where the caption sits.
- **Two status maps.** A host could set a table status and a group status
  for the same member and expect both. The override (G3) is documented
  on `setGroupStatus`.
- **Touch.** The long press and the drag now act on a group. 14t's
  hold-back and finger targets are unchanged, but the look on a tablet is
  owed.
