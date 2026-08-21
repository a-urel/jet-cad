# Task 11 — Sink against sink

**Status: DONE_WITH_CONCERNS.** Commit `405dd90` — `test: the two backends draw
the same drawing`.

## What I implemented

Two files, both new, no production code touched:

- `packages/jet_cad_2d_flutter/test/support/sink_comparison.dart` (671 lines)
- `packages/jet_cad_2d_flutter/test/sink_comparison_test.dart` (172 lines)

`measureAgreement(tester, doc, draw, {textMask})` drives **one `Drawing`
closure** — `void Function(DrawSink)` — through `CanvasDrawSink` and through
`VerticesDrawSink` in turn, and returns an `AgreementReport` of four counts
plus the two images and the vertices backend's flush count.
`expectSinksAgree` wraps it with the two zero assertions and two
non-vacuity assertions.

### I took the direct route

No `DraftCanvas`, no `pumpWidget`, no `markNeedsPaint`, no `runAsync` chaining.
The canvas side records into a `PictureRecorder` and reads the bytes back with
`Picture.toImage` + `Image.toByteData` inside **one, never nested** `runAsync`.
The vertices side needs no async at all: `TriangleRasterizer.pixels` is already
the image, so `decodeImageFromPixels` — one of the two engine round-trips the
prior attempt was fighting — is not called.

**What the widget route would have added, and why it was not worth it.** It
would have covered `DraftCanvasState._attach`'s sink construction, the
`RenderBackend` resolution, and `MediaQuery.devicePixelRatioOf` reaching
`VerticesDrawSink.devicePixelRatio` in `build`. Those are three lines of widget
plumbing, and `draft_canvas_test.dart` is where they would belong if they were
covered — **they are not covered today; no test in this package references
`draft_canvas.dart:192`, and this task did not add one.** Nothing
about them changes what either sink *draws*, which is the entire question this
task asks — the same argument `stroke_width_golden_test.dart`'s header already
makes. Against that: the widget route is what did not finish. Both captures
inside one `testWidgets` need two `pumpWidget` calls over two `SpatialIndex`
instances on one document (whose `onAfterMutate` is a single slot), an observer
attached after construction and therefore a `markNeedsPaint` and a second pump,
and two engine round-trips inside a binding whose fake-async zone will not
deliver one of them — for zero coverage of the sinks.

Run time for the whole comparison file, direct: **under one second** for five
tests. The prior attempt's two tests did not finish in seven minutes.

### Device resolution

`dpr` comes from `tester.view.devicePixelRatio` — **3.0** on this binding, not
the 1.0 the inherited file's header asserted. The rasterizer is built at
`400x300 x 3 = 1200x900` and the observer scales every position by `dpr`; the
canvas recorder gets `canvas.scale(dpr)` before the painter runs and
`picture.toImage(1200, 900)`, which is what the engine does to a layer tree.
The ratio is read, never written down.

Both sides clip: `_DraftCustomPainter.paint` clips to the viewport and the
rasterizer clamps to its surface, so the canvas recording clips too — otherwise
offscreen geometry would count as canvas-only ink.

## What I kept and what I discarded from the inherited work

**Kept**, with edits: the fixture's shape and most of its reasoning, the text
mask (`comparisonTextMask`, unchanged except that it now returns logical pixels
and the caller scales), `_nearInk`, the `AgreementReport` field set, and a good
deal of the header prose.

**Discarded**: both capture functions (`_captureCanvas`, `_captureVertices`) and
everything they pulled in — `DraftCanvas`, `CameraController`,
`GlobalKey<DraftCanvasState>`, `RenderRepaintBoundary`, `markNeedsPaint`, the
two-`pumpWidget` dance and the index-disposal choreography it forced. Also the
four `print('DEBUG …')` statements and `test/_scratch/`'s nineteen probes.

**Discarded as false**: the inherited header's claim that `flutter_test`
defaults to `devicePixelRatio` 1.0. It is 3.0, and the inherited file pinned it
to 1.0 through an explicit `MediaQuery` — which, combined with a rasterizer
built at that ratio, is exactly the logical-resolution capture Task 10 landed to
prevent.

**Discarded as unverified**: the inherited comment claiming the 2π-sweep ARC
divergence "was reproduced and measured separately, by hand, against this same
machinery, and the numbers are in Task 11's report". There was no report and no
numbers. I measured it myself; see below.

