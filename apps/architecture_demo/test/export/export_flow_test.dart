// Ported from apps/floor_planner/test/export/export_flow_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "export/export_flow_test.dart"): EX1, EX3, EX5, EX10, EX13, EX14 SPLIT
// (the -open half is what the app does now; the intent half is the library's,
// cited), EX6-EX8, EX9b, EX12 PORT, EX2, EX2b, EX4, EX9, EX11 COVERED.
//
// COVERED, checked (each opened and read):
//   EX2   packages/jet_cad_2d_plan/test/export/registry_test.dart:115 (X-4)
//   EX2b  registry_test.dart:260 (X-8); page_flows_test.dart:849 (PF17)
//   EX4   page_flows_test.dart:479 (PF14), :627 (PF21);
//         plan_export_types_test.dart:8 (X-1)
//   EX9   editor/plan_editor_test.dart:360 (ED-X1);
//         shortcuts/plan_shortcuts_test.dart:308 (KB-6);
//         export/page_flows_test.dart:161 (PF3)
//   EX11  editor/editor_bar_test.dart:385 (PF5), :402 (PF6)
// Intent halves of the SPLIT rows: PF13 (page_flows_test.dart:441: PDF magic,
// MediaBox and PNG pixels per choice), PF12 (:414, a null answer exports
// nothing), PF7 (:217, the library's flows hold Print and Export), PF2 (:143,
// `<name>.png`), X-1 (the initial choice), EF4 (export/export_font_test.dart:
// 38, the default font).
//
// Decided: premise impossible (spec decision 5): the old tests asserted the
// buttons *disabled* while a flow runs. `PlanEditor` has no host hook to grey
// them, so the -open forms assert that the callback or the dialog does
// nothing while the app is busy. EX14's bare host is gone: the app has no
// font injection; the name is the session's (`exportName`, decision 8).
import 'dart:io';
import 'dart:typed_data';

import 'package:architecture_demo/document_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show PageComponent, SetComponentCommand;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/app_fakes.dart';
import '../support/app_rig.dart';
import '../support/export_rig.dart';

