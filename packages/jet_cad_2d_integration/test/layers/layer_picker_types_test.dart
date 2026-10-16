// Task 7 of 3b (audit docs/superpowers/specs/2026-10-16-architecture-demo-
// test-audit.md, "layers/layer_picker_test.dart", the SPLIT row "every
// registered parametric type (box, wall, opening, separator, room,
// dimension) alone"): the -open half. Ported from apps/floor_planner/test/
// layers/layer_picker_test.dart:403-451.
//
// The six architecture types, alone, enable the picker and show their
// layer; one of them moves with one command. The intent half (a registered
// parametric type, whatever it is, is a layer-bearing object) is jet_cad_2d_
// plan's panels/layer_picker_test.dart "every registered parametric type
// (the mark kit's one type, on four layers) alone".
//
// P-6's layers `A` (ACI 1) and `B` (ACI 5, locked) with a wall and a room on
// A, a door and a dimension on B; a visible layer D (ACI 2) with a box on it
// (turned, off the origin); a separator on layer 0 (turned, off the origin).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_rig.dart';
import '../support/layer_plan.dart';
import '../support/plans.dart';

const PlanStringsEn _en = PlanStringsEn();

/// Every entity record the parametric object [group] owns, with its layer.
List<Handle> childLayers(DraftDocument doc, Handle group) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.layerAt(slot),
    ];

bool pickerEnabled(WidgetTester tester) =>
    tester.widget<PopupMenuButton<Handle>>(byKey('layer-picker')).enabled;

String pickerTooltip(WidgetTester tester) => tester
    .widget<Tooltip>(find.ancestor(
        of: byKey('layer-picker'), matching: find.byType(Tooltip)))
    .message!;

String valueOf(WidgetTester tester) =>
    tester.widget<Text>(byKey('layer-picker-value')).data!;

void main() {
  testWidgets(
      'every registered parametric type (box, wall, opening, separator, room, '
      'dimension) alone: the picker is enabled and shows the object\'s layer '
      '(Task 10 review finding 1, R-own-5)', (tester) async {
    late LayerPlan l;
    late Handle d, box, separator;
    final json = planWith((doc) {
      l = layerFixture(doc);
      final zero = doc.tables.layers[ReservedHandles.layerZero]!;
      d = doc.handleSeed.next();
      doc.commands.execute(AddLayerCommand(LayerRecord(
          handle: d,
          name: 'D',
          color: const IndexedColor(2),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency)));
      box = addObjectOn(doc, const BoxParams(1200.5, 800.25), d,
          at: Transform2.translation(-6400.5, 9100.25)
              .multiply(Transform2.rotation(0.7)));
      separator = addObjectOn(
          doc,
          const SeparatorParams(150.5, -320.25, 1650.75, 410.5),
          ReservedHandles.layerZero,
          at: Transform2.translation(-9800.25, -7300.5)
              .multiply(Transform2.rotation(-0.3)));
    });
    final c = architectureController(json: json);
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    final doc = c.document;
    final cases = <(String, Handle, String, String)>[
      ('box', box, 'D', ArchitectureTypes.box),
      ('wall', l.walls[0], 'A', ArchitectureTypes.wall),
      ('opening', l.openings[0], 'B', ArchitectureTypes.opening),
      ('separator', separator, '0', ArchitectureTypes.separator),
      ('room', l.room!, 'A', ArchitectureTypes.room),
      ('dimension', l.dimension!, 'B', ArchitectureTypes.dimension),
    ];
    for (final (type, h, name, typeId) in cases) {
      expect(c.typeOf(h)?.id, typeId, reason: '$type: premise: its type');
      c.activeSelection.replace([SelectionKey.root(h)]);
      await tester.pump();
      expect(pickerEnabled(tester), isTrue, reason: type);
      expect(pickerTooltip(tester), isNot(_en.plainGroupNoLayer), reason: type);
      expect(valueOf(tester), name, reason: type);
    }
    // And one of them moves: the separator, from layer 0 to D.
    c.activeSelection.replace([SelectionKey.root(separator)]);
    await tester.pump();
    final depth = doc.commands.undoDepth;
    await tester.tap(byKey('layer-picker'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('layer-picker-item-${d.toHex()}'));
    await tester.pumpAndSettle();
    expect(doc.commands.undoDepth, depth + 1);
    expect(objectLayerOf(doc, separator), d);
    expect(childLayers(doc, separator), isNotEmpty, reason: 'premise');
    expect(childLayers(doc, separator).toSet(), {d});
  });
}
