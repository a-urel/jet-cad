# Standing brief — every implementer on plan-11/dimensions

Worktree: `/home/user/jet-cad/.claude/worktrees/plan-dims`, branch
`plan-11/dimensions`. Work only there; never `cd` to `/home/user/jet-cad` or
another worktree. Dependencies are fetched; Flutter/Dart at
`/root/flutter/bin` (put it on PATH).

Read, in order: `CLAUDE.md`; the plan
`docs/superpowers/plans/2026-09-28-dimensions.md` — its header, "Rulings
made here", "Global Constraints", "Review Focus", "File structure", and
YOUR task in full; the spec sections your task cites
(`docs/superpowers/specs/2026-09-28-dimensions-design.md`, revision 4). The
plan and the spec bind you; where they conflict, the spec wins and you
report it. The spike (branch `spike/11-dimensions`, read with
`git show spike/11-dimensions:<path>`; also extracted read-only at
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/spec11-spike-tree/`)
shows working seams; do not copy its shortcuts where the spec differs.

Binding:
- Every test command is prefixed `CI=true`.
- Mutants: `cp` the file to a backup under
  `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/plan11/`,
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
- Packages are frozen except Task 1's decision-25 files (Ruling 11-20).
- Your task's "Port from" line names spike code you may port; never port a
  spike shortcut the spec or plan overrides.
- A product defect or behaviour change beyond the spec: report and stop
  (Ruling 11-19); do not fix it yourself.
- Standing Linux failures, and only these: engine -2 (two hash tests in
  `test/testing/generate_document_test.dart`), render ~1 skip -7
  (`text_ladder` rungs 1-5, `text_lod_ladder` rungs 1-2).

Report: commit hash(es); files; each gate line verbatim; each mutant (edit,
command, red test and line, restore + diff); every deviation from the plan
or spec and why; anything you found that the plan got wrong.

Scratch files: name every script, backup and log you write under the
scratchpad's `plan11/` with a prefix unique to you (`t<N>-` for Task N's
implementer, `rv<N>-` for its reviewer); never overwrite another agent's
files there.
