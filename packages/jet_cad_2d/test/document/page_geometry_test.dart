import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  final page = PageComponent(
      originX: 7350, originY: -1230, scaleDenominator: 50); // A4 landscape

  test('the sheet rect is origin plus effective size times D', () {
    // M-04j (D ignored) and M-04e (orientation swapped).
    final rect = sheetWorldRect(page);
    expect(rect.minX, 7350);
    expect(rect.minY, -1230);
    expect(rect.maxX, 7350 + 297 * 50);
    expect(rect.maxY, -1230 + 210 * 50);
    final portrait =
        sheetWorldRect(page.copyWith(orientation: PageOrientation.portrait));
    expect(portrait.maxX, 7350 + 210 * 50);
  });

  test('100 % is pixelsPerPaperMm / D', () {
    // M-04n.
    const ppm = 96.0 / 25.4;
    expect(zoomOf(ppm / 50, page, ppm), closeTo(1.0, 1e-12));
    expect(zoomOf(ppm / 100, page, ppm), closeTo(0.5, 1e-12));
    expect(zoomOf(0.137, page.copyWith(scaleDenominator: 48), ppm),
        closeTo(0.137 * 48 / ppm, 1e-12));
  });

  test('page space is world minus origin, and back', () {
    final p = pageWorldOf(Vector2(8000, -230), page);
    expect(p.x, 650);
    expect(p.y, 1000);
    expect(worldOfPage(p, page).x, 8000);
    expect(worldOfPage(p, page).y, -230);
  });
}
