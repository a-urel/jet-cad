# Task 9 report: the pixel differential against `VerticesDrawSink`

Commits: `60d5569` and `5596437` on `plan-b/joins-and-hairlines` (base `f01ee5a`).

## Files

- Created `packages/jet_cad_2d_flutter/test/support/gpu_comparison.dart`
- Created `packages/jet_cad_2d_flutter/test/gpu/resident_pixel_differential_test.dart`
- Modified `packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart`
  (Step 5: joins were already handled by an earlier round; this task's own
  work there was routing the colour comparison through a reference-side
  `_coveredArgb` and adding a local hairline fixture)

`packages/jet_cad_2d` was not touched.

## Step 1: what the existing machinery does, and where the brief's sample disagreed

`sink_comparison.dart`'s `AgreementReport` counts, per pixel at device
resolution: `canvasInkPixels` / `verticesInkPixels` (ink above
`kInkAlphaFloor` on the canvas side, non-zero on the vertices side),
`strayVerticesPixels` (vertices ink with no canvas ink within a 3x3
dilation — invented geometry) and `uncoveredCanvasPixels` (the reverse —
missing geometry). It is a **membership** comparison in both directions with
a one-pixel dilation tolerance, not a per-pixel colour distance.

`TriangleRasterizer.observe(Float32List positions, Int32List colors)` and
`bool inked(int x, int y)` both matched the brief's sample exactly — no
divergence there. What *did* disagree with the sample, found while making
the files compile and run:

1. **Missing imports.** Neither `Size`, `PictureRecorder` nor `Canvas` are
   exported through `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` (that
   barrel only re-exports the library's own source files; `vertices_draw_sink.dart`
   *imports* `dart:ui`, it does not *export* it, and `export` does not
   propagate through a plain `import`). Both new files needed an explicit
   `import 'dart:ui';` the sample omitted.
2. **`ResolvedStyle` needs all four named arguments.** The sample's
   `ResolvedStyle(argb: ..., lineweightHundredths: ...)` literals do not
   compile — `linetype` and `linetypeScale` are required too, exactly as the
   task's own "Interfaces from earlier tasks" note warned. Both style
   constants in the test file add `linetype: Handle.none, linetypeScale: 1`.
3. **The transform handling was backwards — this is the substantive one, and
   it is what produced the first failing run below.** See the next section.

## The space mismatch, and the first (genuine) failing run

I built `gpu_comparison.dart` exactly as the brief's Step 2 sample specifies
(only the compile-fixes above applied — no logic changes), ran it against the
corpus, and got:

```
00:00 +0: the resident arm draws the reference drawing
00:00 +0 -1: the resident arm draws the reference drawing [E]
  Expected: a value greater than <5000>
    Actual: <4149>
     Which: is not a value greater than <5000>
  ResidentAgreement(referenceInk: 4149, residentInk: 8223, differing: 4074, overEight: 4074)
```

`differing: 4074` against `referenceInk: 4149` is near-total disagreement,
and `residentInk` is almost exactly double `referenceInk` (8223 / 4149 ≈
1.98 ≈ `devicePixelRatio`) — a strong signal of the "two arms in different
spaces" cause the brief lists first.

Tracing it: `VerticesDrawSink`'s buffer is documented as **logical** pixels
("the buffer is in logical pixels, because that is the space the `Canvas`
this sink flushes into is in") and `_halfWidthFor` returns a **logical**
half-width, computed independently of the residual. The sample's
`sink.beginResidual(Transform2.scale(devicePixelRatio, devicePixelRatio))`
scales the *positions* into device space while the half-width offset added
to them (as a normal, in the same post-residual space) stays logical —
thinning every stroke by a factor of `devicePixelRatio` relative to its
length. `GeometryCollector._halfWidthFor` is the mirror image: it returns an
**already-device**-pixel half-width, independent of the residual, so the
sample's `expandInstances(..., Transform2.identity())` left the collector's
positions in *collection* space while its half-width was already in *device*
magnitude — the opposite mismatch.

The fix (now in `gpu_comparison.dart`): drive both arms at **identity
residual** — the same space the corpus's own raw coordinates are written in —
and apply the device scale *outside* that space to each arm the way each
arm's own space actually wants it:
- the reference: `beginResidual(Transform2.identity())`, then scale the
  **captured triangle positions** by `devicePixelRatio` in the observer,
  after the (logical) half-width has already been added to them — mirroring
  `sink_comparison.dart`'s `_captureVertices` exactly;
- the resident arm: `beginResidual(Transform2.identity())` too, and
  `expandInstances(..., Transform2.scale(devicePixelRatio, devicePixelRatio))`
  as `collectionToDevice`, so the transformed positions land in the same
  device-pixel space the half-width was already measured in.

After that fix, the passing run's actual numbers (captured with a temporary
`print`, then removed before commit):

