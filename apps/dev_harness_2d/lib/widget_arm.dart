// THROWAWAY SPIKE CODE. Branch `spike/widget-per-entity`, 2026-08-29.
//
// Answers one question and is then deleted: at floor-plan scale, what does
// one RenderObject per entity cost against the single `CustomPainter` walk
// `DraftCanvas` performs today?
//
// Nothing here is a proposal. It exists to produce a number.
//
// ignore_for_file: avoid_print -- the diagnostic in `_paintChildren` is what
// proves the fixture is not degenerate, and printing it is the point.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// Which arm of the spike a widget layer is running.
enum WidgetArmMode {
  /// The widget approach's **ceiling**: the whole child set sits inside a
  /// `RepaintBoundary` and the camera is a `Transform` above it. A camera
  /// change touches one transform layer; not one child repaints, and the
  /// retained picture is re-rasterised by Impeller at the new transform so it
  /// stays sharp.
  ///
  /// **It draws the wrong picture.** `strokeWidth` is baked into the retained
  /// picture in recorded space, so line widths scale with zoom. A 0.35 mm line
  /// is 0.35 mm on paper only at the recording camera.
  transformed,

  /// The **honest** arm: screen-space lineweight, recomputed per frame.
  ///
  /// The camera transform is applied inside `paint`, so a camera change
  /// repaints the layer and therefore every child, and each child divides its
  /// stroke width by the current scale to land at the right screen width.
  correctLineweight,
}

/// One drawable primitive, in the coordinates the recording camera produced.
///
/// **Recorded at the measurement camera, not at world scale**, so the op count
/// matches what arm A's painter emits per frame. The consequence is stated
/// where it matters: dash spans were split at the recording scale and are
/// **never re-split** by either widget arm, so both arms draw fewer, longer
/// dashes than they should once the camera moves. That is a cheat in the
/// widget arms' favour and it is deliberate -- this is a steelman, and a
/// negative result under a cheat is worth more than one without.
class ArmPrimitive {
  ArmPrimitive(this.op, this.bounds);

  final DrawOp op;
  final Rect bounds;
}

/// Runs the painter once into a [RecordingDrawSink] and turns each stroke or
/// fill op into an [ArmPrimitive], **with the residual transform baked into
/// the coordinates**.
///
/// **Baking the residual is not optional and the first version of this
/// function got it wrong.** `DraftPainter` rebases the origin so that a
/// drawing far from `(0,0)` does not lose precision in float32, and it emits
/// the remainder as a [BeginResidualOp] that `CanvasDrawSink` pushes onto the
/// canvas. Every geometry op between a begin and an end is therefore in
/// **residual-local** coordinates, not screen coordinates. Dropping the
/// residual and keeping the geometry produced 399,000 primitives whose bounds
/// all fell outside the viewport, so the layer's cull rejected every one of
/// them and all six widget phases measured an empty screen. The `painted=0`
/// warning is what caught it.
///
/// A residual does **not** nest: `CanvasDrawSink.beginResidual` assigns rather
/// than pushes, so the current transform is the last begin until its end.
///
/// **A circle or arc under an anisotropic residual is approximated**, its
/// radius scaled by `scaleMagnitude`, where the painter would draw an ellipse.
/// The corpus's `nonUniformFraction` is 0.2, so this affects a fifth of the
/// instances. It is left approximate on purpose: this measures *cost*, and an
/// approximated circle is the same primitive doing the same class of GPU work.
/// It would not be acceptable in anything that had to match pixels.
///
/// Text ops are dropped -- a paragraph per child is a different measurement --
/// and the counts are returned so the caller can report what the arms do
/// **not** draw rather than let it go unmentioned.
({List<ArmPrimitive> primitives, int droppedText, int residuals})
    extractPrimitives(
  DraftPainter painter,
  ViewportTransform camera,
  Size viewport,
) {
  final sink = RecordingDrawSink();
  painter.paint(sink, camera, viewport);
  final out = <ArmPrimitive>[];
  var droppedText = 0;
  var residuals = 0;
  Transform2? current;
  for (final op in sink.ops) {
    switch (op) {
      case TextOp():
        droppedText++;
      case BeginResidualOp(:final residual):
        current = residual;
        residuals++;
      case EndResidualOp():
        current = null;
      default:
        final baked = _bake(op, current);
        if (baked == null) continue;
        final b = _boundsOf(baked);
        if (b != null) out.add(ArmPrimitive(baked, b));
    }
  }
  return (primitives: out, droppedText: droppedText, residuals: residuals);
}

