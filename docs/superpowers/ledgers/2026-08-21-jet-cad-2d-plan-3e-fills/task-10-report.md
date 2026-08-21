# Task 10 report: the index stays silent about fills

Branch: `main`, on top of `bd78f9b` (Tasks 1-9).

## What I found before changing anything

`spatial_index.dart`'s two `case EntityKind.fill:` branches (in `_considerLeaf`
and `_considerSnapLeaf`) and `reference_query.dart`'s two matching branches
(in `_hitAtOf` and `_snapCandidates`) already existed, committed at `0ee9797`
("feat: EntityKind.fill, stored and inert") — earlier in this plan than the
brief implied. The `spatial_index.dart` two already carried "Unreachable:
... this case exists only so the switch stays exhaustive" reasoning;
`reference_query.dart`'s two only said "A fill produces no hit and no snap
candidate," with no reasoning. `container_index.dart`'s `snapCentreOfLeaf`
and `NarrowPhaseSlack.ofLeaf` guards (`kind != circle && kind != arc`) also
already existed but predate `EntityKind.fill` entirely (from `95dc956` and
`541319b`, both July 28) and never mention it. So the *behaviour* was already
correct; the *reasoning at the four sites plus the two guards* was what
Task 10 still owed.

## What I changed

**Comments only, plus tests — no behavioural code changed.**

- `lib/src/index/spatial_index.dart`: both `case EntityKind.fill:` branches
  extended with the tie-break/priority reasoning (fill's handle is strictly
  lower than its boundary's by construction; the boundary already answers
  `HitKind.fill`; the fill's boundary already contributes every snap vertex).
- `test/invariants/reference_query.dart`: both `case EntityKind.fill:`
  branches given the same reasoning, and correctly identified as unreachable
  for the same `count == 0` early-return the real index uses.
- `lib/src/index/container_index.dart`: added the two comment blocks the
  brief specifies, above `snapCentreOfLeaf` and inside
  `NarrowPhaseSlack.ofLeaf`'s guard, explaining why a fill answers null/none
  through the existing negative guards and why that's exact, not
  approximate.
- `test/index/pick_test.dart`: added `import '../document/region_command_test.dart'
  show region;` (matching the precedent `extents_test.dart` already set in
  Task 9) and the "clicking inside a filled room selects the boundary, not
  the fill" test.
- `test/index/snap_test.dart`: same import, plus two tests — the brief's
  corner-of-the-room check, and a second one I added (see below).
- `test/invariants/corpus.dart`: new `_regionFill()` fixture (a root-level
  filled room plus a second room defined once and placed through a rotated,
  non-uniformly-scaled instance, plus one ordinary line), added to
  `buildCorpus()` between `_textLaidOut()` and `_nearMissIntersection()`.

## Deliberately not changed

- **No `case EntityKind.fill:` was added anywhere that produces a hit or a
  candidate.** That is the requirement this task exists to *not* implement.
- **`_considerSnapCentre` in `spatial_index.dart` was left alone.** While
  investigating T10b (below) I found it carries its own independent
  `kind != circle && kind != arc` guard, redundant with `snapCentreOfLeaf`'s.
  Its own doc comment already explains why ("a slot whose entity has since
  changed kind keeps its tree entry until the next rebuild... this is one
  line against a candidate computed from the wrong two scalars"). It's a
  third, un-asked-for line of defense against a fill ever producing a
  `SnapKind.center` candidate; I left it as-is since the brief scoped this
  task to the two `container_index.dart` guards specifically, and it's
  already correct.

## The strengthened snap test, and why the brief's version alone isn't enough

The brief's own test queries `Vector2(0, 0)` — the room's corner, where the
boundary's real `SnapKind.endpoint` candidate sits at the *same point* a
corrupted fill centre would land on if `snapCentreOfLeaf`'s guard leaked. I
verified by mutation (T10b below) that at that point, `SnapKind.endpoint`
(index 0) always outranks `SnapKind.center` (index 2) by kind priority
regardless of distance — the exact "masked by a closer, higher-priority
candidate" hazard `corpus.dart`'s own `_nearMissIntersection` fixture
documents. A `snapCentreOfLeaf` mutation that plants a spurious centre
exactly there is invisible to that test. I kept the brief's test (it's a
correct, worthwhile pin on its own) and added a second one querying the
room's interior (`Vector2(5, 5)`, radius `0.5`) — five units from every real
edge or vertex, so nothing can mask a fabricated candidate there. That
second test is the one that actually kills T10b.

## Verbatim suite output

### `packages/jet_cad_2d`

```
$ CI=true dart test test/index/pick_test.dart test/index/snap_test.dart
...
00:00 +63: test/index/pick_test.dart: clicking inside a filled room selects the boundary, not the fill
00:00 +64: All tests passed!
```

```
$ CI=true dart test test/invariants/differential_test.dart
...
00:00 +68: regionFill entitiesInRect matches brute force over 200 random rects
00:00 +69: regionFill instancesInRect matches brute force over 200 random rects
00:00 +70: regionFill pick matches brute force over 200 random points
00:00 +71: regionFill snap matches brute force over 200 random points
00:00 +72: nearMissIntersection entitiesInRect matches brute force over 200 random rects
00:00 +73: nearMissIntersection instancesInRect matches brute force over 200 random rects
00:00 +74: nearMissIntersection pick matches brute force over 200 random points
00:00 +75: nearMissIntersection snap matches brute force over 200 random points
00:00 +76: All tests passed!
```

```
$ CI=true dart test
...
00:02 +770: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +771: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +771: All tests passed!
```

(771 total; was 770 before this task — the one new interior-point snap test.
No other test's count moved: only `_regionFill()` was added to the corpus,
inserted via `for (final fixture in buildCorpus())` in `differential_test
.dart`, the only place `buildCorpus()` is called.)

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.19s
```

### `packages/jet_cad_2d_flutter`

```
$ CI=true flutter test
...
00:03 +240 ~1: .../draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +241 ~1: .../draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:03 +242 ~1: All tests passed!
```

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 45 files (0 changed) in 0.08s
```

## Allocation gate

```
$ CI=true dart test test/invariants/query_allocation_test.dart
00:00 +0: forEachInRect does not allocate in steady state
00:00 +1: forEachInstanceInRect does not allocate in steady state
00:01 +2: pickInto does not allocate in steady state, three instances deep
00:01 +3: snapInto does not allocate in steady state, three instances deep
00:02 +4: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +5: (tearDownAll)
00:02 +5: All tests passed!
```
All five pass. Nothing in this task touches an allocating path — comments
only, plus a fixture the pick/snap allocation tests don't exercise (they use
their own fixtures).

