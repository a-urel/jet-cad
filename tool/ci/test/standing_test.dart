// Spec 14d M-14d-q (revision 2, V-6): the standing comparison on runs
// recorded from both reporters -- `dart test` (the engine: relative suite
// paths, `failure`) and `flutter test` (the render package: absolute
// paths, `error`, a skipped suite) -- and a real VM-service skip. Each
// case edits a recorded run the way a regression would.
import 'dart:io';

import 'package:test/test.dart';

import 'package:jet_cad_ci/standing.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

const engineRoot = '/home/user/jet-cad/packages/jet_cad_2d';
const renderRoot = '/home/user/jet-cad/packages/jet_cad_2d_flutter';

const engineFailures = {
  'test/testing/generate_document_test.dart :: the default document is '
      'the one Plan 2 measured, byte for byte',
  'test/testing/generate_document_test.dart :: both text fractions '
      'default to zero and change nothing',
};
const renderFailures = {
  'test/golden/text_lod_ladder_golden_test.dart :: text lod ladder rung 1 '
      '(RenderBackend.canvas)',
  'test/golden/text_lod_ladder_golden_test.dart :: text lod ladder rung 2 '
      '(RenderBackend.canvas)',
};
const renderSkips = {'test/rig/paint_microbench_test.dart :: (suite)'};

/// [run] with the `testDone` line of the test named [name] rewritten by
/// [edit]: how a test starts or stops failing, or gets skipped.
String editDone(String run, String name, String Function(String) edit) {
  final lines = run.split('\n');
  final start = lines.indexWhere(
      (l) => l.contains('"type":"testStart"') && l.contains('"name":"$name"'));
  expect(start, isNot(-1), reason: 'premise: $name in the run');
  final id = RegExp(r'"id":(\d+)').firstMatch(lines[start])![1];
  final done = lines.indexWhere(
      (l) => l.contains('"testID":$id,') && l.contains('"testDone"'));
  expect(done, isNot(-1), reason: 'premise: $name finished');
  lines[done] = edit(lines[done]);
  return lines.join('\n');
}

/// [run] as if the test named [name] passed: its end says success and its
/// error events are gone.
String passes(String run, String name) {
  final start = run.split('\n').firstWhere(
      (l) => l.contains('"type":"testStart"') && l.contains('"name":"$name"'));
  final id = RegExp(r'"id":(\d+)').firstMatch(start)![1];
  final edited = editDone(
      run,
      name,
      (l) => l.replaceFirst(
          RegExp(r'"result":"(failure|error)"'), '"result":"success"'));
  return edited
      .split('\n')
      .where(
          (l) => !(l.contains('"testID":$id,') && l.contains('"type":"error"')))
      .join('\n');
}

