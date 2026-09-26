// Test-only parametric types. RectType duplicates the app's BoxType on
// purpose (Ruling 06-9): a fixture must not share a bug with the code it
// checks.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

abstract class RectParams implements Component {
  double get width;
  double get height;
}

final class ClipRect implements RectParams {
  const ClipRect(this.width, this.height);
  static const String id = 'test.clipRect';
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static ClipRect fromJson(Map<String, Object?> j) => ClipRect(
      (j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is ClipRect && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

/// Same shape, but its parameter edits need only `components` (spec D7).
final class SoftRect implements RectParams {
  const SoftRect(this.width, this.height);
  static const String id = 'test.softRect';
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static SoftRect fromJson(Map<String, Object?> j) => SoftRect(
      (j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is SoftRect && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

enum TripMode { off, throwing, reentrant, throwingReach }

/// A rectangle whose generation can be made to throw, or to call back into
/// the dispatcher (G6-G8).
final class Trip implements RectParams {
  const Trip(this.width, this.height);
  static const String id = 'test.trip';
  static TripMode mode = TripMode.off;
  static DraftDocument? document;
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static Trip fromJson(Map<String, Object?> j) =>
      Trip((j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is Trip && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

RectParams? rectOf(ParametricView v, Handle h) =>
    v.paramsOf<ClipRect>(h) ??
    v.paramsOf<SoftRect>(h) ??
    v.paramsOf<Trip>(h) ??
    v.paramsOf<Post>(h);

/// `generate` calls per handle, counted by [RectType], [PostType],
/// [PinType], [TagType] (Ruling 08-2) and the plan-10 clients (Ruling
/// 10-2). Tests clear it.
final Map<Handle, int> generateCalls = {};

void _counted(Handle h) => generateCalls[h] = (generateCalls[h] ?? 0) + 1;

List<Vector2> corners(RectParams p) => [
      Vector2(0, 0),
      Vector2(p.width, 0),
      Vector2(p.width, p.height),
      Vector2(0, p.height),
    ];

/// The open parameter interval of a->b strictly inside the convex quad [q],
/// or null. "Strictly": a segment lying on q's edge is outside.
(double, double)? insideInterval(Vector2 a, Vector2 b, List<Vector2> q) {
  const tol = Tolerance.standard;
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    area += u.x * v.y - v.x * u.y;
  }
  final s = area > 0 ? 1.0 : -1.0;
  final d = b - a;
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    final e = v - u;
    final len = e.length;
    final f0 = s * (e.x * (a.y - u.y) - e.y * (a.x - u.x)) / len;
    final fd = s * (e.x * d.y - e.y * d.x) / len;
    if (fd.abs() <= tol.linear) {
      if (f0 <= tol.linear) return null;
      continue;
    }
    final t = (tol.linear - f0) / fd;
    if (fd > 0) {
      lo = math.max(lo, t);
    } else {
      hi = math.min(hi, t);
    }
  }
  return (hi - lo) * d.length > Tolerance.standard.linear ? (lo, hi) : null;
}

/// The rectangle [0,w]x[0,h] in local space, minus every neighbour's
/// interior: four edges in order, each split into ascending pieces.
List<Generated> clippedRect(ParametricView view, Handle self) => [
      for (final edge in clippedEdges(view, self))
        for (final (a, b) in edge)
          Generated(EntityKind.line, linePayload(a, b)),
    ];

/// [clippedRect]'s pieces, edge by edge, in [self]'s local space: edge 0 is
/// the bottom edge, (0,0) to (w,0).
List<List<(Vector2, Vector2)>> clippedEdges(ParametricView view, Handle self) {
  final p = rectOf(view, self)!;
  final toLocal = view.toWorld(self).invert();
  final quads = [
    for (final n in view.neighbours(self))
      if (rectOf(view, n) case final q?)
        [
          for (final c in corners(q))
            toLocal.transformPoint(view.toWorld(n).transformPoint(c)),
        ],
  ];
  final c = corners(p);
  final out = <List<(Vector2, Vector2)>>[];
  for (var i = 0; i < 4; i++) {
    final a = c[i], b = c[(i + 1) % 4];
    final len = (b - a).length;
    var keep = <(double, double)>[(0, 1)];
    for (final q in quads) {
      final inside = insideInterval(a, b, q);
      if (inside == null) continue;
      keep = [
        for (final (lo, hi) in keep) ...[
          if ((math.min(hi, inside.$1) - lo) * len > Tolerance.standard.linear)
            (lo, math.min(hi, inside.$1)),
          if ((hi - math.max(lo, inside.$2)) * len > Tolerance.standard.linear)
            (math.max(lo, inside.$2), hi),
        ],
      ];
    }
    out.add([
      for (final (lo, hi) in keep) (a + (b - a) * lo, a + (b - a) * hi),
    ]);
  }
  return out;
}

Aabb2 rectReach(RectParams p, Transform2 toWorld) =>
    Aabb2.fromPoints([for (final c in corners(p)) toWorld.transformPoint(c)]);

final class RectType<T extends RectParams> extends ParametricType<T> {
  const RectType(this.editCapability);
  @override
  final Capability editCapability;
  @override
  Aabb2 reach(T params, Transform2 toWorld) => rectReach(params, toWorld);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _counted(self);
    return clippedRect(view, self);
  }
}

final class TripType extends ParametricType<Trip> {
  const TripType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Trip params, Transform2 toWorld) {
    // M-06w: a client's `reach` throwing on the *new* parameters, exercised
    // only for a non-positive width so the pre-edit survey (still the old
    // parameters) never trips it.
    if (Trip.mode == TripMode.throwingReach && params.width <= 0) {
      throw StateError('tripwire reach');
    }
    return rectReach(params, toWorld);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    switch (Trip.mode) {
      case TripMode.off:
      case TripMode.throwingReach:
        break;
      case TripMode.throwing:
        throw StateError('tripwire');
      case TripMode.reentrant:
        Trip.document!.commands
            .execute(SetComponentCommand<Trip>(self, const Trip(10, 10)));
    }
    return clippedRect(view, self);
  }
}

/// Generates one LINE and one ARC, in an order its parameter flips (M-06m).
final class Hinge implements Component {
  const Hinge(this.flip);
  static const String id = 'test.hinge';
  final bool flip;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'flip': flip};
  static Hinge fromJson(Map<String, Object?> j) => Hinge(j['flip']! as bool);
  @override
  bool operator ==(Object o) => o is Hinge && o.flip == flip;
  @override
  int get hashCode => flip.hashCode;
}

final class HingeType extends ParametricType<Hinge> {
  const HingeType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Hinge params, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(0, 0)),
        toWorld.transformPoint(Vector2(100, 100)),
      ]);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final line =
        Generated(EntityKind.line, linePayload(Vector2(0, 0), Vector2(100, 0)));
    final arc =
        Generated(EntityKind.arc, arcPayload(Vector2(50, 50), 40, 0.3, 1.2));
    return view.paramsOf<Hinge>(self)!.flip ? [arc, line] : [line, arc];
  }
}

