import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension.dart';
import 'dimension_attach.dart';
import 'opening_geometry.dart' show wallsInDocument;
import 'wall.dart' show wallJoin;

/// The page a dimension reads when the root carries none (spec 11 D3): the
/// one `generate` reads.
final PageComponent _defaultPage = PageComponent();

/// A dimension as it stands: its parameters, its group's local-to-world
/// transform, its two measured world points and its layout.
typedef _Dim = ({
  DimensionParams params,
  Transform2 m,
  Vector2 p0,
  Vector2 p1,
  DimLayout layout,
});

/// A dimension's grips (spec 11 D13), through the render layer's object
/// grip seam. Every coordinate is world, and every grip is a `stretch` grip,
/// so it is hit and dragged only while `components` and `geometry` are
/// allowed (07 `OG5`). The ordinals (R-26):
///
/// 0. **the offset grip**, at the dimension line's midpoint `(Q0 + Q1) / 2`:
///    a drop stores [offsetFor] of the drop with the dimension's **current**
///    kind, which the grip never changes; null when the new offset
///    `compareTo`s equal to the stored one;
/// 1. **the end grip at `a`**, at `P0`; 2. **the end grip at `b`**, at `P1`:
///    a drop makes the dropped end D10's choice at the drop, and only that
///    end (decision 22): the attach candidates gathered afresh against the
///    document as it is then ([attachCandidates], by position while F3 is
///    on, decision 23; the plan's Ruling 11-8: no memo), decided by
///    [decideEnd] with the current kind and the other end's current world
///    point, or a [FixedEnd] at the drop in the group's local space when
///    nothing attaches (F3 off, or no wall end point there). So an end
///    attaches, detaches or moves to another wall end point (decision 11).
///    The other end keeps its stored reference, and the offset is kept.
///    Null when the new end equals the stored one, or when the result is
///    degenerate: the two ends' points within `wallJoin.linear`, or the new
///    end equal to the other end.
///
/// Each `drag` receives the point the select tool already resolved through
/// its snap chain (08's Ruling 08-15) and returns one
/// `SetComponentCommand<DimensionParams>`: one undo step, in which the
/// dimension regenerates.
///
/// **Preview:** the would-be five lines (the dimension line, the extension
/// lines at `a` and `b`, the slashes at `a` and `b`), in world, from
/// [layoutDimension] with the would-be parameters (the plan's Ruling 11-3),
/// computed once per pointer move; nothing when the drop would be refused as
/// degenerate or cannot be laid out. **No attach ring** (R-34): a preview is
/// world geometry and knows no camera; the select tool's snap marker shows
/// where the drop resolves.
///
/// **A broken dimension** (D15: an end that does not resolve, an offset that
/// is not finite, or a layout that is not finite) has no grips.
///
/// **Movable:** the select tool moves and rotates a dimension like a box
/// (D11, R-19): a fixed end moves with its group, an attached end stays on
/// its wall.
final class DimensionGrips implements ObjectGripProvider {
  DimensionGrips({required this.index, required this.objectSnap});

  /// The shell's spatial index, which [attachCandidates] queries.
  final SpatialIndex index;

