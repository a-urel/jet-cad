// A symbol source (spec K5): plain data, a label for messages and a reader
// of a library's bytes. A kit's symbols are its sources' libraries.
import 'dart:typed_data';

import 'package:meta/meta.dart';

@immutable
final class SymbolLibrarySource {
  const SymbolLibrarySource({required this.label, required this.read});

  /// Names the source in messages.
  final String label;

  /// Reads the library's bytes. Every library a kit's sources read carries
  /// that kit's id; the plan library refuses one that does not.
  final Future<Uint8List> Function() read;

  @override
  String toString() => 'SymbolLibrarySource($label)';
}
