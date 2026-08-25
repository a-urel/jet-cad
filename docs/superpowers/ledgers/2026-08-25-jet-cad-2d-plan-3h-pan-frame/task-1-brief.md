### Task 1: The baseline, and the map the next session reads

**Files:**
- Modify: `STATUS.md`
- Create: `docs/superpowers/notes/2026-08-25-plan-3h-results.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the three baseline `tile pan` p95 figures Task 7's criterion 3 divides by.

**Why this is first.** Criterion 3 is a ratio of baseline to narrowed on **one machine**. Quoting the spike's 43.13 ms across machines and days would make it a cross-session comparison, which is the weakness the ratio exists to avoid. And `STATUS.md` still tells every session that Plan 3g's G3 is this plan's job; `CLAUDE.md` instructs every session to read `STATUS.md` first, so a stale line there outlives any note.

- [ ] **Step 1: Confirm Low Power Mode is off**

```sh
pmset -g | grep -i lowpower
```

Expected: `lowpowermode         0`. If it reads `1`, stop and tell the controller — every timing in this plan would be contaminated and `STATUS.md` records a uniform ~24% skew from it.

- [ ] **Step 2: Record the baseline, three runs**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d
for i in 1 2 3; do
  caffeinate -dimsu flutter drive --profile -d macos \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart \
    --dart-define=ENTITIES=500000 --dart-define=TILES=on \
    > /tmp/3h_baseline_$i.log 2>&1
  echo "run$i exit=$?"
done
grep -A4 "tile pan" /tmp/3h_baseline_*.log | grep "total "
```

`caffeinate` is not optional: a run that sleeps mid-phase hangs at 0% CPU and its `pumpFrame` never returns.

Expected: three `total  p50=... p95=...` lines. The spike measured p95 ≈ 43.13 ms; anything within a factor of two of that is a usable baseline. If a run reports `DriverError: ... Service has disappeared`, discard it and re-run — R4b at 500,000 entities sits on the driver's timeout and loses a run occasionally.

- [ ] **Step 3: Write the results note's baseline section**

Create `docs/superpowers/notes/2026-08-25-plan-3h-results.md`:

```markdown
# Plan 3h results

**Spec:** [2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md](../specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md)

## Baseline, recorded before any change

Machine: macOS, `flutter drive --profile -d macos`, Low Power Mode `0`.
Commit: <the SHA this task started from>.

| run | `tile pan` p95 |
|---|---|
| 1 | <ms> |
| 2 | <ms> |
| 3 | <ms> |

Median: **<ms>**. Criterion 3 divides this by the narrowed arm's median.
```

Replace every `<...>` with a measured figure. **Do not copy the spike's numbers** — the point of this task is that these came off this machine.

- [ ] **Step 4: Renumber the roadmap in `STATUS.md`**

`STATUS.md` currently carries, inside the Plan 3g block, a line assigning G3 to this plan, and a "Resume here" item 3 about the vertex buffer. Find them:

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
grep -n "It is Plan 3h\|G3" STATUS.md
```

Edit so that:
- the G3 line reads that **Plan 3g assigned G3 to 3h and it now belongs to Plan 3i**, with one clause saying why: the 2026-08-25 high-water measurement showed memory is not a consequence of the pan frame, so the pan frame can be finished without settling zoom;
- the vertex buffer is named as **Plan 3j**;
- Plan 3h is described as **the fallback walk and its instrument, nothing else**.

Do not restructure the file. Three edits, each a sentence or two.

- [ ] **Step 5: Verify nothing else changed**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad && git status --porcelain
```

Expected: exactly `M STATUS.md` and `?? docs/superpowers/notes/2026-08-25-plan-3h-results.md`. **If `analysis_options.yaml` appears, do not stage it.**

- [ ] **Step 6: Commit**

```sh
git add STATUS.md docs/superpowers/notes/2026-08-25-plan-3h-results.md
git commit -m "docs: Plan 3h's baseline, and G3 moves to 3i

Criterion 3 is a ratio on one machine, so the baseline is measured here
rather than quoted from the spike across machines and days.

STATUS.md still told every session that Plan 3g's G3 belongs to this plan.
The 2026-08-25 high-water measurement showed memory is not a consequence of
the pan frame, which is what licenses finishing the pan frame without zoom.
G3 is Plan 3i and the vertex buffer is Plan 3j."
```

---