/// [op] with [t] applied to its coordinates, or [op] itself when [t] is null.
DrawOp? _bake(DrawOp op, Transform2? t) {
  if (t == null) return op;
  final scale = t.scaleMagnitude;
  Vector2 at(double x, double y) => t.transformPoint(Vector2(x, y));
  switch (op) {
    case PointOp(:final x, :final y, :final style):
      final p = at(x, y);
      return PointOp(p.x, p.y, style);
    case PolylineOp(:final points, :final style, :final closed):
      return PolylineOp(_bakePoints(points, t), style, closed: closed);
    case CircleOp(:final cx, :final cy, :final r, :final style):
      final c = at(cx, cy);
      return CircleOp(c.x, c.y, r * scale, style);
    case FillCircleOp(:final cx, :final cy, :final r, :final style):
      final c = at(cx, cy);
      return FillCircleOp(c.x, c.y, r * scale, style);
    case ArcOp(
        :final cx,
        :final cy,
        :final r,
        :final start,
        :final sweep,
        :final style
      ):
      final c = at(cx, cy);
      // The start angle is rotated by the residual's own rotation. A mirrored
      // residual would also reverse the sweep; the corpus has a mirrored
      // fraction, and this does not correct for it, which is one more way an
      // arc is approximate here. See the doc comment above.
      final rotation = math.atan2(t.b, t.a);
      return ArcOp(c.x, c.y, r * scale, start + rotation, sweep, style);
    case FillPolygonOp(:final points, :final triangles, :final style):
      return FillPolygonOp(_bakePoints(points, t), triangles, style);
    default:
      return null;
  }
}

List<double> _bakePoints(List<double> points, Transform2 t) {
  final out = List<double>.filled(points.length, 0);
  for (var i = 0; i + 1 < points.length; i += 2) {
    final p = t.transformPoint(Vector2(points[i], points[i + 1]));
    out[i] = p.x;
    out[i + 1] = p.y;
  }
  return out;
}

Rect? _boundsOf(DrawOp op) => switch (op) {
      PointOp(:final x, :final y) => Rect.fromLTWH(x, y, 0, 0),
      CircleOp(:final cx, :final cy, :final r) ||
      FillCircleOp(:final cx, :final cy, :final r) ||
      ArcOp(:final cx, :final cy, :final r) =>
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
      PolylineOp(:final points) => _pointBounds(points),
      FillPolygonOp(:final points) => _pointBounds(points),
      _ => null,
    };

