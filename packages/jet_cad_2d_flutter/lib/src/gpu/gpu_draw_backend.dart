import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../flutter_text_measurer.dart';
import '../viewport_transform.dart';
import 'gpu_facade.dart' as gpu;
import 'resident_geometry.dart';
import 'text_compositor.dart';
import 'text_patches.dart';

/// The uniform block: `mat4 mvp`, `vec2 half_viewport`, then `float
/// dash_scale`, std140, 80 bytes.
///
/// **80, not the 128 `impellerc` reflects.** Plain std140 arithmetic gives 80:
/// `mat4` occupies 64 bytes (four 16-byte-aligned `vec4` columns), `vec2`
/// needs only 8-byte alignment so it sits at offset 64..72 with no gap, a
/// trailing `float` needs only 4-byte alignment so it sits at 72..76 with no
/// gap either, and the struct's own alignment (16, from `mat4`) rounds 76 up
/// to 80 -- the same 80 the block was before this member existed, because
/// that trailing 4 bytes (float index 19) was always pure alignment padding,
/// never a second scalar. The 128
/// `impellerc` reports (`resident_geometry.dart`'s doc comment) is real, but
/// it is *reflected struct size*, not *bytes the runtime requires bound* --
/// neither `RenderPass.bindUniform` nor `HostBuffer.emplace` on the native
/// side ever reads `UniformSlot.sizeInBytes`
/// (`flutter_gpu/lib/src/render_pass.dart`'s `bindUniform` forwards the
/// `BufferView`'s own `offsetInBytes`/`lengthInBytes` to the native call
/// untouched; `buffer.dart`'s `HostBuffer.emplace` sizes the view to exactly
/// the `ByteData` it was given). The web backend confirms the same
/// assumption explicitly: `flutter_scene`'s `RenderPass.bindUniform`
/// (`gpu/web/render_pass.dart`) widens the bound range to the driver-reported
/// block size only when the emplaced length is *smaller* than that -- "the
/// emplaced length alone can be smaller than the driver's padded size" is
/// this exact situation, anticipated and handled, not a bug. The spike
/// (`git show 8c82208:apps/dev_harness_2d/lib/gpu_arm.dart:414` -- that file
/// was deleted in Task 9, before which it lived at this path) already
/// hand-packed this same 80-byte layout and ran correctly on macOS Metal.
///
/// **Task 9's device run confirmed the native path directly, on more than
/// "no crash".** `mvp` occupies bytes 0-63 of this block and `half_viewport`
/// bytes 64-71 -- the tail the shader divides by to expand each quad's
/// corners into a stroke -- so a block whose tail was not read correctly
/// would place geometry correctly but draw every stroke at the wrong width,
/// or vice versa for a garbled `mvp`. Task 9's picture was both correctly
/// placed and correctly weighted, which is evidence both halves of the
/// block reached the shader, not only that `bindUniform` accepted the bind
/// (see `docs/superpowers/ledgers/2026-08-29-gpu-backend-plan-a-seam-and-strokes/
/// task-9-report.md`).
///
/// [collectionToDevice] takes a point in the buffer's space — the collection
/// camera's screen space — all the way to the live camera's **device-pixel**
/// screen space. This function finishes the job from there: device pixels to
/// normalized device coordinates, y flipped.
///
/// **The parameter is device space, not logical space, and the name says
/// so.** `widthPx`/`heightPx` are device pixels (the caller derives them as
/// `(viewport.width * dpr).round()`), so `sx`/`sy` below divide by a
/// device-pixel denominator. A transform still in logical pixels — which is
/// what `ViewportTransform.worldToScreenMatrix` and `GeometryCollector`'s
/// buffer both are, per `viewport_transform.dart`'s "screen coordinates are
/// logical pixels" — divided by a device-pixel denominator silently drops
/// exactly the `devicePixelRatio` factor: correct at `dpr == 1` and wrong by
/// that factor everywhere else, which is why a `dpr == 1` fixture cannot
/// tell the two apart. This function does not take `dpr` as a parameter and
/// does not convert units itself — the caller (`GpuDrawBackend.render`)
/// folds `dpr` into the transform *before* calling this function, by
/// composing it with `Transform2.scale(dpr, dpr)`, so that what arrives here
/// is already commensurate with `widthPx`/`heightPx`.
///
/// **[dashScale] is deliberately not device space.** It is live **logical**
/// pixels per collection unit -- the factor the shader will compare a dash
/// period against `kDashCollapsePx` to decide whether the pattern has
/// collapsed and should draw solid. `kDashCollapsePx` is compared against a
/// period measured in the painter's screen-space points, which are logical
/// pixels (`viewport_transform.dart`: "screen coordinates are logical
/// pixels"), and against `period * pixelScale` in `dashArc`, where
/// `pixelScale` is `chain.scaleMagnitude`, also logical. A device-space
/// ratio would collapse patterns at `dpr` times the wrong zoom -- correct at
/// `dpr == 1`, wrong on every retina display, which is the shape of a defect
/// a previous plan's device run found in the half-width. See
/// [dashScaleFor] for the composition this value comes from.
///
/// **Required, not defaulted.** A defaulted `dashScale` is a silent 0, and a
/// 0 collapses every dash pattern in the drawing to solid -- a
/// whole-drawing defect hiding behind a default argument.
///
/// [dashScale] is written at float index 18 (byte 72), the block's only
/// trailing scalar; float index 19 (byte 76) stays zero -- it is alignment
/// padding, not a second member (see this function's doc comment above).
ByteData buildFrameInfo(
    Transform2 collectionToDevice, int widthPx, int heightPx,
    {required double dashScale}) {
  final sx = 2.0 / widthPx;
  final sy = -2.0 / heightPx;
  final data = ByteData(80);
  void f(int i, double v) => data.setFloat32(i * 4, v, Endian.host);
  f(0, collectionToDevice.a * sx);
  f(1, collectionToDevice.b * sy);
  f(2, 0);
  f(3, 0);
  f(4, collectionToDevice.c * sx);
  f(5, collectionToDevice.d * sy);
  f(6, 0);
  f(7, 0);
  f(8, 0);
  f(9, 0);
  f(10, 1);
  f(11, 0);
  f(12, collectionToDevice.e * sx - 1);
  f(13, collectionToDevice.f * sy + 1);
  f(14, 0);
  f(15, 1);
  f(16, widthPx / 2);
  f(17, heightPx / 2);
  f(18, dashScale);
  f(19, 0);
  return data;
}

