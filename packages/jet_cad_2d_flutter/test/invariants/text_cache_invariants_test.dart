// The structural half of what `test/rig/paint_microbench_test.dart` prints.
//
// The rig measures at realistic scale and prints; those numbers depend on
// machine load and a rig that fails the build on a slow machine teaches people
// to ignore it. **These numbers do not.** Cache occupancy, eviction counts and
// op counts are a function of the document, the camera and the code — the same
// integers on every machine — so they can be a gate, and they are sized by the
// bound under test rather than by realism.
//
// Plan 3f's mutant 7 (`metricsLimit` defaulting to `kParagraphCacheLimit`)
// passed all 297 tests in the suite it was fired against. Nine of the twelve
// constructions in `flutter_text_measurer_test.dart` were already bare, so
// bare construction was never the missing half. Plan 3f's remedy
// (`645b027`) closed one side of it: a bare measurer swept past 512
// distinct strings through `measure()` and pinned `metricsEvictionCount`.
// That test never calls `paragraphFor`, never runs a painter, and asserts
// `liveParagraphCount == 0` outright — it closes the metrics half and
// leaves the paragraph half exactly as untested as before. This file
// closes that half: a real paint through `CanvasDrawSink` fills both maps
// at once, and the 600-into-512 eviction arithmetic is pinned
// behaviourally rather than restated. Firing mutant 7 again reddens both
// files, but from the *same* side of the cache — the metrics side, at
// `liveMetricsCount` in each. That is real evidence the metrics half is
// doubly covered, not that this file's own paragraph half is gated; mutant
// 13 (`paragraphLimit` defaulting to `kMetricsCacheLimit`) is the one that
// proves that, since nothing before this file ever called `paragraphFor`.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';

/// More distinct keys than `kParagraphCacheLimit` (512) and fewer than
/// `kMetricsCacheLimit` (8192). 600 sits between the two bounds, which is the
/// only property that matters: at 512 or below no value of either limit
/// changes an answer.
const int kDistinctLabels = 600;

/// Cap height in world units. At the camera below, world units are screen
/// pixels, so this is 8 px against a `kMinTextCapPixels` of 3.0 — a 2.67x
/// margin, and `culledTextCount == 0` is asserted rather than assumed.
const double kLabelHeight = 8.0;

/// World == screen, y flipped, no margin.
///
/// **Not `ViewportTransform.fit`.** `fit` applies a 0.95 margin, and deriving
/// an expected on-screen cap height through it is what cost Plan 3f two tasks.
/// At scale 1.0 the level-of-detail arithmetic is `8.0 >= 3.0` and there is
/// nothing to get wrong.
ViewportTransform unitCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(1, 0, 0, -1, 0, kViewport.height));

/// 600 labels, every string distinct, laid out on a grid that fits inside
/// [kViewport] so none of them culls by bounds.
///
/// 25 columns x 24 rows on a 30 x 24 pixel cell: a four-character label at 8 px
/// cap height is roughly 18 px wide, so nothing leaves its cell and nothing
/// leaves the viewport.
DraftDocument sixHundredLabels(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  for (var i = 0; i < kDistinctLabels; i++) {
    final column = i % 25;
    final row = i ~/ 25;
    addText(
      doc,
      doc.rootHandle,
      Handle(1000 + i),
      // Distinct by construction: 600 strings, 600 keys.
      'L${i.toString().padLeft(3, '0')}',
      column * 30.0 + 4,
      row * 24.0 + 8,
      kLabelHeight,
    );
  }
  return doc;
}

void main() {
  test('the default cache bounds hold 600 distinct keys the way they claim',
      () {
    // Bare. Both limits are what is under test, so neither may be supplied.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);

    final doc = sixHundredLabels(measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // The baseline, stated rather than assumed: `doc.extents` measures text
    // through `entityBounds`, so building the document and the index has
    // already warmed the *metrics* map with all 600 keys. That is harmless for
    // the four counters below — the same 600 keys, still no evictions — but it
    // is why `layoutCount` is deliberately not asserted here. Plan 3f's Task 5
    // lost a round to exactly this warm-up.
    expect(doc.extents.isEmpty, isFalse,
        reason: 'the fixture must have measurable text');

    // `CanvasDrawSink` over a real `Canvas`, and nothing else will do:
    // `paragraphFor` has one production caller and this is it. A
    // `RecordingDrawSink` or a `TextKeySink` would leave `liveParagraphCount`
    // at zero while reporting `textOpCount == 600`.
    final recorder = PictureRecorder();
    final sink = CanvasDrawSink(
      canvas: Canvas(recorder),
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      measurer: measurer,
      textStyleOf: doc.textStyleOf,
    );
    final painter = DraftPainter(
      document: doc,
      index: index,
      resolver: DocumentStyleResolver(doc),
    );

    painter.paint(sink, unitCamera(), kViewport);
    // A `Picture` holds native memory past the Dart object. Leaving one alive
    // is the "moved the leak" shape Plan 3f's own rule was written against.
    recorder.endRecording().dispose();

    // The fixture proves it drew what it claims before any cache number is
    // read: a level-of-detail cull would produce a smaller, self-consistent,
    // wrong set of counts.
    expect(painter.textOpCount, kDistinctLabels);
    expect(painter.culledTextCount, 0);
    expect(painter.skippedTextCount, 0);

    // The metrics map is bounded at 8192 and holds all 600.
    expect(measurer.liveMetricsCount, kDistinctLabels);
    expect(measurer.metricsEvictionCount, 0);

    // The paragraph map is bounded at 512, so 600 inserts leave 512 live and
    // evict 88. Eviction is one-per-insert once full.
    expect(measurer.liveParagraphCount, kParagraphCacheLimit);
    expect(measurer.paragraphEvictionCount,
        kDistinctLabels - kParagraphCacheLimit);
  });

  test('referenceWalk culls sub-threshold text at its own default', () {
    // The third of Plan 3f's three named untested defaults, and the one still
    // open. Two callers exist and neither closes it:
    // `test/support/fixtures.dart:183` re-declares its own
    // `minTextCapPixels = kMinTextCapPixels` and always passes it on, so the
    // parameter is shadowed for anything routed through `referenceToRecording`
    // — which is why this calls `referenceWalk` directly.
    // `test/differential_test.dart:63` does call it bare, but asserts only
    // `expect(sink.ops, isNotEmpty)`, which stays true at any threshold.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);

    final doc = DraftDocument.empty(measurer: measurer);
    // 1.0 world unit at the unit camera is 1.0 px of cap height, a third of
    // `kMinTextCapPixels`. Drawn beside a label that clears the threshold, so
    // the walk is proved to be culling rather than simply drawing nothing.
    addText(doc, doc.rootHandle, const Handle(1001), 'TINY', 40, 40, 1.0);
    addText(doc, doc.rootHandle, const Handle(1002), 'BIG', 40, 200, 30.0);

    final sink = RecordingDrawSink();
    referenceWalk(
        doc, sink, unitCamera(), kViewport, DocumentStyleResolver(doc));

    final drawn = sink.ops.whereType<TextOp>().map((op) => op.text).toList();
    expect(drawn, ['BIG'],
        reason: 'TINY is 1 px of cap height against a 3.0 px default');
  });
}
