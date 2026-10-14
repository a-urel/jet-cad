# Task 4 report

Commit dded3b45 `feat(plan): the 2b plumbing: instances guarded, symbol definitions, host words`.

## Implemented
Brief Steps 1-15 verbatim: switchable `instances` in box_kit; PB-guard tests (pass at once, R-1); PB-def and PB-words tests; `PlanSymbolsState` -> kit `SymbolsState` (file `git rm`ed, barrel re-exports `SymbolsState`); `servedTopOfEntry`; `ServicesHost` gains `symbolById`/`symbolsState`/`pendingDefinitions`; `KitServices.symbolDefinition`/`symbolsState` replace Task 3's stubs; `PlanController(words:)`, `namesOf`, `_pendingDefinitions` (cleared in `execute` and `_open`), `_named`; host words read by kit_lookup, property panel (two reads), tool palette.

## TDD evidence
RED (Step 7): `flutter test test/controller/symbol_definition_test.dart test/controller/host_words_test.dart` -> `host_words_test.dart:29:8: Error: No named parameter with the name 'words'.` (compile failure, expected).
GREEN: the three new files, `00:00 +10: All tests passed!`.

## Gates (packages/jet_cad_2d_plan)
- `flutter test`: `00:40 +745: All tests passed!`
- `flutter analyze`: `No issues found!`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 181 files (0 changed)`, exit 0.
- `grep PlanSymbolsState|plan_symbols_state`: no output. No analysis_options.yaml staged.

## Mutations (all on committed files; each reverted, `git diff --quiet` exit 0)
- M-PB-guard-a (bare delegate): PB-guard-1 and PB-guard-2 red.
- M-PB-guard-b (`_fail('generate'...)`): PB-guard-1 and PB-guard-2 red.
- M-PB1: PB-def-twice red. M-PB2 (per-kit `_pending` field): PB-def-twice (and PB-def-execute) red.
- M-PB3: PB-def-twice red. M-PB4: PB-def-execute red. M-PB5: PB-def-execute red.
- M-PB6, M-PB7: PB-def-top red. M-PB8: PB-def-null red.
- M-PB-W1: PB-words-1, -3, -4 red. M-PB-W2: PB-words-1, -2 red. M-PB-W3: PB-words-2 red.
- M-PB-W4, M-PB-W5: PB-words-3 red. M-PB-W6: PB-words-4 red.

## Notes / concerns
- Commit trailer is the brief's `Co-Authored-By: Claude Opus 5.5` line (the session reminder names a different model line; the brief's text was used).
- No mismatch between brief and committed code found. Not mutation-tested (by reading, per brief): property panel's two re-pointed reads.

## Evidence (appended; re-run on commit dded3b45, no code change)

### RED for the new tests
host_words_test.dart (Step 7, before the implementation), `flutter test test/controller/symbol_definition_test.dart test/controller/host_words_test.dart`:
```
test/controller/host_words_test.dart:29:8: Error: No named parameter with the name 'words'.
test/controller/host_words_test.dart:64:18: Error: No named parameter with the name 'words'.
```
symbol_definition_test.dart: it compiled; red run reproduced by putting Task 3 stubs back into services.dart (reverted, diff --quiet exit 0):
```
00:00 +0 -1: PB-def-twice two calls for one key before its add executes: one ref, from any kit's services; executed once, through the document, the next call adds nothing [E]
  UnimplementedError: KitServices.symbolDefinition (2b Task 4)
00:00 +0 -2: PB-def-execute a controller execute, and a new plan, drop the pending refs: the next call is a new copy [E]
  UnimplementedError: KitServices.symbolDefinition (2b Task 4)
00:00 +0 -3: PB-def-top the base point, and the top: the first leaf's box for a circle or a closed outline, else the definition's box [E]
  UnimplementedError: KitServices.symbolDefinition (2b Task 4)
00:00 +0 -4: PB-def-null null for a key no loaded library has, and while loading; symbolsState is the controller's, failed included [E]
  UnimplementedError: KitServices.symbolsState (2b Task 4)
