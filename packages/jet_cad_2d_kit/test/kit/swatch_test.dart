// Spec P3 (colour targets) and P5: the plan's palette is contract data a
// kit's ColourTarget stores by name. Ported from jet_cad_floor_plan's
// plan_color.dart (plan colours spec PC-1): the names and hues are what a
// file and a print show, so both are pinned.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test('W-SW1 the eight swatches, their names and hues, in palette order', () {
    // M-W-SW1: a hue changed, or two swatches swapped, goes red.
    expect([
      for (final s in PlanSwatch.values) (s.name, s.rgb)
    ], const [
      ('red', 0xE53935),
      ('orange', 0xFB8C00),
      ('yellow', 0xFDD835),
      ('green', 0x43A047),
      ('teal', 0x00897B),
      ('blue', 0x1E88E5),
      ('purple', 0x8E24AA),
      ('grey', 0x757575),
    ]);
  });

  test('W-SW2 a swatch is found by its name, never by its index', () {
    for (final s in PlanSwatch.values) {
      expect(planSwatchNamed(s.name), s, reason: s.name);
    }
    // M-W-SW2: `planSwatchNamed` comparing case-insensitively finds 'Teal'.
    for (final name in [null, '', 'Teal', 'magenta', '4', 'teal ']) {
      expect(planSwatchNamed(name), isNull, reason: '$name');
    }
  });
}
