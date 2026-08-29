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
/// (`apps/dev_harness_2d/lib/gpu_arm.dart:414`) already hand-packs this same
/// 80-byte layout and runs correctly on macOS Metal. This project has no
/// device available to confirm the native path the same way; Task 7's
/// harness run is where that confirmation actually happens.
///
/// [collectionToScreen] takes a point in the buffer's space — the collection
/// camera's screen space — to the live camera's screen space. This function
/// finishes the job: screen to normalized device coordinates, y flipped.
ByteData buildFrameInfo(
    Transform2 collectionToScreen, int widthPx, int heightPx) {
  final sx = 2.0 / widthPx;
  final sy = -2.0 / heightPx;
  final data = ByteData(80);
  void f(int i, double v) => data.setFloat32(i * 4, v, Endian.host);
  f(0, collectionToScreen.a * sx);
  f(1, collectionToScreen.b * sy);
  f(2, 0);
  f(3, 0);
  f(4, collectionToScreen.c * sx);
  f(5, collectionToScreen.d * sy);
  f(6, 0);
  f(7, 0);
  f(8, 0);
  f(9, 0);
  f(10, 1);
  f(11, 0);
  f(12, collectionToScreen.e * sx - 1);
  f(13, collectionToScreen.f * sy + 1);
  f(14, 0);
  f(15, 1);
  f(16, widthPx / 2);
  f(17, heightPx / 2);
  f(18, 0);
  f(19, 0);
  return data;
}

/// `outer ∘ inner`.
Transform2 composeTransforms(Transform2 outer, Transform2 inner) => Transform2(
      outer.a * inner.a + outer.c * inner.b,
      outer.b * inner.a + outer.d * inner.b,
      outer.a * inner.c + outer.c * inner.d,
      outer.b * inner.c + outer.d * inner.d,
      outer.a * inner.e + outer.c * inner.f + outer.e,
      outer.b * inner.e + outer.d * inner.f + outer.f,
    );

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
    pass.bindUniform(
      geometry.vertexShader.getUniformSlot('FrameInfo'),
      geometry.uniforms.emplace(buildFrameInfo(
          composeTransforms(camera.worldToScreenMatrix, _collectionInverse),
          widthPx,
          heightPx)),
    );
    // **One call. Six vertices, one instance per record, in buffer order.**
    // The buffer was written once, in walk order, by `GeometryCollector`
    // (Task 3); nothing here sorts or partitions it, so the buffer's order
    // *is* the draw order (`vertices_draw_sink.dart:41-57` is the standing
    // record of what happens when a past version of this codebase drew from
    // a buffer partitioned by attribute instead of by emission order).
    pass.draw(6, instanceCount: geometry.instanceCount);

    commandBuffer.submit();
    // **Reset once per frame, after submit.** `geometry.uniforms` is a
    // `HostBuffer` -- a bump allocator over a small ring of device blocks
    // (`flutter_gpu/lib/src/buffer.dart:208-223`; `_kFrameCount = 4`).
    // `emplace` never rewinds it; only `reset` does, by advancing to the next
    // frame's block and zeroing the bump cursor. Skipping this call would
    // still *work* -- each `emplace` bump-allocates forward inside the
    // current 1 MB block, and one `FrameInfo` per frame is small -- but the
    // block would fill after roughly 12,800 frames (1,024,000 bytes /
    // 80-byte-aligned emplacements) and then silently grow a fresh block per
    // frame forever after, which is exactly the per-frame allocation this
    // project's frame-path non-negotiable forbids -- "the frame path
    // allocates nothing per entity in steady state, and O(1) per flush"
    // (CLAUDE.md). `test/invariants/paint_allocation_test.dart` measures that
    // claim for the existing `Canvas` paint path; this class is not wired
    // into a widget's `paint()` yet (a later task's job), so nothing in this
    // package's suite exercises `render` against that invariant today --
    // getting the reset right here is what keeps that true once it is wired
    // in. Resetting after
    // `submit()` -- not before -- matters too: `reset()` advances the frame
    // cursor that selects *this frame's* ring slot, and the emplace this
    // frame just made must be read by the GPU under the slot it was written
    // to, not the next one.
    geometry.uniforms.reset();
    frames++;
    // Synchronous on both backends: the web shim's `Texture.asImage` states it
    // "matches flutter_gpu's synchronous `asImage`".
    return target.asImage();
  }

  void dispose() => geometry.dispose();
}
