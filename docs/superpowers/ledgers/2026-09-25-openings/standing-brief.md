# Standing brief — every implementer on plan-08/openings

Worktree: `/home/user/jet-cad/.claude/worktrees/plan-openings`, branch
`plan-08/openings`. Work only there; never `cd` to `/home/user/jet-cad` or
another worktree. Dependencies are fetched; Flutter/Dart at
`/root/flutter/bin` (put it on PATH).

Read, in order: `CLAUDE.md`; the plan
`docs/superpowers/plans/2026-09-25-openings.md` — its header, "Rulings made
here", "Global Constraints", "Review Focus", "File structure", and YOUR
task in full; the spec sections your task cites
(`docs/superpowers/specs/2026-09-25-openings-design.md`). The plan and the
spec bind you; where they conflict, the spec wins and you report it. The
spike (`/home/user/jet-cad/.claude/worktrees/spike-openings`, read-only)
shows working seams; do not copy its shortcuts where the spec differs.

Binding:
- Every test command is prefixed `CI=true`.
- Mutants: `cp` the file to a backup under
  `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/plan08/`,
  mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --` a .dart
  file. Fire every mutant your task owns, at every site it names.
- Never commit `analysis_options.yaml` (restore it with `git checkout --`
  on the yaml only). Stage only your own files; never `git add -A`.
- Never synthesize output: every gate line and mutant result in your
  report is copied from a real run.
- Commit trailers, exactly:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv`
- No pushes. No subagents.
- Standing Linux failures, and only these: engine -2 (two hash tests in
  `test/testing/generate_document_test.dart`), render ~1 skip -7
  (`text_ladder` rungs 1-5, `text_lod_ladder` rungs 1-2).

Report: commit hash(es); files; each gate line verbatim; each mutant (edit,
command, red test and line, restore + diff); every deviation from the plan
or spec and why; anything you found that the plan got wrong.

Scratch files: name every script, backup and log you write under the scratchpad with a prefix unique to you (e.g. `t6-` for Task 6 implementer, `rv6-` for its reviewer); never overwrite another agent's files there.
