// Criteria 1, 1b, 2, 2b and 2c: the live fallback, which no pixel gate in this
// repository has ever executed.
//
// **Every pixel comparison in `tile_cache_test.dart` runs at
// `tilesBakedPerFrame: 1000`**, where the first frame bakes the whole visible
// set, `uncovered` is null, and `paintFrame`'s fallback never runs at all. The
// two restricted-budget tests that do reach it assert counters. So the one
// composition this cache produces that nothing checked the pixels of is the
// frame that is part blit and part live walk -- which is also the frame where
// the two paths meet along a seam.

import 'package:flutter_test/flutter_test.dart';

import 'support/tile_comparison.dart';
import 'support/tile_fixture.dart';

// **No `jet_cad_2d_flutter` import here**, and it is not an oversight: this
// file names no symbol from it, and `unused_import` is an **error** in this
// package rather than a warning. Add one only when a symbol needs it.

/// Offsets that are not multiples of the tile's **logical** size.
///
/// A tile is `tileDevicePixels / devicePixelRatio` logical pixels -- 32 at this
/// rig's 64 device pixels and [kTileDpr] of 2, not 64. An offset on that
/// lattice would put the strip boundary exactly on a tile edge at every
/// sample and the sweep would measure one arrangement N times.
///
/// Each is a single-axis pan. A diagonal pan brings in a row *and* a column,
/// and `uncovered` is a bounding rectangle, so the union bounds to the whole
/// viewport and the sample has no interior edge to lose anything across.
const List<Offset> kFallbackOffsets = <Offset>[
  Offset(37, 0),
  Offset(53, 0),
  Offset(71, 0),
  Offset(0, 37),
  Offset(0, 53),
  Offset(0, 71),
  Offset(-41, 0),
  Offset(0, -41),
];

void main() {
  test('criterion 2 and 2c: a partly baked frame equals the live frame',
      () async {
    // `checkTriangleBudget: true` is criterion 1's other half: the pixel
    // assertions below prove the fallback lands the right pixels, and this
    // flag proves it did not re-tessellate the whole viewport to do it. See
    // `kTriangleBudgetRatio`'s doc comment for the measured numbers behind
    // the bound and why `criterion 2b` below does not also carry this flag.
    final reports = await sweepFallbackAgreement(
        of: fillingGrid, offsets: kFallbackOffsets, checkTriangleBudget: true);

    expect(reports, hasLength(kFallbackOffsets.length));
    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];
      expect(report.strayPixels, 0, reason: '${kFallbackOffsets[i]}: $report');
      expect(report.uncoveredPixels, 0,
          reason: '${kFallbackOffsets[i]}: $report');
      expect(report.differingPixels, 0,
          reason: '${kFallbackOffsets[i]}: $report');
    }
  });

  test('criterion 2b: the near-axis arm stays inside the tiled path\'s bound',
      () async {
    // The reference is not invented here: `tile_cache_test.dart` gates the
    // tiled path on this same fixture at `differingPixels <= 60` against a
    // measured 36 of 10342 ink, 0.348%. The fallback arm is held to the same
    // number, so an increase is a tripwire rather than a silent record.
    // No `checkTriangleBudget` here, deliberately: this fixture is a handful
    // of long diagonals spanning most of the viewport, so a strip-sized query
    // and a full-viewport query catch the same entities and the ratio sits at
    // 1.0 (or 0/20 where the strip misses the diagonals) even under correct
    // code. See `kTriangleBudgetRatio`'s doc comment.
    final reports = await sweepFallbackAgreement(
        of: nearAxisDiagonals, offsets: kFallbackOffsets, minimumInk: 200);

    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];
      expect(report.differingPixels, lessThanOrEqualTo(60),
          reason: '${kFallbackOffsets[i]}: $report');
      expect(report.differingPixels / report.liveInk, lessThan(0.01),
          reason: '${kFallbackOffsets[i]}: $report');
    }
  });
}
