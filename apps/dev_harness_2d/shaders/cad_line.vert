// THROWAWAY SPIKE CODE. Branch `spike/flutter-gpu-backend`, 2026-08-29.
//
// Expands one world-space segment per *instance* into a screen-space quad.
//
// Two things are being priced here, and both live in this file. The camera is
// a uniform, so a pan or a zoom rewrites the eighteen floats below and touches
// no vertex. And the lineweight is a device-pixel quantity applied *after*
// projection, which is what lets a stroke hold its width under zoom without
// the CPU re-tessellating it -- the cost the painter walk pays every frame.

uniform FrameInfo {
  mat4 mvp;            // world -> normalized device coordinates
  vec2 half_viewport;  // device pixels / 2, to move between NDC and pixels
} frame_info;

// Per vertex: the unit quad, four corners, a triangle strip.
// x picks the endpoint (0 = p0, 1 = p1), y picks the side (-1 or +1).
in vec2 corner;

// Per instance: the segment.
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
  // A degenerate segment carries no direction. Any direction draws a dot of
  // the right width rather than a NaN.
  vec2 direction = length_px > 0.0 ? delta / length_px : vec2(1.0, 0.0);
  vec2 normal = vec2(-direction.y, direction.x);

  vec2 px = mix(px0, px1, corner.x) + normal * half_width * corner.y;

  gl_Position = vec4(px / frame_info.half_viewport, 0.0, 1.0);
  v_color = color;
}