/// `outer ∘ inner`.
///
/// Delegates to [Transform2.multiply] rather than repeating its six-term
/// formula: `multiply`'s own doc comment states "the argument is applied
/// first, then the receiver, so `parent.multiply(child)` yields the child's
/// transform expressed in the parent's space" — i.e. `parent.multiply(child)
/// == parent ∘ child`, which is exactly `composeTransforms(outer,
/// inner)`'s contract with `outer` as the receiver and `inner` as the
/// argument. Verified by expansion, not assumed: both formulas multiply the
/// receiver's `a, c` row against the argument's `a, b` column the same way,
/// term for term. A second hand-written copy of the same formula in this
/// file would be one more place for the two to silently diverge.
Transform2 composeTransforms(Transform2 outer, Transform2 inner) =>
    outer.multiply(inner);

/// Live logical pixels per collection unit -- the factor the shader compares
/// a dash period against `kDashCollapsePx`.
///
/// **Logical, deliberately.** See [buildFrameInfo]'s doc comment on
/// `dashScale` for why: `kDashCollapsePx` is compared against periods
/// measured in the painter's logical screen-space points, and a device-space
/// ratio would collapse patterns at `dpr` times the wrong zoom.
///
/// **`render` calls this directly -- it is the shipping implementation, not
/// a parallel one.** `GpuDrawBackend.render` cannot run without a GPU, so
/// nothing in `flutter test` can reach code written inline at its call
/// site. A version of the ratio spelled out a second time there -- even one
/// that reads identically today -- would leave the *tested* copy here and
/// the *shipping* copy uncovered, and the exact mutation this function
/// exists to catch (composing with `Transform2.scale(dpr, dpr)`, a
/// device-space ratio that collapses dash patterns at `dpr` times the wrong
/// zoom) is a small, plausible edit at an inline site that no test would
/// then see. Calling this function from `render` is what makes the suite's
/// witness cover the line that actually runs.
///
/// The extra `Transform2.multiply` this adds is one more composition per
/// frame, not per entity -- squarely inside "the frame path allocates
/// nothing per entity in steady state, and O(1) per flush" (CLAUDE.md):
/// `render` already performs two compositions before this one.
double dashScaleFor(ViewportTransform camera, Transform2 collectionInverse) =>
    composeTransforms(camera.worldToScreenMatrix, collectionInverse)
        .scaleMagnitude;

