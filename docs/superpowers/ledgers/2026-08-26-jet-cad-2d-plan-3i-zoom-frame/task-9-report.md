# Task 9 report — the differential arms (criteria 5, 6 and 11)

## What changed

| File | Change |
|---|---|
| `packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart` | **new.** Five arms. |
| `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart` | `captureTiled`, `captureLive`, `differingPixels`, `differingPixelsOnTileEdges`, `inkOnTileEdges`, `rebaseBoundaryCamera`, `kCaptureWidth`/`kCaptureHeight`. |
| `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` | `bandCrossingGrid`, `kBandStrokeLineweight`, `_sideFor`. |
| `packages/jet_cad_2d_flutter/test/support/tile_harness.dart` | `TiledHarness.index`; `settleFromBands`; `repaintOnce`; the `Center` fix in `pumpTiled`. |
| `packages/jet_cad_2d_flutter/test/support/fixtures.dart` | optional `lineweight` on `addEntity`/`addLine`, defaulting to the `25` every caller already had. |
| `docs/superpowers/notes/plan-3i-mutation-log.md` | M3, M7, M9, M9b, M10, M11, M8. |

**Nothing was moved.** `TiledHarness`, `pumpTiled` and `settle` were already in
`test/support/tile_harness.dart` -- Task 8 moved them out of
`tile_regime_test.dart`. No production file changed: `lib/` is byte-identical to
`HEAD` (`git status` shows only the five test files and the log).

## Two defects found in the instruments themselves

Both were found by mutation, not by reading, and both would have made this
task's five arms **completely blind**.

### 1. `pumpTiled`'s canvas was never `kTileViewport`

`pumpWidget` hands its child the surface's *tight* constraints, and a
`SizedBox` under tight constraints is inert. So the tiled canvas was 800x600
**logical** -- 1600x1200 device pixels, 25 x 19 = **475 tiles**, not the 130 its
own comments claim -- and `fillingGrid`, whose extent is derived in its doc
comment against a 400x300 viewport and which reaches only screen x -109.8..495
at `tileCamera`, left the right-hand 38% of every frame blank. Every widget-level
tile test (`tile_regime_test`, `tile_settle_test`, `invariants/tile_bytes_test`)
ran on a half-blank canvas.

Fixed with a `Center` around the `SizedBox` in `pumpTiled` and in `captureLive`.
Measured before/after: 475 tiles and a 1600x1200 capture became 130 and 800x600.
**No pre-existing assertion changed value** -- every count assertion in those
files is relative (`greaterThan(0)`, `greaterThan(afterFirst)`) and the whole
suite is green either way. `tile_settle_test.dart`'s own `pumpFilling` helper
still builds an uncentred tree and is still 800x600 logical; its assertions are
all relative and unaffected, and it was left alone as out of scope.

The two edge helpers now `expect` the capture's byte length against
`width * height * 4`, because indexing a differently-sized buffer as
`(y * width + x) * 4` is not a failure but a **silent** reinterpretation of the
wrong quarter of the image -- it goes on reporting zero.

### 2. `captureLive` returned the tiled image, byte for byte

`_DraftCustomPainter.shouldRepaint` returns `false` unconditionally (and says
why -- `repaint` is the only trigger). Pumping a tree that differs only in
`tiles` re-runs `didUpdateWidget`, tears the cache down, and then **keeps the
retained picture**. The "live" capture came back identical to the tiled one and
`differingPixels` read zero under M3, M7, M9, M9b, M10 and M11 alike -- six
mutants, all green, on a five-arm instrument. Fixed with a `ValueKey` on the
live tree's `DraftCanvas`, so the element is replaced and the render object has
no picture to retain. Verified by hash: the tiled capture's checksum tracks the
mutation, the live capture's does not.

Also fixed: the brief's `inkOnTileEdges` predicate, `!= 0xFFFFFFFF`. A
`DraftCanvas` paints no background, so the page is `0x00000000` and layer zero's
strokes are `0xFFFFFFFF` -- the predicate counted every background pixel and no
drawn one. It read 11,660 where the true figure is 1,868, and would have passed
a floor of 200 on a capture with nothing in it. Now `alpha != 0`, which is what
the rest of `tile_comparison.dart` tests.

