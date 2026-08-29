# Fix wave D — the two Major findings

**Territory:** `packages/jet_cad_2d_flutter/` only. `packages/jet_cad_2d` was
not touched; `apps/dev_harness_2d` was run as a regression check and not
edited.

**Commits**

| SHA | What |
|---|---|
| `d74d620` | `fix(tiles): the frame a pan stops on drew only the composite` |
| `750316b` | `docs: M23 dies, M24 survives and the derivation says why it must` |

Base was `c5794d7`. While this wave ran, the parallel wave committed `85e0726`
and `001599b` (harness + mutation log); both are underneath these two, and
neither touched this package.

---

## MAJOR 1 — the one-frame flash on every pan-after-zoom-out tail. **Closed.**

### The mechanism, re-derived before changing anything

The review's account holds against the source. `resting`'s third disjunct,
`(!scaleChanged && _restGateSteps == 0)`, is the pan's: a pan frame changes the
camera, the count resets to 0, the frame falls through to bake-and-live-walk
and the pixels are right, ring included. The frame *after* the pan stops
repeats the same quantised camera, so the count reads **1** — too late for that
disjunct, too early for `>= kRestGateFrames` — and `_carryOver` is still
standing, because it is dropped only on a frame that covers *and* baked nothing
(`tile_cache.dart`, the covered return). So `resting` is false, the frame
returns after the composite blit alone, and the strip the composite has slid
off is background for exactly that one frame.

Two facts decided the shape of the fix:

* **The count cannot separate the two frames.** D1's in-between frame — matched
  once after a *zoom* — carries the same count of 1 and owes the opposite
  answer, because a wheel delivers isolated notches and a frame that bakes at
  count 1 bakes once per notch.
* **Widening `resting` is the mistake Ruling 17 records.** Any widening that
  catches the pan tail by relaxing the count also catches the wheel's
  in-between frame (breaking D1) and, on a zoom out, spends a full-viewport
  live walk where D3 accepts a background ring.

### The change

One bit, `_lastChangeWasPan`, written **only on a frame that changed
something**, so it remembers the last change across any number of unchanged
frames:

```dart
final cameraHeld =
    previous != null && sameQuantisedCamera(previous, quantised);
_restGateSteps = cameraHeld ? _restGateSteps + 1 : 0;
if (!cameraHeld || scaleChanged) _lastChangeWasPan = !scaleChanged;
```

and one disjunct in `resting`:

```dart
final resting = previous == null ||
    _carryOver == null ||
    (!scaleChanged && _restGateSteps == 0) ||
    _lastChangeWasPan ||
    _restGateSteps >= kRestGateFrames;
```

**A scale change always writes `false`**, whether or not the quantised camera
also moved — a device-pixel-ratio or tile-size change re-anchors the generation
without moving the camera, and `identical(incoming, grid)` calls that a scale
change. That is why the new disjunct needs no `!scaleChanged` of its own: the
bit can never be true on a frame `resting` must treat as moving. It is also
what makes the D3 arm below a real gate rather than a restatement.

Nothing else in the frame path changed. The rest bake is still gated on the
literal `_restGateSteps >= kRestGateFrames`, so the pan tail falls through to
the *budgeted* tile loop and the live fallback — exactly what its pan frames
did — and not to a band bake.

### The three things the brief asked to be proved

**1. The pan tail no longer shows background.** New test, `test/tile_regime_test.dart`:
`the frame the pan stops on still fills what the composite does not cover`.
Settle, one `zoomAt` **out** (the composite shrinks and cannot cover), four
pans, then one more frame at the same camera — and the strip is read in pixels.

The strip is taken **inside the composite's own rows** and to the right of
where the pan carried it, so D3's accepted ring cannot account for it: at
`zoomBy(0.75)` about the viewport centre the composite is
`[50, 350] x [37.5, 262.5]` logical, four pans of 40 put its right edge at
x = 190, and the fixture inks out to x = 261. The measured region is
`(194, 40)-(258, 240)`.

Three parts of the setup are load-bearing and are asserted rather than assumed:

