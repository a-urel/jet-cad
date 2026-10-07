// GPU split spec S8, M-G2 (review V-2): the host lock's guard on the host
// probe's locks as tool/ci/host_probe.sh recorded them, before the split
// and after it. The red cases are the green lock with one forbidden
// package's entry put in, one case per name; the names are spelled here,
// not read from the list under test, so a name dropped from that list
// leaves its own case red.
import 'dart:io';

import 'package:test/test.dart';

import 'package:jet_cad_ci/host_lock.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

final green = fixture('host_post_split.lock.txt');
final preSplit = fixture('host_pre_split.lock.txt');

/// The entry of the package [name] in [lock]: its key line and its
/// fields, up to the next key.
String entryOf(String lock, String name) {
  final lines = lock.split('\n');
  final start = lines.indexOf('  $name:');
  expect(start, isNot(-1), reason: 'premise: $name in the lock');
  var end = start + 1;
  while (lines[end].startsWith('    ')) {
    end++;
  }
  return lines.sublist(start, end).join('\n');
}

/// [lock] with [entry] (the package [name]'s) put in where pub would write
/// it: before the first key that sorts after [name].
String withEntry(String lock, String name, String entry) {
  final lines = lock.split('\n');
  final packages = lines.indexOf('packages:');
  var at = packages + 1;
  while (!lines[at].startsWith(RegExp(r'\S'))) {
    final key = RegExp(r'^  ([^\s:]+):$').firstMatch(lines[at]);
    if (key != null && key[1]!.compareTo(name) > 0) break;
    at++;
  }
  return [...lines.sublist(0, at), entry, ...lines.sublist(at)].join('\n');
}

/// The entries of the four packages `flutter_scene` brought, as the
/// pre-split lock has them; the GPU package's is the render package's
/// entry, renamed, as a git dependency would write it.
final entries = {
  for (final name in [
    'flutter_scene',
    'flutter_gpu',
    'flutter_gpu_shaders',
    'scene',
  ])
    name: entryOf(preSplit, name),
  'jet_cad_2d_gpu': entryOf(green, 'jet_cad_2d_flutter')
      .replaceAll('jet_cad_2d_flutter', 'jet_cad_2d_gpu'),
};

void main() {
  test('HL1 the lock after the split: its packages, and none forbidden', () {
    final packages = lockPackages(green);
    expect(packages, hasLength(42),
        reason: 'the 40 the probe resolved at 2b35b69, and two look-alikes');
    expect(
        packages,
        containsAll([
          'jet_cad_floor_plan',
          'jet_cad_restaurant_symbols',
          'jet_cad_2d',
          'jet_cad_2d_flutter',
          'my_flutter_scene_tools',
          'scene_x',
        ]));
    expect(packages, isNot(contains('sdks')), reason: 'a top-level key');
    expect(packages, isNot(contains('dart')), reason: 'a key under sdks:');
    expect(forbiddenInLock(green), isEmpty);
  });

  test('HL2 every forbidden name is in the green lock as text, none as a key',
      () {
    for (final name in const [
      'flutter_scene',
      'flutter_gpu',
      'flutter_gpu_shaders',
      'scene',
      'jet_cad_2d_gpu',
    ]) {
      expect(green, contains(name), reason: 'premise: $name as text');
      expect(lockPackages(green), isNot(contains(name)));
    }
    expect(green, contains('description: name: flutter_scene'),
        reason: 'premise: a pubspec.lock line, as text, in a string');
  });

  group('HL3 one forbidden package put in the green lock is named', () {
    for (final name in const [
      'flutter_scene',
      'flutter_gpu',
      'flutter_gpu_shaders',
      'scene',
      'jet_cad_2d_gpu',
    ]) {
      test(name, () {
        final red = withEntry(green, name, entries[name]!);
        expect(lockPackages(red), hasLength(43), reason: 'premise');
        expect(lockPackages(red), contains(name), reason: 'premise');
        expect(forbiddenInLock(red), [name]);
      });
    }
  });

  test('HL4 the lock before the split names flutter_scene and its own', () {
    final packages = lockPackages(preSplit);
    expect(packages, hasLength(53), reason: 'what the probe resolved');
    expect(packages, containsAll(['hooks', 'code_assets', 'data_assets']),
        reason: 'F-6: what the build hook brought');
    expect(forbiddenInLock(preSplit),
        ['flutter_gpu', 'flutter_gpu_shaders', 'flutter_scene', 'scene']);
  });

  test(
      'HL5 a forbidden name as a key elsewhere than under packages: is not '
      'a package', () {
    final elsewhere = green
        .replaceFirst('      name: scene_x\n',
            '      name: scene_x\n      flutter_gpu: "0.0.0"\n')
        .replaceFirst('sdks:\n', 'sdks:\n  scene: ">=0.3.0"\n');
    expect(elsewhere, contains('      flutter_gpu: "0.0.0"\n'),
        reason: 'premise: a field of a package');
    expect(elsewhere, contains('sdks:\n  scene: '),
        reason: 'premise: a key under sdks:');
    expect(forbiddenInLock(elsewhere), isEmpty);
    expect(lockPackages(elsewhere), lockPackages(green));
  });

  test('HL6 a quoted key is the same key', () {
    final quoted = withEntry(green, 'scene',
        entries['scene']!.replaceFirst('  scene:', '  "scene":'));
    expect(quoted, contains('\n  "scene":\n'), reason: 'premise');
    expect(forbiddenInLock(quoted), ['scene']);
  });

  test('HL7 text that is not a lock is an error, an empty map is not', () {
    expect(() => lockPackages('# Generated by pub\nsdks:\n  dart: ">=3"\n'),
        throwsFormatException);
    expect(() => lockPackages(''), throwsFormatException);
    expect(lockPackages('packages: {}\nsdks:\n  dart: ">=3"\n'), isEmpty);
  });
}
