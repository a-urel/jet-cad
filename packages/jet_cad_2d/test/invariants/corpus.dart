// The fixed corpus for the differential test. Every row of the task-16
// brief's table is one builder below, each returning a document (and,
// where the row is about the *index's* internal state rather than the
// document's contents, a [CorpusDocument.primeIndex] step to reach it).
//
// Each builder embeds `expect(...)` assertions proving the fixture actually
// has the property its row claims -- a `rotated` fixture at a multiple of
// 90°, a `mirrored` fixture with a positive determinant, or a
// `deepInstances` fixture two levels deep would all pass a differential
// test that never noticed, so those properties are pinned here rather than
// left to eyeballing the numbers below.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// One fixed corpus fixture.
///
/// [build] constructs a fresh, independent [DraftDocument] every time it is
/// called -- the differential test calls it once per test block so that a
/// mutation applied in one block (see [primeIndex]) can never bleed into
/// another.
///
/// [primeIndex], when present, runs once against the [SpatialIndex] just
/// constructed over [build]'s document, before any query. It exists for the
/// two rows whose whole point is the *index's* relationship to a sequence of
/// edits (`dirtyUnderThreshold`, `dirtyOverThreshold`, `afterPurge`) rather
/// than the document's contents alone -- a freshly-constructed `SpatialIndex`
/// always rebuilds from scratch, so "pending dirty entries" or "a rebuild
/// already happened" cannot be baked into a document snapshot; they only
/// exist relative to one particular index instance that watched the edits
/// happen.
class CorpusDocument {
  const CorpusDocument(this.name, this.build, {this.primeIndex});

  final String name;
  final DraftDocument Function() build;
  final void Function(DraftDocument doc, SpatialIndex index)? primeIndex;
}

// --- shared construction helpers ------------------------------------

Handle _addEntity(
  DraftDocument doc, {
  required Handle owner,
  required EntityKind kind,
  required List<double> coords,
  List<double> scalars = const [],
  Handle? layer,
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: layer ?? ReservedHandles.layerZero,
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

Handle _addGroup(
  DraftDocument doc, {
  required Handle parent,
  required Transform2 transform,
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(GroupNode(
    handle: handle,
    parent: parent,
    transform: transform,
    children: const [],
  )));
  return handle;
}

Handle _addInstance(
  DraftDocument doc, {
  required Handle parent,
  required Handle definition,
  required Transform2 transform,
  Handle? layer,
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: handle,
    parent: parent,
    transform: transform,
    definition: definition,
    layer: layer ?? ReservedHandles.layerZero,
  )));
  return handle;
}

Handle _addDefinition(DraftDocument doc, {required String name}) {
  final handle = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
    handle: handle,
    name: name,
    basePoint: Vector2.zero(),
    children: const [],
  ));
  return handle;
}

/// A grid entity mixing kinds so a fixture built with this exercises more
/// than one narrow-phase code path: line, circle, arc and polyline in
/// rotation, plus a bare point every fifth entity.
Handle _addGridEntity(DraftDocument doc, Handle owner, int i) {
  final col = i % 20, row = i ~/ 20;
  final x = col * 10.0, y = row * 10.0;
  switch (i % 5) {
    case 0:
      return _addEntity(doc,
          owner: owner, kind: EntityKind.line, coords: [x, y, x + 3, y + 2]);
    case 1:
      return _addEntity(doc,
          owner: owner,
          kind: EntityKind.circle,
          coords: [x, y],
          scalars: [1.5]);
    case 2:
      return _addEntity(doc,
          owner: owner,
          kind: EntityKind.arc,
          coords: [x, y],
          scalars: [1.5, 0.3, 1.2]);
    case 3:
      return _addEntity(doc,
          owner: owner,
          kind: EntityKind.polyline,
          coords: [x, y, x + 2, y + 1, x + 3, y - 1]);
    default:
      return _addEntity(doc,
          owner: owner, kind: EntityKind.point, coords: [x, y]);
  }
}

DraftDocument _buildGrid(int count) {
  final doc = DraftDocument.empty();
  for (var i = 0; i < count; i++) {
    _addGridEntity(doc, doc.rootHandle, i);
  }
  return doc;
}

