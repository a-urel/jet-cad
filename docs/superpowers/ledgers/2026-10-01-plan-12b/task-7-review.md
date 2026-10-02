# Task 7 review (6b + drawing tools and the frame)

Reviewer worktree: `.claude/worktrees/plan-12b-review`, detached at 4c7eca3 (base 3a3286b; a4d85f0 = 6b, 4c7eca3 = Task 7). `git status --short` was empty before, after every mutant and at the end; no analysis_options rewrite appeared. Mutants: cp backup, one replacement (unique string, or by line for the two identical capability lines), named test file in the foreground, cp back, `diff=0` printed every time. Scripts and outputs: `scratchpad/r7-12b/` (`mut.sh`, `mutl.sh`, `out_*.txt`, `engine.txt`, `render.txt`, `app.txt`).

## Verdict: **Approved with notes**

No product defect, nothing to fix before Task 8. 6b closes Task 6 findings 1-5 exactly. The notes are for the results note.

## 1. Diff review

### 6b (a4d85f0) against task-6-review findings

1. **Oracle below the root (R-12b-7): done.** `container` computes `root = depth == 0` and guards only the two skips with it. Root leaves (groups flatten into depth 0 through `_collect`), root ATTRIBs (carried with `instanceLayer`) and root instances are still filtered; below the root nothing is, as `_drawContainer`/`_descend` (draft_painter.dart:442-523) draw unfiltered. The doc comment quotes D6's residual. The residual test asserts absolute `contains` of `legLine` and `tableCircle` in both sinks, `lineC` in neither, then `agree()`.
2. **Root instance gate in the outline: done.** `_outlinesFor`'s `InstanceNode` case breaks on `!acceptsNode(key.target, rendering)`. A root instance's context is layer 0, so `acceptsNode`'s own-layer test is the right one. The reviewer's scratch case landed (tableLine on B, A hidden by direct write -> segments, arcs empty, bounds null).
3. **V3: landed.** Circle region on layer 0 inside `Table`, current moved to B, layer 0 hidden; arcs equal the 10-arc control.
4. **V4: landed.** `rootA` on ghost `0x6A6A`, contained in both sinks.
5. **`_addLeaf` comment: done.** It names the residual: picking-style filtering inside a definition, painter unfiltered.

### Task 7 (4c7eca3)

- **Tools.** line_tool.dart:46, text_tool.dart:69, placement_tool.dart:251/255 pass `drawingLayer(ctx.document)`. `grep layerZero` over the render `lib/` leaves only the selection, outline and walk's effective-layer arithmetic. `addDrafted`/`addDraftedRegion` have no other caller in lib: arc, circle, polyline and rectangle all commit through `PlacementTool`.
- **draw_tools_layer_test.** The test covers:
  - a line, a text, a plain rectangle and a filled one (`[1,1,1,2]` records), on A, then on locked B;
  - a hidden stored current C via `.restore`, which goes to layer 0. This pins `drawingLayer`, not `header.currentLayer`.
  - The points are off the origin (7010.5, …).
- **canvas_layer_test: does `debugOnVisit` see what reaches the sink?** `debugOnVisit` is called right before the leaf is drawn, after the index filter and `_omitted` (draft_painter.dart:391, 483), and on every descended instance (:423, :514).
  - Nothing is handed to the sink without a visit first, so the visit set is a superset of what is emitted. "None of A's 11 handles visited" therefore implies none of them is sunk, and the M-12e leg is sound.
  - A painter that visited but skipped the sink cannot cause a false green on the absence assertions. It could only cause a false green on the presence legs (non-vacuity, undo), and that is Info, finding 1.
  - The first pump after the hook primes the filter memo with A visible, so the hide really has to invalidate a cached answer.
- **tile_cache_layer_test.**
  - The before/after "far side survives" guard rules out a generation flush.
  - The fresh-cache oracle (`TileRig` over the same document, disposed in `finally`) is measured, not derived, as tile_invalidation_test does it.
  - `before ⊇ reached` and `live ⊇ reached` are the right inequalities for a settle that may cut more tiles than a fresh bake reaches (deviation 3).
  - The undo leg is load-bearing. My mutant U-undo (only the restore form reports `components`) kills it: `Expected: contains all of Set:[ … Actual: Set:[]`.
