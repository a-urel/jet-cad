# Q2b brief — the Q1+Q2 review's m1 and m3

You are a fresh implementer on branch `fix/post-11`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-11` (HEAD `1ba7b94`). Work only
there. Read `CLAUDE.md`, then `.superpowers/sdd/fix-post-11/q12-review.md` and
the rulings after it in `progress.md` (binding). A reviewer works in
`.claude/worktrees/fix-post-11-review`; touch nothing there. Commit; do NOT push.
App files only.

1. **m1:** `apps/floor_planner/test/wall_grips_test.dart` EG6 gains a third
   stray holder kind: a file-style `WallParams` on a **root-level
   `InstanceNode`** (translated and rotated), its stored end on A's dragged
   corner in world — assert that, as EG6 does for the other two. Everything
   EG6 asserts about the other strays holds for it too. Mutant M-R1:
   `_isLiveGroup`'s `node is GroupNode` → `node != null`
   (`apps/floor_planner/lib/parametric/opening_geometry.dart`) must turn EG6
   red; it survives the whole app suite today (the review's probe PR1 is in
   `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/q12r_probe_test.dart`).
2. **m3:** `wall_grips.dart`'s `gripsOf` offers no grips on a holder that is
   not a live wall object, consistent with `drag` and `preview` (use the same
   adapter or predicate they use). A test: `gripsOf` on the node-less and the
   nested stray returns none; on a live wall returns its two. Mutant: the old
   `gripsOf`.

Mutant procedure (binding): `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/q2b-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command. Never synthesize output. Never
commit `analysis_options.yaml`.

Gate: `export PATH=/root/flutter/bin:$PATH; (cd apps/floor_planner && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)` — app +500 at `1ba7b94`.

Commit `test(app): EG6 pins a root-level instance stray; gripsOf offers none on a non-live holder (post-11 review m1, m3)`, ending with
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Write `.superpowers/sdd/fix-post-11/q2b-report.md` and return it: hash, what
changed, mutants with red lines, gate, deviations.
