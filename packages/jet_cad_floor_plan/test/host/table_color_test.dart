// Plan colours spec PC-4 and PC-11 (Slice 2 plan, Task 2): a table's colour
// as the plan stores it -- the `jetcad.table_color` component on the table's
// instance -- and as a host reads and writes it: `FloorPlanTableDetail.color`,
// `setTableColor` and `setTablesColor`, which share one path with the
// table-data setters. On the embedding fixture: tables turned 30 degrees,
// mirrored at 90, scaled, turned 180, all 40 m off the origin, their top
// off-centre and asymmetric; `5` hidden, `L` locked; `7` and ` 7 ` sharing
// a number; an unnumbered table. Hues `teal` and `purple`, and the unknown
// name `magenta`.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart' show FloorPlanColor;
import 'package:jet_cad_floor_plan/src/host/design_changes.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/table_detail.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart'
    show registerAppComponents;
import 'package:jet_cad_floor_plan/src/symbols/symbol_section.dart'
    show changeSizeCommand;
import 'package:jet_cad_floor_plan/src/tables/table_color_component.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/symbols.dart'
    show FurnitureSymbol, PolylineShape;

import '../tables/table_fixture.dart' show entryOf;
import 'embedding_fixture.dart';

const FloorPlanColor teal = FloorPlanColor.teal;
const FloorPlanColor purple = FloorPlanColor.purple;

FloorPlanController controller(WidgetTester tester, [String? json]) {
  final c = FloorPlanController(json: json ?? embeddingPlanJson());
  addTearDown(c.dispose);
  return c;
}

/// [controller] shown in a design view of 1440 x 900, fitted (the shell's
/// Delete and its data expander run).
Future<FloorPlanController> mounted(WidgetTester tester) async {
  final c = controller(tester);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FloorPlanView(controller: c))));
  await tester.pump();
  await tester.pump();
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

/// The `jetcad.table_color` section of the encoding [json], or null.
Map<String, Object?>? colorSection(String json) =>
    ((jsonDecode(json) as Map)['components'] as Map)['jetcad.table_color']
        as Map<String, Object?>?;

/// The embedding fixture with [payloads] (by number) written as raw
/// `jetcad.table_color` payloads, in the codec's own order (type ids
/// sorted, handles ascending), so this build writes it back byte for byte.
String fixtureWith(Map<String, Object?> payloads) {
  final doc = DraftDocumentCodec.decodeString(embeddingPlanJson(),
      registerComponents: registerAppComponents);
  final byHandle = <int, Object?>{
    for (final e in payloads.entries) instanceOf(doc, e.key).value: e.value
  };
  doc.dispose();
  final json = jsonDecode(embeddingPlanJson()) as Map<String, Object?>;
  final components = (json['components']! as Map).cast<String, Object?>();
  components['jetcad.table_color'] = {
    for (final h in byHandle.keys.toList()..sort()) '$h': byHandle[h]
  };
  json['components'] = {
    for (final k in components.keys.toList()..sort()) k: components[k]
  };
  return jsonEncode(json);
}

/// Every change [c] reports from now on, in order.
List<FloorPlanDesignChange> listen(FloorPlanController c) {
  final seen = <FloorPlanDesignChange>[];
  final sub = c.designChanges.listen(seen.add);
  addTearDown(sub.cancel);
  return seen;
}

/// The labels of the commands [doc] applies from now on.
List<String> labelsOf(DraftDocument doc) {
  final labels = <String>[];
  final sub = doc.changes.listen((e) {
    if (e is CommandApplied) labels.add(e.label);
  });
  addTearDown(sub.cancel);
  return labels;
}

/// [d] with its colour replaced.
FloorPlanTableDetail withColor(FloorPlanTableDetail d, FloorPlanColor? color) =>
    FloorPlanTableDetail(
        table: d.table,
        center: d.center,
        size: d.size,
        rotation: d.rotation,
        mirrored: d.mirrored,
        corners: d.corners,
        layer: d.layer,
        locked: d.locked,
        data: d.data,
        color: color);

