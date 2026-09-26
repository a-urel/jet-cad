// SPIKE 10 -- throwaway. The room (Q5): a parametric object that stores a
// seed, the bounding walls and separators it found at click, its islands
// and a name, and regenerates a translucent tint and a two-line label from
// the ring the tracer finds among them.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room_label.dart';
import 'room_trace.dart';
import 'separator.dart';
import 'wall.dart';
import 'wall_geometry.dart';

/// The tint's colour, and its transparency (0..255, 255 invisible): about
/// 25% opaque.
const DraftColor kRoomTint = TrueColor(0x3D85C6);
const int kRoomTintTransparency = 191;

/// Paper heights of the two label lines (decision 7), mm.
const double kRoomNamePaperMm = 2.5;
const double kRoomAreaPaperMm = 2.0;

final class RoomParams implements Component {
  const RoomParams(this.sx, this.sy, this.bounds, this.islands, this.name);

  static const String componentTypeId = 'floor_planner.room';

  /// The seed, in the room group's local space.
  final double sx, sy;

  /// The walls and separators whose edges bounded the ring at click,
  /// ascending.
  final List<Handle> bounds;

  /// The walls whose outlines were holes at click, ascending.
  final List<Handle> islands;

  final String name;

  Vector2 get seed => Vector2(sx, sy);

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'seed': [sx, sy],
        'bounds': [for (final h in bounds) h.toJson()],
        'islands': [for (final h in islands) h.toJson()],
        'name': name,
      };

  static RoomParams fromJson(Map<String, Object?> json) {
    final s = json['seed']! as List;
    return RoomParams(
      (s[0] as num).toDouble(),
      (s[1] as num).toDouble(),
      [for (final h in json['bounds']! as List) Handle.fromJson(h)],
      [for (final h in json['islands']! as List) Handle.fromJson(h)],
      json['name']! as String,
    );
  }

  RoomParams copyWith(
          {Vector2? seed,
          List<Handle>? bounds,
          List<Handle>? islands,
          String? name}) =>
      RoomParams(seed?.x ?? sx, seed?.y ?? sy, bounds ?? this.bounds,
          islands ?? this.islands, name ?? this.name);

  @override
  bool operator ==(Object other) =>
      other is RoomParams &&
      other.sx == sx &&
      other.sy == sy &&
      listEquals(other.bounds, bounds) &&
      listEquals(other.islands, islands) &&
      other.name == name;

  @override
  int get hashCode => Object.hash(
      sx, sy, Object.hashAll(bounds), Object.hashAll(islands), name);
}

/// Which objects a rebuild traces among (Q3).
enum RoomTraceSet {
  /// The referenced walls and separators only; each wall's outline is still
  /// computed among all of its wall neighbours (07's joints).
  refs,

  /// Decision 1 as written: the referenced objects and their neighbours.
  refsAndNeighbours,
}

/// SPIKE switch for Q3's experiment. The spike's rule is [RoomTraceSet.refs].
RoomTraceSet roomTraceSet = RoomTraceSet.refs;

/// [h]'s boundary input in world, or null when [h] is neither a wall nor a
/// separator (or is degenerate). A wall gives 07's **uncut** outline among
/// its wall neighbours; never its stored rings or 08's pieces.
TraceInput? traceInputOf(ParametricView view, Handle h) {
  final w = view.paramsOf<WallParams>(h);
  if (w != null) {
    final self = WorldWall(h, w, view.toWorld(h));
    final others = [
      for (final n in view.neighbours(h))
        if (view.paramsOf<WallParams>(n) case final p?)
          WorldWall(n, p, view.toWorld(n)),
    ];
    final ring = outline(self, others).ring;
    return ring.isEmpty ? null : TraceInput(h, ring, closed: true);
  }
  final s = view.paramsOf<SeparatorParams>(h);
  if (s != null) {
    final t = view.toWorld(h);
    return TraceInput(h, [t.transformPoint(s.start), t.transformPoint(s.end)],
        closed: false);
  }
  return null;
}

/// Every wall's and separator's boundary input in [doc], from the stored
/// parameters (the Room tool's click and Q3's all-walls oracle).
List<TraceInput> documentInputs(DraftDocument doc) {
  final walls = [
    for (final h in doc.components.withComponent<WallParams>())
      WorldWall(h, doc.components.get<WallParams>(h)!,
          doc.tree.accumulatedTransform(h)),
  ];
  return [
    for (final w in walls)
      if (outline(w, [
        for (final o in walls)
          if (o.handle != w.handle) o
      ]).ring
          case final ring when ring.isNotEmpty)
        TraceInput(w.handle, ring, closed: true),
    for (final h in doc.components.withComponent<SeparatorParams>())
      () {
        final s = doc.components.get<SeparatorParams>(h)!;
        final t = doc.tree.accumulatedTransform(h);
        return TraceInput(
            h, [t.transformPoint(s.start), t.transformPoint(s.end)],
            closed: false);
      }(),
  ];
}