## `bandCrossingGrid` against the two anti-degenerate clauses

**Entities larger than one tile.** A 64 device-pixel tile is 32 logical at
`kTileDpr`. Every horizontal line spans world x `-52 .. 380` = 432 world units,
which at `tileCamera`'s 1.4 scale is **604.8 logical pixels = 1209.6 device =
18.9 tiles**; every vertical spans world y `-52 .. 300` = 352 units =
**492.8 logical = 985.6 device = 15.4 tiles**. Crossing multiplicity is the term
`kTileDevicePixels`' own comment measures as the larger one, and a fixture of
tile-sized entities would never be walked into two bands.

**Thick strokes centred just outside a band boundary.** `kBandStrokeLineweight`
= 200 (2.00 mm). Both sinks compute `hundredths / 100 * pixelsPerPaperMm` and
`kLogicalPixelsPerMm = 96/25.4 = 3.7795`, so the stroke is
`2.0 * 3.7795 = 7.559` logical pixels wide -- **half-width 3.780 logical, 7.559
device**. Band `k` owns device rows `[64k, 64k+64)` = logical screen y
`[32k, 32k+32)`. One stroke per boundary sits at logical screen y `32k - 1`
(odd `k`) or `32k + 1` (even `k`): one logical pixel outside, against a 3.780
half-width, so it inks **2.780 logical pixels = 5.56 device rows** into the band
on the far side, across the band's full 800-device-pixel width. Its bounds do
not intersect that band, and the index query is exact -- measured, a line 0.1
world units outside a query rect returns 0 hits. World coordinates come from
inverting `tileCamera` (`wy = (323 - sy)/1.4`), so they are the non-round
far-from-origin numbers that camera implies: 208.571, 184.286, 162.857,
138.571, 117.143, 92.857, 71.429, 47.143, 25.714. Columns 1..12 get the same
treatment at `wx = (sx + 37)/1.4`.

**The arrangement that shipped first was self-masking and M9 caught it.** A
stroke on *both* sides of every boundary puts two centrelines 2 logical pixels
apart against a 3.780 half-width: the inner one's ink covers exactly what the
outer one's loss would expose, and `const pad = 0.0` changed **zero** pixels at
`tileCamera`. One stroke a boundary, alternating sides so both directions of the
pad are exercised across the fixture, is what makes M9 reachable -- 30,160
differing pixels on arm 1.

**Never (0, 0), never the identity.** Extent and spacing are `fillingGrid`'s,
for the reasons in its own doc comment; the camera is `tileCamera` (scale 1.4,
y-flipped, translated -37 / +323).

## How `rebaseBoundaryCamera` was chosen, and how it is known to straddle

`rebaseOriginFor` takes `span = max(visible world width, height)`, sets
`step = 2^floor(log2(span))`, and floors the view *centre* onto that step. For a
band to land in a **different cell** from the frame, a cell boundary has to fall
inside the frame -- at an ordinary camera it does not.

Constraints solved simultaneously: the viewport is 400x300 logical, and the
visible world box has to stay strictly inside `bandCrossingGrid`'s
`-52..380` by `-52..300` extent so the drawing fills the frame rather than
leaving a blank margin the comparison passes on for free.

* At scale **1.5** the span is `400/1.5 = 266.667`, step 256, and the centre
  would have to sit near 0 or 256 -- both outside the `[81.33, 246.67]` window
  the extent allows. **Rejected.**
* At scale **3.0** the span is `400/3 = 133.333`, `floor(log2) = 7`, step
  **128** -- the view is 1.042 steps wide, so exactly one cell boundary lies
  inside it -- and 128 is inside the `[14.67, 313.33]` window. **Taken.**

Translations chosen so the centre lands just past that boundary:
`cx = (200 - e)/3` and `cy = (f - 150)/3`, so `e = -184.5` and `f = 534.5` give
`cx = cy = 128.1667` -- **0.1667 world units, one device pixel, past 128**.
Both are whole device pixels at `kTileDpr` (`-369`, `1069`), so `quantiseCamera`
leaves the matrix untouched and both arms see the same one.

Verified by running it, not by arithmetic alone:

```
DIAG world=61.5,194.83333333333331 / 78.16666666666666,178.16666666666666
DIAG origin=[128.0,128.0]
```

