// What the Export flow (spec 13 D8) reads and makes, apart from its dialogs
// and files: the document's page, the owners that must not plot, the file's
// name and kind, and the bytes. The host (`document_host.dart`) runs the
// flow itself, under busy, after its settle; the Print flow (Task 10) reuses
// these.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../document_files.dart';
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
  final omit = exportOmitOwners(document);
  return switch (choice.format) {
    ExportFormat.pdf => exportPagePdf(
        document: document,
        page: page,
        fontBytes: await fontBytes(),
        omitOwners: omit),
    ExportFormat.png => exportPagePng(
        document: document, page: page, dpi: choice.dpi, omitOwners: omit),
  };
}
