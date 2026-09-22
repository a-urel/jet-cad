import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../geometry/aabb2.dart';
import 'page_component.dart';

/// The sheet in world millimetres: origin plus the effective size at 1:D.
Aabb2 sheetWorldRect(PageComponent page) => Aabb2.raw(
      page.originX,
      page.originY,
      page.originX + page.effectiveWidthMm * page.scaleDenominator,
      page.originY + page.effectiveHeightMm * page.scaleDenominator,
    );

/// 1.0 is 100 %: the sheet at physical size on a 96-dpi screen (spec D4).
double zoomOf(
        double pxPerWorldMm, PageComponent page, double pixelsPerPaperMm) =>
    pxPerWorldMm * page.scaleDenominator / pixelsPerPaperMm;

/// World minus the sheet origin — what the rulers read (spec D5).
Vector2 pageWorldOf(Vector2 world, PageComponent page) =>
    Vector2(world.x - page.originX, world.y - page.originY);

Vector2 worldOfPage(Vector2 pageMm, PageComponent page) =>
    Vector2(pageMm.x + page.originX, pageMm.y + page.originY);
