// Openings hosted in walls (spec 08 D1, D6): their parameters. No Flutter
// import. The geometry they are drawn and cut with is pure Dart, in
// `opening_geometry.dart`.
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'opening_geometry.dart';
import 'wall.dart';

/// What an opening is (spec 08 D6), fixed at creation.
enum OpeningKind { door, window, gap }

/// Which jamb a door hangs on, seen along the host from `start` to `end`
/// (spec 08 D6).
enum HingeEnd { start, end }

/// Which face of the host a door's leaf swings out of, looking from `start`
/// to `end` (spec 08 D6; 07 D2's left and right).
enum SwingSide { left, right }

/// An opening's parameters (spec 08 D6), in mm.
///
/// - [host]: the host wall's handle;
/// - [position]: the distance along the host's centreline from the host's
///   `start` to the opening's **centre**, in the host's group-local space;
/// - [width]: the opening's extent along the centreline;
/// - [kind]: fixed at creation, so [copyWith] cannot change it;
/// - [hinge] and [swing]: a door's; a window or a gap carries them (the
///   tools write `start` and `left`) and never reads them.
///
/// Value-equal with exact `==` on every field: stored values. `fromJson`
/// accepts anything well-typed: a position outside the wall (drawn clamped,
/// D8) or a degenerate width (D6: it cuts and generates nothing) loads.
final class OpeningParams implements Component {
  const OpeningParams(this.host, this.position, this.width, this.kind,
      {this.hinge = HingeEnd.start, this.swing = SwingSide.left});

  static const String componentTypeId = 'floor_planner.opening';

  final Handle host;
  final double position;
  final double width;
  final OpeningKind kind;
  final HingeEnd hinge;
  final SwingSide swing;

  @override
  String get typeId => componentTypeId;

  /// All six keys, for every kind, in this order (D6): one shape, one
  /// round-trip path. The host is its integer value; enums are their names.
  @override
  Map<String, Object?> toJson() => {
        'host': host.toJson(),
        'position': position,
        'width': width,
        'kind': kind.name,
        'hinge': hinge.name,
        'swing': swing.name,
      };

  /// Throws on a missing key, a host that is not a handle, or an unknown
  /// enum name.
  static OpeningParams fromJson(Map<String, Object?> json) => OpeningParams(
        Handle.fromJson(json['host']),
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

  @override
  String toString() => 'OpeningParams(${kind.name} on ${host.toHex()} at '
      '$position, $width, ${hinge.name}, ${swing.name})';
}

/// The opening (spec 08 D1, D10): its own root-level group, at the identity
/// like a wall, referencing its host.
///
/// - [reach] is `Aabb2.empty()`: an opening overlaps nothing, so it is never
///   anybody's spatial neighbour and has none; its reference to its host
///   alone brings it into a closure (D3), and the host's edit regenerates
///   it, its edit the host;
/// - [references] is `[host]`, with the default policy, `cascade`: deleting
///   the host deletes its openings in the same edit (D4);
/// - [generate] draws nothing yet: the symbols come with Task 6 (Ruling
///   08-7), so until then an opening is a childless group whose only effect
///   is the cut it makes in its host (D9, `WallType`);
/// - [diagnose] reports D17's codes, from the same decision the host's cut
///   takes ([hostCutsInView]).
final class OpeningType extends ParametricType<OpeningParams> {
  const OpeningType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(OpeningParams params, Transform2 toWorld) => Aabb2.empty();

  @override
  Iterable<Handle> references(OpeningParams params) => [params.host];

  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];

