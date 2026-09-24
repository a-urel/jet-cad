# Task 10 & 11 (Steps 1–4) report

Worktree: `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/quizzical-jemison-7537de`,
branch `plan-06/parametric-layer`. Never switched branches, never pushed,
never merged.

## Commits produced

1. `fbc6fba` — `docs: Plan 06 invariants and greps` (Task 10).
2. `7ce1e21` — `docs: Plan 06 results, spec amendments, STATUS and roadmap`
   (Task 11, Steps 1–4; the ledger archive, Step 5's second commit, was
   deliberately **not** done, per the controller ruling for this dispatch).

Both trailers are exactly `Co-Authored-By: Claude Opus 5.5
<noreply@anthropic.com>`. `git status --short` was clean before and after
each commit; no `analysis_options.yaml` was touched by any `flutter
analyze` / `flutter pub get` run.

## Task 10 — greps (Step 1)

```
$ git diff main -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l
0

$ grep -rn "package:flutter\|dart:ui" packages/jet_cad_2d/lib | wc -l
3
packages/jet_cad_2d/lib/src/document/tables.dart:38: (doc comment)
packages/jet_cad_2d/lib/src/document/text_metrics.dart:16: (doc comment)
packages/jet_cad_2d/lib/src/geometry/dasher.dart:47: (doc comment)
-> all three are pre-existing prose naming the pure-Dart constraint, no
   import of either. Same three lines Plan 05's own Task 10 recorded.

$ git diff main -- packages/jet_cad_2d/lib/src/document/component.dart | grep '^+' | grep -v '^+++'
+  /// Whether `T` already has a store. ...
+  bool isRegistered<T extends Component>() => _stores.containsKey(T);
-> component.dart's only change is Ruling 06-13's one method.

$ grep -rn "parametric" packages/jet_cad_2d/lib/src/document | wc -l
1
packages/jet_cad_2d/lib/src/document/undo.dart:92: (doc comment on the
  expander field, D2) -- not an import.

$ git diff --stat main -- packages/jet_cad_2d_flutter/lib
 packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart | 12 +++++++-----
 1 file changed, 7 insertions(+), 5 deletions(-)

$ grep -n "handleSeed.next" packages/jet_cad_2d/lib/src/parametric
(no hits)
```

All six checks matched the brief's expectations exactly (the two non-zero
counts are pre-existing prose/doc comments, confirmed above, not
violations). Full detail, with the exact file:line for each hit, is
appended to `docs/superpowers/notes/plan-06-mutation-log.md`'s new
"Invariants and greps (Task 10)" section.

## The four gate lines (Task 10 Step 2 / Task 11 Step 1), run with `CI=true`

Run once, live, in this dispatch, in full, `git status --short` clean
before and after every line. `main` (branch point) is `6adf03d`.

**`packages/jet_cad_2d`:**
```
$ CI=true dart test
00:03 +950: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +950: All tests passed!
```
Exit 0.
```
$ dart analyze
Analyzing jet_cad_2d... No issues found!
```
Exit 0.
```
$ dart format --output=none --set-exit-if-changed .
Formatted 141 files (0 changed) in 0.26 seconds.
```
Exit 0.

