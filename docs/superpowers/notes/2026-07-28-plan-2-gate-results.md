# Plan 2 query-throughput gate — results

**Verdict: FAIL.** Two of six gated rows missed their threshold. Per the plan,
the index design returns to Plan 2; this may not be deferred into Plan 3.

> **A post-fix re-run is recorded at the bottom of this file**
> ("[After the snap redesign](#after-the-snap-redesign)"). Five of the six
> rows now pass; one — `snap at dirty threshold` — still misses, for a
> different reason than the one diagnosed here. Everything between this note
> and that section is the original, pre-fix measurement, left unedited.

Run with `cd packages/jet_cad_2d && dart run benchmark/query_throughput.dart`.

## Machine

- Apple M3 Pro, macOS 26.5.1
- Dart SDK 3.12.2 (stable), macos_arm64
- JIT (`dart run`), not AOT

## Document

`generateDocument(500000)` — entities spread over a floor-plan area at
`originX = 4.5e6`, mostly lines and polylines with circles, arcs, a few hundred
text entities, and 20 definitions each placed many times. Large coordinates are
deliberate: float precision behaves differently there, and a fixture at the
origin proves nothing.

Query radius 60 for pick, 100 for snap, sampled at pseudo-random positions
across the document. p50 and p95 over 120 iterations, first 20 discarded as
warm-up.

## Gated rows — 500,000 entities

| Measurement | p50 | p95 | Threshold | Verdict |
|---|---|---|---|---|
| `forEachInRect` fresh | 0.701 ms | 0.903 ms | < 2 ms | **PASS** |
| `pick` fresh | 0.346 ms | 0.466 ms | < 1 ms | **PASS** |
| `snap` fresh, all kinds | 3.559 ms | 4.119 ms | < 1 ms | **FAIL** |
| `forEachInRect` at dirty threshold | 0.921 ms | 1.149 ms | < 2 ms | **PASS** |
| `pick` at dirty threshold | 0.586 ms | 0.760 ms | < 1 ms | **PASS** |
| `snap` at dirty threshold, all kinds | 4.104 ms | 4.652 ms | < 1 ms | **FAIL** |

The dirty-list rows ran with 24,984 pending entries — the rebuild threshold
`max(64, 0.05 x 500000)` — with `rebuildCount` verified unchanged. A fresh index
is the state a document is in least often; every editing session leaves the
dirty list populated.

A sample `forEachInRect` at the document centre visited 3,832 entities, so the
rect row is returning a realistic working set rather than an empty region.

## Comparison rows — 50,000 entities (not gated)

| Measurement | p50 fresh | p50 at threshold |
|---|---|---|
| `forEachInRect` | 0.071 ms | 0.069 ms |
| `pick` | 0.048 ms | 0.038 ms |
| `snap` | 0.220 ms | 0.238 ms |

Snap is already the outlier at 50k and scales roughly 16x to 500k, against
~10x for rect and ~7x for pick.

## Why snap fails

Snap cost broken down by mask, 500k entities, radius 100, at the document
centre (455 entities within the raw query rect):

| Mask | p50 |
|---|---|
| `endpoint` only | 0.058 ms |
| `nearest` only | 0.066 ms |
| `cheap` **minus** `center` | 0.087 ms |
| `intersection` only | 0.109 ms |
| `cheap` (endpoint..insertion, includes `center`) | 0.655 ms |
| `all` | 1.035 ms |

**`center` alone accounts for roughly 0.57 ms of `cheap`'s 0.655 ms — about 87%
of it, and over half of `all`.** Intersection, despite being quadratic over up
to `kIntersectionCandidateCap = 64` candidates, costs 0.109 ms. The candidate
cap is not the problem and does not need tuning.

The cause is the arc-centre broad-phase widening added when fixing Bug 3 (an
arc's bounding box bounds its *sweep* and need not contain its own centre,
which `snapInto` offers as a `center` candidate). `NarrowPhaseSlack` widens
every `center`-including snap query by enough to reach any arc's centre from
its box, so the broad phase returns far more candidates than the query rect
implies. `SnapMask.cheap` includes `center`, so this is the default path, not
an exotic one.

This cost was recorded during Task 16 as "an accepted cost" — accepted without
measurement. Measured at 500k, it is the term that fails the gate.

Note the numbers above (1.035 ms for `all` at the centre) are lower than the
gated row's 3.559 ms because the gate samples random positions across the
document, including denser regions. The *ratio* between masks is stable at both
radius 2 and radius 100.

## What did pass

- **The packed R-tree survived 500,000 entities.** The plan warned that a
  traversal stack sized by depth alone, rather than depth x breadth, would pass
  the 1,000-item differential test and overflow here. Task 3's breadth-aware
  sizing (two parallel `Int32List(16 x 16)`) held; no overflow, no wrong result.
- **`forEachInRect` and `pick` pass comfortably in both states**, including
  with 24,984 linearly scanned dirty entries on every query.

