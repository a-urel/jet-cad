# Task 2 report — selecting, tapping and moving (G4)

Implementer, 2026-10-04, on `claude/dreamy-gates-2kgh4o` from `f98532f`.

## Commits

- `c5eb454` feat(table-groups): Task 2 — a tap, a long press and a drag act on the whole group (not pushed)

## Files changed

- `packages/jet_cad_floor_plan/lib/src/service/table_select_tool.dart`: `ServiceCallbacks` gets three
  new fields. `TableSelectTool` takes `groups`. Adds the group lookup, the tap, the long press and the drag start.
- `packages/jet_cad_floor_plan/lib/src/host/service_view.dart`: passes `_c.tableGroups` to the tool.
- `packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart`: adds `onGroupTap`, `onMergeRequested` and
  `onSplitRequested` (optional, documented) and passes them through `ServiceCallbacks`.
- `packages/jet_cad_floor_plan/test/service/table_select_tool_test.dart`: mechanical changes only.
  - `groups: ValueNotifier(const {})`.
  - The three new record fields set to `null`.
  - **One import line**, `import 'package:flutter/foundation.dart' show ValueNotifier;`, which the new parameter
    needs because flutter_test does not export it.
  - No expectation was touched.
- `packages/jet_cad_floor_plan/test/host/table_groups_gesture_test.dart`: **new**, 11 tests.

No other file was touched. The engine, the render package, the allocation tests and the goldens were not edited.
No `ServiceCallbacks` record literal exists elsewhere (`view_test.dart` and the demo use `FloorPlanView`'s named
parameters, which are unchanged).

## What was built

- **Lookup** (`_groupLookup`).
  - Returns null while `groups.value` is empty. In that case every gesture takes the pre-groups path: no lookup
    is built and nothing is allocated (G7).
  - Otherwise it builds a `TableGroupLookup` (Task 1, reused) from the picker's candidates:
    `GroupTable(handle, number, visible: true, locked: c.locked)`. The picker lists visible tables only.
  - It also builds a handle-to-group map from `lookup.visibleMembers(id)`.
  - It is rebuilt when the **candidates list identity** or the **groups map identity** changes (R-C2-2).
- **Tap.**
  - A plain tap on an unlocked member does `replace(selectable member keys)`.
  - A modifier tap (Shift, Ctrl or ⌘) does one `replace`:
    - if the tapped key is selected, the selection minus every visible member's key;
    - otherwise the selection plus every selectable member's key.
  - A locked member selects nothing.
  - The callbacks are `onTableTap(number)`, then `onGroupTap(id, number)` when the hit is in a group, a locked
    member included.
  - A table in no group behaves as before (toggle or replace of itself).
- **Long press.** A member uses the same add-or-remove `replace`. A table in no group is toggled as before. No
  callback fires.
- **Drag start** (`_startDrag`).
  - Without a selected hit: the hit's group's selectable members, or `{hit}` for a table in no group, become the
    candidate selection.
  - `roots` are that selection's root-level keys. `involved` is the set of groups having a member among `roots`.
  - If any involved group `hasLockedVisibleMember`, the method returns false: the gesture is spent, the selection
    is **not** replaced, nothing moves and there is no pan.
  - Otherwise the selection is replaced (only when the hit was unselected). `_moving` is `roots` plus every
    involved group's selectable members, sorted by handle. There is one `Move` compound and one
    `onLayoutChanged`, as before.
  - The path with no groups goes through the same code with an empty map. It is equivalent to the old code, and
    ST1–ST17 pass unedited.

## Tests added (`test/host/table_groups_gesture_test.dart`)

The tests run through the real `FloorPlanView`/`ServiceView`.

**Fixture.**
- Tables numbered `12, 3, 7, 20, 5, 8, 9` in handle order, all off the origin, turned by multiples of 37° and/or
  mirrored.
- Table 3 is the asymmetric `trapezoidTable`, mirrored.
- Table 8 is on a visible locked layer and table 9 on a hidden layer. A variant renames 5 to `3` (file duplicate).
- The camera is `Transform2(0.06, 0, 0, -0.06, 690, 420)`, set after mount.

