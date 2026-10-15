# Task 2 report: Engine E5 guard, seeding, adds, dissolve gap

Commit: bcf4d6b8 `feat(engine): E5, the guard for generated instances (2b S1)`.

## Implemented
- regeneration.dart: `_Survey.nested` (survey walk filled), `_refused` rewritten (owned-entity branch, generated-instance node branch by InstanceNode ==, add checks for entities onto a generated instance and nodes/GroupNodes into a live object), seeds comment in `_run` (no code change), `_subtreeRemoval` removes instance-owned entities (survey for d's instances, scan for nested groups' instances).
- parametric_system.dart: GeneratedGeometryError doc. CHANGELOG bullet. Rooms spec D12 amendment. CS11 (R-4): expander set aside around its three adds.
- New test: packages/jet_cad_2d/test/parametric/instance_guard_test.dart (5 tests).

## TDD
RED before implementation: E5G-refuse (move returned null, "move"), E5G-add ("a group into the row"), E5G-dissolve (`Expected: null Actual: <4>` 3EB), E5G-undo ("move"); E5G-component passed already, as the brief predicted.
GREEN after: `dart test` parametric: +184 All tests passed.

## Deviation (one line in the new test)
Brief's E5G-refuse positive control `expect(identical(doc.tree[seat.handle], seat), isTrue)` fails after the refused edits: a refused move's undo rebuilds the node (equal, not identical). Changed to `expect(doc.tree[seat.handle], seat)` (InstanceNode == is exact), with a comment. Probe without prior refusals showed identity held, so this is the refused-edit undo, not the guard.

## Gates (packages/jet_cad_2d)
- dart format .: 0 changed; `--set-exit-if-changed` exit 0
- dart test test/parametric: `+184: All tests passed!`
- query_allocation_test: `+6: All tests passed!`
- dart test (full): `+1337 -2`, only the two standing generate_document_test failures
- dart analyze: No issues found!

## Dependents (step 13)
- jet_cad_2d_plan: +735 all passed. jet_cad_floor_plan --enable-vmservice: +2012 all passed.
- jet_cad_2d_flutter: +1450 ~1 -5: the five text ladder rung 1-5 goldens (standing; the two lod-ladder standing lines did not fail here).
- jet_cad_2d_kit +314, restaurant_symbols +97, apps/floor_planner +212, apps/restaurant_demo +69, tool/screenshots +14: all passed.
- No new failures. git status clean after commit.

## Mutations (all on committed regeneration.dart; reverted by git checkout, `git diff --quiet` exit 0 each)
- M-E5G-value (`: now != seat)` -> `: false)`): E5G-refuse red: "Expected: throws GeneratedGeometryError with handle 2008 ... returned <null> move".
- M-E5G-gone: E5G-refuse red, same message, reason "removal".
- M-E5G-seed (seed seat.parent): E5G-component red: `Expected: empty Actual: {1000: 1}` at instance_guard_test.dart:104.
- M-E5G-add-node: E5G-add red, reason "a group into the row".
- M-E5G-add-onto: E5G-add red, reason "an ATTRIB onto a seat".
- M-E5G-nested: E5G-add red, GeneratedGeometryError thrown by the loaded nested group's move (test line 201, via _run).
- M-E5G-dissolve: E5G-dissolve red: `Expected: null Actual: <4>` 3EB at line 222 (first label remains).
- M-E5G-scan: E5G-dissolve red: `Expected: null Actual: <22>` at line 261 (nested instance's ATTRIB).
- M-E5G-undo: E5G-undo red: bytes after the refused move differ (transform of 1010 stays rotated), reason "move".
Final `dart test test/parametric`: +184 All tests passed.

## Self-review / concerns
- Diff is the brief's code verbatim except the one test line above. analysis_options.yaml untouched; explicit paths staged.
- The two behaviourally-equivalent parts named in the brief remain unmutated.
