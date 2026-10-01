import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spec 13 T-11 (D10), structural: the export path draws through
/// `CanvasDrawSink` (PNG) and `PdfDrawSink` (PDF) and through nothing that
/// bakes or ignores anti-aliasing. `TileCache` is built only by
/// `DraftCanvas` (F-9), so a file that names neither cannot reach it. The
/// behavioural half is `export_png_test.dart`'s coverage check.
///
/// Named mutants: M-13a, M-13e.
void main() {
  final source = File('lib/src/export/page_export.dart').readAsStringSync();

  test('page_export.dart names no VerticesDrawSink, TileCache or DraftCanvas',
      () {
    for (final name in ['VerticesDrawSink', 'TileCache', 'DraftCanvas']) {
      expect(source.contains(name), isFalse, reason: name);
    }
  });

  test('page_export.dart names CanvasDrawSink and PdfDrawSink', () {
    for (final name in ['CanvasDrawSink(', 'PdfDrawSink(']) {
      expect(source.contains(name), isTrue, reason: name);
    }
  });
}
