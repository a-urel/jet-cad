// The test kit of the plan library (spec 2a "Tests"): one parametric type,
// `test.slab`, with all eight property kinds, a gate, a title hook, a
// colour target, grips and an escape-hatch section; one tool with
// settings; a `test-edge` attachment provider; English and Turkish words,
// no German (the fallback).
// With `units: true` (`unitKit()`, 2b Task 5) it also carries a symbol
// library (a numbered table of four, an assigned seat, a booth of six
// whose kind only the kit names), the parametric row `test.row` that
// generates labelled seats through E5, its tool, and the words they need.
// `discKit` gives a second kit whose type has another component type (the
// covariance tests); `conflictKit` a type that
// both contributes and reads places (the kit-set refusal).
//
// Fixtures sit off the origin, turned, with non-default attributes
// (CLAUDE.md): a slab's outline is turned by its own `angle` inside a group
// placed by translation.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Tolerance;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show
        Catalog,
        CatalogLine,
        CatalogPolyline,
        CatalogSymbol,
        CatalogUnit,
        encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

const String slabTypeId = 'test.slab';
const String slabToolId = 'test.slab';
const String discTypeId = 'disc.round';
const String readerTypeId = 'test.reader';
const String testEdgeKind = 'test-edge';

/// What the kits' factories made and disposed, in order: `tool+1`,
/// `cache+1`, `grips+1`, ..., `tool-1`. A serial per kind of product.
final class KitLog {
  final List<String> events = [];
  final Map<String, int> _serials = {};

  /// Logs `<what>+<n>` and returns `n`, this product's serial.
  int created(String what) {
    final n = (_serials[what] ?? 0) + 1;
    _serials[what] = n;
    events.add('$what+$n');
    return n;
  }

  void disposed(String what, int serial) => events.add('$what-$serial');
}

// ---------------------------------------------------------------------------
// The slab.

/// A rectangle [width] x [height] (mm) centred on its group's origin and
/// turned by [angle] (radians), with the attributes the eight property
/// kinds edit.
@immutable
final class SlabComponent implements Component {
  SlabComponent({
    required this.width,
    required this.height,
    this.angle = 0,
    this.thickness = 120,
    this.finish = 'plain',
    this.labelled = false,
    this.label = '',
    this.flipped = false,
    this.swatch,
  }) {
    if (!width.isFinite || width <= 0) {
      throw ArgumentError.value(width, 'width', 'must be finite and above 0');
    }
    if (!height.isFinite || height <= 0) {
      throw ArgumentError.value(height, 'height', 'must be finite and above 0');
    }
    if (!angle.isFinite) {
      throw ArgumentError.value(angle, 'angle', 'must be finite');
    }
  }

  static const String componentTypeId = slabTypeId;

  final double width;
  final double height;
  final double angle;
  final double thickness;
  final String finish;
  final bool labelled;
  final String label;
  final bool flipped;
  final String? swatch;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'angle': angle,
        'finish': finish,
        'flipped': flipped,
        'height': height,
        'label': label,
        'labelled': labelled,
        'swatch': swatch,
        'thickness': thickness,
        'width': width,
      };

  static SlabComponent fromJson(Map<String, Object?> json) => SlabComponent(
        width: (json['width']! as num).toDouble(),
        height: (json['height']! as num).toDouble(),
        angle: ((json['angle'] as num?) ?? 0).toDouble(),
        thickness: ((json['thickness'] as num?) ?? 120).toDouble(),
        finish: json['finish'] as String? ?? 'plain',
        labelled: json['labelled'] as bool? ?? false,
        label: json['label'] as String? ?? '',
        flipped: json['flipped'] as bool? ?? false,
        swatch: json['swatch'] as String?,
      );

  SlabComponent copyWith({
    double? width,
    double? height,
    double? angle,
    double? thickness,
    String? finish,
    bool? labelled,
    String? label,
    bool? flipped,
  }) =>
      SlabComponent(
        width: width ?? this.width,
        height: height ?? this.height,
        angle: angle ?? this.angle,
        thickness: thickness ?? this.thickness,
        finish: finish ?? this.finish,
        labelled: labelled ?? this.labelled,
        label: label ?? this.label,
        flipped: flipped ?? this.flipped,
        swatch: swatch,
      );

  /// This slab in the plan's swatch [swatch] (null: none).
  SlabComponent withSwatch(String? swatch) => SlabComponent(
        width: width,
        height: height,
        angle: angle,
        thickness: thickness,
        finish: finish,
        labelled: labelled,
        label: label,
        flipped: flipped,
        swatch: swatch,
      );

  @override
  bool operator ==(Object other) =>
      other is SlabComponent &&
      other.width == width &&
      other.height == height &&
      other.angle == angle &&
      other.thickness == thickness &&
      other.finish == finish &&
      other.labelled == labelled &&
      other.label == label &&
      other.flipped == flipped &&
      other.swatch == swatch;

  @override
  int get hashCode => Object.hash(width, height, angle, thickness, finish,
      labelled, label, flipped, swatch);

  @override
  String toString() => 'SlabComponent($width x $height @ $angle)';
}

