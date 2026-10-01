// Spec 13 Exit gate, plan 13 Task 11: Export and Print end to end, on the
// sample the app ships. `FloorPlannerApp` with a scripted `DocumentFiles`, a
// fake printer and the vendored Roboto through the injected font cache;
// Open sample from the toolbar; Save; Export → PDF, Export → PNG at 150 dpi
// and Print… through the toolbar; Save again. The sample's page is A4
// landscape at 1:50, centred on the plan (not at the origin), so the sizes
// below are read off its page, and the premises say it is not the identity
// case.
import 'dart:io';
import 'dart:typed_data';

import 'package:floor_planner/document_files.dart';
import 'package:floor_planner/export/export_flow.dart';
import 'package:floor_planner/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';

import '../support/document_rig.dart';
import '../support/export_flat.dart' show fontCache, fontLoads;
import '../support/fake_document_files.dart';
import '../support/fake_page_printer.dart';

const double ptPerMm = 72 / 25.4;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump();
}

/// Lets the PNG flow's engine work (`toImage`, the encoding) finish: real
/// time under `runAsync`, then a pump for the fake zone's continuations.
Future<void> settleWrites(
    WidgetTester tester, FakeDocumentFiles files, int count) async {
  for (var i = 0; i < 400 && files.writes.length < count; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

int pngWidth(Uint8List png) => ByteData.sublistView(png).getUint32(16);
int pngHeight(Uint8List png) => ByteData.sublistView(png).getUint32(20);

List<String> operatorsOf(PdfContent content) =>
    [for (final o in content.operators) o.toString()];

void main() {
  testWidgets(
      'E2E Open sample, Save, Export PDF, Export PNG at 150 dpi, Print, '
      'Save: the PDF is the sample\'s page in pt with embedded text, the PNG '
      'the page at 150 dpi, the print the export\'s content, and the second '
      'Save byte-identical to the first', (tester) async {
    final files = FakeDocumentFiles();
    final printer = FakePagePrinter();
    fontLoads = 0;
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(FloorPlannerApp(
        files: files, exportFont: fontCache(), printer: printer));
    await tester.pump();

    await tapKey(tester, 'toolbar-open-sample');
    noDialog(tester);
    final session = sessionOf(tester);
    final doc = session.document;
    expect(doc.entities.liveCount, greaterThanOrEqualTo(500),
        reason: 'premise: the sample is open');
    final page = exportPageOf(doc);
    expect(page, isNotNull, reason: 'premise: the sample has a page');
    expect(page!.orientation, PageOrientation.landscape,
        reason: 'premise: landscape, so width and height are swapped');
    expect((page.effectiveWidthMm, page.effectiveHeightMm), (297.0, 210.0),
        reason: 'premise: A4 landscape');
    expect(page.originX == 0 || page.originY == 0, isFalse,
        reason: 'premise: the sheet is not at the origin');

    // Save before: the sample is untitled, so Save asks where.
    files.scriptSaveLocation(name: 'sample.jetplan', location: '/p/sample');
    await tapKey(tester, 'toolbar-save');
    noDialog(tester);
    expect(files.writes, hasLength(1), reason: 'premise: saved');
    final before = files.writes.single.bytes;
    expect(session.name, 'sample');

    // Export → PDF.
    files.scriptSaveLocation(name: 'sample.pdf', location: '/out/sample.pdf');
    await tapKey(tester, 'toolbar-export');
    expect(find.byKey(const Key('export-dialog')), findsOneWidget);
    await tapKey(tester, 'export-format-pdf');
    await tapKey(tester, 'export-ok');
    await tester.pump();
    noDialog(tester);
    expect(files.writes, hasLength(2));
    final pdf = files.writes[1];
    expect((pdf.name, pdf.kind), ('sample.pdf', FileKind.pdf));
    final content = PdfContent.parse(pdf.bytes, inflate: zlib.decode);
    expect(content.mediaBox[0], 0);
    expect(content.mediaBox[1], 0);
    expect(content.mediaBox[2], closeTo(297 * ptPerMm, 1e-3));
    expect(content.mediaBox[3], closeTo(210 * ptPerMm, 1e-3));
    expect(content.paths, isNotEmpty);
    expect(content.textRuns, isNotEmpty, reason: 'the sample\'s labels');
    for (final run in content.textRuns) {
      expect(run.fontInfo.subtype, '/Type0');
      expect(run.fontInfo.descendantSubtype, '/CIDFontType2');
      expect(run.fontInfo.fontFile, '/FontFile2',
          reason: 'the font is embedded');
      expect(run.string, isNotNull, reason: 'it maps back to Unicode');
    }
    expect(fontLoads, 1, reason: 'the font came from the app\'s cache');

    // Export → PNG at 150 dpi.
    files.scriptSaveLocation(name: 'sample.png', location: '/out/sample.png');
    await tapKey(tester, 'toolbar-export');
    await tapKey(tester, 'export-format-png');
    await tapKey(tester, 'export-dpi-150');
    await tapKey(tester, 'export-ok');
    await settleWrites(tester, files, 3);
    noDialog(tester);
    expect(files.writes, hasLength(3));
    final png = files.writes[2];
    expect((png.name, png.kind), ('sample.png', FileKind.png));
    expect(png.bytes.sublist(1, 4), 'PNG'.codeUnits);
    // round(297 / 25.4 * 150) x round(210 / 25.4 * 150).
    expect((pngWidth(png.bytes), pngHeight(png.bytes)), (1754, 1240));
    await tester.pump();

    // Print….
    await tapKey(tester, 'toolbar-print');
    await tester.pump();
    noDialog(tester);
    expect(printer.calls, hasLength(1));
    final call = printer.calls.single;
    expect(call.name, 'sample');
    expect(call.format.width, closeTo(297 * ptPerMm, 1e-9));
    expect(call.format.height, closeTo(210 * ptPerMm, 1e-9));
    final printed = PdfContent.parse(call.pdf, inflate: zlib.decode);
    expect(operatorsOf(printed), operatorsOf(content),
        reason: 'the print is the export\'s content stream');
    expect(printed.mediaBox, content.mediaBox);
    expect(session.busy.value, isFalse);

    // Save after: the flows read the document and wrote nothing to it.
    expect(identical(sessionOf(tester).document, doc), isTrue);
    expect(session.dirty.value, isFalse,
        reason: 'no export or print moved the document off its save point');
    await tapKey(tester, 'toolbar-save');
    noDialog(tester);
    expect(files.writes, hasLength(4));
    final after = files.writes[3];
    expect((after.location, after.kind), ('/p/sample', FileKind.jetplan),
        reason: 'premise: saved in place');
    expect(after.bytes, before,
        reason: 'Save after the exports is byte-identical to Save before');
    expect(files.unscriptedCalls, 0);
  });
}