void main() {
  group('T-10 Export -> PDF', () {
    testWidgets(
        'EX1-open Export -> PDF asks where for flat.pdf (kind pdf) and writes '
        'the library\'s bytes there: the page\'s MediaBox, its content stream '
        'the export command\'s, not what the turned screen shows',
        (tester) async {
      final rig = await pumpFlat(tester);
      final files = rig.files
        ..scriptSaveLocation(name: 'flat.pdf', location: '/out/flat.pdf');
      await openDialog(tester);
      await tapKey2(tester, 'export-ok');
      await settleWrites(tester, files);
      noDialog(tester);
      expect(files.saveLocationCalls, ['flat.pdf']);
      expect(files.saveLocationKinds, [FileKind.pdf]);
      expect(files.writes, hasLength(1));
      final w = files.writes.single;
      expect((w.name, w.location, w.kind),
          ('flat.pdf', '/out/flat.pdf', FileKind.pdf));
      expect(w.bytes.sublist(0, 4), '%PDF'.codeUnits);
      final content = parsePdf(w.bytes);
      expect(content.mediaBox[2], closeTo(297 * ptPerMm, 1e-3));
      expect(content.mediaBox[3], closeTo(210 * ptPerMm, 1e-3));
      expect(content.textRuns, isNotEmpty, reason: 'the sample\'s labels');
      final reference = await referenceExport(tester, rig.controller);
      expect(operatorsOf(content), operatorsOf(reference),
          reason: 'the bytes are the export command\'s');
      expect(content.paths, isNotEmpty);
      expect(rig.session.busy.value, isFalse);
      expect(rig.controller.dirty.value, isFalse,
          reason: 'an export leaves the document at its save point');
    });

    testWidgets(
        'EX3-open Export -> PNG at 300 dpi writes flat.png (kind png) of the '
        'page\'s size', (tester) async {
      final rig = await pumpFlat(tester);
      final files = rig.files
        ..scriptSaveLocation(name: 'flat.png', location: '/out/flat.png');
      await openDialog(tester);
      await tapKey2(tester, 'export-format-plan.png');
      await tapKey2(tester, 'export-dpi-300');
      await tapKey2(tester, 'export-ok');
      await settleWrites(tester, files);
      noDialog(tester);
      expect(files.saveLocationCalls, ['flat.png']);
      expect(files.saveLocationKinds, [FileKind.png]);
      final w = files.writes.single;
      expect((w.name, w.location, w.kind),
          ('flat.png', '/out/flat.png', FileKind.png));
      expect(w.bytes.sublist(1, 4), 'PNG'.codeUnits);
      final page = pageOf(rig.controller)!;
      expect((
        pngWidth(w.bytes),
        pngHeight(w.bytes)
      ), (
        (page.effectiveWidthMm / 25.4 * 300).round(),
        (page.effectiveHeightMm / 25.4 * 300).round()
      ));
      expect((pngWidth(w.bytes), pngHeight(w.bytes)), (3508, 2480),
          reason: 'A4 landscape at 300 dpi, computed by hand');
      await tester.pump();
      expect(rig.session.busy.value, isFalse);
    });
  });

  group('T-10 cancel and failure', () {
    testWidgets(
        'EX5-open the app is busy while the dialog is up; Cancel asks '
        'nothing and writes nothing', (tester) async {
      final rig = await pumpFlat(tester);
      await openDialog(tester);
      expect(rig.session.busy.value, isTrue,
          reason: 'busy over the dialog (an exit request is cancelled '
              'meanwhile)');
      await tapKey2(tester, 'export-cancel');
      expect(find.byKey(const Key('export-dialog')), findsNothing);
      expect(rig.files.saveLocationCalls, isEmpty);
      expect(rig.files.writes, isEmpty);
      expect(rig.files.unscriptedCalls, 0);
      expect(rig.session.busy.value, isFalse);
    });

    testWidgets('EX6 Escape cancels the dialog', (tester) async {
      final rig = await pumpFlat(tester);
      await openDialog(tester);
      await press(tester, LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const Key('export-dialog')), findsNothing);
      expect(rig.files.saveLocationCalls, isEmpty);
      expect(rig.files.writes, isEmpty);
      expect(rig.session.busy.value, isFalse);
    });

    testWidgets('EX7 a cancelled save writes nothing', (tester) async {
      final rig = await pumpFlat(tester);
      rig.files.scriptSaveCancel();
      await openDialog(tester);
      await tapKey2(tester, 'export-ok');
      await settleUntil(tester, () => rig.files.saveLocationCalls.isNotEmpty);
      await tester.pump();
      expect(rig.files.saveLocationCalls, ['flat.pdf']);
      expect(rig.files.writes, isEmpty);
      noDialog(tester);
      expect(rig.session.busy.value, isFalse);
    });

    testWidgets('EX8 a throwing write shows "Export failed"', (tester) async {
      final rig = await pumpFlat(tester);
      rig.files
        ..scriptSaveLocation(name: 'flat.pdf', location: '/out/flat.pdf')
        ..failNextWrite(const FileSystemException('disk full'));
      await openDialog(tester);
      await tapKey2(tester, 'export-ok');
      await settleUntil(tester,
          () => find.byKey(const Key('document-error')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('document-error')), findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const Key('document-error-title')))
              .data,
          'Export failed');
      expect(
          tester
              .widget<Text>(find.byKey(const Key('document-error-text')))
              .data,
          contains('disk full'));
      expect(rig.session.busy.value, isTrue,
          reason: 'busy while the error is up');
      await dismissError(tester);
      expect(rig.session.busy.value, isFalse);
      expect(rig.files.writes, hasLength(1), reason: 'the attempt');
    });

    testWidgets(
        'EX8b a save panel that throws shows "Export failed" and writes '
        'nothing', (tester) async {
      final rig = await pumpFlat(tester);
      rig.files.scriptSaveLocationThrow(const FileSystemException('no panel'));
      await openDialog(tester);
      await tapKey2(tester, 'export-ok');
      await settleUntil(tester,
          () => find.byKey(const Key('document-error')).evaluate().isNotEmpty);
      expect(
          tester
              .widget<Text>(find.byKey(const Key('document-error-title')))
              .data,
          'Export failed');
      expect(rig.files.writes, isEmpty);
      await dismissError(tester);
      expect(rig.session.busy.value, isFalse);
    });

    testWidgets(
        'EX13-open the file kind comes from the export\'s extension: a name '
        'the library does not make (.svg, none) is an error shown as '
        '"Export failed", nothing asked and nothing written', (tester) async {
      final rig = await pumpFlat(tester);
      for (final name in ['flat.svg', 'flat']) {
        final flow = rig.host.exportFlow(
            PlanExport(bytes: Uint8List(3), name: name, mimeType: 'image/svg'));
        await tester.pump();
        expect(
            tester
                .widget<Text>(find.byKey(const Key('document-error-title')))
                .data,
            'Export failed');
        expect(
            tester
                .widget<Text>(find.byKey(const Key('document-error-text')))
                .data,
            contains(name));
        await dismissError(tester);
        await flow;
        expect(rig.session.busy.value, isFalse);
      }
      expect(rig.files.saveLocationCalls, isEmpty);
      expect(rig.files.writes, isEmpty);
    });
  });

  group('T-10 enabled', () {
    testWidgets(
        'EX9b Export and Print follow the page: removed, undone, redone '
        '(the bar\'s flags listen to the plan\'s page)', (tester) async {
      final rig = await pumpFlat(tester);
      final c = rig.controller;
      final root = c.document.rootHandle;
      bool both() => on(tester, 'export') && on(tester, 'print');
      bool neither() => !on(tester, 'export') && !on(tester, 'print');
      Future<void> settle() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
      }

      expect(both(), isTrue, reason: 'premise: a page');
      c.document.commands
          .execute(SetComponentCommand<PageComponent>(root, null));
      await settle();
      expect(pageOf(c), isNull, reason: 'premise: removed');
      expect(neither(), isTrue, reason: 'removed');
      c.document.commands.undo();
      await settle();
      expect(pageOf(c), isNotNull, reason: 'premise: undone');
      expect(both(), isTrue, reason: 'attached again by the undo');
      c.document.commands.redo();
      await settle();
      expect(pageOf(c), isNull, reason: 'premise: redone');
      expect(neither(), isTrue, reason: 'redone');
    });

    testWidgets(
        'EX10-open Export during another flow does nothing: with a Save As '
        'write held (the app busy), the button and Cmd+E open no dialog; '
        'after it ends they do', (tester) async {
      final rig = await pumpFlat(tester);
      final files = rig.files
        ..holdWrites = true
        ..scriptSaveLocation(name: 'flat.jetplan', location: '/p/f2');
      final saving = rig.host.saveAsStep();
      await tester.pump();
      expect(files.heldWrites, hasLength(1), reason: 'premise: held');
      expect(rig.session.busy.value, isTrue, reason: 'premise: busy');
      expect(on(tester, 'export'), isTrue,
          reason: 'the library cannot grey the button (decision 5)');
      await tester.tap(exportButton);
      await tester.pump();
      await tester.pump();
      await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyE);
      await tester.pump();
      expect(find.byKey(const Key('export-dialog')), findsNothing);
      expect(rig.session.busy.value, isTrue, reason: 'still the write\'s');
      expect(files.heldWrites, hasLength(1));
      files.heldWrites.single.complete();
      await saving;
      await tester.pump();
      expect(rig.session.busy.value, isFalse);
      await openDialog(tester);
      await tapKey2(tester, 'export-cancel');
    });
  });

  group('T-10 chords', () {
    for (final (modifier, label) in [
      (LogicalKeyboardKey.meta, 'Cmd'),
      (LogicalKeyboardKey.control, 'Ctrl'),
    ]) {
      testWidgets(
          'EX12 with the dialog open, $label+P and $label+E are consumed: '
          'nothing runs, no second dialog, no print', (tester) async {
        final printer = FakePagePrinter();
        final rig = await pumpFlat(tester, printer: printer);
        await openDialog(tester);
        for (final key in [LogicalKeyboardKey.keyP, LogicalKeyboardKey.keyE]) {
          await chord(tester, modifier, key);
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('export-dialog')), findsOneWidget);
        expect(printer.calls, isEmpty);
        expect(rig.files.saveLocationCalls, isEmpty);
        expect(rig.files.writes, isEmpty);
        await tapKey2(tester, 'export-cancel');
        expect(find.byKey(const Key('export-dialog')), findsNothing);
        expect(printer.calls, isEmpty, reason: 'nothing queued behind it');
      });
    }
  });

  group('the flow\'s parts', () {
    testWidgets(
        'EX14-open a bare app exports a PDF named after the session '
        '(Untitled.pdf) in the library\'s default font', (tester) async {
      final rig = await pumpApp(tester);
      expect(rig.session.name, 'Untitled', reason: 'premise: untitled');
      rig.files.scriptSaveLocation(name: 'Untitled.pdf', location: '/out/u');
      await openDialog(tester);
      await tapKey2(tester, 'export-ok');
      await settleWrites(tester, rig.files);
      expect(rig.files.saveLocationCalls, ['Untitled.pdf']);
      expect(rig.files.writes.single.kind, FileKind.pdf);
      expect(rig.files.writes.single.bytes.sublist(0, 4), '%PDF'.codeUnits);
    });
  });
}
