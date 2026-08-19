import 'dart:collection';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

/// The paragraph cache's entry ceiling.
///
/// **Owned by this task and moves at most once.** A future task may raise it,
/// but only alongside a measured distinct-visible-key count recorded beside
/// it — never to relax the zero-new-layouts gate a paint-path test checks
/// against, and never behind an eviction-policy switch.
const int kParagraphCacheLimit = 512;

/// The colour a metrics-only request is built with.
///
/// [FlutterTextMeasurer.measure] shares [FlutterTextMeasurer.paragraphFor]'s
/// cache, whose key includes an ARGB colour because `ui.Paragraph` bakes
/// colour in at build time. Colour cannot change metrics, though, so every
/// metrics-only request is built under this one declared colour rather than
/// adding a cache entry per colour a caller happens to ask metrics for.
const int kMetricsProbeArgb = 0xFF000000;

/// Lays a string out once, at [kNominalTextPixels], behind an LRU cache of
/// `ui.Paragraph`s.
///
/// **Layout is size-independent by design.** Height, rotation, width factor
/// and oblique angle are transforms applied to the laid-out box afterwards —
/// see `text_geometry.dart` — so the only inputs that can change the layout
/// are the string, the font and the colour a paragraph is baked with. That is
/// why a repeat request for the same `(text, style, colour)` triple is a
/// cache hit rather than a re-layout, and why this class needs no
/// scale-band invalidation axis at all.
///
/// **Why the key carries an ARGB colour.** `Canvas.drawParagraph` takes no
/// `Paint` — a `ui.Paragraph` bakes its colour in at
/// [ParagraphBuilder.pushStyle] time — so two same-string entities in
/// different colours are genuinely two different native paragraphs, not one
/// paragraph drawn twice. A key without the colour would draw one of them in
/// the wrong colour.
class FlutterTextMeasurer implements TextMeasurer {
  FlutterTextMeasurer({this.limit = kParagraphCacheLimit});

  /// Entries kept before the least-recently-touched one is evicted.
  final int limit;

  /// Real `ParagraphBuilder.build()` calls since construction.
  int layoutCount = 0;

  /// Entries evicted since construction.
  int evictionCount = 0;

  /// The paragraph most recently evicted, already [Paragraph.dispose]d.
  ///
  /// Debug-only surface for the disposal assertion: a bound on the cache's
  /// *entry count* says nothing about the native glyph memory an evicted
  /// `Paragraph` held unless eviction actually released it, so a test needs
  /// a handle on the evicted paragraph to check `debugDisposed` against.
  Paragraph? debugLastEvicted;

  /// Live entries in the cache.
  int get liveParagraphCount => _cache.length;

  /// Insertion-ordered so the first key is always the least recently
  /// touched: [_touch] removes and reinserts a key on every hit, which moves
  /// it to the end, leaving the untouched entries at the front for
  /// [_evictOldest] to find in O(1).
  final LinkedHashMap<_CacheKey, _Entry> _cache =
      LinkedHashMap<_CacheKey, _Entry>();

  /// Mutated in place and reused across calls so a lookup never allocates a
  /// key object of its own — only a cache *miss* allocates the immutable key
  /// an inserted entry keeps for itself. Never stored: every value read out
  /// of [_cache] by probing with this object is copied into a return value
  /// before this object's fields are next overwritten.
  final _CacheKey _probe = _CacheKey('', Handle.none, 0);

  /// The paragraph for [text] set in [style] at [argb], laid out once and
  /// cached under `(text, styleHandle, argb)` thereafter.
  ///
  /// [styleHandle] and [style] are deliberately separate: the cache key is
  /// the handle, not the record's field values, so [style] only matters on a
  /// miss, when it supplies the `fontFamily` a fresh layout is built with.
  Paragraph paragraphFor(
          String text, Handle styleHandle, TextStyleRecord style, int argb) =>
      _entryFor(text, styleHandle, style, argb).paragraph;

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      _entryFor(text, style.handle, style, kMetricsProbeArgb).metrics;

