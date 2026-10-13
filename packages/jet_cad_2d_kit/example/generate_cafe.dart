// A kit's generator (docs/kits.md section 7): writes the library and adds
// the snapshot entries of new key@N's.
import 'dart:io';

import 'package:jet_cad_2d_kit/authoring.dart';

import 'example.dart';

void main() {
  Directory('assets').createSync(recursive: true);
  Directory('test').createSync(recursive: true);
  File('assets/cafe.jetlib')
      .writeAsBytesSync(encodeLibrary(buildCafeCatalog()));
  final file = File('test/cafe_snapshot.json');
  final committed = file.existsSync()
      ? parseSnapshot(file.readAsStringSync())
      : <String, String>{};
  file.writeAsStringSync(encodeSnapshot(
      updateSnapshot(committed, geometrySnapshot(buildCafeCatalog()))));
}
