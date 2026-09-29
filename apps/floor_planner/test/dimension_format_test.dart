// Spec 11 D9: a dimension's value in the page's display unit, at the unit's
// plan precision, round-half-up with the half decided within
// `dimFormat.linear` (R-13, R-14, R-15, R-32). Every input is in
// millimetres, with its arithmetic worked by hand beside it. Ported from the
// spike's `engine_test.dart` (`Q5b`, `Q5c`).
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show DisplayUnit;

const mm = DisplayUnit.millimeters,
    cm = DisplayUnit.centimeters,
    m = DisplayUnit.meters,
    inch = DisplayUnit.inches,
    ftIn = DisplayUnit.feetInches;

/// The naive rule `roundHalfUp` replaces: convert to the precision and
/// `round()` (the spike's `naiveRound`). Only a premise: a `Q5c` row whose
/// naive answer were already right would not test the half.
int naive(double v, double quantumMm) => (v / quantumMm).round();

void main() {
  test(
      'DF1 every unit at its plan precision, half-up: cm keeps its '
      'trailing zero, fractions are reduced, only feet-inches carries marks, '
      'and a carry reaches the next foot', () {
    final diagonal = math.sqrt(3450.0 * 3450 + 950 * 950);
    // D17's premise: √(3,450² + 950²) = √12,805,000 = 3,578.407 mm.
    expect(diagonal, closeTo(3578.407, 1e-3));
    final cases = <(double, DisplayUnit, String)>[
      // --- The spike's Q5b rows. ---
      (3450, mm, '3450'),
      // 3450.5 is exact in binary and on the half: up.
      (3450.5, mm, '3451'),
      (3450.4, mm, '3450'),
      // 3450 mm = 3450 tenths of a cm: 345.0, the zero kept (R-14).
      (3450, cm, '345.0'),
      (3456, cm, '345.6'),
      // 3450 mm = 345 hundredths of a metre.
      (3450, m, '3.45'),
      // 3455 / 10 = 345.5 hundredths, on the half: 346.
      (3455, m, '3.46'),
      // 345.49 hundredths: down.
      (3454.9, m, '3.45'),
      // 1005 / 10 = 100.5 hundredths (100.49999999999999 as 1.005 × 100).
      (1005, m, '1.01'),
      // 136 3/8" = 136.375 × 25.4 = 3463.925 mm = 1091 eighths.
      (3463.925, inch, '136 3/8'),
      // 136 1/2" = 136.5 × 25.4 = 3467.1 mm = 1092 eighths: 4/8 → 1/2.
      (3467.1, inch, '136 1/2'),
      // 11'-4 1/4" = 136.25" = 136.25 × 25.4 = 3460.75 mm = 545 quarters =
      // 11 × 48 + 17: 11 feet, 17 quarters = 4 1/4".
      (3460.75, ftIn, "11'-4 1/4\""),
      // 12' = 144" = 3657.6 mm = 576 quarters = 12 × 48.
      (3657.6, ftIn, "12'-0\""),
      // 3/16" = 4.7625 mm: 1.5 eighths, the half, up to 2/8 = 1/4.
      (3 * 25.4 / 16, inch, '0 1/4'),
      // 3/8" = 9.525 mm: 1.5 quarters, the half, up to 2/4 = 1/2.
      (3 * 25.4 / 8, ftIn, "0'-0 1/2\""),
      // Whole inches print no fraction: 136" = 3454.4 mm = 1088 eighths.
      (3454.4, inch, '136'),
      // --- The carry (D9): rounding happens on the total. ---
      // 143 7/8" = 143.875 × 25.4 = 3654.425 mm = 575.5 quarters, on the
      // half: 576 = 12 × 48, so 12'-0", never 11'-12" (11' plus 11.875"
      // rounded on its own to 12").
      (3654.425, ftIn, "12'-0\""),
      // --- Zero, and the magnitude of a negative. ---
      (0, mm, '0'),
      (0, cm, '0.0'),
      (0, m, '0.00'),
      (0, inch, '0'),
      (0, ftIn, "0'-0\""),
      // −3463.925 mm: its magnitude, 1091 eighths.
      (-3463.925, inch, '136 3/8'),
      // --- D17's every-unit table (the sample plan's five values). ---
      // Width 14,000: 14000; 1400.0 cm; 1400 hundredths → 14.00;
      // 14,000 / 25.4 = 551.181" → 4,409.45 eighths → 4,409 = 551 1/8;
      // 2,204.72 quarters → 2,205 = 551.25" = 45 × 12 + 11.25 = 45'-11 1/4".
      (14000, mm, '14000'),
      (14000, cm, '1400.0'),
      (14000, m, '14.00'),
      (14000, inch, '551 1/8'),
      (14000, ftIn, "45'-11 1/4\""),
      // Depth 9,000: 9000; 900.0; 9.00; 354.331" → 2,834.65 → 2,835 eighths
      // = 354 3/8; 1,417.32 → 1,417 quarters = 354.25" = 29'-6 1/4".
      (9000, mm, '9000'),
      (9000, cm, '900.0'),
      (9000, m, '9.00'),
      (9000, inch, '354 3/8'),
      (9000, ftIn, "29'-6 1/4\""),
      // Hall 4,690: 4690; 469.0; 4.69; 184.646" → 1,477.17 eighths → 1,477
      // = 184 5/8; 738.58 → 739 quarters = 184.75" = 15'-4 3/4".
      (4690, mm, '4690'),
      (4690, cm, '469.0'),
      (4690, m, '4.69'),
      (4690, inch, '184 5/8'),
      (4690, ftIn, "15'-4 3/4\""),
      // Kitchen 4,380: 4380; 438.0; 4.38; 172.441" → 1,379.53 eighths →
      // 1,380 = 172 4/8 = 172 1/2; 689.76 → 690 quarters = 172.5" =
      // 14'-4 1/2".
      (4380, mm, '4380'),
      (4380, cm, '438.0'),
      (4380, m, '4.38'),
      (4380, inch, '172 1/2'),
      (4380, ftIn, "14'-4 1/2\""),
      // Diagonal 3,578.407: 3578; 3,578 tenths → 357.8; 357.84 hundredths →
      // 3.58; 140.882" → 1,127.06 eighths → 1,127 = 140 7/8; 563.53 → 564
      // quarters = 141" = 11 × 12 + 9 = 11'-9".
      (diagonal, mm, '3578'),
      (diagonal, cm, '357.8'),
      (diagonal, m, '3.58'),
      (diagonal, inch, '140 7/8'),
      (diagonal, ftIn, "11'-9\""),
    ];
    for (final (v, unit, want) in cases) {
      expect(formatDimension(v, unit), want, reason: '$v mm in ${unit.name}');
    }
  });

  test(
      'DF2 half-up is decided within dimFormat.linear of the half: '
      'Q5c\'s rows round up; 3450.5 − 0.9e-6 rounds up and 3450.5 − 2e-6 does '
      'not; the review\'s imperial near-miss prints 9\'-0"', () {
    // The contract's tolerance is 1e-6 mm (R-32), one wallJoin.linear. It is
    // pinned by behaviour, never by its literal: 3450.5 − 0.9e-6 must round
    // up and 3450.5 − 2e-6 must not.

    /// One row: [v] mm in quanta of [quantum] is [want] through
    /// `roundHalfUp` and prints [text] in [unit].
    void row(String what, double v, double quantum, int want, DisplayUnit unit,
        String text) {
      expect(roundHalfUp(v, quantum), want, reason: what);
      expect(formatDimension(v, unit), text, reason: what);
    }

    // --- Q5c's six rows. ---
    // 1005 mm in hundredths of a metre: 1005 / 10 = 100.5, on the half, up.
    // The naive rule on metres (1.005 × 100 = 100.49999999999999) says 100.
    expect((1005 / 1000 * 100).round(), 100); // premise: naive is wrong
    row('1005 mm in m', 1005, 10, 101, m, '1.01');
    // 3/16" = 4.7625 mm, stored 4.762499999999999: 1.5 eighths, up to 2.
    const e = 25.4 / 8, qu = 25.4 / 4;
    const threeSixteenths = 3 * 25.4 / 16;
    expect(threeSixteenths, lessThan(4.7625)); // premise: below the half
    expect(naive(threeSixteenths, e), 1); // premise: naive is wrong
    row('3/16"', threeSixteenths, e, 2, inch, '0 1/4');
    // 3/8" = 9.525 mm, stored 9.524999999999999: 1.5 quarters, up to 2.
    const threeEighths = 3 * 25.4 / 8;
    expect(threeEighths, lessThan(9.525)); // premise: below the half
    expect(naive(threeEighths, qu), 1); // premise: naive is wrong
    row('3/8"', threeEighths, qu, 2, ftIn, "0'-0 1/2\"");
    // A 3-4-5 aligned pair: legs 18.9 and 25.2 (0.6 × 31.5, 0.8 × 31.5),
    // true length 31.5, computed 31.499999999999996: up to 32.
    final h = math.sqrt(18.9 * 18.9 + 25.2 * 25.2);
    expect(h, lessThan(31.5)); // premise: below the half
    expect(naive(h, 1), 31); // premise: naive is wrong
    row('hypot(18.9, 25.2)', h, 1, 32, mm, '32');
    // The same shape at the corpus far origin: (4,500,000 + 0.3) −
    // 4,500,000 and 0.4, true length 0.5, computed 0.4999999998882413.
    const ox = 4500000.0;
    final dx = (ox + 0.3) - ox;
    final far = math.sqrt(dx * dx + 0.16);
    expect(far, lessThan(0.5)); // premise: below the half
    expect(0.5 - far, lessThan(dimFormat.linear)); // premise: within it
    expect(naive(far, 1), 0); // premise: naive is wrong
    row('far-origin hypot(0.3, 0.4)', far, 1, 1, mm, '1');
    // Not over-reaching: 2e-6 below a half is below it.
    row('3450.5 − 2e-6', 3450.5 - 2e-6, 1, 3450, mm, '3450');

    // --- The tolerance's contract, both ways (S-4). ---
    // 0.9e-6 below the half, inside 1e-6: on it, up.
    const nearBelow = 3450.5 - 0.9e-6;
    expect(3450.5 - nearBelow, greaterThan(0.8e-6)); // premise: a real gap
    row('3450.5 − 0.9e-6', nearBelow, 1, 3451, mm, '3451');
    // The other way, 3450.5 − 2e-6 (Q5c's last row, above) is outside the
    // tolerance and rounds down.

    // --- The recorded over-rounding (R-32, D18). ---
    // (0, 0)–(2124, 1731) aligned: √(4,511,376 + 2,996,361) = √7,507,737 =
    // 2,740.02499988595 mm, 1.14e-7 mm below 107 7/8" = 2,740.025 mm =
    // 431.5 quarters. Within the tolerance, so up to 432 quarters = 108" =
    // 9'-0", where exact half-up would give 431 = 107.75" = 8'-11 3/4".
    final l1 = math.sqrt(2124.0 * 2124 + 1731 * 1731);
    final gap1 = 107.875 * 25.4 - l1;
    expect(gap1, greaterThan(1e-7)); // premise: truly below the half …
    expect(gap1, lessThan(dimFormat.linear)); // … by less than the tolerance
    row('(0, 0)–(2124, 1731) in ft-in', l1, qu, 432, ftIn, "9'-0\"");
    // (0, 0)–(4160, 2697) in inches: √(17,305,600 + 7,273,809) =
    // √24,579,409, 6.46e-7 mm below 195 3/16" = 4,957.7625 mm = 1,561.5
    // eighths. Up to 1,562 = 195 2/8 = 195 1/4, where exact half-up would
    // give 195 1/8.
    final l2 = math.sqrt(4160.0 * 4160 + 2697 * 2697);
    final gap2 = 195.1875 * 25.4 - l2;
    expect(gap2, greaterThan(6e-7)); // premise: truly below the half …
    expect(gap2, lessThan(dimFormat.linear)); // … by less than the tolerance
    row('(0, 0)–(4160, 2697) in inches', l2, e, 1562, inch, '195 1/4');
  });
}
