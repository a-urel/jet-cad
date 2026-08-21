# Task 14 report: goldens and the opaque agreement floor

## The fixture

`packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart`,
`fillLadderFixture()`. One document, four regions, all inside a
`[-50, 50]` world box so half-span 60 frames the whole drawing:

| region | quadrant | boundary | property it carries |
|---|---|---|---|
| L-shape, blue fill `0x3366CC` | bottom-left | `(-50,-10)→(-50,-50)→(-10,-50)→(-10,-30)→(-30,-30)→(-30,-10)` | **concave**: vertex 0 is chosen so the chord from it to the notch's far corner (`(-50,-10)→(-10,-30)`, passing through `(-30,-20)`) crosses *outside* the polygon — a fan from vertex 0 is not star-shaped here and overfills the notch; ear-clipping never proposes that triangle |
| square, green fill `0x33CC33` | bottom-right | `(10,-50)→(10,-10)→(50,-10)→(50,-50)`, signed area negative | **clockwise**: only fills if winding normalisation reverses it before ear-clipping (which assumes CCW) |
| circle, orange fill `0xCC6633`, r=15 | top-left | circle boundary | **circle**: never triangulated ahead of time, fanned per frame at the stroke's own step count — the one property that is scale-dependent, which is why there are 3 rungs |
| square, purple fill `0x9933CC` | top-right | `(10,10)→(50,10)→(50,50)→(10,50)` | **hairline**: the *fill* entity (not its boundary) sits on a layer with lineweight 1 (0.01 mm) via `kByLayer`; boundary stays on layer 0. Built with `AddRegionCommand`'s raw constructor, not `.allocate`, because `.allocate` gives both halves the same `layer` and hard-codes the fill's own lineweight to `kLineweightDefault` |

Every fill's colour differs from its black boundary stroke — covers the
fifth property (an inverted fill/boundary handle order would be visible)
across all four regions rather than one dedicated shape.

Three rungs, half-spans `60.0`, `400.0`, `4000.0`, both backends — 6 tests.

## What I saw when I opened the PNGs

Rung 1 (half-span 60, both `fill_ladder_1.png` and
`vertices/fill_ladder_1.png`): all four shapes render clearly and
identically in composition between backends. The L's notch is correctly
unfilled (an "L" outline, not a solid square). The clockwise square fills
solid green — proof winding normalisation runs. The circle is round, not a
polygon. All four fills are visibly opaque and distinct in hue from their
black boundary strokes; the purple hairline-layer square is exactly as
opaque as the others, with no dimming.

Rung 2 (half-span 400): the same four shapes, much smaller (roughly a
sixth of the frame), still individually distinguishable with the same
colours and the L's notch still visible at this scale.

Rung 3 (half-span 4000): a single few-pixel black speck near the centre on
both backends (fill colour saturation is lost at this scale — the black
boundary strokes dominate the handful of inked pixels). Satisfies the
non-vacuity assertion; not useful for visually judging shape correctness,
which is what rungs 1 and 2 are for.

## Suite output

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:03 +272 ~1: All tests passed!

$ flutter test --tags golden
...
00:02 +29: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)

$ dart format --output=none --set-exit-if-changed .
Formatted 47 files (0 changed) in 0.08s

$ cd packages/jet_cad_2d && CI=true dart test
...
00:03 +771: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.19s
```

(`~1` in the flutter run is `draft_painter_recursion_test.dart`'s
pre-existing skip, unrelated to this task.)

## The opaque agreement row

`packages/jet_cad_2d_flutter/test/support/sink_comparison.dart`: added
`fillComparisonDoc()` — a solid pentagon (`0x3366CC` fill / black
boundary) and a solid circle (`0xCC6633` fill / black boundary), both
comfortably above the ink alpha floor, deliberately not a plain rectangle
so the ear-clipped triangulation and the circle's fan are both actually
exercised.

`packages/jet_cad_2d_flutter/test/sink_comparison_test.dart`: added `'the
two sinks agree on an opaque fill'`, per the brief's Step 4, adapted to
this file's existing `paintDrawing(doc, index)` wiring rather than a bare
`drawAll` name.

Measured (`kInkAlphaFloor = 0xC0`, `devicePixelRatio` 3.0 on this
binding):

```
canvasInkPixels    = 377858
verticesInkPixels  = 377856
strayVerticesPixels    = 0   ->  0 / 377858 = 0.0000%   (floor: <= 1%)
uncoveredCanvasPixels  = 0   ->  0 / 377858 = 0.0000%   (floor: <= 1%)
```

`canvasInkPixels` (377858) clears the 4000 non-vacuity floor by close to
two orders of magnitude; both disagreement ratios are exactly zero.

## Mutations