Rect? _pointBounds(List<double> points) {
  if (points.length < 2) return null;
  var minX = points[0], maxX = points[0], minY = points[1], maxY = points[1];
  for (var i = 2; i + 1 < points.length; i += 2) {
    final x = points[i], y = points[i + 1];
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// The camera the widget arms read, as a scale and an offset over the
/// recorded space.
///
/// A `ChangeNotifier` rather than a plain field so arm C's layer can mark
/// itself for paint the way a real implementation would, instead of the rig
/// reaching in and doing it -- the notification path is part of what is being
/// priced.
class ArmCamera extends ChangeNotifier {
  double scale = 1.0;
  Offset offset = Offset.zero;

  void set({required double scale, required Offset offset}) {
    this.scale = scale;
    this.offset = offset;
    notifyListeners();
  }

  Matrix4 get matrix => Matrix4.identity()
    ..translateByDouble(offset.dx, offset.dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);
}

/// One entity, one widget, one element, one render object. The whole point.
class EntityWidget extends LeafRenderObjectWidget {
  const EntityWidget({
    super.key,
    required this.primitive,
    required this.camera,
    required this.mode,
    required this.pixelsPerPaperMm,
    required this.lineweightScale,
  });

  final ArmPrimitive primitive;
  final ArmCamera camera;
  final WidgetArmMode mode;
  final double pixelsPerPaperMm;
  final double lineweightScale;

  @override
  RenderEntity createRenderObject(BuildContext context) => RenderEntity(
        primitive: primitive,
        camera: camera,
        mode: mode,
        pixelsPerPaperMm: pixelsPerPaperMm,
        lineweightScale: lineweightScale,
      );
}

/// Paints exactly one primitive.
///
/// The `Path` and `Vertices` are built once and cached, so no arm pays
/// tessellation per frame. That is the strongest form of the widget approach
/// and it is on purpose.
class RenderEntity extends RenderBox {
  RenderEntity({
    required this.primitive,
    required this.camera,
    required this.mode,
    required this.pixelsPerPaperMm,
    required this.lineweightScale,
  });

  final ArmPrimitive primitive;
  final ArmCamera camera;
  final WidgetArmMode mode;
  final double pixelsPerPaperMm;
  final double lineweightScale;

  final Paint _paint = Paint();
  Path? _path;
  ui.Vertices? _vertices;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.smallest;

  /// The stroke width to hand `Paint`, in the space this child paints in.
  ///
  /// Arm C divides by the camera scale so the line lands at the paper width on
  /// screen -- which is the whole reason it has to repaint when the camera
  /// moves. Arm B does not, which is why it does not have to.
  double _strokeWidth(ResolvedStyle style) {
    final devicePx =
        style.lineweightHundredths / 100.0 * pixelsPerPaperMm * lineweightScale;
    final w = mode == WidgetArmMode.correctLineweight
        ? devicePx / (camera.scale == 0 ? 1.0 : camera.scale)
        : devicePx;
    return w.isFinite && w > 0 ? w : 0.0;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final op = primitive.op;
    switch (op) {
      case PolylineOp(:final points, :final style, :final closed):
        _paint
          ..color = Color(style.argb)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth(style);
        canvas.drawPath(_path ??= _buildPath(points, closed), _paint);
      case CircleOp(:final cx, :final cy, :final r, :final style):
        _paint
          ..color = Color(style.argb)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth(style);
        canvas.drawCircle(Offset(cx, cy), r, _paint);
      case ArcOp(
          :final cx,
          :final cy,
          :final r,
          :final start,
          :final sweep,
          :final style
        ):
        _paint
          ..color = Color(style.argb)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth(style);
        canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
            start, sweep, false, _paint);
      case PointOp(:final x, :final y, :final style):
        _paint
          ..color = Color(style.argb)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), _strokeWidth(style) / 2, _paint);
      case FillCircleOp(:final cx, :final cy, :final r, :final style):
        _paint
          ..color = Color(style.argb)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy), r, _paint);
      case FillPolygonOp(:final points, :final triangles, :final style):
        _paint
          ..color = Color(style.argb)
          ..style = PaintingStyle.fill;
        canvas.drawVertices(_vertices ??= _buildVertices(points, triangles),
            BlendMode.srcOver, _paint);
      default:
        break;
    }
  }

  static Path _buildPath(List<double> points, bool closed) {
    final path = Path();
    if (points.length < 2) return path;
    path.moveTo(points[0], points[1]);
    for (var i = 2; i + 1 < points.length; i += 2) {
      path.lineTo(points[i], points[i + 1]);
    }
    if (closed) path.close();
    return path;
  }

  static ui.Vertices _buildVertices(List<double> points, List<int> triangles) {
    final xy = Float32List(points.length);
    for (var i = 0; i < points.length; i++) {
      xy[i] = points[i].toDouble();
    }
    final idx = Uint16List(triangles.length);
    for (var i = 0; i < triangles.length; i++) {
      idx[i] = triangles[i];
    }
    return ui.Vertices.raw(ui.VertexMode.triangles, xy, indices: idx);
  }

  @override
  void dispose() {
    _vertices?.dispose();
    super.dispose();
  }
}

/// The parent of every [EntityWidget].
class WidgetEntityLayer extends MultiChildRenderObjectWidget {
  WidgetEntityLayer({
    super.key,
    required this.camera,
    required this.mode,
    required List<ArmPrimitive> primitives,
    required double pixelsPerPaperMm,
    required double lineweightScale,
  }) : super(
          children: [
            for (final p in primitives)
              EntityWidget(
                primitive: p,
                camera: camera,
                mode: mode,
                pixelsPerPaperMm: pixelsPerPaperMm,
                lineweightScale: lineweightScale,
              ),
          ],
        );

