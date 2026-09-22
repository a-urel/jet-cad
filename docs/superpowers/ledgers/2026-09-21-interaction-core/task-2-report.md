# Task 2 report — `forEachLeafInBand` and `forEachInstanceInBand`

Status: **DONE**

## What I implemented

`packages/jet_cad_2d/lib/src/index/spatial_index.dart`, a new
`// --- band selection (spec 02, D8)` section between `forEachInstanceInRect`
and the pick section:

- `enum BandMode { window, crossing }` (library level, above `SpatialIndex`) and
  the private `enum _BandVerdict { pass, fail, empty }` beside it.
- `void forEachLeafInBand(Aabb2 world, BandMode mode, QueryFilter filter, void Function(int slot) visit)`
  — root-container leaves only, reentrancy guard taken, `QueryFilter` honoured,
  fills skipped, slots deduplicated, results ascending by handle. Window queries
  the band itself; crossing queries the band widened by `_broadPhaseMargin().pick`.
- `void forEachInstanceInBand(Aabb2 world, BandMode mode, QueryFilter filter, void Function(Handle instance) visit)`
  — root-level instances, descending into the definition through `_bandDescend`,
  ascending by handle value. Window searches root instances over `_kAllBox`,
  crossing over the widened band.
- Private helpers, all in the same section: `_kAllBox`, `_leafPasses`,
  `_bandDescend`; plus `_localBandBox(Transform2 toLocal, Aabb2 world)` written
  beside `_localQueryBox`, the same four-corner pullback over a rectangle
  instead of a point ± half-size.
- Import of `../geometry/band_predicates.dart` (Task 1).

`_bandDescend` mirrors `_descend`'s structure: `_ensurePathCapacity`,
`_containerPath`, the `toWorld.invert()`/`SingularTransformError` guard,
`_scratchForDepth(depth)` collected before recursing (never from inside the
R-tree visitor), the O(depth) cycle guard, and `_composeLeafTransform` filling
`_lta.._ltf` for the crossing narrow phase.

Test: `packages/jet_cad_2d/test/index/band_query_test.dart` (new), 14 tests.

## Departures from the brief

1. **`doc.tables.layers.add(...)`, not `put`.** `TableSection` (document/tables.dart:73)
   exposes `add`, `remove`, `clear`, `operator []` and `byName`. There is no
   `put`.
2. **M-02s band widened to `Aabb2.raw(90, 990, 200, 1030)`.** The brief reuses
   M-02a's band `(90, 990, 200, 1010)` and then moves the straddler to
   `[100,1020, 120,1020]`, which is *outside* that band in y — the assertion
   "window visits `{inside, straddler}`" cannot hold as written. I kept the
   brief's edited geometry and raised the band's `maxY` to 1030, which is the
   smaller change and still only passes by reading the dirty overlay: the test
   asserts the same band answers `{inside}` alone *before* the edit, and
   `index.rebuildCount == 1` proves no rebuild intervened.
3. **The duplicate-slot guard is an adjacent-pair check after the sort, not
   `_scratchContains` before the add.** The brief's `_scratchContains` scans
   the whole result buffer on every accepted slot, which is quadratic in the
   number of results — and a window band dragged over a whole drawing has as
   many results as the drawing has entities, which is exactly the case that
   makes it hurt. Sorting first puts duplicates adjacent, so one comparison per
   result replaces the scan. `_leafPasses` is a pure function of the slot, so
   both visits of a duplicated slot agree and it does not matter which survives.
4. **`_leafPasses` computes the payload and `_composeLeafTransform` only on the
   crossing path.** Window reads the indexed (or overlay) box and needs
   neither.
5. **`_ensurePathCapacity(0)` / `_containerPath[0] = …` hoisted out of
   `forEachInstanceInBand`'s loop** — the value does not change per instance.
6. **`_kAllBox` is `static const`, not `static final`** (`Aabb2.raw` is a const
   constructor).
7. **Added tests beyond the brief's ten**, because three named mutations
   survived the brief's set (see below): a window/far-leaf test, an
   empty-container test, a non-conformal-circle crossing test, and an instance
   ordering test. The differential also grew instance-sized bands, because the
   brief's twelve random bands over a 60000 × 40000 floor plan never touched a
   single instance — the instance half of the differential agreed vacuously.
   Three counters at the end of that test now refuse a vacuous corpus.

## TDD evidence

### RED

Implementation absent (`git checkout -- lib/src/index/spatial_index.dart`),
tests present:

