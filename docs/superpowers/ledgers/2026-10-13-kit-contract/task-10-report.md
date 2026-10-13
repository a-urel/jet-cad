# Task 10 report

Implemented: docs/kits.md, packages/jet_cad_2d_kit/README.md, CHANGELOG.md, example/example.dart, test/authoring/example_test.dart (brief verbatim). Commit 8cff5dd5.

Note: the RED step (compile error before the example existed) was skipped: test and example were created together.

Verification:
- `flutter test test/authoring/example_test.dart`: `+1: All tests passed!`
- `dart run example/example.dart`: `cafe.table.round-two@1: 5 leaves, Yuvarlak masa, 2 kişilik, capacity 2`
- Gate: `flutter test` -> `+225: All tests passed!`; `flutter analyze` -> `No issues found!`; `dart format --set-exit-if-changed` exit 0.
- Names: every listed name grepped under lib/ or example/ (all found). The catalog block in docs/kits.md and README is a verbatim substring of the example (python check True/True). No bare `cafeCatalog`; `Bar` appears only in the section 5 word-id table row (line 105: "two kits may both have a `Bar`"), the brief called it section 4 prose.
- Mutation M-E1 (chairsAround ... 2 -> 3), after commit: E1 red with
  `Expected: an object with length of <5>` / `Actual: [`, `Some tests failed.`
  Reverted with git checkout; `git diff --quiet` rc=0.

## Fix round 1
Added example/cafe_kit.dart, example/generate_cafe.dart (creates assets/ and test/ first), example/cafe_conformance_test.dart; docs/kits.md sections 6-8 quote them verbatim with imports (plus a sentence naming the files).
Verified: `dart run example/generate_cafe.dart` then `flutter test example/cafe_conformance_test.dart` -> `+1: All tests passed!` (generated files removed afterwards).
Gate: `flutter test` all passing, `flutter analyze` -> `No issues found!`, format exit 0 (outputs above in the run; see commit).
