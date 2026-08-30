import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../viewport_transform.dart';
import 'gpu_facade.dart' as gpu;
import 'resident_geometry.dart';

/// The uniform block: `mat4 mvp` then `vec2 half_viewport`, std140, 80 bytes.
///
/// **80, not the 128 `impellerc` reflects.** Plain std140 arithmetic gives 80:
/// `mat4` occupies 64 bytes (four 16-byte-aligned `vec4` columns), `vec2`
/// needs only 8-byte alignment so it sits at offset 64..72 with no gap, and
/// the struct's own alignment (16, from `mat4`) rounds 72 up to 80. The 128
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
ByteData buildFrameInfo(
    Transform2 collectionToDevice, int widthPx, int heightPx) {
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
  f(18, 0);
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

/// Draws [geometry] once per frame with the camera as a uniform.
///
/// **The matrix is the only per-frame CPU work.** The document was already
/// walked once, at construction of [geometry] (`ResidentGeometry`, Task 5);
/// every subsequent frame re-derives only the small `FrameInfo` uniform from
/// the current [ViewportTransform] and re-issues the one draw call the
/// buffer's instance count implies.
class GpuDrawBackend {
  GpuDrawBackend(this.geometry, this.collectionCamera)
      : _collectionInverse = collectionCamera.worldToScreenMatrix.invert();

  final ResidentGeometry geometry;
  final ViewportTransform collectionCamera;
  final Transform2 _collectionInverse;

  gpu.Texture? _target;
  int _w = 0;
  int _h = 0;

  /// Frames submitted. A backend in the paint path that never increments this
  /// is drawing nothing, and a timing figure taken from it is the cost of an
  /// empty screen.
  int frames = 0;

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
    final collectionToDevice = composeTransforms(
      Transform2.scale(dpr, dpr),
      composeTransforms(camera.worldToScreenMatrix, _collectionInverse),
    );
    pass.bindUniform(
      geometry.vertexShader.getUniformSlot('FrameInfo'),
      geometry.uniforms
          .emplace(buildFrameInfo(collectionToDevice, widthPx, heightPx)),
    );
    // **One call. Six vertices, one instance per record, in buffer order.**
    // The buffer was written once, in walk order, by `GeometryCollector`
    // (Task 3); nothing here sorts or partitions it, so the buffer's order
    // *is* the draw order (`vertices_draw_sink.dart:41-57` is the standing
    // record of what happens when a past version of this codebase drew from
    // a buffer partitioned by attribute instead of by emission order).
    pass.draw(6, instanceCount: geometry.instanceCount);

    commandBuffer.submit();
    frames++;
    // Synchronous on both backends: the web shim's `Texture.asImage` states it
    // "matches flutter_gpu's synchronous `asImage`".
    return target.asImage();
  }

  void dispose() => geometry.dispose();
}
