// Export and Print for an embedding host (spec 14b-2 H6, R-9), in both
// modes: the active plan -- the design, or the service copy on screen
// (A-3) -- as PDF or PNG bytes to the host's `onExport`, or as a PDF to
// the printer. Guarded: one flow at a time, `mounted` before a dialog, and
// after every await the plan must still be the controller's active one.
// The bodies, without their dialogs, are also the controller's
// `exportPlan` and `printPlan` (host embedding API spec C-3, S-7).
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show ExportDpi;

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

/// The view's hooks (host embedding API spec C-3, C-4), read at each call:
/// the host's export dialog, in place of the Material one, and where a
/// flow's error goes.
typedef PageFlowHooks = ({
  Future<FloorPlanExportChoice?> Function(
      BuildContext context, FloorPlanExportChoice initial)? exportDialog,
  void Function(Object error)? onError,
});

PageFlowHooks _noHooks() => const (exportDialog: null, onError: null);

bool _never() => false;

/// [choice] as the dialog and the bytes read it. Exhaustive, never by
/// index: a reordered enum cannot swap two resolutions.
ExportChoice toExportChoice(FloorPlanExportChoice choice) => ExportChoice(
      format: switch (choice.format) {
        FloorPlanExportFormat.pdf => ExportFormat.pdf,
        FloorPlanExportFormat.png => ExportFormat.png,
      },
      dpi: switch (choice.dpi) {
        FloorPlanExportDpi.d96 => ExportDpi.d96,
        FloorPlanExportDpi.d150 => ExportDpi.d150,
        FloorPlanExportDpi.d300 => ExportDpi.d300,
      },
    );

/// [choice] as a host reads it; the inverse of [toExportChoice].
FloorPlanExportChoice fromExportChoice(ExportChoice choice) =>
    FloorPlanExportChoice(
      format: switch (choice.format) {
        ExportFormat.pdf => FloorPlanExportFormat.pdf,
        ExportFormat.png => FloorPlanExportFormat.png,
      },
      dpi: switch (choice.dpi) {
        ExportDpi.d96 => FloorPlanExportDpi.d96,
        ExportDpi.d150 => FloorPlanExportDpi.d150,
        ExportDpi.d300 => FloorPlanExportDpi.d300,
      },
    );

/// Export's one body: [document] (the controller's active plan when null)
/// as [choice] says, named [name]; null when it has no page, when the plan
/// shown is no longer it, before or after the bytes, or when [cancelled]
/// says so after them.
Future<FloorPlanExport?> exportOnce(
    FloorPlanController controller, ExportChoice choice, String name,
    {DraftDocument? document, bool Function() cancelled = _never}) async {
  final d = document ?? controller.activeDocument;
  if (!identical(d, controller.activeDocument)) return null;
  final page = exportPageOf(d);
  if (page == null) return null;
  final bytes = await exportBytes(d, page, choice,
      fontBytes: () => controller.exportFont.bytes);
  if (cancelled() || !identical(d, controller.activeDocument)) return null;
  final pdf = choice.format == ExportFormat.pdf;
  return FloorPlanExport(
    bytes: bytes,
    fileName: '$name.${pdf ? 'pdf' : 'png'}',
    mimeType: pdf ? 'application/pdf' : 'image/png',
  );
}

/// Print's one body: the active plan's page as a PDF to [printer], named
/// [name]. False when it has no page, when the plan shown changed while
/// the bytes were made, or when [cancelled] says so after them; true once
/// the printer is done with it.
Future<bool> printOnce(
    FloorPlanController controller, PagePrinter printer, String name,
    {bool Function() cancelled = _never}) async {
  final document = controller.activeDocument;
  final page = exportPageOf(document);
  if (page == null) return false;
  final font = await controller.exportFont.bytes;
  if (!identical(document, controller.activeDocument)) return false;
  final bytes = await exportPdfBytes(document, page, fontBytes: font);
  if (cancelled() || !identical(document, controller.activeDocument)) {
    return false;
  }
  await printer.print(bytes, name, printPageFormat(page));
  return true;
}

/// The two flows of one [FloorPlanView]: one per view state, for its
/// controller.
class PageFlows {
  /// [ready], when given, is the guard (the controller's, shared with its
  /// `exportPlan` and `printPlan`, S-7); else the flows keep their own.
  PageFlows({
    required this.controller,
    required this.settings,
    this.hooks = _noHooks,
    ValueNotifier<bool>? ready,
  })  : _ready = ready ?? ValueNotifier(true),
        _ownsReady = ready == null;

  final FloorPlanController controller;

  /// The view's current settings, read at each call.
  final PageFlowSettings Function() settings;

  /// The view's current hooks, read at each call.
  final PageFlowHooks Function() hooks;

  final ValueNotifier<bool> _ready;
  final bool _ownsReady;
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
        // Spec C-4: the host's dialog when it gave one, today's otherwise;
        // either way from the remembered choice, and null cancels.
        final dialog = hooks().exportDialog;
        final ExportChoice? choice;
        if (dialog != null) {
          final answer =
              await dialog(context, fromExportChoice(controller.exportChoice));
          choice = answer == null ? null : toExportChoice(answer);
        } else {
          choice = await showExportDialog(context, controller.exportChoice);
        }
        if (choice == null) return;
        controller.exportChoice = choice;
        final export = await exportOnce(
            controller, choice, settings().exportName,
            document: document, cancelled: () => _disposed);
        if (export != null) sink(export);
      });

  Future<void> print(BuildContext context) => _run(context, () async {
        final s = settings();
        await printOnce(controller, s.printer, s.exportName,
            cancelled: () => _disposed);
      });

  Future<void> _run(BuildContext context, Future<void> Function() flow) async {
    if (_disposed || !_ready.value) return;
    _ready.value = false;
    try {
      controller.settle();
      await flow();
    } catch (error) {
      // Spec S-8: without the host's callback the error propagates, as it
      // always did, out of a Future the caller drops.
      final report = hooks().onError;
      if (report == null) rethrow;
      report(error);
    } finally {
      // The view may have gone while the flow awaited (review F-1); the
      // controller's guard is released all the same, unless the controller
      // went too.
      if (_ownsReady ? !_disposed : !controller.isDisposed) {
        _ready.value = true;
      }
    }
  }

  void dispose() {
    _disposed = true;
    if (_ownsReady) _ready.dispose();
  }
}
