# Task 5b brief — test-only follow-up to Task 5's review
Read common.md first. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/b5b/.
Read .superpowers/sdd/symbol-palette/task-5-review.md (findings 1, 2). Change ONLY apps/floor_planner/test/symbols/symbol_ghost_test.dart:
1. For dining.table.rect.six assert, via computeMetrics(), that the closed polylines' contours report isClosed and the lines' do not (count both against the entry's leaves). Fire 'close() dropped' (symbol_ghost.dart:49): RED.
2. Two updates changing ONLY the base point's x, then ONLY its y (same at, turns, mirror), each adding exactly one computation. Fire 'base point x left out of the change check' (:134) and '... y ...' (:135): each RED.
App gate (count + new), analyze, format. ONE commit 'test(app): the ghost pins closed contours and each base-point component (5b)'. Append a 'Task 5b' section to task-5-report.md.
