# Task 7 report: the live scale reaches the shader, in the same 80 bytes

Branch: `plan-c/shaded-dashes`.

## Verification of the 80-byte arithmetic (before relying on it)

Confirmed by reading `buildFrameInfo` as it stood before this task: it
allocated `ByteData(80)`, wrote `f(0)`..`f(17)` from `mat4 mvp` and
`vec2 half_viewport`, and left `f(18, 0)` / `f(19, 0)` as trailing zeros —
verified live by running the existing (pre-change) test
`buildFrameInfo maps a device-space transform to NDC...`, which already
asserted `expect(at(18), 0); expect(at(19), 0);` and passed. That test run
(captured before any edits) is the independent confirmation the brief asked
for: the block really was 80 bytes with both trailing floats at zero, not an
assumption carried over from the brief's prose.

std140 arithmetic checks out: `mat4` (64B, 16B-aligned columns) + `vec2`
(8B-aligned, no gap at 64) = 72B; a trailing `float` needs only 4B alignment,
so it sits at 72–75 with no gap; the struct's own 16B alignment (inherited
from the `mat4`) rounds 76 up to 80. The block does not grow — `dash_scale`
lands in space that was always there as padding.

## What changed and why

`packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart`:

- `buildFrameInfo` gained `{required double dashScale}`, written at float
  index 18 (`f(18, dashScale)`); index 19 stays `f(19, 0)`, documented as
  alignment padding, not a second member. Made `required`, not defaulted —
  a defaulted 0 would collapse every dash pattern in the drawing to solid.
- Added a top-level `dashScaleFor(ViewportTransform camera, Transform2
  collectionInverse)` beside `composeTransforms`, exactly the brief's
  formula: `composeTransforms(camera.worldToScreenMatrix,
  collectionInverse).scaleMagnitude`.
- `GpuDrawBackend.render`: named the intermediate `collectionToLogical =
  composeTransforms(camera.worldToScreenMatrix, _collectionInverse)`, then
  `collectionToDevice = composeTransforms(Transform2.scale(dpr, dpr),
  collectionToLogical)`, and passed `dashScale: collectionToLogical
  .scaleMagnitude` into `buildFrameInfo`. This is the same count of
  `Transform2` compositions as before the change (one for
  `collectionToLogical`, one for folding in `dpr`) — no new per-frame
  composed transform was introduced, per the frame-path invariant.
- Doc comments updated on `buildFrameInfo` (block layout, `dashScale`
  semantics, why logical not device) and on the new `dashScaleFor` (why it
  exists only as a test seam and is not called from `render`, and why not
  calling it from `render` still keeps it "one implementation" — see below).

`packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart`:

- Updated the two existing `buildFrameInfo` calls to pass `dashScale:` (4.25
  and 1.0 respectively) and extended the first test's assertions to check
  `at(18)` against that value and `at(19)` stays 0.
