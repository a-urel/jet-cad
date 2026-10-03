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

/// What the flows read from the view at call time (review F-1): a host
/// rebuild with a new `onExport` closure must not rebuild the flows.
typedef PageFlowSettings = ({
  void Function(FloorPlanExport export)? onExport,
  PagePrinter printer,
  String exportName,
});

/// The two flows of one [FloorPlanView]: one per view state, for its
/// controller.
class PageFlows {
  PageFlows({required this.controller, required this.settings});

  final FloorPlanController controller;

  /// The view's current settings, read at each call.
  final PageFlowSettings Function() settings;

  final ValueNotifier<bool> _ready = ValueNotifier(true);
  bool _disposed = false;

  /// False while a flow runs: a second press does nothing.
  ValueListenable<bool> get ready => _ready;

  /// Export is offered only with an `onExport` (H6).
  bool get canExport => settings().onExport != null;

  Future<void> export(BuildContext context) => _run(context, () async {
        final sink = settings().onExport;
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
        if (_disposed || !identical(document, controller.activeDocument)) {
          return;
        }
        final pdf = choice.format == ExportFormat.pdf;
        sink(FloorPlanExport(
          bytes: bytes,
          fileName: '${settings().exportName}.${pdf ? 'pdf' : 'png'}',
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
        if (_disposed || !identical(document, controller.activeDocument)) {
          return;
        }
        final s = settings();
        await s.printer.print(bytes, s.exportName, printPageFormat(page));
      });

  Future<void> _run(BuildContext context, Future<void> Function() flow) async {
    if (_disposed || !_ready.value) return;
    _ready.value = false;
    try {
      controller.settle();
      await flow();
    } finally {
      // The view may have gone while the flow awaited (review F-1).
      if (!_disposed) _ready.value = true;
    }
  }

  void dispose() {
    _disposed = true;
    _ready.dispose();
  }
}
