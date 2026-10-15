// The object-view kit (3a Task 2, spec C1.1, C1.7): kit "view". A rail
// (view.rail) is a line along its group's x axis, of [length], with its
// label drawn as a TEXT child; its fields read that child's text and its
// world turn. A bead (view.bead) sits on a host rail: its position's range
// is read from the host's component, and its Flip shows for a door only,
// behind reshape. Placed off the origin in turned groups (CLAUDE.md).
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Tolerance;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

@immutable
final class RailComponent implements Component {
  const RailComponent(this.length, {this.label = ''});

  static const String componentTypeId = 'view.rail';

  final double length;
  final String label;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'label': label, 'length': length};

  static RailComponent fromJson(Map<String, Object?> json) =>
      RailComponent((json['length']! as num).toDouble(),
          label: json['label']! as String);

  @override
  bool operator ==(Object other) =>
      other is RailComponent && other.length == length && other.label == label;

  @override
  int get hashCode => Object.hash(length, label);
}

final class RailType extends ParametricType<RailComponent> {
  const RailType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(RailComponent p, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(0, -200)),
        toWorld.transformPoint(Vector2(p.length, 200)),
        toWorld.transformPoint(Vector2(0, 200)),
        toWorld.transformPoint(Vector2(p.length, -200)),
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<RailComponent>(self)!;
    return [
      Generated(
          EntityKind.line, linePayload(Vector2.zero(), Vector2(p.length, 0))),
      if (p.label.isNotEmpty)
        Generated.text(textPayload(Vector2(p.length / 2, 150), 120), p.label),
    ];
  }
}

/// The text of [o]'s first TEXT child, as drawn, or null without one.
String? childText(PlanObject o) {
  final entities = o.document.entities;
  for (final slot in entities.liveSlots) {
    if (entities.ownerAt(slot) == o.handle &&
        entities.kindAt(slot) == EntityKind.text) {
      return entities.textAt(slot);
    }
  }
  return null;
}

/// [o]'s world turn in degrees, one decimal, or null when it is not turned.
String? turnText(PlanObject o) {
  final w = o.world;
  final degrees = math.atan2(w.b, w.a) * 180 / math.pi;
  return degrees.abs() < 1e-9 ? null : '${degrees.toStringAsFixed(1)}°';
}

@immutable
final class BeadComponent implements Component {
  const BeadComponent(this.host, this.position,
      {this.door = true, this.flipped = false});

  static const String componentTypeId = 'view.bead';

  final Handle host;
  final double position;
  final bool door;
  final bool flipped;

  @override
  String get typeId => componentTypeId;

  BeadComponent copyWith({double? position, bool? door, bool? flipped}) =>
      BeadComponent(host, position ?? this.position,
          door: door ?? this.door, flipped: flipped ?? this.flipped);

  @override
  Map<String, Object?> toJson() => {
        'door': door,
        'flipped': flipped,
        'host': host.value,
        'position': position,
      };

  static BeadComponent fromJson(Map<String, Object?> json) => BeadComponent(
      Handle(json['host']! as int), (json['position']! as num).toDouble(),
      door: json['door']! as bool, flipped: json['flipped']! as bool);

  @override
  bool operator ==(Object other) =>
      other is BeadComponent &&
      other.host == host &&
      other.position == position &&
      other.door == door &&
      other.flipped == flipped;

  @override
  int get hashCode => Object.hash(host, position, door, flipped);
}

final class BeadType extends ParametricType<BeadComponent> {
  const BeadType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(BeadComponent p, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(-60, -60)),
        toWorld.transformPoint(Vector2(60, 60)),
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) =>
      [Generated(EntityKind.circle, circlePayload(Vector2.zero(), 50))];
}

/// The host rail's length bounds a bead's position; a host that is no
/// rail gives none (every position refused, today's opening on a non-wall).
(double, double)? hostRange(BeadComponent b, PlanObject o) {
  final rail = o.document.components.get<RailComponent>(b.host);
  return rail == null ? null : (0, rail.length);
}

final PlanType<RailComponent> railType = PlanType<RailComponent>(
  id: RailComponent.componentTypeId,
  fromJson: RailComponent.fromJson,
  parametric: const RailType(),
  properties: [
    LengthProperty<RailComponent>(
        id: 'length',
        read: (r) => r.length,
        write: (r, v) => RailComponent(v, label: r.label),
        min: 100),
    TextProperty<RailComponent>(
        id: 'label',
        read: (r) => r.label,
        write: (r, v) => RailComponent(r.length, label: v)),
    TextDisplay<RailComponent>(
        id: 'drawn', read: (r, o) => childText(o) ?? '—'),
    TextDisplay<RailComponent>(id: 'turn', read: (r, o) => turnText(o)),
    // R-P4: the kit's own words through the object.
    TextDisplay<RailComponent>(
        id: 'named', read: (r, o) => o.words.word('type:view.rail')),
  ],
  section: (context, section) => Text(
      '${section.services.words.word('type:view.rail')} '
      '${section.object.handle.value}',
      key: const Key('view-rail-section')),
);

final PlanType<BeadComponent> beadType = PlanType<BeadComponent>(
  id: BeadComponent.componentTypeId,
  fromJson: BeadComponent.fromJson,
  parametric: const BeadType(),
  properties: [
    LengthProperty<BeadComponent>(
        id: 'position',
        read: (b) => b.position,
        write: (b, v) => b.copyWith(position: v),
        range: hostRange),
    ActionProperty<BeadComponent>(
        id: 'flip',
        apply: (b) => b.copyWith(flipped: !b.flipped),
        visible: (b) => b.door,
        gate: PlanGate.reshape),
    ToggleProperty<BeadComponent>(
        id: 'door', read: (b) => b.door, write: (b, v) => b.copyWith(door: v)),
  ],
);

final PlanKit objectKit = PlanKit(
  id: 'view',
  version: '1.0.0',
  types: [railType, beadType],
  names: const KitNames({
    'en': {
      'type:view.rail': 'Rail',
      'type:view.bead': 'Bead',
      'property:view.rail.length': 'Length',
      'property:view.rail.label': 'Label',
      'property:view.rail.drawn': 'Drawn',
      'property:view.rail.turn': 'Turn',
      'property:view.rail.named': 'Named',
      'property:view.bead.position': 'Position',
      'property:view.bead.flip': 'Flip',
      'property:view.bead.door': 'Door',
    },
  }),
);

/// [component] in a root-level group at [at] turned [turn], on the drawing
/// layer: one step; its handle.
Handle addTurned<T extends Component>(
    DraftDocument d, T component, Vector2 at, double turn) {
  final h = d.handleSeed.next();
  d.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: d.rootHandle,
        transform: Transform2.translation(at.x, at.y)
            .multiply(Transform2.rotation(turn)),
        children: const [])),
    SetComponentCommand<T>(h, component),
    SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(d))),
  ], label: 'Add ${component.typeId}'));
  return h;
}