/// Removes [handle]'s entity and adds a *different*, freshly-handled entity
/// with the same kind but a shifted position, at [owner]. Used to generate a
/// genuine dirty-list entry: reusing the freed slot for a box that does
/// *not* match what was there before is what defeats the "revive a dead
/// entry with an identical box" shortcut in `SpatialIndex._reconcileEntity`
/// and forces a real `DirtyList.put`.
void _replaceWithShiftedEntity(DraftDocument doc, Handle handle, double shift) {
  final slot = doc.entities.slotOf(handle)!;
  final record = doc.entities.read(slot);
  final payload = doc.geometry.peek(record.geomIndex);
  final shiftedCoords = Float64List(payload.coords.length);
  for (var i = 0; i < shiftedCoords.length; i += 2) {
    shiftedCoords[i] = payload.coords[i] + shift;
    shiftedCoords[i + 1] = payload.coords[i + 1] + shift;
  }
  doc.commands.execute(RemoveEntityCommand(handle));
  final newHandle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: record.copyWith(handle: newHandle),
    payload: GeometryPayload(
        coords: shiftedCoords, scalars: Float64List.fromList(payload.scalars)),
  ));
}

/// The deepest instance-nesting reached from [container], for pinning
/// `deepInstances`' claimed depth. A tiny, self-contained walk -- not shared
/// with `reference_query.dart` or any index code -- since it exists purely
/// to validate a corpus fixture at build time, not to answer a query.
int _maxInstanceDepth(DraftDocument doc, Handle container, int depth) {
  var maxDepth = depth;
  final node = doc.tree[container];
  final children = node is GroupNode
      ? node.children
      : (doc.tree.definition(container)?.children ?? const <Handle>[]);
  for (final childHandle in children) {
    final child = doc.tree[childHandle];
    switch (child) {
      case GroupNode():
        maxDepth =
            math.max(maxDepth, _maxInstanceDepth(doc, childHandle, depth));
      case InstanceNode(:final definition):
        maxDepth =
            math.max(maxDepth, _maxInstanceDepth(doc, definition, depth + 1));
      case null:
        break;
    }
  }
  return maxDepth;
}

// --- fixtures --------------------------------------------------------

CorpusDocument _empty() => CorpusDocument('empty', () {
      final doc = DraftDocument.empty();
      expect(doc.entities.liveCount, 0);
      expect(doc.tree.definitions, isEmpty);
      expect(doc.tree.nodes.length, 1, reason: 'just the root group');
      return doc;
    });

CorpusDocument _single() => CorpusDocument('single', () {
      final doc = DraftDocument.empty();
      _addEntity(doc,
          owner: doc.rootHandle, kind: EntityKind.line, coords: [0, 0, 5, 5]);
      expect(doc.entities.liveCount, 1);
      return doc;
    });

CorpusDocument _flatGrid() => CorpusDocument('flatGrid', () {
      final doc = _buildGrid(400);
      expect(doc.entities.liveCount, 400);
      expect(doc.extents.isEmpty, isFalse);
      return doc;
    });

CorpusDocument _deepInstances() => CorpusDocument('deepInstances', () {
      final doc = DraftDocument.empty();
      final d3 = _addDefinition(doc, name: 'D3');
      _addEntity(doc, owner: d3, kind: EntityKind.line, coords: [0, 0, 1, 1]);

      final d2 = _addDefinition(doc, name: 'D2');
      // A rotation at this level, not another translation: translations
      // commute under composition (translate(a).multiply(translate(b)) ==
      // translate(b).multiply(translate(a))), so an all-translation chain
      // would not distinguish a correct instance-transform composition
      // order from a reversed one. Mixing in a rotation is what makes this
      // fixture able to catch that mutation.
      _addInstance(doc,
          parent: d2,
          definition: d3,
          transform:
              Transform2.rotation(0.6).multiply(Transform2.translation(4, 0)));

      final d1 = _addDefinition(doc, name: 'D1');
      _addInstance(doc,
          parent: d1, definition: d2, transform: Transform2.translation(0, 4));

      _addInstance(doc,
          parent: doc.rootHandle,
          definition: d1,
          transform: Transform2.scale(1.5, 1.5)
              .multiply(Transform2.translation(10, 10)));

      expect(_maxInstanceDepth(doc, doc.rootHandle, 0), 3,
          reason: 'root -> instance(D1) -> instance(D2) -> instance(D3) -> '
              'leaf is three instance boundaries deep');
      return doc;
    });

