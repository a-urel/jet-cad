// The Print flow's seam (spec 13 D9): what hands a page's PDF to the
// platform's print dialog. The app uses [PrintingPagePrinter]; tests inject
// a fake that records what it is given.
import 'dart:typed_data';

import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart' show Printing;

/// Hands a finished PDF to a print dialog.
abstract interface class PagePrinter {
  /// Prints [pdf], a document named [name] whose page is [format] (the
  /// page's size in pt). Completes when the dialog is done with it.
  Future<void> print(Uint8List pdf, String name, PdfPageFormat format);
}

/// The platform's print dialog through the `printing` package: the system
/// dialog on macOS, the browser's on the web.
class PrintingPagePrinter implements PagePrinter {
  const PrintingPagePrinter();

  /// The bytes are laid out once and never again: `dynamicLayout: false`,
  /// so a paper change in the dialog does not ask for a new layout. Without
  /// [format] the dialog would open on `PdfPageFormat.standard` (F-16).
  @override
  Future<void> print(Uint8List pdf, String name, PdfPageFormat format) =>
      Printing.layoutPdf(
          onLayout: (_) async => pdf,
          name: name,
          format: format,
          dynamicLayout: false);
}
