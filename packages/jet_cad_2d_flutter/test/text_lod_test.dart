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

import 'support/differential.dart';
import 'support/fixtures.dart';

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
    //
    // `clear()` first, and not just a baseline snapshot, because a snapshot
    // alone hides the real failure mode: `measure()` is cache-first, and
    // `SpatialIndex(doc)` already warmed the `('STAIR', Standard)` entry in
    // both the metrics and paragraph caches. A cull moved to *after*
    // `measure()` would call it, but on a warm cache that call is a lookup,
    // not a layout — `layoutCount` would not move either way, and this test
    // would pass while testing nothing. Clearing forces the painter's own
    // call, cull-permitting, to be the one that pays for the layout.
    m.clear();
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

  test('doc.extents is bit-identical whichever threshold the painter runs at',
      () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final view = ViewportTransform.fit(world, const Size(400, 300));

    // 0.0 draws the glyph; 1000.0 culls it at any camera this fixture could
    // reach. `minTextCapPixels` is final on `DraftPainter`, so two instances
    // are needed to run the same document at two thresholds.
    DraftPainter(
            document: doc,
            index: index,
            resolver: DocumentStyleResolver(doc),
            minTextCapPixels: 0.0)
        .paint(RecordingDrawSink(), view, const Size(400, 300));
    final withTextDrawn = doc.extents;

    // Forces the next `doc.extents` read to be genuinely recomputed by
    // `entityBounds` rather than served from `_extentsCache` — a cache hit
    // here would pass even if the cull had leaked into `entityBounds`.
    doc.invalidateDerived();

    DraftPainter(
            document: doc,
            index: index,
            resolver: DocumentStyleResolver(doc),
            minTextCapPixels: 1000.0)
        .paint(RecordingDrawSink(), view, const Size(400, 300));
    final withTextCulled = doc.extents;

    // `doc.extents` is a stored geometric quantity, derived once by
    // `entityBounds` from the payload, the attribute bits and the style
    // record; the painter's cull is a later, per-frame draw decision that
    // never reaches it, and this asserts exactly that: the box does not
    // depend on which painter, at which threshold, last ran.
    //
    // **What this test cannot do, verified rather than assumed.** A cull
    // leaked into `entityBounds` itself
    // (`packages/jet_cad_2d/lib/src/document/extents.dart`) was fired against
    // this test — the nearest reachable form, comparing the raw world-space
    // height against a literal 3.0, since `entityBounds` is handed no camera
    // scale to turn that into an on-screen figure. It did not redden this
    // test: `entityBounds` has no channel to a specific `DraftPainter`'s
    // `minTextCapPixels`, so the mutated function returns the same collapsed
    // box on both reads regardless of which painter ran in between, and two
    // identical wrong answers still compare equal. That mutation *did*
    // redden three of this file's other tests — the collapsed box drops the
    // leaf out of the spatial index's query window, so `culledTextCount`
    // reads 0 instead of 1 — which is the real, if incidental, guard against
    // it; see Task 5's report for the transcript.
    expect(withTextCulled.min.x, withTextDrawn.min.x);
    expect(withTextCulled.min.y, withTextDrawn.min.y);
    expect(withTextCulled.max.x, withTextDrawn.max.x);
    expect(withTextCulled.max.y, withTextDrawn.max.y);
  });

  test('painter and oracle cull the same text under a non-identity placement',
      () {
    // Deliberately not at the identity and not at the origin: the painter and
    // the walk reach `chain` by different routes, and a fixture at the identity
    // transform cannot tell a shared decision from two agreeing ones.
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final doc = textLodDifferentialDocument(m);
    final world = doc.extents;
    final view = ViewportTransform.fit(world, kViewport);

    // Compared through `flatten`, not op for op. The two sides reach the same
    // picture by different arithmetic routes — the painter hands the sink
    // screen-space points under a translation-only residual where the walk
    // hands it local points under the full one — so a raw `DrawOp` comparison
    // reports the fixture's own root line as a difference and never gets as
    // far as the text. `flatten` applies each residual to the geometry drawn
    // under it, which is the comparison every other differential row in this
    // package makes.
    final painted = flatten(paintToRecording(doc, view));
    final walked = flatten(referenceToRecording(doc, view));

    expect(painted.length, walked.length);
    for (var i = 0; i < painted.length; i++) {
      expect(painted[i].matches(walked[i]), isTrue,
          reason: 'item $i: painter ${painted[i]} vs walk ${walked[i]}');
    }
    // Both sides drew the two readable labels and neither drew the two that
    // fall under the threshold. Named rather than counted, so a cull that took
    // the wrong pair away would still be caught.
    expect(painted.map((i) => i.kind).toList(),
        containsAll(<String>['text:EDGE', 'text:LARGE']));
    for (final culled in const ['text:TINY', 'text:NEAR']) {
      expect(painted.map((i) => i.kind), isNot(contains(culled)));
      expect(walked.map((i) => i.kind), isNot(contains(culled)));
    }

    // Non-vacuity: if nothing were culled this would pass with LOD deleted.
    // The threshold is the third *positional* argument — `camera` is already
    // optional-positional on both helpers, and Dart does not let one signature
    // carry optional-positional and named parameters at once.
    final all = flatten(paintToRecording(doc, view, 0.0));
    expect(all.length, greaterThan(painted.length));
    // And by exactly two items, which are the labels the fixture's measured
    // cap heights — 0.665, 2.826, 3.175 and 13.30 px against the 3.0 threshold
    // — say are the ones under it. `greaterThan` alone would still pass if the
    // cull had swallowed three of the four, or all of them.
    expect(all.length - painted.length, 2);
    expect(all.map((i) => i.kind),
        containsAll(<String>['text:TINY', 'text:NEAR']));
    // The matched control arm, which is why the threshold is steerable on
    // *both* helpers and not just on the oracle: at 0.0 the walk draws the
    // same complete set the painter does, so the on-arm's agreement above is a
    // statement about the cull and not about what the two can draw at all.
    expect(flatten(referenceToRecording(doc, view, 0.0)).length, all.length);
  });
}
