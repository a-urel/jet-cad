# Task 2 review — selecting, tapping and moving (G4, G1 callbacks)

Reviewer, 2026-10-04. Diff `f98532f..c5eb454` (one commit, `c5eb454`), reviewed in the detached
worktree `/home/user/jet-cad/.worktrees/tg-review` (left in place; its only dirty file is the
`packages/jet_cad/analysis_options.yaml` that `flutter pub get` rewrites). Logs, the probe file and
the mutant driver are in
`/tmp/claude-0/-home-user-jet-cad/2f6593d4-4647-5923-ae9f-e6a2fe16a3d1/scratchpad/tg-review2/`
(`gate-*.log`, `zz_probe_test.dart`, `mut.py`, `mut.log`, `mut-*.out`).

## Verdict: **Approved**, with one minor finding (non-blocking, test-only; fold in now as a 2b or in Task 3)

The tool matches spec G4 and G1's callbacks line by line. The path with no groups is exactly the
f98532f behaviour, and the test diff is mechanical. Every gate I re-ran matches the implementer's
count. I fired 11 mutants: 6 sampled from the implementer's 21 and 5 of my own. All 11 go red, but
two of mine (R-X1, R-X2) go red **only through my probe tests**, not through the committed suite.
The emptiness guards on `_groupByHandle` in the drag start and the long press are correct but
unpinned (finding 1).

## 1. Spec conformance

**Tap** (`table_select_tool.dart:218-245`).
- An unlocked member does one `replace`:
  - a plain tap replaces with `_memberKeys` (the selectable members);
  - a modifier tap replaces with `_addOrRemoveGroup`. That removes every visible member's key if
    the tapped key is selected, otherwise it adds the selectable members.
- There is no `toggle` on a group path. `toggle([key])` remains only for a table in no group, as
  before.
- A locked hit skips the selection block entirely. `group` is resolved before that block, so a
  locked member still reports.
- Callback order: `onTableTap(number)` first, then `onGroupTap(group, number)`. The early return
  for an unnumbered table comes before both, as before; an unnumbered table can't be a member
  anyway.
- Matches G4 "A tap on a member" and R-1.

**Long press** (`:314-329`).
- The timer is still started only for an unlocked hit, and `_longPress` returns early on a locked
  one.
- A member uses the same `_addOrRemoveGroup` through one `replace`. A table in no group still uses
  `toggle`.
- No callback fires. Matches G4.

**Drag start** (`_startDrag`, `:153-182`).
- `replace` is computed from the hit's own key. If the hit is unselected, `selected` is its group's
  selectable members, or `{key}` when it is in no group.
- `involved` is computed from the root-level keys of `selected`, so it covers **every** group
  touched by the selection, not just the hit's.
- The lock check (`involved.any(hasLockedVisibleMember)`) runs **before**
  `ctx.selection.replace`. On false the caller sets `spent`, so there is no pan, no move and no
  replace.
- `_moving` is `roots` ∪ the selectable members of every involved group, deduplicated and sorted
  by handle.
- `_move` is unchanged: one `CompoundCommand('Move')` and one `onLayoutChanged`.
- Matches G4 "Starting", "What moves" and "Locked members", including the drag started on a
  non-member (TG-G7).

**Lookup** (`_groupLookup`, `:268-294`).
- It returns null when `groups.value` is empty, before it touches `picker.candidates`.
- It rebuilds when the identity of the candidates list or of the groups map changes.
- `GroupTable(visible: true, locked: c.locked)` is right because the picker lists visible tables
  only (`table_picker.dart:172`).
- `_groupByHandle` is built from `visibleMembers`, so a locked member maps to its group. That is
  what makes the locked tap report the group. My mutant R-X4 (built from `selectableMembers`
  instead) is red in TG-G2.
- `TableInfo.number` is already trimmed (`table_index.dart:30,91`), which matches the lookup's
  trimmed keys.

**Plumbing.**
- `ServiceCallbacks` gains the three fields.
- `FloorPlanView` gains the three optional callbacks with doc comments and passes them through the
  closure, which is read at each call (R-5).
- `ServiceView` passes `_c.tableGroups`.
- The engine and the render package are untouched:
  `git diff f98532f..c5eb454 --stat -- packages/jet_cad_2d packages/jet_cad_2d_flutter '*analysis_options.yaml' '*invariants*'`
  is empty. No `analysis_options.yaml` is committed.
- No other construction of `ServiceCallbacks` or `TableSelectTool` exists (grep: only
  `table_select_tool_test.dart:66` and `service_view.dart:60`).

**No allocation on the frame path.**
- The lookup is built only from pointer handlers (tap, long press, drag start), never from paint.
- `selectionPreviewTransform` is unchanged.
- With no groups, `_groupLookup` returns before any allocation.

**Groups never reach the document.** The tool only reads `groups`, and the only edits are the
existing `TransformNodeCommand`s through `_move`.