CorpusDocument _groupsInDefinitions() =>
    CorpusDocument('groupsInDefinitions', () {
      final doc = DraftDocument.empty();

      // Groups nested inside a definition: the case the brief says the
      // first draft of the design missed entirely.
      final dg = _addDefinition(doc, name: 'Dg');
      final g1 =
          _addGroup(doc, parent: dg, transform: Transform2.rotation(0.4));
      final g2 =
          _addGroup(doc, parent: g1, transform: Transform2.translation(1, 0));
      _addEntity(doc, owner: g2, kind: EntityKind.line, coords: [0, 0, 1, 1]);
      _addEntity(doc,
          owner: g2, kind: EntityKind.circle, coords: [2, 2], scalars: [0.5]);
      _addInstance(doc,
          parent: doc.rootHandle,
          definition: dg,
          transform: Transform2.translation(100, 100));

      expect(doc.tree[g1], isA<GroupNode>());
      expect((doc.tree[g1]! as GroupNode).children, contains(g2));
      expect(doc.tree[g2], isA<GroupNode>());
      expect(doc.tree.definition(dg)!.children, contains(g1),
          reason: 'g1 must be nested directly inside the definition');

      // Groups inside groups, directly under the root (no definition
      // involved at all).
      final groot = _addGroup(doc,
          parent: doc.rootHandle, transform: Transform2.translation(-50, -50));
      final groot2 =
          _addGroup(doc, parent: groot, transform: Transform2.rotation(0.9));
      _addEntity(doc,
          owner: groot2,
          kind: EntityKind.circle,
          coords: [0, 0],
          scalars: [2.0]);

      expect(doc.tree[groot], isA<GroupNode>());
      expect((doc.tree[groot]! as GroupNode).children, contains(groot2));
      expect(doc.tree[groot2], isA<GroupNode>());

      return doc;
    });

CorpusDocument _mirrored() => CorpusDocument('mirrored', () {
      final doc = DraftDocument.empty();
      final def = _addDefinition(doc, name: 'Mirror');
      _addEntity(doc,
          owner: def, kind: EntityKind.circle, coords: [0, 0], scalars: [3.0]);
      // A partial sweep, not a full circle: a mutation that drops the arc
      // sweep check needs somewhere the "missing" part of the circle can be
      // picked to be observable.
      _addEntity(doc,
          owner: def,
          kind: EntityKind.arc,
          coords: [6, 0],
          scalars: [2.0, 0.2, 1.5]);
      _addEntity(doc, owner: def, kind: EntityKind.line, coords: [0, 0, 4, 4]);

      final transform = Transform2.scale(-1, 1);
      expect(transform.determinant, lessThan(0),
          reason: 'this fixture exists to test a negative-determinant '
              'instance transform');
      _addInstance(doc,
          parent: doc.rootHandle, definition: def, transform: transform);
      return doc;
    });

CorpusDocument _nonUniformScale() => CorpusDocument('nonUniformScale', () {
      final doc = DraftDocument.empty();
      final def = _addDefinition(doc, name: 'NonUniform');
      _addEntity(doc,
          owner: def, kind: EntityKind.circle, coords: [0, 0], scalars: [2.0]);
      _addEntity(doc,
          owner: def,
          kind: EntityKind.arc,
          coords: [5, 0],
          scalars: [2.0, 0.1, 1.4]);
      _addEntity(doc, owner: def, kind: EntityKind.line, coords: [0, 0, 3, 1]);

      final transform = Transform2.scale(2, 5);
      expect(transform.a, 2.0);
      expect(transform.d, 5.0);
      expect(transform.a, isNot(equals(transform.d)),
          reason: 'this fixture exists to test a non-uniform instance scale');
      _addInstance(doc,
          parent: doc.rootHandle, definition: def, transform: transform);
      return doc;
    });

