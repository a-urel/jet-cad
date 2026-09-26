// Spec 07 D11, spec 08 D14 (Ruling 08-11): the shared band cache that the
// Wall tool joins through and the opening tools find their host through.
// A band is bounded along the centreline as well as across it. 07's wall
// tests reach this code through the Wall tool and stay unedited (Ruling
// 08-1); this file pins the length bound the final review found unkilled
// (fr-X9). The walls are at the far origin in their own rotated groups.
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_bands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/wall_fixture.dart';

void main() {
  test(
      'WB1 (fr-X9) a point on a wall\'s centreline line beyond either end, or '
      'in its band\'s width beyond an end, is in no band: it neither joins '
      'nor hosts; just inside an end it joins that end, bit for bit, and '
      'hosts', () {
    const hA = Handle(1000);
    final doc = wallDoc();
    doc.commands.execute(addWall(
        doc, hA, plan(-1200, 300), plan(1800, 300), 200, Justification.left));
    final bands = WallBands();
    addTearDown(bands.dispose);
    final w = worldWallOf(doc, hA);
    final n = Vector2(-w.d.y, w.d.x);
    final len = (w.e - w.s).length;
    expect(len, closeTo(3000, 1e-6));

    // Beyond the ends: 1e-3 is a thousand times the tolerance.
    for (final (what, p) in [
      ('past the end, on the line', w.e + w.d * 1e-3),
      ('past the end, in the band\'s width', w.e + w.d * 1e-3 + n * 100),
      ('far past the end, on the line', w.e + w.d * 900),
      ('before the start, on the line', w.s - w.d * 1e-3),
      ('before the start, in the band\'s width', w.s - w.d * 1e-3 + n * 100),
    ]) {
      expect(bands.hostAt(doc, p.x, p.y), isNull, reason: what);
      final out = Vector2(7, 7);
      expect(bands.joinInto(doc, p.x, p.y, out), isFalse, reason: what);
      expect(out.storage.toList(), [7, 7], reason: '$what: left alone');
    }

    // Just inside each end (inside the band: A is left-justified, so its
    // band runs from the centreline to 200 along the left normal).
    for (final (what, p, end) in [
      ('inside the end', w.e - w.d * 1e-3 + n * 100, w.e),
      ('inside the start', w.s + w.d * 1e-3 + n * 100, w.s),
    ]) {
      expect(bands.hostAt(doc, p.x, p.y), hA, reason: what);
      final out = Vector2.zero();
      expect(bands.joinInto(doc, p.x, p.y, out), isTrue, reason: what);
      expect(out.storage.toList(), end.storage.toList(), reason: what);
    }
  });
}