All three run with the working tree otherwise clean (`git status
--porcelain` before and after each shows only the six new golden files and
the two support-file edits — the mutated source files are cleanly restored
by `cp` from a `/tmp` backup within the same shell call that applied and
tested them).

### T14a — fan the polygon from vertex 0 instead of ear-clipping

Applied to `packages/jet_cad_2d/lib/src/geometry/triangulate.dart`,
replacing the ear-clipping `while` loop with a straight fan from
`index[0]`, keeping the self-intersection check and winding normalisation
above it untouched.

```
$ flutter test --tags golden test/golden/fill_ladder_golden_test.dart
fill ladder rung 1 (RenderBackend.canvas)     [PASS]
fill ladder rung 1 (RenderBackend.vertices)   [FAIL] Golden "vertices/fill_ladder_1.png": Pixel test failed, 0.43%, 4692px diff detected.
fill ladder rung 2 (RenderBackend.canvas)     [PASS]
fill ladder rung 2 (RenderBackend.vertices)   [FAIL] Golden "vertices/fill_ladder_2.png": Pixel test failed, 0.01%, 81px diff detected.
fill ladder rung 3 (RenderBackend.canvas)     [PASS]
fill ladder rung 3 (RenderBackend.vertices)   [PASS]
```

**Verdict: killed on the vertices backend, not killed on the canvas
backend — and this is not a fixture defect.** I read
`packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`'s
`fillPolygon` (lines 172-190): it takes the `triangles` argument for API
symmetry with `VerticesDrawSink` but never reads it. It builds a `Path`
directly from `points` (the boundary loop) and lets `Canvas.drawPath` fill
it by Skia's own non-zero-winding rule. `CanvasDrawSink`'s fill rendering
is therefore architecturally independent of `triangulateSimplePolygon`'s
output — no fixture, at any size or position, can make the canvas rung
sensitive to a triangulation-only mutant, because the canvas backend never
consults the triangulation to draw a polygon fill at all. Per the brief's
own instruction, I am reporting this rather than the pass it would read as
if I only looked at the vertices column. The vertices backend, which does
consume `triangles` for `drawVertices`, reds clearly at rungs 1 and 2
(rung 3 is a several-pixel speck where the notch's few-pixel footprint
does not register a diff either way).

### T14b — skip winding normalisation

Applied to the same file, deleting the `if (_signedArea(...) < 0) {
index.setAll(...) }` block after the self-intersection check.

```
$ flutter test --tags golden test/golden/fill_ladder_golden_test.dart
fill ladder rung 1 (RenderBackend.canvas)     [FAIL] Golden "fill_ladder_1.png": Pixel test failed, 1.92%, 9216px diff detected.
fill ladder rung 1 (RenderBackend.vertices)   [FAIL] Golden "vertices/fill_ladder_1.png": Pixel test failed, 7.36%, 79524px diff detected.
fill ladder rung 2 (RenderBackend.canvas)     [FAIL] Golden "fill_ladder_2.png": Pixel test failed, 0.05%, 225px diff detected.
fill ladder rung 2 (RenderBackend.vertices)   [FAIL] Golden "vertices/fill_ladder_2.png": Pixel test failed, 0.15%, 1600px diff detected.
fill ladder rung 3 (RenderBackend.canvas)     [FAIL] Golden "fill_ladder_3.png": Pixel test failed, 0.00%, 4px diff detected.
fill ladder rung 3 (RenderBackend.vertices)   [FAIL] Golden "vertices/fill_ladder_3.png": Pixel test failed, 0.00%, 4px diff detected.
```

**Verdict: killed, on both backends, at all three rungs.** With the CW
square's winding never corrected, `_isEar`'s CCW assumption fails at every
vertex, ear-clipping stalls with "no ear anywhere", and
`triangulateSimplePolygon` returns `Int32List(0)` — empty, distinct from
`null`. `AddRegionCommand.apply` only refuses on `null`; an empty result is
accepted but never cached (`if (triangles.isNotEmpty)
target.fills.putTriangles(...)`), so `DraftPainter._drawFill` finds no
cached entry, increments `skippedFillCount`, and calls neither sink. The
green square vanishes from both images identically — this is a painter-level
skip, upstream of both backends, so unlike T14a it reds everywhere.

### T14c — route the fill through `_coveredArgb`

