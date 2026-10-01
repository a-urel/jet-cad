# Task 3 brief — SymbolLibrary, the loader that validates

You are the implementer of Task 3 of plan 09a. Work ONLY in the git worktree
/home/user/jet-cad/.claude/worktrees/plan-09 (branch plan-09/symbol-library-core, HEAD 51a9bda).
Read, in order: CLAUDE.md, the spec docs/superpowers/specs/2026-09-30-symbol-library-design.md (whole; D5, D7, F-3, F-14,
D14 and the V-4/V-9 notes are yours), and Task 3 plus "Global constraints", "Gates", "Rulings" of
docs/superpowers/plans/2026-09-30-symbol-library-core.md. Also read Task 2's report
.superpowers/sdd/symbol-library-core/task-2-report.md and apps/floor_planner/lib/symbols/symbol_component.dart.
Read how entities, geometry payloads (packages/jet_cad_2d/lib/src/document/drafting.dart has linePayload,
polylinePayload, circlePayload, arcPayload; scalars layouts are in geometry_store/primitives) and the codec
(json_codec.dart: how definitions and leaves are encoded, and that leaf handles are stripped from definition.children
on encode) work BEFORE writing the fixtures. Follow Task 3 exactly.

Environment: export PATH=/root/flutter/bin:$PATH ; prefix every test command with CI=true.
Scratch prefix for mutant backups: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/t3/ (create it). Mutation procedure: cp file to scratch backup, mutate ONE line,
run the named test file, cp back, diff must exit 0. NEVER git checkout -- a .dart file. Never commit
analysis_options.yaml (stage by explicit path). Never synthesize output: paste real output for every claim.
Fixtures non-degenerate: definition basePoint off origin, leaves off the origin, a version other than 1, tags of 3+.
Each rule of D5 must have its own throw site AND its own red test; the M-09j matrix (delete each throw, only its case
goes red) must be reported with real output. The library must NOT rely on the tree to reject a malformed library
(the loader validates itself; note the codec may repair or drop things on decode: if a rule can be made unreachable
by the codec's own repair, say so and test the rule on what the loader actually sees, or pre-validate the raw JSON).
Code/comments/commit messages in English. Commit trailers:
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
Do not push. Commit when gates are green (app 608 + new, engine 1121 + 2 standing, render 974 + 1 skip + 7 standing,
analyze and format clean). Pure Dart: no Flutter or dart:io import under lib/symbols/ (test files may use dart:io).
Report to /home/user/jet-cad/.claude/worktrees/plan-09/.superpowers/sdd/symbol-library-core/task-3-report.md: commit SHA, files,
every gate's real tails, the mutant matrix (rule, file:line, red test, real output line), anything the spec got wrong or left
open, decisions made.

## RESTART NOTE (controller)
The container restarted and the first Task 3 implementer was lost mid-task. It left UNTRACKED, UNREVIEWED partial work:
apps/floor_planner/lib/symbols/symbol_library.dart, apps/floor_planner/test/support/symbol_fixtures.dart,
apps/floor_planner/test/symbols/symbol_library_test.dart. Treat it as a draft by an unknown-quality author: read all of it,
re-derive every rule from the spec (D5) rather than trusting it, run it, and finish or rewrite as needed. The mutant matrix
and gates must be produced by you, freshly. Also fold in owed item m-T2-1 as a SEPARATE test-only commit AFTER Task 3's commit:
in apps/floor_planner/test/symbols/symbol_component_test.dart make SC6 check each omitted field of SymbolComponent.fromJson on its
own (one expectation per omitted field: key, name, category, tags, version), and fire the mutants "fromJson tolerates a missing
tags / version / name" (each alone) to show them red; report it as Task 2b in the report.
