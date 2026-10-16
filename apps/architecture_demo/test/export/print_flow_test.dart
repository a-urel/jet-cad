// Ported from apps/floor_planner/test/export/print_flow_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "export/print_flow_test.dart"): PR1, PR3, PR5, PR10 SPLIT, PR6, PR8 PORT,
// PR2, PR4, PR7, PR9 COVERED.
//
// COVERED, checked (each opened and read), in packages/jet_cad_2d_plan/test:
//   PR2  export/registry_test.dart:240 (X-7: the format from the page's
//        effective size in pt); the A3 portrait fixture itself is in
//        jet_cad_2d_flutter's export/export_pdf_test.dart
//   PR4  editor/plan_editor_test.dart:360 (ED-X1); shortcuts/
//        plan_shortcuts_test.dart:308 (KB-6); export/page_flows_test.dart:161
//        (PF3, print answers false)
//   PR7  editor/plan_editor_test.dart:133 (ED-3: export, print in order);
//        editor/editor_words_test.dart:134 (SW1, "Yazdir... (Ctrl+P)")
//   PR9  export/registry_test.dart:260 (X-8)
// Intent halves of the SPLIT rows: X-7, PF3 (name, format in pt, %PDF), PF9
// and PF11 (page_flows_test.dart:324, :388: the error is reported once and
// the guard is free), PF7 (:217, the library's print and export hold each
// other).
//
// Decided: premise impossible (PR1's `fontLoads == 1`): the app injects no
// font cache.
//
// Decided: premise impossible (spec decision 5): the old tests asserted the
// buttons *disabled* while a flow runs; the -open forms assert the callback
// or the printer does nothing while the app is busy. The separator the old PR1
// checked is not in the architecture kit's plan (its omission is I
// `separator/separator_export_test.dart`).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

import '../support/app_fakes.dart';
import '../support/app_rig.dart';
import '../support/export_rig.dart';

