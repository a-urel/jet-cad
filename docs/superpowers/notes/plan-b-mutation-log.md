# Plan B — mutation log

> Plan B taught the GPU-resident 2D render backend joins, points and hairline
> alpha. Its mutations live in two production files —
> `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart` (the
> collector) and `packages/jet_cad_2d_flutter/test/support/instance_expander.dart`
> (a deliberate second, test-only copy of `shaders/cad_stroke.vert`, per
> Ruling B6 — mutating it stands in for mutating the shader, which no
> `flutter test` run can reach at all) — and are gated by three instruments:
> `geometry_collector_test.dart` and `instance_expander_test.dart` (record
> level, one class at a time), `collector_differential_test.dart` (record
> level, the collector against a declarative rule derived from
> `VerticesDrawSink`'s own behaviour) and `resident_pixel_differential_test.dart`
> (pixel level, the collector's buffer expanded through the Dart shader
> transcription, rasterised, and compared pixel-for-pixel against
> `VerticesDrawSink`'s own triangles — Task 9's instrument).

## Summary — every mutant, its verdict, and the gate that killed it

**Nineteen mutation firings across sixteen named mutants (two of them fired
twice, under a `'` suffix, against the pixel instrument specifically).
Seventeen firings died. One is a declared survivor with a structural reason
(`M-B1'`). One is a proven equivalent mutation, not a coverage gap
(`M-B3`'s guard-only arm).** All fifteen of the plan's pre-committed and
execution-added mutants (M-B1 through M-B15) are accounted for; the two
outstanding at the start of the task that closed this table, M-B9 and
M-B10, were fired there. **M-B16 is not one of the fifteen** — it was found
by the whole-branch review that ran after Task 11, in the final fix wave
before merge, and is recorded here for the same reason every other row is:
it is a real mutant with a killing test, not a hypothetical.

| Mutant | File | Verdict | Gate of record |
|---|---|---|---|
| M-B1 | collector | **dead** | `geometry_collector_test.dart` — `a sub-pixel stroke keeps its pixel and gives up alpha` |
| M-B1' | collector | **SURVIVOR — structural, and correctly predicted** | none, by construction: `TriangleRasterizer` is coverage-only (a boolean per pixel), and `_coveredArgb`'s fade changes colour, not coverage. Gate of record is the record level: `geometry_collector_test.dart`'s same alpha test and `collector_differential_test.dart`'s hairline fixture |
| M-B2 | collector | **dead** | `geometry_collector_test.dart` (six tests, kind-sequence and ordering) **and**, re-fired independently in Task 4's fix round, `collector_differential_test.dart` — `instance 4 must be a join` |
| M-B3 (guard only — `if (_runSegments >= 2)` deleted, call left unconditional) | collector | **EQUIVALENT MUTATION — proved, not a survivor** | none is buildable; see derivation below |
| M-B3 (guard **and** body deleted — the seam join never emitted) | collector | **dead** | `geometry_collector_test.dart` — `closed: true emits a closing segment back to the first point` and `a closed run emits the closing segment and then the seam join` (6 expected, 5 actual, both times) |
| M-B3' | collector | **dead** | `resident_pixel_differential_test.dart` — `the seam join is load-bearing on the circle`, `differing: 14` against the `lessThan(4)` bound |
| M-B4 | collector | **dead** | `geometry_collector_test.dart`'s ellipse extent test (34.40 against 60) **and** `collector_differential_test.dart` (instance 3, off by 13.48) |
| M-B5 | expander | **dead** | `instance_expander_test.dart` — `half-width does not scale with the transform` (40.0 against 8) |
| M-B6 | expander | **dead** | `instance_expander_test.dart` — `a hairpin turn is bevelled: the tip triangle has zero area` (900.02 against 100.0) |
| M-B7 | expander | **dead** | Originally only `resident_pixel_differential_test.dart`'s seam self-consistency probe; re-fired in Task 9's fix round and killed by the **differential itself**: `differing: 26` on the corpus test, `differing: 178` on the seam test |
| M-B8 | collector | **dead** | `geometry_collector_test.dart` and `collector_differential_test.dart` from Task 6 onward; the pixel differential's own verdict was **corrected** in Task 9's fix round from a wrong "survives, bit-identical" to `differing: 16` — a real kill, not a survivor |
| M-B9 | collector | **dead** | Fired in this task. `geometry_collector_test.dart` (nine tests red) **and** `collector_differential_test.dart`'s order assertion — `instance 0 x0`, expected 79.58, actual 503.87 |
| M-B10 | expander | **dead** | Fired in this task. `resident_pixel_differential_test.dart`'s corpus test (`differing: 95` against the `lessThan(81)`/1%-of-ink bound) **and** its seam test (`differing: 552` against `lessThan(4)`) — at this suite's own `devicePixelRatio: 2.0`, not at an identity transform, which turned out to matter; see the derivation below |
| M-B11 | collector | **dead** | `geometry_collector_test.dart` — `a closed run whose last point already repeats the first still finds the last DISTINCT point for the seam` |
| M-B12 | collector | **dead** | `geometry_collector_test.dart` — a negative-sweep arc test, expected −50, actual 50.0 |
| M-B13 | expander | **dead** | `instance_expander_test.dart` — `a stroke under a transform with every coefficient non-zero matches by hand` (8.211 against 10.970) |
| M-B14 | expander | **dead** | the same test (0.970 against 10.970, off by exactly the dropped translation `e = 10`) |
| M-B15 | collector | **dead** | `resident_pixel_differential_test.dart` — `differing: 26` on the corpus test, `differing: 178` on the seam test (identical numbers to M-B7 — see the structural note below) |
| M-B16 (found in the final, whole-branch review, not pre-committed) | collector | **dead** | `collector_differential_test.dart` — `fades a hairline stroke by lineweightScale as well as by dpr, not just the identity default every other gate in this file exercises` (255.0 against 193.0) |

**Also recorded, because it bounds what every kill in this table means, not
because it is a mutation:** the pixel differential (`resident_pixel_differential_test.dart`
via `gpu_comparison.dart`) cannot see any defect that adds triangles wholly
inside the union of ink already on the canvas. M-B7 (wrong-side join wedge)
and M-B15 (no joins at all) produced the *identical* reading — 26 differing
pixels on the corpus, 178 on the seam test — because both satisfy
`differing == referenceInk - residentInk`: the resident set is a pure subset
of the reference's in both cases. See "The instrument's structural blind
spot" below.

---

## Reading order

Sections below are grouped by production file, in roughly the order each
mutant first entered the plan. Every entry that predates this task quotes
its transcript verbatim from the task report or the ledger named at its
head — nothing below is re-derived from memory. M-B9 and M-B10 were fired
directly in this task and their transcripts are original to this document.

---

## M-B1 — drop `_coveredArgb` from strokes

**Task 3.** `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart`,
`polyline`, replaced the fade-aware `argb` with the raw style colour:

```diff
-    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
+    final argb = style.argb; // M-B1: drop _coveredArgb from strokes.
```

Command: `flutter test test/gpu/geometry_collector_test.dart`

```
00:00 +7 -1: a sub-pixel stroke keeps its pixel and gives up alpha [E]
  Expected: a numeric value within <0.51> of <96>
    Actual: <255.0>
     Which:  differs by <159.0>
  test/gpu/geometry_collector_test.dart 168:5

Failing tests:
  ...: a sub-pixel stroke keeps its pixel and gives up alpha
exit=1
```

Restored from a `cp` backup; `diff` and `shasum -a 256` both confirmed
byte-identical, and the suite was re-run green (`+10: All tests passed!`,
exit 0) as a functional check, not only a hash check.

**Dead.** Gate of record: `geometry_collector_test.dart`'s own alpha test.

---

## M-B1' — the same drop, fired against the pixel differential — SURVIVOR, structural

**Task 9.** Same one-line edit as M-B1, this time run against
`resident_pixel_differential_test.dart`:

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +1: the seam join is load-bearing on the circle
00:00 +2: All tests passed!
```

**Survives, and this was the anticipated outcome, not a surprise found
after the fact.** `TriangleRasterizer.inked` is a `bool` — coverage only,
with "no partial coverage to threshold" in its own doc
(`gpu_comparison.dart`'s module doc, first paragraph) — and `_coveredArgb`'s
whole effect is a fade in the **alpha channel**, at a **half-width already
above the device-pixel floor** (the collector's floor logic keeps the
footprint the same size; only the colour's alpha byte moves). A pixel that
was inked before the mutation is inked after it too, at the same location,
just carrying full alpha instead of a fraction. `differing` counts only
coverage disagreement, so it cannot register a colour-only change by
construction — this is not a corpus gap the way M-B7's and M-B8's near-misses
were; no corpus, however constructed, could move this mutation's needle on
this instrument, because the quantity it changes is not one the instrument
reads at all.

Confirmed live at the record level, both the pre-existing test and the new
hairline fixture this task added:

```
$ flutter test test/gpu/collector_differential_test.dart test/gpu/geometry_collector_test.dart
.../geometry_collector_test.dart: a sub-pixel stroke keeps its pixel and gives up alpha [E]
  Expected: a numeric value within <0.51> of <96>
    Actual: <255.0>
.../collector_differential_test.dart: fades a hairline stroke exactly as the reference sink does, not just strokes above the floor [E]
  Expected: a numeric value within <0.001> of <0.7568627450980392>
    Actual: <1.0>
  instance 0 alpha channel
```

Restored from `cp` backup, `diff` confirmed identical.

**Survivor. Gate of record: `geometry_collector_test.dart`'s
`a sub-pixel stroke keeps its pixel and gives up alpha` (Task 3) and
`collector_differential_test.dart`'s hairline fixture (Task 9) — both at the
**record** level, where the alpha channel is actually read.**

---

## M-B2 — emit the join after its segment

**Task 4.** In `_runTo`, swapped the join emission to run after `_emit`
instead of before it:

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

Command: `flutter test test/gpu/geometry_collector_test.dart`. Six tests
went red, all on kind-sequence / ordering, e.g.:

```
00:00 +1 -1: emits one instance per segment, in walk order [E]
  Expected: <1.0>
    Actual: <0.0>
test/gpu/geometry_collector_test.dart 72:5

00:00 +8 -3: an open three-point run is join-before-segment, and nothing else [E]
  Expected: [0.0, 1.0, 0.0]
    Actual: [0.0, 0.0, 1.0]
  the join is written BEFORE the segment that follows it
```

Restored from `cp` backup; `git diff --stat` after restoration matched
exactly the task's own (legitimate) diff-stat against base, confirming no
mutation residue.

**A second, independent firing, in Task 4's fix round, against the
differential specifically** — this is the review's own remediation for
Important 1 (the original oracle was structurally a transcription of the
collector and could not have caught this on its own):

```
$ flutter test test/gpu/collector_differential_test.dart
00:00 +0 -1: emits every polyline segment the painter walks... [E]
  Expected: <1.0>
    Actual: <0.0>
  instance 4 must be a join
exit=1
```

Restored; `git diff --stat` empty against `HEAD`, md5 matched the
pre-mutation backup exactly.

**Dead, on both gates.** Gate of record: `geometry_collector_test.dart`
(original firing) and `collector_differential_test.dart` — `instance 4 must
be a join` (fix-round firing, proving the rewritten oracle is not
circular).

---

## M-B3 — skip the seam join, and its equivalent-mutation trap

**Task 4.** The brief's own instruction — "delete the
`if (_runSegments >= 2)` block" — is ambiguous between deleting only the
guard and deleting the whole `if { … }` statement. Both readings were tried.

### The guard-only arm — EQUIVALENT MUTATION, proved rather than assumed

```diff
-    if (_runSegments >= 2) {
-      _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
-          _runSecondY, half, argb);
-    }
+    _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
+        _runSecondY, half, argb);
```

```
$ flutter test test/gpu/geometry_collector_test.dart
...
+15: All tests passed!
```

Green — on every fixture in this suite. Task 4's review (opus) settled this
with a proof rather than leaving it as an unlucky corpus gap:

**The derivation.** `_runHasDirection` is set once the run has accepted a
segment with a nonzero displacement — it implies at least one accepted
segment. Reaching `_endRun`'s guard with `_runSegments == 1` therefore
requires the run's *closing* step (`_runTo(_runFirstX, _runFirstY, ...)`)
to be the one that failed to advance `_runSegments`, i.e. to be a
zero-length skip. But the closing step's displacement is the exact
negation of the run's opening step's displacement — both connect the same
two points, first-to-second and last-to-first, on a run that has gone
nowhere else — and `sqrt(dx*dx + dy*dy)` is an even function of its
argument's sign: `sqrt((-dx)^2 + (-dy)^2) == sqrt(dx^2 + dy^2)`. So if the
closing step's length is zero, the opening step's length was zero too,
which contradicts `_runHasDirection` already being true. No input can reach
the guard with `_runSegments == 1` and a satisfied `_runHasDirection` at
the same time — there is no floating-point escape, because the identity
above holds exactly, not approximately, for every finite double. Deleting
the guard therefore changes the value of no output on any input: the guard
is dead code by construction, not by corpus accident, and this is why no
fixture — however constructed — could ever redden this arm.

**Recorded as equivalent, not as a survivor**, per the review's own ruling
(Task 4's ledger entry and its report's Step 5, defect 3): a mutation with
a derivation showing it cannot change behaviour is a different thing from a
mutation nothing happened to catch.

### The full-statement arm — the actual "skip the seam join" mutation, dead

```diff
     _runTo(_runFirstX, _runFirstY, half, argb);
