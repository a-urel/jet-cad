// The right column follows the selection (PlanEditor.contextualPanels): with
// something selected it shows the object's own properties and the host's
// inspector only; with nothing selected, the Layers and Page sections.
// Fixture: object_inspector_test's plan (turned and mirrored units, a
// planter symbol and a turned rail, all far off the origin).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart' show planText;
import '../support/object_kit.dart';
import '../support/unit_embedding_fixture.dart';
import '../support/unit_fixtures.dart';

late Handle unit, planter, rail;

String plan() => planText([fxKit(), objectKit], (d) {
      unit = placeUnit(d, embeddingTable,
          transform: embeddingPlacement(40000, -27000, 30));
      addUnitLabel(d, unit, '1');
      planter = placeTurned(d, planterSymbol, Vector2(52000, -20000)).handle;
      rail =
          addTurned(d, const RailComponent(3000), Vector2(47000, -40000), 0.7);
      d.commands.clearHistory();
    });

Future<PlanController> mount(WidgetTester tester,
    {bool contextual = true,
    PlanEditorLayout layout = PlanEditorLayout.desktop}) async {
  final c = PlanController(kits: [fxKit(), objectKit], json: plan());
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(layout == PlanEditorLayout.phone
      ? const Size(375, 812)
      : const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: PlanEditor(
    controller: c,
    layout: layout,
    contextualPanels: contextual,
    objectInspectorBuilder: (context, d) =>
        Text('host ${d.kind.name}', key: const Key('host-object')),
  ))));
  await tester.pump();
  await tester.pump();
  return c;
}

Future<void> select(
    WidgetTester tester, PlanController c, List<Handle> hs) async {
  c.selection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

Finder get layers => find.byType(PlanLayerPanel);
Finder get page => find.byType(PlanPagePanel);
Finder get host => find.byKey(const Key('host-object'));

void main() {
  testWidgets(
      'CP1 nothing selected: Layers and Page show; a selected symbol hides '
      'them and keeps its properties and the host widget', (tester) async {
    final c = await mount(tester);
    expect(layers, findsOneWidget);
    expect(page, findsOneWidget);
    await select(tester, c, [planter]);
    expect(layers, findsNothing);
    expect(page, findsNothing);
    expect(find.byType(PlanPropertyPanel), findsOneWidget);
    expect(host, findsOneWidget);
  });

  testWidgets(
      'CP2 a turned unit, a kit object and two objects at once hide them '
      'too; clearing the selection shows them again, their state kept',
      (tester) async {
    final c = await mount(tester);
    final before = tester.state(layers);
    for (final hs in [
      [unit],
      [rail],
      [unit, planter],
    ]) {
      await select(tester, c, hs);
      expect(layers, findsNothing, reason: '$hs');
      expect(page, findsNothing, reason: '$hs');
    }
    await select(tester, c, []);
    expect(layers, findsOneWidget);
    expect(page, findsOneWidget);
    expect(identical(tester.state(layers), before), isTrue);
  });

  testWidgets(
      'CP3 contextualPanels false: a selected symbol keeps Layers and Page '
      'under its properties (0.9.0)', (tester) async {
    final c = await mount(tester, contextual: false);
    await select(tester, c, [planter]);
    expect(layers, findsOneWidget);
    expect(page, findsOneWidget);
    expect(host, findsOneWidget);
  });

  testWidgets(
      'CP4 on a phone the right drawer follows the selection the same way',
      (tester) async {
    final c = await mount(tester, layout: PlanEditorLayout.phone);
    await tester.tap(find.byKey(const Key('chrome-right-button')));
    await tester.pumpAndSettle();
    expect(layers, findsOneWidget);
    expect(page, findsOneWidget);
    await select(tester, c, [planter]);
    expect(layers, findsNothing);
    expect(page, findsNothing);
    expect(host, findsOneWidget);
  });

  testWidgets(
      'CP5 a plan opened anew (a fresh selection) is followed: its '
      'selection hides them, and clearing it shows them', (tester) async {
    final c = await mount(tester);
    c.load(plan());
    await tester.pump();
    expect(layers, findsOneWidget);
    await select(tester, c, [planter]);
    expect(layers, findsNothing);
    await select(tester, c, []);
    expect(layers, findsOneWidget);
  });
}
