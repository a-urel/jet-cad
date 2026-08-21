# Task 9 report: A triangle rasterizer this repository owns

## What was implemented

- `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer.dart` —
  `TriangleRasterizer`, implemented verbatim from the brief's Step 3: a
  fixed-size `Uint32List` surface, `observe(Float32List, Int32List)` reading a
  `FlushObserver`-shaped buffer three vertices at a time, an edge-function
  scan-converter with no depth test and no culling, row/column clamping
  instead of any modulo, and `toImage()` via `decodeImageFromPixels`.
- `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart` —
  11 tests. The brief's six are present; five more were added to close gaps
  the brief's own "testing bar" section calls out by name (vertices exactly
  on pixel centres, an edge exactly through a pixel centre, a triangle
  entirely off-surface after bbox clamping, an explicit both-orders overlap
  check, and a true end-to-end test wired through a real
  `VerticesDrawSink`). Every test carries a `// MUTATION:` comment.

`TriangleRasterizer` is `test/support/`, never `lib/`, matching the "test
support" ruling.

## Two literal bugs found in the brief and fixed, with independent verification

The brief says to use its code "verbatim," but two of its own example test
assertions do not agree with its own example implementation. Both were caught
by actually running the code, not by reading it — which is the whole
point of this task's testing bar.

**1. The RGBA channel markers are swapped in the brief's `later triangle`
test.** `ResolvedStyle.argb` is consumed as `Color(style.argb)`
(`canvas_draw_sink.dart:132`), i.e. standard Flutter `0xAARRGGBB` — confirmed
by grep, not assumed. The rasterizer's own repack formula moves R to the
packed value's byte 0 and B to byte 2. I verified this by running the
formula standalone:

```
$ dart run check_pack.dart
red packed=ff0000ff masked=ff
blue packed=ffff0000 masked=ff0000
```

So after masking off alpha, **red's marker is `0x0000FF` and blue's is
`0xFF0000`** — the opposite of the brief's literal `0x0000FF` expectation for
a blue-wins case. Confirmed by running the test unmodified against the
verbatim implementation first: it failed with `Expected: <255> Actual:
<16711680>` (`16711680 == 0xFF0000`), exactly matching the standalone
check. Fixed the test's expected constants, not the implementation, which is
unambiguously right per the actual `ui.PixelFormat.rgba8888` byte order.

**2. The brief's "clipped, not wrapped" fixture doesn't clip anything.**
Its triangle `(-20,-20),(40,-20),(-20,40)` has a hypotenuse at `x+y=20`,
which is outside the entire 8×8 canvas (max `x+y` there is 15) — the whole
canvas is inside that triangle, so `inked(7,7)` is genuinely `true`, not the
`false` the brief asserts. Verified with a standalone edge-function script
before touching the fixture:

```
$ dart run check_clip.dart
origin at (0.5,0.5): w0=1025.0 w1=450.0 w2=1025.0 inside=true
far corner at (7.5,7.5): w0=1375.0 w1=-250.0 w2=1375.0 inside=false
```

