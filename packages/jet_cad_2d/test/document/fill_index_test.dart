import 'dart:typed_data';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('triangles round-trip by boundary handle', () {
    final ix = FillIndex();
    expect(ix.trianglesFor(const Handle(20)), isNull);
    ix.putTriangles(const Handle(20), Int32List.fromList([0, 1, 2]));
    expect(ix.trianglesFor(const Handle(20)), [0, 1, 2]);
    expect(ix.entryCount, 1);
  });

  test('a hit returns the stored list itself, not a copy', () {
    // The frame path reads this per fill per frame. A defensive copy here
    // would allocate per entity and break the global constraint.
    final ix = FillIndex();
    final stored = Int32List.fromList([0, 1, 2]);
    ix.putTriangles(const Handle(20), stored);
    expect(identical(ix.trianglesFor(const Handle(20)), stored), isTrue);
  });

  test('fillsOf returns every fill naming a boundary, in handle order', () {
    final ix = FillIndex();
    ix.link(const Handle(31), const Handle(40));
    ix.link(const Handle(19), const Handle(40));
    ix.link(const Handle(22), const Handle(41));
    expect(ix.fillsOf(const Handle(40)), [const Handle(19), const Handle(31)]);
    expect(ix.fillsOf(const Handle(41)), [const Handle(22)]);
    expect(ix.fillsOf(const Handle(99)), isEmpty);
  });

  test('dropBoundary removes the triangles and every link naming it', () {
    final ix = FillIndex();
    ix.putTriangles(const Handle(40), Int32List.fromList([0, 1, 2]));
    ix.link(const Handle(19), const Handle(40));
    ix.link(const Handle(31), const Handle(40));
    ix.dropBoundary(const Handle(40));
    expect(ix.trianglesFor(const Handle(40)), isNull);
    expect(ix.fillsOf(const Handle(40)), isEmpty);
    expect(ix.entryCount, 0);
    expect(ix.linkCount, 0,
        reason: 'a link left behind after its boundary died is the leak the '
            'handle key was chosen to make harmless -- but it is still a leak');
  });

  test('unlink removes one fill and leaves its siblings', () {
    final ix = FillIndex();
    ix.link(const Handle(19), const Handle(40));
    ix.link(const Handle(31), const Handle(40));
    ix.unlink(const Handle(19));
    expect(ix.fillsOf(const Handle(40)), [const Handle(31)]);
  });

  test('the index survives a purge because handles do', () {
    // The purge test that a geomIndex-keyed cache cannot pass. Two entities,
    // one removed, then purge -- which renumbers every geomIndex and leaves
    // every handle alone.
    final doc = DraftDocument.empty();
    final a = doc.handleSeed.next();
    final b = doc.handleSeed.next();
    for (final h in [a, b]) {
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: h,
          owner: doc.rootHandle,
          kind: EntityKind.polyline,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.continuousLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const TrueColor(0x000000),
          lineweight: 30,
          transparency: 0,
          flags: 0,
        ),
        payload: GeometryPayload(
            coords: Float64List.fromList(
                h == a ? [0, 0, 1, 0, 1, 1, 0, 0] : [5, 5, 6, 5, 6, 6, 5, 5]),
            scalars: Float64List(0)),
      ));
    }
    doc.fills.putTriangles(b, Int32List.fromList([0, 1, 2]));
    doc.commands.execute(RemoveEntityCommand(a));
    doc.purge();
    expect(doc.fills.trianglesFor(b), [0, 1, 2],
        reason: 'purge renumbers every geomIndex and touches no handle, so a '
            'handle-keyed entry is still attached to the same entity');
  });
}
