# Task 6 review (5b + selection, outline, oracle)

Reviewer worktree: `.claude/worktrees/plan-12b-review`, detached at 3a3286b (base 04a14b3; commits 5b1c912 = 5b, 0473696, 3a3286b). The tree was clean before and after the review: `git status --short` was empty and no analysis_options rewrites appeared. Mutants were done by cp backup with a one-string replacement, run against the named test file in the foreground, then cp back, and `diff` printed 0 every time. The scratch tests were moved out of the tree once they had run. They are kept in `scratchpad/r6-12b/` (`zz_review_residual_test.dart`, `zz_review_gaps_test.dart`) along with the runner `mut.py`.

## Verdict: **Approved with notes**

The selection pruning, the outline's effective layer and the 5b follow-ups have no product defect. 6b is required: R-12b-7 (finding 1) is confirmed, and 6b should also take findings 2–4, which are small.

## 1. Diff review

### 5b (5b1c912)

- OL3b builds the split state from a file: boundaries on 0, fills on A. It survives save and load, asserts the split after the load, then edits and expects every child on A.
- OL9b covers the cascade-loss path, with undo and redo compared by `state(...)`.
- The `Generated` comment is restored. "Each defaults…" now follows "…object's life.", the layer paragraph is its own block, and it is wrapped at 80 columns.

### `SelectionController` (selection.dart)

- **Every DocChange kind.**
  - `DocumentLoaded` and `DocumentPurged` still `clear()`.
  - Every other change, undo and redo included, runs `_resolves(k) || _selectable(k)` per key, with short-circuit order, so `_effectiveLayerOf` only sees a resolving key. The `as InstanceNode` cast on the chain and the `slotOf(...)!` are therefore safe.
  - Undo of a layer move does not bring a key back. That is correct: the selection is not undone, and this is pinned.
- **Hover.** The hover is pruned by the same predicate (R-14), and `changed` is set. A scratch check confirmed that an ATTRIB hover is dropped on a *hide* of A, not only on a lock.
- **Region by boundary.**
  - A fill key redirects to `boundaryHandleOf(payload)`'s slot. If the boundary is missing, the fill's own slot is used.
  - The boundary's own layer is then used, with the ATTRIB rule if an instance owns it. That matches D8/D12.
- **ATTRIB.**
  - A layer-0 leaf owned by an `InstanceNode` uses `_onLayer(owner.layer, context)`. This is exactly `acceptsEntityOnLayer`'s rule (own if non-zero, else context), so the selection prunes exactly what a pick can no longer reach.
  - A non-zero ATTRIB keeps its own layer, as the engine does.
- **Group keys.** A group key uses `objectLayer(document, key)`. A missing `ObjectLayer` gives 0, and a ghost layer gives 0 too (R-9). That matches the stamp, which regenerates such an object on 0.
- **R-12b-8 ruling: accepted.**
  - The render package cannot tell a parametric group from a plain one.
  - A plain group is file-only, and D12 disables the picker for it.
  - Counting it as layer 0 is the only rule available that needs no registry.
- **Cost.**
  - The cost is O(selection × chain). Each key does a map lookup on the tables, one `objectLayer` component read, or one `boundaryHandleOf` peek.
  - There is no per-entity work and no allocation beyond the `Handle(h)` wrapper on the (always empty) chain.
  - This path is not the frame path.
- **Notifies only on a change.**
  - `changed = changed || dead` notifies only when something was removed, and the hover likewise. The "recolour / show C / move an unnamed line" test asserts `notified == 0`.
  - My mutant V2 (last-wins `changed = dead`) shows the order matters, and it is killed.
