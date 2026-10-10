# Task 3 review: docs, results and the record (391d9671..a39a2906)

Method: read the diff once, then checked the results note line by line against task-1-report.md, task-2-report.md and progress.md. Three spot greps in the plan and spec (standing-failures claim, M-3's spec row, `paramsOf`). No tests or git commands run.

### Spec Compliance

- ✅ CHANGELOG, Unreleased: both bullets are verbatim from the brief (diff lines 30-41 against brief lines 12-23, compared word by word and by line wrap). "Nothing yet." is replaced.
- ✅ Results note records the spec and plan, the commits per task, the gate summaries, M-1 to M-17 with killer and red line, the re-pinned tests, F-14 / Slice 2 note / O-8 discharged, the 587-589 overstatement (spec F-8), and O-1 to O-7 unchanged.
- ✅ Provenance, mutant table: every killer set and red line matches the reports.
  - M-1..M-16 killers and red lines match task-1-report.md. This includes M-5 (N-2, N-5, not N-6) and M-12 (PG1 only, "P-2 not claimed").
  - M-17 matches task-2-report.md.
  - The floor-plan kills for M-1, M-2 and M-15 match task-2-report.md. TD7, TD7b, TD7c, TD8, P-1, P-2, P-3 and HD12 are listed exactly as there, with the `+6 -1` / `+19 -8` / `+7 -1` / `+22 -5` counts, and "TD7 (B last) correctly stays green" for M-15.
- ✅ Provenance, gates: Task 1 (2d, 2d_flutter, gpu, symbols, floor_planner, restaurant_demo, floor_plan, S-1, fix round 1) and Task 2 (floor_plan `+1915`, analyze, format 281, floor_planner, restaurant_demo, P-1..P-3 `+3`, TD10 `+12`) match the reports exactly, including times, counts and "(0 changed)" figures. I found no invented number.
- ✅ Rulings from progress.md:
  - M-5 killers N-2 and N-5.
  - The N-4 seed order (21 against 22).
  - P-1..P-3 compare `canon`, with the reviewer's `[20,21,22]` vs `[21,20,22]` probe.
  - P-2 not a killer of M-12.
  - TD10's stamp order A before B (from the Task 2 report).
- ✅ "Left for the final review": all nine deferred "minor (deferred)" lines of progress.md are present. The two fixture-breadth lines are merged into one bullet with both halves kept. File:line references match.
- ✅ Spec status line: "implemented on `fix/node-components-on-delete`, not yet merged", with the results note linked. The revision-3 approval wording is kept.
- ✅ STATUS: names the plan, the branch, the results note and the spec. Says "not merged" and "Nothing is pushed". Next step is the whole-branch review, then the human's look, then the merge on the human's word, with the ledger archived onto the branch as its last commit. This covers the brief's required next step. The "plan written, not started" text is gone, and no other STATUS line still says it (grep).
- ✅ No `analysis_options.yaml` in the diff. Four files, as the report says.
- ⚠️ The "Standing failures ... measured at `e281372`" claim and the "CI on Linux compares its own lists" claim are not in the task reports. They come from the plan's Global constraints (plan lines 89-94) and are stated there as measured. Sourced, but by the plan, not by a run in these tasks.
- ⚠️ "The two allocation invariants and every image golden are untouched" is the plan's constraint (plan lines 37-39), not a measured result in either report. It is plausible from the file lists, and I could not confirm it from the reports.
- ⚠️ "D-8 ... `ParametricView.paramsOf`" appears in the spec (line 376) but neither report lists `paramsOf` among the doc edits (Task 1 says "docs only at the three places" and names `objectsOf`, `dissolves`, `_plan`, `_written`, `_run`). The note's D-8 list is therefore partly spec-derived, not report-derived.

### Strengths

- The note keeps the "nothing was re-run for this note" statement up front and then sticks to it. Each red line is quoted from the report, `[E]` markers and counts included. It does not smooth over the M-3 gap (TD7 was never run as a killer) or the missing red run before implementation.
- The rulings are placed where a reader meets the claim, each with its reason (the `canon` probe values, the 21/22 seed count). The "byte for byte" reading is corrected rather than silently reinterpreted.
- Gates are labelled with the commit they were run at (`90044db4`, `d082640e`, `391d9671`). The note does not claim a single tip-wide run, and the report flags that as a concern.
- The discharge section separates what the old host-spec sentence overstated (walls and rooms already cleaned by 06 D8) from what really orphaned.
- STATUS is accurate about merge and push state, and the deferred minors are handed to the final review as the brief asked.

### Issues

Critical: none. Every recorded result has a source.

Important: none.

Minor

1. `docs/superpowers/notes/2026-10-10-node-components-results.md`, "Left for the final review" lead-in: "none changes behaviour; no named mutant survives any of them". The third bullet (cross-document snapshot) describes a path where `restore` throws a `TypeError` after `addNode` has written, breaking I-3. It is a latent edge, not a change of behaviour, but "none changes behaviour" sits badly next to it. "No named mutant survives any of them" is also asserted by the note and the ledger without a run behind it. Fix: reword to "none changes behaviour the tests pin" or drop the second clause.
2. Same note, "Mutations", M-3 row, and the "Notes from the reports" bullet: the note's table says "Killed by N-2, N-5, N-6" and the bullet says "Recorded as run". Correct and honest. For consistency with the spec's "TD7 (review run)" it could add "TD7 not run", which would save the final reviewer a lookup. Optional.
3. Same note, "What changed", D-8 bullet: lists `paramsOf` and `restore`, which only the spec (not the reports) places in D-8's edit set; the label "D-8" also covers `_deleteByHost`, which is a Task 2 edit. Mildly blurs which task did what. Fix: add "(Task 1)" / "(Task 2)" or cut `paramsOf` unless the diff of `90044db4` shows it.
4. Same note, "The tests re-pinned" paragraph: "Task 2 rewrote TD10 ... reworded the titles of TD7, TD9 and the group". The ledger and report agree. The note then says "Both lists are the global constraint's named exceptions", which is not checkable from the reports. Low risk.
5. Same note, Gates: the "Some tests failed" paragraph has a long unwrapped line ("fingerprints and `jet_cad_2d_flutter`'s five text-ladder goldens. CI on Linux ..."). Cosmetic.
6. STATUS In-flight entry: the condensed spec history drops two facts the old entry carried (Copilot could not review for quota; the O-10 rationale for checking before `addNode`). Both are recorded in the spec, so nothing is lost, but the STATUS entry no longer mentions the Copilot gap. Optional.

### Assessment

**Task quality:** Approved

**Reasoning:** The CHANGELOG text is verbatim from the brief. Every mutant row, red line and gate line in the results note matches task-1-report.md and task-2-report.md, and the ledger rulings and all deferred minors are carried. STATUS and the spec status line are accurate and claim nothing merged or pushed. The remaining issues are minor wording and attribution.