**Input.** Mouse taps and drags (`kind: mouse`), Shift/Ctrl/Meta through `sendKeyDownEvent`, and touch taps,
long presses and drags.

- **TG-G1** A plain tap on 12 with G7={12,3,7,9} selects {3,7,12} (9 is hidden) and reports `table 12`,
  `group G7 12`. A tap on 20 (no group) replaces. A finger tap on 7 selects G7 and reports `table 7`,
  `group G7 7`. (M-TG-4, M-TG-6)
- **TG-G2** With G2={5,8}, a tap on the locked 8 reports `table 8`, `group G2 8` and leaves the selection {20}.
  (M-TG-6, locked half)
- **TG-G3** `select({'3','20'})` before `setTableGroups(G7={12,3,7})`:
  - Shift tap on 7 gives {3,7,12,20};
  - Ctrl tap on 12 gives {20};
  - Cmd tap on 3 gives {3,7,12,20};
  - the callbacks fire in order. (M-TG-5)
- **TG-G4** The same fixture:
  - a mouse long press on 7 leaves nothing changed at 499 ms and gives {3,7,12,20} at 501 ms;
  - a touch long press on 12 gives {20};
  - nothing is reported and nothing is undone. (M-TG-5b)
- **TG-G5** With 20 selected, a drag on the unselected 3:
  - the selection becomes {3,7,12};
  - 12, 3 and 7 are all translated by the same world delta with the linear part unchanged;
  - 20 is unmoved;
  - undoDepth is 1 and layouts is 1;
  - one undo restores all three. (M-TG-7)
- **TG-G6** With G2={5,8} (8 locked) and 20 selected, a drag on 5:
  - nothing moves, undoDepth is 0 and layouts is 0;
  - the camera is unchanged (no pan);
  - the selection is still {20}, i.e. not replaced. (M-TG-8 and the "spent drag replaces" mutant)
- **TG-G7** Tap 5 (G2), Shift tap 20, drag on 20: nothing moves and the selection stays {5,20}. (M-TG-8b)
- **TG-G8** M-TG-5's fixture, drag on 3: 12, 3, 7 and 20 move by one delta, and 5 is unmoved. (M-TG-8c)
- **TG-G9** Tap 20, then `setTableGroups({'G4':{20,5}})`, then tap 20 again: {5,20} and `group G4 20`. Tap 12
  gives {12} (G7 is gone). `setTableGroups({})` then tap 5 gives {5}. (M-TG-17c)
- **TG-G10** G7={12,3,7,9}: tap 3 gives {3,7,12}. Then the layer `Hidden` is shown by a raw layer-table edit (no
  command; the picker rebuilds on the tables' revision) and tap 12 gives {3,7,9,12}. (M-C2-2, the lookup keyed on
  the candidates)
- **TG-G11** Duplicate variant, by touch: a drag on the *second* table numbered 3 selects 4 keys
  (`selectedTables` {3,7,12}) and moves all 4 by one delta in one Move. (M-TG-7, touch path)

## Gate results

Commands per package: `CI=true flutter test`, `CI=true flutter analyze`,
`CI=true dart format --output=none --set-exit-if-changed .`. The logs are in the scratch dir as
`tg-task2/gate-*.log`.

| Package | Test (real summary line) | Expected | Analyze | Format |
|---|---|---|---|---|
| render `jet_cad_2d_flutter` (not edited) | `01:13 +1304 ~1 -7: Some tests failed.` | +1304 ~1 -7 | No issues found | exit 0 (0 changed) |
| planner `jet_cad_floor_plan` | `03:41 +1251: All tests passed!` | +1240 after Task 1b, +11 new | No issues found | exit 0 (0 changed) |
| `jet_cad_restaurant_symbols` | `00:02 +94: All tests passed!` | +94 | No issues found | exit 0 |
| `apps/floor_planner` | `01:35 +201: All tests passed!` | +201 | No issues found | exit 0 |
| `apps/restaurant_demo` | `00:10 +18: All tests passed!` | +18 | No issues found | exit 0 |
| `apps/dev_harness_2d` | `00:36 +82: All tests passed!` | +82 | No issues found | exit 0 |

