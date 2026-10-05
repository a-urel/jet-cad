# Task 1 report — selectableMembers and the demo's grow rule (X1, X2)

Status: done. Commit `d8d06ed`, "fix(table-groups): Task 1 — selectableMembers and the demo's literal grow rule" (not pushed).

## Files changed

- packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart (+16)
- packages/jet_cad_floor_plan/test/host/table_groups_controller_test.dart
- apps/restaurant_demo/lib/main.dart
- apps/restaurant_demo/test/demo_test.dart
- docs/superpowers/specs/2026-10-04-table-groups-design.md

The engine and render packages are not touched: `git diff` over
packages/jet_cad_2d and packages/jet_cad_2d_flutter is empty. No existing
expectation changed. The only removed line in demo_test.dart is the
`show` list of the import, which gains `FloorPlanView`.

## What was built

- `FloorPlanController.selectableMembers(String groupId) → Set<String>`
  (packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart):
  `Set.unmodifiable` of `t.number!` over the cached
  `_groupLookup.selectableMembers(groupId.trim())`. The number is already
  trimmed by `GroupTable`. An unknown id gives `const []` from the lookup,
  so the result is an empty set. It works in both modes and is fresh through
  `_groupLookup`'s three keys. The doc comment cites the fixes spec X1 and
  the parent spec's F-1.
- Demo `DemoHomeState.mergeGroups(groups, numbers, selectable)`
  (apps/restaurant_demo/lib/main.dart), X2's literal rule:
  - `whole` = the groups G with `selectable(G)` non-empty and
    `numbers ⊇ selectable(G)`.
  - If there is exactly one, `id` = G (grow). Otherwise `id` =
    `nextGroupId` (new group).
  - One loop over the groups: G is grown under its id and label. Every
    other group loses the requested numbers and is dropped when emptied.
    `putIfAbsent` adds the new group.
  - The no-op grow re-sets the same content and logs it.
  - `_merge` returns early on an empty request. It passes
    `c.selectableMembers` with `before = c.tableGroups.value`, read just
    before. An emptied group's status still goes through the existing
    `gone` set.
  - The doc comment is rewritten, and R-C5-1's text is removed.
- Parent spec `docs/superpowers/specs/2026-10-04-table-groups-design.md`,
  "Amended at execution": R-C5-1 is marked **Retired** and F-1
  **closed**. Both cite the fixes spec (X2, X1), with no SHA.

## Tests added

packages/jet_cad_floor_plan/test/host/table_groups_controller_test.dart
(the fixture `groupsPlanJson` gains `eightTwice` and `lockFive`, both
defaulting to false, so existing callers are unchanged):
- TG-C13 selectableMembers gives the visible, unlocked members' numbers, in both modes; a group of only a locked and a hidden member gives none; the set is unmodifiable (M-TGF-1)
- TG-C14 selectableMembers trims the id; an unknown id gives the empty set (M-TGF-2)
- TG-C15 a number carried by an unlocked and a locked table is selectable, whichever comes first in handle order (M-TGF-3)
- TG-C16 selectableMembers is fresh after setTableGroups with the same id, after a design layer was locked and the mode switched, and after a layer edit that made no command (M-TGF-10)

apps/restaurant_demo/test/demo_test.dart (it now also imports
`FloorPlanView`):
- D21 X2, M-TGF-4: groups set under a live selection that holds part of a group make a new group, not a grown one
- D22 X2, M-TGF-6: a group with no selectable member never grows
- D23 X2, M-TGF-7: a grow takes a number from another group, which keeps its id, label and group status
- D24 X2 edge cases from a host: a request of exactly one group's selectable members is a logged no-op grow; an empty request changes nothing. It calls the demo's `FloorPlanView.onMergeRequested` directly, the host path.
- M-TGF-5 is D18, which is cited, not duplicated, and re-fired below.

## Mutant table

Every mutant was applied by a scratch edit and the named test file was run.
The backup was then `cp`'d back, and `diff` exited 0 ("RESTORED OK") for
every mutant. Outputs are in the scratch directory as `<name>.out` and
`<name>.diff`.

Controller: packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart,
run with `flutter test test/host/table_groups_controller_test.dart`.

| Mutant | Site | Change | Red | Excerpt |
|---|---|---|---|---|
| M-TGF-1a | :269-272 | `selectableMembers` → `visibleMembers` (keeps the locked member) | TG-C13, TG-C14, TG-C16 | `Expected: Set:['12', '3']  Actual: Set:['12', '3', '8']` |
| M-TGF-1b | :269-272 | the group's raw members | TG-C13, TG-C14, TG-C16 | `Actual: Set:['12', '3', '8', '9']` |
| M-TGF-2 | :270 | `groupId` not trimmed | TG-C14 | `Expected: Set:['12', '3']  Actual: Set:[]` |
| M-TGF-3a | :269-272 | each number decided by its first visible table | TG-C15 (lockFive: true) | `Expected: Set:['12', '3', '8']  Actual: Set:['12', '3']` |
| M-TGF-3b | :269-272 | a number counts only when every table carrying it is selectable | TG-C15 | `Actual: Set:['12', '3']` |
| M-TGF-10a | :269 | memo keyed by the id only | TG-C16 | `Expected: Set:['20', '12', '5']  Actual: Set:['12', '3', '7']` |
| M-TGF-10b | :579-580 | `_groupLookup` keyed by the survey only | TG-C9, TG-C12, TG-C16 | TG-C16: `Actual: Set:['12', '3', '7']` |
| M-TGF-10c (extra) | :579-580 | the layer revision key dropped | TG-C12, TG-C16 | TG-C16: `Expected: Set:['20', '12', '5']  Actual: Set:[]` |
| M-TGF-10d (extra) | :269 | memo keyed by (id, groups), not by survey or layers | TG-C16 | `Expected: empty  Actual: Set:['12', '20', '5']` |

