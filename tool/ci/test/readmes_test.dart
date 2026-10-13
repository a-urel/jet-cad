// Package READMEs spec D8: every Dart block of a package README is in its
// probe file, which CI analyses against the barrels the README names.
import 'dart:io';

import 'package:jet_cad_ci/readmes.dart';
import 'package:test/test.dart';

String read(String path) => File(path).readAsStringSync();

final probeYaml = read('host_probe/pubspec.yaml.in');

final cases = {
  'jet_cad_2d': '../readme_probe/lib/engine.dart',
  'jet_cad_2d_flutter': '../readme_probe/lib/renderer.dart',
  'jet_cad_floor_plan': '../readme_probe/lib/planner.dart',
};

void main() {
  test('RM1 every README block is in its probe', () {
    for (final MapEntry(key: package, value: probe) in cases.entries) {
      final readme = read('../../packages/$package/README.md');
      expect(
          readmeProblems(package, readme, dart: read(probe), yaml: probeYaml),
          isEmpty,
          reason: package);
    }
  });

  test('RM2 a renamed identifier in a README is named', () {
    final readme = read('../../packages/jet_cad_2d/README.md');
    expect(readme, contains('DraftDocument.empty()'), reason: 'premise');
    final renamed =
        readme.replaceFirst('DraftDocument.empty()', 'DraftDocument.blank()');
    expect(
        readmeProblems('jet_cad_2d', renamed,
            dart: read(cases['jet_cad_2d']!), yaml: probeYaml),
        [startsWith('jet_cad_2d: dart: ')]);
  });

  test('RM3 a README without a Dart block is red', () {
    expect(readmeProblems('x', '# x\n\nNo code.\n', dart: '', yaml: ''),
        ['x: no dart block']);
  });

  test("RM4 the planner's font block is the host probe's", () {
    final readme = read('../../packages/jet_cad_floor_plan/README.md');
    final moved = readme.replaceFirst('Roboto-Regular.ttf', 'Roboto.ttf');
    expect(moved, isNot(readme), reason: 'premise');
    expect(
        readmeProblems('jet_cad_floor_plan', moved,
            dart: read(cases['jet_cad_floor_plan']!), yaml: probeYaml),
        [startsWith('jet_cad_floor_plan: yaml: ')]);
  });
}
