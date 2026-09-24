# Task 3 report: neighbourhood, determinism, load and drift

## Tests written

`packages/jet_cad_2d/test/parametric/neighbourhood_test.dart`, N1-N14, taken
verbatim from the brief. No test body was changed. The only edit relative to
the brief's listing was running `dart format` on the file, which reflowed a
handful of long lines (e.g. wrapping `test(...)` calls whose title + body
first line exceeded 80 columns, and the multi-arg `create(...)` call in N6)
and added a blank line before the trailing `expect` in N6's local `run`
function. No semantic change.

## Deviation from the brief

None. Every one of N1-N14 passed on the first run against Task 2's code
(commit `9e5c2dd`) with no fixture or production-code changes. No ruling
required.

## Test output (verbatim)

```
$ cd packages/jet_cad_2d && CI=true dart test test/parametric/neighbourhood_test.dart
00:00 +0: loading test/parametric/neighbourhood_test.dart
00:00 +0: N1 the pair clips each other: A 5, B 3, and no drift
00:00 +1: N2 an edit of A changes B too (M-06d)
00:00 +2: N3 moving A away restores B: old neighbours are dirty (M-06l)
00:00 +3: N4 both transforms matter: B clipped in world by A, both rotated (M-06g engine)
00:00 +4: N5 the same edit on a document and its reload gives the same bytes (M-06b)
00:00 +5: N6 two seeds in one command: either child order, same bytes (M-06b')
00:00 +6: N7 per-object world geometry does not depend on creation order
00:00 +7: N8 load then save is byte-identical, typed
00:00 +8: N9 stale geometry on file is trusted on load and reported by drift (M-06f, Ruling 06-7)
00:00 +9: N10 undo restores stale geometry exactly: undo never regenerates (M-06n)
00:00 +10: N11 a misplaced component is reported and never regenerated
00:00 +11: N12 an edit inside a query walk fails before anything mutates
00:00 +12: N13 rotating A while it overlaps B is one step and re-clips B (Review Focus 1)
00:00 +13: N14 swallowed whole, then back, with new handles (Review Focus 3)
00:00 +14: All tests passed!
```

## Gate summaries

### Engine line (`packages/jet_cad_2d`)

```
$ CI=true dart test
...
00:03 +941: All tests passed!
```
Exit code: 0. Engine count rose from 927 (start of task) to 941 (+14 for
N1-N14), matching exactly.

```
$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 140 files (0 changed) in 0.26 seconds.
```
Exit code: 0.

### Render line (`packages/jet_cad_2d_flutter`)

