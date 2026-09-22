# Task 12 report — gates, results note, spec amendments, STATUS, roadmap

BASE `563fdd4`. **DONE at `1618111`** — one commit, 5 files, 745
insertions, 4 deletions; trailer check `git log -1 --format=%B | grep -c
"Fable 5.1"` → `1`; `git status --short` empty after. Docs only; no code
touched. The mutation log, the plan and the spec review note are unchanged.

## Step 1 — the four gate lines

All four run from their own directory on the tree at `563fdd4`, `CI=true`
on every test command.

| package | summary line | exit |
|---|---|---|
| `packages/jet_cad_2d` | `00:05 +860: All tests passed!` | 0 |
| `packages/jet_cad_2d_flutter` | `00:29 +795 ~1 -5: Some tests failed.` | 1 |
| `apps/dev_harness_2d` | `00:29 +82: All tests passed!` | 0 |
| `apps/floor_planner` | `00:02 +21: All tests passed!` | 0 |

The render layer's exit 1 is exactly the five pre-existing golden failures
and nothing else: `text_ladder_golden_test.dart: text ladder rung 1..5
(RenderBackend.canvas)`. 795 pass, 1 pre-existing skip.

Analyze, all four: `No issues found!`, exit 0 (`Analyzing jet_cad_2d...`;
`Analyzing jet_cad_2d_flutter... (ran in 3.0s)`; `Analyzing
dev_harness_2d... (ran in 3.2s)`; `Analyzing floor_planner... (ran in
1.3s)`).

Format, all four, exit 0: `Formatted 125 files (0 changed) in 0.39
seconds.` / `Formatted 148 files (0 changed) in 0.33 seconds.` / `Formatted
22 files (0 changed) in 0.07 seconds.` / `Formatted 7 files (0 changed) in
0.04 seconds.`

Builds, both exit 0:
`✓ Built build/macos/Build/Products/Release/floor_planner.app (51.0MB)` and
`✓ Built build/web`.

`git status --short` was empty before Step 1 and showed only this task's own
doc files afterwards. **No `analysis_options.yaml` was rewritten at any
point**, so none needed `git checkout --`.

Counts match the expectation in the brief: engine 860, render 795 + 1 skip +
the five goldens, harness 82, app 21, both builds.

## Files written

- `docs/superpowers/notes/2026-09-22-plan-04-results.md` — new. Gate lines
  pasted with exit codes; the Plan 01 golden baseline re-recorded; mutation
  summary (23 fired, 23 killed, 0 survived, 0 equivalent; M-04q's first
  attempt not counted, Ruling 04-18); the differential (seed `0x5EED0004`,
  50 trials, 1..12 majors, Ruling 04-13 and why the spec's version was
  vacuous); the exit gate, one row per criterion 1–16 with its witness, 15
  PASS and criterion 16 **OWED — not looked at; the human looks after this
  branch is presented**; the look itemised as eight items per platform for
  macOS / Chrome / Firefox with seen / not seen / could not judge boxes; the
  four things to know before looking (`header.units` non-goal, adaptive snap
  follows the zoom unless `gridStepMm` is set, the first frame at the
  nominal fit, the differential's seed and trial count); debt from
  `deferred-minors.txt`, one sentence and a file each, plus the rulings; the
  spec-amendment list; the files-touched list.
- `docs/superpowers/specs/2026-09-22-page-grid-rulers-design.md` — seven
  paragraphs appended, each opening `**Amended at execution (Plan 04,
  2026-09-22):**`, at the end of D4 (04-16), D7 (04-7, 04-11, 04-12), D8
  (04-3, 04-14, 04-13), D10 (04-2), D11 (04-15 and `crossAxisAlignment:
  stretch`), D12 (04-1 and 04-16) and the Testing section's "Named mutants"
  subsection (M-04c, M-04g, M-04q / Ruling 04-18). Nothing original was
  rewritten.
- `STATUS.md` — a new `## Plan 04 — page, grid and rulers (executed on
  plan-04/page-grid-rulers, NOT merged)` section above the Plan 02 section,
  in Plan 02's shape (what it delivered; the twelve-task table with head
  SHAs; "What Plan 04 measured" with the gate lines; the exit gate at 15 of
  16 with the sixteenth OWED; five rulings a reader must know; the debt);
  the header's "Last updated" sentence rewritten to lead with Plan 04; a new
  Plan 04 paragraph in "Resume here" saying executed, not merged, criterion
  16 owed, merge is the human's decision.
- `roadmap/04-page-grid-rulers.md` — the `**Status:**` line.
- `roadmap/00-README.md` — the execution-status table row for 04.

## Could not verify / deviations

- **The sub-project table row for 04** (`roadmap/00-README.md` line ~190)
  was **not** changed. That table's columns are File / Depends on / Size —
  it carries no status field — and Plan 02's Task 12 left the equivalent 02
  row untouched, changing only the execution-status table. Flagging it in
  case the intent was otherwise.
- **Criterion 16 is not verified and is not claimed.** No app was launched,
  no screenshot taken, no visual judgement made.
- Two pre-existing staleness items in `roadmap/00-README.md` were left
  alone, as Plan 02 left them: the "**Last updated:** 2026-09-21" line and
  the sentence "**01 has a spec as of 2026-09-21**; the other twelve have
  not started."
- The `STATUS.md` "Resume here" link to the Plan 02 section still uses the
  pre-merge `...-executed-on-plan-02interaction-core-not-merged` anchor
  while that heading now reads "MERGED into `main` at `8c62db3`" — a
  pre-existing broken anchor, not introduced or touched here.
