// N6 (spec decision 5, Task 6 Review Focus 3): the app is busy around the
// library's page flows, through two wrappers -- the export dialog and the
// page printer -- and around its own export write. While busy, the app's
// file callbacks do nothing and the exit request is cancelled.
//
// The sequence of an export, from the library's `EditorPageFlows.export`:
//   1. the dialog runs inside `busyExportDialog`: busy for as long as it is up;
//   2. its answer ends that busy span; the library then makes the bytes (PDF
//      and PNG are async) with ITS OWN guard held and the app not busy: the
//      app has no hook for that stretch (the N6-gap test pins what happens
//      to a flow started there);
//   3. the library calls `onExport` -> `exportFlow`: busy again, for the
//      save panel and the write (the N6-write test).
import 'dart:async';
import 'dart:typed_data';

import 'package:architecture_demo/busy_wrappers.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/app_fakes.dart';
import '../support/app_rig.dart';
import '../support/export_rig.dart';

final Vector2 far = Vector2(-37654.5, 30123.25);

/// The editor's own New callback: what its New button and Cmd+N call. Under
/// a dialog's barrier a tap would not reach the button.
Future<void> pressNew(WidgetTester tester) async {
  await tester.widget<PlanEditor>(find.byType(PlanEditor)).onNew!();
  await tester.pump();
}

/// Draws a wall far from the origin: the plan is dirty, one step of history.
Future<void> dirtyIt(AppRig rig) async {
  await aimCamera(rig.tester, rig.controller, far);
  await drawWall(rig.tester, rig.controller, far, far + Vector2(2600, -900));
  expect(rig.controller.dirty.value, isTrue, reason: 'premise: dirty');
}

