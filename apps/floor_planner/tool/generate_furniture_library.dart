// Writes `assets/library/furniture.jetlib` from the catalog (spec 09 D2).
//
// Run from the app directory, under plain Dart (no Flutter):
//   dart run tool/generate_furniture_library.dart
import 'dart:convert';
import 'dart:io';

import 'package:floor_planner/symbols/build_library.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

void main() {
  final file = File('assets/library/furniture.jetlib');
  final bytes =
      utf8.encode(DraftDocumentCodec.encodeToString(buildFurnitureLibrary()));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  stdout.writeln('wrote ${file.path}: ${bytes.length} bytes');
}
