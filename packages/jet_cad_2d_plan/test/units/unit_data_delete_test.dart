// Ported from jet_cad_floor_plan/test/tables/table_data_test.dart (TD7-TD9);
// assertions unchanged.
// Host embedding API spec E-6, E-9 gate 3, spec 2b S2: a deleted unit takes
// its data with it (`RemoveNodeCommand`, node-components D-1), undoably.
// Units are placed off the origin, turned and mirrored; data is written
// with its keys out of order, a 64-character key and a 1024-unit value.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_2d_plan/src/units/unit_components.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart' show UnitInfo;
import 'package:jet_cad_2d_plan/src/units/unit_label_system.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/unit_fixtures.dart';

/// Data as a host writes it: keys out of order, a value with a space, a dot
/// and a non-ASCII letter.
Map<String, String> hostData() => {
      'zeta': 'Masa 4.ğ',
      'id': '7f3c-ä',
      'alpha': '',
    };

/// A key of exactly 64 characters of the allowed set.
final String key64 = 'k${'a_.-9' * 12}xyz';

/// A value of exactly 1024 UTF-16 units, non-ASCII included.
final String value1024 = '${'ş' * 1000}${'x' * 24}';

/// A plan with the parametric system and the label system installed, in
/// the session's order, torn down in reverse.
DraftDocument rig() {
  final d = plan();
  final parametric = ParametricSystem(d, ParametricCatalog())..install();
  final labels = UnitLabelSystem(d)..install();
  addTearDown(() {
    labels.dispose();
    parametric.dispose();
    d.dispose();
  });
  return d;
}

/// The unit placed last in [doc].
UnitInfo placeTable(DraftDocument doc, Vector2 at,
    {int quarterTurns = 0, bool mirrored = false}) {
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: at,
      quarterTurns: quarterTurns,
      mirrored: mirrored,
      units: unitIndexOf(doc)));
  return unitIndexOf(doc)
      .units
      .reduce((a, b) => a.instance.value > b.instance.value ? a : b);
}

/// The editor's Delete of [t]: its label, then the instance (spec 14a T9).
DraftCommand deleteTable(UnitInfo t) => CompoundCommand(
    [RemoveEntityCommand(t.label!), RemoveNodeCommand(t.instance)],
    label: 'Delete');

UnitData? dataOf(DraftDocument doc, Handle h) =>
    doc.components.get<UnitData>(h);

/// The root group's children in the encoding [json].
List<Object?> rootChildren(String json) {
  final map = jsonDecode(json) as Map<String, Object?>;
  final root = (map['nodes']! as List)
      .cast<Map<String, Object?>>()
      .firstWhere((n) => n['handle'] == map['root']);
  return root['children']! as List;
}

