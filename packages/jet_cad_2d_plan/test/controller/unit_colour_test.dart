// Ported from jet_cad_floor_plan test/host/table_color_test.dart (2b Task
// 9, spec S2 "Per-unit data", S3 "Design writes"): setUnitColour and
// setUnitsColour on the embedding fixture. TC1 (the component's encoding)
// is Task 6's; TC6 (the service mode) is Task 11's. Today's header
// follows.
//
// Plan colours spec PC-4 and PC-11 (Slice 2 plan, Task 2): a table's colour
// as the plan stores it -- the `jetcad.unit_colour` component on the table's
// instance -- and as a host reads and writes it: `PlanUnitDetail.colour`,
// `setUnitColour` and `setUnitsColour`, which share one path with the
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
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogPolyline, CatalogSymbol, CatalogUnit;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show PlanSwatch, UnitKinds, kUnitLabelTag;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart' show LockSet;
import 'package:jet_cad_2d_plan/src/panels/symbol_section.dart'
    show changeSizeCommand;
import 'package:jet_cad_2d_plan/src/units/unit_components.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:jet_cad_2d_plan/src/units/unit_problems.dart' show UnitProblem;

import '../support/unit_embedding_fixture.dart';
import '../support/unit_fixtures.dart' show entryOf, fxKit;

const PlanSwatch teal = PlanSwatch.teal;
const PlanSwatch purple = PlanSwatch.purple;

PlanController controller(WidgetTester tester, [String? json]) {
  final c = PlanController(kits: [fxKit()], json: json ?? embeddingPlanJson());
  addTearDown(c.dispose);
  return c;
}

