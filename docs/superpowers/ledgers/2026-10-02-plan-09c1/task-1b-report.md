# Task 1b report: review fixes for Task 1 (plan 09c-1)

Status: **done, gates green, committed (not pushed).**

## Commit
- `9414208` test(engine): pin the snapshot's order and restore's atomicity
  (parent `31d098d`, Task 2's concurrent commit). Two files, staged by explicit path:
  `packages/jet_cad_2d/test/document/definition_commands_test.dart`,
  `apps/floor_planner/lib/symbols/symbol_placer.dart`. No `analysis_options.yaml`
  (`packages/jet_cad/analysis_options.yaml` remains modified by pub get, unstaged).

## Changes (the review's three findings, exactly)
1. `definition_commands_test.dart`, group "D11 ComponentRegistry.snapshotOf and restore":
   `registry()` now registers `Tally` (`test.tally`) **before** `registerBuiltIns()`
   (`jet_cad.object_layer`), with a comment saying why. Registration order is no longer
   type-id order, so the snapshot's sort is exercised (test #8).
2. Test #7 ("an add whose snapshot cannot be restored throws and adds nothing"): the source
   registry now gets `registerBuiltIns()` and `Tally`, and the handle carries
   `ObjectLayer(kLayer)` as well as `Tally(7,'north')`. The target document registers
   ObjectLayer but not Tally. ObjectLayer sorts first, so a restore that wrote as it
   validated would leave the layer behind. The existing `expect(componentBytes(doc), components)`
   asserts that nothing changed on refusal, together with `definition(h) == null` and an
   unchanged undo depth.
3. `symbol_placer.dart:78-81` comment reworded: "A component can outlive its definition in a
   file saved before 09c (removing a definition now takes its components, spec D11, but
   leaves such orphans alone, and purge never clears a component), so the definition must
   still exist." The comment is the only change; the code is unchanged.

## Mutants (cp backup, mutate, run `test/document/definition_commands_test.dart`, cp back; `diff` exit 0 after each)
Baseline with the fixes: `00:00 +26: All tests passed!`

| Mutant | Site | Result | Real output |
|---|---|---|---|
| no sort: `registered.sort(...)` deleted | component.dart:166 | **red**: #8 ("registered components by type id, unknown payloads oldest first; restore puts each back exactly"), `00:00 +25 -1: Some tests failed.` | `Which: at location [0] is (String, Tally):<(test.tally, Instance of 'Tally')> instead of (String, ObjectLayer):<(jet_cad.object_layer, ObjectLayer(2A1))>` (test file :628) |
| interleaved restore: `store.set(...)` inside the validation loop, write loop removed | component.dart:189-201 | **red**: #7 ("an add whose snapshot cannot be restored throws and adds nothing (all-or-nothing)"), `00:00 +25 -1: Some tests failed.` | `Expected: '{}'` / `Actual: '{"jet_cad.object_layer":{"20979":{"layer":673}}}'` (test file :599, the `componentBytes(doc)` nothing-changed assertion) |

Logs: `/tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task1b/mut_nosort.txt`, `mut_interleaved.txt`.

## Gates (this container, `CI=true`, PATH with /root/flutter/bin)
- Engine `dart test`: `00:19 +1237 -2: Some tests failed.` The 2 are the standing
  `test/testing/generate_document_test.dart` ("the default document is the one Plan 2
  measured, byte for byte", "both text fractions default to zero and change nothing").
  The count is unchanged from Task 1 (`+1237 -2`): only fixtures changed, and no tests were added.
- Engine `dart analyze`: No issues found! `dart format`: 168 files (0 changed), exit 0.
- App `flutter test test/symbols/symbol_placer_test.dart`: `00:00 +25: All tests passed!`
- App `flutter analyze`: No issues found! `dart format`: 177 files (0 changed), exit 0
  (the count includes Task 2's symbol_box files).
- Render package: not touched, not re-run. The full app suite was not re-run either, because
  the only app change is a comment.
