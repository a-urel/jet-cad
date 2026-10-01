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

/// Spec 13 T-5 at the sink: `PdfDrawSink.text`, read back from the bytes by
/// the content reader (`export_testing.dart`, tested on its own in
/// `pdf_content_test.dart`).
///
/// - The export fixture is built with a `FlutterTextMeasurer` (plan 13 P-5:
///   flutter_test's default font, Ahem, every glyph one em wide), so `Tz` is
///   far from 100 and its omission is visible. The fixture's default
///   measurer would give text a singular residual.
/// - It is painted at the page camera with `minTextCapPixels: 0` (so "WC",
///   whose cap height is 1.42 pt, is recorded), and every op, text
///   included, is replayed into a `PdfDrawSink` embedding the vendored
///   Roboto.
/// - A direct call checks a run under a rotated **and** mirrored residual,
///   which the painter never gives text in the fixture (its text residuals
///   are diagonal, where a transposed matrix cannot show).
///
/// The named mutants are M-13l (`Tz` omitted) and M-13m (an extra y flip).
void main() {
  const u = 72 / 25.4;
  final fontBytes = exportFontBytes();

  group('T-5: the fixture\'s text replayed at the page camera', () {
    final measurer = FlutterTextMeasurer();
    final f = exportFixture(measurer: measurer);
    final camera = pageCamera(f.page, u);
    final height = camera.size.height;
    late List<_Text> texts;
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
      texts = _texts(recording.ops);
      content = await _render(
        camera.size.width,
        height,
        fontBytes,
        measurer,
        f.document.textStyleOf,
        (sink) {
          for (final op in recording.ops) {
            _replay(op, sink);
          }
        },
      );
    });

    test('one run per recorded text, in order: "Yatak Odası" and "WC"', () {
      expect([for (final t in texts) t.text], ['Yatak Odası', 'WC'],
          reason: 'the fixture records both labels at minTextCapPixels 0');
      expect(content.textRuns, hasLength(texts.length));
      for (var i = 0; i < texts.length; i++) {
        // The CIDs mapped back through the font's /ToUnicode.
        expect(content.textRuns[i].string, texts[i].text);
      }
    });

    test('every residual is regular and mirrors y (the camera\'s flip)', () {
      for (final t in texts) {
        expect(t.residual.determinant, lessThan(0), reason: t.text);
      }
    });

    test('Tf selects one font at kNominalTextPixels', () {
      for (final run in content.textRuns) {
        expect(run.size, kNominalTextPixels);
      }
      expect(
          {for (final run in content.textRuns) run.fontResource}, hasLength(1),
          reason: 'one PdfTtfFont from the bytes');
    });

    test('the font is a /Type0 over a CIDFontType2 with a FontFile2', () {
      final info = content.textRuns.first.fontInfo;
      expect(
        [info.subtype, info.encoding, info.descendantSubtype, info.fontFile],
        ['/Type0', '/Identity-H', '/CIDFontType2', '/FontFile2'],
      );
    });

    test(
        'the advance from /W times Tz / 100 is the measured width, and Tz is '
        'far from 100', () {
      for (var i = 0; i < texts.length; i++) {
        final t = texts[i], run = content.textRuns[i];
        final measured = measurer
            .measure(text: t.text, style: f.document.textStyleOf(t.style))
            .advanceWidth;
        // Ahem lays every glyph out one em wide; Roboto's are about half
        // that, so the stretch is large and its omission shows.
        expect((run.horizontalScale - 100).abs(), greaterThan(20),
            reason: '${t.text}: Tz ${run.horizontalScale}');
        expect(run.advance, closeTo(measured, _advanceBound(run)),
            reason: '${t.text}: advance ${run.advance} vs measured '
                '$measured');
      }
    });

    test('each run starts at pageSetUp · residual · (0, 0)', () {
      for (var i = 0; i < texts.length; i++) {
        final t = texts[i], run = content.textRuns[i];
        final s = t.residual.transformPoint(Vector2.zero());
        final tol = pdfTolerance(0, 0, t.residual, pageHeight: height);
        expect((run.origin.x - s.x).abs(), lessThanOrEqualTo(tol),
            reason: '${t.text}: origin x ${run.origin.x} vs ${s.x}');
        expect((run.origin.y - (height - s.y)).abs(), lessThanOrEqualTo(tol),
            reason: '${t.text}: origin y ${run.origin.y} vs ${height - s.y}');
      }
    });

    test(
        'text-space (0, 1) and (1, 0) point where pageSetUp · residual takes '
        'them (no extra flip)', () {
      for (var i = 0; i < texts.length; i++) {
        _expectDirections(
            content.textRuns[i], texts[i].residual, texts[i].text);
      }
    });

    test('the run fills in the text\'s colour, under its alpha', () {
      for (var i = 0; i < texts.length; i++) {
        _expectFill(content.textRuns[i], texts[i].resolved, texts[i].text);
      }
    });
  });

  group('T-5: a direct call under a rotated and mirrored residual', () {
    const page = (w: 841.8897637795275, h: 595.2755905511812);
    // A text placement seen through a camera: a 30 degree turn, the
    // instance's anisotropic scale, the camera's flip; nowhere near the
    // origin.
    final residual = Transform2.translation(300, 200)
        .multiply(Transform2.scale(0.12, -0.12))
        .multiply(Transform2.rotation(math.pi / 6))
        .multiply(Transform2.scale(1.5, 0.75));
    const style = ResolvedStyle(
      argb: 0x801E88E5,
      lineweightHundredths: 25,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1,
    );
    const text = 'Yatak Odası';
    final measurer = FlutterTextMeasurer();
    final textStyleOf = DraftDocument.empty().textStyleOf;
    late PdfContent content;

    setUpAll(() async {
      content = await _render(page.w, page.h, fontBytes, measurer, textStyleOf,
          (sink) {
        sink
          ..beginResidual(residual)
          ..text(text, ReservedHandles.standardTextStyle, style)
          ..endResidual();
      });
    });

    test('the residual is mirrored and not symmetric', () {
      expect(residual.determinant, lessThan(0));
      expect((residual.b - residual.c).abs(), greaterThan(0.01));
      expect(residual.b.abs(), greaterThan(0.01));
    });

    test('the run is inside the residual\'s q … Q', () {
      final names = content.operatorNames;
      final bt = names.indexOf('BT');
      expect(names.sublist(0, 4), ['cm', 'J', 'j', 'M']);
      expect(names.sublist(4, 6), ['q', 'cm']);
      expect(names.sublist(bt), ['BT', 'Tf', 'Tz', 'Td', 'TJ', 'ET', 'Q']);
      final td = content.operators[bt + 3];
      expect(td.operands, [0, 0]);
    });

    test('the string round-trips through /ToUnicode, at kNominalTextPixels',
        () {
      final run = content.textRuns.single;
      expect(run.string, text);
      expect(run.size, kNominalTextPixels);
    });

    test('it starts at pageSetUp · residual · (0, 0)', () {
      final run = content.textRuns.single;
      final tol = pdfTolerance(0, 0, residual, pageHeight: page.h);
      expect((run.origin.x - residual.e).abs(), lessThanOrEqualTo(tol));
      expect(
          (run.origin.y - (page.h - residual.f)).abs(), lessThanOrEqualTo(tol));
    });

    test(
        'text-space (0, 1) and (1, 0) point where pageSetUp · residual takes '
        'them', () {
      _expectDirections(content.textRuns.single, residual, text);
    });

    test('the advance is the measured width', () {
      final run = content.textRuns.single;
      final measured = measurer
          .measure(
              text: text, style: textStyleOf(ReservedHandles.standardTextStyle))
          .advanceWidth;
      expect(run.advance, closeTo(measured, _advanceBound(run)));
    });

    test('it fills in its colour, under an ExtGState of its alpha', () {
      _expectFill(content.textRuns.single, style, text);
    });
  });

  group('the advance comes from the measurer and the style it is given', () {
    final residual = Transform2.translation(420, 310)
        .multiply(Transform2.scale(0.05, -0.05))
        .multiply(Transform2.rotation(-0.4));
    const style = ResolvedStyle(
      argb: 0xFF37474F,
      lineweightHundredths: 35,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1,
    );
    const page = (w: 841.8897637795275, h: 595.2755905511812);

    test(
        'any TextMeasurer: a MetricModelMeasurer\'s 0.55 em per glyph is the '
        'run\'s advance (a sink that measures with its own '
        'FlutterTextMeasurer gets Ahem\'s 1 em)', () async {
      final measurer = MetricModelMeasurer(advanceRatio: 0.55);
      final textStyleOf = DraftDocument.empty().textStyleOf;
      final content = await _render(
          page.w, page.h, fontBytes, measurer, textStyleOf, (sink) {
        sink
          ..beginResidual(residual)
          ..text('Yatak Odası', ReservedHandles.standardTextStyle, style)
          ..endResidual();
      });
      final run = content.textRuns.single;
      // 11 glyphs · 0.55 em · 100.
      expect(run.advance, closeTo(605, _advanceBound(run)));
    });

    test(
        'the entity\'s own style record is measured, not the standard one (a '
        'sink that measures every text under Standard gets the wrong width)',
        () async {
      final doc = DraftDocument.empty();
      final labelStyle = doc.handleSeed.next();
      doc.tables.textStyles.add(TextStyleRecord(
          handle: labelStyle, name: 'Label', fontFamily: 'Arial'));
      final measurer = _PerStyleMeasurer({'Standard': 0.55, 'Label': 0.35});
      final content = await _render(
          page.w, page.h, fontBytes, measurer, doc.textStyleOf, (sink) {
        sink
          ..beginResidual(residual)
          ..text('WC', labelStyle, style)
          ..text('WC', ReservedHandles.standardTextStyle, style)
          ..endResidual();
      });
      final [label, standard] = content.textRuns;
      // 2 glyphs · 0.35 em · 100, and 2 · 0.55 · 100.
      expect(label.advance, closeTo(70, _advanceBound(label)));
      expect(standard.advance, closeTo(110, _advanceBound(standard)));
    });

    test(
        'a document that writes the font as a simple TrueType throws on the '
        'first text, before anything is written for it (w_pdf reproduces the '
        'CID path\'s /W only)', () async {
      final document = PdfDocument(compress: false, simpleTrueTypeFonts: true);
      final pdfPage =
          PdfPage(document, pageFormat: PdfPageFormat(page.w, page.h));
      final sink = PdfDrawSink(
        document: document,
        page: pdfPage,
        pixelsPerPaperMm: 72 / 25.4,
        fontBytes: fontBytes,
        measurer: MetricModelMeasurer(),
        textStyleOf: DraftDocument.empty().textStyleOf,
      )..beginResidual(residual);
      expect(
        () => sink.text('WC', ReservedHandles.standardTextStyle, style),
        throwsStateError,
      );
      // A stroke after it, in screen space, so the page has content (the
      // package drops a stream that painted nothing).
      sink
        ..endResidual()
        ..polyline(Float64List.fromList([10, 20, 300, 40]), 2, style,
            closed: false);
      final out = PdfStream();
      await document.write(out);
      expect(PdfContent.parse(out.output(), inflate: zlib.decode).operatorNames,
          ['cm', 'J', 'j', 'M', 'RG', 'w', 'gs', 'm', 'l', 'S'],
          reason: 'no q, cm, rg or gs left behind by the refused text');
      // The same call on a default document draws (the guard is not a
      // blanket refusal).
      final content = await _render(page.w, page.h, fontBytes,
          MetricModelMeasurer(), DraftDocument.empty().textStyleOf, (sink) {
        sink
          ..beginResidual(residual)
          ..text('WC', ReservedHandles.standardTextStyle, style)
          ..endResidual();
      });
      expect(content.textRuns.single.string, 'WC');
      expect(content.textRuns.single.fontInfo.subtype, '/Type0');
    });
  });
}