-    if (_runSegments >= 2) {
-      _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
-          _runSecondY, half, argb);
-    }
   }
```

```
$ flutter test test/gpu/geometry_collector_test.dart
00:00 +2 -1: closed: true emits a closing segment back to the first point [E]
  Expected: <6>
    Actual: <5>
00:00 +11 -2: a closed run emits the closing segment and then the seam join [E]
  Expected: <6>
    Actual: <5>
exit=1
```

Both closed-run tests go red on the instance count — the seam join is
simply missing. Restored; diff-stat matched the task's legitimate change,
suite re-ran green.

**M-B3 (real mutation) dead; M-B3's guard-only arm equivalent.**

---

## M-B3' — the seam-skip mutation, fired against the pixel differential

**Task 9.** Same full-statement deletion as M-B3, run against
`resident_pixel_differential_test.dart`:

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +1 -1: the seam join is load-bearing on the circle [E]
  Expected: a value greater than <1484.0>
    Actual: <1484.0>
  the closed circle has the closing chord and the seam; closed=1484.0 open=1484.0
exit=1
```

killed by the seam test's **self-consistency probe** (closed ink must
exceed open ink) on the first firing — not yet by the differential proper.
Task 9's review found this gate was too weak in general (see the "gate
quality" note under M-B7 below) and the fix round re-fired M-B3' after
restructuring the seam test to assert the differential first:

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +1 -1: the seam join is load-bearing on the circle [E]
  Expected: a value less than <4>
    Actual: <14>
  the reference and resident arms must agree on the seam itself;
  ResidentAgreement(referenceInk: 1498, residentInk: 1484, differing: 14, overEight: 14)
