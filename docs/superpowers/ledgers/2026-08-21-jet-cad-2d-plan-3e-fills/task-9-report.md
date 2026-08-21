# Task 9 report: `entityBounds` and every one of its call sites

Commit: `c7434ab` on `main` (base `023e724`).

## What changed

`entityBounds` (`packages/jet_cad_2d/lib/src/document/extents.dart`) gains two
optional parameters, `EntityKind? boundaryKind` and `GeometryPayload?
boundaryPayload`, documented as resolved by the caller for the same reason
`textStyle` is (doc comment extended, not just the fill case). `EntityKind.fill`
now returns `Aabb2.empty()` when either is null, and otherwise recurses with
the resolved kind/payload — the function never looks a handle up itself.

Every call site was visited via `grep -rn "entityBounds(" packages/jet_cad_2d/lib
packages/jet_cad_2d/test packages/jet_cad_2d_flutter`, which returned exactly
the 20 sites the brief listed. Table below.

## All twenty call sites

| # | File:context | Reachable by a fill? | Change | peek/read | Why |
|---|---|---|---|---|---|
| 1 | `extents.dart` (the definition) | n/a | Signature + fill case implemented | n/a | — |
| 2 | `draft_document.dart` `_boundsOfContainer` | Yes — iterates every live leaf under a container, any kind | Resolves boundary before calling | `read` for both the entity's own payload and the resolved boundary | Existing code already used `.read()` for the entity's own payload because the result is unioned into a memoized `Aabb2` kept across calls (`memo[container]`); matched that for the boundary lookup too. `peek` used only transiently to extract `boundaryHandleOf` from the fill's own payload before discarding it. |
| 3 | `container_index.dart` `addLeaf` (index build) | Yes — builds every leaf, any kind, once per container per index build | Resolves boundary before calling | `peek` | Runs once per leaf during a whole-index build; `read` copies three objects and nothing here keeps the boundary payload past the call — matches the brief's own snippet. |
| 4 | `spatial_index.dart` `_reconcileEntity` | Yes — the incremental-update hot path for any edited/reused-slot entity | Resolves boundary before calling | `peek` | Runs per reconciled entity at edit/undo/redo rate; standing gate is `query_allocation_test.dart`. Nothing retains the boundary payload past the call. |
| 5 | `reference_walk.dart` (`jet_cad_2d_flutter`, `_leaf`) | Yes — the differential-testing "slow, obvious" painter walks every leaf, any kind, and already used `peek` for its own payload | Resolves boundary before calling | `peek` | Matches the file's own established style — every other lookup in this walk already uses `peek` and discards it after `entityBounds`/draw. |
| 6 | `reference_query.dart:210` `referenceEntitiesInRect` | Not exercised by any current corpus fixture (no fill fixtures in `corpus.dart` yet), but structurally general — iterates `doc.entities.liveSlots` with no kind filter | Resolved anyway, for forward-compatibility with the differential-test oracle | `peek` | Matches its existing style (`doc.geometry.peek(record.geomIndex)`); nothing retained past the call. Verified below (T9b variant) that this currently survives mutation, confirming it is not yet exercised — an honest, checked judgment rather than a guess. |
| 7 | `reference_query.dart:891` `_considerIntersections` | **No** — hard-filtered: `if (kind != EntityKind.line && kind != EntityKind.polyline) continue;` before this call is ever reached | Unchanged | n/a | Unreachable by construction, not by fixture content. |
| 8 | `corpus.dart:638` `_textDefaultMeasurer` helper | **No** — `record.kind` is always `EntityKind.text` or `EntityKind.attrib` in this fixture's own construction | Unchanged | n/a | Unreachable by fixture construction. |
| 9 | `corpus.dart:729` `_textLaidOut`'s local `text()` helper | **No** — `kind` parameter defaults to `EntityKind.text` and every call site in the fixture passes `text` or `attrib` | Unchanged | n/a | Unreachable by fixture construction. |
| 10–15 | `extents_test.dart` ×6 (line/circle/arc/polyline/text×2) | **No** — each test hardcodes a non-fill `kind` | Unchanged | n/a | Unreachable; these are the pre-existing unit tests for the other kinds. |
| 16–17 | `snap_centre_index_test.dart` ×2 (`_expectCentreOutsideItsOwnBox`, arc-revive test) | **No** — both operate on entities built via `_addArc`/`_addNarrowArc`, `record.kind` is always `EntityKind.arc` | Unchanged | n/a | Unreachable by fixture construction. |
| 18 | `text_overlay_test.dart:120` | **No** — `kind: EntityKind.text` is hardcoded in the call | Unchanged | n/a | Unreachable by construction. |
| 19 | `text_paint_test.dart:154` | **No** — `kind: EntityKind.text` is hardcoded in the call | Unchanged | n/a | Unreachable by construction. |
| 20 | `sink_comparison.dart:652` `comparisonTextMask` | **No** — guarded by `if (record.kind != EntityKind.text && record.kind != EntityKind.attrib) continue;` before this call | Unchanged | n/a | Unreachable by construction. |

