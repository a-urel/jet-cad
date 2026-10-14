// 2b spec S4 ("PlanEditor shows it when the mode is service, so a host
// with one widget keeps today's single view"; the events and options
// passed through PlanEditor; "Permissions": the design flags never gate
// service) and today's G-5 (overlays rebuild at the host's rebuild only).
// Over the embedding plan and Task 5's rows. SV-12 is 2a's parked
// PlanShortcuts remount item (2a progress.md:180): the mode switch
// remounts the editor's PlanShortcuts, which must speak for the select
// tool's idle keys again.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas.dart';
import 'package:jet_cad_2d_plan/src/controller/permissions.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/service_tool.dart';
import 'package:jet_cad_2d_plan/src/service/view/plan_service_bar.dart';
import 'package:jet_cad_2d_plan/src/service/view/plan_service_view.dart';
import 'package:jet_cad_2d_plan/src/service/view/unit_overlays.dart';
import 'package:jet_cad_2d_plan/src/units/unit_detail.dart';

import '../support/fake_page_printer.dart';
import '../support/service_fixtures.dart';
import '../support/service_host.dart';

Future<void> pumpEditor(WidgetTester tester, PlanEditor editor) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: editor)));
  await tester.pump();
  await tester.pump();
  editor.controller.camera.value = embeddingCamera();
  await tester.pump();
}