- Added group `buildFrameInfo dash_scale` with two tests (brief's Step 1,
  adapted to this codebase's non-identity-fixture convention):
  1. **80 bytes, dash_scale at float 18.** `Transform2.identity()`,
     `dashScale: 2.5`; asserts `lengthInBytes == 80`, `at(18) == 2.5`,
     `at(19) == 0`.
  2. **dash_scale does not disturb mvp/half_viewport.** Non-identity
     `Transform2(2, 3, 5, 7, 11, 13)`, two calls differing only in
     `dashScale` (1.0 vs 3.0), loop-asserts floats 0..17 are unchanged.
- Added group `dashScaleFor` with the brief's third test, rewritten against
  the actual signature (which takes no `dpr`): builds one anisotropic,
  non-identity camera/`collectionInverse` pair, computes `logical =
  dashScaleFor(...)` (asserted `== 6.0`, not a coincidental 1), then defines
  `wrongDeviceScale(dpr)` — the collectionToDevice-based formula
  `render` would use if it mistakenly baked `dpr` into the dash-scale
  input — and asserts it equals `logical` at `dpr == 1` (the vacuous case,
  named explicitly) but equals `logical * 2` (and is *not* close to
  `logical`) at `dpr == 2`, which is the retina-display defect this task
  exists to prevent.

## One deviation from the brief's literal Step 3 code, and why

The brief's Step 3 snippet does not call `dashScaleFor` from `render` — it
recomputes `collectionToLogical.scaleMagnitude` inline. But its prose says
render should call "the same function — one implementation, one witness. Do
not leave a second copy of the expression inline." Taken literally that
would mean `render` calling `dashScaleFor(camera, _collectionInverse)`
directly — but that would **recompute** `composeTransforms(camera
.worldToScreenMatrix, _collectionInverse)` a second time per frame, since
`render` already needs that exact composed value (as `collectionToLogical`)
to build `collectionToDevice`. A second `Transform2` composition per frame is
a second per-frame allocation beyond the one `render` already builds — which
this task's own constraint explicitly forbids ("do not introduce a new
composed transform per frame beyond the one `render` already builds").

I kept the brief's literal Step 3 code (`collectionToLogical.scaleMagnitude`
inline in `render`, `dashScaleFor` uncalled from production code) and treated
"one implementation" as being about the *formula* — `composeTransforms(...)
.scaleMagnitude` — appearing once in substance, not about `render` calling
the named function syntactically. `dashScaleFor` exists solely as the test
seam the brief itself introduces it for ("`render` cannot run without a GPU
... Extract the one line ... and test that"). Documented this reasoning in
both doc comments so a future reader doesn't "fix" `render` into a second
allocation.

## Commands run, verbatim

### `flutter test test/gpu/frame_info_test.dart` (targeted)

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/frame_info_test.dart
...
00:00 +0: buildFrameInfo maps a device-space transform to NDC with y flipped, every float load-bearing
00:00 +1: buildFrameInfo a dpr fold survives composeTransforms + Transform2.scale, not just buildFrameInfo alone
00:00 +2: buildFrameInfo dash_scale the block is still 80 bytes and dash_scale is at float 18
00:00 +3: buildFrameInfo dash_scale dash_scale does not disturb the mvp or the half viewport
00:00 +4: dashScaleFor is logical, not device -- a dpr of 2 does not double it
00:00 +5: composeTransforms outer ∘ inner, every term of both operands load-bearing
00:00 +6: All tests passed!
```
Exit code: 0. 6 tests (3 pre-existing + 3 new), all green.

### `flutter test` (whole package)

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +516 ~1: .../tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:07 +517 ~1: All tests passed!
```
Exit code: 0. 517 passed, 1 skipped (pre-existing skip, unrelated to this
task), 0 failed.

### `flutter analyze`

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s / 1.2s across runs)
```
Exit code: 0.

### `dart format --output=none --set-exit-if-changed .`

First run (before formatting the two edited files) printed:
```
Changed test/gpu/frame_info_test.dart
Formatted 90 files (1 changed) in 0.20 seconds.
```
Exit code: 1 — a real failure, not ignored. Ran `dart format .` (no
`--set-exit-if-changed`) to apply formatting, then re-ran the check:
```
$ dart format --output=none --set-exit-if-changed .
Formatted 90 files (0 changed) in 0.19 seconds.
```
Exit code: 0.

`git status --short` before committing showed only the two intended files —
`analysis_options.yaml` was never touched:
```
 M packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart
 M packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart
```

## Per-test mutation kills (named before committing)

1. **"the block is still 80 bytes and dash_scale is at float 18"** —
   reddened by reverting `f(18, dashScale)` to `f(18, 0)`: `at(18)` would
   read `0.0` instead of `2.5`. (`lengthInBytes` alone would not move, since
   the block's size comes from the `mat4`'s alignment, not this member —
   which is why the test also pins the value, not just the length.)
2. **"dash_scale does not disturb the mvp or the half viewport"** —
   reddened by an off-by-one target index, e.g. `f(17, dashScale)` instead of
   `f(18, dashScale)`: `at(17)` (half-viewport y) would then differ between
   the `dashScale: 1.0` and `dashScale: 3.0` calls, which the loop over
   indices 0..17 catches.
3. **"dashScaleFor is logical, not device -- a dpr of 2 does not double it"**
   — reddened by making `dashScaleFor` compose with `Transform2.scale(dpr,
   dpr)` (the device-space mistake). Demonstrated live below.

## Demonstrated kill: `dashScaleFor`'s device-space mutation

Backup (not `git checkout --`):
```
$ cp lib/src/gpu/gpu_draw_backend.dart \
    /private/tmp/claude-501/.../scratchpad/gpu_draw_backend.dart.bak
