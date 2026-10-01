# Task 4 brief — the placer

You are the implementer of Task 4 of plan 09a. Work ONLY in the git worktree
/home/user/jet-cad/.claude/worktrees/plan-09 (branch plan-09/symbol-library-core, HEAD 5b9237f).
Read, in order: CLAUDE.md, the spec docs/superpowers/specs/2026-09-30-symbol-library-design.md (whole; D3, D6, F-2, F-3, F-6, F-8, D14 are
yours), and Task 4 plus "Global constraints", "Gates", "Rulings" (P-3, P-4, P-5, P-6) of
docs/superpowers/plans/2026-09-30-symbol-library-core.md. Read Tasks 1-3 reports (.superpowers/sdd/symbol-library-core/task-{1,2,3}-report.md)
and the code they made: AddDefinitionCommand/RemoveDefinitionCommand (packages/jet_cad_2d/lib/src/document/commands.dart),
apps/floor_planner/lib/symbols/{symbol_component,symbol_library}.dart, apps/floor_planner/test/support/symbol_fixtures.dart (reuse it).
Also read Transform2 (packages/jet_cad_2d/lib/src/geometry/transform2.dart: multiply applies the ARGUMENT first), InstanceNode's constructor and
defaults (document/node.dart), AddNodeCommand/AddEntityCommand/SetComponentCommand, CompoundCommand (needs a named label), HandleSeed.
Known facts from earlier tasks: purge never touches components, and RemoveDefinitionCommand does NOT clear the component, so the placement
compound must include SetComponentCommand<SymbolComponent>(defHandle, null) on its undo path: use the compound's own inverse (the inverse of
SetComponentCommand(h, value) is SetComponentCommand(h, previous=null), which clears it: verify by test). Follow Task 4 exactly.

Environment: export PATH=/root/flutter/bin:$PATH ; prefix every test command with CI=true.
Scratch prefix for mutant backups: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/t4/ (create it). Mutation procedure: cp file to scratch backup, mutate ONE line, run the named test
file, cp back, diff must exit 0. NEVER git checkout -- a .dart file. Never commit analysis_options.yaml (stage by explicit path).
Never synthesize output: paste real output for every claim. Fixtures non-degenerate per P-4 and Task 4's list (basePoint off origin,
off-origin at, rotated AND mirrored, instance colour and lineweight distinct from the defaults, handle collisions across documents,
a foreign same-name definition, an older version beside a newer one). EVERY mutant in Task 4's list must be fired and reported with real
output; if one is equivalent or cannot be expressed, say so with evidence. Also report what validate() says on a saved plan with symbols (P-6 item 3).
The placer must allocate all handles at construction (F-8), write no table record, never touch purge, and pure Dart only (no Flutter / dart:io under lib/symbols/).
Code/comments/commit messages in English. Commit trailers:
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
Do not push. Commit when gates are green (app 659 + new, engine 1121 + 2 standing, render 974 + 1 skip + 7 standing, analyze and format clean).
Report to /home/user/jet-cad/.claude/worktrees/plan-09/.superpowers/sdd/symbol-library-core/task-4-report.md: commit SHA, files, real gate tails,
the full mutant matrix (id, file:line, red test, real output line), P-6 item 3, anything the spec got wrong or left open, decisions made.
