// Ported from jet_cad_floor_plan/test/tables/table_label_test.dart; assertions unchanged.
//
// Spec 14a T8 (spec 2b S2 "The label"): the label record of a placed unit,
// its command, and the lowest-handle leaf. The stamp, the height and the
// payload are the kit's (Task 3); the restamp is Task 7's.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_2d_plan/src/units/unit_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/unit_fixtures.dart';

void main() {
  group('the label record (T8)', () {
    test('TL5 tag, owner, layer 0, BYBLOCK, centred, width factor its own', () {
      final r = unitLabelRecord(
          handle: const Handle(0x5A0),
          instance: const Handle(0x59F),
          text: 'B4');
      expect(r.kind, EntityKind.attrib);
      // The tag renamed (spec S2: "today's TABLE, renamed").
      expect(r.tag, 'UNIT');
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

    test(
        'TL6 the command anchors at the base point, sized by the first leaf '
        '(review F-1)', () {
      final doc = plan();
      final entry = entryOf(stoolSymbol);
      doc.commands.execute(placeSymbol(doc, entry,
          at: Vector2(-3100, 2200), quarterTurns: 1, mirrored: true));
      final instance = doc.tree.nodes.whereType<InstanceNode>().single;
      final command = addUnitLabelCommand(doc,
          instance: instance.handle,
          definition: instance.definition,
          placement: instance.transform,
          text: '7');
      doc.commands.execute(command);
      final slot = doc.entities.slotOf(command.record.handle)!;
      expect(doc.entities.textAt(slot), '7');
      expect(doc.entities.ownerAt(slot), instance.handle);
      final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
      expect(payload.coords, [400, 300]);
      // L = R(90°) · diag(−1, 1) = [[0, −1], [−1, 0]]; the stamp
      // R(90°) · diag(−1, 1) is the same matrix, and L · L = I.
      expect(payload.scalars, [152, math.pi / 2, -1.0]);
      expect(command.record.handle.value, greaterThan(instance.handle.value),
          reason: 'drawn above its table');
    });

    test('TL7 firstLeafOf is the lowest handle, whatever the slot order', () {
      final doc = plan();
      final early = doc.handleSeed.next();
      final owner = doc.handleSeed.next();
      doc.tree.addDefinition(Definition(
          handle: owner,
          name: 'D',
          basePoint: Vector2(10, 20),
          children: const []));
      AddEntityCommand line(Handle h, double y) => AddEntityCommand(
          record: unitLabelRecord(handle: h, instance: owner, text: 'x')
              .copyWith(kind: EntityKind.line),
          payload: GeometryPayload(
              coords: Float64List.fromList([0, y, 100, y]),
              scalars: Float64List(0)));
      doc.commands.execute(line(doc.handleSeed.next(), 5));
      doc.commands.execute(line(early, 9));
      expect(firstLeafOf(doc, owner)!.payload.coords, [0, 9, 100, 9]);
    });
  });
}
