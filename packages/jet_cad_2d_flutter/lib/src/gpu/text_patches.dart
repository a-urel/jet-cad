import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'instance_record.dart';
import 'resident_text.dart';

/// **Provisional, and Plan F's to move.** The spec leaves the watermark band
/// un-committed as a number (open question 3); Plan E needs a floor to expand
/// an instance's reach at and a ceiling to size a patch target at, and takes
/// these two until Plan F measures the band. `classifyTextPatches` (the
/// floor) and `patchTargetSizeFor` (the ceiling) take them as parameters
/// with these defaults, so a test can pin either edge and Plan F can move
/// them without touching a call site -- `patchRegionFor` takes neither.
const double kBandLowerScale = 0.5;
const double kBandUpperScale = 2.0;

/// Cells an instance's reach-expanded box may span before it leaves the
/// grid for the overflow list, which every label tests. A long wall through
/// a floor plan would otherwise be appended to hundreds of buckets.
const int kClassifyOverflowCells = 16;

/// What one `classifyTextPatches` call did -- diagnostics, for the tests and
/// the harness. Zero everywhere when there are no labels.
class ClassifyStats {
  int cellsX = 0, cellsY = 0;

  /// Instances binned into cells; instances sent to the overflow list;
  /// instances whose expanded box misses every label's union (never tested).
  int binned = 0, overflow = 0, skipped = 0;

  /// `_reaches` calls made. The brute force makes `labels x later instances`.
  int candidatesTested = 0;
}

/// The label box is padded by this many device pixels, taken at the band's
/// LOWER scale (Ruling E9): one device pixel is most collection units at the
/// band's floor, so that is the conservative pad. It covers antialiased glyph
/// edges and glyph overhang past the advance box.
const double kTextBoxPadDevicePixels = 1.0;

/// The miter limit the shader's join branch is bounded by -- a miter tip is
/// never further than `halfWidth * kMiterLimit` from its vertex
/// (`vertices_draw_sink.dart:460, 544-552`). **A copy, not a reference**, by
/// the same rule `GeometryCollector.kMinStrokeDevicePixels` states: the two
/// arms arrive at their numbers separately and the differential is what
/// catches a drift. `resident_text_test.dart` pins this to
/// `VerticesDrawSink.kMiterLimit`.
const double kMiterLimit = 4.0;

/// The axis-aligned bound of the box `(minX, minY)..(maxX, maxY)` under
/// [t]: all four corners transformed and re-bounded, so a rotated, sheared
/// or mirrored box bounds correctly (`Aabb2.transformedBy`'s own rule),
/// written into [out] as `[minX, minY, maxX, maxY]`. Allocation-free --
/// [out] is caller-owned and reused. Called from the rebuild walk (the
/// collector's `text()`, sizing a label's box) and, per frame, from
/// [patchRegionFor] and `text_compositor.dart`'s `labelBoundsLogical` --
/// the frame-path callers this doc once named as future work.
void boundTransformedBox(double minX, double minY, double maxX, double maxY,
    Transform2 t, Float64List out) {
  var lo0 = double.infinity, lo1 = double.infinity;
  var hi0 = double.negativeInfinity, hi1 = double.negativeInfinity;

  final c0x = t.a * minX + t.c * minY + t.e,
      c0y = t.b * minX + t.d * minY + t.f;
  if (c0x < lo0) lo0 = c0x;
  if (c0x > hi0) hi0 = c0x;
  if (c0y < lo1) lo1 = c0y;
  if (c0y > hi1) hi1 = c0y;

  final c1x = t.a * maxX + t.c * minY + t.e,
      c1y = t.b * maxX + t.d * minY + t.f;
  if (c1x < lo0) lo0 = c1x;
  if (c1x > hi0) hi0 = c1x;
  if (c1y < lo1) lo1 = c1y;
  if (c1y > hi1) hi1 = c1y;

  final c2x = t.a * minX + t.c * maxY + t.e,
      c2y = t.b * minX + t.d * maxY + t.f;
  if (c2x < lo0) lo0 = c2x;
  if (c2x > hi0) hi0 = c2x;
  if (c2y < lo1) lo1 = c2y;
  if (c2y > hi1) hi1 = c2y;

  final c3x = t.a * maxX + t.c * maxY + t.e,
      c3y = t.b * maxX + t.d * maxY + t.f;
  if (c3x < lo0) lo0 = c3x;
  if (c3x > hi0) hi0 = c3x;
  if (c3y < lo1) lo1 = c3y;
  if (c3y > hi1) hi1 = c3y;

  out[0] = lo0;
  out[1] = lo1;
  out[2] = hi0;
  out[3] = hi1;
}