  final ArmCamera camera;
  final WidgetArmMode mode;

  @override
  RenderEntityLayer createRenderObject(BuildContext context) =>
      RenderEntityLayer(camera: camera, mode: mode);
}

class _EntityParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays out nothing and paints its children, culled by their recorded bounds.
///
/// **Layout is a no-op on purpose.** A CAD entity's position is a coordinate,
/// not the result of a constraint, so making the children participate in
/// Flutter's layout would price an algorithm a real implementation would also
/// skip. Every child is `sizedByParent` with the smallest constraints, so
/// layout runs once and never again -- a camera change marks paint, not
/// layout.
///
/// **Culling is by the child's recorded bounds** mapped through the current
/// camera, which is what a competent widget implementation would do and is
/// again favourable to these arms.
class RenderEntityLayer extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EntityParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EntityParentData> {
  RenderEntityLayer({required this.camera, required this.mode});

  final ArmCamera camera;
  final WidgetArmMode mode;

  /// How many children the last paint actually drew, after culling. Read by
  /// the rig: an arm that culls everything is measuring nothing.
  int lastPainted = 0;

  void _onCamera() => markNeedsPaint();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // Only arm C reacts. Arm B's camera lives in a `Transform` above a
    // `RepaintBoundary`, so this layer must **not** repaint when it moves --
    // that is precisely the property being measured.
    if (mode == WidgetArmMode.correctLineweight) {
      camera.addListener(_onCamera);
    }
  }

  @override
  void detach() {
    if (mode == WidgetArmMode.correctLineweight) {
      camera.removeListener(_onCamera);
    }
    super.detach();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _EntityParentData) {
      child.parentData = _EntityParentData();
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  @override
  void performLayout() {
    var child = firstChild;
    while (child != null) {
      child.layout(const BoxConstraints.tightFor(width: 0, height: 0));
      child = childAfter(child);
    }
  }

  /// Set once per layer so the diagnostic below prints on the first paint and
  /// never again. Throwaway: it exists to find why the cull rejected every
  /// child, and goes when that is understood.
  bool _reported = false;

  void _paintChildren(PaintingContext context, Offset offset) {
    final visible = offset & size;
    if (!_reported) {
      _reported = true;
      final first = firstChild;
      final b = first is RenderEntity ? first.primitive.bounds : null;
      String r(Rect? x) => x == null
          ? 'null'
          : '[${x.left.toStringAsFixed(1)},${x.top.toStringAsFixed(1)} '
              '${x.right.toStringAsFixed(1)},${x.bottom.toStringAsFixed(1)}]';
      print('WSPIKE DIAG ${mode.name}: visible=${r(visible)} '
          'scale=${camera.scale.toStringAsFixed(3)} '
          'offset=${camera.offset.dx.toStringAsFixed(1)},'
          '${camera.offset.dy.toStringAsFixed(1)} '
          'firstChildBounds=${r(b)} childCount=$childCount');
    }
    var painted = 0;
    var child = firstChild;
    while (child != null) {
      if (child is RenderEntity) {
        final b = child.primitive.bounds;
        // The child paints in recorded space; arm C has already pushed the
        // camera transform, arm B's sits above the repaint boundary. Either
        // way the cull test is the recorded rect mapped by the same transform
        // the canvas is under.
        final mapped = mode == WidgetArmMode.correctLineweight
            ? Rect.fromLTRB(
                b.left * camera.scale + camera.offset.dx,
                b.top * camera.scale + camera.offset.dy,
                b.right * camera.scale + camera.offset.dx,
                b.bottom * camera.scale + camera.offset.dy,
              )
            : b;
        if (!mapped.inflate(2.0).overlaps(visible)) {
          child = childAfter(child);
          continue;
        }
      }
      context.paintChild(child, offset);
      painted++;
      child = childAfter(child);
    }
    lastPainted = painted;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (mode == WidgetArmMode.correctLineweight) {
      context.pushTransform(needsCompositing, offset, camera.matrix,
          (ctx, off) => _paintChildren(ctx, off));
    } else {
      _paintChildren(context, offset);
    }
  }

  @override
  bool hitTestSelf(Offset position) => false;
}
