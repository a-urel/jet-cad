# Results — a removed node takes its components (O-8)

**Spec:** [2026-10-09-node-components-on-delete-design.md](../specs/2026-10-09-node-components-on-delete-design.md),
revision 3, approved 2026-10-10.
**Plan:** [2026-10-10-node-components-on-delete.md](../plans/2026-10-10-node-components-on-delete.md).
**Spec point settled:** the host embedding spec's **O-8** (components
orphaned by node deletion in general).
**Branch:** `fix/node-components-on-delete`, cut from
`spec/node-components-on-delete` at `5a0af46` (`main` at `e281372`, 0.4.0,
plus the spec and the plan). Executed subagent-driven: one implementer
and one independent reviewer per task.

Every gate line and red line below is copied from the task's report
(`.superpowers/sdd/2026-10-10-node-components-on-delete/task-1-report.md`
and `task-2-report.md`, archived with the ledger on merge). Nothing here
was re-run for this note.

## What changed

- **D-1, `commands.dart`.** `AddNodeCommand(node, {index, components})`
  carries a `ComponentSnapshot` (default empty). Apply order: duplicate
  check, `ComponentRegistry.checkRestorable`, `tree.addNode`, `restore`,
  seed. Every refusal comes before the first write, so no rollback is
  needed. `RemoveNodeCommand` reads `snapshotOf(handle)` before the
  removal, `detachAll`s after it, and its inverse is
  `AddNodeCommand(node, index:, components:)`.
- **D-1, `component.dart`.** `ComponentRegistry.checkRestorable` (new);
  `restore` calls it first. After the final review it also refuses a
  registered entry whose value is not of the class this registry
  registered under that type id (`_accepts`, the `is T` test taken at
  `register`).
- **D-2.** `RemoveNodeCommand.capabilities` is static `{structure,
  components}`; `AddNodeCommand.capabilities` is `{structure}` for an
  empty snapshot and `{structure, components}` otherwise. `capability`
  stays `structure` on both.
- **D-4, `regeneration.dart`.** The parametric planner stops planning
  detaches: `_detachLayer`, the dissolve's planned detach and 06 D8's
  `cleanup` list are gone. The `ObjectLayer` and parameter components of
  a lost or dissolved object go with its node.
- **D-7, `table_label_system.dart`.** The 0.4.0 table-data expander
  (`_detachFor` and its branch) goes: the delete itself takes a table's
  data. The label stamping is unchanged.
- **D-8.** Docs: `ParametricView.paramsOf` and `objectsOf`,
  `dissolves`, `_run`, `_plan`, `_written`, `restore`,
  `planner_shell.dart`'s `_deleteByHost`, the table tests' titles.
- **D-6, unchanged.** Loading does not sweep orphans; a plan that carries
  them loads and saves byte for byte. Schema stays 9.

## Commits

| Task | Commits | Content |
|---|---|---|
| 1, the engine | `90044db4` feat(engine): a removed node takes its components (D-1 to D-4) | 12 files, +586/-98 |
| 1, fix round 1 | `d082640e` docs(engine): `objectsOf` names what a lost, deleted and re-parented object keeps (D-8) | doc only; the review's one spec gap |
| 2, the floor plan | `391d9671` feat(floor-plan): the delete takes table data; the expander's detach goes (D-7) | 4 files in `jet_cad_floor_plan` |
| 3, the record | this commit | CHANGELOG, this note, STATUS, the spec's status line |

Task 1's review (Opus): spec one gap (`objectsOf`'s doc, fixed in
`d082640e`), quality *Approved*, no Critical or Important. Task 2's
review (Opus): spec compliant, quality *Approved*, no Critical or
Important.

## Tests

- **New, engine:** `jet_cad_2d/test/document/node_components_test.dart`,
  N-1 to N-7.
  - N-1 a removal takes every component of its handle and no other's.
  - N-2 undo restores the snapshot and the index byte for byte; redo
    removes them again. The node is the middle child of three (final fix
    round), so an inverse that forces the index fails here.
  - N-3 capabilities, and a profile without `components`.
  - N-4 a refused add leaves everything as it was, five cases: an
    unmapped type id with the mapped one sorting first; a type id this
    document maps to a different Dart class (final fix round, M-18); a
    dangling entry in the parent's raw `children`; a definition cycle
    with a mapped snapshot; an index out of range with a mapped
    snapshot.
  - N-5 a compound delete whose second removal fails rolls the first
    back with its components.
  - N-6 a re-parent: bare remove-then-add drops the components, the
    snapshot-carrying one keeps them.
  - N-7 a plan carrying orphans loads and saves byte for byte.
