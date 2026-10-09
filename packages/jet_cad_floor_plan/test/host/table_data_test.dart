// Host embedding API spec E-6, E-7, E-9 gates 2 and 3 (Slice 2 plan, Task
// 2): the host's data on a table through the controller -- setTableData and
// setTablesData, tableDetails' data, the save and the load, the service
// copy, renumbering, undo and redo, and the editor's Delete -- on the
// embedding fixture: tables turned 30 degrees, mirrored at 90, scaled,
// turned 180, all 40 m off the origin; `5` hidden, `L` locked; `7` and ` 7 `
// sharing a number. Data is written with its keys out of order, a
// 64-character key, a 1024-unit value and non-ASCII text.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/table_detail.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart'
    show registerAppComponents;
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';

import 'embedding_fixture.dart';

/// Data as a host writes it: keys out of order, a value with a space, a dot
/// and a non-ASCII letter, an empty value.
Map<String, String> hostData() => {
      'zeta': 'Masa 4.ğ',
      'id': '7f3c-ä',
      'alpha': '',
    };

/// [hostData]'s payload as written: keys sorted.
const String hostPayload =
    '{"data":{"alpha":"","id":"7f3c-ä","zeta":"Masa 4.ğ"}}';

/// A key of exactly 64 characters of the allowed set.
final String key64 = 'k${'a_.-9' * 12}xyz';

/// A value of exactly 1024 UTF-16 units, non-ASCII included.
final String value1024 = '${'ş' * 1000}${'x' * 24}';

FloorPlanController controller(WidgetTester tester, [String? json]) {
  final c = FloorPlanController(json: json ?? embeddingPlanJson());
  addTearDown(c.dispose);
  return c;
}

/// The instance of the one table numbered [n] in [doc].
Handle instanceOf(DraftDocument doc, String n) =>
    TableSurvey.of(doc).withNumber(n).single.instance;

/// The details of [c] carrying [n], in order.
List<FloorPlanTableDetail> detailsOf(FloorPlanController c, String n) => [
      for (final d in c.tableDetails)
        if (d.table.number == n) d
    ];

/// The `jetcad.table_data` section of the encoding [json], or null.
Map<String, Object?>? dataSection(String json) =>
    ((jsonDecode(json) as Map)['components'] as Map)['jetcad.table_data']
        as Map<String, Object?>?;

/// The root group's children in the encoding [json].
List<Object?> rootChildren(String json) {
  final map = jsonDecode(json) as Map<String, Object?>;
  final root = (map['nodes']! as List)
      .cast<Map<String, Object?>>()
      .firstWhere((n) => n['handle'] == map['root']);
  return root['children']! as List;
}

/// [json] with every group's children sorted: the encoding but for the
/// order `AddNodeCommand` re-adds a node in (it appends).
String childrenSorted(String json) {
  final map = jsonDecode(json) as Map<String, Object?>;
  for (final n in (map['nodes']! as List).cast<Map<String, Object?>>()) {
    if (n['children'] case final List<Object?> c) {
      n['children'] = [...c.cast<int>()]..sort();
    }
  }
  return jsonEncode(map);
}

/// The embedding fixture with [payloads] (by number) written as raw
/// `jetcad.table_data` payloads, through bytes, in the codec's own order
/// (type ids sorted, handles ascending), so this build writes it back
/// byte for byte.
String fixtureWith(Map<String, Object?> payloads) {
  final doc = DraftDocumentCodec.decodeString(embeddingPlanJson(),
      registerComponents: registerAppComponents);
  final byHandle = <int, Object?>{
    for (final e in payloads.entries) instanceOf(doc, e.key).value: e.value
  };
  doc.dispose();
  final json = jsonDecode(embeddingPlanJson()) as Map<String, Object?>;
  final components = (json['components']! as Map).cast<String, Object?>();
  components['jetcad.table_data'] = {
    for (final h in byHandle.keys.toList()..sort()) '$h': byHandle[h]
  };
  json['components'] = {
    for (final k in components.keys.toList()..sort()) k: components[k]
  };
  return jsonEncode(json);
}

