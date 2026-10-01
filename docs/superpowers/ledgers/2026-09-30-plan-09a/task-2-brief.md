# Task 2 brief — SymbolComponent and its registration

You are the implementer of Task 2 of plan 09a. Work ONLY in the git worktree
/home/user/jet-cad/.claude/worktrees/plan-09 (branch plan-09/symbol-library-core, HEAD e96c9cc).
Read, in order: CLAUDE.md, the spec docs/superpowers/specs/2026-09-30-symbol-library-design.md (whole;
D1, D3, F-5, F-14 and D14 are yours), and Task 2 plus "Global constraints", "Gates", "Rulings" (P-4, P-5, P-6)
of docs/superpowers/plans/2026-09-30-symbol-library-core.md. Also read apps/floor_planner/lib/parametric/catalog.dart,
packages/jet_cad_2d/lib/src/document/page_component.dart (the registration pattern to copy) and
packages/jet_cad_2d/lib/src/document/component.dart. Follow Task 2 exactly.

Environment: export PATH=/root/flutter/bin:$PATH ; prefix every test command with CI=true.
Scratch prefix for mutant backups: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/t2/ (create it). Mutation procedure: cp file to scratch backup, mutate ONE line,
run the named test file, cp back, diff must exit 0. NEVER git checkout -- a .dart file. Never commit
analysis_options.yaml (git status shows packages/jet_cad/analysis_options.yaml modified by pub get: leave it out;
stage files by explicit path). Never synthesize test output: paste real output for every claim.
Fixtures non-degenerate (definition basePoint off origin, leaves off origin, a tag list of 3+ with non-sorted order,
a version other than 1). Each new test needs a named mutant that turns it red.
Code/comments/commit messages in English. Commit trailers:
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
Do not push. Commit on the plan branch when the gates are green (engine unchanged by this task: run it once to state the count; app and render gates too).
Record P-6 item 1: what DraftDocument.purge does to a component on a definition (read the code, then write a real test that
observes it; do not fix it unless it loses data a save needs; if it does, stop and report).
Report to /home/user/jet-cad/.claude/worktrees/plan-09/.superpowers/sdd/symbol-library-core/task-2-report.md: commit SHA, files, every gate's
real tail output with counts (app must be 596 + new), the mutant table (id, file:line, red test, real failing output line),
P-6's purge finding, anything the spec got wrong or left open, decisions made.
