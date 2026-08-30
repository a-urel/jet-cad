// Hard-edged, and it stays that way for now.
//
// The gate this backend is measured by is a pixel differential against
// `VerticesDrawSink`, which has no COVERAGE-SHADER antialiasing path:
// `flush()` submits `Vertices.raw` through `drawVertices` with per-vertex
// colours and nothing computes coverage. What antialiasing it does get comes
// from MSAA -- it says so itself at `vertices_draw_sink.dart:78-79`,
// "Anti-aliasing comes from MSAA, not from a coverage shader" -- and MSAA
// applies to both arms equally, so it cancels in the differential. A coverage
// fade HERE would not: at one-to-two device-pixel stroke widths, edge pixels
// are most of the ink, so it would differ from the reference by most of a
// channel on most inked pixels and break spec criterion 1 outright.
// Antialiasing becomes possible when something other than the reference sink
// is the oracle.
//
// (An earlier version of this comment claimed the word "antialiasing" does
// not appear in `vertices_draw_sink.dart`. It does, at :78. The conclusion
// held; the evidence cited for it did not, which in this codebase is itself
// the guarded-against failure.)
//
// (An earlier version also said antialiasing was Plan B's work. It is not;
// Plan B's Ruling B3 records why.)

in vec4 v_color;
out vec4 frag_color;

void main() {
  frag_color = v_color;
}
