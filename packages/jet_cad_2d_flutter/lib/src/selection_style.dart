import 'dart:ui' show Color;

/// The band overlay's colours (spec D1). `SelectTool` paints its own preview
/// with these; everything else selection-styled — the selected/hover outline
/// — is Task 7's.
const Color kWindowBandColor = Color(0xFF1E6FE8);
const Color kCrossingBandColor = Color(0xFF2E9E5B);

/// Alpha of the band's fill, out of 255. The stroke stays fully opaque.
const int kBandFillAlpha = 0x22;
