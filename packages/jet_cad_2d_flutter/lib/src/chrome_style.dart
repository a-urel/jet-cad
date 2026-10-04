// The canvas chrome's sizes. Its colours are `ChromePalette`'s and
// `PaperPalette`'s (`canvas_palette.dart`, dark theme spec D2, D3).

/// Thickness of each ruler bar and the corner box, logical pixels.
const double kRulerThickness = 24.0;
const double kMajorTickPixels = 12.0;
const double kMinorTickPixels = 6.0;

/// Below this on-screen sheet size the page-break tiling is not drawn: the
/// bound at extreme zoom-out (spec D8).
const double kBreaksMinSheetPixels = 16.0;

const double kRulerLabelSize = 10.0;