Visible world y runs 78.167..178.167, so the 128 line is 50 world units inside
the frame and the 10.667-world-unit bands genuinely fall on both sides of it --
under M11 some take `(128, 128)` and others `(128, 0)`.

## Two things the arms needed that the brief could not know

**`settleFromBands`.** `paintFrame` bakes up to `262144/(64*64) = 64` tiles a
frame through the per-tile `_bake` path and the rest gate needs two unchanged
cameras, so a plain `settle` reaches its rest frame with **128 of 130 tiles
already baked**; `_restBake` skips every key `_tiles` already serves, so the
band path would have owned 2 tiles in the bottom-right corner and all seven
mutants would have been judged on those. A table edit is the one production
path that drops the tiles and **keeps the lattice and the anchor**, so the very
next frame is a rest frame over an empty generation: 130 slices, at exactly the
camera the fixture was laid out against. The helper asserts `slices > 0` and
`viewportCovered`; measured `slices = 130, liveTileCount = 130`.

**`repaintOnce`, on arm 3 only.** `paintFrame` blits the outgoing composite
first and underneath everything, *before* it decides the frame is resting;
`_restBake` then calls `_dropCarryOver`, which frees it for every later frame
but cannot un-draw this frame's blit. The settled frame after a **scale change**
therefore carries stale magnified ink wherever the incoming tiles are
transparent -- **67,509 differing pixels** measured on arm 3 -- and nothing
schedules the clean frame, because `viewportCovered` is true. This is the same
allowance `tile_cache_test`'s `criterion 1: a settled frame equals the live
frame after a zoom` makes by painting a fifth frame and asserting
`hasCarryOver` is false; arm 3 asserts the same thing.

## Arm 3's pan sign, and a finding about the untiled path

The brief writes arm 3's pan as `Offset(-90, -60)` with the comment "key range
goes negative". It does not: a negative pan makes `-dx` **positive** and the
range starts at `x0 = +2`. `Offset(90, 60)` is what produces the described case,
and it is what shipped. Verified on the shipped code:

```
DIAG arm3 bands=10 rows=-2..7 firstKeyX=-3 rect=Rect.fromLTRB(-192.0, -128.0, 640.0, -64.0)
     srcFirst=Rect.fromLTRB(0.0, 0.0, 64.0, 64.0) carry=false tiles=130
