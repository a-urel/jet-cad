// Plan A draws hard-edged strokes. Antialiasing is Plan B's, and the pixel
// differential in Task 8 is stated against a hard-edged reference for exactly
// that reason.

in vec4 v_color;
out vec4 frag_color;

void main() {
  frag_color = v_color;
}