* `tilesBakedPerFrame: 4`. The rest bake ignores the budget so the settle still
  covers in one frame, but the *pan* frames are budgeted. A generation that
  caught up during the pan would cover the viewport — which ends the settle, so
  the tail frame would never be painted — and would also drop the composite the
  tail frame blits. Both are asserted before the tail frame
  (`viewportCovered` false, `hasCarryOver` true).
* `debugRestGateSteps == 0` before, `== 1` after: the frame under test is
  neither a pan frame nor a rest frame.
* A **rig** test and not a widget test. An uncovered cache asks `DraftCanvas`
  for another frame from a post-frame callback, so the repaint boundary is
  dirty the moment this frame ends and `captureTiled`'s `toImage` asserts on
  `!debugNeedsPaint`. That is not an inconvenience to route around: it is the
  same fact that puts this frame on screen at all. `captureTiledFrame` was
  added beside `captureLiveFrame` in `test/support/tile_comparison.dart` — the
  capture *is* the frame.

**2. A steadily spun wheel still never arms the gate, and still never bakes.**
Already gated by `a steadily spun wheel never arms the rest gate`
(`tile_regime_test.dart`), which is unchanged and green — and green *under
M23*, in the same transcript as the failing pan arm. It is the arm that would
redden if the pan tail had been closed by widening `resting`.

**3. D3's zoom-out ring is intact.** New test: `a zoom out leaves its ring as
background, the frame after the last notch included`. Three notches of 0.9,
then the frame after the last notch — the frame at risk, since it has matched
once and not yet twice exactly like the pan tail. It asserts `bakeCount == 0`,
`liveDrawCount == 0` (a walk there is a full-viewport walk, which is the frame
D3 exists to prevent), `carryOverBlitCount > 0` for non-vacuity, and then the
ring in pixels: zero ink in `(348, 30)-(398, 270)` against a live capture that
inks it.

**The pan before the gesture is not decoration.** It leaves the remembered bit
set, so a bit that a scale change fails to clear turns this frame into the
full-viewport walk D3 refuses. Without that pan the arm would pass for a cache
whose bit was never written.

### The assertion that moved, and why

**One**, and it is the one the brief predicted.

`test/invariants/tile_budget_test.dart`, `criterion 12: a ceiling smaller than
the composite bakes nothing rather than overrun it`: `liveDrawCount` **2 → 3**.

The three frames there are the pan, the frame the pan stops on, and the rest
frame whose rest bake the ceiling declines and whose tile loop the ceiling
admits nothing to. Before this plan only the last walked; the D8 fix made the
pan frame walk (1 → 2); this fix makes the middle one walk (2 → 3). Each of
those frames draws a viewport the shrunken ceiling cannot tile at all, so each
owes exactly one walk: a number above three would mean a frame walking twice,
below it a frame showing background or stale pixels. The comment was rewritten
to say that rather than to record a new number.

**The four load-bearing clauses of that test are untouched and still pass**:
`hasCarryOver` is true, `liveBytes == _compositeBytes`, `liveTileCount == 0`,
`bakeCount == 0`.

Nothing else in the package moved: 411 tests at `c5794d7`, 413 now (411 + the
two new arms), 1 skip both times.

### M23 — fired, died, restored

**Mutation** (the field, the write and the read):

```diff
-  bool _lastChangeWasPan = false;

-    if (!cameraHeld || scaleChanged) _lastChangeWasPan = !scaleChanged;

     final resting = previous == null ||
         _carryOver == null ||
         (!scaleChanged && _restGateSteps == 0) ||
-        _lastChangeWasPan ||
         _restGateSteps >= kRestGateFrames;