```
$ cd packages/jet_cad_2d && CI=true dart test test/index/band_query_test.dart
00:00 +0: loading test/index/band_query_test.dart
00:00 +0 -1: loading test/index/band_query_test.dart [E]
  Failed to load "test/index/band_query_test.dart":
  test/index/band_query_test.dart:71:52: Error: Type 'BandMode' not found.
  List<int> leavesIn(SpatialIndex index, Aabb2 band, BandMode mode,
                                                     ^^^^^^^^
  ...
  test/index/band_query_test.dart:74:9: Error: The method 'forEachLeafInBand' isn't defined for the type 'SpatialIndex'.
   - 'SpatialIndex' is from 'package:jet_cad_2d/src/index/spatial_index.dart' ('lib/src/index/spatial_index.dart').
  Try correcting the name to the name of an existing method, or defining a method named 'forEachLeafInBand'.
    index.forEachLeafInBand(band, mode, filter, out.add);
          ^^^^^^^^^^^^^^^^^
  ...
  test/index/band_query_test.dart:81:9: Error: The method 'forEachInstanceInBand' isn't defined for the type 'SpatialIndex'.
    index.forEachInstanceInBand(band, mode, filter, out.add);
          ^^^^^^^^^^^^^^^^^^^^^
```

A first RED at the *behaviour* level followed once the methods existed: with
the brief's twelve random bands the differential failed on my own non-vacuity
counter —

```
00:00 +9 -1: crossing and window agree with the brute-force arm on the generated corpus [E]
  Expected: a value greater than <0>
    Actual: <0>
     Which: is not a value greater than <0>
  same, for the instances
```

— i.e. the instance arm never selected anything. Fixed by deriving a band per
root instance from that instance's own world box.

### GREEN

```
$ cd packages/jet_cad_2d && CI=true dart test test/index/band_query_test.dart
00:00 +0: window keeps only the enclosed line; crossing adds the straddler
00:00 +1: an instance is selected where its leaf lands after the transform
00:00 +2: an L-shaped block is not crossed by a band in the empty quadrant of its box
00:00 +3: the window band sees a leaf edited since the last rebuild
00:00 +4: a grouped leaf inside a definition uses the group transform too
00:00 +5: a window refuses an instance whose far leaf lies outside the band
00:00 +6: an instance with no selectable member leaf is never window-selected
00:00 +7: a circle is crossed outside its indexed box under a non-uniform group scale
00:00 +8: a fill slot is never reported
00:00 +9: results are ascending by handle even when the tree order differs
00:00 +10: instances come back ascending even when the tree order differs
00:00 +11: a nested query inside the band visitor throws
00:00 +12: a locked layer is skipped under picking, kept under all
00:00 +13: crossing and window agree with the brute-force arm on the generated corpus
00:00 +14: All tests passed!
```

## Package gate line

```
$ cd packages/jet_cad_2d && CI=true dart test
00:03 +819: All tests passed!
dart test EXIT=0

$ dart analyze
Analyzing jet_cad_2d...
No issues found!
dart analyze EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 116 files (0 changed) in 0.25 seconds.
dart format EXIT=0
```

819 tests, up from 805 before this task.

### `query_allocation_test.dart`

Unedited (`git status --short` lists only `spatial_index.dart` modified and the
new test file untracked), and green on its own:

```
$ CI=true dart test test/invariants/query_allocation_test.dart
00:02 +5: (tearDownAll)
00:02 +5: All tests passed!
alloc EXIT=0
```

### `jet_cad_2d_flutter`

`flutter test` exits 1 with five failures, all in
`test/golden/text_ladder_golden_test.dart` (`text ladder rung 1..5`,
`RenderBackend.canvas`). **Pre-existing and unrelated**: I reverted
`spatial_index.dart` to HEAD (0ca5ca0) and re-ran that file alone — the same
five fail. This task adds no code the Flutter package calls. `flutter pub get`
did **not** rewrite any `analysis_options.yaml` in this run; `git status
--short` is clean apart from the two files below.

## Differential (test 14)

- Corpus: `generateDocument(400, definitionCount: 8, instanceCount: 40,
  nestingDepth: 2, mirroredFraction: 0.2, nonUniformFraction: 0.3,
  groupCount: 6)`.
- Trials: **12 random bands** (uniform in `doc.extents`, half-sizes 5–205) plus
  **one band per root instance** sized at 0.35/0.9/1.05/1.6 of that instance's
  own world box, cycling — 52 bands in total on this corpus, each run in
  **both** `BandMode.window` and `BandMode.crossing` (104 comparisons).
