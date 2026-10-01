import 'dart:io' show zlib;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/export_fixture.dart';
import '../support/export_font.dart';
import '../support/pdf_tolerance.dart';

/// Spec 13 T-4, T-5, T-6, T-8 (PDF) and T-9 (PDF), every one through
/// `exportPagePdf(compress: false)` (spec "Route per test"), read back by the
/// content reader (`export_testing.dart`, tested on its own).
///
/// The fixture's document measures with a `FlutterTextMeasurer` (Ahem under
/// flutter_test, plan 13 P-5): its default measurer gives text a singular
/// residual. Expected positions are computed here from the page's numbers
/// and the fixture's world coordinates, **not** through `pageCamera`: PDF
/// page space is y up from the sheet's lower-left corner, so a world point
/// `(x, y)` lands at `((x - 3000) / den · u, (y + 1500) / den · u)`.
///
/// Named mutants: M-13b, M-13c, M-13d, M-13n, M-13o, M-13p, M-13x.
void main() {
  const u = 72 / 25.4;
  final fontBytes = exportFontBytes();

  // A4 landscape in pt, from the paper's millimetres.
  const sheetW = 297 * u, sheetH = 210 * u;

  /// World millimetres to PDF page space at 1:[den], computed from the
  /// fixture's page numbers alone.
  PdfXY toPage(Vector2 w, double den) => (
        x: (w.x - kExportOriginX) / den * u,
        y: (w.y - kExportOriginY) / den * u,
      );

  Future<PdfContent> export(
    ExportFixture f, {
    Set<Handle> omitOwners = const {},
  }) async {
    final bytes = await exportPagePdf(
      document: f.document,
      page: f.page,
      fontBytes: fontBytes,
      omitOwners: omitOwners,
      compress: false,
    );
    return PdfContent.parse(bytes, inflate: zlib.decode);
  }

  for (final den in [50.0, 100.0]) {
    group('T-4 at 1:${den.toInt()}: lineweight is millimetres on paper', () {
      final f =
          exportFixture(scaleDenominator: den, measurer: FlutterTextMeasurer());
      // A line of lineweight 0, wholly on the sheet at both scales.
      _addLine(f.document, [5000, 9000, 8000, 9300],
          rgb: 0x5D4037, lineweight: 0);
      late PdfContent content;

      setUpAll(() async => content = await export(f));

      test('the MediaBox is the effective sheet in pt', () {
        expect(content.mediaBox, hasLength(4));
        expect(content.mediaBox[0], 0);
        expect(content.mediaBox[1], 0);
        expect(content.mediaBox[2], closeTo(sheetW, kPdfRounding));
        expect(content.mediaBox[3], closeTo(sheetH, kPdfRounding));
      });

      test(
          'the instance\'s 0.70 mm override is 0.70 · 72 / 25.4 = 1.98425… pt '
          'in device space (w × the CTM\'s scale)', () {
        final start = toPage(
            kExportInstanceTransform.transformPoint(Vector2(200, 100)), den);
        final red = _strokesStartingAt(content, start);
        expect(red, hasLength(2),
            reason: 'the instance\'s line and polyline both start at '
                'definition (200, 100)');
        for (final p in red) {
          expect(
              p.deviceLineWidth, closeTo(0.70 * u, _widthBound(p, 0.70 * u)));
        }
        expect(0.70 * u, closeTo(1.98425, 1e-5));
      });

      test('a 0.35 mm line is 0.99213… pt', () {
        final p = _strokeOfRgb(content, 0x1565C0);
        expect(p.deviceLineWidth, closeTo(0.35 * u, _widthBound(p, 0.35 * u)));
        expect(0.35 * u, closeTo(0.99213, 1e-5));
      });

      test('lineweight 0 writes 0 w', () {
        final p = _strokeOfRgb(content, 0x5D4037);
        expect(p.state.lineWidth, 0);
      });
    });
  }

  group('T-5, T-6, T-9 at 1:50', () {
    final measurer = FlutterTextMeasurer();
    final f = exportFixture(measurer: measurer);
    late PdfContent content;
    late String codecBefore, codecAfter;
    late int stateBefore, stateAfter;

    setUpAll(() async {
      codecBefore = DraftDocumentCodec.encodeToString(f.document);
      stateBefore = f.document.commands.stateId;
      content = await export(f);
      codecAfter = DraftDocumentCodec.encodeToString(f.document);
      stateAfter = f.document.commands.stateId;
    });

    test('T-5: both labels are drawn, "WC" (below the default LOD) included',
        () {
      expect(
          [for (final t in content.textRuns) t.string], ['Yatak Odası', 'WC']);
    });

    test(
        'T-5: the instance\'s first point is where the page and the fixture '
        'put it (not where a fitted camera would)', () {
      final start = toPage(
          kExportInstanceTransform.transformPoint(Vector2(200, 100)), 50);
      expect(_strokesStartingAt(content, start), hasLength(2),
          reason: 'expected the instance\'s line and polyline at '
              '(${start.x}, ${start.y})');
    });

    test(
        'T-5: each run starts at its insertion point\'s page position (the '
        'baseline origin)', () {
      final big = content.textRuns[0], wc = content.textRuns[1];
      for (final (run, at) in [
        (big, Vector2(4500, 3500)),
        (wc, Vector2(10500, 4500)),
      ]) {
        final e = toPage(at, 50);
        // The run's origin is the residual's written translation: e and f
        // rounded once each (and H for y), plus the arithmetic.
        const bound = 2 * kPdfRounding + 1e-9;
        expect(run.origin.x, closeTo(e.x, bound), reason: run.string);
        expect(run.origin.y, closeTo(e.y, bound), reason: run.string);
      }
    });

    test('T-6: the ACI 7 line strokes black on a page whose screen is dark',
        () {
      expect(f.page.background, kExportBackground);
      final a = toPage(Vector2(3600, 300), 50);
      final p = _strokesStartingAt(content, a).single;
      expect(p.state.strokeRgb, [0, 0, 0]);
      expect(
          content.operators[_strokeColourIndex(content, p)].operands, [0, 0, 0],
          reason: 'written as 0 0 0 RG');
    });

    test('T-6: the instance\'s leaves stroke and fill red', () {
      final start = toPage(
          kExportInstanceTransform.transformPoint(Vector2(200, 100)), 50);
      for (final p in _strokesStartingAt(content, start)) {
        expect(p.state.strokeRgb, [1, 0, 0]);
      }
      // The point marker: a filled square centred on the point's position.
      final centre = toPage(
          kExportInstanceTransform.transformPoint(Vector2(500, 300)), 50);
      final marker = content.paths.where((p) {
        if (!p.fills) return false;
        final v = p.subpaths.single.vertices;
        final cx = v.map((q) => q.x).reduce((a, b) => a + b) / v.length;
        final cy = v.map((q) => q.y).reduce((a, b) => a + b) / v.length;
        // `re`'s corner and side are rounded once each (and H for y).
        const bound = 3 * kPdfRounding + 1e-9;
        return (cx - centre.x).abs() <= bound && (cy - centre.y).abs() <= bound;
      }).toList();
      expect(marker, hasLength(1));
      expect(marker.single.state.fillRgb, [1, 0, 0]);
    });

    test(
        'T-6: the 0x80 fill is under ca 0.50196…, and the op after it under '
        'CA and ca 1', () {
      final i = content.paths
          .indexWhere((p) => p.fills && _isRgb(p.state.fillRgb, 0x1E88E5));
      expect(i, isNonNegative);
      final fill = content.paths[i];
      expect(fill.state.fillAlpha, closeTo(128 / 255, kPdfRounding));
      expect(128 / 255, closeTo(0.50196, 1e-5));
      final next = content.paths[i + 1];
      expect([next.state.strokeAlpha, next.state.fillAlpha], [1, 1],
          reason: 'the next op is opaque and its gs says so');
      expect(next.state.extGStates, isNotEmpty);
    });

    test('T-9: the codec\'s bytes and the stateId are unchanged', () {
      expect(stateBefore, isNot(0), reason: 'the fixture ran commands');
      expect(stateAfter, stateBefore);
      expect(codecAfter, codecBefore);
    });
  });

  group('the run\'s advance is the document\'s measurer\'s', () {
    test(
        'a document measuring 0.55 em per glyph exports runs of that advance '
        '(an export with its own FlutterTextMeasurer stretches to Ahem\'s 1 '
        'em)', () async {
      final f =
          exportFixture(measurer: MetricModelMeasurer(advanceRatio: 0.55));
      final content = await export(f);
      expect(
          [for (final t in content.textRuns) t.string], ['Yatak Odası', 'WC']);
      for (final run in content.textRuns) {
        final expected = run.string!.runes.length * 0.55 * kNominalTextPixels;
        expect(run.advance,
            closeTo(expected, kPdfRounding / run.horizontalScale * expected),
            reason: run.string);
      }
    });
  });

  test(
      'each run is measured under its own style record ("WC" under "Label", '
      'not Standard)', () async {
    final f = exportFixture(
        measurer: _PerStyleMeasurer({'Standard': 0.55, 'Label': 0.35}));
    final content = await export(f);
    final [big, wc] = content.textRuns;
    // 11 glyphs at 0.55 em and 2 at 0.35 em, at kNominalTextPixels.
    expect(big.advance, closeTo(605, kPdfRounding / big.horizontalScale * 605));
    expect(wc.advance, closeTo(70, kPdfRounding / wc.horizontalScale * 70));
  });

  group('T-9: the dispatcher\'s mutation hooks are left as found', () {
    // A region nothing in the fixture reaches, for the "screen" index's
    // query after an edit.
    final probe = Aabb2(Vector2(19900, 19900), Vector2(20200, 20200));
    int count(SpatialIndex index) {
      var n = 0;
      index.forEachInRect(probe, const QueryFilter.all(), (_) => n++);
      return n;
    }

    test(
        'with a screen index on the document: the same hooks after a normal '
        'and a throwing export, and the screen index hears the next edit',
        () async {
      final f = exportFixture(measurer: FlutterTextMeasurer());
      final screen = SpatialIndex(f.document);
      addTearDown(screen.dispose);
      final commands = f.document.commands;
      final after = commands.onAfterMutate, before = commands.onBeforeMutate;
      expect([after, before], everyElement(isNotNull));

      await export(f);
      expect(commands.onAfterMutate, after, reason: 'normal export');
      expect(commands.onBeforeMutate, before, reason: 'normal export');

      // Bytes that are no font: the first text throws inside the paint.
      await expectLater(
        exportPagePdf(
          document: f.document,
          page: f.page,
          fontBytes: Uint8List.fromList(List.filled(64, 7)),
          compress: false,
        ),
        throwsA(anything),
      );
      expect(commands.onAfterMutate, after, reason: 'throwing export');
      expect(commands.onBeforeMutate, before, reason: 'throwing export');

      expect(count(screen), 0);
      _addLine(f.document, [19950, 19950, 20100, 20100],
          rgb: 0x5D4037, lineweight: 35);
      expect(count(screen), 1, reason: 'the screen index saw the edit');
    });

    test('with no index on the document: no hook is left behind', () async {
      final f = exportFixture(measurer: FlutterTextMeasurer());
      final commands = f.document.commands;
      expect([commands.onAfterMutate, commands.onBeforeMutate],
          everyElement(isNull));
      await export(f);
      expect([commands.onAfterMutate, commands.onBeforeMutate],
          everyElement(isNull));
      await expectLater(
        exportPagePdf(
          document: f.document,
          page: f.page,
          fontBytes: Uint8List.fromList(List.filled(64, 7)),
          compress: false,
        ),
        throwsA(anything),
      );
      expect([commands.onAfterMutate, commands.onBeforeMutate],
          everyElement(isNull));
    });
  });

  test(
      'another sheet: A3 portrait at 1:100, off the origin, is a 297 × 420 mm '
      'MediaBox with the ACI 7 line where the page puts it', () async {
    final f = exportFixture(measurer: FlutterTextMeasurer());
    final a3 = f.page.copyWith(
      widthMm: 297,
      heightMm: 420,
      orientation: PageOrientation.portrait,
      scaleDenominator: 100,
    );
    f.document.commands.execute(
      SetComponentCommand<PageComponent>(f.document.rootHandle, a3),
    );
    expect([a3.originX, a3.originY], [kExportOriginX, kExportOriginY]);
    final bytes = await exportPagePdf(
        document: f.document, page: a3, fontBytes: fontBytes, compress: false);
    final content = PdfContent.parse(bytes, inflate: zlib.decode);
    expect(content.mediaBox[0], 0);
    expect(content.mediaBox[1], 0);
    expect(content.mediaBox[2], closeTo(297 * u, kPdfRounding));
    expect(content.mediaBox[3], closeTo(420 * u, kPdfRounding));
    final p = _strokesStartingAt(content, toPage(Vector2(3600, 300), 100));
    expect(p, hasLength(1));
    expect(p.single.state.strokeRgb, [0, 0, 0]);
  });

  group('T-8 (PDF): the separator', () {
    final f = exportFixture(measurer: FlutterTextMeasurer());
    final group =
        Transform2.translation(9200, 5200).multiply(Transform2.rotation(0.1));
    final a = toPage(group.transformPoint(Vector2(100, 150)), 50);
    final b = toPage(group.transformPoint(Vector2(2600, 150)), 50);

    test('with the separator\'s group omitted, no path lies on its segment',
        () async {
      final content = await export(f, omitOwners: {f.separatorGroup});
      expect(_pathsOnSegment(content, a, b), isEmpty);
    });

    test('without the set, the separator is drawn (dashes on its segment)',
        () async {
      final content = await export(f);
      expect(_pathsOnSegment(content, a, b), isNotEmpty);
    });
  });

  test(
      'compress: true (the app\'s path) reads back through FlateDecode to the '
      'same content', () async {
    final f = exportFixture(measurer: FlutterTextMeasurer());
    final plain = await export(f);
    final bytes = await exportPagePdf(
        document: f.document, page: f.page, fontBytes: fontBytes);
    final packed = PdfContent.parse(bytes, inflate: zlib.decode);
    expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF-'));
    expect(packed.operators.map((o) => o.toString()).toList(),
        plain.operators.map((o) => o.toString()).toList());
    expect([for (final t in packed.textRuns) t.string], ['Yatak Odası', 'WC']);
  });
}

