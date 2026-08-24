## Task 12: Criteria 10 and 11 on device

**Files:** none. This task measures and reports.

- [ ] **Step 1: Confirm the machine, and record the reading**

`pmset -g | grep -i lowpowermode` must read `0` and the machine must be on AC power. Plan 3c lost a whole session's timings to Low Power Mode, and the 2026-08-23 spike measured its contamination on this corpus at **+30% on build and +47% on raster** — which is not the uniform ~24% `STATUS.md:101-104` records from Plan 3c, and the results note must say so again if it holds.

- [ ] **Step 2: Reproduce the control before measuring anything**

```sh
cd apps/dev_harness_2d
CI=true flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=50000 \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices
```

Plan 3d's clean row is build 7.07 `[7.06, 7.38]` / raster 8.53 `[8.22, 8.63]`. **If the baseline does not land inside those intervals, the machine is talking and every number below falls with it.** Stop and say so rather than publishing.

- [ ] **Step 3: Measure criteria 10 and 11**

Median of three at `ENTITIES=500000`, `BACKEND=vertices`, `TILES=on`, at the tile size Task 11 chose.

| criterion | reading | threshold |
|---|---|---|
| 10 | settled frame `totalSpan` | **≤ 4.00 ms** — Probe D measured 1.61 ms for a single viewport blit; the allowance covers the grid's extra `drawImageRect` calls |
| 11 | pan frame baking a strip, `totalSpan` | **≤ 16.67 ms** — the frame budget, since a pan frame that misses it is a dropped frame |

**Criterion 11's threshold is the one number no measurement backs, and it does not move.** If it is unreachable at every size in {128, 256, 512}, the response is a smaller `kTilesBakedPerFrame`, or a `kTileClipInflate` the overdraw column justifies — **not a larger threshold**. A gate moved to fit its result is not a gate.

- [ ] **Step 4: Fire M7 on device**

Clip each tile to the viewport instead of to its own rect. **Every correctness criterion stays green** — the blit only ever shows a tile's own rect, so the extra baked content is never displayed — and criteria 10 and 11 collapse. Record the numbers. M7 is the mutation that passes the whole correctness suite and destroys the plan's reason for existing; a run that cannot kill it is not gating this plan.

- [ ] **Step 5: Record, do not commit code**

No source changes. The transcripts go into Task 13's results note verbatim. **Never synthesize test output.**

---

