# Task 6b brief — test-only follow-up to Task 6's review
Read common.md first. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/b6b/.
Read .superpowers/sdd/symbol-palette/task-6-review.md (finding 1). Change ONLY apps/floor_planner/test/symbols/symbol_place_tool_test.dart (Task 7 may have added a separate keys test file: leave it alone):
(a) with a SnapSettings whose object snap is OFF in the ToolContext, a release near the line endpoint lands on the grid point (gridOf(near)), not on the endpoint; fire 'objectSnap: true' (symbol_place_tool.dart, the resolveDragPoint objectSnap argument): RED.
(b) with a page that has NO fixed grid step (the zoom-adaptive case), the release lands on the step dragGridStepMm(page, scale) computes; assert in the test that this step is not 25 and that the point differs from the raw one; fire 'page?.gridStepMm' in place of dragGridStepMm (the gridStepMm argument): RED.
App gate (count + new), analyze, format. ONE commit 'test(app): the placement tool follows the snap settings and the adaptive grid (6b)'. Append a 'Task 6b' section to task-6-report.md.