void main() {
  testWidgets(
      'HD1 E-9 gate 2: data on 1 (30°), 2 (mirrored) and L (locked) '
      'round-trips through designJson and load byte for byte, and '
      'tableDetails reads it back on the same tables', (tester) async {
    final c = controller(tester);
    final third = {'z': 'Ω', key64: value1024, 'a.b-c_9': 'x y.z'};
    expect(
        c.setTablesData({
          '1': hostData(),
          ' 2 ': {'id': 'bbb'},
          'L': third,
        }),
        isTrue);
    final saved = c.designJson();
    expect(jsonDecode(saved)['schemaVersion'], 9);
    expect(dataSection(saved), hasLength(3));

    final back = controller(tester, saved);
    expect(back.designJson(), saved, reason: 'byte for byte');
    final other = controller(tester);
    other.load(saved);
    expect(other.designJson(), saved);
    for (final r in [c, back, other]) {
      expect(detailsOf(r, '1').single.data, hostData());
      expect(detailsOf(r, '1').single.data.keys, ['alpha', 'id', 'zeta']);
      expect(detailsOf(r, '2').single.data, {'id': 'bbb'});
      expect(detailsOf(r, 'L').single.data, third);
      expect(detailsOf(r, 'L').single.locked, isTrue);
      for (final d in r.tableDetails) {
        if (const {'1', '2', 'L'}.contains(d.table.number)) continue;
        expect(d.data, isEmpty, reason: '${d.table}');
      }
    }
    expect(back.tableDetails, c.tableDetails, reason: 'data included');
    expect(
        () => back.tableDetails.first.data['q'] = 'r', throwsUnsupportedError);
  });

  testWidgets(
      'HD2 M-H24: data inserted as zeta, id, alpha is written with its keys '
      'sorted, under the table\'s instance', (tester) async {
    final c = controller(tester);
    expect(c.setTableData('1', hostData()), isTrue);
    final h = instanceOf(c.activeDocument, '1').value;
    expect(c.designJson(), contains('"jetcad.table_data":{"$h":$hostPayload}'));
  });

  testWidgets(
      'HD3 M-H22: a number two tables carry is refused, whichever way it is '
      'written; so are an unknown and an empty number', (tester) async {
    final c = controller(tester);
    final before = c.designJson();
    for (final n in ['7', ' 7 ', '42', '', '  ']) {
      expect(c.setTableData(n, hostData()), isFalse, reason: '"$n"');
    }
    await tester.pump();
    expect(detailsOf(c, '7'), hasLength(2), reason: 'premise: two 7s');
    for (final d in detailsOf(c, '7')) {
      expect(d.data, isEmpty);
    }
    expect(c.designJson(), before);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'HD4 M-H23: in the selection mode both throw a StateError; the design '
      'and the copy are untouched', (tester) async {
    final c = controller(tester);
    c.setTableData('2', {'id': 'two'});
    final before = c.designJson();
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    final copy = c.tableDetails;
    expect(detailsOf(c, '2').single.data, {'id': 'two'},
        reason: 'the copy carries it, read only');
    expect(() => c.setTableData('1', hostData()), throwsStateError);
    expect(() => c.setTablesData({'1': hostData()}), throwsStateError);
    expect(() => c.setTableData('2', const {}), throwsStateError);
    await tester.pump();
    expect(c.designJson(), before);
    expect(c.tableDetails, copy);
    expect(c.canUndo.value, isFalse);
    c.setMode(FloorPlanMode.design);
    expect(detailsOf(c, '1').single.data, isEmpty);
    expect(detailsOf(c, '2').single.data, {'id': 'two'});
  });

  testWidgets(
      'HD5 M-H24b: an empty map removes the data: no jetcad.table_data '
      'section at all', (tester) async {
    final c = controller(tester);
    final empty = c.designJson();
    c.setTableData('1', hostData());
    expect(dataSection(c.designJson()), isNotNull, reason: 'premise');
    expect(c.setTableData('1', const {}), isTrue);
    final json = c.designJson();
    expect(json, isNot(contains('jetcad.table_data')));
    expect(json, empty);
    expect(detailsOf(c, '1').single.data, isEmpty);
    expect(c.setTableData('1', const {}), isTrue,
        reason: 'no data to remove: true, no step');
  });

  testWidgets(
      'HD6 M-H28: a plan whose data is outside the limits loads; each such '
      'table reads empty data, is reported table.invalid_data, and is '
      'written back byte for byte; a later setTableData replaces it',
      (tester) async {
    final payloads = <String, Object?>{
      '1': {
        'data': {for (var i = 0; i < 33; i++) 'k$i': 'v$i'}
      },
      '2': {
        'data': {'Bad Key': 'x', 'alpha': 'a'}
      },
      '3': {
        'data': {'a': '${value1024}x'}
      },
      '4': {
        'data': {'id': 'x', 'seats': 4}
      },
      'L': {
        'data': ['id', 'x']
      },
      '5': jsonDecode(hostPayload),
    };
    final json = fixtureWith(payloads);
    final c = controller(tester);
    c.load(json);
    expect(c.designJson(), json, reason: 'written back as read');
    expect(controller(tester, json).designJson(), json);
    for (final n in ['1', '2', '3', '4', 'L']) {
      expect(detailsOf(c, n).single.data, isEmpty, reason: n);
    }
    expect(detailsOf(c, '5').single.data, hostData(),
        reason: 'a valid payload beside them reads (hidden table)');
    final doc = c.activeDocument;
    final invalid = tableDiagnostics(doc)
        .where((d) => d.code == 'table.invalid_data')
        .map((d) => d.handles.single)
        .toList();
    expect(invalid, [
      for (final n in ['1', '2', '3', '4', 'L']) instanceOf(doc, n)
    ]);

    // The service copy decodes it the same way.
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    expect(detailsOf(c, '1').single.data, isEmpty);
    expect(detailsOf(c, '5').single.data, hostData());
    c.setMode(FloorPlanMode.design);

    expect(c.setTableData('1', {'id': 'one'}), isTrue);
    expect(c.setTableData('2', const {}), isTrue, reason: 'removes it');
    final next = c.designJson();
    final section = dataSection(next)!;
    expect(section['${instanceOf(doc, '1').value}'], {
      'data': {'id': 'one'}
    });
    expect(section.containsKey('${instanceOf(doc, '2').value}'), isFalse);
    expect(section['${instanceOf(doc, '3').value}'], payloads['3']);
    expect(
        tableDiagnostics(doc)
            .where((d) => d.code == 'table.invalid_data')
            .map((d) => d.handles.single),
        [
          for (final n in ['3', '4', 'L']) instanceOf(doc, n)
        ]);
    c.undo();
    c.undo();
    expect(c.designJson(), json, reason: 'undo restores the kept payloads');
  });

  testWidgets(
      'HD7 M-H29(setTablesData): one bad entry changes nothing: an '
      'ambiguous number, an unknown one, two keys trimming to one number '
      'are false; a map outside the limits throws first', (tester) async {
    final c = controller(tester);
    final before = c.designJson();
    expect(c.setTablesData({'1': hostData(), '7': hostData()}), isFalse);
    expect(c.setTablesData({'1': hostData(), '42': hostData()}), isFalse);
    expect(
        c.setTablesData({
          '1': hostData(),
          ' 1': {'id': 'b'}
        }),
        isFalse);
    expect(
        () => c.setTablesData({
              '1': hostData(),
              '2': {'Bad': 'x'}
            }),
        throwsArgumentError);
    expect(
        () => c.setTablesData({
              '42': hostData(),
              '2': {'a': 'x\u0085'}
            }),
        throwsArgumentError,
        reason: 'the maps are checked before the numbers');
    await tester.pump();
    expect(detailsOf(c, '1').single.data, isEmpty);
    expect(c.canUndo.value, isFalse);
    expect(c.designJson(), before);
  });

  testWidgets(
      'HD8 setTablesData is one undo step labelled "Table data"; entries '
      'already equal are skipped; nothing to change is no step; hidden and '
      'locked tables take data', (tester) async {
    final c = controller(tester);
    final doc = c.activeDocument;
    final labels = <String>[];
    final sub = doc.changes.listen((e) {
      if (e is CommandApplied) labels.add(e.label);
    });
    addTearDown(sub.cancel);
    final depth = doc.commands.undoDepth;
    expect(
        c.setTablesData({
          '5': {'id': 'hidden'},
          'L': {'id': 'locked'},
          '3': hostData(),
        }),
        isTrue);
    expect(doc.commands.undoDepth, depth + 1);
    expect(detailsOf(c, '5').single.center, isNull,
        reason: 'premise: 5 is hidden');
    expect(detailsOf(c, '5').single.data, {'id': 'hidden'});
    expect(detailsOf(c, 'L').single.data, {'id': 'locked'});

    final after = c.designJson();
    expect(
        c.setTablesData({
          '5': {'id': 'hidden'},
          ' L ': {'id': 'locked'},
        }),
        isTrue);
    expect(
        c.setTableData('3', {'zeta': 'Masa 4.ğ', 'alpha': '', 'id': '7f3c-ä'}),
        isTrue);
    expect(c.setTablesData(const {}), isTrue);
    expect(doc.commands.undoDepth, depth + 1, reason: 'no step');
    expect(c.designJson(), after);

    expect(
        c.setTablesData({
          '5': const {},
          '3': hostData(),
          '4': {'id': '4'}
        }),
        isTrue);
    expect(doc.commands.undoDepth, depth + 2);
    expect(detailsOf(c, '5').single.data, isEmpty);
    expect(detailsOf(c, '4').single.data, {'id': '4'});
    await tester.pump();
    expect(labels, ['Table data', 'Table data']);
    c.undo();
    expect(c.designJson(), after);
  });

  testWidgets(
      'HD9 the limits through the controller: the boundaries accepted, one '
      'past each refused with an ArgumentError, nothing changed',
      (tester) async {
    final c = controller(tester);
    final full = {
      for (var i = 0; i < 31; i++) 'k${i.toString().padLeft(2, '0')}': '$i',
      key64: value1024,
    };
    expect(c.setTableData('4', full), isTrue);
    expect(detailsOf(c, '4').single.data, full);
    final before = c.designJson();
    final refused = <Map<String, String>>[
      {...full, 'k99': 'x'},
      {'${key64}q': 'v'},
      {'a': '${value1024}x'},
      {'a': 'x\u0085y'},
      {'Id': 'x'},
    ];
    for (final data in refused) {
      expect(() => c.setTableData('4', data), throwsArgumentError,
          reason: '$data');
    }
    expect(c.designJson(), before);
    expect(detailsOf(c, '4').single.data, full);
  });

  testWidgets('HD10 renumbering 1 to 21 keeps its data: it is the instance\'s',
      (tester) async {
    final c = controller(tester);
    c.setTableData('1', hostData());
    final doc = c.activeDocument;
    final label = TableSurvey.of(doc).withNumber('1').single.label!;
    doc.commands.execute(SetEntityTextCommand(label, '21', kTableLabelTag));
    expect(detailsOf(c, '1'), isEmpty);
    expect(detailsOf(c, '21').single.data, hostData());
    expect(c.setTableData('21', {'id': 'new'}), isTrue);
    expect(detailsOf(c, '21').single.data, {'id': 'new'});
    expect(c.setTableData('1', {'id': 'x'}), isFalse);
  });

  testWidgets(
      'HD11 undo and redo of setTableData; dirty and canUndo on return, '
      'revision after the change; dirty again after markSaved', (tester) async {
    final c = controller(tester);
    await tester.pump();
    final revision = c.revision.value;
    expect(c.dirty.value, isFalse);
    expect(c.setTableData('2', hostData()), isTrue);
    expect(c.dirty.value, isTrue, reason: 'on return');
    expect(c.canUndo.value, isTrue, reason: 'on return');
    await tester.pump();
    expect(c.revision.value, greaterThan(revision));
    final withData = c.designJson();
    c.markSaved();
    expect(c.dirty.value, isFalse);

    c.undo();
    await tester.pump();
    expect(detailsOf(c, '2').single.data, isEmpty);
    expect(dataSection(c.designJson()), isNull);
    expect(c.dirty.value, isTrue);
    c.redo();
    await tester.pump();
    expect(detailsOf(c, '2').single.data, hostData());
    expect(c.designJson(), withData);
    expect(c.dirty.value, isFalse, reason: 'back at the save point');
    expect(c.setTableData('2', {'id': 'other'}), isTrue);
    expect(c.dirty.value, isTrue, reason: 'an edit after markSaved');
  });

  testWidgets(
      'HD12 M-H27 (E-9 gate 3): the editor\'s Delete of table 1 drops its '
      'data in the same step; Undo puts it back, the plan as it was but '
      'for the root\'s children order', (tester) async {
    final c = controller(tester);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FloorPlanView(controller: c))));
    await tester.pump();
    await tester.pump();
    expect(
        c.setTablesData({
          '1': hostData(),
          '2': {'id': 'two'}
        }),
        isTrue);
    final doc = c.activeDocument;
    final one = instanceOf(doc, '1'), two = instanceOf(doc, '2');
    final before = c.designJson();
    final depth = doc.commands.undoDepth;
    c.select({'1'});
    await tester.pump();
    expect(c.selectedTables.value, {'1'}, reason: 'premise');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(doc.tree[one], isNull, reason: 'premise: deleted');
    expect(doc.commands.undoDepth, depth + 1, reason: 'one step');
    final deleted = c.designJson();
    expect(dataSection(deleted), {
      '${two.value}': {
        'data': {'id': 'two'}
      }
    });

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    final undone = c.designJson();
    expect(detailsOf(c, '1').single.data, hostData());
    expect(jsonEncode(dataSection(undone)), jsonEncode(dataSection(before)));
    // AddNodeCommand appends: the restored table is the root's last child.
    expect(rootChildren(undone).last, one.value);
    expect(childrenSorted(undone), childrenSorted(before));
  });
}
