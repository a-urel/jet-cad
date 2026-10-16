// N1 (spec B6): the app names neither old package.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _banned = ['jet_cad_floor_plan', 'jet_cad_restaurant_symbols'];

void main() {
  test('N1 the pubspec and every Dart file name no old package', () {
    final files = <File>[
      File('pubspec.yaml'),
      for (final dir in ['lib', 'test'])
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
    ];
    final hits = <String>[];
    for (final f in files) {
      if (f.path.endsWith('boundary_test.dart')) continue;
      final text = f.readAsStringSync();
      for (final name in _banned) {
        if (text.contains(name)) hits.add('${f.path}: $name');
      }
    }
    expect(files.length, greaterThan(2), reason: 'the walk found the files');
    expect(hits, isEmpty);
  });
}
