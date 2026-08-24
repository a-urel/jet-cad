# Task 10 report: the cap, eviction, and criteria 12 and 13

**Status: complete.** Both packages green, goldens untouched.

## What landed

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`

- `liveBytes`, `evictionCount`, `blitDestinationCount`, and one instrument the
  brief asked for if it were cheap: `debugImagesAlive`.
- `_lastUsedFrame` (`Map<TileKey, int>`) and `_frameSerial`: the LRU order,
  keyed identically to `_tiles` and `_baked`.
- `_makeRoomForOneTile()`, `_evict()`, `_disposeImage()`, `_tileBytes`.
- The bake condition became
  `if (image == null && budget > 0 && _makeRoomForOneTile())`.
- `_tileSourceRect` went from a getter to a `late final` field (see
  *Deviations*).
- `_dropEverything`'s comment corrected.

`packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart` — the
brief's three tests verbatim (one line rejoined by `dart format`), plus five
added after asking the three questions of each of them.

## Where eviction runs, and why not at the end of the frame

The obvious place is a sweep after the blit loop. It cannot work here and the
arithmetic says so: the test viewport holds **130** tiles at 64 device pixels
against a cap of **8**, so by the time the loop ends every tile the cache holds
was blitted *this frame* and the guard forbids reclaiming any of them.
`liveBytes` would settle wherever the visible set left it — 2,129,920 B against
a 131,072 B cap, which is exactly what mutant M6's transcript below shows.

So the ceiling is consulted **before** each bake. `_makeRoomForOneTile` returns
`false` when it cannot free a slot, the tile is left uncovered, and the live
fallback owes it. That is what makes the cap hold at every point *inside* the
frame and not only at its edges.

## What `liveBytes` counts, and how it was proved to count the composite

```dart
int get liveBytes {
  final carryOver = _carryOver;
  return _tiles.length * _tileBytes +
      (carryOver == null ? 0 : carryOver.width * carryOver.height * 4);
}
```

The composite is measured from the image's own `width`/`height` rather than
from `viewport`, because its device size is a `ceil` of the viewport and it
outlives the camera it was recorded against.

**The proof is a fixture, not the code.** The brief's three tests only ever
pan, so `_carryOver` is null at every assertion they make — the composite term
is a shape absent from all three. Firing the mutation confirmed it:

```
$ perl -0pi -e 's/\(carryOver == null \? 0 : carryOver\.width \* carryOver\.height \* 4\)/(carryOver == null ? 0 : 0)/'
438c438
<         (carryOver == null ? 0 : carryOver.width * carryOver.height * 4);
---
>         (carryOver == null ? 0 : 0);

00:00 +0: criterion 12: the cap holds and eviction is real, not theoretical
00:00 +1: criterion 12: a pan back to reclaimed tiles draws live, not blank
00:00 +2: criterion 13: allocation is viewport-bounded and the Paint is one
00:00 +3: criterion 12: liveBytes counts the composite, not only the tiles
00:00 +3 -1: criterion 12: liveBytes counts the composite, not only the tiles [E]
  Expected: <4049920>
    Actual: <2129920>
  the composite is one viewport-sized image and it counts
