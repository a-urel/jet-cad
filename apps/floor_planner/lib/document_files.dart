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

/// The one file type the panels offer (spec 12a D9).
const XTypeGroup kJetplanTypeGroup =
    XTypeGroup(label: 'Jet plan', extensions: <String>[kJetplanExtension]);

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

  /// Asks where to save; null when the person cancelled. [suggestedName]
  /// ends in `.jetplan`. The returned [name] is the base name the file
  /// will have.
  Future<({String name, Object location})?> saveLocation(String suggestedName);

  /// Writes [bytes] to [location], as the file [name]; throws on failure.
  Future<void> write(Object location, String name, Uint8List bytes);

  /// Whether [write] to a location [open] or [saveLocation] returned
  /// overwrites that file (macOS) or downloads a copy (web).
  bool get writesInPlace;
}

/// The name a typed save name stands for (spec 12a D9 web): null (a
/// cancel) when [typed] is null or blank; otherwise [typed] without its
/// surrounding white space, with `.jetplan` appended when it does not
/// already end in it.
String? jetplanFileName(String? typed) {
  if (typed == null) return null;
  final name = typed.trim();
  if (name.isEmpty) return null;
  const suffix = '.$kJetplanExtension';
  return name.endsWith(suffix) ? name : '$name$suffix';
}
