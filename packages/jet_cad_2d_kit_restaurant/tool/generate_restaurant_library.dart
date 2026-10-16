// Writes the restaurant kit's library from its catalog and adds the geometry
// snapshot's entries of new key@Ns, never rewriting one (contract K7).
//
// Run from the package directory, under plain Dart (no Flutter):
//   dart run tool/generate_restaurant_library.dart
import 'dart:io';

import 'package:jet_cad_2d_kit/authoring.dart';
import 'package:jet_cad_2d_kit_restaurant/src/catalog/restaurant_catalog.dart';

void main() {
  final library = File('assets/library/restaurant.jetlib');
  final bytes = encodeLibrary(restaurantCatalog);
  library.parent.createSync(recursive: true);
  library.writeAsBytesSync(bytes);
  final snapshot = File('assets/library/restaurant.snapshot.json');
  final committed = snapshot.existsSync()
      ? parseSnapshot(snapshot.readAsStringSync())
      : <String, String>{};
  snapshot.writeAsStringSync(encodeSnapshot(
      updateSnapshot(committed, geometrySnapshot(restaurantCatalog))));
  stdout.writeln('wrote ${library.path}: ${bytes.length} bytes, '
      '${restaurantCatalog.symbols.length} symbols');
}
