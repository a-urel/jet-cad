import 'dart:io';
import 'dart:typed_data';

/// The vendored Roboto (`test/golden/fonts/`, spec 13 F-11), the font the
/// export embeds. Read by `File`, relative to the package root, where
/// `flutter test` runs.
Uint8List exportFontBytes() =>
    File('test/golden/fonts/Roboto-Regular.ttf').readAsBytesSync();
