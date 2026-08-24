# Task 9a report — defect F1 and accepted gap G6, closed together

**STATUS: DONE. F1 CLOSED, G6 CLOSED.**

**Files changed**
- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`
- `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`
- `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`
- `docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md`
  (G6 marked closed, with the mechanism and the measured cost)

---

## 1. The sweep, before and after

The instrument is a scratch test that sweeps the zoom factor from 0.70 to 1.50
in steps of 0.02 — 41 cameras, tile 64 device px, `crossingGrid` — and reports
every factor where `measureTiledAgreement` is not exactly zero. Written, run,
and deleted before the commit.

**Before** (`2d595a1`, my own run, not Task 9's transcript):

```
00:00 +0: F1 sweep 0.70..1.50 step 0.02
BAD factor=0.72 InkReport(live: 15917, tiled: 15547, stray: 0, uncovered: 370, differing: 370)
BAD factor=0.78 InkReport(live: 18064, tiled: 17649, stray: 0, uncovered: 415, differing: 415)
BAD factor=0.82 InkReport(live: 18988, tiled: 18552, stray: 0, uncovered: 436, differing: 436)
BAD factor=1.06 InkReport(live: 17225, tiled: 16698, stray: 0, uncovered: 527, differing: 527)
BAD factor=1.10 InkReport(live: 17447, tiled: 16963, stray: 0, uncovered: 484, differing: 484)
BAD factor=1.22 InkReport(live: 18146, tiled: 17585, stray: 0, uncovered: 561, differing: 561)
SWEEP RESULT: 6 of 41 factors disagree
00:00 +1: All tests passed!
```

**After**, same instrument, unchanged:

```
00:00 +0: F1 sweep 0.70..1.50 step 0.02
SWEEP RESULT: 0 of 41 factors disagree
00:00 +1: All tests passed!
```

**6 of 41 → 0 of 41.**

---

## 2. The change

### One constant, `kTileSlack`

```dart
const double kTileSlack = kScreenClipInflate;
```

It is documented at length where it is defined, and the argument is the one the
brief makes: arrival and invalidation are the same question asked from two
sides, and padding one alone makes them disagree by a ring. `kScreenClipInflate`
is the number because it is the painter's *published* culling slack — "half the
widest stroke the frame can draw" in its own words.

### Arrival — `_bake` pads its cull

```dart
const pad = kTileSlack;
final bake = grid.bakeCameraFor(key).worldToScreenMatrix;
into.save();
into.translate(-pad, -pad);
_drawInto(
    into,
    Size(side + 2 * pad, side + 2 * pad),
    ViewportTransform(
        worldToScreenMatrix: Transform2(
            bake.a, bake.b, bake.c, bake.d, bake.e + pad, bake.f + pad)),
    painter, sink, vertices, origin, (handle) { ... });
