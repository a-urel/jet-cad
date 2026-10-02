# Task 3 report — the index sees layer changes (preceded by 2b)

Implementer: fresh agent. Worktree plan-12b, base ab7a225. Scratch: .../scratchpad/l3/ (runner mut.py: cp backup,
one exact-string mutation asserted unique, the named test file in the foreground, cp back, diff exit printed).

## 2b — Task 2 review follow-ups (commit 582f78b)

Three tests added to packages/jet_cad_2d/test/document/layer_commands_test.dart:
- `RemoveLayerCommand layer 0 is never empty and never deleted, even when it is not the current layer` (current = A;
  asserts layerIsEmpty(0) false and the exact message 'Layer 0 cannot be deleted.' — exact, since the in-use message
  'Layer 0 is in use and cannot be deleted.' would otherwise also match).
- `SetLayerCommand a hidden layer 0 as the effective current layer can be recoloured and locked` (stored current C
  hidden, layer 0 hidden by a direct table write).
- `SetLayerCommand the restore form refuses a name another layer took since, and keeps the record`.

Engine after 2b: `00:18 +1187 -2: Some tests failed.` (the 2 standing generate_document tests), analyze
`No issues found!`, format `Formatted 165 files (0 changed)`.

| id | mutation (layer_commands.dart) | result |
|---|---|---|
| R1 | layerIsEmpty: drop the layer 0 early return | RED `00:00 +15 -1: RemoveLayerCommand layer 0 is never empty and never deleted, ... (Task 2 review R1, R2) [E]` diff=0 |
| R2 | RemoveLayerCommand: layer 0 check -> `if (false) {` | RED `00:00 +15 -1: RemoveLayerCommand layer 0 is never empty and never deleted, ... [E]` diff=0 |
| R3 | decision 7: drop `old.visible &&` | RED `00:00 +22 -1: SetLayerCommand a hidden layer 0 as the effective current layer can be recoloured and locked ... [E]` diff=0 |
| R4 | restore holder check `holder.handle != handle` -> `== Handle(0)` | RED `00:00 +23 -1: SetLayerCommand the restore form refuses a name another layer took since ... [E]` diff=0 |

## Task 3 — commits f5998db (feature) and af87621 (test follow-up)

