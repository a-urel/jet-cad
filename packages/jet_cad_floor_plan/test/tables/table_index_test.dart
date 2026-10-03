// Spec 14a T1, T2, T6, T15: which instances are tables, the number each
// carries, and the diagnostics of a plan's numbering. Tables are placed off
// the origin, turned and mirrored; their labels are added by hand here
// (placement adds them from Task 3).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'table_fixture.dart';

/// Places [entry] and returns its instance.
InstanceNode place(DraftDocument doc, SymbolEntry entry, Vector2 at,
    {int quarterTurns = 0, bool mirrored = false}) {
  doc.commands.execute(placeSymbol(doc, entry,
      at: at, quarterTurns: quarterTurns, mirrored: mirrored, numbered: false));
  return doc.tree.nodes
      .whereType<InstanceNode>()
      .reduce((a, b) => a.handle.value > b.handle.value ? a : b);
}

Handle label(DraftDocument doc, InstanceNode i, String number) {
  final command = addTableLabelCommand(doc,
      instance: i.handle,
      definition: i.definition,
      placement: i.transform,
      number: number);
  doc.commands.execute(command);
  return command.record.handle;
}

void main() {
  test(
      'TI1 the tables are the live, root-level, servable instances, '
      'ascending, with their numbers and seats', () {
    final doc = plan();
    final a = place(doc, entryOf(tableSymbol(seats: 2)), Vector2(-2100, 900),
        quarterTurns: 1, mirrored: true);
    final planter = place(doc, entryOf(planterSymbol), Vector2(400, -800));
    final b =
        place(doc, entryOf(stoolSymbol), Vector2(3300, 1700), quarterTurns: 3);
    final c = place(doc, entryOf(tableSymbol(seats: 2)), Vector2(-700, -2600));
    label(doc, b, ' B4 ');
    label(doc, a, '12');

    final tables = tablesOf(doc);
    expect(
        [for (final t in tables) t.instance], [a.handle, b.handle, c.handle]);
    expect([for (final t in tables) t.number], ['12', 'B4', null]);
    expect([for (final t in tables) t.seats], [2, 1, 2]);
    expect([for (final t in tables) t.symbolKey],
        ['test.table', 'test.stool', 'test.table']);
    expect(tables.any((t) => t.instance == planter.handle), isFalse);
  });

  test('TI2 a removed instance is no table and its number is free', () {
    final doc = plan();
    final a = place(doc, entryOf(tableSymbol()), Vector2(-2100, 900));
    final b = place(doc, entryOf(tableSymbol()), Vector2(2100, 900));
    label(doc, a, '1');
    final lb = label(doc, b, '2');
    doc.commands.execute(CompoundCommand(
        [RemoveEntityCommand(lb), RemoveNodeCommand(b.handle)],
        label: 'Delete'));
    final survey = TableSurvey.of(doc);
    expect([for (final t in survey.tables) t.instance], [a.handle]);
    expect(survey.numbers, ['1']);
    expect(survey.withNumber('2'), isEmpty);
  });

  test('TI3 numbers compare trimmed and case-sensitively (M-14a-4)', () {
    final doc = plan();
    final a = place(doc, entryOf(tableSymbol()), Vector2(-2100, 900));
    final b = place(doc, entryOf(tableSymbol()), Vector2(2100, 900));
    label(doc, a, 'B4');
    label(doc, b, 'b4');
    final survey = TableSurvey.of(doc);
    expect([for (final t in survey.withNumber(' B4 ')) t.instance], [a.handle]);
    expect([for (final t in survey.withNumber('b4')) t.instance], [b.handle]);
    expect(survey.diagnostics(), isEmpty);
  });

  test('TI4 diagnostics: duplicate, unnumbered, extra label, nested', () {
    final doc = plan();
    final a = place(doc, entryOf(tableSymbol()), Vector2(-2100, 900));
    final b =
        place(doc, entryOf(tableSymbol()), Vector2(2100, 900), mirrored: true);
    final c = place(doc, entryOf(stoolSymbol), Vector2(0, 3000));
    final d = place(doc, entryOf(stoolSymbol), Vector2(0, -3000));
    label(doc, a, '4');
    label(doc, b, '4 ');
    final firstOfD = label(doc, d, '9');
    final secondOfD = label(doc, d, '10');
    // A servable instance inside a group: not a table in v1.
    final group = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.translation(500, 500),
        children: const [])));
    final nested = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: nested,
        parent: group,
        transform: placementAt(100, 200, kDeg37),
        definition: a.definition,
        layer: ReservedHandles.layerZero)));

    final survey = TableSurvey.of(doc);
    expect([for (final t in survey.tables) t.instance],
        [a.handle, b.handle, c.handle, d.handle]);
    expect(survey.tables.last.label, firstOfD);
    expect(survey.tables.last.number, '9');
    final diagnostics = survey.diagnostics();
    expect([
      for (final x in diagnostics) x.code
    ], [
      'table.duplicate_number',
      'table.unnumbered',
      'table.extra_label',
      'table.nested',
    ]);
    expect(diagnostics[0].handles, [a.handle, b.handle]);
    expect(diagnostics[0].severity, DiagnosticSeverity.warning);
    expect(diagnostics[1].handles, [c.handle]);
    expect(diagnostics[2].handles, [d.handle, secondOfD]);
    expect(diagnostics[3].handles, [nested]);
    expect(diagnostics[3].severity, DiagnosticSeverity.info);
    expect(tableDiagnostics(doc).length, 4);
  });

  test(
      'TI5 a label that is not tagged TABLE, or not an ATTRIB, is no '
      'number', () {
    final doc = plan();
    final a = place(doc, entryOf(tableSymbol()), Vector2(-2100, 900));
    final command = addTableLabelCommand(doc,
        instance: a.handle,
        definition: a.definition,
        placement: a.transform,
        number: '3');
    doc.commands.execute(AddEntityCommand(
        record: command.record.copyWith(tag: 'REF'), payload: command.payload));
    expect(tablesOf(doc).single.number, isNull);
  });
}
