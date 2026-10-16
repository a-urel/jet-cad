// N1 (spec R3, as 3b's): the demo names neither old package, and keeps no
// bundled plan JSON.
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
    expect(files.length, greaterThan(5), reason: 'the walk found the files');
    expect(hits, isEmpty);
  });

  test('N2 no bundled sample JSON and no UPDATE_SAMPLES path', () {
    expect(Directory('assets/plans').existsSync(), isFalse);
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('assets/')));
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      expect(f.readAsStringSync(), isNot(contains('UPDATE_SAMPLES')),
          reason: f.path);
    }
  });
}
