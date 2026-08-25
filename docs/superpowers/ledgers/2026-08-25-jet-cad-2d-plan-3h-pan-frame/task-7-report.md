# Task 7 report — completed

**Status: DONE.** All six steps completed in one contiguous session. Low
Power Mode read `0` at every one of twenty `pmset` checks — before this task's
first run and after every single device run, including the final check taken
while writing this report. No run was discarded, no code was left mutated,
and only the results note is staged.

This attempt supersedes the prior blocked one (Low Power Mode flipped to `1`
mid-Step-1 there; the machine is now on AC power throughout this attempt).
That report's lessons were followed: `RIG=pan` used throughout, `pgrep`
self-match avoided (no polling loops were needed — every run stayed in the
foreground inside one blocking Bash call, well under any timeout), and
`/tmp/3h_narrowed_1.log` from the prior attempt was **not** reused — three
fresh narrowed runs were taken.

## `pmset` checks, in sequence, every one `0`

| # | position | timestamp | reading |
|---|---|---|---|
| 1 | session start, before touching `apps/dev_harness_2d` | 23:08:27 | `lowpowermode 0` |
| 2 | before narrowed run 1 | 23:10:11 | `0` |
| 3 | after narrowed run 1 | 23:10:38 | `0` |
| 4 | before narrowed run 2 | 23:10:51 | `0` |
| 5 | after narrowed run 2 | 23:11:18 | `0` |
| 6 | before narrowed run 3 | 23:11:25 | `0` |
| 7 | after narrowed run 3 | 23:11:51 | `0` |
| 8 | before `PAN_STEP=30` | 23:12:09 | `0` |
| 9 | after `PAN_STEP=30` | 23:12:48 | `0` |
| 10 | before `PAN_STEP=60` | 23:12:55 | `0` |
| 11 | after `PAN_STEP=60` | 23:13:33 | `0` |
| 12 | before M4 run 1 | 23:15:15 | `0` |
| 13 | after M4 run 1 | 23:15:54 | `0` |
| 14 | before M4 run 2 | 23:16:00 | `0` |
| 15 | after M4 run 2 | 23:16:27 | `0` |
| 16 | before M4 run 3 | 23:16:33 | `0` |
| 17 | after M4 run 3 | 23:17:00 | `0` |
| 18 | before restore-confirmation run | 23:18:08 | `0` |
| 19 | after restore-confirmation run | 23:18:45 | `0` |
| 20 | final check, writing this report | 23:18:53 | `0` |

The whole task ran between 23:08 and 23:19 local time — under 11 minutes wall
clock for eight device runs plus the mutant fire, two widget-test runs and the
restore. `RIG=pan` (see below) is why: each device run's `flutter drive`
completed in 20–40 seconds of wall clock, not the 20–45+ minutes the prior
attempt's `RIG=all` runs took (and mostly failed to complete).

## `RIG=pan` — used for every device run, and why

Every device run in this task (three narrowed, two `PAN_STEP`, three M4, one
restore-confirmation — nine total) used `--dart-define=RIG=pan`. Rationale,
stated in the results note too: R2 alone (`runR2Rig`/`runTilePhases`) is the
sole source of every figure Task 7's criteria need — `tile hold`, `tile pan`,
`tile pan step`, `tile probe`, `capacityMiB`, `tileBytes`, `liveDraws`,
`bakes`. `RIG=pan` runs R2 in full and makes R4a/R4b no-ops, which the file's
own header comment documents as the intended way to run one rig at a time at
500,000 entities. It also sidesteps the exact instability class the prior
attempt burned hours on (R4a/R4b hangs and one `Service has disappeared`
flake) without touching anything the criteria depend on. Because every run in
this task used the same rig selection, there is no comparability problem
between the rows this task computes ratios and deltas from — the one place
this task is not comparable to an external number is criterion 3b against the
spike's 16.66/15.26/17.40 ms figures, which almost certainly used a different
rig selection; flagged in the results note.

## Runs, logs, and figures — recorded as each finished

### Step 1 — narrowed arm, three runs