  /// At most one entry of each code for [self] (spec 08 D17), warnings
  /// unless stated, except `opening.overlap`, one per overlapping pair:
  ///
  /// - `opening.degenerate`, severity error: D6's degenerate opening (a
  ///   width not greater than `wallJoin.linear`, a non-finite position or
  ///   width). It cuts nothing, and nothing else is reported for it.
  /// - `opening.orphan`: the host is a live object that is not a wall (a
  ///   box): handles `[self, host]`. A host that is not a live object at
  ///   all is the engine's `parametric.dangling` (D5), not reported here.
  ///   The host is live exactly when [self] is among its referrers: the
  ///   engine's survey relates only live objects.
  /// - `opening.nofit`: no stretch holds it (D8), or D8's "a wall keeps a
  ///   piece" made it no-fit, or its host is a degenerate wall, which has
  ///   no stretch at all: handles `[self]`. Never also `opening.clamped`.
  /// - `opening.clamped`: drawn off its stored interval (D8): handles
  ///   `[self]`, then every wall whose obstacle interval overlaps the
  ///   **unclamped** interval, ascending. The message says whether a corner
  ///   (the unclamped interval leaves the straight span, or no obstacle is
  ///   in the way) or a wall (an obstacle) moved it.
  /// - `opening.overlap`: [self]'s cut overlaps a fitting cut of a
  ///   higher-handle opening of the same host (D8's [overlaps]): one entry
  ///   per such opening, handles `[self, higher]`. Reported by the lower
  ///   handle only, so once per pair (R2).
  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    final o = view.paramsOf<OpeningParams>(self)!;
    if (!o.position.isFinite ||
        !o.width.isFinite ||
        !(o.width > wallJoin.linear)) {
      return [
        Diagnostic(
          severity: DiagnosticSeverity.error,
          code: 'opening.degenerate',
          message: 'opening ${self.toHex()} has width ${o.width} at '
              '${o.position}: it cuts and draws nothing',
          handles: [self],
        ),
      ];
    }
    final host = o.host;
    if (view.paramsOf<WallParams>(host) == null) {
      if (host != self && !view.referrers(host).contains(self)) {
        return const [];
      }
      return [
        Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: 'opening.orphan',
          message: 'opening ${self.toHex()} is hosted by ${host.toHex()}, '
              'which is not a wall: it draws nothing',
          handles: [self, host],
        ),
      ];
    }
    final nofit = Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'opening.nofit',
      message: 'opening ${self.toHex()} does not fit in wall '
          '${host.toHex()}: it cuts nothing and is drawn outside the wall',
      handles: [self],
    );
    final all = hostCutsInView(view, host);
    if (all == null) return [nofit];
    final i = all.openings.indexOf(self);
    final cut = all.cuts[i];
    if (cut == null) return [nofit];
    final lo = o.position - o.width / 2, hi = o.position + o.width / 2;
    final frame = all.layout.frame;
    final walls = {
      for (final ob in all.layout.obstacles)
        if (overlaps((lo, hi), (ob.a, ob.b))) ob.wall,
    }.toList()
      ..sort((x, y) => x.value.compareTo(y.value));
    final byCorner = walls.isEmpty || lo < frame.uS || hi > frame.uE;
    final cause = [
      if (byCorner) 'a corner of wall ${host.toHex()}',
      if (walls.isNotEmpty)
        'wall ${[for (final w in walls) w.toHex()].join(', ')}',
    ].join(' and ');
    return [
      if (cut.clamped)
        Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: 'opening.clamped',
          message: 'opening ${self.toHex()} is drawn off its stored '
              'position: $cause moved it',
          handles: [self, ...walls],
        ),
      for (var j = i + 1; j < all.openings.length; j++)
        if (all.cuts[j] case final other?
            when overlaps((cut.a, cut.b), (other.a, other.b)))
          Diagnostic(
            severity: DiagnosticSeverity.warning,
            code: 'opening.overlap',
            message: 'openings ${self.toHex()} and '
                '${all.openings[j].toHex()} overlap in wall ${host.toHex()}',
            handles: [self, all.openings[j]],
          ),
    ];
  }
}

/// Whether [w] is a width the tools and the panel may give an opening of
/// [kind] (spec 08 D6): finite and greater than `wallJoin.linear`, or than
/// `4 × wallJoin.linear` for a gap, whose threshold line is inset from each
/// jamb (D10). A loaded opening may still hold any width.
bool isOpeningWidth(OpeningKind kind, double w) =>
    w.isFinite &&
    w > (kind == OpeningKind.gap ? 4 * wallJoin.linear : wallJoin.linear);
