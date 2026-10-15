// The plan library's test helpers (spec 2a "Tests"): plan documents over a
// list of kits and their parametric system, pointer events for driving a
// tool without a canvas, and a pump that puts a widget in an app. Later
// tasks add to it: Task 7 `planText`, Task 8 `controllerFor`.
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/units/unit_components.dart'
    show registerUnitComponents;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'test_kit.dart';

/// Every kit's types registered, in load order, without a guard.
ParametricCatalog catalogOf(List<PlanKit> kits) {
  final catalog = ParametricCatalog();
  for (final kit in kits) {
    for (final type in kit.types) {
      type.registerInto(catalog);
    }
  }
  return catalog;
}

/// The page, the contract's four components, the unit components and
/// [catalog]'s: what a plan document registers. Once per registry
/// (`PageComponent.register` wipes a live page).
void registerPlanComponents(
    ComponentRegistry registry, ParametricCatalog catalog) {
  PageComponent.register(registry);
  registerKitComponents(registry);
  registerUnitComponents(registry);
  catalog.registerComponents(registry);
}

/// A new plan's document over [kits]: millimetres, the default page (A4
/// landscape at 1:50, origin (-7425, -5250)) printing [separator], no
/// history. No system is installed.
DraftDocument planDocument(List<PlanKit> kits,
    {TextMeasurer measurer = const InsertionPointMeasurer(),
    DecimalSeparator separator = DecimalSeparator.point}) {
  final d = DraftDocument.empty(measurer: measurer);
  registerPlanComponents(d.components, catalogOf(kits));
  d.header.units = DrawingUnits.millimeters;
  d.commands.execute(SetComponentCommand<PageComponent>(
      d.rootHandle,
      PageComponent(
          originX: -7425, originY: -5250, decimalSeparator: separator)));
  d.commands.clearHistory();
  return d;
}

/// [kits]' parametric system on [d], installed now and disposed at
/// tear-down. Call inside a test.
ParametricSystem installSystem(DraftDocument d, List<PlanKit> kits) {
  final system = ParametricSystem(d, catalogOf(kits))..install();
  addTearDown(system.dispose);
  return system;
}

/// A root line from [a] to [b] on layer 0, executed; its handle.
Handle addLine(DraftDocument d, Vector2 a, Vector2 b) {
  final command = addDrafted(d, EntityKind.line, linePayload(a, b),
      layer: ReservedHandles.layerZero);
  d.commands.execute(command);
  return command.record.handle;
}

/// The handles of the entities [owner] holds, ascending by slot.
List<Handle> leavesOf(DraftDocument d, Handle owner) => [
      for (final slot in d.entities.liveSlots)
        if (d.entities.ownerAt(slot) == owner) d.entities.handleAt(slot),
    ];

/// [leaf]'s stored coordinates.
Float64List coordsOf(DraftDocument d, Handle leaf) {
  final slot = d.entities.slotOf(leaf)!;
  return d.geometry.read(d.entities.geomIndexAt(slot)).coords;
}

/// A primary-button event at [world], for driving a tool directly.
ToolPointerEvent pointerAt(Vector2 world,
        {int buttons = kPrimaryButton,
        Offset screen = Offset.zero,
        double pickRadiusWorld = 1}) =>
    ToolPointerEvent(
        screen: screen,
        world: world,
        pointer: 1,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: pickRadiusWorld);

/// [child] in a Material app of [size] logical pixels.
Future<void> pumpApp(WidgetTester tester, Widget child,
    {Size size = const Size(1440, 900)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

/// A saved plan over [kits]: [planDocument] with the kits' system
/// installed, [build] run on it, then [encodePlan] (a manifest of the
/// loaded kits the plan uses).
String planText(List<PlanKit> kits, void Function(DraftDocument d) build,
    {DecimalSeparator separator = DecimalSeparator.point}) {
  final d = planDocument(kits, separator: separator);
  final system = ParametricSystem(d, catalogOf(kits))..install();
  try {
    build(d);
  } finally {
    system.dispose();
  }
  return encodePlan(d, validateKitSet(kits));
}

/// A controller over [kits] (and [json]), disposed at tear-down.
PlanController controllerFor(
    {required List<PlanKit> kits,
    String? json,
    double minScale = kPlanMinScale,
    double maxScale = kPlanMaxScale}) {
  final c = PlanController(
      kits: kits, json: json, minScale: minScale, maxScale: maxScale);
  addTearDown(c.dispose);
  return c;
}

/// A saved plan over `[testKit()]`: a slab 1800 x 900 turned 0.4 rad at
/// (-2600, 1400), tiled; a slab 1200 x 700 turned -1.1 rad at (2300,
/// 1400); a line.
String slabPlanText() => planText([testKit()], (d) {
      addObject<SlabComponent>(d,
          SlabComponent(width: 1800, height: 900, angle: 0.4, finish: 'tiled'),
          at: Vector2(-2600, 1400));
      addObject<SlabComponent>(
          d, SlabComponent(width: 1200, height: 700, angle: -1.1),
          at: Vector2(2300, 1400));
      addLine(d, Vector2(-500, 700), Vector2(1800, 2400));
    });

/// [d]'s slabs, ascending.
List<Handle> slabsOf(DraftDocument d) =>
    d.components.withComponent<SlabComponent>().toList();

/// One edit: [slab]'s width set to [width].
void setSlabWidth(PlanController c, Handle slab, double width) {
  final s = c.document.components.get<SlabComponent>(slab)!;
  c.document.commands.execute(
      SetComponentCommand<SlabComponent>(slab, s.copyWith(width: width)));
}
