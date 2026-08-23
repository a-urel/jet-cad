## Task 6: the frame accounting invariants

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart`

**Interfaces:**
- Consumes: `unitCamera()` and `addText` — `unitCamera` is duplicated into this file rather than shared, because the two invariant files are meant to be readable alone and a four-line camera helper is not worth a third support file.
- Produces: nothing.

**Three identities, no magic constants.** Each is true at any corpus size,
which is what lets the fixture stay small.

**Why item 3 is what it is.** An earlier draft asserted that five counters
agree across the two backends. All five are `DraftPainter` fields
(`draft_painter.dart:147,167,177,199,210`), `DrawSink` is write-only, and the
painter never branches on which sink it holds — `DraftCanvas` builds one
painter and swaps only the sink. Two paints could not have disagreed, and
dropping a text op inside `VerticesDrawSink` would have moved no painter
counter, so that claim's own mutant could not have reddened it. What replaces
it compares a number the **sink** owns against a number the **painter** owns.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart`:

```dart
// Identities the rig prints and does not assert. None of them carries a magic
// constant: each is true at any corpus size, which is why this fixture is tiny
// and always runs while the rig stays tagged `rig` and skipped.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

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
    first.paint(
      CanvasDrawSink(
        canvas: Canvas(PictureRecorder()),
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        textStyleOf: doc.textStyleOf,
      ),
      unitCamera(),
      kViewport,
    );

    expect(
        (
          first.textOpCount,
          first.culledTextCount,
          first.skippedTextCount,
          first.screenSpaceLeafCount,
        ),
        before);
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
```

**Where the names come from.** `leavesByOwner()` is the enumeration
`reference_walk.dart:41` already uses; `VerticesDrawSink`'s constructor takes
`canvas` directly (`vertices_draw_sink.dart:105-111`) and defaults
`devicePixelRatio` to `1.0`; `RecordingDrawSink` and `TextOp` are production
types exported from the package barrel.

- [ ] **Step 2: Run it**

```sh
CI=true flutter test test/invariants/frame_accounting_test.dart
```

Expected: three PASS.

- [ ] **Step 3: Fire mutants M15, M16, M17**

`cp lib/src/draft_painter.dart /tmp/dp.dart.bak` and
`cp lib/src/vertices_draw_sink.dart /tmp/vds.dart.bak`.

| mutant | edit | must redden |
|---|---|---|
| M15 | in `_drawText`, keep `_culledText++` but delete the `return` after it | `text accounting closes` — the sum exceeds the leaf count |
| M16 | delete `_textOps = 0;` from the top of `paint()` | `a repeated frame is a repeated frame` |
| M17 | in `VerticesDrawSink.text`, guard the delegation so one op is dropped (`if (_frameTextOps++ != 0) _fallback?.text(...)`) | `the vertices backend loses no text` |

M17 needs a counter field to drop exactly one op; add it as part of the
mutation and remove it with the restore. Record all three transcripts.

- [ ] **Step 4: Full suite, then commit**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

```bash
git add packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart
git commit -m "test: three frame-accounting identities the rig only printed

Text accounting closes, a repeated frame reads identically, and the
vertices backend loses no text through its fallback. No magic constants:
each holds at any corpus size, which is why the fixture is tiny and always
runs while the rig stays skipped.

The third identity replaces one that could not fail. Asserting that five
counters agree across backends is guaranteed by construction -- all five
are DraftPainter fields, DrawSink is write-only, and the painter never
branches on its sink. Comparing a sink-owned count against a painter-owned
one is a real comparison; the rig's version has teeth only because it
compares two processes.

The expected leaf count is derived from the document, never read back off
the painter: an identity whose two sides share a source is not one."
```

---

