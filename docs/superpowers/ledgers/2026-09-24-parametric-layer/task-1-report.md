# Task 1 report — the dispatcher's `expander` slot

## Status: DONE

## What was implemented

`packages/jet_cad_2d/lib/src/document/undo.dart`:

- Added `DraftCommand Function(DraftCommand command)? expander;` on
  `CommandDispatcher`, next to `onBeforeMutate`, with the doc comment from
  the brief verbatim (spec 06 D2 reference, "never undo or redo", pure
  wrapper contract, "one slot, one owner").
- `execute` now computes `final effective = expander?.call(command) ??
  command;` immediately after `_checkNotDisposed()` and before `_require`,
  then runs `_require(effective)`, `effective.apply(target)`, and builds the
  `CommandApplied` change from `effective.label` / `effective.capability`
  instead of `command`'s. `undo()` and `redo()` are untouched — they replay
  concrete inverses popped from the stacks and never consult `expander`.

This is exactly the diff prescribed by the task brief (Step 3), transcribed
verbatim; no deviation was needed against the real code in `undo.dart`.

Test added: `packages/jet_cad_2d/test/document/expander_test.dart`, exactly
as given in the brief (X1–X4), using existing test helpers `addDrafted` and
`linePayload` from `packages/jet_cad_2d/lib/src/document/drafting.dart`
(exported via the `jet_cad_2d` barrel), and `DraftDocumentCodec`,
`DraftPermissions`, `PermissionDeniedError`, `Capability` from the existing
engine API. All of these matched the real code as-is; no brief/reality
mismatch was found.

## TDD evidence

### RED

Command:
```
cd packages/jet_cad_2d && CI=true dart test test/document/expander_test.dart
```

Output (truncated to the relevant errors):
```
00:00 +0: loading test/document/expander_test.dart
00:00 +0 -1: loading test/document/expander_test.dart [E]
  Failed to load "test/document/expander_test.dart":
  test/document/expander_test.dart:33:18: Error: The setter 'expander' isn't defined for the type 'CommandDispatcher'.
   - 'CommandDispatcher' is from 'package:jet_cad_2d/src/document/undo.dart' ('lib/src/document/undo.dart').
  Try correcting the name to the name of an existing setter, or defining a setter or field named 'expander'.
      doc.commands.expander = (c) => _Tagged(c, {Capability.geometry});
                   ^^^^^^^^
  ... (three more identical errors, at lines 47, 60, 76)
00:00 +0 -1: Some tests failed.

Failing tests:
  test/document/expander_test.dart: loading test/document/expander_test.dart
EXIT: 1
```

Exactly the expected compile error: `expander` did not exist.

### GREEN

Command:
```
cd packages/jet_cad_2d && dart format lib/src/document/undo.dart test/document/expander_test.dart && CI=true dart test test/document/expander_test.dart
```

Output:
```
Formatted test/document/expander_test.dart
Formatted 2 files (1 changed) in 0.01 seconds.
00:00 +0: loading test/document/expander_test.dart
00:00 +0: X1 execute runs the expanded command and reports it
00:00 +1: X2 undo and redo never call the expander
00:00 +2: X3 permissions are checked on the expanded command
00:00 +3: X4 history holds the expanded command's inverse
00:00 +4: All tests passed!
EXIT: 0
```

## Gate-line summaries

### Engine line (`packages/jet_cad_2d`)

```
cd packages/jet_cad_2d && CI=true dart test
```
Result: `00:03 +915: All tests passed!` — exit 0. (911 branch-point + 4 new =
915, matches.)

```
dart analyze
```
Result: `Analyzing jet_cad_2d... No issues found!` — exit 0.

```
dart format --output=none --set-exit-if-changed .
```
Result: `Formatted 134 files (0 changed) in 0.25 seconds.` — exit 0.

### Render line (`packages/jet_cad_2d_flutter`)

```
cd packages/jet_cad_2d_flutter && CI=true flutter test
```
Result (tail): `+923 ~1 -5: Some tests failed.` with the five failures all
in `test/golden/text_ladder_golden_test.dart` ("text ladder rung 1..5
(RenderBackend.canvas)") and nothing else. Exit code: **1** (confirmed via
`echo $?` after redirecting to a file, not from the piped `tail`). This
matches the documented standing exception exactly: 923 passed + 1 skip + the
five pre-existing golden failures, no new failures introduced.

```
flutter analyze
```
Result: `Analyzing jet_cad_2d_flutter... No issues found! (ran in 1.7s)` —
exit 0. (Ran a `flutter pub get`-style dependency resolution first, printing
outdated-package notices; this did not touch `analysis_options.yaml` — see
below.)

```
dart format --output=none --set-exit-if-changed .
```
Result: `Formatted 175 files (0 changed) in 0.33 seconds.` — exit 0.

## `analysis_options.yaml` check

`git status --short` before and after the full gate run showed only:
```
 M packages/jet_cad_2d/lib/src/document/undo.dart
?? packages/jet_cad_2d/test/document/expander_test.dart
```
No `analysis_options.yaml` was modified by `flutter analyze`'s dependency
resolution, so nothing needed restoring.

## Files changed

- `packages/jet_cad_2d/lib/src/document/undo.dart` (modified — `expander`
  field + `execute` body)
- `packages/jet_cad_2d/test/document/expander_test.dart` (new)

## Commit

`058918d` — `feat(engine): CommandDispatcher.expander, called in execute
only (spec 06 D2)`, trailer `Co-Authored-By: Claude Opus 5.5
<noreply@anthropic.com>` present exactly.

## Self-review findings

- Diffed the commit against the brief's Step 3 code block: identical,
  including comments.
- Confirmed `undo()` and `redo()` bodies are untouched (no `expander` call
  anywhere in them) — grepped `undo.dart` for `expander` and it appears only
  in the field declaration and in `execute`.
- Confirmed the four new tests (X1–X4) exercise: the expanded command's
  label/capability reaching the `CommandApplied` change (X1), the expander
  never firing on `undo`/`redo` (X2), permission checks running against the
  *expanded* command's capabilities rather than the original (X3, and that a
  denied permission leaves history/document untouched), and that the pushed
  inverse is the expanded command's inverse, not the original's (X4).
- No fixtures here needed the "off the identity" global constraint — this is
  a pure command-dispatch plumbing test with no geometry/transform math, so
  the mutation-testing/degenerate-fixture concern from CLAUDE.md's testing
  bar doesn't bite the same way; the tests are already structured to fail
  under exactly the mutations that matter (wrong command passed to
  `_require`/`apply`, expander called from `undo`/`redo`, wrong label/
  capability propagated, wrong inverse pushed).

## Concerns

None. Brief matched the real code exactly; no ambiguity encountered.