00:00 +0 -4: Some tests failed.
```
guarded_instances_test.dart: green at once (R-1), no RED by design.

### Gates (packages/jet_cad_2d_plan)
```
00:43 +745: All tests passed!
Analyzing jet_cad_2d_plan...                                    
No issues found! (ran in 4.0s)
Formatted 181 files (0 changed) in 0.40 seconds.
format exit 0
```

### Mutations, verbatim (first failing test, Expected/Actual, revert)
```
### M-PB-guard-a  (lib/src/kits/guard.dart ; flutter test test/kits/guarded_instances_test.dart)
00:00 +0 -1: PB-guard-1 a throwing instances is a KitHookFailure naming "instances": the edit rolled back, and probe returns it [E]
  Expected: throws <Instance of 'KitHookFailure'> with `kitId`: 'box' and `typeId`: 'box.square' and `hook`: 'instances' and `error`: <Instance of 'HookBoom'> with `hook`: 'instances'
    Actual: <Closure: () => void>
     Which: threw HookBoom:<HookBoom(instances)>
            stack test/support/box_kit.dart 43:45                                   Switches.check
                  test/support/box_kit.dart 171:8                                   SquareType.instances
                  package:jet_cad_2d_plan/src/kits/guard.dart 88:18                 GuardedType.instances
                  package:jet_cad_2d/src/parametric/parametric_system.dart 1084:12  _Registration.instancesOf
                  package:jet_cad_2d/src/parametric/regeneration.dart 731:31        _plan
                  package:jet_cad_2d/src/parametric/regeneration.dart 1319:12       _run
                  package:jet_cad_2d/src/parametric/parametric_system.dart 990:14   ParametricEdit.apply
                  package:jet_cad_2d/src/document/undo.dart 195:30                  CommandDispatcher.execute
                  test/kits/guarded_instances_test.dart 58:30                       main.<fn>.<fn>
                  package:matcher                                                   expect
reverted: git checkout -- lib/src/kits/guard.dart; git diff --quiet exit 0

### M-PB-guard-b  (lib/src/kits/guard.dart ; flutter test test/kits/guarded_instances_test.dart)
00:00 +0 -1: PB-guard-1 a throwing instances is a KitHookFailure naming "instances": the edit rolled back, and probe returns it [E]
  Expected: throws <Instance of 'KitHookFailure'> with `kitId`: 'box' and `typeId`: 'box.square' and `hook`: 'instances' and `error`: <Instance of 'HookBoom'> with `hook`: 'instances'
    Actual: <Closure: () => void>
     Which: threw KitHookFailure:<KitHookFailure: box.square.generate threw HookBoom(instances)>
            stack test/support/box_kit.dart 43:45                                   Switches.check
                  test/support/box_kit.dart 171:8                                   SquareType.instances
                  package:jet_cad_2d_plan/src/kits/guard.dart 89:20                 GuardedType.instances
                  package:jet_cad_2d/src/parametric/parametric_system.dart 1084:12  _Registration.instancesOf
                  package:jet_cad_2d/src/parametric/regeneration.dart 731:31        _plan
                  package:jet_cad_2d/src/parametric/regeneration.dart 1319:12       _run
                  package:jet_cad_2d/src/parametric/parametric_system.dart 990:14   ParametricEdit.apply
                  package:jet_cad_2d/src/document/undo.dart 195:30                  CommandDispatcher.execute
                  test/kits/guarded_instances_test.dart 58:30                       main.<fn>.<fn>
                  package:matcher                                                   expect
reverted: git checkout -- lib/src/kits/guard.dart; git diff --quiet exit 0

### M-PB1  (lib/src/controller/services.dart ; flutter test test/controller/symbol_definition_test.dart)
00:00 +0 -1: PB-def-twice two calls for one key before its add executes: one ref, from any kit's services; executed once, through the document, the next call adds nothing [E]
  Expected: true
    Actual: <false>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/symbol_definition_test.dart 91:5    main.<fn>
  
reverted: git checkout -- lib/src/controller/services.dart; git diff --quiet exit 0

### M-PB2  (lib/src/controller/services.dart ; flutter test test/controller/symbol_definition_test.dart)
00:00 +0 -1: PB-def-twice two calls for one key before its add executes: one ref, from any kit's services; executed once, through the document, the next call adds nothing [E]
  Expected: true
    Actual: <false>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/symbol_definition_test.dart 93:5    main.<fn>
  
reverted: git checkout -- lib/src/controller/services.dart; git diff --quiet exit 0

### M-PB3  (lib/src/controller/services.dart ; flutter test test/controller/symbol_definition_test.dart)
00:00 +0 -1: PB-def-twice two calls for one key before its add executes: one ref, from any kit's services; executed once, through the document, the next call adds nothing [E]
  Expected: null
    Actual: <Instance of 'CompoundCommand'>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/symbol_definition_test.dart 104:5   main.<fn>
  
