# Task 6 report: The point shape, reconciled

## What I implemented

`CanvasDrawSink.point` no longer pushes the residual onto the `Canvas` and
calls `drawRawPoints` (which draws its square cap in local space, so a
rotated/sheared residual turned the marker with it). It now applies the
residual to the point's coordinates directly and draws an axis-aligned
`Rect` via `canvas.drawRect`, matching what `VerticesDrawSink.point` already
does in screen space. The `1.0` passed to `_widthFor` is deliberate: the
half-width is a device-pixel quantity for this call, and the residual is
never on the canvas, so there is nothing to pre-divide by.

The now-dead `Float32List _point` scratch field (only ever fed to
`drawRawPoints`) was removed, along with its mention in the class-doc
sentence about "the two typed lists below" (now one).

Three pre-existing cases in `draw_sink_test.dart` encoded the old behaviour
directly and had to change (see "Deviation from the brief" below).

## Deviation from the brief, and why

The brief's `point_shape_test.dart` as given does **not** fail against the
unmodified code. Its only assertion on `CanvasDrawSink` was
`expect(sink.canvasCallCount, 1)` — true under both the old and new
implementations, since both make exactly one `Canvas` call per point. The
prose around it claims the test also pins "no save outstanding," but no line
of code checks that. I ran it against the unmodified sink first and confirmed
it passed outright — this is exactly the "count assertion that fires before
the geometric one" trap the task instructions warned about, and by the
brief's own account this plan has shipped comments like this before.

I rewrote the first test to actually measure geometry: it rasterises the
sink's `Picture` to a 16x16 buffer (the same budget
`vertices_draw_sink_test.dart` already uses for pixel-level assertions) and
computes the alpha-nonzero bounding box. Before touching `canvas_draw_sink.dart`,
I empirically probed both shapes with throwaway scratch code (not committed)
to get real numbers rather than guessing:

- A `drawRect`-style axis-aligned square (half=2, centered at a lattice
  point) rasterises to a 4x4-pixel bounding box, at 0° or 30°.
- The old `drawRawPoints` path (default `Paint`, `style=stroke`,
  `strokeWidth=4`, pushed transform, `PointMode.points` at local origin)
  rasterises to 4x4 at 0° and 6x6 at 30° — the shape does grow under rotation,
  confirming the brief's premise, and giving me an exact number to assert
  against instead of a vague "the two backends should differ."

The second test ("the two sinks agree on where the marker goes") is kept
verbatim from the brief — it only exercises `VerticesDrawSink`, which this
task doesn't change, so it was never going to be RED; it documents the
position invariant Task 10 will lean on.

I also updated three tests in `draw_sink_test.dart` that the brief's file
list didn't mention, because they broke as a direct, in-scope consequence of
this change and leaving them broken would have been the regression the
ruling calls out:
- `'beginResidual pushes the affine as a column-major 4x4'` and
  `'endResidual restores the canvas'` both used `point(0, 0, _anyStyle)`
  only as a way to force the deferred `save`/`transform` push. Since `point`
  no longer pushes anything, I swapped in `circle(0, 0, 1, _anyStyle)`,
  updating the surrounding comment to say why.
- `'point reaches the canvas as a point, not a zero-length path'` asserted
  `drawRawPoints` directly with two hardcoded coordinates; the whole
  assertion is obsolete. I rewrote it to assert the new call: it drives a
  point through a real (non-identity, non-trivial) residual — `Transform2(2,
  0, 0, 2, 10, 20)` — and checks that no `save` happened, that `drawRect` was
  called with the exact `Rect` the residual math predicts (`(15.5,
  27.5)-(16.5, 28.5)` for point `(3,4)`, lineweight 25/100mm at 4px/mm), and
  that the paint was filled black. This is a non-degenerate fixture: identity
  or origin-only inputs would not have exposed a swapped `a`/`c` or `b`/`d`
  term in the coordinate math.

## TDD evidence

### RED (real `point_shape_test.dart`, before implementing)

```
00:00 +0: the marker is axis-aligned on screen under a rotated residual
00:00 +0 -1: the marker is axis-aligned on screen under a rotated residual [E]
  Expected: <4>
    Actual: <6>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/point_shape_test.dart 95:5                     main.<fn>

00:00 +0 -1: the two sinks agree on where the marker goes
00:00 +1 -1: Some tests failed.
```

This is the real failure from running against the unmodified
`canvas_draw_sink.dart` — `Expected: <4> Actual: <6>`, matching the
empirically probed old-code bounding box exactly.

### GREEN (after implementing)

