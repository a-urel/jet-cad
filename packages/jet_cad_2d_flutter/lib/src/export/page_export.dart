import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';

import '../canvas_draw_sink.dart';
import '../draft_painter.dart';
import '../flutter_text_measurer.dart';
import 'page_camera.dart';
import 'pdf_draw_sink.dart';

/// Points per paper millimetre: a PDF's user unit is 1/72 inch.
const double _pointsPerMm = 72 / 25.4;

/// The page of [document] as a one-page vector PDF (spec 13 D4).
///
/// - The sheet is the PDF page, at its effective (oriented) size in pt, and
///   the drawing is at the page's scale: the page camera at `u = 72 / 25.4`
///   ([pageCamera]). The screen's camera plays no part.
/// - The paper is white whatever `page.background` is, so the resolver's
///   foreground is black (ACI 7 plots black).
/// - Level of detail is off (`minTextCapPixels: 0`): a small label is part
///   of the deliverable.
/// - A leaf whose direct owner is in [omitOwners] is not drawn (spec D6).
/// - Every text is drawn in [fontBytes], one embedded TrueType font, its run
///   stretched to the advance `document.textMeasurer` laid its box out with.
///
/// The bytes come from `PdfDocument.write`, not `save()`, so no isolate is
/// spawned. The export reads [document] and writes nothing to it: its
/// codec bytes, its `stateId` and its dispatcher's mutation hooks are as
/// they were (see [_withExportIndex]), on a throw as well.
Future<Uint8List> exportPagePdf({
  required DraftDocument document,
  required PageComponent page,
  required Uint8List fontBytes,
  Set<Handle> omitOwners = const {},
  @visibleForTesting bool compress = true,
}) async {
  final camera = pageCamera(page, _pointsPerMm);
  final pdf = PdfDocument(compress: compress);
  final pdfPage = PdfPage(
    pdf,
    pageFormat: PdfPageFormat(camera.size.width, camera.size.height),
  );
  _withExportIndex(document, (index) {
    final sink = PdfDrawSink(
      document: pdf,
      page: pdfPage,
      pixelsPerPaperMm: camera.pixelsPerPaperMm,
      fontBytes: fontBytes,
      // The painter lays every text box out with this measurer; the sink
      // stretches each run to that same advance.
      measurer: document.textMeasurer,
      textStyleOf: document.textStyleOf,
    );
    DraftPainter(
      document: document,
      index: index,
      resolver: DocumentStyleResolver(document, foreground: 0x000000),
      minTextCapPixels: 0.0,
      omitOwners: omitOwners,
    ).paint(sink, camera.camera, camera.size);
  });
  final out = PdfStream();
  await pdf.write(out);
  return out.output();
}

/// The resolutions a PNG export offers (spec 13 decision 6, D5).
enum ExportDpi {
  d96,
  d150,
  d300;

  /// Dots per inch.
  int get value => switch (this) {
        ExportDpi.d96 => 96,
        ExportDpi.d150 => 150,
        ExportDpi.d300 => 300,
      };
}

/// The page of [document] as a PNG at [dpi] (spec 13 D5).
///
/// - The image is `round(effW / 25.4 · dpi)` × `round(effH / 25.4 · dpi)`
///   pixels; the drawing goes through the page camera at `u = dpi / 25.4`,
///   unrounded, so the last column or row is a part pixel at most.
/// - An opaque white ground is filled first; the resolver's foreground is
///   black and level of detail is off, as for [exportPagePdf].
/// - The drawing goes through a [CanvasDrawSink], whose paths are
///   anti-aliased, with a [FlutterTextMeasurer] of the export's own for its
///   paragraphs, cleared before this returns. The painter lays every text
///   box out with `document.textMeasurer`, as on the screen.
/// - A leaf whose direct owner is in [omitOwners] is not drawn (spec D6).
/// - The PNG carries exactly one `pHYs` chunk, right after `IHDR`: pixels
///   per metre `round(dpi / 0.0254)` on both axes, unit metre.
///
/// The export reads [document] and writes nothing to it: its codec bytes,
/// its `stateId` and its dispatcher's mutation hooks are as they were (see
/// [_withExportIndex]), on a throw as well. Only the paint runs under the
/// export's index; `toImage` and the encoding run after it is gone.
Future<Uint8List> exportPagePng({
  required DraftDocument document,
  required PageComponent page,
  ExportDpi dpi = ExportDpi.d150,
  Set<Handle> omitOwners = const {},
}) async {
  final dotsPerInch = dpi.value;
  final camera = pageCamera(page, dotsPerInch / 25.4);
  final width = (page.effectiveWidthMm / 25.4 * dotsPerInch).round();
  final height = (page.effectiveHeightMm / 25.4 * dotsPerInch).round();
  final measurer = FlutterTextMeasurer();
  ui.Picture? picture;
  ui.Image? image;
  try {
    final recorder = ui.PictureRecorder();
    try {
      final canvas = ui.Canvas(recorder)
        ..drawPaint(ui.Paint()..color = const ui.Color(0xFFFFFFFF));
      _withExportIndex(document, (index) {
        final sink = CanvasDrawSink(
          canvas: canvas,
          pixelsPerPaperMm: camera.pixelsPerPaperMm,
          measurer: measurer,
          textStyleOf: document.textStyleOf,
        );
        DraftPainter(
          document: document,
          index: index,
          resolver: DocumentStyleResolver(document, foreground: 0x000000),
          minTextCapPixels: 0.0,
          omitOwners: omitOwners,
        ).paint(sink, camera.camera, camera.size);
      });
    } finally {
      picture = recorder.endRecording();
    }
    image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('the engine encoded no PNG');
    }
    return withPhysChunk(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      dotsPerInch,
    );
  } finally {
    image?.dispose();
    picture?.dispose();
    measurer.clear();
  }
}

