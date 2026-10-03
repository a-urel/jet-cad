// The Export and Print flows' document (plan 13 Tasks 9-10, spec 13 T-10):
// a flat whose page is A4 landscape at 1:50 off the origin, with a real
// separator in a turned group, a rotated, mirrored instance with colour and
// lineweight overrides, and a label (so a PDF embeds the font); the app
// pumped over it with the screen's camera at 400 % and panned off the
// sheet; and the readings the flows' tests share.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:floor_planner/export/export_flow.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:floor_planner/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'document_rig.dart';
import 'fake_document_files.dart';
import 'room_fixture.dart' show addSeparator, attachPage;

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

/// The page the flat carries unless a test gives another: A4 landscape at
/// 1:50, off the origin, dark.
PageComponent flatPage() => PageComponent(
    orientation: PageOrientation.landscape,
    scaleDenominator: scaleDen,
    originX: originX,
    originY: originY,
    background: 0xFF303030);

/// The flat's file: the document above, saved by the codec; [page] instead
/// of [flatPage] when given (keep its origin and scale: [toPdf] assumes
/// them).
Uint8List fixtureBytes({PageComponent? page}) {
  final doc = prepareDocument(const InsertionPointMeasurer());
  final system = installParametric(doc);
  attachPage(doc, page ?? flatPage());
  addSeparator(doc, sepStart, sepEnd,
      at: Transform2.translation(400, -250).multiply(Transform2.rotation(0.1)));
  final definition = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
      handle: definition,
      name: 'export-flow-symbol',
      basePoint: Vector2(120, 45),
      children: const []));
  addLeaf(doc, definition, [
    instanceLineStart.x,
    instanceLineStart.y,
    1000,
    400,
  ]);
  addLeaf(doc, definition, [300, 600, 900, 700], kind: EntityKind.line);
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
  addLeaf(doc, doc.rootHandle, [4000, 500, 9000, 2500],
      color: const TrueColor(0x1565C0));
  final bytes = bytesOf(doc);
  doc.dispose();
  return Uint8List.fromList(bytes);
}

/// A leaf of [kind] under [owner], in layer 0, continuous.
Handle addLeaf(DraftDocument doc, Handle owner, List<double> coords,
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

/// The app over [files] with [fontCache] (and [printer], when given), at
/// 1440 x 900; the flat opened (named `flat`) unless [bytes] says
/// otherwise; the camera at 400 % and panned far off the sheet.
Future<void> pumpFlat(WidgetTester tester, FakeDocumentFiles files,
    {Uint8List? bytes, PagePrinter? printer}) async {
  fontLoads = 0;
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(printer == null
      ? FloorPlannerApp(files: files, exportFont: fontCache())
      : FloorPlannerApp(
          files: files, exportFont: fontCache(), printer: printer));
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

/// The distance from [p] to the segment [a]-[b], in pt.
double pdfDistanceToSegment(PdfXY p, Vector2 a, Vector2 b) {
  final ab = b - a;
  final t =
      (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / ab.length2).clamp(0.0, 1.0);
  final q = a + ab * t;
  return math.sqrt(math.pow(p.x - q.x, 2) + math.pow(p.y - q.y, 2));
}
