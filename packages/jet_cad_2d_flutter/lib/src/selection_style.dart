import 'dart:ui' show Color;

/// The selected outline's colour (spec D1, D9).
const Color kSelectionColor = Color(0xFF1E6FE8);

/// The hover outline's colour — the same hue, carried at 60% alpha so a
/// hovered object reads as a weaker statement than a selected one.
const Color kHoverColor = Color(0x991E6FE8);

/// The band overlay's colours (spec D1). `SelectTool` paints its own preview
/// with these; the selected/hover outline is `SelectionOverlayPainter`'s.
const Color kWindowBandColor = Color(0xFF1E6FE8);
const Color kCrossingBandColor = Color(0xFF2E9E5B);

/// Alpha of the band's fill, out of 255. The stroke stays fully opaque.
const int kBandFillAlpha = 0x22;

/// Outline stroke widths in **screen** pixels. The overlay divides each by
/// `camera.scale` per frame, so the width on screen holds at any zoom.
const double kSelectionStrokePixels = 2.0;
const double kHoverStrokePixels = 1.5;

/// Grip squares (spec D6): side in screen pixels, drawn by `drawRawPoints`
/// with a square cap at this stroke width.
const double kGripPixels = 8.0;

/// Stretch and radius grips.
const Color kGripColor = Color(0xFF1E6FE8);

/// Move (centre) grips.
const Color kGripMoveColor = Color(0xFF7A3FD1);

/// The hovered grip, and the grabbed one during a drag.
const Color kGripHotColor = Color(0xFFE8541E);

/// The rotation grip: a disc of this diameter, [kRotationGripOffset] screen
/// pixels above the top-centre of the selection's screen box (spec D6).
const double kRotationGripPixels = 8.0;
const double kRotationGripOffset = 24.0;

/// The drag preview and its guide line (spec D7).
const Color kPreviewColor = Color(0xFFE8A11E);
const double kPreviewStrokePixels = 1.5;

/// Snap markers (spec D9).
const Color kSnapMarkerColor = Color(0xFF2E9E5B);
const double kSnapMarkerPixels = 10.0;
const double kSnapMarkerStrokePixels = 1.5;
const double kGridMarkerPixels = 6.0;