/// A measurer whose advance depends on the style **record** it is given: so
/// a sink that measures under any other style than the entity's measures a
/// different width.
final class _PerStyleMeasurer implements TextMeasurer {
  _PerStyleMeasurer(this.emPerGlyph);

  final Map<String, double> emPerGlyph;

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      TextMetrics(
        advanceWidth:
            text.runes.length * emPerGlyph[style.name]! * kNominalTextPixels,
        ascent: 80,
        descent: 20,
        capHeight: 70,
      );
}

/// One recorded text and the residual it was drawn under.
final class _Text {
  _Text(this.text, this.style, this.resolved, this.residual);

  final String text;
  final Handle style;
  final ResolvedStyle resolved;
  final Transform2 residual;
}

List<_Text> _texts(List<DrawOp> ops) {
  final out = <_Text>[];
  Transform2? residual;
  for (final op in ops) {
    switch (op) {
      case BeginResidualOp(residual: final r):
        residual = r;
      case EndResidualOp():
        residual = null;
      case TextOp(:final text, :final style, :final resolved):
        out.add(_Text(text, style, resolved, residual!));
      default:
        break;
    }
  }
  return out;
}

/// The bound on a run's advance read back against the measured width.
///
/// The widths in `/W` are integers and `Tf`'s size 100 is exact, so only
/// `Tz` is rounded (by at most 5e-6, `PdfNum`'s rule). The advance is
/// `Tz / 100 · A`, so its error is `δTz / Tz · advance`.
double _advanceBound(PdfContentText run) =>
    kPdfRounding / run.horizontalScale * run.advance.abs() +
    1e-9 * (1 + run.advance.abs());

