// The dimension (spec 11 D2, D3, D7, D8): a parametric object that stores
// two ends (each a wall end point it follows or a fixed point), a kind
// (aligned, horizontal, vertical) and a signed offset, and regenerates a
// dimension line, two extension lines, two slashes and its value. Its pure
// geometry lives in `dimension_geometry.dart`, which this file re-exports
// (the plan's Ruling 11-2), so callers import one file.
//
// Ported from the spike (`spike/11-dimensions`,
// `apps/floor_planner/lib/parametric/dimension.dart`), with the offset
// compared by `compareTo` (D2), the extension lines flagged not pickable
// (D19), the broken ends generating nothing (D7), and without the spike's
// place reading (D5).
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension_geometry.dart';
import 'opening_geometry.dart' show wallsInView;
import 'wall.dart' show WallParams, wallJoin;

export 'dimension_geometry.dart';

/// A dimension's parameters (spec 11 D2), in its group's local space:
///
/// - [a], [b]: the two ends, each an [AttachedEnd] (a wall end point it
///   follows) or a [FixedEnd] (a point in the group's local space);
/// - [kind]: aligned, or linear along the group's local x (horizontal) or
///   local y (vertical) (decision 17);
/// - [offset]: a signed model length in the group's local units, from the
///   outermost measured point on the line's side (D6). Its side is its sign
///   bit (R-2): `+0.0` and every positive value lie on the measuring
///   direction's left normal, `-0.0` and every negative value on its right.
///
/// `fromJson` accepts anything well-typed (R-3): a `k` outside {0, 1}, a
/// non-finite fixed coordinate or a non-finite offset are kept, reported
/// `dimension.broken` (D15), and generate nothing (D7).
final class DimensionParams implements Component {
  const DimensionParams(this.a, this.b, this.kind, this.offset);

  static const String componentTypeId = 'floor_planner.dimension';

  final DimEnd a, b;
  final DimKind kind;
  final double offset;

  @override
  String get typeId => componentTypeId;

  /// Every key, in this order: `a`, `b`, `kind` (by name), `offset`. A
  /// `-0.0` offset is written `-0.0` and read back as `-0.0` (D2).
  @override
  Map<String, Object?> toJson() => {
        'a': a.toJson(),
        'b': b.toJson(),
        'kind': kind.name,
        'offset': offset,
      };

  /// Throws on a missing key, an end of neither shape, or an unknown kind or
  /// side name.
  static DimensionParams fromJson(Map<String, Object?> json) => DimensionParams(
      DimEnd.fromJson(json['a']! as Map<String, Object?>),
      DimEnd.fromJson(json['b']! as Map<String, Object?>),
      DimKind.values.byName(json['kind']! as String),
      (json['offset']! as num).toDouble());

  DimensionParams copyWith(
          {DimEnd? a, DimEnd? b, DimKind? kind, double? offset}) =>
      DimensionParams(
          a ?? this.a, b ?? this.b, kind ?? this.kind, offset ?? this.offset);

  /// Value-equal, exactly (stored values, CLAUDE.md), but not uniformly:
  ///
  /// - the ends and the kind with `==`, so a [FixedEnd]'s coordinates are
  ///   compared with double `==`: `-0.0` and `0.0` are the same coordinate,
  ///   and a NaN coordinate equals nothing;
  /// - the offset with `compareTo(other.offset) == 0` (D2, R-2), because its
  ///   sign bit is its side: `-0.0` differs from `+0.0` (where `-0.0 == 0.0`
  ///   is true in Dart), and a NaN offset equals itself.
  @override
  bool operator ==(Object other) =>
      other is DimensionParams &&
      other.a == a &&
      other.b == b &&
      other.kind == kind &&
      other.offset.compareTo(offset) == 0;

  /// Consistent with `==`: every NaN offset hashes as `double.nan` does
  /// (NaNs of other bit patterns hash differently in the VM, yet compare
  /// equal); the two zeros may collide.
  @override
  int get hashCode =>
      Object.hash(a, b, kind, offset.isNaN ? double.nan : offset);

  @override
  String toString() => 'DimensionParams($a -> $b, ${kind.name}, $offset)';
}

/// The page a dimension reads when the root carries none (spec 11 D3): the
/// app's opening page, 1:50 in metres, as 10's room.
final PageComponent _defaultPage = PageComponent();

