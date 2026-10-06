# Task 1 report — the model and the controller (G1, G2, G4 selection, G5 rule)

Implementer, 2026-10-04, on `claude/dreamy-gates-2kgh4o` from `eed5856`.

## Commits

- `638048b` feat(table-groups): Task 1 — TableGroup, group rules and controller groups (not pushed)

## Files changed

- `packages/jet_cad_floor_plan/lib/src/host/floor_plan_types.dart` — `TableGroup`.
- `packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart` — exports `TableGroup`
  (a second `export 'src/host/floor_plan_types.dart' show TableGroup;` line, see N-1).
- `packages/jet_cad_floor_plan/lib/src/service/table_groups.dart` — **new**.
- `packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart` — groups,
  group statuses, `selectedGroup`, the `_select` expansion, disposal.
- `packages/jet_cad_floor_plan/test/host/barrel_test.dart` — B1 gains `'TableGroup'`
  (mechanical, one line).
- `packages/jet_cad_floor_plan/test/service/table_groups_test.dart` — **new**, 15 tests.
- `packages/jet_cad_floor_plan/test/host/table_groups_controller_test.dart` — **new**, 12 tests.

No other file touched. Engine and render package not edited.

## What was built

**`TableGroup`** (`floor_plan_types.dart`, pattern of `TableStatus`): `@immutable final
class`, `TableGroup({required Set<String> members, String? label})`. Members trimmed, blank
ones dropped, stored as `Set.unmodifiable` (insertion order kept). Label trimmed, blank or
empty → null, then cut to `maxLabel = 24` grapheme clusters via `characters`. Equality:
`setEquals(members)` + label; `hashCode` uses `Object.hashAllUnordered(members)`.

