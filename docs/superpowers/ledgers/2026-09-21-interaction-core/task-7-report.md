# Task 7 — `selection_style.dart` and `OutlineCache`

**Commit:** `87bed32` — `feat(overlay): the rebased outline cache and the
selection style constants`, on `plan-02/interaction-core` (head was `24e09d8`).

## What was implemented

### `lib/src/selection_style.dart` (modified)

The four remaining constants joined the three already there:
`kSelectionColor = Color(0xFF1E6FE8)`, `kHoverColor = Color(0x991E6FE8)`,
`kSelectionStrokePixels = 2.0`, `kHoverStrokePixels = 1.5`. The band trio
(`kWindowBandColor`, `kCrossingBandColor`, `kBandFillAlpha`) is unchanged in
value; only the doc comment was reworded now that the file is no longer
band-only.

### `lib/src/outline_cache.dart` (new)

`OutlineCache(document, selection)` — the review note's **B2** ruling and
spec **D9**, implemented as two layers that never mix:

- **World record**, `Map<SelectionKey, List<_Outline>>`, all `Float64`.
  `_Outline` is a sealed pair: `_Segments(Float64List coords)` (a polyline
  chain, `moveTo` the first pair and `lineTo` the rest) and
  `_Arc(cx, cy, r, start, sweep)` (a circle is `sweep = 2π`).
- **Rebased paths**, `Map<SelectionKey, Path>`, built with the tag origin
  subtracted from every coordinate. **No absolute world coordinate is ever
  handed to `dart:ui`.**

`pathFor(key, origin)` rebuilds *every* path — from the cached
`Float64List`s, with no document access — when `origin` differs from the tag
or when the record was invalidated, retags, and returns `_paths[key]` (null
for a key that is neither selected nor hovered). `origin` exposes the tag;
`@visibleForTesting int debugRebuilds` counts whole rebuilds;
`@visibleForTesting Float64List? debugWorldSegmentsOf(key)` returns every
`_Segments` of a key concatenated in order, or null when the key is absent.

**Walk rules.** `SelectionKey.target` is told apart with
`document.tree[target]`:

- an `InstanceNode` → `accumulatedTransform(target)` (the world placement),
  then the definition's own leaves and, recursively, child groups
  (`toWorld ∘ group.transform`) and nested instances
  (`toWorld ∘ instance.transform`);
- a `GroupNode` → `accumulatedTransform(target)`, then the same container
  walk (owned leaves, nested groups, child instances);
- otherwise a leaf → `Transform2.identity()` when the owner is the root,
  `accumulatedTransform(owner)` otherwise.

`document.leavesByOwner()` is a full entity-store scan, so one is shared
across a whole batch of keys and **explicitly discarded at batch boundaries**
(`_walk` nulls `_byOwner` on both sides) — the document may have changed
since the previous batch. A definition already open on the walk is not
re-entered, so an imported self-reaching definition yields a truncated
outline instead of a stack overflow.

**Per kind.** point/line/polyline → the transformed coordinate array;
circle → transformed centre with `radius × t.scaleMagnitude` and
`start = 0, sweep = 2π`; arc → the same radius rule, the world start angle
taken from the **transformed start point** and the sweep sign flipped when
`t.determinant < 0` (the rule `spatial_index` uses for picks and
`band_predicates` for bands); text/attrib → `textBoxOf(...)` and the four
corners through `t ∘ box.local`, closed back on the first; fill → skipped
(D8: a fill has no coordinates and is never picked).

**Lifecycle.** The cache listens to `SelectionController` (keys in and out,
hover included) and to `document.changes`. Per D9, **every** `DocChange`
rebuilds **every** cached record — a leaf edited inside a selected instance's
definition touches neither the instance nor the group handle, so an
exact-handle rule never fires for it. `DocumentLoaded`/`DocumentPurged` clear
everything. `dispose()` cancels the subscription and removes the listener.

## Departures

1. **`import 'dart:typed_data'` removed from `outline_cache.dart`.**
   `flutter analyze` reported `unnecessary_import` — `package:flutter/
   foundation.dart` already re-exports `Float64List`. Local, obvious, applied.