/// Every [DimensionType.generate] call, summed (spec 11 D3). Never reset by
/// the library.
@visibleForTesting
int debugDimensionGenerates = 0;

/// The world point of [end] of dimension [self] in [view] (spec 11 D6), or
/// null when the end is broken (D7): an attached end whose wall is not a
/// live wall or whose `k` is outside {0, 1}, or a fixed end with a
/// non-finite coordinate.
Vector2? endPointInView(ParametricView view, Handle self, DimEnd end) {
  switch (end) {
    case FixedEnd(:final x, :final y):
      if (!x.isFinite || !y.isFinite) return null;
      return view.toWorld(self).transformPoint(end.point);
    case AttachedEnd(:final wall, :final k, :final side):
      if (k != 0 && k != 1) return null;
      final w = wallsInView(view, wall);
      if (w == null) return null;
      return wallEndPoint(w.host, w.walls, k, side);
  }
}

/// The dimension (spec 11 D3, D7).
///
/// - [reach] is `Aabb2.empty()`: a dimension is nobody's neighbour and has
///   none; it reaches its walls by reference.
/// - [references] are its attached ends' walls, in `a`, `b` order,
///   deduplicated, with the default policy, `cascade`: deleting a measured
///   wall deletes the dimension in the same edit (decision 3).
/// - [pageKey]: the page's unit and scale, which its text reads.
/// - [diagnose]: D15's `dimension.broken` and `dimension.degenerate`.
final class DimensionType extends ParametricType<DimensionParams> {
  const DimensionType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(DimensionParams params, Transform2 toWorld) => Aabb2.empty();

  /// A field read (called once per live object per survey): zero, one or
  /// two handles, in insertion order, deduplicated by the set.
  @override
  Iterable<Handle> references(DimensionParams params) => {
        if (params.a case AttachedEnd(:final wall)) wall,
        if (params.b case AttachedEnd(:final wall)) wall,
      };

  /// The record `(unit, scaleDenominator)` of [page], or of
  /// `PageComponent()`'s defaults when it is null (spec 11 D3): what
  /// [generate] reads of the page, and nothing else, so a paper colour or a
  /// grid change regenerates no dimension.
  @override
  Object? pageKey(PageComponent? page) {
    final p = page ?? _defaultPage;
    return (p.displayUnit, p.scaleDenominator);
  }

  /// Six children, in this order, fixed for the object's life (spec 11 D7,
  /// R-9): the dimension line, the extension lines at `a` and `b`, the
  /// slashes at `a` and `b`, the value. The five LINEs are ByLayer at
  /// [kDimLineweight]; the two extension lines carry
  /// `EntityFlags.unpickable` (D19); the TEXT is [kDimTextAttrs]. A zero
  /// dimension still generates all six.
  ///
  /// The layout is [layoutDimension]'s, in world; each world point `w` is
  /// stored as `toLocal(P0) + toLocal.transformDirection(w − P0)`, relative
  /// to the first end's world point `P0` (D7). The TEXT's scalars are
  /// `[height / s, angle − atan2(M.b, M.a) + 0.0, 1, 0]` (D8).
  ///
  /// **Nothing** for a broken dimension (D7, D15): an end [endPointInView]
  /// finds broken, a non-finite offset, or a dimension [layoutDimension]
  /// cannot lay out in finite numbers (its one guard, which every caller
  /// inherits), so no value reaches the format non-finite or too large to
  /// print. [diagnose] reports each of them `dimension.broken`.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    debugDimensionGenerates++;
    final p = view.paramsOf<DimensionParams>(self)!;
    if (!p.offset.isFinite) return const [];
    final p0 = endPointInView(view, self, p.a);
    final p1 = endPointInView(view, self, p.b);
    if (p0 == null || p1 == null) return const [];

    final toWorld = view.toWorld(self);
    final page = view.page ?? _defaultPage;
    final l = layoutDimension(p0, p1, p.kind, toWorld, p.offset, page);
    if (l == null) return const [];

