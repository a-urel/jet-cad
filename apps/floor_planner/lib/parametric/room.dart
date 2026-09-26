// The room (spec 10 D2, D8-D11, D14-D16, D18): a parametric object that
// stores a seed, a name and an optional label offset, and regenerates a
// translucent tint on the face that holds its seed and two labels, its name
// and its net area, at the face's pole of inaccessibility. The face is
// traced among every live wall and separator by place (D7, D16); the room
// dissolves when its seed ends up in a wall or in an unbounded face (D8,
// D15).
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room_inputs.dart' show placeSourceInView;
import 'room_label.dart';
import 'room_trace.dart';

/// Sentinel for [RoomParams.copyWith]'s nullable [RoomParams.label].
const Object _keep = Object();

/// A room's parameters (spec 10 D2), in the room group's local space, mm.
///
/// - [seedX], [seedY]: the clicked point, stored where clicked and never
///   re-seated;
/// - [name]: the name label's string;
/// - [label]: `null` (auto) or the label anchor's offset from the pole of
///   inaccessibility (D10).
///
/// Value-equal with exact `==` on every field: stored values. Stores no
/// handle. `fromJson` accepts anything well-typed: a non-finite seed traces
/// as `Unbounded` (D8), and a [label] with a non-finite component is
/// treated as `null` by [RoomType.generate].
final class RoomParams implements Component {
  const RoomParams(this.seedX, this.seedY, this.name, {this.label});

  static const String componentTypeId = 'floor_planner.room';

  final double seedX, seedY;
  final String name;
  final (double, double)? label;

  Vector2 get seed => Vector2(seedX, seedY);

  @override
  String get typeId => componentTypeId;

  /// The keys `seed`, `name`, `label`, in that order, **all three always
  /// written** (08 D6's one-shape rule): `label` is `null` when auto.
  @override
  Map<String, Object?> toJson() => {
        'seed': [seedX, seedY],
        'name': name,
        'label': switch (label) {
          (final dx, final dy) => [dx, dy],
          null => null,
        },
      };

  /// Throws on a missing seed or name, or a value of the wrong type.
  static RoomParams fromJson(Map<String, Object?> json) {
    final s = json['seed']! as List;
    final l = json['label'] as List?;
    return RoomParams(
      (s[0] as num).toDouble(),
      (s[1] as num).toDouble(),
      json['name']! as String,
      label: l == null
          ? null
          : ((l[0] as num).toDouble(), (l[1] as num).toDouble()),
    );
  }

  /// [label] takes a `(double, double)` or `null` (auto); left out, it is
  /// kept.
  RoomParams copyWith(
          {double? seedX,
          double? seedY,
          String? name,
          Object? label = _keep}) =>
      RoomParams(seedX ?? this.seedX, seedY ?? this.seedY, name ?? this.name,
          label: identical(label, _keep)
              ? this.label
              : label as (double, double)?);

  @override
  bool operator ==(Object other) =>
      other is RoomParams &&
      other.seedX == seedX &&
      other.seedY == seedY &&
      other.name == name &&
      other.label == label;

  @override
  int get hashCode => Object.hash(seedX, seedY, name, label);

  @override
  String toString() => 'RoomParams(($seedX, $seedY), $name, $label)';
}

/// The tint's colour (spec 10 D9, R-8): ACI 7, the foreground, black on
/// White, Ivory and Grey paper and white on Blueprint, resolved at paint
/// time. Explicit, not ByLayer, so a change to layer 0's colour does not
/// recolour tints.
const DraftColor kRoomTintColor = IndexedColor(7);

/// The tint's transparency (spec 10 D9, decision 28): 229 of 255, alpha 26,
/// about 10%.
const int kRoomTintTransparency = 229;

/// The name label's height on paper, mm (spec 10 D11, decision 7).
const double kRoomNamePaperMm = 2.5;

/// The area label's height on paper, mm (spec 10 D11, decision 7).
const double kRoomAreaPaperMm = 2.0;

/// Each label line sits this many of its own heights above (the name) or
/// below (the area) the anchor, in world directions (spec 10 D10): a gap of
/// `0.2 · (h_name + h_area)` between the two.
const double kRoomLineOffset = 0.7;

/// How far a room's read box reaches past its stored points and its seed,
/// mm (spec 10 D16, R-7): twice D7's certificate margin, so rounding in the
/// local-to-world map of the stored tint cannot put `box(F) ⊕ m` outside
/// it.
const double kRoomReadMargin = 2;