into.restore();
```

The **clip is untouched**: `clipRect(0, 0, side, side)` is applied before the
translate, so the tile still keeps exactly the pixels it owns. Only the
painter's *query* widens. That distinction is what stops the wider query
double-inking a seam, and the F1 gate asserts `strayPixels == 0` for exactly
that reason.

### Invalidation — `_worldRectOf` grows the tile by the same slack

```dart
const pad = kTileSlack;
final side = grid._tileLogical;
final left = key.x * side - pad;
final top = key.y * side - pad;
final span = side + 2 * pad;
// ...four corners of that rectangle, inverted through grid.anchor
```

Grown **in screen space, before the inversion**, because the pad is a fact
about stroke widths and stroke widths are a screen-space quantity. A world-space
margin added afterwards would be the wrong size by the camera's scale, and
wrong by different amounts on the two axes under an anisotropic camera.

`_worldBoxOf`'s doc comment, which recorded G6 in as many words, now records
where the remedy lives and why it is not in that method.

---

## 3. The four direction-two assertions

Task 9 reported four assertions in `tile_invalidation_test.dart` reddening
under the bake-only patch. With **both** sides padded, **three of the four went
green with no test change at all** — which is the whole point of the task:

| assertion | what happened |
| --- | --- |
| `criterion 5: a dragged instance drops the tiles it left` — `stale arrival at TileKey(4, 6)` | **Green, unchanged.** It reddened because the arrival oracle (`tilesFor` → `tilesHolding`) started reporting the padded ring while direction two still used the exact rect. Padding direction two makes the two sets agree again, and the assertion means what it always meant. |
| `criterion 5: a dragged group leaves no ghost either` — `stale arrival at TileKey(0, 0)` | **Green, unchanged.** Same cause, same resolution. |
| `criterion 5: the undo of an instance transform ...` — `stale arrival at TileKey(0, 2)` | **Green, unchanged.** Same cause, same resolution. |
| `criterion 5: a leaf edit invalidates its own tiles and no others` — the **fixture guard**, `newTiles.intersection(oldTiles)` `Actual: Set:[TileKey(2, 6), TileKey(2, 7), TileKey(2, 8), TileKey(2, 9)]` | **Fixture moved, assertion untouched.** See below. |

The fourth is not an assertion that gave anything up. It is the file header's
own separability guard: *"unless the edit lands the leaf on tiles it did not
occupy, direction one and direction two cannot be told apart and deleting
either goes unnoticed."* The edit moved leaf 1001 from `(20, 20)-(60, 60)` to
`(100, 20)-(140, 60)` — two tile columns clear, which was enough while a
tile's record held only what its own rectangle enclosed. Each position now
claims a one-tile ring at this rig's 64 device-pixel tile, and the two rings
met on column 2.

**The guard is not loosened; the fixture is moved out**, to
`(150, 20)-(190, 60)`, five columns clear, so the two directions stay exactly
as separable as they were and M1/M2 remain distinct mutants. The change carries
a comment saying so, naming `kTileSlack` as the reason. The test's own
"no more than half the visible set" and "the far side survives" assertions are
untouched and still pass: the drop is 32 of 130 tiles and instance 301's tiles
are four columns clear of the widest ring this edit can condemn.

**Nothing was quietly loosened, anywhere.** The one assertion in the repository
that *tightened* is F1's own, from `uncoveredPixels <= 600` to `== 0`.

---

## 4. The new G6-direction test, red before the change

`criterion 5 / gap G6: a stroke reaching into a tile its geometry misses
invalidates it`, in `tile_invalidation_test.dart`.

**The fixture is arithmetic, not luck.** A vertical line eight tile rows tall
starts in tile column 1 and is moved so its centreline lands at logical screen
x `192.125` — the seam between tile columns 5 and 6 (device x 384) plus an
eighth of a logical pixel. The world x is derived *through the camera*
(`anchor.screenToWorld(Vector2(6 * 32.0 + 0.125, 0)).x`), not written down. Its
stroke is 2 device pixels wide, so it inks device x 383 and 384 — one pixel
each side of the seam. Column 5 owns device x 383 and its exact world rect
stops 0.089 world units short of the centreline.

**The test proves both premises rather than asserting them**, which is what
makes it a G6 test and not a restatement of direction two as it already was:

- *Premise one, the geometry misses.* The test reconstructs the **exact** tile
  world rect — the box direction two used to test — and asserts it does not
  intersect the moved line's box, for every target tile.
- *Premise two, the stroke inks.* It captures the **live** frame (the oracle
  the whole plan is measured against) through a new
  `captureLiveFrame(rig)` helper and asserts device column 383 carries ink
  inside each target tile's row band.

Both premises pass **before** the change, so the failure below is the claim
itself and not a broken fixture:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart
00:00 +0: criterion 5: a leaf edit invalidates its own tiles and no others
00:00 +1: criterion 5: a dragged instance drops the tiles it left
00:00 +2: criterion 5: a dragged group leaves no ghost either
00:00 +3: criterion 6: a group and an instance nested inside a definition
00:00 +4: criterion 5: the undo of an instance transform invalidates both ends
00:00 +5: criterion 6: a definition edit drops the generation, and less does not
00:00 +6: criterion 9: all five change arms, none omitted
00:00 +7: criterion 9: a load starts a new generation, an edit does not
00:00 +8: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it
00:00 +8 -1: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it [E]
  Expected: false
    Actual: <true>
  stale stroke at TileKey(5, 2): the arriving line inks device column 383, which only this tile can write, and the tile still holds the image it had before the edit

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_invalidation_test.dart 542:7              main.<fn>

00:00 +8 -1: criterion 7: a layer edit repaints and drops the generation
00:00 +9 -1: Some tests failed.

Failing tests:
  .../test/tile_invalidation_test.dart: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it
```

