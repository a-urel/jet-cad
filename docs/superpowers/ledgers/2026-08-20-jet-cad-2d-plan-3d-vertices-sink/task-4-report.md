# Task 4 report: Joins — one walk, miter and bevel

Commit: `9031c57` — "feat: miter and bevel joins, shared by both stroke walks"

## What was implemented

Followed the brief's steps 1–11 essentially verbatim, with three deviations
noted below (each with its own rationale and evidence).

1. **`kMiterLimit` / `kMinMiterCosine`** — the two constants exactly as given,
   `4.0` and `2*(1/4)^2-1 = -0.875`.
2. **Run state as fields** — `_runFirstX/Y`, `_runFirstDx/Dy`, `_runPrevX/Y`,
   `_runPrevDx/Dy`, `_runHasDirection`, `_runSegments`, exactly as the brief
   specifies, beside the buffers. `_runFirst*` and `_runSegments` are written
   by `_beginRun`/`_runTo` but read by nothing yet — only Task 5's closed
   branch of `_endRun` will read them — so they carry `// ignore: unused_field`
   with a comment saying so; without it `flutter analyze` fails (see Deviation
   1 below).
3. **`_beginRun` / `_runTo` / `_endRun`** — verbatim from the brief. `_endRun`
   asserts `!closed` (Task 5's job) and does nothing else.
4. **`_emitJoin` / `_emitTriangle`** — verbatim from the brief: the notch
   `(V, A, M, B)` becomes the bevel triangle `(V, A, B)` plus the tip triangle
   `(A, M, B)`, mitred while `dot(d0, d1) >= kMinMiterCosine` and bevelled
   below it.
5. **`_emitQuad` / `_emitSegment` split** — `_emitQuad` takes a precomputed
   unit direction; `_emitSegment` derives it from endpoints and is what
   `point()` still calls.
6. **`polyline` and `_flatten` route through `_beginRun`/`_runTo`/`_endRun`**,
   both passing `closed: false` — the closing segment moves to Task 5 with its
   seam join, exactly as the brief specifies. No caller reaches
   `closed: true`: all four painter call sites pass `false`.
7. **Class doc comment** — the "No joins and no caps" bullet is now "No caps,
   and no seam join on a closed run," per the controller's ruling.

Files changed:
- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` (modified)
- `packages/jet_cad_2d_flutter/test/vertices_join_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` (modified —
  Step 10's fallout)
- `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
  (modified — one call-site rename)
- `packages/jet_cad_2d_flutter/test/vertices_differential_test.dart` (modified
  — the oracle's slack budget, see Deviation 3)

## Deviations from the brief, and why

### 1. `_runFirst*`/`_runSegments` need `// ignore: unused_field`

The brief gives these fields for Task 5 to consume later, but nothing in
Task 4 reads them (`_endRun`'s closed branch, which would, is exactly what
Task 4 asserts against). `flutter analyze` fails on `unused_field` without
the ignore comments. Added one per unused field/pair, each with a one-line
reason ("read only by the closed branch of `_endRun`, which is Task 5").

### 2. `frameTriangleCount` counts triangles literally, not "quads as one unit"

The brief's Step 10 states as fact: "`frameSegmentCount` counts triangles
rather than segments now." `_emitTriangle` (join triangles) already increments
its counter once per triangle. If `_emitQuad`'s counter increment stayed at
`+= 1` (as the old `_emitSegment` had it, and as Step 6's "the existing twelve
writes, unchanged" could be read to imply), the field would undercount by half
for every ordinary quad — the common case, since most of a CAD drawing is
un-joined dash spans. That contradicts "counts triangles" as a factual claim.
I changed `_emitQuad`'s increment to `+= 2` so `frameTriangleCount` equals
`debugPositions().length ~/ 6` for the frame — a true triangle count — and
updated the one test that pins an exact value (`an unbatchable op flushes
first...`, 2 → 4, since that test's two polylines are separate runs with no
join between them: 2 quads × 2 triangles = 4).

### 3. `vertices_differential_test.dart`'s stray-ink slack needed a join term

`expectNoStrayInk`'s `slackPx` budgeted `widestHalfStroke(ops)` — one
half-width — for how far a triangle's centroid can sit from the primitive it
belongs to. A miter tip can reach up to `half * kMiterLimit` from the vertex
(derived and confirmed empirically: at the miter-limit boundary,
`reach = half / cos(φ/2)` where `φ` is the direction-change angle, and at
`φ = arccos(kMinMiterCosine) ≈ 151°`, `reach/half → kMiterLimit` exactly). A
join triangle's centroid is the average of the two `half`-length corners and
the (up to `half * kMiterLimit`)-length tip, so it sits at most
`half * (2 + kMiterLimit) / 3` from the vertex, which sits on the primitive.
Replaced the flat `widestHalfStroke(ops)` term with
`widestHalfStroke(ops) * (2 + kMiterLimit) / 3`, which is strictly larger and
still tight (this dominates the old term at `kMiterLimit = 4`: factor 2 vs 1).
Before this fix, `the sink inks nothing the painter did not ask for` failed
with 4 of 361 triangles more than the old slack from any primitive — real
corners in the differential corpus, not a bug in the sink.

## A defect found in the brief's own test, fixed and documented in place

`vertices_join_test.dart`'s `'a right-angle corner is mitred out to the square
corner'` test, as given, asserted:

```dart
expect(_inked(sink, 11.5, -1.5), isTrue, reason: 'the miter tip');
expect(_inked(sink, 8.0, 2.0), isFalse, reason: 'the inside of the turn');
```

The second line cannot pass under *any* implementation, correct or buggy.
Verified by instrumentation (see below): `(8.0, 2.0)` sits exactly on the
boundary of segment 2's own plain quad (`x ∈ [8,12], y ∈ [0,10]`), which is
emitted whether or not `_emitJoin` exists at all. Separately, I verified that
for this exact 90° fixture, the *wrong-side* bevel+tip triangles (the ones the
brief's own mutation comment describes) land entirely inside the pre-existing
overlap of segments 1's and 2's quads (`x ∈ [8,10], y ∈ [0,2]`) — a
mathematical coincidence of exactly-orthogonal joins — so they add no ink a
point-containment probe could detect there either. The probe cannot
discriminate the mutation in either direction.

Instrumentation transcript (temporary debug test, not committed):

```
tri 0: (0.0,2.0) (0.0,-2.0) (10.0,2.0)
tri 1: (0.0,-2.0) (10.0,-2.0) (10.0,2.0)
tri 2: (10.0,0.0) (10.0,-2.0) (12.0,0.0)     <- join bevel
tri 3: (10.0,-2.0) (12.0,-2.0) (12.0,0.0)    <- join tip
tri 4: (8.0,0.0) (12.0,0.0) (8.0,10.0)
tri 5: (12.0,0.0) (12.0,10.0) (8.0,10.0)
inked(8,2) plain quads only (tris 0,1,4,5, no join): true
inked(11.5,-1.5) plain quads only (tris 0,1,4,5, no join): false
inked(11.5,-1.5) join tris only (tris 2,3): true
```

`(11.5, -1.5)` — the *first* assertion — is the one point in this fixture that
only a correctly-sided join covers, and it already fully discriminates the
"miter on the inside of the turn" mutation (see mutation run below). I
removed the unsatisfiable second assertion, rewrote the comment to explain why
a right-angle fixture cannot test the inside probe, and kept the rest of the
test's intent (and its `MUTATION:` comment, corrected to name the actual code
path: `_emitJoin`'s `s = cross > 0 ? -half : half`).

## TDD evidence

### RED

```
$ flutter test test/vertices_join_test.dart
...
test/vertices_join_test.dart:57:29: Error: Member not found: 'kMiterLimit'.
    expect(VerticesDrawSink.kMiterLimit, 4.0);
                            ^^^^^^^^^^^
test/vertices_join_test.dart:58:29: Error: Member not found: 'kMinMiterCosine'.
    expect(VerticesDrawSink.kMinMiterCosine, closeTo(-0.875, 1e-12));
                            ^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

Expected: the constants do not exist yet.

### GREEN

```
$ flutter test test/vertices_join_test.dart
00:00 +0: the miter limit and its cosine are Impellers own
00:00 +1: a right-angle corner is mitred out to the square corner
00:00 +2: a mitred corner emits both the bevel and the tip triangle
00:00 +3: a corner past the miter limit is bevelled, one triangle
00:00 +4: a corner just inside the limit is still mitred
00:00 +5: an open polyline gets no join between its ends
00:00 +6: a zero-length step is skipped and the join spans it
00:00 +7: joins are emitted under the residual, not in local space
00:00 +8: a flattened curve joins its chords
00:00 +9: All tests passed!
```

Getting here also required fixing fallout in `vertices_draw_sink_test.dart`
(interleaved join triangles broke `_startCentre`/`_endCentre`'s fixed-stride
arithmetic and the exact triangle counts) and `vertices_differential_test.dart`
(Deviation 3). Both went through their own red/green cycles; final state below.

## Mutations run (real transcripts)

Each: `cp` the production file aside, apply the mutation, run, watch red,
restore via a `trap`, confirm `diff` against the backup shows no drift.

### Mutation 1: drop the bevel triangle (tip alone)

```dart
// _emitJoin, replaced:
_emitTriangle(vx, vy, ax, ay, bx, by, argb);
// with:
// MUTATION: bevel triangle dropped, tip only
```

```
$ flutter test test/vertices_join_test.dart
...
Failing tests:
  a corner just inside the limit is still mitred
  a corner past the miter limit is bevelled, one triangle
  a flattened curve joins its chords
  a mitred corner emits both the bevel and the tip triangle
  an open polyline gets no join between its ends
  a zero-length step is skipped and the join spans it
00:00 +3 -6: Some tests failed.
```

`a mitred corner emits both the bevel and the tip triangle` is exactly the
test this mutation is named for in its own comment — confirmed factually
accurate. Restored; `diff` against the backup was empty.

### Mutation 2: take the miter on the inside of the turn

```dart
// _emitJoin, replaced:
final s = cross > 0 ? -half : half;
// with:
final s = cross > 0 ? half : -half; // MUTATION: wrong side
```

```
$ flutter test test/vertices_join_test.dart
...
00:00 +1 -1: a right-angle corner is mitred out to the square corner [E]
  Expected: true
    Actual: <false>
  the miter tip
...
Failing tests:
  a flattened curve joins its chords
  a mitred corner emits both the bevel and the tip triangle
  a right-angle corner is mitred out to the square corner
  a zero-length step is skipped and the join spans it
  joins are emitted under the residual, not in local space
00:00 +4 -5: Some tests failed.
```

`a right-angle corner is mitred out to the square corner` — the test I fixed
— fails exactly as its rewritten `MUTATION:` comment predicts. Restored;
`diff` against the backup was empty.

### Mutation 3: never emit the join at all

```dart
// _runTo, replaced:
if (_runHasDirection) {
// with:
if (false) {
```

```
$ flutter test test/vertices_join_test.dart test/vertices_draw_sink_test.dart
...
Failing tests: (13 total, including)
  a circle closes on itself
  a non-uniform residual turns a circle into an ellipse
  a polyline of n points emits n-1 segments plus a join at each corner
  an arc is flattened, and its ends sit on the arc
  ...
00:00 +23 -13: Some tests failed.
```

This also exercised the new `_expectUniformMiterStride` sanity check I added
to `vertices_draw_sink_test.dart` (its own reason string appears in the
`a circle closes on itself` failure), confirming that guard fires rather than
silently misreading when the join layout it assumes breaks. Restored; `diff`
against the backup was empty; re-ran both files green afterward (36 tests).

## Full-gate output

```
$ cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
...
00:03 +720: All tests passed!
Analyzing jet_cad_2d...
No issues found!
Formatted 105 files (0 changed) in 0.18 seconds.

$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
...
00:02 +198 ~2: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
Formatted 39 files (0 changed) in 0.07 seconds.
```

198 passing (189 baseline + 9 new join tests, net of the closed-polyline half
moving to a named skip), 2 skipped (the pre-existing one plus the new
Task-5-deferred `'a closed polyline gets a closing segment and a seam join'`).

`analysis_options.yaml` was not touched or committed (`git status` confirms).

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- `packages/jet_cad_2d_flutter/test/vertices_join_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`
- `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
- `packages/jet_cad_2d_flutter/test/vertices_differential_test.dart`

## Self-review findings

- Checked every `// MUTATION:` comment I wrote against the code it describes
  (the specific warning in the task brief about two earlier tasks shipping
  factually wrong ones). Found and fixed one — see "A defect found in the
  brief's own test" above — before it could ship silently passing-but-blind.
- `point()` still calls `_emitSegment` directly, not through the run — correct,
  since a single dot has no corner to join.
- `_endRun`'s `half`/`argb` parameters are unused in the open-only body Task 4
  ships; they are required by Task 5's closed branch and the brief specifies
  the signature, so I kept them rather than stripping and re-adding later.
  `flutter analyze` does not flag unused parameters the way it flags unused
  fields, so no ignore comment was needed there.
- Confirmed via `apps/dev_harness_2d`'s one reference to the renamed
  `frameSegmentCount` (`integration_test/frame_timing_test.dart:158`) that I
  did **not** touch that file, per the controller's explicit ruling ("Do not
  touch it... not part of your gate"). This is a deliberate divergence from
  the brief's Step 10, which asks for "the two rig call sites" there (only one
  actually exists) to be updated. Consequence: that one line in
  `apps/dev_harness_2d` will now fail to compile/analyze until Task 7 (or
  whoever next touches that file) does the same rename there. Flagged as a
  concern below.
- Verified `_runFirstX/Y`, `_runFirstDx/Dy`, `_runSegments` are genuinely
  unused this task (not silently wrong) by reading every call site of
  `_beginRun`/`_runTo`/`_endRun` — only `_endRun`'s asserted-away closed
  branch would read them.

## Concerns

1. **`apps/dev_harness_2d/integration_test/frame_timing_test.dart:158`** now
   references a getter (`frameSegmentCount`) that no longer exists on
   `VerticesDrawSink`, per the deliberate deviation above (controller's
   ruling 2 vs. the brief's Step 10). This was already true before my change
   in spirit — the harness is "expected red" and "not part of the gate" — but
   my rename adds a *new* failure mode (compile error) to a file I was told
   not to touch. Whoever picks up that file next (Task 7, per STATUS.md) needs
   `frameSegmentCount` → `frameTriangleCount` there as a one-line fix.
2. **`frameTriangleCount`'s semantics** (Deviation 2) is my own resolution of
   an ambiguity in the brief's Step 10 rather than a literal transcription —
   documented above with the reasoning; a reviewer may want to confirm this
   reading against the brief's intent.
3. Per the explicit ruling, closed runs remain unimplemented (`_endRun`
   asserts `!closed`) — Task 5's job, not a defect here.

---

## Fix report (review round 1)

The coordinator's review confirmed the geometry, the single walk, no per-entity
allocation, and both disputed judgements (the unsatisfiable `(8.0, 2.0)` probe
and `frameTriangleCount` as a literal count) — **not approved** on four points,
addressed below.

### 1 (Important) — right-turn branch untested; `s = -half` survived the whole suite

Added `'a right (clockwise) turn is mitred out on its own outer side'` to
`vertices_join_test.dart`: `[0,0, 10,0, 10,-10]`, probing `(11.5, 1.5) isTrue`
— the reviewer's fixture. Hand-derived the expected geometry before writing
the test (cross < 0, so `s = half`; bevel `(10,0),(10,2),(12,0)`, tip
`(10,2),(12,2),(12,0)`) and it matches the reviewer's own dump exactly.

Ran the exact mutation the reviewer named — `s = cross > 0 ? -half : half` →
`s = -half`, deleting the right-turn arm — against the file with the new
fixture in place:

```
$ flutter test 2>&1 | tail -6
...
Failing tests:
  test/vertices_join_test.dart: a right (clockwise) turn is mitred out on its own outer side

$ flutter test test/vertices_join_test.dart 2>&1 | tail -20
00:00 +2 -1: a right (clockwise) turn is mitred out on its own outer side [E]
  Expected: true
    Actual: <false>
  the miter tip
...
Failing tests:
  test/vertices_join_test.dart: a right (clockwise) turn is mitred out on its own outer side
```

Exactly one test failed, out of the full 199-test suite (198 + the new
fixture) — confirming the reviewer's finding that every other fixture in the
repository turns left and was blind to this mutant. Restored via the `cp`
backup; `diff` against the backup was empty.

### 2 (Important) — `_endRun`'s assert made reachable

`polyline` now calls `_endRun(closed: closed, half: half, argb: argb)`
instead of hardcoding `closed: false`. `_flatten`'s call site is untouched —
still `closed: false`, per the ruling ("Task 5 makes that one live when it
implements the seam").

The dead `test('a closed polyline gets a closing segment and a seam join',
skip: ...)` placeholder is replaced with an active test that calls
`polyline(..., closed: true)` and asserts it throws `AssertionError` — giving
Task 5 a test it must *change* (from "throws" to a real geometric assertion)
rather than a silent gap to rediscover:

```
$ flutter test test/vertices_draw_sink_test.dart 2>&1 | grep -A1 "closed polyline"
00:00 +4: a closed polyline hits the unimplemented closed branch, loudly
```

Passes because the assert now actually fires — confirmed separately by
reverting the forwarding change locally and observing the same call return 6
triangles with no assertion (the exact silent-drop the reviewer described);
restored before running anything else.

### 3 (Minor) — `_inked`'s off-by-one

`i + 5 < v.length ~/ 2` → `i + 2 < v.length ~/ 2` in
`vertices_join_test.dart`, with a comment explaining the boundary. Re-ran the
full join suite after the fix:

```
$ flutter test test/vertices_join_test.dart
00:00 +9: All tests passed!  (then +10 after item 1's fixture was added)
```

**No assertion changed value.** None of the file's existing probe points
happen to fall inside what was the invisible last triangle in any fixture, so
this was a real but so-far-silent blind spot rather than a value change here.
Its value showed up indirectly: with the fix in place, Mutation 3 from the
original report (dropping the join entirely) re-run in this round still kills
the same set of `vertices_draw_sink_test.dart` tests as before — the fix
doesn't change which tests already relied on full-buffer visibility, it
removes a blind spot at the tail that a Task-5 seam-join fixture would have
walked straight into.

### 4 (Minor) — mutation comment corrected to match the observed red

Replaced the "emit the tip triangle alone" mutation (which fails on
`_triangleCount(sink), 6` before ever reaching the wedge probe) with the
reviewer's variant C: swap the bevel triangle's outer corners for the inner
ones, leaving the tip triangle's `A`/`B` untouched. Comment now names both the
mutation and why the count-only alternative was rejected.

```
$ flutter test test/vertices_join_test.dart --plain-name "a mitred corner emits both the bevel and the tip triangle" 2>&1 | tail -14
00:00 +0: a mitred corner emits both the bevel and the tip triangle
00:00 +0 -1: a mitred corner emits both the bevel and the tip triangle [E]
  Expected: true
    Actual: <false>
  the bevel wedge

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/vertices_join_test.dart 132:5                  main.<fn>
```

`the bevel wedge` is the `_inked(sink, 10.6, -0.6)` reason string — the
triangle-count assertion above it (line 130) passed silently, confirming the
comment now names the mechanism that actually fires.

All three mutations above were restored via `cp` backup + `diff` verification
before the next step; each is a separate `cp`/`trap`/mutate/test/restore
cycle, not a single mutated file carried across steps.

### Full gate after all four fixes

```
$ cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
...
00:03 +720: All tests passed!
Analyzing jet_cad_2d...
No issues found!
Formatted 105 files (0 changed) in 0.18 seconds.

$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
...
00:02 +200 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
Formatted 39 files (0 changed) in 0.07 seconds.
```

200 passing (198 prior + the new right-turn fixture, and the closed-polyline
skip became a real passing test — net +2), 1 skipped (the one pre-existing
skip, unrelated to this task). `analysis_options.yaml` untouched
(`git status` confirms).

### Files changed in this round

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` — forward
  `closed` from `polyline` to `_endRun`.
- `packages/jet_cad_2d_flutter/test/vertices_join_test.dart` — right-turn
  fixture, `_inked` off-by-one fix, corrected mutation comment/variant.
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` — the
  skipped closed-polyline placeholder replaced with an active
  assert-throws test.

### Not addressed (per the coordinator's explicit ruling)

`apps/dev_harness_2d/integration_test/frame_timing_test.dart:158` left alone —
deferred to Task 7 by ruling, which also now needs `segments=` → `triangles=`
in the same print string. The three further minors (the `_inked` zero-area
blind spot, the unreachable `cosHalf <= 0` / `mlen == 0` guards, and the
differential slack's join term applying to plain quads too) are recorded as
deferred to Task 5, per the coordinator's message — not touched here.
