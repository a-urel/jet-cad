// Ported from jet_cad_floor_plan test/host/table_data_test.dart (2b Task
// 9, spec S2 "Per-unit data", S3 "Design writes"): setUnitData and
// setUnitsData on the embedding fixture. HD4 and HD6's service-copy block
// (the service mode) are Task 11's, appended there. Today's header follows.
//
// Host embedding API spec E-6, E-7, E-9 gates 2 and 3 (Slice 2 plan, Task
// 2): the host's data on a table through the controller -- setUnitData and
// setUnitsData, tableDetails' data, the save and the load, the service
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
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kUnitLabelTag;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart' show LockSet;
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';

import '../support/unit_embedding_fixture.dart';
import '../support/unit_fixtures.dart' show fxKit;

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

/// A value of exactly 1024 UTF-16 units that is only 512 characters: each
/// U+1F37D is a surrogate pair (E-6 counts units, review R-1).
final String astral1024 = '\u{1F37D}' * 512;

/// A value of 1025 UTF-16 units that is only 1024 characters.
final String astral1025 = '${'x' * 1023}\u{1F37D}';

PlanController controller(WidgetTester tester, [String? json]) {
  final c = PlanController(kits: [fxKit()], json: json ?? embeddingPlanJson());
  addTearDown(c.dispose);
  return c;
}

/// The units of [doc], read now (the fixture kit loaded).
UnitIndex unitsOfDoc(DraftDocument doc) => UnitIndex.of(doc,
    catalog: ParametricCatalog(), locks: LockSet.scan(doc, (_) => true));

/// The instance of the one table numbered [n] in [doc].
Handle instanceOf(DraftDocument doc, String n) =>
    unitsOfDoc(doc).withLabel(n).single.instance;

/// [doc]'s unit diagnostics (today's `tableDiagnostics`).
List<Diagnostic> unitDiagnostics(DraftDocument doc) =>
    unitsOfDoc(doc).diagnostics();

/// The details of [c] carrying [n], in order.
List<PlanUnitDetail> detailsOf(PlanController c, String n) => [
      for (final d in c.unitDetails)
        if (d.unit.label == n) d
    ];

/// The `jetcad.unit_data` section of the encoding [json], or null.
Map<String, Object?>? dataSection(String json) =>
    ((jsonDecode(json) as Map)['components'] as Map)['jetcad.unit_data']
        as Map<String, Object?>?;

/// The root group's children in the encoding [json].
List<Object?> rootChildren(String json) {
  final map = jsonDecode(json) as Map<String, Object?>;
  final root = (map['nodes']! as List)
      .cast<Map<String, Object?>>()
      .firstWhere((n) => n['handle'] == map['root']);
  return root['children']! as List;
}

