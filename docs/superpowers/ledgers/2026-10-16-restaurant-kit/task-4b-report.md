# Task 4b report: O1 engine seam

Status: DONE_WITH_CONCERNS. Commits: 4f1545f7 (fix, includes the spec edit), fcc1803b (test fix).

Design: `Set<Handle>? exclude` on SpatialIndex.snapInto and resolveDragPoint. Held in a field for the call
only (cleared in finally). A leaf is skipped (leaf walk, centre walk, intersection collection) when its handle
or any ancestor on its owner/parent chain is in the set; an excluded instance is not descended. Read-only
contains per candidate, no allocation. GripDrag.handles (late final, built once per drag); SelectTool sets
`_exclude` (before _moveBase and in _enter, move drags only; reshape/rotate unchanged) and clears it at drag end.

Gates (real runs):
- jet_cad_2d: dart test +1343 -2 (the two generate_document_test standing failures); analyze clean; format 0 changed.
  Allocation invariants (query_allocation_test) in that run pass.
- jet_cad_2d_flutter: +1451 ~1 -5 (the five text_ladder rungs, in standing_failures.txt; the two lod-ladder rungs
  listed there pass on macOS); analyze clean; format 0 changed. paint_allocation_test passes.
- plan --enable-vmservice: failed once before the fixture fix, then drag_self_snap_test passes; rerun of the full
  plan suite after the fix was NOT repeated (only that file). integration --enable-vmservice: +228 all passed.
  architecture_demo: +176 all passed (run before the last test-only commit).

Mutations (on committed code, reverted, git diff clean):
- skip the leaf-visitor exclusion -> snap_exclude_test 3 red; owner walk dropped -> 1 red; instance not skipped ->
  1 red; intersection collection skip dropped -> 1 red; resolveDragPoint not forwarding -> 1 red.
- SelectTool passes exclude: null -> select_tool_drag_test (new O1 test) red (26 vs 24), drag_self_snap_test red.

Decisions / concerns:
- drag_self_snap_test did not pass unchanged: the page grid was still on because PageNotifier follows the change
  stream a microtask late; the test is now async with pumpEventQueue and a premise expect (grid off). Remaining
  cause of the 4275.0 was the grid, not the object snap.
- select_tool_drag_test M-03p relied on the dragged line snapping to its own endpoint (the defect); it now has a
  separate unselected line ending at that point, same assertions (depth compared to the baseline).
- New flutter test needs objectSnap: true in the rig (default off) - first version was vacuous, caught by mutation.
- Plan suite not rerun in full after the fixture fix.

## Fix round 1
- _moveBase no longer sets _exclude: the press point resolves with no exclusion (own corner is a valid base snap);
  only target resolution excludes (move drags only).
- M-03p split: first half restored unchanged; second half (target onto the line's own endpoint = O1's defect,
  premise impossible) kept on an extra unselected line, with a `// Decided:` comment.
- New test: grab near own endpoint, release near another line's endpoint -> move vector exactly (290, 180).
  Mutation: `_exclude = drag.handles` back in _moveBase -> red (282.41 vs 290). Reverted.
- Gates: flutter full "+1453 ~1 -5: Some tests failed." (the five text_ladder standing failures), analyze clean,
  format 0 changed; plan --enable-vmservice "+1574: All tests passed!"; integration "+228: All tests passed!".
