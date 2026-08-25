### Task 8: Close the plan

**Files:**
- Create: `docs/superpowers/notes/plan-3h-mutation-log.md`
- Modify: `STATUS.md`
- Modify: `docs/superpowers/notes/2026-08-25-plan-3h-results.md`

- [ ] **Step 1: Write the mutation log**

Create `docs/superpowers/notes/plan-3h-mutation-log.md` with one section per mutant — M1, M2, M3, M4 — each carrying: the edit as a diff, **the layer it was fired in**, the verbatim output, and the ruling. Plan 3g's most expensive error was firing a mutant on device only while reasoning that the widget suite passed "by construction", so **every section states which suites were actually run under it.**

If M2 survived, its section records gap **H5** with the measured zeros, and says that D2's pad rests on `_bake`'s argument and F1's history rather than on a gate of this plan's own.

- [ ] **Step 2: Run every suite on the final tree**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && CI=true flutter test && CI=true flutter test --tags golden && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed .
```

**Run them; do not read them off an earlier report.** Record the counts. No pre-existing golden PNG may have been regenerated — `git status` must show no `.png` modified.

- [ ] **Step 3: Update `STATUS.md`**

Add a Plan 3h section carrying: the exit gate as *n* of the criteria table, criterion 3's ratio, criterion 3b's absolute figures against 16.67 ms stated as a near-miss rather than smoothed, the mutants and where each died, and gaps H1–H5. Update the suite-count table and the `Verified against` line to the final commit. Rewrite "Resume here" to lead with Plan 3h and name **3i (zoom, G3, level-of-detail geometry)** and **3j (the 192 MiB vertex buffer, whose figure sits on a doubling boundary with no headroom)** as what comes next.

- [ ] **Step 4: Commit**

```sh
git add -A docs/superpowers/notes STATUS.md
git status --porcelain    # analysis_options.yaml must not be staged
git commit -m "docs: Plan 3h closes -- the fallback walk, its instrument, and four mutants"
```

---

## Controller amendment — binding

**1. You also carry Task 1's `STATUS.md` renumbering**, which was never made:
Task 1 was blocked at its first step by Low Power Mode and produced no commit.
`STATUS.md` still tells every session that Plan 3g's G3 is Plan 3h's job. In
addition to this task's own Step 3, edit so that:
- the G3 line reads that **Plan 3g assigned G3 to 3h and it now belongs to
  Plan 3i**, with one clause saying why: the 2026-08-25 high-water measurement
  showed memory is not a consequence of the pan frame, so the pan frame could
  be finished without settling zoom;
- the vertex buffer is named as **Plan 3j**;
- Plan 3h is described as **the fallback walk and its instrument, nothing
  else**.

**2. The mutation log covers five mutants, not four.** A sixth section is not
needed, but **M5** is, and it was found by a reviewer rather than planned:

- **M5 — grow the walk instead of shrinking it.** Replace
  `Size(strip.width, strip.height)` with `viewport` in `paintFrame`'s fallback
  branch, leaving the translate, the camera offset and `_lastStrip` untouched.
  The mutant walks a superset of `uncovered`, so **every pixel stays correct** —
  `stray: 0, uncovered: 0, differing: 0` — and `debugLastStrip` still reports
  the strip. It was **green against the entire package** when first fired. It is
  killed by the triangle-count gate added in Task 5's fix round
  (`kTriangleBudgetRatio`), with `liveTri: 60, tiledTri: 70` against a bound of
  54. Record that the sweep catches *shrinking* the query and could not catch
  *growing* it, because the clip absorbs the excess — the same asymmetry the
  clip's own comment warns about, applied to the `Size` argument.

**3. M3's record is fuller than the plan claimed.** Under M3, criterion **2b**
also reddens (`differing: 417` against a bound of 60), not only criteria 2 and
2c. Record the fuller kill.

**4. M2 survived** and that is the plan's pre-committed second outcome. Its
section records gap **H5** with the measured zeros, and says that D2's pad rests
on `_bake`'s argument and F1's history rather than on a gate of this plan's own.

**5. Two deferred minors from Task 5's fix round belong in the gap list or the
note, your judgement which:**
- the triangle gate has 4 triangles of headroom at its tightest offset (50 of 54
  allowed, out of 60 live) — deterministic, not a flake, but brittle to any
  future edit of `fillingGrid` or `kFallbackOffsets`;
- `checkTriangleBudget` defaults to `false`, so a future third caller of
  `sweepFallbackAgreement` silently gets no gate.

**6. One deferred minor from Task 3:** the per-offset table in that task's
report was produced with a throwaway, unstaged debug file, and nothing in-tree
says how it was made.

---

## Controller amendment 2 — binding: this dispatch is Task 8a only

Task 7 is blocked: the device arm needs mains power and the machine is on
battery with Low Power Mode auto-enabled. **Do not attempt any `flutter drive`
run, and do not wait for one.** You are doing the half of Task 8 that no
machine state can contaminate.

**In scope for you:**

1. **The mutation log**, `docs/superpowers/notes/plan-3h-mutation-log.md`, with
   sections for **M1, M2, M3 and M5** — everything in amendment 1 above that
   concerns those four, including M3's fuller kill and M2's H5 record.
   Add an **M4 section that is a placeholder in name only**: state that M4 is a
   device mutant, that it is not yet fired, and that Task 8b fills it. Do not
   invent a result for it, and do not omit the section — a mutation log missing
   a named mutant reads as a mutant that was never planned.
2. **Task 1's `STATUS.md` renumbering** — amendment 1, item 1. That edit was
   never made; Task 1 was blocked at its first step and produced no commit.
3. **Step 2's full-suite verification**, run on the current tree. Run them; do
   not read the counts off an earlier report. Record the real counts.
4. Items 5 and 6 of amendment 1 — the three deferred minors — recorded wherever
   your judgement puts them.

**Out of scope, and Task 8b's:** the results note
(`docs/superpowers/notes/2026-08-25-plan-3h-results.md`) does not exist and you
do not create it; M4's actual firing; the Plan 3h exit-gate section in
`STATUS.md` that quotes criteria 3 and 3b; the `Verified against` line's final
commit. **Do not write a `STATUS.md` section claiming Plan 3h is closed** — it
is not, and a `STATUS.md` that says otherwise is the single most expensive
document error this project has recorded.

**Where the mutants' figures come from.** Every number below was produced by an
implementer and then independently reproduced by a reviewer, both of whose
transcripts are in this workspace. Read them rather than re-running anything:
`task-4-report.md` (M1), `task-5-report.md` (M2, M3, and under "Fix round 1",
M5). If a figure you need is not in those files, say so in your report rather
than inventing it.

Commit message for your commit — do not use the plan's Step 4 message, which
announces a close that has not happened:

```
docs: Plan 3h's mutation log, and G3 moves to 3i

