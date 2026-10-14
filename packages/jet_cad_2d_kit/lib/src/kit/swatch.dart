// The plan's palette (spec P3 "Colour", P5): eight fixed hues a kit's
// ColourTarget stores by name, never by index, so reordering or extending
// the palette breaks no file; a name this release does not know is kept as
// read and drawn as no colour. Ported from jet_cad_floor_plan's
// plan_color.dart (plan colours spec PC-1).
//
// Pure Dart: no Flutter import. A kit's parametric type (pure Dart over
// `package:jet_cad_2d`) reads it to colour what it generates.

/// A plan colour: one of eight fixed hues.
///
/// [rgb] is the document's colour, `0xRRGGBB`: what white paper, the export
/// and the print show. A dark canvas shows it re-toned, as it shows every
/// colour. A later release may add hues: an exhaustive `switch` over this
/// enum then needs a new case.
enum PlanSwatch {
  red(0xE53935),
  orange(0xFB8C00),
  yellow(0xFDD835),
  green(0x43A047),
  teal(0x00897B),
  blue(0x1E88E5),
  purple(0x8E24AA),
  grey(0x757575);

  const PlanSwatch(this.rgb);

  /// The hue, `0xRRGGBB`.
  final int rgb;
}

/// The palette entry named [name] (its `name`), or null for null and for a
/// name this release does not know.
PlanSwatch? planSwatchNamed(String? name) {
  if (name == null) return null;
  for (final s in PlanSwatch.values) {
    if (s.name == name) return s;
  }
  return null;
}