/// A label some later instance reaches, and the instances that reach it.
///
/// [instances] is a **subsequence** of the main buffer in the main buffer's
/// order -- `kFloatsPerInstance * instanceCount` floats, copied record by
/// record. Draw order is emission order (CLAUDE.md), and a patch is drawn
/// from this alone, so its order is the main buffer's or the patch draws a
/// different picture from the reference.
class TextPatch {
  const TextPatch(
      {required this.textIndex,
      required this.instances,
      required this.instanceCount});

  final int textIndex;
  final Float32List instances;
  final int instanceCount;
}

/// Classifies every label in [texts] against every instance written after
/// it, in collection space -- the spec's "conservative, box on box" test.
///
/// For each label, instances `[instanceIndex, instanceCount)` are tested:
/// the instance's own points (per kind, Ruling E4), expanded by the kind's
/// reach (Ruling E5) at the band's **lower** scale bound, meet the label's
/// box or they do not. A label at least one instance meets is a [TextPatch]
/// whose sub-buffer is exactly those instances, in order.
///
/// **A candidate test, not an ink test.** A stroke through the whitespace
/// between two glyphs, or a dashed instance whose gap crosses the box, is a
/// candidate although no pixel of it covers label ink. Over-inclusion is
/// correct -- `TextCompositor` makes an unneeded patch a no-op -- and its
/// cost is what criterion 11 measures.
///
/// Cost: `labels x later instances` box tests in `double`, at rebuild.
/// Reported by the harness against criterion 7's budget (Task 7).
///
/// **The oracle.** `classifyTextPatches` is the grid; this is Plan E's loop,
/// kept so `classify_grid_test.dart` can prove the two return the same list
/// byte for byte.
@visibleForTesting
List<TextPatch> classifyTextPatchesBruteForce(
  Float32List data,
  int instanceCount,
  List<ResidentTextRecord> texts, {
  required double devicePixelRatio,
  double bandLowerScale = kBandLowerScale,
}) {
  // Collection units per device pixel, at the band's floor -- the LARGEST
  // a device-pixel reach is anywhere inside the band.
  final unitsPerDevicePixel = 1.0 / (devicePixelRatio * bandLowerScale);
  final patches = <TextPatch>[];
  final hits = <int>[];
  for (var ti = 0; ti < texts.length; ti++) {
    final t = texts[ti];
    hits.clear();
    for (var i = t.instanceIndex; i < instanceCount; i++) {
      if (_reaches(data, i, t, unitsPerDevicePixel)) hits.add(i);
    }
    if (hits.isEmpty) continue;
    final sub = Float32List(hits.length * kFloatsPerInstance);
    for (var k = 0; k < hits.length; k++) {
      sub.setRange(k * kFloatsPerInstance, (k + 1) * kFloatsPerInstance, data,
          hits[k] * kFloatsPerInstance);
    }
    patches.add(
        TextPatch(textIndex: ti, instances: sub, instanceCount: hits.length));
  }
  return patches;
}

