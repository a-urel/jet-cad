# Task 1 review — the model and the controller (G1, G2, G4 selection, G5 rule)

Reviewer, 2026-10-04. Diff `eed5856..638048b` (one commit, `638048b`), reviewed in the detached
worktree `/home/user/jet-cad/.worktrees/tg-review` (left in place). Logs in
`/tmp/claude-0/-home-user-jet-cad/2f6593d4-4647-5923-ae9f-e6a2fe16a3d1/scratchpad/tg-review1/`.

## Verdict: **Approved**, with two minor findings (non-blocking; fold in now or in Task 4)

The implementation matches spec G1, G2, the G4 selection-by-number paragraph and the G5 Split /
Merge rules line by line. Every gate I re-ran matches the implementer's counts. All 14 mutants I
fired (8 sampled from the implementer's 46, 6 of my own) went red except one of mine, R-3, which
survives on an untested edge case (finding 1).

## 1. Spec conformance (checked line by line)

**`TableGroup`** (`floor_plan_types.dart:90-132`). Members are trimmed and blank ones dropped
inside the constructor, then stored with `Set.unmodifiable`. The label is trimmed, a blank one
means none, and it is then cut to 24 grapheme clusters. Equality uses `setEquals` plus the
label; the hash is unordered. `final class` with a single constructor, so a `TableGroup`'s
members are always already trimmed. Matches G1/G2.

**`validateTableGroups`** (`table_groups.dart:20-45`). Ids are trimmed before the blank check
and the collision check. Members are trimmed by the constructor before the empty check and the
overlap check. So every check runs on trimmed values, and all of them throw before anything is
returned. The overlap message names the number and both ids. Matches G2.

**`setTableGroups`** (`floor_plan_controller.dart:226-230`) validates first, then assigns, so a
throw touches no notifier. Re-fired M-TG-1b to confirm: red.

**`setGroupStatus`**: keys are trimmed, and nothing prunes against the groups. The orphan
statuses are kept (TG-C4).

**`TableGroupLookup`**
- **Duplicate numbers:** every table carrying a member number counts.
- **Unknown members:** kept in the group, they resolve to no table.
- **Locked and hidden:** a locked visible member counts as visible but not selectable. A hidden
  member counts for neither, and a hidden locked member is not "locked visible".
- **Unnumbered tables:** never members.
- **`splitGroup`:** only the first selected number's group can match. That is correct because
  validated groups do not overlap, and TG-U13's `{'5','7','12','3'}` covers a first number in no
  group. Equal size plus `containsAll` gives exact set equality. The `unnumberedSelected` and
  empty guards are present.
- **`mergeQualifies`:** units are tagged as group or number. Blank numbers are ignored.

**Lead order.**
- All-ASCII-digit numbers compare by (length after stripping zeros, stripped string). `int.parse`
  is never used, and a 30-digit number is tested.
- Mixed numbers fall back to `String.compareTo`.
- In `inLeadOrder`, ties go to the lowest handle.
- **R-C1-3, ruling: accept.** Comparing the *stripped* string is required. Comparing the
  original string would put `'09'` before `'1'` (both have stripped length 1, and `'0' < '1'`).
  The extra tie-break on the original string only separates different spellings of one value
  (`'07'` / `'7'`). It makes the comparator total over distinct strings, so the only remaining
  ties are true duplicates, which go to the handle as the spec says.

**Controller `_select`.**
- `_expandGroups` returns the input set unchanged in the design mode or when there are no
  groups, so behaviour with no groups is identical.
- Each expanded number then goes through the existing live / visible / unlocked filter (lines
  516-521). Re-fired M-TG-9b, M-TG-9-mode and M-TG-9: all red.
- `select(' 3 ')` expands through the trimmed `groupOf`. An ungrouped `' 20 '` also resolves,
  because `TableSurvey.withNumber` trims (probe P5: `{20}` and `{12, 3, 7}`). This is
  consistent.

**`selectedGroup`** is recomputed:
- at the end of every `_refreshSelected`, which covers the selection listener, every document
  change through `_refreshFlags`, `setMode`, `resetLayout`, `load` and `newPlan`;
- in `setTableGroups`.

The lookup cache is keyed on the survey's identity (which follows the document and its
`stateId`), the groups map's identity and `tables.mutationRevision`. The new notifiers are
disposed.

