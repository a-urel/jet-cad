import 'dart:collection';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

/// The paragraph cache's entry ceiling.
///
/// **Owned by Plan 3c Task 9 and moves at most once, under Ruling 4.** A
/// paragraph holds native glyph memory, so this bound is about memory, and it
/// is sized against what one *frame* draws.
const int kParagraphCacheLimit = 512;

/// The metrics cache's entry ceiling.
///
/// **A different number for a different reason, and deliberately not shared
/// with [kParagraphCacheLimit].** A [TextMetrics] is four doubles, so this
/// bound is not about memory; it exists so the map is not unbounded. It is
/// sized against what a full `DraftDocument.extents` sweep *touches*, which is
/// every text entity in the document, because level of detail deliberately does
/// not apply on the query path.
///
/// The rig corpus is expected to hold about 4,020 distinct
/// `(text, styleHandle)` pairs — 4,000 unique `ATTRnnnnn` strings and the
/// twenty distinct labels Ruling 17 pins — and this is that with room. **That
/// figure is derived from the corpus generator, not yet measured;** Plan 3f
/// Task 8 replaces this sentence with the measured count.
///
/// Raising this does not spend Ruling 4's single permitted raise. Ruling 4
/// names [kParagraphCacheLimit] and the zero-new-layouts paint row.
const int kMetricsCacheLimit = 8192;

/// The colour a metrics-only request is built with.
///
/// A `ui.Paragraph` bakes its colour at [ParagraphBuilder.pushStyle] time, so a
/// paragraph must be built to read metrics off it — but colour cannot change
/// metrics, so the one built for a metrics request is built at this declared
/// colour and disposed immediately. See [FlutterTextMeasurer.measure].
const int kMetricsProbeArgb = 0xFF000000;

/// Lays a string out once, at [kNominalTextPixels], behind two caches.
///
/// **Layout is size-independent by design.** Height, rotation, width factor and
/// oblique angle are transforms applied to the laid-out box afterwards — see
/// `text_geometry.dart` — so the only inputs that can change a layout are the
/// string, the font and the colour a paragraph is baked with. That is why this
/// class needs no scale-band invalidation axis at all.
///
/// **Two maps, because one key cannot serve both callers.** `ui.Paragraph`
/// bakes its colour, so a drawn paragraph is genuinely keyed by
/// `(text, styleHandle, argb)`. [TextMetrics] is not: colour cannot change
/// metrics. A single map keyed on the wide tuple lays every coloured string out
/// twice — once at [kMetricsProbeArgb] for [measure] and once at the entity's
/// colour for [paragraphFor] — and, worse, lets a full `extents` sweep evict
/// every paragraph the paint path had warm. Splitting them is what makes one
/// shared measurer safe.
class FlutterTextMeasurer implements TextMeasurer {
  FlutterTextMeasurer({
    this.paragraphLimit = kParagraphCacheLimit,
    this.metricsLimit = kMetricsCacheLimit,
  });

  /// Paragraph entries kept before the least-recently-touched one is evicted.
  final int paragraphLimit;

  /// Metrics entries kept before the least-recently-touched one is evicted.
  final int metricsLimit;

  /// Real `ParagraphBuilder.build()` calls since construction, whether the
  /// paragraph was kept or was a disposed metrics probe.
  int layoutCount = 0;

  /// Paragraph entries evicted since construction.
  ///
  /// Split from [metricsEvictionCount] because the two cost different things:
  /// this one released native glyph memory and guarantees a future re-layout,
  /// that one dropped four doubles. Ruling 54 is about exactly this — a blended
  /// number hides which half moved.
  int paragraphEvictionCount = 0;

  /// Metrics entries evicted since construction.
  int metricsEvictionCount = 0;

  /// The paragraph most recently evicted, already [Paragraph.dispose]d.
  ///
  /// Debug-only surface for the disposal assertion: a bound on the *entry
  /// count* says nothing about the native glyph memory an evicted `Paragraph`
  /// held unless eviction actually released it.
  Paragraph? debugLastEvicted;

  /// The metrics probe most recently built and disposed, already
  /// [Paragraph.dispose]d.
  ///
  /// Debug-only surface for the disposal assertion, mirroring
  /// [debugLastEvicted] for exactly the same reason: a bound on the entry
  /// count says nothing about whether the probe's native glyph memory was
  /// actually released, and this is the highest-frequency disposal site in
  /// the class — once per metrics miss.
  Paragraph? debugLastProbe;