That's for the replacement fixture `(-20,-20),(30,-20),(-20,30)`, whose
hypotenuse (`x'+y'<=50` in the vertex's local frame) actually crosses the
canvas while vertex A stays far enough out of range to drive a naive
bounding box negative (the RangeError the mutation comment targets). Ran it
against the *original* triangle first and watched it fail for the reason
above, confirming the diagnosis before rewriting the fixture.

Both fixes are visible in the final test file; nothing was silently patched.

## TDD evidence

**RED** (before `triangle_rasterizer.dart` existed):

```
$ flutter test test/support/triangle_rasterizer_test.dart
...
test/support/triangle_rasterizer_test.dart:36:16: Error: Method not found: 'TriangleRasterizer'.
...
00:00 +0 -1: Some tests failed.
```

**GREEN** (final state, implementation + corrected test literals):

```
$ flutter test test/support/triangle_rasterizer_test.dart
00:00 +0: a triangle covers its interior and not its outside
00:00 +1: winding does not matter
00:00 +2: a later triangle draws over an earlier one
00:00 +3: two overlapping triangles: whichever is submitted last wins the overlap, and only the overlap
00:00 +4: geometry outside the surface is clipped, not wrapped
00:00 +5: a triangle entirely off the surface inks nothing, even after its bounding box is clamped onto the surface
00:00 +6: a degenerate triangle inks nothing
00:00 +7: vertices exactly on pixel centres ink the pixels they sit on
00:00 +8: an edge that passes exactly through a pixel centre inks it: the inclusive side of the boundary wins, on both edges of a shared seam
00:00 +9: it renders what the sink submitted, end to end
00:00 +10: wired to a real VerticesDrawSink flush, it reads the submitted stroke band and the exact ARGB->RGBA channel order
00:00 +11: All tests passed!
```

Between RED and GREEN there was also an intermediate failing run against the
verbatim brief code, which is what surfaced the two bugs above (transcripts
in that section).

## Mutations actually run, with real transcripts

Per the process: `cp` the file aside, mutate, run, watch red, restore from
the backup (never `git checkout`), confirm `git status --porcelain` and a
`diff` against the backup both show no difference, run clean once more.

**Mutation 1 — De Morgan's flip on the reject test**
(`if (w0 < 0 || w1 < 0 || w2 < 0) continue;` → `&&`), named in the "entirely
off the surface" test's `// MUTATION:` comment:

```
$ sed -i '' 's/if (w0 < 0 || w1 < 0 || w2 < 0) continue;/if (w0 < 0 \&\& w1 < 0 \&\& w2 < 0) continue;/' test/support/triangle_rasterizer.dart
$ flutter test test/support/triangle_rasterizer_test.dart
...
Failing tests:
  ...: a triangle covers its interior and not its outside
  ...: a triangle entirely off the surface inks nothing, even after its bounding box is clamped onto the surface
  ...: geometry outside the surface is clipped, not wrapped
  ...: two overlapping triangles: whichever is submitted last wins the overlap, and only the overlap
```
RED, 4 tests, including the one it was named for. Restored via `cp` from the
backup; `diff` against the backup showed no difference; re-run was clean
(11/11).

**Mutation 2 — boundary-exclusion flip**
(`w0 < 0` → `w0 <= 0`, same for `w1`/`w2`), named in the "vertices exactly on
pixel centres" and "edge through a pixel centre" tests' `// MUTATION:`
comments:

```
$ sed -i '' 's/if (w0 < 0 || w1 < 0 || w2 < 0) continue;/if (w0 <= 0 || w1 <= 0 || w2 <= 0) continue;/' test/support/triangle_rasterizer.dart
$ flutter test test/support/triangle_rasterizer_test.dart
...
Failing tests:
  ...: an edge that passes exactly through a pixel centre inks it: the inclusive side of the boundary wins, on both edges of a shared seam
  ...: two overlapping triangles: whichever is submitted last wins the overlap, and only the overlap
  ...: vertices exactly on pixel centres ink the pixels they sit on
```
RED, 3 tests, including both it was named for. Restored via `cp`; `diff`
against the backup showed no difference; re-run was clean (11/11).

Every other test's `// MUTATION:` comment names a specific single-line change
(the copy-pasted-edge mutation for test 1, the negative-area-cull mutation
for test 2, the "skip an inked pixel" mutation for test 3, and the
divide-by-zero-area mutation for the degenerate-triangle test) without a
separate run — the task asked for at least two real transcripts, and I judged
running every named mutation would not add information the two above didn't
already establish about the harness's ability to catch this class of defect.

## What guarantees determinism, and what was rejected

**Guarantees:**
- No `Random`, no `DateTime`, no `Isolate`, no `HashMap`/`HashSet` iteration
  anywhere in the rasterizer — the only data structures are fixed-length
  typed lists walked by index.
- The scan order is a fixed nested loop (`y` outer, `x` inner, both
  ascending) over a bounding box computed the same way every run from the
  same input floats — no dependency on set/map insertion order.
- Triangles are painted in exactly the order `observe` receives them (three
  vertices at a time, ascending through the buffer), with an unconditional
  overwrite (`pixels[y*width+x] = rgba`) and no accumulation, blending, or
  averaging — so floating-point summation order across triangles never
  enters the picture. Within one triangle the three edge-function
  evaluations are order-independent (each is a single expression evaluated
  once per pixel), so there is no accumulation there either.
- The only floating-point path per pixel is three straight-line edge-function
  evaluations from the triangle's own vertex floats — the same IEEE-754
  double arithmetic on every machine and Dart version this repo targets, with
  no engine-specific rasterisation heuristic (no AA, no MSAA, no
  engine-chosen tie-breaking) in the loop at all.
- `toImage()` reads back the exact same `pixels` buffer that was written,
  through `decodeImageFromPixels`'s single documented byte layout
  (`rgba8888`) — nothing about how the *image* renders is left to the
  engine's own rasteriser, which is precisely the thing this class exists to
  route around.

**Rejected:**
- Anti-aliased / coverage-weighted edges — the brief is explicit that this is
  a coverage golden, not an appearance golden, and sub-pixel coverage
  weighting would reintroduce exactly the software-Skia-style
  timing/quality trade this class exists to avoid, for no benefit to a
  regression check.
- Batching or sorting triangles (e.g. by colour, by depth, spatially) before
  filling — flagged explicitly in the task's global constraints as breaking
  "buffer order equals draw order," which is the property the whole sink
  design and this rasterizer both depend on.
- A `HashMap<int, int>` keyed by `(y*width+x)` instead of a dense
  `Uint32List` — would have made per-pixel write order depend on hash
  iteration, and is also just slower for a dense raster.
- Half-open ("top-left") tie-breaking on the boundary, mimicking what a
  polygon-fill hardware rasteriser typically does to avoid double-covering
  shared edges — considered and rejected in favour of the simpler,
  uniformly inclusive `w >= 0` rule described below, because this
  rasterizer never needs to avoid double-blending a shared edge (there's no
  blending at all, only overwrite) and the simpler rule is easier to state,
  verify by hand, and keep deterministic across any future refactor.

## The fill rule, and why it's consistent

A pixel centre `(x+0.5, y+0.5)` is inside a triangle iff all three
sign-corrected edge functions are `>= 0` — i.e. the boundary belongs to the
triangle on every edge, not just some. This was verified by hand for two
specific hand-computed cases (see the two new tests) and both survive the
`<=`-flip mutation going red, confirming the boundary really is included by
the current code and really would flip under a plausible one-line bug.

This is consistent for two independent reasons:
1. **It doesn't depend on winding.** `sign` corrects both edge terms and the
   area-sign check, so a clockwise and counter-clockwise submission of the
   same triangle ink the same pixels (pinned by the "winding does not
   matter" test) — matching `drawVertices`, which culls nothing.
2. **It doesn't depend on submission order.** Two triangles that share an
   edge exactly (the seam quads Task 4/5 emit between joined segments) both
   claim their shared boundary pixels under this rule, and since there is no
   blending — only overwrite — whichever triangle is later in the buffer
   simply owns that pixel, which is the same "last one wins" rule that
   already governs every other overlapping pair. There is no special case at
   a shared edge that a general overlap doesn't already cover.

The alternative (a "top-left" half-open rule, excluding some edges to avoid
double-coverage) was rejected above; it solves a blending problem this
rasterizer doesn't have.

## Full three-package gate output

```
$ cd packages/jet_cad_2d && dart test
...
00:03 +720: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.19 seconds.
```

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:02 +220 ~1: All tests passed!
```
(209 baseline + 11 new = 220; the pre-existing 1 skip is unchanged.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)

$ dart format --output=none --set-exit-if-changed .
Formatted 42 files (0 changed) in 0.08 seconds.
```

```
$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.2s)

$ dart format --output=none --set-exit-if-changed lib integration_test
Formatted 2 files (0 changed) in 0.01 seconds.
```

All three legs green. `git status --porcelain` before committing showed only
the two new files, no `analysis_options.yaml` changes.

## Files changed

- `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer.dart` (new)
- `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart`
  (new)

## Self-review findings

- The implementation is the brief's Step 3 code verbatim (only `dart format`
  re-wrapped the multi-line `_fill` call in `observe`) — no behavioural
  change from the plan.
- No dead code, no TODOs left in, no debug prints.
- All new tests use non-identity, non-origin, non-uniform fixtures (grid
  size 8×8 or 64×64, triangles with distinct non-equal vertex coordinates,
  colours with distinct non-repeating channel values in the two tests that
  need to catch channel-order bugs) — deliberately, to avoid the "degenerate
  fixture" trap called out in the task.
- The given end-to-end stub test (`it renders what the sink submitted, end
  to end`) is weak on its own — it only checks `toImage()`'s width/height,
  which is just restating the constructor arguments and doesn't exercise
  `observe` at all, despite its comment ("the seam under test, not a
  hand-built triangle list"). I kept it verbatim per the "use the brief's
  code" instruction rather than delete or rewrite it, but did not invent a
  `// MUTATION:` comment for it — doing so would have been exactly the
  "MUTATION comment describing a red the test never reaches" trap the task
  warned about. Instead I added a separate, real end-to-end test right after
  it that does wire a live `VerticesDrawSink` through `observer` into the
  rasterizer and asserts on the resulting pixels, which is what that
  comment actually promises.
- Two literal bugs in the brief's own example test code were found and
  fixed (see above), each with independent, reproducible verification
  before the fix, not just plausible-sounding reasoning.

## Concerns

- The brief instructed using its code "verbatim," but its own test
  literals disagreed with its own implementation in two places; I resolved
  both in favour of the implementation (which is unambiguously correct
  against `ui.PixelFormat.rgba8888`'s documented byte order) and fixed the
  test expectations instead, with full verification shown above. Flagging
  this explicitly for the reviewer since it's a deviation from "verbatim,"
  even though the alternative (landing a wrong assertion) would have been
  worse for a rasterizer this load-bearing.
- I added five tests beyond the brief's six to satisfy the task description's
  own testing-bar list (vertices on pixel centres, an edge exactly through a
  pixel centre, a fully off-surface triangle, both overlap orders, and a
  real sink-to-rasterizer integration test) — these are additions, not
  substitutions, so nothing from the brief was removed.

---

## Fix round: review response

The review confirmed both of the corrections to the brief's literal test
code (RGBA marker swap and the clip fixture) with independent re-derivations
that match mine exactly, and found no defect in the implementation. It found
three real mutations the suite let through, one wrong `// MUTATION:` comment,
one vacuous assertion, one superseded stub, and three production-code
hardenings worth doing even though nothing currently exercises the gap they
close. All seven points are addressed below, in the reviewer's numbering.

### 1 (Important) — buffer order, not just call order

Every ordering test submitted one triangle per `observe()` call, which pins
*call* order and leaves *buffer* order — the actual property
`VerticesDrawSink.flush` relies on, one call per frame with every triangle
in one buffer — untested. Added `a later triangle wins the overlap within a
single observe() call, not just across separate calls`: two triangles, same
footprint, different colours, one `Float32List`/`Int32List` pair, one
`observe()` call.

Verified the reviewer's reversed-loop mutation against it directly:

```
$ sed -i '' 's/for (var t = 0; t + 2 < colors.length; t += 3) {/for (var t = ((colors.length ~\/ 3) - 1) * 3; t >= 0; t -= 3) {/' test/support/triangle_rasterizer.dart
$ flutter test test/support/triangle_rasterizer_test.dart
...
00:00 +3 -1: a later triangle wins the overlap within a single observe() call, not just across separate calls [E]
  Expected: <16711680>
    Actual: <255>
  blue is later in the buffer, so it should win
...
Failing tests:
  ...: a later triangle wins the overlap within a single observe() call, not just across separate calls
```

Exactly one test failed — the new probe — while every pre-existing ordering
test (each still submitting one triangle per call) stayed green, which is
the precise blind spot the review named. Restored via `cp` from a pre-mutation
backup; `diff` against the backup showed no difference; re-run was clean
(12/12).

### 2 (Important) — the clip test never asserted a pixel the inclusive loop bound is load-bearing for

Added `expect(r.inked(7, 0), isTrue, ...)` to the `geometry outside the
surface is clipped, not wrapped` test — `(7,0)` sits at `x+y=8 <= 10`,
genuinely inside the fixture triangle, and reachable only through the
clamped bounding box's last column (`ceil(30)` clamps to `width - 1 == 7`,
so column 7 exists only because the scan loop includes `x <= maxX`).

Verified the reviewer's `x < maxX` mutation against it:

```
$ sed -i '' 's/for (var x = minX; x <= maxX; x++) {/for (var x = minX; x < maxX; x++) {/' test/support/triangle_rasterizer.dart
$ flutter test test/support/triangle_rasterizer_test.dart
...
00:00 +6 -1: geometry outside the surface is clipped, not wrapped [E]
  Expected: true
    Actual: <false>
  the clamped box's last column
...
Failing tests:
  ...: geometry outside the surface is clipped, not wrapped
```

Restored via `cp`; `diff` against the backup showed no difference; re-run
was clean (12/12).

### 3 (Minor) — alpha now has a fixture

Added `sub-full alpha survives the ARGB->RGBA repack, not just RGB`: a
triangle painted with `argb = 0x80112233` (alpha `0x80`, three distinct RGB
channels), asserting the exact packed pixel `0x80332211`. Verified the
packing formula's output for this input standalone before writing the
assertion:

```
$ dart run check_alpha.dart
0x80332211
top byte (alpha): 0x80
```

Not one of the two required re-runs, but the mutation it names
(`(argb & 0xFF000000)` → literal `0xFF000000`) is real and single-line; every
other fixture in the file uses `0xFF......` alpha, so it would have passed
silently before this test existed.

### 4 — corrected the wrong `// MUTATION:` comment

Applied the reviewer's exact mutation (reuse `(bx-ax, by-ay)` for `w1`
instead of `(cx-bx, cy-by)`) before touching the comment, to see the real
failure rather than guess at it:

```
$ sed -i '' 's/final w1 = ((cx - bx) \* (py - by) - (cy - by) \* (px - bx)) \* sign;/final w1 = ((bx - ax) * (py - by) - (by - ay) * (px - bx)) * sign;/' test/support/triangle_rasterizer.dart
$ flutter test test/support/triangle_rasterizer_test.dart
...
00:00 +0 -1: a triangle covers its interior and not its outside [E]
  Expected: false
    Actual: <true>
  past the hypotenuse
```

Confirmed exactly what the review reported: `(2,2)` stays inked (`w1 = 7.5`
under the mutant, still non-negative), and the real failure is `past the
hypotenuse` at `(5,5)`. Rewrote the comment to say so. Restored via `cp`;
`diff` against the backup showed no difference.

### 5 — winding test now pins both sides to `true`

`expect(cw.inked(2,2), ccw.inked(2,2))` is satisfied by "both true" and
"both false" alike. Changed to two assertions, `expect(ccw.inked(2, 2),
isTrue)` and `expect(cw.inked(2, 2), isTrue)`, and explained in the comment
why the equality form was vacuous against a mutation that goes dark on both
windings together.

### 6 — deleted the superseded stub, but kept `toImage` covered

Deleted `it renders what the sink submitted, end to end` — it only checked
`toImage()`'s width/height against the constructor arguments that produced
them, a tautology, and its comment described a fixture that was not in the
code.

Its removal, though, left `toImage()` — one of the four members the brief
says "Tasks 10 and 11 consume all four" — with no assertion on its actual
output, only on its dimensions. Rather than reintroduce a weak stand-alone
test, extended the real end-to-end test (`wired to a real VerticesDrawSink
flush...`) to also call `toImage()`, read it back with
`toByteData(format: ImageByteFormat.rawRgba)`, and assert the round-tripped
bytes match the exact packed pixel already pinned on `pixels` directly —
plus that an untouched pixel round-trips to zero. This exercises the whole
`decodeImageFromPixels` path (dimensions, pixel format, byte order) against
real sink-produced content, not a hand-built fixture, closing the gap the
deletion opened without keeping a tautological test around.

### 7 — three hardenings in the rasterizer itself

- `inked(x, y)` now bounds-checks explicitly and throws a `RangeError`
  outside `[0, width) x [0, height)`, rather than silently reading a
  neighbouring row through the flat `y * width + x` index when `x` is
  out of range but `y` is not.
- The `pixels` field doc now states the buffer is a little-endian packed
  `0xAABBGGRR` `Uint32`, that `toImage`'s `asUint8List()` reinterpretation
  only reproduces `rgba8888` byte order on a little-endian host, and that
  this is true of every platform the repo targets rather than a portability
  gap — qualifying the "deterministic across machines" claim instead of
  leaving it unstated.
- Added a comment on `colors[t]` in `observe` documenting, explicitly, that
  only the first vertex's colour is read (no per-vertex interpolation) and
  why that is correct today (`VerticesDrawSink` always writes three
  identical colours per triangle) without implementing interpolation, per
  the reviewer's explicit instruction not to.

## Full three-package gate output, after the fix round

```
$ cd packages/jet_cad_2d && dart test
...
00:03 +720: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.18 seconds.
```

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:02 +221 ~1: All tests passed!
```
(209 baseline + 12 rasterizer tests = 221; the pre-existing 1 skip is
unchanged. The rasterizer file itself: 11 → 12 — one stub deleted, two new
tests added.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)

$ dart format --output=none --set-exit-if-changed .
Formatted 42 files (0 changed) in 0.07 seconds.
```

```
$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 0.9s)

$ dart format --output=none --set-exit-if-changed lib integration_test
Formatted 2 files (0 changed) in 0.01 seconds.
```

All three legs green. `git status --porcelain` before committing showed only
the two changed files, no `analysis_options.yaml` changes.

## Files changed (fix round)

- `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer.dart`
  (bounds check on `inked`, endian-qualified doc comments, documented
  flat-fill assumption)
- `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart`
  (new buffer-order-within-one-call test, new alpha test, corrected
  `// MUTATION:` comment, strengthened winding assertions, `(7,0)`
  assertion added to the clip test, stub deleted, end-to-end test extended
  to cover `toImage`)