/// The slab's corners in its group's space, counter-clockwise.
List<Vector2> slabCorners(SlabComponent s) {
  final c = math.cos(s.angle), n = math.sin(s.angle);
  final hw = s.width / 2, hh = s.height / 2;
  return [
    for (final (x, y) in [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)])
      Vector2(x * c - y * n, x * n + y * c),
  ];
}

/// The slab's engine type: its outline, one closed polyline.
final class SlabType extends ParametricType<SlabComponent> {
  const SlabType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(SlabComponent params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final c in slabCorners(params)) toWorld.transformPoint(c)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<SlabComponent>(self)!;
    return [
      Generated(
          EntityKind.polyline, polylinePayload(slabCorners(p), closed: true)),
    ];
  }
}

/// What the slab tool and the slab grips share, through
/// `PlanServices.shared`: one per document.
final class SlabCache implements Disposable {
  SlabCache({this.log}) : serial = log?.created('cache') ?? 0;

  final KitLog? log;
  final int serial;
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    log?.disposed('cache', serial);
  }
}

/// One stretch grip, at the middle of the slab's right edge; dragging it
/// sets the width to twice the drop's distance along the slab's axis.
final class SlabGrips implements ObjectGripProvider, Disposable {
  SlabGrips(this.cache, {this.log}) : serial = log?.created('grips') ?? 0;

  final SlabCache cache;
  final KitLog? log;
  final int serial;

  static Transform2? _toWorld(DraftDocument d, Handle group) {
    final node = d.tree[group];
    return node is GroupNode ? node.transform : null;
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    final s = d.components.get<SlabComponent>(group);
    final t = _toWorld(d, group);
    if (s == null || t == null) return const [];
    final p = t.transformPoint(Vector2(
        math.cos(s.angle) * s.width / 2, math.sin(s.angle) * s.width / 2));
    return [Grip(GripRole.stretch, 0, p.x, p.y)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final s = d.components.get<SlabComponent>(group);
    final t = _toWorld(d, group);
    if (s == null || t == null) return null;
    final local = t.invert().transformPoint(world);
    final width =
        2 * (local.x * math.cos(s.angle) + local.y * math.sin(s.angle));
    if (width <= Tolerance.standard.linear) return null;
    return SetComponentCommand<SlabComponent>(group, s.copyWith(width: width));
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final command = drag(d, group, grip, world);
    if (command is! SetComponentCommand<SlabComponent>) return const [];
    final t = _toWorld(d, group)!;
    return [
      (
        EntityKind.polyline,
        polylinePayload(
            [for (final c in slabCorners(command.value!)) t.transformPoint(c)],
            closed: true)
      ),
    ];
  }

  @override
  bool movable(DraftDocument d, Handle group) => true;

  @override
  void dispose() => log?.disposed('grips', serial);
}

/// The slab tool's settings: the size of the next slab, in mm.
@immutable
final class SlabSettings {
  const SlabSettings({required this.width, required this.height});

  final double width;
  final double height;

  SlabSettings copyWith({double? width, double? height}) =>
      SlabSettings(width: width ?? this.width, height: height ?? this.height);

  @override
  bool operator ==(Object other) =>
      other is SlabSettings && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Two presses: the first anchors the slab's centre, the second turns it
/// towards the press and commits a slab of the tool's settings' size.
final class SlabTool extends PlacementTool {
  SlabTool(this.services, {this.log})
      : cache = services.shared<SlabCache>((_) => SlabCache(log: log)),
        serial = log?.created('tool') ?? 0;

  final PlanServices services;
  final KitLog? log;
  final SlabCache cache;
  final int serial;

  @override
  String get name => 'Slab';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final start = points.first;
    final d = point - start;
    if (d.length <= Tolerance.standard.linear) return;
    final size = services.settingsOf<SlabSettings>(slabToolId);
    commit(
        ctx,
        () => placeObjectCommand<SlabComponent>(
            ctx.document,
            SlabComponent(
                width: size.width,
                height: size.height,
                angle: math.atan2(d.y, d.x)),
            at: start),
        needs: const {
          Capability.structure,
          Capability.components,
          Capability.geometry,
        });
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {}

