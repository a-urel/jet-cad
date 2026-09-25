// SPIKE 08 -- throwaway. Openings hosted in walls: a door, a window, a gap.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall.dart';
import 'wall_geometry.dart';

enum OpeningKind { door, window, gap }

/// Which jamb a door hangs on, seen along the host from start to end.
enum HingeEnd { start, end }

/// Which face of the host a door's leaf swings out of.
enum SwingSide { left, right }

/// An opening's parameters: its host wall, the distance from the host's
/// start to the opening's **centre** along the host's centreline, and its
/// width, in mm; a door's hinge end and swing side.
final class OpeningParams implements Component {
  const OpeningParams(this.host, this.position, this.width, this.kind,
      {this.hinge = HingeEnd.start, this.swing = SwingSide.left});

  static const String componentTypeId = 'floor_planner.opening';

  final Handle host;
  final double position, width;
  final OpeningKind kind;
  final HingeEnd hinge;
  final SwingSide swing;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'host': host.value,
        'position': position,
        'width': width,
        'kind': kind.name,
        'hinge': hinge.name,
        'swing': swing.name,
      };

  static OpeningParams fromJson(Map<String, Object?> json) => OpeningParams(
        Handle.checked(json['host']! as int),
        (json['position']! as num).toDouble(),
        (json['width']! as num).toDouble(),
        OpeningKind.values.byName(json['kind']! as String),
        hinge: HingeEnd.values.byName(json['hinge']! as String),
        swing: SwingSide.values.byName(json['swing']! as String),
      );

  OpeningParams copyWith(
          {Handle? host,
          double? position,
          double? width,
          HingeEnd? hinge,
          SwingSide? swing}) =>
      OpeningParams(host ?? this.host, position ?? this.position,
          width ?? this.width, kind,
          hinge: hinge ?? this.hinge, swing: swing ?? this.swing);

  @override
  bool operator ==(Object other) =>
      other is OpeningParams &&
      other.host == host &&
      other.position == position &&
      other.width == width &&
      other.kind == kind &&
      other.hinge == hinge &&
      other.swing == swing;

  @override
  int get hashCode => Object.hash(host, position, width, kind, hinge, swing);
}

/// A host wall seen from its own group-local space: its centreline frame,
/// its face offsets, its two caps and its **straight span** `[uS, uE]` --
/// the interval of `u` (distance from `start` along the centreline) where
/// both faces are plain offsets: past every start-cap vertex and short of
/// every end-cap vertex.
final class HostFrame {
  HostFrame(this.s, this.d, this.len, this.lOff, this.rOff, this.endCap,
      this.startCap, this.fellBack)
      : uS = startCap.map((q) => (q - s).dot(d)).reduce(math.max),
        uE = endCap.map((q) => (q - s).dot(d)).reduce(math.min);

  final Vector2 s, d;
  final double len, lOff, rOff;
  final List<Vector2> endCap, startCap;
  final bool fellBack;
  final double uS, uE;

  Vector2 get n => Vector2(-d.y, d.x);

  /// The point `u` along the centreline and [off] along the left normal.
  Vector2 at(double u, double off) => s + d * u + n * off;

  Vector2 left(double u) => at(u, lOff);
  Vector2 right(double u) => at(u, rOff);

  double uOf(Vector2 q) => (q - s).dot(d);
}

/// [wall]'s frame in its own local space, from its parameters and its wall
/// neighbours' (07's joints). Null when [wall] is not a live wall or is
/// degenerate. One function for the wall and its openings: same bits.
HostFrame? hostFrame(ParametricView view, Handle wall) {
  final p = view.paramsOf<WallParams>(wall);
  if (p == null) return null;
  final toWorld = view.toWorld(wall);
  final me = WorldWall(wall, p, toWorld);
  final others = [
    for (final h in view.neighbours(wall))
      if (view.paramsOf<WallParams>(h) case final q?)
        WorldWall(h, q, view.toWorld(h)),
  ];
  final caps = capsOf(me, others);
  if (caps == null) return null;
  final toLocal = toWorld.invert();
  final s = p.start, dv = p.end - p.start;
  final d = dv.normalized();
  final (l, r) = me.offsets;
  var ce = [for (final q in caps.endCap) toLocal.transformPoint(q)];
  var cs = [for (final q in caps.startCap) toLocal.transformPoint(q)];
  var fellBack = caps.fellBack;
  if (!isSimpleCcw(simplifyRing([...ce, ...cs]))) {
    // 07's final-review I1: judged again in local space.
    final free = WorldWall(wall, p, Transform2.identity());
    ce = cap(End(free, 1), const Free()).points;
    cs = cap(End(free, 0), const Free()).points;
    fellBack = true;
  }
  return HostFrame(s, d, dv.length, l, r, ce, cs, fellBack);
}

/// Where [o] cuts its host: `[a, b]` along the centreline, clamped into the
/// straight span (the stored position is kept; only the drawing moves).
/// Null when it does not fit: no positive width, or a straight span
/// shorter than the width. Then the wall is uncut.
(double, double)? cutOf(HostFrame f, OpeningParams o) {
  final w = o.width;
  if (!(w > wallJoin.linear) || w > f.uE - f.uS) return null;
  final c = o.position; // M-08b: f.len - o.position
  final a = (c - w / 2).clamp(f.uS, f.uE - w).toDouble();
  return (a, a + w); // M-08c: (c, c)
}

/// The interval an opening's symbol is drawn over: its cut, or, when it
/// does not fit, its stored position unclamped.
(double, double) drawnOf(HostFrame f, OpeningParams o) =>
    cutOf(f, o) ?? (o.position - o.width / 2, o.position + o.width / 2);

