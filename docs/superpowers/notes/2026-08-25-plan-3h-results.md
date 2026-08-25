# Plan 3h results

**Spec:** [2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md](../specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md)

## Baseline, recorded from the M4 arm

Machine: macOS, `flutter drive --profile -d macos`, Low Power Mode `0`.

The baseline is the **M4 arm**, not a separate pre-change measurement. Plan 3h's
narrowing landed before Low Power Mode was turned off, so there is no unnarrowed
tree left to measure; M4 reverts the walk to the viewport while keeping the
clip, which is behaviourally the pre-narrowing code. Measuring it in the same
session as the narrowed arm is also the stronger method: same thermal state,
same binary lineage, and criterion 3 is a ratio precisely so that both arms are
read in one regime.

**Rig selection: `RIG=pan` was used for every device run in this note**,
narrowed arm, `PAN_STEP` arms and M4 arm alike. R2 (the pan/zoom rig) is the
sole source of every figure this task's criteria need — `tile hold`,
`tile pan`, `tile pan step`, `tile probe`, `capacityMiB`, `tileBytes`,
`liveDraws`, `bakes` all print from inside `runR2Rig`/`runTilePhases`, which
`RIG=pan` runs in full while skipping R4a/R4b. A prior attempt at this task
(see `task-7-report.md`) hit repeated instability in R4a/R4b at 500,000
entities (a `DriverError: ... Service has disappeared` flake, a
harness-killed run, two 0%-CPU hangs) and switched to `RIG=pan` for the same
reason. Because *every* run in this note used the same rig selection, the
comparability concern the controller amendment raised does not apply within
this note: criterion 3's ratio, the `PAN_STEP` arms and the M4 arm are all
read from the same regime. The one place this note is not comparable to an
external number is criterion 3b against the spike's 16.66/15.26/17.40 ms,
which almost certainly ran under a different rig selection — flagged there.

All device runs below ran with `ENTITIES=500000 TILES=on`, `caffeinate -dimsu`
active throughout, and `pmset -g | grep -i lowpower` read `0` immediately
before and immediately after every single run (twenty checks total across
this task, every one `0` — see the report for the full timestamped list). No
run was discarded.

## Step 1 — three runs of the narrowed arm

Commands as the brief gives them, with `--dart-define=RIG=pan` added (see rig
note above). Logs: `/tmp/3h_narrowed_1.log`, `/tmp/3h_narrowed_2.log`,
`/tmp/3h_narrowed_3.log`.

| run | `tile pan` total | `tile hold` total |
|---|---|---|
| 1 | p50=1.38ms **p95=19.86ms** max=38.03ms mean=3.71ms | p50=1.89ms **p95=2.77ms** max=4.17ms mean=1.76ms |
| 2 | p50=1.81ms **p95=15.99ms** max=49.66ms mean=3.89ms | p50=1.39ms **p95=1.66ms** max=1.91ms mean=1.24ms |
| 3 | p50=1.38ms **p95=13.43ms** max=41.95ms mean=3.27ms | p50=1.45ms **p95=1.79ms** max=2.06ms mean=1.37ms |

`tile pan frames` reported per run: 120, 124, 123 (the timing-callback bucket
does not map 1:1 to the 120 `pumpFrame` calls the phase issues; harmless,
consistent with normal `FrameTiming` delivery, seen on both arms below).

**`capacityMiB`**: `192.00` in all three runs, every occurrence in every log
(the `tile warm` line and both per-phase lines). Matches criterion 8's
expected value exactly, no increase.

**Peak `tileBytes`**: `27262976` bytes (= 26.00 MiB) in all three runs, the
peak occurring during the `tile pan` phase (`tile hold`'s figure is
`12582912` = 12.00 MiB; the corpus and camera path are identical across runs,
so this is deterministic, not a coincidence).

## Step 2 — Criterion 3, the ratio

`tile pan` p95, narrowed arm, three runs: 19.86, 15.99, 13.43 ms.
**Median (narrowed) = 15.99 ms.**

`tile pan` p95, M4 arm, three runs (Step 4 below): 38.14, 36.14, 37.59 ms.
**Median (M4) = 37.59 ms.**

**Ratio = median(M4 p95) / median(narrowed p95) = 37.59 / 15.99 = 2.35.**

