// A PagePrinter for tests (spec 13 D9): records every call's bytes, name and
// page format; throws [failNext] once when set; holds a call open while
// [hold] is set, until the test completes it.
import 'dart:async';
import 'dart:typed_data';

import 'package:floor_planner/export/page_printer.dart';
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

  @override
  Future<void> print(Uint8List pdf, String name, PdfPageFormat format) async {
    calls.add(PrintCall(pdf, name, format));
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
  }
}
