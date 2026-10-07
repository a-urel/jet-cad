// `DocumentFiles` on the web (spec 12a D9, S-15, T-12, R-6): the browser's
// file picker through `file_selector` to open, a name the host asks for to
// save (the browser has no save panel), and a download to write. The only
// file of the app, with the other `*_web.dart` files, that imports the web
// package; `document_files.dart` exports it where JS interop exists and
// the io library does not. No widget test reaches it; `flutter
// analyze` reads it, `flutter build web` compiles it, and the human's look
// on the web covers it.
//
// No dependency on the XFile package and no `XFile.saveTo` (R-6): its
// 0.4.0 removed it and 0.3.x's leaks the object URL.
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:web/web.dart' as web;

import 'document_files.dart';

/// The platform's [DocumentFiles]: here, [WebDocumentFiles] over [askName].
/// The browser's picker shows no type names: [typeLabel] names the group
/// for form's sake.
DocumentFiles createDocumentFiles(
        {required DocumentNamePrompt askName,
        FileTypeLabel typeLabel = englishFileTypeLabel}) =>
    WebDocumentFiles(askName, typeLabel: typeLabel);

/// The file picker to open, [askName] and a download to save. A location
/// is the file name to download as; [open] returns none, since the browser
/// cannot write back to the file it read.
class WebDocumentFiles implements DocumentFiles {
  const WebDocumentFiles(this.askName, {this.typeLabel = englishFileTypeLabel});

  /// Asks for the save name (spec 12a T-12).
  final DocumentNamePrompt askName;

  /// The file types' names (spec 14d L16).
  final FileTypeLabel typeLabel;

  @override
  bool get writesInPlace => false;

  @override
  Future<({String name, Uint8List bytes, Object? location})?> open() async {
    final file =
        await openFile(acceptedTypeGroups: openTypeGroups(label: typeLabel));
    if (file == null) return null;
    try {
      return (name: file.name, bytes: await file.readAsBytes(), location: null);
    } finally {
      // `file_selector_web` hands the file over as an object URL it never
      // revokes; the bytes are read, so release it.
      web.URL.revokeObjectURL(file.path);
    }
  }

  /// `file_selector_web`'s `getSaveLocation` returns a dummy empty path,
  /// so the name comes from [askName]: blank is a cancel, and [kind]'s
  /// extension is appended when missing ([fileNameFor]).
  @override
  Future<({String name, Object location})?> saveLocation(String suggestedName,
      {FileKind kind = FileKind.jetplan}) async {
    final name = fileNameFor(await askName(suggestedName), kind);
    if (name == null) return null;
    return (name: name, location: name);
  }

  /// Downloads [bytes] as [name] (spec 12a S-15): a `Blob`, an object URL,
  /// an anchor with `download` set, a click, and the URL revoked. The blob
  /// has [kind]'s MIME type.
  @override
  Future<void> write(Object location, String name, Uint8List bytes,
      {FileKind kind = FileKind.jetplan}) async {
    final blob = web.Blob(<JSUint8Array>[bytes.toJS].toJS,
        web.BlobPropertyBag(type: kind.mimeType));
    final url = web.URL.createObjectURL(blob);
    try {
      (web.HTMLAnchorElement()
            ..href = url
            ..download = name)
          .click();
    } finally {
      web.URL.revokeObjectURL(url);
    }
  }
}
