import 'dart:ui' show Size;

import 'package:floor_planner/startup_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  test('is at the target scale: between 500 and 1,000 entities', () {
    final doc = startupPlan(measurer);
    expect(doc.entities.liveCount, inInclusiveRange(500, 1000));
  });

  // The degenerate fixture this repository names: a drawing centred on the
  // origin. The extents must not contain (0, 0) and must not be symmetric
  // about either axis.
  test('is off-origin and not axis-symmetric', () {
    final doc = startupPlan(measurer);
    final e = doc.extents;
    expect(e.minX > 0 || e.maxX < 0, isTrue, reason: 'x span excludes 0');
    expect(e.minY > 0 || e.maxY < 0, isTrue, reason: 'y span excludes 0');
    expect(e.minX, isNot(-e.maxX));
    expect(e.minY, isNot(-e.maxY));
    expect(e.maxX - e.minX, isNot(e.maxY - e.minY),
        reason: 'not square either');
  });

  test('the outer walls close: the extents are the outer rectangle', () {
    final doc = startupPlan(measurer);
    final e = doc.extents;
    expect(e.minX, kPlanOriginX);
    expect(e.minY, kPlanOriginY);
    expect(e.maxX, kPlanOriginX + kPlanWidth);
    expect(e.maxY, kPlanOriginY + kPlanHeight);
  });

  // Spec D4's owed check: the constants against the document's own units.
  // At 1440 x 900 the fit scale is 0.95 * min(1440 / 14000, 900 / 9000) --
  // 0.095 px/mm -- so kMinScale allows ~95x further out and kMaxScale
  // ~1000x further in. Both decades are needed by a CAD user; neither is
  // absurd. The numbers are printed so the results note can quote them.
  test('the clamp constants bracket the fitted scale by decades', () {
    final doc = startupPlan(measurer);
    final fit = ViewportTransform.fit(doc.extents, const Size(1440, 900));
    // ignore: avoid_print
    print('STARTUP fit scale ${fit.scale} px/mm; '
        'min $kMinScale (${fit.scale / kMinScale}x out), '
        'max $kMaxScale (${kMaxScale / fit.scale}x in)');
    expect(fit.scale / kMinScale, greaterThan(10));
    expect(kMaxScale / fit.scale, greaterThan(100));
  });
}
