# Task 10 report: Goldens on both backends

## What was implemented

- `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart` — the
  canvas branch of a new `_rung(tester, doc, halfSpan, name, backend)` helper
  calls the existing `_at(doc, halfSpan)` unchanged, so the five canvas PNGs
  stay pixel-identical to what they were before this task. The vertices
  branch builds `DraftCanvas(backend: RenderBackend.vertices)` directly (no
  `_at`), attaches a `TriangleRasterizer` as `vertices.observer`, forces a
  second real paint (see "Two real bugs" below), and compares the rasterized
  image against `vertices/dash_ladder_$name.png`. `main()` now loops over
  `RenderBackend.values` as well as the five rungs — 10 tests instead of 5.
- `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart` —
  the same `_rung` shape, canvas branch delegating to the existing `_framed`.
  5 → 10 tests. Its doc comment states the fixture reuse's known consequence
  verbatim from the brief: the vertices golden carries the rung's polyline
  and none of its glyphs.
- `packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart` —
  this file never builds a `DraftCanvas`; it drives `CanvasDrawSink` directly
  already, so I added `_renderVertices(tester, doc, index, camera)`, which
  drives `VerticesDrawSink` directly the same way — build the sink with a
  `Canvas(PictureRecorder())`, run `DraftPainter.paint`, call `sink.flush()`,
  discard the recording, and rasterize. `devicePixelRatio` is pinned at `1.0`
  (documented in the function's doc comment) since there is no widget
  `MediaQuery` to read it from, matching the canvas half's own `1.0`
  (`kGoldenViewport`-sized PNGs, no retina scaling). Both `testWidgets` gained
  a second `matchesGoldenFile` call per fixture inside their existing loops —
  test count unchanged (2 → 2), golden-comparison count 3 → 6 (paper-space
  loop: 3 zooms × 2 backends; anisotropy: 1 × 2).
- `packages/jet_cad_2d_flutter/test/golden/vertices/*.png` — 14 new PNGs, one
  per existing fixture.
- `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart` — the deferred
  minor from Task 1. `'one sink serves every paint'` now passes
  `backend: RenderBackend.canvas` explicitly, with a comment explaining why:
  under the vertices backend `CanvasDrawSink` is only the text fallback, and
  `state.sink.canvas` would still read back normally there because
  `_DraftCustomPainter.paint` binds it before branching — so the un-pinned
  test passed while asserting the wrong thing about the fallback rather than
  about the sink that actually paints.

I did **not** touch `VerticesDrawSink`, `CanvasDrawSink`, or any other `lib/`
file — every mutation below was applied to a `cp`-backed copy and restored
before the next step, verified by `diff` against the backup and
`git status --porcelain`.

## Two real bugs found and fixed in the test harness (not in the sink)

Neither is a defect in Tasks 1–9; both are properties of driving a widget
test's fake-async binding through a route the plan hadn't exercised before.
I want to be explicit that I found these by actually running the code and
looking at the output, not by reasoning about it — the first cost about 20
minutes of `flutter test` runs that looked like hangs before I isolated it
with five throwaway probe files (built, run, deleted; never committed).

### Bug 1 — `rasterizer.toImage()` hangs forever after a widget has painted

The brief's Step 1 code calls `await rasterizer.toImage()` directly inside
`testWidgets`. Under `flutter test`, once `AutomatedTestWidgetsFlutterBinding`
has pumped a real widget frame, that binding's fake-async test zone never
delivers the completion callback `ui.decodeImageFromPixels` schedules on a
real engine thread — the `await` hangs indefinitely, no exception, 0% CPU.

Isolated with a minimal repro (`test/zzprobeN_test.dart`, built and deleted,
never committed):

```
test('decodeImageFromPixels alone completes', ...);       // fast, passes
testWidgets('... after a real paint', (tester) async {
  await tester.pumpWidget(...);                            // a real paint
  await ui.decodeImageFromPixels(...);                      // hangs forever
});
```

Confirmed by killing the hung process and reading back `flutter_tools`' own
timeout report: `01:54 ... did not complete`. Wrapping the same call in
`tester.runAsync(...)` — which steps outside the fake-async zone for exactly
this kind of real, engine-driven asynchrony — fixed it in the same probe.
Applied to all three files: `(await tester.runAsync(rasterizer.toImage))!`
(dash/text ladder) and `(await tester.runAsync(rasterizer.toImage))!` inside
`_renderVertices` (stroke width).

### Bug 2 — the brief's own "pump twice" sequence never triggers the second paint

Once Bug 1 was fixed, the vertices goldens generated cleanly but several came
out **blank** (0/120000 opaque pixels — confirmed by decoding the PNGs and
counting alpha≠0 pixels, not by eyeballing). Cause: `_DraftCustomPainter`'s
`shouldRepaint` is unconditionally `false` and its `repaint` listenable never
fires on its own between the two pumps the brief's `_rung` calls for (nothing
about the document or camera changes). A bare `tester.pump()` after attaching
the observer therefore finds the render object clean and skips the repaint —
the observer is live but nothing ever calls it, so `rasterizer.pixels` stays
all-zero and `toImage()` produces a blank surface that still "passes" because
there was no comparison to fail against on generation.

