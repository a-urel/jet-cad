# Task 8 report: the shaders, and the Dart that has to say the same thing

Branch: `plan-c/shaded-dashes`. Commit: `a6cd72c` — "feat(shaders): the dash
test, in GLSL and in the Dart that stands in for it".

## Shader diffs and why each line is where it is

### `cad_stroke.vert`

- `frame_info.dash_scale` added as the uniform block's third member (float
  index 18, byte 72 — the slot Task 7 already reserved). Needed at vertex
  time only for the collapse test.
- `in float kind` / `in float half_width` (two separate attributes)
  collapsed into one `in vec2 kind_half`, and `in vec4 dash` added. Without
  the merge the shader would need nine attributes (`corner`, `join_weight`,
  `kind`, `p0`, `p1`, `p2`, `half_width`, `color`, `dash`) — one past the
  GLSL ES 100 floor of eight `gl_MaxVertexAttribs`. `main()` unpacks
  `kind_half.x`/`.y` back into locals named `kind`/`half_width` immediately,
  so every downstream line is unchanged text.
- `out vec3 v_dash` added beside `v_color`. `(t, fracStart, fracEnd)`, one
  varying rather than two, using a negative `fracStart` as the solid
  sentinel — the brief's own reasoning for not adding a fourth varying.
- `const float kDashCollapsePx = 3.0` restated beside `kMinMiterCosine`,
  for the same reason that constant is restated: GLSL cannot read
  `packages/jet_cad_2d`'s Dart constant.
- `float along = 0.0` declared before the kind dispatch, at the top of
  `main()`, alongside `vec2 px` — the vertex-local scratch value the dash
  decision reads once dispatch is done.
- Inside the stroke branch (`kind < 0.5`), one line added after `px` is
  computed: `along = corner.x * length(p1 - p0)`. **`p1 - p0`, not
  `b - a`.** `a`/`b` are `to_pixels(p0)`/`to_pixels(p1)` — already run
  through the live camera's `mvp` — so using them here would put the
  camera back into `t` and reintroduce the defect this plan exists to
  remove (confirmed by mutation M-C12 below). The join branch gets a
  comment, no code: every vertex of a wedge sits at the corner, so `along`
  stays its default `0.0` and the whole wedge tests at the phase stored
  for that corner. The point branch is untouched code plus a one-line note
  that a point is never dashed (`writePoint` never writes a nonzero
  period).
- After `gl_Position`/`v_color` are set (unchanged), the dash block: set
  the solid sentinel, compute `period = abs(dash.x)`, and if `period > 0`
  either collapse (`period * dash_scale < kDashCollapsePx`) or compute the
  real varying. In the collapse branch, `dash.x > 0.0` (an ordinary
  sibling) gets `gl_Position = vec4(0.0, 0.0, 0.0, 1.0)` — the brief's
  literal, not `vec4(0.0)`, since `w = 0` is not a degenerate point, it's
  undefined. `dash.x < 0.0` (the representative) falls through with the
  sentinel already set from three lines above, so it keeps drawing solid
  at its real position.

### `cad_stroke.frag`

- `in vec3 v_dash` added. `if (v_dash.y >= 0.0)` gates the whole test —
  solid instances and collapsed representatives both carry `v_dash.y < 0`
  and skip it outright, taking the vertex shader's default color path.
- The extent test is `f < v_dash.y || f >= v_dash.z` — half-open
  `[fracStart, fracEnd)`, matching `dasher.dart`'s own `b > a` emission
  test (`b`, the frac end, is excluded from the drawn span). A closed
  `f > v_dash.z` would draw a one-fragment-wide sliver at a zero-width
  element where the reference draws nothing.

## Bundle regeneration

```
$ sh tool/build_shaders.sh
wrote assets/shaders/cad.shaderbundle
```

No "Could not complete reflection" failure — every one of the eight
attributes (`corner`, `join_weight`, `kind_half`, `p0`, `p1`, `p2`, `color`,
`dash`) is read on a path the optimizer cannot fold away.

```
$ shasum -a 256 assets/shaders/cad.shaderbundle
a2cd5552de49b79cb3a7edb06375c4fcf0caf0c9889a4362c13d2aa3cd9ba419  assets/shaders/cad.shaderbundle

$ strings -a assets/shaders/cad.shaderbundle | grep -c "attribute "
16
```

16, not 8: `impellerc` emits the ES 100 vertex stage twice under this
runtime-stage set (the GLES stage is compiled once for the reflection pass
and once as the bundled runtime stage), so each of the eight attribute
names appears twice in the binary's strings. Confirmed by listing the
matches — exactly the eight names, each exactly twice, no ninth:

```
$ strings -a assets/shaders/cad.shaderbundle | grep "attribute "
attribute vec2 kind_half;
attribute vec2 p0;
attribute vec2 p1;
attribute vec2 corner;
attribute vec2 p2;
attribute vec4 join_weight;
attribute vec4 color;
attribute vec4 dash;
attribute vec2 kind_half;
attribute vec2 p0;
attribute vec2 p1;
attribute vec2 corner;
attribute vec2 p2;
attribute vec4 join_weight;
attribute vec4 color;
attribute vec4 dash;
```

## `instance_expander.dart`