/// What a room's rebuild decided.
sealed class RoomVerdict {
  const RoomVerdict();
}

final class RoomOk extends RoomVerdict {
  const RoomOk(this.trace);
  final Traced trace;
}

/// The ring broke (decision 10): the room is deleted in the same edit.
final class RoomBroken extends RoomVerdict {
  const RoomBroken(this.why);
  final String why;

  @override
  String toString() => 'RoomBroken($why)';
}

final Expando<Map<Handle, RoomVerdict>> _verdicts = Expando('roomVerdict');

/// [self]'s verdict, once per view (its `dissolves` and its `generate`
/// share it). The spike's "ring breaks" rule (Q3):
///
/// 1. a bounding reference that is not a live wall or separator: broken
///    (the cascade normally deleted the room already);
/// 2. trace from the seed among [roomTraceSet]'s objects: the seed in a
///    wall or on a separator, or no bounded face: broken;
/// 3. an edge of the face from an object that is neither a bound nor an
///    island (only possible with neighbours in the set): broken;
/// 4. a bound that carries no edge of the outer ring: broken.
RoomVerdict roomVerdictOf(ParametricView view, Handle self) {
  final memo = _verdicts[view] ??= {};
  return memo[self] ??= debugVerdicts[self] = _verdict(view, self);
}

/// SPIKE: the last verdict computed for each room, for tests.
final Map<Handle, RoomVerdict> debugVerdicts = {};

RoomVerdict _verdict(ParametricView view, Handle self) {
  final p = view.paramsOf<RoomParams>(self)!;
  bool live(Handle h) =>
      view.paramsOf<WallParams>(h) != null ||
      view.paramsOf<SeparatorParams>(h) != null;
  for (final b in p.bounds) {
    if (!live(b)) return RoomBroken('bound ${b.toHex()} is gone');
  }
  final set = <Handle>{
    ...p.bounds,
    for (final i in p.islands)
      if (live(i)) i,
    if (roomTraceSet == RoomTraceSet.refsAndNeighbours)
      for (final b in p.bounds)
        for (final n in view.neighbours(b))
          if (live(n)) n,
  }.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  final inputs = [
    for (final h in set)
      if (traceInputOf(view, h) case final i?) i,
  ];
  final seed = view.toWorld(self).transformPoint(p.seed);
  final r = traceRoom(seed, inputs);
  switch (r) {
    case SeedInWall(:final source):
      return RoomBroken('the seed is in ${source.toHex()}');
    case Unbounded():
      return const RoomBroken('the face is unbounded');
    case Traced():
      final allowed = {...p.bounds, ...p.islands};
      final used = {...r.outerSources, ...r.holeSourceSet};
      for (final u in used) {
        if (!allowed.contains(u)) {
          return RoomBroken('${u.toHex()} now bounds the room');
        }
      }
      final outer = r.outerSources;
      for (final b in p.bounds) {
        if (!outer.contains(b)) {
          return RoomBroken('${b.toHex()} no longer bounds the room');
        }
      }
      return RoomOk(r);
  }
}

/// The area as the page shows it (decision 6): m² for mm, cm and m, ft² for
/// in and ft-in, two decimals.
String formatArea(double mm2, DisplayUnit unit) => switch (unit) {
      DisplayUnit.inches ||
      DisplayUnit.feetInches =>
        '${(mm2 / (304.8 * 304.8)).toStringAsFixed(2)} ft²',
      _ => '${(mm2 / 1e6).toStringAsFixed(2)} m²',
    };

