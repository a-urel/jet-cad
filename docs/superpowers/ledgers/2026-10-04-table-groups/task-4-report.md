# Task 4 report — the toolbar (G5)

Implementer, 2026-10-04, on `claude/dreamy-gates-2kgh4o` from `9d80fc7`.

## Commits

- `5261b9c` feat(table-groups): Task 4 — Merge and Split on the service bar (not pushed)

## Files changed

- `packages/jet_cad_floor_plan/lib/src/host/service_view.dart` (+52): the two buttons, two `DerivedFlag`s, `_merge`/`_split`, header comment.
- `packages/jet_cad_floor_plan/test/host/table_groups_toolbar_test.dart`: **new**, 5 tests.

No other file touched. No existing test edited (view_test's service-bar tests pass unedited). Engine, render package, allocation tests, goldens untouched.

## What was built

- **Buttons.** After Undo, Redo and the existing 8 px gap: `_button('service-merge', 'Merge', Icons.merge_type, _canMerge, _merge)` and `_button('service-split', 'Split', Icons.call_split, _canSplit, _split)`, then another 8 px gap (only when at least one of them is shown), then Export/Print as before. `_button`'s signature is `(key, tooltip, icon, ValueListenable<bool> enabled, onPressed)`; "label" is the tooltip.
- **Visibility.** `final callbacks = widget.callbacks();` in `build`; each button is in an `if (callbacks.onXRequested != null)`. `FloorPlanView` passes a closure reading its latest `widget`, and a `FloorPlanView` rebuild rebuilds `ServiceView` (new widget, same `ObjectKey`), so a callback added or dropped later shows/hides the button (TB5 proves it; mutant J).
- **Flags.** `_canMerge = DerivedFlag(srcs, () => mergeQualifies(selectedTables.value, tableGroups.value))`; `_canSplit = DerivedFlag(srcs, () => selectedGroup.value != null)`; `srcs = [selectedTables, tableGroups, selectedGroup]` (the progress.md ruling: `selectedGroup` updates after the other two notify). `DerivedFlag` takes a list of sources, so no `Listenable.merge` object is needed. Both are touched in `initState` (so `dispose` never lazily builds one) and disposed in `dispose`.
- **Payloads.** Merge: `widget.callbacks().onMergeRequested?.call(_c.selectedTables.value)` — the controller's unmodifiable set, exactly the selected numbers. Split: reads `selectedGroup.value`, calls `onSplitRequested(id)` when non-null (a null guard instead of `!`; the button is disabled whenever it is null). Callbacks are re-read at press time (14c R-5).

## Tests added (`test/host/table_groups_toolbar_test.dart`)

Through the real `FloorPlanView`/`ServiceView` in the selection mode, the Task 2 fixture style: tables `12, 3, 7, 20, 5, 8, 9` in handle order, off-origin, turned/mirrored, 3 an asymmetric mirrored trapezoid, 8 on a visible locked layer, 9 on a hidden layer, **plus two unnumbered tables** (turned, one mirrored); a variant renames 5 to `3`. Camera `Transform2(0.06, 0, 0, -0.06, 690, 420)`. Selection by mouse taps (Shift adds) and `controller.select`. Group maps are not in id order (`G9` before `G7`). No pixels are read, so no palette fixture.

- **TB1** (M-TG-16) Merge disabled: nothing, one table (20), two unnumbered tables (also recomputed after a groups change), 20 plus an unnumbered, exactly one whole group (tap 7 → {3,7,12}; pressing the disabled button calls nothing); enabled: G9's 5 plus 20 → reports `{5, 20}`; two numbered tables with no groups → `{3, 20}`; a group plus a table → `{3, 7, 12, 20}` == `selectedTables.value`. No command, groups unchanged.
- **TB2** (M-TG-16) two tables sharing the duplicate number 3: `selectedTables == {3}`, 2 keys selected, Merge disabled (also after a groups-change recompute); adding 12 enables it, reports `{3, 12}`.
- **TB3** (M-TG-17 button half) G7 = {12, 3, 8 locked}, G9 = {9 hidden, 5}: part of a group (12 tapped before the groups were set) disabled; tap 3 → {3, 12} enabled, reports `split G7`; + 20 disabled (and Merge on); group + an unnumbered table disabled; 5 alone → G9 enabled, reports `split G9`.
- **TB4** (M-TG-17b through the widgets) {3, 20} by taps: (Merge on, Split off) → `setTableGroups(G2={20,3})` → (off, on), press reports `split G2` → G2 grows to {20,3,7} → (off, off) → two groups each holding part → (on, off) → `{}` → (on, off), press reports `{3, 20}`.
- **TB5** (M-TG-18) no merge/split callback → both absent, Undo/Redo/Print present; rebuilt with merge only → merge present, split absent; split only → the reverse; both → order Undo < Redo < Merge < Split < Print by x, tooltips 'Merge'/'Split', icons `merge_type`/`call_split`; the rebuilt bar still follows the selection (tap 7 → Split on, reports `split G7`).

## Mutant table

All fired by `cp` to scratch, scripted string edit of `service_view.dart`, `flutter test --no-pub test/host/table_groups_toolbar_test.dart`, `cp` back, `diff` exit 0 each time (script and logs: scratchpad `tg-task4/mut.py`, `muts.json`, `mut-*.log`). Line numbers are at `5261b9c` minus the 2-line header comment added last (flags ~:162-168, build ~:238, bar ~:265-273, payloads ~:349-356).

| # | Named | Change | Red tests | Real output excerpt |
|---|---|---|---|---|
| A | M-TG-16 | Merge flag `mergeQualifies(..)` → `selectedTables.value.length >= 2` | TB1, TB3, TB4, TB5 | TB1 `Expected: (bool, bool):<(false, true)> Actual: (bool, bool):<(true, true)>` (exactly one whole group) |
| B | M-TG-16 | → `activeSelection.keys.length >= 2` (counts tables) | TB1, TB2, TB3, TB4, TB5 | TB1/TB2 `Expected: (bool, bool):<(false, false)> Actual: (bool, bool):<(true, false)>` (two unnumbered / one duplicate number, recomputed) |
| L | M-TG-16 | → `selectedTables.value.isNotEmpty` | TB1..TB5 | TB1 line 198 reason `one table`, `Expected: (bool, bool):<(false, false)> Actual: (bool, bool):<(true, false)>` |
| C | M-TG-16 payload | Merge reports the selection minus grouped numbers | TB1 | `Expected: Set:['5', '20'] Actual: Set:['20'] Which: does not contain '5'` |
| D | M-TG-17 | Split flag → any group contains all selected numbers (selectable-blind) | TB3, TB4 | `Expected: (bool, bool):<(false, false)> Actual: (bool, bool):<(false, true)>` (part of a group) |
| E | M-TG-17 payload | Split reports `tableGroups.value.keys.first` | TB3 | `Expected: ['split G7'] Actual: ['split G9']` |
| F | M-TG-17b | both flags' sources `[selectedTables]` only | TB1, TB3, TB4, TB5 | TB4 `Expected: (bool, bool):<(false, true)> Actual: (bool, bool):<(true, false)>` |
| K | M-TG-17b | Merge's sources `[selectedTables]` only | TB4 | `Expected: (bool, bool):<(false, true)> Actual: (bool, bool):<(true, true)>` |
| G | notification-order trap | sources `[selectedTables, tableGroups]` (no `selectedGroup`) | TB1, TB3, TB4, TB5 | `Expected: (bool, bool):<(false, true)> Actual: (bool, bool):<(false, false)>` |
| H | M-TG-18 | drop `if (onMergeRequested != null)` | TB5 | `Expected: no matching candidates Actual: _KeyWidgetFinder:<Found 1 widget with key [<'service-merge'>]` |
| I | M-TG-18 | drop `if (onSplitRequested != null)` | TB5 | same, `service-split` |
| J | M-TG-18 (stale visibility) | callbacks read once into a `late final` field instead of in `build` | TB5 | `Expected: exactly one matching candidate Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'service-merge'>]: []>` |

Note on B: in its first run TB2 survived, because the flags listen only to the three notifiers, so a Shift-tap that adds a second table with an already selected number does not recompute anything. That is a masking effect, not a defect (the real rule depends only on those notifiers). TB1 and TB2 now force a recompute with a groups change over the same selection and re-check. After that B turns TB2 red.

## Gates (real counts, at `5261b9c`; the planner was re-run after the last comment-only edit)

| Package | flutter test | analyze | format |
|---|---|---|---|
| jet_cad_2d_flutter (render) | +1304 ~1 -7 (the 7 standing text-ladder goldens), unchanged | No issues | 0 changed |
| jet_cad_floor_plan | +1276 (1271 + 5) | No issues | 0 changed |
| jet_cad_restaurant_symbols | +94 | No issues | 0 changed |
| apps/floor_planner | +201 | No issues | 0 changed |
| apps/restaurant_demo | +18 | No issues | 0 changed |
| apps/dev_harness_2d | +82 | No issues | 0 changed |

## Proposed rulings

- **R-C4-1:** a second 8 px gap separates Merge/Split from Export/Print, and it is built only when at least one of the two is shown. With no callback the bar is exactly as before. Cost if wrong: one `SizedBox`.
- **R-C4-2:** `_split` guards with `if (id != null)` instead of `selectedGroup.value!`. It cannot fire while the button is disabled, so the behaviour is the same, and it cannot throw. Cost if wrong: none.
- **R-C4-3:** both flags are built eagerly in `initState`, even when no callback is set. That adds two listeners on each of three controller notifiers and one `mergeQualifies` per selection or groups change. This avoids the `late final` first touch in `dispose`. Cost if wrong: switch to nullable flags built on demand.

## Found, not fixed

- None in scope. TB5 confirms that a `FloorPlanView` rebuild rebuilds `ServiceView`'s bar (`ListenableBuilder` builder → new `ServiceView`, same key → `build`).

## For the reviewer

- Check that the flags' source list includes `selectedGroup` (mutant G), and that visibility is read in `build`, not cached (mutant J).
- TB3's "part of a group" comes from selecting 12 before the groups were set. With groups already set, a tap or `select` always expands to the whole group.
- The order check in TB5 uses x positions. Export is absent there because the view has no `onExport`. The existing V1 test covers Export.
