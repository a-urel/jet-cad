# Task 5 review — the demo (G6)

Reviewer, 2026-10-04. Diff `cda29b7..eecc823`, reviewed in a fresh detached worktree
`/home/user/jet-cad/.worktrees/tg-review` at `eecc823`. The worktree and partial review
left by the interrupted run were removed first, and this review started from scratch.

## Verdict: Approved, with 2 minor test-only findings (2b) and 3 notes

The code matches G6 and the plan's Task 5. Every requested mutant I re-ran goes red.
The two surviving mutants are untested branches, not wrong behaviour: Free on a group, and
the R-C5-4 remainder. I confirmed both branches behave correctly with a scratch probe. They
should be pinned by a test-only 2b, as earlier tasks did. Nothing blocks the task.

## Scope checks

- `git diff cda29b7..eecc823 --stat -- packages/` is empty. The engine, render, planner
  and symbols packages are untouched, and so are the allocation invariants.
- Only `apps/restaurant_demo/lib/main.dart` (+162/-10) and `test/demo_test.dart`
  (+329/-2) changed. No `analysis_options.yaml` is committed.
- D1..D15 and the dark-theme test are unedited. The test diff removes only two lines, and
  both are import lines that were widened: `show rootBundle` became
  `show LogicalKeyboardKey, rootBundle`, and `show FloorPlanMode, TableStatus` gained
  `TableGroup`. Everything else is appended after the last existing test.
- The one existing UI string that changed is the status heading, now "... tables or
  group". No test references it.

## Gates (run by me, `CI=true`, `--no-pub`, at `eecc823`)

| Package | Result | Implementer |
|---|---|---|
| restaurant_demo `flutter test` | `+22: All tests passed!` | +22, matches |
| restaurant_demo `flutter analyze` | `No issues found!` | matches |
| restaurant_demo `dart format --set-exit-if-changed .` | `Formatted 3 files (0 changed)`, exit 0 | matches |
| jet_cad_floor_plan `flutter analyze` | `No issues found!` | matches |

I did not re-run the other packages, as the brief scoped it. The diff under `packages/` is
empty, so they cannot have changed.

## Focus questions

### R-C5-1: the grow rule ("touches exactly one group")

**Can the selection-mode UI leave a group half-selected?** I traced every path in the
`eecc823` sources. None of them can.

- **Plain tap** on a member: `replace(_memberKeys)` selects every selectable member
  (`table_select_tool.dart`, `_tap`).
- **Modifier tap and long press**: one `replace(_addOrRemoveGroup(...))`. This adds every
  selectable member, or removes every visible member's key. Either way the group ends fully
  selected or not at all.
- **Drag start** on an unselected member: the group replaces the selection. A drag on an
  already half-selected group leaves the selection as it is (R-C2-1). It never creates one.
- **The number field and `select`**: `_select` runs through `_expandGroups` in the
  selection mode, filtered to visible, unlocked tables.
- **`setMode` and `resetLayout`**: both re-run `_select(numbers)`, so they re-expand.
  Layer locks or visibility changed in the design mode are therefore absorbed when the
  user returns to the selection mode.
- **`load`**: clears the selection.
- **The host API**: it has no layer or lock call, so the service mode cannot change which
  members are selectable.
- **The demo's own `setTableGroups` calls**: there are two, in `_merge` and `_split`, and
  neither can create a half-selected group. The argument is an induction on the selection.
  - Grow: the selection was whole, and the grown group is that selection's group plus the
    other requested numbers.
  - New group: the new group is exactly the selected numbers. What remains of the touched
    groups can only be their unselectable members.
  - Split: no group is left.

**The only route is the host API.** A host calls `setTableGroups` while tables are
selected: M-TG-5's fixture. I probed it with a scratch test, added to `demo_test.dart` and
then restored (`diff` exit 0):

```
PROBE-A selected={3, 20} group=null
PROBE-A groups={G7: TableGroup({12, 3, 7, 20}, null)} log=Salon: Merged {3, 20} as G7
```

So Merge is enabled (two units), and R-C5-1 grows G7 with 20 although 12 and 7 were not
requested. Under G6's literal rule, `{3, 20}` does not include G7's selectable members
`{12, 7}`, so the result would instead be `G8 = {3, 20}` and `G7 = {12, 7}`.