/// The page-space images of text-space (0, 1) and (1, 0) under the run's
/// parsed CTM and text matrix point the way `pageSetUp · residual` takes
/// them, `pageSetUp` being `[1 0 0 −1 0 H]` (spec 13 T-5, S-3).
///
/// The expected value already contains the page's flip, so an extra flip in
/// the sink reverses (0, 1). The bound on the angle is the rounding of the
/// residual's written entries over the vector's length.
void _expectDirections(PdfContentText run, Transform2 r, String what) {
  final m = run.pageMatrix;
  for (final (tx, ty, ex, ey, dx, dy) in [
    (0.0, 1.0, r.c, -r.d, pdfRoundingError(r.c), pdfRoundingError(r.d)),
    (1.0, 0.0, r.a, -r.b, pdfRoundingError(r.a), pdfRoundingError(r.b)),
  ]) {
    final v = m.applyToVector(tx, ty);
    final angle = math.atan2(v.x * ey - v.y * ex, v.x * ex + v.y * ey).abs();
    final bound =
        math.sqrt(dx * dx + dy * dy) / math.sqrt(ex * ex + ey * ey) + 1e-9;
    expect(angle, lessThanOrEqualTo(bound),
        reason: '$what: text-space ($tx, $ty) goes to (${v.x}, ${v.y}), '
            'expected the direction of ($ex, $ey)');
  }
}

