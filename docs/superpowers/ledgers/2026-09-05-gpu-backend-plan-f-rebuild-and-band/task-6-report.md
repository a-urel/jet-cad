# Task 6 report: the compositor rejects off-viewport labels, and the frame path's per-patch objects become fields

## What was implemented

1. **`TextCompositor` viewport rejection** (`lib/src/gpu/text_compositor.dart`):
   - Added `final Float64List _bound = Float64List(4);` (reused scratch) and
     `int labelsSkipped = 0;` (diagnostic counter, reset per `paint` call
     alongside `_patchesComposited`).
   - The plain-label branch of `paint` now calls `boundTransformedBox` into
     `_bound` and skips (`labelsSkipped++`) any label whose box misses the
     viewport on any of the four sides; a box merely touching the edge is
     still drawn (the paragraph clips itself).

2. **`PatchRegion` made mutable, `patchRegionFor(out:)`**
   (`lib/src/gpu/text_patches.dart`):
   - `PatchRegion` lost its `const` constructor and `final` fields; `x, y,
     width, height` are now mutable `int`s, documented as pooled by
     `GpuDrawBackend`.
   - `patchRegionFor` gained `PatchRegion? out`: when given, it writes
     `x0, y0, w, h` into `out` in place and returns it; an off-screen result
     returns `null` without touching `out` at all (verified by the new
     test). No `out` (rebuild-time callers, tests) still allocates a fresh
     `PatchRegion`.

