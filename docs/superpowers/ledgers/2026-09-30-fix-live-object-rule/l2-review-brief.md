# L2 review brief — independent review of 980947d

You are the independent reviewer of L2 on `fix/live-object-rule`. Review in
the detached worktree `/home/user/jet-cad/.claude/worktrees/fix-live-object-rule-review`
(HEAD `980947d`; L1 `e0a56d0` below it is already reviewed and Approved). Do
not commit, do not push. Read `CLAUDE.md`, the brief
`/home/user/jet-cad/.claude/worktrees/fix-live-object-rule/.superpowers/sdd/fix-live-object-rule/l2-brief.md`,
`l1-report.md` and the implementer's `l2-report.md` beside it. The report's
claims are not evidence: verify each one yourself.

Check at least:
- **Completeness**: grep `apps/floor_planner/lib` yourself for every
  root-level check and every `get<…Params>(…)` read; for each, is it a type
  or liveness decision, and does it go through `live_objects.dart`? Any
  missed site is Important. Also look outside `lib/parametric/` (`main.dart`,
  `planner_view.dart`, panels, the harness if the app feeds it).
- **Behaviour unchanged for app-made documents** (one type per group): argue
  it per site; the full app suite is evidence, not proof.
- **The shadow is the later type's object everywhere**: EG7–EG9, AM7 real,
  non-degenerate, and each reverted site goes red where the report says —
  re-fire at least M-L2-1, M-L2-2o, M-L2-3, M-L2-6p, M-L2-7 and M-Q2a
  yourself; add your own at a seam they miss (e.g. a shadow of another pair:
  a room or dimension group also carrying `WallParams`).
- The `selection_panel` Position change (file-only): correct and intended?
- Deviation 1 (`package:meta` in the pubspec, two imports switched): the
  pure-file claim (Ruling 11-2's grep), lock unchanged, web build.
- Cost: nothing new on the frame path (band cache only on invalidate; cite).
- Spec amendments across 06, 07, 08, 10, 11: accurate, not over-claiming.

Procedure (binding): mutate by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/l2r-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`;
pub get may be needed and must leave no tracked change other than the known
`analysis_options.yaml` rewrites (never commit anything). Never synthesize
output.

Gates: render and app (`flutter test`, `analyze`, `format`, and the app's
`flutter build web --release`); engine once (unchanged since e0a56d0).

Write `/home/user/jet-cad/.claude/worktrees/fix-live-object-rule/.superpowers/sdd/fix-live-object-rule/l2-review.md`
(the only file you write outside your scratch prefix) and return it: verdict
(Approved / Needs fixes), Important and minor findings with evidence, every
mutant you fired with its red test and line, gates you ran.
