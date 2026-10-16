// Spec 4a O3: `PlanController.pageFlowBusy` is true from an export's or a
// print's start (the dialog included) to its end, an error and a cancel
// included, for the editor's flows and the controller's own calls.
// Mutations: PB-export-callback goes red when `EditorPageFlows._run`
// releases the guard before the host's `onExport`; PB-signal when
// `PlanPageFlows.acquire` does not raise it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/export_plan.dart';
import '../support/fake_page_printer.dart';
import '../support/flows_bar.dart';
import '../support/mark_kit.dart';

Finder byKey(String k) => find.byKey(Key(k));

Future<PlanController> pump(
  WidgetTester tester, {
  void Function(PlanExport)? onExport,
  FakePagePrinter? printer,
  PlanExportDialog? dialog,
  void Function(Object)? onError,
  List<bool>? log,
}) async {
  final c = PlanController(kits: [markKit()], json: exportPlanJson());
  addTearDown(c.dispose);
  if (log != null) {
    c.pageFlowBusy.addListener(() => log.add(c.pageFlowBusy.value));
  }
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: FlowsBar(
              controller: c,
              onExport: onExport,
              printer: printer,
              onExportDialog: dialog,
              onPageFlowError: onError))));
  await tester.pump();
  await tester.pump();
  return c;
}

/// Real time until [done].
Future<void> until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 600 && !done(); i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'premise: reached');
}

void main() {
  testWidgets(
      'PB-export the editor\'s export: busy from the press, through the '
      'dialog and the bytes, still true inside onExport; false after',
      (tester) async {
    final answer = Completer<PlanExportAnswer?>();
    final inside = <bool>[];
    final log = <bool>[];
    late PlanController c;
    var opened = false;
    c = await pump(tester,
        log: log,
        onExport: (_) => inside.add(c.pageFlowBusy.value),
        dialog: (context, initial, exporters) {
          opened = true;
          return answer.future;
        });
    expect(c.pageFlowBusy.value, isFalse, reason: 'premise: idle');
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    await until(tester, () => opened);
    expect(c.pageFlowBusy.value, isTrue, reason: 'the dialog is up');
    answer.complete(PlanExportAnswer.initial);
    await until(tester, () => inside.isNotEmpty);
    // PB-export-callback: releasing before onExport reads false here.
    expect(inside, [true]);
    await until(tester, () => !c.pageFlowBusy.value);
    expect(log, [true, false], reason: 'one rise, one fall');
  });

  testWidgets('PB-cancel a dialog answering null: busy ends, nothing exported',
      (tester) async {
    final answer = Completer<PlanExportAnswer?>();
    final got = <PlanExport>[];
    var opened = false;
    final c = await pump(tester, onExport: got.add,
        dialog: (context, initial, exporters) {
      opened = true;
      return answer.future;
    });
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    await until(tester, () => opened);
    expect(c.pageFlowBusy.value, isTrue);
    answer.complete(null);
    await until(tester, () => !c.pageFlowBusy.value);
    expect(got, isEmpty);
  });

  testWidgets(
      'PB-error a dialog that throws: onPageFlowError hears it, busy ends',
      (tester) async {
    final errors = <Object>[];
    late PlanController c;
    c = await pump(tester, onExport: (_) {}, onError: errors.add,
        dialog: (context, initial, exporters) async {
      expect(c.pageFlowBusy.value, isTrue, reason: 'busy in the hook');
      throw StateError('no dialog');
    });
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    await until(tester, () => errors.isNotEmpty);
    expect(errors.single, isA<StateError>());
    await until(tester, () => !c.pageFlowBusy.value);
  });

  testWidgets(
      'PB-print the editor\'s print: busy while the job is held; false when '
      'it completes, and when it throws', (tester) async {
    final printer = FakePagePrinter()..hold = true;
    final errors = <Object>[];
    final c = await pump(tester,
        onExport: (_) {}, printer: printer, onError: errors.add);
    await tester.tap(byKey('toolbar-print'));
    await tester.pump();
    await until(tester, () => printer.held.isNotEmpty);
    expect(c.pageFlowBusy.value, isTrue);
    printer.held.single.complete();
    await until(tester, () => !c.pageFlowBusy.value);

    printer
      ..hold = false
      ..failNext = StateError('jam');
    await tester.tap(byKey('toolbar-print'));
    await tester.pump();
    await until(tester, () => errors.isNotEmpty);
    await until(tester, () => !c.pageFlowBusy.value);
  });

  testWidgets(
      'PB-controller the controller\'s own print and export raise it too, '
      'with no view; a refused second call leaves it up', (tester) async {
    final c = PlanController(kits: [markKit()], json: exportPlanJson());
    addTearDown(c.dispose);
    final printer = FakePagePrinter()..hold = true;
    final job = c.print(PlanExportChoice.initial, printer: printer);
    expect(c.pageFlowBusy.value, isTrue, reason: 'raised at the call');
    expect(await c.export('plan.pdf', PlanExportChoice.initial), isNull,
        reason: 'premise: refused while the print runs');
    expect(c.pageFlowBusy.value, isTrue);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    printer.held.single.complete();
    expect(await job, isTrue);
    expect(c.pageFlowBusy.value, isFalse);
    final export = c.export('plan.pdf', PlanExportChoice.initial);
    expect(c.pageFlowBusy.value, isTrue);
    expect(await tester.runAsync(() => export), isNotNull);
    expect(c.pageFlowBusy.value, isFalse);
  });
}
