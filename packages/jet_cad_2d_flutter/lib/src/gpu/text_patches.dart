import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'instance_record.dart';
import 'resident_text.dart';

/// **Provisional, and Plan F's to move.** The spec leaves the watermark band
/// un-committed as a number (open question 3); Plan E needs a floor to expand
/// an instance's reach at and a ceiling to size a patch target at, and takes
/// these two until Plan F measures the band. Every classification function in
/// this file (`classifyTextPatches`, and Task 4's region and size functions)
/// takes them as parameters with these defaults, so a test can pin either
/// edge and Plan F can move them without touching a call site.
const double kBandLowerScale = 0.5;
const double kBandUpperScale = 2.0;

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
/// [out] is caller-owned and reused. Today's caller is on the rebuild walk;
/// a frame-path caller (`labelBoundsLogical`, `patchRegionFor`) arrives in
/// Task 4, where the allocation-free contract starts to matter.
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
List<TextPatch> classifyTextPatches(
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

/// Whether instance [i]'s reach-expanded box meets [t]'s box.
///
/// Points per kind (Ruling E4): a stroke's two, a join's three, a point's
/// ONE -- `writePoint` zeroes the other slots and reading them would pull
/// every point's box to the origin -- a fill's three. Reach per kind
/// (Ruling E5): half-width for a stroke and a point, `halfWidth *
/// kMiterLimit` for a join, nothing for a fill. The kind dispatch is the
/// shader's own chain of `<` comparisons.
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
