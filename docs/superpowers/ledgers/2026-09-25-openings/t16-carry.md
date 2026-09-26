# Task 16 — carried (binding, in addition to the plan's Task 16)

The ledger (progress.md beside this file) is the source of truth; read all of it.

First, as a separate commit ("Task 14 minors"):
1. A test that a box group (06's Box) is movable and rotatable through the
   composite ObjectGrips (e.g. `objects.movable(doc, boxGroup)` is true, or a box
   in SG2's mixed selection moves); mutant own-defaultMovable (`?? true` →
   `?? false` in ObjectGrips.movable) → red.
2. A one-line note in plan-08-mutation-log.md that five entries cite
   opening_grips_test.dart lines from 3d1713f (308/370/373 → 353/415/418 at
   de66cd2; values unchanged).
3. The stale comment in planner_shell_test's status-text test (it still says its
   point is on startup_plan.dart's first `rect`) — fix it (the controller lifts
   Ruling 08-1 for this one comment).

Then the plan's Task 16. Everything owed to it, collected from the ledger:
- **Spec amendments** ("Amended at execution (Plan 08)" paragraphs, like 07's):
  D2/D3 (none expected — check), D8 (already amended in-branch: keep-a-piece by
  admission order, degenerate host), D10/D12 (in-branch), D7 (in-branch),
  D13 (the re-seat via storedCentreOf when p′ is clamped only by ≤ wallJoin.linear;
  the adapter's `moved:`; "both ends moved" wording imprecise but harmless),
  D14 (storedCentreOf — the stored centre's ulp correction and its give-up at
  the fit/no-fit knife edge; the handle allocated inside build, no prediction),
  D15 (PlacementTool.markerPoint per Ruling 08-14; the aperture in host-local units
  = world ÷ |toWorld(f.d)|; the snapped centre stored exactly; off-centreline
  projection under a non-uniformly scaled host is oblique — files only),
  D16 (the no-change rule: `==`, or within wallJoin.linear and unclamped; grip
  candidates are the other openings' cuts as currently drawn; `movableKey` is new
  public render API; OpeningGrips.movable is the one movable rule),
  D17 (in-branch), D18 (none — the figures matched), open question list (mark
  resolved/accepted).
- **Plan amendments:** Task 3's HF3 bullet ("the stem's square end" → amended D7);
  the click point in Task 13 ((x0+100, y0) selects E4); OG11 is a new test ID
  (Task 5); Ruling 08-23 already amended; any other plan text a task found wrong
  (the ledger's "Plan wrong" notes for Tasks 1, 2, 4, 5, 7, 9, 10, 13).
- **Results note** docs/superpowers/notes/2026-09-25-plan-08-results.md, modelled
  on 2026-09-24-plan-07-results.md: the exit gate criterion by criterion (the
  spec's 17; criterion 1's macOS half and the look OWED by the human — list the
  look items per platform); gates on the final tree (run them; paste real output);
  mutation tally from the log; every review verdict and ruling (per task, from
  the ledger); measurements (RC1/RC2 — compare RC2 at n with NC4 at 2n; RC3;
  OT4 hover; the 50-openings edit cost with and without the memo; OG9's print;
  EP7/EP9; the drift of 2,000 end drags); known limits (Task 3's short-stem
  over-block and the parallel-skip jump; D12's no-fit limit; the Scale-field /
  capture observations as relevant: flutter_test non-AA 1-px strokes on integer
  pixels; 600-wall line draw ≈5 ms); debt (06's bare RemoveNodeCommand;
  paste/import handle remapping; the rotate-about-base-point follow-up; the
  Text-tool web alt-tab from fix/post-07).
- **STATUS.md**, **roadmap/08-openings.md** and **roadmap/00-README.md**: 08
  executed on plan-08/openings, NOT merged; the resume point (final whole-branch
  review, then the ledger archive, then the human's macOS build and look, then
  the merge). Keep the "Before …, this paragraph read:" convention.
Run all four gates plus the web build at the end and paste real output. Scratch
prefix `t16-`.
