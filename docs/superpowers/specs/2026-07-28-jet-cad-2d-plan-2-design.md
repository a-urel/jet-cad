# jet_cad_2d Plan 2 — Spatial Index, Queries and Validation

**Status:** approved 2026-07-28, revised after review
**Parent:** [2026-07-27-jet-cad-2d-architecture-design.md](2026-07-27-jet-cad-2d-architecture-design.md)
**Predecessor:** Plan 1 (core document model) — shipped, 264 tests, `feat/jet-cad-2d-core`
**Backlog carried in:** [2026-07-27-jet-cad-2d-plan-2-backlog.md](../plans/2026-07-27-jet-cad-2d-plan-2-backlog.md)

## Summary

Plan 2 delivers the query layer: a definition-shared spatial index, hit-testing
that returns a path rather than a decision, a snap engine under a
zero-allocation budget, and the query set the renderer and every tool will call.
It closes two questions Plan 1 left open — what defines draw order, and where
structural validation lives.

It stays inside `packages/jet_cad_2d`. **No new package, no Flutter dependency.**
The query gate therefore measures the index rather than the framework.

A throwaway rendering spike runs before the plan proper, to put numbers on the
architecture's largest unvalidated assumption months before the gate that
formally tests it.

## Non-goals

Camera, painting, picture caches, `DraftCanvas`, text layout, tools,
`SelectionController`, `DraftPermissions` enforcement in a widget. Those are
Plans 3 and 4 and are not to be anticipated here — an index built to serve a
renderer that does not exist yet is an index built to a guess.

The Phase 0 spike below does paint, and is not an exception to this: it ships
nothing, is deleted when its numbers are recorded, and no Plan 2 deliverable may
depend on it.

Polyline offset and polygon boolean stay deferred, per the parent spec.

## What Plan 1 actually shipped, and what it constrains

Three facts from the delivered code shape everything below. They are stated here
because the first draft of this spec contradicted all three.

**Leaf containment is `EntityRecord.owner`, and only that.** Plan 1 ruled
`owner` authoritative and made `children` hold child *nodes* only
(`draft_document.dart:229-254`). An index must therefore derive its leaf sets by
bucketing on `ownerAt`, exactly as `_leavesByOwner` does — never by walking
`children`. This constrains the index's shape, not merely its build code.

**Containers nest arbitrarily.** `_boundsOfContainer` recurses through
`GroupNode` children (`draft_document.dart:211-221`), and a group owns leaves
via `ownerAt` like any other container. "Two levels" was wrong: the container
tree has arbitrary depth, and the index design must say what it does with the
middle.

**`DocChange` carries no change kind.** As shipped it is
`CommandApplied|CommandUndone|CommandRedone(label, Set<Handle> touched)`, plus
`DocumentLoaded` and `DocumentPurged` (`doc_change.dart`). `SetComponentCommand`
emits `touched: {handle}` — the entity's own handle
(`commands.dart:252`) — indistinguishable from a geometry edit. An invalidation
table keyed on change kind is therefore unimplementable against the shipped
event stream.

## Decisions carried in from Plan 1

### Draw order is ascending handle

Plan 1 shipped leaf ordering as ascending *slot* order. Slots are reused from a
LIFO free list and are renumbered by `purge()`, so that order changes across an
undo/redo cycle — a hit-test tie could resolve differently after an undo, and
the parent spec requires query results to be stably ordered.

**Draw order is ascending handle value**, for every purpose: hit-test tie-breaks,
query result ordering, and later, paint order. Handles are allocated
monotonically, never reused, and survive undo, save, load and purge unchanged.
It matches DXF, where entities draw in database order.

An explicit override — DXF's `SORTENTSTABLE`, "send to front" — layers on top
later as a separate sort table. It is not part of Plan 2, and it must not be
implemented by mutating handles.

Plan 1's `_childrenOf` documentation, which states ascending slot order, is
corrected as part of this plan.

### Structural validation is an engine service

Plan 1 shipped no structural validation. `DocumentTree.addNodeUnchecked`
deliberately preserves `parent`/`children` disagreement as evidence for a
validator — which did not exist, so the evidence was produced and never read.

Plan 2's index walks the container tree, making it the first consumer a
malformed tree would silently corrupt — or hang.

```dart
// on DraftDocument — it needs the entity store, the tree and the tables
List<Diagnostic> validate();
```

