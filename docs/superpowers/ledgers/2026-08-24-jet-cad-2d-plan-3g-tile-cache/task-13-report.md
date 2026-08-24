# Task 13 report (documentation half)

Two files written, no source touched:

- `docs/superpowers/notes/plan-3g-mutation-log.md`
- `docs/superpowers/notes/2026-08-24-plan-3g-results.md`

`STATUS.md` was **not** modified, per the dispatch — the controller owns it once
criteria 10 and 11 land.

## Mutants found, and where

**Forty-one named. Thirty-nine fired.**

| source | mutants |
|---|---|
| spec table | M1–M19 (M18, M19 added by execution in Task 9a) |
| task 1 | M17, firing 1 (the painter's `debugRebaseOrigin ??` override) |
| task 3 | M10 ("mutant 1" in the report), plus an unlabelled `_floorDiv → ~/` — **named M-A here** |
| task 6 | M14, M11 |
| task 6a | destRectFor one-pixel error — **M-M**; alpha on the blit paint — **M-N** |
| task 6 fix 1 | M-N fired again at criterion 4; `style_resolver` transparency dropped — **M-P** |
| task 7 | M1, M2, M5, M12 (compile error), M12b, M16 |
| task 7 fix 1 | the report's "G1/G2/G3" — **renamed M-J, M-K, M-L** |
| task 8 | M8, M8b, M8c, M8d |
| task 9 | M4, M9; the composite call-site `Paint` — **renamed M-Q** |
| task 9a | M18, M19 |
| task 10 | M6, M-B, M-C, M-D, M-E, M-F, M-G, M-H |
| task 11a fix 1 | the truncating bake budget — **named M-R** |

Task 10's report also has sections headed "M3" and "M4" — those are **review
finding IDs**, not mutants, and are not counted.

## Unfired, each with its own section

- **M3** — recorded as **NOT FIRED**: `flutter_test`'s software Skia
  antialiases no `drawVertices`, so the instrument cannot produce the artefact.
  Not counted toward coverage.
- **M7** — recorded as **NOT FIRED**: only criteria 10 and 11 can see it and
  Task 12 is blocked. So the plan currently has no evidence that per-tile
  clipping does the work its design claims. Stated in both notes.
- **M17** — recorded as **not killed by criterion 1**, with the algebraic
  cancellation written out and the wiring test named as the actual gate.
- **M16 and M-J** — recorded as independent in both directions, with the
  mechanism for each, and both marked required.

## Missing transcripts, stated rather than reconstructed

- **M-R** (Task 11a I1). The report says both new tests "were run against the
  pre-fix getter and failed (confirmed live, not asserted)" but gives no
  transcript. Recorded as a gap in the record.
- **M1, M5, M12b, M16, M18, M19, M-J, M-K, M-L** have red transcripts but no
  *separate* restored-green transcript — the reports record `RESTORE CLEAN` /
  `diff` empty and the task's own exit gate instead. Noted in each section
  rather than papered over.
- **M19**'s report gives the failing-test list rather than per-assertion output.
  Reproduced unedited.

## Contradictions found in the reports

1. **`M18` is used for two different mutants.** Task 9's fix round labels the
   call-site-local composite `Paint` mutant "M18"; Task 9a and the spec use M18
   for `kTileSlack = 0.0`. Resolved by keeping the spec's M18 and renaming Task
   9's to **M-Q**, with the collision stated in the log.
2. **Task 7's fix round labels three gating mutants `G1`, `G2`, `G3`**, which
   collide with the spec's accepted gaps G1–G6. Renamed **M-J, M-K, M-L**, with
   the collision stated.
3. **Task 6's F3 finding vs. Task 6a's report.** A committed comment claimed the
   `destRectFor` mutant reddens "at roughly two hundred times the bound"; 6a's
   own transcript is 3192 against 60 — **53×**. Already corrected in the tree
   during Task 6's fix round; the log carries the true figure only.
4. **Task 9's "seven lines at 81–83 columns"** was a byte-counting artifact; in
   codepoints no line exceeds 80. Corrected in the ledger, not repeated here.
5. **The plan's self-review says "Sixteen fired, one recorded as unfirable."**
   That is stale: execution added M18 and M19 to the spec, minted twenty-two
   more locally, and left **two** unfired (M3 and M7), because Task 12 is
   blocked. The notes carry the true count.

Also recorded, since it bears on how much the sweep transcripts prove: **Task
11's control transcript cannot be reproduced from any commit** (it prints
`tiles=off` with no `mean=`; both landed together in `96cdd56`). It is a real
run from a mid-development snapshot, and the sweep transcripts from section 4
onward are reproducible against `96cdd56`. Stated in the results note.

