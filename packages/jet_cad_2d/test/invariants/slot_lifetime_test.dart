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
void main() {
  test('delete then undo then redo keeps every reference intact', () {
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

    // Delete out of order, so the free list is not a simple reversal.
    doc.commands.execute(RemoveEntityCommand(handles[1]));
    doc.commands.execute(RemoveEntityCommand(handles[3]));
    doc.commands.execute(RemoveEntityCommand(handles[0]));

    for (var i = 0; i < 3; i++) {
      doc.commands.undo();
    }

    for (var i = 0; i < handles.length; i++) {
      final slot = doc.entities.slotOf(handles[i])!;
      final geometry = doc.geometry.read(doc.entities.geomIndexAt(slot));
      expect(geometry.pointAt(0), Vector2(i * 10.0, 0),
          reason: 'entity $i must still point at its own geometry');
    }

    for (var i = 0; i < 3; i++) {
      doc.commands.redo();
    }
    expect(doc.entities.liveCount, 1);
    expect(doc.entities.slotOf(handles[2]), isNotNull);
  });

  test('purge rewrites references and is not undoable', () {
    final doc = DraftDocument.empty();
    final keep = doc.handleSeed.next();
    final drop = doc.handleSeed.next();
    doc.commands.execute(
        AddEntityCommand(record: record(drop, doc.rootHandle), payload: at(0)));
    doc.commands.execute(AddEntityCommand(
        record: record(keep, doc.rootHandle), payload: at(50)));
    doc.commands.execute(RemoveEntityCommand(drop));

    doc.purge();

    final slot = doc.entities.slotOf(keep)!;
    expect(doc.geometry.read(doc.entities.geomIndexAt(slot)).pointAt(0),
        Vector2(50, 0));
    expect(doc.geometry.liveCount, 1);
    expect(doc.entities.liveCount, 1);
    expect(doc.commands.canUndo, isFalse);
    expect(doc.commands.canRedo, isFalse);
  });

  test('a save/load cycle does not preserve slots, and does not need to', () {
    final doc = DraftDocument.empty();
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
        record: record(handle, doc.rootHandle), payload: at(7)));

    final loaded = DraftDocumentCodec.decode(DraftDocumentCodec.encode(doc));
    final slot = loaded.entities.slotOf(handle)!;
    expect(loaded.geometry.read(loaded.entities.geomIndexAt(slot)).pointAt(0),
        Vector2(7, 0));
  });
}
