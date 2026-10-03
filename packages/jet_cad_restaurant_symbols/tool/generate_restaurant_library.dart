// Writes `assets/restaurant.jetlib` from the catalog (spec 14 V-2).
//
// Run from the package directory, under plain Dart (no Flutter):
//   dart run tool/generate_restaurant_library.dart
import 'dart:convert';
import 'dart:io';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/symbols.dart';
import 'package:jet_cad_restaurant_symbols/src/catalog.dart';

void main() {
  final file = File('assets/restaurant.jetlib');
  final bytes = utf8.encode(
      DraftDocumentCodec.encodeToString(buildSymbolLibrary(restaurantCatalog)));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  stdout.writeln('wrote ${file.path}: ${bytes.length} bytes');
}