## 2. The path with no groups (invariant 2)

I diffed the old and new code paths with `lookup == null`.

- **Tap.**
  - `group` is null. `_toggle ? toggle([key]) : replace([key])` is the old code.
  - `onTableTap` fires under the same `number != null` condition.
  - `onGroupTap` cannot fire.
  - Identical.
- **Long press.** `group` is null, so `toggle([key])`. Identical.
- **Drag.**
  - `groupOf` is `const {}`, so `hitGroup` is null and `involved` is empty. The lock check is
    vacuously false.
  - Unselected hit:
    - old: `replace([key])`, then `_moving` from `ctx.selection.keys`, which is `{key}`, because
      `replace` does no filtering (F-5);
    - new: `selected = {key}`, `replace({key})`, `_moving = sorted({key})`.
    - Equal.
  - Selected hit: neither version replaces, and both build `_moving` from the root keys of
    `ctx.selection.keys`, sorted. The new version wraps them in a set first; distinct root keys
    have distinct targets, so the set changes nothing.
  - Equal.
- **Touch (14t).** `onPointerDown` (the hold-back-adjusted timer `kLongPressTimeout - kTouchHoldBack`)
  and `touchPress` are byte-identical to f98532f; the diff does not touch them.
- **Test diff** (`table_select_tool_test.dart`): one import (`ValueNotifier`), the `groups:`
  argument, and three `null` record fields. No expectation changed. ST1–ST17 pass unedited in the
  full planner run. I accept the import line as part of the mechanical change: the parameter can't
  be passed without it.

## 3. Focus questions

**Stale `_groupByHandle` after `setTableGroups({})`.**
- Every read is guarded:
  - `_tap` (`:229`) and `_longPress` (`:320`) use `lookup == null ? null : …`;
  - `_startDrag` (`:157`) substitutes `const {}`;
  - the `lookup!` uses run only when a group was found through the guarded map.
- On the real code my probes go **green**:
  - P1: groups set, then `{}`, then a drag on a former member moves it alone and selects `{3}`;
  - P2: the same, then a long press toggles one table and a Shift tap toggles one table.
- Through the committed suite, though, only the tap guard is pinned (TG-G9's last step; my R-X5 is
  red there). The drag and long-press guards are not (finding 1).
- Returning to a non-empty map always rebuilds: it is a new map identity, and `_lookupGroups` held
  the old one.

**Keying on the identity of the candidates list (R-C2-2).**
- `TablePicker.candidates` (`table_picker.dart:153-163`) assigns `_candidates = _build()` exactly
  when `(stateId, tables.mutationRevision)` moves.
- `_build` always returns a fresh `out` list, even when it is empty, so a key change always yields
  a new identity.
- No code mutates the list in place. The only other assignment is the initial `const []`, and grep
  finds `.candidates` read only by the tool (`table_select_tool.dart:272`) and the picker itself.
