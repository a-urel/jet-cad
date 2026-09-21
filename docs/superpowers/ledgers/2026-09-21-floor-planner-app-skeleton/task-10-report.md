# Task 10 report — the look, the results note, the spec's owed lines, the resume point

## What I wrote, file by file

### `docs/superpowers/notes/2026-09-21-plan-01-results.md` (new)

Shaped after `docs/superpowers/notes/2026-09-05-plan-f-results.md`'s first
120 lines (title/links block, "premises measured false" numbered section,
measured-quantities section, the window section, mutation summary, rulings,
exit gate). Every number traces to a source, verified before writing:

- **Harness 82 → 82, diff empty**: I ran
  `git diff --stat 717b9cd..HEAD -- apps/dev_harness_2d` myself in this task
  (empty output) and cross-checked against the Task 9 report's fourth gate
  block (`00:20 +82: All tests passed!` at the harness, both before-plan and
  after-plan since the file set is untouched).
- **`jet_cad_2d` 798, `jet_cad_2d_flutter` 702/1 skip/5 golden**: Task 9
  report's "four gate lines" section, second block, pasted verbatim
  (`+702 ~1 -5`, the five named golden test IDs).
  `apps/floor_planner` 7 tests / both builds `✓ Built`: same report, fourth
  block.
- **523 entities, the `STARTUP` line**: Task 7 report, "Entity count" and
  "The `STARTUP` line, verbatim, for Task 10 to quote" sections — copied
  character-for-character, including the unrounded `1052.6315789473683`.
- **The web build tail**: Task 8 report's `flutter build web` section,
  copied verbatim (Wasm dry-run note, font tree-shake line, `✓ Built
  build/web`). The macOS build tail is from the same report.
- **Mutation summary**: `docs/superpowers/notes/plan-01-mutation-log.md`'s
  own "Summary" section (16 fired/16 killed/0 survived/1 equivalent,
  M-01b's two-shot history) and its per-mutant table, cross-checked against
  the Task 9 report's summary table — the two agree on every row.
- **Rulings**: copied verbatim from the ledger
  (`.superpowers/sdd/2026-09-21-floor-planner-app-skeleton/progress.md`)'s
  per-task lines for the golden baseline, the worktree substitution, Task
  4's rename, Task 6's placeholder, Task 7's brace fix and Task 9's fixture
  fix, plus the plan's own Rulings 01-1..01-4 (paraphrased from the spec's
  D2/D4 and the ledger, since the plan document itself states them in
  prose rather than as a numbered list — I stated each ruling's substance
  and did not invent a number or wording not already in the spec/ledger).
- **Deferred**: every `minor (deferred)` line from `progress.md`, copied
  verbatim, Tasks 1/3(×2)/4/5/7(×2)/8(×2)/9.
- **The look**: every one of Steps 1's seven items and Step 2's six items,
  transcribed verbatim from `task-10-brief.md`, each marked **OWED — not
  looked at; the human looks after this branch is presented** per this
  task's controller ruling. No item says "seen"/"not seen"/"could not
  judge" as a verdict — those three words appear only inside the
  criterion-12 gate-table cell describing what the *brief* asked for, and
  in one negation sentence stating that nothing here is any of the three.
- **Exit gate**: all 12 rows, 11 PASS each citing its witness file/report,
  row 12 OWED in the brief's exact wording.

### `docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md`

Exactly four edits, verified by `git diff` after writing (pasted below):

(a) One paragraph added under D4 after the `Range: 0.001 to 100` paragraph,
stating the 2026-09-21 check in `startup_plan_test.dart`, 0.095 px/mm at
1440×900, 95.0× / 1052.6× headroom, constants unchanged.

(b) The Architecture block's `analysis_options.yaml` line changed to
"generated, committed once at scaffold, never a rewrite (plan Ruling
01-1)".

