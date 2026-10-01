# Common rules for every 09b implementer

- Work ONLY in the git worktree /home/user/jet-cad/.claude/worktrees/plan-09b (branch plan-09b/symbol-palette).
- Read first: CLAUDE.md; the spec docs/superpowers/specs/2026-10-01-symbol-palette-design.md (WHOLE); the plan docs/superpowers/plans/2026-10-01-symbol-palette.md (your task, Rulings P-1..P-5, Global constraints, Gates); earlier task reports in .superpowers/sdd/symbol-palette/.
- Environment: export PATH=/root/flutter/bin:$PATH ; prefix EVERY test/analyze/format/build command with CI=true.
- Mutants: cp the file to your scratch prefix (named in your brief), mutate ONE line, run the named test FILE in the FOREGROUND, cp back, diff must exit 0. NEVER git checkout -- a .dart file. Small batches (container restarts kill background jobs and running agents).
- Never commit analysis_options.yaml (git status shows packages/jet_cad/analysis_options.yaml modified by pub get: stage files by explicit path only).
- Never synthesize output: paste real tail lines for every claim.
- Fixtures must not be degenerate (plan P-3): basePoint off the origin, rotated AND mirrored placements, pointer and camera far from the origin, camera scale != 1, snapped != raw where snap matters. Every new test needs a named mutant that turns it red.
- Code, comments, commit messages in English. Commit trailers exactly:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
- Do NOT push. COMMIT as soon as the gates are green (before long mutant runs), then fire mutants and record them in the report.
- Write your report EARLY and append as you go, to /home/user/jet-cad/.claude/worktrees/plan-09b/.superpowers/sdd/symbol-palette/task-<N>-report.md: commit SHA, files, real gate tails with counts, mutant table (id, file:line, red test, real output line), anything the spec/plan got wrong or left open, decisions made.
- If the spec or plan is wrong or impossible on a point, do the closest thing inside the spec's bounds and REPORT it; do not silently redesign. If a non-negotiable would be violated, stop and report.
