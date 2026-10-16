# Task 8 report: the demo's bars, export, layout and events

Status: DONE_WITH_CONCERNS. Commits: 416faa0f (feat), ef9f6596 (tests ported), then two small test commits (OWN-busy; name-leads-bar + area-switch pointer). Last commit see git log.

## Gates (apps/restaurant_demo)
- flutter test: `00:25 +100: All tests passed!`
- flutter analyze: `No issues found! (ran in 4.0s)`
- dart format --output=none --set-exit-if-changed .: exit 0
- flutter build web last line: `✓ Built build/web`
- test/_pending/ deleted (empty).

## What landed
lib: badges.dart, export_flow.dart (demo dialog = onExportDialog), own_bar.dart (busy via pageFlowBusy), demo_keys.dart, pos_links.dart; main.dart/side_panel.dart/area.dart extended: Save/Revert/Reset layout/Fit, Link tables, pointer line, numbering warnings, badges + centre-7, own bar / own export dialog / plan-keys switches, area name in PlanServiceBar.leading (bar-area), printer, onExport, page-flow error log, dirty/moved/double-tap/unit-change/export/key log sources, layout kept on serviceChanges and restored on entering service and on PlanUnitsReplaced in service. Decision 14: Reset layout also splits groups; a group status goes with its group (also for groups dropped by a restore); the restored line appends "; groups G1 applied; groups G2 dropped" only when groups were applied/dropped (old text unchanged otherwise). exportName now lower-case (salon.png). No new colour literals (badges use scheme colours), so the allow-list is unchanged.

## Audit rows (all PORT unless noted)
demo_test: D3, D4, D6, D7, D9, D10, Dark theme, D16, D19b, DQ1, DQ2 -> layout_test; D14, D8 -> events_test. events: DE1-DE10 -> events_test. badges: DB1-DB8 -> badges_test. host_chrome: DH1-DH8 -> host_chrome_test (DH1/DH2/DH7 profile/find halves also covered by PF2-PF4/FIND in editor_profiles_test, checked; the rest ported). look: DL1/DL2/DL3 -> look_test. Pixel assertions kept as in the old file.
New: LAY-groups, LAY-reset (layout_test), OWN-busy (host_chrome_test), EX-area-own and EX-area-planner (export_area_test).
Fixture changes: duplicates/unnumbered/hidden by raw commands (relabel, putOnLayer, placeStool in demo_rig). Wall tool is disabled, not hidden, under Tables. `reveal` now scrolls from the top (the side panel grew; PF1/profile helper adjusted).

## Mutations (committed code, reverted, `git diff --quiet` passed)
M1 no restore on entering service -> D3, DE9, D10, LAY-groups. M2 no groups suffix in log -> LAY-groups. M3 Reset keeps group statuses -> LAY-reset. M4 restore keeps stale statuses -> LAY-groups. M5 no restore on plan replaced -> D16, DE7, DE8. M6 layout not kept -> DE7, DE8, DE9, D10 (+4). M7 own export reads current area at write time -> EX-area-own. M9 link includes shared labels -> DE1. M10 unlinked counts hidden -> DE1. M11 id from first of several -> DE10. M12 moved unsorted -> DE5. M13 pointer not cleared on mode change -> DE6. M14 hover null -> no line -> DE6, DE8. M15 no detail breakpoint -> DB1,2,3,5 (+2). M16 badge ignores focus -> DB3. M17 minutes frozen -> DB1. M18 badges interactive -> DB2. M19 shortcuts always on -> DH6. M21 own export ignores busy -> OWN-busy. M22 Save without markSaved -> D4. M23 Revert with nothing stored does nothing -> D10, DQ2. M24 exportName not lower-case -> D8. M25 own answer not remembered -> DH4. M26 onExportDialog unwired -> DH4. M27 name in trailing -> DH3 (after adding the order assertion). M28 POS selectionWidth 2 -> DL1, DL2. M29 read-only bar = full -> DH2. M30 no dirty log -> D6. M31 Reset shown in design -> D9. M32 added not logged -> DE7. M33 onPageFlowError unwired -> DH5. M34 own print error rethrown -> DH5. M35 centre-7 no-op -> DB4. M36 area switch keeps pointer -> DE6 (after strengthening).
Survivors: M8 (editor key constant) green for EX-area-planner: that path writes nothing because the flow dies with its editor; the test asserts the library rule, no demo mutation turns it red. M20 (demo keys ungated) is equivalent: with the plan's keys on the plan handles the key first.

## Concerns
- Revert with nothing stored (the state at start, since a save at init asserts during build and would also settle the plan's separator) makes a new EMPTY plan, per audit D10/DQ2; the old demo reverted to its sample JSON. A user pressing Revert before any Save empties the area. Alternative: Revert -> newPlan(build: sample). Say if wanted.
- Planner Export with an area switch while its dialog is up writes nothing (library rule); own-bar Export completes for the area it started in.
- main.dart is ~800 lines.
- No library defect found; nothing red for a library reason.
