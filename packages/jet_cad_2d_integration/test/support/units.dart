// The fixture kit `fx` and its units (3a Task 26), ported from
// jet_cad_2d_plan's test/support/unit_fixtures.dart (2b Tasks 6 and 8),
// symbol_fixtures.dart's leafRecord and unit_editor_fixture.dart's symbols.
// The plan's placer and its label command are not exported (spec C6), so
// placeUnit and labelUnit re-state their no-thumbnail path over the
// engine's commands and the contract's label helpers: a definition copied
// once per key and version (symbol_placer.dart:52-101), an instance on the
// given layer, and a UNIT label owned by the instance, anchored at the
// base point, the height of the first leaf's top, stamped upright
// (unit_label.dart:55-75, 134-186).
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show
        Catalog,
        CatalogCircle,
        CatalogLine,
        CatalogPolyline,
        CatalogSymbol,
        CatalogUnit,
        encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanController;
import 'package:vector_math/vector_math_64.dart' show Vector2;

const String fxKitId = 'fx';

/// The fixture kit's words (ruling IP-R4; 3a Task 27's review): its
/// library table's name and category in German and Turkish, today's
/// furniture words for `dining.table.square.two` and `Dining Room`. English
/// is the library's stored name.
const KitNames fxNames = KitNames({
  'de': {
    'symbol:fx.dining.table.two': 'Quadratischer Esstisch, 2 Plätze',
    'category:fx/Dining Room': 'Esszimmer',
  },
  'tr': {
    'symbol:fx.dining.table.two': 'Kare yemek masası, 2 kişilik',
    'category:fx/Dining Room': 'Yemek odası',
  },
});

/// The fixtures' kit: no type, no tool, [fxNames]; with [library], a
/// symbol library of those symbols (the Symbols tab offers them).
PlanKit fxKit({List<CatalogSymbol> library = const []}) => PlanKit(
      id: fxKitId,
      version: '1.0.0',
      names: fxNames,
      symbols: [
        if (library.isNotEmpty)
          SymbolLibrarySource(
              label: 'fx',
              read: () async =>
                  encodeLibrary(Catalog(kit: fxKitId, symbols: library))),
      ],
    );

EntityRecord leafRecord(int handle, Handle owner, EntityKind kind) =>
    EntityRecord(
      handle: Handle(handle),
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
    );

/// A served unit of kind `table` seating [seats], the default labelling.
CatalogUnit tableUnit(int seats) =>
    CatalogUnit(kind: UnitKinds.table, capacity: seats);

/// A 1200 x 800 top with two 450 x 450 chairs below and above it; the base
/// point is the top's centre, (900, 700).
CatalogSymbol tableSymbol({String key = 'fx.table.two', int seats = 2}) =>
    CatalogSymbol(
      key: key,
      name: 'Test table',
      category: 'Tests',
      tags: const ['table', 'test'],
      unit: tableUnit(seats),
      base: (900, 700),
      shapes: const [
        CatalogPolyline([(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
            closed: true),
        CatalogPolyline([(675, -50), (1125, -50), (1125, 400), (675, 400)],
            closed: true),
        CatalogPolyline([(675, 1000), (1125, 1000), (1125, 1450), (675, 1450)],
            closed: true),
      ],
    );

/// DT1's and LK2's library table (ruling IP-R4): today's
/// `dining.table.square.two`'s name, a served two-seat unit of the fixture
/// kit, its shapes the fixture table's.
final CatalogSymbol diningTableTwo = CatalogSymbol(
  key: 'fx.dining.table.two',
  name: 'Square dining table, 2 seats',
  category: 'Dining Room',
  tags: const ['table', 'dining'],
  unit: tableUnit(2),
  base: tableSymbol().base,
  shapes: tableSymbol().shapes,
);

/// [s] as a library entry, built by hand (no library rule is checked): its
/// leaves ascending by handle in shape order, each a BYBLOCK leaf on layer
/// 0; its unit when [CatalogSymbol.unit] is set; its attachment kinds and
/// family kept (3a Task 28: 2b's copy dropped them).
SymbolEntry entryOf(CatalogSymbol s) {
  const definition = Handle(0x0F0);
  final leaves = <SymbolLeaf>[];
  var next = 0x100;
  for (final shape in s.shapes) {
    final (EntityKind kind, GeometryPayload payload) = switch (shape) {
      CatalogPolyline(:final points, :final closed) => (
          EntityKind.polyline,
          polylinePayload([for (final (x, y) in points) Vector2(x, y)],
              closed: closed)
        ),
      CatalogCircle(center: (final x, final y), :final radius) => (
          EntityKind.circle,
          circlePayload(Vector2(x, y), radius)
        ),
      CatalogLine(from: (final ax, final ay), to: (final bx, final by)) => (
          EntityKind.line,
          linePayload(Vector2(ax, ay), Vector2(bx, by))
        ),
      _ => throw UnsupportedError('no arc in the unit fixtures'),
    };
    leaves
        .add((record: leafRecord(next++, definition, kind), payload: payload));
  }
  final unit = s.unit;
  return SymbolEntry(
    symbol: SymbolComponent(
        key: s.key,
        version: s.version,
        name: s.name,
        category: s.category,
        tags: s.tags,
        attachTo: s.attachTo,
        family: s.family),
    unit: unit == null
        ? null
        : UnitComponent(
            kind: unit.kind,
            capacity: unit.capacity,
            labelling: unit.labelling),
    definition: Definition(
        handle: definition,
        name: s.id,
        basePoint: Vector2(s.base.$1, s.base.$2),
        children: const []),
    leaves: leaves,
  );
}

const double kDeg37 = 37 * math.pi / 180;

/// `translate(at) · R(theta) · (mirror x) · translate(-base)`.
Transform2 placementAt(double x, double y, double theta,
        {bool mirrored = false, double baseX = 900, double baseY = 700}) =>
    Transform2.translation(x, y)
        .multiply(Transform2.rotation(theta))
        .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
        .multiply(Transform2.translation(-baseX, -baseY));

/// A layer [name] beside layer 0.
Handle addLayer(DraftDocument doc, String name,
    {bool visible = true, bool locked = false}) {
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final h = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: h,
      name: name,
      color: const IndexedColor(4),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked)));
  return h;
}