**Recommendation: accept this as demo behaviour, and record F-1 as an API finding. Do not
add the seam now.**

- **The literal rule cannot be implemented by a host today.**
  - `FloorPlanTable` carries no lock or visibility flag, and no host call answers "which
    members are selectable".
  - Approximating it with all plan numbers is lock-blind. D18 shows the cost: a group with a
    locked or hidden member could never grow.
- **The divergence is narrow.** It needs a POS that sets groups under a live selection and
  then merges. The demo never does that, and its UI cannot produce the state.
- **R-C5-1 follows the spec's own stance.** G4 says a half-selected group "moves whole" on
  a drag: touching a group stands for the whole group. Growing G7 whole on a merge is the
  same reading. It is a defensible host decision, which G5 explicitly delegates ("The host
  decides what a selection spanning a group means").
- **What Task 6 should record:**
  - R-C5-1, in the spec's "Amended at execution" section, replacing G6's literal wording;
  - F-1 (`selectableMembers(groupId)`, or a lock/visible flag on `FloorPlanTable`) as debt
    in the results note.

### R-C5-2: a group emptied by a merge loses its group status

Accept. Without it, a stale status reattaches when the id comes back.

- Ids come back because numbering is max + 1 over the current groups. Once every group is
  gone, the next merge makes `G1` again.
- The rule mirrors Split.
- Pinned: M7 is red, in D17.

### R-C5-3: one log line for both outcomes, in reading order

Accept. The id in the line tells grow from new.

- The `Merged {…}` line sorts in reading order while the old `selected {…}` line keeps its
  plain string sort (`12, 3, 7`). That is cosmetic, and the old line has to stay as it is,
  since changing it would break an existing expectation.

### R-C5-4: a remainder group keeps its id and label

Accept the behaviour, but it is unpinned (finding 2). It also has a consequence the report
does not state (note A). Probe:

```
PROBE-B groups={G7: TableGroup({8, 9}, Window), G8: TableGroup({12, 3, 5, 11}, null)}
        log=Salon: Merged {3, 5, 11, 12} as G8 line=G7: 8+9, G8: 3+5+11+12
```

### G<n> numbering

`nextGroupId(groups.keys)` takes the groups **before** the merge, so it cannot hit any
existing `G<n>`.

- `^G(\d+)$` with BigInt means a huge suffix cannot throw.
- Non-`G` ids are ignored, and `G1` is used when there are none.
- D17 pins it: after a split, the next merge is G4, not a reused G3; after the drop, the
  next is G6, not G1. M3 is red. The implementer's M10 covers the "after the drop" case.

### Status routing

- With `selectedGroup` set, the buttons call `setGroupStatus` on that id and log
  `<Area>: <Status> for G<n>`. M5 is red in D16, D17 and D19.
- With no group selected, the per-table path is byte-for-byte the old loop. Only the
  `next` declaration moved below the early return. D16 exercises it (`Eating` on 20 leaves
  `groupStatuses` empty).
- **Free on a group clears the group status.** My probe confirmed it (`PROBE-B after free
  groupStatuses={} log=Salon: Free for G8`), but no test pins it (finding 1).
- Status buttons in the design mode are unaffected, because `selectedGroup` is always null
  there (R-C1-2).

### D16's drag

- **Real transforms.** The tables are off the origin and turned or mirrored. The camera is
  the off-origin, non-unit fit. Taps go through `camera.worldToScreen` of the definition's
  base point.
- **What it checks:**
  - 12 and 7 move by 3's step, which must exceed 100 mm;
  - their linear parts are unchanged, which matters because the tables are turned or
    mirrored;
  - non-members 20 and 5 are bit-identical (`after[n] == before[n]`);
  - `layout changed` is logged exactly once.
- 20 was selected before the press, and the drag on an unselected member replaced the
  selection with G1. So 20 staying put is the spec'd G4 behaviour (an unselected member's
  group replaces the selection), not merely a fixture accident.

## Mutants (fired by me)

The script is `scratchpad/tg-review5/mut.py` with `muts.json`, and each mutant's output is
in `mut-<id>.log`. For each mutant it:

