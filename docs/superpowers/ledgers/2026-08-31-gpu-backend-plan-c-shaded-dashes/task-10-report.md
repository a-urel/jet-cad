# Task 10 report: the gates

## Stage 1 — control-arm plumbing

`test/support/triangle_rasterizer.dart` gained a test-only `debugDisableDashTest`
field on `TriangleRasterizer` (constructor param, default `false`), which
short-circuits `_fill`'s `hasDash` computation to `false` regardless of the
dash varying passed in. It lives only in `test/support/`, has no counterpart
in `lib/` or `cad_stroke.frag`, and is documented as such.

`test/support/gpu_comparison.dart`'s `measurePaintedAgreement` gained a
matching `debugDisableDashTest` parameter (default `false`), forwarded only to
the resident arm's `TriangleRasterizer` (the reference arm's triangles never
carry dash varyings, so the flag would be a no-op there).

`test/gpu/resident_pixel_differential_test.dart` had a stale comment claiming
"Task 9 gives this file a real dashed arm" -- Task 9's own report says the
opposite ("Task 10's job"). Fixed the comment to point at
`dash_differential_test.dart` instead of leaving a false claim in a file nobody
else was going to touch again this task.

Verified green (see below).


## Stage 2 — the declarative oracle and the record differential

Taken over inline by the controller after the machine slept a third time,
killing the implementer with nothing produced.

`test/gpu/dash_differential_test.dart` created. `_expectedDashInstances` walks
the **painter's op stream** -- `BeginResidualOp`, `BeginDashOp`,
`PolylineOp`, `EndDashOp` -- and derives the expected instance list from
indices and the pattern. There is no run state machine in it: no
`hasDirection`, no previous point. Each polyline op is transformed into
collection space, its zero-length steps dropped by the reference's own
`sqrt(dx*dx + dy*dy) == 0` predicate, and the answer read off the surviving
indices.

It compares kind, both endpoints and the dash quad, and deliberately **not**
half-width or colour -- those are `_halfWidthFor` and `_coveredArgb`'s rules,
gated elsewhere, and folding them in would make a red run ambiguous about
which rule broke.

**Scope, stated rather than discovered later.** The oracle covers polyline
ops only, and the document under test is `shadedDashFixture()` with handles
911 (circle) and 912 (arc) removed by `RemoveEntityCommand`. Deriving a
curve's expected instances means knowing how many chords the collector chose,
and the only way to know that is to reimplement `_flattenSteps` -- which is
transcription, the exact failure this oracle exists to avoid. The oracle
throws `StateError` if it ever meets a `CircleOp` or `ArcOp`, so the scope
cannot silently widen. Curves are gated by `geometry_collector_test.dart`'s
arc tests (running phase, per-chord factor, suppressed seam) and by the pixel
differential.

### A corpus gap this stage's own vacuity check found

The differential passed on its first run, which proves nothing. The vacuity
check beside it did not: **the corpus contained no solid multi-segment run at
all.** Entity 910 is the only multi-segment polyline and it is dashed; every
solid entity was a two-point line with no interior vertex. So "a dashed run
emits no joins" (Ruling C3) was indistinguishable from "this collector never
emits joins" -- the control for the rule was missing.

Fixed by adding **entity 917**, a solid three-point polyline, to
`shadedDashFixture`, with the reasoning in its own comment. This is a Task 3
file amended by Task 10; recorded here rather than silently.

### The kill, fired

```
$ cp lib/src/gpu/geometry_collector.dart <scratchpad>/geometry_collector.dart.bak
# geometry_collector.dart:194
#   before: final n = _dashFracStart.isEmpty ? 1 : _dashFracStart.length;
#   after:  final n = 1; // MUTATION: dash fan disabled for kill-test
$ flutter test test/gpu/dash_differential_test.dart
  Expected: <12>
    Actual: <11>
  the collector must emit exactly one instance per segment per drawn pattern
  element -- neither dropping nor duplicating one
00:00 +1 -1: Some tests failed.
$ cp <scratchpad>/geometry_collector.dart.bak lib/src/gpu/geometry_collector.dart
$ git diff --stat lib/          # empty -- restored byte for byte
$ flutter test test/gpu/dash_differential_test.dart
00:00 +2: All tests passed!
```

**The count reconciles exactly**, which is what makes 12 a derivation rather
than a number the test happened to agree with: 910 dashed, 4 segments x D=1 =
4; 913 DASHDOT, 1 segment x D=2 = 2; 914 ALLGAP, 1 segment x 1 = 1; 915
solid, 1 segment = 1; 916 dashed hairline, 1 segment x 1 = 1; 917 solid, 2
segments + 1 join = 3. Total 12. The mutation costs exactly one instance,
because 913 is the only entity in the corpus with D > 1 -- worth stating,
since it means this particular kill is carried by a single entity.

