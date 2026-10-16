// Two kits for the property panel (2a Task 17). The box kit's box.box is
// today's demo box (floor_plan/lib/src/parametric/box.dart: a rectangle
// whose outline loses what lies inside an overlapping box), drawn with B,
// with a field of every kind, a gate, an enabled rule, a title hook and a
// colour target. The disc kit's disc.disc is another component type (Review
// Focus 3), with an escape-hatch section that throws for a disc over 5 m,
// and a tool, D, whose settings set the next disc's radius.
import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Tolerance;
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

enum BoxFinish { matte, gloss }

/// The box's parameters, in mm and radians.
final class BoxParams implements Component {
  const BoxParams(this.width, this.height,
      {this.turn = 0,
      this.count = 1,
      this.finish = BoxFinish.matte,
      this.solid = false,
      this.label = '',
      this.colour});

  static const String componentTypeId = 'box.box';

  final double width;
  final double height;

  /// An angle field's subject; not drawn.
  final double turn;

  /// A number field's subject (one decimal); editable only while [solid].
  final double count;
  final BoxFinish finish;
  final bool solid;
  final String label;

  /// A swatch name, or null.
  final String? colour;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'colour': colour,
        'count': count,
        'finish': finish.name,
        'height': height,
        'label': label,
        'solid': solid,
        'turn': turn,
        'width': width,
      };

  static BoxParams fromJson(Map<String, Object?> json) => BoxParams(
        (json['width']! as num).toDouble(),
        (json['height']! as num).toDouble(),
        turn: (json['turn']! as num).toDouble(),
        count: (json['count']! as num).toDouble(),
        finish: BoxFinish.values.byName(json['finish']! as String),
        solid: json['solid']! as bool,
        label: json['label']! as String,
        colour: json['colour'] as String?,
      );

  BoxParams copyWith(
          {double? width,
          double? height,
          double? turn,
          double? count,
          BoxFinish? finish,
          bool? solid,
          String? label}) =>
      BoxParams(width ?? this.width, height ?? this.height,
          turn: turn ?? this.turn,
          count: count ?? this.count,
          finish: finish ?? this.finish,
          solid: solid ?? this.solid,
          label: label ?? this.label,
          colour: colour);

  BoxParams withColour(String? colour) => BoxParams(width, height,
      turn: turn,
      count: count,
      finish: finish,
      solid: solid,
      label: label,
      colour: colour);

  @override
  bool operator ==(Object other) =>
      other is BoxParams &&
      other.width == width &&
      other.height == height &&
      other.turn == turn &&
      other.count == count &&
      other.finish == finish &&
      other.solid == solid &&
      other.label == label &&
      other.colour == colour;

  @override
  int get hashCode =>
      Object.hash(width, height, turn, count, finish, solid, label, colour);
}

// BoxType, _corners, _insideInterval: floor_plan/lib/src/parametric/box.dart
// :35-124, unchanged.

List<Vector2> _corners(BoxParams p) => [
      Vector2(0, 0),
      Vector2(p.width, 0),
      Vector2(p.width, p.height),
      Vector2(0, p.height),
    ];

/// A rectangle whose outline loses what lies strictly inside any
/// overlapping box: overlapping boxes read as one outline, the wall
/// clean-up preview (spec 06 D13).
final class BoxType extends ParametricType<BoxParams> {
  const BoxType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(BoxParams params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final c in _corners(params)) toWorld.transformPoint(c)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<BoxParams>(self)!;
    final toLocal = view.toWorld(self).invert();
    final quads = [
      for (final n in view.neighbours(self))
        if (view.paramsOf<BoxParams>(n) case final q?)
          [
            for (final c in _corners(q))
              toLocal.transformPoint(view.toWorld(n).transformPoint(c)),
          ],
    ];
    final c = _corners(p);
    const tol = Tolerance.standard;
    final out = <Generated>[];
    for (var i = 0; i < 4; i++) {
      final a = c[i], b = c[(i + 1) % 4];
      final len = (b - a).length;
      var keep = <(double, double)>[(0, 1)];
      for (final q in quads) {
        final inside = _insideInterval(a, b, q);
        if (inside == null) continue;
        keep = [
          for (final (lo, hi) in keep) ...[
            if ((math.min(hi, inside.$1) - lo) * len > tol.linear)
              (lo, math.min(hi, inside.$1)),
            if ((hi - math.max(lo, inside.$2)) * len > tol.linear)
              (math.max(lo, inside.$2), hi),
          ],
        ];
      }
      for (final (lo, hi) in keep) {
        out.add(Generated(
            EntityKind.line, linePayload(a + (b - a) * lo, a + (b - a) * hi)));
      }
    }
    return out;
  }
}

/// The open parameter interval of a->b strictly inside the convex quad [q].
(double, double)? _insideInterval(Vector2 a, Vector2 b, List<Vector2> q) {
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
  return (hi - lo) * d.length > tol.linear ? (lo, hi) : null;
}