Applied to `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`,
changing `fillPolygon`'s `final argb = style.argb;` to `final argb =
_coveredArgb(style.argb, style.lineweightHundredths);`.

```
$ flutter test --tags golden test/golden/fill_ladder_golden_test.dart
fill ladder rung 1 (RenderBackend.canvas)     [PASS]
fill ladder rung 1 (RenderBackend.vertices)   [FAIL] Golden "vertices/fill_ladder_1.png": Pixel test failed, 7.36%, 79524px diff detected.
fill ladder rung 2 (RenderBackend.canvas)     [PASS]
fill ladder rung 2 (RenderBackend.vertices)   [FAIL] Golden "vertices/fill_ladder_2.png": Pixel test failed, 0.15%, 1600px diff detected.
fill ladder rung 3 (RenderBackend.canvas)     [PASS]
fill ladder rung 3 (RenderBackend.vertices)   [FAIL] Golden "vertices/fill_ladder_3.png": Pixel test failed, 0.00%, 4px diff detected.
```

**Verdict: killed on the vertices backend at all three rungs, canvas
untouched at all three — exactly as specified.** At the hairline layer's
resolved device width (`1/100 * kLogicalPixelsPerMm * dpr ≈ 0.11` device
pixels, well under `kMinStrokeDevicePixels = 1.0`), `_coveredArgb` fades
the alpha to roughly a fifth, dimming the whole purple square rather than
just its edge — hence the much larger pixel-diff count than T14a's
localised notch (79524 vs 4692 at rung 1). `CanvasDrawSink` has no
`_coveredArgb` equivalent and is unaffected, matching the brief exactly.

## Files touched

- `packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/golden/fill_ladder_{1,2,3}.png` (new)
- `packages/jet_cad_2d_flutter/test/golden/vertices/fill_ladder_{1,2,3}.png` (new)
- `packages/jet_cad_2d_flutter/test/support/sink_comparison.dart` (added `fillComparisonDoc()`)
- `packages/jet_cad_2d_flutter/test/sink_comparison_test.dart` (added the opaque-fill agreement test)

No file outside these was modified; `git status --porcelain` shows no
`analysis_options.yaml` and no pre-existing golden PNG.

## What I was unsure about

The brief states T14a "must red the L-shaped rung on BOTH backends" and
offers only one diagnosis for a vertices-only red: "the canvas golden is
not exercising the notch and your fixture is wrong." I confirmed by
reading `CanvasDrawSink.fillPolygon` that this specific failure mode has a
second, non-fixture cause: the canvas backend structurally never reads the
triangulation for a polygon fill, so it cannot be made sensitive to a
triangulation bug by any fixture change. I did not alter the fixture to
chase this, since doing so would not change the outcome — I'm flagging it
as an open question for review rather than silently reporting a partial
pass or force-fitting the fixture into an unwinnable shape.

---

## Review fix: T14a's uncatchable footprint, and the amended `fillComparisonDoc`

The review confirmed T14a's canvas-side immunity as a genuine architectural
fact, not a fixture defect, and ruled the brief's "both backends" wording
wrong. It raised one **Important** finding on top of that: the opaque
agreement row (`fillComparisonDoc`) carried only a convex pentagon and a
circle, so it could not exercise the one property T14a's own investigation
had just identified as canvas-invisible -- a bad concave triangulation
would ship on the vertices backend with no Flutter-level signal at all,
since the golden ladder's L-shape rung only asserts on canvas *and*
vertices together via `matchesGoldenFile`, and the vertices half of that
pairing is exactly what a triangulation regression would still fail, but
nothing in the comparison suite corroborated it independently.

### First attempt, and why it was insufficient

Added an L-shape to `fillComparisonDoc()`, its first vertex placed at the
convex tip diagonally farthest from the notch (the same design used in
`fill_ladder_golden_test.dart`'s own L-shape), scaled 2x and translated
clear of the pentagon and circle.

Unmutated: `canvas=211607 vertices=212034 stray=0 uncovered=0` -- clean.

Under T14a: `canvas=211607 vertices=214150 stray=2070 uncovered=0`.
`2070 / 211607 = 0.978%` -- **under the 1% ceiling**, not over it. The
mutation was real (confirmed by hand: the fan's `(Q0, Q2, Q3)` triangle
overfills a genuine ~400-world-unit² sliver of the notch, matching the
measured pixel count once scaled by the fit camera's device-pixel
factor), but the pentagon and circle's own ink diluted the ratio below
the declared floor. This is not "clears 1% with margin" -- it is a coin
flip against rasterisation noise, exactly what the coordinator asked me
not to ship.

### Second attempt, and a wrong turn

Reasoned that the polygon's one **reflex** vertex (the notch's own inner
corner) should be an even worse pivot than a convex tip, re-pivoted the
same L there, and measured: unmutated `stray=0`, and **under T14a,
`stray=0` too** -- a fan from that vertex turned out to be entirely
star-shaped for this particular L-tromino. I verified this by hand:
tracing the chord from the reflex vertex to every other vertex, all six
stay inside the polygon (an L-tromino's reflex corner sits inside its own
visibility kernel; it is the far convex tips of each arm that sit outside
it, as the first attempt already used). A reflex vertex is not
automatically a worse pivot than a convex one -- I had asserted that
without checking, and the measurement caught it. This is recorded in the
committed source comment as a fixture-note, since a later reader could
make the same wrong assumption.

### What shipped: the convex-tip pivot, at 3x scale

Reverted to pivoting at the convex arm-tip (the design that produced a
real, measured overfill), and scaled the whole L-shape 3x linearly so its
own share of the fixture's ink budget -- and its overfill's share of
that -- clears the ceiling with real margin rather than by a coin flip.

```
$ flutter test test/probe_fill_agreement_test.dart   # unmutated, amended fixture
UNMUTATED CANVAS=174135 VERTICES=174130 STRAY=0 UNCOVERED=0
00:00 +1: All tests passed!
```

`canvasInkPixels = 174135` (> 4000 non-vacuity floor by two orders of
magnitude), `strayVerticesPixels = 0` (0.0000%), `uncoveredCanvasPixels =
0` (0.0000%). Both ratios inside the 1% ceiling.

```
$ # T14a applied (fan the polygon from vertex 0 instead of ear-clipping),
$ # probe first, then the actual agreement test, then restored -- one shell call
T14A CANVAS=174135 VERTICES=182140 STRAY=7744 UNCOVERED=0

