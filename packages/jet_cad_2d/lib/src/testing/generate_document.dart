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

/// Room-label vocabulary for [labelFraction]'s doc comment and
/// implementation. Order is part of the fixture: a test naming an index into
/// this list depends on it. Copied verbatim from the Plan 3c Task 7 brief.
const List<String> _kLabelVocabulary = <String>[
  'WC',
  'KITCHEN',
  'BAR',
  'STORE',
  'OFFICE',
  'ENTRY',
  'HALL',
  'STAIR',
  'LIFT',
  'TERRACE',
  'PANTRY',
  'CLOAK',
  'PLANT',
  'RISER',
  'LOBBY',
  'CORRIDOR',
  'SERVICE',
  'DECK',
  'GARDEN',
  'ROOF',
];

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
/// The extensions below are all off by default, and "off" means **draws
/// nothing**.
///
/// Every one of them takes its randomness from a second [math.Random] and
/// allocates no handle while it is zero, so the default document is the one
/// Plan 2 measured, coordinate for coordinate. One stray `nextDouble()` on the
/// primary stream would shift every value after it and silently invalidate the
/// gate results note; `generate_document_test.dart` pins the serialisation's
/// fingerprint against exactly that.
///
/// [labelFraction] and [attributedInstanceFraction] draw from that same
/// second stream too, and there is one such stream, not one per extension:
/// turning either on shifts every draw the other makes, so the two are
/// **not** independently reproducible. A fixture names both together or
/// names neither; naming just one and expecting the other's defaulted output
/// to match a fixture that also named the first is not a thing this
/// generator supports.
DraftDocument generateDocument(
  int entityCount, {
  int definitionCount = 20,
  int instanceCount = 0,
  double originX = kDefaultOriginX,

  /// How deep an instance chain inside definitions may run. Definitions are
  /// chained in index order, so a cycle cannot be constructed.
  int nestingDepth = 0,

  /// Fraction of root instances placed with a negative determinant.
  double mirroredFraction = 0,

  /// Fraction of root instances scaled past `kAnisotropyThreshold`, so the
  /// painter's exact per-axis path is actually reached.
  double nonUniformFraction = 0,

  /// Group nodes under the root, each a cluster of local geometry placed on
  /// the floor plan — the folded-leaf-transform path.
  int groupCount = 0,

  /// Total layer records including layer 0.
  int layerCount = 1,

  /// Fraction of **definition-owned** entities authored ByBlock. Root-level
  /// ByBlock has no instance to resolve against and exercises no extra path.
  double byBlockFraction = 0,

  /// Fraction of all entities carrying a dashed linetype rather than ByLayer.
  double dashedFraction = 0,

  /// Fraction of the **root** entity budget rendered as repeating floor-plan
  /// labels ("KITCHEN", "STAIR", ...) from [_kLabelVocabulary], in place of
  /// the plain, contentless floor texts [_addFloorText] would otherwise put
  /// there. Comes *out of* the root budget rather than adding to it, so the
  /// total leaf count does not move when this is on -- unlike
  /// [attributedInstanceFraction], which is additive. See the class doc
  /// comment above for why the two extensions cannot be pinned
  /// independently.
  double labelFraction = 0,

  /// Fraction of root instances given one additional ATTRIB leaf: a unique
  /// tag value, owned by the instance node, in the instance's own local
  /// space. DXF stores an ATTRIB already placed in world space, and
  /// `container_index.dart` transforms every leaf a container owns by that
  /// container's composed transform, so writing world coordinates here would
  /// apply the instance's placement twice. Additive -- each one is a leaf
  /// the root budget did not already account for -- unlike [labelFraction].
  /// See the class doc comment above for why the two extensions cannot be
  /// pinned independently.
  double attributedInstanceFraction = 0,
}) {
  final random = math.Random(0xC0FFEE);
  // A second stream, drawn from only by the extensions. Keeping them off the
  // primary one is what makes the default document byte-identical however many
  // extensions exist.
  final extra = math.Random(0x5EEDED);
  final doc = DraftDocument.empty();

  final layers = <Handle>[];
  if (layerCount > 1) {
    layers.add(ReservedHandles.layerZero);
    for (var i = 1; i < layerCount; i++) {
      final handle = doc.handleSeed.next();
      doc.tables.layers.add(LayerRecord(
        handle: handle,
        name: 'layer_$i',
        // A concrete colour, so an entity on this layer resolves ByLayer to
        // something other than layer 0's — otherwise more layers would mean
        // more table records and one resolution outcome.
        color: IndexedColor(1 + (i % 254)),
        linetype: ReservedHandles.continuousLinetype,
        lineweight: 25 + (i % 4) * 25,
        transparency: 0,
      ));
      layers.add(handle);
    }
  }

  Handle? dashedLinetype;
  if (dashedFraction > 0) {
    dashedLinetype = doc.handleSeed.next();
    doc.tables.linetypes.add(LinetypeRecord(
      handle: dashedLinetype,
      name: 'Dashed',
      description: '__ __ __',
      pattern: const DashPattern(dashes: [12.0, -6.0], totalLength: 18.0),
    ));
  }

  final styling = _Styling(
    random: extra,
    layers: layers,
    dashed: dashedLinetype,
    dashedFraction: dashedFraction,
    byBlockFraction: byBlockFraction,
  );

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
      _addSymbolEntity(doc,
          owner: handle,
          random: random,
          styling: styling,
          insideDefinition: true);
    }
  }

  // --- nesting: definitions chained in index order. ------------------------
  //
  // Index order is the whole cycle guard: definition i places only i + 1, so
  // the placement graph is a forest of forward chains and cannot close. The
  // chains are cut every `nestingDepth` definitions, which is what bounds the
  // depth to the number asked for rather than to `definitionCount`.
  if (nestingDepth > 0) {
    for (var d = 0; d + 1 < definitionHandles.length; d++) {
      if ((d + 1) % (nestingDepth + 1) == 0) continue; // chain boundary
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: doc.handleSeed.next(),
        parent: definitionHandles[d],
        transform: Transform2.translation((extra.nextDouble() - 0.5) * 400,
                (extra.nextDouble() - 0.5) * 400)
            .multiply(Transform2.rotation(extra.nextDouble() * math.pi * 2))
            .multiply(Transform2.scale(0.5 + extra.nextDouble(), 0.5)),
        definition: definitionHandles[d + 1],
        layer: ReservedHandles.layerZero,
      )));
    }
  }

  // --- groups: clusters of local geometry placed on the floor plan. --------
  //
  // A group folds its transform into the leaves of the container above it, so
  // its contents are authored in local coordinates exactly as a definition's
  // are; the floor position lives in the group's own transform. Authoring them
  // at floor coordinates instead would move the whole cluster by the plan's
  // width once the transform composed.
  final groupHandles = <Handle>[];
  var groupEntityCount = 0;
  if (groupCount > 0) {
    groupEntityCount = math.min(groupCount * 8, entitiesLeft ~/ 4);
    for (var g = 0; g < groupCount; g++) {
      final handle = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(GroupNode(
        handle: handle,
        parent: doc.rootHandle,
        transform: Transform2.translation(
                originX + extra.nextDouble() * kFloorWidth,
                kOriginY + extra.nextDouble() * kFloorHeight)
            .multiply(Transform2.rotation(extra.nextDouble() * math.pi * 2)),
        children: const [],
      )));
      groupHandles.add(handle);
    }
    for (var i = 0; i < groupEntityCount; i++) {
      _addSymbolEntity(doc,
          owner: groupHandles[i % groupHandles.length],
          random: random,
          styling: styling,
          insideDefinition: false);
    }
    entitiesLeft -= groupEntityCount;
  }

  // --- root-level content: the rest of the entity budget, spread across
  // the floor plan, mostly straight and a few hundred texts. --------------
  final rootEntityCount = entitiesLeft;
  final baseTextCount = math.min(300, rootEntityCount ~/ 100);
  // Labels replace the plain floor texts one-for-one rather than adding to
  // them: with both present, a kind-text entity's `text` would sometimes be
  // '' (the floor text's own default) and sometimes a vocabulary word, which
  // is a distinct string the labelling extension did not choose and no
  // fixture should have to account for. So when labelFraction is on, every
  // root-level text entity is a label; when it is off, `labelCount` is 0 and
  // this whole block reduces to the original formula exactly.
  final labelCount = labelFraction > 0
      ? math.min(rootEntityCount, (rootEntityCount * labelFraction).round())
      : 0;
  final textCount = labelFraction > 0 ? 0 : baseTextCount;
  final remaining = rootEntityCount - textCount - labelCount;
  final lineCount = (remaining * 0.45).round();
  final polylineCount = (remaining * 0.30).round();
  final circleCount = (remaining * 0.15).round();
  final arcCount = remaining - lineCount - polylineCount - circleCount;

  for (var i = 0; i < lineCount; i++) {
    _addFloorLine(doc, originX: originX, random: random, styling: styling);
  }
  for (var i = 0; i < polylineCount; i++) {
    _addFloorPolyline(doc, originX: originX, random: random, styling: styling);
  }
  for (var i = 0; i < circleCount; i++) {
    _addFloorCircle(doc, originX: originX, random: random, styling: styling);
  }
  for (var i = 0; i < arcCount; i++) {
    _addFloorArc(doc, originX: originX, random: random, styling: styling);
  }
  for (var i = 0; i < textCount; i++) {
    _addFloorText(doc, originX: originX, random: random, styling: styling);
  }
  for (var i = 0; i < labelCount; i++) {
    _addLabelText(doc,
        originX: originX, random: random, extra: extra, styling: styling);
  }

  // --- instances: every definition placed many times, scattered across
  // the floor plan. --------------------------------------------------------
  final effectiveInstanceCount =
      instanceCount > 0 ? instanceCount : definitionCount * 25;
  var mirroredDue = 0.0;
  var nonUniformDue = 0.0;
  var attributedDue = 0.0;
  for (var i = 0; i < effectiveInstanceCount; i++) {
    final definition = definitionHandles[i % definitionHandles.length];
    final x = originX + random.nextDouble() * kFloorWidth;
    final y = kOriginY + random.nextDouble() * kFloorHeight;
    // Mostly plain translation, occasionally rotated -- a symbol dropped at
    // an angle is common in a real floor plan and exercises the transform
    // composition the index relies on, without making every instance's
    // placement a special case to reason about.
    var transform = random.nextDouble() < 0.15
        ? Transform2.translation(x, y)
            .multiply(Transform2.rotation(random.nextDouble() * math.pi * 2))
        : Transform2.translation(x, y);
    // A quota, not a coin flip. The fraction specifies the corpus, and a coin
    // flip would make it a property of the seed instead: 500 instances at 0.25
    // came out 0.308 that way, three standard deviations off, and a rig cannot
    // tell that from a real difference. Both accumulators advance every
    // instance; when they collide, mirroring wins and the non-uniform debt is
    // carried rather than dropped, so each count still lands exactly.
    //
    // A mirror is conformal — equal scale on both axes, negative determinant —
    // so it stays off the painter's anisotropy path and the two stay distinct
    // things to measure.
    mirroredDue += mirroredFraction;
    nonUniformDue += nonUniformFraction;
    if (mirroredDue >= 1.0) {
      mirroredDue -= 1.0;
      final s = 0.8 + extra.nextDouble() * 0.4;
      transform = transform.multiply(Transform2.scale(-s, s));
    } else if (nonUniformDue >= 1.0) {
      nonUniformDue -= 1.0;
      // Past kAnisotropyThreshold (2.0) on purpose: a gently squashed instance
      // would measure the fast path and be reported as coverage of the exact
      // one.
      transform = transform
          .multiply(Transform2.scale(1.0, 2.5 + extra.nextDouble() * 3));
    }
    final instanceHandle = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instanceHandle,
      parent: doc.rootHandle,
      transform: transform,
      definition: definition,
      layer: ReservedHandles.layerZero,
    )));

    // Additive, unlike labelFraction above: each attribute is a leaf the
    // root budget never accounted for, owned by the instance it tags.
    attributedDue += attributedInstanceFraction;
    if (attributedDue >= 1.0) {
      attributedDue -= 1.0;
      _addInstanceAttribute(doc,
          instance: instanceHandle, extra: extra, styling: styling, ordinal: i);
    }
  }

  return doc;
}

