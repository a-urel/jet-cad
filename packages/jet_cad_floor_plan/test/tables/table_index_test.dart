// Spec 14a T1, T2, T6, T15: which instances are tables, the number each
// carries, and the diagnostics of a plan's numbering. Tables are placed off
// the origin, turned and mirrored; their labels are added by hand here
// (placement adds them from Task 3).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/symbols/seating_component.dart';
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
      'ascending by handle whatever the tree order, with their numbers and '
      'seats', () {
    final doc = plan();
    final early = doc.handleSeed.next();
    final a = place(doc, entryOf(tableSymbol(seats: 2)), Vector2(-2100, 900),
        quarterTurns: 1, mirrored: true);
    final planter = place(doc, entryOf(planterSymbol), Vector2(400, -800));
    final b =
        place(doc, entryOf(stoolSymbol), Vector2(3300, 1700), quarterTurns: 3);
    final c = place(doc, entryOf(tableSymbol(seats: 2)), Vector2(-700, -2600));
    label(doc, b, ' B4 ');
    label(doc, a, '12');
    // Added last, with the lowest handle: the tree holds it after the rest.
    doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: early,
        parent: doc.rootHandle,
        transform: placementAt(5100, -900, kDeg37, mirrored: true),
        definition: b.definition,
        layer: ReservedHandles.layerZero)));

    final tables = tablesOf(doc);
    expect([for (final t in tables) t.instance],
        [early, a.handle, b.handle, c.handle]);
    expect([for (final t in tables) t.number], [null, '12', 'B4', null]);
    expect([for (final t in tables) t.seats], [1, 2, 1, 2]);
    expect([for (final t in tables) t.symbolKey],
        ['test.stool', 'test.table', 'test.stool', 'test.table']);
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

  test(
      'TI4 diagnostics: duplicate, unnumbered, extra label, nested, each with '
      'its severity; the lowest-handle label is the number', () {
    final doc = plan();
    final earlyLabel = doc.handleSeed.next();
    final earlyNested = doc.handleSeed.next();
    final a = place(doc, entryOf(tableSymbol()), Vector2(-2100, 900));
    final b =
        place(doc, entryOf(tableSymbol()), Vector2(2100, 900), mirrored: true);
    final c = place(doc, entryOf(stoolSymbol), Vector2(0, 3000));
    final d = place(doc, entryOf(stoolSymbol), Vector2(0, -3000));
    final planterEntry = entryOf(planterSymbol);
    final planter = place(doc, planterEntry, Vector2(4000, 4000));
    label(doc, a, '4');
    label(doc, b, '4 ');
    final firstOfD = label(doc, d, '9');
    final secondOfD = label(doc, d, '10');
    // A third label of d's, added last with the lowest handle.
    final command = addTableLabelCommand(doc,
        instance: d.handle,
        definition: d.definition,
        placement: d.transform,
        number: '11');
    doc.commands.execute(AddEntityCommand(
        record: command.record.copyWith(handle: earlyLabel),
        payload: command.payload));
    // Servable instances inside a group: not tables in v1; the one with the
    // lower handle is added second. A planter there is nothing.
    final group = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.translation(500, 500),
        children: const [])));
    InstanceNode inGroup(Handle h, Handle def) => InstanceNode(
        handle: h,
        parent: group,
        transform: placementAt(100, 200, kDeg37),
        definition: def,
        layer: ReservedHandles.layerZero);
    final lateNested = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(inGroup(lateNested, a.definition)));
    doc.commands.execute(AddNodeCommand(inGroup(earlyNested, c.definition)));
    doc.commands.execute(
        AddNodeCommand(inGroup(doc.handleSeed.next(), planter.definition)));

    final survey = TableSurvey.of(doc);
    expect([for (final t in survey.tables) t.instance],
        [a.handle, b.handle, c.handle, d.handle]);
    expect(survey.tables.last.label, earlyLabel);
    expect(survey.tables.last.number, '11');
    expect(survey.nested, [earlyNested, lateNested]);
    final diagnostics = survey.diagnostics();
    expect([
      for (final x in diagnostics) x.code
    ], [
      'table.duplicate_number',
      'table.unnumbered',
      'table.extra_label',
      'table.nested',
      'table.nested',
    ]);
    expect([
      for (final x in diagnostics) x.severity
    ], [
      DiagnosticSeverity.warning,
      DiagnosticSeverity.warning,
      DiagnosticSeverity.warning,
      DiagnosticSeverity.info,
      DiagnosticSeverity.info,
    ]);
    expect(diagnostics[0].handles, [a.handle, b.handle]);
    expect(diagnostics[1].handles, [c.handle]);
    expect(diagnostics[2].handles, [d.handle, firstOfD, secondOfD]);
    expect(diagnostics[3].handles, [earlyNested]);
    expect(diagnostics[4].handles, [lateNested]);
    expect(tableDiagnostics(doc).length, 5);
  });

  test(
      'TI4b an instance of a definition that is gone is no table, whatever '
      'its components say', () {
    final doc = plan();
    final a = place(doc, entryOf(tableSymbol()), Vector2(-2100, 900));
    label(doc, a, '1');
    final orphan = doc.handleSeed.next();
    final def = doc.handleSeed.next();
    doc.commands.execute(
        SetComponentCommand<SeatingComponent>(def, SeatingComponent(seats: 3)));
    doc.tree.addNode(InstanceNode(
        handle: orphan,
        parent: doc.rootHandle,
        transform: placementAt(900, 900, kDeg37),
        definition: def,
        layer: ReservedHandles.layerZero));
    expect([for (final t in tablesOf(doc)) t.instance], [a.handle]);
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
    doc.commands.execute(AddEntityCommand(
        record: command.record.copyWith(
            handle: doc.handleSeed.next(), kind: EntityKind.text, text: '5'),
        payload: command.payload));
    expect(tablesOf(doc).single.number, isNull);
  });

  test('TI6 an empty label is no number: the table is unnumbered', () {
    final doc = plan();
    final a = place(doc, entryOf(tableSymbol()), Vector2(-2100, 900),
        quarterTurns: 3);
    final b = place(doc, entryOf(stoolSymbol), Vector2(1900, -400));
    label(doc, a, '  ');
    label(doc, b, '');
    final survey = TableSurvey.of(doc);
    expect([for (final t in survey.tables) t.number], [null, null]);
    expect([for (final d in survey.diagnostics()) d.code],
        ['table.unnumbered', 'table.unnumbered']);
  });
}
