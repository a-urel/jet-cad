// THROWAWAY SPIKE CODE. Branch `spike/flutter-gpu-backend`, 2026-08-29.
//
// No antialiasing: this spike prices the frame, not the picture. A real
// backend would carry a coverage varying and fade the outer edge.

in vec4 v_color;
out vec4 frag_color;

void main() {
  frag_color = v_color;
}
