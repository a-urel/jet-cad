# Plan 3a mutation log

**Verdict: all fourteen mutants accounted for.** Twelve were killed by tests
that already existed, one was killed by a test written for it, and one is
provably equivalent once a missing invariant is enforced — which it now is.

The plan named four surfaces where a defect would be invisible to a passing
suite: the camera and rebasing arithmetic, the merge ordering, the
per-container sort and deduplication, and style resolution. Plan 2's evidence
is that defects there are found by mutation, not by reading, so each mutant
below was applied to the source by hand, both suites were run, and the source
was restored.

Baseline before any mutation: `jet_cad_2d` 619 tests, `jet_cad_2d_flutter` 106
tests, both green. Every mutant was applied in isolation.

## The table

| # | Mutant | File | Killed by |
|---|--------|------|-----------|
| 1 | `camera . leaf . rebase` → `camera . rebase . leaf` | `draft_painter.dart` | `draft_painter_recursion_test.dart: two levels of nesting compose ancestors outward-in` (+4 more) |
| 1b | the plan's own reference composition: world origin after the camera | `draft_painter.dart` | `draft_painter_root_test.dart: a group-owned leaf is drawn through its folded transform` (+6 more) |
| 2 | `about.multiply(m)` → `m.multiply(about)` in `zoomAt` | `camera_controller.dart` | `camera_controller_test.dart: zoomAt keeps the world point under the cursor fixed` |
| 3 | `_instances[next] < leafHandle` → `<=` | `draft_painter.dart` | **equivalent** — see below |
| 4a | drop `scratch.leaves.sortByHandle` | `draft_painter.dart` | `draft_painter_recursion_test.dart: definition contents are drawn in ascending handle order` (+5 more) |
| 4b | drop the neighbour dedupe | `draft_painter.dart` | `draft_painter_recursion_test.dart: a slot in both the tree and the dirty overlay is drawn once` |
| 5 | `accumulated.multiply(instanceTransform)` → reversed | `draft_painter.dart` | `draft_painter_recursion_test.dart: two levels of nesting compose ancestors outward-in` (+4 more) |
| 6 | `rebaseOriginFor` returns the view centre unsnapped | `camera_controller.dart` | `camera_controller_test.dart: rebaseOriginFor is stable while the camera moves within one grid step` (+3 more) |
| 6b | `floorToDouble` → `truncateToDouble` | `camera_controller.dart` | `camera_controller_test.dart: rebaseOriginFor snaps downward on negative coordinates, not toward zero` |
| 7 | `ByBlock` resolves to the layer instead of the context | `style_resolver.dart` | `style_resolver_test.dart: ByBlock resolves against the context, and layer-0 inherits it` (+4 more, across both packages) |
| 8 | layer-0 resolves to `layerZero` instead of `ctx.layer` | `style_resolver.dart` | `style_resolver_test.dart: the layer-0 rule is substitution, not deferral — an entity on layer 0 is drawn on the placing instance's layer` |
| 8b | layer-0 substitution dropped in `contextFor` | `style_resolver.dart` | `style_resolver_test.dart: … a nested instance on layer 0 resolves ByLayer against the substituted layer` |
| 9 | anisotropy threshold comparison flipped | `draft_painter.dart` | `lineweight_test.dart: the threshold is exclusive, so exactly 2.0 stays on the fast path` (+6 more) |
| 10 | `_strokeWidth` skips the `/ _residualScale` division | `canvas_draw_sink.dart` | `draw_sink_test.dart: stroke width is a paper quantity, divided out of the residual` and `lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically` |

Four mutants beyond the plan's ten were added while running it: 1b, 6b, 4b, 8b.
1b is the plan's own reference implementation of the rebase, kept as a mutant
because the implementation deliberately deviates from it (see the ledger); 6b
and 4b split plan rows that named two behaviours in one line; 8b covers the
`contextFor` half of the layer-0 rule, which the plan's row 8 did not reach.

## Mutant 3: a survivor that was not a missing test

`<` → `<=` in the root merge changed nothing any test could observe. The two
comparisons differ only when a root-level instance handle equals a leaf entity
handle — a tie no fixture could produce, and the reason no fixture could is
what matters.

Entities and nodes live in separate stores. `AddEntityCommand` checked
`entities.containsHandle`; `AddNodeCommand` checked `tree[handle]`. **Neither
checked the other store**, so one handle naming both an entity and a node was
accepted. That is legal to neither DXF, where handles are globally unique, nor
to this codebase, which already raises one shared `handleSeed` from both
commands — the intent was a single handle space and the enforcement was half of
one.

The consequences reach past rendering. `DocChange.touched` is a `Set<Handle>`,
so a collision leaves "which one changed?" without an answer, and the render
path's two merges — the root one in `paint` and the per-container one in
`_drawContainer` — both order by comparing handle values, where a tie has no
defined result.

So the fix is the invariant, not a fixture:

- `AddEntityCommand` now also rejects a handle the tree holds, and
  `AddNodeCommand` a handle the entity store holds. The entity-side check runs
  **before** `geometry.add`, so a rejection leaks no geometry slot — the same
  leak an earlier test already pins for the same-store path.
- Three tests in `commands_test.dart`, under `handles are one space, not two`.
  The third is the one that keeps the guard honest: undo must return a handle
  to the other store, or undo/redo would slowly poison the handle space.
- `DraftPainter.paint` now names the invariant its comparison depends on.

Two existing fixtures were genuinely colliding and the new guard caught them:
`container_index_test.dart` wrote out `Handle(1000 + i)` in a loop that also
called `addLine`, which draws from the seed the loop had just raised — so the
second pass reused the entity's handle. `pick_test.dart` wrote out
`Handle(402)` for an instance after `addEntity` had already been handed 402.
Both now allocate from the seed. Neither test asserted on the handle values;
both had been silently building malformed documents.

With the guard in place mutant 3 is **equivalent** — no reachable document
distinguishes `<` from `<=`. Removing either half of the guard is caught:

| Guard mutant | Killed by |
|---|---|
| drop the entity-side cross check | `commands_test.dart: … AddEntityCommand refuses a handle the tree already holds` |
| drop the node-side cross check | `commands_test.dart: … AddNodeCommand refuses a handle the entity store already holds` |

## What this says about the fixtures

The `differentialFixture` earns its rule. Mutants 1, 1b, 4a and 5 are all
composition-order or ordering defects, and each was caught first by the
differential comparison against `referenceWalk` — the fixture's no-identity-
transform rule is why. Plan 2's post-mortem records four fixtures that missed a
composition-order defect because their transforms were the identity, which
commutes.

Note also which mutants were caught by *one* test only: 2, 4b, 6b, 8, 8b. Those
are single points of failure in the suite — a fixture change that weakens any
one of them removes the only evidence for that behaviour.

## Reproducing

Each row was produced by replacing the named expression, running
`flutter test` in `packages/jet_cad_2d_flutter` (and `dart test` in
`packages/jet_cad_2d` for the resolver rows), and restoring the file. Final
state after the mutant-3 fix: `jet_cad_2d` 622 tests, `jet_cad_2d_flutter` 106
tests, both green.