**Gate ≥ 2.4 — MISS.** The number is reported as measured; the threshold is
not adjusted. Both arms ran at the same `ENTITIES=500000`, the same
`TILES=on`, the same `RIG=pan`, in the same session, and Low Power Mode read
`0` before and after every one of the six runs behind this ratio — the three
checks the brief asks to make before accepting a sub-2.4 reading. None of
them explain the miss; the miss is real, and it is reported as a MISS,
unadjusted, per instruction. Three things are true about it at once, below:
the measurement cannot settle whether 2.35 is a genuine miss or noise; the
ordering of the two arms biases the ratio against the miss, not for it; and
the 2.4 gate itself was derived in a way the spec's own argument for making
criterion 3 a ratio warns against.

**The measurement cannot settle the question either way.** Narrowed p95
{13.43, 15.99, 19.86}: mean 16.43, **CV 19.7%**. M4 p95 {36.14, 37.59,
38.14}: mean 37.29, **CV 2.8%**. Pairing every M4 run against every narrowed
run gives nine ratios, sorted: 1.82, 1.89, 1.92, 2.26, 2.35, 2.39, 2.69, 2.80,
2.84 — a span of 1.82 to 2.84 that straddles 2.4 in the middle, not near
either edge. Plainly: re-running this exact arrangement again, hoping the
median lands at or above 2.4, would be close to a coin flip, not a
confirmation of either result.

