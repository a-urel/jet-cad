You are the IMPLEMENTER of Task 6 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad/.worktrees/plan-09c1-t6 (branch wip/09c1-t6, cut from the plan branch tip 54eab37; the controller will cherry-pick your commits onto plan-09c/wall-attach). Work and commit ONLY there. Do not touch the main checkout or the plan worktree /home/user/jet-cad/.worktrees/plan-09c1 (another implementer, Task 9, works there) — EXCEPT that your report goes into the ledger directory /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/ (git-ignored; read progress.md and earlier reports there too).

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan (in your worktree): docs/superpowers/plans/2026-10-02-wall-attach.md — its Rulings (P-1..P-8), Global constraints, Gates, and your task's section "### Task 6".
3. The spec: docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md — the decisions your task cites, and the Testing / Named mutants sections. The spec is binding; the plan says how.
4. The ledger: /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/progress.md (rulings so far — read ALL of them, several bind this task) and task-2/3/4/5 reports and reviews there.

Task 6 specifics (app only): spec D4 (rev 4, read it in full with the W-3, W-7, W-14, S-4, S-9, T-1, T-6 amendments) and plan Task 6. Build on Task 4's lib/symbols/wall_attach.dart (FaceRun {a, t, m, length, thickness, wall, side}, FaceSide, faceRunsOf(doc, wall, {accept}), faceRunsAmong(host, walls)), Task 2's lib/symbols/symbol_box.dart (SymbolBox, boxOfEntry, boxOfDefinition — nullable: a null box means "does not attach", never `!`, ruling R-C2-2), Task 5's placementTransform(at:, basePoint:, rotation: (cos, sin), mirrored:) in lib/symbols/symbol_placer.dart (no unit-length check: pass a normalised t, R-C5-3), the tag consts in lib/symbols/symbol_library.dart (againstWallTag, familyTagPrefix — use them, not literals, R-C3-3).
Deliver: attachToWall(...) returning ({Transform2 transform, Vector2 q, FaceRun run})? per D4 steps 1-5 exactly; neighbours per D4 (root-level instances on visible, unlocked layers — find how picking filters layers, e.g. isUsableHost / layer visibility helpers in lib/layers or the engine —, SymbolComponent on the definition, orthonormal per the spec's definition with Tolerance.standard.linear, back edge on the run line within wallJoin.linear, front on the room side, interval overlapping [0, L]; an `exclude` handle for 09c-2); WallFaces (shell-owned cache over WallBands.liveWalls + an accept predicate + the document; runs and neighbours keyed on bands.generation; boxes of document definitions memoised and cleared on change; a pointer query over a cached set allocates O(1) — the Task 2 review's N-3: SymbolBox.backCentre allocates a Vector2 per call, so do not call it per neighbour per pointer move). No Flutter / dart:ui import in wall_attach.dart (plan P-4).
Tests: new test/symbols/wall_attach_test.dart using test/support/wall_attach_fixture.dart (extend it if needed, keeping existing scenes identical): every case the plan's Task 6 lists (30° and −112.5°, mirrored and not; the toilet's back exactly on the face within 1e-9 and its front in the room; pointer inside the band attaching to its own half's face for each justification; the T tie (pointer 1 px right of a stem narrower than captureWorld − 1 px, nearer the host face than the stem's own face: the right piece wins); edge snaps to a run end and to a neighbour rotated 180°; a back-to-back symbol on the opposite face is not a neighbour; a neighbour outside [0, L] is not one; the niche (L = W − 2e-10: assert L < W first, then u == L/2 exactly); a run shorter than W -> null; the axis-aligned -0.0 exception (M-09c-n); the far face with no run at p's u (M-09c-ah's −w variant, assert the winning run, not null)).
Mutants (plan Task 6): M-09c-b, -c, -d, -h, -i, -j (at the function), -m, -n, -af, -ah (s ≥ −w and s ≥ 0, each), -aq, -au; WallFaces not keyed on the generation. Gate: the app (engine, render unchanged) incl. web build — run them in YOUR worktree only.

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
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C6-k) with its cost-if-wrong in your report; do not silently deviate.
- Container restarts happen: write your report early to /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-6-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task6/

Report (task-6-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts (engine/render/app passes, failures, skips; analyze; format; web build when required), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
