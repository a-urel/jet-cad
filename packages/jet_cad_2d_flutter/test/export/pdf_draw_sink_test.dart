import 'dart:io' show zlib;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/export_fixture.dart';
import '../support/export_font.dart';
import '../support/pdf_tolerance.dart';

/// Spec 13 T-3 and T-3b: `PdfDrawSink`'s geometry, read back from the bytes
/// by the content reader (`export_testing.dart`, tested on its own in
/// `pdf_content_test.dart`).
///
/// - T-3: the export fixture painted at the page camera into a
///   `RecordingDrawSink(shadesDashes: false)`, so the dashes arrive as cut
///   spans as they will in the export. The ops are replayed into a
///   `PdfDrawSink` on a `PdfDocument(compress: false)`. Text ops are left
///   out: the fixture's default measurer gives text a singular residual, and
///   text is `pdf_draw_sink_text_test.dart`'s (T-5).
/// - T-3b: direct calls on the sink.
///
/// The named mutants are M-13b (sink level), M-13h, M-13i, M-13j, M-13k,
/// M-13y, M-13z and M-13ad.
void main() {
  const u = 72 / 25.4;

  group('T-3: the fixture replayed at the page camera', () {
    final f = exportFixture();
    final camera = pageCamera(f.page, u);
    final height = camera.size.height;
    late List<_Expected> expected;
    late PdfContent content;

    setUpAll(() async {
      final index = SpatialIndex(f.document);
      final recording = RecordingDrawSink();
      try {
        DraftPainter(
          document: f.document,
          index: index,
          resolver: DocumentStyleResolver(f.document, foreground: 0x000000),
          minTextCapPixels: 0,
        ).paint(recording, camera.camera, camera.size);
      } finally {
        index.dispose();
      }
      expected = _expectedPrimitives(recording.ops);
      content = await _render(camera.size.width, height, (sink) {
        for (final op in recording.ops) {
          _replay(op, sink);
        }
      });
    });

    /// [local] under [residual] carried to page space through the page
    /// set-up `[1 0 0 -1 0 H]`, from the recorded doubles alone.
    PdfXY toPage(double x, double y, Transform2? residual) {
      final s = residual == null
          ? Vector2(x, y)
          : residual.transformPoint(Vector2(x, y));
      return (x: s.x, y: height - s.y);
    }

    /// Page space back to the residual's local space.
    Vector2 toLocal(PdfXY p, Transform2? residual) {
      final s = Vector2(p.x, height - p.y);
      return residual == null ? s : residual.invert().transformPoint(s);
    }

    void expectNear(PdfXY actual, PdfXY wanted, double tol, String what) {
      expect((actual.x - wanted.x).abs(), lessThanOrEqualTo(tol),
          reason: '$what: x ${actual.x} vs ${wanted.x} (bound $tol)');
      expect((actual.y - wanted.y).abs(), lessThanOrEqualTo(tol),
          reason: '$what: y ${actual.y} vs ${wanted.y} (bound $tol)');
    }

    void expectStyle(PdfContentPath path, _Expected e) {
      final argb = e.style.argb;
      final rgb = [
        ((argb >> 16) & 0xFF) / 255,
        ((argb >> 8) & 0xFF) / 255,
        (argb & 0xFF) / 255,
      ];
      final alpha = ((argb >> 24) & 0xFF) / 255;
      final colour = path.strokes ? path.state.strokeRgb : path.state.fillRgb;
      for (var i = 0; i < 3; i++) {
        expect(colour[i], closeTo(rgb[i], kPdfRounding),
            reason: '${e.what}: colour channel $i');
      }
      expect(
        path.strokes ? path.state.strokeAlpha : path.state.fillAlpha,
        closeTo(alpha, kPdfRounding),
        reason: '${e.what}: alpha',
      );
      if (path.strokes) {
        // M-13b at the sink: lw / 100 · u in page units, whatever the
        // residual's scale.
        final width = e.style.lineweightHundredths / 100 * u;
        expect(
          path.deviceLineWidth,
          closeTo(width, pdfWidthTolerance(width, e.residual)),
          reason: '${e.what}: the stroke is lw / 100 · u wide on the page',
        );
      }
    }

    /// Every cubic of [sub] lies on the circle ([cx], [cy], [r]) of the local
    /// frame. The bound is the rounding carried back through the residual,
    /// plus the cubic's own `2.7e-4 · r`.
    void expectOnCircle(PdfContentSubpath sub, double cx, double cy, double r,
        Transform2? residual, String what) {
      var p0 = sub.start;
      for (final s in sub.segments) {
        expect(s.isCubic, isTrue, reason: '$what: only cubics');
        for (final t in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
          final p = _bezier(p0, s, t);
          final q = toLocal(p, residual);
          final page = pdfTolerance(q.x, q.y, residual,
                  pageHeight: height, operandsKnown: false) *
              math.sqrt2;
          final bound = page / _minStretch(residual) + 2.7e-4 * r;
          expect(
            ((q - Vector2(cx, cy)).length - r).abs(),
            lessThanOrEqualTo(bound),
            reason: '$what: the cubic at t $t is off its circle',
          );
        }
        p0 = s.to;
      }
    }

    test('one path per primitive, in order', () {
      expect(content.paths.length, expected.length,
          reason: 'paths ${content.paths.length}, primitives '
              '${expected.length}');
      expect(expected.whereType<_Expected>().map((e) => e.kind).toSet(),
          containsAll(['polyline', 'arc', 'circle', 'fillPolygon', 'point']),
          reason: 'the fixture reaches every primitive the painter emits');
    });

    test('the page set-up is cm [1 0 0 -1 0 H], J 0, j 0, 4 M', () {
      final ops = content.operators;
      expect(ops[0].name, 'cm');
      expect(
        [for (final v in ops[0].operands) (v as num).toDouble()],
        [1, 0, 0, -1, 0, closeTo(height, kPdfRounding)],
      );
      expect([
        ops[1].name,
        ops[1].operands
      ], [
        'J',
        [0]
      ]);
      expect([
        ops[2].name,
        ops[2].operands
      ], [
        'j',
        [0]
      ]);
      expect([
        ops[3].name,
        ops[3].operands
      ], [
        'M',
        [4]
      ]);
      expect(content.mediaBox[3], closeTo(height, kPdfRounding));
    });

    test(
        'every polyline and fill lands on its op\'s points through the '
        'residual and the page set-up', () {
      var checked = 0;
      for (var i = 0; i < expected.length; i++) {
        final e = expected[i];
        if (e.kind != 'polyline' && e.kind != 'fillPolygon') continue;
        final path = content.paths[i];
        final sub = path.subpaths.single;
        expect(
            path.paint, e.kind == 'polyline' ? PdfPaint.stroke : PdfPaint.fill);
        expect(sub.closed, e.kind == 'fillPolygon' || e.closed, reason: e.what);
        final v = sub.vertices;
        expect(v.length, e.points.length ~/ 2, reason: e.what);
        for (var k = 0; k < v.length; k++) {
          final x = e.points[2 * k], y = e.points[2 * k + 1];
          expectNear(
              v[k],
              toPage(x, y, e.residual),
              pdfTolerance(x, y, e.residual, pageHeight: height),
              '${e.what} vertex $k');
        }
        expectStyle(path, e);
        checked++;
      }
      expect(checked, greaterThan(20), reason: 'the dashes alone are 20');
    });

    test('the circle is four 90-degree cubics on its circle', () {
      final i = expected.indexWhere((e) => e.kind == 'circle');
      final e = expected[i];
      final path = content.paths[i];
      final sub = path.subpaths.single;
      expect(path.paint, PdfPaint.stroke);
      expect(sub.segments.length, 4);
      expect(sub.closed, isTrue);
      for (var q = 0; q <= 4; q++) {
        final a = q * math.pi / 2;
        final x = e.cx + e.r * math.cos(a), y = e.cy + e.r * math.sin(a);
        final at = q == 0 ? sub.start : sub.segments[q - 1].to;
        expectNear(
            at,
            toPage(x, y, e.residual),
            pdfTolerance(x, y, e.residual, pageHeight: height),
            'circle at ${q * 90} degrees');
      }
      expectOnCircle(sub, e.cx, e.cy, e.r, e.residual, 'circle');
      expectStyle(path, e);
    });

    test(
        'the -110 degree arc runs its signed sweep in cubics of at most 90 '
        'degrees', () {
      final i = expected.indexWhere((e) => e.kind == 'arc');
      final e = expected[i];
      expect(e.sweep, closeTo(kExportArcSweep, 1e-12));
      final path = content.paths[i];
      final sub = path.subpaths.single;
      expect(path.paint, PdfPaint.stroke);
      expect(sub.closed, isFalse);
      expect(sub.segments.length, 2, reason: '110 degrees: two cubics');
      for (final (what, angle, at) in [
        ('start', e.start, sub.start),
        ('end', e.start + e.sweep, sub.segments.last.to),
      ]) {
        final x = e.cx + e.r * math.cos(angle);
        final y = e.cy + e.r * math.sin(angle);
        expectNear(at, toPage(x, y, e.residual),
            pdfTolerance(x, y, e.residual, pageHeight: height), 'arc $what');
      }
      expectOnCircle(sub, e.cx, e.cy, e.r, e.residual, 'arc');
      // The mid-point is on the side the sweep's sign says: at start +
      // sweep / 2 in the local frame, not at start - sweep / 2.
      final mid = toLocal(_bezier(sub.start, sub.segments[0], 1), e.residual);
      final angle = math.atan2(mid.y - e.cy, mid.x - e.cx);
      final want = e.start + e.sweep / 2;
      final diff = math.atan2(math.sin(angle - want), math.cos(angle - want));
      expect(diff.abs(), lessThan(1e-3),
          reason: 'the mid-point is at ${angle * 180 / math.pi} degrees, '
              'the sweep says ${want * 180 / math.pi}');
      expectStyle(path, e);
    });

    test(
        'the point is an axis-aligned square of side lw · u around its '
        'position', () {
      final i = expected.indexWhere((e) => e.kind == 'point');
      final e = expected[i];
      expect(e.style.lineweightHundredths, kExportInstanceLineweight);
      _expectSquare(content.paths[i], toPage(e.cx, e.cy, e.residual),
          e.style.lineweightHundredths / 100 * u);
      expectStyle(content.paths[i], e);
    });
  });

  group('T-3b: direct calls', () {
    const page = (w: 841.8897637795275, h: 595.2755905511812);
    const red = ResolvedStyle(
      argb: 0xFFC62828,
      lineweightHundredths: 50,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1,
    );
    const translucent = ResolvedStyle(
      argb: 0x801E88E5,
      lineweightHundredths: 25,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1,
    );
    // The fixture's instance placement, seen through the page camera's
    // scale and flip: rotated, mirrored, scaled, nowhere near the origin.
    final residual = Transform2.translation(300, 200)
        .multiply(Transform2.scale(0.8, -0.8))
        .multiply(kExportInstanceTransform)
        .multiply(Transform2.translation(-7000, -5600));
    final square = Float64List.fromList([10, 20, 110, 20, 110, 90, 10, 90]);

    Future<PdfContent> draw(void Function(PdfDrawSink sink) body) =>
        _render(page.w, page.h, body);

    test('closed: true writes h before S; closed: false does not', () async {
      final c = await draw((sink) {
        sink.polyline(square, 4, red, closed: true);
        sink.polyline(square, 4, red, closed: false);
      });
      final names = c.operatorNames;
      final strokes = [
        for (var i = 0; i < names.length; i++)
          if (names[i] == 'S') i,
      ];
      expect(strokes, hasLength(2));
      expect(names[strokes[0] - 1], 'h', reason: 'closed');
      expect(names.sublist(strokes[0] + 1, strokes[1]), isNot(contains('h')),
          reason: 'open');
      expect(c.paths[0].subpaths.single.closed, isTrue);
      expect(c.paths[1].subpaths.single.closed, isFalse);
    });

    test('an opaque stroke after a 0x80 fill runs under CA and ca 1', () async {
      final c = await draw((sink) {
        sink.fillPolygon(square, 4, Int32List(0), translucent);
        sink.polyline(square, 4, red, closed: false);
      });
      expect(c.paths[0].state.fillAlpha, closeTo(128 / 255, kPdfRounding));
      final stroke = c.paths[1].state;
      expect([stroke.strokeAlpha, stroke.fillAlpha], [1, 1]);
      // Written for the stroke itself, not inherited.
      final names = c.operatorNames;
      final s = c.paths[1].operatorIndex;
      expect(names.sublist(c.paths[0].operatorIndex + 1, s), contains('gs'));
    });

    test('a stroke after a residual\'s Q writes its colour and width again',
        () async {
      final c = await draw((sink) {
        sink.beginResidual(residual);
        sink.polyline(square, 4, red, closed: false);
        sink.endResidual();
        sink.polyline(square, 4, red, closed: false);
      });
      final names = c.operatorNames;
      final q = names.lastIndexOf('Q');
      expect(names.indexOf('q'), greaterThan(0), reason: 'the residual');
      final after = names.sublist(q + 1, c.paths[1].operatorIndex);
      expect(after, containsAll(['RG', 'w', 'gs']));
      final state = c.paths[1].state;
      expect(state.strokeRgb[0], closeTo(0xC6 / 255, kPdfRounding));
      expect(state.strokeRgb[1], closeTo(0x28 / 255, kPdfRounding));
      expect(c.paths[1].deviceLineWidth,
          closeTo(0.5 * u, pdfWidthTolerance(0.5 * u, null)));
      // And under the residual: the same page width, through cm.
      expect(c.paths[0].deviceLineWidth,
          closeTo(0.5 * u, pdfWidthTolerance(0.5 * u, residual)));
    });

    // O-11: an instance scaled past the doubles (the embedding fixture's
    // table 9) composes a residual with a NaN or an infinite entry, which
    // the pdf package asserts on (`!value.isNaN`) and could not write as a
    // PDF number anyway. Whatever is drawn under it is skipped: no path, no
    // text, `q` and `Q` balanced, and the next residual draws as before.
    // M-O11e: a primitive under `cm` is not guarded. M-O11f: `point`, which
    // carries the residual by hand, is not guarded. M-O11g: a residual is
    // always taken as writable. M-O11h: `endResidual` leaves an unwritable
    // residual's skip in force for the screen-space primitive after it.
    final unwritable = <String, Transform2>{
      'a NaN entry': const Transform2(double.nan, 0, 0, 1, 0, 0),
      'an infinite entry': const Transform2(1, 0, 0, 1, double.infinity, 0),
    };
    final primitives = <String, void Function(PdfDrawSink)>{
      'polyline': (sink) => sink.polyline(square, 4, red, closed: true),
      'circle': (sink) => sink.circle(50, 50, 10, red),
      'arc': (sink) => sink.arc(50, 50, 10, 0.3, 1.2, red),
      'fillPolygon': (sink) =>
          sink.fillPolygon(square, 4, Int32List(0), translucent),
      'fillCircle': (sink) => sink.fillCircle(50, 50, 10, red),
      'point': (sink) => sink.point(50, 50, red),
      'text': (sink) => sink.text('Ab', ReservedHandles.standardTextStyle, red),
    };
    for (final MapEntry(key: what, value: bad) in unwritable.entries) {
      for (final MapEntry(key: name, value: primitive) in primitives.entries) {
        test(
            'O-11 under a residual with $what, $name draws nothing (M-O11e to '
            'M-O11h)', () async {
          final c = await draw((sink) {
            sink.beginResidual(bad);
            primitive(sink);
            sink.endResidual();
            sink.polyline(square, 4, red, closed: false);
            sink.beginResidual(residual);
            sink.polyline(square, 4, red, closed: true);
            sink.endResidual();
          });
          expect(c.paths, hasLength(2),
              reason: 'the screen-space polyline after it, and the next '
                  'residual\'s');
          expect(c.textRuns, isEmpty);
          final names = c.operatorNames;
          expect(names.where((n) => n == 'q').length,
              names.where((n) => n == 'Q').length);
          for (final op in c.operators) {
            for (final v in op.operands) {
              if (v is num) {
                expect(v.isFinite, isTrue, reason: '${op.name} $v');
              }
            }
          }
        });
      }
    }

    test(
        'a polyline and the -110 degree arc under a rotated and mirrored '
        'residual land where the residual and the page set-up put them',
        () async {
      // Not diagonal and not symmetric: a sink that writes the residual
      // transposed, or a reader that applies a matrix transposed, moves
      // these points. T-3's fixture residuals are all translations or
      // diagonal, which hides both.
      // The fixture's instance placement (rotated 30 degrees, scaled
      // (1.5, -0.75)) under a uniform scale: one mirror, so det < 0.
      final residual = Transform2.translation(300, 200)
          .multiply(Transform2.scale(0.8, 0.8))
          .multiply(kExportInstanceTransform)
          .multiply(Transform2.translation(-7000, -5600));
      expect(residual.determinant, lessThan(0), reason: 'mirrored');
      expect(residual.b.abs(), greaterThan(0.1), reason: 'rotated');
      expect((residual.b - residual.c).abs(), greaterThan(0.1),
          reason: 'not symmetric');
      final pts = Float64List.fromList([7010, 5620, 7110, 5620, 7110, 5690]);
      const cx = 7200.0, cy = 5700.0, r = 80.0, start = 0.4;
      const sweep = -110 * math.pi / 180;
      final c = await draw((sink) {
        sink.beginResidual(residual);
        sink.polyline(pts, 3, red, closed: false);
        sink.arc(cx, cy, r, start, sweep, red);
        sink.endResidual();
      });
      PdfXY toPage(double x, double y) {
        final p = residual.transformPoint(Vector2(x, y));
        return (x: p.x, y: page.h - p.y);
      }

      Vector2 toLocal(PdfXY p) =>
          residual.invert().transformPoint(Vector2(p.x, page.h - p.y));

      void near(PdfXY actual, double x, double y, String what) {
        final want = toPage(x, y);
        final tol = pdfTolerance(x, y, residual, pageHeight: page.h);
        expect((actual.x - want.x).abs(), lessThanOrEqualTo(tol),
            reason: '$what: x ${actual.x} vs ${want.x} (bound $tol)');
        expect((actual.y - want.y).abs(), lessThanOrEqualTo(tol),
            reason: '$what: y ${actual.y} vs ${want.y} (bound $tol)');
      }

      final v = c.paths[0].subpaths.single.vertices;
      expect(v, hasLength(3));
      for (var k = 0; k < 3; k++) {
        near(v[k], pts[2 * k], pts[2 * k + 1], 'polyline vertex $k');
      }

      final arc = c.paths[1].subpaths.single;
      expect(arc.segments, hasLength(2));
      near(arc.start, cx + r * math.cos(start), cy + r * math.sin(start),
          'arc start');
      near(arc.segments.last.to, cx + r * math.cos(start + sweep),
          cy + r * math.sin(start + sweep), 'arc end');
      // Samples on the circle, in the local frame.
      var p0 = arc.start;
      for (final s in arc.segments) {
        for (final t in const [0.25, 0.5, 0.75]) {
          final q = toLocal(_bezier(p0, s, t));
          final bound = pdfTolerance(q.x, q.y, residual,
                      pageHeight: page.h, operandsKnown: false) *
                  math.sqrt2 /
                  _minStretch(residual) +
              2.7e-4 * r;
          expect(((q - Vector2(cx, cy)).length - r).abs(),
              lessThanOrEqualTo(bound),
              reason: 'the cubic at t $t is off its circle');
        }
        p0 = s.to;
      }
      // The mid-point is on the side the sweep's sign says.
      final mid = toLocal(arc.segments.first.to);
      final angle = math.atan2(mid.y - cy, mid.x - cx);
      final want = start + sweep / 2;
      final diff = math.atan2(math.sin(angle - want), math.cos(angle - want));
      expect(diff.abs(), lessThan(1e-3),
          reason: 'the mid-point is at ${angle * 180 / math.pi} degrees, '
              'the sweep says ${want * 180 / math.pi}');
    });

    test('a residual with nothing drawn under it writes no q and no Q',
        () async {
      final c = await draw((sink) {
        sink.beginResidual(residual);
        sink.endResidual();
        sink.polyline(square, 4, red, closed: false);
      });
      expect(c.operatorNames, isNot(contains('q')));
      expect(c.operatorNames, isNot(contains('Q')));
    });

    test(
        'the point under a rotated, mirrored residual is an axis-aligned '
        'square of side lw · u; at lineweight 0 nothing', () async {
      const lw70 = ResolvedStyle(
        argb: 0xFFFF0000,
        lineweightHundredths: 70,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1,
      );
      const lw0 = ResolvedStyle(
        argb: 0xFFFF0000,
        lineweightHundredths: 0,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1,
      );
      final c = await draw((sink) {
        sink.beginResidual(residual);
        // A primitive first, so the residual's cm is open when the point
        // comes: the point must not draw under it.
        sink.polyline(square, 4, red, closed: false);
        sink.point(7400, 5900, lw70);
        sink.point(7400, 5900, lw0);
        sink.endResidual();
      });
      expect(c.paths, hasLength(2), reason: 'nothing at lineweight 0');
      final s = residual.transformPoint(Vector2(7400, 5900));
      _expectSquare(c.paths[1], (x: s.x, y: page.h - s.y), 0.70 * u);
    });

    test('lineweight 0 writes 0 w', () async {
      const hairline = ResolvedStyle(
        argb: 0xFF000000,
        lineweightHundredths: 0,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1,
      );
      final c = await draw((sink) {
        sink.polyline(square, 4, hairline, closed: false);
      });
      final w = c.operators.where((o) => o.name == 'w').single;
      expect(w.operands, [0]);
    });

    test('a fill circle is four cubics, closed, filled', () async {
      final c = await draw((sink) {
        sink.fillCircle(400, 300, 50, translucent);
      });
      final p = c.paths.single;
      expect(p.paint, PdfPaint.fill);
      expect(p.subpaths.single.segments.where((s) => s.isCubic), hasLength(4));
      expect(p.subpaths.single.closed, isTrue);
    });

    test('an arc takes one cubic per 90 degrees or part of one', () async {
      Future<int> cubics(double sweep) async {
        final c = await draw((sink) => sink.arc(400, 300, 50, 0.3, sweep, red));
        return c.paths.single.subpaths.single.segments.length;
      }

      expect(await cubics(math.pi / 2), 1);
      expect(await cubics(-math.pi / 2 - 1e-6), 2);
      expect(await cubics(-110 * math.pi / 180), 2);
      expect(await cubics(3 * math.pi / 2), 3);
      expect(await cubics(7), 4, reason: 'past a full turn: the full circle');
    });

    test('beginDash and endDash throw; shadesDashes is false', () async {
      await draw((sink) {
        expect(sink.shadesDashes, isFalse);
        expect(
          () => sink.beginDash(
              const DashPattern(dashes: [2, -1], totalLength: 3), 1),
          throwsUnsupportedError,
        );
        expect(sink.endDash, throwsUnsupportedError);
      });
    });
  });
}

