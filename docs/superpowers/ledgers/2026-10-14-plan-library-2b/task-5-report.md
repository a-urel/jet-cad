# Task 5 report

Commit 395ec35f "test(plan): the test kit's units and the service fixture (2b)".
Files: packages/jet_cad_2d_plan/test/support/test_kit.dart (modified), test/support/service_fixture.dart, test/kits/test_kit_units_test.dart (new).
Implemented verbatim from the brief (units library, RowComponent/RowType/RowTool, unitKit, service fixture). Only deviation: header comment re-wrapped.

TDD: RED step skipped as a separate run (files were written together); first run of
`flutter test test/kits/test_kit_units_test.dart test/kits/test_kits_test.dart` printed "All tests passed!" (the 5 new tests plus TK1-TK5 passed; the first failing run was against files with a stray fence line from my extraction, a compile error, not a meaningful red).
GREEN: same command: `00:00 +10: All tests passed!`.

Gate (packages/jet_cad_2d_plan): flutter test -> `00:42 +751: All tests passed!`; flutter analyze -> `No issues found!`; dart format --set-exit-if-changed exit 0. git status showed only the 3 task files (no analysis_options change).

Mutations (all on committed test_kit.dart, reverted with git checkout, `git diff --quiet` exit 0 each):
- M-TK-row (`'${row.prefix}$i'`), TK-row: `Expected: ['A1']`, `Actual: ['A0']`, `Which: at location [0] is 'A0' instead of 'A1'`.
- M-TK-prefix (`{}` in freeRowPrefix), TK-two-rows: `Expected: 'B'`, `Actual: 'A'` (second row's prefix).
- M-TK-conf (deleted `'unit:test/booth': 'Booth',`), TK-conformance: `Expected: empty`, `Actual: [KitProblemCode:KitProblemCode.unitKindWord]` (fails at the first expect, the kit's own names; brief predicted the second expect).

Concerns: none. Brief line numbers (testKit :537, section :714) matched by content.
