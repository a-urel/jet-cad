# Task 1 brief — engine definition commands

You are the implementer of Task 1 of plan 09a. Work ONLY in the git worktree
/home/user/jet-cad/.claude/worktrees/plan-09 (branch plan-09/symbol-library-core).
Read, in order: /home/user/jet-cad/.claude/worktrees/plan-09/CLAUDE.md, the spec
docs/superpowers/specs/2026-09-30-symbol-library-design.md (whole; D4, F-1, F-3, F-13, R-1
are yours), and Task 1 plus "Global constraints", "Gates" and "Rulings" of
docs/superpowers/plans/2026-09-30-symbol-library-core.md. Follow Task 1 exactly.

Environment: export PATH=/root/flutter/bin:$PATH ; prefix every test command with CI=true.
Scratch prefix for mutant backups: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/t1/ (create it). Mutation procedure: cp the file to
the scratch backup, mutate ONE line, run the named test file, cp it back, then
diff backup file must exit 0. NEVER git checkout -- a .dart file. Never commit
analysis_options.yaml (git status shows packages/jet_cad/analysis_options.yaml modified by
pub get: leave it out of your commit; stage files by explicit path).
Never synthesize test output: paste real output for every claim in your report.
Tests must be non-degenerate: definition basePoint off the origin, leaves off the origin,
non-identity instance transform. Each new test needs a named mutant that turns it red.
Code/comments/commit messages in English. Commit trailers:
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
Do not push. Commit on the plan branch when the gates are green.

Report (write it to /home/user/jet-cad/.claude/worktrees/plan-09/.superpowers/sdd/symbol-library-core/task-1-report.md): commit SHA,
files, every gate's real tail output with counts (engine must be 1106+new, 2 standing failures unchanged), the
mutant table (id, file:line mutated, red test name, the real failing output line), the M-09g/M-09p
equivalence experiments' real results, anything the spec got wrong or left open, and any decision you made.
