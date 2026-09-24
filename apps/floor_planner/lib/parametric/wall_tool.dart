import 'dart:math' as math;
import 'dart:ui' show Canvas;

import 'package:flutter/foundation.dart' show ValueNotifier, immutable;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall.dart';
import 'wall_geometry.dart';

/// The Wall tool's settings (spec 07 D11): what the next wall is drawn
/// with. The shell owns them; the panel edits them (Task 8).
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

/// The Wall tool's object-snap kinds: the drag kinds plus `nearest`, so a
/// click on a centreline's body lands on it and makes a T (spec 07 D11).
final SnapMask kWallSnapMask = kDragSnapMask.with_(SnapKind.nearest);

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
///   onto that wall (see [_joinBand]), so a click nearer a face than the
///   centreline still makes a T or a node.
/// - Enter and Escape end the chain. Every other key-down is swallowed
///   while it is pending (05 D3): undo never lands mid-chain (Ruling 07-1).
///
/// [points] holds the chain's first point and, once a wall is down, its
/// last: the next wall's start.
class WallTool extends PlacementTool {
  WallTool(this.settings);

  /// Owned by the shell and shared with the panel, which edits it (Task 8);
  /// the tool only reads it, at each commit and each paint.
  final ValueNotifier<WallSettings> settings;

  int _walls = 0;

  /// The rubber band's far end: the hover point, joined to a wall when it
  /// lies in one's band. Reused, never reallocated.
  final Vector2 _bandEnd = Vector2.zero();

  /// The document of the last hover, for [hovered], which has no context.
  DraftDocument? _document;

  @override
  String get name => 'Wall';

  @override
  SnapMask get snapMask => kWallSnapMask;

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
    _document = ctx.document;
    super.onPointerMove(e, ctx);
  }

  /// Runs after every hover's resolution (and re-resolution), so
  /// [hoverPoint] is already the resolved point.
  @override
  void hovered(Vector2 raw) {
    final doc = _document;
    _bandEnd.setFrom(
        (doc == null ? null : _joinBand(doc, hoverPoint)) ?? hoverPoint);
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (!acceptingSelf) point = _joinBand(ctx.document, point) ?? point;
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
  /// [p] is in a wall's band when it lies between the wall's two faces (by
  /// its justification) and its projection lies within the centreline's
  /// length, both within `wallJoin.linear`. Then:
  /// - within one thickness of a centreline end, along the centreline, it
  ///   joins that end: bitwise the world endpoint, computed as `WallType`
  ///   computes it (`WorldWall` of the params and the group's transform),
  ///   so the two walls make a node;
  /// - otherwise it joins the projection onto the centreline: a T.
  ///
  /// When several walls qualify, the lowest handle wins. Null when [p] is
  /// in no wall's band. O(walls), per click and per hover: never on the
  /// frame path.
  static Vector2? _joinBand(DraftDocument doc, Vector2 p) {
    final tol = wallJoin.linear;
    for (final h in doc.components.withComponent<WallParams>()) {
      final w = WorldWall(h, doc.components.get<WallParams>(h)!,
          doc.tree.accumulatedTransform(h));
      if (w.degenerate) continue;
      final d = w.d;
      final vx = p.x - w.s.x, vy = p.y - w.s.y;
      final along = vx * d.x + vy * d.y;
      // Along the left normal (-d.y, d.x), as the face offsets are.
      final across = vy * d.x - vx * d.y;
      final (left, right) = w.offsets;
      final length = w.s.distanceTo(w.e);
      if (across > left + tol ||
          across < right - tol ||
          along < -tol ||
          along > length + tol) {
        continue;
      }
      final toEnd = length - along;
      if (along <= w.t || toEnd <= w.t) return along <= toEnd ? w.s : w.e;
      return Vector2(w.s.x + d.x * along, w.s.y + d.y * along);
    }
    return null;
  }

  /// Spec 07 D2: a wall no longer than `wallJoin.linear` is degenerate.
  static bool _tooShort(Vector2 s, Vector2 e) =>
      !(s.distanceTo(e) > wallJoin.linear);

  /// One wall from [s] to [e] in world, which is its group's local space:
  /// the group sits at the identity.
  bool _addWall(ToolContext ctx, Vector2 s, Vector2 e) {
    if (_tooShort(s, e)) return false;
    final w = settings.value;
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
