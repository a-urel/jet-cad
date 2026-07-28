# Plan 2 query-throughput gate — results

**Verdict: FAIL.** Two of six gated rows missed their threshold. Per the plan,
the index design returns to Plan 2; this may not be deferred into Plan 3.

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
