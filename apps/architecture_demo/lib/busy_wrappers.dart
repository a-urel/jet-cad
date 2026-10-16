// Spec decision 5: the app's `busy` covers the library's own page flows
// through two wrappers. `PlanEditor` has no hook to grey out its buttons,
// so the app sees an export or a print only through the two seams it hands
// the editor: the export dialog and the page printer.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

/// The export dialog with the session busy while it is up (spec decision
/// 5): the library's own dialog, so the app sees the export in flight.
///
/// While a flow already runs (a save write, say) the library cannot know:
/// its Export button is enabled and its guard is free. The dialog then does
/// not open and answers null, which the library reads as a cancel, so no
/// export starts during another flow ("the callback does nothing while
/// busy"). Busy is cleared when the dialog answers or throws.
///
/// The busy span ends there. What follows -- the library makes the bytes,
/// then calls `onExport` -- is not busy until the host's export write
/// starts (see `DocumentHostState.exportFlow`).
///
/// [isDisposed] tells that the session is gone (the app torn down with the
/// dialog up): the clear is then skipped, as `DocumentHostState._flow` does.
PlanExportDialog busyExportDialog(ValueNotifier<bool> busy,
        {PlanExportDialog dialog = showPlanExportDialog,
        bool Function()? isDisposed}) =>
    (context, initial, exporters) async {
      if (busy.value) return null;
      busy.value = true;
      try {
        return await dialog(context, initial, exporters);
      } finally {
        if (isDisposed == null || !isDisposed()) busy.value = false;
      }
    };

/// [inner] with the session busy while the platform's print job runs. While
/// a flow already runs the print does nothing (the library's Print is
/// enabled all the same): the library has made the PDF and is told it was
/// printed. Busy is cleared when the job ends or throws; a throw reaches
/// the library, which reports it through `onPageFlowError`.
final class BusyPagePrinter implements PagePrinter {
  BusyPagePrinter(this.busy, this.inner, {this.isDisposed});

  final ValueNotifier<bool> busy;
  final PagePrinter inner;

  /// True once the session is disposed: the job may end after the app was
  /// torn down, and [busy] is then gone with it.
  final bool Function()? isDisposed;

  @override
  Future<void> print(Uint8List pdf, String name, PdfPageFormat format) async {
    if (busy.value) return;
    busy.value = true;
    try {
      await inner.print(pdf, name, format);
    } finally {
      if (isDisposed == null || !isDisposed!()) busy.value = false;
    }
  }
}