## `definitionBounds` — carried backlog item, fixed

`DraftDocument.definitionBounds` recomputed `leavesByOwner()` — a full
entity-store scan — once per definition. `ContainerIndex.build` already
memoised per definition, which fixed per-*instance* recomputation, so the
defect scaled with definition *count*, not entity count. The gate's default
fixture uses 20 definitions and could never have seen it; the recorded case was
2,000 definitions over 32,000 entities at roughly 35 seconds.

`definitionBounds` now takes an optional `leavesByOwner` map and
`ContainerIndex.build` threads through the one it already holds.

| | Before | After |
|---|---|---|
| Build 2,000 definitions / 32,000 entities | ~35 s (recorded) | **88 ms** |

The parameter is optional rather than required: a caller asking for one
definition's bounds in isolation has no such map to share and should not have
to build one.

## Constants

Neither declared constant was tuned. The rebuild threshold
`max(64, 0.05 x count)` and `kIntersectionCandidateCap = 64` were left at their
plan values, because the measurements do not implicate either — the dirty rows
pass, and intersection is 0.109 ms of a 3.5 ms failure. Tuning them would have
moved numbers without addressing the cause.

## Options for the redesign

Recorded for the decision, not chosen here — the gate's verdict is a design
decision, not an implementer's.

1. **Index arc centres as their own tree entries** so an arc's stored box
   contains every point the snap engine offers as a candidate, and drop the
   `center` slack entirely. This attacks the root cause: the invariant that
   broad phase must never be tighter than the region narrow phase tests is
   currently restored by widening the *query*, which is what costs the time.
2. **Query arc centres separately** — a second, narrow query for centre
   candidates only, so the main snap query keeps a tight box.
3. **Drop `center` from `SnapMask.cheap`**, making it opt-in. Cheapest change,
   but a behaviour change for callers and it does not fix the cost when
   `center` is requested.

Option 1 is the principled one: the box is what is wrong, and the slack is a
compensation for it.

---

## After the snap redesign

Option 1 was taken: arc and circle centres are indexed in a `PackedRTree` of
their own inside each `ContainerIndex`, and the arc-centre term is gone from
`NarrowPhaseSlack` entirely. Same machine, same generator, same seeds, same
`dart run benchmark/query_throughput.dart`.

**Verdict: FAIL, on one row instead of two.** `snap fresh` clears its
threshold by more than 2x. `snap at dirty threshold` clears it on p50 and
misses on p95 — and misses for a reason that has nothing to do with arc
centres. See "[What still fails, and why](#what-still-fails-and-why)".

### Gated rows — 500,000 entities

Four consecutive runs; the figures below are the **median** of the four, and
the run-to-run spread on this machine is roughly ±15%, which matters for the
last row and for nothing else.

| Measurement | p50 before | p50 after | p95 after | Threshold | Verdict |
|---|---|---|---|---|---|
| `forEachInRect` fresh | 0.701 ms | 0.672 ms | 0.778 ms | < 2 ms | **PASS** |
| `pick` fresh | 0.346 ms | 0.348 ms | 0.408 ms | < 1 ms | **PASS** |
| `snap` fresh, all kinds | 3.559 ms | **0.550 ms** | 0.664 ms | < 1 ms | **PASS** |
| `forEachInRect` at dirty threshold | 0.921 ms | 0.856 ms | 1.029 ms | < 2 ms | **PASS** |
| `pick` at dirty threshold | 0.586 ms | 0.493 ms | 0.617 ms | < 1 ms | **PASS** |
| `snap` at dirty threshold, all kinds | 4.104 ms | **0.883 ms** | 1.100 ms | < 1 ms | **FAIL** |

