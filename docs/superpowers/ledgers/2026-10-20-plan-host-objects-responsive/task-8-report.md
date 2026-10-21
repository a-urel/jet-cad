# Task 8 report: designing on a phone

Status: DONE (with concerns).

Commits (20d46bb9..004e2ae1):
- 64299e80 fix(integration): the recording strings copy gains the panel button words
- 004e2ae1 test(integration): designing on a phone (also adds jet_cad_2d_kit_restaurant ^0.1.0 to jet_cad_2d_integration, per R1)

Scenario (packages/jet_cad_2d_integration/test/phone/phone_design_test.dart, PH1), 375x812, all gestures PointerDeviceKind.touch:
left drawer -> Wall -> close drawer -> two taps 4 m apart (length within Tolerance(1e-6)); left drawer -> Symbols tab -> search -> restaurant.table.rect.four cell -> close -> tap canvas (one InstanceNode placed, off origin); drawer -> Tools tab -> Select -> tap table; right drawer -> symbol-rotation 30 (rotation 30 deg within 1e-6) -> host DropdownButton -> t1 (objectDetails.single.data == {'id':'t1'}, kind unit, symbolKey restaurant.table.rect.four).
No plan-library or architecture-kit defect blocked the scenario; the one fix is test support.

Fix: test/support/recording_plan_strings.dart lacked openToolsPanel/openPropertiesPanel/openServicePanel (added in T6), so leak_test and locale_separator_test did not compile and `flutter analyze` failed in jet_cad_2d_integration. Red before: `flutter analyze` error + `flutter test test/l10n` 2 load failures. Green after: l10n +9. Mutation: removing a member = analyze error (the interface contract).

Mutations on the scenario (committed code, reverted, git diff --quiet clean):
1. plan_controller.dart setObjectData made `false && ...` -> PH1 red.
2. editor_layout.dart layoutFor phone threshold `width < tablet` -> `< 100` -> PH1 red (chrome-left-button not found).

Gates (jet_cad_2d_integration): flutter test --enable-vmservice: "+234: All tests passed!"; flutter analyze: No issues found; dart format: 0 changed; check_kit_deps: "3 package(s) checked, none names the plan library or another kit". No other package touched.

Concerns:
- Picking a tool or a gallery cell in a phone drawer leaves the drawer open (D5 only closes on canvas tap/same button/Escape), so the user must close it before drawing; the scenario does that. A canvas tap on an open drawer closes it and is consumed. Possible UX follow-up (auto-close on tool/symbol pick), not blocking D7.
- Wall finishing on phone relies on switching tool (no Enter); the chain ends when Select is picked.

## Fix round 1 (controller review)
- Commit feat(plan): a pick in a phone drawer closes it: PlanEditor listens to `activeTool` and `armedSymbol`; a change while the LEFT drawer is open closes it (phone/tablet only, desktop has no drawer; right drawer untouched; tab switch/search pick nothing so keep it open). Re-picking the already-active tool does not close it (no change event).
- Test EL8 in jet_cad_2d_plan/test/editor/editor_layout_test.dart. Mutation: `_onPick` early-returns -> EL8 red, reverted clean.
- Separate commit: PH1 simplified (three dismiss taps removed; asserts the drawer is gone after the Wall and symbol picks). Wall-chain ending untouched.
- Gates: plan `flutter test --enable-vmservice` +1628 all passed, analyze clean, format 0 changed; integration +234 all passed, analyze clean, format 0 changed.

## Fix round 2
- Commit "test(plan): a second symbol pick closes the phone drawer": EL8 now arms demo.sofa.three, reopens the drawer with the symbol tool already active, picks demo.sofa.two, and asserts armedSymbol changed and the drawer closed.
- Mutation: `c.armedSymbol.addListener(_onPick);` commented out -> EL8 red; reverted, git diff clean.
- Gates: plan `flutter test --enable-vmservice` +1628 all passed, analyze clean, format 0 changed.
