// Identities the rig prints and does not assert. None of them carries a magic
// constant: each is true at any corpus size, which is why this fixture is tiny
// and always runs while the rig stays tagged `rig` and skipped.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';

/// World == screen, y flipped, no margin. See
/// `text_cache_invariants_test.dart` for why this is not
/// `ViewportTransform.fit`.
ViewportTransform unitCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(1, 0, 0, -1, 0, kViewport.height));

/// Text in all three accounting states at once.
///
/// A fixture where any of the three counters is zero cannot tell a correct
/// accounting identity from one that drops a term.
DraftDocument threeWayTextDocument(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  // Drawn: 30 px of cap height against a 3.0 threshold.
  addText(doc, doc.rootHandle, const Handle(1001), 'ALPHA', 40, 500, 30.0);
  addText(doc, doc.rootHandle, const Handle(1002), 'BETA', 40, 440, 30.0);
  // Culled: 1 px, a third of the threshold.
  addText(doc, doc.rootHandle, const Handle(1003), 'GAMMA', 40, 380, 1.0);
  // Skipped: the empty string is nothing to lay out, and the painter counts it
  // separately from a cull because the two mean different things.
  addText(doc, doc.rootHandle, const Handle(1004), '', 40, 320, 30.0);
  return doc;
}

/// Every text leaf in [doc], counted from the document rather than from the
/// painter.
///
/// Plan 3c's Ruling 28 in miniature: an identity whose two sides come from the
/// same source is not an identity. Reading the expected total back off the
/// painter would make this assertion compare a number with itself.
int textLeafCount(DraftDocument doc) {
  var n = 0;
  // `leavesByOwner()` is the same enumeration `referenceWalk` uses to find
  // leaves, and it is the document's own answer rather than the painter's.
  for (final slots in doc.leavesByOwner().values) {
    for (final slot in slots) {
      final kind = doc.entities.kindAt(slot);
      if (kind == EntityKind.text || kind == EntityKind.attrib) n++;
    }
  }
  return n;
}

/// Paints [doc] once through a `CanvasDrawSink` over a throwaway recorder and
/// returns the painter, counters intact.
({DraftPainter painter, CanvasDrawSink sink}) paintOnce(
  DraftDocument doc,
  SpatialIndex index,
  FlutterTextMeasurer measurer, {
  bool vertices = false,
}) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final sink = CanvasDrawSink(
    canvas: canvas,
    pixelsPerPaperMm: kLogicalPixelsPerMm,
    measurer: measurer,
    textStyleOf: doc.textStyleOf,
  );
  final painter = DraftPainter(
    document: doc,
    index: index,
    resolver: DocumentStyleResolver(doc),
  );
  if (vertices) {
    // `devicePixelRatio` defaults to 1.0 and is left there: the widget rebinds
    // it from `MediaQuery` per frame, and a widgetless test has no display to
    // ask. Nothing this test asserts is in device pixels.
    final batching = VerticesDrawSink(
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      fallback: sink,
      canvas: canvas,
    );
    painter.paint(batching, unitCamera(), kViewport);
    batching.flush();
  } else {
    painter.paint(sink, unitCamera(), kViewport);
  }
  recorder.endRecording().dispose();
  return (painter: painter, sink: sink);
}

void main() {
  test('text accounting closes: drawn + culled + skipped is every text leaf',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = threeWayTextDocument(measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final p = paintOnce(doc, index, measurer).painter;

    // All three non-zero, so no term can be dropped without changing the sum.
    expect(p.textOpCount, greaterThan(0));
    expect(p.culledTextCount, greaterThan(0));
    expect(p.skippedTextCount, greaterThan(0));
    expect(p.textOpCount + p.culledTextCount + p.skippedTextCount,
        textLeafCount(doc));
  });

  test('a repeated frame is a repeated frame', () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = threeWayTextDocument(measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final first = paintOnce(doc, index, measurer).painter;
    final before = (
      first.textOpCount,
      first.culledTextCount,
      first.skippedTextCount,
      first.screenSpaceLeafCount,
    );

    // The same painter, painted again: every counter resets at the top of
    // `paint()`, so a second identical frame must read identically. A counter
    // that accumulates instead of resetting reads double here.
    //
    // The recorder is bound to a local and ended after the paint, exactly as
    // `paintOnce` does for the first frame: an un-ended recording is the
    // "moved the leak" shape Plan 3f was written against (Task 5).
    final recorder = PictureRecorder();
    first.paint(
      CanvasDrawSink(
        canvas: Canvas(recorder),
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        textStyleOf: doc.textStyleOf,
      ),
      unitCamera(),
      kViewport,
    );
    recorder.endRecording().dispose();

    expect((
      first.textOpCount,
      first.culledTextCount,
      first.skippedTextCount,
      first.screenSpaceLeafCount,
    ), before);
  });

  test('the vertices backend loses no text on the way through its fallback',
      () {
    // `VerticesDrawSink` delegates exactly three calls to its fallback --
    // beginResidual, endResidual and text (vertices_draw_sink.dart:300,307,721)
    // -- and of the seven `_canvasCalls++` sites in CanvasDrawSink, none is in
    // the two residual methods. So under this backend that counter counts
    // paragraphs and nothing else, and the equality below is a real comparison
    // between a sink-owned number and a painter-owned one.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = threeWayTextDocument(measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final r = paintOnce(doc, index, measurer, vertices: true);

    expect(r.painter.textOpCount, greaterThan(0),
        reason: 'a fixture drawing no text cannot test a text seam');
    expect(r.sink.canvasCallCount, r.painter.textOpCount);
  });
}