```

`deviceRect.left = -192`, so band-local and grid-space arithmetic genuinely
differ and M10 is witnessable -- the warning in the task instructions is
answered by measurement, not by assertion.

**Finding: `DraftPainter.paint` queries the index with no slack, and the tiled
path does.** `_bake` and `_bakeBand` pad their index query by `kTileSlack`;
`DraftPainter.paint` uses `camera.visibleWorld(viewport)` untouched
(`draft_painter.dart:338`), while `kScreenClipInflate` pads only the *clip*. So
a stroke whose centreline lies within its own half-width **outside a viewport
edge** is drawn by the tiled frame and missed by the live one -- **the tiled
frame is the correct one, and the difference is a property of the reference.**
At `Offset(-90, -60)` this fixture's stroke at world y 184.286 lands at screen y
-2.5 against a 3.780 half-width and arm 3 read **1,767 stray pixels across the
top three device rows, zero uncovered**. This is defect F1's root cause,
closed for the tile path in Plan 3g Task 9a and still open on the untiled one;
no existing fixture could see it because they all sit strictly inside the
viewport, which is the degenerate-fixture shape this repository names as
dominant. Not fixed here: it is a production change to the default rendering
path and could move `test/golden`.

The four cameras this task uses are checked against it. The dangerous window is
a 3.780-logical band outside each edge; at `Offset(90, 60)` those are world y in
(248.9, 250.98) and (82.0, 84.07) and world x in (-5.37, -3.30) and
(216.48, 218.56), and none of the fixture's nine horizontal or twelve vertical
thick strokes falls in any of them. Recorded in the arm's own comment.

## RED — the arms before the helpers existed

The four support files were restored to their `HEAD` content and the new test
run against them.

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart
test/tile_slice_differential_test.dart:39:44: Error: Undefined name 'bandCrossingGrid'.
    final h = await pumpTiled(t, document: bandCrossingGrid);
                                           ^^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:40:11: Error: Method not found: 'settleFromBands'.
    await settleFromBands(t, h);
          ^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:41:34: Error: Method not found: 'captureTiled'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                 ^^^^^^^^^^^^
test/tile_slice_differential_test.dart:41:60: Error: Method not found: 'captureLive'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                                           ^^^^^^^^^^^
test/tile_slice_differential_test.dart:41:12: Error: Method not found: 'differingPixels'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
           ^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:51:19: Error: Undefined name 'bandCrossingGrid'.
        document: bandCrossingGrid, camera: rebaseBoundaryCamera());
                  ^^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:51:45: Error: Method not found: 'rebaseBoundaryCamera'.
        document: bandCrossingGrid, camera: rebaseBoundaryCamera());
                                            ^^^^^^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:52:11: Error: Method not found: 'settleFromBands'.
    await settleFromBands(t, h);
          ^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:53:34: Error: Method not found: 'captureTiled'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                 ^^^^^^^^^^^^
test/tile_slice_differential_test.dart:53:60: Error: Method not found: 'captureLive'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                                           ^^^^^^^^^^^
test/tile_slice_differential_test.dart:53:12: Error: Method not found: 'differingPixels'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
           ^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:60:44: Error: Undefined name 'bandCrossingGrid'.
    final h = await pumpTiled(t, document: bandCrossingGrid);
                                           ^^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:61:11: Error: Method not found: 'settleFromBands'.
    await settleFromBands(t, h);
          ^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:68:34: Error: Method not found: 'captureTiled'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                 ^^^^^^^^^^^^
test/tile_slice_differential_test.dart:68:60: Error: Method not found: 'captureLive'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                                           ^^^^^^^^^^^
test/tile_slice_differential_test.dart:68:12: Error: Method not found: 'differingPixels'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
           ^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:76:44: Error: Undefined name 'bandCrossingGrid'.
    final h = await pumpTiled(t, document: bandCrossingGrid);
                                           ^^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:77:11: Error: Method not found: 'settleFromBands'.
    await settleFromBands(t, h);
          ^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:87:34: Error: Method not found: 'captureTiled'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                 ^^^^^^^^^^^^
test/tile_slice_differential_test.dart:87:60: Error: Method not found: 'captureLive'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                                           ^^^^^^^^^^^
test/tile_slice_differential_test.dart:87:12: Error: Method not found: 'differingPixels'.
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
           ^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:94:44: Error: Undefined name 'bandCrossingGrid'.
    final h = await pumpTiled(t, document: bandCrossingGrid);
                                           ^^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:95:11: Error: Method not found: 'settleFromBands'.
    await settleFromBands(t, h);
          ^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:96:25: Error: Method not found: 'captureTiled'.
    final tiled = await captureTiled(t, h);
                        ^^^^^^^^^^^^
test/tile_slice_differential_test.dart:97:24: Error: Method not found: 'captureLive'.
    final live = await captureLive(t, h);
                       ^^^^^^^^^^^
test/tile_slice_differential_test.dart:98:15: Error: Undefined name 'kCaptureWidth'.
    const w = kCaptureWidth, hgt = kCaptureHeight; // 800 x 600 device pixels
              ^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:98:36: Error: Undefined name 'kCaptureHeight'.
    const w = kCaptureWidth, hgt = kCaptureHeight; // 800 x 600 device pixels
                                   ^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:100:9: Error: Method not found: 'differingPixelsOnTileEdges'.
        differingPixelsOnTileEdges(tiled, live,
        ^^^^^^^^^^^^^^^^^^^^^^^^^^
test/tile_slice_differential_test.dart:106:12: Error: Method not found: 'inkOnTileEdges'.
    expect(inkOnTileEdges(live, tileDevicePixels: 64, width: w, height: hgt),
           ^^^^^^^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: test/tile_slice_differential_test.dart:39:44: Error: Undefined name 'bandCrossingGrid'.
      final h = await pumpTiled(t, document: bandCrossingGrid);
                                             ^^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:40:11: Error: Method not found: 'settleFromBands'.
      await settleFromBands(t, h);
            ^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:41:34: Error: Method not found: 'captureTiled'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                   ^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:41:60: Error: Method not found: 'captureLive'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                                             ^^^^^^^^^^^
  test/tile_slice_differential_test.dart:41:12: Error: Method not found: 'differingPixels'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
             ^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:51:19: Error: Undefined name 'bandCrossingGrid'.
          document: bandCrossingGrid, camera: rebaseBoundaryCamera());
                    ^^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:51:45: Error: Method not found: 'rebaseBoundaryCamera'.
          document: bandCrossingGrid, camera: rebaseBoundaryCamera());
                                              ^^^^^^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:52:11: Error: Method not found: 'settleFromBands'.
      await settleFromBands(t, h);
            ^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:53:34: Error: Method not found: 'captureTiled'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                   ^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:53:60: Error: Method not found: 'captureLive'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                                             ^^^^^^^^^^^
  test/tile_slice_differential_test.dart:53:12: Error: Method not found: 'differingPixels'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
             ^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:60:44: Error: Undefined name 'bandCrossingGrid'.
      final h = await pumpTiled(t, document: bandCrossingGrid);
                                             ^^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:61:11: Error: Method not found: 'settleFromBands'.
      await settleFromBands(t, h);
            ^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:68:34: Error: Method not found: 'captureTiled'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                   ^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:68:60: Error: Method not found: 'captureLive'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                                             ^^^^^^^^^^^
  test/tile_slice_differential_test.dart:68:12: Error: Method not found: 'differingPixels'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
             ^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:76:44: Error: Undefined name 'bandCrossingGrid'.
      final h = await pumpTiled(t, document: bandCrossingGrid);
                                             ^^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:77:11: Error: Method not found: 'settleFromBands'.
      await settleFromBands(t, h);
            ^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:87:34: Error: Method not found: 'captureTiled'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                   ^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:87:60: Error: Method not found: 'captureLive'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
                                                             ^^^^^^^^^^^
  test/tile_slice_differential_test.dart:87:12: Error: Method not found: 'differingPixels'.
      expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
             ^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:94:44: Error: Undefined name 'bandCrossingGrid'.
      final h = await pumpTiled(t, document: bandCrossingGrid);
                                             ^^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:95:11: Error: Method not found: 'settleFromBands'.
      await settleFromBands(t, h);
            ^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:96:25: Error: Method not found: 'captureTiled'.
      final tiled = await captureTiled(t, h);
                          ^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:97:24: Error: Method not found: 'captureLive'.
      final live = await captureLive(t, h);
                         ^^^^^^^^^^^
  test/tile_slice_differential_test.dart:98:15: Error: Undefined name 'kCaptureWidth'.
      const w = kCaptureWidth, hgt = kCaptureHeight; // 800 x 600 device pixels
                ^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:98:36: Error: Undefined name 'kCaptureHeight'.
      const w = kCaptureWidth, hgt = kCaptureHeight; // 800 x 600 device pixels
                                     ^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:100:9: Error: Method not found: 'differingPixelsOnTileEdges'.
          differingPixelsOnTileEdges(tiled, live,
          ^^^^^^^^^^^^^^^^^^^^^^^^^^
  test/tile_slice_differential_test.dart:106:12: Error: Method not found: 'inkOnTileEdges'.
      expect(inkOnTileEdges(live, tileDevicePixels: 64, width: w, height: hgt),
             ^^^^^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart
```

