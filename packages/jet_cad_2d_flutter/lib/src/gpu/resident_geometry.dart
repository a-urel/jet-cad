import 'dart:typed_data';

import 'gpu_facade.dart' as gpu;
import 'instance_record.dart';

/// The document's geometry, uploaded once and read every frame.
///
/// **Uploaded once is the whole claim.** The spike measured a 14.7 ms
/// collection walk at 10,000 entities against a 0.61 ms frame; this class is
/// where the walk stops being per-frame.
class ResidentGeometry {
  ResidentGeometry._(this.instanceCount, this._corners, this._instances,
      this._pipeline, this._vertexShader, this._uniforms);

  /// **Package-prefixed, because this is a library asset.** `jet_cad_2d_flutter`
  /// declares `assets/shaders/cad.shaderbundle` in its own `pubspec.yaml`, and
  /// Flutter namespaces a package-declared asset under `packages/<name>/` in
  /// the built asset bundle regardless of which package's code loads it — the
  /// asset key is a property of who *declared* the asset, not of who reads it.
  /// The spike's bare `assets/shaders/cad.shaderbundle`
  /// (`apps/dev_harness_2d/lib/gpu_arm.dart:253`) only worked because the
  /// harness app declared that same path in its own `pubspec.yaml`, which
  /// shadows the prefix for an app that owns the asset outright — this
  /// package does not have that luxury as a dependency of some other app.
  static const String _bundlePath =
      'packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle';

  /// Bytes a buffer of [instances] records occupies.
  static int byteLengthFor(int instances) => instances * kFloatsPerInstance * 4;

  /// Uploads [instances], or returns null if this platform has no GPU.
  static Future<ResidentGeometry?> create(
      Float32List instances, int instanceCount) async {
    if (!gpu.gpuAvailable()) return null;
    // **The async loader, not `fromAsset`.** `ShaderLibrary.fromAsset` is
    // synchronous and throws on web, where asset loading is not.
    final library = await gpu.loadShaderLibraryAsync(_bundlePath);
    final vertex = library?['CadStrokeVertex'];
    final fragment = library?['CadStrokeFragment'];
    if (vertex == null || fragment == null) return null;

    // Two triangles of a unit quad: (endpoint, side).
    final corners = Float32List.fromList(<double>[
      0, -1, 0, 1, 1, -1, //
      1, -1, 0, 1, 1, 1, //
    ]);

    final context = gpu.gpuContext;
    // **Two buffer slots, not one interleaved layout.** `impellerc`'s
    // reflection of this shader (verified against a fresh single-stage run:
    // `corner@0, kind@8, p0@12, p1@20, half_width@28, color@32`) describes the
    // offsets *only if every attribute came from one combined buffer* — that
    // is the layout the shader bundle declares by default, and `VertexLayout`
    // exists specifically to override it
    // (`flutter_gpu/src/vertex_layout.dart`: "override the default
    // interleaved layout that the shader bundle declares ... to bind ...
    // attributes from separate buffers"). Binding `corner` from its own
    // buffer at slot 0 and the instance record from its own buffer at slot 1
    // means the instance attributes' offsets are the record's *own* offsets
    // (`instance_record.dart`'s `[kind, x0, y0, x1, y1, halfWidth, r, g, b,
    // a]`), not the reflected ones shifted by `corner`'s 8 bytes. This is the
    // same two-buffer split the spike uses
    // (`apps/dev_harness_2d/lib/gpu_arm.dart:379-386`).
    final layout = gpu.VertexLayout(buffers: <gpu.VertexBuffer>[
      const gpu.VertexBuffer(strideInBytes: 8, attributes: [
        gpu.VertexAttribute(name: 'corner', format: gpu.VertexFormat.float32x2),
      ]),
      const gpu.VertexBuffer(
        strideInBytes: kFloatsPerInstance * 4,
        stepMode: gpu.VertexStepMode.instance,
        attributes: [
          gpu.VertexAttribute(name: 'kind', format: gpu.VertexFormat.float32),
          gpu.VertexAttribute(
              name: 'p0', format: gpu.VertexFormat.float32x2, offsetInBytes: 4),
          gpu.VertexAttribute(
              name: 'p1',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: 12),
          gpu.VertexAttribute(
              name: 'half_width',
              format: gpu.VertexFormat.float32,
              offsetInBytes: 20),
          gpu.VertexAttribute(
              name: 'color',
              format: gpu.VertexFormat.float32x4,
              offsetInBytes: 24),
        ],
      ),
    ]);

    return ResidentGeometry._(
      instanceCount,
      context.createDeviceBufferWithCopy(ByteData.sublistView(corners)),
      context.createDeviceBufferWithCopy(ByteData.sublistView(
          instances, 0, instanceCount * kFloatsPerInstance)),
      context.createRenderPipeline(vertex, fragment, vertexLayout: layout),
      vertex,
      context.createHostBuffer(),
    );
  }

  final int instanceCount;
  final gpu.DeviceBuffer _corners;
  final gpu.DeviceBuffer _instances;
  final gpu.RenderPipeline _pipeline;
  final gpu.Shader _vertexShader;
  final gpu.HostBuffer _uniforms;

  int get byteLength => byteLengthFor(instanceCount);

  gpu.DeviceBuffer get corners => _corners;
  gpu.DeviceBuffer get instances => _instances;
  gpu.RenderPipeline get pipeline => _pipeline;
  gpu.Shader get vertexShader => _vertexShader;
  gpu.HostBuffer get uniforms => _uniforms;

  /// **A deliberate no-op.** None of `flutter_gpu`'s `DeviceBuffer`,
  /// `RenderPipeline`, `Shader` or `HostBuffer` expose a `dispose` method
  /// (`flutter_gpu/lib/src/{buffer,render_pipeline,shader,context}.dart`
  /// carry none) — their native peers are reclaimed by the engine's own
  /// finalizers. This method exists as the seam `GpuDrawBackend.dispose`
  /// (Task 6) calls, so a future native resource with a real teardown has
  /// somewhere to plug in without changing that call site.
  void dispose() {}
}