void main() {
  group('T-10 Print', () {
    testWidgets(
        'PR1-open the button hands the printer one export: the content '
        'stream of Export -> PDF, the session\'s name, the page in pt',
        (tester) async {
      final printer = FakePagePrinter();
      final rig = await pumpFlat(tester, printer: printer);
      expect(on(tester, 'print'), isTrue);

      await tester.tap(printButton);
      await settleUntil(tester, () => printer.calls.isNotEmpty);
      await tester.pump();
      noDialog(tester);
      expect(printer.calls, hasLength(1), reason: 'printed once');
      final call = printer.calls.single;
      expect(call.name, 'flat');
      expect(call.format.width, closeTo(297 * ptPerMm, 1e-9));
      expect(call.format.height, closeTo(210 * ptPerMm, 1e-9));
      expect(call.pdf.sublist(0, 4), '%PDF'.codeUnits);
      expect(rig.files.saveLocationCalls, isEmpty, reason: 'nothing is saved');
      expect(rig.files.writes, isEmpty);
      expect(rig.session.busy.value, isFalse);

      final printed = parsePdf(call.pdf);
      final reference = await referenceExport(tester, rig.controller);
      expect(operatorsOf(printed), operatorsOf(reference),
          reason: 'the same content stream as an export');
      expect(printed.mediaBox, reference.mediaBox);
      expect(printed.mediaBox[2], closeTo(call.format.width, 1e-3));
      expect(printed.mediaBox[3], closeTo(call.format.height, 1e-3));
      expect([for (final t in printed.textRuns) t.string],
          unorderedEquals(liveTexts(rig.controller)),
          reason: 'the plan\'s labels, in the embedded font');
      expectInsideSheet(printed);
    });

    testWidgets(
        'PR3-open a throwing printer shows the page-flow error dialog '
        '(neutral words, the thrown text); the print job is over, so the app '
        'is not busy meanwhile', (tester) async {
      final printer = FakePagePrinter()
        ..failNext = const FileSystemException('no printer');
      final rig = await pumpFlat(tester, printer: printer);
      await tester.tap(printButton);
      await settleUntil(tester,
          () => find.byKey(const Key('document-error')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('document-error')), findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const Key('document-error-title')))
              .data,
          'The page could not be exported or printed');
      expect(
          tester
              .widget<Text>(find.byKey(const Key('document-error-text')))
              .data,
          contains('no printer'));
      // Decided: the printer's busy span ends when its job throws; the
      // library reports the error after that, and the app shows it unheld
      // (the dialog is modal, the file chords are consumed above it).
      expect(rig.session.busy.value, isFalse);
      await dismissError(tester);
      expect(find.byKey(const Key('document-error')), findsNothing);
      expect(printer.calls, hasLength(1), reason: 'one error, one dialog');
    });
  });

  group('T-10 Print waits', () {
    testWidgets(
        'PR10-open busy while the print dialog is up: Save does nothing, '
        'Print and Export are held by the library, a second Cmd+P prints '
        'nothing; busy ends with the job', (tester) async {
      final printer = FakePagePrinter()..hold = true;
      final rig = await pumpFlat(tester, printer: printer);
      expect([
        on(tester, 'print'),
        on(tester, 'save'),
        on(tester, 'export')
      ], [
        true,
        true,
        true
      ], reason: 'premise: idle');
      await tester.tap(printButton);
      await settleUntil(tester, () => printer.held.isNotEmpty);
      expect(printer.held, hasLength(1), reason: 'premise: the dialog is up');
      // The dialog stays up a while: the flow waits for it, not a timer.
      await tester.pump(const Duration(seconds: 30));
      expect(rig.session.busy.value, isTrue);
      expect(on(tester, 'print'), isFalse, reason: 'the library holds Print');
      expect(on(tester, 'export'), isFalse, reason: 'the library holds Export');
      expect(on(tester, 'save'), isTrue,
          reason: 'the library cannot grey Save (decision 5)');
      await tester.tap(find.byKey(const Key('toolbar-save')));
      await tester.pump();
      await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
      await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(rig.files.saveLocationCalls, isEmpty);
      expect(rig.files.writes, isEmpty);
      expect(printer.calls, hasLength(1), reason: 'no second print');
      printer.held.single.complete();
      await tester.pump();
      await tester.pump();
      expect(rig.session.busy.value, isFalse);
      expect([on(tester, 'print'), on(tester, 'save'), on(tester, 'export')],
          [true, true, true]);
    });
  });

  group('T-10 Print enabled', () {
    testWidgets(
        'PR5-open Print during another flow prints nothing: with a Save As '
        'write held the button and Cmd+P hand the printer no job; after it '
        'ends Print works', (tester) async {
      final printer = FakePagePrinter();
      final rig = await pumpFlat(tester, printer: printer);
      final files = rig.files
        ..holdWrites = true
        ..scriptSaveLocation(name: 'flat.jetplan', location: '/p/f2');
      final saving = rig.host.saveAsStep();
      await tester.pump();
      expect(rig.session.busy.value, isTrue, reason: 'premise: busy');
      expect(on(tester, 'print'), isTrue,
          reason: 'the library cannot grey the button (decision 5)');
      await tester.tap(printButton);
      await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      expect(printer.calls, isEmpty);
      expect(rig.session.busy.value, isTrue, reason: 'still the write\'s');
      files.heldWrites.single.complete();
      await saving;
      await tester.pump();
      expect(rig.session.busy.value, isFalse);
      await tester.tap(printButton);
      await settleUntil(tester, () => printer.calls.isNotEmpty);
      expect(printer.calls, hasLength(1));
    });
  });

  group('T-10 Print chords', () {
    for (final (modifier, label) in [
      (LogicalKeyboardKey.meta, 'Cmd'),
      (LogicalKeyboardKey.control, 'Ctrl'),
    ]) {
      testWidgets('PR6 $label+P prints, once', (tester) async {
        final printer = FakePagePrinter();
        await pumpFlat(tester, printer: printer);
        await chord(tester, modifier, LogicalKeyboardKey.keyP);
        await settleUntil(tester, () => printer.calls.isNotEmpty);
        await tester.pump();
        noDialog(tester);
        expect(printer.calls, hasLength(1));
        expect(printer.calls.single.name, 'flat');
      });
    }
  });

  testWidgets(
      'PR8 the production printer, at printing\'s platform channel: the '
      'name, the page in pt, no dynamic layout, and the given bytes laid out '
      'whatever paper the dialog asks for', (tester) async {
    // printing's method-channel protocol (printing 5.15.1,
    // method_channel.dart): Dart asks `printPdf`, the platform calls back
    // `onLayout` for the bytes and `onCompleted` when the dialog closes.
    const channel = MethodChannel('net.nfet.printing');
    final messenger = tester.binding.defaultBinaryMessenger;
    Map<Object?, Object?>? asked;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'printPdf') {
        asked = call.arguments as Map<Object?, Object?>;
        return 1;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Future<Object?> fromPlatform(String method, Map<String, Object?> args) {
      final reply = Completer<Object?>();
      messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, args)),
          (data) => reply.complete(
              data == null ? null : channel.codec.decodeEnvelope(data)));
      return reply.future;
    }

    final pdf = Uint8List.fromList(List.generate(64, (i) => (i * 37) % 251));
    const format = PdfPageFormat(1190.5, 841.75);
    var done = false;
    final printing = const PrintingPagePrinter()
        .print(pdf, 'flat', format)
        .then((_) => done = true);
    await tester.pump();
    expect(asked, isNotNull, reason: 'the dialog was asked for');
    expect(asked!['name'], 'flat');
    expect(asked!['width'], 1190.5);
    expect(asked!['height'], 841.75);
    expect(asked!['dynamic'], isFalse);
    final job = asked!['job'];
    // The dialog asks for another paper (A4 portrait): the same bytes.
    final laid = await fromPlatform('onLayout', {
      'job': job,
      'width': 595.0,
      'height': 842.0,
      'marginLeft': 0.0,
      'marginTop': 0.0,
      'marginRight': 0.0,
      'marginBottom': 0.0,
    });
    expect(laid, pdf);
    expect(done, isFalse, reason: 'it waits for the dialog');
    await fromPlatform('onCompleted', {'job': job, 'completed': true});
    await printing;
    expect(done, isTrue);
  });
}
