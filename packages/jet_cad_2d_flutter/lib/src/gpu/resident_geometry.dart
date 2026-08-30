import 'package:flutter/foundation.dart';

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
  /// (`git show 8c82208:apps/dev_harness_2d/lib/gpu_arm.dart:253` -- that
  /// file was deleted in Task 9, before which it lived at this path) only
  /// worked because the harness app declared that same path in its own
  /// `pubspec.yaml`, which
  /// shadows the prefix for an app that owns the asset outright — this
  /// package does not have that luxury as a dependency of some other app.
  ///
  /// **This means the load path is untestable from inside this package.**
  /// `flutter test` builds `build/unit_test_assets/AssetManifest.bin` from
  /// this package's own `pubspec.yaml`, so it carries only the bare key —
  /// there is no consuming app here to apply the `packages/` prefix. A
  /// widget test in this package that tried to exercise `create`'s load path
  /// against the prefixed key would fail to find the asset. That failure is
  /// expected and is not evidence the path is wrong; do not "fix" it back to
  /// the bare key to make such a test pass. Task 9's harness run (a real
  /// app depending on this package) is where the prefixed key was actually
  /// exercised, successfully -- see the task-9 report.
  static const String _bundlePath =
      'packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle';

  /// The unit quad's six corners: two triangles, not a triangle strip,
  /// because a strip cannot mix kinds and Plans B through D add kinds to
  /// this same buffer. `x` picks the endpoint (0 = p0, 1 = p1), `y` picks the
  /// side (-1 or +1) — see `cad_stroke.vert`'s `corner` comment. Four
  /// distinct corners, (0,-1) (0,1) (1,-1) (1,1); the diagonal (0,1)-(1,-1)
  /// is shared by both triangles, and both wind the same way (signed area
  /// -2 for each, worked by hand).
  ///
  /// `@visibleForTesting`: no test can reach this data through `create`
  /// itself (it runs only with a real GPU context), so it is hoisted here to
  /// be asserted directly by a plain `flutter test`.
  @visibleForTesting
  static const List<double> kCornerVertices = <double>[
    0, -1, 0, 1, 1, -1, //
    1, -1, 0, 1, 1, 1, //
  ];

  /// The pipeline's vertex input layout: `corner` in its own buffer at slot
  /// 0 (per vertex), the instance record in its own buffer at slot 1 (per
  /// instance).
  ///
  /// **Two buffer slots, not one interleaved layout.** `impellerc`'s
  /// reflection of this shader (verified against a fresh single-stage run:
  /// `corner@0, kind@8, p0@12, p1@20, half_width@28, color@32`) describes the
  /// offsets *only if every attribute came from one combined buffer* — that
  /// is the layout the shader bundle declares by default, and `VertexLayout`
  /// exists specifically to override it
  /// (`flutter_gpu/src/vertex_layout.dart`: "override the default
  /// interleaved layout that the shader bundle declares ... to bind ...
  /// attributes from separate buffers", and `offsetInBytes` is defined there
  /// as the offset "from the start of each element in the owning vertex
  /// buffer" — a buffer-relative offset, not a global one). Binding `corner`
  /// from its own buffer at slot 0 and the instance record from its own
  /// buffer at slot 1 means the instance attributes' offsets are the
  /// record's *own* offsets (`instance_record.dart`'s `[kind, x0, y0, x1,
  /// y1, halfWidth, r, g, b, a]`), not the reflected ones shifted by
  /// `corner`'s 8 bytes. This is the same two-buffer split the spike used
  /// (`git show 8c82208:apps/dev_harness_2d/lib/gpu_arm.dart:379-386` --
  /// that file was deleted in Task 9, before which it lived at this path).
  ///
  /// `@visibleForTesting`: same reason as [kCornerVertices] — this is pure
  /// configuration data, constructible and assertable without a GPU context,
  /// but only reachable through `create`'s GPU-gated path otherwise.
  ///
  /// `@internal` besides: its type, `gpu.VertexLayout`, resolves through
  /// `gpu_facade.dart`'s re-export of `flutter_scene`'s internal GPU shim
  /// (`gpu_facade.dart:21`) -- a consumer outside this package could not
  /// declare a variable of this type even if it read the field, so this
  /// annotation makes the analyzer say so rather than leaving that for a
  /// confused import error. Same reasoning as the five getters below.
  @visibleForTesting
  @internal
  static const gpu.VertexLayout kStrokeVertexLayout = gpu.VertexLayout(
    buffers: <gpu.VertexBuffer>[
      gpu.VertexBuffer(strideInBytes: 8, attributes: <gpu.VertexAttribute>[
        gpu.VertexAttribute(name: 'corner', format: gpu.VertexFormat.float32x2),
      ]),
      gpu.VertexBuffer(
        strideInBytes: kFloatsPerInstance * 4,
        stepMode: gpu.VertexStepMode.instance,
        attributes: <gpu.VertexAttribute>[
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
    ],
  );

  /// Bytes a buffer of [instances] records occupies.
  static int byteLengthFor(int instances) => instances * kFloatsPerInstance * 4;

  /// Uploads [instances], or returns null if this platform has no GPU, or if
  /// the upload itself failed.
  ///
  /// **Two different reasons collapse to the same `null`, deliberately, and
  /// that split is worth spelling out.** A platform with no GPU is routine —
  /// `gpuAvailable()` covers it above, silently, and is expected to be false
  /// on most CI and many devices. Everything past that guard runs only once
  /// the GPU is confirmed present, so a failure there (a bad or missing
  /// shader-bundle asset key — `ShaderLibrary.fromAsset` throws `Exception
  /// ("Failed to initialize ShaderLibrary: ...")`,
  /// `flutter_gpu/src/shader_library.dart:28-31` — or a device buffer
  /// allocation the driver rejected — `createDeviceBufferWithCopy` throws
  /// `Exception('DeviceBuffer creation failed')`,
  /// `flutter_gpu/src/context.dart:152-158`) is a real bug, not an expected
  /// fallback. It is still returned as `null`, because the whole point of a
  /// nullable return is that the caller does not have to catch — but it is
  /// reported through [FlutterError.reportError] first, so it reaches
  /// `FlutterError.onError` and whatever crash reporting an app wires to it,
  /// rather than surfacing only as "nothing drew" with no diagnostic at all.
  static Future<ResidentGeometry?> create(
      Float32List instances, int instanceCount) async {
    if (!gpu.gpuAvailable()) return null;
    try {
      return await _upload(instances, instanceCount);
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'jet_cad_2d_flutter',
        context:
            ErrorDescription('uploading the resident GPU geometry backend'),
      ));
      return null;
    }
  }

  static Future<ResidentGeometry?> _upload(
      Float32List instances, int instanceCount) async {
    // **The async loader, not `fromAsset`.** `ShaderLibrary.fromAsset` is
    // synchronous and throws on web, where asset loading is not.
    final library = await gpu.loadShaderLibraryAsync(_bundlePath);
    final vertex = library?['CadStrokeVertex'];
    final fragment = library?['CadStrokeFragment'];
    if (vertex == null || fragment == null) return null;

    final corners = Float32List.fromList(kCornerVertices);

    final context = gpu.gpuContext;

    // **Never a zero-byte device buffer.** An empty document — the app's
    // startup state, and a real output of `GeometryCollector` — passes
    // `instanceCount == 0` here. Whether a zero-byte `DeviceBuffer` is legal
    // is a per-backend question this plan cannot answer without a device
    // (`createDeviceBufferWithCopy` throws on a rejected allocation,
    // `flutter_gpu/src/context.dart:152-158`), so this never asks: with zero
    // instances the upload is one record's worth of zeroed bytes instead of
    // zero bytes. It is never read — `GpuDrawBackend.render` already skips
    // the draw call whenever `geometry.instanceCount == 0` — so its content
    // does not matter, only that the allocation succeeds.
    final instanceBytes = instanceCount == 0
        ? ByteData(kFloatsPerInstance * 4)
        : ByteData.sublistView(
            instances, 0, instanceCount * kFloatsPerInstance);

    return ResidentGeometry._(
      instanceCount,
      context.createDeviceBufferWithCopy(ByteData.sublistView(corners)),
      context.createDeviceBufferWithCopy(instanceBytes),
      context.createRenderPipeline(vertex, fragment,
          vertexLayout: kStrokeVertexLayout),
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

  /// **`@internal`, all five.** Every return type here (`gpu.DeviceBuffer`,
  /// `gpu.RenderPipeline`, `gpu.Shader`, `gpu.HostBuffer`) resolves through
  /// `gpu_facade.dart`'s `export 'package:flutter_scene/src/gpu/gpu.dart';`
  /// -- the off-contract, pre-1.0, `lib/src/` path that file exists to
  /// confine. `gpu_facade.dart` itself is deliberately unexported from this
  /// package's barrel, so without this annotation a consumer outside this
  /// package could see these getters (`ResidentGeometry` itself is public,
  /// for `GpuDrawBackend`'s sake) but could not name a variable to hold what
  /// they return. `@internal` makes that an analyzer error at the call site
  /// instead of a confusing one at the type. `GpuDrawBackend` is this
  /// package's only caller of all five, one call site each
  /// (`gpu_draw_backend.dart:167, 190, 194-195, 198-199, 224-225`), which stays
  /// legal: `@internal` only restricts use from *outside* this package.
  @internal
  gpu.DeviceBuffer get corners => _corners;
  @internal
  gpu.DeviceBuffer get instances => _instances;
  @internal
  gpu.RenderPipeline get pipeline => _pipeline;
  @internal
  gpu.Shader get vertexShader => _vertexShader;
  @internal
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
