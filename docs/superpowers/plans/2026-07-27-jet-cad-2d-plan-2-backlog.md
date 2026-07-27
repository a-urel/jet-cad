# jet_cad_2d — carried backlog into Plan 2

Items deliberately parked during Plan 1 (core document model), with the ruling that parked them.
Plan 1 shipped at 264 tests, analyzer and formatter clean. Nothing here is a known-wrong behaviour
in shipped code except where marked.

## Must be scheduled in Plan 2

### 1. Structural validation of a loaded tree has no home

Nothing checks that `root` names an existing node, that a node's `parent` and its parent's
`children` list agree, or that a `children` entry resolves. A missing root degrades silently to
empty extents via `_childrenOf`'s `?? const []` fallback.

`lib/src/document/tree.dart` assigns this class of problem to "structural validation on import" —
a layer Plan 1 never scheduled. `addNodeUnchecked` deliberately preserves parent/`children`
disagreement *as evidence* for exactly such a validator, so the evidence is being produced with
nothing to consume it.

Needs a named `validate()` entry point that fails loudly, or reports through the `diagnostics`
channel `decode` already has.

### 2. Encode silently launders malformed files

On save, a `children` entry naming a Definition, or a leaf listed under container A whose `owner`
says B, is dropped with no diagnostic. The leaf-containment ruling (owner is authoritative) makes
the drop *correct*, but it destroys the evidence that the file was malformed.

Consequence: a structural validator arriving later will only ever see files this build has already
cleaned. Emit `tree.leaf_in_children` / `tree.dangling_child` diagnostics on load, through the
existing `decode(..., diagnostics:)` channel, before encode drops them.

### 3. Leaf ordering has no z-order

Per the Plan 1 ruling, leaf containment is `owner`-authoritative and `children` holds child nodes
only. Leaf draw order is therefore *ascending slot order*, which is deterministic but is allocation
order, not an author-controlled z-order — and it moves under undo, since the slot free list is a
stack.

Plan 2's renderer and hit-testing both need a real answer here. If an explicit z-order is required,
it needs its own field; do not reintroduce a second containment list to carry it.

## Performance

### 4. `definitionBounds` rebuilds its bucket map per call

`lib/src/document/draft_document.dart` — a caller iterating every definition is still O(D×E). Plan 1
reduced this from O(D × containers × E), so it improved by a large factor but is not solved. Hoist
the bucket map to the memo that already spans one `_computeExtents` pass.

## Correctness, low severity

### 5. `_boundsOfContainer` memoizes a cycle-truncated box

The `visiting` guard returns `Aabb2.empty()` without memoizing, but the *enclosing* container then
memoizes a box computed without that contribution, and a later legitimate reference reuses the
truncated value. Reachable only on a malformed in-memory tree — so it depends on item 1 staying
open.

### 6. `@immutable` table records alias the caller's collections

`DashPattern.dashes`, `PatternLine.dashes`, `PatternRecord.lines`, `DimStyleRecord.opaque`,
`Diagnostic.handles` all store the list the caller passed. Mutating it afterwards mutates the
record.

Inconsistent with the Plan 1 ruling that wrapped `GroupNode.children` and `Definition.children` in
`List.unmodifiable` for exactly this reason. The obstacle is that these keep `const` constructors,
which `DocumentTables.standard()` relies on and which `List.unmodifiable` forbids. A real
trade-off — resolve it deliberately rather than by omission.

This bug class appeared **five times** in Plan 1 (`Aabb2`, `Node.children`, `RawDataStore.allFor`,
`ComponentRegistry.unknownOf`, and these). Treat every accessor returning a `List`, `Map`, `Set`,
or `Vector2` as guilty until checked.

### 7. `attachUnknown` does not require the `typeId` that `toJson` demands

`ComponentRegistry.toJson` does `payload['typeId']! as String`; `attachUnknown` does not enforce it,
so a payload without it raises a `TypeError` at *save* time rather than at the call. Separately, an
unknown payload silently overwrites a registered component sharing the same handle and typeId.

## Test debt

### 8. Untested error branches and switch arms

Spanning Plan 1 Tasks 2, 3, 4, 5, 12, 14, 16. All verified correct by inspection during the final
review; none is a known defect. One batch commit.

### 9. Numeric-vs-lexicographic handle sort has no fixture

Every sort site was verified numeric (`a.value.compareTo(b.value)`, `int.parse(a).compareTo(...)`).
No test would catch a regression to lexicographic ordering. A `[2, 10]` fixture closes it.

## Accepted as-is — do not "fix" without a design decision

### 10. Undoing a mid-group delete re-appends the child at the end

Disclosed in `lib/src/document/tree.dart`. Fixing it requires carrying an index in
`RemoveNodeCommand`'s inverse, which is a design change belonging to whichever plan owns
re-parenting and z-order (see item 3).

### 11. `Transform2.isIdentity` is an exact `==` check

Explicit human ruling, documented at the getter with a contract test that pins the difference
against `equals(identity, Tolerance.standard)`. It is a fast path, not a geometric decision. Do not
convert it to a tolerance comparison.

### 12. Exact `==` on doubles for stored-value comparisons

Deliberate and restated by category during Plan 1: geometric *decisions* use `Tolerance`;
stored-value comparisons are exact. Both appear throughout. Neither is a defect.

### 13. The extents-scaling test is wall-clock based

`DraftDocument.empty()` constructs its own `EntityStore` with no injection seam, so no deterministic
formulation was available without a production change. It is a best-of-five ratio test with a 6×
threshold against a measured 0.40–2.48× fixed and 88× broken. If it ever flakes, add a
`@visibleForTesting` store parameter to `empty()` and count scans instead.
