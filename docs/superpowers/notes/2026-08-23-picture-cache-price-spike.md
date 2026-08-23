# Spike — pricing the picture cache before Plan 3g designs it

**Date:** 2026-08-23
**Branch:** `spike/picture-cache-price`, instrumentation at `d3636f9`
**Status:** **provisional.** Every timing below was taken with macOS Low Power
Mode **on** and the machine **on battery at 12–15%**. The relative comparisons
survive that; the absolute milliseconds do not. The clean pass is owed and
specified at the end, along with the one measurement that actually gates the
recommendation.

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
1-call frame into a 2N-call frame and kills the design.

**The hypothesis was wrong.** That is the spike's main result, and the reason it
was run instead of written down as a conclusion.

## Environment

| | |
|---|---|
| machine | Apple M3 Pro, macOS 26.5.1 (25F80) |
| Flutter | 3.47.1 stable, framework `6655482ec0`, engine `11d79658c4` |
| driver | `flutter drive --profile -d macos`, `RIG=pan` (R2), 242 frames |
| corpus | `TEXT=true`, `BACKEND=vertices` |
| **power** | **Low Power Mode ON, battery, 12–15%** — see the status line above |

`RIG=pan` is R2, and **R2 is not pan alone**: 120 `panBy` frames followed by 120
`zoomAt` frames (`measurement_rig.dart:215-221`). Half the measured frames move
the scale. The name is the rig's, not a description of the gesture.

Reproduce:

```sh
cd apps/dev_harness_2d
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=$N \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices \
  --dart-define=SPLIT=$K --dart-define=REPLAY=$R
```

## The three probes

- **Probe A — `SPLIT=k`.** Flush every `k` batched quads, so the frame's single
  `drawVertices` becomes many calls **with the triangle count held fixed**. The
  only moving variable is draw-call count. The hook fires on quads alone
  (`vertices_draw_sink.dart`, in `_emitQuad`); join triangles do not advance it.
- **Probe B — painter counters.** Split the frame's drawn leaves into
  root-owned and definition-owned; count container visits and root instances.
- **Probe C — `REPLAY=true`.** Wrap each flush's `drawVertices` in a `Picture`
  recorded *that frame* and replay it under a transform. An upper bound on the
  **recording** term, and only on that — see "What Probe C does not price".

## Probe B — the prize is a property of the corpus, not of drawings

Counters, not timings. Low Power Mode does not reach them.

| corpus | root leaves | definition leaves | instanced share | container visits | root instances |
|---|---|---|---|---|---|
| 50,000 | 317 | 3,713 | **92.1%** | 350 | 187 |
| 500,000 | 3,533 | 4,041 | **53.4%** | 362 | 187 |

The definition-owned leaf count barely moves (3,713 → 4,041) while the root
count grows 11×. `generateDocument` places a **fixed** set of 20 definitions
regardless of `entityCount`, so the instanced share is decided by the
generator's composition and by nothing else.

**Neither percentage is a cache hit rate, and the difference is larger than the
corpus caveat.** An instanced leaf is only a cache *hit* if some other instance
already baked the picture it wants, and `STATUS.md` records three reasons a
second instance may want a different one:

- **Trap 3** (`STATUS.md:988`) — a baked picture is not scale-invariant now that
  dashes exist. `VerticesDrawSink` tessellates in screen space, so stroke width
  and dash phase bake into the picture along with the geometry.
- **3f's unanswered question** (`STATUS.md:975`) — may a cached picture contain
  text at all, when level of detail is continuous in scale.
- **Trap 4's closure** (`STATUS.md:1041-1050`) — after Plan 3f.1 the
  `StyleContext` key carries six real fields, and `linetypeScale` is a raw
  double accumulated as a product, so `2.0 × 4.0` and `1.0 × 8.0` are different
  keys.