/// Draws [geometry] once per frame with the camera as a uniform, plus one
/// more pass per patch.
///
/// **Per-frame CPU work is bounded by patches, never by entities.** The
/// document was already walked once, at construction of [geometry]
/// (`ResidentGeometry`, Task 5); every subsequent frame re-derives only the
/// small `FrameInfo` uniform from the current [ViewportTransform] and
/// re-issues the main draw call the buffer's instance count implies. Each
/// covered label's patch (`ResidentGeometry.patches`) then adds one more
/// `FrameInfo`, one more draw call, one `patchRegionFor` and one
/// `labelBoundsLogical` call (each its own `Float64List(4)` scratch, per
/// their own doc comments), one `PatchRegion`, one `(ResidentPatch,
/// PatchRegion)` record, one `PatchImage` and three `Rect`s -- still O(1)
/// per flush, not per entity: every one of those is one per PATCH, never one
/// per instance inside it.
class GpuDrawBackend {
  GpuDrawBackend(this.geometry, this.collectionCamera,
      {FlutterTextMeasurer? measurer,
      TextStyleRecord Function(Handle)? textStyleOf})
      : _collectionInverse = collectionCamera.worldToScreenMatrix.invert(),
        _compositor = measurer != null && textStyleOf != null
            ? TextCompositor(measurer: measurer, textStyleOf: textStyleOf)
            : null;

  final ResidentGeometry geometry;
  final ViewportTransform collectionCamera;
  final Transform2 _collectionInverse;

  /// Composites the main image with every patch, in emission order --
  /// `null` without a [FlutterTextMeasurer] and a text-style lookup, in
  /// which case [paint] draws the main image alone and no text at all
  /// (Ruling E2's shape again: a caller that never supplies the two stays on
  /// the pre-Plan-E path with no behaviour change).
  final TextCompositor? _compositor;

  /// Reused every frame -- one `PatchImage` per patch this frame drew,
  /// built after `submit()` (see [render]'s tail) and consumed by
  /// [_compositor] in [paint].
  final List<PatchImage> _patchImages = <PatchImage>[];

  /// Reused per frame: `(patch, region)` pairs the patch loop in [render]
  /// found, drained into [_patchImages] after `submit()` -- see [render]'s
  /// tail for why the split matters.
  final List<(ResidentPatch, PatchRegion)> _pendingRegions =
      <(ResidentPatch, PatchRegion)>[];

  /// Painted with `filterQuality: none`, same as [TextCompositor]'s own --
  /// allocated once, reused by every `drawImageRect` call [paint] makes when
  /// there is no [_compositor] to draw through instead.
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.none;

  /// This frame's `collectionToLogical`, set once per [render] -- at the
  /// top, before its early returns, so it is current even on a frame that
  /// draws nothing -- and read by [paint]; see [paint]'s doc comment for why
  /// it is not recomputed there.
  Transform2 _collectionToLogical = Transform2.identity();

  gpu.Texture? _target;
  int _w = 0;
  int _h = 0;

  /// Frames submitted. A backend in the paint path that never increments this
  /// is drawing nothing, and a timing figure taken from it is the cost of an
  /// empty screen.
  int frames = 0;

  /// Patches drawn, clamped to the target's size, or entirely off screen,
  /// last frame -- diagnostics only, reset at the top of every [render].
  int patchesRendered = 0, patchesClipped = 0, patchesOffscreen = 0;

