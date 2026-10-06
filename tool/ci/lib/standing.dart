// The standing comparison (spec 14d P5, revision 2): a test run's failing
// and skipped tests against the ones the repository knows of, exactly. A
// new failure is red; so is a standing one that passes, or no longer runs
// (the list is then stale, or a re-baseline landed). Skips are compared
// the same way, and a skip because the VM service is out of reach is red
// even when listed: a runner without loopback must not pass the
// allocation invariants by skipping them.
import 'dart:convert';

/// The engine's allocation tests skip with a reason that starts so
/// (`jet_cad_2d/test/invariants/vm_allocation_meter.dart`).
const String vmServiceSkipMarker =
    'the VM allocation profiler could not be started';

/// A test's identity across runs: its suite's path relative to the
/// package, and its full name (groups included).
String testId(String suite, String name) => '$suite :: $name';

/// What a run did against what was expected of it.
final class Outcome {
  const Outcome({
    required this.ended,
    required this.unexplained,
    required this.tests,
    required this.newFailures,
    required this.fixed,
    required this.newSkips,
    required this.ranSkips,
    required this.vmSkips,
  });

  /// Whether the run reported its end (a `done` event).
  final bool ended;

  /// The run said it failed, yet no test failed (review F-1's backstop):
  /// a failure this reading does not know how to attribute.
  final bool unexplained;

  /// Tests that finished, the hidden loaders left out.
  final int tests;

  /// Failing, and not standing.
  final List<String> newFailures;

  /// Standing failures that passed, or did not run.
  final List<String> fixed;

  /// Skipped, and not standing.
  final List<String> newSkips;

  /// Standing skips that ran, or did not appear.
  final List<String> ranSkips;

  /// Skipped because the VM service was out of reach: red, listed or not.
  final List<String> vmSkips;

  bool get ok =>
      ended &&
      !unexplained &&
      tests > 0 &&
      newFailures.isEmpty &&
      fixed.isEmpty &&
      newSkips.isEmpty &&
      ranSkips.isEmpty &&
      vmSkips.isEmpty;

  /// One line per difference, for the CI log.
  List<String> report() => [
        if (!ended) 'the run did not end (no "done" event)',
        if (unexplained) 'the run failed, but no test did',
        if (tests == 0) 'the run had no test',
        for (final t in newFailures) 'new failure: $t',
        for (final t in fixed) 'standing failure passed or did not run: $t',
        for (final t in newSkips) 'new skip: $t',
        for (final t in ranSkips) 'standing skip ran or did not appear: $t',
        for (final t in vmSkips) 'skipped for want of the VM service: $t',
      ];
}

/// Compares the JSON reporter's output [json] (one event per line, as
/// `--file-reporter json:<file>` writes it) with the standing [failures]
/// and [skips] (ids as [testId] makes them). Suite paths are made
/// relative to [root], the package's directory: `flutter test` reports
/// them absolute, `dart test` relative.
Outcome compareRun(
  String json, {
  required String root,
  required Set<String> failures,
  required Set<String> skips,
}) {
  // `--root .` arrives as `<dir>/.`: normalised, with one trailing slash.
  final base = Uri.directory(root).normalizePath().toFilePath();
  final suites = <int, String>{};
  final names = <int, String>{};
  final skipReasons = <int, String>{};
  final failing = <String>{};
  final skipped = <String>{};
  final vm = <String>{};
  var ended = false;
  var succeeded = true;
  var tests = 0;
  for (final line in const LineSplitter().convert(json)) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      continue; // Anything a tool printed around the events.
    }
    if (decoded is! Map<String, Object?>) continue;
    final event = decoded;
    switch (event['type']) {
      case 'suite':
        final suite = event['suite']! as Map<String, Object?>;
        final path = suite['path']! as String;
        suites[suite['id']! as int] =
            path.startsWith(base) ? path.substring(base.length) : path;
      case 'testStart':
        final test = event['test']! as Map<String, Object?>;
        names[test['id']! as int] = testId(
            suites[test['suiteID']! as int] ?? '?', test['name']! as String);
      case 'error':
        // A failure reported apart from the test's end: one after it
        // completed (its `testDone` said success), or an error of a test
        // that is still running. Either way the test failed.
        final id = event['testID']! as int;
        failing.add(names[id] ?? '? :: #$id');
      case 'print':
        if (event['messageType'] == 'skip') {
          skipReasons[event['testID']! as int] = event['message']! as String;
        }
      case 'testDone':
        final id = event['testID']! as int;
        final name = names[id] ?? '? :: #$id';
        final hidden = event['hidden'] == true;
        if (event['result'] != 'success') {
          failing.add(name);
        } else if (event['skipped'] == true) {
          skipped.add(name);
          if ((skipReasons[id] ?? '').contains(vmServiceSkipMarker)) {
            vm.add(name);
          }
        }
        if (!hidden) tests++;
      case 'done':
        ended = true;
        succeeded = event['success'] != false;
    }
  }
  List<String> sorted(Iterable<String> s) => s.toList()..sort();
  return Outcome(
    ended: ended,
    unexplained: ended && !succeeded && failing.isEmpty,
    tests: tests,
    newFailures: sorted(failing.difference(failures)),
    fixed: sorted(failures.difference(failing)),
    newSkips: sorted(skipped.difference(skips)),
    ranSkips: sorted(skips.difference(skipped)),
    vmSkips: sorted(vm),
  );
}

/// The ids a standing list holds for [package]: lines
/// `<package> | <suite> | <name>`; blank lines and `#` comments skipped.
Set<String> standingFor(String list, String package) => {
      for (final raw in const LineSplitter().convert(list))
        if (raw.trim().isNotEmpty && !raw.trimLeft().startsWith('#'))
          if (_fields(raw) case [final p, final suite, final name]
              when p == package)
            testId(suite, name),
    };

List<String> _fields(String line) {
  final first = line.indexOf(' | ');
  if (first < 0) return const [];
  final second = line.indexOf(' | ', first + 3);
  if (second < 0) return const [];
  return [
    line.substring(0, first).trim(),
    line.substring(first + 3, second).trim(),
    line.substring(second + 3).trim(),
  ];
}
