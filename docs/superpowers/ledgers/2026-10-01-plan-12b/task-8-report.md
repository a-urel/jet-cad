# Task 8 report — tools and hosts in the app

Base HEAD 4c7eca3. Scratch: scratchpad/l8/.

## Progress log
- Six parametric tools: `SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(doc)))` appended as the creation compound's last child (one compound, one undo step).
- symbol_placer.dart: `InstanceNode.layer: drawingLayer(doc)`; definition leaves untouched (library's rule, layer 0).
- dimension_attach.dart: host kept only when `acceptsNode(host, rendering())` AND `objectLayer(doc, host)` is visible; doc comment residual rewritten.
- opening_tool.dart + wall_bands.dart: `WallBands.hostAt(..., accept:)` optional predicate; OpeningTool passes the top-level `isUsableHost` (object layer visible and unlocked). Its scan memo also keys on `doc.tables.mutationRevision`.

## Commit
`27db262 feat(app): tools draw on the current layer` (on 4c7eca3). Not pushed.

## Files
- apps/floor_planner/lib/parametric/{box,wall,opening,separator,room,dimension}_tool.dart: `SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(doc)))` as the creation compound's last child (box :38, wall :231, opening :258, separator :103, room :209, dimension :308).
- apps/floor_planner/lib/symbols/symbol_placer.dart:130 `layer: drawingLayer(doc)` on the InstanceNode.
- apps/floor_planner/lib/parametric/dimension_attach.dart: host kept when `acceptsNode(host, rendering())` && `_layerVisible(doc, objectLayer(doc, host))` (:142); new private `_layerVisible` (missing record = visible, as FilterEvaluator); doc comment's residual rewritten (closed for objects; what remains is a hand-written file whose children carry `invisible` or sit on a hidden layer other than the object layer).
- apps/floor_planner/lib/parametric/wall_bands.dart: `hostAt(doc, x, y, {accept})` and `_indexAt(..., [accept])`: a refused wall is passed over (`continue`), so the next band in handle order may host. `joinInto` (the Wall tool's join) passes none: unchanged (decision 8).
- apps/floor_planner/lib/parametric/opening_tool.dart: top-level `isUsableHost(doc, wall)` (objectLayer visible and unlocked; missing record visible/unlocked); `_hostAt` passes it, and its scan memo also keys on `doc.tables.mutationRevision`; class doc updated.
- apps/floor_planner/test/support/layer_fixture.dart (new): `layerDoc` (A ACI 1, B ACI 5 locked, C ACI 3 hidden, by AddLayerCommand; app components + parametric system), `addObjectOn` / `onLayer` (creation compound + ObjectLayer), `addWallsOn` (each wall in its own rotated group, corpusGroups), `layerFixture` (box of 4 walls on A, door on B hosted by wall 0, room on A, aligned dimension on B attached to wall 0's ends), `layerOf`, `objectLayerOf`, `moveObject`, `toolContextOf`, `clickWith`. Re-exports dimension_fixture (and through it room/wall fixtures).
- apps/floor_planner/test/layers/tools_layer_test.dart (9): fixture premise; Box, Wall, Door (host keeps A), Separator, Room, Dimension each on current B with every generated child on B, one undo step, undo removes object, children and ObjectLayer; Box with a hidden stored current C -> layer 0; placeSymbol: instance on B, definition leaves on layer 0, one undo step.
- apps/floor_planner/test/layers/attach_layer_test.dart (2, per swing): C5 T with a flush door on B; S on A attaches S/0/{l,c,r} through the door and S/1/centre through its children; S moved to hidden C: door still drawn near the points (premise), S not drawn, brute oracle still has the point, attachCandidates empty for all four; undo restores.
- apps/floor_planner/test/layers/opening_host_layer_test.dart (6): control on A; hidden C -> nothing; locked B -> nothing; same-point re-hover after hiding A (before the stream delivers) builds no preview; overlapping corner bands: south wall on C or B is passed over, east wall hosts; isUsableHost with a component naming a missing layer (=layer 0) and layer 0 locked.

## Sample document / exact-component tests
App suite at 27db262 before the new tests: `03:08 +934: All tests passed!` with the tool changes in. No existing test asserted a created object's exact component set or bytes in a way the new component moves; startup_plan builds its objects by command, not by tools, so it carries no ObjectLayer and is unchanged. **No existing test edited.**

## Gates at 27db262 (CI=true, real tails)
- engine: `00:18 +1225 -2: Some tests failed.` (the 2 standing: generate_document_test `the default document is the one Plan 2 measured, byte for byte`, `both text fractions default to zero and change nothing`); `No issues found!`; `Formatted 168 files (0 changed) in 0.58 seconds.`
- render: `00:58 +1187 ~1 -7: Some tests failed.` (7 standing text ladders); `No issues found! (ran in 1.4s)`; `Formatted 208 files (0 changed) in 0.72 seconds.`
- app: `03:05 +951: All tests passed!` (934 + 17); `No issues found! (ran in 1.5s)`; `Formatted 169 files (0 changed) in 0.71 seconds.`
- dev_harness_2d analyze: `No issues found! (ran in 1.2s)`.
- invariants diff vs 4c7eca3 empty; no golden touched; analysis_options.yaml not staged (status clean after commit).

## Mutants (scratchpad/l8/mut.sh: cp backup, one replacement, named test file in the foreground, cp back; every one `diff=0`)
| id | file:line / mutation | test | real output |
|---|---|---|---|
| M-LP-16 box | box_tool.dart:38 `ObjectLayer(drawingLayer(doc))` -> `ObjectLayer(ReservedHandles.layerZero)` | tools_layer | `00:00 +8 -1: Some tests failed.` `Expected: <19> Actual: <1>` |
| M-LP-16 wall | wall_tool.dart:231 same | tools_layer | `00:00 +8 -1: Some tests failed.` `Expected: <19> Actual: <1>` |
| M-LP-16 opening | opening_tool.dart:258 same | tools_layer | `00:00 +8 -1: Some tests failed.` `Expected: <19> Actual: <1>` |
| M-LP-16 separator | separator_tool.dart:103 same | tools_layer | `00:00 +8 -1: Some tests failed.` |
| M-LP-16 room | room_tool.dart:209 same | tools_layer | `00:00 +8 -1: Some tests failed.` |
| M-LP-16 dimension | dimension_tool.dart:308 same | tools_layer | `00:00 +8 -1: Some tests failed.` |
| M-LP-16 symbol | symbol_placer.dart:130 `layer: drawingLayer(doc)` -> `layer: ReservedHandles.layerZero` | tools_layer | `00:00 +8 -1: Some tests failed.` `Expected: <19> Actual: <1>` |
| D-stored (own) | box_tool.dart:38 -> `ObjectLayer(doc.header.currentLayer)` | tools_layer | `00:00 +8 -1: Some tests failed.` hidden-stored test `Expected: <1> Actual: <20>` |
| T-drop (own) | wall_tool.dart:231 the ObjectLayer command removed | tools_layer | `00:00 +8 -1: Some tests failed.` `Expected: <19> Actual: <null>` |
| M-LP-20 | dimension_attach.dart:142 drop `&& _layerVisible(doc, objectLayer(doc, host))` | attach_layer | `00:00 +0 -2: Some tests failed.` `Expected: empty Actual: [AttachedEnd:19/0/left]` |
| M-LP-25 | opening_tool.dart:286 `hostAt(..., accept: isUsableHost)` -> `hostAt(doc, raw.x, raw.y)` | opening_host_layer | `00:00 +2 -4: Some tests failed.` (hidden, locked, re-hover, overlap) `Expected: null Actual: <29>` |
| H-locked (own) | opening_tool.dart:449 drop `&& !(record?.locked ?? false)` | opening_host_layer | red: locked `Expected: null Actual: <29>`, overlap `Expected: <25> Actual: <21>`, isUsableHost `Expected: false` |
| H-pass (own) | wall_bands.dart:71 refused wall `continue` -> `return -1` | opening_host_layer | `00:00 +5 -1: Some tests failed.` overlap `Expected: <25> Actual: <null>` |
| H-rev (own) | opening_tool.dart:281 drop the `mutationRevision` memo key | opening_host_layer | `00:00 +5 -1: Some tests failed.` re-hover `Expected: <1> Actual: <2>` |

M-LP-16 was fired on every tool (the plan asked for one); each is killed by its own test.

## What the spec/plan got wrong or left open; decisions
1. **Where the host rule lives (S-11).** The spec says "the host must have a visible and unlocked objectLayer" but not what happens where bands overlap. I put the rule inside the scan (`WallBands.hostAt`'s `accept`), so a wall that may not host is passed over and the next band in handle order hosts, rather than "the lowest handle's band, then refuse". Rationale: a user who cannot see or select the hidden wall would otherwise be blocked by it. Pinned by H-pass. The Wall tool's band join (`joinInto`) is left unfiltered: decision 8 says a hidden or locked wall still joins, and S-11 names only the opening tool. Reviewer to confirm.
2. **The scan memo** (`_hostAt`, keyed by raw point and band generation) would serve a stale host on hover after a layer edit until the document's change stream delivers (a click already invalidates). I added `tables.mutationRevision` to the key (one int compare). Pinned by H-rev.
3. **Missing layer record** (only reachable if layer 0 itself is absent, since `objectLayer` falls back to layer 0): treated as visible and unlocked in both `dimension_attach` and `isUsableHost`, matching `FilterEvaluator`.
4. **Fixture** puts the room on A and the dimension on B (P-6 names them without layers). The tools test uses current layer B (locked) so the expected layer is neither layer 0 nor the walls' A; D3 keeps a locked current layer usable.
5. The plan's file table lists `opening_tool.dart (host)` separately; the host change also touches `wall_bands.dart` (the scan), not listed.
