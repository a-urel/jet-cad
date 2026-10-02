# Task 7 brief — the drawing tools and the frame (spec D6, D7) — preceded by 6b
Read common.md in this directory first and follow it. HEAD 3a3286b. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/l7/ (use only that directory; other agents' scratch dirs are not yours).

## First, as its own commit: 6b (Task 6's review, findings 1-5)
Read task-6-review.md. The reviewer's scratch tests are in scratchpad/r6-12b/ (zz_review_residual_test.dart, zz_review_gaps_test.dart).
1. reference_walk.dart: drop the leaf and nested-instance skips BELOW the root; keep the root-level ones (root leaf by layer, ATTRIB by its instance, root instance by effective layer). The oracle must match the painter below the root (spec D6's residual; progress R-12b-7). Add the residual test: a nested instance on hidden C and a definition circle on C inside the visible instance on A -> both sinks contain legLine and tableCircle and the walks agree. Re-fire M-LP-22, R-instance, R-attrib (see task-6-report.md / review for their definitions) -> still red.
2. OutlineCache: gate a root InstanceNode key by acceptsNode(key.target, rendering) (or the equivalent in its code); land the reviewer's scratch test (tableLine on B, A hidden by direct table write -> no outline).
3. Land the V3 test (a region inside the Table definition with layer 0 hidden; _addFill must test the boundary in the instance's context); re-fire V3 -> red.
4. Land the V4 test (a line on a ghost layer missing from the table appears in both sinks); re-fire V4 -> red.
5. _addLeaf's comment: one sentence naming the D6 residual (the outline is filtered below the root; the painter is not).
Commit `fix(render): Task 6 review follow-ups` (6b).

## Then plan Task 7 exactly
- Line, text and placement tools (packages/jet_cad_2d_flutter/lib/src/draw/{line_tool,text_tool,placement_tool}.dart) pass drawingLayer(document) instead of layerZero.
- Tests: test/layers/draw_tools_layer_test.dart (each tool family — line, text, one placement shape — draws on a non-zero current layer); test/layers/canvas_layer_test.dart (a DraftCanvas repaints after a hiding SetLayerCommand and its painted sink receives none of the layer's entities — M-12e: a table write that bypasses TableSection's onMutated must make it red; find how to construct that mutant cleanly, e.g. mutate TableSection's remove/add notification, and say exactly what you mutated); test/layers/tile_cache_layer_test.dart (a tile-cached canvas redraws after a layer move and after its undo — M-LP-19: the move commands report capability components -> red); test/layers/export_layer_test.dart (a page export omits a hidden layer; look at test/export/ and test/support/export_fixture.dart).
Mutants: M-LP-16 (drafting), M-12e, M-LP-19. Gates: all packages.