The render package's 7 failures are the standing set:
- `text_ladder_golden_test.dart` rungs 1 to 5 (canvas);
- `text_lod_ladder_golden_test.dart` rungs 1 and 2 (canvas).

Earlier notes call all of them "text-ladder", but they span the two files above. `analysis_options.yaml` is not
modified in this checkout and was not staged.

## Mutant table

**Method.** For each mutant:
1. `cp` the file to `tg-task2/<name>.bak`;
2. replace one exact string with Python (count must be 1);
3. run `flutter test test/host/table_groups_gesture_test.dart test/service/table_select_tool_test.dart`;
4. `cp` the backup back and check that `diff` exits 0 ("restored ok" printed for every one of the 21).

The driver is `tg-task2/mutants.py`. Its full output, with every `[E]` line, is in `tg-task2/mutants.log`. Line
numbers refer to the committed `table_select_tool.dart` (T).

| Mutant | Site | Change | Red tests (real `[E]`) |
|---|---|---|---|
| M-TG-4 plain tap selects one member | T:239 `_tap` | `: _memberKeys(lookup!, group)` → `: {key}` | TG-G1, TG-G9, TG-G10 |
| M-TG-5 modifier tap via toggle | T:237-239 | `replace(_toggle ? _addOrRemoveGroup(..) : ..)` → `if (_toggle) toggle(_memberKeys(..)) else replace(..)` | TG-G3 |
| M-TG-5b long press via toggle | T:324-325 `_longPress` | `replace(_addOrRemoveGroup(..))` → `toggle(_memberKeys(..))` | TG-G4 |
| M-TG-6a onGroupTap missing | T:249 | line removed | TG-G1, G2, G3, G9 |
| M-TG-6b onGroupTap wrong number | T:249 | `call(group, number)` → `call(group, groups.value[group]!.members.first)` | TG-G1, G2, G3 |
| M-TG-6c onGroupTap before onTableTap | T:248-249 | lines swapped | TG-G1, G2, G3, G9 |
| M-TG-6d locked member reports no group | T:233 | `lookup == null ? null :` → `lookup == null \|\| hit.locked ? null :` | TG-G2 |
| M-TG-6e locked member selects its group | T:234 | `if (!hit.locked)` → `if (!hit.locked \|\| group != null)` | TG-G2 |
| M-TG-7 drag moves only the hit table | T:182-186 `_startDrag` | `_moving = _sorted({...})` → `_moving = [hit.table.instance]` | TG-G5, TG-G8, TG-G11, ST3 |
| M-TG-7b drag start selects the hit only | T:172 | `: _memberKeys(lookup!, hitGroup)` → `: {key}` | TG-G5, TG-G11 |
| M-TG-8 locked group moved | T:180 | the `involved.any(hasLockedVisibleMember)` return removed | TG-G6, TG-G7 |
| M-TG-8b only the hit's group checked | T:180 | `involved.any(..)` → `hitGroup != null && lookup!.hasLockedVisibleMember(hitGroup)` | TG-G7 |
| M-TG-8c half-selected group moved in part | T:184-185 | the involved-groups expansion removed from `_moving` | TG-G8 |
| M-C2-1 spent drag replaces the selection | T:180-181 | `if (replace) ctx.selection.replace(selected);` moved above the locked check | TG-G6 |
| M-TG-17c lookup ignores the groups map | T:282 | `!identical(_lookupGroups, map)` → `false` | TG-G9 |
| M-C2-2 lookup ignores the candidates | T:281 | `!identical(_lookupCandidates, candidates) \|\|` removed | TG-G10 |
| M-C2-3 a modifier tap always adds | T:263 `_addOrRemoveGroup` | `if (selection.contains(tapped))` → `if (false)` | TG-G3, TG-G4 |
| M-C2-4 candidates' lock ignored | T:290 | `locked: c.locked` → `locked: false` | TG-G6, TG-G7 |
| M-C2-5 FloorPlanView drops onGroupTap | `floor_plan_view.dart:136` | `onGroupTap: widget.onGroupTap` → `onGroupTap: null` | TG-G1, G2, G3, G9 |
| M-C2-6 ServiceView passes no groups | `service_view.dart:61` | `groups: _c.tableGroups` → `groups: ValueNotifier(const {})` | all 11 TG-G tests |
| M-C2-7 removal misses members | T:265 | `visibleMembers(id)` → `visibleMembers(id).take(1)` | TG-G3, TG-G4 |

