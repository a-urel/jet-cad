// Review F-2 (spec 14d M-14d-q): the scripts that give CI its verdict, run
// as CI runs them, by their exit codes. check_host_lock.dart is the GPU
// split's (spec S8, M-G2).
import 'dart:io';

import 'package:test/test.dart';

Future<ProcessResult> dartRun(String script, List<String> args) =>
    Process.run(Platform.resolvedExecutable, ['run', script, ...args]);

const engine = ['--package', 'packages/jet_cad_2d', '--root'];
const engineRoot = '/home/user/jet-cad/packages/jet_cad_2d';

void main() {
  group('expect_failures.dart', () {
    test('SC1 exactly the standing set: exit 0', () async {
      final r = await dartRun('expect_failures.dart', [
        ...engine,
        engineRoot,
        'test/fixtures/engine_run.json',
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('the standing failures and skips, exactly'));
    });

    test('SC2 a difference: exit 1, every difference printed', () async {
      final r = await dartRun('expect_failures.dart', [
        ...engine,
        engineRoot,
        'test/fixtures/vm_skip_run.json',
      ]);
      expect(r.exitCode, 1);
      expect(r.stdout, contains('skipped for want of the VM service'));
      expect(r.stdout, contains('standing failure passed or did not run'));
    });

    test('SC3 a test that failed after it completed: exit 1', () async {
      final r = await dartRun('expect_failures.dart', [
        ...engine,
        engineRoot,
        'test/fixtures/late_failure_run.json',
      ]);
      expect(r.exitCode, 1);
      expect(r.stdout, contains('new failure: '));
    });

    test('SC4 no run to read: a non-zero exit', () async {
      final r = await dartRun('expect_failures.dart', [
        ...engine,
        engineRoot,
        'test/fixtures/no_such_run.json',
      ]);
      expect(r.exitCode, isNot(0));
    });

    test('SC5 bad arguments: exit 2', () async {
      final r = await dartRun('expect_failures.dart', ['a.json']);
      expect(r.exitCode, 2);
    });
  });

  group('check_guide.dart', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('check_guide'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('SC6 the repository\'s guide and probe: exit 0', () async {
      final r = await dartRun('check_guide.dart', const []);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });

    test(
      'SC7 a guide block the probe lacks: exit 1, the block named',
      () async {
        final guide = File('${tmp.path}/guide.md')
          ..writeAsStringSync('```dart\nvoid nowhere() {}\n```\n');
        final r = await dartRun('check_guide.dart', ['--guide', guide.path]);
        expect(r.exitCode, 1);
        expect(r.stdout, contains('not in the host probe: dart: void nowhere'));
      },
    );

    test('SC8 a guide with no code block: exit 1', () async {
      final guide = File('${tmp.path}/guide.md')..writeAsStringSync('# Text\n');
      final r = await dartRun('check_guide.dart', ['--guide', guide.path]);
      expect(r.exitCode, 1);
    });
  });

  group('check_host_lock.dart', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('check_host_lock'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('SC9 the lock after the split, look-alikes and all: exit 0', () async {
      final r = await dartRun('check_host_lock.dart', [
        'test/fixtures/host_post_split.lock.txt',
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('43 packages, none of flutter_scene, '));
    });

    test(
      'SC10 the lock before the split: exit 1, each package named',
      () async {
        final r = await dartRun('check_host_lock.dart', [
          'test/fixtures/host_pre_split.lock.txt',
        ]);
        expect(r.exitCode, 1);
        for (final name in const [
          'flutter_gpu',
          'flutter_gpu_shaders',
          'flutter_scene',
          'scene',
        ]) {
          expect(r.stdout, contains('a host must not resolve $name\n'));
        }
      },
    );

    test('SC11 the GPU package alone: exit 1', () async {
      final green = File(
        'test/fixtures/host_post_split.lock.txt',
      ).readAsStringSync();
      expect(green, contains('\n  jet_cad_2d_flutter:\n'), reason: 'premise');
      final lock = File('${tmp.path}/pubspec.lock')
        ..writeAsStringSync(
          green.replaceFirst(
            '\n  jet_cad_2d_flutter:\n',
            '\n  jet_cad_2d_gpu:\n    source: git\n  jet_cad_2d_flutter:\n',
          ),
        );
      final r = await dartRun('check_host_lock.dart', [lock.path]);
      expect(r.exitCode, 1);
      expect(r.stdout, contains('a host must not resolve jet_cad_2d_gpu'));
    });

    test('SC12 no lock to read, or not a lock: exit 2', () async {
      final missing = await dartRun('check_host_lock.dart', [
        '${tmp.path}/no_such.lock',
      ]);
      expect(missing.exitCode, 2);
      final text = File('${tmp.path}/pubspec.lock')
        ..writeAsStringSync('name: host_probe\n');
      final notLock = await dartRun('check_host_lock.dart', [text.path]);
      expect(notLock.exitCode, 2);
    });

    test('SC13 bad arguments: exit 2', () async {
      expect((await dartRun('check_host_lock.dart', const [])).exitCode, 2);
      expect((await dartRun('check_host_lock.dart', ['a', 'b'])).exitCode, 2);
    });
  });

  test(
    'SC21b --ref on the new probe\'s lock: exit 0, at another exit 1',
    () async {
      const ref = '99ab3f2eb2a20bf1207d4679572103c3520df028';
      const lock = 'test/fixtures/host_probe.lock.txt';
      final ok = await dartRun('check_host_lock.dart', [lock, '--ref', ref]);
      expect(ok.exitCode, 0, reason: '${ok.stdout}${ok.stderr}');
      final bad = await dartRun('check_host_lock.dart', [
        lock,
        '--ref',
        '0000000000000000000000000000000000000000',
      ]);
      expect(bad.exitCode, 1);
      expect(
        bad.stdout,
        contains(
          'jet_cad_2d_plan: git at $ref, not git at '
          '0000000000000000000000000000000000000000',
        ),
      );
    },
  );

  test(
    'SC22 package_root.dart prints a package\'s root from a config',
    () async {
      final dir = Directory.systemTemp.createTempSync('package_root');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/.dart_tool').createSync();
      File('${dir.path}/.dart_tool/package_config.json').writeAsStringSync(
        '{"configVersion":2,"packages":[{"name":"a","rootUri":"../x/a",'
        '"packageUri":"lib/"},{"name":"b","rootUri":"file:///abs/b/",'
        '"packageUri":"lib/"}]}',
      );
      final a = await dartRun('package_root.dart', [dir.path, 'a']);
      expect(a.exitCode, 0, reason: '${a.stdout}${a.stderr}');
      // `../x/a` resolves against `.dart_tool/`, so the root is `<dir>/x/a`.
      expect((a.stdout as String).trim(), endsWith('/x/a'));
      // macOS reaches the temp directory through a symlink (/var, /private/var).
      expect(
        Directory(
          Directory((a.stdout as String).trim()).parent.parent.path,
        ).resolveSymbolicLinksSync(),
        Directory(dir.path).resolveSymbolicLinksSync(),
      );
      final b = await dartRun('package_root.dart', [dir.path, 'b']);
      expect((b.stdout as String).trim(), '/abs/b');
      final none = await dartRun('package_root.dart', [dir.path, 'c']);
      expect(none.exitCode, 2);
    },
  );

  // Task 2 review R-1: CI's probe runs only at HEAD, which is green, so a
  // probe that stopped running the check would pass unseen. Its commands,
  // comments aside, in their order. Sub-project 4a R4: the host probe.
  test(
    'SC14 host_probe.sh checks the lock after pub get, before the build',
    () {
      const script = 'host_probe.sh';
      final commands = [
        for (final line in File(script).readAsLinesSync())
          if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
            line.trim(),
      ];
      int at(String command) {
        final i = commands.indexOf(command);
        expect(i, isNot(-1), reason: '$script runs `$command`');
        return i;
      }

      expect(commands, contains('set -euo pipefail'));
      // The final review's F-3 (MU6): stale output survives a build, so the
      // probe starts clean.
      final clean = at(
        r'rm -rf "$probe/build" "$probe/.dart_tool" "$probe/pubspec.lock"',
      );
      final get = at('flutter pub get');
      expect(clean, lessThan(get), reason: 'cleaned before pub get');
      final check = at(
        r'dart run "$ci/check_host_lock.dart" "$probe/pubspec.lock" '
        r'--ref "$ref"',
      );
      final analyze = at('flutter analyze');
      final build = at('flutter build web');
      expect(
        commands.any((c) => c.contains('package_root.dart')),
        isFalse,
        reason: 'the kits carry their libraries: nothing is copied',
      );
      expect(
        get < check && check < analyze && analyze < build,
        isTrue,
        reason:
            'pub get, the check, analyze, build: $get, $check, '
            '$analyze, $build',
      );
    },
  );

  // The final review's F-3 (MU7): the probe's checks after the build, run
  // as bash runs them, in a scratch probe; one red case per check.
  group('SC15 host_probe.sh after the build', () {
    final script = File('host_probe.sh').readAsStringSync();
    final from = script.indexOf('\nfail=0\n');
    final tail = script.substring(from + 1);

    late Directory probe;
    setUp(() {
      probe = Directory.systemTemp.createTempSync('host_probe_tail');
      Directory(
        '${probe.path}/build/web/assets/packages/jet_cad_2d_flutter',
      ).createSync(recursive: true);
      File(
        '${probe.path}/build/web/main.dart.js',
      ).writeAsStringSync('main();\n');
    });
    tearDown(() => probe.deleteSync(recursive: true));

    Future<ProcessResult> runTail() => Process.run('bash', [
      '-c',
      'set -euo pipefail\n$tail',
    ], workingDirectory: probe.path);

    test('premise: the block is the script\'s last', () {
      expect(from, isNot(-1));
      expect(tail, contains('exit 1'));
      expect(tail, contains('du -sh build/web'));
    });

    test('a clean build: exit 0', () async {
      final r = await runTail();
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('no GPU renderer, no build hook'));
    });

    test('a build hook ran: exit 1, named', () async {
      Directory(
        '${probe.path}/.dart_tool/hooks_runner/flutter_scene',
      ).createSync(recursive: true);
      final r = await runTail();
      expect(r.exitCode, 1);
      expect(r.stderr, contains('a build hook ran (flutter_scene)'));
    });

    test("objective_c's hook, in both layouts, is allowed", () async {
      for (final dir in ['', 'shared/']) {
        Directory(
          '${probe.path}/.dart_tool/hooks_runner/${dir}objective_c',
        ).createSync(recursive: true);
      }
      final r = await runTail();
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });

    test('a name that only starts with objective_c is not', () async {
      Directory(
        '${probe.path}/.dart_tool/hooks_runner/shared/objective_c_x',
      ).createSync(recursive: true);
      final r = await runTail();
      expect(r.exitCode, 1);
      expect(r.stderr, contains('a build hook ran (objective_c_x)'));
    });

    test("flutter_scene's assets: exit 1", () async {
      Directory(
        '${probe.path}/build/web/assets/packages/flutter_scene',
      ).createSync();
      final r = await runTail();
      expect(r.exitCode, 1);
      expect(r.stderr, contains("ships flutter_scene's assets"));
    });

    test('main.dart.js names cad.shaderbundle: exit 1', () async {
      File('${probe.path}/build/web/main.dart.js').writeAsStringSync(
        'load("packages/jet_cad_2d_gpu/assets/shaders/cad.shaderbundle");\n',
      );
      final r = await runTail();
      expect(r.exitCode, 1);
      expect(r.stderr, contains('loads cad.shaderbundle'));
    });

    test('no main.dart.js: exit 1', () async {
      File('${probe.path}/build/web/main.dart.js').deleteSync();
      final r = await runTail();
      expect(r.exitCode, 1);
      expect(r.stderr, contains('has no main.dart.js'));
    });
  });

  // The final review's F-3 (MU4, MU5): ci.yml read as text.
  final workflow = File('../../.github/workflows/ci.yml').readAsStringSync();

  test('SC16 every live package is in the CI matrix', () {
    final listed = RegExp(
      r'^\s+- package: (\S+)$',
      multiLine: true,
    ).allMatches(workflow).map((m) => m[1]).toSet();
    final live = [
      for (final dir in Directory('../../packages').listSync())
        if (dir is Directory &&
            File('${dir.path}/pubspec.yaml').existsSync() &&
            !dir.path.endsWith('/jet_cad')) // dormant, outside CI
          'packages/${dir.uri.pathSegments.where((s) => s.isNotEmpty).last}',
    ];
    expect(live, contains('packages/jet_cad_2d_gpu'), reason: 'premise');
    expect(listed, containsAll(live));
  });

  test("SC17 each app's web build asserts no flutter_scene assets", () {
    final builds = RegExp(
      r'^\s+flutter build web$',
      multiLine: true,
    ).allMatches(workflow).length;
    final asserts = RegExp(
      r'^\s+flutter build web\n\s+test ! -e '
      r'build/web/assets/packages/flutter_scene$',
      multiLine: true,
    ).allMatches(workflow).length;
    expect(builds, 1, reason: 'premise: the restaurant demo');
    expect(asserts, builds);
    expect(
      workflow,
      contains(
        'run: tool/ci/host_probe.sh "file://\$GITHUB_WORKSPACE" '
        '"\$(git rev-parse HEAD)"',
      ),
    );
  });

  // 2b Task 14: the plan library's pick and band allocation tests read the
  // VM's allocation profiler too; without the flag they skip, which the
  // standing comparison reads as red.
  test('SC20b the plan library\'s tests run with --enable-vmservice', () {
    final entry = workflow.indexOf('- package: packages/jet_cad_2d_plan');
    expect(entry, isNot(-1));
    final next = workflow.indexOf('- package: ', entry + 1);
    expect(
      workflow.substring(entry, next),
      contains('\n            test_flags: --enable-vmservice\n'),
    );
  });

  // 3a Task 9: the integration package carries the paint-allocation
  // invariant over the sample flat (spec 3a C6), which reads the VM's
  // allocation profiler; without the flag it skips, which the standing
  // comparison reads as red.
  test(
    'SC20c the integration package\'s tests run with --enable-vmservice',
    () {
      final entry = workflow.indexOf(
        '- package: packages/jet_cad_2d_integration',
      );
      expect(entry, isNot(-1));
      final next = workflow.indexOf('- package: ', entry + 1);
      expect(next, isNot(-1), reason: 'premise: not the matrix\'s last entry');
      expect(
        workflow.substring(entry, next),
        contains('\n            test_flags: --enable-vmservice\n'),
      );
    },
  );
}
