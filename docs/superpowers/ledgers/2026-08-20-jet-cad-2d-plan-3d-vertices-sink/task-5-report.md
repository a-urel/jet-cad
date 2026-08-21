# Task 5 report: the seam — closed runs join instead of capping

## What was implemented

`_endRun` (`packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`) now
closes a closed run instead of asserting: it draws the closing segment back to
the run's first point (`_runTo`) and then, guarded by `_runSegments >= 2`,
emits the seam join between the closing segment's direction and the first
segment's direction.

`_flatten` now stops one sample short (`steps - 1`) when `closed`, so the loop
never draws the chord back to the start point itself — `_endRun` draws it, and
the join lands where the two chords actually meet instead of on a duplicated
point. `circle()` already called `_flatten(..., closed: true)`; that call is
now genuinely closed instead of documented-but-inert, and the
`assert(!closed || (sweep - 2 * math.pi).abs() < 1e-9)` that stood in for the
missing branch is gone.

`polyline`'s `closed:` forwarding to `_endRun` is now load-bearing rather than
reachable-only-by-a-test-that-expects-an-assert.

Two stale doc comments in the class header and around `_runFirst*`/`_runSegments`
that described the fields as Task-5-not-landed-yet were rewritten to describe
what they're for now.

## TDD evidence

### RED (Step 2)

Ran `flutter test test/vertices_join_test.dart` after adding the four new
tests from the brief, before touching `vertices_draw_sink.dart`:

```
00:00 +10 -1: a circle joins at its seam, so there is no notch at the start angle [E]
  Expected: true
    Actual: <false>
  test/vertices_join_test.dart 239:5   main.<fn>

00:00 +10 -2: the seam is one join, not two, and not a cap [E]
  'package:jet_cad_2d_flutter/src/vertices_draw_sink.dart': Failed assertion: line 342 pos 12: '!closed': closed runs arrive in Task 5
  package:jet_cad_2d_flutter/src/vertices_draw_sink.dart 342:12  VerticesDrawSink._endRun
  package:jet_cad_2d_flutter/src/vertices_draw_sink.dart 285:5   VerticesDrawSink.polyline
  test/vertices_join_test.dart 247:9   main.<fn>

00:00 +10 -3: an open run of the same points has three corners, not four [E]
  Expected: <12>
    Actual: <10>

00:00 +10 -4: a closed run of two points closes without a phantom seam [E]
  'package:jet_cad_2d_flutter/src/vertices_draw_sink.dart': Failed assertion: line 342 pos 12: '!closed': closed runs arrive in Task 5
```

Exactly as predicted by the brief: the circle row failed the `_inked`
assertion, the two `closed: true` rows tripped Task 4's assert. (The
"three corners, not four" failure at this point is the pre-existing
open-run behaviour, unaffected by Task 5 — see the discrepancy section below.)

### GREEN (Steps 3–6)

After implementing `_endRun`'s closed branch and `_flatten`'s
stop-one-short change:

```
$ flutter test test/vertices_join_test.dart test/vertices_draw_sink_test.dart
...
00:00 +42: All tests passed!
```

14 tests in `vertices_join_test.dart` (13 named join tests + the miter-constant
test), 28 in `vertices_draw_sink_test.dart`. All green.

## A discrepancy in the brief's own numbers, found and fixed

The brief's Step 1 text specifies, verbatim:

```dart
test('an open run of the same points has three corners, not four', () {
  ...
  expect(_triangleCount(sink), 6 + 6);
});
```

Implementing exactly what Step 3/4 specify and running this test against it
gives `Actual: <10>`, not 12. I traced it by hand and confirmed empirically:
a 4-point open run (`[p0, p1, p2, p3]`, `closed: false`) is 3 segments (6
triangles) with a join only at the two *interior* vertices p1 and p2 (4
triangles) — `_runTo`'s join fires on every call after the first, and an open
run never calls `_runTo` a fourth time to reach p3, let alone folds back to
p0. That's 2 corners, not 3; 10 triangles, not 12. The closed row (16, which
the brief gets right) adds exactly one quad (the p3→p0 segment) plus two new
joins: the one at p3 that only exists because the run keeps going past it now
that it's closed, and the explicit seam join at p0. 10 + 6 = 16, which matches
both rows.

I fixed the test's title, comment, and expected value (`6 + 6` → `6 + 4`,
"three corners" → "two corners") to match reality rather than land a false
assertion. This is the same class of error the task brief warned about for
`// MUTATION:` comments, just landed as a wrong expected count instead of a
wrong comment — I'm flagging it explicitly per "actually run it and check."

