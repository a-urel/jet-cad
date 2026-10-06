# Task 1 review — selectableMembers and the demo's grow rule (X1, X2)

**Reviewed:** `cfee751..d8d06ed`, in a detached worktree at `.worktrees/tgf-review` (d8d06ed).
**Verdict: Approved.** There are no blocking, major or minor findings, only two notes. Both proposed rulings, R-C1-1 and R-C1-2, are accepted.

## 1. Implementation against X1 / X2 and the plan

### X1, `FloorPlanController.selectableMembers` (floor_plan_controller.dart:258-272)

- **Source.** It reads `_groupLookup.selectableMembers(groupId.trim())`. That is the cached lookup over (survey identity, groups identity, layer `mutationRevision`), so it is fresh at every call (F-6).
- **Trimming.** The id is trimmed. Group keys are trimmed by `validateTableGroups` (table_groups.dart:24), so a trimmed query matches. `GroupTable.number` is already trimmed, and `t.number!` is safe because the lookup skips tables with no number.
- **Unknown id.** It gives `const []` from the lookup, so the result is an empty set.
- **Duplicates.** A number carried by two tables appears once, because the result is a set literal. It is in the set when any carrier is selectable, because `_selectable` filters per table.
- **Unmodifiable.** The result is wrapped in `Set.unmodifiable`.
- **Modes.** It works in both modes. In design mode it reads `_active.document`, the design document.
- **No new API surface.** There is no listenable and no new type, and `FloorPlanTable` is unchanged (A-2).
- **Allocation.** It allocates one set per call. It is host-only (called at merge time), not on the frame path.

### X2, the demo's `mergeGroups` (main.dart:303-327) and `_merge` (:333-349)

- **Grow condition.** `whole` = the groups G where `selectable(G)` is non-empty and `numbers ⊇ selectable(G)`. A grow happens only when `whole.length == 1`; with zero or two or more groups it is a new group. This is the literal rule.
- **The single loop:**
  - `e.key == id` adds `numbers` to the group, keeping its locked and hidden members, its label and its map position.
  - Every other group either:
    - is kept by identity when untouched;
    - is rebuilt as `rest` with its label;
    - or is dropped when emptied.

  On a grow, this is what removes the requested numbers from other groups. The old grow path had no need to, since under R-C5-1 it touched only one group.
- **New-group path, equivalent to before.** `nextGroupId` returns `G<max trailing digits + 1>`, which cannot equal an existing key. So `e.key == id` is never true on this path, and `putIfAbsent` acts exactly like the old `next[id] = ...`. D17, D19 and D20 pass unedited.
- **Same groups for both arguments.** `selectable` answers over the same groups as `groups`: `before = c.tableGroups.value` is read just before the call, and `selectableMembers` reads `_groups.value` (R-9).
- **Statuses.** An emptied group's status goes through the unchanged `gone` set (R-C5-2).
- **No-op grow from a host.** The request `{3, 12}` with `G7 = {12, 3, 8 locked, 9 hidden}` puts only G7 in `whole`. The groups are re-set equal, the status is kept, and the merge is logged "Merged {3, 12} as G7" (D24).
- **Empty request.** It returns early in `_merge`, so nothing is set and nothing is logged.
- **No groups.** `whole` is empty, so the result is `G1 = numbers`, as before (invariant 3).
- **Document.** No document write was added (invariant 2).
- **Existing tests.** No existing expectation changed. The only removed test line is the `show` list of an import, which gains `FloorPlanView`.

### Parent spec amendment (2026-10-04-table-groups-design.md:617-646)

- R-C5-1 is marked **Retired**, cites the fixes spec X2, and is kept "as history only". The original rule is now in the past tense ("was implemented as").
- F-1 is marked **closed**, cites X1, and names `FloorPlanController.selectableMembers(groupId)` with `FloorPlanTable` left flagless (A-2). It then flags "the text below is the finding as it stood".
- The wording is accurate.
- The remainder consequence still holds under the new rule: a group left holding only locked or hidden members never grows (M-TGF-6) and cannot be selected for Split.
- No dart file still describes R-C5-1 as current. The only remaining mention is D21's header comment, which says "R-C5-1 retired". STATUS is Task 3's.

### Rulings

- **R-C1-1 — accept.** I confirmed the premise. The first-table mutant (M-TGF-3a, written independently below) goes red only on the `lockFive: true` iteration ("lockFive: true", `Actual: Set:['12', '3']`). The loop runs `false` first, so the spec's literal variant alone lets that mutant survive. The extra variant is needed, and the literal one is kept.
- **R-C1-2 — accept.** X2 says "the demo returns without change", and `_merge` is the demo's entry from the host path. `mergeGroups` documents that `numbers` must not be empty. D24 kills the guard's removal through `FloorPlanView.onMergeRequested`.

## 2. Gates (my runs: Flutter at /home/user/flutter, `CI=true`, review worktree)

| Package | test | analyze | format | Implementer |
|---|---|---|---|---|
| packages/jet_cad_floor_plan | `09:11 +1282: All tests passed!` | No issues found! | 208 files (0 changed) | +1282 |
| apps/restaurant_demo | `00:36 +28: All tests passed!` | No issues found! | 3 files (0 changed) | +28 |
| apps/floor_planner | `03:36 +201: All tests passed!` | No issues found! | 44 files (0 changed) | +201 |

All three match the implementer's counts. The planner is +4 on the branch point (+1278) and the demo is +4 on +24.

