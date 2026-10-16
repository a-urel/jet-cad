import 'dart:async' show StreamSubscription, unawaited;
import 'dart:collection' show UnmodifiableListView;
import 'dart:typed_data' show Float64List;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show Disposable, PlanServices;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../ids.dart';
import '../live.dart';
import 'wall.dart';
import 'wall_geometry.dart';

/// The kit's one [WallBands] for [services]' document (spec 3a C2): a
/// `PlanServices.shared` object, disposed with its document. The wall tool,
/// the opening tools and the wall faces share it.
WallBands wallBandsOf(PlanServices services) =>
    services.shared<WallBands>((s) => WallBands(liveTypesOf(s)));

/// The walls' bands, cached for the tools that look for a wall under the
/// pointer on every move (spec 07 D11; spec 08 D14, Ruling 08-11): the Wall
/// tool, which joins a band it is clicked in, and the Door, Window and Gap
/// tools, which find their host with [hostAt]. One per kit per document
/// ([wallBandsOf]); the four tools share it.
///
/// Per live, non-degenerate wall, ascending by handle, [_stride] doubles: the
/// world start and end (`WorldWall`'s own `s` and `e`, so bitwise what
/// `WallType` builds), the unit direction, the length, the left and right
/// face offsets and the thickness; and the wall's handle beside them.
/// Refreshed on a document change or a change in liveness: rebuilt when
/// the document reports a change (its `changes` stream, which delivers
/// after the task that made the change), when a tool calls [invalidate],
/// and when a read finds a cached wall no longer live (a plan freezes a
/// wall, spec 2a E2, with no document change: spec 3a C1.5). A frozen
/// object stays frozen for its document's life; a new document resets the
/// cache. A scan is O(walls) over the cached doubles, plus the liveness
/// check's O(cached objects) `liveTypeIdOf` calls, each over the catalog's
/// types (O(cached objects × the catalog's types)), and allocates nothing
/// in steady state.
final class WallBands implements Disposable {
  /// [live] names the live walls (`liveObjectsOf`): a frozen wall has no
  /// band.
  WallBands(this._live);

  final LiveTypeOf _live;

  static const int _stride = 10;
  Float64List _cache = Float64List(_stride * 16);
  final List<Handle> _handles = <Handle>[];
  late final List<Handle> _liveView = UnmodifiableListView(_handles);
  int _walls = 0;
  bool _stale = true;
  int _generation = 0;
  DraftDocument? _document;
  StreamSubscription<DocChange>? _changes;

  /// Bumped whenever the cache goes stale: on each of the document's
  /// changes, on [invalidate], when a read finds a cached wall no longer
  /// live, and when a different document is scanned. A
  /// tool that caches something derived from the walls compares it with
  /// the value it built at.
  int get generation => _generation;

  /// The next scan rebuilds the cache: a tool that has just committed, or
  /// is about to act on a click, must never see a band the document no
  /// longer has.
  void invalidate() {
    _stale = true;
    _generation++;
  }

  /// The live, non-degenerate walls of [doc], ascending by handle (spec
  /// 09c D3, D6): what the wall faces are built from. Runs the refresh, so
  /// the first call starts the document subscription and a caller that
  /// never asked [hostAt] or [joinInto] still sees current walls; a change
  /// moves [generation] as before.
  ///
  /// An unmodifiable **view** of the cache's own handle list, not a copy:
  /// no allocation per call, and it reads the walls of the latest refresh.
  /// Call again (which refreshes) before trusting it after a change.
  List<Handle> liveWalls(DraftDocument doc) {
    _refresh(doc);
    return _liveView;
  }

  /// The index of the lowest-handle wall whose band contains `(px, py)`, or
  /// -1. In a band: between the wall's two faces (by its justification) and
  /// within the centreline's length, both within `wallJoin.linear`. With
  /// [accept], a wall it refuses is passed over, as if it had no band.
  int _indexAt(DraftDocument doc, double px, double py,
      [bool Function(DraftDocument, Handle)? accept]) {
    _refresh(doc);
    final tol = wallJoin.linear;
    final c = _cache;
    for (var i = 0, o = 0; i < _walls; i++, o += _stride) {
      final sx = c[o], sy = c[o + 1];
      final dx = c[o + 4], dy = c[o + 5];
      final vx = px - sx, vy = py - sy;
      final along = vx * dx + vy * dy;
      // Along the left normal (-dy, dx), as the face offsets are.
      final across = vy * dx - vx * dy;
      if (across > c[o + 7] + tol ||
          across < c[o + 8] - tol ||
          along < -tol ||
          along > c[o + 6] + tol) {
        continue;
      }
      if (accept != null && !accept(doc, _handles[i])) continue;
      return i;
    }
    return -1;
  }

