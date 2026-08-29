# Task 7 report — the slice, band-local, integral, unfiltered

## What changed

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:

- `TileGrid.sliceSourceRect(TileBand band, TileKey key)` — where a key's
  pixels sit **inside** the band image: `key.x * tileDevicePixels -
  band.deviceRect.left`, top `0`, side `tileDevicePixels`. Band-local, never
  the grid-space rectangle.
- `TileCache._sliceTile(Image band, TileBand from, TileKey key, TileGrid
  grid)` — a plain `drawImageRect` copy from the band image into a fresh
  `tileDevicePixels`-square `Image`, using `_blitPaint` (`FilterQuality.none`
  — the source rect is integral and the destination is the same size, so
  there is nothing to interpolate).
- `TileCache.debugSliceTile(...)` — `@visibleForTesting` wrapper around
  `_sliceTile`.

`packages/jet_cad_2d_flutter/test/tile_band_test.dart`:

- New test `'a slice rectangle is band-local and integral'`, added inside
  the existing `group('the band bake', ...)` so it reuses that group's
  `setUp` — the panned fixture (`anchor` resting, `frame` panned by
  `(-50, -30)` logical / `(-100, -60)` device pixels) and its `band =
  bands[3]`.

## Why the test lives in the panned group, not a fresh `gridAt(tileCamera())`

The brief's literal Step-1 snippet builds `grid = gridAt(camera)` with no
pan and takes `grid.bandsFor(camera, kTileViewport).first`. With anchor ==
camera exactly, `deviceDeltaFrom` is `(0, 0)`, so the first visible key's
`x` is `0` and `band.deviceRect.left` (which `bandsFor` defines as
`band.keys.first.x * tileDevicePixels`) is also `0`. In that state, a
grid-space implementation (`key.x * tileDevicePixels`, no subtraction) and
the band-local one are numerically identical for **every** key in the
band — the offset being subtracted is zero. That fixture cannot ever fail
on M10, on any key, first or later. So I did not use it; I added the test
into the group whose fixture already carries a real pan and whose keys
already start at `x = 1` (`band.deviceRect.left == 64`), which is the one
place in this file where the offset being subtracted is actually nonzero.

## The two things the brief's test does not do

1. **Non-first-key assertion.** Added
   `expect(grid.sliceSourceRect(band, band.keys[1]).left, 64.0, ...)`
   (`band.keys[1]` is the second key of `band`, at grid column 2, one tile
   to the right of `band.keys.first`).

2. **Whether the grid-space mutant dies on the first key or only later
   ones, given this fixture's keys start at `x = 1`.** It dies on the
   **first** key too, here. `band.deviceRect.left` is `1 * 64 = 64`, not
   `0`, so a grid-space read of `sliceSourceRect(band, band.keys.first)`
   gives `1 * 64 = 64`, against the band-local `0` — the two already
   disagree on the very first assertion. Concretely: the first-key
   assertion (`== 0.0`) is only "necessary but weak" as a *pattern* — it
   is vacuous whenever `band.deviceRect.left` happens to be `0`, which is
   exactly the resting, unpanned case the brief's own literal snippet
   would have produced. It is not weak in *this* fixture, because the pan
   already makes the band's grid-space offset nonzero.

   The second-key assertion earns its place on a different axis: it is not
   more powerful than the first-key one in this specific fixture (both
   already catch M10 here, since the fixture's offset is nonzero end to
   end), but it also cannot be gamed by an implementation that special-cases
   `key == band.keys.first` (e.g. hardcodes `Rect.fromLTWH(0, 0, ...)` for
   the first key while reading grid-space directly for every other one) —
   a shape the single first-key assertion would let through undetected. It
   also pins the *general* invariant — a constant one-tile spacing between
   consecutive keys, independent of which grid column the band starts at —
   rather than only a boundary value.

   Neither assertion, alone or together, can catch M10 in a fixture whose
   band happens to start at grid column 0 (offset `0`): with that offset,
   band-local and grid-space reduce to the same arithmetic for every key,
   full stop. Catching M10 at all requires a band whose grid-space offset
   is nonzero, which is why this test reuses the panned fixture rather than
   a fresh unpanned one.

## RED (before the implementation existed)

```
$ CI=true flutter test test/tile_band_test.dart
...
test/tile_band_test.dart:231:26: Error: The method 'sliceSourceRect' isn't defined for the type 'TileGrid'.
 - 'TileGrid' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing method, or defining a method named 'sliceSourceRect'.
        final src = grid.sliceSourceRect(band, key);
                         ^^^^^^^^^^^^^^^
test/tile_band_test.dart:242:19: Error: The method 'sliceSourceRect' isn't defined for the type 'TileGrid'.
 - 'TileGrid' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing method, or defining a method named 'sliceSourceRect'.
      expect(grid.sliceSourceRect(band, band.keys.first).left, 0.0);
                  ^^^^^^^^^^^^^^^
test/tile_band_test.dart:256:19: Error: The method 'sliceSourceRect' isn't defined for the type 'TileGrid'.
 - 'TileGrid' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing method, or defining a method named 'sliceSourceRect'.
      expect(grid.sliceSourceRect(band, band.keys[1]).left, 64.0,
                  ^^^^^^^^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart: ...
00:00 +0 -1: Some tests failed.
```