/// How [RegionRectType] breaks its **last** region (RG7): a client bug the
/// planner must refuse, whether that region is matched or added.
enum RegionFault { none, open, crossed }

/// A rectangle generating [count] regions, one LINE and one open two-point
/// POLYLINE, like a wall's centreline (Ruling 07-8): the
/// planner's region handling, tested without wall geometry.
final class RegionRect implements Component {
  const RegionRect(this.width, this.height, this.count,
      {this.fault = RegionFault.none});
  static const String id = 'test.regionRect';
  final double width;
  final double height;
  final int count;
  final RegionFault fault;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {
        'width': width,
        'height': height,
        'count': count,
        'fault': fault.name,
      };
  static RegionRect fromJson(Map<String, Object?> j) => RegionRect(
      (j['width']! as num).toDouble(),
      (j['height']! as num).toDouble(),
      j['count']! as int,
      fault: RegionFault.values.byName(j['fault']! as String));
  @override
  bool operator ==(Object o) =>
      o is RegionRect &&
      o.width == width &&
      o.height == height &&
      o.count == count &&
      o.fault == fault;
  @override
  int get hashCode => Object.hash(width, height, count, fault);
}

/// Region [i] of a [RegionRect]: the rectangle inset by 10·i, closed.
List<Vector2> regionRectLoop(RegionRect p, int i) {
  final d = 10.0 * i;
  return [
    Vector2(d, d),
    Vector2(p.width - d, d),
    Vector2(p.width - d, p.height - d),
    Vector2(d, p.height - d),
  ];
}