- **export_layer_test.** It runs the real `exportPagePdf` with `PdfContent`, with a control export first.
  - Hiding goes through `SetLayerCommand` after an export, so it goes through a fresh per-export index.
  - It uses two turned groups (identity asserted false).
  - Path count is exactly −3, which pins both the instance's definition leaf and that A and 0 still plot.

## 2. Rulings on the implementer's deviations

1. **M-12e built in the engine's `TableSection` wiring (tables.dart:562 `layers = TableSection()`): accepted.**
   - Spec Named mutants: "a layer toggle that writes the table without notifying (bypass `TableSection`'s `onMutated`)". The layers section with no `onMutated` is exactly that, applied to the real command path.
   - The plan's "copy of the table edit used by the test" would have been a test-side fake that proves nothing about the product.
   - The DocChange still repaints, so the red comes from the sink leg, which is the point of the mutant.
   - **The `add`-only bypass survivor is an equivalent mutant for this test.** `SetLayerCommand` is remove-then-add, and `remove` alone moves the revision before the next `_beginQuery`.
   - It is not a hole. I fired it against the whole engine suite: the engine's `tables_revision_test.dart` kills it, with `every table mutator bumps the revision and notifies [E]` and `every section is wired, not just layers [E]`, at `00:18 +1223 -4` (2 + the 2 standing).
   - The results note should cite that kill rather than list the bypass as a survivor.
2. **"Painted sink" observed through `debugOnVisit`: accepted.** See §1. The canvas builds its `CanvasDrawSink` internally and offers no per-handle probe. The hook is the established tile-invalidation probe, and it is a superset of emission.
3. **Fresh-cache oracle instead of "same tile set after undo": accepted.** Band-cut tiles make set equality false in a correct cache; the oracle is the one tile_invalidation_test already trusts.
4. **Export with no code change; E-leaf/E-instance as its mutants: accepted.** D6 predicted no code change. My own painter-side mutant (O2) kills it too.
5. **(6b) The context handle is still carried below the root, though unused there: accepted.** It is harmless, and removing it is a refactor.

## 3. Gates (CI=true, at 4c7eca3, rerun here)

- **Engine.** `00:17 +1225 -2: Some tests failed.` The 2 failures are the standing `generate_document_test.dart` ones:
  - `the default document is the one Plan 2 measured, byte for byte [E]`
  - `both text fractions default to zero and change nothing [E]`

  `No issues found!`; `Formatted 168 files (0 changed) in 0.63 seconds.`
- **Render.** `01:04 +1187 ~1 -7: Some tests failed.`
  - The 7 failures are the standing ones:
    - `text_ladder_golden_test.dart: text ladder rung 1..5 (RenderBackend.canvas) [E]`
    - `text_lod_ladder_golden_test.dart: text lod ladder rung 1..2 (RenderBackend.canvas) [E]`
  - The skip is the `rig`-tagged test (`Skip: run explicitly: flutter test --tags rig --run-skipped`).
  - 1187 = 1175 + 4 (6b) + 8 (Task 7: 3 draw tools, 1 canvas, 3 tile, 1 export).

  `No issues found! (ran in 1.7s)`; `Formatted 208 files (0 changed) in 0.68 seconds.`
- **App.** `03:12 +934: All tests passed!`; `No issues found! (ran in 1.6s)`; `Formatted 165 files (0 changed) in 0.76 seconds.`
- **dev_harness_2d analyze.** `No issues found! (ran in 1.0s)`.
- **Invariant tests.** `git diff --stat main(7330c7b) 4c7eca3 -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants` is empty. No PNG changed between 3a3286b and 4c7eca3.

## 4. Mutants (real lines; `diff=0` after every restore)