Plus new tests added to `extents_test.dart`: the brief's three direct
`entityBounds` fill tests, and the fourth — through `SpatialIndex` via
`region(doc)` / `SetEntityGeometryCommand`, imported from
`region_command_test.dart`. Its box read matches the codebase's idiom:
`index.rootIndex.boxOfLeaf(slot) ?? index.rootIndex.dirty.boxOf(slot)` (the
brief's snippet used `index.boxOfLeaf`/`index.dirty` directly, but those are
members of `ContainerIndex`, not `SpatialIndex`; `SpatialIndex.rootIndex`
exposes the same `ContainerIndex` the brief's own `_reconcileEntity` snippet
iterates over).

## Suite output — `packages/jet_cad_2d`

```
$ CI=true dart test
...
00:03 +762: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.19 seconds.
```

## Suite output — `packages/jet_cad_2d_flutter`

```
$ CI=true flutter test
...
00:03 +242 ~1: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)

$ dart format --output=none --set-exit-if-changed .
Formatted 45 files (0 changed) in 0.08 seconds.
```

## Allocation gate

```
$ cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
00:00 +0: forEachInRect does not allocate in steady state
00:00 +1: forEachInstanceInRect does not allocate in steady state
00:01 +2: pickInto does not allocate in steady state, three instances deep
00:02 +3: snapInto does not allocate in steady state, three instances deep
00:02 +4: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +5: All tests passed!

$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: All tests passed!
```

## Mutation transcripts

All mutations applied, tested, and reverted from a `cp`'d original inside one
shell call each, never `git checkout`.

### T9a — fill always returns `Aabb2.empty()`, even when the boundary resolves

Mutated `extents.dart`'s fill case to `return Aabb2.empty();` unconditionally.

```
00:00 +8 -2: an edited boundary moves its fill's indexed box [E]
  Expected: <100.0>
    Actual: <Infinity>
00:00 +8 -3: Some tests failed.

Failing tests:
  test/document/extents_test.dart: a fill bounds to its boundary, not to nothing
  test/document/extents_test.dart: a fill on a circle boundary bounds to the circle
  test/document/extents_test.dart: an edited boundary moves its fill's indexed box
```

**KILLED** — three named tests fail. Restored and reconfirmed identical to the
pre-mutation file via `diff -q`.

### T9b — skip the fill resolution at ONE call site, in turn

**`spatial_index.dart` `_reconcileEntity`** (the one the brief calls out —
this is the site the through-index test exercises, since `SetEntityGeometryCommand`
on an existing boundary drives the incremental reconcile path, not a full
rebuild):

```
00:00 +23 -1: an edited boundary moves its fill's indexed box [E]
  Expected: <100.0>
    Actual: <Infinity>
  the fill is derived from the boundary; if the reconcile misses it, the
  fill is culled and picked against an outline that moved

Failing tests:
  test/document/extents_test.dart: an edited boundary moves its fill's indexed box
```

23 other tests (all of `extents_test.dart` and `region_command_test.dart`,
including the three direct fill-bounds unit tests) **stay green**; exactly the
one test that goes through the index goes red — the mutation the brief calls
"the point of the task." Restored, confirmed `diff -q` identical.

**`container_index.dart` `addLeaf`** (initial build, same mutation shape):
ran against the same two files, then the whole `jet_cad_2d` suite (762 tests)
— **survives** in both cases. This is real: the through-index test edits the
boundary immediately after `region(doc)`, so the box it checks is written by
`_reconcileEntity`, not by the initial `ContainerIndex.build`. No fixture in
the current suite reads a fill's box from a *freshly built, unedited* index.
Flagged as a known coverage gap below.

