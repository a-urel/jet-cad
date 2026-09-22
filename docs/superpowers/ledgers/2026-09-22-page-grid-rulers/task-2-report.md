# Task 2 report: `DocChange.capability`, and the skip in the index and the tile cache

## What was implemented

- `packages/jet_cad_2d/lib/src/document/doc_change.dart`: added
  `import 'command.dart';` and a `Capability capability` field (default
  `Capability.geometry`) to `CommandApplied`, `CommandUndone` and
  `CommandRedone`, each with the doc comment specified in the brief.
- `packages/jet_cad_2d/lib/src/document/undo.dart`: the three dispatcher
  construction sites now pass `capability`:
  - `execute()` → `CommandApplied(..., capability: command.capability)`
  - `undo()` → `CommandUndone(..., capability: inverse.capability)`
  - `redo()` → `CommandRedone(..., capability: inverse.capability)`
  (`inverse` is the command actually applied in `undo`/`redo`, per the brief.)
- `packages/jet_cad_2d/lib/src/index/spatial_index.dart`: added
  `import '../document/command.dart';` (needed for `Capability` — it was not
  visible transitively through `doc_change.dart`'s plain import) and, in
  `_onChange`, destructured `:final capability` in all three command-change
  cases and return before `_reconcile(touched)` when
  `capability == Capability.components`, with the comment from the brief.
- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`: in `applyChange`,
  the three command-change cases now destructure `:final capability` and
  return before the `touched.isEmpty` check when
  `capability == Capability.components` (comment: "Spec D13: a
  components-only edit moved no pixels."). Nothing else in this file
  changed — verified with `git diff` (see below).
- `packages/jet_cad_2d/test/document/compound_command_test.dart`: replaced
  the comment above the `compound.capability` assertion with the exact text
  from the brief. This is the only edit to that file.
- New test: `packages/jet_cad_2d/test/index/component_edit_skip_test.dart`
  (verbatim from the brief's Step 1, formatted by `dart format`).
- New test in `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`:
  `'a components-only change drops no tile'`, placed right after the first
  `applyChange` test ("criterion 5: a leaf edit invalidates its own tiles and
  no others"). Uses `rigOver(instancedFixture(measurer))`, `rig.paintOnce()`
  for a baked viewport, `rig.doc.rootHandle` (not a literal) as the touched
  handle, and compares `invalidationCount` before/after instead of asserting
  it is a hardcoded `0`, per the corrected instruction in the task
  description.

## TDD evidence

### RED

To get honest RED evidence after having already written the test files, I
backed up the four implementation files with `cp` to my scratchpad, reverted
them in the worktree to `HEAD`'s (pre-Task-2) content with
`git show HEAD:<path> > <path>` (four separate single-purpose commands, no
compound git invocation), ran the new tests to confirm the compile failure,
then restored the implementation from the `cp` backups (not `git checkout --`,
per the constraints' rule about reverting mutations).

```
$ cd packages/jet_cad_2d && CI=true dart test test/index/component_edit_skip_test.dart
00:00 +0: loading test/index/component_edit_skip_test.dart
00:00 +0 -1: loading test/index/component_edit_skip_test.dart [E]
  Failed to load "test/index/component_edit_skip_test.dart":
  test/index/component_edit_skip_test.dart:55:38: Error: The getter 'capability' isn't defined for the type 'CommandApplied'.
   - 'CommandApplied' is from 'package:jet_cad_2d/src/document/doc_change.dart' ('lib/src/document/doc_change.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'capability'.
        if (change case CommandApplied(:final capability) ||
                                       ^^^^^^^^^^
  test/index/component_edit_skip_test.dart:56:25: Error: The getter 'capability' isn't defined for the type 'CommandUndone'.
   ...
  test/index/component_edit_skip_test.dart:57:25: Error: The getter 'capability' isn't defined for the type 'CommandRedone'.
   ...
  test/index/component_edit_skip_test.dart:91:19: Error: The getter 'capability' isn't defined for the type 'CommandApplied'.
   ...
      expect(change.capability, Capability.geometry);
                    ^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart
test/tile_invalidation_test.dart:221:13: Error: No named parameter with the name 'capability'.
            capability: Capability.components),
            ^^^^^^^^^^
../jet_cad_2d/lib/src/document/doc_change.dart:19:9: Context: Found this candidate, but the arguments don't match.
  const CommandApplied({required this.label, required this.touched});
        ^^^^^^^^^^^^^^
00:00 +0 -1: loading .../test/tile_invalidation_test.dart [E]
  Failed to load "...": Compilation failed for testPath=.../test/tile_invalidation_test.dart: ...
00:00 +0 -1: Some tests failed.
```

### GREEN

After restoring the implementation from the `cp` backups:

```
$ cd packages/jet_cad_2d && CI=true dart test test/index/component_edit_skip_test.dart
00:00 +0: loading test/index/component_edit_skip_test.dart
00:00 +0: a components-only edit on the root reconciles nothing
00:00 +1: the change carries the capability of the command that made it
00:00 +2: a compound with one geometry member still reconciles
00:00 +3: the default capability is geometry, so old construction sites keep their meaning
00:00 +4: All tests passed!
```

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart
...
00:00 +0: criterion 5: a leaf edit invalidates its own tiles and no others
00:00 +1: a components-only change drops no tile
00:00 +2: criterion 5: a dragged instance drops the tiles it left
...
00:00 +12: All tests passed!
```

## Gate line: `packages/jet_cad_2d`

```
$ CI=true dart test
...
00:03 +841: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +842: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +842: All tests passed!
$ echo $?
0
```
842 tests, all passing. Exit code 0.

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ echo $?
0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 120 files (0 changed) in 0.29 seconds.
$ echo $?
0
```
(First run flagged the new test file as unformatted — 1 file changed, exit
1 — because I had hand-written it; `dart format test/index/component_edit_skip_test.dart`
fixed it, then this rerun is clean.)

## Gate line: `packages/jet_cad_2d_flutter`

```
$ CI=true flutter test
...
00:11 +772: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
$ echo $?
1
```
Final counter was `+772` (700 passed, 1 skipped, 5 failed) — exactly the
five pre-existing `text_ladder_golden_test.dart` failures named in the task
description and nothing else. Exit code 1, as expected for this gate line.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 2.2s)
$ echo $?
0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 136 files (0 changed) in 0.28 seconds.
$ echo $?
0
```

`flutter pub get`/`flutter test` triggered a dependency resolution
("Resolving dependencies...") on both runs; `git status --short` after both
runs showed no `analysis_options.yaml` (or any other) rewrite, so no
`git checkout --` was needed.

## Files changed

- `packages/jet_cad_2d/lib/src/document/doc_change.dart`
- `packages/jet_cad_2d/lib/src/document/undo.dart`
- `packages/jet_cad_2d/lib/src/index/spatial_index.dart`
- `packages/jet_cad_2d/test/document/compound_command_test.dart`
- `packages/jet_cad_2d/test/index/component_edit_skip_test.dart` (new)
- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`

Commit: `362b422` — "feat(engine): DocChange carries the command's
capability; index and tiles skip component edits". Trailer verified:
`git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.

## Self-review

**Completeness.** All four `component_edit_skip_test.dart` tests present and
green; the tile-cache test present and green; all three `DocChange` classes
(`CommandApplied`, `CommandUndone`, `CommandRedone`) carry `capability`; all
three dispatcher sites (`execute`, `undo`, `redo`) pass it through; both
consumers (`SpatialIndex._onChange`, `TileCache.applyChange`) skip on
`Capability.components`; the `compound_command_test.dart` comment rewritten
exactly as specified.

**Quality.** The `Capability` import had to be added explicitly to
`spatial_index.dart` — it is not re-exported transitively through
`doc_change.dart`'s plain (non-`export`) import of `command.dart`, so without
this addition the file would not compile. `tile_cache.dart` already imported
the `jet_cad_2d` barrel, which does `export 'src/document/command.dart'`, so
no new import was needed there.

**Discipline.** `git diff packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
shows exactly the D13 skip (three lines: the pattern destructuring change and
the two-line early return) — nothing else in that file changed.
`compound_command_test.dart`'s diff is the one comment. No mutation sweep was
run beyond what the brief's Step 1 tests exercise inline (M-04r, M-04s are
named in the brief's own test comments, not run as a separate sweep).

**Testing.** No test output was synthesized — the RED transcripts above were
captured by genuinely reverting the four implementation files to their
pre-Task-2 (`HEAD`) content via `cp`-backed swaps, never `git checkout --`,
and restoring from the `cp` backups afterward (per the constraints file's
mutation-revert rule, applied here to get honest TDD evidence rather than to
a fault-seeded mutant). Both full gate lines were run to completion and their
exit codes captured directly, not inferred.

## Concerns

None. Both gate lines are green in the sense specified by the brief (the
`jet_cad_2d_flutter` `flutter test` exit 1 is exactly the five pre-existing
golden failures).


## Controller correction (2026-09-22)

The breakdown "(700 passed, 1 skipped, 5 failed)" above is wrong arithmetic on the pasted counter `+772 ~1 -5`: 772 counted = 766 passed + 1 skipped + 5 failed. The transcript is the evidence; the parenthetical was the implementer's misread, not a printed figure. Ruling 04-10.
