import 'dart:typed_data';

/// Floats per instance record.
///
/// `[kind, halfWidth, x0, y0, x1, y1, x2, y2, r, g, b, a,
///   dashPeriod, dashPhase, dashFracStart, dashFracEnd]`.
///
/// **Sixteen floats, none of them packed, because of the web.** ES 100 has
/// neither bitwise operators nor integer vertex attributes, so a `uint32`
/// colour could not be unpacked in the shader. 64 bytes per record.
///
/// **Ten became twelve in Plan B**, because a join carries a vertex and both
/// its neighbours where a stroke carries two endpoints. The third point is
/// stored rather than a pair of unit directions: a unit direction is only
/// unit-length after a *conformal* transform, and nothing promises the camera
/// is one. The reference takes its directions in device space, after the
/// residual (`vertices_draw_sink.dart`, `_runTo`), so storing points and
/// normalising in the shader after the mvp puts both arms in the same space
/// by construction instead of by coincidence.
///
/// **Twelve became sixteen in Plan C**, and `kind` moved next to `halfWidth`
/// in the same change. The four new slots carry the dash: the period in
/// collection units, the phase at this instance's start, and the drawn
/// pattern element's own extent as a fraction of the cycle. The move is
/// Ruling C6: the shader reads `kind` and `half_width` as one `vec2`
/// attribute, because `gl_MaxVertexAttribs` is guaranteed to be no more than
/// 8 under GLSL ES 100 and the eighth slot is now the `dash` quad.
///
/// **`dashPeriod` is signed and the sign is data.** Zero means solid.
/// Negative marks the one instance per primitive that draws solid when the
/// live period falls under `kDashCollapsePx` -- see `cad_stroke.vert`'s
/// collapse branch, and Plan C's record section for why the alternative
/// (every instance of a collapsed primitive drawing solid) is visibly wrong
/// rather than merely wasteful.
const int kFloatsPerInstance = 16;

/// The kind tag, in slot 0 of every record.
///
/// **One buffer and one draw call carry every kind**, because separate
/// pipelines are separate draw calls and three draw calls submit as "all
/// strokes, then all joins, then all fills" — not walk order.
/// `vertices_draw_sink.dart:41-57` records that defect being shipped and
/// reverted once already, partitioned by colour rather than by kind.
///
/// **The values are 0, 1, 2 and the order is load-bearing**, not merely
/// distinct: `cad_stroke.vert` dispatches with `kind < 0.5` then
/// `kind < 1.5`, because ES 100 has no integer attributes and no `switch` on
/// one. Renumbering these without editing that shader silently draws every
/// join as a stroke.
const double kKindStroke = 0;

/// A corner between two segments. `(x0, y0)` is the vertex, `(x1, y1)` the
/// previous point and `(x2, y2)` the next one; the shader builds the bevel
/// and, where the turn is shallow enough, the miter tip.
const double kKindJoin = 1;

/// A `point()` op: a square of the stroke's own width centred on
/// `(x0, y0)`. `(x1, y1)` and `(x2, y2)` are unused.
///
/// **Not a zero-length capped stroke, and not a tiny horizontal segment
/// either.** The reference draws it as a horizontal segment from `px - half`
/// to `px + half` — but it computes that offset in **device** space, where
/// its residual has already been applied. This record holds *collection*
/// space, and the shader expands `halfWidth` in device pixels after the mvp,
/// so a `± half` baked into `x0`/`x1` here would scale with the camera on one
/// axis while the other stayed fixed: the square would shear under zoom. Its
/// own kind is what keeps both axes in the same space.
const double kKindPoint = 2;

/// The record's field layout, as an offset in **floats** from the record's
/// start — the writers below index by float, not byte.
///
/// **The one place this order is declared for Dart.**
/// `ResidentGeometry.kInstanceVertexLayout` derives its `offsetInBytes`
/// values from these same constants (`* 4`), so reordering a field here moves
/// the writers and the vertex layout together instead of leaving one behind.
/// `cad_stroke.vert`'s attribute list is a third, independent copy — GLSL
/// cannot read a Dart constant — and `test/support/instance_expander.dart` is
/// a fourth. The expander is the one that is *gated*: it reads these same
/// constants, and `test/gpu/instance_expander_test.dart` pins the
/// expander's own arithmetic today, so a drift between this file and the
/// expander goes red in `flutter test`. `test/gpu/resident_pixel_differential_test.dart`
/// (Task 9) is the one that compares the expander's output against the
/// reference sink pixel for pixel. A drift between either and the GLSL
/// still needs a device run or a hand-check against `impellerc`'s
/// reflection.
abstract final class InstanceFieldOffset {
  static const int kind = 0;
  static const int halfWidth = 1;
  static const int x0 = 2;
  static const int y0 = 3;
  static const int x1 = 4;
  static const int y1 = 5;
  static const int x2 = 6;
  static const int y2 = 7;
  static const int r = 8;
  static const int g = 9;
  static const int b = 10;
  static const int a = 11;
  static const int dashPeriod = 12;
  static const int dashPhase = 13;
  static const int dashFracStart = 14;
  static const int dashFracEnd = 15;
}