- Run 1: `/tmp/3h_narrowed_1.log` (fresh, this session — **not** the prior
  attempt's `/tmp/3h_narrowed_1.log`, which was overwritten by this run).
  `tile pan total p50=1.38ms p95=19.86ms max=38.03ms mean=3.71ms`.
  `tile hold total p50=1.89ms p95=2.77ms max=4.17ms mean=1.76ms`.
- Run 2: `/tmp/3h_narrowed_2.log`.
  `tile pan total p50=1.81ms p95=15.99ms max=49.66ms mean=3.89ms`.
  `tile hold total p50=1.39ms p95=1.66ms max=1.91ms mean=1.24ms`.
- Run 3: `/tmp/3h_narrowed_3.log`.
  `tile pan total p50=1.38ms p95=13.43ms max=41.95ms mean=3.27ms`.
  `tile hold total p50=1.45ms p95=1.79ms max=2.06ms mean=1.37ms`.

`capacityMiB=192.00` in every occurrence, all three logs. Peak
`tileBytes=27262976` (26.00 MiB) in all three, during the `tile pan` phase.
`bakes=14 perFrame=0.117 liveDraws=10` in the `tile pan` phase, identical in
all three (deterministic corpus/camera path).

No run was discarded at this step — all three completed cleanly on the first
attempt, `All tests passed.`, exit code 0.

### Step 2 — criterion 3 and 3b

`tile pan` p95 sorted: narrowed [13.43, 15.99, 19.86] → median **15.99**; M4
[36.14, 37.59, 38.14] → median **37.59** (computed with `python3`, not by
hand, to avoid an arithmetic slip: `37.59/15.99 = 2.3508442776735463`).

**Ratio = 2.35. Gate ≥ 2.4 — MISS.** Checked per the brief's own
troubleshooting list before accepting it: same `ENTITIES=500000` both arms,
same `TILES=on` both arms, same `RIG=pan` both arms, Low Power Mode `0`
before and after all six runs behind the ratio. None of those explain the
miss. Reported as a MISS, not adjusted, not re-run to chase 2.4.

**Criterion 3b**: narrowed p95 19.86/15.99/13.43 ms against 16.67 ms budget.
Median (15.99) lands under. One run (19.86, the first narrowed run) lands
3.19 ms over — a plainly larger miss than the spike's own worst sample
(17.40, 0.73 ms over). Stated as such in the results note, not smoothed into
"passes."

### Step 3 — `PAN_STEP` arms

- `PAN_STEP=30`: `/tmp/3h_step30.log`. `tile pan total p50=2.34ms p95=28.59ms
  max=54.98ms mean=9.79ms`, `bakes=60 perFrame=0.500 liveDraws=47`.
- `PAN_STEP=60`: `/tmp/3h_step60.log`. `tile pan total p50=18.18ms
  p95=32.35ms max=41.58ms mean=18.95ms`, `bakes=116 perFrame=0.967
  liveDraws=115`, `newEvictions=32` (the only arm in this task where the
  cache evicted tiles mid-phase), `tileBytes=100663296` (96.00 MiB).

Both completed on the first attempt, no discards.

### Step 4 — mutant M4

Backed up: `cp lib/src/tile_cache.dart /tmp/tile_cache.m4` (md5 verified
identical to the pre-edit file before editing). Applied the exact mutation
the brief specifies: kept `canvas.clipRect(uncovered, doAntiAlias: false)`
and `_lastStrip = strip;`, dropped `canvas.translate(strip.left, strip.top)`
and the `q`/`ViewportTransform` construction, passed `viewport` and
`quantised` straight to `_drawInto`. Full diff is in the results note and
matches `diff /tmp/tile_cache.m4 lib/src/tile_cache.dart` exactly — no
unrelated lines touched.

**`CI=true flutter test test/tile_fallback_test.dart` under M4 — RED**, not
green as the brief's Step 4 text predicted. One test failed: `criterion 2 and
2c: a partly baked frame equals the live frame`, on a triangle-count
assertion (`Expected: a value less than <54.0>`, `Actual: <70>`,
`InkReport(... liveTri: 60, tiledTri: 70)`). `criterion 2b` in the same file
still passed. Log: `/tmp/3h_m4_tile_fallback_test.log`.

**`CI=true flutter test` (whole `jet_cad_2d_flutter` package) under M4 —
RED.** Final tally: `+371 ~1 -1: Some tests failed.` — 371 passed, 1 skipped
(pre-existing, unrelated), exactly **one** failure in the entire package:
the same `criterion 2 and 2c` test. No other test anywhere in the suite
failed under M4 — confirmed by grepping the full log for `[E]` (one match)
and by the `-1` failure counter never exceeding 1 for the rest of the run.
Log: `/tmp/3h_m4_full_suite.log`.

**This is the finding flagged prominently, per instruction, rather than
adjusted to match the plan.** The plan's spec and the existing mutation log
(`docs/superpowers/notes/plan-3h-mutation-log.md`) both currently state "M4
has no unit witness" / "no unit gate can kill it." That is now false: the
triangle-count gate a later fix round added to `test/tile_fallback_test.dart`
to kill M5 (grow the walk to the viewport) also kills M4 (narrow the clip,
not the query) — both mutations leave the fallback walking the full viewport,
and the gate only sees geometry, not pixels, so it cannot tell the two
mutations apart. The mutation log's M4 section is not this task's file to
edit (the brief's own "Files" section and the controller's staging
instruction both scope this task to the results note only; the mutation log
says explicitly "Task 8b fires M4 and fills this section in"), so the results
note calls this out for whoever next touches that file.

**Device arm, three runs, fired anyway** — the widget-suite finding answers
what the pixels do, not what the device timing does, and criterion 3 still
needs the device denominator:

- Run 1: `/tmp/3h_m4_1.log`. `tile pan total p50=1.16ms p95=38.14ms
  max=73.91ms mean=5.02ms`. `tile hold total p50=1.30ms p95=2.35ms
  max=36.38ms mean=1.84ms`.
- Run 2: `/tmp/3h_m4_2.log`. `tile pan total p50=1.50ms p95=36.14ms
  max=77.55ms mean=5.17ms`. `tile hold total p50=1.70ms p95=2.68ms
  max=42.88ms mean=2.29ms`.
- Run 3: `/tmp/3h_m4_3.log`. `tile pan total p50=1.35ms p95=37.59ms
  max=64.31ms mean=5.09ms`. `tile hold total p50=1.44ms p95=2.37ms
  max=27.79ms mean=1.66ms`.

`capacityMiB=192.00` unchanged in all three. Peak `tileBytes=27262976`
unchanged in all three — identical to the narrowed arm, since tile geometry
and count are unaffected by M4. `bakes=14 liveDraws=10` in the `tile pan`
phase, identical to the narrowed arm too — M4 changes how much each fallback
walks, not how many frames fall back. No run was discarded at this step.

### Restore

`cp /tmp/tile_cache.m4 lib/src/tile_cache.dart` — **not** `git checkout`
(the file was never staged/committed this session, so there was nothing to
check out from; the copy restores the mutant's own pre-image). Verified:
`git diff -- lib/src/tile_cache.dart` and `git status --porcelain --
lib/src/tile_cache.dart` both empty after the copy.

`CI=true flutter test test/tile_fallback_test.dart` on the restored tree:
green, `+2: All tests passed!`.

One confirmation device run, `RIG=pan`, `/tmp/3h_restore_confirm.log`:
`tile pan total p50=1.75ms p95=18.24ms max=38.30ms mean=3.60ms` — back in the
narrowed arm's 13.43–19.86 ms range, nowhere near M4's 36.14–38.14 ms range.
Not counted as one of the three official narrowed runs.

## Criteria 6, 7, 8

- **Criterion 6** (`tile hold` p50 ≤ 2.0 ms, p95 ≤ 2.5 ms): three-run medians
  p50=1.45 ms, p95=1.79 ms — **PASS**. Flagged transparently: run 1's raw
  (non-median) p95 was 2.77 ms, individually over the 2.5 ms figure; the
  three-run median is what the criterion is scored against and it passes
  cleanly.
- **Criterion 7** (peak `tileBytes` ≤ 96 MiB): 27262976 bytes = 26.00 MiB,
  identical across all narrowed and M4 runs — **PASS**, well under budget.
- **Criterion 8** (`capacityMiB`, narrowed arm, expected 192.00): 192.00
  exactly, every occurrence, every narrowed run — **PASS**, no increase to
  explain.

## Discarded runs

**None.** Every one of the nine device runs in this task (three narrowed, two
`PAN_STEP`, three M4, one restore-confirmation) completed cleanly on its
first attempt with exit code 0 and `All tests passed.`. `RIG=pan` avoided the
instability class (R4a/R4b hangs, the `Service has disappeared` flake) that
cost the prior attempt every one of its runs.

## `git status --porcelain`, before staging

```
$ git status --porcelain
?? docs/superpowers/notes/2026-08-25-plan-3h-results.md
```

`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` does **not**
appear — confirmed separately with `git diff --stat --
apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` (empty output).
It was not staged and was not reverted; it simply did not show as dirty this
session, same as the prior attempt observed. `packages/jet_cad_2d_flutter/
lib/src/tile_cache.dart` shows no diff — confirmed restored exactly (see
Restore above). No `analysis_options.yaml` appears in git status anywhere in
the repo.

## Process/log cleanup state

`pgrep -fl "flutter_tools.snapshot drive|dev_harness_2d.app|caffeinate
-dimsu"` returns nothing as of this report — no lingering processes, and none
of the prior attempt's self-matching `pgrep -f` polling-loop problem
recurred, because no polling was needed: every run blocked synchronously
inside one Bash call. All eleven `/tmp/3h_*.log` files (3 narrowed, 2
`PAN_STEP`, 3 M4, 1 restore-confirmation) plus `/tmp/3h_m4_tile_fallback_test.log`
and `/tmp/3h_m4_full_suite.log` and `/tmp/tile_cache.m4` are left in place for
inspection. No golden PNGs were touched.

## Commit

Staged and committed only `docs/superpowers/notes/2026-08-25-plan-3h-results.md`,
per the controller's amendment 6 (ignore the brief's `git add` line for
`STATUS.md` — Task 8 owns that file). Commit SHA recorded by the calling
session after this report; see the git log for
"docs: Plan 3h's device measurements and M4's ruling".

