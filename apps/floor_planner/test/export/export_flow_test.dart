// Spec 13 D8, T-10 (the export half), plan 13 Task 9: Export… through the
// app. The app is pumped with a scripted `DocumentFiles` over a document
// whose page is A4 landscape at 1:50 off the origin, with a real separator
// and a rotated, mirrored instance with colour and lineweight overrides;
// the screen's camera is at 400 % and panned off the sheet, so an export
// that followed the screen would put nothing where the page does. The PDF
// is read back with the render package's reader; the PNG flows run under
// `tester.runAsync` (Picture.toImage).
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:floor_planner/document_files.dart';
import 'package:floor_planner/document_host.dart';
import 'package:floor_planner/export/export_dialog.dart';
import 'package:floor_planner/export/export_flow.dart';
import 'package:floor_planner/export/export_font.dart';
import 'package:floor_planner/main.dart';
import 'package:floor_planner/new_document.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/live_objects.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/document_rig.dart';
import '../support/fake_document_files.dart';
import '../support/fake_exit_guard.dart';
import '../support/room_fixture.dart'
    show addSeparator, attachPage, kids, kindOf, recordOf, worldPoints;

const String vendoredFont =
    '../../packages/jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf';

/// The page: A4 landscape at 1:50, its lower-left corner at (3000, -1500),
/// a dark background.
const double originX = 3000, originY = -1500, scaleDen = 50;

/// The instance: translation, 30 degrees, scale (1.5, -0.75); red, 0.70 mm.
final Transform2 instanceTransform = Transform2.translation(7000, 5600)
    .multiply(Transform2.rotation(math.pi / 6))
    .multiply(Transform2.scale(1.5, -0.75));

/// The instance's line, in its definition's frame.
final Vector2 instanceLineStart = Vector2(200, 100);

/// The separator's ends in world, in a turned group of its own.
final Vector2 sepStart = Vector2(9000, 5000), sepEnd = Vector2(11500, 5300);

/// A label on the sheet, so the PDF embeds the font.
const String labelText = 'Yatak Odası';

/// The flat's file: the document above, saved by the codec.
Uint8List fixtureBytes() {
  final doc = prepareDocument(const InsertionPointMeasurer());
  final system = installParametric(doc);
  attachPage(
      doc,
      PageComponent(
          orientation: PageOrientation.landscape,
          scaleDenominator: scaleDen,
          originX: originX,
          originY: originY,
          background: 0xFF303030));
  addSeparator(doc, sepStart, sepEnd,
      at: Transform2.translation(400, -250).multiply(Transform2.rotation(0.1)));
  final definition = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
      handle: definition,
      name: 'export-flow-symbol',
      basePoint: Vector2(120, 45),
      children: const []));
  _leaf(doc, definition, [
    instanceLineStart.x,
    instanceLineStart.y,
    1000,
    400,
  ]);
  _leaf(doc, definition, [300, 600, 900, 700], kind: EntityKind.line);
  doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      transform: instanceTransform,
      definition: definition,
      layer: ReservedHandles.layerZero,
      color: const TrueColor(0xFF0000),
      lineweight: 70)));
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x37474F),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: labelText,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: packTextAttrs(),
    ),
    payload: textPayload(Vector2(4500, 3500), 250),
  ));
  final bytes = bytesOf(doc);
  system.dispose();
  doc.dispose();
  return Uint8List.fromList(bytes);
}

/// A document with no page.
Uint8List pagelessBytes() {
  final doc = prepareDocument(const InsertionPointMeasurer());
  _leaf(doc, doc.rootHandle, [4000, 500, 9000, 2500],
      color: const TrueColor(0x1565C0));
  final bytes = bytesOf(doc);
  doc.dispose();
  return Uint8List.fromList(bytes);
}

Handle _leaf(DraftDocument doc, Handle owner, List<double> coords,
    {EntityKind kind = EntityKind.line,
    DraftColor color = const ByBlockColor(),
    int? lineweight}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: color,
      lineweight: lineweight ?? (owner == doc.rootHandle ? 35 : kByBlock),
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
  return handle;
}

/// The font cache the app is given: the vendored file, read by `File`.
ExportFontCache fontCache() => ExportFontCache(load: () async {
      fontLoads++;
      return File(vendoredFont).readAsBytesSync();
    });