bool _properlyCross(Vector2 a, Vector2 b, Vector2 c, Vector2 d) {
  double cr(Vector2 o, Vector2 p, Vector2 q) =>
      (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x);
  final d1 = cr(c, d, a), d2 = cr(c, d, b), d3 = cr(a, b, c), d4 = cr(a, b, d);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

/// The width of the tint's slit to each hole, mm.
const double kSlit = 0.5;

/// One ring holding [ring] minus [holes] for the tint: each hole joined to
/// the outer ring by a bridge from its rightmost vertex H to the nearest
/// visible outer vertex V (earcut's keyhole). The engine's triangulator
/// refuses a keyhole whose bridge is two coincident edges (Q5), so the
/// return edge is moved [slit] mm to the bridge's right: a slit of that
/// width, outside the tint. Holes that find no bridge are left out (the
/// tint covers them).
List<Vector2> keyhole(List<Vector2> ring, List<List<Vector2>> holes,
    {double slit = kSlit}) {
  var poly = [...ring];
  double maxX(List<Vector2> r) => r.map((p) => p.x).reduce(math.max);
  final hs = [...holes]..sort((a, b) => maxX(b).compareTo(maxX(a)));
  for (var k = 0; k < hs.length; k++) {
    final hole = hs[k].reversed.toList(); // clockwise inside the ring
    var hi = 0;
    for (var i = 1; i < hole.length; i++) {
      if (hole[i].x > hole[hi].x) hi = i;
    }
    final h = hole[hi];
    final order = List<int>.generate(poly.length, (i) => i)
      ..sort((a, b) => (poly[a] - h).length2.compareTo((poly[b] - h).length2));
    int? vi;
    for (final i in order) {
      final v = poly[i];
      var ok = true;
      for (final r in [poly, ...hs.sublist(k)]) {
        for (var e = 0; e < r.length && ok; e++) {
          if (_properlyCross(h, v, r[e], r[(e + 1) % r.length])) ok = false;
        }
      }
      if (ok) {
        vi = i;
        break;
      }
    }
    if (vi == null) continue;
    final v = poly[vi];
    final d = (h - v).normalized();
    final right = Vector2(d.y, -d.x) * slit;
    poly = [
      ...poly.sublist(0, vi + 1),
      for (var j = 0; j < hole.length; j++) hole[(hi + j) % hole.length],
      if (slit == 0) ...[h, v] else ...[h + right, v + right],
      ...poly.sublist(vi + 1),
    ];
  }
  return poly;
}

/// The room (decisions 1-13 as the spike reads them).
final class RoomType extends ParametricType<RoomParams> {
  const RoomType();

  @override
  Capability get editCapability => Capability.geometry;

  /// Nobody's neighbour: the room reaches its walls by reference, as an
  /// opening reaches its host.
  @override
  Aabb2 reach(RoomParams params, Transform2 toWorld) => Aabb2.empty();

  @override
  Iterable<Handle> references(RoomParams params) =>
      [...params.bounds, ...params.islands];

  /// Decision 13: bounds cascade, islands are orphaned (the room stays).
  @override
  ReferencePolicy policyFor(RoomParams params, Handle referent) =>
      params.bounds.contains(referent)
          ? ReferencePolicy.cascade
          : ReferencePolicy.orphan;

  @override
  bool dissolves(ParametricView view, Handle self) =>
      roomVerdictOf(view, self) is RoomBroken;

  @override
  bool get readsPage => true;

  /// The tint (one region: the ring, holes keyholed in), then the name and
  /// the area, centred on the ring's pole of inaccessibility.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final v = roomVerdictOf(view, self);
    if (v is! RoomOk) return const [];
    final p = view.paramsOf<RoomParams>(self)!;
    final tr = v.trace;
    final toLocal = view.toWorld(self).invert();
    List<Vector2> local(List<Vector2> r) =>
        [for (final q in r) toLocal.transformPoint(q)];
    final page = view.page;
    final denom = page?.scaleDenominator ?? 1.0;
    final unit = page?.displayUnit ?? DisplayUnit.meters;
    final nameH = kRoomNamePaperMm * denom, areaH = kRoomAreaPaperMm * denom;
    final pole = poleOfInaccessibility(tr.ring, tr.holes, precision: 10);
    final attrs = packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.middle);
    return [
      Generated.region(
          polylinePayload(local(keyhole(tr.ring, tr.holes)), closed: true),
          color: kRoomTint,
          transparency: kRoomTintTransparency,
          flags: EntityFlags.unpickable,
          // Not drawn: the fill alone is the tint, so the keyhole's slit
          // edges and a separator under the ring's edge stay unstroked.
          boundaryFlags: EntityFlags.unpickable | EntityFlags.invisible),
      Generated.text(
          textPayload(
              toLocal.transformPoint(pole + Vector2(0, 0.7 * nameH)), nameH),
          p.name,
          textAttrs: attrs),
      Generated.text(
          textPayload(
              toLocal.transformPoint(pole - Vector2(0, 0.7 * areaH)), areaH),
          formatArea(tr.area, unit),
          textAttrs: attrs),
    ];
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) => [
        if (roomVerdictOf(view, self) case RoomBroken(:final why))
          Diagnostic(
            severity: DiagnosticSeverity.warning,
            code: 'room.broken',
            message: 'room ${self.toHex()}: $why',
            handles: [self],
          ),
      ];
}

/// The Room tool's click (decision 1): the ring around [seed] among every
/// wall and separator of [doc], or null when there is none. Returns the
/// room's parameters: bounds = the outer ring's sources, islands = the
/// holes' sources.
RoomParams? roomAt(DraftDocument doc, Vector2 seed, String name) {
  final r = traceRoom(seed, documentInputs(doc));
  if (r is! Traced) return null;
  int byValue(Handle a, Handle b) => a.value.compareTo(b.value);
  return RoomParams(
    seed.x,
    seed.y,
    r.outerSources.toList()..sort(byValue),
    r.holeSourceSet.toList()..sort(byValue),
    name,
  );
}

/// The command the Room tool would execute: a root-level group at the
/// identity carrying [params].
DraftCommand addRoom(Handle h, DraftDocument doc, RoomParams params) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [])),
      SetComponentCommand<RoomParams>(h, params),
    ], label: 'Add room');
