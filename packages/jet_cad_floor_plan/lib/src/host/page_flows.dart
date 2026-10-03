// Export and Print for an embedding host (spec 14b-2 H6, R-9), in both
// modes: the active plan -- the design, or the service copy on screen
// (A-3) -- as PDF or PNG bytes to the host's `onExport`, or as a PDF to
// the printer. Guarded: one flow at a time, `mounted` before a dialog, and
// after every await the plan must still be the controller's active one.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../export/export_bytes.dart';
import '../export/export_dialog.dart';
import '../export/page_printer.dart';
import 'floor_plan_controller.dart';
import 'floor_plan_types.dart';

/// The two flows of one [FloorPlanView].
class PageFlows {
  PageFlows({
    required this.controller,
    required this.onExport,
    required this.printer,
    required this.exportName,
  });

  final FloorPlanController controller;
  final void Function(FloorPlanExport export)? onExport;
  final PagePrinter printer;
  final String exportName;

  final ValueNotifier<bool> _ready = ValueNotifier(true);

  /// False while a flow runs: a second press does nothing.
  ValueListenable<bool> get ready => _ready;

  /// Export is offered only with an `onExport` (H6).
  bool get canExport => onExport != null;

  Future<void> export(BuildContext context) => _run(context, () async {
        final sink = onExport;
        if (sink == null) return;
        final document = controller.activeDocument;
        final page = exportPageOf(document);
        if (page == null || !context.mounted) return;
        final choice = await showExportDialog(context, controller.exportChoice);
        if (choice == null) return;
        controller.exportChoice = choice;
        if (!identical(document, controller.activeDocument)) return;
        final bytes = await exportBytes(document, page, choice,
            fontBytes: () => controller.exportFont.bytes);
        if (!identical(document, controller.activeDocument)) return;
        final pdf = choice.format == ExportFormat.pdf;
        sink(FloorPlanExport(
          bytes: bytes,
          fileName: '$exportName.${pdf ? 'pdf' : 'png'}',
          mimeType: pdf ? 'application/pdf' : 'image/png',
        ));
      });

  Future<void> print(BuildContext context) => _run(context, () async {
        final document = controller.activeDocument;
        final page = exportPageOf(document);
        if (page == null) return;
        final font = await controller.exportFont.bytes;
        if (!identical(document, controller.activeDocument)) return;
        final bytes = await exportPdfBytes(document, page, fontBytes: font);
        if (!identical(document, controller.activeDocument)) return;
        await printer.print(bytes, exportName, printPageFormat(page));
      });

  Future<void> _run(BuildContext context, Future<void> Function() flow) async {
    if (!_ready.value) return;
    _ready.value = false;
    try {
      controller.settle();
      await flow();
    } finally {
      _ready.value = true;
    }
  }

  void dispose() => _ready.dispose();
}
