# Sub-project 06 spike: findings

**Date:** 2026-09-24.
**Branch:** `spike/06-parametric`, cut from `main` at `48b373c`.
**Status:** throwaway. The branch is never merged; this note is its only
output. It is an input to 06's brainstorm, not a design.

## What was built

- **The client.** A throwaway `ParametricRectangle`:
  - a `GroupNode` placed at a non-identity transform, carrying a
    `ParamRect(width, height)` component;
  - LINE children in group-local space, generated from the parameters;
  - each rectangle is its rectangle minus the interior of every overlapping
    neighbour.
- **Why the subtraction.** It makes the dependency **mutual**: A clips B and
  B clips A, standing in for a wall mitre. The pair fixture is checked not
  to be degenerate: A has 5 children and B has 3. The first fixture had no
  real overlap, and Q2's count assertion caught that.
- **Regeneration is two-phase:**
  1. every footprint is read from parameters and transforms only;
  2. each dirty object's segments are computed from those footprints.

  Children are reused in ascending handle order (`SetEntityGeometryCommand`),
  extras are removed, and missing ones are added with `handleSeed.next()`.
- **Approach A (`ParametricEdit`).** A wrapper command:
  1. snapshots the neighbour map;
  2. applies the inner edit;
  3. derives seeds from `touched`;
  4. regenerates the closure (seeds ∪ old neighbours ∪ new neighbours) as a
     `CompoundCommand`;
  5. returns `Compound([regen⁻¹, edit⁻¹])` as the inverse.

  Undo and redo replay that concrete inverse and **never regenerate**. A2
  installs the wrapper for every command through a three-line dispatcher
  hook, `CommandDispatcher.wrapCommand`, added on the spike branch only.
- **Approach B.** An `onAfterMutate` pass, chained after the `SpatialIndex`'s
  hook. It executes the regeneration as a second command:
  - **naive:** it stays a second command;
  - **folded:** a spike-only `foldLastTwo` merges the two history entries.

- **Tests.** `test/spike06/`, 16 tests, all green. The engine suite with the
  hook is 927 = 911 + 16, green, allocation invariants included.

## Answers to the roadmap's open questions

| Question | Answer, with evidence |
|---|---|
| Where does the compound live? | **Already in the engine, and enough.** `CompoundCommand` needed no change. The only engine addition A needs is optional: a dispatcher hook so edits from *any* tool are wrapped (A2). A caller-built wrapper works without it (A1). |
| When does regeneration run? | **Inside the same `apply`, after the inner edit (A).** One undo step (Q2). It does not trip `QueryReentrancyError`, because it reads components and the tree, never the index (Q7). B-naive gives **2 undo entries per edit**; one undo reverts only the regeneration, so the parameters say 2600 while the geometry is the old one: a stale state one keystroke away (Q9). B-folded works (Q10), but needs a history-merge API, a re-entrancy flag, a skip for undo and redo changes, and chaining onto the single `onAfterMutate` slot that `SpatialIndex` already owns. |
| What triggers it? | **`touched`, mapped to parametric owners.** A touched group with the component is a seed, and so is a touched child's owner. Coarse but sufficient. A move (`TransformNodeCommand`) is a trigger with no extra wiring (Q2c). |
| Dependency graph? | **Derived each time, from parameters.** Old neighbours must be included: moving A away must restore B (Q2c, killed by M-06d). The "before" neighbour map is snapshotted before the inner edit applies. The index cannot be used for this inside `apply`, because it is reconciled only in `onAfterMutate`, after `apply` returns. That last point is read from the code, not measured. |
| Cycles? | **No iteration needed.** Generation reads neighbours' *parameters*, never their *generated geometry*, so a mutual dependency is just two independent evaluations. The fixed-point question only arises if geometry depends on geometry. A wall mitre does not: it needs centreline and thickness, which are parameters. **M-06e is vacuous under this design.** |
| Determinism | Same state plus the same edit gives the same bytes, **provided the regeneration walk sorts** (Q5, Q5b). Creation order is *history*, and it legitimately changes child handles: A's children are 1001..1004, 2001 built A-first, and 2005..2009 built B-first (Q6). Per-object world geometry is order-independent. |
| On load: trust or regenerate? | **Trust.** Regenerating on load changed nothing (Q4, the M-06f probe answered). Regeneration is a pure function of the saved parameters and transforms, and doubles round-trip exactly through the codec. A "would regeneration change anything?" check is a cheap `validate()` diagnostic. |
| Direct edit of a generated line | Under A2 it is **silently overwritten** by the regeneration it triggers, but it still costs an undo entry (Q12). The spec must choose: refuse it, which is cleaner, or back-solve. |
| Selectable as one thing? | Not probed. It is 02's group-versus-leaf question, and the spec must answer it. |

