// 2b spec S4 "Widgets" (PlanServiceView alone, its flows and options),
// "Permissions" (the design flags never gate service; serviceMerge),
// "Painting" (the colour opacity every exporter receives) and "Unit
// overlays" (generated units get theirs); S3 (the copy's tool reports to
// the view). Over the embedding plan (tables turned, mirrored, scaled 40 m
// off the origin) and Task 5's two rows (one turned, one curved).
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart';
import 'package:jet_cad_2d_plan/src/controller/permissions.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/export/export_dialog.dart'
    show PlanExportDialog;
import 'package:jet_cad_2d_plan/src/export/registries.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/view/plan_service_view.dart';
import 'package:jet_cad_2d_plan/src/service/view/unit_overlays.dart';
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart';

import '../../support/fake_page_printer.dart';
import '../../support/recording_exporters.dart';
import '../../support/service_fixtures.dart';
import '../../support/service_host.dart';

/// Moves the unit labelled [label] of the active document by (dx, dy) mm,
/// one command (bars_test.dart:296-305's `move`).
void move(PlanController c, String label, double dx, double dy) {
  final d = c.activeDocument;
  final node =
      d.tree[c.unitIndex.withLabel(label).single.instance]! as InstanceNode;
  d.commands.execute(CompoundCommand([
    TransformNodeCommand(
        node.handle, Transform2.translation(dx, dy).multiply(node.transform))
  ], label: 'Move'));
}

Future<void> settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
}

/// A host dialog that answers [exporter] at 96 dpi at once.
PlanExportDialog answer(String exporter) =>
    (_, __, ___) async => PlanExportAnswer(
        exporter: exporter,
        choice: const PlanExportChoice(dpi: PlanExportDpi.d96));

