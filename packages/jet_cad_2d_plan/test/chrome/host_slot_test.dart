// Host slots keep working under a bare MaterialApp (spec "The scope": the
// transparent Material around every host slot, anti-goal "host Material
// widgets keep working"): a Material TextField and an InkWell in each slot
// build and respond to a tap.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/host_slot.dart';

import '../support/unit_editor_fixture.dart' as t;
import '../support/unit_editor_fixture.dart' show editorCamera, kEditorSurface;
import '../support/unit_fixtures.dart' show fxKit;

/// A host widget that needs a Material ancestor twice over: a TextField
/// and an InkWell, keyed by [id]; a tap on the ink is recorded in [taps].
Widget probe(String id, List<String> taps) => SizedBox(
      width: 160,
      height: 40,
      child: Row(children: [
        Expanded(child: TextField(key: Key('$id-field'))),
        SizedBox(
          width: 24,
          height: 24,
          child: InkWell(
            key: Key('$id-ink'),
            onTap: () => taps.add(id),
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      ]),
    );

Future<PlanController> mountApp(
    WidgetTester tester, Widget Function(PlanController) app,
    {bool service = false}) async {
  final c = PlanController(kits: [fxKit()], json: t.unitEditorPlanJson());
  addTearDown(c.dispose);
  if (service) c.setMode(PlanMode.service);
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // A bare MaterialApp: no Scaffold of the test's own.
  await tester.pumpWidget(MaterialApp(home: app(c)));
  await tester.pump();
  await tester.pump();
  c.camera.value = editorCamera();
  await tester.pump();
  return c;
}

Future<void> exercise(WidgetTester tester, String id, List<String> taps) async {
  expect(tester.takeException(), isNull);
  final ink = find.byKey(Key('$id-ink')).first;
  await tester.tap(ink);
  await tester.pump();
  expect(taps, [id]);
  final field = find.byKey(Key('$id-field')).first;
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, 'typed');
  await tester.pump();
  expect(find.text('typed'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  late List<String> taps;
  setUp(() => taps = []);

  // Today the editor's Scaffold and the service view's own transparent
  // Material already sit above every slot; the slot's Material is what
  // stays when the chrome drops them, so it is pinned on its own.
  testWidgets(
      'HS1 PlanHostSlot alone: a Material TextField and an InkWell build '
      'under a bare MaterialApp and respond to a tap', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Center(child: PlanHostSlot(child: probe('slot', taps)))));
    await exercise(tester, 'slot', taps);
  });

  group('HS1 a Material TextField and an InkWell in each host slot', () {
    testWidgets('PlanEditor bar leading', (tester) async {
      await mountApp(
          tester,
          (c) => PlanEditor(
              controller: c,
              bar: PlanEditorBar(leading: [probe('slot', taps)])));
      await exercise(tester, 'slot', taps);
    });

    testWidgets('PlanEditor bar trailing', (tester) async {
      await mountApp(
          tester,
          (c) => PlanEditor(
              controller: c,
              bar: PlanEditorBar(trailing: [probe('slot', taps)])));
      await exercise(tester, 'slot', taps);
    });

    testWidgets('PlanEditor service bar leading', (tester) async {
      await mountApp(
          tester,
          (c) => PlanEditor(
              controller: c,
              serviceBar: PlanServiceBar(leading: [probe('slot', taps)])),
          service: true);
      await exercise(tester, 'slot', taps);
    });

    testWidgets('PlanEditor service bar trailing', (tester) async {
      await mountApp(
          tester,
          (c) => PlanEditor(
              controller: c,
              serviceBar: PlanServiceBar(trailing: [probe('slot', taps)])),
          service: true);
      await exercise(tester, 'slot', taps);
    });

    testWidgets('PlanEditor unitInspectorBuilder', (tester) async {
      final c = await mountApp(
          tester,
          (c) => PlanEditor(
              controller: c,
              contextualPanels: false,
              unitInspectorBuilder: (context, d) => probe('slot', taps)));
      c.selection.replace([SelectionKey.root(t.tableOf(c, '1'))]);
      await tester.pump();
      await exercise(tester, 'slot', taps);
    });

    testWidgets('PlanEditor objectInspectorBuilder', (tester) async {
      final c = await mountApp(
          tester,
          (c) => PlanEditor(
              controller: c,
              contextualPanels: false,
              objectInspectorBuilder: (context, d) => probe('slot', taps)));
      c.selection.replace([SelectionKey.root(t.tableOf(c, '1'))]);
      await tester.pump();
      await exercise(tester, 'slot', taps);
    });

    testWidgets('PlanEditor unitOverlayBuilder in service', (tester) async {
      await mountApp(
          tester,
          (c) => PlanEditor(
              controller: c,
              unitOverlayLayout: const PlanOverlayLayout(interactive: true),
              unitOverlayBuilder: (context, o) => probe('slot', taps)),
          service: true);
      await exercise(tester, 'slot', taps);
    });

    testWidgets('PlanServiceView bar leading', (tester) async {
      await mountApp(
          tester,
          (c) => PlanServiceView(
              controller: c,
              bar: PlanServiceBar(leading: [probe('slot', taps)])),
          service: true);
      await exercise(tester, 'slot', taps);
    });

    testWidgets('PlanServiceView bar trailing', (tester) async {
      await mountApp(
          tester,
          (c) => PlanServiceView(
              controller: c,
              bar: PlanServiceBar(trailing: [probe('slot', taps)])),
          service: true);
      await exercise(tester, 'slot', taps);
    });

    testWidgets('PlanServiceView serviceSidePanel', (tester) async {
      await mountApp(
          tester,
          (c) => PlanServiceView(
              controller: c, serviceSidePanel: probe('slot', taps)),
          service: true);
      await exercise(tester, 'slot', taps);
    });

    testWidgets('PlanServiceView unitOverlayBuilder', (tester) async {
      await mountApp(
          tester,
          (c) => PlanServiceView(
              controller: c,
              unitOverlayLayout: const PlanOverlayLayout(interactive: true),
              unitOverlayBuilder: (context, o) => probe('slot', taps)),
          service: true);
      await exercise(tester, 'slot', taps);
    });
  });
}
