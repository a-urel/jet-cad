# Task 14 — carried (binding, in addition to the plan's Task 14)

First, as a separate commit ("Task 13 minors"):
1. **m1:** SP2 (startup_plan_test.dart) asserts every wall child's handle is below
   the LOWEST finish handle (`maxWallChild < minFinish`); mutant rv13-wallsMid
   (the kitchen-tile grid built before the walls) → red.
2. **m2:** fix the stale comments: startup_plan.dart ~124–138 (the bed-1/2 door's
   approach leaves bed 1 60 mm clear; the hall/living door's swing starts at
   x0+4040 so bed 2 is clear by 40 mm; the kitchen/living swing's far edge is
   y0+4360, the sofa 140 mm clear; the hall/kitchen swing is x0+5060..5960) and
   startup_plan_test.dart:268 (SP4's zone starts from the hinge face). Measure,
   don't copy: verify each number against the built plan.
3. **m3:** the E4 click point's comment in planner_shell_test notes that it holds
   while the pick radius (6 px) is under ~506 mm, i.e. at flutter_test's default
   800×600 surface.

Then the plan's Task 14 (mutation testing): fire ALL 37 spec mutants
(M-08a…M-08z3, M-08snap, M-08sn, M-08pin; M-08a structural on a scratch copy per
Ruling 08-19) at EVERY site each now has — multi-site mutants include M-08b (the
wall's reader, the tool writer, the grip writer), M-08h (the symbol, the tool
preview's symbol and jambs), M-08i (render capture, render rotatable, app
composite), M-08sn (geometry, tool, grip), M-08u (window, gap), M-08pin (Opening,
and 07's WS7 Wall/Box sections share _commit) — plus the tasks' named extras the
ledger lists as killed. Write docs/superpowers/notes/plan-08-mutation-log.md in
the form of plan-07-mutation-log.md (each: file, backup, edit, command, red
test and line copied from the run, restore + diff). Record equivalents and
survivors with their arguments (the ledger has them: X2-fillskip superseded,
X9-adapterDesc, rv7-invOrder, rv8-addForm, rv8-startOnly, rv9-adapterSelf,
rv10-edgeAnyHost, rv11-nestedAsk, rv12-chgCurrent, M-08b/M-08e controls,
M-08f1b-h …). Note: 07's Wall-tool join sites moved to wall_bands.dart (Task 9).
Never synthesize a transcript: every red line is copied from a run you made.
Scratch prefix `t14-`.
