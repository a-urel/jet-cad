# Task 10 report — criterion 10: an edit after a settle invalidates

## What changed

| File | Change |
|---|---|
| `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` | `kMovableHandle`; `bandCrossingGrid` gains a group + leaf at its resting position. |
| `packages/jet_cad_2d_flutter/test/support/tile_harness.dart` | `TiledHarness.moveOneEntityOntoDisjointTiles()`. |
| `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart` | new test: `an edit after a sliced settle condemns the sliced tiles`; `import 'support/tile_harness.dart';`. |
| `docs/superpowers/notes/plan-3i-mutation-log.md` | **M5**. |

No production file changed: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
is byte-identical to `HEAD` (diffed against a copy taken before firing M5, and
`git status` shows it clean).

## The two helpers, and why they live beside `bandCrossingGrid`

The brief called `h.moveOneEntityOntoDisjointTiles()` and `kMovableHandle`
without either existing. `TransformNodeCommand.apply` (`commands.dart:292-300`)
only accepts a handle already in `DraftDocument.tree` — a `GroupNode` or an
`InstanceNode` — so `kMovableHandle` names a **group**, not a bare leaf, added
to `bandCrossingGrid` itself:

```dart
addGroup(doc, doc.rootHandle, kMovableHandle,
    Transform2(1, 0, 0, 1, worldX(80), worldY(144)));
addLine(doc, kMovableHandle, Handle(handle++), 0, 0, 6, 6);
```

`moveOneEntityOntoDisjointTiles` (`tile_harness.dart`) replaces its transform
absolutely — `TransformNodeCommand` replaces, it does not compose:

```dart
void moveOneEntityOntoDisjointTiles() {
  double worldX(double screenX) => (screenX + 37.0) / 1.4;
  double worldY(double screenY) => (323.0 - screenY) / 1.4;
  document.commands.execute(TransformNodeCommand(
      kMovableHandle, Transform2(1, 0, 0, 1, worldX(300), worldY(48))));
}
```

## The coordinates of the move, and the arithmetic showing the two tile sets are disjoint

`tileCamera()` maps `sx = 1.4 wx - 37`, `sy = -1.4 wy + 323`. A 64 device-pixel
tile at `kTileDpr` (2) is 32 logical pixels, and this test never pans or zooms,
so the grid anchor is the camera itself and tile `(x, y)` covers logical screen
`[32x, 32x+32) × [32y, 32y+32)`.

**Resting position — screen (80, 144).** `worldX(80) = 117/1.4 =
83.571428571…`, `worldY(144) = 179/1.4 = 127.857142857…`. Tile column 2 spans
logical x `[64, 96)`; row 4 spans logical y `[128, 160)`. 80 sits 16 px inside
the column, 144 sits 16 px inside the row. The leaf's local `(0,0)-(6,6)`
diagonal moves the far endpoint to screen `(80 + 1.4·6, 144 − 1.4·6) = (88.4,
135.6)` — still inside the same tile (88.4 < 96, 135.6 > 128) — so the whole
entity rests in tile `(2, 4)` alone, with 7.6–16 logical pixels of margin on
every side, clear of `kTileSlack`'s one-tile ring.

**Destination — screen (300, 48).** `worldX(300) = 337/1.4 =
240.714285714…`, `worldY(48) = 275/1.4 = 196.428571429…`. Tile column 9 spans
logical x `[288, 320)`; row 1 spans logical y `[32, 64)`. The far endpoint
lands at `(308.4, 39.6)`, again inside the same tile `(9, 1)`.