Files:
- `packages/jet_cad_2d/lib/src/index/query_filter.dart`: `acceptsEntityOnLayer(slot, filter, context)`,
  `acceptsNodeOnLayer(node, filter, context)`; `acceptsEntity` / `acceptsNode` are now those in the root context
  (`context` = layer 0). The ATTRIB rule lives in the one shared leaf path: a leaf on layer 0 not owned by the root
  looks up its owner in `_ownerLayer` (memo: the owner's own layer if it is an `InstanceNode`, else `Handle.none`);
  a non-zero owner layer wins, else `context`. `invalidate()` clears `_ownerLayer`. Class doc comment updated (the
  "no command can flip a layer" paragraph was stale).
- `packages/jet_cad_2d/lib/src/index/spatial_index.dart`: `_beginQuery` compares `document.tables.mutationRevision`
  with `_tablesRevision` and invalidates `_filters` when it moved; `rebuildAll` records it. `_reconcile` skips a
  touched handle with a record in `tables.layers` (first check in the loop). `_effectiveLayer` (`Uint32List`, grown
  with `_containerPath` in `_ensurePathCapacity`) plus `_effectiveBelow(instance, depth)`. Writes: `[0] = layer 0` in
  `pickInto`, `snapInto`, `forEachInstanceInBand`; `[1]` per root instance in `forEachInstanceInBand`; `[depth+1]`
  before each recursion in `_descend` and `_bandDescend`.
- `packages/jet_cad_2d/test/support/layer_fixture.dart` (new, P-6 engine half).
- `packages/jet_cad_2d/test/index/layer_filter_test.dart` (new, 17 tests).

### The sites (spec cites 571, 587, 865, 881, 909 at main; verified identical at ab7a225)

| base line | what | now |
|---|---|---|
| 571 | `_bandDescend` leaf (band selection inside an instance) | :588 `acceptsEntityOnLayer(slot, filter, context)` |
| 587 | `_bandDescend` nested instance | :604 `acceptsNodeOnLayer(node, filter, context)` |
| 865 | `_descend.visitLeaf` (pick, and snap's leaf kinds) | :909 `acceptsEntityOnLayer` |
| 881 | `_descend.visitSnapCentre` (snap's `center` kind) | :925 `acceptsEntityOnLayer` |
| 909 | `_descend` nested instance (depth 0: root instance) | :953 `acceptsNodeOnLayer` |

Unchanged on purpose (root context, so `acceptsEntity`/`acceptsNode` = context layer 0 + the ATTRIB rule):
`forEachInRect` :324, `forEachInstanceInRect` :350, `forEachLeafInBand` :408, `forEachInstanceInBand` root :463,
`_considerIntersections` :1616.

### Gates (CI=true, real tails), on f5998db; engine re-run on af87621

- engine `dart test`: `00:18 +1202 -2: Some tests failed.` at f5998db, `00:18 +1204 -2: Some tests failed.` at af87621.
  The 2 are the standing ones: `test/testing/generate_document_test.dart: the default document is the one Plan 2
  measured, byte for byte [E]` and `... both text fractions default to zero and change nothing [E]`.
  `dart analyze`: `No issues found!`; format `Formatted 167 files (0 changed)`.
- render `flutter test`: `01:00 +1154 ~1 -7: Some tests failed.`: text ladder rung 1-5 and text lod ladder rung 1-2
  (canvas), the 7 standing. analyze `No issues found! (ran in 1.8s)`; format `Formatted 200 files (0 changed)`.
- app: `03:19 +934: All tests passed!`; `No issues found! (ran in 1.8s)`; `Formatted 165 files (0 changed)`.
- dev_harness_2d analyze: `No issues found! (ran in 1.3s)`.
- `git diff 582f78b --stat -- packages/jet_cad_2d/test/invariants` is empty (both invariant files untouched; the
  render one is untouched too, no render file changed). `git status --short` clean after commit (no
  analysis_options.yaml).

### Mutants (test file `test/index/layer_filter_test.dart`; every one `diff= 0` after restore)

| id | mutation | result |
|---|---|---|
| M-LP-1 | `_beginQuery`: `if (revision != _tablesRevision) {` -> `if (false) {` | RED `00:00 +0 -1: ... a layer hidden by a direct table write after a query is excluded ... (M-LP-1) [E]` (also the command, lock, layer-0 and hide-A tests; `00:01 +10 -5`) |
| M-LP-2 | `_reconcile`: drop `if (document.tables.layers[handle] != null) continue;` | RED `00:00 +3 -1: ... cost the index no rebuild (M-LP-2) [E]` and `... rebuilds once: the undo of an add (S-4) [E]` |
| M-LP-14 pick | `visitLeaf` -> `acceptsEntity(slot, filter)` | RED `00:00 +6 -1: ... with layer 0 hidden, picking reaches every level of the instance [E]` (+ snapping, both probes; visitLeaf is pick's and snap's shared leaf path) |
| M-LP-14 snap | `visitSnapCentre` -> `acceptsEntity(slot, filter)` | RED `00:00 +7 -1: ... with layer 0 hidden, snapping reaches every level of the instance [E]` |
| M-LP-14 band | `_bandDescend` leaf -> `acceptsEntity(slot, filter)` | RED `00:00 +8 -1: ... with layer 0 hidden, a band selects the instance through its leaves [E]` |
| M-LP-14 recursion | `_effectiveBelow`: `? _effectiveLayer[depth]` -> `? ReservedHandles.layerZero.value` | RED `00:00 +6 -1: ... picking reaches every level ... [E]` (+ snapping, band, both probes) |
| M-LP-23 | ATTRIB rule: `owner == document.rootHandle ? Handle.none : _instanceLayer(owner)` -> `Handle.none` | RED `00:00 +5 -1: ... the instance on A is still drawn, and so is its ATTRIB ... [E]` (+ pick, hide A, lock A, instance move; `00:01 +10 -5`) |
| M-LP-24 (descend) | `_descend` nested -> `acceptsNode(node, filter)` | RED `00:00 +6 -1: ... picking reaches every level ... [E]` (+ snapping, both probes) |
| M-LP-24 (band) | `_bandDescend` nested -> `acceptsNode(node, filter)` | RED `00:00 +8 -1: ... a band selects the instance through its leaves [E]` |

Own:

| id | mutation | result |
|---|---|---|
| T3a | `invalidate()`: drop `_ownerLayer.clear();` | RED `00:00 +11 -1: ... moving the instance to a hidden layer takes its ATTRIB along ... [E]` |
| T3b (probe) | `if (revision != _tablesRevision) {` -> `if (true) {` (cache dropped every query) | RED `00:01 +13 -1: allocation probe ... a pick two instances deep ... [E]` and `... a snap ... [E]` (`_Set` per call) |
| T3c | band root: drop `_effectiveLayer[1] = _effectiveBelow(resolved, 0);` | first SURVIVED `00:01 +15: All tests passed!`; after af87621's test, RED `00:00 +9 -1: ... a pick and a band after a snap through an instance on locked B ... [E]` |
| T3d | `acceptsNodeOnLayer`: always `context` (ignore a nested instance's own layer) | RED `00:00 +5 -1 ...` through `00:00 +8 -7` (incl. `a nested instance on a non-zero layer answers for its own layer`) |
| T3e | `_descend`: drop `_effectiveLayer[depth + 1] = ...` | first SURVIVED `00:01 +16: All tests passed!`; after af87621, RED `00:00 +10 -1: ... a pick and a snap after a band through an instance on layer 0, then layer 0 hidden ... [E]` |
| T3f | `_bandDescend`: drop `_effectiveLayer[depth + 1] = ...` | first SURVIVED `00:01 +17: All tests passed!`; after af87621, RED `00:00 +9 -1: ... a pick and a band after a snap through an instance on locked B ... [E]` |

Why T3c/T3e/T3f first survived: the array starts zero-filled, `Handle(0)` names no layer, and `FilterEvaluator` treats
a missing layer as visible and unlocked. A missing write is only visible when an earlier query left a hidden or
locked layer at that depth. The af87621 tests set that up: a snap through an instance on locked B, or a band
through an instance on layer 0 followed by hiding layer 0.

## Decisions and things the spec/plan got wrong or left open

1. **Probe: "zero allocations" is not literally achievable, and is not what I assert.** `_descend` already allocates
   one `Aabb2` per recursion level and one `Transform2` per level/instance, and closures per level (documented in
   `_descend` and budgeted in `query_allocation_test.dart`). The probe asserts what that file asserts:
   `Vector2`, `_Record`, `TextMetrics` and `_Set` under 0.5 per call, and `Aabb2` < 7 and `Transform2` < 10 per call.
   `_Set` is what a dropped cache re-allocates (the `seen` set in `_visibleContainer`); T3b proves the probe catches
   it. `_Uint32List`, the class a per-query depth array would show up as, **cannot be watched**: a scratch measurement
   read about 18,400 accumulated `_Uint32List` with **zero** queries run between reset and read (VM-service
   traffic). HEAD ab7a225 and this branch read the same (18,364 vs 18,369 per 1,000 picks). The scratch test was
   deleted.
2. **The ATTRIB rule is in the one leaf path, not only in `acceptsEntity`.** `acceptsEntity` is
   `acceptsEntityOnLayer(slot, filter, layer 0)`. So an ATTRIB owned by a *nested* instance (indexed as a leaf of
   the definition's container) also follows its owner's layer, or the context's when the owner is on layer 0. P-4's
   "up its parent chain of instances" collapses to this: an `InstanceNode`'s parent is never an instance; a nested
   one sits in a definition, and the walk's depth array is the only place its context is known.
3. **`acceptsEntityOnLayer` takes the context's effective layer, not "the layer to test".** The substitution is
   applied inside it: own layer if non-zero, else owner instance's if non-zero, else context. This keeps the
   column read and the substitution in one place. Same for `acceptsNodeOnLayer`.
4. **`_ownerLayer` memo staleness.** The memo is safe because an instance's layer changes only by node replacement
   (`SetInstanceLayerCommand`). Its `touched` is the node, `_reconcile` rebuilds for a node, and `rebuildAll`
   invalidates. T3a pins it. A direct `tree.replaceNode` without a command is as stale as `_containerVisible`
   already is for `Node.visible`. Not new.
5. **Frame-path cost.** Per leaf: one int compare (layer 0?). For a layer-0 leaf whose owner is not the root (group
   leaves, ATTRIBs, definition leaves), one more int compare and one map hit (`_ownerLayer`). Per query: one int
   compare (revision) and a few array writes.
6. **S-4 is pinned.** The `AddLayerCommand` undo test asserts exactly one rebuild for a handle no longer in the
   table. The add itself rebuilds nothing.
7. **`Handle(0)` as the array's initial value** is harmless with every write in place (T3c/e/f pin them). Filling it
   with layer 0 instead would only change which stale value a missing write reads. Left as is.
8. **For Task 9 (info, from Task 2's review):** nothing in this task reads the layer table inside a
   `tables.changes` callback. The revision check runs at the next query.