```

Mutation applied to the committed, formatted, all-green function:
```diff
-double dashScaleFor(ViewportTransform camera, Transform2 collectionInverse) =>
-    composeTransforms(camera.worldToScreenMatrix, collectionInverse)
-        .scaleMagnitude;
+double dashScaleFor(ViewportTransform camera, Transform2 collectionInverse) =>
+    composeTransforms(
+      Transform2.scale(2.0, 2.0), // MUTATION: device-space dpr=2 mistake
+      composeTransforms(camera.worldToScreenMatrix, collectionInverse),
+    ).scaleMagnitude;
```

Run:
```
$ flutter test test/gpu/frame_info_test.dart
...
00:00 +4: dashScaleFor is logical, not device -- a dpr of 2 does not double it
00:00 +4 -1: dashScaleFor is logical, not device -- a dpr of 2 does not double it [E]
  Expected: a numeric value within <1e-9> of <6.0>
    Actual: <12.0>
     Which:  differs by <6.0>
  scaleMagnitude of a uniform (3*2)x scale is 6, not a coincidental 1
  ...
00:00 +4 -1: composeTransforms outer ∘ inner, every term of both operands load-bearing
00:00 +5 -1: Some tests failed.
```
Killed exactly as predicted — `12.0` is precisely `6.0 * dpr` for the
hardcoded `dpr = 2.0` in the mutation. Exit code: 1.

Restore:
```
$ cp /private/tmp/claude-501/.../scratchpad/gpu_draw_backend.dart.bak \
    lib/src/gpu/gpu_draw_backend.dart
$ diff lib/src/gpu/gpu_draw_backend.dart \
    /private/tmp/claude-501/.../scratchpad/gpu_draw_backend.dart.bak
$ echo $?
0
```
Byte-identical, restore confirmed. Re-ran the full targeted suite green
afterward (the 6/6 run captured above was taken after this point).

## What the brief got right / wrong

- The 80-byte arithmetic and index-18 placement were exactly right, and
  verified rather than trusted (see the first section).
- "Declare a bare `float`, not a `vec2`" — followed; only a scalar
  `dashScale` was added, no unread component.
- The one place the brief's literal code and its own stated intent
  ("one implementation, one witness... do not leave a second copy of the
  expression inline") pointed in different directions is the `render` call
  site — see "One deviation" above. I followed the literal code (which also
  satisfies the frame-path allocation constraint) over the looser prose
  reading that would have added a second per-frame `Transform2` allocation.
- The brief's proposed third test (`dashScaleAt(dpr: ...)`) referenced a
  function name that doesn't match the actual extracted signature
  (`dashScaleFor(ViewportTransform, Transform2)`, no `dpr` parameter, since
  the whole point is that the formula never sees `dpr`). Rewrote the test
  around the real signature, using a `wrongDeviceScale(dpr)` helper inside
  the test to model the mistake `dashScaleFor` must not make, which is a
  more direct way to show non-vacuousness at `dpr == 2` than the brief's
  sketch implied.

## `packages/jet_cad_2d` untouched, `shaders/`/`assets/shaders/` untouched

Confirmed by the `git status --short` output above (only the two
`jet_cad_2d_flutter` files) and by not opening any file under those paths
during this task.

## Addendum: `render` now calls `dashScaleFor` (coordinator correction)

The coordinator reversed the "do not introduce a new composed transform per
frame" reading above: the invariant is *per entity* / *O(1) per flush*, not
*no second composition ever*, and `render` already performs two compositions
per frame — a third stays O(1). More importantly, the deviation left the
*tested* formula (`dashScaleFor`) and the *shipping* formula
(`collectionToLogical.scaleMagnitude`, inline in `render`) as two separate
spellings of the same expression — exactly the shape where the device-space
mutation this task exists to prevent could land in the shipping copy with no
test able to see it, since `render` is unreachable from `flutter test`.
Agreed with the correction; made the change.

### What changed

`packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart`, `render`:

```diff
     final collectionToLogical =
         composeTransforms(camera.worldToScreenMatrix, _collectionInverse);
     final collectionToDevice =
         composeTransforms(Transform2.scale(dpr, dpr), collectionToLogical);
     pass.bindUniform(
       geometry.vertexShader.getUniformSlot('FrameInfo'),
       geometry.uniforms.emplace(buildFrameInfo(
           collectionToDevice, widthPx, heightPx,
-          dashScale: collectionToLogical.scaleMagnitude)),
+          dashScale: dashScaleFor(camera, _collectionInverse))),
     );