  /// The wall whose band contains the world point `(x, y)`, the lowest
  /// handle when several do (spec 08 D14), or null. With [accept], only a
  /// wall it accepts is a candidate (the Opening tools pass their layer
  /// rule, spec 12b S-11); it is called only for a wall whose band contains
  /// the point.
  Handle? hostAt(DraftDocument doc, double x, double y,
      {bool Function(DraftDocument, Handle)? accept}) {
    final i = _indexAt(doc, x, y, accept);
    return i < 0 ? null : _handles[i];
  }

  /// Spec 07 D11: where the Wall tool joins the world point `(px, py)`.
  /// When it lies in a wall's band (the lowest handle's, when several),
  /// [out] is set to:
  /// - within one thickness of a centreline end, along the centreline, that
  ///   end: bitwise the world endpoint `WallType` builds (`WorldWall` of the
  ///   params and the group's transform), so the two walls make a node;
  /// - otherwise the projection onto the centreline: a T.
  ///
  /// Returns false, and leaves [out] alone, when the point is in no band.
  bool joinInto(DraftDocument doc, double px, double py, Vector2 out) {
    final i = _indexAt(doc, px, py);
    if (i < 0) return false;
    final c = _cache;
    final o = i * _stride;
    final sx = c[o], sy = c[o + 1];
    final dx = c[o + 4], dy = c[o + 5];
    final length = c[o + 6];
    final along = (px - sx) * dx + (py - sy) * dy;
    final t = c[o + 9];
    final toEnd = length - along;
    if (along <= t || toEnd <= t) {
      if (along <= toEnd) {
        out.setValues(sx, sy);
      } else {
        out.setValues(c[o + 2], c[o + 3]);
      }
    } else {
      out.setValues(sx + dx * along, sy + dy * along);
    }
    return true;
  }

  void _refresh(DraftDocument doc) {
    if (!identical(doc, _document)) {
      final old = _changes;
      if (old != null) unawaited(old.cancel());
      _document = doc;
      _changes = doc.changes.listen((_) => invalidate());
      invalidate();
    }
    if (!_stale && !_stillLive()) invalidate();
    if (!_stale) return;
    _stale = false;
    _walls = 0;
    _handles.clear();
    // Live walls only, by the engine's object rule through [_live] (spec 3a
    // C1.5: a frozen wall is none). A stray `WallParams` (on a nested group,
    // on a handle with no node, or shadowed on a group a later-registered
    // type names: no tool makes one, but a file can bring each in) is not a
    // wall, and must not shadow one under it. O(walls · registered types), on
    // a rebuild only.
    for (final h
        in liveObjectsOf<WallParams>(doc, _live, ArchitectureTypes.wall)) {
      final w = WorldWall(h, doc.components.get<WallParams>(h)!,
          doc.tree.accumulatedTransform(h));
      if (w.degenerate) continue;
      if ((_walls + 1) * _stride > _cache.length) {
        _cache = Float64List(_cache.length * 2)..setAll(0, _cache);
      }
      final (left, right) = w.offsets;
      _cache.setAll(_walls * _stride, [
        w.s.x, w.s.y, w.e.x, w.e.y, w.d.x, w.d.y, //
        w.s.distanceTo(w.e), left, right, w.t,
      ]);
      _handles.add(h);
      _walls++;
    }
  }

  /// Whether every cached wall is still a live wall by [_live]: a plan
  /// freezes a wall (spec 2a E2) without changing the document, so no
  /// change reaches the stream, and a frozen wall must not keep its band
  /// (spec 3a C1.5). Runs on every read ([_refresh]), so every reader --
  /// [liveWalls], [hostAt], [joinInto] -- is covered. Iterates the cached
  /// handles in place: O(cached objects) calls of [_live], the plan's
  /// `liveTypeIdOf` (a set lookup and the catalog's naming rule, over its
  /// types), so O(cached objects × the catalog's types); no allocation.
  bool _stillLive() {
    for (var i = 0; i < _walls; i++) {
      if (_live(_handles[i]) != ArchitectureTypes.wall) return false;
    }
    return true;
  }

  /// Cancels the document subscription: `PlanServices.shared` calls it
  /// when the document goes.
  @override
  void dispose() {
    final changes = _changes;
    if (changes != null) unawaited(changes.cancel());
    _changes = null;
    _document = null;
  }
}