**Lifetime.** Neither `setMode`, `resetLayout`, `load` nor `newPlan` touches `_groups` or
`_groupStatuses`.

**Package hygiene** (step 5):
- `git diff eed5856..638048b --stat -- packages/jet_cad_2d packages/jet_cad_2d_flutter` is
  empty.
- Neither allocation invariant test is touched.
- No `analysis_options.yaml` is committed. The worktree shows
  `packages/jet_cad/analysis_options.yaml` modified by `pub get`, not committed.
- The only existing test changed is `barrel_test.dart`: one line, `'TableGroup'`, which is
  allowed under invariant 2.
- No existing expectation changed.

**Groups never reach the document.** TG-C10 compares `designJson()` and the service copy
byte for byte.

**Frame path:** nothing in this task is on it. The lookup is built when the selection, the
document or the groups change, never per frame.

## 2. Rulings and judgement calls the task asked for

- **R-C1-1 (`table_groups.dart` depends on Flutter through `TableGroup`). Accept.** The spec
  puts `TableGroup` in `host/floor_plan_types.dart` (G1, Files), which already imports
  `flutter/foundation` and `flutter/widgets`. The spec also calls `table_groups.dart`
  "Flutter-free". The implementer kept the explicit file placement, and `table_groups.dart` has
  no Flutter import of its own. Every consumer is Flutter code, and the package's tests run
  under `flutter test`. If wrong, the cost is small and local: move `TableGroup` to a Dart-only
  file and re-export it.
- **R-C1-2 (`selectedGroup` is null in the design mode). Accept.** G4 says "Groups do not exist
  in the design mode", and expansion is limited to the selection mode, so a non-null id there
  would contradict the rest of the spec. Killed by M-TG-17-design (TG-C9).
- **Barrel split onto a second `export ... show TableGroup;` line. Accept as mechanical.**
  - I counted the merged `show` line at 81 columns, so `dart format` would break it after
    `show`.
  - B1's parser looks for `' show '` with spaces, which a line break after `show` defeats.
    Editing that parser would change an existing test beyond what is allowed.
  - The second directive is valid Dart, analyze is clean, and B1/B2 pass with only the one-line
    addition to B1.
- **Staleness after a raw layer edit. Acceptable, and the same as `selectedTables`.**
  - Probe P3: G9 = {9, 5}, `select({'5'})` gives `G9`. Showing layer `Hidden` directly through
    `layers.remove/add` (no command, no selection change) leaves `selectedGroup == 'G9'`. By the
    rule it should now be null, because 9 is selectable.
  - It corrects at the next selection change or document change, and the lookup cache already
    follows `mutationRevision` (TG-C12, M-C1-17).
  - `selectedTables` has the same gap today: per F-5, a selected key on a newly hidden layer is
    pruned only at the next document change.
  - In the selection mode the service copy is `runtime`: no layer command exists, and only a
    host poking `activeDocument.tables` can do this.
