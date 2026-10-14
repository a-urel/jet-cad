# Task 13 report: symbols (loader, gallery model, gallery, placer, panel focus)

Status: **DONE_WITH_CONCERNS**. One finding needs a ruling (a ported assertion the kit contract makes impossible, F-1 below).

BASE 23621eb9. Commits:
- `25b56f97` feat(plan): the symbol loader and the gallery (P2). Also `execute` catching `PermissionDeniedError` and its test S-PD.
- `c8d10b25` test(plan): S-12 pins that retrySymbols does nothing from ready. M-S12 survived the brief's S-12.
- `0d314ba4` test(plan): S-18 the gallery reports the locale and shows its words. This adds the test for the `PlanLocaleScope.push` the dispatch requires.

## Implemented

- `lib/src/symbols/plan_symbol.dart`: `PlanSymbol` (kitId, names, entry; `id`, `component`).
- `lib/src/symbols/plan_symbol_loader.dart`: `PlanSymbolLoader` and `PlanSymbolLoad`.
  - The loader keeps one cached read per source, by identity. A failed read is evicted.
  - `load` assembles in kit order, then source order, then library order.
  - It reports `libraryUnreadable`, `libraryKitMismatch` and `symbolDuplicate` as diagnostics.
  - The state is `failed` only when every source failed.
  - `isDisposed`, `dispose`.
- `lib/src/symbols/gallery_model.dart`: `PlanSymbolWords`, `PlanSymbolGroup`, `groupIdOf` and `searchPlanSymbols`.
  - `searchPlanSymbols` hides retired symbols and applies the filter first.
  - Each query term must match, after folding, the shown name, the shown category, the stored English name or category, or a tag.
  - Groups are keyed by kit and English category.
- `lib/src/symbols/symbol_placer.dart`: the port of `symbol_placer.dart` (`InstanceStyle`, `placementTransform`, `definitionForEntry`, `placeSymbol`, `isLeafEqual`).
  - The copy carries the entry's whole `SymbolComponent` and its `UnitComponent`.
  - A definition is reused only when its unit is equal to the entry's.
  - The table number is dropped (it moves to 2b).
- `lib/src/symbols/thumbnail_document.dart`: `symbolThumbnailDocument`.
- `lib/src/panels/panel_focus.dart`: a verbatim copy of `jet_cad_floor_plan/lib/src/panel_focus.dart` plus one source line (ruling R-f).
- `lib/src/panels/plan_symbol_gallery.dart`: `PlanSymbolGallery`.
  - States: loading, failed with Retry, and ready.
  - The search field and its key guard, the filter, and enabled by `allowsTool(plan.symbol)` plus the engine's placement needs.
  - A tap arms the symbol through `controller.armSymbol`.
  - It calls `PlanLocaleScope.push` from `didChangeDependencies` and when it is handed another controller.
