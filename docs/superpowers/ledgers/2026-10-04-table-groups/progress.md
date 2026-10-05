# Table groups — progress ledger

**Plan:** docs/superpowers/plans/2026-10-04-table-groups.md (at `eed5856`).
**Spec:** docs/superpowers/specs/2026-10-04-table-groups-design.md rev 2, approved 2026-10-04 ("Onaylıyorum, planı yaz").
**Branch:** `claude/dreamy-gates-2kgh4o`, main checkout /home/user/jet-cad.
**Branch point gates** (code identical to `0e0ae65`, the dark theme branch merged with main — measured there, Flutter 3.47.6):
- render (`jet_cad_2d_flutter`): +1304 ~1 -7 (the 7 standing text-ladder goldens, 1 skip) — must stay unchanged (package not edited)
- planner (`jet_cad_floor_plan`): +1213
- restaurant symbols: +94
- app `floor_planner`: +201
- demo `restaurant_demo`: +18
- `dev_harness_2d`: +82
- engine: +1241 -2 standing (not edited)

## Tasks

| Task | Implementer commits | Review | Status |
|---|---|---|---|
| 1 Model and controller | `638048b`, `f98532f` (1b) | Approved (2 minor: Merge's group-id tag unpinned — 1b test by the controller, mutant red, restored, planner +1240; `selectedGroup` notification order documented) | done |
| 2 Select, tap, move | `c5eb454`, `e85ded9` (2b) | Approved (1 minor: stale-map guards at drag start and long press unpinned) -> 2b test-only by the controller (TG-G12..14 from the reviewer's probes; R-X1, R-X2 red, restored; planner +1254) | done |
| 3 The look | `b464204`, `9d80fc7` (3b) | Approved (1 minor: frame order by highest member survived — 3b interleaves TG-L5's groups, mutant red, restored, planner +1271; 3 notes) | done |
| 4 Toolbar | `5261b9c`, `cda29b7` (4b) | Approved (2 minor, test-only: R-C4-1's gap condition and the flags' dispose unpinned) -> 4b by the controller (TB6/TB7 from the reviewer's probes; M1, M2 red, restored; planner +1278) | done |
| 5 Demo | `eecc823`, `9c09121` (5b) | Approved (2 minor, test-only: Free on a group and R-C5-4 unpinned) -> 5b by the controller (D16 Free check, D20; R1, R2, R3 red, restored; demo +23). First review run lost to a container restart, re-run clean | done |
| 6 Exit | `0d931d3` | gates green (render unchanged, engine +1241 -2 standing), web ✓ both, Chromium smoke 10 PNGs, results note, spec amendments, STATUS | done |

## Rulings (with cost-if-wrong)

- **R-C1-1 (accepted by review 1):** `table_groups.dart` depends on Flutter only through `TableGroup` (the spec puts it in the host types file). Cost if wrong: move `TableGroup` to a Dart-only file.
- **R-C1-2 (accepted):** `selectedGroup` is always null in the design mode.
- **R-C1-3 (accepted):** numeric lead order ties on (stripped length, stripped string), then the original string, then the handle.
- **Note (review 1):** `selectedGroup` updates after `selectedTables`/`tableGroups` notify; **Task 4's toolbar listens to a merge of `selectedTables`, `tableGroups` and `selectedGroup`**. A raw layer edit leaves it stale until the next selection or document change, as `selectedTables` today (accepted).
- **R-C2-1 (accepted by review 2):** a half-selected group's drag grows only the moved set, not the selection; moved-but-unselected members show no preview outline and jump on release (Task 3 must not assume every moved table has an outline).
- **R-C2-2 (accepted):** the tool's group lookup is keyed on the identity of the picker's candidates list plus the groups map.
- **R-C2-3, R-C2-4 (accepted):** a modifier removal removes all visible members' keys; members come from the picker's candidates (singular transform / empty box excluded).
- **R-C3-1..R-C3-7 (accepted by review 3):** frames/labels from the picker's candidates; group painters take the `_paper` ARGB notifier (built once, so a palette by value would go stale); survey skipped only when both status maps are empty; one painter class with a layer mode, "rebuilds once" per painter; exact `arcTo` round joins; chip padding 5/2 px, radius 4; M-TG-22's chair line is a neighbour's chair edge. `debugRebuilds` added to the status painter as a test seam.
- **Notes (review 3):** `shouldRepaint` additions stay unpinned (painters built once); "frames stay put during a drag" holds by construction (optional guard test not added); a hull of ≥3 identical points draws no frame (unrealistic, not fixed).
- **R-C4-1..3 (accepted by review 4):** the second gap only when Merge or Split is shown; Split's press null-guards; both flags built eagerly (a callback can appear on a later rebuild).
- **R-C5-1 (accepted by review 5; spec amendment owed in Task 6):** the demo's grow rule is "the request touches exactly one group" instead of G6's "includes all selectable members of exactly one group" — a host cannot see locks or visibility. No selection-mode UI path leaves a group half-selected; the only way in is a host calling `setTableGroups` under a live selection (then the touched group grows). Consistent with G4 (a half-selected group moves whole).
- **F-1 (API finding, debt for Task 6):** a host cannot ask which members of a group are selectable (`selectableMembers(id)`, or locked/visible flags on `FloorPlanTable`, would close it). A leftover group made only of locked/hidden members can be cleared only by the POS.
- **R-C5-2..4 (accepted):** a merge that empties a group removes its status; one log line `Merged {…} as G<n>`, numbers sorted; a remainder keeps id and label even with one member.
- **Note (review 5):** render package not re-run in Task 5 (its diff is empty); Task 6 runs it.
