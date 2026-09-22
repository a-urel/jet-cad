import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/page_fixture.dart';

void main() {
  test('fitToPage fits the sheet rect, not the extents', () {
    // M-04k's render half.
    final page = standardPage();
    final fitted = fitToPage(page, kChromeSize);
    final expected = ViewportTransform.fit(sheetWorldRect(page), kChromeSize);
    expect(fitted.scale, closeTo(expected.scale, 1e-12));
    final centre = sheetWorldRect(page).center;
    final s = fitted.worldToScreen(centre);
    expect(s.x, closeTo(400, 1e-6));
    expect(s.y, closeTo(300, 1e-6));
    expect(fitted.worldToScreen(Vector2(page.originX, page.originY)).y,
        greaterThan(300),
        reason: 'y flips: the bottom-left is below centre');
  });
}