/// The embedding fixture's table (four seats): its top an asymmetric
/// quadrilateral; its base point the definition's origin, outside its box.
const CatalogSymbol embeddingTable = CatalogSymbol(
  key: 'fx.embedding.four',
  name: 'Test embedding table',
  category: 'Tests',
  tags: ['table', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 4),
  base: (0, 0),
  shapes: [
    CatalogPolyline([(300, -200), (1100, -200), (900, 400), (300, 250)],
        closed: true),
  ],
);

/// [embeddingTable]'s box in definition space: its centre (700, 100) is not
/// its base point (0, 0).
const Aabb2 embeddingBox = Aabb2.raw(300, -200, 1100, 400);

/// A chair: no unit, its base point (0, 0) off its seat.
const CatalogSymbol editorChair = CatalogSymbol(
  key: 'fx.chair.plain',
  name: 'Test chair',
  category: 'Tests',
  tags: ['chair', 'test'],
  base: (0, 0),
  shapes: [
    CatalogPolyline([(50, 50), (500, 50), (500, 430), (50, 430)], closed: true),
    CatalogPolyline([(50, 430), (500, 430), (500, 500), (50, 500)],
        closed: true),
  ],
);

/// `translate(x, y) · R(theta) · diag(sx, sy)`, written out.
Transform2 embeddingPlacement(double x, double y, double degrees,
    {double sx = 1, double sy = 1}) {
  final t = degrees * math.pi / 180;
  final cos = math.cos(t), sin = math.sin(t);
  return Transform2(sx * cos, sx * sin, -sy * sin, sy * cos, x, y);
}

/// [s] placed by [transform] on [layer] (layer 0 by default), one step:
/// its definition copied unless a live one of its key and version is there
/// (the placer's reuse, less its leaf-equality check: fixture symbols are
/// never edited). Returns the instance.
Handle placeUnit(DraftDocument doc, CatalogSymbol s,
    {required Transform2 transform, Handle? layer}) {
  final entry = entryOf(s);
  final commands = <DraftCommand>[];
  Handle? definition;
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    final c = doc.components.get<SymbolComponent>(h)!;
    if (c.key == entry.symbol.key &&
        c.version == entry.symbol.version &&
        doc.tree.definition(h) != null) {
      definition = h;
      break;
    }
  }
  if (definition == null) {
    final copy = doc.handleSeed.next();
    commands
      ..add(AddDefinitionCommand(Definition(
          handle: copy,
          name: entry.symbol.id,
          basePoint: entry.definition.basePoint,
          children: const [])))
      ..add(SetComponentCommand<SymbolComponent>(copy, entry.symbol));
    if (entry.unit case final unit?) {
      commands.add(SetComponentCommand<UnitComponent>(copy, unit));
    }
    for (final leaf in entry.leaves) {
      commands.add(AddEntityCommand(
          record:
              leaf.record.copyWith(handle: doc.handleSeed.next(), owner: copy),
          payload: leaf.payload));
    }
    definition = copy;
  }
  final h = doc.handleSeed.next();
  commands.add(AddNodeCommand(InstanceNode(
      handle: h,
      parent: doc.rootHandle,
      definition: definition,
      layer: layer ?? ReservedHandles.layerZero,
      transform: transform)));
  doc.commands.execute(CompoundCommand(commands, label: 'Place ${s.name}'));
  return h;
}

