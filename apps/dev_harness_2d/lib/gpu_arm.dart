// THROWAWAY SPIKE CODE. Branch `spike/flutter-gpu-backend`, 2026-08-29.
//
// Prices a GPU-resident geometry buffer against the per-frame painter walk.
//
// The question, in one line: **can a pan or a zoom cost a uniform write
// instead of a document walk, and still draw sharp?** Plan 3i's tile cache
// buys a cheap gesture frame by blitting a magnified bitmap, and
// `2026-08-29-vector-gesture-replay-spike.md` measured what it costs to draw
// real geometry instead — 22.9x at 500,000 entities, because a replay is
// O(visible geometry) per frame on the CPU. This arm asks whether moving the
// geometry to the GPU once removes that per-frame term altogether.
//
// **What this deliberately does not do**, so the numbers are read honestly:
//
//   - **No joins and no caps.** Every segment is an independent quad. The
//     notch at a corner is visible. Joins are a constant factor on the vertex
//     count, not a term in the per-frame cost this measures.
//   - **No antialiasing.** See `cad_line.frag`.
//   - **Dash spans are baked at the collection camera** and never re-split, so
//     a dash pattern stretches under zoom. This is the same cheat
//     `2026-08-29-widget-per-entity-spike.md` ran in the widget arms' favour,
//     and it is stated for the same reason.
//   - **Fills and text are not drawn**, only counted.
//
// Each of those makes this arm look better than a real backend would. The
// point is that the *shape* of the cost — O(1) CPU per frame against
// O(visible geometry) — is not something they change.
//
// ignore_for_file: avoid_print -- printing the numbers is what a spike is for.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Floats per segment in the instance buffer: p0, p1, half width, rgba.
const int kFloatsPerSegment = 9;

/// The segments of a whole document, in the space of the camera they were
/// collected under.
///
/// **Not world space, and the difference is the point.** `DraftPainter` folds
/// the camera into the residual chain it hands a sink, and its level-of-detail
/// decisions read the camera's scale. Collecting under an identity camera
/// would give world coordinates and the *wrong* level of detail — every
/// hairline a full circle. Collecting under the fit camera gives the level of
/// detail a fitted view would draw, and the buffer's space is then that
/// camera's screen space. The render's matrix maps out of it:
///
///     mvp = ndcFromScreen(now) ∘ worldToScreen(now) ∘ screenToWorld(fit)
class GpuSegments {
  GpuSegments(this.data, this.count, this.collectionCamera,
      {required this.skippedFills, required this.skippedText});

  /// [count] * [kFloatsPerSegment] floats, tightly packed.
  final Float32List data;
  final int count;

  /// The camera [data] is expressed in the screen space of.
  final ViewportTransform collectionCamera;

  final int skippedFills;
  final int skippedText;

  int get byteLength => count * kFloatsPerSegment * 4;
}

/// Collects every stroked segment a painter walk emits.
///
/// **Applies the residual.** Dropping it is the first defect the widget spike's
/// smoke run found — geometry between `beginResidual` and `endResidual` is in
/// residual-local coordinates, and keeping the points while throwing the
/// transform away puts the whole drawing outside the viewport.
class SegmentCollector implements DrawSink {
  SegmentCollector({
    required this.pixelsPerPaperMm,
    required this.devicePixelRatio,
    this.lineweightScale = 1.0,
  });

  final double pixelsPerPaperMm;
  final double devicePixelRatio;
  final double lineweightScale;

  final List<double> _out = <double>[];
  int _segments = 0;
  int _skippedFills = 0;
  int _skippedText = 0;

  Transform2 _residual = Transform2.identity();

  int get segmentCount => _segments;
  int get skippedFills => _skippedFills;
  int get skippedText => _skippedText;

  GpuSegments finish(ViewportTransform camera) => GpuSegments(
        Float32List.fromList(_out),
        _segments,
        camera,
        skippedFills: _skippedFills,
        skippedText: _skippedText,
      );

  /// `VerticesDrawSink._halfWidthFor`, copied rather than shared: this is
  /// throwaway code and the sink's is private. If the two ever disagree the
  /// comparison is invalid, so the formula is reproduced exactly.
  double _halfWidthFor(int lineweightHundredths) {
    final logical =
        lineweightHundredths / 100.0 * pixelsPerPaperMm * lineweightScale;
    final floorLogical =
        VerticesDrawSink.kMinStrokeDevicePixels / devicePixelRatio;
    final w =
        logical.isFinite && logical > floorLogical ? logical : floorLogical;
    return w / 2;
  }