| Code | Meaning |
|---|---|
| `tree.root_missing` | the tree's root handle names no node |
| `tree.parent_child_mismatch` | a node's `parent` disagrees with the container listing it |
| `tree.dangling_child` | a `children` entry resolves to nothing |
| `tree.leaf_in_children` | a `children` entry names an entity, not a node |
| `tree.cycle` | a consistent `parent`/`children` cycle among groups |
| `tree.definition_cycle` | a definition reaches itself |
| `entity.owner_missing` | an entity's `owner` names no container |

`tree.cycle` is the one malformation that hangs index construction rather than
merely corrupting it, and it is not covered by `tree.definition_cycle`.
`DocumentTree.addNode` guards the instance→definition edge, but
`addDefinition`/`replaceDefinition` are documented as unguarded
(`tree.dart:116-130`) — which is precisely why `_boundsOfContainer` carries a
`visiting` set (`draft_document.dart:194-196`). The index needs the same guard,
and `validate()` is how a caller learns before paying for it.

The code is `tree.definition_cycle`, not `entity.definition_cycle`: nothing
about it concerns an entity.

Reuses Plan 1's `Diagnostic` and the `decode(..., diagnostics:)` channel. Index
construction asserts `validate().isEmpty` in debug builds only — a release build
must not pay for it, and a caller may legitimately choose to index a document it
knows is imperfect.

### Deferred again, deliberately

`RemoveEntityCommand` dropping a leaf that a file listed in `children`, and
encode silently laundering malformed files, stay parked for the persistence
plan. Both are about what a *file* carries; neither affects the index.

## Phase 0 — rendering spike (throwaway)

Before any index work. A disposable Flutter app, deleted when its numbers are
recorded.

- Hard-coded 50k-entity document positioned at world coordinates near 4.5e6.
- Naïve `CustomPainter`: no caches, no text, no patterns, no dashes.
- Measure p95 frame time under sustained pan and zoom.

Two questions it must answer, both cheap now and expensive later:

1. **Is float32 jitter visible at 4.5e6 without rebasing?** The parent spec's
   coordinate-rebasing design is built on the claim that it is. If it is not
   visible, the design does not change — the arithmetic is unambiguous — but the
   spike records what the failure actually looks like, which the Plan 3 golden
   tests need in order to assert against something real.
2. **What does 50k × `canvas.drawPath` cost with no caching?** This is the raw
   ceiling every caching decision in Plan 3 is measured against.

**This spike cannot pass the Plan 3 frame-time gate** — that gate requires the
real definition and tile caches to be meaningful. It can only fail
informatively. If it fails badly enough that caching plausibly cannot close the
gap, the render design reopens before Plan 2 builds an index on top of it.

**Output path:** `docs/superpowers/notes/2026-07-28-render-spike-results.md`,
committed. The Plan 3 spec does not exist yet, so "append it to Plan 3" would
send the numbers nowhere.

## Architecture

### Indexed containers, and what happens to groups

An **indexed container** is the tree root or a `Definition`. Each gets one index.

**Groups are not indexed.** A group is flattened into its nearest indexed
ancestor at build time, with its transform composed into every box it
contributes. `InstanceNode` is *not* flattened: it is the sharing boundary and
the point of the whole design.

So each `ContainerIndex` holds, in the container's own space:

- every leaf owned by that container, or by any group beneath it, with the
  composing group transforms applied;
- one box per `InstanceNode` beneath it — the instance's definition box,
  transformed.

A world query hits the root index, inverse-transforms the query region into each
hit instance's local space, queries that instance's definition index, and
recurses through nested instances with composed transforms.

**Why flatten groups rather than index them.** A group is a one-off: it is not
shared, so a per-group index buys no reuse, while costing an index object and a
recursion level on every query. A definition is shared by construction — 500
tables share one index — which is what makes the two-kind split pay.

**The cost, declared.** Changing a group's transform dirties every leaf beneath
it, because their composed boxes all move. Groups are ad-hoc and small in the
target workload — repeated furniture is a block, not a group — so this is the
right trade, but it is a real cost and not a free one. If profiling ever shows
large groups being dragged, the fix is to index groups above a size threshold,
which this structure permits without redesign.

This is why the parent spec's "two-level" phrasing is superseded: there are two
*kinds* of index, and arbitrarily many instances of them, with group depth
flattened out.

### Packed R-tree

Every index is the same structure: an STR bulk-loaded packed R-tree in typed
arrays.

```dart
final class ContainerIndex {
  final Float64List _boxes;    // minX, minY, maxX, maxY per node, level by level
  final Uint32List  _payload;  // leaf payloads — entity SLOT, or node handle
  final Uint32List  _levels;   // start offset of each level
  final Uint64List  _dead;     // bitmask — entries superseded by the dirty list
}
```

