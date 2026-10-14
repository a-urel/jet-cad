// Two small kits for the lock and failure-boundary tests (2a Tasks 10, 11):
// `box` (a square that contributes places, a stamp tool) and `ring` (a disc
// that reads places). Every hook of both types can be made to throw through
// one shared [Switches]: a per-object hook throws for an object whose
// params are `poisoned`, a type-level hook (a getter, `pageKey`, a factory)
// throws for every call. The scene sits off the origin, turned.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// What a switched hook throws.
final class HookBoom implements Exception {
  const HookBoom(this.hook);
  final String hook;
  @override
  String toString() => 'HookBoom($hook)';
}

/// The hooks made to throw, by name: `reach`, `references`, `generate`,
/// `diagnose`, `dissolves`, `placeBox`, `placeInput`, `readBox` (per object,
/// for a poisoned one); `editCapability`, `referencePolicy`, `pageKey`,
/// `contributesPlace`, `readsPlaces`, `create` (type level); `fromJson` (a
/// poisoned component's factory). Not a throw: `openRegion` makes a
/// poisoned square's `generate` add an open region, which the engine's
/// planner refuses outside any hook (an `ArgumentError`, no
/// KitHookFailure).
final class Switches {
  final Set<String> failing = {};

  /// Switches that act once, then turn themselves off (`openRegion`).
  final Set<String> once = {};

  /// Whether [name] is on for a poisoned object; a [once] switch is spent.
  bool takes(String name, bool poisoned) =>
      poisoned && (failing.contains(name) || once.remove(name));

  void check(String hook, [bool poisoned = true]) {
    if (poisoned && failing.contains(hook)) throw HookBoom(hook);
  }
}

@immutable
final class SquareParams implements Component {
  const SquareParams({required this.side, this.poisoned = false, this.partner});

  static const String id = 'box.square';

  final double side;
  final bool poisoned;

  /// An object this square references (a `cascade` referrer of it).
  final Handle? partner;

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() =>
      {'partner': partner?.value, 'poisoned': poisoned, 'side': side};

  static SquareParams fromJson(Map<String, Object?> json) => SquareParams(
      side: (json['side']! as num).toDouble(),
      poisoned: json['poisoned']! as bool,
      partner:
          json['partner'] == null ? null : Handle(json['partner']! as int));

  SquareParams copyWith({double? side, bool? poisoned}) => SquareParams(
      side: side ?? this.side,
      poisoned: poisoned ?? this.poisoned,
      partner: partner);

  @override
  bool operator ==(Object other) =>
      other is SquareParams &&
      other.side == side &&
      other.poisoned == poisoned &&
      other.partner == partner;

  @override
  int get hashCode => Object.hash(side, poisoned, partner);
}

@immutable
final class DiscParams implements Component {
  const DiscParams({required this.radius, this.poisoned = false});

  static const String id = 'ring.disc';

  final double radius;
  final bool poisoned;

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => {'poisoned': poisoned, 'radius': radius};

  static DiscParams fromJson(Map<String, Object?> json) => DiscParams(
      radius: (json['radius']! as num).toDouble(),
      poisoned: json['poisoned']! as bool);

  @override
  bool operator ==(Object other) =>
      other is DiscParams &&
      other.radius == radius &&
      other.poisoned == poisoned;

  @override
  int get hashCode => Object.hash(radius, poisoned);
}

/// A centred square of side [side] mapped by [toWorld], boxed.
Aabb2 squareBox(double side, Transform2 toWorld) {
  final h = side / 2;
  return Aabb2.fromPoints([
    for (final (x, y) in [(-h, -h), (h, -h), (h, h), (-h, h)])
      toWorld.transformPoint(Vector2(x, y)),
  ]);
}

/// A disc of [radius] at [toWorld]'s origin, boxed (the transforms here are
/// rigid).
Aabb2 discBox(double radius, Transform2 toWorld) {
  final c = toWorld.transformPoint(Vector2.zero());
  return Aabb2.fromPoints(
      [c - Vector2(radius, radius), c + Vector2(radius, radius)]);
}