exit=1
```

`differing: 14` matches the coordinator's independently-derived seam-notch
area (14.09 px², the 0.09 rounding away under integer pixel counting) —
corroboration the number is measuring the real geometric defect, not an
artifact. The main corpus test's own bound is untouched by this mutation
(the corpus's circle and arc are large enough that this one seam's notch
doesn't move their pixel counts), which is exactly why the dedicated
small-radius seam test exists as a second, independent probe.

Restored both times from `cp` backups, `diff` confirmed identical.

**Dead. Gate of record: `resident_pixel_differential_test.dart`'s
`the seam join is load-bearing on the circle`, on the differential
assertion specifically (post fix-round reordering).**

---

## M-B4 — flatten circles in collection space rather than local space

**Task 5.** Transformed the circle's centre once and walked a circle of
`deviceRadius` around it, rather than flattening in local space and
transforming each sample.

```
$ flutter test test/gpu/geometry_collector_test.dart test/gpu/collector_differential_test.dart
  Expected: a numeric value within <0.5> of <60>
    Actual: <34.40478706359863>
  test/gpu/geometry_collector_test.dart 508:5

  Expected: a numeric value within <0.001> of <607.2809769386906>
    Actual: <620.758056640625>
  instance 3 x0
  test/gpu/collector_differential_test.dart 163:7

00:00 +19 -2: Some tests failed.
exit=1
```

Under the fixture's `scale(3, 1)`, the mutant draws a circle of one radius
instead of the ellipse the correctly-flattened reference draws — 34.40
where 60 is required, arithmetically exact for a mutant that used the
wrong axis's scale (`deviceRadius = 10 * sqrt(3) = 17.32`,
`2 * 17.32 * 0.9866 ≈ 34.40`, per Task 5's review re-deriving this figure
independently rather than trusting the transcript). The differential
diverges independently at instance 3.

Restored from `/tmp/gc-t5.bak`, md5 matched, `git diff --stat` empty.

**Dead, on both gates.** Gate of record: `geometry_collector_test.dart`'s
ellipse-extent test and `collector_differential_test.dart` (instance 3).

---

## M-B5 — expand the quad at collection scale

**Task 8.** In `test/support/instance_expander.dart`'s stroke branch, the
`halfWidth` read directly from the record (already a device-pixel quantity)
was multiplied by the transform's scale magnitude:

```diff
-    final halfWidth = data[o + InstanceFieldOffset.halfWidth];
+    final halfWidth = data[o + InstanceFieldOffset.halfWidth] * t.scaleMagnitude;
```

```
$ flutter test test/gpu/instance_expander_test.dart
00:00 +6 -1: half-width does not scale with the transform [E]
  Expected: a numeric value within <0.001> of <8>
    Actual: <40.0>
  the width did not