/// One primitive the replay must produce: what it is, the residual in force
/// and the recorded values.
final class _Expected {
  _Expected(this.kind, this.residual, this.style,
      {this.points = const [],
      this.closed = false,
      this.cx = 0,
      this.cy = 0,
      this.r = 0,
      this.start = 0,
      this.sweep = 0,
      required this.what});

  final String kind;
  final Transform2? residual;
  final ResolvedStyle style;
  final List<double> points;
  final bool closed;
  final double cx, cy, r, start, sweep;
  final String what;
}

List<_Expected> _expectedPrimitives(List<DrawOp> ops) {
  final out = <_Expected>[];
  Transform2? residual;
  var leaf = Handle.none;
  for (final op in ops) {
    switch (op) {
      case BeginResidualOp(residual: final r, :final debugHandle):
        residual = r;
        leaf = debugHandle;
      case EndResidualOp():
        residual = null;
      case PolylineOp(:final points, :final style, :final closed):
        out.add(_Expected('polyline', residual, style,
            points: points, closed: closed, what: 'polyline of $leaf'));
      case FillPolygonOp(:final points, :final style):
        out.add(_Expected('fillPolygon', residual, style,
            points: points, what: 'fill of $leaf'));
      case CircleOp(:final cx, :final cy, :final r, :final style):
        out.add(_Expected('circle', residual, style,
            cx: cx, cy: cy, r: r, what: 'circle of $leaf'));
      case FillCircleOp(:final cx, :final cy, :final r, :final style):
        out.add(_Expected('fillCircle', residual, style,
            cx: cx, cy: cy, r: r, what: 'fill circle of $leaf'));
      case ArcOp(
          :final cx,
          :final cy,
          :final r,
          :final start,
          :final sweep,
          :final style
        ):
        out.add(_Expected('arc', residual, style,
            cx: cx,
            cy: cy,
            r: r,
            start: start,
            sweep: sweep,
            what: 'arc of $leaf'));
      case PointOp(:final x, :final y, :final style):
        if (style.lineweightHundredths > 0) {
          out.add(_Expected('point', residual, style,
              cx: x, cy: y, what: 'point of $leaf'));
        }
      case TextOp():
      case BeginDashOp():
      case EndDashOp():
        break;
    }
  }
  return out;
}

