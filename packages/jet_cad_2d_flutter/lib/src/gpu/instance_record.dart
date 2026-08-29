import 'dart:typed_data';

/// Floats per instance record.
///
/// `[kind, x0, y0, x1, y1, halfWidth, r, g, b, a]`.
///
/// **Ten floats, and none of them packed, because of the web.** The shader
/// bundle must carry an OpenGL ES 100 stage — `flutter_scene`'s web loader
/// reads `entry.openglEs` and transpiles it to ES 300 — and ES 100 has neither
/// bitwise operators nor integer vertex attributes, so a `uint32` colour could
/// not be unpacked in the shader. 40 bytes per record against the spike's 36.
const int kFloatsPerInstance = 10;

/// The kind tag, in slot 0 of every record.
///
/// **One buffer and one draw call carry every kind**, because separate
/// pipelines are separate draw calls and three draw calls submit as "all
/// strokes, then all joins, then all fills" — not walk order.
/// `vertices_draw_sink.dart:41-57` records that defect being shipped and
/// reverted once already, partitioned by colour rather than by kind.
const double kKindStroke = 0;

/// Writes the stroke record at [index]. [argb] is `0xAARRGGBB`.
void writeStroke(
  Float32List into,
  int index, {
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required double halfWidth,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o] = kKindStroke;
  into[o + 1] = x0;
  into[o + 2] = y0;
  into[o + 3] = x1;
  into[o + 4] = y1;
  into[o + 5] = halfWidth;
  into[o + 6] = ((argb >> 16) & 0xFF) / 255.0;
  into[o + 7] = ((argb >> 8) & 0xFF) / 255.0;
  into[o + 8] = (argb & 0xFF) / 255.0;
  into[o + 9] = ((argb >> 24) & 0xFF) / 255.0;
}