`flutter analyze` also caught `library_private_types_in_public_api` on the
oracle's own signature; renamed to `_expectedDashInstances`.

## Stage 3 — emission order

Four tests added to `dash_differential_test.dart`:

1. **A primitive's dash instances are consecutive and ascending in cycle
   position.** Not merely "all D are present": a fan emitted in descending
   order, or interleaved across primitives, draws the same pixels today and
   stops doing so the moment a translucent dashed layer exists. The test
   groups instances by identical geometry and asserts `dashFracStart` strictly
   increases inside each group, and it **counts the groups of width > 1** and
   requires at least one -- a corpus with no multi-element fan cannot exercise
   this ordering at all, and entity 913 (DASHDOT) is the only source of one.
2. **Exactly one instance per primitive carries the collapse mark.** Two
   representatives draw a collapsed line twice over itself, which with
   blending on is darker rather than merely wasteful; none makes it vanish.
3. **On a dashed arc the join still precedes its segment.** Plan B's
   intra-entity ordering rule has to survive the element fan. Run on entity
   912 alone, asserting the kind sequence is stroke-first then a strict
   alternation (DASHED has D == 1, so the fan is width 1).
4. **Order survives undo, redo, save, load and purge** -- the buffer compared
   float by float against the baseline, with the failure message naming the
   instance and field index rather than a flat offset.

### A round-trip defect in `packages/jet_cad_2d`, found here and NOT fixed

Test 4's save/load arm failed on its first run: instance 0's `dashPeriod` read
`-6.078470230102539` against a baseline of `-10.333399772644043`. **The ratio
is 1.7000 exactly** -- `shadedDashFixture`'s `globalLinetypeScale`.

Probed directly:

```
encoded header: {units: unitless, scale: 1.0, globalLinetypeScale: 1.7,
                 importedExtents: null, customVariables: {}}
decoded globalLinetypeScale: 1.0
```

**`DraftDocumentCodec.encode` writes the field and `DocumentHeader.fromJson`
parses it back correctly. `json_codec.dart`'s `_loadHeader` then copies only
`units`, `scale`, `importedExtents` and `customVariables` onto the target
document, and drops `globalLinetypeScale` on the floor** -- a one-line
omission at `json_codec.dart:164-168`, two lines below the `fromJson` call
that read the value.

The user-visible consequence: **save a drawing with a non-default global
linetype scale, load it, and every dashed entity in it changes its dash
length.** Nothing caught it before because no save/load test in the engine's
own suite ever set the field to anything but 1.0 -- the degenerate fixture,
in the suite whose own project doc names that as the dominant failure mode.

`packages/jet_cad_2d` is untouched by this plan, so it is **recorded, not
repaired**. The test **pins** it: it asserts the decoded value is 1.0, then
restores 1.7 by hand before collecting. When somebody fixes `_loadHeader`,
that expectation goes red and its `reason` names the hand-restore as the
thing to delete. **This belongs in the results note and in `STATUS.md` as a
defect Plan C found in another package.**

## Stage 4 — the pixel differential, and a plan claim that measured false

The first version of this gate ran on the whole corpus and **failed**:

```
PLAN-C pixel gate: referenceInk=2938 residentInk=2944 differing=146
                   gapPixels=762 controlDiffering=892
```

146 differing against 2938 is 5.0%, over the plan's 1% criterion. Rather than
widen the budget, the disagreement was split by entity:

```
SPLIT all                 ref=2938 res=2944 differing=146
SPLIT no-curves           ref=2232 res=2232 differing=0
SPLIT polyline-910-only   ref=2916 res=2916 differing=0
SPLIT circle-911-only     ref=3758 res=3709 differing=621
SPLIT arc-912-only        ref=2153 res=2174 differing=365
```

**Every one of the 146 pixels comes from the two curve entities. Straight
geometry differs by exactly zero.**

### The plan's claim about curves at ratio 1.0 was wrong

Plan C's Task 10 brief says the four-scale test should "report the arc's
numbers without a threshold" because at ratio *r* the sagitta grows as
`0.25 x r` -- and it says the ratio-1.0 disagreement "must be at the
criterion-1 level". **It is not, and the reason is not the sagitta.** The
reference emits every dash span as its own `arc()` op and re-chords each one
independently (`vertices_draw_sink.dart`), so its chord vertices sit in
different places from the resident arm's, which chords the whole sweep once.
**Different vertices at the same camera** -- a divergence that does not
vanish at ratio 1.0 and never could. Ruling C4 said to record the divergence;
it did not anticipate that ratio 1.0 is already inside it.

