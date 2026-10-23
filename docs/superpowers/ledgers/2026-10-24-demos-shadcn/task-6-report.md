# Task 6 report — BLOCKED (nothing committed)

Blocker: `cd apps/restaurant_demo && flutter test integration_test -d macos` FAILS
(exit 1): POS1 (integration_test/pos_test.dart:101, `pressInPanel(tester, 'own-bar')`).
tap() warns the offset (1363.8, 702.0) "would not hit test" on the ShadSwitch keyed
`own-bar`; the hit lands elsewhere in the panel (local 63.8, 637), so the switch does
not toggle, and the next line fails: finder for key `own-export` finds 0 widgets
("could not find any matching widgets", demo_rig.dart:194 press). On the real
binary's window the keyed ShadSwitch's box centre is not on the switch itself (the
same class as the Task 3 ruling "ShadSwitch wrapped in Align"; the widget tests at
their window size pass). Not touched: lib/ and the test are out of this task's scope.

Gates (real last lines, all at HEAD 4a129cb2):
- restaurant_demo flutter test: `01:17 +126: All tests passed!`; analyze `No issues found! (ran in 4.8s)`; format `Formatted 45 files (0 changed)`, exit 0
- architecture_demo flutter test: `01:26 +182: All tests passed!`; analyze `No issues found! (ran in 4.7s)`; format `Formatted 47 files (0 changed)`, exit 0
- jet_cad_2d_plan flutter test: `02:24 +1846 ~13: All tests passed!`
- jet_cad_2d_integration flutter test: `01:03 +240: All tests passed!`
- tool/screenshots flutter test: `00:08 +14: All tests passed!`
- tool/ci dart test: `00:57 +122: All tests passed!` (first run, in parallel with the demo suites: 2 api_boundary tests AB1/AB2 hit the 30 s timeout under load; rerun alone green)
- check_guide: `docs/host-guide.md: all 38 code blocks are in the host probe` (after my doc edits)
- check_screenshots: `screenshots: every rule holds`
- flutter build macos --debug: both `✓ Built build/macos/Build/Products/Debug/<demo>.app`, exit 0
- architecture_demo integration_test -d macos: `00:04 +1: All tests passed!`
- restaurant_demo integration_test -d macos: FAILED (above)

State: docs/host-guide.md edited (intro + §10 sentences), uncommitted. Results note,
STATUS.md and ledger archive NOT written (they must record the failure/fix).

## Update after fix a6913fc0
Re-run in apps/restaurant_demo: flutter test `00:34 +126: All tests passed!`; analyze `No issues found! (ran in 3.7s)`; format `Formatted 45 files (0 changed)`; integration_test -d macos `00:05 +1: All tests passed!`.
Finished: host-guide edit, results note, STATUS.md entry, ledger archive; committed.
