// Spec 2b S1 "The guard" and "The dissolve gap closes" (E5): 06 D6's guard
// gains a node branch for generated instances; any node or entity added
// into a live object, or onto one of its generated instances, is refused;
// a components-only write on a generated instance passes and seeds
// nothing; a removed subtree takes its instances' entities with it.
// Fixture: support/row_clients.dart (two rows off the origin, row 2 turned,
// mirrored and curved).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/row_clients.dart';

const Tolerance exact = Tolerance(linear: 0, angular: 0);

/// Runs [edit]: it must be refused with [GeneratedGeometryError] naming
/// [handle], and leave the bytes, the history and the state as they were.
/// A handle the edit adds is taken from the seed before this call.
void expectRefused(
    DraftDocument doc, DraftCommand edit, Handle handle, String what) {
  final bytes = enc(doc);
  final depth = doc.commands.undoDepth;
  final state = doc.commands.stateId;
  expect(
      () => doc.commands.execute(edit),
      throwsA(isA<GeneratedGeometryError>()
          .having((e) => e.handle, 'handle', handle)),
      reason: what);
  expect(enc(doc), bytes, reason: what);
  expect(doc.commands.undoDepth, depth, reason: what);
  expect(doc.commands.stateId, state, reason: what);
}

/// Every live entity's owner is a live node or definition.
void expectNoOrphan(DraftDocument doc) {
  for (final slot in doc.entities.liveSlots) {
    final owner = doc.entities.ownerAt(slot);
    expect(
        doc.tree[owner] != null || doc.tree.definition(owner) != null, isTrue,
        reason: '${doc.entities.handleAt(slot).toHex()} is owned by '
            '${owner.toHex()}, which is gone');
  }
}

