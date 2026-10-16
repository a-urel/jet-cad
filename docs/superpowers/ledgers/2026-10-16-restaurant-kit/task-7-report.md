# Task 7 report: the demo's service features

Status: DONE_WITH_CONCERNS (no library defect found; concerns below are scope decisions).
Commits: f2910334 `feat(restaurant_demo): service features on the new API`, 7bea05c8 `test(restaurant_demo): demo tests ported (service)`.

## What landed
- lib split (main.dart 510 lines): area.dart, statuses.dart, groups.dart, zones.dart, table_menu.dart, editor_profiles.dart, side_panel.dart, main.dart (shell + DemoHomeState).
- Design/Service toggle (`mode-toggle`), editor profiles (`DemoEditor` -> `PlanPermissions.full/unitsOnly/readOnly`, composed `permissions.copyWith(serviceMove: moves)`, readOnly keeps the service flags; Tables = no Layers/Page, `symbolFilter: isUnitSymbol`, `unitInspectorBuilder` with the POS id via `setUnitData`; readOnly bar print/export/zoom), selection by number + app-bar find (`find-table`, select + `centerOn`), table menu (right click and long press), statuses incl. random (seeded `RestaurantDemo(random:)`), merge/split with `G<n>` ids, zones + fade others, Moves / Long press / Floor drag switches, a minimal side panel (tables line, groups line, log).
- Decision: the log mechanism (`DemoHomeState.log`, `_log`) is back now, fed by the T7 features (mode, selected, status, random, merged, split, menu, tapped, group tapped, layout changed, found, linked), because ported assertions read it. Task 8 adds the remaining sources (dirty, hover, double tap, moved, floor tap, design changes, export, key, page-flow error).
- Decision: Ordered now carries a caption (like Bill) so the tr "Sipariş verildi" (15 graphemes) exercises the 12-grapheme cut; the colours moved to lib/statuses.dart and the three literals are on the colour invariant's allow-list.
- Fixtures: raw commands + helpers in test/support/demo_rig.dart (`relabel`, `putOnLayer`, `placementOf`, `unitScreen`, `unitCorners`, `rightClick`, `enterService`). The group tests relabel the Salon's units 1-8 as 12,3,7,20,5,11,8,9 (unit 7 on a locked layer, 8 hidden), units 9-11 renamed out of the way.

## Gates (apps/restaurant_demo, last lines of my runs)
- flutter test: `00:11 +53: All tests passed!`
- flutter analyze: `No issues found! (ran in 3.4s)`
- dart format --output=none --set-exit-if-changed .: exit 0
- Old packages untouched. app_shell_test SH1 adjusted (the area name now also appears in the side panel: finder scoped to `area-toggle`).

## Audit rows (demo_test section 4)
PORT done: D1, D2 (selection by number; `unit-section`), D5 -> service_modes_test; D11, D18 (with a moves-on control), D19 (minus its German "Reset layout" line, see D19b), D22, D23 -> service_modes_test; D12, D13 (now through the demo's own record), D17, D20, D21 -> statuses_test; D16 G6, D17b, D17 G6, D18 G6, D20 G6, D21 X2, D22 X2, D23 X2, D24 X2, D19 G6 -> groups_test; DZ1, DZ2 -> zones_test. D15: closed (SPLIT in T6: -open dropped, intent = sample_plans_test SP2, app_shell_test SH1/SH2).
Left in the reduced test/_pending/demo_pending.dart.txt for Task 8 (header lists them): D3, D4, D6, D7, D8, D9, D10, Dark theme row, D14, D16 (layout Revert), D19b (stub: German "Anordnung zurücksetzen" button), DQ1, DQ2. Reasons: layout save/restore, Save/Revert, export, events, numbering lines are Task 8's.
New: AR-isolated (area_isolation_test), ST-caption-tr / ST-caption-de (statuses_test), PF1-PF4 and FIND (editor_profiles_test; they also cover the editor-profile, POS-id and find halves of host_chrome's DH1, DH2, DH7 which stay for Task 8 to confirm and port the rest of: own bar, export dialog, keys, focus).

## Mutations (run on committed code; each reverted with `git checkout -- <file>`, `git diff --quiet` passed)
- M1 both areas share one controller -> red: AR-isolated.
- M2 plan library `UnitStatus` not cutting the caption (service_state.dart, reverted) -> red: ST-caption-de, ST-caption-tr.
- M3 Moves switch not composed into permissions -> red: PF1, D18.
- M4 random keeps previous statuses (no `statusNames.clear()`) -> red: D13 (first draft of D13 was green here: it set the stale statuses on the controller, not through the demo; fixed to go through the status button).
- M5 statuses not worded again on language change -> red: D21.
- M6 locked table treated as selectable -> red: D20.
- M7 next group id without +1 -> red: D16 G6, D17 G6, D17b, D19 G6 (+3).
- M8 split keeps the group status -> red: D16 G6, D19 G6.
- M9 merge keeps an emptied group's status -> red: D17 G6.
- M10 grow when any member overlaps -> red: D21 X2, D23 X2.
- M11 fade others ignored -> red: DZ1. M12 zone frames the page -> red: DZ1.
- M13 selection log unsorted -> red: D11.
- M14 Tables gallery unfiltered, M15 Layers/Page shown under Tables -> red: PF2.
- M16 POS id replaces the unit's data -> red: PF3.
- M17 find does not centre -> red: FIND.
- M18 group status never to the group -> red: D16 G6, D17 G6, D19 G6.
- M19 long press always toggles -> red: D22. M20 floor drag always pan -> red: D23.
- M21 readOnly drops the service flags -> red: PF1.
- M22 status caption not re-worded -> red: D19, D21, ST-caption-de, ST-caption-tr.
- M1b (Teras built from the Salon build) is SH2's mutation, green for AR-isolated by design.

## Concerns
- ST-caption-de has no demo status longer than 12 graphemes (de: Bestellt, Beim Essen, Rechnung); the German case drives a host-supplied caption through `setUnitStatus` and the demo's own flow for tr. The "overlay" is the service view's paint (the badges overlay is Task 8's); the assertions are the 12-grapheme cut and no exception.
- `toolbar-export` is absent from the readOnly bar until a host `onExport` is given (library rule), so PF4 asserts the bar's configured actions, not an Export button; Task 8 wires `onExport`.
- Under Tables the wall tool is shown disabled, not hidden (library palette behaviour); PF2 asserts `enabled == false`.
- Nothing red on the library for a library reason.

## Fix round 1
- Ordered is as the old demo's again: colour, no caption (lib/statuses.dart). The "Ordered carries a caption" decision above is withdrawn.
- ST-caption-tr and ST-caption-de both send a host caption through `setUnitStatus` ('Sipariş verildi', 'Zahlung ausstehend'), assert the 12-grapheme cut (a grapheme-cluster caption too) and no exception.
- Mutation: UnitStatus not cutting the caption (plan library, reverted, diff clean) -> red: ST-caption-de, ST-caption-tr.
- Gates: flutter test `+53: All tests passed!`, analyze clean, format exit 0.
