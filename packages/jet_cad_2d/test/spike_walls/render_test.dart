// SPIKE 07 — throwaway. Dumps SVGs of the interesting joints, with the
// census's gap (red) and overlap (blue) samples, for eyeballing.

import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'geometry_test.dart' as g;
import 'svg.dart';
import 'wall.dart';

void main() {
  test('render', () {
    final h = g.far(0, 0);
    dump('q1_l67', [
      g.wall(g.far(-3000, 0), h, 200),
      g.wall(h, g.polar(h, 180 - 67, 2500), 115, Justification.left),
    ], h, 400);
    for (final (j1, j2, j3) in [
      (Justification.left, Justification.left, Justification.left),
      (Justification.left, Justification.centre, Justification.left),
      (Justification.centre, Justification.centre, Justification.centre),
      (Justification.right, Justification.left, Justification.centre),
      (Justification.left, Justification.left, Justification.centre),
      (Justification.left, Justification.centre, Justification.centre),
    ]) {
      dump('q2_${j1.name}_${j2.name}_${j3.name}', [
        g.wall(h, g.polar(h, 10, 3000), 200, j1),
        g.wall(g.polar(h, 50, 2000), h, 115, j2),
        g.wall(h, g.polar(h, 200, 2500), 150, j3),
      ], h, 500);
    }
    dump('q2c_split300left_br115centre', [
      g.wall(h, g.polar(h, 17, 3000), 300, Justification.left),
      g.wall(g.polar(h, 197, 3000), h, 300, Justification.left),
      g.wall(h, g.polar(h, 107, 3000), 115),
    ], h, 600);
    dump('q2c_cross200right_115left', [
      g.wall(h, g.polar(h, 73, 3000), 200, Justification.right),
      g.wall(g.polar(h, 253, 3000), h, 200, Justification.right),
      g.wall(h, g.polar(h, 163, 3000), 115, Justification.left),
      g.wall(g.polar(h, 343, 3000), h, 115, Justification.left),
    ], h, 600);
    dump('q4_l20', [
      g.wall(g.far(-3000, 0), h, 200),
      g.wall(h, g.polar(h, 180 - 20, 2500), 200),
    ], h, 800);
  });
}
