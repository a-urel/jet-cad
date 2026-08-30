# Task 5 — circle() and arc()

**Executed by the controller inline, not by a subagent.** The dispatched
implementer (`a77a685831a0c8d65`) was killed by the machine sleeping three
times, and on the fourth resume it stalled for 50 minutes on a `flutter test`
invocation that never returned (2 tool uses in 685 s). It had, before stalling,
written the four Step-1 tests and the `_flatten` implementation, both of which
survived on disk and are the basis of commit `c9d7f73`. I verified both against
the reference myself rather than inheriting them: see "What I checked in the
inherited work" below.

**Commits:** `c9d7f73`, `c73758e`.

---

## What I checked in the inherited work

The implementation on disk was written by the stalled subagent. Before building
on it I read it against `VerticesDrawSink._flatten` and confirmed all three
properties the brief names, each of which is a defect if wrong:

| property | reference | collector | verdict |
|---|---|---|---|
| flattening space | local, because a non-uniform residual makes an ellipse | local — `cx + r*cos(a)`, then `t.a*lx + t.c*ly + t.e` | matches |
| what the scale decides | the **count** only, via `r * t.scaleMagnitude` | `deviceRadius = r * t.scaleMagnitude`, used only in `_flattenSteps` | matches |
| closed sweep | stops one sample short, `last = closed ? steps - 1 : steps` | identical | matches |
| drives the run machine | `_beginRun`/`_runTo`/`_endRun` | same — does **not** emit segments directly, so joins survive | matches |

The four tests likewise: they fill in `ResolvedStyle`'s four required named
arguments, use `InstanceFieldOffset.*` throughout, and recompute the chord
count from `VerticesDrawSink.kFlattenTolerance` / `kMaxFlattenSegments` rather
than hardcoding today's number.

## Stage 1 — the implementation

First run: **19 passed, 1 failed.**

```
00:00 +19 -1: Some tests failed.

Failing tests:
  .../test/gpu/geometry_collector_test.dart: counts the ops Plan A does not draw instead of dropping them silently
```

That test asserted `circle` + `text` gave `instanceCount 0, skippedOps 2`. A
circle is drawn now, so the assertion was stating something that had become
false. **Rewritten, not weakened**: both assertions are kept and the ops become
`fillCircle` + `text`, chosen because they stay skipped for the whole of Plan B
(fills are Plan D, text is Plan E) — so it does not have to be rewritten again
at Task 6 the way it just was here. The rename drops "Plan A" from the title,
which was also stale.

After the rewrite: **20 passed, exit 0.**

```
00:00 +20: All tests passed!
exit=0
```

Committed as `c9d7f73`.

## Stage 2 — the differential oracle (Ruling B5)

`differentialFixture` carries a circle (handle 701) and an arc (703) which
stopped being `skippedOps` in stage 1, so the oracle's count assertion was
wrong.

**Extended, not weakened.** Two branches added to the op loop for `CircleOp`
and `ArcOp`, each flattening via a new `_flattenedLocalPoints` and handing the
point list to the **existing** `_expectedInstancesFor`. No run-state
bookkeeping was added back — that property cost Task 4 a full fix round.

`_flattenedLocalPoints` derives from the **reference**: it reads
`VerticesDrawSink.kFlattenTolerance` and `kMaxFlattenSegments` live (both
public) and reproduces `_flattenSteps`' expression, the local-space walk, and
the one-sample-short rule. `GeometryCollector` keeps its *own* copies of those
two constants deliberately, so reading the reference's here is what arms the
alarm the collector's doc comment promises: raise either arm out of step with
the other and this test goes red.

### The anti-vacuity check, and why it was necessary

**It passed on the first run after the extension, and that proved nothing** —
my earlier "confirm it red" run had executed from the repo root instead of the
package and died on `Failed to load ... Does not exist`, so no red state had
ever been established. Rather than accept a green run with no red before it, I
disabled both new branches (`if (false && op is CircleOp)`, likewise `ArcOp`)
and re-ran:

```
00:00 +0 -1: emits every polyline segment the painter walks, ... [E]
  Expected: <14>
    Actual: <182>
exit=1
```

**14 against 182**: circle 701 and arc 703 contribute 168 of the 182 instances.
The extension is load-bearing by a wide margin.

Restored from the `cp` backup, `md5 121c3c5fa93bee8eb33a9ede3758b522` matching
on both sides, `grep -c 'if (false &&'` → 0. Restored via `cp`, **never**
`git checkout --`.

Green again after restore, committed as `c73758e`.

### Does circle 701 put the seam limb under the differential gate?

