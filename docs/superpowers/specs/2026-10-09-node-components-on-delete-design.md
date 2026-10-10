# A removed node takes its components — design

**Date:** 2026-10-09. **Status:** design, **revision 1**.

**Asked for by the human, 2026-10-09:** `RemoveNodeCommand` removes the
tree node but never detaches the node's components, so a deleted node's
components stay in the saved plan on a dead handle forever. Found by the
independent review of the host embedding API spec
(`2026-10-09-host-embedding-api-design.md` on
`claude/exciting-pasteur-9m22jv`, review V-1, recorded there as **O-8**,
out of scope). Goal: deleting a node drops its components and undo
restores them exactly (registered and preserve-unknown alike, in the same
order), with no schema change for a plan that never had orphans.

**Branch:** `claude/dazzling-easley-7e2a09`, from `main` at `85905bd`
(release 0.3.0 and its STATUS). **Size:** S. **Touched:** `jet_cad_2d`
(commands, the parametric planner), tests in `jet_cad_2d`,
`jet_cad_2d_flutter` and `jet_cad_floor_plan`, the CHANGELOG.

## Facts (at `85905bd`)

- **F-1. The gap.** `RemoveNodeCommand.apply` (`commands.dart:422-433`)
  reads the node, `tree.removeNode`s it and returns `AddNodeCommand(node)`;
  no component is read or touched. `AddNodeCommand` (`:378-403`) carries a
  node only.
- **F-2. The precedent.** `RemoveDefinitionCommand` (`:517-561`) takes
  `components.snapshotOf(handle)`, `detachAll`s it and returns
  `AddDefinitionCommand(definition, components: snapshot)`, which
  `restore`s it after its refusals (`:476-498`). Its `capabilities` are
  **static** `{structure, components}` because the dispatcher checks them
  before `apply` (spec 09c W-1, `:511-516`); the add declares
  `components` only for a non-empty snapshot (`:467-470`); `capability`
  stays `structure` on both.
- **F-3. The snapshot machinery exists.** `ComponentRegistry.snapshotOf`
  (registered ascending by type id, unknown payloads oldest first),
  `detachAll` (registered and unknown) and `restore` (all-or-nothing: an
  unmapped type id throws before any write; unknown payloads appended in
  snapshot order) (`component.dart:153-205`).
- **F-4. The tree.** `DocumentTree.removeNode` never throws; `addNode`
  throws only from its cycle guard, **before** mutating, and appends the
  handle to its parent's `children` (`tree.dart:155-209`).
- **F-5. Production permission profiles** are `DraftPermissions.all` and
  `.runtime` (`command.dart:53-62`; `floor_plan_controller.dart:137, 663,
  760`). `runtime` denies `structure`, so it already refuses every
  `RemoveNodeCommand`. No production profile allows `structure` without
  `components`; tests build such profiles (`symbol_placer_test.dart:831`,
  among others).
- **F-6. Every production `RemoveNodeCommand`** is a delete:
  - the select tool's Delete: an instance after its owned leaves
    (`select_tool.dart:707-714`), a group's cascade
    (`:740-758`);
  - the parametric planner's `_subtreeRemoval` (`regeneration.dart:822-880`),
    used for a doomed `cascade` referrer (08 D4) and a dissolving object
    (10 D15).
- **F-7. Every production `AddNodeCommand`** adds a node on a **fresh**
  handle (`startup_plan.dart:329-387`, `symbol_placer.dart:203`, the six
  parametric tools, `generate_document.dart`), so none carries components
  to restore. The only other `AddNodeCommand`s are `RemoveNodeCommand`'s
  inverse and tests.
