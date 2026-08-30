# Task 6 report: the frame path — one uniform write, one draw call

## What I implemented

- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart`
  - `ByteData buildFrameInfo(Transform2 collectionToScreen, int widthPx, int heightPx)`
    — pure, no GPU. Packs the `FrameInfo` uniform (column-major `mat4 mvp` +
    `vec2 half_viewport`) as 80 bytes.
  - `Transform2 composeTransforms(Transform2 outer, Transform2 inner)` — `outer ∘ inner`.
  - `class GpuDrawBackend` — `GpuDrawBackend(ResidentGeometry, ViewportTransform)`,
    `ui.Image? render(ViewportTransform camera, Size viewport, double dpr)`,
    `int get frames`, `void dispose()`.
- `packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart` — covers
  `buildFrameInfo` and `composeTransforms`, no GPU.

`render` follows the brief's given implementation essentially verbatim (I
verified every API call against the actual `flutter_gpu`/`flutter_scene`
source rather than assuming it, see below) — one texture (cached across
frames unless the size changes), one command buffer, one render pass, two
vertex buffer bindings (corners at slot 0, instances at slot 1), one uniform
bind, one `draw(6, instanceCount: geometry.instanceCount)`.

## What I tested and the results

`test/gpu/frame_info_test.dart`, two tests: `buildFrameInfo` and
`composeTransforms`. Both are pure-function tests, no GPU context needed.

### TDD Evidence

**RED** — `flutter test test/gpu/frame_info_test.dart` with
`gpu_draw_backend.dart` temporarily removed (backed up with `cp` to
`/tmp/gpu_draw_backend.dart.real` first, not `git checkout`, since nothing
had been committed yet to check out from):

```
test/gpu/frame_info_test.dart:5:8: Error: Error when reading 'lib/src/gpu/gpu_draw_backend.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/gpu/gpu_draw_backend.dart';
       ^
test/gpu/frame_info_test.dart:21:20: Error: Method not found: 'buildFrameInfo'.
      final data = buildFrameInfo(collectionToScreen, 200, 100);
                   ^^^^^^^^^^^^^^
test/gpu/frame_info_test.dart:53:22: Error: Method not found: 'composeTransforms'.
      final result = composeTransforms(outer, inner);
                     ^^^^^^^^^^^^^^^^^
00:00 +0 -1: loading .../frame_info_test.dart [E]
```

Expected failure, for the expected reason — both pure functions genuinely
did not exist yet.

**GREEN** — restored the implementation (`cp` back from the backup), ran
again:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart
00:00 +0: buildFrameInfo maps screen space to NDC with y flipped, every matrix term load-bearing
00:00 +1: composeTransforms outer ∘ inner, every term of both operands load-bearing
00:00 +2: All tests passed!
```

## Mutation Evidence

Backed up the real file first (`cp lib/src/gpu/gpu_draw_backend.dart
/tmp/gpu_draw_backend.dart.pre_mutation`), then made the named edit — negate
the y row by replacing `sy` with `+2.0 / heightPx` at the one call site the
brief names:

```diff
-  f(5, collectionToScreen.d * sy);
+  f(5, collectionToScreen.d * (2.0 / heightPx));
```

`flutter test test/gpu/frame_info_test.dart`, actual output:

```
00:00 +0: buildFrameInfo maps screen space to NDC with y flipped, every matrix term load-bearing
00:00 +0 -1: buildFrameInfo maps screen space to NDC with y flipped, every matrix term load-bearing [E]
  Expected: a numeric value within <0.000001> of <-0.14>
    Actual: <0.14000000059604645>
     Which:  differs by <0.28000000059604646>
  d * sy -- the y-scale row; negating sy here is the named mutation for this task

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/frame_info_test.dart 35:7                  main.<fn>.<fn>

00:00 +0 -1: composeTransforms outer ∘ inner, every term of both operands load-bearing
00:00 +1 -1: Some tests failed.
```

Red, on the exact assertion the mutation targets (`at(5)`), for the exact
reason (the sign flip of the y row). Reverted with `cp
/tmp/gpu_draw_backend.dart.pre_mutation lib/src/gpu/gpu_draw_backend.dart`
and confirmed with `diff` against the pre-mutation backup that the file was
byte-identical to the original (`IDENTICAL TO ORIGINAL`). Re-ran the test —
green again:

```
00:00 +0: buildFrameInfo maps screen space to NDC with y flipped, every matrix term load-bearing
00:00 +1: composeTransforms outer ∘ inner, every term of both operands load-bearing
00:00 +2: All tests passed!
```

No `git checkout` was used at any point during mutation or its reversion —
only `cp` backups and restores, per this task's explicit safety instruction.

## Why each term of my test fixture is load-bearing

The brief's own Step 1 sample test uses `Transform2.identity()` for
`collectionToScreen`. I did not use that fixture — I deviated from the
brief's literal test content here, deliberately, because it is exactly this
codebase's named dominant failure mode (a diagonal/identity transform makes
off-diagonal terms untestable) and the task instructions explicitly call
for avoiding it. With `a=1, b=0, c=0, d=1, e=0, f=0`:

- `at(1) = b * sy = 0 * sy = 0` regardless of whether the code reads `b` at
  all, multiplies it by the right scale, or has the term dropped entirely.
- `at(4) = c * sx = 0 * sx = 0` — same problem, the other off-diagonal term.

Both would silently pass under a bug that swapped, dropped, or
mistranslated `b`/`c`. My fixture uses `Transform2(2, 3, 5, 7, 11, 13)` —
six distinct, nonzero terms:

- `a=2` → `at(0) = a*sx = 0.02` — catches a wrong or missing `a`, or `sx`
  computed from the wrong dimension.
- `b=3` → `at(1) = b*sy = -0.06` — the off-diagonal term an identity fixture
  cannot exercise; catches `b` dropped, swapped with `c`, or `sy`'s sign
  applied to the wrong row.
- `c=5` → `at(4) = c*sx = 0.05` — the other off-diagonal term; catches the
  mirror-image mistake (`c` swapped with `b`, or `sx` misapplied here).
- `d=7` → `at(5) = d*sy = -0.14` — the y-scale row. This is the named
  mutation's target: negating `sy` here flips the sign and the test catches
  it exactly.
- `e=11` → `at(12) = e*sx - 1 = -0.89` — catches the x-translate mapping and
  the NDC `-1` offset independently (a wrong `e`, wrong `sx`, or a dropped/
  mis-signed `-1` all move this value).
- `f=13` → `at(13) = f*sy + 1 = 0.74` — catches the y-translate mapping and
  the NDC `+1` offset the same way.
- `widthPx=200, heightPx=100` (asymmetric, kept from the brief's own
  fixture) → `at(16)=100, at(17)=50` — a swapped width/height would show up
  as `100`/`50` transposed, not cancel out.

Since all six of `a,b,c,d,e,f` are distinct primes, no accidental
cancellation or coincidental match can make a swapped or dropped term
produce the same numeric result as the correct one — the property the
brief's own "Beware the degenerate fixture" section asks for.

`composeTransforms` gets the identical treatment: `outer = Transform2(2, 3,
5, 7, 11, 13)`, `inner = Transform2(17, 19, 23, 29, 31, 37)` — twelve
distinct primes across both operands, so a transposed pair anywhere in the
formula (e.g. `b`/`c` swapped, or an `outer`/`inner` term crossed) cannot
land on the same value as the correct term. Expected outputs are
hand-computed integer arithmetic (`129, 184, 191, 272, 258, 365`), asserted
with exact `expect(result.a, 129)` rather than against `Transform2.multiply`
— comparing to the method `composeTransforms` structurally duplicates would
not catch a mistake shared by both.

Float32 tolerance: `buildFrameInfo`'s assertions use `closeTo(..., 1e-6)`
rather than the brief's `1e-9`. At my fixture's magnitudes (values up to
~1.0), float32's ~2^-24 relative precision gives round-trip error up to
roughly `1e-9` at the smallest values here and larger at bigger ones —
tight enough that `1e-9` was at risk of a false failure from rounding noise
alone, not from a real defect. `1e-6` still catches every mutation in this
file, since a dropped negation or a swapped term changes results by 100%,
not by parts in a million.

## Where the `HostBuffer` reset happens and why there