**Changed in the fixture** (both because a mutant survived):

- The oblique corner and the past-limit corner went from lineweight 80 to 160.
  At 80 (4.5 device px) the bevel triangle's inradius is under a pixel, so
  removing it changed the picture by 37 pixels and none of them cleared the
  one-pixel dilation.
- The past-limit corner went from a 178° direction change to **160°**. At 178°
  the direction vectors are nearly antiparallel, so `A`, `V` and `B` are nearly
  collinear and *the bevel triangle is itself degenerate* — the branch was
  exercised while the ink it controls was nil. At 160° the suppressed miter tip
  would reach 5.9 half-widths past the corner, and mutant 4 below is caught by
  431 pixels because of it.

## TDD evidence

The first run of the comparison was against the inherited widget-routed capture
and did not produce output; that is the state I inherited, not a test I wrote.
The first run of the direct capture produced real counts immediately
(`FIXTURE canvas=11897 vertices=12641 stray=0 uncovered=0`). Since a
zero-disagreement first run cannot distinguish "correct" from "vacuous", the
work of establishing that this test can fail is entirely in the mutation
section, and I did not treat the green first run as evidence of anything. The
non-vacuity guards (`canvasInkPixels`/`verticesInkPixels` floors) are in
`expectSinksAgree` itself so they cannot be forgotten at a call site.

Two of the five tests — anisotropy and sub-pixel — were written to **fail if the
divergence disappeared**, so they are red-by-construction against a fixture that
does not reach the regime; I confirmed both by watching the counts move as I
changed `scaleY` and `lineweight`.

## The actual disagreement numbers, and what the images showed

All numbers 2026-08-21, 1200x900 device pixels, dpr 3.0.

| Fixture | canvas ink | vertices ink | stray | uncovered |
|---|---|---|---|---|
| `comparisonFixture` (painter, every primitive + text) | 22398 | 23241 | **0** | **0** |
| `comparisonDirectOps` (closed pentagon + rotated point) | 18291 | 18906 | **0** | **0** |
| `anisotropyDivergenceFixture(scaleY: 3.0)` | 19194 | 24580 | 3513 | 897 |
| `subPixelDivergenceFixture(lineweight: 1)` | 0 | 1140 | 1140 | 0 |
| `fullSweepArcDrawing` (r 36 dev px, 25 dev px wide) | 5688 | 5710 | 0 | 6 |

**The two comparisons that assert agreement are at zero.** I did not widen the
dilation at any point; it is the 3x3 neighbourhood the brief specifies and
nothing else.

I wrote every capture out as PPM (`writeDisagreementImages`, red = canvas-only,
blue = vertices-only, black = both), converted with `sips`, and opened all of
them. What I saw:

- **`comparisonFixture`.** The drawing is right: a small square marker top
  left, a solid black block where `flutter_test`'s test font renders "SINK" as
  a filled rectangle, an oblique `Λ` bend, a near-fold, an open arc, and a
  visibly *elliptical* circle top right — so the residual is genuinely rotated
  and non-uniform and not quietly the identity. In the diff the text block is
  solid red (the vertices sink draws no glyphs; it is inside the mask and
  counts nothing), everything else is black with a one-pixel blue fringe on the
  curves — the vertices sink is consistently a fraction of a pixel wider,
  because its ink is geometric coverage while the canvas ink is thresholded at
  `0xC0`. One small red patch sits at the ellipse's seam. All of it is inside
  the dilation.
- **Anisotropy at `scaleY` 3.0.** The clearest picture in the task. The canvas
  stroke is **visibly fatter at the two ends of the ellipse's major axis** (red
  halo outside the black) and **visibly thinner along its flanks** (blue fringe
  outside the black), while the vertices stroke is even the whole way round.
  That is exactly row 1: `CanvasDrawSink._widthFor` divides by
  `scaleMagnitude = sqrt(3) = 1.732` and then lets the residual scale the
  result, so its apparent device width runs from `0.577W` to `1.732W`;
  `VerticesDrawSink` takes the perpendicular after transforming and draws `W`
  everywhere. Both directions of disagreement are present, which is what says
  this is a width divergence and not a misplaced ellipse.
- **Sub-pixel at lineweight 1.** The diff is a single clean blue line: the
  vertices sink draws its one-device-pixel floor-clamped stroke, and the canvas
  image is *blank at the ink floor* — 0 pixels. A 0.11-device-pixel stroke
  anti-aliases to roughly alpha 29, nowhere near `0xC0`.
