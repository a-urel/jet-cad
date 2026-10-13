/// Test instruments for the export (plan 13, P-2): a reader of the PDF
/// `PdfDrawSink` writes, shared by the render package's tests and the app's.
///
/// A separate library: nothing in `lib/` imports it, so it never reaches the
/// app's build.
///
/// Not API: a test instrument, outside semver; it may change in any release.
library;

export 'src/export/testing/pdf_content.dart';
