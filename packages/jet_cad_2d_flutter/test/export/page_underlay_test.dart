import 'dart:convert' show latin1;
import 'dart:io' show zlib;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/export_font.dart';
import '../support/pdf_tolerance.dart';

/// Plan colours spec PC-7: a page export's underlay, through the real
/// `exportPagePng` and `exportPagePdf(compress: false)`.
///
/// **The fixture is nowhere near the identity.** The placement is
/// `translation(4000.5, 2500.25) · rotation(0.7) · scale(1, -1)` -- turned,
/// mirrored and away from the origin -- and the L-shaped polygon is off-centre
/// and asymmetric in its own space, so a placement that is lost, whose linear
/// part is lost, or whose mirror is lost puts the L somewhere else. The page's
/// lower-left corner is world (3000, -1500) at 1:50, A4 landscape.
///
/// Every expected position is computed here from those literals and the
/// formula below, **not** through `pageCamera`, `Transform2` or the code
/// under test: a local point `(x, y)` is mirrored to `(x, -y)`, turned by 0.7
/// rad and moved by the translation,
///
///     wx = 4000.5 + x cos 0.7 + y sin 0.7
///     wy = 2500.25 + x sin 0.7 - y cos 0.7
///
/// and a world point is on the sheet at `((wx - 3000) / 50 · u,
/// (9000 - wy) / 50 · u)` (y down, the PNG) or `(…, (wy + 1500) / 50 · u)`
/// (y up, the PDF), `u` the output unit per paper millimetre.
///
/// Named mutants: M-C7a, M-C7b, M-PU-a, M-PU-b, M-PU-c.
void main() {
  // The L, closed (the first point repeated), off-centre and asymmetric.
  const lCorners = <(double, double)>[
    (200, 100),
    (900, 100),
    (900, 300),
    (450, 300),
    (450, 700),
    (200, 700),
  ];
  const circle = (cx: 600.5, cy: -350.25, r: 180.0);
  const teal = 0x9900897B; // teal at alpha 153
  const purple = 0x998E24AA; // purple at alpha 153
  const alpha = 153 / 255;

  final cos07 = math.cos(0.7), sin07 = math.sin(0.7);
  (double, double) world(double x, double y) => (
        4000.5 + x * cos07 + y * sin07,
        2500.25 + x * sin07 - y * cos07,
      );
  (double, double) pixel(double x, double y, int dpi) {
    final (wx, wy) = world(x, y);
    final u = dpi / 25.4;
    return ((wx - 3000) / 50 * u, (9000 - wy) / 50 * u);
  }

  (double, double) pdfPoint(double x, double y) {
    final (wx, wy) = world(x, y);
    const u = 72 / 25.4;
    return ((wx - 3000) / 50 * u, (wy + 1500) / 50 * u);
  }

  // The sheet's height in pt (A4 landscape, 210 mm), and the residual
  // `camera · placement` the PDF sink is handed, written out from the page's
  // numbers at u = 72 / 25.4 (the same algebra as PU5's): used only to size
  // the 5-decimal tolerance.
  const sheetH = 210 * 72 / 25.4;
  const kPdf = 72 / 25.4 / 50;
  final pdfResidual = Transform2(
    kPdf * cos07,
    -kPdf * sin07,
    kPdf * sin07,
    kPdf * cos07,
    kPdf * (4000.5 - 3000),
    kPdf * (9000 - 2500.25),
  );

  final placement = Transform2.translation(4000.5, 2500.25)
      .multiply(Transform2.rotation(0.7))
      .multiply(Transform2.scale(1, -1));

  PageUnderlayPolygon lShape(int argb) {
    final xy = Float64List.fromList([
      for (final (x, y) in lCorners) ...[x, y],
      200, 100, // the closing pair
    ]);
    return PageUnderlayPolygon(
      placement: placement,
      argb: argb,
      xy: xy,
      count: lCorners.length + 1,
      triangles: triangulateSimplePolygon(xy, lCorners.length + 1),
    );
  }

  PageUnderlayCircle disc(int argb) => PageUnderlayCircle(
        placement: placement,
        argb: argb,
        cx: circle.cx,
        cy: circle.cy,
        r: circle.r,
      );

  /// A document with the page and one thick black line through the L's wide
  /// base (local (600, 200)), so the draw order shows where the line crosses.
  ({DraftDocument document, PageComponent page}) fixture() {
    final doc = DraftDocument.empty(measurer: FlutterTextMeasurer());
    final page = PageComponent(
      orientation: PageOrientation.landscape,
      scaleDenominator: 50,
      originX: 3000,
      originY: -1500,
      background: 0xFFFFFFFF,
    );
    PageComponent.register(doc.components);
    doc.commands.execute(
      SetComponentCommand<PageComponent>(doc.rootHandle, page),
    );
    final (cx, cy) = world(600, 200);
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
          color: const TrueColor(0x000000),
          lineweight: 100,
          transparency: 0,
          flags: 0,
        ),
        payload: GeometryPayload(
          coords:
              Float64List.fromList([cx - 300, cy - 100, cx + 300, cy + 100]),
          scalars: Float64List(0),
        ),
      ),
    );
    return (document: doc, page: page);
  }

  Future<Uint8List> exportPng(
    WidgetTester tester,
    ({DraftDocument document, PageComponent page}) f, {
    List<PageUnderlayFill>? underlay,
  }) async =>
      (await tester.runAsync(() => underlay == null
          ? exportPagePng(document: f.document, page: f.page)
          : exportPagePng(
              document: f.document,
              page: f.page,
              underlay: underlay,
            )))!;

  Future<({int width, ByteData data})> decode(
    WidgetTester tester,
    Uint8List png,
  ) async =>
      (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(png);
        final frame = await codec.getNextFrame();
        codec.dispose();
        final image = frame.image;
        try {
          final data =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          return (width: image.width, data: data);
        } finally {
          image.dispose();
        }
      }))!;

  List<int> at(({int width, ByteData data}) img, (double, double) p) {
    final i = (p.$2.floor() * img.width + p.$1.floor()) * 4;
    return [for (var k = 0; k < 4; k++) img.data.getUint8(i + k)];
  }

  /// [rgb] over white at alpha 153: `round(153/255·s + (1 − 153/255)·255)`.
  List<int> overWhite(int rgb) => [
        for (final shift in [16, 8, 0])
          (alpha * ((rgb >> shift) & 0xFF) + (1 - alpha) * 255).round(),
      ];

  void expectNear(List<int> actual, List<int> expected, {String? reason}) {
    for (var k = 0; k < 3; k++) {
      expect((actual[k] - expected[k]).abs(), lessThanOrEqualTo(2),
          reason: '$reason: channel $k of $actual vs $expected');
    }
    expect(actual[3], 255, reason: reason);
  }

  group('PU1: the PNG', () {
    testWidgets(
        'the L is teal over white at its placed image, white outside it, '
        'the disc purple, and the drawing\'s line stays on top',
        (tester) async {
      final f = fixture();
      final img = await decode(
        tester,
        await exportPng(tester, f, underlay: [lShape(teal), disc(purple)]),
      );
      const dpi = 150;
      // Inside the tall arm, away from the line.
      expectNear(at(img, pixel(300, 600, dpi)), overWhite(0x00897B),
          reason: 'inside the L (300, 600)');
      // The L's base, right of the tall arm, away from the line.
      expectNear(at(img, pixel(850, 150, dpi)), overWhite(0x00897B),
          reason: 'inside the L (850, 150)');
      // Outside the L, inside its bounding box.
      expect(at(img, pixel(800, 600, dpi)), [255, 255, 255, 255],
          reason: 'outside the L (800, 600)');
      // The disc, off-centre, mirrored with the rest.
      expectNear(at(img, pixel(circle.cx, circle.cy, dpi)), overWhite(0x8E24AA),
          reason: 'the disc\'s centre');
      // Where the mirrored image of the disc would land if the mirror were
      // lost: the disc's local centre with y not negated.
      expect(at(img, pixel(circle.cx, -circle.cy, dpi)), [255, 255, 255, 255],
          reason: 'not at the unmirrored disc');
      // The line, thick and black, where it crosses the L's base: the
      // underlay is under the drawing.
      expect(at(img, pixel(600, 200, dpi)), [0, 0, 0, 255],
          reason: 'the line over the L');
    });
  });

  group('PU2: the PDF', () {
    final fontBytes = exportFontBytes();

    test(
        'two fills precede every stroke; the L is the six placed corners, '
        'teal; the disc is cubic', () async {
      final f = fixture();
      final bytes = await exportPagePdf(
        document: f.document,
        page: f.page,
        fontBytes: fontBytes,
        underlay: [lShape(teal), disc(purple)],
        compress: false,
      );
      final content = PdfContent.parse(bytes, inflate: zlib.decode);
      final fills = content.paths.where((p) => p.fills).toList();
      final strokes = content.paths.where((p) => p.strokes).toList();
      expect(fills, hasLength(2));
      expect(strokes, isNotEmpty);
      for (final fill in fills) {
        expect(fill.operatorIndex, lessThan(strokes.first.operatorIndex));
      }
      expect(fills[0].operatorIndex, lessThan(fills[1].operatorIndex));

      final l = fills[0];
      // The reader hands vertices already mapped through the CTM in force
      // (page space, y up), so they are compared as they come.
      final vertices = l.subpaths.single.vertices;
      // The stored loop repeats its first point: six corners and the pair.
      expect(vertices, hasLength(lCorners.length + 1));
      for (var i = 0; i <= lCorners.length; i++) {
        final (x, y) = lCorners[i % lCorners.length];
        final (px, py) = pdfPoint(x, y);
        // The `pdf` package writes every number to five decimals, the CTM's
        // entries included: the bound is the 5-decimal rule's own
        // (`pdfTolerance`), a few thousandths of a point at these magnitudes.
        final tol = pdfTolerance(x, y, pdfResidual, pageHeight: sheetH);
        expect(vertices[i].x, closeTo(px, tol), reason: 'corner $i x');
        expect(vertices[i].y, closeTo(py, tol), reason: 'corner $i y');
      }
      expect(l.state.fillRgb[0], closeTo(0, 1e-4));
      expect(l.state.fillRgb[1], closeTo(0x89 / 255, 1e-4));
      expect(l.state.fillRgb[2], closeTo(0x7B / 255, 1e-4));
      expect(l.state.fillAlpha, closeTo(alpha, 1e-4));

      final d = fills[1];
      expect(d.subpaths.single.segments, isNotEmpty);
      expect(d.subpaths.single.segments.every((s) => s.isCubic), isTrue,
          reason: 'a circle is Bezier arcs, not a polygon');
      // Its centre in page space: the mean of the four quadrant points.
      final points = d.subpaths.single.vertices;
      final (cx, cy) = pdfPoint(circle.cx, circle.cy);
      final meanX = points.take(4).map((p) => p.x).reduce((a, b) => a + b) / 4;
      final meanY = points.take(4).map((p) => p.y).reduce((a, b) => a + b) / 4;
      final centreTol =
          pdfTolerance(circle.cx, circle.cy, pdfResidual, pageHeight: sheetH) *
              2;
      expect(meanX, closeTo(cx, centreTol));
      expect(meanY, closeTo(cy, centreTol));
      expect(d.state.fillRgb[0], closeTo(0x8E / 255, 1e-4));
    });
  });

  /// [pdf] with the trailer's `/ID` (a fresh random 20-byte value per write,
  /// the `pdf` package's) blanked: the one part of two writes of one document
  /// that differs. Blanking shortens it, but the same way on both sides of a
  /// comparison, and the rest of the file is compared byte for byte.
  String withoutId(Uint8List pdf) => latin1
      .decode(pdf)
      .replaceAllMapped(RegExp(r'/ID\[<[0-9a-f]+><[0-9a-f]+>\]'), (m) => '/ID');

  group('PU3: an empty underlay changes nothing', () {
    test('the PDF bytes are those of the export without the parameter',
        () async {
      final f = fixture();
      final fontBytes = exportFontBytes();
      final without = await exportPagePdf(
        document: f.document,
        page: f.page,
        fontBytes: fontBytes,
        compress: false,
      );
      final empty = await exportPagePdf(
        document: f.document,
        page: f.page,
        fontBytes: fontBytes,
        underlay: const [],
        compress: false,
      );
      expect(withoutId(empty), withoutId(without));
      // And a non-empty one is not the same bytes: the comparison can fail.
      final filled = await exportPagePdf(
        document: f.document,
        page: f.page,
        fontBytes: fontBytes,
        underlay: [lShape(teal)],
        compress: false,
      );
      expect(withoutId(filled), isNot(withoutId(without)));
    });

    testWidgets('the PNG bytes are those of the export without the parameter',
        (tester) async {
      final f = fixture();
      final without = await exportPng(tester, f);
      final empty = await exportPng(tester, f, underlay: const []);
      expect(empty, without);
      final filled = await exportPng(tester, f, underlay: [lShape(teal)]);
      expect(filled, isNot(without));
    });

    test('drawPageUnderlay([]) does not touch the sink', () {
      final sink = RecordingDrawSink();
      drawPageUnderlay(
        sink,
        pageCamera(fixture().page, 150 / 25.4).camera,
        const [],
      );
      expect(sink.ops, isEmpty);
    });
  });

  group('PU4: a polygon that cannot be filled is refused', () {
    final xy = Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 0]);
    final tri = Int32List.fromList([0, 1, 2]);

    test('empty triangles', () {
      expect(
        () => PageUnderlayPolygon(
          placement: placement,
          argb: teal,
          xy: xy,
          count: 4,
          triangles: Int32List(0),
        ),
        throwsArgumentError,
      );
    });

    test('count * 2 beyond xy', () {
      expect(
        () => PageUnderlayPolygon(
          placement: placement,
          argb: teal,
          xy: xy,
          count: 5,
          triangles: tri,
        ),
        throwsArgumentError,
      );
    });

    test('fewer than four points (three and the repeat)', () {
      expect(
        () => PageUnderlayPolygon(
          placement: placement,
          argb: teal,
          xy: xy,
          count: 3,
          triangles: tri,
        ),
        throwsArgumentError,
      );
    });

    test('a well-formed polygon is accepted', () {
      expect(
        PageUnderlayPolygon(
          placement: placement,
          argb: teal,
          xy: xy,
          count: 4,
          triangles: tri,
        ).count,
        4,
      );
    });
  });

  group('PU5: the sink sees camera · placement per fill, in order', () {
    test('beginResidual, the fill, endResidual, for each fill', () {
      final page = fixture().page;
      final camera = pageCamera(page, 150 / 25.4).camera;
      final l = lShape(teal), d = disc(purple);
      final sink = RecordingDrawSink();
      drawPageUnderlay(sink, camera, [l, d]);

      // camera = (k, 0, 0, -k, -3000 k, 9000 k), k = u / 50, from the page's
      // numbers; placement = translation · rotation · scale(1, -1) written
      // out: the linear part (cos, sin, sin, -cos) and the translation.
      final k = 150 / 25.4 / 50;
      final expected = [
        k * cos07,
        -k * sin07,
        k * sin07,
        k * cos07,
        k * (4000.5 - 3000),
        k * (9000 - 2500.25),
      ];
      final ops = sink.ops;
      expect(ops, hasLength(6));
      for (final at in [0, 3]) {
        final begin = ops[at] as BeginResidualOp;
        final r = begin.residual;
        final actual = [r.a, r.b, r.c, r.d, r.e, r.f];
        for (var i = 0; i < 6; i++) {
          expect(actual[i], closeTo(expected[i], 1e-9),
              reason: 'component $i of op $at');
        }
        expect(ops[at + 2], isA<EndResidualOp>());
      }

      final polygon = ops[1] as FillPolygonOp;
      expect(polygon.points, l.xy.sublist(0, l.count * 2));
      expect(polygon.triangles, l.triangles.toList());
      expect(polygon.style.argb, teal);
      expect(ops[4], FillCircleOp(circle.cx, circle.cy, circle.r, d.styleOf));
      expect((ops[4] as FillCircleOp).style.argb, purple);
    });
  });
}

extension on PageUnderlayCircle {
  /// The style `drawPageUnderlay` is expected to hand the sink: the colour
  /// as given, no lineweight, the continuous linetype.
  ResolvedStyle get styleOf => ResolvedStyle(
        argb: argb,
        lineweightHundredths: 0,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1,
      );
}