- Each comparison asserts set equality for leaves, set equality for instances,
  ascending handle order, and no duplicate slot.
- Three non-vacuity counters guard the corpus: some leaves were selected, some
  instances were selected, and some window trials selected *no* instance.
- Per Ruling 02-6 the brute-force arm uses `Transform2`s, `GeometryPayload`
  boxes via `entityBounds`, `Aabb2.transformedBy`, and the **same** predicates
  (`boxEnclosedByBand`, `leafTouchedByBandT`, `textBoxOf`). It re-derives the
  container walk — groups flattened, instances kept, a leaf owned by an
  instance node counted as a leaf of the *enclosing* container (the ATTRIB
  rule) — so what it checks independently is the broad phase, the descent and
  the dedupe, not a second geometry implementation.
- One thing the brute force had to mirror rather than improve on: the window
  box is `entityBounds(...).transformedBy(containerSpaceTransform)
  .transformedBy(toWorld)`, two AABB steps, because that is what
  `ContainerIndex.build` stores and `_leafPasses` lifts. Folding the two
  transforms into one product bounds a rotated box more tightly than the index
  can and would disagree on leaves straddling the band's edge — mutation M2
  below is exactly that, and it is caught.

## Mutation testing

Fifteen named mutations, applied one at a time to the finished
`spatial_index.dart` and run against `band_query_test.dart` alone.

| # | mutation | result |
|---|---|---|
| M1 | window `_bandDescend` uses the band's local box instead of `_kAllBox` | KILLED (far-leaf window test) |
| M2 | window does not lift the container-space box into world space | KILLED (far-leaf, empty-container, differential) |
| M3 | nested instance transform composed in reverse | KILLED (differential) |
| M4 | leaf crossing broad phase drops the pick margin | KILLED (non-conformal circle) |
| M5 | fill slots are reported by `forEachLeafInBand` | KILLED (fill test) |
| M6 | window instance passes when ANY member leaf is enclosed | KILLED (far-leaf, differential) |
| M7 | the window box skips the dirty-overlay fallback | KILLED (edited-leaf test) |
| M8 | the leaf group transform is dropped from the crossing narrow phase | KILLED (three tests) |
| M9 | leaf results are not sorted by handle | KILLED (three tests) |
| M10 | the filter is ignored by the root leaf walk | KILLED (locked-layer test) |
| M11 | window instance query uses the widened band instead of `_kAllBox` | SURVIVED — **equivalent mutant** |
| M12 | an empty container counts as a window pass | KILLED (empty-container test) |
| M13 | instance results are not sorted | KILLED (instance ordering test) |
| M14 | the duplicate-slot guard is removed | SURVIVED — defensive, see below |
| M15 | the cycle guard in `_bandDescend` is removed | SURVIVED — defensive, see below |

**12 of 15 killed, 3 survived** (superseded by the sixteen-mutation run in
Fix round 1 below, which is the table of record). The three survivors,
analysed rather than papered over:

- **M11 is an equivalent mutant.** An instance can only pass window if at least
  one member leaf's world box is enclosed by the band; the instance's indexed
  box is `definitionBounds(def).transformedBy(composed)`, which contains every
  member leaf's world box (`Aabb2.transformedBy` is monotone), so it necessarily
  overlaps the band and is found by the narrower query too. `_kAllBox` is kept
  because it puts both walks on one rule, which is what the brief asks for and
  what makes `_bandDescend`'s doc comment true at the root as well.
- **M14 and M15 guard states today's write paths cannot produce.** A duplicate
  slot needs a leaf live in both the packed tree and the dirty overlay, but
  `PackedRTree.search` skips dead items (`packed_rtree.dart:219`) and
  `_reconcileEntity` pairs every `dirty.put` with `markLeafDead`
  (`spatial_index.dart:2573`). A container cycle needs a definition cycle,
  which `AddNodeCommand` refuses on write. `_descend`'s own identical cycle
  guard is untested for the same reason. Both are cheap and both turn a future
  malformed graph into "this branch reports nothing" rather than a hang or a
  double visit.

## Files changed

- `packages/jet_cad_2d/lib/src/index/spatial_index.dart` (modified, +~300)
- `packages/jet_cad_2d/test/index/band_query_test.dart` (new)

Nothing else. No `analysis_options.yaml` touched.

## Self-review

