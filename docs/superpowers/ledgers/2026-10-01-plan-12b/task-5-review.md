# Task 5 review: the stamp and the detach (spec D2)

Reviewer worktree: `.claude/worktrees/plan-12b-review`, detached at 04a14b3 (base 4a735fb). It was clean before and after the review, with no analysis_options rewrites. Mutants were done with a cp backup in `scratchpad/r5/`, and `diff` exited 0 after each restore. The scratch tests were moved out of the tree once they had run.

## Verdict: **Approved with notes**

The production code has no defect. One test gap (a mutant that survives, and a test that kills it) and one doc-comment slip. Neither blocks the task.

## 1. Diff review (regeneration.dart, parametric_system.dart, the new test)

- **Stamp coverage.** `_stampLayer` runs after the payload rewrite in three places: on a matched region's fill (:593), on its boundary (:594), each separately, and on every matched plain or TEXT child, after its string rewrite (:625). The boundary is excluded from `byKind`, so no record is stamped twice. The guard is an exact `!=` on `layerAt` at plan time. No earlier plan command can change a child's layer, so the read is accurate. Added records (plain, TEXT, fill and boundary) all get `layer` through `_recordOf`. Correct.
- **Per-object layer.** `final layer = objectLayer(t, h)` is computed inside the closure loop, so a neighbour that is regenerated keeps its own layer (my R1 mutant shows this; see §3).
- **`objectLayer` with a missing layer → 0, with no throw.** `objectLayer` reads the component and checks `tables.layers.contains`. `_stampLayer`'s `slotOf(c)!` only sees live matched children. The stamp uses `.restore`, so a locked target (B in OL3) or a hidden one (C in OL4) is never refused. R-9 holds.
- **Apply order and rollback.** Stamps are ordinary plan commands, applied by the hand-rolled loop. Their inverse is `SetEntityLayerCommand.restore(old)`, which is exact. I verified the rollback dynamically. I temporarily injected `RemoveEntityCommand(0xDEAD)` at the end of `_plan` whenever the plan held a stamp, then moved a region object to A. The edit threw `StateError`, the document encoded byte for byte as before, every child was back on 0, `ObjectLayer` was absent, and the history held only the creates. Without the injection the same test fails with `Expected: throws <Instance of 'StateError'> Actual: <Closure: () => void>`, so the injection is what triggered the throw.
- **ParametricReplay inverse.** The replay is `[reversed inverses (stamps included), r.inverse]`. In OL2–OL5 undo and redo are state-equal (`canon` minus the seed). `capability` is the replay's highest-ranked child, so undoing a real move reports geometry, as D1 intends.
- **Detach.** `_detachLayer` is planned:
  - after the registered component's detach in the dissolve (`_plan`);
  - for each `lost` object in the `_run` cleanup.

  A dissolving object is still live in the after-survey, so it is never `lost`, and there is no double detach. If an inner edit already detached the `ObjectLayer`, `_detachLayer` sees null and plans nothing. I also tested the **cascade-loss** path, which the implementer did not cover: a Pin (policy cascade) on layer A whose host Post is deleted loses its `ObjectLayer`, undo restores it and redo detaches it again. Under M-LP-11 that test goes red (`Expected: null Actual: ObjectLayer:<ObjectLayer(12)>`).
- **Paths that do not involve a registered object.** `ObjectLayer` is not a registered parametric type, so `_written`, `_heldBefore` and `stray` never read it. A scratch test confirmed the following:
  - `SetComponentCommand<ObjectLayer>` on a plain root group, a nested group, or a never-used handle lands and undoes, with no refusal and no regeneration.
  - On a generated child's handle it is refused by `_refused` (`GeneratedGeometryError`), which is correct.
  - On a nested group (the CS7 re-parent) the component is inert, the same as the registered component left there. Info only.
- **A component-only move that stamps nothing.** If the object is already on the layer, or both the old and new values resolve to 0 (absent or ghost), the plan is empty. `_geometryChanged` stays false and the edit reports components (OL8b pins the case where the layer is already equal).
- **Info, not a finding.** An `ObjectLayer` left on a node that dies without being a `lost` object stays on the dead handle. Example: a re-parented (nested) object whose parent is deleted. This is the existing behaviour for registered components too. `layerIsEmpty` ignores dead holders, but `validate` would warn once the layer is deleted. It only happens in the CS7 state; I am noting it for the results note, not as a Task 5 defect.

## 2. Gates (CI=true, at 04a14b3, rerun here)

- **engine:** `00:18 +1223 -2: Some tests failed.` The 2 failures are the standing ones: `generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte` and `... both text fractions default to zero and change nothing`. analyze `No issues found!`; format `Formatted 168 files (0 changed) in 0.61 seconds.`
- **render:** `01:02 +1154 ~1 -7: Some tests failed.` The 7 failures are all standing: `text_ladder_golden_test.dart` rungs 1–5 (RenderBackend.canvas) and `text_lod_ladder_golden_test.dart` rungs 1–2 (RenderBackend.canvas). analyze `No issues found! (ran in 1.4s)`; format `Formatted 200 files (0 changed) in 0.61 seconds.`
- **app:** `03:17 +934: All tests passed!` analyze `No issues found! (ran in 1.8s)`; format `Formatted 165 files (0 changed) in 0.77 seconds.`
- **dev_harness_2d analyze:** `No issues found! (ran in 1.1s)`.