exit=1
```

`40.0` is `8 * 5` — the fixture's `Transform2.scale(5, 5)` leaking into the
width. Red on exactly the predicted test, no other. Restored from
`cp` backup, `diff` confirmed identical, suite re-ran green (`+7`).

**Dead.** Gate of record: `instance_expander_test.dart` — `half-width does
not scale with the transform`.

---

## M-B6 — always miter, never bevel

**Task 8.** The miter-limit guard replaced with an always-true condition:

```diff
-          if (d0x * d1x + d0y * d1y >= kExpanderMinMiterCosine) {
+          if (true) {
```

```
$ flutter test test/gpu/instance_expander_test.dart
00:00 +3 -1: a hairpin turn is bevelled: the tip triangle has zero area [E]
  Expected: a numeric value within <0.0001> of <100.0>
    Actual: <900.02001953125>
  M collapses onto A, so (A, M, B) has no area
exit=1
```

Task 8's review verified this numerically, from source, rather than trusting
the transcript: hairpin gives `cosHalf = 0.005`, `reach = 800`,
`m.x = 900.02` — matching the reported `900.02001953125` to the digit.
Restored from `cp` backup, `diff` confirmed identical, suite re-ran green.

**Dead.** Gate of record: `instance_expander_test.dart` — `a hairpin turn
is bevelled: the tip triangle has zero area`.

---

## M-B7 — flip the join's outer side

**Task 9, two firings — the first exposed the original gate's weakness,
the second is the actual kill.**

```diff
-          final s = crossZ > 0 ? -halfWidth : halfWidth;
+          final s = crossZ > 0 ? halfWidth : -halfWidth;
```

First firing, against the pre-fix-round suite:

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +1 -1: the seam join is load-bearing on the circle [E]
  Expected: a value greater than <1320.0>
    Actual: <1320.0>
  the closed circle has the closing chord and the seam; closed=1320.0 open=1320.0
exit=1
```

Killed, but **only by the seam test's self-consistency probe** — a check
that never reads `referenceInk` or `differing` at all. Task 9's own report
measured the main corpus test's `differing` at 26 under this mutation,
comfortably under the original 1%-of-ink budget (81), so the differential
proper had, at that point, zero demonstrated kills for this mutant. Task 9's
review (Important 1) named this directly: the corpus's entire join
contribution is 26 px, under budget by construction, and deleting
`_emitJoin` outright (M-B15, below) passed the same gate green.

Second firing, after the fix round added `lessThan(4)` and reordered the
seam test's assertions so the differential runs first:

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0 -1: the resident arm draws the reference drawing [E]
  Expected: a value less than <4>
    Actual: <26>
  ResidentAgreement(referenceInk: 8183, residentInk: 8157, differing: 26, overEight: 26)

00:00 +0 -2: the seam join is load-bearing on the circle [E]
  Expected: a value less than <4>
    Actual: <178>
  the reference and resident arms must agree on the seam itself;
  ResidentAgreement(referenceInk: 1498, residentInk: 1320, differing: 178, overEight: 178)
exit=1
```

Now killed by the **differential itself**, on both tests — `differing: 26`
is the exact same number the original probe found; the new bound simply no
longer admits it. Restored from `cp` backup both times, `diff` confirmed
identical.

**Dead. Gate of record: `resident_pixel_differential_test.dart`'s main
corpus test and its seam test, on the `differing` assertion — after the
fix round's bound tightening; the pre-fix-round gate could not have made
this claim on its own.**

---

## M-B8 — treat `point()` as a zero-length capped stroke

**Tasks 6 and 9 — three firings, with a correction between them.**

`point()` rewritten to `writeStroke` a segment from `(x - half, y)` to
`(x + half, y)` instead of `writePoint`:

```diff
-    writePoint(_buffer, _instances,
-        x: t.a * x + t.c * y + t.e, y: t.b * x + t.d * y + t.f, ...);
+    final px = t.a * x + t.c * y + t.e;
+    final py = t.b * x + t.d * y + t.f;
+    final half = _halfWidthFor(style.lineweightHundredths);
+    writeStroke(_buffer, _instances,
+        x0: px - half, y0: py, x1: px + half, y1: py, halfWidth: half, ...);
```

**Task 6, record level:**

```
$ flutter test test/gpu/geometry_collector_test.dart test/gpu/collector_differential_test.dart
.../geometry_collector_test.dart: a point is one instance of its own kind... [E]
  Expected: <2.0>
    Actual: <0.0>
.../collector_differential_test.dart: emits every polyline segment... [E]
  Expected: <2.0>
    Actual: <0.0>
  instance 182 must be a point
exit=0
```

(`exit=0` here is `flutter test`'s process exit for the whole invocation
completing, not a claim the mutation survived — both named tests are listed
under "Failing tests"; the report's transcript is quoted as printed.) Both
failures are `kKindPoint` expected, `kKindStroke` actual — the mutation
caught at the kind tag and independently at the differential.

**Task 9, pixel level — first firing, wrongly reported as a survivor.**
`flutter test test/gpu/resident_pixel_differential_test.dart` passed clean
(`+2: All tests passed!`), and the original report reasoned the two arms
draw "bit-identical" squares under this corpus, from two rotation probes
that in fact only showed no *rotation* the harness could introduce
separates the two arms — not that the arms were identical outright. Task 9's
review caught the gap and demanded the arithmetic be worked through
directly rather than inferred.

**Task 9's fix round, corrected — a real kill.** `GeometryCollector.point()`
correctly stores the collection-space centre and applies `±halfWidth` (a
device quantity) after `collectionToDevice`. The mutation instead computes
`x0/x1` **before** `collectionToDevice`, i.e. it subtracts a device-space
`half` from a collection-space `cx`, and `expandInstances` then applies
`collectionToDevice` to each mutated endpoint independently — doubling the
offset a second time on the corpus's `scale(2, 2)`. Worked through by hand:
`half ≈ 1.88976` device px for the corpus's `point(340, 210, _thick)`,
giving a **7.56 × 3.78 device-pixel rectangle** where both the reference and
the correct resident arm draw a **3.78 × 3.78 square** — exactly the shear
`kKindPoint` exists to prevent, per the collector's own doc.

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0 -1: the resident arm draws the reference drawing [E]
  Expected: a value less than <4>
    Actual: <16>
  ResidentAgreement(referenceInk: 8183, residentInk: 8199, differing: 16, overEight: 16)
exit=1
```

`differing: 16` matches the coordinator's independent hand count (32 pixels
inked across the symmetric difference of the two squares, 16 disagreeing)
almost exactly. Under the *original* 1%-of-ink threshold this would have
survived; under the fix round's `lessThan(4)` it is a kill. The doc comment
that claimed bit-identity was corrected in the same commit.

Restored from `cp` backups on every firing; `diff` confirmed identical
each time.

**Dead — on the record level from Task 6, and, once the analysis was
corrected, on the pixel level too.** Gate of record:
`geometry_collector_test.dart` / `collector_differential_test.dart` (Task 6)
and `resident_pixel_differential_test.dart` (Task 9, corrected).

---

## M-B9 — sort the instance buffer by kind before upload

**Fired in this task.** Not fired by any earlier task; this is the spec's
*"give strokes, joins and fills separate draw calls"* mutation, reduced to
the one buffer this plan actually has.

Backup: `cp lib/src/gpu/geometry_collector.dart <scratch>/gc_t10.bak`, md5
`83f77567826de4359b5e016c1418c7fc` matching on both files.

Exact edit, in `GeometryCollector.data`:

```diff
-  Float32List get data => _buffer.sublist(0, _instances * kFloatsPerInstance);
+  Float32List get data {
+    // M-B9: sort the instance buffer by kind before upload.
+    final flat = _buffer.sublist(0, _instances * kFloatsPerInstance);
+    final records = List<int>.generate(_instances, (i) => i)
+      ..sort((a, b) => flat[a * kFloatsPerInstance]
+          .compareTo(flat[b * kFloatsPerInstance]));
+    final out = Float32List(flat.length);
+    for (var i = 0; i < records.length; i++) {
+      out.setRange(i * kFloatsPerInstance, (i + 1) * kFloatsPerInstance, flat,
+          records[i] * kFloatsPerInstance);
+    }
+    return out;
+  }
```

(`flat[a * kFloatsPerInstance]` is `InstanceFieldOffset.kind`, offset 0 —
this sorts strictly by kind, stroke/join/point, exactly as the brief's
sample code, with `InstanceFieldOffset` imported and already in scope.)

Command: `flutter test test/gpu/geometry_collector_test.dart test/gpu/collector_differential_test.dart`

Verbatim failure (abridged to the load-bearing lines; nine tests went red
in total):

```
00:00 +1 -1: emits one instance per segment, in walk order [E]
  Expected: <1.0>
    Actual: <0.0>
  test/gpu/geometry_collector_test.dart 73:5

00:00 +1 -2: closed: true emits a closing segment back to the first point [E]
  Expected: [1.0, 0.0, 1.0, 1.0]
    Actual: [1.0, 1.0, 0.0, 0.0]
     Which: at location [1] is <1.0> instead of <0.0>
  test/gpu/geometry_collector_test.dart 102:5

00:00 +8 -3: an open three-point run is join-before-segment, and nothing else [E]
  Expected: [0.0, 1.0, 0.0]
    Actual: [0.0, 0.0, 1.0]
  test/gpu/geometry_collector_test.dart 267:5

00:00 +8 -4: the join carries the corner and both its neighbours [E]
  Expected: <0>
    Actual: <40.0>
  test/gpu/geometry_collector_test.dart 293:5

00:00 +8 -5: a closed run emits the closing segment and then the seam join [E]
  Expected: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    Actual: [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]
  test/gpu/geometry_collector_test.dart 315:5

00:00 +8 -6: a repeated point is spanned by the join, not turned into one [E]
  Expected: <0>
    Actual: <40.0>
  test/gpu/geometry_collector_test.dart 354:5

00:00 +11 -8: an arc is an open run and has no seam [E]
  Expected: <0.0>
    Actual: <1.0>
  test/gpu/geometry_collector_test.dart 469:5

00:00 +12 -9: a negative sweep runs clockwise, not mirrored [E]
  Expected: <0.0>
    Actual: <1.0>
  test/gpu/geometry_collector_test.dart 548:5

00:00 +14 -9: .../collector_differential_test.dart: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr [E]
  Expected: a numeric value within <0.001> of <79.58204339388764>
    Actual: <503.868896484375>
  instance 0 x0
  test/gpu/collector_differential_test.dart 210:5

Failing tests:
  .../collector_differential_test.dart: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
  .../geometry_collector_test.dart: a closed run emits the closing segment and then the seam join
  .../geometry_collector_test.dart: a negative sweep runs clockwise, not mirrored
  .../geometry_collector_test.dart: a repeated point is spanned by the join, not turned into one
  ... and 5 more
exit=1
```

This reddens on both fronts the brief predicted: every test in
`geometry_collector_test.dart` that reads raw buffer offsets and expects
walk order (the kind-sequence tests) goes red the moment the buffer is no
longer in walk order, and `collector_differential_test.dart`'s own
walk-order assertion — `instance 0 x0`, expected 79.58 (the first polyline
segment's endpoint, in walk order), actual 503.87 (whatever instance a
stable sort by `kind` happened to put first) — fails directly, independent
of the unit-level failures.

Restore:

```
$ cp <scratch>/gc_t10.bak lib/src/gpu/geometry_collector.dart
$ diff <scratch>/gc_t10.bak lib/src/gpu/geometry_collector.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
$ md5 lib/src/gpu/geometry_collector.dart
MD5 (lib/src/gpu/geometry_collector.dart) = 83f77567826de4359b5e016c1418c7fc
```

Re-ran the two files: `+26: All tests passed!`, exit 0.

**Dead. Gate of record: `geometry_collector_test.dart`'s kind-sequence
tests and `collector_differential_test.dart`'s own order assertion at
line 210.**

---

## M-B10 — emit joins as collector geometry at the collection width

**Fired in this task.** The spec's own wording: *"emit joins as collector
geometry at the collection width → miters distort."* The brief warned this
mutant **may be unkillable at the identity transform**, and instructed:
fire it against the pixel differential; if the existing comparison runs at
the identity, add a scaled arm under a 3x transform and re-fire; report
which of the two happened.

**What actually happened: the mutant died directly, without needing a
scaled arm — because the differential's own comparison never runs at the
identity to begin with.** `gpu_comparison.dart`'s `measureResidentAgreement`
passes `expandInstances` a `collectionToDevice` of
`Transform2.scale(devicePixelRatio, devicePixelRatio)`, and every call site
in `resident_pixel_differential_test.dart` uses `devicePixelRatio: 2.0`.
`Transform2.scaleMagnitude` is `sqrt(|determinant|)`, so for
`scale(2, 2)` that is exactly `2.0`, not `1.0` — the comparison the brief
worried about (`t.scaleMagnitude == 1`, making `halfWidth * t.scaleMagnitude`
a no-op) is not the comparison this suite runs.

Backup: `cp test/support/instance_expander.dart <scratch>/ie_t10.bak`, md5
`99dac061f228bfe680536ca5873d69e4` matching on both files.

Exact edit — a join-local `halfWidth` shadowing the shared one, scoped to
the `kKindJoin` branch only (the stroke and point branches, which read
`halfWidth` from the outer scope, are untouched):

```diff
         final crossZ = d0x * d1y - d0y * d1x;
+        // M-B10: emit joins as collector geometry at the collection width --
+        // halfWidth is already a device-pixel quantity (GeometryCollector's
+        // own doc), so re-scaling it here by the transform's scale magnitude
+        // double-applies the collection-to-device scale for joins only.
+        final halfWidth = data[o + InstanceFieldOffset.halfWidth] * t.scaleMagnitude;
```

Command: `flutter test test/gpu/resident_pixel_differential_test.dart`

Verbatim failure:

```
00:00 +0 -1: the resident arm draws the reference drawing [E]
  Expected: a value less than <81>
    Actual: <95>
  ResidentAgreement(referenceInk: 8183, residentInk: 8278, differing: 95, overEight: 95)
  test/gpu/resident_pixel_differential_test.dart 121:5

00:00 +0 -2: the seam join is load-bearing on the circle [E]
  Expected: a value less than <4>
    Actual: <552>
  the reference and resident arms must agree on the seam itself;
  ResidentAgreement(referenceInk: 1498, residentInk: 2050, differing: 552, overEight: 552)
  test/gpu/resident_pixel_differential_test.dart 231:5

00:00 +0 -2: Some tests failed.
exit=1
```

Killed decisively on both tests — `differing: 95` clears even the loose
1%-of-ink budget (81), and `differing: 552` on the seam test is by far the
largest kill margin in this log (the next largest, M-B7/M-B15's seam
reading, is 178). `expect` stopped at the first failing assertion in each
test (the 1%-of-ink check on the corpus test, the differential check on the
seam test), so the tighter `lessThan(4)` bound never got a chance to report
its own number here, but both already-failed assertions make the verdict
unambiguous.

Restore:

```
$ cp <scratch>/ie_t10.bak test/support/instance_expander.dart
$ diff <scratch>/ie_t10.bak test/support/instance_expander.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
$ md5 test/support/instance_expander.dart
MD5 (test/support/instance_expander.dart) = 99dac061f228bfe680536ca5873d69e4
```

Re-ran `resident_pixel_differential_test.dart` and `instance_expander_test.dart`
together: `+11: All tests passed!`, exit 0.

### The brief's caveat was real, just not triggered by this suite — confirmed with a transcript, not asserted

The brief's warning that this mutant "may be unkillable at the identity
transform" deserved more than a note that it didn't apply here, because the
kill above depends entirely on this suite's own choice of `devicePixelRatio
2.0` — a fact motivated by other tests, not by any deliberate intent to
cover this mutation class. If a future corpus variant ever ran this same
comparison at `devicePixelRatio: 1.0`, `t.scaleMagnitude` would be exactly
`1.0` and the mutation would multiply `halfWidth` by `1.0` — a true no-op,
indistinguishable from correct code by this instrument. Rather than assert
that from the arithmetic alone, it was probed directly: a throwaway test
(never committed — written to `test/gpu/_scratch_mb10_probe_test.dart`,
run once, then deleted) called `measureResidentAgreement` with
`devicePixelRatio: 1.0` against the same mutated `instance_expander.dart`:

```
$ flutter test test/gpu/_scratch_mb10_probe_test.dart
00:00 +0: M-B10 probe at dpr=1.0 (scaleMagnitude=1, functionally identity)
PROBE dpr=1.0: ResidentAgreement(referenceInk: 382, residentInk: 382, differing: 0, overEight: 0)
00:00 +1: All tests passed!
exit=0
```

`differing: 0` — the mutation is genuinely invisible at that scale, exactly
as the brief anticipated, confirming the "identity" caveat is a real
property of this mutation class and not a hypothetical one. The corpus's
own `devicePixelRatio: 2.0` is what saves it here, not a `1.0`-proof design.
**No scaled arm was added to `resident_pixel_differential_test.dart`**,
because the brief's instruction to add one is conditional on the mutant
being unkillable at the comparison the suite actually runs, and it is not:
`differing: 95` and `differing: 552` are both live kills on the committed
suite today. The dpr-dependence is recorded here, in the log, as the
residual risk it is, rather than silently resolved by adding a test the
task's own instructions did not call for once the conditional's premise
turned out false.

**Dead — on the suite as committed, at its own `devicePixelRatio: 2.0`.
Gate of record: `resident_pixel_differential_test.dart`'s corpus test and
seam test. Caveat of record: this kill is scale-dependent, confirmed by a
throwaway probe at `devicePixelRatio: 1.0` (`differing: 0`), and would not
hold if a future variant of this comparison ever ran at an actual unit
scale.**

---

## M-B11 — capture the seam's incoming neighbour before the closing step

**Task 4's fix round.** The review's own named defect: read `_runPrevX/Y`
before the closing `_runTo` call instead of `_runBackX/Y` after it.

```diff
     if (!closed || !_runHasDirection) return;
+    final inX = _runPrevX, inY = _runPrevY; // captured BEFORE the closing step
     _runTo(_runFirstX, _runFirstY, half, argb);
     if (_runSegments >= 2) {
-      _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
-          _runSecondY, half, argb);
+      _emitJoin(_runFirstX, _runFirstY, inX, inY, _runSecondX, _runSecondY,
+          half, argb);
     }
