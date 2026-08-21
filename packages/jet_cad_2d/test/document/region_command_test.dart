import 'dart:typed_data';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

GeometryPayload squareLoop() => GeometryPayload(
    coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
    scalars: Float64List(0));

/// A six-vertex L: it reduces to four triangles, so its index list cannot be
/// confused with the square's two.
GeometryPayload lLoop() => GeometryPayload(
    coords: Float64List.fromList(
        [0, 0, 20, 0, 20, 10, 10, 10, 10, 20, 0, 20, 0, 0]),
    scalars: Float64List(0));

/// An open polyline: `triangulationFor` returns null for it, which is what
/// makes a boundary carrying it unfillable.
GeometryPayload openLoop() => GeometryPayload(
    coords: Float64List.fromList([0, 0, 10, 0, 10, 10]),
    scalars: Float64List(0));

/// The payload of a fill naming [boundary] -- no coordinates, one scalar.
GeometryPayload fillPayload(Handle boundary) => GeometryPayload(
    coords: Float64List(0),
    scalars: Float64List.fromList([boundary.value.toDouble()]));

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

  test('removing a boundary removes its fill, and undo restores both', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(RemoveEntityCommand(cmd.boundary.handle));
    expect(doc.entities.slotOf(cmd.fill.handle), isNull,
        reason: 'an orphaned fill draws nothing and reports nothing');
    expect(doc.fills.entryCount, 0);
    expect(doc.fills.linkCount, 0);
    doc.commands.undo();
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });

  test('removing a fill alone unlinks it and leaves the boundary drawable', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(RemoveEntityCommand(cmd.fill.handle));
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.fills.fillsOf(cmd.boundary.handle), isEmpty);
  });

  // --- Removing a fill ALONE, then restoring it. Every fixture above removes
  // the boundary, and an entity-liveness assertion passes even with the fill
  // index left empty, which is how this survived seventeen reviews.

  test('undoing a fill-only removal restores the index, not just the record',
      () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(RemoveEntityCommand(cmd.fill.handle));
    doc.commands.undo();

    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.fills.fillsOf(cmd.boundary.handle), [cmd.fill.handle],
        reason: 'the record alone is not a fill: the painter, the removal '
            'cascade and `touched` all read the link, not the store');
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6));

    // Indistinguishable from a fill that was never removed, including under a
    // later boundary edit -- which is where the missing link did its damage:
    // it made `SetEntityGeometryCommand` skip the refresh and draw the stale
    // index list against the new points.
    Set<Handle>? touched;
    doc.commands.onAfterMutate = (change) => touched = change.touched;
    doc.commands
        .execute(SetEntityGeometryCommand(cmd.boundary.handle, lLoop()));
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(12),
        reason: 'six vertices reduce to four triangles; a length of 6 here is '
            'the square\'s triangulation drawn against the L\'s points');
    expect(touched, contains(cmd.fill.handle));
  });

  test('a restored fill is a dependent again, so the cascade still sees it',
      () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(RemoveEntityCommand(cmd.fill.handle));
    doc.commands.undo();

    doc.commands.execute(RemoveEntityCommand(cmd.boundary.handle));
    expect(doc.entities.slotOf(cmd.fill.handle), isNull,
        reason: 'with the link gone this took the no-dependents branch and '
            'left the fill orphaned -- the state the cascade exists to '
            'prevent');
    expect(doc.fills.linkCount, 0);
    expect(doc.fills.entryCount, 0);
  });

  test('a fill added back onto an edited boundary gets the new triangulation',
      () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final fillSlot = doc.entities.slotOf(cmd.fill.handle)!;
    final fillRecord = doc.entities.read(fillSlot);
    final fillGeometry = doc.geometry.read(doc.entities.geomIndexAt(fillSlot));

    doc.commands.execute(RemoveEntityCommand(cmd.fill.handle));
    // No fill names the boundary now, so `SetEntityGeometryCommand` leaves the
    // cache entry alone: it is a square's triangulation over an L's points.
    doc.commands
        .execute(SetEntityGeometryCommand(cmd.boundary.handle, lLoop()));
    doc.commands
        .execute(AddEntityCommand(record: fillRecord, payload: fillGeometry));

    expect(doc.fills.fillsOf(cmd.boundary.handle), [cmd.fill.handle]);
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(12),
        reason: 'materialising only when the entry is absent restores the '
            'fill onto the stale entry left behind by the edit');
    expect(doc.fills.trianglesFor(cmd.boundary.handle),
        orderedEquals(triangulationFor(EntityKind.polyline, lLoop())!),
        reason: 'derived from the boundary\'s current payload, not from '
            'whatever the cache happened to hold');
  });

  test('a fill added directly is linked, not silently inert', () {
    final doc = DraftDocument.empty();
    final template = region(doc);
    // Handles swapped: this document is malformed in exactly the way
    // `_rebuildFills` preserves -- the fill draws over its own outline, and
    // `validate()` reports it without repairing it.
    final boundary =
        template.boundary.copyWith(handle: Handle(template.fill.handle.value));
    final fill =
        template.fill.copyWith(handle: Handle(template.boundary.handle.value));
    doc.commands
        .execute(AddEntityCommand(record: boundary, payload: squareLoop()));
    doc.commands.execute(
        AddEntityCommand(record: fill, payload: fillPayload(boundary.handle)));

    expect(doc.fills.fillsOf(boundary.handle), [fill.handle],
        reason: 'an unlinked fill never paints and reports nothing');
    expect(doc.fills.trianglesFor(boundary.handle), hasLength(6));
    expect(doc.validate().map((d) => d.code),
        contains(ValidationCodes.fillDrawOrderInverted),
        reason: 'linking is not repairing: the malformation is still reported');

    // And that malformation is exactly what makes the removal cascade's
    // inverse un-replayable, so the removal is refused rather than performed.
    expect(() => doc.commands.execute(RemoveEntityCommand(boundary.handle)),
        throwsStateError);
    expect(doc.entities.slotOf(boundary.handle), isNotNull);
    expect(doc.entities.slotOf(fill.handle), isNotNull);
  });

  // --- The inverse of removing a filled boundary has to be replayable.

  test('removing a boundary whose pair could not be restored is refused', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    // In-session, no codec needed: this is the state
    // `SetEntityGeometryCommand` documents as "the painter then counts a skip".
    doc.commands
        .execute(SetEntityGeometryCommand(cmd.boundary.handle, openLoop()));
    expect(doc.fills.trianglesFor(cmd.boundary.handle), isNull);

    expect(() => doc.commands.execute(RemoveEntityCommand(cmd.boundary.handle)),
        throwsStateError,
        reason: 'the cascade\'s inverse is an AddRegionCommand that would '
            'refuse an unfillable boundary, so undo would throw forever');
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.fills.fillsOf(cmd.boundary.handle), [cmd.fill.handle]);
  });

  test('the refused removal has an escape, and the escape undoes cleanly', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands
        .execute(SetEntityGeometryCommand(cmd.boundary.handle, openLoop()));

    doc.commands.execute(RemoveEntityCommand(cmd.fill.handle));
    doc.commands.execute(RemoveEntityCommand(cmd.boundary.handle));
    expect(doc.entities.liveSlots, isEmpty);

    doc.commands.undo();
    doc.commands.undo();
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.fills.fillsOf(cmd.boundary.handle), [cmd.fill.handle],
        reason: 'the malformed pair is restored exactly as it was, link '
            'included; validate() still reports it');
    expect(doc.fills.trianglesFor(cmd.boundary.handle), isNull,
        reason: 'still unfillable, so still no index list to draw');
    expect(doc.validate().map((d) => d.code),
        contains(ValidationCodes.fillBoundaryNotClosed),
        reason: 'the user\'s data survived the round trip unrepaired');
  });
}
