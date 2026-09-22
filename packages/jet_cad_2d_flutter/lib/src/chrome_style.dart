import 'dart:ui' show Color;

/// Thickness of each ruler bar and the corner box, logical pixels.
const double kRulerThickness = 24.0;
const double kMajorTickPixels = 12.0;
const double kMinorTickPixels = 6.0;

/// Below this on-screen sheet size the page-break tiling is not drawn: the
/// bound at extreme zoom-out (spec D8).
const double kBreaksMinSheetPixels = 16.0;

const Color kSheetEdgeColor = Color(0xFF9E9E9E);
const Color kMajorGridColor = Color(0x33000000);
const Color kMinorGridColor = Color(0x14000000);
const Color kPageBreakColor = Color(0xFF3366CC);
const Color kRulerBackground = Color(0xFFF2F2F2);
const Color kRulerInk = Color(0xFF444444);
const Color kRulerPointer = Color(0xFFE53935);
const double kRulerLabelSize = 10.0;