Green after the change, with the rest of the file:

```
00:00 +0: criterion 5: a leaf edit invalidates its own tiles and no others
00:00 +1: criterion 5: a dragged instance drops the tiles it left
00:00 +2: criterion 5: a dragged group leaves no ghost either
00:00 +3: criterion 6: a group and an instance nested inside a definition
00:00 +4: criterion 5: the undo of an instance transform invalidates both ends
00:00 +5: criterion 6: a definition edit drops the generation, and less does not
00:00 +6: criterion 9: all five change arms, none omitted
00:00 +7: criterion 9: a load starts a new generation, an edit does not
00:00 +8: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it
00:00 +9: criterion 7: a layer edit repaints and drops the generation
00:00 +10: All tests passed!
```

### The F1 group is now a gate, not a measurement

`group('defect F1: ...')` measured a live defect and bounded it at
`uncoveredPixels <= 600`. It is now
`group('defect F1 stays closed: a stroke centreline just outside a tile still
inks it')`, running the **same six killer factors** and asserting
`uncoveredPixels == 0`, `strayPixels == 0` and `differingPixels == 0`. The
mechanism, the old numbers and the fix are written out above it.

`criterion 1: a settled frame equals the live frame after a zoom` had drawn its
five factors from the clean thirty-five, with the exclusion disclosed. The
exclusion is gone: the list is now six factors and **1.10 and 1.22 are two of
the six killers**, in it deliberately.

---

## 5. Mutants

Both applied to a copy taken beforehand, restored from that copy, and the
restore proved with `diff` producing no output. No `git checkout`.

### M18 — the slack is removed (`kTileSlack = 0.0`)

The un-fix. Three tests red, at both ends of the defect:

```
00:00 +14 -1: .../tile_invalidation_test.dart: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it [E]
  Expected: false
    Actual: <true>
  stale stroke at TileKey(5, 2): the arriving line inks device column 383, which only this tile can write, and the tile still holds the image it had before the edit

00:00 +23 -2: .../tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom [E]
  Expected: <0>
    Actual: <484>
  InkReport(live: 17447, tiled: 16963, stray: 0, uncovered: 484, differing: 484)

00:00 +23 -3: .../tile_cache_test.dart: defect F1 stays closed: ... the six factors that used to lose a stroke column agree exactly [E]
  Expected: <0>
    Actual: <370>
  factor 0.72: a stroke whose centreline sits just outside a tile still inks the pixel column inside it, and no other tile can write that column: InkReport(live: 15917, tiled: 15547, stray: 0, uncovered: 370, differing: 370)

Failing tests:
  .../tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
  .../tile_cache_test.dart: defect F1 stays closed: ... the six factors that used to lose a stroke column agree exactly
  .../tile_invalidation_test.dart: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it
```

Note that criterion 1's zoom test now fires on this mutant at **484 pixels**,
because 1.10 is in its factor list. That is the visible defect, seen by the
criterion that owns it rather than by a group that merely bounds it.

### M19 — the bake is padded, direction two is not

