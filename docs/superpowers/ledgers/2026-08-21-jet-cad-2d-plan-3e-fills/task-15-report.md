# Task 15 report: the translucent seam, measured against the real engine

## The fixture

`packages/jet_cad_2d_flutter/test/fill_seam_test.dart`. One entity, no
boundary stroke: a convex rectangle with one rectangular notch cut into its
top edge (two reflex vertices, at device coordinates `(500,300)` and
`(700,300)`), given directly in device-pixel coordinates so both sinks draw
it under the identity residual with no camera or paper scale in between.
Nine-point boundary (eight distinct plus the stored closing duplicate),
triangulated by `triangulateSimplePolygon` into 6 triangles sharing 4
internal edges — enough concavity that ear-clipping (not a fan) is forced,
so the triangulation has real internal shared edges for the mode-2 seam to
occur on, not just the outer boundary.

Fill style: `argb = 0x803366CC` (alpha `0x80`), `lineweightHundredths: 10`
(inert for a fill — `fillPolygon` uses `style.argb` directly, never
`_coveredArgb`). Drawn white background first (`0xFFFFFFFF`), then the one
fill, through `CanvasDrawSink.fillPolygon` (a `drawPath` fill) and through
`VerticesDrawSink.fillPolygon` (batched triangles, one `drawVertices` after
an explicit `flush()`).

- **Viewport:** 400 × 300 logical.
- **Device pixel ratio:** 3.0, the `flutter_test` binding's own default —
  asserted in the test (`expect(tester.view.devicePixelRatio, 3.0)`), not
  set, so a future binding-default change fails loudly instead of silently
  rescaling the measurement.
- **Capture surface:** 1200 × 900 device pixels (`400×3.0`, `300×3.0`).
- **Interior mask:** computed purely from the fixture's own boundary
  geometry — never from either rendered image, so it cannot be biased
  toward whichever sink happens to agree with it. A device pixel's centre
  qualifies if it is inside the boundary (even-odd test) **and** more than
  one device pixel from the nearest boundary edge (point-to-segment
  distance over every edge of the ring). 656,204 pixels qualified.

## The measurement, verbatim

```
$ cd packages/jet_cad_2d_flutter && flutter test test/fill_seam_test.dart
00:00 +0: the translucent seam, measured
SEAM interior=656204 over8=0 fraction=0.000% worst=0
00:00 +1: All tests passed!
```

Zero pixels over the 8/255 channel threshold, zero maximum channel delta,
over 656,204 interior pixels. This is not merely under the 0.5% / 32-per-255
bounds — I checked further (see below) and it is **exact byte equality**
between the two captures across the *entire* 1200×900 surface, boundary
antialiasing included, not only inside the eroded interior mask.

## Step 3: proving the instrument can see a seam at all

Before trusting the pass, I forced one, inside a single shell call with a
`trap`-guarded restore (never `git checkout`):

```
$ cp lib/src/vertices_draw_sink.dart /tmp/t15.dart
$ trap 'cp /tmp/t15.dart lib/src/vertices_draw_sink.dart' EXIT
$ perl -0pi -e 's/(      _emitTriangle\(\n(?:.*\n)*?        argb,\n      \);)/$1\n      _emitTriangle(\n        t.a * points[a * 2] + t.c * points[a * 2 + 1] + t.e,\n        t.b * points[a * 2] + t.d * points[a * 2 + 1] + t.f,\n        t.a * points[b * 2] + t.c * points[b * 2 + 1] + t.e,\n        t.b * points[b * 2] + t.d * points[b * 2 + 1] + t.f,\n        t.a * points[c * 2] + t.c * points[c * 2 + 1] + t.e,\n        t.b * points[c * 2] + t.d * points[c * 2 + 1] + t.f,\n        argb,\n      );/' lib/src/vertices_draw_sink.dart
$ flutter test test/fill_seam_test.dart
...
Expected: a value less than or equal to <0.005>
  Actual: <1.0>
   Which: is not a value less than or equal to <0.005>
above this the plan routes translucent fills through the fallback sink; see the design's declared rule
...
00:00 +0 -1: the translucent seam, measured [E]
00:00 +0 -1: Some tests failed.
$ cp /tmp/t15.dart lib/src/vertices_draw_sink.dart
```

`fraction = 1.0` (every triangle now emitted twice, so essentially every
interior pixel double-blends) — the measurement went red as required.
`git status --porcelain` on `vertices_draw_sink.dart` after the restore
shows no diff; the mutation never reached the working tree in the passing
run.

