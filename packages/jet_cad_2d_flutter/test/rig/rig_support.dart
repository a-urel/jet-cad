// Shared corpus and camera helpers for the rigs. R1/R3 (`paint_microbench_test.dart`)
// and the Task 4 spike (`batch_spike_test.dart`) both need the same document
// and the same cameras — a spike measured on a different corpus than the rig
// it is compared against measures nothing.

import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

const Size kRigViewport = Size(1600, 1200);

/// Root instances per document, held fixed across both entity counts.
///
/// **Not the plan's `definitionCount: entityCount ~/ 25`.** That asks for
/// 20,000 definitions and 500,000 root instances at the large size, and the
/// document never finishes building: `DocumentTree._link` scans and copies the
/// parent's `children` list on every add, so filling one parent is quadratic in
/// its child count. Measured on this machine, at 50,000 entities: 6,250
/// instances 236 ms, 12,500 → 532 ms, 25,000 → 2,684 ms, 50,000 → 15,767 ms —
/// four times the instances, thirty times the time. Loading a file does not go
/// through it (`DraftDocumentCodec` uses `addNodeUnchecked`), so this is the
/// command path only, and fixing it means changing how a node holds its
/// children. Recorded for a later plan; the rig works around it.
///
/// 200 definitions each placed 100 times is also the more honest floor plan.
/// A drawing with one definition per 25 entities has no reuse to measure.
const int kDefinitionCount = 200;
const int kInstanceCount = 20000;

/// A viewport-sized window over the document centre.
///
/// The fit camera draws the entire drawing, which is the worst case and not a
/// frame anyone renders. This is the one that speaks to a frame budget: the
/// working set a user actually looks at.
ViewportTransform workingSetCamera(DraftDocument doc) {
  final e = doc.extents;
  final cx = (e.minX + e.maxX) / 2;
  final cy = (e.minY + e.maxY) / 2;
  // 3000 x 2250 world units at 1600 x 1200 px: a room or two of a floor plan
  // whose whole extent is 60000 x 40000.
  return ViewportTransform.fit(
      Aabb2(Vector2(cx - 1500, cy - 1125), Vector2(cx + 1500, cy + 1125)),
      kRigViewport);
}

/// Fits the entire drawing — the worst case, and not a frame anyone renders.
ViewportTransform wholeDrawingCamera(DraftDocument doc) =>
    ViewportTransform.fit(doc.extents, kRigViewport);

DraftDocument rigCorpus(int entityCount) => generateDocument(
      entityCount,
      definitionCount: kDefinitionCount,
      instanceCount: kInstanceCount,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 50,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35,
    );

/// `rigCorpus` plus text. A separate function, not a flag on [rigCorpus]:
/// `labelFraction` comes out of the root budget, so switching it on inside
/// [rigCorpus] would move the line, polyline, circle and arc counts and retire
/// Plan 3b's dash and canvas-call baselines as a side effect.
///
/// [measurer] is required and has no default. Ruling 32: a corpus with
/// `labelFraction` on and the zero-metrics `InsertionPointMeasurer` collapses
/// every glyph box to a point and every text transform to a singular matrix —
/// `doc.extents` then omits the labels, both cameras move, and the rig
/// measures a drawing nothing renders. The caller passes the measurer so it
/// can decide whether the document shares one cache with the sink or keeps
/// its own; that choice changes the distinct-key count and the rig reports
/// both.
DraftDocument textRigCorpus(int entityCount,
        {required TextMeasurer measurer}) =>
    generateDocument(
      entityCount,
      definitionCount: kDefinitionCount,
      instanceCount: kInstanceCount,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 50,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35,
      labelFraction: 0.02,
      attributedInstanceFraction: 0.2,
      measurer: measurer,
    );

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
}
