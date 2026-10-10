# Plan — an undone node removal restores the node's index (O-10)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** undoing a node removal puts the node back at its original index
among its parent's `children` (and redo removes it again), for a single
and a multi-node delete, so Delete → Undo writes the document back byte
for byte.

**Spec:** [2026-10-09-host-embedding-api-design.md](../specs/2026-10-09-host-embedding-api-design.md),
*Out of scope, recorded*, **O-10**: *"Its own task (`AddNodeCommand`
restoring the child's index)"*. This plan is that task; it settles O-10
and changes nothing else the spec describes.

**Started** on the human's request (2026-10-10). **Branch:**
`fix/undo-node-index`, from `main` at `4e3ed91` (Slice 3 merged). Slice 4
(`claude/exciting-pasteur-9m22jv`) is in flight and not on `main`; its
DS1/DS2 tests are tightened once both are on `main`, not here.

**Architecture:** `RemoveNodeCommand` reads the node's index in its
parent's raw `children` list before removing it and hands it to its
inverse, `AddNodeCommand(node, index: i)`. `DocumentTree.addNode` takes
the index and inserts there instead of appending. A `CompoundCommand`'s
inverse is its children's inverses in reverse order, so each re-insert
happens against exactly the list its removal left: a multi-node delete
restores every index, in any removal order, with no extra machinery.

**Tech stack:** Dart 3, `package:test` (engine), `flutter_test` (planner).

## The defect, as measured

- `RemoveNodeCommand.apply` returns `AddNodeCommand(node)`
  (`jet_cad_2d/lib/src/document/commands.dart:430`), and
  `AddNodeCommand` links through `DocumentTree._link` (`tree.dart:557`),
  which appends. Deleting root child B of `[A, B, C]` and undoing leaves
  `[A, C, B]`.
- Two non-adjacent children deleted in one compound come back reversed
  at the end: `[A, B, C, D, E]` minus B and D, undone, is
  `[A, C, E, D, B]`.
- Draw order is ascending handle value (`spatial_index.dart:64`), so
  nothing drawn changes; `designJson()` differs from the saved file while
  `dirty` reads false.
- Entities are not affected: `SlotAllocator` reuses freed slots
  last-in-first-out, so a reverse-order undo lands every record back in
  its own slot, and the codec writes entities in slot order.

## Global constraints

- `CLAUDE.md`'s non-negotiables. **Draw order stays ascending handle
  value**: nothing here touches the spatial index or the painters.
- **The index is into the raw `children` list**, leaf and dangling
  entries included (`childNodesOf` filters only on the way out). Undo
  restores the raw list as it was, so the raw index is the one that
  round-trips.
- **`AddNodeCommand(node)` without an index still appends**: every
  existing call (tools, fixtures, the startup plan) keeps its meaning.
