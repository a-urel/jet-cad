// 3a Task 12 (spec C3.2, C1.5, C2): the wall as the kit declares it -- its
// plan type's fields, its tool's settings and letter, the tool made over a
// plan's services (its settings read there, the shared band cache), the
// grips over the services' live walls, and the kit carrying both. Walls at
// the far origin in their own turned groups, or spokes of a node at a
// turned hub.
import 'dart:ui' show Locale;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/kit.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_bands.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';
import '../support/wall_shell.dart';

/// A primary press at [world], as the canvas hands one to a tool.
ToolPointerEvent pressEvent(Vector2 world) => ToolPointerEvent(
    screen: Offset.zero,
    world: world,
    pointer: 1,
    buttons: kPrimaryButton,
    shift: false,
    control: false,
    meta: false,
    alt: false,
    pickRadiusWorld: 1);

/// [doc]'s tool context: a unit camera, object snap on, no page.
ToolContext contextOf(DraftDocument doc) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  final selection = SelectionController(doc);
  addTearDown(() {
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return ToolContext(
      document: doc, index: index, camera: camera, selection: selection);
}

/// [command]'s members' handles: a grip drag's walls, in order.
List<Handle> handlesOf(DraftCommand command) => [
      for (final m in (command as CompoundCommand).children)
        (m as SetComponentCommand<WallParams>).handle,
    ];

/// The panel's words (English, no kit words: the fields need none).
final KitWords words = KitNamesWords(KitNames.empty, () => const Locale('en'));

void main() {
  test(
      'WT-type the wall type: thickness, strict as isWallThickness in its '
      'write, and justification of left, centre and right, each needing '
      'reshape, under property:architecture.wall.*', () {
    final doc = wallDoc();
    const h = Handle(1300);
    doc.commands.execute(addWall(
        doc, h, plan(-1200, 300), plan(1800, 900), 115, Justification.left));
    final p = doc.components.get<WallParams>(h)!;
    final [thickness, justification] = wallPlanType.fieldsOf(doc, h, words);
    expect([
      thickness.wordId,
      justification.wordId
    ], [
      'property:architecture.wall.thickness',
      'property:architecture.wall.justification',
    ]);
    expect([thickness.spec.gate, justification.spec.gate],
        [PlanGate.reshape, PlanGate.reshape]);
    expect([thickness.value, justification.value], [115, Justification.left]);
    expect(
        switch (justification.spec) {
          ChoiceProperty(:final values) => values,
          _ => null,
        },
        Justification.values);
    for (final t in [wallJoin.linear, 0.0, -115.0, nextUp(kWallMaxThickness)]) {
      expect(() => thickness.commit!(t), throwsArgumentError, reason: '$t');
      expect(() => wallPlanType.commitField(doc, h, thickness, t, words),
          throwsArgumentError,
          reason: '$t');
    }
    for (final t in [nextUp(wallJoin.linear), kWallMaxThickness, 240.5]) {
      expect(thickness.commit!(t), p.copyWith(thickness: t), reason: '$t');
    }
    expect(justification.commit!(Justification.right),
        p.copyWith(justification: Justification.right));
    expect(wallPlanType.id, ArchitectureTypes.wall);
    expect(wallPlanType.parametric, isA<WallType>());
  });

  test(
      "WT-settings the Wall tool: W, the commits' needs, settings from 200 "
      'centre, the same strict thickness and the three justifications, '
      'ungated, under property:architecture.wall.*; the tool made over a '
      "plan's services draws with the settings it reads there", () {
    expect(wallPlanTool.id, ArchitectureTools.wall);
    expect(wallPlanTool.letter, 'W');
    expect(wallPlanTool.needs, {
      Capability.structure,
      Capability.components,
      Capability.geometry,
    });
    final settings = wallPlanTool.settings!;
    expect(settings.initial, const WallSettings());
    Object? stored;
    final [thickness, justification] = settings.fieldsOf(
        const WallSettings(thickness: 150, justification: Justification.right),
        (v) => stored = v,
        toolId: ArchitectureTools.wall);
    expect([
      thickness.wordId,
      justification.wordId
    ], [
      'property:architecture.wall.thickness',
      'property:architecture.wall.justification',
    ]);
    expect([thickness.spec.gate, justification.spec.gate], [null, null]);
    expect([thickness.value, justification.value], [150, Justification.right]);
    expect(() => thickness.commit!(wallJoin.linear), throwsArgumentError);
    expect(() => thickness.commit!(nextUp(kWallMaxThickness)),
        throwsArgumentError);
    expect(stored, isNull);
    thickness.commit!(kWallMaxThickness);
    expect(
        stored,
        const WallSettings(
            thickness: kWallMaxThickness, justification: Justification.right));
    justification.commit!(Justification.left);
    expect(stored,
        const WallSettings(thickness: 150, justification: Justification.left));

    final doc = wallDoc();
    final services =
        FakePlanServices(document: doc, catalog: testCatalog(), settings: {
      ArchitectureTools.wall:
          const WallSettings(thickness: 115, justification: Justification.left),
    });
    addTearDown(services.dispose);
    final tool = wallPlanTool.create(services);
    addTearDown(tool.dispose);
    final ctx = contextOf(doc);
    tool.onPointerDown(pressEvent(plan(0, 0)), ctx);
    tool.onPointerDown(pressEvent(plan(3000, 400)), ctx);
    final h = walls(doc).single;
    final p = doc.components.get<WallParams>(h)!;
    expect([p.thickness, p.justification], [115, Justification.left]);
    expect(doc.tree[h]!.transform, Transform2.identity());
  });

  test(
      "WT-bands the tool made over a plan's services scans the kit's shared "
      'band cache: its commit invalidates wallBandsOf(services), and a new '
      "chain's first click in the new wall's band right after joins it", () {
    final doc = wallDoc();
    final services = FakePlanServices(
        document: doc,
        catalog: testCatalog(),
        settings: {ArchitectureTools.wall: const WallSettings()});
    addTearDown(services.dispose);
    final bands = wallBandsOf(services);
    final tool = wallPlanTool.create(services);
    addTearDown(tool.dispose);
    final ctx = contextOf(doc);
    final g = bands.generation;
    tool.onPointerDown(pressEvent(plan(0, 0)), ctx);
    tool.onPointerDown(pressEvent(plan(3000, 0)), ctx);
    expect(bands.generation, greaterThan(g));
    final a = worldWallOf(doc, walls(doc).single);
    // End the chain, so the next wall does not run from A's end along A
    // itself; then a new chain whose first click lies in A's band, 70 mm
    // off its centreline, and a second click well away from A.
    tool.cancel(ctx);
    tool.onPointerDown(pressEvent(plan(1500, 70)), ctx);
    tool.onPointerDown(pressEvent(plan(1500, 1500)), ctx);
    expect(walls(doc), hasLength(2), reason: 'premise: the stem landed');
    final start = doc.components.get<WallParams>(walls(doc).last)!.start;
    expect(distToLine(start, a.s, a.e), lessThan(wallJoin.linear));
  });

  test(
      "WT-frozen the wall's grips over a plan's services: a frozen wall "
      'offers no grips and does not follow a joined end; with nothing '
      'frozen it does (spec 3a C1.5)', () {
    final hub = plan(1500, 1500);
    const wa = Handle(1300), wb = Handle(2600), wf = Handle(3900);
    final doc = wallDoc();
    for (final (h, deg, t, j, fromHub) in [
      (wa, 20.0, 200.0, Justification.centre, true),
      (wb, 140.0, 115.0, Justification.left, false),
      (wf, 255.0, 150.0, Justification.right, true),
    ]) {
      doc.commands.execute(
          addSpoke(doc, h, hub, deg + 23, 2000, t, j, fromHub: fromHub));
    }
    final q = polar(hub, 23 + 80, 500);
    final frozen =
        FakePlanServices(document: doc, catalog: testCatalog(), frozen: {wf});
    addTearDown(frozen.dispose);
    final grips = wallPlanType.gripsFor(frozen)!;
    expect(grips.gripsOf(doc, wf), isEmpty);
    final g = grips.gripsOf(doc, wa)[0];
    expect(handlesOf(grips.drag(doc, wa, g, q)!), [wa, wb]);
    expect(grips.preview(doc, wa, g, q), hasLength(2));

    final all = FakePlanServices(document: doc, catalog: testCatalog());
    addTearDown(all.dispose);
    final control = wallPlanType.gripsFor(all)!;
    expect(control.gripsOf(doc, wf), hasLength(2));
    expect(handlesOf(control.drag(doc, wa, control.gripsOf(doc, wa)[0], q)!),
        [wa, wb, wf]);
  });

  test(
      'WT-kit the kit carries the wall type after the box and the Wall tool '
      'after the Box tool, and it validates', () {
    expect([for (final t in architectureKit.types.take(2)) t.id],
        [ArchitectureTypes.box, ArchitectureTypes.wall]);
    expect(identical(architectureKit.types[1], wallPlanType), isTrue);
    expect([for (final t in architectureKit.tools.take(2)) t.id],
        [ArchitectureTools.box, ArchitectureTools.wall]);
    expect(identical(architectureKit.tools[1], wallPlanTool), isTrue);
    expect(architectureKit.validate(), isEmpty);
  });
}
