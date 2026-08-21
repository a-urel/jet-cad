# Task 16 report: the rig grows fills

**Low Power Mode, checked before dispatch and again now:** `pmset -g | grep lowpowermode` → **1** (ON). Every timing row below is marked contaminated per Plan 3d's finding: ~24% uniform hit on raster and build, and CPU-only paths (which the vertices backend's build phase is closer to) run 23-40% *faster* with it off, so the canvas/vertices gap and the FILLS on/off delta below are directional only, not the true magnitude.

## What changed

- `apps/dev_harness_2d/lib/main.dart`: added `kFillFraction` (0.4, named beside `kDashedFraction`) and `kFillsEnabled` (a `String.fromEnvironment('FILLS', ...)`, unrecognised value throws — same shape as `kBackend`, per the brief's warning about Plan 3c's `bool.fromEnvironment('TEXT')` loss). `harnessDocument` now calls a new `_addFillRegions(doc, count)` when `kFillsEnabled`, purely additive after `generateDocument` returns (fills-off is byte-identical to before — confirmed below). It adds closed-polyline rooms; `kFillFraction` of them become an `AddRegionCommand` pair (fill + boundary), the rest are plain closed `EntityKind.polyline` boundaries with no fill.
- `apps/dev_harness_2d/lib/measurement_rig.dart`: `printInvariants` gained the `fills=$fillCount skippedFills=$skippedFillCount` line, verbatim per the brief.
- `apps/dev_harness_2d/integration_test/frame_timing_test.dart`: `boot()` gained a guard mirroring the existing dashed-linetype sanity check — `doc.fills.linkCount` must be nonzero iff `FILLS=true` — so a silently-ignored define fails loudly instead of printing plausible zeros.
- `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`: `_corpus()` now adds 200 fill regions (same `AddRegionCommand`/plain-boundary quota shape) before the two-flush allocation gate; added `expect(painter.fillCount, greaterThan(0))` and `expect(painter.skippedFillCount, 0)` so the gate can't go vacuous. Added `fillHeavyCorpus()` (5,000 fills, `fraction: 1.0`) and the load-cost test from the brief, using `DraftDocumentCodec.encodeToString`/`.decodeString` (the real API `AddRegionCommand`/Task 1-15 gave, not the placeholder `JsonCodec.save/load` names in the brief's snippet).

## A real bug found and fixed mid-task, worth recording

My first placement scattered rooms uniformly over the full 60,000×40,000 floor plan. The device run showed `fills=0 skippedFills=0` — the corpus had fills (`doc.fills.linkCount=20`, confirmed) but R2's window only covers ~3000×2250 around the extents' centre, so a uniform scatter almost never lands one there (measured, not guessed).

Second attempt clustered rooms tightly at the *initial* fit centre. Still `fills=0`. Root cause, found by replaying R2's own pan+zoom script against a throwaway `SpatialIndex` query: `printInvariants` reports the state *after* 120 pan steps + 120 zoom steps, not the initial fit — and the pan alone moves the window by empirically-measured **(+3228, -1355)** world units (120 × `panBy(Offset(-7,-3))` at the fit's screen-to-world scale). A tight cluster at the start point is gone by the time anything is measured.

Fixed by placing rooms in a corridor — the bounding box of the initial-fit window and the post-pan-and-zoom window, plus margin — derived from that same empirical replay. Verified via `flutter test` (not `drive`) at both 10,000 and 50,000 entities before spending device time: 18-19 fills visible at the initial window, 18-60 at the final one, both counts. All temporary debug instrumentation was stripped before the real runs; only the `linkCount` sanity guard was kept.

## Device transcripts (six runs, all timing rows CONTAMINATED by Low Power Mode=1)

### 1. ENTITIES=10000 BACKEND=canvas FILLS=true
```
R2 (10000) frames=241
  build  p50=20.06ms p95=21.02ms max=190.01ms          [CONTAMINATED]
  raster p50=75.00ms p95=80.75ms max=536.43ms           [CONTAMINATED]
  lineweightScale=1.0
  screenSpaceLeafCount=2169 dashSpans=48070 collapsed=291 canvasCalls=50969
  fills=18 skippedFills=0
  backend=canvas
```

### 2. ENTITIES=10000 BACKEND=vertices FILLS=true
```
R2 (10000) frames=243
  build  p50=9.12ms p95=11.18ms max=201.24ms            [CONTAMINATED]
  raster p50=5.00ms p95=6.67ms max=80.99ms              [CONTAMINATED]
  lineweightScale=1.0
  screenSpaceLeafCount=2169 dashSpans=48070 collapsed=291 canvasCalls=0
  fills=18 skippedFills=0
  backend=vertices triangles=207343 drawVerticesCalls=1
```
Backend-independent fields match run 1 exactly (`screenSpaceLeafCount`, `dashSpans`, `collapsed`, `fills`, `skippedFills`).

### 3. ENTITIES=50000 BACKEND=canvas FILLS=true
```
R2 (50000) frames=240
  build  p50=20.84ms p95=22.38ms max=283.38ms           [CONTAMINATED]
  raster p50=79.52ms p95=94.49ms max=675.14ms           [CONTAMINATED]
  lineweightScale=1.0
  screenSpaceLeafCount=2394 dashSpans=51163 collapsed=334 canvasCalls=54381
  fills=60 skippedFills=0
  backend=canvas
```

