import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// Copied from `test/index/pick_test.dart` rather than imported: a test file
/// is not a library other tests build on, and the one extra parameter here
/// ([layer]) is what the filter test needs.
Handle addEntity(DraftDocument doc, Handle owner, EntityKind kind,
    List<double> coords, List<double> scalars,
    {Handle layer = ReservedHandles.layerZero}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: layer,
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

GeometryPayload pl(List<double> coords, [List<double> scalars = const []]) =>
    GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars));

/// The same non-degenerate placement `band_predicates_test.dart` uses:
/// translate, rotate 30 degrees, then scale 1.5x. Nothing below sits at the
/// identity transform, which is the degenerate fixture this package's testing
/// bar rules out.
final placement = Transform2.translation(300, -200)
    .multiply(Transform2.rotation(math.pi / 6))
    .multiply(Transform2.scale(1.5, 1.5));

/// A band around [centre] with half-size [h], in world space.
Aabb2 bandAt(Vector2 centre, double h) =>
    Aabb2.raw(centre.x - h, centre.y - h, centre.x + h, centre.y + h);

/// Copied from `test/document/region_command_test.dart`, same reason as
/// [addEntity], with the loop moved off the origin: a region sitting at
/// `(0, 0)` is the degenerate fixture this plan's constraints rule out.
GeometryPayload squareLoopAt(double x, double y) => GeometryPayload(
    coords: Float64List.fromList([
      x, y, //
      x + 10, y,
      x + 10, y + 10,
      x, y + 10,
      x, y,
    ]),
    scalars: Float64List(0));

AddRegionCommand region(
        DraftDocument doc, Handle owner, GeometryPayload loop) =>
    AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: owner,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: loop,
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );

/// Adds a [GroupNode] under the root at [transform] and returns its handle.
Handle addGroup(DraftDocument doc, Handle handle, Transform2 transform) {
  doc.commands.execute(AddNodeCommand(GroupNode(
    handle: handle,
    parent: doc.rootHandle,
    transform: transform,
    children: const [],
  )));
  return handle;
}

/// The world box the index indexes [handle] by, given the composed transform
/// [toWorld] that carries its stored coordinates into world space.
///
/// The same composition `ContainerIndex.build` performs, so a band built from
/// this is a band expressed in the terms the window rule actually decides on
/// — which is what lets a rotated fixture state an exact expectation instead
/// of a hand-computed approximation.
Aabb2 worldBoxOf(DraftDocument doc, Handle handle, Transform2 toWorld) =>
    _ownerSpaceBox(doc, doc.entities.slotOf(handle)!).transformedBy(toWorld);

Aabb2 unionOf(Iterable<Aabb2> boxes) {
  var box = Aabb2.empty();
  for (final b in boxes) {
    box = box.union(b);
  }
  return box;
}

List<int> leavesIn(SpatialIndex index, Aabb2 band, BandMode mode,
    [QueryFilter filter = const QueryFilter.all()]) {
  final out = <int>[];
  index.forEachLeafInBand(band, mode, filter, out.add);
  return out;
}

List<Handle> instancesIn(SpatialIndex index, Aabb2 band, BandMode mode,
    [QueryFilter filter = const QueryFilter.all()]) {
  final out = <Handle>[];
  index.forEachInstanceInBand(band, mode, filter, out.add);
  return out;
}

List<Handle> handlesOf(DraftDocument doc, List<int> slots) =>
    [for (final slot in slots) doc.entities.handleAt(slot)];

// --- the brute-force arm (plan Ruling 02-6) -------------------------------
//
// Deliberately **not** a second geometry implementation: it calls the very
// predicates the index calls (`boxEnclosedByBand`, `leafTouchedByBandT`) and
// composes boxes exactly as `ContainerIndex.build` does. What it checks
// independently is the broad phase, the descent into instances and groups,
// and the dedupe — the three things the index does that a direct walk of the
// document does not.

/// The local verdict type, mirroring the index's private `_BandVerdict`.
enum _Verdict { pass, fail, empty }

Map<Handle, List<int>> _leavesByOwner(DraftDocument doc) {
  final map = <Handle, List<int>>{};
  for (final slot in doc.entities.liveSlots) {
    (map[doc.entities.ownerAt(slot)] ??= <int>[]).add(slot);
  }
  return map;
}

