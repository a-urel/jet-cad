// Openings hosted in walls (spec 08 D1, D6): their parameters. No Flutter
// import. The geometry they are drawn and cut with is pure Dart, in
// `opening_geometry.dart`.
import 'package:jet_cad_2d/jet_cad_2d.dart';

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
/// - [diagnose] reports nothing yet: D17's codes come with Task 5.
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

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) => const [];
}

/// Whether [w] is a width the tools and the panel may give an opening of
/// [kind] (spec 08 D6): finite and greater than `wallJoin.linear`, or than
/// `4 × wallJoin.linear` for a gap, whose threshold line is inset from each
/// jamb (D10). A loaded opening may still hold any width.
bool isOpeningWidth(OpeningKind kind, double w) =>
    w.isFinite &&
    w > (kind == OpeningKind.gap ? 4 * wallJoin.linear : wallJoin.linear);
