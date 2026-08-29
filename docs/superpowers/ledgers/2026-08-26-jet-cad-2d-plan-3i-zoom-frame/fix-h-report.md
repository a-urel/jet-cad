# Fix wave H — criterion 8 re-pointed at the pan phase (Ruling 21)

**Status:** complete. Commits `9e2a455` and `7aef7f9` on `main`, from `9a36fec`.

**Gate:** `apps/dev_harness_2d` **72** at `--concurrency=1` (was 61, +11 new),
`packages/jet_cad_2d_flutter` **413** with **1 skip** (unchanged),
`packages/jet_cad_2d` **797** (unchanged). Analyze and format clean.

**M30 fired and died.**

**The two arms measurably differ on the real app.** Arm A `tile pan` p95 8.64
and 11.39 ms; arm B 27.41 and 27.20 ms. `liveDraws=10` in every arm. Details
and the caveat in §5.

---

## 1. What was wrong

`ZOOM_MODE=criterion8` alternated `TileCache.debugFullViewportQuery` around
**`runTileZoomPhase`**. That flag modifies exactly one thing — the live
fallback's query extent in `TileCache.paintFrame` — and every frame of the zoom
phase is a *moving* frame, which blits the carry-over composite and returns
before the fallback can run. The n=9 interleaved run at 500,000 entities
completed cleanly and measured nothing: `gestureLiveDraws=0` in all eighteen
arms, arm A p95 1.69 1.86 1.78 2.06 1.64 1.71 1.77 1.88 2.22 against arm B p95
1.77 1.68 1.74 1.73 …, indistinguishable, and directionless `settleWallMs`.

Plan 3h's criterion 3 — which criterion 8 exists to re-measure at n=7–9
interleaved — was measured on the **`tile pan` phase**, which is where the live
fallback runs and where 3h's M4 bites
(`docs/superpowers/notes/2026-08-25-plan-3h-results.md`).

The degenerate log is kept at `scratchpad/KEEP_c8_DEGENERATE_run.log`.

## 2. What one arm is now, and why

**One arm = purge → warm → `tile hold` (60 frames) → `tile pan` (120 frames).**
No probe, no settle call. `runTilePanArm` in
`apps/dev_harness_2d/lib/measurement_rig.dart`.

