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
}