/// [png] with one `pHYs` chunk of `round(dpi / 0.0254)` pixels per metre
/// on both axes (unit 1, the metre) right after `IHDR`; any `pHYs` already
/// in [png] is dropped, so exactly one remains.
///
/// Public only so a test can feed it a PNG that already has a `pHYs`, which
/// the engine's encoder never writes.
@visibleForTesting
Uint8List withPhysChunk(Uint8List png, int dpi) {
  final pixelsPerMetre = (dpi / 0.0254).round();
  const signatureLength = 8;
  final view = ByteData.sublistView(png);
  int chunkEnd(int at) => at + 12 + view.getUint32(at);
  String typeAt(int at) => String.fromCharCodes(png, at + 4, at + 8);
  if (png.length < signatureLength + 12 || typeAt(signatureLength) != 'IHDR') {
    throw StateError('not a PNG that starts with IHDR');
  }
  final out = BytesBuilder(copy: false)
    ..add(Uint8List.sublistView(png, 0, chunkEnd(signatureLength)));

  final chunk = Uint8List(4 + 4 + 9 + 4);
  ByteData.sublistView(chunk)
    ..setUint32(0, 9)
    ..setUint32(8, pixelsPerMetre)
    ..setUint32(12, pixelsPerMetre)
    ..setUint8(16, 1);
  chunk.setAll(4, 'pHYs'.codeUnits);
  ByteData.sublistView(chunk)
      .setUint32(17, _crc32(Uint8List.sublistView(chunk, 4, 17)));
  out.add(chunk);

  for (var at = chunkEnd(signatureLength); at < png.length; at = chunkEnd(at)) {
    if (typeAt(at) == 'pHYs') continue;
    out.add(Uint8List.sublistView(png, at, chunkEnd(at)));
  }
  return out.takeBytes();
}

/// CRC-32 (ISO 3309, the polynomial PNG names, reflected `0xEDB88320`).
int _crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
}, growable: false);

/// Runs [body] with a `SpatialIndex` over [document], then leaves the
/// document's mutation hooks exactly as it found them, on a throw as well.
///
/// `SpatialIndex(document)` takes the dispatcher's single `onAfterMutate`
/// and `onBeforeMutate` slots, and its `dispose()` nulls them. The engine
/// offers no index that leaves them alone, and the document an export reads
/// is the app's live one, whose long-lived screen index owns those slots:
/// without the restore, one export would unhook it for good. Both hooks are
/// captured before the index is built and put back after it is disposed.
///
/// [body] is synchronous on purpose: no edit can run between the capture and
/// the restore, so nothing the restore overwrites can be newer than what it
/// captured. Shared by every export path.
void _withExportIndex(
  DraftDocument document,
  void Function(SpatialIndex index) body,
) {
  final commands = document.commands;
  final afterMutate = commands.onAfterMutate;
  final beforeMutate = commands.onBeforeMutate;
  try {
    final index = SpatialIndex(document);
    try {
      body(index);
    } finally {
      index.dispose();
    }
  } finally {
    commands
      ..onAfterMutate = afterMutate
      ..onBeforeMutate = beforeMutate;
  }
}
