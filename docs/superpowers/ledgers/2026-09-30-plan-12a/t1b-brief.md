# Task 1b brief — the Task 1 review's I-1

Implementer, branch `plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a` (HEAD `1fce8b7`). Read
`CLAUDE.md`, and in `.superpowers/sdd/plan-12a/`: `t1-brief.md`,
`t1-report.md`, `t1-review.md` (I-1). Test-only; no `lib` change. Another
agent reviews Task 2 in a separate worktree: do not touch it.

Add to `packages/jet_cad_2d/test/document/undo_state_test.dart` the case
"a new dispatcher's first edit leaves its initial id": a
`DraftDocument.empty()` with no fixture history; read `stateId` before any
command; one off-origin edit → the id differs from the initial one; undo →
the initial id exactly, with the content; redo → the post-edit id. Fire the
review's r1 (`_state = _next++` in `recordExecute`) and r2 (`int _next =
-1`): both red, record test and line; re-fire M-12a-5, 6a, 6b, 14 (undo,
redo) to confirm they are still red.

Procedure: backups under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t1b-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart file.
`CI=true`; `export PATH=/root/flutter/bin:$PATH`. Never synthesize output.
Gates: the engine (`+1106 -2` expected, or +N for N cases). Commit
`test(engine): a new dispatcher's first edit leaves its initial id` with
the two trailers; do not push. Write `t1b-report.md` in the ledger
directory and return it.
