// The overlays' sizes and widths. Their colours are `PaperPalette`'s
// (`canvas_palette.dart`, dark theme spec D3): they follow the paper.

/// Alpha of the band's fill, out of 255. The stroke stays fully opaque.
const int kBandFillAlpha = 0x22;

/// Outline stroke widths in **screen** pixels. The overlay divides each by
/// `camera.scale` per frame, so the width on screen holds at any zoom.
const double kSelectionStrokePixels = 2.0;
const double kHoverStrokePixels = 1.5;

/// Grip squares (spec D6): side in screen pixels, drawn by `drawRawPoints`
/// with a square cap at this stroke width.
const double kGripPixels = 8.0;

/// The rotation grip: a disc of this diameter, [kRotationGripOffset] screen
/// pixels above the top-centre of the selection's screen box (spec D6).
const double kRotationGripPixels = 8.0;
const double kRotationGripOffset = 24.0;

/// The drag preview's and its guide line's stroke (spec D7).
const double kPreviewStrokePixels = 1.5;

/// Snap markers (spec D9).
const double kSnapMarkerPixels = 10.0;
const double kSnapMarkerStrokePixels = 1.5;
const double kGridMarkerPixels = 6.0;