```

New test added first, against the *correct* code, to confirm it is
meaningful before mutating anything (`+15/+16: a closed run whose last
point already repeats the first still finds the last DISTINCT point for the
seam`, then `All tests passed!`). Then the mutation:

```
$ flutter test test/gpu/geometry_collector_test.dart
00:00 +15 -1: a closed run whose last point already repeats the first still finds the last DISTINCT point for the seam [E]
  Expected: <30>
    Actual: <0.0>
  incoming from the last DISTINCT point, not the repeat
  test/gpu/geometry_collector_test.dart 403:5
exit=1
```

Exactly the predicted defect: on a closed run whose raw point list already
repeats its first point at the end, `_runTo`'s zero-length guard makes the
closing step a no-op, so `_runBackX/Y` (read *after* the call, the correct
implementation) still holds the last real point — but `_runPrevX/Y` (read
*before* the call, the mutant) reads the about-to-be-skipped-past vertex
itself.

Restored; `git diff --stat` empty against `HEAD`, md5 matched.

**Dead.** Gate of record: `geometry_collector_test.dart` — `a closed run
whose last point already repeats the first still finds the last DISTINCT
point for the seam`.

---

## M-B12 — `sweep.abs()`, a negative sweep drawn mirrored

**Task 5's fix round.** Task 5's review found every arc in the corpus and
in the unit tests swept positive (fixture arc 703 at +1.9, unit tests at
`2*pi` and `pi/2`), so `sweep / steps` could have been written
`sweep.abs() / steps` and nothing in the suite would have noticed —
`draft_painter.dart` passes the sweep through unnormalised, so a clockwise
arc is representable and would draw mirrored across its start ray.

The fix round's new test sweeps `-pi/2` from `(50, 0)` and requires the run
to end at `(0, -50)`. Firing `sweep.abs() / steps` in place of `sweep /
steps`:

```
Expected: -50
  Actual: 50.0
