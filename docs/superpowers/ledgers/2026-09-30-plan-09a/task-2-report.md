# Task 2 report — SymbolComponent and its registration

Commit: 51a9bda `feat(app): the symbol component` on plan-09/symbol-library-core (not pushed).

## Files
- apps/floor_planner/lib/symbols/symbol_component.dart (new)
- apps/floor_planner/lib/parametric/catalog.dart (import; `registerAppComponents` calls `SymbolComponent.register(r)` last; doc comment; no parametric registration)
- apps/floor_planner/test/symbols/symbol_component_test.dart (new, 12 tests SC1-SC12)
analysis_options.yaml not staged (packages/jet_cad/analysis_options.yaml still shows modified).

## Gates (CI=true)
- Engine `dart test`: `+1121 -2: Some tests failed.` (the 2 standing failures, test/testing/generate_document_test.dart; 1106 + 15 from Task 1). analyze: No issues found. format: Formatted 160 files (0 changed).
- Render `flutter test`: `+974 ~1 -7: Some tests failed.` (standing: 7 text ladder goldens, 1 skip, unchanged). analyze: No issues found. format: 0 changed.
- App `flutter test`: `02:24 +608: All tests passed!` (596 + 12). analyze: No issues found. format exit=0, `Formatted 129 files (0 changed)`.
- `flutter build web --release`: `✓ Built build/web`.

## Mutants (file:line, red test, real output)
Fixtures: definition handle 4200, basePoint (900,400), leaves off origin, tags ['sofa','seating','couch'] (unsorted), version 3.

| id | mutation | file:line | red test | output |
|---|---|---|---|---|
| M-09u-a | `_sameTags` ignores order (`b.contains(a[i])`) | symbol_component.dart:91 | SC2 | `+1 -1: ... SC2 tag order matters to equality [E]` |
| M-09u-b | toJson swaps category/key | symbol_component.dart:58 | SC5 | `+4 -1: ... SC5 toJson round-trips and its key order is pinned [E]` |
| reg omitted | `SymbolComponent.register` commented out | catalog.dart:48 | SC7, SC8, SC9, SC10, SC11, SC12 | `+6 -1: ... SC7 saves and loads typed ... [E]` (+6 -6 total) |
| SC1 name | equality drops name | symbol_component.dart:83 | SC1 | `Expected: not SymbolComponent<(... Four-seat sofa ...)> Actual: SymbolComponent<(... Three-seat sofa ...)>` |
| SC1 version | equality drops version | :85 | SC1 | `Expected: not ...sofa.three@4 ... Actual: ...sofa.three@3` |
| SC1 tag length | drops length check | :89 | SC1 | `Expected: not ...(sofa/seating) Actual: ...(sofa/seating/couch)` |
| SC3 | `tags = tags` (no copy) | :44 | SC3 | `Expected: ['sofa','seating','couch'] Actual: ['mutated','seating','couch']` |
| SC4 version | `version < 0` | :48 | SC4 | `Expected: throws <Instance of 'ArgumentError'> Actual: <Closure: () => SymbolComponent>` |
| SC4 key | empty-key check off | :45 | SC4 | same |
| SC6 | missing field returns '' | :75 | SC6 | `Expected: throws <Instance of 'FormatException'>` |
| SC9 | PageComponent.register dropped | catalog.dart:46 | SC9 | `Expected: true Actual: <false>` |
| SC8 | engine component.dart:151 toJson skips unknown payloads | component.dart:151 | SC8 | `Expected: ... ponents":{"jetcad.sy ... Actual: ... ponents":{},"rawData ...` |
| SC11/12 | engine draft_document.dart:204 `purge()` also does `components.clear()` | draft_document.dart:204 | SC11, SC12 | `Expected: SymbolComponent<(sofa.three@3 ...)> Actual: <null>` |

Every run restored the file; `diff` backup vs file exit 0 each time (no git checkout used). Backups/scripts in scratchpad t2/.
Not red by a mutant: SC10 (no parametric diagnostics / live-object rule / regeneration untouched). It is a guard: it would only go red if SymbolComponent were added to `parametricCatalog` with a type; I did not build such a stub type. Stated honestly as unfired. A probe mutant (`internal: true` on register) stays green: that flag only affects foreign-format export, nothing tested here; not claimed.

## P-6 item 1: purge on a definition's component
Read: `DraftDocument.purge()` (draft_document.dart:192) compacts the geometry store and the entity slots, rewrites `geomIndex`, calls `invalidateDerived` and `notifyPurged`. It never touches `components`, `tree` or definitions. Observed by SC11: with a hole at slot 0 (first leaf removed, `liveSlots [1]` before, `[0]` after purge) the component on the definition handle is still present and `==`, `withComponent<SymbolComponent>()` still `[def]`, `validate()` empty, encoded bytes identical before and after, and the saved bytes load with a typed component. SC12: a component on a handle whose definition was removed (by a compound lacking a SetComponent clear) also survives purge, i.e. purge neither cleans orphan components nor loses live ones. No data a save needs is lost: no fix, no stop. Consequence for Task 4: undo of a placement must clear the component through `SetComponentCommand` (the compound does; RemoveDefinitionCommand does not), else a component is orphaned on a dead handle.

## Decisions / spec notes
- Plan says "ParametricSystem.regenerate"; no such method exists. Regeneration runs as the dispatcher expander. SC10 installs the system (`installParametric`), asserts `diagnostics()`/`drift()`/`validate()` empty, executes an edit through the expander, and asserts the component and diagnostics unchanged.
- `CompoundCommand` requires a named `label`.
- Constructor throws ArgumentError (not assert) for empty key / version < 1; fields alphabetical in toJson (category, key, name, tags, version).
- Nothing in the spec contradicted; nothing left open. Engine unchanged by this task (temporary mutants only, restored).