- **New, render:** S-1 in `jet_cad_2d_flutter/test/select_tool_test.dart`
  ('keys and delete'): the select tool's Delete of an instance and of a
  group holding a nested group, all three carrying data.
- **New, floor plan:** `jet_cad_floor_plan/test/delete_components_test.dart`,
  P-1 (a table with table data and an unknown payload, and a wall,
  deleted together), P-2 (a wall alone), P-3 (a wall that hosts a door).
- **Rewritten, floor plan:** TD10 and `_RefusingTarget`
  (`tables/table_data_test.dart`), so a stamp has applied before the
  throw (spec V-1). TD7 to TD7c and HD12 run unedited and still compare
  `encodeToString`.

### The tests re-pinned, and why

The spike at `e281372` saw exactly these seven go red under D-1 (spec
F-14); each is edited as the plan names, and nothing else was edited.

1. `compound_command_test` *"capabilities is the union of the
   children's"*: the expected set gains `Capability.components` (D-2).
2. `cascade_test` CS7: the re-add carries
   `components: doc.components.snapshotOf(hA)` (D-3).
3. `cascade_test` LV2: the same.
4. `objects_of_test` OB1: `h5300`'s re-add carries
   `components: doc.components.snapshotOf(h5300)`.
5. `misplaced_test` MP6: removing the nested group now takes its `Hinge`
   (null after the removal, `const Hinge(true)` after undo, then redo);
   06 ruling 3's recorded cost, *"a misplaced component survives a
   delete"*, no longer holds for a removed group (D-4).
6. `dissolve_test` DV1: a `restoredBy<T>` helper reads the restore off
   the replay's `AddNodeCommand`; the replay no longer holds a
   `SetComponentCommand` for the fuse, and the order list loses the
   `detach` entry.
7. `page_test` PG1: `restoredBy` helper added; a new expectation that no
   `SetComponentCommand<Gauge>` on `hG2` is in `result.inverse`.

Task 2 rewrote TD10 and `_RefusingTarget` and reworded the titles of
TD7, TD9 and the group (TD8's title held no expander wording and is
unchanged). Both lists are the global constraint's named exceptions.

## Rulings that change a claim of the spec or the plan

- **M-5's killers are N-2 and N-5, not N-6.** The spec and the plan name
  N-6. The Task 1 implementer saw N-6 stay green under M-5 (its carrying
  branch compares a fresh unknown order too: the bare branch's undo
  reverses the unknown order and the carrying branch reverses it back);
  the reviewer confirmed it by reading.
- **The N-4 tests take `handleSeed.next()` before the baseline
  encoding.** The encoding includes the seed, so the plan's order failed
  (21 against 22) against a correct implementation. Two tests changed
  their fixture order; no assertion was weakened.
- **P-1 to P-3 compare `canon(doc)`, not `encodeToString`.** `canon`
  (`test/support/wall_fixture.dart`) sorts `entities` by handle and
  compares everything else exactly, components and unknown payloads
  included. Undo of a wall's child-entity removals restores the entities
  into other slots, and the encoder writes slot order (06 D11: slot order
  is history, not state). The reviewer probed P-2 at `391d9671`: the
  encodings differ (`enc equal: false`), `canon` is equal, and the only
  differing top-level key is `entities` (handle order `[20, 21, 22]`
  before, `[21, 20, 22]` after undo). So the spec's P-1 *"undo restores
  the plan byte for byte"* reads **byte for byte, entities in handle
  order**. The repo already uses `canon` for delete-then-undo
  (`opening_object_test.dart`). The tables' TD7 to TD7c and HD12 still
  compare `encodeToString`.
- **P-2 is not a recorded killer of M-12.** The spec's table names PG1
  and P-2. Under D-1 a re-added cleanup detaches nothing the removal has
  not already taken, so P-2 is expected green under M-12 (read by the
  reviewer, not run). PG1 is M-12's killer, from Task 1's run.
- **Stamp order in TD10 is A before B** (the touched order is the
  compound's), so the plan's arguments stand without the swap fallback.

## Mutations

Each applied alone, run, the red line captured and the file restored from
a saved copy (`cp`, never `git checkout`). Lines are copied from the
reports. M-1 to M-16 are Task 1's, run in `jet_cad_2d` (and S-1 in
`jet_cad_2d_flutter`); M-17 is Task 2's, and Task 2 re-applied M-1, M-2
and M-15 to `commands.dart` against the floor plan's suites. M-18 and the
`index: 0` probe (X-0) are the final fix round's own runs, in
`jet_cad_2d`; the final review's re-runs of M-17, M-3, M-12, M-5 and M-14
and its own X-0 probe are listed under Gates.