void _replay(DrawOp op, DrawSink sink) {
  switch (op) {
    case BeginResidualOp(:final residual, :final debugHandle):
      sink.beginResidual(residual, debugHandle: debugHandle);
    case EndResidualOp():
      sink.endResidual();
    case PointOp(:final x, :final y, :final style):
      sink.point(x, y, style);
    case PolylineOp(:final points, :final style, :final closed):
      sink.polyline(Float64List.fromList(points), points.length ~/ 2, style,
          closed: closed);
    case CircleOp(:final cx, :final cy, :final r, :final style):
      sink.circle(cx, cy, r, style);
    case ArcOp(
        :final cx,
        :final cy,
        :final r,
        :final start,
        :final sweep,
        :final style
      ):
      sink.arc(cx, cy, r, start, sweep, style);
    case FillPolygonOp(:final points, :final triangles, :final style):
      sink.fillPolygon(Float64List.fromList(points), points.length ~/ 2,
          Int32List.fromList(triangles), style);
    case FillCircleOp(:final cx, :final cy, :final r, :final style):
      sink.fillCircle(cx, cy, r, style);
    case TextOp():
      // T-5 (`pdf_draw_sink_text_test.dart`) replays text, with a measurer
      // that gives it a regular residual.
      break;
    case BeginDashOp():
    case EndDashOp():
      throw StateError('recorded with shadesDashes: false, no dash bracket');
  }
}