**The M4 arm ran last, in a session that had grown visibly noisier, which
biases the ratio's numerator upward — against the miss, not for it.** `tile
hold` is a phase M4's code change cannot touch at all (`bakes=0 liveDraws=0`
in every run, narrowed and M4 alike — see the tables in Step 1 and in Step
4's device-arm section), so any difference in its readings is pure session
drift, not signal from the mutation. Narrowed `tile hold` max: 1.91, 2.06,
4.17 ms across the three runs. M4 `tile hold` max, same phase, run order 1/2/3
(fired after all three narrowed runs and after the mutation itself): 36.38,
42.88, 27.79 ms — an order of magnitude higher, on a phase M4 is inert on.
Whatever drove that up plausibly touched `tile pan`'s numerator in the same
session, in the direction that inflates the ratio. If the M4 arm carries that
same bias on `tile pan`, the true ratio is more likely below 2.35 than above
it — which argues the miss, if anything, understates itself.

**The 2.4 gate was derived across sessions — the exact comparison criterion 3
was designed to avoid.** It comes from the spike's 2.59x, whose numerator was
the spike's own separately-run "clean" arm at 43.13 ms — a different machine
session than the one that produced the spike's 16.66 ms clamped figure.
Compared against this task's M4 figure (37.59 ms), that 43.13 ms numerator
reads **−12.8%**; compared against the spike's own 16.66 ms and this task's
narrowed median (15.99 ms), the denominator side reads only **−4%**. The gap
between sessions sits almost entirely in the numerator, not the denominator —
and a gate built from a cross-session numerator is the comparison the spec's
own §"Criterion 3 is a ratio" gives as the reason to make this criterion a
ratio in the first place, not an absolute figure.

**Settling this needs more than this task's design can give it.**
Distinguishing 2.35 from 2.4 with any confidence needs interleaved runs —
narrow, M4, narrow, M4, … rather than three-then-three blocked, so that
session drift lands on both arms instead of concentrating on whichever ran
last — and something on the order of n=7–9 per arm, not n=3. That is not
attempted here. It is written up as an open question for **Plan 3i**, not
resolved in this task.

**Evidence, not a gate: the mean tells a cleaner story than p95 does, and it
is reported as evidence only.** `measurement_rig.dart:63-70` designates the
mean, not p50 or p95, as the statistic for a differencing measurement of
exactly this shape — a cost that lands on a minority of frames. Narrowed
`tile pan` means: {3.71, 3.89, 3.27} ms, CV 8.8%. M4 `tile pan` means: {5.02,
5.17, 5.09} ms, CV 1.5%. The two sets do not overlap at all — narrowed's
highest (3.89) sits below M4's lowest (5.02) — and both are far tighter than
either arm's p95 spread: **Δ ≈ 1.38 ms per frame**. Since `bakes=14
liveDraws=10` in the same 120-frame phase on both arms (Step 1, Step 4), that
per-frame delta concentrates onto the same roughly-ten fallback frames either
way, which is consistent with **about 16.6 ms saved per fallback frame**.
This is offered as evidence that the narrowing is doing real, low-noise work
— it is **not** a substitute score for criterion 3. Criterion 3 is defined on
p95; scoring it on whichever statistic happens to pass after p95 already
missed would be moving the gate after seeing the result, and that is not what
happened here. Criterion 3's ruling is, and remains, the p95 **MISS** above.

## Step 2 (continued) — Criterion 3b, the absolute figure

Narrowed `tile pan` p95, three runs: **19.86, 15.99, 13.43 ms**, against the
**16.67 ms** budget the spec deliberately declined to gate.

- Run 3 (13.43 ms) and run 2 (15.99 ms) land **under** 16.67 ms.
- Run 1 (19.86 ms) lands **over** 16.67 ms by 3.19 ms — **not a near miss**,
  a clear miss, larger than the spike's own worst sample (17.40 ms, 0.73 ms
  over).
- **Median = 15.99 ms, which lands under 16.67 ms** — stated plainly: on the
  median, the plan lands under budget. But one of three runs misses it
  outright, by more than the spike's near miss did. This is not smoothed into
  a clean pass: the honest statement is "median under budget, one run
  clearly over, more variance on this machine tonight than the spike showed."
  **RECORDED**, ungated per spec.

## Criterion 6 — scored against the threshold, not the median

The spec states criterion 6 as a per-run threshold — `tile hold` p50 ≤
2.0 ms, p95 ≤ 2.5 ms — not as a threshold on a three-run median. Narrowed
`tile hold`, per run (from Step 1's table):

| run | p50 | p95 |
|---|---|---|
| 1 | 1.89ms | **2.77ms** |
| 2 | 1.39ms | 1.66ms |
| 3 | 1.45ms | 1.79ms |

Run 1's p95 (2.77 ms) breaches the 2.5 ms gate outright. **Criterion 6:
MISS**, scored per run — the same rule criterion 3b uses just above for its
own "one of three runs over budget" finding. A three-run threshold cannot be
scored by median in one section of this note and by median in another and
still be one document: 3b refused to smooth run 1's 19.86 ms over-budget
reading into a pass on the strength of the median, so 6 does not smooth run
1's 2.77 ms over-gate reading into a pass on the strength of its median
either. p50 does not breach its own 2.0 ms gate in any run (highest reading
1.89 ms).

## Step 3 — Criteria 4 and 5, `PAN_STEP` arms

Both runs used `RIG=pan` (see rig note above), `ENTITIES=500000 TILES=on`.
Logs: `/tmp/3h_step30.log`, `/tmp/3h_step60.log`. Recorded, not gates.

**`PAN_STEP=30`** (`tile pan step: dx=-27.5744 dy=-11.8176 magnitude=30.0000`):
```
tile pan total  p50=2.34ms p95=28.59ms max=54.98ms mean=9.79ms
bakes=60 perFrame=0.500 blits=1527 carryOverBlits=0 liveDraws=47 newEvictions=0 liveTiles=72 tileBytes=75497472
capacityMiB=192.00
```

**`PAN_STEP=60`** (`tile pan step: dx=-55.1487 dy=-23.6352 magnitude=60.0000`):
```
tile pan total  p50=18.18ms p95=32.35ms max=41.58ms mean=18.95ms
bakes=116 perFrame=0.967 blits=1215 carryOverBlits=0 liveDraws=115 newEvictions=32 liveTiles=96 tileBytes=100663296
capacityMiB=192.00
```

A faster pan bakes far more per frame (`perFrame` 0.117 at the historical
step → 0.500 at 30 px/frame → 0.967 at 60 px/frame) and pushes `liveDraws`
from 10 to 47 to 115 — at 60 px/frame nearly every frame takes the live
fallback at least once, which is why `p50` itself rises to 18.18 ms (the
median frame is no longer a pure blit, unlike the historical-step arm). At
60 px/frame `tileBytes` also crosses toward `newEvictions=32`, the only arm
in this note where the cache evicted tiles mid-phase, and `tileBytes` reaches
`100663296` bytes — **exactly** 96.00 MiB, criterion 7's bound reached, not
merely approached: **at, not under**. Worth flagging beside criterion 7 even
though criterion 7 itself is scored on the narrowed arm's default-step
figure (26.00 MiB, comfortably under), not this sweep.

## Step 4 — Mutant M4

**M4's code change**, applied to
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` (backed up first to
`/tmp/tile_cache.m4`), exactly as specified: kept `canvas.clipRect(uncovered,
doAntiAlias: false)` and `_lastStrip = strip;`, dropped `canvas.translate`,
and passed `viewport`/`quantised` to `_drawInto` instead of the strip-sized
size and shifted transform:

```diff
     final strip = stripFor(uncovered, viewport);
     _lastStrip = strip;
-    canvas.translate(strip.left, strip.top);
-    final q = quantised.worldToScreenMatrix;
     _drawInto(
         canvas,
-        Size(strip.width, strip.height),
-        ViewportTransform(
-            worldToScreenMatrix: Transform2(
-                q.a, q.b, q.c, q.d, q.e - strip.left, q.f - strip.top)),
+        viewport,
+        quantised,
         painter,
         sink,
         vertices,
         origin,
         null);
     canvas.restore();
```

