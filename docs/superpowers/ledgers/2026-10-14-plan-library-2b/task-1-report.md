# Task 1 report: Engine E5

Commit: 1012413b `feat(engine): E5, a parametric type generates instances (2b S1)`

## Implemented
Followed the brief verbatim: GeneratedAttrib / GeneratedInstance / GeneratedDefinitionError / ParametricType.instances / _Registration.instancesOf (parametric_system.dart); _Survey instances/generated/leaves, owned gains generated ATTRIBs, _plan calls _planInstances, plus _attribRecord/_planInstances/_planAttributes/_instanceRemoval (regeneration.dart); GuardedType.instances forwarder (R-1, guard.dart); CS11 premise `drift(doc) == [hP1]` (R-4); CHANGELOG bullet; test support row_clients.dart and instances_test.dart (copied from the brief, then `dart format`).

Files: packages/jet_cad_2d/{CHANGELOG.md, lib/src/parametric/parametric_system.dart, lib/src/parametric/regeneration.dart, test/parametric/cascade_test.dart, test/parametric/instances_test.dart, test/parametric/support/row_clients.dart}; packages/jet_cad_2d_plan/lib/src/kits/guard.dart.

## TDD
RED (lib changes temporarily reverted via a saved patch, tests present):
`cd packages/jet_cad_2d && dart test test/parametric/instances_test.dart` printed first error
`test/parametric/support/row_clients.dart:177:8: Error: Type 'GeneratedInstance' not found.` then `Method not found: 'GeneratedAttrib'` (expected: types undefined). Patch re-applied.
GREEN: same command after `dart format .`: `00:00 +9: All tests passed!`

## Gates
- `dart test test/parametric`: `+178: All tests passed!`
- `dart test test/invariants/query_allocation_test.dart`: `+6: All tests passed!`
- `dart test` (jet_cad_2d): `+1331 -2: Some tests failed.` failing: generate_document_test.dart "both text fractions default to zero and change nothing" and "the default document is the one Plan 2 measured, byte for byte" = exactly the two standing_failures.txt lines for packages/jet_cad_2d.
- `dart analyze` jet_cad_2d: `No issues found!`; `dart format --output=none --set-exit-if-changed .`: exit 0.
- jet_cad_2d_plan: `flutter analyze` No issues found!; `flutter test` `+735: All tests passed!`; format exit 0.
- Dependents: jet_cad_floor_plan `+2008 ~4: All tests passed!`; jet_cad_2d_kit `+314: All tests passed!`; jet_cad_2d_flutter `+1450 ~1 -5`: the 5 failures are text_ladder_golden_test rungs 1-5 (RenderBackend.canvas), all listed in standing_failures.txt (the file also lists two lod-ladder entries that did not fail here).
- `git status --short` before commit: only this task's files (no analysis_options.yaml).

## Mutations (committed files; each reverted with git checkout, `git diff --quiet` exit 0 every time; runner script in scratchpad, ran `dart test ... --name <id>`)
All 23 red (exit 1), reverted, diff --quiet 0. Failing expectation quoted:
- M-E5-args-tag / args-dup (E5-args): `Expected: throws <Instance of 'ArgumentError'>` ... returned
- M-E5-args-copy (E5-args): `Expected: [Instance of 'GeneratedAttrib']` Actual two
- M-E5-default (E5-default): `UnimplementedError: instances`
- M-E5-call (E5-shrink): `Expected: an object with length of <12> Actual: []`
- M-E5-match (E5-shrink): handle list expectation `[1002, 1004, ...]` differs
- M-E5-surplus-leaves (E5-shrink): `Expected: null Actual: <14>` (seat 11's label left)
- M-E5-label-shape (E5-shrink): `Expected: ByBlockColor() Actual: ByLayerColor()`
- M-E5-eq-def/eq-transform/eq-layer (E5-noop): `Expected: Set:[2000] Actual: Set:[2000, 2002, ... 2010]`
- M-E5-eq-payload/eq-text (E5-noop): `Expected: Set:[2000] Actual: Set:[2000, 2003, ... 2011]`
- M-E5-tag-own (E5-tag): `Expected: 'UNIT' Actual: ''`
- M-E5-tag-missing (E5-tag): `Expected: [2003] Actual: [2003, 2012]`
- M-E5-tag-add (E5-tag): red (exit 1; output had no Expected line in my grep, failure is the missing ROW label)
- M-E5-owned (E5-tag): `Expected: throws GeneratedGeometryError ... Actual: returned <null>`
- M-E5-lowest (E5-dup-tag): `Expected: [1007] Actual: [2012]`
- M-E5-def (E5-def): `Expected: throws GeneratedDefinitionError ... threw StateError: no definition with handle 1092`
- M-E5-sort (E5-order): `Expected: true Actual: <false>`
- M-E5-layer-add (E5-layer): `Expected: <602> Actual: <1>`
- M-E5-layer-match (E5-layer): `Expected: <603> Actual: <602>`
- M-E5-label-layer (E5-layer): `Expected: <1> Actual: <603>`
After mutations: `dart test test/parametric` `+178: All tests passed!`; git status clean.

## Self-review
- No deviations from the brief; formatting only. No existing assertion changed except CS11's (R-4).
- Concern: none blocking. standing_failures lists two jet_cad_2d_flutter lod-ladder goldens that passed here (environmental, not related).

# Fix round 1

Finding: matched instance's definition/transform change untested.

Change (commit 4ef4a8d4 `test(engine): E5-move, a matched seat's definition and transform change`, test-only):
- test/parametric/support/row_clients.dart: `Row.copyWith` gains `spacing` and `bend`.
- test/parametric/instances_test.dart: new test `E5-move`. Row 2 (mirrored, curved, 5 seats with SeatNote components) regenerated with `seat: hStool, bend: 0.3125, spacing: 640.75`. Asserts: seat handles kept, each `definition == hStool`, each transform `equals(seatAt(next, i), exact)`, SeatNotes kept, one undo step added, `drift` empty; one undo restores `canon` bytes, drift empty. Premise lines assert new placements differ from old.

Covering runs: `dart test test/parametric` -> `+179: All tests passed!`; `dart analyze` -> No issues found!; `dart format --output=none --set-exit-if-changed .` -> exit 0 (after `dart format .`).

Mutations (committed regeneration.dart; reverted with git checkout, `git diff --quiet` exit 0 each):
- M-E5-def-set (delete SetInstanceDefinitionCommand add): E5-move red: `Expected: <600> Actual: <500>` ("seat 1").
- M-E5-transform-set (delete TransformNodeCommand add): E5-move red: `Expected: true Actual: <false>` ("seat 2").

Minor evidence, M-E5-tag-add re-run (`if (c == null) continue;`): `dart test ... --name E5-tag` prints `Bad state: Pattern matching error` at `test/parametric/instances_test.dart 224:7` (the `final [label, added] = leavesOf(doc, ss[k]);` destructure, the added ROW label missing). Reverted, diff --quiet exit 0.