**Task 9's half-fix, and the reason this was one task rather than two.** Five
red:

```
Failing tests:
  .../tile_invalidation_test.dart: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it
  .../tile_invalidation_test.dart: criterion 5: a dragged group leaves no ghost either
  .../tile_invalidation_test.dart: criterion 5: a dragged instance drops the tiles it left
  .../tile_invalidation_test.dart: criterion 5: a leaf edit invalidates its own tiles and no others
  .../tile_invalidation_test.dart: criterion 5: the undo of an instance transform invalidates both ends
```

Exactly Task 9's four, plus the new G6 test. The pixels are correct under this
mutant — the sweep is 0 of 41 — and the *record* is a ring wider than the
geometry that condemns it. Nothing in the repository could see that before this
task, which is why Task 9 was right to stop.

---

## 6. What it costs: the measured over-drop

Instrument: a scratch test that bakes a warm generation over the invalidation
fixture, applies one edit, and reads `invalidationCount`. Run with the slack
in, then with `kTileSlack = 0.0` (copy-restore, `diff` proved), then deleted.

**At the 64 device-pixel tile the tests use** — the worst case, because the ring
is a whole tile there (`kTileSlack` is 32 logical pixels and a 64 device-pixel
tile at `dpr` 2 is 32 logical wide):

| edit | before | after | extra |
| --- | --- | --- | --- |
| leaf move, five columns | 15 of 130 | **32 of 130** | +17 |
| leaf nudge, two world units | 6 of 130 | **12 of 130** | +6 |
| dragged instance | 8 of 130 | **28 of 130** | +20 |
| dragged group | 8 of 130 | **24 of 130** | +16 |

Two to three and a half times as many tiles, and never more than a quarter of
the visible set.

**The ring is a fixed 32 logical pixels, so it shrinks against a larger tile:**

| tile | edit | before | after |
| --- | --- | --- | --- |
| 128 device px | leaf move | 6 of 35 | **10 of 35** |
| 128 device px | dragged instance | 6 of 35 | **8 of 35** |
| 256 device px (production) | leaf move | 4 of 12 | **6 of 12** |
| 256 device px (production) | dragged instance | 4 of 12 | **4 of 12** |

At the production 256 the dragged instance costs **nothing extra at all**, and
the leaf move costs two tiles. The rig's viewport holds only twelve tiles at
that size, so these are a trend rather than a production figure — but the
trend is the right way round, and it is the direction `kTileDevicePixels`
already documents (a 128 px tile bakes 4.00x its area, a 512 px tile 1.56x).

**It is a hit-rate cost, never a correctness one.** A tile dropped that need
not have been is rebaked at the next frame's budget; a tile kept that should
have been dropped is ink a user is looking at.

---

## 7. The whole gate

```
$ cd packages/jet_cad_2d        && CI=true dart test    -> 00:02 +797: All tests passed!
                                   dart analyze         -> No issues found!
                                   dart format --output=none --set-exit-if-changed .
                                                        -> Formatted 113 files (0 changed)
$ cd packages/jet_cad_2d_flutter && CI=true flutter test -> 00:04 +350 ~1: All tests passed!
                                   flutter analyze      -> No issues found! (ran in 3.5s)
                                   dart format --output=none --set-exit-if-changed .
                                                        -> Formatted 62 files (0 changed)
                                   CI=true flutter test --tags golden
                                                        -> 00:04 +35: All tests passed!
```

`+350` against Task 9's `+349`: the one new test is the G6 one. The engine
package is untouched and its 797 are unchanged.

---

## 8. Constraints

- **No golden moved.** `git diff --stat 2d595a1 -- packages/jet_cad_2d_flutter/test/golden`
  produces **no output**. `CI=true flutter test --tags golden` -> 35/35.
- **No `analysis_options.yaml` staged.** `flutter pub get` ran several times
  during this task; `git status --short` before staging listed exactly the five
  files at the top of this report and nothing else. Explicit paths only.