Confirmed with another throwaway probe: the exact same fixture, camera, and
pump sequence, read back `triangleCount == 0` after the second pump. Adding
one line before that pump —

```dart
tester
    .renderObject<RenderObject>(find.descendant(
        of: find.byType(DraftCanvas), matching: find.byType(CustomPaint)))
    .markNeedsPaint();
```

— forces the *same* picture to paint again, this time through the attached
observer, and the same probe read back 272 real triangles. Applied to both
`_rung` helpers (dash and text ladder); `stroke_width`'s `_renderVertices`
never goes through a widget paint at all, so it isn't affected.

Both bugs are explained inline at the exact line they were fixed, in all
three modified test files — not just in this report.

## What I saw in each PNG

Every PNG below was opened with the `Read` tool and looked at; for the ones
where "looks blank" mattered I also decoded the PNG and counted non-transparent
pixels rather than trust a thumbnail.

- **`dash_ladder_1.png` / `vertices/dash_ladder_1.png`** — both show the same
  hexagon-like silhouette: six dashed horizontal rules and the dashed circle
  cropped tight (halfSpan 60). Rung for rung the shapes match; the vertices
  version's dash strokes read very slightly bolder, consistent with the
  `kMinStrokeDevicePixels` floor (see divergences below).
- **`dash_ladder_2.png` / `vertices/`** — full circle visible this time, both
  backends draw the same dashed circle crossing six dashed rules. No visible
  notch or crack at any dash boundary in either.
- **`dash_ladder_3.png` / `vertices/`** — a finer dash pattern at this zoom
  (halfSpan 400), consistent between backends.
- **`dash_ladder_4.png` / `vertices/`** — the dash collapse floor has kicked
  in: both backends draw what reads as solid horizontal lines with a small
  circle at the centre. This is the one dash_ladder rung where **both**
  mutations below moved the golden — consistent with the collapse floor
  drawing the circle as one continuous closed sweep rather than many
  independent dash arcs at this zoom (see "Mutations" for why that matters).
- **`dash_ladder_5.png` / `vertices/`** — fully collapsed: solid lines and a
  small dot-like circle, same in both.
- **`stroke_width_0_5x.png`, `_1_0x.png`, `_8_0x.png`, `anisotropy_bypass.png`
  and their `vertices/` counterparts** — crosshair-plus-square at three
  zooms, and the conformal/8:1-stretched shape pair. All four pairs match
  visually: same crosshair, same square, and on `anisotropy_bypass` both
  instances (conformal and 8:1) draw the *same* stroke width on every edge in
  **both** backends — the bypass is not merely present in the canvas
  rendering, the vertices sink (whose own per-axis-perpendicular math is what
  the bypass compares against) draws the identical shape. No visible corner
  cracks on the rectangular corners in either.
- **`text_ladder_1.png`** (canvas) shows four "JUSTIFY" rows in four colours
  against a faint anchor rule. **`vertices/text_ladder_1.png` is entirely
  blank — 0 of 120,000 pixels have any alpha.** See "A real finding" below.
- **`text_ladder_2.png`** (canvas) shows "Apy" four times against a
  horizontal anchor rule. **`vertices/text_ladder_2.png` is also entirely
  blank.**
- **`text_ladder_3.png` / `vertices/`** — canvas shows four "ROTATE" cells
  each with a small cross anchor; vertices shows the four crosses (60 opaque
  pixels, all `0xC00000`) with no glyphs, exactly as the file's own doc
  comment predicts.
- **`text_ladder_4.png`** (canvas) shows two rows of "HI" pairs (width
  factor × oblique) each over its own anchor rule. **`vertices/text_ladder_4.png`
  shows only one of the two rules** (342 opaque pixels, all in row 102 —
  the `oblique: 0.0` row's rule; the `oblique: 0.3` row's rule is entirely
  absent).
- **`text_ladder_5.png`** (canvas) shows "STAIR" and its mirrored "ЯIATS"
  between two vertical anchor rules. **`vertices/text_ladder_5.png` shows
  only the right-hand rule**, not the left one.

## A real finding: four of the five text-ladder vertices goldens pin less than they look like they do, and two pin nothing at all

This is not a `VerticesDrawSink` defect and I did not touch the sink to
"fix" it. It's a consequence of three things stacking:

1. `_rule`'s lineweight is `9` (0.09 mm) — at `kLogicalPixelsPerMm ≈ 3.7795`
   and this widget's device pixel ratio, the *logical* stroke width computes
   below `kMinStrokeDevicePixels / devicePixelRatio`, so `_halfWidthFor`
   floors it to a half-width of about a quarter of a logical pixel — already
   the thinnest line the vertices sink ever draws.
