// Spec 3a C3.1: the box as the kit declares it. Its two properties are
// lengths above zero, the bound strict and refused in write (today's
// selection_panel.dart:415-417), gated by reshape (today's _capable,
// :384-390); its type has no grips, colour or section and is exported; its
// tool is B. The box sits in a group turned 30 degrees, off the origin.
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/box/box_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/box/box_tool.dart';

import '../support/catalog.dart';

final Transform2 atA = Transform2.translation(7010.5, 3020.25)
    .multiply(Transform2.rotation(math.pi / 6));

/// The panel's words (English, no kit words: the box's fields need none).
final KitWords words = KitNamesWords(KitNames.empty, () => const Locale('en'));

void main() {
  const a = Handle(1000);

  test(
      'BX-props width and height: a positive length commits one step, zero, '
      '-0.0 and a negative are refused in write; both need reshape', () {
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    installParametric(doc);
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: a,
          parent: doc.rootHandle,
          transform: atA,
          children: const [])),
      SetComponentCommand<BoxParams>(a, const BoxParams(1200.5, 800.25)),
    ], label: 'Add box'));
    final [width, height] = boxPlanType.fieldsOf(doc, a, words);
    expect(width.wordId, 'property:architecture.box.width');
    expect(height.wordId, 'property:architecture.box.height');
    expect((width.value, height.value), (1200.5, 800.25));
    for (final f in [width, height]) {
      // M-BX-2: a side without its gate.
      expect(f.spec.gate, PlanGate.reshape, reason: f.wordId);
      for (final bad in [0.0, -0.0, -3.0]) {
        // M-BX-1: the bound inclusive (`v >= 0`).
        expect(() => boxPlanType.commitField(doc, a, f, bad, words),
            throwsArgumentError,
            reason: '${f.wordId} $bad');
      }
    }
    final depth = doc.commands.undoDepth;
    doc.commands.execute(boxPlanType.commitField(doc, a, width, 1e-3, words));
    doc.commands
        .execute(boxPlanType.commitField(doc, a, height, 950.75, words));
    expect(doc.components.get<BoxParams>(a), const BoxParams(1e-3, 950.75));
    expect(doc.commands.undoDepth, depth + 2, reason: 'one step each');
    expect(ParametricSystem(doc, testCatalog()).drift(), isEmpty);
  });

  test(
      'BX-kit the kit carries the box: its type (no grips, colour or '
      'section; exported) and its tool B, which needs structure, components '
      'and geometry, has no settings and makes a BoxTool', () {
    expect(architectureKit.types, contains(boxPlanType));
    expect(boxPlanType.id, ArchitectureTypes.box);
    expect(BoxParams.componentTypeId, boxPlanType.id);
    expect(boxPlanType.grips, isNull);
    expect(boxPlanType.hasColour, isFalse);
    expect(boxPlanType.hasSection, isFalse);
    expect(boxPlanType.exported, isTrue);
    expect(architectureKit.tools, contains(boxPlanTool));
    expect(boxPlanTool.id, ArchitectureTools.box);
    // M-BX-3: another letter.
    expect(boxPlanTool.letter, 'B');
    expect(boxPlanTool.needs,
        {Capability.structure, Capability.components, Capability.geometry});
    expect(boxPlanTool.settings, isNull);
    expect(architectureKit.propertyIds,
        containsAll(['architecture.box.width', 'architecture.box.height']));
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    final services = FakePlanServices(document: doc);
    addTearDown(services.dispose);
    final tool = boxPlanTool.create(services);
    addTearDown(tool.dispose);
    expect(tool, isA<BoxTool>());
  });
}