/// [controller] shown in a design view of 1440 x 900, fitted (the shell's
/// Delete and its data expander run).
Future<PlanController> mounted(WidgetTester tester) async {
  final c = controller(tester);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester
      .pumpWidget(MaterialApp(home: Scaffold(body: PlanEditor(controller: c))));
  await tester.pump();
  await tester.pump();
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

/// The `jetcad.unit_colour` section of the encoding [json], or null.
Map<String, Object?>? colorSection(String json) =>
    ((jsonDecode(json) as Map)['components'] as Map)['jetcad.unit_colour']
        as Map<String, Object?>?;

/// The embedding fixture with [payloads] (by number) written as raw
/// `jetcad.unit_colour` payloads, in the codec's own order (type ids
/// sorted, handles ascending), so this build writes it back byte for byte.
String fixtureWith(Map<String, Object?> payloads) {
  final c = PlanController(kits: [fxKit()], json: embeddingPlanJson());
  final doc = c.document;
  final byHandle = <int, Object?>{
    for (final e in payloads.entries) instanceOf(doc, e.key).value: e.value
  };
  c.dispose();
  final json = jsonDecode(embeddingPlanJson()) as Map<String, Object?>;
  final components = (json['components']! as Map).cast<String, Object?>();
  components['jetcad.unit_colour'] = {
    for (final h in byHandle.keys.toList()..sort()) '$h': byHandle[h]
  };
  json['components'] = {
    for (final k in components.keys.toList()..sort()) k: components[k]
  };
  return jsonEncode(json);
}

/// Every change [c] reports from now on, in order.
List<PlanUnitChange> listen(PlanController c) {
  final seen = <PlanUnitChange>[];
  final sub = c.unitChanges.listen(seen.add);
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
PlanUnitDetail withColor(PlanUnitDetail d, PlanSwatch? color) => PlanUnitDetail(
    unit: d.unit,
    center: d.center,
    size: d.size,
    rotation: d.rotation,
    mirrored: d.mirrored,
    corners: d.corners,
    layer: d.layer,
    locked: d.locked,
    data: d.data,
    colour: color);

void main() {
  // TC1 (the component's encoding) is Task 6's (unit_components_test).

  testWidgets(
      'TC2 setUnitColour: true; one undo step labelled "Unit colour"; '
      'dirty, canUndo and revision moved; tableDetails reads it; the file '
      'holds it on the instance; undo removes it, redo puts it back',
      (tester) async {
    final c = controller(tester);
    await tester.pump();
    final doc = c.document;
    final labels = labelsOf(doc);
    final revision = c.revision.value;
    final depth = doc.commands.undoDepth;
    final empty = c.save();
    expect(c.dirty.value, isFalse);
    expect(colorSection(empty), isNull, reason: 'premise');

    expect(c.setUnitColour('1', teal), isTrue);
    expect(c.dirty.value, isTrue, reason: 'on return');
    expect(c.canUndo.value, isTrue, reason: 'on return');
    expect(doc.commands.undoDepth, depth + 1);
    await tester.pump();
    expect(labels, ['Unit colour']);
    expect(c.revision.value, greaterThan(revision));
    expect(detailsOf(c, '1').single.colour, teal);
    for (final d in c.unitDetails) {
      if (d.unit.label == '1') continue;
      expect(d.colour, isNull, reason: '${d.unit}');
    }
    final one = instanceOf(doc, '1').value;
    final saved = c.save();
    expect(saved, contains('"jetcad.unit_colour":{"$one":{"color":"teal"}}'));
    expect(colorSection(saved), {
      '$one': {'color': 'teal'}
    });

    final back = controller(tester, saved);
    expect(back.save(), saved, reason: 'byte for byte');
    expect(detailsOf(back, '1').single.colour, teal);

    c.undo();
    await tester.pump();
    expect(detailsOf(c, '1').single.colour, isNull);
    expect(colorSection(c.save()), isNull);
    expect(c.save(), empty);
    c.redo();
    await tester.pump();
    expect(detailsOf(c, '1').single.colour, teal);
    expect(c.save(), saved);
  });

  testWidgets(
      'TC3 M-C9 setUnitsColour: one undo step for several tables; one bad '
      'entry (a number two tables carry, the same number twice, an unknown '
      'one) changes nothing, whatever its place in the map', (tester) async {
    // Each bad map on a controller of its own: nothing edited, nothing to
    // undo. The valid entries come first, so a path that executes as it
    // goes has changed table 1 by the time it meets the bad one.
    final bad = <String, Map<String, PlanSwatch?>>{
      'shared number': {'1': teal, '7': purple},
      'shared number (padded)': {'1': teal, ' 7 ': purple},
      'the same number twice': {'1': teal, ' 1 ': purple},
      'unknown number': {'1': teal, '42': purple},
      'empty number': {'1': teal, '': purple},
    };
    for (final MapEntry(key: why, value: wanted) in bad.entries) {
      final fresh = controller(tester);
      final before = fresh.save();
      expect(fresh.setUnitsColour(wanted), isFalse, reason: why);
      expect(detailsOf(fresh, '1').single.colour, isNull, reason: why);
      expect(fresh.document.commands.undoDepth, 0, reason: why);
      expect(fresh.canUndo.value, isFalse, reason: why);
      expect(fresh.dirty.value, isFalse, reason: why);
      expect(fresh.save(), before, reason: why);
    }
    final c = controller(tester);
    final doc = c.document;
    expect(c.setUnitsColour({'1': teal, ' 2 ': purple, 'L': null}), isTrue);
    expect(doc.commands.undoDepth, 1, reason: 'one step for two edits');
    expect(detailsOf(c, '1').single.colour, teal);
    expect(detailsOf(c, '2').single.colour, purple);
    expect(detailsOf(c, 'L').single.colour, isNull);
    c.undo();
    expect(doc.commands.undoDepth, 0);
    expect(detailsOf(c, '1').single.colour, isNull);
    expect(detailsOf(c, '2').single.colour, isNull);

    expect(c.setUnitColour('7', teal), isFalse);
    expect(c.setUnitColour('42', teal), isFalse);
    expect(c.setUnitsColour(const {}), isTrue, reason: 'nothing to change');
    expect(doc.commands.undoDepth, 0);
  });

  testWidgets(
      'TC4 an entry equal to the table\'s colour is skipped: no edit; '
      'removing a colour that is not there is true with no edit',
      (tester) async {
    final c = controller(tester);
    final doc = c.document;
    expect(c.setUnitColour('1', teal), isTrue);
    expect(doc.commands.undoDepth, 1);
    expect(c.setUnitColour(' 1 ', teal), isTrue);
    expect(doc.commands.undoDepth, 1, reason: 'the second is no edit');
    expect(c.setUnitColour('2', null), isTrue);
    expect(doc.commands.undoDepth, 1, reason: 'no colour to remove');
    expect(c.setUnitsColour({'1': teal, '2': null}), isTrue);
    expect(doc.commands.undoDepth, 1, reason: 'both skipped');
    expect(c.setUnitsColour({'1': teal, '3': purple}), isTrue);
    expect(doc.commands.undoDepth, 2, reason: 'only 3 is an edit');
    expect(c.setUnitColour('1', null), isTrue);
    expect(doc.commands.undoDepth, 3);
    expect(detailsOf(c, '1').single.colour, isNull);
    expect(colorSection(c.save())!.length, 1, reason: 'only 3 left');
  });

  testWidgets(
      'TC5 a table on the hidden layer and one on the locked layer take a '
      'colour, and the API recolours the locked one', (tester) async {
    final c = controller(tester);
    expect(detailsOf(c, '5').single.center, isNull,
        reason: 'premise: 5 is hidden');
    expect(detailsOf(c, 'L').single.locked, isTrue, reason: 'premise');
    expect(c.setUnitsColour({'5': teal, 'L': purple}), isTrue);
    expect(detailsOf(c, '5').single.colour, teal);
    expect(detailsOf(c, 'L').single.colour, purple);
    expect(detailsOf(c, 'L').single.locked, isTrue);
    expect(c.setUnitColour('L', PlanSwatch.red), isTrue);
    expect(detailsOf(c, 'L').single.colour, PlanSwatch.red);
    expect(c.setUnitColour('L', null), isTrue);
    expect(detailsOf(c, 'L').single.colour, isNull);
    expect(detailsOf(c, '5').single.colour, teal);
  });

  // TC6 (the service mode throws a StateError) is Task 11's: its Step 3
  // appends it here.

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
    expect(c.save(), json, reason: 'written back as read');
    expect(controller(tester, json).save(), json);
    for (final n in ['1', '2', '3', 'L']) {
      expect(detailsOf(c, n).single.colour, isNull, reason: n);
    }
    expect(detailsOf(c, '4').single.colour, purple,
        reason: 'a readable payload beside them reads');
    final doc = c.document;
    List<Handle> invalid() => [
          for (final d in unitDiagnostics(doc))
            if (d.code == 'unit.invalid_colour') d.handles.single
        ];
    expect(invalid(), [
      for (final n in ['1', '2', '3', 'L']) instanceOf(doc, n)
    ]);
    expect(UnitProblem.invalidColour, 'unit.invalid_colour');
    final warning =
        unitDiagnostics(doc).firstWhere((d) => d.code == 'unit.invalid_colour');
    expect(warning.severity, DiagnosticSeverity.warning);
    expect(warning.message, contains(instanceOf(doc, '1').toHex()));

    // Today's service-copy check (the copy decodes it the same way) needs
    // the service mode: Task 11.

    final seen = listen(c);
    expect(c.dirty.value, isFalse);
    expect(c.setUnitColour('1', null), isTrue, reason: 'removes the kept one');
    expect(c.dirty.value, isTrue, reason: 'an edit');
    await tester.pump();
    expect(seen, isEmpty,
        reason: 'colour null before and after: no change to report');
    final section = colorSection(c.save())!;
    expect(section.containsKey('${instanceOf(doc, '1').value}'), isFalse);
    expect(section['${instanceOf(doc, '2').value}'], {'color': 'magenta'});
    expect(section['${instanceOf(doc, '3').value}'], payloads['3']);
    expect(section['${instanceOf(doc, 'L').value}'], payloads['L']);

    expect(c.setUnitColour('2', teal), isTrue, reason: 'replaces magenta');
    await tester.pump();
    expect(seen, hasLength(1));
    final change = seen.single as PlanUnitChanged;
    expect(change.before.colour, isNull);
    expect(change.after.colour, teal);
    expect(invalid(), [
      for (final n in ['3', 'L']) instanceOf(doc, n)
    ]);
    c.undo();
    c.undo();
    expect(c.save(), json, reason: 'undo restores the kept payloads');
  });

  testWidgets(
      'TC8 M-C11 (witness) deleting a coloured table in the editor drops '
      'its colour in the same step; Undo puts it back: the component, the '
      'table in tableDetails, and unitChanges\' Added carrying the colour',
      (tester) async {
    final c = await mounted(tester);
    final doc = c.document;
    expect(c.setUnitColour('3', teal), isTrue);
    final three = instanceOf(doc, '3');
    final withColor = detailsOf(c, '3').single;
    expect(withColor.colour, teal, reason: 'premise');
    expect(c.unitDetailInstances.last.value > three.value, isTrue,
        reason: 'premise: tables after 3, which an index diff shifts');
    final before = c.save();
    c.markSaved();
    final seen = listen(c);

    c.select({'3'});
    await tester.pump();
    expect(c.editorSelectedUnits.value, {'3'}, reason: 'premise');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(doc.tree[three], isNull, reason: 'premise: deleted');
    expect(doc.components.get<UnitColour>(three), isNull,
        reason: 'the colour left with the table');
    expect(c.save(), isNot(contains('jetcad.unit_colour')));
    expect(seen, [PlanUnitRemoved(withColor)]);
    expect((seen.single as PlanUnitRemoved).unit.colour, teal);

    c.undo();
    await tester.pump();
    expect(doc.components.get<UnitColour>(three), UnitColour(teal));
    expect(detailsOf(c, '3').single, withColor);
    expect(detailsOf(c, '3').single.colour, teal);
    expect(c.save(), before);
    expect(c.dirty.value, isFalse, reason: 'back at the save point');
    expect(seen, [PlanUnitRemoved(withColor), PlanUnitAdded(withColor)]);
    expect((seen[1] as PlanUnitAdded).unit.colour, teal);
  });

  testWidgets(
      'TC9 M-C14 unitChanges: a recolour is one Changed, colour null to '
      'teal and nothing else; a renumber and a change of size keep the '
      'colour', (tester) async {
    final c = await mounted(tester);
    final doc = c.document;
    final two = instanceOf(doc, '2');
    final b2 = detailsOf(c, '2').single;
    expect(b2.mirrored, isTrue, reason: 'premise: 2 is the mirrored one');
    expect(b2.colour, isNull);
    final seen = listen(c);

    expect(c.setUnitColour('2', teal), isTrue);
    await tester.pump();
    expect(seen, [PlanUnitChanged(b2, withColor(b2, teal))]);
    expect((seen.single as PlanUnitChanged).before.colour, isNull);
    expect((seen.single as PlanUnitChanged).after.colour, teal);
    expect(withColor(b2, teal) == b2, isFalse, reason: '== reads the colour');
    expect(withColor(b2, teal).hashCode == b2.hashCode, isFalse);
    expect(withColor(b2, teal), withColor(b2, teal));
    expect(withColor(b2, teal) == withColor(b2, purple), isFalse);
    expect(withColor(b2, teal).toString(), contains('colour: '));
    expect(b2.toString(), isNot(contains('colour')),
        reason: 'no colour, no change to a host\'s log line');

    expect(c.setUnitColour('2', teal), isTrue);
    await tester.pump();
    expect(seen, hasLength(1), reason: 'no edit, no change');

    // A renumber of the coloured table keeps the colour.
    seen.clear();
    final label = c.unitIndex.withLabel('2').single.label!;
    doc.commands.execute(SetEntityTextCommand(label, '22', kUnitLabelTag));
    await tester.pump();
    expect(detailsOf(c, '2'), isEmpty);
    expect(detailsOf(c, '22').single.colour, teal);
    expect(seen, hasLength(1));
    expect((seen.single as PlanUnitChanged).before.colour, teal);
    expect((seen.single as PlanUnitChanged).after.colour, teal);
    expect(c.setUnitColour('22', purple), isTrue);
    expect(detailsOf(c, '22').single.colour, purple);
    expect(c.setUnitColour('22', teal), isTrue);

    // Change size (the Symbol section's Size menu, F-17): the instance
    // takes another definition; its components stay on the instance.
    seen.clear();
    const other = CatalogSymbol(
      key: 'fx.embedding.wide',
      name: 'Test embedding table, wide',
      category: 'Tests',
      tags: ['table', 'test'],
      unit: CatalogUnit(kind: UnitKinds.table, capacity: 6),
      base: (0, 0),
      shapes: [
        CatalogPolyline([(300, -200), (1500, -200), (1300, 400), (300, 250)],
            closed: true),
      ],
    );
    final node = doc.tree[two]! as InstanceNode;
    final oldDefinition = node.definition;
    doc.commands.execute(changeSizeCommand(doc, two, entryOf(other))!);
    await tester.pump();
    expect((doc.tree[two]! as InstanceNode).definition, isNot(oldDefinition),
        reason: 'premise: another definition');
    expect(doc.components.get<UnitColour>(two), UnitColour(teal));
    final now = c.unitDetails[c.unitDetailInstances.indexOf(two)];
    expect(now.colour, teal);
    expect(now.unit.capacity, 6, reason: 'premise: the new size');
    expect(seen, hasLength(1));
    expect((seen.single as PlanUnitChanged).before.colour, teal);
    expect((seen.single as PlanUnitChanged).after.colour, teal);
    c.undo();
    await tester.pump();
    expect(c.unitDetails[c.unitDetailInstances.indexOf(two)].colour, teal);
  });
}