**Yes, and this closes an open note from Task 4's re-review.** That reviewer
recorded that because `differentialFixture` has no closed polyline, the entire
**closed limb** of the declarative rule — the seam arithmetic that cost Task 4
a fix round, and that the controller's own remediation formula got wrong — was
gated only by unit tests and never by the differential comparison. Circle 701
is a closed run, so `_expectedInstancesFor`'s `closed && n >= 3` branch now
executes under this gate, against a real painter walk, on every run.

## M-B4 — flatten in collection space rather than local space

The exact edit: transform the centre once (`ccx`, `ccy`), then walk a circle of
`deviceRadius` around it, replacing both the `_beginRun` seed and the `_runTo`
loop body.

```
flutter test test/gpu/geometry_collector_test.dart test/gpu/collector_differential_test.dart
```

**Killed by both gates.**

```
  Expected: a numeric value within <0.5> of <60>
    Actual: <34.40478706359863>
     Which:  differs by <25.595212936401367>
  test/gpu/geometry_collector_test.dart 508:5

  Expected: a numeric value within <0.001> of <607.2809769386906>
    Actual: <620.758056640625>
     Which:  differs by <13.477079701934372>
  instance 3 x0
  test/gpu/collector_differential_test.dart 163:7

00:00 +19 -2: Some tests failed.
exit=1
```

The ellipse test reads an x-extent of **34.40 where 60 is required** — under
`scale(3, 1)` the mutant draws a circle of some single radius instead of the
ellipse the reference draws. The differential test diverges independently at
instance 3.

Restored from `/tmp/gc-t5.bak`, `md5 91c1059396fdfb199bfa9276701bab9d` matching,
`git diff --stat` empty. **`cp` restore, not `git checkout --`.**

## Defects found in the plan's sample code

**One, and it is the fifth task running to find at least one.**

`ResolvedStyle` requires four named arguments — `argb`, `lineweightHundredths`,
`linetype`, `linetypeScale` — and this plan's test literals supply two. That is
now the third distinct code block of mine carrying the same defect (Tasks 3, 4
and 5). It is mechanical to fix and was fixed in all four tests here.

Nothing else in the brief's sample code was wrong: `_flatten`, `_flattenSteps`,
`circle` and `arc` compile and behave as their comments claim, and the four
tests' arithmetic checks out.

## Gate

See the "Gate output" section appended below, with exit codes.

## Gate output

**The first gate run FAILED, and it failed on the trap this plan names.**

```
Changed test/gpu/collector_differential_test.dart
Changed test/gpu/geometry_collector_test.dart
Formatted 85 files (2 changed) in 0.12 seconds.
FORMAT_EXIT=1
```

`Formatted 85 files (2 changed)` reads like a status line and **is** the
failure — exit 1. That is precisely the misreading that cost Plan A a review
round, and here it caught my own two edits. Recorded rather than silently
fixed.

Tests and analyze were green on that same run:

```
14:24 +459 ~1: All tests passed!
TEST_EXIT=0
No issues found! (ran in 0.7s)
ANALYZE_EXIT=0
```

Formatting applied, then re-verified:

```
Formatted test/gpu/collector_differential_test.dart
Formatted test/gpu/geometry_collector_test.dart
Formatted 2 files (2 changed) in 0.01 seconds.
---
Formatted 85 files (0 changed) in 0.11 seconds.
FORMAT_EXIT=0
```

**Full gate re-run on the formatted tree — the tree actually committed:**

```
00:05 +459 ~1: All tests passed!
TEST_EXIT=0
No issues found! (ran in 0.7s)
ANALYZE_EXIT=0
FORMAT_EXIT=0
```

459 passed, 1 pre-existing suite-level skip (`test/rig/paint_microbench_test.dart`,
skipped by the `rig` tag in `dart_test.yaml`). Suite went 455 -> 459.

`git status --short` empty; no `analysis_options.yaml` appeared at any point,
including after the two stray `flutter pub get` runs a mis-rooted background
command triggered.

## Summary for the reviewer

- Emission order and the run machine are **Task 4's**, unchanged here.
- What is new: `_flatten`, `_flattenSteps`, `kFlattenTolerance`,
  `kMaxFlattenSegments`, `circle()`, `arc()`, four unit tests, and the
  oracle's two new op branches plus `_flattenedLocalPoints`.
- `point`, `fillPolygon`, `fillCircle` and `text` remain `_skipped++`. Task 6
  lands `point`.
- One assertion was rewritten (`counts the ops it does not draw ...`), keeping
  both of its expectations and moving to ops that stay skipped for the rest of
  the plan. Classification: **correct** — it was asserting something the task
  legitimately made false, not something vacuous.
- Every other differential assertion is unchanged; the oracle gained branches
  and gained no bookkeeping.