The caller (`main.dart`'s `runPanArm`) restores R2's fitted camera and pumps one
frame before every arm, exactly as the zoom arm's `runArm` does, because the
arms of a ratio must start from the same camera and the phase does not own it.

Then, inside the phase:

**Purge.** Two frames: one at `zoomAt(Offset.zero, 2.0)`, which makes
`paintFrame` fail `TileGrid.matchesScale`, retire the generation and dispose its
tiles; then `camera.value = start`, restoring the arm's camera bit-identically
rather than by a zoom round trip that lands a float away. `TileCache` exposes no
public way to drop a generation, so an excursion is the only lever the harness
has. `tilesAfterPurge` is reported per arm and must read 0.

**Why the purge is not optional, in the run's own numbers.** The first check run
on the real app had no purge and reached `R2 app-run: done` cleanly. Arm A
repeat 1 read `bakes=14 liveDraws=10 p95=14.01ms`. **All three arms after it
read `bakes=0 liveDraws=0 blits=1600`** — a pure blit parade. The fitted camera
and the pan path are identical in every arm by construction, the cache is
nowhere near capacity so `newEvictions=0`, and every arm after the first panned
over the tiles the previous arm's pan had baked. That is exactly the "one arm
inherits the previous arm's warm generation in a way that biases the pan"
failure, and the warm loop cannot fix it: a cache that is already full warms in
no frames. The log is kept at `scratchpad/KEEP_c8_inherited_generation.log`.

**Warm.** Pump non-moving frames until the viewport is covered and three
consecutive frames bake nothing, bounded at 400 and reported as `warmFrames` /
`warmBakes`. The first version exited on the *first* non-baking frame and read
`warmFrames=1 warmBakes=0` in all four arms of the second check run:
`kRestGateFrames` is 2, so the frame straight after the purge's camera change
can never bake — Ruling 15's arithmetic — and the loop stopped before the warm
began, leaving the two boundary frames to do the warming where no counter
attributes it. Coverage plus three idle frames is a condition a frame that was
never allowed to bake cannot meet. Now reads `warmFrames=5 warmBakes=3` (the
rest path counts bands, not tiles).

**`tile hold`, kept.** 60 frames, ~1 ms each, and it is a phase Plan 3h's M4
**cannot** touch: the camera does not move, every visible tile is a hit, the
live fallback never runs (`hold bakes=0 liveDraws=0` in every arm of the final
run), and the flag modifies nothing else. A systematic arm-to-arm difference
there is pure session drift — it is the control that exposed 3h's own ordering
bias. Cheap enough to keep in every arm.

**`tile pan`, the statistic.** 120 frames at `tilePanStep(kPanStep)`, the same
step from the same function `runTilePhases` pans R2's own block with — extracted
so an arm and the block criterion 9 reads cannot drift into two measurements
under one name. `tile pan` p95 is the number, at `report`'s own quantile
`(n*0.95).floor()`, so an arm and an R2 block are the same statistic.

**`_probeBake` dropped.** It reimplements the bake geometry instead of calling
`paintFrame`, so it cannot see `debugFullViewportQuery` at all: it would read
bit-identical on both arms while costing a live walk, a walk per tile and a
`toImageSync` per tile in each of eighteen arms.

**No `settle()`.** Every frame of the phase goes through one `FrameTimingLog`,
and a frame pumped outside it runs the reported stream ahead of the pumped one —
the shifted-ordinal condition `FrameTimingLog` refuses to publish from. The warm
loop's own termination condition is the settle it would have asked for.

**Evidence that an arm reproduces the phase criterion 9 and 3h describe:** every
arm of the final run reported `bakes=14 blits=1582 carryOverBlits=0
liveDraws=10 newEvictions=0 liveTiles=26 tileBytes=27262976`, byte-identical to
R2's own `tile pan` block in the same session and to Plan 3h's recorded
counters. The two arms differ in timing and in nothing else.

## 3. Arrangement and labelling

`runInterleaved` still owns the ordering, unchanged and still tested, so the
interleaved unit is one whole arm alternating A, B, A, B, … and never blocked.
`runZoomCriterionArms` became a thin wrapper over a new generic
`runCriterionArms<R>`; criterion 4 keeps its own entry point, its `'tile zoom'`
phase name and its `printZoomReport` default, pinned where an edit to criterion
8 cannot reach them. **`ZOOM_MODE=criterion4` and `ZOOM_MODE=plain` are
untouched.**

`zoomArmLabel` now takes a **required** `phase` — no default, because the phase
an arm ran on is precisely the load-bearing word Ruling 21 turned on, and a
transcript naming the wrong phase is indistinguishable from a working one.
Every printed line of every arm carries the full label: phase, criterion,
repeat, side, the exact flag state, the arm's description and the entity count.
Every arm's number is printed; nothing is aggregated.

Two warnings the instrument now makes about itself, because no test can see
either:

- `liveDraws=0 over the pan … this arm is DEGENERATE` — Ruling 21's exact
  condition. The eighteen degenerate arms would have printed it.
- `did not start from a purged cache (tilesAfterPurge=…, warmBakes=…)` — the
  inheritance failure of §2.

## 4. M30

`docs/superpowers/notes/plan-3i-mutation-log.md`, section **M30 — criterion 8's
two arms both run with the flag false**. `ZoomArm.applyTo`'s
`cache.debugFullViewportQuery = this == ZoomArm.fullViewportQuery` forced to
`false`. **Red**, three tests, each on a different face of the defect: the
*sequence* of flag states, the *count* of arms that ran with it set, and the
disagreement between an arm's *label* and the cache it ran on
(`the label claims true and the cache ran at false`). Seven tests in the file
stayed green — under M30 everything about the instrument keeps working except
the difference between its two arms. `cp` aside, `diff`-confirmed mutation,
`cp` restore, empty `diff`, re-run green. Never `git checkout`.

The log entry also records what M30 does **not** gate: no test in this
repository can see that a flag was flipped on a phase where it does nothing.
That cost a full n=9 device run to find, and the defence built here is the
`liveDraws=0` warning, not a test.

## 5. Confirmation on the real app — a functional check, **not a measurement**

`ZOOM_ARMS=2 ENTITIES=50000 TILES=on JC_WINDOW=800x600 ZOOM_MODE=criterion8`,
profile build, `caffeinate -dimsu`, `lowpowermode 0` and AC power before and
after. Reached `R2 app-run: done`, nothing thrown, **zero warnings**.
Log: `scratchpad/KEEP_c8_FIXED_check.log`.

| repeat | arm | flag | tilesAfterPurge | warm | `tile hold` p95 | **`tile pan` p95** | pan frames | bakes | liveDraws |
|---|---|---|---|---|---|---|---|---|---|
| 1/2 | A | `debugFullViewportQuery=false` | 0 | 5 f / 3 b | 2.18 ms | **8.64 ms** | 120/120 | 14 | 10 |
| 1/2 | B | `debugFullViewportQuery=true` | 0 | 5 f / 3 b | 1.87 ms | **27.41 ms** | 120/120 | 14 | 10 |
| 2/2 | A | `debugFullViewportQuery=false` | 0 | 5 f / 3 b | 1.99 ms | **11.39 ms** | 120/120 | 14 | 10 |
| 2/2 | B | `debugFullViewportQuery=true` | 0 | 5 f / 3 b | 1.86 ms | **27.20 ms** | 120/120 | 14 | 10 |

**The check the fix had to pass:**

- **`liveDraws` is non-zero in arm B** — 10, on both repeats. The live fallback
  runs in this phase, so the flag has a code path to modify. It was 0 in all
  eighteen arms of the degenerate run.
- **Arm B's `tile pan` p95 is visibly above arm A's** — 27.41 vs 8.64 (3.17x)
  and 27.20 vs 11.39 (2.39x). Both arm-B figures exceed both arm-A figures with
  no overlap.
- **The control says the difference is not session drift.** `tile hold` reads
  A 2.18, 1.99 against B 1.87, 1.86 — no systematic direction, and if anything
  arm B is slightly *lower*, which is the opposite direction from the pan.
- Sampling is complete: 120 of 120 pan frames reported in every arm, no SHORT
  SAMPLE warning; the earlier runs lost three to five per arm to `drain`'s
  default of 4 extra frames.

**No number in this table is a measurement of record.** It is n=2 at 50,000
entities in an 800x600 window, run to prove the instrument responds to the
mutation it alternates. The measurement of record is `ZOOM_ARMS=9` at 500,000,
which has not been taken. The ratios above are not criterion 8's score and must
not be quoted as one.

## 6. Files

- `apps/dev_harness_2d/lib/measurement_rig.dart` — `tilePanStep`,
  `kTileHoldFrames`, `kTilePanFrames`, `PanArmReport`, `runTilePanArm`,
  `printPanArmReport`, `runCriterionArms<R>`, `zoomArmLabel`'s required `phase`.
- `apps/dev_harness_2d/lib/main.dart` — criterion 8's branch and `runPanArm`.
- `apps/dev_harness_2d/test/criterion8_pan_arm_test.dart` — new, 10 tests.
- `apps/dev_harness_2d/test/zoom_arm_wiring_test.dart` — `phase:` at three call
  sites; no assertion changed.
- `docs/superpowers/notes/plan-3i-mutation-log.md` — M30.

Nothing outside `apps/dev_harness_2d/` was modified except the mutation log.
`analysis_options.yaml` and `macos/Runner.xcodeproj/project.pbxproj` untouched;
every commit staged by named path.

## 7. Open, for the controller

- Ruling 21's own text should be closed out with the *second* finding this wave
  produced, which it did not predict: an arm inheriting the previous arm's warm
  generation. Ruling 14's concern 4 raised the possibility for the zoom arm and
  M15 settled it there — a zoom round trip retires the generation. A pan arm has
  no such excursion, so the same concern lands differently and needed the purge.
- `runTilePhases`' own warm loop has the early-exit weakness §2 describes
  (`tile warm: frames=1` in every transcript). It was left alone deliberately:
  criterion 9 reads that block and its figures must stay reproducible. Worth a
  ruling before anyone "fixes" it.