- `plan_controller.dart`:
  - The `symbols:` parameter (factory and private constructor).
  - The fields `_symbolLoader`, `_ownsSymbolLoader`, `_armed`, `_symbols`, `_symbolsById` and `_symbolRun`.
  - The members `symbolsState`, `symbols`, `symbolById`, `armedSymbol`, `armSymbol`, `retrySymbols` and `_loadSymbols`. The load starts last in the constructor.
  - `dispose` disposes only an owned loader, plus `_armed`.
  - **`execute` now also catches `PermissionDeniedError` and answers false** (Task 12's ruling), with its doc comment updated.
- Barrel: exports `plan_symbol.dart`, `plan_symbol_loader.dart` and `plan_symbol_gallery.dart`.

Tests:
- `test/support/symbol_fixtures.dart`: from the brief.
- `test/symbols/plan_symbol_loader_test.dart`: S-1..S-8.
- `test/symbols/gallery_model_test.dart`: 4 ported search tests, SN1, SN2, GM-1..GM-9.
- `test/symbols/symbol_placer_test.dart`: the whole file ported, plus SS9 and SP-1 (new).
- `test/controller/symbols_controller_test.dart`: S-9..S-14. S-10 is S-late-fail.
- `test/panels/plan_symbol_gallery_test.dart`: the ported panel tests, plus S-15..S-18.
- `test/controller/permissions_controller_test.dart`: + S-PD.

Review Focus 5 (S-10, S-late-fail) passes. The test draws a line while both libraries are loading. Alpha finishes, and the state stays `loading`. Beta then fails. The results:
- the state is `ready`;
- the symbols are alpha's two;
- there is no beta symbol;
- there is exactly one diagnostic, `('beta', 'beta', libraryUnreadable)`;
- the line, stateId and undoDepth are unchanged;
- `plan.select` is still active;
- a second line draws.

## TDD evidence

RED (Step 7). `flutter test test/symbols test/controller/symbols_controller_test.dart test/panels/plan_symbol_gallery_test.dart test/controller/permissions_controller_test.dart` printed compilation errors:
```
test/symbols/symbol_placer_test.dart:16:8: Error: Error when reading 'lib/src/symbols/symbol_placer.dart': No such file or directory
test/support/symbol_fixtures.dart:241:29: Error: Type 'PlanSymbol' not found.
test/symbols/symbol_placer_test.dart:202:21: Error: Method not found: 'placementTransform'.
```
RED for S-PD, which compiled before any lib change (`flutter test test/controller/permissions_controller_test.dart --plain-name "S-PD"`):
```
00:00 +0 -1: S-PD a widget-side commit under readOnly answers false and changes nothing (execute: every refusal is false) [E]
  PermissionDeniedError: "Remove entity" needs geometry
  package:jet_cad_2d_plan/src/controller/plan_controller.dart 437:25  PlanController.execute
```
GREEN, first run after the implementation. Every file passed except `gallery_model_test.dart`, which failed to load (F-1):
```
Failed to load ".../test/symbols/gallery_model_test.dart": Invalid argument (tags): must be lower case, not empty, without outer white space: "Reading"
  package:jet_cad_2d_kit/src/model/symbol_component.dart 55:9  new SymbolComponent
```
After the F-1 handling: `flutter test test/symbols/gallery_model_test.dart` printed `00:00 +14 ~1: All tests passed!`.

## Mutations

Each mutation ran on committed files through a scratchpad script (`mutate.py`). The script applies the mutation, runs the named test, runs `git checkout -- <file>`, then `git diff --quiet -- <file>`. Every revert printed `git diff --quiet exit=0`.

| Mutation | File: change | Red line |
|---|---|---|
| M-SPD | plan_controller: drop `on PermissionDeniedError { return false; }` | S-PD `PermissionDeniedError: "Remove entity" needs geometry` |
| M-S-none | plan_controller: drop `_loadSymbols`' no-library early return | C1 `Expected: PlanSymbolsState.ready  Actual: PlanSymbolsState.loading` |
| M-S2 | loader: drop the `if (earlier != null) {…continue;}` block | S-2 `Which: at location [2] is 'alpha.item.two@1' instead of 'alpha.item.three@1'` |
| M-S4 | loader: kit check condition → `if (false)` | S-4 `Actual: ['beta.item.four@1', 'alpha.item.one@1']` |
| M-S5 | loader: the read's catch body → `rethrow;` | S-5 `Bad state: no asset here` |
| M-S6 | loader: `failed == reads.length` → `failed > 0` | S-6 `Expected: ready  Actual: failed` |
| M-S7a | loader: drop `if (kept != null) return kept;` | S-7 `Expected: <1>  Actual: <2>` |
| M-S7b | loader: the eviction body emptied (`onError: (Object _) {}`) | S-7 `Expected: ['alpha.item.a@1', 'beta.item.b@1']  Actual: ['alpha.item.a@1']` |
| M-S9 | plan_controller: drop the `for (final d in load.diagnostics)` loop | S-9 `Actual: []` |
| M-S11 | plan_controller: `if (_ownsSymbolLoader) _symbolLoader.dispose();` → `_symbolLoader.dispose();` | S-11 `Expected: false  Actual: <true>` |
| M-S12 | plan_controller: drop the `!= failed` guard | S-12 `Expected: ready  Actual: loading`. The brief's S-12 **survived**; it was fixed in c8d10b25 |
| M-S13 | plan_controller: `_disposed \|\| run != _symbolRun` → `run != _symbolRun` | S-13 `FlutterError:A ValueNotifier<PlanSymbolsState> was used after being disposed.` |
| M-S14 | plan_controller: drop `_armed.value = symbol;` | S-14 `Expected: same instance as PlanSymbol(demo: demo.sofa.three@1)  Actual: <null>` |
| M-GM2 | model: drop `!s.component.retired && ` | GM-2 `Expected: not contains 'demo.chair.old@1'` |
| M-GM3a | model: drop `searchFold(c.name),` | GM-3 `Expected: ['demo.sofa.three@1']  Actual: []` |
| M-GM3b | model: drop the tags line | GM-3 `Expected: ['demo.sofa.three@1', 'demo.sofa.two@1']  Actual: []` |
| M-GM3c | model: drop `searchFold(c.category),` | GM-3 `Expected: ['demo.sofa.three@1', 'demo.sofa.two@1']  Actual: []` |
| M-GM4a | model: drop `searchFold(words.name(s)),` | GM-4 `Expected: ['demo.sofa.three@1']  Actual: []` |
| M-GM4b | model: drop `searchFold(words.category(s)),` | GM-4 `Expected: ['demo.sofa.three@1', 'demo.sofa.two@1']  Actual: []` |
| M-GM5 | model: `terms.every(` → `terms.any(` | GM-5 `Actual: ['demo.sofa.three@1', 'demo.sofa.two@1']` |
| M-GM6 | model: drop `&& (filter == null \|\| filter(s))` | GM-6 `Which: at location [3] is [` |
| M-GM7 | model: key `('', s.component.category)` in both places | GM-7 `Actual: [(, Bar)]` |
| M-S15 | gallery: `filter: widget.filter` → `filter: null` | S-15 `Which: at location [0] is 'demo.bed.double@1' instead of 'demo.sofa.three@1'` |
| M-S16 | gallery: drop the `allowsTool` line of `_enabled` | S-16 `Expected: false  Actual: <true>` |
| M-09b7 | gallery: `_FieldKeys.build` returns `child` | "typing r, w and m…" `Actual: {'R': 1, 'W': 1, 'M': 1, 'Esc': 0}` |
| M-09b22 | gallery: `_enabled` starts with `return true;` | "a tap reports the entry…" `Expected: false  Actual: <true>` |
| M-S18a | gallery: drop `PlanLocaleScope.push` from `didChangeDependencies` | S-18 `Expected: Locale:<tr>  Actual: Locale:<en>` |
| M-S18b | gallery: `PlanSymbolWords(PlanStrings.of(context).languageCode)` → `PlanSymbolWords.english` | S-18 `Expected: 'Yatak odası'  Actual: 'Bed Room'` |
| M-SP1a | placer: the copy's `SetComponentCommand<UnitComponent>` dropped | SP-1 `Expected: UnitComponent(table, 6, assigned)  Actual: <null>` |
| M-SP1b | placer: drop the unit equality in the reuse test | SP-1 `Expected: an object with length of <2>  Actual: [Definition(12 "fixture.table.round@4")]` |
| M-SP1c | placer: copy a field-wise `SymbolComponent` (no attachTo/retired) | SP-1 `Expected: SymbolComponent(…, retired)  Actual: SymbolComponent(fixture.table.round@4, Round table, Dining)` |
| M-P-leafEqual | placer: `isLeafEqual(doc, h, entry)` → `true` | the ported "leaf-equal reuse L1 …" tests `Expected: ['fixture.sofa.three@3', 'fixture.sofa.three@3#2']` |

## Gates (packages/jet_cad_2d_plan, at 0d314ba4, clean tree)

```
dart format .                                   Formatted 84 files (0 changed)
flutter test                                    00:04 +292 ~1: All tests passed!
flutter analyze                                 No issues found! (ran in 2.9s)
dart format --output=none --set-exit-if-changed .   format gate exit 0
```
The `~1` is the skipped mixed-case test (F-1). `git status --short` was empty after the gates. No `analysis_options.yaml` was touched.

## Files

All under `packages/jet_cad_2d_plan/`.

New lib files:
- `lib/src/symbols/plan_symbol.dart`
- `lib/src/symbols/plan_symbol_loader.dart`
- `lib/src/symbols/gallery_model.dart`
- `lib/src/symbols/symbol_placer.dart`
- `lib/src/symbols/thumbnail_document.dart`
- `lib/src/panels/panel_focus.dart`
- `lib/src/panels/plan_symbol_gallery.dart`

Modified lib files:
- `lib/src/controller/plan_controller.dart`
- `lib/jet_cad_2d_plan.dart`

New test files:
- `test/support/symbol_fixtures.dart`
- `test/symbols/plan_symbol_loader_test.dart`
- `test/symbols/gallery_model_test.dart`
- `test/symbols/symbol_placer_test.dart`
- `test/controller/symbols_controller_test.dart`
- `test/panels/plan_symbol_gallery_test.dart`

Modified test file:
- `test/controller/permissions_controller_test.dart` (S-PD)

## Findings

**F-1 (needs a ruling): a ported assertion the contract makes impossible.** The test is `symbol_search_test.dart:182-189`, "a mixed-case tag is found in any case".
- Its fixture tags a symbol `'Reading'` and asserts `expect(entries[1].component.tags.first, 'Reading')`.
- The kit contract's `SymbolComponent` refuses any tag that is not lower case (K2, `jet_cad_2d_kit/lib/src/model/symbol_component.dart:53-57`, an `ArgumentError`). So no `PlanSymbol` can carry a mixed-case tag.
- The shared group fixture threw at load time and took the whole file down.

What I did:
- I lower-cased the fixture's tag (`'reading'`), a fixture change A12 allows. This lets the sibling test "a term in the key alone finds nothing" run with its assertions unchanged.
- I kept the mixed-case test verbatim but marked it `skip:` with a FINDING reason. With `--run-skipped` it fails exactly on the impossible line: `Expected: 'Reading'  Actual: 'reading'`. Its query lines (`'reading'`, `'READING'`, `'rEaDiNg'`) would pass.

Nothing is weakened. A suggested ruling: the assertion moves, its intent covered elsewhere:
- the stored-side case fold is impossible by contract and is pinned by the kit's own SymbolComponent tag tests;
- the query-side case fold is pinned by SN1 (`'KÖŞE LOCA'`, `'ISITICI'`) and GM-5 (`'BED'`).

The test could then be deleted, or rewritten to query an upper-case term against a lower-case tag.

## Deviations from the brief

1. **plan_symbol_gallery.dart**
   - It imports `package:jet_cad_2d/jet_cad_2d.dart show foregroundFor`, because `jet_cad_2d_flutter` does not export it.
   - It imports `../symbols/plan_symbols_state.dart`, because the enum is not reachable otherwise.
   - It adds `didChangeDependencies` → `PlanLocaleScope.push(context, controller)` and a push in `didUpdateWidget` when the controller changes. The dispatch says every new widget calls it; the brief's code did not.
   - The new test S-18 pins the push and the kit's words in Turkish (mutations M-S18a and M-S18b).
2. **plan_symbol_loader.dart** imports `plan_symbols_state.dart`, as the brief's note says.
3. **symbol_placer.dart**
   - `SymbolLeaf` is dropped from the `show` list (unused; the analyzer flagged it).
   - The header comment is rewritten for the port. Lines 18-78, 156-163 and 239-283 are verbatim.
4. **plan_controller.dart**
   - The factory's doc comment gains a paragraph on `symbols`/`thumbnails` ownership.
   - `execute`'s doc names `PermissionDeniedError`.
   - Everything else is as Step 11.
5. **Gallery test port**
   - The source's host owned the `PanelFieldFocusNode`; the gallery now owns it. `Host.searchFocus` reads it from the field (`tester.widget<TextField>(field).focusNode!`). Every focus assertion is unchanged.
   - "the panel" became "the gallery" in test names and comments.
   - The thumbnail test reads `h.loaded('demo.bed.double').entry` for `entry.definition.basePoint`.
   - The permissions test uses `h.controller.document.commands.permissions = p; await h.pump();`, as the brief says.
   - `dart:typed_data` is dropped: `Uint8List` comes through `flutter/services` (analyzer info).
   - The highlight test (`:505-532`) is not ported, as the brief says (Task 14).
6. **Placer test port**
   - `var y` → `final y` (lint `prefer_final_locals`).
   - `.cast<Map>()` → `.cast<Map<String, Object?>>()` (lint `strict_raw_type`).
   - `dart format` reflowed a few lines.
   - No assertion changed.
   - SS9's fixture is this file's `sofa()` with its leaves reversed, under `target()`.
7. **S-12 strengthened.** The brief's assertion `read.reads == 2` stays. With M-S12 applied, the loader's cache keeps that count at 2, so M-S12 survived. I added:
   - the state stays `ready` right after `retrySymbols()` from `ready`;
   - `c.symbols` stays the same instance.
8. **New tests beyond the brief**, each with named mutations, for the Step 9 placer adaptations the brief described but did not test:
   - SP-1 pins the whole component, the unit, and a unit-less definition not being reused (M-SP1a/b/c);
   - S-18 (deviation 1).
9. **Loader test**: `dart:async` dropped (unused).
10. **Mutation forms**
    - M-S4 is `if (false)` in place of deleting the block. It behaves the same and keeps the code compiling.
    - M-S7b empties the eviction's body instead of deleting the whole `.then`. Deleting it would leave a failed read's error unhandled, which tests something else.
    - M-09b22 is a leading `return true;` in `_enabled`.
11. **F-1** above: one ported test skipped pending a ruling, its fixture tag lower-cased.

## Self-review

- Spec P2, all met:
  - libraries load at construction and never block an edit (S-10);
  - problems are diagnostics and the load goes on (S-2, S-4, S-5, S-9);
  - `failed` only when every source failed (S-6);
  - a shared loader and thumbnail cache are never disposed by a controller (S-11);
  - retry only from `failed` (S-12);
  - the gallery hides retired symbols (R2), searches names, categories and tags in either language, and takes an optional filter.
- Draw order: the placer allocates the copy's handles first, then its leaves in the library's ascending order, then the instance. This is today's order (ported tests P- and L- pass).
- Stored-value comparisons stay exact `==` in `isLeafEqual` and in the unit check.
- `armSymbol` answers false until Task 14 registers `plan.symbol`. `selectTool` refuses an unknown id. The symbol stays armed (S-14).

## Concerns

- F-1 needs a ruling (one skipped ported test).
- A retry that succeeds leaves the earlier `libraryUnreadable` diagnostics in the log, which deduplicates and does not clear them. They are not plan-scoped, so `load` does not clear them either. Today's loader had no diagnostics log, so there is nothing to compare against. Consider clearing a source's library diagnostics on a successful retry (Task 20's bar shows the log).
- `ListenableBuilder(listenable: Listenable.merge([...]))` in the gallery builds a new merged listenable on each outer build. This was the brief's code. It is harmless, and not on the frame path.

## Controller ruling F-1

The ruling: retire the skipped test, keep its intent on the query side, and end with no skips.

- **Retired:** `symbol_search_test.dart:182-189` "a mixed-case tag is found in any case". K2 admits only lower-case tags, so its premise cannot exist. The retirement is noted in `test/symbols/gallery_model_test.dart`'s port comment (source name, K2).
- **No existing ported test covers the intent.** SN1's `'KÖŞE LOCA'` and `'ISITICI'` hit names, and GM-5's `'BED'` hits names, tags and categories at once; none pins a tag-only hit.
- **Added SF-Q** "a mixed-case query finds a lower-case tag (ruling F-1)":
  - `hitsOnly(entries, 'reading', 'tag')` checks that "reading" hits the tag alone;
  - the queries `'ReAdInG'`, `'READING'` and `'rEaDiNg'` each find `fixture.chair.wingback@1`.
- **Mutation M-SFQ:** `gallery_model.dart` `searchFold(query).split` → `query.split`. SF-Q went red with `Expected: ['fixture.chair.wingback@1']  Actual: []`. The revert left `git diff --quiet` exiting 0.
- **Deviation 11 now reads:** the ported mixed-case tag test is retired (K2) and replaced by SF-Q; the fixture's tag is lower case.
- **Commit:** `953356d8` test(plan): retire the mixed-case tag test; SF-Q folds the query.
- **Gates** (packages/jet_cad_2d_plan, clean tree):
  - `flutter test` printed `00:04 +293: All tests passed!`, with no skips;
  - `flutter analyze` printed `No issues found!`;
  - `dart format --output=none --set-exit-if-changed .` exited 0.
