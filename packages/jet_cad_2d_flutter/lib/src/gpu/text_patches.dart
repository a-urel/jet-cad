import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';

/// **Provisional, and Plan F's to move.** The spec leaves the watermark band
/// un-committed as a number (open question 3); Plan E needs a floor to expand
/// an instance's reach at and a ceiling to size a patch target at, and takes
/// these two until Plan F measures the band. Every function in this file
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
/// [out] is caller-owned and reused -- because one caller is on the
/// rebuild walk and another is on the frame path.
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