- **Full-sweep arc.** A black donut with **one red radial notch at the 3
  o'clock position** — the start angle — and nothing anywhere else on the ring.

## Which divergences appeared, and which are permitted

Against the design document's table (`…-plan-3d-design.md`, the five rows):

- **Row 1, anisotropic stroke width — appeared, permitted, admitted by name.**
  Present but sub-pixel in `comparisonFixture` (1.15 anisotropy, ~0.16 device
  px), and given its own fixture and its own assertions at `scaleY` 3.0 so it
  is *measured* rather than swallowed by the dilation. The test asserts the
  disagreement in **both** directions and that vertices ink exceeds canvas ink.
- **Row 2, point shape — no longer a divergence.** Task 6 reconciled it, and
  mutant 3 below confirms the comparison would notice if that were undone.
- **Row 3, anti-aliasing — appeared, permitted, handled by construction.** The
  `kInkAlphaFloor = 0xC0` threshold is what excludes AA spill from the canvas
  mask, and the one-pixel dilation covers the residual half-pixel.
- **Row 4, sub-pixel strokes — appeared, permitted, admitted by name.** This is
  the row the brief flagged as exercised nowhere in the repository. It is now
  exercised: `subPixelDivergenceFixture` reaches 0.11 device pixels, the canvas
  backend inks nothing at all, and the test asserts precisely that. Note this
  makes the design document's "untestable by comparison" slightly too strong —
  it is untestable as *agreement*, but perfectly measurable as divergence.
- **Row 5, overlapping translucent strokes — did not appear.** The corpus is
  opaque (`argb` alpha is `255 - transparency`), as the design document says.

**Nothing else appeared** in the two agreement comparisons. Both are at zero, so
there is no unexplained residue to attribute to Tasks 4, 5 or 6.

## The 2π-sweep ARC question

**Can the corpus produce one? No.**

- `packages/jet_cad_2d/lib/src/testing/generate_document.dart` draws arc sweeps
  from `(0.25 + random.nextDouble() * 1.5) * math.pi` at the root
  (`_addFloorArc`) — the range `[0.25π, 1.75π)` — and
  `(0.5 + random.nextDouble()) * math.pi` inside definitions — `[0.5π, 1.5π)`.
  Both are strictly below `2π`, so no generated document contains one.
- **There is no DXF reader in this repository at all.**
  `packages/jet_cad_2d/lib/src/codec/` holds `json_codec.dart` and
  `schema_version.dart` and nothing else, so no real `ARC` entity can enter
  from a file today. The original question — "whether a real ARC entity can
  carry a 2π sweep through the DXF reader" — cannot be answered against code
  that does not exist.

**What would have to change for it to.** Either a DXF reader that maps an `ARC`
with equal (or 2π-apart) start and end angles onto a `2π` sweep — the natural
translation, and the reason the question was raised — or a corpus change that
widens `_addFloorArc`'s range. Nothing between `AddEntityCommand` and
`sink.arc` validates or normalises `payload.scalars[2]`:
`draft_painter.dart` reads it and passes it straight through. So the value
reaches the sink untouched the moment anything produces one.

**The divergence is real, and I measured it.** Test 5 pins it: a `2π` sweep
draws a full circle whose seam is unjoined on the vertices backend, where
`Canvas.drawArc` closes the loop. **6 uncovered pixels**, and the image shows
exactly one radial notch at the start angle.

**A second finding, which I think matters more than the first.** The divergence
is *invisible at any ordinary lineweight*. The seam notch is about
`half * sqrt(2 / R)` device pixels wide at the sink's quarter-pixel flattening
tolerance, so it only clears the one-pixel dilation when the stroke is a large
fraction of the radius. A `2π` arc pushed through the real painter at a fitted
camera (radius ≈ 420 device px, lineweight 200) measured **0 stray and 0
uncovered** — the defect was there and the comparison could not see it. Sizes I
swept, all direct at the sink:

```
ARCDIRECT r=12.0 lw=225 canvas=5688  vertices=5710  stray=0 uncovered=6
ARCDIRECT r=20.0 lw=225 canvas=9455  vertices=9540  stray=0 uncovered=4
ARCDIRECT r=30.0 lw=225 canvas=14150 vertices=14356 stray=0 uncovered=0
ARCDIRECT r=12.0 lw=120 canvas=2953  vertices=3044  stray=0 uncovered=0
ARCDIRECT r=40.0 lw=400 canvas=33862 vertices=34074 stray=0 uncovered=14
```