### 4. ENTITIES=50000 BACKEND=vertices FILLS=true
```
R2 (50000) frames=243
  build  p50=9.87ms p95=12.26ms max=312.86ms            [CONTAMINATED]
  raster p50=5.26ms p95=6.73ms max=82.63ms              [CONTAMINATED]
  lineweightScale=1.0
  screenSpaceLeafCount=2394 dashSpans=51163 collapsed=334 canvasCalls=0
  fills=60 skippedFills=0
  backend=vertices triangles=224892 drawVerticesCalls=1
```
Backend-independent fields match run 3 exactly.

### 5. ENTITIES=10000 BACKEND=canvas FILLS=false
```
R2 (10000) frames=242
  build  p50=19.89ms p95=20.85ms max=188.89ms           [CONTAMINATED]
  raster p50=74.79ms p95=80.13ms max=539.30ms            [CONTAMINATED]
  lineweightScale=1.0
  screenSpaceLeafCount=2111 dashSpans=48070 collapsed=291 canvasCalls=50893
  fills=0 skippedFills=0
  backend=canvas
```
`screenSpaceLeafCount=2111` here vs `2169` at `FILLS=true` (run 1) — the +58 delta is exactly the visible closed-polyline additions (fills + plain boundaries) that landed in the window; `dashSpans`/`collapsed` are unchanged, confirming the FILLS define is otherwise inert, as designed.

### 6. ENTITIES=10000 BACKEND=vertices FILLS=false
```
R2 (10000) frames=243
  build  p50=9.09ms p95=11.31ms max=203.79ms            [CONTAMINATED]
  raster p50=4.93ms p95=6.20ms max=56.20ms              [CONTAMINATED]
  lineweightScale=1.0
  screenSpaceLeafCount=2111 dashSpans=48070 collapsed=291 canvasCalls=0
  fills=0 skippedFills=0
  backend=vertices triangles=206495 drawVerticesCalls=1
```
Matches run 5's backend-independent fields exactly, and matches the pre-Task-16 baseline (`screenSpaceLeafCount=2111`, same dash/collapsed counts) — `FILLS=false` reproduces the prior corpus byte-for-byte in every field the rig reports.

**Exit-gate criterion `skippedFillCount == 0`: met in all four `FILLS=true` runs.**

## Allocation gate (Step 3)

`packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`, `flutter test`:
```
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=68ms
00:00 +3: All tests passed!
```
The corpus now carries 200 rooms (fills + plain boundaries); `painter.fillCount > 0` and `painter.skippedFillCount == 0` are asserted directly, and the pre-existing `debugCapacityVertices` before/after comparison across the subject frame passed with fills present — a triangulation cache miss on the frame path would have shown up here as buffer growth, and none did. This is not a timing measurement, so it is not marked contaminated.

## Load-cost row (Step 5)

**`LOAD fills=5000 elapsed=68ms`** — `DraftDocumentCodec.decodeString` on a 5,000-fill document (`fillHeavyCorpus()`, `fraction: 1.0` so every boundary is a region). This is a load-time measurement (JSON parse + triangulation), not a frame-rate measurement — Low Power Mode's effect on it wasn't isolated, so treat it as informational per the brief's "no threshold" instruction rather than a clean baseline.

## Full local verification (all green)

```
packages/jet_cad_2d:         CI=true dart test → 771 passed; dart analyze → no issues; dart format --set-exit-if-changed → clean
packages/jet_cad_2d_flutter: flutter test → 276 passed; flutter test --tags golden → 29 passed; flutter analyze → no issues; dart format → clean
apps/dev_harness_2d:         flutter analyze → no issues
```
`git status --porcelain` before commit showed only the four intended files — no `project.pbxproj`, no `analysis_options.yaml`.

## Concerns / things I was unsure about

1. **The brief's Step 5 snippet names `JsonCodec.save`/`JsonCodec.load`, which don't exist** — the real codec is `DraftDocumentCodec` (`.encodeToString`/`.decodeString`), per "What Tasks 1-15 give you" and every existing test in this codebase. Used the real API; flagging the mismatch in case it was meant literally.
2. **`fillHeavyCorpus()`'s size (5,000) and `_corpus()`'s addition (200 rooms) are my own choices** — the brief specifies neither count, only that the row must exist and the gate must run "on a corpus containing fills." Chose 5,000 as large enough to produce a non-trivial, reportable number without making the suite slow.
3. **The rig corpus's fill placement (a "corridor" derived from replaying R2's pan/zoom script) is coupled to today's exact script constants** (120 steps, `Offset(-7,-3)`, zoom anchor `(800,600)`, factors 1.03/0.97). If `measurement_rig.dart`'s script changes later, this could silently under-cover again — the only thing that would catch it is the printed `fills=`/`skippedFills=` line itself, which is the same safety net the brief relies on for the `FILLS` define generally. No stronger guard seemed in scope for this task.
4. **`kFillFraction = 0.4` and the corridor's exact margins are my own numbers**, chosen to make `skippedFillCount == 0` and `fillCount > 0` hold robustly at both 10,000 and 50,000 entities, not derived from any stated requirement.