/// A [RegionRect]'s plain POLYLINE child: open, two points, at mid height.
GeometryPayload regionRectCentreline(RegionRect p) =>
    polylinePayload([Vector2(0, p.height / 2), Vector2(p.width, p.height / 2)]);

final class RegionRectType extends ParametricType<RegionRect> {
  const RegionRectType(
      {this.regionColor = const ByLayerColor(),
      this.plainColor = const ByLayerColor()});

  /// The colour of every region (fill and boundary), and of every plain
  /// child, handed to [Generated] (spec 07 D3; RG11).
  final DraftColor regionColor, plainColor;

  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(RegionRect params, Transform2 toWorld) => Aabb2.fromPoints([
        for (final c in regionRectLoop(params, 0)) toWorld.transformPoint(c),
      ]);

  /// The diagonal LINE comes **first** on purpose: the planner, not the
  /// client, puts regions ahead of plain children (spec 07 D8). The open
  /// POLYLINE (the mid-height centreline) comes last: a plain child of the
  /// same kind as a region's boundary, which the planner must never match
  /// against a boundary.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<RegionRect>(self)!;
    return [
      Generated(EntityKind.line,
          linePayload(Vector2(0, 0), Vector2(p.width, p.height)),
          color: plainColor),
      for (var i = 0; i < p.count; i++)
        Generated.region(
            switch (i == p.count - 1 ? p.fault : null) {
              RegionFault.open => polylinePayload(regionRectLoop(p, i)),
              RegionFault.crossed => polylinePayload([
                  for (final k in [0, 2, 1, 3]) regionRectLoop(p, i)[k],
                ], closed: true),
              _ => polylinePayload(regionRectLoop(p, i), closed: true),
            },
            color: regionColor),
      Generated(EntityKind.polyline, regionRectCentreline(p),
          color: plainColor),
    ];
  }
}

/// A host (Ruling 08-2): a clipped rectangle, like [ClipRect], that also
/// reads its referrers, as a wall reads its openings.
final class Post implements RectParams {
  const Post(this.width, this.height);
  static const String id = 'test.post';
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static Post fromJson(Map<String, Object?> j) =>
      Post((j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is Post && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);

  /// How far below the bottom edge a referrer's tick reaches.
  static const double tick = 120;

  /// Handles whose `view.referrers` [PostType.diagnose] also reports (RF1),
  /// beyond the Post's own. Tests reset it.
  static List<Handle> watch = [];

  /// The very lists `view.referrers` returned to [PostType.diagnose], by
  /// the handle asked about (RF1: they must be unmodifiable). Tests clear
  /// it.
  static final Map<Handle, List<Handle>> seen = {};
}

/// A referrer's tick on its Post: one LINE down from the bottom edge at
/// [Pin.offset], in the Post's local space.
GeometryPayload postTick(double offset) =>
    linePayload(Vector2(offset, 0), Vector2(offset, -Post.tick));

Diagnostic referrersOf(Handle h, List<Handle> referrers) => Diagnostic(
      severity: DiagnosticSeverity.info,
      code: 'test.referrers',
      message: '${h.toHex()} has ${referrers.length} referrers',
      handles: [h, ...referrers],
    );

final class PostType extends ParametricType<Post> {
  const PostType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Post params, Transform2 toWorld) => rectReach(params, toWorld);

