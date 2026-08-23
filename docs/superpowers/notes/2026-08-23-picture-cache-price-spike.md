# Spike — pricing the picture cache before Plan 3g designs it

**Date:** 2026-08-23
**Branch:** `spike/picture-cache-price`, instrumentation at `d3636f9`, `2496a93`
and `a77de50`
**Status:** **measured clean.** Low Power Mode off, AC power, medians of three
where marked. An earlier revision of this note carried a contaminated sweep; the
clean pass replaced it and **changed one of its conclusions** — see "What the
clean pass overturned".

## Why the spike existed

Plan 3g was going to be "the definition/tile picture cache", inherited from the
parent architecture spec. That spec was written when `CanvasDrawSink` was the
only backend and the frame was one `drawPath` per leaf. Plan 3d flipped the
default to `VerticesDrawSink`, which submits the whole frame as **one**
`drawVertices`.

Draw order is ascending handle value and an instance's subtree draws as one
contiguous run, so replaying a per-definition `Picture` mid-frame forces the
vertex buffer to flush at its boundary — the mechanism `_flushBeforeUnbatchable`
already provides for text. The pre-spike hypothesis was that this turns a
1-call frame into a 700-call frame and kills the design.

**The hypothesis was wrong**, and that is the reason the spike was run instead
of written down as a conclusion.

## Environment

| | |
|---|---|
| machine | Apple M3 Pro, macOS 26.5.1 (25F80) |
| Flutter | 3.47.1 stable, framework `6655482ec0`, engine `11d79658c4` |
| driver | `flutter drive --profile -d macos`, `RIG=pan` (R2), 242 frames |
| corpus | `TEXT=true`, `BACKEND=vertices` |
| power | **Low Power Mode 0, AC power** — `pmset -g` read before the session |

`RIG=pan` is R2, and **R2 is not pan alone**: 120 `panBy` frames followed by 120
`zoomAt` frames (`measurement_rig.dart:215-221`). Half the measured frames move
the scale. The name is the rig's, not a description of the gesture.

**The session's control.** Plan 3d's clean `50,000 / vertices` row is build
7.07 ms `[7.06, 7.38]` / raster 8.53 ms `[8.22, 8.63]`. This session's `SPLIT=0`
baseline reproduced it at **7.36 / 8.25**, both inside 3d's intervals, and its
`500,000` baseline reproduced 3d's 17.44 / 21.64 at **17.79 / 22.40**. The
instrument is measuring what 3d measured.

Reproduce:

```sh
cd apps/dev_harness_2d
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=$N \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices \
  --dart-define=SPLIT=$K --dart-define=REPLAY=$R --dart-define=SNAPSHOT=$S
```

## The instrument gap this spike walked into

`report()` printed `buildDuration` and `rasterDuration` and nothing else. **Those
two do not have to account for a frame's cost.** Probe D's `bake` arm rasterises
217,758 triangles into a texture on every frame, and both columns stay flat:
raster reads **0.87 ms**, indistinguishable from a bare blit.

The work did not vanish; the instrument stopped seeing it. `toImageSync` returns
before the rasterisation it schedules, and that GPU work falls outside either
window. `totalSpan` — vsync-start to raster-finish — catches it: the same arm
reads **13.56 ms** there.

`report()` now prints all three. **Every conclusion below that involves a bake is
read off `totalSpan`**, and a column that reads "free" is not believed without a
second column agreeing.

## Probe D — the recommendation's gate, and it passes

`SNAPSHOT=blit` bakes the frame into a device-resolution `Image` once and blits
it on every later frame — the **settled / pan-valid** regime, where a tile is
still good. `SNAPSHOT=bake` rebakes on every frame — the **zoom** regime, where a
scale change invalidates every tile and a tiling scheme pays the bake it hoped
to amortise.

The pixels go stale in `blit` mode the moment the camera moves. That is
deliberate and it is not the measurement: the measurement is frame cost. A probe
may trade correctness away; it may not trade away saying so.

`n=1` per cell. The effect is 10–25×, far outside this rig's scatter, and the
blit cost is independently confirmed three times over by landing on the same
number at three corpus sizes.