So the test uses `r = 12` logical (36 device px) stroked 25 device px wide,
which is where it is detectable. **I did not fix the defect** — the brief's
instruction is to report it if the corpus can produce one, and the corpus
cannot. The test carries the instruction that when Task 5's `closed` decision
learns about a full sweep, the right fix is to change its two expectations to
zero rather than delete the fixture.

The same arithmetic explains why `comparisonFixture`'s circle cannot catch a
missing seam join either, and is why `comparisonDirectOps` exists.

## Mutations

All five run as: `cp` the file aside, mutate with a python `assert`-guarded
replacement so a stale pattern fails loudly, run, restore, and confirm
`git status --porcelain lib/` is empty. Real transcripts, trimmed to the
assertion lines.

### Mutant 1 — skip the seam join (`_endRun`, `vertices_draw_sink.dart`)

```
00:00 +0: the two backends draw the same drawing
00:00 +1: the two backends agree on the ops the painter cannot emit
Expected: <0>
  Actual: <17>
00:00 +1 -1: the two backends agree on the ops the painter cannot emit [E]
00:00 +4 -1: Some tests failed.
```

**Caught, 17 uncovered pixels — and caught by the pentagon, not by the
document fixture.** The circle in `comparisonFixture` reaches
`_endRun(closed: true)`, but its chords are a quarter-pixel apart, so its seam
notch is far below the dilation. This is the single most important thing the
direct-ops comparison buys.

### Mutant 2 — emit only the miter tip, not the bevel triangle (`_emitJoin`)

```
00:00 +0: the two backends draw the same drawing
Expected: <0>
  Actual: <10>
00:00 +0 -1: the two backends draw the same drawing [E]
00:00 +0 -1: the two backends agree on the ops the painter cannot emit
Expected: <0>
  Actual: <12>
00:00 +0 -2: the two backends agree on the ops the painter cannot emit [E]
00:00 +3 -2: Some tests failed.
```

Caught twice, 10 and 12 uncovered. Caught by the document fixture **only after**
the lineweight change described above; at the inherited lineweight 80 it
survived there and was caught by the pentagon alone.

### Mutant 3 — revert `CanvasDrawSink.point` to the pre-Task-6 sheared square

```
00:00 +0: the two backends draw the same drawing
00:00 +1: the two backends agree on the ops the painter cannot emit
Expected: <0>
  Actual: <12>
00:00 +1 -1: the two backends agree on the ops the painter cannot emit [E]
00:00 +4 -1: Some tests failed.
```

**Caught, 12 pixels — and again only by the direct-ops comparison.** This is a
finding worth carrying forward, and unlike the seam join it really is
*unreachable*, not merely unobservable: **no painter path can hand `point` a
rotated residual.** `draft_painter.dart` routes `point`, `line` and `polyline`
through `_emitScreenSpace`, which calls
`sink.beginResidual(Transform2.translation(...))` — a pure translation, under
which the screen-space square Task 6 introduced and the local-space
`drawRawPoints` cap it replaced are *the same square*. No painter path supplies
a rotated residual to `point`. Any document-driven fixture, however adversarial
its transforms, would have let this mutant live.

### Mutant 4 — remove the miter-limit guard (`kMinMiterCosine`)

```
00:00 +0: the two backends draw the same drawing
Expected: <0>
  Actual: <431>
00:00 +0 -1: the two backends draw the same drawing [E]
00:00 +4 -1: Some tests failed.
```

Caught, **431 stray pixels** — the unsuppressed miter spike at the 160° corner.
Not in the brief's list; added because the "angle past the miter limit"
requirement is otherwise pinned by nothing observable, and because it is what
proved the 178° corner was vacuous.

### Mutant 5 — `_flushBeforeUnbatchable` becomes a no-op

```
Expected: <2>
  Actual: <1>
text must force a mid-frame flush with real batched work on both sides of it
00:00 +0 -1: the two backends draw the same drawing [E]
00:00 +4 -1: Some tests failed.
```