  @override
  void dispose() {
    log?.disposed('tool', serial);
    super.dispose();
  }
}

/// The slab's eight property kinds: two lengths, an angle gated by
/// `rotate`, a number, a choice, a toggle, a text enabled only while
/// labelled, the area shown, and a flip.
List<PropertySpec<SlabComponent>> slabProperties() => [
      LengthProperty<SlabComponent>(
          id: 'width',
          read: (s) => s.width,
          write: (s, v) => s.copyWith(width: v),
          min: 100,
          max: 20000),
      LengthProperty<SlabComponent>(
          id: 'height',
          read: (s) => s.height,
          write: (s, v) => s.copyWith(height: v),
          min: 100,
          max: 20000),
      AngleProperty<SlabComponent>(
          id: 'angle',
          read: (s) => s.angle,
          write: (s, v) => s.copyWith(angle: v),
          gate: PlanGate.rotate),
      NumberProperty<SlabComponent>(
          id: 'thickness',
          read: (s) => s.thickness,
          write: (s, v) => s.copyWith(thickness: v),
          min: 1,
          max: 500,
          decimals: 1),
      ChoiceProperty<SlabComponent, String>(
          id: 'finish',
          values: const ['plain', 'tiled', 'polished'],
          read: (s) => s.finish,
          write: (s, v) => s.copyWith(finish: v)),
      ToggleProperty<SlabComponent>(
          id: 'labelled',
          read: (s) => s.labelled,
          write: (s, v) => s.copyWith(labelled: v)),
      TextProperty<SlabComponent>(
          id: 'label',
          read: (s) => s.label,
          write: (s, v) => s.copyWith(label: v),
          maxLength: 24,
          enabled: (s) => s.labelled),
      ValueDisplay<SlabComponent>(
          id: 'area', read: (s) => s.width * s.height, unit: ValueUnit.area),
      ActionProperty<SlabComponent>(
          id: 'flip', apply: (s) => s.copyWith(flipped: !s.flipped)),
    ];

/// The slab tool's settings' specs; their words are the slab's own
/// (`property:test.slab.width`, `property:test.slab.height`).
List<PropertySpec<SlabSettings>> slabSettingSpecs() => [
      LengthProperty<SlabSettings>(
          id: 'width',
          read: (s) => s.width,
          write: (s, v) => s.copyWith(width: v),
          min: 100,
          max: 20000),
      LengthProperty<SlabSettings>(
          id: 'height',
          read: (s) => s.height,
          write: (s, v) => s.copyWith(height: v),
          min: 100,
          max: 20000),
    ];

/// The escape hatch: one button that widens the slab by 250 mm.
Widget slabSection(BuildContext context, PlanSection<SlabComponent> section) =>
    TextButton(
        key: const Key('test-slab-widen'),
        onPressed: () => section
            .commit(section.value.copyWith(width: section.value.width + 250)),
        child: Text(section.words.word('property:test.slab.widen')));

/// A flipped slab's section is titled by another word.
String slabTitle(SlabComponent s) =>
    s.flipped ? 'type:test.slab.flipped' : 'type:test.slab';

PlanType<SlabComponent> slabType({KitLog? log}) => PlanType<SlabComponent>(
      id: slabTypeId,
      fromJson: SlabComponent.fromJson,
      parametric: const SlabType(),
      grips: (services) => SlabGrips(
          services.shared<SlabCache>((_) => SlabCache(log: log)),
          log: log),
      properties: slabProperties(),
      section: slabSection,
      title: slabTitle,
      colour: ColourTarget<SlabComponent>(
          read: (s) => s.swatch, write: (s, swatch) => s.withSwatch(swatch)),
    );

PlanTool slabTool({KitLog? log}) => PlanTool(
      id: slabToolId,
      icon: Icons.crop_square,
      letter: 'S',
      needs: const {
        Capability.structure,
        Capability.components,
        Capability.geometry,
      },
      settings: PlanToolSettings<SlabSettings>(
          initial: const SlabSettings(width: 1200, height: 600),
          specs: slabSettingSpecs()),
      create: (services) => SlabTool(services, log: log),
    );

// ---------------------------------------------------------------------------
// The test edge.

/// A horizontal edge at world [y], of kind [kind]: a symbol whose pointer
/// comes within `capture` of it (within `edgeCapture` while it is already
/// attached here, `keep`) sits unturned with its local `minY` on the edge,
/// mirrored when asked. With `mayRotate` false it attaches only a symbol
/// whose turn already fits (unturned, or the plain mirror).
class TestEdge implements AttachmentProvider, Disposable {
  TestEdge({this.kind = testEdgeKind, this.y = 3000, this.log})
      : serial = log?.created('edge') ?? 0;