/// Classifies every label in [texts] against every instance written after
/// it, in collection space -- the spec's "conservative, box on box" test.
///
/// For each label, instances `[instanceIndex, instanceCount)` are tested:
/// the instance's own points (per kind, Ruling E4), expanded by the kind's
/// reach (Ruling E5) at the band's **lower** scale bound, meet the label's
/// box or they do not. A label at least one instance meets is a [TextPatch]
/// whose sub-buffer is exactly those instances, in order.
///
/// **A candidate test, not an ink test.** A stroke through the whitespace
/// between two glyphs, or a dashed instance whose gap crosses the box, is a
/// candidate although no pixel of it covers label ink. Over-inclusion is
/// correct -- `TextCompositor` makes an unneeded patch a no-op -- and its
/// cost is what criterion 11 measures.
///
/// Cost: `labels x later instances` box tests in `double`, at rebuild.
/// Reported by the harness against criterion 7's budget (Task 7).
///
/// **A uniform grid over the labels' union** (Ruling F7). Cell size is the
/// largest label box; an instance's reach-expanded box is binned into every
/// cell it touches, or into the overflow list past [kClassifyOverflowCells];
/// a label tests only the instances in the cells its box touches,
/// deduplicated by a stamp array, plus the overflow list. Hit indices are
/// **sorted** so the sub-buffer stays a subsequence of the main buffer in
/// the main buffer's order -- indices, never the buffer.
List<TextPatch> classifyTextPatches(
  Float32List data,
  int instanceCount,
  List<ResidentTextRecord> texts, {
  required double devicePixelRatio,
  double bandLowerScale = kBandLowerScale,
  ClassifyStats? stats,
}) {
  if (texts.isEmpty) return const <TextPatch>[];
  final unitsPerDevicePixel = 1.0 / (devicePixelRatio * bandLowerScale);

  // The labels' union, and the largest label box: the cell.
  var uMinX = double.infinity, uMinY = double.infinity;
  var uMaxX = double.negativeInfinity, uMaxY = double.negativeInfinity;
  var cell = 0.0;
  for (final t in texts) {
    if (t.boxMinX < uMinX) uMinX = t.boxMinX;
    if (t.boxMinY < uMinY) uMinY = t.boxMinY;
    if (t.boxMaxX > uMaxX) uMaxX = t.boxMaxX;
    if (t.boxMaxY > uMaxY) uMaxY = t.boxMaxY;
    final w = t.boxMaxX - t.boxMinX, h = t.boxMaxY - t.boxMinY;
    if (w > cell) cell = w;
    if (h > cell) cell = h;
  }
  if (!(cell > 0)) cell = 1.0;
  // No more than 256 cells a side: a huge union over tiny labels would
  // otherwise build a grid nobody can afford at rebuild.
  final cellW = math.max(cell, (uMaxX - uMinX) / 256);
  final cellH = math.max(cell, (uMaxY - uMinY) / 256);
  final nx = math.max(1, ((uMaxX - uMinX) / cellW).ceil());
  final ny = math.max(1, ((uMaxY - uMinY) / cellH).ceil());
  if (stats != null) {
    stats.cellsX = nx;
    stats.cellsY = ny;
  }
  int cellX(double x) => ((x - uMinX) / cellW).floor().clamp(0, nx - 1);
  int cellY(double y) => ((y - uMinY) / cellH).floor().clamp(0, ny - 1);

  final buckets = List<List<int>>.generate(nx * ny, (_) => <int>[]);
  final overflow = <int>[];
  final box = Float64List(4);
  for (var i = 0; i < instanceCount; i++) {
    _expandedBox(data, i, unitsPerDevicePixel, box);
    if (box[2] < uMinX || box[0] > uMaxX || box[3] < uMinY || box[1] > uMaxY) {
      if (stats != null) stats.skipped++;
      continue;
    }
    final cx0 = cellX(box[0]), cx1 = cellX(box[2]);
    final cy0 = cellY(box[1]), cy1 = cellY(box[3]);
    if ((cx1 - cx0 + 1) * (cy1 - cy0 + 1) > kClassifyOverflowCells) {
      overflow.add(i);
      if (stats != null) stats.overflow++;
      continue;
    }
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        buckets[cy * nx + cx].add(i);
      }
    }
    if (stats != null) stats.binned++;
  }

  // Stamp: the 1-based index of the label that last saw instance i. Zero is
  // "never", so no fill is needed.
  final stamp = Int32List(instanceCount);
  final patches = <TextPatch>[];
  final hits = <int>[];
  for (var ti = 0; ti < texts.length; ti++) {
    final t = texts[ti];
    final mark = ti + 1;
    hits.clear();
    final cx0 = cellX(t.boxMinX), cx1 = cellX(t.boxMaxX);
    final cy0 = cellY(t.boxMinY), cy1 = cellY(t.boxMaxY);
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        for (final i in buckets[cy * nx + cx]) {
          if (i < t.instanceIndex || stamp[i] == mark) continue;
          stamp[i] = mark;
          if (stats != null) stats.candidatesTested++;
          if (_reaches(data, i, t, unitsPerDevicePixel)) hits.add(i);
        }
      }
    }
    for (final i in overflow) {
      if (i < t.instanceIndex) continue;
      if (stats != null) stats.candidatesTested++;
      if (_reaches(data, i, t, unitsPerDevicePixel)) hits.add(i);
    }
    if (hits.isEmpty) continue;
    // Indices, not the buffer: main-buffer order is the draw order.
    hits.sort();
    final sub = Float32List(hits.length * kFloatsPerInstance);
    for (var k = 0; k < hits.length; k++) {
      sub.setRange(k * kFloatsPerInstance, (k + 1) * kFloatsPerInstance, data,
          hits[k] * kFloatsPerInstance);
    }
    patches.add(
        TextPatch(textIndex: ti, instances: sub, instanceCount: hits.length));
  }
  return patches;
}

