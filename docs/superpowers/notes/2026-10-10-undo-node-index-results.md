# Results — an undone node removal restores the node's index (O-10)

**Plan:** [2026-10-10-undo-node-index.md](../plans/2026-10-10-undo-node-index.md).
**Spec point:** the host embedding spec's O-10, now settled.
**Branch:** `fix/undo-node-index`, from `main` at `4e3ed91`.

## What changed

- `RemoveNodeCommand.apply` reads `DocumentTree.indexInParent(handle)`
  (the first index of the handle in its parent's raw `children`) before
  removing, and returns `AddNodeCommand(node, index: i)`.
- `AddNodeCommand` gains `index` (null appends, today's meaning);
  `DocumentTree.addNode(node, {index})` range-checks it against the
  parent's list before any write (`RangeError`; an `ArgumentError` for an
  index under a parent that is neither a group nor a definition) and
  `_link` inserts there.
- A compound delete needs nothing more: its inverse is its children's
  inverses in reverse order, so every re-insert meets the list its own
  removal left.
- Entities were never affected: `SlotAllocator` reuses freed slots last
  in, first out, so a reverse-order undo lands each record in its own
  slot, and the codec writes entities by slot.
- `_link`'s doc no longer says `children` order is draw order: draw order
  is ascending handle value (`spatial_index.dart:64`); `children` order
  matters to the encoding.

## Tests

- **New, engine:** `jet_cad_2d/test/document/node_index_undo_test.dart`,
  N1–N7 (14 tests). Every container in the fixture lists its children out
  of handle order (pinned as a premise): the root `[t2, t0, t4, t1, t3]`,
  a nested group, a definition. N1 a middle child; N2 two non-adjacent
  root children in one step, in both removal orders; N3 a nested group's
  first child with a node inside a definition; N3b a group cascade,
  children first; N4 the index's range and container checks; N5 no index
  appends; N6 a malformed list naming the handle twice; N7 a raw list
  naming a leaf and a dangling handle before the node (review F-1).
- **Tightened, engine:** DV1 (`dissolve_test`) pinned the defect
  (`[hC, hF]` after undo) and now reads `[hF, hC]`; `canon`'s
  `sortNodes` parameter is gone (`parametric/support/fixture.dart`) and
  with it every sorted comparison in `cascade_test`, `misplaced_test`,
  `object_layer_test`, `page_test`, `dissolve_test`; `guards_test`'s
  `encNodesSorted` and `_sortNodeChildren` are gone.
- **Tightened, planner:** HD12 (`host/table_data_test`) compares
  `designJson()` whole and reads `dirty` false after the undo; TD7b and
  TD10 (`tables/table_data_test`) compare the encoding whole; TD7c (new)
  deletes two non-adjacent tables, neither last, in one step. The two
  `childrenSorted` helpers are gone. `canon`'s `sortNodes` is gone from
  `jet_cad_floor_plan/test/support/wall_fixture.dart` and
  `apps/floor_planner/test/support/wall_fixture.dart`, with every caller
  (`wall_regen`, `opening_cut`, `opening_object`, `room_object`,
  `room_tie`, `room_follow`, `dimension_follow`, `room_dissolve`).
- **Not here:** Slice 4's DS1 and DS2 (`keyboard_focus_test.dart`, on
  `claude/exciting-pasteur-9m22jv`, not on `main`) compare around the
  defect; they are tightened once both are on `main`.

## Mutations (engine, against `node_index_undo_test` and `dissolve_test`)

Each run on a copy of the source restored from the copy afterwards.

| Mutant | Result |
|---|---|
| M1 the inverse drops the index | red: N1, N2 ×2, N3, N3b, N4, N6, DV1 |
| M2 `addNode` does not pass the index to `_link` | red: N1, N2 ×2, N3, N3b, N4 ×2, N6, DV1 |
| M3 insert at index + 1 | red: N1, N2 ×2, N3, N3b, N4 ×2, N6, DV1 |
| M4 the index read after `removeNode` | red: N1, N2 ×2, N3, N3b, N4, N6, DV1 |
| M5 insert sorted by handle | red: N1, N2 ×2, N3, N3b, N4 ×2, N6 — **not DV1**, whose root is ascending: only the out-of-order fixture sees it |
| M6 no range check | red: N4 (−1 and 4) |
| M7 no container check | red: N4 (the `Handle.none` parent) |
| M8 the index taken from `childNodesOf`'s filtered list | red: N7 only (review F-1; it survived N1–N6) |

**The planner's tightened tests against the old engine** (`tree.dart`
and `commands.dart` from `main`, restored from a copy afterwards): HD12,
TD7b, TD7c and TD10 red; with the fix, green.

**The de-sorted comparisons against the old engine**, the same way: 17
engine tests red (DV1, MP8, G3, G6 and the cascade, object-layer and page
undo tests in `test/parametric`) and 5 planner tests red (WR7, OR5, DN3
at both origins, RD1, RD3). Each compared sorted child lists because of
O-10 and now compares the bytes; the callers that stay green on the old
engine (their deleted node was already last) compare the bytes too.

## Gates

Run on macOS 27.0.1, Flutter 3.47.6, from this branch's tip; each
package's JSON compared with `tool/ci/expect_failures.dart`.

| Package | Tests | Comparison | Analyze | Format |
|---|---|---|---|---|
| `jet_cad_2d` | 1272 (after the review's N7) | the standing failures and skips, exactly | No issues | 0 changed |
| `jet_cad_2d_flutter` | 1390 (5 fail, 1 skip) | **differs**: text lod ladder rungs 1 and 2 pass here | No issues | 0 changed |
| `jet_cad_2d_gpu` | 20 | exactly | No issues | 0 changed |
| `jet_cad_floor_plan` (`--enable-vmservice`) | 1693 (1 fail) | **differs**: T-1 in `test/service/table_theme_painter_test.dart` fails | No issues | 0 changed |
| `jet_cad_restaurant_symbols` | 97 | all passed | No issues | 0 changed |
| `apps/floor_planner` | 212 | exactly | No issues | 0 changed |
| `apps/restaurant_demo` | 60 | exactly | No issues | 0 changed |

**The two differences are this host's, not this change's.** Both are
text-metric tests (the render package's lod-ladder goldens, standing
failures of macOS values; T-1 counts glyph rows, *Expected: a value
greater than <176420>, Actual: <175568>*), and both read the same with
`tree.dart` and `commands.dart` put back to `main`'s. Slice 3's ledger
recorded both as they are listed on 2026-10-09; this host is now on
macOS 27.0.1. Neither reads a node's place in a `children` list. CI's
Linux runner is the arbiter.


## Independent review

*Approve with fixes* (2026-10-10). The reviewer re-ran M1, M4 and M5 and
the engine suite and confirmed T-1 fails the same on `main`'s engine.
Findings, all applied:

- **F-1** (test gap): no test held a leaf or a dangling handle in a raw
  `children` list, so M8 survived. N7 added; M8 now red.
- **F-2** (doc): `_relinkDefinition`'s doc still said `children` order is
  draw order. Reworded like `_link`'s.
- **F-3** (doc): spec sentences stating the old append left unmarked
  (parametric layer's G3/G6 amendment, openings, rooms' table row and
  DV1 line). Marked superseded.
- **F-4** (test strength): TD7b, TD7c and HD12 add tables in ascending
  handle order; TD7c's comment now says the engine test covers M5.
- **F-5** (nit): T-1's path given.