void main() {
  group('a deleted unit takes its data (E-9 gate 3)', () {
    test(
        'TD7 M-H27: a Delete takes the data in the same step; undo puts '
        'it back byte for byte, redo drops it again; the other table keeps '
        'its', () {
      final doc = rig();
      final a = placeTable(doc, Vector2(41200, -27300),
          quarterTurns: 1, mirrored: true);
      final b = placeTable(doc, Vector2(44700, -27300), quarterTurns: 3);
      final other = UnitData({key64: value1024});
      final mine = UnitData(hostData());
      doc.commands.execute(SetComponentCommand<UnitData>(a.instance, other));
      doc.commands.execute(SetComponentCommand<UnitData>(b.instance, mine));
      final before = DraftDocumentCodec.encodeToString(doc);
      final depth = doc.commands.undoDepth;

      // B is the root's last child (TD7b: the first table; TD7c: two
      // non-adjacent ones in one step).
      doc.commands.execute(deleteTable(b));
      expect(doc.tree[b.instance], isNull);
      expect(dataOf(doc, b.instance), isNull, reason: 'no orphan');
      expect(dataOf(doc, a.instance), same(other));
      expect(doc.commands.undoDepth, depth + 1, reason: 'one step');
      final json = jsonDecode(DraftDocumentCodec.encodeToString(doc)) as Map;
      expect((json['components'] as Map)['jetcad.unit_data'],
          {'${a.instance.value}': other.toJson()});

      doc.commands.undo();
      expect(dataOf(doc, b.instance), same(mine));
      expect(DraftDocumentCodec.encodeToString(doc), before);
      doc.commands.redo();
      expect(doc.tree[b.instance], isNull);
      expect(dataOf(doc, b.instance), isNull);
      doc.commands.undo();
      expect(DraftDocumentCodec.encodeToString(doc), before);
    });

    test(
        'TD7b the first table deleted and undone: its data back, the plan '
        'byte for byte, the table back before B among the root\'s children '
        '(O-10)', () {
      final doc = rig();
      final a = placeTable(doc, Vector2(41200, -27300),
          quarterTurns: 1, mirrored: true);
      final b = placeTable(doc, Vector2(44700, -27300), quarterTurns: 3);
      final mine = UnitData(hostData());
      doc.commands.execute(SetComponentCommand<UnitData>(a.instance, mine));
      final before = DraftDocumentCodec.encodeToString(doc);
      expect(rootChildren(before).sublist(rootChildren(before).length - 2),
          [a.instance.value, b.instance.value],
          reason: 'premise: A is not the last child');
      doc.commands.execute(deleteTable(a));
      expect(dataOf(doc, a.instance), isNull);
      doc.commands.undo();
      expect(dataOf(doc, a.instance), same(mine));
      expect(DraftDocumentCodec.encodeToString(doc), before);
    });

    test(
        'TD7c two non-adjacent tables, neither last, deleted in one step: '
        'undo writes the plan back byte for byte, redo deletes both again', () {
      final doc = rig();
      final a = placeTable(doc, Vector2(41200, -27300),
          quarterTurns: 1, mirrored: true);
      final b = placeTable(doc, Vector2(44700, -27300), quarterTurns: 3);
      final c = placeTable(doc, Vector2(41200, -23100), quarterTurns: 2);
      final d = placeTable(doc, Vector2(44700, -23100), mirrored: true);
      doc.commands.execute(
          SetComponentCommand<UnitData>(a.instance, UnitData(hostData())));
      doc.commands.execute(SetComponentCommand<UnitData>(
          c.instance, UnitData({key64: value1024})));
      final before = DraftDocumentCodec.encodeToString(doc);
      final root = rootChildren(before);
      expect(
          root.sublist(root.length - 4),
          [
            for (final t in [a, b, c, d]) t.instance.value
          ],
          reason: 'premise: B between A and C, D after both');
      final depth = doc.commands.undoDepth;
      // The tables sit in ascending handle order, so this cannot tell
      // "restore the index" from "insert sorted by handle"; the engine's
      // node_index_undo_test, whose children are out of order, does.

      doc.commands.execute(CompoundCommand([
        RemoveEntityCommand(a.label!),
        RemoveNodeCommand(a.instance),
        RemoveEntityCommand(c.label!),
        RemoveNodeCommand(c.instance),
      ], label: 'Delete'));
      expect(doc.commands.undoDepth, depth + 1, reason: 'one step');
      expect(doc.tree[a.instance], isNull);
      expect(doc.tree[c.instance], isNull);
      expect(dataOf(doc, c.instance), isNull);
      final deleted = DraftDocumentCodec.encodeToString(doc);

      doc.commands.undo();
      expect(DraftDocumentCodec.encodeToString(doc), before);
      doc.commands.redo();
      expect(DraftDocumentCodec.encodeToString(doc), deleted);
      doc.commands.undo();
      expect(DraftDocumentCodec.encodeToString(doc), before);
    });

    test(
        'TD8 a nested instance of a deleted group loses its data too; a '
        'kept payload is dropped and restored as read', () {
      final doc = rig();
      final t = placeTable(doc, Vector2(-41200, 27300), quarterTurns: 2);
      final definition = (doc.tree[t.instance]! as InstanceNode).definition;
      final group = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(GroupNode(
          handle: group,
          parent: doc.rootHandle,
          transform: Transform2.translation(-4000, 300),
          children: const [])));
      final nested = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(InstanceNode(
          handle: nested,
          parent: group,
          transform: placementAt(100, 200, kDeg37, mirrored: true),
          definition: definition,
          layer: ReservedHandles.layerZero)));
      final kept = UnitData.fromJson(
          (jsonDecode('{"data":{"Bad Key":[1,"x"]}}') as Map)
              .cast<String, Object?>());
      doc.commands.execute(SetComponentCommand<UnitData>(nested, kept));
      final before = DraftDocumentCodec.encodeToString(doc);

      // The editor's group cascade: the instance, then the group.
      doc.commands.execute(CompoundCommand(
          [RemoveNodeCommand(nested), RemoveNodeCommand(group)],
          label: 'Delete'));
      expect(dataOf(doc, nested), isNull);
      doc.commands.undo();
      expect(dataOf(doc, nested), same(kept));
      expect(DraftDocumentCodec.encodeToString(doc), before);
    });

    test(
        'TD9 an edit that does not remove the table keeps its data: a turn, '
        'and a delete of another table', () {
      final doc = rig();
      final a = placeTable(doc, Vector2(41200, -27300), mirrored: true);
      final b = placeTable(doc, Vector2(44700, -23100), quarterTurns: 1);
      final mine = UnitData(hostData());
      doc.commands.execute(SetComponentCommand<UnitData>(a.instance, mine));
      final node = doc.tree[a.instance]! as InstanceNode;
      doc.commands.execute(CompoundCommand([
        TransformNodeCommand(
            a.instance,
            Transform2.translation(-1750, 3300)
                .multiply(Transform2.rotation(kDeg37))
                .multiply(Transform2.translation(1750, -3300))
                .multiply(node.transform)),
      ], label: 'Rotate'));
      expect(dataOf(doc, a.instance), same(mine));
      doc.commands.execute(deleteTable(b));
      expect(dataOf(doc, a.instance), same(mine));
    });
  });
}
