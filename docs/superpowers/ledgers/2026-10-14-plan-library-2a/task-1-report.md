# Task 1 report: engine seams E1, E3, E4

Status: DONE

Commit: `3d84a62c feat(engine): catalog type queries, PartialMutationError, unreadable components (2a E1, E3, E4)` on `feat/plan-library-2a` (BASE `aee66cb7`). Working tree clean afterwards (`git status --short` prints nothing).

## What was implemented

- **E1** (`lib/src/parametric/parametric_system.dart`): `Iterable<String> ParametricCatalog.typeIds` (`{for (final t in _types) t.typeId}`: registration order, each id once) and `String? ParametricCatalog.typeIdOf(CommandTarget target, Handle group)` (`_naming(target, _types, group)?.typeId`), doc comments as the brief gives them, placed after `objectsOf`.
- **E3**: new `lib/src/core/partial_mutation_error.dart` (`final class PartialMutationError extends StateError`), exported from `lib/jet_cad_2d.dart` between `list_equality.dart` and `tolerance.dart`. The four throws now construct `PartialMutationError` with the same message: `CompoundCommand.apply` (`commands.dart`), `_undoInner`, `_cascade`, `_run`'s apply loop (`regeneration.dart`). The import goes into `commands.dart` and `parametric_system.dart` (the library `regeneration.dart` is a part of). Comments updated as Step 6 orders: `CompoundCommand` class comment, `_undoInner` comment, `_cascade` comment. The other `StateError`s (refusals) are untouched.
- **E4** (`lib/src/document/component.dart`): `loadJson(json, {List<Diagnostic>? diagnostics})` with the brief's body and doc comment. With no list, the factory is called with no try, exactly as before. With a list, any throw (`catch (error)`, `Error` included) keeps the payload raw via `attachUnknown` (with `typeId`) and adds `Diagnostic(severity: error, code: 'component.unreadable', message: '<typeId>: <error>', handles: [handle])`. `toJson` now writes unknown payloads first and registered values second, with the brief's comment over the moved block.
- **E4 plumbing** (`lib/src/codec/json_codec.dart`): `decode` and `decodeString` take `bool keepUnreadableComponents = false`. `decodeString` passes it on. The components load passes `diagnostics: keepUnreadableComponents ? (diagnostics ?? <Diagnostic>[]) : null`. `decode`'s doc comment is replaced with the brief's text.
- **CHANGELOG**: `## Unreleased` with the three bullets, between `# Changelog` and `## 0.7.2`.

## TDD evidence

### RED (Step 4)

Command: `cd packages/jet_cad_2d && dart test test/parametric/catalog_queries_test.dart test/parametric/partial_mutation_test.dart test/codec/unreadable_component_test.dart`, exit 1. All three files fail to compile. First error line of each:

```
  test/parametric/catalog_queries_test.dart:39:24: Error: The getter 'typeIds' isn't defined for the type 'ParametricCatalog'.
  test/parametric/partial_mutation_test.dart:87:45: Error: 'PartialMutationError' isn't a type.
  test/codec/unreadable_component_test.dart:172:9: Error: No named parameter with the name 'keepUnreadableComponents'.
```

The full error list also names `typeIdOf` (catalog_queries_test.dart:89 and following) and `loadJson`'s `diagnostics` (`unreadable_component_test.dart:100:29: Error: No named parameter with the name 'diagnostics'.`). No other compile errors appeared: the brief's test code compiled as written once the members existed.

### GREEN (Step 11)

Same command after Steps 5-10:

```
00:00 +12: All tests passed!
```

That is 12 tests: 2 for E1, 4 for E3, 6 for E4.

## Gates

### packages/jet_cad_2d (Step 12)

- `dart format .`: `Formatted 181 files (5 changed)` (the three new test files plus `commands.dart` and `regeneration.dart`, where the longer `PartialMutationError(` call made the formatter re-break the throw).
- `dart test`: `+1301 -2: Some tests failed.` The only two failures:
  - `test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte`
  - `test/testing/generate_document_test.dart: both text fractions default to zero and change nothing`

  Both are the `packages/jet_cad_2d` lines of `tool/ci/standing_failures.txt` and were already failing before this task.
