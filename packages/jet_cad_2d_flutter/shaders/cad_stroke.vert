// Expands one world-space segment per instance into a screen-space quad.
//
// **Authored for OpenGL ES 100.** `impellerc` emits the `openglEs` stage the
// web loader reads and transpiles to ES 300, and ES 100 has no bitwise
// operators and no integer attributes -- hence a float kind tag and a vec4
// colour rather than a packed uint32.

uniform FrameInfo {
  mat4 mvp;            // collection space -> normalized device coordinates
  vec2 half_viewport;  // device pixels / 2
} frame_info;

// Per vertex: two triangles of a unit quad, six corners.
// x picks the endpoint (0 = p0, 1 = p1), y picks the side (-1 or +1).
in vec2 corner;

// Per instance.
in float kind;
in vec2 p0;
in vec2 p1;
in float half_width;  // device pixels
in vec4 color;

out vec4 v_color;

void main() {
  vec4 clip0 = frame_info.mvp * vec4(p0, 0.0, 1.0);
  vec4 clip1 = frame_info.mvp * vec4(p1, 0.0, 1.0);

  vec2 px0 = clip0.xy * frame_info.half_viewport;
  vec2 px1 = clip1.xy * frame_info.half_viewport;

  vec2 delta = px1 - px0;
  float length_px = length(delta);
  // Reachable, not merely defensive. The collector's guard is an exact `==`
  // on `double` (geometry_collector.dart:64), taken before the values are
  // narrowed to float32 by the Float32List -- two distinct doubles can
  // collapse to the same float and slip past it. Separately, two distinct
  // floats can still project to the same device pixel at extreme zoom-out,
  // giving `length_px == 0.0` here regardless of what the collector rejected.
  // A NaN here is a whole frame of nothing, so the fallback direction stays.
  vec2 direction = length_px > 0.0 ? delta / length_px : vec2(1.0, 0.0);
  vec2 normal = vec2(-direction.y, direction.x);

  vec2 px;
  if (kind < 0.5) {
    // kKindStroke (instance_record.dart) -- the only kind the collector
    // emits today.
    px = mix(px0, px1, corner.x) + normal * half_width * corner.y;
  } else {
    // Unreachable while kKindStroke is the only tag the collector writes.
    // `px = px0` collapses all six vertices of the quad to one point, a
    // deliberate draw-nothing fallback -- not an unfinished stub -- for any
    // future kind that reaches here before its own branch is written.
    //
    // `kind` is read here deliberately: this build's `impellerc` fails
    // reflection ("Could not complete reflection on generated shader") when
    // a declared attribute is never consumed by something the optimizer
    // cannot fold away -- confirmed by bisecting a minimal repro against
    // this exact impellerc binary, independent of attribute count or the
    // record layout. This dispatch is also where a future join/cap/dash
    // kind hangs its own expansion.
    px = px0;
  }

  gl_Position = vec4(px / frame_info.half_viewport, 0.0, 1.0);
  v_color = color;
}
