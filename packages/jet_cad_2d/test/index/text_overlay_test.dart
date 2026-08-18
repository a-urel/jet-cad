// Pins `spatial_index.dart`'s incremental dirty-overlay path to resolve text
// exactly the way a full rebuild does. Before this task, the overlay path
// hard-coded `text: ''` when re-deriving a leaf's box, so an edited text
// entity kept its old, degenerate box on the overlay while a rebuilt index
// gave it the correct laid-out one -- "the box is not where the glyphs are",
// on the path an editing session spends all its time in.

import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

EntityRecord _textRecord(
  Handle handle,
  Handle owner,
  Handle textStyle, {
  String text = 'A',
  int textAttrs = 0,
}) =>
    EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
      text: text,
      textStyle: textStyle,
      textAttrs: textAttrs,
    );

void main() {
  test('an edited text has the same box in the overlay as after a rebuild', () {
    final doc = DraftDocument.empty(measurer: const MetricModelMeasurer());
    final style = doc.tables.textStyles.byName('STANDARD')!;
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: _textRecord(handle, doc.rootHandle, style.handle),
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

  test(
      "a non-STANDARD text style's fixedHeight overrides the entity's own "
      'height scalar', () {
    // Every other fixture in this suite uses STANDARD, whose fixedHeight is
    // 0 (height comes from the entity). A bug that resolved every entity's
    // style as a bare STANDARD lookup -- rather than through the entity's
    // own `textStyle` handle -- would go undetected by any of them, since
    // "resolve to STANDARD" and "resolve to the entity's own STANDARD" are
    // the same answer. This fixture's style is not STANDARD and has a
    // non-zero fixedHeight, so the two answers diverge.
    final doc = DraftDocument.empty(measurer: const MetricModelMeasurer());
    final standard = doc.tables.textStyles.byName('STANDARD')!;
    const bigStyle = TextStyleRecord(
      handle: Handle(600),
      name: 'BIG',
      fontFamily: 'Roboto',
      fixedHeight: 500,
    );
    doc.tables.textStyles.add(bigStyle);

    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: _textRecord(handle, doc.rootHandle, bigStyle.handle),
      payload: GeometryPayload(
        // The entity's own height scalar is 200; BIG's fixedHeight (500)
        // must win.
        coords: Float64List.fromList([1000, 2000]),
        scalars: Float64List.fromList([200, 0, 0, 0]),
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final slot = doc.entities.slotOf(handle)!;
    final actual = index.rootIndex.boxOfLeaf(slot)!;

    // What the box would be if the engine had resolved STANDARD instead of
    // the entity's own style -- the bug this test pins.
    final wrongStyle = entityBounds(
      kind: EntityKind.text,
      payload: doc.geometry.peek(doc.entities.geomIndexAt(slot)),
      measurer: doc.textMeasurer,
      textStyle: standard,
      textAttrs: 0,
      text: 'A',
    );

    expect(actual.maxY - actual.minY,
        isNot(closeTo(wrongStyle.maxY - wrongStyle.minY, 1e-6)));
  });

  test(
      'a non-default justification anchors the box on the opposite edge '
      'from left/baseline', () {
    // Every other fixture in this suite leaves `textAttrs` at its default
    // (left/baseline), so a bug that hard-coded `textAttrs: 0` at any engine
    // call site would go undetected. Right/top justification anchors the
    // box's *top-right* corner at the insertion point instead of the
    // bottom-left, so `maxX`/`maxY` landing on the anchor -- rather than
    // `minX`/`minY`, as the default case would put them -- is proof the
    // stored `textAttrs` was actually read.
    final doc = DraftDocument.empty(measurer: const MetricModelMeasurer());
    final style = doc.tables.textStyles.byName('STANDARD')!;
    final handle = doc.handleSeed.next();
    final attrs = packTextAttrs(h: TextJustifyH.right, v: TextJustifyV.top);
    doc.commands.execute(AddEntityCommand(
      record:
          _textRecord(handle, doc.rootHandle, style.handle, textAttrs: attrs),
      payload: GeometryPayload(
        coords: Float64List.fromList([1000, 2000]),
        scalars: Float64List.fromList([200, 0, 0, 0]),
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final slot = doc.entities.slotOf(handle)!;
    final box = index.rootIndex.boxOfLeaf(slot)!;

    expect(box.maxX, closeTo(1000, 1e-6));
    expect(box.maxY, closeTo(2000, 1e-6));
    expect(box.minX, lessThan(1000));
    expect(box.minY, lessThan(2000));
  });
}