    final toLocal = toWorld.invert();
    final base = toLocal.transformPoint(p0);
    Vector2 local(Vector2 w) => base + toLocal.transformDirection(w - p0);
    Generated line((Vector2, Vector2) s, {int flags = 0}) =>
        Generated(EntityKind.line, linePayload(local(s.$1), local(s.$2)),
            lineweight: kDimLineweight, flags: flags);
    final t = local(l.textAt);
    return [
      line((l.q0, l.q1)),
      line(l.ext0, flags: EntityFlags.unpickable),
      line(l.ext1, flags: EntityFlags.unpickable),
      line(l.slash0),
      line(l.slash1),
      Generated.text(
          GeometryPayload(
              coords: Float64List.fromList([t.x, t.y]),
              scalars: Float64List.fromList([
                l.textHeight / toWorld.scaleMagnitude,
                l.textAngle - math.atan2(toWorld.b, toWorld.a) + 0.0,
                1,
                0,
              ])),
          l.text,
          textAttrs: kDimTextAttrs),
    ];
  }

  /// Spec 11 D15, each code at most once per dimension. A dimension either
  /// draws its six children or is broken (D7); it is never silently empty.
  ///
  /// - **`dimension.broken`**, an error, when an attached end names a live
  ///   object that is not a wall, or has a `k` outside {0, 1}, or a fixed
  ///   end has a coordinate that is not finite, or the offset is not finite,
  ///   or both ends resolve and [layoutDimension] cannot lay the dimension
  ///   out ("it cannot be laid out in finite numbers": an aligned pair whose
  ///   distance overflows, a value above [kDimMaxValueMm], an attached wall's
  ///   non-finite end point, or a page so large that a paper length
  ///   overflows). The layout is tried with a zero offset when the offset is
  ///   not finite, so that reason is never the offset's. [generate] makes
  ///   nothing for a broken dimension (D7). One diagnostic names every
  ///   reason, in the order `a`, `b`, the offset, the layout. A broken
  ///   dimension is never also `dimension.degenerate`.
  /// - **`dimension.degenerate`**, a warning, when D6's value is ≤
  ///   `wallJoin.linear` (R-29): the two points coincide for aligned, or the
  ///   component is zero for a linear kind. It still draws (D7). The value
  ///   is [layoutDimension]'s, the one layout (Ruling 11-3).
  ///
  /// An attached end naming a handle that is not a live object at all is
  /// the engine's `parametric.dangling` (08 D5), and is not repeated here:
  /// such a dimension measures nothing and reports nothing of its own.
  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    final p = view.paramsOf<DimensionParams>(self)!;
    final p0 = endPointInView(view, self, p.a);
    final p1 = endPointInView(view, self, p.b);
    final l = p0 == null || p1 == null
        ? null
        : layoutDimension(p0, p1, p.kind, view.toWorld(self),
            p.offset.isFinite ? p.offset : 0.0, view.page ?? _defaultPage);
    final why = [
      ..._brokenEnd(view, 'a', p.a),
      ..._brokenEnd(view, 'b', p.b),
      if (!p.offset.isFinite) 'the offset is not finite',
      if (p0 != null && p1 != null && l == null)
        'it cannot be laid out in finite numbers',
    ];
    if (why.isNotEmpty) {
      return [
        Diagnostic(
          severity: DiagnosticSeverity.error,
          code: 'dimension.broken',
          message: '${self.toHex()} is broken (${why.join('; ')}): it draws '
              'nothing',
          handles: [self],
        ),
      ];
    }
    if (l == null || l.value > wallJoin.linear) return const [];
    return [
      Diagnostic(
        severity: DiagnosticSeverity.warning,
        code: 'dimension.degenerate',
        message: '${self.toHex()} measures zero',
        handles: [self],
      ),
    ];
  }

  /// Why [end] (named [name]) is broken (D15), or nothing: a dead wall
  /// handle is not broken (it is `parametric.dangling`).
  static List<String> _brokenEnd(ParametricView view, String name, DimEnd end) {
    switch (end) {
      case FixedEnd(:final x, :final y):
        return [
          if (!x.isFinite || !y.isFinite)
            'end $name is a point that is not finite',
        ];
      case AttachedEnd(:final wall, :final k):
        return [
          if (view.paramsOf<Component>(wall) != null &&
              view.paramsOf<WallParams>(wall) == null)
            'end $name names ${wall.toHex()}, which is not a wall',
          if (k != 0 && k != 1) 'end $name has k = $k, not 0 or 1',
        ];
    }
  }
}
