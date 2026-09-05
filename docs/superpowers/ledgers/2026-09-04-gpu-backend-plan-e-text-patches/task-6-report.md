# Task 6 report: the resident geometry carries patches, and the backend paints them

Commit: `87529e8` — "feat(gpu): patch targets and sub-buffers on the device, and a paint
that composites them"

## What was implemented

### `lib/src/gpu/resident_geometry.dart`

- New `ResidentPatch` class: `textIndex`, `instanceCount`, a `DeviceBuffer`
  sub-buffer (`@internal instances`), a `Texture` target (`@internal target`),
  `targetWidth`, `targetHeight`. Matches the brief's code verbatim.
- `ResidentGeometry.create`/`_upload` gained `texts` (`List<ResidentTextRecord>`,
  default `const []`), `patches` (`List<TextPatch>`, default `const []`),
  `devicePixelRatio` (default `1.0`), `maxPatchWidth`/`maxPatchHeight` (default
  `4096` each). `_upload` uploads one sub-buffer + one target per `TextPatch`,
  sized by `patchTargetSizeFor`, with `enableShaderReadUsage: true` passed
  explicitly (the brief's reasoning comment about the web shim's `asImage()`
  check is carried verbatim).
- `ResidentGeometry.texts` and `.patches` are new fields; the private
  constructor grew two more positional params.
- `byteLengthFor(int instances, {int patchInstances = 0})` — every existing
  single-argument call site still compiles (verified: whole-suite green).
- `byteLength` getter now folds in `patches.fold(0, (sum, p) => sum +
  p.instanceCount)`; new `patchTargetBytes` getter sums `targetWidth *
  targetHeight * 4` across patches.
- Doc comments updated: the class doc now states patches are part of the
  claim; the `@internal, all five` doc for the five GPU-typed getters was
  corrected to say `corners`/`pipeline`/`vertexShader` now have two call
  sites (main pass + per-patch), `uniforms` those two plus `reset()`, and
  `instances` still exactly one (the patch loop reads `ResidentPatch.instances`
  instead, never `geometry.instances`) — checked against the actual call
  sites in `gpu_draw_backend.dart` with `grep -n`, not asserted from memory.

### `lib/src/gpu/gpu_draw_backend.dart`

- Constructor gained optional `measurer` (`FlutterTextMeasurer?`) and
  `textStyleOf` (`TextStyleRecord Function(Handle)?`); `_compositor` is a
  `TextCompositor` only when both are supplied, else `null`. The existing
  two-argument call site (`GpuDrawBackend(geometry, collectionCamera)`)
  still compiles.
- New fields: `_compositor`, `_patchImages` (`List<PatchImage>`),
  `_pendingRegions` (`List<(ResidentPatch, PatchRegion)>`), `_imagePaint`
  (`Paint()..filterQuality = FilterQuality.none`, allocated once),
  `_collectionToLogical` (`Transform2`, set once per `render`, read by
  `paint`), `patchesRendered`/`patchesClipped`/`patchesOffscreen` (`int`,
  reset each `render`).
- `render`: after the main pass's `pass.draw(...)` and before
  `commandBuffer.submit()`, one more render pass per `geometry.patches`
  entry, on the same command buffer — bind order matches the brief exactly:
  pipeline, primitive type, cull mode, color blend, viewport, scissor,
  corner buffer (slot 0), patch's own instance buffer (slot 1), `FrameInfo`
  uniform (built from `composeTransforms(Transform2.translation(-region.x,
  -region.y), collectionToDevice)`), draw. Off-screen labels increment
  `patchesOffscreen` and `continue`; a region that reached the target's
  width or height increments `patchesClipped` (drawn anyway, per the
  brief). `commandBuffer.submit(); frames++;` runs once, then the
  `_pendingRegions` loop builds `_patchImages` via `patch.target.asImage()`
  — strictly after `submit()`, per the brief's web-snapshot-timing
  reasoning, carried verbatim in the code comment. `_collectionToLogical`
  is assigned once, right where the local `collectionToLogical` is first
  computed.