No per-node objects. Building 500k entities allocates a handful of buffers, not
500k records. Coordinates stay `Float64`; the index never sees screen space, so
the float32 concern that shapes the renderer does not arise here.

**The payload is an entity slot, not a handle** — `forEachInRect`'s visitor
signature is `void Function(int slot)`, and the renderer wants the slot in order
to read columns without a second lookup.

That choice has one consequence that must be stated: **slots are not stable.**
They are renumbered by `purge()` and reused from a LIFO free list under undo.
`DocumentPurged` therefore invalidates the entire index *and* every dirty-list
entry — a full rebuild, with no incremental path. Plan 1's `DocumentPurged` doc
comment already says every derived structure keyed by a slot is invalid; this is
that structure.

### Edits go to a dirty list

A packed tree cannot accept insertions. An added or edited entity is written to
a dirty list, and its previous tree entry — if any — is marked in `_dead`. Every
query walks the tree skipping dead entries, then scans the dirty list.

**The dirty list is keyed by slot with replace-in-place**, not append. A drag
emits one edit per pointer-move; a naive append would put 200 entries in the
list for one entity, trip the rebuild threshold mid-drag, and rebuild during
exactly the burst the design exists to avoid.

Rebuild threshold: `dirty.length > max(64, 0.05 * count)`. The constant is a
starting point to be tuned against the benchmark, not a claim.

### Invalidation: re-derive and compare

`DocChange` carries no change kind, so the index cannot be told *what* changed.
It is told *which handles* changed, and re-derives their boxes.

For each handle in `touched`: look up what it is, recompute its box, compare
against the indexed box. Unchanged ⇒ nothing to do. Changed ⇒ dirty.

| Event | Effect |
|---|---|
| `CommandApplied` / `CommandUndone` / `CommandRedone` | re-derive each `touched` handle's box; dirty those that moved |
| `DocumentLoaded` | full rebuild, every index |
| `DocumentPurged` | full rebuild, every index — slots were renumbered |

This is what makes the load-bearing property work without changing Plan 1: a
`SetComponentCommand` touches an entity handle indistinguishably from a geometry
edit, but re-derivation finds the box unchanged and dirties nothing. The
appearance-edits-do-not-touch-the-index guarantee is preserved by measurement
rather than by a change kind the stream cannot carry.

**Cost:** O(|touched|) bounds computations per command, each one entity or one
container box. Commands touch one or a few handles. This is cheaper than the
alternative of threading typed kinds through every command and its inverse, and
it cannot go stale when a later plan adds a command — including the
geometry-editing command that **does not exist yet** in Plan 1 (the shipped set
is add/remove entity, add/remove/transform node, set component). Re-derivation
works for whatever arrives.

If the benchmark shows re-derivation dominating, typed kinds on `DocChange` are
the escape hatch, and adding them is additive.

## Query API

```dart
// Frame path — zero allocation, called at pointer-move and per-frame rates
void forEachInRect(Aabb2 world, QueryFilter filter, void Function(int slot) visit);
bool pickInto(Vector2 world, double radius, QueryFilter filter, HitPath out);
void snapInto(Vector2 world, double radius, SnapMask mask, SnapResult out);

// Non-frame path — O(n) column or tree scans, NOT for a paint loop
Iterable<Handle> entitiesInRect(Aabb2 world, QueryFilter filter);
Iterable<Handle> instancesOf(Handle definition);   // O(nodes)
Iterable<Handle> onLayer(Handle layer);            // O(entities)
Iterable<Handle> attributesOf(Handle instance);    // O(entities)
Iterable<Handle> withComponent<T extends Component>();   // exists — Plan 1
```

Only `withComponent<T>` shipped in Plan 1 (`ComponentRegistry.withComponent`).
Every other method above is new in Plan 2.

`onLayer`, `instancesOf` and `attributesOf` are **O(n) scans, once per call**,
with no index behind them. They are documented as such at the declaration, so
that Plan 3 does not call `onLayer` inside a paint loop and discover it there.

### Visibility and locking are query parameters, not caller policy

`LayerRecord` carries `visible` and `locked` (`tables.dart:82-83`); `Node`
carries `visible` (`node.dart:26`). Three callers want three different answers,
so the filter is in the signature rather than left to the caller to apply
afterwards — applying it afterwards would mean the index returns work the caller
throws away, at frame rate.

```dart
final class QueryFilter {
  final bool visibleOnly;     // layer.visible AND every ancestor node.visible
  final bool excludeLocked;   // layer.locked

  const QueryFilter.all();        // select-all-on-layer, adapters, tests
  const QueryFilter.rendering();  // visibleOnly
  const QueryFilter.picking();    // visibleOnly + excludeLocked
}
```

