// Spec D9 (POS-host Task 5): the host's inspector for any one selected
// object. Fixture: object_data_test's plan (a unit turned 30 degrees, a unit
// on a locked layer, a mirrored and turned planter symbol, a turned rail
// titled "Rail", an empty group), all far off the origin.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart' show planText;
import '../support/object_kit.dart';
import '../support/unit_embedding_fixture.dart';
import '../support/unit_fixtures.dart';

late Handle unitOne, unitTwo, unitLocked, planter, rail;

String plan() => planText([fxKit(), objectKit], (d) {
      final locked = addLayer(d, 'Locked', locked: true);
      unitOne = placeUnit(d, embeddingTable,
          transform: embeddingPlacement(40000, -27000, 30));
      addUnitLabel(d, unitOne, '1');
      unitTwo = placeUnit(d, embeddingTable,
          transform: embeddingPlacement(44000, -27000, 75, sy: -1));
      addUnitLabel(d, unitTwo, '2');
      unitLocked = placeUnit(d, embeddingTable,
          transform: embeddingPlacement(43000, -31000, 120, sy: -1),
          layer: locked);
      addUnitLabel(d, unitLocked, 'L');
      planter = placeTurned(d, planterSymbol, Vector2(52000, -20000)).handle;
      rail =
          addTurned(d, const RailComponent(3000), Vector2(47000, -40000), 0.7);
      d.commands.clearHistory();
    });

SelectionKey key(Handle h) => SelectionKey.root(h);
PlanObjectRef ref(Handle h) => PlanObjectRef.of(h);

class Rig {
  Rig(this.c);
  final PlanController c;
  final List<PlanObjectDetail> calls = [];

  /// Details the builder got for a ref the controller no longer answers.
  final List<PlanObjectDetail> stale = [];
}

Future<Rig> mount(WidgetTester tester,
    {bool objects = true,
    bool units = false,
    bool panel = true,
    List<PlanKit>? kits}) async {
  final c = PlanController(kits: kits ?? [fxKit(), objectKit], json: plan());
  addTearDown(c.dispose);
  final rig = Rig(c);
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: PlanEditor(
    controller: c,
    propertyPanel: panel,
    objectInspectorBuilder: !objects
        ? null
        : (context, d) {
            rig.calls.add(d);
            if (c.objectDetailOf(d.ref) == null) rig.stale.add(d);
            return Column(key: const Key('host-object'), children: [
              Text('${d.kind.name} ${d.typeId} ${d.symbolKey} ${d.label} '
                  '${d.data}'),
              TextButton(
                  key: const Key('host-object-set'),
                  onPressed: () => c.setObjectData(d.ref, {'id': 'linked'}),
                  child: const Text('link')),
            ]);
          },
    unitInspectorBuilder: !units
        ? null
        : (context, d) =>
            Text('unit ${d.unit.label}', key: const Key('host-unit')),
  ))));
  await tester.pump();
  await tester.pump();
  return rig;
}

Future<void> select(WidgetTester tester, Rig r, List<Handle> hs) async {
  r.c.selection.replace([for (final h in hs) key(h)]);
  await tester.pump();
}

Finder get host => find.byKey(const Key('host-object'));

