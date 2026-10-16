// The wall fixture of jet_cad_floor_plan/test/support/wall_fixture.dart and
// wall_shell.dart (3a Task 12), for the integration package's wall tests:
// public libraries only (R-P1), so `WorldWall` and `wallJoin` are
// reproduced over the public `WallParams`, the catalog is the rig's
// `kitCatalog` (R-P14), and the helpers that need the kit's geometry
// (`ringOf`, `worldWall`, `spoke`, `triangulates`, `wallDoc`, `reload`)
// stay in the kit's own copy.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_rig.dart' show kitCatalog;

/// Every "do these join" decision for walls, as the kit's `wallJoin`
/// (jet_cad_floor_plan/lib/src/parametric/wall.dart:19), reproduced: the
/// kit does not export it (R-P1).
const Tolerance wallJoin = Tolerance(linear: 1e-6, angular: 1e-9);

/// A wall in world space, as the kit's `WorldWall` builds one
/// (wall_geometry.dart:19-62), reproduced over the public [WallParams]
/// (R-P1): its world ends are the stored ends through the group's
/// transform, bit for bit.
final class WorldWall {
  WorldWall(this.handle, WallParams p, this.toWorld)
      : params = p,
        s = toWorld.transformPoint(p.start),
        e = toWorld.transformPoint(p.end),
        t = p.thickness,
        j = p.justification;

  final Handle handle;
  final WallParams params;
  final Transform2 toWorld;
  final Vector2 s, e;
  final double t;
  final Justification j;

  /// The unit direction from start to end.
  late final Vector2 d = (e - s).normalized();

  /// The left and right face offsets along the left normal.
  (double, double) get offsets => switch (j) {
        Justification.centre => (t / 2, -t / 2),
        Justification.left => (t, 0),
        Justification.right => (0, -t),
      };

  /// The start for `k == 0`, the end otherwise.
  Vector2 endpoint(int k) => k == 0 ? s : e;
}

/// The measurement corpus's far origin (`generate_document.dart`): one ulp
/// is ~9.3e-10 in x here.
const double ox = 4500000, oy = 1200000;

Vector2 far(double x, double y) => Vector2(ox + x, oy + y);

/// The plan point `(x, y)`, turned [deg] degrees about the far origin: every
/// relational fixture is drawn rotated.
Vector2 plan(double x, double y, [double deg = 23]) {
  final r = deg * math.pi / 180;
  final c = math.cos(r), s = math.sin(r);
  return far(x * c - y * s, x * s + y * c);
}

/// The next double above a positive [x]: one ulp.
double nextUp(double x) {
  final b = ByteData(8)..setFloat64(0, x);
  b.setInt64(0, b.getInt64(0) + 1);
  return b.getFloat64(0);
}

/// [from] plus [len] along [deg] degrees anticlockwise from +x.
Vector2 polar(Vector2 from, double deg, double len) {
  final r = deg * math.pi / 180;
  return from + Vector2(math.cos(r), math.sin(r)) * len;
}

/// Wall [h]'s own group transform: a translation near the far origin times
/// a rotation that is never a multiple of 90°. Every wall of a joint sits in
/// its own (06's M-06o lesson).
Transform2 groupAt(int h) => Transform2.translation(
        ox - 950 + 311.5 * (h % 7), oy + 420 - 173.25 * (h % 5))
    .multiply(Transform2.rotation(0.3 + 0.7 * (h % 9)));

/// The meet of line p1p2 and line q1q2 by Cramer's rule on explicit
/// coordinates — an oracle independent of `intersect`.
Vector2 oracleMeet(Vector2 p1, Vector2 p2, Vector2 q1, Vector2 q2) {
  final a1 = p2.y - p1.y, b1 = p1.x - p2.x, c1 = a1 * p1.x + b1 * p1.y;
  final a2 = q2.y - q1.y, b2 = q1.x - q2.x, c2 = a2 * q1.x + b2 * q1.y;
  final det = a1 * b2 - a2 * b1;
  return Vector2((b2 * c1 - b1 * c2) / det, (a1 * c2 - a2 * c1) / det);
}

/// [w]'s face line at [offset] along its left normal (start to end), as two
/// points, from its world coordinates.
(Vector2, Vector2) face(WorldWall w, double offset) => faceOf(w.s, w.e, offset);

/// The face line of the wall from [s] to [e] at [offset] along its left
/// normal, as two points (today's `face`, wall_fixture.dart:96-103, over
/// the two ends; 3a Task 26 shares it).
(Vector2, Vector2) faceOf(Vector2 s, Vector2 e, double offset) {
  final dx = e.x - s.x, dy = e.y - s.y;
  final len = math.sqrt(dx * dx + dy * dy);
  final nx = -dy / len * offset, ny = dx / len * offset;
  return (Vector2(s.x + nx, s.y + ny), Vector2(e.x + nx, e.y + ny));
}

/// The perpendicular distance from [p] to the line through [a] and [b].
double distToLine(Vector2 p, Vector2 a, Vector2 b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  return (dx * (p.y - a.y) - dy * (p.x - a.x)).abs() /
      math.sqrt(dx * dx + dy * dy);
}

/// The foot of [p] on the line through [a] and [b].
Vector2 project(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a;
  return a + d * ((p - a).dot(d) / d.dot(d));
}

/// Crossing-number point-in-polygon.
bool insideRing(Vector2 p, List<Vector2> r) {
  var c = false;
  for (var i = 0, j = r.length - 1; i < r.length; j = i++) {
    final a = r[i], b = r[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      c = !c;
    }
  }
  return c;
}