  /// [clippedRect], then one tick per referrer that is a [Pin], in the
  /// referrers' ascending order.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _counted(self);
    return [
      ...clippedRect(view, self),
      for (final r in view.referrers(self))
        if (view.paramsOf<Pin>(r) case final pin?)
          Generated(EntityKind.line, postTick(pin.offset)),
    ];
  }

  /// One `test.referrers` entry for itself, then one per [Post.watch]
  /// handle, each naming the handle then its referrers.
  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) => [
        for (final h in [self, ...Post.watch])
          referrersOf(h, Post.seen[h] = view.referrers(h)),
      ];
}

/// A referrer (Ruling 08-2): it names a [host] and reads it. [offset] is
/// read by the host, [region] adds one region to what it generates.
final class Pin implements Component {
  const Pin(this.host, this.offset, {this.region = false});
  static const String id = 'test.pin';
  final Handle host;
  final double offset;
  final bool region;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() =>
      {'host': host.toJson(), 'offset': offset, 'region': region};
  static Pin fromJson(Map<String, Object?> j) =>
      Pin(Handle.fromJson(j['host']), (j['offset']! as num).toDouble(),
          region: j['region']! as bool);
  @override
  bool operator ==(Object o) =>
      o is Pin && o.host == host && o.offset == offset && o.region == region;
  @override
  int get hashCode => Object.hash(host, offset, region);
}

/// A [Pin]'s region, when it has one: a closed square in its local space.
final GeometryPayload pinRegion = polylinePayload(
    [Vector2(0, 0), Vector2(50, 0), Vector2(50, 50), Vector2(0, 50)],
    closed: true);

final class PinType extends ParametricType<Pin> {
  const PinType();
  @override
  Capability get editCapability => Capability.geometry;

  /// Empty: no spatial relation ever finds a Pin; only its reference does.
  @override
  Aabb2 reach(Pin params, Transform2 toWorld) => Aabb2.empty();

  @override
  Iterable<Handle> references(Pin params) => [params.host];

  /// On a [Post]: the host's **clipped** bottom edge, host-local to world
  /// to its own local, so it depends on the host's neighbours (the two-hop
  /// shape). On another Pin: one LINE from its own origin to the host's.
  /// Otherwise nothing, and a region last when [Pin.region] is set.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _counted(self);
    final p = view.paramsOf<Pin>(self)!;
    final host = p.host;
    final out = <Generated>[];
    if (view.paramsOf<Post>(host) != null) {
      out.addAll(hostEdge(view, self, host));
    } else if (host != self && view.paramsOf<Pin>(host) != null) {
      // Not on itself: that line would have no length.
      out.add(Generated(
          EntityKind.line,
          linePayload(Vector2(0, 0),
              hostToOwn(view, self, host).transformPoint(Vector2(0, 0)))));
    }
    if (p.region) out.add(Generated.region(pinRegion));
    return out;
  }
}

/// [host]'s local space to [self]'s; asked only for a host that is live.
Transform2 hostToOwn(ParametricView view, Handle self, Handle host) =>
    view.toWorld(self).invert().multiply(view.toWorld(host));

/// The Post [host]'s **clipped** bottom edge, host-local to world to
/// [self]'s local: one LINE per piece.
List<Generated> hostEdge(ParametricView view, Handle self, Handle host) {
  final m = hostToOwn(view, self, host);
  return [
    for (final (a, b) in clippedEdges(view, host)[0])
      Generated(EntityKind.line,
          linePayload(m.transformPoint(a), m.transformPoint(b))),
  ];
}

/// An `orphan`-policy referrer (Ruling 08-2, spec 08 D4): like [Pin] on a
/// live Post, and kept when its host goes. It declares its host **twice**,
/// so the survey's and `diagnostics()`'s deduplication are both exercised.
final class Tag implements Component {
  const Tag(this.host);
  static const String id = 'test.orphanTag';
  final Handle host;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'host': host.toJson()};
  static Tag fromJson(Map<String, Object?> j) =>
      Tag(Handle.fromJson(j['host']));
  @override
  bool operator ==(Object o) => o is Tag && o.host == host;
  @override
  int get hashCode => host.hashCode;

  /// The orphan marker's length, up the Tag's own local y axis.
  static const double marker = 250;
}

