# Task 5 report — the demo (G6)

Implementer, 2026-10-04, on `claude/dreamy-gates-2kgh4o` from `5261b9c`.

## Commits

- `eecc823` feat(table-groups): Task 5 — the demo merges, splits and sets group statuses (not pushed). Parent `cda29b7` (Task 4b, test-only, committed by the controller while this task ran).

## Files changed

- `apps/restaurant_demo/lib/main.dart`: merge, split, status routing, groups line, `onGroupTap` log.
- `apps/restaurant_demo/test/demo_test.dart`: 4 new tests (D16..D19) and their helpers; imports gain `PointerDeviceKind`, `LogicalKeyboardKey`, `TableGroup`. No existing test edited.

Nothing under `packages/` touched. NOTE: `packages/jet_cad_floor_plan/test/host/table_groups_toolbar_test.dart`
showed up modified in the shared working tree during this task (TB6, TB7, from review 4
findings 1 and 2). It was committed as `cda29b7` (Task 4b) before my commit. It is not
mine and is not in `eecc823`.

## What was built (`DemoHomeState`)

- **`mergeGroups(groups, numbers)`** (static, pure): the groups having a member among
  `numbers` are "touched". Exactly one touched → **grow** it under its id, label kept,
  members ∪ numbers. Otherwise → **new group** `nextGroupId(groups.keys)` (ids of the
  groups *before* the merge) of exactly `numbers`; the numbers leave every group; a group
  left empty is dropped, a group left non-empty keeps its id and label.
- **`nextGroupId(ids)`**: `G<max+1>` over ids matching `^G(\d+)$` (BigInt, so a huge
  suffix cannot throw); `G1` when none.
- **`_merge(area, numbers)`** (wired as `onMergeRequested`, bound to the area the view
  was built for): `setTableGroups(merged)`; group statuses of groups the merge emptied
  are removed (R-C5-2); log `<Area>: Merged {numbers by number} as G<n>` (both grow and
  new: the spec's one log line; the id tells which).
- **`_split(area, id)`** (`onSplitRequested`): the group and its group status removed;
  log `<Area>: Split G<n>`.
- **Status buttons**: `selectedGroup.value != null` → `setGroupStatus` on that id (Free
  removes it), log `<Area>: <Status> for G<n>`; otherwise per selected table as before
  (log unchanged). "Random statuses" unchanged (per table).
- **Display**: a 'Groups' heading and a `groups`-keyed line `G1: 3+7+12 (Bill), G4: 7+20`,
  ids and members in reading order (`byNumber`: shared prefix, digits by value), the
  group status by its `kStatuses` name. `none` when no group. The state rebuilds on
  `tableGroups` and `groupStatuses` as on `revision`.
- **`onGroupTap`** logged `<Area>: group G1 tapped at 7`.
- Status heading text: "Status of the selected tables or group".

## Tests added (`apps/restaurant_demo/test/demo_test.dart`)

Fixture `groupPlan()`: eight tables of six kinds, all off the origin, turned and/or
mirrored, numbered `12, 3, 7, 20, 5, 11, 8, 9` in handle order (not sorted); 8 on a
visible locked layer, 9 on a hidden one. The fit camera (off-origin, non-unit). Taps at
the table's base point (the restaurant tables' centre) through the camera, as D14.

- **D16** Shift taps 12 then 3 → Merge → `G1={3,12}`, log `Salon: Merged {3, 12} as G1`,
  line `G1: 3+12`, `selectedGroup == G1`; number field `3, 7` (3 expands to G1) → Merge →
  grown `G1={3,7,12}` (one group), logged; tap 20 → no group log; Eating per table →
  `tableStatuses {20}`, no group status; tap 7 → log `group G1 tapped at 7`, `tapped 7`,
  `selected …`; Bill → `groupStatuses {G1: Bill}`, table statuses untouched, log
  `Salon: Bill for G1`, line `G1: 3+7+12 (Bill)`; with 20 selected, a mouse drag starting
  on 3 → 12, 3, 7 moved by the same world step (> 100 mm), linear parts unchanged, 20 and
  5 bit-identical, `layout changed` once; Split → no group, no group status, 20's own
  status kept, log `Salon: Split G1`, line `none`.
