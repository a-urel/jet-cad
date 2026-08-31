// Expands one instance into a screen-space primitive, branching on its kind.
//
// **Authored for OpenGL ES 100.** `impellerc` emits the `openglEs` stage the
// web loader reads and transpiles to ES 300, and ES 100 has no bitwise
// operators and no integer attributes -- hence a float kind tag and a vec4
// colour rather than a packed uint32, and a `<` dispatch rather than a
// switch.
//
// **Everything scale-dependent happens HERE, at the live camera.** The
// instance buffer holds a centreline, a corner or a centre in collection
// space plus a half-width in device pixels; expanding any of it at collection
// time would thicken the drawing with the camera. That is why joins are a
// kind and not collector geometry: a miter is a function of the live
// half-width.
//
// **`test/support/instance_expander.dart` is this file, in Dart.** It is what
// the suite can actually run. Any edit here that is not mirrored there is a
// divergence no test in this package can see -- change them together.
//
// **Dashes are decided here and tested one line away.** The vertex stage
// turns the instance's `dash` quad into a single varying, `t`, which is the
// pattern-space coordinate at this vertex; the fragment stage keeps the
// fragment when `fract(t)` lands inside the element's own extent. `t` is
// measured in COLLECTION units, and the live camera does not appear in it at
// all: the reference's on-screen period is proportional to the camera scale
// (`draft_painter.dart`'s `_dashScale` folds in `toScreen.scaleMagnitude`)
// and so is the distance along the primitive, so the ratio is scale-free.
// The camera reaches this file for one purpose only -- deciding whether the
// pattern has collapsed to solid.

uniform FrameInfo {
  mat4 mvp;            // collection space -> normalized device coordinates
  vec2 half_viewport;  // device pixels / 2
  float dash_scale;    // live LOGICAL pixels per collection unit
} frame_info;

// Per vertex: two triangles, six corners.
// `corner.x` picks the endpoint (0 = p0, 1 = p1), `corner.y` picks the side
// (-1 or +1). `join_weight` selects one of (V, A, B, M) for the join branch,
// which needs six distinct roles where `corner` offers only four.
in vec2 corner;
in vec4 join_weight;

// Per instance. `kind` and `half_width` share one attribute because GLSL
// ES 100 guarantees only eight vertex attributes and `dash` takes the eighth.
in vec2 kind_half;   // (kind, half width in device pixels)
in vec2 p0;
in vec2 p1;
in vec2 p2;
in vec4 color;
in vec4 dash;        // (period, phase, fracStart, fracEnd), collection units

out vec4 v_color;

// (t, fracStart, fracEnd). A NEGATIVE fracStart means "solid" and the
// fragment stage skips the test entirely -- one sentinel rather than a
// second varying.
out vec3 v_dash;

const float kMinMiterCosine = -0.875;

// `kDashCollapsePx`, restated because GLSL cannot read a Dart
// constant; `instance_expander.dart` asserts the two agree.
const float kDashCollapsePx = 3.0;

vec2 to_pixels(vec2 p) {
  vec4 clip = frame_info.mvp * vec4(p, 0.0, 1.0);
  return clip.xy * frame_info.half_viewport;
}