Nothing in this spike prices any of that: **no cache exists here to hit or
miss.** 92.1% is the ceiling on what a *perfectly* hitting definition cache
could reach, before any of the three discounts above. Carrying it forward as
the expected saving would be the defect Plan 3f.1's results note names — a
cause stated more strongly than its evidence.

## Probe A — draw-call count is not the killer

Five runs, **one each — `n=1`**. The control holds across all five:
`triangles=217758`, `screenSpaceLeafCount=2170`, `dashSpans=48323` — identical
every time, so call count really is the only thing that moved.

All rows at **`ENTITIES=50000`**.

| `SPLIT` | `drawVertices` calls | build p50 | raster p50 |
|---|---|---|---|
| 0 (off) | 20 | 9.57 ms | 12.10 ms |
| 4096 | 29 | 9.40 ms | 11.41 ms |
| 512 | 166 | 9.85 ms | **10.58 ms** |
| 128 | 633 | 11.26 ms | 11.92 ms |
| 32 | 2507 | 14.22 ms | 14.04 ms |

**Raster is flat from 20 to 633 calls**, and the break appears at 2,507.

The 10.58 ms at 166 calls is below the 20-call baseline, which is not a
speed-up. It is the scatter — and **a noise band inferred from the single point
it is being used to dismiss is circular**, which is why the owed sweep runs each
of these three times. Read the flat region as "no effect large enough for `n=1`
to separate", not as a measured bound.

Build does rise with call count: **+1.69 ms at 633, +4.65 ms at 2,507**. That is
the per-flush `Vertices.raw` plus two `sublistView`s plus `dispose` — the time
cost of the "three objects per flush" Plan 3d recorded as an allocation count.
**A definition cache pays this term too**; see "Two Dart-side terms" below.

The definition-Picture route's target is one replay per visible container visit:
**350 flushes + 350 replays = 700 calls**. That is past 633, the last measured
flat point. The extrapolation is short but it is an extrapolation, and the owed
sweep measures at the target instead of near it.

## Probe C — wrapping a `drawVertices` in a `Picture` is raster-free

All rows at **`ENTITIES=50000`**, `n=1` each.

| form | calls | build p50 | raster p50 |
|---|---|---|---|
| direct `drawVertices` | 20 | 9.57 ms | 12.10 ms |
| recorded + replayed under a transform | 20 | 9.68 ms | **11.85 ms** |
| direct `drawVertices` | 633 | 11.26 ms | 11.92 ms |
| recorded + replayed under a transform | 633 | 13.06 ms | **11.85 ms** |

633 record-and-replay round trips per frame cost nothing at raster time.

### The null result's alternative explanation, and how it was excluded

A replay that drew **nothing** would produce this table unchanged. The controls
quoted above — `triangles`, `screenSpaceLeafCount`, `dashSpans` — are Dart-side
counters that count *submission*, not pixels, so none of them can tell the two
apart. Two independent checks separate them:

1. **The mechanism draws** (`test/spike_replay_draws_test.dart`, on the spike
   branch). A `drawVertices` recorded into a `Picture`, replayed under the same
   `save`/`translate`/`drawPicture`/`restore` the probe uses, with
   `picture.dispose()` called immediately after — as the probe does — still puts
   ink on the surface. This closes the disposal question and nothing else: it is
   two triangles under software Skia, not 218,000 under Impeller.
2. **Absence would not look like this.** Raster tracks triangle count across the
   two corpus sizes measured — 217,758 → 559,682 triangles against 12.10 →
   29.75 ms, a two-point fit of 51.6 ns per triangle with a **0.86 ms
   zero-triangle intercept**. A frame that submitted its geometry and drew none
   of it would raster in about 0.9 ms. The replay arm measured 11.85 ms, within
   2% of the direct arm and **14× above** the blank-frame estimate.

