# jet_cad_2d Plan 2 — Spatial Index, Queries and Validation

**Status:** approved 2026-07-28
**Parent:** [2026-07-27-jet-cad-2d-architecture-design.md](2026-07-27-jet-cad-2d-architecture-design.md)
**Predecessor:** Plan 1 (core document model) — shipped, 264 tests, `feat/jet-cad-2d-core`
**Backlog carried in:** [2026-07-27-jet-cad-2d-plan-2-backlog.md](../plans/2026-07-27-jet-cad-2d-plan-2-backlog.md)

## Summary

Plan 2 delivers the query layer: a two-level spatial index, hit-testing that
returns a path rather than a decision, a snap engine under a zero-allocation
budget, and the query set the renderer and every tool will call. It closes two
questions Plan 1 left open — what defines draw order, and where structural
validation lives.

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

## Decisions carried in from Plan 1

These were resolved during Plan 2 brainstorming and supersede what Plan 1
shipped.

### Draw order is ascending handle

Plan 1 shipped leaf ordering as ascending *slot* order. Slots are reused from a
LIFO free list, so that order changes across an undo/redo cycle — a hit-test tie
could resolve differently after an undo, and the parent spec requires query
results to be stably ordered.

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

Plan 2's index walks the tree to build its top level, making it the first
consumer a malformed tree would silently corrupt. Validation lands here.

```dart
/// Structural problems in the document, in a stable order.
///
/// Empty means well-formed. Callers decide whether to reject, repair or warn;
/// this reports and does not mutate.
List<Diagnostic> validate();
```

Codes:

| Code | Meaning |
|---|---|
| `tree.root_missing` | the tree's root handle names no node |
| `tree.parent_child_mismatch` | a node's `parent` disagrees with the container listing it |
| `tree.dangling_child` | a `children` entry resolves to nothing |
| `tree.leaf_in_children` | a `children` entry names an entity, not a node |
| `entity.owner_missing` | an entity's `owner` names no container |
| `entity.definition_cycle` | a definition reaches itself |

Reuses Plan 1's `Diagnostic` and the `decode(..., diagnostics:)` channel.
Index construction asserts `validate().isEmpty` in debug builds only — a release
build must not pay for it, and a caller may legitimately choose to index a
document it knows is imperfect.

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

Output: a numbers section appended to the Plan 3 spec. No code survives.

## Architecture

### Two-level index

```
Top level:   world-space AABBs of root-level nodes (instances, groups, entities)
Definition:  local-space AABBs of one definition's entities — built once, shared
```

A world query hits the top level, inverse-transforms the query region into each
hit instance's local space, and queries that definition's index. Nested
instances recurse with composed transforms.

This is what makes repetition cheap: 500 identical tables share one definition
index; dragging a table updates one top-level record rather than 500 entity
records; editing the definition rebuilds one shared index rather than 500.

### Packed R-tree

Both levels are the same structure: an STR bulk-loaded packed R-tree in typed
arrays.

```dart
final class PackedRTree {
  final Float64List _boxes;    // minX, minY, maxX, maxY per node, level by level
  final Uint32List  _payload;  // leaf payloads (slot or handle)
  final Uint32List  _levels;   // start offset of each level
  final Uint64List  _dead;     // bitmask — entries superseded by the dirty list
}
```

No per-node objects. Building 500k entities allocates a handful of buffers, not
500k records. Coordinates stay `Float64`; the index never sees screen space, so
the float32 concern that shapes the renderer does not arise here.

### Edits go to a dirty list

A packed tree cannot accept insertions. An added or edited entity is appended to
a linearly scanned dirty list, and its previous tree entry — if any — is marked
in `_dead`. Every query walks the tree skipping dead entries, then scans the
dirty list.

Rebuild threshold: `dirty.length > max(64, 0.05 * count)`. The constant is a
starting point to be tuned against the benchmark, not a claim.

This matches the real usage profile — long reads punctuated by short edit
bursts — and avoids dynamic R*-tree rebalancing entirely.

### Invalidation is driven by `DocChange`

Plan 1 already emits it. Plan 2 subscribes.

| Change | Effect |
|---|---|
| entity geometry, add, remove | that entity → dirty; its container's world box → dirty |
| node transform | that node's top-level record → dirty |
| definition content | rebuild that `DefinitionIndex`; every instance's world box → dirty |
| layer, style, component, header edit | none — no geometry changed |

The last row is load-bearing. Appearance edits must not touch the index, for the
same reason `documentRevision` must not touch the picture caches in Plan 3: a
channel that invalidates more than it must makes the primary workload
pathological.

## Query API