/// The box at [at] (its lower-left corner) in a group turned [turn] about
/// it: one step, labelled `Add box`; the group takes the current layer.
CompoundCommand boxCommand(
        DraftDocument doc, Handle h, Vector2 at, BoxParams params,
        {double turn = 0}) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.translation(at.x, at.y)
              .multiply(Transform2.rotation(turn)),
          children: const [])),
      SetComponentCommand<BoxParams>(h, params),
      SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(doc))),
    ], label: 'Add box');

/// floor_plan/lib/src/parametric/box_tool.dart:10-47: two opposite corners,
/// world-axis aligned, one box.
class BoxTool extends RectangleTool {
  BoxTool();

  @override
  String get name => 'Box';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final c1 = points.first;
    if (isDegenerateRectangle(c1, point)) return;
    commit(ctx, () {
      final doc = ctx.document;
      return boxCommand(
          doc,
          doc.handleSeed.next(),
          Vector2(math.min(c1.x, point.x), math.min(c1.y, point.y)),
          BoxParams((point.x - c1.x).abs(), (point.y - c1.y).abs()));
    }, needs: const {
      Capability.structure,
      Capability.components,
      Capability.geometry,
    });
    clearShape();
  }
}

final PlanType<BoxParams> boxType = PlanType<BoxParams>(
  id: BoxParams.componentTypeId,
  fromJson: BoxParams.fromJson,
  parametric: const BoxType(),
  properties: [
    LengthProperty<BoxParams>(
        id: 'width',
        read: (p) => p.width,
        write: (p, v) => p.copyWith(width: v),
        min: 1,
        gate: PlanGate.reshape),
    LengthProperty<BoxParams>(
        id: 'height',
        read: (p) => p.height,
        write: (p, v) => p.copyWith(height: v),
        min: 1,
        gate: PlanGate.reshape),
    AngleProperty<BoxParams>(
        id: 'turn', read: (p) => p.turn, write: (p, v) => p.copyWith(turn: v)),
    NumberProperty<BoxParams>(
        id: 'count',
        read: (p) => p.count,
        write: (p, v) => p.copyWith(count: v),
        min: 0,
        max: 99,
        decimals: 1,
        enabled: (p) => p.solid),
    ChoiceProperty<BoxParams, BoxFinish>(
        id: 'finish',
        values: BoxFinish.values,
        read: (p) => p.finish,
        write: (p, v) => p.copyWith(finish: v)),
    ToggleProperty<BoxParams>(
        id: 'solid',
        read: (p) => p.solid,
        write: (p, v) => p.copyWith(solid: v)),
    TextProperty<BoxParams>(
        id: 'label',
        read: (p) => p.label,
        write: (p, v) => p.copyWith(label: v),
        maxLength: 12),
    ValueDisplay<BoxParams>(
        id: 'area', read: (p) => p.width * p.height, unit: ValueUnit.area),
    ActionProperty<BoxParams>(
        id: 'swap', apply: (p) => p.copyWith(width: p.height, height: p.width)),
  ],
  title: (p) => p.solid ? 'type:box.box.solid' : 'type:box.box',
  colour: ColourTarget<BoxParams>(
      read: (p) => p.colour, write: (p, s) => p.withColour(s)),
);

final PlanKit boxKit = PlanKit(
  id: 'box',
  version: '1.0.0',
  types: [boxType],
  tools: [
    PlanTool(
        id: 'box.draw',
        icon: Icons.crop_din,
        letter: 'B',
        needs: const {
          Capability.structure,
          Capability.components,
          Capability.geometry,
        },
        create: (_) => BoxTool()),
  ],
  names: const KitNames({
    'en': {
      'type:box.box': 'Box',
      'type:box.box.solid': 'Solid box',
      'tool:box.draw': 'Box',
      'property:box.box.width': 'Width',
      'property:box.box.height': 'Height',
      'property:box.box.turn': 'Turn',
      'property:box.box.count': 'Count',
      'property:box.box.finish': 'Finish',
      'property:box.box.finish.matte': 'Matte',
      'property:box.box.finish.gloss': 'Gloss',
      'property:box.box.solid': 'Solid',
      'property:box.box.label': 'Label',
      'property:box.box.area': 'Area',
      'property:box.box.swap': 'Swap sides',
    },
    'tr': {'type:box.box': 'Kutu', 'property:box.box.width': 'Genişlik'},
  }),
);

/// The disc's parameters: a circle of [radius] about the group's origin.
final class DiscParams implements Component {
  const DiscParams(this.radius, {this.colour});

  static const String componentTypeId = 'disc.disc';

  final double radius;
  final String? colour;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'colour': colour, 'radius': radius};

  static DiscParams fromJson(Map<String, Object?> json) =>
      DiscParams((json['radius']! as num).toDouble(),
          colour: json['colour'] as String?);

  DiscParams withRadius(double radius) => DiscParams(radius, colour: colour);
  DiscParams withColour(String? colour) => DiscParams(radius, colour: colour);

  @override
  bool operator ==(Object other) =>
      other is DiscParams && other.radius == radius && other.colour == colour;

  @override
  int get hashCode => Object.hash(radius, colour);
}