```

— the mirrored, fourth-quadrant-instead-of-first-quadrant endpoint the new
test exists to catch, exactly as the brief for the fix round predicted.
Restored; the surrounding commit (`733660f`) landed the corrected formula
and the new test together, both doc corrections (`skippedOps`, and the
differential test's stale "b and c are always 0" claim) alongside it.

**Dead.** Gate of record: `geometry_collector_test.dart`'s negative-sweep
arc test.

---

## M-B13 — transpose `to_pixels`

**Task 8's fix round.** Task 8's review found every fixture transform up to
that point was diagonal and translation-free, so both a correctly-ordered
`to_pixels` and a transposed one passed all seven tests — the degenerate
fixture this project's own `CLAUDE.md` names, in the one function where a
drift moves every coordinate.

```diff
-  double toX(double x, double y) => t.a * x + t.c * y + t.e;
-  double toY(double x, double y) => t.b * x + t.d * y + t.f;
+  double toX(double x, double y) => t.a * x + t.b * y + t.e;
+  double toY(double x, double y) => t.c * x + t.d * y + t.f;
```

Against a new fixture with a full-coefficient transform
(`Transform2(2, 0.5, -1, 3, 10, 10)`, every one of `a..f` non-zero and
`b != c`):

```
$ flutter test test/gpu/instance_expander_test.dart
00:00 +7 -1: a stroke under a transform with every coefficient non-zero matches by hand [E]
  Expected: a numeric value within <0.001> of <10.970142500145332>
    Actual: <8.211145401000977>
