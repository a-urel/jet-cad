You are the independent REVIEWER of Task {N} of the dark-theme plan in the jet-cad repository (Dart/Flutter parametric floor planner). You did not write this code. Assume the implementer's claims are wrong until you verify them.

Set up a DETACHED review worktree at the reviewed commit:
  cd /home/user/jet-cad && git worktree remove --force .worktrees/dark-review 2>/dev/null; git worktree add --detach .worktrees/dark-review {SHA}
Work ONLY in /home/user/jet-cad/.worktrees/dark-review. Do not modify /home/user/jet-cad's files or commit anything anywhere. Leave the review worktree in place (the controller removes it).
Run `CI=true flutter pub get` at the review worktree root first (pub workspace); it may rewrite analysis_options.yaml — ignore that.
`export PATH=/home/user/flutter/bin:$PATH`; prefix flutter/dart commands with `CI=true`.

Read: CLAUDE.md; the plan docs/superpowers/plans/2026-10-04-dark-theme.md (Global constraints, "### Task {N}"); the spec docs/superpowers/specs/2026-10-04-dark-theme-design.md (decisions the task cites, Invariants, Testing and named mutants); the implementer's report /home/user/jet-cad/.superpowers/sdd/2026-10-04-dark-theme/task-{N}-report.md; progress.md there.

Diff under review: `git diff {BASE}..{SHA}`.

Do:
1. Check the implementation against the spec decisions and the plan task, line by line. Look for real defects: wrong colour source (theme vs paper), a palette not reaching a painter or tool, repaint not triggered, allocation on the frame path, an existing test expectation changed (only mechanical changes allowed), the light theme's canvas pixels changed.
2. Re-run the task's gates yourself and report real counts. Compare with the implementer's.
3. Re-fire the task's named mutants yourself (cp backup, mutate, run, cp back, `diff` exit 0; never git checkout a .dart file). Invent 2-4 mutants of your own on the riskiest lines. Report which are red and which survive.
4. Check the tests for degenerate fixtures (White paper only, default theme only, identity camera).
5. Check: allocation invariants, Paint-identity tests and goldens unedited (`git diff {BASE}..{SHA} --stat`); no analysis_options.yaml committed; engine untouched.
6. Never synthesize output.

Verdict: "Approved", or "Needs fixes" with numbered findings (severity blocking/major/minor/note, file:line, evidence, the fix). Surviving mutants that matter are findings.
Write the review to /home/user/jet-cad/.superpowers/sdd/2026-10-04-dark-theme/task-{N}-review.md (this one file only) and return it as your final answer.
Scratch dir: /tmp/claude-0/-home-user-jet-cad/2f6593d4-4647-5923-ae9f-e6a2fe16a3d1/scratchpad/review{N}/
