# Task 6 report — the band bake

## What changed

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- New private `TileCache._bakeBand(band, grid, quantised, painter, sink,
  vertices, origin, visitedInto)`, placed immediately after `_bake` and
  modelled on it. It carries the brief's three rules with the brief's wording:
  the query is padded and the clip is not, the clip is hard
  (`doAntiAlias: false`), and the rebase origin is the one passed in.
- New `@visibleForTesting Image debugBakeBand(...)` forwarding to it.

`packages/jet_cad_2d_flutter/test/tile_band_test.dart`
- A `_RecordingPainter extends DraftPainter` that records the camera, the
  viewport `Size` and `debugRebaseOrigin` at the moment `paint` is entered and
  draws nothing.
- A `group('the band bake')` of five tests (see below).

`packages/jet_cad_2d` was not touched.

## One deliberate deviation from the brief's Step 3 — read this

The brief's Step 3 builds the band camera from **`quantised`**:

```dart
final m = quantised.worldToScreenMatrix;
... m.e - band.deviceRect.left / dpr + pad ...
```

That is wrong whenever the frame camera has panned away from the grid's
anchor, and the implementation uses **`grid.anchor`** instead.

The reasoning:

- `TileGrid`'s own class doc: "Tile `(x, y)` occupies device pixels
  `[x*T, (x+1)*T) x [y*T, (y+1)*T)` in the **anchor's** screen space."
  `bandsFor` builds `TileBand.deviceRect` straight out of tile keys, so
  `deviceRect` is in anchor device space.
- `TileGrid.bakeCameraFor(key)` — the single-tile analogue this method is
  modelled on — takes its translation from `anchor`, not from the frame
  camera, for exactly this reason.
- `_gridFor` only re-anchors when the **scale** changes. A pan at constant
  scale keeps the grid and its anchor, and a rest bake happens after pans by
  construction, so `quantised != grid.anchor` is the normal case at a band
  bake, not an edge case.
- The later task cuts tiles out of the band image and stores them under those
  tile keys, blitted with `destRectFor(key, quantised)`. If the band were
  rasterised in frame-camera space and the tiles in anchor space, every sliced
  tile would be offset by the accumulated pan — and that is the exact defect
  the "tiled equals live, zero differing pixels" gate exists to catch, so the
  brief's formula would have gone red one task later with the cause two tasks
  back.

The `quantised` parameter is **kept** in the signature (so the later task's
call site is unchanged) and is used by
`assert(grid.matchesScale(quantised), ...)`, which states the one thing the
frame camera is still required to agree with the anchor about.

If the plan owner intends the brief's literal formula, this is the line to
revisit: `lib/src/tile_cache.dart`, `final m = grid.anchor.worldToScreenMatrix;`
inside `_bakeBand`.

## What was exposed for testing, and why

`TileCache.debugBakeBand`, marked `@visibleForTesting`. Two reasons:

1. `_bakeBand` has no production caller in this task, and `unused_element` is
   reported by `flutter analyze` (which exits non-zero on any issue), so the
   gate cannot go green without a caller.
2. What this task decides is arithmetic — which camera, which query size,
   which origin — and all of it is observable at the moment `_drawInto` calls
   `painter.paint`. The seam lets that be asserted directly instead of through
   the pixel instruments that do not exist until the differential task.

No other production surface was added. The `_RecordingPainter` seam is
test-only and needs nothing from `lib/`: `DraftPainter.paint` is already
overridable and `debugRebaseOrigin` is already a public mutable field that
`_drawInto` sets and clears.

## The tests

In `test/tile_band_test.dart`, `group('the band bake')`. The fixture anchors
the grid at `quantiseCamera(tileCamera(), kTileDpr)` and then pans the *frame*
camera by `(-50, -30)` logical — exactly `(-100, -60)` device pixels at
`kTileDpr = 2`, so the grid's whole-device-pixel invariant holds. That pan puts
the visible key range at `x in 1..14`, `y in 0..10`, and the band under test is
`bands[3]`: `deviceRect.left = 64`, `top = 192`. Neither offset is zero and the
anchor and the frame camera disagree, which is what makes the assertions
non-vacuous.

1. `the fixture puts the band off both axes and off the anchor` — the
   anti-degenerate guard itself, asserted rather than assumed.
2. `the band camera puts a world point at the band-local pixel` — takes world
   `(123.5, 77.25)`, computes where the anchor puts it in logical screen
   pixels, and asserts the band camera puts it there minus the band's logical
   offset plus `kTileSlack`; also asserts the answer is **not** what the frame
   camera's translation would give, and that `a`, `b`, `c`, `d` come through
   untouched.
3. `the padded query reaches kTileSlack past the band on every side` — the
   `Size` handed to `_drawInto` is `width + 2 * kTileSlack` by
   `height + 2 * kTileSlack`, the camera's translation carries `+pad` on both
   axes, and the resulting image is the band's own device size (896 x 64), not
   the padded query's.
4. `every band is rebased against the origin handed in` — bakes the first,
   fourth and last band with one `Vector2(4500000, -3100000)` and asserts all
   three saw `same(origin)`.
5. `the walk reports the handles it touched into visitedInto` — the only one
   that uses the real painter, so the walk actually runs; asserts
   `visitedInto` is non-empty and that every handle in it names something in
   the document.

