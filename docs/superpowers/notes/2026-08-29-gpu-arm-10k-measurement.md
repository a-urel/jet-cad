# The GPU arm at 10,000 entities — the measurement of record

**Date:** 2026-08-29. **Branch:** `spike/flutter-gpu-backend`.
**Why this note exists:** the numbers were taken for
`2026-08-29-gpu-resident-render-backend-design.md` and lived only inside that
spec. `CLAUDE.md` makes notes the results of record and makes independent
verification the reason, so a reviewer could not reach them. A reviewer caught
that; this is the fix.

## The run

```
flutter run -d macos --profile \
  --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 \
  --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 \
  --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3
```

macOS profile, 1400x900, three interleaved repeats, 30 frames per phase. The
corpus is `spikeDocument()` in `apps/dev_harness_2d/lib/main.dart`, so
`DASHED` takes its default of **0.35** and `labelFraction` is **0** — **this
corpus carries no text.** Every figure below is therefore a no-text figure, and
the design spec's text pass is not in any of them.

Harness line, verbatim:

```
GSPIKE collect+upload: walk 14.7 ms, total 15.7 ms, segments=59875,
buffer=2.06 MB, skippedFills=0, skippedText=0
```

`skippedFills=0` and `skippedText=0` mean the collector was **not** asked to
skip anything on this corpus — it contains neither. It does **not** mean fills
and text are covered by the 14.7 ms.

## Frame timings

Milliseconds, `p50 build / p50 raster`, one column per repeat. **The
aggregation rule, stated before any comparison is drawn: median of the three
per-repeat p50s, per stage, then summed.** Arms are interleaved within one
session, which is the only arrangement whose ratios mean anything here — see
Plan 3i.

### zoom

| arm | r1 | r2 | r3 | median build | median raster | sum |
|---|---|---|---|---|---|---|
| A painter (untiled) | 8.71 / 4.25 | 7.44 / 3.73 | 7.54 / 3.64 | 7.54 | 3.73 | **11.27** |
| B tiles (blit) | 0.30 / 0.77 | 0.36 / 1.13 | 0.28 / 0.84 | 0.30 | 0.84 | **1.14** |
| C flutter_gpu | 0.63 / 0.63 | 0.61 / 0.65 | 0.32 / 0.26 | 0.61 | 0.63 | **1.24** |

### pan

| arm | r1 | r2 | r3 | median build | median raster | sum |
|---|---|---|---|---|---|---|
| A painter | 7.48 / 3.86 | 7.46 / 3.62 | 7.47 / 3.68 | 7.47 | 3.68 | **11.15** |
| B tiles | 0.41 / 1.00 | 0.20 / 0.47 | 0.39 / 1.06 | 0.39 | 1.00 | **1.39** |
| C flutter_gpu | 0.15 / 0.20 | 0.67 / 0.69 | 0.68 / 0.74 | 0.67 | 0.69 | **1.36** |

### hold

| arm | r1 | r2 | r3 | median build | median raster | sum |
|---|---|---|---|---|---|---|
| A painter | 0.11 / 5.14 | 0.08 / 4.87 | 0.07 / 4.78 | 0.08 | 4.87 | **4.95** |
| B tiles | 0.24 / 1.08 | 0.16 / 0.72 | 0.09 / 0.35 | 0.16 | 0.72 | **0.88** |
| C flutter_gpu | 0.24 / 0.90 | 0.22 / 0.78 | 0.23 / 0.95 | 0.23 | 0.90 | **1.13** |

### p95, same runs

| arm | phase | build p95 | raster p95 |
|---|---|---|---|
| A painter | zoom | 10.27 / 10.55 / 12.35 | 5.67 / 4.46 / 4.65 |
| B tiles | zoom | 0.43 / 0.49 / 0.51 | 3.18 / 4.39 / 4.73 |
| C flutter_gpu | zoom | 0.87 / 0.99 / 0.91 | 1.03 / 1.20 / 1.20 |

## What these numbers do and do not say

**They do not say arm C is cheaper than arm B at this scale.** On the stated
rule the zoom frame is **B 1.14 ms against C 1.24 ms**, and on the pan it is
**B 1.39 against C 1.36**. The two arms are at parity, and on a zoom the blit
is marginally cheaper. An earlier draft of the design spec read "1.1 against
0.9" and drew the opposite conclusion; 0.9 does not follow from any aggregation
of the three repeats and the sign of the comparison was wrong.

**They do not, on their own, say the untiled painter misses the frame budget.**
Arm A's zoom is 11.27 ms of 16.67 at p50 — 68% of budget, not over it. Mixing
this run's p95 build (12.35) with its p50 raster (3.73) to reach 16.08 would be
an arithmetic sleight and is not done here.

**The recorded miss is elsewhere and it is stronger.**
`2026-08-21-plan-3d-results.md:333` measures the same backend at the same
10,000 entities and records **"vertices raster p95 is 22.10–22.36 ms"** across
three runs — an explicit statement that a minority of frames exceed 16.67 ms.
That note's raster p50 at this scale is **6.68 ms** against this run's 3.64-4.25,
a ~1.8x divergence, and the two runs are **not the same measurement**: different
camera script, different viewport, different corpus settings. Neither figure
corrects the other; the divergence is recorded rather than resolved.

**What they do say**, and it is enough for the design question:

- **Arm C's frame does not grow with the drawing.** Its zoom build is 0.61 ms
  here at 59,875 segments and the spike measured 0.17-0.26 ms at 2,380,424.
  Arm A's goes 7.54 → 383.
- **Arm C's p95 is tight at this scale** — 1.03-1.20 ms raster across three
  repeats — where the spike recorded it as unstable and undiagnosed at
  2,380,424 segments (10-13 ms). The instability is a large-scale phenomenon
  and this scale does not reach it.
- **A full collection walk is 14.7 ms**, against the untiled painter's ~7.5 ms
  per-frame build on the same corpus. A rebuild is therefore roughly **2x one
  of today's untiled frames** — not "no worse than today", which an earlier
  draft of the spec claimed.

## What is missing from this measurement

Stated so no later reader takes the table for more than it is:

- **No text.** `labelFraction: 0`. Every figure excludes the design's text pass.
- **No antialiasing, no joins, no caps** in arm C — the spike's declared cheats
  carry over unchanged.
- **Dashes baked at the collection camera** in arm C. `DASHED=0.35`, so a
  substantial share of the 59,875 segments are dash spans; under a shaded-dash
  design the segment count and the 2.06 MB would both fall, and by how much is
  unmeasured.
- **Arm B's bake budget is not exercised.** `kBakeBudgetDevicePixels` spreads a
  generation drop across frames, and no phase here forces one.
- **Native only.** No web run at 10,000 entities exists.
