// Package READMEs spec D8: every Dart block of a package README is in its
// probe file, which CI analyses against the barrels the README names.
import 'dart:io';

import 'package:jet_cad_ci/readmes.dart';
import 'package:test/test.dart';

String read(String path) => File(path).readAsStringSync();

final cases = {
  'jet_cad_2d': '../readme_probe/lib/engine.dart',
  'jet_cad_2d_flutter': '../readme_probe/lib/renderer.dart',
};

void main() {
  test('RM1 every README block is in its probe', () {
    for (final MapEntry(key: package, value: probe) in cases.entries) {
      final readme = read('../../packages/$package/README.md');
      expect(
        readmeProblems(package, readme, dart: read(probe)),
        isEmpty,
        reason: package,
      );
    }
  });

  test('RM2 a renamed identifier in a README is named', () {
    final readme = read('../../packages/jet_cad_2d/README.md');
    expect(readme, contains('DraftDocument.empty()'), reason: 'premise');
    final renamed = readme.replaceFirst(
      'DraftDocument.empty()',
      'DraftDocument.blank()',
    );
    expect(
      readmeProblems('jet_cad_2d', renamed, dart: read(cases['jet_cad_2d']!)),
      [startsWith('jet_cad_2d: dart: ')],
    );
  });

  test('RM3 a README without a Dart block is red', () {
    expect(readmeProblems('x', '# x\n\nNo code.\n', dart: ''), [
      'x: no dart block',
    ]);
  });
}
