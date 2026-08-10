import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addLine(DraftDocument doc, Handle owner, Handle handle,
    [double x = 0, double y = 0]) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
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
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y, x + 1, y]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Handle define(DraftDocument doc, Handle def) {
  doc.tree.addDefinition(Definition(
      handle: def, name: 'sym', basePoint: Vector2.zero(), children: const []));
  return def;
}

/// Runs [action] and returns the change it published.
///
/// `changes` is an asynchronous broadcast stream — `onAfterMutate` is the
/// synchronous channel, and `SpatialIndex` already owns that single slot. A
/// derived structure that only has to be right by the next *frame* takes the
/// stream, which is what this map is built for.
Future<DocChange> changeFrom(DraftDocument doc, void Function() action) {
  final next = doc.changes.first;
  action();
  return next;
}

/// Every owner's bucket, as a fresh full derivation would give it.
Map<Handle, List<int>> fullDerivation(DraftDocument doc) => {
      for (final entry in doc.leavesByOwner().entries)
        entry.key: List<int>.from(entry.value)..sort()
    };

void expectMatchesFullRebuild(LeafOwnerMap map, DraftDocument doc) {
  final expected = fullDerivation(doc);
  for (final entry in expected.entries) {
    expect(map.slotsOf(entry.key), orderedEquals(entry.value),
        reason: 'bucket for ${entry.key} drifted from a full derivation');
  }
  for (final owner in doc.leavesByOwner().keys) {
    expect(map.slotsOf(owner), isNotEmpty);
  }
}

