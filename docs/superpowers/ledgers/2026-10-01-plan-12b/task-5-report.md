# Task 5 report — the stamp and the detach (spec D2)

Base: HEAD 4a735fb. **Commit: 04a14b3** `feat(engine): parametric objects keep their layer` (not pushed).

## Files
- `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`
  - `_recordOf(handle, owner, kind, g, layer, {boundary})`: every added record (plain, region fill and
    boundary, TEXT) is drafted on `layer`.
  - `_plan`: `final layer = objectLayer(t, h);` per non-dissolving object. New `_stampLayer(t, out, c, layer)`:
    plans `SetEntityLayerCommand.restore(c, layer)` only when `t.entities.layerAt(slot) != layer` (exact `==`).
    Called after the payload rewrite for a matched region's fill, then its boundary (each on its own), and for
    every matched plain/TEXT child after its payload and string rewrite.
  - New `_detachLayer(t, h)`: `SetComponentCommand<ObjectLayer>(h, null)` when `h` carries one. Planned after
    the registered detach by 10 D15's dissolve (in `_plan`) and by 06 D8's cleanup (in `_run`, for each `lost`).
  - Doc comments of `_plan`, `_recordOf` updated.
- `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`: imports `layer_commands.dart` and
  `object_layer.dart` (part file uses them); the `Generated` class comment records the one-column amendment of
  06 D11 / 10 D13 (the layer is the planner's: written on add, restamped on a match when it differs).
- `packages/jet_cad_2d/test/parametric/object_layer_test.dart` (new, 12 tests), on the engine's parametric test
  catalog (`ClipRect`, `SoftRect`, `RegionRect`, `Caption`, `Fuse`) with layers A (ACI 1), B (ACI 5, locked),
  C (ACI 3, hidden); every object in a turned group off the origin (`atA`, `atB`, `parked`, `onA(...)`).
  - OL1 added children on the object's layer (ClipRect on A, RegionRect fill+boundary on B, Caption TEXT on C).
  - OL2 move (SetComponentCommand<ObjectLayer>) then two edits (one removing a child, one adding one): every
    child on A; undo/redo state-equal.
  - OL3 regions: move restamps fill and boundary separately (per-record reasons), an added region lands on A,
    a second move to B restamps all three regions; undo/redo.
  - OL4 TEXT: move to C, string edit keeps C; undo/redo.
  - OL5 neighbour edit: moving B (ObjectLayer B) re-splits A (moved to A) — removed and added pieces — all
    children stay on their object's layer; undo/redo.
  - OL6 no ObjectLayer => layer 0: a new object without one, and a moved region object whose component is
    detached regenerates every record back on 0.
  - OL7 missing layer: `ObjectLayer(0x6A6A)` creates on 0 and is kept as stored; an object on A whose layer the
    table loses regenerates its matched children onto 0; `validate()` gives exactly two
    `component.object_layer_missing` warnings ([hA, ghost], [hB, A]).
  - OL8a no layer command: the replay of a geometry edit of a SoftRect, a RegionRect and a Caption (all on
    non-zero layers) holds SetEntityGeometryCommand and no SetEntityLayerCommand.
  - OL8b capability (S-10): a SoftRect re-set to the same value -> `ParametricEdit.capability == components`
    and the dispatcher's CommandApplied reports components; an ObjectLayer re-set to the same layer -> components;
    a real move -> geometry.
  - OL9 detach on delete (S-1): delete the last object on A -> `components.get<ObjectLayer>(hA) == null`, B's
    kept; `RemoveLayerCommand(A)` (user form) succeeds; no `object_layer_missing`; two undos restore the
    component and the state; redo detaches again.
  - OL10 detach on dissolve: a Fuse on A burnt -> node, Fuse and ObjectLayer gone; deleting A leaves no warning;
    undo restores.
  - OL11 save/load keeps the component and the stamped records.

## Decisions
- **"The top undo entry's ParametricReplay.replay"**: the undo stack has no public read. The test expands the
  command through `doc.commands.expander` on a reloaded copy and applies it (dissolve_test's pattern), reading
  the inverse — exactly the object the dispatcher records as the top undo entry. The capability half (OL8b) is
  also checked through the real dispatcher's `CommandApplied`.
- Undo comparisons use `canon` minus `handleSeed` (the seed only rises; an undone add leaves it raised).
- `SetEntityLayerCommand.restore` is used for the stamp (P-2), so a locked/hidden object layer never refuses.
- OL8 was split into OL8a/OL8b so M-LP-6 shows both observations (the replay and the capability) red
  independently.

## Gates (CI=true, real tails, at 04a14b3)
- engine: `00:18 +1223 -2: Some tests failed.` — the 2 standing (`generate_document_test.dart: both text
  fractions default to zero and change nothing`, `... the default document is the one Plan 2 measured, byte for
  byte`). 1211 + 12 new. `No issues found!` `Formatted 168 files (0 changed) in 0.58 seconds.`
- render: `00:59 +1154 ~1 -7: Some tests failed.` (7 standing, unchanged) `No issues found! (ran in 1.5s)`
  `Formatted 200 files (0 changed) in 0.65 seconds.`
- app: `03:15 +934: All tests passed!` `No issues found! (ran in 1.8s)` `Formatted 165 files (0 changed) in
  0.84 seconds.`
- dev_harness_2d analyze: `No issues found! (ran in 1.2s)`
- Existing parametric suite unedited: `git diff 4a735fb --stat` touches only the two lib files and the new test.
  Invariant tests unedited (`git diff 4a735fb --stat -- packages/*/test/invariants` empty). analysis_options not
  staged. (Render/app gates were run on the first version of the commit; the amend only split one test in the
  engine's new test file, after which the engine gate was re-run.)

## Mutants (file `lib/src/parametric/regeneration.dart` at 04a14b3; cp backup, one line, test file
`test/parametric/object_layer_test.dart` in the foreground, cp back, `diff` exit 0 each time)
| id | line | mutation | result (real output) |
|---|---|---|---|
| M-LP-3 | :478 | `_stampLayer` condition -> `if (false) {` (stamp added children only) | `00:00 +3 -8: Some tests failed.` OL2 move-then-edit red (`Expected: <18> Actual: <1>`), also OL3, OL4, OL5, OL11 … |
| M-LP-4 (boundary) | :594 | drop `_stampLayer(t, out, boundary, layer);` | `00:00 +7 -4: Some tests failed.` OL3 red at `expectRegionsOn` with reason `boundary 7D2` (`Expected: <18> Actual: <1>`); also OL6, OL11 |
| M-LP-4 (fill) | :593 | drop `_stampLayer(t, out, fills[i], layer);` | `00:00 +7 -4: Some tests failed.` OL3 red with reason `fill 7D1`; also OL6, OL11 |
| M-LP-6 | :478 | condition -> `if (true) {` (drop the `!=` guard) | `00:00 +10 -2: Some tests failed.` OL8a (`Expected: empty Actual: WhereTypeIterable<SetEntityLayerCommand>:[`) and OL8b (`Expected: Capability:<Capability.components> Actual: Capability:<Capability.geometry>`) |
| M-LP-11 | :981 | drop `..._detachLayer(t, h),` from the cleanup | `00:00 +10 -1: Some tests failed.` OL9 (`Expected: null Actual: ObjectLayer:<ObjectLayer(12)>`) |
| X-dissolve | :561 | dissolve `..addAll(const <DraftCommand>[])` | `00:00 +10 -1: Some tests failed.` OL10 (`Expected: null Actual: ObjectLayer:<ObjectLayer(12)>`) |
| X-recordOf | :449 | `_recordOf` writes `layer: ReservedHandles.layerZero` | `00:00 +2 -9: Some tests failed.` OL1 and 8 more |
| X-plain | :625 | drop the plain/TEXT matched stamp | `00:00 +4 -7: Some tests failed.` OL2, OL3 (the plain children), OL4, OL11 and 3 more |

All killed; none survived. Logs in the scratch prefix `l5/`.

## Spec / plan points
1. Spec/plan say "the top undo entry's `ParametricReplay.replay`", but `UndoStack` has no public accessor for it;
   the test reads the identical inverse through the expander on a copy (see Decisions). No production API added.
2. The plan cites the dissolve at `:530-533` and the cleanup at `:943`; at 4a735fb the dissolve is in `_plan`
   (~:518) and the cleanup is in `_run` (~:943) — consistent, just noting the cleanup is `_run`'s `cleanup` list,
   not a separate function.
3. `validate()`'s `object_layer_missing` diagnostic carries `[holder, layer]` as its handles (Task 2's choice);
   OL7 pins that.
4. Nothing in the spec contradicted the code; the `!=` guard and capability behaviour are as D1/D2 predict
   (a real move reports geometry, a no-op components edit reports components).
