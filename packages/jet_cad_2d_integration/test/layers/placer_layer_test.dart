// Ported from jet_cad_floor_plan/test/layers/tools_layer_test.dart (3a Task 26, spec C6); assertions unchanged.
//
// Spec 12b D2's creation and D7: each parametric tool commits its object
// with `ObjectLayer(drawingLayer(document))` in the creation compound, so
// the object and every child the parametric system generates for it are on
// the effective current layer, in one undo step; the symbol placer writes
// that layer on the instance, and the definition's leaves stay on layer 0.
//
// P-6's fixture: the walls on `A`, the current layer `B` (locked: D3 keeps
// a locked layer usable), so the expected layer is neither layer 0 nor the
// walls' own; every click is off the origin, at the corpus far origin turned
// 23°, every wall in its own rotated group.
//
// The placer's case (:230-256); the other nine run in the kit. The plan's
// placer is not exported: the symbol is the furniture library's
// `architecture.sofa.three`, armed and placed with the Symbol tool as a
// host's user places it, turned once (R) and mirrored (M) by the armed
// tool's own keys (ruling IT-R10).
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_rig.dart';
import '../support/layer_plan.dart';
import '../support/plans.dart' show planWith;

void main() {
  testWidgets(
      'the symbol placer puts the instance on the current layer, in one undo '
      'step; the definition\'s leaves stay on layer 0', (tester) async {
    late LayerPlan l;
    final c = PlanController(
        kits: [architectureKit],
        json: planWith((doc) {
          l = layerFixture(doc);
          doc.commands.execute(SetCurrentLayerCommand(l.b));
        }));
    addTearDown(c.dispose);
    final doc = c.document;
    expect(drawingLayer(doc), l.b, reason: 'premise: B is current');
    await pumpPlanEditor(tester, c);
    await frameOn(tester, c, l.at(3000.5, 2000.25), scale: 0.25);
    await focusCanvas(tester);
    for (var i = 0;
        i < 400 && c.symbolsState.value != SymbolsState.ready;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    final entry = c.symbols
        .firstWhere((s) => s.component.key == 'architecture.sofa.three')
        .entry;
    expect(
        c.armSymbol(c.symbols
            .firstWhere((s) => s.component.key == 'architecture.sofa.three')),
        isTrue);
    await tester.pump();
    await pressKey(tester, LogicalKeyboardKey.keyR);
    await pressKey(tester, LogicalKeyboardKey.keyM);
    final depth = doc.commands.undoDepth;
    await mouseClick(tester, globalAt(tester, c, l.at(3000.5, 2000.25)));
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    final instance = doc.tree.nodes.whereType<InstanceNode>().single;
    expect(instance.layer, l.b, reason: 'the instance takes the layer');
    final leaves = [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == instance.definition) slot
    ];
    expect(leaves, hasLength(entry.leaves.length),
        reason: 'premise: the definition was copied');
    for (final slot in leaves) {
      expect(doc.entities.layerAt(slot), ReservedHandles.layerZero,
          reason: 'a definition leaf stays on layer 0 (the library\'s rule)');
    }
    doc.commands.undo();
    expect(doc.tree.nodes.whereType<InstanceNode>(), isEmpty);
  });
}
