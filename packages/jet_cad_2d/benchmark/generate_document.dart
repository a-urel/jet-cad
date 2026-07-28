// Document generator for the query-throughput gate (task-18-brief.md, Step 1).
//
// A benchmark document of identical points at the origin measures nothing
// that matters: every leaf lands in one R-tree node, every query is a
// best case, and float precision never enters into it. This generator
// spreads entities over a plausible floor-plan area at large world
// coordinates, with a realistic kind mix, so the tree actually has depth
// and shape and the numbers this benchmark reports mean something.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// The floor plan's extent in each axis, independent of [entityCount]: a
/// site is a fixed physical size, and adding more detail to it raises
/// density rather than growing the plan. Chosen together with
/// [kQueryRectHalfSize] in `query_throughput.dart` so a 500k-entity document
/// gives the "~2k visible" rect query the brief's gate row describes without
/// re-deriving that number from a run's actual output.
const double kFloorWidth = 60000.0;
const double kFloorHeight = 40000.0;

/// Large-coordinate offset on the Y axis. The brief only names `originX`
/// explicitly, but a fixture that is huge on one axis and near zero on the
/// other is only half honest about float precision at scale, so both axes
/// sit far from the origin.
const double kOriginY = 1200000.0;

/// [generateDocument]'s own default for `originX`, pulled out as a constant
/// so `query_throughput.dart` can build extra fixtures (the dirty-list
/// filler) at the same large coordinates without repeating the literal.
const double kDefaultOriginX = 4500000.0;

/// Builds a document for benchmark measurement.
///
/// Entities are spread over a [kFloorWidth] x [kFloorHeight] floor-plan
/// area offset by [originX] (and the fixed [kOriginY]), with a realistic
/// mix: mostly lines and polylines, some circles and arcs, a few hundred
/// text entities, and [definitionCount] definitions — each a small
/// multi-entity symbol in its own local space — placed by many instances
/// scattered across the floor plan.
///
/// [entityCount] is the total number of leaf entities in the document,
/// split between root-level content and the entities living inside
/// definitions. [instanceCount], when left at its default of 0, is derived
/// from [definitionCount] so every definition is placed several times over;
/// pass it explicitly to control instancing directly (the definition-bounds
/// build-time probe in `query_throughput.dart` does this, to guarantee every
/// definition is reached by at least one instance).
DraftDocument generateDocument(
  int entityCount, {
  int definitionCount = 20,
  int instanceCount = 0,
  double originX = kDefaultOriginX,
}) {
  final random = math.Random(0xC0FFEE);
  final doc = DraftDocument.empty();

  // --- definitions: small local symbols, entities owned by the definition
  // handle directly (never by a `children` list -- see
  // `EntityRecord.owner`'s governing rule). --------------------------------
  const leavesPerDefinition = 16;
  final definitionBudget = definitionCount * leavesPerDefinition <= entityCount
      ? leavesPerDefinition
      : math.max(1, entityCount ~/ math.max(1, definitionCount));

  final definitionHandles = <Handle>[];
  var entitiesLeft = entityCount;
  for (var d = 0; d < definitionCount; d++) {
    final handle = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: handle,
      name: 'symbol_$d',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    definitionHandles.add(handle);

    final leaves = math.min(definitionBudget, entitiesLeft);
    entitiesLeft -= leaves;
    for (var i = 0; i < leaves; i++) {
      _addSymbolEntity(doc, owner: handle, random: random);
    }
  }

  // --- root-level content: the rest of the entity budget, spread across
  // the floor plan, mostly straight and a few hundred texts. --------------
  final rootEntityCount = entitiesLeft;
  final textCount = math.min(300, rootEntityCount ~/ 100);
  final remaining = rootEntityCount - textCount;
  final lineCount = (remaining * 0.45).round();
  final polylineCount = (remaining * 0.30).round();
  final circleCount = (remaining * 0.15).round();
  final arcCount = remaining - lineCount - polylineCount - circleCount;

  for (var i = 0; i < lineCount; i++) {
    _addFloorLine(doc, originX: originX, random: random);
  }
  for (var i = 0; i < polylineCount; i++) {
    _addFloorPolyline(doc, originX: originX, random: random);
  }
  for (var i = 0; i < circleCount; i++) {
    _addFloorCircle(doc, originX: originX, random: random);
  }
  for (var i = 0; i < arcCount; i++) {
    _addFloorArc(doc, originX: originX, random: random);
  }
  for (var i = 0; i < textCount; i++) {
    _addFloorText(doc, originX: originX, random: random);
  }

  // --- instances: every definition placed many times, scattered across
  // the floor plan. --------------------------------------------------------
  final effectiveInstanceCount =
      instanceCount > 0 ? instanceCount : definitionCount * 25;
  for (var i = 0; i < effectiveInstanceCount; i++) {
    final definition = definitionHandles[i % definitionHandles.length];
    final x = originX + random.nextDouble() * kFloorWidth;
    final y = kOriginY + random.nextDouble() * kFloorHeight;
    // Mostly plain translation, occasionally rotated -- a symbol dropped at
    // an angle is common in a real floor plan and exercises the transform
    // composition the index relies on, without making every instance's
    // placement a special case to reason about.
    final transform = random.nextDouble() < 0.15
        ? Transform2.translation(x, y)
            .multiply(Transform2.rotation(random.nextDouble() * math.pi * 2))
        : Transform2.translation(x, y);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      transform: transform,
      definition: definition,
      layer: ReservedHandles.layerZero,
    )));
  }

  return doc;
}