```
$ CI=true flutter test
...
00:16 +923 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Exit code: 1 (`echo $?` right after the flutter test invocation, captured
separately from the piped/tailed output). These are exactly the five standing
`text_ladder_golden_test.dart` failures named in the task instructions and
`global-constraints.md`'s branch-point count (923 + 1 skip + the five
goldens) — the standing exception, nothing new. No test outside that file
failed.

```
$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 175 files (0 changed) in 0.32 seconds.
```
Exit code: 0.

`flutter pub get` ran as a side effect of `flutter analyze`/`flutter test`
inside this workspace; `git status --short` after all gates shows only the
new test file, confirming `analysis_options.yaml` was not staged or modified
in the working tree.

## Files changed

- `packages/jet_cad_2d/test/parametric/neighbourhood_test.dart` (new file,
  N1-N14).

No production code, support file, or spec/plan file was touched.

## Self-review: which named mutant kills each N-test

- **N1** — no specific named mutant; it pins the base fixture invariant (A 5,
  B 3 children, no drift) that every other relational test in this suite and
  in `regeneration_test.dart` depends on. A mutant that broke reach-overlap
  detection (e.g. flipping an inequality in `_survey`'s `overlap`) or that
  fed the wrong neighbour set to `generate` would change the child counts and
  turn this red.
- **N2 (M-06d)** — a mutant that computed a seed's neighbours-after but not
  neighbours-before (or vice versa) into the closure would still regenerate
  A but skip B, since B is only reached via A's neighbour edge, not as a
  direct seed. `worldSegments(doc, hB)` would then stay unchanged and
  `isNot(b)` would fail.
- **N3 (M-06l)** — the mutant is any closure construction that only takes
  *after*-neighbours (dropping `before.neighbours[s]` in `_closure`). Moving
  A away means A has no neighbours *after* the move, so if only after-
  neighbours count, B (a before-neighbour, now orphaned) is never re-seeded
  and keeps its stale 3 children instead of growing back to 4. The test
  would then see `kids(doc, hB)` stay at 3.
- **N4 (M-06g engine)** — `_worldOf` returning the identity transform. With
  ranked geometry left in local coordinates instead of world, B's clipped
  segments would coincide with, or fall inside, A's local rectangle when
  transformed by the identity, so at least one midpoint would land inside
  `(0,2000)x(0,1000)` and the `isFalse` assertion would fail. This is exactly
  Ruling 06-8's engine-side placement of M-06g, and the test is deliberately
  built on a rotated, translated A (`atA`) so an identity substitution is
  observable — a fixture at the identity transform would pass this mutant by
  accident.
- **N5 (M-06b)** — removing any of the three sorts named in Ruling 06-5 (the
  survey's object order, the closure's sort, or `ComponentStore.handles`'
  internal sort) makes the plan's handle-reservation order, and hence which
  reserved handle each new child gets, depend on component-store insertion
  order. `x` and `y` differ only in that in-memory order (`x` holds `[n2,
  n1, s]`, `y`/reload holds `[n1, n2, s]`), so a missing sort would make
  `enc(y)` and `enc(x)` diverge after the same edit is applied to both.
- **N6 (M-06b')** — removing the closure's own sort alone (leaving the
  survey and `ComponentStore.handles` sorted). The seed set `{hA, hB}` is
  built from a `Set`, so its iteration order still depends on which
  `TransformNodeCommand` ran first in the compound; without `_closure`
  re-sorting into ascending handle order, `run(true)` and `run(false)` would
  reserve new children's handles in different orders and diverge.
- **N7** — a mutant that let creation order leak into `generate`'s neighbour
  lookup (e.g. `neighbours` built from an unsorted map so the first-seen
  neighbour's parameters are read at each object's own reach position,
  order-dependent) would make A's or B's *world* geometry itself differ
  between `pair(x)` (A created first) and `pair(y, bFirst: true)` (B created
  first), even though child *handles* are allowed to differ (D11). This test
  compares `worldSegments`, not raw bytes or handles, isolating exactly that
  guarantee.
- **N8** — a mutant in the codec's typed round-trip (e.g. a component
  written with extra/fewer digits than parsed back, or `registerComponents`
  wired after `loadJson` reads components as in Ruling 06-1's original
  ordering bug) would make `enc(back) != s` or leave `ClipRect` unregistered
  so `back.components.get<ClipRect>(hA)` returns null instead of `(2600,
  1400)`.
- **N9 (M-06f, Ruling 06-7)** — the mutant this pins is `install()` (or the
  system's constructor) eagerly regenerating on load. If load regenerated,
  the tampered coordinate (`12.5`) would be overwritten with the correct
  computed value before `enc(back)` is taken, so `enc(back) != stale` would
  fail (bytes would differ from the stale file) — the opposite direction
  from what one might expect, which is exactly why Ruling 06-7 exists: this
  test's construction (comparing round-tripped bytes to the hand-tampered
  ones) is the kill for "regeneration runs on load".
- **N10 (M-06n)** — a mutant where `ParametricReplay.apply` called `_run`/
  regeneration instead of replaying the recorded inverse compound would
  regenerate B's geometry on undo (since the stale child's payload differs
  from what `generate` would produce), so `canon(back)` after `undo()` would
  no longer equal `stale` — undo would "fix" the stale geometry instead of
  restoring it byte-for-byte.
- **N11** — a mutant in `_isObject`'s parent-is-root check, or in
  `diagnostics()` iterating only `objects` instead of every handle with a
  registered component, would either misclassify the leaf line as a
  parametric object (and try to generate children for it, so
  `kids(doc, h)` would be non-empty) or drop the diagnostic entirely (so
  `d.single` would throw on an empty list, or `d.single.code` would not be
  `parametric.misplaced`).
- **N12** — a mutant that dropped or narrowed the `_inQuery` reentrancy guard
  in `SpatialIndex.forEachInRect` (e.g. only guarding `add`/`remove` but not
  `execute`'s downstream document mutation) would let the nested
  `doc.commands.execute` inside the visitor succeed instead of throwing
  `QueryReentrancyError`, so `error` would stay `null` and
  `expect(error, isA<QueryReentrancyError>())` would fail; if the mutation
  is instead allowed to partially apply before some other failure,
  `enc(doc) != before` would catch it too.
- **N13 (Review Focus 1)** — a mutant that special-cased a `CompoundCommand`
  containing exactly one `TransformNodeCommand` to skip the parametric
  wrapper (an "optimisation" that unwraps trivial compounds before the
  expander sees them) would leave B's geometry stale after the rotation, so
  `worldSegments(doc, hB)` would equal the pre-rotation `b`, and the
  `isNot(b)` assertion would fail; it would also not add an undo step,
  catching an alternate mutant that merges the regeneration into the
  existing step instead of one atomic compound.
- **N14 (Review Focus 3)** — a mutant in `_plan`'s kind/ordinal matching
  that reused a *removed* child's freed handle for a *different* kind's new
  child in the same regeneration step (crossing the by-kind bucketing), or
  one that matched surplus/missing children by position across the whole
  closure instead of per-object per-kind, would let some element of the new
  3-child set collide with the old 3-child set, so
  `kids(doc, hB).toSet().intersection(old.toSet())` would be non-empty
  instead of empty. It also pins that going through zero children and back
  to nonzero reserves fresh handles rather than somehow reusing the just-
  freed ones from the same edit.

## Concerns

None. All fourteen tests passed against Task 2's code as committed
(`9e5c2dd`) with no code or fixture changes, no weakened assertions, and no
ruling to ledger. The engine gate is fully green (941/941, analyze clean,
format clean). The render gate shows only the five pre-existing
`text_ladder_golden_test.dart` failures named as the standing exception in
`CLAUDE.md` and `global-constraints.md`; analyze and format are clean there
too.
