import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall_geometry.dart';

/// Which side of the centreline a wall's body lies on, looking from `start`
/// to `end` (spec 07 D2).
enum Justification { left, centre, right }

/// Every "do these join" decision for walls (spec 07 D7): endpoint
/// coincidence, a point on a centreline, parallel faces. Absolute, in mm.
///
/// Not the engine's standard tolerance (1e-9): at the far origin one ulp is
/// ~9.3e-10, and two rotated groups leave a snapped joint up to ~4.7e-10
/// apart; 1e-6 is about a thousand ulps there and far below anything drawn
/// on purpose. Stored values are still compared with exact `==`.
const Tolerance wallJoin = Tolerance(linear: 1e-6, angular: 1e-9);

/// A wedge corner farther than this many half-thicknesses of the thicker
/// wall from the node is clamped (spec 07 D6).
const double mitreLimit = 4;

/// A wall's parameters (spec 07 D2): both centreline endpoints in
/// group-local space, the thickness and the justification, in mm.
///
/// Value-equal with exact `==` on the doubles: a stored value. `fromJson`
/// accepts a degenerate wall (length ≤ `wallJoin.linear` or thickness ≤ 0);
/// the geometry gives it no outline.
final class WallParams implements Component {
  const WallParams(
      this.sx, this.sy, this.ex, this.ey, this.thickness, this.justification);

  static const String componentTypeId = 'floor_planner.wall';

  final double sx, sy, ex, ey;
  final double thickness;
  final Justification justification;

  Vector2 get start => Vector2(sx, sy);
  Vector2 get end => Vector2(ex, ey);

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'start': [sx, sy],
        'end': [ex, ey],
        'thickness': thickness,
        'justification': justification.name,
      };

  /// Throws `ArgumentError` on an unknown justification name.
  static WallParams fromJson(Map<String, Object?> json) {
    final s = json['start']! as List;
    final e = json['end']! as List;
    return WallParams(
        (s[0] as num).toDouble(),
        (s[1] as num).toDouble(),
        (e[0] as num).toDouble(),
        (e[1] as num).toDouble(),
        (json['thickness']! as num).toDouble(),
        Justification.values.byName(json['justification']! as String));
  }

  WallParams copyWith(
          {Vector2? start,
          Vector2? end,
          double? thickness,
          Justification? justification}) =>
      WallParams(start?.x ?? sx, start?.y ?? sy, end?.x ?? ex, end?.y ?? ey,
          thickness ?? this.thickness, justification ?? this.justification);

  @override
  bool operator ==(Object other) =>
      other is WallParams &&
      other.sx == sx &&
      other.sy == sy &&
      other.ex == ex &&
      other.ey == ey &&
      other.thickness == thickness &&
      other.justification == justification;

  @override
  int get hashCode => Object.hash(sx, sy, ex, ey, thickness, justification);

  @override
  String toString() =>
      'WallParams(($sx, $sy) -> ($ex, $ey), $thickness, ${justification.name})';
}

/// A wall's world geometry from its parameters and its group's accumulated
/// transform: the one function every joint computation goes through (spec
/// 07 D4), so two walls that compute the same neighbour get the same bits.
/// Null when [h] carries no `WallParams` (a box, say).
WorldWall? _worldWall(ParametricView view, Handle h) {
  final p = view.paramsOf<WallParams>(h);
  return p == null ? null : WorldWall(h, p, view.toWorld(h));
}

/// [self]'s world outline among its wall neighbours (spec 07 D4-D6).
/// Neighbours that are not walls are ignored.
({List<Vector2> ring, bool fellBack, List<Handle>? hole}) _outlineOf(
    ParametricView view, WorldWall self) {
  final others = [
    for (final n in view.neighbours(self.handle))
      if (_worldWall(view, n) case final w?) w,
  ];
  return outline(self, others);
}

/// The wall (spec 07 D3, D4, D12): a region (the outline and its fill) and
/// the centreline, regenerated from its own parameters and its wall
/// neighbours'.
final class WallType extends ParametricType<WallParams> {
  const WallType();

  @override
  Capability get editCapability => Capability.geometry;

  /// The world centreline's bounding box, expanded by `wallJoin.linear`
  /// (spec 07 D4): every joint is a centreline relation, and an axis-aligned
  /// wall's box would otherwise have no height (or width) to overlap with.
  @override
  Aabb2 reach(WallParams params, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(params.start),
        toWorld.transformPoint(params.end),
      ]).expandedBy(wallJoin.linear);

  /// In this order, fixed at creation (spec 07 D3): the region, whose
  /// outline is computed in world space and taken to group-local space
  /// through `toWorld(self).invert()`, then the open centreline from
  /// `start` to `end`, the stored values themselves. A degenerate wall (D2)
  /// generates the centreline alone.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<WallParams>(self)!;
    final centreline =
        Generated(EntityKind.polyline, polylinePayload([p.start, p.end]));
    final me = _worldWall(view, self)!;
    final ring = _outlineOf(view, me).ring;
    if (ring.isEmpty) return [centreline];
    final toLocal = view.toWorld(self).invert();
    return [
      Generated.region(polylinePayload(
          [for (final q in ring) toLocal.transformPoint(q)],
          closed: true)),
      centreline,
    ];
  }

  /// At most one entry of each code for [self] (spec 07 D12), warnings:
  ///
  /// - `wall.hole`: [self] owns a crossing lobe that was dropped at one of
  ///   its nodes (D5.6), so the node shows a hole. Reported by the lobe's
  ///   owner only, naming every member wall. A wall owning such lobes at
  ///   both ends reports one entry naming both nodes' members.
  /// - `wall.fallback`: [self]'s joined outline was not simple, so it
  ///   squared both of its ends (D6's short wall).
  /// - `wall.degenerate`: [self] is D2's degenerate wall and has no outline;
  ///   nothing else is reported for it.
  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    final me = _worldWall(view, self)!;
    if (me.degenerate) {
      return [
        Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: 'wall.degenerate',
          message: 'wall ${self.toHex()} is no longer than the join '
              'tolerance or not thicker than zero: it has no outline',
          handles: [self],
        ),
      ];
    }
    final o = _outlineOf(view, me);
    return [
      if (o.hole case final members?)
        Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: 'wall.hole',
          message: 'the joint of walls '
              '${[for (final h in members) h.toHex()].join(', ')} leaves a '
              'hole: a crossing lobe was dropped',
          handles: members,
        ),
      if (o.fellBack)
        Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: 'wall.fallback',
          message: 'wall ${self.toHex()} is shorter than its corners: both '
              'of its ends are square',
          handles: [self],
        ),
    ];
  }
}
