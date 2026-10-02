# Task 1 report: Engine, a removed definition takes its components (spec D11)

Status: **done, gates green, committed (not pushed).**

## Commits
- `a5a6b35` feat(engine): a removed definition takes its components
- `48c8d57` test(engine): a removed definition's inverse at its edges (two edge tests added after the mutant pass; engine test file only)

## Files changed
- `packages/jet_cad_2d/lib/src/document/component.dart`: new `ComponentSnapshot` (immutable; `components` = `(typeId, Component)` ascending by type id, `unknown` = payloads oldest first; `isEmpty`/`isNotEmpty`; `ComponentSnapshot.empty`). `ComponentRegistry.snapshotOf(h)`, `detachAll(h)`, `restore(h, snapshot)`. restore checks every type id before it writes anything, so it is all-or-nothing (StateError).
- `packages/jet_cad_2d/lib/src/document/commands.dart`:
  - `RemoveDefinitionCommand`: `capabilities` are static `{structure, components}` and `capability` stays `structure`. After the existing guards, `apply` takes the snapshot, calls `detachAll` and then removes the definition. The inverse is `AddDefinitionCommand(definition, components: snapshot)`. `touched` and the guards are unchanged.
  - `AddDefinitionCommand`: new optional named `components` (default empty). `capabilities` is `{structure}`, or `{structure, components}` when the snapshot is not empty. In `apply`, the restore runs after the refusals and before `addDefinition`, so a throwing restore changes nothing.
- `packages/jet_cad_2d/test/document/definition_commands_test.dart`: 11 new tests (below).
- `apps/floor_planner/test/symbols/symbol_component_test.dart`: SC12 rewritten (P-6).
- `apps/floor_planner/test/symbols/symbol_placer_test.dart`: P13 changed (see R-C1-2).
- Not changed: `jet_cad_2d.dart`, which already exports `component.dart`, so `ComponentSnapshot` is public.

## Tests added (engine, `definition_commands_test.dart`)
Fixture `withComponents()`: two definitions far from the origin (base `(1e5+40, -7e4)` and `(-310, 925)`). Each carries `Tally` (a test type, non-default fields), `ObjectLayer(0x2A1)` (not layer 0) and one unknown payload. The second definition is the neighbour that must stay untouched.
Group "D11 RemoveDefinitionCommand takes the handle's components":
1. remove takes them all, undo restores the bytes, redo takes them (registry `toJson` and the full `DraftDocumentCodec` encoding byte-equal after undo; neighbour untouched)
2. a refused removal takes nothing
3. the forward capabilities are {structure, components} even with nothing attached; the summary stays structure
4. without components the forward command is refused before anything changes, carrying components or not
5. the inverse of an empty snapshot runs without components; the inverse of a non-empty one is refused, and kept (entry kept, state id unchanged, later granted undo gives the same bytes)
Group "D11 the inverse, at its edges":
6. a snapshot of unknown payloads alone is not empty: its undo needs components
7. an add whose snapshot cannot be restored throws and adds nothing (all-or-nothing)
Group "D11 ComponentRegistry.snapshotOf and restore":
8. registered components by type id, unknown payloads oldest first; restore puts each back exactly (unknowns attached out of type-id order)
9. a snapshot does not follow later changes and cannot be edited
10. a handle carrying nothing gives an empty value; restoring it adds nothing
11. a type registered after the snapshot is not invented
The existing `capability == structure` assertions (the "capability is structure and touched names the handle" tests) are kept and pass.

## Existing assertions rewritten (P-6)
- **SC12**, old: `'SC12 purge does not clean a component on a handle that no longer names anything (what a removed definition leaves behind)'` with `expect(r.doc.components.get<SymbolComponent>(r.def), sofa());` after the remove and again after purge.
  New: `'SC12 a removed definition takes its component with it (spec 09c D11): undo brings it back byte for byte, and purge finds no orphan'`. After the remove compound it asserts `get<SymbolComponent>(r.def)` is null, `withComponent` is empty and `toJson` has no `jetcad.symbol`. Undo gives the encoded document byte-equal and the component equal to `sofa()`. Redo then purge leaves `withComponent` empty and `validate()` empty.
- **P13** (`symbol_placer_test.dart`), not named by P-6. Old order: `foreign(905)`, `SetComponentCommand(905, sofaSymbol())`, `RemoveDefinitionCommand(905)`, then `expect(withComponent.length, 1, reason: 'the orphan component is still there')`. With D11 the remove takes the component, so the test went red. New order: `foreign(905)`, `RemoveDefinitionCommand(905)`, `SetComponentCommand(905, sofaSymbol())`. This is the orphan a pre-09c file may carry, which D11 leaves alone. The assertions are unchanged. See R-C1-2.
- P5, P9, P10, P17, P18: unchanged and passing (no diff in their lines).

## Gates (real counts, this container, Flutter 3.47.2)
- Engine (`packages/jet_cad_2d`), on the tip `48c8d57`: `+1237 -2`. The 2 failures are the standing `test/testing/generate_document_test.dart` ("the default document is the one Plan 2 measured, byte for byte", "both text fractions default to zero and change nothing"). That is the 1,226 at the branch point plus 11 new. At `a5a6b35` it was `+1235 -2`. analyze: No issues found. format: 0 changed, exit 0.
- Render (`packages/jet_cad_2d_flutter`), unchanged by this task but run once at `a5a6b35`: `+1187 ~1 -7`. The 7 are the standing canvas text ladders (`text_ladder_golden_test.dart` rungs 1–5, `text_lod_ladder_golden_test.dart` rungs 1–2). analyze: No issues found. format: exit 0.
- App (`apps/floor_planner`), at `a5a6b35`: `04:02 +993: All tests passed!` analyze: No issues found. format: exit 0. The second commit touches only the engine test file.
- `apps/dev_harness_2d` analyze: No issues found.
- Allocation invariant tests: not edited (no diff). `analysis_options.yaml`: not staged. `packages/jet_cad/analysis_options.yaml` stays modified in the worktree by pub get, as expected.