/// One entity's box in its owner's space — the same call
/// `ContainerIndex.build` makes for every leaf it indexes.
Aabb2 _ownerSpaceBox(DraftDocument doc, int slot) => entityBounds(
      kind: doc.entities.kindAt(slot),
      payload: doc.geometry.peek(doc.entities.geomIndexAt(slot)),
      measurer: doc.textMeasurer,
      textStyle: doc.textStyleOf(doc.entities.textStyleAt(slot)),
      textAttrs: doc.entities.textAttrsAt(slot),
      text: doc.entities.textAt(slot),
    );

/// Walks one container the way `ContainerIndex.build` does: groups flattened
/// with their transforms composed in, instances kept as the sharing boundary,
/// and a leaf owned by an instance node (an ATTRIB) counted as a leaf of
/// *this* container under that instance's composed transform.
void _walkContainer(
  DraftDocument doc,
  Handle container,
  Map<Handle, List<int>> byOwner,
  void Function(int slot, Transform2 composed) onLeaf,
  void Function(InstanceNode node, Transform2 composed) onInstance,
) {
  final stack = <(Handle, Transform2)>[(container, Transform2.identity())];
  final seen = <Handle>{container};
  while (stack.isNotEmpty) {
    final (current, acc) = stack.removeLast();
    for (final slot in byOwner[current] ?? const <int>[]) {
      onLeaf(slot, acc);
    }
    final node = doc.tree[current];
    final List<Handle> children;
    if (node is GroupNode) {
      children = doc.tree.childNodesOf(node.children);
    } else {
      final definition = doc.tree.definition(current);
      children = definition == null
          ? const <Handle>[]
          : doc.tree.childNodesOf(definition.children);
    }
    for (final child in children) {
      if (!seen.add(child)) continue;
      final resolved = doc.tree[child];
      if (resolved is GroupNode) {
        stack.add((child, acc.multiply(resolved.transform)));
      } else if (resolved is InstanceNode) {
        final composed = acc.multiply(resolved.transform);
        onInstance(resolved, composed);
        for (final slot in byOwner[child] ?? const <int>[]) {
          onLeaf(slot, composed);
        }
      }
    }
  }
}

/// Whether the band takes this leaf, given its composed container-space
/// transform and the container's own placement in the world.
///
/// Returns null for a leaf the index can never reach: an empty owner-space box
/// overlaps no query rectangle, so it is in neither walk's broad phase and is
/// not a member leaf for the every-leaf window rule either. Only a fill with
/// an unresolved boundary, or a coordinate-less payload, bounds to nothing.
bool? _leafSelected(DraftDocument doc, int slot, Transform2 composed,
    Transform2 toWorld, Aabb2 band, BandMode mode) {
  final ownerBox = _ownerSpaceBox(doc, slot);
  if (ownerBox.isEmpty) return null;
  if (mode == BandMode.window) {
    // Composed exactly as the index does it: the container-space box first
    // (that is the box `ContainerIndex` stores), then lifted by the
    // container's placement. Folding the two transforms into one product
    // instead would bound a rotated box more tightly than the index can and
    // disagree on the leaves that straddle the band's edge.
    final box = ownerBox.transformedBy(composed).transformedBy(toWorld);
    return boxEnclosedByBand(box, band);
  }
  final payload = doc.geometry.peek(doc.entities.geomIndexAt(slot));
  final kind = doc.entities.kindAt(slot);
  TextBox? textBox;
  if (kind == EntityKind.text || kind == EntityKind.attrib) {
    final style = doc.textStyleOf(doc.entities.textStyleAt(slot));
    final metrics =
        doc.textMeasurer.measure(text: doc.entities.textAt(slot), style: style);
    textBox =
        textBoxOf(payload, doc.entities.textAttrsAt(slot), style, metrics);
  }
  return leafTouchedByBandT(kind, payload, toWorld.multiply(composed), band,
      textBox: textBox);
}

