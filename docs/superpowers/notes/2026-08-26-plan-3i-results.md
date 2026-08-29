# Plan 3i — results of record

**Two criteria miss, and both are named here rather than at the end.**
**Criterion 9 misses**: the `tile pan` p95 regressed against Plan 3h — 20.90,
21.75 and 23.70 ms against 3h's recorded 19.86, 15.99 and 13.43 ms, measured at
3h's own viewport with byte-identical tile counters. The two sets do not
overlap: the lowest reading here is above the highest reading there.
**Criterion 8 misses its 2.4 gate on the median** — 2.33 at n=9 interleaved,
with four of the nine pairwise ratios at or above 2.4 and a spread of 1.69 to
3.09. A third thing is not a miss but must be read as a limit: **criteria 2 and
4 were measured at 1400×900, not the design spec's pinned 1600×1200**, because
this display cannot produce that window (Ruling 20). The spec's memory
predictions, all priced against the 3200×2400 device rectangle 1600×1200
implies, remain untested.

Criteria 1, 2, 3 and 4 pass, at both corpora, with margin.

---

## Conditions

All device runs below: `TILES=on`, macOS profile build, `caffeinate -dimsu`
held throughout, `pmset -g | grep lowpowermode` read `0` and `pmset -g ps` read
`AC Power` immediately before and immediately after every run. Every run
reached `R2 app-run: done` with no viewport-mismatch warning and nothing
thrown. Logs are kept beside this note's ledger entry.

**Viewport is stated per criterion and is not uniform**, deliberately:

- **Criteria 1, 2, 3, 4 — 1400×900 logical at dpr 2.** The design spec §5 pins
  1600×1200 and prices every memory figure against the 3200×2400 device
  rectangle it implies. This display cannot produce it: the logical desktop is
  1496×967 and the panel 3456×2234, so at dpr 2 even the widest scaling gives
  1728×1117 and the height never reaches 1200 in any mode. Ruling 20 records
  the human's choice of the largest window that fits.
- **Criteria 8 and 9 — 800×600 logical at dpr 2**, because both are defined
  against Plan 3h's recorded figures and 3h ran at the nib default. Nothing in
  this harness set a window size until 2026-08-28; before that the code fitted
  its camera to `Size(1600, 1200)` while the window was 800×600, so **it had
  always assumed a window it never created.**

The first criterion-9 reading was taken at 1400×900 and read 23.16 ms. It is
**discarded, not reported as a result**: its counters (`bakes=19 liveDraws=15
tileBytes=45088768`) differ from 3h's, so it measured different work. The
readings below reproduce 3h's counters exactly.

---

## Criterion 1 — a moving frame bakes zero and draws zero live geometry

**PASS.** `gestureBakes=0` and `gestureLiveDraws=0` in **all sixteen arms** of
the criterion-4 runs, over 80 gesture frames each, at 50,000 and 500,000.

This is the plan's central claim and it holds without exception.

## Criterion 2 — moving-frame p95 within 16.67 ms

**PASS at both corpora, with roughly an order of magnitude of margin.**

| corpus | gesture p95 across the eight arms |
|---|---|
| 50,000 | 2.11, 1.97, 1.59, 1.90, 2.01, 2.19, 1.88, 2.08 ms |
| 500,000 | 1.61, 2.25, 1.84, 1.71, 1.85, 1.92, 1.90, 1.92 ms |

The gate is 16.67 ms. The worst reading is 2.25 ms.

**Corpus size barely moves it**, which is the result behind the result: a
moving frame blits one composite and returns, so its cost does not scale with
entity count. That is criterion 1 showing up in criterion 2's timing.

## Criterion 3 — the settle completes in one frame

**PASS as `settleFrames == 2`, not `== 1`, per Ruling 15.** Every arm-A repeat
at both corpora read exactly 2. Arm B read exactly 25 every time.

The spec's criteria table says "one frame"; `kRestGateFrames = 2` is pinned
separately in the same spec, for its own reason — a pan straight after a zoom
finds an empty generation and would otherwise arm the gate mid-pan. The last
gesture frame changes the camera, so idle frame 1 can only reach
`_restGateSteps == 1` and takes the moving-frame early return; idle frame 2 is
the first that can bake. **On correct code `settleFrames` is always 2**, so the
criterion as literally written is a gate only broken code could pass. The
reading was recorded before any device run, so there is no result it was fitted
to. A reader who disagrees with the ruling has the arithmetic here to disagree
with.