```
TASK9_PROBE ResidentAgreement(referenceInk: 8183, residentInk: 8183, differing: 0, overEight: 0)
```

Bit-for-bit agreement on the full corpus. No threshold was moved to get
there — the fix was re-deriving the transform, exactly as instructed.

## The fixture requirement from the shader review

Added, per the task instructions (not in the brief's own sample corpus): a
polyline with a repeated interior point —
`[345, 15, 345, 55, 345, 55, 385, 75]` (points 1 and 2 coincide) — so the
pixel gate also covers the case where a join's incoming direction must come
from the last point that actually *moved*, not the raw predecessor. This
mirrors `geometry_collector_test.dart`'s "a repeated point is spanned by the
join, not turned into one" (the Task 4 unit test), now also exercised in
pixels.

## Instrument scope: what this file does and does not measure

`TriangleRasterizer.inked` is `pixels[i] != 0` — a boolean, not a colour
sample; its own doc says as much ("there is no partial coverage to
threshold"). `ResidentAgreement.differing` and `.overEight` in
`gpu_comparison.dart` are therefore **always equal by construction** — I kept
`overEight` as a separate field only so a reader coming from
`sink_comparison.dart`'s `AgreementReport` (whose "differing by more than 2 /
8" fields are genuine per-channel colour distances) finds an honestly-equal
number here rather than a name that used to mean something this rasterizer
cannot measure. **The per-channel half of the design document's criterion 1
is not gated by this file.** It is gated separately by the record-level
`argb` assertions in `geometry_collector_test.dart` and the extended
`collector_differential_test.dart` (Step 5, below).

## Step 5: the collector differential's colour comparison

`collector_differential_test.dart` already handled joins in full (kind
assertion on every instance including joins and points, x0..y2, and
half-width scaled by dpr) before this task — that work landed in an earlier
round on this branch, not in Task 9. What this task's Step 5 actually added:

- `final argb = style.argb;` → `final argb = _referenceCoveredArgb(style.argb, style.lineweightHundredths);`,
  a new reference-side reproduction of `VerticesDrawSink._coveredArgb` (that
  method is private to its own file, so this is a second, independent
  formula, the same pattern `_referenceLogicalHalfWidth` already used for the
  width comparison).
- A **local** hairline fixture, `_hairlineFixture()`, rather than adding an
  entity to the shared `differentialFixture()`. I chose the local-fixture
  option the brief offered explicitly, because `differentialFixture` is
  shared by six other suites (`differential_test.dart`,
  `draft_canvas_test.dart`, `large_coordinate_test.dart`,
  `tile_invalidation_test.dart`, `vertices_differential_test.dart`, plus this
  file) whose entity counts, extents and tile boundaries a new entity could
  quietly move. The local fixture is one hairline `line` entity (lineweight
  5 → about 0.38 device px, fading to ≈75.7% alpha, a mid-range value chosen
  so a wrong-by-a-factor fade formula shows as a wrong number rather than
  agreeing by coincidence at 0% or 100%) inside a rotated, non-uniformly
  scaled group, so it is not the identity-transform degenerate case
  `assertNoIdentityTransforms` exists to rule out elsewhere in the file.
- The body of the original test was extracted into a shared
  `_checkAgainstOracle(DraftDocument doc)` so both the standing corpus and
  the new hairline fixture run through the same oracle rather than a second,
  possibly-diverging copy of it.

Both tests pass on the correct code and — see the mutation transcripts below
— the new hairline test independently kills M-B1' at the record level.

## Mutation transcripts

All four fired against the production files with a `cp` backup, run against
`resident_pixel_differential_test.dart`, then restored — verified byte-identical
by `diff` after every restoration.

```
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak
cp test/support/instance_expander.dart /tmp/ie.bak
```

### M-B3' (seam) — delete the seam-join block in `_endRun`

Mutation: removed the `if (_runSegments >= 2) { _emitJoin(...); }` block from
`GeometryCollector._endRun`.

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +1: the seam join is load-bearing on the circle
00:00 +1 -1: the seam join is load-bearing on the circle [E]
  Expected: a value greater than <1484.0>
    Actual: <1484.0>
     Which: is not a value greater than <1484.0>
  the closed circle has the closing chord and the seam; closed=1484.0 open=1484.0

00:00 +1 -1: Some tests failed.
```

Killed — by the seam-load-bearing test specifically, not the main corpus
test (the corpus's own circle is large enough that its seam notch is
sub-pixel; see the note on M-B7 below and the in-file comment on why the
seam test uses a small radius). Restored:

```
$ cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart
$ diff /tmp/gc.bak lib/src/gpu/geometry_collector.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
```

### M-B7 (join side) — flip `s` in the expander

Mutation: `test/support/instance_expander.dart`,
`crossZ > 0 ? -halfWidth : halfWidth` → `crossZ > 0 ? halfWidth : -halfWidth`.

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +1: the seam join is load-bearing on the circle
00:00 +1 -1: the seam join is load-bearing on the circle [E]
  Expected: a value greater than <1320.0>
    Actual: <1320.0>
     Which: is not a value greater than <1320.0>
  the closed circle has the closing chord and the seam; closed=1320.0 open=1320.0

00:00 +1 -1: Some tests failed.
```

Killed by the same seam test. The main corpus test's `differing` moved from
0 to 26 (confirmed with a temporary probe print, then removed) but stayed
under the 1%-of-`referenceInk` threshold (26 < 81), so it alone would not
have caught this mutation on this corpus — every join wedge the corpus's
circle/arc/hairpin produces at their chosen sizes is individually small.
This is why the "seam is load-bearing" test's own geometry (a small radius,
wide stroke) matters as a second, independent probe rather than a
restatement of the first. Restored:

```
$ cp /tmp/ie.bak test/support/instance_expander.dart
$ diff /tmp/ie.bak test/support/instance_expander.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
```

### M-B8 (point as stroke) — survives, structurally, and here is the proof

Mutation: `GeometryCollector.point()` rewritten to `writeStroke` a segment
from `(cx - half, cy)` to `(cx + half, cy)` instead of `writePoint`.

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +1: the seam join is load-bearing on the circle
00:00 +2: All tests passed!
```

**This mutation survives the pixel instrument, and I want to be precise
about why rather than call it a corpus gap.** `VerticesDrawSink.point()`
draws a point exactly the way the mutation does — "a horizontal segment of
the stroke's own width is a square of it" is the reference's own comment —
and the shader's `kKindPoint` branch (`instance_expander.dart`) builds the
identical axis-aligned square directly in the post-`collectionToDevice`
frame. Under any `collectionToDevice` this instrument can legitimately use
(identity, or `Transform2.scale(devicePixelRatio, devicePixelRatio)` — the
only kinds jet-cad's camera-to-device step actually produces, since the
document/camera side of the pipeline is what carries rotation, not the final
device projection), the two squares come out **bit-identical**, because both
are axis-aligned in the same output frame.

I did not take that on faith — I probed both directions with the correct
(unmutated) code:

- A **rotation baked into the shared upstream residual** (applied identically
  to both arms, `beginResidual`, with `collectionToDevice` left as a pure
  `scale(dpr, dpr)`) — the shape production actually reaches, since nested
  instance/group transforms can rotate document geometry relative to the
  camera: `refInk=256 resInk=256 differing=0`. Agreement — because rotation
  there doesn't change which frame the point-square gets built in relative to
  the other.
- A **rotation baked into `collectionToDevice` itself** (applied as a proper
  affine map to the reference's captured positions too, not the scalar
  multiply `gpu_comparison.dart` uses) — a shape jet-cad's camera never
  actually produces: `refInk=228 resInk=256 differing=84`. Real, large
  disagreement, on the *correct*, unmutated code. This confirms the
  divergence is about which frame `collectionToDevice`'s rotation would
  separate, not about M-B8 specifically, and that using such a transform in
  this harness would make the baseline itself fail for a reason unrelated to
  Plan B's collector logic.

So M-B8 is undetectable by this instrument for a real, structural reason, not
because the corpus is thin. Its actual gate is the record level, and I
confirmed both catch it immediately:

```
$ flutter test test/gpu/collector_differential_test.dart test/gpu/geometry_collector_test.dart
...
00:00 +23 -2: .../geometry_collector_test.dart: a point is one instance of its own kind, at the transformed position [E]
  Expected: <2.0>
    Actual: <0.0>
...
00:00 +25 -2: .../collector_differential_test.dart: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr [E]
  Expected: <2.0>
    Actual: <0.0>
  instance 182 must be a point
```

Restored:

```
$ cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart
$ diff /tmp/gc.bak lib/src/gpu/geometry_collector.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
```

Documented this in the corpus's own doc comment
(`resident_pixel_differential_test.dart`) next to the point bullet, and
committed separately (`5596437`) once the finding was confirmed.

### M-B1' (hairline) — survives, exactly as anticipated

Mutation: `GeometryCollector.polyline()`,
`final argb = _coveredArgb(style.argb, style.lineweightHundredths);` →
`final argb = style.argb;`.

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +1: the seam join is load-bearing on the circle
00:00 +2: All tests passed!
```

Survives — expected, and for the reason the brief names: `TriangleRasterizer`
is coverage-only, and a hairline's alpha fade changes colour, not coverage.
Confirmed its gate is live at the record level (both the pre-existing Task 3
test and this task's new hairline fixture):

```
$ flutter test test/gpu/collector_differential_test.dart test/gpu/geometry_collector_test.dart
...
.../geometry_collector_test.dart: a sub-pixel stroke keeps its pixel and gives up alpha [E]
  Expected: a numeric value within <0.51> of <96>
    Actual: <255.0>
...
.../collector_differential_test.dart: fades a hairline stroke exactly as the reference sink does, not just strokes above the floor [E]
  Expected: a numeric value within <0.001> of <0.7568627450980392>
    Actual: <1.0>
  instance 0 alpha channel
```

Restored:

```
$ cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart
$ diff /tmp/gc.bak lib/src/gpu/geometry_collector.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
```

Did not invent a coverage difference to kill it — the survival is recorded,
with its reason and its gate of record, both in this report and in the test
file's own doc comment.

## What this instrument does and does not measure

**Does measure:** whether the collector's buffer, expanded through the Dart
transcription of the vertex shader, produces the same *ink footprint* as
`VerticesDrawSink`'s own triangles — the geometric shape and extent of every
stroke, join and point, at device resolution, across a corpus chosen so every
named mutation from Tasks 4-8 has a real chance to move a pixel. This is the
first thing in the whole plan that compares the collector's output to a
picture rather than to another set of numbers.

**Does not measure:** per-channel colour agreement (coverage-only
rasterizer — `differing == overEight` always, by construction), any
divergence that only a genuinely rotated `collectionToDevice` would expose
(unreachable in production, and shown above to disagree even on correct
code, so not a legitimate transform for this harness), and anything Task 11's
actual device/GPU run is responsible for. Colour agreement is gated by the
record-level `argb` assertions in `geometry_collector_test.dart` and
`collector_differential_test.dart`; M-B8 specifically is gated by the `kind`
assertions in the same two files.

## Full gate output, verbatim, with exit codes

```
$ cd packages/jet_cad_2d && dart test
...
00:02 +796: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +797: All tests passed!
$ echo "exit=$?"
exit=0

$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ echo "exit=$?"
exit=0

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
$ echo "exit=$?"
exit=0
```

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:05 +473 ~1: .../tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
00:05 +474 ~1: .../tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:05 +475 ~1: All tests passed!
(0 lines matching "[E]"; no "Some tests failed" line anywhere in the log)

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
$ echo "exit=$?"
exit=0

$ dart format --output=none --set-exit-if-changed .
Formatted 89 files (0 changed) in 0.11 seconds.
$ echo "exit=$?"
exit=0
```

`git status --short` after the full gate: clean. No `analysis_options.yaml`
appeared or changed at any point in this task; `git status` was checked
before every commit.

## Everything wrong in the brief's sample code

1. `gpu_comparison.dart`'s sample was missing `import 'dart:ui';` — `Size`,
   `PictureRecorder` and `Canvas` are not reachable through
   `jet_cad_2d_flutter.dart`'s barrel export.
2. `resident_pixel_differential_test.dart`'s sample `ResolvedStyle` literals
   omitted the required `linetype` and `linetypeScale` arguments.
3. The transform handling in `measureResidentAgreement` was backwards on
   both arms: it scaled the sink's residual by `devicePixelRatio` (which
   thins every stroke, since the sink's half-width is logical and
   residual-independent) and left the collector's `expandInstances`
   transform at identity (which under-scales the collector's positions
   relative to its already-device half-width). The fix drives both arms at
   identity residual and applies the device scale on the *far* side of each
   arm's own space — post-hoc on captured positions for the reference,
   via `collectionToDevice` for the resident arm.
4. `collector_differential_test.dart`'s Step 5 description implied the oracle
   still needed to learn about joins from scratch; an earlier round on this
   branch had already taught it that. The actual open work was the colour
   comparison (`_coveredArgb`) and the hairline fixture, both now done.

## Corpus note: the seam-join test's own radius

The brief's Step 3 sample used radius 90 for "the seam join is load-bearing
on the circle." At that radius, `GeometryCollector.kFlattenTolerance` (0.25
device px) keeps every chord's sagitta error, and with it the seam join's own
notch, below what a 1px-granularity coverage rasterizer can register — a
probe across radii 8-90 and lineweights 50-200 found `closed == open`
(`diff = 0.0`) at every combination with lineweight 50, and non-zero only at
a small radius with a wide stroke. I changed the test's geometry to radius 8
with a 200-hundredths-mm stroke (`diff = 14.0` px in the probe), not the
threshold, and said why in the test's own comment.

---

## Fix round 1

FIX_BASE: `5596437`. Commit for this round: `70d0841`.

### What the coordinator's review found, and why it was right

Both findings check out on independent replay:

1. **The main assertion's 1%-of-ink budget (81 px on this corpus) could not
   fail on any defect this plan named.** My own M-B7 probe from the original
   report already measured the corpus's *entire* join contribution at 26 px
   — under budget. The repeated-interior-point fixture
   (`resident_pixel_differential_test.dart:97-101`), added specifically for
   the join-collapse defect, contributes about 2.2 px of that 26 — also
   under budget on its own. And the two mutations that did go red in the
   original round (M-B3', M-B7) both died on `'the seam join is load-bearing
   on the circle'`'s **self-consistency** probe (`residentInk` closed vs.
   open), which never reads `referenceInk` or `differing` at all — it would
   pass even if the resident arm agreed with nothing in the reference. The
   differential proper — reference vs. resident — had zero demonstrated
   kills.
2. **M-B8 is not bit-identical, and the original report's doc comment
   overclaimed.** Worked through below.

### New assertions, and the reasoning for each

`resident_pixel_differential_test.dart`, main test — added, kept the
existing 1% criterion alongside it:

```dart
expect(r.differing, lessThan(4), reason: r.toString());
```

Reasoning (also in the file's own comment): the two arms compute in
different float precisions all the way to the rasteriser — the collector's
record is `Float32List` (about 1.19e-7 relative precision) while
`VerticesDrawSink` computes in `double` throughout. At this corpus's
device-pixel coordinate magnitudes (order 1e2-1e3), the two arms' triangle
vertices can differ by roughly `1e3 * 1.19e-7 ≈ 1.2e-4` device pixels — far
too small to move a pixel's coverage in general, but not exactly zero, and a
pixel whose centre happens to sit within that margin of a triangle edge
could flip `TriangleRasterizer`'s half-open inside test on one side or the
other. `lessThan(4)` admits a couple of such boundary flips as plausible
float32-rounding noise, while staying two orders of magnitude below every
named-mutation kill measured below (14, 16, 26, 178). The measured value on
the correct code is 0 and stays 0 on every run in this round — the bound is
not loosened to admit anything actually observed; it exists so a future 1-2
px drift reads as rounding, not as a new regression this bound was raised to
hide.

`resident_pixel_differential_test.dart`, seam-join test — restructured to
capture the full `ResidentAgreement` for the closed circle (not just
`.residentInk`), with the differential assertion **first**:

```dart
final closedAgreement = measureResidentAgreement(
    (s) => s.circle(80, 220, 8, _wideStroke), ...);
final openInk = measureResidentAgreement(
    (s) => s.arc(80, 220, 8, 0, 6.283185307179586, _wideStroke), ...)
    .residentInk.toDouble();

expect(closedAgreement.differing, lessThan(4), ...);           // now first
expect(closedAgreement.residentInk.toDouble(), greaterThan(openInk), ...); // now second
```

Reasoning for the reorder: `expect` throws on its first failure, so with the
self-consistency check first (the original order), a mutation that breaks
both assertions only ever shows as a self-consistency failure — the
differential assertion never runs and never gets a chance to report. Putting
the differential first means a mutation that breaks the seam is shown
failing the differential specifically, which is what this fix round asked
for.

### Re-fired mutations, each showing which assertion reddened

All four (plus the new M-B15) fired against the production files with a
`cp` backup, run against `resident_pixel_differential_test.dart`, restored,
and verified byte-identical by `diff` after every restoration.

```
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak2
cp test/support/instance_expander.dart /tmp/ie.bak2
```

#### M-B3' (seam) — reddens the differential specifically

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +1: the seam join is load-bearing on the circle
00:00 +1 -1: the seam join is load-bearing on the circle [E]
  Expected: a value less than <4>
    Actual: <14>
     Which: is not a value less than <4>
  the reference and resident arms must agree on the seam itself; ResidentAgreement(referenceInk: 1498, residentInk: 1484, differing: 14, overEight: 14)

  package:matcher                                       expect
  package:flutter_test/src/widget_tester.dart 473:18    expect
  test/gpu/resident_pixel_differential_test.dart 211:5  main.<fn>

00:00 +1 -1: Some tests failed.
```

`differing: 14` on the seam-only draw, matching the coordinator's
independently-computed 14.09 px² almost exactly (the 0.09 px² rounds away
under integer pixel counting). The main corpus test's `differing` bound
(lessThan(4)) is not touched by this mutation — the corpus's own circle and
arc are large enough that this specific seam-notch defect doesn't move their
pixel counts, which is exactly why the dedicated small-radius seam test
exists.

Restored:

```
$ cp /tmp/gc.bak2 lib/src/gpu/geometry_collector.dart
$ diff /tmp/gc.bak2 lib/src/gpu/geometry_collector.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
```

#### M-B7 (join side) — reddens the differential on both tests

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +0 -1: the resident arm draws the reference drawing [E]
  Expected: a value less than <4>
    Actual: <26>
     Which: is not a value less than <4>
  ResidentAgreement(referenceInk: 8183, residentInk: 8157, differing: 26, overEight: 26)

  package:matcher                                       expect
  package:flutter_test/src/widget_tester.dart 473:18    expect
  test/gpu/resident_pixel_differential_test.dart 141:5  main.<fn>

00:00 +0 -1: the seam join is load-bearing on the circle
00:00 +0 -2: the seam join is load-bearing on the circle [E]
  Expected: a value less than <4>
    Actual: <178>
     Which: is not a value less than <4>
  the reference and resident arms must agree on the seam itself; ResidentAgreement(referenceInk: 1498, residentInk: 1320, differing: 178, overEight: 178)

  package:matcher                                       expect
  package:flutter_test/src/widget_tester.dart 473:18    expect
  test/gpu/resident_pixel_differential_test.dart 211:5  main.<fn>

00:00 +0 -2: Some tests failed.
```

Now killed by the **differential** on both tests: the main corpus test's
`differing: 26` (this is the exact same number the original report's probe
found — the earlier 1%-of-ink budget of 81 simply admitted it; the new bound
of 4 does not), and the seam test's `differing: 178`, an order of magnitude
above the seam test's own single-notch reading — consistent with the r=8
circle having several chords, each with its join now on the wrong side.

Restored:

```
$ cp /tmp/ie.bak2 test/support/instance_expander.dart
$ diff /tmp/ie.bak2 test/support/instance_expander.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
```

#### M-B15 (join deletion outright) — new this round, reddens the differential

Mutation: `GeometryCollector._emitJoin` rewritten to a no-op — no
`_reserve`/`writeJoin`/`_instances++` — so **no join is ever written**, not
only the seam's (unlike M-B3', which left `_runTo`'s interior joins intact
and only deleted `_endRun`'s closing one).

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +0 -1: the resident arm draws the reference drawing [E]
  Expected: a value less than <4>
    Actual: <26>
     Which: is not a value less than <4>
  ResidentAgreement(referenceInk: 8183, residentInk: 8157, differing: 26, overEight: 26)

  package:matcher                                       expect
  package:flutter_test/src/widget_tester.dart 473:18    expect
  test/gpu/resident_pixel_differential_test.dart 141:5  main.<fn>

00:00 +0 -1: the seam join is load-bearing on the circle
00:00 +0 -2: the seam join is load-bearing on the circle [E]
  Expected: a value less than <4>
    Actual: <178>
     Which: is not a value less than <4>
  the reference and resident arms must agree on the seam itself; ResidentAgreement(referenceInk: 1498, residentInk: 1320, differing: 178, overEight: 178)

00:00 +0 -2: Some tests failed.
```

Killed by the differential on both tests, with numbers **identical** to
M-B7's (26 and 178). Re-verified this was not a stale-file artefact — `diff`
against the pristine backup confirms the `_emitJoin` body is genuinely gone
for this run (shown below). The coincidence has a plausible geometric
explanation I did not chase further: a join drawn on the *wrong* side (M-B7)
fills a wedge on the turn's *interior*, a region the two adjacent stroke
quads already cover at a corner — so a wrong-side join and no join at all
can leave the same pixels uninked on the true (exterior) notch, differing
only in whether a redundant, already-covered interior wedge gets drawn on
top. Both mutations miss the same real ink; that is enough to establish the
kill, which is what this task needed.

```
$ diff /tmp/gc.bak2 lib/src/gpu/geometry_collector.dart
227,240c227,228
<     // No collinearity test here, deliberately: the bevel/miter/collinear
<     // decision belongs to the shader, in device pixels, where the reference
<     // makes it too. See this plan's Ruling B4.
<     _reserve(_instances + 1);
<     writeJoin(_buffer, _instances,
<         vx: vx,
...
<     _instances++;
---
>     // M-B15: _emitJoin deleted outright -- no join is ever written, not
>     // just the seam's.
```

Restored:

```
$ cp /tmp/gc.bak2 lib/src/gpu/geometry_collector.dart
$ diff /tmp/gc.bak2 lib/src/gpu/geometry_collector.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
```

#### M-B8 (point as stroke) — corrected: not bit-identical, now a kill

**The original report's claim that the two arms draw bit-identical squares
was wrong.** I had shown (via two rotation probes) that no *rotation* the
harness could legitimately introduce would separate them, and jumped from
"no rotation separates them" to "bit-identical" without re-deriving the
non-rotated arithmetic directly. Working it through, as the coordinator
did:

`GeometryCollector.point()`'s correct path stores just the collection-space
centre `(cx, cy)` in the record; `expandInstances`'s `kKindPoint` branch
applies `collectionToDevice` to that centre alone and adds `±halfWidth`
(already a **device**-space quantity — `_halfWidthFor`'s own doc) directly
in the output frame, giving a true square.

The M-B8 mutation instead computes `x0: cx - half, y0: cy, x1: cx + half,
y1: cy` **before** `collectionToDevice` runs — subtracting a device-space
`half` from a collection-space `cx`. For the corpus's `point(340, 210,
_thick)` (lineweight 50, `ppmm ≈ 3.7795`, `dpr = 2`): `half ≈ 1.88976`
(device magnitude), so the mutated endpoints are `340 ∓ 1.88976` in
collection space. `expandInstances` then applies `collectionToDevice =
scale(2, 2)` to each endpoint independently: `676.22 → 683.78` — a **7.56 ×
3.78 device-pixel rectangle** (the half-width offset gets doubled a second
time by the very transform it was supposed to already be past), against the
reference's and the correct resident arm's **3.78 × 3.78 square**. This is
exactly the shear `kKindPoint` exists to prevent
(`geometry_collector.dart:284-289`'s own doc: "that `± half` is a device
quantity and this record holds collection space").

Re-ran with `differing` actually observed this time, rather than reading a
passing run as proof of bit-identity:

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +0 -1: the resident arm draws the reference drawing [E]
  Expected: a value less than <4>
    Actual: <16>
     Which: is not a value less than <4>
  ResidentAgreement(referenceInk: 8183, residentInk: 8199, differing: 16, overEight: 16)

  package:matcher                                       expect
  package:flutter_test/src/widget_tester.dart 473:18    expect
  test/gpu/resident_pixel_differential_test.dart 141:5  main.<fn>

00:00 +0 -1: the seam join is load-bearing on the circle
00:00 +1 -1: Some tests failed.
```

`differing: 16`, matching the coordinator's hand count (32 pixels inked
across the two arms' symmetric difference, 16 of them disagreeing) almost
exactly. **Under the original 1%-of-ink threshold (81) this survived; under
the new `lessThan(4)` bound it is a kill.** The doc comment in
`resident_pixel_differential_test.dart` (the point bullet in `_corpus`'s doc)
and this report's own M-B8 section have both been corrected — see the diff
in commit `70d0841` for the exact replaced text. The survivor list drops to
one: M-B1', reasoned correctly the first time.

Restored:

```
$ cp /tmp/gc.bak2 lib/src/gpu/geometry_collector.dart
$ diff /tmp/gc.bak2 lib/src/gpu/geometry_collector.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
```

#### M-B1' (hairline) — re-confirmed survivor, unchanged reasoning

Re-fired against the new tight bound to make sure it didn't accidentally
become detectable:

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +1: the seam join is load-bearing on the circle
00:00 +2: All tests passed!
```

`exit=0` — still survives, for the reason recorded in the original report:
`TriangleRasterizer.inked` is coverage-only, and an alpha fade with no
coverage change is invisible to it by construction. Its gate of record is
unchanged: `geometry_collector_test.dart`'s "a sub-pixel stroke keeps its
pixel and gives up alpha" and `collector_differential_test.dart`'s hairline
fixture.

Restored:

```
$ cp /tmp/gc.bak2 lib/src/gpu/geometry_collector.dart
$ diff /tmp/gc.bak2 lib/src/gpu/geometry_collector.dart && echo "IDENTICAL - restored cleanly"
IDENTICAL - restored cleanly
$ diff /tmp/ie.bak2 test/support/instance_expander.dart && echo "IE IDENTICAL"
IE IDENTICAL
```

### Minors addressed

- The seam test's "the closed circle has the closing chord and the seam"
  comment now says what it actually measures: both draws include a
  closing-length chord (the open arc's own final `_runTo` lands near, not
  exactly on, the start angle, since it is `start + sweep` computed
  independently rather than a zero-length skip back to point 0) — only the
  closed draw adds the seam join on top of it, which is why M-B3'/M-B7/M-B15
  all read the closed circle's ink exactly equal to the open one rather than
  leaving a smaller chord-sized residue.
- `gpu_comparison.dart`'s "does not measure" list now names draw order:
  `TriangleRasterizer._fill` is last-write-wins over coverage with no depth
  test, so any permutation of emission order that preserves the union of
  triangle footprints is invisible to this instrument; draw order can only
  be pinned by a record-order assertion, never by pixels.
- `_referenceCoveredArgb`'s doc now notes that only its guard
  (`kMinStrokeDevicePixels`) is read live off the reference; its fade slope
  (`* 2`) is a separate literal that happens to equal `2 /
  kMinStrokeDevicePixels` only because the floor is `1.0` today, and would
  go silently stale if the floor changed, unlike
  `_referenceLogicalHalfWidth`'s floor which tracks the live constant in
  both places.

### Full gate output, verbatim, with exit codes

```
$ cd packages/jet_cad_2d && dart test
...
00:02 +796: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +797: All tests passed!
$ echo "exit=$?"
exit=0

$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ echo "exit=$?"
exit=0

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
$ echo "exit=$?"
exit=0
```

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:05 +473 ~1: .../tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:05 +474 ~1: .../tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:05 +475 ~1: All tests passed!
(0 lines matching "[E]"; no "Some tests failed" line anywhere in the log)

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
$ echo "exit=$?"
exit=0

$ dart format --output=none --set-exit-if-changed .
Formatted 89 files (0 changed) in 0.12 seconds.
$ echo "exit=$?"
exit=0
```

`git status --short` after the full gate and after the commit: clean. No
`analysis_options.yaml` appeared or changed at any point in this round;
checked before every commit.

### Updated survivor list

Only **M-B1'** (hairline alpha fade) survives this instrument now, for the
reason recorded above and in the original report — a coverage-only
rasterizer structurally cannot see an alpha-only change. Its gate of record
is the two record-level tests named above. Every other named mutation
(M-B3', M-B7, M-B8, and the new M-B15) now reddens the pixel differential
assertion specifically, not merely a self-consistency probe.
