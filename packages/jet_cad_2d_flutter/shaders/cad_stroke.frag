// Hard-edged, and it stays that way for now.
//
// The gate this backend is measured by is a pixel differential against
// `VerticesDrawSink`, which has no antialiasing path at all -- `flush()`
// submits `Vertices.raw` through `drawVertices` with per-vertex colours, and
// the word does not appear in the file. At one-to-two device-pixel stroke
// widths, edge pixels are most of the ink, so a coverage fade here would
// differ from the reference by most of a channel on most inked pixels and
// break spec criterion 1 outright. Antialiasing becomes possible when
// something other than the reference sink is the oracle.
//
// (An earlier version of this comment said antialiasing was Plan B's. It is
// not; Plan B's Ruling B3 records why.)

in vec4 v_color;
out vec4 frag_color;

void main() {
  frag_color = v_color;
}