| id | mutation | test | real output |
|---|---|---|---|
| M-LP-22 | reference_walk.dart `_hidden` → `false` | reference_walk_layer | `00:00 +1 -6: Some tests failed.` `Expected: not contains <25>` |
| V4 | reference_walk.dart `?.visible ?? true` → `?? false` | reference_walk_layer | `00:00 +6 -1: Some tests failed.` `Expected: contains <27>` |
| R-below | reference_walk.dart `final root = depth == 0;` → `const root = true;` | reference_walk_layer | `00:00 +6 -1: Some tests failed.` `Expected: contains <31>` |
| Outline root gate | outline_cache.dart `acceptsNode(key.target, …)` → `… && false` | outline_layer | `00:00 +7 -1: Some tests failed.` `Expected: empty Actual: [1190.0, 810.0, 1160.0, 870.0]` |
| V3 | outline_cache.dart `_addFill` boundary context → `ReservedHandles.layerZero` | outline_layer | `00:00 +7 -1: Some tests failed.` (arc lists differ) |
| M-LP-16 line | line_tool.dart `drawingLayer(ctx.document)` → `ReservedHandles.layerZero` | draw_tools_layer | `00:00 +1 -2: Some tests failed.` `Expected: <19> Actual: <1>` |
| M-LP-16 text | text_tool.dart same | draw_tools_layer | `00:00 +1 -2: Some tests failed.` `Expected: <19> Actual: <1>` |
| M-12e | tables.dart:562 `layers = TableSection(onMutated: _bump)` → `TableSection()` | canvas_layer | `00:00 +0 -1: Some tests failed.` `Expected: not contains <23> Actual: Set:[22, 23, 24, 26, …]` |
| M-LP-19 entity | layer_commands.dart:392 `SetEntityLayerCommand.capability` → `components` | tile_cache_layer | `00:00 +1 -2: Some tests failed.` `Expected: empty` |
| M-LP-19 instance | layer_commands.dart:431 `SetInstanceLayerCommand.capability` → `components` | tile_cache_layer | `00:00 +2 -1: Some tests failed.` `Expected: empty` |
| **U-undo (own)** | layer_commands.dart:392 `=> _restore ? Capability.components : Capability.geometry` (only the undo reports components) | tile_cache_layer | `00:00 +2 -1: Some tests failed.` `Expected: contains all of Set:[ … Actual: Set:[]` |
| **O1 (own, M-LP-1 at the frame)** | spatial_index.dart:245 `if (revision != _tablesRevision)` → `if (false)` | canvas_layer | `00:00 +0 -1: Some tests failed.` `Expected: not contains <23>` |
| **O2 (own)** | draft_painter.dart:373 instance query `QueryFilter.rendering()` → `QueryFilter.all()` | export_layer | `00:00 +0 -1: Some tests failed.` `Expected: <3> Actual: <2>` |
| **add-only bypass (own, engine)** | tables.dart:121 drop `onMutated?.call();` in `add` | whole engine suite | `00:18 +1223 -4: Some tests failed.` `tables_revision_test.dart: every table mutator bumps the revision and notifies [E]`, `… every section is wired, not just layers [E]` |

R-instance and R-attrib were not re-fired. R-below and M-LP-22 cover the root guard's two sides, and the implementer's lines for both are in task-7-report.md.

## 5. Non-degeneracy (P-6)

- **Draw tools.** Layers A (ACI 1), B (ACI 5, locked) and C (ACI 3, hidden), added by command. Clicks are at 7000+ world units. The current layer is non-zero, and the hidden case is a non-zero C.
- **Canvas.** LayerFixture: turned instances, ATTRIB on 0 under A, region with split handles, no ACI 7. The hidden layer is A (non-zero), and three non-A handles are asserted still visited.
- **Tile.** The instance is turned and translated, with its definition line on layer 0 (follows A by substitution). The lines are off the origin. A far line on locked B guards against a full flush.
- **Export.** Groups are asserted non-identity, three layers are distinct, a locked layer still plots, and the probe uses world → page positions through the accumulated transform.

## Findings

1. **(Info) The canvas test observes the visit hook, not the sink.**
   - Visits are a superset of emission, so the hide leg (absence) is sound and M-12e/O1 kill it.
   - The presence legs (non-vacuity, undo) would also pass for a painter that visited but stopped emitting. That failure mode is already covered by the differential and golden suites.
   - **Fix (optional, not required).** One comment line in the test stating that direction.
2. **(Info, for the results note) Record the M-12e `add`-only bypass as equivalent for the canvas test and killed by the engine's `tables_revision_test.dart` (two tests), not as a survivor.**
3. **(Info) The tile test's undo leg is pinned for the root line by U-undo.**
   - The instance's undo leg has the same assertion and the same command class split, so it was not separately mutated.
   - No action.
4. **(Info) Every deviation (1–5) is accepted as reasoned in §2.**