Caught. Text is masked out of the pixel comparison, so the mid-frame flush and
the ordering that depends on it are checked by `verticesFlushCount` — 2 for the
document fixture (batch, flush before the paragraph, batch, flush at the end),
1 for the direct ops. Added because the file's header claimed text was
"asserted by flush count" and, as inherited, it was not asserted at all.

After every mutant: `git status --porcelain lib/` empty. No `git checkout` was
used to restore anything.

## The three-package gate

```
=== jet_cad_2d ===
00:02 +720: All tests passed!
No issues found!
Formatted 105 files (0 changed) in 0.13 seconds.
=== jet_cad_2d_flutter ===
00:02 +236 ~1: All tests passed!
No issues found! (ran in 0.9s)
Formatted 44 files (0 changed) in 0.06 seconds.
=== dev_harness_2d ===
No issues found! (ran in 0.8s)
Formatted 2 files (0 changed) in 0.01 seconds.
```

**236 passing, 1 skipped**, against the 231/1 baseline: +5, which is exactly
this file's five tests. No regression.

`git status --porcelain` before the commit listed only the two new test files —
no `analysis_options.yaml` (three of them are rewritten by every
`flutter pub get` in this workspace and none was staged), no `test/_scratch/`,
no production file.

## Files changed

- **Added** `packages/jet_cad_2d_flutter/test/support/sink_comparison.dart`
- **Added** `packages/jet_cad_2d_flutter/test/sink_comparison_test.dart`
- **Deleted** `packages/jet_cad_2d_flutter/test/_scratch/` (19 untracked probe
  files, never committed)

No production code was modified. `lib/` is byte-identical to `002b5e0`.

## Self-review findings, fixed before committing

1. `flutter analyze` flagged an unused `package:flutter/widgets.dart` import in
   the test file. Removed.
2. Both captures built a `FlutterTextMeasurer` and never cleared it, leaking
   native `Paragraph` memory per test. Now cleared — on the canvas side *after*
   `toImage`, because the recorded picture still refers to the paragraphs until
   it has been rasterised; on the vertices side immediately, because that
   picture is never rasterised.
3. The header claimed text was "asserted by flush count instead". It was not.
   Rather than soften the comment I made it true — see mutant 5.
4. The inherited fixture's "past the miter limit" corner exercised the branch
   with degenerate geometry. Replaced (see above).

## Concerns

1. **`writeDisagreementImages` ships unused.** It is the tool the task's own
   instruction ("look at the images") requires, it is what produced every image
   described in this report, and the two failure `reason` strings name it — but
   no test calls it. A reviewer may reasonably want it deleted; I would argue
   the next person to see a non-zero count needs it to exist.
2. **Two of the five mutants are caught only by `comparisonDirectOps`.** The
   two cases differ and the distinction matters:
   - **The seam join is reachable through the painter but not observable
     there.** `draft_painter.dart:588` and `:619` call `sink.circle`, which
     passes `closed: true`, so `_endRun`'s seam branch does run in a real
     frame. Its notch is simply below the one-pixel dilation at the quarter-
     pixel flattening tolerance, so no ink comparison over painter output can
     see it. Only the pentagon's 72-degree seam can.
   - **A rotated residual at `point` is genuinely unreachable.**
     `draft_painter.dart:425-429` routes point, line and polyline
     unconditionally through `_emitScreenSpace`, whose residual is a bare
     `Transform2.translation` (`:498`). A corollary: `_emit`'s
     `case EntityKind.point` at `draft_painter.dart:566` is dead code, for the
     same reason.

   Either way the consequence outlives this task: **the seam join and Task 6's
   point-shape fix have no coverage through any frame path** — not the
   goldens, not `draft_painter_*` — and are pinned against the `DrawSink`
   interface only.
3. **The 2π-sweep ARC defect is characterised, not fixed**, and test 5 will go
   red the day someone fixes it. The test says so in a comment; it is still a
   test that fails on an improvement.
4. **The sub-pixel and anisotropy tests assert that a divergence exists.** If
   `CanvasDrawSink` ever grows a `devicePixelRatio` and a floor, or if
   `_widthFor` learns about two axis scales, they go red. That is intentional —
   they are the record that the rows are live — but they are not agreement
   tests and should not be read as ones.
5. **This comparison runs on software Skia at dpr 3.0 and says nothing about
   Impeller.** Rows 1 and 4 are Impeller rules mirrored in Dart; what is
   compared here is the mirror, not the engine. Phase C's device measurement is
   still the only thing that can check the mirror is faithful.