  @override
  final String kind;
  final double y;
  final KitLog? log;
  final int serial;

  @override
  Attachment? attach(AttachmentQuery query) {
    final kept = identical(query.keep?.token, this);
    final reach = kept ? query.edgeCapture : query.capture;
    if ((query.pointer.y - y).abs() > reach) return null;
    final x = query.mirrored ? -1.0 : 1.0;
    if (!query.mayRotate) {
      final t = query.current;
      const tol = Tolerance.standard;
      if ((t.a - x).abs() > tol.angular || t.b.abs() > tol.angular) {
        return null;
      }
    }
    return Attachment(
        transform:
            Transform2(x, 0, 0, 1, query.pointer.x, y - query.footprint.minY),
        marker: Vector2(query.pointer.x, y),
        token: this);
  }

  @override
  void dispose() => log?.disposed('edge', serial);
}

// ---------------------------------------------------------------------------
// The test kit's words.

const KitNames testWords = KitNames({
  'en': {
    'type:test.slab': 'Slab',
    'type:test.slab.flipped': 'Flipped slab',
    'tool:test.slab': 'Slab',
    'property:test.slab.width': 'Width',
    'property:test.slab.height': 'Height',
    'property:test.slab.angle': 'Angle',
    'property:test.slab.thickness': 'Thickness',
    'property:test.slab.finish': 'Finish',
    'property:test.slab.finish.plain': 'Plain',
    'property:test.slab.finish.tiled': 'Tiled',
    'property:test.slab.finish.polished': 'Polished',
    'property:test.slab.labelled': 'Labelled',
    'property:test.slab.label': 'Label',
    'property:test.slab.area': 'Area',
    'property:test.slab.flip': 'Flip',
    'property:test.slab.widen': 'Widen',
  },
  'tr': {
    'type:test.slab': 'Döşeme',
    'type:test.slab.flipped': 'Ters döşeme',
    'tool:test.slab': 'Döşeme',
    'property:test.slab.width': 'Genişlik',
    'property:test.slab.height': 'Yükseklik',
    'property:test.slab.angle': 'Açı',
    'property:test.slab.thickness': 'Kalınlık',
    'property:test.slab.finish': 'Kaplama',
    'property:test.slab.finish.plain': 'Düz',
    'property:test.slab.finish.tiled': 'Fayanslı',
    'property:test.slab.finish.polished': 'Cilalı',
    'property:test.slab.labelled': 'Etiketli',
    'property:test.slab.label': 'Etiket',
    'property:test.slab.area': 'Alan',
    'property:test.slab.flip': 'Çevir',
    'property:test.slab.widen': 'Genişlet',
  },
});

/// The test kit: one type, one tool, one provider; a fresh descriptor per
/// call. [log] records its factories' products. With [units], also the
/// unit library, the row type and its tool, and their words (2b).
PlanKit testKit({String version = '1.2.0', KitLog? log, bool units = false}) =>
    PlanKit(
      id: 'test',
      version: version,
      symbols: [
        if (units)
          SymbolLibrarySource(
              label: 'test units', read: () async => testUnitLibraryBytes()),
      ],
      types: [slabType(log: log), if (units) rowType()],
      tools: [slabTool(log: log), if (units) rowTool()],
      attachments: [(services) => TestEdge(log: log)],
      names: units ? testWords.merge(testUnitWords) : testWords,
    );

/// The test kit with its units (2b): `testKit(units: true)`.
PlanKit unitKit({KitLog? log}) => testKit(log: log, units: true);

// ---------------------------------------------------------------------------
// The disc kit: another component type, for the covariance tests.

@immutable
final class DiscComponent implements Component {
  DiscComponent({required this.radius, this.swatch}) {
    if (!radius.isFinite || radius <= 0) {
      throw ArgumentError.value(radius, 'radius', 'must be finite and above 0');
    }
  }

  static const String componentTypeId = discTypeId;

  final double radius;
  final String? swatch;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'radius': radius, 'swatch': swatch};

  static DiscComponent fromJson(Map<String, Object?> json) => DiscComponent(
      radius: (json['radius']! as num).toDouble(),
      swatch: json['swatch'] as String?);