final class SquareType extends ParametricType<SquareParams> {
  SquareType(this.sw);
  final Switches sw;

  bool _poisoned(ParametricView v, Handle h) =>
      v.paramsOf<SquareParams>(h)?.poisoned ?? false;

  @override
  Capability get editCapability {
    sw.check('editCapability');
    return Capability.geometry;
  }

  @override
  Aabb2 reach(SquareParams params, Transform2 toWorld) {
    sw.check('reach', params.poisoned);
    return squareBox(params.side, toWorld);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<SquareParams>(self)!;
    sw.check('generate', p.poisoned);
    final h = p.side / 2;
    final c = [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)];
    return [
      for (var i = 0; i < 4; i++)
        Generated(EntityKind.line, linePayload(c[i], c[(i + 1) % 4])),
      if (sw.takes('openRegion', p.poisoned))
        Generated.region(polylinePayload(c)),
    ];
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    sw.check('diagnose', _poisoned(view, self));
    return const [];
  }

  @override
  Iterable<Handle> references(SquareParams params) {
    sw.check('references', params.poisoned);
    final p = params.partner;
    return p == null ? const [] : [p];
  }

  @override
  ReferencePolicy get referencePolicy {
    sw.check('referencePolicy');
    return ReferencePolicy.cascade;
  }

  @override
  Object? pageKey(PageComponent? page) {
    sw.check('pageKey');
    return null;
  }

  @override
  bool dissolves(ParametricView view, Handle self) {
    sw.check('dissolves', _poisoned(view, self));
    return false;
  }

  @override
  bool get contributesPlace {
    sw.check('contributesPlace');
    return true;
  }

  @override
  Aabb2? placeBox(ParametricView view, Handle self) {
    final p = view.paramsOf<SquareParams>(self)!;
    sw.check('placeBox', p.poisoned);
    return squareBox(p.side, view.toWorld(self));
  }

  @override
  Object placeInput(ParametricView view, Handle self) {
    final p = view.paramsOf<SquareParams>(self)!;
    sw.check('placeInput', p.poisoned);
    final t = view.toWorld(self);
    return (p.side, t.a, t.b, t.c, t.d, t.e, t.f);
  }

  @override
  bool get readsPlaces {
    sw.check('readsPlaces');
    return false;
  }
}

final class DiscType extends ParametricType<DiscParams> {
  DiscType(this.sw);
  final Switches sw;

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(DiscParams params, Transform2 toWorld) {
    sw.check('reach', params.poisoned);
    return discBox(params.radius, toWorld);
  }

  /// A circle; it reads the squares placed over it (a place reader).
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<DiscParams>(self)!;
    sw.check('generate', p.poisoned);
    view.placedIn(discBox(p.radius, view.toWorld(self)));
    return [
      Generated(EntityKind.circle, circlePayload(Vector2.zero(), p.radius)),
    ];
  }

  @override
  bool get readsPlaces => true;

  @override
  Aabb2 readBox(DiscParams params, Transform2 toWorld, Aabb2 stored) {
    sw.check('readBox', params.poisoned);
    return discBox(params.radius, toWorld);
  }
}

/// A tool that does nothing; only its factory is switched.
final class StampTool extends Tool {
  @override
  String get name => 'stamp';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}
}

/// The `box` kit: the square, the stamp tool. [types] false leaves the
/// square out (a loaded kit that lacks a type the plan has).
PlanKit boxKit(Switches sw, {bool types = true}) => PlanKit(
      id: 'box',
      version: '1.4.0',
      types: [
        if (types)
          PlanType<SquareParams>(
              id: SquareParams.id,
              fromJson: (json) {
                final p = SquareParams.fromJson(json);
                sw.check('fromJson', p.poisoned);
                return p;
              },
              parametric: SquareType(sw)),
      ],
      tools: [
        PlanTool(
            id: 'box.stamp',
            icon: Icons.crop_square,
            create: (services) {
              sw.check('create');
              return StampTool();
            }),
      ],
      names: KitNames({
        'en': {
          if (types) 'type:box.square': 'Square',
          'tool:box.stamp': 'Stamp',
        },
      }),
    );