**`draft_document.dart` `_boundsOfContainer`**: same mutation, ran the full
762-test suite — **survives**, for the same reason: no test currently calls
`doc.extents` on a document containing a fill. Flagged below.

### T9c — `read` instead of `peek` in the index's hot path

Mutated both `geometry.peek(...)` calls in `spatial_index.dart`'s
`_reconcileEntity` boundary-resolution block to `geometry.read(...)`.

```
--- correctness (extents_test.dart + region_command_test.dart) ---
00:00 +24: All tests passed!

--- test/invariants/query_allocation_test.dart ---
00:00 +0: forEachInRect does not allocate in steady state
00:00 +1: forEachInstanceInRect does not allocate in steady state
00:01 +2: pickInto does not allocate in steady state, three instances deep
00:02 +3: snapInto does not allocate in steady state, three instances deep
00:02 +4: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +5: All tests passed!
```

Correctness survives as expected (`peek` vs `read` is an allocation choice,
not a correctness one). **The allocation gate also survives** — this
contradicts the brief's stated expectation. Checked why: `query_allocation_test.dart`
builds its documents once during setup and only *queries*
(`forEachInRect`/`pickInto`/`snapInto`) during the measured "steady state"
window — it performs no `SetEntityGeometryCommand` or other edit inside that
window, so `_reconcileEntity` (and therefore the mutated branch) is never
invoked while allocations are being counted, independent of whether its
fixtures contain a fill. This is a genuine, verified finding, not a
fabrication: the `peek` choice at this site is correct and matches the
surrounding hot-path convention, but no *automated* regression currently pins
it against a `read` regression. Restored, confirmed `diff -q` identical.

### T9b variant — `reference_query.dart:210` oracle

Same "skip resolution" mutation, run against `test/invariants/differential_test.dart`
(72 tests, corpus-driven) — **survives**, confirming the table's judgment that
no current corpus fixture puts a fill through this oracle. Restored, confirmed
identical.

## Concerns / things I was unsure about

1. **The brief's index-test snippet (`index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot)`
   with `index = SpatialIndex(doc)`) does not compile as written** — `boxOfLeaf`
   and `dirty` are members of `ContainerIndex`, not `SpatialIndex`. Used
   `index.rootIndex.boxOfLeaf(slot) ?? index.rootIndex.dirty.boxOf(slot)`
   instead, which is the same expression the brief's own `_reconcileEntity`
   snippet uses (there, the loop variable there is itself a `ContainerIndex`).
2. **Coverage gap, not a defect**: `container_index.dart`'s initial-build
   resolution and `draft_document.dart`'s `_boundsOfContainer` resolution are
   both implemented correctly (mirror the same pattern, verified by direct
   code reading) but are not currently pinned by any test that would go red
   if the resolution were silently deleted — no fixture builds a fresh index
   or reads `doc.extents` over an *unedited* fill. Task 9's own required test
   only exercises the reconcile path. Left as-is rather than inventing new
   fixtures outside the brief's scope; worth a follow-up test in a later task
   if fill fixtures are added to `corpus.dart`.
3. Per the same reasoning, `reference_query.dart`'s `referenceEntitiesInRect`
   was resolved defensively (it is the oracle for `entitiesInRect`, which
   *will* return correct fill boxes post-Task-9) even though nothing in the
   current corpus reaches it — judged safer than leaving a production-mirroring
   oracle silently wrong for a kind the real index now handles.

---

## Fix round 1: closing the `container_index.dart` build and `draft_document.extents` gap

Both survivors from T9b were genuine silent-call-site gaps: two of the five
production sites' boundary resolution could be deleted with nothing going
red. Closed with two new tests in `extents_test.dart`.