/// A measurer whose advance depends on the style record's name.
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

/// A root line of [rgb] and [lineweight], added through a command.
void _addLine(
  DraftDocument doc,
  List<double> coords, {
  required int rgb,
  required int lineweight,
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(
    AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: doc.rootHandle,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: TrueColor(rgb),
        lineweight: lineweight,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List(0),
      ),
    ),
  );
}

bool _isRgb(List<double> c, int rgb) =>
    (c[0] - ((rgb >> 16) & 0xFF) / 255).abs() <= kPdfRounding &&
    (c[1] - ((rgb >> 8) & 0xFF) / 255).abs() <= kPdfRounding &&
    (c[2] - (rgb & 0xFF) / 255).abs() <= kPdfRounding;

PdfContentPath _strokeOfRgb(PdfContent c, int rgb) =>
    c.paths.where((p) => p.strokes && _isRgb(p.state.strokeRgb, rgb)).single;

/// The bound on a path's first point read back against a position computed
/// from the world, charging the worst case of the 5-decimal rule (spec 13
/// T-3) to every written number: the residual's six entries (each moves the
/// point by at most 5e-6 · |operand|), the operands themselves (times the
/// residual's linear part), the page height, and the arithmetic.
double _pointBound(PdfContent c, PdfContentPath p) {
  final m = _moveOperands(c, p);
  final r = _residualOf(p);
  final ax = m.x.abs(), ay = m.y.abs();
  final x =
      kPdfRounding * (ax + ay + 1) + kPdfRounding * (r.a.abs() + r.c.abs());
  final y = kPdfRounding * (ax + ay + 1) +
      kPdfRounding * (r.b.abs() + r.d.abs()) +
      kPdfRounding;
  return math.max(x, y) + 1e-9 * (1 + ax + ay);
}