/// How many times a [fontCache] read the file.
int fontLoads = 0;

/// The app over [files] with [fontCache], at 1440 x 900; the flat opened
/// (named `flat`) unless [bytes] says otherwise; the camera at 400 % and
/// panned far off the sheet.
Future<void> pumpFlat(WidgetTester tester, FakeDocumentFiles files,
    {Uint8List? bytes}) async {
  fontLoads = 0;
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester
      .pumpWidget(FloorPlannerApp(files: files, exportFont: fontCache()));
  await tester.pump();
  files.scriptOpen(
      name: 'flat.jetplan', bytes: bytes ?? fixtureBytes(), location: '/p/f');
  await hostOf(tester).openFlow();
  await tester.pump();
  await tester.pump();
  final page = exportPageOf(sessionOf(tester).document);
  if (page == null) return;
  // 400 %: 4 x the sheet at physical size on a 96-dpi screen (spec 04 D4).
  final s = 4 * kLogicalPixelsPerMm / page.scaleDenominator;
  viewOf(tester).camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(700, 450)
          .multiply(Transform2.scale(s, -s))
          .multiply(Transform2.translation(60000, -90000)));
  await tester.pump();
  expect(tester.widget<Text>(find.byKey(const Key('zoom-text'))).data,
      '1:50 · 400%',
      reason: 'premise: the screen is at 400 %');
}

Finder get exportButton => find.byKey(const Key('toolbar-export'));

bool exportEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(exportButton).onPressed != null;

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(exportButton);
  await tester.pump();
  await tester.pump();
  expect(find.byKey(const Key('export-dialog')), findsOneWidget,
      reason: 'premise: the dialog is up');
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump();
}

