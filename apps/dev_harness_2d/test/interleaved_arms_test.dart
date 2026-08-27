// `runInterleaved`'s ordering, which is the entire content of the function
// and the entire reason it exists.
//
// Plan 3i's Tasks 12 and 13 both score a ratio between two arms run **in one
// session**. A driver that ran all of one arm and then all of the other would
// satisfy "both arms ran" and still carry the bias those tasks exist to
// remove — session and thermal drift landing on whichever arm ran last. So
// the assertion here is on the *sequence*, recorded by the callbacks
// themselves, and not on the call counts: three rests and three tileds is
// true of the blocked ordering too.

import 'package:dev_harness_2d/measurement_rig.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('three arms alternate, never block', () async {
    final order = <String>[];
    await runInterleaved(
      arms: 3,
      rest: () async => order.add('rest'),
      tiled: () async => order.add('tiled'),
    );
    expect(order, <String>['rest', 'tiled', 'rest', 'tiled', 'rest', 'tiled']);
  });

  test('zero arms calls neither', () async {
    final order = <String>[];
    await runInterleaved(
      arms: 0,
      rest: () async => order.add('rest'),
      tiled: () async => order.add('tiled'),
    );
    expect(order, isEmpty);
  });

  test('each callback is awaited before the next arm starts', () async {
    // Without the `await`s a `for` loop over async callbacks still produces
    // the right *call* order and the wrong *completion* order: every arm
    // would be in flight at once, and two measurement phases sharing one
    // engine would interleave their frames rather than their arms. Each
    // callback below records on both sides of a real suspension, so the
    // transcript can tell the two apart.
    final order = <String>[];
    Future<void> Function() phase(String name) => () async {
          order.add('$name:start');
          await Future<void>.delayed(Duration.zero);
          order.add('$name:end');
        };
    await runInterleaved(arms: 2, rest: phase('rest'), tiled: phase('tiled'));
    expect(order, <String>[
      'rest:start',
      'rest:end',
      'tiled:start',
      'tiled:end',
      'rest:start',
      'rest:end',
      'tiled:start',
      'tiled:end',
    ]);
  });
}
