# Task 4 report: SymbolLibrary.decode and K3's fifteen rules

**Status:** DONE
**Commit:** `07d8d752 feat(kit): the .jetlib validator, K3's fifteen rules (K3)`

## What was implemented

Exactly the brief's code blocks, verbatim. `dart format .` reflowed the test file and the validator. No logic changed.

- `packages/jet_cad_2d_kit/lib/src/model/symbol_library.dart` (new) contains:
  - `SymbolLeaf`, `SymbolLibraryError(rule, message)`, `SymbolEntry` and `SymbolLibrary`.
  - `SymbolLibrary` has `maxCoordinate`, `format`, `kits`, `entries`, `categories` and `decode`.
  - Guarded factories go through `registerKitComponentsWrapped`. `_ruleOf` maps a constructor's `ArgumentError` by field:
    - anything in `jetcad.library` is rule 2;
    - `key` is rule 5;
    - `tags`, `attachTo` and `family` are rule 8, and so is a unit's `kind`;
    - every other field is rule 1.
  - A `FormatException` is rule 2 in `jetcad.library` and rule 1 elsewhere.
  - Any other throwable from the codec (a TypeError, a null-check failure, a SchemaVersionError) is caught by `catch (e)` and becomes rule 1. Nothing but `SymbolLibraryError` escapes `decode`.
- `packages/jet_cad_2d_kit/lib/src/model/model.dart` gains `export 'symbol_library.dart';`, placed after the `register.dart` export.
- `packages/jet_cad_2d_kit/test/support/library_fixtures.dart` (new) holds the valid "sample" library and the codec-JSON breakers.
- `packages/jet_cad_2d_kit/test/model/symbol_library_test.dart` (new) holds V0a-V15s.

## TDD evidence

**RED.** Command: `cd packages/jet_cad_2d_kit && flutter test test/model/symbol_library_test.dart`. It failed to compile, as expected, because the types did not exist yet:

```
Compilation failed for testPath=.../test/model/symbol_library_test.dart: test/support/library_fixtures.dart:74:6: Error: Type 'SymbolLeaf' not found.
test/model/symbol_library_test.dart:26:5: Error: Undefined name 'SymbolLibrary'.
00:00 +0 -1: Some tests failed.
```

**GREEN.** Command: `flutter test test/model test/invariants`.

```
00:00 +160: All tests passed!
```

Every one-fault case passed on the first run with the rule it names. No fixture edit needed fixing.

## Gate (Step 7), run before the commit

`cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`

```
Formatted 21 files (0 changed) in 0.03 seconds.
00:00 +160: All tests passed!
No issues found! (ran in 2.4s)
Formatted 21 files (0 changed) in 0.03 seconds.
format exit 0
```

`git status --short` showed only the four task files. No `analysis_options.yaml` was touched. The four files were staged by explicit path and committed.

## Mutation check (Step 6): after the commit, on the committed file

Every mutation edited `lib/src/model/symbol_library.dart` and ran `flutter test test/model/symbol_library_test.dart --name <test> -r expanded`. Each was then reverted with `git checkout -- lib/src/model/symbol_library.dart`, and `git diff --quiet -- <file>` exited 0 after every revert. The tree was clean afterwards (`git diff --quiet HEAD` exit 0).

A script in the scratchpad ran them one at a time: `scratchpad/mutate.py`, which applies one exact-string replacement, runs the test, reverts and checks. Each mutation's output went to `scratchpad/mut-out/<name>.txt`. The red lines quoted below are copied from those files.