CorpusDocument _rotated() => CorpusDocument('rotated', () {
      final doc = DraftDocument.empty();
      final def = _addDefinition(doc, name: 'Rotated');
      _addEntity(doc, owner: def, kind: EntityKind.line, coords: [0, 0, 4, 0]);
      _addEntity(doc,
          owner: def, kind: EntityKind.circle, coords: [2, 2], scalars: [1.0]);

      final transform = Transform2.rotation(0.7);
      // A multiple of 90 degrees would have either `a` or `b` be exactly
      // zero (0 rad: a=1,b=0; pi/2: a=0,b=1; and so on) -- an axis-aligned
      // rotation, where a shortcut that special-cases axes could silently
      // pass. Asserting both are meaningfully non-zero pins that 0.7 rad is
      // genuinely not one of those angles.
      expect(transform.a.abs(), greaterThan(0.01));
      expect(transform.b.abs(), greaterThan(0.01));
      _addInstance(doc,
          parent: doc.rootHandle, definition: def, transform: transform);
      return doc;
    });

CorpusDocument _largeCoordinates() => CorpusDocument('largeCoordinates', () {
      final doc = DraftDocument.empty();
      const base = 4.5e6;
      final handles = <Handle>[];
      for (var i = 0; i < 20; i++) {
        handles.add(_addEntity(doc,
            owner: doc.rootHandle,
            kind: EntityKind.line,
            coords: [base + i * 5, base, base + i * 5 + 3, base + 2]));
      }
      handles.add(_addEntity(doc,
          owner: doc.rootHandle,
          kind: EntityKind.circle,
          coords: [base + 50, base + 50],
          scalars: [4.0]));

      // The property this row exists to catch: the *entities themselves*
      // sit far from the origin, not merely a container translation with
      // near-origin geometry underneath it.
      for (final h in handles) {
        final slot = doc.entities.slotOf(h)!;
        final payload = doc.geometry.peek(doc.entities.geomIndexAt(slot));
        for (final c in payload.coords) {
          expect(c.abs(), greaterThan(1e6),
              reason: 'every raw coordinate must itself be large, not just '
                  'the document extents');
        }
      }
      expect(doc.extents.minX, greaterThan(1e6));
      return doc;
    });

/// A definition whose contents grow *after* the index over it was built.
///
/// The row this corpus was missing, and the one that made "add an entity to a
/// block definition" invisible through every instance: the entity lands on
/// the definition's own dirty overlay -- one entry, far below the rebuild
/// floor of 64 -- while every instance box that places that definition still
/// describes it as it was, so no query ever steps in far enough to see it.
/// `sharedDefinition` above cannot catch it, because its definition is
/// complete before the index exists.
///
/// Both new entities sit well outside the definition's original bound of
/// [0, 1]^2, and the arc is there so the snap trials exercise a centre that
/// only became reachable because the instance boxes grew.
CorpusDocument _definitionGrownAfterBuild() => CorpusDocument(
      'definitionGrownAfterBuild',
      () {
        final doc = DraftDocument.empty();
        final def = _addDefinition(doc, name: 'Grown');
        _addEntity(doc,
            owner: def, kind: EntityKind.line, coords: [0, 0, 1, 1]);
        for (final offset in const [0.0, 50.0, 100.0]) {
          _addInstance(doc,
              parent: doc.rootHandle,
              definition: def,
              transform: Transform2.translation(offset, offset));
        }
        return doc;
      },
      primeIndex: (doc, index) {
        final def =
            doc.tree.definitions.firstWhere((d) => d.name == 'Grown').handle;
        final before = index.rebuildCount;
        _addEntity(doc,
            owner: def, kind: EntityKind.line, coords: [20, 20, 21, 21]);
        _addEntity(doc,
            owner: def,
            kind: EntityKind.arc,
            coords: [-15, -15],
            scalars: [4.0, 0.1, 0.3]);
        // Out and back: a third entity pushes the definition much further
        // still, and is then removed again. Growth alone is monotone, so
        // without a way back every instance box would stay stretched to
        // (300, 300) and this row would report instances over an empty
        // region that the brute-force oracle -- which re-derives every
        // definition bound from the document -- knows nothing about.
        final transient = _addEntity(doc,
            owner: def, kind: EntityKind.line, coords: [300, 300, 301, 301]);
        doc.commands.execute(RemoveEntityCommand(transient));
        expect(index.rebuildCount, before,
            reason: 'this row is about reconciliation reaching the instance '
                'boxes; a rebuild would re-derive them for its own reasons '
                'and the row would prove nothing');
      },
    );