## GREEN

```
00:00 +0: a settled generation is identical to a live frame
00:00 +1: and at a camera on a power-of-two rebase boundary
00:00 +2: and stays identical after a pan smaller than one tile
00:00 +3: and when a pan lands between the scale change and the bake
00:00 +4: tile boundaries carry no difference of their own
00:00 +5: All tests passed!
```

## Mutations

Every mutant was applied to a copy-aside of `lib/src/tile_cache.dart`, run
against the **whole package suite** with `CI=true flutter test`, and restored
from the copy. **Never `git checkout`.** Full write-ups, including the reasoning
for each, are in `docs/superpowers/notes/plan-3i-mutation-log.md`.

| | Mutation | Killed by | Differing pixels |
|---|---|---|---|
| M3 | `sliceSourceRect` always `(0, 0)` | arms 1, 2, 3, 5, tile edges + Task 7 unit | 58,424 / 59,892 / 68,370 / 78,387; 10,684 on edges |
| M7 | `bandsFor` clamps to the viewport | **arm 2**, arm 3 + Task 5 unit | 3,780 / 8,692 |
| M9 | `const pad = 0.0` | all five arms + two Task 6 units | 30,160 (arms 1, 5); 8,196 / 9,170; 3,475 on edges |
| M9b | camera keeps `+pad`, canvas loses `-pad` | all five arms | 140,032 / 140,060 / 192,258 / 227,695; 8,469 on edges |
| M10 | slice rect drops `- band.deviceRect.left` | **arm 3 only** + Task 7 unit | 132,650 |
| M11 | band derives its own origin | Task 6 origin unit **only** | 0 on every arm |
| M8 | `_sliceTile` uses `FilterQuality.low` | **nothing -- declared survivor** | 0 |