Handle _addEntity(
  DraftDocument doc, {
  required Handle owner,
  required EntityKind kind,
  required List<double> coords,
  List<double> scalars = const [],
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

/// One entity of a small local symbol: local coordinates near zero, at the
/// scale of real hardware (a door, a fixture) rather than a whole building.
void _addSymbolEntity(
  DraftDocument doc, {
  required Handle owner,
  required math.Random random,
}) {
  double c() => (random.nextDouble() - 0.5) * 1000.0; // +/-500 units
  switch (random.nextInt(4)) {
    case 0:
      _addEntity(doc,
          owner: owner, kind: EntityKind.line, coords: [c(), c(), c(), c()]);
    case 1:
      final points = <double>[];
      final n = 3 + random.nextInt(3);
      for (var i = 0; i < n; i++) {
        points
          ..add(c())
          ..add(c());
      }
      _addEntity(doc, owner: owner, kind: EntityKind.polyline, coords: points);
    case 2:
      _addEntity(doc,
          owner: owner,
          kind: EntityKind.circle,
          coords: [c(), c()],
          scalars: [50.0 + random.nextDouble() * 200.0]);
    default:
      _addEntity(doc, owner: owner, kind: EntityKind.arc, coords: [
        c(),
        c()
      ], scalars: [
        50.0 + random.nextDouble() * 200.0,
        random.nextDouble() * math.pi * 2,
        (0.5 + random.nextDouble()) * math.pi,
      ]);
  }
}

double _floorX(double originX, math.Random random) =>
    originX + random.nextDouble() * kFloorWidth;
double _floorY(math.Random random) =>
    kOriginY + random.nextDouble() * kFloorHeight;

void _addFloorLine(DraftDocument doc,
    {required double originX, required math.Random random}) {
  final x0 = _floorX(originX, random), y0 = _floorY(random);
  final length = 50.0 + random.nextDouble() * 2950.0;
  final angle = random.nextDouble() * math.pi * 2;
  final x1 = x0 + length * math.cos(angle);
  final y1 = y0 + length * math.sin(angle);
  _addEntity(doc,
      owner: doc.rootHandle, kind: EntityKind.line, coords: [x0, y0, x1, y1]);
}

void _addFloorPolyline(DraftDocument doc,
    {required double originX, required math.Random random}) {
  final n = 3 + random.nextInt(4);
  var x = _floorX(originX, random), y = _floorY(random);
  final coords = <double>[x, y];
  for (var i = 1; i < n; i++) {
    final length = 50.0 + random.nextDouble() * 1500.0;
    final angle = random.nextDouble() * math.pi * 2;
    x += length * math.cos(angle);
    y += length * math.sin(angle);
    coords
      ..add(x)
      ..add(y);
  }
  _addEntity(doc,
      owner: doc.rootHandle, kind: EntityKind.polyline, coords: coords);
}

void _addFloorCircle(DraftDocument doc,
    {required double originX, required math.Random random}) {
  final x = _floorX(originX, random), y = _floorY(random);
  final radius = 50.0 + random.nextDouble() * 1450.0;
  _addEntity(doc,
      owner: doc.rootHandle,
      kind: EntityKind.circle,
      coords: [x, y],
      scalars: [radius]);
}

void _addFloorArc(DraftDocument doc,
    {required double originX, required math.Random random}) {
  final x = _floorX(originX, random), y = _floorY(random);
  final radius = 50.0 + random.nextDouble() * 1450.0;
  _addEntity(doc, owner: doc.rootHandle, kind: EntityKind.arc, coords: [
    x,
    y
  ], scalars: [
    radius,
    random.nextDouble() * math.pi * 2,
    (0.25 + random.nextDouble() * 1.5) * math.pi,
  ]);
}

void _addFloorText(DraftDocument doc,
    {required double originX, required math.Random random}) {
  final x = _floorX(originX, random), y = _floorY(random);
  _addEntity(doc,
      owner: doc.rootHandle,
      kind: EntityKind.text,
      coords: [x, y],
      scalars: [100.0 + random.nextDouble() * 200.0]);
}
