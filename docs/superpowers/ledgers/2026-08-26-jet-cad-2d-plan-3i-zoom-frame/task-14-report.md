# Task 14 — the exit gate: report

**Status: complete.** Documentation and reconciliation only. **No production
code and no test code was changed** — `git status` before staging showed
exactly four modified files (`STATUS.md`, `ledgers/README.md`, the results
note, the mutation log) and one new directory (the archived ledger). Neither
`analysis_options.yaml` nor `macos/Runner.xcodeproj/project.pbxproj` was
touched; every stage was by named path.

---

## Suite counts — run, not read

All three run by me on this tree, `CI=true` prefixed, before any edit.

`packages/jet_cad_2d`:

```
00:02 +797: All tests passed!
Analyzing jet_cad_2d...
No issues found!
Formatted 113 files (0 changed) in 0.15 seconds.
```

`packages/jet_cad_2d_flutter`:

```
00:05 +413 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
Formatted 73 files (0 changed) in 0.10 seconds.
```

`apps/dev_harness_2d` (`flutter test --concurrency=1`):

```
00:13 +72: All tests passed!
Analyzing dev_harness_2d...
No issues found! (ran in 0.9s)
Formatted 14 files (0 changed) in 0.07 seconds.
```

**797 / 413 with 1 skip / 72 — exactly the expected counts.**

The golden suite (`flutter test --tags golden`) was **not** run; the gate names
three suites and that is not one of them. `STATUS.md`'s table now marks that
row as not re-run rather than carrying a stale claim.

---

## Step 1 — the mutation log

**The file was already complete. Every one of its thirty-six sections carries
a mutation, a procedure, a `**Result:**` verdict and a verbatim transcript.**
I audited all thirty-six programmatically for those four elements and found no
section missing any of them. **Nothing was synthesised**; no transcript was
added, edited or invented.

Two changes were made:

1. **A summary table was added at the top**, after the numbering-collision note
   and before the canvas-correction notes: every mutant, the layer the mutation
   was applied in (cache / rig / app), its verdict, and the gate of record.
   Every gate name in it was read out of the entry's own transcript and
   cross-checked against the test name in the shipped suite.
2. **`## M4` was retitled `## M4 — the wheel clause`**, because the
   numbering-collision note cites it as `§"M4 — the wheel clause"` and no such
   heading existed. The note is otherwise present and accurate; that was its
   one inaccuracy.

**The four specific checks:**

- **M8 is a declared survivor.** Its entry says so in its heading, opens
  "green by design", and states that **its death would have been the finding**
  — a death would mean the source rectangles are not integral. The summary
  table repeats that framing. It is nowhere written up as a gate's failure.
- **M11 is unreachable by pixels.** Its entry derives why: the origin cancels
  algebraically in `float64` in `DraftPainter._emitScreenSpace` before
  anything reaches `float32`, ~1e-13 device px against the 1.1e-05 Task 6a
  measured as the pixel-flip threshold. Its gate of record is `tile_band_test.dart`
  — `every band is rebased against the origin handed in`, and the differential
  arms are green **by arithmetic, not by omission**. The table says so.
