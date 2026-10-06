# Task 4 review — the toolbar (G5)

Reviewer, 2026-10-04. Commit `5261b9c` against `9d80fc7`. Worked in a detached
worktree at `/home/user/jet-cad/.worktrees/tg-review` (left in place). Scratch:
`scratchpad/tg-review4/` (gates.sh, gates.txt, mut.py, mut-*.log,
zz_review4_probe_test.dart, service_view.dart.orig).

## Verdict: Approved, with 2 minor findings (both test-only)

The code matches G5 line by line. All four re-fired named mutants are red.
Two mutants I wrote myself survive the committed suite: R-C4-1's "bar
identical" claim and the flags' dispose. In both cases the code is correct
but no test pins it. Each fix is a few lines of test, and I wrote and
checked both (findings 1 and 2).

## Scope and hygiene

- `git diff 9d80fc7..5261b9c --stat`: `service_view.dart` (+53/-1) and the new
  `test/host/table_groups_toolbar_test.dart` (+425). No other file.
- `git diff --stat -- packages/jet_cad_2d packages/jet_cad_2d_flutter` is
  **empty**. The engine and render packages are untouched, so render's full
  suite was not re-run, as the dispatch allowed.
- Allocation invariants are unedited. No `analysis_options.yaml` is committed
  (the only one modified is in the working tree, rewritten by `pub get`).
- No existing test was edited. `view_test.dart`'s service-bar tests (V1, V2,
  the print/export tests) pass unchanged.

## Spec check (G5)

