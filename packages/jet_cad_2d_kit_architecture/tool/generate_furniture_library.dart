// Writes the architecture kit's furniture library from its catalog and adds
// the geometry snapshot's entries of new key@Ns, never rewriting one (spec
// 3a C4, contract K7).
//
// Run from the package directory, under plain Dart (no Flutter):
//   dart run tool/generate_furniture_library.dart
import 'dart:io';

import 'package:jet_cad_2d_kit/authoring.dart';
import 'package:jet_cad_2d_kit_architecture/src/furniture/furniture_catalog.dart';

void main() {
  final library = File('assets/library/furniture.jetlib');
  final bytes = encodeLibrary(furnitureCatalog);
  library.parent.createSync(recursive: true);
  library.writeAsBytesSync(bytes);
  final snapshot = File('assets/library/furniture.snapshot.json');
  final committed = snapshot.existsSync()
      ? parseSnapshot(snapshot.readAsStringSync())
      : <String, String>{};
  snapshot.writeAsStringSync(encodeSnapshot(
      updateSnapshot(committed, geometrySnapshot(furnitureCatalog))));
  stdout.writeln('wrote ${library.path}: ${bytes.length} bytes, '
      '${furnitureCatalog.symbols.length} symbols');
}