- `_lookupCandidates` starts null, so the first call always builds.
- TG-G10 (a raw layer edit that moves only the tables' revision) kills the mutant that drops the
  candidates key.
- **Accepted.** One note for the future: the list is a growable `List` exposed publicly. If anyone
  ever mutates it in place, this key breaks silently. `List.unmodifiable` in `_build` would close
  that, but it is out of scope here.

**R-C2-1: a half-selected group stays half-selected after the drag; only `_moving` grows.**
- **Accepted.**
  - G4 "What moves" defines only `_moving` ("the root-level selected keys expanded …"), and its
    rationale is about the move: "moves whole".
  - "Starting" grants a selection change only when the hit is unselected.
  - Expanding the selection would be an unspecified side effect.
- The visual cost is narrow. During such a drag, the moved but unselected members show no outline
  preview and jump on release. That is the same behaviour G3 already prescribes for frames, fills
  and chips ("stay where they are and jump on release").
- It arises only when a selection was made before `setTableGroups` grouped it, or by a `select` that
  preceded the groups.
- Record it in the ledger. Task 3 must not assume that every moved table has a preview outline.

**R-C2-3 (removal by visible members, addition by selectable members). Accepted.**
- A locked key never enters a selection through the tool or `select`.
- If a member becomes locked while selected (a raw layer edit), its key survives until the next
  document change prunes it (F-5). In that case removal by visible members is the more total and
  correct choice.
- No other behaviour can be observed.

**R-C2-4 (members come from the candidates). Accepted.**
- A table with a singular transform or an empty box cannot be hit, moved or selected by the tool
  today (14c).
- The divergence from `controller.select`, which reads the survey, predates this task.
- This is what the spec's "member keys come from the picker's candidates" says.

## 4. Gates (re-run by me at `c5eb454`)

| Package | Test | Analyze | Format |
|---|---|---|---|
| render `jet_cad_2d_flutter` (not edited) | `01:19 +1304 ~1 -7: Some tests failed.` (the 7 are `text_ladder_golden_test` rungs 1–5 and `text_lod_ladder_golden_test` rungs 1–2, canvas; the standing set) | No issues found | 0 changed, exit 0 |
| planner `jet_cad_floor_plan` | `03:44 +1251: All tests passed!` | No issues found | 0 changed, exit 0 |
| `jet_cad_restaurant_symbols` | `00:02 +94: All tests passed!` | No issues found | exit 0 |
| `apps/floor_planner` | `01:31 +201: All tests passed!` | No issues found | exit 0 |
| `apps/restaurant_demo` | `00:10 +18: All tests passed!` | No issues found | exit 0 |
| `apps/dev_harness_2d` | `00:35 +82: All tests passed!` | No issues found | exit 0 |

Every count matches the implementer's report. The planner is +1240 after Task 1b, plus the 11
new tests.

## 5. Mutants

**Method.**
- `mut.py` copies each file to a backup and replaces one exact string, asserting a count of 1.
- It then runs `flutter test table_groups_gesture_test.dart table_select_tool_test.dart
  zz_probe_test.dart`. The probe file was copied in for the run only, then deleted.
- Finally it copies the backup back and byte-compares the restored file with the backup
  (`restored True` for all 11).
- `git status` afterwards shows only `analysis_options.yaml`.

| Mutant | Change | Red (real `[E]`) |
|---|---|---|
| M-TG-5 | the group modifier tap becomes `toggle(_memberKeys)` | TG-G3 |
| M-TG-7b | the drag start selects `{key}` only | TG-G5, TG-G11 |
| M-TG-8b | only the hit's group checked for a lock | TG-G7 |
| M-TG-8c | `_moving` without the involved-groups expansion | TG-G8 |
| M-TG-17c | the groups-map identity is ignored in the rebuild | TG-G9 |
| M-C2-6 | `ServiceView` passes `ValueNotifier(const {})` | TG-G1…G11 (all 11), plus probes P1 and P4 |
| **R-X1** (mine) | `_startDrag`: `groupOf = _groupByHandle` (stale after `{}`) | **probe P1 only** (null-check throw at `:164`, then the wrong translation). The committed suite stays green. |
| **R-X2** (mine) | `_longPress`: reads `_groupByHandle` and the stale `_lookup` unguarded | **probe P2 only** (`{7,20}` expected; the stale G7 selected 3, 7, 12 and 20). The committed suite stays green. |
| R-X3 (mine) | the drag start never calls `replace` | TG-G5, TG-G11, ST4, ST6, ST9, plus probes P1 and P3 |
| R-X4 (mine) | `_groupByHandle` built from `selectableMembers` | TG-G2, plus probe P4 |
| R-X5 (mine) | `_tap`: reads `_groupByHandle` and the stale `_lookup` unguarded | TG-G9, plus probe P2 |

## 6. Fixtures

The fixtures are not degenerate:
- tables off the origin, turned by multiples of 37° and mirrored, one of them an asymmetric
  trapezoid;
- numbers out of handle order (`12, 3, 7, 20, 5, 8, 9`), with `G7 = {12, 3, 7}`;
- a camera off the origin at 0.06 px/mm with y flipped, set after mount;
- a locked visible member and a hidden member;
- a file-duplicate variant;
- mouse, Shift/Ctrl/Meta and touch input.

Two observations:
- **No member is both hidden and locked.** "A locked member on a hidden layer does not count" (G4)
  holds structurally, because the tool sees only the picker's visible candidates. My probe P3 hides
  the locked layer and a drag on 5 then moves it: green. Optional to land.
- **No probe after `{}`** — see finding 1.

## Findings

1. **minor — the guards against a stale `_groupByHandle` in the drag start and the long press are
   unpinned.**
   - Where: `table_groups_gesture_test.dart:369-392` (TG-G9); the guards are at
     `table_select_tool.dart:157` and `:320`.
   - Evidence: mutants R-X1 and R-X2 (section 5) leave all 11 TG-G tests and ST1–ST17 green. R-X1
     makes a drag on a former member after `setTableGroups({})` throw a null check inside
     `_startDrag` and move the wrong tables. R-X2 makes a long press after `{}` select the old
     group.
   - This is exactly the stale-lookup hazard the report flags ("A change that reads
     `_groupByHandle` without the guard would see stale groups"). The code is correct today.
   - Fix: extend TG-G9, or add TG-G12, after `setTableGroups(const {})`:
     - a mouse long press on a former member (e.g. 7) toggles only that table;
     - a mouse drag on an unselected former member (e.g. 3) selects `{3}` and moves only 3, leaving
       12 and 7 unmoved.

     My `zz_probe_test.dart` P1/P2 do exactly this and go red under R-X1/R-X2 respectively. Re-fire
     both and record them in the ledger.

2. **note — R-C2-1 to R-C2-4 are all accepted** (section 3). Record R-C2-1's consequence for Task 3:
   during a drag of a half-selected group, the moved but unselected members have no preview
   outline.
