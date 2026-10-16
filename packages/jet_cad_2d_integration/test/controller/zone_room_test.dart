// ignore_for_file: invalid_use_of_internal_member
// R-16's room line of the controller's framing tests (3a Task 28, D-38;
// rulings R-P9, R-P18, IA-R6): CZ1 (jet_cad_floor_plan/test/host/
// controller_test.dart:559-586), ported whole over the zone fixture with
// its room named `7` (`zone_plan.dart`). `fitToTables` is the plan's
// `fitToUnits`; `framingFor` is `@internal` (R-P9); today's
// `frameTables(bound, size)` is the plan's `frameUnits`, internal, so the
// oracle is a copy of it ([frameUnits] below); a table's label is its UNIT
// label (`units.dart`'s `unitsLabelled`). Assertions unchanged.
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kUnitLabelTag;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/units.dart' show fxKit, unitsLabelled;
import '../support/zone_plan.dart';

/// The floor a framing shows round its units, per side, and the least span
/// it shows per axis, in millimetres; the default zoom bounds (copied from
/// jet_cad_2d_plan/lib/src/units/unit_fit.dart:15-19 and
/// lib/src/controller/camera_bounds.dart:13-14).
const double kUnitFitMarginMm = 500, kUnitFitMinSpanMm = 3000;
const double kPlanMinScale = 0.001, kPlanMaxScale = 100.0;

/// The camera that frames [box], a non-empty world bound of units, in a
/// drawing area of [viewport] (zone spec Z3): the plan's `frameUnits`,
/// copied as the oracle (jet_cad_2d_plan/lib/src/units/unit_fit.dart:
/// 21-64): [box] grown by [kUnitFitMarginMm] per side, then about its
/// centre to at least [kUnitFitMinSpanMm] per axis, fitted as
/// [ViewportTransform.fit] fits (5 % margin, y flipped), its scale clamped
/// to `[minScale, maxScale]` about the same centre.
ViewportTransform frameUnits(Aabb2 box, Size viewport,
    {double minScale = kPlanMinScale, double maxScale = kPlanMaxScale}) {
  assert(!box.isEmpty, 'frameUnits needs a non-empty box');
  var minX = box.minX - kUnitFitMarginMm, maxX = box.maxX + kUnitFitMarginMm;
  var minY = box.minY - kUnitFitMarginMm, maxY = box.maxY + kUnitFitMarginMm;
  final cx = minX / 2 + maxX / 2, cy = minY / 2 + maxY / 2;
  if (maxX - minX < kUnitFitMinSpanMm) {
    minX = cx - kUnitFitMinSpanMm / 2;
    maxX = cx + kUnitFitMinSpanMm / 2;
  }
  if (maxY - minY < kUnitFitMinSpanMm) {
    minY = cy - kUnitFitMinSpanMm / 2;
    maxY = cy + kUnitFitMinSpanMm / 2;
  }
  final s = ViewportTransform.fit(Aabb2.raw(minX, minY, maxX, maxY), viewport)
      .worldToScreenMatrix
      .a;
  final clamped = s.clamp(minScale, maxScale);
  final mx = minX / 2 + maxX / 2, my = minY / 2 + maxY / 2;
  return ViewportTransform(
      worldToScreenMatrix: Transform2(
          clamped,
          0,
          0,
          -clamped,
          viewport.width / 2 - clamped * mx,
          viewport.height / 2 + clamped * my));
}

/// Today's `frameTables`.
ViewportTransform frameTables(Aabb2 box, Size viewport) =>
    frameUnits(box, viewport);

PlanController controller(WidgetTester tester, String json) {
  final c = PlanController(kits: [architectureKit, fxKit()], json: json);
  addTearDown(c.dispose);
  return c;
}

/// Unit [n]'s instance.
InstanceNode tableNode(DraftDocument doc, String n) =>
    doc.tree[unitsLabelled(doc, n).single]! as InstanceNode;

/// Unit [n]'s UNIT label (today's `TableSurvey...withNumber(n).single.label`).
Handle labelOf(DraftDocument doc, String n) {
  final instance = unitsLabelled(doc, n).single;
  return [
    for (final slot in doc.entities.liveSlots)
      if (doc.entities.ownerAt(slot) == instance &&
          doc.entities.read(slot).tag == kUnitLabelTag)
        doc.entities.handleAt(slot),
  ].single;
}

void main() {
  PlanController zoned(WidgetTester tester) {
    final c = controller(tester, zonePlanJson());
    c.camera.value = zoneCamera();
    return c;
  }

  const zoneSize = Size(1200, 900);

  testWidgets(
      'CZ1 a turned, mirrored table 40 m off the origin is framed by the '
      'four corners of its box; table " 7 " by 7, not the TEXT or the room '
      'named 7 (M-Z1, M-Z3)', (tester) async {
    final c = zoned(tester);
    final d = c.document;
    final three = tableNode(d, '3').transform;
    expect(three.determinant, lessThan(0), reason: 'premise: mirrored');
    expect(three.b, isNot(0), reason: 'premise: turned');
    expect(three.e.abs(), greaterThan(30000), reason: 'premise: off origin');
    expect(c.fitToUnits({'3'}), isTrue);
    expectCamera(
        c.framingFor(zoneSize), frameTables(boundOf(d, {'3'}), zoneSize));

    final label = labelOf(d, '7');
    expect(d.entities.read(d.entities.slotOf(label)!).text, ' 7 ',
        reason: 'premise: labelled with spaces');
    final seven = boundOf(d, {'7'});
    final looks = sevenTexts(d);
    expect(looks, hasLength(2), reason: 'premise: the TEXT and the room name');
    for (final p in looks) {
      expect(seven.expandedBy(15000).containsPoint(p), isFalse,
          reason: 'premise: far from table 7');
    }
    c.camera.value = zoneCamera();
    expect(c.fitToUnits({'7'}), isTrue);
    expectCamera(c.framingFor(zoneSize), frameTables(seven, zoneSize));
  });
}
