# Plan 3b mutation log

**Verdict: twenty-four mutants accounted for.** Twelve were killed by tests
already in the suite before this task, verified independently by their
task's reviewer and recorded here rather than re-run. Of the twelve run in
this task, seven were killed by tests that already existed and five survived
their first run; each of those five was closed with a new test, confirmed to
kill the mutant, then the mutant was reverted. Nothing was found equivalent —
every mutant named in the task-11 brief and every one this task added beyond
it turned out to be a real, distinguishable behaviour.

Baseline before this task's mutants: `jet_cad_2d` 665 tests, `jet_cad_2d_flutter`
120 passed / 1 skipped (including 8 goldens), both green. Each mutant below was
applied to the source by hand, the narrowest test file(s) that could plausibly
catch it were run, and the source was restored with `git checkout --` before
the next one — confirmed by `git status --short` between mutants. Final state:
`jet_cad_2d` 667 tests, `jet_cad_2d_flutter` 123 passed / 1 skipped, both green,
`dart format` and `dart analyze` clean in both packages and `apps/dev_harness_2d`.

## Part 1: already recorded done (not re-run)

These were applied and killed during their own tasks (6–11), each verified by
a reviewer independent of the implementer. Per instructions, they are recorded
here with their evidence and were not re-run.

| # | Mutant | Killed by | Observed |
|---|---|---|---|
| A1 | `_dashSegment` uses `from = 0` instead of `_range[0] * length` | `the phase is carried from the true start` | fails |
| A2 | `cursor = 0` in the polyline walk | `a long segment clipped to a small window costs few pattern steps` | 3556 steps against a bound of 20 |
| A3 | the cycle taken from `pattern.totalLength` | `a totalLength that disagrees with the dashes does not change the output` | `[40,52]` where honest tiling gives `[40,48]` |
| A4 | `cursor = 0` in the arc walk | the arc step-bound test | 2619 steps against a bound of 15 |
| A5 | the straddling window walked as one range | `a window straddling the arc start emits on both sides of it` **and** the completeness test | `above == 0`; drawn total 67.56 against 133.55 ± 24 |
| A6 | the line `_dashScale` drops `toScreen.scaleMagnitude` | `the instance scale multiplies the on-screen dash length` | ratio 1.0 where 2.0 expected |
| A7 | the curve `scale` gains `toScreen.scaleMagnitude` | `the instance scale does not change a curve's dash pattern` | 5 spans against 3; 4 against 2 on the centred camera |
| A8 | `_localClipFor` pulls back through `toScreen` instead of `chain` | `rebasing does not clip a dashed curve out of its own frame` | 3 spans against 35 |
| A9 | `dashArc` ignores `pixelScale` in the collapse test | the `pixelScale` unit test | fails |
| A10 | the painter drops its `pixelScale:` argument | the painter-level collapse test | `collapsedDashCount` 0 where 1 expected |
| A11 | the continuous linetype's pattern made non-empty | `the differential fixture is entirely continuous` | fails |
| A12 | the rig's forced repaint removed | the `canvasCallCount == 0` guard | `Bad state: no repaint happened` |

## Part 2: run in this task

The task-11 brief's table names thirteen mutants (rows 1, 2, 2b, 3–12); rows
1, 2, 2b, and the line half of 5 are A1–A3/A6 above and were skipped. The
remaining nine are B1–B9 below. Three more (B10–B12) were added because
running B2 and B8 raised the question "is the sibling call site covered
too?", and it was not.

