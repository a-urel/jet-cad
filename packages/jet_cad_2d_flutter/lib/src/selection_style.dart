import 'dart:ui' show Color;

/// The selected outline's colour (spec D1, D9).
const Color kSelectionColor = Color(0xFF1E6FE8);

/// The hover outline's colour — the same hue, carried at 60% alpha so a
/// hovered object reads as a weaker statement than a selected one.
const Color kHoverColor = Color(0x991E6FE8);

/// The band overlay's colours (spec D1). `SelectTool` paints its own preview
/// with these; the selected/hover outline is `SelectionOverlay`'s.
const Color kWindowBandColor = Color(0xFF1E6FE8);
const Color kCrossingBandColor = Color(0xFF2E9E5B);

/// Alpha of the band's fill, out of 255. The stroke stays fully opaque.
const int kBandFillAlpha = 0x22;

/// Outline stroke widths in **screen** pixels. The overlay divides each by
/// `camera.scale` per frame, so the width on screen holds at any zoom.
const double kSelectionStrokePixels = 2.0;
const double kHoverStrokePixels = 1.5;