---

# Fix report — review round 1

Commit `c678ec3`. Two files touched, both tests; `lib/` still
byte-identical to `002b5e0`.

## The Important fix: the characterisation test had no floors

The reviewer is right, and the way it is right is worse than the omission
itself. `sink_comparison_test.dart`'s full-sweep-ARC test called
`measureAgreement` directly, so it inherited none of `expectSinksAgree`'s ink
floors — and its load-bearing assertion was
`expect(report.uncoveredCanvasPixels, greaterThan(0))`. "Some canvas ink has no
vertices ink near it" is the assertion an **empty vertices side satisfies
best**. The one test in the file whose job is to hold a known divergence still
was the one test that would have passed against a backend that drew nothing.

Reproduced the reviewer's mutation myself — `VerticesDrawSink.arc` returning
early for `sweep > 6.0` — against the file **as committed at `405dd90`**: all
five tests passed. Then added the bounds and reran it.

```
######## REVIEWER MUTANT: VerticesDrawSink.arc returns early for sweep > 6.0 ########
00:00 +0: the two backends draw the same drawing
00:00 +1: the two backends agree on the ops the painter cannot emit
00:00 +2: anisotropic stroke width diverges, and vertices is right
00:00 +3: a sub-pixel stroke is where the two backends stop agreeing
00:00 +4: a full-sweep ARC leaves an unjoined seam. This is a defect
Expected: a value greater than <4000>
  Actual: <0>
the vertices backend must have drawn the whole ring, not skipped the op and left a notch-shaped hole
00:00 +4 -1: a full-sweep ARC leaves an unjoined seam. This is a defect [E]
00:00 +4 -1: Some tests failed.
######## RESTORED ########
(empty = clean)
```

Now red, on `verticesInkPixels` reading **0**. Restored with `cp`;
`git status --porcelain lib/` empty.

Four assertions added to that test, not two:

- `canvasInkPixels > 4000` and `verticesInkPixels > 4000`. The ring measures
  5688 and 5710, so the floor sits at about 70% of the real number — clear of
  an empty side by everything, and far enough below the measurement not to be
  brittle against a rasteriser tie-break.
- `uncoveredCanvasPixels < 50`, the bound the reviewer asked for. Without it
  "unjoined seam" can quietly become "half the ring missing" and still read as
  this known defect. The notch is 6 pixels.
- `uncoveredCanvasPixels > 0`, unchanged, now meaningful because it sits above
  those three.

## The same shape, checked across the file

Two of the five tests bypass `expectSinksAgree`. Both now carry floors.

- **Anisotropy** had none. Its three assertions were `stray > 1000`,
  `uncovered > 200` and `verticesInk > canvasInk` — the first and third of
  which an empty *canvas* side would satisfy. Added
  `canvasInkPixels > 10000` and `verticesInkPixels > 10000` against measured
  19194 and 24580, with a comment saying why a test outside `expectSinksAgree`
  has to supply its own. Verified with a seventh mutant, `VerticesDrawSink.circle`
  emitting nothing:

```
######## MUTANT 7: VerticesDrawSink.circle emits nothing ########
00:00 +0: the two backends draw the same drawing
Expected: <0>
  Actual: <2593>
00:00 +0 -1: the two backends draw the same drawing [E]
00:00 +0 -1: the two backends agree on the ops the painter cannot emit
00:00 +1 -1: anisotropic stroke width diverges, and vertices is right
Expected: a value greater than <10000>
  Actual: <0>
00:00 +1 -2: anisotropic stroke width diverges, and vertices is right [E]
00:00 +3 -2: Some tests failed.
######## RESTORED ########
(empty = clean)
```

- **Sub-pixel** was already guarded and I left it alone: it asserts
  `canvasInkPixels == 0` exactly (not a floor that an empty side clears) and
  `verticesInkPixels > 500`, so an empty vertices side fails on the second.

The three tests that go through `expectSinksAgree` were already floored inside
it.

## Comment correction 1 — the 178-degree corner

The reviewer refuted my evidence and I have withdrawn the claim. It rebuilt the
178-degree corner and ran the miter-limit mutant against it: caught by **4567**
pixels. So the angle change did not *enable* detection of that mutant, and the
sentence "would have been caught by luck rather than by geometry" was wrong.
The reason is visible in the formula I should have applied: the suppressed
tip's reach is `half / cos(theta/2)`, which **grows** as the corner approaches a
reversal, so 178 degrees produces a longer spike than 160 does, not a shorter
one.

