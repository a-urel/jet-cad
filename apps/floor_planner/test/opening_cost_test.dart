// Ruling 08-6: RC3, 06's NC4 method in the app, with real walls. Spec 08's
// open question 13 says a wall move's cost includes each opening
// recomputing its host's joints; the engine's RC2 uses test clients, which
// have no joints. Printed, not asserted: the results note records it next
// to NC4 and RC2.
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart';
import 'support/wall_fixture.dart';

/// Walls per zigzag chain.
const int columns = 10;

/// The chain point [c] of row [r]: rows 6 m apart, each a zigzag whose odd
/// points sit 600 mm up, so every wall joins the next at an L.
Vector2 chainPoint(int r, int c) =>
    plan(3000.0 * c, 6000.0 * r + (c.isOdd ? 600 : 0));

/// [n] walls, 200 centre, each in its own rotated group, joined end to end
/// in chains of [columns], each with a door at 900 (800): one edit.
List<Handle> chains(DraftDocument doc, int n) {
  final walls = [for (var i = 0; i < n; i++) Handle(100000 + 100 * i)];
  doc.commands.execute(CompoundCommand([
    for (var i = 0; i < n; i++) ...[
      addWall(doc, walls[i], chainPoint(i ~/ columns, i % columns),
          chainPoint(i ~/ columns, i % columns + 1), 200, Justification.centre),
      addOpening(doc, Handle(walls[i].value + 50),
          OpeningParams(walls[i], 900, 800, OpeningKind.door)),
    ],
  ], label: 'Chains'));
  return walls;
}

/// A root LINE among the walls, touching none of them.
DraftCommand line(DraftDocument doc, int k) => AddEntityCommand(
    record: draftRecord(doc.handleSeed.next(), doc.rootHandle, EntityKind.line),
    payload: linePayload(plan(-2000.0 + 3 * k, -3000), plan(-1500, -2700)));

double median(List<double> xs) => (xs.toList()..sort())[xs.length ~/ 2];

void main() {
  test(
      'RC3 timing: a line draw and a wall move among 100 / 300 / 600 joined '
      'walls, each with a door (printed)', () {
    for (final n in [100, 300, 600]) {
      final doc = wallDoc();
      final walls = chains(doc, n);
      // Not degenerate: every wall is cut by its door, and the moved one
      // is joined at both ends, so its move changes two neighbours' joints
      // and their doors (two hops).
      final moved = walls[(n ~/ columns ~/ 2) * columns + columns ~/ 2];
      expect(worldPieces(doc, moved), hasLength(2));
      final home = (doc.tree[moved]! as GroupNode).transform;
      final away = Transform2.translation(50, 0).multiply(home);
      double time(DraftCommand Function(int) edit, int k) {
        final sw = Stopwatch()..start();
        doc.commands.execute(edit(k));
        sw.stop();
        return sw.elapsedMicroseconds / 1000;
      }

      DraftCommand move(int k) =>
          TransformNodeCommand(moved, k.isEven ? away : home);
      // Untimed warm-ups for the JIT, four of each as RC2's: an even
      // number, so the wall ends back home and every timed move is real.
      for (final k in [-4, -3, -2, -1]) {
        time((k) => line(doc, k), k);
        time(move, k);
      }
      final lines = [for (var k = 0; k < 5; k++) time((k) => line(doc, k), k)];
      final moves = [for (var k = 0; k < 5; k++) time(move, k)];
      expect(driftOf(doc), isEmpty);
      // ignore: avoid_print
      print('RC3 n=$n line draw median ${median(lines).toStringAsFixed(2)} ms '
          '${lines.map((x) => x.toStringAsFixed(2)).toList()}; '
          'move median ${median(moves).toStringAsFixed(2)} ms '
          '${moves.map((x) => x.toStringAsFixed(2)).toList()}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