- Every test command prefixed with `CI=true`.
- **No `git checkout` used to revert anything.** Both mutants and both halves of
  the over-drop measurement were applied to a copy taken beforehand, restored
  from that copy, and each restore proved with `diff` producing no output.
- No test output synthesized; every transcript above is pasted from a run.
- **Anti-degenerate.** The new fixture's line spans about eight tile rows, so
  it cannot fit in one tile; the camera is `tileCamera()` and not
  `ViewportTransform.fit`; the viewport holds 130 tiles and the test asserts
  `liveTileCount > 30` before it claims anything. The fixture reaches a
  definition (clause 4) placed four tile columns clear of anything the edit
  condemns, so "and still not a generation drop" is a question the geometry can
  answer.
- **The frame path still allocates nothing per entity in steady state.** The
  padding is inside `_bake`, which is explicitly not a steady-state frame and
  already allocates its `visited` list there; the added `save`/`translate`/
  `restore` and one `ViewportTransform` are O(1) per bake, and bakes are
  budgeted. `paint_allocation_test.dart` and `query_allocation_test.dart` are
  both green.

---

## 9. Deviations

**D1 — `captureLiveFrame` added to `test/support/tile_comparison.dart`.** The
differential gate reduces two captures to counts; the G6 test needs to ask
*where* the ink is, to prove that the stroke really reaches into the tile column
its centreline is not in. Same quantised-camera live arm as
`measureTiledAgreement`, so the two are one drawing seen twice.

**D2 — the F1 group was rewritten rather than left alone.** Its bounds
(`uncoveredPixels <= 600`) still held after the fix, so it would have stayed
green while claiming a defect that no longer exists — a gate that cannot see
what it claims to measure, which is the shape this plan keeps finding. It now
asserts exact zeros on the same six factors.

**D3 — criterion 1's zoom factor list gained the killers.** It excluded the six
and said so; the exclusion is gone and 1.10 and 1.22 are in the list. M18's
transcript shows criterion 1 firing at 484 pixels because of it.

**D4 — the spec's G6 section is marked CLOSED**, with the mechanism, the
6-of-41 → 0-of-41 sweep and the measured over-drop table. G6 was recorded as
"not closable from the tile cache"; that was wrong in one specific way, and the
section now says why: the remedy is not to inflate the *entity's* box by a
resolved lineweight (which would need style resolution the caller does not have,
and would be a different number from the bake's) but to inflate the *tile's*
box by the slack the bake already queries with.

---

## 10. Open

- **The ring is coarse, and deliberately so.** `kTileSlack` is 32 logical
  pixels because that is what `DraftPainter` publishes as its clip inflate —
  "half the widest stroke the frame can draw". A stroke at the *default*
  lineweight is sub-pixel, so almost every edit pays for a worst case it does
  not use. A tighter number is available in principle (resolve the touched
  entity's lineweight, and inflate the bake's cull per tile by the widest
  lineweight the document contains) but it would have to be the **same** number
  on both sides, which means the painter would have to publish it — a change
  to `DraftPainter`, not to the cache. The over-drop table above is the price
  of not doing that, and at the production tile size it is close to nothing.
- **`kScreenClipInflate` is documented as "device pixels" and used as logical
  pixels.** `DraftPainter.paint` compares it against `viewport.width`, which is
  logical, and `kTileDevicePixels`'s own header already reads it as logical
  ("32 *logical* pixels"). The doc comment is wrong; the usage is consistent,
  and on a 2x display the logical reading culls *less*, which is the safe
  direction. Not fixed here — it is a one-word comment change in a file this
  brief does not own, and changing the constant's meaning would change the
  bake's cost. Worth a line in whatever task next touches `draft_painter.dart`.
- **No instrument sees a leaked `ui.Image`.** Unchanged from Task 9; `STATUS.md`
  trap 5 already records it.