  ui.Image? render(ViewportTransform camera, Size viewport, double dpr) {
    // **Reset first, unconditionally -- before the early returns below, and
    // before anything that can throw.** `geometry.uniforms` is a
    // `HostBuffer` -- a bump allocator over a small ring of device blocks
    // (`flutter_gpu/lib/src/buffer.dart:208-223`; `_kFrameCount = 4`).
    // `reset()` only mutates its own bookkeeping cursors (`_frameCursor`,
    // `_bufferCursor`, `_offsetCursor`); it touches no `DeviceBuffer`
    // contents and enqueues no GPU work, so calling it here rather than
    // after `submit()` changes nothing about which physical slot a later
    // `emplace` in *this* call lands in, or when the GPU is done reading a
    // slot from `frameCount` (4) resets ago -- verified by reading `reset`'s
    // body, which is exactly those three assignments and nothing else.
    // Resetting after `submit()` instead left a real gap: `emplace` advances
    // the bump cursor before `bindUniform` and `submit` run, and
    // `bindUniform` throws on a failed bind
    // (`flutter_gpu/lib/src/render_pass.dart`'s `bindUniform`), so a
    // persistent bind failure would skip the post-submit `reset()` every
    // frame -- Flutter catches a paint-time exception and repaints past it
    // rather than stopping, so this is not a one-off crash but a leak of one
    // emplacement per frame, forever, until the block fills and a fresh
    // `DeviceBuffer` gets allocated every frame after that: exactly the
    // per-frame allocation this project's frame-path non-negotiable forbids
    // -- "the frame path allocates nothing per entity in steady state, and
    // O(1) per flush" (CLAUDE.md). Resetting first is exception-safe against
    // that failure mode, and it also covers the two early returns below for
    // free: a call to `render` that draws nothing is still "this frame" and
    // still needs the ring to advance once.
    //
    // `test/invariants/paint_allocation_test.dart` measures the O(1)-per-
    // flush claim for the existing `Canvas` paint path; this class is not
    // wired into a widget's `paint()` yet (a later task's job), so nothing
    // in this package's suite exercises this method against that invariant
    // today -- getting the reset right here is what keeps that true once it
    // is wired in.
    geometry.uniforms.reset();

    // **The same "reset first, before the early returns" reasoning extends
    // to every other per-frame field below (Task 6 review, round 2,
    // finding 1) -- it did not, until this fix.** `_collectionToLogical`
    // does not depend on `widthPx`/`heightPx`, so nothing stops computing it
    // here; the counters and the two patch lists do not depend on anything
    // computed below either. A document with zero instances but a
    // non-empty `texts` list is legitimate (an all-text drawing, or one just
    // rebuilt to remove its last stroke) and hits the `instanceCount == 0`
    // branch below on every subsequent frame -- forever, not once -- so
    // anything reset only past that branch would never reset again.
    // Previously that meant `_collectionToLogical` stayed pinned at its
    // `Transform2.identity()` field initialiser (the camera silently
    // ignored) and `_patchImages` kept whichever patches the LAST geometry
    // WITH instances had produced, composited by `paint` over `main: null`
    // against a `texts` list that may not even belong to the same document
    // any more. The hoist also folds in `_pendingRegions`, previously
    // cleared only after a successful drain at this method's tail: a throw
    // between the first `.add` there and that drain (a LATER patch's own
    // `patchCommandBuffer.submit()`, or `patch.target.asImage()`/
    // `target.asImage()` in the drain itself) used to strand entries for the
    // next frame's single-cursor merge with `geometry.texts` to trip over.
    // Resetting unconditionally, on every call, means a throw can now only ever
    // strand entries until the very next `render` -- never for a frame that
    // legitimately draws nothing, which is exactly what "still needs the
    // ring to advance once" above already argues for `geometry.uniforms`.
    _collectionToLogical =
        composeTransforms(camera.worldToScreenMatrix, _collectionInverse);
    _patchImages.clear();
    _pendingRegions.clear();
    patchesRendered = 0;
    patchesClipped = 0;
    patchesOffscreen = 0;

    final widthPx = (viewport.width * dpr).round();
    final heightPx = (viewport.height * dpr).round();
    if (widthPx <= 0 || heightPx <= 0 || geometry.instanceCount == 0) {
      return null;
    }
    if (_target == null || _w != widthPx || _h != heightPx) {
      // **`createTexture`, not `createImageSurface`.** The web backend has no
      // `createImageSurface` at all, and on macOS Metal its optional format
      // argument resolves to `PixelFormat.unknown` and throws.
      _target = gpu.gpuContext
          .createTexture(gpu.StorageMode.devicePrivate, widthPx, heightPx);
      _w = widthPx;
      _h = heightPx;
    }
    final target = _target!;

    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final pass = commandBuffer.createRenderPass(gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(texture: target, clearValue: vm.Vector4(1, 1, 1, 1)),
    ));

