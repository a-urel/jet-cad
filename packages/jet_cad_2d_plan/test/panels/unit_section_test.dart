// 2b Task 10, spec S4 "The unit inspector" (the unit section): one selected
// placed unit shows its kind, its label field (Number for a numbered unit,
// Label for an assigned one; gated by relabel), its capacity and the ±90
// buttons (gated by rotate). Ported from jet_cad_floor_plan's
// tables/table_section_test.dart (TS1-TS8, assertions unchanged) and new
// cases (UW-*). Units are placed off the origin, turned and mirrored.
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogPolyline, CatalogSymbol, CatalogUnit;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show placeSymbol;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/unit_fixtures.dart';

Finder get section => find.byKey(const Key('unit-section'));
Finder get label => find.byKey(const Key('unit-label'));
Finder get capacity => find.byKey(const Key('unit-capacity'));
Finder get error => find.byKey(const Key('unit-label-error'));
Finder get duplicate => find.byKey(const Key('unit-label-duplicate'));
Finder get left => find.byKey(const Key('unit-rotate-left'));
Finder get right => find.byKey(const Key('unit-rotate-right'));

String fieldText(WidgetTester tester) =>
    tester.widget<TextField>(label).controller!.text;

/// The label field's title.
String fieldTitle(WidgetTester tester) =>
    tester.widget<TextField>(label).decoration!.labelText!;

Future<void> pumpPanel(WidgetTester tester, PlanController c) => pumpApp(
    tester, SingleChildScrollView(child: PlanPropertyPanel(controller: c)));

Future<void> select(WidgetTester tester, PlanController c, Handle h) async {
  c.selection.replace([SelectionKey.root(h)]);
  await tester.pump();
}

