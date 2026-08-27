# Plan 3i — the zoom frame

**Date:** 2026-08-26. **Base:** `main` at `026b873`. **Revised twice** the same
day, after three external reviews and then two more; §10 records what each
round changed and the one finding that was rejected.

**Goal.** Make the zoom gesture cheap and the sharpening that follows it
immediate, by splitting the tiled frame into two regimes: a **moving** frame
that draws only the carry-over composite, and a **resting** frame that walks
the visible region in tile-row bands and slices each band into tiles. Measured at 50,000 and 500,000
entities.

**What this plan does not do.** It does not deliver level-of-detail geometry.
G3 stays open and blocks nothing after this plan — see §8.

**The success criterion the human chose**, and every decision follows from it:
*the gesture stays smooth even if what it shows is stale, and the drawing
snaps to full resolution when the gesture ends.* Map-application behaviour. A
correct frame **during** a pinch was considered and rejected as this plan's
target; that is what would require LOD.

**The second thing the human chose**, in review: on a zoom **out** the
composite shrinks and opens a ring at the edge, and **that ring is left as
background until the gesture ends**. See D3.

**Prior art this spec argues from:**

- [2026-08-23-picture-cache-price-spike.md](../notes/2026-08-23-picture-cache-price-spike.md)
  — at 500,000 entities a whole-viewport bake is **32.06 ms** against
  **40.27 ms** live and **1.61 ms** to blit. §9 records what is soft about
  that figure.
- [2026-08-24-plan-3g-results.md](../notes/2026-08-24-plan-3g-results.md) —
  measured leaf overdraw at a 512-pixel tile is **4.185x**; a whole-generation
  tiled walk is **71.97 ms** against a per-tile bake of **12.56 ms**; and the
  one-tile budget "spread the work across roughly 11 frames of 30–40 ms —
  about 350–450 ms of catch-up after every zoom", labelled there as an
  inference rather than a measurement.