### The plan's claim ("M4 has no unit witness") is FALSE — reported prominently

The plan and the existing mutation log
(`docs/superpowers/notes/plan-3h-mutation-log.md`, M4's placeholder section)
both state M4 dies only on criterion 3's device ratio and that "no unit gate
can kill it." **This is no longer true.** After the plan was written, a
reviewer found M5 (grow the walk to the viewport, leaving the clip narrow)
and a fix round added a triangle-count gate to
`test/tile_fallback_test.dart`'s "criterion 2 and 2c" test specifically to
kill it. M4 also walks the whole viewport — arrived at from a different
starting mutation than M5 (M4 keeps the narrow clip and drops the
strip-sized query; M5, per the mutation table, grows the query to the
viewport while leaving the clip untouched), but both mutants end up handing
`_drawInto` the full viewport instead of the strip. That shared end state is
all the triangle-count gate can see — it counts geometry, not pixels, so it
cannot tell "narrow the clip, not the query" apart from "grow the query,
leave the clip." The same gate that was built to kill M5 kills M4 as well.

`CI=true flutter test test/tile_fallback_test.dart` under M4 — **RED**, not
green as the brief's Step 4 predicted:

```
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: a value less than <54.0>
    Actual: <70>
     Which: is not a value less than <54.0>
  pan Offset(37.0, 0.0): the tiled arm emitted as much geometry as the full-frame live arm, so the fallback walked far more than the strip: InkReport(live: 38886, tiled: 38886, stray: 0, uncovered: 0, differing: 0, liveTri: 60, tiledTri: 70)
```
(`criterion 2b` in the same file still passes.) Full log:
`/tmp/3h_m4_tile_fallback_test.log`.

**The whole-package sweep** (`CI=true flutter test`, the entire
`jet_cad_2d_flutter` package, not one file) — **RED**, exactly one failure
out of the whole suite:

```
00:05 +371 ~1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
```
371 passed, 1 skipped (`~1`, pre-existing and unrelated to this mutation), 1
failed — the same "criterion 2 and 2c" test, the only failure anywhere in the
package. Full log: `/tmp/3h_m4_full_suite.log`.

**This is the finding to report prominently**: M4 gained a unit witness the
plan did not anticipate, contradicted by the retroactive M5 fix round. The
mutation log's M4 placeholder section ("no unit gate can kill it... It dies
only on criterion 3's device ratio") needs correction — that text is now
false and Task 8b (which owns that file) should update it to say M4 dies on
both the widget suite and the device ratio.

### Device arm, three runs, taken after the widget-suite finding

Fired anyway, per instruction — the pixels being wrong (which the widget
suite now proves) does not answer what the device timing does, and criterion
3's ratio still needs the device denominator. Logs: `/tmp/3h_m4_1.log`,
`/tmp/3h_m4_2.log`, `/tmp/3h_m4_3.log`.

| run | `tile pan` total | `tile hold` total |
|---|---|---|
| 1 | p50=1.16ms **p95=38.14ms** max=73.91ms mean=5.02ms | p50=1.30ms p95=2.35ms max=36.38ms mean=1.84ms |
| 2 | p50=1.50ms **p95=36.14ms** max=77.55ms mean=5.17ms | p50=1.70ms p95=2.68ms max=42.88ms mean=2.29ms |
| 3 | p50=1.35ms **p95=37.59ms** max=64.31ms mean=5.09ms | p50=1.44ms p95=2.37ms max=27.79ms mean=1.66ms |

`capacityMiB=192.00` in all three (unchanged by M4, as expected — M4 does not
touch the vertex sink's capacity path). Peak `tileBytes=27262976` (26.00 MiB)
in all three, identical to the narrowed arm (tile geometry and count are
unaffected by M4; only the live-fallback walk's extent changes).
`bakes=14 liveDraws=10` in the `tile pan` phase in all three — identical to
the narrowed arm's bake/liveDraw counts, confirming M4 does not change *how
many* frames fall back, only how much each fallback walks.

**M4's device ratio, computed against itself under this note's baseline
framing**: M4 *is* the baseline arm here, so the ratio it reports against
itself is `median(M4 p95) / median(M4 p95) = 1.0`. Restated in the terms
this note's baseline section frames it: under M4, the shipped (narrowed) code
reads 2.35x faster (Step 2's ratio), which is the sense in which "M4 dies on
criterion 3" — not because M4 fails a ratio computed from itself, but because
the actual shipped code clears 2.35x over what M4 represents, while a true
regression would read close to 1.0. The ratio that matters for M4's ruling is
Step 2's 2.35, read as "the narrowed code over the pre-narrowing code," and
M4 is now doubly dead: the widget suite catches it directly (RED above), and
even if it hadn't, the device ratio shows the narrowing is real (not ≈ 1.0,
though short of the 2.4 gate — see Step 2's MISS discussion).

**An absolute threshold could not have witnessed M4, because correct code
fails 16.67 too.** The narrowed arm's own p95 figures (19.86, 15.99,
13.43 ms) straddle 16.67 ms — one run already over it on the shipped, correct
tree — while M4's p95 figures (38.14, 36.14, 37.59 ms) are more than double
that. A single 16.67 ms gate would fail both the correct tree and M4 on some
runs, and pass neither reliably; it cannot distinguish them. Only the ratio,
read against the same-session narrowed arm, can.

### Restoring the tree

```
cp /tmp/tile_cache.m4 lib/src/tile_cache.dart
```
(**not** `git checkout` — the file was never staged or committed, so this
copies the mutant's own pre-image back rather than reverting via git.)
Confirmed: `git diff -- lib/src/tile_cache.dart` empty, `git status
--porcelain -- lib/src/tile_cache.dart` empty.

`CI=true flutter test test/tile_fallback_test.dart` on the restored tree:
green, `+2: All tests passed!` (both `criterion 2 and 2c` and `criterion 2b`
pass).

One confirmation device run on the restored tree (`RIG=pan`,
`ENTITIES=500000 TILES=on`, log `/tmp/3h_restore_confirm.log`): `tile pan`
total `p50=1.75ms p95=18.24ms max=38.30ms mean=3.60ms` — back in the narrowed
arm's range (13.43–19.86 ms), not M4's (36.14–38.14 ms). This run is a
confirmation only, not counted among the three official narrowed runs above.

## Criteria summary

| # | criterion | result | figure |
|---|---|---|---|
| 3 | `tile pan` p95 ratio, M4/narrowed, ≥ 2.4x | **MISS** | 2.35x (37.59 / 15.99 ms); n=3 per arm cannot distinguish this from noise (pairwise ratios span 1.82–2.84) and the M4 arm's ordering biases the ratio against the miss — see Step 2 |
| 3b | `tile pan` p95 absolute vs 16.67 ms | **RECORDED** | median 15.99 ms under budget; 1 of 3 runs (19.86 ms) over budget by 3.19 ms — not a clean pass |
| 4 | `tile pan` p95 at `PAN_STEP=30` | **RECORDED** | p95=28.59ms, bakes=60 perFrame=0.500 liveDraws=47 |
| 5 | `tile pan` p95 at `PAN_STEP=60` | **RECORDED** | p95=32.35ms, bakes=116 perFrame=0.967 liveDraws=115 |
| 6 | `tile hold` p50 ≤ 2.0ms, p95 ≤ 2.5ms | **MISS** | run 1's p95 (2.77ms) breaches the 2.5ms gate; scored per run, same rule as 3b — see "Criterion 6" section |
| 7 | peak `tileBytes` ≤ 96 MiB | **PASS** | 27262976 bytes = 26.00 MiB |
| 8 | `capacityMiB`, narrowed arm | **PASS** | 192.00, exact match, all runs, no increase |
| M4 | dies on criterion 3 and (newly) on the widget suite | **DIES — doubly** | widget suite RED (`tile_fallback_test.dart`, criterion 2/2c); device ratio 2.35x (short of 2.4, though the ratio's own reliability at n=3 is itself open — see Step 2) |

**Exit-gate note:** criterion 3, this task's headline, misses its gate
(2.35 against ≥ 2.4), and criterion 6 also misses on one run's p95. Per
instruction neither is adjusted or re-run to chase its threshold. Criterion
3's miss is reported alongside an explicit statement that n=3 per arm cannot
settle whether it is real or noise, that the run ordering biases it against
the miss, and that the 2.4 gate was itself derived across sessions — all
three written up for Plan 3i rather than resolved here. The mean, offered
separately as evidence and not as a gate, shows a clean, non-overlapping,
low-noise Δ≈1.38 ms/frame in the narrowing's favor. Six device runs support
criterion 3 (three narrowed, three M4), all taken in one contiguous session
with Low Power Mode confirmed off before and after each.
