import 'dart:math' as math;
import 'dart:ui' show Canvas;

import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension.dart';
import 'dimension_attach.dart';
import 'wall.dart' show wallJoin;

/// Spec 11 D12: the Dimension tool (I). A `PlacementTool` of **three clicks
/// per dimension** (decision 9), not chained (R-25): after the commit it
/// waits for a new first click, as 10's Separator tool.
///
/// - **Points** resolve through the drawing tools' chain (05 D4,
///   `kDragSnapMask`): object snap (F3), then the grid, else the raw point.
///   The third point too (R-22): only its height along the measuring
///   direction's normal, and for a linear kind its side, is used.
/// - **Shift** (R-20): at the second click, 05's ortho from the first
///   point; at the third, **linear**, with ortho off ([orthoBase] is null
///   once two points are placed). The tool records Shift from the pointer
///   events and the Shift key before `PlacementTool` sees them (S-8), since
///   [accept] does not carry it.
/// - **Click 2** is ignored when the pair is degenerate (R-23): the two
///   points within `wallJoin.linear`, or their attach candidates sharing a
///   wall end point. The tool keeps waiting for the second point.
/// - **Click 3** commits: the kind ([kindFor]), both ends decided **at the
///   commit** (decision 22) from candidates gathered afresh against the
///   document as it is then ([attachCandidates], [decideEnd]; decision 23:
///   by position while F3 is on), a [FixedEnd] where none attaches, and the
///   offset by D6's placement function ([offsetFor]). One
///   [CompoundCommand], the group at the identity and its
///   [DimensionParams]: one undo step, in which the dimension generates. A
///   refused commit places nothing.
/// - **Enter** does nothing while points are pending (R-33: `finish` stays
///   the default no-op); **Esc** and undo are `PlacementTool`'s (05 D3, D5).
class DimensionTool extends PlacementTool {
  DimensionTool();

  /// Whether Shift is held, as the last pointer event or Shift key said.
  bool _shift = false;

  @override
  String get name => 'Dimension';

  /// R-20: 05's ortho at the second click; none once two points are placed,
  /// so the third point's drag side is where the person dragged, not an
  /// ortho-pinned point (M-11ortho3).
  @override
  Vector2? get orthoBase => points.length >= 2 ? null : super.orthoBase;

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    _shift = e.shift;
    super.onPointerMove(e, ctx);
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    _shift = e.shift;
    super.onPointerDown(e, ctx);
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    final key = event.logicalKey;
    if ((key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight) &&
        event is! KeyRepeatEvent) {
      _shift = event is KeyDownEvent;
    }
    return super.onKey(event, ctx);
  }

  /// The kind a third point [q] commits for the pair [p0], [p1] (spec 11
  /// D12, R-21), in world (the tool's group is the identity):
  ///
  /// - without [shift], aligned;
  /// - with it, the side dragged to: `e_x` and `e_y`, how far [q] lies
  ///   outside the two points' x and y spans (0 inside); `e_y > e_x` is
  ///   horizontal (dragged above or below), `e_x > e_y` vertical (dragged
  ///   left or right), and a tie (both 0 inside the span box included)
  ///   horizontal when `|dx| ≥ |dy|`, else vertical;
  /// - a linear kind that would measure ≤ `wallJoin.linear` (a vertical pair
  ///   dragged above) gives way to the other, so a non-degenerate pair never
  ///   makes a zero linear dimension.
  ///
  /// The comparisons are exact: they choose between two valid outcomes from
  /// a pointer position, and a tie has no wrong answer.
  static DimKind kindFor(Vector2 q, Vector2 p0, Vector2 p1,
      {required bool shift}) {
    if (!shift) return DimKind.aligned;
    final ex = _outside(q.x, p0.x, p1.x), ey = _outside(q.y, p0.y, p1.y);
    final dx = (p1.x - p0.x).abs(), dy = (p1.y - p0.y).abs();
    final horizontal = ey > ex || (ey == ex && dx >= dy);
    if (horizontal) {
      return dx <= wallJoin.linear ? DimKind.vertical : DimKind.horizontal;
    }
    return dy <= wallJoin.linear ? DimKind.horizontal : DimKind.vertical;
  }

  /// How far [v] lies outside the span of [a] and [b]; 0 inside.
  static double _outside(double v, double a, double b) {
    final lo = math.min(a, b), hi = math.max(a, b);
    if (v < lo) return lo - v;
    if (v > hi) return v - hi;
    return 0;
  }

  static bool _objectSnap(ToolContext ctx) => ctx.snap?.objectSnap ?? true;

  /// [p]'s attach candidates against [ctx]'s document as it is now: never a
  /// memo (the plan's Ruling 11-8).
  static List<AttachedEnd> _candidatesAt(ToolContext ctx, Vector2 p) =>
      attachCandidates(ctx.document, ctx.index, p,
          objectSnap: _objectSnap(ctx), thickest: thickestWall(ctx.document));

  /// R-23: whether [p1] as the second point makes a dimension of nothing
  /// with [p0]: within `wallJoin.linear` of it, or on a wall end point it
  /// also lies on.
  static bool _degenerate(ToolContext ctx, Vector2 p0, Vector2 p1) {
    if ((p1 - p0).length <= wallJoin.linear) return true;
    final c1 = _candidatesAt(ctx, p1);
    if (c1.isEmpty) return false;
    return _candidatesAt(ctx, p0).any(c1.contains);
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    if (points.length == 1) {
      if (!_degenerate(ctx, points.first, point)) points.add(point);
      return;
    }
    _commit(point, ctx);
    clearShape();
  }

  /// The third click at [q]: spec 11 D12's commit.
  void _commit(Vector2 q, ToolContext ctx) {
    final doc = ctx.document;
    final p0 = points[0], p1 = points[1];
    final kind = kindFor(q, p0, p1, shift: _shift);
    final m = Transform2.identity();
    // Decision 22: both ends at the commit, with the committed kind's
    // measuring direction, from candidates gathered now.
    DimEnd end(Vector2 at, Vector2 other) =>
        decideEnd(doc, _candidatesAt(ctx, at),
            kind: kind, at: at, other: other, m: m) ??
        FixedEnd(at.x, at.y);
    final a = end(p0, p1), b = end(p1, p0);
    final offset = offsetFor(q, p0, p1, kind, m);
    try {
      commit(ctx, () {
        // Allocated inside the build, after the permission check (Ruling
        // 05-3), never predicted.
        final h = doc.handleSeed.next();
        return CompoundCommand([
          AddNodeCommand(GroupNode(
              handle: h,
              parent: doc.rootHandle,
              transform: Transform2.identity(),
              children: const [])),
          SetComponentCommand<DimensionParams>(
              h, DimensionParams(a, b, kind, offset)),
        ], label: 'Add dimension');
      }, needs: const {
        Capability.structure,
        Capability.components,
        Capability.geometry,
      });
    } on ArgumentError {
      // Refused: nothing is placed.
    } on StateError {
      // Likewise.
    } on DanglingReferenceError {
      // An end's wall stopped being an object: nothing is placed.
    }
  }

  /// After the first click, the rubber band from it to the resolved hover
  /// point, as the Line tool draws it (spec 11 D12's preview, R-24); painted
  /// per frame from two stored points.
  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.length != 1 || !hoverVisible) return;
    final p = points.first, h = hoverPoint;
    band
      ..reset()
      ..moveTo(p.x - origin.x, p.y - origin.y)
      ..lineTo(h.x - origin.x, h.y - origin.y);
    canvas.drawPath(band, bandPaint);
  }
}