/// [count] points uniform in the disk of radius [r] about [centre].
List<Vector2> diskSamples(Vector2 centre, double r,
    {int count = 20000, int seed = 7}) {
  final rnd = math.Random(seed);
  return [
    for (var i = 0; i < count; i++)
      () {
        final a = rnd.nextDouble() * 2 * math.pi;
        final rad = r * math.sqrt(rnd.nextDouble());
        return centre + Vector2(math.cos(a), math.sin(a)) * rad;
      }(),
  ];
}

/// How many samples in the disk of radius [r] about [centre] lie in two or
/// more of [rings] — the overlap census.
int overlapCensus(List<List<Vector2>> rings, Vector2 centre, double r) => [
      for (final p in diskSamples(centre, r))
        if (rings.where((g) => insideRing(p, g)).length >= 2) p
    ].length;

/// The points of [a] that also occur in [b], compared bitwise.
List<Vector2> sharedBitwise(List<Vector2> a, List<Vector2> b) => [
      for (final p in a)
        if (b.any((q) => q.x == p.x && q.y == p.y)) p
    ];

/// The smallest distance from [p] to any point of [ring].
double nearestIn(List<Vector2> ring, Vector2 p) =>
    ring.map((q) => (q - p).length).reduce(math.min);

// ---------------------------------------------------------------------------
// Documents: walls through the parametric system (Task 5 onwards).

/// Creates wall [h] in its own group [at] with the local parameters [p]:
/// one command, as the Wall tool and 06's fixtures create an object.
DraftCommand addWallLocal(
        DraftDocument doc, Handle h, WallParams p, Transform2 at) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: at,
          children: const [])),
      SetComponentCommand<WallParams>(h, p),
    ], label: 'Add wall');

/// Creates wall [h] from world [s] to world [e] in group [at] (default
/// [groupAt]`(h)`): its stored endpoints are [s] and [e] taken back through
/// [at], so a joint drawn at one world point meets within rounding, not
/// bitwise.
DraftCommand addWall(DraftDocument doc, Handle h, Vector2 s, Vector2 e,
    double t, Justification j,
    {Transform2? at}) {
  final g = at ?? groupAt(h.value);
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  return addWallLocal(doc, h, WallParams(ls.x, ls.y, le.x, le.y, t, j), g);
}

/// [spoke]'s document form: wall [h] between [hub] and the point [len]
/// along [deg], in a group at [hub] whose hub end is local `(0, 0)`, so its
/// world hub end is **bitwise** [hub].
DraftCommand addSpoke(DraftDocument doc, Handle h, Vector2 hub, double deg,
    double len, double t, Justification j,
    {required bool fromHub}) {
  final g = Transform2.translation(hub.x, hub.y)
      .multiply(Transform2.rotation(0.3 + 0.7 * (h.value % 9)));
  final tip = g.invert().transformPoint(polar(hub, deg, len));
  return addWallLocal(
      doc,
      h,
      fromHub
          ? WallParams(0, 0, tip.x, tip.y, t, j)
          : WallParams(tip.x, tip.y, 0, 0, t, j),
      g);
}

/// [group]'s children, ascending.
List<Handle> kids(DraftDocument doc, Handle group) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

EntityKind kindOf(DraftDocument doc, Handle h) =>
    doc.entities.kindAt(doc.entities.slotOf(h)!);

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// The points of a polyline payload, less a closed one's repeated first
/// point.
List<Vector2> pointsOf(GeometryPayload p, {bool closed = false}) {
  final c = p.coords;
  final n = c.length ~/ 2 - (closed ? 1 : 0);
  return [for (var i = 0; i < n; i++) Vector2(c[2 * i], c[2 * i + 1])];
}

/// Wall [h] as the geometry reads it: its stored parameters under its
/// group's accumulated transform.
WorldWall worldWallOf(DraftDocument doc, Handle h) => WorldWall(
    h, doc.components.get<WallParams>(h)!, doc.tree.accumulatedTransform(h));

/// Wall [h]'s stored outline (the boundary its fill names), read back to
/// world through its group's transform. Empty when it has no fill.
List<Vector2> worldOutline(DraftDocument doc, Handle h) {
  final fills = [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == EntityKind.fill) k
  ];
  if (fills.isEmpty) return const [];
  final boundary = Handle(payloadOf(doc, fills.single).scalars[0].toInt());
  final m = doc.tree.accumulatedTransform(h);
  return [
    for (final q in pointsOf(payloadOf(doc, boundary), closed: true))
      m.transformPoint(q),
  ];
}

/// The points of [a] within [tol] of some point of [b].
List<Vector2> sharedNear(List<Vector2> a, List<Vector2> b,
        [double tol = 1e-6]) =>
    [
      for (final p in a)
        if (b.any((q) => (q - p).length < tol)) p
    ];

/// Whether [ring] has exactly four points, one within 1e-6 of each of
/// [want].
bool isRectNear(List<Vector2> ring, List<Vector2> want) =>
    ring.length == 4 && want.every((p) => nearestIn(ring, p) < 1e-6);

/// `drift()` of [doc] under the kit's types.
List<Handle> driftOf(DraftDocument doc) =>
    ParametricSystem(doc, kitCatalog()).drift();

/// `diagnostics()` of [doc] under the kit's types.
List<Diagnostic> diagnosticsOf(DraftDocument doc) =>
    ParametricSystem(doc, kitCatalog()).diagnostics();

String enc(DraftDocument d) => DraftDocumentCodec.encodeToString(d);

/// Entities sorted by handle: slot order is history, not state (06 D11).
String canon(DraftDocument d) {
  final j = DraftDocumentCodec.encode(d);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  return jsonEncode(j);
}

// test/support/wall_shell.dart, unchanged.
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