| corpus | mode | build | raster | **total** | vs `off` |
|---|---|---|---|---|---|
| 50,000 | off | 7.46 | 8.30 | **15.04** | — |
| 50,000 | blit | 0.28 | 0.97 | **1.49** | **10.1× cheaper** |
| 50,000 | bake | 8.28 | 0.87 | **13.56** | 1.11× cheaper |
| 500,000 | off | 17.79 | 22.40 | **40.27** | — |
| 500,000 | blit | 0.32 | 0.97 | **1.61** | **25.0× cheaper** |
| 500,000 | bake | 17.66 | 1.13 | **32.06** | 1.26× cheaper |

**The blit is corpus-independent** — 0.86 ms of raster at 10,000 entities, 0.97
at 50,000, 0.97 at 500,000. It is a viewport-sized texture and it costs what a
viewport-sized texture costs. Drawing the geometry is not corpus-independent, so
the ratio widens with the drawing: 10× at 50,000, 25× at 500,000, and still
climbing.

**And the boundary is measured, not assumed.** Under continuous invalidation the
same scheme buys 11% at 50,000 and 26% at 500,000 — not 10× and not 25×. A tile
cache is a *pan and settle* optimisation. Under a zoom gesture it is roughly a
wash, and any design that assumes otherwise is assuming against this table.

## Probe B — the prize is a property of the corpus, not of drawings

Counters, not timings, so nothing here depends on the power state.

| corpus | root leaves | definition leaves | instanced share | container visits | root instances |
|---|---|---|---|---|---|
| 10,000 | 2,697 | 167,799 | **98.4%** | 10,739 | 5,382 |
| 50,000 | 317 | 3,713 | **92.1%** | 350 | 187 |
| 500,000 | 3,533 | 4,041 | **53.4%** | 362 | 187 |

98.4%, 92.1%, 53.4% — **the share moves by 45 points across the corpus sizes and
not monotonically with anything a drawing would recognise.** `generateDocument`
places a fixed set of 20 definitions regardless of `entityCount`, so this is the
generator's composition and nothing else. None of these numbers is evidence
about a real drawing.

**Nor is any of them a cache hit rate**, which is the larger caveat. An instanced
leaf is a *hit* only if some other instance already baked the picture it wants,
and `STATUS.md` records three reasons a second instance may want a different one:

- **Trap 3** (`STATUS.md:988`) — a baked picture is not scale-invariant now that
  dashes exist. `VerticesDrawSink` tessellates in screen space, so stroke width
  and dash phase bake into the picture along with the geometry.
- **3f's unanswered question** (`STATUS.md:975`) — may a cached picture contain
  text at all, when level of detail is continuous in scale.
- **Trap 4's closure** (`STATUS.md:1041-1050`) — after Plan 3f.1 the
  `StyleContext` key carries six real fields, and `linetypeScale` is a raw double
  accumulated as a product, so `2.0 × 4.0` and `1.0 × 8.0` are different keys.

**No cache exists here to hit or miss**, so this spike prices none of that.

## Probe A — draw-call count is not the killer

Flush every `k` batched quads, so the frame's single `drawVertices` becomes many
calls **with the triangle count held fixed**. The hook fires on quads alone, in
`_emitQuad`; join triangles do not advance it. All rows at `ENTITIES=50000`.

The control holds on every run: `triangles=217758`, `screenSpaceLeafCount=2170`,
`dashSpans=48323`.

| `SPLIT` | calls | n | build p50 | raster p50 | raster [min, max] | total p50 |
|---|---|---|---|---|---|---|
| 0 (off) | 20 | 3 | 7.36 | **8.25** | [8.23, 8.30] | 15.00 |
| 128 | 633 | 3 | 8.21 | **8.16** | [7.99, 8.20] | 15.85 |
| 115 | **702** | 3 | 8.43 | **8.23** | [8.12, 8.26] | 16.16 |
| 32 | 2507 | 1 | 9.97 | **9.70** | — | 19.13 |

**702 calls is the definition-Picture route's actual target** — 350 flushes plus
350 replays, one per visible container visit — and it is measured, not
extrapolated to. Raster there is 8.23 ms against a baseline of 8.25, with
overlapping intervals. There is no effect.

The break is real and lands between 702 and 2,507 calls: +18% of raster. So the
instrument does detect per-call cost; it detects none at the route's target.

Build rises with call count — **+0.85 ms at 633, +1.07 at 702, +2.61 at 2,507**.
That is the per-flush `Vertices.raw` plus two `sublistView`s plus `dispose`: the
time cost of the "three objects per flush" Plan 3d recorded as an allocation
count. **A definition cache pays this term too**; see "Two Dart-side terms".

