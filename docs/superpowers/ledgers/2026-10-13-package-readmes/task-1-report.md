# Task 1 report (R-10)

Implemented: barrel exports SymbolLibraryState/Loading/Ready/Failed and TableNumberProblem (placed by path order); B1 set extended with the five names; new test B-R10; host-guide bullet updated.
Extra (not in brief): the new exports made `import '.../src/symbols/symbol_library_state.dart'` unnecessary in test/example_test.dart, test/host/editor_panels_test.dart, test/host/editor_tools_test.dart (3 analyzer infos, unnecessary_import); removed those lines.

TDD: RED `flutter test test/host/barrel_test.dart` -> compile errors "'SymbolLibraryFailed' isn't a type.", "Couldn't find constructor 'SymbolLibraryLoading'.", "Undefined name 'TableNumberProblem'."; "Some tests failed."
GREEN same command -> "00:00 +7: All tests passed!"

Mutations (barrel copied aside to /private/tmp/claude-501/barrel.bak, restored, cmp clean):
- M-R10a (symbol_library_state export removed): first error `test/host/barrel_test.dart:95:17: Error: 'SymbolLibraryState' isn't a type.`
- M-R10b (table_numbers export removed): first error `test/host/barrel_test.dart:101:12: Error: Undefined name 'TableNumberProblem'.`

Gate (jet_cad_floor_plan): `flutter test --enable-vmservice` -> "+2012: All tests passed!"; expect_failures -> "packages/jet_cad_floor_plan: 2012 tests; the standing failures and skips, exactly"; flutter analyze -> "No issues found!"; dart format -> "Formatted 298 files (0 changed)"; check_guide -> "docs/host-guide.md: all 56 code blocks are in the host probe".
Files: docs/host-guide.md, packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart, test/host/barrel_test.dart, test/example_test.dart, test/host/editor_panels_test.dart, test/host/editor_tools_test.dart.
Self-review: diff read; no analysis_options.yaml in status. Concerns: none (the 3 import removals are outside the brief's file list).