| Mutant | Killed by | Red line (report) |
|---|---|---|
| M-1 no `detachAll` in `RemoveNodeCommand` | N-1, N-2, N-5, N-6, S-1; floor plan: TD7, TD7b, TD7c, TD8, P-1, P-2, P-3, HD12 | `+0 -1: N-1 a removal takes every component of its handle, no other [E]`; S-1: `keeps nothing` with `Expected: true Actual: <false>`; floor plan: `+6 -1: ... TD7 M-H27: a Delete takes the data in the same step...` and `+19 -8: ... HD12 M-H27 (E-9 gate 3): the editor's Delete of table 1 drops its data...` (8 red) |
| M-2 the inverse built without the snapshot | N-2, N-5, N-6, S-1; floor plan: TD7, TD7b, TD7c, TD8, P-1, P-2, P-3, HD12 | `+1 -1: N-2 undo restores the snapshot and the index byte for byte; redo removes them again [E]`; S-1: `Actual: ...components":{},"rawData"`; floor plan: `+19 -8 ... HD12 ...` |
| M-3 the snapshot taken after `detachAll` | N-2 (Task 1's run); TD7, TD7b, TD7c (the final review's run at `a39a2906`) | `+1 -1: N-2 undo restores ... [E]`; floor plan: `00:00 +0 -3: Some tests failed.` |
| M-4 `detachAll` drops registered only | N-1, N-2, N-5, N-6 | `+0 -1: N-1 a removal takes every component of its handle, no other [E]` |
| M-5 `restore` appends unknown payloads reversed | **N-2, N-5** (not N-6) | `+1 -1: N-2 undo restores ... [E]` |
| M-6 `detachAll(handle)` replaced by `clear()` | N-1, N-2, N-5 | `+0 -1: N-1 a removal takes every component of its handle, no other [E]` |
| M-7 `RemoveNodeCommand.capabilities` deleted | N-3 | `+2 -1: N-3 capabilities, and a profile without components [E]` |
| M-8 `AddNodeCommand.capabilities` deleted | N-3 | `+2 -1: N-3 capabilities, and a profile without components [E]` |
| M-9 `restore` before `addNode`, no check | N-4 (cycle), N-4 (index) | `+5 -1: N-4 a refused add leaves everything as it was a definition cycle, with a mapped snapshot [E]` |
| M-10 `checkRestorable` line deleted in `AddNodeCommand` | N-4 (unmapped), N-4 (dangling) | `+3 -1: N-4 ... an unmapped type id, the mapped one sorting first [E]` |
| M-11 the dissolve's planned detach put back | DV1 | `DV1 ... [E]` `Expected: empty Actual: [null]` (`dissolve_test.dart` 231:5, `fuseSets(redoReplay)`) |
| M-12 the cleanup list put back | **PG1** (P-2 not claimed) | `PG1 ... [E]` `Expected: empty Actual: [Instance of 'SetComponentCommand<Gauge>']` `no separate component restore` (`page_test.dart` 235:5) |
| M-13 decode sweeps components of handles that name nothing | N-7 | `+9 -1: N-7 a plan carrying orphans loads and saves byte for byte [E]` |
| M-14 revision 1's rollback instead of the check | N-4 (dangling) | `+4 -1: N-4 ... the same under a parent that already lists the handle, the raw list compared ... [E]` |
| M-15 the inverse built without the index | N-2, N-5; floor plan: TD7b, TD7c, P-1, P-3, HD12 | `+1 -1: N-2 undo restores ... [E]`; floor plan: `+7 -1: ... TD7b the first table deleted and undone...` and `+22 -5` for HD12. TD7 (B last) correctly stays green |
| M-16 `checkRestorable` `break`s after the first entry | N-4 (unmapped), N-4 (dangling) | `+3 -1: N-4 ... an unmapped type id, the mapped one sorting first [E]` |
| M-17 `TableLabelEdit`'s catch skips the derived inverses | TD10 | `00:00 +0 -1: a deleted table takes its data (E-9 gate 3) TD10 all or nothing: a stamp that throws after another stamp puts that one back with the edit [E]`; `Expected: ... ":[200.0,-1.57079632 ...` / `Actual: ... ":[200.0,-2.21656815 ...` (A's label left stamped) |
| M-18 `checkRestorable` checks the type id only (the `_accepts` test removed) | N-4 (different class) | `00:00 +10 -1: Some tests failed.`; `+4 -1: N-4 a refused add leaves everything as it was a type id this document maps to a different class [E]`; `Which: returned <null>` (`node_components_test.dart` 291:7, the add did not throw) |
| X-0 probe: the inverse built with `index: 0` in `RemoveNodeCommand` | N-2, N-5 | `00:00 +1 -1: N-2 undo restores the snapshot and the index byte for byte; redo removes them again [E]`; `00:00 +7 -2: N-5 a compound delete whose second removal fails rolls the first back with its components [E]`; `00:00 +9 -2: Some tests failed.` |