- `paint`: `render`, then — if `_compositor` is null — draws only the main
  image with `_imagePaint` (no text, no patches); otherwise calls
  `compositor.paint(...)` with `collectionToLogical: _collectionToLogical`
  (the stored field, not recomputed — the brief's explicit ask).
- Class doc and `render`'s own inline doc amended: "the matrix is the only
  per-frame CPU work" is now "...once per pass", explaining the added
  `FrameInfo` + draw call per patch is still O(1) per flush (per label, not
  per entity inside it).

### One deviation from the brief, documented in place

`patchPass.setScissor(...)` — called exactly as the brief's Step 3 code
specifies — trips `flutter analyze` as `undefined_method`. Investigated
before working around it: `gpu_facade.dart` re-exports
`flutter_scene/src/gpu/gpu.dart`'s conditional export, which has three
concrete `RenderPass` shapes — native (verbatim `package:flutter_gpu`, which
does declare `setScissor` at `flutter_gpu/lib/src/render_pass.dart:607`,
checked against the exact Flutter SDK this workspace builds with), the web
shim (`flutter_scene/lib/src/gpu/web/render_pass.dart`, which declares a
`Scissor` data class but never gives `RenderPass` a `setScissor` method at
all), and the analyzer's own generic stand-in
(`flutter_scene/lib/src/gpu/stub/shim_stubs.dart`, whose own doc comment
calls itself "the analyzer fallback is a throwing stub" — `flutter analyze`
resolves to this one, confirmed empirically: the stub declares `setViewport`
(no diagnostic on that sibling call) but not `setScissor`). Checked `flutter
pub outdated` — `flutter_scene` is not listed as upgradable, `0.23.0` (the
pinned version) is the newest published one, so this is a real gap in the
dependency, not a version to bump past.

Fix: `// ignore: undefined_method` directly above the call, with an in-place
comment carrying the investigation above (file paths, line numbers, the
empirical check) so a future reader does not have to re-derive it, and an
explicit note that a future web target would need this revisited since the
web backend itself lacks the method — this is not exercised by anything
today. Runtime behaviour is unchanged from the brief: the harness (Task 7,
macOS Metal) resolves the native shape, where `setScissor` is real.

## TDD evidence

RED (before implementation, both new tests present, old signatures):

```
test/gpu/resident_geometry_test.dart:33:49: Error: No named parameter with the name 'patchInstances'.
    expect(ResidentGeometry.byteLengthFor(1000, patchInstances: 37),
                                                ^^^^^^^^^^^^^^
lib/src/gpu/resident_geometry.dart:213:14: Context: Found this candidate, but the arguments don't match.
  static int byteLengthFor(int instances) => instances * kFloatsPerInstance * 4;
test/gpu/resident_geometry_test.dart:41:9: Error: No named parameter with the name 'texts'.
        texts: const [],
        ^^^^^
lib/src/gpu/resident_geometry.dart:235:36: Context: Found this candidate, but the arguments don't match.
  static Future<ResidentGeometry?> create(
```
(`resident_geometry_test.dart` failed to load — compile error — 1 file, 0
tests ran from it.)

`frame_info_test.dart`'s new patch-`FrameInfo` test needed no implementation
change (`buildFrameInfo` was already correct) — it passed the moment it was
added, alongside the file's other 6 tests, 7/7 green from the start; it is
included here as evidence the fixture itself is correct, not as a RED→GREEN
pair.

GREEN (after implementation), both files together:

```
$ flutter test test/gpu/resident_geometry_test.dart test/gpu/frame_info_test.dart
...
00:00 +23: All tests passed!
```

24 tests total (17 pre-existing `resident_geometry_test.dart` + 2 new + 7
`frame_info_test.dart`, one of which is new).

## Gate commands and output

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +617 ~1: All tests passed!
```
Exit code: 0. (`~1` is one pre-existing skipped test, unrelated to this task
— present before this change too.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.17s
```
Exit code: 0. (First run after edits printed `Formatted 99 files (4 changed)`
— exit 1 — for the four touched files; `dart format .` was run to apply the
formatter's own reflow (no content changes beyond whitespace/wrapping), then
the exit-if-changed check re-run clean.)

```
$ git status --short
 M packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart
 M packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart
 M packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart
 M packages/jet_cad_2d_flutter/test/gpu/resident_geometry_test.dart
```
No `analysis_options.yaml` touched; nothing else staged.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart`
- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart`
- `packages/jet_cad_2d_flutter/test/gpu/resident_geometry_test.dart`
- `packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart`

## Self-review

Read `render` top to bottom once more before committing (twice total: once
while writing, once as the final check named in the task instructions):

- Bind order in the patch pass matches the main pass's and the brief's:
  pipeline → primitive type → cull mode → color blend → viewport → scissor →
  corner buffer (slot 0) → instance buffer (slot 1) → uniform → draw.
- The translation's sign: `Transform2.translation(-region.x, -region.y)` is
  the OUTER transform composed with `collectionToDevice` as inner —
  `composeTransforms(outer, inner) == outer ∘ inner`
  (`composeTransforms`'s own doc), so a collection point is first mapped to
  device space, then shifted by `-region.x, -region.y` — landing the
  region's own device-pixel origin at the patch target's `(0, 0)`. Cross-
  checked against the new `frame_info_test.dart` case, which asserts exactly
  this composition maps device `(120, 240)` (the region's origin) to NDC
  `(-1, 1)` — green.
- `asImage()` only after `submit()`: confirmed the code calls
  `commandBuffer.submit(); frames++;` before the `_pendingRegions` loop that
  calls `patch.target.asImage()`, and before the final `return
  target.asImage()` — both after submit, as the brief requires and its
  comment explains.
- `_patchImages.clear()` sits at the top of the patch section (before the
  loop that populates `_pendingRegions`), and `_pendingRegions.clear()` runs
  after it is drained into `_patchImages` — both per-frame, matching the
  brief's "cleared per frame" instruction for `_pendingRegions` and "cleared
  at the top of the patch loop" for `_patchImages`.
- The early return (`widthPx <= 0 || heightPx <= 0 ||
  geometry.instanceCount == 0`) skips the patch loop too when it fires;
  verified this is consistent, since `classifyTextPatches` never produces a
  `TextPatch` when `instanceCount == 0` (its per-label scan range is
  `[t.instanceIndex, instanceCount)`, empty when `instanceCount == 0`), so
  no patch is silently dropped by the early return.
- `PatchImage.dst` is `region / dpr` (logical), `src` is the device region
  at the target's own origin (`Rect.fromLTWH(0, 0, region.width,
  region.height)`) — matches the brief's Task 4 carry-forward note exactly.
- `patchRegionFor` and `labelBoundsLogical` are each called once per entry
  of `geometry.patches` (never per `geometry.texts`), so their per-call
  `Float64List(4)` scratch stays the documented per-patch exception to
  invariant 1, not a per-entity one.
- Doc-comment honesty pass: updated the `@internal, all five` comment in
  `resident_geometry.dart` (line-number claim was going to go stale the
  moment the patch loop added second call sites for `corners`/`pipeline`/
  `vertexShader`/`uniforms`) and the class-level "matrix is the only
  per-frame CPU work" claim in `gpu_draw_backend.dart` (now says "once per
  pass" and explains the O(1)-per-flush framing for the added per-patch
  work). Re-read both after editing to confirm they match the code as
  committed.

## Concerns

- The `setScissor` gap (see above) is a real limitation in the pinned
  `flutter_scene: ^0.23.0` dependency, not something introduced by this
  task. It is confined to one documented `// ignore:` and does not change
  runtime behaviour on the harness's actual target (native, macOS Metal).
  Flagging it because: (1) it is the one place this task's code does not
  literally match the brief's snippet without an added suppression comment,
  and (2) a future web target for this backend would need `setScissor`
  addressed for real (there is currently no `setScissor` on that backend at
  all, in this pinned dependency version) — worth a note for whoever owns
  web support later, or for a future `flutter_scene` upgrade.
- `render`/`paint`'s patch path is unexercised by anything that runs today
  (no GPU in `flutter test`) — this is expected and named in the task brief
  itself; Task 7's harness run is where it first executes. Nothing in this
  report claims otherwise.

## Fix round 1 (Ruling R6-1)

Commit: `64a2e68` — "fix(gpu): the patch pass is bounded by its viewport, not
a scissor the web shim lacks"

**What changed.** Removed `patchPass.setScissor(...)` and its `// ignore:
undefined_method` from the patch loop in `gpu_draw_backend.dart`'s `render`.
The ruling's reasoning: the pass's viewport is already `(0, 0, region.width,
region.height)`, and `FrameInfo` (built from `toPatch`) maps exactly that
region onto NDC `[-1, 1]` on both axes, so every fragment outside the region
is outside the clip volume and is never rasterised in the first place — the
scissor call was redundant with the viewport, and suppressing an analyzer
error for a method the web shim (`flutter_scene/lib/src/gpu/web/render_pass.dart`)
never defines at all would have been a `NoSuchMethodError` waiting for
whichever plan first targets web.

Rewrote the Ruling E8 comment at that site: it now says the viewport alone
bounds the draw (clipping happens at the primitive stage against the NDC
volume `FrameInfo` produces, upstream of any per-fragment scissor test), and
explains the scissor's removal by name — the web backend's `RenderPass`
declares a `Scissor` data class but never gives `RenderPass` a `setScissor`
method, so a call there would fail outright rather than merely fail static
analysis; the analyzer's own generic stand-in lacks the same method for the
same documented reason ("the analyzer fallback is a throwing stub").
`grep -rn "Scissor\|scissor"` across the two touched files after the edit
confirms every remaining mention lives inside this one explanatory comment —
no other doc comment in the diff (including `ResidentPatch`'s and `render`'s
class-level docs) ever mentioned scissor, so nothing else needed updating.

**Covering tests.**

```
$ flutter test test/gpu/resident_geometry_test.dart test/gpu/frame_info_test.dart
...
00:00 +23: All tests passed!
```
24 tests, unchanged from before the fix (this change touches only
`gpu_draw_backend.dart`, which nothing in these two files can exercise
without a GPU — the fix is a removal plus a comment rewrite, verified by
re-reading the diff, not by a test that newly passes).

**Full package gate.**

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:08 +617 ~1: All tests passed!
```
Exit code: 0.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```
Exit code: 0. No `// ignore:` directive anywhere in `lib/src/gpu/` --
confirmed with `grep -rn "ignore: undefined_method" lib/src/gpu/`, exit
code 1 (no match).

```
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.15 seconds.
```
Exit code: 0.

```
$ git status --short
 M packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart
```
No `analysis_options.yaml` touched.

## Fix round 2 (five findings, one parked as R6-2)

Commit: `55ef7af` — "fix(gpu): a frame that draws nothing still resets its
patch state and transform"

**What changed, per finding.**

1. **[Important] Reset hoisted above the early return.** `_collectionToLogical`,
   `_patchImages.clear()`, `_pendingRegions.clear()`, and
   `patchesRendered`/`patchesClipped`/`patchesOffscreen = 0` now run
   unconditionally at the top of `render`, beside `geometry.uniforms.reset()`,
   before `if (widthPx <= 0 || heightPx <= 0 || geometry.instanceCount == 0)
   return null;`. `_collectionToLogical` does not depend on
   `widthPx`/`heightPx`, so nothing blocked computing it there. The mid-function
   duplicate (`final collectionToLogical = composeTransforms(...); //
   _collectionToLogical = collectionToLogical;`) was removed; the later
   `collectionToDevice` composition and the patch loop's `labelBoundsLogical`
   call now read the `_collectionToLogical` field directly instead of a local
   variable that no longer exists. The reset-first comment above
   `geometry.uniforms.reset()` grew a new paragraph extending its own
   reasoning ("a call to `render` that draws nothing is still 'this frame'")
   to these fields by name, spelling out the concrete failure this fixes: an
   all-text, zero-instance `ResidentGeometry` (or a document rebuilt down to
   zero instances after a frame that had patches) would otherwise return
   `null` on every subsequent frame, freezing `_collectionToLogical` at its
   `Transform2.identity()` field initialiser and leaving `_patchImages`
   holding a previous, possibly mismatched document's patches for `paint` to
   composite over `main: null`.
2. **[Minor] `_pendingRegions`'s stale-on-throw window closed.** The
   bottom-of-`render` `_pendingRegions.clear()` (after the drain loop that
   builds `_patchImages`) was removed; the list is now cleared only by the
   top-of-`render` reset from finding 1, unconditionally, on every call. A
   comment at the removal site explains why: a throw between the loop's
   `_pendingRegions.add(...)` (inside the patch loop) and the drain (after
   `submit()`) used to leave stale `(ResidentPatch, PatchRegion)` pairs for
   the next frame's compositor merge to trip over; the single reset point
   now bounds that staleness to at most one `render` call, matching the
   `geometry.uniforms` precedent's own reasoning.
3. **[Minor] Class doc corrected.** "The matrix is the only per-frame CPU
   work, once per pass" (false: `patchRegionFor` and `labelBoundsLogical`
   each allocate their own `Float64List(4)` scratch per patch, plus a
   `PatchRegion`, a `(ResidentPatch, PatchRegion)` record, a `PatchImage` and
   three `Rect`s) is now "Per-frame CPU work is bounded by patches, never by
   entities", naming every one of those allocations explicitly and stating
   each is one per PATCH, never one per instance inside it — matching
   invariant 1's stated exception.
4. **[Minor] Framebuffer-origin assumption recorded.** A new paragraph sits
   immediately before `patchPass.setViewport(...)` in the patch loop: it
   names the assumption load-bearing exactly when `region` is smaller than
   `patch.target` (anchoring at `(0, 0)` and reading the same corner back as
   `src = Rect.fromLTWH(0, 0, region.width, region.height)` after `submit`
   are the same physical corner only on a top-left-origin framebuffer),
   states it is confirmed for Impeller/Metal (Task 9's device run placed
   geometry correctly, which a flipped origin would not have) and unverified
   for the WebGL shim, which nothing in this codebase has run against yet —
   matching the style of the file's neighbouring web-correctness comments
   (e.g. the `asImage()`-ordering paragraph just below the patch loop).
5. **[Minor] `dispose()`'s doc now names `Texture`.** `resident_geometry.dart`'s
   `dispose()` doc comment listed `DeviceBuffer`, `RenderPipeline`, `Shader`,
   `HostBuffer` as the types with no native `dispose` method; it now also
   names `Texture` (the `P` patch targets `ResidentGeometry` owns since Task
   6) and says explicitly that this was checked against `Texture`
   specifically (`flutter_gpu/lib/src/texture.dart` and
   `flutter_scene/lib/src/gpu/web/texture.dart`, both `grep`ped for
   `dispose` with no match) rather than assumed from the other four types.

**Parked (Ruling R6-2, not touched):** disposing the `1 + P` `ui.Image`
handles built per frame. Left exactly as committed in round 1 — no code or
comment change.

**Covering tests.**

```
$ flutter test test/gpu/resident_geometry_test.dart test/gpu/frame_info_test.dart
...
00:00 +23: All tests passed!
```
24 tests (23 shown plus the loading line), unchanged in count from round 1 —
this round touches only `gpu_draw_backend.dart` and a doc comment in
`resident_geometry.dart`, neither reachable from these two files' fixtures
without a GPU; verified by re-reading the diff for stray references to the
removed local variable (`grep -n "collectionToLogical\b"
gpu_draw_backend.dart` — every remaining hit is the `_collectionToLogical`
field, none a bare local).

**Full package gate.**

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:08 +617 ~1: All tests passed!
```
Exit code: 0.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.15 seconds.
```
Exit code: 0.

```
$ git status --short
 M packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart
 M packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart
```
No `analysis_options.yaml` touched.

## Fix round 3 (Ruling R6-3, a device-run finding)

Commit: `4af35bf` — "fix(gpu): one command buffer per render pass -- Metal
refuses a second encoder on one buffer"

**The finding.** Task 9's first harness run with patches crashed on the
first arm-C frame, right after `GSPIKE collect+upload: ... textOps=165
patches=87 ...`, with:

```
-[AGXG15XFamilyCommandBuffer renderCommandEncoderWithDescriptor:]:967:
failed assertion 'A command encoder is already encoding to this command
buffer'
```

**Cause.** `render` created every patch pass with
`commandBuffer.createRenderPass(...)` on the SAME command buffer as the
main pass. `flutter_gpu`'s `RenderPass` opens its Metal encoder at
*construction* (`flutter_gpu/lib/src/command_buffer.dart:130`'s
`createRenderPass`), and a `CommandBuffer` accepts exactly one `submit()`
(`flutter_gpu/lib/src/command_buffer.dart:240-248` throws `StateError` on a
second call — checked directly against the Flutter SDK this package builds
with) — so a second `createRenderPass` on one buffer, which the patch loop
did once per patch, opened a second Metal encoder before the first had
finished, which Metal refuses outright. The control run (`patches=0`)
completed normally, isolating the crash to the patch passes specifically —
consistent with the code: the control run's patch loop never executes, so
`commandBuffer.createRenderPass` is only ever called once.

**What changed, per the ruling.** In `gpu_draw_backend.dart`'s `render`:

1. The main pass keeps its own command buffer, and it now calls
   `commandBuffer.submit()` immediately after its `draw`, before any patch
   pass is created (previously `submit()` ran once, after the whole patch
   loop). A new comment at that `submit()` call quotes the Metal assertion
   verbatim, states the cause (encoder-at-construction plus one-submit-only,
   both cited against the exact SDK source), notes the control run isolated
   it, and records that the web shim's `CommandBuffer` is "a thin
   convenience wrapper... `submit` is a no-op and `createRenderPass` returns
   a pass that drives the GL context in place" (quoted from
   `flutter_scene/lib/src/gpu/web/command_buffer.dart`'s own doc comment),
   so per-pass buffers cost nothing extra there.
2. Each patch pass now gets a FRESH `gpu.gpuContext.createCommandBuffer()`
   (`patchCommandBuffer`), used for that patch's `createRenderPass`,
   bindings, uniform and `draw`, then `patchCommandBuffer.submit()` right
   after the `draw` — one buffer per patch, submitted in turn, in
   `geometry.patches` order (unchanged iteration order).
3. Every `asImage()` call — the drain loop's `patch.target.asImage()` and
   the method's own `target.asImage()` — stays after the LAST submit, which
   by construction is now the last patch's `patchCommandBuffer.submit()` (or
   the main pass's, if there are no patches this frame); their comment was
   updated to say "after the LAST `submit()`" and to note there are now
   `1 + P` submits, not one.
4. `frames++` still runs exactly once per `render` call, moved to sit after
   the patch loop (previously it ran right after the single `submit()`;
   there is no longer a single submit to sit next to, so it now marks "one
   `render` call happened" directly, which is what its own doc comment
   already claims: "Frames submitted... a timing figure taken from it is the
   cost of an empty screen").

The uniform ring (`geometry.uniforms`, reset once at the top of `render`)
and the three counters are unchanged from round 2 — still one `emplace` per
pass, still reset once, unconditionally, before the early returns.

**Doc comments amended.** The class doc's patch-pass paragraph and the
patch-loop's own leading comment were reworded from "on the SAME command
buffer -- still one submit per frame" to "each on its OWN command buffer,
submitted right after its own draw -- still O(1) per flush, one pair per
patch, never per entity". The round-2 fix's own comment (about
`_pendingRegions`'s stale-on-throw window) referenced `commandBuffer.submit`
as one of the operations that could throw between an `.add` and the drain;
that parenthetical was updated to name what can actually throw there now (a
LATER patch's own `patchCommandBuffer.submit()`, or either `asImage()` call)
rather than the single submit that no longer exists at that point in the
method. `grep -n "one command buffer\|one submit\|SAME command buffer"` on
the file after the edit shows only the new comment's own "one command buffer
per pass" phrasing — no stale claim of a single per-frame buffer remains.

**Did not run the harness.** Per the ruling, Task 9's agent re-runs the
device harness; this task verified only what `flutter test`/`flutter
analyze`/`dart format` can (the GPU path itself is still unreachable from
`flutter test`, as every prior round of this task noted).

**Covering tests.**

```
$ flutter test test/gpu/resident_geometry_test.dart test/gpu/frame_info_test.dart
...
00:00 +23: All tests passed!
```
24 tests (23 individual results plus the loading line), unchanged in count —
this round restructures command-buffer usage only, inside code no test in
these two files can reach without a GPU.

**Full package gate.**

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +617 ~1: All tests passed!
```
Exit code: 0.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.4s)
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.15 seconds.
```
Exit code: 0.

```
$ git status --short
 M packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart
```
No `analysis_options.yaml` touched.
