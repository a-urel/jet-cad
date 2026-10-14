# Task 5 report (R2, R7, R3, R5)

Commit: 06ee312e on feat/plan-library-2a. Status: DONE.

## Implemented
Brief transcribed as written (diffs applied with `git apply`, example and test files copied verbatim from the brief): `optionalField`, `retired` on SymbolComponent/CatalogSymbol/builder, rule 11 width test + `_perimeter`, `conformance` typeIds/toolIds/propertyIds, `example/cafe_code.dart`, `test/kit/example_code_test.dart`, docs/kits.md (section 10 + edits), README, CHANGELOG, DOC1 count 4 -> 6.

## TDD evidence
- Step 1 RED: the three test files failed to compile: `test/model/symbol_component_test.dart:31:7: Error: No named parameter with the name 'retired'.`, `The getter 'retired' isn't defined for the type 'SymbolComponent'` (builder/snapshot tests fail the same way through CatalogSymbol/SymbolComponent).
- Step 2 GREEN: `flutter test test/model test/authoring` -> `+237: All tests passed!` (C7, F0 included).
- Step 3 RED (symbol_library_test): exactly three `[E]`: V11c a closed outline on one diagonal, off the origin; R7-1 a 600 mm by 1e-9 mm sliver is refused; R7-2 a triangle of area 2 * linear² is refused. R7-3/R7-4 green.
- Step 4 GREEN: `+161: All tests passed!` (symbol_library_test + test/authoring).
- Step 5 RED: `test/authoring/conformance_test.dart:414:11: Error: No named parameter with the name 'typeIds'.`
- Step 6 GREEN: `flutter test test/authoring` -> `+53: All tests passed!`.
- Step 7: `example_code_test.dart` -> `+1: All tests passed!`.

## Gates
- packages/jet_cad_2d_kit `flutter test`: `+312: All tests passed!`; `flutter analyze`: `No issues found!`; `dart format --output=none --set-exit-if-changed .` exit 0 (66 files, 0 changed); `dart run example/example.dart` prints its one line (`cafe.table.round-two@1: 5 leaves, Yuvarlak masa, 2 kişilik, capacity 2`).
- DOC1 (the docs-sync test, doc_snippets_test) passes inside the 312 with 6 blocks.
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 1 package(s) checked, none names the plan library or another kit`.
- `cd tool/ci && dart test`: `+116: All tests passed!`.
- `git status --short` after commit: clean. No analysis_options.yaml staged.

## Mutations (committed files; each reverted with git checkout, `git diff --quiet` exit 0 every time)
All run as brief states; each test went red (exit 1, `[E]` line):
M-R2a (R2-1), M-R2a(C7) (C7 key order and text pinned), M-R2a(F0) (F0 the sample kit conforms), M-R2b (R2-2), M-R2c (R2-2), M-R2d (R2-3), M-R2e (R2-5), M-R2f (snapshot R2-6), M-R2f(R2-7) (conformance R2-7), M-R3a, M-R3b, M-R3c, M-R3f (all R3-2), M-R3d (R3-3), M-R3e (R3-4), M-R7a (R7-1), M-R7a(R7-2) (R7-2), M-R7c (R7-3), M-V11c (V11c), M-R5 (R5-1), M-DOC1(R5) (DOC1 kits.md).

## Deviations from the brief
- M-R2f: snapshot.dart's line is indented 6 spaces, not 8 as in the brief's snippet; the mutation text was adjusted accordingly. M-R7*/M-R5 snippets likewise adjusted to the file's actual indentation (10 spaces for rule 11 lines, 4 for `min:`). No source change.
- "docs-sync test": no file of that name exists; I took it to be DOC1 in doc_snippets_test (passes).

## Self-review / concerns
None known. Transcript above is quoted from actual command output; the mutation driver script lived in the scratchpad (not committed).