    pass.bindPipeline(geometry.pipeline);
    pass.setPrimitiveType(gpu.PrimitiveType.triangle);
    // **Load-bearing from Plan B on, and it was not before.** A stroke quad's
    // winding is invariant under reversing the segment — the direction and
    // the normal flip together — so Plan A never had to think about this. A
    // join's is not: `_emitJoin` picks the outer side with
    // `s = cross > 0 ? -half : half` (`vertices_draw_sink.dart`), so a left
    // turn and a right turn wind opposite ways and any culling would drop
    // half the corners in a drawing. `CullMode.none` is also the enum's zero
    // value, so this is pinning a default rather than changing behaviour —
    // pinned because a default that becomes load-bearing and stays implicit
    // is the kind of thing that changes under you in a package upgrade.
    pass.setCullMode(gpu.CullMode.none);
    pass.setColorBlendEnable(true);
    pass.bindVertexBuffer(
        gpu.BufferView(geometry.corners,
            offsetInBytes: 0, lengthInBytes: geometry.corners.sizeInBytes),
        slot: 0);
    pass.bindVertexBuffer(
        gpu.BufferView(geometry.instances,
            offsetInBytes: 0, lengthInBytes: geometry.instances.sizeInBytes),
        slot: 1);
    // **`dpr` is folded in here, not inside `buildFrameInfo`.** The
    // collector's buffer holds logical-pixel coordinates
    // (`viewport_transform.dart`: "screen coordinates are logical pixels"),
    // and so do `camera.worldToScreenMatrix` and `_collectionInverse` --
    // `composeTransforms` of the two is still a logical-to-logical mapping.
    // `buildFrameInfo` divides by `widthPx`/`heightPx`, which are *device*
    // pixels; handing it a logical-space transform against a device-pixel
    // denominator silently drops the `dpr` factor (correct only at `dpr ==
    // 1`, which is why that case alone cannot catch the mistake). Composing
    // with `Transform2.scale(dpr, dpr)` as the outermost transform converts
    // the logical mapping into a device-pixel one before `buildFrameInfo`
    // ever sees it -- matching the spike's own comment on the equivalent
    // step, "Logical screen -> device pixels -> NDC"
    // (`git show 8c82208:apps/dev_harness_2d/lib/gpu_arm.dart:423-426` --
    // that file was deleted in Task 9, before which it lived at this path).
    // Task 9's device run confirmed the fold itself: the drawing filled the
    // full viewport rather than the top-left quadrant the missing-`dpr`
    // defect this fixes used to produce (see the task-9 report).
    //
    // **`_collectionToLogical` -- set once, at the top of this method,
    // before the early returns (see that comment) -- is what
    // `collectionToDevice` composes here, not a second computation of it,
    // and `dashScale` comes from `dashScaleFor`, not a second spelling of
    // its formula here.** `render` cannot run without a GPU, so this is the
    // one call site nothing in `flutter test` can reach directly; the only
    // way the suite's coverage of the logical-vs-device distinction means
    // anything for what actually ships is for this line to build
    // `collectionToDevice` through the exact function the tests exercise
    // (`composeTransforms`) against the field's own value, rather than
    // restate `composeTransforms(...).scaleMagnitude` inline (see
    // `dashScaleFor`'s own doc comment above). `dashScaleFor` below still
    // recomputes the same `camera.worldToScreenMatrix`/`_collectionInverse`
    // composition internally, once more (see its own doc comment for why it
    // takes `camera` and `_collectionInverse` rather than a precomputed
    // transform) -- one extra `Transform2` composition per frame, not per
    // entity, so it stays inside "the frame path allocates nothing per
    // entity in steady state, and O(1) per flush" (CLAUDE.md).
    final collectionToDevice =
        composeTransforms(Transform2.scale(dpr, dpr), _collectionToLogical);
    pass.bindUniform(
      geometry.vertexShader.getUniformSlot('FrameInfo'),
      geometry.uniforms.emplace(buildFrameInfo(
          collectionToDevice, widthPx, heightPx,
          dashScale: dashScaleFor(camera, _collectionInverse))),
    );
    // **One call. `cornerVertexCount` vertices, one instance per record, in
    // buffer order.** The buffer was written once, in walk order, by
    // `GeometryCollector` (Task 3); nothing here sorts or partitions it, so
    // the buffer's order *is* the draw order (`vertices_draw_sink.dart:41-57`
    // is the standing record of what happens when a past version of this
    // codebase drew from a buffer partitioned by attribute instead of by
    // emission order). The vertex count itself is read off
    // `ResidentGeometry.kCornerVertices`, not restated as a literal `6`, so
    // a kind Plans C or D add to that buffer cannot leave this call drawing
    // one kind short.
    pass.draw(ResidentGeometry.cornerVertexCount,
        instanceCount: geometry.instanceCount);

