// Plan 12b P-6 on a PlanController: layers `A` (ACI 1), `B` (ACI 5, locked)
// and `C` (ACI 3, hidden) beside a visible layer 0, each added by
// `AddLayerCommand`; with `objects`, a mark on `A` and a mark on `B`, each
// turned and far from the origin. The plan is built on a scratch
// controller, saved and loaded into the returned one, so it opens clean
// with an empty history, as `layerDoc()`'s `clearHistory()` left it, and
// carries the manifest a plan needs (spec P4).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'mark_kit.dart';

/// Plan millimetres ([x], [y]) at the fixtures' far origin: nothing sits
/// at the origin (CLAUDE.md's testing bar).
Vector2 at(double x, double y) => Vector2(x - 31250.5, y + 18420.25);

/// A group's transform: at plan point ([x], [y]), turned by [turn] rad.
Transform2 placed(double x, double y, double turn) {
  final p = at(x, y);
  return Transform2.translation(p.x, p.y).multiply(Transform2.rotation(turn));
}

/// A controller over P-6's layers, and what was added to it.
final class LayerPlan {
  LayerPlan._(this.controller, this.a, this.b, this.c, this.marks);

  final PlanController controller;

  /// `A` (ACI 1), `B` (ACI 5, locked) and `C` (ACI 3, hidden).
  final Handle a, b, c;

  /// With `objects`: `[0]` a mark on `A`, `[1]` a mark on `B`.
  final List<Handle> marks;

  DraftDocument get doc => controller.document;
}

/// P-6's layers on a fresh plan of [kits] ([markKit] by default). [more]
/// adds to the scratch document before it is saved; what it returns is
/// kept in [LayerPlan.marks] after the fixture's own marks.
LayerPlan layerPlan(
    {bool objects = false,
    List<PlanKit>? kits,
    List<Handle> Function(DraftDocument doc, Handle a, Handle b, Handle c)?
        more}) {
  final scratch = PlanController(kits: [markKit()]);
  final doc = scratch.document;
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  Handle add(String name, int aci, {bool visible = true, bool locked = false}) {
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    )));
    return handle;
  }

  final a = add('A', 1);
  final b = add('B', 5, locked: true);
  final c = add('C', 3, visible: false);
  final marks = <Handle>[
    if (objects) ...[
      addMark(doc, a, at: placed(5250.5, 2750.25, 0.35)),
      addMark(doc, b, at: placed(-3100.25, 4400.5, -0.6)),
    ],
    ...?more?.call(doc, a, b, c),
  ];
  final json = scratch.save();
  scratch.dispose();
  final controller = PlanController(kits: kits ?? [markKit()], json: json);
  addTearDown(controller.dispose);
  return LayerPlan._(controller, a, b, c, marks);
}

/// A drafted line on [layer] from plan point ([x1], [y1]) to ([x2], [y2]),
/// as the Line tool adds it: one command. Returns its handle.
Handle addLineOn(DraftDocument doc, Handle layer, double x1, double y1,
    double x2, double y2) {
  final s = at(x1, y1), e = at(x2, y2);
  final add = addDrafted(
      doc,
      EntityKind.line,
      GeometryPayload(
          coords: Float64List.fromList([s.x, s.y, e.x, e.y]),
          scalars: Float64List(0)),
      layer: layer);
  doc.commands.execute(add);
  return add.record.handle;
}

/// A drafted region on [layer] — a circle's boundary and its fill, as the
/// Circle tool adds a filled one — centred at plan point ([x], [y]), and a
/// second fill naming the same boundary, also on [layer] (a file can hold
/// one; spec 12b S-8 moves every fill of a boundary).
({Handle fill, Handle boundary, Handle secondFill}) addRegionOn(
    DraftDocument doc, Handle layer, double x, double y, double r) {
  final c = at(x, y);
  final region = addDraftedRegion(
      doc,
      EntityKind.circle,
      GeometryPayload(
          coords: Float64List.fromList([c.x, c.y]),
          scalars: Float64List.fromList([r])),
      layer: layer)!;
  doc.commands.execute(region);
  final boundary = region.boundary.handle;
  final second = AddEntityCommand(
      record: draftRecord(
          doc.handleSeed.next(), doc.rootHandle, EntityKind.fill,
          layer: layer, color: const IndexedColor(4)),
      payload: GeometryPayload(
          coords: Float64List(0),
          scalars: Float64List.fromList([boundary.value.toDouble()])));
  doc.commands.execute(second);
  return (
    fill: region.fill.handle,
    boundary: boundary,
    secondFill: second.record.handle
  );
}

/// A symbol as the library makes one: a definition whose line is on
/// layer 0, an instance of it at the root on [layer] at plan point ([x],
/// [y]), turned a little, and an ATTRIB on layer 0 owned by the instance.
({Handle definition, Handle instance, Handle attrib}) addSymbolOn(
    DraftDocument doc, Handle layer, double x, double y) {
  Handle leaf(
      Handle owner, EntityKind kind, List<double> coords, List<double> scalars,
      {String text = ''}) {
    final add = AddEntityCommand(
        record: draftRecord(doc.handleSeed.next(), owner, kind,
            layer: ReservedHandles.layerZero, text: text),
        payload: GeometryPayload(
            coords: Float64List.fromList(coords),
            scalars: Float64List.fromList(scalars)));
    doc.commands.execute(add);
    return add.record.handle;
  }

  final definition = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
      handle: definition,
      name: 'Table ${definition.toHex()}',
      basePoint: Vector2(40, 30),
      children: const []));
  leaf(definition, EntityKind.line, [10, 10, 610, 340], const []);
  // `at` is the top-level helper here: the source's local is renamed.
  final p = at(x, y);
  final instance = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform:
          Transform2.translation(p.x, p.y).multiply(Transform2.rotation(0.4)),
      definition: definition,
      layer: layer)));
  final attrib =
      leaf(instance, EntityKind.attrib, [90, 60], [4, 0], text: 'TAG');
  return (definition: definition, instance: instance, attrib: attrib);
}

/// Entity [h]'s stored layer.
Handle layerOf(DraftDocument doc, Handle h) =>
    doc.entities.layerAt(doc.entities.slotOf(h)!);

/// Object [h]'s `ObjectLayer` component, or null.
Handle? objectLayerOf(DraftDocument doc, Handle h) =>
    doc.components.get<ObjectLayer>(h)?.layer;
