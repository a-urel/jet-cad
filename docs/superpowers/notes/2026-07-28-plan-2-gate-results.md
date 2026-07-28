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

---

## Final state — after the blocker fixes

Branch at `14afae6`. 599 tests passing, 0 skipped.

Five of six rows pass with margin. The sixth, `snap at dirty threshold`, is
**genuinely marginal and does not reliably pass**. Three consecutive runs on
the same tree:

| Run | p50 | p95 | Verdict |
|---|---|---|---|
| 1 | 0.895 ms | 1.153 ms | FAIL |
| 2 | 0.772 ms | 0.938 ms | PASS |
| 3 | 0.866 ms | 1.073 ms | FAIL |

p50 clears the 1 ms budget every time; p95 straddles it. Machine run-to-run
spread on this hardware is roughly ±15%, which is the same order as the
distance to the threshold — so a single green run on this row means nothing,
and this file records the distribution rather than a lucky sample.

### What that row is actually waiting on

Not snap. The arc-centre redesign removed that cost entirely (`center` went
from ~0.57 ms to 0.002 ms). What remains is the **dirty overlay: a linear scan
of 24,984 entries**. Every query pays one pass; `snap` pays two — the fused
leaf-and-centre search plus a second inside `_considerIntersections`. Per-pass
cost measured at ~0.21 ms, which matches the gap exactly.

`forEachInRect` carries the identical cost and passes only because its budget
is 2 ms rather than 1 ms.

An identified partial fix — reusing `_descend`'s depth-0 walk for intersection
candidates — was measured to land at ~0.9–1.0 ms, still marginal, and is
conditional on `NarrowPhaseSlack.pick == 0`. It was deliberately not taken:
shaving a constant until one row complies is not the same as fixing the linear
scan, and the scan is the real answer.

**This is an open design question, not a tuning knob.** The dirty overlay is
linear by construction; at the rebuild threshold it is 5% of the document
scanned on every query at pointer-move rate.

## Post-drag drift — the regression that the fresh-index gate could not see

The fix that carried a definition's growth into the boxes placing it made three
structures grow monotonically with no path back. The gate cannot observe this:
`query_throughput.dart` queries a freshly built index, so it structurally never
sees the state an editing gesture creates.

Measured on one out-and-back drag inside a definition, `rebuildCount` still 1:

| Placements | Drag distance | Instances reported over empty space | `pickInto` there |
|---|---|---|---|
| 300 | 500 | 152 → **0** | 31.80 → 1.31 µs |
| 300 | 1000 | 300 → **0** | 77.42 → 1.76 µs |
| 3000 | 1000 | 3000 → **0** | 3755.09 → **11.97 µs** |

Before the fix, one ordinary gesture cost 3.75 ms per pick over a region
containing no geometry — 23% of a 16 ms frame — permanently, with no rebuild
ever triggering.

Edit side after the fix: an interior drag is unchanged (3.69 µs at 300
placements, 2.90 µs at 3000); a bound-moving drag now pays both directions,
67 µs at 300 and 535 µs at 3000, against 32/261 µs for growth alone.

**Lesson for the gate itself:** every row here measures a fresh index. A
benchmark that only ever measures the state a document is in least often will
miss a regression of this size. The dirty-threshold rows exist for exactly this
reason and still were not enough — they fill the dirty list, but they do not
*drag* anything.

---

## Ruling: the marginal row is accepted, deliberately

**Decision (human, 2026-07-29): accept `snap at dirty threshold` as it stands.
The dirty overlay's scaling becomes an open item for Plan 3, to be settled with
a measurement rather than now.**

### What is being accepted

Five of six gated rows pass with margin. The sixth clears its 1 ms budget on
p50 in every run (0.77–0.90 ms) and straddles it on p95 (0.938–1.153 ms across
three consecutive runs on an idle machine with ~±15% spread).

### Why this is defensible and not a rounding-down

The failure is at the **stress target, not the product's workload.** At 50,000
entities the same row measures **0.238 ms** — under a quarter of the budget.
A restaurant floor plan, which is what this engine exists to serve, is
thousands of entities, not hundreds of thousands. The 500k figure was set as a
ceiling for opening DWG-scale files, and it is the only place the row fails.

### What is actually wrong, so a later reader does not have to re-derive it

The overlay itself is well designed: `DirtyList.put` is slot-keyed
replace-in-place, so a 200-sample drag leaves **one** entry rather than 200 —
without that, a drag would trip the rebuild threshold during exactly the burst
the structure exists to absorb. `search` is a flat loop over a `Float64List`,
allocation-free and cache-friendly.

The flaw is the **threshold**, not the scan:

```dart
int get rebuildThreshold => math.max(64, (leafCount * 0.05).floor());
```

It is a *fraction of document size*, so the overlay's per-query cost grows
linearly with the document — 2,500 entries at 50k, 25,000 at 500k, 250,000 at
5M. That partly defeats the point of a logarithmic index: the R-tree gives
`O(log n + k)` and the overlay takes back `O(n/20)`. Past some size the overlay
costs more than the tree it fronts.

`snapInto` pays the scan **twice** — once in `searchLeavesAndSnapCentres` and
again in `_considerIntersections`' `searchLeavesRaw`. At ~0.21 ms per pass that
is ~0.42 ms, which matches the entire gap between snap fresh (0.48 ms) and snap
at threshold (0.82–0.90 ms). `forEachInRect` carries one pass of the same cost
and passes only because its budget is 2 ms rather than 1 ms.

### Options for Plan 3, with the reason none was taken now

- **A. Bound the threshold absolutely** — `min(max(64, n * 0.05), ~2000)`. Caps
  the scan; costs more rebuilds on large documents. Needs a measurement of what
  a 500k STR-pack rebuild costs and how often an editing session would trigger
  one. Trades a query cliff for a possible rebuild stall.
- **B. Index the overlay** — a small secondary structure, `O(d)` to
  `O(log d + k)`. The overlay is small and changes constantly, so it would be
  rebuilt continuously; the net gain is unclear.
- **C. Incremental rebuild** — repack a slice of the tree per frame so the
  overlay never grows large. Best behaviour, most work.
- **D. True incremental insertion** — a classic node-splitting R-tree instead
  of STR-packing, removing the overlay entirely. Largest change, and it gives
  up STR's query quality.

**Why not now:** choosing between A and C requires knowing whether a rebuild
stall is worse than the scan, and that cannot be answered without a real render
loop under a real editing session. Task 1's render spike produces exactly that
measurement. Picking A today would lock in a trade-off before seeing the
failure mode it introduces.

**Carried to Plan 3:** measure the overlay under the render spike, then choose.
