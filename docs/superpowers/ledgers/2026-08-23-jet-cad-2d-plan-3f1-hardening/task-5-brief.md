## Task 5: `TextKeySink` moves, and the text-cache invariants become assertions

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/support/text_key_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/rig/rig_support.dart` — delete the class, import it
- Create: `packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart`

**Interfaces:**
- Consumes: `FlutterTextMeasurer()` bare, `CanvasDrawSink`, `DraftPainter`, `referenceWalk`.
- Produces: `test/support/text_key_sink.dart` exporting `TextKeySink` — the rig, `flutter_text_measurer_test.dart` and this new file all import it from there.

**Why the sink matters, and why the obvious helper is wrong.** The two caches
fill on two different paths. `measure()` fills the metrics map and
`DraftPainter._drawText` calls it directly at `draft_painter.dart:873`, so any
sink reaches it. `paragraphFor` fills the paragraph map and has exactly **one**
production caller — `CanvasDrawSink.text` at `canvas_draw_sink.dart:207`.
`paintToRecording` (`test/support/fixtures.dart:167`) drives a
`RecordingDrawSink`, and `TextKeySink` records only keys: either would report
`textOpCount == 600` with `liveParagraphCount` sitting at **zero**.

**Why the camera is built by hand.** `ViewportTransform.fit` applies a 0.95
margin, and deriving an expected on-screen cap height through it cost Plan 3f
two tasks. This fixture builds `ViewportTransform` directly at scale `1.0`, so
world units are screen pixels and the threshold arithmetic is `8.0 >= 3.0` with
nothing to get wrong.

- [ ] **Step 1: Move `TextKeySink` without changing it**

Create `packages/jet_cad_2d_flutter/test/support/text_key_sink.dart` holding
the class exactly as it stands at `test/rig/rig_support.dart:111-167`,
including its full doc comment and the `isAttributeTag` static. Add the imports
it needs:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
```

Then in `test/rig/rig_support.dart`, delete the class and add:

```dart
import '../support/text_key_sink.dart';
export '../support/text_key_sink.dart';
```

The `export` keeps `paint_microbench_test.dart` and
`flutter_text_measurer_test.dart` compiling unchanged — they import
`rig_support.dart` and reference `TextKeySink` through it. One definition, four
readers.

- [ ] **Step 2: Verify the move changed nothing**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/flutter_text_measurer_test.dart
flutter analyze
```

Expected: green, and analyze clean — which is what proves no import went stale.
`unused_import` is an error in this package, so a leftover import fails here
rather than at review.

- [ ] **Step 3: Write the failing invariant test**

Create `packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart`:

```dart
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
// passed all 297 tests in the suite it shipped with. Nine of the twelve
// constructions in `flutter_text_measurer_test.dart` are already bare, so bare
// construction was never the missing half: **no test in that file ever pushed
// past 512 distinct metrics keys**, so nothing it asserted was sensitive to
// `metricsLimit` at any value. This file supplies the other half.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

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
    // `test/support/fixtures.dart:184` re-declares its own
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
    referenceWalk(doc, sink, unitCamera(), kViewport,
        DocumentStyleResolver(doc));

    final drawn = sink.ops.whereType<TextOp>().map((op) => op.text).toList();
    expect(drawn, ['BIG'],
        reason: 'TINY is 1 px of cap height against a 3.0 px default');
  });
}
```

**Where the names come from.** `RecordingDrawSink` and `TextOp` are production
types in `lib/src/draw_sink.dart:289` and `:267`, both exported from the
package barrel, and `TextOp` carries its string in a field named `text`.
`kLogicalPixelsPerMm` is exported from `draft_canvas.dart:19`. The only import
this file needs beyond the barrel is `../support/fixtures.dart`, for `addText`
and `kViewport`.

- [ ] **Step 4: Run it**

```sh
CI=true flutter test test/invariants/text_cache_invariants_test.dart
```

Expected: both PASS. If the first fails on `painter.culledTextCount`, the grid
arithmetic is wrong and the fixture is not drawing what it claims — fix the
fixture, never the expectation.

- [ ] **Step 5: Fire mutants M12, M13, M14**

`cp lib/src/flutter_text_measurer.dart /tmp/ftm.dart.bak` and
`cp lib/src/reference_walk.dart /tmp/rw.dart.bak`; restore from the copies.

| mutant | edit | must redden |
|---|---|---|
| M12 | `this.metricsLimit = kParagraphCacheLimit` | `liveMetricsCount` reads 512, `metricsEvictionCount` reads 88 |
| M13 | `this.paragraphLimit = kMetricsCacheLimit` | `liveParagraphCount` reads 600, `paragraphEvictionCount` reads 0 |
| M14 | `reference_walk.dart:36` default → `0.0` | `drawn` reads `['TINY', 'BIG']` |

M12 is Plan 3f's survivor: run the **whole** Flutter suite under it, not just
this file, and record that the only red is here. That is the evidence the hole
is closed rather than moved.

- [ ] **Step 6: Full suite, then commit**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

```bash
git add packages/jet_cad_2d_flutter/test/support/text_key_sink.dart \
        packages/jet_cad_2d_flutter/test/rig/rig_support.dart \
        packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart
git commit -m "test: the text cache's default bounds become an always-on gate

Plan 3f's mutant 7 passed all 297 tests. The recorded reason was that every
test in flutter_text_measurer_test.dart supplied both bounds explicitly;
nine of its twelve constructions are in fact bare. The real reason is
single: no test ever pushed past 512 distinct metrics keys, so nothing it
asserted was sensitive to metricsLimit at any value.

600 distinct labels sit between the two bounds, painted through a
CanvasDrawSink over a PictureRecorder -- paragraphFor has exactly one
production caller and a RecordingDrawSink never reaches it. The camera is
built by hand at scale 1.0 rather than through ViewportTransform.fit,
whose 0.95 margin cost Plan 3f two tasks.

Also closes reference_walk's minTextCapPixels default, the third of Plan
3f's three named untested defaults. Its two callers shadow it: one
re-declares the same default, the other asserts only that ops are
non-empty."
```

---

