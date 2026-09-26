import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room_inputs.dart';

/// A room separator's parameters (spec 10 D3): both ends in group-local
/// space, in mm. A free two-point line that splits a face as a
/// zero-thickness wall would.
///
/// Value-equal with exact `==` on the doubles: a stored value. `fromJson`
/// accepts anything well-typed; a separator no longer than
/// `roomTrace.linear`, or with an end that is not finite, is degenerate and
/// generates nothing.
final class SeparatorParams implements Component {
  const SeparatorParams(this.sx, this.sy, this.ex, this.ey);

  static const String componentTypeId = 'floor_planner.separator';

  final double sx, sy, ex, ey;

  Vector2 get start => Vector2(sx, sy);
  Vector2 get end => Vector2(ex, ey);

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'start': [sx, sy],
        'end': [ex, ey],
      };

  static SeparatorParams fromJson(Map<String, Object?> json) {
    final s = json['start']! as List;
    final e = json['end']! as List;
    return SeparatorParams((s[0] as num).toDouble(), (s[1] as num).toDouble(),
        (e[0] as num).toDouble(), (e[1] as num).toDouble());
  }

  SeparatorParams copyWith({Vector2? start, Vector2? end}) => SeparatorParams(
      start?.x ?? sx, start?.y ?? sy, end?.x ?? ex, end?.y ?? ey);

  @override
  bool operator ==(Object other) =>
      other is SeparatorParams &&
      other.sx == sx &&
      other.sy == sy &&
      other.ex == ex &&
      other.ey == ey;

  @override
  int get hashCode => Object.hash(sx, sy, ex, ey);

  @override
  String toString() => 'SeparatorParams(($sx, $sy) -> ($ex, $ey))';
}

/// The room separator (spec 10 D3): one dashed open polyline, and an input
/// to rooms (its world segment, D4).
///
/// Its `diagnose` is the default, nothing, until `separator.degenerate`
/// lands (spec 10 D22; Ruling 10-15).
final class SeparatorType extends ParametricType<SeparatorParams> {
  const SeparatorType();

  @override
  Capability get editCapability => Capability.geometry;

  /// Empty (spec 10 D3, R-2): a separator's input to rooms depends on its
  /// own parameters and transform only, so nothing reads it through the
  /// neighbour relation, and it is in no wall's neighbour list.
  @override
  Aabb2 reach(SeparatorParams params, Transform2 toWorld) => Aabb2.empty();

  @override
  bool get contributesPlace => true;

  /// The world box of [self]'s segment ([roomInputInView]), or null when it
  /// is degenerate.
  @override
  Aabb2? placeBox(ParametricView view, Handle self) =>
      placeBoxInView(view, self);

  /// [self]'s world segment, a [RoomInput]. The engine asks only when
  /// [placeBox] is not null; a fresh `Object()` otherwise counts as changed.
  @override
  Object placeInput(ParametricView view, Handle self) =>
      roomInputInView(view, self) ?? Object();

  /// One open two-point POLYLINE from `start` to `end` (spec 10 D3): colour
  /// ByLayer (the foreground on every paper), linetype
  /// [ReservedHandles.dashedLinetype] (D17) and lineweight 35, 0.35 mm
  /// (R-3), all written once on add (D13). Nothing for a degenerate
  /// separator, judged in world as its input is: a childless group.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    if (roomInputInView(view, self) == null) return const [];
    final p = view.paramsOf<SeparatorParams>(self)!;
    return [
      Generated(EntityKind.polyline, polylinePayload([p.start, p.end]),
          linetype: ReservedHandles.dashedLinetype, lineweight: 35),
    ];
  }
}

/// The DASHED linetype a separator draws with (spec 10 D3, R-4; Ruling
/// 10-14), on [ReservedHandles.dashedLinetype].
///
/// In model millimetres, because the painter scales a pattern by world to
/// screen: 4 mm and 2 mm on paper at 1:50, 2 mm and 1 mm at 1:100. It does
/// not follow the page scale.
const LinetypeRecord kDashedLinetypeRecord = LinetypeRecord(
  handle: ReservedHandles.dashedLinetype,
  name: 'DASHED',
  description: 'Dashed __ __ __',
  pattern: DashPattern(dashes: [200, -100], totalLength: 300),
);

/// Adds [kDashedLinetypeRecord] to [doc]'s linetypes, outside the history
/// (spec 10 D3): the sample plan and the test fixtures call it when they
/// make a document. `installParametric` does not: on a loaded file it would
/// change the document outside the history.
///
/// A no-op when [ReservedHandles.dashedLinetype] already holds a record,
/// whatever it is, and when another handle already carries the name
/// `DASHED` (the table's names are case-insensitive): that record is kept,
/// and a separator, which still names handle 6, draws continuous there.
void ensureDashedLinetype(DraftDocument doc) {
  final linetypes = doc.tables.linetypes;
  if (linetypes.contains(kDashedLinetypeRecord.handle)) return;
  if (linetypes.byName(kDashedLinetypeRecord.name) != null) return;
  linetypes.add(kDashedLinetypeRecord);
}