```

**Procedure:** `cp lib/src/tile_cache.dart` to a scratch copy, edit, run,
restore by `cp`, `diff` to prove the restore, run again. (The transcripts below
are the post-`dart format` re-firing, so the line number in the stack matches
the committed file.)

**RED:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
00:00 +0: the same camera compares same
00:00 +1: a scale change compares different
00:00 +2: a translation change compares different
00:00 +3: the two scale terms are compared independently
00:00 +4: the skew terms are compared too
00:00 +5: a moving frame bakes nothing and walks nothing
00:00 +6: a moving frame with no composite falls through and draws something
00:00 +7: a steadily spun wheel never arms the rest gate
00:00 +8: a pan after a zoom fills the region the composite slides off
00:00 +9: the frame the pan stops on still fills what the composite does not cover
00:00 +9 -1: the frame the pan stops on still fills what the composite does not cover [E]
  Expected: a value greater than <200>
    Actual: <0>
     Which: is not a value greater than <200>
  the one frame between the last pan and the rest bake must draw what the pan frames before it drew, or the strip flashes background for a frame and comes back
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_regime_test.dart 357:5                    main.<fn>
  
00:00 +9 -1: a zoom out leaves its ring as background, the frame after the last notch included
00:00 +10 -1: an edit inside one band rebakes that band alone
00:00 +11 -1: a skipped band keeps its tiles out of the ceiling's reach
00:00 +12 -1: the gate is two unchanged frames, and the constant says so
00:00 +13 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: the frame the pan stops on still fills what the composite does not cover
```

The measured ink is **literally zero** — not a shortfall but background, which
is what the finding says the frame shows. Note the two arms that stay green
beside it: the wheel (D1) and the zoom-out ring (D3).

**Restore:** `diff` against the pre-mutation copy printed nothing.

**GREEN:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
00:00 +0: the same camera compares same
00:00 +1: a scale change compares different
00:00 +2: a translation change compares different
00:00 +3: the two scale terms are compared independently
00:00 +4: the skew terms are compared too
00:00 +5: a moving frame bakes nothing and walks nothing
00:00 +6: a moving frame with no composite falls through and draws something
00:00 +7: a steadily spun wheel never arms the rest gate
00:00 +8: a pan after a zoom fills the region the composite slides off
00:00 +9: the frame the pan stops on still fills what the composite does not cover
00:00 +10: a zoom out leaves its ring as background, the frame after the last notch included
00:00 +11: an edit inside one band rebakes that band alone
00:00 +12: a skipped band keeps its tiles out of the ceiling's reach
00:00 +13: the gate is two unchanged frames, and the constant says so
00:00 +14: All tests passed!
```

---

## MAJOR 2 — the ungated ceiling guard. **The arm cannot be built; reported as a finding.**

### The review's diagnosis is right

`tile_regime_test.dart`'s `a skipped band keeps its tiles out of the ceiling's
reach` cannot fail. `pumpTiled` never sets `cacheBytes`, the cache runs at
`kTileCacheBytes` against ~2.1 MB of tiles, `_makeRoomForBytes` exits before its
first iteration, and both assertions hold identically with and without the skip
branch's `_lastUsedFrame[key] = _frameSerial`.

### But the arm it asks for cannot exist, and not for want of a tighter cap

Write `t` for `_tileBytes`, `V` for the visible tiles held at the moment of a
room request, `St` for the stale off-viewport tiles held.

1. **The rest bake refuses to start unless the cap funds one band plus every
   visible tile**: `bandBytes + visibleTiles * t <= cacheBytes`. At the harness
   viewport that is `13t + 130t = 143t`, and it is the smallest cap under which
   a skip branch executes at all.
2. **Every room request inside the rest bake is made while a visible key is
   still missing.** `_makeRoomForBytes(bandBytes + t)` runs only for a band with
   a missing key; `_makeRoomForOneTile()` runs only for a key not in `_tiles`.
   So `V <= visibleTiles - 1 = 129`.
3. **The demand therefore never exceeds the stale supply.** The ceiling for
   `_makeRoomForBytes(bandBytes + t)` is `cacheBytes - 14t >= 129t`, and
   `liveBytes` there is `(V + St) * t` — `_band` is not yet assigned and the
   composite was dropped before the loop — so the evictions needed are
   `V + St - 129 <= St`. Inside the slice loop the band image is resident and
   the ceiling is `cacheBytes - t >= bandBytes + 129t`; the same subtraction
   gives the same bound.
4. **Every stale key's serial is strictly older than every visible key's.** A
   key is stamped only on a frame it is visible on, and the frame that made a
   key stale is by definition a frame whose camera changed — which resets the
   rest gate, so no rest bake happens on it. `_lastUsedFrame` is kept in
   lockstep with `_tiles` by `_evict`, `_disposeTiles` and `_invalidateTouched`,
   so there are no phantom entries to disturb the ordering.

Victim selection is oldest-first, so `_makeRoomForBytes` takes stale keys and
stops before reaching any visible key — skipped band or otherwise. And by the
end of the frame every visible key carries the serial anyway, because the tile
loop stamps each one it blits. The stamp is therefore unobservable through
`viewportCovered`, `evictionCount`, `liveTileCount` or `liveBytes`.

**A second thing the derivation settles**, because the requested arm was framed
on it: a hole left by such an eviction would not be a blank region even if one
could be produced. A missing key joins `uncovered` and the live fallback draws
it — correct pixels at a cost — and the one path that would show background
instead, `carryOverCovers` returning early, is unreachable here: a frame that
*skips* a band holds tiles from a previous fill, while a standing composite
implies a scale change, which disposes every tile. `viewportCovered` was never
the observable this proof needed.

### M24 — fired, survives, and the survival was predicted before it was fired

**Mutation:**

```diff
       if (!bandMissing) {
-        for (final key in band.keys) {
-          _lastUsedFrame[key] = _frameSerial;
-        }
         continue;
       }