Future<void> enterAndSubmit(WidgetTester tester, String text) async {
  await tester.pump(kDoubleTapTimeout * 2);
  await tester.tap(label);
  await tester.pump();
  await tester.enterText(label, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

/// A seat (an assigned unit): [tableSymbol]'s shapes and base point.
const CatalogSymbol seatSymbol = CatalogSymbol(
  key: 'fx.seat.single',
  name: 'Test seat',
  category: 'Tests',
  tags: ['seat', 'test'],
  unit: CatalogUnit(
      kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned),
  base: (900, 700),
  shapes: [
    CatalogPolyline([(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
        closed: true),
  ],
);

/// A seat placed by hand (no label) and a table labelled 1, both off the
/// origin, turned or mirrored.
({String json, String seatKey}) seatAndTable() {
  final json = planText([fxKit()], (d) {
    placeAt(d, seatSymbol, Vector2(-2400.5, 1300.25), quarterTurns: 1);
    addUnitLabel(
        d,
        placeAt(d, tableSymbol(seats: 4), Vector2(2400.75, 1300.5),
            mirrored: true),
        '1');
  });
  return (json: json, seatKey: seatSymbol.key);
}

/// A controller over an empty plan of the fixture kit (it installs the
/// parametric system, the label system and the lock).
PlanController rig() =>
    controllerFor(kits: [fxKit()], json: planText([fxKit()], (d) {}));

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

List<String?> numbers(PlanController c) =>
    [for (final u in c.unitIndex.units) u.text];

void main() {
  testWidgets(
      'UW-section-assigned an assigned unit: the kind\'s word as the title, '
      'the field titled Label, empty; typing gives it a label', (tester) async {
    final f = seatAndTable();
    final c = controllerFor(kits: [fxKit()], json: f.json);
    await pumpPanel(tester, c);
    final seat = c.unitIndex.units.singleWhere((u) => u.text == null);
    await select(tester, c, seat.instance);
    expect(tester.widget<Text>(section).data, 'Seat');
    // M-UW5: the field always titled by `number`.
    expect(fieldTitle(tester), 'Label');
    expect(fieldText(tester), '');
    await enterAndSubmit(tester, 'S1');
    expect(c.unitIndex.withLabel('S1').single.instance, seat.instance);
    final table = c.unitIndex.withLabel('1').single;
    await select(tester, c, table.instance);
    expect(fieldTitle(tester), 'Number');
    expect(tester.widget<Text>(capacity).data, '4');
  });

  testWidgets(
      'UW-relabel-gate relabel off: the field is read-only and a typed '
      'label commits nothing; the buttons still show', (tester) async {
    final f = seatAndTable();
    final c = controllerFor(kits: [fxKit()], json: f.json);
    c.permissions = PlanPermissions.full.copyWith(relabel: false);
    await pumpPanel(tester, c);
    final table = c.unitIndex.withLabel('1').single;
    await select(tester, c, table.instance);
    // M-UW6: `_editable` of the unit target ignoring `relabel`.
    expect(tester.widget<TextField>(label).readOnly, isTrue);
    final depth = c.document.commands.undoDepth;
    await enterAndSubmit(tester, '5');
    expect(c.document.commands.undoDepth, depth);
    expect(c.unitIndex.withLabel('1'), hasLength(1));
    expect(left, findsOneWidget);
  });

  testWidgets(
      'UW-locked-none a placed unit under the lock (its kit missing) shows '
      'no unit section', (tester) async {
    final f = seatAndTable();
    final c = controllerFor(kits: const [], json: f.json);
    await pumpPanel(tester, c);
    final table = c.unitIndex.withLabel('1').single;
    expect(c.isLocked(table.instance), isTrue, reason: 'premise');
    await select(tester, c, table.instance);
    // M-UW7: the unit target ignoring `isLocked`.
    expect(section, findsNothing);
  });

  testWidgets('TS1 one table shows its number and seats; a planter does not',
      (tester) async {
    final c = rig();
    final a = placeAt(c.document, tableSymbol(seats: 4), Vector2(-2400, 1300),
        quarterTurns: 1, mirrored: true);
    addUnitLabel(c.document, a, '1');
    final planter = placeAt(c.document, planterSymbol, Vector2(900, -700));
    await pumpPanel(tester, c);
    expect(section, findsNothing);

    await select(tester, c, a);
    expect(section, findsOneWidget);
    expect(fieldText(tester), '1');
    expect(tester.widget<Text>(capacity).data, '4');
    expect(duplicate, findsNothing, reason: 'a unique number');
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);

    await select(tester, c, planter);
    expect(section, findsNothing);
  });

  testWidgets(
      'TS2 a new number is one step; its own number again, or padded, is '
      'nothing (M-14a-4)', (tester) async {
    final c = rig();
    final a = placeAt(c.document, tableSymbol(), Vector2(-2400, 1300),
        mirrored: true);
    addUnitLabel(c.document, a, '1');
    final b = placeAt(c.document, tableSymbol(), Vector2(2400, 1300),
        quarterTurns: 3);
    addUnitLabel(c.document, b, '2');
    await pumpPanel(tester, c);
    await select(tester, c, a);
    final depth = c.document.commands.undoDepth;

    await enterAndSubmit(tester, ' 1 ');
    expect(c.document.commands.undoDepth, depth,
        reason: 'unchanged: no command');
    expect(error, findsNothing);

    await enterAndSubmit(tester, 'B4');
    expect(c.document.commands.undoDepth, depth + 1);
    expect(numbers(c), ['B4', '2']);
    expect(fieldText(tester), 'B4');

    await enterAndSubmit(tester, 'b4');
    expect(numbers(c), ['b4', '2'], reason: 'case-sensitive');
    await select(tester, c, b);
    await enterAndSubmit(tester, 'B4');
    expect(error, findsNothing, reason: '"B4" is not "b4"');
    expect(numbers(c), ['b4', 'B4']);
    c.document.commands.undo();
    await select(tester, c, a);
    c.document.commands.undo();
    c.document.commands.undo();
    await tester.pump();
    expect(numbers(c), ['1', '2']);
    expect(fieldText(tester), '1');
  });

  testWidgets(
      'TS3 a number used by another table, or invalid, is refused: the '
      'field reverts and says why, until the next edit', (tester) async {
    final c = rig();
    final a = placeAt(c.document, tableSymbol(), Vector2(-2400, 1300));
    addUnitLabel(c.document, a, '1');
    final b =
        placeAt(c.document, tableSymbol(), Vector2(2400, 1300), mirrored: true);
    addUnitLabel(c.document, b, '2');
    await pumpPanel(tester, c);
    await select(tester, c, a);
    final depth = c.document.commands.undoDepth;

    await enterAndSubmit(tester, ' 2');
    expect(c.document.commands.undoDepth, depth);
    expect(fieldText(tester), '1');
    expect(tester.widget<Text>(error).data, 'Number 2 is already used');

    await tester.enterText(label, '12');
    await tester.pump();
    expect(error, findsNothing, reason: 'the next edit ends it');

    await enterAndSubmit(tester, '123456789');
    expect(fieldText(tester), '1');
    expect(tester.widget<Text>(error).data, '1 to 8 characters');
    expect(numbers(c), ['1', '2']);

    // A selection change ends it (review F-5).
    await select(tester, c, b);
    await select(tester, c, a);
    expect(error, findsNothing);
  });

  testWidgets(
      'TS3b unchanged is nothing: an unnumbered table\'s empty field, a '
      'duplicate from a file (review F-1)', (tester) async {
    final c = rig();
    final bare = placeAt(c.document, tableSymbol(), Vector2(1700, -2900));
    final a = placeAt(c.document, tableSymbol(), Vector2(-2400, 1300));
    addUnitLabel(c.document, a, '1');
    final b = placeAt(c.document, tableSymbol(), Vector2(2400, 1300));
    addUnitLabel(c.document, b, '2');
    c.document.commands.execute(SetEntityTextCommand(
        c.unitIndex.units.last.label!, '1', kUnitLabelTag));
    await pumpPanel(tester, c);
    final depth = c.document.commands.undoDepth;

    await select(tester, c, bare);
    await enterAndSubmit(tester, '');
    expect(error, findsNothing);
    expect(c.unitIndex.units.first.label, isNull, reason: 'no empty label');

    await select(tester, c, b);
    await enterAndSubmit(tester, '1');
    expect(error, findsNothing);
    expect(c.document.commands.undoDepth, depth);
  });

  testWidgets(
      'TS4 a deleted table\'s number is accepted (M-14a-2); the Q-2 ruling: '
      'renamed 101, the next placement is 102', (tester) async {
    final c = rig();
    final a = placeAt(c.document, tableSymbol(), Vector2(-2400, 1300));
    addUnitLabel(c.document, a, '1');
    final b =
        placeAt(c.document, stoolSymbol, Vector2(2400, 1300), quarterTurns: 2);
    final bLabel = addUnitLabel(c.document, b, '2');
    c.document.commands.execute(CompoundCommand(
        [RemoveEntityCommand(bLabel), RemoveNodeCommand(b)],
        label: 'Delete'));
    await pumpPanel(tester, c);
    await select(tester, c, a);

    await enterAndSubmit(tester, '2');
    expect(error, findsNothing);
    expect(numbers(c), ['2']);

    await enterAndSubmit(tester, '101');
    c.execute(placeSymbol(c.document, entryOf(stoolSymbol),
        at: Vector2(0, -2200), mirrored: true, units: c.unitIndex));
    expect(numbers(c), ['101', '102']);
  });

  testWidgets('TS5 an unnumbered table gets a label from the field',
      (tester) async {
    final c = rig();
    final a = placeAt(c.document, tableSymbol(), Vector2(1700, -2900),
        quarterTurns: 1);
    final node = c.document.tree[a]! as InstanceNode;
    await pumpPanel(tester, c);
    await select(tester, c, a);
    expect(fieldText(tester), '');

    await enterAndSubmit(tester, '7');
    final t = c.unitIndex.units.single;
    expect(t.text, '7');
    final doc = c.document;
    final payload = doc.geometry
        .read(doc.entities.geomIndexAt(doc.entities.slotOf(t.label!)!));
    final st = unitLabelStamp(node.transform);
    expect(payload.scalars, [200, st.rotation, st.widthFactor]);
  });

  testWidgets('TS6 a duplicate from a file is shown on both tables',
      (tester) async {
    final c = rig();
    final a = placeAt(c.document, tableSymbol(), Vector2(-2400, 1300));
    addUnitLabel(c.document, a, '1');
    final b = placeAt(c.document, tableSymbol(), Vector2(2400, 1300));
    addUnitLabel(c.document, b, '2');
    c.document.commands.execute(SetEntityTextCommand(
        c.unitIndex.units.last.label!, '1', kUnitLabelTag));
    await pumpPanel(tester, c);
    for (final h in [a, b]) {
      await select(tester, c, h);
      expect(
          tester.widget<Text>(duplicate).data, 'Number 1 is used by 2 tables');
    }
  });

  testWidgets(
      'TS7 the rotate buttons turn the table in place about its base point '
      '(not its box centre), one Rotate step each, the number upright '
      '(M-14a-15)', (tester) async {
    final c = rig();
    final doc = c.document;
    final a = placeAt(doc, oneChairTable, Vector2(-2300, 1700),
        quarterTurns: 1, mirrored: true);
    addUnitLabel(doc, a, '1');
    final start = (doc.tree[a]! as InstanceNode).transform;
    await pumpPanel(tester, c);
    await select(tester, c, a);
    final depth = doc.commands.undoDepth;
    final labels = <String>[];
    final sub = doc.changes.listen((ch) {
      if (ch is CommandApplied) labels.add(ch.label);
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
    final st = unitLabelStamp(once);
    final payload = doc.geometry.read(doc.entities
        .geomIndexAt(doc.entities.slotOf(c.unitIndex.units.single.label!)!));
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
    final c = rig();
    final a = placeAt(c.document, tableSymbol(), Vector2(-2300, 1700));
    addUnitLabel(c.document, a, '1');
    c.document.commands.permissions = DraftPermissions.runtime;
    await pumpPanel(tester, c);
    await select(tester, c, a);
    expect(tester.widget<TextField>(label).readOnly, isTrue);
    expect(left, findsNothing);
    expect(right, findsNothing);
  });

  testWidgets(
      'UW-order the Symbol section stands above the unit section (R5-2, '
      'today\'s order)', (tester) async {
    final c = controllerFor(kits: [fxKit()], json: seatAndTable().json);
    await pumpPanel(tester, c);
    await select(tester, c, c.unitIndex.withLabel('1').single.instance);
    expect(find.byKey(const Key('symbol-section')), findsOneWidget);
    expect(section, findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('symbol-section'))).dy,
        lessThan(tester.getTopLeft(section).dy));
  });

  testWidgets(
      'UW-runtime-unit under runtime permissions a placed unit\'s Symbol '
      'rotation is read-only and its Mirror disabled, where a symbol with no '
      'unit still turns and mirrors (V-1, 14a Q-4)', (tester) async {
    final c = rig();
    final unit = placeAt(c.document, tableSymbol(), Vector2(-2300, 1700));
    addUnitLabel(c.document, unit, '1');
    final planter = placeAt(c.document, planterSymbol, Vector2(900, -700));
    c.document.commands.permissions = DraftPermissions.runtime;
    await pumpPanel(tester, c);
    bool rotationEditable() => !tester
        .widget<TextField>(find.byKey(const Key('symbol-rotation')))
        .readOnly;
    bool mirrorEnabled() =>
        tester
            .widget<OutlinedButton>(find.byKey(const Key('symbol-mirror')))
            .onPressed !=
        null;
    await select(tester, c, planter);
    expect(rotationEditable(), isTrue, reason: 'premise: a planter turns');
    expect(mirrorEnabled(), isTrue);
    await select(tester, c, unit);
    // M-UW13: `_turnableAt` ignoring a placed unit's `geometry` need.
    expect(rotationEditable(), isFalse);
    expect(mirrorEnabled(), isFalse);
  });
}