void main() {
  float kind = kind_half.x;
  float half_width = kind_half.y;
  vec2 px;

  // Distance from the primitive's start to this vertex, in COLLECTION units.
  float along = 0.0;

  if (kind < 0.5) {
    // kKindStroke: two triangles around a centreline.
    vec2 a = to_pixels(p0);
    vec2 b = to_pixels(p1);
    vec2 delta = b - a;
    float len = length(delta);
    // Reachable, not merely defensive. The collector's guard runs on
    // `double` before the values are narrowed to float32, and two distinct
    // doubles can collapse to one float; separately, two distinct floats can
    // still project to the same device pixel at extreme zoom-out. A NaN here
    // is a whole frame of nothing.
    vec2 dir = len > 0.0 ? delta / len : vec2(1.0, 0.0);
    vec2 normal = vec2(-dir.y, dir.x);
    px = mix(a, b, corner.x) + normal * half_width * corner.y;
    // Collection units, taken from the attributes rather than from `a` and
    // `b`: `to_pixels` has already applied the live camera to those, and the
    // camera must not appear in `t`.
    along = corner.x * length(p1 - p0);

  } else if (kind < 1.5) {
    // kKindJoin: the notch at a corner, as the bevel (V, A, B) plus the
    // miter tip (A, M, B). Exactly `VerticesDrawSink._emitJoin`, in device
    // pixels, which is the space that function works in too.
    vec2 v = to_pixels(p0);
    vec2 prev = to_pixels(p1);
    vec2 next = to_pixels(p2);

    vec2 in_delta = v - prev;
    vec2 out_delta = next - v;
    float in_len = length(in_delta);
    float out_len = length(out_delta);
    vec2 d0 = in_len > 0.0 ? in_delta / in_len : vec2(1.0, 0.0);
    vec2 d1 = out_len > 0.0 ? out_delta / out_len : d0;

    float cross_z = d0.x * d1.y - d0.y * d1.x;

    if (cross_z == 0.0 || in_len == 0.0 || out_len == 0.0) {
      // Collinear: either straight through, where the quads already meet, or
      // a reversal, where both the miter and the bevel are degenerate. The
      // reference emits nothing; collapsing every corner onto the vertex
      // gives two zero-area triangles, which is the same picture.
      px = v;
    } else {
      // The outer side of the turn is the one away from it: a left turn
      // (cross > 0) opens a notch on the right.
      float s = cross_z > 0.0 ? -half_width : half_width;
      vec2 n0 = vec2(-d0.y, d0.x) * s;
      vec2 n1 = vec2(-d1.y, d1.x) * s;
      vec2 a = v + n0;
      vec2 b = v + n1;

      // Bevel by default: with M at A the tip triangle (A, M, B) has zero
      // area and disappears, which is what the reference's early return
      // achieves by not emitting it.
      vec2 m = a;
      if (dot(d0, d1) >= kMinMiterCosine) {
        vec2 sum = n0 + n1;
        float sum_len = length(sum);
        if (sum_len > 0.0 && half_width > 0.0) {
          vec2 mu = sum / sum_len;
          // `n0` has length `half_width`, so this is the cosine of half the
          // included angle.
          float cos_half = dot(mu, n0) / half_width;
          if (cos_half > 0.0) {
            m = v + mu * (half_width / cos_half);
          }
        }
      }

      px = join_weight.x * v + join_weight.y * a + join_weight.z * b +
           join_weight.w * m;
    }
    // `along` stays 0: every vertex of a join wedge sits at the corner, so
    // the whole wedge is tested at the phase stored for that corner.

  } else {
    // kKindPoint: a square of the stroke's width centred on p0. Both axes
    // are expanded here, in device pixels, so the dot stays square and stays
    // the same size at every zoom -- which is what the reference gets for
    // free by computing its `+/- half` in device space. A point is never
    // dashed.
    vec2 c = to_pixels(p0);
    px = c + vec2((corner.x * 2.0 - 1.0) * half_width, corner.y * half_width);
  }

  gl_Position = vec4(px / frame_info.half_viewport, 0.0, 1.0);
  v_color = color;

  // The dash decision. `dash.x` is signed: zero is solid, and a negative
  // value marks the one instance per primitive that draws solid when the
  // pattern collapses.
  v_dash = vec3(0.0, -1.0, 0.0);
  float period = abs(dash.x);
  if (period > 0.0) {
    if (period * frame_info.dash_scale < kDashCollapsePx) {
      // Collapsed. The reference stops dashing and draws the whole primitive
      // (`draft_painter.dart:629-631` takes `dashPolyline`'s false return and
      // calls `polyline` with the untouched points), so the representative
      // keeps its solid `v_dash` and every sibling collapses to a point.
      if (dash.x > 0.0) {
        gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
      }
    } else {
      v_dash = vec3((dash.y + along) / period, dash.z, dash.w);
    }
  }
}