CorpusDocument _sharedDefinition() => CorpusDocument('sharedDefinition', () {
      final doc = DraftDocument.empty();
      final def = _addDefinition(doc, name: 'Shared');
      _addEntity(doc, owner: def, kind: EntityKind.line, coords: [0, 0, 1, 1]);
      _addEntity(doc,
          owner: def,
          kind: EntityKind.circle,
          coords: [0.5, 0.5],
          scalars: [0.3]);

      for (var i = 0; i < 300; i++) {
        final col = i % 20, row = i ~/ 20;
        _addInstance(doc,
            parent: doc.rootHandle,
            definition: def,
            transform: Transform2.translation(col * 5.0, row * 5.0));
      }

      final placements = doc.tree.nodes
          .whereType<InstanceNode>()
          .where((n) => n.definition == def);
      expect(placements.length, 300);
      return doc;
    });

/// Shared by the two dirty-state rows below: 400 root-level lines, which
/// puts `ContainerIndex.rebuildThreshold` (`max(64, 0.05 * leafCount)`) at a
/// fixed, known 64 -- pinned by an assertion in each row's `primeIndex`
/// rather than trusted to stay 64 if this count ever changes.
DraftDocument _buildDirtyBase() {
  final doc = DraftDocument.empty();
  for (var i = 0; i < 400; i++) {
    _addEntity(doc,
        owner: doc.rootHandle,
        kind: EntityKind.line,
        coords: [i * 3.0, 0, i * 3.0 + 1, 1]);
  }
  return doc;
}

List<Handle> _sortedHandles(DraftDocument doc) =>
    doc.entities.liveSlots.map(doc.entities.handleAt).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

CorpusDocument _dirtyUnderThreshold() => CorpusDocument(
      'dirtyUnderThreshold',
      _buildDirtyBase,
      primeIndex: (doc, index) {
        final threshold = index.indexFor(doc.rootHandle)!.rebuildThreshold;
        expect(threshold, 64,
            reason: 'fixture assumes 400 root leaves -> threshold 64; if '
                'this changes, the dirty count below must stay under it');

        const dirtyCount = 30;
        expect(dirtyCount, lessThan(threshold));
        final handles = _sortedHandles(doc);
        for (var i = 0; i < dirtyCount; i++) {
          _replaceWithShiftedEntity(doc, handles[i], 5000.0 + i);
        }

        expect(index.rebuildCount, 1,
            reason: 'must stay below threshold: no rebuild yet');
        expect(index.indexFor(doc.rootHandle)!.dirty.length, dirtyCount,
            reason: 'the dirty overlay must hold exactly the entries just '
                'written, not have silently revived any of them');
      },
    );

CorpusDocument _dirtyOverThreshold() => CorpusDocument(
      'dirtyOverThreshold',
      _buildDirtyBase,
      primeIndex: (doc, index) {
        final threshold = index.indexFor(doc.rootHandle)!.rebuildThreshold;
        expect(threshold, 64);

        const total = 90; // > 64: crosses the threshold mid-sequence
        final handles = _sortedHandles(doc);
        final rebuildCountBefore = index.rebuildCount;
        for (var i = 0; i < total; i++) {
          _replaceWithShiftedEntity(doc, handles[i], 5000.0 + i);
        }

        expect(index.rebuildCount, greaterThan(rebuildCountBefore),
            reason: 'crossing the threshold mid-sequence must trigger an '
                'automatic rebuild, exercising the transition rather than '
                'only ever the freshly-built or only-ever-dirty states');
        final finalDirty = index.indexFor(doc.rootHandle)!.dirty.length;
        expect(finalDirty, greaterThan(0),
            reason: 'edits after the automatic rebuild must still leave a '
                'few pending, so queries also exercise the overlay again '
                'after the rebuild, not just before it');
        expect(finalDirty, lessThanOrEqualTo(threshold));
      },
    );

