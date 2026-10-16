# Task 9 + 11 + fix wave report: DONE_WITH_CONCERNS

Base 08533d65. Commits:
- e6e72a5b fix(restaurant_demo): the Salon's sheet is A3 at 1:50 so the room fits it
- f7e498a7 fix(restaurant_demo): Revert before any Save rebuilds the area's sample
- f34567a1 test(restaurant_demo): POS1 on macOS; the builds
- 026ad859 fix(restaurant_demo): the Salon's sheet keeps the plan's separator; D10 and DQ2 follow the sample Revert
- aafb2840 docs: 4a parity and audit closed, results, amendments, STATUS
Tree clean (`git status --short` empty).

## Fix wave
(a) Sheet: A3 at 1:50 (21000x14850) over the same centre; least invasive (walls, placements, SP1/SW2's 1200 mm unchanged; narrowing the room breaks SW2, 1:75 changes the scale). First version replaced the plan's page and dropped the German comma separator; DQ2 went red; second commit keeps the plan's own page via copyWith. Test SW3.
 Mutations: `_sheet(document)` commented out -> SW3 red; sheet from fresh PageComponent -> DQ2 red. Both reverted, git diff --quiet.
(b) Revert: Area carries `sample`; revert() with nothing stored -> newPlan(build: a.sample). Test DE11 (pristine Salon 11 tables; table 3 deleted then revert -> 11; Teras 6). Mutation newPlan() without build -> DE11 red; reverted clean. Ported D10 and DQ2 asserted the old empty result: changed to the sample (D10 'none' -> salonTables with a Decided note; DQ2 adds the tables assertion, separator assertion unchanged).

## Task 9
integration_test/pos_test.dart (+ integration_test dev dependency in pubspec). Run:
 00:00 +0: POS1 ...
 POS_PNG .../Containers/com.jetcad.restaurantDemo/Data/tmp/2026-10-16-restaurant-kit-pos.png 247547 bytes; export 71495 bytes
 00:05 +1: All tests passed!
PNG copied to docs/superpowers/notes/2026-10-16-restaurant-kit-pos.png (viewed: the room is inside the sheet). Mutation: POS id `<area>_<n>` in lib/pos_links.dart:43 -> POS1 red; reverted clean.
Builds: macos Release app 49.7MB; web built; ios simulator Runner.app built; apk --debug built (Android toolchain present).

## Task 11
Gates fresh (see the results note table): engine dart test +1343 -2 (generate_document_test x2, also red on a clean worktree of 8caf8e00, standing), flutter +1453 ~1 -5 (text ladder rungs 1-5 goldens, standing list), gpu +20, plan(vmservice) +1579, kit_restaurant +184, kit +403, architecture kit +655, integration(vmservice) +228, architecture_demo +176, restaurant_demo +102; analyze clean and format exit 0 everywhere.
check_kit_deps ok (3 packages); check_guide ok on the OLD guide (56 blocks); host probe at 026ad859 exit 0 (build/web 42M); dry-runs kit_restaurant and plan: 0 warnings.
Parity: 136 test ids cited by HAVE/RENAMED rows checked by script against the files (all exist; PF6 is in editor_bar_test, PP-1 in page_printer_test). The 10 PARTIAL/MISSING rows closed in "Closed (4a)"; ONE ROW OPEN: "new guide / host probe" (Task 10, yours). Audit: 95 rows closed by script from test names (file:line); COVERED SC1 checked at symbol_library_test.dart:398, symbol_section_test.dart:558/:367, units_test.dart:72; SNL-dropped covered by plan_symbol_loader_test.dart:24.
Results note, amendments (umbrella A13/A14/A10/A12 line; 3b N6-gap line), STATUS done.

## Concerns
- Task 10 pending: parity row open; docs/host-guide.md still old; check_guide/probe still old API.
- Standing failures on this machine (engine fingerprints, flutter text ladders), not from the branch.
- The engine packages changed (O1) - released with 4b.
- dart format on the repo was only run per package; no analysis_options.yaml committed (checked git status each time).