/// The `ring` kit: the disc.
PlanKit ringKit(Switches sw) => PlanKit(
      id: 'ring',
      version: '2.0.1',
      types: [
        PlanType<DiscParams>(
            id: DiscParams.id,
            fromJson: DiscParams.fromJson,
            parametric: DiscType(sw)),
      ],
      names: const KitNames({
        'en': {'type:ring.disc': 'Disc'},
      }),
    );

/// The square's placement: off the origin, turned by 30 degrees.
final Transform2 atSquare = Transform2.translation(7010, 3020)
    .multiply(Transform2.rotation(math.pi / 6));

/// A placement relative to [atSquare].
Transform2 nearSquare(double x, double y, double turn) => atSquare
    .multiply(Transform2.translation(x, y))
    .multiply(Transform2.rotation(turn));

/// Adds a root-level group carrying [params] at [at]; its handle.
Handle addObject<T extends Component>(
    DraftDocument d, Transform2 at, T params) {
  final h = d.handleSeed.next();
  d.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: d.rootHandle, transform: at, children: const [])),
    SetComponentCommand<T>(h, params),
  ], label: 'Add object'));
  return h;
}

/// A placed symbol of the `box` kit: a definition keyed `box.lamp.round`
/// holding one circle, and one instance of it at [at].
({Handle definition, Handle instance, Handle circle}) addLamp(
    DraftDocument d, Transform2 at) {
  final def = d.handleSeed.next();
  final circle = d.handleSeed.next();
  final instance = d.handleSeed.next();
  d.commands.execute(CompoundCommand([
    AddDefinitionCommand(Definition(
        handle: def,
        name: 'box.lamp.round@1',
        basePoint: Vector2.zero(),
        children: const [])),
    SetComponentCommand<SymbolComponent>(
        def,
        SymbolComponent(
            key: 'box.lamp.round',
            version: 1,
            name: 'Round lamp',
            category: 'Lighting',
            tags: const ['lamp'])),
    AddEntityCommand(
        record: draftRecord(circle, def, EntityKind.circle,
            layer: ReservedHandles.layerZero),
        payload: circlePayload(Vector2(12.5, -7.25), 150)),
    AddNodeCommand(InstanceNode(
        handle: instance,
        parent: d.rootHandle,
        transform: at,
        definition: def,
        layer: ReservedHandles.layerZero)),
  ], label: 'Place lamp'));
  return (definition: def, instance: instance, circle: circle);
}

/// Adds a root-level line; its handle.
Handle addLine(DraftDocument d, Vector2 a, Vector2 b) {
  final command = addDrafted(d, EntityKind.line, linePayload(a, b),
      layer: ReservedHandles.layerZero);
  d.commands.execute(command);
  return command.record.handle;
}

/// [owner]'s entities, ascending.
List<Handle> kids(DraftDocument d, Handle owner) => [
      for (final slot in d.entities.liveSlots)
        if (d.entities.ownerAt(slot) == owner) d.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// [owner]'s entities' coordinates, in handle order.
List<List<double>> coordsOf(DraftDocument d, Handle owner) => [
      for (final k in kids(d, owner))
        d.geometry
            .read(d.entities.geomIndexAt(d.entities.slotOf(k)!))
            .coords
            .toList(),
    ];

/// [d]'s encoding with the entities sorted by handle: slot order is
/// history, not state (as `jet_cad_2d/test/parametric/support/fixture.dart`
/// compares documents).
String canon(DraftDocument d) {
  final j = DraftDocumentCodec.encode(d);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  return jsonEncode(j);
}

/// The engine JSON of [typeId]'s components in the plan text [json], as
/// text: the bytes a save writes for that type.
String componentsText(String json, String typeId) =>
    jsonEncode(((jsonDecode(json) as Map)['components']! as Map)[typeId]);
