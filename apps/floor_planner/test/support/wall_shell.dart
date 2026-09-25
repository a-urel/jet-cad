import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall_fixture.dart';

// Document-level assertions shared by the Wall tool's and the end grips'
// shell tests.

/// Every wall, ascending by handle.
List<Handle> walls(DraftDocument doc) =>
    doc.components.withComponent<WallParams>().toList();

/// [p]'s coordinates, for exact list comparison.
List<double> xy(Vector2 p) => [p.x, p.y];

/// A stored wall's left and right face offsets (spec 07 D2), written out
/// here rather than read from `WorldWall.offsets`.
(double, double) facesOf(WallParams p) => switch (p.justification) {
      Justification.centre => (p.thickness / 2, -p.thickness / 2),
      Justification.left => (p.thickness, 0),
      Justification.right => (0, -p.thickness),
    };

/// Wall [a] runs into a node that wall [b] runs out of: they share exactly
/// two outline corners, each at the Cramer meet of the faces on its side.
void expectMitre(DraftDocument doc, Handle a, Handle b) {
  final wa = worldWallOf(doc, a), wb = worldWallOf(doc, b);
  final ra = worldOutline(doc, a), rb = worldOutline(doc, b);
  final shared = sharedNear(ra, rb);
  expect(shared, hasLength(2), reason: '${a.toHex()} / ${b.toHex()}');
  final (al, ar) = facesOf(doc.components.get<WallParams>(a)!);
  final (bl, br) = facesOf(doc.components.get<WallParams>(b)!);
  final (a1, a2) = face(wa, al);
  final (b1, b2) = face(wb, bl);
  final (a3, a4) = face(wa, ar);
  final (b3, b4) = face(wb, br);
  expect(nearestIn(shared, oracleMeet(a1, a2, b1, b2)), lessThan(1e-6));
  expect(nearestIn(shared, oracleMeet(a3, a4, b3, b4)), lessThan(1e-6));
}

/// Wall [h]'s outline is its plain rectangle: both ends square.
void expectSquare(DraftDocument doc, Handle h) {
  final w = worldWallOf(doc, h);
  final (l, r) = facesOf(doc.components.get<WallParams>(h)!);
  final (a, b) = face(w, l);
  final (c, d) = face(w, r);
  expect(isRectNear(worldOutline(doc, h), [a, b, c, d]), isTrue,
      reason: '${h.toHex()} is square at both ends');
}