### Mutation check

Each mutation was applied to `lib/src/tile_cache.dart`, the file run, and the
file restored from a byte copy.

| mutation | result |
|---|---|
| `grid.anchor` -> `quantised` in the band camera | `+6 -2` — tests 2 and 3 red |
| `Size(width + 2*pad, height + 2*pad)` -> `Size(width, height)` | `+7 -1` — test 3 red |
| `origin` -> `Vector2.zero()` at the `_drawInto` call | `+7 -1` — test 4 red |
| drop the pad from both `into.translate` and the camera translation | `+6 -2` — tests 2 and 3 red |

**Not gated here:** `doAntiAlias: false`. A hard clip versus a soft one is a
pixel fact and needs the pixel instruments the differential task owns; there is
no way to see it from the camera arithmetic. Stated rather than quietly
skipped.

**M9 and M11 are not claimed as fired.** Per the controller ruling they belong
to the later task's pixel instruments. Mutation rows 1-4 above are unit-level
gates on the same arithmetic, not substitutes for those two.

## Verbatim RED

Implementation stashed (`git stash push -- .../tile_cache.dart`), test file in
place:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart: test/tile_band_test.dart:147:31: Error: The method 'debugBakeBand' isn't defined for the type 'TileCache'.
   - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'debugBakeBand'.
        final image = rig.cache.debugBakeBand(band, grid, frame, painter,
                                ^^^^^^^^^^^^^
  test/tile_band_test.dart:188:31: Error: The method 'debugBakeBand' isn't defined for the type 'TileCache'.
   - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'debugBakeBand'.
        final image = rig.cache.debugBakeBand(band, grid, frame, painter,
                                ^^^^^^^^^^^^^
  test/tile_band_test.dart:219:33: Error: The method 'debugBakeBand' isn't defined for the type 'TileCache'.
   - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'debugBakeBand'.
          final image = rig.cache.debugBakeBand(each, grid, frame, painter,
                                  ^^^^^^^^^^^^^
  test/tile_band_test.dart:233:31: Error: The method 'debugBakeBand' isn't defined for the type 'TileCache'.
   - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'debugBakeBand'.
        final image = rig.cache.debugBakeBand(band, grid, frame, rig.painter,
                                ^^^^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart
```

## Verbatim GREEN

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_band_test.dart
00:00 +0: the bands partition the visible keys, in row order, without gaps
00:00 +1: a band is one tile tall and the full union width
00:00 +2: the union overhangs the viewport, and the bands carry the overhang
00:00 +3: the band bake the fixture puts the band off both axes and off the anchor
00:00 +4: the band bake the band camera puts a world point at the band-local pixel
00:00 +5: the band bake the padded query reaches kTileSlack past the band on every side
00:00 +6: the band bake every band is rebased against the origin handed in
00:00 +7: the band bake the walk reports the handles it touched into visitedInto
00:00 +8: All tests passed!
```

## The gate — whole package, not one file

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
...
00:07 +391 ~1: 1 skipped test.
00:07 +391 ~1: All other tests passed!

Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)

Formatted 69 files (0 changed) in 0.12 seconds.
```

391 passing, 1 skipped (pre-existing), 0 failing. The first run of the gate
after the edit reported `Changed lib/src/tile_cache.dart` and
`Changed test/tile_band_test.dart` from `dart format`; both were formatted and
the gate re-run in full, output above.

`git status --porcelain` before staging showed only the two intended files —
no `analysis_options.yaml` rewrite this time, though `flutter test` did run
`pub get`.

## What `_bakeBand` allocates

Per call — a bake, not a steady-state frame, so this is allowed and is stated
rather than hidden:

- one `PictureRecorder` and one `Canvas`,
- three `Rect`s (the clip rect, and `band.deviceRect`'s field reads are free)
  and one `Size`,
- one `Transform2` for the band camera, plus one `ViewportTransform` whose
  constructor inverts it into a second `Transform2`,
- one closure for the `onVisit` callback,
- one `Picture` (disposed immediately) and one `Image` (returned; the caller
  owns it, and `_imagesAlive` is incremented for the byte meter exactly as
  `_bake` does),
- growth of the caller's `visitedInto` list: one `int` per visited handle,
  amortised. This is the same per-entity allocation `_bake` already makes, on
  the same bake path.

Nothing is allocated per entity in the frame path's steady state, because
`_bakeBand` is not on it.

## Notes for the next task

- **`_bakeBand` has no production caller.** `debugBakeBand` is its only caller
  and is what keeps the analyzer quiet. When the band bake is wired into
  `paintFrame`, `debugBakeBand` can stay (the arithmetic tests use it) or be
  removed with those tests rerouted; it must not simply be deleted while the
  tests still reference it.
- `_bakeBand` does **not** increment `_bakes`, matching the brief. If the
  band bake should count against `bakeCount`, that is a decision for the
  wiring task.
- `_bakeBand` does not write `_baked`; it fills `visitedInto` instead, and the
  owner climb `_bake` performs is deliberately absent so the caller can do it
  once per band rather than once per tile.
- The returned image increments `_imagesAlive` and is not registered in
  `_tiles`, so whoever calls it owns the dispose. The tests dispose theirs via
  `addTearDown`.
