# Task 4 report: Joins — the run state machine and the seam

Branch `plan-b/joins-and-hairlines`, base `5d5ba07`.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart`
- `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart`
- `packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart`

```
 .../lib/src/gpu/geometry_collector.dart            | 121 ++++++++++--
 .../test/gpu/collector_differential_test.dart      | 203 +++++++++++++++------
 .../test/gpu/geometry_collector_test.dart          | 157 +++++++++++++++-
 3 files changed, 411 insertions(+), 70 deletions(-)
```

---

## TDD evidence

### Failing run, before implementation (Step 2)

Command: `cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart`

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +1: emits one instance per segment, in walk order
00:00 +2: closed: true emits a closing segment back to the first point
00:00 +3: drops a zero-length segment rather than handing the shader a NaN
00:00 +4: counts the ops Plan A does not draw instead of dropping them silently
00:00 +5: clamps to the device-pixel floor at a hairline lineweight
00:00 +6: lineweightScale multiplies the logical width before the clamp
00:00 +7: a sub-pixel stroke keeps its pixel and gives up alpha
00:00 +8: a stroke at or above one device pixel keeps full alpha
00:00 +9: a zero lineweight is the hairline case and keeps full alpha
00:00 +10: an open three-point run is join-before-segment, and nothing else
00:00 +10 -1: an open three-point run is join-before-segment, and nothing else [E]
  Expected: <3>
    Actual: <2>
  segment, join, segment -- no caps, no trailing join

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 242:5         main.<fn>

00:00 +10 -1: the join carries the corner and both its neighbours
00:00 +10 -2: the join carries the corner and both its neighbours [E]
  Expected: <0>
    Actual: <40.0>
  the previous point

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 264:5         main.<fn>

00:00 +10 -2: a closed run emits the closing segment and then the seam join
00:00 +10 -3: a closed run emits the closing segment and then the seam join [E]
  Expected: <6>
    Actual: <3>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 285:5         main.<fn>

00:00 +10 -3: a repeated point is spanned by the join, not turned into one
00:00 +10 -4: a repeated point is spanned by the join, not turned into one [E]
  Expected: <3>
    Actual: <2>
  the repeat adds no instance

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 325:5         main.<fn>

00:00 +10 -4: a two-point run has no join at all
00:00 +11 -4: Some tests failed.

Failing tests:
  .../geometry_collector_test.dart: a closed run emits the closing segment and then the seam join
  .../geometry_collector_test.dart: a repeated point is spanned by the join, not turned into one
  .../geometry_collector_test.dart: an open three-point run is join-before-segment, and nothing else
  .../geometry_collector_test.dart: the join carries the corner and both its neighbours
exit=1
```

Four of the five new tests failed on instance counts exactly as the brief predicted (3/3/6/3 → 2/2/3/2); the fifth ("a two-point run has no join at all") already passed because a two-point run was already a single stroke before this task. All five pre-existing tests still passed at this point.

### Passing run, after implementation (Step 4)

Command: same.

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +1: emits one instance per segment, in walk order
00:00 +1 -1: emits one instance per segment, in walk order [E]
  Expected: <2>
    Actual: <3>
...
00:00 +1 -2: closed: true emits a closing segment back to the first point [E]
  Expected: <3>
    Actual: <6>
...
00:00 +13 -2: Some tests failed.
```

This first pass after implementing the run state machine turned up two *pre-existing* tests in the same file — "emits one instance per segment, in walk order" and "closed: true emits a closing segment back to the first point" — that the brief's Step 1 snippet did not anticipate: both drive a 3-point polyline, which now legitimately emits an interior join, shifting every later instance's buffer index. These are not among the brief's five new tests; they predate this task and their raw-index assertions (`c.data.sublist(kFloatsPerInstance + 1, ...)`) silently pointed at the wrong instance once a join is interleaved. I fixed both **by extending them to account for the join** (asserting the join's `kind` explicitly and reading the shifted stroke indices), not by weakening any check — see "Two pre-existing tests fixed" below for the exact diffs.

After that fix, the full run:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +1: emits one instance per segment, in walk order
00:00 +2: closed: true emits a closing segment back to the first point
00:00 +3: drops a zero-length segment rather than handing the shader a NaN
00:00 +4: counts the ops Plan A does not draw instead of dropping them silently
00:00 +5: clamps to the device-pixel floor at a hairline lineweight
00:00 +6: lineweightScale multiplies the logical width before the clamp
00:00 +7: a sub-pixel stroke keeps its pixel and gives up alpha
00:00 +8: a stroke at or above one device pixel keeps full alpha
00:00 +9: a zero lineweight is the hairline case and keeps full alpha
00:00 +10: an open three-point run is join-before-segment, and nothing else
00:00 +11: the join carries the corner and both its neighbours
00:00 +12: a closed run emits the closing segment and then the seam join
00:00 +13: a repeated point is spanned by the join, not turned into one
00:00 +14: a two-point run has no join at all
00:00 +15: All tests passed!
exit=0
```