void main() {
  testWidgets(
      'SV-1 PlanServiceView mounted alone follows the mode: nothing in '
      'design, the bar and the canvas in service, nothing again in design',
      (tester) async {
    final c = serviceController();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanServiceView(controller: c))));
    await tester.pump();
    expect(find.byType(InteractionLayer), findsNothing);
    expect(byKey('service-bar'), findsNothing);
    // M-SV-1: the view does not listen to the controller or its mode.
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    expect(find.byType(InteractionLayer), findsOneWidget);
    expect(byKey('service-bar'), findsOneWidget);
    c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    expect(find.byType(InteractionLayer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'SV-2 alone, the host\'s flows: Print goes to its printer under its '
      'exportName; Export goes through its dialog to its onExport; a failing '
      'printer reaches onPageFlowError', (tester) async {
    final exporter = RecordingPageExporter('acme.page', 'pg', 'x/pg');
    final c = PlanController(
        kits: [fxKit()], json: embeddingPlanJson(), exporters: [exporter]);
    addTearDown(c.dispose);
    final printer = FakePagePrinter();
    final exports = <PlanExport>[];
    final errors = <Object>[];
    await pumpService(
        tester,
        c,
        PlanServiceView(
            controller: c,
            printer: printer,
            exportName: 'hall',
            onExport: exports.add,
            onExportDialog: answer('acme.page'),
            onPageFlowError: errors.add));
    await tester.tap(byKey('service-print'));
    await tester.pump();
    await settle(tester, () => printer.calls.isNotEmpty);
    // M-SV-2: the view's settings hand the flows exportName 'plan'.
    expect(printer.calls.single.name, 'hall');
    await tester.tap(byKey('service-export'));
    await tester.pump();
    await settle(tester, () => exports.isNotEmpty);
    expect(exports.single.name, 'hall.pg');
    expect(exporter.requests, hasLength(1));
    printer.failNext = StateError('no printer');
    await tester.tap(byKey('service-print'));
    await tester.pump();
    await settle(tester, () => errors.isNotEmpty);
    expect(errors.single, isA<StateError>());
  });

  testWidgets(
      'SV-3 the design flags never gate service: with undo, export and print '
      'refused, the service bar keeps Undo, Export and Print, Ctrl+Z undoes '
      'a service move and Export delivers its bytes', (tester) async {
    final c = serviceController();
    c.permissions =
        PlanPermissions.full.copyWith(undo: false, export: false, print: false);
    final exports = <PlanExport>[];
    await pumpService(
        tester,
        c,
        PlanServiceView(
            controller: c,
            onExport: exports.add,
            onExportDialog: answer('plan.png')));
    for (final k in ['service-undo', 'service-export', 'service-print']) {
      expect(byKey(k), findsOneWidget, reason: k);
    }
    final before = unitCentre(c, '1');
    move(c, '1', 900, -600);
    await tester.pump();
    expect(unitCentre(c, '1').x, before.x + 900, reason: 'premise: moved');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    // M-SV-3b: the service chords bind Undo only while permissions.undo.
    expect(unitCentre(c, '1').x, before.x);
    await tester.tap(byKey('service-export'));
    await tester.pump();
    await settle(tester, () => exports.isNotEmpty);
    // M-SV-3a: EditorPageFlows reads permissions.export in service too.
    expect(exports.single.name, 'plan.png');
  });

  testWidgets(
      'SV-4 serviceMerge: false shows neither Merge nor Split though both '
      'callbacks are given; true shows both again, read at the next build',
      (tester) async {
    final c = serviceController();
    await pumpService(
        tester,
        c,
        PlanServiceView(
            controller: c, onMergeRequested: (_) {}, onSplitRequested: (_) {}));
    expect(byKey('service-merge'), findsOneWidget, reason: 'premise');
    expect(byKey('service-split'), findsOneWidget, reason: 'premise');
    c.permissions = c.permissions.copyWith(serviceMerge: false);
    await tester.pump();
    // M-SV-4: the bar ignores serviceMerge.
    expect(byKey('service-merge'), findsNothing);
    expect(byKey('service-split'), findsNothing);
    expect(byKey('service-undo'), findsOneWidget);
    c.permissions = c.permissions.copyWith(serviceMerge: true);
    await tester.pump();
    expect(byKey('service-merge'), findsOneWidget);
    expect(byKey('service-split'), findsOneWidget);
  });

  testWidgets(
      'SV-5 the view\'s unitColourOpacity reaches every exporter in service: '
      '0.8 from PlanServiceView(theme:), 0.35 with no theme', (tester) async {
    final exporter = RecordingPageExporter('acme.page', 'pg', 'x/pg');
    final c = PlanController(
        kits: [fxKit()], json: embeddingPlanJson(), exporters: [exporter]);
    addTearDown(c.dispose);
    final exports = <PlanExport>[];
    Future<void> exportOnce() async {
      final before = exports.length;
      await tester.tap(byKey('service-export'));
      await tester.pump();
      await settle(tester, () => exports.length > before);
    }

    await pumpService(
        tester,
        c,
        PlanServiceView(
            controller: c,
            onExport: exports.add,
            onExportDialog: answer('acme.page'),
            theme: const PlanTheme(unitColourOpacity: 0.8)));
    await exportOnce();
    // M-SV-5: the view hands the flows kUnitColourOpacity always.
    expect(exporter.requests.last.unitColourOpacity, 0.8);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PlanServiceView(
                controller: c,
                onExport: exports.add,
                onExportDialog: answer('acme.page')))));
    await tester.pump();
    await exportOnce();
    expect(exporter.requests.last.unitColourOpacity, kUnitColourOpacity);
  });

  testWidgets(
      'SV-6 generated units get overlays: one per labelled unit with '
      'geometry, the seats of both rows included, each seat\'s detail '
      'naming its row\'s type', (tester) async {
    final c = rowsController();
    final built = <PlanUnitOverlay>[];
    await pumpService(
        tester,
        c,
        PlanServiceView(
            controller: c,
            unitOverlayBuilder: (_, o) {
              built.add(o);
              return const SizedBox(width: 8, height: 8);
            }));
    final expected = <String>[
      for (final d in c.unitDetails)
        if (d.unit.label != null && d.center != null) d.unit.label!
    ];
    expect(expected.where((l) => l.startsWith('A')), isNotEmpty,
        reason: 'premise: the fixture\'s seats are labelled');
    // M-SV-6: _recompute skips a unit whose generatedBy is not null.
    expect([for (final o in built) o.detail.unit.label!]..sort(),
        [...expected]..sort());
    final seats = built.where((o) => o.detail.unit.generatedBy != null);
    expect(seats, isNotEmpty);
    expect({for (final o in seats) o.detail.unit.generatedBy}, {'test.row'});
  });

  testWidgets(
      'SV-7 the copy\'s tool reports to the view\'s host: a tap on a seat '
      'and a tap on the table each reach onUnitTap with their label; after '
      'resetService the new copy reports too', (tester) async {
    final c = rowsController();
    final taps = <String>[];
    await pumpService(
        tester, c, PlanServiceView(controller: c, onUnitTap: taps.add));
    // Frame the plan so every unit is on the canvas.
    c.fitToView();
    await tester.pump();
    await tester.pump();
    final seat =
        c.unitDetails.firstWhere((d) => d.unit.generatedBy != null).unit.label!;
    final table =
        c.unitDetails.firstWhere((d) => d.unit.generatedBy == null).unit.label!;
    for (final label in [seat, table]) {
      await tester.tapAt(globalOfWorld(tester, c, unitCentre(c, label)),
          kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
    }
    // M-SV-7: the canvas never sets the session's host.
    expect(taps, [seat, table]);
    c.resetService();
    await tester.pump();
    await tester.pump();
    await tester.tapAt(globalOfWorld(tester, c, unitCentre(c, seat)),
        kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(taps, [seat, table, seat]);
  });

  testWidgets(
      'SV-restore after restoreService the view is on the new copy: its '
      'canvas shows the new activeDocument, and a tap at the restored '
      'table\'s place reaches onUnitTap (final review I-3, '
      'M-SR-restore-notify)', (tester) async {
    final c = rowsController();
    final taps = <String>[];
    await pumpService(
        tester, c, PlanServiceView(controller: c, onUnitTap: taps.add));
    c.fitToView();
    await tester.pump();
    await tester.pump();
    final table =
        c.unitDetails.firstWhere((d) => d.unit.generatedBy == null).unit.label!;
    final designed = unitCentre(c, table);
    // Down and left of the plan, onto the floor: under the rows' seats
    // nothing is there.
    move(c, table, -1500, -1500);
    final restored = unitCentre(c, table);
    final json = c.serviceJson()!;
    c.resetService();
    await tester.pump();
    await tester.pump();
    expect(unitCentre(c, table).x, closeTo(designed.x, 1e-6),
        reason: 'premise: the reset put the table back');
    await tester.tapAt(globalOfWorld(tester, c, restored),
        kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(taps, isEmpty, reason: 'premise: the floor before the restore');

    c.restoreService(json);
    await tester.pump();
    await tester.pump();
    final canvas = tester.widget<PlanCanvasView>(find.byType(PlanCanvasView));
    expect(identical(canvas.document, c.activeDocument), isTrue);
    await tester.tapAt(globalOfWorld(tester, c, restored),
        kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(taps, [table]);
  });
}