exit=1
```

The re-review predicted this exact number from the fixture's own
coefficients before comparing (`toY` at B drives to −90 instead of 60,
giving vertex 0 `px = 8.211146` — matching the transcript to six digits).
Restored; the GLSL-source test in the same run stayed green throughout
(no GPU/transform involvement), confirming the failure is scoped to the
one mutated arithmetic path.

**Dead.** Gate of record: `instance_expander_test.dart` — `a stroke under a
transform with every coefficient non-zero matches by hand`.

---

## M-B14 — drop the translation from `to_pixels`

**Task 8's fix round**, same new fixture:

```diff
-  double toX(double x, double y) => t.a * x + t.c * y + t.e;
-  double toY(double x, double y) => t.b * x + t.d * y + t.f;
+  double toX(double x, double y) => t.a * x + t.c * y;
+  double toY(double x, double y) => t.b * x + t.d * y;
```

```
$ flutter test test/gpu/instance_expander_test.dart
00:00 +7 -1: a stroke under a transform with every coefficient non-zero matches by hand [E]
  Expected: a numeric value within <0.001> of <10.970142500145332>
    Actual: <0.9701424837112427>
  Which:  differs by <10.00000001643409>
exit=1
```

Differs by exactly `10.0` — the dropped `e = 10` translation term, and
nothing else moved. Restored; suite re-ran green.

**Dead.** Gate of record: the same `instance_expander_test.dart` test as
M-B13.

---

## M-B15 — delete `_emitJoin` entirely

**Task 9's fix round.** New this round: `_emitJoin` rewritten to a no-op
(no `_reserve`/`writeJoin`/`_instances++`), so *no* join is ever written —
unlike M-B3', which left `_runTo`'s interior joins intact and deleted only
`_endRun`'s closing one.

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0 -1: the resident arm draws the reference drawing [E]
  Expected: a value less than <4>
    Actual: <26>
  ResidentAgreement(referenceInk: 8183, residentInk: 8157, differing: 26, overEight: 26)

00:00 +0 -2: the seam join is load-bearing on the circle [E]
  Expected: a value less than <4>
    Actual: <178>
  ResidentAgreement(referenceInk: 1498, residentInk: 1320, differing: 178, overEight: 178)
exit=1
```

Killed by the differential on both tests, with numbers **identical to
M-B7's** (26 and 178). Re-verified this was not a stale-file artefact by
diffing the mutated file against the pristine backup — the `_emitJoin` body
is genuinely gone for this run. See "The instrument's structural blind
spot" below for why the two mutants read identically.

