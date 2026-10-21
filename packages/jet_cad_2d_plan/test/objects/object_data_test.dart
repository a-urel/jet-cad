// Spec D8 (POS-host Task 3): host data on any placed object, named by a
// PlanObjectRef. Fixture: two units (one turned 30 degrees, one on a locked
// layer), a mirrored and turned planter (a symbol that is no unit) and a
// turned rail (a kit type's object, titled "Rail"), all far off the origin.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart' show planText;
import '../support/object_kit.dart';
import '../support/unit_embedding_fixture.dart';
import '../support/unit_fixtures.dart';

late Handle unitOne, unitLocked, planter, rail, plain;

String plan() => planText([fxKit(), objectKit], (d) {
      final locked = addLayer(d, 'Locked', locked: true);
      unitOne = placeUnit(d, embeddingTable,
          transform: embeddingPlacement(40000, -27000, 30));
      addUnitLabel(d, unitOne, '1');
      unitLocked = placeUnit(d, embeddingTable,
          transform: embeddingPlacement(43000, -31000, 120, sy: -1),
          layer: locked);
      addUnitLabel(d, unitLocked, 'L');
      planter = placeTurned(d, planterSymbol, Vector2(52000, -20000)).handle;
      rail =
          addTurned(d, const RailComponent(3000), Vector2(47000, -40000), 0.7);
      plain = d.handleSeed.next();
      d.commands.execute(AddNodeCommand(GroupNode(
          handle: plain,
          parent: d.rootHandle,
          transform: Transform2.translation(41000, -45000),
          children: const [])));
      d.commands.clearHistory();
    });

PlanController controller([String? json]) {
  final c = PlanController(kits: [fxKit(), objectKit], json: json ?? plan());
  addTearDown(c.dispose);
  return c;
}

PlanObjectRef ref(Handle h) => PlanObjectRef.of(h);