2. The text-ladder fixtures anchor their rules at exact, round world
   coordinates (`x: 100` against a `0–200` world width, `y: 75` against a
   `0–150` world height, etc.) and `kWorld`'s aspect exactly matches
   `kGoldenViewport`'s, so the camera fit is an exact `2.0×` scale with no
   letterboxing — meaning several of these anchors land within a
   sub-pixel's width of an exact screen-space pixel boundary.
3. `TriangleRasterizer` is explicitly a **coverage-only, no-anti-aliasing**
   scan-converter (Task 9's own design) — a pixel is inked only if its exact
   centre falls inside a triangle. It has no partial-coverage fallback the
   way MSAA (what Impeller actually uses in production) does.

A quarter-pixel-wide band centred within a quarter-pixel of a pixel boundary
can miss every pixel centre along its entire length. That is exactly what
happened for the `x: 100` rule (rung 1), the `y: 75` rule (rung 2), the
`oblique: 0.3` row's rule (rung 4), and the left-hand rule (rung 5) — each
independently confirmed by decoding the PNG and finding zero opaque pixels on
the affected line, not by eyeballing a thumbnail. I did not chase down why
some near-boundary rules survive (rung 4's other rule, rung 5's right-hand
rule) and others don't; the arithmetic is sensitive to sub-pixel differences
in the accumulated transform that I did not think were worth a second
investigation once the mechanism was clear from the ones that failed.

**This means `vertices/text_ladder_1.png` and `vertices/text_ladder_2.png`
pin literally nothing beyond "the test didn't throw"** — a real instance of
the exact failure mode the task brief calls out by name. I left them as
generated rather than "fixing" the golden, because:

- The fixtures are shared with the canvas backend by design (the brief's
  entire point is "the existing 14 PNGs keep their fixtures"), so changing
  the anchor coordinates to dodge this would also move the 14 pre-existing
  canvas PNGs, which the brief explicitly forbids regenerating.
- The cause is confined to the synthetic, no-AA test rasterizer — a real
  Impeller/MSAA raster in production would show partial coverage on all of
  these lines. This is a golden-harness artifact, not evidence that
  `VerticesDrawSink` drew the wrong thing.

I'm flagging it prominently rather than quietly accepting it. If a future
task wants these two goldens to pin something, the fix belongs in the
fixture (an anchor coordinate that isn't an exact multiple of the pixel
grid), not in the sink or the rasterizer.

## Mutations run against the sink, with real transcripts

Per `cp` aside → mutate → run (no `--update-goldens`) → record → restore →
`diff` against backup → `git status --porcelain` → re-run clean.

### Mutation 1 — skip the bevel triangle in `_emitJoin`

```
$ cp lib/src/vertices_draw_sink.dart /tmp/.../vertices_draw_sink.dart.bak
$ sed -i '' 's/    _emitTriangle(vx, vy, ax, ay, bx, by, argb);/    \/\/ MUTATED: bevel triangle skipped\n    \/\/ _emitTriangle(vx, vy, ax, ay, bx, by, argb);/' lib/src/vertices_draw_sink.dart
$ flutter test --tags golden
...
Failing tests:
  .../dash_ladder_golden_test.dart: dash ladder rung 4 (RenderBackend.vertices)
  .../stroke_width_golden_test.dart: an anisotropic instance draws exact per-axis widths
  .../stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
```

Exact pixel diffs, from re-running each file individually:

```
Golden "vertices/stroke_width_8_0x.png": Pixel test failed, 0.00%, 3px diff detected.
Golden "vertices/anisotropy_bypass.png": Pixel test failed, 0.01%, 6px diff detected.
Golden "vertices/dash_ladder_4.png": Pixel test failed, 0.00%, 2px diff detected.
```

Three vertices goldens moved under a mutation that removes the bevel
triangle at every mitred join and leaves only the tip — exactly the
"hairline crack" the join code's own comment describes, and small pixel
counts because the affected corners are a handful of pixels each at this
resolution.

Restored: `cp` from backup, `diff` reported no difference, `git status
--porcelain` on `lib/` was empty, and a clean re-run of `flutter test --tags
golden` passed 23/23 again.

### Mutation 2 — always skip the seam-closing branch in `_endRun`

```
$ cp lib/src/vertices_draw_sink.dart /tmp/.../vertices_draw_sink.dart.bak
$ sed -i '' 's/    if (!closed || !_runHasDirection) return;/    if (true) return; \/\/ MUTATED: seam join always skipped/' lib/src/vertices_draw_sink.dart
$ flutter test --tags golden
...
Failing tests:
  .../dash_ladder_golden_test.dart: dash ladder rung 4 (RenderBackend.vertices)
```

```
$ flutter test --tags golden test/golden/dash_ladder_golden_test.dart
Golden "vertices/dash_ladder_4.png": Pixel test failed, 0.00%, 4px diff detected.
```

Only rung 4 moved. That is expected, not a weak result: the dash-ladder
circle is dashed, and dashing almost certainly breaks the sweep into many
separate open (`closed: false`) arcs at every zoom where individual dashes
are still visible (rungs 1–3) — `_endRun`'s existing `if (!closed || ...)
return;` guard already short-circuits before this mutation's line runs for
any of those, so the mutation is a no-op there by construction, not because
the golden failed to catch it. Rung 4 is exactly the zoom where the dash
collapse floor (mentioned in the fixture's own doc comment) makes the dashed
pattern draw as what reads visually as one solid line — consistent with the
geometry layer handing the sink one continuous **closed** sweep instead of
many dash arcs at that zoom, which is the only way this mutation's line
could be reached at all. I did not go further to confirm this in the
painter's dash code — it is the most consistent explanation for why exactly
one rung, and the same one both mutations agree on, moves.

Restored: `cp` from backup, `diff` reported no difference, `git status
--porcelain` on `lib/` was empty, and a clean re-run of `flutter test --tags
golden` passed 23/23 again.

Both required mutations moved at least one golden with real, nonzero pixel
diffs. I did not additionally test whether the seam-join mutation moves
anything through a *non-dashed* closed shape, because no golden fixture in
this suite draws one (the `anisotropy_bypass`/`stroke_width` closed-looking
polylines all reach the painter with `closed: false`, per fact 2 in the
design spec) — that gap is inherent to the fixtures Task 10 was told to
reuse, not something this task can close without adding a new fixture, which
was out of scope.

## What happened to the 14 existing canvas goldens

Unchanged. `git status --short` before staging showed no `M` against any
pre-existing `.png` at any point in this task, including after both
mutation runs (each mutation run compares against the *checked-in* canvas
PNGs too, since `flutter test --tags golden` runs both backends together,
and none of the three mutation-affected tests were canvas-backend tests).
`git diff --stat -- 'packages/jet_cad_2d_flutter/test/golden/*.png'` was
empty at every check.

## Differences between the two sets, and the spec's permitted list

- **Sub-pixel strokes (permitted).** `CanvasDrawSink` has no
  `kMinStrokeDevicePixels` floor at all; `VerticesDrawSink` clamps to 1
  device pixel and fades alpha below it. Visible directly in the
  `dash_ladder` rungs (vertices dashes read slightly bolder) and is the root
  cause of the text-ladder blank-golden finding above — the vertices sink's
  floor is what keeps those rules' *alpha* at full strength even though
  their *width* underflows to sub-pixel, which is a detail the canvas
  backend's own, unfloored math handles differently (and, per the spec
  table, that's the one divergence direction that's genuinely ambiguous:
  "vertices, but untestable by comparison").
- **Point shape, anti-aliasing, overlapping translucent strokes (permitted,
  per the spec table)** — none of these three are exercised by anything I
  observed differing in this task's fixtures: no point markers in any of
  these six fixtures, anti-aliasing differences are exactly what a coverage
  rasterizer's design already accounts for (Task 9's own "not an appearance
  golden" framing), and none of the corpora carry translucent overlapping
  strokes.
- **Anisotropic stroke width (permitted, vertices authoritative)** —
  `anisotropy_bypass.png` is exactly the fixture built to exercise this, and
  both backends draw the *same* uniform width on every edge of the 8:1
  stretched instance, which is the passing case, not the divergent one (the
  bypass in `CanvasDrawSink` exists precisely so the two backends agree
  here).
- **Nothing outside the five-item list showed up.** The only other
  difference I found — the four text-ladder rules going missing — is a
  property of the coverage-only test rasterizer interacting with exact
  pixel-grid-aligned fixture coordinates, not a drawing disagreement between
  the two backends' actual geometry or alpha math.

## Full three-package gate output

```
$ cd packages/jet_cad_2d && dart test
...
00:02 +720: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.13 seconds.
```

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:02 +231 ~1: All tests passed!
```
(221 baseline + 10 new backend-parameterized dash/text-ladder tests = 231;
stroke_width's test count is unchanged, 3 → 3, since its new backend
comparisons live inside the existing loops. The pre-existing 1 skip is
unchanged.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)

$ dart format --output=none --set-exit-if-changed .
Formatted 42 files (0 changed) in 0.05 seconds.
```

```
$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 0.8s)

