// Spec 3a C1.5, C3.3: the opening's document adapters ask the live answer
// they are handed (the plan's `PlanServices.liveTypeIdOf`), never a catalog
// of their own. A wall the plan has frozen (spec 2a E2) is neither a host
// nor an obstacle there, and a frozen opening is not among its host's
// openings, while the catalog still names both, exactly as `generate`,
// which sees no frozen object, draws them.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_geometry.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_geometry.dart'
    show wallsInDocument;

import '../support/opening_fixture.dart';
import '../support/wall_fixture.dart';

const hA = Handle(1000), hX = Handle(1200);
const hO = Handle(5000), hP = Handle(5100);

void main() {
  test(
      'OG-live (spec 3a C1.5) a frozen crossing wall is no obstacle, a '
      'frozen host has no frame or layout, a frozen opening is not among '
      'its host\'s openings; the catalog names all three', () {
    final doc = wallDoc();
    // A: 4,000 left-justified, at 23 degrees in its own rotated group at
    // the far origin. X crosses it at about 1,900 (an X obstacle, 08 D7).
    doc.commands.execute(
        addWall(doc, hA, plan(0, 0), plan(4000, 0), 200, Justification.left));
    final fa = oracleFrameOf(doc, hA);
    doc.commands.execute(addWall(doc, hX, oracleAt(fa, 1800, -900),
        oracleAt(fa, 1950, 900), 150, Justification.centre));
    // O, a door at 700, and P, a window at 3,200: both on A, both fit.
    doc.commands.execute(addOpening(
        doc, hO, const OpeningParams(hA, 700, 800, OpeningKind.door)));
    doc.commands.execute(addOpening(
        doc, hP, const OpeningParams(hA, 3200, 600, OpeningKind.window)));
    expect(driftOf(doc), isEmpty, reason: 'premise: regenerated');

    final live = liveOf(doc);
    // Control: X is A's one obstacle; O and P are A's openings.
    expect([for (final o in layoutInDocument(doc, hA, live)!.obstacles) o.wall],
        [hX]);
    expect(
        [for (final (h, _) in openingsInDocument(doc, hA, live)) h], [hO, hP]);

    // X frozen: no obstacle; A's one stretch is its straight span.
    final noX = liveOf(doc, frozen: {hX});
    expect(testCatalog().typeIdOf(doc, hX), ArchitectureTypes.wall,
        reason: 'the catalog still names it');
    expect([for (final w in wallsInDocument(doc, hA, noX)!.walls) w.handle],
        isNot(contains(hX)));
    final layout = layoutInDocument(doc, hA, noX)!;
    expect(layout.obstacles, isEmpty);
    expect(layout.stretches, [(layout.frame.uS, layout.frame.uE)]);

    // A frozen: no host, no frame, no layout.
    final noA = liveOf(doc, frozen: {hA});
    expect(testCatalog().typeIdOf(doc, hA), ArchitectureTypes.wall);
    expect(wallsInDocument(doc, hA, noA), isNull);
    expect(hostFrameInDocument(doc, hA, noA), isNull);
    expect(layoutInDocument(doc, hA, noA), isNull);
    expect(hostFrameInDocument(doc, hA, live), isNotNull, reason: 'control');

    // O frozen: P alone is A's.
    final noO = liveOf(doc, frozen: {hO});
    expect(testCatalog().typeIdOf(doc, hO), ArchitectureTypes.opening);
    expect([for (final (h, _) in openingsInDocument(doc, hA, noO)) h], [hP]);
  });
}
