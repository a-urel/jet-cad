# Task 6 report: `RemoveEntityCommand` cascades to fills

## What changed

- `packages/jet_cad_2d/lib/src/document/commands.dart`: replaced
  `RemoveEntityCommand.apply` with the cascade-aware version from the brief,
  verbatim. Behavior:
  - Removing a `fill` entity: removes it and calls `target.fills.unlink(handle)`;
    inverse is `AddEntityCommand`.
  - Removing a boundary with exactly one dependent fill: removes both entities
    in the same mutation, calls `target.fills.dropBoundary(handle)`; inverse is
    `AddRegionCommand(fill: fillRecord, boundary: record, boundaryPayload: payload)`.
  - Removing a boundary with more than one dependent fill: throws `StateError`
    rather than inventing an n-ary inverse (this plan's commands cannot create
    that state).
  - Removing a boundary with no dependents: unchanged prior behavior, but now
    also calls `target.fills.dropBoundary(handle)`.
- `packages/jet_cad_2d/test/document/region_command_test.dart`: appended the
  two tests from the brief verbatim — "removing a boundary removes its fill,
  and undo restores both" and "removing a fill alone unlinks it and leaves the
  boundary drawable".

Both edits matched the brief's code exactly; no discrepancy between the brief
and the tree.

## Suite output — `packages/jet_cad_2d`

`region_command_test.dart` alone (13 tests, includes the 2 new ones):

```
00:00 +0: loading test/document/region_command_test.dart
00:00 +0: the fill gets the lower handle, so it draws underneath
00:00 +1: apply refuses an inverted pair rather than drawing it wrong
00:00 +2: the fill names its boundary and the index links them
00:00 +3: the triangulation is materialised by the command, not by a draw
00:00 +4: an unfillable boundary is refused before anything is written
00:00 +5: undo removes both halves and redo restores the same handles
00:00 +6: editing a boundary re-triangulates and touches its fills
00:00 +7: the handle and the geomIndex survive the edit
00:00 +8: it refuses a fill, because a fill's payload is a reference
00:00 +9: undo restores the previous geometry and its triangulation
00:00 +10: two edits then two undos: the inverse must not share the store's buffer
00:00 +11: removing a boundary removes its fill, and undo restores both
00:00 +12: removing a fill alone unlinks it and leaves the boundary drawable
00:00 +13: All tests passed!
```

Full engine suite (`CI=true dart test`), tail:

```
00:01 +748: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +749: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +750: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +750: All tests passed!
```

750 tests passed (748 pre-existing + 2 new). Re-ran once more after the
mutation round-trips to confirm the restored file is bit-identical and the
suite is still green — same 750/750 result.

`dart analyze`:

```
Analyzing jet_cad_2d...
No issues found!
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 110 files (0 changed) in 0.13 seconds.
```

## Suite output — `packages/jet_cad_2d_flutter`

`CI=true flutter test`, tail:

```
00:02 +241 ~1: test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:02 +242 ~1: All tests passed!
```

242 tests passed, 1 skipped (pre-existing `~1`, unrelated to this change).

`flutter analyze`:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 45 files (0 changed) in 0.06 seconds.
```

`git status --porcelain` after both runs shows only the two intended files
modified — no `analysis_options.yaml` rewritten by `flutter pub get`.

## Mutation transcripts

All three run with `cp` backup + `trap ... EXIT` restore inside one shell call
each, per the brief.

### T6a — do not cascade, leave the fill orphaned

Mutation: `perl -0pi -e 's/    if \(dependents\.length == 1\) \{/    if (false) {/'`

```
=== T6a: do not cascade -- leave the fill orphaned ===
110:    if (false) {
00:00 +11 -1: removing a boundary removes its fill, and undo restores both [E]
  Bad state: 13 carries 1 fills; remove them before removing the boundary
  package:jet_cad_2d/src/document/commands.dart 129:7  RemoveEntityCommand.apply
  package:jet_cad_2d/src/document/undo.dart 109:28     CommandDispatcher.execute
  test/document/region_command_test.dart 217:18        main.<fn>

00:00 +12 -1: Some tests failed.

Failing tests:
  test/document/region_command_test.dart: removing a boundary removes its fill, and undo restores both
```

**KILLED.** With the `length == 1` branch disabled, a single dependent falls
into the `dependents.isNotEmpty` guard and throws `StateError` instead of
cascading — caught by `removing a boundary removes its fill, and undo restores
both` at the `doc.commands.execute(RemoveEntityCommand(cmd.boundary.handle))`
call.

### T6b — cascade but forget the index (drop the `dropBoundary` call)

Mutation: removes the `target.fills.dropBoundary(handle);` line immediately
before `target.invalidateDerived();` / `return CommandResult(... AddRegionCommand(`
in the boundary-cascade branch, keeping everything else (entities/geometry
removed, `AddRegionCommand` inverse returned).

```
=== T6b: cascade but forget the index ===
117d116
<       target.fills.dropBoundary(handle);
00:00 +11 -1: removing a boundary removes its fill, and undo restores both [E]
  Expected: <0>
    Actual: <1>

  package:matcher                               expect
  test/document/region_command_test.dart 220:5  main.<fn>

00:00 +12 -1: Some tests failed.

Failing tests:
  test/document/region_command_test.dart: removing a boundary removes its fill, and undo restores both
```

**KILLED.** As the task instructions warned, entity liveness alone (`slotOf`
returning `isNull`) stays green under this mutation — the entities are still
gone. It is `expect(doc.fills.entryCount, 0)` (line 220) that fails: the
triangulation entry for the removed boundary's handle is left behind in
`FillIndex` because `dropBoundary` never ran. Without that assertion this
mutation would have survived.

### T6c — removing a fill forgets to unlink it

Mutation: `perl -0pi -e 's/      target\.fills\.unlink\(handle\);//'`

```
=== T6c: removing a fill forgets to unlink it ===
98c98
<       target.fills.unlink(handle);
---
>
00:00 +12 -1: removing a fill alone unlinks it and leaves the boundary drawable [E]
  Expected: empty
    Actual: [18]

  package:matcher                               expect
  test/document/region_command_test.dart 234:5  main.<fn>

00:00 +12 -1: Some tests failed.

Failing tests:
  test/document/region_command_test.dart: removing a fill alone unlinks it and leaves the boundary drawable
```

**KILLED.** `expect(doc.fills.fillsOf(cmd.boundary.handle), isEmpty)` catches
the stale link — `fillsOf` still reports the removed fill's handle (`[18]`)
because `unlink` never ran.

After each mutation the file was restored from `/tmp/t6.dart` inside the same
shell call as the mutation and the test run (`trap ... EXIT`), consistent with
the brief's requirement not to use `git checkout` to revert. A final `diff
/tmp/t6.dart lib/src/document/commands.dart` after all three rounds confirmed
byte-identical restoration, and the full 750-test suite was re-run clean
afterward.

## Anything uncertain / discrepancies with the brief

None found. The brief's `apply` body matched the pre-existing file at
`3f6e7ba` exactly (down to comments), the two new tests matched the existing
`region_command_test.dart` helpers (`region(doc)`, `squareLoop()`) with no
adaptation needed, and all three named mutations killed on the first attempt
with the exact `perl` commands given. `git status --porcelain` confirms no
`analysis_options.yaml` changes and no other untracked/modified files besides
the two intended edits.