- **All or nothing** (`DraftCommand.apply`'s contract): an index out of
  range, or an index for a parent that lists no children, throws before
  anything is mutated.
- `_link` stays idempotent: a handle the parent already lists keeps its
  position whatever the index says (the codec's double-write).
- Gates per `CLAUDE.md`, plus `jet_cad_floor_plan` and `apps/floor_planner`
  (`flutter test`, `flutter analyze`, the format check). The engine's
  standing failures compared with
  `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d <run.json>`.

## Review focus

- **A fixture whose `children` are already in ascending handle order**
  cannot tell "restore the index" from "insert sorted by handle". Every
  engine fixture here lists its children out of handle order.
- **A malformed list naming a handle twice**: `_unlink` drops every copy;
  undo restores one, at the first index. Pinned as the documented outcome,
  not byte-exact (no file this build writes carries a duplicate).
- **A node inside a definition**, not a group: the same index path through
  `Definition.children`.
- **Redo after undo** recaptures the index from the live list (the redo is
  `AddNodeCommand`'s inverse, a fresh `RemoveNodeCommand`).
- **The dispatcher's rollback** (a compound whose later child throws)
  re-adds through the same inverses, so a failed edit restores order too
  (planner TD10).

---

### Task 1: the engine restores the index

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/tree.dart` (`addNode`,
  `_link`, a new `indexInParent`)
- Modify: `packages/jet_cad_2d/lib/src/document/commands.dart`
  (`AddNodeCommand.index`, `RemoveNodeCommand.apply`)
- Create: `packages/jet_cad_2d/test/document/node_index_undo_test.dart`

**Interfaces:**
- `void DocumentTree.addNode(Node node, {int? index})` — inserts at
  [index] in the parent's `children`; throws `RangeError` (index outside
  `0..children.length`) or `ArgumentError` (index for a parent that is
  neither a group nor a definition) before mutating.
- `int? DocumentTree.indexInParent(Handle handle)` — the first index of
  [handle] in its parent's raw `children`, or null (no node, no container,
  not listed).
- `AddNodeCommand(Node node, {int? index})`, `final int? index`.

- [ ] **Step 1: the failing tests.** Fixture: a root whose children are
  allocated first and added out of handle order, e.g. handles h1 < … < h5
  added as `[h3, h1, h5, h2, h4]`, each a `GroupNode` or `InstanceNode`
  with a non-identity transform; a nested group `g` under the root with
  three children in non-ascending order; a definition with two nodes.
  - N1 delete the middle root child (`h5`), undo: `encodeToString` equal
    to before, byte for byte; redo: equal to the deleted state; undo again:
    equal to before.
  - N2 one `CompoundCommand` deleting two non-adjacent root children
    (`h1`, `h2`), undo byte-exact; and the same two in the other order.
  - N3 a child of the nested group, and a node inside the definition:
    undo byte-exact.
  - N4 `AddNodeCommand(node, index: 0)` inserts first;
    `index: children.length` appends; `index: -1` and `length + 1` throw
    `RangeError` with the encoding unchanged and the undo depth unchanged;
    an index under a parent that lists nothing (`Handle.none`) throws
    `ArgumentError`.
  - N5 `AddNodeCommand(node)` appends (today's behaviour, pinned).
  - N6 a parent listing the removed handle twice: undo restores one copy at
    the first index.
- [ ] **Step 2:** run them, see N1–N4 and N6 fail (`[…, h5]` appended).
- [ ] **Step 3: implement.** `RemoveNodeCommand.apply` reads
  `target.tree.indexInParent(handle)` before `removeNode` and returns
  `AddNodeCommand(node, index: index)`; `AddNodeCommand.apply` passes
  `index` to `addNode`; `addNode` validates the index against the
  parent's list before `_guardCycle`'s mutation-free check is followed by
  any write; `_link(handle, parent, [index])` inserts at index when given
  and appends otherwise.
- [ ] **Step 4:** the engine suite green; the named mutations each turn a
  test red (recorded in the task report): M1 the inverse drops the index;
  M2 `_link` ignores the index; M3 index + 1; M4 the index read after
  `removeNode` (−1/null); M5 insert sorted by handle; M6 no range check.
- [ ] **Step 5:** commit.

### Task 2: the planner's relaxed comparisons, tightened

**Files:**
- Modify: `packages/jet_cad_floor_plan/test/host/table_data_test.dart`
  (HD12), `packages/jet_cad_floor_plan/test/tables/table_data_test.dart`
  (TD7b, TD10, a new TD7c)
- Modify: every `canon(…, sortNodes: true)` caller and the three `canon`
  helpers (`jet_cad_2d/test/parametric/support/fixture.dart`,
  `jet_cad_floor_plan/test/support/wall_fixture.dart`,
  `apps/floor_planner/test/support/wall_fixture.dart`), and
  `object_layer_test`'s `state`

- [ ] **Step 1:** HD12: the undone `designJson()` equals `before` byte for
  byte, `dirty` false; TD7b: the first table deleted and undone, encoding
  equal to before; TD7c (new): tables 1 and 3 of three deleted in one
  step, undone, byte-exact, redone, equal to the deleted state; TD10: the
  refused edit's rollback leaves the encoding byte-exact. Drop the
  `childrenSorted` helpers once unused.
- [ ] **Step 2:** measure: with the engine fix, every `sortNodes: true`
  caller passes without the sort. Remove the parameter and its doc comment;
  any caller that still needs it is investigated, not kept relaxed
  silently.
- [ ] **Step 3:** with Task 1's change reverted (copy aside, restore from
  the copy), HD12, TD7b, TD7c go red; restored, green.
- [ ] **Step 4:** gates; commit.

### Task 3: records

- [ ] Spec O-10 marked settled with the commit; CHANGELOG Unreleased
  (`AddNodeCommand`'s `index`, the undo's order); STATUS; a results note
  `docs/superpowers/notes/2026-10-10-undo-node-index-results.md` with the
  mutation table and the gate transcripts' summary lines.
- [ ] An independent review of the branch; findings fixed; commit.
