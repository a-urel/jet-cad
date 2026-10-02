# Task 6 report (5b + selection, outline, oracle)

## 5b — commit 5b1c912 `test(engine): Task 5 review follow-ups`
- packages/jet_cad_2d/test/parametric/object_layer_test.dart: OL3b (region object on A, every boundary set to layer 0 directly, save/load, a RegionRect edit; asserts the split state after load and every child on A after the edit), OL9b (Pin on A hosted by a Post on B; deleting the Post cascades the Pin; ObjectLayer gone, undo restores state exactly, redo detaches again). `_Scene.over` added to read a reloaded doc with the scene's layers.
- packages/jet_cad_2d/lib/src/parametric/parametric_system.dart: Generated comment restored ("Each defaults…" after "…object's life."), layer paragraph its own block, 80 cols.
- Engine gate: `00:17 +1225 -2: Some tests failed.` (the 2 standing generate_document tests; 1223 + 2 new). analyze `No issues found!`; format `Formatted 168 files (0 changed) in 0.61 seconds.`

| id | mutation | red test | real output |
|---|---|---|---|
| R4 | regeneration.dart:594 boundary stamp guarded on the fill's layer | OL3b | `00:00 +13 -1: Some tests failed.` / `Expected: <18> Actual: <1>` |
| M-LP-11 | regeneration.dart:981 drop cleanup `..._detachLayer(t, h),` | OL9, OL9b | `00:00 +12 -2: Some tests failed.` OL9b `Expected: null Actual: ObjectLayer:<ObjectLayer(12)>` |
diff after each restore: 0.

## Task 6 — commits 0473696 `feat(render): selection, outline and oracle follow layers`, 3a3286b `test(render): pin the nested-instance and hidden-instance rules`