## 3. Mutants (re-fired by me)

Method: back up the file with `cp`, apply the mutation with a Python exact-string replace (match count 1), run the named test file, `cp` the backup back, then run `diff`. The `diff` printed "RESTORED OK" for every mutant. Outputs are in `/tmp/claude-0/-home-user-jet-cad/2f6593d4-4647-5923-ae9f-e6a2fe16a3d1/scratchpad/tgf-review1/<name>.{out,diff}`.

### Demo: main.dart, `flutter test test/demo_test.dart`

| Mutant | Change | Result |
|---|---|---|
| R-C5-1 / M-TGF-4 | `whole` = groups whose members touch `numbers` | RED: D21 (`Actual: {'G7': TableGroup({12, 3, 7, 20}, null)}`), D23 |
| M-TGF-6 vacuous grow | `s.isNotEmpty &&` dropped | RED: D22 |
| M-TGF-7 keep 5 | other groups keep the requested numbers when `whole.length == 1` | RED: D23, with the spec's evidence `ArgumentError: Table number "5" is in two groups, "G7" and ...` |
| M-TGF-5 never grow | `id = nextGroupId(...)` always | RED: D16, D18, D23, D24 |
| M-TGF-5 all members (lock-blind) | `_merge` passes `(id) => before[id]!.members` | RED: D18, D20, D24 |
| M-TGF-5 grow drops the label | `label:` dropped on the grown group | RED: D18, D24 |
| own: first fully-requested group wins | `whole.isNotEmpty ? whole.first : ...` | RED: D17, D20 |
| own: new-group write overwrites | `putIfAbsent` → `next[id] = TableGroup(members: numbers)` | RED: D18, D24 |
| own: subset reversed | `s.containsAll(numbers)` | RED: D16, D18, D23 |
| own: empty guard removed | `if (numbers.isEmpty) return;` deleted | RED: D24 |

### Controller: floor_plan_controller.dart, `flutter test test/host/table_groups_controller_test.dart`

| Mutant | Change | Result |
|---|---|---|
| M-TGF-1 | `selectableMembers` → `visibleMembers` (keeps locked 8) | RED: TG-C13, TG-C14, TG-C16 |
| M-TGF-2 | id not trimmed | RED: TG-C14 |
| M-TGF-3 first table decides | each number decided by its first visible carrier | RED: TG-C15, on the `lockFive: true` iteration only |
| M-TGF-10 memo by id only | `_memo.putIfAbsent(groupId, ...)` | RED: TG-C16 ("the same id, new members": `Actual: Set:['12', '3', '7']`) |
| own: result modifiable | `Set.unmodifiable` dropped | RED: TG-C13 |
| own: empty outside selection mode | `const {}` unless `FloorPlanMode.selection` | RED: TG-C13, TG-C16 |
| own: lookup not keyed by survey | `!identical(_lookupSurvey, survey)` dropped | RED: TG-C12, TG-C16 |

Not re-fired here, taken from the implementer's table: M-TGF-3b ("every carrier selectable"), M-TGF-10b/c/d (lookup keyed by survey only, layer revision dropped, memo by (id, groups)), the remainder-label mutant and the lost-status mutant. The mutants I did re-fire behaved as the implementer reported.

**Survivors: none.**

## 4. Fixtures (degeneracy check)

- **Controller (TG-C13..16).** These use `groupsPlanJson`: tables off the origin, turned or mirrored, numbers in non-sorted handle order (`12, 3, 7, 20, ...`), a locked 8 and a hidden 9, and a duplicate-number variant with both carrier orders.
  - TG-C13 checks both modes, and a group whose only members are locked or hidden, which gives `isEmpty`.
  - TG-C16 changes the groups under the same id, the design layers before a mode switch, and the service copy's layers through a raw edit that makes no command. Each step kills a distinct memo-key mutant.
- **Demo (D21..24).**
  - The numbers are unsorted (`3, 20`; `20, 5`).
  - D22 uses a non-trivial next id: G9 is followed by G10.
  - D23 carries a label (`Bar`) and a group status (`Bill`) on the remainder, and checks the status text.
  - D24 drives the host path through `FloorPlanView.onMergeRequested` with a locked and a hidden member in the grown group.
  - Locked and hidden members are present wherever the rule depends on them (D18, D20, D22, D24).
- No degenerate fixture was found.

## 5. Scope checks

- `git diff cfee751..d8d06ed --stat -- packages/jet_cad_2d packages/jet_cad_2d_flutter` is empty, so the engine and render packages are untouched.
- No invariants test was touched, and the diff contains no `analysis_options.yaml`. The worktree's `packages/jet_cad/analysis_options.yaml` was modified by `pub get` only, and nothing was committed.

## Notes (non-blocking)

- **N-1 (note).** No test covers a grow that **empties** another group. That case is host-only: it needs the other group to have no selectable member, for example a host requesting a locked 8 that is G9's only member.
  - The drop and the status removal go through code shared with the new-group path (the loop's `rest.isNotEmpty` branch and `_merge`'s `gone` set). D17 and D20 pin that path, and so does the `ArgumentError` that an empty group would raise.
  - A mutant would have to special-case the grow path to escape, so no test is required.
- **N-2 (note).** The static `mergeGroups` called directly with an empty `numbers` returns a memberless group, which `setTableGroups` refuses. This is the documented precondition and the cost R-C1-2 names. Acceptable.