- copied `main.dart` to a backup;
- applied a string replacement, asserted unique;
- ran `flutter test --no-pub test/demo_test.dart`;
- copied the backup back, then checked `diff` exit 0.

Every restore diff exited 0, and `git status` of the worktree is clean apart from the pub
`analysis_options.yaml`.

| # | Change | Result |
|---|---|---|
| M1 | `touched.length == 1` → `== -1` | **red** (D16, D18) |
| M3 | `'G${max + BigInt.one}'` → `'G${ids.length + 1}'` | **red** (D17) |
| M5 | `final group = c.selectedGroup.value` → `final String? group = null` | **red** (D16, D17, D19) |
| M7 | `if (gone.any(...))` → `if (false)` | **red** (D17) |
| M11 | `{...grown.members, ...numbers}` → `{...numbers}` | **red** (D18) |
| R1 (mine) | Free on a group does nothing (drop `next.remove(group)`) | **survives**, `+20: All tests passed!` |
| R2 (mine) | remainder group dropped (`else if (rest.isNotEmpty)` → `else if (false)`) | **survives** |
| R3 (mine) | remainder loses its label (`TableGroup(members: rest)`) | **survives** |
| R4 (mine) | new-group merge leaves the numbers in their old groups (`rest = e.value.members`) | **red** (D17) |

## Findings

1. **minor (test-only).** Free on a selected group is unpinned.
   - Where: `main.dart:220-223`, the `status == null` branch of the group path, which the
     brief lists as "Free clears".
   - Evidence: mutant R1 survives.
   - Fix: in D16, after `Bill for G1`, press `status-free`. Expect `groupStatuses` empty,
     `tableStatuses` still `{20: Eating}`, and the log `Salon: Free for G1`. Then press
     `status-bill` again so the rest of D16 runs unchanged, or move the check to just
     before Split.
2. **minor (test-only).** R-C5-4 is unpinned.
   - Where: `main.dart:320-322`, where a new-group merge leaves a group with members it
     keeps under its id and label.
   - Evidence: R2 and R3 survive.
   - Why it matters: the branch is reachable in the demo. Use D18's POS group
     `G7 = {12, 3, 8 locked, 9 hidden}` labelled `Window`, plus a second group, then merge
     across both (PROBE-B above).
   - Fix: a D20 with exactly PROBE-B's fixture. Expect
     `{G7: TableGroup({8, 9}, Window), G8: TableGroup({12, 3, 5, 11})}` and the line
     `G7: 8+9, G8: 3+5+11+12`. This kills R2 and R3.

## Notes (no action required for this task)

- **A.** A remainder made only of unselectable members, like `G7 = {8, 9}` above, is a
  group that no demo UI can split or merge. Split needs a non-empty selectable set, and the
  members cannot be selected. Only the POS (`setTableGroups`) can clear it. This is
  acceptable for a demo and is another facet of F-1: the host cannot tell that the
  remainder is unselectable. Record it next to F-1 in the results note.
- **B.** The new callbacks bind `a` (the area the view was built for). The existing
  `onTableTap` and `onLayoutChanged` read `area` at call time. This is harmless, since the
  view is rebuilt on an area switch, but it is inconsistent. Leave it, so the existing
  lines stay unedited.
- **C.** The plan's global constraint asks for the render package to be "run once per task
  to show it unchanged". The implementer did not run it, and neither did I, since the brief
  scoped it out. The `packages/` diff is empty, so the 7 standing failures and 1 skip
  cannot have moved. Task 6 runs it anyway.

## Degenerate-fixture check

`groupPlan()` passes the check:

- eight tables, none at the origin, with quarter turns 0–3 and some mirrored;
- numbers unsorted in handle order (`12, 3, 7, 20, 5, 11, 8, 9`);
- a locked member (8) and a hidden member (9);
- the off-origin, non-unit fit camera;
- reading-order expectations (`3+12`, not `12+3`) that would catch a plain sort (the
  implementer's M9);
- a dark-platform run (D19).

The one gap is a duplicate number in a group, which the plan's fixture list carries for the
planner and which the demo code never treats specially. That gap is acceptable here.