- **M24 survived and provably must.** Its entry carries the four-clause
  derivation (the rest bake's up-front pricing `bandBytes + visibleTiles * t
  <= cacheBytes` bounds demand below the stale supply, and the victim policy is
  oldest-first), the fix-wave caveat on clause 4 found at final review, and
  both byte-identical probe transcripts. The table carries the one-line
  version.
- **The per-plan numbering note is present and accurate.** It names Plan 3h's
  `M4` and `M5` against this file's, and points at `debugFullViewportQuery`'s
  doc comment and this file's `M14` as the places that spell out "Plan 3h's
  M4".

**Counts.** Thirty-nine mutations across thirty-six entries (M19a/b and
M19c/d/e are multi-mutation entries). **Thirty-seven died, two survive.** Of
the spec's own eleven (M1–M11), **ten died and M8 is the declared survivor** —
the exit gate's clause 2 met exactly. The other twenty-eight came from
reviewers, the eight fix waves and the whole-branch review; M24 is among them.

---

## Step 2 — the eleven-criterion exit gate

Written into `docs/superpowers/notes/2026-08-26-plan-3i-results.md`.

**9 pass, 2 miss. The misses are criteria 8 and 9, and they are named in the
first paragraph**, which now opens "Nine of the eleven criteria pass. Two miss
— criterion 8 and criterion 9 — and both are named here rather than at the
end." **No threshold was adjusted and neither miss was softened.** Criteria 1,
2, 3, 4, 8 and 9 were already scored with their device data and are referenced,
not re-scored or restated at length.

**Criteria 5, 6, 7, 10 and 11 were confirmed, not asserted** — each from the
gating test in the shipped suite and the mutant in the log that reddens it:

| # | Verdict | Gate |
|---|---|---|
| 5 | PASS | `tile_slice_differential_test.dart` — `a settled generation is identical to a live frame`, `and at a camera on a power-of-two rebase boundary`; `tile_cache_test.dart` — `criterion 1: a settled frame equals the live frame after a zoom`. Reddened by M3, M9, M9b |
| 6 | PASS | `tile_slice_differential_test.dart` — `tile boundaries carry no difference of their own`. Reddened by M9 and M9b, each of which takes all five differential arms |
| 7 | PASS | `invariants/tile_bytes_test.dart` — `the ceiling holds at every point inside the rest frame` (M6 on `debugImagesAlive`, M6b on the lower bound) and `the ceiling binds inside the rest frame, and eviction holds it` (M21); `a live band image is counted in liveBytes` pins the instrument extension |
| 10 | PASS | `tile_invalidation_test.dart` — `an edit after a sliced settle condemns the sliced tiles`. Reddened by M5 |
| 11 | PASS | `tile_slice_differential_test.dart` — `and stays identical after a pan smaller than one tile`, `and when a pan lands between the scale change and the bake`. Reddened by M7 (both arms) and M10 (the second) |

A full eleven-row tally table was added, plus the plan's other exit-gate
clauses:

- **Clause 2 (mutants)** — as above.
- **Clause 3 (the five anti-degenerate clauses)** — each confirmed with the
  assertion or the measurement that proves it. Clause 2 of that rule
  ("entities larger than one tile") is confirmed from **this plan's own device
  logs**, not from Plan 3g's: `overdraw=4.525 areaFactor=1.563` at 500,000 and
  `overdraw=3.687 areaFactor=1.563` at 50,000, the residue above the area
  factor being crossing multiplicity. Clauses 1, 3 and 5 come from
  `zoom_script_test.dart`; clause 4 from the per-corpus tables already in the
  note.

---

## Step 3 — `STATUS.md`

- **"Plan 3i — in flight, 12 of 14 plus two code halves"** is now
  **"Plan 3i — done, 14 of 14, exit gate 9 of 11"**, with the two misses and
  their numbers at the head of the section. Every anchor reference in the file
  was updated to the new heading.
- **The LOD correction stands and was strengthened.** The section head now
  says the spec **declined** LOD in as many words, and adds that any older text
  in the file describing 3i as *delivering* it is wrong. The stale roadmap item
  ("Plan 3i — zoom, G3, and level-of-detail geometry") is struck through
  rather than deleted, with the reason for keeping it, and its two carried
  items are discharged in place.
- **G3 is on the open-gap list** with the spec's own condition attached: *it
  becomes necessary the day the target changes to correct geometry while the
  fingers are still moving.*
- **The gaps this plan accepted** were added from spec §8: the zoom-out
  background ring, an edit landing mid-gesture, and the resting frame's ungated
  duration (D5's peak is gated, its length is not).
- **The new gaps this session produced** were added: criterion 9's regression
  measured but not diagnosed; the spec's §5 memory pricing at 3200x2400
  untested because the window cannot be made that large (Ruling 20); and the
  naked-eye seam check (gap G1) still owed by a human.
- **Rulings 17, 20 and 21 were added** beside the existing 14 and 15, with the
  header changed from "Two rulings" to "Five of the ledger's twenty-one
  rulings", pointing at the archived `progress.md` for the other sixteen.
  17 because a reader would otherwise read the shipped fall-through condition
  as drift from the brief; 20 because every figure in the results note is
  qualified by it; 21 because a discarded device run is otherwise invisible.
  The remaining sixteen were left in the ledger — `STATUS.md` is a resume
  document, not a second ledger.
- **"Verified against"** is now `dbc31e8`, with `7aef7f9` named as the last
  *code* commit and everything after it identified as documentation.
- **Suite counts** were replaced with the three I ran. The golden row is marked
  **not re-run** rather than carried forward as if it had been.
- **The ledger chore** paragraph now says none is outstanding and points at the
  archive, repeating the ordering lesson.
- The **"Measured, and left for Plan 3i"** section got a one-paragraph header
  saying both items are answered and which of the two rival options 3i chose,
  so the questions there are not mistaken for conclusions.

---

## Step 4 — the archive

`.superpowers/sdd/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/` was copied
**verbatim** to `docs/superpowers/ledgers/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/`
and verified with `diff -rq` — no differing files.

The eight `KEEP_*.log` measurement transcripts were copied to
`measurement-logs/` inside it, **including `KEEP_c8_DEGENERATE_run.log`**, the
run taken, read and discarded under Ruling 21 that the results note names
deliberately.

A row was added to `docs/superpowers/ledgers/README.md` matching the three
rows already there, and a `README.md` was written inside the archive in the
style of Plan 3d's and Plan 3h's, marking `measurement-logs/` as the one thing
in the directory that is **not** part of the original ledger.

**The archive was committed before anything else was staged.** The original
git-ignored directory was **not** deleted — the controller does that after
verifying.

---

## Concerns

1. **Criterion 9's regression is real, undiagnosed, and shipped.** The counters
   are byte-identical to Plan 3h's, so the same work now costs 1.35x more per
   expensive pan frame. Two candidates are named in the results note; neither is
   ruled in or out, and one of them (`_lastChangeWasPan`) is a deliberate
   correctness fix that a future plan may not simply revert. This is the single
   most valuable open thread the plan leaves.
2. **Nothing in this repository has ever been measured at the viewport the spec
   prices.** Ruling 20's finding — that the harness never set its window and
   every figure it has ever produced was taken at the nib default — means Plan
   3g's and Plan 3h's published memory figures are also at 800x600, not at any
   size a spec priced. That is broader than Plan 3i and I did not chase it; it
   deserves a look before a plan reasons from those numbers again.
3. **`docs/superpowers/ledgers/README.md`'s table is incomplete and was already
   so.** Archived directories exist for Plans 3e, 3f, 3f.1 and 3g with **no
   row** in the table; only 3c, 3d and 3h had rows before mine. I added 3i's
   row as instructed and did **not** backfill the four missing ones — out of
   scope, and each needs its own plan's record read properly rather than
   guessed at.
4. **The golden suite was not run.** The gate names three suites. No change
   here can move a golden, but the previous `STATUS.md` carried a "35 pass"
   figure that would now be stale by three days if left unqualified, so I
   marked it rather than re-ran it.
5. **`bakeCount` still mixes units** (per band on the rest path, per tile on
   the budgeted path). `STATUS.md` already records this; it is a live trap for
   anyone comparing 3i's transcripts against 3g's or 3h's, and it is a code
   concern I am reporting rather than fixing.

---

## Commits

- **`5c886a2`** — `docs: archive Plan 3i's ledger before the workspace is
  cleared`. 70 files: the whole ledger verbatim, plus `measurement-logs/` with
  the eight `KEEP_*.log` transcripts and a scoped `.gitignore` negating the
  root's `*.log` rule (without it the evidence would have been silently
  dropped from the commit), plus the `ledgers/README.md` row.
- **`198e7db`** — `docs: Plan 3i's record -- criteria, mutants, and STATUS
  reconciled`. `STATUS.md`, the results note, the mutation log.
- **The commit immediately after `198e7db`** adds this report to the
  archive. Its own SHA is deliberately not written here: a self-referential
  SHA is falsified by the amend that would write it.

The archive commit landed **first**, before `STATUS.md` or either note was
staged.
