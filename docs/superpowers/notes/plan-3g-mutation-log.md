# Plan 3g — mutation log

Spec: `docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md`
Plan: `docs/superpowers/plans/2026-08-23-jet-cad-2d-plan-3g-tile-cache.md`
Results: `docs/superpowers/notes/2026-08-24-plan-3g-results.md`

Every transcript below is copied from the task report that produced it, in
`docs/superpowers/ledgers/` (archived from
`.superpowers/sdd/2026-08-23-jet-cad-2d-plan-3g-tile-cache/`). Nothing here was
re-run for this note and nothing here was reconstructed. Where a report gave a
summary rather than a transcript, this log says so in those words rather than
inventing one.

Method, uniform across every task: the file was copied aside, mutated in place,
run, restored **from the copy** — never `git checkout` — and the restore proved
with `diff` producing no output. Several reports print `RESTORE CLEAN` or
`RESTORED CLEAN`, which is that `diff`.

## Numbering, and two collisions worth naming

The spec named **M1–M17**. Execution added **M18** (the slack removed) and
**M19** (the bake padded and direction two not), both landed in the spec's own
table. Individual tasks then minted mutants of their own, and two of those
labels collide with labels already in use:

- **Task 9's fix-round report calls the call-site-local composite `Paint`
  mutant "M18".** The spec's M18 is the slack removal from Task 9a. They are
  different mutants. This log records the composite-`Paint` one as **M-Q** and
  leaves M18 to the spec.
- **Task 7's fix-round report calls its three gating mutants "G1", "G2" and
  "G3".** The spec's G1–G6 are accepted gaps. This log records them as **M-J**,
  **M-K** and **M-L**.

Locally-minted mutants that carried a label in their report keep it (`M8b`,
`M8c`, `M8d`, `M12b`, `M-B`…`M-H`). Those that carried none are given one here,
with the report they came from named alongside.

| label | mutant | task | outcome |
|---|---|---|---|
| M1 | old-position invalidation direction deleted | 7 | red, 3 tests (4 after the C1 fix) |
| M2 | new-position invalidation direction deleted | 7 | red, 3 tests (4 after the C1 fix) |
| M3 | `doAntiAlias: true` on the tile clip | — | **NOT FIRED — unfirable in this instrument.** See below |
| M4 | `TileGrid.matchesScale` returns `true` always | 9 | red, 6 tests |
| M5 | `_isDefinitionOwned` always false | 7 | red, 2 tests |
| M6 | the eviction call deleted | 10 | red, 4 tests |
| M7 | clip each tile to the viewport instead of its own rect | 12 | **FIRED on device, killed nothing** — no green-to-red transition exists. See below |
| M8 | the table `Listenable` dropped from `_repaint` | 8 | red, 2 tests |
| M8b | the merge kept, the generation drop deleted | 8 | red, 1 assertion |
| M8c | the adapter disposes without unsubscribing | 8 | red |
| M8d | `didUpdateWidget` stops watching `tiles`/`tileDevicePixels` | 8 | red |
| M9 | the bake budget ignored | 9 | red, 5 tests |
| M10 | the rounding deleted from `quantiseCamera` | 3 | red, 2 of 8 |
| M11 | blit with `BlendMode.src` | 6 | **survived every criterion**; killed by a new test |
| M12 | the `CommandRedone` arm deleted | 7 | **compile error, not a red test** |
| M12b | the `CommandRedone` arm present and doing nothing | 7 | red, criterion 9 only |
| M13 | the blit `Paint` built at the `drawImageRect` call site | 4 | **survived the identity getter**; killed by a canvas spy |
| M14 | text skipped in a bake | 6 | red, criterion 3 (at a different assertion than predicted) |
| M15 | the bake camera offset by one device pixel | 5 | red, criteria 1 and 2 |
| M16 | the node call sites removed from the painter | 7 | red, 3 tests (4 after the C1 fix) |
| M17 | the injected rebase origin dropped | 1, 5 | **not killed by criterion 1**; killed by a wiring test |
| M18 | `kTileSlack = 0.0` | 9a | red, 3 tests |
| M19 | the bake padded, direction two not | 9a | red, 5 tests |
| M-A | `_floorDiv` → `~/` | 3 | survived the brief's test; killed after the test was fixed |
| M-B | the "not this frame" eviction guard deleted | 10 | red |
| M-C | eviction removes the tile without disposing the image | 10 | red |
| M-D | the uncovered region no longer accumulated | 10 | red |
| M-E | `_blitDestinations++` deleted (tile blit) | 10 | survived criterion 13 as briefed; killed by a new test |
| M-F | the composite becomes an eviction victim | 10 | red, 2 tests |
| M-G | a sub-composite ceiling bakes anyway | 10 | red, 3 tests |
| M-H | `_blitDestinations++` deleted (composite blit) | 10 | red |
| M-J | the owner-chain walk reverted (a dragged group) | 7 fix 1 | red, 2 tests |
| M-K | `_enclosingDefinition`'s climb reduced to its first line | 7 fix 1 | red |
| M-L | `DocumentPurged` downgraded to `_dropGeneration` | 7 fix 1 | red |
| M-M | one device pixel of error in `TileGrid.destRectFor` | 6a | red, 3 tests |
| M-N | alpha on the blit paint | 6a, 6 fix 1 | red, in both places |
| M-P | `style_resolver` drops `transparency` | 6 fix 1 | red |
| M-Q | the composite `Paint` built at the call site | 9 fix 1 | red |
| M-R | `budgetedTilesPerFrame` truncating to zero | 11a fix 1 | red — **no transcript in the report** |

**Forty-one mutants named. Forty fired. One — M3 — was not, and it has its own
section saying why. M7 *was* fired, on device, and killed nothing: it has its own
section saying why that is worse than not firing it.**

---

# M1 — delete the old-position direction of invalidation

*Task 7. `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`.*

**The edit.** Deleted the `for (final entry in _baked.entries)` block outright.

**Command.** `CI=true flutter test test/tile_invalidation_test.dart`

**Red:**

```
00:00 +0 -1: criterion 5: a leaf edit invalidates its own tiles and no others [E]
  Expected: false
    Actual: <true>
  old position, TileKey(0, 7)
  test/tile_invalidation_test.dart 121:7              main.<fn>

00:00 +0 -2: criterion 5: a dragged instance drops the tiles it left [E]
  Expected: false
    Actual: <true>
  ghost at TileKey(0, 3)
  test/tile_invalidation_test.dart 171:7              main.<fn>

00:00 +0 -3: criterion 5: the undo of an instance transform invalidates both ends [E]
  Expected: false
    Actual: <true>
  ghost at TileKey(5, 7)
  test/tile_invalidation_test.dart 207:7              main.<fn>

00:00 +3 -3: Some tests failed.
```

**Restored.** The report records "Restored, `RESTORE CLEAN`, six green" — the
`diff` produced no output and the file went back to six passing tests. The
report gives no separate green transcript for this mutant; the file's green run
is the Step 5 passing run recorded in the same report.

**Re-fired after the C1 fix** (the fix changes what `_baked` contains, so every
round-1 kill was re-run rather than assumed): still red, and now on one more
test — the leaf edit, the dragged instance, the **dragged group** and the undo.

---

# M2 — delete the new-position direction of invalidation

*Task 7.*

**The edit.** The direction-two sweep replaced by a call kept behind
`grid.tileDevicePixels < 0`, so `_worldRectOf` stays referenced and the mutant
is the missing *sweep* rather than an unused-method analyzer error.

**Command.** `CI=true flutter test test/tile_invalidation_test.dart`

**Red:**

```
00:00 +0 -1: criterion 5: a leaf edit invalidates its own tiles and no others [E]
  Expected: false
    Actual: <true>
  new position, TileKey(3, 7)
  test/tile_invalidation_test.dart 126:7              main.<fn>

00:00 +0 -2: criterion 5: a dragged instance drops the tiles it left [E]
  Expected: false
    Actual: <true>
  stale arrival at TileKey(5, 7)
  test/tile_invalidation_test.dart 174:7              main.<fn>

00:00 +0 -3: criterion 5: the undo of an instance transform invalidates both ends [E]
  Expected: false
    Actual: <true>
  stale arrival at TileKey(0, 3)
  test/tile_invalidation_test.dart 210:7              main.<fn>

00:00 +3 -3: Some tests failed.
```

**Restored.** `RESTORE CLEAN`.

**Why M1 and M2 are separable at all, and this is the load-bearing part.** The
brief's fixture edit was a *shrink*, which makes the new tile set a subset of
the old: M2 survives it. The obvious repair — an *extension* — makes the new set
a superset: M1 survives that. **Only a move separates them**, and every
direction test now asserts at runtime that the two sets are disjoint before it
asserts anything about invalidation.

---

# M3 — `doAntiAlias: true` on the tile clip

## NOT FIRED. The instrument cannot produce the artefact M3 would create.

This is not a pass. It is a mutant that was never run, and it is recorded here
so that no coverage claim rests on it.

`packages/jet_cad_2d_flutter/test/drawvertices_antialiasing_test.dart` pins that
**`flutter_test`'s software Skia does not antialias `drawVertices` at all** —
that file's own words are "a fact about `flutter_test`'s software Skia, not
about this codebase." M3 turns antialiasing on for the tile clip. An instrument
that antialiases nothing cannot render the difference, so the mutant would run
green for a reason that has nothing to do with the code under test.

**What is gated instead.** Criterion 2 proves *geometric* completeness — no
pixel missing, none drawn twice, no clipping arithmetic error — and **M15 fires
it**, because a bake camera offset by one device pixel moves pixels software
Skia renders and compares perfectly well.

**What is still owed.** That Impeller honours a non-antialiased clip exactly on
the device pixel grid. That is accepted gap **G1**, and it is owed and not
delivered by this plan. A green criterion 2 is not a settled seam.

**Recorded as deferred, not as coverage.** An earlier draft of the spec counted
M3 toward a coverage claim two sections after conceding it was unfirable. That
is the Plan 3f.1 defect this plan exists partly to avoid repeating.

---

# M4 — `TileGrid.matchesScale` returns `true` always

*Task 9. Drops `scaleGeneration` from the key in effect.*

**The edit:**

```
   bool matchesScale(ViewportTransform camera) {
-    final a = anchor.worldToScreenMatrix;
-    final b = camera.worldToScreenMatrix;
-    return a.a == b.a && a.b == b.b && a.c == b.c && a.d == b.d;
+    return true; // M4
   }
```

**Command.** `CI=true flutter test test/tile_cache_test.dart`

**Red:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
00:00 +8: criterion 3: text survives the tile round trip
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +10: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own
00:00 +11: criterion 8: a pan drops nothing and a scale change drops everything
00:00 +11 -1: criterion 8: a pan drops nothing and a scale change drops everything [E]
  Expected: <2>
    Actual: <1>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 389:5                     main.<fn>
  
