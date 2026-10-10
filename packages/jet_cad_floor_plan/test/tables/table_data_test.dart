// Host embedding API spec E-6, E-9 gate 3 (Slice 2 plan, Task 2): the
// host's data on a table -- the component, its limits, its lenient read
// (spec point S-2), its diagnostic (S-3) and the delete that takes it with
// the table (`RemoveNodeCommand`, node-components D-1), undoably, and the
// table system's all-or-nothing rollback of its stamps. Tables
// are placed off the origin, turned and mirrored; data is written with its
// keys out of order, a 64-character key, a 1024-unit value and non-ASCII
// text.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_data_component.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label_system.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'table_fixture.dart';

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

/// A value of exactly 1024 UTF-16 units that is only 512 characters: each
/// U+1F37D is a surrogate pair (E-6 counts units, review R-1).
final String astral1024 = '\u{1F37D}' * 512;

/// A value of 1025 UTF-16 units that is only 1024 characters.
final String astral1025 = '${'x' * 1023}\u{1F37D}';

/// A plan with the parametric system and the table system installed, in
/// the shell's order, torn down in reverse.
DraftDocument rig() {
  final d = plan();
  final parametric = installParametric(d);
  final tables = TableLabelSystem(d)..install();
  addTearDown(() {
    tables.dispose();
    parametric.dispose();
    d.dispose();
  });
  return d;
}

/// The table placed last in [doc].
TableInfo placeTable(DraftDocument doc, Vector2 at,
    {int quarterTurns = 0, bool mirrored = false}) {
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: at, quarterTurns: quarterTurns, mirrored: mirrored));
  return TableSurvey.of(doc)
      .tables
      .reduce((a, b) => a.instance.value > b.instance.value ? a : b);
}

/// The editor's Delete of [t]: its label, then the instance (spec 14a T9).
DraftCommand deleteTable(TableInfo t) => CompoundCommand(
    [RemoveEntityCommand(t.label!), RemoveNodeCommand(t.instance)],
    label: 'Delete');

FloorPlanTableData? dataOf(DraftDocument doc, Handle h) =>
    doc.components.get<FloorPlanTableData>(h);

/// The root group's children in the encoding [json].
List<Object?> rootChildren(String json) {
  final map = jsonDecode(json) as Map<String, Object?>;
  final root = (map['nodes']! as List)
      .cast<Map<String, Object?>>()
      .firstWhere((n) => n['handle'] == map['root']);
  return root['children']! as List;
}

