import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

GeometryPayload line(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

EntityRecord lineRecord(Handle handle, Handle owner) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

void main() {
  test('empty document has standard tables, a root, and empty extents', () {
    final doc = DraftDocument.empty();
    expect(doc.tables.layers[ReservedHandles.layerZero], isNotNull);
    expect(doc.tree[doc.rootHandle], isA<GroupNode>());
    expect(doc.extents.isEmpty, isTrue);
    // Reserved handles can never be reissued.
    expect(doc.handleSeed.next().value,
        greaterThanOrEqualTo(ReservedHandles.firstFree.value));
  });

  test('extents cover entities placed under the root', () {
    final doc = DraftDocument.empty();
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(handle, doc.rootHandle),
      payload: line(0, 0, 10, 5),
    ));
    expect(doc.extents.min, Vector2(0, 0));
    expect(doc.extents.max, Vector2(10, 5));
  });

  test('extents are recomputed after a mutation, not stale', () {
    final doc = DraftDocument.empty();
    final first = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(first, doc.rootHandle),
      payload: line(0, 0, 1, 1),
    ));
    expect(doc.extents.max, Vector2(1, 1));

    final second = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(second, doc.rootHandle),
      payload: line(0, 0, 20, 20),
    ));
    expect(doc.extents.max, Vector2(20, 20));

    doc.commands.undo();
    expect(doc.extents.max, Vector2(1, 1));
  });

  test('an instance contributes its definition bounds under its transform', () {
    final doc = DraftDocument.empty();

    final defHandle = doc.handleSeed.next();
    final entityHandle = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: defHandle,
      name: 'Unit',
      basePoint: Vector2.zero(),
      // `children` holds child nodes only; the entity below states its own
      // containment through EntityRecord.owner, which is authoritative.
      children: const [],
    ));
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(entityHandle, defHandle),
      payload: line(0, 0, 2, 2),
    ));

    // The definition alone is not placed, so it contributes nothing yet.
    expect(doc.extents.isEmpty, isTrue);

    final instance = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform:
          Transform2.translation(100, 0).multiply(Transform2.scale(3, 3)),
      definition: defHandle,
      layer: ReservedHandles.layerZero,
    )));

    expect(doc.extents.min, Vector2(100, 0));
    expect(doc.extents.max, Vector2(106, 6));
  });

  test('extents follow a node through a nested group, a remove and an undo',
      () {
    // Extents read the containers' `children` lists, which only a maintained
    // parent/children sync keeps current: the group is empty when it is added
    // and gains its child on the next command.
    final doc = DraftDocument.empty();
    final group = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.translation(50, 0),
      children: const [],
    )));

    final defHandle = doc.handleSeed.next();
    final entityHandle = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: defHandle,
      name: 'Unit',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(entityHandle, defHandle),
      payload: line(0, 0, 2, 2),
    ));

    final instance = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: group,
      transform: Transform2.identity(),
      definition: defHandle,
      layer: ReservedHandles.layerZero,
    )));
    expect(doc.extents.min, Vector2(50, 0));
    expect(doc.extents.max, Vector2(52, 2));

    // Removing unlinks it, so the group contributes nothing.
    doc.commands.execute(RemoveNodeCommand(instance));
    expect(doc.extents.isEmpty, isTrue);

    // Undo re-adds through AddNodeCommand, which links it back.
    doc.commands.undo();
    expect(doc.extents.max, Vector2(52, 2));
  });

  test('definitionBounds is computed once and reused across instances', () {
    final doc = DraftDocument.empty();
    final defHandle = doc.handleSeed.next();
    final entityHandle = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: defHandle,
      name: 'Unit',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(entityHandle, defHandle),
      payload: line(0, 0, 2, 2),
    ));
    expect(doc.definitionBounds(defHandle).max, Vector2(2, 2));
    expect(doc.definitionBounds(defHandle).max, Vector2(2, 2));
  });

  test('a command-built container and a file-loaded one hold the same leaves',
      () {
    // Two routes to one document. The command route sets EntityRecord.owner
    // and never touches `children`. The file route arrives with the leaf
    // handles listed in `children` too, which is what every older writer —
    // and every DXF BLOCK — puts there. `owner` is the single source of
    // truth, so the two must agree on what the container holds.
    final doc = DraftDocument.empty();
    final innerDef = doc.handleSeed.next();
    final outerDef = doc.handleSeed.next();
    for (final (handle, name) in [(innerDef, 'Inner'), (outerDef, 'Outer')]) {
      doc.tree.addDefinition(Definition(
        handle: handle,
        name: name,
        basePoint: Vector2.zero(),
        children: const [],
      ));
    }

    final innerLeaf = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(innerLeaf, innerDef),
      payload: line(0, 0, 1, 1),
    ));

    // Two leaves *and* a child node under the outer definition, so the two
    // kinds of containment cannot be mistaken for one another, and the leaves
    // sit on either side of the node in the older file's ordering.
    final leafA = doc.handleSeed.next();
    final leafB = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(leafA, outerDef),
      payload: line(0, 0, 2, 2),
    ));
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(leafB, outerDef),
      payload: line(-4, -4, -3, -3),
    ));
    final instance = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: outerDef,
      transform: Transform2.translation(10, 0),
      definition: innerDef,
      layer: ReservedHandles.layerZero,
    )));

    expect(doc.tree.definition(outerDef)!.children, [instance],
        reason: 'children lists the child node, and neither leaf');
    // leafB down to (-4,-4), leafA up to (2,2), the instance out to (11,1).
    expect(doc.definitionBounds(outerDef).toJson(), [-4.0, -4.0, 11.0, 2.0]);

    // The same document as an older writer would have saved it.
    final json = DraftDocumentCodec.encode(doc);
    final outer = (json['definitions']! as List)
        .cast<Map<String, Object?>>()
        .firstWhere((d) => d['handle'] == outerDef.value);
    outer['children'] = [leafA.value, instance.value, leafB.value];

    final loaded = DraftDocumentCodec.decode(json);

    // Same leaves: the leaf handles in `children` are ignored, not counted a
    // second time and not mistaken for nodes.
    expect(loaded.definitionBounds(outerDef).toJson(),
        doc.definitionBounds(outerDef).toJson());
    expect(loaded.definitionBounds(innerDef).toJson(),
        doc.definitionBounds(innerDef).toJson());
    // And not re-emitted, so the disagreement does not outlive the load.
    expect(DraftDocumentCodec.encodeToString(loaded),
        DraftDocumentCodec.encodeToString(doc));

    // RemoveEntityCommand has nothing to unlist, and needs nothing to unlist:
    // deleting a leaf that the older file also named in `children` leaves no
    // dangling handle for the next save to carry forward.
    loaded.commands.execute(RemoveEntityCommand(leafA));
    final resaved = (DraftDocumentCodec.encode(loaded)['definitions']! as List)
        .cast<Map<String, Object?>>()
        .firstWhere((d) => d['handle'] == outerDef.value);
    expect(resaved['children'], [instance.value]);
  });

  test('extents cost scales with entities, not containers x entities', () {
    // _boundsOfContainer used to answer "which live entities does *this*
    // container own?" by scanning every live entity slot and filtering on
    // ownerAt — once per container, so a recompute was O(containers x
    // entities), and invalidateDerived() fires on every command.
    //
    // Same entity count both times, twenty times the containers. Under the
    // per-container scan the second document costs twenty times the first;
    // under one bucketing pass it costs the same, because the extra work is
    // only the extra containers themselves.
    DraftDocument documentWith(int containerCount) {
      final doc = DraftDocument.empty();
      final groups = [
        for (var i = 0; i < containerCount; i++) doc.handleSeed.next(),
      ];
      for (final group in groups) {
        doc.tree.addNode(GroupNode(
          handle: group,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [],
        ));
      }
      // Written straight to the stores: 20k dispatched commands would time
      // the dispatcher, and what is under test is the bounds walk.
      for (var i = 0; i < 20000; i++) {
        final geomIndex = doc.geometry.add(line(0, 0, i.toDouble(), 1));
        doc.entities.add(lineRecord(
          doc.handleSeed.next(),
          groups[i % groups.length],
        ).copyWith(geomIndex: geomIndex));
      }
      doc.invalidateDerived();
      return doc;
    }

    int fastestRecomputeMicros(DraftDocument doc) {
      var best = -1;
      for (var run = 0; run < 5; run++) {
        doc.invalidateDerived();
        final watch = Stopwatch()..start();
        final box = doc.extents;
        watch.stop();
        expect(box.max, Vector2(19999, 1), reason: 'sanity: same box each way');
        if (best < 0 || watch.elapsedMicroseconds < best) {
          best = watch.elapsedMicroseconds;
        }
      }
      return best;
    }

    final few = documentWith(20);
    final many = documentWith(400);
    // Warm both before timing either, so JIT does not land on one of them.
    fastestRecomputeMicros(few);
    fastestRecomputeMicros(many);

    final fewMicros = fastestRecomputeMicros(few);
    final manyMicros = fastestRecomputeMicros(many);

    // Twenty times the containers; a factor of six is a wide margin around
    // "no growth" that a twenty-fold one cannot fit inside.
    expect(manyMicros, lessThan(fewMicros * 6),
        reason:
            '20 containers took ${fewMicros}us and 400 took ${manyMicros}us '
            'over the same 20000 entities');
  });

  test('purge compacts both stores, rewrites geomIndex, and clears history',
      () {
    final doc = DraftDocument.empty();
    final a = doc.handleSeed.next();
    final b = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
        record: lineRecord(a, doc.rootHandle), payload: line(0, 0, 1, 1)));
    doc.commands.execute(AddEntityCommand(
        record: lineRecord(b, doc.rootHandle), payload: line(5, 5, 6, 6)));
    doc.commands.execute(RemoveEntityCommand(a));

    doc.purge();

    final slot = doc.entities.slotOf(b)!;
    // The surviving entity still points at its own geometry after both stores
    // were renumbered.
    expect(doc.geometry.read(doc.entities.geomIndexAt(slot)).pointAt(0),
        Vector2(5, 5));
    expect(doc.geometry.liveCount, 1);
    expect(doc.commands.canUndo, isFalse,
        reason: 'purge is not undoable, so history cannot survive it');
  });

  test('purge emits DocumentPurged', () async {
    final doc = DraftDocument.empty();
    final events = <DocChange>[];
    final sub = doc.changes.listen(events.add);
    doc.purge();
    await Future<void>.delayed(Duration.zero);
    expect(events.last, isA<DocumentPurged>());
    await sub.cancel();
    await doc.dispose();
  });

  test('runtime permissions forbid geometry but allow transform', () {
    final doc = DraftDocument.empty(permissions: DraftPermissions.runtime);
    expect(
      () => doc.commands.execute(AddEntityCommand(
        record: lineRecord(const Handle(1000), doc.rootHandle),
        payload: line(0, 0, 1, 1),
      )),
      throwsA(isA<PermissionDeniedError>()),
    );
    doc.commands.execute(
        TransformNodeCommand(doc.rootHandle, Transform2.translation(1, 1)));
  });
}