final class DiscType extends ParametricType<DiscParams> {
  const DiscType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(DiscParams params, Transform2 toWorld) => Aabb2.fromPoints([
        for (final (x, y) in [(-1, -1), (1, -1), (1, 1), (-1, 1)])
          toWorld.transformPoint(Vector2(x * params.radius, y * params.radius)),
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<DiscParams>(self)!;
    return [
      Generated(EntityKind.circle, circlePayload(Vector2.zero(), p.radius))
    ];
  }
}

CompoundCommand discCommand(
        DraftDocument doc, Handle h, Vector2 at, DiscParams params) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.translation(at.x, at.y),
          children: const [])),
      SetComponentCommand<DiscParams>(h, params),
      SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(doc))),
    ], label: 'Add disc');

/// The disc tool's settings: the next disc's radius.
final class DiscToolSettings {
  const DiscToolSettings({this.radius = 400});

  final double radius;

  @override
  bool operator ==(Object other) =>
      other is DiscToolSettings && other.radius == radius;

  @override
  int get hashCode => radius.hashCode;
}

/// A click places one disc of the settings' radius there.
class DiscTool extends PlacementTool {
  DiscTool(this.services);

  final PlanServices services;

  @override
  String get name => 'Disc';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    final radius = services.settingsOf<DiscToolSettings>('disc.draw').radius;
    commit(ctx, () {
      final doc = ctx.document;
      return discCommand(doc, doc.handleSeed.next(), point, DiscParams(radius));
    }, needs: const {
      Capability.structure,
      Capability.components,
      Capability.geometry,
    });
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {}
}

final PlanType<DiscParams> discType = PlanType<DiscParams>(
  id: DiscParams.componentTypeId,
  fromJson: DiscParams.fromJson,
  parametric: const DiscType(),
  properties: [
    LengthProperty<DiscParams>(
        id: 'radius',
        read: (p) => p.radius,
        write: (p, v) => p.withRadius(v),
        min: 1),
  ],
  colour: ColourTarget<DiscParams>(
      read: (p) => p.colour, write: (p, s) => p.withColour(s)),
  section: (context, section) {
    final value = section.value;
    if (value.radius > 5000) throw StateError('a disc over 5 m');
    return OutlinedButton(
        key: const Key('disc-grow'),
        onPressed: () => section.commit(value.withRadius(value.radius * 2)),
        child: Text(section.words.word('property:disc.disc.grow')));
  },
);

final PlanKit discKit = PlanKit(
  id: 'disc',
  version: '1.0.0',
  types: [discType],
  tools: [
    PlanTool(
        id: 'disc.draw',
        icon: Icons.circle,
        letter: 'D',
        needs: const {
          Capability.structure,
          Capability.components,
          Capability.geometry,
        },
        settings: PlanToolSettings<DiscToolSettings>(
            initial: const DiscToolSettings(),
            specs: [
              LengthProperty<DiscToolSettings>(
                  id: 'radius',
                  read: (s) => s.radius,
                  write: (s, v) => DiscToolSettings(radius: v),
                  min: 1),
            ]),
        create: (services) => DiscTool(services)),
  ],
  names: const KitNames({
    'en': {
      'type:disc.disc': 'Disc',
      'tool:disc.draw': 'Disc',
      'property:disc.disc.radius': 'Radius',
      'property:disc.disc.grow': 'Grow',
      'property:disc.draw.radius': 'Radius',
    },
  }),
);

/// A controller over a 1:20 page anchored at (7000, 3000), grid snap off,
/// nothing drawn (`floor_plan/test/support/box_rig.dart:16-28`'s
/// `boxDoc`), with [kits] (the box kit by default).
PlanController boxController({List<PlanKit>? kits}) {
  final m = FlutterTextMeasurer();
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: false)));
  doc.commands.clearHistory();
  final json = ensureManifest(DraftDocumentCodec.encodeToString(doc));
  unawaited(doc.dispose());
  m.clear();
  final c = PlanController(kits: kits ?? [boxKit], json: json);
  addTearDown(c.dispose);
  return c;
}

/// One box on [c]'s plan, one step; its group's handle.
Handle addBox(PlanController c, Vector2 at, BoxParams params,
    {double turn = 0}) {
  final doc = c.document;
  final h = doc.handleSeed.next();
  doc.commands.execute(boxCommand(doc, h, at, params, turn: turn));
  return h;
}

/// One disc on [c]'s plan, one step; its group's handle.
Handle addDisc(PlanController c, Vector2 at, DiscParams params) {
  final doc = c.document;
  final h = doc.handleSeed.next();
  doc.commands.execute(discCommand(doc, h, at, params));
  return h;
}

/// [kits]' types in a catalog of their own, for `drift()`.
ParametricCatalog catalogOf(List<PlanKit> kits) {
  final catalog = ParametricCatalog();
  for (final kit in kits) {
    for (final t in kit.types) {
      t.registerInto(catalog);
    }
  }
  return catalog;
}
