// Export and Print from an editor's bar and chords (2a spec P2, P5): the
// dialog (the host's when it gave one), the remembered answer, the bytes
// to the host's onExport, the PDF to the printer. Under the controller's
// one-flow guard; the host's hooks and settings are read at each call;
// `permissions.export` and `.print` are read again after the dialog and
// after the bytes, so a flow started before the host refused it does not
// run to its end. Ported from jet_cad_floor_plan/lib/src/host/page_flows.dart.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart' show BuildContext;

import '../controller/plan_controller.dart';
import 'builtin_exporters.dart' show exportPageOf;
import 'export_dialog.dart';
import 'page_flows.dart';
import 'page_printer.dart';
import 'registries.dart';

/// What the flows read from the view at call time.
typedef PageFlowSettings = ({
  void Function(PlanExport export)? onExport,
  PagePrinter printer,
  String exportName,
});

/// The view's hooks, read at each call: the host's export dialog, in place
/// of the Material one, and where a flow's error goes.
typedef PageFlowHooks = ({
  PlanExportDialog? exportDialog,
  void Function(Object error)? onError,
});

PageFlowHooks _noHooks() => const (exportDialog: null, onError: null);

/// The two flows of one editor view, for its controller.
class EditorPageFlows {
  EditorPageFlows(
      {required this.controller,
      required this.settings,
      this.hooks = _noHooks});

  final PlanController controller;

  /// The view's current settings, read at each call.
  final PageFlowSettings Function() settings;

  /// The view's current hooks, read at each call.
  final PageFlowHooks Function() hooks;

  bool _disposed = false;

  PlanPageFlows get _flows => controller.pageFlows;

  /// False while a flow runs (this view's, another view's or the host's
  /// own call): a second press does nothing.
  ValueListenable<bool> get ready => _flows.ready;

  /// Export is offered only with an `onExport`.
  bool get canExport => settings().onExport != null;

  bool _exportAllowed() => controller.permissions.export;
  bool _printAllowed() => controller.permissions.print;

  Future<void> export(BuildContext context) => _run(() async {
        final sink = settings().onExport;
        if (sink == null) return;
        final flows = _flows;
        final document = controller.document;
        final paged = exportPageOf(document) != null;
        if (!paged && flows.exporters.every((e) => e is PlanPageExporter)) {
          return;
        }
        if (!context.mounted) return;
        // The host's dialog when it gave one, the Material one otherwise;
        // either way from the remembered answer, and null cancels.
        final dialog = hooks().exportDialog;
        final answer = dialog != null
            ? await dialog(context, flows.dialogAnswer, flows.exporters)
            : await showPlanExportDialog(
                context, flows.dialogAnswer, flows.exporters);
        // A view gone meanwhile is the bytes' cancel, below.
        if (answer == null || (!_disposed && !_exportAllowed())) return;
        flows.dialogAnswer = answer;
        final export = await flows.exportOnce(
            answer.exporter, answer.choice, settings().exportName,
            document: document,
            cancelled: () => _disposed || !_exportAllowed());
        if (export != null) sink(export);
      });

  Future<void> print(BuildContext context) => _run(() async {
        final s = settings();
        await _flows.printOnce(s.printer, s.exportName,
            choice: _flows.dialogAnswer.choice,
            cancelled: () => _disposed || !_printAllowed());
      });

  Future<void> _run(Future<void> Function() flow) async {
    final flows = _flows;
    if (_disposed || !flows.acquire()) return;
    try {
      controller.settlePendingInput();
      await flow();
    } catch (error) {
      // Without the host's callback the error propagates, as it always
      // did, out of a Future the caller drops.
      final report = hooks().onError;
      if (report == null) rethrow;
      report(error);
    } finally {
      // The view may have gone while the flow awaited; the controller's
      // guard is released all the same, unless the controller went too.
      flows.release();
    }
  }

  void dispose() => _disposed = true;
}
