# Task 6 report: the demo's new base and the samples

Status: DONE_WITH_CONCERNS. Commits: 3ce50a94 `feat(restaurant_demo): the new base and the samples as builds`, then a one-line test rename (see git log).

## What landed
- pubspec: jet_cad_2d_plan, jet_cad_2d_kit_architecture, jet_cad_2d_kit_restaurant (+ jet_cad_2d, jet_cad_2d_kit, vector_math for the samples); no old package, no assets/plans, font from jet_cad_2d_plan. `assets/plans/*.json` and UPDATE_SAMPLES deleted.
- `lib/samples/place_tables.dart` (TablePlacer: definition copy by key, root instance via placementTransform, `unitLabelAttrib` UNIT label numbered in build order), `salon.dart`, `teras.dart` as PlanBuilds.
- `lib/main.dart` = shell only: two Areas (each `PlanController(kits: [architectureKit, restaurantKit], build: ...)`), area / language / look toggles, PlanEditor of the current area (keyed by area). `demo_theme.dart` ported by rename (FloorPlanTheme -> PlanTheme, posPlanTheme, kPosPlanLight/Dark). `demo_strings.dart` untouched.
- Tests: boundary_test (N1, N2), sample_plans_test (SP1-SP4 x2), app_shell_test (SH1-3), symbols_load_test (RL15), corner_booth_test (SC3), `test/support/demo_rig.dart` (pumpDemo, byKey, the one unit finder `unitInstance`/`unitLabels`, `definitionName`).
- Old tests moved aside, no case dropped: `test/_pending/{demo,events,badges,host_chrome,look}_pending.dart.txt` (`.txt` so the analyzer does not read old-package imports; flutter test never ran them). demo -> Task 7; events, badges, host_chrome, look -> Task 8. Each has a header. Task 11: `test/_pending/` must be empty.

## Facts
- The old JSON plans held only instances (13 Salon, 9 Teras): no wall, door or window. None were invented; the samples are the old placements (transforms in sample_plans_test are copied from the old JSON and pass byte-for-byte on translation). No architecture table was used as a served table; all are restaurant keys.
- Teras units 1-4 round four-seat, 5-6 high tables; planters are non-units (matches D15's 1..6).
- A label's build-time stamp (`instanceToWorld`) is re-stamped by the library on any later command; replacing it with a different transform did not turn any test red (equivalent mutation, noted, not tested).

## Gates (apps/restaurant_demo)
- flutter test: `00:02 +15: All tests passed!`
- flutter analyze: `No issues found!`
- dart format --output=none --set-exit-if-changed .: exit 0
- flutter build macos last line: `✓ Built build/macos/Build/Products/Release/restaurant_demo.app (48.5MB)`

## Mutations (run on committed code, reverted, `git diff --quiet` passed each time)
1. Salon: rect.four(7500) and round.six(2700) swapped in build order -> red: Salon SP1, Salon SP2.
2. `import 'package:jet_cad_floor_plan/...'` added to lib/main.dart -> red: N1.
3. TablePlacer ignores quarterTurns -> red: SC3 (premise 90 degrees).
4. restaurant kit's `symbols: const []` (kit file, reverted) -> red: RL15.
5. Teras area built over a second controller on buildSalon (Teras becomes the Salon plan) -> red: SH2.
6. Numbering stops incrementing (`_next` not `_next++`) -> red: Salon SP2, Teras SP2, SC3, SH2.

## Audit rows
- sample_plans_test SPLIT: PORT done (SP1-SP4: table written out, numbers, capacities, clean open, save/load/save byte-stable); JSON compare + UPDATE_SAMPLES DROPPED. Library halves COVERED, not re-opened.
- D15 intent (Salon 1..11, Teras 1..6, once each, no label warning): covered here by SP2 (`labelWarnings` empty) and SH1/SH2; the D15 case itself stays in demo_pending for Task 7 to close.
- RL15 -> symbols_load_test (41 + 69, 6 + 6 categories in kit order, no diagnostic). SC3 -> corner_booth_test through PlanPropertyPanel on the real asset.

## What Tasks 7 / 8 must restore
Task 7: Design/Service toggle, editor profiles and permissions, selection and find, table menu, statuses (random), merge/split, POS-id linking (host data), zones and fade; AR-isolated and ST-caption-de/tr. Task 8: demo's own service bar (`bar-area`), export/print + export dialog (pageFlowBusy), save/revert/restore layout, events log, badges, search field, keys-off mode, side panel; EX-area. `Area` is now just (name, controller); `RestaurantDemo` no longer takes `plans`/`random`/`printer`; `DemoHome` takes look/onLook/onLocale only. Keys kept: area-toggle/area-N, language-toggle/lang-xx, look-toggle/look-standard/look-pos.

## Concerns
- `packages/jet_cad_floor_plan/test/invariants/theme_colours_test.dart` (old package, not mine to touch) goes red: its allow-list names the old demo's main.dart literals `Color(0x99FFB300)`, `0x9943A047`, `0x99E53935` (stale: the badge code is gone) and its mutant test reads that file. It stays red until Task 8 restores those literals or the controller edits/retires that test. Not run in the demo's gate; the CLAUDE.md gate for that package is not in this task's list.
- Salon/Teras have no walls (faithful to the old plans); say if the human wants walls added.
- `jet_cad_2d_flutter` stays a dev dependency, unused by today's tests, for Tasks 7/8's ported tests.

## Fix round 1
1. Colour invariant: `apps/restaurant_demo/test/invariants/theme_colours_test.dart` (same three patterns, stale-entry rule, missing-root failure, root `lib` only; whole-file allow `lib/demo_theme.dart`, literal `Colors.teal` in main.dart). The old package's test lost exactly the demo root, the demo_theme file entry, the four main.dart entries and the `const demo` case; that case's intent (a second literal in an allow-listed file goes red) is kept there on floor_planner's main.dart, and the demo's copy asserts it for the demo. Old suite: `00:01 +3: All tests passed!`. Mutations: `const _stray = Color(0xFF000000);` appended to lib/main.dart -> red (M-DT-14 and the mutants test); an extra stale allow entry -> red (same two). Task 8 adds entries if it restores badge literals.
2. Salon room: four 250 mm walls (WallParams, centre) built before the tables, centrelines x 400..15250, y -250..10500 (mm from the sheet corner) = 1200 mm clear of the furniture box (x 1765..13900, y 1075..9150), so the room is a little wider than the A4 sheet; door (1100) in the south long wall, two windows (1800) in the north wall. Teras unchanged. Tests SW1 (4 walls, 1 door, 2 windows, door and windows on opposite long walls, Teras none) and SW2 (every table box corner inside the inner faces, min margin >= 1200, numbers 1-11, first wall handle below first table). Mutation: east wall pulled in to 12000 -> red SW2. SP1-SP4 unchanged and green.
Gates: demo `00:03 +20: All tests passed!`, analyze clean, format exit 0.