- **D17** merges `{12,3}`, `{7,20}`, `{5,11}` → G1..G3; split G2; merge `{20,7}` → **G4**
  (not a second G3); Ordered on G1, Bill on G3 (line shows both); `11, 3` (two groups)
  → new **G5** `{12,3,5,11}`, G1 and G3 gone **with their statuses**; `20, 5` (G4 + G5) →
  **G6** of all six (the id from the groups before the merge, not a reused G1).
- **D18** a POS-restored `G7={12,3,8 locked,9 hidden}` labelled `Window`; tap 3 →
  `{12,3}`, `selectedGroup G7`; Shift-tap 20 → Merge → `G7={12,3,8,9,20}`, label
  `Window`, log `Merged {3, 12, 20} as G7`, line `G7: 3+8+9+12+20`. Pins R-C5-1.
- **D19** dark platform brightness: merge `20, 5, 7`, Eating on the group, split; no
  exception at each step, theme dark.

## Mutant table

Fired by `scratchpad/tg-task5/mut.py` + `muts.json`: `cp` main.dart to scratch, string
replace (asserted unique), `flutter test --no-pub test/demo_test.dart`, `cp` back, `diff`
exit 0 for every mutant (logs `mut-M*.log`). Lines at the committed main.dart.

| # | Target | Change | Red | Real output excerpt |
|---|---|---|---|---|
| M1 | grow → new (brief) | `touched.length == 1` → `== -1` (main.dart:305) | D16, D18 | D16 `Expected: {'G1': Set:['3', '7', '12']} Actual: {'G2': Set:['12', '3', '7']}` |
| M2 | new → grow (the reverse) | `touched.length == 1`/`.single` → `isNotEmpty`/`.first` (:305-306) | D17 | `Expected: {'G4': Set:['7', '20'], 'G5': Set:['12', '3', '5', '11']} Actual: {'G1': Set:['12', '3'], 'G3': Set:['5', '11'], 'G4': Set:['7', '20']}` |
| M3 | numbering count+1 (brief) | `'G${max + BigInt.one}'` → `'G${ids.length + 1}'` (:283) | D17 | `Expected: {'G1': …, 'G3': Set:['5', '11'], 'G4': Set:['7', '20']} Actual: {'G1': Set:['12', '3'], 'G3': Set:['7', '20']}` |
| M4 | split keeps the status (brief) | drop `setGroupStatus(..remove(id))` in `_split` (:353) | D16, D19 | `Expected: empty Actual: {` (groupStatuses after Split) |
| M5 | status ignores selectedGroup (brief) | `final group = c.selectedGroup.value` → `final String? group = null` (:217) | D16, D17, D19 | D16 `Expected: {'G1': TableStatus:TableStatus(Color(alpha: 0.6000, red: 0.8980, …` ; D17 `Expected: equals ['G1', 'G3'] unordered Actual: _CompactKeysIterable<String>:[]` |
| M6 | onGroupTap not logged (brief) | drop the `onGroupTap:` argument (:435) | D16 | `Expected: ['Salon: group G1 tapped at 7', 'Salon: tapped 7', 'Salon: selected {12, 3, 7}'] Actual: ['Salon: tapped 7', 'Salon: selected {12, 3, 7}', 'Salon: Eating for {20}']` |
| M7 | R-C5-2 | `if (gone.any(...))` → `if (false)` (:342) | D17 | `Expected: empty Actual: {` (statuses of the emptied G1, G3) |
| M8 | grow keeps the label | drop `label: grown.label` (:312) | D18 | `Expected: {'G7': TableGroup({12, 3, 8, 9, 20}, Window)} Actual: {'G7': TableGroup({12, 3, 8, 9, 20}, null)}` |
| M9 | display order | members `..sort(byNumber)` → `..sort()` (:371) | D16, D17, D18 | `Expected: 'G1: 3+12' Actual: 'G1: 12+3'` |
| M10 | id from groups before the drop | `nextGroupId(groups.keys)` → `nextGroupId(next.keys)` after the drop (:317) | D17 | `Expected: {'G6': Set:['7', '20', '12', '3', '5', '11']} Actual: {'G1': Set:['12', '3', '7', '20', '5', '11']}` |
| M11 | grow keeps unselected members | `{...grown.members, ...numbers}` → `{...numbers}` (:312) | D18 | `Expected: {'G7': TableGroup({12, 3, 8, 9, 20}, Window)} Actual: {'G7': TableGroup({12, 3, 20}, Window)}` |

