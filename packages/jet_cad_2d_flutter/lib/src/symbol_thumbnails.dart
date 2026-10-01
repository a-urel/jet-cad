import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'draft_canvas.dart' show kLogicalPixelsPerMm;
import 'draft_painter.dart';
import 'vertices_draw_sink.dart';
import 'viewport_transform.dart';

/// The fraction of a document's larger side added as a margin on every side
/// before the thumbnail camera fits it.
///
/// Taken from the larger side, not per axis, so a symbol that is one straight
/// line (zero height) still gets a margin across it.
const double kThumbnailPadding = 0.08;

/// Thumbnails of small documents, painted by [DraftPainter] and cached.
///
/// Knows nothing about symbols: a caller hands it a [key] (a value it compares
/// with `==`) and a builder for the document to paint. The cache is an
/// in-memory LRU of [maxEntries] keyed by `(key, logicalSize,
/// devicePixelRatio, foreground)`; it stores the `Future`, so a repeated
/// request never repaints and a pending one is shared. Nothing persists.
///
/// **Ownership of the images.** The cache owns every image it hands out and
/// disposes it when its entry is evicted or the cache is disposed. A holder
/// that keeps an image beyond that must take its own `clone()` when the
/// future completes (in the same callback, or straight after its `await`):
/// an entry evicted while still pending disposes its image one microtask
/// after completion, so every listener of that future can clone it first.
///
/// The paint is the one render path there is: a [VerticesDrawSink] (no text
/// fallback; a thumbnail draws no text) recorded into a picture whose canvas
/// is scaled by the device pixel ratio, then `Picture.toImage`, the
/// asynchronous call that is portable to the web. Off the frame path: the
/// scratch document and index live only for one paint.
class SymbolThumbnails {
  SymbolThumbnails({this.maxEntries = 64}) {
    if (maxEntries < 1) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'must be at least 1');
    }
  }

  /// How many images the cache keeps before it evicts the least recently
  /// requested one.
  final int maxEntries;

  // Insertion order is recency order: a hit is removed and re-inserted.
  final LinkedHashMap<Object, _Entry> _entries =
      LinkedHashMap<Object, _Entry>();

  bool _disposed = false;

  /// The number of entries currently cached, pending or complete.
  int get length => _entries.length;

  /// The image of [document] fitted into [logicalSize], at
  /// `round(width * devicePixelRatio) x round(height * devicePixelRatio)`
  /// device pixels, with ACI 7 drawn in [foreground] (`0xRRGGBB`).
  ///
  /// [document] is called only when the request misses the cache. A builder
  /// or a paint that throws completes the returned future with that error;
  /// this method itself does not throw for it.
  Future<ui.Image> imageFor({
    required Object key,
    required DraftDocument Function() document,
    required ui.Size logicalSize,
    required double devicePixelRatio,
    required int foreground,
  }) {
    if (_disposed) throw StateError('SymbolThumbnails used after dispose');
    // A record compares field by field; the stored values compare exactly.
    final cacheKey = (key, logicalSize, devicePixelRatio, foreground);
    final hit = _entries.remove(cacheKey);
    if (hit != null) {
      _entries[cacheKey] = hit;
      return hit.future;
    }
    final entry =
        _Entry(_paint(document, logicalSize, devicePixelRatio, foreground));
    _entries[cacheKey] = entry;
    while (_entries.length > maxEntries) {
      final oldest = _entries.keys.first;
      _entries.remove(oldest)!.release();
    }
    return entry.future;
  }

  /// Disposes every cached image (a pending one once it completes) and
  /// empties the cache. The cache cannot be used afterwards.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final entry in _entries.values) {
      entry.release();
    }
    _entries.clear();
  }

  static Future<ui.Image> _paint(
    DraftDocument Function() build,
    ui.Size logicalSize,
    double devicePixelRatio,
    int foreground,
  ) async {
    // `async`: a throw anywhere below completes the future with it, never
    // escapes into the caller's build.
    final doc = build();
    final resolver = DocumentStyleResolver(doc, foreground: foreground);
    final extents = doc.extents;
    final pad = kThumbnailPadding *
        math.max(extents.maxX - extents.minX, extents.maxY - extents.minY);
    final camera = ViewportTransform.fit(
        extents.isEmpty ? extents : extents.expandedBy(pad), logicalSize);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(devicePixelRatio);
    final index = SpatialIndex(doc);
    try {
      final sink = VerticesDrawSink(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        canvas: canvas,
        devicePixelRatio: devicePixelRatio,
      );
      DraftPainter(document: doc, index: index, resolver: resolver)
          .paint(sink, camera, logicalSize);
      sink.flush();
    } catch (_) {
      recorder.endRecording().dispose();
      rethrow;
    } finally {
      index.dispose();
    }
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(
        (logicalSize.width * devicePixelRatio).round(),
        (logicalSize.height * devicePixelRatio).round(),
      );
    } finally {
      picture.dispose();
    }
  }
}

class _Entry {
  _Entry(this.future) {
    future.then((image) {
      if (_released) {
        // Evicted while pending: the listeners of [future] run in this same
        // turn, after this one; let them take their clones first.
        scheduleMicrotask(image.dispose);
      } else {
        _image = image;
      }
    }, onError: (Object _, StackTrace __) {
      // The error belongs to whoever awaits [future]; the cache only must
      // not report it as unhandled.
    });
  }

  final Future<ui.Image> future;
  ui.Image? _image;
  bool _released = false;

  void release() {
    _released = true;
    _image?.dispose();
    _image = null;
  }
}