void main() {
  testWidgets(
      'OD1 a planter symbol takes data: set, read back, undo removes, redo '
      'restores', (tester) async {
    final c = controller();
    final r = ref(planter);
    final detail = c.objectDetailOf(r)!;
    expect(detail.kind, PlanObjectKind.symbol);
    expect(detail.symbolKey, 'fx.planter.round');
    expect(detail.typeId, isNull);
    expect(detail.label, isNull);
    expect(detail.data, isEmpty);
    expect(c.objectDetails, isEmpty);

    final labels = <String>[];
    final sub = c.document.changes.listen((e) {
      if (e is CommandApplied) labels.add(e.label);
    });
    addTearDown(sub.cancel);
    expect(c.setObjectData(r, {'zeta': 'z', 'id': 'bar-1'}), isTrue);
    await tester.pump();
    expect(labels, ['Object data']);
    expect(c.objectDetailOf(r)!.data, {'id': 'bar-1', 'zeta': 'z'});
    expect(c.objectDetailOf(r)!.data.keys, ['id', 'zeta']);
    expect(c.objectDetails.map((d) => d.ref), [r]);
    c.undo();
    expect(c.objectDetailOf(r)!.data, isEmpty);
    expect(c.objectDetails, isEmpty);
    c.redo();
    expect(c.objectDetailOf(r)!.data, {'id': 'bar-1', 'zeta': 'z'});
    expect(c.setObjectData(r, const {}), isTrue);
    expect(c.objectDetailOf(r)!.data, isEmpty);
  });

  testWidgets('OD2 a kit type object takes data; it survives save and load',
      (tester) async {
    final c = controller();
    final r = ref(rail);
    final detail = c.objectDetailOf(r)!;
    expect(detail.kind, PlanObjectKind.type);
    expect(detail.typeId, 'view.rail');
    expect(detail.label, 'Rail');
    expect(detail.symbolKey, isNull);
    expect(
        c.setObjectsData({
          r: {'name': 'Hall'},
          ref(planter): {'a': '1'}
        }),
        isTrue);
    final saved = c.save();
    final back = controller(saved);
    expect(back.objectDetails, c.objectDetails);
    expect(back.objectDetails.map((d) => d.ref), [ref(planter), r],
        reason: 'ascending handle');
    expect(back.objectDetailOf(r)!.data, {'name': 'Hall'});
    final other = controller();
    other.load(saved);
    expect(other.objectDetailOf(r), c.objectDetailOf(r));
    expect(other.save(), saved);
  });

  testWidgets('OD3 a unit\'s data is the same data through either API',
      (tester) async {
    final c = controller();
    final r = ref(unitOne);
    final unit = c.objectDetailOf(r)!;
    expect(unit.kind, PlanObjectKind.unit);
    expect(unit.label, '1');
    expect(unit.symbolKey, embeddingTable.key);
    expect(c.setObjectData(r, {'id': 'by-object'}), isTrue);
    expect(c.unitDetails.singleWhere((d) => d.unit.label == '1').data,
        {'id': 'by-object'});
    expect(c.setUnitData('1', {'id': 'by-label'}), isTrue);
    expect(c.objectDetailOf(r)!.data, {'id': 'by-label'});
    expect(c.objectDetails.map((d) => d.ref), [r]);
  });

  testWidgets('OD4 a plan saved by 0.8.1 opens with its unit data',
      (tester) async {
    final text =
        File('test/fixtures/plan_0_8_1_unit_data.json').readAsStringSync();
    final c = PlanController(kits: [fxKit()], json: text);
    addTearDown(c.dispose);
    expect([for (final d in c.unitDetails) '${d.unit.label} ${d.data}'],
        ['1 {id: a-1, name: Masa}', '2 {zone: terrace}']);
    expect([
      for (final o in c.objectDetails) '${o.label} ${o.kind} ${o.data}'
    ], [
      '1 PlanObjectKind.unit {id: a-1, name: Masa}',
      '2 PlanObjectKind.unit {zone: terrace}',
    ]);
    expect(c.save(), text, reason: 'written back as read');
  });

  testWidgets('OD5 limits and locks', (tester) async {
    final c = controller();
    final r = ref(planter);
    expect(() => c.setObjectData(r, {for (var i = 0; i < 33; i++) 'k$i': 'v'}),
        throwsArgumentError);
    expect(() => c.setObjectData(r, {'Bad Key': 'v'}), throwsArgumentError);
    expect(c.canUndo.value, isFalse);

    // An object under a lock (a frozen one) refuses; nothing is stepped.
    c.lockBroken({planter});
    final before = c.save();
    expect(c.setObjectData(r, {'a': 'b'}), isFalse);
    expect(
        c.setObjectsData({
          ref(rail): {'a': 'b'},
          r: {'a': 'b'}
        }),
        isFalse,
        reason: 'all or nothing');
    expect(c.save(), before);
    expect(c.canUndo.value, isFalse);
    expect(c.lockHint.value, isFalse,
        reason: 'refused up front, not by the engine (no lock hint)');

    // An object on a locked layer takes data.
    expect(c.setObjectData(ref(unitLocked), {'id': 'locked-layer'}), isTrue);
    expect(c.objectDetailOf(ref(unitLocked))!.data, {'id': 'locked-layer'});
    expect(c.canUndo.value, isTrue);
  });

  testWidgets('OD6 in service mode setObjectData throws', (tester) async {
    final c = controller();
    c.setMode(PlanMode.service);
    await tester.pump();
    expect(() => c.setObjectData(ref(planter), {'a': 'b'}), throwsStateError);
    expect(() => c.setObjectsData({ref(planter): {}}), throwsStateError);
  });

  testWidgets('OD7 a ref from before newPlan names nothing', (tester) async {
    final c = controller();
    final r = ref(rail);
    expect(c.objectDetailOf(r), isNotNull);
    c.newPlan();
    expect(c.objectDetailOf(r), isNull);
    expect(c.setObjectData(r, {'a': 'b'}), isFalse);
    expect(c.objectDetails, isEmpty);
    expect(c.objectDetailOf(ref(Handle(999999))), isNull);
  });

  testWidgets('OD8 a plain group and a non-object are no object',
      (tester) async {
    final c = controller();
    // The root and a plain group (the grouping feature's) are no object.
    expect(c.objectDetailOf(ref(plain)), isNull);
    expect(c.setObjectData(ref(plain), {'a': 'b'}), isFalse);
    expect(c.objectDetailOf(ref(c.document.rootHandle)), isNull);
    expect(c.setObjectData(ref(c.document.rootHandle), {'a': 'b'}), isFalse);
    expect(c.canUndo.value, isFalse);
  });
}