void main() {
  testWidgets(
      'OI1 a selected bar counter shows the host widget with kind '
      'symbol and its key', (tester) async {
    final r = await mount(tester);
    expect(host, findsNothing);
    await select(tester, r, [planter]);
    expect(host, findsOneWidget);
    expect(find.byKey(const Key('object-inspector')), findsOneWidget);
    final d = r.calls.last;
    expect(d.kind, PlanObjectKind.symbol);
    expect(d.symbolKey, 'fx.planter.round');
    expect(d.ref, ref(planter));
    expect(find.textContaining('symbol null fx.planter.round null {}'),
        findsOneWidget);
    // Under the property panel, before the layer panel.
    final panelY = tester.getTopLeft(find.byType(PlanPropertyPanel)).dy;
    final layerY = tester.getTopLeft(find.byType(PlanLayerPanel)).dy;
    final hostY = tester.getTopLeft(host).dy;
    expect(hostY, greaterThan(panelY));
    expect(hostY, lessThan(layerY));
  });

  testWidgets(
      'OI2 a selected room shows it with kind type, the type id and '
      'its name', (tester) async {
    final r = await mount(tester);
    await select(tester, r, [rail]);
    final d = r.calls.last;
    expect(d.kind, PlanObjectKind.type);
    expect(d.typeId, 'view.rail');
    expect(d.label, 'Rail');
    expect(find.textContaining('type view.rail null Rail {}'), findsOneWidget);
  });

  testWidgets(
      'OI3 with both builders a table goes to unitInspectorBuilder '
      'and a rail to objectInspectorBuilder; with only the new one, the '
      'table goes to it', (tester) async {
    final both = await mount(tester, units: true);
    await select(tester, both, [unitOne]);
    expect(find.byKey(const Key('host-unit')), findsOneWidget);
    expect(host, findsNothing);
    expect(both.calls, isEmpty);
    await select(tester, both, [rail]);
    expect(find.byKey(const Key('host-unit')), findsNothing);
    expect(host, findsOneWidget);
    await select(tester, both, [planter]);
    expect(host, findsOneWidget);
    expect(both.calls.map((d) => d.kind),
        everyElement(isNot(PlanObjectKind.unit)));

    await tester.pumpWidget(const SizedBox());
    final only = await mount(tester);
    await select(tester, only, [unitOne]);
    expect(host, findsOneWidget);
    expect(only.calls.last.kind, PlanObjectKind.unit);
    expect(only.calls.last.label, '1');
    expect(only.calls.last.symbolKey, embeddingTable.key);
  });

  testWidgets(
      'OI4 two objects selected, none, a locked object, the panel '
      'off: no host widget', (tester) async {
    final r = await mount(tester);
    await select(tester, r, [planter, rail]);
    expect(host, findsNothing);
    await select(tester, r, []);
    expect(host, findsNothing);
    // A layer lock is not an object lock: the property panel shows, so does
    // this.
    await select(tester, r, [unitLocked]);
    expect(host, findsOneWidget);
    await select(tester, r, [rail]);
    expect(host, findsOneWidget);
    await select(tester, r, [planter, rail]);
    expect(host, findsNothing);

    // A kit-locked object (its kit missing): as the property panel, nothing.
    await tester.pumpWidget(const SizedBox());
    final broken = await mount(tester, kits: [objectKit]);
    expect(broken.c.isLocked(planter), isTrue);
    expect(broken.c.objectDetailOf(ref(planter)), isNotNull);
    await select(tester, broken, [planter]);
    expect(host, findsNothing);
    expect(broken.calls, isEmpty);

    await tester.pumpWidget(const SizedBox());
    final off = await mount(tester, panel: false);
    await select(tester, off, [rail]);
    expect(host, findsNothing);
    expect(off.calls, isEmpty);
  });

  testWidgets(
      'OI5 the inspected object deleted, the deletion undone and '
      'redone: the widget goes, comes back, goes', (tester) async {
    final r = await mount(tester);
    await select(tester, r, [rail]);
    expect(host, findsOneWidget);
    expect(r.c.deleteSelection(), isTrue);
    await tester.pump();
    expect(r.c.objectDetailOf(ref(rail)), isNull);
    expect(host, findsNothing);
    r.c.undo();
    await tester.pump();
    r.c.selection.replace([key(rail)]);
    await tester.pump();
    expect(host, findsOneWidget);
    // Redo with the object selected removes it under the open inspector.
    r.c.redo();
    await tester.pump();
    expect(host, findsNothing);
    expect(r.stale, isEmpty);
    expect(r.calls.every((d) => d.ref == ref(rail)), isTrue);
    expect(r.calls, isNotEmpty);
  });

  testWidgets(
      'OI6 setObjectData from inside the host widget updates the '
      'detail the next build sees', (tester) async {
    final r = await mount(tester);
    await select(tester, r, [planter]);
    expect(r.calls.last.data, isEmpty);
    await tester.tap(find.byKey(const Key('host-object-set')));
    await tester.pump();
    expect(r.calls.last.data, {'id': 'linked'});
    expect(find.textContaining('{id: linked}'), findsOneWidget);
    r.c.undo();
    await tester.pump();
    expect(find.textContaining('{}'), findsOneWidget);
  });
}
