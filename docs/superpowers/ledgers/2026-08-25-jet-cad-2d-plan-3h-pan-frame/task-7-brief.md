### Task 7: The device measurement, and mutant M4

**Files:**
- Modify: `docs/superpowers/notes/2026-08-25-plan-3h-results.md`

**Interfaces:**
- Consumes: Task 1's baseline, Task 6's `PAN_STEP`.
- Produces: criteria 3, 3b, 4, 5, 6, 7, 8 and M4's ruling.

- [ ] **Step 1: Three runs of the narrowed arm**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d
pmset -g | grep -i lowpower   # must read 0
for i in 1 2 3; do
  caffeinate -dimsu flutter drive --profile -d macos \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart \
    --dart-define=ENTITIES=500000 --dart-define=TILES=on \
    > /tmp/3h_narrowed_$i.log 2>&1
done
grep -A4 "tile pan" /tmp/3h_narrowed_*.log | grep "total "
grep "tile hold" -A4 /tmp/3h_narrowed_*.log | grep "total "
grep "capacityMiB" /tmp/3h_narrowed_*.log | tail -3
grep "tileBytes" /tmp/3h_narrowed_*.log | tail -3
```

Record: `tile pan` p95 x3 (criterion 3b), `tile hold` p50 and p95 x3 (criterion 6), `capacityMiB` (criterion 8, expected **192.00**), peak `tileBytes` (criterion 7, ≤ 96 MiB).

- [ ] **Step 2: Criterion 3, the ratio**

Compute `median(baseline p95) / median(narrowed p95)`. **Gate: ≥ 2.4.** The spike measured 2.59.

If it lands below 2.4, **do not adjust the threshold.** Report the number, and check first that both arms ran at the same `ENTITIES`, the same `TILES`, and with Low Power Mode off.

- [ ] **Step 3: Criteria 4 and 5, recorded**

```sh
for s in 30 60; do
  caffeinate -dimsu flutter drive --profile -d macos \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart \
    --dart-define=ENTITIES=500000 --dart-define=TILES=on \
    --dart-define=PAN_STEP=$s > /tmp/3h_step$s.log 2>&1
  echo "== $s =="; grep "tile pan step" /tmp/3h_step$s.log
  grep -A4 "tile pan" /tmp/3h_step$s.log | grep "total "
done
```

**These are recorded, not gates.** Also record `liveDraws` and `bakes` from each, since a faster pan changes the composition and the p95 alone does not say how.

- [ ] **Step 4: Fire mutant M4**

M4 is the original defect: **narrow the clip, not the query.**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter
cp lib/src/tile_cache.dart /tmp/tile_cache.m4
```

In `paintFrame`'s fallback branch, keep `canvas.clipRect(uncovered, ...)` and `_lastStrip = strip;`, but revert the walk to the viewport: drop the `canvas.translate`, and pass `viewport` and `quantised` to `_drawInto` as the code did before Task 5. Then:

```sh
CI=true flutter test test/tile_fallback_test.dart   # must stay GREEN -- M4's pixels are correct
cd /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d
caffeinate -dimsu flutter drive --profile -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=ENTITIES=500000 --dart-define=TILES=on > /tmp/3h_m4.log 2>&1
grep -A4 "tile pan" /tmp/3h_m4.log | grep "total "
```

Expected: the sweep stays green — **M4 has no unit witness, and confirming that is part of firing it** — and `tile pan` p95 returns to roughly the baseline, so the ratio against Task 1's baseline reads ≈ 1.0 and M4 dies on criterion 3.

Restore from `/tmp/tile_cache.m4` and re-run one narrowed device run to confirm the tree is back.

- [ ] **Step 5: Write the results note**

Fill in the note created in Task 1 with every figure above, one section per criterion, each stating **PASS**, **MISS** or **RECORDED**. State criterion 3b's absolute figures beside the 16.67 ms budget and say plainly whether the plan lands under it — the spike's median was 16.66 with one run at 17.40, and this is the number the spec deliberately declined to gate.

Include the M4 section: the sweep's green result, the device ratio, and the sentence that matters — **an absolute threshold could not have witnessed M4, because correct code fails 16.67 too.**

