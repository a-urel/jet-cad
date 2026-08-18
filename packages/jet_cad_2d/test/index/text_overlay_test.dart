// Pins `spatial_index.dart`'s incremental dirty-overlay path to resolve text
// exactly the way a full rebuild does. Before this task, the overlay path
// hard-coded `text: ''` when re-deriving a leaf's box, so an edited text
// entity kept its old, degenerate box on the overlay while a rebuilt index
// gave it the correct laid-out one -- "the box is not where the glyphs are",
// on the path an editing session spends all its time in.

import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('an edited text has the same box in the overlay as after a rebuild', () {
    final doc = DraftDocument.empty(measurer: const MetricModelMeasurer());
    final style = doc.tables.textStyles.byName('STANDARD')!;
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: doc.rootHandle,
        kind: EntityKind.text,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0,
        text: 'A',
        textStyle: style.handle,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([1000, 2000]),
        scalars: Float64List.fromList([200, 0, 0, 0]),
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    doc.commands
        .execute(SetEntityTextCommand(handle, 'A MUCH LONGER LABEL', ''));

    // Dirtying a leaf removes it from the packed R-tree and parks it in the
    // dirty overlay, so `boxOfLeaf` alone answers null for an entity edited
    // since the last rebuild. That is correct, not a defect -- the codebase's
    // own idiom for reading a leaf's box regardless of which side it lives
    // on is `boxOfLeaf(slot) ?? dirty.boxOf(slot)` (see spatial_index.dart's
    // `_reconcileEntity`), so the test follows the same idiom rather than
    // reading the packed tree directly.
    final slot = doc.entities.slotOf(handle)!;
    final incrementalOrNull =
        index.rootIndex.boxOfLeaf(slot) ?? index.rootIndex.dirty.boxOf(slot);
    expect(incrementalOrNull, isNotNull);
    final incremental = incrementalOrNull!;
    index.rebuildAll();
    final rebuilt = index.rootIndex.boxOfLeaf(slot)!;

    // The dirty-overlay path at spatial_index.dart's `_reconcileEntity` must
    // resolve text the same way the full build does. Hard-coding `text: ''`
    // there leaves an edited text in a degenerate box while a rebuilt one is
    // correct -- on the path an editing session spends all its time in.
    expect(incremental.minX, closeTo(rebuilt.minX, 1e-9));
    expect(incremental.maxX, closeTo(rebuilt.maxX, 1e-9));
    expect(incremental.minY, closeTo(rebuilt.minY, 1e-9));
    expect(incremental.maxY, closeTo(rebuilt.maxY, 1e-9));
    expect(rebuilt.maxX - rebuilt.minX, greaterThan(0.0));
  });
}
