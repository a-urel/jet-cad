// Spec 14a T14, T16: the Selection panel's Table section — the Number
// field (one command per change, refusals revert with an error line), the
// seats, the duplicate warning, and the two rotate buttons — and the label
// following its table to a hidden layer (T8). Tables are placed off the
// origin, turned and mirrored.
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/selection_panel.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label_system.dart';
import 'package:jet_cad_floor_plan/src/tables/table_rotate.dart';
import 'package:jet_cad_floor_plan/symbols.dart' show FurnitureSymbol;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'table_fixture.dart';

Finder get section => find.byKey(const Key('table-section'));
Finder get number => find.byKey(const Key('table-number'));
Finder get seats => find.byKey(const Key('table-seats'));
Finder get error => find.byKey(const Key('table-number-error'));
Finder get duplicate => find.byKey(const Key('table-number-duplicate'));
Finder get left => find.byKey(const Key('table-rotate-left'));
Finder get right => find.byKey(const Key('table-rotate-right'));

String fieldText(WidgetTester tester) =>
    tester.widget<TextField>(number).controller!.text;

/// A plan with the parametric and table systems, as the shell has them.
DraftDocument rig() {
  final doc = plan();
  final parametric = installParametric(doc);
  final tables = TableLabelSystem(doc)..install();
  addTearDown(() {
    tables.dispose();
    parametric.dispose();
  });
  return doc;
}

Handle placeOne(DraftDocument doc, FurnitureSymbol s, Vector2 at,
    {int quarterTurns = 0, bool mirrored = false}) {
  doc.commands.execute(placeSymbol(doc, entryOf(s),
      at: at, quarterTurns: quarterTurns, mirrored: mirrored));
  return doc.tree.nodes
      .whereType<InstanceNode>()
      .reduce((a, b) => a.handle.value > b.handle.value ? a : b)
      .handle;
}

Future<SelectionController> pumpPanel(
    WidgetTester tester, DraftDocument doc) async {
  final selection = SelectionController(doc);
  addTearDown(selection.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SelectionPanel(document: doc, selection: selection),
      ),
    ),
  ));
  return selection;
}

Future<void> select(
    WidgetTester tester, SelectionController s, Handle h) async {
  s.replace([SelectionKey.root(h)]);
  await tester.pump();
}