(Produced by re-applying the implementation diff as a patch after
`git checkout --` reverted `lib/src/tile_cache.dart` — the test file was
already in place — then reapplying the implementation once RED was
confirmed.)

## GREEN (after the implementation)

```
$ CI=true flutter test test/tile_band_test.dart
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart
00:00 +0: the bands partition the visible keys, in row order, without gaps
00:00 +1: a band is one tile tall and the full union width
00:00 +2: the union overhangs the viewport, and the bands carry the overhang
00:00 +3: the band bake the fixture puts the band off both axes and off the anchor
00:00 +4: the band bake the band camera puts a world point at the band-local pixel
00:00 +5: the band bake the padded query reaches kTileSlack past the band on every side
00:00 +6: the band bake every band is rebased against the origin handed in
00:00 +7: the band bake a slice rectangle is band-local and integral
00:00 +8: the band bake the walk reports the handles it touched into visitedInto
00:00 +9: All tests passed!
```

(`+7` is this task's new test.)

## The gate — whole package, not one file

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:07 +392 ~1: All tests passed!
```

(The `~1` is a single pre-existing skip in this suite, unrelated to this
task — every other test, 392 of them, passed.)

```
$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 69 files (0 changed) in 0.14 seconds.
```

All three gate commands are green.

## The test seam: `debugSliceTile`

`_sliceTile` has no production caller yet — Task 8 (or later) is what
wires the slice into `paintFrame`. Left unreferenced, `unused_element`
(an error in this package's analyzer config) would fail the gate. Exposed
it exactly the way Task 6 exposed `_bakeBand` as `debugBakeBand`: a public
`@visibleForTesting` wrapper that forwards to the private method, with a
doc comment naming `debugBakeBand` as the precedent and stating why the
seam exists. **Not deleted, and `debugBakeBand` itself is untouched** —
Task 6's tests still reference it.

No test in this task calls `debugSliceTile` — the brief's test only
exercises `sliceSourceRect`, and pixel-level verification of the copy
itself is explicitly out of scope here ("No mutation duty in this task.
M3, M8 and M10 fire in the later task that owns the pixel instruments.").
`debugSliceTile` exists solely to satisfy the analyzer until that task
lands.

## What `_sliceTile` allocates

Per call (one call per tile sliced out of a resting band, never per
entity):

- One `PictureRecorder` and its `Canvas` wrapper.
- One `Rect` from `grid.sliceSourceRect(from, key)` (the source rect).
- One `Rect` literal for the destination (`Rect.fromLTWH(0, 0,
  tileDevicePixels, tileDevicePixels)`), allocated fresh at the call site
  rather than reusing the cache's existing `late final Rect
  _tileSourceRect` field, which is numerically identical to it (same
  square, same origin, same side). `_bake`'s own doc comment records that
  a per-blit `Rect` allocation was exactly the defect Task 10 fixed for the
  *blit* path (`_tileSourceRect` used to be a getter); `_sliceTile` as
  implemented here (verbatim from the brief) reintroduces that same shape
  of allocation on the *slice* path. It is bounded — once per tile per
  resting frame, not per entity — so it does not violate the "nothing per
  entity in steady state" rule, but it is a real, avoidable allocation a
  later pass could remove by reusing `_tileSourceRect`.
- One `Picture` (`recorder.endRecording()`), disposed immediately after
  `toImageSync`.
- One `ui.Image` (`picture.toImageSync(...)`), which persists — tracked via
  `_imagesAlive++` — and is the caller's to dispose (per `_sliceTile`'s own
  doc comment, matching `_bakeBand`'s contract).

This runs only on a resting frame, and only once per tile a band is being
sliced into — bounded by the tile count in one band (an area, not an
entity count), never by the number of entities the band's pixels came
from. It touches no document state and walks no tree, so it is a pure
texture copy exactly as advertised.

## Anything surprising

The main surprise was algebraic, not code: `TileBand.deviceRect.left` is
*defined* (in `TileGrid.bandsFor`) as `band.keys.first.x *
tileDevicePixels` — the same quantity a grid-space mutant would read
directly for the first key. That means the brief's own literal test,
run against the literal unpanned camera it names, can never distinguish
band-local from grid-space on *any* key, because the very definition of
`deviceRect.left` makes the two arithmetically identical whenever a band
starts at grid column 0. The panned group already present in this file
(Task 5/6's fixture, `panX = -50`, `panY = -30`) was the only fixture in
the file where that offset is actually nonzero, so the test was written
there instead of as a standalone block using the brief's exact snippet.
