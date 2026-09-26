// Spec 08 D2: what references cost. One `references` call per live object
// per survey, twice per edit, including for an edit that touches no object.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import 'neighbour_cost_test.dart' show cell, gridDoc, line, median;
import 'support/clients.dart';

/// Post [i]'s Pin: its own group, turned and shifted off the Post's.
Transform2 pinCell(int i) => cell(i)
    .multiply(Transform2.translation(310, 170))
    .multiply(Transform2.rotation(0.45 + 0.02 * (i % 5)));

const Post segment = Post(1000, 20);

/// [n] Posts on `cell(i)`, each with one Pin, created in one edit; returns
/// the Posts' handles, ascending.
List<Handle> postGrid(DraftDocument doc, int n) {
  final posts = [for (var i = 0; i < n; i++) doc.handleSeed.next()];
  final pins = [for (var i = 0; i < n; i++) doc.handleSeed.next()];
  doc.commands.execute(CompoundCommand([
    for (var i = 0; i < n; i++) ...[
      AddNodeCommand(GroupNode(
          handle: posts[i],
          parent: doc.rootHandle,
          transform: cell(i),
          children: const [])),
      SetComponentCommand<Post>(posts[i], segment),
      AddNodeCommand(GroupNode(
          handle: pins[i],
          parent: doc.rootHandle,
          transform: pinCell(i),
          children: const [])),
      SetComponentCommand<Pin>(pins[i], Pin(posts[i], 150.0 + 50 * (i % 13))),
    ],
  ], label: 'Grid'));
  return posts;
}

void main() {
  test(
      'RC1 a root line drawn among 300 Posts and 300 Pins makes exactly '
      '2 × 600 references calls and no overlap test', () {
    const n = 300;
    final doc = gridDoc(testCatalog());
    final posts = postGrid(doc, n);
    // Not degenerate: every Post has its Pin as its one referrer.
    final report = {
      for (final d in ParametricSystem(doc, testCatalog()).diagnostics())
        if (d.code == 'test.referrers') d.handles.first: d.handles.length - 1,
    };
    expect(report.keys, posts);
    expect(report.values.toSet(), {1});
    final depth = doc.commands.undoDepth;
    final seed = doc.handleSeed.current.value;
    final calls = debugReferenceCalls;
    final tests = debugOverlapTests;

    doc.commands.execute(line(doc, 0));
    expect(debugReferenceCalls - calls, 2 * 2 * n);
    expect(debugOverlapTests - tests, 0);
    // The line landed at the root, as one undo step.
    final h = Handle(seed + 1);
    expect(doc.entities.ownerAt(doc.entities.slotOf(h)!), doc.rootHandle);
    expect(doc.commands.undoDepth, depth + 1);

    // Nor does an edit of a referrer, whose seed the dangling-reference
    // check reads (spec 08 D5, Ruling 08-3): still two surveys' worth.
    final pin = doc.components.withComponent<Pin>().first;
    final was = doc.components.get<Pin>(pin)!;
    final edited = debugReferenceCalls;
    doc.commands
        .execute(SetComponentCommand<Pin>(pin, Pin(was.host, was.offset + 25)));
    expect(debugReferenceCalls - edited, 2 * 2 * n);
    expect(doc.commands.undoDepth, depth + 2);

    // And `diagnostics()`'s reference entries read its one survey.
    final diagnosed = debugReferenceCalls;
    ParametricSystem(doc, testCatalog()).diagnostics();
    expect(debugReferenceCalls - diagnosed, 2 * n);
  });

  test(
      'RC2 timing: a line draw and a Post move among 100 / 300 / 600 Posts, '
      'each with a Pin (printed)', () {
    for (final n in [100, 300, 600]) {
      final doc = gridDoc(testCatalog());
      final posts = postGrid(doc, n);
      final moved = posts[n ~/ 2];
      final home = cell(n ~/ 2);
      final away = home.multiply(Transform2.translation(50, 0));
      double time(DraftCommand Function(int) edit, int k) {
        final sw = Stopwatch()..start();
        doc.commands.execute(edit(k));
        sw.stop();
        return sw.elapsedMicroseconds / 1000;
      }

      DraftCommand move(int k) =>
          TransformNodeCommand(moved, k.isEven ? away : home);
      // Untimed warm-ups for the JIT: four of each (fewer left the medians
      // JIT noise, Task 1's review m-3), an even number, so the Post ends
      // back home and every timed move is a real one.
      for (final k in [-4, -3, -2, -1]) {
        time((k) => line(doc, k), k);
        time(move, k);
      }
      final lines = [for (var k = 0; k < 5; k++) time((k) => line(doc, k), k)];
      final moves = [for (var k = 0; k < 5; k++) time(move, k)];
      print('RC2 n=$n line draw median ${median(lines).toStringAsFixed(2)} ms '
          '${lines.map((x) => x.toStringAsFixed(2)).toList()}; '
          'move median ${median(moves).toStringAsFixed(2)} ms '
          '${moves.map((x) => x.toStringAsFixed(2)).toList()}');
    }
  });
}