```
00:00 +0: the marker is axis-aligned on screen under a rotated residual
00:00 +1: the two sinks agree on where the marker goes
00:00 +2: All tests passed!
```

`flutter analyze lib/src/canvas_draw_sink.dart` initially flagged
`unused_field` on the now-dead `_point` field; removed it and the field-list
comment sentence, then re-ran clean.

`draw_sink_test.dart`, after updating the three affected cases:

```
00:00 +16: CanvasDrawSink circle and arc reach the canvas as circles and arcs
00:00 +17: CanvasDrawSink point reaches the canvas as an axis-aligned rect in screen space, not a rotated cap
00:00 +18: All tests passed!
```

(19 tests counting the `flatten`/`RecordingDrawSink`/`NullDrawSink` groups
above it in the same file — all pass.)

## Mutation run (real transcript)

I backed up `canvas_draw_sink.dart`, reverted `point` in place to the exact
old implementation (`_pushTransform(); drawRawPoints(...)`), ran the two
affected test files, confirmed RED, then restored from the backup under a
`trap` and confirmed `git status --porcelain` / `git diff --stat` matched my
real implementation (not the mutated one) before proceeding.

```
--- mutated point() back to old drawRawPoints behavior ---
119:  void point(double x, double y, ResolvedStyle style) {
120-    _pushTransform();
121-    final _point = Float32List(2);
122-    _point[0] = x;
123-    _point[1] = y;
124-    canvas.drawRawPoints(PointMode.points, _point, _paintFor(style));
125-    _canvasCalls++;
126-  }
127-
--- running point_shape_test.dart and draw_sink_test.dart against mutated code ---
00:00 +0: point_shape_test.dart: the marker is axis-aligned on screen under a rotated residual
00:00 +0 -1: the marker is axis-aligned on screen under a rotated residual [E]
  Expected: <4>
    Actual: <6>
...
00:00 +17: draw_sink_test.dart: CanvasDrawSink point reaches the canvas as an axis-aligned rect in screen space, not a rotated cap
00:00 +17 -2: CanvasDrawSink point reaches the canvas as an axis-aligned rect in screen space, not a rotated cap [E]
  Expected: empty
    Actual: WhereIterable<RecordedCall>:[Instance of 'RecordedCall']
  a point never pushes the residual onto the canvas

package:matcher                                     expect
package:flutter_test/src/widget_tester.dart 473:18  expect
test/draw_sink_test.dart 301:7                      main.<fn>.<fn>

00:00 +17 -2: Some tests failed.

Failing tests:
  .../test/draw_sink_test.dart: CanvasDrawSink point reaches the canvas as an axis-aligned rect in screen space, not a rotated cap
  .../test/point_shape_test.dart: the marker is axis-aligned on screen under a rotated residual
```

Both tests went red for the reason claimed in their own `// MUTATION:`
comments — one on the bounding-box size, one on the save call reappearing.
After restoring: `flutter test` → `+206 ~1: All tests passed!`, `flutter
analyze` → `No issues found!`, `dart format --set-exit-if-changed .` → no
diff.

## What happened to the golden suite

`flutter test --tags golden` (all 13 golden-tagged tests): **all pass, no
PNG regenerated or diffed.** I checked which goldens actually exercise
`DrawSink.point` before running — none do. `stroke_width_golden_test.dart`
and `text_ladder_golden_test.dart` are the only files under `test/golden/`
that mention the word "point" and both uses are prose comments, not
`PointEntity`/`EntityKind.point` fixtures. No ladder rung in this repo
currently draws a point entity, so this change has no observable effect on
any committed golden PNG. Nothing was regenerated.

## Full-gate output

`packages/jet_cad_2d` (untouched by this task, run for completeness):
```
dart test    -> 00:03 +720: All tests passed!
dart analyze -> No issues found!
dart format --output=none --set-exit-if-changed . -> Formatted 105 files (0 changed)
```

`packages/jet_cad_2d_flutter`:
```
flutter test  -> 00:02 +206 ~1: All tests passed!   (baseline was 204 passing, 1 skipped; +2 from point_shape_test.dart)
flutter analyze -> No issues found!
dart format --output=none --set-exit-if-changed . -> Formatted 40 files (0 changed)
flutter test --tags golden -> +13: All tests passed!, nothing regenerated
```