CorpusDocument _afterPurge() => CorpusDocument(
      'afterPurge',
      () {
        final doc = DraftDocument.empty();
        final handles = <Handle>[
          for (var i = 0; i < 60; i++)
            _addEntity(doc,
                owner: doc.rootHandle,
                kind: EntityKind.line,
                coords: [i * 2.0, 0, i * 2.0 + 1, 1]),
        ];
        for (var i = 0; i < handles.length; i += 3) {
          doc.commands.execute(RemoveEntityCommand(handles[i]));
        }
        expect(doc.entities.liveCount, lessThan(60));
        final liveSlots = doc.entities.liveSlots.toList();
        expect(liveSlots.any((s) => s >= doc.entities.liveCount), isTrue,
            reason: 'the fixture needs actual holes for purge() to have '
                'anything to renumber');
        return doc;
      },
      primeIndex: (doc, index) {
        final rebuildsBefore = index.rebuildCount;
        doc.purge();
        expect(index.rebuildCount, greaterThan(rebuildsBefore),
            reason: 'purge() must trigger a full reindex through the '
                'DocumentPurged hook, not leave the index reading stale '
                'slot numbers');
        final liveSlots = doc.entities.liveSlots.toList();
        for (var i = 0; i < liveSlots.length; i++) {
          expect(liveSlots[i], i,
              reason: 'purge() must leave slots dense starting at 0');
        }
      },
    );

CorpusDocument _afterUndoReusingSlot() =>
    CorpusDocument('afterUndoReusingSlot', () {
      final doc = DraftDocument.empty();
      final a = _addEntity(doc,
          owner: doc.rootHandle, kind: EntityKind.line, coords: [0, 0, 1, 1]);
      final b = _addEntity(doc,
          owner: doc.rootHandle, kind: EntityKind.line, coords: [2, 2, 3, 3]);
      final c = _addEntity(doc,
          owner: doc.rootHandle, kind: EntityKind.line, coords: [4, 4, 5, 5]);
      doc.commands.execute(RemoveEntityCommand(b));
      // Reuses b's freed slot (SlotAllocator's free list is LIFO and has
      // exactly one entry here), while taking a handle greater than c's.
      final d = _addEntity(doc,
          owner: doc.rootHandle, kind: EntityKind.line, coords: [6, 6, 7, 7]);

      final slotC = doc.entities.slotOf(c)!;
      final slotD = doc.entities.slotOf(d)!;
      expect(slotD, lessThan(slotC),
          reason: 'the fixture is only meaningful if slot order disagrees '
              'with handle order');
      expect(d.value, greaterThan(c.value));
      expect(a.value, lessThan(c.value));
      return doc;
    });

CorpusDocument _textDefaultMeasurer() =>
    CorpusDocument('textDefaultMeasurer', () {
      final doc = DraftDocument.empty();
      final measurer = doc.textMeasurer;

      void assertDegenerate(Handle h) {
        final slot = doc.entities.slotOf(h)!;
        final record = doc.entities.read(slot);
        final box = entityBounds(
          kind: record.kind,
          payload: doc.geometry.peek(record.geomIndex),
          measurer: measurer,
          textStyle: ReservedHandles.standardTextStyle,
        );
        expect(box.minX, box.maxX,
            reason: 'InsertionPointMeasurer must produce a zero-area box');
        expect(box.minY, box.maxY);
      }

      for (var i = 0; i < 10; i++) {
        final h = _addEntity(doc,
            owner: doc.rootHandle,
            kind: EntityKind.text,
            coords: [i * 3.0, i * 2.0],
            scalars: [2.5]);
        assertDegenerate(h);
      }

      // An ATTRIB owned by an instance node, not the root -- exercising the
      // same degenerate-box path through a placed definition.
      final def = _addDefinition(doc, name: 'WithAttrib');
      _addEntity(doc, owner: def, kind: EntityKind.line, coords: [0, 0, 1, 1]);
      final inst = _addInstance(doc,
          parent: doc.rootHandle,
          definition: def,
          transform: Transform2.translation(50, 50));
      final attrib = _addEntity(doc,
          owner: inst,
          kind: EntityKind.attrib,
          coords: [0.5, 0.5],
          scalars: [1.0]);
      assertDegenerate(attrib);

      return doc;
    });