  DiscComponent copyWith({double? radius}) =>
      DiscComponent(radius: radius ?? this.radius, swatch: swatch);

  DiscComponent withSwatch(String? swatch) =>
      DiscComponent(radius: radius, swatch: swatch);

  @override
  bool operator ==(Object other) =>
      other is DiscComponent &&
      other.radius == radius &&
      other.swatch == swatch;

  @override
  int get hashCode => Object.hash(radius, swatch);
}

/// A 24-gon of the disc's radius, centred on its group's origin.
List<Vector2> discOutline(DiscComponent d) => [
      for (var i = 0; i < 24; i++)
        Vector2(d.radius * math.cos(i * math.pi / 12),
            d.radius * math.sin(i * math.pi / 12)),
    ];

final class DiscType extends ParametricType<DiscComponent> {
  const DiscType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(DiscComponent params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final p in discOutline(params)) toWorld.transformPoint(p)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<DiscComponent>(self)!;
    return [
      Generated(
          EntityKind.polyline, polylinePayload(discOutline(p), closed: true)),
    ];
  }
}

const KitNames discWords = KitNames({
  'en': {
    'type:disc.round': 'Round disc',
    'property:disc.round.radius': 'Radius',
  },
});

PlanKit discKit({String version = '0.4.0'}) => PlanKit(
      id: 'disc',
      version: version,
      types: [
        PlanType<DiscComponent>(
          id: discTypeId,
          fromJson: DiscComponent.fromJson,
          parametric: const DiscType(),
          properties: [
            LengthProperty<DiscComponent>(
                id: 'radius',
                read: (d) => d.radius,
                write: (d, v) => d.copyWith(radius: v),
                min: 50,
                max: 10000),
          ],
          colour: ColourTarget<DiscComponent>(
              read: (d) => d.swatch,
              write: (d, swatch) => d.withSwatch(swatch)),
        ),
      ],
      names: discWords,
    );

// ---------------------------------------------------------------------------
// The conflict kit: a type the engine refuses (spec 10 D16).

@immutable
final class ReaderComponent implements Component {
  const ReaderComponent(this.size);

  static const String componentTypeId = readerTypeId;

  final double size;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'size': size};

  static ReaderComponent fromJson(Map<String, Object?> json) =>
      ReaderComponent((json['size']! as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is ReaderComponent && other.size == size;

  @override
  int get hashCode => size.hashCode;
}

/// Both contributes places and reads them: `ParametricCatalog.register`
/// throws for it (`parametric_system.dart:497-505`).
final class ReaderType extends ParametricType<ReaderComponent> {
  const ReaderType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  bool get contributesPlace => true;

  @override
  bool get readsPlaces => true;

  @override
  Aabb2 reach(ReaderComponent params, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(0, 0)),
        toWorld.transformPoint(Vector2(params.size, params.size)),
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];
}

PlanKit conflictKit() => PlanKit(
      id: 'test',
      version: '1.0.0',
      types: [
        PlanType<ReaderComponent>(
            id: readerTypeId,
            fromJson: ReaderComponent.fromJson,
            parametric: const ReaderType()),
      ],
      names: const KitNames({
        'en': {'type:test.reader': 'Reader'},
      }),
    );

// ---------------------------------------------------------------------------
// The units (2b): the symbols, the row, its tool, its words.

const String rowTypeId = 'test.row';
const String rowToolId = 'test.row';

/// The seat a row generates.
const String rowSeatKey = 'test.seat.basic.one@1';

/// The placed, numbered table of four.
const String tableSymbolId = 'test.table.square.four@1';

/// The booth of six: a kind the contract does not name.
const String boothSymbolId = 'test.booth.corner.six@1';

/// The row tool's row: six seats, 600 mm apart, straight.
const int kRowToolSeats = 6;
const double kRowToolSpacing = 600;