The gate's own verdict is on **p95**, not p50. The four `snap at dirty
threshold` p95 readings were 0.974, 1.198, 1.096 and 1.110 ms — one pass,
three failures. Reporting it as a pass on the strength of the one run that
cleared it would be dishonest; it fails.

Snap is 6.5x faster fresh and 4.6x faster at the dirty threshold. The two
rows that already passed are unchanged, which is the point: `forEachInRect`
and `pickInto` never see the centre tree.

### Cost by mask — the table this redesign was aimed at

500k entities, radius 100, at the document centre; the same measurement as
"[Why snap fails](#why-snap-fails)" above, repeated on the new code.

| Mask | p50 before | p50 after |
|---|---|---|
| `cheap` **minus** `center` | 0.087 ms | 0.090 ms |
| **`center` only** | not measured | **0.002 ms** |
| `intersection` only | 0.109 ms | 0.057 ms |
| `cheap` (includes `center`) | 0.655 ms | **0.088 ms** |
| `all` | 1.035 ms | **0.198 ms** |

`center` was ~87% of `cheap`. It is now unmeasurable next to the rest:
`cheap` and `cheap`-minus-`center` are the same number to within noise, which
is what "the centre is indexed where it actually is" is supposed to look
like. `intersection` also halved, for an unrelated reason recorded below.

### What actually changed

1. **Centres are indexed.** A third `PackedRTree` per `ContainerIndex`, one
   degenerate (point) box per arc or circle, payload the leaf's slot. It is
   deliberately *not* folded into the leaf tree: those boxes are what
   `forEachInRect` and `pickInto` report against, and snap-only data has no
   business on the hit-test path.
2. **The slack channel is gone, not shrunk.** `NarrowPhaseSlack` had three
   channels; the `snap` one was `pick` plus `centreGap + rho * fraction`.
   With centres indexed, that term has nothing left to reach, and `snap`
   became identical to `pick` — so the channel was removed rather than left
   as a synonym for its sibling.
3. **A much smaller compensation replaces it, in one place.** A parent
   indexes a definition by that definition's *bound*, and an arc's centre can
   lie outside it; that box may not be grown, because
   `forEachInstanceInRect` reports against it. So `ContainerIndex` publishes
   `ownSnapCentreReach` — how far its own centres escape its own bound — and
   `SpatialIndex` lifts that through the instance transforms and widens the
   **instance search only**. The old margin was a union over every arc in the
   document; this one is a union over how far a centre escapes its own
   definition, and is exactly zero for a document with no instances, however
   many arcs it has.
4. **The dirty overlay carries centres, in the same array.** `DirtyList` now
   records a centre beside every box, with NaN meaning "no centre" so the
   containment test rejects it by arithmetic rather than by a flag. One
   `put`, one `remove`, one swap-with-last — a slot cannot go dirty for its
   box and stale for its centre.

### What still fails, and why

`snap at dirty threshold` is the only miss, and the arc centre is not
implicated. Deltas over the corresponding fresh row, at p95:

| | fresh p95 | at threshold p95 | delta |
|---|---|---|---|
| `forEachInRect` | 0.778 ms | 1.029 ms | +0.25 ms |
| `pick` | 0.408 ms | 0.617 ms | +0.21 ms |
| `snap` | 0.664 ms | 1.100 ms | +0.44 ms |

The dirty overlay is a **linear scan**, 24,984 entries at this document size
(the `max(64, 0.05 x count)` rebuild threshold). Every query pays one pass
over it. `snap` pays **two**: one for the fused leaf-and-centre search, and a
second inside `_considerIntersections`, which runs its own root-level query
with its own rectangle. Two passes is 2 x ~0.21 ms, which is the delta
measured.

That is a pre-existing property of Plan 2's dirty-list design, not of this
redesign — `forEachInRect` shows the same per-pass cost and passes only
because its threshold is 2 ms rather than 1 ms. It was invisible before
because snap was failing by 4x on a different term.

**The identified fix, not taken here:** `_considerIntersections` re-queries
the root for line and polyline candidates that `_descend` has just walked
past at depth 0. Collecting them during that walk would remove the second
pass and bring the row to roughly 0.9-1.0 ms — still marginal. It is not
done in this change because the two queries use different rectangles
whenever `NarrowPhaseSlack.pick` is non-zero (the cap selects "the 64
greatest handles *touching the query rectangle*", so a wider rectangle can
select a different 64), and making that conditional correct deserves its own
task rather than being bolted onto this one. The honest characterisation is
that snapping at the dirty threshold is now bounded by the dirty overlay
itself, and the next thing to attack is the overlay, not the snap engine.

### Two defects fixed alongside, both of which moved these numbers

- **`_considerIntersections` allocated one `Aabb2` per call** to hold its
  query rectangle — flat per call, on the frame path, the exact construction
  `_descend` had already removed from its own hot path for the same reason.
  `snapInto` measured 5.004 `Aabb2`/call; it is four loose doubles now.
- **The intersection cap kept the 64 *lowest* handles**, i.e. the
  earliest-drawn entities, discarding whatever the user had just drawn —
  and contradicting the later-drawn-wins rule applied three lines below it
  to the same pair. It keeps the 64 greatest now.

That second fix made `intersection` **9x slower** on this fixture before it
was addressed: the newest line-like entities in the generated document are
polylines, and the cap bounds *entities*, not segments, so a cap-ful of
six-point polylines is up to 25x the segment-pair work of a cap-ful of
two-point lines. `_collectNearSegments` now discards, in one linear pass,
every segment further from the query point than the radius — which cannot
contribute an accepted crossing, since an accepted crossing lies on the
segment and within the radius. Exact same results; `intersection only` went
0.598 ms -> 0.057 ms, below even its pre-redesign 0.109 ms.

### Constants

Still untuned. `max(64, 0.05 x count)` and `kIntersectionCandidateCap = 64`
are at their plan values. The remaining failure is a scan whose length that
first constant sets, so lowering it *would* move the number — which is
exactly why it was left alone: that would trade query time for rebuild
frequency without anyone having decided to.
