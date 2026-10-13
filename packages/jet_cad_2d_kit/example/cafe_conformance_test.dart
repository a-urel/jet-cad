// A kit's conformance test (docs/kits.md section 8). It reads the files
// generate_cafe.dart writes, so it is analysed here, not run.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

import 'example.dart';

void main() {
  test('the kit conforms', () {
    expect(
      conformance(
        catalog: buildCafeCatalog(),
        committedLibrary: File('assets/cafe.jetlib').readAsBytesSync(),
        committedSnapshot: File('test/cafe_snapshot.json').readAsStringSync(),
        names: cafeNames,
        locales: const ['tr'],
      ),
      isEmpty,
    );
  });
}