    // **Submitted here, before any patch pass is created -- one command
    // buffer per RENDER PASS, not one per frame.** Task 9's first device run
    // with patches aborted on the very first frame that had one:
    // `-[AGXG15XFamilyCommandBuffer renderCommandEncoderWithDescriptor:]:967:
    // failed assertion 'A command encoder is already encoding to this
    // command buffer'`. Cause: `flutter_gpu`'s `RenderPass` opens its Metal
    // encoder at *construction*
    // (`flutter_gpu/lib/src/command_buffer.dart:130`'s `createRenderPass`),
    // and a `CommandBuffer` accepts exactly one `submit()`
    // (`flutter_gpu/lib/src/command_buffer.dart:240-248` throws
    // `StateError` on a second call) -- so a second `createRenderPass` on
    // the SAME buffer, which the patch loop below used to do once per
    // patch, opened a second encoder Metal refuses outright. The control
    // run (`patches=0`) completed normally, which isolated the crash to the
    // patch passes specifically. The fix is one command buffer per pass:
    // this one submits now, and each patch pass below gets its own fresh
    // `gpu.gpuContext.createCommandBuffer()`, submitted in turn, right after
    // its own `draw`. On the web shim this costs nothing extra --
    // `CommandBuffer` there is "a thin convenience wrapper... `submit` is a
    // no-op and `createRenderPass` returns a pass that drives the GL context
    // in place" (`flutter_scene/lib/src/gpu/web/command_buffer.dart`'s own
    // doc comment) -- multiple buffers per frame are exactly as cheap as one
    // there, which is also why the original (Metal-incompatible) shape had
    // passed every check that does not run on a real device.
    commandBuffer.submit();

