// Spec 07 D11, spec 08 D14 (Ruling 08-11): the shared band cache that the
// Wall tool joins through and the opening tools find their host through.
// A band is bounded along the centreline as well as across it. 07's wall
// tests reach this code through the Wall tool and stay unedited (Ruling
// 08-1); this file pins the length bound the final review found unkilled
// (fr-X9). The walls are at the far origin in their own rotated groups.
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall_bands.dart';
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

  test(
      'WB2 (09c D3, D6) liveWalls in a fresh WallBands sees the live walls, '
      'ascending, and a wall added after the first call once the change is '
      'delivered; it returns an unmodifiable view, not a copy; the '
      'generation moves on the change', () async {
    final doc = wallDoc();
    // Reserved up front, so the wall added last has the middle handle.
    final h1 = doc.handleSeed.next(), h3 = doc.handleSeed.next();
    final h2 = doc.handleSeed.next(), hd = doc.handleSeed.next();
    doc.commands.execute(addWall(
        doc, h1, plan(-1200, 300), plan(1800, 300), 200, Justification.left));
    doc.commands.execute(addWall(doc, h2, plan(-1200, 1300), plan(1800, 1700),
        120, Justification.right));
    // A degenerate wall (zero thickness) has no band, so it is not listed.
    doc.commands.execute(addWallLocal(doc, hd,
        WallParams(10, 20, 3000, 40, 0, Justification.centre), groupAt(7)));
    expect(doc.components.get<WallParams>(hd), isNotNull);
    final bands = WallBands();
    addTearDown(bands.dispose);

    // Fresh: the first call refreshes (no hostAt or joinInto ran before).
    final live = bands.liveWalls(doc);
    expect(live, [h1, h2]);
    expect(() => live.add(h3), throwsUnsupportedError);
    final g0 = bands.generation;

    // A wall added after construction, with a handle between the two:
    // the subscription the first call started marks the cache stale.
    doc.commands.execute(addWall(doc, h3, plan(-900, -800), plan(2100, -400),
        150, Justification.centre));
    await pumpEventQueue();
    expect(bands.generation, greaterThan(g0));
    final again = bands.liveWalls(doc);
    expect(again, [h1, h3, h2]);
    // A view of the cache's own list: the first result reads the same.
    expect(live, [h1, h3, h2]);
  });
}