/// Instance [i]'s reach-expanded box into [out] as `minX, minY, maxX, maxY`
/// -- the same points-per-kind and reach-per-kind as [_reaches] (Rulings
/// E4, E5), written out rather than shared so [_reaches] stays Plan E's
/// oracle word for word; `classify_grid_test.dart` proves they agree.
void _expandedBox(
    Float32List d, int i, double unitsPerDevicePixel, Float64List out) {
  final o = i * kFloatsPerInstance;
  final kind = d[o + InstanceFieldOffset.kind];
  final half = d[o + InstanceFieldOffset.halfWidth];
  final int points;
  final double reachDevice;
  if (kind < 0.5) {
    points = 2;
    reachDevice = half;
  } else if (kind < 1.5) {
    points = 3;
    reachDevice = half * kMiterLimit;
  } else if (kind < 2.5) {
    points = 1;
    reachDevice = half;
  } else {
    points = 3;
    reachDevice = 0;
  }
  final reach = reachDevice * unitsPerDevicePixel;
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (var p = 0; p < points; p++) {
    final x = d[o + InstanceFieldOffset.x0 + p * 2];
    final y = d[o + InstanceFieldOffset.y0 + p * 2];
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  out[0] = minX - reach;
  out[1] = minY - reach;
  out[2] = maxX + reach;
  out[3] = maxY + reach;
}

/// Whether instance [i]'s reach-expanded box meets [t]'s box.
///
/// Points per kind (Ruling E4): a stroke's two, a join's three, a point's
/// ONE -- `writePoint` zeroes the other slots and reading them would pull
/// every point's box to the origin -- a fill's three. Reach per kind
/// (Ruling E5): half-width for a stroke and a point, `halfWidth *
/// kMiterLimit` for a join, nothing for a fill. The kind dispatch is the
/// shader's own chain of `<` comparisons.
///
/// If the dispatch or the reach here changes, change [_expandedBox] too --
/// it must never bound less than this function does.
bool _reaches(
    Float32List d, int i, ResidentTextRecord t, double unitsPerDevicePixel) {
  final o = i * kFloatsPerInstance;
  final kind = d[o + InstanceFieldOffset.kind];
  final half = d[o + InstanceFieldOffset.halfWidth];
  final int points;
  final double reachDevice;
  if (kind < 0.5) {
    points = 2;
    reachDevice = half;
  } else if (kind < 1.5) {
    points = 3;
    reachDevice = half * kMiterLimit;
  } else if (kind < 2.5) {
    points = 1;
    reachDevice = half;
  } else {
    points = 3;
    reachDevice = 0;
  }
  final reach = reachDevice * unitsPerDevicePixel;
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (var p = 0; p < points; p++) {
    final x = d[o + InstanceFieldOffset.x0 + p * 2];
    final y = d[o + InstanceFieldOffset.y0 + p * 2];
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  return minX - reach <= t.boxMaxX &&
      maxX + reach >= t.boxMinX &&
      minY - reach <= t.boxMaxY &&
      maxY + reach >= t.boxMinY;
}

/// Where a patch draws on screen this frame: device pixels, on the viewport.
///
/// **Mutable, and pooled by `GpuDrawBackend`** (Ruling F10, Plan E's RF-1):
/// one instance per patch for the backend's life, written in place by
/// [patchRegionFor]'s `out` each frame. Rebuild-time callers and tests pass
/// no `out` and get a fresh one.
class PatchRegion {
  PatchRegion(this.x, this.y, this.width, this.height);
  int x, y, width, height;
}

/// The label's box under the live camera, intersected with the viewport,
/// rounded outward and clamped to the patch target's size (Ruling E8).
///
/// Returns null when the label is entirely off screen -- no pass, no
/// composite. Never returns a negative origin: `flutter_gpu`'s `Viewport`
/// and `Scissor` throw on one, and the pass is anchored at the target's own
/// origin anyway; this region's `x, y` are for the compositor's `dst`.
///
/// The four corners are [boundTransformedBox]'s (Ruling P2) -- one bound
/// loop, not a second copy of it. The caller passes a reused scratch on the
/// frame path; a null scratch allocates one -- test callers.
PatchRegion? patchRegionFor(ResidentTextRecord t, Transform2 collectionToDevice,
    int widthPx, int heightPx,
    {required int maxWidth,
    required int maxHeight,
    Float64List? scratch,
    PatchRegion? out}) {
  final bound = scratch ?? Float64List(4);
  boundTransformedBox(
      t.boxMinX, t.boxMinY, t.boxMaxX, t.boxMaxY, collectionToDevice, bound);
  final x0 = bound[0].floor().clamp(0, widthPx);
  final y0 = bound[1].floor().clamp(0, heightPx);
  final x1 = bound[2].ceil().clamp(0, widthPx);
  final y1 = bound[3].ceil().clamp(0, heightPx);
  if (x1 <= x0 || y1 <= y0) return null;
  final w = (x1 - x0).clamp(0, maxWidth);
  final h = (y1 - y0).clamp(0, maxHeight);
  if (out == null) return PatchRegion(x0, y0, w, h);
  out
    ..x = x0
    ..y = y0
    ..width = w
    ..height = h;
  return out;
}

/// The patch target's size: the label's box at the band's CEILING, in
/// device pixels, rounded up and clamped to the viewport -- the largest
/// region [patchRegionFor] can return inside the band, so a zoom inside it
/// resizes the region and never the texture. Never zero in either
/// dimension: a zero-sized texture is a per-backend question this plan does
/// not ask (the same rule `ResidentGeometry._upload` applies to an empty
/// instance buffer).
///
/// **A rotated box under a rotating camera:** this sizes by the collection
/// box's width and height, but under a rotated live camera the device
/// region is the rotated box's bound and can be up to sqrt(2) larger in
/// each dimension. `CameraController` in this codebase pans and zooms and
/// does not rotate; if that changes, [patchRegionFor]'s clamp-to-target
/// keeps the pass legal (the drawn region shrinks) and the harness's
/// `patchClipped` counter (Task 6) reports it.
(int, int) patchTargetSizeFor(ResidentTextRecord t, double devicePixelRatio,
    {double bandUpperScale = kBandUpperScale,
    required int maxWidth,
    required int maxHeight}) {
  final k = devicePixelRatio * bandUpperScale;
  final w = ((t.boxMaxX - t.boxMinX) * k).ceil().clamp(1, maxWidth);
  final h = ((t.boxMaxY - t.boxMinY) * k).ceil().clamp(1, maxHeight);
  return (w, h);
}
