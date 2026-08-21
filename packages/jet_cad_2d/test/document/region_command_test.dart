import 'dart:typed_data';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

GeometryPayload squareLoop() => GeometryPayload(
    coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
    scalars: Float64List(0));

AddRegionCommand region(DraftDocument doc) => AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: squareLoop(),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );

void main() {
  test('the fill gets the lower handle, so it draws underneath', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    expect(cmd.fill.handle.value, lessThan(cmd.boundary.handle.value),
        reason: 'draw order is ascending handle value; a fill above its own '
            'boundary paints over its outline');
    doc.commands.execute(cmd);
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
  });

  test('apply refuses an inverted pair rather than drawing it wrong', () {
    final doc = DraftDocument.empty();
    final good = region(doc);
    final inverted = AddRegionCommand(
      fill: good.fill.copyWith(handle: Handle(good.boundary.handle.value + 1)),
      boundary: good.boundary,
      boundaryPayload: good.boundaryPayload,
    );
    expect(() => doc.commands.execute(inverted), throwsStateError);
  });

  test('the fill names its boundary and the index links them', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final slot = doc.entities.slotOf(cmd.fill.handle)!;
    final payload = doc.geometry.peek(doc.entities.geomIndexAt(slot));
    expect(payload.coords, isEmpty, reason: 'a fill stores no geometry');
    expect(boundaryHandleOf(payload), cmd.boundary.handle);
    expect(doc.fills.fillsOf(cmd.boundary.handle), [cmd.fill.handle]);
  });

  test('the triangulation is materialised by the command, not by a draw', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6),
        reason: 'a square is two triangles; the frame path reads and never '
            'computes');
  });

  test('an unfillable boundary is refused before anything is written', () {
    final doc = DraftDocument.empty();
    final open = GeometryPayload(
        coords: Float64List.fromList([0, 0, 10, 0, 10, 10]), // not closed
        scalars: Float64List(0));
    expect(
        () => doc.commands.execute(AddRegionCommand.allocate(
              seed: doc.handleSeed,
              owner: doc.rootHandle,
              boundaryKind: EntityKind.polyline,
              boundaryPayload: open,
              layer: ReservedHandles.layerZero,
              fillColor: const TrueColor(0x3366CC),
              boundaryColor: const TrueColor(0x000000),
            )),
        throwsStateError);
    expect(doc.entities.liveSlots, isEmpty,
        reason: 'apply must either complete fully or leave the target '
            'unmutated');
  });

  test('undo removes both halves and redo restores the same handles', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.undo();
    expect(doc.entities.liveSlots, isEmpty);
    expect(doc.fills.entryCount, 0);
    expect(doc.fills.linkCount, 0);
    doc.commands.redo();
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });

  test('editing a boundary re-triangulates and touches its fills', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final before = doc.fills.trianglesFor(cmd.boundary.handle)!;

    // `execute` is void; `onAfterMutate` is the synchronous channel that
    // carries a command's `touched` set out to a caller in the same
    // statement, which is what the assertion below needs.
    Set<Handle>? touched;
    doc.commands.onAfterMutate = (change) => touched = change.touched;

    // An L, not a translation: a moved square re-triangulates to the same
    // index list and cannot tell a working invalidation from a missing one.
    doc.commands.execute(SetEntityGeometryCommand(
      cmd.boundary.handle,
      GeometryPayload(
          coords: Float64List.fromList(
              [0, 0, 20, 0, 20, 10, 10, 10, 10, 20, 0, 20, 0, 0]),
          scalars: Float64List(0)),
    ));
    final after = doc.fills.trianglesFor(cmd.boundary.handle)!;
    expect(after.length, 12, reason: 'six vertices reduce to four triangles');
    expect(after.length, isNot(before.length));
    expect(touched, contains(cmd.fill.handle),
        reason: 'the fill\'s indexed box is derived from this boundary; if the '
            'fill is not touched, SpatialIndex never re-derives it');
  });

  test('the handle and the geomIndex survive the edit', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final slot = doc.entities.slotOf(cmd.boundary.handle)!;
    final geomBefore = doc.entities.geomIndexAt(slot);
    doc.commands.execute(SetEntityGeometryCommand(
        cmd.boundary.handle,
        GeometryPayload(
            coords: Float64List.fromList([0, 0, 5, 0, 5, 5, 0, 5, 0, 0]),
            scalars: Float64List(0))));
    expect(doc.entities.slotOf(cmd.boundary.handle), slot);
    expect(doc.entities.geomIndexAt(slot), geomBefore,
        reason: 'identity preserved is the whole reason this command exists');
  });

  test('it refuses a fill, because a fill\'s payload is a reference', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    expect(
        () => doc.commands.execute(SetEntityGeometryCommand(
            cmd.fill.handle,
            GeometryPayload(
                coords: Float64List(0),
                scalars: Float64List.fromList([999.0])))),
        throwsStateError);
  });

  test('undo restores the previous geometry and its triangulation', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(SetEntityGeometryCommand(
        cmd.boundary.handle,
        GeometryPayload(
            coords: Float64List.fromList(
                [0, 0, 20, 0, 20, 10, 10, 10, 10, 20, 0, 20, 0, 0]),
            scalars: Float64List(0))));
    doc.commands.undo();
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });

  test(
      'two edits then two undos: the inverse must not share the store\'s '
      'buffer', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final original = List<double>.from(squareLoop().coords);

    doc.commands.execute(SetEntityGeometryCommand(
        cmd.boundary.handle,
        GeometryPayload(
            coords: Float64List.fromList(
                [0, 0, 20, 0, 20, 10, 10, 10, 10, 20, 0, 20, 0, 0]),
            scalars: Float64List(0))));
    final firstEdit = List<double>.from(doc.geometry
        .peek(
            doc.entities.geomIndexAt(doc.entities.slotOf(cmd.boundary.handle)!))
        .coords);

    doc.commands.execute(SetEntityGeometryCommand(
        cmd.boundary.handle,
        GeometryPayload(
            coords: Float64List.fromList([0, 0, 5, 0, 5, 5, 0, 5, 0, 0]),
            scalars: Float64List(0))));

    // If the first edit's inverse captured the store's own buffer (`peek`
    // rather than `read`), the second `replace` overwrote that buffer in
    // place, so the first undo below would restore the *second* edit's
    // coordinates instead of the original square.
    doc.commands.undo();
    final afterFirstUndo = doc.geometry
        .peek(
            doc.entities.geomIndexAt(doc.entities.slotOf(cmd.boundary.handle)!))
        .coords;
    expect(afterFirstUndo, orderedEquals(firstEdit));

    doc.commands.undo();
    final afterSecondUndo = doc.geometry
        .peek(
            doc.entities.geomIndexAt(doc.entities.slotOf(cmd.boundary.handle)!))
        .coords;
    expect(afterSecondUndo, orderedEquals(original));
  });
}