$ flutter test test/sink_comparison_test.dart --plain-name "the two sinks agree on an opaque fill"
00:00 +0: the two sinks agree on an opaque fill
Expected: a value less than or equal to <1741>
  Actual: <7744>
   Which: is not a value less than or equal to <1741>
...
00:00 +0 -1: the two sinks agree on an opaque fill [E]
Failing tests:
  .../sink_comparison_test.dart: the two sinks agree on an opaque fill

$ # restore
RESTORED OK  (diff against /tmp backup: empty)
```

`7744 / 174135 = 4.45%` -- **clears the 1% ceiling by a factor of about
4.4**, real margin rather than a coin flip. Restore confirmed clean by
`diff` against the pre-mutation backup.

### T14c, re-run against the committed golden ladder fixture

T14c's hairline-layer property lives in `fill_ladder_golden_test.dart`'s
`fillLadderFixture()`, not in `fillComparisonDoc()` -- the two fixtures
are deliberately separate (see below), and this fix did not touch the
golden ladder fixture. Re-ran the mutation once more per the review's
request, to close the loose end that it had not independently verified:

```
$ # vertices_draw_sink.dart's fillPolygon routed through _coveredArgb, applied,
$ # run, restored -- one shell call
fill ladder rung 1 (RenderBackend.canvas)     [PASS]
fill ladder rung 1 (RenderBackend.vertices)   [FAIL] Pixel test failed, 7.36%, 79524px diff detected.
fill ladder rung 2 (RenderBackend.canvas)     [PASS]
fill ladder rung 2 (RenderBackend.vertices)   [FAIL] Pixel test failed, 0.15%, 1600px diff detected.
fill ladder rung 3 (RenderBackend.canvas)     [PASS]
fill ladder rung 3 (RenderBackend.vertices)   [FAIL] Pixel test failed, 0.00%, 4px diff detected.
RESTORED OK  (diff against /tmp backup: empty)
```

Identical to the transcript in the original report -- still kills the
hairline rung on the vertices backend only, at all three rungs, canvas
untouched. Confirms the fixture is unaffected by this fix, as expected.

### `fillComparisonDoc` and the golden ladder fixture stayed separate

Per the coordinator's instruction to stop and report rather than
`--update-goldens` if editing `fillComparisonDoc` touched a golden: it did
not. `flutter test --tags golden` passed unchanged (`+29`), and
`git status --porcelain` after every step in this fix shows only
`sink_comparison_test.dart` and `sink_comparison.dart` modified -- no
golden PNG, no `analysis_options.yaml`. The two fixtures remain
independent, as the design intends.

### Gate

```
$ cd packages/jet_cad_2d_flutter && flutter test && flutter test --tags golden && flutter analyze && dart format --output=none --set-exit-if-changed .
...
00:03 +272 ~1: All tests passed!
...
00:02 +29: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
Formatted 47 files (0 changed) in 0.09s

$ cd packages/jet_cad_2d && CI=true dart test
...
00:03 +771: All tests passed!

$ git status --porcelain
 M packages/jet_cad_2d_flutter/test/sink_comparison_test.dart
 M packages/jet_cad_2d_flutter/test/support/sink_comparison.dart
```

(`~1` is the same pre-existing skip noted in the original report, unrelated
to this task.)

### Files touched by this fix

- `packages/jet_cad_2d_flutter/test/support/sink_comparison.dart` (added
  the L-shape to `fillComparisonDoc()`)
- `packages/jet_cad_2d_flutter/test/sink_comparison_test.dart` (updated the
  recorded measurement comment to the amended fixture's numbers)

No golden PNG and no `analysis_options.yaml` are among the changes.