void main() {
  testWidgets(
      'N6-dialog while the export dialog is up the app is busy: New does '
      'nothing (no replace dialog, the plan unchanged); dismissed, busy '
      'ends', (tester) async {
    final rig = await pumpFlat(tester);
    await dirtyIt(rig);
    final doc = rig.controller.document;
    final walls = wallsOf(rig.controller).length;
    expect(rig.session.busy.value, isFalse, reason: 'premise: idle');
    await openDialog(tester);
    expect(rig.session.busy.value, isTrue);
    await pressNew(tester);
    await tester.pump();
    expect(find.byKey(const Key('replace-dialog')), findsNothing);
    expect(identical(rig.controller.document, doc), isTrue);
    expect(wallsOf(rig.controller), hasLength(walls));
    expect(rig.controller.dirty.value, isTrue);
    await tapKey2(tester, 'export-cancel');
    expect(rig.session.busy.value, isFalse);
    expect(find.byKey(const Key('export-dialog')), findsNothing);
  });

  testWidgets(
      'N6-print while the print job is pending the app is busy: Cmd+S '
      'writes and asks nothing; completed, busy ends', (tester) async {
    final printer = FakePagePrinter()..hold = true;
    final rig = await pumpFlat(tester, printer: printer);
    await tester.tap(printButton);
    await settleUntil(tester, () => printer.held.isNotEmpty);
    expect(printer.held, hasLength(1), reason: 'premise: the job is pending');
    expect(rig.session.busy.value, isTrue);
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(rig.files.saveLocationCalls, isEmpty);
    expect(rig.files.writes, isEmpty);
    printer.held.single.complete();
    await tester.pump();
    await tester.pump();
    expect(rig.session.busy.value, isFalse);
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    expect(rig.files.writes, hasLength(1), reason: 'Save works again');
  });

  testWidgets(
      'N6-exit while the export dialog is up the exit request is cancelled, '
      'with no second dialog; after it closes the app exits', (tester) async {
    final rig = await pumpFlat(tester);
    await openDialog(tester);
    final response = tester.binding.handleRequestAppExit();
    await tester.pump();
    expect(find.byKey(const Key('replace-dialog')), findsNothing);
    expect(find.byKey(const Key('export-dialog')), findsOneWidget,
        reason: 'the one dialog is still the export\'s');
    expect(await response, AppExitResponse.cancel);
    await tapKey2(tester, 'export-cancel');
    expect(rig.session.busy.value, isFalse);
    final after = tester.binding.handleRequestAppExit();
    await tester.pump();
    expect(await after, AppExitResponse.exit, reason: 'clean and idle');
  });

  testWidgets(
      'N6-write while the export write is held the app is busy: New and '
      'Cmd+S do nothing and a second flow does not start; the write ends '
      'busy', (tester) async {
    final rig = await pumpFlat(tester);
    final files = rig.files
      ..holdWrites = true
      ..scriptSaveLocation(name: 'flat.pdf', location: '/out/flat.pdf');
    final doc = rig.controller.document;
    await openDialog(tester);
    await tapKey2(tester, 'export-ok');
    await settleUntil(tester, () => files.heldWrites.isNotEmpty);
    expect(files.heldWrites, hasLength(1), reason: 'premise: write held');
    expect(rig.session.busy.value, isTrue);
    await pressNew(tester);
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(identical(rig.controller.document, doc), isTrue,
        reason: 'New did not run');
    expect(files.writes, hasLength(1), reason: 'Save did not run');
    expect(files.saveLocationCalls, ['flat.pdf']);
    files.heldWrites.single.complete();
    await tester.pump();
    await tester.pump();
    expect(rig.session.busy.value, isFalse);
  });

  testWidgets(
      'N6-gap between the dialog closing and the write starting the app is '
      'NOT busy (the library is making the bytes): a New started there '
      'replaces the plan, and the library drops the export -- nothing is '
      'asked, nothing written, busy ends false', (tester) async {
    final rig = await pumpFlat(tester);
    final doc = rig.controller.document;
    await openDialog(tester);
    await tapKey2(tester, 'export-format-plan.png');
    await tapKey2(tester, 'export-dpi-300');
    await tester.tap(find.byKey(const Key('export-ok')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('export-dialog')), findsNothing,
        reason: 'premise: the dialog has closed');
    expect(rig.files.saveLocationCalls, isEmpty,
        reason: 'premise: the bytes are still being made');
    expect(rig.session.busy.value, isFalse,
        reason: 'the gap: no hook in the library, the app is not busy');
    await pressNew(tester);
    expect(identical(rig.controller.document, doc), isFalse,
        reason: 'New ran: the plan is replaced');
    // EX3-open's 300 dpi export needs about a second of real time to reach
    // its save panel; wait twice that.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    expect(rig.files.saveLocationCalls, isEmpty);
    expect(rig.files.writes, isEmpty);
    expect(rig.session.busy.value, isFalse);
  });

  testWidgets(
      'N6-once the editor gets the same busy printer and the same busy '
      'dialog across rebuilds, and the printer wraps the one given',
      (tester) async {
    final printer = FakePagePrinter();
    final rig = await pumpFlat(tester, printer: printer);
    PlanEditor editor() => tester.widget<PlanEditor>(find.byType(PlanEditor));
    final first = editor();
    expect(first.printer, isA<BusyPagePrinter>());
    expect((first.printer! as BusyPagePrinter).inner, same(printer));
    expect((first.printer! as BusyPagePrinter).busy, same(rig.session.busy));
    expect(first.onExportDialog, isNotNull);
    rig.session.nameChanged();
    await tester.pump();
    final second = editor();
    expect(identical(second, first), isFalse, reason: 'premise: rebuilt');
    expect(second.printer, same(first.printer));
    expect(second.onExportDialog, same(first.onExportDialog));
  });

  group('the wrappers', () {
    late BuildContext context;
    Future<void> pumpContext(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      context = tester.element(find.byType(SizedBox));
    }

    testWidgets(
        'busyExportDialog: busy while the given dialog runs; its answer '
        'passes through; busy ends when it answers or throws', (tester) async {
      await pumpContext(tester);
      final busy = ValueNotifier(false);
      final answer = Completer<PlanExportAnswer?>();
      var seen = <bool>[];
      Future<PlanExportAnswer?> inner(
          BuildContext c, PlanExportAnswer i, List<PlanExporter> e) {
        seen.add(busy.value);
        return answer.future;
      }

      const given = PlanExportAnswer(
          exporter: 'plan.png',
          choice: PlanExportChoice(dpi: PlanExportDpi.d300));
      final result =
          busyExportDialog(busy, dialog: inner)(context, given, const []);
      expect(seen, [true], reason: 'busy when the dialog started');
      expect(busy.value, isTrue);
      answer.complete(given);
      expect(await result, same(given));
      expect(busy.value, isFalse);

      Future<PlanExportAnswer?> throwing(
              BuildContext c, PlanExportAnswer i, List<PlanExporter> e) =>
          Future.error(StateError('no dialog'));
      await expectLater(
          busyExportDialog(busy, dialog: throwing)(context, given, const []),
          throwsStateError);
      expect(busy.value, isFalse, reason: 'cleared by the finally');
      seen = [];
    });

    testWidgets(
        'busyExportDialog during another flow: the dialog does not open and '
        'answers null; the other flow\'s busy stays', (tester) async {
      await pumpContext(tester);
      final busy = ValueNotifier(true);
      var opened = 0;
      Future<PlanExportAnswer?> inner(
          BuildContext c, PlanExportAnswer i, List<PlanExporter> e) async {
        opened++;
        return i;
      }

      final result = await busyExportDialog(busy, dialog: inner)(
          context, PlanExportAnswer.initial, const []);
      expect(result, isNull);
      expect(opened, 0);
      expect(busy.value, isTrue);
    });

    test(
        'BusyPagePrinter: busy while the inner job runs, cleared when it '
        'ends or throws (the throw reaches the caller); during another flow '
        'it prints nothing and leaves busy', () async {
      final busy = ValueNotifier(false);
      final inner = FakePagePrinter()..hold = true;
      final printer = BusyPagePrinter(busy, inner);
      const format = PdfPageFormat(100, 200);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final job = printer.print(bytes, 'n', format);
      await Future<void>.delayed(Duration.zero);
      expect(busy.value, isTrue);
      expect(inner.calls.single.name, 'n');
      expect(inner.calls.single.pdf, bytes);
      expect(inner.calls.single.format, format);
      inner.held.single.complete();
      await job;
      expect(busy.value, isFalse);

      inner
        ..hold = false
        ..failNext = StateError('no printer');
      await expectLater(printer.print(bytes, 'n', format), throwsStateError);
      expect(busy.value, isFalse, reason: 'cleared by the finally');

      busy.value = true;
      final before = inner.calls.length;
      await printer.print(bytes, 'n', format);
      expect(inner.calls.length, before, reason: 'nothing printed');
      expect(busy.value, isTrue, reason: 'the other flow\'s');
    });
  });
}
