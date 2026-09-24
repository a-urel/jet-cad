import 'dart:async' show StreamSubscription, unawaited;
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;
import 'dart:ui' show Canvas;

import 'package:flutter/foundation.dart'
    show ValueNotifier, immutable, visibleForTesting;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall.dart';
import 'wall_geometry.dart';

/// The Wall tool's settings (spec 07 D11): what the next wall is drawn
/// with. The shell owns them; the Selection panel's Wall section edits
/// them while the tool is active.
@immutable
final class WallSettings {
  const WallSettings(
      {this.thickness = 200, this.justification = Justification.centre});

  /// In mm.
  final double thickness;
  final Justification justification;

  WallSettings copyWith({double? thickness, Justification? justification}) =>
      WallSettings(
          thickness: thickness ?? this.thickness,
          justification: justification ?? this.justification);

  @override
  bool operator ==(Object other) =>
      other is WallSettings &&
      other.thickness == thickness &&
      other.justification == justification;

  @override
  int get hashCode => Object.hash(thickness, justification);

  @override
  String toString() => 'WallSettings($thickness, ${justification.name})';
}

/// Spec 07 D11, Ruling 07-1: a chain of walls, like AutoCAD's LINE.
///
/// - The first click sets the chain's start; each later click commits
///   **one wall** from the previous point, one undo step each.
/// - A wall is a group at the identity carrying [WallParams], so its stored
///   endpoints are the snapped points themselves and a chained run meets
///   bit for bit.
/// - A click on the chain's first point, once two walls are down, commits
///   the closing wall and ends the chain. A click on its last point, once
///   a wall is down, ends it (so a double click is harmless). Before that, a
///   click on the start is a zero-length wall and is refused, as the Line
///   tool refuses one (M-05x).
/// - **It joins a wall wherever its band is clicked** (D11): an accepted
///   point, and the rubber band's end, that lies in a wall's band is moved
///   onto that wall (see [_joinBandInto]): a T, or a node near an end.
///   This is the only way it makes a joint; it snaps with the drawing
///   tools' own kinds (03 D8), never `nearest`, which would pull a click
///   onto any unrelated line near it and away from the grid.
/// - Enter and Escape end the chain. Every other key-down is swallowed
///   while it is pending (05 D3): undo never lands mid-chain (Ruling 07-1).
///
/// [points] holds the chain's first point and, once a wall is down, its
/// last: the next wall's start.
class WallTool extends PlacementTool {
  WallTool(this.settings);

  /// Owned by the shell and shared with the Selection panel, which edits it;
  /// the tool only reads it, at each commit and each paint.
  final ValueNotifier<WallSettings> settings;

  int _walls = 0;

  /// The rubber band's far end: the hover point, joined to a wall when it
  /// lies in one's band. Reused, never reallocated.
  final Vector2 _bandEnd = Vector2.zero();

  /// The context of the last hover, for [hovered], which has none.
  ToolContext? _context;

  /// The band scan's cache (see [_joinBandInto]): per non-degenerate wall,
  /// ascending by handle, [_stride] doubles -- the world start and end
  /// (`WorldWall`'s own `s` and `e`, so bitwise what `WallType` builds),
  /// the unit direction, the length, the left and right face offsets and
  /// the thickness. Rebuilt only when [_cachedDocument] reports a change.
  static const int _stride = 10;
  Float64List _cache = Float64List(_stride * 16);
  int _cachedWalls = 0;
  bool _cacheStale = true;
  DraftDocument? _cachedDocument;
  StreamSubscription<DocChange>? _changes;

  /// How many band scans have run: a test seam for the early return.
  @visibleForTesting
  int debugBandScans = 0;

  /// The rubber band's far end, for tests.
  @visibleForTesting
  Vector2 get debugBandEnd => _bandEnd;

  @override
  String get name => 'Wall';

  @override
  Vector2? selfSnap(Vector2 raw, double apertureWorld) {
    if (_walls >= 2 && raw.distanceTo(points.first) <= apertureWorld) {
      return points.first;
    }
    if (_walls >= 1 && raw.distanceTo(points.last) <= apertureWorld) {
      return points.last;
    }
    return null;
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    _context = ctx;
    super.onPointerMove(e, ctx);
  }

  /// Runs after every hover's resolution (and re-resolution), so
  /// [hoverPoint] is already the resolved point. With no chain pending
  /// there is no rubber band, and nothing to scan.
  @override
  void hovered(Vector2 raw) {
    if (points.isEmpty) return;
    final ctx = _context;
    final p = hoverPoint;
    if (ctx == null || !_joinBandInto(ctx, p.x, p.y, _bandEnd)) {
      _bandEnd.setFrom(p);
    }
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (!acceptingSelf) {
      final joined = Vector2.zero();
      if (_joinBandInto(ctx, point.x, point.y, joined)) point = joined;
    }
    // Until the next hover, the band ends where this click landed.
    _bandEnd.setFrom(point);
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    if (acceptingSelf) {
      // Ruling 05-4: the accepted point *is* the stored first point.
      if (_walls >= 2 && identical(point, points.first)) {
        _addWall(ctx, points.last, point);
      }
      clearShape();
      return;
    }
    final start = points.last;
    if (_tooShort(start, point)) return;
    if (!_addWall(ctx, start, point)) {
      clearShape();
      return;
    }
    _walls++;
    if (points.length == 1) {
      points.add(point);
    } else {
      points[1] = point;
    }
  }