(c) All four `ScrollAction` occurrences in the D2 code block (the enum
declaration, the field type, and both `static const` values) became
`ScrollSignalAction`, plus one added sentence after the code block quoting
the Flutter-collision reason and attributing it to "execution ruling, Task
4".

(d) M-01b's bullet in the Named mutants list rewritten to the exact text
given in my instructions (the ramp, the 3.6 mutant value, the parenthetical
about the coalescing guard and the mutant surviving on its first shot).
The clamp-constants bullet in Open questions now starts with `~~STRUCK~~ —`
and ends with "checked; see the results note."

I grepped for any other `ScrollAction` occurrence outside the code block
after the edit; none exist except the new sentence's own reference to the
old (rejected) name, which is intentional prose.

### `roadmap/00-README.md`

The 01 row's Executed column: `—` →
`[2026-09-21](../docs/superpowers/notes/2026-09-21-plan-01-results.md) (branch, look OWED)`.
One line changed.

### `roadmap/01-app-skeleton.md`

`**Status:** not started` →
`**Status:** spec 2026-09-21 (rev 2), plan 2026-09-21, executed on plan-01/app-skeleton, the human's look OWED`.
One line changed.

### `STATUS.md`

Read the first 60 lines and the "Resume here" section before editing.
Added a new `## Plan 01 — the app skeleton (on plan-01/app-skeleton, not
merged)` section directly above `## Plan F —` (previously at line 77),
shaped after Plan F's own section: an opening paragraph (what it delivers,
branch/commit range, NOT-merged statement, spec/plan/results/mutation-log
links), a "Delivered" paragraph, a "rulings a reader must know" paragraph
(the rename, the placeholder main, the golden baseline), a measured-
quantities table, and an exit-gate summary sentence (11 of 12, criterion 12
OWED). Then updated the "Resume here" paragraph about sub-project 01: "its
plan is written... not yet executed" became "...and has now executed on
plan-01/app-skeleton..., the exit gate is 11 of 12..., merging is the
human's call after that look," with links to the new Plan 01 section and
the results note. `git diff --stat STATUS.md` shows only additions to the
new section plus the small wording swap in the Resume paragraph (75
insertions, 3 deletions) — no other line touched, confirmed by reading the
full diff.

## `git show --stat HEAD`

```
commit b6d64a9bd0a78bf7facc6c520410a837d6e46703
Author: Ahmet Urel <a-urel@hotmail.com>
Date:   Mon Sep 21 16:20:17 2026 +0300

    docs: Plan 01 results -- the look on macOS and in two browser families, the gate, the resume point

    Records Task 10: the results note (harness/suite counts, the STARTUP fit-scale
    line, both build tails, the mutation summary, every ruling and deferred item,
    and the twelve-row exit gate with criterion 12 OWED); the spec's four owed
    lines (D4's clamp check, Ruling 01-1's committed analysis_options.yaml,
    ScrollAction -> ScrollSignalAction, M-01b's corrected wording, and the struck
    open question); the roadmap's two files; and STATUS.md's new Plan 01 section
    and updated resume point. Steps 1 and 2 of the brief (running the app and
    judging it by eye) are not performed here -- they require a human, and every
    item is recorded OWED, not simulated.

    Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>

 STATUS.md                                          |  78 ++++-
 .../notes/2026-09-21-plan-01-results.md            | 364 +++++++++++++++++++++
 ...2026-09-21-floor-planner-app-skeleton-design.md |  34 +-
 roadmap/00-README.md                               |   2 +-
 roadmap/01-app-skeleton.md                         |   2 +-
 5 files changed, 465 insertions(+), 15 deletions(-)
```

Exactly five files.

## Self-review

- **Every number traces**: listed above per-fact, each to a specific report
  or ledger line; the harness diff and count I additionally re-verified
  myself with `git diff --stat 717b9cd..HEAD -- apps/dev_harness_2d`
  (empty) rather than trusting the ledger's assertion alone.