## Verification, not assumption

Ran at `37918c5` before writing:

```
packages/jet_cad_2d          797 tests, All tests passed! / analyze clean / format 113 files (0 changed)
packages/jet_cad_2d_flutter  363 tests + 1 skip, All tests passed! / analyze clean / format 63 files (0 changed)
packages/jet_cad_2d_flutter  35 golden tests, All tests passed!
git diff --stat 37918c5 -- packages/jet_cad_2d_flutter/test/golden   (empty)
```

Machine state read for the results note: `lowpowermode 1`, Battery Power.
Criteria 10 and 11 are PENDING and **no number was written for either**.

## Concerns

1. **M7 unfired is the real hole in this plan's coverage**, and it is larger
   than M3's. M3 is a sub-pixel antialiasing question; M7 is "does per-tile
   clipping happen at all", and every correctness criterion passes without it.
   Task 12 must fire it, not only read two timings.
2. The vertex-buffer measurement 3h inherits (`debugCapacityVertices`, tiles on
   against off at 500,000) also needs a device and shares Task 12's blocker. It
   is recorded as owed, not as measured.
3. Three separate label collisions in one plan (M18 twice, G1–G3 twice) suggest
   task briefs should carry the mutant and gap namespaces explicitly.


---

# Amendment, after Task 12 ran

Both notes updated in a second commit. Nothing else changed; suites re-verified
green (797 / 363+1 skip / 35 golden), tree otherwise clean.

**Criterion 10 — PASS**, 1.58 ms median p50 (p95 1.96) against ≤ 4.00, **26×**
the same runs' untiled 41.09 ms. Control reproduced at build 7.26 / raster 8.56,
`lowpowermode 0` on AC before all six runs.

**Criterion 11 — MISS**, 35.67 ms median p95 against 16.67, 2.1× over, max
median 65.77. **Threshold not moved, miss not softened.** The note carries the
cause: the bake walk is 5.7–6.4 ms per tile and the ~32 ms of excess is the
**live fallback** drawing the uncovered strip (`liveDraws=10`, live walk
31.5–41.6 ms). The spec's prescribed remedy is spent — the budget is already
floored at one tile, and lowering it further leaves the strip uncovered for more
frames. Handed to Plan 3h as a design question.

**M7 — fired, killed nothing.** The mutation log's M7 section is rewritten from
NOT FIRED to fired-with-no-transition, with both verbatim device transcripts, the
diff, the restore proof and run A's backgrounding deviation. Criterion 10 is
structurally blind (`bakeFrames=0/60` — the clip never executes in the frame it
measures); criterion 11 was already red, so **no green-to-red transition exists
anywhere.** Recorded as accepted gap **G7** in the results note, quoting the
spec's own sentence against itself, with what is owed: a **bake-time assertion**
that a tile's geometry is bounded by its own rect — the command-time-assertion
shape trap 5 recommends — not a third timing.

**Count is now 41 named, 40 fired, 39 killing something.** M3 remains the only
unfired mutant.

**Twelfth disguise added** to the taxonomy: *an instrument that reimplements what
it measures* — `_probeBake` reports `overdraw=4.185` bit-identically under M7, a
mutation that moved real triangles by 61%, because it reimplements the bake
geometry instead of calling `_bake`. Distinguished from disguise 1 (visible in
one line) and disguise 3 (fails loudly): a reimplementation answers confidently
and wrongly. A seventh question added to match — *does this instrument observe
the shipped path, or a copy of it?*

**Settle recorded as inference, not measurement**, per instruction: 11 frames
five-for-five, ~30–40 ms each, ~350–450 ms per zoom, with its three supports and
the explicit note that the rig cannot time warm frames.

**Concerns after the amendment.**

1. **`_probeBake`'s blindness contaminates a decision, not just a column.** The
   overdraw column is part of what chose `kTileDevicePixels = 512`. The choice
   still looks right on the other two columns, but the overdraw figures describe
   the specification rather than the shipped bake, and nothing has re-derived
   them from `_bake` itself.
2. **Criterion 10 now passes and gates nothing.** It is the plan's headline
   number and no mutant can redden it. Worth stating in `STATUS.md` beside the
   26×, so the figure is not read as a gate.
3. The vertex-buffer reading 3h inherits (`debugCapacityVertices`, tiles on vs
   off at 500,000) was not in Task 12's brief and is still owed.