`geometry.uniforms.reset()` is called once per `render()`, immediately
after `commandBuffer.submit()` and before `frames++` (see the doc comment
at that call site in `gpu_draw_backend.dart`).

- **Why once per frame at all:** `HostBuffer` is a bump allocator
  (`flutter_gpu/lib/src/buffer.dart:208-223`, verified by reading the
  vendored source at
  `/opt/homebrew/Caskroom/flutter/3.27.3/flutter/bin/cache/pkg/flutter_gpu/lib/src/buffer.dart`).
  `emplace` only ever advances the cursor forward inside the current
  1,024,000-byte block; nothing else in this class rewinds it. Without a
  reset, each frame's `FrameInfo` emplacement (80 bytes, 256-aligned per
  `minimumUniformByteAlignment`) permanently consumes a slice of the block.
  The block fills after roughly 12,800 frames and then silently starts
  allocating a fresh `DeviceBuffer` block every frame thereafter — direct,
  measurable per-frame allocation, which is this project's stated
  non-negotiable ("the frame path allocates nothing per entity in steady
  state, and O(1) per flush").
- **Why after `submit()`, not before:** `submit()` records this frame's
  commands, including the uniform bind that reads from whatever ring slot
  is currently active. `reset()` only advances the bookkeeping cursors
  (`_frameCursor`, `_bufferCursor`, `_offsetCursor`) — it does not touch any
  buffer's bytes — so calling it after `submit()` cannot invalidate data
  this frame's commands already reference. Calling it *before* this frame's
  own `emplace()` would produce the same net per-frame effect (advance
  exactly once per `render()` call either way), but placing it after
  `submit()` keeps the ordering easy to state: "write and submit this
  frame's data against the current ring slot, then hand the next frame a
  fresh one." `target.asImage()` (called after `reset()`) does not depend
  on `geometry.uniforms` at all — it reads the render target texture, an
  unrelated GPU resource — so nothing after the reset call needs the
  uniform buffer's state.
- I did **not** find a test in this package that exercises this reset path,
  because `GpuDrawBackend` needs a live GPU device, and none is available in
  `flutter test` on this checkout (see "parts no test exercises" below).

## What I found on the 128-vs-80 uniform size, and what I chose

I chose **80 bytes**, and I settled it from code rather than assumption —
this is not the "pick one and hope" case the brief flags as unacceptable.

- Plain std140 arithmetic for `mat4 mvp; vec2 half_viewport;` gives 80:
  `mat4` is 64 bytes (four 16-byte-aligned `vec4` columns); `vec2` needs
  only 8-byte alignment, so it fits at offset 64..72 with no padding gap;
  the struct's own base alignment is 16 (from `mat4`), which rounds the
  72-byte content up to 80.
- I read the vendored `flutter_gpu` source
  (`/opt/homebrew/Caskroom/flutter/3.27.3/flutter/bin/cache/pkg/flutter_gpu/lib/src/{render_pass,buffer,shader}.dart`).
  `RenderPass.bindUniform` forwards `BufferView.offsetInBytes`/
  `lengthInBytes` straight to the native `_bindUniformDevice` call; it never
  reads `UniformSlot.sizeInBytes` (the reflected 128). `HostBuffer.emplace`
  sizes its `BufferView` to exactly the `ByteData` it was handed — nothing
  pads it out to the reflected struct size. So on the Dart side of the
  native backend, nothing enforces or even checks the 128 figure at bind
  time; it exists purely as reflection metadata (`Shader
  ._getUniformStructSize`), reachable through `UniformSlot.sizeInBytes` but
  never consulted by the binding path itself.
- The web backend (`flutter_scene` 0.23.0,
  `lib/src/gpu/web/render_pass.dart` and `web/buffer.dart`) makes the same
  assumption explicit rather than implicit. Its `RenderPass.bindUniform`
  contains this comment and code, which is exactly this task's question,
  already answered by the library's own authors:

  ```dart
  // Bind at least the driver-reported block data size; the emplaced
  // length alone can be smaller than the driver's padded size, and a
  // too-small range makes the draw a no-op. DeviceBuffer pads its GL
  // data store so the extended range stays inside the buffer.
  var lengthInBytes = bufferView.lengthInBytes;
  final minBindSize = pipeline._structBlockBindSizes[struct.name];
  if (minBindSize != null && minBindSize > lengthInBytes) {
    lengthInBytes = minBindSize;
  }
  ```

  i.e., the web shim *expects* callers to emplace exactly the content size
  (80) and widens the bound range itself when the driver wants more,
  backed by 256 bytes of tail padding on the `DeviceBuffer`'s GL data store
  (`_kUniformTailPaddingBytes`). Pre-padding to 128 on the caller's side
  would work too, but is not what the API is designed around.
- The spike (`apps/dev_harness_2d/lib/gpu_arm.dart:414`, `ByteData(80)`)
  already runs this identical 80-byte layout and is reported (by the task
  brief, which is closer to that measurement than I am) to run correctly on
  macOS Metal.
- What I could **not** do: run a real device in this session to watch the
  native Metal/Vulkan path bind an 80-byte range against a shader whose
  reflection says 128, byte for byte. That would be the fully conclusive
  check. Given the Dart-layer evidence (no validation against the reflected
  size anywhere in the bind path) and the web backend's explicit, documented
  handling of exactly this situation, I judged 80 bytes settled rather than
  merely assumed, and did not fall back to the "conservative" 128 the brief
  allows for an unsettled case. Task 7's harness run is where this gets its
  final, device-backed confirmation, same as `resident_geometry.dart`'s
  shader-bundle asset path.

## Which parts of this file no test exercises, and why

`render()`, `dispose()`, the `GpuDrawBackend` constructor's field
assignment, and the texture-caching branch inside `render()` are not
exercised by any test in this package. All of them need a live
`gpu.GpuContext` (`gpuContext.createTexture`, `.createCommandBuffer`,
`RenderPass`, `.bindUniform`, `.draw`, `.asImage`), and `flutter test` in
this checkout has no such device — `gpu.gpuAvailable()` (used by
`ResidentGeometry.create`, and the same underlying probe `GpuDrawBackend`
would need) is exactly the seam this package already built for that reason
(`gpu_facade.dart`'s `debugSetGpuFactory`/`gpuAvailable`), and
`resident_geometry_test.dart` documents the same gap for the shader-bundle
load path. `buildFrameInfo` and `composeTransforms` are the whole
per-frame CPU surface, and both are pure and fully covered — that split is
exactly what the brief's framing ("`render` needs a device; `buildFrameInfo`
does not") asks for. The `HostBuffer.reset()` placement is justified by
reading `HostBuffer`'s source (cited above) rather than by a test, for the
same device-availability reason.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart` (new)
- `packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart` (new)

Commit: `543a309` — "feat(gpu): the frame path -- one uniform write, one draw call"

## Self-review findings

- Read the diff after formatting; no dead code, no unused imports, no
  overbuilding beyond the brief's specified interface.
- Caught and fixed one overclaim in my own first draft: a comment implied
  `test/invariants/paint_allocation_test.dart` currently measures this
  file's reset behaviour. I checked (`grep -n "gpu\|Gpu"` against that test
  file — no hits) and corrected the comment to say plainly that nothing in
  this package's suite exercises `render` yet, since `GpuDrawBackend` is not
  wired into a widget's `paint()` in this task.
- Verified every `flutter_gpu`/`flutter_scene` API surface the brief's
  sample code uses (`createTexture`, `StorageMode.devicePrivate`,
  `createCommandBuffer`, `RenderTarget.singleColor`, `ColorAttachment`,
  `PrimitiveType.triangle`, `BufferView`, `bindUniform`, `getUniformSlot`,
  `draw`) against the actual vendored source rather than trusting the
  brief's code at face value, per this task's standing note that prior
  tasks' sample code has had real defects. Found none here — the brief's
  `render()` implementation matches the real API exactly.
- Confirmed `git status --porcelain` was clean of everything except the two
  intended files before committing, and specifically checked for and
  reverted an `analysis_options.yaml` rewrite that `flutter pub get`
  produced in `packages/jet_cad/` (a sibling package, not one I touched) —
  `git checkout -- packages/jet_cad/analysis_options.yaml` before running
  the test suite, per the non-negotiable.

## Issues or concerns

- The 80-vs-128 uniform size question is settled from code reading and the
  web backend's documented behaviour, but not from an actual device run —
  I said so plainly above rather than presenting it as fully proven. If
  Task 7's harness run (the first place this actually touches a real GPU)
  disagrees, that is the place to catch it, and the fix is a one-line
  change to the `ByteData(80)` size in `buildFrameInfo`.
- I deviated from the brief's literal Step 1 test fixture (identity
  transform) in favor of a non-degenerate one, per the outer task
  instructions' explicit "beware the degenerate fixture" section. I did not
  deviate from the brief's `render()`/`buildFrameInfo`/`composeTransforms`
  implementation code at all — that part was verified correct against the
  real API and left as given.

---

# Fix report — review round 1 (Needs fixes, one Critical + one effective-Critical + three Minors)

## What I changed

**Critical 1 — `buildFrameInfo` dropped the device-pixel-ratio conversion.**
Per the coordinator's ruling, `buildFrameInfo` keeps its three-argument
shape (`Transform2`, `int widthPx`, `int heightPx`) unchanged — no `dpr`
parameter. Instead:

- Renamed the parameter `collectionToScreen` → `collectionToDevice`
  throughout `gpu_draw_backend.dart`, and rewrote its doc comment to state
  the contract plainly: the transform must already be in device-pixel
  space when it reaches this function, because `sx`/`sy` divide by
  `widthPx`/`heightPx`, which are device pixels. `buildFrameInfo`'s
  internal formula did not change at all — only what its parameter is
  documented (and now named) to mean.
- In `GpuDrawBackend.render`, `dpr` is now folded in at the call site,
  before `buildFrameInfo` is invoked:

  ```dart
  final collectionToDevice = composeTransforms(
    Transform2.scale(dpr, dpr),
    composeTransforms(camera.worldToScreenMatrix, _collectionInverse),
  );
  ```

  `Transform2.scale(double sx, double sy)` exists in
  `packages/jet_cad_2d/lib/src/geometry/transform2.dart:38-39` exactly as
  needed — I checked before using it rather than assuming the shape.

**Critical 2 (filed as adjacent, treated as Critical) — `GeometryCollector`
emitted a logical half-width into a device-pixel shader attribute.** Fixed
in `geometry_collector.dart`'s `_halfWidthFor`, per the ruling to fix it in
the collector (this task's own file) rather than the shader or the
backend:

```dart
double _halfWidthFor(int lineweightHundredths) {
  final logical =
      lineweightHundredths / 100.0 * pixelsPerPaperMm * lineweightScale;
  final device = logical * devicePixelRatio;
  final w = device.isFinite && device > kMinStrokeDevicePixels
      ? device
      : kMinStrokeDevicePixels;
  return w / 2;
}
```

The logical width is now converted to device pixels (`* devicePixelRatio`)
before the floor comparison and the halving, and the floor is
`kMinStrokeDevicePixels` applied directly — not divided back into logical
space, which is what the original version did and which is exactly backwards
for a value the shader consumes in device pixels.

**Minor 2 — the reset was not exception-safe.** Moved
`geometry.uniforms.reset()` from immediately after `commandBuffer.submit()`
to the first line of `render()`, before the `widthPx`/`heightPx` early
returns and before anything that can throw (`bindUniform`, in particular).

I verified this placement is safe with respect to the GPU's read timing by
re-reading `HostBuffer.reset()`'s body in
`/opt/homebrew/Caskroom/flutter/3.27.3/flutter/bin/cache/pkg/flutter_gpu/lib/src/buffer.dart:208-223`:

```dart
void reset() {
  _frameCursor = (_frameCursor + 1) % frameCount;
  _bufferCursor = 0;
  _offsetCursor = 0;
}
```

`reset()` touches only its own three integer cursors — no `DeviceBuffer`
contents, no GPU command submission. Moving the call earlier within the
same `render()` invocation cannot change which physical ring slot this
call's own `emplace()` lands in (that is determined by the cursor value at
the moment `emplace` runs, and `reset()` is the only thing that changes
that value, so calling it once per `render()` call — regardless of exactly
where inside the call — produces the same one-slot-per-frame cadence). It
also cannot affect when the GPU finishes reading a slot from `frameCount`
(4) resets ago, since that timing is governed entirely by the GPU's own
command-buffer submission and completion, neither of which `reset()`
touches. Resetting first is exception-safe (a throw from `bindUniform`
still leaves this frame's ring advance intact) and covers both early
returns for free.

**Minor 3 — `composeTransforms` duplicated `Transform2.multiply`.** Verified
the argument-order match by re-reading `Transform2.multiply`'s doc comment
(`transform2.dart:58-61`: "the argument is applied first, then the
receiver, so `parent.multiply(child)` yields the child's transform
expressed in the parent's space") and by expanding both formulas term by
term — they are identical with `outer` playing `multiply`'s receiver role
and `inner` playing its argument role. Changed the body to delegate:

```dart
Transform2 composeTransforms(Transform2 outer, Transform2 inner) =>
    outer.multiply(inner);
```

**Minor 4 — the test asserted 8 of 20 floats while claiming every term was
load-bearing.** Added the missing 12 assertions to the first `buildFrameInfo`
test (the structural zeros at indices 2, 3, 6, 7, 8, 9, 11, 14, 18, 19; the
`1`s at indices 10 and 15). Index 15 — the homogeneous `w` — gets an explicit
`reason:` calling out why it matters: a typo turning it into `0` zeroes
every `gl_Position.w`, a whole frame of nothing, and nothing else in the
test would have noticed.

## Covering tests

- `packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart` — the existing
  `buildFrameInfo` test, now with all 20 floats asserted and the parameter
  references updated to `collectionToDevice`; plus a new second test, "a dpr
  fold survives composeTransforms + Transform2.scale, not just buildFrameInfo
  alone".
- `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart` — the
  three existing half-width assertions, recomputed by hand for the new
  formula (details below), plus their doc comments rewritten to explain the
  device-pixel arithmetic.

### What the `dpr == 2` test asserts, and why those numbers follow

The test mirrors `render`'s exact recipe rather than testing `buildFrameInfo`
in isolation, because the defect was in the *composition* the caller
performs, not in `buildFrameInfo`'s own arithmetic (which never changed).

Setup: `dpr = 2.0`, a logical viewport of `200 × 100` (so
`widthPx = (200*2).round() = 400`, `heightPx = (100*2).round() = 200` — the
same computation `render` does), and the same six-distinct-term logical
fixture as the `dpr == 1` test, `logicalTransform = Transform2(2, 3, 5, 7,
11, 13)`.

`collectionToDevice = composeTransforms(Transform2.scale(dpr, dpr),
logicalTransform)`. `Transform2.scale(2, 2) = Transform2(2, 0, 0, 2, 0, 0)`.
Expanding `composeTransforms`'s formula (`outer = scale`, `inner =
logicalTransform`) with `outer.b = outer.c = outer.e = outer.f = 0`, every
cross term drops out and each of the inner transform's six terms is simply
multiplied by `dpr`:

```
a = 2*2 + 0*3 = 4      b = 0*2 + 2*3 = 6
c = 2*5 + 0*7 = 10     d = 0*5 + 2*7 = 14
e = 2*11 + 0*13 + 0 = 22   f = 0*11 + 2*13 + 0 = 26
```

So `collectionToDevice = Transform2(4, 6, 10, 14, 22, 26)` — asserted
directly in the test before `buildFrameInfo` is even called, so a broken
fold shows up at the composition step, not just downstream in the NDC
numbers.

`buildFrameInfo(collectionToDevice, 400, 200)`: `sx = 2/400 = 0.005`, `sy =
-2/200 = -0.01`.

```
at(0) = 4 * 0.005 = 0.02        at(1) = 6 * -0.01 = -0.06
at(4) = 10 * 0.005 = 0.05       at(5) = 14 * -0.01 = -0.14
at(12) = 22 * 0.005 - 1 = -0.89 at(13) = 26 * -0.01 + 1 = 0.74
at(16) = 400/2 = 200            at(17) = 200/2 = 100
```

Six of these eight numbers (`at(0), at(1), at(4), at(5), at(12), at(13)`)
are numerically identical to the `dpr == 1` test's values — this is
correct, not a fixture weakness: for a fixed *logical* viewport, the NDC
mapping of a logical point is dpr-invariant by construction (`dpr` appears
in both the transform's terms and in `widthPx`/`heightPx`'s denominator and
cancels: `(dpr * term) / (logical * dpr) = term / logical`). The two
numbers that are *not* invariant, `at(16) = 200` and `at(17) = 100`, are
exactly double the `dpr == 1` test's `100` and `50` — that pair is the
direct fingerprint that `dpr` reached `widthPx`/`heightPx` correctly, and
is what a caller-side regression (dpr silently dropped from the viewport
size calculation, independent of the fold this task fixes) would move.

The discriminating power against *this task's* defect (the dropped fold
into the transform, not into the viewport size) is in the six transform-
derived numbers, demonstrated by contrast in the test's own comment: calling
`buildFrameInfo(logicalTransform, 400, 200)` directly — i.e. skipping
`Transform2.scale(dpr, dpr)` — gives `sx = 0.005` against the *unscaled*
`a = 2`, so `at(0) = 2 * 0.005 = 0.01`, not the `0.02` the test asserts. I
verified this by hand for `at(0)` and noted in the test comment that every
other transform-derived term shifts the same way; I did not add a second,
separate "buggy" assertion block to the test itself, since the point is
covered by the real assertions already going red under the actual reverted
mutation (see Mutation Evidence below) — the contrast in the comment is
there for a reader, not as duplicate test surface.

### Hand-worked half-width values for all three `GeometryCollector` cases

All three fixtures share `pixelsPerPaperMm = 4`, `devicePixelRatio = 2`,
`kMinStrokeDevicePixels = 1.0`. New formula: `logical = lineweightHundredths
/ 100 * pixelsPerPaperMm * lineweightScale`; `device = logical *
devicePixelRatio`; `w = device > 1.0 ? device : 1.0`; `halfWidth = w / 2`.

**Case 1 — `lineweightHundredths = 50, lineweightScale = 1`** (the first
test, "applies the residual...", and implicitly the baseline the
`lineweightScale` test compares against):

```
logical = 50/100 * 4 * 1 = 2.0
device  = 2.0 * 2 = 4.0
4.0 > 1.0, so w = 4.0
halfWidth = 4.0 / 2 = 2.0
```

Old value was `1.0`; new value is `2.0`. `r[5]` in the first test updated
accordingly.

**Case 2 — hairline, `lineweightHundredths = 0`:**

```
logical = 0/100 * 4 * 1 = 0.0
device  = 0.0 * 2 = 0.0
0.0 is not > 1.0, so the clamp takes over: w = kMinStrokeDevicePixels = 1.0
halfWidth = 1.0 / 2 = 0.5
```

Old value was `0.25`; new value is `0.5`. Still clearly discriminates a
"clamp dropped" mutation, which would instead compute `w = device = 0.0`
and `halfWidth = 0.0`.

**Case 3 — `lineweightHundredths = 50, lineweightScale = 2`:**

```
logical = 50/100 * 4 * 2 = 4.0
device  = 4.0 * 2 = 8.0
8.0 > 1.0, so w = 8.0
halfWidth = 8.0 / 2 = 4.0
```

Old value was `2.0`; new value is `4.0`. Discrimination against Case 1
(the default `lineweightScale = 1`) is preserved: `2.0` (Case 1) versus
`4.0` (Case 3) are still distinct, so a dropped `lineweightScale` multiply
would still be caught — it would leave this test reading `2.0` instead of
`4.0`. None of the three fixtures needed weakening; all three still
discriminate the same mutations they did before, against the corrected
numbers.

## Exact commands and their real output

Mutation re-check after the rename (`buildFrameInfo`'s `collectionToDevice`
parameter), same named mutation as round 1 — negate the y row by replacing
`sy` with `2.0 / heightPx` at the `f(5, ...)` call site. Backed up first with
`cp`, not `git checkout`:

```
$ flutter test test/gpu/frame_info_test.dart --reporter expanded
...
00:00 +0: buildFrameInfo maps a device-space transform to NDC with y flipped, every float load-bearing
00:00 +0 -1: buildFrameInfo maps a device-space transform to NDC with y flipped, every float load-bearing [E]
  Expected: a numeric value within <0.000001> of <-0.14>
    Actual: <0.14000000059604645>
     Which:  differs by <0.28000000059604646>
  d * sy -- the y-scale row; negating sy here is the named mutation for this task
  ...
00:00 +0 -1: buildFrameInfo a dpr fold survives composeTransforms + Transform2.scale, not just buildFrameInfo alone
00:00 +0 -2: buildFrameInfo a dpr fold survives composeTransforms + Transform2.scale, not just buildFrameInfo alone [E]
  Expected: a numeric value within <0.000001> of <-0.14>
    Actual: <0.14000000059604645>
     Which:  differs by <0.28000000059604646>
  d * sy, dpr folded in
  ...
00:00 +1 -2: Some tests failed.
```

Both `buildFrameInfo` tests go red on the same mutation, independently
confirming the new dpr-fold test also exercises the y-row term. Reverted
with `cp` from a pre-mutation backup, confirmed byte-identical with `diff`,
re-ran:

```
$ flutter test test/gpu/frame_info_test.dart --reporter expanded
...
00:00 +0: buildFrameInfo maps a device-space transform to NDC with y flipped, every float load-bearing
00:00 +1: buildFrameInfo a dpr fold survives composeTransforms + Transform2.scale, not just buildFrameInfo alone
00:00 +2: composeTransforms outer ∘ inner, every term of both operands load-bearing
00:00 +3: All tests passed!
```

No `git checkout` was used at any point during this round's mutation or its
reversion, or at any point while fixing the review findings — only `cp`
backups and restores, and one `git checkout -- packages/jet_cad/analysis_options.yaml`
to revert a file `flutter pub get` rewrote (a sibling package, not one this
task touches), per the standing non-negotiable.

Full gate, run as specified:

```
$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
...
00:08 +429 ~1: .../test/tile_measurement_seam_test.dart: the rest bake fires: the unflagged arm slices every visible tile
00:08 +430 ~1: .../test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:08 +431 ~1: .../test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:08 +432 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...                                 
No issues found! (ran in 1.1s)
Formatted 83 files (0 changed) in 0.14 seconds.
```

Exit code of the full chained command: `0`. 432 tests passed (up from 431
in round 1 — the new dpr-fold test), the same 1 pre-existing skip
(`~1`, unrelated to this task), 0 failures. `flutter analyze`: no issues.
`dart format --set-exit-if-changed`: no changes needed.

`git status --porcelain` immediately before committing showed only the four
files this round touched:

```
 M packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart
 M packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart
 M packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart
 M packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
```

No `analysis_options.yaml` rewrite was outstanding at that point (it was
reverted earlier in this round, during the test/analyze iteration, and
`flutter pub get` did not touch it again on the final gate run).

## Files changed (this round)

- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart`
- `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart`
- `packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart`
- `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart`

Commit: `1a21f0a` — "fix(gpu): fold dpr into the frame matrix, and stroke
half-width into device pixels"

## Issues or concerns

- Both defects the review found were real, and both were mine to catch
  the first time — I verified the brief's sample `render()`/`buildFrameInfo`
  code against the live `flutter_gpu` API in round 1 but did not separately
  re-derive the unit consistency of the `dpr` handling end to end, and I
  did not read `geometry_collector.dart` closely enough during round 1
  (it was Task 3's file, out of this task's stated scope, but the review
  correctly points out I was in a position to notice the mismatch against
  the shader's documented `// device pixels` contract while wiring `render`
  against it). Noted for calibration, not as a excuse.
- The `dpr == 2` test's discriminating power is specifically against the
  fold being dropped or mis-composed in `render`'s exact recipe
  (`composeTransforms(Transform2.scale(dpr, dpr), ...)`); it cannot, by
  itself, prove `render()`'s real call site still matches that recipe,
  since `render()` remains untestable without a GPU in this checkout (same
  limitation noted in round 1's report). I re-read `render()`'s current
  source after making the fix to confirm it uses the identical composition
  the test now pins.
