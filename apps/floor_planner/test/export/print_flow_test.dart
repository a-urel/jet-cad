// Spec 13 D9, T-10 (the print half), plan 13 Task 10: Print… through the
// app. The app is pumped with a fake printer over Task 9's flat (A4
// landscape at 1:50 off the origin, a real separator, a rotated, mirrored
// instance with overrides, a label), the screen's camera at 400 % and
// panned off the sheet. The printer must receive one export's bytes: their
// content stream equals an `exportPagePdf` of the same document with the
// separators omitted and the same font (the files themselves differ in
// `/ID`, spec R-1), with the document's name and the page's size in pt.
import 'dart:io';

import 'package:floor_planner/export/export_flow.dart';
import 'package:floor_planner/parametric/live_objects.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'package:floor_planner/shell_commands.dart';

import '../support/document_rig.dart';
import '../support/export_flat.dart';
import '../support/fake_document_files.dart';
import '../support/fake_page_printer.dart';
import '../support/room_fixture.dart' show kids, worldPoints;

const double ptPerMm = 72 / 25.4;

Finder get printButton => find.byKey(const Key('toolbar-print'));

bool printEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(printButton).onPressed != null;

/// The content stream's operators, as written.
List<String> operatorsOf(PdfContent content) =>
    [for (final o in content.operators) o.toString()];

/// What an Export → PDF of the open document makes, computed here, not by
/// the app's helpers: `exportPagePdf` of the document's page with every
/// live separator omitted (or [omitOwners]) and the vendored font.
Future<PdfContent> referenceExport(WidgetTester tester,
    {Set<Handle>? omitOwners}) async {
  final doc = sessionOf(tester).document;
  final bytes = await exportPagePdf(
      document: doc,
      page: doc.components.get<PageComponent>(doc.rootHandle)!,
      fontBytes: File(vendoredFont).readAsBytesSync(),
      omitOwners: omitOwners ?? liveObjectsOf<SeparatorParams>(doc).toSet());
  return PdfContent.parse(bytes, inflate: zlib.decode);
}