  /// Live entries in the paragraph cache — native paragraphs, which is what
  /// Plan 3c's "peak live paragraphs" row means.
  int get liveParagraphCount => _paragraphs.length;

  /// Live entries in the metrics cache.
  int get liveMetricsCount => _metrics.length;

  /// Zeroes all three counters without touching either map.
  ///
  /// It deliberately leaves the entries alone. The counters are per-
  /// measurement; the caches are the thing being measured, and a reset that
  /// cleared them would guarantee the next frame lays everything out again —
  /// the opposite of the steady state every text row is about.
  void resetCounters() {
    layoutCount = 0;
    paragraphEvictionCount = 0;
    metricsEvictionCount = 0;
  }

  /// Insertion-ordered so the first key is always the least recently touched.
  final LinkedHashMap<_ParagraphKey, _ParagraphEntry> _paragraphs =
      LinkedHashMap<_ParagraphKey, _ParagraphEntry>();

  final LinkedHashMap<_MetricsKey, _MetricsEntry> _metrics =
      LinkedHashMap<_MetricsKey, _MetricsEntry>();

  /// Mutated in place and reused so a lookup never allocates a key object of
  /// its own — only a miss allocates the immutable key an inserted entry keeps.
  /// Never stored: anything read out by probing with it is copied into a return
  /// value before its fields are next overwritten.
  final _ParagraphKey _paragraphProbe = _ParagraphKey('', Handle.none, 0);
  final _MetricsKey _metricsProbe = _MetricsKey('', Handle.none);

  /// The paragraph for [text] set in [style] at [argb], laid out once and
  /// cached under `(text, styleHandle, argb)` thereafter.
  ///
  /// [styleHandle] and [style] are deliberately separate: the cache key is the
  /// handle, not the record's field values, so [style] only matters on a miss,
  /// when it supplies the `fontFamily` a fresh layout is built with.
  Paragraph paragraphFor(
      String text, Handle styleHandle, TextStyleRecord style, int argb) {
    _paragraphProbe
      ..text = text
      ..styleHandle = styleHandle
      ..argb = argb;
    final hit = _paragraphs[_paragraphProbe];
    if (hit != null) {
      _paragraphs.remove(hit.key);
      _paragraphs[hit.key] = hit;
      return hit.paragraph;
    }
    final paragraph = _layOut(text, style, argb);
    if (_paragraphs.length >= paragraphLimit) _evictOldestParagraph();
    final key = _ParagraphKey(text, styleHandle, argb);
    // Unreachable by construction: this line is only reached after an exact-key
    // miss, and `measure` never inserts here. A displaced entry would be a
    // `Paragraph` dropped without `dispose()` — a native leak — so the
    // invariant is asserted rather than handled, because handling it would be
    // dead code and a mutation of dead code is equivalent by construction.
    assert(!_paragraphs.containsKey(key));
    _paragraphs[key] = _ParagraphEntry(key, paragraph);
    return paragraph;
  }