void main() {
  setUp(resetRowCalls);

  test(
      'E5G-refuse a seat\'s move, removal, definition change and layer '
      'change, and an edit or removal of its label, are each refused; the '
      'row moved whole passes and its seats ride along untouched '
      '(M-E5G-value, M-E5G-gone)', () {
    final doc = hall();
    final balcony = addLayer(doc, 'Balcony', 5);
    final seat = seats(doc, hRow2)[3];
    final label = leavesOf(doc, seat.handle).single;
    expectRefused(
        doc,
        TransformNodeCommand(seat.handle,
            seat.transform.multiply(Transform2.translation(25.5, -10.25))),
        seat.handle,
        'move');
    expectRefused(doc, RemoveNodeCommand(seat.handle), seat.handle, 'removal');
    expectRefused(doc, SetInstanceDefinitionCommand(seat.handle, hStool),
        seat.handle, 'definition');
    expectRefused(doc, SetInstanceLayerCommand(seat.handle, balcony),
        seat.handle, 'layer');
    expectRefused(
        doc, SetEntityTextCommand(label, 'Z9', kSeatTag), label, 'label text');
    expectRefused(doc, RemoveEntityCommand(label), label, 'label removal');
    expectRefused(
        doc,
        CompoundCommand(
            [RemoveEntityCommand(label), RemoveNodeCommand(seat.handle)],
            label: 'Delete seat'),
        seat.handle,
        'the select tool\'s delete of one seat');

    // Positive control: the row moved whole.
    doc.commands.execute(TransformNodeCommand(
        hRow2, atRow2.multiply(Transform2.translation(400.5, -120.25))));
    // Equal, not identical: a refused edit's undo rebuilds the node.
    expect(doc.tree[seat.handle], seat);
    expect(leavesOf(doc, seat.handle), [label]);
    expect(drift(doc), isEmpty);
  });

  test(
      'E5G-component a components-only write on a seat passes, seeds '
      'nothing, regenerates nothing and leaves the index alone; one undo '
      'step (M-E5G-seed)', () async {
    final doc = hall();
    final seat = seats(doc, hRow1)[6].handle;
    final index = SpatialIndex(doc);
    index.forEachInRect(Aabb2(Vector2(-20000, -20000), Vector2(30000, 30000)),
        const QueryFilter.all(), (_) {});
    final rebuilds = index.rebuildCount;
    final depth = doc.commands.undoDepth;
    resetRowCalls();
    final applied = await applying(
        doc,
        () => doc.commands.execute(
            SetComponentCommand<SeatNote>(seat, const SeatNote('vip'))));
    expect(rowGenerateCalls, isEmpty);
    expect(rowInstanceCalls, isEmpty);
    expect(applied.single.touched, {seat});
    expect(applied.single.capability, Capability.components);
    expect(index.rebuildCount, rebuilds);
    expect(doc.components.get<SeatNote>(seat), const SeatNote('vip'));
    expect(doc.commands.undoDepth, depth + 1);
    doc.commands.undo();
    expect(doc.components.get<SeatNote>(seat), isNull);
    doc.commands.redo();
    expect(doc.components.get<SeatNote>(seat), const SeatNote('vip'));
    expect(rowGenerateCalls, isEmpty);
    expect(rowInstanceCalls, isEmpty);
    index.dispose();
  });

  test(
      'E5G-add a node added into a live row is refused, a GroupNode '
      'included, and so is an entity added onto one of its seats; the same '
      'adds at the root pass, and a nested group a file brought in stays '
      'editable (M-E5G-add-node, M-E5G-add-onto, M-E5G-nested)', () {
    final doc = hall();
    final seat = seats(doc, hRow1).first.handle;
    final label = leavesOf(doc, seat).single;
    final group = doc.handleSeed.next();
    final instance = doc.handleSeed.next();
    final attrib = doc.handleSeed.next();
    final line = doc.handleSeed.next();
    expectRefused(
        doc,
        AddNodeCommand(GroupNode(
            handle: group,
            parent: hRow1,
            transform: Transform2.translation(50.5, 20.25),
            children: const [])),
        group,
        'a group into the row');
    expectRefused(
        doc,
        AddNodeCommand(InstanceNode(
            handle: instance,
            parent: hRow1,
            transform: seatAt(row1, 12),
            definition: hSeat,
            layer: ReservedHandles.layerZero)),
        instance,
        'an instance into the row');
    expectRefused(
        doc,
        AddEntityCommand(
            record: recordOf(doc, label)
                .copyWith(handle: attrib, tag: 'NOTE', text: 'aisle'),
            payload: payloadOf(doc, label)),
        attrib,
        'an ATTRIB onto a seat');
    expectRefused(
        doc,
        AddEntityCommand(
            record: draftRecord(line, seat, EntityKind.line,
                layer: ReservedHandles.layerZero),
            payload: linePayload(Vector2(-120.5, 0), Vector2(120.5, 40.25))),
        line,
        'a LINE onto a seat');

    // Positive controls: a group and an instance at the root, and an ATTRIB
    // onto that plain instance, pass.
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: atRow1.multiply(Transform2.translation(-2000.5, 0)),
        children: const [])));
    doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: atRow2.multiply(Transform2.translation(0, -1500.25)),
        definition: hStool,
        layer: ReservedHandles.layerZero)));
    doc.commands.execute(AddEntityCommand(
        record: recordOf(doc, label).copyWith(
            handle: attrib, owner: instance, tag: 'NOTE', text: 'aisle'),
        payload: payloadOf(doc, label)));
    expect(doc.tree[group]!.parent, doc.rootHandle);
    expect(doc.entities.ownerAt(doc.entities.slotOf(attrib)!), instance);

    // A nested group a file brought into the row: moving it is not an add.
    late Handle nested;
    final loaded = loadedWith(doc, (raw) {
      nested = raw.handleSeed.next();
      raw.commands.execute(AddNodeCommand(GroupNode(
          handle: nested,
          parent: hRow1,
          transform: Transform2.translation(-300.5, 450.25),
          children: const [])));
    });
    expect(loaded.tree[nested]!.parent, hRow1);
    final moved =
        Transform2.translation(80.25, -40.5).multiply(Transform2.rotation(0.3));
    loaded.commands.execute(TransformNodeCommand(nested, moved));
    expect(loaded.tree[nested]!.transform.equals(moved, exact), isTrue);
    expect(drift(loaded), isEmpty);
  });

  test(
      'E5G-dissolve a dissolving row takes its seats\' labels with it, and a '
      'loaded row takes a nested group\'s instance and its label too; undo '
      'restores every one (M-E5G-dissolve, M-E5G-scan)', () {
    final doc = hall();
    final labels = labelsOf(doc, hRow1);
    final ss = [for (final s in seats(doc, hRow1)) s.handle];
    final row2Labels = labelsOf(doc, hRow2);
    final placed = canon(doc);
    doc.commands.execute(
        SetComponentCommand<Row>(hRow1, row1.copyWith(dissolve: true)));
    expect(doc.tree[hRow1], isNull);
    for (final s in ss) {
      expect(doc.tree[s], isNull);
    }
    for (final l in labels) {
      expect(doc.entities.slotOf(l), isNull, reason: l.toHex());
    }
    expect(labelsOf(doc, hRow2), row2Labels);
    expectNoOrphan(doc);
    doc.commands.undo();
    expect(canon(doc), placed);

    late Handle group, instance, attrib;
    final loaded = loadedWith(hall(), (raw) {
      group = raw.handleSeed.next();
      instance = raw.handleSeed.next();
      attrib = raw.handleSeed.next();
      raw.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: group,
            parent: hRow1,
            transform: Transform2.translation(-300.5, 450.25)
                .multiply(Transform2.rotation(0.4)),
            children: const [])),
        AddNodeCommand(InstanceNode(
            handle: instance,
            parent: group,
            transform: Transform2.translation(20.5, -15.25),
            definition: hStool,
            layer: ReservedHandles.layerZero)),
        AddEntityCommand(
            record: draftRecord(attrib, instance, EntityKind.attrib,
                    layer: ReservedHandles.layerZero, text: 'Z1')
                .copyWith(tag: kSeatTag),
            payload: textPayload(Vector2(5.5, -8.25), 120.5)),
      ], label: 'A nested group'));
    });
    expect(loaded.tree[instance]!.parent, group);
    expect(drift(loaded), isEmpty);
    final before = canon(loaded);
    loaded.commands.execute(
        SetComponentCommand<Row>(hRow1, row1.copyWith(dissolve: true)));
    expect(loaded.tree[group], isNull);
    expect(loaded.tree[instance], isNull);
    expect(loaded.entities.slotOf(attrib), isNull);
    expectNoOrphan(loaded);
    loaded.commands.undo();
    expect(canon(loaded), before);
  });

  test(
      'E5G-undo refused edits leave nothing behind: undo and redo across '
      'refused and allowed edits walk the same states (M-E5G-undo)', () {
    final doc = hall();
    final seat = seats(doc, hRow1)[4];
    // Taken first: a refused add raises the seed no further.
    final group = doc.handleSeed.next();
    final s0 = canon(doc);
    expectRefused(
        doc,
        TransformNodeCommand(
            seat.handle, seat.transform.multiply(Transform2.rotation(0.25))),
        seat.handle,
        'move');
    doc.commands.execute(
        SetComponentCommand<SeatNote>(seat.handle, const SeatNote('window')));
    final s1 = canon(doc);
    doc.commands
        .execute(SetComponentCommand<Row>(hRow1, row1.copyWith(count: 10)));
    final s2 = canon(doc);
    expectRefused(
        doc,
        AddNodeCommand(GroupNode(
            handle: group,
            parent: hRow1,
            transform: Transform2.translation(10.5, 0),
            children: const [])),
        group,
        'a group into the row');
    doc.commands.execute(
        SetComponentCommand<Row>(hRow1, row1.copyWith(count: 10, prefix: 'K')));
    final s3 = canon(doc);
    expect({s0, s1, s2, s3}, hasLength(4));

    doc.commands.undo();
    expect(canon(doc), s2);
    doc.commands.undo();
    expect(canon(doc), s1);
    doc.commands.undo();
    expect(canon(doc), s0);
    doc.commands.redo();
    expect(canon(doc), s1);
    doc.commands.redo();
    expect(canon(doc), s2);
    doc.commands.redo();
    expect(canon(doc), s3);
  });
}