## The `_runSegments >= 2` guard: also checked, also found wrong as stated

The brief's test for the two-point closed run carries:

```
// MUTATION: drop the `_runSegments >= 2` guard and this throws or emits a
// triangle at a NaN.
```

I ran this mutation (removed the guard entirely) and the *entire* join suite
stayed green — including this exact test. I traced why: `_runHasDirection`
being true (checked just above) already guarantees at least one real segment
before the guard is reached, and the closing `_runTo` call either adds a
second (incrementing `_runSegments` to ≥2) or is itself a zero-length no-op —
which is only possible if the run's last point already sits exactly on its
first point, which in turn is only possible if the original path already had
≥2 segments to get there without ever taking a zero-length step itself (a
zero-length first step would have left `_runHasDirection` false). Either way,
`_runSegments` is provably ≥2 whenever the guard runs. I confirmed this both
by hand and empirically (mutation transcript below).

I did **not** delete the guard — it's harmless, cheap, and documents a real
invariant about today's callers even though it's not currently reachable-false
— but I rewrote both the code comment and the test's `// MUTATION:` comment to
say so honestly, and replaced the false mutation claim with the mutation I
actually verified goes red (see Mutation 2 below): disabling all three of
`_emitJoin`'s own bails (`cross == 0`, `dot < kMinMiterCosine`, `mlen == 0`)
together — which are Task 4 code, reused unchanged here — is what actually
protects this exact reversal fixture from a NaN.

## `_inked`'s zero-area blind spot: fixtures checked, not hardened

I did not harden `_inked` against zero-area triangles. Instead I verified by
direct instrumentation that none of this task's fixtures ever hand it one:

```
circle seam: 116 triangles, min area = 0.005084780736069661
closed square: 16 triangles, min area = 2.0
two-point closed (reversal): 4 triangles, min area = 60.0
```

- The circle seam's smallest triangle has a small but strictly positive area
  (a shallow-angle join tip on a fine chord), never zero.
- The closed square is all right-angle miters, comfortably non-degenerate.
- The one fixture that *would* produce a degenerate (zero-area) join if
  `_emitJoin`'s bails were bypassed — the two-point closed reversal — never
  reaches `_inked` at all: its test (`a closed run of two points closes
  without a phantom seam`) checks `debugPositions().isFinite` directly, and
  the reversal's join is skipped entirely by `_emitJoin`'s `cross == 0` bail
  (0 triangles emitted for that join, confirmed above: 4 triangles total = 2
  quads only, 0 join triangles).

So the only fixture in this task shaped like the risk the review flagged
deliberately avoids `_inked`, and every fixture that does use `_inked` stays
comfortably non-degenerate. I judged hardening `_inked` itself out of scope —
it's shared file-level infrastructure this task didn't need to touch to stay
correct, and touching it without a driving test would be scope creep.

## The replaced assert test: before and after

Before (in `vertices_draw_sink_test.dart`):

```dart
test('a closed polyline hits the unimplemented closed branch, loudly', () {
  final sink = _sink()..beginResidual(Transform2.identity());
  expect(
      () => sink.polyline(
          Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, _style(),
          closed: true),
      throwsA(isA<AssertionError>()));
});
```

It asserted that calling `polyline(..., closed: true)` threw an
`AssertionError` — pinning the placeholder's `assert(!closed, ...)` as the
expected behaviour.

After:

```dart
test('a closed polyline draws its closing segment and seam join', () {
  final closed = _sink()
    ..beginResidual(Transform2.identity())
    ..polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, _style(),
        closed: true)
    ..endResidual();
  // Three segments and three corners: 3 * 2 quad triangles plus 3 * 2 join
  // triangles, every corner shallow enough to mitre.
  expect(closed.debugPositions().length, (3 * 2 + 3 * 2) * 3 * 2);
});
```

It now asserts the real closing geometry: 3 segments (the two original plus
the closing one) each contributing a quad, and 3 corners (2 interior + 1 seam)
each contributing a full miter, for `(6 + 6) * 6 = 72` floats.

## Mutations run, with real transcripts

Two mutations run for real (backed up with `cp`, mutated, ran, watched red,
restored with `cp`, confirmed clean with `git status --porcelain` and
`git diff --stat`, reran green):

### Mutation 1 — drop the explicit seam join in `_endRun`

Changed `if (_runSegments >= 2) {` to `if (false && _runSegments >= 2) {`.

```
00:00 +10 -1: a circle joins at its seam, so there is no notch at the start angle [E]
  Expected: true
    Actual: <false>

00:00 +10 -2: the seam is one join, not two, and not a cap [E]
  Expected: <16>
    Actual: <14>
```