/// What a [Tag] draws with no live Post: one fixed LINE at its own origin.
final GeometryPayload tagMarker =
    linePayload(Vector2(0, 0), Vector2(0, Tag.marker));

final class TagType extends ParametricType<Tag> {
  const TagType();
  @override
  Capability get editCapability => Capability.geometry;

  @override
  ReferencePolicy get referencePolicy => ReferencePolicy.orphan;

  @override
  Aabb2 reach(Tag params, Transform2 toWorld) => Aabb2.empty();

  @override
  Iterable<Handle> references(Tag params) => [params.host, params.host];

  /// On a live [Post]: the host's clipped bottom edge, as a [Pin] draws it.
  /// Otherwise the orphan marker.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _counted(self);
    final host = view.paramsOf<Tag>(self)!.host;
    if (view.paramsOf<Post>(host) != null) return hostEdge(view, self, host);
    return [Generated(EntityKind.line, tagMarker)];
  }
}

/// A text client (spec 10 D12, Ruling 10-2): one generated TEXT holding
/// [text], centred on its insertion point ([x], [y]) in its own local
/// space.
final class Caption implements Component {
  const Caption(this.text, this.x, this.y);
  static const String id = 'test.caption';
  final String text;
  final double x, y;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'text': text, 'x': x, 'y': y};
  static Caption fromJson(Map<String, Object?> j) => Caption(
      j['text']! as String,
      (j['x']! as num).toDouble(),
      (j['y']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is Caption && o.text == text && o.x == x && o.y == y;
  @override
  int get hashCode => Object.hash(text, x, y);

  /// Its TEXT's cap height, model mm.
  static const double height = 250;

  /// Its TEXT's justification: centre, middle (Ruling 10-14's literal).
  static final int attrs =
      packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.middle);
}

/// A [Caption]'s TEXT payload, in its own local space.
GeometryPayload captionPayload(Caption p) =>
    textPayload(Vector2(p.x, p.y), Caption.height);

final class CaptionType extends ParametricType<Caption> {
  const CaptionType();
  @override
  Capability get editCapability => Capability.geometry;

  /// A 1 mm box centred on the insertion point, in world.
  @override
  Aabb2 reach(Caption params, Transform2 toWorld) => Aabb2.fromPoints([
        for (final (dx, dy) in const [
          (-.5, -.5),
          (.5, -.5),
          (.5, .5),
          (-.5, .5)
        ])
          toWorld.transformPoint(Vector2(params.x + dx, params.y + dy)),
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _counted(self);
    final p = view.paramsOf<Caption>(self)!;
    return [
      Generated.text(captionPayload(p), p.text, textAttrs: Caption.attrs),
    ];
  }
}

/// An attributes client (spec 10 D13, Ruling 10-2): a 400 x 300 region, a
/// plain LINE and two TEXTs at ([x], [y]) in its own local space, each
/// record with attributes read from its parameters, so a test can tell
/// "written on add" from "rewritten on a match".
///
/// [inherit] leaves the region's `boundaryFlags` unset and gives its fill
/// `EntityFlags.invisible`, so the boundary must take the fill's flags
/// (D13's default). Otherwise the fill's flags are 0 and the boundary's are
/// `invisible`, which tells them apart.
///
/// The two TEXTs' strings, [first] and [second], change independently, so
/// matching the i-th generated TEXT to the i-th existing one is observable
/// (Task 1's review, rv1-idx). The first TEXT's flags are `invisible`, so
/// a builder that drops the flags is observable on a TEXT too (rv1-flags).
final class Swatch implements Component {
  const Swatch(this.x, this.y, this.alpha, this.weight,
      {this.first = 'Oak', this.second = 'Ash', this.inherit = false});
  static const String id = 'test.swatch';
  final double x, y;

  /// The transparency of the region's two records and of the LINE.
  final int alpha;

