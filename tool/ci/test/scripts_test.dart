// Review F-2 (spec 14d M-14d-q): the two scripts that give CI its verdict,
// run as CI runs them, by their exit codes.
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
}