What survives is the argument about the **bevel**, which is a different
triangle. Past the limit the bevel is the only ink the join contributes, and its
area goes as `sin` of the direction change — 0.035 at 178 degrees, a sliver
under the dilation. That is why the corner was worth moving, and the comment
now says only that, plus the reviewer's 4567 as the counter-fact so the next
reader does not re-derive the wrong conclusion from the same fixture.

## Comment correction 2 — the report's coverage claim

"`draft_canvas_test.dart` already exists to hold them" read as a coverage claim
and was not one. Reworded to say plainly that the `devicePixelRatio` plumbing at
`draft_canvas.dart:192` is **not covered today**, that no test in the package
references it, and that this task did not add one. The argument for the direct
route never depended on that line being covered — it depends on the line not
changing what either sink draws — so the correction costs the argument nothing.

## Two claims sharpened, as the reviewer asked

- **The seam join is reachable through the painter but not observable there.**
  My report headline said "unreachable"; the in-file comment already had it
  right. `draft_painter.dart:588` and `:619` call `sink.circle`, which passes
  `closed: true`, so `_endRun`'s seam branch does run in a real frame — its
  notch is just below the dilation. Corrected in the concerns section.
- **A rotated residual at `point` is genuinely unreachable.**
  `draft_painter.dart:425-429` routes point, line and polyline unconditionally
  through `_emitScreenSpace`, whose residual is a bare `Transform2.translation`
  (`:498`). Added the corollary the reviewer named: `_emit`'s
  `case EntityKind.point` at `draft_painter.dart:566` is **dead code**.
- Recorded the consequence plainly, because it outlives this task: **the seam
  join and Task 6's point-shape fix have no coverage through any frame path** —
  not the goldens, not `draft_painter_*` — and are pinned against the
  `DrawSink` interface only.

The 2π-ARC derivation was re-derived by the reviewer and holds; left as written.

## Gate, after the fix

```
=== jet_cad_2d ===
00:02 +720: All tests passed!
No issues found!
Formatted 105 files (0 changed) in 0.13 seconds.
=== jet_cad_2d_flutter ===
00:02 +236 ~1: All tests passed!
No issues found! (ran in 0.9s)
Formatted 44 files (0 changed) in 0.06 seconds.
=== dev_harness_2d ===
No issues found! (ran in 0.8s)
Formatted 2 files (0 changed) in 0.01 seconds.
```

236 passing / 1 skipped, unchanged: the fix adds assertions to existing tests,
not new tests. `git status --porcelain` showed only the two modified test files —
no `analysis_options.yaml`, no production file.

## Mutation tally after the fix

Seven mutants run against this file in total, all caught:

| # | Mutation | Caught by | Pixels |
|---|---|---|---|
| 1 | seam join skipped (`_endRun`) | direct ops | 17 uncovered |
| 2 | bevel triangle not emitted (`_emitJoin`) | fixture + direct ops | 10 / 12 uncovered |
| 3 | `CanvasDrawSink.point` reverted to pre-Task-6 | direct ops | 12 |
| 4 | miter-limit guard removed | fixture | 431 stray |
| 5 | `_flushBeforeUnbatchable` no-op | fixture | flushes 2 → 1 |
| 6 | `arc` returns early for `sweep > 6.0` (reviewer's) | full-sweep ARC | vertices ink 0 |
| 7 | `circle` emits nothing | fixture + anisotropy | 2593 stray; vertices ink 0 |

## Concern, revised

Concern 1 from the first report stands (`writeDisagreementImages` ships unused —
though the reviewer used it to produce the images for this review, which is
some evidence it should stay). Concern 2 is rewritten above. Concerns 3, 4 and 5
are unchanged.

One new one: **the lesson from this round generalises past this file.** The
failure was not a missing floor, it was writing a `greaterThan(0)` on *missing*
ink without first pinning that both sides drew anything — an assertion whose
best-case satisfier is an empty renderer. Every test in this plan that measures
a divergence rather than an agreement has that shape available to it.
`expectSinksAgree` carries the floors so its callers cannot forget; anything
calling `measureAgreement` directly is on its own, and the file now says so at
both such call sites.
