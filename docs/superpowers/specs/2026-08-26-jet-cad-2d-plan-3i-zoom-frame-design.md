# Plan 3i — the zoom frame

**Date:** 2026-08-26. **Base:** `main` at `559e01b`.

**Goal.** Make the zoom gesture cheap and the sharpening that follows it
immediate, by splitting the tiled frame into two regimes: a **moving** frame
that bakes nothing, and a **resting** frame that bakes the viewport once and
slices it into tiles. Measured at 50,000 and 500,000 entities.

**What this plan does not do.** It does not deliver level-of-detail geometry.
G3 stays open and is explicitly **not** blocking after this plan — see §6.

**The success criterion the human chose**, and every decision below follows
from it: *the gesture stays smooth even if what it shows is stale, and the
drawing snaps to full resolution when the gesture ends.* Map-application
behaviour. A correct frame **during** a pinch was considered and rejected as
this plan's target; that is what would require LOD.

**Prior art this spec argues from:**

- [2026-08-23-picture-cache-price-spike.md](../notes/2026-08-23-picture-cache-price-spike.md)
  — at 500,000 entities a whole-viewport bake is **32.06 ms** (build 17.66,
  raster 1.13) against **40.27 ms** live and **1.61 ms** to blit.
- [2026-08-24-plan-3g-results.md](../notes/2026-08-24-plan-3g-results.md) —
  measured leaf overdraw at a 512-pixel tile is **4.185x**, because an entity
  larger than a tile is walked once per tile it crosses; and the one-tile
  budget "spread the work across roughly 11 frames of 30–40 ms — about
  350–450 ms of catch-up after every zoom — which no criterion in this exit
  gate measures", labelled there as an inference, not a measurement.
