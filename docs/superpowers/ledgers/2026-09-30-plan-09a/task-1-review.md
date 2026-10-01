# Task 1 review (477138f) - independent

Verdict: Needs fixes (one major, small).

Gates re-run by me: engine `00:17 +1120 -2` (the 2 standing generate_document failures), analyze No issues, format 0 changed; render `00:54 +974 ~1 -7` (the render run overlapped my mutants in time but matches the standing numbers), analyze/format clean; app `02:50 +596: All tests passed!`, analyze/format clean. git status: only packages/jet_cad/analysis_options.yaml.

Findings
1. MAJOR commands.dart:460 (RemoveDefinitionCommand.capability): mutant `Capability.geometry` leaves the suite green (`+14: All tests passed!`). Only Add's capability is asserted. Dual-effect: a geometry command would be allowed/denied under the wrong permission and the index may treat it differently. Add a test asserting Remove's capability and touched == {handle} (Remove's `touched: {}` mutant also survives, line 489; the spec calls M-09p equivalent for the index, but a direct assertion like Add's costs one line).
2. MINOR definition_commands_test.dart (pick test): the "no rebuild call" test goes red when the index ignores every command (spatial_index.dart:2667 mutated to `return`), but stays green when the `definition(handle) != null` structural arm at spatial_index.dart:2718 is inverted, because _reconcileEntity falls back to rebuildAll for a removal/unknown handle. So it proves wiring, not the touched-definition rule. Accepted: spec marks this equivalent.
3. MINOR: extents test compares `isEmpty` only for the undone state (weak but the redo/min/max values are checked off-origin).
No other findings: atomicity holds (all refusals precede mutation; moving addDefinition before the children check or removeDefinition before the owner loop is caught), DuplicateHandleError/ArgumentError/StateError semantics match the plan, handleSeed.raiseTo tested, read-only permission tested for both commands, inverse carries the pre-removal value, export already via commands.dart (jet_cad_2d.dart:15), doc comments and the SpatialIndex class comment are accurate (Add/Remove named, direct tree calls still unheard).

Mutant matrix (my runs, test file definition_commands_test.dart, backup diff exit 0 each time)
- Remove: drop owner guard: RED `RemoveDefinitionCommand refuses while a leaf is owned by it, allows once it is gone`
- Remove: drop instance guard: RED `... refuses while an instance names it, allows once it is gone`
- Remove: drop parent guard: RED `... refuses while a node is parented to it`
- Add: drop children guard: RED `AddDefinitionCommand refuses a definition that lists children, and mutates nothing`
- Add: drop definition / node / entity arm (each separately): RED `AddDefinitionCommand refuses a handle that names a definition, a node or an entity` (+2 -1 each)
- Remove inverse restores wrong name: RED `AddDefinitionCommand adds, undoes and redoes the same value`, `RemoveDefinitionCommand its undo restores the same definition value`
- Skip raiseTo: RED `AddDefinitionCommand raises the handle seed past a handle it is given`
- Add mutates before children refusal: RED (children test, +3 -1); Remove mutates before owner refusal: RED (owner test, +9 -1)
- Add capability geometry: RED `AddDefinitionCommand capability is structure and touched names the handle`
- Remove capability geometry: GREEN `+14: All tests passed!` (finding 1)
- Remove touched {}: GREEN (finding 1)
- Index: definition arm inverted (spatial_index.dart:2718): GREEN (finding 2)
- Index: onAfterMutate ignores all commands: RED `a pick finds an instance of an added definition with no rebuild`
Fixtures non-degenerate: basePoint (40,30), instance rotated pi/2 at (1000,500), leaves off-origin, re-added same handle with moved leaf.

## Re-review (1b), e96c9cc
Verdict: Approved.
- Engine gate: `00:17 +1121 -2: Some tests failed.` (the 2 standing generate_document failures); analyze No issues found; format 0 changed.
- Remove capability -> geometry: RED `RemoveDefinitionCommand capability is structure and touched names the handle` (+14 -1).
- Remove touched -> {}: RED, same test (+14 -1).
- Add inverse removes wrong handle (Handle(1)): RED `AddDefinitionCommand adds, undoes and redoes the same value`, `a pick finds an instance ... no rebuild`, `the extents follow a compound placement and its undo`.
- Backups diffed exit 0 after each; git status shows only packages/jet_cad/analysis_options.yaml. Findings 1 (major) resolved.