/// [s] with its base point at [at], [quarterTurns] counter-clockwise and
/// [mirrored] (unit_fixtures.dart's placeAt, over the contract's
/// transform).
Handle placeAt(DraftDocument doc, CatalogSymbol s, Vector2 at,
        {int quarterTurns = 0, bool mirrored = false}) =>
    placeUnit(doc, s,
        transform: placementTransform(
            at: at,
            basePoint: Vector2(s.base.$1, s.base.$2),
            quarterTurns: quarterTurns,
            mirrored: mirrored));

/// The box of [definition]'s lowest-handle leaf when it is a circle or a
/// polyline, else empty (the plan's `placedLabelTopOf`,
/// unit_label.dart:134-164, the label height's rule, ruling R-21).
Aabb2 labelTopOf(DraftDocument doc, Handle definition) {
  int? first;
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.ownerAt(slot) != definition) continue;
    if (first == null ||
        doc.entities.handleAt(slot).value <
            doc.entities.handleAt(first).value) {
      first = slot;
    }
  }
  if (first == null) return Aabb2.empty();
  final p = doc.geometry.read(doc.entities.geomIndexAt(first));
  switch (doc.entities.kindAt(first)) {
    case EntityKind.circle:
      final r = p.scalars[0];
      return Aabb2.raw(
          p.coords[0] - r, p.coords[1] - r, p.coords[0] + r, p.coords[1] + r);
    case EntityKind.polyline:
      final c = p.coords;
      var minX = c[0], maxX = c[0], minY = c[1], maxY = c[1];
      for (var i = 2; i + 1 < c.length; i += 2) {
        minX = math.min(minX, c[i]);
        maxX = math.max(maxX, c[i]);
        minY = math.min(minY, c[i + 1]);
        maxY = math.max(maxY, c[i + 1]);
      }
      return Aabb2.raw(minX, minY, maxX, maxY);
    default:
      return Aabb2.empty();
  }
}

/// [text] as [instance]'s UNIT label, one step; the label's handle.
Handle labelUnit(DraftDocument doc, Handle instance, String text) {
  final node = doc.tree[instance]! as InstanceNode;
  final def = doc.tree.definition(node.definition)!;
  final h = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: instance,
      kind: EntityKind.attrib,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
      text: text,
      tag: kUnitLabelTag,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: kUnitLabelTextAttrs,
    ),
    payload: unitLabelPayload(
      anchor: def.basePoint,
      height: unitLabelHeight(labelTopOf(doc, node.definition)),
      instanceToWorld: node.transform,
    ),
  ));
  return h;
}

/// The instances of [doc] whose UNIT label reads [label] trimmed, by
/// handle (today's `TableSurvey.withNumber`, 2b's `withLabel`).
List<Handle> unitsLabelled(DraftDocument doc, String label) {
  final out = <Handle>[];
  for (final slot in doc.entities.liveSlots) {
    final r = doc.entities.read(slot);
    if (r.kind == EntityKind.attrib &&
        r.tag == kUnitLabelTag &&
        r.text.trim() == label.trim()) {
      out.add(r.owner);
    }
  }
  return out..sort((a, b) => a.value.compareTo(b.value));
}

/// Table [n]'s instance; ` 7 ` is the later of the two sevens, null the
/// unlabelled unit (2b's `tableOf`, unit_editor_fixture.dart:228-236).
Handle tableOf(PlanController c, String? n) {
  final d = c.document;
  if (n == null) {
    final labelled = {
      for (final slot in d.entities.liveSlots)
        if (d.entities.read(slot).tag == kUnitLabelTag)
          d.entities.ownerAt(slot),
    };
    return d.tree.nodes
        .whereType<InstanceNode>()
        .where((i) =>
            d.components.get<UnitComponent>(i.definition) != null &&
            !labelled.contains(i.handle))
        .single
        .handle;
  }
  return unitsLabelled(d, n)[n == ' 7 ' ? 1 : 0];
}