### M3

```diff
@@ -339,7 +339,7 @@
   /// numbered. Integral by construction -- [deviceDeltaFrom] rounds, and a
   /// tile side is `tileDevicePixels` exactly.
   Rect sliceSourceRect(TileBand band, TileKey key) => Rect.fromLTWH(
-        key.x * tileDevicePixels.toDouble() - band.deviceRect.left,
+        0,
         0,
         tileDevicePixels.toDouble(),
         tileDevicePixels.toDouble(),
```

```
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <58424>
a band is queried with a pad and clipped without one, and the tiles cut out of it have to hold what
the live frame draws

  [stack trace elided]
The test description was:
  a settled generation is identical to a live frame

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <68370>
rebasing is frame-global: every band must be walked against the frame origin, not one it derived for
itself

  [stack trace elided]
The test description was:
  and at a camera on a power-of-two rebase boundary

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <59892>
an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
same as an opaque one, so no timing gate can see it

  [stack trace elided]
The test description was:
  and stays identical after a pan smaller than one tile

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <78387>
a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
range moves

  [stack trace elided]
The test description was:
  and when a pan lands between the scale change and the bake

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <10684>
a seam lives on the boundary, and a whole-frame count buries it under 62 interior columns out of
every 64

  [stack trace elided]
The test description was:
  tile boundaries carry no difference of their own

00:06 +392 ~1 -7: Some tests failed.
Failing tests:
  test/tile_band_test.dart: the band bake a slice rectangle is band-local and integral
  test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
  test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
  test/tile_slice_differential_test.dart: and at a camera on a power-of-two rebase boundary
  ... and 3 more
```

### M7

```diff
@@ -368,11 +368,18 @@
             row * tileDevicePixels.toDouble(),
             byRow[row]!.length * tileDevicePixels.toDouble(),
             tileDevicePixels.toDouble(),
-          ),
+          ).intersect(_viewportDeviceRect(camera, viewport)),
         ),
     ];
   }
 
+  /// M7: the viewport in the grid's own device space.
+  Rect _viewportDeviceRect(ViewportTransform camera, Size viewport) {
+    final (dx, dy) = deviceDeltaFrom(camera);
+    return Rect.fromLTWH(-dx.toDouble(), -dy.toDouble(),
+        viewport.width * devicePixelRatio, viewport.height * devicePixelRatio);
+  }
+
   /// Floor division that stays correct for negative numerators.
   ///
   /// Dart's `~/` truncates toward zero, so `-1 ~/ 64` is `0` and the tile to
```

```
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <8692>
an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
same as an opaque one, so no timing gate can see it

  [stack trace elided]
The test description was:
  and stays identical after a pan smaller than one tile

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <3780>
a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
range moves

  [stack trace elided]
The test description was:
  and when a pan lands between the scale change and the bake

00:07 +395 ~1 -4: Some tests failed.
Failing tests:
  test/tile_band_test.dart: a band is one tile tall and the full union width
  test/tile_band_test.dart: the band bake a slice rectangle is band-local and integral
  test/tile_slice_differential_test.dart: and stays identical after a pan smaller than one tile
  test/tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
```

### M9

```diff
@@ -2006,7 +2006,7 @@
     // uses -- padding one alone makes them disagree. The canvas is pulled back
     // by the same amount, so the padded viewport's origin lands where the
     // band's own origin was.
-    const pad = kTileSlack;
+    const pad = 0.0;
     into.save();
     into.translate(-pad, -pad);
```