/// Which layer, linetype and colour an entity gets.
///
/// Every accessor returns the Plan 2 value without drawing at all when its
/// extension is off, which is what keeps the default document identical. The
/// draws are ordered layer, linetype, colour, and that order is part of the
/// fingerprint the test pins.
class _Styling {
  _Styling({
    required this.random,
    required this.layers,
    required this.dashed,
    required this.dashedFraction,
    required this.byBlockFraction,
  });

  final math.Random random;

  /// Empty when there is only layer 0.
  final List<Handle> layers;
  final Handle? dashed;
  final double dashedFraction;
  final double byBlockFraction;

  /// Which layer is a choice, so it is drawn. How *many* entities are dashed
  /// or ByBlock is a quota, for the reason given at the instance loop.
  double _dashedDue = 0;
  double _byBlockDue = 0;

  Handle layerFor() => layers.isEmpty
      ? ReservedHandles.layerZero
      : layers[random.nextInt(layers.length)];

  Handle linetypeFor() {
    final handle = dashed;
    if (handle == null) return ReservedHandles.byLayerLinetype;
    _dashedDue += dashedFraction;
    if (_dashedDue < 1.0) return ReservedHandles.byLayerLinetype;
    _dashedDue -= 1.0;
    return handle;
  }

  /// ByBlock only inside a definition: at the root there is no instance to
  /// resolve against, so it would resolve to the context and exercise nothing.
  /// The quota advances only for those, so the fraction means what it says
  /// rather than being diluted by every root entity that could not take it.
  DraftColor colorFor({required bool insideDefinition}) {
    if (!insideDefinition || byBlockFraction == 0) return const ByLayerColor();
    _byBlockDue += byBlockFraction;
    if (_byBlockDue < 1.0) return const ByLayerColor();
    _byBlockDue -= 1.0;
    return const ByBlockColor();
  }
}