$ dart format --output=none --set-exit-if-changed lib integration_test
Formatted 2 files (0 changed) in 0.01 seconds.
```

All three legs green. `git status --porcelain` before the commit showed only
the intended files — no `analysis_options.yaml` drift (three separate `flutter
pub get` runs during this task each rewrote `packages/jet_cad_2d/`,
`packages/jet_cad/` and `apps/dev_harness/`'s `analysis_options.yaml`; all
three were `git checkout --`'d back before any commit, confirmed clean by
`git status --short | grep analysis_options` returning nothing each time).

## Files changed

- `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart`
  (backend loop, `_rung` helper)
- `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart`
  (backend loop, `_rung` helper)
- `packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart`
  (`_renderVertices` helper, both `testWidgets` extended)
- `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart` (Task 1's
  deferred minor: `backend: RenderBackend.canvas` pinned explicitly)
- `packages/jet_cad_2d_flutter/test/golden/vertices/*.png` (14 new)

No `lib/` file was modified in the final state — the two mutations above were
applied and reverted via `cp`, never `git checkout`, and confirmed byte-identical
to the pre-mutation backup by `diff` before moving on each time.

## Self-review findings

- The canvas branch of both `_rung` helpers calls the file's pre-existing
  `_at`/`_framed` function completely unchanged, so there is no code path by
  which this task's edits could have altered a canvas golden's pixels — the
  `git diff --stat` on the 14 pre-existing PNGs being empty is a consequence
  of that, not a coincidence I had to get lucky on.
- Both hangs (Bug 1 and Bug 2 above) are explained inline, at the exact line
  that fixes them, in all three test files — a future reader hitting the same
  hang doesn't have to rediscover the cause.
- `stroke_width_golden_test.dart`'s `_renderVertices` reuses `cameraAt(zoom)`
  and `ViewportTransform.fit(doc.extents, kGoldenViewport)` computed once per
  fixture and passed to both the canvas and vertices render paths, rather
  than recomputed twice — guards against the two paths silently drifting
  onto different cameras if either call site is edited later.
- I did not add a differential/pixel-diff *assertion* comparing the two
  backends' images to each other (e.g. "vertices and canvas agree within N
  pixels except at documented divergences") — the brief asks for two
  independent golden sets, not a cross-backend comparison test, and Task 11
  (per the plan's table of contents, not read in detail) looks like the
  place a `sink_comparison.dart`-style membership check belongs.
- Five scratch probe files (`test/zzprobeN_test.dart`) were created, run, and
  deleted during root-causing the two bugs above; `git status --short` at
  every checkpoint after each was confirmed to show no such file, and the
  final `git status --short` before committing showed only the intended
  changes.

## Concerns

- **`vertices/text_ladder_1.png` and `vertices/text_ladder_2.png` are
  entirely blank** (0/120,000 opaque pixels each) — see "A real finding"
  above. I judged this reportable-and-leave-as-is rather than
  reportable-and-fix, since fixing it would mean touching a fixture shared
  with the canvas backend, which risks moving one of the 14 protected PNGs;
  I did not attempt it. A reviewer may disagree with that call.
- **`vertices/text_ladder_4.png` and `vertices/text_ladder_5.png`** each pin
  only one of their two thin anchor rules, for the same root cause.
- The seam-join mutation (Mutation 2) only moved one golden, and I've
  reasoned rather than proven why the other four dash-ladder rungs are
  immune (dashing keeps them at `closed: false`, so the mutation's line is
  unreached). I did not add instrumentation to confirm this directly — it
  would have meant either a temporary print in the sink or reading the
  painter's dash-splitting code, and I judged the pixel-diff evidence
  (one rung moves, consistently, under two independently-written mutations
  that both touch closed-run behaviour) sufficient without it.
- Two genuine test-infrastructure bugs (both described in detail above) had
  to be found and fixed before this task's actual deliverable — the goldens
  — could even be generated. Neither was anticipated by the brief's Step 1
  code, which would have hung indefinitely (Bug 1) or silently produced
  blank goldens with all ten vertices tests reporting green (Bug 2) if
  followed literally without the debugging in between.

---

## Fix round: review response

**Not approved, narrowly.** The review confirmed the code was sound and the
harness fixes genuine, but found the *cause* I gave for the blank goldens was
wrong, measured with a `FlushObserver` rather than argued: dpr in the ladder
widget tests is **3.0**, not the 2.0 I had assumed from PNG dimensions.
`_rule`'s lineweight 9 → 0.3402 logical px; `floorLogical = 1.0/3.0 = 0.3333`,
so `_halfWidthFor` does **not** clamp and `_coveredArgb` does **not** fade —
`deviceWidth` is 1.02, above `kMinStrokeDevicePixels`. The sink emits the
rule correctly, at full alpha, at its true (thin) width. The actual bug:
`TriangleRasterizer` sampled pixel centres in **logical** pixels while the
sink's own width floor is a **device**-pixel quantity — a band that is a full
device pixel wide (1.02 px, what Impeller would rasterize and ink) can be
under half a *logical* pixel wide at dpr 3, and a logical-resolution,
no-AA, pixel-centre sampler can miss it along its entire length. The
reviewer proved this with a negative control: mutating `polyline` to emit no
geometry at all still left `text_ladder` rungs 1 and 2 green.

### Confirming the real dpr, not assuming it

Before touching code I re-measured rather than trusted my own report. Two
throwaway probes (built, run, deleted, never committed):

```
$ flutter test test/zzprobe_dpr_test.dart
ladder dpr = 3.0
stroke_width dpr = 3.0          # tester.view.devicePixelRatio, both shapes
```

```
$ flutter test test/zzprobe_dpr2_test.dart
dash_ladder-style vertices.devicePixelRatio = 3.0   # read off the live sink
dash_ladder-style tester.view.devicePixelRatio = 3.0
```

`tester.view.devicePixelRatio` is 3.0 in *every* shape, including under
`setSurfaceSize` — confirming the reviewer's number independently, from the
live field the widget actually set, not from re-deriving it. The review's
"stroke_width_golden_test.dart runs at dpr 1.0" refers to the explicit `1.0`
I already pass to `VerticesDrawSink` there (there is no widget's `MediaQuery`
in that file to read a real one from) — not to `tester.view.devicePixelRatio`,
which is 3.0 there too. I kept `1.0` for that file (matching the reviewer's
own corrected-claims list, which treats it as a given, not a target to fix)
but named it (`_kVerticesDevicePixelRatio`) and ran it through the same
resolution/scaling code path as the other two files, rather than a special
case, so the fix generalizes to both ratios instead of hardcoding "×3" only
where I happened to see it matter.

### Fix 1 — rasterize at device resolution

In all three files, `TriangleRasterizer` is now constructed at
`(kGoldenViewport * dpr).round()` instead of `kGoldenViewport.round()`, and
the `observer` scales every position by `dpr` before handing it to
`rasterizer.observe`. `dpr` is read back from
`key.currentState!.vertices!.devicePixelRatio` (dash/text ladder — the exact
value `MediaQuery.devicePixelRatioOf(context)` set on the sink the widget
built) or from the named `_kVerticesDevicePixelRatio` constant
(stroke_width — no widget to read one from). `TriangleRasterizer` itself was
not modified; the scaling is a small closure at each call site, matching the
review's own phrasing ("construct the rasterizer at device resolution...
scale the observed positions").

Regenerated all 14 vertices PNGs:

```
$ flutter test --tags golden --update-goldens test/golden/dash_ladder_golden_test.dart test/golden/text_ladder_golden_test.dart test/golden/stroke_width_golden_test.dart
...
00:00 +23: All tests passed!
```

Dimensions and opaque-pixel counts, decoded directly (not eyeballed):

| File | Dimensions | Opaque px (before fix) | Opaque px (after fix) |
|---|---|---|---|
| `vertices/dash_ladder_1.png` | 1200×900 (was 400×300) | 1905 | 17053 |
| `vertices/dash_ladder_2.png` | 1200×900 | 2561 | 21405 |
| `vertices/dash_ladder_3.png` | 1200×900 | 1590 | 17048 |
| `vertices/dash_ladder_4.png` | 1200×900 | 772 | 7638 |
| `vertices/dash_ladder_5.png` | 1200×900 | 220 | 1752 |
| `vertices/text_ladder_1.png` | 1200×900 (was 400×300) | **0** | 1528 |
| `vertices/text_ladder_2.png` | 1200×900 | **0** | 2096 |
| `vertices/text_ladder_3.png` | 1200×900 | 60 | 449 |
| `vertices/text_ladder_4.png` | 1200×900 | 342 (1 of 2 rules) | 3078 (both) |
| `vertices/text_ladder_5.png` | 1200×900 | 96 (1 of 2 rules) | 858 (both) |
| `vertices/stroke_width_*.png`, `anisotropy_bypass.png` | 400×300 (unchanged, dpr 1) | unchanged | unchanged (byte-identical) |

`git diff --stat` on `packages/jet_cad_2d_flutter/test/golden/*.png`
(the 14 pre-existing, non-`vertices/` PNGs) is empty at every checkpoint —
none moved.

**Looked at every regenerated PNG.** `dash_ladder_1.png` and `_2.png` (device
resolution) are visibly crisper than before and match their canvas
counterparts rung for rung — the hexagon silhouette and cropped circle in
rung 1, the full dashed circle in rung 2, no notch or crack visible at any
dash boundary. `dash_ladder_3/4/5` likewise track their canvas siblings
through the collapse floor (fine dashes → solid-looking lines → a single
bar-and-dot at the most extreme zoom). `text_ladder_1.png` now shows the
vertical anchor rule (previously nothing); `text_ladder_2.png` now shows the
horizontal anchor rule; `text_ladder_3.png` now shows all four crosses
(previously one) at their single colour `0xC00000`, confirmed by decoding —
no stray colours; `text_ladder_4.png` now shows both anchor rules (row 307
and rows 677–678, decoded independently, not merely "looks like two lines");
`text_ladder_5.png` now shows both vertical rules (columns 143–144 and 1084).
None of `stroke_width`'s or `anisotropy_bypass`'s vertices PNGs changed a
byte — expected, since dpr 1.0 there means the fix is a no-op.

### Fix 2 — minimum-ink assertion

Added `expect(rasterizer.pixels.any((p) => p != 0), isTrue, reason: ...)`
immediately before each `matchesGoldenFile` call: `dash_ladder_golden_test.dart`
(one, in `_rung`), `text_ladder_golden_test.dart` (one, in `_rung`), and
`stroke_width_golden_test.dart` (two — inside the three-zoom loop and in the
anisotropy test — `_renderVertices` now returns `(ui.Image, TriangleRasterizer)`
so the caller can assert on the rasterizer's own pixels before trusting the
image comparison).

### Ran the reviewer's negative control myself, against all 14

`cp` the sink aside, mutate `polyline` to `return;` unconditionally before
any of its body runs (emitting no geometry at all — arcs/circles/points are
untouched, since they go through `_flatten`/`_beginRun`, not `polyline`),
run every golden file, restore, `diff` against backup, confirm clean.

```
$ sed -i '' -e mutate-polyline-to-return-immediately lib/src/vertices_draw_sink.dart
$ flutter test --tags golden
...
Failing tests:
  dash_ladder_golden_test.dart: dash ladder rung 1 (RenderBackend.vertices)
  dash_ladder_golden_test.dart: dash ladder rung 2 (RenderBackend.vertices)
  dash_ladder_golden_test.dart: dash ladder rung 3 (RenderBackend.vertices)
  dash_ladder_golden_test.dart: dash ladder rung 4 (RenderBackend.vertices)
  dash_ladder_golden_test.dart: dash ladder rung 5 (RenderBackend.vertices)
  text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
  text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.vertices)
  text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.vertices)
  text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.vertices)
  text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.vertices)
  stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
  stroke_width_golden_test.dart: an anisotropic instance draws exact per-axis widths
```

All 12 vertices *tests* failed — dash (5/5), text (5/5), stroke_width (2/2).
That covers 14 golden *files*, but `stroke_width`'s three-zoom test is a
`for` loop whose `expectLater` throws on the first mismatch (0.5x) and
aborts, so the file-level failure alone only directly proves 0.5x and
`anisotropy_bypass` went blank, not 1.0x/8.0x independently. Rather than
assert the other two "obviously" also fail, I checked: a second throwaway
probe rebuilt all four stroke_width-file fixtures (three zooms plus
anisotropy) under the same live mutation and read `rasterizer.pixels.any(...)`
for each independently, without the loop's early abort:

```
$ flutter test test/zzprobe_control_test.dart
stroke_width_0_5x inked = false
stroke_width_1_0x inked = false
stroke_width_8_0x inked = false
anisotropy_bypass inked = false
```

**All 14 vertices goldens go dark under a mutation that draws no polylines**
— the fixed instrument now catches the class of defect it was built for.
Restored via `cp`; `diff` against the backup showed no difference; a clean
`flutter test --tags golden` afterward passed 23/23.

### Re-ran both original mutations post-fix

Same `cp`-aside → mutate → run → record → restore → `diff` → clean-rerun
discipline as the first submission, confirming both still catch real defects
at the new (larger, more sensitive) resolution:

**Bevel triangle skipped** (`_emitJoin`, `_emitTriangle(vx, vy, ax, ay, bx, by, argb);` → commented out):

```
Golden "vertices/stroke_width_0_5x.png": Pixel test failed, 0.00%, 3px diff detected.
Golden "vertices/stroke_width_1_0x.png": Pixel test failed, 0.00%, 3px diff detected.
Golden "vertices/stroke_width_8_0x.png": Pixel test failed, 0.00%, 3px diff detected.
Golden "vertices/anisotropy_bypass.png": Pixel test failed, 0.01%, 6px diff detected.
Golden "vertices/dash_ladder_4.png": Pixel test failed, 0.00%, 6px diff detected.
```

Five goldens moved (was three, pre-fix, at the coarser logical resolution —
all three stroke_width zooms are now independently visible in the output
rather than only the first one the loop happened to report). Restored via
`cp`; `diff` clean; re-run 23/23.

**Seam join always skipped** (`_endRun`, `if (!closed || !_runHasDirection) return;` → `if (true) return;`):

```
Golden "vertices/dash_ladder_4.png": Pixel test failed, 0.00%, 27px diff detected.
```

Same single rung as before (27px now vs 4px pre-fix — more sensitive at
device resolution), for the same reason given in the original submission:
dashing keeps every other rung's circle arcs at `closed: false`, so the
mutated line is unreached there; rung 4 is where the dash collapse floor
draws the circle as one continuous closed sweep. Restored via `cp`; `diff`
clean; re-run 23/23.

### Fix 3 — corrected causal record

The original report's "A real finding" section attributed the blanks to
`vertices_draw_sink.dart:499`'s clamp (`_halfWidthFor`) and `:515`'s fade
(`_coveredArgb`). **Neither fires for these fixtures.** `_rule`'s lineweight
9 computes to 0.3402 logical px against a floor of 0.3333 (dpr 3) — just
*above* the floor, so no clamping — and `deviceWidth` 1.02 is above
`kMinStrokeDevicePixels` 1.0, so no fade. The sink draws the rule at its
true, correct, unclamped, full-alpha width; the rasterizer failed to see it.
The report above (the "Fix round" section) is the corrected record. The
original "A real finding" and "Differences... permitted list" sections below
are superseded by it and are being read as history, not as the current
account — I have not deleted them, per not rewriting history, but the
correct causal explanation is the one in this fix round.

**The related claim about bolder vertices dashes was also wrong.** They are
not "consistent with the `kMinStrokeDevicePixels` floor" — that floor is
never reached by any fixture in this suite: the text ladder's rules compute
to 0.3402 logical px against a 0.3333 floor (dpr 3, just above), the dash
ladder's lineweight-30 dashes compute to 1.134 logical px (well above), and
`stroke_width`'s 0.5 mm lineweight computes to 4.0 device px at its dpr 1.0
(far above). The boldness is the no-AA rasterizer snapping a sub-2-px band
to a whole number of rows/columns, nothing more. **The spec's permitted
sub-pixel-stroke divergence (`kMinStrokeDevicePixels`/`_coveredArgb` vs
`CanvasDrawSink`'s unfloored math) is therefore not exercised anywhere in
this suite** — worth stating plainly, since without this correction a reader
would assume the boldness *was* that divergence and that it was covered.

### Fix 4 — doc comment

`text_ladder_golden_test.dart`'s "carries the rung's polyline" claim is
**true after Fix 1** — verified by decoding every PNG and counting pixels,
not by re-reading the claim and hoping: rung 3 shows all four crosses, rung
4 both rules, rung 5 both rules, matching their canvas counterparts' anchor
geometry exactly. Updated the comment to say "rule or crosses" (rungs 4 and
5 each have two rule polylines, not one) and added a note that this was
verified by decoding, plus a pointer to why it wasn't always true.

### Deferred item taken: a framing-difference comment

Added to both `_rung` doc comments (dash and text ladder): `_at`/`_framed`
match on `find.byKey(kCanvasKey)`, which sits on the outer `SizedBox`, and
`matchesGoldenFile` walks up to the nearest `RepaintBoundary` from there —
not necessarily the one `DraftCanvas` owns internally — while the vertices
path rasterizes exactly `DraftCanvas`'s own surface. The two PNGs are not
pixel-registered captures of the same boundary. I did not chase down the
exact mechanism behind the canvas set's own capture dimensions (800×600 for
the ladders) beyond confirming they are unaffected by this task's changes;
per the review, the tree-sharing between the two backends' widget
constructions stays as it is.

### Full three-package gate, after the fix round

```
$ cd packages/jet_cad_2d && dart test
...
00:02 +720: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.13 seconds.
```

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:02 +231 ~1: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)

$ dart format --output=none --set-exit-if-changed .
Formatted 42 files (0 changed) in 0.05 seconds.
```

```
$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 0.8s)

$ dart format --output=none --set-exit-if-changed lib integration_test
Formatted 2 files (0 changed) in 0.01 seconds.
```

All three legs green, same counts as the first submission (no test was added
or removed by this fix round — only assertions inside existing tests).
`git status --porcelain` before committing showed only the three modified
test files and the 10 changed `vertices/*.png` (the 4 stroke_width-file ones
are byte-identical, so `git add` did not stage them as changed) — no
`analysis_options.yaml` drift.

### Files changed (fix round)

- `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart`
  (device-resolution rasterizer, position scaling, min-ink assertion,
  framing-difference comment)
- `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart`
  (same, plus the corrected "carries the rung's polyline" comment)
- `packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart`
  (named `_kVerticesDevicePixelRatio`, `_renderVertices` returns the
  rasterizer alongside the image, min-ink assertion at both call sites)
- `packages/jet_cad_2d_flutter/test/golden/vertices/dash_ladder_{1..5}.png`,
  `text_ladder_{1..5}.png` (regenerated at device resolution; `stroke_width_*`
  and `anisotropy_bypass` unchanged, byte-identical)

No `lib/` file changed in the final state. Three mutations were applied and
reverted via `cp` during this fix round (the polyline no-op control, and
re-runs of both original mutations); each was confirmed byte-identical to
the pre-mutation backup by `diff` before moving on, and `git status
--porcelain` on `lib/` was empty at every checkpoint.

Commit: `002b5e0` "fix: rasterize the vertices goldens at device resolution".

### Self-review of the fix round

- Re-derived `dpr` from the actual live field the widget set
  (`key.currentState!.vertices!.devicePixelRatio`) rather than hardcoding
  `3.0`, so this survives a future change to the test binding's default
  ratio or a `MediaQuery` override without silently going stale.
- Kept `stroke_width_golden_test.dart`'s `1.0` — the review's own
  corrected-claims list treats it as a given — but named it and ran it
  through the identical resolution/scaling shape the other two files use,
  so a future edit to that constant can't reintroduce a logical-resolution
  gap by omission.
- Did not touch `TriangleRasterizer` itself (Task 9's owned, tested class);
  the scaling lives at each call site as a small wrapping observer, matching
  the review's own phrasing and keeping the change inside this task's
  assigned files.
- Did not touch either sink or any fixture, per the review's explicit
  instruction — confirmed by `diff` against backups at every mutation
  checkpoint and `git status --porcelain` on `lib/` being empty at commit
  time.