## Mutation transcripts

Each mutation was applied via `cp` backup + `perl -0pi` patch, run, then
restored from the backup — inside one shell call each — never `git
checkout`.

### T10a — give the oracle a fill hit the real index does not produce

Patched `reference_query.dart`'s `_hitAtOf` to short-circuit *before* the
`count == 0` guard: `if (record.kind == EntityKind.fill) return (kind:
HitKind.fill, point: world);`

```
00:00 +70: regionFill pick matches brute force over 200 random points
00:00 +70 -1: regionFill pick matches brute force over 200 random points [E]
  Expected: <true>
    Actual: <false>
  regionFill trial 0 at [28.23769415478484,31.65819127652852] r=0.01

  package:matcher                                expect
  test/invariants/differential_test.dart 157:13  main.<fn>.<fn>

00:00 +70 -1: regionFill snap matches brute force over 200 random points
...
00:00 +75 -1: Some tests failed.

Failing tests:
  test/invariants/differential_test.dart: regionFill pick matches brute force over 200 random points
```

**Kill.** Restored; `git diff --stat` afterward showed only my legitimate
task-10 changes to that file (22 insertions, 2 deletions — the enriched
comments), confirming the mutation left no trace.

### T10b — make `snapCentreOfLeaf` answer for a fill

First attempt (mutating only `snapCentreOfLeaf` to return `(composed.e + 5,
composed.f + 5)` for a fill) did **not** go red on either snap test — because
`_considerSnapCentre` in `spatial_index.dart` carries its own independent
`kind != circle && kind != arc` guard and rejects the fill's tree entry
again at query time, exactly as its doc comment says it exists to do. A
single-function mutation of `snapCentreOfLeaf` alone is masked by that
second guard; it is not a test gap, it is a genuinely redundant safety net.

To exercise the scenario the brief names, I mutated both guards together —
`snapCentreOfLeaf` (plant a fabricated centre at the room's interior) and
`_considerSnapCentre` (stop re-filtering it out, report the same point):

```
00:00 +22: a fill never wins a snap, so boundary vertices are not doubled
00:00 +23: a fill manufactures no snap candidate of its own, even away from every real vertex
00:00 +23 -1: a fill manufactures no snap candidate of its own, even away from every real vertex [E]
  Expected: false
    Actual: <true>
  no real snap feature is within reach of the room interior; a hit here can only mean the fill supplied one it should not have

  package:matcher                  expect
  test/index/snap_test.dart 613:5  main.<fn>

00:00 +23 -1: Some tests failed.

Failing tests:
  test/index/snap_test.dart: a fill manufactures no snap candidate of its own, even away from every real vertex
```

**Kill** — by the corner-check test (the brief's own version) alone: **no**,
that one stayed green through this same combined mutation, confirmed by
running it standalone first (masked by the endpoint tie-break, as explained
above). The interior-point test is what actually catches it. Restored both
files; `git diff --stat` afterward matched the legitimate task-10 diff
exactly (19 / 18 insertions, both files), confirming a clean restore.

## Corpus addition — did it move any other test?

`_regionFill()` was the only new corpus fixture, added to `buildCorpus()`'s
list. Searched the whole test tree for other callers of `buildCorpus()`:
only `differential_test.dart` calls it, via `for (final fixture in
buildCorpus())`, so no other test enumerates or counts corpus rows. Ran the
whole `jet_cad_2d` suite before and after (770 → 771; the +1 is the new
interior-point snap test, unrelated to the corpus) — no other test's
assertion count or content moved.

## Uncertain / worth flagging

- **The third guard.** `_considerSnapCentre`'s redundant kind check means
  the brief's literal T10b framing ("make `snapCentreOfLeaf` answer for a
  fill") is, on its own, an equivalent mutation — it changes no observable
  behaviour by itself. I did not add a standing test that kills a
  `snapCentreOfLeaf`-only mutation, because none exists to write (the
  redundant guard genuinely absorbs it). I documented this in the
  `NarrowPhaseSlack`/`snapCentreOfLeaf` comment blocks I added, but did not
  add a comment at `_considerSnapCentre` itself since the brief scoped this
  task to `container_index.dart`'s two guards specifically, and that
  function's own comment already explains its own redundancy. Flagging in
  case a reviewer wants that third guard's fill-specific reasoning written
  down too, or wants a mutation test targeting it directly (which would
  require mutating `_considerSnapCentre` alone, not `snapCentreOfLeaf`).
- **`_regionFill()`'s second room** (through a rotated, non-uniformly-scaled
  instance) is not required by the brief's letter — it asks only that a
  region be added to close the deferred survivor. I added it to avoid a
  fixture that only exercises the fill leaf at the identity transform,
  per this repo's own stated bar against degenerate fixtures. If a reviewer
  considers that scope creep on a "no behavioural change" task, it's cheap
  to trim back to a single root-level room.