Ran once more after the final commit to confirm the committed tree is green:
`flutter test` → `00:02 +206 ~1: All tests passed!`.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart` — `point`
  rewritten to draw an axis-aligned device-space `Rect`; removed the now-dead
  `_point` `Float32List` field and updated the adjacent doc comment.
- `packages/jet_cad_2d_flutter/test/point_shape_test.dart` (new, revised
  after review) — two tests: a rasterised geometric check on
  `CanvasDrawSink` under a sheared, non-uniformly-scaled residual (`a != d`,
  nonzero shear, nonzero local point, exact position asserted), and the
  position-agreement check on `VerticesDrawSink`, also updated to a
  non-uniform sheared residual.
- `packages/jet_cad_2d_flutter/test/draw_sink_test.dart` — three cases
  updated to stop asserting the removed `drawRawPoints`/push-on-point
  behaviour (see "Deviation from the brief" above); the rect-position case
  further revised after review to a non-uniform sheared residual with an
  exact position assertion.

## Self-review findings

- Checked for other callers or assumptions about `CanvasDrawSink.point`
  pushing the residual or calling `drawRawPoints`: `reference_walk.dart`
  calls `sink.point(...)` generically through the `DrawSink` interface and
  has no sink-specific assumption. `differential_test.dart` doesn't touch
  `.point` by name. No other production or test file referenced
  `drawRawPoints` or the removed `_point` field.
- Verified `_paintFor` (used by `polyline`/`circle`/`arc`/text-adjacent
  paths) never sets `.style`, relying on the sink-lifetime invariant that
  `_paint.style` is `stroke` except transiently inside `point`, which sets it
  to `fill` and resets it to `stroke` before returning — confirmed this
  reset happens unconditionally at the end of the method, so no early return
  path could leave it stuck on `fill`.
- Confirmed `sink.canvasCallCount` stays at exactly 1 per `point` call (no
  accidental double-count from the `save`/`restore` no longer happening).
- **Correction (post-review):** my original self-review said "no allocation
  introduced." That overstates it. `point` mutates the shared `_paint` in
  place (no new `Paint`), but `Rect.fromLTRB(...)` allocates a `Rect`, and
  the old `point` never allocated one — it only allocated the `Color`
  (`_paintFor` did `..color = Color(style.argb)`) and reused the field-level
  `Float32List _point` for the raw point coordinates. So the new `point` does
  allocate one more object per call than the old one: a `Rect`. This is the
  same class of per-call allocation `circle` (`Offset`, `Rect.fromCircle`)
  and `arc` (`Rect.fromCircle`) already incur, so it's consistent with the
  sink's existing pattern rather than a new kind of cost, and
  `paint_allocation_test.dart` — which gates `VerticesDrawSink`, not
  `CanvasDrawSink` — is unaffected either way. But "no allocation introduced"
  was not the true claim; "no new *invariant-gated* allocation" is.
- Confirmed via `git diff --stat` and `git status --porcelain` after the
  mutation-and-restore that the restored file matched my actual
  implementation, not the reverted-to-old version, before committing.

## Fix round (reviewer feedback on the first submission)

The reviewer approved the task but flagged two things.

**1. Every residual in the new/changed tests had `a == d`.** True of all
three: `point_shape_test.dart`'s two tests used a pure rotation
(`a = d = cosθ`), and `draw_sink_test.dart`'s rewritten point test used a
pure uniform scale (`Transform2(2, 0, 0, 2, 10, 20)`, `a = d = 2`). The
reviewer proved this hides a real bug class: cross-swapping `a` and `d` in
`CanvasDrawSink.point`'s coordinate math (`sx = a*x + c*y + e; sy = b*x + d*y
+ f` → `sx = d*x + c*y + e; sy = b*x + a*y + f`) left every test green,
because when `a == d` the swap is a no-op, and `point_shape_test.dart`'s
shape test additionally draws at the local origin, where `x = y = 0` makes
the swap a no-op regardless of `a` vs `d`.

Fix: all three residuals now have `a != d` plus a genuine shear (`b != -c`,
so the matrix isn't a rotation), and the two tests that touch
`CanvasDrawSink` (`point_shape_test.dart`'s shape test, and
`draw_sink_test.dart`'s rect test) now draw at a nonzero local point `(3, 4)`
and assert the exact device-space position, not just the marker's size — so
a swap of `a` and `d` moves the marker to the wrong place and the assertion
catches it. `point_shape_test.dart`'s "the two sinks agree" test also got a
non-uniform sheared residual for consistency, though it only exercises
`VerticesDrawSink`, which this task doesn't touch, so it isn't the vehicle
for catching this particular mutation.

New residual used in `point_shape_test.dart`'s shape test:
`Transform2(1.5, 0.3, 0.4, 0.8, 1.9, 3.9)`, point `(3, 4)` — chosen so the
correct device center lands exactly on `(8.0, 8.0)`, keeping the rasterised
bbox `(minX: 6, maxX: 9, minY: 6, maxY: 9)` free of ambiguous anti-aliasing
at the raster edge.

New residual used in `draw_sink_test.dart`'s rect test:
`Transform2(2, 0.5, -0.25, 1, 10, 20)`, point `(3, 4)` — correct center
`(15.0, 25.5)`, asserted `Rect.fromLTRB(14.5, 25.0, 15.5, 26.0)` exactly
(this test reads `SpyCanvas`'s captured float args directly, no
rasterisation, so no pixel rounding to account for).

### Mutation run (real transcript) — the `a`/`d` cross-swap

Backed up `canvas_draw_sink.dart`, applied the reviewer's exact mutation to
the coordinate math, ran the two affected test files, confirmed RED, restored
under a `trap`, confirmed `git status --porcelain` / `git diff --stat` showed
the file back to my real implementation.

Mutated code (confirmed present before running):
```
128:    final sx = _residual.d * x + _residual.c * y + _residual.e;
129:    final sy = _residual.b * x + _residual.a * y + _residual.f;
```

Test run against the mutated code:
```
00:00 +0: point_shape_test.dart: the marker is axis-aligned on screen under a sheared, non-uniformly-scaled residual
00:00 +0 -1: the marker is axis-aligned on screen under a sheared, non-uniformly-scaled residual [E]
  Expected: ({int maxX, int maxY, int minX, int minY}):<(maxX: 9, maxY: 9, minX: 6, minY: 6)>
    Actual: ({int maxX, int maxY, int minX, int minY}):<(maxX: 7, maxY: 12, minX: 3, minY: 8)>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/point_shape_test.dart 108:5                     main.<fn>