```

**Procedure:** as M23, plus a scratch probe built to *be* the arm and run under
both variants. `bandCrossingGrid`, settled from bands; then *n* pans of exactly
one tile (64 device pixels, so the visible key count stays 130 and the pricing
minimum stays `143t`), each settled — which leaves 10 stale keys per pan and
nothing else; then `cacheBytes = 143 * 16384 = 2342912`; then
`moveOneEntityWithinOneBand` and a settle. That is the tightest legal cap with
a real eviction load inside a rest bake that skips nine of its ten bands. It
was **not landed**: it distinguishes nothing, and a test that cannot fail is
the finding it was written to close. The file
(`test/zz_scratch_m24_probe_test.dart`) was deleted; nothing untracked remains.

**Before the mutation:**

```
PROBE pans=0 held=130 afterCap=130 bytesAfterCap=2129920 evictionsDuringEdit=0 liveTiles=130 covered=true liveDraws=2 bakes=142 liveBytes=2129920 cap=2342912
PROBE pans=1 held=140 afterCap=140 bytesAfterCap=2293760 evictionsDuringEdit=0 liveTiles=137 covered=true liveDraws=2 bakes=185 liveBytes=2244608 cap=2342912
PROBE pans=3 held=160 afterCap=160 bytesAfterCap=2621440 evictionsDuringEdit=8 liveTiles=143 covered=true liveDraws=2 bakes=199 liveBytes=2342912 cap=2342912
PROBE pans=6 held=190 afterCap=190 bytesAfterCap=3112960 evictionsDuringEdit=29 liveTiles=143 covered=true liveDraws=2 bakes=220 liveBytes=2342912 cap=2342912
00:00 +4: All tests passed!
```

**After it:**

```
PROBE pans=0 held=130 afterCap=130 bytesAfterCap=2129920 evictionsDuringEdit=0 liveTiles=130 covered=true liveDraws=2 bakes=142 liveBytes=2129920 cap=2342912
PROBE pans=1 held=140 afterCap=140 bytesAfterCap=2293760 evictionsDuringEdit=0 liveTiles=137 covered=true liveDraws=2 bakes=185 liveBytes=2244608 cap=2342912
PROBE pans=3 held=160 afterCap=160 bytesAfterCap=2621440 evictionsDuringEdit=8 liveTiles=143 covered=true liveDraws=2 bakes=199 liveBytes=2342912 cap=2342912
PROBE pans=6 held=190 afterCap=190 bytesAfterCap=3112960 evictionsDuringEdit=29 liveTiles=143 covered=true liveDraws=2 bakes=220 liveBytes=2342912 cap=2342912
00:00 +4: All tests passed!
```

The `pans=3` and `pans=6` rows are the ones that matter: 8 and 29 evictions
happen *during* the edit frame, at a `liveBytes` landing exactly on the cap,
with nine of ten bands skipped — and the coverage, the tile count and the
eviction count are identical with the stamp and without it.

The **whole package suite** is also green under the mutation: 413 passing, 1
skipped, the same as with it.

**Restore:** `diff` against the pre-mutation copy printed nothing; the package
suite green again (the gate below).

### What was done instead of the arm

* **The production stamp stays.** It is what the ceiling proof cites — at band
  `i` the set `_makeRoomForBytes` may not evict is the keys of bands `0..i-1` —
  and it costs one map write per key of a skipped band. It is the belt to the
  pricing's braces, and a future change to the pricing would make it
  load-bearing rather than redundant.
* **The test's comment was rewritten** to say what it actually gates — that a
  skipped band's tiles are still standing and still blitted afterwards, nothing
  evicted and the generation exactly as large as before — and to record, with
  the arithmetic, that the stamp itself is unobservable, pointing at M24.
* **No production seam was added.** Gating the stamp needs an instrument that
  can see intra-frame victim selection: a debug hook on `_evict`, or exposure of
  `_lastUsedFrame`. The brief forbids adding one for this, and the derivation
  says such an instrument would be gating an invariant that the up-front pricing
  already makes unreachable.

---

## Gate

`packages/jet_cad_2d_flutter`:

```
00:06 +411 ~1: .../test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:06 +412 ~1: .../test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:06 +413 ~1: All tests passed!
--- analyze
Try `flutter pub outdated` for more information.
Analyzing jet_cad_2d_flutter...                                 
No issues found! (ran in 1.2s)
--- format
Formatted 73 files (0 changed) in 0.13 seconds.
```

`packages/jet_cad_2d`:

```
00:03 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +797: All tests passed!
--- analyze
Analyzing jet_cad_2d...
No issues found!
--- format
Formatted 113 files (0 changed) in 0.20 seconds.
```

`apps/dev_harness_2d`:

```
00:16 +45: .../test/zoom_script_test.dart: the focal point is off-centre
00:16 +46: All tests passed!
```

**Counts against the baselines.** `packages/jet_cad_2d` 797, unchanged.
`packages/jet_cad_2d_flutter` 411 → **413** with 1 skip: the two new arms and
nothing else. `apps/dev_harness_2d` 41 → **46**, all five from the parallel
wave's `85e0726`/`001599b`; this wave did not touch that package and ran it only
to prove it is not broken.

No `analysis_options.yaml` was staged. No golden PNG was regenerated. Nothing
was reverted by `git checkout`; the two mutation restores were `cp` from
scratch copies with an empty `diff` each.

---

## Concerns

1. **The pan tail's frame now costs a live walk it did not cost before.** That
   is the point — the alternative is a background flash — but it is a real
   frame-cost change on the pan path, and D8 says the pan path is untouched.
   The reading taken here is that D8 protects the pan's *pixels and bakes*, and
   this frame now does exactly what the pan frames either side of it do; it is
   not a new class of work. If a reviewer reads D8 more strictly, the honest
   alternative is to accept the flash, and that was the state the review
   rejected.
2. **`_lastChangeWasPan` stays true across an arbitrarily long rest.** After a
   pan settles, the bit is still true on every subsequent frame; `resting` is
   already true on those through the count, so the bit changes nothing there,
   but it does mean the bit is not "the previous frame was a pan" — it is "the
   last change was a pan", which is what the doc comment says and what the
   comment on the assignment explains.
3. **M24's survival rests on the up-front pricing.** If a future change relaxes
   `bandBytes + visibleTiles * t <= cacheBytes` — for instance pricing only the
   *missing* tiles rather than all visible ones — clause 3 of the derivation
   breaks, the stamp becomes load-bearing, and the arm the review asked for
   becomes buildable. That is worth a note wherever that pricing is next
   touched; the mutation-log entry carries the derivation so the connection is
   findable.
4. **The two new arms are rig tests, so they never exercise `DraftCanvas`.**
   They cannot: the widget capture asserts on a dirty repaint boundary, which is
   precisely the state these frames leave. The scheduling half — that
   `DraftCanvas` really does ask for the tail frame — is argued from
   `draft_canvas.dart`'s `if (!cache.viewportCovered) onUnsettled?.call()` and
   asserted in the rig as `viewportCovered` being false, not measured through
   the widget.
