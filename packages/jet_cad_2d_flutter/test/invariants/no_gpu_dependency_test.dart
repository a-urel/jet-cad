import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The GPU split's guard (spec `2026-10-07-gpu-package-split-design.md` S7,
/// M-G1): `jet_cad_2d_flutter` neither depends on nor imports a GPU package.
///
/// **Why it matters to a host.** `flutter_scene` carries a build hook that
/// compiles shaders with the engine's `impellerc`, and raises the Flutter
/// floor to 3.47. Flutter runs the hooks of the built app's own dependency
/// closure, so one dependency key here puts that hook into every host's
/// build. The GPU lives in `jet_cad_2d_gpu`, which depends on this package
/// and plugs in through `resident_gpu.dart`'s registry -- never the other
/// way round.
const List<String> kForbiddenPackages = <String>[
  'flutter_scene',
  'flutter_gpu',
  'jet_cad_2d_gpu',
];

const List<String> _dependencySections = <String>[
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
];

/// The forbidden packages that [pubspec] names as a dependency **key** in any
/// dependency section. Keys, not text: a comment, a description or a `path:`
/// value that mentions a name does not count, and neither does a look-alike
/// key (`flutter_scene_extras:`).
List<String> forbiddenDependencyKeys(String pubspec) {
  final found = <String>[];
  String? section;
  final topLevel = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)\s*:');
  final dependencyKey = RegExp(r'^ {2}([A-Za-z_][A-Za-z0-9_]*)\s*:');
  for (final line in pubspec.split('\n')) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final top = topLevel.firstMatch(line);
    if (top != null) {
      section = top.group(1);
      continue;
    }
    if (!_dependencySections.contains(section)) continue;
    final key = dependencyKey.firstMatch(line);
    if (key != null && kForbiddenPackages.contains(key.group(1))) {
      found.add(key.group(1)!);
    }
  }
  return found;
}

/// The forbidden packages a Dart [source] reaches by a `package:` URI in a
/// string literal: an import, an export, or either half of a conditional
/// import. Whole-line `//` comments are skipped, so a doc comment may name
/// the GPU package without tripping the guard.
List<String> forbiddenPackageUris(String source) {
  final uri = RegExp(r'''['"]package:([A-Za-z_][A-Za-z0-9_]*)/''');
  final found = <String>[];
  for (final line in source.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    for (final m in uri.allMatches(line)) {
      if (kForbiddenPackages.contains(m.group(1))) found.add(m.group(1)!);
    }
  }
  return found;
}

void main() {
  test("the pubspec names no GPU package as a dependency", () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // MUTATION (M-G1): `flutter_scene: ^0.23.0` back under `dependencies:`.
    expect(forbiddenDependencyKeys(pubspec), isEmpty);
  });

  test('no file under lib/ reaches a GPU package by a package: URI', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty, reason: 'run from the package root');
    for (final f in files) {
      for (final name in forbiddenPackageUris(f.readAsStringSync())) {
        offenders.add('${f.path}: package:$name/');
      }
    }
    // MUTATION (M-G1): one lib/ file importing `package:jet_cad_2d_gpu/`.
    expect(offenders, isEmpty);
  });

  group('the key matcher', () {
    for (final name in kForbiddenPackages) {
      test('is red on $name under each dependency section', () {
        for (final section in _dependencySections) {
          final pubspec = 'name: x\n'
              '$section:\n'
              '  meta: ^1.18.0\n'
              '  $name:\n'
              '    path: ../$name\n'
              'flutter:\n'
              '  uses-material-design: true\n';
          expect(forbiddenDependencyKeys(pubspec), <String>[name],
              reason: section);
        }
      });
    }

    test('is green on look-alikes, comments, values and other sections', () {
      const pubspec = 'name: x\n'
          'description: draws without flutter_scene or flutter_gpu\n'
          'dependencies:\n'
          '  # flutter_scene: ^0.23.0 -- moved to jet_cad_2d_gpu\n'
          '  flutter_scene_extras: ^1.0.0\n'
          '  my_flutter_gpu: ^1.0.0\n'
          '  scene: ^0.3.0\n'
          '  other:\n'
          '    path: ../jet_cad_2d_gpu\n'
          '    flutter_scene: nested, not a dependency key\n'
          'flutter:\n'
          '  flutter_scene: not a dependency section\n';
      expect(forbiddenDependencyKeys(pubspec), isEmpty);
    });
  });

  group('the URI matcher', () {
    for (final name in kForbiddenPackages) {
      test('is red on $name by import, export and conditional import', () {
        expect(forbiddenPackageUris("import 'package:$name/x.dart';"),
            <String>[name]);
        expect(forbiddenPackageUris('export "package:$name/x.dart" show y;'),
            <String>[name]);
        expect(
            forbiddenPackageUris("import 'stub.dart'\n"
                "    if (dart.library.io) 'package:$name/x.dart';"),
            <String>[name]);
      });
    }

    test('is green on comments and look-alike packages', () {
      expect(
          forbiddenPackageUris(
              '/// Installed by `package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart`.\n'
              "// import 'package:flutter_scene/src/gpu/gpu.dart';\n"
              "import 'package:flutter_scene_extras/x.dart';\n"
              "import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';\n"),
          isEmpty);
    });
  });
}