Neither check is an ink comparison on a real Impeller surface, and the existing
instrument cannot supply one: `measureAgreement`'s vertices arm goes through the
repository's **software rasterizer**, not a `Canvas`, so it never executes a
`drawPicture` at all (`test/support/sink_comparison.dart`). A real-surface ink
check is on the owed list.

### What Probe C does not price

- **The transform.** The probe replays under `translate(0.5, 0.25)` — the
  cheapest transform there is. A real instance placement carries rotation and
  scale. The `Picture` round trip is priced; the transform is not.
- **The flush.** See below.

## Two Dart-side terms, and only one of them is cached away

The build column carries two separate costs, and collapsing them overstates what
a cache saves:

| term | measured | does a definition cache pay it? |
|---|---|---|
| **flush** — `Vertices.raw`, two `sublistView`s, `dispose`, per call | +1.69 ms at 633 calls | **Yes.** It flushes at every replay boundary, ~350 times. Unavoidable, not cached away. |
| **recording** — `PictureRecorder`, `endRecording` | +1.80 ms at 633 calls, on top of the flush | **No.** A cache records once and replays for many frames. |
| **the walk** — index query, style resolution, dashing, join construction | the bulk of the 9.57 ms baseline | **No**, for a hit. This is the prize. |

So the route's steady-state Dart cost is roughly *the walk it still does* plus
*its own flush term*, and Probe C's +1.80 ms is the one line of the three that
amortises to nothing.

## The sharper limit the measurements found

Every configuration measured on this repository — this spike's contaminated rows
and Plan 3d's clean ones alike — is **raster-bound**.

| corpus | backend | build p50 | raster p50 | source |
|---|---|---|---|---|
| 10,000 | vertices | 5.71 ms | **6.68 ms** | 3d, clean |
| 50,000 | vertices | 7.07 ms | **8.53 ms** | 3d, clean |
| 500,000 | vertices | 17.44 ms | **21.64 ms** | 3d, clean |
| 50,000 | vertices | 9.57 ms | **12.10 ms** | this spike, contaminated |
| 500,000 | vertices | 25.48 ms | **29.75 ms** | this spike, contaminated |

A definition-level cache — `Picture` or pre-tessellated vertex data — attacks
**build only**. The same triangles are still uploaded and still rasterised.
Reduce the walk, the style resolution, the dashing and the join construction to
zero and the 500,000-entity frame still sits at 21.64 ms, above the 16.67 ms
budget.

So the parent spec's cache is mechanically sound and aimed at the wrong half of
the frame.

What moves raster is fewer triangles, or geometry replaced by a texture. At
500,000 entities the frame submits 559,682 triangles — 1,679,046 vertices at 12
bytes each, **roughly 20 MB of traffic per frame**. Screen-space tiles rasterised
to an `Image` remove that for the static content of a pan; a tile recorded as a
`Picture` does not, because a `Picture` replays the same geometry.

**That 20 MB is traffic, not capacity, and it is not the 96.00 MiB figure
`STATUS.md:1005` records** at the same corpus. The 96 MiB is the vertex buffer's
high-water mark, pinned for the widget's life and paid once; the 20 MB is what
crosses to the GPU on every frame. A tiling scheme changes both, differently.

## This refines a headline cost model, and the refinement is backend-qualified

`STATUS.md:110` carries, from the dash/leaf separation note: **"the unit of
render cost is the canvas call, not the drawn leaf … raster is super-linear
because each call is one Impeller `Entity`."**

Probe A moves 20 → 633 `drawVertices` calls at a fixed triangle count and raster
does not respond. Both findings are real and they do not contradict: the earlier
one was measured on `drawPath`, where each call carries a **tessellation** into
its `Entity`; a `drawVertices` call carries triangles that are already built.
The cost per call is a function of what the call contains.

**The claim as written in `STATUS.md` is unqualified**, so a resumer inherits an
apparent contradiction. It needs "on the canvas backend" attached to it, in
`STATUS.md` as well as here.

## What the contamination does and does not reach

