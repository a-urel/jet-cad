# Common rules for every plan-13 implementer

- Work ONLY in the git worktree /home/user/jet-cad/.claude/worktrees/plan-13 (branch plan-13/export-and-print).
- Read first: CLAUDE.md; the spec docs/superpowers/specs/2026-10-01-export-and-print-design.md (WHOLE); the plan docs/superpowers/plans/2026-10-01-export-and-print.md (your task, Rulings P-1..P-8, Global constraints, Gates); earlier task reports in .superpowers/sdd/export-and-print/.
- Environment: export PATH=/root/flutter/bin:$PATH ; prefix EVERY test/analyze/format/build command with CI=true.
- Mutants: cp the file to your scratch prefix (named in your brief), mutate ONE line, run the named test FILE in the FOREGROUND, cp back, diff must exit 0. NEVER git checkout -- a .dart file. Small batches (container restarts kill background jobs and running agents).
- Never commit analysis_options.yaml (git status shows packages/jet_cad/analysis_options.yaml modified by pub get: stage files by explicit path only).
- Never synthesize output: paste real tail lines for every claim.
- Fixtures must not be degenerate (plan P-3): the export fixture's page origin is (3000, -1500) at 1:50, the instance is rotated 30 degrees and scaled (1.5, -0.75) with colour and lineweight overrides, the screen page background is dark. Nothing at the origin, no identity transform, no default style. Every new test needs a named mutant that turns it red.
- No golden PNG may be regenerated; never pass --update-goldens. The render package has 7 standing golden failures on Linux (text ladders): that count must not change.
- The two allocation invariant tests (packages/jet_cad_2d/test/invariants/query_allocation_test.dart, packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart) must stay unedited and green.
- Code, comments, commit messages in English. Commit trailers exactly:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
- Do NOT push. COMMIT as soon as the gates are green (before long mutant runs), then fire mutants and record them in the report.
- Write your report EARLY and append as you go, to /home/user/jet-cad/.claude/worktrees/plan-13/.superpowers/sdd/export-and-print/task-<N>-report.md: commit SHA, files, real gate tails with counts, mutant table (id, file:line, red test, real output line), anything the spec/plan got wrong or left open, decisions made.
- If the spec or plan is wrong or impossible on a point, do the closest thing inside the spec's bounds and REPORT it; do not silently redesign. If a non-negotiable would be violated, stop and report.
