# Q3 review brief — independent review of 47a7fcb

Review in the **detached** worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-11-review` (at `47a7fcb`); fire
mutants only there. Do not commit or push. Read `CLAUDE.md` first. Inputs (in
`/home/user/jet-cad/.claude/worktrees/fix-post-11/.superpowers/sdd/fix-post-11/`):
`q3-brief.md`, `q3-report.md`, the ledger `progress.md`. The diff:
`git show 47a7fcb`. Claims are not evidence. Never synthesize output.

Establish:
1. **The guard is right and complete.** Read `_written`, `_heldBefore`,
   `_Survey.stray` and the `_run` step. Is "wrote (not `==` to the before
   value)" the right condition, given spec 06 D5/D6/D8 and spec 08 D4? Can a
   client still attach a registered component off a live root-level group
   through `execute` — e.g. a compound that removes a node and writes a
   *different* value in one step, a write whose value `==` the before value on
   a handle whose node the same edit removes, a re-parent plus a write, a
   custom command that under-reports `touched`? A probe settles each better
   than a reading.
2. **Nothing legal is refused.** Every app path (the report's grep; verify it),
   undo/redo (never through `_run`), the cascade's cleanup, 08 D4's re-parent,
   loading a file with misplaced components and then editing near them.
3. **Cost.** `_Survey.stray` and `_written` on the edit path: no frame-path
   cost; per edit O(touched·types) plus one insertion per stray. Confirm the
   survey walk does not now allocate per object in the common (no stray) case.
4. **Tests.** MP1–MP9 non-degenerate? The seven converted fixtures: do they
   still test what they tested (a file-style stray written into the store), and
   are any assertions weakened? Is spec 06's amendment true?
5. **Re-fire** at least M-Q3a, M-Q3e, M-Q3h, M-Q3i, plus two of your own.
   Procedure (binding): `cp` to a backup under
   `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/q3r-`
   (yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER
   `git checkout --` a .dart file. `CI=true` on every test command.
6. **Gates:** [engine] and [app] (lines in `q3-brief.md`); standing failures
   engine −2.

Write `.superpowers/sdd/fix-post-11/q3-review.md` in the **branch** worktree
(that file only) and return it: Approved / Needs fixes; Important findings with
reproductions; Minor; what you fired; the gates.