Low Power Mode was on for every run, and the machine was on battery below 15%.
Plan 3c lost a whole session's timings to exactly this. `STATUS.md:101-104`
records the re-measurement: **"the contamination is a uniform ~24% on both
raster and build"** — and, separately, that Plan 3b's claim that CPU-only paths
are unaffected is wrong, since they run 23–40% faster with it off. Those are two
findings, not one; the second is about CPU-only paths and is **not** evidence
that build and raster diverge under Low Power Mode.

- **Probe B is untouched.** Counters are a function of the document and the
  camera.
- **Probes A and C are relative** — one session, one power state, triangle count
  pinned.
- **The flat line has a failure mode, and it is not "contamination scales both
  arms alike".** Low Power Mode throttles the GPU, so raster is inflated; a
  fixed per-call submission cost is then a *smaller fraction* of a longer frame
  and can hide inside a wider scatter. The break at 2,507 calls shows the
  instrument does detect call cost eventually, which bounds how much can be
  hiding — but it does not bound it at 633, and that is precisely where the
  clean pass matters.
- **"Raster-bound" is a build/raster ratio**, which the uniform ~24% would leave
  intact — but this spike's rows are not what settles it. **Plan 3d's clean
  rows settle it independently**, at all three corpus sizes and on both backends.
- **Every absolute millisecond in this note is contaminated** and must not be
  quoted as a baseline.

## Recommendation

**Plan 3g should be a tile cache whose tiles are rasterised, not a definition
`Picture` cache.** The definition cache is not dead — Probes A and C refute the
objection that killed it on paper — but its ceiling is the frame's raster time,
and that ceiling is already above budget at the corpus size the cache exists for.

**The recommendation is gated on a measurement nobody has taken.** It assumes a
blit beats drawing the triangles it replaces. That is very likely and it is
untested here, and it is a stronger assumption than anything Probes A–C
established. Probe D below is the gate, not a follow-up.

## Owed

1. **Probe D — the price of blitting a pre-rasterised tile against drawing its
   triangles.** *This gates the recommendation.* Not attempted here.
2. **Whether the 21.64 ms raster at 500,000 entities is upload-bound** (about
   20 MB of vertex traffic per frame) **or fill-bound** (overdraw across 559,682
   triangles). Those want different remedies and nothing here distinguishes them.
   A tiling scheme that assumes the wrong one buys nothing.
3. **The clean pass.** Charger connected, `sudo pmset -a lowpowermode 0`, then:
   `SPLIT=0` ×3, `SPLIT=128` ×3, **a `SPLIT` tuned to ~700 calls ×3** (the
   route's actual target, rather than the 633 measured here), `SPLIT=32` ×1, and
   `REPLAY=true` ×3 at both 20 and ~700 calls. The control is Plan 3d's
   `50,000 / vertices → 7.07 / 8.53` row: reproduce it from the same driver and
   the same corpus. **If the baseline does not land on that row, the machine is
   talking and the sweep falls with it.**
4. **An ink comparison on a real Impeller surface with `REPLAY=true`**, since
   the repository's existing instrument routes the vertices arm through a
   software rasterizer and never reaches `drawPicture`.
5. **A Probe C arm under a rotation-and-scale transform**, since the one that
   ran used a sub-pixel translate.
6. **The web whole-drawing abort's back-to-back same-session re-run**, which
   `STATUS.md` says 3g is owed. Out of scope here and still owed.

## Disposition

The instrumentation is throwaway and lives only on `spike/picture-cache-price`.
Nothing in `packages/` or `apps/` from this spike is meant to merge.

**This note is not throwaway.** It is the result of record, it reverses the
roadmap's Plan 3g, and it must reach `main` — linked from `STATUS.md`, which
`CLAUDE.md` makes the first thing a resumer reads and which still describes 3g
as the definition/tile picture cache — before that branch is deleted. The same
ordering `STATUS.md` records as the lesson for ledgers.