/// The local operands of the path's `m`.
PdfXY _moveOperands(PdfContent c, PdfContentPath p) {
  for (var i = p.operatorIndex; i >= 0; i--) {
    final op = c.operators[i];
    if (op.name == 'm') {
      return (
        x: (op.operands[0] as num).toDouble(),
        y: (op.operands[1] as num).toDouble(),
      );
    }
  }
  throw StateError('no m before operator ${p.operatorIndex}');
}

/// The residual the path was drawn under: `CTM × pageSetUp⁻¹`, and the page
/// set-up `[1 0 0 −1 0 H]` is its own inverse. Only its linear part is used,
/// which H does not touch, so A4 landscape's H serves every page.
PdfContentMatrix _residualOf(PdfContentPath p) =>
    p.state.ctm.times(const PdfContentMatrix(1, 0, 0, -1, 0, 210 * 72 / 25.4));

/// Stroked paths whose first point is at [at] within [_pointBound].
List<PdfContentPath> _strokesStartingAt(PdfContent c, PdfXY at) => [
      for (final p in c.paths)
        if (p.strokes &&
            (p.subpaths.first.start.x - at.x).abs() <= _pointBound(c, p) &&
            (p.subpaths.first.start.y - at.y).abs() <= _pointBound(c, p))
          p,
    ];

