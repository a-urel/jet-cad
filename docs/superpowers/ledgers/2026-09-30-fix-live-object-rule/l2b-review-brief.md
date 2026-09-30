# L2b review brief — independent review of 9a4df2a

Independent reviewer of L2b on `fix/live-object-rule`. Review in the detached
worktree `/home/user/jet-cad/.claude/worktrees/fix-live-object-rule-review`
(HEAD `9a4df2a`; `e0a56d0` and `980947d` below it are reviewed and Approved).
Do not commit, do not push. Read `CLAUDE.md`, and in
`/home/user/jet-cad/.claude/worktrees/fix-live-object-rule/.superpowers/sdd/fix-live-object-rule/`:
`l2-review.md` (its m1, m2, m5), `l2b-brief.md`, `l2b-report.md`. The
report's claims are not evidence: verify each one yourself.

Check: EG10 and TT10 real and non-degenerate (premises asserted, rotated
off-origin groups, the stray made as a file would); re-fire at least
M-RV-narrowBands, M-RV-narrowAdapter, M-L2-5t-face, M-L2-5t-name yourself and
add your own; `lib` behaviour unchanged (`git diff 980947d 9a4df2a -- apps/floor_planner/lib`
is a comment wrap only); the reports' claims about TT10's two sites.

Procedure: backups under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/l2br-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart file.
`CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`. Never
synthesize output. Gates: app `flutter test`, `analyze`, `format`.

Write `…/l2b-review.md` in that directory (the only file you write outside
your scratch prefix) and return it: verdict (Approved / Needs fixes),
findings with evidence, mutants fired with red test and line, gates.