The gate's "~2k visible entities" means `QueryFilter.rendering()`.

### The scratch stack, and why queries are not reentrant

Descending through nested instances needs a stack. A recursive Dart call would
allocate a frame and a composed `Transform2` per level, at pointer-move rate,
which the zero-allocation budget forbids.

The index therefore owns a reusable scratch stack: a preallocated `Float64List`
of composed transforms, a `Uint32List` of node handles, and an explicit depth
counter.

**A query is consequently not reentrant, and a document must not be mutated
inside a visitor.** Either corrupts the walk and yields wrong results with no
error. A debug-only `_inQuery` flag asserts both: the query entry points check
it, and **`CommandDispatcher.execute`/`undo`/`redo` check it too** — a mutation
from inside a visitor is the more likely mistake of the two, and the one a
reader would not expect to be forbidden.

Scratch depth is fixed. Instance nesting deeper than the scratch is truncated
from the root, flagged, and does not affect the correctness of the leaf result.

### Ordered output without allocating

Every query returns results in ascending handle order. Hash iteration order is
forbidden: it makes tests flaky and selection jump between frames.

Ordering requires buffering, which is why it is specified rather than assumed.
Slots are collected into a preallocated `Uint32List` scratch, sorted by
`handleAt(slot)`, then visited. The scratch grows by reallocation when a result
set exceeds it — result count is unbounded — so the allocation harness **warms
the scratch before asserting**, and the assertion is "no allocation in steady
state", not "no allocation ever".

The sort is a hand-written in-place sort over the scratch's live prefix.
`List.sort` is not used: it would require a sublist view, which allocates.

### Anisotropy

`Transform2` is a full affine, so inverse-transforming a circular pick radius
yields an ellipse and a query rectangle yields a rotated parallelogram.

- **Broad phase** uses a conservative axis-aligned bound of the
  inverse-transformed query region — never the region itself — and accepts false
  positives.
- **Narrow phase** measures distance **in world space**, transforming the
  candidate rather than the query. Exact under any affine, including mirroring,
  and it avoids ellipse math entirely.

## Text is a declared lower bound

`entityBounds` delegates text and attribute entities to the document's
`TextMeasurer`, and the engine's default `InsertionPointMeasurer` returns
`Aabb2(insertion, insertion)` — a degenerate box (`extents.dart:26-40`).

**The index uses the document's own measurer**, so it is exactly as accurate as
that document's extents are, and never disagrees with them. With the default
measurer:

- a rect query finds a text entity only when the query contains its insertion
  point;
- a pick hits text only within the pick radius of its insertion point;
- text contributes a point, not a box, to any index box.

This is a declared lower bound, not a defect — it is the same honest answer
`extents` gives, for the same reason: no font stack is present in a pure-Dart
engine. Plan 3's widget layer supplies a real measurer.

There is no staleness hazard: `DraftDocument.textMeasurer` is final at
construction, precisely so a measurer cannot change under a cached derivation. A
document built with a real measurer indexes real text boxes from the start.

## Hit-testing

```dart
class HitPath {
  final Uint32List chain;   // root → … → leaf, caller-owned
  int chainLength;
  Handle entity;
  Vector2 worldPoint;
  HitKind kind;             // vertex | edge | fill
  bool truncated;           // chain deeper than the buffer
}
```

The engine reports what was hit; policy lives in the widget layer. Plan 4's
`DraftViewer` will select `chain[0]` — tapping a chair selects its table —
while `DraftDesigner` supports descending into a group. Plan 2 ships neither
policy, only the path.

Priority: vertex/endpoint → edge → fill.

**Tie-break, stated once:** greater root-level ancestor handle wins; if equal,
greater leaf handle wins. The parent spec's "topmost node, then draw order" is
circular now that draw order *is* handle order, so it is replaced by this.

Chains deeper than the buffer truncate **from the root** and set `truncated`, so
the leaf hit stays correct. Truncation affects only deeply nested instances and
never the identity of what was hit.

## Snapping

```dart
void snapInto(Vector2 world, double radius, SnapMask mask, SnapResult out);
```

| Kind | Cost |
|---|---|
| endpoint, midpoint, center, quadrant, insertion | cheap — constant per entity |
| nearest, perpendicular, tangent | moderate — one projection per entity |
| intersection | expensive — pairwise among candidates in the query rect, capped |
| grid, ortho/polar | free — no geometry query |