final Uint8List _font = exportFontBytes();

/// A one-page document of [width] × [height] pt, [body] drawn into its
/// sink, written uncompressed with `write(PdfStream)` and read back.
Future<PdfContent> _render(
  double width,
  double height,
  void Function(PdfDrawSink sink) body,
) async {
  final document = PdfDocument(compress: false);
  final page = PdfPage(document, pageFormat: PdfPageFormat(width, height));
  body(PdfDrawSink(
    document: document,
    page: page,
    pixelsPerPaperMm: 72 / 25.4,
    fontBytes: _font,
    measurer: FlutterTextMeasurer(),
    textStyleOf: DraftDocument.empty().textStyleOf,
  ));
  final out = PdfStream();
  await document.write(out);
  return PdfContent.parse(out.output(), inflate: zlib.decode);
}

/// [path] is one closed four-corner subpath, filled, whose edges are
/// axis-aligned on the page, of side [side], centred on [centre].
///
/// The `re` operands are written in page units, once each (5e-6). The H of
/// the page set-up adds 5e-6. So 2e-5 bounds the centre and the side.
void _expectSquare(PdfContentPath path, PdfXY centre, double side) {
  const tol = 2e-5;
  expect(path.paint, PdfPaint.fill);
  final sub = path.subpaths.single;
  expect(sub.closed, isTrue);
  final v = sub.vertices;
  expect(v, hasLength(4));
  for (var k = 0; k < 4; k++) {
    final a = v[k], b = v[(k + 1) % 4];
    final dx = (a.x - b.x).abs(), dy = (a.y - b.y).abs();
    expect(math.min(dx, dy), lessThanOrEqualTo(tol),
        reason: 'edge $k is axis-aligned on the page ($dx, $dy)');
    expect(math.max(dx, dy), closeTo(side, tol), reason: 'edge $k length');
  }
  final cx = v.map((p) => p.x).reduce((a, b) => a + b) / 4;
  final cy = v.map((p) => p.y).reduce((a, b) => a + b) / 4;
  expect(cx, closeTo(centre.x, tol), reason: 'centre x');
  expect(cy, closeTo(centre.y, tol), reason: 'centre y');
}

/// The cubic [s] (from [p0]) at [t].
PdfXY _bezier(PdfXY p0, PdfContentSegment s, double t) {
  final m = 1 - t;
  final c1 = s.controls[0], c2 = s.controls[1], p3 = s.to;
  double at(double a, double b, double c, double d) =>
      m * m * m * a + 3 * m * m * t * b + 3 * m * t * t * c + t * t * t * d;
  return (
    x: at(p0.x, c1.x, c2.x, p3.x),
    y: at(p0.y, c1.y, c2.y, p3.y),
  );
}

/// The smallest singular value of [r]'s linear part: how much a page error
/// can grow on the way back to local space.
double _minStretch(Transform2? r) {
  if (r == null) return 1;
  final t = r.a * r.a + r.b * r.b + r.c * r.c + r.d * r.d;
  final det = r.determinant;
  return math.sqrt((t - math.sqrt(math.max(0, t * t - 4 * det * det))) / 2);
}