## Probe C — a `Picture` replay is nearly free, and "free" was contamination

Wrap each flush's `drawVertices` in a `Picture` recorded that frame and replay it
under a transform. All rows `ENTITIES=50000`, `n=3`.

| form | calls | build p50 | raster p50 | raster [min, max] | total p50 |
|---|---|---|---|---|---|
| direct | 20 | 7.36 | 8.25 | [8.23, 8.30] | 15.00 |
| recorded + replayed | 20 | 7.23 | 8.29 | [8.24, 8.33] | 14.95 |
| direct | 702 | 8.43 | 8.23 | [8.12, 8.26] | 16.16 |
| recorded + replayed | 702 | 9.62 | **8.58** | [8.51, 8.60] | 17.67 |

At 20 replays there is nothing to see. **At 702 replays there is: +0.35 ms of
raster, about 0.5 µs per replay.** The two triples do not overlap — [8.12, 8.26]
against [8.51, 8.60] — so it is a real effect and not scatter.

It is small enough to leave the verdict standing and it is **not zero**, which is
what the contaminated sweep reported.

### The null result's alternative explanation, and how it was excluded

A replay that drew **nothing** would produce a flat raster column too. The
controls quoted above are Dart-side counters that count *submission*, not pixels.
Two checks separate them:

1. **The mechanism draws** (`test/spike_replay_draws_test.dart`, on the spike
   branch). A `drawVertices` recorded into a `Picture`, replayed under the same
   `save`/`translate`/`drawPicture`/`restore` the probe uses, with
   `picture.dispose()` called immediately after — as the probe does — still puts
   ink on the surface. This closes the disposal question and nothing else: two
   triangles under software Skia, not 218,000 under Impeller.
2. **Absence would not look like this.** Raster tracks triangle count: 217,758 →
   559,682 triangles against 8.25 → 22.40 ms clean, a two-point fit of 41.4 ns
   per triangle with a **-0.76 ms intercept** — that is, the whole of raster is
   geometry, with nothing left over. A frame that drew none of its triangles
   would raster in about nothing. The replay arm measured 8.58 ms.

Neither is an ink comparison on a real Impeller surface, and the existing
instrument cannot supply one: `measureAgreement`'s vertices arm goes through the
repository's **software rasterizer**, not a `Canvas`, so it never executes a
`drawPicture` at all (`test/support/sink_comparison.dart`). Still owed.

### What Probe C does not price

- **The transform.** The probe replays under `translate(0.5, 0.25)` — the
  cheapest transform there is. A real instance placement carries rotation and
  scale. The `Picture` round trip is priced; the transform is not.
- **The flush.** See below.

## Two Dart-side terms, and only one of them is cached away

| term | measured (at 702 calls) | does a definition cache pay it? |
|---|---|---|
| **flush** — `Vertices.raw`, two `sublistView`s, `dispose`, per call | +1.07 ms | **Yes.** It flushes at every replay boundary. Unavoidable, not cached away. |
| **recording** — `PictureRecorder`, `endRecording` | +1.19 ms on top | **No.** A cache records once and replays for many frames. |
| **the walk** — index query, style resolution, dashing, join construction | the bulk of the 7.36 ms baseline | **No**, for a hit. This is the prize. |

## The limit that decides the shape

Every configuration measured here and in Plan 3d is **raster-bound**.

| corpus | build p50 | raster p50 | source |
|---|---|---|---|
| 10,000 | 5.71 | **6.68** | 3d, clean |
| 50,000 | 7.07 | **8.53** | 3d, clean |
| 500,000 | 17.44 | **21.64** | 3d, clean |
| 50,000 | 7.36 | **8.25** | this session |
| 500,000 | 17.79 | **22.40** | this session |

A definition-level cache — `Picture` or pre-tessellated vertex data — attacks
**build only**. The same triangles are still uploaded and still rasterised. Take
the walk, the style resolution, the dashing and the join construction to zero and
the 500,000-entity frame still sits at 22.40 ms of raster inside a 40.27 ms
total, against a 16.67 ms budget.

**Probe D's blit arm gets that same frame to 1.61 ms**, because a rasterised tile
replaces the geometry instead of re-walking it.

## What the clean pass overturned

The contaminated sweep was not merely imprecise. Three things changed:

1. **"Raster-free" became "+0.35 ms at 702 replays".** Under Low Power Mode the
   direct and replayed arms read 11.92 and 11.85 — a difference the wrong way
   round. Clean, the two triples are disjoint. A fixed per-call cost is a smaller
   fraction of a throttled frame and hides inside the wider scatter; that is the
   named failure mode of a flat line, and it fired.
2. **The build penalty halved.** +1.69 ms at 633 calls contaminated, +0.85 clean.
3. **The contamination is not uniform on this corpus.** `STATUS.md:101-104`
   records it as **"a uniform ~24% on both raster and build"**, measured during
   Plan 3c. Here, at 50,000 entities: build 9.57 → 7.36 clean (**+30%
   contaminated**), raster 12.10 → 8.25 (**+47%**). One corpus, `n=1`
   contaminated against `n=3` clean — but a 17-point gap is not scatter.
   `STATUS.md`'s "uniform" does not hold here, and a future plan that budgets
   against it should know.

## This refines a headline cost model, and the refinement is backend-qualified

`STATUS.md:110` carries, from the dash/leaf separation note: **"the unit of
render cost is the canvas call, not the drawn leaf … raster is super-linear
because each call is one Impeller `Entity`."**

Probe A moves 20 → 702 `drawVertices` calls at a fixed triangle count and raster
does not respond. Both findings are real and they do not contradict: the earlier
one was measured on `drawPath`, where each call carries a **tessellation** into
its `Entity`; a `drawVertices` call carries triangles that are already built. The
cost per call is a function of what the call contains. `STATUS.md` states the
claim unqualified, so a resumer inherits an apparent contradiction; the
qualification now lives in both places.

## Recommendation

**Plan 3g should be a tile cache whose tiles are rasterised**, not a definition
`Picture` cache.

The definition cache is not dead — Probes A and C refute the objection that
killed it on paper — but it attacks build, the frame's non-binding half, and its
ceiling is a raster time already over budget. A rasterised tile is 10× cheaper
than drawing at 50,000 entities and 25× at 500,000, and the margin widens with
the drawing because the blit does not.

**The gate this recommendation was previously waiting on has been measured and
passed** (Probe D). What remains is design work, and it starts from three facts
this spike established rather than assumed:

- A tile is a **pan-and-settle** optimisation. Under continuous zoom the same
  scheme buys 11–26%, and the design must say what it does during a zoom gesture
  rather than discover it.
- The blit is **corpus-independent**, so tile count and tile size are budgeted
  against the viewport, not against the drawing.
- Bake cost is **not visible in `rasterDuration`**. Any gate 3g writes against a
  bake must read `totalSpan`, or it will pass while the work happens.

## Owed

1. **Whether the 22.40 ms raster at 500,000 entities is upload-bound** (about
   20 MB of vertex traffic per frame) **or fill-bound** (overdraw across 559,682
   triangles). Probe D does not discriminate: its bake arm uploads the same
   vertices to a different target. Tile *size* policy depends on the answer.
2. **An ink comparison on a real Impeller surface** with `REPLAY=true` and with
   `SNAPSHOT=blit`, since the repository's existing instrument routes the
   vertices arm through a software rasterizer and never reaches `drawPicture`.
3. **A Probe C arm under a rotation-and-scale transform**, since the one that ran
   used a sub-pixel translate.
4. **The web whole-drawing abort's back-to-back same-session re-run**, which
   `STATUS.md` says 3g is owed. Out of scope here and still owed.

Note what is **not** on this list any more: the clean pass, and Probe D.

## Numbers that must not be carried forward

- **Probe B's percentages** are the corpus generator's composition, and they are
  not cache hit rates.
- **`20 MB per frame` is traffic, not capacity**, and it is not the 96.00 MiB
  `STATUS.md:1005` records at the same corpus. That figure is the vertex buffer's
  high-water mark, pinned for the widget's life and paid once. A tiling scheme
  changes both, differently.

## Disposition

The instrumentation is throwaway and lives only on `spike/picture-cache-price`.
Nothing in `packages/` or `apps/` from this spike is meant to merge — **except
`report()`'s `totalSpan` line**, which is not a probe. It is a hole in a
measurement rig that six plans have published numbers from, and it should land on
`main` whether or not 3g ever builds a tile.

**This note is not throwaway.** It is the result of record, it reverses the
roadmap's Plan 3g, and it must reach `main` — linked from `STATUS.md`, which
`CLAUDE.md` makes the first thing a resumer reads.