One best candidate, ordered by (kind priority, distance).

**Intersection snapping considers at most 64 candidates**, taken in ascending
handle order from those inside the query rectangle. The number is declared here
rather than left to the implementer, for the same reason the rebuild threshold
is: undeclared constants get invented, and an invented one is untestable.

**A snap query allocates nothing.** It runs at pointer-move rate. The caller owns
`SnapResult` including its chain buffer, and the query writes into it. A
`SnapResult` returning a freshly allocated `List<Handle>` would violate the
budget it is declared under.

Snapping crosses instance boundaries — snapping to a chair's corner inside a
table instance — and is an engine service available to any tool, in the viewer
as much as the designer.

## Testing

### Differential testing is the load-bearing test

Every query result must equal a brute-force linear scan over the same document.
That single property kills most index bugs outright, and unlike hand-picked
cases it does not depend on guessing which cases matter.

### The corpus is specified, not left to the implementer

Plan 1 shipped five green tests that proved nothing, every one because the
*fixture* was degenerate rather than because the assertion was wrong: one entity
made slot 0 indistinguishable from slot 0; LIFO undo made restore-by-value
indistinguishable from restore-by-slot; commutative translations made
composition order invisible.

The differential corpus is therefore fixed here:

- nested instances at least three levels deep
- **groups nested inside definitions**, and groups inside groups — the case the
  first draft of this design missed entirely
- non-uniform scale, and mirrored (negative determinant) scale
- rotation at angles that are not multiples of 90°
- coordinates near 4.5e6, not near the origin
- a definition shared by hundreds of instances
- documents with a dirty list both under and over the rebuild threshold
- a document after `purge()`, and after an undo that reused a freed slot
- text entities under the default measurer, asserting the declared lower bound
  rather than asserting text is found
- an empty document, and a document of one entity

A fixture near the origin with axis-aligned unit transforms would pass every
test while exercising almost nothing.

### Allocation assertions

The zero-allocation claim is tested, not asserted in prose. `snapInto`,
`pickInto` and `forEachInRect` run inside a harness that fails if the query path
allocates **after the result scratch is warmed**.

### Reentrancy and mutation

Tests assert that calling a query from inside a visitor trips the debug flag,
and that executing a command from inside a visitor trips it too — so both
documented restrictions are enforced rather than merely written down.

## Validation gate

Run at the end of Plan 2, against generated documents, with no painting. This
measures the index, deliberately not the renderer.

| Measurement | Threshold | Verdict if missed |
|---|---|---|
| `forEachInRect` returning ~2k visible entities from 500k | < 2 ms | **fail** — index design returns to Plan 2 |
| `pick` at 500k | < 1 ms | **fail** |
| `snap` at 500k, all kinds enabled | < 1 ms, zero allocation | **fail** |

**Every measurement runs twice: once on a freshly built index, and once with the
dirty list at its rebuild threshold.** At 500k the threshold is 25k linearly
scanned entries on every query, including `pick` and `snap` at pointer-move
rate. Measuring only a fresh index would let a threshold pass the gate and fail
in use — which is the state the index spends every editing session in.

Benchmarks live in a separate suite from the correctness tests, so a loaded CI
machine cannot fail correctness by being slow.

The gate may not be deferred into Plan 3. The parent spec's reasoning holds: the
cost of reversing a design grows sharply once the next layer is built on it.

## Risks

| Risk | Mitigation |
|---|---|
| Re-derive-and-compare dominates on large `touched` sets | commands touch one or a few handles; typed `DocChange` kinds are an additive escape hatch if the benchmark disagrees |
| Group flattening makes a large group's transform edit expensive | declared; indexing groups above a size threshold is possible without redesign |
| Packed-tree rebuild cost dominates during edit bursts | dirty list is slot-keyed with replace-in-place, so a drag is one entry; gate measures at threshold |
| Scratch-stack non-reentrancy or in-visitor mutation violated by a future caller | debug assert in both the query entry points and the command dispatcher, plus tests |
| Conservative broad phase yields too many false positives under extreme anisotropy | narrow phase is exact; if the false-positive rate shows in the benchmark, the renderer's anisotropy bypass threshold applies here too |
| Text invisible to queries under the default measurer | declared lower bound, tested as such; Plan 3 supplies a real measurer and `textMeasurer` is final so it cannot go stale |
| Differential corpus still misses a case | the corpus is a floor, not a ceiling; any defect found later adds a fixture rather than a one-off test |
| 32-bit handle space, since payload arrays are `Uint32List` | unchanged from Plan 1 — the range check and import-time compaction already exist |