/// Two lines whose real segments come nowhere near each other or the query
/// point, but whose *infinite* extensions cross exactly at the origin.
///
/// **Not one of the task-16 brief's fifteen named rows.** Added after
/// mutation-testing the differential harness found a real hole: dropping
/// `segmentIntersection`'s segment clamp (the "return the infinite-line
/// intersection" mutation) went uncaught by every fixture above, because
/// none of them contains two root-level lines whose segments *don't* cross
/// but whose infinite extensions *do*, near a point close enough to a
/// random trial to be sampled in 200 tries. See the task-16 report,
/// "Mutation 5 / corpus hole", for the full account.
///
/// **Deliberately axis-aligned, not diagonal.** An earlier version of this
/// fixture used two diagonal lines (`y = x` and `y = -x`), which pins down
/// the "masked by a closer, higher-priority candidate" hazard but turned out
/// to make the *broad-phase* window that both lines' boxes are
/// simultaneously reachable from vanishingly small -- a single point, not a
/// sampleable region, since a diagonal segment's bounding box and its
/// nearest point coincide. Two axis-aligned segments (`y = 0` and `x = 0`)
/// decouple those two boxes' zero-width/zero-height overlap conditions along
/// perpendicular axes, leaving a genuinely samplable few-unit-square window
/// where a random trial can land -- confirmed against both this suite's
/// fixed seeds (20260730, 20260731) before being kept at these exact
/// coordinates.
///
/// Each segment's near endpoint sits exactly 3.0 from the origin — past the
/// snap query's fixed `radius = 2.0` — so no endpoint, midpoint or
/// nearest/perpendicular candidate from either line is ever a competing
/// candidate near the origin; only the (illegitimate, clamp-dropped)
/// intersection candidate would be found there at all.
CorpusDocument _nearMissIntersection() =>
    CorpusDocument('nearMissIntersection', () {
      final doc = DraftDocument.empty();
      // Horizontal: y = 0, x from 3 to 10 -- does not reach x = 0.
      final a = _addEntity(doc,
          owner: doc.rootHandle, kind: EntityKind.line, coords: [3, 0, 6, 0]);
      // Vertical: x = 0, y from 3 to 10 -- does not reach y = 0.
      final b = _addEntity(doc,
          owner: doc.rootHandle, kind: EntityKind.line, coords: [0, 3, 0, 6]);

      final origin = Vector2.zero();
      expect(distanceToSegment(origin, Vector2(3, 0), Vector2(6, 0)),
          greaterThan(2.0),
          reason: 'segment a must stay further than the snap radius from '
              'the origin, or its own endpoint/nearest candidates would '
              'mask the bug this fixture exists to catch');
      expect(distanceToSegment(origin, Vector2(0, 3), Vector2(0, 6)),
          greaterThan(2.0));
      final hit = segmentIntersectionTol(Vector2(3, 0), Vector2(6, 0),
          Vector2(0, 3), Vector2(0, 6), Tolerance.standard);
      expect(hit, isNull,
          reason: 'the real (clamped) segments must NOT cross -- only '
              "their infinite extensions do, which is exactly what this "
              'fixture exists to distinguish');
      expect(doc.extents, const _Aabb2Matcher(0, 0, 6, 6));
      expect(a.value, isNot(b.value));
      return doc;
    });

/// Matches an [Aabb2] by value -- there is no `operator ==` on [Aabb2] (see
/// its own file), so this is the corpus's own small equality check, used
/// only to pin [_nearMissIntersection]'s extents at build time.
class _Aabb2Matcher extends Matcher {
  const _Aabb2Matcher(this.minX, this.minY, this.maxX, this.maxY);
  final double minX, minY, maxX, maxY;

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) =>
      item is Aabb2 &&
      item.minX == minX &&
      item.minY == minY &&
      item.maxX == maxX &&
      item.maxY == maxY;

  @override
  Description describe(Description description) =>
      description.add('Aabb2($minX, $minY .. $maxX, $maxY)');
}

/// The fixed corpus. One builder per row of the task-16 brief's table, in
/// the brief's own order, plus [_nearMissIntersection] -- see its own doc
/// comment for why it was added.
List<CorpusDocument> buildCorpus() => [
      _empty(),
      _single(),
      _flatGrid(),
      _deepInstances(),
      _groupsInDefinitions(),
      _mirrored(),
      _nonUniformScale(),
      _rotated(),
      _largeCoordinates(),
      _sharedDefinition(),
      _definitionGrownAfterBuild(),
      _dirtyUnderThreshold(),
      _dirtyOverThreshold(),
      _afterPurge(),
      _afterUndoReusingSlot(),
      _textDefaultMeasurer(),
      _nearMissIntersection(),
    ];
