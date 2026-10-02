# Task 3 review (with 2b): the index sees layer changes

Reviewer: independent agent, detached worktree `.claude/worktrees/plan-12b-review` at `af87621` (base `ab7a225`;
commits `582f78b` 2b, `f5998db`, `af87621`). Scratch: `.../scratchpad/r3/`. The runner `mut.py` takes a cp backup,
applies one exact-string mutation (asserted unique), runs the named test file in the foreground, copies the backup
back and prints the `diff` exit code. Two temporary files were used and removed: a probe test and a trial of the fix
for finding 1, restored by cp with `diff=0`. `git status --short` was empty at the end, and no analysis_options.yaml
was touched.

## Verdict: **Approved with notes**

The design matches D6, P-4 and S-2/S-4/S-7. Every named mutant and all four 2b mutants go red. The frame path gains
no per-entity allocation, and the invariant tests are unedited and green. There is one real regression, reachable
only from a malformed document (finding 1), and two test gaps (findings 2–3). All three are cheap. I recommend
landing them as a small test-and-guard commit "3b" before Task 6/9 build on this, the same way 2b was handled.

## Gates (re-run here, CI=true, real tails)

- engine `dart test`: `00:18 +1204 -2: Some tests failed.`. The 2 failures are the standing ones:
  `generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte [E]` and
  `... both text fractions default to zero and change nothing [E]`. `dart analyze`: `No issues found!`. Format:
  `Formatted 167 files (0 changed) in 0.65 seconds.`
- render `flutter test`: `01:03 +1154 ~1 -7: Some tests failed.`. The 7 failures are text ladder rungs 1–5 and text
  lod ladder rungs 1–2 (canvas). analyze `No issues found! (ran in 1.6s)`; format `Formatted 200 files (0 changed)`.
- app: `03:22 +934: All tests passed!`; `No issues found! (ran in 1.8s)`; `Formatted 165 files (0 changed)`.
- dev_harness_2d analyze: `No issues found! (ran in 1.3s)`.
- `git diff main af87621 --stat -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants`
  is empty (exit 0). Both invariant tests are inside the green counts above.

## Diff check

- **Revision check.** All six public query entry points call `_beginQuery`: `forEachInRect` :315,
  `forEachInstanceInRect` :343, `forEachLeafInBand` :394, `forEachInstanceInBand` :449, `pickInto` :795 and
  `snapInto` :1527. `_considerIntersections` (:1616) runs inside `snapInto`. No query reaches `_filters` without
  passing through `_beginQuery`. The painter's root queries go through the index.
- **Evaluators outside the index.** Two exist, and neither goes stale:
  - `select_tool.dart:468` builds a fresh evaluator per band.
  - `outline_cache.dart:377` keeps one per walk and drops it with the walk (:236, :241). It now inherits the ATTRIB
    rule through `acceptsEntity`. Its instance walk is Task 6's half (plan Task 6, M-LP-14 outline).
- **`Handle` is an `extension type`**, so `Handle(_effectiveLayer[depth])` allocates nothing.
- **`_tablesRevision = -1`.** The first query invalidates once, which is harmless. A load goes through `rebuildAll`,
  which records the revision.
- **P-4 vs the resolver.** `_effectiveBelow` gives an instance's own layer, or the parent depth's when its own is
  layer 0. That is exactly `contextFor`'s `node.layer == layerZero ? inherited.layer : node.layer`
  (style_resolver.dart:104-105). The leaf rule `layer == 0 ? context : layer` is `styleFor` (:177-178). Each site
  checks out:
  - Depth 0 is written as layer 0 in `pickInto`, `snapInto` and `forEachInstanceInBand`.
  - The band root writes `[1]`.
  - `_descend` and `_bandDescend` write `[depth+1]` after `_ensurePathCapacity(depth+1)` and before recursing.
  - `context` is read once per container visit, before the loop that writes `depth+1`, so it is not overwritten.
- **Depth-array growth.** `_effectiveLayer` grows inside `_ensurePathCapacity` alongside `_instancePath` and
  `_containerPath` (same capacity, `setAll` copy). It grows only on a new maximum depth, never per query. The band
  root now asks for capacity 1 instead of 0, which is needed for the `[1]` write.
