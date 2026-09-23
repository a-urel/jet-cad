import 'dart:ui' show Size;

import 'package:floor_planner/startup_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
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

  test(
      'the startup plan carries an A4 landscape page at 1:50 centred on the '
      'plan, in millimetres, with no history', () {
    final doc = startupPlan(measurer);
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    expect(page.preset, SheetSize.a4);
    expect(page.orientation, PageOrientation.landscape);
    expect(page.scaleDenominator, 50);
    expect(page.displayUnit, DisplayUnit.meters);
    final rect = sheetWorldRect(page);
    final extents = doc.extents;
    expect(rect.center.x, closeTo(extents.center.x, 1e-9));
    expect(rect.center.y, closeTo(extents.center.y, 1e-9));
    expect(rect.minX, lessThan(kPlanOriginX));
    expect(rect.maxX, greaterThan(kPlanOriginX + kPlanWidth));
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(doc.commands.canUndo, isFalse, reason: 'Ruling 04-1');
  });

  test(
      'SP1 the furniture is eight filled regions with the furniture '
      'outline', () {
    final doc = startupPlan(measurer);
    final boundaries = <Handle>[];
    for (final slot in doc.entities.liveSlots) {
      final h = doc.entities.handleAt(slot);
      if (doc.fills.fillsOf(h).isNotEmpty) boundaries.add(h);
    }
    expect(boundaries, hasLength(8));
    for (final b in boundaries) {
      final r = doc.entities.read(doc.entities.slotOf(b)!);
      expect(r.color, const TrueColor(0x8A6D3B));
      expect(r.lineweight, 25);
      final fill = doc.fills.fillsOf(b).single;
      expect(
          doc.entities.read(doc.entities.slotOf(fill)!).color, kDraftFillColor);
    }
    expect(doc.entities.liveCount, 509, reason: 'Ruling 05-12: 523 − 14');
  });

  test('SP2 every fill draws over every floor-finish line (M-05r)', () {
    final doc = startupPlan(measurer);
    var maxFinish = 0, minFill = 1 << 62;
    for (final slot in doc.entities.liveSlots) {
      final r = doc.entities.read(slot);
      if (r.kind == EntityKind.fill && r.handle.value < minFill) {
        minFill = r.handle.value;
      }
      if (r.kind == EntityKind.line &&
          r.color == const TrueColor(0xBBBBBB) &&
          r.handle.value > maxFinish) {
        maxFinish = r.handle.value;
      }
    }
    expect(maxFinish, greaterThan(0));
    expect(minFill, greaterThan(maxFinish));
  });
}
