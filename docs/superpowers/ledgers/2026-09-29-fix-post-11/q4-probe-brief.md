# Q4 probe brief — why a panel-legal wall thickness throws at turned placements

You are an investigator, not an implementer. Work only in the **detached**
worktree `/home/user/jet-cad/.claude/worktrees/fix-post-11-probe` (at
`a025c2f`). Commit nothing, push nothing; leave the worktree clean
(`git status --short` empty) at the end. Read `CLAUDE.md` first.

## The finding (post-11 found item (c))
`docs/superpowers/notes/2026-09-28-plan-11-results.md`, "Found, not fixed"
(c), and the Plan 11 ledger
(`docs/superpowers/ledgers/2026-09-28-dimensions/progress.md`, the Task 7
re-review line and "Ruling (m4 …)"): at every turned placement, a wall
thickness the Selection panel accepts (`isWallThickness`:
`apps/floor_planner/lib/parametric/wall.dart:28`, finite and above
`wallJoin.linear`) — 1.5e154, and 1e100 — makes `execute` throw 07's region
check (`_checkRegion`, `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`,
"generated a region whose boundary is not a closed polyline with a non-empty
triangulation"); the edit rolls back. The ruling asked: does the panel catch it?

## Establish, with probes (temporary tests you delete afterwards)
1. **What the user sees.** Drive the Selection panel's thickness field
   (`apps/floor_planner/lib/selection_panel.dart`, `_Kind.thickness`) with such
   a value on a wall in a turned group, through the widget, and report exactly
   what happens: is the exception caught anywhere, does it reach
   `FlutterError`, what does the field show afterwards, is the document
   unchanged, is history unchanged. Also through the wall tool's settings
   (the tool-settings target) and then drawing a wall with it.
2. **The threshold.** At which thickness does it start to throw, as a function
   of placement (origin, unturned far, turned near, turned far — the app's
   test fixtures have placements: `apps/floor_planner/test/support/room_fixture.dart`)?
   Is it a precision collapse of the band ring (which points coincide or go
   non-finite?), or overflow? Is there a thickness a real user could type
   (say ≤ 1e7 mm, 10 km) that throws anywhere a user can put a wall?
3. **Other routes to the same throw.** Any other panel-legal parameter
   (length via grips, opening width, a far wall end drag) that trips the same
   region check? Anything that throws from `execute` in the app's normal
   input paths?
4. **Options, each with its cost:**
   (i) an upper bound in `isWallThickness` (what value, and does it hold at
   every placement the app can reach — derive it, don't guess);
   (ii) the wall type never generates an untriangulable region (it generates
   no fill, or diagnoses, when the ring degenerates) — what spec 07 says about
   it (`docs/superpowers/specs/2026-09-24-walls-design.md`, D8, D12) and what
   would change;
   (iii) the panel catches a refused edit and shows the field as invalid;
   (iv) anything better you find.
   Recommend one, with a named mutant that would prove the fix.

Scratch prefix (yours alone):
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/q4p-`.
`CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`. Never
`git checkout --` a .dart file (backup, edit, restore, diff). Never synthesize
output: paste what the probes printed.

Write `/home/user/jet-cad/.claude/worktrees/fix-post-11/.superpowers/sdd/fix-post-11/q4-probe-report.md`
(that file only, in the branch worktree) and return it; keep the probe test
sources in the scratchpad and name them in the report.