  void _emit(double x0, double y0, double x1, double y1, double half, int argb) {
    _out
      ..add(x0)
      ..add(y0)
      ..add(x1)
      ..add(y1)
      ..add(half)
      ..add(((argb >> 16) & 0xFF) / 255.0)
      ..add(((argb >> 8) & 0xFF) / 255.0)
      ..add((argb & 0xFF) / 255.0)
      ..add(((argb >> 24) & 0xFF) / 255.0);
    _segments++;
  }

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {
    _residual = residual;
  }

  @override
  void endResidual() {}

  @override
  void point(double x, double y, ResolvedStyle style) {
    final half = _halfWidthFor(style.lineweightHundredths);
    final t = _residual;
    final px = t.a * x + t.c * y + t.e;
    final py = t.b * x + t.d * y + t.f;
    // A point is a zero-length segment; the shader's degenerate branch gives
    // it a direction and it draws as a dot of the right width.
    _emit(px, py, px, py, half, style.argb);
  }

  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count < 2) return;
    final half = _halfWidthFor(style.lineweightHundredths);
    final t = _residual;
    var px = t.a * points[0] + t.c * points[1] + t.e;
    var py = t.b * points[0] + t.d * points[1] + t.f;
    final firstX = px, firstY = py;
    for (var i = 1; i < count; i++) {
      final qx = t.a * points[i * 2] + t.c * points[i * 2 + 1] + t.e;
      final qy = t.b * points[i * 2] + t.d * points[i * 2 + 1] + t.f;
      _emit(px, py, qx, qy, half, style.argb);
      px = qx;
      py = qy;
    }
    if (closed) _emit(px, py, firstX, firstY, half, style.argb);
  }

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      arc(cx, cy, r, 0, 2 * math.pi, style);

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style) {
    final half = _halfWidthFor(style.lineweightHundredths);
    final t = _residual;
    final deviceRadius = r * t.scaleMagnitude;
    final steps = _stepsFor(deviceRadius, sweep.abs());
    var prevX = 0.0, prevY = 0.0;
    for (var i = 0; i <= steps; i++) {
      final angle = start + sweep * (i / steps);
      final lx = cx + r * math.cos(angle);
      final ly = cy + r * math.sin(angle);
      final x = t.a * lx + t.c * ly + t.e;
      final y = t.b * lx + t.d * ly + t.f;
      if (i > 0) _emit(prevX, prevY, x, y, half, style.argb);
      prevX = x;
      prevY = y;
    }
  }

  /// Chord count for a sweep, at a quarter-pixel sagitta.
  ///
  /// **Fixed at collection time, and that is a real limitation.** A circle's
  /// tessellation is scale-dependent — `DrawSink.fillCircle` says so — and a
  /// buffer uploaded once cannot re-fan it. Zooming far in on a small circle
  /// in this arm shows the chords. A real backend would either re-upload the
  /// arcs above a scale threshold or draw them from an analytic fragment
  /// shader; neither changes the per-frame term this spike measures.
  int _stepsFor(double deviceRadius, double sweep) {
    if (!deviceRadius.isFinite || deviceRadius <= 0.25) return 1;
    final maxAngle = 2 * math.acos(1 - 0.25 / deviceRadius);
    if (!maxAngle.isFinite || maxAngle <= 0) return 256;
    return math.max(1, math.min(512, (sweep / maxAngle).ceil()));
  }

  @override
  void fillPolygon(
      Float64List points, int count, Int32List triangles, ResolvedStyle style) {
    _skippedFills++;
  }

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {
    _skippedFills++;
  }

  @override
  void text(String text, Handle style, ResolvedStyle resolved) {
    _skippedText++;
  }
}

/// Draws a [GpuSegments] buffer through `flutter_gpu`, once per frame, with
/// the camera as its only per-frame input.
class GpuLineRenderer {
  GpuLineRenderer._(this._segments, this._pipeline, this._vertexShader,
      this._cornerBuffer, this._segmentBuffer, this._hostBuffer);

  static const String _bundlePath = 'assets/shaders/cad.shaderbundle';

