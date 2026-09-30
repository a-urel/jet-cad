# L1 review brief — independent review of e0a56d0

You are the independent reviewer of L1 on `fix/live-object-rule`. Review in
the detached worktree `/home/user/jet-cad/.claude/worktrees/fix-live-object-rule-review`
(HEAD `e0a56d0`); do not commit, do not push, do not touch the branch
worktree (another agent is working there). Read `CLAUDE.md`, the brief
`/home/user/jet-cad/.claude/worktrees/fix-live-object-rule/.superpowers/sdd/fix-live-object-rule/l1-brief.md`
and the implementer's report `…/l1-report.md` beside it. The report's claims
are not evidence: verify each one yourself.

Check at least:
- **No engine behaviour change**: `_survey`'s `found`/`stray` identical to
  019aedb's for every holder shape (one type, two types, a type registered
  twice, strays of every holder kind); `stray` never iterated (grep); the
  engine suite and the render/app suites unchanged apart from the +5.
- **The public query is the engine's rule exactly**: `names`/`objectsOf`
  built on the same private function; `isFor`'s exact matching (`U == T`)
  correct for every case the app will ask (a concrete registered type) and
  for the ones the report claims false; the "registered twice" argument.
- **The tests are non-degenerate** and each named mutant really goes red
  where the report says: re-fire at least M-L1a, M-L1b, M-L1c, M-L1g, M-L1h
  yourself; add your own at a seam they miss.
- The deviations (objectsOf's order via the store's contract; spec D5's
  wording about diagnostics) are true statements of the code.
- Spec 06 D5's amendment: accurate, consistent with the style.
- Cost: nothing new on the frame path.

Procedure (binding): mutate by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/l1r-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`;
`dart pub get` / `flutter pub get` may be needed and must leave no tracked
change (`git status` clean at the end). Never synthesize output.

Write `/home/user/jet-cad/.claude/worktrees/fix-live-object-rule/.superpowers/sdd/fix-live-object-rule/l1-review.md`
(the only file you write outside your scratch prefix) and return it: verdict
(Approved / Needs fixes), Important and minor findings with evidence, every
mutant you fired with its red test and line, gates you ran.