- `STATUS.md`,
  [After Plan 3h](../../../STATUS.md#after-plan-3h--what-the-window-showed-2026-08-26)
  — measured 2026-08-26 at 800x600, dpr 2, 512-pixel tiles: one zoom step
  takes a covered generation of 12 tiles to **1**, and a 20-step gesture takes
  the generation counter from 2 to **22** while the tile count never rises
  above 1. The gesture bakes twenty tiles and discards twenty.

**Prior art this spec depends on having landed:** `967fa3b`, the tile-settle
fix. Before it, a camera that stopped stopped frame production with it and the
cache never finished. The resting frame this plan defines **is** the frame
that fix schedules; without it there is nothing to put the rest bake into.

---

## 1. What is wrong, stated once

Three facts, all measured, that together describe the whole defect.

1. **Every scale change drops every tile.** `_gridFor` calls
   `_retireGeneration` whenever `matchesScale` fails. A trackpad pinch
   delivers hundreds of scale changes — one instrumented gesture logged 709
   `PointerPanZoomUpdateEvent`s — so a gesture is hundreds of retirements.

2. **Each of those frames still bakes.** The bake budget permits one tile,
   and that tile is discarded by the next frame's retirement. The work is not
   quite waste — the tile is blitted once — but it buys one twelfth of one
   frame for a full tile bake.

3. **Filling a generation tile by tile costs about ten times what drawing the
   same viewport once costs.** 32.06 ms for one viewport bake against the
   350–450 ms of catch-up 3g inferred. The cause is not the budget; it is the
   **4.185x** overdraw a tiled walk pays and a single walk does not.

Fact 3 is the one that decides the design. The settle is not slow because it
is rationed; it is slow because it is tiled.

---

## 2. Decisions

**D1 — Two regimes, told apart by scale equality.** A frame is *moving* if its
quantised scale differs from the previous frame's, and *resting* otherwise.
`_gridFor` already computes this (`matchesScale`); nothing new is measured and
no new interface is needed.

**D2 — No gesture-end event.** The regime is derived, not reported. A mouse
wheel has no gesture-end event and a trackpad does; deriving the regime serves
both, and keeps `TileCache` free of input concepts.

**D3 — A moving frame bakes nothing.** It blits the carry-over composite and,
where the composite does not cover, walks live over the uncovered region — the
Plan 3h path, unchanged. Zoom *in* magnifies the composite past the viewport
edges and covers; zoom *out* leaves a ring that the live walk owes.

**D4 — A resting frame bakes the viewport once and slices it.** One walk into
one `Picture`, one `toImageSync` to a viewport-sized image, then one
`drawImageRect` per visible tile key to cut that image into tile images. The
transient viewport image is released in the same frame.

**D5 — One long resting frame is accepted, not budgeted.** ~32 ms at 500,000
entities, more on a slower machine. The screen is static when it happens, so a
dropped frame is not visible. **The human accepted this trade explicitly**;
criterion 2 gates the *moving* frame, and no criterion gates the resting one.

**D6 — Sliced tiles carry no pad.** `kTileSlack`'s 32 logical pixels exist
because separately rasterised neighbours sample the same stroke twice at
different sub-pixel offsets. Tiles cut from one rasterisation cannot: every
pixel comes from one sampling. The pad stays where it still does work — the
live fallback's query in `paintFrame` — and goes away for this generation's
tiles.

**D7 — The pan path is untouched.** After a rest bake the tiles are ordinary
tiles: blitted while they cover, baked one at a time at the edge as a pan
reveals new ones. That path was measured in 3g and 3h and fits its budget.
Criterion 9 exists to prove this plan did not disturb it.

**D8 — Approach C, and the two it beat.** *A*, one viewport image and no
tiles, was rejected: the next pan finds nothing and starts over. *B*, one walk
recorded once and rasterised per tile, was rejected as strictly worse than C —
it pays per-tile rasterisation for nothing C does not already get from a
sub-rectangle blit.

---

## 3. The seam, as a consequence rather than a goal

Gap G1 says software Skia does not antialias `drawVertices`, so no widget test
in this repository can produce an antialiased seam; the instrument for it is a
human looking at a GPU, and `--dart-define=CORPUS=simple` now provides the
drawing to look at.

D6 has a consequence worth stating and worth gating: **a generation cut from a
single rasterisation has no seam class at all.** The defect a seam comes from
is two neighbours sampling one stroke twice. That cannot happen here.

This is not a claim that seams are solved. It says nothing about the
carry-over composite during a gesture, which is stale by construction, and
nothing about the live fallback drawn beside blitted tiles on a moving frame.
It is a property of the settled generation only, and criterion 6 measures
exactly that and nothing more.

---

## 4. Criteria

Nine, all failable, and every threshold is named here rather than left for
the measurement to choose. Criterion 4's 3x is the one with slack in it, and
§4's note below says where the slack came from.

| # | Criterion | Instrument |
|---|---|---|
| 1 | A moving frame bakes **zero** tiles | scripted 20-step zoom, bake counter |
| 2 | Moving-frame p95 within 16.67 ms, at 50,000 and 500,000 | rig, a new `tile zoom` phase |
| 3 | The settle completes in **one** frame | `viewportCovered`, frame count |
| 4 | The rest bake is **>= 3x** cheaper than the tiled fill it replaces | same session, interleaved |
| 5 | A sliced generation is **identical to a live frame** | 3g/3h's differential instrument |
| 6 | **Zero** difference at tile boundaries in a settled generation | pixel sweep against the one viewport image |
| 7 | The transient image is released; `debugImagesAlive` holds | the existing invariant |
| 8 | Plan 3h's criterion 3, re-measured at **n=7–9 interleaved** | rig |
| 9 | The pan path does not regress | Plan 3h's existing gate |

**Criterion 4 is a ratio, and its arrangement is the criterion.** Plan 3h's
headline criterion missed at 2.35 against a gate of 2.4, and the gate had been
**mis-derived from a cross-session numerator** — the exact comparison a ratio
exists to prevent. Criterion 4 is therefore specified as *same session,
interleaved (rest, tiled, rest, tiled, …), never blocked*, and 3x is chosen
with headroom against a predicted ~10x rather than against the best number
seen.

**Criterion 8 is that wound itself.** Plan 3h handed it here: n=3 per arm
cannot settle whether 2.35 is real or noise, and the only arrangement that
removes the thermal and session-drift ordering bias is n=7–9 interleaved.
**The gate is the arrangement and the report, not the number.** If the ratio
still reads below 2.4 at n=9 interleaved, that is an answer and it is
recorded as one.

---

## 5. The anti-degenerate rule

Five clauses. A gate whose fixture or script fails any of them is vacuous, and
this plan says so before it measures rather than after.

1. **The zoom script goes both in and out.** Zoom out leaves a ring the live
   fallback owes and zoom in does not. A script that only zooms in cannot see
   criterion 2's worst case.
2. **The fixture contains entities larger than one tile.** Crossing
   multiplicity is what produces the 4.185x overdraw, and overdraw is what
   this design attacks. A fixture of tile-sized entities makes the win
   invisible and criterion 4 unfailable.
3. **The script crosses at least one power-of-two rebase-origin boundary.**
   `rebaseOriginFor` snaps to a step derived from the view span, so a script
   inside one step never re-quantises and never exercises the residual path.
4. **Both corpora, 50,000 and 500,000.** The win scales with the drawing; one
   column would let a reader take the small corpus's modest ratio for the
   whole story, which is how 3g nearly lost criterion 11.
5. **Neither the camera nor the fixture sits at the identity or the origin.**
   The standing rule of this repository, restated because a zoom fixture is
   exactly where someone reaches for a clean scale of 1.0 at (0, 0).

---

## 6. Named mutants

Six. Five must die; the sixth is written down as a survivor **before** it is
fired, so that no gate is credited with catching it.

| | Mutation | Killed by |
|---|---|---|
| M1 | keep baking on a moving frame | criterion 1 |
| M2 | the slice loop emits only the first tile | criterion 3 |
| M3 | the slice source rectangle ignores the tile offset | criteria 5 and 6 |
| M4 | the rest bake fires on every frame, not only at rest | criterion 2 |
| M5 | keep the pad when slicing | **nothing — a deliberate survivor** |
| M6 | the transient viewport image is never released | criterion 7 |

**M5 survives by construction and is recorded, not gated.** Keeping the pad
changes no pixel; it only does work that buys nothing. Plan 3h's M6 — narrowing
the clip — had exactly this shape and was recorded as gap H6 rather than
dressed in a gate that could not see it. Removing the pad is justified by D6's
argument, and the honest statement is that no measurement here distinguishes
the two.

---

## 7. Accepted gaps

- **G3 — level-of-detail geometry. Still open, and after this plan it blocks
  nothing.** A correct frame during a gesture remains a 32–40 ms frame at
  500,000 entities. This plan does not make that frame faster; it stops
  drawing it during a gesture. G3 becomes necessary the day the target changes
  to "correct geometry while the fingers are still moving".
- **Antialiasing on the vertices backend.** `drawVertices` ignores
  `isAntiAlias` and `defaultRenderBackend()` returns it, so edge quality is
  the surface's MSAA. Recorded in `STATUS.md` on 2026-08-26; not this plan's
  subject and not changed by it.
- **The resting frame's length is not gated.** D5 accepted it by decision.
  A slower machine will show a longer hitch, and this plan will not have
  measured how much longer.
- **The carry-over composite is still bilinear-filtered stale pixels during a
  gesture.** That is what makes the gesture cheap and it is the target
  behaviour, not a defect. What a magnified composite looks like at large zoom
  factors is a judgement for a human with the window open.

---

## 8. Files

- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — the two regimes, the
  rest bake, the slice. The bulk of the change.
- `packages/jet_cad_2d_flutter/test/` — a zoom-regime test file; extensions to
  the existing differential and invariant instruments for criteria 5, 6 and 7.
- `apps/dev_harness_2d/lib/measurement_rig.dart` — a `tile zoom` phase for
  criteria 2 and 4, and the interleaved arrangement criterion 8 requires.
- `docs/superpowers/notes/` — the results note, and the mutation log.

`packages/jet_cad_2d` is pure Dart and **this plan does not touch it.**