  /// Loads the shader bundle, uploads [segments], and builds the pipeline.
  ///
  /// **The upload happens here and never again.** That is the whole claim
  /// being tested.
  static Future<GpuLineRenderer> create(GpuSegments segments) async {
    final library = await gpu.ShaderLibrary.fromAsset(_bundlePath);
    if (library == null) {
      throw StateError('cad.shaderbundle did not load');
    }
    final vertex = library['CadLineVertex'];
    final fragment = library['CadLineFragment'];
    if (vertex == null || fragment == null) {
      throw StateError('cad.shaderbundle is missing a stage');
    }

    // The unit quad, as a triangle strip: (endpoint, side).
    final corners = Float32List.fromList(<double>[
      0, -1, //
      0, 1, //
      1, -1, //
      1, 1, //
    ]);

    final context = gpu.gpuContext;
    final cornerBuffer =
        context.createDeviceBufferWithCopy(ByteData.sublistView(corners));
    final segmentBuffer =
        context.createDeviceBufferWithCopy(ByteData.sublistView(segments.data));

    // Two slots: the quad steps per vertex, the segment steps per instance.
    // This is the layout the whole approach rests on — the geometry is
    // uploaded once as instance data and the four corners are shared by every
    // segment in the drawing.
    final layout = gpu.VertexLayout(buffers: <gpu.VertexBuffer>[
      const gpu.VertexBuffer(
        strideInBytes: 8,
        attributes: <gpu.VertexAttribute>[
          gpu.VertexAttribute(name: 'corner', format: gpu.VertexFormat.float32x2),
        ],
      ),
      const gpu.VertexBuffer(
        strideInBytes: kFloatsPerSegment * 4,
        stepMode: gpu.VertexStepMode.instance,
        attributes: <gpu.VertexAttribute>[
          gpu.VertexAttribute(name: 'p0', format: gpu.VertexFormat.float32x2),
          gpu.VertexAttribute(
              name: 'p1', format: gpu.VertexFormat.float32x2, offsetInBytes: 8),
          gpu.VertexAttribute(
              name: 'half_width',
              format: gpu.VertexFormat.float32,
              offsetInBytes: 16),
          gpu.VertexAttribute(
              name: 'color',
              format: gpu.VertexFormat.float32x4,
              offsetInBytes: 20),
        ],
      ),
    ]);

    final pipeline =
        context.createRenderPipeline(vertex, fragment, vertexLayout: layout);

    return GpuLineRenderer._(
      segments,
      pipeline,
      vertex,
      cornerBuffer,
      segmentBuffer,
      context.createHostBuffer(),
    );
  }

  final GpuSegments _segments;
  final gpu.RenderPipeline _pipeline;
  final gpu.Shader _vertexShader;
  final gpu.DeviceBuffer _cornerBuffer;
  final gpu.DeviceBuffer _segmentBuffer;
  final gpu.HostBuffer _hostBuffer;

  gpu.GpuImageSurface? _surface;
  int _surfaceWidth = 0;
  int _surfaceHeight = 0;

  /// Frames rendered. Read by the rig to prove the arm drew anything.
  int frames = 0;

  int get segmentCount => _segments.count;
  int get bufferBytes => _segments.byteLength;

  /// Renders one frame and returns the image to composite.
  ///
  /// **The only per-frame CPU work in this method is the matrix**: sixteen
  /// floats, plus the two that carry the viewport. Nothing here is O(entity).
  ui.Image? render(ViewportTransform camera, Size viewport, double dpr) {
    final widthPx = (viewport.width * dpr).round();
    final heightPx = (viewport.height * dpr).round();
    if (widthPx <= 0 || heightPx <= 0) return null;

    if (_surface == null ||
        _surfaceWidth != widthPx ||
        _surfaceHeight != heightPx) {
      _surface = _createSurface(widthPx, heightPx);
      _surfaceWidth = widthPx;
      _surfaceHeight = heightPx;
    }
    final surface = _surface!;

    // `GpuImageSurface` always vends a frame; the nullable result on the
    // `GpuSurface` interface exists for swapchain destinations that can skip.
    final frame = surface.acquireNextFrame();

    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final pass = commandBuffer.createRenderPass(
      gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(
          texture: frame.colorTexture,
          clearValue: vm.Vector4(1, 1, 1, 1),
        ),
      ),
    );

    pass.bindPipeline(_pipeline);
    pass.setPrimitiveType(gpu.PrimitiveType.triangleStrip);
    pass.setColorBlendEnable(true);
    pass.bindVertexBuffer(
        gpu.BufferView(_cornerBuffer,
            offsetInBytes: 0, lengthInBytes: _cornerBuffer.sizeInBytes),
        slot: 0);
    pass.bindVertexBuffer(
        gpu.BufferView(_segmentBuffer,
            offsetInBytes: 0, lengthInBytes: _segmentBuffer.sizeInBytes),
        slot: 1);
    pass.bindUniform(
      _vertexShader.getUniformSlot('FrameInfo'),
      _hostBuffer.emplace(_frameInfo(camera, widthPx, heightPx, dpr)),
    );
    pass.draw(4, instanceCount: _segments.count);