Files:
- packages/jet_cad_2d_flutter/lib/src/selection.dart: `_onChange` also drops a key / the hover failing `_selectable`; `_effectiveLayerOf(key)`: context layer 0 down the key's chain (O(chain), no allocation); InstanceNode -> own (or context if 0); GroupNode -> engine `objectLayer`; entity -> a fill redirects to its boundary's slot (`boundaryHandleOf`), own layer, or if 0 the owning instance's (ATTRIB), else context. A layer missing from the table counts as visible and unlocked (FilterEvaluator's rule).
- packages/jet_cad_2d_flutter/lib/src/outline_cache.dart: `context` handle threaded through `_addInstance/_addContainer/_addLeaf/_addFill`; leaves use `FilterEvaluator.acceptsEntityOnLayer(slot, rendering, context)` (the engine's public method, which substitutes inside: own, else ATTRIB owner, else context); nested instances are gated by `acceptsNodeOnLayer(child, rendering, context)` and recursed with `own==0 ? context : own`. A root instance key starts at its own layer; a group key and a leaf key at layer 0. No per-entity allocation added (a Handle passed down).
- packages/jet_cad_2d_flutter/lib/src/reference_walk.dart: P-5 by its own recursion: `container(..., Handle layer)`; each `_Item` carries the effective layer it is placed through (an ATTRIB its instance's); a leaf is skipped when `own==0 ? context : own` is hidden, an instance likewise, and its definition is walked with its effective layer. Table read each time, no memo, no index.
- packages/jet_cad_2d_flutter/test/support/layer_fixture.dart (new): mirrors the engine fixture (A ACI 1, B ACI 5 locked, C ACI 3 hidden; turned group with lines on 0/A/B/C; Table/Leg symbol on layer 0, instance on A with ATTRIB on 0; circle region on A) plus root lines on 0 and A and an "object": a turned root group carrying `ObjectLayer(A)` with a polyline child on A.
- test/layers/selection_prune_test.dart (10), outline_layer_test.dart (6), reference_walk_layer_test.dart (5).

Gates (CI=true, real tails):
- engine: `00:17 +1225 -2: Some tests failed.` (the 2 standing: `the default document is the one Plan 2 measured, byte for byte`, `both text fractions default to zero and change nothing`); `No issues found!`; `Formatted 168 files (0 changed) in 0.59 seconds.`
- render at 0473696: `00:56 +1174 ~1 -7: Some tests failed.`; at 3a3286b: `00:58 +1175 ~1 -7: Some tests failed.` The 7 are the standing text ladder rungs 1-5 and text lod ladder rungs 1-2 (RenderBackend.canvas). analyze `No issues found! (ran in 1.5s)`; format `Formatted 204 files (0 changed) in 0.63 seconds.`
- app: `03:11 +934: All tests passed!`; `No issues found! (ran in 1.8s)`; `Formatted 165 files (0 changed) in 0.81 seconds.`
- dev_harness_2d analyze: `No issues found! (ran in 1.1s)`.
- `git diff --stat 04a14b3 -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants` empty. No golden touched. analysis_options.yaml never staged (git status clean after each commit).

Mutants (runner scratchpad/l6/mut.py: cp backup, one unique exact-string replacement, named test file in the foreground, cp back, diff printed; every one `diff= 0`):

| id | file / mutation | test | real output |
|---|---|---|---|
| M-LP-15 (keys) | selection.dart `final dead = !_resolves(k) \|\| !_selectable(k);` -> `!_resolves(k)` | selection_prune | `00:00 +4 -6: Some tests failed.` e.g. `hiding A drops every key on A ... [E]` |
| M-LP-15 (hover) | selection.dart hover: drop `\|\| !_selectable(_hover!)` | selection_prune | `00:00 +9 -1: Some tests failed.` `the hover is dropped ... [E]` `Expected: null Actual: SelectionKey:<SelectionKey( 24)>` |
| O-fill | selection.dart: fill not redirected to its boundary | selection_prune | `00:00 +8 -2: Some tests failed.` both region tests |
| O-attrib | selection.dart: layer-0 leaf owned by an instance -> context | selection_prune | 4+ red, incl. `hiding layer 0 drops the root entity ... [E]` |
| O-group | selection.dart: drop the GroupNode/objectLayer branch | selection_prune | red, incl. `moving the object to the locked layer drops its group key [E]` |
| O-missing | selection.dart: a missing layer counts as unusable | selection_prune | `00:00 +9 -1: Some tests failed.` `a key on a layer the table does not have is kept [E]` |
| M-LP-14 (outline) | outline_cache.dart `_addLeaf`: `acceptsEntityOnLayer(slot, rendering, context)` -> `acceptsEntity(slot, rendering)` | outline_layer | `00:00 +3 -2: Some tests failed.` layer-0-hidden test `Actual: []`; A-hidden test `Expected: empty Actual: [1190.0, 810.0, 1160.0, 870.0]` |
| M-LP-14 (outline, recursion: one level) | outline_cache.dart nested recursion `_onLayer(node.layer, context)` -> `node.layer` | outline_layer | `00:00 +4 -1: Some tests failed.` (leg line missing) |
| O-root-instance | outline_cache.dart root instance key starts at layer 0, not its own | outline_layer | `00:00 +3 -2: Some tests failed.` |
| O-nested-context | outline_cache.dart `acceptsNodeOnLayer(child, rendering, context)` -> `..., layerZero` | outline_layer | `00:00 +5 -1: Some tests failed.` |
| O-nested-node | outline_cache.dart drop the nested `acceptsNodeOnLayer` gate | outline_layer | first SURVIVED `00:00 +5: All tests passed!` (a layer-0 leaf under a hidden nested instance is dropped by context anyway); after 3a3286b's test (leg line on B, nested on C) RED `00:00 +5 -1: Some tests failed.` |
| M-LP-22 | reference_walk.dart `_hidden` -> `false` | reference_walk_layer | `00:00 +1 -4` the absolute assertions: `Expected: not contains <25> Actual: Set:[22, 23, ...]` (lineC in the reference sink) |
| R-leaf | reference_walk.dart drop the leaf skip | reference_walk_layer | 4 red |
| R-instance | reference_walk.dart drop the instance skip | reference_walk_layer | first SURVIVED `00:00 +5: All tests passed!`; after 3a3286b (leg line on visible B inside the instance moved to C) RED `00:00 +4 -1` `Expected: not contains <31>` |
| R-attrib | reference_walk.dart ATTRIB placed through the container's layer, not its instance's | reference_walk_layer | `00:00 +2 -3: Some tests failed.` |
| R-recursion | reference_walk.dart definition walked with `node.layer` instead of the effective layer | reference_walk_layer | `00:00 +4 -1` `layer 0 hidden: ... [E]` (leg line missing) |

M-LP-22 note: at first the differential check ran before the absolute assertions and named the mutant by "the painter missed N reference ops"; 3a3286b moved the differential check after them, so the absolute assertion (spec: "the absolute assertion must go red") is what goes red.

## Decisions, and what the spec/plan got wrong or left open

1. **The oracle inside definitions is stricter than the painter (brief vs spec D6).** The brief and P-5 ask the oracle to skip contained leaves and nested instances by their effective layer; spec D6 keeps the painter's definition walk unfiltered and records the residual "a definition leaf on a non-zero hidden layer still draws". The two disagree exactly in that residual state. Verified with a scratch test (deleted): nested instance moved to hidden C inside the visible instance on A -> `painter has leg: true; reference has leg: false`, and the superset check fails `the painter drew polyline(780.00,72.99)(773.01,67.02) inside the view and the reference did not`. No committed fixture reaches that state (library symbols keep every leaf on layer 0). I followed the brief. If the controller prefers the oracle to mirror the residual, the change is to pass the context down without the two skips inside a definition (depth > 0); say so and I or Task 7 can flip it.
2. **The selection's parametric object is any GroupNode key, read through `objectLayer`.** The render package registers no parametric type and cannot tell a parametric group from a plain one; the test uses `ObjectLayer` on a plain root group (the brief's second option). Consequence (residual, file-only): a plain group with no `ObjectLayer` counts as layer 0, so hiding or locking layer 0 drops it from the selection even when its children are on a visible layer. D12 already treats a plain group as file-only (the picker disables).
3. **ATTRIB keys.** `resolveHit` gives an ATTRIB its own root key (its owner is the instance, not a group). D8 lists "a root entity's own" only; I gave a layer-0 ATTRIB its instance's layer, matching `acceptsEntity`'s S-2 rule, so the selection prunes exactly what picking can no longer reach. Pinned by O-attrib.
4. **A region key's fill on a hidden layer with its boundary visible is kept** (D8: a region's layer is its boundary's). Picking would not reach that fill (its own layer is tested), but D12 makes the state file-only. Pinned by a test as the spec's rule.
5. **The outline now gates nested instances with `acceptsNodeOnLayer`.** Before this task the outline never filtered nested instances; now a nested instance on a hidden layer drops its contents from the outline, as picking does (the painter still draws them: the same residual as point 1). Pinned by O-nested-node.
6. **Chain keys** (no task produces one): the effective layer is computed down the chain anyway; `_resolves` already guarantees every chain entry is an InstanceNode before the cast.
