# Task 4b brief — test-only follow-up to Task 4's review
Read common.md first. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/b4b/.
Read .superpowers/sdd/symbol-palette/task-4-review.md (findings 1, 2). Change ONLY packages/jet_cad_2d_flutter/test/symbol_gallery_test.dart (no lib change):
1. After the images settle, pump with a new selectedId and with enabled: false; assert the thumbnail request count has NOT grown. Fire 'imageFor on every widget update' (symbol_gallery.dart:330, `if (true || ...`): must go RED.
2. With SymbolThumbnails(maxEntries: 1) and two cells (the first cell's entry evicted while pending), assert both cells end up showing an image that is non-null and not disposed (debugDisposed false). Fire 'clone taken after an await gap' (:348, `async { await null; ...`): must go RED. Image work under tester.runAsync.
Render gate (count + new, 1 skip, 7 standing), analyze, format. ONE commit 'test(render): the gallery requests once per key and clones on completion (4b)'. Append a 'Task 4b' section to task-4-report.md.
