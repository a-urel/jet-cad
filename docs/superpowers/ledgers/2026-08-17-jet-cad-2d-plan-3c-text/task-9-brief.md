## Task 9: `FlutterTextMeasurer` and the paragraph cache

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`
- Test: `packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart`

**Interfaces:**
- Consumes: `TextMetrics`, `TextMeasurer`, `kNominalTextPixels`, `kCapHeightRatio`.
- Produces: `FlutterTextMeasurer implements TextMeasurer` with `Paragraph paragraphFor(String text, Handle styleHandle, TextStyleRecord style, int argb)`, `int get layoutCount`, `int get evictionCount`, `int get liveParagraphCount`, `void clear()`; `const int kParagraphCacheLimit = 512`.

- [ ] **Step 1: Write the failing tests**

```dart
test('the same string in two colours is two entries, not one', () {
  final m = FlutterTextMeasurer();
  m.paragraphFor('WC', const Handle(7), _style, 0xFFFF0000);
  m.paragraphFor('WC', const Handle(7), _style, 0xFF00FF00);
  // ui.Paragraph bakes its colour and drawParagraph takes no Paint, so a key
  // without argb would draw one of these in the wrong colour.
  expect(m.layoutCount, 2);
  expect(m.liveParagraphCount, 2);
});

test('a repeat request lays out nothing and allocates no metrics', () {
  final m = FlutterTextMeasurer();
  final a = m.measure(text: 'WC', style: _style);
  final before = m.layoutCount;
  final b = m.measure(text: 'WC', style: _style);
  expect(m.layoutCount, before);
  // The pick path measures per candidate; a fresh object per call breaks
  // query_allocation_test.
  expect(identical(a, b), isTrue);
});

test('eviction disposes the paragraph', () {
  final m = FlutterTextMeasurer(limit: 2);
  m.paragraphFor('A', const Handle(7), _style, 0xFF000000);
  m.paragraphFor('B', const Handle(7), _style, 0xFF000000);
  m.paragraphFor('C', const Handle(7), _style, 0xFF000000);
  expect(m.evictionCount, 1);
  expect(m.liveParagraphCount, 2);
  // A Paragraph holds native glyph memory: a bound on the count is not a
  // bound on the memory unless eviction releases it.
  expect(m.debugLastEvicted!.debugDisposed, isTrue);
});

test('metrics are cap-height based and taken at the nominal size', () {
  final m = FlutterTextMeasurer();
  final metrics = m.measure(text: 'WC', style: _style);
  expect(metrics.capHeight, closeTo(kCapHeightRatio * kNominalTextPixels, 1e-9));
  expect(metrics.ascent, greaterThan(0));
  expect(metrics.advanceWidth, greaterThan(0));
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/flutter_text_measurer_test.dart`
Expected: FAIL — `FlutterTextMeasurer` is undefined.

- [ ] **Step 3: Implement it**

Key: a value class over `(String text, Handle style, int argb)` with `==` and
`hashCode`. Entry: `(Paragraph paragraph, TextMetrics metrics)`. LRU: a
`LinkedHashMap` with remove-and-reinsert on hit, `limit` default
`kParagraphCacheLimit = 512`, and `paragraph.dispose()` on eviction.

Layout is always at `kNominalTextPixels`:

```dart
    final builder = ParagraphBuilder(ParagraphStyle(
      fontFamily: style.fontFamily,
      fontSize: kNominalTextPixels,     // never the effective height
      textAlign: TextAlign.left,
    ))
      ..pushStyle(TextStyle(color: Color(argb), fontFamily: style.fontFamily,
          fontSize: kNominalTextPixels))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ParagraphConstraints(width: double.infinity));
    final lines = paragraph.computeLineMetrics();
    final metrics = TextMetrics(
      advanceWidth: paragraph.longestLine,
      ascent: lines.isEmpty ? 0 : lines.first.ascent,
      descent: lines.isEmpty ? 0 : lines.first.descent,
      // dart:ui exposes no cap height; the declared ratio stands in for it and
      // the deviation is recorded in the results note.
      capHeight: kCapHeightRatio * kNominalTextPixels,
    );
```

`measure()` needs an `argb` for the key it shares with drawing. Use a single
declared `kMetricsProbeArgb = 0xFF000000` for metric-only requests and document
why: colour cannot change metrics, so a metrics request reuses the black entry
rather than adding one per colour.

Then implement `CanvasDrawSink.text` properly: `_pushTransform()`, then
`canvas.drawParagraph(measurer.paragraphFor(...), Offset.zero)`. The sink needs
the measurer, so add it as a constructor parameter alongside `pixelsPerPaperMm`
and thread it from `DraftCanvas`.

- [ ] **Step 4: Run and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze`

```bash
git add packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): lay text out once at nominal size behind an LRU"
```

---

