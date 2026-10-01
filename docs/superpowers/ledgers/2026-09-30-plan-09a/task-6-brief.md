# Task 6 brief — the end to end (+ owed follow-up tests)

You are the implementer of Task 6 of plan 09a. Work ONLY in the git worktree
/home/user/jet-cad/.claude/worktrees/plan-09 (branch plan-09/symbol-library-core, HEAD a5e38a0).
Read, in order: CLAUDE.md, the spec docs/superpowers/specs/2026-09-30-symbol-library-design.md (whole; D6, D10, F-6, F-7, F-12, D14 are yours),
and Task 6 plus "Global constraints", "Gates", "Rulings" (P-4..P-7) of docs/superpowers/plans/2026-09-30-symbol-library-core.md.
Read the reports of Tasks 3-5 (.superpowers/sdd/symbol-library-core/task-{3,4,5}-report.md) and the code: apps/floor_planner/lib/symbols/*.dart,
assets/library/furniture.jetlib (load it with dart:io IN THE TEST and SymbolLibrary.decode), the painter tests that RECORD what is drawn
(packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart, draft_painter_test.dart, lineweight_test.dart, text_paint_test.dart: find the recording DrawSink
and how they build a DraftPainter, resolver and camera; you may copy the harness into apps/floor_planner/test/support/ if the render package does not export it: do NOT edit
render lib code), the engine index tests (packages/jet_cad_2d/test/index/pick_test.dart, snap_test.dart) for pick/snap call signatures, and apps/floor_planner/lib/new_document.dart
(prepareDocument). Follow Task 6 exactly.

Part A (Task 6): ONE end-to-end test, per the plan: place a library symbol (a REAL symbol from the committed asset, e.g. bed.double or a chair) through the real dispatcher
rotated one quarter turn AND mirrored, at a point far from the origin (e.g. (12345, -6789)), with a DISTINCT instance colour (a concrete IndexedColor or RGB not equal to any default)
and a concrete lineweight (e.g. 70, not kByBlock/default). Assert in that test: (1) the painter's recorded strokes carry the instance colour and the resolved lineweight, and NOT the
BYBLOCK-default ones, at the transformed positions (compute expected world endpoints independently from the symbol's local coordinates: a line leaf's two endpoints -> world via your own
formula, not Transform2 from the placer); (2) a pick at a point ON a named leaf (computed independently) returns the leaf, through the instance chain; (3) a snap onto a NAMED leaf endpoint whose
world position you computed independently, within Tolerance (F-12: the insertion point is NOT a snap candidate, do not assert it); (4) document extents; (5) validate() empty; (6) save->load
(registerAppComponents) byte-identical. Non-default-ness must be asserted by a control: the same symbol placed with the default style draws DIFFERENT colour/weight (so the test cannot pass at defaults).
Also confirm what a BYBLOCK-lineweight symbol leaf resolves to when the instance is the default style (record it: P-5 of Task 5's decision R-T5-2).
Part A case 2: the Select tool's rotation/move grips on the placed instance (P-6 item 2): run whatever the existing select-tool test harness in the render package allows (look at packages/jet_cad_2d_flutter/test/ for grip tests and
at select_tool.dart lines ~630-700 which already handle InstanceNode for delete). Record whether move/rotate grips work on an InstanceNode. If they do not, DO NOT FIX: record it as a found item for 09b.
P-7: if any assertion exposes a defect in engine or render code, STOP at that assertion, write a minimal reproduction and a report, and do NOT patch lib code; do not weaken an assertion to go green. If everything passes, the test stands.
Mutants (Part A): M-09c (placer drops rotation; drops mirror), M-09d (placer drops style), M-09a (placer ignores basePoint) must each turn THIS test red independently of Task 4's tests (run only this file and report its red test names); plus a painter-level mutant: make the placed instance's transform identity at the placer (equivalent to dropping it) and show which assertion catches it.

Part B (owed follow-up, SEPARATE test-only commit after Part A's commit):
 B1 (m-T3-1): in apps/floor_planner/test/symbols/symbol_library_test.dart add a case for the zero-sweep check: an arc whose sweep is tiny but non-zero and BELOW Tolerance.standard.angular must be refused (and one just above the tolerance accepted); show the mutant 'exact == 0' turns it red (symbol_library.dart line with p.scalars[2].abs() <= Tolerance.standard.angular).
 B2 (i-T4-1): in apps/floor_planner/test/symbols/symbol_placer_test.dart add a test that a placement cannot mutate the library entry: snapshot every leaf payload's coords/scalars and record fields before placing, place (rotated, mirrored, twice), then assert the entry's payloads are byte-equal to the snapshot; fire a mutant that transforms the payload in place (e.g. in symbol_placer.dart mutate leaf.payload.coords[0] += 1 before adding) to show it red.

Environment: export PATH=/root/flutter/bin:$PATH ; prefix every test command with CI=true. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/t6/ (create it). Mutation procedure: cp file to scratch backup, mutate ONE line, run the named test FILE (foreground, small batches; background jobs die on container restarts), cp back, diff must exit 0. NEVER git checkout -- a .dart file.
Never commit analysis_options.yaml (stage by explicit path). Never synthesize output; real output for every claim. COMMIT after Part A is green and again after Part B, before the long mutant runs if you like, then amend nothing: commit mutant results only in the report. Code/comments/commit messages in English. Commit trailers:
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
Do not push. Gates: app 768 + new, engine 1121 + 2 standing, render 974 + 1 skip + 7 standing, analyze/format clean, and flutter build web --release.
Write the report EARLY and update it as you go: /home/user/jet-cad/.claude/worktrees/plan-09/.superpowers/sdd/symbol-library-core/task-6-report.md (commit SHAs, what each assertion proved, real gate tails, mutant matrix with real output lines, the grips finding, BYBLOCK lineweight finding, any defect found).
