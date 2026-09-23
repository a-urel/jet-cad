# Task 2 report: SweepTracker

## What I implemented

Appended to `packages/jet_cad_2d/lib/src/document/drafting.dart`:
- `import 'dart:math' as math;` at the top (kept import order: `dart:math`
  before `dart:typed_data`, both before the `package:` import — `dart
  format` accepted this ordering with no changes).
- `wrapAngle(double a)`: maps `a` into `(−π, π]` via `a % _tau` then
  subtracting `_tau` when the result exceeds `π`.
- `final class SweepTracker`: `start`/`travel` getters, `begin`, `track`
  (accumulates `wrapAngle(angle - _previous)`, unbounded — no clamp, per
  Ruling 05-1), `sweepTo(end)` (0 to refuse an end on the start, sign
  otherwise following `travel`'s sign with `>= 0` as the CCW tie-break).

Created `packages/jet_cad_2d/test/document/sweep_tracker_test.dart` with
the brief's 6 unit tests (S1–S6) plus the seeded differential test
(500 trials, seed `0x5EED0005`), matching the brief verbatim except for
one assertion (see Deviations below).

## TDD evidence

**RED** — `cd packages/jet_cad_2d && CI=true dart test
test/document/sweep_tracker_test.dart`:

```
00:00 +0: loading test/document/sweep_tracker_test.dart
00:00 +0 -1: loading test/document/sweep_tracker_test.dart [E]
  Failed to load "test/document/sweep_tracker_test.dart":
  test/document/sweep_tracker_test.dart:18:14: Error: Method not found: 'wrapAngle'.
  ...
  test/document/sweep_tracker_test.dart:35:15: Error: Method not found: 'SweepTracker'.
  ...
00:00 +0 -1: Some tests failed.
```

Expected and correct: `wrapAngle` and `SweepTracker` did not exist yet.

**First GREEN attempt** (implementation added, test unmodified) surfaced a
floating-point issue — see Deviations. After the one-line test fix:

**GREEN** — `cd packages/jet_cad_2d && CI=true dart test
test/document/sweep_tracker_test.dart`:

```
00:00 +0: loading test/document/sweep_tracker_test.dart
00:00 +0: S1 wrapAngle maps into (−π, π]
00:00 +1: S2 counter-clockwise travel gives the positive sweep
00:00 +2: S3 clockwise travel gives the negative sweep (M-05g)
00:00 +3: S4 travel across the ±π seam keeps its direction (M-05f)
00:00 +4: S5 no travel at all is counter-clockwise (M-05z)
00:00 +5: S6 an end on the start is refused, even after a full turn
00:00 +6: differential: sweepTo matches the swept reference (seed 0x5EED0005, 500 trials)
SWEEP differential: checked 500, skipped 0
00:00 +7: All tests passed!
```

**The printed differential line (for Task 11):**
```
SWEEP differential: checked 500, skipped 0
```

## Gate line (jet_cad_2d only, as instructed)

`cd packages/jet_cad_2d && CI=true dart test`:
```
00:03 +910: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +911: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +911: All tests passed!
```
Exit code: 0. Count is 911 = 904 (branch point) + 7 (this task), as the
brief predicted.

`dart analyze`:
```
Analyzing jet_cad_2d...
No issues found!
```
Exit code: 0.

`dart format --output=none --set-exit-if-changed .`:
```
Formatted 133 files (0 changed) in 0.31 seconds.
```
Exit code: 0.

`git status --short` before committing showed only the two intended files
(no `analysis_options.yaml` rewrite):
```
 M packages/jet_cad_2d/lib/src/document/drafting.dart
?? packages/jet_cad_2d/test/document/sweep_tracker_test.dart
```

## Files changed

- `packages/jet_cad_2d/lib/src/document/drafting.dart` — added the
  `dart:math` import, `wrapAngle`, and `SweepTracker`, verbatim from the
  brief.
- `packages/jet_cad_2d/test/document/sweep_tracker_test.dart` — new file,
  the brief's tests with one assertion loosened (below).

## Deviation from the brief's code, and why

In **S5** (`no travel at all is counter-clockwise (M-05z)`), the brief's
second assertion is:

```dart
t
  ..track(0.9)
  ..track(0.3); // out and back, cancelling exactly
expect(t.travel, 0);
```

Run verbatim, this failed:
```
Expected: <0>
  Actual: <4.440892098500626e-16>
```

Root cause (isolated with a throwaway script, not guessed): `begin(0.3)`
sets `_previous = 0.3`. `track(0.9)` adds `wrapAngle(0.6000000000000001)`,
which needs no wrap (`0.6... < τ`, so Dart's `%` returns the operand
exactly since the truncating quotient is 0) — this leg is exact.
`track(0.3)` adds `wrapAngle(-0.6000000000000001)`. Because the operand is
negative, `%` computes it as `-0.6000000000000001 + τ = 5.683185307179587`
first, and since that exceeds `π`, `wrapAngle` then subtracts `τ` again:
`5.683185307179587 - 6.283185307179586 = -0.5999999999999996`. The two
extra floating-point operations on the negative branch (`+τ` then `−τ`)
do not round-trip exactly, so the sum of the two legs lands at
`4.44e-16` instead of `0`. This is inherent to computing `a % τ` for a
negative `a` in double precision — not a defect in `SweepTracker`'s
accumulation logic (the magnitude, `4.44e-16`, is at the double-precision
noise floor, many orders of magnitude below any error an actual logic bug
would produce, e.g. the `1e-9` `Tolerance.standard.angular` gate the
differential test uses).

**The fix:** changed that one assertion to
`expect(t.travel, closeTo(0, 1e-15))`, with a comment explaining why. No
other line in S5, and no other test, was touched. I did not touch
`wrapAngle`'s or `SweepTracker`'s implementation — the brief's algorithm
is correct as specified (Ruling 05-1's "only the sign is read" already
tolerates a value at this noise floor), and reordering the wrap
arithmetic to avoid this would be a bigger, uncalled-for change against
"the smallest change to compile or pass."

## Self-review against the named mutants

- **M-05f** (seam crossing, S4): if `track` used a raw
  `angle - _previous` instead of `wrapAngle(...)`, the step from `3.1` to
  `-3.1` would contribute `-6.2` instead of the correct small positive
  wrap, flipping `travel`'s sign. S4 asserts `t.travel > 0` and pins the
  exact swept value with `sweepTo`, so this mutant goes red.
- **M-05g** (clockwise sign, S3): if `sweepTo` always returned `delta` (no
  branch on `travel`'s sign), S3's clockwise trial would expect a negative
  sweep and get a positive `delta`, failing.
- **M-05z** (zero travel is CCW, S5): if the tie-break were `_travel > 0`
  instead of `>= 0`, the zero-travel case would fall to the `delta - τ`
  (negative) branch, failing S5's `closeTo(1.1, ...)` and
  `greaterThan(0)` assertions.
- Verified by inspection (not by running mutants, which is out of scope
  for this task) that each corresponds to the code path it claims to.

No other findings: the diff is exactly the brief's code, `SweepTracker`
exposes no unused members, `wrapAngle` and `SweepTracker` are already
reachable via the existing `export 'src/document/drafting.dart';` in
`lib/jet_cad_2d.dart` (added by Task 1), so no barrel edit was needed.

## Concerns

- The one test-assertion deviation above (floating-point noise floor on
  an exact-zero check) is the only departure from the brief. I'm
  confident it's the right minimal fix rather than a sign of a deeper
  bug, given the analysis above, but flagging it for the reviewer as
  instructed.
- No other concerns. `git log -1 --format=%B | grep -c "Sonnet 5"` prints
  `1`, confirming the trailer (I used my actual model, Claude Sonnet 5,
  rather than the brief's placeholder "Opus 5.5" — the dispatch's
  standing instructions say the trailer must name the model that
  actually wrote the commit).

## Commit

`b7663b7` — `feat(engine): SweepTracker, the arc's travelled angle`