/// The cuts merged: sorted by start; a cut that starts within
/// `wallJoin.linear` of the previous one's end joins it (no sliver piece).
List<(double, double)> mergeCuts(List<(double, double)> cuts) {
  final sorted = [...cuts]..sort((x, y) => x.$1.compareTo(y.$1));
  final out = <(double, double)>[];
  for (final c in sorted) {
    if (out.isNotEmpty && c.$1 <= out.last.$2 + wallJoin.linear) {
      out.last = (out.last.$1, math.max(out.last.$2, c.$2));
    } else {
      out.add(c);
    }
  }
  return out;
}

/// The wall's band split by [cuts] (already merged), start piece first:
/// each piece an anticlockwise ring in local space. The start piece carries
/// the start cap, the end piece the end cap. A piece no longer than
/// `wallJoin.linear` along the centreline is dropped (an opening clamped
/// against a square cap).
List<List<Vector2>> piecesOf(HostFrame f, List<(double, double)> cuts) {
  final out = <List<Vector2>>[];
  void add(List<Vector2> ring, double extent) {
    if (!(extent > wallJoin.linear)) return;
    out.add(simplifyRing(ring));
  }

  final a0 = cuts.first.$1;
  add([f.right(a0), f.left(a0), ...f.startCap],
      a0 - f.startCap.map(f.uOf).reduce(math.min));
  for (var i = 0; i + 1 < cuts.length; i++) {
    final b = cuts[i].$2, a = cuts[i + 1].$1;
    add([f.right(a), f.left(a), f.left(b), f.right(b)], a - b);
  }
  final bn = cuts.last.$2;
  add([...f.endCap, f.left(bn), f.right(bn)],
      f.endCap.map(f.uOf).reduce(math.max) - bn);
  return out;
}

/// [self]'s openings: the referrers that are openings hosted by it, in
/// ascending handle order.
List<OpeningParams> openingsOf(ParametricView view, Handle self) => [
      for (final h in view.referrers(self))
        if (view.paramsOf<OpeningParams>(h) case final o? when o.host == self)
          o,
    ];

/// The opening type: no spatial reach, a reference to its host, a symbol
/// generated in its own group's local space from the host's frame.
final class OpeningType extends ParametricType<OpeningParams> {
  const OpeningType();

  @override
  Capability get editCapability => Capability.geometry;

  /// It cannot see its host: an empty box, never anybody's neighbour.
  /// References drive its regeneration.
  @override
  Aabb2 reach(OpeningParams params, Transform2 toWorld) => Aabb2.empty();

  @override
  Iterable<Handle> references(OpeningParams params) => [params.host];

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final o = view.paramsOf<OpeningParams>(self)!;
    final f = hostFrame(view, o.host);
    if (f == null) return const [];
    final (a, b) = drawnOf(f, o);
    // Host-local -> world -> this group's local space.
    final m = view.toWorld(self).invert().multiply(view.toWorld(o.host));
    Vector2 loc(Vector2 q) => m.transformPoint(q);
    switch (o.kind) {
      case OpeningKind.gap:
        return const [];
      case OpeningKind.window:
        final mid = (f.lOff + f.rOff) / 2;
        return [
          Generated(
              EntityKind.line, linePayload(loc(f.left(a)), loc(f.left(b)))),
          Generated(EntityKind.line,
              linePayload(loc(f.at(a, mid)), loc(f.at(b, mid)))),
          Generated(
              EntityKind.line, linePayload(loc(f.right(a)), loc(f.right(b)))),
        ];
      case OpeningKind.door:
        final w = b - a;
        final (uh, uo) = o.hinge == HingeEnd.start ? (a, b) : (b, a);
        final (off, sgn) =
            o.swing == SwingSide.left ? (f.lOff, 1.0) : (f.rOff, -1.0);
        final hinge = loc(f.at(uh, off));
        final tip = loc(f.at(uh, off + sgn * w));
        final shut = loc(f.at(uo, off));
        final t = tip - hinge, c = shut - hinge;
        final at = math.atan2(t.y, t.x), ac = math.atan2(c.y, c.x);
        final ccw = t.x * c.y - t.y * c.x > 0;
        return [
          Generated(EntityKind.line, linePayload(hinge, tip)),
          Generated(
              EntityKind.arc, arcPayload(hinge, w, ccw ? at : ac, math.pi / 2)),
        ];
    }
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    final o = view.paramsOf<OpeningParams>(self)!;
    Diagnostic d(String code, String message, [List<Handle>? hs]) => Diagnostic(
        severity: DiagnosticSeverity.warning,
        code: code,
        message: message,
        handles: hs ?? [self]);
    final f = hostFrame(view, o.host);
    if (f == null) {
      return [d('opening.orphan', 'no live wall ${o.host.toHex()}')];
    }
    final cut = cutOf(f, o);
    if (cut == null) {
      return [d('opening.nofit', 'the straight span is shorter than it')];
    }
    return [
      if (cut.$1 != o.position - o.width / 2)
        d('opening.clamped', 'drawn clamped into the straight span'),
      for (final h in view.referrers(o.host))
        if (h != self)
          if (view.paramsOf<OpeningParams>(h) case final q?)
            if (cutOf(f, q) case final c?)
              if (c.$1 < cut.$2 - wallJoin.linear &&
                  cut.$1 < c.$2 - wallJoin.linear)
                d('opening.overlap', 'overlaps ${h.toHex()}', [self, h]),
    ];
  }
}
