// SPIKE 10 -- throwaway. The room separator (decisions 11, 17): a free
// two-point line the tracer treats as a zero-thickness wall. Drawn dashed.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall.dart';

/// SPIKE: a reserved-range handle for the separator's DASHED linetype
/// (6..15 are below `ReservedHandles.firstFree` and unused). The spec must
/// decide how a type's linetype enters a document's tables.
const Handle kSeparatorLinetype = Handle(6);

/// Adds the DASHED linetype a separator draws with, once, straight into the
/// tables (not undoable: tables have no command).
void ensureSeparatorLinetype(DraftDocument doc) {
  if (doc.tables.linetypes.contains(kSeparatorLinetype)) return;
  doc.tables.linetypes.add(const LinetypeRecord(
    handle: kSeparatorLinetype,
    name: 'DASHED',
    description: 'Room separator __ __ __',
    // The painter scales a pattern by world-to-screen (times the entity's
    // and the header's linetype scales): these are model millimetres, 4 mm
    // and 2 mm on paper at 1:50. A paper-unit [6, -4] drew 1.2 px dashes at
    // 0.2 px/mm and the separator vanished (Q6).
    pattern: DashPattern(dashes: [200, -100], totalLength: 300),
  ));
}

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

  @override
  bool operator ==(Object other) =>
      other is SeparatorParams &&
      other.sx == sx &&
      other.sy == sy &&
      other.ex == ex &&
      other.ey == ey;

  @override
  int get hashCode => Object.hash(sx, sy, ex, ey);
}

/// The separator: one dashed open polyline, its own group at the identity.
final class SeparatorType extends ParametricType<SeparatorParams> {
  const SeparatorType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(SeparatorParams params, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(params.start),
        toWorld.transformPoint(params.end),
      ]).expandedBy(wallJoin.linear);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<SeparatorParams>(self)!;
    return [
      Generated(EntityKind.polyline, polylinePayload([p.start, p.end]),
          linetype: kSeparatorLinetype,
          // 0.35 mm: an exactly axis-aligned default hairline can fall
          // between pixel centres and vanish in the test rasteriser (Q6).
          lineweight: 35),
    ];
  }
}
