// What the Export and Print flows (spec 13 D8, D9) read and make, apart
// from their dialogs, files and printer: the document's page, the owners
// that must not plot, the file's name and kind, the page's size in pt, and
// the bytes. The host (`document_host.dart`) runs the flows themselves,
// under busy, after its settle.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

import '../document_files.dart';

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

/// The file kind [choice] writes.
FileKind exportFileKind(ExportChoice choice) => switch (choice.format) {
      ExportFormat.pdf => FileKind.pdf,
      ExportFormat.png => FileKind.png,
    };

/// The name the save offers for the document [name]: `<name>.pdf` or
/// `<name>.png` (spec 13 D8).
String exportFileName(String name, ExportChoice choice) =>
    '$name.${exportFileKind(choice).extension}';

/// [page] of [document] as [choice] says: a vector PDF with [fontBytes]'
/// font embedded (read only for a PDF), or a PNG at the chosen dpi; the
/// separators omitted either way.
Future<Uint8List> exportBytes(
  DraftDocument document,
  PageComponent page,
  ExportChoice choice, {
  required Future<Uint8List> Function() fontBytes,
}) async {
  return switch (choice.format) {
    ExportFormat.pdf =>
      exportPdfBytes(document, page, fontBytes: await fontBytes()),
    ExportFormat.png => exportPagePng(
        document: document,
        page: page,
        dpi: choice.dpi,
        omitOwners: exportOmitOwners(document)),
  };
}

/// [page] of [document] as a vector PDF with [fontBytes]' font embedded,
/// the separators omitted: what Export → PDF writes and what Print hands
/// to the printer (spec 13 D8, D9).
Future<Uint8List> exportPdfBytes(DraftDocument document, PageComponent page,
        {required Uint8List fontBytes}) =>
    exportPagePdf(
        document: document,
        page: page,
        fontBytes: fontBytes,
        omitOwners: exportOmitOwners(document));

/// [page]'s paper in pt, as laid out (orientation applied): the size the
/// print dialog opens on (spec 13 D9; without it the dialog opens on
/// `PdfPageFormat.standard`).
PdfPageFormat printPageFormat(PageComponent page) => PdfPageFormat(
    page.effectiveWidthMm * 72 / 25.4, page.effectiveHeightMm * 72 / 25.4);
