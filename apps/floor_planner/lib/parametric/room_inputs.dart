// What a room traces (spec 10 D4): every live wall's uncut band and every
// live separator's segment, in world, through two adapters that agree bit
// for bit -- the view adapter for `generate`, `diagnose` and `placeBox`, and
// the document adapter for the tools -- and the band trimming of a drawn
// separator (D20). No Flutter import: this file is Dart over
// `package:jet_cad_2d` and `vector_math` only (spec 10 D1).
import 'dart:async' show StreamSubscription, unawaited;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'opening_geometry.dart' show wallsInView;
import 'room_trace.dart' show PlaceSource, distToSegment, pointInRing;
import 'separator.dart';
import 'wall.dart';
import 'wall_geometry.dart';

/// Every geometric decision of the room tracer (spec 10 D5, R-6): two
/// points within [Tolerance.linear] are one vertex, a segment no longer
/// than it is dropped (and a separator no longer than it is degenerate,
/// D3), and two directions within [Tolerance.angular] are parallel.
///
/// The linear part is 07's `wallJoin.linear`, so a joint 07 builds is a
/// joint the tracer sees: with 1e-12 the T butts are missed off the origin
/// and rooms merge (the spike's M-tol, a worst error of 53,514,299.998 mm²
/// at 1e9 mm). The angular part is the spike's parallel threshold, tested
/// at all six placements. Stored values are still compared with exact `==`.
const Tolerance roomTrace = Tolerance(linear: 1e-6, angular: 1e-12);

/// One input to the tracer (spec 10 D4): a wall's uncut band, closed, or a
/// separator's segment, open, in world, tagged with its [source] handle.
///
/// It is also the object's `placeInput` (spec 10 D16), compared with exact
/// `==` between an edit's before- and after-views: equal inputs have equal
/// [points], bit for bit (`-0.0 == 0.0` aside), and so an equal [box] and
/// an equal trace. The points are never mutated by anyone who reads them.
final class RoomInput {
  RoomInput(this.source, List<Vector2> points, {required this.closed})
      : points = List.unmodifiable(points);

  final Handle source;

  /// True for a wall's band (a ring, its first point not repeated), false
  /// for a separator's two-point segment.
  final bool closed;

  /// World points, never mutated.
  final List<Vector2> points;

  /// The world box of [points]: the object's place box (spec 10 D16).
  late final Aabb2 box = Aabb2.fromPoints(points);

