import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const ResolvedStyle _anyStyle = ResolvedStyle(
  argb: 0xFFFF0000,
  lineweightHundredths: 25,
  linetype: ReservedHandles.continuousLinetype,
  linetypeScale: 1.0,
);

/// Records what reaches `dart:ui`.
///
/// `CanvasDrawSink` reuses one `Paint` across ops, so the paint is snapshotted
/// at call time; holding the reference would show every call the last colour.
class _SpyCanvas implements Canvas {
  final List<_Call> calls = <_Call>[];

  Iterable<_Call> named(String name) => calls.where((c) => c.name == name);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.positionalArguments;
    Paint? paint;
    for (final a in args) {
      if (a is Paint) paint = a;
    }
    calls.add(_Call(
      _nameOf(invocation.memberName),
      args,
      color: paint?.color,
      strokeWidth: paint?.strokeWidth,
      paintingStyle: paint?.style,
    ));
    return null;
  }
}

class _Call {
  _Call(this.name, this.args,
      {this.color, this.strokeWidth, this.paintingStyle});

  final String name;
  final List<Object?> args;
  final Color? color;
  final double? strokeWidth;
  final PaintingStyle? paintingStyle;
}

String _nameOf(Symbol s) {
  final text = s.toString(); // Symbol("drawPath")
  return text.substring(text.indexOf('"') + 1, text.lastIndexOf('"'));
}

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
        ..endResidual();
      expect(sink.opCount, 6);
    });
  });

  group('CanvasDrawSink', () {
    late _SpyCanvas canvas;
    late CanvasDrawSink sink;

    setUp(() {
      canvas = _SpyCanvas();
      // 96 dpi / 25.4 mm — one paper millimetre is 3.78 logical pixels.
      sink = CanvasDrawSink(canvas, pixelsPerPaperMm: 4.0);
    });

    test('beginResidual pushes the affine as a column-major 4x4', () {
      // Canvas.transform takes Matrix4 storage order. Row-major here would
      // transpose every residual and shear the whole drawing.
      sink.beginResidual(const Transform2(2, 3, 4, 5, 6, 7));

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

    test('point reaches the canvas as a point, not a zero-length path', () {
      // drawRawPoints over drawPoints: the latter needs a fresh List<Offset>
      // per call, and points are per-entity work on the frame path.
      sink.point(3, 4, _anyStyle);
      final call = canvas.named('drawRawPoints').single;
      expect(call.args.first, PointMode.points);
      expect(call.args[1], <double>[3, 4]);
    });
  });
}