void main() {
  test('a node transform costs no rebuild', () async {
    // leavesByOwner() is a full live-slot scan that allocates a fresh map. R4b
    // issues one TransformNodeCommand per frame at 500k entities; rebuilding
    // here would turn that rig into a measurement of this scan.
    final doc = generateDocument(5000, definitionCount: 20);
    final map = LeafOwnerMap(doc);
    final before = map.rebuildCount;

    const node = Handle(90000);
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: node,
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    )));
    map.applyChange(await changeFrom(
        doc,
        () => doc.commands.execute(
            TransformNodeCommand(node, Transform2.translation(1, 1)))));

    expect(map.rebuildCount, before);
  });

  test('an added entity lands in its owner bucket without a full rebuild',
      () async {
    final doc = DraftDocument.empty();
    final def = define(doc, const Handle(500));
    addLine(doc, def, const Handle(700));
    final map = LeafOwnerMap(doc);
    final before = map.slotsOf(def).length;
    final rebuilds = map.rebuildCount;

    late Handle handle;
    map.applyChange(await changeFrom(
        doc, () => handle = addLine(doc, def, const Handle(701))));

    expect(map.slotsOf(def), hasLength(before + 1));
    expect(map.slotsOf(def), contains(doc.entities.slotOf(handle)));
    expect(map.rebuildCount, rebuilds);
  });

  test('a removed entity leaves its bucket without a full rebuild', () async {
    // The removal path cannot ask the store for the slot — it is gone. The map
    // has to remember it. Getting this wrong leaves a dead slot in the bucket,
    // which the painter would then draw.
    final doc = DraftDocument.empty();
    final def = define(doc, const Handle(500));
    addLine(doc, def, const Handle(700));
    final doomed = addLine(doc, def, const Handle(701));
    final map = LeafOwnerMap(doc);
    final slot = doc.entities.slotOf(doomed)!;
    final rebuilds = map.rebuildCount;

    map.applyChange(await changeFrom(
        doc, () => doc.commands.execute(RemoveEntityCommand(doomed))));

    expect(map.slotsOf(def), isNot(contains(slot)));
    expect(map.slotsOf(def), hasLength(1));
    expect(map.rebuildCount, rebuilds);
  });

  test('a slot reused by another owner does not keep the old one', () async {
    // Slots come off a free list, so the slot a removed entity vacated is the
    // slot the next added entity gets. A map that only ever adds would report
    // that slot under both owners, and the painter would draw the new entity
    // inside the old definition.
    final doc = DraftDocument.empty();
    final a = define(doc, const Handle(500));
    final b = define(doc, const Handle(501));
    final doomed = addLine(doc, a, const Handle(700));
    final map = LeafOwnerMap(doc);
    final freed = doc.entities.slotOf(doomed)!;

    map.applyChange(await changeFrom(
        doc, () => doc.commands.execute(RemoveEntityCommand(doomed))));
    late Handle reborn;
    map.applyChange(await changeFrom(
        doc, () => reborn = addLine(doc, b, const Handle(701))));

    expect(doc.entities.slotOf(reborn), freed,
        reason: 'the fixture only means something if the slot is reused');
    expect(map.slotsOf(a), isEmpty);
    expect(map.slotsOf(b), [freed]);
  });

  test('undoing an add takes the slot back out', () async {
    final doc = DraftDocument.empty();
    final def = define(doc, const Handle(500));
    addLine(doc, def, const Handle(700));
    final map = LeafOwnerMap(doc);

    late Handle added;
    map.applyChange(await changeFrom(
        doc, () => added = addLine(doc, def, const Handle(701))));
    final slot = doc.entities.slotOf(added)!;
    expect(map.slotsOf(def), contains(slot));

    map.applyChange(await changeFrom(doc, doc.commands.undo));
    expect(map.slotsOf(def), isNot(contains(slot)));
    expectMatchesFullRebuild(map, doc);
  });

  test('a purge forces a full rebuild', () {
    // DocumentPurged renumbers slots, so every slot-keyed structure is invalid
    // and there is no incremental path back — the same answer SpatialIndex
    // gives.
    final doc = generateDocument(1000, definitionCount: 5);
    final map = LeafOwnerMap(doc);
    final rebuilds = map.rebuildCount;
    map.applyChange(const DocumentPurged());
    expect(map.rebuildCount, rebuilds + 1);
  });

  test('a load forces a full rebuild', () {
    final doc = generateDocument(1000, definitionCount: 5);
    final map = LeafOwnerMap(doc);
    final rebuilds = map.rebuildCount;
    map.applyChange(const DocumentLoaded());
    expect(map.rebuildCount, rebuilds + 1);
  });

  test('an empty touched set means the whole document changed', () {
    // DocChange documents it that way, and a change that names nothing cannot
    // be reconciled handle by handle.
    final doc = generateDocument(1000, definitionCount: 5);
    final map = LeafOwnerMap(doc);
    final rebuilds = map.rebuildCount;
    map.applyChange(const CommandApplied(label: 'opaque', touched: {}));
    expect(map.rebuildCount, rebuilds + 1);
  });

  test('buckets stay ascending by slot after an incremental add', () async {
    final doc = generateDocument(1000, definitionCount: 5);
    final map = LeafOwnerMap(doc);
    map.applyChange(await changeFrom(
        doc, () => addLine(doc, doc.rootHandle, const Handle(90000))));

    final slots = map.slotsOf(doc.rootHandle);
    expect(slots, orderedEquals(List<int>.from(slots)..sort()));
  });

  test('a run of edits leaves the same map a full rebuild would', () async {
    // The incremental path is an optimisation of one derivation. Anything it
    // gets wrong shows up here, whatever the mechanism.
    final doc = generateDocument(2000, definitionCount: 10);
    final map = LeafOwnerMap(doc);
    final def = define(doc, const Handle(90000));

    for (var i = 0; i < 12; i++) {
      map.applyChange(await changeFrom(
          doc,
          () => addLine(doc, i.isEven ? def : doc.rootHandle, Handle(91000 + i),
              i.toDouble(), 0)));
    }
    for (var i = 0; i < 12; i += 3) {
      map.applyChange(await changeFrom(doc,
          () => doc.commands.execute(RemoveEntityCommand(Handle(91000 + i)))));
    }
    map.applyChange(await changeFrom(doc, doc.commands.undo));

    expectMatchesFullRebuild(map, doc);
    expect(map.rebuildCount, 1, reason: 'the constructor built it once');
  });

  test('slotsOf answers for an owner it has never heard of', () {
    final doc = DraftDocument.empty();
    expect(LeafOwnerMap(doc).slotsOf(const Handle(12345)), isEmpty);
  });
}
