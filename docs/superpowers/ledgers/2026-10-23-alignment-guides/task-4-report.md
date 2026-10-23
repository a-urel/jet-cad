# Task 4 report: the reference cache

## Built
- `packages/jet_cad_2d_plan/lib/src/guides/guide_references.dart`: `GuideReferenceCache` (`current`, `unionOf`) and top-level `worldBoxOf`.
- One pass over `tree.nodes` (ascending). An instance in `units().current` is a unit: skipped if seat, layer hidden (`UnitInfo.visible`), own node hidden, or its owner (root group) hidden; box = `UnitInfo.box` through `UnitInfo.toWorld`. Any other root instance without a `UnitComponent` is a non-unit: layer rule is `layers[node.layer]?.visible ?? true` (same as UnitIndex), own-node visibility, box from one lazy bucketing pass (leaves by owner, ATTRIBs skipped) + `boxOfLeaves`, memoised per definition per build. Singular/non-finite transform, empty/non-finite box skipped.
- Invalidation: `identical(units().current, last)`, `commands.stateId`, `tables.mutationRevision`.
- Test: `test/guides/guide_references_test.dart` (10 tests). Fixtures: 30 deg at (4000,-2500); 90 deg mirrored; 37 deg; generated stool under a root slab group turned 0.4 rad at (3100.5,-1700.25); all off origin.

## TDD evidence
Tests written with the impl moved away: compile failure (red):
`test/guides/guide_references_test.dart:57:3: Error: Type 'GuideReferenceCache' not found.` / `:114:5: Error: Method not found: 'worldBoxOf'.` Then impl restored: `+10: All tests passed!`.

## Mutations (command: perl edit of guide_references.dart, `flutter test test/guides/guide_references_test.dart`, file restored by cmp after each)
- M2 seat filter removed: RED `a seat and a table on a hidden layer...` Expected: [26, 30] Actual: [21, 26, 30]
- M3 parent transform dropped (`node.transform` for `unit.toWorld`): RED `a generated unit gets its group's transform...` Expected within <1e-9> of <2982.5370717641176> Actual: <-146.08560130787484>
- M4 never invalidated: RED `locking an object gives a new current...` Expected: false Actual: <true>; also `current is identical across reads; a placement and its undo move it` Expected: false Actual: <true>
- M5 hidden root group ignored: RED `a generated unit ... a hidden group skips it` Expected: <0> Actual: <1>
- M6 own node visibility ignored: RED (`+5 -1` on the generated-unit/hidden-node tests, "Some tests failed")
- M7 layer ignored for non-unit: RED (`+5 -1`)
- M8 layer ignored for unit: RED (`+8 -2`, unionOf test)
- M9 only three corners: RED (`+2 -5`, five tests)
- **M1 ATTRIB not skipped in bucketing: GREEN (equivalent mutant).** `boxOfLeaves` already skips attribute kinds, and a unit's label is owned by the instance, not the definition. The skip is kept as the brief states, as defence; the label test pins the unit box via `UnitInfo.box`.
- **M10 table revision removed from the key: GREEN (equivalent mutant).** `UnitIndexCache` already rebuilds on the same revision, so `identical(index, _index)` covers it. Kept to mirror the brief.

## Gate (cd packages/jet_cad_2d_plan)
`flutter test --enable-vmservice`: `+1668: All tests passed!` (1658 + 10). `flutter analyze`: `No issues found!`. `dart format --output=none --set-exit-if-changed .`: `Formatted 328 files (0 changed)`.

## Concerns
- Two equivalent mutants (M1, M10) above.
- `UnitInfo.box` for a unit is the definition box via UnitIndex (direct leaves, no nested instances), per the recorded deviation.
- A unit instance that is neither root nor in a recognised root group (nested) is not in the index, so it is not a reference.

## Fix round 1
F1: added `a symbol nested in a group is no reference; at the root it is` (a planter, no unit, one level inside a plain root group, and the same symbol at the root). Mutation: removed `if (node.parent != root) continue;` -> RED: `a symbol nested in a group is no reference; at the root it is` Expected: [22] Actual: [21, 22]. Reverted (git status shows only the test file modified). A symbol nested inside a definition is not a tree node, so there is nothing to test there. Gate: see commit; flutter test +1669 all passed, analyze clean, format 0 changed.