## Concerns for review

1. **Criterion 3 misses its gate** (2.35 against ≥ 2.4). This is this task's
   headline number and it is reported as a genuine miss, not adjusted. The
   results note discusses why it plausibly still reads as "the narrowing is
   real" (criteria 4/5's much larger deltas, M4's now-doubled kill via the
   widget suite) rather than as evidence the fix regressed, but the number
   itself is what it is.
2. **The plan's and mutation log's claim that M4 has no unit witness is now
   false**, discovered and reported per this task's explicit instruction to
   test rather than assume. The mutation log's M4 placeholder section needs
   updating by whoever owns Task 8b; this task does not touch that file.
3. **Criterion 3b is a genuine mixed result**: two of three runs land under
   the 16.67 ms budget, one lands clearly over it (more so than the spike's
   near miss). Reported plainly rather than rounded to a clean pass.
4. **`RIG=pan` was used throughout.** I believe this is sound (argued above
   and in the results note) but it is a deviation from the brief's literal
   command line, and it is the reason this task took under 11 minutes of
   device-run wall clock rather than the hours the prior attempt spent.

---

## Fix round 1

Coordinator approved commit `894f3a2` on spec and quality (reviewer traced
every figure to a log independently, re-fired M4 itself and reproduced the
`+371 ~1 -1` tally and the `liveTri: 60, tiledTri: 70` figure exactly). No
re-measurement was requested or performed in this round — all four edits
below are to the results note's text only, using figures already in hand
from the original measurement.

