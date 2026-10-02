# Task 3 brief — the index sees layer changes (spec D6 engine half, plan P-4) — preceded by 2b
Read common.md in this directory first and follow it. HEAD ab7a225. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/l3/.

## First, as its own commit: 2b (Task 2's review, test-only)
Read task-2-review.md findings 1-3 and add the tests they describe to packages/jet_cad_2d/test/document/layer_commands_test.dart:
1. layer 0's guards in layerIsEmpty and RemoveLayerCommand: set the current layer to A first (so the current-layer check does not mask it) and assert the refusal's reason names layer 0. Re-fire the reviewer's R1 and R2 (remove the layer-0 guard in each) -> red.
2. decision 7 as a transition (R-12b-4): hidden layer 0 as the effective current layer (stored current C, hidden) -> a recolour and a lock of layer 0 both apply. Re-fire R3 (refuse any SetLayerCommand with visible:false on the effective current layer) -> red.
3. SetLayerCommand.restore's name-collision guard: rename A to "Walls", add a layer named "A" directly to the table, undo() throws StateError, bytes unchanged, A still "Walls", undo still available. Re-fire R4 (drop the guard) -> red.
Commit `test(engine): Task 2 review follow-ups` (2b) before starting Task 3.

## Then plan Task 3 exactly
_reconcile skips a touched handle naming a record in tables.layers before _reconcileEntity (a removed/dangling handle still falls through, spec S-4); _beginQuery compares tables.mutationRevision and invalidates _filters, rebuildAll records it; plan P-4's effective layer (_effectiveLayer preallocated per depth beside _containerPath, acceptsEntityOnLayer / acceptsNodeOnLayer sharing the memo maps, the ATTRIB rule in acceptsEntity with an _ownerLayer memo cleared by invalidate), applied at the instance leaf sites and nested-instance acceptsNode sites (spec cites spatial_index.dart:571, 587, 865, 881, 909 — verify on the branch and name each site in the report); test/support/layer_fixture.dart (P-6 engine half); test/index/layer_filter_test.dart with the plan's tests, including an allocation probe (steady-state zero allocations for a pick and a snap in the instance fixture, the query_allocation_test.dart pattern, in the NEW file — never edit the invariant tests).
Note from Task 2's review: SetLayerCommand is remove-then-add, so tables.changes fires twice with the record briefly missing; nothing you add may read the layer table synchronously inside a tables.changes callback.
Read first: lib/src/index/{query_filter,spatial_index}.dart whole regions around the cited lines; lib/src/document/style_resolver.dart contextFor (:96-165) for the substitution rule; test/invariants/query_allocation_test.dart for the probe pattern; how ATTRIBs are owned (node.dart:148-151) and indexed.
Mutants: M-LP-1 (the direct-write case), M-LP-2, M-LP-14 (pick, snap, band, one-level instead of recursive), M-LP-23, M-LP-24. Gates: all packages.