_Verdict _bruteContainer(
    DraftDocument doc,
    Map<Handle, List<int>> byOwner,
    Handle container,
    Transform2 toWorld,
    Aabb2 band,
    BandMode mode,
    Set<Handle> open) {
  var anyLeaf = false, allPass = true, anyPass = false;
  final instances = <(InstanceNode, Transform2)>[];
  _walkContainer(doc, container, byOwner, (slot, composed) {
    if (doc.entities.kindAt(slot) == EntityKind.fill) return;
    final verdict = _leafSelected(doc, slot, composed, toWorld, band, mode);
    if (verdict == null) return;
    anyLeaf = true;
    if (verdict) {
      anyPass = true;
    } else {
      allPass = false;
    }
  }, (node, composed) => instances.add((node, composed)));

  if (mode == BandMode.crossing && anyPass) return _Verdict.pass;
  if (mode == BandMode.window && anyLeaf && !allPass) return _Verdict.fail;

  var childPass = false;
  for (final (node, composed) in instances) {
    if (open.contains(node.definition)) continue; // cycle guard
    open.add(node.definition);
    final verdict = _bruteContainer(doc, byOwner, node.definition,
        toWorld.multiply(composed), band, mode, open);
    open.remove(node.definition);
    if (mode == BandMode.crossing) {
      if (verdict == _Verdict.pass) return _Verdict.pass;
    } else {
      if (verdict == _Verdict.fail) return _Verdict.fail;
      if (verdict == _Verdict.pass) childPass = true;
    }
  }
  if (mode == BandMode.crossing) return _Verdict.fail;
  return (anyLeaf && allPass) || childPass ? _Verdict.pass : _Verdict.empty;
}

({Set<int> leaves, Set<Handle> instances}) bruteForce(
    DraftDocument doc, Aabb2 band, BandMode mode) {
  final byOwner = _leavesByOwner(doc);
  final leaves = <int>{};
  final instances = <Handle>{};
  _walkContainer(doc, doc.rootHandle, byOwner, (slot, composed) {
    if (doc.entities.kindAt(slot) == EntityKind.fill) return;
    if (_leafSelected(doc, slot, composed, Transform2.identity(), band, mode) ==
        true) {
      leaves.add(slot);
    }
  }, (node, composed) {
    final verdict = _bruteContainer(doc, byOwner, node.definition, composed,
        band, mode, <Handle>{doc.rootHandle});
    if (verdict == _Verdict.pass) instances.add(node.handle);
  });
  return (leaves: leaves, instances: instances);
}

// --- tests ----------------------------------------------------------------

