# Task 4 report — `AddRegionCommand`

Commit: `ce09943` on `main` (built on `a21188d`).

## What changed

- `packages/jet_cad_2d/lib/src/document/commands.dart`: appended
  `AddRegionCommand`, its top-level helper `triangulationFor`, and
  `RemoveRegionCommand`, verbatim from the brief's Step 3, plus the four new
  imports it needs (`dart:typed_data`, `../geometry/triangulate.dart`,
  `style.dart`; `entity_store.dart`/`geometry_store.dart`/`command.dart` were
  already imported).
- `packages/jet_cad_2d/test/document/region_command_test.dart` (new):
  the six tests from the brief's Step 1, copied verbatim.

I read the supporting code before implementing (`EntityRecord`,
`GeometryPayload`, `HandleSeed`, `FillIndex`, `CommandTarget`,
`ReservedHandles`, `DraftColor`/`TrueColor`, `kLineweightDefault`,
`boundaryHandleOf`, `triangulateSimplePolygon`) and every signature the brief
assumes matched what Tasks 1-3 actually produced — no adaptation was needed
beyond the imports above.

Nothing in the brief's code diverged from its own comments as far as I could
exercise it; see the T4d note below for the one place I checked closely.

## Step 2 — red before implementing

```
$ cd packages/jet_cad_2d && dart test test/document/region_command_test.dart
00:00 +0: loading test/document/region_command_test.dart
00:00 +0 -1: loading test/document/region_command_test.dart [E]
  Failed to load "test/document/region_command_test.dart":
  test/document/region_command_test.dart:9:1: Error: Type 'AddRegionCommand' not found.
  ...
00:00 +0 -1: Some tests failed.
```

## Step 4 — green after implementing

```
$ cd packages/jet_cad_2d && CI=true dart test test/document/region_command_test.dart
00:00 +0: loading test/document/region_command_test.dart
00:00 +0: the fill gets the lower handle, so it draws underneath
00:00 +1: apply refuses an inverted pair rather than drawing it wrong
00:00 +2: the fill names its boundary and the index links them
00:00 +3: the triangulation is materialised by the command, not by a draw
00:00 +4: an unfillable boundary is refused before anything is written
00:00 +5: undo removes both halves and redo restores the same handles
00:00 +6: All tests passed!
```

## Full suite output, both packages

```
$ cd packages/jet_cad_2d && CI=true dart test
...
00:02 +742: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +743: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +743: All tests passed!

$ cd packages/jet_cad_2d && dart analyze
Analyzing jet_cad_2d...
No issues found!

$ cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.14 seconds.
```

(One line in the new `apply` exceeded the formatter's column width; I ran
`dart format` once to let it wrap that line before the final
`--set-exit-if-changed` check, which then reported 0 changed.)

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:02 +241 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:02 +242 ~1: All tests passed!

$ cd packages/jet_cad_2d_flutter && flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)

$ cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
Formatted 45 files (0 changed) in 0.06 seconds.
```

Suite summary: 743 tests in `jet_cad_2d` (all new prior to this task: 737 +
6 new region-command tests), 242 in `jet_cad_2d_flutter` (unaffected by this
task, pre-existing `~1` skip). Both packages: 0 analyzer issues, 0 format
diffs.

## Step 5 — the four named mutations

Run as one shell call, mutate → test → `cp` restore inside the same call,
per the brief's own trap-ordering warning. I used `tail -25` on each `dart
test` invocation instead of the brief's `run()` SURVIVED/KILLED wrapper, so
the transcripts below are the real failure text, not a boolean summary. All
four mutations produced actual failing named tests — none of the four
survived, and none was a false "every test failed to load" reading.

### T4a — allocate the boundary first (fill would paint over its outline)

Mutation applied: swapped the two `seed.next()` lines so `boundaryHandle` is
allocated before `fillHandle`.

```
=== T4a: allocate boundary before fill ===
347:    final boundaryHandle = seed.next();
348:    final fillHandle = seed.next();
00:00 +1 -2: the triangulation is materialised by the command, not by a draw [E]
  Bad state: a region's fill must carry the lower handle: got fill 13 against boundary 12
  package:jet_cad_2d/src/document/commands.dart 389:7  AddRegionCommand.apply
  package:jet_cad_2d/src/document/undo.dart 109:28     CommandDispatcher.execute
  test/document/region_command_test.dart 56:18         main.<fn>

00:00 +2 -4: undo removes both halves and redo restores the same handles [E]
  Bad state: a region's fill must carry the lower handle: got fill 13 against boundary 12
  ...