| Point | Code | OK |
|---|---|---|
| Buttons after Redo, gap, keys `service-merge`/`service-split`, icons `merge_type`/`call_split` | service_view.dart:262-271 | yes |
| Hidden without callback, read in `build` | `final callbacks = widget.callbacks();` :238, `if (… != null)` :266/:269 | yes |
| Merge enabled by `mergeQualifies(selectedTables, tableGroups)` | :161-162 | yes |
| Split enabled iff `selectedGroup != null` | :165-166 | yes |
| Freshness: both flags listen to `selectedTables`, `tableGroups` **and** `selectedGroup` (the notification-order trap) | `_groupSources` :155-159, shared by both flags | yes |
| Merge payload exactly `selectedTables.value` (the controller's unmodifiable snapshot, replaced rather than mutated, so no aliasing) | `_merge` :349-350 | yes |
| Split payload the group id | `_split` :352-355 | yes |
| Callbacks re-read at press time (14c R-5) | `widget.callbacks()` inside `_merge`/`_split` | yes |
| Flags built in `initState`, disposed in `dispose` | :205-206, :218-219 | yes (no test pins the dispose, finding 2) |

The notification-order trap: `_refreshSelectedGroup` (controller :596-606)
runs after `_selectedTables` has notified. Adding an unnumbered table to a
whole-group selection leaves `selectedTables` unchanged and does not notify,
so only `selectedGroup` moves. Both flags listen to it, so Split recomputes.
Mutant G proves it.

A rebuild with a new callback: `FloorPlanView`'s `ListenableBuilder` builds a
new `ServiceView` widget with the same `ObjectKey(document)`, so the state
survives and `build` re-reads `callbacks()`. TB5 proves it, and mutant J
turns it red.

A new document key (`resetLayout`/`load`) disposes the old state. Its flags
remove their listeners from the controller's long-lived notifiers. My probe
P1 confirms this at `5261b9c`: after `resetLayout` `selectedGroup` still has
listeners (the new view), and after a switch to design it has none. P2
confirms that the bar of the newly built view follows the groups after
`resetLayout`.

## Rulings

- **R-C4-1 (second 8 px gap only when Merge or Split is shown): accept.** With
  no callbacks the `Row` children are exactly the base's. This is not pinned
  (finding 1).
- **R-C4-2 (`if (id != null)` instead of `!`): accept.** The button is enabled
  only after a notification that set `selectedGroup` non-null, so the guard
  never changes behaviour, and it cannot throw.
- **R-C4-3 (flags built eagerly): accept.** The cost is 2 × 3 listeners and one
  `mergeQualifies` per selection or groups notification. That is event rate,
  not the frame path, so invariant 1 does not apply. Building the flags lazily
  would be wrong anyway, because callbacks can appear at a later rebuild
  (TB5).

## Gates (my runs at `5261b9c`, `CI=true flutter test --no-pub`, then analyze and format)

| Package | test | analyze | format | Implementer |
|---|---|---|---|---|
| jet_cad_floor_plan | +1276 All passed | No issues | 0 changed (208 files) | +1276, matches |
| jet_cad_restaurant_symbols | +94 | No issues | 0 changed | +94, matches |
| apps/floor_planner | +201 | No issues | 0 changed | +201, matches |
| apps/restaurant_demo | +18 | No issues | 0 changed | +18, matches |
| apps/dev_harness_2d | +82 | No issues | 0 changed | +82, matches |
| jet_cad_2d_flutter (render) | not run: diff empty | | | +1304 ~1 -7 |

Planner +1276 = 1271 (after Task 3b) + 5 new tests. This matches the ledger.

## Mutants (re-fired by me)

Each one: `cp` the original to scratch, apply a scripted edit (the script
asserts exactly one match), run
`flutter test --no-pub test/host/table_groups_toolbar_test.dart` plus my probe
file, `cp` back. `diff` exited 0 after every mutant. Logs are in
`scratchpad/tg-review4/mut-*.log`.

| # | Change | Committed tests red | Probe red | Excerpt |
|---|---|---|---|---|
| G (named) | `_groupSources` without `_c.selectedGroup` | TB1, TB3, TB4, TB5 | P1, P2 | `Expected: (bool, bool):<(false, true)> Actual: (bool, bool):<(false, false)>` |
| J (named) | callbacks read once into `late final _cb` | TB5 | — | `Expected: exactly one matching candidate Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'service-merge'>]: []>` |
| B (named) | Merge flag → `_c.activeSelection.keys.length >= 2` | TB1, TB2, TB3, TB4, TB5 | P2 | `Actual: (bool, bool):<(true, false)>` |
| K (named) | Merge sources → `[_c.selectedTables]` | TB4 | — | `Actual: (bool, bool):<(true, true)>` |
| M1 (mine) | the trailing `SizedBox(width: 8)` unconditional (breaks R-C4-1) | **none** (toolbar test + all 22 of `view_test.dart`: +27 passed) | P3 | P3: `Expected: <8> Actual: <16.0>` |
| M2 (mine) | `_canMerge.dispose(); _canSplit.dispose();` deleted (leak on a new document key) | **none** (+6 -1, only P1) | P1 | `Expected: false Actual: <true>` (reason "no view left listening") |
| M3 (mine) | Split flag also requires `selectedTables.length >= 2` (a single-visible-member group) | TB3 | — | `Expected: (false, true) Actual: (false, false)` (G9, its 9 hidden) |

My results for G, J, B and K agree with the implementer's table.

## Fixtures

The fixtures are not degenerate. The camera is off-origin at 0.06 px/mm with
y flipped. Tables are turned and mirrored, and 3 is an asymmetric mirrored
trapezoid. Numbers are out of handle order (`12, 3, 7, 20, 5, 8, 9`) and
group maps are out of id order (`G9` before `G7`). One member is locked and
visible, one is hidden, two tables are unnumbered, and one variant duplicates
a number. Selection goes through real mouse taps (with Shift) and
`select`. No pixels are read, so no palette fixture is needed. The B-masking
note in the report is correct: a Shift-add of a second table with an
already-selected number notifies nothing. TB1 and TB2 force a recompute with
a groups change.

## Findings

1. **minor — R-C4-1 ("with no callbacks the bar is identical") is not pinned.**
   `service_view.dart:272-274`. Evidence: mutant M1 (the second gap made
   unconditional, which moves Print 8 px right on every host without the
   callbacks, against G7's "no groups, no change") passes the toolbar test
   and all of `view_test.dart`. TB5 checks only that the buttons are absent.
   **Fix (test-only):** in TB5's no-callback step, add
   ```dart
   expect(tester.getTopLeft(byKey('service-print')).dx -
       tester.getTopRight(byKey('service-redo')).dx, 8);
   ```
   I checked this as probe P3: it passes at `5261b9c` and goes red under M1
   (`Expected: <8> Actual: <16.0>`).

2. **minor — the flags' dispose (no leak when `ServiceView` is rebuilt under a
   new document key) is not pinned.** `service_view.dart:218-219`. Evidence:
   mutant M2 (both disposes deleted) passes all 5 committed tests. The
   leaked flags stay subscribed to the controller's long-lived
   `selectedTables`/`tableGroups`/`selectedGroup` after every `resetLayout`
   or `load`. **Fix (test-only):** the planner itself never listens to
   `selectedGroup` except through these flags, so `hasListeners` is a clean
   probe:
   ```dart
   // ignore_for_file: invalid_use_of_protected_member
   final h = await mount(tester);
   final sg = h.c.selectedGroup as ValueNotifier<String?>;
   expect(sg.hasListeners, isTrue);
   h.c.resetLayout(); await tester.pump(); await tester.pump();
   expect(sg.hasListeners, isTrue, reason: 'the new view listens');
   h.c.setMode(FloorPlanMode.design); await tester.pump(); await tester.pump();
   expect(sg.hasListeners, isFalse, reason: 'no view left listening');
   ```
   I checked this as probe P1: green at `5261b9c`, red under M2 and under G.
   The full probe file is `scratchpad/tg-review4/zz_review4_probe_test.dart`
   (P1-P3). I deleted it from the worktree after use.

Note (no action): `_canMerge` listens to `selectedGroup` without needing it.
This is harmless (`DerivedFlag` notifies only on a change), and sharing one
source list keeps the trap closed for both flags.
