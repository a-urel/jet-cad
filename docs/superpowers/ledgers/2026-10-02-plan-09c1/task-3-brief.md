You are the IMPLEMENTER of Task 3 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Work ONLY there. Do not touch the main checkout at /home/user/jet-cad.

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan: docs/superpowers/plans/2026-10-02-wall-attach.md — its Rulings (P-1..P-8), Global constraints, Gates, and your task's section "### Task 3".
3. The spec: docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md — the decisions your task cites, and the Testing / Named mutants sections. The spec is binding; the plan says how.
4. The ledger: .superpowers/sdd/plan-09c1/progress.md (rulings so far) and earlier task reports in .superpowers/sdd/plan-09c1/.

Task 3 specifics (app only): edit lib/symbols/furniture_catalog.dart (14 new symbols per spec D9's table, tags per D9 and plan Task 3), add loader rule R03d in lib/symbols/symbol_library.dart (look at how R03/R03b/R03c are written and tested in test/symbols/symbol_library_test.dart), regenerate the asset with `cd apps/floor_planner && dart run tool/generate_furniture_library.dart` (commit the generator's exact output), update the '27' assertions (furniture_library_test.dart:56 and any other, e.g. symbol_panel/gallery/search tests counting symbols — grep for 27) to 41 and name each in the report (plan P-6).
IMPORTANT (from the Task 2 review, N-1): test/symbols/symbol_box_test.dart's test 16 requires its `catalogBoxes` literal table to cover exactly the asset's keys. Add 14 HAND-DERIVED literals for the new symbols (derive them from your shapes by hand; do not print them from boxOfEntry), and do NOT weaken the key-set check. Use the box functions from lib/symbols/symbol_box.dart (Task 2) for the family depth/front/back test and the base-point-on-centre-x test.
Drawing style: look at the existing entries (beds: outline + pillows + fold line; wardrobe: outline + door lines + handles; base unit: outline + front line + knob; desk: outline + drawer block; sofa: outline + back + arms + seat divisions). New family members should be the same drawing scaled in width (pillows: two for 1400/1800 doubles, one for singles; wardrobe doors: 2 for 1200, 3 for 1800 (existing), 4 for 2400; sofa.two with one seat division). Dishwasher and washing machine: 600x600 outline, a front control strip line near y=40, and for the washer a door circle. Every shape front on y = 0, back at max y; base point on the box's centre x and off the origin (baseY = 0 like the other wall units is fine since baseX > 0).
Gates incl. `CI=true flutter build web --release` in apps/floor_planner. Engine and render unchanged: state it.

CONCURRENCY: another implementer works in the same worktree at the same time (Task 4: lib/parametric/wall_bands.dart, lib/symbols/wall_attach.dart, test/wall_bands_test.dart, test/symbols/wall_faces_test.dart, test/support/wall_attach_fixture.dart). Stage and commit ONLY your own files by explicit path. If a full-suite run fails in a file that is the other task's (uncommitted, in progress), re-run your own test files and say so in your report; do not edit the other task's files. Run the full app suite once more after your commit.

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
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C3-k) with its cost-if-wrong in your report; do not silently deviate.
- Container restarts happen: write your report early to .superpowers/sdd/plan-09c1/task-3-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task3/

Report (task-3-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts (engine/render/app passes, failures, skips; analyze; format; web build when required), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
