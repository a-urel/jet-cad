# Task 7 report

Status: DONE. Commit 35fb2868 `feat(plan): the service mode on phones and tablets` (base 8dba22f8).

Changes: PlanServiceView and PlanEditor gain `serviceSidePanel`; PlanServiceView gains `breakpoints`, `layout` (PlanEditor passes its own). Desktop: Row with Key('service-side-panel') 320 wide. Phone/tablet: Task 6's PlanDrawerHost (right drawer, 300, 85% cap), button Key('service-right-button') (Icons.tune, tooltip `openServicePanel`: Details / Details / Ayrintilar) as the bar's last item, pinned; the rest of the bar scrolls horizontally off desktop (no overflow at 320). Drawer closes on layout change and on leaving service; PlanEditor clears its design drawer when the mode is service (SL4). New string `openServicePanel` (en/de/tr + recording strings). CHANGELOG line added.

Tests: test/service/view/service_layout_test.dart (9): SL1 desktop, SL2 phone, SL3 none (1200/800/320), each for PlanServiceView and PlanEditor; SL4, SL5 (tablet + 320 no overflow, 272 cap), SL6 (PlanEditor passes layout/breakpoints).
Existing test/service/** green unedited (+351 before adding mine); no existing test edited.

Gates (plan package): flutter test --enable-vmservice: +1626 All tests passed; analyze: No issues found; format: 0 changed; check_kit_deps green.

Mutations (run on committed code, reverted with git checkout -- lib):
- M1 dock on every layout (`layout == desktop` -> `layout != null`): SL2 (both), SL4, SL5 red.
- M2 drop `_drawer = null` in PlanEditor._modes: SL4 red.
- M3 PlanEditor stops passing breakpoints+layout: SL6 red; M3b stops passing breakpoints only: SL6 red.
- M4 drop `_panelOpen = false` on layout change: NOT caught (no test) - small gap.

Concerns: with `serviceBar.visible: false` on phone/tablet there is no right button (the button lives in the bar); a host hiding the bar must open its panel itself. Panel width in drawer is 300 (D5 default), docked is 320.

## Fix round 1 (commit 20d46bb9 `test(plan): the service drawer closes on a layout change`)
- Added SL7 (phone panel open, resize to 1440x900 and back: no exception, no leftover drawer/barrier, docked 320 at desktop, selection and statuses kept).
- Mutation M4 (drop `_panelOpen = false` on layout change) on committed code: SL7 red (only that test); reverted, git diff clean.
- Documented concern 1 in the `serviceSidePanel` doc of PlanServiceView and PlanEditor: with `serviceBar.visible` false on phone/tablet there is no button and no way to open the panel.
- Gates: service tests +353 all passed, analyze clean, format 0 changed.