**`service/table_groups.dart`** (no Flutter import of its own; see R-C1-1):
- `validateTableGroups(Map<String, TableGroup>)` → unmodifiable map, ids trimmed, input
  order kept. `ArgumentError` for: blank id; ids colliding after trim; empty members (after
  `TableGroup`'s trim); a number in two groups — message `Table number "5" is in two groups,
  "G4" and "G5"`. All checks run before the map is returned.
- `groupIdsByNumber(groups)` → number → id.
- `GroupTable({handle, number, visible, locked})` — the per-table facts; `selectable =
  visible && !locked`. Keys are engine `Handle`s (the tool wraps them in
  `SelectionKey.root` in Task 2).
- `TableGroupLookup(groups, tables)` — precomputed at construction: `groupOf(number)`
  (trimmed), `visibleMembers(id)` (visible incl. locked, ascending handle, every table with a
  member number — duplicates included), `selectableMembers(id)`, `hasLockedVisibleMember(id)`
  (a locked member on a hidden layer does not count), `splitGroup(selectedNumbers,
  {required bool unnumberedSelected})` — the Split rule.
- `mergeQualifies(selectedNumbers, groups)` — the Merge rule (≥ 2 units; unit = group id or
  ungrouped number; blank numbers ignored).
- `tableNumberOrder(numbers)` — the lead comparator: numeric when every number is
  `^[0-9]+$` (stripped-of-leading-zeros length, then stripped string, then the original
  string so `'07'` and `'7'` order totally), never `int.parse`; else `String.compareTo`.
- `inLeadOrder(members)` — numbered members by that order, ties to the lowest handle.

**`FloorPlanController`:**
- `setTableGroups(groups)`: `validateTableGroups` first (throw → nothing assigned, no
  notifier touched), then `_groups.value = valid`, then `selectedGroup` recomputed.
- `tableGroups`, `setGroupStatus(statuses)` (keys trimmed, orphans kept, never pruned by a
  groups change), `groupStatuses`, `selectedGroup`.
- `_select` now iterates `_expandGroups(numbers)`: in the selection mode, a number in a group
  is replaced by all the group's member numbers; the existing live / visible / unlocked
  filter is unchanged and applies to every expanded number. Design mode: `numbers` as given
  (no change at all when there are no groups — the same set object is returned).
- `selectedGroup` is recomputed at the end of every `_refreshSelected` (selection listener,
  every document change via `_refreshFlags`, `setMode`, `resetLayout`, `load`) and by
  `setTableGroups`. It uses the active plan's survey (`_tables`) and layer flags; it is
  null in the design mode (R-C1-2) and when there are no groups.
- A cached `TableGroupLookup`, rebuilt when the survey identity, the groups map identity or
  the active document's `tables.mutationRevision` moves (a raw layer edit makes no command).
- Groups and group statuses are fields of the controller like `_statuses`: `setMode`,
  `resetLayout`, `load` and `newPlan` do not touch them. The three new notifiers are disposed.

## Tests added

`test/service/table_groups_test.dart` (pure, fixtures: handles given out of order, `G7 =
{12, 3, 7}`, a file duplicate `5` on two handles, a locked `8`, a hidden `9`, a hidden-and-
locked `10`, an unnumbered table):
- TG-U1 members trimmed, blank dropped, unmodifiable (M-TG-2, M-C1-14)
- TG-U2 label trimmed, blank → none, cut to 24 grapheme clusters (family emoji) (M-C1-1, M-C1-2)
- TG-U3 equality by value, set equality, hash (M-C1-3)
- TG-U4 ids trimmed, order kept, unmodifiable (M-TG-2, M-C1-13)
- TG-U5 overlap throws naming number and both ids, `'5'` vs `' 5 '` (M-TG-1)
- TG-U6 blank id, colliding ids, empty members after trim throw (G2)
- TG-U7 number → group, trimmed; unknown member number kept (G2, M-C1-12)
- TG-U8 visible members ascending by handle, duplicate both, locked counts, hidden not (M-C1-4, M-C1-5)
- TG-U9 selectable drops locked; locked-but-hidden is not "locked visible" (M-C1-6, M-C1-7)
- TG-U10 Merge disabled: one table, two unnumbered, duplicate number, one whole group, part of one (M-TG-16)
- TG-U11 Merge enabled: two numbered, group + table, two groups (M-TG-16)
- TG-U12 Split: exact selectable members, locked-member group, single-visible-member group (M-TG-17)
- TG-U13 Split null: group+table, part, group+unnumbered, empty, ungrouped, incl. locked number (M-TG-17)
- TG-U14 lead order: `{12,3,7}` → `3,7,12`; leading zeros; `07`/`7`; 30-digit number; `5A` and `-7` → string order (M-C1-8, -9, -10)
- TG-U15 `inLeadOrder`: duplicate → lowest handle, unnumbered dropped (M-C1-11)

`test/host/table_groups_controller_test.dart` (plan: tables numbered `12, 3, 7, 20, 5, 8,
9` in handle order, all off the origin, turned by multiples of 37° and/or mirrored; `8` on a
visible locked layer; `9` on a hidden layer; an unnumbered table; variants: `5` renamed `3`
(file duplicate), `9` left on layer 0):
- TG-C1 overlap throws (`'5'` vs `' 5 '`), old map kept (`same`), no listener of
  `tableGroups` or `selectedGroup` notified (counters) (M-TG-1)
- TG-C2 blank id, `'  '`, `'G1'`/`' G1 '`, empty members after trim: each throws, old map
  kept, no notification (G2)
- TG-C3 `' G1 '` / `' 5 '` resolve as `G1` / `5`; group status keys trimmed (M-TG-2)
- TG-C4 orphan group status kept across `setTableGroups`; no revision/dirty/undo/json change (G2)
- TG-C5 selection mode: `select({'3'})` (via setMode) and `select({'12','20'})` expand; design
  mode: not expanded (M-TG-9)
- TG-C6 expansion with a file duplicate selects 4 keys (M-TG-9)
- TG-C7 G7 = {12,3,7,8,9}: `select({'3'})` and `select({'8'})` give `{3,7,12}` (M-TG-9b)
- TG-C8 `selectedGroup` (raw `activeSelection.replace`): G7 with locked third member
  qualifies; group+table, part, group+unnumbered, ungrouped → null; single visible member
  group qualifies (M-TG-17, Split half)
- TG-C9 selection `{3,20}` unchanged, `setTableGroups` flips `selectedGroup` to `G2`, then
  null, then `G2`; design mode → null; listener sequence `[G2, null, G2, null]`
  (M-TG-17b, M-C1-15)
- TG-C10 `designJson()` and the service copy byte-identical with groups, a labelled group
  and a group status set (M-TG-19, invariant check, not counted)
- TG-C11 groups and group statuses (`same`) survive setMode round trip, `resetLayout`, `load`
  of the same plan, and still expand / give `selectedGroup` after each (M-TG-20)
- TG-C12 `selectedGroup` after a load of another plan (9 visible) and after a raw layer-table
  edit (no command) (M-C1-16, M-C1-17)

## Gate results

Commands per package: `CI=true flutter test`, `CI=true flutter analyze`,
`CI=true dart format --output=none --set-exit-if-changed .` (logs `tg-task1/gate-*.log`).

| Package | Test (real summary line) | Branch point | Analyze | Format |
|---|---|---|---|---|
| render `jet_cad_2d_flutter` (not edited) | `01:16 +1304 ~1 -7: Some tests failed.` — the 7 `text_ladder_golden_test.dart` rungs | +1304 ~1 -7 | No issues found | exit 0 |
| planner `jet_cad_floor_plan` | `03:37 +1240: All tests passed!` | +1213 (+27 new: 15 unit, 12 controller) | No issues found | exit 0 |
| `jet_cad_restaurant_symbols` | `00:02 +94: All tests passed!` | +94 | No issues found | exit 0 |
| `apps/floor_planner` | `01:27 +201: All tests passed!` | +201 | No issues found | exit 0 |
| `apps/restaurant_demo` | `00:10 +18: All tests passed!` | +18 | No issues found | exit 0 |
| `apps/dev_harness_2d` | `00:34 +82: All tests passed!` | +82 | No issues found | exit 0 |

The standing failures are the same set (render's 7 text-ladder goldens, 1 skip). Engine not run
(not edited; run at the exit per the plan). `analysis_options.yaml` not staged (not modified in
this checkout).

## Mutant table

Each: `cp` to scratch backup, python exact-string replace (count must be 1), run the named
test file(s), `cp` back, `diff` exit 0 ("restored ok" in every run). Output excerpts are the
real `[E]` lines from the runs (logs in the scratch dir `tg-task1/<name>.out`).
U = `test/service/table_groups_test.dart`, C = `test/host/table_groups_controller_test.dart`.

| Mutant | Site | Change | Red (real `[E]` lines) |
|---|---|---|---|
| M-TG-1a overlap accepted | `table_groups.dart:37` | `if (other != null)` → `&& false` | TG-U5, TG-C1 |
| M-TG-1b assigned before validation (notifies on throw) | `floor_plan_controller.dart:227` | `_groups.value = Map.unmodifiable(groups);` inserted before `validateTableGroups` | TG-C1, TG-C2 |
| M-TG-2a ids untrimmed | `table_groups.dart:24` | `raw.trim()` → `raw` | TG-U4, TG-U6, TG-C2, TG-C3 |
| M-TG-2b members untrimmed | `floor_plan_types.dart:104` | `m.trim()` → `m` (kept blank filter) | TG-U1, TG-U3, TG-U5, TG-C1, TG-C3 |
| M-TG-2c group status ids untrimmed | `floor_plan_controller.dart:243` | `e.key.trim()` → `e.key` in `setGroupStatus` | TG-C3 |
| M-G2-blank blank id accepted | `table_groups.dart:25` | `if (id.isEmpty)` → `&& false` | TG-U6, TG-C2 |
| M-G2-collide colliding ids accepted (last wins) | `table_groups.dart:28` | `if (out.containsKey(id))` → `&& false` | TG-U6, TG-C2 |
| M-G2-empty empty group accepted | `table_groups.dart:32` | `if (group.members.isEmpty)` → `&& false` | TG-U6, TG-C2 |
| M-G2-orphan orphan statuses pruned | `floor_plan_controller.dart:228` | after `_groups.value = valid;` prune `_groupStatuses` to ids in `valid` | TG-C4 |
| M-TG-9 `select` not expanded | `floor_plan_controller.dart:515` | `_expandGroups(numbers)` → `numbers` | TG-C1, C3, C5, C6, C7, C11, C12 (+3 more) |
| M-TG-9-mode expanded in design mode | `floor_plan_controller.dart:532` | `_mode.value != selection \|\| groups.isEmpty` → `groups.isEmpty` | TG-C5 |
| M-TG-9b expansion unfiltered | `floor_plan_controller.dart:520` | filter `continue` only when `numbers.contains(n)` (expanded members bypass it) | TG-C7, TG-C12 |
| M-TG-17 (unnumbered ignored, rule) | `table_groups.dart:150` | drop `unnumberedSelected \|\|` | TG-U13, TG-C8 |
| M-TG-17 (visible, not selectable) | `table_groups.dart:155` | `selectableMembers(id)` → `visibleMembers(id)` | TG-U12, TG-U13, TG-C7, TG-C8 |
| M-TG-17 (subset accepted: part of a group) | `table_groups.dart:158` | condition → `!numbers.containsAll(selected)` | TG-U13, TG-C8, TG-C9 |
| M-TG-17 (superset accepted: group + table) | `table_groups.dart:158` | condition → `!selected.containsAll(numbers)` | TG-U13, TG-C8 |
| M-TG-17 (controller never sees an unnumbered table) | `floor_plan_controller.dart:599` | `unnumberedSelected: unnumbered` → `false && unnumbered` | TG-C8 |
| M-TG-17b flags stale on `setTableGroups` | `floor_plan_controller.dart:229` | `_refreshSelectedGroup();` removed from `setTableGroups` | TG-C9 |
| M-TG-17-design `selectedGroup` in design mode (R-C1-2) | `floor_plan_controller.dart:594` | drop `_mode.value == selection &&` | TG-C9 |
| M-TG-16 units by number, not group | `table_groups.dart:177` | `units.add((false, n))` | TG-U10 |
| M-TG-16 threshold one unit | `table_groups.dart:178` | `>= 2` → `>= 1` | TG-U10 |
| M-TG-16 grouped numbers count for nothing | `table_groups.dart:177` | `if (id == null) units.add((false, n))` | TG-U11 |
| M-TG-16 blank numbers counted | `table_groups.dart:175` | `if (n.isEmpty) continue;` → `&& false` | TG-U10 |
| M-TG-20 groups cleared on `setMode` | `floor_plan_controller.dart:409` | `_groups.value = const {};` after `_mode.value = next;` | TG-C5, TG-C11 |
| M-TG-20 group statuses cleared on `setMode` | `floor_plan_controller.dart:409` | `_groupStatuses.value = const {};` there | TG-C11 |
| M-TG-20 cleared on `resetLayout` | `floor_plan_controller.dart:424` | both cleared after `_drop(service);` | TG-C11 |
| M-TG-20 cleared on `load` | `floor_plan_controller.dart:384` | both cleared in `_replaceDesign` | TG-C11, TG-C12 |
| M-C1-1 label untrimmed | `floor_plan_types.dart:106` | `label?.trim()` → `label` | TG-U2, TG-U3 |
| M-C1-2 label cut by code units | `floor_plan_types.dart:108` | `characters.take(24)` → `substring(0, min(len, 24))` | TG-U2 |
| M-C1-3a ordered member equality | `floor_plan_types.dart:125` | `setEquals` → `join() ==` | TG-U3 |
| M-C1-3b ordered hash | `floor_plan_types.dart:128` | `hashAllUnordered` → `hashAll` | TG-U3 |
| M-C1-4 members not sorted by handle | `table_groups.dart:93` | `..sort(...)` removed | TG-U8, TG-U9 |
| M-C1-5 hidden members counted | `table_groups.dart:97` | drop `\|\| !t.visible` | TG-U8, TG-U9 |
| M-C1-6 locked counted selectable | `table_groups.dart:77` | `visible && !locked` → `visible` | TG-U9, U12, U13, TG-C7, TG-C8 |
| M-C1-7 any member counts as locked | `table_groups.dart:112` | `list.any((t) => t.locked)` → `list.isNotEmpty` | TG-U9 |
| M-C1-8 lead never numeric | `table_groups.dart:188` | `if (... every(_digits ...))` → `if (false)` | TG-U14, TG-U15 |
| M-C1-9 leading zeros kept | `table_groups.dart:199` | `_stripZeros(a/b)` → `a/b` | TG-U14 |
| M-C1-10a `int.parse` | `table_groups.dart:200` | `byLength = int.parse(a).compareTo(int.parse(b))` | TG-U14 |
| M-C1-10b "all digits" as "has a digit" | `table_groups.dart:194` | `^[0-9]+$` → `[0-9]` | TG-U14 |
| M-C1-11 ties to the highest handle | `table_groups.dart:227` | `a.handle…compareTo(b…)` → `b…compareTo(a…)` | TG-U15 |
| M-C1-12 `groupOf` untrimmed | `table_groups.dart:128` | `number.trim()` → `number` | TG-U7, TG-U12 |
| M-C1-13 validated map modifiable | `table_groups.dart:45` | `Map.unmodifiable(out)` → `out` | TG-U4 |
| M-C1-14 members modifiable | `floor_plan_types.dart:102` | `Set.unmodifiable(` → `(` | TG-U1 |
| M-C1-15 lookup cache ignores the groups | `floor_plan_controller.dart:559` | `!identical(_lookupGroups, groups) \|\|` removed | TG-C9 |
| M-C1-16 lookup cache ignores the survey | `floor_plan_controller.dart:558` | `!identical(_lookupSurvey, survey) \|\|` removed | TG-C12 |
| M-C1-17 lookup cache ignores layer edits | `floor_plan_controller.dart:560` | `_lookupLayers != layersRevision` → `false` | TG-C12 |

46 mutants fired, 46 killed, 0 survivors. Lines are of the committed files. Test names
gained their mutant tags (M-C1-12..17) after the runs; only the name strings changed.

Real excerpts (first `[E]` line and the summary line of each run, cut at 140 columns):

```
M-TG-1a: 00:00 +4 -1: test/service/table_groups_test.dart: validateTableGroups (G2) TG-U5 a number in two groups throws, naming it and both ids, trim
    00:01 +25 -2: Some tests failed.
M-TG-1b: 00:00 +15 -1: test/host/table_groups_controller_test.dart: TG-C1 an overlap throws, trimmed numbers included, keeping the old groups and not
    00:01 +25 -2: Some tests failed.
M-TG-2a: 00:00 +3 -1: test/service/table_groups_test.dart: validateTableGroups (G2) TG-U4 ids are trimmed, in the given order, and the map is unmodif
    00:00 +23 -4: Some tests failed.
M-TG-2b: 00:00 +0 -1: test/service/table_groups_test.dart: TableGroup (G1, G2) TG-U1 members are trimmed, a blank one dropped, and the set is unmodif
    00:00 +22 -5: Some tests failed.
M-TG-2c: 00:00 +17 -1: test/host/table_groups_controller_test.dart: TG-C3 ids and numbers are trimmed: " G1 " and " 5 " are G1 and 5, for the groups 
    00:00 +26 -1: Some tests failed.
M-G2-blank: 00:00 +5 -1: test/service/table_groups_test.dart: validateTableGroups (G2) TG-U6 a blank id, two ids the same after trimming, and a group wi
    00:00 +25 -2: Some tests failed.
M-G2-collide: 00:00 +5 -1: test/service/table_groups_test.dart: validateTableGroups (G2) TG-U6 a blank id, two ids the same after trimming, and a group wi
    00:01 +25 -2: Some tests failed.
M-G2-empty: 00:00 +5 -1: test/service/table_groups_test.dart: validateTableGroups (G2) TG-U6 a blank id, two ids the same after trimming, and a group wi
    00:00 +25 -2: Some tests failed.
M-G2-orphan: 00:00 +18 -1: test/host/table_groups_controller_test.dart: TG-C4 a group status with no group is kept, and a groups change leaves the status
    00:00 +26 -1: Some tests failed.
M-TG-9: 00:00 +15 -1: test/host/table_groups_controller_test.dart: TG-C1 an overlap throws, trimmed numbers included, keeping the old groups and not
    00:00 +20 -7: Some tests failed.
M-TG-9-mode: 00:00 +19 -1: test/host/table_groups_controller_test.dart: TG-C5 in the selection mode a number selects its whole group; in the design mode 
    00:00 +26 -1: Some tests failed.
M-TG-9b: 00:00 +21 -1: test/host/table_groups_controller_test.dart: TG-C7 the expansion never selects a member on a locked or a hidden layer (M-TG-9b
    00:01 +25 -2: Some tests failed.
M-TG-17-unnumbered: 00:00 +12 -1: test/service/table_groups_test.dart: the Split rule (G5) TG-U13 a group plus a table, part of a group, a group plus an unnumbe
    00:00 +25 -2: Some tests failed.
M-TG-17-visible: 00:00 +11 -1: test/service/table_groups_test.dart: the Split rule (G5) TG-U12 exactly one group's selectable members qualify, a group with a
    00:01 +23 -4: Some tests failed.
M-TG-17-subset: 00:00 +12 -1: test/service/table_groups_test.dart: the Split rule (G5) TG-U13 a group plus a table, part of a group, a group plus an unnumbe
    00:01 +24 -3: Some tests failed.
M-TG-17-superset: 00:00 +12 -1: test/service/table_groups_test.dart: the Split rule (G5) TG-U13 a group plus a table, part of a group, a group plus an unnumbe
    00:00 +25 -2: Some tests failed.
M-TG-17-ctl-unnumbered: 00:00 +22 -1: test/host/table_groups_controller_test.dart: TG-C8 selectedGroup: exactly one group's selectable members, a locked third membe
    00:01 +26 -1: Some tests failed.
M-TG-17b: 00:00 +23 -1: test/host/table_groups_controller_test.dart: TG-C9 selectedGroup follows the groups with the selection unchanged, and is null 
    00:00 +26 -1: Some tests failed.
M-TG-17-design: 00:00 +23 -1: test/host/table_groups_controller_test.dart: TG-C9 selectedGroup follows the groups with the selection unchanged, and is null 
    00:00 +26 -1: Some tests failed.
M-TG-16-bynumber: 00:00 +9 -1: the Merge rule (G5) TG-U10 disabled for one table, two unnumbered tables, two tables sharing one number, one whole group and pa
    00:00 +14 -1: Some tests failed.
M-TG-16-one: 00:00 +9 -1: the Merge rule (G5) TG-U10 disabled for one table, two unnumbered tables, two tables sharing one number, one whole group and pa
    00:00 +14 -1: Some tests failed.
M-TG-16-nogroup: 00:00 +10 -1: the Merge rule (G5) TG-U11 enabled for two numbered tables, a group and a table, two groups (M-TG-16) [E]
    00:00 +14 -1: Some tests failed.
M-TG-16-blank: 00:00 +9 -1: the Merge rule (G5) TG-U10 disabled for one table, two unnumbered tables, two tables sharing one number, one whole group and pa
    00:00 +14 -1: Some tests failed.
M-TG-20-mode: 00:03 +19 -1: test/host/table_groups_controller_test.dart: TG-C5 in the selection mode a number selects its whole group; in the design mode 
    00:03 +25 -2: Some tests failed.
M-TG-20-modestatus: 00:00 +25 -1: test/host/table_groups_controller_test.dart: TG-C11 groups and group statuses survive a mode round trip, resetLayout and a loa
    00:00 +26 -1: Some tests failed.
M-TG-20-reset: 00:00 +25 -1: test/host/table_groups_controller_test.dart: TG-C11 groups and group statuses survive a mode round trip, resetLayout and a loa
    00:00 +26 -1: Some tests failed.
M-TG-20-load: 00:00 +25 -1: test/host/table_groups_controller_test.dart: TG-C11 groups and group statuses survive a mode round trip, resetLayout and a loa
    00:00 +25 -2: Some tests failed.
M-C1-15: 00:00 +8 -1: TG-C9 selectedGroup follows the groups with the selection unchanged, and is null in the design mode (M-TG-17b) [E]
    00:00 +11 -1: Some tests failed.
M-C1-16: 00:00 +11 -1: TG-C12 selectedGroup reads the active plan as it is: after a load of another plan, and after a layer edit that made no command
    00:00 +11 -1: Some tests failed.
M-C1-17: 00:00 +11 -1: TG-C12 selectedGroup reads the active plan as it is: after a load of another plan, and after a layer edit that made no command
    00:00 +11 -1: Some tests failed.
M-C1-1: 00:00 +1 -1: TableGroup (G1, G2) TG-U2 the label is trimmed, a blank one is none, and it is cut to 24 characters, counted as grapheme cluste
    00:00 +13 -2: Some tests failed.
M-C1-2: 00:00 +1 -1: TableGroup (G1, G2) TG-U2 the label is trimmed, a blank one is none, and it is cut to 24 characters, counted as grapheme cluste
    00:00 +14 -1: Some tests failed.
M-C1-3a: 00:00 +2 -1: TableGroup (G1, G2) TG-U3 equality is by value: the members as a set, the label (M-C1-3) [E]
    00:00 +14 -1: Some tests failed.
M-C1-3b: 00:00 +2 -1: TableGroup (G1, G2) TG-U3 equality is by value: the members as a set, the label (M-C1-3) [E]
    00:00 +14 -1: Some tests failed.
M-C1-14: 00:00 +0 -1: TableGroup (G1, G2) TG-U1 members are trimmed, a blank one dropped, and the set is unmodifiable (M-TG-2) [E]
    00:00 +14 -1: Some tests failed.
M-C1-4: 00:00 +7 -1: TableGroupLookup (G2, G4) TG-U8 visible members ascending by handle: a duplicate gives both, a locked one counts, a hidden one 
    00:00 +13 -2: Some tests failed.
M-C1-5: 00:00 +7 -1: test/service/table_groups_test.dart: TableGroupLookup (G2, G4) TG-U8 visible members ascending by handle: a duplicate gives bot
    00:03 +25 -2: Some tests failed.
M-C1-6: 00:00 +8 -1: test/service/table_groups_test.dart: TableGroupLookup (G2, G4) TG-U9 selectable members drop the locked one; a locked member co
    00:00 +22 -5: Some tests failed.
M-C1-7: 00:00 +8 -1: TableGroupLookup (G2, G4) TG-U9 selectable members drop the locked one; a locked member counts as locked only on a visible laye
    00:00 +14 -1: Some tests failed.
M-C1-8: 00:00 +13 -1: the lead order (G3) TG-U14 all digits sort numerically by (length after leading zeros, then string), never int.parse; otherwis
    00:00 +13 -2: Some tests failed.
M-C1-9: 00:00 +13 -1: the lead order (G3) TG-U14 all digits sort numerically by (length after leading zeros, then string), never int.parse; otherwis
    00:00 +14 -1: Some tests failed.
M-C1-10a: 00:00 +13 -1: the lead order (G3) TG-U14 all digits sort numerically by (length after leading zeros, then string), never int.parse; otherwis
    00:00 +14 -1: Some tests failed.
M-C1-10b: 00:00 +13 -1: the lead order (G3) TG-U14 all digits sort numerically by (length after leading zeros, then string), never int.parse; otherwis
    00:00 +14 -1: Some tests failed.
M-C1-11: 00:00 +14 -1: the lead order (G3) TG-U15 inLeadOrder: by number, a duplicate to the lowest handle, an unnumbered table dropped (M-C1-11) [E]
    00:00 +14 -1: Some tests failed.
M-C1-12: 00:00 +6 -1: test/service/table_groups_test.dart: TableGroupLookup (G2, G4) TG-U7 a number resolves to its group, trimmed; an unknown member
    00:03 +25 -2: Some tests failed.
M-C1-13: 00:00 +3 -1: test/service/table_groups_test.dart: validateTableGroups (G2) TG-U4 ids are trimmed, in the given order, and the map is unmodif
    00:00 +26 -1: Some tests failed.
```


M-TG-19 (invariant, not counted): TG-C10 green — `designJson()` and the service copy's
encoding are byte-identical with groups and group statuses set.

## Proposed rulings

- **R-C1-1 — "Flutter-free" `table_groups.dart` imports `TableGroup` from the host types.**
  The file has no Flutter import of its own, but `floor_plan_types.dart` imports
  `flutter/foundation` and `flutter/widgets` (for `Color`, `@immutable`, `characters`), so it
  is Flutter-dependent transitively. The alternative (a Flutter-free mirror type or a generic
  members accessor) costs an extra type for no consumer: every consumer (tool, painters,
  toolbar) is Flutter code. Cost if wrong: small — split `TableGroup` into a Dart-only file
  re-exported by the types file.
- **R-C1-2 — `selectedGroup` is null in the design mode.** The spec defines it by G5's Split
  rule but does not say what it reads in the design mode; G4 says "Groups do not exist in the
  design mode", and expansion is selection-mode only, so a design-mode selection of exactly a
  group's tables reads null. Cost if wrong: small — drop the mode check in
  `_refreshSelectedGroup` (one line, TG-C9's last two expectations flip).
- **R-C1-3 — Numeric lead ties broken by the original string.** "(length after stripping
  leading zeros, then string)": I compare the stripped string, then the original string, so
  `'07'` < `'7'` deterministically (only then the handle). Cost if wrong: nil in practice —
  it only decides where the caption sits for numbers that differ only by leading zeros.

## Notes

- **N-1 (barrel).** Adding `TableGroup` to the one-line `show` list makes it 81 columns;
  `dart format` then breaks it as `show\n  A,\n  B, ...`, which B1's parser (`' show '` with
  spaces) rejects. I added a second export line for the same file, `export
  'src/host/floor_plan_types.dart' show TableGroup;`; analyze is clean and B1/B2 pass with
  only the mechanical `'TableGroup'` added to B1's expected set.
- Implemented before the tests for the pure file (not strict TDD); every new test then had
  a named mutant fired against it, all red.
- `TableGroupLookup` requires validated groups (documented); it is not defensive against
  overlapping maps.
- `_refreshSelectedGroup` scans `_tables.tables` once per selection change (as
  `_refreshSelected` already does) — not on the frame path.

## Found, not fixed

Nothing outside the task.

## Where the reviewer should look hardest

1. `selectedGroup` freshness: it is recomputed only in `_refreshSelected` and
   `setTableGroups`. A raw layer edit (no command, no selection change) does not recompute it
   until the next selection change or document change — the same staleness `selectedTables`
   has today. TG-C12 covers the lookup cache, not an un-triggered recompute.
2. Notification order in `setTableGroups`: `tableGroups` notifies before `selectedGroup` is
   updated, so a `tableGroups` listener reading `selectedGroup` sees the old value for that
   one callback. Task 4's toolbar should listen to a merge of both.
3. R-C1-2 (design mode → null).