- **Reentrancy.** Both walks take `_beginQuery()` and release it in a
  `finally`, with the guard body inlined rather than passed to a closure-taking
  helper, per `_beginQuery`'s doc comment. `_bandDescend` does *not* take the
  guard — it runs inside one. The test asserts both the throw and that the flag
  is lowered again afterwards.
- **Scratch discipline.** `forEachInstanceInBand` uses `_scratchForDepth(0)`
  and `_bandDescend` starts at depth 1, so no level's buffer is aliased. Each
  level's buffer is fully consumed by its own loop before any deeper call
  touches its own.
- **Allocation.** These allocate O(results) plus one `Aabb2` per widened band
  and one `Transform2` per instance actually descended into. That is stated in
  the doc comments and is inside the constraint (pointer-up rate, not frame
  rate). `query_allocation_test.dart` does not call them and still passes
  unedited.
- **Tolerance.** No tolerance comparison introduced anywhere; every decision is
  an exact `<=`/`>=` on doubles, in world space.
- **Pure Dart.** No `dart:ui`; the only new import is Task 1's predicates.
- **Draw order.** `sortByHandle` for leaves, `sortByValue` for instance handles
  — the same two calls the rect queries use.
- The `analysis_options.yaml` rule was checked before committing;
  `git status --short` shows only the two files above.

## Concerns

1. **Window mode's cost is O(container), by design.** `forEachInstanceInBand`
   in window mode searches every root instance over `_kAllBox` and then walks
   every leaf of each definition it reaches. That is the brief's rule and it is
   correct, but on a drawing with thousands of root instances a single window
   drag walks the whole document once. It is not on the frame path, and the
   spec's own exit gate measures interaction latency rather than this, so I did
   not add a pruning fast path (an instance whose *box* is already disjoint
   from the band cannot pass window, which would be a sound early `fail`) —
   that is a change to the shape of the rule and belongs to whoever owns the
   D8 performance budget, not to this task.
2. **The five `jet_cad_2d_flutter` golden failures are pre-existing** (verified
   against HEAD) but they mean that package's gate line is not green on this
   machine, independently of this task. Worth its own look.
3. **The brief's M-02s band was arithmetically impossible** (departure 2). If
   the plan author intended a different edit rather than a different band, the
   test should be adjusted to match their intent — the behaviour under test
   (window reads the dirty overlay) is the same either way.

## Commit

`fff06e4  feat(index): window and crossing band walks, descending into instances`

**Trailer departure.** The brief asked for
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. This session's
harness supplies its own attribution line, stating that it replaces earlier
attribution guidance, so the commit carries
`Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` instead.
Flagged rather than silently changed; say the word and I will amend it back.

---

# Fix round 1

Three Important findings from the Task 2 review, all addressed. Built on
`29f2376`; no history rewritten.

## Finding 1 — the mutation table did not reconcile with its own totals

**Correct.** The original section claimed "Sixteen named mutations" and "13 of
16 killed" over a table of fifteen rows showing twelve killed and three
survived. Neither number was right: the run behind that table was **15
mutations, 12 killed, 3 survived**. The "16" and the "13" were a stale count
carried over from an earlier pass, not a missing sixteenth row — nothing was
run and left unlogged.

Two things were done. The original section's prose is corrected in place to
"Fifteen named mutations … 12 of 15 killed, 3 survived", and marked as
superseded. And the whole suite was re-run from scratch against the fixed
implementation, now with a sixteenth mutation covering finding 2, with the
script printing its own totals so the table and the prose cannot drift apart
again.

Two anchoring defects were found and fixed while doing this, which is the
other reason the earlier numbers could not be trusted:

- `M9` and `M13` had anchors that also match `forEachInRect` /
  `forEachInstanceInRect` earlier in the file, and `str.replace(old, new, 1)`
  hit the *rect* query instead of the band walk. Both are now anchored on text
  unique to the band methods. `M13` was reported SURVIVED in an intermediate
  run purely because of this; correctly anchored, it is killed.
- `M6`'s anchor went stale when a `curly_braces_in_flow_control_structures`
  fix wrapped the statement it matched.

### Mutation table of record

Sixteen mutations, one at a time, each restored from a `cp` backup (never
`git checkout --`), each run as
`CI=true dart test test/index/band_query_test.dart`:

```
M1  window descends with the band's local box instead of the all box
    KILLED by a window refuses an instance whose far leaf lies outside the band
M2  window does not lift the container-space box into world space
    KILLED by a collapsed instance is judged by its image, not refused; a window refuses an instance whose far leaf lies outside the band; an instance with no selectable member leaf is never window-selected
M3  nested instance transform composed in reverse
    KILLED by crossing and window agree with the brute-force arm on the generated corpus
M4  leaf crossing broad phase drops the pick margin
    KILLED by a circle is crossed outside its indexed box under a non-uniform group scale
M5  fill slots are reported by forEachLeafInBand
    KILLED by a fill slot is never reported
M6  window instance passes when ANY member leaf is enclosed
    KILLED by a window refuses an instance whose far leaf lies outside the band; crossing and window agree with the brute-force arm on the generated corpus
M7  the window box skips the dirty-overlay fallback
    KILLED by the window band sees a leaf edited since the last rebuild
M8  the leaf group transform is dropped from the crossing narrow phase
    KILLED by a circle is crossed outside its indexed box under a non-uniform group scale; a fill slot is never reported; a grouped leaf inside a definition uses the group transform too
M9  leaf results are not sorted by handle
    KILLED by a circle is crossed outside its indexed box under a non-uniform group scale; a fill slot is never reported; a locked layer is skipped under picking, kept under all
M10 the filter is ignored by the root leaf walk
    KILLED by a locked layer is skipped under picking, kept under all
M11 window instance query uses the widened band instead of the all box
    SURVIVED
M12 an empty container counts as a window pass
    KILLED by an instance with no selectable member leaf is never window-selected
M13 instance results are not sorted
    KILLED by instances come back ascending even when the tree order differs
M14 the duplicate slot guard is removed
    SURVIVED
M15 the cycle guard in _bandDescend is removed
    SURVIVED
M16 a singular container transform is refused instead of judged forward
    KILLED by a collapsed instance is judged by its image, not refused

TOTAL 16  KILLED 13  SURVIVED 3  OTHER 0
```

13 + 3 = 16. The three survivors are the same three analysed in the original
section (M11 equivalent; M14 and M15 guarding states today's write paths
cannot produce) — unchanged by this round.

## Finding 2 — a singular instance transform must not be refused

**Correct, and the controller's ruling is implemented as stated.**
`_bandDescend` no longer inverts `toWorld` before the mode branch. Window takes
`_kAllBox` and never inverts at all — its box lift in `_leafPasses` is
forward-only, `local.transformedBy(toWorld)`. Crossing inverts only to pull the
band back as a broad phase, and on `SingularTransformError` falls back to
`_kAllBox` for that container, so its leaves are then judged by the same
forward `leafTouchedByBand` the brute-force arm uses. The decision is commented
at the guard, including why band selection parts company with `_descend` here.

`AddNodeCommand` **accepts** a singular transform: `commands.dart:340` checks
only for a duplicate handle before delegating to `tree.addNode`, whose own
guard is the definition-cycle check. Nothing rejects a singular `Transform2` on
a node, so the case is reachable through the ordinary public path and the test
builds it that way.

New test, `'a collapsed instance is judged by its image, not refused'`: an
instance at `translation(300, -200) * rotation(pi/6) * scale(0, 1)` over a
definition holding the line `[60,80 -> 70,80]`. The body collapses to the
single world point `(260, -130.718)`; the test asserts the collapse itself
first, so it cannot pass on a fixture that is not actually degenerate. Then a
window band around that point selects the instance, a crossing band selects it,
a band 50 units away selects nothing, a root-level straddler keeps the two
modes apart — and the brute-force arm, which has no singular guard at all, is
asserted to agree in **both** modes on both leaves and instances.

That test is mutation `M16` above, and it is the only thing that kills it: the
previous `return _BandVerdict.empty` guard, re-applied verbatim, fails exactly
this test and nothing else.

## Finding 3 — degenerate fixtures in six tests

All six rebuilt against `constraints.md`: geometry off the origin, a
non-identity container, and a straddling entity so `window` and `crossing`
assert *different* sets. Bands are now derived from the fixtures' real world
boxes through a new `worldBoxOf` helper
(`entityBounds(...).transformedBy(...)`, the same composition
`ContainerIndex.build` performs) rather than hand-written axis-aligned
literals, which is what makes an exact expectation under a rotated placement
possible at all.