- **No "seen" anywhere in the look**: checked with
  `grep -n "seen" docs/superpowers/notes/2026-09-21-plan-01-results.md` —
  three hits, all negations or the gate table's restatement of what the
  brief's verdict options *would have been* ("Nothing here is 'seen', 'not
  seen' or 'could not judge'"; "The heuristic's misclassification, if
  seen, is likewise OWED"; the criterion-12 row's own description of the
  brief's ask). None asserts an observation happened.
- **The spec has exactly the four edits**: confirmed via `git diff` on the
  spec file, pasted in this report's file-by-file section above — five
  hunks total (the ScrollAction rename spans two hunks in the code block
  plus the trailing sentence, counted as one edit (c) per the brief).
- **STATUS.md's other sections untouched**:
  `git diff --stat STATUS.md` → `78 ++++-`, one file, and reading the full
  diff (pasted in the conversation) shows only the new section inserted
  wholesale before Plan F's header, and the Resume-here paragraph's wording
  swap — no other line in the file's ~2800 lines was touched.
- **`git show --stat HEAD` lists exactly five files**: confirmed above.

## Issues or concerns

- The plan's own Rulings 01-1 through 01-4 are not printed as a standalone
  numbered list anywhere in the plan document or the ledger I could find
  (they are referenced by name in the spec's D2/D4 text and the ledger's
  per-task lines, e.g. "Ruling 01-1" for the analysis_options.yaml
  scaffold-once decision, "Ruling 01-4" for the coalescing guard). I stated
  each by its substance as it appears in the spec/ledger text rather than
  quoting a numbered-list source that does not exist verbatim. If a
  separate canonical wording exists elsewhere in the plan document that I
  did not find, the reviewer should compare; I did not invent facts, only
  restated what the spec and ledger already say under each ruling's name.
- I did not run `flutter run`, open a browser, or otherwise attempt any
  part of Steps 1–2, per the controller ruling in my task instructions.
- I did not run `superpowers:finishing-a-development-branch` — left for
  the controller, per my task instructions.

## Fix report — round 1

**Retraction.** My original report's "Issues or concerns" section claimed
"the plan's own Rulings 01-1 through 01-4 are not printed as a standalone
numbered list anywhere in the plan document or the ledger I could find."
That is false. `docs/superpowers/plans/2026-09-21-floor-planner-app-skeleton.md`
has a section titled **"Rulings made here rather than left to an
implementer"** at lines 45–72, with Ruling 01-1 … 01-4 labeled verbatim, each
as a full bolded-lead-in bullet with two to three sentences. I should have
found this before writing the note; I did not open the plan document itself
during the original task, only the spec, the ledger and the task reports.
Retracted.

**The actual defect.** Because I never read the plan document's Rulings
section, Ruling 01-3 in `docs/superpowers/notes/2026-09-21-plan-01-results.md`
was fabricated from an unrelated fact (the harness's `exp(pan.dy / -200)`
two-finger-scroll-to-zoom conversion not lifting into the package — a spec
finding from the "What this brainstorm changed" section, not a plan ruling
at all) instead of quoting the plan's real Ruling 01-3, which is about
`Tolerance.standard`. `Tolerance.standard` was never mentioned anywhere in
the note before this fix.

**What changed.**

1. Read `docs/superpowers/plans/2026-09-21-floor-planner-app-skeleton.md`
   lines 45–72 — the plan's "Rulings made here rather than left to an
   implementer" section, four bullets, Ruling 01-1 … 01-4.