Demo: apps/restaurant_demo/lib/main.dart, run with
`flutter test test/demo_test.dart`.

| Mutant | Site | Change | Red | Excerpt |
|---|---|---|---|---|
| R-C5-1 (M-TGF-4) | :308-311 | `whole` = the groups touched (`members.any(numbers.contains)`) | D21, D23 | D21: `Actual: {'G7': TableGroup:TableGroup({12, 3, 7, 20}, null)}` |
| M-TGF-6 vacuous | :310 | `s.isNotEmpty &&` dropped | D22 | `Actual: {'G9': TableGroup:TableGroup({8, 9, 20, 5}, Back)}` |
| M-TGF-5 never grow | :313 | `id = nextGroupId(...)` always | D16, D18, D23, D24 | D18: `Expected: {'G7': TableGroup:TableGroup({12, 3, 8, 9, 20}, Window)}` `Actual: {'G7': ...({8, 9}, Window), 'G8': ...({12, 3, 20}, null)}` |
| M-TGF-5 all members incl. locked | :310 | `numbers.containsAll(groups[id]!.members)` | D18, D20, D24 | D18: `Actual: {'G7': ...({8, 9}, Window), 'G8': ...({12, 3, 20}, null)}` |
| M-TGF-5 drops label (grow) | :319 | `label:` dropped | D18, D24 | `Actual: {'G7': TableGroup:TableGroup({12, 3, 8, 9, 20}, null)}` |
| M-TGF-7 keep 5 | :316 | on a grow, other groups keep the requested numbers | D23 | `Actual: ArgumentError:<Invalid argument (groups): Table number "5" is in two groups, "G7" and ...` |
| M-TGF-7 drops label (remainder) | :323 | `label:` dropped | D20, D23 | D23: `Actual: {'G7': TableGroup:TableGroup({12, 3, 5}, null), 'G1': TableGroup:TableGroup({11}, null)}` |
| M-TGF-7 loses status | :341 | `gone` = changed groups, not removed ones | D23 | `Actual: {}  Which: has different length and is missing map key 'G1'` |
| X2 no-op grow (extra) | :310 | strict superset required | D24 | `Actual: {'G7': ...({8, 9}, Window), 'G2': ..., 'G8': ...({3, 12}, null)}` |
| X2 empty request (extra) | :334 | early return removed | D24 | `Invalid argument (groups): Group "G8" has no member: "G8"` |

## Gates (Flutter 3.47.6, `CI=true`, real output tails)

| Package | test | analyze | format |
|---|---|---|---|
| packages/jet_cad_floor_plan | `07:06 +1282: All tests passed!` (branch point +1278, plus 4) | No issues found! | 208 files, 0 changed |
| apps/restaurant_demo | `00:31 +28: All tests passed!` (+24, plus 4) | No issues found! | 3 files, 0 changed |
| apps/floor_planner | `02:53 +201: All tests passed!` | No issues found! | 44 files, 0 changed |
| packages/jet_cad_restaurant_symbols | `00:03 +94: All tests passed!` | No issues found! | 13 files, 0 changed |
| apps/dev_harness_2d | `01:01 +82: All tests passed!` | No issues found! | 22 files, 0 changed |
| packages/jet_cad_2d_flutter | `01:58 +1304 ~1 -7: Some tests failed.` (standing: the text ladder goldens, as at the branch point) | No issues found! | 218 files, 0 changed |

## Proposed rulings

- **R-C1-1 — M-TGF-3 is run over both handle orders.** The spec's fixture
  renames table 5 to "8". In the controller fixture, table 5's handle
  precedes the locked 8's, so the unlocked carrier comes first. A mutant
  that "decides by the first table" would then survive (M-TGF-3a passes on
  `lockFive: false`).
  - TG-C15 therefore loops over `lockFive: false` (the spec's literal
    variant) and `lockFive: true`. In the second, table 5's table is the
    locked one and the original 8 is unlocked on layer 0, so the locked
    carrier comes first.
  - M-TGF-3a goes red on `lockFive: true`.
  - Cost if wrong: one extra loop iteration and a fixture flag; nothing is
    removed from the spec's literal case.
- **R-C1-2 — the empty request is guarded in `_merge`, not in
  `mergeGroups`.** `mergeGroups` keeps its non-null `id` record, and its
  doc states that `numbers` are not empty. D24 reaches `_merge` through the
  demo's `FloorPlanView.onMergeRequested`, the host path, and kills the
  removed guard.
  - Cost if wrong: a direct caller of the static `mergeGroups` with an empty
    set gets a group with no member, which `setTableGroups` refuses with an
    `ArgumentError`.

## Found, not fixed

- Nothing new. STATUS.md still names R-C5-1 as current; that update is
  Task 3's.

## Where the reviewer should look hardest

- `mergeGroups`' unified loop (main.dart:313-327). `id` is either the grown
  group or a fresh `nextGroupId`, which cannot collide with an existing key.
  The grown group keeps its map position; a new one is appended by
  `putIfAbsent`. Check that the old new-group path is unchanged, which
  D17, D19 and D20 pin.
- TG-C16's raw layer edits (`layers.remove` / `layers.add(copyWith(locked:))`)
  on layer 0, in the design and then in the service copy. They follow
  TG-C12's existing pattern.
- `selectableMembers` allocates a fresh unmodifiable set per call. It is
  host-only, so it is not on the frame path.