## An additional check, beyond what the brief required

A `fraction=0.000%, worst=0` result over an eroded interior mask is
consistent with "just barely under the rule," which would be a weak result
to build a routing decision on. So I also compared the two full 1200×900
captures pixel-by-pixel with no mask at all (a throwaway diagnostic test,
not committed): `anyDiff=0, maxAny=0` — the two images are byte-identical
everywhere, including right at the outer antialiased boundary that the
interior mask deliberately excludes. I also sampled points directly along
one of the triangulation's internal shared edges (the diagonal from
`(100,800)` to `(500,100)`, shared between triangles `[7,0,1]` and
`[7,1,2]`) and at the fill's plain interior: every sampled pixel from both
backends reads `(153,178,229,255)`, which is the exact single-pass
Porter-Duff composite of `0x3366CC` at alpha `0x80` over white
(`51·0.502+255·0.498≈153`, `102·0.502+255·0.498≈178`,
`204·0.502+255·0.498≈229`) — i.e. a single coverage-1.0 blend, not two
partial blends compounding to something darker.

**Correction, added after review — see "Addendum" below.** The sentence
that stood here originally read Step 3's forced-seam pass as proof this
zero is not an instrument blind spot. That overreached. Step 3's mutation
emits every triangle a second time at full coverage; a fully-covered pixel
drawn twice blends twice regardless of whether antialiasing exists at all,
so it proves the instrument can see a gross full-alpha double-draw. It does
not prove the instrument can see the specific mechanism mode 2 predicts —
a genuinely *partial*-coverage edge pixel blended twice. The addendum below
settles that question directly, and the answer is that this instrument
cannot show it at all.

## The decision the rule produced

**The rule does not fire.** `0.000% ≤ 0.5%` and `worst = 0 ≤ 32`.
Translucent fills continue to batch through `VerticesDrawSink.fillPolygon`
unchanged; no routing change was made. `vertices_draw_sink.dart` is
untouched by this task (`git status --porcelain` shows only the new test
file, plus the addendum file below).

Mode 1 (overlapping stroke joins under alpha) is unaffected by this
decision either way — this fixture carries no stroke, `fillPolygon`'s
routing is the only thing this task's rule governs, and `polyline` is
unchanged. Its lens-overlap shape was already characterised by Plan 3d as
real geometry, not a bug; nothing here revisits that.

**Scope of this conclusion, stated precisely — read this before copying
anything into the results note.** The declared rule, measured against the
declared instrument, did not fire, and translucent fills batch as a direct
consequence: that part is settled. What is **not** settled is whether the
mode-2 seam exists on the engine this codebase actually ships on. The
addendum below shows the declared instrument (`flutter_test`'s software
Skia, reached through `ui.Picture.toImage()`) cannot produce the
partial-coverage mechanism the design predicts, on *any* geometry, not just
this fixture's. So "0.000%" is not evidence the seam is absent — it is the
reading this instrument was always going to give, seam or no seam. The
correct sentence for the results note is: **the mode-2 question is open on
Impeller/GPU**, unmeasured by anything in this repository's test suite,
because the suite's own picture-capture path cannot see it. Do not write
"no seam was found."

## What I was unsure about

The zero-diff result was surprising enough on first read (I expected some
small measured percentage, comfortably under 0.5%, not literally zero) that
I did not trust it on the first green run — the whole point of Step 3 is
that a pass can mean the instrument is blind, and a *perfect* pass is the
shape that failure mode takes most convincingly. I did the extra
full-canvas/no-mask check and the blend-arithmetic check above specifically
to rule that out before writing this report, rather than accepting a
suspiciously clean number at face value. I cannot rule out that Impeller's
GPU/MSAA path (which this instrument does not exercise — `flutter_test`
renders through software Skia) produces a visible seam that software Skia's
`drawVertices` does not; that gap exists for every golden in this
repository, not just this one, and is outside what this task's declared
instrument can measure. The rule was declared against this exact
instrument, and this instrument reports zero. That gap turned out to be
exactly right, and turned out to be checkable directly rather than only
suspected — see the addendum immediately below, added after code review.

## Addendum (post-review): why the instrument reads zero either way

Code review on this task confirmed the fixture, the measurement, the
decision and Step 3's transcript, and raised one finding: Step 3's forced
seam (every triangle emitted twice, full coverage) proves the instrument
catches a gross double-draw, not the specific partial-coverage-on-a-shared-
edge mechanism mode 2 predicts. That distinction matters, so I built a
direct probe and ran it for real rather than taking the reviewer's numbers
on faith — the transcript below is from my own run, independently
reproducing what the reviewer reported.

