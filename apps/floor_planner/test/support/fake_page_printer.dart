// A PagePrinter for tests (spec 13 D9): records every call's bytes, name and
// page format; throws [failNext] once when set; while [hold] is set, keeps
// each call open (as the system print dialog does) until the test completes
// its completer in [held].
import 'dart:async';
import 'dart:typed_data';

import 'package:jet_cad_floor_plan/editor.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

class PrintCall {
  PrintCall(this.pdf, this.name, this.format);
  final Uint8List pdf;
  final String name;
  final PdfPageFormat format;
}

class FakePagePrinter implements PagePrinter {
  final List<PrintCall> calls = [];

  /// Thrown by the next call, then cleared.
  Object? failNext;

  /// When true, each call waits on a completer added to [held].
  bool hold = false;

  /// The open calls' completers, in call order, while [hold] is set.
  final List<Completer<void>> held = [];

  @override
  Future<void> print(Uint8List pdf, String name, PdfPageFormat format) async {
    calls.add(PrintCall(pdf, name, format));
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
    if (hold) {
      final open = Completer<void>();
      held.add(open);
      await open.future;
    }
  }
}