Both targeted tests died, matching their `// MUTATION:` comments exactly.
Restored via `cp /tmp/vertices_draw_sink.dart.bak lib/src/vertices_draw_sink.dart`;
`git diff --stat` showed the file back to the intended 61-line diff; reran —
all 14 join tests green again.

### Mutation 2 — drop the `_runSegments >= 2` guard (investigative, then honest correction)

Removing the guard alone: all 14 tests stayed green (see discrepancy section
above) — this disproved the brief's original `// MUTATION:` claim for the
two-point test.

Then, to find what *does* protect that fixture, I disabled all three of
`_emitJoin`'s bails together (`cross == 0`, `dot < kMinMiterCosine`,
`mlen == 0`, each turned into `if (false && ...)`):

```
00:00 +12 -2: a closed run of two points closes without a phantom seam [E]
  Expected: true
    Actual: <false>
  test/vertices_join_test.dart 285:7   main.<fn>

00:00 +4 -1: a corner past the miter limit is bevelled, one triangle [E]
  Expected: <5>
    Actual: <6>
```

The two-point test went red exactly where predicted (`v.isFinite` false, a
NaN from `mx /= mlen` with `mlen == 0`), and a pre-existing Task 4 test
(unrelated to this fixture) also went red as an incidental confirmation that
those bails are real and exercised elsewhere. Restored via `cp
/tmp/vertices_draw_sink.dart.bak2 lib/src/vertices_draw_sink.dart`; `git diff
--stat` showed the intended 61-line diff again; reran — all 14 tests green.

I rewrote the two-point test's comment to describe this honestly rather than
claim the `_runSegments >= 2` guard is what saves it.

## Full-gate output

```
$ cd packages/jet_cad_2d && dart test
00:03 +720: All tests passed!
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.18 seconds.

$ cd packages/jet_cad_2d_flutter && flutter test
00:02 +204 ~1: All tests passed!
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
$ dart format --output=none --set-exit-if-changed .
Formatted 39 files (0 changed) in 0.07 seconds.
```

204 passing / 1 skipped in `jet_cad_2d_flutter`, up from the stated baseline
of 200/1 — the net of 4 new tests added and 0 removed (the assert test was
replaced in place, not removed).

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` — `_endRun`'s
  closed branch, `_flatten`'s stop-one-short loop bound, doc comment cleanup.
- `packages/jet_cad_2d_flutter/test/vertices_join_test.dart` — four new tests
  from the brief (one comment and one expected value corrected against the
  brief's own text, per above).
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` — the assert
  test replaced with the real closing-geometry assertion (Step 5), and
  `_expectUniformMiterStride` given a `closed` parameter (`4 * segments`
  instead of `4 * segments - 2`) because `circle()`'s two existing tests now
  exercise a genuinely closed run with one more corner than the open-arc
  formula assumed — this was a necessary consequence of the seam landing, not
  called out explicitly in the brief, but required for the full gate to stay
  green.

## Self-review findings

- Confirmed `apps/dev_harness_2d` was left untouched (not part of this task's
  gate, per the ruling).
- Confirmed `analysis_options.yaml` was never staged or modified
  (`git status --porcelain --ignored` shows nothing for it).
- Confirmed draw order: the seam join is appended after the closing quad,
  which is itself appended in the same buffer via the ordinary `_runTo` path
  — no out-of-order insertion.
- Confirmed the frame-allocation invariant isn't touched: no new fields beyond
  what Task 4 already declared, no per-call allocation added; ran the flutter
  gate including `test/invariants/paint_allocation_test.dart` (part of `flutter
  test`) and it passed.
- Double-checked the `_expectUniformMiterStride(sink, closed: true)` call
  sites are exactly the two that call `circle()`; the two that call `arc()`
  (open) were left at the default `closed: false`.

## Concerns

- The brief's own text (Step 1) contains a wrong expected value (`6 + 6`
  instead of `6 + 4`) and a wrong `// MUTATION:` claim (the `_runSegments >=
  2` guard). Both are fixed here with the reasoning documented in-line and
  above; a reviewer should double-check my arithmetic on the "two corners, not
  four" trace, since it's the one place I diverged from the brief's literal
  text on a value rather than only on prose.
- `_expectUniformMiterStride`'s `closed` parameter is a change to test
  infrastructure not explicitly called for in the brief, but was necessary
  for the full gate to pass once circles genuinely close — flagging it
  explicitly rather than burying it as an unremarked side effect.