Handle _addEntity(
  DraftDocument doc, {
  required Handle owner,
  required EntityKind kind,
  required List<double> coords,
  required _Styling styling,
  bool insideDefinition = false,
  List<double> scalars = const [],
  String text = '',
  String tag = '',
}) {
  final handle = doc.handleSeed.next();
  final layer = styling.layerFor();
  final linetype = styling.linetypeFor();
  final color = styling.colorFor(insideDefinition: insideDefinition);
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: layer,
      linetype: linetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: color,
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
      text: text,
      tag: tag,
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
  required _Styling styling,
  required bool insideDefinition,
}) {
  double c() => (random.nextDouble() - 0.5) * 1000.0; // +/-500 units
  switch (random.nextInt(4)) {
    case 0:
      _addEntity(doc,
          owner: owner,
          kind: EntityKind.line,
          coords: [c(), c(), c(), c()],
          styling: styling,
          insideDefinition: insideDefinition);
    case 1:
      final points = <double>[];
      final n = 3 + random.nextInt(3);
      for (var i = 0; i < n; i++) {
        points
          ..add(c())
          ..add(c());
      }
      _addEntity(doc,
          owner: owner,
          kind: EntityKind.polyline,
          coords: points,
          styling: styling,
          insideDefinition: insideDefinition);
    case 2:
      _addEntity(doc,
          owner: owner,
          kind: EntityKind.circle,
          coords: [c(), c()],
          styling: styling,
          insideDefinition: insideDefinition,
          scalars: [50.0 + random.nextDouble() * 200.0]);
    default:
      _addEntity(doc,
          owner: owner,
          kind: EntityKind.arc,
          coords: [c(), c()],
          styling: styling,
          insideDefinition: insideDefinition,
          scalars: [
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
    {required double originX,
    required math.Random random,
    required _Styling styling}) {
  final x0 = _floorX(originX, random), y0 = _floorY(random);
  final length = 50.0 + random.nextDouble() * 2950.0;
  final angle = random.nextDouble() * math.pi * 2;
  final x1 = x0 + length * math.cos(angle);
  final y1 = y0 + length * math.sin(angle);
  _addEntity(doc,
      owner: doc.rootHandle,
      kind: EntityKind.line,
      coords: [x0, y0, x1, y1],
      styling: styling);
}

void _addFloorPolyline(DraftDocument doc,
    {required double originX,
    required math.Random random,
    required _Styling styling}) {
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
      owner: doc.rootHandle,
      kind: EntityKind.polyline,
      coords: coords,
      styling: styling);
}

void _addFloorCircle(DraftDocument doc,
    {required double originX,
    required math.Random random,
    required _Styling styling}) {
  final x = _floorX(originX, random), y = _floorY(random);
  final radius = 50.0 + random.nextDouble() * 1450.0;
  _addEntity(doc,
      owner: doc.rootHandle,
      kind: EntityKind.circle,
      coords: [x, y],
      styling: styling,
      scalars: [radius]);
}

void _addFloorArc(DraftDocument doc,
    {required double originX,
    required math.Random random,
    required _Styling styling}) {
  final x = _floorX(originX, random), y = _floorY(random);
  final radius = 50.0 + random.nextDouble() * 1450.0;
  _addEntity(doc,
      owner: doc.rootHandle,
      kind: EntityKind.arc,
      coords: [x, y],
      styling: styling,
      scalars: [
        radius,
        random.nextDouble() * math.pi * 2,
        (0.25 + random.nextDouble() * 1.5) * math.pi,
      ]);
}

void _addFloorText(DraftDocument doc,
    {required double originX,
    required math.Random random,
    required _Styling styling}) {
  final x = _floorX(originX, random), y = _floorY(random);
  _addEntity(doc,
      owner: doc.rootHandle,
      kind: EntityKind.text,
      coords: [x, y],
      styling: styling,
      scalars: [100.0 + random.nextDouble() * 200.0]);
}

/// A root-level room label: a floor position from the primary [random]
/// stream (matching every other floor entity), a word from [extra] (the
/// stream [labelFraction] shares with [attributedInstanceFraction] — see
/// [generateDocument]'s doc comment).
void _addLabelText(DraftDocument doc,
    {required double originX,
    required math.Random random,
    required math.Random extra,
    required _Styling styling}) {
  final x = _floorX(originX, random), y = _floorY(random);
  final label = _kLabelVocabulary[extra.nextInt(_kLabelVocabulary.length)];
  _addEntity(doc,
      owner: doc.rootHandle,
      kind: EntityKind.text,
      coords: [x, y],
      styling: styling,
      scalars: [100.0 + random.nextDouble() * 200.0],
      text: label);
}

/// One ATTRIB leaf owned by [instance], placed in the instance's own local
/// space — never world space; see [generateDocument]'s doc comment on
/// [attributedInstanceFraction] for why. [ordinal] is the instance loop
/// index, which is unique per call and is what makes the tag value unique
/// without needing a draw for it.
void _addInstanceAttribute(
  DraftDocument doc, {
  required Handle instance,
  required math.Random extra,
  required _Styling styling,
  required int ordinal,
}) {
  // Small, symbol-scale local coordinates — the same order of magnitude as
  // `_addSymbolEntity`'s — drawn from `extra`, the stream this extension
  // shares with `labelFraction`.
  final x = (extra.nextDouble() - 0.5) * 200.0;
  final y = (extra.nextDouble() - 0.5) * 100.0;
  _addEntity(doc,
      owner: instance,
      kind: EntityKind.attrib,
      coords: [x, y],
      styling: styling,
      scalars: [80.0],
      text: 'ATTR${ordinal.toString().padLeft(5, '0')}',
      tag: 'REF');
}
