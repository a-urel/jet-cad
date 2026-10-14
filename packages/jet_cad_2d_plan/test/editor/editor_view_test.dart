// 2a spec P2 (PlanEditor is today's design-mode view). Ported, assertions
// unchanged, from jet_cad_floor_plan/test/host/view_test.dart (V1's and
// V2's design halves), test/planner_shell_test.dart ("a bare shell opens on
// the empty document and its default page", the zoom text, the three
// chrome slots, the status text) and test/planner_draw_test.dart (A16,
// A27: the bar's read-outs, which Task 16 sent here), each over a
// PlanEditor.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show PolylineTool, SelectionKey, kLogicalPixelsPerMm;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';

import '../support/canvas_fixture.dart';
import '../support/design_harness.dart' show press, status;
import '../support/editor_host.dart';
import '../support/mark_kit.dart';

/// [c] in a PlanEditor under the drawing fixture's camera (pumpDraw).
Future<void> pumpDrawEditor(WidgetTester tester, PlanController c) =>
    pumpDraw(tester, c, frame: (_) => PlanEditor(controller: c));

void main() {
  testWidgets(
      'V1 the editor has Export and Print and no file commands (its design '
      'half)', (tester) async {
    final c = editorController();
    await pumpEditor(tester, PlanEditor(controller: c, onExport: (_) {}));
    expect(find.byType(PlanEditor), findsOneWidget);
    expect(byKey('toolbar-export'), findsOneWidget);
    expect(byKey('toolbar-print'), findsOneWidget);
    for (final k in ['toolbar-new', 'toolbar-open', 'toolbar-save']) {
      expect(byKey(k), findsNothing, reason: k);
    }
    expect(byKey('document-name'), findsNothing);
  });

  testWidgets('V2 without onExport, Export is not offered (its design half)',
      (tester) async {
    final c = editorController();
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(byKey('toolbar-export'), findsNothing);
    expect(byKey('toolbar-print'), findsOneWidget);
  });

  testWidgets('a bare editor opens on the empty document and its default page',
      (tester) async {
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(home: PlanEditor(controller: c)));
    await tester.pump();

    expect(c.document.entities.liveCount, 0);
    expect(c.document.commands.canUndo, isFalse);
    expect(c.page.value, PageComponent(originX: -7425, originY: -5250));
    expect(c.document.header.units, DrawingUnits.millimeters);
    expect(tester.widget<Text>(find.byKey(const Key('zoom-text'))).data,
        startsWith('1:50 · '));
  });

  testWidgets('the zoom text reads the scale and the fitted zoom',
      (tester) async {
    final c = editorController();
    await tester.pumpWidget(MaterialApp(home: PlanEditor(controller: c)));
    await tester.pump();
    final page =
        c.document.components.get<PageComponent>(c.document.rootHandle)!;
    final zoom = zoomOf(c.camera.value.scale, page, kLogicalPixelsPerMm);
    final text = tester.widget<Text>(find.byKey(const Key('zoom-text'))).data;
    expect(text, '1:50 · ${(zoom * 100).round()}%');
    c.camera.zoomAt(const Offset(100, 100), 2.0);
    await tester.pump();
    final after = tester.widget<Text>(find.byKey(const Key('zoom-text'))).data;
    expect(after, '1:50 · ${(zoom * 2 * 100).round()}%');
  });

  testWidgets('the three chrome slots are laid out', (tester) async {
    final c = editorController();
    await tester.pumpWidget(MaterialApp(home: PlanEditor(controller: c)));
    await tester.pump();
    for (final key in const [
      Key('chrome-top'),
      Key('chrome-left'),
      Key('chrome-right')
    ]) {
      expect(find.byKey(key), findsOneWidget);
      expect(tester.getSize(find.byKey(key)).width, greaterThan(0));
    }
  });

  testWidgets('the status text shows the tool name and follows the selection',
      (tester) async {
    final c = editorController();
    await tester.pumpWidget(MaterialApp(home: PlanEditor(controller: c)));
    await tester.pump();

    final statusFinder = find.byKey(const Key('status-text'));
    expect(tester.widget<Text>(statusFinder).data, 'Select');

    // The first mark of the fixture, as the source picked a wall.
    final first = c.catalog.objectsOf<MarkCross>(c.document).first;
    c.selection.replace([SelectionKey.root(first)]);
    await tester.pump();

    expect(tester.widget<Text>(statusFinder).data, 'Select — 1 selected');
  });

  testWidgets(
      'A16 F3 mid-polyline flips OSNAP and keeps the shape pending '
      '(Ruling F-2)', (tester) async {
    final c = drawController().c;
    await pumpDrawEditor(tester, c);
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7060, 3090));
    await tester.pump();
    final polyline = activeTool(c) as PolylineTool;
    expect(polyline.isPending, isTrue);
    String osnapText() =>
        tester.widget<Text>(find.byKey(const Key('osnap-text'))).data!;
    expect(osnapText(), 'OSNAP');
    await press(tester, LogicalKeyboardKey.f3);
    expect(osnapText(), 'osnap off',
        reason: 'the tool ignores F3, so it reaches the shell');
    expect(status(tester), 'Polyline');
    expect(polyline.isPending, isTrue);
  });

  testWidgets(
      "A27 the status line's scale for a 1:1e20 page parses back to exactly "
      '1e20 (post-11 m3)', (tester) async {
    final c = drawController().c;
    await pumpDrawEditor(tester, c);
    final doc = c.document;
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, page.copyWith(scaleDenominator: 1e20)));
    // The editor hears of the page from `document.changes`, an
    // asynchronous stream: the first pump delivers it, the second rebuilds
    // the line.
    await tester.pump();
    await tester.pump();
    final text = tester.widget<Text>(find.byKey(const Key('zoom-text'))).data!;
    expect(text, startsWith('1:'));
    final scaleText = text.substring(2, text.indexOf(' · '));
    expect(double.parse(scaleText), 1e20,
        reason: 'the status line reads "$text"');
  });
}