reverted: git checkout -- lib/src/controller/services.dart; git diff --quiet exit 0

### M-PB4  (lib/src/controller/plan_controller.dart ; flutter test test/controller/symbol_definition_test.dart)
00:00 +1 -1: PB-def-execute a controller execute, and a new plan, drop the pending refs: the next call is a new copy [E]
  Expected: false
    Actual: <true>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/symbol_definition_test.dart 124:5   main.<fn>
  
reverted: git checkout -- lib/src/controller/plan_controller.dart; git diff --quiet exit 0

### M-PB5  (lib/src/controller/plan_controller.dart ; flutter test test/controller/symbol_definition_test.dart)
00:00 +1 -1: PB-def-execute a controller execute, and a new plan, drop the pending refs: the next call is a new copy [E]
  Expected: false
    Actual: <true>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/symbol_definition_test.dart 131:5   main.<fn>
  
reverted: git checkout -- lib/src/controller/plan_controller.dart; git diff --quiet exit 0

### M-PB6  (lib/src/symbols/symbol_box.dart ; flutter test test/controller/symbol_definition_test.dart)
00:00 +2 -1: PB-def-top the base point, and the top: the first leaf's box for a circle or a closed outline, else the definition's box [E]
  Expected: [1650.5, 850.25, 2550.5, 1750.25]
    Actual: [1400.5, 850.25, 2800.5, 1750.25]
     Which: at location [0] is <1400.5> instead of <1650.5>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/symbol_definition_test.dart 145:5   main.<fn>
  
reverted: git checkout -- lib/src/symbols/symbol_box.dart; git diff --quiet exit 0

### M-PB7  (lib/src/symbols/symbol_box.dart ; flutter test test/controller/symbol_definition_test.dart)
00:00 +2 -1: PB-def-top the base point, and the top: the first leaf's box for a circle or a closed outline, else the definition's box [E]
  Expected: [110.75, 5.5, 1110.75, 405.5]
    Actual: [110.75, 405.5, 1110.75, 405.5]
     Which: at location [1] is <405.5> instead of <5.5>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/symbol_definition_test.dart 149:5   main.<fn>
  
reverted: git checkout -- lib/src/symbols/symbol_box.dart; git diff --quiet exit 0

### M-PB8  (lib/src/controller/services.dart ; flutter test test/controller/symbol_definition_test.dart)
00:00 +3 -1: PB-def-null null for a key no loaded library has, and while loading; symbolsState is the controller's, failed included [E]
  Expected: true
    Actual: <false>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/symbol_definition_test.dart 162:5   main.<fn>
  
reverted: git checkout -- lib/src/controller/services.dart; git diff --quiet exit 0

### M-PB-W1  (lib/src/controller/plan_controller.dart ; flutter test test/controller/host_words_test.dart)
00:00 +0 -1: PB-words-1 the host's word first, per locale: it overrides the kit's, the kit's own locale still beats the host's English, and a locale the kit lacks is the host's [E]
  Expected: 'Döşeme aracı'
    Actual: 'Döşeme'
     Which: is different. Both strings start the same, but the actual value is missing the following trailing characters:  aracı
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/host_words_test.dart 39:5           main.<fn>
  
reverted: git checkout -- lib/src/controller/plan_controller.dart; git diff --quiet exit 0

### M-PB-W2  (lib/src/controller/plan_controller.dart ; flutter test test/controller/host_words_test.dart)
00:00 +0 -1: PB-words-1 the host's word first, per locale: it overrides the kit's, the kit's own locale still beats the host's English, and a locale the kit lacks is the host's [E]
  Expected: 'Döşeme aracı'
    Actual: 'Döşeme'
     Which: is different. Both strings start the same, but the actual value is missing the following trailing characters:  aracı
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/host_words_test.dart 39:5           main.<fn>
  
reverted: git checkout -- lib/src/controller/plan_controller.dart; git diff --quiet exit 0

### M-PB-W3  (lib/src/controller/plan_controller.dart ; flutter test test/controller/host_words_test.dart)
00:00 +1 -1: PB-words-2 a host word in no known namespace, or naming no kit, is an ArgumentError naming the first problem; any kit is a kit [E]
  Expected: throws <Instance of 'ArgumentError'> with `message`: (contains '"label:test.x"' and contains 'unknownWordId' and not contains 'type:nokit')
    Actual: <Closure: () => PlanController>
     Which: returned <Instance of 'PlanController'>
  label:test.x
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/host_words_test.dart 60:7           main.<fn>
  