/// Lets the PNG flow's engine work (`toImage`, the encoding) finish: real
/// time under `runAsync`, then a pump for the fake zone's continuations.
Future<void> settleWrites(WidgetTester tester, FakeDocumentFiles files) async {
  for (var i = 0; i < 400 && files.writes.isEmpty; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// Presses [key] with [modifier]; whether the key-down was handled.
Future<bool> chordHandled(WidgetTester tester, LogicalKeyboardKey modifier,
    LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(modifier);
  final handled = await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
  return handled;
}

/// World [p] in the PDF's page space (pt, y up from the sheet's bottom).
Vector2 toPdf(Vector2 p) {
  const k = 72 / 25.4 / scaleDen;
  return Vector2((p.x - originX) * k, (p.y - originY) * k);
}

double distanceToSegment(PdfXY p, Vector2 a, Vector2 b) {
  final ab = b - a;
  final t =
      (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / ab.length2).clamp(0.0, 1.0);
  final q = a + ab * t;
  return math.sqrt(math.pow(p.x - q.x, 2) + math.pow(p.y - q.y, 2));
}

int pngWidth(Uint8List png) => ByteData.sublistView(png).getUint32(16);
int pngHeight(Uint8List png) => ByteData.sublistView(png).getUint32(20);

void main() {
  group('T-10 Export → PDF', () {
    testWidgets(
        'EX1 writes flat.pdf, kind pdf: MediaBox A4 landscape, the '
        'instance\'s first point where the page puts it (not the screen), its '
        'overrides, no path at the separator', (tester) async {
      final files = FakeDocumentFiles();
      await pumpFlat(tester, files);
      final doc = sessionOf(tester).document;
      final separators = liveObjectsOf<SeparatorParams>(doc);
      expect(separators, hasLength(1), reason: 'premise: a real separator');
      final sepLeaf = kids(doc, separators.single).single;
      expect(kindOf(doc, sepLeaf), EntityKind.polyline,
          reason: 'premise: its generated polyline');
      expect(recordOf(doc, sepLeaf).linetype, ReservedHandles.dashedLinetype,
          reason: 'premise: dashed');
      final sepWorld = worldPoints(doc, sepLeaf);
      expect(sepWorld, hasLength(2), reason: 'premise: one segment');

      files.scriptSaveLocation(name: 'flat.pdf', location: '/out/flat.pdf');
      await openDialog(tester);
      await tapKey(tester, 'export-ok');
      await tester.pump();
      noDialog(tester);
      expect(files.saveLocationCalls, ['flat.pdf']);
      expect(files.saveLocationKinds, [FileKind.pdf]);
      expect(files.writes, hasLength(1));
      final w = files.writes.single;
      expect(w.name, 'flat.pdf');
      expect(w.location, '/out/flat.pdf');
      expect(w.kind, FileKind.pdf);

      expect(fontLoads, 1, reason: 'the font came from the app\'s cache');
      final content = PdfContent.parse(w.bytes, inflate: zlib.decode);
      expect([for (final t in content.textRuns) t.string], [labelText],
          reason: 'the label, in the embedded font');
      expect(content.mediaBox[2], closeTo(297 * 72 / 25.4, 1e-3));
      expect(content.mediaBox[3], closeTo(210 * 72 / 25.4, 1e-3));

      final start = toPdf(instanceTransform.transformPoint(instanceLineStart));
      final atStart = [
        for (final p in content.paths)
          if (p.strokes &&
              (p.subpaths.first.start.x - start.x).abs() < 1e-2 &&
              (p.subpaths.first.start.y - start.y).abs() < 1e-2)
            p,
      ];
      expect(atStart, hasLength(1),
          reason: 'the instance\'s line starts at (${start.x}, ${start.y})');
      expect(atStart.single.state.strokeRgb, [1, 0, 0],
          reason: 'the instance\'s colour override');
      expect(atStart.single.deviceLineWidth, closeTo(0.70 * 72 / 25.4, 1e-3),
          reason: 'its lineweight override, in pt');

      final a = toPdf(sepWorld[0]), b = toPdf(sepWorld[1]);
      final onSeparator = [
        for (final p in content.paths)
          for (final s in p.subpaths)
            for (final v in s.vertices)
              if (distanceToSegment(v, a, b) < 1.0) v,
      ];
      expect(onSeparator, isEmpty, reason: 'no path at the separator');
      expect(content.paths, isNotEmpty);
    });

    testWidgets(
        'EX2 an edit after an export reaches the screen\'s index (spec I-3, '
        'R-13-17: the export leaves the index\'s hooks as it found them)',
        (tester) async {
      final files = FakeDocumentFiles();
      await pumpFlat(tester, files);
      files.scriptSaveLocation(name: 'flat.pdf', location: '/out/flat.pdf');
      await openDialog(tester);
      await tapKey(tester, 'export-ok');
      await tester.pump();
      expect(files.writes, hasLength(1), reason: 'premise: exported');

      final doc = sessionOf(tester).document;
      final added = _leaf(doc, doc.rootHandle, [-20000, -21000, -19000, -20500],
          color: const TrueColor(0x00AA00));
      await tester.pump();
      final found = <Handle>[];
      viewOf(tester).index.forEachInRect(
          const Aabb2.raw(-20100, -21100, -18900, -20400),
          const QueryFilter.all(),
          (slot) => found.add(doc.entities.handleAt(slot)));
      expect(found, [added]);
    });
  });

  group('T-10 Export → PNG', () {
    testWidgets('EX3 at 300 dpi writes flat.png, kind png, of A4\'s size',
        (tester) async {
      final files = FakeDocumentFiles();
      await pumpFlat(tester, files);
      files.scriptSaveLocation(name: 'flat.png', location: '/out/flat.png');
      await openDialog(tester);
      await tapKey(tester, 'export-format-png');
      await tapKey(tester, 'export-dpi-300');
      await tapKey(tester, 'export-ok');
      await settleWrites(tester, files);
      noDialog(tester);
      expect(files.saveLocationCalls, ['flat.png']);
      expect(files.saveLocationKinds, [FileKind.png]);
      final w = files.writes.single;
      expect(w.name, 'flat.png');
      expect(w.kind, FileKind.png);
      expect(w.bytes.sublist(1, 4), 'PNG'.codeUnits);
      expect((pngWidth(w.bytes), pngHeight(w.bytes)), (3508, 2480));
      await tester.pump();
      expect(sessionOf(tester).busy.value, isFalse);
    });

    testWidgets(
        'EX4 the dialog opens on the last choice of this app session '
        '(PDF, 150 dpi at first), across a document swap', (tester) async {
      final files = FakeDocumentFiles();
      await pumpFlat(tester, files);
      await openDialog(tester);
      SegmentedButton<ExportFormat> format() =>
          tester.widget<SegmentedButton<ExportFormat>>(
              find.byKey(const Key('export-format')));
      expect(format().selected, {ExportFormat.pdf});
      expect(find.byKey(const Key('export-dpi')), findsNothing,
          reason: 'no dpi for a PDF');
      await tapKey(tester, 'export-format-png');
      expect(
          tester
              .widget<SegmentedButton<ExportDpi>>(
                  find.byKey(const Key('export-dpi')))
              .selected,
          {ExportDpi.d150});
      await tapKey(tester, 'export-dpi-96');
      files.scriptSaveCancel();
      await tapKey(tester, 'export-ok');
      expect(files.writes, isEmpty);

      // Another document: the host keeps the choice.
      files.scriptOpen(
          name: 'again.jetplan', bytes: fixtureBytes(), location: '/p/a');
      await hostOf(tester).openFlow();
      await tester.pump();
      await tester.pump();
      await openDialog(tester);
      expect(format().selected, {ExportFormat.png});
      expect(
          tester
              .widget<SegmentedButton<ExportDpi>>(
                  find.byKey(const Key('export-dpi')))
              .selected,
          {ExportDpi.d96});
      await tapKey(tester, 'export-cancel');
    });
  });

  group('T-10 cancel and failure', () {
    testWidgets('EX5 Cancel in the dialog asks nothing and writes nothing',
        (tester) async {
      final files = FakeDocumentFiles();
      await pumpFlat(tester, files);
      await openDialog(tester);
      await tapKey(tester, 'export-cancel');
      expect(find.byKey(const Key('export-dialog')), findsNothing);
      expect(files.saveLocationCalls, isEmpty);
      expect(files.writes, isEmpty);
      expect(files.unscriptedCalls, 0);
      expect(sessionOf(tester).busy.value, isFalse);
    });

    testWidgets('EX6 Escape cancels the dialog', (tester) async {
      final files = FakeDocumentFiles();
      await pumpFlat(tester, files);
      await openDialog(tester);
      await press(tester, LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const Key('export-dialog')), findsNothing);
      expect(files.saveLocationCalls, isEmpty);
      expect(files.writes, isEmpty);
    });

    testWidgets('EX7 a cancelled save writes nothing', (tester) async {
      final files = FakeDocumentFiles();
      await pumpFlat(tester, files);
      files.scriptSaveCancel();
      await openDialog(tester);
      await tapKey(tester, 'export-ok');
      expect(files.saveLocationCalls, ['flat.pdf']);
      expect(files.writes, isEmpty);
      noDialog(tester);
      expect(sessionOf(tester).busy.value, isFalse);
    });

    testWidgets('EX8 a throwing write shows "Export failed"', (tester) async {
      final files = FakeDocumentFiles();
      await pumpFlat(tester, files);
      files
        ..scriptSaveLocation(name: 'flat.pdf', location: '/out/flat.pdf')
        ..failNextWrite(const FileSystemException('disk full'));
      await openDialog(tester);
      await tapKey(tester, 'export-ok');
      await tester.pump();
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
      expect(sessionOf(tester).busy.value, isTrue,
          reason: 'busy while the error is up');
      await dismissError(tester);
      expect(sessionOf(tester).busy.value, isFalse);
    });
  });

  group('T-10 enabled', () {
    testWidgets(
        'EX9 disabled with no page: the button, the chord, and the flow '
        'itself does nothing', (tester) async {
      final files = FakeDocumentFiles();
      await pumpFlat(tester, files, bytes: pagelessBytes());
      expect(exportPageOf(sessionOf(tester).document), isNull,
          reason: 'premise: no page');
      expect(exportEnabled(tester), isFalse);
      expect(on(tester, 'save'), isTrue, reason: 'premise: idle');
      await chordHandled(
          tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyE);
      await tester.pump();
      expect(find.byKey(const Key('export-dialog')), findsNothing);
      // The flow itself re-reads the page: started directly, it ends
      // without a dialog. Not awaited first, so a flow that wrongly opened
      // the dialog fails here rather than waiting on it.
      var ended = false;
      final flow = hostOf(tester).exportFlow().then((_) => ended = true);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('export-dialog')), findsNothing);
      expect(ended, isTrue, reason: 'the flow ended by itself');
      await flow;
      expect(files.saveLocationCalls, isEmpty);
    });

    testWidgets('EX10 enabled with a page; disabled while a flow runs',
        (tester) async {
      final files = FakeDocumentFiles();
      await pumpFlat(tester, files);
      expect(exportEnabled(tester), isTrue);
      files
        ..holdWrites = true
        ..scriptSaveLocation(name: 'flat.jetplan', location: '/p/f2');
      final saving = hostOf(tester).saveAsStep();
      await tester.pump();
      expect(sessionOf(tester).busy.value, isTrue, reason: 'premise: busy');
      expect(exportEnabled(tester), isFalse);
      await chordHandled(
          tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyE);
      expect(find.byKey(const Key('export-dialog')), findsNothing);
      files.heldWrites.single.complete();
      await saving;
      await tester.pump();
      expect(exportEnabled(tester), isTrue);
    });
  });

  group('T-10 chords', () {
    for (final (modifier, label) in [
      (LogicalKeyboardKey.metaLeft, 'Cmd'),
      (LogicalKeyboardKey.controlLeft, 'Ctrl'),
    ]) {
      testWidgets('EX11 $label+E opens the dialog', (tester) async {
        final files = FakeDocumentFiles();
        await pumpFlat(tester, files);
        expect(await chordHandled(tester, modifier, LogicalKeyboardKey.keyE),
            isTrue);
        await tester.pump();
        expect(find.byKey(const Key('export-dialog')), findsOneWidget);
        await tapKey(tester, 'export-cancel');
      });

      testWidgets(
          'EX12 with the dialog open, $label+P and $label+E are consumed: '
          'handled, nothing runs, no second dialog', (tester) async {
        final files = FakeDocumentFiles();
        await pumpFlat(tester, files);
        await openDialog(tester);
        for (final key in [LogicalKeyboardKey.keyP, LogicalKeyboardKey.keyE]) {
          expect(await chordHandled(tester, modifier, key), isTrue,
              reason: '$label+${key.keyLabel} handled');
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('export-dialog')), findsOneWidget);
        expect(files.saveLocationCalls, isEmpty);
        expect(files.writes, isEmpty);
        await tapKey(tester, 'export-cancel');
      });
    }
  });

  group('the font', () {
    testWidgets(
        'EX14 a bare host (no font given) exports a PDF in the bundled font, '
        'named Untitled.pdf', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final measurer = FlutterTextMeasurer();
      final doc = DraftDocumentCodec.decodeString(utf8.decode(fixtureBytes()),
          measurer: measurer,
          registerComponents: registerAppComponents,
          diagnostics: <Diagnostic>[]);
      final session = DocumentSession(doc, measurer);
      addTearDown(session.dispose);
      final files = FakeDocumentFiles()
        ..scriptSaveLocation(name: 'Untitled.pdf', location: '/out/u.pdf');
      await tester.pumpWidget(MaterialApp(
          home: DocumentHost(
              session: session, files: files, exitGuard: FakeExitGuard())));
      await tester.pump();
      await openDialog(tester);
      await tapKey(tester, 'export-ok');
      await tester.pump();
      noDialog(tester);
      expect(files.saveLocationCalls, ['Untitled.pdf']);
      final content =
          PdfContent.parse(files.writes.single.bytes, inflate: zlib.decode);
      expect([for (final t in content.textRuns) t.string], [labelText]);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the flow\'s parts', () {
    test('EX13 file names and kinds', () {
      const pdf = ExportChoice.initial;
      final png = pdf.copyWith(format: ExportFormat.png);
      expect(exportFileName('flat', pdf), 'flat.pdf');
      expect(exportFileName('flat', png), 'flat.png');
      expect(exportFileKind(pdf), FileKind.pdf);
      expect(exportFileKind(png), FileKind.png);
      expect(ExportChoice.initial,
          const ExportChoice(format: ExportFormat.pdf, dpi: ExportDpi.d150));
    });
  });
}

/// Whether the toolbar button [id] is enabled, as built.
bool on(WidgetTester tester, String id) =>
    tester.widget<IconButton>(find.byKey(Key('toolbar-$id'))).onPressed != null;
