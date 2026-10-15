// Spec 3a C3.4: the separator as the kit declares it. Its type is not
// exported, has grips (two ends, band-trimmed over the kit's RoomInputs with
// the plan's F3, read at each drag) and no properties; its tool is S, made
// over the same RoomInputs, in today's palette place. And ND2's DASHED
// line (jet_cad_floor_plan/test/new_document_test.dart:49-62): the kit's
// prepare alone sets the record and adds no page, entity or history (spec
// 3a C1.3; ND2's registration and unit lines are Task 5's).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_inputs.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator/separator_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator/separator_tool.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator_linetype.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

// testCatalog() through room_fixture.dart's re-export (Task 16).
import '../support/room_fixture.dart';

Vector2 at(Grip g) => Vector2(g.x, g.y);

/// The distance from [p] to the line through [a] and [b], relative to [a]
/// (separator_tool_test.dart:90-94).
double distToLine(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a, q = p - a;
  return (q.x * d.y - q.y * d.x).abs() / d.length;
}

void main() {
  test(
      'SP-type the kit carries the separator: its type is not exported, has '
      'grips and no properties, colour or section; its tool S needs '
      'structure, components and geometry, has no settings, and is made '
      'over the services\' one RoomInputs', () {
    expect(architectureKit.types, contains(separatorPlanType));
    expect(separatorPlanType.id, ArchitectureTypes.separator);
    expect(SeparatorParams.componentTypeId, separatorPlanType.id);
    // M-SP-1: the type exported.
    expect(separatorPlanType.exported, isFalse);
    expect(separatorPlanType.grips, isNotNull);
    expect(separatorPlanType.properties, isEmpty);
    expect(separatorPlanType.hasColour, isFalse);
    expect(separatorPlanType.hasSection, isFalse);
    expect(architectureKit.tools, contains(separatorPlanTool));
    expect(separatorPlanTool.id, ArchitectureTools.separator);
    // M-SP-3: another letter.
    expect(separatorPlanTool.letter, 'S');
    expect(separatorPlanTool.needs,
        {Capability.structure, Capability.components, Capability.geometry});
    expect(separatorPlanTool.settings, isNull);
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    final services = FakePlanServices(document: doc, catalog: testCatalog());
    addTearDown(services.dispose);
    final tool = separatorPlanTool.create(services) as SeparatorTool;
    addTearDown(tool.dispose);
    expect(identical(tool.inputs, roomInputsOf(services)), isTrue);
  });

  test(
      'SP-order the kit\'s tools keep today\'s palette order (box, wall, '
      'door, window, gap, room, separator, dimension)', () {
    const today = [
      ArchitectureTools.box,
      ArchitectureTools.wall,
      ArchitectureTools.door,
      ArchitectureTools.window,
      ArchitectureTools.gap,
      ArchitectureTools.room,
      ArchitectureTools.separator,
      ArchitectureTools.dimension,
    ];
    final ids = [for (final t in architectureKit.tools) t.id];
    expect(ids, contains(ArchitectureTools.separator));
    // M-SP-4: the separator's tool listed first.
    expect(ids, [
      for (final id in today)
        if (ids.contains(id)) id,
    ]);
  });

  test(
      'SP-grips the type\'s grips: two stretch grips at the world ends; the '
      'end dragged into the north wall\'s band is trimmed to its inner face '
      'with the plan\'s object snap on and kept as placed with it off; the '
      'start stays exactly; movable', () {
    // The separator and every wall in their own turned groups at the
    // corpus's far origin; the drop's segment from the start is not
    // collinear with the separator, so the end that stays matters.
    final plan = buildPlan(boxWalls,
        seps: const [(3000.5, 1000.25, 3000.5, 3000.75)], place: corpusGroups);
    final doc = plan.doc;
    final sep = plan.seps.single;
    final p = plan.at(3600.75, 4030.5);
    for (final on in [true, false]) {
      final why = 'F3 ${on ? 'on' : 'off'}';
      final services = FakePlanServices(
          document: doc, catalog: testCatalog(), objectSnap: on);
      addTearDown(services.dispose);
      final grips = separatorPlanType.gripsFor(services)!;
      expect(grips.movable(doc, sep), isTrue);
      final [g0, g1] = grips.gripsOf(doc, sep);
      expect([g0.role, g1.role], [GripRole.stretch, GripRole.stretch]);
      expect((at(g0) - plan.at(3000.5, 1000.25)).length, lessThan(1e-6));
      expect((at(g1) - plan.at(3000.5, 3000.75)).length, lessThan(1e-6));
      final stored = doc.components.get<SeparatorParams>(sep)!;
      final depth = doc.commands.undoDepth;
      doc.commands.execute(grips.drag(doc, sep, g1, p)!);
      expect(doc.commands.undoDepth, depth + 1, reason: '$why: one step');
      final now = doc.components.get<SeparatorParams>(sep)!;
      expect((now.sx, now.sy), (stored.sx, stored.sy),
          reason: '$why: the start stays, exactly');
      final w = doc.tree.accumulatedTransform(sep).transformPoint(now.end);
      if (on) {
        // M-SP-7: the end trimmed from the wrong end.
        expect(distToLine(w, plan.at(0, 3900), plan.at(8000, 3900)),
            lessThan(1e-6),
            reason: '$why: on the north wall\'s inner face');
        expect(distToLine(w, at(g0), p), lessThan(1e-6),
            reason: '$why: on the segment from the start to the drop');
        expect((w - p).length, greaterThan(20),
            reason: '$why: out of the band');
      } else {
        // M-SP-2: the grips' object snap fixed on.
        expect((w - p).length, lessThan(1e-6), reason: '$why: as placed');
      }
      expect(driftOf(doc), isEmpty);
      doc.commands.undo();
      expect(doc.components.get<SeparatorParams>(sep), stored);
    }
  });

  test(
      'ND2 the set-up alone sets DASHED, and adds no page, entity or '
      'history (spec 12a D4): the kit\'s prepare, on a document whose page '
      'type is registered as the plan library registers it', () {
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    PageComponent.register(doc.components);
    architectureKit.prepare!(doc);
    expect(doc.components.get<PageComponent>(doc.rootHandle), isNull);
    expect(doc.entities.liveCount, 0);
    expect(doc.commands.undoDepth, 0);
    // M-SP-9: the kit without its prepare.
    expect(doc.tables.linetypes[ReservedHandles.dashedLinetype],
        kDashedLinetypeRecord);
  });
}
