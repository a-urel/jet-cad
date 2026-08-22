// `dart:typed_data` for Float64List, `dart:ui` for the bare `Size` the
// painter's viewport takes (the barrel doesn't re-export it, only fixtures.dart
// does), and `hide Aabb2` because vector_math ships its own Aabb2 and
// `jet_cad_2d` exports the one this codebase means. Every text-bearing test in
// this directory has these lines — see `text_paint_test.dart` and
// `draft_canvas_test.dart`.
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// One text entity of [height] world units at the world origin, and nothing
/// else, so the camera fit is decided by [world] rather than by the glyph box.
DraftDocument _doc(double height, Aabb2 world, FlutterTextMeasurer m) {
  final doc = DraftDocument.empty(measurer: m);
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: 'STAIR',
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: packTextAttrs(),
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([world.min.x, world.min.y]),
      scalars: Float64List.fromList([height, 0, 1, 0]),
    ),
  ));
  return doc;
}

void main() {
  test('text below the threshold is culled and never measured', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    // 1000 world units across a 400 px viewport, with `ViewportTransform.fit`'s
    // own 5% margin, is 0.38 px per unit, so a height-2 glyph is 0.76 px of
    // cap height — under the 3.0 default.
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    // `SpatialIndex(doc)` above already measured this text once, to bound it
    // for insertion — a mechanism the painter's LOD gate has nothing to do
    // with. The load-bearing claim is that the painter's own cull adds no
    // *further* layout, so the baseline is taken here, after the index and
    // before `paint`, rather than asserted against zero.
    final baseline = m.layoutCount;
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    expect(painter.culledTextCount, 1);
    expect(painter.textOpCount, 0);
    // The load-bearing half: culling after `measure` would push this past
    // `baseline`. It is why the LOD gate sits before the measure call.
    expect(m.layoutCount, baseline);
  });

  test('the same text at the same camera draws once LOD is off', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0.0);
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    // The control arm. Without it the first test passes on a corpus with no
    // text at all.
    expect(painter.culledTextCount, 0);
    expect(painter.textOpCount, 1);
  });

  test('readable text at the same threshold is not culled', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    // 40 world units at 0.38 px per unit (see the culled test above for where
    // that figure comes from) is 15.2 px of cap height.
    final doc = _doc(40.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    expect(painter.culledTextCount, 0);
    expect(painter.textOpCount, 1);
  });

  test('the threshold is exclusive at exactly kMinTextCapPixels', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    const size = Size(400, 300);
    // The camera's scale is derived, not hand-computed, because
    // `ViewportTransform.fit` bakes in its own 5% margin (see the factory's
    // doc comment) on top of the raw viewport/world ratio — a height picked
    // against the raw ratio alone lands a few percent off the boundary this
    // test means to sit on. One `view` instance is reused for the fixture and
    // for `paint` so the same double is multiplied both times.
    final view = ViewportTransform.fit(world, size);
    final doc = _doc(kMinTextCapPixels / view.scale, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();

    painter.paint(sink, view, size);

    // `<`, not `<=`: a glyph exactly at the threshold is drawn.
    expect(painter.culledTextCount, 0);
    expect(painter.textOpCount, 1);
  });

  test('culledTextCount is a per-frame figure, not a running total', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final view = ViewportTransform.fit(world, const Size(400, 300));

    painter.paint(RecordingDrawSink(), view, const Size(400, 300));
    painter.paint(RecordingDrawSink(), view, const Size(400, 300));

    expect(painter.culledTextCount, 1);
  });

  test('the threshold does not reach doc.extents', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final wide = doc.extents;
    doc.invalidateDerived();
    final again = doc.extents;
    // A document box that changed with zoom would be absurd; the painter's
    // threshold is a draw decision and lives nowhere near entityBounds.
    expect(again.min.x, wide.min.x);
    expect(again.min.y, wide.min.y);
    expect(again.max.x, wide.max.x);
    expect(again.max.y, wide.max.y);
  });
}