- **Notification order. Acceptable; a doc sentence is owed (finding 2).**
  - Probes P1 and P2 confirm that `selectedGroup` is stale for one callback:
    - P1: a `tableGroups` listener reading `selectedGroup` sees `null`, and the value afterwards
      is `G2`;
    - P2: a `selectedTables` listener reading `selectedGroup` sees `null`, and afterwards `G2`.
  - Updating `selectedGroup` first does not fix it: two separate `ValueNotifier`s cannot be
    swapped together, so a `selectedGroup` listener would then see stale
    `selectedTables` / `tableGroups` instead. "Derived value last" is the more conventional
    order.
  - It is self-correcting for any listener on a merge of the three. The derived value changes
    only after the primary notifies, so the merge always fires again with the final state, and
    if `selectedGroup` does not change, the value read was already right.
  - Task 4's toolbar should listen to `Listenable.merge([selectedTables, tableGroups,
    selectedGroup])` or build from a builder. A host listening to only one of them must be told
    (finding 2).

## 3. Gates (re-run by me, real summary lines)

`CI=true flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .`
in each package:

| Package | Test | Implementer | Analyze | Format |
|---|---|---|---|---|
| `jet_cad_floor_plan` | `03:44 +1240: All tests passed!` | +1240 | No issues found | exit 0 (203 files, 0 changed) |
| `jet_cad_restaurant_symbols` | `00:02 +94: All tests passed!` | +94 | No issues found | exit 0 |
| `apps/floor_planner` | `01:28 +201: All tests passed!` | +201 | No issues found | exit 0 |
| `apps/restaurant_demo` | `00:10 +18: All tests passed!` | +18 | No issues found | exit 0 |
| `apps/dev_harness_2d` | `00:34 +82: All tests passed!` | +82 | No issues found | exit 0 |
| render `jet_cad_2d_flutter` | `01:21 +1304 ~1 -7: Some tests failed.` | +1304 ~1 -7 | No issues found | exit 0 |

The render package's 7 failures are the standing ones: `text_ladder_golden_test.dart` rungs 1-5
and `text_lod_ladder_golden_test.dart` rungs 1-2, all `RenderBackend.canvas`. They equal the
branch point. The engine was not run (not edited; it is run at the exit per the plan).

## 4. Mutants (re-fired by me)

Method:
1. `cp` the file to a scratch backup.
2. Python exact-string replace, with the anchor count asserted to be 1.
3. `CI=true flutter test <files>`.
4. `cp` the backup back.
5. `diff` exits 0. "restored diff exit 0" was printed after every run, and `git status` is clean
   afterwards apart from the `pub get` `analysis_options.yaml`.

U is `test/service/table_groups_test.dart` and C is
`test/host/table_groups_controller_test.dart`.

| Mutant | Change | Result (real `[E]` / summary) |
|---|---|---|
| M-TG-1a overlap accepted | `if (other != null && false)` | **red**: TG-U5, TG-C1; `+25 -2` |
| M-TG-1b assign before validate (notifies on throw) | `_groups.value = Map.unmodifiable(groups);` before `validateTableGroups` | **red**: TG-C1, TG-C2; `+10 -2` |
| M-TG-9 no expansion | `for (final n in numbers)` | **red**: TG-C1, C3, C5, C6, C7, C11 (+1); `+5 -7` |
| M-TG-9-mode expansion in design mode | `if (groups.isEmpty)` | **red**: TG-C5; `+11 -1` |
| M-TG-9b unfiltered expansion | filter only when `numbers.contains(n)` | **red**: TG-C7, TG-C12; `+10 -2` |
| M-TG-17 split visible instead of selectable | `visibleMembers(id)` in `splitGroup` | **red**: TG-U12, TG-U13, TG-C7, TG-C8; `+23 -4` |
| M-TG-16 merge units by number | `units.add((false, n))` | **red**: TG-U10; `+14 -1` |
| M-TG-20 groups cleared on `resetLayout` | `_groups`/`_groupStatuses` set to `const {}` after `_drop(service)` | **red**: TG-C11; `+11 -1` |
| **R-1 (mine)** the controller's facts ignore hidden layers | `visible: true` in `_groupLookup` | **red**: TG-C7, TG-C8, TG-C12; `+9 -3` |
| **R-2 (mine)** the controller's facts ignore locked layers | `locked: false` in `_groupLookup` | **red**: TG-C7, TG-C8; `+10 -2` |
| **R-3 (mine)** merge unit tag dropped | `(true, id)` → `(false, id)` in `mergeQualifies` | **SURVIVES**: U+C `+27: All tests passed!` |
| **R-4 (mine)** `selectedGroup` computed before the assignment in `setTableGroups` | swap `_groups.value = valid;` and `_refreshSelectedGroup();` | **red**: TG-C9; `+11 -1` |
| **R-5 (mine)** no recompute on a selection change | `_refreshSelectedGroup();` removed from `_refreshSelected` | **red**: TG-C1, C3, C6, C7, C8, C9 (+); `+4 -8` |
| **R-6 (mine)** ungrouped numbers dropped once groups exist | `null => <String>[]` in `_expandGroups` | **red**: TG-C5; `+11 -1` |

13 of 14 are red. R-3 survives; see finding 1.

## 5. Fixtures

There are no degenerate fixtures in the group rules.
- **Unit facts:** handles are given out of order, numbers are unsorted (`G7 = {12, 3, 7}`), and
  the facts include a file duplicate `5` on two handles, a locked `8`, a hidden `9`, a hidden
  locked `10`, an unnumbered table and an unknown member `99`.
- **Controller plan:** every table is off the origin, turned by multiples of 37° and/or
  mirrored. Table 8 is on a visible locked layer, table 9 on a hidden layer, and there is an
  unnumbered table plus a duplicate variant. The camera plays no part in this task, so an
  identity camera is not degenerate here.
- **Locked and hidden members:** the tests built around them (TG-U9, TG-C7, TG-C8, TG-C12) do
  include them.
- **One fixture gap:** finding 1.

## Findings

1. **minor — test gap (surviving mutant R-3).**
   - **Where:** `packages/jet_cad_floor_plan/lib/src/service/table_groups.dart:176`; tests in
     `test/service/table_groups_test.dart` TG-U10/TG-U11.
   - **Evidence:** the `(bool, String)` tag that keeps group ids apart from ungrouped numbers is
     never tested. Every fixture's group ids (`G7`, `G2`) differ from every table number. With
     the tag dropped, all 27 tests pass.
   - **Why it matters:** group ids are POS-given free text, and a POS numbering groups `1`, `2`,
     … is plausible. The correct code gives `true` for `mergeQualifies({'3','7','1'},
     {'1': {3,7}})` (probe P4). The mutant collapses group `1` and table `1` into one unit and
     would disable Merge.
   - **Fix:** in TG-U11 add `expect(mergeQualifies({'3', '7', '1'}, validateTableGroups({'1':
     g({'3', '7'})})), isTrue);`, then re-fire R-3 to see it go red.
2. **minor — documentation.**
   - **Where:** `packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart:244-251`
     (the `selectedGroup` doc).
   - **Evidence:** `selectedGroup` is updated after `selectedTables` and `tableGroups` notify.
     A listener on either of those that reads `selectedGroup` sees the previous value for that
     callback (probes P1, P2, both read `null`, then `G2`). This is not a defect, since no order
     of two `ValueNotifier`s avoids it (§2). But a host cannot see it from the API, and the
     implementer's report already relies on Task 4 listening to a merge.
   - **Fix:** add one sentence to the doc: "Updated after [selectedTables] and [tableGroups]
     notify; to read it with either, listen to it too (e.g. `Listenable.merge`)." Carry "toolbar
     listens to a merge of `selectedTables`, `tableGroups` and `selectedGroup`" into Task 4's
     brief.
3. **note — staleness after a raw layer edit.** `selectedGroup` is not recomputed after a direct
   edit to `activeDocument.tables.layers` (probe P3: stays `G9` until the next selection or
   document change). This is the same class as `selectedTables` today (F-5), and such an edit
   cannot be made through a command in the selection mode. Accepted; no change.
4. **note — rulings.** R-C1-1, R-C1-2 and R-C1-3 are accepted as proposed (§1, §2), with the
   costs-if-wrong the implementer gave. The ledger can record them.

## Probe evidence (scratch test, run and removed; never committed)

`test/host/zz_review_probe_test.dart` was copied in, run with `CI=true flutter test`, and
deleted. `git status` afterwards showed only the `pub get` `analysis_options.yaml`. Real output
lines:

```
P1 in tableGroups callback selectedGroup=null, after=G2
P2 in selectedTables callback selectedGroup=null, after=G2
P3 after raw show (no selection change): tables={5} group=G9
P4 mergeQualifies({3,7,1}) = true
P5 select(" 20 ")={20} select(" 3 ")={12, 3, 7}
00:00 +5: All tests passed!
```
