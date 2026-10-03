// Spec 14a T8, T10: the label record, its height, and the stamp that keeps
// it upright. The stamp is checked the way it is drawn: the label's world
// linear map is the instance's linear part times the text's own,
// `R(rotation) · diag(widthFactor, 1)`, and must be the identity.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'table_fixture.dart';

/// The label's world linear map under [placement], from the stamp.
Transform2 worldLinear(Transform2 placement) {
  final s = tableLabelStamp(placement);
  final linear =
      Transform2(placement.a, placement.b, placement.c, placement.d, 0, 0);
  return linear
      .multiply(Transform2.rotation(s.rotation))
      .multiply(Transform2.scale(s.widthFactor, 1));
}

void main() {
  group('tableLabelStamp (T10)', () {
    const degrees = [0.0, 37.0, 90.0, 180.0, -123.0, 270.0, 179.0];
    for (final mirrored in [false, true]) {
      for (final deg in degrees) {
        test(
            'TL1 ${mirrored ? 'mirrored, ' : ''}$deg°: the label reads '
            'upright in world (M-14a-7, M-14a-8)', () {
          final p =
              placementAt(-4321, 2468, deg * math.pi / 180, mirrored: mirrored);
          final w = worldLinear(p);
          expect(w.a, closeTo(1, 1e-12));
          expect(w.b, closeTo(0, 1e-12));
          expect(w.c, closeTo(0, 1e-12));
          expect(w.d, closeTo(1, 1e-12));
          final s = tableLabelStamp(p);
          expect(s.rotation, greaterThan(-math.pi));
          expect(s.rotation, lessThanOrEqualTo(math.pi));
          expect(s.widthFactor, mirrored ? -1.0 : 1.0);
        });
      }
    }

    test('TL2 placements store clean values: no −0.0, exact quarter turns', () {
      final bp = Vector2(900, 700);
      final plain = tableLabelStamp(
          placementTransform(at: Vector2(3000, -1200), basePoint: bp));
      expect((plain.rotation, plain.widthFactor), (0.0, 1.0));
      expect(plain.rotation.isNegative, isFalse);

      final mirrored = tableLabelStamp(placementTransform(
          at: Vector2(3000, -1200), basePoint: bp, mirrored: true));
      expect((mirrored.rotation, mirrored.widthFactor), (0.0, -1.0));
      expect(mirrored.rotation.isNegative, isFalse);

      final quarter = tableLabelStamp(placementTransform(
          at: Vector2(3000, -1200), basePoint: bp, quarterTurns: 1));
      expect((quarter.rotation, quarter.widthFactor), (-math.pi / 2, 1.0));

      final half = tableLabelStamp(placementTransform(
          at: Vector2(3000, -1200), basePoint: bp, quarterTurns: 2));
      expect((half.rotation, half.widthFactor), (math.pi, 1.0));

      final threeMirrored = tableLabelStamp(placementTransform(
          at: Vector2(3000, -1200),
          basePoint: bp,
          quarterTurns: 3,
          mirrored: true));
      expect((threeMirrored.rotation, threeMirrored.widthFactor),
          (-math.pi / 2, -1.0));
    });

    test('TL3 restamp: nothing for a translation; new scalars for a turn', () {
      final p = placementAt(500, 600, kDeg37, mirrored: true);
      final payload = tableLabelPayload(
          anchor: Vector2(900, 700), height: 152, placement: p);
      final moved = Transform2.translation(-2500, 1250).multiply(p);
      expect(restampedTableLabel(payload, moved), isNull);

      final turned = Transform2.rotation(0.3).multiply(p);
      final next = restampedTableLabel(payload, turned)!;
      expect(next.coords, [900, 700]);
      expect(next.scalars[0], 152);
      final s = tableLabelStamp(turned);
      expect(next.scalars.sublist(1), [s.rotation, s.widthFactor]);
    });
  });

  group('tableLabelHeight (T8, M-14a-14)', () {
    GeometryPayload circle(double r) => GeometryPayload(
        coords: Float64List.fromList([400, 300]),
        scalars: Float64List.fromList([r]));
    GeometryPayload box(double w, double h) => GeometryPayload(
        coords: Float64List.fromList(
            [100, 200, 100 + w, 200, 100 + w, 200 + h, 100, 200 + h]),
        scalars: Float64List(0));

    test('TL4 written out by hand', () {
      expect(tableLabelHeight(EntityKind.circle, circle(190)), 152);
      expect(tableLabelHeight(EntityKind.circle, circle(300)), 200);
      expect(tableLabelHeight(EntityKind.polyline, box(2000, 400)), 160);
      expect(tableLabelHeight(EntityKind.polyline, box(1200, 750)), 200);
      expect(tableLabelHeight(EntityKind.polyline, box(450, 600)), 180);
      expect(tableLabelHeight(EntityKind.line, box(10, 10)), 200);
    });
  });

  group('the label record (T8)', () {
    test('TL5 tag, owner, layer 0, BYBLOCK, centred, width factor its own', () {
      final r = tableLabelRecord(
          handle: const Handle(0x5A0),
          instance: const Handle(0x59F),
          number: 'B4');
      expect(r.kind, EntityKind.attrib);
      expect(r.tag, 'TABLE');
      expect(r.text, 'B4');
      expect(r.owner, const Handle(0x59F));
      expect(r.layer, ReservedHandles.layerZero);
      expect(r.color, const ByBlockColor());
      expect(r.textStyle, ReservedHandles.standardTextStyle);
      expect(r.textAttrs & 0xF, TextJustifyH.centre.index);
      expect((r.textAttrs >> 4) & 0xF, TextJustifyV.middle.index);
      expect(r.textAttrs & (1 << 8), isNot(0),
          reason: 'the width factor is read only with bit 8');
    });

    test('TL6 the command anchors at the base point, sized by the first leaf',
        () {
      final doc = plan();
      final entry = entryOf(stoolSymbol);
      doc.commands.execute(placeSymbol(doc, entry,
          at: Vector2(-3100, 2200), quarterTurns: 1, mirrored: true));
      final instance = doc.tree.nodes.whereType<InstanceNode>().single;
      doc.commands.execute(addTableLabelCommand(doc,
          instance: instance.handle,
          definition: instance.definition,
          placement: instance.transform,
          number: '7'));
      final slot = doc.entities.liveSlots
          .firstWhere((s) => doc.entities.kindAt(s) == EntityKind.attrib);
      final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
      expect(payload.coords, [400, 300]);
      // L = R(90°) · diag(−1, 1) = [[0, −1], [−1, 0]]; the stamp
      // R(90°) · diag(−1, 1) is the same matrix, and L · L = I.
      expect(payload.scalars, [152, math.pi / 2, -1.0]);
      expect(
          doc.entities.handleAt(slot).value, greaterThan(instance.handle.value),
          reason: 'drawn above its table');
    });
  });
}
