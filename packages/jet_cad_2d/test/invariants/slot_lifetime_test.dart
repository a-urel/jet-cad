import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

EntityRecord record(Handle handle, Handle owner) => EntityRecord(
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

GeometryPayload at(double x) => GeometryPayload(
      coords: Float64List.fromList([x, 0, x + 1, 1]),
      scalars: Float64List(0),
    );

/// The slot rules from the spec, exercised through the document rather than
/// through either store alone.
///
/// A plain "remove N, undo N" round trip through the command dispatcher is
/// not a useful probe for "undo may land in a different slot": the
/// allocator's free list is a stack, and undo is by construction a perfect
/// inverse of every command it replays, so a fully-undone sequence always
/// lands every entity back on the exact slot it started from, no matter what
/// order the removes happened in.
///
/// That holds **within a single undo history**, and only there. It is not a
/// property of commands: `DraftDocument implements CommandTarget` and
/// `CommandDispatcher` is exported, so a second dispatcher over the same
/// target is an ordinary command-level route whose allocations the first
/// dispatcher's history knows nothing about — the interleaving below is a
/// direct store write only because that is the shortest stand-in for it.
///
/// An implementation whose inverse commands carried slot numbers instead of
/// payloads would pass the naive shape of test. To actually exercise the
/// rule, the first test below claims a freed slot through a write that never
/// goes through the dispatcher at all — standing in for any allocation this
/// undo session does not own — so that when the dispatcher later restores
/// something, the slot it used to have is provably no longer available and
/// the record's rewritten geomIndex is what has to carry the day.
void main() {
  test('undo restores through freshly-claimed slots, not merely mirrored ones',
      () {
    final doc = DraftDocument.empty();
    final handles = [
      for (var i = 0; i < 4; i++) doc.handleSeed.next(),
    ];
    for (var i = 0; i < handles.length; i++) {
      doc.commands.execute(AddEntityCommand(
        record: record(handles[i], doc.rootHandle),
        payload: at(i * 10.0),
      ));
    }
    final originalSlots = [
      for (final h in handles) doc.entities.slotOf(h)!,
    ];

    doc.commands.execute(RemoveEntityCommand(handles[1]));
    doc.commands.execute(RemoveEntityCommand(handles[3]));
    doc.commands.execute(RemoveEntityCommand(handles[0]));

    // Written directly to the stores, bypassing the dispatcher: this claim
    // on the freed slot is invisible to — and so can never be reversed by —
    // doc.commands.undo().
    final fillerGeom = doc.geometry.add(at(999));
    doc.entities.add(record(doc.handleSeed.next(), doc.rootHandle)
        .copyWith(geomIndex: fillerGeom));

    for (var i = 0; i < 3; i++) {
      doc.commands.undo();
    }

    for (var i = 0; i < handles.length; i++) {
      final slot = doc.entities.slotOf(handles[i])!;
      final geometry = doc.geometry.read(doc.entities.geomIndexAt(slot));
      expect(geometry.pointAt(0), Vector2(i * 10.0, 0),
          reason: 'entity $i must still point at its own geometry');
      if (i == 2) {
        // Never removed, so its slot was never up for grabs.
        expect(slot, originalSlots[i],
            reason: 'an entity that was never removed keeps its slot');
      } else {
        expect(slot, isNot(originalSlots[i]),
            reason: 'entity $i was restored into a claimed slot, not its own');
      }
    }

    for (var i = 0; i < 3; i++) {
      doc.commands.redo();
    }
    // The filler sits outside command history entirely, so it survives
    // every redo too.
    expect(doc.entities.liveCount, 2);
    expect(doc.entities.slotOf(handles[2]), originalSlots[2]);
  });

  test('removing an entity does not renumber the survivors', () {
    final doc = DraftDocument.empty();
    final handles = [
      for (var i = 0; i < 4; i++) doc.handleSeed.next(),
    ];
    for (var i = 0; i < handles.length; i++) {
      doc.commands.execute(AddEntityCommand(
        record: record(handles[i], doc.rootHandle),
        payload: at(i * 10.0),
      ));
    }
    final before = [for (final h in handles) doc.entities.slotOf(h)!];

    doc.commands.execute(RemoveEntityCommand(handles[1])); // a middle entity

    expect(doc.entities.slotOf(handles[0]), before[0]);
    expect(doc.entities.slotOf(handles[2]), before[2]);
    expect(doc.entities.slotOf(handles[3]), before[3]);
    expect(doc.entities.slotOf(handles[1]), isNull);
  });

  test('purge rewrites references, clears history, and renumbers slots', () {
    final doc = DraftDocument.empty();
    final keep = doc.handleSeed.next();
    final drop = doc.handleSeed.next();
    final throwaway = doc.handleSeed.next();
    doc.commands.execute(
        AddEntityCommand(record: record(drop, doc.rootHandle), payload: at(0)));
    doc.commands.execute(AddEntityCommand(
        record: record(keep, doc.rootHandle), payload: at(50)));
    doc.commands.execute(RemoveEntityCommand(drop));
    doc.commands.execute(AddEntityCommand(
        record: record(throwaway, doc.rootHandle), payload: at(99)));
    doc.commands.undo(); // undoes the throwaway add, leaving a real redo entry

    final keepSlotBefore = doc.entities.slotOf(keep)!;
    expect(keepSlotBefore, isNot(0),
        reason: 'keep was added second, after drop claimed slot 0');
    expect(doc.commands.canUndo, isTrue,
        reason: 'sanity: there is genuinely something to undo before purge');
    expect(doc.commands.canRedo, isTrue,
        reason: 'sanity: there is genuinely something to redo before purge');

    doc.purge();

    final slot = doc.entities.slotOf(keep)!;
    expect(slot, isNot(keepSlotBefore),
        reason: 'purge compacted the only survivor down to slot 0');
    expect(slot, 0);
    expect(doc.geometry.read(doc.entities.geomIndexAt(slot)).pointAt(0),
        Vector2(50, 0));
    expect(doc.geometry.liveCount, 1);
    expect(doc.entities.liveCount, 1);
    expect(doc.commands.canUndo, isFalse);
    expect(doc.commands.canRedo, isFalse);
  });

  test('a save/load cycle renumbers slots, and does not need to preserve them',
      () {
    final doc = DraftDocument.empty();
    final handles = [for (var i = 0; i < 3; i++) doc.handleSeed.next()];
    for (var i = 0; i < handles.length; i++) {
      doc.commands.execute(AddEntityCommand(
          record: record(handles[i], doc.rootHandle), payload: at(i * 10.0)));
    }
    doc.commands.execute(RemoveEntityCommand(handles[1]));

    // A hole in the middle: liveSlots is {0, 2}, not a dense prefix.
    expect(doc.entities.liveSlots.toList(), [0, 2]);

    final loaded = DraftDocumentCodec.decode(DraftDocumentCodec.encode(doc));

    // The loader allocates fresh from an empty store, in file order — it
    // does not and must not replay the saved slot numbers — so the hole is
    // gone and the survivor after it is renumbered.
    expect(loaded.entities.liveSlots.toList(), [0, 1]);

    final slot0 = loaded.entities.slotOf(handles[0])!;
    final slot2 = loaded.entities.slotOf(handles[2])!;
    expect(slot0, 0);
    expect(slot2, isNot(2));
    expect(slot2, 1);

    expect(loaded.geometry.read(loaded.entities.geomIndexAt(slot0)).pointAt(0),
        Vector2(0, 0));
    expect(loaded.geometry.read(loaded.entities.geomIndexAt(slot2)).pointAt(0),
        Vector2(20, 0));
  });
}