Four of five mutants live in the widget suite and are recorded here: M1's
clamp, M2's surviving pad, M3's shrunk query, and M5, which a reviewer found
after the narrowing landed and which was green against the entire package
until Task 5's fix round gated the fallback's triangle count.

M4 is a device mutant and its section is empty on purpose.

STATUS.md still told every session that Plan 3g's G3 belongs to Plan 3h. The
2026-08-25 high-water measurement showed memory is not a consequence of the pan
frame, which is what licensed finishing the pan frame without settling zoom.
G3 is Plan 3i and the vertex buffer is Plan 3j.
```

---

## Controller amendment 3 — binding: this dispatch is Task 8b, the close-out

Task 8a landed the mutation log's four widget-suite mutants and `STATUS.md`'s
roadmap renumbering. Task 7 landed the device arm and the results note. You are
closing the plan.

**1. Fire M4 and write its section — and correct a claim the log currently
makes.** The mutation log's M4 placeholder, and the plan itself, say M4 has **no
unit witness**. **That is now false**, and saying so is the most valuable line
you will write. After the plan was written, a reviewer found mutant M5 — growing
the walk to the viewport — and Task 5's fix round added a triangle-count gate to
`test/tile_fallback_test.dart` to kill it. M4 also hands `_drawInto` the full
viewport, so the same gate catches it.

Fire it yourself rather than quoting: keep `canvas.clipRect(uncovered, ...)` and
`_lastStrip = strip;`, drop the `canvas.translate`, and pass `viewport` and
`quantised` to `_drawInto`. Copy `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
aside first, restore from the copy, **never `git checkout`**. Run the whole
package. Two independent runs have already produced `+371 ~1 -1` with exactly
one failure — `criterion 2 and 2c`, `liveTri: 60, tiledTri: 70` against a bound
of 54 — but record what **you** get.

M4's device figures are in the results note: the M4 arm's `tile pan` p95 is
{36.14, 37.59, 38.14}, median 37.59, against the narrowed median 15.99. State
the layer for each: killed in the widget suite **and** separated on device.

**2. `STATUS.md`'s Plan 3h section must lead with the miss, not bury it.**
Criterion 3, the headline, is **MISS at 2.35 against a gate of 2.4**, and
criterion 6 is **MISS** on run 1's `tile hold` p95 of 2.77 ms against 2.5 ms.
Anyone skimming `STATUS.md` must see that before they see anything that sounds
like success. Do not write a section that reads as a clean close.

Carry, in this order: the two misses; that the measurement **cannot settle**
criterion 3 either way at n=3 (pairwise ratios 1.82–2.84 straddling 2.4); that
the **2.4 gate was mis-derived** from a cross-session numerator, which is the
comparison the ratio existed to prevent; that the **mean** shows the effect is
real and large (≈16.6 ms per fallback frame, non-overlapping, low noise) and is
**evidence, not a gate**; then the five mutants and where each died; then gaps
H1–H5.

**3. Plan 3i inherits three things, and `STATUS.md` must name all three:**
- **G3, zoom and level-of-detail geometry** — already renumbered by Task 8a;
- **settling criterion 3**, by re-measuring at **n=7–9 interleaved rather than
  blocked**, which is the only arrangement that removes the thermal ordering
  bias that inflated this task's numerator;
- and note that **Plan 3j** owns the 192 MiB vertex buffer, whose figure sits on
  a doubling boundary with no headroom.

**4. Update the suite-count table and the `Verified against` line** to your
final commit. Task 8a measured 797 / 372+1 skip / 35 golden, but **run them
again on the final tree** — the plan requires it and two commits have landed
since.

**5. Do not touch the results note.** It is finished and was reviewed twice.

**6. M5 is a five-mutant plan's fifth mutant and it was found by a reviewer,
not planned.** `STATUS.md` should say so: it is the plan's own evidence that the
review loop caught something the design did not.
