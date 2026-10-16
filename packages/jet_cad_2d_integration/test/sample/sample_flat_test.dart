// 3a Task 25 (spec C3.7, C1.9, C6; D-34): the sample flat built by the plan
// library over the architecture kit. Ported from jet_cad_floor_plan/test/
// startup_plan_test.dart: the clamp constants' case (now the plan's
// constants) and the page-with-no-history case (the history after a build
// is the plan library's). The kit runs the other twelve.
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

// The kit's sample constants the page case reads (its lib/src/sample/
// sample_flat.dart), written out: this package imports public libraries
// only.
const double kPlanOriginX = 12000.0;
const double kPlanWidth = 14000.0;

/// The walls' extents: the union of every wall group's bounds (each at the
/// identity, SP5), so the dimensions' lines outside the plan are not in it.
Aabb2 wallExtents(DraftDocument doc) {
  var box = Aabb2.empty();
  for (final w in doc.components.withComponent<WallParams>()) {
    box = box.union(doc.definitionBounds(w));
  }
  return box;
}

/// Lets the controller's library load finish.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

PlanController flat() {
  final c = sampleFlatController();
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Spec D4's owed check: the constants against the document's own units.
  // At 1440 x 900 the fit scale is 0.95 * min(1440 / 14000, 900 / 9000) --
  // 0.095 px/mm -- so kPlanMinScale allows ~95x further out and
  // kPlanMaxScale ~1000x further in. Both decades are needed by a CAD user;
  // neither is absurd. The numbers are printed so the results note can
  // quote them.
  test('the clamp constants bracket the fitted scale by decades', () {
    final doc = flat().document;
    final fit = ViewportTransform.fit(doc.extents, const Size(1440, 900));
    // ignore: avoid_print
    print('STARTUP fit scale ${fit.scale} px/mm; '
        'min $kPlanMinScale (${fit.scale / kPlanMinScale}x out), '
        'max $kPlanMaxScale (${kPlanMaxScale / fit.scale}x in)');
    expect(fit.scale / kPlanMinScale, greaterThan(10));
    expect(kPlanMaxScale / fit.scale, greaterThan(100));
  });

  test(
      'the startup plan carries an A4 landscape page at 1:50 centred on the '
      'plan, in millimetres, with no history', () {
    final doc = flat().document;
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    expect(page.preset, SheetSize.a4);
    expect(page.orientation, PageOrientation.landscape);
    expect(page.scaleDenominator, 50);
    expect(page.displayUnit, DisplayUnit.meters);
    final rect = sheetWorldRect(page);
    // Centred on the plan, the walls' outer rectangle (19,000, 12,500):
    // the page is set before the rooms and dimensions, and spec 11 D17's
    // overall dimensions, outside the walls, do not move it (Ruling 11-14,
    // the controller's ruling).
    final extents = wallExtents(doc);
    expect(extents.center.x, 19000);
    expect(extents.center.y, 12500);
    expect(rect.center.x, closeTo(extents.center.x, 1e-9));
    expect(rect.center.y, closeTo(extents.center.y, 1e-9));
    expect(rect.minX, lessThan(kPlanOriginX));
    expect(rect.maxX, greaterThan(kPlanOriginX + kPlanWidth));
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(doc.commands.canUndo, isFalse, reason: 'Ruling 04-1');
  });

  test(
      'SF-controller sampleFlatController opens the sample flat clean: seven '
      'rooms named in English, 611 entities, nothing to undo, not dirty, no '
      'diagnostic once the library has loaded', () async {
    final c = flat();
    await settle();
    final doc = c.document;
    final rooms = doc.components.withComponent<RoomParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect([
      for (final r in rooms) doc.components.get<RoomParams>(r)!.name
    ], [
      'Hall',
      'Bedroom 1',
      'Bedroom 2',
      'Kitchen',
      'Bath',
      'Living',
      'Dining',
    ]);
    expect(doc.entities.liveCount, 611);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    expect(c.diagnostics.value, isEmpty);
  });
}