/// The embedding fixture with [payloads] (by number) written as raw
/// `jetcad.unit_data` payloads, through bytes, in the codec's own order
/// (type ids sorted, handles ascending), so this build writes it back
/// byte for byte.
String fixtureWith(Map<String, Object?> payloads) {
  final c = PlanController(kits: [fxKit()], json: embeddingPlanJson());
  final doc = c.document;
  final byHandle = <int, Object?>{
    for (final e in payloads.entries) instanceOf(doc, e.key).value: e.value
  };
  c.dispose();
  final json = jsonDecode(embeddingPlanJson()) as Map<String, Object?>;
  final components = (json['components']! as Map).cast<String, Object?>();
  components['jetcad.unit_data'] = {
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
        c.setUnitsData({
          '1': hostData(),
          ' 2 ': {'id': 'bbb'},
          'L': third,
        }),
        isTrue);
    final saved = c.save();
    expect((jsonDecode(saved) as Map)['schemaVersion'], 10);
    expect(dataSection(saved), hasLength(3));

    final back = controller(tester, saved);
    expect(back.save(), saved, reason: 'byte for byte');
    final other = controller(tester);
    other.load(saved);
    expect(other.save(), saved);
    for (final r in [c, back, other]) {
      expect(detailsOf(r, '1').single.data, hostData());
      expect(detailsOf(r, '1').single.data.keys, ['alpha', 'id', 'zeta']);
      expect(detailsOf(r, '2').single.data, {'id': 'bbb'});
      expect(detailsOf(r, 'L').single.data, third);
      expect(detailsOf(r, 'L').single.locked, isTrue);
      for (final d in r.unitDetails) {
        if (const {'1', '2', 'L'}.contains(d.unit.label)) continue;
        expect(d.data, isEmpty, reason: '${d.unit}');
      }
    }
    expect(back.unitDetails, c.unitDetails, reason: 'data included');
    expect(
        () => back.unitDetails.first.data['q'] = 'r', throwsUnsupportedError);
  });

  testWidgets(
      'HD2 M-H24: data inserted as zeta, id, alpha is written with its keys '
      'sorted, under the table\'s instance', (tester) async {
    final c = controller(tester);
    expect(c.setUnitData('1', hostData()), isTrue);
    final h = instanceOf(c.document, '1').value;
    expect(c.save(), contains('"jetcad.unit_data":{"$h":$hostPayload}'));
  });

  testWidgets(
      'HD3 M-H22: a number two tables carry is refused, whichever way it is '
      'written; so are an unknown and an empty number', (tester) async {
    final c = controller(tester);
    final before = c.save();
    for (final n in ['7', ' 7 ', '42', '', '  ']) {
      expect(c.setUnitData(n, hostData()), isFalse, reason: '"$n"');
    }
    await tester.pump();
    expect(detailsOf(c, '7'), hasLength(2), reason: 'premise: two 7s');
    for (final d in detailsOf(c, '7')) {
      expect(d.data, isEmpty);
    }
    expect(c.save(), before);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'HD4 M-H23: in service both throw a StateError; the design '
      'and the copy are untouched', (tester) async {
    final c = controller(tester);
    c.setUnitData('2', {'id': 'two'});
    final before = c.save();
    c.setMode(PlanMode.service);
    await tester.pump();
    final copy = c.unitDetails;
    expect(detailsOf(c, '2').single.data, {'id': 'two'},
        reason: 'the copy carries it, read only');
    expect(() => c.setUnitData('1', hostData()), throwsStateError);
    expect(() => c.setUnitsData({'1': hostData()}), throwsStateError);
    expect(() => c.setUnitData('2', const {}), throwsStateError);
    await tester.pump();
    expect(c.save(), before);
    expect(c.unitDetails, copy);
    expect(c.canUndo.value, isFalse);
    c.setMode(PlanMode.design);
    expect(detailsOf(c, '1').single.data, isEmpty);
    expect(detailsOf(c, '2').single.data, {'id': 'two'});
  });

  testWidgets(
      'HD5 M-H24b: an empty map removes the data: no jetcad.unit_data '
      'section at all', (tester) async {
    final c = controller(tester);
    final empty = c.save();
    c.setUnitData('1', hostData());
    expect(dataSection(c.save()), isNotNull, reason: 'premise');
    expect(c.setUnitData('1', const {}), isTrue);
    final json = c.save();
    expect(json, isNot(contains('jetcad.unit_data')));
    expect(json, empty);
    expect(detailsOf(c, '1').single.data, isEmpty);
    expect(c.setUnitData('1', const {}), isTrue,
        reason: 'no data to remove: true, no step');
  });

  testWidgets(
      'HD6 M-H28: a plan whose data is outside the limits loads; each such '
      'table reads empty data, is reported table.invalid_data, and is '
      'written back byte for byte; a later setUnitData replaces it',
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
    expect(c.save(), json, reason: 'written back as read');
    expect(controller(tester, json).save(), json);
    for (final n in ['1', '2', '3', '4', 'L']) {
      expect(detailsOf(c, n).single.data, isEmpty, reason: n);
    }
    expect(detailsOf(c, '5').single.data, hostData(),
        reason: 'a valid payload beside them reads (hidden table)');
    final doc = c.document;
    final invalid = unitDiagnostics(doc)
        .where((d) => d.code == 'unit.invalid_data')
        .map((d) => d.handles.single)
        .toList();
    expect(invalid, [
      for (final n in ['1', '2', '3', '4', 'L']) instanceOf(doc, n)
    ]);

    // The service copy decodes it the same way.
    c.setMode(PlanMode.service);
    await tester.pump();
    expect(detailsOf(c, '1').single.data, isEmpty);
    expect(detailsOf(c, '5').single.data, hostData());
    c.setMode(PlanMode.design);

    expect(c.setUnitData('1', {'id': 'one'}), isTrue);
    expect(c.setUnitData('2', const {}), isTrue, reason: 'removes it');
    final next = c.save();
    final section = dataSection(next)!;
    expect(section['${instanceOf(doc, '1').value}'], {
      'data': {'id': 'one'}
    });
    expect(section.containsKey('${instanceOf(doc, '2').value}'), isFalse);
    expect(section['${instanceOf(doc, '3').value}'], payloads['3']);
    expect(
        unitDiagnostics(doc)
            .where((d) => d.code == 'unit.invalid_data')
            .map((d) => d.handles.single),
        [
          for (final n in ['3', '4', 'L']) instanceOf(doc, n)
        ]);
    c.undo();
    c.undo();
    expect(c.save(), json, reason: 'undo restores the kept payloads');
  });

  testWidgets(
      'HD7 M-H29(setUnitsData): one bad entry changes nothing: an '
      'ambiguous number, an unknown one, two keys trimming to one number '
      'are false; a map outside the limits throws first', (tester) async {
    final c = controller(tester);
    final before = c.save();
    expect(c.setUnitsData({'1': hostData(), '7': hostData()}), isFalse);
    expect(c.setUnitsData({'1': hostData(), '42': hostData()}), isFalse);
    expect(
        c.setUnitsData({
          '1': hostData(),
          ' 1': {'id': 'b'}
        }),
        isFalse);
    expect(
        () => c.setUnitsData({
              '1': hostData(),
              '2': {'Bad': 'x'}
            }),
        throwsArgumentError);
    expect(
        () => c.setUnitsData({
              '42': hostData(),
              '2': {'a': 'x\u0085'}
            }),
        throwsArgumentError,
        reason: 'the maps are checked before the numbers');
    await tester.pump();
    expect(detailsOf(c, '1').single.data, isEmpty);
    expect(c.canUndo.value, isFalse);
    expect(c.save(), before);
  });

  testWidgets(
      'HD8 setUnitsData is one undo step labelled "Unit data"; entries '
      'already equal are skipped; nothing to change is no step; hidden and '
      'locked tables take data', (tester) async {
    final c = controller(tester);
    final doc = c.document;
    final labels = <String>[];
    final sub = doc.changes.listen((e) {
      if (e is CommandApplied) labels.add(e.label);
    });
    addTearDown(sub.cancel);
    final depth = doc.commands.undoDepth;
    expect(
        c.setUnitsData({
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

    final after = c.save();
    expect(
        c.setUnitsData({
          '5': {'id': 'hidden'},
          ' L ': {'id': 'locked'},
        }),
        isTrue);
    expect(
        c.setUnitData('3', {'zeta': 'Masa 4.ğ', 'alpha': '', 'id': '7f3c-ä'}),
        isTrue);
    expect(c.setUnitsData(const {}), isTrue);
    expect(doc.commands.undoDepth, depth + 1, reason: 'no step');
    expect(c.save(), after);

    expect(
        c.setUnitsData({
          '5': const {},
          '3': hostData(),
          '4': {'id': '4'}
        }),
        isTrue);
    expect(doc.commands.undoDepth, depth + 2);
    expect(detailsOf(c, '5').single.data, isEmpty);
    expect(detailsOf(c, '4').single.data, {'id': '4'});
    await tester.pump();
    expect(labels, ['Unit data', 'Unit data']);
    c.undo();
    expect(c.save(), after);
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
    expect(c.setUnitData('4', full), isTrue);
    expect(detailsOf(c, '4').single.data, full);
    final before = c.save();
    final refused = <Map<String, String>>[
      {...full, 'k99': 'x'},
      {'${key64}q': 'v'},
      {'a': '${value1024}x'},
      {'a': astral1025},
      {'a': 'x\u0085y'},
      {'Id': 'x'},
    ];
    for (final data in refused) {
      expect(() => c.setUnitData('4', data), throwsArgumentError,
          reason: '$data');
    }
    expect(c.save(), before);
    expect(detailsOf(c, '4').single.data, full);

    // E-6 counts UTF-16 units, not characters (review R-1): 512 surrogate
    // pairs are 1024 units, accepted; 1023 units and one pair are 1025,
    // refused on write, and kept verbatim and read empty on load.
    expect(c.setUnitData('4', {'a': astral1024}), isTrue);
    expect(detailsOf(c, '4').single.data, {'a': astral1024});
    final json = fixtureWith({
      '4': {
        'data': {'a': astral1025}
      },
    });
    c.load(json);
    expect(c.save(), json, reason: 'written back as read');
    expect(detailsOf(c, '4').single.data, isEmpty);
    final doc = c.document;
    expect(
        unitDiagnostics(doc)
            .where((d) => d.code == 'unit.invalid_data')
            .map((d) => d.handles.single),
        [instanceOf(doc, '4')]);
  });

  testWidgets('HD10 renumbering 1 to 21 keeps its data: it is the instance\'s',
      (tester) async {
    final c = controller(tester);
    c.setUnitData('1', hostData());
    final doc = c.document;
    final label = c.unitIndex.withLabel('1').single.label!;
    doc.commands.execute(SetEntityTextCommand(label, '21', kUnitLabelTag));
    expect(detailsOf(c, '1'), isEmpty);
    expect(detailsOf(c, '21').single.data, hostData());
    expect(c.setUnitData('21', {'id': 'new'}), isTrue);
    expect(detailsOf(c, '21').single.data, {'id': 'new'});
    expect(c.setUnitData('1', {'id': 'x'}), isFalse);
  });

  testWidgets(
      'HD11 undo and redo of setUnitData; dirty and canUndo on return, '
      'revision after the change; dirty again after markSaved', (tester) async {
    final c = controller(tester);
    await tester.pump();
    final revision = c.revision.value;
    expect(c.dirty.value, isFalse);
    expect(c.setUnitData('2', hostData()), isTrue);
    expect(c.dirty.value, isTrue, reason: 'on return');
    expect(c.canUndo.value, isTrue, reason: 'on return');
    await tester.pump();
    expect(c.revision.value, greaterThan(revision));
    final withData = c.save();
    c.markSaved();
    expect(c.dirty.value, isFalse);

    c.undo();
    await tester.pump();
    expect(detailsOf(c, '2').single.data, isEmpty);
    expect(dataSection(c.save()), isNull);
    expect(c.dirty.value, isTrue);
    c.redo();
    await tester.pump();
    expect(detailsOf(c, '2').single.data, hostData());
    expect(c.save(), withData);
    expect(c.dirty.value, isFalse, reason: 'back at the save point');
    expect(c.setUnitData('2', {'id': 'other'}), isTrue);
    expect(c.dirty.value, isTrue, reason: 'an edit after markSaved');
  });

  testWidgets(
      'HD12 M-H27 (E-9 gate 3): the editor\'s Delete of table 1 drops its '
      'data in the same step; Undo puts it back, the plan as it was byte '
      'for byte (O-10), not dirty', (tester) async {
    final c = controller(tester);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanEditor(controller: c))));
    await tester.pump();
    await tester.pump();
    expect(
        c.setUnitsData({
          '1': hostData(),
          '2': {'id': 'two'}
        }),
        isTrue);
    final doc = c.document;
    final one = instanceOf(doc, '1'), two = instanceOf(doc, '2');
    final before = c.save();
    c.markSaved();
    final root = rootChildren(before);
    expect(root.indexOf(one.value), lessThan(root.length - 1),
        reason: 'premise: table 1 is not the root\'s last child');
    final depth = doc.commands.undoDepth;
    c.select({'1'});
    await tester.pump();
    expect(c.editorSelectedUnits.value, {'1'}, reason: 'premise');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(doc.tree[one], isNull, reason: 'premise: deleted');
    expect(doc.commands.undoDepth, depth + 1, reason: 'one step');
    final deleted = c.save();
    expect(dataSection(deleted), {
      '${two.value}': {
        'data': {'id': 'two'}
      }
    });

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(detailsOf(c, '1').single.data, hostData());
    expect(c.save(), before);
    expect(c.dirty.value, isFalse, reason: 'back at the save point');
  });
}