    frame.present(commandBuffer);
    commandBuffer.submit();
    frames++;
    return surface.currentImage;
  }

  /// Builds the presentable surface, choosing a format it will actually take.
  ///
  /// **`createImageSurface`'s own default argument does not work, and finding
  /// that out cost the first smoke run.** `createImageSurface` falls back to
  /// `GpuContext.defaultColorFormat` when no format is given, and on this
  /// macOS Metal context that getter returns **`PixelFormat.unknown`** -- the
  /// value the enum documents as "an invalid or unspecified format ... never
  /// the format of a real texture". The surface then throws
  /// `Unsupported GpuSurface pixel format`. So the parameter is optional in
  /// the signature and mandatory in fact. The candidates are tried in order
  /// and the one that takes is printed, so the note records a measured fact
  /// rather than a guess.
  static gpu.GpuImageSurface _createSurface(int widthPx, int heightPx) {
    const candidates = <gpu.PixelFormat>[
      gpu.PixelFormat.r8g8b8a8UNormInt,
      gpu.PixelFormat.b8g8r8a8UNormInt,
      gpu.PixelFormat.r8g8b8a8UNormIntSRGB,
      gpu.PixelFormat.b8g8r8a8UNormIntSRGB,
    ];
    Object? lastError;
    for (final format in candidates) {
      try {
        final surface =
            gpu.gpuContext.createImageSurface(widthPx, heightPx, format: format);
        if (!_reportedFormat) {
          _reportedFormat = true;
          print('GSPIKE surface format: $format '
              '(context default was ${gpu.gpuContext.defaultColorFormat})');
        }
        return surface;
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('no GpuSurface pixel format was accepted; last error: '
        '$lastError');
  }

  static bool _reportedFormat = false;

  /// The uniform block: `mat4 mvp` then `vec2 half_viewport`, std140.
  ///
  /// `mvp` takes a point in the buffer's space (the collection camera's
  /// screen space) all the way to normalized device coordinates under the
  /// camera the frame is being drawn with.
  ByteData _frameInfo(
      ViewportTransform camera, int widthPx, int heightPx, double dpr) {
    final fitInverse = _inverse(_segments.collectionCamera.worldToScreenMatrix);
    final toScreen = _compose(camera.worldToScreenMatrix, fitInverse);

    // Logical screen -> device pixels -> NDC. y is already down in screen
    // space and NDC has y up, so the y row is negated.
    final sx = 2 * dpr / widthPx;
    final sy = -2 * dpr / heightPx;

    final data = ByteData(80);
    void f(int index, double value) =>
        data.setFloat32(index * 4, value, Endian.host);

    // Column-major, as GLSL wants it.
    f(0, toScreen.a * sx);
    f(1, toScreen.b * sy);
    f(2, 0);
    f(3, 0);
    f(4, toScreen.c * sx);
    f(5, toScreen.d * sy);
    f(6, 0);
    f(7, 0);
    f(8, 0);
    f(9, 0);
    f(10, 1);
    f(11, 0);
    f(12, toScreen.e * sx - 1);
    f(13, toScreen.f * sy + 1);
    f(14, 0);
    f(15, 1);
    f(16, widthPx / 2);
    f(17, heightPx / 2);
    f(18, 0);
    f(19, 0);
    return data;
  }

  static Transform2 _inverse(Transform2 t) => t.invert();

  /// `outer ∘ inner`.
  static Transform2 _compose(Transform2 outer, Transform2 inner) => Transform2(
        outer.a * inner.a + outer.c * inner.b,
        outer.b * inner.a + outer.d * inner.b,
        outer.a * inner.c + outer.c * inner.d,
        outer.b * inner.c + outer.d * inner.d,
        outer.a * inner.e + outer.c * inner.f + outer.e,
        outer.b * inner.e + outer.d * inner.f + outer.f,
      );
}

/// Renders and composites the GPU arm, inside the frame that asked for it.
///
/// **The render happens in `paint`, not in a callback that schedules another
/// frame.** A two-frame arrangement would put the GPU submit in one frame's
/// numbers and the composite in the next, and neither figure would be the
/// cost of a gesture frame. Here `FrameTiming.buildDuration` covers the
/// uniform write and the submit, and `rasterDuration` covers the composite --
/// the same split every other arm in this harness is read with.
class GpuArmPainter extends CustomPainter {
  GpuArmPainter({
    required this.renderer,
    required this.camera,
    required this.devicePixelRatio,
  }) : super(repaint: camera);

  final GpuLineRenderer renderer;
  final CameraController camera;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final image = renderer.render(camera.value, size, devicePixelRatio);
    if (image == null) return;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(GpuArmPainter oldDelegate) =>
      oldDelegate.renderer != renderer ||
      oldDelegate.camera != camera ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}

/// The GPU arm as a widget: one `CustomPaint` over a repaint boundary.
class GpuArmView extends StatelessWidget {
  const GpuArmView({
    super.key,
    required this.renderer,
    required this.camera,
  });

  final GpuLineRenderer renderer;
  final CameraController camera;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: GpuArmPainter(
            renderer: renderer,
            camera: camera,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      );
}