void main() {
  test(
      'TC1 M-C1 (tables) the component: teal encodes {"color":"teal"}; an '
      'unknown name is stored as read; any other shape is kept verbatim; '
      'nothing throws', () {
    final made = FloorPlanTableColor(teal);
    expect(made.toJson(), {'color': 'teal'});
    expect(jsonEncode(made.toJson()), '{"color":"teal"}');
    expect(made.name, 'teal');
    expect(made.colorValue, teal);
    expect(made.isKept, isFalse);
    expect(FloorPlanTableColor.fromJson({'color': 'teal'}), made);
    expect(FloorPlanTableColor.fromJson({'color': 'teal'}).hashCode,
        made.hashCode);
    expect(FloorPlanTableColor.fromJson({'color': 'purple'}) == made, isFalse);
    expect(FloorPlanTableColor(purple).colorValue, purple);

    final unknown = FloorPlanTableColor.fromJson({'color': 'magenta'});
    expect(unknown.name, 'magenta');
    expect(unknown.colorValue, isNull);
    expect(unknown.isKept, isFalse);
    expect(unknown.toJson(), {'color': 'magenta'});
    expect(unknown == made, isFalse);

    for (final raw in <Map<String, Object?>>[
      {'color': 7},
      {'hue': 'teal'},
      {'color': 'teal', 'x': 1},
      {'color': null},
      {
        'color': <Object?>['teal']
      },
      <String, Object?>{},
    ]) {
      final kept = FloorPlanTableColor.fromJson(raw);
      expect(kept.isKept, isTrue, reason: '$raw');
      expect(kept.name, isNull, reason: '$raw');
      expect(kept.colorValue, isNull, reason: '$raw');
      expect(kept.toJson(), raw, reason: '$raw');
      expect(jsonEncode(kept.toJson()), jsonEncode(raw), reason: '$raw');
      expect(kept == made, isFalse, reason: '$raw');
      expect(FloorPlanTableColor.fromJson(raw), kept, reason: '$raw');
    }
    final deep = FloorPlanTableColor.fromJson({
      'color': {
        'a': [1, 2]
      }
    });
    expect(() => (deep.kept!['color'] as Map)['b'] = 1, throwsUnsupportedError,
        reason: 'unmodifiable all the way down');
  });

  testWidgets(
      'TC2 setTableColor: true; one undo step labelled "Table colour"; '
      'dirty, canUndo and revision moved; tableDetails reads it; the file '
      'holds it on the instance; undo removes it, redo puts it back',
      (tester) async {
    final c = controller(tester);
    await tester.pump();
    final doc = c.activeDocument;
    final labels = labelsOf(doc);
    final revision = c.revision.value;
    final depth = doc.commands.undoDepth;
    final empty = c.designJson();
    expect(c.dirty.value, isFalse);
    expect(colorSection(empty), isNull, reason: 'premise');

    expect(c.setTableColor('1', teal), isTrue);
    expect(c.dirty.value, isTrue, reason: 'on return');
    expect(c.canUndo.value, isTrue, reason: 'on return');
    expect(doc.commands.undoDepth, depth + 1);
    await tester.pump();
    expect(labels, ['Table colour']);
    expect(c.revision.value, greaterThan(revision));
    expect(detailsOf(c, '1').single.color, teal);
    for (final d in c.tableDetails) {
      if (d.table.number == '1') continue;
      expect(d.color, isNull, reason: '${d.table}');
    }
    final one = instanceOf(doc, '1').value;
    final saved = c.designJson();
    expect(saved, contains('"jetcad.table_color":{"$one":{"color":"teal"}}'));
    expect(colorSection(saved), {
      '$one': {'color': 'teal'}
    });

    final back = controller(tester, saved);
    expect(back.designJson(), saved, reason: 'byte for byte');
    expect(detailsOf(back, '1').single.color, teal);

    c.undo();
    await tester.pump();
    expect(detailsOf(c, '1').single.color, isNull);
    expect(colorSection(c.designJson()), isNull);
    expect(c.designJson(), empty);
    c.redo();
    await tester.pump();
    expect(detailsOf(c, '1').single.color, teal);
    expect(c.designJson(), saved);
  });

  testWidgets(
      'TC3 M-C9 setTablesColor: one undo step for several tables; one bad '
      'entry (a number two tables carry, the same number twice, an unknown '
      'one) changes nothing, whatever its place in the map', (tester) async {
    // Each bad map on a controller of its own: nothing edited, nothing to
    // undo. The valid entries come first, so a path that executes as it
    // goes has changed table 1 by the time it meets the bad one.
    final bad = <String, Map<String, FloorPlanColor?>>{
      'shared number': {'1': teal, '7': purple},
      'shared number (padded)': {'1': teal, ' 7 ': purple},
      'the same number twice': {'1': teal, ' 1 ': purple},
      'unknown number': {'1': teal, '42': purple},
      'empty number': {'1': teal, '': purple},
    };
    for (final MapEntry(key: why, value: wanted) in bad.entries) {
      final fresh = controller(tester);
      final before = fresh.designJson();
      expect(fresh.setTablesColor(wanted), isFalse, reason: why);
      expect(detailsOf(fresh, '1').single.color, isNull, reason: why);
      expect(fresh.activeDocument.commands.undoDepth, 0, reason: why);
      expect(fresh.canUndo.value, isFalse, reason: why);
      expect(fresh.dirty.value, isFalse, reason: why);
      expect(fresh.designJson(), before, reason: why);
    }
    final c = controller(tester);
    final doc = c.activeDocument;
    expect(c.setTablesColor({'1': teal, ' 2 ': purple, 'L': null}), isTrue);
    expect(doc.commands.undoDepth, 1, reason: 'one step for two edits');
    expect(detailsOf(c, '1').single.color, teal);
    expect(detailsOf(c, '2').single.color, purple);
    expect(detailsOf(c, 'L').single.color, isNull);
    c.undo();
    expect(doc.commands.undoDepth, 0);
    expect(detailsOf(c, '1').single.color, isNull);
    expect(detailsOf(c, '2').single.color, isNull);

    expect(c.setTableColor('7', teal), isFalse);
    expect(c.setTableColor('42', teal), isFalse);
    expect(c.setTablesColor(const {}), isTrue, reason: 'nothing to change');
    expect(doc.commands.undoDepth, 0);
  });

  testWidgets(
      'TC4 an entry equal to the table\'s colour is skipped: no edit; '
      'removing a colour that is not there is true with no edit',
      (tester) async {
    final c = controller(tester);
    final doc = c.activeDocument;
    expect(c.setTableColor('1', teal), isTrue);
    expect(doc.commands.undoDepth, 1);
    expect(c.setTableColor(' 1 ', teal), isTrue);
    expect(doc.commands.undoDepth, 1, reason: 'the second is no edit');
    expect(c.setTableColor('2', null), isTrue);
    expect(doc.commands.undoDepth, 1, reason: 'no colour to remove');
    expect(c.setTablesColor({'1': teal, '2': null}), isTrue);
    expect(doc.commands.undoDepth, 1, reason: 'both skipped');
    expect(c.setTablesColor({'1': teal, '3': purple}), isTrue);
    expect(doc.commands.undoDepth, 2, reason: 'only 3 is an edit');
    expect(c.setTableColor('1', null), isTrue);
    expect(doc.commands.undoDepth, 3);
    expect(detailsOf(c, '1').single.color, isNull);
    expect(colorSection(c.designJson())!.length, 1, reason: 'only 3 left');
  });

  testWidgets(
      'TC5 a table on the hidden layer and one on the locked layer take a '
      'colour, and the API recolours the locked one', (tester) async {
    final c = controller(tester);
    expect(detailsOf(c, '5').single.center, isNull,
        reason: 'premise: 5 is hidden');
    expect(detailsOf(c, 'L').single.locked, isTrue, reason: 'premise');
    expect(c.setTablesColor({'5': teal, 'L': purple}), isTrue);
    expect(detailsOf(c, '5').single.color, teal);
    expect(detailsOf(c, 'L').single.color, purple);
    expect(detailsOf(c, 'L').single.locked, isTrue);
    expect(c.setTableColor('L', FloorPlanColor.red), isTrue);
    expect(detailsOf(c, 'L').single.color, FloorPlanColor.red);
    expect(c.setTableColor('L', null), isTrue);
    expect(detailsOf(c, 'L').single.color, isNull);
    expect(detailsOf(c, '5').single.color, teal);
  });

  testWidgets(
      'TC6 M-PC11-a in the selection mode setTableColor and setTablesColor '
      'throw a StateError, the design untouched; the service copy reads the '
      'design\'s colour', (tester) async {
    final c = controller(tester);
    expect(c.setTableColor('2', purple), isTrue);
    final before = c.designJson();
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    expect(detailsOf(c, '2').single.color, purple,
        reason: 'the copy carries it, read only');
    expect(detailsOf(c, '1').single.color, isNull);
    expect(() => c.setTableColor('1', teal), throwsStateError);
    expect(() => c.setTablesColor({'1': teal}), throwsStateError);
    expect(() => c.setTableColor('2', null), throwsStateError);
    expect(() => c.setTablesColor(const {}), throwsStateError);
    expect(
        () => c.setTableColor('1', teal),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            'setTableColor needs the design mode (P-5)')));
    expect(
        () => c.setTableData('1', const {'a': 'b'}),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            'setTableData needs the design mode (P-5)')));
    await tester.pump();
    expect(c.designJson(), before);
    expect(c.canUndo.value, isFalse);
    c.setMode(FloorPlanMode.design);
    expect(detailsOf(c, '1').single.color, isNull);
    expect(detailsOf(c, '2').single.color, purple);
  });

  testWidgets(
      'TC7 M-C2 M-PC11-b a colour this release cannot read: the plan opens; '
      'each such table reads colour null and is reported table.invalid_color; '
      'the payloads are written back byte for byte; null removes one without '
      'a change reported, a hue replaces one', (tester) async {
    final payloads = <String, Object?>{
      '1': {'color': 7},
      '2': {'color': 'magenta'},
      '3': {'color': 'teal', 'x': 1},
      'L': {'hue': 'teal'},
      '4': {'color': 'purple'},
    };
    final json = fixtureWith(payloads);
    final c = controller(tester);
    c.load(json);
    expect(c.designJson(), json, reason: 'written back as read');
    expect(controller(tester, json).designJson(), json);
    for (final n in ['1', '2', '3', 'L']) {
      expect(detailsOf(c, n).single.color, isNull, reason: n);
    }
    expect(detailsOf(c, '4').single.color, purple,
        reason: 'a readable payload beside them reads');
    final doc = c.activeDocument;
    List<Handle> invalid() => [
          for (final d in tableDiagnostics(doc))
            if (d.code == 'table.invalid_color') d.handles.single
        ];
    expect(invalid(), [
      for (final n in ['1', '2', '3', 'L']) instanceOf(doc, n)
    ]);
    expect(TableDiagnosticCodes.invalidColor, 'table.invalid_color');
    final warning = tableDiagnostics(doc)
        .firstWhere((d) => d.code == 'table.invalid_color');
    expect(warning.severity, DiagnosticSeverity.warning);
    expect(warning.message, contains(instanceOf(doc, '1').toHex()));

    // The service copy decodes it the same way.
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    expect(detailsOf(c, '1').single.color, isNull);
    expect(detailsOf(c, '2').single.color, isNull);
    expect(detailsOf(c, '4').single.color, purple);
    c.setMode(FloorPlanMode.design);
    await tester.pump();

    final seen = listen(c);
    expect(c.dirty.value, isFalse);
    expect(c.setTableColor('1', null), isTrue, reason: 'removes the kept one');
    expect(c.dirty.value, isTrue, reason: 'an edit');
    await tester.pump();
    expect(seen, isEmpty,
        reason: 'colour null before and after: no change to report');
    final section = colorSection(c.designJson())!;
    expect(section.containsKey('${instanceOf(doc, '1').value}'), isFalse);
    expect(section['${instanceOf(doc, '2').value}'], {'color': 'magenta'});
    expect(section['${instanceOf(doc, '3').value}'], payloads['3']);
    expect(section['${instanceOf(doc, 'L').value}'], payloads['L']);

    expect(c.setTableColor('2', teal), isTrue, reason: 'replaces magenta');
    await tester.pump();
    expect(seen, hasLength(1));
    final change = seen.single as FloorPlanTableChanged;
    expect(change.before.color, isNull);
    expect(change.after.color, teal);
    expect(invalid(), [
      for (final n in ['3', 'L']) instanceOf(doc, n)
    ]);
    c.undo();
    c.undo();
    expect(c.designJson(), json, reason: 'undo restores the kept payloads');
  });

  testWidgets(
      'TC8 M-C11 (witness) deleting a coloured table in the editor drops '
      'its colour in the same step; Undo puts it back: the component, the '
      'table in tableDetails, and designChanges\' Added carrying the colour',
      (tester) async {
    final c = await mounted(tester);
    final doc = c.activeDocument;
    expect(c.setTableColor('3', teal), isTrue);
    final three = instanceOf(doc, '3');
    final withColor = detailsOf(c, '3').single;
    expect(withColor.color, teal, reason: 'premise');
    expect(c.tableDetailInstances.last.value > three.value, isTrue,
        reason: 'premise: tables after 3, which an index diff shifts');
    final before = c.designJson();
    c.markSaved();
    final seen = listen(c);

    c.select({'3'});
    await tester.pump();
    expect(c.selectedTables.value, {'3'}, reason: 'premise');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(doc.tree[three], isNull, reason: 'premise: deleted');
    expect(doc.components.get<FloorPlanTableColor>(three), isNull,
        reason: 'the colour left with the table');
    expect(c.designJson(), isNot(contains('jetcad.table_color')));
    expect(seen, [FloorPlanTableRemoved(withColor)]);
    expect((seen.single as FloorPlanTableRemoved).table.color, teal);

    c.undo();
    await tester.pump();
    expect(doc.components.get<FloorPlanTableColor>(three),
        FloorPlanTableColor(teal));
    expect(detailsOf(c, '3').single, withColor);
    expect(detailsOf(c, '3').single.color, teal);
    expect(c.designJson(), before);
    expect(c.dirty.value, isFalse, reason: 'back at the save point');
    expect(seen,
        [FloorPlanTableRemoved(withColor), FloorPlanTableAdded(withColor)]);
    expect((seen[1] as FloorPlanTableAdded).table.color, teal);
  });

  testWidgets(
      'TC9 M-C14 designChanges: a recolour is one Changed, colour null to '
      'teal and nothing else; a renumber and a change of size keep the '
      'colour', (tester) async {
    final c = await mounted(tester);
    final doc = c.activeDocument;
    final two = instanceOf(doc, '2');
    final b2 = detailsOf(c, '2').single;
    expect(b2.mirrored, isTrue, reason: 'premise: 2 is the mirrored one');
    expect(b2.color, isNull);
    final seen = listen(c);

    expect(c.setTableColor('2', teal), isTrue);
    await tester.pump();
    expect(seen, [FloorPlanTableChanged(b2, withColor(b2, teal))]);
    expect((seen.single as FloorPlanTableChanged).before.color, isNull);
    expect((seen.single as FloorPlanTableChanged).after.color, teal);
    expect(withColor(b2, teal) == b2, isFalse, reason: '== reads the colour');
    expect(withColor(b2, teal).hashCode == b2.hashCode, isFalse);
    expect(withColor(b2, teal), withColor(b2, teal));
    expect(withColor(b2, teal) == withColor(b2, purple), isFalse);
    expect(withColor(b2, teal).toString(), contains('color: '));
    expect(b2.toString(), isNot(contains('color')),
        reason: 'no colour, no change to a host\'s log line');

    expect(c.setTableColor('2', teal), isTrue);
    await tester.pump();
    expect(seen, hasLength(1), reason: 'no edit, no change');

    // A renumber of the coloured table keeps the colour.
    seen.clear();
    final label = TableSurvey.of(doc).withNumber('2').single.label!;
    doc.commands.execute(SetEntityTextCommand(label, '22', kTableLabelTag));
    await tester.pump();
    expect(detailsOf(c, '2'), isEmpty);
    expect(detailsOf(c, '22').single.color, teal);
    expect(seen, hasLength(1));
    expect((seen.single as FloorPlanTableChanged).before.color, teal);
    expect((seen.single as FloorPlanTableChanged).after.color, teal);
    expect(c.setTableColor('22', purple), isTrue);
    expect(detailsOf(c, '22').single.color, purple);
    expect(c.setTableColor('22', teal), isTrue);

    // Change size (the Symbol section's Size menu, F-17): the instance
    // takes another definition; its components stay on the instance.
    seen.clear();
    const other = FurnitureSymbol(
      key: 'test.embedding.wide',
      name: 'Test embedding table, wide',
      category: 'Tests',
      tags: ['table', 'test'],
      seats: 6,
      baseX: 0,
      baseY: 0,
      shapes: [
        PolylineShape([(300, -200), (1500, -200), (1300, 400), (300, 250)],
            closed: true),
      ],
    );
    final node = doc.tree[two]! as InstanceNode;
    final oldDefinition = node.definition;
    doc.commands.execute(changeSizeCommand(doc, two, entryOf(other))!);
    await tester.pump();
    expect((doc.tree[two]! as InstanceNode).definition, isNot(oldDefinition),
        reason: 'premise: another definition');
    expect(doc.components.get<FloorPlanTableColor>(two),
        FloorPlanTableColor(teal));
    final now = c.tableDetails[c.tableDetailInstances.indexOf(two)];
    expect(now.color, teal);
    expect(now.table.seats, 6, reason: 'premise: the new size');
    expect(seen, hasLength(1));
    expect((seen.single as FloorPlanTableChanged).before.color, teal);
    expect((seen.single as FloorPlanTableChanged).after.color, teal);
    c.undo();
    await tester.pump();
    expect(c.tableDetails[c.tableDetailInstances.indexOf(two)].color, teal);
  });
}