---

## Mutation transcripts (Step 5)

Backup taken first:

```
$ cp lib/src/gpu/geometry_collector.dart <scratchpad>/gc.bak
$ md5 lib/src/gpu/geometry_collector.dart <scratchpad>/gc.bak
MD5 (lib/src/gpu/geometry_collector.dart) = b506a918bbc9255fe6d721c59457cfbf
MD5 (<scratchpad>/gc.bak) = b506a918bbc9255fe6d721c59457cfbf
```

### M-B2 — emit the join AFTER its segment (swap the two statements in `_runTo`)

Exact edit applied to `_runTo`:

```diff
-    if (_runHasDirection) {
-      _emitJoin(_runPrevX, _runPrevY, _runBackX, _runBackY, x, y, half, argb);
-    } else {
-      _runSecondX = x;
-      _runSecondY = y;
-    }
-    _emit(_runPrevX, _runPrevY, x, y, half, argb);
+    if (!_runHasDirection) {
+      _runSecondX = x;
+      _runSecondY = y;
+    }
+    _emit(_runPrevX, _runPrevY, x, y, half, argb);
+    if (_runHasDirection) {
+      _emitJoin(_runPrevX, _runPrevY, _runBackX, _runBackY, x, y, half, argb);
+    }
```

Command: `flutter test test/gpu/geometry_collector_test.dart`

Verbatim failure (relevant excerpts; six tests went red, all on kind-sequence / ordering):

```
00:00 +1: emits one instance per segment, in walk order
00:00 +1 -1: emits one instance per segment, in walk order [E]
  Expected: <1.0>
    Actual: <0.0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 72:5          main.<fn>

00:00 +1 -1: closed: true emits a closing segment back to the first point
00:00 +1 -2: closed: true emits a closing segment back to the first point [E]
  Expected: [1.0, 0.0, 1.0, 1.0]
    Actual: [1.0, 0.0, 0.0, 0.0]
     Which: at location [2] is <0.0> instead of <1.0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 101:5         main.<fn>

00:00 +8 -3: an open three-point run is join-before-segment, and nothing else [E]
  Expected: [0.0, 1.0, 0.0]
    Actual: [0.0, 0.0, 1.0]
     Which: at location [1] is <0.0> instead of <1.0>
  the join is written BEFORE the segment that follows it

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 259:5         main.<fn>

00:00 +8 -4: the join carries the corner and both its neighbours [E]
  Expected: <0>
    Actual: <40.0>
  the previous point
  ...
00:00 +11 -2: a closed run emits the closing segment and then the seam join [E]
  Expected: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    Actual: [0.0, 0.0, 1.0, 0.0, 1.0, 1.0]
     Which: at location [1] is <0.0> instead of <1.0>
  ...
00:00 +11 -6: a repeated point is spanned by the join, not turned into one [E]
  Expected: <0>
    Actual: <40.0>
  the incoming neighbour is still the first point

Failing tests:
  .../geometry_collector_test.dart: a closed run emits the closing segment and then the seam join
  .../geometry_collector_test.dart: a repeated point is spanned by the join, not turned into one
  .../geometry_collector_test.dart: an open three-point run is join-before-segment, and nothing else
  .../geometry_collector_test.dart: closed: true emits a closing segment back to the first point
  ... and 2 more
exit=1
```

Restore, and proof it came from the backup and not `git checkout --`:

```
$ cp <scratchpad>/gc.bak lib/src/gpu/geometry_collector.dart
$ git diff --stat lib/src/gpu/geometry_collector.dart
 .../lib/src/gpu/geometry_collector.dart            | 120 ++++++++++++++++++---
 1 file changed, 107 insertions(+), 13 deletions(-)
```

