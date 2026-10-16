// Ported from apps/floor_planner/test/export/export_end_to_end_test.dart
// (audit docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md,
// section "export/export_end_to_end_test.dart"): E2E, PORT. The app with a
// scripted `DocumentFiles` and a fake printer; Open sample from the toolbar;
// Save; Export -> PDF, Export -> PNG at 150 dpi and Print... through the
// toolbar; Save again. The sample's page is A4 landscape at 1:50, off the
// origin, so the sizes below are read off its page, and the premises say it
// is not the identity case. The old app's `session.dirty` is the
// controller's `dirty` now.
import 'package:architecture_demo/document_files.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_fakes.dart';
import '../support/app_rig.dart';
import '../support/export_rig.dart';

void main() {
  testWidgets(
      'E2E Open sample, Save, Export PDF, Export PNG at 150 dpi, Print, '
      'Save: the PDF is the sample\'s page in pt with embedded text, the PNG '
      'the page at 150 dpi, the print the export\'s content, and the second '
      'Save byte-identical to the first', (tester) async {
    final printer = FakePagePrinter();
    final rig = await pumpApp(tester, printer: printer);
    final files = rig.files;
    final c = rig.controller;

    await rig.tapKey('toolbar-open-sample');
    await tester.pump();
    noDialog(tester);
    final doc = c.document;
    expect(doc.entities.liveCount, greaterThanOrEqualTo(500),
        reason: 'premise: the sample is open');
    final page = pageOf(c);
    expect(page, isNotNull, reason: 'premise: the sample has a page');
    expect((page!.effectiveWidthMm, page.effectiveHeightMm), (297.0, 210.0),
        reason: 'premise: A4 landscape');
    expect(page.originX == 0 || page.originY == 0, isFalse,
        reason: 'premise: the sheet is not at the origin');

    // Save before: the sample is untitled, so Save asks where.
    files.scriptSaveLocation(name: 'sample.jetplan', location: '/p/sample');
    await rig.tapKey('toolbar-save');
    await tester.pump();
    noDialog(tester);
    expect(files.writes, hasLength(1), reason: 'premise: saved');
    final before = files.writes.single.bytes;
    expect(rig.session.name, 'sample');

    // Export -> PDF.
    files.scriptSaveLocation(name: 'sample.pdf', location: '/out/sample.pdf');
    await openDialog(tester);
    await tapKey2(tester, 'export-format-plan.pdf');
    await tapKey2(tester, 'export-ok');
    await settleWrites(tester, files, count: 2);
    noDialog(tester);
    expect(files.writes, hasLength(2));
    final pdf = files.writes[1];
    expect((pdf.name, pdf.kind), ('sample.pdf', FileKind.pdf));
    final content = parsePdf(pdf.bytes);
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

    // Export -> PNG at 150 dpi.
    files.scriptSaveLocation(name: 'sample.png', location: '/out/sample.png');
    await openDialog(tester);
    await tapKey2(tester, 'export-format-plan.png');
    await tapKey2(tester, 'export-dpi-150');
    await tapKey2(tester, 'export-ok');
    await settleWrites(tester, files, count: 3);
    noDialog(tester);
    expect(files.writes, hasLength(3));
    final png = files.writes[2];
    expect((png.name, png.kind), ('sample.png', FileKind.png));
    expect(png.bytes.sublist(1, 4), 'PNG'.codeUnits);
    // round(297 / 25.4 * 150) x round(210 / 25.4 * 150).
    expect((pngWidth(png.bytes), pngHeight(png.bytes)), (1754, 1240));
    await tester.pump();

    // Print....
    await tester.tap(printButton);
    await settleUntil(tester, () => printer.calls.isNotEmpty);
    await tester.pump();
    noDialog(tester);
    expect(printer.calls, hasLength(1));
    final call = printer.calls.single;
    expect(call.name, 'sample');
    expect(call.format.width, closeTo(297 * ptPerMm, 1e-9));
    expect(call.format.height, closeTo(210 * ptPerMm, 1e-9));
    final printed = parsePdf(call.pdf);
    expect(operatorsOf(printed), operatorsOf(content),
        reason: 'the print is the export\'s content stream');
    expect(printed.mediaBox, content.mediaBox);
    expect(rig.session.busy.value, isFalse);

    // Save after: the flows read the document and wrote nothing to it.
    expect(identical(c.document, doc), isTrue);
    expect(c.dirty.value, isFalse,
        reason: 'no export or print moved the document off its save point');
    await rig.tapKey('toolbar-save');
    await tester.pump();
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