  /// The cached entry for `(text, styleHandle, argb)`, built and inserted on
  /// a miss.
  ///
  /// The lookup itself allocates nothing: [_probe] is overwritten in place
  /// and handed to the map only to compare, never to be stored. On a hit the
  /// entry is touched (moved to the most-recently-used end) and returned
  /// as-is — the same [_Entry], the same [TextMetrics] instance, every time —
  /// which is what lets a repeat [measure] call return `identical` metrics.
  _Entry _entryFor(
      String text, Handle styleHandle, TextStyleRecord style, int argb) {
    _probe
      ..text = text
      ..styleHandle = styleHandle
      ..argb = argb;
    final hit = _cache[_probe];
    if (hit != null) {
      _touch(hit);
      return hit;
    }
    return _buildEntry(text, styleHandle, style, argb);
  }

  void _touch(_Entry entry) {
    _cache.remove(entry.key);
    _cache[entry.key] = entry;
  }

  _Entry _buildEntry(
      String text, Handle styleHandle, TextStyleRecord style, int argb) {
    // Layout is always at kNominalTextPixels — never the entity's effective
    // height. Height, rotation, width factor and oblique angle are all
    // transforms applied afterwards, so only the string and the style may
    // affect layout; passing an effective size here would silently destroy
    // the cache (every distinct on-screen size would re-lay the same string
    // out again) and break the plan's central claim that text needs no
    // scale-band invalidation axis.
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
    final lines = paragraph.computeLineMetrics();
    final metrics = TextMetrics(
      // `longestLine` is -FLT_MAX, not 0, for a paragraph with no lines,
      // and -FLT_MAX is finite — so this shares `ascent`'s and
      // `descent`'s guard rather than relying on an isFinite check
      // downstream. `MetricModelMeasurer` returns 0.0 here and the two
      // must agree: the differential oracle assumes the seam's two
      // implementations are interchangeable.
      advanceWidth: lines.isEmpty ? 0 : paragraph.longestLine,
      ascent: lines.isEmpty ? 0 : lines.first.ascent,
      descent: lines.isEmpty ? 0 : lines.first.descent,
      // dart:ui exposes no cap height; the declared ratio stands in for it
      // and the deviation is recorded in the results note.
      capHeight: kCapHeightRatio * kNominalTextPixels,
    );
    layoutCount++;

    if (_cache.length >= limit) _evictOldest();

    final key = _CacheKey(text, styleHandle, argb);
    final entry = _Entry(key, paragraph, metrics);
    _cache[key] = entry;
    return entry;
  }

  void _evictOldest() {
    final oldestKey = _cache.keys.first;
    final evicted = _cache.remove(oldestKey)!;
    evicted.paragraph.dispose();
    debugLastEvicted = evicted.paragraph;
    evictionCount++;
  }

  /// Disposes every cached paragraph and empties the cache.
  ///
  /// For a widget that owns this measurer for its whole lifetime: a
  /// `Paragraph` holds native glyph memory that outlives the Dart object
  /// referencing it until [Paragraph.dispose] runs, so the owner's own
  /// `dispose()` has to reach every live entry, not just drop the map.
  void clear() {
    for (final entry in _cache.values) {
      entry.paragraph.dispose();
    }
    _cache.clear();
  }
}

/// `(text, styleHandle, argb)`. Mutable so [FlutterTextMeasurer._probe] can
/// reuse one instance as a lookup key across calls; every key actually
/// *stored* in the cache is a separate, never-mutated-again instance built
/// on a miss.
class _CacheKey {
  _CacheKey(this.text, this.styleHandle, this.argb);

  String text;
  Handle styleHandle;
  int argb;

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      other.text == text &&
      other.styleHandle == styleHandle &&
      other.argb == argb;

  @override
  int get hashCode => Object.hash(text, styleHandle, argb);
}

class _Entry {
  _Entry(this.key, this.paragraph, this.metrics);

  final _CacheKey key;
  final Paragraph paragraph;
  final TextMetrics metrics;
}