/// Both labels' justification, centre and middle (spec 10 D9, Ruling
/// 10-14): `TextJustifyH.centre`, not DXF's other "middle".
final int kRoomLabelAttrs =
    packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.middle);

/// The page a room reads when the root carries none (spec 10 D11, R-14): the
/// app's opening page, 1:50 in metres.
final PageComponent _defaultPage = PageComponent();

/// Every [RoomType.generate] call, summed (Ruling 10-19): `RK2` prints its
/// delta per edit as "rooms rebuilt". Never reset by the library.
@visibleForTesting
int debugRoomGenerates = 0;

/// Each view's room traces, by handle (spec 10 D15): one trace per room per
/// view, shared by [RoomType.dissolves] and [RoomType.generate].
final Expando<Map<Handle, TraceResult>> _tracesByView =
    Expando('roomTraceInView');

/// [self]'s face in [view] (spec 10 D7): the trace around its seed, taken
/// to world, among the view's contributors. Memoised per view and room.
TraceResult _traceOf(ParametricView view, Handle self) {
  final memo = _tracesByView[view] ??= <Handle, TraceResult>{};
  return memo[self] ??= traceRoomAmong(
      view.toWorld(self).transformPoint(view.paramsOf<RoomParams>(self)!.seed),
      placeSourceInView(view));
}

/// The room (spec 10 D2, D9-D11, D14-D16).
///
/// - [reach] is `Aabb2.empty()` and it names no reference: a room is
///   nobody's neighbour; it reaches its walls and separators by place.
/// - It is a place **reader** ([readsPlaces]): an edit that changes a
///   wall's band or a separator's segment touching its [readBox]
///   regenerates it.
/// - [pageKey]: the page's unit and scale, which its labels read.
/// - [dissolves] when its seed lies in a wall or no bounded face holds it
///   (D8).
///
/// Its `diagnose` is the default, nothing, until D22's codes land (Ruling
/// 10-15).
final class RoomType extends ParametricType<RoomParams> {
  const RoomType();

  /// Geometry (spec 10 D2, R-1): a rename changes a generated label, and the
  /// label grip moves one.
  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(RoomParams params, Transform2 toWorld) => Aabb2.empty();

  @override
  bool get readsPlaces => true;

  /// [stored] (the world box of the tint's and the labels' stored points;
  /// the tint holds every outer-ring vertex, D9) grown to hold the world
  /// seed, then by [kRoomReadMargin] (spec 10 D16, R-7). A non-finite seed
  /// adds nothing: such a room traces `Unbounded` and never lives.
  @override
  Aabb2 readBox(RoomParams params, Transform2 toWorld, Aabb2 stored) {
    final s = toWorld.transformPoint(params.seed);
    final box =
        s.x.isFinite && s.y.isFinite ? stored.expandedToPoint(s) : stored;
    return box.expandedBy(kRoomReadMargin);
  }

  /// The record `(unit, scaleDenominator)` of [page], or of
  /// `PageComponent()`'s defaults when it is null (spec 10 D14, R-14): what
  /// [generate] reads of the page, and nothing else, so a paper colour or a
  /// grid change regenerates no room.
  @override
  Object? pageKey(PageComponent? page) {
    final p = page ?? _defaultPage;
    return (p.displayUnit, p.scaleDenominator);
  }

  /// True for D8's `SeedInWall` and `Unbounded`: the room is deleted in the
  /// same edit (D15).
  @override
  bool dissolves(ParametricView view, Handle self) =>
      _traceOf(view, self) is! Traced;