void main() {
  testWidgets(
      'SV-8 PlanEditor shows PlanServiceView in service and its editor in '
      'design: no canvas of the other mode, one canvas in each',
      (tester) async {
    final c = serviceController();
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(find.byType(PlanCanvas), findsOneWidget);
    expect(find.byType(PlanServiceView), findsNothing);
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    // M-SV-8: PlanEditor builds its editor whatever the mode.
    expect(find.byType(PlanServiceView), findsOneWidget);
    expect(find.byType(PlanCanvas), findsNothing);
    expect(byKey('chrome-left'), findsNothing);
    expect(find.byType(InteractionLayer), findsOneWidget);
    c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlanCanvas), findsOneWidget);
    expect(find.byType(PlanServiceView), findsNothing);
  });

  testWidgets(
      'SV-9 every service option of PlanEditor reaches its PlanServiceView '
      'unchanged', (tester) async {
    final c = serviceController();
    void tap(String _) {}
    void doubleTap(String _) {}
    void menu(String _, Offset __) {}
    void group(String _, String __) {}
    void hover(String? _) {}
    void merge(Set<String> _) {}
    void split(String _) {}
    void layout() {}
    void moved(List<PlanUnitDetail> _) {}
    void floor(Offset _) {}
    Widget? badge(BuildContext _, PlanUnitOverlay __) => null;
    const bar = PlanServiceBar(actions: [PlanServiceAction.print]);
    const layout2 = PlanOverlayLayout(hideBelowScale: 0.1);
    c.setMode(PlanMode.service);
    await pumpEditor(
        tester,
        PlanEditor(
          controller: c,
          serviceBar: bar,
          onUnitTap: tap,
          onUnitDoubleTap: doubleTap,
          onUnitContextMenu: menu,
          onGroupTap: group,
          onUnitHover: hover,
          onMergeRequested: merge,
          onSplitRequested: split,
          onLayoutChanged: layout,
          onUnitsMoved: moved,
          onFloorTap: floor,
          longPress: PlanLongPress.contextMenu,
          floorDrag: PlanFloorDrag.band,
          userCamera: false,
          shortcuts: false,
          autofocus: false,
          unitOverlayBuilder: badge,
          unitOverlayLayout: layout2,
          unitOverlayModes: const {PlanMode.design, PlanMode.service},
          exportName: 'hall',
        ));
    final v = tester.widget<PlanServiceView>(find.byType(PlanServiceView));
    // M-SV-9: PlanEditor does not hand onUnitHover down.
    expect(v.bar, same(bar));
    expect(v.onUnitTap, same(tap));
    expect(v.onUnitDoubleTap, same(doubleTap));
    expect(v.onUnitContextMenu, same(menu));
    expect(v.onGroupTap, same(group));
    expect(v.onUnitHover, same(hover));
    expect(v.onMergeRequested, same(merge));
    expect(v.onSplitRequested, same(split));
    expect(v.onLayoutChanged, same(layout));
    expect(v.onUnitsMoved, same(moved));
    expect(v.onFloorTap, same(floor));
    expect(v.longPress, PlanLongPress.contextMenu);
    expect(v.floorDrag, PlanFloorDrag.band);
    expect(v.userCamera, isFalse);
    expect(v.shortcuts, isFalse);
    expect(v.autofocus, isFalse);
    expect(v.unitOverlayBuilder, same(badge));
    expect(v.unitOverlayLayout, same(layout2));
    expect(v.unitOverlayModes, {PlanMode.design, PlanMode.service});
    expect(v.exportName, 'hall');
  });

  testWidgets(
      'SV-10 in service, PlanEditor\'s own rebuild (new permissions) builds '
      'no overlay; the host\'s rebuild builds every one again (G-5)',
      (tester) async {
    final c = rowsController();
    var builds = 0;
    final host = ValueNotifier(0);
    addTearDown(host.dispose);
    c.setMode(PlanMode.service);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ValueListenableBuilder<int>(
                valueListenable: host,
                builder: (_, __, ___) => PlanEditor(
                    controller: c,
                    unitOverlayBuilder: (_, __) {
                      builds++;
                      return const SizedBox(width: 6, height: 6);
                    })))));
    await tester.pump();
    await tester.pump();
    final overlaid = [
      for (final d in c.unitDetails)
        if (d.unit.label != null && d.center != null) d
    ].length;
    expect(builds, overlaid, reason: 'premise: one build each');
    builds = 0;
    c.permissions = c.permissions.copyWith(rotate: false);
    await tester.pump();
    await tester.pump();
    // M-SV-10: PlanEditor makes its PlanServiceView afresh at each build.
    expect(builds, 0);
    host.value++;
    await tester.pump();
    expect(builds, overlaid);
  });

  testWidgets(
      'SV-11 the design permissions never gate service: with print refused, '
      'the service bar\'s Print prints once (spec S4 "Permissions")',
      (tester) async {
    final c = serviceController();
    final printer = FakePagePrinter();
    c.permissions = PlanPermissions.full.copyWith(print: false);
    c.setMode(PlanMode.service);
    await pumpEditor(tester, PlanEditor(controller: c, printer: printer));
    expect(byKey('service-print'), findsOneWidget, reason: 'premise: shown');
    await tester.tap(byKey('service-print'));
    await tester.pump();
    for (var i = 0; i < 400 && printer.calls.isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    // M-SV-3c: `_printAllowed() => controller.permissions.print`.
    expect(printer.calls, hasLength(1));
    expect(printer.calls.single.name, 'plan');
  });

  testWidgets(
      'SV-12 shortcuts: false across a mode switch: the editor\'s '
      'PlanShortcuts, remounted in design, keeps the select tool\'s idle '
      'Escape the host\'s (the selection stays, the host hears it)',
      (tester) async {
    final c = serviceController();
    var escapes = 0;
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CallbackShortcuts(bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () => escapes++,
    }, child: PlanEditor(controller: c, shortcuts: false)))));
    await tester.pump();
    await tester.pump();
    c.camera.value = embeddingCamera();
    await tester.pump();
    Future<void> focusCanvas() async {
      final at =
          tester.getTopLeft(find.byType(InteractionLayer)) + const Offset(6, 6);
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: at - const Offset(3, 3));
      await g.moveTo(at);
      await g.down(at);
      await g.up();
      await g.removePointer();
      await tester.pump();
    }

    await focusCanvas();
    c.select({'1'});
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.selectedUnits.value, {'1'}, reason: 'premise: the host\'s key');
    expect(escapes, 1);

    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    await focusCanvas();
    c.select({'1'});
    await tester.pump();
    // M-PS-idle: PlanShortcuts' initState does not apply its idle keys.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.selectedUnits.value, {'1'},
        reason: 'remounted: still the host\'s');
    expect(escapes, 2);
  });
}
