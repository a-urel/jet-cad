# Task 1 report: the engine, node commands carry components (D-1 to D-4)

Commit: 90044db4 "feat(engine): a removed node takes its components (node-components D-1 to D-4)" on fix/node-components-on-delete. 12 files, +586/-98. No analysis_options.yaml staged (git status clean after commit).

## Implemented
- `component.dart`: `ComponentRegistry.checkRestorable`; `restore` calls it first; `restore` doc updated.
- `commands.dart`: `AddNodeCommand(node, {index, components})`, `components` field (default `ComponentSnapshot.empty`), `capabilities` ({structure} / +components), apply order: duplicate check, checkRestorable, tree.addNode, restore, seed. `RemoveNodeCommand`: static `capabilities` {structure, components}, snapshotOf before removal, `detachAll` after, inverse `AddNodeCommand(node, index:, components:)`. Both class docs rewritten.
- `regeneration.dart` (D-4): `_detachLayer` deleted; dissolve is `out.addAll(_subtreeRemoval(t, s, h)); continue;`; `cleanup` list removed from `_run` (`seeds.isEmpty` return, `for (final c in plan)`); docs of `_plan`, `_written`, `_run` rewritten.
- `parametric_system.dart`: docs only at the three places, plus removal of the `../document/object_layer.dart` import that became unused (analyzer `unused_import` with --fatal-infos; it was only used by `_detachLayer`).
- New `test/document/node_components_test.dart` (N-1..N-7), S-1 added to `select_tool_test.dart` ('keys and delete' group, first test).
- `_Registration.detach` (parametric_system.dart:~789) is now unused by the planner but kept (mutants M-11/M-12 re-use it; brief did not say to delete it).

## Deviation from the brief (test fixture, assertions unchanged)
N-4 'an unmapped type id...' and 'an index out of range...' failed on first run against a correct implementation: `before = enc(doc)` was taken before `doc.handleSeed.next()`, and the encoding includes `handleSeed` (21 vs 22). Fix: moved `final h = doc.handleSeed.next();` above `final before = enc(doc);` in those two tests (with a comment). Every assertion is unchanged. `dart format` also reflowed the new file.

## Step 2 (red before implementation)
Not captured as a separate red run: I implemented Steps 3-4 before first running the new tests (the brief says the first run is a compile error on `components:`). Red evidence is the mutants below, each seen red against the finished tree.

## Gates (pasted summary lines)
- jet_cad_2d: `dart test` -> `00:06 +1280 -2: Some tests failed.` failing: only generate_document_test "both text fractions default to zero and change nothing" and "the default document is the one Plan 2 measured, byte for byte" (the two standing). `dart analyze --fatal-infos` -> `No issues found!`; `dart format ... .` -> `Formatted 172 files (0 changed)`.
- jet_cad_2d_flutter: `flutter test` -> `00:19 +1432 ~1 -5: Some tests failed.` failing: only the five text_ladder_golden rungs 1-5 (standing). analyze `No issues found!`; format `Formatted 228 files (0 changed)`.
- jet_cad_2d_gpu: `+20: All tests passed!`, analyze clean, format 0 changed.
- jet_cad_restaurant_symbols: `+97: All tests passed!`, analyze clean, format 0 changed.
- apps/floor_planner: `+212: All tests passed!`, analyze clean, format 0 changed.
- apps/restaurant_demo: `+68: All tests passed!`, analyze clean, format 0 changed.
- jet_cad_floor_plan (`--enable-vmservice`): `01:49 +1912: All tests passed!`, analyze `No issues found!`, format 0 changed.
- The pre-mutant S-1 run: `+22: All tests passed!` (select_tool_test.dart).

## Mutants (each applied alone, run, restored via cp from a saved copy; git status clean afterwards)
Driver script and backups in the scratchpad; each restored from `cp`, never git checkout.