```

`collectionToLogical` stays named and used for `collectionToDevice` — it is
still needed for the mvp path, which is unrelated to `dashScale`. `dashScale`
now comes from calling `dashScaleFor(camera, _collectionInverse)`, which
recomputes `composeTransforms(camera.worldToScreenMatrix,
_collectionInverse)` a second time (once as `collectionToLogical`, once
inside `dashScaleFor`) rather than reusing the first result. That is one
extra `Transform2.multiply` per frame, not per entity, and `render` already
performs two compositions before this one — inside the O(1)-per-flush
invariant, not a violation of it.

Rewrote both doc comments that argued for the old (now-reversed) shape:

- `dashScaleFor`'s own doc comment no longer says "render does not call this
  function" and no longer frames the inline read as protecting the
  frame-path invariant. It now says why `render` must call this function
  specifically (the mutation-coverage argument above) and why the added
  composition is still O(1) per frame, not a violation.
- The comment block at the `render` call site was rewritten the same way —
  removed the reasoning for reading `collectionToLogical.scaleMagnitude`
  directly, replaced with why `dashScaleFor(camera, _collectionInverse)` is
  called instead and why the redundant composition is acceptable.

### Re-fired mutation kill against the new shape

Backup (not `git checkout --`):
```
$ cp lib/src/gpu/gpu_draw_backend.dart \
    /private/tmp/claude-501/.../scratchpad/gpu_draw_backend.dart.bak2
```

Same mutation as before — `dashScaleFor` composes with the device-space
`Transform2.scale(2.0, 2.0)`:
```diff
 double dashScaleFor(ViewportTransform camera, Transform2 collectionInverse) =>
-    composeTransforms(camera.worldToScreenMatrix, collectionInverse)
-        .scaleMagnitude;
+    composeTransforms(
+      Transform2.scale(2.0, 2.0), // MUTATION: device-space dpr=2 mistake
+      composeTransforms(camera.worldToScreenMatrix, collectionInverse),
+    ).scaleMagnitude;
```

Run:
```
$ flutter test test/gpu/frame_info_test.dart
...
00:00 +4: dashScaleFor is logical, not device -- a dpr of 2 does not double it
00:00 +4 -1: dashScaleFor is logical, not device -- a dpr of 2 does not double it [E]
  Expected: a numeric value within <1e-9> of <6.0>
    Actual: <12.0>
     Which:  differs by <6.0>
  scaleMagnitude of a uniform (3*2)x scale is 6, not a coincidental 1
  ...
00:00 +4 -1: composeTransforms outer ∘ inner, every term of both operands load-bearing
00:00 +5 -1: Some tests failed.
```
Killed, same failure shape as before the correction — expected, since
`dashScaleFor`'s body and this test are unchanged; what changed is that
`render` now depends on that same body at runtime. Exit code: 1.

Restore:
```
$ cp /private/tmp/claude-501/.../scratchpad/gpu_draw_backend.dart.bak2 \
    lib/src/gpu/gpu_draw_backend.dart
$ diff lib/src/gpu/gpu_draw_backend.dart \
    /private/tmp/claude-501/.../scratchpad/gpu_draw_backend.dart.bak2
$ echo $?
0
```
Byte-identical, restore confirmed.

### Full gate, re-run after the change

```
$ flutter test test/gpu/frame_info_test.dart
...
00:00 +5: composeTransforms outer ∘ inner, every term of both operands load-bearing
00:00 +6: All tests passed!
```
Exit code: 0.

```
$ flutter test
...
00:07 +516 ~1: .../tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:07 +517 ~1: All tests passed!
```
Exit code: 0. 517 passed, 1 pre-existing unrelated skip, 0 failed.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 90 files (0 changed) in 0.17 seconds.
```
Exit code: 0.

`git status --short` before committing showed only the one file this
addendum touched:
```
 M packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart
```
`analysis_options.yaml` not touched.