```

All three of the brief's tests stay green. The added test
`liveBytes counts the composite, not only the tiles` is the only thing in the
repository that fires. It warms a covered generation, zooms 1.19x so the
generation is retired into a real composite (`hasCarryOver` asserted `isTrue`
as a *setup* assertion, not as the claim), and pins

```
liveBytes == liveTileCount * 64*64*4 + 800*600*4
```

1,920,000 B of composite against 209,920 B of tiles at that moment: the
composite is worth **117 tiles** here, and 29.3 MiB on the reference viewport.

## Do the budget tests run with a carry-over standing?

**Two of them cannot, one of them must, and the split is forced rather than
chosen.** Task 9's implementer was right that nothing outside
`tile_cache_test.dart` zooms, and it was worth asking.

- The two cap tests run at a 131,072-byte cap. One composite is 1,920,000 B —
  **fourteen times the whole cap**. Eviction must never reclaim the composite
  (the frame path reads it every frame it stands, and reclaiming it replaces
  stale pixels with blank ones), so with one standing `liveBytes <= cacheBytes`
  is not a cap that is being violated, it is a *contradiction*. A zoom there
  would assert something no correct implementation could satisfy. Raising the
  cap past one composite instead would put it past the visible set too and
  eviction would never run — anti-degenerate clause 7 in reverse.
- So the composite state is covered at the **production** ceiling instead,
  where a generation *and* a composite both fit — which is the exact case
  `kTileCacheBytes`'s "96 MiB, not 64" doc comment exists for. That is the
  fourth test above, and it is what closes the gap Task 9's observation named.

The file's header comment carries this reasoning so the next reader does not
have to re-derive it.

## Mutant M6 — delete the eviction call

Copied aside, mutated in place, restored from the copy, `diff` clean both ways.
No `git checkout` was used.

```
$ cp .../tile_cache.dart $SP/tile_cache.orig.dart
$ perl -0pi -e 's/if \(image == null && budget > 0 && _makeRoomForOneTile\(\)\) \{/if (image == null && budget > 0) {/' .../tile_cache.dart
$ diff $SP/tile_cache.orig.dart .../tile_cache.dart
622c622
<       if (image == null && budget > 0 && _makeRoomForOneTile()) {
---
>       if (image == null && budget > 0) {
```

Red:

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

Criterion 12's cap assertion goes red, as required. Four tests die; the cap
assertion reads **16.2x over the ceiling**.

Restored:

```
$ cp $SP/tile_cache.orig.dart .../tile_cache.dart && diff $SP/tile_cache.orig.dart .../tile_cache.dart
RESTORED CLEAN
```

**One thing M6 revealed and it is worth recording.** The brief's second test —
`a pan back to reclaimed tiles draws live, not blank` — **stays green under
M6**, i.e. with no cap at all. At a budget of two tiles against a 130-tile
viewport the frame never covers, so `liveDrawCount > 0` is true on the very
first frame, before a single eviction. It cannot distinguish "the camera came
back over reclaimed tiles and the walk covered them" from "the budget never
covered anything". The test is kept verbatim and a companion was added that
makes the same journey and compares pixels — see below.

## The verbatim failing run (step 1, before the implementation)

The HEAD `tile_cache.dart` was copied in over the implementation and restored
afterwards, same protocol:

```
test/invariants/tile_budget_test.dart:61:24: Error: The getter 'liveBytes' isn't defined for the type 'TileCache'.
test/invariants/tile_budget_test.dart:63:22: Error: The getter 'evictionCount' isn't defined for the type 'TileCache'.
test/invariants/tile_budget_test.dart:96:29: Error: The getter 'blitDestinationCount' isn't defined for the type 'TileCache'.
test/invariants/tile_budget_test.dart:101:22: Error: The getter 'blitDestinationCount' isn't defined for the type 'TileCache'.
test/invariants/tile_budget_test.dart:128:22: Error: The getter 'blitDestinationCount' isn't defined for the type 'TileCache'.
test/invariants/tile_budget_test.dart:131:22: Error: The getter 'blitDestinationCount' isn't defined for the type 'TileCache'.
```

## The verbatim passing run

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

Both packages, whole gate:

```
$ cd packages/jet_cad_2d && CI=true dart test              -> 00:02 +797: All tests passed!
$ cd packages/jet_cad_2d && dart analyze                   -> No issues found!
$ cd packages/jet_cad_2d && dart format --set-exit-if-changed . -> 113 files (0 changed)
$ cd packages/jet_cad_2d_flutter && CI=true flutter test   -> 00:05 +359 ~1: All tests passed!
$ cd packages/jet_cad_2d_flutter && flutter analyze        -> No issues found!
$ cd packages/jet_cad_2d_flutter && dart format --set-exit-if-changed . -> exit 0
$ cd packages/jet_cad_2d_flutter && CI=true flutter test --tags golden -> 00:03 +35: All tests passed!
```

## The golden diff

```
$ git diff --stat b657dec -- packages/jet_cad_2d_flutter/test/golden
(no output)
```

Empty. No golden PNG was regenerated.

## The other four mutants, and the tests they forced

Every added test earns its place by a named mutation. Each was applied by
`perl -0pi`, run, and restored from the copy; the `diff` is shown.

### M-B — the "not this frame" guard, deleted

```
721d720
<         if (entry.value == _frameSerial) continue;
```

```
00:00 +4 -1: criterion 12: eviction never reclaims a tile this frame blitted [E]
  Expected: <0>
    Actual: <130>
  a settled frame at the cap bakes nothing: the only tiles it could evict are the eight it just blitted
```

This is the thrash the brief names, and the number is the whole story: **130
rebakes on a settled frame that has not moved**, and it would repeat forever
with the frame path doing the evicting. `liveBytes` stays under the cap
throughout, which is exactly why no cap assertion can see it — the added test
asserts `bakeCount == 0`, `evictionCount` unchanged, `blitCount == 8` and
`liveDrawCount == 1` on a repeated frame at a full cap.

### M-C — eviction removes the tile without disposing the image

```
736c736
<     _disposeImage(_tiles.remove(key));
---
>     _tiles.remove(key);
```

```
00:00 +6 -1: criterion 12: eviction disposes what it reclaims [E]
  Expected: <8>
    Actual: <16>
  pan 1: every image this cache created and did not dispose is a tile it can still blit
```

**This is the leaked-image instrument the constraints asked for, and it was
cheap.** `_imagesAlive` is incremented at the two `toImageSync` sites and
decremented in `_disposeImage`, the single door every image now leaves by. The
test holds `debugImagesAlive == liveTileCount` across six evicting pans,
`== liveTileCount + 1` with a composite standing, and `== 0` after `dispose()`.
Under M-C the leak is visible on the *second* pan, before any counter the plan
already had moves at all: `liveTileCount` falls, `liveBytes` falls,
`evictionCount` rises, and the process grows.

### M-D — a reclaimed tile leaves a blank strip

The one the brief says would ship. The uncovered region is no longer
accumulated, so nothing tells the live fallback it is owed:

```
632d631
<         uncovered = uncovered == null ? dest : uncovered.expandToInclude(dest);
```

```
00:00 +3 -3: criterion 12: a frame at the cap still equals the live frame [E]
  Expected: <0>
    Actual: <18888>
  InkReport(live: 19860, tiled: 972, stray: 0, uncovered: 18888, differing: 18888)
```

**18,888 of 19,860 inked pixels missing.** The brief's own pan-back test *does*
catch this one (`liveDrawCount` reads 0), but only because M-D removes the live
walk entirely; it cannot catch M6, where the walk still runs. The added test is
the same journey with `expectTiledEqualsLive`, and it is the only assertion in
the file that is about pixels rather than counters.

Its setup is asserted rather than assumed, which is trap 9: `evictionCount > 0`
after the pan away, `holds(TileKey(0, 0))` is `false`, and the set of keys held
at the far end that are still inside the end camera's visible rectangle
(x in 0..12, y in 0..9 — the anchor never moved) is checked to be non-empty
*and* checked to have lost members by the time the camera arrives back. Without
those, "a frame at the cap" would be a claim about a frame that never reached
the cap.

### M-E — the destination counter never increments

```
630d629
<       _blitDestinations++;
```

```
00:00 +3 -1: criterion 13: and the destination count is a live reading, not a zero [E]
  Expected: a value greater than <30>
    Actual: <0>
```

**The brief's criterion 13 test stays green under M-E**, and this is trap 3 —
an instrument that cannot produce the artefact. Its two assertions are
`first == second` and `first < 200`; a counter stuck at zero satisfies both.
The added test pins `blitDestinationCount == blitCount` on a covered frame with
no composite standing, and a floor of 30 for anti-degenerate clause 3.

## Deviations

1. **`_tileSourceRect` became a `late final` field.** It was
   `Rect get _tileSourceRect => Rect.fromLTWH(...)`, which allocated a fresh
   `Rect` on each of a frame's ~130 blits. Bounded by the viewport, so never a
   rule break — but this task lands the criterion that per-frame allocation is
   a viewport quantity, and building it once is a one-line change with no
   behaviour change (`tileDevicePixels` is `final`). Flagged rather than
   silently folded in.

2. **One line of the brief's test 1 was rejoined by `dart format`.** The
   `expect(rig.cache.liveBytes, lessThanOrEqualTo(131072), reason: 'pan $i');`
   fits on one line. `dart format --set-exit-if-changed` is a binding gate;
   nothing else in the three verbatim tests moved.

3. **`evictionCount` is a lifetime counter, not reset by `resetCounters`.** It
   follows `invalidationCount`, which the file already documents as counting
   edits rather than frames. Both of the brief's tests read it after a
   `resetCounters` call and both still work; making it per-frame would have
   made the second one's reading depend on where the reset landed.

4. **Five tests added beyond the brief's three.** Each is justified by a mutant
   above that leaves all three of the brief's green.

## Concerns for the reviewer

- **The cap is exercised at 131,072 B, not at 96 MiB.** The brief says why —
  a production cap needs a corpus this suite cannot afford — but it means the
  *policy* is proven and the *number* is not. If `kTileCacheBytes` is ever
  wrong for the reference viewport, nothing here says so.
- **Eviction order among tiles that share a `_frameSerial` falls to map
  iteration order.** It is deterministic but not meaningful. The added tests
  were deliberately written not to depend on it (the pan-back test filters the
  held set rather than naming a key), because an assertion that did would be a
  test of `LinkedHashMap` rather than of the policy.
- **`_makeRoomForOneTile` scans `_lastUsedFrame` linearly per eviction.** It
  runs only when full, over a map the ceiling itself bounds, and a warm frame
  never enters it — but at a production cap holding thousands of tiles, an
  eviction-heavy frame is O(evictions x tiles). Worth a measurement before the
  cap is raised.
- **`debugImagesAlive` sees a leak, not a double-dispose.** `ui.Image.dispose`
  is documented as idempotent-ish rather than harmless, and the counter would
  go negative rather than throw. Nothing currently double-disposes; the
  `dispose()`-then-teardown path in the last test exercises exactly that and
  reads 0.

---

# Fix round 1

**Status: complete.** All four findings addressed. Both packages green,
goldens still empty against `b657dec`.

## I1 — the intersection: a composite standing *and* eviction running

Correct, and it was invisible from either side. Two tests added, plus one
production change that makes the second reachable at all.

### The fixture, and why the reviewer's suggested cap does not work

`cacheBytes = _compositeBytes + 8 * _tileBytes` = 2,051,072 cannot reach the
state: a composite is minted only from a generation that **covered** the
viewport, a covering generation here is 130 tiles = 2,129,920 B, and that is
already more than the proposed ceiling. The first frame would never cover, so
nothing would ever be retired and `_carryOver` would stay null — the same hole
in a new disguise.

The ceiling has to admit a covering generation *first* and be squeezed by the
composite *after*:

```dart
/// 138 tiles. A covering generation at this viewport and tile size is 130, so
/// the first frame covers [...] The composite is then 1,920,000 of the
/// ceiling's 2,260,992 bytes, leaving room for twenty tiles.
const int _capWithComposite = 138 * _tileBytes;
```

Measured, not asserted from arithmetic — the probe run:

```
frame1 tiles=130 bytes=2129920 carry=false live=0 evict=0  bake=130 gen=1
zoomed tiles=20  bytes=2247680 carry=true  live=0 evict=0  bake=150 gen=2
again  tiles=20  bytes=2247680 carry=true  live=0 evict=0  bake=150 gen=2
pan0   tiles=20  bytes=2247680 carry=true  live=1 evict=15 bake=165 gen=2
pan1   tiles=20  bytes=2247680 carry=true  live=2 evict=30 bake=180 gen=2
pan2   tiles=20  bytes=2247680 carry=true  live=3 evict=45 bake=195 gen=2
```

Fifteen evictions a frame with a composite standing throughout. That is the
state.

**One setup assertion I wrote was wrong and the test caught it**, which is why
it was written as a setup assertion. I claimed `liveDrawCount > 0` on the zoom
frame; it reads 0, because a zoom *in* magnifies the composite past the
viewport edges and `paintFrame` takes the `carryOverCovers` early return — the
gesture frame this cache exists to make cheap. The setup now asserts what
actually says the ceiling is shared (`liveTileCount < covering`, 20 of 130,
and `> 0`), with a comment recording why the obvious reading is wrong. The live
walk appears on the pans, where the composite has moved off the edge.

### `cacheBytes` is no longer `final`

Required by the second half of the policy. "A composite stands **and** the
ceiling is smaller than one" is unreachable through the constructor, by the
argument above: any ceiling that permits a composite already exceeds one. The
test warms at a real ceiling and takes it away — the same manoeuvre, and the
same documented justification, that `tilesBakedPerFrame` already carries in
this file for the same class of gate.

### M-F — the composite becomes a victim

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

The other eight tests stay green. Nothing in the file before this round could
see it.

### M-G — a sub-composite ceiling bakes anyway

```
754c754
<       if (victim == null) return false;
---
>       if (victim == null) return true;
```

```
00:00 +6 -4: criterion 12: a ceiling smaller than the composite bakes nothing rather than overrun it [E]
  Expected: <1920000>
    Actual: <4049920>
  and it is all the cache holds -- every tile went, and the ceiling stayed a ceiling rather than being quietly exceeded

00:00 +6 -3: criterion 12: eviction runs with a composite standing, and never takes it [E]
  Expected: a value less than <130>
    Actual: <130>
```

Also kills the two cap tests, as it should. Restored from the copy, `diff`
clean.

**A second measured surprise, and it is I2's subject.** The sub-composite test
originally asserted `liveTileCount == 0` after one pan and read 11. Eviction is
asked only on a *miss*, so the tiles the loop had already blitted before it
reached one are protected and survive the frame. The steady state is one pan
later:

```
zoomed tiles=130 bytes=4049920 carry=true live=0 evict=0   bake=260
tiny1  tiles=11  bytes=2100224 carry=true live=1 evict=119 bake=0
tiny2  tiles=0   bytes=1920000 carry=true live=1 evict=130 bake=0
tiny3  tiles=0   bytes=1920000 carry=true live=1 evict=130 bake=0
```

The test now pans twice and asserts `liveBytes == _compositeBytes` exactly:
the ceiling holds the composite and nothing else, `bakeCount == 0`,
`liveDrawCount == 1`.

## I2 — the guard keys on *blitted*, not *visible*

**Narrowed the comment; did not tighten the guard.** Both were offered; the
reasoning for this choice:

- Tightening means sweeping `TileGrid.visibleKeys` once more *before* the bake
  loop to mark the whole visible set — a second pass over the frame path,
  paid on every warm frame, to buy back a few bakes on the frames that
  overrun. The frame path is the thing this plan exists to make cheap.
- The cost of not tightening is a **hit rate, never a pixel**. A victim taken
  before it is reached becomes an ordinary miss: rebaked if the budget allows,
  otherwise added to `uncovered` and drawn by the live walk. That path is
  exactly what `a frame at the cap still equals the live frame` compares
  pixel-for-pixel, and it reads zero.
- The bound is stated in the comment: **at most one such eviction per bake**,
  because each pass frees exactly one tile and the freed slot is filled
  immediately. At production sizes it is usually none, since the LRU order puts
  every off-screen tile ahead of every on-screen one.

The `tiny1 tiles=11` probe row above is this effect measured, and the
sub-composite test's comment now names it.

## M3 — the unasserted precondition

`criterion 13: and the destination count is a live reading, not a zero` now
asserts `hasCarryOver` is `isFalse` and `carryOverBlitCount` is `0` before
claiming `blitDestinationCount == blitCount`, with a reason saying the equality
holds only in that state.

## M4 — the composite's own `_blitDestinations++`

Pinned. A second phase was added to the same test: warm, zoom 1.19x, and assert
`blitDestinationCount == blitCount + carryOverBlitCount` with
`carryOverBlitCount == 1` and `liveDrawCount == 0` as asserted preconditions.

### M-H — the composite's increment deleted

```
606d605
<       _blitDestinations++;
```

```
00:00 +3 -1: criterion 13: and the destination count is a live reading, not a zero [E]
  Expected: <131>
    Actual: <130>
  the composite allocates a destination like any other blit
```

Every other test green. Restored, `diff` clean.

## Not fixed, as directed

`_lastUsedFrame.entries` allocating a `MapEntry` per scan step. Left as is.

## Restored green

```
00:00 +0: criterion 12: the cap holds and eviction is real, not theoretical
00:00 +1: criterion 12: a pan back to reclaimed tiles draws live, not blank
00:00 +2: criterion 13: allocation is viewport-bounded and the Paint is one
00:00 +3: criterion 13: and the destination count is a live reading, not a zero
00:00 +4: criterion 12: liveBytes counts the composite, not only the tiles
00:00 +5: criterion 12: eviction never reclaims a tile this frame blitted
00:00 +6: criterion 12: a frame at the cap still equals the live frame
00:00 +7: criterion 12: eviction disposes what it reclaims
00:00 +8: criterion 12: eviction runs with a composite standing, and never takes it
00:00 +9: criterion 12: a ceiling smaller than the composite bakes nothing rather than overrun it
00:00 +10: All tests passed!
```

```
$ cd packages/jet_cad_2d && CI=true dart test              -> 00:02 +797: All tests passed!
$ cd packages/jet_cad_2d && dart analyze                   -> No issues found!
$ cd packages/jet_cad_2d && dart format --set-exit-if-changed . -> 113 files (0 changed)
$ cd packages/jet_cad_2d_flutter && CI=true flutter test   -> 00:04 +361 ~1: All tests passed!
$ cd packages/jet_cad_2d_flutter && flutter analyze        -> No issues found!
$ cd packages/jet_cad_2d_flutter && dart format --set-exit-if-changed . -> 63 files (0 changed)
$ cd packages/jet_cad_2d_flutter && CI=true flutter test --tags golden -> 00:03 +35: All tests passed!
$ git diff --stat b657dec -- packages/jet_cad_2d_flutter/test/golden -> (empty)
```

## Concerns after this round

- **`cacheBytes` is now mutable on a production type for a test's sake.** It
  follows `tilesBakedPerFrame`'s precedent and carries the same justification,
  but that is now two mutable knobs on `TileCache` whose only writer is a test.
  If a third appears, a debug-only setter surface is probably the better shape.
- **I2's bound is argued, not measured.** "At most one eviction per bake"
  follows from the loop freeing one tile per pass, and the eleven-tile probe
  row is consistent with it, but nothing asserts it. A test would have to reach
  into the eviction loop to count passes per bake.
- The earlier round's concerns stand unchanged: the cap is exercised at
  131,072 B rather than at 96 MiB, tie-breaking among equal serials falls to
  map iteration order, and the linear scan is O(evictions x tiles) on an
  eviction-heavy frame at a production ceiling.

---

# Fix round 2

**Status: complete.** One finding, accepted without rebuttal. Both packages
green, goldens still empty against `b657dec`.

## The claim was false, and my own transcript said so

`_makeRoomForOneTile`'s comment said the bound on evicting a tile that is
visible this frame but not yet reached is **"at most one such eviction per
bake"**, with the justification "each pass frees exactly one tile and the
freed slot is filled immediately". The first half of that sentence is a fact
about the loop *body*; the bound is a fact about the loop, and the loop is a
`while` that keeps going until the ceiling is satisfied or no legal victim
remains. Nothing stops at one.

The falsifying measurement was in this document, in the fix-round-1 probe
table, about eighty lines above the sentence:

```
tiny1  tiles=11  bytes=2100224 carry=true live=1 evict=119 bake=0
```

**119 evictions in one frame**, in exactly the state the new sub-composite test
constructs. I wrote both the trace and the sentence in the same round and did
not turn back to the one while writing the other.

## What the comment says now, and how each part is known

Four claims, each with its source:

1. **"One call reclaims every held tile whose serial is older than this
   frame's, until the ceiling admits one more tile or no such tile is left."**
   Read off the loop: `while (bytes > ceiling)` with a single `_evict` and
   `bytes -= _tileBytes` per pass, exiting only on the ceiling or on
   `victim == null`.
2. **"Bounded only by the number of tiles this frame has not yet blitted,
   which is the whole cache at the first miss of a frame."** Follows from the
   guard being the sole exclusion in the victim scan.
3. **"119 evictions in a single frame."** Measured, and now *asserted* — see
   below. Not left as a probe memory.
4. **"At a `cacheBytes` that holds the working set the loop never runs at
   all."** `bytes > ceiling` is false on entry, so no eviction of any kind
   happens and there is no victim to choose. This replaces the old "usually
   none at production sizes", which was true for the wrong reason — it
   appealed to LRU ordering when the real reason is that the loop is never
   entered.

The parts of the old comment that were true are kept and unchanged: the guard
itself is exact (a tile blitted this frame is never reclaimed, whatever the
ceiling demands), the cost is a hit rate and never a pixel, and the
differential test at the cap is what proves the second of those.

## The cited number is now an assertion, not a memory

Citing 119 in a source comment while nothing checked it would have reproduced
the defect in miniature. The sub-composite test records `evictionCount` before
the squeezed frame and asserts the delta:

```dart
expect(rig.cache.evictionCount - beforeSqueeze, greaterThan(50),
    reason: 'a single frame under a ceiling it cannot satisfy empties '
        'everything the blitted-this-frame guard does not protect');
```

A floor of 50 rather than the exact 119: the exact figure depends on map
iteration order among equal serials, which is a fact about `LinkedHashMap`
rather than about the policy. What the assertion has to exclude is "at most
one", and any floor above 1 does that; 50 makes it substantive. No mutant is
recorded for this round — the production change is a comment — but this
assertion is what would go red if the loop were ever narrowed to one eviction
per call, which is the shape the false sentence described.

## Restored green

```
00:00 +10: All tests passed!   (tile_budget_test.dart)

$ cd packages/jet_cad_2d && CI=true dart test              -> 00:02 +797: All tests passed!
$ cd packages/jet_cad_2d && dart analyze                   -> No issues found!
$ cd packages/jet_cad_2d && dart format --set-exit-if-changed . -> 113 files (0 changed)
$ cd packages/jet_cad_2d_flutter && CI=true flutter test   -> 00:04 +361 ~1: All tests passed!
$ cd packages/jet_cad_2d_flutter && flutter analyze        -> No issues found!
$ cd packages/jet_cad_2d_flutter && dart format --set-exit-if-changed . -> 63 files (0 changed)
$ cd packages/jet_cad_2d_flutter && CI=true flutter test --tags golden -> 00:03 +35: All tests passed!
$ git diff --stat b657dec -- packages/jet_cad_2d_flutter/test/golden -> (empty)
```

## The lesson, recorded where the next reader will meet it

This is the eleventh instance of the plan's recurring defect and the first
where the evidence was already inside the artefact being reviewed. Every
previous instance needed a new measurement to expose it; this one needed only
re-reading the page. A claim about a loop was written from the loop's *body*
while a transcript of the loop's *behaviour* sat above it in the same file.

The practical rule it yields, and the one I would add to this task's residue:
**when a comment states a numeric bound, the number must come from a
transcript or from an assertion — never from a reading of the code that
produced it.** The corrected comment cites a measurement, and the measurement
is now asserted.
