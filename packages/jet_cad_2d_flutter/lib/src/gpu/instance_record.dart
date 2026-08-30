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

/// The record's field layout, as an offset in **floats** from the record's
/// start — [writeStroke] indexes by float, not byte.
///
/// **The one place this order is declared for Dart.**
/// `ResidentGeometry.kStrokeVertexLayout` (`resident_geometry.dart`) derives
/// its `offsetInBytes` values from these same constants (`* 4`), so
/// reordering a field here moves both [writeStroke] and the vertex layout
/// together instead of leaving one behind. `cad_stroke.vert`'s attribute
/// list is a third, independent copy — GLSL cannot read a Dart constant —
/// and nothing in this package catches that copy drifting from these two;
/// only a device run, or hand-verifying against `impellerc`'s reflection the
/// way `kStrokeVertexLayout`'s own doc comment records having done once,
/// would.
abstract final class StrokeFieldOffset {
  static const int kind = 0;
  static const int x0 = 1;
  static const int y0 = 2;
  static const int x1 = 3;
  static const int y1 = 4;
  static const int halfWidth = 5;
  static const int r = 6;
  static const int g = 7;
  static const int b = 8;
  static const int a = 9;
}

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
  into[o + StrokeFieldOffset.kind] = kKindStroke;
  into[o + StrokeFieldOffset.x0] = x0;
  into[o + StrokeFieldOffset.y0] = y0;
  into[o + StrokeFieldOffset.x1] = x1;
  into[o + StrokeFieldOffset.y1] = y1;
  into[o + StrokeFieldOffset.halfWidth] = halfWidth;
  into[o + StrokeFieldOffset.r] = ((argb >> 16) & 0xFF) / 255.0;
  into[o + StrokeFieldOffset.g] = ((argb >> 8) & 0xFF) / 255.0;
  into[o + StrokeFieldOffset.b] = (argb & 0xFF) / 255.0;
  into[o + StrokeFieldOffset.a] = ((argb >> 24) & 0xFF) / 255.0;
}