void main() {
  group('the engine run (dart test)', () {
    final run = fixture('engine_run.json');

    test('ST1 exactly the standing failures: ok', () {
      final o = compareRun(run,
          root: engineRoot, failures: engineFailures, skips: const {});
      expect(o.report(), isEmpty);
      expect(o.ok, isTrue);
      expect(o.tests, greaterThan(2), reason: 'premise: passing tests too');
    });

    test('ST2 a new failure is red', () {
      final broken = editDone(
          run,
          'a version-3 document loads under the version-4 build',
          (l) => l.replaceFirst('"result":"success"', '"result":"failure"'));
      final o = compareRun(broken,
          root: engineRoot, failures: engineFailures, skips: const {});
      expect(o.ok, isFalse);
      expect(o.newFailures, [
        'test/codec/schema_v3_fixture_test.dart :: a version-3 document '
            'loads under the version-4 build'
      ]);
    });

    test('ST3 a standing failure that passes is red (the list is stale)', () {
      final passing =
          passes(run, 'both text fractions default to zero and change nothing');
      final o = compareRun(passing,
          root: engineRoot, failures: engineFailures, skips: const {});
      expect(o.ok, isFalse);
      expect(o.fixed, hasLength(1));
      expect(o.newFailures, isEmpty);
    });

    test('ST4 a standing failure that no longer runs is red', () {
      final o = compareRun(run, root: engineRoot, failures: {
        ...engineFailures,
        'test/testing/generate_document_test.dart :: a test since removed',
      }, skips: const {});
      expect(o.ok, isFalse);
      expect(o.fixed, [
        'test/testing/generate_document_test.dart :: a test '
            'since removed'
      ]);
    });

    test('ST5 an extra skip is red', () {
      final skipped = editDone(
          run,
          'a version-3 document loads under the version-4 build',
          (l) => l.replaceFirst('"skipped":false', '"skipped":true'));
      final o = compareRun(skipped,
          root: engineRoot, failures: engineFailures, skips: const {});
      expect(o.ok, isFalse);
      expect(o.newSkips, hasLength(1));
    });

    test('ST6 a run that did not end is red', () {
      final truncated =
          run.split('\n').where((l) => !l.contains('"type":"done"')).join('\n');
      final o = compareRun(truncated,
          root: engineRoot, failures: engineFailures, skips: const {});
      expect(o.ok, isFalse);
      expect(o.ended, isFalse);
    });

    test('ST7 a run with no test is red', () {
      final o = compareRun('{"success":true,"type":"done","time":1}',
          root: engineRoot, failures: const {}, skips: const {});
      expect(o.ok, isFalse);
      expect(o.tests, 0);
    });

    test('ST8 a loader that fails is a new failure', () {
      final broken = editDone(
          run,
          'loading test/codec/schema_v3_fixture_test.dart',
          (l) => l.replaceFirst('"result":"success"', '"result":"error"'));
      final o = compareRun(broken,
          root: engineRoot, failures: engineFailures, skips: const {});
      expect(
          o.newFailures,
          contains(startsWith('test/codec/schema_v3_fixture_test.dart :: '
              'loading')));
    });
  });

  group('the render run (flutter test)', () {
    final run = fixture('render_run.json');

    test(
        'ST9 absolute paths, error results and a skipped suite read as '
        'the standing set', () {
      expect(run, contains('"path":"$renderRoot/test/'),
          reason: 'premise: absolute suite paths');
      expect(run, contains('"result":"error"'), reason: 'premise');
      final o = compareRun(run,
          root: renderRoot, failures: renderFailures, skips: renderSkips);
      expect(o.report(), isEmpty);
      expect(o.ok, isTrue);
    });

    test(
        'ST10 the standing skip missing from the list is red; listed but '
        'run is red', () {
      expect(
          compareRun(run,
              root: renderRoot,
              failures: renderFailures,
              skips: const {}).newSkips,
          renderSkips.toList());
      final ran = editDone(run, '(suite)',
          (l) => l.replaceFirst('"skipped":true', '"skipped":false'));
      final o = compareRun(ran,
          root: renderRoot, failures: renderFailures, skips: renderSkips);
      expect(o.ok, isFalse);
      expect(o.ranSkips, renderSkips.toList());
    });
  });

  group('a skip for want of the VM service', () {
    final run = fixture('vm_skip_run.json');
    const probe =
        'test/invariants/zz_vm_skip_probe_test.dart :: allocation probe';

    test('ST11 red when not listed', () {
      final o = compareRun(run,
          root: engineRoot, failures: const {}, skips: const {});
      expect(o.ok, isFalse);
      expect(o.vmSkips, [probe]);
      expect(o.newSkips, [probe]);
    });

    test('ST12 red even when listed', () {
      final o = compareRun(run,
          root: engineRoot, failures: const {}, skips: const {probe});
      expect(o.newSkips, isEmpty, reason: 'premise: listed');
      expect(o.ok, isFalse);
      expect(o.vmSkips, [probe]);
    });
  });

  group('failures reported apart from a test\'s end (review F-1)', () {
    final run = fixture('late_failure_run.json');
    const late = 'test/zz_late_failure_probe_test.dart :: fails after it '
        'completed';

    test('ST15 a test that fails after it completed is a new failure', () {
      expect(
          run,
          contains('"testID":3,"result":"success","skipped":false,'
              '"hidden":false,"type":"testDone"'),
          reason: 'premise: its end said success');
      final o = compareRun(run,
          root: engineRoot, failures: const {}, skips: const {});
      expect(o.ok, isFalse);
      expect(o.newFailures, [late]);
    });

    test('ST16 a run that failed with no test failing is red', () {
      final unattributed = run
          .split('\n')
          .where((l) => !l.contains('"type":"error"'))
          .join('\n');
      expect(unattributed, contains('{"success":false,"type":"done"'),
          reason: 'premise: the run said it failed');
      final o = compareRun(unattributed,
          root: engineRoot, failures: const {}, skips: const {});
      expect(o.newFailures, isEmpty, reason: 'premise: nothing attributed');
      expect(o.unexplained, isTrue);
      expect(o.ok, isFalse);
    });

    test('ST17 a failed run whose failures are all standing is explained', () {
      final o = compareRun(fixture('engine_run.json'),
          root: engineRoot, failures: engineFailures, skips: const {});
      expect(o.unexplained, isFalse);
      expect(o.ok, isTrue);
    });
  });

  test('ST18 the VM-service marker is the engine\'s own reason (review F-5)',
      () {
    final meter = File(
            '../../packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart')
        .readAsStringSync();
    expect(meter, contains("'$vmServiceSkipMarker"));
  });

  group('the standing lists', () {
    test(
        'ST13 lines by package; comments and blanks ignored; a name may '
        'hold the separator', () {
      const list = '''
# a comment
a | test/x_test.dart | one
b | test/y_test.dart | two | three

a | test/z_test.dart | four
''';
      expect(standingFor(list, 'a'),
          {'test/x_test.dart :: one', 'test/z_test.dart :: four'});
      expect(standingFor(list, 'b'), {'test/y_test.dart :: two | three'});
    });

    test(
        'ST14 the committed lists hold the standing set the recorded runs '
        'show', () {
      final failures = File('standing_failures.txt').readAsStringSync();
      final skips = File('standing_skips.txt').readAsStringSync();
      expect(standingFor(failures, 'packages/jet_cad_2d'), engineFailures);
      expect(standingFor(failures, 'packages/jet_cad_2d_flutter'),
          containsAll(renderFailures));
      expect(
          standingFor(failures, 'packages/jet_cad_2d_flutter'), hasLength(7));
      expect(standingFor(skips, 'packages/jet_cad_2d_flutter'), renderSkips);
      expect(standingFor(skips, 'packages/jet_cad_2d'), isEmpty);
    });
  });
}