### What the gates are now

1. **Straight geometry is pixel-EXACT**: `differing == 0`, not "within 1%".
   For a segment the dash coordinate is a collection-space length ratio and
   the fragment test is a half-open compare on `fract(t)` -- there is no
   approximation anywhere in the chain, so a budget here would have accepted
   a real defect.
2. **The control differs by exactly the gap**: `controlDiffering == 433 ==
   gapPixels`. Disabling the fragment dash test inks every gap the test cuts,
   and nothing else moves.
3. **Curves are measured, not gated** -- circle 16.5%, arc 17.0% of their own
   ink -- with a loose 25% tripwire that is labelled in its own `reason` as
   a tripwire rather than a criterion. The threshold that would bound this is
   the watermark band, and the band belongs to Plan F.

```
PLAN-C straight: referenceInk=2232 residentInk=2232 differing=0
                 gapPixels=433 controlDiffering=433
PLAN-C curve circle 911: referenceInk=3758 residentInk=3709 differing=621 (16.5%)
PLAN-C curve arc 912:    referenceInk=2153 residentInk=2174 differing=365 (17.0%)
```

**For the results note and the exit gate: criterion 1 passes on straight
geometry in its strongest possible form and is REPLACED by a measurement on
curves. That is a miss against the criterion as written, recorded as one.**

## Stage 5 — the four-scale measurement, and the plan's premise corrected

**This stage overturned the sentence Plan C is built on.**

The plan's "What is wrong today" section says a frozen buffer "still shows
eight dashes at 4x zoom instead of the thirty-two the reference draws".
**It does not. The reference draws eight too.**

`DraftPainter._dashScale` is `linetypeScale x globalLinetypeScale x
toScreen.scaleMagnitude`, and the points it hands the dasher are already in
screen space. So the period AND the distance both scale with the camera, and
their quotient -- the number of dashes along an entity -- does not move.
**Dash patterns are anchored in world space, not screen space.** Zooming in
makes each dash longer on screen and leaves their number alone.

Measured three independent ways:

1. `Dasher.dashPolyline` on one segment, points and rate both scaled by `k`:
   **5 spans at every one of k = 1, 2, 4, 8.**
2. The analytic derivation above.
3. A painter probe at four cameras: `dashSpans` reads 80 / 80 / 37 / 22, and
   the fall is entirely **viewport culling** (fewer entities in view), not a
   per-entity change. That probe's real finding is the next line.

### What IS camera-dependent, and it is the thing Plan C actually moved

The same probe reads `collapsed = 1, 1, 0, 0` across those four cameras.
**`kDashCollapsePx` is a screen-space test**, so the collapse decision is the
half of dashing that genuinely moves with the camera -- and a buffer with it
baked in at collection time gets it wrong at every other zoom. That is what
this plan moved into the shader, and it now has its own gate:

```
PLAN-C collapse: period=66.32752990722656 collapsedRuns=1 openRuns=6
```

One buffer. Below `kDashCollapsePx` it draws a single solid run, which is
what the reference draws when `dashPolyline` returns false; above it, the
same buffer draws six. The branch is decided live.

### The four-scale result

```
PLAN-C four-scale dash count (dasher, resident): {0.5: (5, 6), 1.0: (5, 6),
                                                  2.0: (5, 6), 4.0: (5, 6)}
```

**Both arms are invariant, and the resident arm's count is identical at all
four scales** -- asserted exactly (`toSet()` has length 1), which is the
assertion a buffer whose dash coordinate carried any camera term would fail.

The two counts differ by one, consistently. **That is the probe's boundary
behaviour, not a disagreement between the arms**, and the authority on the
arms is the pixel differential in stage 4: `differing == 0` on exactly this
geometry, identical ink pixel for pixel. A count taken by walking a
centreline and a count of spans `Dasher` emits treat a segment's last,
clipped element differently, and reconciling them means re-implementing the
clip. Bounded at `<= 1` and recorded rather than tuned away.

### Two measurement defects found in this stage's own instrument

1. **The first run counter read 92 runs where the truth was 5.** It sampled a
   single rounded pixel along a one-to-two-pixel-wide stroke, so the sample
   drifted off the quad and back: speckle counted as dashes. Fixed with a 3x3
   neighbourhood.
2. **The 3x3 probe then read 6 where the segment has 5**, at every ratio,
   because the segment shares its endpoints with the polyline's neighbours
   and a 3x3 window there reaches into the adjacent segment's ink. Fixed by
   trimming four device pixels off each end -- after which the reading is
   stable at 6 across all four ratios.

A probe run from the repo root instead of the package also produced
`Failed to load ... Does not exist`, the same trap Plan B's ledger records.
