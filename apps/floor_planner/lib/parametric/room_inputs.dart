// What a room traces (spec 10 D4): every live wall's uncut band and every
// live separator's segment, in world, through two adapters that agree bit
// for bit -- the view adapter for `generate`, `diagnose` and `placeBox`, and
// the document adapter for the tools. No Flutter import: this file is Dart
// over `package:jet_cad_2d` and `vector_math` only (spec 10 D1).
import 'dart:async' show StreamSubscription, unawaited;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'opening_geometry.dart' show wallsInView;
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
/// which delivers after the task that made the change) and rebuilt at the
/// next query.
final class RoomInputs {
  RoomInputs(this.document) {
    _changes = document.changes.listen((_) => _stale = true);
  }

  final DraftDocument document;
  StreamSubscription<DocChange>? _changes;
  bool _stale = true;

  final Map<Handle, RoomInput?> _inputs = {};
  final Map<Handle, List<Handle>> _neighbours = {};

  /// Every contributor with an input, ascending, and its place box.
  final List<(Handle, Aabb2)> _placed = [];
  Aabb2 _bounds = Aabb2.empty();

  /// How many times the cache was rebuilt. Never reset.
  int debugRebuilds = 0;

  /// [h]'s input, or null when [h] is not a live wall or separator or is
  /// degenerate.
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
  List<Handle> placedIn(Aabb2 box) {
    _refresh();
    return List.unmodifiable([
      for (final (h, b) in _placed)
        if (b.intersects(box)) h,
    ]);
  }

  /// `U` (spec 10 D7): the bounding box of every place box, all of them
  /// finite. Empty when nothing is placed.
  Aabb2 get bounds {
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
      for (final h in _live<WallParams>(doc))
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
    for (final h in _live<SeparatorParams>(doc)) {
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
    _bounds = u;
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
List<Handle> _live<T extends Component>(DraftDocument doc) => [
      for (final h in doc.components.withComponent<T>())
        if (doc.tree[h] case final GroupNode node
            when node.parent == doc.tree.root)
          h,
    ]..sort((a, b) => a.value.compareTo(b.value));
