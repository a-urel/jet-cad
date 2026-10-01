import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';

import '../draft_painter.dart';
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
/// spawned. The export reads [document] and writes nothing to it.
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
  final index = SpatialIndex(document);
  try {
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
  } finally {
    index.dispose();
  }
  final out = PdfStream();
  await pdf.write(out);
  return out.output();
}
