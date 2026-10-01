# Task 3b brief — test-only follow-up to Task 3's review
Read common.md first. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/b3b/.
Read .superpowers/sdd/symbol-palette/task-3-review.md (findings 1, 2). Change ONLY packages/jet_cad_2d_flutter/test/symbol_thumbnails_test.dart (no lib change):
1. padding: for both fixtures assert the outer 2 device pixels on every side have alpha 0, AND the ink reaches within ~15% of an edge (so too much padding fails too). Fire: 'pad = 0.0 *' (symbol_thumbnails.dart:114) and 'fit on the raw extents' (:117): both must go RED.
2. sink DPR: add a sub-pixel leaf (lineweight 5 = 0.05 mm) and compare its peak alpha at DPR 1 and DPR 2 (or whatever observable difference vertices_draw_sink.dart:562,580 produces); fire 'sink devicePixelRatio forced to 1.0' (:125): must go RED. If no observable difference exists, prove it by experiment and record the mutant as equivalent.
Pixel tests under tester.runAsync. Render gate (count + new, 1 skip, 7 standing), analyze, format. ONE commit 'test(render): thumbnails pin the padding and the sink DPR (3b)'. Append a 'Task 3b' section to task-3-report.md.