**Disjointness.** `(2, 4)` and `(9, 1)` are seven columns and three rows
apart — far beyond `kTileSlack`'s one-tile ring on either side. The test does
not merely assert this by construction; it measures it: `oldTiles` is read
from the harness's own settled `_baked` record (`h.cache.tilesHolding
(kMovableHandle)`) and `newTiles` from a fresh oracle over the post-edit
document (`tilesFor(h.document, kMovableHandle)`, the same "direction two"
oracle every earlier test in this file uses), and `newTiles.intersection
(oldTiles)` is asserted empty before anything about invalidation is checked.

## A fixture defect found and fixed before M5 would gate anything

The brief's own test sketch uses a plain `settle(t, h)` for the first settle.
Writing the test that way and running it, M5 (see below) **did not** turn it
red — the counter and pixel assertions both passed with `_baked[key] =
record;` deleted. Diagnosing this with a throwaway probe
(`debugOnSliceForTest`, since deleted) on `bandCrossingGrid` under a plain
`settle`:

```
plain settle:     liveTileCount=130 slices=2   bakeCount=138
settleFromBands:  liveTileCount=130 slices=130 bakeCount=148
```

At this harness's default budget (`kBakeBudgetDevicePixels`, 64 tiles of 64
device pixels per frame against a 130-tile viewport), the ordinary per-tile
`_bake` path — which has its own, separate `_baked[key] = Uint32List.fromList
(visited);` write at `tile_cache.dart:1949`, untouched by M5 — bakes 128 of
130 tiles across the first two frames, before the rest gate ever arms at
`_restGateSteps >= kRestGateFrames`. The rest bake then finds only 2 keys
missing, in the bottom-right corner — exactly what `settleFromBands`'s own doc
comment in `tile_harness.dart` says. `kMovableHandle`'s resting tile, column
2 row 4, is nowhere near that corner, so a test built on a plain `settle`
reads `_baked[key]` written by the untouched per-tile path and the mutation
under test is never reached. This is the same "fixture guard" failure mode
`tile_invalidation_test.dart`'s own header warns about, one level removed: not
a superset/subset tile-set problem, but the settle mechanism silently routing
around the very code path the test exists to gate.

Fixed by using `settleFromBands(t, h)` — already built in Task 8/9's own
`tile_harness.dart` for exactly this purpose — for the first settle, which
forces a table edit that drops every tile at the unmoved camera so the next
frame's rest bake slices the **whole** viewport. The test asserts this
directly rather than trusting it: `expect(slices, tilesBefore, ...)`, i.e. 130
of 130 sliced, so `kMovableHandle`'s tile is necessarily among them. No
assertion about invalidation or pixels was loosened or removed; only the
settle helper used to reach the starting state changed.

## RED (Step 2, before the fixture fix — plain `settle`)

Not separately preserved verbatim: this was the exploratory run that led to
the `settleFromBands` fix above, superseded by the fixed test's own RED under
M5 below. The observed failure with a plain `settle` was the suite passing
outright with `_baked[key] = record;` deleted — i.e. **M5 survived**, which is
what triggered the investigation into which tiles the settle had actually
sliced.

## GREEN — the finished test, unmutated code

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart
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
00:00 +10: an edit after a sliced settle condemns the sliced tiles
00:00 +11: All tests passed!
```

## M5 — the mutation, and its RED

**Mutation:** delete `_baked[key] = record;` from the resting branch's slice
loop in `_bakeBand`'s caller (`tile_cache.dart:1212`), leaving every sliced
tile with no `_baked` record at all.

**Procedure:** copied `tile_cache.dart` aside first (never `git checkout`),
applied the one-line deletion, ran the new test, restored from the copy and
diffed to confirm the restore was byte-exact.

**Result: RED**, and red for the intended reason — `kMovableHandle` is
unfindable in the settled cache at all (`h.cache.tilesHolding(kMovableHandle)`
returns empty), because its tile carries no `_baked` record for anything, not
only none for the moved entity.

**Verbatim output:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart
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
00:00 +10: an edit after a sliced settle condemns the sliced tiles
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: non-empty
  Actual: Set:[]
the movable entity must be findable in the settled cache

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart:690:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart line 690
The test description was:
  an edit after a sliced settle condemns the sliced tiles
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +10 -1: an edit after a sliced settle condemns the sliced tiles [E]
  Test failed. See exception logs above.
  The test description was: an edit after a sliced settle condemns the sliced tiles

00:00 +10 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: an edit after a sliced settle condemns the sliced tiles
```

After restoring the file, `test/tile_invalidation_test.dart` was re-run and
confirmed GREEN again (identical to the GREEN transcript above), and
`git diff packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` showed no
changes.

## The gate — full package, verbatim

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:06 +400 ~1: All tests passed!
```

(The one `~1` is a pre-existing, intentionally-tagged `rig` test —
`Skip: run explicitly: flutter test --tags rig --run-skipped` — unrelated to
this task; unchanged from before this task's edits.)

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
```

```
$ cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
Formatted 71 files (0 changed) in 0.13s
```

(`dart format` was run once without `--output=none` first to actually apply
formatting to the new test — it reformatted `test/tile_invalidation_test.dart`
— and the check above was the confirming re-run afterward.)

`git status` after all edits shows only the three test-support files touched;
`analysis_options.yaml` is not staged or modified.

## Pre-existing tests changed

None. Every existing test in `tile_invalidation_test.dart` and every other
file in the package suite is untouched; only the new test and its two support
helpers were added.