  /// The LINE's lineweight.
  final int weight;
  final String first, second;
  final bool inherit;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {
        'x': x,
        'y': y,
        'alpha': alpha,
        'weight': weight,
        'first': first,
        'second': second,
        'inherit': inherit,
      };
  static Swatch fromJson(Map<String, Object?> j) => Swatch(
      (j['x']! as num).toDouble(),
      (j['y']! as num).toDouble(),
      j['alpha']! as int,
      j['weight']! as int,
      first: j['first']! as String,
      second: j['second']! as String,
      inherit: j['inherit']! as bool);
  @override
  bool operator ==(Object o) =>
      o is Swatch &&
      o.x == x &&
      o.y == y &&
      o.alpha == alpha &&
      o.weight == weight &&
      o.first == first &&
      o.second == second &&
      o.inherit == inherit;
  @override
  int get hashCode => Object.hash(x, y, alpha, weight, first, second, inherit);

  static const double width = 400, height = 300;

  /// Its TEXTs' cap height, model mm.
  static const double textHeight = 60;

  /// The first TEXT's justification: centre, middle (0x21).
  static final int firstAttrs =
      packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.middle);

  /// The second TEXT's justification: right, top (0x32).
  static final int secondAttrs =
      packTextAttrs(h: TextJustifyH.right, v: TextJustifyV.top);
}

/// A [Swatch]'s rectangle, closed, in its own local space.
GeometryPayload swatchLoop(Swatch p) => polylinePayload([
      Vector2(p.x, p.y),
      Vector2(p.x + Swatch.width, p.y),
      Vector2(p.x + Swatch.width, p.y + Swatch.height),
      Vector2(p.x, p.y + Swatch.height),
    ], closed: true);

/// A [Swatch]'s LINE: the rectangle's diagonal.
GeometryPayload swatchLine(Swatch p) => linePayload(
    Vector2(p.x, p.y), Vector2(p.x + Swatch.width, p.y + Swatch.height));

/// A [Swatch]'s two TEXT payloads: at the centre, and below the rectangle.
GeometryPayload swatchFirstText(Swatch p) => textPayload(
    Vector2(p.x + Swatch.width / 2, p.y + Swatch.height / 2),
    Swatch.textHeight);
GeometryPayload swatchSecondText(Swatch p) =>
    textPayload(Vector2(p.x + Swatch.width, p.y - 20), Swatch.textHeight);

final class SwatchType extends ParametricType<Swatch> {
  const SwatchType();
  @override
  Capability get editCapability => Capability.geometry;

  /// The rectangle, in world.
  @override
  Aabb2 reach(Swatch params, Transform2 toWorld) => Aabb2.fromPoints([
        for (final (dx, dy) in const [
          (0.0, 0.0),
          (Swatch.width, 0.0),
          (Swatch.width, Swatch.height),
          (0.0, Swatch.height)
        ])
          toWorld.transformPoint(Vector2(params.x + dx, params.y + dy)),
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _counted(self);
    final p = view.paramsOf<Swatch>(self)!;
    return [
      p.inherit
          ? Generated.region(swatchLoop(p),
              transparency: p.alpha, flags: EntityFlags.invisible)
          : Generated.region(swatchLoop(p),
              transparency: p.alpha,
              flags: 0,
              boundaryFlags: EntityFlags.invisible),
      Generated(EntityKind.line, swatchLine(p),
          transparency: p.alpha,
          flags: EntityFlags.invisible,
          linetype: ReservedHandles.continuousLinetype,
          lineweight: p.weight),
      Generated.text(swatchFirstText(p), p.first,
          textAttrs: Swatch.firstAttrs, flags: EntityFlags.invisible),
      Generated.text(swatchSecondText(p), p.second,
          textAttrs: Swatch.secondAttrs),
    ];
  }
}

/// A 1 mm box centred on ([x], [y]) in an object's local space, in world:
/// the reach of the page-key clients, which never reaches a neighbour's in
/// the page tests.
Aabb2 dotReach(double x, double y, Transform2 toWorld) => Aabb2.fromPoints([
      for (final (dx, dy) in const [(-.5, -.5), (.5, -.5), (.5, .5), (-.5, .5)])
        toWorld.transformPoint(Vector2(x + dx, y + dy)),
    ]);

/// A page-key client keyed on the page's scale (spec 10 D14, Ruling 10-2):
/// one LINE from ([x], [y]) along its own local x axis, `10 x` the scale
/// denominator long (500 with no page). [host], when set, is declared in
/// `references` (policy `cascade`) and otherwise ignored, so a loaded
/// Gauge can name a dead handle (Ruling 10-4).
final class Gauge implements Component {
  const Gauge(this.x, this.y, {this.host});
  static const String id = 'test.gauge';
  final double x, y;
  final Handle? host;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'x': x, 'y': y, 'host': host?.toJson()};
  static Gauge fromJson(Map<String, Object?> j) =>
      Gauge((j['x']! as num).toDouble(), (j['y']! as num).toDouble(),
          host: j['host'] == null ? null : Handle.fromJson(j['host']));
  @override
  bool operator ==(Object o) =>
      o is Gauge && o.x == x && o.y == y && o.host == host;
  @override
  int get hashCode => Object.hash(x, y, host);

