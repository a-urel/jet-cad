You are the IMPLEMENTER of Task 7 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Work ONLY there. Do not touch the main checkout at /home/user/jet-cad.

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan: docs/superpowers/plans/2026-10-02-wall-attach.md — its Rulings (P-1..P-8), Global constraints, Gates, and your task's section "### Task 7".
3. The spec: docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md — the decisions your task cites, and the Testing / Named mutants sections. The spec is binding; the plan says how.
4. The ledger: .superpowers/sdd/plan-09c1/progress.md (rulings so far) and earlier task reports in .superpowers/sdd/plan-09c1/.

Task 7 specifics (app only): spec D6 (rev 4) and plan Task 7. The plan branch tip is b3284f1; everything Tasks 1-6, 8-10 built is there. Read the ledger's rulings in full — several bind this task: C-3 and R-C8b-1 (the tool's single recompute path `_update(ctx, raw)` = `_resolve` + `_syncPlacement`, used by pointer events, the camera listener and `_onArmed` — add the attachment THERE, once), R-C2-2 (null box = does not attach), R-C3-3 (use `againstWallTag` from lib/symbols/symbol_library.dart), R-C6-1..6 (WallFaces API: runsOf/neighboursOf/boxOf/attach, the `exclude` handle), the "Owed to Task 7 (from 8b)" note.
Deliver:
- SymbolPlaceTool takes an optional `WallFaces` (without it: today's behaviour bit for bit). In `_update`, after `_resolve`: when the armed entry's tags contain againstWallTag, `ctx.snap?.objectSnap ?? true` is on, and WallFaces.attach(...) with p = the RAW pointer, captureWorld = kWallAttachPixels / scale (kWallAttachPixels = 16.0, a new const), edgeCaptureWorld = kSnapAperturePixels / scale, mirrored = the tool's mirror, returns a result, the ghost's placement (the field `_syncPlacement` maintains) is that transform and the marker point is its q, drawn with the SnapKind.nearest glyph; otherwise today's placement and marker. The release places with `placeSymbol(..., transform: attached)` when attached (Task 5's `transform:` argument), else today's path. No Transform2 built in a paint (W-15): the attachment is computed in `_update`, the paint only reads fields.
- Keys while attached (decision 5): M toggles the mirror and the attached placement follows it in place; R / Shift+R change the turn count only (the attached ghost does not turn); off the face, the count applies. A key must recompute through `_update` (or the same path) so the attached ghost reflects M at once.
- After its own commit the tool calls `bands.invalidate()` (W-5) — check how WallFaces exposes / holds the bands; a unit placed right after another must see it as a neighbour before the change stream delivers.
- lib/main.dart: one WallFaces built over the shell's existing `_bands` (WallBands, main.dart ~:331), the document and `isUsableHost` (lib/parametric/opening_tool.dart:447) as the accept predicate, handed to the symbol tool; disposed with the shell if it needs disposal. Check how the document can change under the shell (document host keys the shell by document, 12a D2) so WallFaces never reads a stale document.
Tests (test/symbols/symbol_place_tool_test.dart, test/symbols/symbol_shell_test.dart; reuse test/support/wall_attach_fixture.dart): a tagged symbol attaches on hover and on release at 30° far from the origin at camera scale != 1, and the placed instance's transform equals attachToWall's bytes exactly; an untagged one (the island) does not; F3 off does not; a hidden and a locked wall do not host (through the shell's predicate); M while attached mirrors in place (footprint unchanged); R while attached changes nothing visible, then turns off the face; the marker at q; a camera zoom that brings a face within capture attaches (M-09c-ak); a re-arm between a tagged and an untagged entry while the ghost rests near a face switches attachment on/off (the 8b-owed mutant "the re-arm re-resolve skips the attachment"); a FRESH SHELL where no Wall or Opening tool ran: two units placed in a row along a face, the second snaps to the first (W-5); one undo step per placement; the permission check still precedes allocation.
Mutants (plan Task 7): M-09c-a (tag ignored), M-09c-e (through the shell's predicate: isUsableHost dropped), M-09c-j (mirror dropped while attached), M-09c-k (R turns the attached ghost), M-09c-l (attaches with F3 off), M-09c-ap (no invalidate after commit), M-09c-ak (camera re-resolve skips the attachment), the 8b-owed re-arm mutant, the marker at the raw point, the release ignoring the attached transform.
Note from the Task 8 re-review: F3 does not refresh the ghost today and 8b's re-arm test relies on that; do not change that behaviour (if you think you must, stop and report).
Gate: the app incl. `CI=true flutter build web --release`; engine and render unchanged. You are the only implementer in the plan worktree.

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
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C7-k) with its cost-if-wrong in your report; do not silently deviate.
- Container restarts happen: write your report early to .superpowers/sdd/plan-09c1/task-7-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task7/

Report (task-7-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts (engine/render/app passes, failures, skips; analyze; format; web build when required), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
