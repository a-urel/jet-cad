// Spec 2a E1: the catalog lists its type ids and names the type of a
// group's live object by the engine's own rule. No parametric system is
// installed: nothing regenerates, so each component lands where it is put,
// nested and on an entity included. Every group is off the origin at a
// rotation.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';

final Transform2 at = Transform2.translation(7010, 3020)
    .multiply(Transform2.rotation(math.pi / 6));

/// SoftRect, ClipRect, Trip, then ClipRect again: not sorted, and one type
/// id registered twice.
ParametricCatalog e1Catalog() => ParametricCatalog()
  ..register<SoftRect>(SoftRect.id, SoftRect.fromJson,
      const RectType<SoftRect>(Capability.components))
  ..register<ClipRect>(ClipRect.id, ClipRect.fromJson,
      const RectType<ClipRect>(Capability.geometry))
  ..register<Trip>(Trip.id, Trip.fromJson, const TripType())
  ..register<ClipRect>(ClipRect.id, ClipRect.fromJson,
      const RectType<ClipRect>(Capability.geometry));

Handle addGroup(DraftDocument doc, Handle parent, Transform2 transform) {
  final h = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(GroupNode(
      handle: h, parent: parent, transform: transform, children: const [])));
  return h;
}

void main() {
  test('E1-typeIds the type ids, in registration order, each once', () {
    // M-E1a: sorted, clipRect comes first.
    // M-E1b: one entry per registration, clipRect is listed twice.
    expect(e1Catalog().typeIds.toList(), [SoftRect.id, ClipRect.id, Trip.id]);
    expect(ParametricCatalog().typeIds, isEmpty);
  });

  test(
      "E1-typeIdOf names a live object's type by the engine rule, and null "
      'for anything that is not one', () {
    final catalog = e1Catalog();
    final doc = DraftDocument.empty();
    catalog.registerComponents(doc.components);

    final soft = addGroup(doc, doc.rootHandle, at);
    doc.commands
        .execute(SetComponentCommand<SoftRect>(soft, const SoftRect(400, 900)));
    final trip = addGroup(
        doc, doc.rootHandle, at.multiply(Transform2.translation(-1800, 650)));
    doc.commands.execute(SetComponentCommand<Trip>(trip, const Trip(310, 95)));
    // Two registered types on one root-level group: the later registered
    // (ClipRect, registered again last) names it.
    final both = addGroup(
        doc,
        doc.rootHandle,
        at
            .multiply(Transform2.translation(2500, -300))
            .multiply(Transform2.rotation(0.7)));
    doc.commands
        .execute(SetComponentCommand<SoftRect>(both, const SoftRect(300, 200)));
    doc.commands
        .execute(SetComponentCommand<ClipRect>(both, const ClipRect(700, 650)));
    final nested = addGroup(doc, soft,
        Transform2.translation(120, 80).multiply(Transform2.rotation(0.4)));
    doc.commands
        .execute(SetComponentCommand<ClipRect>(nested, const ClipRect(50, 60)));
    final layered = addGroup(
        doc, doc.rootHandle, at.multiply(Transform2.translation(-900, 1400)));
    doc.commands.execute(SetComponentCommand<ObjectLayer>(
        layered, const ObjectLayer(ReservedHandles.layerZero)));
    final add = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)),
        layer: ReservedHandles.layerZero);
    doc.commands.execute(add);
    final line = add.record.handle;
    doc.commands
        .execute(SetComponentCommand<ClipRect>(line, const ClipRect(90, 40)));
    final gone = addGroup(
        doc, doc.rootHandle, at.multiply(Transform2.translation(4000, 900)));
    doc.commands
        .execute(SetComponentCommand<ClipRect>(gone, const ClipRect(80, 70)));
    doc.commands.execute(RemoveNodeCommand(gone));

    expect(catalog.typeIdOf(doc, soft), SoftRect.id);
    expect(catalog.typeIdOf(doc, trip), Trip.id);
    // M-E1c: the first registration found, without the root-level rule,
    // answers softRect here.
    expect(catalog.typeIdOf(doc, both), ClipRect.id);
    // M-E1c, M-E1d: without the root-level rule, the nested group and the
    // entity answer clipRect.
    expect(catalog.typeIdOf(doc, nested), isNull);
    expect(catalog.typeIdOf(doc, line), isNull);
    expect(catalog.typeIdOf(doc, layered), isNull,
        reason: 'ObjectLayer is a component, not a parametric type');
    expect(catalog.typeIdOf(doc, gone), isNull);
    expect(catalog.typeIdOf(doc, doc.rootHandle), isNull);
    expect(catalog.typeIdOf(doc, const Handle(987654)), isNull);
  });
}