- `STATUS.md`,
  [After Plan 3h](../../../STATUS.md#after-plan-3h--what-the-window-showed-2026-08-26)
  — measured 2026-08-26: one zoom step takes a covered generation of 12 tiles
  to **1**, and a 20-step gesture takes the generation counter from 2 to
  **22** while the tile count never rises above 1.

**Prior art this spec depends on having landed:** `967fa3b`, the tile-settle
fix. The resting frame this plan defines **is** the frame that fix schedules.

---

## 1. What is wrong, stated once

Three facts, all measured.

1. **Every scale change drops every tile.** `_gridFor` calls
   `_retireGeneration` whenever `matchesScale` fails
   (`tile_cache.dart:1017-1020`). One instrumented trackpad pinch logged 709
   `PointerPanZoomUpdateEvent`s, so a gesture is hundreds of retirements.

2. **Each of those frames still bakes one tile, and the next frame discards
   it.** The budget permits exactly one tile
   (`kBakeBudgetDevicePixels = 262144`, floored to 1 at `:535-538`).

3. **The settle is slow because it is rationed, and the ration is one tile
   because a tiled pass costs several times what one walk costs.** Both halves
   are needed and the second is what the design attacks. The catch-up is
   ~11 frames because 11 tiles is what the viewport holds and the budget
   permits one per frame; the reason a larger budget was refused is that a
   512-pixel tile bakes in 12.56 ms and two of them exceed the frame. One
   viewport walk is 32.06 ms against a tiled generation walk of 71.97 ms, and
   the gap is the **4.185x** overdraw a tiled pass pays because an entity
   larger than a tile is walked once per tile it crosses.

**Fact 3 was overstated in the first draft** — it said the cause was overdraw
and not the budget. Three reviews caught it, and `STATUS.md` records "a stated
cause stronger than its evidence" as this project's recurring failure. The
ration and the tiling are one mechanism: the ration exists *because* tiling
made a single tile expensive, and removing the tiling is what makes the ration
unnecessary.

---

## 2. Decisions

**D1 — Three frame kinds, and the resting one has a precondition.** A frame is
*moving* if its quantised scale fails `matchesScale` against the current
generation's anchor. A frame qualifies for a **rest bake** only when all three
hold: the scale matched, the generation does not cover the viewport, and the
**whole quantised camera** — scale *and* translation — has been unchanged for
two consecutive frames.

**Translation is in that clause and not only scale.** Immediately after a
zoom the generation is empty, so a pan that follows keeps the scale and does
*not* cover the viewport: under a scale-only rule two same-scale pan frames
would satisfy every condition and spend a full bake while the camera is still
moving. Requiring the camera to be unchanged excludes that, and still excludes
an ordinary pan over a covered generation by the second clause, which is what
keeps D8 true.

**The third kind is the frame in between**, which matched once and has not yet
matched twice. It draws exactly what a moving frame draws: the composite, and
nothing else. Left undefined it would fall through to the ordinary tile loop —
bake one tile, `uncovered` bounds to the whole viewport, and on a zoom out a
full-viewport live walk lands once per gesture, which is the frame D3 exists to
prevent.

**A scale-changing frame does not count toward the two matches.** It fails
against the outgoing grid and would match the grid it just installed; the
counter resets on any change and starts from the first frame that changed
nothing.

**The two-frame clause is the wheel's.** A mouse wheel delivers isolated
notches, so without it every notch is one moving frame followed immediately by
a resting frame — a full bake per notch, discarded by the next notch, and
invisible to any criterion that only watches moving frames. Two consecutive
unchanged cameras cost one frame of latency (~16.7 ms) and make a continuously
spun wheel bake nothing.

**D2 — No gesture-end event.** The regime is derived, not reported. A mouse
wheel has no gesture-end event and a trackpad does; deriving serves both and
keeps `TileCache` free of input concepts.

**D3 — A moving frame draws the composite and nothing else.** No bake, and
**no live walk**. On a zoom in the composite magnifies past the viewport edges
and covers it. On a zoom out it shrinks and leaves a ring, and **the ring is
background until the gesture ends** — the human's decision in review.

The alternative was measured before it was rejected. On a moving frame the new
generation is empty, so every visible key misses, `uncovered` accumulates by
`expandToInclude` into the **whole viewport** rather than a ring
(`tile_cache.dart:786-807`), and `stripFor` clamps to the viewport. "Walk the
uncovered region" is therefore a full-viewport live walk — 31.5–41.6 ms at
500,000 entities — on **every** zoom-out frame. Splitting criterion 2 by zoom
direction would have hidden exactly the worst case §6 clause 1 exists to
expose.

**D4 — A resting frame bakes the tile-aligned region in bands and slices each
band.** The source is **not** the viewport. `visibleKeys` yields "every key
covering the viewport, as a full rectangle" (`:263-278`), including tiles that
extend past it; a viewport-sized source has no pixels for those overhangs, and
a tile marked present with a transparent overhang blits that transparency on
the next small pan.

**Bands, not one image, and D5 says why.** The region is walked one tile row
at a time. Each band is the union's full width and one tile tall.

The sequence inside the frame:

1. Drop the carry-over composite. The frame is about to draw real content and
   does not need it.
2. For each band: one walk into one `Picture`, one `toImageSync`, then one
   `PictureRecorder` + `drawImageRect` + `toImageSync` per key in that band,
   then release the band image before starting the next.
3. No band image outlives its band.

Four things about that walk are load-bearing and are decided here rather than
left to the implementer:

- **The query is padded, the clip is not.** A stroke whose centreline lies
  just outside a band still inks inside it. `_bake` already handles this by
  querying padded and clipping hard (`:1442-1535`), and the band pass does the
  same: query the band expanded by `kTileSlack`, clip to the unexpanded band.
  Dropping this is M9.
- **The rebase origin is the viewport's**, `rebaseOriginFor(quantised.
  visibleWorld(viewport))`, exactly as `paintFrame` derives it today. Deriving
  it from a band's own region gives each band a different `float32` residual —
  the thing the frame-global rule exists to prevent — and can cross a
  power-of-two step. Dropping this is M11.
- **Slice rectangles are source-local.** A key's device rectangle is in grid
  space and goes negative as soon as a same-scale pan moves the key range, so
  the copy reads `keyDeviceRect - bandDeviceRect.topLeft`, never the grid-space
  rectangle. Dropping this is M10.
- **Step 2's per-key work is a texture copy, not a geometry raster**, and that
  is the whole difference from the rejected Approach B. Both use a recorder and
  `toImageSync`; B re-rasterises geometry per tile, C copies pixels. The first
  draft's "one `toImageSync`" was wrong: the call count is **bands + keys**.

**D5 — Memory: bands exist because one image does not fit.** The first
revision priced the source at the viewport's ~29.3 MiB while D4 had already
made it the union of visible keys. Those are not the same thing:
`visibleKeys` yields a full rectangle, so the union has **exactly the area of
the tile set it will be sliced into** — 48 MiB at the 3200x2400 reference
viewport, not 29.3.

One source image therefore peaks at source 48 + tiles 48 = **96 MiB against a
`kTileCacheBytes` of exactly 96 MiB** (`:164`), with the composite already
dropped. Zero headroom, and the failure is not a soft overrun:
`_makeRoomForOneTile` refuses any tile whose last-used frame is the current
one (`:942`), which is every tile the slice loop just wrote, so at the cap it
returns false, the tail of the loop emits nothing, and the generation never
covers. Criterion 3 fails — and M2 stops being distinguishable from correct
code under a cap.

**One tile row at a time is the answer, and raising the cap is not.** A band is
8 MiB at the reference viewport, so the peak is 8 + 48 = **56 MiB**. The cost
is one walk per band instead of one for the region; bands are full width, so
crossing multiplicity is paid on horizontal boundaries only and is nothing like
the 4.185x a 48-tile pass pays. Raising `kTileCacheBytes` was rejected because
Plan 3j already inherits a 192 MiB vertex buffer sitting on a doubling boundary
with no headroom, and spending memory here would prejudge that reckoning.

**The ceiling holds inside the frame.** The slice **bypasses
`budgetedTilesPerFrame`** — the budget rations bakes and a slice is not a bake
— but it does not bypass the ceiling: the "consult before, not after" rule the
tile loop already follows applies to each sliced tile, and criterion 7 gates it
with an instrument that can actually see the band image.

**D6 — Sliced tiles inherit the walk's visited set, so invalidation still
works.** `_invalidateTouched` condemns tiles by iterating `_baked` in both
directions (`:1170`, `:1203`), and `_bake` is what writes a tile's `_baked`
record (`:1527`). A sliced tile with no record is invisible to invalidation:
edit an entity after a settle and the stale tile keeps blitting over the
corrected drawing, with `invalidationCount` reading zero. **This is a
correctness defect, not a performance one, and the first draft did not mention
`_baked` at all.**

Each band's walk produces one visited set, and **every tile sliced from that
band takes that same set, shared by reference** — one `Uint32List` per band,
one map entry per tile. Invalidation therefore becomes band-coarse rather than
tile-precise: a touched handle condemns its whole band, and the next resting
frame rebakes. That is the right trade, because a band is exactly the unit a
rebake walks anyway, so condemning one costs one walk and never N.

Direction two is unaffected and stays geometrically precise: it iterates
`_baked.keys` and asks what the edit's new geometry reaches (`:1203`), which
is a question about tile rectangles, not about what a bake visited.

**D7 — Slicing removes the seam *between tiles*, and the pad still does work
at the region's edge.** The first revision said the pad was simply absent from
this path. That is wrong at the boundary: the band pass performs one query, and
a stroke centred just outside the band inks inside it, so the query is padded
by `kTileSlack` and the clip is hard — D4 states it and M9 fires at it.

What slicing does remove is the seam *class*: separately rasterised
neighbours sample one stroke twice at different sub-pixel offsets, and tiles
cut from one rasterisation cannot. `_bake`'s own comment states the rule the
pad follows — the query is padded, the clip is not (`:1490`). Inside a band
there are no per-tile queries and therefore no per-tile clips to disagree.

**D8 — The pan path is untouched.** After a rest bake the tiles are ordinary
tiles, complete out to their own boundaries (D4), blitted while they cover and
baked one at a time at the edge as a pan reveals new ones. Criterion 9 exists
to prove this plan did not disturb it.

**D9 — Approach C, and the two it beat.** *A*, one viewport image and no
tiles, was rejected: the next pan finds nothing. *B*, one recorded picture
rasterised per tile, was rejected because per-tile geometry rasterisation is
what C replaces with a texture copy. A review argued C collapses into B
because both need a recorder per tile; **that is rejected** — the recorder is
not the cost, the geometry is.

---

## 3. The seam, as a consequence rather than a goal

Gap G1 says software Skia does not antialias `drawVertices`, so no widget test
here can produce an antialiased seam; the instrument is a human looking at a
GPU, and `--dart-define=CORPUS=simple` provides the drawing.

D7 has a consequence worth gating: **a generation cut from a single
rasterisation has no seam class at all.** It says nothing about the composite
during a gesture, which is stale by construction, and nothing about the
background ring D3 leaves on a zoom out. Criterion 6 measures the settled
generation and nothing else.

---

## 4. Criteria

Ten, all failable, every threshold named here.

| # | Criterion | Instrument |
|---|---|---|
| 1 | A moving frame bakes **zero** tiles and draws **zero** live geometry | scripted zoom, bake counter and painter's leaf counter |
| 2 | Moving-frame p95 within 16.67 ms, at 50,000 and 500,000 | rig, a new `tile zoom` phase |
| 3 | The settle completes in **one** frame, read off `totalSpan` | `viewportCovered`, frame count, `totalSpan` |
| 4 | Rest-bake wall clock **>= 3x** cheaper than the tiled fill it replaces | same session, interleaved |
| 5 | A sliced generation is **identical to a live frame** | 3g/3h's differential instrument |
| 6 | **Zero** difference at tile boundaries in a settled generation | pixel sweep against a live capture |
| 7 | `liveBytes <= kTileCacheBytes` at **every point inside** the rest frame, **counting the band image**, and every band image is released | `liveBytes` extended to count the live band, cross-checked against `debugImagesAlive` |
| 8 | Plan 3h's criterion 3, re-measured at **n=7–9 interleaved** | rig |
| 9 | The pan path does not regress | Plan 3h's existing gate |
| 10 | An edit **after** a settle invalidates the sliced tiles | `invalidationCount`, the 3g/3h invalidation matrix |
| 11 | A settled generation is identical to live **after a sub-tile pan**, and after a pan taken *between* the last scale change and the rest bake | differential, two extra arms |

**Criterion 7's instrument had to be extended, not merely pointed at.**
`liveBytes` sums `_tiles` and `_carryOver` and nothing else (`:572`), so a
resident band image is invisible to it and the criterion would have read green
inside exactly the window it exists for. It counts the live band image for as
long as one exists, and `debugImagesAlive` (`:615`) is the cross-check.

**Criterion 11 exists because criterion 9 cannot see a transparent blit.**
M7 — the source is the viewport rather than the tile-aligned union — leaves an
edge tile with a transparent overhang, and a transparent blit costs exactly
what an opaque one costs, so Plan 3h's p95 pan gate is blind to it. It needs a
differential: rest-bake, pan by less than one tile, compare against live. The
second arm is M10's: a pan taken between the last scale change and the rest
bake moves the visible key range so the first key's grid-space rectangle goes
negative, which a pure zoom script never produces.

**Criterion 3 must read `totalSpan`.** The price-spike note this spec argues
from records that `toImageSync` returns before the raster it schedules, that
build and raster both read free for a 13.56 ms arm, and that every bake
conclusion there was read off `totalSpan`. A criterion counting Dart-side
frames would certify a one-frame settle that spills into the next.

**Criterion 4 names its numerator and denominator, because the first draft did
not and the two readings straddled its own gate.** It is **wall clock to a
covered viewport, from the first frame after the gesture ends to the frame
that covers it**: the rest-bake arm is one frame; the tiled arm is today's
behaviour with the rest bake disabled. Work-for-work (71.97 vs 32.06 = 2.25x)
is *not* the measurement — that comparison would fail a 3x gate while the
behaviour improved by an order of magnitude, and picking whichever reading
passes after the fact is exactly what §4 exists to prevent.

**Criterion 4's arrangement is part of the criterion.** Plan 3h's headline
criterion missed at 2.35 against a gate of 2.4 that had been mis-derived from
a cross-session numerator. Criterion 4 is therefore *same session, interleaved
(rest, tiled, rest, tiled, …), never blocked*, and 3x is chosen with headroom
against a prediction that is **~40x at the pinned reference viewport** — the
~11x a reader might carry over belongs to the 800x600 viewport where the
generation is 12 tiles, not 48.

**Criterion 6 has to name the alignment rule or it is a restatement of M3.**
The slice source rectangle is `destRectFor(key)` scaled by `devicePixelRatio`,
it **must be integral**, and the copy is sampled at `FilterQuality.none`. The
integrality exists only because `quantiseCamera` puts the camera on whole
device pixels; that invariant is load-bearing for criteria 5 and 6 and is
asserted, not assumed.

**Criterion 8 is Plan 3h's open wound**, handed here. n=3 cannot settle
whether 2.35 is real or noise. **The gate is the arrangement and the report,
not the number.** If the ratio still reads below 2.4 at n=9 interleaved, that
is an answer and is recorded as one.

---

## 5. The measurement script, pinned

A gate whose script is not reproducible is not failable. The `tile zoom` phase
is defined here and not left to the implementer:

- **Viewport 1600x1200 logical at `devicePixelRatio` 2** — the 3200x2400
  reference viewport every memory figure in this spec is priced against, and
  **not** the 800x600 test viewport the 2026-08-26 frame counts were taken at.
  The first revision quoted both without saying which was which, reproducing
  inside a freshly pinned script the very omission §9 flags in the 32.06 ms
  figure.
- **Start** from R2's existing fitted camera, so the zoom arm and the pan arm
  share a starting state.
- **Focal point** off-centre, at 30% / 70% of the viewport, so the anchor is
  not the trivial centre.
- **40 steps in, then 40 steps out**, factor 1.03 per step — a span of about
  3.26x each way, which crosses at least one power-of-two rebase boundary
  (§6 clause 3).
- **One camera change per frame**, matching what a trackpad delivers.
- **Then 30 idle frames**, which is where criteria 3 and 4 are read.
- **p95 over the 80 gesture frames**, warm-up excluded by resetting counters
  after the fitted camera settles.
- **The interleaved unit for criteria 4 and 8 is one whole arm**, not one
  frame: arms alternate, and the report gives every arm's number, not only the
  aggregate.

---

## 6. The anti-degenerate rule

Five clauses. A gate whose fixture or script fails any of them is vacuous.

1. **The script goes both in and out.** Zoom out opens the ring D3 leaves and
   zoom in does not. A script that only zooms in cannot see criterion 1's
   zero-live-geometry claim where it matters.
2. **The fixture contains entities larger than one tile.** Crossing
   multiplicity produces the 4.185x overdraw, which is what the design
   attacks. A fixture of tile-sized entities makes criterion 4 unfailable.
3. **The script crosses at least one power-of-two rebase-origin boundary.**
   `rebaseOriginFor` snaps to a step derived from the view span
   (`camera_controller.dart:18-32`), so a script inside one step never
   re-quantises.
4. **Both corpora, 50,000 and 500,000.** The win scales with the drawing.
5. **Neither the camera nor the fixture sits at the identity or the origin** —
   the standing rule, restated because a zoom fixture is exactly where someone
   reaches for a clean scale of 1.0 at (0, 0).

---

## 7. Named mutants

Eleven. Ten must die; M8 is written down as a survivor **before** it is fired.

| | Mutation | Killed by |
|---|---|---|
| M1 | keep baking on a moving frame | criterion 1 |
| M2 | the slice loop emits only the first tile | criterion 3 |
| M3 | the slice source rectangle ignores the tile offset | criteria 5 and 6 |
| M4 | the rest bake fires on every frame, not only at rest | criterion 2 |
| M5 | the sliced tiles record no `_baked` | criterion 10 |
| M6 | the source image is never released | criterion 7 |
| M7 | the source is the viewport, not the tile-aligned union | criterion 11 — an edge tile blits its transparent overhang after a sub-tile pan |
| M8 | slice at `FilterQuality.low` | **nothing — a deliberate survivor** |
| M9 | the band query is not expanded by `kTileSlack` | criterion 5, on a fixture with strokes thick enough to cross a band edge |
| M10 | slice rectangles stay in grid space instead of band-local | criterion 11's second arm |
| M11 | the rebase origin is derived from the band, not the viewport | criterion 5, on an arm placed near a power-of-two rebase boundary |

**M8 survives by construction and is recorded, not gated.** With integral
source rectangles a bilinear sample and a nearest sample read the same texels,
so no pixel changes; only a sampler is paid for. Plan 3h's M6 — narrowing the
clip — had exactly this shape and was recorded as gap H6 rather than dressed
in a gate that could not see it.

**The first draft's M5 was "keep the pad when slicing" and was meaningless.**
It was replaced in the second revision, and the third corrected the reasoning
behind it too: the slice performs no query, but the *band pass* does, and that
query is padded. M9 is the mutant that belongs there.

**M7's killer moved.** It was pointed at criterion 9, Plan 3h's p95 pan gate,
which cannot see it: a transparent blit costs exactly what an opaque one
costs. One of the four blocking findings from the second round had landed on a
gate blind to it, which is the shape §7 exists to catch.

---

## 8. Accepted gaps

- **G3 — level-of-detail geometry. Still open, and after this plan it blocks
  nothing.** A correct frame during a gesture remains a 32–40 ms frame at
  500,000 entities. This plan does not make that frame faster; it stops
  drawing it during a gesture. G3 becomes necessary the day the target changes
  to correct geometry while the fingers are still moving.
- **The zoom-out background ring.** D3 leaves it, by the human's decision.
  What it looks like at speed is a judgement for a human with the window open,
  and no criterion here measures it.
- **An edit landing mid-gesture.** `applyChange` drops the carry-over
  (`tile_cache.dart:1128`). A moving frame then has no composite and, under
  D3, draws nothing at all until the gesture ends. Rare, recorded, ungated.
- **The resting frame's length is not gated.** D5's peak is gated; its
  duration is not. A slower machine shows a longer hitch and this plan will
  not have measured how much longer.
- **Antialiasing on the vertices backend.** `drawVertices` ignores
  `isAntiAlias` and `defaultRenderBackend()` returns it, so edge quality is
  the surface's MSAA. Recorded in `STATUS.md`; not this plan's subject.

---

## 9. What is soft in the numbers this spec quotes

Stated here rather than left for a reader to discover.

- **32.06 ms was n=1**, taken on the `TEXT=true` corpus, and the note does not
  record the viewport size or device pixel ratio. It is the right order of
  magnitude and it is not a derivation. D5's "~32 ms" inherits that softness,
  which is one more reason the resting frame's duration is not a gate.
- **4.185x came from a probe that reimplements `_bake`** rather than calling
  it (3g finding 12). It is the right evidence for the *shape* of the win and
  this spec should not be read as having measured the shipped path.
- **350–450 ms was labelled an inference by the note that produced it.** The
  frame *count* was measured on 2026-08-26; the milliseconds were not.
- **The per-key texture copy is unmeasured.** D9 rejects Approach B on the
  argument that the recorder is not the cost, the geometry is. That is almost
  certainly right, but `bands + keys` recorder-and-`toImageSync` calls have
  never been timed here; the nearest datum is 1.61 ms for one whole-viewport
  blit. It is the one number the rejected review finding turns on, and the
  results note should measure it rather than inherit the argument.

---

## 10. What the reviews changed

Five external reviews over two rounds. Nineteen findings accepted, one
rejected, none deferred.

**Round one, blocking:** `_baked` was never mentioned and dropping it is a
correctness defect (D6, criterion 10, M5); `visibleKeys` yields tiles that
overhang the viewport, so a viewport-sized source produces incomplete edge
tiles (D4, M7); the peak exceeds the byte cap (D5); a moving frame's "live walk
over the uncovered region" is a full-viewport walk, so criterion 2 was
unmeetable on every zoom-out frame (D3, and the human's decision to leave the
ring).

**Round one, structural:** the resting regime had no precondition (D1); a
mouse wheel would bake once per notch (D1); criterion 4's ratio had two
readings straddling its own gate (§4); §1 fact 3 stated a cause stronger than
its evidence (§1); criterion 3 could not see raster spill (§4); criterion 6
required the source image the design releases (§4); the old M5 was meaningless
(§7); the script was not pinned (§5).

**Round two, blocking, and every one of them is the same shape — a gate that
went blind when the design changed under it:**

- **The memory arithmetic was internally inconsistent.** D4 made the source
  the union of visible keys; D5 kept pricing it as the viewport. The union is
  a full rectangle, so it has the tile set's own area: 48 MiB, not 29.3, and
  one source image peaks at exactly the 96 MiB cap with no headroom. The
  failure is hard, not soft — `_makeRoomForOneTile` cannot evict a tile this
  frame wrote, so the slice loop's tail emits nothing and M2 becomes
  indistinguishable from correct code under a cap. **Bands are the answer**
  (D5), and raising the cap was rejected because Plan 3j inherits a memory
  reckoning this plan must not prejudge.
- **Criterion 7's instrument could not see what criterion 7 gates.**
  `liveBytes` counts tiles and the composite and nothing else, so a resident
  source image is invisible to it (§4).
- **M7's killer could not see M7.** A transparent blit costs what an opaque
  one costs, so criterion 9's p95 gate is blind to an edge tile's overhang.
  Criterion 11 was added for it.
- **The slice rectangle was specified in the wrong coordinate space.** A key's
  device rectangle is grid-space and goes negative after a same-scale pan;
  the copy must read band-local. The pinned pure-zoom script would never have
  produced the case, so criterion 11 carries a second arm and M10 fires at it.
- **The band query still needs the pad.** D7 had concluded the pad was simply
  absent because there are no per-tile queries. There is still one query per
  band, and a stroke centred just outside it inks inside it. D4 states the
  rule `_bake` already follows and M9 fires at its removal.
- **The rest pass's rebase origin was unpinned.** Deriving it from the band
  rather than the viewport gives each band its own `float32` residual and can
  cross a power-of-two step — the exact thing the frame-global rule prevents.
  M11 fires at it.
- **A pan straight after a zoom would have rest-baked mid-pan.** The
  generation is empty then, so two same-scale pan frames satisfied every
  condition. D1 now requires the whole quantised camera to be unchanged.
- **A third frame kind was undefined.** The frame that matched once and not
  yet twice fell through to the ordinary tile loop and, on a zoom out, took a
  full-viewport live walk once per gesture — the frame D3 exists to prevent.

**Round two, minor:** the spec quoted two viewports without distinguishing
them, inside the section that pins the script (§5), and the ~11x prediction
belongs to the smaller one (§4); criterion 6 attributed slice integrality to
`quantiseCamera` when it comes from `deviceDeltaFrom`'s `.round()` (§4); the
per-key texture-copy cost is unmeasured and now says so (§9).

**Rejected, both rounds:** that Approach C collapses into Approach B because
both need a recorder and `toImageSync` per tile. The recorder is not the cost.
B rasterises geometry per tile; C copies texels. §9 records that this argument
is unmeasured, which is the honest form of holding the position.

**Left for the plan, not the spec:** `STATUS.md` still describes 3i as "zoom,
G3, and level-of-detail geometry" and says the answer is level-of-detail
geometry. This spec declines LOD in its second paragraph. That is reconciled
when the plan lands, not before, so the two documents are never
half-updated against each other.

## 11. Files

- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — the two regimes, the
  rest bake, the slice, the shared `_baked` record. The bulk of the change.
- `packages/jet_cad_2d_flutter/test/` — a zoom-regime test file; extensions to
  the differential, invalidation and invariant instruments for criteria 5, 6,
  7 and 10.
- `apps/dev_harness_2d/lib/measurement_rig.dart` — the `tile zoom` phase §5
  pins, and the interleaved arrangement criteria 4 and 8 require.
- `docs/superpowers/notes/` — the results note and the mutation log.

`packages/jet_cad_2d` is pure Dart and **this plan does not touch it.**