  /// The key: the page's scale denominator, 50 with no page.
  static double keyOf(PageComponent? page) => page?.scaleDenominator ?? 50;

  /// [GaugeType.pageKey] calls, never reset: tests read deltas (spec 10
  /// D14: a `pageKey` is called on a page-changing edit only; Task 3's
  /// review, rv3-noShort).
  static int pageKeyCalls = 0;
}

final class GaugeType extends ParametricType<Gauge> {
  const GaugeType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Gauge params, Transform2 toWorld) =>
      dotReach(params.x, params.y, toWorld);
  @override
  Iterable<Handle> references(Gauge params) =>
      [if (params.host case final host?) host];
  @override
  Object? pageKey(PageComponent? page) {
    Gauge.pageKeyCalls++;
    return Gauge.keyOf(page);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _counted(self);
    final p = view.paramsOf<Gauge>(self)!;
    final length = 10 * Gauge.keyOf(view.page);
    return [
      Generated(EntityKind.line,
          linePayload(Vector2(p.x, p.y), Vector2(p.x + length, p.y))),
    ];
  }
}

/// A page-key client keyed on the page's display unit (spec 10 D14, Ruling
/// 10-2): one LINE from ([x], [y]) along its own local x axis,
/// `100 x (unit.index + 1)` long (300 with no page: metres).
final class Dial implements Component {
  const Dial(this.x, this.y);
  static const String id = 'test.dial';
  final double x, y;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'x': x, 'y': y};
  static Dial fromJson(Map<String, Object?> j) =>
      Dial((j['x']! as num).toDouble(), (j['y']! as num).toDouble());
  @override
  bool operator ==(Object o) => o is Dial && o.x == x && o.y == y;
  @override
  int get hashCode => Object.hash(x, y);

  /// The key: the page's display unit, metres with no page.
  static DisplayUnit keyOf(PageComponent? page) =>
      page?.displayUnit ?? DisplayUnit.meters;
}

final class DialType extends ParametricType<Dial> {
  const DialType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Dial params, Transform2 toWorld) =>
      dotReach(params.x, params.y, toWorld);
  @override
  Object? pageKey(PageComponent? page) => Dial.keyOf(page);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _counted(self);
    final p = view.paramsOf<Dial>(self)!;
    final length = 100.0 * (Dial.keyOf(view.page).index + 1);
    return [
      Generated(EntityKind.line,
          linePayload(Vector2(p.x, p.y), Vector2(p.x + length, p.y))),
    ];
  }
}

/// A dissolving client (spec 10 D15, Ruling 10-2): a [w] x [h] rectangle
/// at ([x], [y]) in its own local space. It generates a region on the
/// rectangle and a LINE on its diagonal, and dissolves when [burnt] is set
/// or when a [ClipRect] neighbour covers its world centre: a verdict read
/// from the after-view, as a room's is.
final class Fuse implements Component {
  const Fuse(this.x, this.y, this.w, this.h, {this.burnt = false});
  static const String id = 'test.fuse';
  final double x, y, w, h;
  final bool burnt;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() =>
      {'x': x, 'y': y, 'w': w, 'h': h, 'burnt': burnt};
  static Fuse fromJson(Map<String, Object?> j) => Fuse(
      (j['x']! as num).toDouble(),
      (j['y']! as num).toDouble(),
      (j['w']! as num).toDouble(),
      (j['h']! as num).toDouble(),
      burnt: j['burnt']! as bool);
  @override
  bool operator ==(Object o) =>
      o is Fuse &&
      o.x == x &&
      o.y == y &&
      o.w == w &&
      o.h == h &&
      o.burnt == burnt;
  @override
  int get hashCode => Object.hash(x, y, w, h, burnt);

