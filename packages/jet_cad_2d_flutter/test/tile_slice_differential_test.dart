// The pixel instruments the slice path is judged by: criteria 5, 6 and 11.
//
// **Why four arms and not one.** Arm 1 compares a settled tiled frame against
// the live frame at the same camera, and that is the criterion. It cannot see
// two whole classes of defect on its own:
//
//   * A band cut wider than the viewport blits its **transparent overhang**
//     off the right-hand edge, where nothing is looking. Plan 3h's p95 pan
//     gate is blind to it too — a transparent blit costs exactly what an
//     opaque one costs. Only a pan smaller than one tile brings that overhang
//     inside the viewport, which is arm 2.
//   * A slice rectangle measured in grid space rather than band space is the
//     *same rectangle* whenever the visible key range starts at column 0,
//     because `TileBand.deviceRect.left` is defined as
//     `keys.first.x * tileDevicePixels`. The pinned pure-zoom script never
//     moves that range. Arm 3 takes a pan between the scale change and the
//     rest bake, which does.
//
// Arm 4 is criterion 6 with teeth: the same comparison restricted to the rows
// and columns a tile boundary falls on, plus the clause that says the sweep
// looked at ink rather than at background.
//
// **Every arm settles through `settleFromBands`, and that is load-bearing.**
// A plain `settle` reaches its rest frame with 128 of 130 tiles already baked
// by the per-tile path, so the band bake would slice two corner tiles and
// every mutant below would be judged on those two. See `settleFromBands`.
//
// **Zero, never a tolerance.** `quantiseCamera` puts every tile destination on
// whole device pixels, so a blit is a 1:1 texel copy; there is nothing for a
// tolerance to absorb and a seam of one unit is exactly what one would hide.
import 'package:flutter_test/flutter_test.dart';

import 'support/tile_comparison.dart';
import 'support/tile_fixture.dart';
import 'support/tile_harness.dart';

void main() {
  testWidgets('a settled generation is identical to a live frame', (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settleFromBands(t, h);
    expect(
        differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'a band is queried with a pad and clipped without one, and '
            'the tiles cut out of it have to hold what the live frame draws');
  });

  // The same arm at a camera whose view span straddles a power-of-two rebase
  // step, so a band that derived its own origin would land in a different
  // cell of that step from the frame. See `rebaseBoundaryCamera`.
  testWidgets('and at a camera on a power-of-two rebase boundary', (t) async {
    final h = await pumpTiled(t,
        document: bandCrossingGrid, camera: rebaseBoundaryCamera());
    await settleFromBands(t, h);
    expect(
        differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'rebasing is frame-global: every band must be walked against '
            'the frame origin, not one it derived for itself');
  });

  testWidgets('and stays identical after a pan smaller than one tile',
      (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settleFromBands(t, h);
    // Under one 32-logical-pixel tile in both axes, so the visible key range
    // does not move and no tile is rebaked: what changes is only *where* the
    // tiles already held blit, which is what drags an edge tile's overhang
    // into view.
    h.camera.panBy(const Offset(-11, -7));
    await settle(t, h);
    expect(
        differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'an edge tile sliced from a viewport-sized source blits its '
            'transparent overhang here, and costs the same as an opaque one, '
            'so no timing gate can see it');
  });

  testWidgets('and when a pan lands between the scale change and the bake',
      (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settleFromBands(t, h);
    h.camera.zoomAt(const Offset(120, 90), 1.3);
    await t.pump(); // moving: the generation is retired and a new one anchored
    // 90 x 60 logical is 180 x 120 device pixels, two and a bit tiles in each
    // axis, and **positive**, which drives the visible key range *negative*:
    // `visibleKeys` starts at `-dx`, so `x0 = floorDiv(-180, 64) = -3` and
    // `y0 = -2`, and the band's `deviceRect.left` is -192. Both halves matter.
    // Without a pan at all, band-local and grid-space slice arithmetic are the
    // *same arithmetic* -- `deviceRect.left` is `keys.first.x * 64`, which is
    // zero when the range starts at column 0 -- and M10 is unwitnessable; with
    // the range negative the grid-space rectangle is negative too and reads
    // off the front of the band image, which is the case the pinned pure-zoom
    // script never produces.
    //
    // **The sign is also what keeps the untiled reference honest here, and
    // that is a measured constraint rather than a preference.** A tile bake
    // queries the index padded by `kTileSlack`; `DraftPainter.paint` queries
    // `camera.visibleWorld(viewport)` with no slack at all. So a stroke whose
    // centreline lies within its own half-width *outside* a viewport edge is
    // drawn by the tiled frame and missed by the live one -- the tiled frame
    // is the correct one, and the difference is a property of the reference.
    // At `Offset(-90, -60)` this fixture's thick stroke at world y 184.286
    // lands at screen y -2.5 against a 3.78 half-width and the arm read 1,767
    // stray pixels across the top three device rows. At `Offset(90, 60)` the
    // four such windows are world y in (248.9, 250.98) and (82.0, 84.07) and
    // world x in (-5.37, -3.30) and (216.48, 218.56), and no thick stroke this
    // fixture places falls in any of them. Reported as a finding: the
    // asymmetry is real and belongs to `DraftPainter`, not to the tile path.
    h.camera.panBy(const Offset(90, 60));
    await t.pump(); // moving again, so the rest gate starts over
    await settle(t, h);
    // The rest frame blitted the outgoing composite underneath the generation
    // it then dropped, so it is not a statement about the new tiles alone.
    // See `repaintOnce`; `tile_cache_test`'s criterion 1 pays for the same
    // frame and asserts the same thing before comparing.
    await repaintOnce(t, h);
    expect(h.cache.hasCarryOver, isFalse,
        reason: 'a composite still on screen composes the outgoing '
            'generation under every transparent pixel of the incoming one');
    expect(
        differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'a grid-space slice rectangle reads off the wrong part of the '
            'band image as soon as the visible key range moves');
  });

  // Criterion 6, with its teeth: the boundary columns and rows specifically.
  testWidgets('tile boundaries carry no difference of their own', (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settleFromBands(t, h);
    final tiled = await captureTiled(t, h);
    final live = await captureLive(t, h);
    const w = kCaptureWidth, hgt = kCaptureHeight; // 800 x 600 device pixels
    expect(
        differingPixelsOnTileEdges(tiled, live,
            tileDevicePixels: 64, width: w, height: hgt),
        0,
        reason: 'a seam lives on the boundary, and a whole-frame count buries '
            'it under 62 interior columns out of every 64');
    // Not vacuous: the sweep must have looked at ink, not at background.
    expect(inkOnTileEdges(live, tileDevicePixels: 64, width: w, height: hgt),
        greaterThan(200),
        reason: 'two blank captures agree perfectly and prove nothing');
  });
}
