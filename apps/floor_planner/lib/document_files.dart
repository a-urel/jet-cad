// Where a document's bytes come from and go to (spec 12a D9): the
// `DocumentFiles` interface the host calls, and the selection of the
// platform's implementation by conditional export. `document_files_io.dart`
// (macOS: native panels, writes in place) where the io library exists,
// `document_files_web.dart` (the browser's file picker, downloads) where
// the JS interop library does, `document_files_stub.dart` otherwise. Tests
// inject a fake and never reach a real panel.
//
// Neither the io library nor the web package is imported here: this file
// is read on every platform. Those imports live only in the `_io` and
// `_web` files (plan 12a's grep).
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XTypeGroup;

export 'document_files_stub.dart'
    if (dart.library.io) 'document_files_io.dart'
    if (dart.library.js_interop) 'document_files_web.dart';

/// The extension of a jet plan file, without the dot.
const String kJetplanExtension = 'jetplan';

/// The one file type the open panels offer (spec 12a D9), and the save
/// panel's for [FileKind.jetplan].
const XTypeGroup kJetplanTypeGroup =
    XTypeGroup(label: 'Jet plan', extensions: <String>[kJetplanExtension]);

/// What a saved file holds (spec 13 D8): a document, or an export of its
/// page. It picks the save panel's type group, the extension a typed web
/// name gains, and the web download's MIME type.
enum FileKind {
  /// A jet plan document (the JSON the host saves).
  jetplan(kJetplanExtension, 'Jet plan', 'application/json'),

  /// A page exported as PDF.
  pdf('pdf', 'PDF document', 'application/pdf'),

  /// A page exported as PNG.
  png('png', 'PNG image', 'image/png');

  const FileKind(this.extension, this.label, this.mimeType);

  /// The file name extension, without the dot.
  final String extension;

  /// The type group's label in the save panel.
  final String label;

  /// The MIME type of the web download's blob.
  final String mimeType;

  /// The save panel's one file type for this kind.
  XTypeGroup get typeGroup =>
      XTypeGroup(label: label, extensions: <String>[extension]);
}

/// The type groups the native save panel offers for [kind] (spec 13 D8):
/// that kind's alone. The panel enforces and appends the extension itself,
/// so the io side appends nothing to the path it returns.
List<XTypeGroup> saveTypeGroupsFor(FileKind kind) =>
    <XTypeGroup>[kind.typeGroup];

/// Asks the person for a file name, starting from [suggested]; null when
/// they cancelled (spec 12a D9 web, T-12). The host supplies it (an app
/// dialog), so the interface carries no `BuildContext`.
typedef DocumentNamePrompt = Future<String?> Function(String suggested);

/// Opens and saves a document's bytes (spec 12a D9). A location is opaque
/// to the host: it hands back to [write] what [open] or [saveLocation]
/// returned. A cancel is null; a failure is a throw.
abstract interface class DocumentFiles {
  /// Asks for a file and reads it; null when the person cancelled. [name]
  /// is the file's base name (with its extension); [location] is where a
  /// [write] would overwrite it, or null when there is no such place (web).
  Future<({String name, Uint8List bytes, Object? location})?> open();

  /// Asks where to save a file of [kind]; null when the person cancelled.
  /// [suggestedName] ends in the kind's extension. The returned [name] is
  /// the base name the file will have.
  Future<({String name, Object location})?> saveLocation(String suggestedName,
      {FileKind kind = FileKind.jetplan});

  /// Writes [bytes], a file of [kind], to [location], as the file [name];
  /// throws on failure.
  Future<void> write(Object location, String name, Uint8List bytes,
      {FileKind kind = FileKind.jetplan});

  /// Whether [write] to a location [open] or [saveLocation] returned
  /// overwrites that file (macOS) or downloads a copy (web).
  bool get writesInPlace;
}

/// The name a typed save name stands for, for a file of [kind] (spec 12a
/// D9 web, spec 13 D8): null (a cancel) when [typed] is null or blank;
/// otherwise [typed] without its surrounding white space, with `.` and the
/// kind's extension appended when it does not already end in them. The
/// comparison is case-sensitive, as `jetplanFileName`'s always was:
/// `plan.PDF` becomes `plan.PDF.pdf`.
String? fileNameFor(String? typed, FileKind kind) {
  if (typed == null) return null;
  final name = typed.trim();
  if (name.isEmpty) return null;
  final suffix = '.${kind.extension}';
  return name.endsWith(suffix) ? name : '$name$suffix';
}

/// [fileNameFor] a jet plan document.
String? jetplanFileName(String? typed) => fileNameFor(typed, FileKind.jetplan);