/// The unit library, kit `test`. Each unit draws its top first (K3 rule
/// 11); every base point is off the frame's origin.
final Catalog testUnitCatalog = Catalog(kit: 'test', symbols: [
  CatalogSymbol(
    key: 'test.table.square.four',
    name: 'Square table',
    category: 'Tests',
    tags: const ['table', 'square'],
    unit: const CatalogUnit(kind: UnitKinds.table, capacity: 4),
    base: (600, 600),
    shapes: const [
      CatalogPolyline([(150, 150), (1050, 150), (1050, 1050), (150, 1050)],
          closed: true),
      CatalogPolyline([(375, -150), (825, -150), (825, 100), (375, 100)],
          closed: true),
      CatalogPolyline([(375, 1100), (825, 1100), (825, 1350), (375, 1350)],
          closed: true),
      CatalogPolyline([(-150, 375), (100, 375), (100, 825), (-150, 825)],
          closed: true),
      CatalogPolyline([(1100, 375), (1350, 375), (1350, 825), (1100, 825)],
          closed: true),
    ],
  ),
  CatalogSymbol(
    key: 'test.seat.basic.one',
    name: 'Seat',
    category: 'Tests',
    tags: const ['seat'],
    unit: const CatalogUnit(
        kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned),
    base: (250, 265),
    shapes: const [
      CatalogPolyline([(25, 40), (475, 40), (475, 490), (25, 490)],
          closed: true),
      CatalogLine((25, 440), (475, 440)),
    ],
  ),
  CatalogSymbol(
    key: 'test.booth.corner.six',
    name: 'Corner booth',
    category: 'Tests',
    tags: const ['booth'],
    unit: const CatalogUnit(kind: 'booth', capacity: 6),
    base: (400, 400),
    shapes: const [
      CatalogPolyline([
        (100, 100),
        (1700, 100),
        (1700, 700),
        (700, 700),
        (700, 1500),
        (100, 1500)
      ], closed: true),
      CatalogLine((300, 300), (1500, 300)),
    ],
  ),
]);

Uint8List testUnitLibraryBytes() => encodeLibrary(testUnitCatalog);

/// The units' words: the row in English and Turkish, the symbols and their
/// category in Turkish (their English is the catalog's), the booth's kind in
/// English only (spec S4 "Words": the English fallback).
const KitNames testUnitWords = KitNames({
  'en': {
    'type:test.row': 'Row',
    'tool:test.row': 'Row',
    'unit:test/booth': 'Booth',
  },
  'tr': {
    'type:test.row': 'Sıra',
    'tool:test.row': 'Sıra',
    'symbol:test.table.square.four': 'Kare masa',
    'symbol:test.seat.basic.one': 'Koltuk',
    'symbol:test.booth.corner.six': 'Köşe loca',
    'category:test/Tests': 'Testler',
  },
});

/// A row of [count] seats of the definition [seat] (its [base] point and
/// [top] box, from `PlanServices.symbolDefinition`), [spacing] mm apart,
/// turning [curve] radians a seat, labelled `<prefix>1` to `<prefix>N`.
@immutable
final class RowComponent implements Component {
  /// Throws [ArgumentError] for a prefix over 8 code units or with a
  /// control character, a count outside 1 to 999, a spacing that is not
  /// finite and above 0, a curve that is not finite or reaches ±π, and a
  /// base point that is not finite.
  RowComponent({
    required this.prefix,
    required this.count,
    required this.spacing,
    this.curve = 0,
    required this.seat,
    required Vector2 base,
    required this.top,
  }) : base = Vector2.copy(base) {
    if (prefix.length > 8 ||
        prefix.codeUnits.any((u) => u < 0x20 || (u >= 0x7F && u <= 0x9F))) {
      throw ArgumentError.value(prefix, 'prefix',
          'must be at most 8 code units, no control character');
    }
    if (count < 1 || count > 999) {
      throw ArgumentError.value(count, 'count', 'must be 1 to 999');
    }
    if (!spacing.isFinite || spacing <= 0) {
      throw ArgumentError.value(
          spacing, 'spacing', 'must be finite and above 0');
    }
    if (!curve.isFinite || curve.abs() >= math.pi) {
      throw ArgumentError.value(curve, 'curve', 'must be finite, below π');
    }
    if (!this.base.x.isFinite || !this.base.y.isFinite) {
      throw ArgumentError.value(base, 'base', 'must be finite');
    }
  }

  static const String componentTypeId = rowTypeId;

