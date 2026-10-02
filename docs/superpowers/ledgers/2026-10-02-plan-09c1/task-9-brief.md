You are the IMPLEMENTER of Task 9 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Work ONLY there. Do not touch the main checkout at /home/user/jet-cad.

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan: docs/superpowers/plans/2026-10-02-wall-attach.md — its Rulings (P-1..P-8), Global constraints, Gates, and your task's section "### Task 9".
3. The spec: docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md — the decisions your task cites, and the Testing / Named mutants sections. The spec is binding; the plan says how.
4. The ledger: .superpowers/sdd/plan-09c1/progress.md (rulings so far) and earlier task reports in .superpowers/sdd/plan-09c1/.

Task 9 specifics (app only): spec D10 (rev 4, W-11). In lib/symbols/symbol_placer.dart, the lookup in `placeSymbol` (~:75-90) reuses a found definition (key+version match, definition exists) only when it is leaf-equal to the entry: same base point; the definition has no child nodes; the same number of live leaves (entities owned by the definition — see how boxOfDefinition in lib/symbols/symbol_box.dart enumerates them); pairwise ascending handle on both sides, every EntityRecord field except handle, owner and geomIndex (kind, layer, linetype, colour, lineweight, transparency, flags, linetype scale, text, tag, text style, text attributes — check packages/jet_cad_2d/lib/src/document/entity_store.dart for the exact field list and use them all), and the payload's coordinates and scalars, all exact ==. A non-equal one is passed over and the search continues to the next handle; none left -> a copy under the existing `#n` name rule. Consider sharing the record comparison with the Task 3b pre-09c test helper only if trivial; otherwise keep it local to the placer (a pure function, e.g. `isLeafEqual(DraftDocument, Handle, SymbolEntry)`), tested directly too. Tests in test/symbols/symbol_placer_test.dart: each of an edited leaf coordinate, scalar, colour, lineweight, flags, a text field (if a record field can be set without breaking validate), an extra leaf, a missing leaf, a child node, a moved base point causes a copy (name `key@version#2`, two definitions); an unedited one is reused (P7's count stays); `-0.0` vs `0.0` counts as equal (stated, not a mutant). Fixtures: a non-origin base point, a placement rotated and mirrored. Mutants: M-09c-p (ignore a payload scalar; ignore a style field; ignore the base point — each), M-09c-bd (ignore child nodes; ignore the leaf count — each). Gate: the app (engine and render unchanged).
Process: you are the only implementer in the plan worktree now, but reviewers run in their own worktrees; if you start another long `flutter test` in parallel, do it in a detached scratch worktree (two flutter test runs in one worktree corrupt build/unit_test_assets).

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
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C9-k) with its cost-if-wrong in your report; do not silently deviate.
- Container restarts happen: write your report early to .superpowers/sdd/plan-09c1/task-9-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task9/

Report (task-9-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts (engine/render/app passes, failures, skips; analyze; format; web build when required), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