| Mutation | Change | Red tests | Quoted red line |
|---|---|---|---|
| M-V0a | sort `drafts` by key | V0a | `Expected: ['sample.sofa.three@3', 'sample.table.high-top@2', 'sample.chair.arm@1']` / `Actual: ['sample.chair.arm@1', 'sample.sofa.three@3', 'sample.table.high-top@2']` |
| M-V0a2 | `unit: null` | V0a | `Expected: UnitComponent:<UnitComponent(table, 4, numbered)>` / `Actual: <null>` |
| M-V0b | drop the leaves `..sort` | V0b | `Expected: [4210, 4211, 4212, 4213]` / `Actual: [4213, 4210, 4212, 4211]` |
| M-V1b | delete the diagnostics check | V1b | `the library was accepted; expected rule 1 naming [codec repaired]` |
| M-V1g | `on FormatException catch (e)` | V1g | `Null check operator used on a null value` at `DraftDocumentCodec._loadEntities` escaped through `SymbolLibrary.decode` |
| M-V2b | `library.format < 1` | V2b | `the library was accepted; expected rule 2 naming [format 2]` |
| M-V4d | delete the `leaves.isEmpty` check | V4d | `the library was accepted; expected rule 4 naming [sample.chair.arm@1, no leaf]` |
| M-V5a | delete the kit check | V5a | `Expected: <5>` / `Actual: <7>` (`message: definition 1068 (other.sofa.three@3) is named "sample.sofa.three@3", not "other.sofa.three@3"`) |
| M-V5b | delete the `'key' => 5` arm | V5b, V5c, V5d, V5e | `Expected: <5>` / `Actual: <1>` (`message: jetcad.symbol "sample.Sofa.three": Invalid argument (key): ...`) |
| M-V7 | delete the name check | V7a, V7b | `the library was accepted; expected rule 7 naming ["sample.sofa.three@2", sample.sofa.three@3]` |
| M-V8 | delete the tags/attachTo/family arm | V8a-V8f (V8g, the unit kind, stays green as designed) | `Expected: <8>` / `Actual: <1>` (`message: jetcad.symbol "sample.sofa.three": Invalid argument (tags): ... "Seating"`) |
| M-V9 | delete the unit-and-family check | V9a | `the library was accepted; expected rule 9 naming [sample.table.high-top@2, table-high]` |
| M-V10 | delete the unit loop | V10a, V10b | `the library was accepted; expected rule 10 naming [not a symbol]` |
| M-V11a | `if (false)` for `if (!closed)` (the rule-11 check disabled) | V11a, V11b | `the library was accepted; expected rule 11 naming [sample.table.high-top@2, 10D6, not a closed]` |
| M-V11 | `false \|\|` for the circle test | V0g | `SymbolLibraryError (rule 11): definition 1130 (sample.chair.arm@1) is a unit whose first leaf, 113A, is not a closed polyline or a circle` |
| M-V13c | `point` moved to the accepted cases | V13c point | `Expected: <13>` / `Actual: <15>` (`message: leaf 1075 of 1068 has a malformed point payload (2 coordinates, 1 scalars)`) |
| M-V14 (linetype) | delete the linetype check | V14b, V14c, V14d | `the library was accepted; expected rule 14 naming [1072, not BYBLOCK]` |
| M-V14 (text) | delete the text check | V14p | `the library was accepted; expected rule 14 naming [1072, text]` |
| M-V15 | `p.scalars[2] == 0` | V15p, V15q, V15r | `the library was accepted; expected rule 15 naming [1074, zero sweep]` |

Per-run summaries: V0a-V11 each ended `00:00 +0 -1: Some tests failed.` (or `-2`/`-4`/`-6` for the groups). The group runs were:

- rule 5: `+1 -4`
- rule 8: `+1 -6`
- V14: `+15 -3`
- rule 15: `+17 -3`

In each group the passes are the cases the mutation does not touch.

## Notes

- **M-V11a was applied as `if (!closed)` → `if (false)`, not as a deletion.** Deleting the block would leave `closed` as an unused local. The effect is the same: rule 11 is never raised.
- **The mutation runs triggered a workspace `flutter pub get`.** The resolution output appeared at the head of each mutation log. `git status --short` stayed clean afterwards: no `analysis_options.yaml` was rewritten.

## Self-review

- **Brief coverage:** files, interfaces, rule mapping, the export and the commit message all match the brief.
- **The guarded factory (Task 3 review note):** it catches `ArgumentError` and `FormatException` and maps them by rule. `TypeError` and the codec's null-check failures fall through to `catch (e)` and become rule 1. M-V1g proves that `catch` is load-bearing.
- **Tests:** they pin the rule number and the message parts, and every refusal test has a named mutation that turns it red. Test output is free of warnings.
- **Concerns:** none.