- [ ] **Step 6: Commit**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
git add docs/superpowers/notes/2026-08-25-plan-3h-results.md
git commit -m "docs: Plan 3h's device measurements and M4's ruling"
```

---


---

## Controller amendment — binding, and it changes what "the baseline" means

Task 1 was blocked at its first step: Low Power Mode was on, which `STATUS.md`
records as a uniform ~24% skew, so no baseline was ever measured and the
results note this brief says to "modify" **does not exist**. Low Power Mode has
since been turned off. Under two controller rulings the baseline moved here.

**1. You create the results note; it is not there to modify.**
Create `docs/superpowers/notes/2026-08-25-plan-3h-results.md` with this header,
then the criterion sections the steps below ask for:

```markdown
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
```

**2. The M4 arm gets three runs, not one, because it is now the denominator's
source.** Step 4 as written takes a single M4 run. Take **three**, exactly as
Step 1 takes three of the narrowed arm, and record all three plus their median.

**3. Criterion 3 is therefore `median(M4 p95) / median(narrowed p95)`, gate
≥ 2.4.** M4 dies on it for the reason the plan gives, restated for this
arrangement: under M4 the shipped code *is* the baseline, so the ratio it would
report against itself is ≈ 1.0, far below the gate. Say that in the note in
those terms.

**4. Criterion 3b is measurable after all.** Earlier in this plan it was going
to be recorded as NOT MEASURED because of Low Power Mode. It is off now, so
record the narrowed arm's absolute `tile pan` p95 figures against the 16.67 ms
budget and state plainly whether the plan lands under it — the spike's median
was 16.66 with one run at 17.40, and this is the number the spec deliberately
declined to gate. Do not smooth a near miss into a pass.

**5. Check `pmset -g | grep -i lowpower` yourself before your first run**, and
again after your last. It must read `0` both times. If it reads `1`, stop and
report BLOCKED — every timing in this task would be contaminated.

**6. Ignore the brief's `git add` line for `STATUS.md`.** Task 8 owns that file
and carries the G3-to-3i renumbering that Task 1 never got to make. Stage only
the results note.

---

## Controller amendment 2 — what the first attempt learned

Task 7 was attempted once and blocked. Nothing was committed and no code was
mutated, but the attempt cost hours and produced five lessons. Read them before
your first run; the report from that attempt is at `task-7-report.md` and you
may read it, but these are the parts that matter.

**1. Check `pmset` between runs, not only at the start and the end.** The first
attempt confirmed `0`, started measuring, and found `1` mid-task — the machine
had come off mains and macOS auto-enabled Low Power Mode at ~80% battery. It is
on AC power now. Check before every run, and if any check reads `1`, stop and
report BLOCKED with the runs already completed listed as usable or not.

**2. Never write a `pgrep -f` pattern that matches its own command line.** The
first attempt polled with `pgrep -qf "frame_timing_test.dart"` inside a
`while` loop, and the pattern matched the polling shell itself, so the loop
never exited and left runaway shells alive. Match on something the polling
command does not contain — for example `pgrep -qf "[f]rame_timing_test.dart"`,
where the bracket keeps the pattern from matching itself — and verify your loop
exits by testing it once against a process you know has finished.

**3. `RIG=pan` is available and was used.** The first attempt hit repeated
instability in R4a and R4b — one `DriverError: ... Service has disappeared`
(the flake the brief names), one harness-killed run, and two hangs at 0% CPU —
and switched to `--dart-define=RIG=pan`, the harness's own documented per-rig
mode, on the grounds that R2 alone produces every figure this task needs.
**You may use it, and if you do, say so in the note as well as the report** —
a figure taken under a different rig selection than the rows it will be
compared against is a comparability question, and the reader must be able to
see it. If the full run is stable for you, prefer it.

**4. One narrowed run from that attempt exists** at `/tmp/3h_narrowed_1.log`.
It was taken inside the confirmed-`0` window but it is n=1 and it scored
nothing. **Do not reuse it as one of your three.** Take your own three; the
whole point of the medians is that they come from one contiguous, verified
regime.

**5. Budget the wall clock.** Six runs at 500,000 entities plus two `PAN_STEP`
arms is a long sitting. Run them one at a time, blocking inside a single Bash
call for each, and write the log path into your report as you go rather than at
the end — so that a run lost late does not cost the ones already taken.