  /// [FuseType.dissolves] calls per handle. Tests clear it.
  static final Map<Handle, int> dissolvesCalls = {};

  /// When set, [FuseType.dissolves] throws (DV1's rollback case). Tests
  /// reset it.
  static bool fault = false;

  /// The rectangle's corners, anticlockwise, in its own local space.
  List<Vector2> get corners => [
        Vector2(x, y),
        Vector2(x + w, y),
        Vector2(x + w, y + h),
        Vector2(x, y + h),
      ];

  /// The rectangle's centre, in its own local space.
  Vector2 get centre => Vector2(x + w / 2, y + h / 2);
}

final class FuseType extends ParametricType<Fuse> {
  const FuseType();
  @override
  Capability get editCapability => Capability.geometry;

  /// The rectangle, in world.
  @override
  Aabb2 reach(Fuse params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final c in params.corners) toWorld.transformPoint(c)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _counted(self);
    final p = view.paramsOf<Fuse>(self)!;
    final c = p.corners;
    return [
      Generated.region(polylinePayload(c, closed: true)),
      Generated(EntityKind.line, linePayload(c[0], c[2])),
    ];
  }

  /// [Fuse.burnt], or a [ClipRect] neighbour holds the world centre
  /// strictly inside (by `Tolerance.standard.linear`), read in the
  /// neighbour's own local space.
  @override
  bool dissolves(ParametricView view, Handle self) {
    Fuse.dissolvesCalls[self] = (Fuse.dissolvesCalls[self] ?? 0) + 1;
    if (Fuse.fault) throw StateError('fuse fault');
    final p = view.paramsOf<Fuse>(self);
    if (p == null) return false;
    if (p.burnt) return true;
    final centre = view.toWorld(self).transformPoint(p.centre);
    const tol = Tolerance.standard;
    for (final n in view.neighbours(self)) {
      final r = view.paramsOf<ClipRect>(n);
      if (r == null) continue;
      final q = view.toWorld(n).invert().transformPoint(centre);
      if (q.x > tol.linear &&
          q.x < r.width - tol.linear &&
          q.y > tol.linear &&
          q.y < r.height - tol.linear) {
        return true;
      }
    }
    return false;
  }
}

ParametricCatalog testCatalog() => ParametricCatalog()
  ..register<ClipRect>(ClipRect.id, ClipRect.fromJson,
      const RectType<ClipRect>(Capability.geometry))
  ..register<SoftRect>(SoftRect.id, SoftRect.fromJson,
      const RectType<SoftRect>(Capability.components))
  ..register<Trip>(Trip.id, Trip.fromJson, const TripType())
  ..register<Hinge>(Hinge.id, Hinge.fromJson, const HingeType())
  ..register<RegionRect>(
      RegionRect.id, RegionRect.fromJson, const RegionRectType())
  ..register<Post>(Post.id, Post.fromJson, const PostType())
  ..register<Pin>(Pin.id, Pin.fromJson, const PinType())
  ..register<Tag>(Tag.id, Tag.fromJson, const TagType())
  ..register<Caption>(Caption.id, Caption.fromJson, const CaptionType())
  ..register<Swatch>(Swatch.id, Swatch.fromJson, const SwatchType())
  ..register<Gauge>(Gauge.id, Gauge.fromJson, const GaugeType())
  ..register<Dial>(Dial.id, Dial.fromJson, const DialType())
  ..register<Fuse>(Fuse.id, Fuse.fromJson, const FuseType());
