// `DocumentFiles` on macOS (spec 12a D9): `file_selector`'s native open and
// save panels, and the io library to write. The only file of the app that
// imports the io library; `document_files.dart` exports it where that
// library exists. No widget test reaches it (the panels are native); `flutter
// analyze` reads it, and the human's look on macOS covers it.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'document_files.dart';

/// The platform's [DocumentFiles]: here, [IoDocumentFiles]. [askName] is
/// the web's save-name prompt; the native save panel asks instead, so it
/// is not used here.
DocumentFiles createDocumentFiles({required DocumentNamePrompt askName}) =>
    const IoDocumentFiles();

/// Native panels; a location is the file's path, and [write] overwrites it.
class IoDocumentFiles implements DocumentFiles {
  const IoDocumentFiles();

  @override
  bool get writesInPlace => true;

  @override
  Future<({String name, Uint8List bytes, Object? location})?> open() async {
    final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[kJetplanTypeGroup]);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return (name: _baseName(file.path), bytes: bytes, location: file.path);
  }

  /// The save panel enforces and appends the extension itself, and the
  /// sandbox grants exactly the URL it returns, so the returned path is
  /// the location **unchanged** (spec 12a D9, S-16): appending to it would
  /// write outside the grant.
  @override
  Future<({String name, Object location})?> saveLocation(
      String suggestedName) async {
    final location = await getSaveLocation(
        acceptedTypeGroups: const <XTypeGroup>[kJetplanTypeGroup],
        suggestedName: suggestedName);
    if (location == null) return null;
    return (name: _baseName(location.path), location: location.path);
  }

  @override
  Future<void> write(Object location, String name, Uint8List bytes) async {
    if (location is! String) {
      throw ArgumentError.value(location, 'location', 'not a file path');
    }
    await File(location).writeAsBytes(bytes, flush: true);
  }

  static String _baseName(String path) =>
      path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);
}