21 fired, 21 killed, 0 survivors.

**Real excerpts** from `tg-task2/<name>.out`:

```
M-TG-5 (TG-G3):
Expected: Set:[ SelectionKey( 1C), SelectionKey( 1E), SelectionKey( 18), SelectionKey( 20) ]
  Actual: Set:[ SelectionKey( 20), SelectionKey( 18), SelectionKey( 1E) ]
   Which: does not contain SelectionKey:<SelectionKey( 1C)>
M-TG-8c (TG-G8):
Expected: a numeric value within <0.000001> of <-2159.957524751003>
  Actual: <-1459.9575247510027>
   Which: differs by <700.0000000000002>
12: x
M-C2-1 (TG-G6):
Expected: Set:[SelectionKey:SelectionKey( 20)]
  Actual: Set:[SelectionKey:SelectionKey( 22)]
not replaced
M-TG-17c (TG-G9):
Expected: Set:[SelectionKey:SelectionKey( 22), SelectionKey:SelectionKey( 20)]
  Actual: Set:[SelectionKey:SelectionKey( 20)]
```

The summary lines all read `Some tests failed.`, with exit 1 for each mutant.

## Proposed rulings

- **R-C2-1. M-TG-8c: the selection itself is not expanded at drag start; only `_moving` is.**
  - The spec words it as "`_moving` is the root-level selected keys expanded …", and says nothing about the
    selection. So after the drag, a half-selected group remains half selected (7 and 12 moved but unselected).
  - During that drag only the selected tables' outlines follow the preview.
  - Cost if wrong: one `ctx.selection.replace(expanded)` line, and an assertion in TG-G8.
- **R-C2-2. The lookup is keyed on the identity of `picker.candidates` instead of reading `(stateId, table
  revision)` directly.**
  - The picker returns a new list exactly when its key moves (`table_picker.dart:154-163`), so this is the same
    key without duplicating it.
  - Cost if wrong: two int fields.
- **R-C2-3. A modifier removal removes the keys of all the group's *visible* members (locked ones included), and
  an addition adds the *selectable* ones.**
  - A locked key is never in a selection, so this only makes the removal total.
  - Cost if wrong: none observable.
- **R-C2-4. The tool's members come from the picker's candidates**, as the brief and the spec say. A member with a
  singular transform or an empty box is therefore neither moved nor selected by a tap, but `controller.select`
  (Task 1, from the survey) still selects it by number.
  - That is the same divergence the picker has today for such tables.
  - Cost if wrong: such degenerate tables would need adding from the survey.
- **Mechanical-change note.** `table_select_tool_test.dart` gained one import line (`ValueNotifier`) besides the
  constructor parameter and the record fields. The parameter cannot be passed without it. No expectation changed.

## Found, not fixed

- Nothing in scope.
- `onMergeRequested` and `onSplitRequested` are plumbed but unused until Task 4.

## Where the reviewer should look hardest

- **`_startDrag`'s unified path** (T:153-190).
  - The no-group case now goes through the same code with an empty map. It is the old behaviour, and ST3/ST4/ST7
    pass unedited.
  - Check the equivalence: `replace({key})` vs `replace([key])`, and `_moving` from `roots` vs from
    `ctx.selection.keys` after the replace.
- **`_groupLookup` returns null whenever the groups map is empty**, but `_groupByHandle` is not cleared then.
  - Every read is guarded: `lookup == null ? null : …` in `_tap`/`_longPress`, and the `const {}` substitute in
    `_startDrag`.
  - A change that reads `_groupByHandle` without the guard would see stale groups.
- **The locked check runs before any selection change.** M-C2-1 pins this.
- **TG-G4's mouse long press** relies on `startGesture(kind: mouse)` reaching the tool without the touch
  hold-back (500 ms). The touch half uses the hold-back path (V19's pattern).