3. **`buildFrameInfo(out:)`, and the backend's own reused fields**
   (`lib/src/gpu/gpu_draw_backend.dart`):
   - `buildFrameInfo` gained `ByteData? out`; it uses `out` in place only
     when it is exactly 80 bytes, otherwise allocates a fresh block (all
     twenty floats, `f(19, 0)` included, are always written explicitly, so a
     reused block never carries stale data forward).
   - `GpuDrawBackend` replaced the per-patch `(ResidentPatch, PatchRegion)`
     record list (`_pendingRegions`) with:
     - `final ByteData _frameInfo = ByteData(80);` -- one uniform block,
       passed as `out:` to both `emplace(buildFrameInfo(...))` call sites
       (main pass and patch pass).
     - `final List<PatchRegion> _regionPool = <PatchRegion>[];` -- grown to
       `geometry.patches.length` lazily, one `PatchRegion(0,0,0,0)` per new
       slot, never shrunk.
     - `final List<ResidentPatch> _pendingPatches` and
       `final List<PatchRegion> _pendingRegions` -- two parallel lists,
       cleared at the top of `render` (added `_pendingPatches.clear()`
       beside the existing `_pendingRegions.clear()`), filled in the patch
       loop (indexed `for (var p = 0; ...)`, `_regionPool[p]` passed as
       `patchRegionFor`'s `out`), and drained by index in the tail instead
       of the record-destructuring `for (final (patch, region) in
       _pendingRegions)`.
   - Updated the class doc's enumeration of per-patch allocations:
     `PatchRegion` and the uniform block are off the list; `PatchImage`,
     three `Rect`s, the `Transform2` for `toPatch`, one `saveLayer` and one
     `asImage()` handle remain, alongside the GPU shim's own per-pass
     objects (`gpu.Viewport`, `vm.Vector4`, `gpu.BufferView`, the command
     buffer, the render pass) which Task 8's probe reports beside ours.
   - Updated the "left populated here" comment at the tail of `render` to
     name both `_pendingPatches` and `_pendingRegions`.

## TDD evidence

### Step 1-2: compositor test, RED

Created `test/gpu/text_compositor_viewport_test.dart` verbatim from the
brief. Ran before any implementation change:

```
$ flutter test test/gpu/text_compositor_viewport_test.dart
...
test/gpu/text_compositor_viewport_test.dart:63:23: Error: The getter 'labelsSkipped' isn't defined for the type 'TextCompositor'.
test/gpu/text_compositor_viewport_test.dart:74:23: Error: The getter 'labelsSkipped' isn't defined for the type 'TextCompositor'.
00:00 +0 -1: Some tests failed.
```
Compilation failure, as expected (RED).

### Step 3-4: rejection implemented, GREEN

After adding `_bound`, `labelsSkipped` and the rejection branch:

```
$ flutter test test/gpu/text_compositor_viewport_test.dart test/gpu/text_compositor_test.dart test/gpu/text_order_test.dart
...
00:00 +15: All tests passed!
```
(15 tests: the new viewport test, 8 existing `text_compositor_test.dart`
tests, 6 `text_order_test.dart` differential tests -- all green.)

### Step 4 (continued): the two `out:` tests, RED

Added the `buildFrameInfo` `out:` test to `test/gpu/frame_info_test.dart`
and the `patchRegionFor` `out:` test to `test/gpu/text_patches_test.dart`,
before touching `buildFrameInfo`/`patchRegionFor`'s signatures:

```
$ flutter test test/gpu/frame_info_test.dart test/gpu/text_patches_test.dart
...
test/gpu/frame_info_test.dart:160:68: Error: No named parameter with the name 'out'.
test/gpu/text_patches_test.dart:305:44: Error: No named parameter with the name 'out'.
test/gpu/text_patches_test.dart:310:44: Error: No named parameter with the name 'out'.
00:00 +0 -2: Some tests failed.
```
Compilation failure, as expected (RED).

### Step 5: the reuses implemented, GREEN

After adding `out:` to `buildFrameInfo` and `patchRegionFor`, and making
`PatchRegion` mutable:

```
$ flutter test test/gpu/frame_info_test.dart test/gpu/text_patches_test.dart
...
00:00 +28: All tests passed!
```

### Step 6: all five named files together, GREEN

```
$ flutter test test/gpu/text_compositor_viewport_test.dart test/gpu/text_compositor_test.dart test/gpu/text_patches_test.dart test/gpu/frame_info_test.dart test/gpu/text_order_test.dart
...
00:00 +43: All tests passed!
```

### Mutation check (self-review, beyond the brief's steps)

To confirm the new compositor test actually catches the named mutation
(M-F11: invert the rejection), I inverted the boolean in
`text_compositor.dart`'s rejection condition, re-ran the suite, and
restored the file:

```
$ flutter test test/gpu/text_compositor_viewport_test.dart test/gpu/text_order_test.dart
00:00 +0 -5: .../text_order_test.dart: the composited picture matches the reference at scale 2.0 [E]
  Expected: a value greater than or equal to <0.995>
    Actual: <0.7747019323009456>
...
00:00 +0 -6: .../text_order_test.dart: with level of detail on, both arms cull TINY the same way at scale 1 [E]
  Expected: a value greater than or equal to <0.995>
    Actual: <0.8398215733982157>
...
00:00 +2 -6: Some tests failed.

Failing tests:
  test/gpu/text_compositor_viewport_test.dart: labels outside the viewport are skipped; inside and straddling are drawn
  test/gpu/text_order_test.dart: the composited picture matches the reference at scale 0.5
  test/gpu/text_order_test.dart: the composited picture matches the reference at scale 0.8
  test/gpu/text_order_test.dart: the composited picture matches the reference at scale 1.25
  ... and 2 more
```
Both the new test and `text_order_test.dart`'s composited differential go
red under the mutation, as the brief's comment predicted. File restored
from a backup copy (`cp` before/after); `git diff --stat` after restoring
showed the file back to its pre-mutation state, and the full gate (below)
was re-run clean afterward.

## Gate commands (final, after restoring the mutation)

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +654 ~1: All tests passed!
$ echo $?
0
```
(654 passed, 1 skipped -- the skip is pre-existing and unrelated to this
task, per `draw_sink_test.dart`'s own skip reason: "GeometryCollector
shades dashes and the bracket is a no-op today (Task 5 implements it)".)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
$ echo $?
0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.16 seconds.
$ echo $?
0
```

All three gates: exit 0.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/gpu/text_compositor.dart` (modified)
- `packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart` (modified)
- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart` (modified)
- `packages/jet_cad_2d_flutter/test/gpu/text_compositor_viewport_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/gpu/text_patches_test.dart` (modified)
- `packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart` (modified)

`git status --short` before staging showed exactly these six paths (five
modified, one untracked); no `analysis_options.yaml` touched.
`packages/jet_cad_2d`, `vertices_draw_sink.dart`, `canvas_draw_sink.dart`
were not touched. No shader change.

## Self-review findings

- Grepped the whole tree for `const PatchRegion(` and `PatchRegion` before
  and after the edit: the only call sites were `text_patches.dart` itself
  and the two `text_patches_test.dart` sites I added (already non-const).
  No other file constructed a `PatchRegion`, so the brief's "drop the
  `const` where found" step had nothing to do beyond what the new tests
  already wrote correctly.
- Verified the `_regionPool` growth loop (`while (_regionPool.length <=
  p) { _regionPool.add(PatchRegion(0, 0, 0, 0)); }`) only ever grows, never
  shrinks, and reuses existing slots on every subsequent frame with the
  same or fewer patches -- steady state allocates nothing there.
- Verified `_frameInfo` is threaded through both `emplace(buildFrameInfo(...))`
  call sites (main pass and patch pass) as `out:`, and that
  `HostBuffer.emplace` (per the class's own existing doc comment) copies
  the bytes out, so reusing one `ByteData` for two `emplace` calls per
  frame is safe -- the second `emplace` does not retroactively corrupt the
  first pass's already-copied uniform data.
- Ran a manual mutation (inverting the rejection's boolean) to confirm the
  new compositor test is load-bearing and not vacuously green; it kills
  both the new test and the pre-existing `text_order_test.dart` composited
  differential, as the brief's own comment claims. Restored the file
  afterward and re-ran the full gate to confirm no residue.
- Confirmed `patchRegionFor`'s off-screen path returns `null` before
  touching `out` at all (the `if (x1 <= x0 || y1 <= y0) return null;` guard
  precedes the `out` write), matching the test's expectation that an
  off-screen answer "must not scribble on the pool entry."

## Concerns

None. All three gates pass at exit 0, TDD evidence is complete for every
step the brief specifies, and a manual mutation check beyond the brief's
own steps confirms the new test is not vacuous.

---

# Fix round 1 (review findings)

Commit HEAD before this round: `8b1427e`. Review found the shipped code
correct but flagged two test-strength gaps, both in brief-supplied tests.

## Finding 1 — `buildFrameInfo`'s `out:` test didn't prove "every float
written explicitly"

**Problem.** `out` was a virgin `ByteData(80)` (zeroed by the runtime) and
`fresh` is also all the structural zeros `buildFrameInfo` writes as
literals (`f(2,0)`, `f(3,0)`, `f(6,0)`, `f(7,0)`, `f(8,0)`, `f(9,0)`,
`f(11,0)`, `f(14,0)`, `f(19,0)`). The byte loop compared zero to zero for
every one of those floats regardless of whether the function actually
wrote them, so deleting any single `f(i, 0)` line would leave the test
green.

**Fix.** In `test/gpu/frame_info_test.dart`, before calling
`buildFrameInfo(..., out: out)`, the test now pre-dirties every byte of
`out` to `0xFF`:

```dart
final out = ByteData(80);
// A reused block must be fully overwritten: every byte starts dirty,
// so a byte the function only ever writes as a literal 0 (`f(2, 0)`,
// `f(19, 0)`, and the other structural zeros) still has to come back
// 0 -- a virgin, already-zeroed `ByteData` could not tell "explicitly
// written" from "never touched" apart.
for (var i = 0; i < 80; i++) {
  out.setUint8(i, 0xFF);
}
final written = buildFrameInfo(m, 800, 600, dashScale: 1.7, out: out);
```

**Hand-fired mutation, RED.** Deleted `f(19, 0);` from `buildFrameInfo` in
`lib/src/gpu/gpu_draw_backend.dart` (backed up first with `cp`), ran:

```
$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && flutter test test/gpu/frame_info_test.dart
...
00:00 +2: buildFrameInfo buildFrameInfo writes into `out` when given one of the right size
00:00 +2 -1: buildFrameInfo buildFrameInfo writes into `out` when given one of the right size [E]
  Expected: <0>
    Actual: <255>
  byte 76

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/frame_info_test.dart 165:9                 main.<fn>.<fn>

00:00 +2 -1: buildFrameInfo dash_scale the block is still 80 bytes and dash_scale is at float 18
...
00:00 +7 -1: Some tests failed.
```

Byte 76 is float index 19 (`76 / 4 = 19`) -- exactly the deleted write.
Restored `gpu_draw_backend.dart` from the `cp` backup;
`git diff --stat lib/src/gpu/gpu_draw_backend.dart` after restoring
produced no output (file bit-identical to the committed `8b1427e`
version), and `flutter test test/gpu/frame_info_test.dart` was re-run
green afterward.

## Finding 2 — the compositor test only ever failed on two of the four
sides

**Problem.** The brief's four fixtures only ever missed the viewport on
the left (`_bound[2] < 0`) and below (`_bound[1] > height`); nothing was
off the right or above, so a rejection with the x and y comparisons
transposed (`_bound[1] > viewport.width` and `_bound[0] >
viewport.height` instead of the other way round) would still pass both
assertions.

**Fix.** Rewrote `test/gpu/text_compositor_viewport_test.dart`'s first
test with six labels under a pan of `(-1000, -1000)` on a deliberately
asymmetric `Size(400, 2000)` viewport, one per rejection clause plus the
two that must still draw, each classified by exactly one of
`boundTransformedBox`'s four bounds:

- `inside`: collection `(1020, 1100)..(1100, 1130)` -> screen
  `(20, 100)..(100, 130)` -- drawn.
- `offLeft`: collection `(400, 1100)..(480, 1130)` -> screen
  `(-600, 100)..(-520, 130)` -- `maxX < 0`.
- `straddleLeft`: collection `(970, 1200)..(1030, 1230)` -> screen
  `(-30, 200)..(30, 230)` -- overlaps the left edge, no clause fires,
  drawn.
- `offRight`: collection `(1500, 1100)..(1580, 1130)` -> screen
  `(500, 100)..(580, 130)` -- `minX (500) > width (400)`. Chosen so the
  swap is actually visible: `minX (500)` is NOT `> height (2000)` and
  `minY (100)` is NOT `> width (400)`, so neither swapped comparison
  fires by coincidence.
- `offTop`: collection `(1020, 900)..(1100, 930)` -> screen
  `(20, -100)..(100, -70)` -- `maxY < 0`.
- `offBottom`: collection `(1000, 3100)..(1080, 3150)` -> screen
  `(0, 2100)..(80, 2150)` -- `minY (2100) > height (2000)`.

Expectations: 2 drawn (`inside`, `straddleLeft`), `labelsSkipped == 4`.
The anti-vacuity arm keeps the same six labels under
`Transform2.identity()` on a `Size(2000, 3200)` viewport (large enough to
contain every collection-space box, including `offBottom`'s new
`y = 3150`) and expects all 6 drawn, 0 skipped.

A first attempt used a square-ish `Size(400, 300)` viewport with
`offRight`/`offBottom` placed far enough out that BOTH the correct and the
swapped comparison fired on each of them (500 and 900+ both exceed 400
and 300) -- the swap was undetectable, confirmed by actually running it
(see below). The `Size(400, 2000)` asymmetry above is what breaks that
coincidence: `width < height` lets `offRight`'s `minX` clear `width` but
stay under `height`, so only the correct comparison fires on it.

Also added a second test pinning `boundTransformedBox`'s four-corner
bound under a **rotated** outer transform (nothing exercised this
before): `Transform2.translation(50, 50).multiply(Transform2.rotation(pi
/ 2))`, worked out by hand in the test's comments from
`Transform2.rotation`'s own factory (`transform2.dart`:
`(cos, sin, -sin, cos, 0, 0)`) and `Transform2.multiply`'s composition
order, giving `composed = (0, 1, -1, 0, 50, 50)`, i.e.
`(x, y) -> (50 - y, 50 + x)`. Two labels: `onScreen` (collection
`(0,0)..(50,20)`, bound `(30,50)..(50,100)`, inside `Size(400,300)`) and
`offScreen` (collection `(1000,0)..(1050,20)`, bound
`(30,1050)..(50,1100)`, `minY = 1050 > 300`). Expect 1 drawn, 1 skipped.

**Hand-fired mutations, both RED.**

1. Axis swap (the finding's own mutation) -- edited
   `lib/src/gpu/text_compositor.dart`'s rejection to
   `_bound[1] > viewport.width || ... || _bound[0] > viewport.height`
   (backed up first with `cp`), ran:

   ```
   $ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && flutter test test/gpu/text_compositor_viewport_test.dart
   ...
   00:00 +0: labels outside the viewport are skipped on all four sides; inside and straddling are drawn
   00:00 +0 -1: labels outside the viewport are skipped on all four sides; inside and straddling are drawn [E]
     Expected: <2>
       Actual: <3>
     inside and straddleLeft

     package:matcher                                     expect
     package:flutter_test/src/widget_tester.dart 473:18  expect
     test/gpu/text_compositor_viewport_test.dart 107:5   main.<fn>

   00:00 +0 -1: a rotated outer transform is bounded correctly, not just a pan -- boundTransformedBox's min/max ordering under rotation
   00:00 +1 -1: Some tests failed.
   ```

   `offRight` is drawn instead of skipped under the swap, as predicted:
   `drawParagraph` count moves from 2 to 3. Restored
   `text_compositor.dart` from the `cp` backup;
   `git diff --stat lib/src/gpu/text_compositor.dart` after restoring
   produced no output (bit-identical to `8b1427e`).

2. This also confirms the pre-fix version of the test (the earlier
   `Size(400, 300)` layout) was genuinely blind to the mutation: run
   under that layout with the same axis swap, all assertions still
   passed (both `offRight` and `offBottom` cleared 400 AND 300, so the
   swapped comparison fired on the wrong axis by coincidence and produced
   the same skip verdict). This was the reproduction that motivated the
   `Size(400, 2000)` redesign above, not a claim landed in the suite.

## Covering tests, run together after both fixes

```
$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && flutter test test/gpu/text_compositor_viewport_test.dart test/gpu/frame_info_test.dart test/gpu/text_compositor_test.dart test/gpu/text_order_test.dart
...
00:00 +24: All tests passed!
```

## Gate commands (fix round 1)

```
$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && flutter test
...
00:07 +655 ~1: All tests passed!
$ echo $?
0
```

```
$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.4s)
$ echo $?
0
```

```
$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.16 seconds.
$ echo $?
0
```

All three gates: exit 0. `git status --short` before staging showed only
the two intended test files modified; no `analysis_options.yaml` touched.

## Files changed (fix round 1)

- `packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart` (modified)
- `packages/jet_cad_2d_flutter/test/gpu/text_compositor_viewport_test.dart` (modified)

Committed as `500f67c`, `test(gpu): the uniform block's reuse and the
compositor's four sides have witnesses`.

## Concerns (fix round 1)

None. Both findings were fixed exactly as scoped (test-strength only, no
production-code change), both hand-fired mutations went red and were
restored cleanly, and all three gates pass at exit 0.