Notes from the reports:

- M-12 was reconstructed as `cleanup = [for (final h in lost)
  before.objects[h]!.detach(h)]` prepended to the plan (the layer detach
  omitted); the `SetComponentCommand<Gauge>` in the inverse is what PG1
  pins. M-11 and M-12 re-use `_Registration.detach`.
- M-13 is mutated at the `doc.rawData.loadJson` call in
  `json_codec.dart` (the codec's `decode`).
- M-1 and M-2 run through S-1 in `jet_cad_2d_flutter`, both red.
- The recorded M-1, M-2, M-15 floor plan kills confirm the spec's
  expectation (TD7 and HD12 for M-1, TD7 and P-1 for M-2, TD7b for M-15)
  with the expander's detach gone: M-1 and M-2 are no longer masked by
  it.
- M-3's spec table adds TD7 as a "review run" killer. Task 1's run
  pasted one red line, N-2's (its report's table also lists N-5 and N-6,
  with no line for them; the row above names N-2 only). The floor plan
  re-check of M-3 was not part of Task 2's plan. The final review ran it
  at `a39a2906`: TD7, TD7b and TD7c red, which settles the claim.
- X-0 (the inverse's index forced to 0) survived all of
  `node_components_test.dart` while N-2's node sat at index 0, and was
  killed only by `node_index_undo_test.dart` (host spec O-10). N-2 now
  removes the middle child, and X-0 turns N-2 and N-5 red.

## Gates

The `Some tests failed` lines are the standing failures on this machine
(macOS), measured at `e281372`: `jet_cad_2d`'s two `generate_document_test`
fingerprints and `jet_cad_2d_flutter`'s five text-ladder goldens. CI on Linux compares its own lists exactly
(`tool/ci/standing_failures.txt`) and is the check of record for them.

**Task 1** (at `90044db4`; `task-1-report.md`):

- `jet_cad_2d`: `dart test` -> `00:06 +1280 -2: Some tests failed.`
  failing only `generate_document_test` *"both text fractions default to
  zero and change nothing"* and *"the default document is the one Plan 2
  measured, byte for byte"* (the two standing). `dart analyze
  --fatal-infos` -> `No issues found!`; format -> `Formatted 172 files
  (0 changed)`.
- `jet_cad_2d_flutter`: `flutter test` -> `00:19 +1432 ~1 -5: Some tests
  failed.` failing only the five `text_ladder_golden` rungs 1-5
  (standing). Analyze `No issues found!`; format `Formatted 228 files
  (0 changed)`.
- `jet_cad_2d_gpu`: `+20: All tests passed!`, analyze clean, format 0
  changed.
- `jet_cad_restaurant_symbols`: `+97: All tests passed!`, analyze clean,
  format 0 changed.
- `apps/floor_planner`: `+212: All tests passed!`, analyze clean, format
  0 changed.
- `apps/restaurant_demo`: `+68: All tests passed!`, analyze clean, format
  0 changed.
- `jet_cad_floor_plan` (`--enable-vmservice`): `01:49 +1912: All tests
  passed!`, analyze `No issues found!`, format 0 changed.
- Before the mutants, S-1: `+22: All tests passed!` (`select_tool_test`).

**Task 1, fix round 1** (`d082640e`, doc only): `dart analyze
--fatal-infos` -> `No issues found!`; format -> `Formatted 172 files (0
changed)`; `dart test test/parametric/objects_of_test.dart` -> `00:00 +1:
All tests passed!`.

**Task 2** (at `391d9671`; `task-2-report.md`):

- `jet_cad_floor_plan`: `flutter test --enable-vmservice` -> `01:45
  +1915: All tests passed!` (1912 and P-1 to P-3). `flutter analyze` ->
  `No issues found! (ran in 3.1s)`; format -> `Formatted 281 files (0
  changed)`.
- `apps/floor_planner`: `00:33 +212: All tests passed!`; analyze `No
  issues found!`; format `Formatted 47 files (0 changed)`.
- `apps/restaurant_demo`: `00:19 +68: All tests passed!`; analyze `No
  issues found!`; format `Formatted 9 files (0 changed)`.
- P-1 to P-3 with the expander still installed (plan Step 2): `00:00 +3:
  All tests passed!` (after the `canon` change).
- TD10 on the code: `00:00 +12: All tests passed!`.
- `jet_cad_2d`, `jet_cad_2d_flutter` and `jet_cad_2d_gpu` were not
  touched by Task 2 (Task 1's `commands.dart` was mutated and restored,
  `cmp` clean, `git status` clean).

**Final review** (fresh, whole branch, a scratch worktree at `a39a2906`;
`final-review.md`, archived with the ledger). Flutter 3.47.6, this machine.
Lines copied from it:

- `packages/jet_cad_2d`: `dart test` -> `00:06 +1280 -2: Some tests
  failed.` (the two standing `generate_document_test` fingerprints);
  `dart analyze --fatal-infos` -> `No issues found!`; format -> `Formatted
  172 files (0 changed) in 0.38 seconds.`
- `packages/jet_cad_2d_flutter`: `flutter test` -> `00:26 +1432 ~1 -5:
  Some tests failed.` (the five text-ladder rungs); analyze `No issues
  found! (ran in 3.9s)`; format `Formatted 228 files (0 changed) in 0.44
  seconds.`
- `packages/jet_cad_2d_gpu`: `00:02 +20: All tests passed!`; analyze `No
  issues found! (ran in 2.6s)`; format `Formatted 10 files (0 changed) in
  0.01 seconds.`
- `packages/jet_cad_restaurant_symbols`: `00:01 +97: All tests passed!`;
  analyze `No issues found! (ran in 3.0s)`; format `Formatted 15 files (0
  changed) in 0.03 seconds.`
- `apps/floor_planner`: `00:32 +212: All tests passed!`; analyze `No
  issues found! (ran in 3.6s)`; format `Formatted 47 files (0 changed) in
  0.12 seconds.`
- `apps/restaurant_demo`: `00:18 +68: All tests passed!`; analyze `No
  issues found! (ran in 3.4s)`; format `Formatted 9 files (0 changed) in
  0.06 seconds.`
- `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice` ->
  `01:52 +1915: All tests passed!`; analyze `No issues found! (ran in
  6.6s)`; format `Formatted 281 files (0 changed) in 1.06 seconds.`

The final review's mutant re-runs (each applied alone, restored from a
`cp` copy, `cmp` clean, `git status --short` empty at the end):

- **M-17**, TD10: `00:00 +0 -1: ... TD10 all or nothing: a stamp that
  throws after another stamp puts that one back with the edit [E]`.
  Killed.
- **M-3**, floor plan TD7 to TD7c: TD7, TD7b and TD7c red, `00:00 +0 -3:
  Some tests failed.`
- **M-12**: PG1 `+0 -1: PG1 ... [E]`, killed; `delete_components_test.dart`
  `00:00 +3: All tests passed!` (P-2 does not kill M-12, as ruled).
- **M-5**, `node_components_test.dart`: N-2 `[E]` and N-5 `[E]`, ending
  `+8 -2: Some tests failed.`; N-6 stayed green, as ruled.
- **M-14**: `+4 -1: N-4 ... the same under a parent that already lists the
  handle, the raw list compared ... [E]`. Killed.
- **X-0** (the inverse's index forced to 0): `node_components_test.dart`
  stayed green (N-2's node sat at index 0); `node_index_undo_test.dart`
  killed it, N2, N3b, N4, N6 and N7 red, `+17 -7`.

**Final fix round** (the working tree after `a39a2906`; the engine's
`component.dart` changed, so every consumer was re-run). Standing failures
as above, nothing else red:

- `packages/jet_cad_2d`: `dart test` -> `00:06 +1281 -2: Some tests
  failed.` (the two standing); `dart analyze --fatal-infos` -> `No issues
  found!`; format -> `Formatted 172 files (0 changed) in 0.41 seconds.`
- `packages/jet_cad_2d_flutter`: `00:23 +1432 ~1 -5: Some tests failed.`
  (the five text-ladder rungs); analyze `No issues found! (ran in 3.2s)`;
  format `Formatted 228 files (0 changed) in 0.46 seconds.`
- `packages/jet_cad_2d_gpu`: `00:00 +20: All tests passed!`; analyze `No
  issues found! (ran in 2.5s)`; format `Formatted 10 files (0 changed)`.
- `apps/floor_planner`: `00:33 +212: All tests passed!`; analyze `No
  issues found! (ran in 3.7s)`; format `Formatted 47 files (0 changed)`.
- `apps/restaurant_demo`: `00:17 +68: All tests passed!`; analyze `No
  issues found! (ran in 3.0s)`; format `Formatted 9 files (0 changed)`.
- `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice` ->
  `01:56 +1915: All tests passed!`; analyze `No issues found! (ran in
  3.4s)`; format `Formatted 281 files (0 changed) in 0.96 seconds.`
- `node_components_test.dart` alone: `00:00 +11: All tests passed!`.

The two allocation invariants (`query_allocation_test`,
`paint_allocation_test`) and every image golden are untouched. The
branch's CI run is the check of record for the Linux standing lists.

## What this discharges

- **The host embedding spec's F-14** (*"A component is attached per
  handle"*; `RemoveNodeCommand` keeps components): settled. A removed
  node takes its components, undo restores them in the same order, and
  the spike at `e281372` that spec F-14 describes held.
- **The Slice 2 orphaning note** (`host-embedding-api-design.md:587-589`,
  *"The orphaning on delete still happens to every other component of
  every deleted node (a wall's or room's parameters)"*) and its
  **O-8**: settled for every node a `RemoveNodeCommand` removes. The
  note's sentence about walls and rooms **overstated** even at 0.4.0
  (this spec's F-8): the parametric layer's 06 D8 cleanup already
  detached a live object's parameters and layer, so in the floor planner
  a wall's or room's parameters did not orphan. What orphaned was every
  component of a node that is not a live object of a registered type (an
  instance's other than table data, a nested group's, a preserve-unknown
  payload a newer release wrote on any node) and every component of every
  removed node in a document without a `ParametricSystem`. Those are what
  this change fixes; for objects it replaces the cleanup (D-4).
- That spec's text is not edited (O-5 here): this note and the spec are
  the record.

## Out of scope, unchanged

O-1 to O-7 stand as the spec records them: `RemoveEntityCommand` and its
inverses leave components on a removed leaf handle (O-1); no
`validate()` diagnostic for components on dead handles (O-2); no
purge-time sweep of registered types on dead handles (O-3); `loadJson`
does not raise the handle seed past component handles (O-4); the shipped
host spec's text is not edited (O-5); `rawData` is not on
`CommandTarget`, so a deleted node's raw data stays (O-6); after D-7 a
hand-built `SetComponentCommand<FloorPlanTableData>` onto a dead handle
persists (O-7).

## The final review, and what became of its findings

Final review of the whole branch (`final-review.md`): no Critical, no
Important; ready to merge with fixes. Nothing below changes behaviour the
tests pin, apart from the cross-document snapshot, which is now closed.

- **Fixed, text only.** DV1's title and comment
  (`dissolve_test.dart`), P-2's title (`delete_components_test.dart`),
  TD9's title (`table_data_test.dart`), PG1's comment reflow
  (`page_test.dart`).
- **Fixed, N-2's fixture.** The removed node is the middle of three
  children, so the new file stands on its own for the index (X-0 above).
- **Fixed, the cross-document snapshot (was out of scope).** A snapshot
  whose type id maps here to a different Dart class used to pass
  `checkRestorable` and then fail after `addNode` wrote, breaking I-3
  (`RemoveDefinitionCommand` had the same gap before this branch).
  `checkRestorable` now refuses it with a `StateError` before any write;
  N-4's fifth case pins it and M-18 turns it red.
- **Left.** `_Registration.detach` (`parametric_system.dart:793`) is dead
  in `lib`, kept only as M-11's and M-12's template. Fixture breadth
  (plan-mandated): the sibling and S-1's three handles share one
  `ObjectLayer` value and the `a.earlier` payload; P-1 to P-3 have no
  surviving sibling with the same types, and P-1's table carries one
  unknown payload where the constraint asks for two. A leftover `derived`
  / `else continue` in `TableLabelEdit`'s loop (`table_label_system.dart:93-99`),
  brief-permitted.
