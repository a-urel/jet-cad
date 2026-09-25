// SPIKE 08 -- throwaway test support.
import 'dart:math' as math;

import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';

/// Creates opening [h] as its own root-level group at [at] (default the
/// identity, like walls).
DraftCommand addOpening(DraftDocument doc, Handle h, OpeningParams o,
        {Transform2? at}) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: at ?? Transform2.identity(),
          children: const [])),
      SetComponentCommand<OpeningParams>(h, o),
    ], label: 'Add opening');

/// Every region boundary of [h] (the polylines its fills name), ascending
/// by fill handle, read back to world.
List<List<Vector2>> worldPieces(DraftDocument doc, Handle h) {
  final m = doc.tree.accumulatedTransform(h);
  return [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == EntityKind.fill)
        [
          for (final q in pointsOf(
              payloadOf(doc, Handle(payloadOf(doc, k).scalars[0].toInt())),
              closed: true))
            m.transformPoint(q),
        ],
  ];
}

/// [h]'s children of [kind], read to world: each as its payload's coords.
List<List<Vector2>> worldPoints(DraftDocument doc, Handle h, EntityKind kind) {
  final m = doc.tree.accumulatedTransform(h);
  return [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == kind)
        [
          for (var i = 0; i + 1 < payloadOf(doc, k).coords.length; i += 2)
            m.transformPoint(Vector2(
                payloadOf(doc, k).coords[i], payloadOf(doc, k).coords[i + 1])),
        ],
  ];
}

/// An independent frame for wall [h]: its world centreline and face
/// offsets, from the stored parameters and the group transform only,
/// written out without the geometry library.
({Vector2 s, Vector2 d, Vector2 n, double len, double lo, double ro})
    oracleFrame(DraftDocument doc, Handle h) {
  final p = doc.components.get<WallParams>(h)!;
  final m = doc.tree.accumulatedTransform(h);
  final s = m.transformPoint(Vector2(p.sx, p.sy));
  final e = m.transformPoint(Vector2(p.ex, p.ey));
  final dx = e.x - s.x, dy = e.y - s.y;
  final len = math.sqrt(dx * dx + dy * dy);
  final d = Vector2(dx / len, dy / len);
  final t = p.thickness;
  final (lo, ro) = switch (p.justification) {
    Justification.left => (t, 0.0),
    Justification.right => (0.0, -t),
    Justification.centre => (t / 2, -t / 2),
  };
  return (s: s, d: d, n: Vector2(-d.y, d.x), len: len, lo: lo, ro: ro);
}

/// The world rectangle of wall [h] between `u = a` and `u = b`, face to
/// face, by [oracleFrame].
List<Vector2> gapRect(DraftDocument doc, Handle h, double a, double b) {
  final f = oracleFrame(doc, h);
  Vector2 at(double u, double v) => f.s + f.d * u + f.n * v;
  return [at(a, f.ro), at(b, f.ro), at(b, f.lo), at(a, f.lo)];
}

/// Wall [h]'s uncut world outline: what 07 stores for it with no openings,
/// read from a twin of [doc] (saved, reloaded, every opening deleted) --
/// the band the pieces must tile. A differential oracle: 07's own path,
/// local-space fallback included.
List<Vector2> uncutOutline(DraftDocument doc, Handle h) {
  final twin = reload(enc(doc));
  for (final o in twin.components.withComponent<OpeningParams>().toList()) {
    twin.commands.execute(CompoundCommand([
      for (final k in kids(twin, o)) RemoveEntityCommand(k),
      RemoveNodeCommand(o),
    ], label: 'Delete opening'));
  }
  return worldOutline(twin, h);
}

/// The tiling oracle: [count] points uniform in the bounding box of
/// [original] (grown by 50 mm). Every point inside [original] must be in
/// exactly one piece xor in some gap rectangle; no point outside it may be
/// in a piece or a gap; no point is in two pieces. Returns the violations
/// by kind.
Map<String, int> tiling(List<Vector2> original, List<List<Vector2>> pieces,
    List<List<Vector2>> gaps,
    {int count = 20000, int seed = 11}) {
  final box = Aabb2.fromPoints(original).expandedBy(50);
  final rnd = math.Random(seed);
  final out = <String, int>{
    'overlap': 0,
    'hole': 0,
    'pieceInGap': 0,
    'pieceOutside': 0,
    'gapOutside': 0,
  };
  for (var i = 0; i < count; i++) {
    final p = Vector2(box.minX + rnd.nextDouble() * (box.maxX - box.minX),
        box.minY + rnd.nextDouble() * (box.maxY - box.minY));
    final inside = insideRing(p, original);
    final k = pieces.where((r) => insideRing(p, r)).length;
    final g = gaps.any((r) => insideRing(p, r));
    if (k > 1) out['overlap'] = out['overlap']! + 1;
    if (inside && !g && k == 0) out['hole'] = out['hole']! + 1;
    if (g && k > 0) out['pieceInGap'] = out['pieceInGap']! + 1;
    if (!inside && k > 0) out['pieceOutside'] = out['pieceOutside']! + 1;
    if (!inside && g) out['gapOutside'] = out['gapOutside']! + 1;
  }
  return out;
}

int violations(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

/// Whether every piece is a simple anticlockwise ring that triangulates.
bool allTriangulate(List<List<Vector2>> pieces) =>
    pieces.every((r) => isSimpleCcw(r) && triangulates(r));

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;