- **ATTRIB rule.** An ATTRIB owned by an instance is indexed in the container holding that instance
  (`container_index.dart:207-224`), as a leaf transformed by the placement. So the leaf path is the right place for
  the rule, and the rule "owner's non-zero layer, else context" equals the owner's effective layer at every depth.
- **`_ownerLayer` staleness.** I verified the claim:
  - The only writer of an instance's layer is `SetInstanceLayerCommand` (`layer_commands.dart:446`; `grep
    replaceNode(` finds only that and `TransformNodeCommand`, which keeps the layer). Its `capability` is
    `geometry`, not `components`, so `_onChange` does not return early. Its `touched` is `{node}`, the node
    resolves, so `structural` triggers `rebuildAll`, which calls `invalidate`.
  - Its undo is the restore form, and the same reasoning applies.
  - `ParametricReplay.capability` is `replay.capability`, the highest of its children, so a replay that ever held
    one would still be `geometry`.
  - `TransformNodeCommand` touches a node and also rebuilds.
  - An instance whose layer changes without a rebuild is possible only through a direct `tree.replaceNode` with no
    command. That leaves the boxes and `_containerVisible` just as stale (pre-existing), so it is not new.
  - Mutant O4 (drop `_ownerLayer.clear()`) goes red.
- **Frame cost.** No allocation is added:
  - `context` is captured by closures that already existed.
  - A map write happens only on a memo miss.
  - The per-query cost is one int compare plus 1–2 array writes per descent.
  - Per leaf, one int compare. A layer-0 leaf whose owner is not the root also pays one `_ownerLayer` hit. That
    covers every parametric object's generated children (group leaves), so the rendering pass now does two map hits
    per such leaf instead of one. The spec allows this (S-2, "memoised per owner as `_containerVisible` is").
    Info only (note 5).

## Findings

1. **Minor (real regression on a malformed document).** `_reconcile`'s skip fires for any handle that names a layer
   record, before the entity and node checks. Handles are unique only by convention:
   - `AddEntityCommand` (commands.dart:54) and `AddNodeCommand` (:353) do not check the tables.
   - The JSON loader only raises the seed (json_codec.dart `_loadTables`).
   - `validate()` does not diagnose a collision between a table handle and an entity handle.

   In a document where a layer record shares an entity's handle, an edit to that entity is now skipped, and the
   index stays stale with no diagnostic. Before this diff, `_reconcileEntity` handled it correctly.

   **Demonstrated** with a scratch probe test, since deleted. It used the fixture, a layer record added at `lineA`'s
   handle, and `SetEntityGeometryCommand` moving lineA:
   `stale index at new place: false rebuilds=1` / `fresh index at new place: true` / `validate: []`.

   **Fix.** Only skip a handle that is purely a layer:
   ```dart
   if (document.tables.layers[handle] != null &&
       !document.entities.containsHandle(handle) &&
       _lastKnownSlot[handle] == null &&
       document.tree[handle] == null &&
       document.tree.definition(handle) == null) {
     continue;
   }
   ```
   These are hash lookups per touched handle, not per frame. Trialled here: the probe printed
   `stale index at new place: true rebuilds=1`, and `layer_filter_test.dart` + probe gave `00:01 +18: All tests
   passed!`. Restored with `diff=0`.

   Land the probe as a regression test. Mutant: drop the `containsHandle` conjunct, and the test must go red.
   M-LP-2 keeps passing with the guard because a real layer handle passes every conjunct.
2. **Minor (test gap; mutant survives).** The implementer extended the ATTRIB rule to ATTRIBs owned by a *nested*
   instance (report decision 2). That branch is untested. Mutant O1 drops `&& ownLayer !=
   ReservedHandles.layerZero` in `acceptsEntityOnLayer`, so an owner on layer 0 pins the ATTRIB to layer 0 instead
   of the context. It **survived**: `00:01 +17: All tests passed!`.

   The branch is reachable: an ATTRIB owned by `nested` (inside `Table`) is a leaf of `Table`'s container.

   **Fix.** In `layer_filter_test.dart`, add a layer-0 ATTRIB owned by `f.nested`, at a non-origin instance-local
   point. Hide layer 0, then assert it is still picked and drawn through the instance on A. O1 must go red.
3. **Minor (test gap; mutant survives).** Mutant O2 uses `_lockedLayer(resolved.layer)` instead of
   `_lockedLayer(layer)` in `acceptsNodeOnLayer`, which means no lock substitution for nested instances. It
   **survived**: `00:01 +17: All tests passed!`.

   The fixture cannot show it: every symbol leaf is on layer 0, so each leaf's own test hides the node-level miss.
   Mutant O5, the visibility twin, is caught.

   **Fix.** In the test, not the shared fixture: put a line on a fresh unlocked layer `D` in `Leg`. Lock `A`, then
   assert a pick on that line is null, because the nested instance on layer 0 follows the locked `A` and is pruned
   whole. O2 must go red.

Notes (no action):

4. Mutant O6 (`rebuildAll` does not record `_tablesRevision`) survives. It is equivalent apart from cost: the
   next query repeats one `invalidate()`.
5. The extra `_ownerLayer` hit for layer-0 group leaves on the render pass is a map lookup and no allocation, within
   the spec. If a later benchmark asks for it, the owner memo and `_containerVisible` could share one per-owner
   entry.
6. `Handle(0)` as the array's initial value is fine. The af87621 tests pin every write: T3c, T3e and T3f were
   re-checked by reading the tests, not re-fired.

## Mutants re-fired here (layer_filter_test.dart unless noted; every one `diff= 0`)

| id | mutation | result |
|---|---|---|
| M-LP-1 | `_beginQuery`: `if (revision != _tablesRevision) {` → `if (false) {` | RED `00:00 +0 -1: ... a layer hidden by a direct table write after a query is excluded ... (M-LP-1) [E]` (`00:01 +12 -5`) |
| M-LP-2 | drop `if (document.tables.layers[handle] != null) continue;` | RED `00:00 +3 -1: ... cost the index no rebuild (M-LP-2) [E]`, `00:00 +3 -2: ... rebuilds once: the undo of an add (S-4) [E]` |
| M-LP-14 pick | `visitLeaf` → `acceptsEntity(slot, filter)` | RED `00:00 +6 -1: ... with layer 0 hidden, picking reaches every level of the instance [E]` (+ snap, band-then-pick, probe) |
| M-LP-14 snap | `visitSnapCentre` → `acceptsEntity` | RED `00:00 +7 -1: ... with layer 0 hidden, snapping reaches every level of the instance [E]` |
| M-LP-14 band | `_bandDescend` leaf → `acceptsEntity` | RED `00:00 +8 -1: ... with layer 0 hidden, a band selects the instance through its leaves [E]` |
| M-LP-14 one level | `_effectiveBelow`: `? _effectiveLayer[depth]` → `? ReservedHandles.layerZero.value` | RED `00:00 +6 -1: ... picking reaches every level ... [E]` (+ snapping, band, band-then-pick; `00:00 +11 -6`) |
| M-LP-23 | ATTRIB: `owner == document.rootHandle ? Handle.none : _instanceLayer(owner)` → `Handle.none` | RED `00:00 +5 -1: ... the instance on A is still drawn, and so is its ATTRIB ... [E]` (+ pick, hide A, lock A) |
| M-LP-24 descend | `_descend` nested → `acceptsNode(node, filter)` | RED `00:00 +6 -1: ... picking reaches every level ... [E]` (+ snapping, band-then-pick, pick probe) |
| M-LP-24 band | `_bandDescend` nested → `acceptsNode(node, filter)` | RED `00:00 +8 -1: ... a band selects the instance through its leaves [E]` |
| R1 (layer_commands_test) | drop `if (layer == ReservedHandles.layerZero) return false;` in `layerIsEmpty` | RED `00:00 +15 -1: RemoveLayerCommand layer 0 is never empty and never deleted, even when it is not the current layer (Task 2 review R1, R2) [E]` |
| R3 (layer_commands_test) | drop `old.visible &&` | RED `00:00 +22 -1: SetLayerCommand a hidden layer 0 as the effective current layer can be recoloured and locked (decision 7 is a transition, R-12b-4) [E]` |
| R4 (layer_commands_test) | `holder.handle != handle` → `holder.handle == Handle(0)` | RED `00:00 +23 -1: SetLayerCommand the restore form refuses a name another layer took since, and keeps the record (Task 2 review R4) [E]` |
| O1 (own) | ATTRIB: drop `&& ownLayer != ReservedHandles.layerZero` | **SURVIVED** `00:01 +17: All tests passed!` → finding 2 |
| O2 (own) | `acceptsNodeOnLayer`: `_lockedLayer(layer)` → `_lockedLayer(resolved.layer)` | **SURVIVED** `00:01 +17: All tests passed!` → finding 3 |
| O3 (own) | `acceptsEntityOnLayer`: lock test on the stored layer, not the substituted one | RED `00:00 +12 -1: ... locking A makes its ATTRIB unpickable and keeps it snappable [E]` |
| O4 (own) | `invalidate()`: drop `_ownerLayer.clear();` | RED `00:00 +13 -1: ... moving the instance to a hidden layer takes its ATTRIB along; the undo brings both back [E]` |
| O5 (own) | `acceptsNodeOnLayer`: `_visibleLayer(layer)` → `_visibleLayer(resolved.layer)` | RED `00:00 +6 -1: ... picking reaches every level ... [E]` (`00:00 +11 -6`) |
| O6 (own) | `rebuildAll`: drop `_tablesRevision = ...` | SURVIVED `00:01 +17: All tests passed!` (equivalent apart from cost, note 4) |

## Rulings on the implementer's points

- **(1) Probe uses budgets, not literal zero: confirmed (R-12b-5).** `_descend` already allocates one `Aabb2` and one
  `Transform2` per level, and `query_allocation_test.dart` budgets exactly those. `vm_allocation_meter.dart`'s own
  header (failure mode 1) documents why a class built in bulk elsewhere, such as `_Uint32List`, cannot be watched.
  The new path's frame-relevant regression (a dropped cache re-allocating the `_Set`) is watched at 0.5 per call,
  and T3b proves the probe catches it. By reading the code, the depth array is preallocated and grown only on a new
  maximum depth. That meets the spec's "no allocation per entity or per query".
- **(2) ATTRIB rule in the shared leaf path: confirmed.** It equals S-2 at the root, where the context is layer 0 and
  `acceptsEntity` is unchanged in meaning. It is also the correct generalisation for an ATTRIB of a nested instance,
  which is indexed as a definition-container leaf. The spec's "owner's effective layer" needs the walk's context
  there. The extension needs its own test (finding 2).
- **(4) The memo relies on rebuilds: confirmed (R-12b-6).** `SetInstanceLayerCommand` and its undo touch the node,
  and a node handle makes the reconcile structural, so `rebuildAll` runs and calls `invalidate`. No other command
  rewrites an instance's layer. The cost is acceptable: moving an instance to another layer is rare, and it already
  rebuilt before this task.

## Tests and fixture (P-6)

The fixture is not degenerate:
- A, B and C are ACI 1, 5 and 3; B is locked and C hidden; layer 0 is visible. No colour is ACI 7.
- The group transform is rotated π/6 and translated (500, −300). The instance is rotated π/2 at (1200, 800). The
  nested instance is rotated 0.4 at (60, −25). Definition base points are off the origin.
- Every probe point is a world point through those transforms. The region is at (−600, 420).
- The hidden layer is C. Layer 0 is hidden only in the substitution tests, which are about layer 0, through decision
  7's legal route (A made current first).
- The ATTRIB is laid out with `MetricModelMeasurer`, so it has a real glyph box.

Every test has a named mutant that turns it red, except as noted in findings 2 and 3. The `af87621` tests close
T3c/T3e/T3f by first leaving a hidden or locked layer in the depth array. That is the right way to defeat the
zero-initialised array's degenerate default.