  /// The tint, then the name, then the area (spec 10 D9), a fixed order, so
  /// the children keep their handles for the room's life (D18) while the
  /// tint keeps its form:
  ///
  /// 1. **the tint**: [tintOf] of the face, in the trace's seed-relative
  ///    frame, taken to the room's local space. Steps 1 and 2 are a region,
  ///    [kRoomTintColor] on both records, [kRoomTintTransparency], its fill
  ///    drawn and its boundary invisible (R-10); step 3 an invisible closed
  ///    POLYLINE of the outer ring, [kRoomTintColor];
  /// 2. **the name**, a TEXT, [RoomParams.name];
  /// 3. **the area**, a TEXT, [formatArea] of the trace's net area in the
  ///    page's unit (D11).
  ///
  /// Both labels ByLayer, `STANDARD`, [kRoomLabelAttrs], flags 0. The anchor
  /// is `toLocal(pole) + label` (`label = (0, 0)` when auto or non-finite),
  /// the pole the face's [poleOfInaccessibility] in world (D10). The name
  /// sits at `anchor_w + (0, 0.7 · h_name)` and the area at `anchor_w −
  /// (0, 0.7 · h_area)`, in world, `h` 2.5 and 2.0 mm × the page's scale;
  /// each TEXT's rotation is minus the group's world rotation and its height
  /// is divided by the group's scale (the geometric mean under a non-uniform
  /// one), so the labels are horizontal and sized on paper.
  ///
  /// Nothing for a room that dissolves: the planner never asks it then.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    debugRoomGenerates++;
    final trace = _traceOf(view, self);
    if (trace is! Traced) return const [];
    final p = view.paramsOf<RoomParams>(self)!;
    final toWorld = view.toWorld(self);
    final toLocal = toWorld.invert();
    final seedW = toWorld.transformPoint(p.seed);

    // The tint, decided in the seed-relative frame, then taken to local
    // space through the seed: `seed_l + toLocal(q)` as a direction.
    List<Vector2> relative(List<Vector2> r) => [for (final q in r) q - seedW];
    Vector2 local(Vector2 q) => p.seed + toLocal.transformDirection(q);
    final ring = relative(trace.ring);
    final tint = tintOf(ring, [for (final h in trace.holes) relative(h)]);
    var step = tint.step;
    var points = [for (final q in tint.points) local(q)];
    // D9's chain is decided in the seed-relative frame; the local points are
    // a similarity of them. Should the map ever cost a region its
    // triangulation, the room takes the chain's next step rather than let
    // the engine refuse the edit (an edit is never refused because of a
    // tint).
    if (step == 1 && !_triangulates(points)) {
      step = 2;
      points = [for (final q in ring) local(q)];
    }
    if (step == 2 && !_triangulates(points)) step = 3;
    final boundary = polylinePayload(points, closed: true);

    // The labels, placed in world.
    final page = view.page ?? _defaultPage;
    final hName = kRoomNamePaperMm * page.scaleDenominator;
    final hArea = kRoomAreaPaperMm * page.scaleDenominator;
    final pole = poleOfInaccessibility(trace.ring, trace.holes).point;
    final anchorW =
        toWorld.transformPoint(toLocal.transformPoint(pole) + _offsetOf(p));
    final scale = toWorld.scaleMagnitude;
    // `+ 0.0` turns the identity's `-0.0` into `0.0`, as `textPayload` has.
    final rotation = -math.atan2(toWorld.b, toWorld.a) + 0.0;
    GeometryPayload label(Vector2 w, double h) {
      final q = toLocal.transformPoint(w);
      return GeometryPayload(
          coords: Float64List.fromList([q.x, q.y]),
          scalars: Float64List.fromList([h / scale, rotation, 1, 0]));
    }

    return [
      if (step == 3)
        Generated(EntityKind.polyline, boundary,
            color: kRoomTintColor, flags: EntityFlags.invisible)
      else
        Generated.region(boundary,
            color: kRoomTintColor,
            transparency: kRoomTintTransparency,
            boundaryFlags: EntityFlags.invisible),
      Generated.text(
          label(anchorW + Vector2(0, kRoomLineOffset * hName), hName), p.name,
          textAttrs: kRoomLabelAttrs),
      Generated.text(
          label(anchorW - Vector2(0, kRoomLineOffset * hArea), hArea),
          formatArea(trace.area, page.displayUnit),
          textAttrs: kRoomLabelAttrs),
    ];
  }
}

/// [p]'s label offset, local: `(0, 0)` when auto or when a component is not
/// finite (spec 10 D2; `room.degenerate` reports the latter, D22).
Vector2 _offsetOf(RoomParams p) => switch (p.label) {
      (final dx, final dy) when dx.isFinite && dy.isFinite => Vector2(dx, dy),
      _ => Vector2.zero(),
    };

/// Whether the closed ring [points] triangulates, as the engine asks of a
/// generated region.
bool _triangulates(List<Vector2> points) =>
    triangulationFor(EntityKind.polyline, polylinePayload(points, closed: true))
        ?.isNotEmpty ??
    false;
