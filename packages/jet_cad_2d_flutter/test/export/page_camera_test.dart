import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/export_fixture.dart';

/// Spec 13 T-1: the page camera. Mutants M-13f (origin ignored) and M-13g
/// (no y flip) go red here.
void main() {
  const pt = 72 / 25.4;
  const px150 = 150 / 25.4;
  const tol = Tolerance.standard;

  // Every page is off the origin, so a camera that drops `originX/Y` moves
  // every corner.
  final cases = <(String, PageComponent, double)>[
    ('A4 landscape 1:50, the fixture', exportFixture().page, pt),
    (
      'A4 portrait 1:100',
      PageComponent(
        orientation: PageOrientation.portrait,
        scaleDenominator: 100,
        originX: -2500,
        originY: 4200,
      ),
      pt,
    ),
    (
      'A3 landscape 1:20',
      PageComponent(
        widthMm: 297,
        heightMm: 420,
        orientation: PageOrientation.landscape,
        scaleDenominator: 20,
        originX: 12000,
        originY: 800,
      ),
      px150,
    ),
  ];

  void expectPoint(Vector2 actual, double x, double y, String what) {
    expect(tol.eq(actual.x, x), isTrue, reason: '$what: x ${actual.x} != $x');
    expect(tol.eq(actual.y, y), isTrue, reason: '$what: y ${actual.y} != $y');
  }

  for (final (name, page, u) in cases) {
    group(name, () {
      // The sheet's corners, from the page's own fields (not through
      // `sheetWorldRect`, which the camera itself uses).
      final effW = page.orientation == PageOrientation.landscape
          ? page.heightMm
          : page.widthMm;
      final effH = page.orientation == PageOrientation.landscape
          ? page.widthMm
          : page.heightMm;
      final left = page.originX;
      final bottom = page.originY;
      final right = page.originX + effW * page.scaleDenominator;
      final top = page.originY + effH * page.scaleDenominator;
      final w = effW * u;
      final h = effH * u;

      test('the four sheet corners map to the output corners', () {
        final cam = pageCamera(page, u).camera;
        expectPoint(cam.worldToScreen(Vector2(left, top)), 0, 0, 'top-left');
        expectPoint(cam.worldToScreen(Vector2(right, top)), w, 0, 'top-right');
        expectPoint(
          cam.worldToScreen(Vector2(right, bottom)),
          w,
          h,
          'bottom-right',
        );
        expectPoint(
          cam.worldToScreen(Vector2(left, bottom)),
          0,
          h,
          'bottom-left',
        );
      });

      test('size and pixelsPerPaperMm', () {
        final c = pageCamera(page, u);
        expect(c.size.width, w);
        expect(c.size.height, h);
        expect(c.pixelsPerPaperMm, u);
      });

      test('a 1,000 mm world segment is 1000 / den * u long, x and y', () {
        final cam = pageCamera(page, u).camera;
        final a = Vector2(left + 1234.5, bottom + 987.25);
        final expected = 1000 / page.scaleDenominator * u;
        final alongX =
            cam.worldToScreen(a + Vector2(1000, 0)) - cam.worldToScreen(a);
        final alongY =
            cam.worldToScreen(a + Vector2(0, 1000)) - cam.worldToScreen(a);
        expectPoint(alongX, expected, 0, 'along x');
        // World y up is screen y down.
        expectPoint(alongY, 0, -expected, 'along y');
      });

      test('a world point above the sheet maps to a negative y', () {
        final cam = pageCamera(page, u).camera;
        final above = cam.worldToScreen(Vector2(left + 500, top + 250));
        expect(above.y, lessThan(0));
        expect(
          tol.eq(above.y, -250 / page.scaleDenominator * u),
          isTrue,
          reason: '${above.y}',
        );
        // And one below the sheet maps past its bottom.
        final below = cam.worldToScreen(Vector2(left + 500, bottom - 250));
        expect(below.y, greaterThan(h));
      });
    });
  }

  test('the size is unrounded at 150 dpi', () {
    final c = pageCamera(exportFixture().page, px150);
    // A4 landscape: 297 x 210 mm at 150 / 25.4 px per mm.
    expect(c.size.width, 297 * px150);
    expect(c.size.height, 210 * px150);
    expect(c.size.width, isNot(c.size.width.roundToDouble()));
    expect(c.size.height, isNot(c.size.height.roundToDouble()));
  });

  test('the fixture instance origin lands where the page puts it', () {
    // (7000, 5600) at 1:50 in pt: ((7000 - 3000) / 50, (9000 - 5600) / 50)
    // paper mm, the sheet's top at -1500 + 210 * 50 = 9000.
    final cam = pageCamera(exportFixture().page, pt).camera;
    expectPoint(
      cam.worldToScreen(Vector2(7000, 5600)),
      80 * pt,
      68 * pt,
      'instance origin',
    );
  });

  test('a non-finite or non-positive unit throws ArgumentError', () {
    final page = exportFixture().page;
    for (final u in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => pageCamera(page, u), throwsArgumentError, reason: '$u');
    }
  });
}
