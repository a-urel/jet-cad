import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

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

/// A world wall from [s] to [e], stored in group [at] (default
/// [groupAt]`(h)`) as local parameters: its world endpoints are the local
/// ones taken back through [at], so a joint drawn at one world point meets
/// within rounding, not bitwise.
WorldWall worldWall(int h, Vector2 s, Vector2 e, double t,
    [Justification j = Justification.centre, Transform2? at]) {
  final g = at ?? groupAt(h);
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  return WorldWall(Handle(h), WallParams(ls.x, ls.y, le.x, le.y, t, j), g);
}

/// A spoke of a node at [hub]: wall [h] between [hub] and the point [len]
/// along [deg], starting at [hub] when [fromHub]. Its group sits at [hub]
/// under [groupAt]`(h)`'s rotation and its hub end is local `(0, 0)`, so
/// every spoke's hub end is **bitwise** [hub] in world — the exact joint a
/// pinched node needs.
WorldWall spoke(
    int h, Vector2 hub, double deg, double len, double t, Justification j,
    {required bool fromHub}) {
  final g = Transform2.translation(hub.x, hub.y)
      .multiply(Transform2.rotation(0.3 + 0.7 * (h % 9)));
  final tip = g.invert().transformPoint(polar(hub, deg, len));
  final p = fromHub
      ? WallParams(0, 0, tip.x, tip.y, t, j)
      : WallParams(tip.x, tip.y, 0, 0, t, j);
  return WorldWall(Handle(h), p, g);
}

/// [w]'s outline among [all] ([w] itself is skipped).
({List<Vector2> ring, bool fellBack, List<Handle>? hole}) ringOf(
        WorldWall w, List<WorldWall> all,
        {bool fallback = true}) =>
    outline(
        w,
        [
          for (final o in all)
            if (o.handle != w.handle) o
        ],
        fallback: fallback);

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
(Vector2, Vector2) face(WorldWall w, double offset) {
  final dx = w.e.x - w.s.x, dy = w.e.y - w.s.y;
  final len = math.sqrt(dx * dx + dy * dy);
  final nx = -dy / len * offset, ny = dx / len * offset;
  return (Vector2(w.s.x + nx, w.s.y + ny), Vector2(w.e.x + nx, w.e.y + ny));
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

/// Whether [ring] closes into a polyline that the engine triangulates.
bool triangulates(List<Vector2> ring) {
  final tri = triangulationFor(
      EntityKind.polyline, polylinePayload(ring, closed: true));
  return tri != null && tri.isNotEmpty;
}

/// The smallest distance from [p] to any point of [ring].
double nearestIn(List<Vector2> ring, Vector2 p) =>
    ring.map((q) => (q - p).length).reduce(math.min);

// ---------------------------------------------------------------------------
// Documents: walls through the parametric system (Task 5 onwards).

/// An empty document with the floor planner's parametric system installed.
DraftDocument wallDoc() {
  final doc = DraftDocument.empty();
  installParametric(doc);
  return doc;
}

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

/// `drift()` of [doc] under the floor planner's catalog.
List<Handle> driftOf(DraftDocument doc) =>
    ParametricSystem(doc, parametricCatalog).drift();

/// `diagnostics()` of [doc] under the floor planner's catalog.
List<Diagnostic> diagnosticsOf(DraftDocument doc) =>
    ParametricSystem(doc, parametricCatalog).diagnostics();

String enc(DraftDocument d) => DraftDocumentCodec.encodeToString(d);

/// Entities sorted by handle: slot order is history, not state (06 D11).
/// [sortNodes] also sorts every node's child list: `RemoveNodeCommand`'s
/// inverse re-links a restored node at the end of its parent, so a
/// delete-then-undo reorders the root's children without changing draw
/// order, which is ascending handle value (06's `encNodesSorted`).
String canon(DraftDocument d, {bool sortNodes = false}) {
  final j = DraftDocumentCodec.encode(d);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  if (sortNodes) {
    for (final n in j['nodes']! as List) {
      final children = (n as Map)['children'];
      if (children is List) {
        children.sort((a, b) => (a as int).compareTo(b as int));
      }
    }
  }
  return jsonEncode(j);
}

/// Decodes [s] with the floor planner's factories and installs its system.
DraftDocument reload(String s) {
  final doc = DraftDocumentCodec.decode(jsonDecode(s) as Map<String, Object?>,
      registerComponents: parametricCatalog.registerComponents);
  installParametric(doc);
  return doc;
}