`expandInstances` gains `{required double dashScale}`; `ExpandedTriangles`
gains `Float32List dashVaryings` (three floats per vertex). The dash block
was inserted at the end of the per-vertex loop, after `positions`/`colors`
are written, in the shader's own statement order: default the varying to
the solid sentinel, test `period`, collapse-or-compute. `along` is computed
inside the `kind < 0.5` branch from the raw `x0,y0,x1,y1` attributes — never
from the already-projected `ax,ay,bx,by` — mirroring the vert file's `p1 -
p0` line for line. `kExpanderDashCollapsePx = 3.0` mirrors `kDashCollapsePx`
the same way `kExpanderMinMiterCosine` already mirrors the miter literal,
and a test asserts the two agree with `jet_cad_2d`'s own `kDashCollapsePx`.

`gpu_comparison.dart`'s `measureResidentAgreement` gained the same
`{required double dashScale}` (Ruling P3 — its signature change was the
plan's, not this task's, but leaving it broken would leave the suite not
compiling). Its doc explains why every caller today passes `1.0`: both arms
are driven at the same camera the buffer is collected at, so the
live-to-collection ratio is exactly 1. The three call sites in
`resident_pixel_differential_test.dart` were updated to pass it.

Seven pre-existing `expandInstances` calls in `instance_expander_test.dart`
(none dash-related) also needed `dashScale: 1.0` added, since the new
parameter is `required`, not defaulted — not mentioned in the brief's step
list but necessary for the file to compile.

## Mutation kill 1 — `along` from device-space points (M-C12)

`cp test/support/instance_expander.dart test/support/instance_expander.dart.orig`,
then in the stroke branch changed:

```dart
final rawDx = x1 - x0, rawDy = y1 - y0;
along = c.x * math.sqrt(rawDx * rawDx + rawDy * rawDy);
```
to
```dart
// MUTATION M-C12: device-space along, not collection-space.
along = c.x * len;   // len == length(b - a), device space
```

```
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +2 -1: t is measured in COLLECTION units, so the camera cancels [E]
  Expected: a numeric value within <0.000001> of <1.8333333730697632>
    Actual: <6.833333492279053>
     Which:  differs by <5.0000001192092896>
...
00:00 +13 -1: Some tests failed.
```

Restored: `cp test/support/instance_expander.dart.orig test/support/instance_expander.dart`,
then re-ran:

```
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +15: All tests passed!
```

## Mutation kill 2 — collapse branch deleted

`cp test/support/instance_expander.dart test/support/instance_expander.dart.orig2`,
then replaced the collapse `if`/`else` with an unconditional periodic
varying:

```dart
var vDashT = 0.0, vDashFracStart = -1.0, vDashFracEnd = 0.0;
// MUTATION: collapse branch deleted.
if (period > 0.0) {
  vDashT = (dashPhase + along) / period;
  vDashFracStart = dashFracStart;
  vDashFracEnd = dashFracEnd;
}
```

```
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +3 -1: a collapsed non-representative instance produces a degenerate triangle [E]
  Expected: a value less than <0.0>
    Actual: <0.0>
     Which: is not a value less than <0.0>
...
00:00 +14 -1: Some tests failed.
```

Restored: `cp test/support/instance_expander.dart.orig2 test/support/instance_expander.dart`,
then re-ran:

```
$ flutter test test/gpu/instance_expander_test.dart
...
00:00 +15: All tests passed!
```

Both restores used the `cp` backup, never `git checkout --`. Both backup
files (`.orig`, `.orig2`) were deleted after use and do not appear in
`git status`.

## Commands, full gate

```
$ flutter test
...
00:06 +523: All tests passed!            (exit 0)

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)           (exit 0)

$ dart format --output=none --set-exit-if-changed .
Formatted 90 files (0 changed) in 0.17 seconds.   (exit 0)
```

`git status --short` before commit carried no `analysis_options.yaml` and
no leftover backup files — confirmed, then `git add
packages/jet_cad_2d_flutter/{shaders,assets,test}` and committed as the
brief's message.

## What the brief got wrong (or left implicit)

1. **The seven pre-existing, non-dash `expandInstances` calls in
   `instance_expander_test.dart`** (miter, join, point, transform-coefficient
   tests) needed `dashScale: 1.0` added once the parameter became required.
   The brief's step list only shows the six *new* tests; it doesn't mention
   these compile breaks, though its own Ruling P3 (about
   `gpu_comparison.dart`) already established the principle — "a task that
   ends with a non-compiling suite is not a completed task" — that made the
   fix here unambiguous.
2. **The attribute-count check.** The brief says to run
   `strings -a ... | grep -c "attribute "` and "record it," without stating
   an expected number. It came back 16, not 8 — each of the eight names
   appears twice in the compiled bundle (once per emitted GLES artifact),
   not once. Recorded here with the full attribute listing so the count is
   verifiable as "eight names, twice each," not just a bare "16."
3. Everything else — the `t`-in-collection-units design claim, the collapse
   representative/sibling split, the half-open fragment test, the eight-
   attribute ceiling — matched the brief exactly; no other correction
   needed.

## Review round 1 fix

Finding (Important): `resident_pixel_differential_test.dart`'s third
`measureResidentAgreement` call site (`openInk`) passed `dashScale: 1.0` as
a bare literal, unlike its two siblings, each of which explains why 1.0 is
correct there. Fixed by adding the same one-line reason, reusing the middle
site's exact wording rather than inventing a third phrasing:

```dart
pixelsPerPaperMm: _ppmm,
// Same camera on both arms -- see the corpus test's own comment.
dashScale: 1.0)
    .residentInk
```

Deferred per the coordinator: the reviewer's separate observation that `'a
point instance is never dashed'` is redundant against `'a solid instance
signals solid with a negative fracStart'` is real but out of scope for this
fix — the coordinator is carrying it to final review since the test was
mandated verbatim by the brief.

Commands:

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +2: All tests passed!              (exit 0)

$ flutter analyze
No issues found! (ran in 1.6s)           (exit 0)

$ dart format --output=none --set-exit-if-changed .
Formatted 90 files (0 changed) in 0.18 seconds.   (exit 0)
```

Commit: `8361cb6` — "fix(test): explain the third dashScale: 1.0 site too".