  /// Metrics for [text] in [style], cached colour-free.
  ///
  /// **This does not consult the paragraph map, and that is a decision.** That
  /// map is keyed on `(text, styleHandle, argb)` and cannot be queried on the
  /// narrow pair without either a linear scan or a third reverse index. Neither
  /// is needed: `DraftPainter._drawText` calls this *before* it calls
  /// `DrawSink.text`, and `DrawSink.text` is the only route to [paragraphFor],
  /// so at first sight of a string the paragraph map has nothing to find. A
  /// probe could only pay after a metrics eviction, and [metricsLimit] is sized
  /// above the corpus's whole distinct-key count so that does not happen.
  ///
  /// The paragraph built here is **disposed**, not kept. ACI 7 resolves to
  /// white (`resolved_style.dart`), so [kMetricsProbeArgb]'s black is almost
  /// never the drawn colour; keeping it would hold two paragraph entries per
  /// distinct string and halve this cache's effective capacity.
  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) {
    _metricsProbe
      ..text = text
      ..styleHandle = style.handle;
    final hit = _metrics[_metricsProbe];
    if (hit != null) {
      _metrics.remove(hit.key);
      _metrics[hit.key] = hit;
      return hit.metrics;
    }
    final probe = _layOut(text, style, kMetricsProbeArgb);
    final metrics = _metricsOf(probe);
    probe.dispose();
    debugLastProbe = probe;
    if (_metrics.length >= metricsLimit) _evictOldestMetrics();
    final key = _MetricsKey(text, style.handle);
    _metrics[key] = _MetricsEntry(key, metrics);
    return metrics;
  }

  Paragraph _layOut(String text, TextStyleRecord style, int argb) {
    // Layout is always at kNominalTextPixels — never the entity's effective
    // height. Height, rotation, width factor and oblique angle are all
    // transforms applied afterwards, so only the string and the style may
    // affect layout; passing an effective size here would silently destroy the
    // cache and break the claim that text needs no scale-band axis.
    final builder = ParagraphBuilder(ParagraphStyle(
      fontFamily: style.fontFamily,
      fontSize: kNominalTextPixels,
      textAlign: TextAlign.left,
    ))
      ..pushStyle(TextStyle(
          color: Color(argb),
          fontFamily: style.fontFamily,
          fontSize: kNominalTextPixels))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ParagraphConstraints(width: double.infinity));
    layoutCount++;
    return paragraph;
  }

  TextMetrics _metricsOf(Paragraph paragraph) {
    final lines = paragraph.computeLineMetrics();
    return TextMetrics(
      // `longestLine` is -FLT_MAX, not 0, for a paragraph with no lines, and
      // -FLT_MAX is finite — so this shares `ascent`'s and `descent`'s guard
      // rather than relying on an isFinite check downstream.
      // `MetricModelMeasurer` returns 0.0 here and the two must agree: the
      // differential oracle assumes the seam's two implementations are
      // interchangeable.
      advanceWidth: lines.isEmpty ? 0 : paragraph.longestLine,
      ascent: lines.isEmpty ? 0 : lines.first.ascent,
      descent: lines.isEmpty ? 0 : lines.first.descent,
      // dart:ui exposes no cap height; the declared ratio stands in for it.
      capHeight: kCapHeightRatio * kNominalTextPixels,
    );
  }

  void _evictOldestParagraph() {
    final oldestKey = _paragraphs.keys.first;
    final evicted = _paragraphs.remove(oldestKey)!;
    evicted.paragraph.dispose();
    debugLastEvicted = evicted.paragraph;
    paragraphEvictionCount++;
  }

  void _evictOldestMetrics() {
    _metrics.remove(_metrics.keys.first);
    metricsEvictionCount++;
  }

  /// Disposes every cached paragraph and empties both maps.
  ///
  /// **The application calls this, not the widget.** The document owns the
  /// measurer, two canvases over one document share it, and a canvas that
  /// cleared on dispose would wipe its sibling's cache. A `Paragraph` holds
  /// native glyph memory that outlives the Dart object referencing it until
  /// [Paragraph.dispose] runs, so whoever constructed this object has to reach
  /// every live entry when the document is retired.
  void clear() {
    for (final entry in _paragraphs.values) {
      entry.paragraph.dispose();
    }
    _paragraphs.clear();
    _metrics.clear();
  }
}

/// `(text, styleHandle, argb)`. Mutable so [FlutterTextMeasurer._paragraphProbe]
/// can reuse one instance as a lookup key across calls; every key actually
/// *stored* is a separate, never-mutated-again instance built on a miss.
class _ParagraphKey {
  _ParagraphKey(this.text, this.styleHandle, this.argb);

  String text;
  Handle styleHandle;
  int argb;

  @override
  bool operator ==(Object other) =>
      other is _ParagraphKey &&
      other.text == text &&
      other.styleHandle == styleHandle &&
      other.argb == argb;

  @override
  int get hashCode => Object.hash(text, styleHandle, argb);
}

/// `(text, styleHandle)`. Mutable for the same reason [_ParagraphKey] is.
///
/// A record key would be the obvious spelling and is the wrong one: building
/// one per lookup was measured at roughly 41 `_Record` allocations per pick and
/// broke `query_allocation_test`. See `MetricModelMeasurer`'s doc comment.
class _MetricsKey {
  _MetricsKey(this.text, this.styleHandle);

  String text;
  Handle styleHandle;

  @override
  bool operator ==(Object other) =>
      other is _MetricsKey &&
      other.text == text &&
      other.styleHandle == styleHandle;

  @override
  int get hashCode => Object.hash(text, styleHandle);
}

class _ParagraphEntry {
  _ParagraphEntry(this.key, this.paragraph);

  final _ParagraphKey key;
  final Paragraph paragraph;
}

class _MetricsEntry {
  _MetricsEntry(this.key, this.metrics);

  final _MetricsKey key;

  /// The same instance on every hit: the pick path measures per candidate and a
  /// fresh object per call breaks `query_allocation_test`.
  final TextMetrics metrics;
}