- **F-8. The parametric layer already detaches, for objects.** Inside a
  `ParametricEdit`, 06 D8's cleanup plans `SetComponentCommand<T>(h,
  null)` plus the `ObjectLayer` detach (`_detachLayer`, 12b D2) for each
  object **lost** in the edit (live before, not after, and
  `tree[h] == null`) (`regeneration.dart:975-982`); a dissolving object's
  plan is `_subtreeRemoval` then the same two detaches
  (`:557-562`). So in the floor planner a wall's or room's parameters and
  layer do **not** orphan today. What orphans: every component of a node
  that is not a live object of a registered type — an instance's (the
  host spec's `jetcad.table_data`), a nested group's, a preserve-unknown
  payload a newer release wrote on any node — and **every** component of
  every removed node in a document without a `ParametricSystem` (the bare
  engine and `jet_cad_2d_flutter`).
- **F-9. Ruling 06-3** (parametric plan, `plan-rulings.md:24-31`) narrowed
  the cleanup to objects live before the edit, because a leaf handle has
  no tree node either and would read as "gone" on every edit. Its
  recorded **cost**: *"a misplaced component survives a delete"*.
  `misplaced_test.dart` MP6 pins that cost for a removed nested group
  (`:245-248`).
- **F-10. Re-parenting is `RemoveNodeCommand(h)` then `AddNodeCommand(h,
  parent: g)` in one compound** (openings spec, *"The re-parent case is
  reachable"*; `cascade_test.dart` CS7 `:406-431`, LV2 `:774-798`;
  `objects_of_test.dart` OB1). The rule is that a re-parented object
  **keeps its component** (spec 08 D4; `parametric_system.dart:389, 601`).
  No UI path re-parents; only a hand-built command does.
- **F-11. Loading.** `ComponentRegistry.loadJson` keeps every entry as
  read, unknown types verbatim (`component.dart:273-292`); it does not ask
  whether the handle names anything, and does not raise the handle seed.
  The tree, tables and entities raise it (`json_codec.dart:136-274`).
- **F-12. A spike** (throwaway, in a scratch worktree, deleted): the
  RemoveNode/AddNode change of D-1 alone, against the three suites.
  `jet_cad_floor_plan`: 1437 pass. `jet_cad_2d_flutter`: only the five
  text-ladder goldens fail, as they do at `85905bd` on this machine.
  `jet_cad_2d`: the two standing `generate_document_test` fingerprints
  (fail at `85905bd` too) and **seven** that this design changes on
  purpose: `compound_command_test` *capabilities is the union* (F-2's
  static set), CS7, LV2 and OB1 (F-10), MP6 (F-9), DV1 and PG1 (they read
  the undo replay and expect the cleanup's detach to carry the restore,
  F-8).

## Decisions

### D-1. The fix lives in `RemoveNodeCommand` and `AddNodeCommand`

A node's components are part of the node's lifetime, as a definition's
already are (F-2). `RemoveNodeCommand.apply`:

1. reads the node (missing → `StateError`, as today);
2. `snapshot = components.snapshotOf(handle)`;
3. `tree.removeNode(handle)` (cannot throw, F-4);
4. `components.detachAll(handle)`;
5. returns `AddNodeCommand(node, components: snapshot)`, `touched:
   {handle}`.

`AddNodeCommand` gains `final ComponentSnapshot components` (named,
default `ComponentSnapshot.empty`). `apply`:

1. the duplicate-handle refusal, as today;
2. `tree.addNode(node)` (its guard throws before mutating);
3. `components.restore(handle, components)`; if it throws (a type id
   this registry does not map: only a snapshot from another document can
   carry one), `tree.removeNode(handle)` and rethrow. That is exact: the
   handle was not in the tree, and `addNode` only appended it to its
   parent's `children`;
4. raises the seed, `invalidateDerived`, inverse `RemoveNodeCommand`.

**Rejected:**

- **(B) Detach at the delete sites** (a new `ClearComponentsCommand`
  emitted before each `RemoveNodeCommand` by the select tool and
  `_subtreeRemoval`, or the host spec's expander per type). It keeps
  the re-parent idiom untouched, but leaves the bug class open: any
  other caller of `RemoveNodeCommand` — a host's own command, a future
  tool — orphans again. The engine owns the invariant or nobody does.
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
  (`select_tool.dart:725`) leaves such a key selected (spec D10). No
  production profile is such (F-5), and deleting a node *is* removing its
  component data, so the refusal is the honest answer.

### D-3. Re-parenting carries the snapshot

The re-parent idiom (F-10) becomes `RemoveNodeCommand(h)` then
`AddNodeCommand(node', components: doc.components.snapshotOf(h))`, the
snapshot read when the compound is built. 08 D4's rule (a re-parented
object keeps its component) is unchanged; it is now stated by the
command rather than by an omission. A bare remove-then-add now means
*delete, then a new empty node on the same handle*. CS7, LV2 and OB1 are
rewritten to the new idiom; one new case pins the bare form dropping the
components (D-8, N-6).

### D-4. The parametric planner stops planning detaches

After D-1, every object 06 D8's cleanup detaches was removed by a
`RemoveNodeCommand` in the same edit (`lost` requires `tree[h] == null`,
and only `RemoveNodeCommand` removes a node), and every dissolving
object's plan ends in one (`_subtreeRemoval` removes `d` last). Each
planned detach is therefore a no-op that still lands in history. So:

- the `cleanup` list (`regeneration.dart:975-982`) and the dissolve's
  `registration.detach(h)` and `_detachLayer(t, h)` (`:560-561`) go;
  `_detachLayer` goes with them. `lost` stays: it still seeds the
  closure (Ruling 06-3, 06-4). `if (seeds.isEmpty && cleanup.isEmpty)`
  becomes `if (seeds.isEmpty)` (`lost ⊆ seeds`, so the behaviour is
  unchanged).
