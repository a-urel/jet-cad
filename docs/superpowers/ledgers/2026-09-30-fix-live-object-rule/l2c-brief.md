# L2c brief — the L2b review's R1

Implementer, branch `fix/live-object-rule`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-live-object-rule` (HEAD `9a4df2a`).
Read `CLAUDE.md` and `l2b-report.md`, `l2b-review.md` beside this file. The
worktree has uncommitted controller edits under `docs/` (a note, three
specs): do NOT stage, commit or change them — stage only your test file.
Never commit `analysis_options.yaml`. Commit; do NOT push.

R1: EG10 (`apps/floor_planner/test/wall_grips_test.dart`) asks
`attachCandidates` at the stray `WallParams`' far end, which is not near any
of the dimension group's drawn entities, so the dimension group is never
reached by the attach walk and the mutant **narrowAttach** (the walk's owner
check at `dimension_attach.dart` l.124 narrowed to "a live root group
carrying `WallParams` and not `OpeningParams`") survives the suite; under it
a point on the stray's line near the dimension's drawn geometry throws on
`wallsInDocument(doc, dim)!`. Put EG10's attach query at a point that is both
on one of the stray's attach lines and on (within the index's tight box of)
the dimension's drawn geometry, as EG9's `shadowTip` does; assert that
premise; keep `isNot(contains(dim))` and add a control that the query finds
something real if cheap. Fire narrowAttach (red, with the line) and re-fire
M-RV-narrowBands to confirm EG10 still kills it.

Procedure: backups under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/l2c-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart file.
`CI=true`; `export PATH=/root/flutter/bin:$PATH`. Never synthesize output.
Gates: app `flutter test`, `analyze`, `format`.

Commit `test(app): EG10 reaches the attach walk's owner check` with the two
trailers
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Write `.superpowers/sdd/fix-live-object-rule/l2c-report.md` and return it.