00:00 +0 -1: point_shape_test.dart: the two sinks agree on where the marker goes
...
00:00 +17: draw_sink_test.dart: CanvasDrawSink point reaches the canvas as an axis-aligned rect in screen space, not a rotated cap
00:00 +17 -1: CanvasDrawSink point reaches the canvas as an axis-aligned rect in screen space, not a rotated cap [E]
  Expected: Rect:<Rect.fromLTRB(14.5, 25.0, 15.5, 26.0)>
    Actual: Rect:<Rect.fromLTRB(11.5, 29.0, 12.5, 30.0)>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/draw_sink_test.dart 317:7                       main.<fn>.<fn>

00:00 +17 -2: Some tests failed.

Failing tests:
  .../test/draw_sink_test.dart: CanvasDrawSink point reaches the canvas as an axis-aligned rect in screen space, not a rotated cap
  .../test/point_shape_test.dart: the marker is axis-aligned on screen under a sheared, non-uniformly-scaled residual
```

Both fixtures went red for exactly the predicted reason: the marker's
*position* under the mutation, not its size (the shape test's bbox is still
a 4x4 square, `7-3=4` and `12-8=4` — it's just recentred on the wrong point).
The `Rect` actual value `(11.5, 29.0)-(12.5, 30.0)` matches hand computation
of the mutated formula (`sx = d*3 + c*4 + e = 1*3 + -0.25*4 + 10 = 12.0`,
`sy = b*3 + a*4 + f = 0.5*3 + 2*4 + 20 = 29.5`) exactly.

Restored, then reran the full flutter suite: `flutter test` →
`+206 ~1: All tests passed!`; `flutter analyze` → `No issues found!`;
`dart format --output=none --set-exit-if-changed .` → no diff; `flutter test
--tags golden` → `+13: All tests passed!`, nothing regenerated. Also reran
`packages/jet_cad_2d`'s gate for completeness: `dart test` →
`+720: All tests passed!`; `dart analyze` → `No issues found!`; `dart format`
→ no diff.

**2. The allocation claim in the self-review overstated what's true.** See
the corrected bullet under "Self-review findings" above — `point` does
allocate one more object per call than the old implementation (a `Rect`),
which is not a regression against any tested invariant but was not the
"no allocation introduced" I originally wrote.

## Concerns

None outstanding. One thing worth flagging for whoever reviews Task 10 (the
sink-against-sink comparison): `CanvasDrawSink._widthFor` has no floor
analogous to `VerticesDrawSink._halfWidthFor`'s
`kMinStrokeDevicePixels`/`devicePixelRatio` floor — an extremely thin
lineweight's point marker could size differently between the two backends at
the low end. That floor divergence already existed for every other primitive
before this task and is out of this task's scope; I did not touch it.
