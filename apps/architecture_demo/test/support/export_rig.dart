// The export and print tests' shared moves (ported from the old app's
// test/support/export_flat.dart, on the architecture kit's sample): the app
// pumped over the sample opened as `flat`, the screen's camera turned and
// panned off the sheet, and the readings of a PDF and a PNG.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show PageComponent;
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'app_fakes.dart';
import 'app_rig.dart';

const double ptPerMm = 72 / 25.4;

Finder get exportButton => find.byKey(const Key('toolbar-export'));
Finder get printButton => find.byKey(const Key('toolbar-print'));

/// Whether the toolbar button [id] is enabled, as built.
bool on(WidgetTester tester, String id) =>
    tester.widget<IconButton>(find.byKey(Key('toolbar-$id'))).onPressed != null;

/// The app with the sample opened from `flat.jetplan` (at `/p/flat`): titled
/// `flat`, clean, its page A4 landscape at 1:50 off the origin; the screen's
/// camera turned and panned far off the sheet, so an export that followed
/// the screen would plot something else.
Future<AppRig> pumpFlat(WidgetTester tester,
    {FakeDocumentFiles? files, PagePrinter? printer}) async {
  final rig = await pumpApp(tester, files: files, printer: printer);
  rig.files.scriptOpen(
      name: 'flat.jetplan', bytes: sampleBytes(), location: '/p/flat');
  await rig.host.openFlow();
  await tester.pump();
  expect(rig.session.name, 'flat', reason: 'premise: titled');
  expect(rig.controller.dirty.value, isFalse, reason: 'premise: clean');
  final page = pageOf(rig.controller)!;
  expect((page.effectiveWidthMm, page.effectiveHeightMm), (297.0, 210.0),
      reason: 'premise: A4 landscape');
  expect(page.originX != 0 && page.originY != 0, isTrue,
      reason: 'premise: the sheet is off the origin');
  await aimCamera(tester, rig.controller, kFar);
  return rig;
}

/// Opens the export dialog through the bar's Export button.
Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(exportButton);
  await tester.pump();
  await tester.pump();
  expect(find.byKey(const Key('export-dialog')), findsOneWidget,
      reason: 'premise: the dialog is up');
}

/// Taps the widget keyed [key], then two frames.
Future<void> tapKey2(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump();
}

/// Lets the export's engine work (the bytes, `toImage`, the encoding) run in
/// real time under `runAsync`, with a pump for the fake zone's continuations,
/// until [done] (at most 8 s).
Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// [settleUntil] [count] files are written.
Future<void> settleWrites(WidgetTester tester, FakeDocumentFiles files,
        {int count = 1}) =>
    settleUntil(tester, () => files.writes.length >= count);

int pngWidth(Uint8List png) => ByteData.sublistView(png).getUint32(16);
int pngHeight(Uint8List png) => ByteData.sublistView(png).getUint32(20);

/// The content stream's operators, as written.
List<String> operatorsOf(PdfContent content) =>
    [for (final o in content.operators) o.toString()];

PdfContent parsePdf(Uint8List bytes) =>
    PdfContent.parse(bytes, inflate: zlib.decode);

/// What Export -> PDF of [c]'s plan makes, asked of the library's own
/// command apart from the app's wiring: the content stream to compare the
/// app's written or printed bytes with.
Future<PdfContent> referenceExport(
    WidgetTester tester, PlanController c) async {
  final export = await tester.runAsync(
      () => c.export('plan.pdf', PlanExportChoice.initial, name: 'x'));
  return parsePdf(export!.bytes);
}

/// The page [c]'s plan carries, or null when it has none (the library's
/// `page` notifier is internal).
PageComponent? pageOf(PlanController c) =>
    c.document.components.get<PageComponent>(c.document.rootHandle);