void main() {
  group('T-10 Print', () {
    testWidgets(
        'PR1 the button hands the printer one export: the content stream of '
        'Export → PDF, the name, A4 landscape in pt; no separator',
        (tester) async {
      final files = FakeDocumentFiles();
      final printer = FakePagePrinter();
      await pumpFlat(tester, files, printer: printer);
      expect(printEnabled(tester), isTrue);

      await tester.tap(printButton);
      await tester.pump();
      await tester.pump();
      noDialog(tester);
      expect(printer.calls, hasLength(1), reason: 'printed once');
      final call = printer.calls.single;
      expect(call.name, 'flat');
      expect(call.format.width, closeTo(297 * ptPerMm, 1e-9));
      expect(call.format.height, closeTo(210 * ptPerMm, 1e-9));
      expect(fontLoads, 1, reason: 'the font came from the app\'s cache');
      expect(files.saveLocationCalls, isEmpty, reason: 'nothing is saved');
      expect(files.writes, isEmpty);
      expect(sessionOf(tester).busy.value, isFalse);

      final printed = PdfContent.parse(call.pdf, inflate: zlib.decode);
      final reference = await referenceExport(tester);
      expect(operatorsOf(printed), operatorsOf(reference),
          reason: 'the same content stream as an export');
      expect(printed.mediaBox, reference.mediaBox);
      expect(printed.mediaBox[2], closeTo(call.format.width, 1e-3));
      expect(printed.mediaBox[3], closeTo(call.format.height, 1e-3));
      expect([for (final t in printed.textRuns) t.string], [labelText],
          reason: 'premise: the label, in the embedded font');

      // The separator plots in an export that does not omit it, so the
      // equality above says the print omits it.
      final unomitted = await referenceExport(tester, omitOwners: const {});
      expect(operatorsOf(unomitted), isNot(operatorsOf(reference)),
          reason: 'premise: omitting the separator changes the stream');
      final doc = sessionOf(tester).document;
      final sepLeaf =
          kids(doc, liveObjectsOf<SeparatorParams>(doc).single).single;
      final sepWorld = worldPoints(doc, sepLeaf);
      final a = toPdf(sepWorld[0]), b = toPdf(sepWorld[1]);
      bool onSeparator(PdfContent c) => [
            for (final p in c.paths)
              for (final s in p.subpaths)
                for (final v in s.vertices)
                  if (pdfDistanceToSegment(v, a, b) < 1.0) v,
          ].isNotEmpty;
      expect(onSeparator(unomitted), isTrue,
          reason: 'premise: the separator\'s path where the check looks');
      expect(onSeparator(printed), isFalse, reason: 'no path at the separator');
    });

    testWidgets(
        'PR2 an A3 portrait page: the format is 297 x 420 mm in pt, and the '
        'printed MediaBox agrees', (tester) async {
      final printer = FakePagePrinter();
      await pumpFlat(tester, FakeDocumentFiles(),
          printer: printer,
          bytes: fixtureBytes(
              page: PageComponent(
                  widthMm: 297,
                  heightMm: 420,
                  orientation: PageOrientation.portrait,
                  scaleDenominator: scaleDen,
                  originX: originX,
                  originY: originY,
                  background: 0xFF303030)));
      await hostOf(tester).printFlow();
      await tester.pump();
      final call = printer.calls.single;
      expect(call.format.width, closeTo(297 * ptPerMm, 1e-9));
      expect(call.format.height, closeTo(420 * ptPerMm, 1e-9));
      final printed = PdfContent.parse(call.pdf, inflate: zlib.decode);
      expect(printed.mediaBox[2], closeTo(297 * ptPerMm, 1e-3));
      expect(printed.mediaBox[3], closeTo(420 * ptPerMm, 1e-3));
      expect(operatorsOf(printed), operatorsOf(await referenceExport(tester)));
    });

    testWidgets('PR3 a throwing printer shows "Print failed"', (tester) async {
      final printer = FakePagePrinter()
        ..failNext = const FileSystemException('no printer');
      await pumpFlat(tester, FakeDocumentFiles(), printer: printer);
      await tester.tap(printButton);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('document-error')), findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const Key('document-error-title')))
              .data,
          'Print failed');
      expect(
          tester
              .widget<Text>(find.byKey(const Key('document-error-text')))
              .data,
          contains('no printer'));
      expect(sessionOf(tester).busy.value, isTrue,
          reason: 'busy while the error is up');
      await dismissError(tester);
      expect(sessionOf(tester).busy.value, isFalse);
      expect(printer.calls, hasLength(1));
    });
  });

  group('T-10 Print enabled', () {
    testWidgets(
        'PR4 disabled with no page: the button, the chord, and the flow '
        'itself prints nothing', (tester) async {
      final printer = FakePagePrinter();
      await pumpFlat(tester, FakeDocumentFiles(),
          printer: printer, bytes: pagelessBytes());
      expect(exportPageOf(sessionOf(tester).document), isNull,
          reason: 'premise: no page');
      expect(printEnabled(tester), isFalse);
      expect(
          tester
              .widget<IconButton>(find.byKey(const Key('toolbar-save')))
              .onPressed,
          isNotNull,
          reason: 'premise: idle');
      await chordHandled(
          tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(printer.calls, isEmpty);
      await hostOf(tester).printFlow();
      await tester.pump();
      noDialog(tester);
      expect(printer.calls, isEmpty);
    });

    testWidgets('PR5 enabled with a page; disabled while a flow runs',
        (tester) async {
      final files = FakeDocumentFiles();
      final printer = FakePagePrinter();
      await pumpFlat(tester, files, printer: printer);
      expect(printEnabled(tester), isTrue);
      files
        ..holdWrites = true
        ..scriptSaveLocation(name: 'flat.jetplan', location: '/p/f2');
      final saving = hostOf(tester).saveAsStep();
      await tester.pump();
      expect(sessionOf(tester).busy.value, isTrue, reason: 'premise: busy');
      expect(printEnabled(tester), isFalse);
      await chordHandled(
          tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(printer.calls, isEmpty);
      files.heldWrites.single.complete();
      await saving;
      await tester.pump();
      expect(printEnabled(tester), isTrue);
    });
  });

  testWidgets(
      'PR7 Print… follows Export… in the file commands and the toolbar, '
      'with its icon and chords', (tester) async {
    await pumpFlat(tester, FakeDocumentFiles(), printer: FakePagePrinter());
    final commands = hostOf(tester).fileCommands;
    expect([for (final c in commands) c.id].sublist(commands.length - 2),
        ['export', 'print']);
    final print = commands.last;
    expect(print.label, 'Print…');
    expect(print.icon, Icons.print_outlined);
    expect(print.shortcuts, kPrintChords);
    expect(
        tester.getRect(printButton).left,
        greaterThan(
            tester.getRect(find.byKey(const Key('toolbar-export'))).left));
  });

  group('T-10 Print chords', () {
    for (final (modifier, label) in [
      (LogicalKeyboardKey.metaLeft, 'Cmd'),
      (LogicalKeyboardKey.controlLeft, 'Ctrl'),
    ]) {
      testWidgets('PR6 $label+P prints, once', (tester) async {
        final printer = FakePagePrinter();
        await pumpFlat(tester, FakeDocumentFiles(), printer: printer);
        expect(await chordHandled(tester, modifier, LogicalKeyboardKey.keyP),
            isTrue);
        await tester.pump();
        noDialog(tester);
        expect(printer.calls, hasLength(1));
        expect(printer.calls.single.name, 'flat');
      });
    }
  });
}