## Mutant table (each fired by cp backup, mutate, run, cp back, diff exit 0)
| Mutant | Site | Change | Red tests | Excerpt |
|---|---|---|---|---|
| **M-09c-q** | commands.dart:451 | `target.components.restore(handle, components);` commented out | engine: #1, #5; app: SC12 | engine: `Expected: '{"aa.past":{"19":...},"jet_cad.object_layer":{"18":{"layer":673},"19":...` `Actual: '{"aa.past":{"19":{"v":-3}},"jet_cad.object_layer":{"19":{"layer":673}},...` ; app: `Expected: ... ponents":{"jetcad.sy ...` |
| **M-09c-r** | component.dart:164 | `_unknown[handle] ?? ` removed (snapshot holds no unknowns) | #1, #5, #8, #9 | `Expected: '...,"zz.future":{"18...'` `Actual: '...{"count":3,"label":"south"}}}'` |
| **M-09c-aj** | commands.dart:488 | forward `capabilities` → `const {Capability.structure}` | #3, #4 | `Expected: Set:[...structure, ...components] Actual: Set:[Capability:Capability.structure]`; `Expected: throws <Instance of 'PermissionDeniedError'> with capability components; Actual: <Closure> returned <null>` |
| **M-09c-ba** | commands.dart:431 | inverse non-empty → `const {Capability.structure}` | #5 | `Expected: throws <Instance of 'PermissionDeniedError'> with capability: Capability.components; Actual: <Closure: () => void> Which: returned <null>` |
| detach skipped | commands.dart:514 | `target.components.detachAll(handle);` commented out | engine: #1; app: SC12 | engine: `Expected: null Actual: <Instance of 'Tally'>`; app: `Expected: null Actual: SymbolComponent:<SymbolComponent(sofa.three@3, ...)>` |
| isEmpty ignores unknown | component.dart:86 | `isEmpty => components.isEmpty` | #6 | red: "a snapshot of unknown payloads alone is not empty" |
| snapshot shares the live list | component.dart:79 | `unknown = unknown` (no unmodifiable copy) | #9 | red |
| restore ignores the type id | component.dart:192 | `_stores[_typeOf[typeId]]` → `_stores.values.last` | #1, #5, #7, #8, #11 | red |
| restore after add | commands.dart:451/452 | restore moved after `addDefinition` | #7 | red |
| detach before guards | commands.dart:499 | `detachAll` before the node/entity guards | #1, #2, #5, #6 | red |
| unknowns sorted by type id | component.dart:167 | snapshot sorts unknown payloads by typeId | #8 | red |
| isEmpty always false | component.dart:86 | `isEmpty => false` | #3, #5, #8, #10 | red |

Every mutant: `restored diff=0`. Every new test has at least one mutant that turns it red (#10 by `isEmpty => false`).

## Proposed rulings
- **R-C1-1 (snapshot order).** The plan says the snapshot is "ordered by type id". Registered components are ordered by type id. Unknown payloads keep the registry's own order (oldest first, as `unknownOf` lists them). Sorting them by type id would make `restore` reorder `unknownOf` for a handle whose payloads were attached out of type-id order. `toJson` would still be equal, but "re-attaches each exactly" would not hold. A mutant (unknowns sorted) pins this. Cost if wrong: a one-line sort plus one test expectation.
- **R-C1-2 (P13).** P13, which P-6 does not name, depended on the old behaviour. Its orphan is now written after the removal: the orphan a pre-09c file may carry, which D11 leaves alone. Its assertions are unchanged. Cost if wrong: the test intent is kept, so only the setup order would need revisiting.
- **R-C1-3 (API shape).** Two choices go beyond the plan's API list. (a) `ComponentRegistry.detachAll(Handle)` is new and public, because the registry had no type-id-free detach. (b) The inverse is the public `AddDefinitionCommand` with an optional `components:` snapshot, not a private command class. Cost if wrong: small, a rename or move to a private class.
- **R-C1-4 (consequence of W-1, for the reviewer to confirm).** Static capabilities mean that undoing a plain `AddDefinitionCommand` (its inverse is a `RemoveDefinitionCommand`) now also needs `components`. That holds even though the handle carries nothing. This is exactly what the spec's W-1 rule implies. No existing test runs with structure allowed but components denied. Cost if wrong: a permission set of that unusual shape could no longer undo a definition add.

## Found, not fixed
- `ComponentSnapshot` has no `operator ==`. The round trip is compared through `toJson` bytes, as the plan's "exact ==" for the snapshot round trip names it. The plan says "an immutable value". Unknown payloads are maps, so deep equality would need hand-written code (the engine has no `package:collection`).
- `restore` is additive: it replaces a registered value of the same type and appends unknown payloads. On a handle that already carries unknown payloads, it would add duplicates. The only caller restores onto a handle it just emptied, and the dispatcher's linear history guarantees that.

## Look hardest at
1. R-C1-4 above: the undo of a plain definition add now needs `components`.
2. `AddDefinitionCommand.apply` ordering: guards, then `restore`, then `addDefinition`. The restore is validated first, so the command stays all-or-nothing.
3. P13's changed setup (R-C1-2).
4. Test #11 ("a type registered after the snapshot is not invented") is owed the mutant "restore ignores the type id" (`_stores.values.last`). That mutant is somewhat artificial, because nothing else in restore can invent a component. The test pins the plan's clause rather than a likely bug.
