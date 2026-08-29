import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../draw_sink.dart';
import 'instance_record.dart';

/// Collects a document's stroked segments into one buffer, in walk order.
///
/// **This is a `DrawSink`, and that is deliberate.** `RecordingDrawSink`
/// equality is this project's primary correctness mechanism; a backend that
/// invented its own traversal would give it up. What changes is not the
/// interface but *when* it runs — on a rebuild, not on a frame.
///
/// **Walk order is the draw order and nothing may reorder it.** The buffer is
/// submitted in the order written, in one draw call, and that is the whole
/// reason this design needs no depth buffer. Sorting it — by handle, by colour,
/// by anything — reintroduces the defect `vertices_draw_sink.dart:41-57`
/// records.
class GeometryCollector implements DrawSink {
  GeometryCollector({
    required this.pixelsPerPaperMm,
    required this.devicePixelRatio,
    this.lineweightScale = 1.0,
  });

  final double pixelsPerPaperMm;
  final double devicePixelRatio;
  final double lineweightScale;

  /// **A minimum stroke width in device pixels.** Copied from
  /// `VerticesDrawSink.kMinStrokeDevicePixels` rather than shared, because that
  /// one is a private implementation detail of a sink this class does not use.
  /// If the two ever disagree the differential test in Task 8 goes red, which
  /// is the intended alarm.
  static const double kMinStrokeDevicePixels = 1.0;

  Float32List _buffer = Float32List(0);
  int _instances = 0;
  int _skipped = 0;
  Transform2 _residual = Transform2.identity();

  Float32List get data => _buffer.sublist(0, _instances * kFloatsPerInstance);
  int get instanceCount => _instances;

  /// Ops this plan does not draw yet — arcs, circles, fills, text, points.
  /// Counted rather than ignored so a corpus that needs Plan B through E is
  /// visible as a number instead of as a missing picture.
  int get skippedOps => _skipped;

  double _halfWidthFor(int lineweightHundredths) {
    final logical =
        lineweightHundredths / 100.0 * pixelsPerPaperMm * lineweightScale;
    final floor = kMinStrokeDevicePixels / devicePixelRatio;
    final w = logical.isFinite && logical > floor ? logical : floor;
    return w / 2;
  }

  void _emit(
      double x0, double y0, double x1, double y1, double half, int argb) {
    // Exactly the sink's own test: `_emitSegment` bails on zero length
    // (`vertices_draw_sink.dart:503-507`). A degenerate segment has no
    // direction and the shader would divide by zero building its normal.
    if (x0 == x1 && y0 == y1) return;
    _reserve(_instances + 1);
    writeStroke(_buffer, _instances,
        x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: argb);
    _instances++;
  }

  /// Doubling growth, mirroring `VerticesDrawSink._reserve`
  /// (`vertices_draw_sink.dart:511-521`). A `List<double>` grown via its
  /// `length` setter null-fills the new slots and throws for a non-nullable
  /// element type — confirmed by hand — so the buffer is a `Float32List`
  /// grown by copy, and `writeStroke` writes straight into it.
  void _reserve(int instances) {
    final needed = instances * kFloatsPerInstance;
    if (needed <= _buffer.length) return;
    var capacity = _buffer.isEmpty ? kFloatsPerInstance * 16 : _buffer.length;
    while (capacity < needed) {
      capacity *= 2;
    }
    final grown = Float32List(capacity);
    grown.setRange(0, _buffer.length, _buffer);
    _buffer = grown;
  }

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {
    _residual = residual;
  }

  @override
  void endResidual() {}

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
  void point(double x, double y, ResolvedStyle style) => _skipped++;

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      _skipped++;

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      _skipped++;

  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
          ResolvedStyle style) =>
      _skipped++;

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) =>
      _skipped++;

  @override
  void text(String text, Handle style, ResolvedStyle resolved) => _skipped++;
}