**Why the obvious fixture (a plain `region(doc)`, no edit) cannot work for
either site — checked, not assumed.** `AddRegionCommand.apply` enforces
`fill.owner == boundary.owner`, and `entityBounds`'s fill case recurses to
produce a box *bit-identical* to the boundary's own (`entityBounds(kind:
boundaryKind, payload: boundaryPayload, ...)` — the same call, on the same
payload). So for any document built through the command layer, the boundary
is always a leaf in the exact same container as the fill, contributing an
identical box. `Aabb2.union` treats an empty box as a no-op
(`if (other.isEmpty) return this;` in `aabb2.dart`), so
`union(boundary_box, fill_box=boundary_box)` and
`union(boundary_box, fill_box=Aabb2.empty())` are the same value — always,
regardless of what else is in the document. A `doc.extents` test built on a
plain region, with or without unrelated entities elsewhere, is mathematically
incapable of going red under this mutation. Confirmed by writing that
version first and running it against the T9b mutation below: it passed
green on both sides, i.e. it would have been a degenerate fixture.

**`container_index.dart` build** doesn't have that problem — `ContainerIndex`
indexes each leaf as an independent entry keyed by slot, so the fill's own
`boxOfLeaf` can be read directly, decoupled from the boundary's. New test
`'a fresh index resolves a fill to its boundary without any edit'`: builds a
region, constructs `SpatialIndex(doc)` once with **no edits at all**, and
reads `index.rootIndex.boxOfLeaf(fillSlot)` directly — exercising
`ContainerIndex.build`'s own resolution rather than `_reconcileEntity`'s
(which the existing edit-based test already covered).

**`draft_document.extents`** needed the redundancy actually broken: the
boundary now lives in a `Definition` nothing instantiates, added directly via
`doc.tree.addDefinition` + `AddEntityCommand` (not `AddRegionCommand`, which
would refuse the mismatched owners). Unplaced, it is unreachable by any tree
walk from the root, so it never contributes its own box to `doc.extents` —
the *only* way its box can appear is through the fill, sitting at the root,
resolving the boundary handle carried in its own payload. New test
`"doc.extents finds a fill's boundary by handle, not by walking the tree"`
adds a second, unrelated line at the root too, so the assertion pins one
specific corner (`10.0`) rather than merely `isEmpty`/not-`isEmpty`, which
would have been a coarser, more guessable signal.

### Mutation re-runs

**`container_index.dart`**, same "skip resolution" mutation as before
(`if (record.kind == EntityKind.fill)` → `if (false && record.kind ==
EntityKind.fill)`), against `test/document/extents_test.dart`:

```
00:00 +11 -1: a fresh index resolves a fill to its boundary without any edit [E]
  Expected: <0.0>
    Actual: <Infinity>
  the fill is derived from the boundary; if the initial build never resolves
  it, a document opened fresh -- never edited -- indexes its fill as an
  empty box that is never found and never picked

Failing tests:
  test/document/extents_test.dart: a fresh index resolves a fill to its boundary without any edit
```

**KILLED.** 11 other tests in the file, including the reconcile-path index
test and the new `doc.extents` test, stay green — exactly the fresh-build
site is exercised. Restored from a `cp`'d original inside the same shell
call; `diff -q` confirmed identical afterward.

**`draft_document.dart`**, same mutation shape, same file:

```
00:00 +12 -1: doc.extents finds a fill's boundary by handle, not by walking the tree [E]
  Expected: <10.0>
    Actual: <-1.0>
  only the fill can pull the orphaned boundary's box into doc.extents; a
  fill that fails to resolve it leaves this corner at -1, from the line
  alone.

Failing tests:
  test/document/extents_test.dart: doc.extents finds a fill's boundary by handle, not by walking the tree
```

**KILLED.** All 12 other tests, including the two index tests, stay green.
`-1.0` is exactly what the doc comment predicted: the line's own corner,
with the boundary's box entirely absent from the union. Restored the same
way, `diff -q` confirmed identical.

### Gate — both packages, after the fix

```
$ cd packages/jet_cad_2d && CI=true dart test
00:03 +764: All tests passed!
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.19 seconds.

$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:03 +242 ~1: All tests passed!
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
$ dart format --output=none --set-exit-if-changed .
Formatted 45 files (0 changed) in 0.08 seconds.

$ cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
00:02 +5: All tests passed!

$ git status --porcelain
 M packages/jet_cad_2d/test/document/extents_test.dart
```

(764 = the 762 reported before plus the 2 new tests in this round; no other
file touched — only `extents_test.dart` grew.)

### Left alone, as directed

- `reference_query.dart` oracle T9b survivor: unchanged, deferred to Task 10.
- T9c (`peek`/`read` in the reconcile hot path not measured by
  `query_allocation_test.dart`): unchanged, deferred to Task 16.
