# A removed node takes its components — design

**Date:** 2026-10-09, revisions 2 and 3 2026-10-10. **Status:** design,
**revision 3, approved by the human on 2026-10-10**; plan
[2026-10-10-node-components-on-delete.md](../plans/2026-10-10-node-components-on-delete.md).
Revision 1 (`c3c0c4b`, merged into `main` as docs only
through PR #10 at `b5bef3a`) was written at `85905bd` (release 0.3.0).
Revision 2 (`e8b48a9`) re-read every fact at `e281372` (release 0.4.0 and
its STATUS), re-ran the spike there, and changed D-1's all-or-nothing
mechanism and D-7 (the 0.4.0 table-data expander); see
[Revisions](#revisions). Revision 2 was reviewed independently:
**Approve with fixes**, V-1 to V-11, no redesign. Revision 3 folds in
every fix; see [Review](#review).

**Asked for by the human, 2026-10-09:** `RemoveNodeCommand` removes the
tree node but never detaches the node's components, so a deleted node's
components stay in the saved plan on a dead handle forever. Found by the
independent review of the host embedding API spec
(`2026-10-09-host-embedding-api-design.md`, review V-1, recorded there as
**O-8**, out of scope; that spec shipped in 0.4.0). Goal: deleting a node
drops its components and undo restores them exactly (registered and
preserve-unknown alike, in the same order), with no schema change for a
plan that never had orphans.

**Branch:** `spec/node-components-on-delete`, from `main` at `e281372`.
**Size:** S. **Touched:** `jet_cad_2d` (commands, the component registry,
the parametric planner), `jet_cad_floor_plan` (the table system), tests
in `jet_cad_2d`, `jet_cad_2d_flutter` and `jet_cad_floor_plan`, the
CHANGELOG.

## Facts (at `e281372`)

- **F-1. The gap.** `RemoveNodeCommand.apply` (`commands.dart:436-448`)
  reads the node and its index among its parent's `children`
  (`indexInParent`, host spec O-10), `tree.removeNode`s it and returns
  `AddNodeCommand(node, index: index)`; no component is read or touched.
  `AddNodeCommand` (`:384-410`) carries a node and an index only.
- **F-2. The precedent.** `RemoveDefinitionCommand` (`:532-576`) takes
  `components.snapshotOf(handle)`, `detachAll`s it and returns
  `AddDefinitionCommand(definition, components: snapshot)`, which
  `restore`s it after its refusals and before `addDefinition`
  (`:491-513`). Its `capabilities` are **static** `{structure,
  components}` because the dispatcher checks them before `apply` (spec 09c
  W-1, `:526-542`); the add declares `components` only for a non-empty
  snapshot (`:483-485`); `capability` stays `structure` on both.
- **F-3. The snapshot machinery exists.** `ComponentRegistry.snapshotOf`
  (registered ascending by type id, unknown payloads oldest first),
  `detachAll` (registered and unknown) and `restore`
  (`component.dart:156-205`). `restore` is all-or-nothing: it maps every
  registered type id of the snapshot to a store, throwing `StateError`
  for one it does not map, **before** it writes anything; then it writes
  the registered values and appends the unknown payloads in snapshot
  order.
- **F-4. The tree.** `DocumentTree.removeNode` never throws
  (`tree.dart:239-242`) and unlinks **every** occurrence of the handle
  from its parent's `children` (`_unlink`, `_withoutAll`, `:670-683`).
  `addNode(node, {index})` (`:165-181`) throws only before mutating: from
  its cycle guard, for an index outside `0..children.length`
  (`RangeError`), or for an index under a parent with no `children`
  (`ArgumentError`). It then links the handle at `index`, or appends;
  `_link` **skips** the insert when the parent's list already names the
  handle (`:597-600`; it did at `85905bd` too). The list names a handle
  with no node — a dangling entry — after a load of a plan that lists
  one, or after a hand-built `AddNodeCommand(GroupNode(g, children:
  [x]))` for an `x` not yet added: `AddNodeCommand` has no refusal like
  `AddDefinitionCommand`'s non-empty `children` check (`commands.dart:398-410`
  against `:498-504`). The encoder writes `childNodesOf(children)`
  (`json_codec.dart:56, 63`), which drops a dangling entry, so the raw
  list differs from what is saved.
- **F-5. Production permission profiles** are `DraftPermissions.all`,
  `.runtime` and `.readOnly` (`command.dart:53-62`;
  `floor_plan_controller.dart:294, 1194` load with `all`, `:1306` with
  `runtime`). `runtime` and `readOnly` deny `structure`, so they already
  refuse every `RemoveNodeCommand`. No production profile allows
  `structure` without `components`; tests build such profiles
  (`symbol_placer_test.dart:831`, among others). Slice 4's
  `FloorPlanEditorCapabilities` (`editor_capabilities.dart`) gates the
  editor's tools and panels, not commands: it is not a permission
  profile.
- **F-6. Every production `RemoveNodeCommand`** is a delete:
  - the select tool's Delete (`select_tool.dart:760-823`): an instance
    after its owned leaves (`:792-802`), a group's cascade
    (`_groupCascade`, `:829-847`); the per-key permission preflight reads
    each command's `capabilities` (`:812`);
  - the host's `FloorPlanController.deleteSelection`
    (`floor_plan_controller.dart:705-711`, new in 0.4.0), which runs the
    select tool's own delete (`planner_shell.dart:925-929`);
  - the parametric planner's `_subtreeRemoval` (`regeneration.dart:822-879`),
    used for a doomed `cascade` referrer (08 D4) and a dissolving object
    (10 D15).
- **F-7. Every production `AddNodeCommand`** adds a node on a **fresh**
  handle (`startup_plan.dart:329-387`, `symbol_placer.dart:203`, the six
  parametric tools, `generate_document.dart:244, 270, 376`), so none
  carries components to restore. The only other `AddNodeCommand`s are
  `RemoveNodeCommand`'s inverse and tests.
- **F-8. The parametric layer already detaches, for objects.** Inside a
  `ParametricEdit`, 06 D8's cleanup plans `SetComponentCommand<T>(h,
  null)` plus the `ObjectLayer` detach (`_detachLayer`, 12b D2,
  `regeneration.dart:483-490`) for each object **lost** in the edit (live
  before, not after, and `tree[h] == null`) (`:972-983`); a dissolving
  object's plan is `_subtreeRemoval` then the same two detaches
  (`:556-562`). So in the floor planner a wall's or room's parameters and
  layer do **not** orphan today (the host spec's Slice 2 says they do,
  `:587-589`; it overstates). What orphans: every component of a node
  that is not a live object of a registered type — an instance's (other
  than table data, F-12), a nested group's, a preserve-unknown payload a
  newer release wrote on any node — and **every** component of every
  removed node in a document without a `ParametricSystem` (the bare
  engine and `jet_cad_2d_flutter`).
- **F-9. Ruling 06-3** (parametric plan,
  `docs/superpowers/ledgers/2026-09-24-parametric-layer/plan-rulings.md:24-31`)
  narrowed the cleanup to objects live before the edit, because a leaf
  handle has no tree node either and would read as "gone" on every edit.
  Its recorded **cost**: *"a misplaced component survives a delete"*.
  `misplaced_test.dart` MP6 pins that cost for a removed nested group
  (`:246-249`).
- **F-10. Re-parenting is `RemoveNodeCommand(h)` then `AddNodeCommand(h,
  parent: g)` in one compound** (openings spec, *"The re-parent case is
  reachable"*; `cascade_test.dart` CS7 `:405-431`, LV2 `:773-800`;
  `objects_of_test.dart` OB1, `:122-124`). The rule is that a re-parented
  object **keeps its component** (spec 08 D4; `parametric_system.dart:388-389,
  601-602`). No UI path and no host API re-parents; only a hand-built
  command does.
- **F-11. Loading.** `ComponentRegistry.loadJson` keeps every entry as
  read, unknown types verbatim (`component.dart:273-292`); it does not ask
  whether the handle names anything, and does not raise the handle seed.
  The tree, tables and entities raise it (`json_codec.dart:141-274`).
- **F-12. The 0.4.0 table-data expander.** `TableLabelSystem`
  (`table_label_system.dart`) wraps every edit in a `TableLabelEdit`;
  after the edit, per touched handle, `_detachFor` (`:134-142`, called at
  `:96`) plans `SetComponentCommand<FloorPlanTableData>(h, null)` for a
  handle that names nothing live and still carries table data (host spec
  E-6, E-9 gate 3), all or nothing, its inverse replayed under
  `inner.capabilities`. So a deleted **table**'s host data does not
  orphan in 0.4.0. `tables/table_data_test.dart` TD7, TD7b, TD7c
  (`:249-447`) and `host/table_data_test.dart` HD12 (`:458`) pin the
  outcome (M-H27): after a delete the plan has no entry for the table,
  one undo step, undo writes the plan back byte for byte, redo drops it
  again.
- **F-13. Schema 9** (`schema_version.dart:48`), since 0.4.0. Its reason
  is host data a 0.3.0 terminal could neither see nor keep consistent,
  among it a deleted table's data left orphaned (host spec Slice 2,
  `:572-577`).
- **F-14. A spike** (throwaway, in a scratch worktree at `e281372`,
  deleted): D-1 of this revision alone (the check, then `addNode`, then
  `restore`; the static capabilities of D-2), against the three suites.
  `jet_cad_floor_plan` (`--enable-vmservice`, as CI): **1912 pass**, TD7
  to TD7c and HD12 among them. `jet_cad_2d_flutter`: only the five
  text-ladder goldens fail, as they do at `e281372` on this machine.
  `jet_cad_2d`: 1263 pass; the two standing `generate_document_test`
  fingerprints fail (they fail at `e281372` too), and **seven** that this
  design changes on purpose, the same seven as revision 1's spike at
  `85905bd`: `compound_command_test` *capabilities is the union* (F-2's
  static set), CS7, LV2 and OB1 (F-10), MP6 (F-9), DV1 and PG1 (they read
  the undo replay and expect the cleanup's detach to carry the restore,
  F-8). With `_detachFor`'s branch also removed (D-7):
  `jet_cad_floor_plan` **1912 pass**; then, each applied alone and the
  file restored from a copy, M-1 turns TD7 and HD12 red, M-2 turns TD7
  red, and M-15 turns TD7b red.

## Decisions

### D-1. The fix lives in `RemoveNodeCommand` and `AddNodeCommand`

A node's components are part of the node's lifetime, as a definition's
already are (F-2). `RemoveNodeCommand.apply`:

1. reads the node (missing → `StateError`, as today) and its
   `indexInParent`, as today;
2. `snapshot = components.snapshotOf(handle)`;
3. `tree.removeNode(handle)` (cannot throw, F-4);
4. `components.detachAll(handle)`;
5. returns `AddNodeCommand(node, index: index, components: snapshot)`,
   `touched: {handle}`.

`AddNodeCommand` gains `final ComponentSnapshot components` (named,
default `ComponentSnapshot.empty`). `apply`:

1. the duplicate-handle refusal, as today;
2. `components.checkRestorable(handle, components)`: **new** on
   `ComponentRegistry`, the check `restore` already makes before writing
   (F-3), split out so a caller can make it before any other mutation;
   it throws the same `StateError` and writes nothing. `restore` keeps
   making it;
3. `tree.addNode(node, index: index)` (every refusal throws before
   mutating, F-4);
4. `components.restore(handle, components)`, which can no longer throw;
5. raises the seed, `invalidateDerived`, inverse `RemoveNodeCommand`.

Every refusal happens before the first write, so no step is compensated.
Only a snapshot from another document can carry a type id this registry
does not map.

**Rejected:**

- **(A) Revision 1's rollback:** `addNode`, then `restore`, and on its
  throw `tree.removeNode(handle)` and rethrow. Not exact, at `85905bd`
  already: when the parent's list already names the handle (a dangling
  entry, F-4), `addNode`'s `_link` skips the insert and the rollback's
  `_unlink` drops that entry too, so a refused add would change the
  parent's raw `children`. The encoder filters dangling entries, so this
  never reaches a saved plan, but it breaks I-3 in memory.
- **(B) Detach at the delete sites** (a new `ClearComponentsCommand`
  emitted before each `RemoveNodeCommand` by the select tool and
  `_subtreeRemoval`, or an expander per type as 0.4.0 does for table data,
  F-12). It keeps the re-parent idiom untouched, but leaves the bug class
  open: any other caller of `RemoveNodeCommand` — a host's own command, a
  future tool — orphans again, and each new component type needs its own
  expander. The engine owns the invariant or nobody does.
- **(C) A sweep at save or load.** See D-6.

### D-2. Capabilities

- `RemoveNodeCommand.capabilities` = **static** `{structure,
  components}` (the dispatcher checks before `apply`, when the node's
  components are not known: F-2's W-1). `capability` stays `structure`,
  so `SpatialIndex`, `TileCache` and `CompoundCommand.capability` read
  what they read today.
- `AddNodeCommand.capabilities` = `{structure}` for an empty snapshot
  (every production add, F-7), `{structure, components}` otherwise.
- **Consequence:** a profile that allows `structure` and denies
  `components` can no longer delete a node; the select tool's preflight
  (`select_tool.dart:812`) leaves such a key selected (spec D10), and
  the host's `deleteSelection` answers false when it refuses every
  selected object. The same profile now refuses the **undo of any node
  add** and the **redo of a delete**, because both run a
  `RemoveNodeCommand` and the dispatcher checks an inverse's
  `capabilities` (`undo.dart:212, 243, 287-293`; the entry stays on its
  stack, `:214-225`); `RemoveDefinitionCommand` already behaves so. No
  production profile is such (F-5), and deleting a node *is* removing
  its component data, so the refusal is the honest answer.

### D-3. Re-parenting carries the snapshot

The re-parent idiom (F-10) becomes `RemoveNodeCommand(h)` then
`AddNodeCommand(node', components: doc.components.snapshotOf(h))`, the
snapshot read when the compound is built. 08 D4's rule (a re-parented
object keeps its component) is unchanged; it is now stated by the
command rather than by an omission. A bare remove-then-add now means
*delete, then a new empty node on the same handle*. The snapshot is read
when the compound is **built**, so a write to `h`'s components earlier
in the same compound is not in it and is lost: build the snapshot from
the state the removal will see. CS7, LV2 and OB1 are rewritten to the
new idiom; one new case pins the bare form dropping the components
(N-6).

### D-4. The parametric planner stops planning detaches

After D-1, every object 06 D8's cleanup detaches was removed by a
`RemoveNodeCommand` in the same edit (`lost` requires `tree[h] == null`,
and only `RemoveNodeCommand` removes a node), and every dissolving
object's plan ends in one (`_subtreeRemoval` removes `d` last). Each
planned detach is therefore a no-op that still lands in history. So:

- the `cleanup` list (`regeneration.dart:976-983`) and the dissolve's
  `registration.detach(h)` and `_detachLayer(t, h)` (`:560-561`) go;
  `_detachLayer` (`:483-490`) goes with them. `lost` stays: it still
  seeds the closure (Ruling 06-3, 06-4). `if (seeds.isEmpty &&
  cleanup.isEmpty)` (`:1006`) becomes `if (seeds.isEmpty)`: `lost ⊆
  seeds`, and the page seeds (10 D14) only add to `seeds`, so the
  behaviour is unchanged.
- **Outcome unchanged, mechanism superseded:** 06 D8, 10 D15 and 12b
  D2/R-4 still hold (a lost or dissolved object's component and layer
  are gone after the edit and back after undo); the node's own snapshot
  carries them. The doc comments that name the cleanup are rewritten.
- DV1 and PG1 are re-pinned: the undo replay restores the component
  through the `AddNodeCommand` whose snapshot carries it, and holds **no**
  `SetComponentCommand` of that type.
- **Ruling 06-3's cost shrinks.** A misplaced component on a removed
  **node** now goes with it (MP6's lines `:246-249` flip: removing the
  nested group detaches its Hinge, undo restores it). One on a removed
  **leaf** still survives (`RemoveEntityCommand` is untouched, O-1).

### D-5. Callers: what changes

| Caller | Change |
|---|---|
| Select tool Delete, instance (`select_tool.dart:792-802`) | its components go; undo restores. |
| Select tool Delete, group cascade (`:829-847`) | every removed node's components go, nested groups' included. |
| Host `FloorPlanController.deleteSelection` (`floor_plan_controller.dart:705-711`) | as the select tool's Delete, which it runs. |
| `_subtreeRemoval`, doomed referrer and dissolve | as above; the planned detaches go (D-4). |
| Parametric tools, `startup_plan`, `symbol_placer`, `generate_document` (`AddNodeCommand` on a fresh handle) | none: empty snapshot, `{structure}` as today. |
| Wall-aware symbols (`wall_attach*`) | none: they place through `symbol_placer` and move by `TransformNodeCommand`. |
| `TableLabelSystem` (`table_label_system.dart`) | `_detachFor` and its branch go (D-7); the label stamping (`_stampFor`) is unchanged: a removed table is not a live instance, so it returns null as today. |
| `ParametricReplay` / `TableLabelEdit` replays | carry `inner.capabilities`, which now include `components` for a delete; `all` allows it. |
| Re-parenting (tests only) | must carry the snapshot (D-3). |

### D-6. Loading does not sweep orphans; no schema concern

- **No sweep on load, save or purge.** A plan saved by 0.4.0 or earlier
  may carry components on dead handles; they load and save byte for
  byte, as today. Reasons: (1) preserve-unknown: a reader keeps what it
  cannot interpret, and a handle this build sees as dead may name
  something a newer build models (a table record, a type of node this
  build does not know); (2) a load→save of an unedited plan stays
  byte-identical; (3) nothing **edits** through a dead handle's
  component (the symbol reuse path checks `tree.definition(h) != null`,
  `symbol_placer.dart:105`; the parametric survey reads live objects
  only; the table system stamps live instances only). Orphans are not
  wholly inert, but change no outcome: `ParametricSystem.diagnostics()`
  reports a dead holder as `parametric.misplaced`
  (`parametric_system.dart:618-629`), `validate()` reports an
  `ObjectLayer` naming a missing layer on any handle (`validate.dart:329-337`),
  an orphan parametric component keeps the parametric expander wrapping
  every command (`parametric_system.dart:671-674`), and an orphan
  `SeatingComponent` keeps the table system off its cheap path
  (`table_label_system.dart:49`).
- **Not a schema concern; `kSchemaVersion` stays 9.** The format is
  unchanged. A plan that never had orphans is written exactly as before;
  after this change a delete simply stops adding entries. Every schema-9
  reader (0.4.0 on) reads either kind of plan identically, so a 0.4.0
  terminal and this build share plans as they are; a delete on the 0.4.0
  terminal may still leave the orphans of F-8, which this build keeps.
- Recorded, not done: a validation diagnostic for orphans, a purge-time
  sweep of registered types on dead handles, and raising the seed past
  component handles on load (O-2, O-3, O-4).

### D-7. The table-data expander goes

0.4.0 closed the gap for one type, table data, with an expander at the
delete's edit (F-12): the per-type form D-1 rejects as (B). After D-1,
`RemoveNodeCommand` has detached a deleted table's data before
`TableLabelEdit` reads its `touched`, so `_detachFor` finds no
`FloorPlanTableData` and returns null for every node delete: it never
fires. What it would still reach is table data on a removed **leaf**,
on a handle a file brought in dead, or written onto a dead handle by a
hand-built command, none of which a table delete makes (O-1, O-7).

- `_detachFor` (`table_label_system.dart:134-142`) and its branch in
  `TableLabelEdit.apply` (`:96-98`) go; the file header's and
  `TableLabelEdit`'s doc sentences about the detach (E-6, F-14) are
  rewritten to say the delete itself takes the data. `TableLabelEdit`
  keeps its label stamping, its all-or-nothing and its replay.
- **Why not keep it as a safety net:** for every node delete it is an
  equivalent mutant: deleting it changes no outcome a test can observe,
  so no test can pin it (the testing bar), and it costs a `get` per
  touched handle per edit while there is any servable definition.
- **TD7, TD7b, TD7c and HD12 stay unedited and green** (F-14): they pin
  the outcome (M-H27), which this work keeps for tables and extends to
  every component. With the expander gone they are killers of M-1.
- **TD10 is rewritten** (review V-1). `TableLabelEdit`'s catch
  (`table_label_system.dart:108-115`) undoes the derived commands
  applied so far, then the edit. Its only test, TD10
  (`tables/table_data_test.dart:415-447`), throws after `_detachFor`'s
  detach; after D-1 and D-7 nothing derived has applied before its
  throw, so a catch that skips the derived inverses (M-17) survives:
  the review saw the whole floor-plan suite stay green under it, and the
  author the table and host table-data tests. The new TD10 turns **two**
  tables in one edit, with a `_RefusingTarget` that refuses the geometry
  read of the second stamp once the first stamp has written: the edit
  throws with one stamp applied, and afterwards both labels and the
  encoding are as before. TD8's and TD9's titles and `_RefusingTarget`'s
  doc, which describe the expander's detach, are reworded.
- The host embedding API spec is shipped and is not edited. This work
  discharges its F-14, its Slice 2 note on orphaning and **O-8**; the
  results note and STATUS record it, and that the spec's line on walls
  and rooms (`:587-589`) overstated (F-8). Its E-9 sentence about a
  **0.3.0** terminal orphaning a deleted table's data stays true for
  0.3.0.

### D-8. Docs

- CHANGELOG **Unreleased**: deleting a node removes every component on
  it with it (undo restores them), as 0.4.0 already did for a table's
  host data: a nested group's components, an instance's, and data a
  newer release wrote. Plans are unchanged (schema 9), and orphaned
  entries an older release left in a plan stay as they are. A hand-built
  re-parent (`RemoveNodeCommand` then `AddNodeCommand`) must now carry
  the snapshot to keep the components (D-3).
- The host guide says nothing about components on delete; unchanged.
- The doc comments on `RemoveNodeCommand`, `AddNodeCommand`,
  `ComponentRegistry.restore` (*"which is how `RemoveDefinitionCommand`'s
  inverse uses it"*, `component.dart:183`, gains `RemoveNodeCommand`'s)
  and `checkRestorable`, `ParametricView.paramsOf` and `objectsOf`
  (`parametric_system.dart:386-392, 442-446, 598-604`), `_detachLayer`'s
  and the dissolve's (`regeneration.dart:483-486, 540-551`), `_written`'s
  list (`:686-708`), the table system's (`table_label_system.dart:1-4`,
  `TableLabelEdit`'s, its catch's *"the data detached"* at `:109-110`,
  D-7), `_deleteByHost`'s *"the table-data
  expander"* (`planner_shell.dart:925-929`), and the TD8 to TD10 titles
  and `_RefusingTarget`'s doc (`tables/table_data_test.dart:356, 392,
  415, 452-455`) are brought in line. The host guide's line on deleting
  a table's data (`docs/host-guide.md:1099-1100`) stays true.
- `ComponentRegistry.restore`'s doc keeps *"meant for a handle that
  carries nothing"* and adds why: on a handle that already carries
  unknown payloads it appends duplicates, and the encoding keeps only
  the last per type (review V-11, O-4).

## Invariants

- **I-1.** When `RemoveNodeCommand.apply` returns, no component
  (registered or unknown) sits on its handle: `snapshotOf(handle)` is
  empty. A later command in the same compound may attach to the handle
  again (D-3's re-parent, a `SetComponentCommand`, which checks no
  liveness, `commands.dart:605-618`); that is the caller's write, not a
  leftover.
- **I-2.** Undo of a node removal restores `snapshotOf(handle)` exactly:
  the same registered values (`==`), the same unknown payloads in the
  same order; the encoded document equals the one before the removal,
  byte for byte (the node at its index, host spec O-10, and its
  components). Redo removes them again.
- **I-3.** Every command stays all-or-nothing: a refused `AddNodeCommand`
  (duplicate, cycle, index out of range, unmapped type) leaves the tree,
  every parent's `children` and the components as they were.
- **I-4.** Other handles' components are untouched by a removal.
- **I-5.** A plan loads and saves byte for byte whether or not it carries
  orphans (D-6).

## Testing and named mutants

The fixture is never degenerate: the removed node is **not** the first
handle, sits under a non-root parent at a non-identity transform and
**not** at the end of its parent's `children` (so the index is not the
append), carries **two registered** components with non-default values
(`ObjectLayer` on a non-zero layer and a test type) and **two unknown**
payloads whose type ids are **not** in sorted order (`"z.later"`
attached before `"a.earlier"`, one with a nested map), and has a
**sibling** carrying the same two registered types and one unknown
payload with different values.

**Engine** (`packages/jet_cad_2d/test/document/node_components_test.dart`,
new):

- **N-1** remove: every component of the handle gone (`get` null for
  both types, `unknownOf` empty, `snapshotOf(...).isEmpty`, no entry for
  the handle in `components.toJson()`); the sibling's `snapshotOf` equal
  to before.
- **N-2** undo: `snapshotOf` equal to before (registered `==`, unknown
  payload list equal in order), the node back at its index; `JsonCodec`
  encode equal to before; redo: gone again; undo: back again.
- **N-3** capabilities: `RemoveNodeCommand` → `{structure, components}`,
  `capability` `structure`; `AddNodeCommand` empty → `{structure}`,
  non-empty → `{structure, components}`; a profile with `structure` and
  not `components` refuses the remove (`PermissionDeniedError`) and the
  encoding is unchanged; under that profile a node add is allowed and
  its undo is refused, the entry left on the undo stack (D-2).
- **N-4** all-or-nothing. Every snapshot here is **non-empty**
  (registered and unknown), so *"nothing attached"* is never vacuous:
  - a snapshot taken in a second document carrying a type this one
    maps (`jet_cad.object_layer`) **and**, sorting after it, one it does
    not (`test.foreign`) → throws, the handle is in neither the tree nor
    its parent's `children`, and nothing is attached;
  - the same under a parent whose raw `children` already names the
    handle as a dangling entry, made by
    `AddNodeCommand(GroupNode(g, children: [x]))` before `x` is added
    (F-4) → throws, and `(tree[g] as GroupNode).children` — the raw list,
    not the encoding, which filters dangling entries — equals the list
    before, dangling entry included;
  - one whose node closes a definition cycle, and one whose index is
    out of range, each with a mapped snapshot → throw, nothing attached.
- **N-5** a compound delete (two removals, the second failing) rolls the
  first back with its components (`CompoundCommand`'s rollback replays
  the new inverse).
- **N-6** re-parent: bare remove-then-add drops the components;
  remove-then-add carrying the snapshot keeps them, unknown order
  included.
- **N-7** load: a plan carrying an orphan (registered and unknown, on a
  handle naming nothing) loads and re-encodes byte for byte (I-5).

**Parametric** (existing files, re-pinned per D-3/D-4): CS7, LV2, OB1
carry the snapshot; DV1 and PG1 read the restore off the replay's
`AddNodeCommand`; MP6's removed nested group loses its Hinge and undo
brings it back.

**Render** (`jet_cad_2d_flutter/test/select_tool_test.dart`): **S-1**
the select tool's Delete of an instance and of a group holding a nested
group, all three carrying components (registered and unknown): one undo
step; after it, none of the three handles carries anything; undo
restores all three exactly; redo removes them.

**Floor plan** (`jet_cad_floor_plan/test/delete_components_test.dart`,
new): **P-1** in the shell (both expanders installed): a table instance
carrying table data and an unknown payload (a stand-in for a newer
release's data) and a wall, deleted together: the saved plan has no
entry for either handle; undo restores the plan byte for byte. **P-2** a
wall deleted alone: its `WallParams` and `ObjectLayer` are gone and the
undo replay carries them in the node's snapshot (D-4). TD7 to TD7c and
HD12 run unedited; TD10 is rewritten so a stamp has applied before the
throw (D-7).

| Mutant | Where | Killed by |
|---|---|---|
| M-1 no `detachAll` in `RemoveNodeCommand` | commands | N-1, S-1, P-1, P-2, TD7, HD12 |
| M-2 the inverse built without the snapshot | commands | N-2, S-1, P-1, TD7 |
| M-3 the snapshot taken after `detachAll` | commands | N-2, TD7 (review run) |
| M-4 `detachAll` that drops registered only (keeps `_unknown`) | component | N-1, P-1 |
| M-5 `restore` appends unknown payloads reversed | component | N-2, N-6 |
| M-6 `detachAll` replaced by `clear()` | commands | N-1 (sibling) |
| M-7 `RemoveNodeCommand.capabilities` back to `{structure}` | commands | N-3 |
| M-8 `AddNodeCommand.capabilities` always `{structure}` | commands | N-3 |
| M-9 `AddNodeCommand` restores before `addNode` | commands | N-4 (cycle, index, non-empty snapshot) |
| M-10 no `checkRestorable` before `addNode` | commands | N-4 (unmapped) |
| M-11 the dissolve's planned detach put back | regeneration | DV1 (replay holds a `SetComponentCommand`) |
| M-12 the cleanup list put back | regeneration | PG1, P-2 |
| M-13 a load-time sweep of dead-handle entries | codec | N-7 |
| M-14 revision 1's rollback (A) instead of the check | commands | N-4 (dangling entry) |
| M-15 the inverse built without the index | commands | N-2, TD7b |
| M-16 `checkRestorable` checks only the first type id | component | N-4 (mapped type before the unmapped one) |
| M-17 `TableLabelEdit`'s catch skips the derived inverses | table system | TD10 (rewritten) |

Each mutant is applied, the named test seen red, the file restored from
a copy (never `git checkout`), as the testing bar requires; the results
file records each. The kills of the TD and HD tests listed here were
seen on spikes at `e8b48a9` (F-14, and the review's run, which also saw
M-1 to M-3 turn TD7b, TD7c, TD8 and TD10 red); the plan re-checks them
against its own code.

## Risks

- **A host builds a re-parent by hand** and loses components (D-3). No
  public host API re-parents; the CHANGELOG states the new reading.
- **History entries made before the change** do not exist across a
  load (history is not saved), so no old inverse replays against the new
  behaviour.
- **A 0.4.0 terminal beside this build** (D-6): both read and write
  schema 9; the 0.4.0 one may still leave F-8's orphans, which change no
  outcome here.
- **A host's own command that calls `target.tree.removeNode`** directly
  (review V-9). `DraftCommand` is public (`command.dart:122`) and
  `CommandTarget.tree` is mutable. Today `tree.removeNode` is called only
  by `RemoveNodeCommand` (`commands.dart:442`), by `repairCycles` and by
  the codec's `clear`, both at load. Such a command on a parametric
  object loses 0.4.0's cleanup after D-4, so its component and layer
  orphan where they did not. The invariant belongs to
  `RemoveNodeCommand`, as D-1 says; a host removes a node through it.

## Out of scope, recorded

- **O-1.** `RemoveEntityCommand` and its inverses (`AddEntityCommand`,
  `AddRegionCommand`) leave components on a removed **leaf** handle. Only
  a file can put one there today (MP6's misplaced Hinge on a line); its
  own task if a writer appears.
- **O-2.** A `validate()` diagnostic for components on dead handles.
- **O-3.** A purge-time sweep of **registered** types on dead handles
  (unknown payloads would stay, D-6).
- **O-4.** `loadJson` does not raise the handle seed past component
  handles (F-11): a hand-made file whose seed is below an orphan's handle
  could hand that handle to a new node, which would inherit the orphan.
  Every file jet-cad writes saves a seed above every handle it ever
  issued. Such a node would also make an undone add `restore` onto a
  handle that already carries the orphan: unknown payloads would then
  appear twice, and the encoding keep the last per type (review V-11).
- **O-5.** The shipped host embedding API spec's text (F-14, the Slice 2
  note, O-8) is not edited (D-7).
- **O-6.** `rawData` (`RawDataStore`, keyed by handle, `raw_data.dart:11`)
  is not on `CommandTarget` (`command.dart:88-109`), so no command, this
  `RemoveNodeCommand` included, drops a deleted node's raw data. Only a
  load writes it (`json_codec.dart:135`): file-borne only, like O-1
  (review V-8).
- **O-7.** After D-7, a hand-built `SetComponentCommand<FloorPlanTableData>`
  onto a dead handle persists; 0.4.0's `_detachFor` undid it in the same
  edit. No host API reaches it: `setTablesData` targets live tables
  (`floor_plan_controller.dart:1585-1591`) and `activeDocument` is
  `@internal` (`:800-802`) (review V-8).

## Files (expected)

- `packages/jet_cad_2d/lib/src/document/commands.dart` (D-1, D-2)
- `packages/jet_cad_2d/lib/src/document/component.dart`
  (`checkRestorable`, doc comment)
- `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`,
  `parametric_system.dart` (D-4, doc comments)
- `packages/jet_cad_floor_plan/lib/src/tables/table_label_system.dart`
  (D-7), `planner_shell.dart` (a doc comment, D-8)
- `packages/jet_cad_2d/test/document/node_components_test.dart` (new),
  `compound_command_test.dart`, `test/parametric/{cascade,objects_of,
  misplaced,dissolve,page}_test.dart`
- `packages/jet_cad_2d_flutter/test/select_tool_test.dart`
- `packages/jet_cad_floor_plan/test/delete_components_test.dart` (new),
  `test/tables/table_data_test.dart` (TD10 rewritten, TD8 and TD9
  titles, `_RefusingTarget`'s doc)
- `CHANGELOG.md`, `STATUS.md`, the results note

## Revisions

### Revision 2

Every fact was re-read at `e281372`; what changed against revision 1:

- **F-1, F-4:** `RemoveNodeCommand`'s inverse carries the node's index
  (host spec O-10, merged before 0.4.0), and `addNode` gained two
  refusals and an insert at an index. Revision 1's rollback was found
  inexact, so **D-1** now checks the snapshot before `addNode`
  (`checkRestorable`) and compensates nothing; revision 1's form is
  rejected as (A) and named as M-14. *Corrected in revision 3 (V-3):*
  revision 2 said the O-10 change made the rollback inexact; `_link`
  already skipped an already-listed handle at `85905bd`, so it was
  inexact in revision 1 too.
- **F-5:** `readOnly` is a third production profile; Slice 4's editor
  capabilities are not a profile.
- **F-6:** the host's `deleteSelection` is a new production delete path
  (D-5 row).
- **F-12, D-7:** 0.4.0 shipped an expander that detaches a deleted
  table's data. Revision 1 expected it to plan a no-op detach after the
  node's own; it in fact never fires after D-1, so it is removed, and
  its tests become killers of M-1.
- **F-13, D-6:** schema 9; `kSchemaVersion` stays 9, and a 0.4.0
  terminal shares plans with this build.
- **F-14:** the spike re-run at `e281372`: the same seven intended
  changes in `jet_cad_2d`, nothing new elsewhere.
- **F-8:** records that the host spec's line on walls and rooms
  orphaning overstated.
- Fixture: the removed node is not its parent's last child; N-2, N-4,
  I-2, I-3 and M-15 cover the index.
- Line references throughout are at `e281372`.

### Revision 3

Folds in the independent review of revision 2 (below): TD10 rewritten
and M-17 (V-1); N-4's snapshots non-empty, a mapped type before the
unmapped one, M-16, and the raw-list assertion (V-2); F-4, (A) and the
revision 2 history corrected (V-3); I-1 restated (V-4); D-2's undo and
redo consequence and its N-3 assertion (V-5); D-8's list (V-6); D-6's
"inert" reworded (V-7); O-6, O-7 (V-8); a Risks line (V-9); D-3's
build-time snapshot (V-10); O-4 and `restore`'s doc (V-11); F-9's and
F-10's line references.

## Review

Revision 2 (`e8b48a9`) was reviewed by an independent reviewer:
**Approve with fixes**. The review is in the ledger
(`.superpowers/sdd/2026-10-09-node-components-on-delete/spec-review.md`,
archived on merge). The reviewer re-ran the spike in its own scratch
worktree and every count of F-14 matched; F-1 to F-14 held but F-4
(partly, V-3) and two line references (F-9, F-10). A second reviewer
(Copilot CLI) did not run: its monthly quota was exhausted. The author
re-checked V-1 on a spike (the M-17 mutant: killed by TD10 at
`e8b48a9`'s code, alive with D-1 and D-7 across the floor plan's table
tests), V-3 (`git show 85905bd`), and V-2's encoder claim.

| Finding | Severity | Disposition |
|---|---|---|
| V-1 D-7 leaves `TableLabelEdit`'s rollback unpinned | Major | Accepted: TD10 rewritten so a stamp applies before the throw; M-17 named (D-7, Testing) |
| V-2 N-4 leaves M-9, a first-type-only mutant and M-14's kill conditional | Minor | Accepted: non-empty snapshots, a mapped type before the unmapped one, M-16 named, the raw `children` asserted (N-4) |
| V-3 (A)'s defect misdated; a dangling entry needs no file | Minor | Accepted: F-4, D-1 (A) and Revision 2 corrected; N-4 builds the entry with `AddNodeCommand` |
| V-4 I-1 false for the re-parent idiom | Minor | Accepted: I-1 stated about `RemoveNodeCommand.apply` |
| V-5 D-2 omits undo of an add and redo of a delete | Minor | Accepted: D-2 consequence, N-3 assertion |
| V-6 stale docs D-8 misses | Minor | Accepted: D-8 lists `planner_shell.dart`, the TD8 to TD10 titles, `_RefusingTarget`, the catch's comment |
| V-7 "the orphans are inert" overstates | Info | Accepted: D-6 reworded; no-sweep stands |
| V-8 `rawData`; table data written onto a dead handle | Info | Accepted: O-6, O-7 |
| V-9 a host command calling `tree.removeNode` | Info | Accepted: Risks |
| V-10 the re-parent snapshot is read at build time | Info | Accepted: D-3 |
| V-11 `restore` duplicates unknown payloads on a carrying handle | Info | Accepted: O-4 note, `restore`'s doc (D-8) |