## Criterion 4 — rest-bake wall clock at least 3× cheaper

**PASS at both corpora, on every arm.** The ratio is
`settleWallMs(arm B, rest bake OFF)` over `settleWallMs(arm A, rest bake ON)`,
computed per arm and reported per arm as the plan requires.

| repeat | 50,000 A / B / ratio | 500,000 A / B / ratio |
|---|---|---|
| 1 | 58.22 / 334.98 / **5.75×** | 87.89 / 822.44 / **9.36×** |
| 2 | 34.10 / 292.66 / **8.58×** | 101.43 / 799.31 / **7.88×** |
| 3 | 59.52 / 334.65 / **5.62×** | 77.88 / 741.29 / **9.52×** |
| 4 | 51.03 / 346.97 / **6.80×** | 98.02 / 781.35 / **7.97×** |

**The arms are demonstrably two different code paths**, which is what Ruling 14
built the runtime switches for: `settleFrames` reads 2 in every arm A and 25 in
every arm B. Had the flag not flipped, both arms would have run identical code
and every ratio would have read 1.00 — a degenerate number in a document of
record. It did not.

## Criteria 5, 6, 7, 10, 11 — gated in the suite, not on the device

These five are unit and differential gates and were scored as tasks landed;
they are not device measurements and no device run bears on them. Their
instruments and their mutants are in
[plan-3i-mutation-log.md](plan-3i-mutation-log.md).

**One limit belongs here rather than in the log.** Criterion 7's headline
ceiling assertion originally ran with 43× headroom and could not fail; a
binding-cap arm was added and is gated by M21. Separately, `liveBytes` is
**structurally blind** to a leaked band image at any cap — `_band` is
reassigned per band, so a leak stops being counted — which means the ceiling
clause could never have been M6's gate. M6 dies on `debugImagesAlive`. Both
facts are recorded in the log rather than left for a reader to re-derive.

## Criterion 8 — Plan 3h's criterion 3, re-measured at n=9 interleaved

**MISS on the 2.4 gate, read on the median: 2.33.** The gate is not adjusted.

500,000 entities, 800×600, nine repeats, arms alternating A, B, A, B, … never
blocked. Arm A is the narrow band query; arm B sets
`debugFullViewportQuery`, which is **Plan 3h's M4** as a runtime flag (mutant
numbering is per-plan and `M4` names a different mutation in Plan 3i's log).

| repeat | A `tile pan` p95 | B `tile pan` p95 | ratio | A hold | B hold |
|---|---|---|---|---|---|
| 1 | 23.63 | 55.02 | 2.328 | 1.69 | 1.93 |
| 2 | 21.82 | 50.35 | 2.308 | 1.55 | 1.74 |
| 3 | 29.42 | 56.67 | 1.926 | 2.13 | 1.61 |
| 4 | 26.02 | 44.06 | **1.693** | 1.62 | 1.92 |
| 5 | 21.15 | 54.41 | 2.573 | 1.72 | 1.90 |
| 6 | 26.50 | 57.84 | 2.183 | 1.67 | 2.19 |
| 7 | 21.73 | 57.52 | 2.647 | 0.85 | 2.08 |
| 8 | 20.49 | 63.28 | **3.088** | 2.19 | 1.86 |
| 9 | 21.42 | 62.55 | 2.920 | 1.88 | 1.46 |

**Median 2.328. Mean 2.407. Range 1.693 to 3.088. Four of nine pairs at or
above 2.4.**

**The finding is the spread, not the centre, and it answers the question Plan
3h handed here.** 3h read 2.35 at n=3 and could not say whether that was real
or noise. It was real: at n=9 interleaved the median lands at 2.33, essentially
the same place. But the distribution straddles the gate — the mean is above
2.4, the median below, and the pairwise ratios span a factor of 1.8 between
best and worst. **No sample size settles "2.35 or 2.4", because the gate sits
inside the measurement's own noise.** That is consistent with 3h's own
suspicion about the gate's provenance: 2.4 came from the spike's 2.59×, whose
numerator was a separately-run session — the cross-session comparison a ratio
criterion exists to avoid.

