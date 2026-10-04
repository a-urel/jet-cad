You are the IMPLEMENTER of Task 11a of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Work ONLY there. Do not touch the main checkout at /home/user/jet-cad.

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan: docs/superpowers/plans/2026-10-02-wall-attach.md — its Rulings (P-1..P-8), Global constraints, Gates, and your task's section "### Task 11a".
3. The spec: docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md — the decisions your task cites, and the Testing / Named mutants sections. The spec is binding; the plan says how.
4. The ledger: .superpowers/sdd/plan-09c1/progress.md (rulings so far) and earlier task reports in .superpowers/sdd/plan-09c1/.

Task 11a specifics (app only): the end-to-end test of plan Task 11's first bullet, as apps/floor_planner/test/symbols/wall_attach_end_to_end_test.dart, through the real document host and shell (see test/symbols/symbol_palette_end_to_end_test.dart for how 09b drove the host: injected library read from File, fake document files, the real thumbnail cache). Scenario: a plan with a wall at 30° far from the origin and an L corner (two walls, 100 and 240 mm; build them with commands or the Wall tool), camera scale != 1:
 1. arm `bed.double` from the Symbols tab, hover near a face, press/release: the instance is flush (back edge on the face line within 1e-9 relative) and turned to the wall; compare its transform bytes with `attachToWall` computed independently from the document;
 2. arm `kitchen.base.600`, place three along the inside face of the L starting at the corner, each snapping to the previous (assert exact abutment: the second's left end equals the first's right end along t, within 1e-9);
 3. undo three times (the three units go), redo three times (back, bytes equal to before the undo);
 4. Save As (fake files) -> Open -> Save: byte-identical;
 5. "a plan saved before 09c": build a plan whose symbol definitions come from the pre-09c library fixture test/fixtures/furniture_pre_09c.jetlib (Task 3b; see `pre09cLibrary()` in test/symbols/furniture_library_test.dart — factor a shared helper into test/support/ if needed) by placing a few old symbols (bed.double, bed.wardrobe, kitchen.base.600, office.desk) with the placer, encode it, open it in the host: the symbols' bytes are unchanged after open + save; then placing the same symbols from the CURRENT library reuses those definitions (no `#2` names: the pre-09c definitions are leaf-equal to today's v1 entries — this is the D10 + 3b guarantee end to end), and a tagged one attaches.
Also fix the stale comment at test/symbols/symbol_placer_test.dart:~891-892 ("a record has no ==, a payload compares by identity" — both have value == now; the Task 9 review's note).
Mutants: M-09c-c (rotation keeps quarter turns) and M-09c-b at the end-to-end level; the release ignoring the attached transform; leaf-equality ignoring a style field (step 5 must go red: a pre-09c definition copied as #2 — choose a mutant that makes step 5 red, e.g. isLeafEqual always false); the asset not regenerated is not applicable. Gate: the app incl. web build; engine and render unchanged. You are the only implementer in the plan worktree.

Rules:
- `export PATH=/root/flutter/bin:$PATH`; prefix every test/analyze/format command with `CI=true`.
- TDD where it helps: write the tests, see them fail, implement, see them pass.
- Every new test must be owed a named mutant that turns it red. Fire every mutant your task lists: `cp` the file to a backup in your scratch dir, mutate, run the named test file, `cp` the backup back, verify `diff` exits 0. NEVER `git checkout --` a .dart file. Record each mutant: file:line, the change, the red test name(s), real output excerpt.
- Avoid degenerate fixtures (identity transform, origin, axis-aligned walls, default attributes, unmirrored only) as the plan's P-2 says.
- Never edit the two allocation invariant tests (packages/jet_cad_2d/test/invariants/query_allocation_test.dart, packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart).
- Never stage analysis_options.yaml; stage files by explicit path.
- Never synthesize test output. Quote real output only.
- Run the task's gates (plan "Gates"); the standing failures at the branch point are recorded in the plan's Gates section — compare counts.
- Commit as soon as gates are green, with the plan's commit message and these trailers:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_017Jpc94HDwBboPTaZBjjAFr
  Do NOT push. Do not touch other branches.
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C11a-k) with its cost-if-wrong in your report; do not silently deviate.
- Container restarts happen: write your report early to .superpowers/sdd/plan-09c1/task-11a-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task11a/

Report (task-11a-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts (engine/render/app passes, failures, skips; analyze; format; web build when required), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