  /// Whether object snap (F3) is on, read at each drag event: with it off
  /// nothing attaches (decision 4).
  final bool Function() objectSnap;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    final s = _stateOf(d, group);
    if (s == null) return const [];
    final mid = (s.layout.q0 + s.layout.q1) * 0.5;
    return [
      Grip(GripRole.stretch, 0, mid.x, mid.y),
      Grip(GripRole.stretch, 1, s.p0.x, s.p0.y),
      Grip(GripRole.stretch, 2, s.p1.x, s.p1.y),
    ];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final s = _stateOf(d, group);
    if (s == null) return null;
    final next = _dropped(d, s, grip.index, world);
    if (next == null || next.params == s.params) return null;
    return SetComponentCommand<DimensionParams>(group, next.params);
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final s = _stateOf(d, group);
    if (s == null) return const [];
    final next = _dropped(d, s, grip.index, world);
    if (next == null) return const [];
    final p = next.params;
    final l =
        layoutDimension(next.p0, next.p1, p.kind, s.m, p.offset, _pageOf(d));
    if (l == null) return const [];
    return [
      for (final (a, b) in [(l.q0, l.q1), l.ext0, l.ext1, l.slash0, l.slash1])
        (EntityKind.line, linePayload(a, b)),
    ];
  }

  @override
  bool movable(DraftDocument d, Handle group) => true;

  /// The page [d]'s dimensions read, from the root, as `generate`'s view
  /// reads it.
  static PageComponent _pageOf(DraftDocument d) =>
      d.components.get<PageComponent>(d.rootHandle) ?? _defaultPage;

  /// Dimension [group] as it stands; null when it is not a dimension or is
  /// broken (D15): an end that does not resolve, an offset that is not
  /// finite, or a layout that is not finite.
  static _Dim? _stateOf(DraftDocument d, Handle group) {
    final p = d.components.get<DimensionParams>(group);
    if (p == null || !p.offset.isFinite) return null;
    final m = d.tree.accumulatedTransform(group);
    final p0 = _pointOf(d, m, p.a), p1 = _pointOf(d, m, p.b);
    if (p0 == null || p1 == null) return null;
    final l = layoutDimension(p0, p1, p.kind, m, p.offset, _pageOf(d));
    if (l == null) return null;
    return (params: p, m: m, p0: p0, p1: p1, layout: l);
  }

  /// The world point of [end] in a dimension group whose local-to-world
  /// transform is [m], through the document (08's document adapter), or
  /// null when it is broken (D7): an attached end whose wall is not a live
  /// wall or whose `k` is outside {0, 1}, a fixed end with a coordinate that
  /// is not finite. The layout guards the rest.
  static Vector2? _pointOf(DraftDocument d, Transform2 m, DimEnd end) {
    switch (end) {
      case FixedEnd(:final x, :final y):
        if (!x.isFinite || !y.isFinite) return null;
        return m.transformPoint(end.point);
      case AttachedEnd(:final wall, :final k, :final side):
        if (k != 0 && k != 1) return null;
        final ws = wallsInDocument(d, wall);
        if (ws == null) return null;
        return wallEndPoint(ws.host, ws.walls, k, side);
    }
  }

  /// The dimension [s] with grip [ordinal] dropped at world point [q]: the
  /// parameters it would store and their two measured world points; null
  /// when the drop is refused as degenerate (an end grip only).
  ({DimensionParams params, Vector2 p0, Vector2 p1})? _dropped(
      DraftDocument d, _Dim s, int ordinal, Vector2 q) {
    final p = s.params;
    if (ordinal == 0) {
      // The current kind; the grip never changes it (R-26).
      final o = offsetFor(q, s.p0, s.p1, p.kind, s.m);
      return (params: p.copyWith(offset: o), p0: s.p0, p1: s.p1);
    }
    final atA = ordinal == 1;
    final other = atA ? p.b : p.a;
    final otherW = atA ? s.p1 : s.p0;
    // Decision 22: the dropped end only, at the drop, with the current kind
    // and the other end's current point, from candidates gathered now.
    final candidates = attachCandidates(d, index, q,
        objectSnap: objectSnap(), thickest: thickestWall(d));
    final DimEnd end =
        decideEnd(d, candidates, kind: p.kind, at: q, other: otherW, m: s.m) ??
            _fixedAt(s.m, q);
    if (end == other) return null;
    final w = _pointOf(d, s.m, end);
    if (w == null || (w - otherW).length <= wallJoin.linear) return null;
    return atA
        ? (params: p.copyWith(a: end), p0: w, p1: s.p1)
        : (params: p.copyWith(b: end), p0: s.p0, p1: w);
  }

  /// World point [q] as a fixed end: in the group's local space (R-1).
  static FixedEnd _fixedAt(Transform2 m, Vector2 q) {
    final l = m.invert().transformPoint(q);
    return FixedEnd(l.x, l.y);
  }
}