| test | before | after |
|---|---|---|
| `results are ascending by handle...` | three lines at `y = 0` from `x = 0`, identity, band encloses all three | four lines at `y = 500` in a group at `placement`; `d` (highest handle, `x` 105 to 400) straddles. window `[a,b,c]`, crossing `[a,b,c,d]` |
| `instances come back ascending...` | `Transform2.translation(x, 0)`, band encloses all three | every instance at `placement * translation(x, 0)`; a fourth instance `d` of a second definition whose single leaf runs 60 to 400 straddles. window `[a,b,c]`, crossing `[a,b,c,d]` |
| `a locked layer is skipped...` | two lines at the origin, identity, nothing straddling | three lines in a group at `placement` at local `y` 80/90/85; the third runs to `x = 400`. window/all `[open,shut]`, window/picking `[open]`, crossing/all `[open,shut,straddler]`, crossing/picking `[open,straddler]` |
| `a nested query inside the band visitor throws` | one line at the origin, identity | two lines in a group at `placement`, one straddling; plus new assertions that the visitor is actually *reached* (crossing sees 2, window 1) — a guard that never fires proves nothing |
| `a fill slot is never reported` | region at the origin, identity, both bands enclose everything | region at local `(40, 60)` in a group at `placement`, plus a line from inside the square out to `x = 300`. window `[boundary]`, crossing `[boundary, straddler]`, and the fill is absent from both |
| `a circle is crossed outside its indexed box...` | group `scale(2, 5)`, circle at `(0, 0)` | group `translation(700, -400) * scale(2, 5)`, circle at `(17, 9)`, plus a straddling line at local `y = 17`. window `[circle]`, crossing `[circle, straddler]` |

One deliberate non-change, stated because it looks like the same defect: the
circle fixture's group carries a translation and a **non-uniform scale** but no
rotation. `constraints.md` allows exactly that for a group ("a translation plus
rotation *or* non-uniform scale"), and a rotation would destroy the property
under test — `Aabb2.transformedBy` is conservative, so a rotated ellipse box
swells past the approximated radius `2*sqrt(10)` and the gap between the
indexed box and the narrow phase, which is the whole point of the test, closes.
The reason is written into the fixture's comment. The circle's centre is off
the origin and the group is off the identity, so the degeneracy the constraint
targets is gone.

The test count went from 14 to 15 (the new collapsed-instance test); every
rebuilt test keeps the property it guarded, and M4/M5/M9/M10/M13 above confirm
each rebuilt fixture still kills the mutation it was there for.

## Commands and output

```
$ cd packages/jet_cad_2d && CI=true dart test test/index/band_query_test.dart
00:00 +0: loading test/index/band_query_test.dart
00:00 +0: window keeps only the enclosed line; crossing adds the straddler
00:00 +1: an instance is selected where its leaf lands after the transform
00:00 +2: an L-shaped block is not crossed by a band in the empty quadrant of its box
00:00 +3: the window band sees a leaf edited since the last rebuild
00:00 +4: a grouped leaf inside a definition uses the group transform too
00:00 +5: a window refuses an instance whose far leaf lies outside the band
00:00 +6: an instance with no selectable member leaf is never window-selected
00:00 +7: a circle is crossed outside its indexed box under a non-uniform group scale
00:00 +8: a collapsed instance is judged by its image, not refused
00:00 +9: a fill slot is never reported
00:00 +10: results are ascending by handle even when the tree order differs
00:00 +11: instances come back ascending even when the tree order differs
00:00 +12: a nested query inside the band visitor throws
00:00 +13: a locked layer is skipped under picking, kept under all
00:00 +14: crossing and window agree with the brute-force arm on the generated corpus
00:00 +15: All tests passed!
covering EXIT=0
```

Package gate line:

```
$ cd packages/jet_cad_2d && CI=true dart test
00:03 +820: All tests passed!
dart test EXIT=0

$ dart analyze
Analyzing jet_cad_2d...
No issues found!
dart analyze EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 116 files (0 changed) in 0.23 seconds.
dart format EXIT=0
```

`query_allocation_test.dart`, still unedited:

```
$ CI=true dart test test/invariants/query_allocation_test.dart
00:02 +5: All tests passed!
```

The working tree before committing held only the two files of this task; no
`analysis_options.yaml` was rewritten.

## Files changed in this round

- `packages/jet_cad_2d/lib/src/index/spatial_index.dart` (+30/-10) —
  `_bandDescend`'s singular-transform handling and the comment explaining it.
- `packages/jet_cad_2d/test/index/band_query_test.dart` (+251/-62) — six
  fixtures rebuilt, one test added, three helpers added (`addGroup`,
  `worldBoxOf`, `unionOf`), `squareLoop` replaced by `squareLoopAt`.
- `.superpowers/sdd/2026-09-21-interaction-core/task-2-report.md` — this
  section, and the corrected counts in the original mutation section.
