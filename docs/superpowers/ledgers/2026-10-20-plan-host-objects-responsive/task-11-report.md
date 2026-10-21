# Task 11 report (close)

Status: DONE. Commit ea002d52 "docs: the POS-host sub-project's results and STATUS" (results note, phone PNG, STATUS). No production code touched.

Gates (real last lines):
- jet_cad: `flutter test` 00:02 +95 ~6: All tests passed! (dart test cannot load it: it is a Flutter package); analyze No issues; format exit 0
- jet_cad_2d: 00:07 +1343 -2: Some tests failed. = the 2 standing generate_document_test failures; analyze/format clean
- jet_cad_2d_flutter: 00:25 +1453 ~1 -5: Some tests failed. = the 5 standing text_ladder rungs (canvas); analyze/format clean
- jet_cad_2d_gpu: +20 All passed; kit +409; kit_architecture +661; kit_restaurant +184; plan (--enable-vmservice) +1630; integration (--enable-vmservice) +240; all analyze "No issues found", format exit 0
- apps: dev_harness +10, dev_harness_2d +82, architecture_demo +176, restaurant_demo +112 all passed; analyze/format clean
- tool/screenshots +14 passed; tool/readme_probe (no tests dir) analyze/format clean; tool/ci dart test +114 passed
- check_guide: all 35 code blocks are in the host probe; check_readmes: all 2 code blocks; check_screenshots: every rule holds; check_kit_deps: 3 packages checked, none names the plan library or another kit; host_probe.sh exit 0 ("build/web is 42M")
- pub publish --dry-run: jet_cad_2d_kit, jet_cad_2d_kit_architecture, jet_cad_2d_plan: "Package has 0 warnings." each (after the commit)

Phone screenshot: docs/superpowers/notes/2026-10-20-plan-host-objects-phone.png, 375x812 at 2x, real Roboto (font manifest loaded), design mode, Salon: title bar, search and EN/DE/TR toggle, plan toolbar, rulers, the Salon walls with VIP (NE) and Garden (S) dashed outlines, tables 1-7 and the bar; the plan is not fitted to the width (right edge cut at 375 px). Taken with a throwaway test (deleted, not committed).

Findings for the human (in the results note): plan, kit_architecture, restaurant_demo, architecture_demo and integration pubspec floors on jet_cad_2d_kit are still ^0.1.0 although the plan uses PlanType.area/name: raise to ^0.1.1 at release. jet_cad_2d_kit_restaurant and the four engine packages: git diff main...HEAD empty.