| # | Mutant | File | Killed by | Observed |
|---|---|---|---|---|
| B1 | `period < collapsePx` → `<=` in `dashPolyline` | `dasher.dart` | **survived** → new test `a period exactly at the floor does not collapse` | `Expected: non-empty / Actual: []` |
| B2 | the line-path `_dashScale` drops `globalLinetypeScale` | `draft_painter.dart` | `globalLinetypeScale multiplies it too` (existing) | `Expected: a value less than <21> / Actual: <21>` |
| B3 | the pattern restarts per polyline rather than per vertex | `dasher.dart` | `the pattern restarts at every vertex` (existing) | span `[1]` is `<6.0>` instead of `<0.0>` |
| B4 | `circleClipWindows` returns `-1` unconditionally | `segment_clip.dart` | 8 existing tests, including `a circle wholly outside the clip emits nothing` and `a large circle clipped to a small window costs few pattern steps` | e.g. step count 3491 against a bound of 15; non-empty spans where the clip excludes the whole circle |
| B5 | the clip inflation set to `0` | `draft_painter.dart` | **survived** → new test `a dashed stroke whose centreline sits one pixel outside the raw viewport still emits a span there` | `Expected: non-empty / Actual: []` |
| B6 | `_localClipFor` returns `_rebasedClip` unconditionally (skips the pullback) | `draft_painter.dart` | `the instance scale does not change a curve's dash pattern` **and** `rebasing does not clip a dashed curve out of its own frame` | both tripped their own sanity guard: `0` spans where `>3`/`>30` expected |
| B7 | `DocumentHeader.globalLinetypeScale` defaults to `0.0` | `header.dart` | `globalLinetypeScale round-trips and defaults to 1` (existing) — **not** the brief's predicted killer, see note below | `Expected: <1.0> / Actual: <0.0>` |
| B8 | the painter routes circle/arc through `_emitScreenSpace` | `draft_painter.dart` | three tests in `lineweight_test.dart`'s `curves cannot be bypassed` group — **not** the golden, see note below | `screenSpaceLeafCount`/`anisotropicCurveCount` off by exactly the misrouted count, e.g. `Expected: <0> / Actual: <1>` |
| B9 | `_emitSpan` writes to `_span` but the painter passes `_points` | `draft_painter.dart` | `dash_ladder_golden_test.dart` rungs 1–3 (existing) **and** new test `a dashed stroke whose centreline sits one pixel outside...` — see note below | golden: 0.89%–a few % pixel diff on rungs 1–3; new test: `Expected: non-empty / Actual: []` |
| B10 | `dashArc`'s own collapse check, `period * pixelScale < collapsePx` → `<=` (arc twin of B1) | `dasher.dart` | **survived** → new test `a screen period exactly at the floor does not collapse` | `Expected: true / Actual: false` |
| B11 | the circle-kind inline dash scale drops `globalLinetypeScale` (separate call site from B2 — `_emit`'s `EntityKind.circle` case) | `draft_painter.dart` | **survived** → new test `globalLinetypeScale multiplies a curve's dash pattern too` | `Expected: a value less than <7> / Actual: <7>` |
| B12 | the arc-kind inline dash scale drops `globalLinetypeScale` (a *third*, separately written call site — `_emit`'s `EntityKind.arc` case) | `draft_painter.dart` | **survived** → new test `globalLinetypeScale multiplies an arc entity's dash pattern too` | `Expected: a value less than <7> / Actual: <7>` |

Nine mutants (B1, B2, B3, B4, B5, B6, B7, B8, B9) were the ones named or
implied by the task-11 brief and the orchestrator's "at minimum" list. Three
(B10, B11, B12) were found by asking, for each duplicated call site, whether
its sibling was independently covered — it was not, twice.

### Why B7 is not caught the way the brief predicted

The brief's row 10 names `a document written before the field reads back as
1` as B7's killer. That test does catch a *different* mutant (the `?? 1.0`
fallback inside `DocumentHeader.fromJson` being dropped or changed) but not
this one: `fromJson`'s missing-key fallback is a separate hardcoded `1.0`
literal, independent of the field's own initializer. Mutating only the field
default leaves that test computing `DocumentHeader().toJson()` from a header
whose in-memory field is already `0.0`, then stripping the key and reading
`fromJson`'s own unrelated `?? 1.0` back out — which still reads `1.0`,
masking the mutant entirely. It survived a run against that exact test before
`globalLinetypeScale round-trips and defaults to 1` was tried, which asserts
the field's default directly and catches it.

### Why B8 is not caught the way the brief predicted

The brief's row 11 names the golden `anisotropy_bypass.png` as B8's killer.
That golden's fixture (`anisotropicFixture` in
`stroke_width_golden_test.dart`) is built entirely from `_addLine` calls —
no circle, no arc — so a mutation to how circles/arcs are routed has nothing
to act on there; the golden passed unchanged under this mutant. It is
`lineweight_test.dart`'s `curves cannot be bypassed` group — which does
place circle and arc entities under an anisotropic transform — that catches
it, three times over.

### Why B9 needed a new test despite the brief's confidence

The brief predicted "any dashed painter test — spans would carry the whole
polyline." Running the mutant against the full `draft_painter_test.dart`
file (before B5's new test existed) showed the opposite: every existing
dashed-line test in that file passed. The reason is coincidental but exact:
with `count` still hardcoded to `2` at the `sink.polyline(_points, 2, ...)`
call, every emitted "span" carries the same four numbers —
`_points[0..3]`, the *first* two vertices of the leaf's whole screen-space
polyline — rather than the individual dash's endpoints. For a two-point line
entity that pair *is* the entity's own endpoints, so:
- the span count and each span's length-4 shape are unaffected (`a dashed
  entity reaches the sink as many spans, not one polyline` passes),
- and `the instance scale multiplies the on-screen dash length` still reports
  the exact expected `2.0` ratio, because doubling the placement scale
  doubles the *whole original line's* endpoints in the same proportion a
  correctly-computed dash span's length would have scaled by.

Only a test that checks a span's coordinates against a value that could not
also describe the entity's first two vertices — the golden's rendered pixels,
or B5's `outside`-leg filter (which checks for an `x` value that never
appears in the fixture's first vertex pair) — can tell the two apart. This is
recorded as its own finding, not folded into B5: it is a distinct code
location, and it demonstrates that "any test with dashed geometry" is not
evidence of coverage — the specific value being asserted matters.

## Closing section: mutants only one test catches

Per the log format's own convention, these are the tests nobody may delete
without replacing — each is the *only* test (or, where noted, the only test
per package before this task, now the only *pre-existing* one) that
distinguishes the mutant from correct behaviour:

- A1 `the phase is carried from the true start`
- A2 `a long segment clipped to a small window costs few pattern steps` — and per its own doc comment, no output-only test ever could
- A3 `a totalLength that disagrees with the dashes does not change the output`
- A4 the arc step-bound test
- A6 `the instance scale multiplies the on-screen dash length`
- A7 `the instance scale does not change a curve's dash pattern`
- A8 `rebasing does not clip a dashed curve out of its own frame`
- A9 the `pixelScale` unit test
- A10 the painter-level collapse test
- A11 `the differential fixture is entirely continuous`
- A12 the `canvasCallCount == 0` guard
- B1 `a period exactly at the floor does not collapse` (new)
- B2 `globalLinetypeScale multiplies it too`
- B3 `the pattern restarts at every vertex`
- B5 `a dashed stroke whose centreline sits one pixel outside the raw viewport still emits a span there` (new)
- B7 `globalLinetypeScale round-trips and defaults to 1`
- B9, before this task: `dash_ladder_golden_test.dart`'s rungs 1–3 were the *only* thing standing between this mutant and a green suite — every value-checking test in `draft_painter_test.dart` was coincidentally blind to it (see above). It now has a second, non-golden witness.
- B10 `a screen period exactly at the floor does not collapse` (new)
- B11 `globalLinetypeScale multiplies a curve's dash pattern too` (new)
- B12 `globalLinetypeScale multiplies an arc entity's dash pattern too` (new)

B4, B6, and B8 are each caught by multiple tests (eight, two, and three
respectively) and are not single points of failure.

## Reproducing

Each row in Part 2 was produced by replacing the named expression, running
`dart test` in `packages/jet_cad_2d` (B1, B3, B4, B7, B10) or `flutter test`
in `packages/jet_cad_2d_flutter` (B2, B5, B6, B8, B9, B11, B12) against the
narrowest test file(s) that could plausibly catch it, then restoring the file
with `git checkout --` and confirming `git status --short` was empty before
the next mutant. Final state: `jet_cad_2d` 667 tests / 0 failed,
`jet_cad_2d_flutter` 123 passed / 1 skipped / 0 failed (including 8 goldens),
`dart format --output=none --set-exit-if-changed .` and `dart analyze` clean
in both packages and `apps/dev_harness_2d`.
