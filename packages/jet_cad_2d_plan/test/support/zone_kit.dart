// The zone kit (POS-host Task 4): kit "zone", one type zone.area, a
// rectangle [w] x [h] from its group's origin, which declares itself as an
// area (spec D11) through its group's world transform: turned, mirrored or
// off the origin, its outline is the transformed corners, anticlockwise.
// [zoneAreaCalls] counts the area capability's calls.
import 'package:flutter/foundation.dart' show immutable;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

@immutable
final class ZoneComponent implements Component {
  const ZoneComponent(this.w, this.h, [this.name = '']);

  static const String componentTypeId = 'zone.area';

  final double w, h;

  /// The zone's own name; empty for none.
  final String name;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() =>
      {'h': h, if (name.isNotEmpty) 'name': name, 'w': w};

  static ZoneComponent fromJson(Map<String, Object?> json) => ZoneComponent(
      (json['w']! as num).toDouble(),
      (json['h']! as num).toDouble(),
      (json['name'] as String?) ?? '');

  @override
  bool operator ==(Object other) =>
      other is ZoneComponent &&
      other.w == w &&
      other.h == h &&
      other.name == name;

  @override
  int get hashCode => Object.hash(w, h, name);
}

final class ZoneType extends ParametricType<ZoneComponent> {
  const ZoneType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(ZoneComponent p, Transform2 toWorld) => Aabb2.fromPoints([
        for (final c in [
          Vector2(0, 0),
          Vector2(p.w, 0),
          Vector2(p.w, p.h),
          Vector2(0, p.h)
        ])
          toWorld.transformPoint(c)
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<ZoneComponent>(self)!;
    return [
      Generated(EntityKind.line, linePayload(Vector2(0, 0), Vector2(p.w, 0))),
      Generated(
          EntityKind.line, linePayload(Vector2(p.w, 0), Vector2(p.w, p.h))),
      Generated(
          EntityKind.line, linePayload(Vector2(p.w, p.h), Vector2(0, p.h))),
      Generated(EntityKind.line, linePayload(Vector2(0, p.h), Vector2(0, 0))),
    ];
  }
}

/// How many times the area capability ran.
int zoneAreaCalls = 0;

final PlanType<ZoneComponent> zoneType = PlanType<ZoneComponent>(
  id: ZoneComponent.componentTypeId,
  fromJson: ZoneComponent.fromJson,
  parametric: const ZoneType(),
  name: (z) => z.name,
  area: (z, o) {
    zoneAreaCalls++;
    // A zone with no width has no area now.
    if (z.w <= 0) return null;
    final ring = [
      for (final c in [
        Vector2(0, 0),
        Vector2(z.w, 0),
        Vector2(z.w, z.h),
        Vector2(0, z.h)
      ])
        o.world.transformPoint(c)
    ];
    // Mirrored: reversed, so the outline stays anticlockwise.
    return o.world.determinant < 0 ? ring.reversed.toList() : ring;
  },
);

final PlanKit zoneKit = PlanKit(
  id: 'zone',
  version: '1.0.0',
  types: [zoneType],
  names: const KitNames({
    'en': {'type:zone.area': 'Zone'},
  }),
);

/// A [ZoneComponent] of [w] x [h] in a root group placed by [world], on the
/// drawing layer: one step; its handle.
Handle addZone(DraftDocument d, double w, double h, Transform2 world,
    [String name = '']) {
  final handle = d.handleSeed.next();
  d.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: handle,
        parent: d.rootHandle,
        transform: world,
        children: const [])),
    SetComponentCommand<ZoneComponent>(handle, ZoneComponent(w, h, name)),
    SetComponentCommand<ObjectLayer>(handle, ObjectLayer(drawingLayer(d))),
  ], label: 'Add zone'));
  return handle;
}