  final String prefix;
  final int count;
  final double spacing;
  final double curve;
  final Handle seat;
  final Vector2 base;
  final Aabb2 top;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'base': [base.x, base.y],
        'count': count,
        'curve': curve,
        'prefix': prefix,
        'seat': seat.toJson(),
        'spacing': spacing,
        'top': [top.minX, top.minY, top.maxX, top.maxY],
      };

  static RowComponent fromJson(Map<String, Object?> json) {
    final base = (json['base']! as List).cast<num>();
    final top = (json['top']! as List).cast<num>();
    return RowComponent(
      prefix: json['prefix']! as String,
      count: json['count']! as int,
      spacing: (json['spacing']! as num).toDouble(),
      curve: (json['curve']! as num).toDouble(),
      seat: Handle.fromJson(json['seat']),
      base: Vector2(base[0].toDouble(), base[1].toDouble()),
      top: Aabb2.raw(top[0].toDouble(), top[1].toDouble(), top[2].toDouble(),
          top[3].toDouble()),
    );
  }

  RowComponent copyWith(
          {String? prefix, int? count, double? spacing, double? curve}) =>
      RowComponent(
        prefix: prefix ?? this.prefix,
        count: count ?? this.count,
        spacing: spacing ?? this.spacing,
        curve: curve ?? this.curve,
        seat: seat,
        base: base,
        top: top,
      );

  @override
  bool operator ==(Object other) =>
      other is RowComponent &&
      other.prefix == prefix &&
      other.count == count &&
      other.spacing == spacing &&
      other.curve == curve &&
      other.seat == seat &&
      other.base.x == base.x &&
      other.base.y == base.y &&
      other.top.minX == top.minX &&
      other.top.minY == top.minY &&
      other.top.maxX == top.maxX &&
      other.top.maxY == top.maxY;

  @override
  int get hashCode => Object.hash(prefix, count, spacing, curve, seat, base.x,
      base.y, top.minX, top.minY, top.maxX, top.maxY);

  @override
  String toString() => 'RowComponent($prefix × $count @ $spacing, $curve)';
}

/// Seat [i] (0-based) of [row] in the row's group space: a chord walk of
/// `spacing`, turning `curve` a seat; the seat's base point on its place.
Transform2 rowSeatTransform(RowComponent row, int i) {
  final theta = i * row.curve;
  final double x, y;
  if (row.curve == 0) {
    x = i * row.spacing;
    y = 0;
  } else {
    final r = row.spacing / (2 * math.sin(row.curve / 2));
    x = r * math.sin(theta);
    y = r * (1 - math.cos(theta));
  }
  final c = math.cos(theta), s = math.sin(theta);
  return Transform2.translation(x, y)
      .multiply(Transform2(c, s, -s, c, 0, 0))
      .multiply(Transform2.translation(-row.base.x, -row.base.y));
}

/// The row's engine type: seats only (spec 2b "The test kit"; the
/// selection rules of S2 discuss a seats-only row), each labelled through
/// the kit's `unitLabelAttrib`.
final class RowType extends ParametricType<RowComponent> {
  const RowType();

  @override
  Capability get editCapability => Capability.geometry;

  /// The seats' tops, in the world.
  @override
  Aabb2 reach(RowComponent params, Transform2 toWorld) {
    final t = params.top;
    return Aabb2.fromPoints([
      for (var i = 0; i < params.count; i++)
        for (final (x, y) in [
          (t.minX, t.minY),
          (t.maxX, t.minY),
          (t.maxX, t.maxY),
          (t.minX, t.maxY),
        ])
          toWorld
              .multiply(rowSeatTransform(params, i))
              .transformPoint(Vector2(x, y)),
    ]);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];

  @override
  List<GeneratedInstance> instances(ParametricView view, Handle self) {
    final row = view.paramsOf<RowComponent>(self)!;
    final toWorld = view.toWorld(self);
    final out = <GeneratedInstance>[];
    for (var i = 0; i < row.count; i++) {
      final seat = rowSeatTransform(row, i);
      out.add(GeneratedInstance(row.seat, seat, attributes: [
        unitLabelAttrib('${row.prefix}${i + 1}',
            instanceToWorld: toWorld.multiply(seat),
            anchor: row.base,
            top: row.top),
      ]));
    }
    return out;
  }
}

/// The first free prefix for a row of [count] seats in [d] (spec S2: the
/// placing tool's job): `A`, `B`, …, `Z`, `AA`, `AB`, …, the first `P` for
/// which none of `P1` to `P<count>` is the trimmed text of a live UNIT
/// ATTRIB. O(entities), once per placement.
String freeRowPrefix(DraftDocument d, int count) {
  final e = d.entities;
  final labels = <String>{
    for (final s in e.liveSlots)
      if (e.kindAt(s) == EntityKind.attrib && e.tagAt(s) == kUnitLabelTag)
        e.textAt(s).trim(),
  };
  for (var n = 0;; n++) {
    final prefix = _letters(n);
    var free = true;
    for (var i = 1; i <= count && free; i++) {
      if (labels.contains('$prefix$i')) free = false;
    }
    if (free) return prefix;
  }
}

