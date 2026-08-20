import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/differential.dart';
import 'support/spy_canvas.dart';

const ResolvedStyle _anyStyle = ResolvedStyle(
  argb: 0xFFFF0000,
  lineweightHundredths: 25,
  linetype: ReservedHandles.continuousLinetype,
  linetypeScale: 1.0,
);

const TextStyleRecord _standard =
    TextStyleRecord(handle: Handle(11), name: 'Standard', fontFamily: 'Roboto');

const ResolvedStyle _resolved = ResolvedStyle(
  argb: 0xFF00FFAA,
  lineweightHundredths: 18,
  linetype: ReservedHandles.continuousLinetype,
  linetypeScale: 1.0,
);

Vector2 _v(double x, double y) => Vector2(x, y);

void main() {
  group('RecordingDrawSink', () {
    test('captures ops in order with residual-local points', () {
      final sink = RecordingDrawSink();
      final residual = Transform2.translation(3, 4);

      sink
        ..beginResidual(residual)
        ..polyline(Float64List.fromList([0, 0, 1, 1]), 2, _anyStyle,
            closed: false)
        ..endResidual();

      expect(sink.ops, [
        BeginResidualOp(residual),
        PolylineOp(const [0.0, 0.0, 1.0, 1.0], _anyStyle, closed: false),
        const EndResidualOp(),
      ]);
    });

    test('polyline copies the caller buffer', () {
      // The painter reuses one scratch buffer per depth, so a sink that
      // retained the caller's list would record the same (last) geometry for
      // every entity and the differential oracle would compare two identical
      // wrong answers.
      final sink = RecordingDrawSink();
      final buffer = Float64List.fromList([0, 0, 1, 1]);
      sink.polyline(buffer, 2, _anyStyle, closed: false);
      buffer[0] = 99;
      expect((sink.ops.single as PolylineOp).points.first, 0.0);
    });

    test('polyline reads count points, not the whole buffer', () {
      // The painter's scratch buffer is sized for the largest entity it has
      // seen, so all but one call hands over a buffer with stale tail data.
      final sink = RecordingDrawSink();
      final buffer = Float64List.fromList([0, 0, 1, 1, 77, 77, 88, 88]);
      sink.polyline(buffer, 2, _anyStyle, closed: false);
      expect((sink.ops.single as PolylineOp).points, [0.0, 0.0, 1.0, 1.0]);
    });

    test('ops compare by value, which is what the oracle rests on', () {
      const other = ResolvedStyle(
        argb: 0xFF00FF00,
        lineweightHundredths: 25,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
      );

      expect(PolylineOp(const [0.0, 1.0], _anyStyle, closed: false),
          PolylineOp(const [0.0, 1.0], _anyStyle, closed: false));
      expect(PolylineOp(const [0.0, 1.0], _anyStyle, closed: false).hashCode,
          PolylineOp(const [0.0, 1.0], _anyStyle, closed: false).hashCode);
      expect(PolylineOp(const [0.0, 1.0], _anyStyle, closed: false),
          isNot(PolylineOp(const [0.0, 1.0], _anyStyle, closed: true)),
          reason: 'a closed polyline draws one more segment');
      expect(PolylineOp(const [0.0, 1.0], _anyStyle, closed: false),
          isNot(PolylineOp(const [0.0, 1.0], other, closed: false)),
          reason: 'the same geometry in another colour is another op');
      expect(PolylineOp(const [0.0, 1.0], _anyStyle, closed: false),
          isNot(PolylineOp(const [0.0, 2.0], _anyStyle, closed: false)));
      expect(const PointOp(1, 2, _anyStyle), const PointOp(1, 2, _anyStyle));
      expect(const PointOp(1, 2, _anyStyle),
          isNot(const PointOp(2, 1, _anyStyle)));
      expect(const CircleOp(0, 0, 5, _anyStyle),
          isNot(const CircleOp(0, 0, 6, _anyStyle)));
      expect(const ArcOp(0, 0, 5, 0, 1, _anyStyle),
          isNot(const ArcOp(0, 0, 5, 0, 2, _anyStyle)));
      expect(BeginResidualOp(Transform2.translation(1, 2)),
          BeginResidualOp(Transform2.translation(1, 2)));
      expect(BeginResidualOp(Transform2.translation(1, 2)),
          isNot(BeginResidualOp(Transform2.translation(1, 3))));
    });

    test('a text op records its string, style handle and resolved style', () {
      final sink = RecordingDrawSink()
        ..beginResidual(Transform2.translation(10, 20))
        ..text('WC', const Handle(7), _resolved)
        ..endResidual();
      expect(sink.ops[1], TextOp('WC', const Handle(7), _resolved));
    });

    test('text ops compare by value over all three fields', () {
      // Each field guards its own mutation: dropping any one of the three
      // from `==`/`hashCode` would let a wrong TextOp compare equal to a
      // right one and this test would stop catching it.
      expect(const TextOp('WC', Handle(7), _resolved),
          const TextOp('WC', Handle(7), _resolved));
      expect(const TextOp('WC', Handle(7), _resolved).hashCode,
          const TextOp('WC', Handle(7), _resolved).hashCode);
      expect(const TextOp('WC', Handle(7), _resolved),
          isNot(const TextOp('XX', Handle(7), _resolved)),
          reason: 'different text is a different op');
      expect(const TextOp('WC', Handle(7), _resolved),
          isNot(const TextOp('WC', Handle(8), _resolved)),
          reason: 'a different style handle is a different op');
      expect(const TextOp('WC', Handle(7), _resolved),
          isNot(const TextOp('WC', Handle(7), _anyStyle)),
          reason: 'a different resolved style is a different op');
    });
  });

  group('NullDrawSink', () {
    test('counts every op and keeps nothing', () {
      final sink = NullDrawSink()
        ..beginResidual(Transform2.identity())
        ..point(1, 2, _anyStyle)
        ..polyline(Float64List.fromList([0, 0, 1, 1]), 2, _anyStyle,
            closed: false)
        ..circle(0, 0, 5, _anyStyle)
        ..arc(0, 0, 5, 0, 1, _anyStyle)
        ..text('WC', const Handle(7), _resolved)
        ..endResidual();
      expect(sink.opCount, 7);
    });
  });

  group('flatten', () {
    test('turns a text op into an origin and two unit images', () {
      // The residual here is not a pure scale on purpose: a fixture that only
      // scales cannot tell a right implementation from one that swapped the
      // +x and +y unit images, because a symmetric scale sends both the same
      // way as sending them straight. Rotation (and shear, more generally)
      // breaks that symmetry.
      final items = flatten(<DrawOp>[
        BeginResidualOp(const Transform2(0, 2, -2, 0, 100, 200)),
        const TextOp('WC', Handle(7), _resolved),
        const EndResidualOp(),
      ]);
      expect(items.single.kind, 'text:WC');
      expect(items.single.style, _resolved);
      expect(items.single.points[0], _v(100, 200));
      expect(items.single.points[1], _v(100, 202));
      expect(items.single.points[2], _v(98, 200));
    });

    test('flatten with a pure scale, as a sanity check on the brief', () {
      final items = flatten(<DrawOp>[
        BeginResidualOp(const Transform2(2, 0, 0, 2, 100, 200)),
        const TextOp('WC', Handle(7), _resolved),
        const EndResidualOp(),
      ]);
      expect(items.single.kind, 'text:WC');
      expect(items.single.points[0], _v(100, 200));
      expect(items.single.points[1], _v(102, 200));
      expect(items.single.points[2], _v(100, 202));
    });
  });

  group('CanvasDrawSink', () {
    late SpyCanvas canvas;
    late CanvasDrawSink sink;

    setUp(() {
      canvas = SpyCanvas();
      // 96 dpi / 25.4 mm — one paper millimetre is 3.78 logical pixels.
      sink = CanvasDrawSink(
          canvas: canvas,
          pixelsPerPaperMm: 4.0,
          measurer: FlutterTextMeasurer(),
          textStyleOf: (Handle handle) => _standard);
    });

    test('beginResidual pushes the affine as a column-major 4x4', () {
      // Canvas.transform takes Matrix4 storage order. Row-major here would
      // transpose every residual and shear the whole drawing.
      sink.beginResidual(const Transform2(2, 3, 4, 5, 6, 7));
      // The push is deferred to the first primitive drawn under the residual,
      // so a residual under which nothing is drawn never touches canvas
      // state. A point does *not* force it -- it applies the residual to its
      // own coordinates instead of pushing it -- so a circle is the simplest
      // primitive that does.
      sink.circle(0, 0, 1, _anyStyle);

      expect(canvas.named('save'), hasLength(1));
      final matrix = canvas.named('transform').single.args.single;
      expect(matrix, isA<Float64List>());
      expect(matrix, <double>[
        2, 3, 0, 0, //
        4, 5, 0, 0, //
        0, 0, 1, 0, //
        6, 7, 0, 1, //
      ]);
    });

    test('endResidual restores the canvas', () {
      sink
        ..beginResidual(Transform2.translation(3, 4))
        // Forces the deferred push, same as above -- a point would not, so a
        // circle is used instead; endResidual only restores what was
        // actually pushed.
        ..circle(0, 0, 1, _anyStyle)
        ..endResidual();
      expect(canvas.named('restore'), hasLength(1));
    });

    test('stroke width is a paper quantity, divided out of the residual', () {
      // 25/100 mm at 4 px/mm is 1 logical pixel on paper. Inside a residual
      // that scales by 2, Paint.strokeWidth is measured in the scaled units,
      // so it must be halved to come out one pixel wide on screen.
      sink
        ..beginResidual(Transform2.scale(2, 2))
        ..polyline(Float64List.fromList([0, 0, 1, 1]), 2, _anyStyle,
            closed: false);

      final call = canvas.named('drawPath').single;
      expect(call.strokeWidth, closeTo(0.5, 1e-12));
      expect(call.paintingStyle, PaintingStyle.stroke);
      expect(call.color, const Color(0xFFFF0000));
    });

    test('a width that scales away becomes a hairline, not a negative', () {
      const zero = ResolvedStyle(
        argb: 0xFFFF0000,
        lineweightHundredths: 0,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
      );
      sink.polyline(Float64List.fromList([0, 0, 1, 1]), 2, zero, closed: false);
      expect(canvas.named('drawPath').single.strokeWidth, 0.0,
          reason:
              '0 is Skia hairline: one device pixel whatever the transform');
    });

    test('a degenerate residual does not produce a NaN width', () {
      sink
        ..beginResidual(Transform2.scale(0, 0))
        ..polyline(Float64List.fromList([0, 0, 1, 1]), 2, _anyStyle,
            closed: false);
      final w = canvas.named('drawPath').single.strokeWidth!;
      expect(w.isFinite, isTrue);
      expect(w, greaterThanOrEqualTo(0));
    });

    test('polyline draws the points it was given, and closes when asked', () {
      sink.polyline(
          Float64List.fromList([0, 0, 10, 0, 10, 5, 99, 99]), 3, _anyStyle,
          closed: true);

      final path = canvas.named('drawPath').single.args.first as Path;
      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 10, 5),
          reason: 'the fourth point is past `count` and must not be drawn');
      expect(path.computeMetrics().single.isClosed, isTrue);
    });

    test('circle and arc reach the canvas as circles and arcs', () {
      sink
        ..circle(1, 2, 5, _anyStyle)
        ..arc(1, 2, 5, 0.5, 1.5, _anyStyle);

      expect(canvas.named('drawCircle'), hasLength(1));
      final arc = canvas.named('drawArc').single;
      expect(
          arc.args[0], Rect.fromCircle(center: const Offset(1, 2), radius: 5));
      expect(arc.args[1], 0.5);
      expect(arc.args[2], 1.5);
      expect(arc.args[3], isFalse, reason: 'an arc is not a pie slice');
    });

    test(
        'point reaches the canvas as an axis-aligned rect in screen space, '
        'not a rotated cap', () {
      // The residual is not pushed onto the canvas for a point -- it is
      // folded into the coordinates before `drawRect`, in screen space -- so
      // the marker's shape does not rotate or shear with the residual. See
      // `point_shape_test.dart` for a rasterised check that this holds under
      // an actually rotated residual.
      sink
        ..beginResidual(const Transform2(2, 0, 0, 2, 10, 20))
        ..point(3, 4, _anyStyle);

      expect(canvas.named('save'), isEmpty,
          reason: 'a point never pushes the residual onto the canvas');
      final call = canvas.named('drawRect').single;
      final rect = call.args.first as Rect;
      // (3,4) under a *2 scale + (10,20) translate lands at (16,28); 25/100
      // mm at 4 px/mm is 1 device pixel, so half a pixel either side -- and
      // the residual's scale plays no part in the marker's own size, because
      // the width here is a device-pixel quantity, not a paper one
      // pre-divided by it.
      expect(rect, const Rect.fromLTRB(15.5, 27.5, 16.5, 28.5));
      expect(call.paintingStyle, PaintingStyle.fill);
      expect(call.color, const Color(0xFFFF0000));
    });
  });
}