    // **One more render pass per patch, each on its OWN command buffer,
    // submitted right after its own draw -- still O(1) per flush, one pair
    // per patch, never per entity.** Each covered label gets its own target,
    // so its pass starts with `RenderTarget.singleColor` against
    // `patch.target` rather than the main `target`; everything else about a
    // patch pass mirrors the main one above (same pipeline, same corner
    // buffer, same culling and blend state), reading `patch.instances` in
    // place of `geometry.instances` and a `FrameInfo` built from a
    // transform that maps the region's own device-pixel origin to the patch
    // target's top-left instead of the viewport's. `_patchImages` and the
    // three counters below were already reset at the top of this method,
    // before the early returns (see that comment) -- not reset again here.
    final dashScale = dashScaleFor(camera, _collectionInverse);
    for (final patch in geometry.patches) {
      final t = geometry.texts[patch.textIndex];
      final region = patchRegionFor(t, collectionToDevice, widthPx, heightPx,
          maxWidth: patch.targetWidth, maxHeight: patch.targetHeight);
      if (region == null) {
        patchesOffscreen++;
        continue;
      }
      // The region reached the target's size: either the live scale is past
      // the band's ceiling and Plan F's rebuild has not landed, or it sits
      // exactly at the ceiling. Drawn anyway, short if clamped; counted so
      // the harness can say how often. A diagnostic, not a decision.
      if (region.width == patch.targetWidth ||
          region.height == patch.targetHeight) {
        patchesClipped++;
      }
      final patchCommandBuffer = gpu.gpuContext.createCommandBuffer();
      final patchPass =
          patchCommandBuffer.createRenderPass(gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(
            texture: patch.target, clearValue: vm.Vector4(0, 0, 0, 0)),
      ));
      patchPass.bindPipeline(geometry.pipeline);
      patchPass.setPrimitiveType(gpu.PrimitiveType.triangle);
      patchPass.setCullMode(gpu.CullMode.none);
      patchPass.setColorBlendEnable(true);
      // Ruling E8: anchored at the target's origin. `Viewport` throws on a
      // negative origin, and the region's on-screen position is the
      // compositor's business.
      //
      // **No `Scissor` -- the viewport alone bounds the draw, and that is
      // enough.** `FrameInfo` (`buildFrameInfo`, built from `toPatch` below)
      // maps the region's own device-pixel rect to NDC `[-1, 1]` on both
      // axes; every vertex this pass emits is clipped against that NDC
      // volume before rasterisation runs at all, which is what actually
      // keeps a stroke's quad from painting outside the region when
      // `region` is smaller than the reused target (a live scale below the
      // band's ceiling) -- clipping happens at the primitive stage,
      // upstream of any per-fragment scissor test, so a scissor identical
      // to the viewport rect would have discarded nothing a correct NDC
      // mapping does not already discard. A `setScissor` call was here
      // originally (Ruling E8's letter) but was removed: the web backend's
      // `RenderPass` (`flutter_scene/lib/src/gpu/web/render_pass.dart`)
      // declares a `Scissor` data class yet never gives `RenderPass` a
      // `setScissor` method at all, so calling it would have been a
      // `NoSuchMethodError` waiting for whichever plan first targets web --
      // a real gap on that backend, not one a call site here can paper
      // over, and not worth suppressing the analyzer for (`flutter
      // analyze`'s own generic stand-in,
      // `flutter_scene/lib/src/gpu/stub/shim_stubs.dart`, is missing the
      // same method, for the same reason its own doc comment gives: "the
      // analyzer fallback is a throwing stub").
      //
      // **Framebuffer-origin assumption.** Anchoring at `(0, 0)` here, then
      // reading the same corner back below as `src = Rect.fromLTWH(0, 0,
      // region.width, region.height)` (this method's tail, after `submit`),
      // is only the same physical corner of `patch.target` if the backend's
      // framebuffer origin is top-left -- load-bearing exactly when `region`
      // is smaller than the target (a live scale below the band's ceiling),
      // since then the two corners of a bottom-left-origin backend would
      // disagree. Confirmed top-left for Impeller/Metal (Task 9's device run
      // placed geometry correctly, which a flipped origin would not have);
      // unverified for the WebGL shim, which nothing in this codebase has
      // run against yet.
      patchPass.setViewport(
          gpu.Viewport(x: 0, y: 0, width: region.width, height: region.height));
      patchPass.bindVertexBuffer(
          gpu.BufferView(geometry.corners,
              offsetInBytes: 0, lengthInBytes: geometry.corners.sizeInBytes),
          slot: 0);
      patchPass.bindVertexBuffer(
          gpu.BufferView(patch.instances,
              offsetInBytes: 0, lengthInBytes: patch.instances.sizeInBytes),
          slot: 1);
      final toPatch = composeTransforms(
          Transform2.translation(-region.x.toDouble(), -region.y.toDouble()),
          collectionToDevice);
      patchPass.bindUniform(
        geometry.vertexShader.getUniformSlot('FrameInfo'),
        geometry.uniforms.emplace(buildFrameInfo(
            toPatch, region.width, region.height,
            dashScale: dashScale)),
      );
      patchPass.draw(ResidentGeometry.cornerVertexCount,
          instanceCount: patch.instanceCount);
      // Submitted immediately, on this patch's own command buffer -- see
      // the main pass's `submit()` above for why one buffer cannot carry
      // more than one render pass on Metal.
      patchCommandBuffer.submit();
      patchesRendered++;
      _pendingRegions.add((patch, region));
    }

    frames++;

    // **`asImage()` only after the LAST `submit()`, on purpose.** By this
    // point every command buffer this frame created -- the main pass's and
    // each patch's own -- has already been submitted, in order, above; nothing
    // below submits anything. On native the image is a handle over the live
    // texture (`flutter_gpu/texture.cc`'s `Texture::AsImage`) and reads
    // whatever the texture holds when the picture rasterises, so the order
    // would not matter there. On the web shim `asImage()` SNAPSHOTS the
    // texture now (`snapshotTextureSync`), so taken before a target's own
    // submit it would show last frame's contents. One order that is right on
    // both backends -- the finding Codex made against revision 5's first
    // draft, still true now that there are `1 + P` submits instead of one.
    for (final (patch, region) in _pendingRegions) {
      _patchImages.add(PatchImage(
        textIndex: patch.textIndex,
        image: patch.target.asImage(),
        src: Rect.fromLTWH(
            0, 0, region.width.toDouble(), region.height.toDouble()),
        dst: Rect.fromLTWH(region.x / dpr, region.y / dpr, region.width / dpr,
            region.height / dpr),
        layerBounds: labelBoundsLogical(
            geometry.texts[patch.textIndex], _collectionToLogical),
      ));
    }
    // `_pendingRegions` is intentionally left populated here, rather than
    // cleared again -- the next `render` call clears it unconditionally, at
    // the top, before its own early returns (see that comment): a single
    // reset point that covers both a frame that legitimately draws nothing
    // and a frame that throws between the `.add` above and this point,
    // which a clear only here could not.
    return target.asImage();
  }

  /// One frame onto [canvas]: [render], then the compositor. This is the
  /// call site a widget uses (Plan F) and the harness uses (Task 7).
  ///
  /// **Without a [_compositor], the main image alone -- no text, and no
  /// patches.** A [GpuDrawBackend] built without a [FlutterTextMeasurer] and
  /// a text-style lookup (Ruling E2's shape again) still draws every stroke,
  /// join, point and fill exactly as before Plan E; it draws no glyph at all,
  /// resident or patched, until both are supplied.
  void paint(
      Canvas canvas, ViewportTransform camera, Size viewport, double dpr) {
    final main = render(camera, viewport, dpr);
    final compositor = _compositor;
    if (compositor == null) {
      if (main != null) {
        canvas.drawImageRect(
            main,
            Rect.fromLTWH(0, 0, main.width.toDouble(), main.height.toDouble()),
            Rect.fromLTWH(0, 0, viewport.width, viewport.height),
            _imagePaint);
      }
      return;
    }
    // `_collectionToLogical` is this frame's -- set once by the [render] call
    // just above, not recomputed here. `render` already builds this exact
    // composition for its own `collectionToDevice`, and `dashScaleFor` builds
    // it a second time internally; a third `composeTransforms` call here,
    // per frame rather than per entity, would still sit inside "the frame
    // path allocates nothing per entity in steady state, and O(1) per flush"
    // (CLAUDE.md) -- but there is no reason to pay it when [render] already
    // has the answer.
    compositor.paint(canvas,
        main: main,
        viewport: viewport,
        collectionToLogical: _collectionToLogical,
        texts: geometry.texts,
        patches: _patchImages);
  }

  void dispose() => geometry.dispose();
}