That diff stat is exactly this task's own change against `5d5ba07` (the base) — proof the mutation is gone and the file is back to the Task 4 implementation, not the pre-task base and not some other state. Re-ran the suite to confirm: `flutter test test/gpu/geometry_collector_test.dart` → `+15: All tests passed!`.

### M-B3 — skip the seam join (delete the `if (_runSegments >= 2)` block)

**Note on the brief's instruction and a first wrong mutation.** "Delete the `if (_runSegments >= 2)` block" is ambiguous between deleting only the guard (leaving the join call unconditional) and deleting the whole `if { … }` statement, guard and body together, which is what "skip the seam join" actually requires. I first tried the former:

```diff
-    // Guarded for the same reason the reference guards it: today's callers
-    // cannot reach here with one segment, but that is a fact about the
-    // callers, not a promise the join arithmetic makes.
-    if (_runSegments >= 2) {
-      _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
-          _runSecondY, half, argb);
-    }
+    _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
+        _runSecondY, half, argb);
```

This left the suite **green** (`+15: All tests passed!`) — no fixture in this suite reaches `_endRun` with fewer than 2 segments, so unguarding the call changes nothing observable and this is not the mutation the brief intends ("skip the seam join" — the join must stop being emitted, not become unconditional). Restored from the backup and applied the correct mutation instead: delete the guard **and** its body, so the seam join is never emitted on a closed run.

Exact edit applied to `_endRun`:

```diff
     _runTo(_runFirstX, _runFirstY, half, argb);
-    // Guarded for the same reason the reference guards it: today's callers
-    // cannot reach here with one segment, but that is a fact about the
-    // callers, not a promise the join arithmetic makes.
-    if (_runSegments >= 2) {
-      _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
-          _runSecondY, half, argb);
-    }
   }
```

Command: `flutter test test/gpu/geometry_collector_test.dart`

Verbatim failure:

```
00:00 +2: closed: true emits a closing segment back to the first point
00:00 +2 -1: closed: true emits a closing segment back to the first point [E]
  Expected: <6>
    Actual: <5>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 99:5          main.<fn>

00:00 +11 -1: a closed run emits the closing segment and then the seam join
00:00 +11 -2: a closed run emits the closing segment and then the seam join [E]
  Expected: <6>
    Actual: <5>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 300:5         main.<fn>

Failing tests:
  .../geometry_collector_test.dart: a closed run emits the closing segment and then the seam join
  .../geometry_collector_test.dart: closed: true emits a closing segment back to the first point
exit=1
```

Both closed-run tests go red on the count (6 expected, 5 actual — the seam join is missing), exactly as the brief predicted.

Restore, and proof it came from the backup:

```
$ cp <scratchpad>/gc.bak lib/src/gpu/geometry_collector.dart
$ git diff --stat lib/src/gpu/geometry_collector.dart
 .../lib/src/gpu/geometry_collector.dart            | 120 ++++++++++++++++++---
 1 file changed, 107 insertions(+), 13 deletions(-)
$ flutter test test/gpu/geometry_collector_test.dart
...
00:00 +15: All tests passed!
```

Same diff-stat signature as the M-B2 restore — the file is back to exactly the Task 4 implementation.

---

## Two pre-existing tests fixed (not among the brief's five, not among Ruling B5's scope)

`geometry_collector_test.dart`'s "emits one instance per segment, in walk order" and "closed: true emits a closing segment back to the first point" both drive a 3-point polyline and read raw `data.sublist` offsets that assumed a segment-only buffer. Once joins land, both went red on the pre-existing count assertion (2→3, 3→6). Both were fixed by reading the strokes' shifted indices (0/2 for the open case; 0/2/4 for the closed case) — the same coordinate facts each test checked before, at the corrected offsets. Only the first of the two ("emits one instance per segment, in walk order") also gained explicit `kind` assertions on all three instances; the second ("closed: true...") gained no `kind` assertion, only the corrected stroke indices. Neither lost any check it had before — no assertion was removed or loosened — but my original wording overstated this uniformly to both tests, which was wrong; corrected here (Fix round 1, Minor 3).

---

## `collector_differential_test.dart` changes (Ruling B5)

The oracle's rebuild loop was replaced with `_mirrorPolylineRun`, a second, independent implementation of `GeometryCollector`'s run state machine (`_beginRun`/`_runTo`/`_endRun`), applied per `PolylineOp` after its residual, appending an `_ExpectedInstance` (stroke or join) in the same order the collector emits them. Per-assertion classification:

1. **`expect(expected/expectedPoints, isNotEmpty, ...)`** — unchanged in nature. Was correct before (guards against a vacuous fixture); still correct, now over the join-aware list.

2. **`expect(collector.instanceCount, expected.length, ...)`** — was correct before this task (segment-for-segment), and is the assertion Ruling B5 exists to fix: without extending the oracle to emit joins itself, this line would have gone red the moment the collector started emitting them (14 actual vs. 10 expected on `differentialFixture`, verified below). **Was correct before, now correctly extended** — not weakened, not deleted; the fix was to make the left-hand *and* right-hand side both reflect the true run state machine.

3. **`expect(data[o + InstanceFieldOffset.kind], kKindStroke, ...)` → `expect(data[o + InstanceFieldOffset.kind], e.kind, ...)`** — **was vacuous**. Every instance this test could previously see was a stroke (the collector only wrote strokes), so this assertion always compared against the one value it could ever be — no defect that mislabeled an instance's kind was reachable. This is exactly the gap Plan A's ledger names: "would pass on a genuinely unwritten slot and cannot catch a wrong-kind-among-several defect." With `e.kind` now `kKindJoin` for interior/seam joins and `kKindStroke` for segments, this assertion discriminates for the first time — a collector that wrote every join as a stroke (or vice versa) now fails here.

4. **`x0`/`y0`/`x1`/`y1` position checks** — were correct before (checked the real segment endpoints against the walk); remain correct, now checked against `e.x0..e.y1`, which for a stroke is still `(start, end)` and for a join is `(vertex, previous point)`.