### Edit 1 — Ruling 10, first half: criterion 3's ratio is measurement-inconclusive

Kept the MISS exactly as originally written, and added four new paragraphs
to the note's Step 2 immediately after it, covering: (a) the measurement
cannot settle whether 2.35 is real or noise (narrowed p95 CV 19.7%, M4 p95
CV 2.8%, nine pairwise ratios spanning 1.82-2.84 and straddling 2.4 in the
middle); (b) the M4 arm ran last in a session that had grown noisier, shown
via `tile hold` max (a phase M4's code cannot touch: `bakes=0 liveDraws=0`
both arms) reading an order of magnitude higher in the M4 runs (36.38/42.88/
27.79 vs 1.91/2.06/4.17 ms), which biases the ratio's numerator upward,
against the miss; (c) the 2.4 gate itself came from the spike's 2.59x, whose
numerator (43.13 ms) was measured in a different session than its own
16.66 ms denominator-side figure — a cross-session comparison of exactly the
kind criterion 3 was made a ratio to avoid, with the gap concentrated almost
entirely in the numerator (-12.8% vs this task's M4, against only -4% on the
denominator side); (d) settling it would need interleaved n=7-9 runs, not
three-then-three blocked at n=3, and that is deferred to Plan 3i.

Quoted, the note's new criterion 3 core paragraph (the rest is the four
paragraphs after it, quoted in full in the note itself):

> **Gate ≥ 2.4 — MISS.** The number is reported as measured; the threshold is
> not adjusted. Both arms ran at the same `ENTITIES=500000`, the same
> `TILES=on`, the same `RIG=pan`, in the same session, and Low Power Mode read
> `0` before and after every one of the six runs behind this ratio — the three
> checks the brief asks to make before accepting a sub-2.4 reading. None of
> them explain the miss; the miss is real, and it is reported as a MISS,
> unadjusted, per instruction. Three things are true about it at once, below:
> the measurement cannot settle whether 2.35 is a genuine miss or noise; the
> ordering of the two arms biases the ratio against the miss, not for it; and
> the 2.4 gate itself was derived in a way the spec's own argument for making
> criterion 3 a ratio warns against.

