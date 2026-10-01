import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import '../viewport_transform.dart';

/// The camera an export paints a page through (spec 13 D2).
///
/// Its screen is the sheet itself: `(0, 0)` is the sheet's top-left corner,
/// y runs down, there is no margin, and one unit is `1 / pixelsPerPaperMm`
/// paper millimetres -- a point for the PDF, a pixel for the PNG.
@immutable
class PageCamera {
  const PageCamera({
    required this.camera,
    required this.size,
    required this.pixelsPerPaperMm,
  });

  /// World to sheet, y flipped.
  final ViewportTransform camera;

  /// The effective sheet in output units, **unrounded**: a PNG rounds its
  /// own pixel size, and the last column is then a part pixel at most.
  final Size size;

  /// The output unit per paper millimetre, `u`. Lineweight is paper-based,
  /// so this, not the camera's scale, sets a stroke's width.
  final double pixelsPerPaperMm;
}

/// The page camera for [page] at [unitsPerPaperMm] (`u`), spec D2:
/// with `S = sheetWorldRect(page)` and `k = u / page.scaleDenominator`,
/// `x' = (x - S.minX) * k` and `y' = (S.maxY - y) * k`.
///
/// Reads the page and nothing else: no screen camera, no viewport, no
/// extents. Throws [ArgumentError] when [unitsPerPaperMm] is not finite and
/// positive.
PageCamera pageCamera(PageComponent page, double unitsPerPaperMm) {
  if (!unitsPerPaperMm.isFinite || unitsPerPaperMm <= 0) {
    throw ArgumentError.value(
      unitsPerPaperMm,
      'unitsPerPaperMm',
      'must be finite and positive',
    );
  }
  final sheet = sheetWorldRect(page);
  final k = unitsPerPaperMm / page.scaleDenominator;
  return PageCamera(
    camera: ViewportTransform(
      worldToScreenMatrix: Transform2(
        k,
        0,
        0,
        -k,
        -sheet.minX * k,
        sheet.maxY * k,
      ),
    ),
    size: Size(
      page.effectiveWidthMm * unitsPerPaperMm,
      page.effectiveHeightMm * unitsPerPaperMm,
    ),
    pixelsPerPaperMm: unitsPerPaperMm,
  );
}