```
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <30160>
a band is queried with a pad and clipped without one, and the tiles cut out of it have to hold what
the live frame draws

  [stack trace elided]
The test description was:
  a settled generation is identical to a live frame

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <3475>
rebasing is frame-global: every band must be walked against the frame origin, not one it derived for
itself

  [stack trace elided]
The test description was:
  and at a camera on a power-of-two rebase boundary

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <30160>
an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
same as an opaque one, so no timing gate can see it

  [stack trace elided]
The test description was:
  and stays identical after a pan smaller than one tile

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <9170>
a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
range moves

  [stack trace elided]
The test description was:
  and when a pan lands between the scale change and the bake

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <8196>
a seam lives on the boundary, and a whole-frame count buries it under 62 interior columns out of
every 64

  [stack trace elided]
The test description was:
  tile boundaries carry no difference of their own

00:06 +391 ~1 -8: Some tests failed.
Failing tests:
  test/tile_band_test.dart: the band bake the band camera puts a world point at the band-local pixel
  test/tile_band_test.dart: the band bake the padded query reaches kTileSlack past the band on every side
  test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
  test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
  ... and 4 more
```

### M9b

```diff
@@ -2008,7 +2008,6 @@
     // band's own origin was.
     const pad = kTileSlack;
     into.save();
-    into.translate(-pad, -pad);
 
     final m = grid.anchor.worldToScreenMatrix;
     final bandCamera = ViewportTransform(
```

```
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <140032>
a band is queried with a pad and clipped without one, and the tiles cut out of it have to hold what
the live frame draws

  [stack trace elided]
The test description was:
  a settled generation is identical to a live frame

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <192258>
rebasing is frame-global: every band must be walked against the frame origin, not one it derived for
itself

  [stack trace elided]
The test description was:
  and at a camera on a power-of-two rebase boundary

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <140060>
an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
same as an opaque one, so no timing gate can see it

  [stack trace elided]
The test description was:
  and stays identical after a pan smaller than one tile

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <227695>
a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
range moves

  [stack trace elided]
The test description was:
  and when a pan lands between the scale change and the bake

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <8469>
a seam lives on the boundary, and a whole-frame count buries it under 62 interior columns out of
every 64

  [stack trace elided]
The test description was:
  tile boundaries carry no difference of their own

00:07 +393 ~1 -6: Some tests failed.
Failing tests:
  test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
  test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
  test/tile_slice_differential_test.dart: and at a camera on a power-of-two rebase boundary
  test/tile_slice_differential_test.dart: and stays identical after a pan smaller than one tile
  ... and 2 more
```

### M10

```diff
@@ -339,7 +339,7 @@
   /// numbered. Integral by construction -- [deviceDeltaFrom] rounds, and a
   /// tile side is `tileDevicePixels` exactly.
   Rect sliceSourceRect(TileBand band, TileKey key) => Rect.fromLTWH(
-        key.x * tileDevicePixels.toDouble() - band.deviceRect.left,
+        key.x * tileDevicePixels.toDouble(),
         0,
         tileDevicePixels.toDouble(),
         tileDevicePixels.toDouble(),
```

```
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <132650>
a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
range moves

  [stack trace elided]
The test description was:
  and when a pan lands between the scale change and the bake

00:07 +397 ~1 -2: Some tests failed.
Failing tests:
  test/tile_band_test.dart: the band bake a slice rectangle is band-local and integral
  test/tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
```

### M11 — survives every pixel arm, and why

```diff
@@ -1988,6 +1988,7 @@
         grid.matchesScale(quantised),
         'a band belongs to one generation, so the frame camera and the grid '
         'anchor must agree on scale');
+    assert(origin.x == origin.x);
     final dpr = grid.devicePixelRatio;
     final width = band.deviceRect.width / dpr;
     final height = band.deviceRect.height / dpr;
@@ -2029,11 +2030,9 @@
       painter,
       sink,
       vertices,
-      // **The viewport's origin, never the band's.** Rebasing is frame-global
-      // by construction: a per-band origin gives each band its own
-      // quantisation step and `float32` residuals the live frame does not
-      // have, and can cross a power-of-two step between one row and the next.
-      origin,
+      // ignore: dead_code
+      rebaseOriginFor(bandCamera
+          .visibleWorld(Size(width + 2 * pad, height + 2 * pad))),
       (handle) => visitedInto.add(handle.value),
     );
     into.restore();
```

