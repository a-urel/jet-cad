# Task 12 report: gates, results note, spec amendments, STATUS, roadmap

**Status:** DONE (Steps 1–4; Step 5's ledger archive is not done, per
Ruling T12-a).
**Commit:** `136af89` docs: Plan 03 results, spec amendments, STATUS and
roadmap. Trailer: `Co-Authored-By: Claude Opus 5.5` (Ruling T2-a; Opus 5.5
wrote this commit).

## What I did

1. **Step 1: ran all four gate lines, with both release builds, on the
   final tree.** HEAD was `7879e36` and `git status --short` was clean. One
   script (scratchpad `gates-p03/run.sh`) ran each command in its package
   directory, wrote the output to a file and appended `EXIT=$?`. Summary
   lines from those files:
   - engine: `CI=true dart test` printed `00:03 +890: All tests passed!`,
     EXIT=0. `dart analyze` printed `No issues found!`, EXIT=0. `dart
     format` printed `Formatted 130 files (0 changed) in 0.23 seconds.`,
     EXIT=0.
   - render: `CI=true flutter test` printed `00:12 +851 ~1 -5: Some tests
     failed.`, EXIT=1. The five failing tests are exactly `test/golden/text_ladder_golden_test.dart:
     text ladder rung 1..5 (RenderBackend.canvas)`; I checked with a
     `grep | sort | uniq` over the failing list. `flutter analyze` printed
     `No issues found! (ran in 1.5s)`, EXIT=0. `dart format` printed
     `Formatted 159 files (0 changed) in 0.29 seconds.`, EXIT=0.
   - harness: `CI=true flutter test --concurrency=1` printed `00:20 +82: All
     tests passed!`, EXIT=0. `flutter analyze` printed `No issues found!
     (ran in 1.0s)`, EXIT=0. `dart format` printed `Formatted 22 files (0
     changed) in 0.05 seconds.`, EXIT=0.
   - app: `CI=true flutter test` printed `00:01 +26: All tests passed!`,
     EXIT=0. `flutter analyze` printed `No issues found! (ran in 0.9s)`,
     EXIT=0. `dart format` printed `Formatted 8 files (0 changed) in 0.03
     seconds.`, EXIT=0. `flutter build macos --release` printed `✓ Built
     build/macos/Build/Products/Release/floor_planner.app (51.1MB)`, EXIT=0.
     `flutter build web --release` printed `✓ Built build/web`, EXIT=0.
   - The differential's printed line, from the engine run: `03 differential:
     seed 0x5EED0003, 200 trials, worst residual per kind: {point: 0.0,
     line: 2.9103830456733704e-10, polyline: 4.656612873077393e-10, circle:
     4.656612873077393e-10, arc: 4.656612873077393e-10, text:
     4.656612873077393e-10}`.
   - `git status --short` was clean after the run, so no
     `analysis_options.yaml` was rewritten.
2. **Step 2: the results note**,
   `docs/superpowers/notes/2026-09-23-plan-03-results.md`, in Plan 04's
   shape. It has:
   - the pasted gate lines;
   - a count-reconciliation table. Engine +2 comes from Task 10's addendum.
     Render +8 is Task 7's fix round (+3: two cursor-lifecycle tests and
     the stale-press test; the listener-leak and centre-grip fixes changed
     T14 and T8 in place) plus Task 10's addendum (+5). App +1 is Task 9's
     fifth test. The step-by-step counts come from the task reports;
   - the differential and the mutation tally (62 = 60 + 1 + 1);
   - criteria 1–16, each with named test witnesses;
   - criterion 16 OWED, with the brief's 12 items plus the controller's
     13th (grips and drags over 04's page grid), per platform;
   - Rulings 03-1…03-21 and all seven controller rulings (the two
     pre-flight rulings, T2-a, T7-a, T7-b, T11-a, T12-a), each with its cost
     if wrong. Ruling 03-7's cost sentence is recorded as corrected, as the
     ledger asked;
   - the debt: the plan's six items, the `PageComponent.copyWith` int cast,
     and the deferred minors no later task closed, grouped by task. A
     "closed by a later task" list follows for the record;
   - the list of spec amendments.
3. **Step 3: the spec amendments.** Each is a paragraph starting
   "**Amended at execution (Plan 03, 2026-09-23):**", appended at the end of
   its section. `git diff --numstat` shows the spec at 210 added lines and
   0 deleted.
   - D2: Rulings 03-6 and 03-9.
   - D3: Ruling 03-1, plus the reading of criterion 2.
   - D5: Ruling 03-8, the `ValueNotifier<MouseCursor>` mirror (why, and how
     it goes quiet while the layer leaves the tree), and the `GripRef` found
     again at the slop.
   - D6: Rulings 03-10 and 03-15.
   - D7: Ruling 03-3.
   - D8: Ruling 03-11.
   - Invariant 5: Ruling 03-12.
   - Differential: Ruling 03-16.
   - Named mutants: the M-03ab…M-03ax table (id, mutation, test; ab and as
     marked as re-expressed, ah's killer being O1), and the controller's
     M-03ay…M-03bg table.
4. **Mutation log:** fixed the two prose slips.
   - "= 61" now reads 60 killed, with the reconciliation to 62.
   - "10 killed, each behind a new test" now reads 10 killed: seven new
     tests (bf/bf′ share one), with M-03bc and M-03bd already guarded.
5. **Step 4: STATUS and the roadmap.**
   - `STATUS.md`: a new header paragraph; a new section, "Plan 03 — grips
     and transform (executed on `plan-03/grips-and-transform`, not
     merged)", with the task table (head commits abd0d28, 2612233, 7258df6,
     70bdde1, 8ea39b3, 2f2bab3, b7de33a, f6810fb, 32fa2cd, 061fd85,
     7879e36, and "this commit") and "What Plan 03 measured"; a Resume
     paragraph. "The other ten sub-projects" is now "nine".
   - `roadmap/03-grips-and-transform.md`: status line.
   - `roadmap/00-README.md`: row 03.

## Files changed
- docs/superpowers/notes/2026-09-23-plan-03-results.md (new)
- docs/superpowers/notes/plan-03-mutation-log.md
- docs/superpowers/specs/2026-09-23-grips-and-transform-design.md
- STATUS.md
- roadmap/03-grips-and-transform.md
- roadmap/00-README.md

## Self-review
- Every count in the note, STATUS and roadmap matches the pasted run: 890,
  851 + 1 + 5, 82, 26, both builds.
- The heading anchor `#plan-03--grips-and-transform-executed-on-plan-03grips-and-transform-not-merged`
  follows the GitHub slug rules used by the existing Plan 04 anchor.
- The spec diff is additions only. No code was touched.
- I checked the facts I cite against the code:
  - `dragGridStepMm` returns `double?`;
  - `Tool.paintWorldOverlay(Canvas, Vector2, double)`;
  - the cursor mirror's `_leaving`, `activate` and `didUpdateWidget` in
    `interaction_layer.dart`;
  - `GripCache` is built after `OutlineCache` in `main.dart`, and
    `PlannerView._repaint` includes `grips`.

## Concerns / deviations
- **Deviation (controller-mandated):** Step 5's ledger archive is not done
  (Ruling T12-a).
- **Deviation (controller-mandated):** the brief's planned counts (888 /
  843 / 82 / 25) differ from what ran (890 / 851 / 82 / 26). The note
  explains each difference.
- **Not touched:** STATUS.md's "Branch and worktree map" still says "No
  worktrees. Nothing is in flight." That was already stale before this
  task, and the brief does not list the section. The final wave may want
  to add the Plan 03 worktree row.
- **Not touched:** the mutation log's line 23 says "seven new test files
  (Tasks 1, 3, 4 ×2, 7, 8 ×2)". It means seven new tests in five files.
  It was not one of the two flagged slips, so I left it.