The "drag moves all members" check exercises planner behaviour (Task 2); there is no
demo code for it to mutate.

## Proposed rulings

- **R-C5-1 (grow rule):** the spec's "the numbers include all the selectable members of
  exactly one group" is implemented as "exactly one group has a member among the
  numbers". The host cannot see which members are selectable (layers' lock/visibility
  are not in the host API; `FloorPlanTable` carries no flag). The literal rule over the
  plan's numbers (`G.members ∩ planNumbers ⊆ numbers`) would be lock-blind: a group with
  a locked or hidden member could never grow (D18 would make a new G8 and leave G7 = {8, 9}).
  Equivalence: a selection made under the current groups always holds every selectable
  member of a group it touches (`_select` expands groups; a tap selects the whole group;
  a modifier removal removes all members' keys, R-C2-3), and Merge's requests are
  `selectedTables.value`. The two rules differ only for a *half-selected* group (selected
  before `setTableGroups` added the group), which the demo cannot produce (its groups
  only come from the selection itself). Cost if wrong: a POS that sets groups under a
  live selection and then merges could grow a group the staff only half selected; fix is
  a host API seam (see finding F-1) and a one-line rule change.
- **R-C5-2:** a merge that empties a group (its members all merged elsewhere) also
  removes that group's group status, as a split does. Without it the stale status would
  reattach to a later group reusing the id (ids restart from the max of the existing
  groups). Spec silent. Cost if wrong: one `setGroupStatus` call.
- **R-C5-3:** one log line for both outcomes, the spec's `Merged {numbers} as G<n>`
  (prefixed `<Area>: ` like every demo line); numbers and the groups line use a
  reading-order sort (`3` before `12`), while the existing `selected {…}` line keeps its
  plain string sort (unchanged). Cost if wrong: string edits.
- **R-C5-4:** a group left with members after a new-group merge keeps its id and label,
  even with a single member (e.g. a locked one). Cost if wrong: drop groups under 2.

## Findings, not fixed

- **F-1 (spec H9, API finding):** a host cannot apply G6's grow rule literally because
  it cannot ask which members of a group are selectable. A `selectableMembers(groupId)`
  (or a lock/visible flag on `FloorPlanTable`) would close it. Workaround in R-C5-1.

## For the reviewer

- R-C5-1: check the equivalence argument, especially whether any UI path yields a
  half-selected group in the selection mode.
- The callbacks bind the area the view was built for (`final a = area` in `build`), not
  `area` at call time.

## Gates

Run with `CI=true`, `--no-pub`, on the tree at `eecc823`'s content (log at
`scratchpad/tg-task5/gates.log`):

| Package | flutter test | analyze | format |
|---|---|---|---|
| apps/restaurant_demo | +22 (18 + D16..D19), all passed | No issues | 0 changed |
| jet_cad_floor_plan | +1278 (1276 + Task 4b's TB6, TB7), all passed | No issues | 0 changed |
| jet_cad_restaurant_symbols | +94 | No issues | 0 changed |
| apps/floor_planner | +201 | No issues | 0 changed |
| apps/dev_harness_2d | +82 | No issues | 0 changed |
| jet_cad_2d_flutter (render) | not run. The package was not edited, nothing it depends on changed, and the brief says "Render unchanged (not edited)". | — | — |

No standing failures were added or removed. D1..D15 and the dark-theme test pass with no edits.
