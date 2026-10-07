import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_gpu/src/resident_geometry.dart';

/// The shader bundle's asset key (spec S1, risk R-1), checked off a device.
///
/// `ResidentGeometry.create` loads the bundle by [ResidentGeometry.bundleAssetKey];
/// a wrong key, or a bundle the pubspec no longer declares, fails only on a
/// real GPU, where `create` reports it and returns null and the harness falls
/// back to `vertices`. `flutter test` cannot load the prefixed key (that
/// constant's own doc comment says why), so this pins the three facts the
/// key depends on instead: its shape, the declaration, and the file.
void main() {
  // `flutter test` runs from the package root.
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('the pubspec reading finds the name and the declared assets', () {
    // Not vacuous: the readings below see what this pubspec does say.
    expect(pubspecName(pubspec), 'jet_cad_2d_gpu');
    expect(flutterAssets(pubspec), isNotEmpty);
  });

  test(
      'the key is packages/<the pubspec name>/<a declared asset>, and that '
      'asset is on disk', () {
    final name = pubspecName(pubspec);
    final prefix = 'packages/$name/';
    // MUTATION (MU2): the key's package prefix typo'd, or left at the
    // pre-split `packages/jet_cad_2d_flutter/`.
    expect(ResidentGeometry.bundleAssetKey, startsWith(prefix));
    final asset = ResidentGeometry.bundleAssetKey.substring(prefix.length);
    // MUTATION (MU2): the path after the prefix typo'd. MUTATION (MU3): the
    // `flutter: assets:` declaration dropped from the pubspec.
    expect(flutterAssets(pubspec), contains(asset),
        reason: 'Flutter bundles only declared assets');
    // The bundle renamed on disk, the declaration and the key left behind:
    // `flutter test` already refuses to build the asset bundle ("No file or
    // variants found for asset"), before this runs. Renamed with its
    // declaration and the key left behind: red on the `contains` above. This
    // line states the third fact for a reader, and for a runner that does
    // not bundle assets.
    expect(File(asset).existsSync(), isTrue, reason: '$asset on disk');
  });

  group('the pubspec reading', () {
    // MUTATION: the `flutter:` section gate dropped -- another section's
    // `assets:` list, here `other:`'s, would be read as Flutter's.
    test('reads only the top-level flutter: assets: list', () {
      const text = 'name: x\n'
          'dependencies:\n'
          '  flutter:\n'
          '    sdk: flutter\n'
          'assets:\n'
          '  - not/this\n'
          'flutter:\n'
          '  uses-material-design: true\n'
          '  assets:\n'
          '    # a comment\n'
          '    - assets/a.bin\n'
          '    - "assets/b.bin" # trailing\n'
          '  fonts:\n'
          '    - family: F\n'
          'other:\n'
          '  assets:\n'
          '    - not/this/either\n';
      expect(pubspecName(text), 'x');
      expect(flutterAssets(text), <String>['assets/a.bin', 'assets/b.bin']);
    });

    test('reads no assets where flutter: declares none', () {
      expect(flutterAssets('name: x\nflutter:\n  uses-material-design: true\n'),
          isEmpty);
      expect(flutterAssets('name: x\n'), isEmpty);
    });
  });
}

/// The top-level `name:` of [pubspec].
///
/// **Line reading, not a YAML parser:** `package:yaml` is not a dependency of
/// this package, and this pubspec's shapes are the plain ones `pub` writes.
String? pubspecName(String pubspec) {
  for (final line in pubspec.split('\n')) {
    final m = RegExp(r'^name:\s*(\S+)').firstMatch(line);
    if (m != null) return m.group(1);
  }
  return null;
}

/// The entries of the top-level `flutter:` section's `assets:` block list in
/// [pubspec], unquoted, comments dropped.
List<String> flutterAssets(String pubspec) {
  final lines = pubspec
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'(^|\s)#.*$'), ''))
      .toList();
  final assets = <String>[];
  var inFlutter = false;
  int? assetsIndent;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final indent = line.length - line.trimLeft().length;
    if (indent == 0) {
      inFlutter = RegExp(r'^flutter:\s*$').hasMatch(line);
      assetsIndent = null;
      continue;
    }
    if (!inFlutter) continue;
    final body = line.trim();
    if (assetsIndent != null && indent > assetsIndent) {
      final m = RegExp(r'''^-\s+(["']?)(.+?)\1\s*$''').firstMatch(body);
      if (m != null) assets.add(m.group(2)!);
      continue;
    }
    assetsIndent = RegExp(r'^assets:\s*$').hasMatch(body) ? indent : null;
  }
  return assets;
}
