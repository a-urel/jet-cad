# Task 7 report (6b + drawing tools and the frame)

Started at HEAD 3a3286b.

## 6b — commit a4d85f0 `fix(render): Task 6 review follow-ups`

Files:
- packages/jet_cad_2d_flutter/lib/src/reference_walk.dart: `container` filters only at depth 0 (`final root = depth == 0;` guards both skips). Root leaves (groups flattened into the root), root ATTRIBs (through their instance's effective layer) and root instances are still skipped when hidden; below the root nothing is. Doc comment quotes D6's residual. The context handle is still carried down (harmless; it only matters at the root).
- packages/jet_cad_2d_flutter/lib/src/outline_cache.dart: `_outlinesFor`'s InstanceNode case breaks when `FilterEvaluator.acceptsNode(key.target, rendering)` refuses (finding 2); `_addLeaf`'s comment names the D6 residual (finding 5).
- test/layers/reference_walk_layer_test.dart: + residual test (nested on C, tableCircle on C, inside the instance on A: both sinks contain legLine and tableCircle, lineC in neither, walks agree); + V4 test (rootA on ghost 0x6A6A drawn by both).
- test/layers/outline_layer_test.dart: + root instance on hidden A (direct write) with tableLine on B -> no outline; + V3 (circle region on layer 0 inside Table; 10 arcs before and identical after hiding layer 0).

Render gate at a4d85f0: `00:56 +1179 ~1 -7: Some tests failed.` (1175 + 4 new; the 7 standing text ladder rungs). analyze `No issues found! (ran in 1.5s)`; format `Formatted 204 files (0 changed) in 0.68 seconds.` (Full all-package gates run at Task 7's commit, below.)

| id | file / mutation | test | real output |
|---|---|---|---|
| M-LP-22 | reference_walk.dart `_hidden` -> `false` | reference_walk_layer | `00:00 +1 -6: Some tests failed.` e.g. `Expected: not contains <22>` |
| R-instance | reference_walk.dart drop `if (root && _hidden(effective)) continue;` | reference_walk_layer | `00:00 +5 -2: Some tests failed.` `Expected: not contains <33>` |
| R-attrib | reference_walk.dart ATTRIB `_Item(..., composed, instanceLayer,` -> `layer` | reference_walk_layer | `00:00 +4 -3: Some tests failed.` `Expected: not contains <37>` |
| R-below (new) | reference_walk.dart `final root = depth == 0;` -> `const root = true;` (the old stricter oracle) | reference_walk_layer | `00:00 +6 -1: Some tests failed.` residual test `Expected: contains <31>` |
| V4 | reference_walk.dart `?.visible ?? true` -> `?? false` | reference_walk_layer | `00:00 +6 -1: Some tests failed.` `Expected: contains <27>` |
| O-root-gate | outline_cache.dart root `acceptsNode(...)` gate -> `... && false` | outline_layer | `00:00 +7 -1: Some tests failed.` `Expected: empty Actual: [1190.0, 810.0, 1160.0, 870.0]` |
| V3 | outline_cache.dart `_addFill` boundary context -> `ReservedHandles.layerZero` | outline_layer | `00:00 +7 -1: Some tests failed.` (arc list differs) |
All `diff= 0` after restore.

## Task 7 — commit 4c7eca3 `feat(render): drawing tools use the current layer`

Files:
- packages/jet_cad_2d_flutter/lib/src/draw/line_tool.dart:46, text_tool.dart:69, placement_tool.dart:251 (region) and :255 (plain shape): `layer: drawingLayer(ctx.document)` instead of `ReservedHandles.layerZero`.
- test/support/layer_fixture.dart: optional `measurer` (default `MetricModelMeasurer`), because `DraftCanvas` refuses a document without a `FlutterTextMeasurer`.
- test/layers/draw_tools_layer_test.dart (3): drawScene + P-6 layers added by `AddLayerCommand`; the line tool, the text tool, the rectangle tool plain and filled (5 records). (1) A current -> all 5 on A; (2) locked B current -> all on B (D3: lock does not make a layer unusable); (3) a hidden stored current layer C (`SetCurrentLayerCommand.restore`) -> all on layer 0 (pins drawingLayer vs header.currentLayer).
- test/layers/canvas_layer_test.dart (1): a real `DraftCanvas` (tiles off) over LayerFixture with its own long-lived SpatialIndex; `state.painter.debugOnVisit` records every leaf handed to the sink and every instance descended. First frame primes the filter memo with A visible; the frame after the hook contains all 11 A handles (non-vacuous). `SetLayerCommand(A hidden)` -> `debugNeedsPaint` true after `idle`, paint count moves, the frame visits none of A's 11 handles and still visits lineZero, lineB, rootZero; undo -> A's handles again. The "painted sink" is observed through `debugOnVisit` (called right before `_drawLeaf` hands a leaf to the sink); there is no other per-handle probe on the live canvas's CanvasDrawSink.
- test/layers/tile_cache_layer_test.dart (3): `pumpTiled` over a fixture with layers A/B(locked)/C(hidden); a root line and a turned instance (definition line on layer 0) on A, a far line on B. Moving the line (and, separately, the instance) to hidden C -> after settle no live tile holds it and the far tiles survive (not a generation drop); undo -> every tile a fresh cache (TileRig oracle, as tile_invalidation_test does) bakes it into holds it again. Third test: a move A->B (both visible, ByLayer colour changes) drops the old tiles at the change itself, keeps the far side, and rebakes.
- test/layers/export_layer_test.dart (1): the real `exportPagePdf(compress: false)` over `exportFixture(FlutterTextMeasurer)` read by PdfContent. Root line and nested-group line (two turned groups) to C, the outer group's instance to C, the outer group's line to locked B, the export instance to A. Control export with C visible: the probed strokes present. Then `SetLayerCommand` hides C: root and nested lines absent, B's line present, exactly 3 paths fewer (the instance's one leaf included).

Gates at 4c7eca3 (CI=true, real tails):
- engine: `00:19 +1225 -2: Some tests failed.` (the 2 standing: `generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte`, `… both text fractions default to zero and change nothing`); `No issues found!`; `Formatted 168 files (0 changed) in 0.71 seconds.`
- render: `00:58 +1187 ~1 -7: Some tests failed.` (1175 at 3a3286b + 4 (6b) + 8 (Task 7); the 7 standing text ladder rungs 1-5 / text lod ladder rungs 1-2, RenderBackend.canvas); analyze `No issues found! (ran in 1.6s)`; format `Formatted 208 files (0 changed) in 0.62 seconds.`
- app: `03:04 +934: All tests passed!`; `No issues found! (ran in 1.6s)`; `Formatted 165 files (0 changed) in 0.78 seconds.`
- dev_harness_2d analyze: `No issues found! (ran in 1.1s)`.
- `git diff --stat a4d85f0 -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants` empty; no golden touched; analysis_options.yaml never staged (git status clean after commit).

Mutants (scratchpad/l7/mut.py (unique string) and mutl.py (by line number, for the two identical capability lines); cp backup, named test file in the foreground, cp back; every one `diff= 0`):

| id | file:line / mutation | test | real output |
|---|---|---|---|
| M-LP-16 line | line_tool.dart:46 `drawingLayer(ctx.document)` -> `ReservedHandles.layerZero` | draw_tools_layer | `00:00 +1 -2: Some tests failed.` `Expected: <19> Actual: <1>` |
| M-LP-16 text | text_tool.dart:69 same | draw_tools_layer | `00:00 +1 -2: Some tests failed.` |
| M-LP-16 region | placement_tool.dart:251 same (filled shape) | draw_tools_layer | `00:00 +1 -2: Some tests failed.` |
| M-LP-16 shape | placement_tool.dart:255 same (plain shape) | draw_tools_layer | `00:00 +1 -2: Some tests failed.` |
| D-stored | line_tool.dart:46 -> `ctx.document.header.currentLayer` | draw_tools_layer | `00:00 +2 -1: Some tests failed.` hidden-stored test `Expected: <1> Actual: <21>` |
| M-12e | packages/jet_cad_2d/lib/src/document/tables.dart:562 `layers = TableSection(onMutated: _bump);` -> `layers = TableSection();` | canvas_layer | `00:00 +0 -1: Some tests failed.` `Expected: not contains <23> Actual: Set:[22, 23, 24, …]` |
| M-12e' (info) | tables.dart:121 drop `onMutated?.call();` in `add` only | canvas_layer | SURVIVES `00:00 +1: All tests passed!` — expected: SetLayerCommand is remove-then-add and `remove` still bumps the revision once, which is all `_beginQuery` needs. |
| M-LP-19 entity | layer_commands.dart:392 `SetEntityLayerCommand.capability` -> `Capability.components` | tile_cache_layer | `00:00 +1 -2: Some tests failed.` (line-to-C `Expected: empty`; A->B `Expected: false Actual: <true>`) |
| M-LP-19 instance | layer_commands.dart:431 `SetInstanceLayerCommand.capability` -> `Capability.components` | tile_cache_layer | `00:00 +2 -1: Some tests failed.` instance-to-C `Expected: empty` |
| E-leaf | query_filter.dart:144 drop `if (!_visibleLayer(layer)) return false;` | export_layer | `00:00 +0 -1: Some tests failed.` `Expected: false Actual: <true>` |
| E-instance | query_filter.dart:177 drop the instance layer test | export_layer | `00:00 +0 -1: Some tests failed.` `Expected: <3> Actual: <2>` |

## What the spec/plan got wrong or left open; decisions

1. **M-12e's construction.** The plan says "bypass onMutated in a copy of the table edit used by the test". The test's edit is a `SetLayerCommand` through the dispatcher, so a copy of it would be a test-side fake rather than a product mutant. I mutated the product instead: the layers section is built without `onMutated` (one line, tables.dart:562). Then the command still emits its DocChange (so the canvas does repaint), but `tables.mutationRevision` does not move, `_reconcile` skips the layer handle (D6), the index's filter memo stays stale, and the frame still hands A's entities to the sink: red. Bypassing only `add`'s call survives (remove still bumps), recorded above.
2. **"Its painted sink"** is observed with `DraftPainter.debugOnVisit` on the canvas state's own painter (the leaf is reported immediately before `_drawLeaf` hands it to the sink). The canvas's `CanvasDrawSink` has no per-handle record; replacing it would need a rebuild hack.
3. **Tile test oracle.** The canvas's settle can cut tiles from a band whose shared record names more than each tile reaches (tiles (11,9),(12,9) held the root line before the move and legitimately do not after the undo), so "same tile set after undo" is false in a correct implementation. The undo assertion uses tile_invalidation_test's fresh-cache oracle: every tile the subject reaches holds it again.
4. **Export.** No code change, as D6 predicted. The test has no named mutant in the spec; E-leaf / E-instance (the filter's layer checks) are the ones that turn it red.
5. **6b.** The oracle still carries the context handle below the root (only the root uses it); simplifying it away would be a refactor beyond the finding.
