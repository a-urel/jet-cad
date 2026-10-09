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
      final r = await dartRun('expect_failures.dart',
          [...engine, engineRoot, 'test/fixtures/engine_run.json']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('the standing failures and skips, exactly'));
    });

    test('SC2 a difference: exit 1, every difference printed', () async {
      final r = await dartRun('expect_failures.dart',
          [...engine, engineRoot, 'test/fixtures/vm_skip_run.json']);
      expect(r.exitCode, 1);
      expect(r.stdout, contains('skipped for want of the VM service'));
      expect(r.stdout, contains('standing failure passed or did not run'));
    });

    test('SC3 a test that failed after it completed: exit 1', () async {
      final r = await dartRun('expect_failures.dart',
          [...engine, engineRoot, 'test/fixtures/late_failure_run.json']);
      expect(r.exitCode, 1);
      expect(r.stdout, contains('new failure: '));
    });

    test('SC4 no run to read: a non-zero exit', () async {
      final r = await dartRun('expect_failures.dart',
          [...engine, engineRoot, 'test/fixtures/no_such_run.json']);
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

    test('SC7 a guide block the probe lacks: exit 1, the block named',
        () async {
      final guide = File('${tmp.path}/guide.md')
        ..writeAsStringSync('```dart\nvoid nowhere() {}\n```\n');
      final r = await dartRun('check_guide.dart', ['--guide', guide.path]);
      expect(r.exitCode, 1);
      expect(r.stdout, contains('not in the host probe: dart: void nowhere'));
    });

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
      final r = await dartRun(
          'check_host_lock.dart', ['test/fixtures/host_post_split.lock.txt']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('43 packages, none of flutter_scene, '));
    });

    test('SC10 the lock before the split: exit 1, each package named',
        () async {
      final r = await dartRun(
          'check_host_lock.dart', ['test/fixtures/host_pre_split.lock.txt']);
      expect(r.exitCode, 1);
      for (final name in const [
        'flutter_gpu',
        'flutter_gpu_shaders',
        'flutter_scene',
        'scene',
      ]) {
        expect(r.stdout, contains('a host must not resolve $name\n'));
      }
    });

    test('SC11 the GPU package alone: exit 1', () async {
      final green =
          File('test/fixtures/host_post_split.lock.txt').readAsStringSync();
      expect(green, contains('\n  jet_cad_2d_flutter:\n'), reason: 'premise');
      final lock = File('${tmp.path}/pubspec.lock')
        ..writeAsStringSync(green.replaceFirst('\n  jet_cad_2d_flutter:\n',
            '\n  jet_cad_2d_gpu:\n    source: git\n  jet_cad_2d_flutter:\n'));
      final r = await dartRun('check_host_lock.dart', [lock.path]);
      expect(r.exitCode, 1);
      expect(r.stdout, contains('a host must not resolve jet_cad_2d_gpu'));
    });

    test('SC12 no lock to read, or not a lock: exit 2', () async {
      final missing =
          await dartRun('check_host_lock.dart', ['${tmp.path}/no_such.lock']);
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

  // Task 2 review R-1: CI's probe runs only at HEAD, which is green, so a
  // probe that stopped running the check would pass unseen. Its commands,
  // comments aside, in their order.
  test('SC14 host_probe.sh checks the lock after pub get, before the build',
      () {
    final commands = [
      for (final line in File('host_probe.sh').readAsLinesSync())
        if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
          line.trim(),
    ];
    int at(String command) {
      final i = commands.indexOf(command);
      expect(i, isNot(-1), reason: 'host_probe.sh runs `$command`');
      return i;
    }

    expect(commands, contains('set -euo pipefail'));
    // The final review's F-3 (MU6): stale output survives a build, so the
    // probe starts clean.
    final clean =
        at(r'rm -rf "$probe/build" "$probe/.dart_tool" "$probe/pubspec.lock"');
    final get = at('flutter pub get');
    expect(clean, lessThan(get), reason: 'cleaned before pub get');
    final check =
        at(r'dart run "$ci/check_host_lock.dart" "$probe/pubspec.lock"');
    final analyze = at('flutter analyze');
    final build = at('flutter build web');
    expect(get < check && check < analyze && analyze < build, isTrue,
        reason: 'pub get, the check, analyze, build: $get, $check, '
            '$analyze, $build');
  });

  // The final review's F-3 (MU7): the probe's checks after the build, run
  // as bash runs them, in a scratch probe; one red case per check.
  group('SC15 host_probe.sh after the build', () {
    final script = File('host_probe.sh').readAsStringSync();
    final from = script.indexOf('\nfail=0\n');
    final tail = script.substring(from + 1);

    late Directory probe;
    setUp(() {
      probe = Directory.systemTemp.createTempSync('host_probe_tail');
      Directory('${probe.path}/build/web/assets/packages/jet_cad_floor_plan')
          .createSync(recursive: true);
      File('${probe.path}/build/web/main.dart.js')
          .writeAsStringSync('main();\n');
    });
    tearDown(() => probe.deleteSync(recursive: true));

    Future<ProcessResult> runTail() =>
        Process.run('bash', ['-c', 'set -euo pipefail\n$tail'],
            workingDirectory: probe.path);

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

    test('a build hook ran: exit 1', () async {
      Directory('${probe.path}/.dart_tool/hooks_runner')
          .createSync(recursive: true);
      final r = await runTail();
      expect(r.exitCode, 1);
      expect(r.stderr, contains('a build hook ran'));
    });

    test("flutter_scene's assets: exit 1", () async {
      Directory('${probe.path}/build/web/assets/packages/flutter_scene')
          .createSync();
      final r = await runTail();
      expect(r.exitCode, 1);
      expect(r.stderr, contains("ships flutter_scene's assets"));
    });

    test('main.dart.js names cad.shaderbundle: exit 1', () async {
      File('${probe.path}/build/web/main.dart.js').writeAsStringSync(
          'load("packages/jet_cad_2d_gpu/assets/shaders/cad.shaderbundle");\n');
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
    final listed = RegExp(r'^\s+- package: (\S+)$', multiLine: true)
        .allMatches(workflow)
        .map((m) => m[1])
        .toSet();
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
    final builds = RegExp(r'^\s+flutter build web$', multiLine: true)
        .allMatches(workflow)
        .length;
    final asserts = RegExp(
            r'^\s+flutter build web\n\s+test ! -e '
            r'build/web/assets/packages/flutter_scene$',
            multiLine: true)
        .allMatches(workflow)
        .length;
    expect(builds, 2, reason: 'premise: the demo and the floor planner');
    expect(asserts, builds);
    expect(
        workflow,
        contains('run: tool/ci/host_probe.sh "file://\$GITHUB_WORKSPACE" '
            '"\$(git rev-parse HEAD)"'));
  });

  // Host embedding API spec, invariant 1 (P-1): the host-probe job also
  // analyses the 0.3.0 probe against the commit under test, after the
  // probe is resolved there, from a checkout that has the tag.
  test('SC18 the host-probe job analyses the 0.3.0 probe, with the tags', () {
    final from = workflow.indexOf('\n  host-probe:\n');
    expect(from, isNot(-1), reason: 'premise: the job');
    final next = RegExp(r'^  \S', multiLine: true)
        .allMatches(workflow, from + 2)
        .where((m) => m.start > from + 2)
        .firstOrNull;
    final job = workflow.substring(from, next?.start ?? workflow.length);
    expect(
        job,
        contains('      - uses: actions/checkout@v5\n'
            '        with:\n'
            '          fetch-depth: 0\n'),
        reason: 'the whole history: the tag is in the clone');
    final probe = job.indexOf('run: tool/ci/host_probe.sh ');
    final old = job.indexOf('run: tool/ci/old_host_probe.sh v0.3.0\n');
    expect(probe, isNot(-1));
    expect(old, greaterThan(probe), reason: 'after the probe is resolved');
  });

  // Slice 2's final review F-2: the planner's pick allocation test reads
  // the VM's allocation profiler, which `flutter test` serves only with
  // `--enable-vmservice`; without it the test skips, and the standing
  // comparison reads that as red. The flag is the planner's, passed to the
  // one test step every package runs.
  test('SC20 the planner\'s tests run with --enable-vmservice', () {
    expect(
        workflow,
        contains('          - package: packages/jet_cad_floor_plan\n'
            '            tool: flutter\n'));
    final entry = workflow.indexOf('- package: packages/jet_cad_floor_plan');
    final next = workflow.indexOf('- package: ', entry + 1);
    expect(workflow.substring(entry, next),
        contains('\n            test_flags: --enable-vmservice\n'));
    expect(
        workflow,
        contains('run: \${{ matrix.tool }} test \${{ matrix.test_flags }} '
            '--file-reporter "json:\$RUNNER_TEMP/tests.json" || true\n'));
  });

  // The script itself, run by bash in a scratch repository with the tag
  // and a stand-in `flutter` that records what it analysed.
  group('SC19 old_host_probe.sh', () {
    late Directory repo;
    late File main;
    late File seen;
    const tagged = 'void main() {} // as v0.3.0 had it\n';
    const current = 'void main() {} // this commit\n';

    Future<ProcessResult> git(List<String> args) async {
      final r = await Process.run('git', args, workingDirectory: repo.path);
      expect(r.exitCode, 0, reason: 'git $args: ${r.stderr}');
      return r;
    }

    Future<ProcessResult> runScript({required int flutterExit}) {
      final bin = Directory('${repo.path}/bin')..createSync();
      File('${bin.path}/flutter')
        ..writeAsStringSync('#!/usr/bin/env bash\n'
            'cp lib/main.dart "${seen.path}"\n'
            'echo "flutter \$*"\n'
            'exit $flutterExit\n')
        ..createSync();
      Process.runSync('chmod', ['+x', '${bin.path}/flutter']);
      return Process.run('bash', ['tool/ci/old_host_probe.sh', 'v0.3.0'],
          workingDirectory: repo.path,
          environment: {
            'PATH': '${bin.path}:${Platform.environment['PATH']}',
          });
    }

    setUp(() async {
      repo = Directory.systemTemp.createTempSync('old_host_probe');
      seen = File('${repo.path}/seen.dart');
      Directory('${repo.path}/tool/ci/host_probe/lib')
          .createSync(recursive: true);
      File('old_host_probe.sh').copySync('${repo.path}/tool/ci/'
          'old_host_probe.sh');
      main = File('${repo.path}/tool/ci/host_probe/lib/main.dart')
        ..writeAsStringSync(tagged);
      await git(['init', '-q']);
      await git(['add', 'tool']);
      await git([
        '-c', 'user.name=t', '-c', 'user.email=t@t', //
        'commit', '-q', '-m', 'release',
      ]);
      await git(['tag', 'v0.3.0']);
      // A later commit, so the tag is not HEAD.
      main.writeAsStringSync(current);
      await git([
        '-c', 'user.name=t', '-c', 'user.email=t@t', //
        'commit', '-q', '-am', 'later',
      ]);
    });
    tearDown(() => repo.deleteSync(recursive: true));

    test('no resolved probe: exit 2, main.dart untouched', () async {
      final r = await runScript(flutterExit: 0);
      expect(r.exitCode, 2);
      expect(r.stderr, contains('run tool/ci/host_probe.sh first'));
      expect(main.readAsStringSync(), current);
      expect(seen.existsSync(), isFalse);
    });

    test("the tag's main.dart analysed; this commit's put back", () async {
      File('${repo.path}/tool/ci/host_probe/pubspec.lock')
          .writeAsStringSync('packages: {}\n');
      final r = await runScript(flutterExit: 0);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('flutter analyze'));
      expect(r.stdout, contains("old host probe: v0.3.0's main.dart"));
      expect(seen.readAsStringSync(), tagged);
      expect(main.readAsStringSync(), current);
    });

    test('analysis fails: exit non-zero, main.dart put back', () async {
      File('${repo.path}/tool/ci/host_probe/pubspec.lock')
          .writeAsStringSync('packages: {}\n');
      final r = await runScript(flutterExit: 1);
      expect(r.exitCode, 1);
      expect(seen.readAsStringSync(), tagged);
      expect(main.readAsStringSync(), current);
    });
  });
}