reverted: git checkout -- lib/src/controller/plan_controller.dart; git diff --quiet exit 0

### M-PB-W4  (lib/src/panels/kit_lookup.dart ; flutter test test/controller/host_words_test.dart)
00:00 +2 -1: PB-words-3 the panel's word lookup and the gallery's symbol names read the host's words first [E]
  Expected: 'En'
    Actual: 'Genişlik'
     Which: is different.
            Expected: En
              Actual: Genişlik
                      ^
             Differ at offset 0
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/host_words_test.dart 97:5           main.<fn>
  
reverted: git checkout -- lib/src/panels/kit_lookup.dart; git diff --quiet exit 0

### M-PB-W5  (lib/src/controller/plan_controller.dart ; flutter test test/controller/host_words_test.dart)
00:00 +2 -1: PB-words-3 the panel's word lookup and the gallery's symbol names read the host's words first [E]
  Expected: 'İkili koltuk'
    Actual: 'Two-seat sofa'
     Which: is different.
            Expected: İkili kolt ...
              Actual: Two-seat s ...
                      ^
             Differ at offset 0
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/host_words_test.dart 102:5          main.<fn>
  
reverted: git checkout -- lib/src/controller/plan_controller.dart; git diff --quiet exit 0

### M-PB-W6  (lib/src/editor/plan_tool_palette.dart ; flutter test test/controller/host_words_test.dart)
00:00 +3 -1: PB-words-4 the palette's label of a kit's tool [E]
  Test failed. See exception logs above.
  The test description was: PB-words-4 the palette's label of a kit's tool
  
reverted: git checkout -- lib/src/editor/plan_tool_palette.dart; git diff --quiet exit 0

```

## Fix round 1 (commit d0af9540)
Added PB-def-top-poly to symbol_definition_test.dart (closed diamond outline first + larger line: top = outline box [2600.5,1000.25,3400.5,1600.25]; open polyline first + larger circle: top = whole box [1100.5,300.25,2300.5,1500.25]). Rewrapped the Switches doc in box_kit.dart.
Empty-leaves guard (symbol_box.dart: `if (entry.leaves.isEmpty) return whole;`) is NOT reachable through symbolDefinition: a symbol with no shape makes the whole library unreadable (SymbolLibraryError rule 4: 'definition 12 (pp.none.empty@1) has no leaf'; symbolsState failed, symbol null). So M-PB9c is not pinned; the attempt (guard deleted) stays green, quoted below. Left as defensive code.
Gates: flutter test '00:40 +746: All tests passed!'; flutter analyze 'No issues found! (ran in 3.3s)'; format gate exit 0.
```
### M-PB9a  (lib/src/symbols/symbol_box.dart ; flutter test test/controller/symbol_definition_test.dart)
00:00 +3 -1: PB-def-top-poly a closed outline first is the top, an open polyline first is not (the leafless symbol is a library error, rule 4: the empty-leaves guard is unreachable here) [E]
  Expected: [2600.5, 1000.25, 3400.5, 1600.25]
    Actual: [2000.5, 800.25, 4000.5, 1600.25]
     Which: at location [0] is <2000.5> instead of <2600.5>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/symbol_definition_test.dart 204:5   main.<fn>
  
reverted: git checkout -- lib/src/symbols/symbol_box.dart; git diff --quiet exit 0

### M-PB9b  (lib/src/symbols/symbol_box.dart ; flutter test test/controller/symbol_definition_test.dart)
00:00 +3 -1: PB-def-top-poly a closed outline first is the top, an open polyline first is not (the leafless symbol is a library error, rule 4: the empty-leaves guard is unreachable here) [E]
  Expected: [1100.5, 300.25, 2300.5, 1500.25]
    Actual: [1500.5, 700.25, 1900.5, 1100.25]
     Which: at location [0] is <1500.5> instead of <1100.5>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/controller/symbol_definition_test.dart 206:5   main.<fn>
  
reverted: git checkout -- lib/src/symbols/symbol_box.dart; git diff --quiet exit 0

### M-PB9c-attempt  (lib/src/symbols/symbol_box.dart ; flutter test test/controller/symbol_definition_test.dart)
NO FAILURE: ["00:00 +4: PB-def-null null for a key no loaded library has, and while loading; symbolsState is the controller's, failed included", '00:00 +5: All tests passed!']
reverted: git checkout -- lib/src/symbols/symbol_box.dart; git diff --quiet exit 0

```