void main() {
  test('window keeps only the enclosed line; crossing adds the straddler', () {
    final doc = DraftDocument.empty();
    final inside = addEntity(
        doc, doc.rootHandle, EntityKind.line, [100, 1000, 120, 1000], []);
    final straddling = addEntity(
        doc, doc.rootHandle, EntityKind.line, [190, 1000, 230, 1000], []);
    addEntity(doc, doc.rootHandle, EntityKind.line, [300, 1000, 320, 1000], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    const band = Aabb2.raw(90, 990, 200, 1010);
    expect(handlesOf(doc, leavesIn(index, band, BandMode.window)), [inside],
        reason: 'the straddler leaves the band, so a window must not take it');
    expect(handlesOf(doc, leavesIn(index, band, BandMode.crossing)),
        [inside, straddling],
        reason: 'crossing takes anything the band touches, ascending');
  });

  test('an instance is selected where its leaf lands after the transform', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
        handle: def, name: 'D', basePoint: Vector2.zero(), children: const []));
    addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: placement,
      definition: def,
      layer: ReservedHandles.layerZero,
    )));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
        instancesIn(index, bandAt(placement.transformPoint(Vector2(5, 0)), 1),
            BandMode.crossing),
        [instance]);
    expect(instancesIn(index, bandAt(Vector2(5, 0), 1), BandMode.crossing),
        isEmpty,
        reason: "the leaf's raw local coordinates are not where it is drawn");
  });

  test(
      'an L-shaped block is not crossed by a band in the empty quadrant of '
      'its box', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
        handle: def, name: 'L', basePoint: Vector2.zero(), children: const []));
    addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    addEntity(doc, def, EntityKind.line, [0, 0, 0, 10], []);
    final at = Transform2.translation(500, 700)
        .multiply(Transform2.rotation(math.pi / 6))
        .multiply(Transform2.scale(1.5, 1.5));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: at,
      definition: def,
      layer: ReservedHandles.layerZero,
    )));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
        instancesIn(index, bandAt(at.transformPoint(Vector2(7, 7)), 1),
            BandMode.crossing),
        isEmpty,
        reason: "(7,7) is inside the block's bounding box and nowhere near "
            'either arm, which is exactly what descending past the box buys');
    expect(
        instancesIn(index, bandAt(at.transformPoint(Vector2(5, 0)), 1),
            BandMode.crossing),
        [instance]);
  });

  test('the window band sees a leaf edited since the last rebuild', () {
    final doc = DraftDocument.empty();
    final inside = addEntity(
        doc, doc.rootHandle, EntityKind.line, [100, 1000, 120, 1000], []);
    final straddler = addEntity(
        doc, doc.rootHandle, EntityKind.line, [190, 1000, 230, 1000], []);
    addEntity(doc, doc.rootHandle, EntityKind.line, [300, 1000, 320, 1000], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // A band tall enough to enclose the edited position; the straddler is
    // outside it at its original x range, so the assertion below can only
    // pass by reading the *new* geometry.
    const band = Aabb2.raw(90, 990, 200, 1030);
    expect(handlesOf(doc, leavesIn(index, band, BandMode.window)), [inside]);

    doc.commands.execute(
        SetEntityGeometryCommand(straddler, pl([100, 1020, 120, 1020])));
    expect(index.rebuildCount, 1,
        reason: 'one edit must land on the dirty overlay, not force a rebuild');

    expect(handlesOf(doc, leavesIn(index, band, BandMode.window)),
        [inside, straddler],
        reason: 'the window must read the overlay, not the stale tree box');
  });

  test('a grouped leaf inside a definition uses the group transform too', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const group = Handle(300);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
        handle: def, name: 'G', basePoint: Vector2.zero(), children: const []));
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: def,
      transform: Transform2.translation(40, 0),
      children: const [],
    )));
    addEntity(doc, group, EntityKind.line, [0, 0, 10, 0], []);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: placement,
      definition: def,
      layer: ReservedHandles.layerZero,
    )));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
        instancesIn(index, bandAt(placement.transformPoint(Vector2(45, 0)), 1),
            BandMode.crossing),
        [instance],
        reason: "the group's translation must reach the narrow phase");
    expect(
        instancesIn(index, bandAt(placement.transformPoint(Vector2(5, 0)), 1),
            BandMode.crossing),
        isEmpty,
        reason: 'and the leaf must not also be findable at its raw '
            'coordinates inside the group');
  });

  test('a window refuses an instance whose far leaf lies outside the band', () {
    // The every-leaf rule has to be decided over the *whole* definition, not
    // over the leaves the band's own local box happens to reach: descending
    // with the band pulled back into definition space finds only the near
    // line, sees every leaf it found enclosed, and passes a block that is
    // 1500 units wider than the band.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
        handle: def,
        name: 'Wide',
        basePoint: Vector2.zero(),
        children: const []));
    addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    addEntity(doc, def, EntityKind.line, [1000, 0, 1010, 0], []);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: placement,
      definition: def,
      layer: ReservedHandles.layerZero,
    )));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    Vector2 w(double x, double y) => placement.transformPoint(Vector2(x, y));
    final nearOnly = Aabb2.fromPoints([w(0, 0), w(10, 0)]).expandedBy(1);
    expect(instancesIn(index, nearOnly, BandMode.window), isEmpty,
        reason: 'the far line is not in the band, so the block is not either');
    expect(instancesIn(index, nearOnly, BandMode.crossing), [instance],
        reason: 'crossing only needs the near line');

    final both = Aabb2.fromPoints([w(0, 0), w(10, 0), w(1000, 0), w(1010, 0)])
        .expandedBy(1);
    expect(instancesIn(index, both, BandMode.window), [instance],
        reason: 'and with both lines enclosed the window does take it');
  });

  test('an instance with no selectable member leaf is never window-selected',
      () {
    // `_BandVerdict.empty` is not `_BandVerdict.pass`: a container the filter
    // has emptied has nothing inside the band, however completely the band
    // covers where it sits.
    final doc = DraftDocument.empty();
    const locked = Handle(51);
    const def = Handle(200);
    const instance = Handle(400);
    doc.tables.layers.add(const LayerRecord(
      handle: locked,
      name: 'L',
      color: IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: true,
      locked: true,
    ));
    doc.tree.addDefinition(Definition(
        handle: def,
        name: 'OnlyLocked',
        basePoint: Vector2.zero(),
        children: const []));
    addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], [], layer: locked);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: placement,
      definition: def,
      layer: ReservedHandles.layerZero,
    )));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    Vector2 w(double x, double y) => placement.transformPoint(Vector2(x, y));
    final band = Aabb2.fromPoints([w(0, 0), w(10, 0)]).expandedBy(50);
    expect(instancesIn(index, band, BandMode.window), [instance],
        reason: 'unfiltered, the block is wholly inside the band');
    expect(
        instancesIn(index, band, BandMode.window, const QueryFilter.picking()),
        isEmpty,
        reason: 'with its only leaf filtered out there is nothing to select');
    expect(
        instancesIn(
            index, band, BandMode.crossing, const QueryFilter.picking()),
        isEmpty);
  });

  test(
      'a circle is crossed outside its indexed box under a non-uniform group '
      'scale', () {
    // A circle of radius 2 under scale(2,5) is indexed by the exact
    // ellipse's box, which reaches 4 units either side of the centre in x,
    // while the narrow phase deliberately approximates it by the circle of
    // radius 2 * sqrt(10) ~= 6.3246 (see distance.dart). A broad phase that
    // were only the indexed box would reject the band below before
    // `leafTouchedByBand`, which accepts it, ever ran -- which is what
    // `_broadPhaseMargin().pick` is widened by.
    //
    // The group carries a translation as well as the non-uniform scale, and
    // the circle sits at (17, 9) in the group's space, so neither the
    // fixture nor its geometry is at the identity or the origin. A *rotation*
    // is deliberately not added on top: `Aabb2.transformedBy` is
    // conservative, so a rotated ellipse box swells past the approximated
    // radius and the gap this test exists to measure closes.
    final doc = DraftDocument.empty();
    final groupAt =
        Transform2.translation(700, -400).multiply(Transform2.scale(2, 5));
    final group = addGroup(doc, const Handle(100), groupAt);
    final circle = addEntity(doc, group, EntityKind.circle, [17, 9], [2.0]);
    // Starts inside the window band below and runs far past it.
    final straddler =
        addEntity(doc, group, EntityKind.line, [17, 17, 60, 17], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final centre = groupAt.transformPoint(Vector2(17, 9));
    final circleBox = worldBoxOf(doc, circle, groupAt);
    final rho = 2.0 * math.sqrt(10.0);
    expect(rho, greaterThan(centre.x - circleBox.minX),
        reason: 'the fixture is only meaningful past the ellipse box, which '
            'reaches ${centre.x - circleBox.minX} either side of the centre');

    expect(
        handlesOf(
            doc,
            leavesIn(index, bandAt(Vector2(centre.x + rho, centre.y), 0.3),
                BandMode.crossing)),
        [circle],
        reason: 'the approximated rim lies outside the indexed box');
    expect(
        leavesIn(index, bandAt(Vector2(centre.x + rho + 3, centre.y), 0.3),
            BandMode.crossing),
        isEmpty,
        reason: 'and the margin must not make everything nearby a hit');

    // The straddler makes the two modes disagree, per the plan's fixture
    // constraint: its box runs far past the band, its stroke enters it.
    final band = Aabb2.raw(circleBox.minX - 1, circleBox.minY - 1,
        circleBox.maxX + 22, circleBox.maxY + 31);
    expect(handlesOf(doc, leavesIn(index, band, BandMode.window)), [circle]);
    expect(handlesOf(doc, leavesIn(index, band, BandMode.crossing)),
        [circle, straddler]);
  });

  test('a collapsed instance is judged by its image, not refused', () {
    // `Transform2.scale(0, 1)` is singular, so the definition's whole body
    // collapses to one world point. A pick has nothing to measure there and
    // `_descend` says so; a band has a perfectly good question to answer --
    // is that point inside the rectangle -- and spec D8 answers yes. The
    // walk must therefore not refuse a singular transform, and must not need
    // its inverse to reach this verdict.
    //
    // `AddNodeCommand` accepts it: `commands.dart:340` checks only for a
    // duplicate handle and delegates to `tree.addNode`, whose own guard is
    // the definition-cycle check. Nothing anywhere rejects a singular
    // `Transform2` on a node.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
        handle: def,
        name: 'Flat',
        basePoint: Vector2.zero(),
        children: const []));
    addEntity(doc, def, EntityKind.line, [60, 80, 70, 80], []);
    final collapsed = Transform2.translation(300, -200)
        .multiply(Transform2.rotation(math.pi / 6))
        .multiply(Transform2.scale(0, 1));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: collapsed,
      definition: def,
      layer: ReservedHandles.layerZero,
    )));
    final image = collapsed.transformPoint(Vector2(65, 80));
    expect(collapsed.transformPoint(Vector2(60, 80)).x, closeTo(image.x, 1e-9),
        reason: 'the fixture is only a fixture if the body really collapses');
    expect(collapsed.transformPoint(Vector2(70, 80)).y, closeTo(image.y, 1e-9));

    // The straddler keeps the two modes apart and gives the band fixture an
    // entity that is crossed but not enclosed.
    final straddler = addEntity(doc, doc.rootHandle, EntityKind.line,
        [image.x - 1, image.y, image.x + 600, image.y], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final band = bandAt(image, 2);
    expect(instancesIn(index, band, BandMode.window), [instance],
        reason: 'the degenerate image is wholly inside the band');
    expect(instancesIn(index, band, BandMode.crossing), [instance]);
    expect(
        instancesIn(
            index, bandAt(Vector2(image.x + 50, image.y), 2), BandMode.window),
        isEmpty,
        reason: 'and a band that misses the image still selects nothing');

    // The brute-force arm composes forward only and has no singular guard at
    // all, so it is the independent check that the walk agrees with D8.
    for (final mode in BandMode.values) {
      final brute = bruteForce(doc, band, mode);
      expect(instancesIn(index, band, mode).toSet(), brute.instances,
          reason: '$mode');
      expect(leavesIn(index, band, mode).toSet(), brute.leaves,
          reason: '$mode');
    }
    expect(
        handlesOf(doc, leavesIn(index, band, BandMode.crossing)), [straddler],
        reason: 'the root straddler is crossed by the band');
    expect(leavesIn(index, band, BandMode.window), isEmpty,
        reason: 'and not enclosed by it');
  });

  test('a fill slot is never reported', () {
    // The region lives at (40, 60) inside a group at [placement], so neither
    // the fill's box nor the band that finds it is axis-aligned with the
    // world or anchored at the origin.
    final doc = DraftDocument.empty();
    final group = addGroup(doc, const Handle(100), placement);
    final cmd = region(doc, group, squareLoopAt(40, 60));
    doc.commands.execute(cmd);
    // Starts inside the square and runs far outside the window band.
    final straddler =
        addEntity(doc, group, EntityKind.line, [45, 65, 300, 65], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(doc.entities.kindAt(doc.entities.slotOf(cmd.fill.handle)!),
        EntityKind.fill);
    final boundary = cmd.boundary.handle;

    // Straddles the square's bottom edge in the group's own space, so the
    // fill's box (which is the boundary's box) is touched just as surely as
    // the boundary itself -- and the fill is still not reported.
    final edge = bandAt(placement.transformPoint(Vector2(45, 60)), 0.5);
    expect(
        handlesOf(doc, leavesIn(index, edge, BandMode.crossing)), [boundary]);

    final around = worldBoxOf(doc, boundary, placement).expandedBy(2);
    expect(handlesOf(doc, leavesIn(index, around, BandMode.window)), [boundary],
        reason: 'a fill is not pickable and is not band-selectable either; '
            'it follows its boundary');
    expect(handlesOf(doc, leavesIn(index, around, BandMode.crossing)),
        [boundary, straddler],
        reason: 'the straddler separates the two modes, and the fill is '
            'absent from both');
  });

  test('results are ascending by handle even when the tree order differs', () {
    // Inside a group at [placement], at y = 500 in the group's space: the
    // answer must be ascending by handle under a rotated, scaled, translated
    // container just as it is at the identity.
    final doc = DraftDocument.empty();
    final group = addGroup(doc, const Handle(100), placement);
    // Four handles taken up front, then used out of order, so the R-tree's
    // own leaf order (which follows insertion and x position) cannot be what
    // produces an ascending answer.
    final a = doc.handleSeed.next();
    final b = doc.handleSeed.next();
    final c = doc.handleSeed.next();
    final d = doc.handleSeed.next();
    void line(Handle handle, double x0, double x1) {
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: handle,
          owner: group,
          kind: EntityKind.line,
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
          coords: Float64List.fromList([x0, 500, x1, 500]),
          scalars: Float64List(0),
        ),
      ));
    }

    line(c, 100, 110); // lowest x, third handle
    line(a, 140, 150);
    line(b, 120, 130);
    line(d, 105, 400); // the straddler, and the last handle
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final band = unionOf([
      for (final h in [a, b, c]) worldBoxOf(doc, h, placement),
    ]).expandedBy(1);
    expect(handlesOf(doc, leavesIn(index, band, BandMode.window)), [a, b, c],
        reason: 'ascending by handle, not by x and not by insertion');
    expect(
        handlesOf(doc, leavesIn(index, band, BandMode.crossing)), [a, b, c, d],
        reason: "and the straddler's stroke enters the band its box leaves");
  });

  test('instances come back ascending even when the tree order differs', () {
    final doc = DraftDocument.empty();
    const def = Handle(200), wide = Handle(201);
    for (final (handle, name) in [(def, 'D'), (wide, 'W')]) {
      doc.tree.addDefinition(Definition(
          handle: handle,
          name: name,
          basePoint: Vector2.zero(),
          children: const []));
    }
    final short = addEntity(doc, def, EntityKind.line, [60, 80, 70, 80], []);
    addEntity(doc, wide, EntityKind.line, [60, 80, 400, 80], []);
    // Handle order and x order deliberately disagree, so the instance tree's
    // own spatial traversal order cannot be what produces an ascending answer.
    // Every placement is [placement] -- translation, rotation and scale all
    // non-trivial -- with the per-instance offset applied inside it.
    const a = Handle(400), b = Handle(401), c = Handle(402), d = Handle(403);
    Transform2 at(double x) => placement.multiply(Transform2.translation(x, 0));
    for (final (handle, definition, x) in [
      (a, def, 200.0),
      (b, def, 0.0),
      (c, def, 100.0),
      (d, wide, 0.0), // the straddler: one long leaf, the highest handle
    ]) {
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: handle,
        parent: doc.rootHandle,
        transform: at(x),
        definition: definition,
        layer: ReservedHandles.layerZero,
      )));
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // Exactly the three short instances' leaves, nothing more: `d`'s leaf runs
    // straight through the band and far past it.
    final band = unionOf([
      for (final x in [0.0, 100.0, 200.0]) worldBoxOf(doc, short, at(x)),
    ]).expandedBy(1);
    expect(instancesIn(index, band, BandMode.window), [a, b, c]);
    expect(instancesIn(index, band, BandMode.crossing), [a, b, c, d]);
  });

  test('a nested query inside the band visitor throws', () {
    final doc = DraftDocument.empty();
    final group = addGroup(doc, const Handle(100), placement);
    final inside = addEntity(doc, group, EntityKind.line, [60, 80, 70, 80], []);
    addEntity(doc, group, EntityKind.line, [65, 80, 400, 80], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // Wide enough that the visitor certainly fires -- a guard that is never
    // reached proves nothing -- and narrow enough that the second line
    // straddles it rather than sitting inside.
    final band = worldBoxOf(doc, inside, placement).expandedBy(1);
    expect(
        () => index.forEachLeafInBand(
            band,
            BandMode.crossing,
            const QueryFilter.all(),
            (slot) =>
                index.forEachInRect(band, const QueryFilter.all(), (_) {})),
        throwsA(isA<QueryReentrancyError>()));
    expect(
        () => index.forEachInstanceInBand(
            band, BandMode.window, const QueryFilter.all(), (_) {}),
        returnsNormally,
        reason: 'the guard must be lowered again after the throw');
    expect(leavesIn(index, band, BandMode.crossing), hasLength(2),
        reason: 'a guard that fires inside a visitor proves nothing unless '
            'the visitor is actually reached');
    expect(leavesIn(index, band, BandMode.window), hasLength(1),
        reason: 'and the straddler keeps the two modes apart here too');
  });

  test('a locked layer is skipped under picking, kept under all', () {
    final doc = DraftDocument.empty();
    const locked = Handle(51);
    doc.tables.layers.add(const LayerRecord(
      handle: locked,
      name: 'L',
      color: IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: true,
      locked: true,
    ));
    // All three leaves live in a group at [placement], off the origin.
    final group = addGroup(doc, const Handle(100), placement);
    final open = addEntity(doc, group, EntityKind.line, [60, 80, 70, 80], []);
    final shut = addEntity(doc, group, EntityKind.line, [60, 90, 70, 90], [],
        layer: locked);
    final straddler =
        addEntity(doc, group, EntityKind.line, [65, 85, 400, 85], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final band = unionOf([
      for (final h in [open, shut]) worldBoxOf(doc, h, placement),
    ]).expandedBy(1);
    expect(
        handlesOf(doc, leavesIn(index, band, BandMode.window)), [open, shut]);
    expect(
        handlesOf(
            doc,
            leavesIn(
                index, band, BandMode.window, const QueryFilter.picking())),
        [open]);
    expect(handlesOf(doc, leavesIn(index, band, BandMode.crossing)),
        [open, shut, straddler],
        reason: 'the straddler is crossed but not enclosed');
    expect(
        handlesOf(
            doc,
            leavesIn(
                index, band, BandMode.crossing, const QueryFilter.picking())),
        [open, straddler]);
  });

  test(
      'crossing and window agree with the brute-force arm on the generated '
      'corpus', () {
    final doc = generateDocument(400,
        definitionCount: 8,
        instanceCount: 40,
        nestingDepth: 2,
        mirroredFraction: 0.2,
        nonUniformFraction: 0.3,
        groupCount: 6);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final ext = doc.extents;
    final rng = math.Random(0xBAD5EED);

    // Twelve bands dropped anywhere in the extents, plus one per root
    // instance sized against *that instance's* own world box. The random
    // twelve alone never enclose or even touch an instance — a 60000 x 40000
    // floor plan against a 200-unit band — so the instance half of the
    // differential would agree vacuously, which the two counters at the
    // bottom of this test refuse to accept.
    final bands = <Aabb2>[
      for (var i = 0; i < 12; i++)
        () {
          final cx = ext.minX + rng.nextDouble() * (ext.maxX - ext.minX);
          final cy = ext.minY + rng.nextDouble() * (ext.maxY - ext.minY);
          final hw = 5 + rng.nextDouble() * 200;
          final hh = 5 + rng.nextDouble() * 200;
          return Aabb2.raw(cx - hw, cy - hh, cx + hw, cy + hh);
        }(),
    ];
    var placed = 0;
    _walkContainer(doc, doc.rootHandle, _leavesByOwner(doc), (_, __) {},
        (node, composed) {
      final box = doc.definitionBounds(node.definition).transformedBy(composed);
      if (box.isEmpty) return;
      // Cycles through under-sized, edge-straddling and enclosing bands, so
      // both `crossing` and `window` see instances taken and rejected.
      const factors = [0.35, 0.9, 1.05, 1.6];
      final f = factors[placed++ % factors.length];
      final c = box.center;
      final hw = box.size.x / 2 * f, hh = box.size.y / 2 * f;
      bands.add(Aabb2.raw(c.x - hw, c.y - hh, c.x + hw, c.y + hh));
    });

    var sawLeaves = 0, sawInstances = 0, rejectedInstances = 0;
    for (var trial = 0; trial < bands.length; trial++) {
      final band = bands[trial];
      for (final mode in BandMode.values) {
        final leaves = leavesIn(index, band, mode);
        final instances = instancesIn(index, band, mode);
        final brute = bruteForce(doc, band, mode);
        expect(leaves.toSet(), brute.leaves, reason: '$mode trial $trial');
        expect(instances.toSet(), brute.instances,
            reason: '$mode trial $trial');
        expect(
            leaves,
            orderedEquals(leaves.toList()
              ..sort((a, b) => doc.entities
                  .handleAt(a)
                  .value
                  .compareTo(doc.entities.handleAt(b).value))),
            reason: '$mode trial $trial is not in ascending handle order');
        expect(leaves.toSet(), hasLength(leaves.length),
            reason: '$mode trial $trial reported a slot twice');
        sawLeaves += leaves.length;
        sawInstances += instances.length;
        if (mode == BandMode.window && instances.isEmpty) rejectedInstances++;
      }
    }
    expect(sawLeaves, greaterThan(0),
        reason: 'a corpus where every band is empty would agree vacuously');
    expect(sawInstances, greaterThan(0), reason: 'same, for the instances');
    expect(rejectedInstances, greaterThan(0),
        reason: 'and a corpus where every window took every instance would '
            'agree just as vacuously the other way');
  });
}