/// 0 → A, 25 → Z, 26 → AA: bijective base 26.
String _letters(int n) {
  var k = n + 1;
  final codes = <int>[];
  while (k > 0) {
    k--;
    codes.add(0x41 + k % 26);
    k ~/= 26;
  }
  return String.fromCharCodes(codes.reversed);
}

/// A root-level group at [at] turned by [angle], carrying [row] and the
/// drawing layer: one step (the seats come from the row's regeneration).
CompoundCommand placeRowCommand(DraftDocument d, RowComponent row,
    {required Vector2 at, double angle = 0, Handle? handle}) {
  final h = handle ?? d.handleSeed.next();
  return CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: d.rootHandle,
        transform: Transform2.translation(at.x, at.y)
            .multiply(Transform2.rotation(angle)),
        children: const [])),
    SetComponentCommand<RowComponent>(h, row),
    SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(d))),
  ], label: 'Add row');
}

/// The definition's top, as `SymbolDefinitionRef.top` gives it (spec S2):
/// the first leaf's box when it is a closed polyline or a circle, else the
/// leaves' vertex box. The unit library's entries all take the first
/// branch.
Aabb2 entryTop(SymbolEntry entry) {
  if (entry.leaves.isEmpty) return Aabb2.empty();
  final first = entry.leaves.first;
  final p = first.payload;
  if (first.record.kind == EntityKind.circle) {
    final r = p.scalars[0];
    return Aabb2.raw(
        p.coords[0] - r, p.coords[1] - r, p.coords[0] + r, p.coords[1] + r);
  }
  if (first.record.kind == EntityKind.polyline && isClosedPolyline(p)) {
    return Aabb2.fromPoints(
        [for (var i = 0; i < p.pointCount; i++) p.pointAt(i)]);
  }
  return Aabb2.fromPoints([
    for (final l in entry.leaves)
      for (var i = 0; i < l.payload.pointCount; i++) l.payload.pointAt(i),
  ]);
}

/// What a row placement needs.
const Set<Capability> rowNeeds = {
  Capability.structure,
  Capability.components,
  Capability.geometry,
};

/// Two presses: the first anchors the row, the second turns it towards the
/// press and places a row of [kRowToolSeats] seats with the first free
/// prefix, through `symbolDefinition` once.
final class RowTool extends PlacementTool {
  RowTool(this.services);

  final PlanServices services;

  @override
  String get name => 'Row';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final start = points.first;
    final d = point - start;
    if (d.length <= Tolerance.standard.linear) return;
    clearShape();
    // The permissions first: a refused row allocates no handle (Ruling
    // 05-3), then the definition, once per placement (spec S2).
    if (!rowNeeds.every(ctx.document.commands.permissions.allows)) return;
    final ref = services.symbolDefinition(rowSeatKey);
    if (ref == null) return;
    final document = services.document;
    ctx.execute(CompoundCommand([
      if (ref.add case final add?) add,
      placeRowCommand(
          document,
          RowComponent(
              prefix: freeRowPrefix(document, kRowToolSeats),
              count: kRowToolSeats,
              spacing: kRowToolSpacing,
              seat: ref.handle,
              base: ref.basePoint,
              top: ref.top),
          at: start,
          angle: math.atan2(d.y, d.x)),
    ], label: 'Add row'));
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {}
}

PlanType<RowComponent> rowType() => PlanType<RowComponent>(
      id: rowTypeId,
      fromJson: RowComponent.fromJson,
      parametric: const RowType(),
    );

PlanTool rowTool() => PlanTool(
      id: rowToolId,
      icon: Icons.event_seat,
      needs: rowNeeds,
      create: RowTool.new,
    );

// ---------------------------------------------------------------------------
// Placing objects.

/// A root-level group at [at] carrying [component] and the drawing layer:
/// one undo step. [T] must be the component's concrete type: the store is
/// chosen by it.
CompoundCommand placeObjectCommand<T extends Component>(
    DraftDocument d, T component,
    {required Vector2 at, Handle? handle}) {
  final h = handle ?? d.handleSeed.next();
  return CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: d.rootHandle,
        transform: Transform2.translation(at.x, at.y),
        children: const [])),
    SetComponentCommand<T>(h, component),
    SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(d))),
  ], label: 'Add ${component.typeId}');
}

/// [placeObjectCommand], executed; the new object's handle.
Handle addObject<T extends Component>(DraftDocument d, T component,
    {required Vector2 at}) {
  final h = d.handleSeed.next();
  d.commands.execute(placeObjectCommand<T>(d, component, at: at, handle: h));
  return h;
}
