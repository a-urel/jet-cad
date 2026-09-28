// SPIKE 11 -- throwaway. The dimension: a parametric object storing two ends
// (each a wall end point or a fixed point), a kind (aligned, horizontal,
// vertical) and an offset, and regenerating five lines and one TEXT.
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension_geometry.dart';
import 'opening_geometry.dart' show wallsInView;
import 'wall_geometry.dart' show WorldWall;

/// One end of a dimension (decision 1).
sealed class DimEnd {
  const DimEnd();

  Map<String, Object?> toJson();

  static DimEnd fromJson(Map<String, Object?> json) {
    if (json['point'] case final List p) {
      return FixedEnd((p[0] as num).toDouble(), (p[1] as num).toDouble());
    }
    return AttachedEnd(Handle.fromJson(json['wall']), json['k']! as int,
        WallSide.values.byName(json['side']! as String));
  }
}

/// A wall end point (decision 4): (wall handle, end k, side). Follows the
/// wall; never moved by the dimension's own group transform (decision 12).
final class AttachedEnd extends DimEnd {
  const AttachedEnd(this.wall, this.k, this.side);
  final Handle wall;
  final int k;
  final WallSide side;

  @override
  Map<String, Object?> toJson() =>
      {'wall': wall.toJson(), 'k': k, 'side': side.name};

  @override
  bool operator ==(Object other) =>
      other is AttachedEnd &&
      other.wall == wall &&
      other.k == k &&
      other.side == side;

  @override
  int get hashCode => Object.hash(wall, k, side);

  @override
  String toString() => '${wall.toHex()}/$k/${side.name}';
}

/// A fixed point in the dimension group's local space: moves and rotates
/// with the group (decision 12).
final class FixedEnd extends DimEnd {
  const FixedEnd(this.x, this.y);
  final double x, y;

  Vector2 get point => Vector2(x, y);

  @override
  Map<String, Object?> toJson() => {
        'point': [x, y]
      };

  @override
  bool operator ==(Object other) =>
      other is FixedEnd && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// A dimension's parameters, in its group's local space (Q4's proposal):
///
/// - [a], [b]: the two ends;
/// - [kind]: aligned, or linear along the group's local x (horizontal) or
///   local y (vertical);
/// - [offset]: local mm, signed, from the outermost measured point on the
///   line's side along the measuring direction's left normal
///   ([layoutDimension]).
final class DimensionParams implements Component {
  const DimensionParams(this.a, this.b, this.kind, this.offset);

  static const String componentTypeId = 'floor_planner.dimension';

  final DimEnd a, b;
  final DimKind kind;
  final double offset;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'a': a.toJson(),
        'b': b.toJson(),
        'kind': kind.name,
        'offset': offset,
      };

  static DimensionParams fromJson(Map<String, Object?> json) => DimensionParams(
      DimEnd.fromJson(json['a']! as Map<String, Object?>),
      DimEnd.fromJson(json['b']! as Map<String, Object?>),
      DimKind.values.byName(json['kind']! as String),
      (json['offset']! as num).toDouble());

  DimensionParams copyWith(
          {DimEnd? a, DimEnd? b, DimKind? kind, double? offset}) =>
      DimensionParams(
          a ?? this.a, b ?? this.b, kind ?? this.kind, offset ?? this.offset);

  @override
  bool operator ==(Object other) =>
      other is DimensionParams &&
      other.a == a &&
      other.b == b &&
      other.kind == kind &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(a, b, kind, offset);

  @override
  String toString() => 'DimensionParams($a -> $b, ${kind.name}, $offset)';
}

/// The page a dimension reads with no page on the root: 1:50 in metres.
final PageComponent _defaultPage = PageComponent();

/// Q2's option (b), switched on by the drift test only: the dimension also
/// reads by place, with a read box around its stored children.
@visibleForTesting
bool debugDimensionReadsPlaces = false;

/// Option (b)'s read margin, mm: [kDimExtGapPaperMm] at 1:1000.
const double kDimReadMargin = kDimExtGapPaperMm * 1000;

/// Every [DimensionType.generate] call, summed.
@visibleForTesting
int debugDimensionGenerates = 0;

/// The world point of [end] of dimension [self] in [view], or null when an
/// attached end's wall is not a live wall.
Vector2? endPointInView(ParametricView view, Handle self, DimEnd end) {
  switch (end) {
    case FixedEnd():
      return view.toWorld(self).transformPoint(end.point);
    case AttachedEnd(:final wall, :final k, :final side):
      final w = wallsInView(view, wall);
      if (w == null) return null;
      return wallEndPoint(w.host, w.walls, k, side);
  }
}

/// The dimension's lines and text colour: ByLayer (layer 0's ACI 7, the
/// paper's foreground). Lineweight 0.30 mm: at 0.18 mm (0.68 logical px at
/// `kLogicalPixelsPerMm`) the vertices sink draws a one-pixel quad, and an
/// exactly axis-aligned one falling between pixel centres paints nothing in
/// the test rasteriser (the 10 spike's finding 4, seen again here: Q6's
/// first renders lost every horizontal dimension line at 0.2 px/mm). Wider
/// than one pixel always covers a row of pixel centres.
const int kDimLineweight = 30;