00:00 +11 -1: a zoom gesture blits the carry-over and bakes nothing
00:00 +11 -2: a zoom gesture blits the carry-over and bakes nothing [E]
  Expected: <8>
    Actual: <0>
  one composite blit per gesture frame
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 412:5                     main.<fn>
  
00:00 +11 -2: the gesture frame the carry-over serves is not blank
00:00 +11 -3: the gesture frame the carry-over serves is not blank [E]
  Expected: <0>
    Actual: <130>
  the new generation holds nothing, so the ink below cannot have come from a tile
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 443:5                     main.<fn>
  
00:00 +11 -3: the settle spreads its bakes across frames
00:00 +11 -4: the settle spreads its bakes across frames [E]
  Expected: <12>
    Actual: <16>
  and every bake was kept, so 12 is a throttle rather than a recount of four tiles rebaked three times
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 465:5                     main.<fn>
  
00:00 +11 -4: criterion 1: a settled frame equals the live frame after a zoom
00:00 +11 -5: criterion 1: a settled frame equals the live frame after a zoom [E]
  Expected: <0>
    Actual: <19471>
  InkReport(live: 16310, tiled: 19903, stray: 19471, uncovered: 15878, differing: 35349)
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/support/tile_comparison.dart 139:3             expectTiledEqualsLive
  
00:00 +11 -5: defect F1: a stroke centreline just outside a tile is culled from it the loss is one stroke column, and it is ink lost rather than moved
00:00 +12 -5: a whole-document change clears the carry-over as well as the tiles
00:00 +12 -6: a whole-document change clears the carry-over as well as the tiles [E]
  Expected: true
    Actual: <false>
  Instance of 'DocumentLoaded': the floor -- there must be a composite to clear
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 585:7                     main.<fn>
  
00:00 +12 -6: a table edit drops the generation without minting a carry-over
00:00 +13 -6: accepted gap: near-axis strokes displace a bounded number of pixels the ten-line fan stays inside the bound
00:00 +14 -6: accepted gap: near-axis strokes displace a bounded number of pixels the worst single slope measured stays inside the bound
00:00 +15 -6: accepted gap: near-axis strokes displace a bounded number of pixels the same camera and tile size agree exactly on axis-aligned ink
00:00 +16 -6: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a whole-document change clears the carry-over as well as the tiles
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a zoom gesture blits the carry-over and bakes nothing
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 8: a pan drops nothing and a scale change drops everything
  ... and 2 more
```

**The two the criteria name.** Criterion 8 reads `Expected: <2> Actual: <1>` — a
scale change no longer starts a generation. Criterion 1 after a zoom reads
**35,349 differing pixels of 480,000** against a criterion that demands zero: the
generation is replayed at the old scale, so old stroke widths, old dash phase,
wrong destinations. **No pan test in this repository can see this, because a pan
cannot change a scale.**

**Restored green:**

```
00:00 +22: All tests passed!
```

Restored from a copy and proved by `diff` (no diff).

---

# M5 — `_isDefinitionOwned` always false

*Task 7.* `if (true) return null;` at the top of `_enclosingDefinition`.

**Command.** `CI=true flutter test test/tile_invalidation_test.dart`

**Red:**

```
00:00 +3 -1: criterion 6: a definition edit drops the generation, and less does not [E]
  Expected: <0>
    Actual: <121>
  a definition edit changes every instance of it, so tile-level invalidation by definition is exact rather than coarse
  test/tile_invalidation_test.dart 234:5              main.<fn>

00:00 +3 -2: criterion 9: all five change arms, none omitted [E]
  Expected: <0>
    Actual: <122>
  test/tile_invalidation_test.dart 265:5              main.<fn>