**`packages/jet_cad_2d_flutter`:**
```
$ CI=true flutter test
00:13 +925: Some tests failed.

Failing tests:
  test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Exit 1 — the standing exception, exactly these five golden rungs and
nothing else (925 pass + 1 pre-existing skip + these 5).
```
$ flutter analyze
Analyzing jet_cad_2d_flutter... No issues found! (ran in 1.7s)
```
Exit 0.
```
$ dart format --output=none --set-exit-if-changed .
Formatted 176 files (0 changed) in 0.33 seconds.
```
Exit 0.

**`apps/dev_harness_2d`:**
```
$ CI=true flutter test --concurrency=1
00:22 +82: All tests passed!
```
Exit 0.
```
$ flutter analyze
Analyzing dev_harness_2d... No issues found! (ran in 1.6s)
```
Exit 0.
```
$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.05 seconds.
```
Exit 0.

**`apps/floor_planner`:**
```
$ CI=true flutter test
00:04 +67: All tests passed!
```
Exit 0.
```
$ flutter analyze
Analyzing floor_planner... No issues found! (ran in 1.0s)
```
Exit 0.
```
$ dart format --output=none --set-exit-if-changed .
Formatted 19 files (0 changed) in 0.05 seconds.
```
Exit 0.
```
$ flutter build macos --release
Building macOS application...
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.4MB)
```
Exit 0.
```
$ flutter build web --release
Compiling lib/main.dart for the Web...                             26.0s
✓ Built build/web
```
Exit 0. **Both builds printed `✓ Built`.**

Branch commit trailers: `git rev-list --count 6adf03d..HEAD` → 13 (at the
time of the check, before this dispatch's two commits); `git log --format=%B
6adf03d..HEAD | grep -c "Co-Authored-By: Claude"` → 13. One trailer per
commit, all `Claude Opus 5.5`.

## Counts vs. the plan's own arithmetic

| suite | branch point | plan's sum | actual | diff | why |
|---|---|---|---|---|---|
| engine | 911 | 948 | **950** | +2 | Task 2's review round added `P11`/`P12` (mutants `M-06w`, `M-06x`); recorded as a controller ruling in the ledger, not silent drift |
| render layer | 923+1skip+5goldens | 925+1skip+5goldens | **925+1skip+5goldens** | 0 | exact match |
| harness | 82 | 82 | **82** | 0 | no task touches the harness |
| app | 46 | 66 (brief's own pre-flight sum, using the plan's stale `SP` naming) | **67** | +1 vs. the brief's sum, 0 vs. the ledger's corrected expectation | the panel's tests are `SE1`–`SE8` (8 tests), not the plan's `SP1`–`SP7` (7) — a naming collision with `startup_plan_test.dart`'s own `SP1`–`SP5`, caught at pre-flight and ruled before any code was written (names only, no test gained or lost beyond the ledger's own corrected count of 67) |

All four gate results match what `progress.md`, `plan-rulings.md` and the
mutation log already predicted going into this dispatch; nothing was
surprising.

## Docs written

- `docs/superpowers/notes/plan-06-mutation-log.md` — appended "Invariants
  and greps (Task 10)": the six greps with full detail, the four gate
  lines, the branch commit-trailer check.
- `docs/superpowers/notes/2026-09-24-plan-06-results.md` — new file: gate
  lines, the counts-vs-plan table, the mutation tally, the exit-gate table
  (14 rows), the five Review Focus items and their tests, the debt section
  (every ledger `minor (deferred)` and controller `Ruling:` line, one line
  each, the Task 8 focus-out gap flagged as the most user-visible, plus the
  spec's three open questions), criterion 14's OWED checklist (six items,
  three platforms, nothing ticked), the plan's rulings 06-1…06-13 (06-14
  explicitly recorded NOT made, no D13 amendment written for it), the
  controller's nine ledger rulings, and the spec-amendments summary.
- `docs/superpowers/specs/2026-09-24-parametric-layer-design.md` — seven
  "Amended at execution (Plan 06)" paragraphs appended (D1, D3, D4, D6, D10,
  the mutant table, the Testing section). Nothing original rewritten.
- `STATUS.md` — new header (Plan 06 executed, not merged, gate 13/14, look
  OWED, final review pending), a full "Plan 06" section inserted before the
  "Plan 05" section (overview, where-it-stands, documents, delivered,
  task-list table, rulings-a-reader-must-know, the measured-quantities
  table, debt), and the "Resume here" top paragraph rewritten with the old
  text preserved below as dated history.
- `roadmap/06-parametric-layer.md` — status line replaced ("not started" →
  executed/not merged/gate 13-14/look OWED/review pending, with links).
- `roadmap/00-README.md` — the 06 row filled in (spec, plan and results
  links, plus the same one-line status).

## Concerns

- **The ledger archive was intentionally not done.** Per the controller
  ruling for this dispatch and the ledger's own pre-existing ruling
  ("Tasks 10 and 11 (Steps 1–4) go to one dispatch; Task 11's ledger
  archive waits until after the final whole-branch review and its fix
  wave"), only Steps 1–4 of Task 11 landed. The `mkdir … cp -R … ledgers`
  step and its commit are for the controller to run after the final review.
- **Criterion 14 (the human's look) is OWED and not simulated.** The
  results note's checklist is entirely unticked; no device was run in this
  dispatch beyond the two release builds above (which only prove the builds
  compile, not that they look right).
- **No code was touched.** This dispatch is docs-only, as scoped; the two
  new tests that shifted the engine count (`P11`, `P12`) were already
  landed by Task 2's own fix round, not by this dispatch.
- **Nothing else surfaced.** Every grep, every gate count and every mutant
  tally matched what the ledger already recorded going in; this dispatch
  found no new defect.

## Fix round 1 (review r1) — two Important findings, both addressed

The coordinator's review of Tasks 10–11 found two findings:

1. **Wrong fork point.** STATUS.md, the results note and the mutation log
   all said the branch was "cut from local `main` at `6adf03d`". The real
   fork point is `6a279b3` — confirmed by `git log --format="%H %P" -1
   058918d`, which prints `6a279b3` as `058918d`'s sole parent. `6adf03d` is
   one commit earlier (`docs(spec): 06 revision 2 applies the r1 review`) —
   spec revision 2's own commit — which the plan's own `global-constraints.md`
   mislabelled as the branch point when it wrote "Branch-point counts at
   `6adf03d`". Both commits are docs-only (`6adf03d..6a279b3` adds only the
   plan document), so no measured count changes — only the cited SHA was
   wrong.
2. **Stale trailer count.** The results note's "13 commits on the branch
   (Tasks 1–10), 13 trailers" was measured with `git rev-list --count
   6adf03d..HEAD` when `HEAD` was `7b31030` — *before* Task 10's own commit
   (`fbc6fba`) existed, and therefore also before Task 11's commit
   (`7ce1e21`). It was stale the moment it was written into a note that
   itself became part of a later commit.

### What was fixed

- Replaced every fork-point reference (`6adf03d` used as a `git diff`/`git
  log` range bound, or as "cut from `main` at") with `6a279b3`, in:
  - `docs/superpowers/notes/2026-09-24-plan-06-results.md` (the header, the
    gate-lines intro, the harness `diff --stat` line, the counts table's
    column header);
  - `docs/superpowers/notes/plan-06-mutation-log.md` (the Task 10 section's
    intro, the "Branch-point counts from the plan" line, the harness
    `diff --stat` line, and the branch-commit-trailer block, recomputed
    against the correct historical endpoint — see below);
  - `STATUS.md` (the Plan 06 section's "Where it stands", and the "Resume
    here" paragraph).
  - `6adf03d` is kept in exactly the four places that genuinely mean "spec
    revision 2's own commit" — one explanatory sentence in each of the
    three files above, plus the mutation log's second one — each stating
    that `6adf03d` is spec revision 2's commit and that the plan's own
    constraints text mislabelled it as the fork point.
  - Also caught and fixed in passing: the mutation log's Task 10 section
    asserted `git diff --stat 6adf03d..HEAD -- apps/dev_harness_2d` was
    empty without that exact command ever having been run in this dispatch.
    Re-ran it (with the corrected base) before citing it again — see
    "Commands run" below.
- Recomputed the mutation log's own historical trailer count (Task 10's
  section, describing the tree as of `fbc6fba`) against the corrected range,
  explicitly bounded at `fbc6fba` rather than a bare `HEAD`, so the number
  stays true regardless of what lands later on the branch.
- Fixed the results note's stale trailer count using the pattern the
  coordinator suggested: made the SHA-correction fix commit first (with the
  trailer-count paragraph left as an explicit, unfilled placeholder —
  command shown, no fabricated numbers), then, immediately after that
  commit landed, ran the real commands against its own SHA, then wrote the
  measured numbers into a small follow-up commit that touches only that one
  paragraph.

### Commands run, with output

```
$ git log -1 --format="%H %P" 058918d
058918db23d2921c1e78ad514593018f2b1ca3fe 6a279b3b619a40ce0c7923916b9688574ec115f9
```
Confirms `6a279b3` is `058918d`'s sole parent — the real fork point.

```
$ git rev-list --count 6a279b3..fbc6fba
13
$ git log --format=%B 6a279b3..fbc6fba | grep -c "Co-Authored-By: Claude Opus 5.5"
13
```
The mutation log's Task 10 section's own trailer count, corrected and
re-measured against its true historical endpoint (`fbc6fba`, Task 10's own
commit): 13 commits, 13 trailers — coincidentally the same numeral as the
stale, wrongly-based figure it replaces, but now measured against the
correct range and stated as such.

```
$ git diff --stat 6a279b3..fbc6fba -- apps/dev_harness_2d
(no output)
$ git diff --stat 6a279b3..HEAD -- apps/dev_harness_2d
(no output)
```
Confirms the harness `diff --stat` claim in both the mutation log (bounded
at `fbc6fba`) and the results note (bounded at the then-current `HEAD`) is
genuinely empty, not asserted without having been run.

```
$ git add STATUS.md docs/superpowers/notes/2026-09-24-plan-06-results.md docs/superpowers/notes/plan-06-mutation-log.md
$ git commit   # "fix(docs): correct Plan 06's fork point to 6a279b3 (review r1)"
[plan-06/parametric-layer 01defe5] fix(docs): correct Plan 06's fork point to 6a279b3 (review r1)
 3 files changed, 51 insertions(+), 26 deletions(-)
```

```
$ git rev-list --count 6a279b3..01defe5
15
$ git log --format=%B 6a279b3..01defe5 | grep -c "Co-Authored-By: Claude Opus 5.5"
15
```
Measured immediately after the fix commit landed, against its own SHA
(`01defe5`), so the count legitimately includes that very commit: 15
commits from `6a279b3` through `01defe5` (Tasks 1–10: 13, plus the Task 11
results/STATUS/roadmap commit `7ce1e21`, plus this fix commit itself:
`13 + 1 + 1 = 15`), 15 matching trailers — one per commit.

```
$ git add docs/superpowers/notes/2026-09-24-plan-06-results.md
$ git commit   # "docs: record the branch commit trailer count at 01defe5 (review r1)"
[plan-06/parametric-layer af4149d] docs: record the branch commit trailer count at 01defe5 (review r1)
 1 file changed, 16 insertions(+), 8 deletions(-)
```

`git status --short` was clean before and after every command above; no
`analysis_options.yaml` was touched.

### Result

Both Important findings addressed. Commits: `01defe5` (the fork-point
correction) and `af4149d` (the trailer count, measured against `01defe5`
and recorded in its own small commit, per the coordinator's suggested
pattern). No code was touched; this remains a docs-only dispatch.
