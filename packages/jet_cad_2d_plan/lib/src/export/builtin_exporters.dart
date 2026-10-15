// Spec P5: the built-in exporters, `plan.pdf` and `plan.png`, and the page
// helpers the flows read. Ported from
// jet_cad_floor_plan/lib/src/export/export_bytes.dart with the unit
// colours the flows made (2b; `unitFillsOf`): no fill writes today's bytes.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ExportDpi, exportPagePdf, exportPagePng;
import 'package:pdf/pdf.dart' show PdfPageFormat;

import 'registries.dart';
import 'unit_colour_underlay.dart' show unitFillsOf;

/// The page [document]'s root carries, or null when it has none. Read from
/// the document, never from the screen (export_bytes.dart:18-24).
PageComponent? exportPageOf(DraftDocument document) =>
    document.components.isRegistered<PageComponent>()
        ? document.components.get<PageComponent>(document.rootHandle)
        : null;

/// [page]'s paper in pt, as laid out: the size the print dialog opens on
/// (export_bytes.dart:68-72).
PdfPageFormat printPageFormat(PageComponent page) => PdfPageFormat(
    page.effectiveWidthMm * 72 / 25.4, page.effectiveHeightMm * 72 / 25.4);

ExportDpi _dpiOf(PlanExportDpi dpi) => switch (dpi) {
      PlanExportDpi.d96 => ExportDpi.d96,
      PlanExportDpi.d150 => ExportDpi.d150,
      PlanExportDpi.d300 => ExportDpi.d300,
    };

/// `plan.pdf`: the page as a one-page vector PDF with the plan's font
/// embedded, the omitted objects not drawn.
final class PlanPdfExporter implements PlanPageExporter {
  const PlanPdfExporter();

  static const String exporterId = 'plan.pdf';

  @override
  String get id => exporterId;

  @override
  String get extension => 'pdf';

  @override
  String get mimeType => 'application/pdf';

  @override
  Future<Uint8List> export(PlanExportRequest request) async => exportPagePdf(
      document: request.document,
      page: request.page!,
      fontBytes: await request.fonts.bytes,
      underlay: unitFillsOf[request] ?? const [],
      omitOwners: request.omitted);
}

/// `plan.png`: the page as a PNG at the choice's resolution, the omitted
/// objects not drawn.
final class PlanPngExporter implements PlanPageExporter {
  const PlanPngExporter();

  static const String exporterId = 'plan.png';

  @override
  String get id => exporterId;

  @override
  String get extension => 'png';

  @override
  String get mimeType => 'image/png';

  @override
  Future<Uint8List> export(PlanExportRequest request) => exportPagePng(
      document: request.document,
      page: request.page!,
      dpi: _dpiOf(request.choice.dpi),
      underlay: unitFillsOf[request] ?? const [],
      omitOwners: request.omitted);
}