### Edit 2 — Ruling 10, second half: the "corroborate" sentence replaced with the mean, labelled as evidence only

Removed the sentence claiming criteria 4/5 and the M4 unit result
"corroborate that the narrowing is doing real, large work" — correct per the
coordinator's point that 4/5 have no M4 counterpart and say nothing about the
narrowing specifically. Replaced with a new paragraph using the mean, which
`measurement_rig.dart:63-70` designates as the differencing statistic, and
explicitly labelled as evidence rather than a gate:

> **Evidence, not a gate: the mean tells a cleaner story than p95 does, and it
> is reported as evidence only.** `measurement_rig.dart:63-70` designates the
> mean, not p50 or p95, as the statistic for a differencing measurement of
> exactly this shape — a cost that lands on a minority of frames. Narrowed
> `tile pan` means: {3.71, 3.89, 3.27} ms, CV 8.8%. M4 `tile pan` means: {5.02,
> 5.17, 5.09} ms, CV 1.5%. The two sets do not overlap at all — narrowed's
> highest (3.89) sits below M4's lowest (5.02) — and both are far tighter than
> either arm's p95 spread: **Δ ≈ 1.38 ms per frame**. Since `bakes=14
> liveDraws=10` in the same 120-frame phase on both arms (Step 1, Step 4), that
> per-frame delta concentrates onto the same roughly-ten fallback frames either
> way, which is consistent with **about 16.6 ms saved per fallback frame**.
> This is offered as evidence that the narrowing is doing real, low-noise work
> — it is **not** a substitute score for criterion 3. Criterion 3 is defined on
> p95; scoring it on whichever statistic happens to pass after p95 already
> missed would be moving the gate after seeing the result, and that is not what
> happened here. Criterion 3's ruling is, and remains, the p95 **MISS** above.

All figures (CVs, the pairwise ratios, the means, the 1.38 ms delta, the
-12.8%/-4% percentages) were recomputed independently with `python3` from the
same per-run numbers already in the note and report, not re-measured or
sourced from the coordinator's message verbatim without checking — cross-
checked against the coordinator's stated figures and found to match exactly.

### Edit 3 — Ruling 11: criterion 6 rescored per-run, not by median

Added a new "Criterion 6" section, placed after criterion 3b's section (so
the two adjacent sections state and then apply the same scoring rule), and
changed criterion 6's row in the summary table from PASS to MISS:

> Run 1's p95 (2.77 ms) breaches the 2.5 ms gate outright. **Criterion 6:
> MISS**, scored per run — the same rule criterion 3b uses just above for its
> own "one of three runs over budget" finding. A three-run threshold cannot be
> scored by median in one section of this note and by median in another and
> still be one document: 3b refused to smooth run 1's 19.86 ms over-budget
> reading into a pass on the strength of the median, so 6 does not smooth run
> 1's 2.77 ms over-gate reading into a pass on the strength of its median
> either. p50 does not breach its own 2.0 ms gate in any run (highest reading
> 1.89 ms).

No new data — the per-run p50/p95 table under this section is the same three
narrowed-arm `tile hold` figures already recorded in Step 1.

### Edit 4 — two minors

- The M4-vs-M5 parenthetical, which the coordinator flagged as
  self-contradictory as written, is replaced: both mutants are now described
  as converging on the same end state — `_drawInto` receiving the full
  viewport instead of the strip — which is all the triangle-count gate can
  see, rather than the previous wording that implied the gate distinguishes
  between them by name.
- The `PAN_STEP=60` `tileBytes` sentence now states the figure
  (`100663296` bytes) is **exactly** 96.00 MiB, criterion 7's bound reached
  rather than approached, and adds the explicit phrase "at, not under."

### Verification before committing

`git status --porcelain` showed only
`docs/superpowers/notes/2026-08-25-plan-3h-results.md` as modified —
`analysis_options.yaml` did not appear anywhere in the repo's status, and
`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` did not appear
either (unstaged, since it was never modified in this fix round — no device
runs were performed). Staged and committed only the results note.

**Commit:** `838c45470fc068274b58f9a8aeb1f1803b5a81b3` — "docs: Plan 3h fix
round 1 -- criterion 3's ratio is inconclusive, criterion 6 rescored".