```dart
// Frame path — zero allocation, called at pointer-move and per-frame rates
void forEachInRect(Aabb2 world, void Function(int slot) visit);
bool pickInto(Vector2 world, double radius, HitPath out);
void snapInto(Vector2 world, double radius, SnapMask mask, SnapResult out);

// Non-frame path — allocation permitted, for tools, adapters and tests
Iterable<Handle> entitiesInRect(Aabb2 world);
Iterable<Handle> instancesOf(Handle definition);
Iterable<Handle> onLayer(Handle layer);
Iterable<Handle> withComponent<T extends Component>();   // exists — Plan 1
Iterable<Handle> attributesOf(Handle instance);
```

Of these, only `withComponent<T>` shipped in Plan 1
(`ComponentRegistry.withComponent`). Every other method above is new in Plan 2.
`onLayer`, `instancesOf` and `attributesOf` need no spatial index — they are
column or tree scans — but they belong to the same query surface and ship
together so that tools written against Plan 2 have one place to look.

### The scratch stack, and why queries are not reentrant

Descending through nested instances needs a stack. A recursive Dart call would
allocate a frame and a composed `Transform2` per level, at pointer-move rate,
which the zero-allocation budget forbids.

The index therefore owns a reusable scratch stack: a preallocated `Float64List`
of composed transforms, a `Uint32List` of node handles, and an explicit depth
counter.

**A query is consequently not reentrant.** Calling any query from inside another
query's visitor corrupts the scratch and yields wrong results with no error.
This is stated in the visitor's contract, and a debug-only `_inQuery` flag
asserts it. It is the price of the budget, and it is cheaper than allocating per
query at pointer-move rate.

Scratch depth is fixed. Instance nesting deeper than the scratch is truncated
from the root, flagged, and does not affect the correctness of the leaf result.

### Anisotropy

`Transform2` is a full affine, so inverse-transforming a circular pick radius
yields an ellipse and a query rectangle yields a rotated parallelogram.

- **Broad phase** uses a conservative axis-aligned bound of the
  inverse-transformed query region — never the region itself — and accepts false
  positives.
- **Narrow phase** measures distance **in world space**, transforming the
  candidate rather than the query. Exact under any affine, and it avoids ellipse
  math entirely.

### Ordering

Every query returns results in ascending handle order. Hash iteration order is
forbidden: it makes tests flaky and selection jump between frames.

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

Priority: vertex/endpoint → edge → fill. Ties break by topmost node, then by
handle.

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

One best candidate, ordered by (kind priority, distance). Intersection snapping
considers only candidates inside the query rectangle and stops at a declared
candidate cap rather than degrading without bound.

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
- non-uniform scale, and mirrored (negative determinant) scale
- rotation at angles that are not multiples of 90°
- coordinates near 4.5e6, not near the origin
- a definition shared by hundreds of instances
- documents with a dirty list both under and over the rebuild threshold
- an empty document, and a document of one entity

A fixture near the origin with axis-aligned unit transforms would pass every
test while exercising almost nothing.

### Allocation assertions

The zero-allocation claim is tested, not asserted in prose. `snapInto`,
`pickInto` and `forEachInRect` run inside a harness that fails if the query path
allocates.

### Reentrancy

A test asserts that calling a query from inside a visitor trips the debug flag,
so the documented restriction is enforced rather than merely written down.

## Validation gate

Run at the end of Plan 2, against generated documents, with no painting. This
measures the index, deliberately not the renderer.

| Measurement | Threshold | Verdict if missed |
|---|---|---|
| `forEachInRect` returning ~2k visible entities from 500k | < 2 ms | **fail** — index design returns to Plan 2 |
| `pick` at 500k | < 1 ms | **fail** |
| `snap` at 500k, all kinds enabled | < 1 ms, zero allocation | **fail** |

Benchmarks live in a separate suite from the correctness tests, so a loaded CI
machine cannot fail correctness by being slow.

The gate may not be deferred into Plan 3. The parent spec's reasoning holds: the
cost of reversing a design grows sharply once the next layer is built on it.

## Risks

| Risk | Mitigation |
|---|---|
| Packed-tree rebuild cost dominates during edit bursts | rebuild threshold is tunable against the benchmark; dirty list is linear and small by construction |
| Scratch-stack non-reentrancy is violated by a future caller | debug assert plus a test; documented in the visitor contract |
| Conservative broad phase yields too many false positives under extreme anisotropy | narrow phase is exact; if the false-positive rate shows up in the benchmark, the bypass threshold from the renderer's anisotropy policy applies here too |
| Differential corpus still misses a case | the corpus is a floor, not a ceiling; any defect found later adds a fixture rather than a one-off test |
| 32-bit handle space, since payload arrays are `Uint32List` | unchanged from Plan 1 — the range check and import-time compaction already exist |
