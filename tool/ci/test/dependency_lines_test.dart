// Spec 2026-10-13-publish-host-packages D1: every pubspec of the live line
// names a published package by a hosted constraint, never by `path:` or
// `git:`. Run from tool/ci: the pubspecs are read from the repository.
import 'dart:io';

import 'package:test/test.dart';

/// The packages published on pub.dev.
const published = ['jet_cad_2d', 'jet_cad_2d_flutter', 'jet_cad_floor_plan'];

/// The live line's pubspecs, relative to tool/ci.
const pubspecs = [
  '../../packages/jet_cad_2d/pubspec.yaml',
  '../../packages/jet_cad_2d_flutter/pubspec.yaml',
  '../../packages/jet_cad_2d_gpu/pubspec.yaml',
  '../../packages/jet_cad_floor_plan/pubspec.yaml',
  '../../packages/jet_cad_restaurant_symbols/pubspec.yaml',
  '../../apps/floor_planner/pubspec.yaml',
  '../../apps/restaurant_demo/pubspec.yaml',
  '../../apps/dev_harness_2d/pubspec.yaml',
  '../../tool/screenshots/pubspec.yaml',
  '../../tool/readme_probe/pubspec.yaml',
];

/// The dependency lines of [pubspec] that name one of [published] by a
/// source other than a hosted constraint: the key line followed by an
/// indented `path:` or `git:` line, or by a nested map.
List<String> nonHosted(String pubspec) {
  final lines = pubspec.split('\n');
  final found = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final key = RegExp(r'^  (\w+):\s*$').firstMatch(lines[i]);
    if (key == null || !published.contains(key[1])) continue;
    final next = i + 1 < lines.length ? lines[i + 1] : '';
    if (RegExp(r'^    \S').hasMatch(next))
      found.add('${key[1]}: ${next.trim()}');
  }
  return found;
}

/// The hosted constraints of [pubspec] on one of [published].
Map<String, String> hosted(String pubspec) => {
  for (final m in RegExp(
    r'^  (\w+): (\S+)\s*$',
    multiLine: true,
  ).allMatches(pubspec))
    if (published.contains(m[1])) m[1]!: m[2]!,
};

void main() {
  test('DL1 no live-line pubspec names a published package by path or git', () {
    for (final path in pubspecs) {
      expect(nonHosted(File(path).readAsStringSync()), isEmpty, reason: path);
    }
  });

  test('DL2 every such dependency is the caret of D1', () {
    var seen = 0;
    for (final path in pubspecs) {
      final constraints = hosted(File(path).readAsStringSync());
      seen += constraints.length;
      for (final c in constraints.values) {
        expect(c, '^0.7.2', reason: path);
      }
    }
    expect(
      seen,
      20,
      reason:
          'premise: the dependents are read; the pubspecs hold 20 '
          'dependency lines on a published package (14, and the three each of '
          'tool/screenshots and tool/readme_probe)',
    );
  });

  test('DL3 the reader sees a path dependency', () {
    expect(nonHosted('dependencies:\n  jet_cad_2d:\n    path: ../x\n'), [
      'jet_cad_2d: path: ../x',
    ]);
    expect(nonHosted('dependencies:\n  jet_cad_2d: ^0.7.2\n'), isEmpty);
  });
}
