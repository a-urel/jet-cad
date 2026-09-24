import 'package:test/test.dart';
import 'geometry_test.dart' as g;
import 'wall.dart';

void main() {
  test('debug Q2 w1', () {
    final h = g.far(0, 0);
    final w1 = g.wall(h, g.polar(h, 10, 3000), 200);
    final w2 = g.wall(g.polar(h, 50, 2000), h, 115, Justification.left);
    final w3 = g.wall(h, g.polar(h, 200, 2500), 150, Justification.right);
    final all = [w1, w2, w3];
    final r = g.ring(w1, all, fallback: false);
    for (final p in r) {
      print('(${(p.x - g.ox).toStringAsFixed(9)}, ${(p.y - g.oy).toStringAsFixed(9)})');
    }
    print('simple ${isSimpleCcw(r)} tri ${g.triangulates(r)}');
  });
}