**Setup.** `Canvas.drawVertices` driven directly, no `VerticesDrawSink`
involved: two triangles sharing a diagonal edge from `(100,100)` to
`(300,220)` — the exact shape a shared triangulation edge takes — filled
translucent at `argb = 0x803366CC`, the same alpha this task's rule uses.

**Probe 1 — does the antialiasing flag do anything on `drawVertices`?**
Captured once with `Paint.isAntiAlias = true`, once `false`:

```
diffPixels(bytes)=0 maxDelta=0
```

Byte-identical. The same two-triangle rectangle is also byte-identical to a
single `drawPath` fill of the same outer rectangle:

```
diffPixels(bytes)=0 maxDelta=0
```

**Probe 2 — does the internal diagonal show a coverage ramp at all?**
Sampled six device pixels straddling the diagonal, in the `drawVertices`
capture (`isAntiAlias: true`):

```
vertices (150,130) = 153,178,229,255
vertices (150,131) = 153,178,229,255
vertices (150,132) = 153,178,229,255
vertices (199,160) = 153,178,229,255
vertices (200,160) = 153,178,229,255
vertices (201,160) = 153,178,229,255
```

Every one reads the flat, fully-covered fill colour — no ramp, no partial
value, at any of them. For contrast, the *same slope* filled by
`Canvas.drawPath` (one triangle, same hypotenuse), sampled at the identical
coordinates:

```
path     (150,130) = 224,232,247,255
path     (150,131) = 255,255,255,255
path     (150,132) = 255,255,255,255
path     (199,160) = 255,255,255,255
path     (200,160) = 224,232,247,255
path     (201,160) = 167,189,233,255
```

Real partial-coverage values (`224,232,247` and `167,189,233`, both between
white and the full-coverage colour) exist on `drawPath`, at coordinates
where `drawVertices` shows nothing but flat colour or flat white.

**Reading.** `flutter_test`'s software Skia does not implement
per-primitive antialiasing for `drawVertices` in this environment,
independent of the `isAntiAlias` paint flag. Mode 2's predicted mechanism —
two triangles each contributing partial coverage to a shared edge pixel,
compounding into a double blend — has no partial coverage to compound in
this instrument, on any geometry, not only `fill_seam_test.dart`'s fixture.
The `0.000%` `fill_seam_test.dart` measured is exactly what this instrument
would read whether or not the mode-2 seam is real on Impeller/GPU.

**Pinned as a permanent regression, not left only in this report.** Added
`packages/jet_cad_2d_flutter/test/drawvertices_antialiasing_test.dart`,
committed alongside this addendum. It asserts the two probes above as
`expect`s: `isAntiAlias` changes nothing on `drawVertices`, and the same
slope shows a genuine partial-coverage pixel under `drawPath` but never
under `drawVertices`. Chose to commit this rather than leave the finding
only in prose because a report is read once and then archived, while a test
runs on every future change — if a Skia upgrade in this environment ever
starts antialiasing `drawVertices`, this test goes red *before* anyone
reads `fill_seam_test.dart`'s stale `0.000%` as settled, and the comment
block at the top of the file says explicitly what to do next
(re-measure `fill_seam_test.dart`). Ran it directly rather than trusting
the diagnostic script above verbatim, since a probe worth pinning is worth
re-verifying as the actual committed artifact:

```
$ flutter test test/drawvertices_antialiasing_test.dart
00:00 +0: drawVertices ignores isAntiAlias: the paint flag changes nothing
00:00 +1: drawVertices shows no coverage ramp on a shared edge where drawPath does
00:00 +2: All tests passed!
```

## Suite output

```
$ cd packages/jet_cad_2d_flutter && flutter test
00:03 +273 ~1: All tests passed!

$ flutter test --tags golden
00:02 +29: All tests passed!

$ flutter analyze
No issues found! (ran in 1.2s)

$ dart format --output=none --set-exit-if-changed .
Formatted 48 files (0 changed) in 0.09s

$ cd packages/jet_cad_2d && CI=true dart test
00:03 +771: All tests passed!

$ dart analyze
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.19s
```

`git status --porcelain` before committing showed only
`packages/jet_cad_2d_flutter/test/fill_seam_test.dart` as untracked; no
`analysis_options.yaml` changes, no pre-existing PNG touched.
