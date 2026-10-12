// What the Export and Print flows (spec 13 D8, D9) read and make, apart
// from their dialogs, files and printer: the document's page, the owners
// that must not plot, the bytes, and the page's size in pt. Moved here
// from the app (spec 14b-2 H6) so an embedding host's view exports with
// the same code as the app.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

import '../colors/table_color_underlay.dart';
import '../host/floor_plan_theme.dart' show kTableColorOpacity;
import '../parametric/live_objects.dart';
import '../parametric/separator.dart';
import 'export_dialog.dart';

/// The page [document]'s root carries, or null when it has none (spec 13
/// D8: the flow then returns without effect). Read from the document, never
/// from the screen: the export plots the page, at its scale.
PageComponent? exportPageOf(DraftDocument document) =>
    document.components.isRegistered<PageComponent>()
        ? document.components.get<PageComponent>(document.rootHandle)
        : null;

/// The owners whose leaves do not plot (spec 13 D6, decision 11): every
/// live separator of [document], at the moment of the export.
Set<Handle> exportOmitOwners(DraftDocument document) =>
    liveObjectsOf<SeparatorParams>(document).toSet();

/// [page] of [document] as [choice] says: a vector PDF with [fontBytes]'
/// font embedded (read only for a PDF), or a PNG at the chosen dpi; the
/// separators omitted either way, and the coloured tables filled under the
/// drawing at [tableColorOpacity] (plan colours spec PC-7).
Future<Uint8List> exportBytes(
  DraftDocument document,
  PageComponent page,
  ExportChoice choice, {
  required Future<Uint8List> Function() fontBytes,
  double tableColorOpacity = kTableColorOpacity,
}) async {
  return switch (choice.format) {
    ExportFormat.pdf => exportPdfBytes(document, page,
        fontBytes: await fontBytes(), tableColorOpacity: tableColorOpacity),
    ExportFormat.png => exportPagePng(
        document: document,
        page: page,
        dpi: choice.dpi,
        omitOwners: exportOmitOwners(document),
        underlay: tableColorUnderlay(document, tableColorOpacity)),
  };
}

/// [page] of [document] as a vector PDF with [fontBytes]' font embedded,
/// the separators omitted, the coloured tables filled under the drawing at
/// [tableColorOpacity] (plan colours spec PC-7): what Export → PDF writes
/// and what Print hands to the printer (spec 13 D8, D9).
Future<Uint8List> exportPdfBytes(DraftDocument document, PageComponent page,
        {required Uint8List fontBytes,
        double tableColorOpacity = kTableColorOpacity}) =>
    exportPagePdf(
        document: document,
        page: page,
        fontBytes: fontBytes,
        omitOwners: exportOmitOwners(document),
        underlay: tableColorUnderlay(document, tableColorOpacity));

/// [page]'s paper in pt, as laid out (orientation applied): the size the
/// print dialog opens on (spec 13 D9; without it the dialog opens on
/// `PdfPageFormat.standard`).
PdfPageFormat printPageFormat(PageComponent page) => PdfPageFormat(
    page.effectiveWidthMm * 72 / 25.4, page.effectiveHeightMm * 72 / 25.4);