Failing tests:
  test/document/region_command_test.dart: the fill gets the lower handle, so it draws underneath
  test/document/region_command_test.dart: the fill names its boundary and the index links them
  test/document/region_command_test.dart: the triangulation is materialised by the command, not by a draw
  test/document/region_command_test.dart: undo removes both halves and redo restores the same handles
```

**KILLED** — 4 named tests failed, starting with "the fill gets the lower
handle, so it draws underneath" (the test directly named for this purpose).

### T4b — drop the ordering re-check (`if (fill.handle.value >= boundary.handle.value)` → `if (false)`)

```
=== T4b: drop ordering re-check ===
388:    if (false) {
00:00 +1 -1: apply refuses an inverted pair rather than drawing it wrong [E]
  Expected: throws <Instance of 'StateError'>
    Actual: <Closure: () => void>
     Which: returned <null>

  package:matcher                              expect
  test/document/region_command_test.dart 39:5  main.<fn>

Failing tests:
  test/document/region_command_test.dart: apply refuses an inverted pair rather than drawing it wrong
```

**KILLED** — the named test "apply refuses an inverted pair rather than
drawing it wrong" fails exactly as expected.

### T4c — don't populate triangles at command time (delete the `putTriangles` call)

```
=== T4c: don't populate triangles at command time ===
(putTriangles line absent from grep)
    Actual: <null>
     Which: has no length property
  a square is two triangles; the frame path reads and never computes

  package:matcher                              expect
  test/document/region_command_test.dart 57:5  main.<fn>

00:00 +4 -2: undo removes both halves and redo restores the same handles [E]
  Expected: an object with length of <6>
    Actual: <null>
     Which: has no length property

Failing tests:
  test/document/region_command_test.dart: the triangulation is materialised by the command, not by a draw
  test/document/region_command_test.dart: undo removes both halves and redo restores the same handles
```

**KILLED** — "the triangulation is materialised by the command, not by a
draw" (the test named for this purpose) and the undo/redo test both fail.

### T4d — accept a nearly-closed loop (delete the closedness check in `triangulationFor`)

```
=== T4d: accept a nearly-closed loop ===
closedness check removed
00:00 +4 -1: an unfillable boundary is refused before anything is written [E]
  Expected: throws <Instance of 'StateError'>
    Actual: <Closure: () => void>
     Which: returned <null>

  package:matcher                              expect
  test/document/region_command_test.dart 67:5  main.<fn>

Failing tests:
  test/document/region_command_test.dart: an unfillable boundary is refused before anything is written
```

**KILLED** — the open-boundary fixture (`test/document/region_command_test.dart`'s
"an unfillable boundary is refused before anything is written", built on the
non-closed `coords: [0,0, 10,0, 10,10]` payload) is exactly what catches this
mutation, as the brief predicted. Confirmed: this is a real kill, not a false
reading — the suite loaded and ran, and this one specific test failed with a
clear assertion mismatch (expected `throwsStateError`, got a normal return).

### Restore verification

```
=== restore check ===
IDENTICAL
```

`diff /tmp/t4.dart "$F"` after the final `cp` printed nothing and the script
echoed `IDENTICAL`; I additionally re-ran the region-command suite after the
whole mutation block finished and got all 6 green again, and `git status
--porcelain` showed only the two files intended for the commit (no
`analysis_options.yaml`, no leftover mutation).

```
$ cd packages/jet_cad_2d && CI=true dart test test/document/region_command_test.dart
...
00:00 +6: All tests passed!
```

## Concerns / things I was unsure about

- None of the brief's code disagreed with its own doc comments in any way I
  could exercise. `triangulationFor`'s null/empty split, the fill-first
  handle allocation, the exact-equality closedness check, and the
  boundary-before-fill removal order in `RemoveRegionCommand` all behaved as
  documented.
- The only deviation from the brief's literal Step 5 script is cosmetic: I
  used `tail -25` on each `dart test` call to capture the real failure text
  for this report, instead of the brief's `run()` helper that only echoes
  SURVIVED/KILLED. Both approaches ran the same mutate → test → restore
  sequence inside one shell call per the brief's trap-ordering requirement;
  mine additionally lets me show a reviewer the actual assertion output
  rather than a boolean, per the "never synthesize test output" / "read the
  failure text" instructions.
- `dart format` reformatted one line in `commands.dart` on first run (the
  `throw StateError` message concatenation line was one column too long)
  before settling; noted above so it's not mistaken for an unexplained diff.