**The control worked and is reported rather than assumed.** `tile hold` is a
phase M4 cannot touch, and it is inside each arm precisely so ordering bias
shows up. Its means are 1.700 ms (A) and 1.854 ms (B) — a **+9.1%** drift
toward arm B. Real, and an order of magnitude smaller than the 2.33× effect it
would have to explain. 3h's blocked three-then-three ordering produced an
order-of-magnitude difference on this same inert phase; interleaving reduced it
to 9%.

**Validity check: all eighteen arms reported `bakes=14 blits=1582
carryOverBlits=0 liveDraws=10 liveTiles=26 tileBytes=27262976`** — identical,
and identical to Plan 3h's recorded counters. The flag changes the *extent* of
the fallback walk, not how many walks happen. That is exactly what M4 is
defined to change.

**One run was taken, read, and discarded**, and it is named here because a
discarded measurement is part of the record. The first n=9 interleaved run
wired its arms around the **zoom** phase and measured nothing:
`gestureLiveDraws=0` in all eighteen arms, because a moving frame blits the
composite and returns, so the live fallback — the only code the flag touches —
never ran. Arm A and arm B were indistinguishable. **The flag was flipped on a
path that never executes**, which is the 1.00 Ruling 14 exists to prevent
arriving through a different door. Ruling 21 records the root cause as the
controller's brief: 3h's criterion 3 was measured on the **pan** phase.
The irony is exact — the zoom phase has no live walk *because this plan removed
it*, and criterion 1 scored that as a pass in the same session. The plan's own
success blinded criterion 8's first instrument.

## Criterion 9 — the pan path does not regress

**MISS.** Recorded as a miss rather than explained away, per the plan's
instruction.

500,000 entities, 800×600 — Plan 3h's viewport — three samples, against 3h's
three:

| | this plan | Plan 3h |
|---|---|---|
| `tile pan` p95 | 20.90, 21.75, **23.70** | 19.86, 15.99, 13.43 |
| mean | 22.12 ms | 16.43 ms |
| median | 21.75 ms | 15.99 ms |
| `tile hold` p95 | 1.79 ms | 2.77, 1.66, 1.79 |

**The sets do not overlap**: the lowest reading here (20.90) is above the
highest reading there (19.86). Mean to mean the pan path is **1.35× slower**.

**`tile hold` did not regress** — 1.79 ms sits inside 3h's 1.66–2.77 range.
The regression is specific to panning.

**The counters say the work is the same, which is where an investigation should
start.** Every reading here carries `bakes=14 perFrame=0.117 blits=1582
liveDraws=10 liveTiles=26 tileBytes=27262976`, matching 3h's record exactly. So
the pan phase bakes the same tiles, draws the same number of live fallbacks and
holds the same bytes — the cost per expensive frame moved, not their count.
This plan added two things to that path that are candidates and are named
without picking between them: the rest-gate bookkeeping every frame now
performs, and the `_lastChangeWasPan` frame introduced in the fix wave, which
converts the frame a pan stops on from a composite blit into a live walk. The
second is a deliberate correctness fix — it closed a one-frame background flash
— and it adds a walk that Plan 3h's numbers never paid for.

**No threshold was moved and no reading was dropped to reach this.** Three
samples were taken to match 3h's three.

---

## What this record does not establish

- **The spec's memory pricing is untested.** Every figure in §5 — 48 MiB of
  tiles, 8 MiB bands, a 56 MiB peak — is priced at 3200×2400 device pixels.
  Nothing here ran at that size. Criterion 7's ceiling holds at the sizes
  tested, which is a weaker statement.
- **Criterion 8's gate remains unsettled as a gate**, though the quantity is
  now well characterised. Whether 2.4 was ever the right number is a question
  about the spike's derivation, not about this measurement.
- **Criterion 9's cause is not diagnosed**, only measured. The counters above
  are the starting point.
- **The naked-eye seam check (gap G1) has not been done.** It needs a human at
  the window, comparing `2d: seam check -- tiles ON` against its tiles-off
  control.