- **Pruning during a drag.**
  - `GripDrag.move/rotate/reshape` snapshot `selection.keys` at `_beginDrag`, and the command is built from the drag.
  - Keys do not reach the shell during a drag (select_tool's comment at `_liveIndexOf`).
  - A press inside the slop that loses its key to a cmd+Z is already handled: `_liveIndexOf` returns -1, and `pivot == null` gives click-only.
  - The selection only receives keys through picking and the band, which already filter on `picking()`. So a prune can only happen on a real layer change. I found no path where pruning breaks a tool or a grip.
- **Info.** A direct `TableSection` write emits no DocChange, so it does not prune. The plan's global constraint (every layer change goes through a command) makes that unreachable from the app.

### `OutlineCache`

- **Context threading.**
  - The context is passed as a `Handle` argument, with no per-entity allocation.
  - The `FilterEvaluator` is still built once per `_walk` and dropped after it, so its memo never goes stale across a hide.
- **Leaves.** Leaves use `acceptsEntityOnLayer(slot, rendering, context)`.
- **Nested instances.** They are gated by `acceptsNodeOnLayer(child, rendering, context)` and recursed with `own == 0 ? context : own`. This is the index's P-4 rule (own, else context, recursively; ATTRIB through `_ownerLayer`).
- **Group and root leaf keys.** These start at context 0. That is correct: a root key's context is the root.
- **The root instance key is not gated by its own effective layer.** See finding 2.

### `reference_walk`

The implementation is an independent recursion, and it follows the brief: each `_Item` carries the context, and an ATTRIB carries its instance's effective layer. Below the root, though, the oracle filters leaves and nested instances, and the painter does not. That is finding 1.

## 2. Ruling on R-12b-7 (controller: the oracle must match the painter below the root)

**The controller is right.** Drop the two skips below the root.

1. **Spec D6 is explicit.**
   - "The painter's definition walk stays unfiltered … Residual, recorded: a definition leaf on a non-zero hidden layer still draws."
   - The oracle bullet says only "skips a root-level leaf … and an instance whose effective layer is hidden".
   - The painter tests instances only at the root, through `forEachInstanceInRect(rendering)` (draft_painter.dart:373). `_drawContainer` and `_descend` (:438-523) apply no filter.
   - P-5 says "re-implements P-4's rule". P-4 is the index's rule for queries (pick, snap, band). It cannot override D6's explicit statement of what the painter, and therefore the oracle, does.
2. **Verified.** Scratch test `zz_review_residual_test.dart`: nested instance moved to C, and `tableCircle` moved to C, inside the visible instance on A.
   - `painter leg true circle true` / `reference leg false circle false`.
   - `expectPainterSupersetOfReference` fails with: `the painter drew circle(764.19,111.09) r=2.47 inside the view and the reference did not — that is a wrong drawing, not loose culling`.
3. **No reason to keep the skips.**
   - The differential is one-directional (painter ⊇ reference). An oracle that is stricter than the painter catches nothing extra; it can only raise a false red in a spec-sanctioned state.
   - The real guard against "hidden content drawn" is R-18's absolute assertion, and that stays.
   - If the residual is ever closed, painter and oracle change together, in the same task.
4. **What 6b should do.**
   - In `container` at `depth > 0`, skip neither leaves nor nested instances. The context then only matters at the root.
   - Keep at the root:
     - the root-leaf skip;
     - the ATTRIB-by-instance skip (root ATTRIBs, under groups too);
     - the root-instance skip.
   - Add a test pinning painter == oracle in the residual state: nested instance on C, plus a definition leaf on C.
     - Both sinks **contain** `legLine` and `tableCircle`, which pins the residual absolutely.
     - Then `agree()`.
   - The existing 3a3286b test (instance moved to C with the leg line on visible B) stays valid. It is the root-instance skip.
   - The R-recursion and R-leaf-inside mutants then no longer apply. Re-fire M-LP-22, R-instance and R-attrib.
5. **Implementer's point 5 (the outline drops a nested hidden instance; the painter draws it): accepted.**
   - D6 lists "`OutlineCache`'s instance walk" among the places a contained leaf or nested instance is filtered by the effective layer.
   - The outline marks what selection and picking reach, and picking gates nested instances by `acceptsNodeOnLayer` (S-7). The outline and picking agree, which is the property that matters for a highlight.
   - The state is file-only.
   - The `_addLeaf` comment ("skips exactly what the canvas skips") is now inaccurate in that state. 6b should name the residual there (finding 5).

## 3. Gates (CI=true, at 3a3286b, rerun here)

- **Engine.** `00:19 +1225 -2: Some tests failed.` The 2 failures are the standing ones:
  - `generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte`
  - `… both text fractions default to zero and change nothing`

  analyze: `No issues found!`. format: `Formatted 168 files (0 changed) in 0.78 seconds.`
- **Render.** `01:04 +1175 ~1 -7: Some tests failed.` The 7 failures are standing:
  - `text_ladder_golden_test.dart` rungs 1–5 (RenderBackend.canvas)
  - `text_lod_ladder_golden_test.dart` rungs 1–2 (RenderBackend.canvas)

  analyze: `No issues found! (ran in 1.6s)`. format: `Formatted 204 files (0 changed) in 0.69 seconds.`
- **App.** `03:19 +934: All tests passed!` analyze: `No issues found! (ran in 1.9s)`. format: `Formatted 165 files (0 changed) in 0.98 seconds.`
- **dev_harness_2d analyze.** `No issues found! (ran in 1.3s)`.
- **Invariant tests.** `git diff --stat` for both invariant directories against 04a14b3 and against main (7330c7b) is empty. No golden was touched.

## 4. Mutants (real lines; `diff= 0` after every restore)

| id | file / mutation | test | real output |
|---|---|---|---|
| R4 (5b) | regeneration.dart:594 boundary stamp guarded on `fills[i]`'s layer | object_layer_test | `00:00 +3 -1: OL3b … [E]` `Expected: <18> Actual: <1>`; `00:00 +13 -1: Some tests failed.` |
| M-LP-11 (OL9b) | regeneration.dart:981 drop `..._detachLayer(t, h),` | object_layer_test | `00:00 +10 -2: OL9b detach on cascade loss … [E]` `Expected: null Actual: ObjectLayer:<ObjectLayer(12)>` (and OL9); `00:00 +12 -2: Some tests failed.` |
| M-LP-15 keys | selection.dart `!_resolves(k) \|\| !_selectable(k)` → `!_resolves(k)` | selection_prune | `00:00 +4 -6: Some tests failed.` (e.g. `moving the object to the locked layer drops its group key [E]`, `Actual: Set:[SelectionKey( 1C), SelectionKey( 1B)]`) |
| M-LP-15 hover | selection.dart hover: drop `\|\| !_selectable(_hover!)` | selection_prune | `00:00 +8 -1: the hover is dropped … [E]` `Expected: null Actual: SelectionKey:<SelectionKey( 24)>`; `00:00 +9 -1` |
| M-LP-14 outline (substitution) | outline_cache.dart `_addLeaf`: `acceptsEntityOnLayer(slot, rendering, context)` → `acceptsEntity(slot, rendering)` | outline_layer | `00:00 +4 -2: Some tests failed.` layer-0-hidden `Actual: []`; A-hidden `Expected: empty Actual: [1190.0, 810.0, 1160.0, 870.0]` |
| M-LP-14 outline (one level) | outline_cache.dart nested recursion `_onLayer(node.layer, context)` → `node.layer` | outline_layer | `00:00 +5 -1: Some tests failed.` layer-0-hidden test, `Actual: [1190.0, 810.0, 1160.0, 870.0]` (leg line missing) |
| M-LP-22 | reference_walk.dart `_hidden` → `false` | reference_walk_layer | `00:00 +1 -4: Some tests failed.` e.g. `Expected: not contains <25> Actual: Set:[22, 23, 24, 25, …]` |
| V1 (own) | selection.dart `_selectable` ignores `locked` | selection_prune | `00:00 +6 -4: Some tests failed.` (lock, object, region, hover) |
| V2 (own) | selection.dart `changed = changed \|\| dead` → `changed = dead` | selection_prune | `00:00 +0 -1: hiding A drops every key … [E]` `Expected: <1> Actual: <0>`; `00:00 +9 -1` |
| **V3 (own)** | outline_cache.dart `_addFill`: boundary tested in context `layerZero` instead of `context` | outline_layer | **`00:00 +6: All tests passed!` (survives)**; killed by scratch `zz_review_gaps_test.dart` V3: `Expected: <10> Actual: <15>` |
| **V4 (own)** | reference_walk.dart missing layer counts as hidden (`?? true` → `?? false`) | reference_walk_layer | **`00:00 +5: All tests passed!` (survives)**; killed by scratch V4: `Expected: contains <27> Actual: Set:[22, 23, 24, 26, …]` |

The implementer's other mutants (O-fill, O-attrib, O-group, O-missing, O-root-instance, O-nested-context, O-nested-node, R-leaf, R-instance, R-attrib, R-recursion) were not re-fired. My V1 and V2 cover the predicate and the notify logic independently.

## 5. Non-degeneracy (P-6)

The render `LayerFixture` is not degenerate:

- **Layers.** A is ACI 1, B is ACI 5 and locked, C is ACI 3 and hidden. Layer 0 is visible and is hidden only in the layer-0 tests.
- **Transforms.** Every group, the object, the instance and the nested instance have non-identity, turned transforms. The fixture test asserts this.
- **Positions and base points.** Every line is off the origin, and the definitions' base points are off the origin.
- **Colours.** No ACI 7, and three distinct colours (asserted).
- **ATTRIB.** The ATTRIB sits on layer 0 under an instance on A, so the substitution is exercised rather than coinciding.
- **Region.** The region has distinct fill and boundary handles. The two region tests separate them (boundary on B; fill alone on C).
- **Outline assertions.** These compare exact world coordinates through two transform levels, so an identity placement would fail them.

There are two gaps (findings 3–4). Both are surviving mutants, not degenerate fixtures.

## Findings

1. **(Important, 6b) The oracle is stricter than the painter below the root (R-12b-7, confirmed).**
   - **Fix.** As in §2.4:
     - drop the leaf and nested-instance skips at depth > 0 and keep the root-level ones;
     - add the residual-agreement test with absolute `contains` on `legLine` and `tableCircle`;
     - re-fire M-LP-22, R-instance and R-attrib;
     - update the walk's doc comment to quote D6's residual.
2. **(Minor) `OutlineCache._outlinesFor`'s `InstanceNode` case does not gate the root instance by its own layer.**
   - **Problem.** A root instance on a hidden layer still outlines a definition leaf that sits on a visible non-zero layer. Scratch: `tableLine` on B, A hidden by a direct write, the instance key outlined → `segments [1190.0, 810.0, 1160.0, 870.0]`, `worldBoundsOf` non-null, while the painter draws nothing of it.
   - **Reach.** It is only reachable while a key is held without a DocChange, because the selection prunes otherwise. Root leaf keys are gated (`_addLeaf`); root instance keys are not.
   - **Fix.** Before `_addInstance` in that case:

     ```dart
     if (!(_filters ??= FilterEvaluator(document)).acceptsNode(key.target, const QueryFilter.rendering())) break;
     ```

     Add the scratch case as a test (`zz_review_residual_test.dart`, second test). Its mutant is dropping the gate.
3. **(Minor, test gap) V3 survives. No test has a region inside a definition.**
   - **Problem.** `_addFill`'s boundary test in the instance's context is unpinned.
   - **Fix.** Land `zz_review_gaps_test.dart`'s V3: a fill and boundary on 0 in `Table`, with layer 0 hidden and the instance on A. The arc count must equal the control, 10, where the mutant gives 15.
4. **(Minor, test gap) V4 survives. The oracle's "a missing layer is drawn" rule is unpinned.**
   - **Problem.** Because the differential is one-directional, an oracle that draws *less* is only caught by absolute `contains` assertions.
   - **Fix.** Land `zz_review_gaps_test.dart`'s V4: `rootA` moved to ghost `0x6A6A` is contained in both sinks.
5. **(Doc, 6b) `_addLeaf`'s comment is now false in the D6 residual.**
   - The comment says the outline "skips exactly what the canvas skips".
   - **Fix.** Add one sentence: inside a definition the outline follows picking (D6 lists the outline walk) and the painter does not filter, so a definition leaf or nested instance on a hidden layer is drawn but not outlined.
6. **(Info) Accepted rulings and decisions.**
   - R-12b-8 is accepted.
   - The implementer's decisions 2, 3, 4 and 6 are accepted. On 3, the ATTRIB key uses its instance's layer, which matches `acceptsEntity` (S-2).
   - A direct table write does not prune the selection, because there is no DocChange. That is unreachable from the app under the plan's global constraint.