- The existing rollback test (`test/document/compound_command_test.dart:204`, "a rollback inverse that throws surfaces both failures…", `isA<StateError>()`) stays green: `dart test test/document/compound_command_test.dart` gives `+10: All tests passed!`.
- `dart analyze`: `No issues found!`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 181 files (0 changed)`, exit 0.

### Dependents (Step 13), no code or test changed in any

- `packages/jet_cad_2d_flutter`, `flutter test`: `+1450 ~1 -5: Some tests failed.` The five failures are exactly `test/golden/text_ladder_golden_test.dart: text ladder rung 1..5 (RenderBackend.canvas)`. All five are standing failures. The two `text_lod_ladder` standing lines passed locally on this run.
- `packages/jet_cad_floor_plan`, `flutter test`: `01:58 +2008 ~4: All tests passed!`

I also ran the other three packages Step 13 lists, because E4's opt-in is checked against `SymbolLibrary.decode` in the kit:
- `packages/jet_cad_2d_kit`: `+253: All tests passed!`
- `packages/jet_cad_restaurant_symbols`: `+97: All tests passed!`
- `packages/jet_cad_2d_gpu`: `+20: All tests passed!`

`git status --short` was empty after all pub/test runs. No `analysis_options.yaml` was rewritten.

## Mutations (Step 15)

All mutations ran after the commit, on committed files only. Each was applied, its test was run with `dart test <file> --name '<id>'`, the file was reverted with `git checkout -- <file>`, and `git diff --quiet -- <file>` exited 0 every time. A small Python driver did the apply → test → checkout → diff-check sequence (scratchpad `mutate.py`). Every mutant compiled: no compile errors appeared in any run. Every run gave `00:00 +0 -1: Some tests failed.`

| Mutation | File | Test | Failing line quoted |
|---|---|---|---|
| M-E1a sorted `typeIds` | parametric_system.dart | E1-typeIds | `Expected: ['test.softRect', 'test.clipRect', 'test.trip']` / `Actual: ['test.clipRect', 'test.softRect', 'test.trip']` |
| M-E1b list, one per registration | parametric_system.dart | E1-typeIds | `Actual: ['test.softRect', 'test.clipRect', 'test.trip', 'test.clipRect']` |
| M-E1c first registration, no root rule | parametric_system.dart | E1-typeIdOf | `Expected: 'test.clipRect'` / `Actual: 'test.softRect'` |
| M-E1d last registration, no root rule | parametric_system.dart | E1-typeIdOf | `Expected: null` / `Actual: 'test.clipRect'` |
| M-E3a compound back to StateError | commands.dart | E3-compound | `Which: threw StateError:<Bad state: "Two lines": child 1 threw (tripped) and the rollback then threw (tripped); the target is partially mutated …>` |
| M-E3b `_undoInner` back to StateError | regeneration.dart | E3-undo | `Which: threw StateError:<Bad state: "Armed edit": tripped, and undoing the edit then threw (tripped); …>` |
| M-E3c `_cascade` back to StateError | regeneration.dart | E3-cascade | `Which: threw StateError:<Bad state: "Armed edit": the reference cascade threw (tripped) and its rollback threw (tripped); …>` |
| M-E3d `_run` back to StateError | regeneration.dart | E3-regeneration | `Which: threw StateError:<Bad state: "Armed edit": regeneration threw (tripped) and its rollback threw (tripped); …>` |
| M-E4a no `attachUnknown` in catch | component.dart | E4-1 | `Expected: [{'typeId': 'test.spar', 'width': -5.0, 'depth': 80.0}]` / `Actual: []` |
| M-E4b no `diagnostics.add` | component.dart | E4-1 | `Expected: an object with length of <1>` / `Actual: []` |
| M-E4c `handles: const []` | component.dart | E4-1 | `Expected: [4200]` / `Actual: []` |
| M-E4d `message: '$error'` | component.dart | E4-1 | `Expected: a string starting with 'test.spar: '` / `Actual: 'Invalid argument (width): must be positive: -5.0'` |
| M-E4e `on Exception catch` | component.dart | E4-2 | the test throws: `Null check operator used on a null value` at `unreadable_component_test.dart 32:23 Spar.fromJson` |
| M-E4f no null branch, `diagnostics?.add` | component.dart | E4-3 | `Expected: throws <Instance of 'ArgumentError'>` / `Which: returned <null>` |
| M-E4g registered block first in `toJson` | component.dart | E4-4 | `Expected: {'width': 950.5, 'depth': 80.0}` / `Actual: {'width': -5.0, 'depth': 80.0}` |
| M-E4h `diagnostics: null` | json_codec.dart | E4-5 | the test throws: `Invalid argument (width): must be positive: -5.0` at `unreadable_component_test.dart 176:39` (the first decode) |
| M-E4i `diagnostics: diagnostics` | json_codec.dart | E4-6 | `Expected: throws <Instance of 'ArgumentError'>` / `Which: returned <Instance of 'DraftDocument'>` |
| M-E4j `keepUnreadableComponents ? diagnostics : null` | json_codec.dart | E4-5 | the test throws: `Invalid argument (width): must be positive: -5.0` at `unreadable_component_test.dart 189:38` (the second decode, `quiet`, as the brief says) |

For M-E4e, M-E4h and M-E4j the error escapes the test body instead of failing an `expect`, so the driver's `Expected:` filter caught nothing. I re-ran each by hand, with the same apply → test → `git checkout` → `git diff --quiet` (exit 0) sequence, to quote the lines above.

After the mutation step: `git status --short` was empty and HEAD was still `3d84a62c`.

## Files changed

- packages/jet_cad_2d/lib/src/core/partial_mutation_error.dart (new)
- packages/jet_cad_2d/lib/jet_cad_2d.dart
- packages/jet_cad_2d/lib/src/document/commands.dart
- packages/jet_cad_2d/lib/src/parametric/parametric_system.dart
- packages/jet_cad_2d/lib/src/parametric/regeneration.dart
- packages/jet_cad_2d/lib/src/document/component.dart
- packages/jet_cad_2d/lib/src/codec/json_codec.dart
- packages/jet_cad_2d/CHANGELOG.md
- packages/jet_cad_2d/test/parametric/catalog_queries_test.dart (new)
- packages/jet_cad_2d/test/parametric/partial_mutation_test.dart (new)
- packages/jet_cad_2d/test/codec/unreadable_component_test.dart (new)

## Deviations from the brief

1. **Comment rewrapping (no change in wording).** Step 6 edits two doc comments in place: `CompoundCommand`'s class comment and `_cascade`'s comment. Done literally, both left a line over 80 columns, so I re-broke the surrounding comment lines to fit. The words are exactly the brief's. Also, the `_undoInner` sentence "That failure is a [PartialMutationError] (spec 2a E3)." is joined onto the existing comment's last line and wrapped, not put on its own line.
2. **`dart format` re-broke the three test files and the four throw statements.** The brief's code is not laid out in this package's formatter style. Step 12's `dart format .` changed line breaks only: no token, assertion, name or mutation comment changed. The mutation targets were matched against the formatted text. For example, `throw PartialMutationError(` now sits on its own line, followed by the message string.
3. **Step 13 scope.** The dispatch asked for `jet_cad_2d_flutter` and `jet_cad_floor_plan`. I also ran `jet_cad_2d_kit`, `jet_cad_restaurant_symbols` and `jet_cad_2d_gpu`, as the brief's Step 13 lists them. All were green; nothing beyond that.

No change to any interface, name or signature in the brief.

## Self-review

- The `diagnostics == null` path is byte-for-byte the old behaviour: the factory is called with no try. This is what keeps `SymbolLibrary.decode` and `jet_cad_floor_plan` unchanged. Their suites are green.
- The `toJson` reorder changes output only when one handle has both a raw payload and a registered value under the same type id. Before E4, `loadJson` could never produce that. Directly, it can still arise from a caller's `attachUnknown` with a registered id, or from `restore` of a snapshot with such a payload. In those cases the registered value now wins where the raw payload used to. This is the brief's intent and is documented in the comment.
- A kept-raw payload survives remove + undo. `checkRestorable` checks only registered entries, and `restore` appends unknown payloads unchecked, so `AddNodeCommand`'s inverse path cannot refuse it.
- `typeIds` returns a fresh insertion-ordered `Set` typed as `Iterable`. A caller that needs indexing must call `.toList()`, as the E1 test does.
- `typeIdOf` reads only the tree and the stores (`_naming`), and no client code runs. It adds nothing to the frame path.

## Concerns

None blocking.
- For Task 11: a group whose only component was kept raw is now a plain root-level group to the parametric system. `typeIdOf` returns null and `names` returns false, so its children are directly editable. This is what the brief's plan decision says. Task 11's `reportUnreadable` / lock handling is what keeps such a group from being edited freely.
