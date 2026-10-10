// Spec "A removed node takes its components" (revision 3), P-1 to P-3:
// in the shell's rig (the parametric system, then the table system), a
// delete takes every component of every removed node, a door with its
// wall, and undo writes the plan back byte for byte (entities in handle
// order: slot order is history, 06 D11).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/parametric/opening.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:jet_cad_floor_plan/src/tables/table_data_component.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart' show addOpening, deleteLikeSelectTool;
import 'support/wall_fixture.dart' show addWallLocal, canon;
import 'tables/table_data_test.dart'
    show rig, placeTable, deleteTable, hostData, dataOf;

bool namesHandle(DraftDocument doc, Handle h) => doc.components
    .toJson()
    .values
    .any((perType) => (perType! as Map).containsKey('${h.value}'));

/// A layer that is not layer 0, added to [doc].
Handle addLayer(DraftDocument doc) {
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final h = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: h,
      name: 'Walls',
      color: const IndexedColor(5),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: true,
      locked: false)));
  return h;
}

void main() {
  test(
      'P-1 a table with data and a newer release\'s payload, and a wall, '
      'deleted together: no entry for either; undo byte for byte', () {
    final doc = rig();
    final layer = addLayer(doc);
    final t = placeTable(doc, Vector2(41200, -27300),
        quarterTurns: 1, mirrored: true);
    doc.commands.execute(SetComponentCommand<FloorPlanTableData>(
        t.instance, FloorPlanTableData(hostData())));
    doc.components.attachUnknown(t.instance, {'typeId': 'z.next', 'v': 2});
    final w = doc.handleSeed.next();
    doc.commands.execute(addWallLocal(
        doc,
        w,
        const WallParams(120, -40, 5120, 310, 200, Justification.left),
        Transform2.translation(38000, -25000)
            .multiply(Transform2.rotation(0.3))));
    doc.commands
        .execute(SetComponentCommand<ObjectLayer>(w, ObjectLayer(layer)));
    final before = canon(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(CompoundCommand([
      ...(deleteTable(t) as CompoundCommand).children,
      ...(deleteLikeSelectTool(doc, w) as CompoundCommand).children,
    ], label: 'Delete'));

    expect(doc.commands.undoDepth, depth + 1);
    for (final h in [t.instance, w]) {
      expect(doc.tree[h], isNull);
      expect(namesHandle(doc, h), isFalse, reason: h.toHex());
      expect(doc.components.unknownOf(h), isEmpty);
    }
    doc.commands.undo();
    expect(canon(doc), before);
    expect(dataOf(doc, t.instance), isNotNull);
  });

  test(
      'P-2 a wall deleted alone: WallParams and ObjectLayer gone, the undo '
      'replay restores them through the node\'s snapshot', () {
    final doc = rig();
    final layer = addLayer(doc);
    final w = doc.handleSeed.next();
    const p = WallParams(-300, 75, 4100, 75, 150, Justification.centre);
    doc.commands.execute(addWallLocal(
        doc,
        w,
        p,
        Transform2.translation(-12000, 8000)
            .multiply(Transform2.rotation(-0.8))));
    doc.commands
        .execute(SetComponentCommand<ObjectLayer>(w, ObjectLayer(layer)));
    final before = canon(doc);

    doc.commands.execute(deleteLikeSelectTool(doc, w));
    expect(doc.components.get<WallParams>(w), isNull);
    expect(doc.components.get<ObjectLayer>(w), isNull);
    doc.commands.undo();
    expect(doc.components.get<WallParams>(w), p);
    expect(doc.components.get<ObjectLayer>(w), ObjectLayer(layer));
    expect(canon(doc), before);
  });

  test(
      'P-3 a wall hosting a door: the door goes with it (08 D4\'s '
      'cascade), both components and layers gone; undo restores both', () {
    final doc = rig();
    final layer = addLayer(doc);
    final w = doc.handleSeed.next();
    doc.commands.execute(addWallLocal(
        doc,
        w,
        const WallParams(0, 0, 6000, 0, 200, Justification.centre),
        Transform2.translation(25000, 14000)
            .multiply(Transform2.rotation(1.2))));
    final door = doc.handleSeed.next();
    doc.commands.execute(
        addOpening(doc, door, OpeningParams(w, 2400, 900, OpeningKind.door)));
    doc.commands.execute(CompoundCommand([
      SetComponentCommand<ObjectLayer>(w, ObjectLayer(layer)),
      SetComponentCommand<ObjectLayer>(door, ObjectLayer(layer)),
    ], label: 'Layers'));
    final before = canon(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(deleteLikeSelectTool(doc, w));

    expect(doc.commands.undoDepth, depth + 1);
    expect(doc.tree[door], isNull, reason: 'premise: the cascade ran');
    for (final h in [w, door]) {
      expect(namesHandle(doc, h), isFalse, reason: h.toHex());
    }
    doc.commands.undo();
    expect(canon(doc), before);
  });
}