Restored; `diff` confirmed identical.

**Dead.** Gate of record: `resident_pixel_differential_test.dart`, the same
two assertions as M-B7's second firing.

---

## M-B16 — drop `lineweightScale` from `_coveredArgb`

**The final, whole-branch review's fix wave (post Task 11, pre-merge).**
Not one of the plan's pre-committed mutants — this one was found by a
reviewer reading `_coveredArgb` beside `_halfWidthFor` and noticing the
latter's `lineweightScale` factor is pinned by a dedicated test
(`geometry_collector_test.dart` — `lineweightScale multiplies the logical
width before the clamp`) while the former's has no equivalent. Every
`GeometryCollector` this file and `geometry_collector_test.dart` construct
for a colour assertion omits `lineweightScale`, so it defaults to `1.0` and
the factor is the identity everywhere the two existing gates
(`collector_differential_test.dart`, `resident_pixel_differential_test.dart`)
already looked — deleting it was invisible to both, and to all fifteen
mutants above.

The oracle had to be fixed first: `collector_differential_test.dart`'s own
`_referenceCoveredArgb` did not model `lineweightScale` at all, so it was
given the parameter (mirroring `VerticesDrawSink._coveredArgb`'s own
`lineweightScale *` term) before the new test was written — otherwise a
collector that dropped the factor and an oracle that never modelled it
would still agree, for the wrong reason.

```diff
   int _coveredArgb(int argb, int lineweightHundredths) {
     final deviceWidth = lineweightHundredths /
         100.0 *
         pixelsPerPaperMm *
-        lineweightScale *
         devicePixelRatio;
```

New test, `collector_differential_test.dart` — `fades a hairline stroke by
lineweightScale as well as by dpr, not just the identity default every
other gate in this file exercises` (`pixelsPerPaperMm=kLogicalPixelsPerMm`,
`devicePixelRatio=2.0`, `lineweightHundredths=25`, `lineweightScale=0.2` —
chosen so the unscaled device width, `1.8898` px, sits above
`kMinStrokeDevicePixels` while the scaled width, `0.3780` px, sits below
it and off the `coverage` clamp boundary, so the two arms disagree on a
genuine mid-range alpha rather than a 0/255 coincidence):

```
$ flutter test test/gpu/collector_differential_test.dart
00:00 +2 -1: fades a hairline stroke by lineweightScale as well as by dpr, not just the identity default every other gate in this file exercises [E]
  Expected: a numeric value within <0.51> of <193.0>
    Actual: <255.0>
     Which:  differs by <62.0>
  a collector that dropped lineweightScale from the fade formula would leave this at 255, not 193
exit=1
```

The correct arm fades to alpha 193 (`round(255 * 0.7559...)`); the mutant,
having lost the factor entirely, computes the same device width regardless
of the configured scale and stays above the floor, so it returns the
style's alpha unchanged at 255 — exactly the defect this test exists to
catch. `geometry_collector_test.dart` and `resident_pixel_differential_test.dart`
were re-run against the same mutated file and stayed fully green, confirming
the claim that every existing instrument on this branch is blind to this
factor: it is the new test alone that kills it.

Restored from a `cp` backup (never `git checkout --`); `md5` before
mutating and after restoring matched exactly
(`690b9f918f55df1da84060b1441c9a83`), and `git diff` against the working
tree's pre-mutation state showed only the doc fix from I2 (below), nothing
from the mutation itself.

**Dead.** Gate of record: `collector_differential_test.dart` — `fades a
hairline stroke by lineweightScale as well as by dpr, not just the
identity default every other gate in this file exercises`.

---

## The instrument's structural blind spot

**Not a mutation — a property of `resident_pixel_differential_test.dart`
itself, recorded because it bounds what every pixel-level kill in this log
actually means.**

M-B7 (every join wedge built on the *wrong* side of its corner) and M-B15
(no join ever emitted, at all) produced the *identical* reading on both the
corpus test and the seam test — `differing: 26` and `differing: 178`,
respectively, to the pixel. Task 9's re-review proved this is forced, not
coincidental: both mutants satisfy `differing == referenceInk - residentInk`
exactly, meaning the resident arm's inked set is a **pure subset** of the
reference's in both cases — the resident arm never inks a pixel the
reference didn't already ink.

The reason is geometric. A join wedge, correctly placed, fills the notch on
the *outer* side of a turn — a region neither adjacent segment quad already
covers. A join wedge built on the *wrong* side (M-B7) is wholly invented
geometry sitting on the turn's *interior*, and that region is already
covered by the union of the two adjacent segment quads at that corner —
so the wrong-side wedge contributes **zero new inked pixels**, and the
reading is indistinguishable from having drawn no wedge there at all
(M-B15). Both mutants miss the exact same real ink (the true, uncovered
outer notch) and neither adds any ink the other doesn't already lack.

**The consequence for every kill and every survival recorded above:** this
instrument measures the *symmetric difference of two coverage unions*
(`gpu_comparison.dart`'s own doc, "Draw order is also unmeasured" /
"Geometry added INSIDE the existing footprint is invisible" sections). It
cannot see, by the same argument, any defect that adds triangles entirely
within a footprint already inked by something else — a join emitted on
*both* sides of a corner, a duplicated instance sitting on top of an
existing one, a segment quad that overshoots into its neighbour's, or a
miter tip that over-reaches inward without crossing outside the existing
outline. `sink_comparison.dart` (Plan A's sibling instrument) names this
same class of defect `strayVerticesPixels`; this file has no analogue, and
none of the mutations this plan fired needed one to be caught — but a later
plan that reuses this instrument for a new kind of geometry should not read
a passing `ResidentAgreement` as proof that no interior-overlap defect
exists.

---

## Full gate, this task

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:05 +475: All tests passed!
exit=0

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
exit=0

$ dart format --output=none --set-exit-if-changed .
Formatted 89 files (0 changed) in 0.12 seconds.
exit=0
```

`git status --porcelain` was clean before this document was written (no
`analysis_options.yaml` appeared at any point during either mutation's
firing or restoration); the only change this task makes to the tree is this
document itself. `packages/jet_cad_2d` was not touched.
