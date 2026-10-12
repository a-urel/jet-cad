// The plan's colours (plan colours spec PC-1): eight fixed hues a room's
// tint and a table's fill take. The file stores a colour by its name, never
// its index, so reordering or extending the palette breaks no file; a name
// this release does not know is kept as read and drawn as no colour.
//
// No Flutter import: the room (pure Dart over `package:jet_cad_2d`) reads it.

/// A plan colour (plan colours spec PC-1): one of eight fixed hues.
///
/// [rgb] is the document's colour, `0xRRGGBB`: what white paper, the export
/// and the print show. A dark canvas shows it re-toned, as it shows every
/// colour (`darkCanvasTone`). A later release may add hues: a host's
/// exhaustive `switch` over this enum then needs a new case.
enum FloorPlanColor {
  red(0xE53935),
  orange(0xFB8C00),
  yellow(0xFDD835),
  green(0x43A047),
  teal(0x00897B),
  blue(0x1E88E5),
  purple(0x8E24AA),
  grey(0x757575);

  const FloorPlanColor(this.rgb);

  /// The hue, `0xRRGGBB`.
  final int rgb;
}

/// The palette entry named [name] (its `name`), or null for null and for a
/// name this release does not know.
FloorPlanColor? floorPlanColorNamed(String? name) {
  if (name == null) return null;
  for (final c in FloorPlanColor.values) {
    if (c.name == name) return c;
  }
  return null;
}