## 3. Mutants (regeneration.dart, test/parametric/object_layer_test.dart unless noted)

| id | line | mutation | real output |
|---|---|---|---|
| M-LP-3 | :478 | guard → `if (false) {` | `00:00 +4 -8: Some tests failed.` (OL2, 3, 4, 5, 6, 7, 8b, 11) |
| M-LP-4 boundary | :594 | drop boundary stamp | `00:00 +8 -4: Some tests failed.` OL3 with reason `boundary 7D2`, `Expected: <18> Actual: <1>` |
| M-LP-4 fill | :593 | drop fill stamp | `00:00 +8 -4: Some tests failed.` OL3 with reason `fill 7D1` |
| M-LP-6 | :478 | guard → `if (true) {` | `00:00 +10 -2: Some tests failed.` OL8a `Expected: empty Actual: WhereTypeIterable<SetEntityLayerCommand>:[`; OL8b `Expected: Capability:<Capability.components> Actual: Capability:<Capability.geometry>` |
| M-LP-11 | :981 | drop cleanup `_detachLayer` | `00:00 +11 -1: Some tests failed.` OL9 |
| M-LP-11 (cascade, own scratch test) | :981 | same | `00:00 +0 -1` `Expected: null Actual: ObjectLayer:<ObjectLayer(12)>` |
| X-dissolve | :561 | `_detachLayer(t,h)` → `const <DraftCommand>[]` | `00:00 +11 -1: Some tests failed.` OL10 |
| R1 (own) | :564 | `objectLayer(t, closure.first)` | `00:00 +10 -2: Some tests failed.` OL2, OL5 |
| R2 (own) | :628 | added plain record on `layerZero` | `00:00 +4 -8: Some tests failed.` OL1, 2, 5, 7, 8a, 8b, 9, 10 |
| R3 (own) | :625 | stamp matched TEXT only | `00:00 +6 -6: Some tests failed.` OL2, 3, 5, 6, 7, 11 |
| **R4 (own)** | :594 | boundary stamp guarded on the **fill's** layer | **`00:00 +12: All tests passed!` (survives)** |

All named mutants are killed. Ledger accuracy: the report's M-LP-3 line (`+3 -8`) has 11 tests, so it predates the OL8 split. At 04a14b3 it is `+4 -8`, and it is still killed.

## 4. Rulings on the implementer's deviations

1. **Replay read through the expander on a reloaded copy instead of the undo stack.** Accepted. `UndoStack` has no public read, and the object read is the inverse the dispatcher records. OL8b also cross-checks the capability through the real dispatcher's `CommandApplied`. No production API was added, which is right.
2. **Line references.** Accepted. The cleanup is `_run`'s `cleanup` list, as the plan meant.
3. **`object_layer_missing` handles `[holder, layer]`.** Accepted. This is Task 2's choice, now pinned by OL7.
4. **No spec contradiction.** Agreed. A real move reports geometry and an unchanged edit reports components, exactly as D1/D2 predict.

## 5. Non-degeneracy

The fixtures are non-degenerate:
- Layers: A is ACI 1, B is ACI 5 and locked, C is ACI 3 and hidden.
- Positions: every object sits in a turned, translated group off the origin. The ghost handle is 0x6A6A.
- Moves: from 0 to A, A to B (locked) and 0 to C (hidden), so the restore form is exercised on both refusing states. Layer-0 results are only asserted where the test is about layer 0 (OL6, OL7).
- Neighbours: the R1 kill shows that a neighbour is regenerated and keeps its own layer.

## Findings

1. **(Minor, test gap) R4 survives: no test has a region whose fill and boundary are on different layers.**
   - **What is untested.** Spec D2 says the fill and boundary are restamped "each only if it differs". Every test moves both together, so a guard read from the wrong record still passes. That state is reachable from a file.
   - **Proof the test works.** I wrote a scratch test: a region object on A, every boundary record set to 0 directly (as a file can hold), save and load, then a `RegionRect` edit, expecting every child on A. It passes on 04a14b3 and goes red under R4 (`Expected: <18> Actual: <1>`).
   - **Fix.** Add it as OL3b. The text is in `scratchpad/r5/zz_review_split_test.dart`; use the scene's `_Scene` helpers.
   - Optionally also land the cascade-loss detach test (`scratchpad/r5/zz_review_cascade_test.dart`), since D2 names "every path that removes a live object" and only the delete and dissolve paths are pinned in-tree.
2. **(Minor, doc) The `Generated` class comment splits an existing sentence** (`parametric_system.dart`, about :206–216).
   - **Problem.** The new layer paragraph was inserted before "Each defaults to what `draftRecord` writes: ByLayer, flags 0…". "Each" now reads as referring to the layer paragraph, not to the attribute list. The joined line is also about 96 columns long; `dart format` does not reflow comments.
   - **Fix.** Put the "Each defaults … written on add only." text back directly after "…fixed for an object's life.". Make the layer paragraph its own block after it, wrapped at 80 columns.
3. **(Info) An `ObjectLayer` on a nested (re-parented, CS7) group is inert and is not detached when its dead parent takes it down.** This matches the existing registered-component behaviour. Record it in the results note as a known limitation; no Task 5 change.