2. **The brief's outline list is followed, but the walk also descends into
   *instances nested inside a selected group*.** The brief spells out "every
   owned leaf recursively" for a group and says nothing about a child
   instance; D9 says "a group as the union of its members" and Task 6's
   delete cascade removes child instances, so leaving them un-outlined would
   have made the overlay disagree with what Delete removes. One shared
   container walk covers group and definition alike.
3. **A `point` entity is recorded as a one-point `_Segments`.** It gives the
   right world record and the right path bounds, but a path of a single
   `moveTo` draws nothing, so a selected `point` currently has no visible
   outline. A screen-sized marker cannot live in a world-space cache; this is
   flagged for Task 8's painter rather than guessed at here. See *Concerns*.
4. **Test 6 asserts through `pathFor`'s bounds rather than a new debug
   accessor.** The brief lists only `debugWorldSegmentsOf`, which cannot see
   an `_Arc`. `getBounds()` of the rebased circle path gives both the world
   radius (`width == 2r`) and the rebased centre, which is what the test
   needs, without widening the interface.

## TDD evidence

### RED — the seven tests before any implementation existed

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart
test/outline_cache_test.dart:10:8: Error: Error when reading 'lib/src/outline_cache.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
       ^
test/outline_cache_test.dart:18:23: Error: Type 'OutlineCache' not found.
(SelectionController, OutlineCache) wire(DraftDocument doc) {
                      ^^^^^^^^^^^^
test/outline_cache_test.dart:21:17: Error: Method not found: 'OutlineCache'.
  final cache = OutlineCache(doc, selection);
                ^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

### GREEN — after `outline_cache.dart` and the constants landed

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart
00:00 +0: the path is built in rebased space
00:00 +1: the origin tag rebuilds once per change, not per call
00:00 +2: a DocChange inside a selected instance rebuilds the outline
00:00 +3: an instance outline composes the placement
00:00 +4: a grouped leaf inside a definition composes the group transform too
00:00 +5: a circle under a non-uniform instance scale is emitted with the geometric-mean radius
00:00 +6: keys dropped from the selection leave the cache
00:00 +7: All tests passed!
```

### Mutations — six fired, six killed, all seven tests covered

Each mutation was applied to `lib/src/outline_cache.dart` alone, the file
restored from a byte copy afterwards, and the suite re-run.

| # | mutation | test it killed | reading |
|---|---|---|---|
| **M-02v** | `final ox = _origin.x, oy = _origin.y;` → `final ox = 0.0, oy = 0.0;` (a world-space path) | 1 **and** 6 | `Expected: a numeric value within <0.000001> of <42.0> / Actual: <4500010.0>` |
| **M-02w** | `_onChange` returns before `_walk` | 3 | `Expected: a numeric value within <1e-9> of <281.69134295108995> / Actual: <308.69134295108995>` |
| circle radius | `payload.scalars[0] * t.scaleMagnitude` → `* t.a` | 6 | `Expected: a numeric value within <0.001> of <16.0> / Actual: <7.207751035690308>` |
| group transform | child group walked with `toWorld` instead of `toWorld.multiply(node.transform)` | 5 | `Expected: a numeric value within <1e-9> of <265.2984934275555> / Actual: <303.14711431702995>` |
| origin tag | `if (_stale \|\| origin != _origin)` → `if (true)` | 2 | `Expected: <1> / Actual: <2>` |
| key drop | `_world.removeWhere((k, _) => !live.contains(k));` deleted | 7 | `Expected: null / Actual: [140.0, 25.0, 190.0, 65.0]` |
| instance placement | `accumulatedTransform(key.target)` → `Transform2.identity()` | 3, 4, 5, 6 | `Expected: ... <303.14711431702995> / Actual: <3.0>` |

Every fixture is off the identity and off the origin: `kPlacement` is
translate ∘ rotate ∘ scale, the grouped case adds a second non-commuting
rotation, the circle sits under a rotated 2×8 scale (det 16, so the world
radius 8 is neither `2 × 2` nor `2 × 8`), and test 1 sits at
`kDefaultOriginX`.

## Gate line

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:11 +741 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
TEST_EXIT=1
```

**741 pass, 1 skip, 5 failures — exactly the five pre-existing
`text_ladder_golden_test.dart` goldens named above and nothing else** (the
`~1` skip is `test/rig/paint_microbench_test.dart`, skipped at suite level by
the `rig` tag). 734 + 7 = 741: the seven new tests are the whole delta.
`flutter test` exits 1 on those five per the standing baseline ruling
(Skia/SDK drift from 2026-08-24).

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
ANALYZE_EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 132 files (0 changed) in 0.26 seconds.
FORMAT_EXIT=0
```

`packages/jet_cad_2d` is untouched by this task (`git status --short` showed
only the three flutter-package files before the commit), so its gate line was
not re-run.

## Trailer check

```
$ git log -1 --format=%B | grep -c "Fable 5.1"
1
```

`analysis_options.yaml` was **not** committed — `git status --short`
immediately before `git add` showed exactly three paths, all under
`packages/jet_cad_2d_flutter`, and `flutter pub get` (which ran twice during
this task) left no modified `analysis_options.yaml` behind.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/selection_style.dart` — modified
- `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart` — new
- `packages/jet_cad_2d_flutter/test/outline_cache_test.dart` — new

## Self-review

- **M-02v holds by construction, not by discipline.** `_rebuildPaths` is the
  only method that touches `Path`, and it is the only place `_origin` is
  read; there is no code path from a `Float64List` to `dart:ui` that skips
  the subtraction. Confirmed by the mutation: zeroing the origin moves the
  bound to `4500010.0`.
- **Allocation.** `pathFor` at the steady state is a map lookup and two
  `double` comparisons — nothing allocated. Paths are allocated at
  origin-change, selection-change, hover-change and `DocChange` rate only,
  which is D9's rule. `debugWorldSegmentsOf` allocates, and is
  `@visibleForTesting`.
- **Listener order.** `SelectionController` is constructed before the cache
  in every call site here, so on a `DocChange` the controller prunes dead
  keys and notifies first; the cache's own `_onChange` then rebuilds what is
  left. The reverse order is also safe — `_outlinesFor` on a dead handle
  returns an empty list and `_onSelection` removes the key immediately after.
- **Composition equivalence.** `accumulatedTransform(childGroup)` equals
  `accumulatedTransform(parent).multiply(child.transform)`, so the manual
  composition down the walk and the tree's own accumulation agree; test 5
  asserts against `tree.accumulatedTransform(group)` rather than a
  hand-written product, which is the stricter statement.
- **`leavesByOwner()` freshness.** The one real hazard I found while writing
  this was caching the scan in a field with `??=` and never clearing it — a
  `DocChange` would then have rebuilt every outline from a stale owner map.
  `_walk` now nulls it on both sides of the batch. M-02w exercises exactly
  that path (an `AddEntity` would be the sharper witness; see *Concerns*).

## Concerns

1. **A selected `point` draws nothing.** Its record is a single world point,
   so the path is one `moveTo`. Task 8 needs a decision: a screen-sized
   marker in the painter, or a tiny world-space cross here. It is recorded,
   not silently accepted.
2. **`_byOwner` staleness has no direct test.** `_walk` clears the scan at
   both batch boundaries, but M-02w's `SetEntityGeometryCommand` does not
   change the owner map, so the blanket-rebuild test passes with or without
   the clear. A leaf **added** to a selected instance's definition after the
   first walk would be the witness. I did not add it because the brief fixes
   the seven tests; it is a one-line candidate for Task 8 or a review pass.
3. **The text branch has no test in this task.** `textBoxOf` and the corner
   composition are exercised nowhere in `outline_cache_test.dart` — the seven
   tests the brief names cover segments and arcs only. The code mirrors
   `band_predicates.leafTouchedByBand`'s text arm line for line, but "mirrors"
   is reading, not measuring. Worth a fixture when the overlay lands.
4. **Arc sweep direction under `addArc` is asserted only indirectly.** Test 6
   uses a full circle, where the sweep sign cannot be wrong. A mirrored arc
   (negative determinant) has no witness here; the sign rule is copied from
   the pick's, which does have one.

---

# Fix round 1

All four review items addressed. **The seven original tests are unchanged**
(byte-identical; `git diff 87bed32 -- test/outline_cache_test.dart` touches
only the additions below).

## What changed

### 1. Important — `Vector2? worldPointOf(SelectionKey key)` (public)

A `point` entity is now recorded as its own `_Outline` variant, `_Point(x, y)`,
rather than a one-pair `_Segments`. That was the honest fix: a one-pair
`_Segments` builds a path of a lone `moveTo`, which draws nothing and cannot
be told apart from a vanished target, and it also polluted
`debugWorldSegmentsOf`. `_rebuildPaths` skips `_Point` (nothing to stroke).

`worldPointOf` returns the world position when a key's **whole** record is a
single `_Point`, and null for every other key and for an unknown key. It is
public, documented as the overlay's affordance for drawing a point key as a
screen-space cross (Task 8), and its doc comment states that the value is
**absolute world** — the caller subtracts `origin` before it reaches
`dart:ui`, since a world-space cache cannot hold a pixel-sized marker.

### 2. `origin` doc comment

> **Do not mutate; a mutated tag desyncs the rebased paths.** The live field
> is handed out rather than a copy because the overlay reads it once per frame
> and a copy would allocate at frame rate.

### 3. `debugRebuilds` is now a getter

`int _debugRebuilds = 0;` plus `@visibleForTesting int get debugRebuilds =>
_debugRebuilds;`. `_rebuildPaths` increments the private field.

### 4a. Text fixture

New test, `'a rotated text is recorded as its four oriented world corners'`.
A `text` leaf inside a definition placed at `kPlacement`: string `'JET'`,
`ReservedHandles.standardTextStyle`, height 40 and **rotation 0.4 rad** in
`scalars[1]` (the engine's own convention — `pick_test.dart`'s rotated-text
test sets rotation there, not in `textAttrs`), and `textAttrs` packed with
`packTextAttrs(h: TextJustifyH.right, v: TextJustifyV.top)` so neither
justification sits at its default. The measurer is a local
`_FixedMeasurer implements TextMeasurer` returning deliberately asymmetric
fixed metrics (advance 260, ascent 78, descent 22, cap 70), so a layout that
swapped two of them would show. A local `addText` helper mirrors the engine's
(the engine's lives in its own `test/`, which cannot be imported across
packages).

The assertion is the reviewer's: the ten recorded doubles equal
`kPlacement × box.local × (box corner)` for the engine's own `textBoxOf`, to
1e-9, for the four corners plus the repeated first — and, as an anti-vacuity
check, that no two adjacent corners share an ordinate, so the quad is
genuinely oriented rather than an axis-aligned box.

### 4b. Mirrored arc fixture — **and a departure, measured**

New test, `'a mirrored arc flips its sweep and takes its start from the
transformed start point'`. An arc (`c = (5, 3)`, `r = 2`, `start = 0.9`,
`sweep = 1.7`) inside a definition placed at
`kPlacement.multiply(Transform2.scale(1, -1))`, whose determinant the test
asserts is negative before anything else.

**The reviewer's suggested assertion — `pathFor(...).getBounds()` equals
`arcBounds(...)` on the world values — does not hold, and I measured why
rather than loosening it into meaninglessness.** `ui.Path.getBounds` returns
the bounds of the **conic control points**, not of the curve. Probe output
(centre `(10, -4)`, radius 7, throwaway test, deleted):

```
start=0.0 sweep=1.5707963267948966
  path  Rect.fromLTRB(10.0, -4.0, 17.0, 3.0)
  exact (10.0, -4.0, 17.0, 3.0)
start=-1.2 sweep=2.6
  path  Rect.fromLTRB(11.2, -10.5, 19.1, 2.9)
  exact (11.189770000301685, -10.524273601770584, 17.0, 2.898148109919222)
```

A 2.6 rad sweep reads `maxX = 19.1` where the arc's own bound is `17.0` — a
control point sticking out by 0.3 r. A comparison with enough slack to absorb
that could not pin a start angle or a sweep sign, which is the whole point of
the test. (Test 6's circle is exact only because `addArc` with `sweep = 2π`
and `start % 90° == 0` appends an **oval**, whose bounds are the rect.)

So the test asserts on the **record**, through a new
`@visibleForTesting Float64List? debugWorldArcsOf(key)` (`cx, cy, r, start,
sweep` per arc — symmetric with `debugWorldSegmentsOf`, which cannot see an
arc at all): centre, radius, the world start angle taken from the
**transformed start point**, and `sweep = -1.7`, each to 1e-9, plus a check
that the world start angle is **not** the stored 0.9. The path is still tied
in, by the exact statement that is available: the rebased `getBounds()`
**contains** `arcBounds(centre - origin, radius, start, -sweep0)` within
float32 headroom (`slack = 1e-3`; float32 spacing at |x| ~ 73 is about 8e-6,
three orders below the radius 3), and is no wider than a conic hull can be
(`< 2 r √2`), so the containment is not vacuous.

## Covering tests and mutations — four fired, four killed

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart
00:00 +0: the path is built in rebased space
00:00 +1: the origin tag rebuilds once per change, not per call
00:00 +2: a DocChange inside a selected instance rebuilds the outline
00:00 +3: an instance outline composes the placement
00:00 +4: a grouped leaf inside a definition composes the group transform too
00:00 +5: a circle under a non-uniform instance scale is emitted with the geometric-mean radius
00:00 +6: keys dropped from the selection leave the cache
00:00 +7: a point key answers its world position, a line key does not
00:00 +8: a rotated text is recorded as its four oriented world corners
00:00 +9: a mirrored arc flips its sweep and takes its start from the transformed start point
00:00 +10: All tests passed!
```

| mutation | test killed | reading |
|---|---|---|
| point record skips the transform (`_Point(p.x, p.y)` → `_Point(payload.coords[0], payload.coords[1])`) | 8 | `Expected: a numeric value within <1e-9> of <322.1374953737966> / Actual: <13.0>` |
| text corners skip `box.local` (`t.multiply(box.local)` → `t`) | 9 | `Expected: a numeric value within <1e-9> of <243.3026928438183> / Actual: <316.5>` |
| arc sweep sign not flipped (`t.determinant < 0 ? -scalars[2] : scalars[2]` → `scalars[2]`) | 10 | `Expected: a numeric value within <1e-9> of <-1.7> / Actual: <1.7>` — *a negative determinant flips the sweep* |
| arc start from the stored scalar (`atan2(...)` → `scalars[1]`) | 10 | `Expected: a numeric value within <1e-9> of <-0.3764012244017041> / Actual: <0.9>` — *the world start angle comes from the transformed start point* |

Test 8's point arm is exercised twice, through both branches of the walk: the
**group** key (D2's selection of a grouped leaf) and the **leaf** key itself,
which reaches the point through `entities.ownerAt` → `accumulatedTransform`.

## Gate line

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:11 +744 ~1 -5: Some tests failed.
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
TEST_EXIT=1
```

**744 pass, 1 skip, the same five pre-existing goldens and nothing else** —
741 + 3 new tests. Exit 1 on those five per the standing baseline ruling.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)

$ dart format --output=none --set-exit-if-changed .
Formatted 132 files (0 changed) in 0.29 seconds.
FORMAT_EXIT=0
```

`flutter analyze` caught one thing on the way: `dot` was unused in the point
test because the key selected was the group. Rather than delete the variable,
the leaf-key arm above was added — the analyzer found a missing assertion,
not dead code.

## Files changed in this round

- `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`
- `packages/jet_cad_2d_flutter/test/outline_cache_test.dart`

`selection_style.dart` is untouched by this round.

## Concerns after round 1

1. Concern 1 of the original report (**a selected point draws nothing**) is
   now *handed to* Task 8 rather than closed: `worldPointOf` gives the
   painter the position, but the cross itself — its size, its colour, whether
   the hover paint applies — is Task 8's to draw and to test.
2. Concern 2 (**`_byOwner` staleness has no direct test**) still stands. The
   witness would be a leaf **added** to a selected instance's definition
   after the first walk.
3. New, small: `worldPointOf` returns null for a group holding a point *and*
   something else, which is the right answer for a cross but means a mixed
   group's point member has no marker. Recorded for Task 8; widening it would
   need a list-returning accessor and a painter that wants one.