void _expectFill(PdfContentText run, ResolvedStyle style, String what) {
  final argb = style.argb;
  final rgb = [
    ((argb >> 16) & 0xFF) / 255,
    ((argb >> 8) & 0xFF) / 255,
    (argb & 0xFF) / 255,
  ];
  for (var i = 0; i < 3; i++) {
    expect(run.state.fillRgb[i], closeTo(rgb[i], kPdfRounding),
        reason: '$what: fill channel $i');
  }
  expect(
      run.state.fillAlpha, closeTo(((argb >> 24) & 0xFF) / 255, kPdfRounding),
      reason: '$what: alpha');
  expect(run.state.extGStates, isNotEmpty,
      reason: '$what: a gs is written for the run');
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
    case TextOp(:final text, :final style, :final resolved):
      sink.text(text, style, resolved);
    case BeginDashOp():
    case EndDashOp():
      throw StateError('recorded with shadesDashes: false, no dash bracket');
  }
}

/// A one-page document of [width] × [height] pt, [body] drawn into its
/// sink, written uncompressed with `write(PdfStream)` and read back.
Future<PdfContent> _render(
  double width,
  double height,
  Uint8List fontBytes,
  TextMeasurer measurer,
  TextStyleRecord Function(Handle) textStyleOf,
  void Function(PdfDrawSink sink) body,
) async {
  final document = PdfDocument(compress: false);
  final page = PdfPage(document, pageFormat: PdfPageFormat(width, height));
  body(PdfDrawSink(
    document: document,
    page: page,
    pixelsPerPaperMm: 72 / 25.4,
    fontBytes: fontBytes,
    measurer: measurer,
    textStyleOf: textStyleOf,
  ));
  final out = PdfStream();
  await document.write(out);
  return PdfContent.parse(out.output(), inflate: zlib.decode);
}