void main() {
  group('the limits (E-6, S-6)', () {
    test(
        'TD1 accepted at the boundaries: 32 keys, a 64-character key, a '
        '1024-unit value, an empty value, non-ASCII text', () {
      expect(key64.length, 64);
      expect(value1024.length, 1024);
      final full = {
        for (var i = 0; i < 31; i++) 'k${i.toString().padLeft(2, '0')}': '$i',
        key64: value1024,
      };
      expect(full.length, 32);
      expect(tableDataProblem(full), isNull);
      expect(FloorPlanTableData(full).data, full);
      expect(tableDataProblem(hostData()), isNull);
      expect(tableDataProblem(const {}), isNull,
          reason: 'empty is within the limits: it removes the data');
      expect(tableDataProblem({'a': ' ¡ é'}), isNull,
          reason: 'U+00A0 is past the C1 range');
      expect(tableDataProblem({'a': 'a~b'}), isNull,
          reason: 'U+007E is below the DEL and C1 range');
      expect(astral1024.length, 1024);
      expect(astral1024.runes.length, 512);
      expect(tableDataProblem({'a': astral1024}), isNull,
          reason: '1024 UTF-16 units, though 512 characters');
      expect(FloorPlanTableData({'a': astral1024}).data, {'a': astral1024});
    });

    test(
        'TD2 refused one past each boundary: 33 keys, a 65-character key, a '
        '1025-unit value, each control character range, a bad key', () {
      final over = {for (var i = 0; i < 33; i++) 'k$i': 'v'};
      expect(astral1025.length, 1025);
      expect(astral1025.runes.length, 1024,
          reason: 'over in UTF-16 units, not in characters');
      final refused = <Map<String, String>>[
        over,
        {'${key64}q': 'v'},
        {'a': '${value1024}x'},
        {'a': astral1025},
        {'a': 'x\u0085y'},
        {'a': '\u0000'},
        {'a': 'line\nbreak'},
        {'a': '\u001f'},
        {'a': '\u007f'},
        {'a': '\u009f'},
        {'Bad': 'x'},
        {'bad key': 'x'},
        {'': 'x'},
        {'ı': 'x'},
      ];
      for (final data in refused) {
        expect(tableDataProblem(data), isNotNull, reason: '$data');
        expect(() => FloorPlanTableData(data), throwsArgumentError,
            reason: '$data');
      }
      expect(() => FloorPlanTableData(const {}), throwsArgumentError,
          reason: 'an empty map is no component');
    });
  });

  group('the component', () {
    test(
        'TD3 M-H24: keys inserted as zeta, id, alpha are written sorted; '
        'the data is unmodifiable and value-equal', () {
      final c = FloorPlanTableData(hostData());
      expect(jsonEncode(c.toJson()),
          '{"data":{"alpha":"","id":"7f3c-ä","zeta":"Masa 4.ğ"}}');
      expect(c.data.keys, ['alpha', 'id', 'zeta']);
      expect(() => c.data['x'] = 'y', throwsUnsupportedError);
      expect(c.isKept, isFalse);
      expect(c.typeId, 'jetcad.table_data');
      final same =
          FloorPlanTableData({'alpha': '', 'zeta': 'Masa 4.ğ', 'id': '7f3c-ä'});
      expect(same, c);
      expect(same.hashCode, c.hashCode);
      expect(FloorPlanTableData({...hostData(), 'id': '7f3c-a'}), isNot(c));
    });

    test(
        'TD4 M-H28: fromJson never throws; a payload of another shape or '
        'outside the limits is kept verbatim and reads as empty data', () {
      final payloads = <String>[
        jsonEncode({
          'data': {for (var i = 33; i > 0; i--) 'k$i': 'v$i'}
        }),
        '{"data":{"Bad Key":"x","alpha":"a"}}',
        jsonEncode({
          'data': {'a': '${value1024}x'}
        }),
        jsonEncode({
          'data': {'a': astral1025}
        }),
        '{"data":{"zeta":"z","n":4}}',
        '{"data":["1","2"]}',
        '{"data":{}}',
        '{}',
        '{"data":{"a":"b"},"extra":1}',
        jsonEncode({
          'data': {'a': 'x\u0085'}
        }),
        '{"data":{"a":{"b":[1,2.5,null,true,{"z":"y","c":"d"}]}},"x":-0.5}',
      ];
      for (final text in payloads) {
        final json = (jsonDecode(text) as Map).cast<String, Object?>();
        final c = FloorPlanTableData.fromJson(json);
        expect(c.isKept, isTrue, reason: text);
        expect(c.data, isEmpty, reason: text);
        expect(jsonEncode(c.toJson()), text, reason: 'written back as read');
        expect(FloorPlanTableData.fromJson(json), c, reason: 'value-equal');
      }
      final deep = FloorPlanTableData.fromJson(
          (jsonDecode(payloads.last) as Map).cast<String, Object?>());
      expect(
          () => (deep.kept!['data']! as Map)['q'] = 1, throwsUnsupportedError,
          reason: 'kept unmodifiable all the way down');
      expect(
          deep,
          isNot(FloorPlanTableData.fromJson(
              (jsonDecode(payloads.first) as Map).cast<String, Object?>())));
    });

    test(
        'TD5 a valid but unsorted stored payload is the data, re-sorted on '
        'write (S-6)', () {
      final c = FloorPlanTableData.fromJson(
          (jsonDecode('{"data":{"zeta":"Masa 4.ğ","id":"7f3c-ä","alpha":""}}')
                  as Map)
              .cast<String, Object?>());
      expect(c.isKept, isFalse);
      expect(c, FloorPlanTableData(hostData()));
      expect(jsonEncode(c.toJson()),
          '{"data":{"alpha":"","id":"7f3c-ä","zeta":"Masa 4.ğ"}}');
    });

    test(
        'TD6 registerAppComponents registers it: a plan decodes it typed, '
        'and one outside the limits decodes too, with a diagnostic', () {
      final doc = plan();
      final a = placeTable(doc, Vector2(41200, -27300), quarterTurns: 1);
      final b = placeTable(doc, Vector2(-38900, 26100), mirrored: true);
      doc.commands.execute(SetComponentCommand<FloorPlanTableData>(
          a.instance, FloorPlanTableData(hostData())));
      final json = (jsonDecode(DraftDocumentCodec.encodeToString(doc)) as Map)
          .cast<String, Object?>();
      doc.dispose();
      ((json['components']! as Map)['jetcad.table_data']
              as Map)['${b.instance.value}'] =
          jsonDecode('{"data":{"Bad Key":"x"}}');
      final text = jsonEncode(json);
      final back = DraftDocumentCodec.decodeString(text,
          registerComponents: registerAppComponents);
      addTearDown(back.dispose);
      expect(dataOf(back, a.instance), FloorPlanTableData(hostData()));
      expect(dataOf(back, b.instance)!.isKept, isTrue);
      expect(DraftDocumentCodec.encodeToString(back), text,
          reason: 'byte for byte');
      final invalid = tableDiagnostics(back)
          .where((d) => d.code == TableDiagnosticCodes.invalidData)
          .toList();
      expect(invalid.single.handles, [b.instance]);
      expect(invalid.single.severity, DiagnosticSeverity.warning);
      expect(TableDiagnosticCodes.invalidData, 'table.invalid_data');
    });
  });

  group('a deleted table takes its data (E-9 gate 3)', () {
    test(
        'TD7 M-H27: a Delete takes the data in the same step; undo puts '
        'it back byte for byte, redo drops it again; the other table keeps '
        'its', () {
      final doc = rig();
      final a = placeTable(doc, Vector2(41200, -27300),
          quarterTurns: 1, mirrored: true);
      final b = placeTable(doc, Vector2(44700, -27300), quarterTurns: 3);
      final other = FloorPlanTableData({key64: value1024});
      final mine = FloorPlanTableData(hostData());
      doc.commands
          .execute(SetComponentCommand<FloorPlanTableData>(a.instance, other));
      doc.commands
          .execute(SetComponentCommand<FloorPlanTableData>(b.instance, mine));
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
      expect((json['components'] as Map)['jetcad.table_data'],
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
      final mine = FloorPlanTableData(hostData());
      doc.commands
          .execute(SetComponentCommand<FloorPlanTableData>(a.instance, mine));
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
      doc.commands.execute(SetComponentCommand<FloorPlanTableData>(
          a.instance, FloorPlanTableData(hostData())));
      doc.commands.execute(SetComponentCommand<FloorPlanTableData>(
          c.instance, FloorPlanTableData({key64: value1024})));
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
      final kept = FloorPlanTableData.fromJson(
          (jsonDecode('{"data":{"Bad Key":[1,"x"]}}') as Map)
              .cast<String, Object?>());
      doc.commands
          .execute(SetComponentCommand<FloorPlanTableData>(nested, kept));
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
      final mine = FloorPlanTableData(hostData());
      doc.commands
          .execute(SetComponentCommand<FloorPlanTableData>(a.instance, mine));
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

    test(
        'TD10 all or nothing: a stamp that throws after another stamp '
        'puts that one back with the edit', () {
      final doc = rig();
      final a = placeTable(doc, Vector2(41200, -27300), quarterTurns: 1);
      final b = placeTable(doc, Vector2(44700, -27300), mirrored: true);
      final before = DraftDocumentCodec.encodeToString(doc);
      Transform2 turned(TableInfo t, double x, double y) =>
          Transform2.translation(x, y)
              .multiply(Transform2.rotation(kDeg37))
              .multiply(Transform2.translation(-x, -y))
              .multiply((doc.tree[t.instance]! as InstanceNode).transform);
      final edit = doc.commands.expander!(CompoundCommand([
        TransformNodeCommand(a.instance, turned(a, 41200, -27300)),
        TransformNodeCommand(b.instance, turned(b, 44700, -27300)),
      ], label: 'Turn both'));
      expect(edit, isA<TableLabelEdit>());
      final target =
          _RefusingTarget(doc, a.label!, labelPayload(doc, a.label!));
      expect(() => edit.apply(target), throwsA(isA<_Refused>()));
      expect(target.refused, isTrue,
          reason: 'premise: A\'s stamp wrote before B\'s read was refused');
      expect(DraftDocumentCodec.encodeToString(doc), before,
          reason: 'both tables unturned, A\'s label as it was');
    });
  });
}

final class _Refused implements Exception {}

GeometryPayload labelPayload(DraftDocument doc, Handle label) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(label)!));

bool samePayload(GeometryPayload x, GeometryPayload y) =>
    x.coords.length == y.coords.length &&
    x.scalars.length == y.scalars.length &&
    [for (var i = 0; i < x.coords.length; i++) x.coords[i] == y.coords[i]]
        .every((e) => e) &&
    [for (var i = 0; i < x.scalars.length; i++) x.scalars[i] == y.scalars[i]]
        .every((e) => e);

/// [doc] as a command target whose geometry -- read by a label stamp --
/// is refused once, the first time it is asked for after [stamped]'s
/// payload has changed from [unstamped]: so the edit throws with that
/// stamp applied, and the rollback (which reads geometry again) is let
/// through.
final class _RefusingTarget implements CommandTarget {
  _RefusingTarget(this.doc, this.stamped, this.unstamped);

  final DraftDocument doc;
  final Handle stamped;
  final GeometryPayload unstamped;
  bool refused = false;

  @override
  GeometryStore get geometry {
    if (!refused && !samePayload(labelPayload(doc, stamped), unstamped)) {
      refused = true;
      throw _Refused();
    }
    return doc.geometry;
  }

  @override
  EntityStore get entities => doc.entities;
  @override
  DocumentTree get tree => doc.tree;
  @override
  DocumentTables get tables => doc.tables;
  @override
  ComponentRegistry get components => doc.components;
  @override
  HandleSeed get handleSeed => doc.handleSeed;
  @override
  DocumentHeader get header => doc.header;
  @override
  FillIndex get fills => doc.fills;
  @override
  void invalidateDerived() => doc.invalidateDerived();
}