- **Outcome unchanged, mechanism superseded:** 06 D8, 10 D15 and 12b
  D2/R-4 still hold (a lost or dissolved object's component and layer
  are gone after the edit and back after undo); the node's own snapshot
  carries them. The doc comments that name the cleanup are rewritten.
- DV1 and PG1 are re-pinned: the undo replay restores the component
  through the `AddNodeCommand` whose snapshot carries it, and holds **no**
  `SetComponentCommand` of that type.
- **Ruling 06-3's cost shrinks.** A misplaced component on a removed
  **node** now goes with it (MP6's line `:245-248` flips: removing the
  nested group detaches its Hinge, undo restores it). One on a removed
  **leaf** still survives (`RemoveEntityCommand` is untouched, O-1).

### D-5. Callers: what changes

| Caller | Change |
|---|---|
| Select tool Delete, instance (`select_tool.dart:707-714`) | its components go; undo restores. The host spec's `jetcad.table_data` needs no expander (D-7). |
| Select tool Delete, group cascade (`:740-758`) | every removed node's components go, nested groups' included. |
| `_subtreeRemoval`, doomed referrer and dissolve | as above; the planned detaches go (D-4). |
| Parametric tools, `startup_plan`, `symbol_placer`, `generate_document` (`AddNodeCommand` on a fresh handle) | none: empty snapshot, `{structure}` as today. |
| Wall-aware symbols (`wall_attach*`) | none: they place through `symbol_placer` and move by `TransformNodeCommand`. |
| `TableLabelSystem`'s expander (`table_label_system.dart:43-50`) | none: it wraps the edit and stamps labels by `touched`; a removed table is not a live instance, so `_stampFor` returns null as today. |
| `ParametricReplay` / `TableLabelEdit` replays | carry `inner.capabilities`, which now include `components` for a delete; `all` allows it. |
| Re-parenting (tests only) | must carry the snapshot (D-3). |

### D-6. Loading does not sweep orphans; no schema concern

- **No sweep on load, save or purge.** A plan saved by 0.3.0 or earlier
  may carry components on dead handles; they load and save byte for
  byte, as today. Reasons: (1) preserve-unknown: a reader keeps what it
  cannot interpret, and a handle this build sees as dead may name
  something a newer build models (a table record, a type of node this
  build does not know); (2) a load→save of an unedited plan stays
  byte-identical; (3) the orphans are inert: nothing reads a component
  through a dead handle (the symbol reuse path checks
  `tree.definition(h) != null`, `symbol_placer.dart:96-106`; the
  parametric survey reads live objects only).
- **Not a schema concern; `kSchemaVersion` stays 8.** The format is
  unchanged. A plan that never had orphans is written exactly as before;
  after this change a delete simply stops adding entries. Any reader,
  0.2.0 on, reads either kind of plan identically.
- Recorded, not done: a validation diagnostic for orphans, a purge-time
  sweep of registered types on dead handles, and raising the seed past
  component handles on load (O-2, O-3, O-4).

### D-7. The host embedding spec (another branch)

Its F-14, E-9's last bullet and **O-8** are discharged by this work once
that branch rebases onto it. Its Slice 2 expander on `TableLabelSystem`
that appends `SetComponentCommand<FloorPlanTableData>(h, null)` (E-6,
*"Delete drops it"*) becomes redundant: it would plan a no-op detach after
the node's own. **Recommended there:** drop that expander and re-aim
M-H27 at `RemoveNodeCommand` (an instance carrying table data, deleted,
saved: no entry; undo: restored). E-9's sentence about a **0.3.0**
terminal orphaning a deleted table's data stays true for 0.3.0. This
spec does not edit that branch; the note travels in the results file
and STATUS.

### D-8. Docs

- CHANGELOG **Unreleased**: deleting a node removes its components with
  it (undo restores them); plans are unchanged (schema 8), and orphaned
  entries an older release left in a plan stay as they are.