| Mutant | Edit | Killing test(s) | Red line |
|---|---|---|---|
| M-1 | drop `detachAll` in RemoveNodeCommand | N-1, N-2, N-5, N-6; S-1 | `+0 -1: N-1 a removal takes every component of its handle, no other [E]`; S-1: `keys and delete S-1 ... [E]` / `Expected: true Actual: <false>` / `13 keeps nothing` |
| M-2 | inverse without `components:` | N-2, N-5, N-6; S-1 | `+1 -1: N-2 undo restores the snapshot and the index byte for byte; redo removes them again [E]`; S-1: `Expected: ...components":{"a.earlier":{"19":{}...` `Actual: ...components":{},"rawData"` |
| M-3 | snapshotOf after detachAll | N-2, N-5, N-6 | `+1 -1: N-2 undo restores ... [E]` |
| M-4 | detachAll drops stores only, not `_unknown` | N-1, N-2, N-5, N-6 | `+0 -1: N-1 a removal takes every component of its handle, no other [E]` |
| M-5 | restore appends `snapshot.unknown.reversed` | N-2, N-5 | `+1 -1: N-2 undo restores ... [E]` (N-6 stayed green: its carrying branch compares a fresh unknown order too; N-5 was the second kill) |
| M-6 | `detachAll(handle)` -> `clear()` | N-1, N-2, N-5 | `+0 -1: N-1 a removal takes every component of its handle, no other [E]` |
| M-7 | RemoveNodeCommand.capabilities deleted | N-3 | `+2 -1: N-3 capabilities, and a profile without components [E]` |
| M-8 | AddNodeCommand.capabilities deleted | N-3 | `+2 -1: N-3 capabilities, and a profile without components [E]` |
| M-9 | restore before addNode, no check | N-4 (cycle), N-4 (index) | `+5 -1: N-4 a refused add leaves everything as it was a definition cycle, with a mapped snapshot [E]` |
| M-10 | checkRestorable line deleted in AddNodeCommand | N-4 (unmapped), N-4 (dangling) | `+3 -1: N-4 ... an unmapped type id, the mapped one sorting first [E]` |
| M-11 | dissolve's `registration.detach(h)` put back | DV1 | `DV1 ... [E]` `Expected: empty Actual: [null]` (dissolve_test.dart 231:5, `fuseSets(redoReplay)`) |
| M-12 | cleanup list put back and applied | PG1 | `PG1 ... [E]` `Expected: empty Actual: [Instance of 'SetComponentCommand<Gauge>']` `no separate component restore` (page_test.dart 235:5) |
| M-13 | decode sweeps components of handles not in tree/definitions/entities | N-7 | `+9 -1: N-7 a plan carrying orphans loads and saves byte for byte [E]` |
| M-14 | rollback variant: no check, `try { restore } catch { removeNode; rethrow }` | N-4 (dangling) | `+4 -1: N-4 ... the same under a parent that already lists the handle, the raw list compared ... [E]` |
| M-15 | inverse without `index:` | N-2, N-5 | `+1 -1: N-2 undo restores ... [E]` |
| M-16 | checkRestorable `break`s after first entry | N-4 (unmapped), N-4 (dangling) | `+3 -1: N-4 ... an unmapped type id, the mapped one sorting first [E]` |

Notes: M-1 and M-2 run through the flutter S-1 as the brief names (both red, lines above). M-12 was reconstructed as `cleanup = [for (final h in lost) before.objects[h]!.detach(h)]` prepended to the plan (the layer detach omitted; the SetComponentCommand<Gauge> in the inverse is what PG1 pins). M-5: the brief names N-6 too; N-6 stayed green (killed by N-2 and N-5 instead). M-13 names the codec's `decode`; mutated at the `doc.rawData.loadJson` call in `json_codec.dart`.

## The seven re-pins
1. compound_command_test.dart "capabilities is the union of the children's": expected set gains `Capability.components` (comment names spec D-2).
2. cascade_test.dart CS7: re-add carries `components: doc.components.snapshotOf(hA)`.
3. cascade_test.dart LV2: same.
4. objects_of_test.dart OB1: `h5300`'s re-add carries `components: doc.components.snapshotOf(h5300)`.
5. misplaced_test.dart MP6: removing the nested group now yields `Hinge` null (reason cites D-4), then undo restores `const Hinge(true)`, then redo; rest unchanged.
6. dissolve_test.dart DV1: `restoredBy<T>` helper added beside `flatten`; undo replay `fuseSets` isEmpty + `restoredBy<Fuse>` == [fuse]; redo `fuseSets` isEmpty; order list loses the `detach` entry; delete: fuseSets isEmpty + `restoredBy<Fuse>(deleteReplay, hF) == [fuse]`; comments reworded.
7. page_test.dart PG1: `restoredBy` helper added; `restores = restoredBy<Gauge>(result.inverse, hG2)` still `[gauge2]`; new expect that no `SetComponentCommand<Gauge>` on hG2 is in `result.inverse`; comment reworded.

No other existing test needed an edit.

## Self-review / concerns
- Doc comment lines kept <= 80 columns (checked the diff). `dart format` clean.
- DV1's test title still says "component detached ... and the cleanup are untouched" (title left verbatim per the brief's "wording kept"); task 2/the controller may want to reword it.
- `_Registration.detach` is dead code outside the mutants; left in place.
- No behaviour concerns: the spike's prediction held (exactly the seven + two standing in jet_cad_2d; five goldens in flutter; floor_plan 1912 green).

## Fix round 1
Finding: `ParametricView.objectsOf` doc (parametric_system.dart ~443-449) still said a lost, re-parented or deleted object "is not listed although its component may still be attached".

Change (doc only, commit d082640e): the sentence now says an object an edit lost or deleted is not listed because its node's removal took its component (node-components D-4); a re-parented one is not listed although its component stays attached when the re-add carries the snapshot (D-3); a component on a non-root-level group never is. The rest of the doc is kept (reflowed to 80 columns); the `dissolves` doc edit is unchanged.

Commands (packages/jet_cad_2d), real output:
- `dart analyze --fatal-infos` -> `No issues found!`
- `dart format --output=none --set-exit-if-changed .` -> `Formatted 172 files (0 changed)`
- `dart test test/parametric/objects_of_test.dart` -> `00:00 +1: All tests passed!`
- added lines over 80 columns in the diff: 0. `git status` showed only parametric_system.dart before the commit.