  @override
  bool operator ==(Object other) {
    if (other is! RoomInput ||
        other.source != source ||
        other.closed != closed ||
        other.points.length != points.length) {
      return false;
    }
    for (var i = 0; i < points.length; i++) {
      if (other.points[i].x != points[i].x ||
          other.points[i].y != points[i].y) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(source, closed,
      Object.hashAll([for (final p in points) Object.hash(p.x, p.y)]));

  @override
  String toString() => 'RoomInput(${source.toHex()}, '
      '${closed ? 'band' : 'segment'}, $points)';
}

/// [h]'s input to the tracer from its component [params] and its group's
/// accumulated transform [toWorld] (spec 10 D4): the one function both
/// adapters call.
///
/// - `WallParams`: the wall's uncut band, [localOutlineOf] among [walls]
///   (its wall neighbours, ascending) taken to world through [toWorld] --
///   the ring 07 stores for the wall when it has no openings, so a
///   doorway, a window or a gap never breaks a room (R-5: the local ring,
///   not 07's world outline, so the band traced is the one drawn). None for
///   07 D2's degenerate wall (an empty ring).
/// - `SeparatorParams`: its world segment, open. None when its length is
///   not more than `roomTrace.linear` or an endpoint is not finite (D3's
///   degenerate separator).
/// - anything else: none. Boxes and openings are not inputs.
///
/// A result with a non-finite coordinate is none (S-6).
RoomInput? roomInputOf(Handle h, Component params, Transform2 toWorld,
    {List<WorldWall> walls = const []}) {
  switch (params) {
    case final WallParams p:
      final ring = localOutlineOf(WorldWall(h, p, toWorld), walls).ring;
      if (ring.isEmpty) return null;
      final world = [for (final q in ring) toWorld.transformPoint(q)];
      if (!world.every(_finite)) return null;
      return RoomInput(h, world, closed: true);
    case final SeparatorParams p:
      final s = toWorld.transformPoint(p.start);
      final e = toWorld.transformPoint(p.end);
      if (!_finite(s) || !_finite(e)) return null;
      if (!((e - s).length > roomTrace.linear)) return null;
      return RoomInput(h, [s, e], closed: false);
    default:
      return null;
  }
}

bool _finite(Vector2 p) => p.x.isFinite && p.y.isFinite;

// ---------------------------------------------------------------------------
// The view adapter.

/// Each view's [roomInputInView] results, by handle. A view is built for one
/// pass (an edit's trigger and plan, `drift()`, `diagnostics()`) over a
/// document that does not change during it, so each band is computed once
/// per view however many place boxes and traces read it (spec 10 D4; 08's
/// `hostCutsInView` precedent).
final Expando<Map<Handle, RoomInput?>> _inputsByView =
    Expando('roomInputInView');

/// [h]'s input through the view adapter (spec 10 D4): a wall's neighbours
/// are `view.neighbours(h)` carrying `WallParams`, ascending. Memoised per
/// [view] and handle. Null for a handle that is not a live wall or
/// separator of the view, and for a degenerate one.
RoomInput? roomInputInView(ParametricView view, Handle h) {
  final memo = _inputsByView[view] ??= <Handle, RoomInput?>{};
  if (memo.containsKey(h)) return memo[h];
  return memo[h] = _inputInView(view, h);
}

RoomInput? _inputInView(ParametricView view, Handle h) {
  if (wallsInView(view, h) case final w?) {
    return roomInputOf(h, w.host.params, w.host.toWorld, walls: w.walls);
  }
  if (view.paramsOf<SeparatorParams>(h) case final s?) {
    return roomInputOf(h, s, view.toWorld(h));
  }
  return null;
}

/// [h]'s place box through the view adapter: its input's box, or null.
Aabb2? placeBoxInView(ParametricView view, Handle h) =>
    roomInputInView(view, h)?.box;

/// The whole plane, as a box: `placedIn` of it lists every contributor.
const Aabb2 _everywhere = Aabb2.raw(double.negativeInfinity,
    double.negativeInfinity, double.infinity, double.infinity);

/// Each view's [placeSourceInView], so `U` is computed once per view.
final Expando<PlaceSource> _sourceByView = Expando('placeSourceInView');

/// What a room traces among inside `generate` and `diagnose` (spec 10 D7):
/// the view's `placedIn`, [roomInputInView], and `U` the union of
/// `placeBoxOf(h)` over `placedIn` of the whole plane (Ruling 10-13), the
/// engine having already turned a non-finite box into null. Memoised per
/// [view], `U` included.
PlaceSource placeSourceInView(ParametricView view) =>
    _sourceByView[view] ??= _ViewSource(view);

final class _ViewSource implements PlaceSource {
  _ViewSource(this.view);

  final ParametricView view;

  @override
  List<Handle> placedIn(Aabb2 box) => view.placedIn(box);

  @override
  RoomInput? inputOf(Handle h) => roomInputInView(view, h);

  @override
  late final Aabb2? bounds = () {
    var u = Aabb2.empty();
    for (final h in view.placedIn(_everywhere)) {
      if (view.placeBoxOf(h) case final b?) u = u.union(b);
    }
    return u.isEmpty ? null : u;
  }();
}

// ---------------------------------------------------------------------------
// The document adapter.

/// The engine's neighbour predicate, not a geometric decision of rooms
/// (Ruling 10-10): two reaches are neighbours when they overlap by more than
/// this on both axes (`_Survey.neighboursOf`). The document adapter must
/// find exactly the neighbours `ParametricView.neighbours` does, so it uses
/// the engine's own amount.
final double _engineNeighbourOverlap = Tolerance.standard.linear;

/// The trace inputs of a whole document, for the Room and Separator tools
/// and the separator grips (spec 10 D4, D19-D21; Ruling 10-11): the
/// **document adapter**. The shell owns one instance and hands it to all
/// three.
///
/// It holds every **live** wall and separator (a root-level group carrying
/// the component, as the engine's survey reads one), each wall's wall
/// neighbours by the engine's own predicate over `WallType().reach`, each
/// input and place box, and [bounds]. The inputs are those the view adapter
/// gives, bit for bit (`RI1`).
///
/// Marked stale on each of the document's changes (its `changes` stream,
/// which delivers after the task that made the change) and on [invalidate],
/// and rebuilt at the next query.
///
/// It is the tools' [PlaceSource] (spec 10 D7, D19): `traceRoomAmong(seed,
/// roomInputs)` traces what a room there would.
final class RoomInputs implements PlaceSource {
  RoomInputs(this.document) {
    _changes = document.changes.listen((_) => invalidate());
  }

  final DraftDocument document;
  StreamSubscription<DocChange>? _changes;
  bool _stale = true;
  int _generation = 0;

  /// Bumped whenever the cache goes stale: on each of the document's
  /// changes and on [invalidate]. A tool that caches something derived from
  /// the inputs (a traced preview) compares it with the value it built at.
  int get generation => _generation;

  /// The next query rebuilds the cache. The document's `changes` stream
  /// delivers only after the task that made a change, so whatever reads
  /// the cache in the task of an edit calls this first: it must never read
  /// an input the document no longer has. The Room and Separator tools call
  /// it at each click and again right after their `execute`; the separator
  /// grips call it at release, before they trim, since they never execute
  /// (the select tool executes the command they return).
  void invalidate() {
    _stale = true;
    _generation++;
  }

  final Map<Handle, RoomInput?> _inputs = {};
  final Map<Handle, List<Handle>> _neighbours = {};

  /// Every contributor with an input, ascending, and its place box.
  final List<(Handle, Aabb2)> _placed = [];
  Aabb2? _bounds;

  /// How many times the cache was rebuilt. Never reset.
  int debugRebuilds = 0;

  /// [h]'s input, or null when [h] is not a live wall or separator or is
  /// degenerate.
  @override
  RoomInput? inputOf(Handle h) {
    _refresh();
    return _inputs[h];
  }

  /// [h]'s place box: its input's box, or null.
  Aabb2? placeBoxOf(Handle h) => inputOf(h)?.box;

  /// Live wall [h]'s wall neighbours, ascending, as `ParametricView
  /// .neighbours` lists the walls among them; empty for any other handle.
  List<Handle> wallNeighboursOf(Handle h) {
    _refresh();
    return _neighbours[h] ?? const [];
  }

  /// The live walls and separators, ascending, whose place box touches
  /// [box] (closed: touching counts), as `ParametricView.placedIn` answers.
  @override
  List<Handle> placedIn(Aabb2 box) {
    _refresh();
    return List.unmodifiable([
      for (final (h, b) in _placed)
        if (b.intersects(box)) h,
    ]);
  }

  /// `U` (spec 10 D7): the bounding box of every place box, all of them
  /// finite. Null when nothing is placed.
  @override
  Aabb2? get bounds {
    _refresh();
    return _bounds;
  }

  void _refresh() {
    if (!_stale) return;
    _stale = false;
    debugRebuilds++;
    _inputs.clear();
    _neighbours.clear();
    _placed.clear();
    final doc = document;
    final walls = <WorldWall>[
      for (final h in liveObjectsOf<WallParams>(doc))
        WorldWall(h, doc.components.get<WallParams>(h)!,
            doc.tree.accumulatedTransform(h)),
    ];
    _sweep(walls);
    final byHandle = {for (final w in walls) w.handle: w};
    for (final w in walls) {
      _inputs[w.handle] = roomInputOf(w.handle, w.params, w.toWorld, walls: [
        for (final n in _neighbours[w.handle]!) byHandle[n]!,
      ]);
    }
    for (final h in liveObjectsOf<SeparatorParams>(doc)) {
      _inputs[h] = roomInputOf(h, doc.components.get<SeparatorParams>(h)!,
          doc.tree.accumulatedTransform(h));
    }
    final order = _inputs.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    var u = Aabb2.empty();
    for (final h in order) {
      if (_inputs[h] case final input?) {
        _placed.add((h, input.box));
        u = u.union(input.box);
      }
    }
    _bounds = u.isEmpty ? null : u;
  }

  /// Each wall's wall neighbours, ascending: one sort-and-sweep over the
  /// walls' reaches with the engine's predicate (spec 10 D16.5's pass).
  void _sweep(List<WorldWall> walls) {
    const type = WallType();
    final boxes = [
      for (final w in walls) (w.handle, type.reach(w.params, w.toWorld)),
    ]..sort((p, q) => p.$2.minX.compareTo(q.$2.minX));
    final tol = _engineNeighbourOverlap;
    final found = <Handle, List<Handle>>{
      for (final w in walls) w.handle: <Handle>[],
    };
    for (var i = 0; i < boxes.length; i++) {
      final (ha, a) = boxes[i];
      final bound = a.maxX - tol;
      for (var j = i + 1; j < boxes.length; j++) {
        final (hb, b) = boxes[j];
        if (!(b.minX < bound)) break;
        if (a.minX < b.maxX - tol &&
            a.minY < b.maxY - tol &&
            b.minY < a.maxY - tol) {
          found[ha]!.add(hb);
          found[hb]!.add(ha);
        }
      }
    }
    for (final MapEntry(key: h, value: list) in found.entries) {
      _neighbours[h] =
          List.unmodifiable(list..sort((a, b) => a.value.compareTo(b.value)));
    }
  }

  /// Cancels the document subscription. The owner calls it once.
  void dispose() {
    final changes = _changes;
    if (changes != null) unawaited(changes.cancel());
    _changes = null;
  }
}

/// The live objects of [doc] carrying a [T], ascending: a root-level group
/// carrying the component, as the engine's survey reads one. A component on
/// a nested group, or on a handle with no node (a deleted object's), is not
/// one (08's final review m5).
List<Handle> liveObjectsOf<T extends Component>(DraftDocument doc) => [
      for (final h in doc.components.withComponent<T>())
        if (doc.tree[h] case final GroupNode node
            when node.parent == doc.tree.root)
          h,
    ]..sort((a, b) => a.value.compareTo(b.value));

// ---------------------------------------------------------------------------
// Band trimming (spec 10 D20, R-21).

/// The separator a person draws from [a] to [b], in world, as it is stored
/// (spec 10 D20, R-21; Ruling 10-9): the one function the Separator tool and
/// the separator grips call.
///
/// With [objectSnap] (F3), an end inside a wall's uncut band ([inputs]'
/// closed inputs) moves back along the segment to the first point where the
/// segment, walked from its other end as placed, enters that band: the
/// stored end lies on the face, to rounding, so it joins the face (D5) and
/// the separator does not draw into the wall. An end in open space stays
/// where it was put. An end inside several bands (walls that overlap) stops
/// at the first of their faces the walk meets. When the walk crosses into
/// another band first and passes into the end's band through a joint (a
/// mitre), the trimmed end lies in that other band: it is trimmed again,
/// to where the walk enters that one, and so on while it lies in, or within
/// `roomTrace.linear` of, a band not yet trimmed to (a mitre's end lies on
/// the edge the two bands share, where the crossing number may count it
/// out of either). Each round moves the end toward the other end along
/// the segment and uses up at least one band, so it stops. Both ends inside
/// one band: null.
///
/// Without [objectSnap], `(a, b)` as placed: trimming is object snapping,
/// and an end left inside a band still splits the face correctly.
///
/// Either way, a result no longer than `roomTrace.linear` is null: it
/// would be a degenerate separator (D3).
(Vector2, Vector2)? trimSeparator(Vector2 a, Vector2 b, RoomInputs inputs,
    {required bool objectSnap}) {
  var s = a, e = b;
  if (objectSnap) {
    final inA = _bandsHolding(a, inputs);
    final inB = _bandsHolding(b, inputs);
    if (inA.any(inB.contains)) return null;
    if (inB.isNotEmpty) e = _trimmed(a, b, inB, inputs);
    if (inA.isNotEmpty) s = _trimmed(b, a, inA, inputs);
  }
  if (!((e - s).length > roomTrace.linear)) return null;
  return (s, e);
}

/// [to], which [bands] hold, walked back from [from] to where the walk
/// enters them ([_entry]), then again while the point reached lies in, or
/// on the boundary of, a band not yet used.
Vector2 _trimmed(
    Vector2 from, Vector2 to, List<RoomInput> bands, RoomInputs inputs) {
  final used = {...bands};
  var end = _entry(from, to, bands);
  while (true) {
    final more = [
      for (final band in _bandsTouching(end, inputs))
        if (used.add(band)) band,
    ];
    if (more.isEmpty) return end;
    end = _entry(from, end, more);
  }
}

/// The bands among [inputs] that hold [p] (the crossing-number test, taken
/// relative to [p], as the tracer takes its seed).
List<RoomInput> _bandsHolding(Vector2 p, RoomInputs inputs) => [
      for (final h in inputs.placedIn(Aabb2.raw(p.x, p.y, p.x, p.y)))
        if (inputs.inputOf(h) case final input? when input.closed)
          if (pointInRing(
              Vector2.zero(), [for (final q in input.points) q - p]))
            input,
    ];

/// The bands among [inputs] that hold [p] or pass within
/// `roomTrace.linear` of it.
List<RoomInput> _bandsTouching(Vector2 p, RoomInputs inputs) {
  final tol = roomTrace.linear;
  final near = Aabb2.raw(p.x - tol, p.y - tol, p.x + tol, p.y + tol);
  return [
    for (final h in inputs.placedIn(near))
      if (inputs.inputOf(h) case final input? when input.closed)
        if (_touches(p, input.points, tol)) input,
  ];
}

/// Whether ring [r] holds [p] or passes within [tol] of it, relative to [p].
bool _touches(Vector2 p, List<Vector2> r, double tol) {
  final local = [for (final q in r) q - p];
  final o = Vector2.zero();
  if (pointInRing(o, local)) return true;
  for (var i = 0; i < local.length; i++) {
    if (distToSegment(o, local[i], local[(i + 1) % local.length]) <= tol) {
      return true;
    }
  }
  return false;
}

/// The first point where the segment walked from [from] to [to] crosses an
/// edge of one of [bands], all of which hold [to]: where it enters them.
/// Solved relative to [from], so the point lies on the face to rounding at
/// any distance from the origin. [to] itself when no edge is crossed (a
/// point on a band's boundary, which the crossing-number test may count
/// either way).
Vector2 _entry(Vector2 from, Vector2 to, List<RoomInput> bands) {
  final r = to - from;
  var best = double.infinity;
  for (final band in bands) {
    final pts = band.points;
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      final c = pts[i] - from, d = pts[(i + 1) % n] - from;
      final sx = d.x - c.x, sy = d.y - c.y;
      final denom = r.x * sy - r.y * sx;
      if (denom == 0) continue;
      final t = (c.x * sy - c.y * sx) / denom;
      final u = (c.x * r.y - c.y * r.x) / denom;
      if (t >= 0 && t <= 1 && u >= 0 && u <= 1 && t < best) best = t;
    }
  }
  return best.isFinite ? from + r * best : to;
}