Future<void> enterAndSubmit(WidgetTester tester, String text) async {
  await tester.pump(kDoubleTapTimeout * 2);
  await tester.tap(number);
  await tester.pump();
  await tester.enterText(number, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

List<String?> numbers(DraftDocument doc) =>
    [for (final t in tablesOf(doc)) t.number];

void main() {
  testWidgets('TS1 one table shows its number and seats; a planter does not',
      (tester) async {
    final doc = rig();
    final a = placeOne(doc, tableSymbol(seats: 4), Vector2(-2400, 1300),
        quarterTurns: 1, mirrored: true);
    final planter = placeOne(doc, planterSymbol, Vector2(900, -700));
    final s = await pumpPanel(tester, doc);
    expect(section, findsNothing);

    await select(tester, s, a);
    expect(section, findsOneWidget);
    expect(fieldText(tester), '1');
    expect(tester.widget<Text>(seats).data, '4');
    expect(duplicate, findsNothing, reason: 'a unique number');
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);

    await select(tester, s, planter);
    expect(section, findsNothing);
  });

  testWidgets(
      'TS2 a new number is one step; its own number again, or padded, is '
      'nothing (M-14a-4)', (tester) async {
    final doc = rig();
    final a =
        placeOne(doc, tableSymbol(), Vector2(-2400, 1300), mirrored: true);
    final b =
        placeOne(doc, tableSymbol(), Vector2(2400, 1300), quarterTurns: 3);
    final s = await pumpPanel(tester, doc);
    await select(tester, s, a);
    final depth = doc.commands.undoDepth;

    await enterAndSubmit(tester, ' 1 ');
    expect(doc.commands.undoDepth, depth, reason: 'unchanged: no command');
    expect(error, findsNothing);

    await enterAndSubmit(tester, 'B4');
    expect(doc.commands.undoDepth, depth + 1);
    expect(numbers(doc), ['B4', '2']);
    expect(fieldText(tester), 'B4');

    await enterAndSubmit(tester, 'b4');
    expect(numbers(doc), ['b4', '2'], reason: 'case-sensitive');
    await select(tester, s, b);
    await enterAndSubmit(tester, 'B4');
    expect(error, findsNothing, reason: '"B4" is not "b4"');
    expect(numbers(doc), ['b4', 'B4']);
    doc.commands.undo();
    await select(tester, s, a);
    doc.commands.undo();
    doc.commands.undo();
    await tester.pump();
    expect(numbers(doc), ['1', '2']);
    expect(fieldText(tester), '1');
  });

  testWidgets(
      'TS3 a number used by another table, or invalid, is refused: the '
      'field reverts and says why, until the next edit', (tester) async {
    final doc = rig();
    final a = placeOne(doc, tableSymbol(), Vector2(-2400, 1300));
    final b = placeOne(doc, tableSymbol(), Vector2(2400, 1300), mirrored: true);
    final s = await pumpPanel(tester, doc);
    await select(tester, s, a);
    final depth = doc.commands.undoDepth;

    await enterAndSubmit(tester, ' 2');
    expect(doc.commands.undoDepth, depth);
    expect(fieldText(tester), '1');
    expect(tester.widget<Text>(error).data, 'Number 2 is already used');

    await tester.enterText(number, '12');
    await tester.pump();
    expect(error, findsNothing, reason: 'the next edit ends it');

    await enterAndSubmit(tester, '123456789');
    expect(fieldText(tester), '1');
    expect(tester.widget<Text>(error).data, '1 to 8 characters');
    expect(numbers(doc), ['1', '2']);

    // A selection change ends it (review F-5).
    await select(tester, s, b);
    await select(tester, s, a);
    expect(error, findsNothing);
  });

  testWidgets(
      'TS3b unchanged is nothing: an unnumbered table\'s empty field, a '
      'duplicate from a file (review F-1)', (tester) async {
    final doc = rig();
    doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
        at: Vector2(1700, -2900), numbered: false));
    final bare = doc.tree.nodes.whereType<InstanceNode>().single.handle;
    placeOne(doc, tableSymbol(), Vector2(-2400, 1300));
    final b = placeOne(doc, tableSymbol(), Vector2(2400, 1300));
    doc.commands.execute(
        SetEntityTextCommand(tablesOf(doc).last.label!, '1', kTableLabelTag));
    final s = await pumpPanel(tester, doc);
    final depth = doc.commands.undoDepth;

    await select(tester, s, bare);
    await enterAndSubmit(tester, '');
    expect(error, findsNothing);
    expect(tablesOf(doc).first.label, isNull, reason: 'no empty label');

    await select(tester, s, b);
    await enterAndSubmit(tester, '1');
    expect(error, findsNothing);
    expect(doc.commands.undoDepth, depth);
  });

  testWidgets(
      'TS4 a deleted table\'s number is accepted (M-14a-2); the Q-2 ruling: '
      'renamed 101, the next placement is 102', (tester) async {
    final doc = rig();
    final a = placeOne(doc, tableSymbol(), Vector2(-2400, 1300));
    final b = placeOne(doc, stoolSymbol, Vector2(2400, 1300), quarterTurns: 2);
    final bLabel = tablesOf(doc).last.label!;
    doc.commands.execute(CompoundCommand(
        [RemoveEntityCommand(bLabel), RemoveNodeCommand(b)],
        label: 'Delete'));
    final s = await pumpPanel(tester, doc);
    await select(tester, s, a);

    await enterAndSubmit(tester, '2');
    expect(error, findsNothing);
    expect(numbers(doc), ['2']);

    await enterAndSubmit(tester, '101');
    placeOne(doc, stoolSymbol, Vector2(0, -2200), mirrored: true);
    expect(numbers(doc), ['101', '102']);
  });

  testWidgets('TS5 an unnumbered table gets a label from the field',
      (tester) async {
    final doc = rig();
    doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
        at: Vector2(1700, -2900), quarterTurns: 1, numbered: false));
    final a = doc.tree.nodes.whereType<InstanceNode>().single;
    final s = await pumpPanel(tester, doc);
    await select(tester, s, a.handle);
    expect(fieldText(tester), '');

    await enterAndSubmit(tester, '7');
    final t = tablesOf(doc).single;
    expect(t.number, '7');
    final payload = doc.geometry
        .read(doc.entities.geomIndexAt(doc.entities.slotOf(t.label!)!));
    final st = tableLabelStamp(a.transform);
    expect(payload.scalars, [200, st.rotation, st.widthFactor]);
  });

  testWidgets('TS6 a duplicate from a file is shown on both tables',
      (tester) async {
    final doc = rig();
    final a = placeOne(doc, tableSymbol(), Vector2(-2400, 1300));
    final b = placeOne(doc, tableSymbol(), Vector2(2400, 1300));
    doc.commands.execute(
        SetEntityTextCommand(tablesOf(doc).last.label!, '1', kTableLabelTag));
    final s = await pumpPanel(tester, doc);
    for (final h in [a, b]) {
      await select(tester, s, h);
      expect(
          tester.widget<Text>(duplicate).data, 'Number 1 is used by 2 tables');
    }
  });

  testWidgets(
      'TS7 the rotate buttons turn the table in place about its base point '
      '(not its box centre), one Rotate step each, the number upright '
      '(M-14a-15)', (tester) async {
    final doc = rig();
    final a = placeOne(doc, oneChairTable, Vector2(-2300, 1700),
        quarterTurns: 1, mirrored: true);
    final start = (doc.tree[a]! as InstanceNode).transform;
    final s = await pumpPanel(tester, doc);
    await select(tester, s, a);
    final depth = doc.commands.undoDepth;
    final labels = <String>[];
    final sub = doc.changes.listen((c) {
      if (c is CommandApplied) labels.add(c.label);
    });
    addTearDown(sub.cancel);

    await tester.tap(right);
    await tester.pump();
    final once = (doc.tree[a]! as InstanceNode).transform;
    expect(doc.commands.undoDepth, depth + 1);
    expect(once.transformPoint(Vector2(900, 700)), Vector2(-2300, 1700),
        reason: 'the base point stays at the same world point');
    expect(parts(once), isNot(parts(start)));
    // Right is clockwise: R(−90°) takes the local x axis's image (a, b) to
    // (b, −a), exactly.
    expect([once.a, once.b], [start.b, -start.a]);
    expect(parts(once).any((v) => v == 0 && v.isNegative), isFalse,
        reason: 'no −0.0 is stored');
    final st = tableLabelStamp(once);
    final payload = doc.geometry.read(doc.entities
        .geomIndexAt(doc.entities.slotOf(tablesOf(doc).single.label!)!));
    expect(payload.scalars.sublist(1), [st.rotation, st.widthFactor]);

    for (var k = 0; k < 3; k++) {
      await tester.tap(right);
      await tester.pump();
    }
    expect(parts((doc.tree[a]! as InstanceNode).transform), parts(start),
        reason: 'four quarter turns: exactly where it began');

    // Left is counter-clockwise: (a, b) to (−b, a).
    await tester.tap(left);
    await tester.pump();
    final leftOnce = (doc.tree[a]! as InstanceNode).transform;
    expect([leftOnce.a, leftOnce.b], [-start.b, start.a]);
    expect(leftOnce.transformPoint(Vector2(900, 700)), Vector2(-2300, 1700));
    await tester.pump();
    expect(labels, List.filled(5, 'Rotate'));
    doc.commands.undo();
    expect(parts((doc.tree[a]! as InstanceNode).transform), parts(start));
  });

  testWidgets(
      'TS8 under runtime permissions the field is read-only and the rotate '
      'buttons do not show (Q-4)', (tester) async {
    final doc = rig();
    final a = placeOne(doc, tableSymbol(), Vector2(-2300, 1700));
    doc.commands.permissions = DraftPermissions.runtime;
    final s = await pumpPanel(tester, doc);
    await select(tester, s, a);
    expect(tester.widget<TextField>(number).readOnly, isTrue);
    expect(left, findsNothing);
    expect(right, findsNothing);
  });

  test(
      'TS9 a 37°-turned table: the base point stays, the linear part turns '
      'exactly, four turns return within rounding', () {
    final doc = rig();
    final a = placeOne(doc, tableSymbol(), Vector2(-2300.5, 1700.25));
    final node0 = doc.tree[a]! as InstanceNode;
    doc.commands.execute(TransformNodeCommand(
        a, placementAt(-2300.5, 1700.25, kDeg37, mirrored: true)));
    final start = (doc.tree[a]! as InstanceNode).transform;
    expect(parts(start), isNot(parts(node0.transform)));
    for (var k = 0; k < 4; k++) {
      doc.commands.execute(rotateTableCommand(doc, a, 1)!);
      final t = (doc.tree[a]! as InstanceNode).transform;
      final w = t.transformPoint(Vector2(900, 700));
      expect(w.x, closeTo(-2300.5, 1e-9));
      expect(w.y, closeTo(1700.25, 1e-9));
    }
    final end = (doc.tree[a]! as InstanceNode).transform;
    expect([end.a, end.b, end.c, end.d], [start.a, start.b, start.c, start.d]);
    expect(end.e, closeTo(start.e, 1e-9));
    expect(end.f, closeTo(start.f, 1e-9));
  });

  test(
      'TS10 a table moved to a hidden layer hides its number; back, it shows '
      '(M-14a-12)', () {
    final doc = rig();
    final layerA = doc.handleSeed.next();
    final layerB = doc.handleSeed.next();
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    for (final (h, name, visible) in [
      (layerA, 'A', true),
      (layerB, 'B', false),
    ]) {
      doc.commands.execute(AddLayerCommand(LayerRecord(
          handle: h,
          name: name,
          color: const IndexedColor(3),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency,
          visible: visible,
          locked: false)));
    }
    doc.commands.execute(SetCurrentLayerCommand(layerA));
    final a =
        placeOne(doc, tableSymbol(), Vector2(-2300, 1700), mirrored: true);
    final slot = doc.entities.slotOf(tablesOf(doc).single.label!)!;
    bool drawn() =>
        FilterEvaluator(doc).acceptsEntity(slot, const QueryFilter.rendering());
    expect(drawn(), isTrue);
    doc.commands.execute(SetInstanceLayerCommand(a, layerB));
    expect(drawn(), isFalse);
    doc.commands.execute(SetInstanceLayerCommand(a, layerA));
    expect(drawn(), isTrue);
  });
}