00:00 +4 -2: Some tests failed.
```

`121` and `122` rather than `130` is the tell: without the definition path the
per-tile path still drops the eight or nine tiles the edited leaf occupies, and
leaves every other instance of the block stale.

**Restored.** `RESTORE CLEAN`. Re-fired after the C1 fix: still red, on
criterion 6 (both tests) and criterion 9.

---

# M6 — ignore the LRU cap

*Task 10. The eviction call deleted.*

**The edit, and the `diff` that proves it applied:**

```
$ cp .../tile_cache.dart $SP/tile_cache.orig.dart
$ perl -0pi -e 's/if \(image == null && budget > 0 && _makeRoomForOneTile\(\)\) \{/if (image == null && budget > 0) {/' .../tile_cache.dart
$ diff $SP/tile_cache.orig.dart .../tile_cache.dart
622c622
<       if (image == null && budget > 0 && _makeRoomForOneTile()) {
---
>       if (image == null && budget > 0) {
```

**Command.** `CI=true flutter test test/invariants/tile_budget_test.dart`

**Red:**

```
00:00 +0: loading .../test/invariants/tile_budget_test.dart
00:00 +0: criterion 12: the cap holds and eviction is real, not theoretical
00:00 +0 -1: criterion 12: the cap holds and eviction is real, not theoretical [E]
  Expected: a value less than or equal to <131072>
    Actual: <2129920>
     Which: is not a value less than or equal to <131072>
  pan 0

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/invariants/tile_budget_test.dart 61:7          main.<fn>

00:00 +0 -1: criterion 12: a pan back to reclaimed tiles draws live, not blank
00:00 +1 -1: criterion 13: allocation is viewport-bounded and the Paint is one
00:00 +2 -1: criterion 12: liveBytes counts the composite, not only the tiles
00:00 +3 -1: criterion 12: eviction never reclaims a tile this frame blitted
00:00 +3 -2: criterion 12: eviction never reclaims a tile this frame blitted [E]
  Expected: <8>
    Actual: <130>
  setup: the cap is full, which is the state the guard is about. A frame that stopped short of it would never ask.
...
00:00 +3 -4: Some tests failed.

Failing tests:
  ...: criterion 12: a frame at the cap still equals the live frame
  ...: criterion 12: eviction disposes what it reclaims
  ...: criterion 12: eviction never reclaims a tile this frame blitted
  ...: criterion 12: the cap holds and eviction is real, not theoretical
```

Four tests die; the cap assertion reads **16.2× over the ceiling** — 2,129,920 B
against 131,072 B.

**Restored:**

```
$ cp $SP/tile_cache.orig.dart .../tile_cache.dart && diff $SP/tile_cache.orig.dart .../tile_cache.dart
RESTORED CLEAN
```

**Green, restored (the whole file):**

```
00:00 +0: loading .../test/invariants/tile_budget_test.dart
00:00 +0: criterion 12: the cap holds and eviction is real, not theoretical
00:00 +1: criterion 12: a pan back to reclaimed tiles draws live, not blank
00:00 +2: criterion 13: allocation is viewport-bounded and the Paint is one
00:00 +3: criterion 13: and the destination count is a live reading, not a zero
00:00 +4: criterion 12: liveBytes counts the composite, not only the tiles
00:00 +5: criterion 12: eviction never reclaims a tile this frame blitted
00:00 +6: criterion 12: a frame at the cap still equals the live frame
00:00 +7: criterion 12: eviction disposes what it reclaims
00:00 +8: All tests passed!
```

**What M6 revealed, and it is the reason three more tests exist.** The brief's
second test — `a pan back to reclaimed tiles draws live, not blank` — **stays
green under M6, i.e. with no cap at all.** At a budget of two tiles against a
130-tile viewport the frame never covers, so `liveDrawCount > 0` is true on the
very first frame, before a single eviction. The test cannot distinguish "the
camera came back over reclaimed tiles and the walk covered them" from "the
budget never covered anything". The test was kept verbatim and a companion added
that makes the same journey and compares pixels.

---

# M7 — clip each tile to the viewport instead of to its own rect

## FIRED on device, Task 12. Killed nothing. There is no green-to-red transition anywhere in this suite.

This is the worst outcome available. M3 could not be fired; M7 *was* fired,
twice, and the suite did not notice.

The spec named M7 **"the mutation that passes every correctness gate and
destroys the plan's entire reason for existing"** and said **"a suite that
cannot kill it is not gating this plan"**. That sentence stands, and this suite
does not kill it. It is accepted gap **G7**.

**The edit** (`git diff` before the restore):

```diff
@@ -724,7 +724,7 @@ class TileCache {
       if (image == null && budget > 0 && _makeRoomForOneTile()) {
-        image = _bake(key, grid, painter, sink, vertices, origin);
+        image = _bake(key, grid, painter, sink, vertices, origin, viewport);
@@ -1353,6 +1353,7 @@ class TileCache {
     Vector2 origin,
+    Size viewport,
   ) {
@@ -1365,7 +1366,10 @@ class TileCache {
-    into.clipRect(Rect.fromLTWH(0, 0, side, side), doAntiAlias: false);
+    // M7: clip each tile to the viewport instead of to its own rect.
+    into.clipRect(
+        Rect.fromLTWH(0, 0, viewport.width, viewport.height),
+        doAntiAlias: false);
@@ -1407,7 +1411,7 @@ class TileCache {
     _drawInto(
         into,
-        Size(side + 2 * pad, side + 2 * pad),
+        Size(viewport.width + 2 * pad, viewport.height + 2 * pad),
```

**Both expressions of "its own rect" had to change**, and that is worth its own
sentence. The clip alone is not the mutant the spec describes: `_drawInto`'s
`Size` argument is what the painter culls against, so widening only the clip
would have left every bake walking the same leaves it walks today — **a no-op
that would have reported "M7 changes nothing" for entirely the wrong reason.**

**The mutant was demonstrably live**, on fields that count actual drawing and
independently of any timing: `triangles` **734442 → 1183035** (+61%) and
`canvasCalls` **97 → 150**, identically in both M7 runs.

## What it moved, and what it did not

| reading | clean (median of 3) | M7 run A | M7 run B | verdict |
|---|---|---|---|---|
| criterion 10, hold p50 | 1.58 | 1.47 | 1.24 | **unchanged** |
| criterion 10, hold p95 | 1.96 | 1.75 | 2.32 | **unchanged** |
| criterion 11, pan p95 | 35.67 | 49.90 | 63.62 | 1.4×–1.8× worse |
| criterion 11, pan max | 65.77 | 89.13 | 90.03 | 1.35× worse |
| R2 build p50 | 23.10 | 38.47 | 39.04 | 1.67× worse |
| R2 total p50 | 41.09 | 56.76 | 58.19 | 1.4× worse |

**Criterion 10 is structurally blind to M7, and no threshold could fix that.**
The settled frame bakes nothing — `bakeFrames=0/60` in every run, clean and
mutated alike — so **the clip M7 breaks is never executed in the frame criterion
10 measures.** The hold column under M7 sits inside the clean run-to-run spread.

**Criterion 11 degraded but did not turn red, because it was already red.**
35.67 ms clean against a 16.67 ms threshold, before any mutation. A criterion
that fails on clean source cannot distinguish the mutant from the original.

Criteria 1–9, 12 and 13 pass under M7 **by construction**: the blit shows only a
tile's own rect and `toImageSync` crops the rest, so the pixels are identical
and only the work differs.

**M7 run A, verbatim** (its shell was backgrounded mid-build; see below):

```
flutter: R2 (500000) frames=242
flutter:   build  p50=38.47ms p95=44.59ms max=1462.95ms mean=30.39ms
flutter:   raster p50=9.17ms p95=42.76ms max=144.74ms mean=13.92ms
flutter:   total  p50=56.76ms p95=89.36ms max=1721.78ms mean=53.09ms
flutter:   screenSpaceLeafCount=4612 dashSpans=146358 collapsed=345 canvasCalls=150 (…)
flutter:   tiles=on tilePx=512 bakeBudgetPx=262144 bakeBudgetTiles=1 liveTiles=2 generation=122 carryOver=true
flutter:   bakes=148 blits=1651 carryOverBlits=121 liveDraws=135 blitDests=3197 evictions=0(life) invalidations=0(life) tileBytes=9777152
flutter:   backend=vertices triangles=1183035 drawVerticesCalls=42
flutter:   tile warm: frames=11 liveTiles=12 tileBytes=12582912 evictions=0(life)
flutter:   tile hold frames=60
flutter:   build  p50=0.30ms p95=0.40ms max=0.44ms mean=0.26ms
flutter:   raster p50=0.97ms p95=1.17ms max=1.38ms mean=0.85ms
flutter:   total  p50=1.47ms p95=1.75ms max=2.05ms mean=1.30ms
flutter:     bakeFrames=0/60 maxBakesInAFrame=0
flutter:     bakes=0 perFrame=0.000 blits=720 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=12 tileBytes=12582912
flutter:   tile pan frames=123
flutter:   build  p50=0.24ms p95=40.65ms max=72.55ms mean=4.92ms
flutter:   raster p50=0.90ms p95=8.78ms max=11.27ms mean=1.43ms
flutter:   total  p50=1.37ms p95=49.90ms max=89.13ms mean=7.00ms
flutter:     bakeFrames=14/120 maxBakesInAFrame=1
flutter:     bakes=14 perFrame=0.117 blits=1582 carryOverBlits=0 liveDraws=10 newEvictions=0 liveTiles=26 tileBytes=27262976
flutter:   tile probe: tilePx=512 dpr=2.0 viewport=800x600 tileLogical=256.0 pad=32.0
flutter:     tiles=12 liveLeaves=4350 tileLeaves=18204 overdraw=4.185 areaFactor=1.563
flutter:     liveWalkMs=38.84 tileWalkMsTotal=74.00 walkMsPerTile=6.167 visibleSetBytes=12582912
```

**M7 run B, verbatim** (foreground, confirmation):

```
flutter: R2 (500000) frames=242
flutter:   build  p50=39.04ms p95=47.14ms max=1591.95ms mean=31.36ms
flutter:   raster p50=10.69ms p95=37.55ms max=147.71ms mean=13.54ms
flutter:   total  p50=58.19ms p95=84.51ms max=1833.17ms mean=53.80ms
flutter:   screenSpaceLeafCount=4612 dashSpans=146358 collapsed=345 canvasCalls=150 (…)
flutter:   tiles=on tilePx=512 bakeBudgetPx=262144 bakeBudgetTiles=1 liveTiles=2 generation=122 carryOver=true
flutter:   bakes=148 blits=1651 carryOverBlits=121 liveDraws=135 blitDests=3197 evictions=0(life) invalidations=0(life) tileBytes=9777152
flutter:   backend=vertices triangles=1183035 drawVerticesCalls=42
flutter:   tile warm: frames=11 liveTiles=12 tileBytes=12582912 evictions=0(life)
flutter:   tile hold frames=60
flutter:   build  p50=0.28ms p95=0.50ms max=0.54ms mean=0.28ms
flutter:   raster p50=0.71ms p95=1.47ms max=1.51ms mean=0.80ms
flutter:   total  p50=1.24ms p95=2.32ms max=2.44ms mean=1.32ms
flutter:     bakeFrames=0/60 maxBakesInAFrame=0
flutter:     bakes=0 perFrame=0.000 blits=720 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=12 tileBytes=12582912
flutter:   tile pan frames=122
flutter:   build  p50=0.20ms p95=51.70ms max=69.98ms mean=5.83ms
flutter:   raster p50=0.50ms p95=10.83ms max=14.49ms mean=1.46ms
flutter:   total  p50=0.93ms p95=63.62ms max=90.03ms mean=8.02ms
flutter:     bakeFrames=14/120 maxBakesInAFrame=1
flutter:     bakes=14 perFrame=0.117 blits=1582 carryOverBlits=0 liveDraws=10 newEvictions=0 liveTiles=26 tileBytes=27262976
flutter:   tile probe: tilePx=512 dpr=2.0 viewport=800x600 tileLogical=256.0 pad=32.0
flutter:     tiles=12 liveLeaves=4350 tileLeaves=18204 overdraw=4.185 areaFactor=1.563
flutter:     liveWalkMs=34.21 tileWalkMsTotal=89.63 walkMsPerTile=7.469 visibleSetBytes=12582912
```

**Restore proof.** Copy-aside taken before the mutation, `shasum` matching the
tree at `394f63ef67a6576e728eac7c5846f7caaff6bcbb`; restored by `cp` from the
copy-aside, never `git checkout`; `diff` printed `DIFF CLEAN`, the `shasum`
matched again, and `git status --short` and `git diff --stat` both printed
nothing.

**Run A's deviation, recorded rather than dropped.** The mutation forces a full
macOS app rebuild and the command exceeded the 600 s tool timeout during it, so
the shell was moved to the background and the run finished there. The failure
mode the foreground rule exists to prevent — a background-*launched* run
stalling at 0% CPU waiting for a frame the windowing system never requests — did
not occur: the app was sampled at 42.6% CPU mid-run and produced a full
transcript. It was nonetheless re-run in the foreground as run B, and both agree
on every conclusion.

## The instrument that reimplements what it measures

**The rig's `tile probe` reports `overdraw=4.185` bit-for-bit identically in the
clean and the mutated runs.** `_probeBake` in `measurement_rig.dart`
reimplements the bake geometry rather than calling `TileCache._bake`, so the
overdraw column measures **what the cache should do, never what it does.**
Anyone reading that column as evidence about the shipped clip is reading a copy
of the specification.

This is the **twelfth** disguise in this plan's catalogue of gates that cannot
see what they claim to measure, and it is a new one: *an instrument that
reimplements what it measures*. It is not a bug in `_probeBake` — a probe that
called the real `_bake` could not sum per-tile leaf counts the way this one does
— but it is a boundary nobody had written down.

## What is owed

**A bake-time assertion that a tile's geometry is bounded by its own rect** —
the command-time-assertion shape trap 5 already recommends for this repository —
**not another frame-path timing.** Two device timings were the plan's answer for
M7 and both turned out unable to deliver: one is blind by construction, the
other is red on clean source. A third timing would be a fourth attempt at the
same wrong instrument.

Two tasks touched M7 without firing it, and both said so explicitly: Task 6a's
rejected region-based-culling experiment preserved per-tile culling and was
therefore **not** M7, and 6a's report notes that baking one surface and slicing
it "is not a tile cache, and is mutant M7's shape".

---

# M8 — drop `_tables` from the merge, keep the revision read in `paintFrame`

*Task 8. `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`.*

**The edit:**

```dart
_repaint = Listenable.merge([widget.camera, _changes]); // M8
```

**Red:**

```
00:00 +21 -1: .../test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation [E]

  The following TestFailure was thrown running a test:
  Expected: a value greater than <1>
    Actual: <1>
     Which: is not a value greater than <1>
  a layer edit must cause a frame at all -- the half a counter inside paint could never reach

  #4      main.<anonymous closure> (file:///.../test/tile_invalidation_test.dart:515:5)
```

and, in the same run:

```
00:00 +23 -1: .../test/draft_canvas_test.dart: a table edit repaints with tiles off too

  The following TestFailure was thrown running a test:
  Expected: true
    Actual: <false>
  the drawing changed, so a frame is owed
```

**The asymmetry this mutant exists to record.** The cache's own logic is
untouched by M8 and remains correct in every particular; it is simply never
reached. A revision counter inside `paintFrame` is right and unreachable, and
**only a frame count can tell the difference.**

**Restored:**

```
$ cp /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart && diff /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart
M8 RESTORED (no diff)
```

Full suite re-run after every restore in this task: `341 tests, All tests
passed!`

---

# M8b — keep `_tables` in the merge, delete the drop from the revision branch

*Task 8. The mutant the brief's own test would not have caught.*

**The edit:**

```dart
// M8b
if (tablesRevision != _tablesRevision) {
  _tablesRevision = tablesRevision;
}
```

**Red:**

```
00:00 +8: criterion 7: a layer edit repaints and drops the generation

  The following TestFailure was thrown running a test:
  Expected: <8>
    Actual: <0>
  every tile baked before the edit was drawn against the old layer table and must have been thrown
  away

  #4      main.<anonymous closure> (file:///.../test/tile_invalidation_test.dart:521:5)
```

**The frame-count assertion passed.** Only the added assertion went red — the
two halves are separable mutants, which is the whole point of asserting both.

**Restored:**

```
$ cp /tmp/tile_cache.dart.bak lib/src/tile_cache.dart && diff /tmp/tile_cache.dart.bak lib/src/tile_cache.dart
M8b RESTORED (no diff)
```

---

# M8c — the adapter disposes without unsubscribing

*Task 8.*

**The edit:**

```dart
@override
void dispose() {
  // M8c: the removal deleted, the disposal kept.
  super.dispose();
}
```

**Red:**

```
00:00 +16: the table adapter detaches on both teardown paths

  The following TestFailure was thrown running a test:
  Expected: <1>
    Actual: <2>
  re-attaching must replace the listener, not add one

  #4      main.<anonymous closure> (file:///.../test/draft_canvas_test.dart:509:7)
```

Red at the **first** re-attach, on the `didUpdateWidget` path — the leak Task 2's
carried minor named, caught by count and not by symptom. There was no instrument
for listener lifetime at all before this task; `DocumentTables.debugListenerCount`
was added for it, and the sequence 0 → 1 → re-attach → 1 → re-attach → 1 →
unmount → 0 is pinned.

**Restored:**

```
$ cp /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart && diff /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart
M8c RESTORED (no diff)
```

---

# M8d — `didUpdateWidget` stops watching `tiles` / `tileDevicePixels`

*Task 8.*

**The edit:**

```dart
        false) { // M8d
```

**Red:**

```
00:00 +16: the table adapter detaches on both teardown paths

  The following TestFailure was thrown running a test:
  Expected: not same instance as <Instance of 'TileCache'>
    Actual: <Instance of 'TileCache'>
  tileDevicePixels is fixed at the cache's construction, so a changed value that reused the cache
  would be ignored outright

  #4      main.<anonymous closure> (file:///.../test/draft_canvas_test.dart:512:5)
```

**Restored:**

```
$ cp /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart && diff /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart
M8d RESTORED (no diff)
```

---

# M9 — bake the whole visible set in one frame

*Task 9.*

**The edit:**

```
       var image = _tiles[key];
-      if (image == null && budget > 0) {
+      if (image == null) { // M9: the budget is ignored
```

**Command.** `CI=true flutter test test/tile_cache_test.dart`

**Red:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +0 -1: a first frame bakes up to its budget and draws the rest live [E]
  Expected: <3>
    Actual: <130>
  the budget, not the visible set
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 65:5                      main.<fn>
  
00:00 +0 -1: a warm frame bakes nothing and blits the whole visible set
00:00 +1 -1: the blit Paint is one instance for the life of the cache
00:00 +2 -1: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +3 -1: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +4 -1: criterion 1: and it still holds after twenty-three awkward pans
00:00 +5 -1: criterion 2: a fixture crossing tile boundaries still matches
00:00 +6 -1: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
00:00 +7 -1: criterion 3: text survives the tile round trip
00:00 +8 -1: criterion 4: overlapping translucent strokes composite identically
00:00 +9 -1: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own
00:00 +10 -1: criterion 8: a pan drops nothing and a scale change drops everything
00:00 +11 -1: a zoom gesture blits the carry-over and bakes nothing
00:00 +11 -2: a zoom gesture blits the carry-over and bakes nothing [E]
  Expected: <0>
    Actual: <1040>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 411:5                     main.<fn>
  
00:00 +11 -2: the gesture frame the carry-over serves is not blank
00:00 +11 -3: the gesture frame the carry-over serves is not blank [E]
  Expected: <0>
    Actual: <130>
  the new generation holds nothing, so the ink below cannot have come from a tile
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 443:5                     main.<fn>
  
00:00 +11 -3: the settle spreads its bakes across frames
00:00 +11 -4: the settle spreads its bakes across frames [E]
  Expected: <12>
    Actual: <130>
  four per frame, three frames
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 464:5                     main.<fn>
  
00:00 +11 -4: criterion 1: a settled frame equals the live frame after a zoom
00:00 +12 -4: defect F1: a stroke centreline just outside a tile is culled from it the loss is one stroke column, and it is ink lost rather than moved
00:00 +13 -4: a whole-document change clears the carry-over as well as the tiles
00:00 +14 -4: a table edit drops the generation without minting a carry-over
00:00 +14 -5: a table edit drops the generation without minting a carry-over [E]
  Expected: <0>
    Actual: <130>
  the generation is dropped
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 624:5                     main.<fn>
  
00:00 +14 -5: accepted gap: near-axis strokes displace a bounded number of pixels the ten-line fan stays inside the bound
00:00 +15 -5: accepted gap: near-axis strokes displace a bounded number of pixels the worst single slope measured stays inside the bound
00:00 +16 -5: accepted gap: near-axis strokes displace a bounded number of pixels the same camera and tile size agree exactly on axis-aligned ink
00:00 +17 -5: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a first frame bakes up to its budget and draws the rest live
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a table edit drops the generation without minting a carry-over
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a zoom gesture blits the carry-over and bakes nothing
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the gesture frame the carry-over serves is not blank
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the settle spreads its bakes across frames
```

**`the settle spreads its bakes across frames` — `Expected: <12> Actual: <130>`.**
The whole visible set in one frame: the ~60 ms stall this cache exists to remove,
moved rather than removed.

**Note the report makes and this log repeats.** M9 is invisible to every
*correctness* criterion — criteria 1 to 8 all pass a cache that bakes everything
at once, because the *pixels* are correct. It is not invisible to every test:
Task 4's first-frame budget test catches it too, as do the two zero-budget
gesture tests. **Criterion 11 is still the one that names the property** — and
criterion 11 is a **MISS**, at 35.67 ms against 16.67. M9 defends against the
single-frame hiccup, and the shipped one-tile budget removes that hiccup by
spreading the same work across a settle no criterion measures. See G7's
neighbour in the results note.

**Restored.** Restored from a copy, `diff` clean, green again.

---

# M10 — blit without snapping (the rounding deleted from `quantiseCamera`)

*Task 3. `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`.*

**The edit.** `final e = m.e;` — the rounding deleted, `f` left correct.

**Command.** `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart`

**Red:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +0: quantiseCamera snaps the translation to whole device pixels and nothing else
00:00 +0 -1: quantiseCamera snaps the translation to whole device pixels and nothing else [E]
  Expected: <0.0>
    Actual: <0.6199999999999974>
  e is a whole device pixel

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_grid_test.dart 36:7                       main.<fn>.<fn>

00:00 +0 -1: quantiseCamera returns the same instance when already quantised
00:00 +1 -1: quantiseCamera a dpr of 1 still quantises
00:00 +1 -2: quantiseCamera a dpr of 1 still quantises [E]
  Expected: <17.0>
    Actual: <17.31>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_grid_test.dart 53:7                       main.<fn>.<fn>

00:00 +1 -2: TileGrid the visible key count matches ceil(extent / tile) + 1 per axis
00:00 +2 -2: TileGrid every destination is a whole device pixel, at every panned camera
00:00 +3 -2: TileGrid adjacent tiles abut exactly, with no gap and no overlap
00:00 +4 -2: TileGrid the bake camera puts a tile top-left at the logical origin
00:00 +5 -2: TileGrid matchesScale is exact, not tolerant
00:00 +6 -2: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart: quantiseCamera a dpr of 1 still quantises
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart: quantiseCamera snaps the translation to whole device pixels and nothing else
```

2 of 8 tests go red.

**Restored green:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +8: All tests passed!
```

File compared byte-for-byte against the pre-mutation backup with `diff` —
identical, confirmed before rerunning. M10 was re-verified once more against the
final test file after M-A's fix landed and still reddens the same two tests the
same way.

**Note on scope.** Task 8's ruling R16 later narrowed `quantiseCamera` to the
tiled branch only: it has exactly one call site,
`tile_cache.dart:348`. Criterion 1's instrument quantises its own live arm at
`tile_comparison.dart:81`, so the gate never depended on the widget doing it.

---

# M-A — `_floorDiv` → `~/`

*Task 3. Locally minted; unlabelled in the report, named here.*

**The edit.** `static int _floorDiv(int a, int b) => a ~/ b;`

**First run — the brief's test as written did not redden:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +0: quantiseCamera snaps the translation to whole device pixels and nothing else
00:00 +1: quantiseCamera returns the same instance when already quantised
00:00 +2: quantiseCamera a dpr of 1 still quantises
00:00 +3: TileGrid the visible key count matches ceil(extent / tile) + 1 per axis
00:00 +4: TileGrid every destination is a whole device pixel, at every panned camera
00:00 +5: TileGrid adjacent tiles abut exactly, with no gap and no overlap
00:00 +6: TileGrid the bake camera puts a tile top-left at the logical origin
00:00 +7: TileGrid matchesScale is exact, not tolerant
00:00 +8: All tests passed!
```

**Why the test was degenerate, not the mutant.** `_floorDiv` appears only in
`visibleKeys` (`tile_cache.dart:133-136`); `destRectFor` (`:156-164`) never
calls it, so the brief's "abut exactly" test **cannot detect this mutant under
any pan or key choice** — the brief's claim that it would was false. And the
brief's pan direction could never reach a negative key at all: panning subtracts
from `e`/`f`, the anchor-relative delta goes negative, `left = -dx` goes
positive, and no key is ever below zero. The pan sign was flipped and a min-key
assertion added against an independently computed floor
(`(-dx / kTestTile).floor()`).

**Red, fixed test, mutant reapplied:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +3: TileGrid the visible key count matches ceil(extent / tile) + 1 per axis
00:00 +4: TileGrid every destination is a whole device pixel, at every panned camera
00:00 +4 -1: TileGrid every destination is a whole device pixel, at every panned camera [E]
  Expected: <-1>
    Actual: <0>
  pan 0 leftmost column: floor division toward negative infinity, not truncation toward zero

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_grid_test.dart 106:9                      main.<fn>.<fn>

00:00 +4 -1: TileGrid adjacent tiles abut exactly, with no gap and no overlap
00:00 +5 -1: TileGrid the bake camera puts a tile top-left at the logical origin
00:00 +6 -1: TileGrid matchesScale is exact, not tolerant
00:00 +7 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart: TileGrid every destination is a whole device pixel, at every panned camera
```

Reddened exactly at `pan 0`, exactly at the hand-computed value
(`_floorDiv(-15, 64) = -15 ~/ 64 = 0` where the floor is `-1`).

**Restored green:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
...
00:00 +8: All tests passed!
```

Byte-identical restore confirmed by `diff` against the pre-mutation backup
before rerunning. **The failure mode this now gates:** a grid that mis-keys
negative tiles ships, and it presents as a one-tile-wide duplicate column
appearing one tile into any leftward pan.

---

# M11 — blit with `BlendMode.src` instead of `srcOver`

## Survived every criterion. Killed by a test written for it.

*Task 6.*

**The edit:**

```dart
  final Paint _blitPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..blendMode = BlendMode.src; // MUTANT M11
```

**First run against the full file — green:**

```
00:00 +8: criterion 3: text survives the tile round trip
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +10: All tests passed!
```

**M11 reddened nothing — not criterion 4, not criterion 1, not the pan test.**
This contradicts the spec's "criterion 1 probably goes red too."

**Why, algebraically.** `tile_comparison.dart`'s `_capture` always starts from a
blank, fully transparent recorder for both arms. `srcOver` computes
`result = src + dst*(1 - src.a)`; `src` computes `result = src`. When
`dst.a == 0` — the only condition any pixel in this harness is ever blitted
under, since the tile grid partitions the destination and each pixel is written
by exactly one tile exactly once — the two formulas are identical. **The
instrument is structurally blind to this mutation.**

**Confirmed empirically**, with a diagnostic that pre-fills the destination with
opaque red (something `_capture` never does): unmutated, `redSurvived = 460140`,
`erased (alpha=0) = 0` out of 480,000 pixels. Under M11, `redSurvived = 0`,
`erased = 460140`. The mutation erases nearly everything beneath every tile's
non-inked area — a severe, real defect the pixel-diff criteria cannot see at all.

**The fix: a new test**, `M11 regression: the blit composites with srcOver, so a
tile leaves what is beneath it alone wherever it has no ink of its own`,
asserting `debugBlitPaint.blendMode == BlendMode.srcOver` directly and
corroborating with the red-backdrop pixel check embedded in the test.

**Red with M11 active:**

```
00:00 +10: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own
00:00 +10 -1: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own [E]
  Expected: BlendMode:<BlendMode.srcOver>
    Actual: BlendMode:<BlendMode.src>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 309:5                     main.<fn>
```

Criteria 1 and 4 stayed green even with M11 active, confirming the algebraic
argument.

**Restored green (full file):**

```
00:00 +8: criterion 3: text survives the tile round trip
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +10: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own
00:00 +11: All tests passed!
```

`diff lib/src/tile_cache.dart <backup>` → empty, confirmed before restoring.

**One blit M11 could never see** — the carry-over composite's own `Paint` —
was later pinned by Task 9's fix round: `debugCarryOverPaint.blendMode ==
srcOver`, because the composite is drawn underneath everything and would clobber
the backdrop to transparent under `src`.

**Criterion 4 was then left with no killing mutant at all**, since M11 was its
only one and M11 is blind. That was closed by firing **M-N** at it; see below.

---

# M12 — delete the `CommandRedone` arm

## Compile error, not a red test. Reported rather than counted as a kill.

*Task 7.*

**The edit.** The brief's literal instruction: delete the `CommandRedone()` arm
from the switch.

```
lib/src/tile_cache.dart:379:13: Error: The type 'DocChange' is not exhaustively matched by the switch cases since it doesn't match 'CommandRedone()'.
 - 'DocChange' is from 'package:jet_cad_2d/src/document/doc_change.dart'
Try adding a default case or cases that match 'CommandRedone()'.
    switch (change) {
            ^
00:00 +0 -1: Some tests failed.
```

`DocChange` is `sealed`, and Dart 3 makes a non-exhaustive switch **statement**
over a sealed type a compile-time error. The omission the spec describes cannot
reach a test at all. **That is strictly stronger than a red test, and it is not
evidence that criterion 9's redo row can see anything** — which is why M12b
exists. It is also why the switch is written without a `default:` arm, and why
that choice is now documented on `applyChange`: a `default:` would restore
exactly the silent-omission failure mode the compiler is here preventing.

---

# M12b — the redo arm present, and doing nothing

*Task 7. The defect a real cache would have.*

**The edit:**

```dart
      case CommandRedone():
        return; // M12b: the redo arm is present, and does nothing.
      case CommandApplied(:final touched):
      case CommandUndone(:final touched):
```

**Red:**

```
00:00 +0: criterion 5: a leaf edit invalidates its own tiles and no others
00:00 +1: criterion 5: a dragged instance drops the tiles it left
00:00 +2: criterion 5: the undo of an instance transform invalidates both ends
00:00 +3: criterion 6: a definition edit drops the generation, and less does not
00:00 +4: criterion 9: all five change arms, none omitted
00:00 +4 -1: criterion 9: all five change arms, none omitted [E]
  Expected: <0>
    Actual: <130>
  the arm an undo-only gate never sees
  test/tile_invalidation_test.dart 269:5              main.<fn>

00:00 +5 -1: Some tests failed.
```

**Criterion 9's redo row only** — the apply and undo rows above it stayed green,
which is what proves the row is specific to redo rather than to the switch as a
whole.

**A malformed first attempt, recorded because it is instructive.** Inserting the
no-op arm *after* the existing `CommandApplied`/`CommandUndone` case labels made
those two labels fall into the no-op body, so all five tests went red. That is a
mutant that broke three arms, not one, and it would have "killed" criterion 9
for the wrong reason. It was corrected before anything was recorded as a result.

**Restored.** `RESTORE CLEAN`. Re-fired after the C1 fix: still red, still
exactly one test.

---

# M13 — build the blit `Paint` per tile at the `drawImageRect` call site

## The identity getter could not see it. A canvas spy can.

*Task 4.*

**The edit.** `_blitPaint` replaced at its one use site with a fresh literal,
leaving the field and the `debugBlitPaint` getter untouched:

```dart
      canvas.drawImageRect(image, _tileSourceRect, dest,
          Paint()..filterQuality = FilterQuality.none);
```

**Against the brief's three-test file — all green:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: All tests passed!
```

**Why.** `debugBlitPaint` returns the `_blitPaint` field directly, and the
mutation never touches that field — it only changes what is passed to
`drawImageRect`. `identical(rig.cache.debugBlitPaint, first)` compares the field
to itself across two frames, which stays true regardless of what actually
reaches `dart:ui`. **The assertion is a tautology.** The spec had claimed this
getter "is what makes M13 killable"; it was corrected, one section after the
spec itself cited the trap.

`paint_allocation_test.dart` already documents the identical shape for
`VerticesDrawSink.debugPaint`, and closes it the same way.

**The fix.** A fourth test reading, via the repository's existing `SpyCanvas`,
every `Paint` object actually handed to `drawImageRect` across the whole visible
set (>30 tiles, satisfying anti-degenerate clause 3 on its own).

**Red, with M13 still active:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +3 -1: the blit hands drawImageRect the same Paint object every time, not a call-site-local one [E]
  Expected: true
    Actual: <false>
  paintFrame must hand drawImageRect the one Paint built for the cache's life, not a fresh one per blit

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 95:7                      main.<fn>

00:00 +3 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
CI=true flutter test test/tile_cache_test.dart 2>&1  1.65s user 0.35s system 104% cpu 1.921 total
```

**The new test goes red under M13; the identity test stays green** — the two are
not redundant, exactly the relationship `paint_allocation_test.dart` documents
between its own two tests.

**Restored green:**

```
$ cd packages/jet_cad_2d_flutter && time CI=true flutter test test/tile_cache_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +4: All tests passed!
CI=true flutter test test/tile_cache_test.dart 2>&1  1.49s user 0.32s system 99% cpu 1.822 total
```

**Nothing about the production code was wrong.** `_blitPaint` is one `Paint` for
the life of the cache. The deviation was entirely in what could observe it.

---

# M14 — skip text when baking a tile

*Task 6. `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`.*

**The edit.** `drawText` is `final` on `DraftPainter` (`draft_painter.dart:93`),
so it cannot be toggled per-bake from `TileCache`. Mutated `_drawText`'s entry
guard directly:

```dart
  void _drawText(DrawSink sink, int slot, GeometryPayload payload,
      ResolvedStyle style, Transform2 chain, Vector2 localOrigin) {
    if (!drawText || true) return; // MUTANT M14: skip text unconditionally.
```

**Red:**

```
00:00 +8: criterion 3: text survives the tile round trip
00:00 +8 -1: criterion 3: text survives the tile round trip [E]
  Expected: <6>
    Actual: <0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 263:5                     main.<fn>
```

**Finding, reported rather than hidden.** The spec predicted criterion 3 would
go red "with a large `uncoveredPixels` count" — through the pixel comparison,
with the counter check staying green. It reddens instead at the `textOpCount`
assertion, before `expectTiledEqualsLive` ever runs, because the guard mutation
is global and cannot be scoped to "during a bake only" — that scoping is exactly
what `final` prevents. A real "skip text only while baking" defect would leave
the live-only call correct and break only the tiled path's pixels; this stand-in
cannot distinguish the two. **It still reddens the test**, which is what the bar
requires.

**Restored:**

```
00:00 +8: criterion 3: text survives the tile round trip
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +10: All tests passed!
```

`diff lib/src/draft_painter.dart <backup>` → empty, confirmed.

**Related, and it is the reason criterion 3 reads its counters where it does.**
As originally written, criterion 3 read `textOpCount` after the wrong paint: the
painter resets its counters per call and the cache calls it per tile, so the
reading was the *last tile's*, usually text-free. Fixed by reading from one
standalone whole-viewport paint. `textOpCount = 6`, `culledTextCount = 0`.

---

# M15 — offset a tile's bake camera by one device pixel

*Task 5. This is the mutant G1 says the instrument **can** fire.*

**The edit.** In `TileGrid.bakeCameraFor`, `m.e - key.x * _tileLogical` became
`m.e - key.x * _tileLogical + 1 / devicePixelRatio`.

**Command.** `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart`

**Red:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +4 -1: criterion 1: a warm tiled frame equals the live frame exactly [E]
  Expected: <0>
    Actual: <5574>
  InkReport(live: 19860, tiled: 19878, stray: 5574, uncovered: 5556, differing: 11130)

00:00 +4 -1: criterion 1: and it still holds after twenty-three awkward pans
00:00 +4 -2: criterion 1: and it still holds after twenty-three awkward pans [E]
  Expected: <0>
    Actual: <5640>
  InkReport(live: 19722, tiled: 19740, stray: 5640, uncovered: 5622, differing: 11262)

00:00 +4 -2: criterion 2: a fixture crossing tile boundaries still matches
00:00 +4 -3: criterion 2: a fixture crossing tile boundaries still matches [E]
  Expected: <0>
    Actual: <5574>
  InkReport(live: 19860, tiled: 19878, stray: 5574, uncovered: 5556, differing: 11130)

00:00 +4 -3: Some tests failed.
Failing tests:
  .../test/tile_cache_test.dart: criterion 1: a warm tiled frame equals the live frame exactly
  .../test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
  .../test/tile_cache_test.dart: criterion 2: a fixture crossing tile boundaries still matches
```

**Criterion 2 goes red with non-zero stray (5574) and uncovered (5556) counts**,
exactly as the spec requires. Reproduced identically on a second, independent run
before restoring.

**Restored green:**

```
$ cp /tmp/tile_cache.dart.bak lib/src/tile_cache.dart
$ diff /tmp/tile_cache.dart.bak lib/src/tile_cache.dart   # empty, confirmed
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: All tests passed!
```

Killed cleanly by criterion 2 exactly as specified. No deviation.

---

# M16 — record only leaf handles per tile, dropping the node list

*Task 7. Applied to `draft_painter.dart`, the two node call sites at `:401`
(`_drawInstance`) and `:485` (`_descend`). The two leaf sites at `:374` and
`:454` were left alone, so the cache records leaves and nothing else.*

**Red:**

```
00:00 +0 -1: criterion 5: a leaf edit invalidates its own tiles and no others [E]
  Expected: non-empty
    Actual: Set:[]
  test/tile_invalidation_test.dart 99:5               main.<fn>

00:00 +0 -2: criterion 5: a dragged instance drops the tiles it left [E]
  Expected: non-empty
    Actual: Set:[]
  a tile that never recorded the node cannot find the pixels a drag left behind, and the ghost is invisible to every leaf-handle test
  test/tile_invalidation_test.dart 151:5              main.<fn>

00:00 +0 -3: criterion 5: the undo of an instance transform invalidates both ends [E]
  Expected: non-empty
    Actual: Set:[]
  test/tile_invalidation_test.dart 196:5              main.<fn>

00:00 +3 -3: Some tests failed.
```

**But it dies on the fixture guard, not on an invalidation assertion** — a red
that is a statement about the fixture rather than about the machine. So the test
was strengthened to name the ghost **without going through the node's own
record**: `tilesHolding(Handle(1002)).difference(tilesHolding(Handle(301)))`, the
tiles carrying this definition's pixels other than the far placement's. Under the
correct implementation that is `{(0,3),(0,4),(1,3),(1,4)}` — instance 300's four
tiles, all of which are dropped. Under M16 `tilesHolding(301)` is empty, so the
set is all eight and the assertion demands *more*, not less. **It is monotone in
the right direction: the mutant cannot shrink its way out.**

**Proved rather than argued.** A throwaway probe reproduced the drag with the
node-record guard removed, so the ghost assertion was reached:

```
=== under M16 ===
leafTiles=8 ghostTiles=8
00:00 +0 -1: ghost tiles alone [E]
  Expected: false
    Actual: <true>
  ghost at TileKey(0, 3)
  test/zz_m16_probe_test.dart 39:7                    main.<fn>

=== control, restored tree ===
leafTiles=8 ghostTiles=4
00:00 +1: All tests passed!
```

Probe deleted; painter restored, `PAINTER RESTORE CLEAN`; cache verified
untouched, `CACHE RESTORE CLEAN`.

## M16 and the group mutant (M-J) are independent. Neither subsumes the other.

This matters enough to state on its own, because a reader who has just seen both
mutants attack "a dragged container leaves a ghost" would reasonably assume one
covers the other. It does not, in either direction.

- **A group is recovered through the leaf's owner-chain climb**, which M16 does
  not touch at all. So M16 leaves the dragged-**group** test green — correctly.
- **An instance is recovered only from the two `debugOnVisit` node call sites**,
  which M16 removes. And a leaf inside a definition has the *definition* as its
  owner, not the instance placing it, so the owner chain can never reach an
  enclosing instance. So M-J leaves the dragged-**instance** test green.

**Two independent mechanisms, two independent mutants, neither masking the
other. Both are required.**

**Re-fired after the C1 fix:** M16 still red on the leaf edit, the dragged
instance, the undo and the **nested definitions** test — and green on the
dragged group, which is the separation above, working.

---

# M17 — bake tiles with a per-tile rebase origin instead of the frame-global one

## NOT killed by criterion 1. Killed by a wiring test. This distinction is the point.

*Tasks 1 and 5.*

Recording M17 as "killed by criterion 1" would be **the same false coverage
claim this plan's spec cites from Plan 3f.1**, and it would have been made here
if Task 5 had stopped at "the mutant is green, so move the fixture further out".

## Firing 1 — Task 1, the painter's own override

**The edit.** Dropped the `debugRebaseOrigin ??` override so `origin` ignores the
injected value:

```dart
    final origin = debugDisableRebasing ? Vector2.zero() : rebaseOriginFor(world);
```

**Red:**

```
$ CI=true flutter test test/draft_painter_rebase_test.dart
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  ... (dependency resolution output, identical to the runs above)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart
00:00 +0: an injected rebase origin overrides the one the view span would give
00:00 +0 -1: an injected rebase origin overrides the one the view span would give [E]
  Expected: <-4064.0>
    Actual: <32.0>
  x rebased against the injected origin

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/draft_painter_rebase_test.dart 74:7            main.<fn>

00:00 +0 -1: debugOnVisit reports every leaf drawn and every container descended
00:00 +1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart: an injected rebase origin overrides the one the view span would give
```

**Restored green:**

```
$ CI=true flutter test test/draft_painter_rebase_test.dart
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  ... (dependency resolution output, identical to the runs above)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart
00:00 +0: an injected rebase origin overrides the one the view span would give
00:00 +1: debugOnVisit reports every leaf drawn and every container descended
00:00 +2: All tests passed!
```

## Firing 2 — Task 5, `_bake` drops the injected origin. Green, twice.

**The edit.** In `_bake`, `_drawInto(..., origin, null)` became
`_drawInto(..., Vector2.zero(), null)`.

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: All tests passed!
```

**The spec's escape hatch — relocate `crossingGrid` to 4.5e6 — also green:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: All tests passed!
```

## Why no pixel comparison on this backend can ever fire M17

Not "not far enough yet". **An exact algebraic identity.**

`crossingGrid`'s entities are all `EntityKind.line`, which `DraftPainter` routes
through `_emitScreenSpace` (`draft_painter.dart:589`). Per point it computes:

```dart
_points[i*2] = toScreen.a*x + toScreen.c*y + toScreen.e - _screenOrigin.x;
```

then hands `_points` to
`sink.beginResidual(Transform2.translation(_screenOrigin.x, _screenOrigin.y))`.
`VerticesDrawSink.polyline` applies that residual itself, entirely in Dart
`Float64` (`vertices_draw_sink.dart:322-323`):

```dart
final px = a*points[0] + c*points[1] + e;   // e == _screenOrigin.x
```

Substituting: `px = (toScreen.a*x + toScreen.c*y + toScreen.e - _screenOrigin.x)
+ _screenOrigin.x`. Under M17, `_screenOrigin.x = camera.worldToScreen(Vector2.zero()).x`,
which is *exactly* `toScreen.e` (multiplying by zero is exact). **The origin
cancels out of the final coordinate as a pure identity, independent of its
value** — for any point, line, polyline, circle, arc or fill entity under any
placement. The intermediates are large (~6.3 million at 4.5e6), but the
cancellation happens entirely in Dart `double` arithmetic and never in a
`Float32` slot: `VerticesDrawSink` writes only the final, already-small result
into `_positions`. Software Skia is never handed the large value at all, so it
has nothing to round away.

**Swept rather than asserted**, restoring to baseline between each check:

- At `1e12` (lines only): green, both mutant and baseline.
- At `1e15` (lines only): the 23-iteration pan-loop test goes red under M17 —
  **and reproducibly goes red identically on the restored, non-mutated
  baseline**, same `InkReport` numbers, confirmed on three repeated runs. That
  is `ViewportTransform`'s own translation losing precision under repeated
  `Float64` addition, unrelated to M17. **A criterion that reds on correct code
  is not gating anything**, so it is not a kill.
- Adding a text entity (the one sink here that pushes a residual through a real
  `canvas.transform` + `Path`) at 4.5e6: green for the single-shot tests; the
  pan-loop test failed identically in mutant and baseline again.
- A standalone probe confirmed the mechanism *can* exist — a bare `Path.moveTo`
  with a genuinely huge coordinate plus a cancelling `canvas.transform` produced
  167 differing pixels through real `dart:ui`. That shape never occurs in any
  sink reachable from `TileCache`.

Four **pre-existing** tests in this package — `large_coordinate_test.dart`,
`viewport_transform_test.dart`, `draft_painter_root_test.dart` and Task 1's
`draft_painter_rebase_test.dart` — all validate this same precision claim, and
**none renders through a real `dart:ui` `Canvas`** to do it. That is independent
prior evidence that this codebase's own authors already knew real-canvas pixel
comparison does not reproduce this loss under `flutter_test`.

## The gate that does kill it

A test that reads the coordinate `_bake` hands the sink: **"M17 regression: a
bake hands the sink a residual, not a raw site-plan-magnitude coordinate"**. It
subclasses `VerticesDrawSink` to record the largest absolute coordinate ever
handed to `polyline`, then forwards, and asserts it stays under `1e5` for a line
placed at `4.5e6`.

**Red (new test, M17 active):**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
00:00 +7 -1: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate [E]
  Expected: a value less than <100000.0>
    Actual: <4500400.0>
     Which: is not a value less than <100000.0>
  a residual, not a world coordinate -- if `_bake` drops the injected origin, `_emitScreenSpace` hands the sink the raw 4500000-magnitude world value instead, which this bound catches even though it renders to the same pixel

00:00 +7 -1: Some tests failed.
Failing tests:
  .../test/tile_cache_test.dart: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
```

`4500400.0` is exactly `o + 400` — the raw, un-rebased world x of the line's far
endpoint. Criteria 1 and 2 stayed green under the same run, confirming the new
test is not redundant with them.

**Restored green:**

```
$ cp /tmp/tile_cache.dart.bak lib/src/tile_cache.dart
$ diff /tmp/tile_cache.dart.bak lib/src/tile_cache.dart   # empty, confirmed
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
00:00 +8: All tests passed!
```

**A fact about the shipped codebase, not about this plan.** The rebase origin has
**no effect on vertices-backend pixels at all**. Rebasing earns its keep on the
`CanvasDrawSink` path, where the residual becomes a canvas transform Skia
evaluates in `float32` — and text takes that path every frame. Nothing in 3g
acts on this; it is carried forward.

---

# M18 — the slack is removed (`kTileSlack = 0.0`)

*Task 9a. Added to the spec's table by execution. The un-fix.*

**Red — three tests, at both ends of the defect:**

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

Criterion 1's zoom test fires on this mutant at **484 pixels**, because 1.10 is
in its factor list. **That is the visible defect seen by the criterion that owns
it**, rather than by a group that merely bounds it.

**Restored.** Applied to a copy taken beforehand, restored from that copy, the
restore proved with `diff` producing no output. No `git checkout`. The report
gives no separate green transcript for this mutant beyond the task's own exit
gate (Flutter 350, engine 797, goldens 35/35, `git diff --stat 2d595a1 -- test/golden`
empty).

---

# M19 — pad only the bake, not `_worldRectOf`

*Task 9a. Task 9's reverted half-fix, and the reason F1 and G6 were one task
rather than two.*

**Red — five tests:**

```
Failing tests:
  .../tile_invalidation_test.dart: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it
  .../tile_invalidation_test.dart: criterion 5: a dragged group leaves no ghost either
  .../tile_invalidation_test.dart: criterion 5: a dragged instance drops the tiles it left
  .../tile_invalidation_test.dart: criterion 5: a leaf edit invalidates its own tiles and no others
  .../tile_invalidation_test.dart: criterion 5: the undo of an instance transform invalidates both ends
```

Exactly Task 9's four direction-two assertions, plus the new G6 test. **The
pixels are correct under this mutant** — the zoom sweep is 0 of 41 — and the
*record* is a ring wider than the geometry that condemns it. **Nothing in the
repository could see that before Task 9a**, which is why Task 9 was right to
build this patch, measure it, and revert it rather than land it.

The report gives the failing-test list rather than per-assertion output for this
mutant; that is what is on record and it is reproduced here unedited.

---

# M-B — the "not this frame" eviction guard, deleted

*Task 10.*

```
721d720
<         if (entry.value == _frameSerial) continue;
```

**Red:**

```
00:00 +4 -1: criterion 12: eviction never reclaims a tile this frame blitted [E]
  Expected: <0>
    Actual: <130>
  a settled frame at the cap bakes nothing: the only tiles it could evict are the eight it just blitted
```

**130 rebakes on a settled frame that has not moved**, and it would repeat
forever with the frame path doing the evicting. `liveBytes` stays under the cap
throughout, **which is exactly why no cap assertion can see it** — the added test
asserts `bakeCount == 0`, `evictionCount` unchanged, `blitCount == 8` and
`liveDrawCount == 1` on a repeated frame at a full cap.

---

# M-C — eviction removes the tile without disposing the image

*Task 10.*

```
736c736
<     _disposeImage(_tiles.remove(key));
---
>     _tiles.remove(key);
```

**Red:**

```
00:00 +6 -1: criterion 12: eviction disposes what it reclaims [E]
  Expected: <8>
    Actual: <16>
  pan 1: every image this cache created and did not dispose is a tile it can still blit
```

**This is the leaked-image instrument the constraints asked for.** `_imagesAlive`
is incremented at the two `toImageSync` sites and decremented in `_disposeImage`,
the single door every image now leaves by. The test holds
`debugImagesAlive == liveTileCount` across six evicting pans,
`== liveTileCount + 1` with a composite standing, and `== 0` after `dispose()`.
Under M-C the leak is visible on the *second* pan, before any pre-existing
counter moves at all: `liveTileCount` falls, `liveBytes` falls, `evictionCount`
rises, and the process grows.

**Honest limitation, recorded:** `debugImagesAlive` sees a leak, **not** a
double-dispose.

---

# M-D — a reclaimed tile leaves a blank strip

*Task 10. The one the plan says would ship.*

```
632d631
<         uncovered = uncovered == null ? dest : uncovered.expandToInclude(dest);
```

**Red:**

```
00:00 +3 -3: criterion 12: a frame at the cap still equals the live frame [E]
  Expected: <0>
    Actual: <18888>
  InkReport(live: 19860, tiled: 972, stray: 0, uncovered: 18888, differing: 18888)
```

**18,888 of 19,860 inked pixels missing.** The pan-back test *does* catch this
one (`liveDrawCount` reads 0) — but only because M-D removes the live walk
entirely; it cannot catch M6, where the walk still runs. The added test is the
same journey with `expectTiledEqualsLive`, and it is the only assertion in the
file that is about pixels rather than counters.

**Its setup is asserted rather than assumed** — `evictionCount > 0` after the pan
away, `holds(TileKey(0, 0))` is `false`, and the set of keys held at the far end
that are still inside the end camera's visible rectangle is checked to be
non-empty *and* to have lost members by the time the camera arrives back.
Without those, "a frame at the cap" would be a claim about a frame that never
reached the cap.

---

# M-E — the destination counter never increments (the tile blit)

*Task 10.*

```
630d629
<       _blitDestinations++;
```

**Red (on the added test):**

```
00:00 +3 -1: criterion 13: and the destination count is a live reading, not a zero [E]
  Expected: a value greater than <30>
    Actual: <0>
```

**The plan's criterion 13 test stays green under M-E.** Its two assertions are
`first == second` and `first < 200`; **a counter stuck at zero satisfies both.**
The added test pins `blitDestinationCount == blitCount` on a covered frame with
no composite standing, and a floor of 30 for anti-degenerate clause 3.

---

# M-F — the composite becomes an eviction victim

*Task 10.*

```
754c754,759
<       if (victim == null) return false;
---
>       if (victim == null) {
>         if (_carryOver == null) return false;
>         _dropCarryOver();
>         bytes = liveBytes;
>         continue;
>       }
```

**Red:**

```
00:00 +8 -1: criterion 12: eviction runs with a composite standing, and never takes it [E]
  Expected: true
    Actual: <false>
  setup: the scale change minted one
...
00:00 +8 -2: criterion 12: a ceiling smaller than the composite bakes nothing rather than overrun it [E]
  Expected: true
    Actual: <false>
  the composite survives a ceiling it does not fit under: it is not in the tile map and eviction cannot reach it
```

The other eight tests stay green. **Nothing in the file before this round could
see it.**

---

# M-G — a sub-composite ceiling bakes anyway

*Task 10.*

```
754c754
<       if (victim == null) return false;
---
>       if (victim == null) return true;
```

**Red:**

```
00:00 +6 -4: criterion 12: a ceiling smaller than the composite bakes nothing rather than overrun it [E]
  Expected: <1920000>
    Actual: <4049920>
  and it is all the cache holds -- every tile went, and the ceiling stayed a ceiling rather than being quietly exceeded

00:00 +6 -3: criterion 12: eviction runs with a composite standing, and never takes it [E]
  Expected: a value less than <130>
    Actual: <130>
```

Also kills the two cap tests, as it should. Restored from the copy, `diff` clean.

**A measured surprise this mutant surfaced.** The sub-composite test originally
asserted `liveTileCount == 0` after one pan and read 11. Eviction is asked only
on a *miss*, so the tiles the loop had already blitted before it reached one are
protected and survive the frame. The steady state is one pan later:

```
zoomed tiles=130 bytes=4049920 carry=true live=0 evict=0   bake=260
tiny1  tiles=11  bytes=2100224 carry=true live=1 evict=119 bake=0
tiny2  tiles=0   bytes=1920000 carry=true live=1 evict=130 bake=0
tiny3  tiles=0   bytes=1920000 carry=true live=1 evict=130 bake=0
```

The test now pans twice and asserts `liveBytes == _compositeBytes` exactly.
The `evict=119` row was later **asserted** as a floor (`> 50`, not the exact
figure, since the exact count would be a map-iteration-order claim), so no number
in the surrounding comment rests on memory.

---

# M-H — the composite's own `_blitDestinations++` deleted

*Task 10.*

```
606d605
<       _blitDestinations++;
```

**Red:**

```
00:00 +3 -1: criterion 13: and the destination count is a live reading, not a zero [E]
  Expected: <131>
    Actual: <130>
  the composite allocates a destination like any other blit
```

Every other test green. Restored, `diff` clean.

---

# M-J — the owner-chain walk reverted (a dragged group leaves ghosts)

*Task 7, fix round 1. The report calls this "gating mutant G1"; renamed here to
avoid collision with accepted gap G1.*

**What it gates.** `debugOnVisit` fires for `InstanceNode` only —
`draft_painter.dart:401` and `:485` are both preceded by
`if (node is! InstanceNode) return;`. A group is never "descended into" as far as
the painter is concerned: `ContainerIndex.build` flattens a group's leaves into
its container's leaf list with a composed transform, so the group's *leaves* are
visited and the group itself is invisible. `TransformNodeCommand` accepts a
`GroupNode` and returns `touched: {handle}` — so the group handle is the only
thing the change carries, and the only thing no tile recorded.

**The defect in shipped code, before any mutation**, reproduced by the reviewer:

```
$ CI=true flutter test test/zz_c1_probe_test.dart
groupTiles=[]
leafTiles=[TileKey(9, 0), TileKey(10, 0), TileKey(9, 1), TileKey(10, 1)]
inval=4
old leaf tile TileKey(9, 0) still held: true
old leaf tile TileKey(10, 0) still held: true
old leaf tile TileKey(9, 1) still held: true
old leaf tile TileKey(10, 1) still held: true
```

`groupTiles=[]` — no group handle was ever recorded. `inval=4` — direction two
fired on the arrival tiles and direction one found nothing, so the four departure
tiles kept their pixels. **This is the M16 defect in shipped code, presenting as
the M2-only-survivor state.**

**Red, with the fix reverted:**

```
00:00 +2 -1: criterion 5: a dragged group leaves no ghost either [E]
  Expected: false
    Actual: <true>
  ghost at TileKey(9, 0): the group's pixels are still there and the group that put them there has moved
  test/tile_invalidation_test.dart 275:7              main.<fn>

00:00 +2 -2: criterion 6: a group and an instance nested inside a definition [E]
  Expected: non-empty
    Actual: []
  a group inside a definition must be findable
  test/tile_invalidation_test.dart 302:7              main.<fn>.expectWholeDrop

00:00 +6 -2: Some tests failed.
```

**Red on the pixel assertion, not on a guard.** Restored, `RESTORE CLEAN`.

**How it got through three passes.** Task 1's review traced `debugOnVisit` across
all four call sites and confirmed "once per container descended". That was true
of the fixture it traced. **No fixture in Task 1 or Task 7 contained a group**,
so one implementation and two reviews approved an unbounded claim without
anything contradicting it. The third reviewer wrote a group fixture and ran it.

The covering test states its criterion on **leaf 1003's** tiles, not on
`tilesHolding(Handle(400))` — the same lesson as M16. Leaf 1003 is what is on
screen; the group is only what moves it. Group 400 sits at tile columns 9–10,
rows 0–1, measured free of every pre-existing placement, and a probe confirmed
every pre-existing tile set is byte-for-byte unchanged by the addition:

```
live=130
1001 -> 6: (0,7) (0,8) (0,9) (1,7) (1,8) (1,9)
300  -> 4: (0,3) (0,4) (1,3) (1,4)
301  -> 4: (8,3) (8,4) (9,3) (9,4)
1002 -> 8: (0,3) (0,4) (1,3) (1,4) (8,3) (8,4) (9,3) (9,4)
400  -> 4: (10,0) (10,1) (9,0) (9,1)
1003 -> 4: (10,0) (10,1) (9,0) (9,1)
9999 -> 0:
```

**The fix was chosen in the cache rather than in the painter precisely so that
M16 stays a valid mutant** — see M16's independence note.

---

# M-K — `_enclosingDefinition`'s climb reduced to its first line

*Task 7, fix round 1. The report calls this "gating mutant G2".*

**What it gates.** A leaf under a group *inside* a definition has a group as its
owner, and `tree.definition(group)` is null — so the climb is required.
Reducing the method to its first line left **all 336 tests green**: no
leaf-under-a-group-inside-a-definition existed anywhere in this repository.
`differentialFixture`'s `Handle(520)` is an `InstanceNode` whose `parent` **is**
the definition, which `chain.isEmpty ? container : chain.last` already resolves
at the first level — so the round-1 justification was wrong and the code was
right for the wrong stated reason.

**The shape was built, not just described.** A new `nestedFixture` carries both:
a **group inside a definition** (410, parent 210) owning leaf 1005, and an
**instance inside a definition** (320, parent 210) placing definition 220 which
owns leaf 1004. Measured under both root placements of `PLATE`:

```
1005 -> 2: (0,3) (8,3)      410 -> 2: (0,3) (8,3)
1004 -> 2: (1,4) (9,4)      320 -> 2: (1,4) (9,4)
```

**Red:**

```
00:00 +3 -1: criterion 6: a group and an instance nested inside a definition [E]
  Expected: <0>
    Actual: <128>
  a leaf under a nested group is inside a definition
  test/tile_invalidation_test.dart 310:7              main.<fn>.expectWholeDrop

00:00 +7 -1: Some tests failed.
```

`128` of 130 is the tell: the per-tile path drops the two tiles the leaf itself
occupies and leaves every other placement of the block stale.

Restored, `RESTORE CLEAN`.

---

# M-L — `DocumentPurged` downgraded to `_dropGeneration`

*Task 7, fix round 1. The report calls this "gating mutant G3".*

**What it gates.** `DocumentPurged → _dropEverything` was unpinned: downgrading
it to `_dropGeneration()` stayed green, **because both arms leave zero tiles and
only the *next* frame's generation distinguishes them.**

**Red, after the criterion 9 test gained a purge assertion:**

```
00:00 +7 -1: criterion 9: a load starts a new generation, an edit does not [E]
  Expected: <3>
    Actual: <2>
  a purge rewrites the entity store wholesale
  test/tile_invalidation_test.dart 447:5              main.<fn>
```

Restored, `RESTORE CLEAN`.

---

# M-M — one device pixel of error in `TileGrid.destRectFor`

*Task 6a. The gate on G5's measured bound.*

**The edit.** `key.x * tileDevicePixels + dx + 1`.

**Red:**

```
00:00 +0 -1: ... the ten-line fan stays inside the bound [E]
  Expected: a value less than or equal to <60>
    Actual: <3192>
  InkReport(live: 10342, tiled: 10344, stray: 1597, uncovered: 1595, differing: 3192)
00:00 +0 -2: ... the worst single slope measured stays inside the bound [E]
  Expected: a value less than or equal to <45>
    Actual: <136>
  near-horizontal: InkReport(live: 1030, tiled: 1014, stray: 60, uncovered: 76, differing: 136)
00:00 +0 -3: ... agree exactly on axis-aligned ink [E]
  Expected: <0>
    Actual: <11148>
```

All three red, at **53× the bound** (3192 measured against a bound of 60; 36
measured / 60 asserted and 26 / 45 at the worst slope on correct code). Restored,
`diff` against the pre-mutation copy empty.

**This is what makes the G5 bound a gate rather than a shrug.** A test that
asserts "≤ 60" is only worth landing if something realistic pushes it past 60,
and a one-device-pixel destination error does, by a factor of fifty-three.

---

# M-N — alpha on the blit paint

*Task 6a, then fired again at criterion 4 in Task 6's fix round 1.*

**The edit:**

```dart
  final Paint _blitPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..color = const Color(0x80FFFFFF); // MUTANT (F1): alpha on the blit paint.
```

## Firing 1 — Task 6a, against the gap-group's `differing == stray + uncovered` clause

```
00:00 +0 -1: ... the ten-line fan stays inside the bound [E]
  Expected: <36>
    Actual: <10361>
  a pixel differing without being stray or uncovered is a colour defect, which this gap is not: InkReport(live: 10342, tiled: 10344, stray: 19, uncovered: 17, differing: 10361)
```

Red on the clause, **with stray and uncovered unchanged at 19 and 17** — which is
what proves the clause pulls its own weight: the counts alone cannot see a colour
defect. Restored, `diff` empty.

## Firing 2 — Task 6's fix round, at criterion 4 itself

Criterion 4 had **no mutation that reddened it** — M11 was honestly shown blind
and nothing was fired in its place. The review called that a spec failure. So this
mutant was fired directly at criterion 4:

```
$ CI=true flutter test test/tile_cache_test.dart --plain-name "criterion 4"
00:00 +0: criterion 4: overlapping translucent strokes composite identically
00:00 +0 -1: criterion 4: overlapping translucent strokes composite identically [E]
  Expected: <0>
    Actual: <19860>
  InkReport(live: 19860, tiled: 19860, stray: 0, uncovered: 0, differing: 19860)

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/support/tile_comparison.dart 140:3             expectTiledEqualsLive

00:00 +0 -1: Some tests failed.
```

**Every ink pixel differs — 19,860 of 19,860** — because the blit paint's colour
tints every tile, which a translucent fixture's non-white, non-uniform ink makes
visible everywhere it draws.

**Restored green:**

```
$ diff lib/src/tile_cache.dart <scratchpad copy>
(empty)
$ CI=true flutter test test/tile_cache_test.dart --plain-name "criterion 4"
00:00 +0: criterion 4: overlapping translucent strokes composite identically
00:00 +1: All tests passed!
```

**No test file changed for this firing.** The existing criterion 4 test is the
killer; it only needed the right mutant fired at it once, and the transcript
above is that record.

---

# M-P — `style_resolver` drops `transparency`

*Task 6, fix round 1. Fired to prove criterion 4's new alpha assertion is a gate
and not a read-back.*

**Why it exists.** `InkReport` counts ink; it carries **no colour information**.
So a `style_resolver` that dropped `transparency` entirely would leave both arms
of the fixture fully opaque and `expectTiledEqualsLive` would still pass at zero.
The fixture passed `transparency: 153` and **nothing asserted it took effect.**

**The assertion added, before the pixel comparison:**

```dart
    final firstLineSlot = rig.doc.entities.slotOf(const Handle(1000))!;
    final resolvedStyle = DocumentStyleResolver(rig.doc)
        .styleFor(firstLineSlot, StyleContext.documentRoot);
    expect(resolvedStyle.argb, 0x66FFFFFF,
        reason: 'transparency: 153 must resolve to a translucent ARGB, not '
            'the opaque one a dropped transparency channel would give: '
            '0x${resolvedStyle.argb.toRadixString(16)}');
```

`0x66` is `255 - 153 = 102`, so the assertion reads the value **through the
resolver**, not the raw input the fixture supplied. That is what makes it a gate.

**Green on correct code first:**

```
$ CI=true flutter test test/tile_cache_test.dart --plain-name "criterion 4"
00:00 +0: criterion 4: overlapping translucent strokes composite identically
00:00 +1: All tests passed!
```

**The edit:**

```dart
      argb: ((255 - 0.clamp(0, 255)) << 24) | _rgbOf(color), // MUTANT (F2 check): transparency dropped.
```

**Red:**

```
$ CI=true flutter test test/tile_cache_test.dart --plain-name "criterion 4"
00:00 +0: criterion 4: overlapping translucent strokes composite identically
00:00 +0 -1: criterion 4: overlapping translucent strokes composite identically [E]
  Expected: <1728053247>
    Actual: <4294967295>
  transparency: 153 must resolve to a translucent ARGB, not the opaque one a dropped transparency channel would give: 0xffffffff

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 293:5                     main.<fn>
```

Reddens at the ARGB assertion itself, **before** `rig.paintOnce()` or any pixel
comparison runs — exactly the trap this closes.

**Restored:**

```
$ diff lib/src/document/style_resolver.dart <scratchpad copy>
(empty)
$ CI=true flutter test test/tile_cache_test.dart
... +14: All tests passed!
```

(14, not 10 — Task 6a's gap-group tests landed between Task 6's original
submission and this fix round.)

---

# M-Q — the composite `Paint` built at the `drawImageRect` call site

*Task 9, fix round 1. **The report labels this "M18"**, which collides with the
spec's M18 (the slack removed). Renamed here.*

**Why it exists, and it is the most instructive mutant in this plan.** Criterion
13's `SpyCanvas` test — "every `drawImageRect` shares one `Paint`" — was **made
false by Task 9's own carry-over composite**, which carries its own filtered
`Paint`. The assertion was true the day it was written and silently wrong
afterwards, and invisible because **no test entered that path with a composite
standing.**

**The edit:**

```
       canvas.drawImageRect(carryOver, ..., dest,
-          _carryOverPaint);
+          Paint()..filterQuality = FilterQuality.low); // M18: call-site-local
```

**Red:**

```
00:00 +3 -1: the blit hands drawImageRect the same Paint object every time, not a call-site-local one [E]
  Expected: true
    Actual: <false>
  the composite goes first and with its own field, so an incoming tile and a live walk both composite on top of it
```

Restored from a copy, `diff` clean, green again.

**What the same phase pinned, which nothing else in this plan gated:**
`debugBlitPaint.filterQuality == none` against
`debugCarryOverPaint.filterQuality == low` — the ruling that the carry-over is
the one blit that is *not* a 1:1 texel-to-pixel copy — and
`debugCarryOverPaint.blendMode == srcOver`, which closes **M11's hazard on the
one blit M11 could never see**: the composite is drawn underneath everything and
would clobber the backdrop to transparent under `src`.

**Two further assertions were reading the wrong thing** and now say so: `a warm
frame bakes nothing and blits the whole visible set` and `the settle spreads its
bakes across frames` both asserted `liveDrawCount` as a statement about
*coverage*, where a composite standing would make the same number mean
*suppression*. Each now carries the composite half explicitly.

---

# M-R — `budgetedTilesPerFrame` truncating to zero

*Task 11a, fix round 1. **No transcript exists in the report.***

**What it is.** `budgetedTilesPerFrame` truncated, so any `tileDevicePixels`
whose area exceeds `bakeBudgetDevicePixels` divided to zero. `TILE_PX=1024` under
the harness's default budget — a numerically valid value, inside the declared
range, accepted by `minimum: 1` — would have **run the whole sweep on the
live-walk fallback while still printing `tiles=on`**, publishing the untiled
baseline under a tiled heading.

**The fix.** Clamped, not rejected: the getter floors at one tile whenever the
budget is positive (`bakeBudgetDevicePixels > 0 && tiles == 0 ? 1 : tiles`),
leaving `0` alone — that value is the zoom-path tests' deliberate "bake nothing"
configuration and must stay reachable.

**Its gates.** Two new tests in `tile_cache_test.dart`:
`budgetedTilesPerFrame floors a nonzero budget at one tile, never zero` (the
getter, both branches) and `a tile larger than the default budget still bakes
one, not none` (a real `paintFrame` at `tileDevicePixels: 1024` under
`kBakeBudgetDevicePixels`, asserting `bakeCount >= 1`).

**The report states that both were run against the pre-fix getter and failed —
"confirmed live, not asserted" — before the fix landed, and pass after. It does
not reproduce the transcript.** That is recorded here as a gap in the record
rather than reconstructed. The re-reviewer separately confirmed that the floor
sits at `tile_cache.dart:499-502` and that `paintFrame` calls that getter
directly at `:687`, so it is the truncation point itself and not a bypassable
duplicate.

**Why it is worth remembering past this plan.** The repository's
throw-on-bad-define rule was written after Plan 3c lost a device run to
`bool.fromEnvironment('TEXT')` reading `TEXT=1` as false. That guard works at the
**string** level. `TILE_PX=1024` is a valid number that turned the feature off
inside a guard built for invalid ones. **Same failure, numeric disguise, two
years later. The guard's type was right; its scope was not.**

---

## What the count actually is

**Forty-one mutants named. Forty fired. Thirty-nine killed something.**

- **Nineteen** from the spec's table (M1–M19), of which **eighteen fired**: M3
  is unfirable in this instrument. M7 fired and killed nothing — see G7.
- **Twenty-two** minted during execution: M8b, M8c, M8d, M12b, M-A, M-B, M-C,
  M-D, M-E, M-F, M-G, M-H, M-J, M-K, M-L, M-M, M-N (fired twice), M-P, M-Q, M-R,
  and the two firings of M17 at different sites. All fired.
- **Two fired without producing a red test, for reasons that are results in
  themselves:** M12 is a compile error (stronger than a red test, and no evidence
  about criterion 9), and M-R's red run is described but not transcribed.
- **Four mutants survived the gate they were aimed at and forced a new test:**
  M11, M13, M17 and M-E. A fifth, M-A, survived a gate that was degenerate as
  written. Every one of those five is a section of the successor's note in
  `2026-08-24-plan-3g-results.md`.
- **One mutant survived the gates it was aimed at and no test was written for
  it: M7.** Criterion 10 is structurally blind to it and criterion 11 is red
  before any mutation, so there is no green-to-red transition anywhere in this
  suite. That is accepted gap **G7**, and what it owes is a bake-time assertion,
  not another timing.
