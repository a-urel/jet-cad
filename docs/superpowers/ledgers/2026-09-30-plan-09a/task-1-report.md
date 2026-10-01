# Task 1 report — engine definition commands

Commit: 477138f `feat(engine): undoable definition commands` on plan-09/symbol-library-core (not pushed).

Files:
- packages/jet_cad_2d/lib/src/document/commands.dart (AddDefinitionCommand, RemoveDefinitionCommand; already exported through commands.dart)
- packages/jet_cad_2d/lib/src/index/spatial_index.dart (class comment only)
- packages/jet_cad_2d/test/document/definition_commands_test.dart (new, 14 tests)

No `CommandTarget` change was needed: Remove scans `tree.nodes` and `entities.liveSlots`/`ownerAt` (O(n), off the frame path). Remove also refuses a node whose `parent` is the definition (as the plan says). `analysis_options.yaml` left out of the commit.

## Gates (real tails)

- Engine `dart test`: `00:17 +1120 -2: Some tests failed.` = 1106 + 14 new passing; the 2 failures are the standing `test/testing/generate_document_test.dart` ones ("the default document is the one Plan 2 measured, byte for byte", "both text fractions default to zero and change nothing"). `dart analyze`: `No issues found!`. `dart format`: `Formatted 160 files (0 changed)`.
- Render `flutter test`: `00:48 +974 ~1 -7: Some tests failed.` (974 + 1 skip + 7 standing, unchanged). analyze: `No issues found!`; format 0 changed.
- App `flutter test`: `02:50 +596: All tests passed!`; analyze `No issues found!`; format 0 changed.

## Mutants (mutated line in commands.dart at mutation time; backup diff exit 0 after every run)

| id | mutation | line | red test(s), real output line |
|---|---|---|---|
| M-09q1 | Remove: drop instance/parent "named by" guard | 472 | `+8 -1: RemoveDefinitionCommand refuses while an instance names it, allows once it is gone [E]`; `+9 -2: ... refuses while a node is parented to it [E]` |
| M-09q2 | Remove: drop entity-owner guard | 480 | `+9 -1: RemoveDefinitionCommand refuses while a leaf is owned by it, allows once it is gone [E]` |
| M-09r1 | Add: drop non-empty children guard | 430 | `+3 -1: AddDefinitionCommand refuses a definition that lists children, and mutates nothing [E]` |
| M-09r2 | Add: drop definition arm of duplicate check | 425 | `+2 -1: AddDefinitionCommand refuses a handle that names a definition, a node or an entity [E]` |
| M-09r3 | Add: drop node arm | 426 | same test red |
| M-09r4 | Add: drop entity arm | 426 | same test red |
| X-raise | Add: drop `handleSeed.raiseTo` | 438 | `+1 -1: ... raises the handle seed past a handle it is given [E]` |
| X-cap | Add capability geometry | 417 | `+6 -1: ... capability is structure and touched names the handle [E]` |
| X-inv | Add inverse removes wrong handle | 441 | red: adds/undoes/redoes; pick finds instance; extents follow compound |
| X-inv2 | Remove inverse restores altered value | 488 | red: `adds, undoes and redoes the same value`; `its undo restores the same definition value` |
| X-rmunknown | Remove: unknown handle throws ArgumentError | 469 | `+7 -1: RemoveDefinitionCommand refuses an unknown handle [E]` |
| X-rmstate | Remove re-adds the definition | 485 | six tests red (add/undo/redo, instance, leaf, undo value, pick, extents) |

Two further attempted mutants did not compile (an `if (... && false)` flow-promotion error, a `Vector2` use outside an import); they are not counted.

## Equivalence experiments (M-09g, M-09p)

- M-09g1 (Add skips `invalidateDerived`, line 438): own test file `+14: All tests passed!`; whole engine suite: only the 2 standing failures. Equivalent, as the spec says. M-09g2 (Remove skips it, line 485): `+14: All tests passed!`, whole-suite same. The calls stay.
- M-09p (Add `touched: {}`, line 442): the spatial index is unaffected, since an empty touched set falls back to `rebuildAll` (the whole suite, pick and extents tests included, stays green apart from one test). That one test is my own direct assertion that `touched` names the handle (`touched names the handle` test, `+6 -1 ... [E]` in its file; whole suite `+123 -1` for that test plus the 2 standing). So the mutant is behaviourally equivalent for the index but not silent: it is caught by the direct `touched` assertion, which I added deliberately. M-09p2 (Remove `touched: {}`, line 488): green, equivalent, and not asserted directly (Remove's touched is not asserted; only Add's is).

## Spec points left open or slightly off

- The stale-pick case the spec asks for (after undo finds nothing) is trivially true if the instance is also undone. I made it discriminating: after undoing all three, the same definition handle is re-added with a leaf elsewhere; a stale container would answer at the old place. This test and the extents test are only red by X-inv/X-rmstate style mutants, never by M-09g/M-09p (equivalent, as the spec says).
- Extents: with an empty document the extents `isEmpty` is used for the before/after-undo comparison (asserts equal emptiness, not box values).
- The spec says AddDefinition's duplicate checks in AddEntity/AddNode still ignore definitions (D14); untouched.
- Decision: `RemoveDefinitionCommand` also refuses a node parented to the definition (plan text), tested separately.

## Task 1b (commit e96c9cc, test-only)

1. New test "RemoveDefinitionCommand capability is structure and touched names the handle". Mutants, diff exit 0 after each:
   - commands.dart:460 Remove capability -> geometry: `00:00 +7 -1: RemoveDefinitionCommand capability is structure and touched names the handle [E]`
   - commands.dart:489 Remove touched -> {}: `00:00 +7 -1: RemoveDefinitionCommand capability is structure and touched names the handle [E]`
2. The pre-state was genuinely empty, so I made it non-empty (a root line 100,100-200,140 added first). The test now asserts the placed union box (100..970, 100..560) and, after undo, the exact four box values equal the pre-placement ones.
3. Comment added above the index group: the pick test proves the index is wired to command changes, not the touched-definition structural arm (equivalent per F-13).

Engine gate: `00:16 +1121 -2: Some tests failed.` (1106 + 15 new; the 2 standing failures unchanged); analyze `No issues found!`; format `Formatted 160 files (0 changed)`. Render and app not re-run: nothing outside the test file changed.