## Findings nobody asked about

1. **Permissions.** Under `DraftPermissions.runtime` a *parameter* edit is
   refused: `PermissionDeniedError: "Set component" needs geometry` (Q11).
   The regeneration needs `geometry`, which runtime does not grant. The
   doctrine says runtime may "change properties". The spec must decide
   whether derived geometry needs the geometry capability.
2. **Draw order interleaves.** A child added by a later regeneration takes a
   fresh handle above every other object's. A's fifth child is 2001, above
   B's group at 2000 (Q6). If a parametric object's children must draw
   together, handle-order draw order does not give that for free.
3. **Slot order is history.** The codec writes entities in slot order, and
   freed slots are reused. In these fixtures the raw bytes happened to match
   (Q2, Q5). In general, "byte-identical" holds for load→save (Q3) and for
   the same state plus the same edit. It does not hold across different
   histories. The roadmap's "two insertion orders give byte-identical
   output" criterion must be restated. Options:
   - sort entities by handle on encode, a format-neutral codec change;
   - compare a canonical form.
4. **Walk order defence in depth.** M-06b was killed only when **both** the
   store's sort and the walk's sort were removed. Either one alone suffices.
   A single-seed fixture (Q5) could not kill it; it took two neighbours
   gaining children in one edit (Q5b). The spec should require the walk to
   sort, and not rely on `ComponentStore.handles`.
5. **The M-06g trap moved.** Children live in group-local space, and the
   renderer applies the group transform. So dropping the transform is
   invisible for an isolated object: Q1 survived M-06g. It shows only
   through *relations* between objects (Q2, Q2b, Q2c). The degenerate fixture
   for M-06g is "one object", not only "identity transform".
6. **M-06a is not reachable from this design.** Every compound the spike
   builds has independent children: distinct handles, and a node plus its
   component. Reversing the inverse order changed nothing in the spike. The
   engine's own `compound_command_test.dart` still kills it.
7. **Cost.** 200 rectangles, one edit: 8.2–8.7 ms over three runs, with
   800 entities. The naive parts:
   - the O(n²) neighbour map, built twice;
   - a scan of every entity per dirty object to find its children, since
     there is no owner index.

   That is fine for a floor plan's few hundred parametric objects, but an
   owner→children index and a broad phase would be needed well before 5,000.

## Mutants

| Mutant | Result | Killed by |
|---|---|---|
| M-06a (compound inverse forward) | survived the spike; killed by the engine's `compound_command_test.dart` | see finding 6 |
| M-06b (hash/insertion order) | engine only: survived; walk only: survived; **both: killed** | Q5b |
| M-06c (regeneration outside the undo step) | killed | Q2 |
| M-06d (dependents skipped) | killed | Q2, Q2b, Q2c, Q4, Q6, Q10 |
| M-06e (no fixed-point bound) | N/A: no iteration exists | — |
| M-06f (regenerate on load) | probe answered: a no-op | Q4 |
| M-06g (group transform dropped) | killed; **Q1 survived** | Q2, Q2b, Q2c |

M-06c, M-06d and M-06g are flags read from `MUTANT` in the throwaway code.
M-06a and M-06b are cp-backed edits of the engine, restored and diffed
clean.

## Recommendation for the spec

1. **Approach A: regenerate inside the command.** Fold the edit and its
   regeneration into one `CompoundCommand` whose inverse is concrete. Undo
   and redo never regenerate. Handles stay stable on redo, verified.
2. **A dispatcher hook** (`wrapCommand`, or a "command expander") so that
   moves, grip edits and deletes from existing tools regenerate without each
   tool knowing about parametrics. Or require every tool to route through one
   application-side function. The hook is three lines and keeps 03's and
   05's tools untouched.
3. **Two-phase, parameters-only generation.** No fixed point. Neighbours come
   from parameters, including the pre-edit neighbours.
4. **Trust geometry on load.** Add a `validate()` diagnostic for drift.
5. **Decide in the spec:**
   - the permission question (finding 1);
   - draw order of regenerated children (finding 2);
   - the restated byte-identity criterion (finding 3);
   - what happens to a direct edit of a generated entity;
   - whether the parametric group is selected as one thing.
