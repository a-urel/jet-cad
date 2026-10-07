/// The resident backend's per-frame uniform block and the two transforms it
/// is built from. **Pure, and in this package on purpose:** no GPU type
/// appears here, so `flutter test` exercises the exact code
/// `GpuDrawBackend.render` (package `jet_cad_2d_gpu`) runs every frame, and
/// core's differential tests (`test/support/gpu_comparison.dart`) read the
/// same functions without depending on the GPU package.
library;

import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../viewport_transform.dart';

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
/// `impellerc` reports (the doc comment in `resident_geometry.dart`, now in
/// package `jet_cad_2d_gpu`) is real, but
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
///
/// `out`, when given and 80 bytes long, is written in place and returned --
/// the frame path's own block; a fresh one otherwise.
ByteData buildFrameInfo(
    Transform2 collectionToDevice, int widthPx, int heightPx,
    {required double dashScale, ByteData? out}) {
  final sx = 2.0 / widthPx;
  final sy = -2.0 / heightPx;
  final data = out != null && out.lengthInBytes == 80 ? out : ByteData(80);
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
