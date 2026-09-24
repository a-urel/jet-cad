import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Which side of the centreline a wall's body lies on, looking from `start`
/// to `end` (spec 07 D2).
enum Justification { left, centre, right }

/// Every "do these join" decision for walls (spec 07 D7): endpoint
/// coincidence, a point on a centreline, parallel faces. Absolute, in mm.
///
/// Not `Tolerance.standard`: at the far origin one ulp is ~9.3e-10, and two
/// rotated groups leave a snapped joint up to ~4.7e-10 apart; 1e-6 is about a
/// thousand ulps there and far below anything drawn on purpose. Stored values
/// are still compared with exact `==`.
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