/// The bound on `w × sqrt|det CTM|` against [expected] (the residual's
/// linear part, from the CTM).
double _widthBound(PdfContentPath p, double expected) {
  final r = _residualOf(p);
  return pdfWidthTolerance(expected, Transform2(r.a, r.b, r.c, r.d, r.e, r.f));
}

/// The index of the last `RG` written before [p] was painted.
int _strokeColourIndex(PdfContent c, PdfContentPath p) {
  for (var i = p.operatorIndex; i >= 0; i--) {
    if (c.operators[i].name == 'RG') return i;
  }
  throw StateError('no RG');
}

/// Paths every vertex of which lies on the segment [a]–[b] (within 0.01 pt,
/// far below a dash's length and far above the writer's rounding).
List<PdfContentPath> _pathsOnSegment(PdfContent c, PdfXY a, PdfXY b) {
  double dist(PdfXY q) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final t = (((q.x - a.x) * dx + (q.y - a.y) * dy) / (dx * dx + dy * dy))
        .clamp(0.0, 1.0);
    return math.sqrt(
        math.pow(q.x - (a.x + t * dx), 2) + math.pow(q.y - (a.y + t * dy), 2));
  }

  return [
    for (final p in c.paths)
      if (p.subpaths.isNotEmpty &&
          p.subpaths.every((s) => s.vertices.every((q) => dist(q) <= 0.01)))
        p,
  ];
}