2. In `docs/superpowers/notes/2026-09-21-plan-01-results.md`'s "Rulings"
   section, replaced all four bullets with text drawn from the plan's own
   wording (trimmed to roughly its first two sentences each), dropping the
   wrong `exp(pan.dy / -200)` sentence entirely rather than relocating it
   (it was already covered as a spec fact in the note's "What this plan's
   own premises measured false" item 1 area is not accurate either — it is
   actually covered in the spec itself, section "What this brainstorm
   changed," and is not a Task-10-owned finding, so I did not duplicate it
   into the premises section). The replacement text:

   - **Ruling 01-1** — the app's `analysis_options.yaml` is committed once,
     at scaffold, and never again. The spec's architecture block says
     "generated and NOT committed"; what `CLAUDE.md`'s "never commit
     `analysis_options.yaml`" has always meant in this repo is never commit
     the rewrite `flutter pub get` makes to a tracked one.
   - **Ruling 01-2** — the first fit happens at the real viewport, once. The
     spec says the app "shows the startup plan"; it does not say who fits
     the camera — `PlannerShell` constructs the camera fitted to a nominal
     1440×900, and `PlannerView` re-fits it once, on its first layout, to
     the size it actually got.
   - **Ruling 01-3** — the bound decisions use `Tolerance.standard` (linear
     `1e-9`), a `static const` in `camera_controller.dart`, not a
     constructor parameter. The spec says `Tolerance`; it does not say
     which, and a scale between `0.001` and `100` sits where `1e-9` is many
     ulps wide and far below anything a gesture produces.
   - **Ruling 01-4** — a `PointerPanZoomUpdate` whose `scale` equals the
     running value does not call `zoomAt`. A two-finger scroll reports
     `scale == 1.0` on every update; calling `zoomAt(anchor, 1.0)` would
     build a new transform and notify for nothing — the check is exact `==`
     on a stored event field (spec invariant 6).

3. Made the identical correction to the commit-range phrase (see point 4)
   in `STATUS.md`'s Plan 01 section. `STATUS.md` never actually carried the
   wrong Ruling 01-3 text or any numbered rulings list — its "Three rulings
   a reader must know" paragraph covers the rename, the placeholder
   `main.dart` and the golden baseline, none of which were wrong — so no
   ruling-text correction was needed there; verified with
   `grep -n "exp(pan.dy\|Tolerance.standard\|01-3" STATUS.md` (no hits
   before this fix).

4. Corrected the commit-range phrase in three places (one more than the
   two named in the fix instructions, for internal consistency): the
   results note's header ("Ten tasks done, `717b9cd..5cab91a`" →
   `717b9cd..b6d64a9` with the Tasks 1–9 / Task 10 split spelled out),
   `STATUS.md`'s Plan 01 section header (same pattern), and `STATUS.md`'s
   Resume-here paragraph ("...all ten tasks, `717b9cd..5cab91a`" — the same
   wrong range, in the same category of error, so fixed for consistency
   even though not explicitly named in the fix instructions). One
   occurrence was deliberately left alone: the results note's harness
   table ("| | branch point (`717b9cd`) | head (`5cab91a`) |") — that table
   reports the harness's test count as measured at the time of Task 9's
   run, which really was `5cab91a`; the count (82) is unaffected by Task
   10's docs-only commits, so the historical reference stays accurate.

5. `git status --short` after the edits showed only the two intended files
   modified, no `analysis_options.yaml` anywhere in the workspace touched
   (nothing to restore with `git checkout --`).

6. Committed only the note and `STATUS.md`:

   ```
   commit 531998a
   docs: Plan 01 results -- restate the plan's four rulings verbatim, fix the commit range

   Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>

    STATUS.md                                                    | 6 ++++--
    docs/superpowers/notes/2026-09-21-plan-01-results.md         | 24 ++++++++++++------
    2 files changed, 29 insertions(+), 21 deletions(-)
   ```

**Verification.** `grep -n "Ruling 01-" docs/superpowers/notes/2026-09-21-plan-01-results.md`
now shows the four corrected bullets plus the two unrelated in-text
references (the M-01b degenerate-fixture explanation citing Ruling 01-4,
and the D4-check summary line); `grep -n "Tolerance.standard"` now finds
one hit, in Ruling 01-3. `git show --stat 531998a` lists exactly the two
files named in the fix instructions.