/// Bottom-centre: the text sits above the dimension line (decision 8).
final int kDimTextAttrs =
    packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.bottom);

/// The dimension (spike): no reach, references its attached walls (policy
/// cascade, decision 3), reads the page's unit and scale.
final class DimensionType extends ParametricType<DimensionParams> {
  const DimensionType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(DimensionParams params, Transform2 toWorld) => Aabb2.empty();

  @override
  Iterable<Handle> references(DimensionParams params) => {
        if (params.a case AttachedEnd(:final wall)) wall,
        if (params.b case AttachedEnd(:final wall)) wall,
      };

  @override
  Object? pageKey(PageComponent? page) {
    final p = page ?? _defaultPage;
    return (p.displayUnit, p.scaleDenominator);
  }

  @override
  bool get readsPlaces => debugDimensionReadsPlaces;

  /// The stored children's box grown by [kDimReadMargin]: an extension
  /// line starts within the gap (1.5 paper mm × the scale) of its measured
  /// point. `readBox` cannot read the page, so the margin assumes a scale no
  /// coarser than 1:1000.
  @override
  Aabb2 readBox(DimensionParams params, Transform2 toWorld, Aabb2 stored) =>
      stored.expandedBy(kDimReadMargin);

  /// In this order, fixed for the object's life: the dimension line, the
  /// two extension lines, the two slashes, the value.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    debugDimensionGenerates++;
    final p = view.paramsOf<DimensionParams>(self)!;
    final p0 = endPointInView(view, self, p.a);
    final p1 = endPointInView(view, self, p.b);
    if (p0 == null || p1 == null) return const [];
    final toWorld = view.toWorld(self);
    final toLocal = toWorld.invert();
    final scale = toWorld.scaleMagnitude;
    final axis = toWorld.transformDirection(
        p.kind == DimKind.vertical ? Vector2(0, 1) : Vector2(1, 0));
    final page = view.page ?? _defaultPage;
    final l = layoutDimension(
        p0, p1, p.kind, axis, p.offset * scale, page.scaleDenominator);
    // Local points relative to p0, as the room does with its seed.
    final base = toLocal.transformPoint(p0);
    Vector2 local(Vector2 w) => base + toLocal.transformDirection(w - p0);
    Generated line((Vector2, Vector2) s) =>
        Generated(EntityKind.line, linePayload(local(s.$1), local(s.$2)),
            lineweight: kDimLineweight);
    final groupAngle = math.atan2(toWorld.b, toWorld.a);
    final t = local(l.textAt);
    return [
      line((l.q0, l.q1)),
      line(l.ext0),
      line(l.ext1),
      line(l.slash0),
      line(l.slash1),
      Generated.text(
          GeometryPayload(
              coords: Float64List.fromList([t.x, t.y]),
              scalars: Float64List.fromList([
                l.textHeight / scale,
                l.textAngle - groupAngle + 0.0,
                1,
                0
              ])),
          formatDimension(l.value, page.displayUnit),
          textAttrs: kDimTextAttrs),
    ];
  }
}

// ---------------------------------------------------------------------------
// Q3: which wall end point a snapped point is.

/// A snapped point within this many mm of a wall end point is that point.
/// The snap reports the stored local ring mapped back to world, the corner
/// is computed in world: the two differ by rounding only (Q3 measures it).
const double kAttachTolerance = 1e-5;

/// Every wall end point of [candidates] within [tol] of [q], each wall's
/// point computed among [all] (its joint context), nearest first.
List<(AttachedEnd, double)> attachMatches(
    Vector2 q, List<WorldWall> candidates, List<WorldWall> all,
    {double tol = kAttachTolerance}) {
  final out = <(AttachedEnd, double)>[];
  for (final w in candidates) {
    final others = [
      for (final o in all)
        if (o.handle != w.handle) o,
    ];
    for (final (k, side, p) in wallEndPoints(w, others)) {
      final d = (p - q).length;
      if (d <= tol) out.add((AttachedEnd(w.handle, k, side), d));
    }
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

/// The end a Dimension tool click at snapped [q] stores (decision 9): the
/// wall end point [attachMatches] finds, chosen by a fixed rule so the
/// choice does not depend on which coincident entity the snap reported: a
/// face point before a centre point, then the lowest wall handle, then the
/// lower k, then left before right. Null: the end is fixed.
AttachedEnd? attachAt(
    Vector2 q, List<WorldWall> candidates, List<WorldWall> all,
    {double tol = kAttachTolerance}) {
  final m = attachMatches(q, candidates, all, tol: tol);
  if (m.isEmpty) return null;
  int rank(AttachedEnd e) => e.side == WallSide.centre ? 1 : 0;
  final ends = [for (final (e, _) in m) e]..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final h = a.wall.value.compareTo(b.wall.value);
      if (h != 0) return h;
      final k = a.k.compareTo(b.k);
      if (k != 0) return k;
      return a.side.index.compareTo(b.side.index);
    });
  return ends.first;
}