  @override
  void finish(ToolContext ctx) => clearShape();

  @override
  void clearShape() {
    super.clearShape();
    _walls = 0;
  }

  /// Spec 07 D11: the Wall tool joins a wall wherever its band is clicked.
  ///
  /// With object snap off (F3) nothing is joined, like every other snap
  /// (`PlacementTool` reads the same setting). Otherwise `(px, py)` is in a
  /// wall's band when it lies between the wall's two faces (by its
  /// justification) and its projection lies within the centreline's
  /// length, both within `wallJoin.linear`. Then [out] is set to:
  /// - within one thickness of a centreline end, along the centreline, that
  ///   end: bitwise the world endpoint `WallType` builds (`WorldWall` of the
  ///   params and the group's transform), so the two walls make a node;
  /// - otherwise the projection onto the centreline: a T.
  ///
  /// When several walls qualify, the lowest handle wins. Returns false, and
  /// leaves [out] alone, when the point is in no wall's band.
  ///
  /// It runs on every pointer move while a chain is pending: an O(walls)
  /// scan over cached doubles that allocates nothing in steady state. The
  /// cache is rebuilt after the document changes (its `changes` stream,
  /// which delivers before the next pointer event) and after this tool's
  /// own commit.
  bool _joinBandInto(ToolContext ctx, double px, double py, Vector2 out) {
    if (!(ctx.snap?.objectSnap ?? true)) return false;
    _refreshCache(ctx.document);
    debugBandScans++;
    final tol = wallJoin.linear;
    final c = _cache;
    for (var i = 0, o = 0; i < _cachedWalls; i++, o += _stride) {
      final sx = c[o], sy = c[o + 1];
      final dx = c[o + 4], dy = c[o + 5];
      final length = c[o + 6];
      final vx = px - sx, vy = py - sy;
      final along = vx * dx + vy * dy;
      // Along the left normal (-dy, dx), as the face offsets are.
      final across = vy * dx - vx * dy;
      if (across > c[o + 7] + tol ||
          across < c[o + 8] - tol ||
          along < -tol ||
          along > length + tol) {
        continue;
      }
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
    return false;
  }

  void _refreshCache(DraftDocument doc) {
    if (!identical(doc, _cachedDocument)) {
      final old = _changes;
      if (old != null) unawaited(old.cancel());
      _cachedDocument = doc;
      _changes = doc.changes.listen((_) => _cacheStale = true);
      _cacheStale = true;
    }
    if (!_cacheStale) return;
    _cacheStale = false;
    _cachedWalls = 0;
    for (final h in doc.components.withComponent<WallParams>()) {
      final w = WorldWall(h, doc.components.get<WallParams>(h)!,
          doc.tree.accumulatedTransform(h));
      if (w.degenerate) continue;
      if ((_cachedWalls + 1) * _stride > _cache.length) {
        _cache = Float64List(_cache.length * 2)..setAll(0, _cache);
      }
      final (left, right) = w.offsets;
      _cache.setAll(_cachedWalls * _stride, [
        w.s.x, w.s.y, w.e.x, w.e.y, w.d.x, w.d.y, //
        w.s.distanceTo(w.e), left, right, w.t,
      ]);
      _cachedWalls++;
    }
  }

  /// Spec 07 D2: a wall no longer than `wallJoin.linear` is degenerate.
  static bool _tooShort(Vector2 s, Vector2 e) =>
      !(s.distanceTo(e) > wallJoin.linear);

  /// One wall from [s] to [e] in world, which is its group's local space:
  /// the group sits at the identity.
  bool _addWall(ToolContext ctx, Vector2 s, Vector2 e) {
    if (_tooShort(s, e)) return false;
    final w = settings.value;
    _cacheStale = true;
    return commit(ctx, () {
      final doc = ctx.document;
      final h = doc.handleSeed.next();
      return CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: doc.rootHandle,
            transform: Transform2.identity(),
            children: const [])),
        SetComponentCommand<WallParams>(
            h, WallParams(s.x, s.y, e.x, e.y, w.thickness, w.justification)),
      ], label: 'Add wall');
    }, needs: const {
      Capability.structure,
      Capability.components,
      Capability.geometry,
    });
  }

  @override
  void dispose() {
    final changes = _changes;
    if (changes != null) unawaited(changes.cancel());
    _changes = null;
    super.dispose();
  }

  /// The next wall's centreline and its band at the current thickness and
  /// justification, from the chain's last point to the hover point.
  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final a = points.last, b = _bandEnd;
    final ax = a.x - origin.x, ay = a.y - origin.y;
    final bx = b.x - origin.x, by = b.y - origin.y;
    band
      ..reset()
      ..moveTo(ax, ay)
      ..lineTo(bx, by);
    final dx = bx - ax, dy = by - ay;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len > 0) {
      // The left normal and the faces' offsets along it, as WorldWall's.
      final nx = -dy / len, ny = dx / len;
      final t = settings.value.thickness;
      final (l, r) = switch (settings.value.justification) {
        Justification.centre => (t / 2, -t / 2),
        Justification.left => (t, 0.0),
        Justification.right => (0.0, -t),
      };
      band
        ..moveTo(ax + nx * l, ay + ny * l)
        ..lineTo(bx + nx * l, by + ny * l)
        ..lineTo(bx + nx * r, by + ny * r)
        ..lineTo(ax + nx * r, ay + ny * r)
        ..close();
    }
    canvas.drawPath(band, bandPaint);
  }
}
