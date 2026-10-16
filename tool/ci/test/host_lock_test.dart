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
  'jet_cad_2d_gpu': entryOf(
    green,
    'jet_cad_2d_flutter',
  ).replaceAll('jet_cad_2d_flutter', 'jet_cad_2d_gpu'),
};

void main() {
  test('HL1 the lock after the split: its packages, and none forbidden', () {
    final packages = lockPackages(green);
    expect(
      packages,
      hasLength(43),
      reason: 'the 40 the probe resolved at 2b35b69, and three look-alikes',
    );
    expect(
      packages,
      containsAll([
        'jet_cad_floor_plan',
        'jet_cad_restaurant_symbols',
        'jet_cad_2d',
        'jet_cad_2d_flutter',
        'my_flutter_scene_tools',
        'my_scene',
        'scene_x',
      ]),
    );
    expect(packages, isNot(contains('sdks')), reason: 'a top-level key');
    expect(packages, isNot(contains('dart')), reason: 'a key under sdks:');
    expect(forbiddenInLock(green), isEmpty);
  });

  test(
    'HL2 every forbidden name is in the green lock as text, none as a key',
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
      expect(
        green,
        contains('description: name: flutter_scene'),
        reason: 'premise: a pubspec.lock line, as text, in a string',
      );
    },
  );

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
        expect(lockPackages(red), hasLength(44), reason: 'premise');
        expect(lockPackages(red), contains(name), reason: 'premise');
        expect(forbiddenInLock(red), [name]);
      });
    }
  });

  test('HL4 the lock before the split names flutter_scene and its own', () {
    final packages = lockPackages(preSplit);
    expect(packages, hasLength(53), reason: 'what the probe resolved');
    expect(
      packages,
      containsAll(['hooks', 'code_assets', 'data_assets']),
      reason: 'F-6: what the build hook brought',
    );
    expect(forbiddenInLock(preSplit), [
      'flutter_gpu',
      'flutter_gpu_shaders',
      'flutter_scene',
      'scene',
    ]);
  });

  test('HL5 a forbidden name as a key elsewhere than under packages: is not '
      'a package', () {
    final elsewhere = green
        .replaceFirst(
          '      name: scene_x\n',
          '      name: scene_x\n      flutter_gpu: "0.0.0"\n',
        )
        .replaceFirst('sdks:\n', 'sdks:\n  scene: ">=0.3.0"\n');
    expect(
      elsewhere,
      contains('      flutter_gpu: "0.0.0"\n'),
      reason: 'premise: a field of a package',
    );
    expect(
      elsewhere,
      contains('sdks:\n  scene: '),
      reason: 'premise: a key under sdks:',
    );
    expect(forbiddenInLock(elsewhere), isEmpty);
    expect(lockPackages(elsewhere), lockPackages(green));
  });

  test('HL6 a quoted key is the same key', () {
    final quoted = withEntry(
      green,
      'scene',
      entries['scene']!.replaceFirst('  scene:', '  "scene":'),
    );
    expect(quoted, contains('\n  "scene":\n'), reason: 'premise');
    expect(forbiddenInLock(quoted), ['scene']);
  });

  test('HL7 text that is not a lock is an error, an empty map is not', () {
    expect(
      () => lockPackages('# Generated by pub\nsdks:\n  dart: ">=3"\n'),
      throwsFormatException,
    );
    expect(() => lockPackages(''), throwsFormatException);
    expect(lockPackages('packages: {}\nsdks:\n  dart: ">=3"\n'), isEmpty);
    expect(
      lockPackages('packages: {} # none\nsdks:\n  dart: ">=3"\n'),
      isEmpty,
    );
  });

  test('HL8 a layout pub never writes is an error, not a clean lock '
      '(Task 2 review R-3)', () {
    // A flow map: its keys are on the packages: line itself.
    expect(
      () => lockPackages('packages: {flutter_scene: {}}\n'),
      throwsFormatException,
    );
    // A key indented less than the first: read as a field, it would hide
    // flutter_scene.
    final shallow = withEntry(
      green,
      'flutter_scene',
      entries['flutter_scene']!.replaceFirst(
        '  flutter_scene:',
        ' flutter_scene:',
      ),
    );
    expect(shallow, contains('\n flutter_scene:\n'), reason: 'premise');
    expect(() => lockPackages(shallow), throwsFormatException);
  });

  group('HL-C the old probe\'s four packages come from the commit', () {
    const ref = '2b35b69931d6acdb03c219a38c923a8fd3fdc50c';

    test('HL-C1 the green lock: all four from git at the ref', () {
      expect(notFromCommit(green, ref, packages: oldProbedFromCommit), isEmpty);
      expect(lockEntryFields(green, 'jet_cad_2d'), {
        'source': 'git',
        'resolved-ref': ref,
      });
    });

    test('HL-C2 another ref: each of the four named', () {
      const other = '0000000000000000000000000000000000000000';
      expect(
        notFromCommit(green, other, packages: oldProbedFromCommit),
        hasLength(4),
      );
      expect(
        notFromCommit(green, other, packages: oldProbedFromCommit).first,
        contains('jet_cad_2d'),
      );
    });

    // The named mutant of spec D6: one override dropped, so pub took the
    // package from pub.dev.
    for (final name in [
      'jet_cad_2d',
      'jet_cad_2d_flutter',
      'jet_cad_floor_plan',
      'jet_cad_restaurant_symbols',
    ]) {
      test('HL-C3 $name hosted: named', () {
        final entry = entryOf(green, name);
        final hostedEntry = [
          '  $name:',
          '    dependency: transitive',
          '    description:',
          '      name: $name',
          '      sha256: "0000"',
          '      url: "https://pub.dev"',
          '    source: hosted',
          '    version: "0.7.1"',
        ].join('\n');
        final lock = green.replaceFirst(entry, hostedEntry);
        expect(lock, isNot(green), reason: 'premise');
        expect(notFromCommit(lock, ref, packages: oldProbedFromCommit), [
          contains(name),
        ]);
      });
    }

    // A hosted entry carries no resolved-ref, so HL-C3 alone cannot tell the
    // source test from the ref test: this one keeps the ref and changes only
    // the source.
    test('HL-C3b the right ref under another source: named', () {
      final entry = entryOf(green, 'jet_cad_floor_plan');
      final lock = green.replaceFirst(
        entry,
        entry.replaceFirst('source: git', 'source: path'),
      );
      expect(lock, isNot(green), reason: 'premise');
      expect(notFromCommit(lock, ref, packages: oldProbedFromCommit), [
        contains('jet_cad_floor_plan'),
      ]);
    });

    test('HL-C4 a package missing from the lock: named', () {
      final lock = green.replaceFirst(
        '${entryOf(green, 'jet_cad_restaurant_symbols')}\n',
        '',
      );
      expect(notFromCommit(lock, ref, packages: oldProbedFromCommit), [
        contains('jet_cad_restaurant_symbols'),
      ]);
    });
  });

  // Sub-project 4a R4: the host probe of the plan library and the kits. Its
  // lock is a real one (tool/ci/host_probe.sh, run on a commit of the task's
  // own, whose sha is the ref below), with the path of the clone made the old
  // fixtures' `/home/user/jet-cad`.
  group('HL-N the new probe\'s six packages come from the commit', () {
    final fresh = fixture('host_probe.lock.txt');
    const ref = '99ab3f2eb2a20bf1207d4679572103c3520df028';
    const six = [
      'jet_cad_2d',
      'jet_cad_2d_flutter',
      'jet_cad_2d_kit',
      'jet_cad_2d_kit_architecture',
      'jet_cad_2d_kit_restaurant',
      'jet_cad_2d_plan',
    ];

    test('HL-N1 the probe\'s lock: the six, none forbidden, none old', () {
      final packages = lockPackages(fresh);
      expect(packages, containsAll(six));
      expect(packages, isNot(contains('jet_cad_floor_plan')));
      expect(packages, isNot(contains('jet_cad_restaurant_symbols')));
      expect(forbiddenInLock(fresh), isEmpty);
      expect(probedFromCommit, six, reason: 'the list under test');
    });

    test('HL-N2 all six from git at the ref; another ref names each', () {
      expect(notFromCommit(fresh, ref), isEmpty);
      const other = '0000000000000000000000000000000000000000';
      expect(notFromCommit(fresh, other), hasLength(6));
    });

    for (final name in six) {
      test('HL-N3 $name hosted: named', () {
        final entry = entryOf(fresh, name);
        final hostedEntry = [
          '  $name:',
          '    dependency: transitive',
          '    description:',
          '      name: $name',
          '      sha256: "0000"',
          '      url: "https://pub.dev"',
          '    source: hosted',
          '    version: "0.7.1"',
        ].join('\n');
        final lock = fresh.replaceFirst(entry, hostedEntry);
        expect(lock, isNot(fresh), reason: 'premise');
        expect(notFromCommit(lock, ref), [contains(name)]);
      });
    }

    test('HL-N4 the old probe\'s lock fails the new list, and the reverse', () {
      expect(
        notFromCommit(green, '2b35b69931d6acdb03c219a38c923a8fd3fdc50c'),
        hasLength(4),
      );
      expect(
        notFromCommit(fresh, ref, packages: oldProbedFromCommit),
        hasLength(2),
      );
    });
  });
}