```
00:06 +398 ~1 -1: Some tests failed.
Failing tests:
  test/tile_band_test.dart: the band bake every band is rebased against the origin handed in
```

The task instructions expected arm 1 at a rebase-boundary camera to kill this.
It does not, and the reason is structural rather than a weakness in the arm.
`DraftPainter._emitScreenSpace` computes `p_screen - _screenOrigin` in `float64`
and hands the sink `beginResidual(translation(_screenOrigin))`;
`VerticesDrawSink` adds the residual back in `float64` before storing an
**absolute** screen coordinate in its `Float32List`. The origin cancels
algebraically **before** anything is rounded to `float32`, so at this fixture's
magnitudes the difference is around `1e-13` device pixels -- fourteen orders of
magnitude below the `1.1e-05` Task 6a measured as the threshold for flipping one
pixel on a near-axis slope, and this fixture is axis-aligned by construction.
Confirmed by measurement: with the boundary camera genuinely giving bands
`(128, 128)` and `(128, 0)`, `differingPixels` reads **0**.

`rebaseBoundaryCamera` still earns its place -- it runs arms 1's comparison at a
second scale (3.0 against 1.4) and is red under M3, M9 and M9b -- but the gate
of record for the origin argument is Task 6's direct observation, which is what
the task brief's own table said. The origin is paid for at 4.5e6-scale
coordinates (`large_coordinate_test.dart`), where that `float64` cancellation is
no longer exact; no fixture in this plan is at those magnitudes.

### M8 — the declared survivor

```diff
@@ -2080,6 +2080,9 @@
   /// from the rejected Approach B. `FilterQuality.none`: the source rectangle
   /// is integral and the destination is the same size, so there is nothing to
   /// interpolate and a sampler would be pure cost.
+  final Paint _sliceFilterPaint = Paint()
+    ..filterQuality = FilterQuality.low;
+
   Image _sliceTile(Image band, TileBand from, TileKey key, TileGrid grid) {
     final recorder = PictureRecorder();
     final into = Canvas(recorder);
@@ -2088,7 +2091,7 @@
       grid.sliceSourceRect(from, key),
       Rect.fromLTWH(
           0, 0, tileDevicePixels.toDouble(), tileDevicePixels.toDouble()),
-      _blitPaint,
+      _sliceFilterPaint,
     );
     final picture = recorder.endRecording();
     final image = picture.toImageSync(tileDevicePixels, tileDevicePixels);
```

```
00:06 +399 ~1: All tests passed!
```

Green, as declared, and **not reported as a defect**. Its dying would have been
the finding: it would mean `sliceSourceRect` is not integral and a slice is
resampling. The suite being green under it is the positive statement -- the
rectangles are integral, a bilinear sample and a nearest sample read the same
texels, and only a sampler is paid for. Plan 3h's M6 had this shape and is
recorded as gap H6.

## Pre-existing tests changed

None changed an assertion or its value. The only behavioural change to shared
test infrastructure is the `Center` in `pumpTiled`, which affects
`tile_regime_test.dart`, `tile_settle_test.dart` and
`invariants/tile_bytes_test.dart`: their canvas goes from 800x600 logical
(475 tiles) to `kTileViewport`'s 400x300 (130 tiles), which is what all three
files' own comments already claim. Every count assertion in them is relative and
none moved. `addEntity`/`addLine` gained an optional `lineweight` defaulting to
the hardcoded `25` they already used, so no existing fixture moves by a pixel.

## The gate

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
00:06 +395 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: and at a camera on a power-of-two rebase boundary
00:06 +396 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: and stays identical after a pan smaller than one tile
00:06 +397 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
00:06 +398 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:06 +399 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...                                 
No issues found! (ran in 1.2s)
Formatted 71 files (0 changed) in 0.13 seconds.
```

`git status` before staging: only the five test files and the mutation log.
No `analysis_options.yaml`, no golden PNG, nothing under `packages/jet_cad_2d`,
and `lib/` identical to `HEAD`.
