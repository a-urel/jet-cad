# Task 1 report: the symbol box family moves into the contract

Status: DONE_WITH_CONCERNS (one ordering deviation, no content deviation)
Commit: d742f063 refactor(kit): the symbol box family moves into the contract (spec 3a C1.4)

## Implemented
Steps 1-9 as briefed. New kit files: lib/src/model/symbol_box.dart (plan symbol_box.dart 16-151 + doc tail + 154-171,
isOrthonormal, placementTransform/_quarterTurn from placer 44-86), test/support/box_fixtures.dart,
test/model/symbol_box_test.dart, test/model/placement_transform_test.dart; model.dart export; placements.dart copy removed.
Plan library: symbol_box.dart git-rm'd, 8 lib files + 10 test files re-pointed at the kit barrel, symbol_box_test.dart cut to the
placed boxOfDefinition case, symbol_placer_test.dart group removed, new test/invariants/contract_names_test.dart. Spec amendment inserted.
`find lib -name '*.dart' | wc -l` in jet_cad_2d_plan after the delete: 100.

## TDD evidence
Step 1 precondition: purity_test "All tests passed!", plan `flutter analyze` "No issues found!", git status clean.
RED (deviation, see below): with the export line temporarily removed,
`flutter test test/model/symbol_box_test.dart test/model/placement_transform_test.dart` printed
`test/model/symbol_box_test.dart:29:1: Error: Type 'SymbolBox' not found.` / `:30:5: Error: Method not found: 'boxOfLeaves'.`
GREEN: same command with the export: `00:00 +28: All tests passed!`; kit `test/model/ test/kit/unit_label_test.dart test/invariants/purity_test.dart`: `+249: All tests passed!`.
Plan step-6 run: `+281: All tests passed!`, analyze `No issues found!`.

## Gates
- kit: flutter test `+368: All tests passed!`; analyze `No issues found!`; format exit 0.
- plan: `flutter test --enable-vmservice` `+1495: All tests passed!`; analyze `No issues found!`; format exit 0 (286 files, 0 changed).
- `dart run tool/ci/check_kit_deps.dart`: "kit dependencies: 1 package(s) checked, none names the plan library or another kit", exit 0.
- git status before commit: only this task's files, no analysis_options.yaml. After commit: clean.

## Mutations (committed files, each reverted with git checkout --, `git diff --quiet` exit 0 each time)
- M-SB-ortho (drop a·c+b·d term): symbol_box_test `SB-ortho ... [E]`, `Expected: false`.
- M-SB-export (delete export): `test/model/symbol_box_test.dart:29:1: Error: Type 'SymbolBox' not found.` (compile failure).
- M-SB-pure (import flutter/foundation): purity P1 `[E]`, `Actual: ['lib/src/model/symbol_box.dart: package:flutter/foundation.dart']`.
- M-SB-arc (delete the k<4 loop): `boxOfLeaves each side set by a different kind of leaf, far from the origin [E]` and the arc group (`crosses 0 rad only`, `π/2 only`, `π only`, `3π/2 only`, `negative start ... crosses -π/2` all [E]).
- M-SB-clean (drop clean()): placement_transform_test `P3 ... [E]` and `P23 ... [E]`.
- M-SB-owner (append `_isOrthonormal` in symbol_section.dart): `SB-one-owner ... [E]`, `Actual: ['lib/src/panels/symbol_section.dart: bool _isOrthonormal(']`; analyze warned `unused_element` at symbol_section.dart:273:6; gone after revert.

## Deviations
1. Order: I created the kit's lib file before running the Step 3 RED run, so the first run was green. I then reproduced the RED by temporarily deleting the export line (restored; diff shows only the intended added export line). Evidence above.
2. `git add` failed once on the already-staged deleted file path (git rm had staged it); the commit re-ran without that pathspec, deletion is in the commit.
3. Imports written as multi-line `show` lists where the line would exceed 80 columns (dart format output); no semantic difference.

## Concerns
None beyond the above. The plan's test line numbers in the brief matched the sources.