- The host guide says nothing about components on delete; unchanged.
- The doc comments on `RemoveNodeCommand`, `AddNodeCommand`,
  `ComponentRegistry.restore` (*"which is how `RemoveDefinitionCommand`'s
  inverse uses it"* gains `RemoveNodeCommand`'s), `ParametricView.paramsOf`
  and `objectsOf` (`parametric_system.dart:386-391, 442-446, 599-604`),
  and `_written`'s list (`regeneration.dart:692-704`) are brought in line.

## Invariants

- **I-1.** After any command, no component (registered or unknown) sits
  on a handle that a `RemoveNodeCommand` in that command removed.
- **I-2.** Undo of a node removal restores `snapshotOf(handle)` exactly:
  the same registered values (`==`), the same unknown payloads in the
  same order; the encoded document equals the one before the removal,
  byte for byte. Redo removes them again.
- **I-3.** Every command stays all-or-nothing: a refused `AddNodeCommand`
  (duplicate, cycle, unmapped type) leaves the tree and the components as
  they were.
- **I-4.** Other handles' components are untouched by a removal.
- **I-5.** A plan loads and saves byte for byte whether or not it carries
  orphans (D-6).

## Testing and named mutants

The fixture is never degenerate: the removed node is **not** the first
handle, sits under a non-root parent at a non-identity transform, carries
**two registered** components with non-default values (`ObjectLayer` on
a non-zero layer and a test type) and **two unknown** payloads whose
type ids are **not** in sorted order (`"z.later"` attached before
`"a.earlier"`, one with a nested map), and has a **sibling** carrying the
same two registered types and one unknown payload with different values.

**Engine** (`packages/jet_cad_2d/test/document/node_components_test.dart`,
new):

- **N-1** remove: every component of the handle gone (`get` null for
  both types, `unknownOf` empty, `snapshotOf(...).isEmpty`, no entry for
  the handle in `components.toJson()`); the sibling's `snapshotOf` equal
  to before.
- **N-2** undo: `snapshotOf` equal to before (registered `==`, unknown
  payload list equal in order); `JsonCodec` encode equal to before; redo:
  gone again; undo: back again.
- **N-3** capabilities: `RemoveNodeCommand` → `{structure, components}`,
  `capability` `structure`; `AddNodeCommand` empty → `{structure}`,
  non-empty → `{structure, components}`; a profile with `structure` and
  not `components` refuses the remove (`PermissionDeniedError`) and the
  encoding is unchanged.
- **N-4** all-or-nothing: an `AddNodeCommand` whose snapshot is taken in
  a second document registering a type this one does not → throws, the
  handle is in neither the tree nor its parent's `children`, and nothing
  is attached; one whose node closes a definition cycle → throws, nothing
  attached.
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
carrying an unknown payload (a stand-in for a newer release's data) and
a wall, deleted together: the saved plan has no entry for either handle;
undo restores the plan byte for byte. **P-2** a wall deleted alone: its
`WallParams` and `ObjectLayer` are gone and the undo replay carries them
in the node's snapshot (D-4).

| Mutant | Where | Killed by |
|---|---|---|
| M-1 no `detachAll` in `RemoveNodeCommand` | commands | N-1, S-1, P-1, P-2 |
| M-2 the inverse built without the snapshot | commands | N-2, S-1, P-1 |
| M-3 the snapshot taken after `detachAll` | commands | N-2 |
| M-4 `detachAll` that drops registered only (keeps `_unknown`) | component | N-1, P-1 |
| M-5 `restore` appends unknown payloads reversed | component | N-2, N-6 |
| M-6 `detachAll` replaced by `clear()` | commands | N-1 (sibling) |
| M-7 `RemoveNodeCommand.capabilities` back to `{structure}` | commands | N-3 |
| M-8 `AddNodeCommand.capabilities` always `{structure}` | commands | N-3 |
| M-9 `AddNodeCommand` restores before `addNode` with no rollback | commands | N-4 (cycle) |
| M-10 no `removeNode` rollback when `restore` throws | commands | N-4 (unmapped) |
| M-11 the dissolve's planned detach put back | regeneration | DV1 (replay holds a `SetComponentCommand`) |
| M-12 the cleanup list put back | regeneration | PG1, P-2 |
| M-13 a load-time sweep of dead-handle entries | codec | N-7 |

Each mutant is applied, the named test seen red, the file restored from
a copy (never `git checkout`), as the testing bar requires; the results
file records each.

## Risks

- **A host builds a re-parent by hand** and loses components (D-3). No
  public host API re-parents; the CHANGELOG states the new reading.
- **History entries made before the change** do not exist across a
  load (history is not saved), so no old inverse replays against the new
  behaviour.

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
  issued.

## Files (expected)

- `packages/jet_cad_2d/lib/src/document/commands.dart` (D-1, D-2)
- `packages/jet_cad_2d/lib/src/document/component.dart` (doc comment)
- `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`,
  `parametric_system.dart` (D-4, doc comments)
- `packages/jet_cad_2d/test/document/node_components_test.dart` (new),
  `compound_command_test.dart`, `test/parametric/{cascade,objects_of,
  misplaced,dissolve,page}_test.dart`
- `packages/jet_cad_2d_flutter/test/select_tool_test.dart`
- `packages/jet_cad_floor_plan/test/delete_components_test.dart` (new)
- `CHANGELOG.md`, `STATUS.md`, the results note