5. **`x2`/`y2` checks — new.** These slots existed in the record (`kFloatsPerInstance = 12` since Task 2) but this test never read them, because a stroke always writes `(0, 0)` there and nothing before this task wrote anything else. They are added now and asserted for *every* instance, strokes included (against the stroke's own `(0, 0)`) — this is the concrete fix for "cannot catch a wrong-kind-among-several defect": a join emitted where a stroke was expected now fails on `x2`/`y2` even in a hypothetical where its `kind` byte were accidentally correct, and vice versa.

6. **`halfWidth` check** — unchanged in logic and correctness; still correct, and now covers joins too (a join carries the same half-width as its neighbouring segments, which `_mirrorPolylineRun`'s `emitJoin` closure threads through unchanged).

7. **colour (`r`/`g`/`b`/`a`) checks** — unchanged in logic and correctness; still correct, now covers joins too, via `e.style`.

No assertion was weakened, loosened, or removed to make the suite pass. Verified the fixture is genuinely exercising joins (not vacuously equal by coincidence) with a standalone debug run: `differentialFixture()` painted through `GeometryCollector` produces **`instanceCount=14`** (10 strokes + 4 interior joins — the two placements of the "outer" definition's 4-point polyline each contribute 2 interior joins), which is exactly what `expected.length` computes and what the oracle asserted equal.

```
00:00 +0: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
00:00 +1: All tests passed!
exit=0
```

---

## Full gate output (Step 6)

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:06 +454: All tests passed!
exit=0
```
(454 passed, 1 pre-existing skip unrelated to this task — `~1` markers throughout the run predate this branch.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
exit=0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 85 files (0 changed) in 0.15 seconds.
exit=0
```

(The first `dart format` run after implementation reported 3 files changed — `geometry_collector.dart`, `collector_differential_test.dart`, `geometry_collector_test.dart` — mechanical line-wrapping from the brief's sample signatures exceeding this project's line length; `dart format` was applied and the check above is the post-format, clean run.)

`git status --porcelain` after the full gate shows only the three intended files modified — no `analysis_options.yaml` appeared:

```
 M packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart
 M packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart
 M packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
```

---

## Defects found in the brief's sample code

1. **The brief's Step 1 test snippets do not compile.** All five new tests construct `const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25)`, but `ResolvedStyle`'s constructor (`packages/jet_cad_2d/lib/src/document/resolved_style.dart:8-13`) requires `linetype` and `linetypeScale` as well — every other `ResolvedStyle` literal in this file (and the project) already supplies them. The analyzer reported this as an error (`The named parameter 'linetype' is required, but there's no corresponding argument`) on all five occurrences before any test could run. Fixed by adding `linetype: Handle.none, linetypeScale: 1` to each of the five literals.

2. **The brief's Step 1 snippet, taken alone, breaks two pre-existing tests it does not mention.** "emits one instance per segment, in walk order" and "closed: true emits a closing segment back to the first point" (both already in the file, both predating this task) drive a 3-point polyline and assert raw buffer offsets that assumed segment-only output. Neither is in the brief's diff, and the brief's Step 4 ("Expected: all pass") does not flag them, but they went red the moment the run state machine landed. Documented and fixed above ("Two pre-existing tests fixed").

3. **The M-B3 instruction is ambiguous and, read one way, produces a false-negative mutation.** "delete the `if (_runSegments >= 2)` block" was first read as "delete the guard, keep the call" (unguard it), which left the join call unconditional — and the suite stayed green, because no fixture here reaches `_endRun` with fewer than two segments. That is not "skip the seam join," which is what the step's own summary says the mutation should do. The correct reading — confirmed by re-running and getting the expected red — is to delete the entire `if { … }` statement, guard and body, so the seam join is never emitted. Both attempts and the correct one are transcribed above under M-B3.

4. **Ruling B5's own required fix, not the sample code, but confirming it was necessary rather than assumed:** without extending `collector_differential_test.dart`'s oracle, the differential test would have gone red the moment Task 4's `polyline` started emitting joins (verified: the fixture's true instance count is 14, not the pre-Task-4 oracle's 10). This report treats that as done work (Ruling B5), not a leftover concern.

No other defects found in the brief's Step 3 sample beyond routine `dart format` line-wrapping (see gate output above), which is not a correctness issue.

---

## Fix round 1

FIX_BASE `7296ad2`. `geometry_collector.dart`'s logic is untouched this round, as directed — the file only got mutated and restored (twice, transcribed below) for evidence, never committed with a mutation in it. Both directives from the review are noted and require no action: the M-B3 guard-only arm is an equivalent mutation (proof: `_runHasDirection` implies the run's opening step accepted a non-zero displacement; reaching `_endRun`'s guard with `_runSegments == 1` requires the closing step to skip, i.e. the closing displacement is the exact negation of the opening one, and `sqrt(dx*dx+dy*dy)` is even in that negation — so if the closing step's length is zero the opening step's was too, contradicting `_runHasDirection`; no input can separate the guarded and unguarded arms), and emission order / the repeated-vertex skip are confirmed correct and left untouched.

### The rewritten oracle, and why it has no bookkeeping

The previous oracle (`_mirrorPolylineRun`) was a second implementation of `GeometryCollector`'s own `_beginRun`/`_runTo`/`_endRun` state machine: same private-field names minus the leading underscore, same statement order, the same `sqrt(dx*dx+dy*dy) == 0` guard copied verbatim into two closures (`emitSeg`/`runTo`). It never called into the code under test, so it was not circular in the strict sense, but it was a transcription of it — close enough that a misreading of the reference baked into the collector's state machine (an off-by-one in when `_runBack` updates, a wrong operand order in `_emitJoin`'s arguments) had a good chance of being baked into the oracle's replica the same way, in the same sitting, by the same author. Two implementations that agree because they are the same implementation twice prove nothing.

The rewrite, `_expectedInstancesFor`, has no run state at all — no field threads a "previous point" or "has direction" flag from one loop iteration to the next. It:

1. Transforms every raw point by the residual (unchanged from before).
2. Dedupes consecutive points against the previous *kept* point, using `_coincide` — the reference's own zero-length predicate, `math.sqrt(dx*dx + dy*dy) == 0` — and, for a closed run only, drops a trailing point that coincides with the first.
3. Reads the expected instance list declaratively off the deduped array `p[0..n-1]` by index: a stroke `(p[i], p[i+1])` for every `i` in `0..n-2`; a join at `p[i]` carrying `(p[i-1], p[i+1])` for every interior `i` in `1..n-2`, interleaved `S₀, J₁, S₁, J₂, S₂, …`; and, closed with `n >= 3`, one more join at `p[n-1]` carrying `(p[n-2], p[0])`, the closing stroke `(p[n-1], p[0])`, and the seam join at `p[0]` carrying `(p[n-1], p[1])`.

**A correction to the review's own step 3, found by running it.** The review's literal formula for the closed case was "the closing stroke `(p[n-1], p[0])`, then the seam join at `p[0]`" — no join at `p[n-1]` before the closing stroke. Implemented literally, that produces only **one** interior join plus the seam for a closed triangle (`n = 3`: the base loop's `1..n-2` range is `1..1`, contributing exactly `J₁`). But the already-passing, already-verified Task 4 test `geometry_collector_test.dart`'s "a closed run emits the closing segment and then the seam join" pins **six** instances for exactly that shape — `kKindStroke, kKindJoin, kKindStroke, kKindJoin, kKindStroke, kKindJoin` — three joins, not two, with its own comment reading "a join at vertices 1 *and* 2, then the seam join at vertex 0". A hand-trace of the real `_endRun` confirms why: its closing step is `_runTo(_runFirstX, _runFirstY, ...)`, an ordinary call to the same function that writes a join before every segment it draws — the last point is not exempted from that rule merely because the segment it precedes happens to be the closing one. So the closing stroke has its own ordinary leading join, exactly like every other stroke, and the seam join is a *fourth*, additional corner on top of that (the one no point in the raw list names on its own). I implemented the corrected three-part closed case (ordinary join at `p[n-1]`, closing stroke, seam join) rather than the review's literal two-part one, and verified it reproduces the real collector's output exactly for both the plain 3-point closed triangle and the M-B11 4-point (redundant-trailing-point) shape — both hand-traced against the actual `_beginRun`/`_runTo`/`_endRun` code and matching to the coordinate.

This satisfies the "no bookkeeping" requirement in the strongest sense available: the formula is read from array indices, not carried in mutable state across a loop, and it is now also independently verified to reproduce the reference's real behaviour rather than trusted on the review's word alone.

### M-B2 fired against `collector_differential_test.dart` specifically

Backup and mutation (identical edit to Fix round 0's M-B2 — swap the join and segment statements in `_runTo`):

```
$ cp lib/src/gpu/geometry_collector.dart <scratchpad>/gc_fixround1.bak
$ md5 lib/src/gpu/geometry_collector.dart <scratchpad>/gc_fixround1.bak
MD5 (lib/src/gpu/geometry_collector.dart) = a5a280beb1254b314f79320279fd9c4a
MD5 (<scratchpad>/gc_fixround1.bak) = a5a280beb1254b314f79320279fd9c4a
```

```diff
-    if (_runHasDirection) {
-      _emitJoin(_runPrevX, _runPrevY, _runBackX, _runBackY, x, y, half, argb);
-    } else {
-      _runSecondX = x;
-      _runSecondY = y;
-    }
-    _emit(_runPrevX, _runPrevY, x, y, half, argb);
+    if (!_runHasDirection) {
+      _runSecondX = x;
+      _runSecondY = y;
+    }
+    _emit(_runPrevX, _runPrevY, x, y, half, argb);
+    if (_runHasDirection) {
+      _emitJoin(_runPrevX, _runPrevY, _runBackX, _runBackY, x, y, half, argb);
+    }
```

Command: `flutter test test/gpu/collector_differential_test.dart`

Verbatim failure:

```
00:00 +0: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
00:00 +0 -1: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr [E]
  Expected: <1.0>
    Actual: <0.0>
  instance 4 must be a join

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/collector_differential_test.dart 131:7     main.<fn>

00:00 +0 -1: Some tests failed.

Failing tests:
  .../collector_differential_test.dart: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
exit=1
```

**The differential test itself — not just `geometry_collector_test.dart` — catches this mutation.** The declarative oracle is not circular: it flags the exact instance (4) whose kind flips under the reorder, on the real `differentialFixture()` walk, using an expected list built with no reference to the collector's internal state machine.

Restore, and proof it came from the backup:

```
$ cp <scratchpad>/gc_fixround1.bak lib/src/gpu/geometry_collector.dart
$ git diff --stat lib/src/gpu/geometry_collector.dart
(no output -- the file matches HEAD exactly)
$ md5 lib/src/gpu/geometry_collector.dart
MD5 (lib/src/gpu/geometry_collector.dart) = a5a280beb1254b314f79320279fd9c4a
$ flutter test test/gpu/collector_differential_test.dart
...
00:00 +1: All tests passed!
```

The empty `git diff --stat` against `HEAD` (`7296ad2`) and the matching md5 (identical to the pre-mutation backup's own md5) both confirm the restore, not a `git checkout --`.

### M-B11 — the named defect in `_endRun`'s seam

Added to `geometry_collector_test.dart`: `'a closed run whose last point already repeats the first still finds the last DISTINCT point for the seam'`, driving `polyline([0,0, 60,0, 30,50, 0,0], 4, style, closed: true)` and asserting `instanceCount == 6` plus the seam instance's (`x1`, `y1`) `== (30, 50)` — the last point distinct from the first, not `(0, 0)`.

Ran first against the correct implementation, to confirm the test is meaningful before mutating anything:

```
$ flutter test test/gpu/geometry_collector_test.dart
...
00:00 +15: a closed run whose last point already repeats the first still finds the last DISTINCT point for the seam
00:00 +16: All tests passed!
```

Backup:

```
$ cp lib/src/gpu/geometry_collector.dart <scratchpad>/gc_mb11.bak
$ md5 lib/src/gpu/geometry_collector.dart <scratchpad>/gc_mb11.bak
MD5 (lib/src/gpu/geometry_collector.dart) = a5a280beb1254b314f79320279fd9c4a
MD5 (<scratchpad>/gc_mb11.bak) = a5a280beb1254b314f79320279fd9c4a
```

Exact edit applied to `_endRun` (the review's own named mutation — capture the seam's incoming neighbour *before* the closing `_runTo` step instead of reading `_runBack` after it):

```diff
   void _endRun(
       {required bool closed, required double half, required int argb}) {
     if (!closed || !_runHasDirection) return;
+    final inX = _runPrevX, inY = _runPrevY; // captured BEFORE the closing step
     _runTo(_runFirstX, _runFirstY, half, argb);
     // Guarded for the same reason the reference guards it: today's callers
     // cannot reach here with one segment, but that is a fact about the
     // callers, not a promise the join arithmetic makes.
     if (_runSegments >= 2) {
-      _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
-          _runSecondY, half, argb);
+      _emitJoin(_runFirstX, _runFirstY, inX, inY, _runSecondX, _runSecondY,
+          half, argb);
     }
   }
```

Command: `flutter test test/gpu/geometry_collector_test.dart`

Verbatim failure:

```
00:00 +14: a two-point run has no join at all
00:00 +15: a closed run whose last point already repeats the first still finds the last DISTINCT point for the seam
00:00 +15 -1: a closed run whose last point already repeats the first still finds the last DISTINCT point for the seam [E]
  Expected: <30>
    Actual: <0.0>
  incoming from the last DISTINCT point, not the repeat

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 403:5         main.<fn>

00:00 +15 -1: Some tests failed.

Failing tests:
  .../geometry_collector_test.dart: a closed run whose last point already repeats the first still finds the last DISTINCT point for the seam
exit=1
```

Exactly the predicted defect: the seam's incoming neighbour reads as `(0.0, …)` — the vertex itself — instead of `(30, 50)`, the last point distinct from the first. `_runTo`'s zero-length guard (the closing step is a no-op when the raw list's last point already equals the first) means `_runBack` is never touched by that call, so reading it *after* the call correctly leaves it at the last real point; reading `_runPrev` *before* the call reads the vertex, which the closing step was about to skip past.

Restore, and proof:

```
$ cp <scratchpad>/gc_mb11.bak lib/src/gpu/geometry_collector.dart
$ git diff --stat lib/src/gpu/geometry_collector.dart
(no output -- the file matches HEAD exactly)
$ md5 lib/src/gpu/geometry_collector.dart
MD5 (lib/src/gpu/geometry_collector.dart) = a5a280beb1254b314f79320279fd9c4a
$ flutter test test/gpu/geometry_collector_test.dart
...
00:00 +16: All tests passed!
```

### Full gate output (Fix round 1)

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:06 +455: All tests passed!
exit=0
```
(455 passed — one more than Fix round 0's 454, the new M-B11 test — with the same single pre-existing, unrelated skip.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
exit=0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 85 files (0 changed) in 0.15 seconds.
exit=0
```

(The oracle rewrite's first `dart format` pass reported `Changed test/gpu/collector_differential_test.dart` — mechanical wrapping from the new declarative function's longer lines; applied, and the run above is the clean, post-format check.)

`git status --porcelain` before committing — only the two test files, `geometry_collector.dart` untouched as directed, no `analysis_options.yaml`:

```
 M packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart
 M packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
```
