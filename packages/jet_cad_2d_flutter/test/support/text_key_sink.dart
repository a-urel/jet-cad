import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// Counts the distinct `(string, styleHandle, argb)` triples a frame draws,
/// and nothing else.
///
/// That triple is `FlutterTextMeasurer`'s cache key. The number of *distinct*
/// ones visible at a camera is the number of entries the cache must hold for a
/// steady-state frame to lay nothing out, so it is what decides whether the
/// zero-new-layouts gate row is reachable at all — a count above
/// `kParagraphCacheLimit` makes that row unpassable by construction, no matter
/// how the painter behaves.
///
/// A [RecordingDrawSink] would answer the same question and would also
/// materialise every one of the frame's other ops; at 500,000 entities that is
/// the measurement changing what it measures.
class TextKeySink implements DrawSink {
  /// Draws per distinct key, so a hit rate can be taken as well as an entry
  /// count: `1 - keys/ops` is the fraction of this frame's text that a warm
  /// cache serves without laying anything out.
  final Map<(String, int, int), int> drawsPerKey = <(String, int, int), int>{};
  int textOps = 0;

  Iterable<(String, int, int)> get keys => drawsPerKey.keys;

  void reset() {
    drawsPerKey.clear();
    textOps = 0;
  }

  /// True for a generated ATTRIB's tag, `ATTRnnnnn`.
  ///
  /// The corpus's two text sources have opposite cache behaviour by
  /// construction — 928 label entities share a twenty-word vocabulary, while
  /// every one of the 4,000 attributes carries a string built from its own
  /// instance ordinal — and separating those two distributions is, in the
  /// spec's words, the whole reason the corpus has both. The sink cannot see
  /// an entity's kind, so it classifies by the shape `_addInstanceAttribute`
  /// gives the tag. **The rig cross-checks the split against the entity-kind
  /// counts it takes from the document**, so this predicate is checked rather
  /// than assumed.
  static bool isAttributeTag(String text) =>
      text.length == 9 &&
      text.startsWith('ATTR') &&
      int.tryParse(text.substring(4)) != null;

  @override
  void text(String text, Handle style, ResolvedStyle resolved) {
    final key = (text, style.value, resolved.argb);
    drawsPerKey[key] = (drawsPerKey[key] ?? 0) + 1;
    textOps++;
  }

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {}
  @override
  void endResidual() {}
  @override
  void point(double x, double y, ResolvedStyle style) {}
  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {}
  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) {}
  @override
  void arc(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style) {}
  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
      ResolvedStyle style) {}
  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {}
}