/// Writes the four colour slots at record base [o]. [argb] is `0xAARRGGBB`.
void _writeColor(Float32List into, int o, int argb) {
  into[o + InstanceFieldOffset.r] = ((argb >> 16) & 0xFF) / 255.0;
  into[o + InstanceFieldOffset.g] = ((argb >> 8) & 0xFF) / 255.0;
  into[o + InstanceFieldOffset.b] = (argb & 0xFF) / 255.0;
  into[o + InstanceFieldOffset.a] = ((argb >> 24) & 0xFF) / 255.0;
}

/// Writes the four dash slots at record base [o].
///
/// **Every writer calls this, `writePoint` included.** `writePoint` takes no
/// dash arguments — a `point()` is never dashed, since `DraftPainter`
/// returns before it ever looks up a linetype — but it still calls this with
/// every argument at its default of zero, rather than relying on a fresh
/// `Float32List`'s own zero-initialisation. A record reused across frames (or
/// sliced from a larger buffer that once held a dashed instance at the same
/// index) is not guaranteed to already be zero there; only an explicit write
/// is.
void _writeDash(Float32List into, int o, double period, double phase,
    double fracStart, double fracEnd) {
  into[o + InstanceFieldOffset.dashPeriod] = period;
  into[o + InstanceFieldOffset.dashPhase] = phase;
  into[o + InstanceFieldOffset.dashFracStart] = fracStart;
  into[o + InstanceFieldOffset.dashFracEnd] = fracEnd;
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

  /// Collection units. 0 is solid; a negative value marks the collapse
  /// representative and its magnitude is the period.
  double dashPeriod = 0,
  double dashPhase = 0,
  double dashFracStart = 0,
  double dashFracEnd = 0,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindStroke;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  into[o + InstanceFieldOffset.x0] = x0;
  into[o + InstanceFieldOffset.y0] = y0;
  into[o + InstanceFieldOffset.x1] = x1;
  into[o + InstanceFieldOffset.y1] = y1;
  into[o + InstanceFieldOffset.x2] = 0;
  into[o + InstanceFieldOffset.y2] = 0;
  _writeColor(into, o, argb);
  _writeDash(into, o, dashPeriod, dashPhase, dashFracStart, dashFracEnd);
}

/// Writes the join record at [index].
///
/// The three points are **not interchangeable**: the shader takes the
/// incoming direction as `vertex - previous` and the outgoing as
/// `next - vertex`, and swapping the neighbours reverses the turn, which
/// puts the wedge on the inside of the corner where there is no notch to
/// fill.
void writeJoin(
  Float32List into,
  int index, {
  required double vx,
  required double vy,
  required double prevX,
  required double prevY,
  required double nextX,
  required double nextY,
  required double halfWidth,
  required int argb,

  /// Collection units. 0 is solid; a negative value marks the collapse
  /// representative and its magnitude is the period.
  double dashPeriod = 0,
  double dashPhase = 0,
  double dashFracStart = 0,
  double dashFracEnd = 0,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindJoin;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  into[o + InstanceFieldOffset.x0] = vx;
  into[o + InstanceFieldOffset.y0] = vy;
  into[o + InstanceFieldOffset.x1] = prevX;
  into[o + InstanceFieldOffset.y1] = prevY;
  into[o + InstanceFieldOffset.x2] = nextX;
  into[o + InstanceFieldOffset.y2] = nextY;
  _writeColor(into, o, argb);
  _writeDash(into, o, dashPeriod, dashPhase, dashFracStart, dashFracEnd);
}

/// Writes the point record at [index].
///
/// **Takes no dash arguments, by design.** A `point()` is never dashed —
/// `VerticesDrawSink.point` does not consult a linetype, and neither does the
/// painter's point path: `_emitScreenSpace` returns before `_patternFor` is
/// ever called. A caller therefore cannot express something the reference
/// cannot draw. The four dash slots are still written, explicitly, to zero —
/// see [_writeDash]'s own doc for why that write has to be explicit rather
/// than left to a fresh buffer's zero-initialisation.
void writePoint(
  Float32List into,
  int index, {
  required double x,
  required double y,
  required double halfWidth,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindPoint;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  into[o + InstanceFieldOffset.x0] = x;
  into[o + InstanceFieldOffset.y0] = y;
  into[o + InstanceFieldOffset.x1] = 0;
  into[o + InstanceFieldOffset.y1] = 0;
  into[o + InstanceFieldOffset.x2] = 0;
  into[o + InstanceFieldOffset.y2] = 0;
  _writeColor(into, o, argb);
  _writeDash(into, o, 0, 0, 0, 0);
}
