# P1 review: c7e4ac3, intersection snaps map grouped segments to world

Reviewer: independent. Reviewed in the detached worktree
`.claude/worktrees/fix-phantom-snap-review` at `c7e4ac3`. Every mutant and
probe ran there, and nothing was committed or pushed. Every restore was
`cp` followed by `diff` (exit 0) and `git diff --quiet` (clean). At the end
of the review, `git status` is clean in both worktrees. The probe file I
added is removed; a copy is at `scratchpad/p1r-probe_test.dart`.

## Verdict: **Needs fixes (one comment-only fix, I-1)**

The engine change is correct. I reproduced every claim the report makes
about it, and every mutant it names is killed in the gate configuration.
The one Important finding is about honesty, not code. The new allocation
test's doc comment says it catches a per-segment `Vector2`. That is true
only when the test runs after the other tests in its file. Run alone, the
same mutants pass. The comment and the report should say so. No code
change is required.

## Important findings

### I-1: the new allocation case catches a per-segment `Vector2` only in file context

`packages/jet_cad_2d/test/invariants/query_allocation_test.dart`, the
`_groupedCrossingDocument` doc comment, says: "**What it catches, measured
by mutation:** a `Vector2` per mapped segment (3.9 per call) ...". The
report says the same in its M-P9 row: "Killed ... 3.902 per call".

To reproduce, take M-P9 (in `_collectNearSegments`, replace
`_isectA1.setValues(x1, y1);` with `_isectA1.setFrom(Vector2(x1, y1));`).
I measured it with a temporary `print` of the counts; the file was backed
up and restored with `diff` exit 0.

**Full file:** `CI=true dart test test/invariants/query_allocation_test.dart`
- Red 7 times out of 7.
- `Vector2` per call: 1.166, 3.11, 0.95, 1.094, 0.95, 4.046, 1.022 (budget 0.5).

**Test alone:** `... --plain-name intersecting`
- **Green 3 times out of 3.** One of those runs was instrumented and read
  `Vector2: 0.014`, which is the unmutated baseline. The unmutated alone run
  also read 0.014.

**A more realistic escaping-looking regression** (M-P9e):
`distanceToSegment(world, Vector2(x1, y1), Vector2(x2, y2))`
- Full file: red, 3.038 per call.
- Alone: green, 0.014 per call.

So when the test runs by itself, the JIT scalar-replaces even a
per-segment `Vector2`. This is the same limit the report records for
M-P9b and M-P9c, and it supports the report's explanation for those
survivors. It also means this case's kill depends on the JIT state the
earlier tests in the file leave behind, and the kill margin is thin: the
lowest full-file readings are 0.95 against a budget of 0.5.

In the gate as written (`dart test` over the whole package), the kill does
hold: 7 runs out of 7.

Fix:
- The doc comment should state the measured range (about 0.95 to 4.0 per
  call in file order).
- It should say the test passes the same mutants when run alone.
- The report's M-P9 row should carry the same qualification.

Making the case order-independent (for example, its own warm-up that
defeats scalar replacement) is optional. It is a harness-level question,
not this fix's.

## Minor findings

### M-1: no committed test covers a line-like candidate with fewer than 2 points

The new `if (points < 2) continue;` guard sits after
`_nearSegmentStart[k] = written`. That ordering is correct.

Mutant R4 moves the offset write to after the guard, so a short candidate
leaves a stale offset. It **survives** all of these:
- the unit file;
- `differential_test.dart`;
- my Q4 probe and my noteLeaf probe.

What kills it: a one-point root polyline, drawn last, near a grouped
crossing. Under R4 the index names the one-point polyline as the
intersection's entity: `Expected: <20> Actual: <21>`, where 20 is the
later-drawn line of the crossing pair and 21 is the one-point polyline.

The code is right. The seam is untested. Consider a unit test like that
probe (it is in the scratch copy as "probe R4").

### M-2: the AM2 C6 premise is looser than it needs to be at the origin

I measured it, with the test backed up and restored:
- `origin`: exactly q (`x==true y==true`, offset 0.0).
- `corpus far origin, 23 deg, own groups`: `SnapKind.intersection`
  `[4501709.8861087095, 1200834.4396294742]` against q
  `[4501709.88610871, 1200834.439629475]`, offset **1.1641532182693481e-9**.

So the report's 1.16e-9 is right, and the comment's "1.2e-9" is the same
number rounded.

The new premise is sound:
- It is `res != null`, kind intersection, within 1e-5.
- 1e-5 is the file's own snap premise tolerance (lines 466 and 486).
- The added checks at the resolved point (`bruteCandidates` and `through`
  both empty) strengthen the clause.

It is weaker than the old premise at the origin, where exact `==` still
holds. It could keep `==` when `place == origin` and use a tolerance only
at the far placement. Spec 11 uses 1e-8 for the analogous AP3 bound at the
same placement. Not blocking.

The comment tells the truth. It says the snap finds the crossing at every
placement, exactly at the origin and 1.2e-9 off at the far turned
placement, and it states the pre-fix behaviour as history.

On the original engine, this AM2 premise goes red at the far placement
with `(null null, q …)`, as the report says. I re-fired this with M-P8 in
the app.

### M-3: docs the controller must fix in the closing commit (reported, not edited)

`docs/superpowers/specs/2026-09-28-dimensions-design.md` is now false or
stale in these places:
- **Lines 1169-1181** (the Q3c amendment).
  - "`SpatialIndex._considerIntersections` and `_collectNearSegments` read
    stored payload coordinates as world and never apply the leaf's group
    transform" is in the present tense and is now fixed.
  - "`AM2` asserts 'none, or an intersection exactly at `q`' at every
    placement" is **false**. It now asserts an intersection within 1e-5 of
    `q` at every placement, plus the empty candidate set at `q` and at the
    resolved point.
- **Line 2228**: "**`AM2`'s X crossing** asserts 'none, or an intersection
  exactly at `q`'" is **false** for the same reason.
- **Line 230** (non-goals): "Intersection snaps between groups' children
  (spike Q3c): an X crossing of two wall faces gives no snap" is now false
  at every placement. The conclusion still holds: such an end is fixed,
  because no attach point is there.
- **Line 157**: "`_considerIntersections` (1530: root-level entities
  only)".
  - The line number was already stale before this commit (1535 at
    `7b6630c`, 1545 now).
  - The scope is now "the root container's leaves, a flattened group's
    included".

Other docs:
- **Plan 11** (`docs/superpowers/plans/2026-09-28-dimensions.md:1638-1645`)
  is an "amended at execution" record. It is true as history, but a
  forward pointer to this fix would help a reader.
- **`docs/superpowers/notes/2026-09-28-plan-11-results.md:588`** ("Found,
  not fixed" (a)) and **STATUS.md** (lines 12, 55, 637, 2721, 2753) still
  list (a) as open.

### M-4: the pair loop's first doc sentence still says "root-level"

`_considerIntersections`' first sentence still says "among the root-level
line and polyline entities". It is not false, since grouped leaves of the
root are root-level content. The scope paragraph below it is now precise.
Leave it as is, or align the wording.

### M-5: NaN handling (negligible)

The near test changed from `if (d > radius) continue;` to
`if (d <= radius) {...}`. For a NaN distance, the old code accepted the
segment and the new code rejects it. This is reachable only with
non-finite coordinates, so it is not a finding for finite input.

## 1. Correctness of the fix (established)

**The identity is canonical.** `Transform2.identity()` is
`factory Transform2.identity() => const Transform2(1, 0, 0, 1, 0, 0);`
(`transform2.dart:33`). It is a canonicalized const, so no instance is
built per call. `_composeLeafTransform(identity, null)` copies 1, 0, 0, 1,
0, 0. With a group it gives `1*g.a + 0*g.b` and so on, which is exactly
the group's coefficients.

**Ungrouped input is bit-identical.**
- For finite coordinates, `1*x + 0*y + 0 == x` (up to the sign of a zero).
- The pair loop's order is unchanged:
  - i ascending, j > i;
  - near segments in stored order, since the new loop walks s = 1..n-1 and
    writes rows in order;
  - `winningSlot` unchanged.
- So ordering and ties are unchanged. The old suite passes: 1,041 of the
  engine's tests are the pre-existing ones.

**Every candidate is mapped.** Each root-container candidate goes through
`root.transformOfLeaf(slot)` (null means the identity), and every point is
mapped before `distanceToSegment`.

**The pair loop reads only mapped rows.** It reads `_nearSegmentWorld`,
captured *after* `_collectNearSegments` (see mutant R2 below).

**Buffer growth is correct.**
- When `at + 4 > length`, a buffer of `length * 2` gets
  `setRange(0, at, old)`, and `at = written * 4`, so every written row is
  copied.
- Lengths are multiples of 4, so a single doubling always suffices.
- M-P10 kills a dropped copy, and R2 (a stale capture) is killed by the
  buffer test.

**Nested groups compose the same way in all three places.**
- `ContainerIndex.build`: `acc.multiply(transform)`, starting from the
  identity.
- The oracle's `allLeavesInWorld`: `toWorld.multiply(node.transform)`.
- `toRootSpace`: `t.multiply(acc)` from the owner outward.

  At depth 2 all three give the same product.

**The dirty overlay path works.**
- `_reconcileEntity` computes `composed = _groupTransformOf(owner, …)` and
  calls `noteLeaf(slot, composed, …)`, which sets or clears
  `_leafTransforms` (`container_index.dart:639-643`).
- My **noteLeaf probe** added a line into an existing mirrored group
  *after* the build, so it arrived through the overlay:
  - `rebuildCount` stayed unchanged and `dirtyCount` grew, so this is a
    **new** `_leafTransforms` entry, not the re-set of an existing one that
    the committed test covers.
  - The snap is at the world crossing (19.8, -1.4) within 1e-9, with none
    at the phantom (6, 1).
  - The index agrees with the oracle over an 81 × 81 grid.
  - After `RemoveEntityCommand` and its undo (still no rebuild), the probe
    passes the same checks again.
- M-P1, M-P2, R3, R5 and R6 each turn this probe red.

## 2. The AM2 deviation

See M-2 above: the new premise is right and its comment is true, but the
premise could be exact at the origin. See M-3 for the spec text that the
change makes false.

## 3. Test sharpness

**The fixtures are non-degenerate.**
- The unit tests use:
  - rotation plus translation;
  - a pure rotation (the phantom test);
  - a non-uniform scale (2, 0.5);
  - a mirror (det −2, b ≠ c);
  - a nested translation over a rotation;
  - a pure translation only where the point is the near-segment
    distinction.
- The corpus's `groupedCrossings` asserts its own premises: non-axis-aligned
  A, anisotropy > 1.5 in B, det < 0 and non-symmetric C, D containing E, at
  least 10 world crossings, no crossing near a segment end, and a bare
  phantom.
- M-P5 and M-P6 each leave one unit test green (the pure rotation and the
  pure translation). The report discloses this, and the other tests and
  the differential kill both mutants.

**The aimed differential targets are independent of the index.** They come
from the oracle's `allLeavesInWorld` (`leaf.toWorld`) plus
`segmentIntersectionTol`. The only index call in that test is the query
under test. `reference_query.dart` is unchanged:
`git diff 7b6630c c7e4ac3 --stat -- …/reference_query.dart` is empty.

**The corpus builder is independent too.** It uses the `Transform2` values
it chose (`mde = md.multiply(me)`), not values read back from the document
or the index.

**The app test derives world geometry independently.** It walks each group
chain by hand (`acc = node.transform.multiply(acc)` up to the root) and
uses its own parametric crossing formula. The engine's `accumulatedTransform`
is used only to *build* the move command, not the expectations.

The app test passes on the fix:
- `P1 moved -300: 29 stored crossings, 14 with no world crossing within
  200.0 mm`;
- `P1 moved -300: 13 world crossings of P1 aimed at`.

The app test is red on the original engine (M-P8, re-fired):
`Expected: a value less than <0.000001> Actual: <180.0> near phantom
[16940.0,8250.0] the snap [16940.0,8250.0] is a world crossing`.

## 4. The open question: oracle and index candidate boxes under the cap

The two box formulas are identical:
- **Index, fresh build** (`addLeaf`):
  `entityBounds(...).transformedBy(composed)` (`container_index.dart:103-112`).
- **Index, dirty overlay** (`_reconcileEntity`):
  `expected = current.transformedBy(composed)` from the same
  `entityBounds(...)`, handed to `noteLeaf` as the container-space box
  (`spatial_index.dart:2883-2899`).
- **Oracle:** `entityBounds(local).transformedBy(toRootSpace(...))`.

Both are the loose box of the transformed local box, not a tight box of
the transformed geometry, and the overlap tests are inclusive on both
sides. The only possible differences:
- Composition rounding at a group depth of 3 or more, where the two
  products associate differently. This can only matter for a box touching
  the query square to within an ulp.
- The oracle's intersection pass ignores the query filter; the index
  filters before capping. This is pre-existing, and unreachable with
  `QueryFilter.all()`, which every differential snap call passes.

Neither is new in this commit. The fix does not touch candidate selection.

**Probe** (Q4): 60 groups (random rotation, ±scale and translation, half
of them mirrored), each holding a line and a two-segment polyline, plus 10
root lines.
- **130 root leaves touch the origin's query square (the cap is 64).**
- The index matched the oracle (intersection mask, `QueryFilter.all()`)
  over a 49 × 49 grid at radius 2:
  - fresh build: **0 disagreements, 2,401 snaps found**;
  - after 20 grouped leaves were edited through the overlay (no rebuild):
    **0 disagreements**.
- The probe is sharp:
  - on the original engine (M-P8): 2,401 disagreements;
  - M-P1, M-P2, R1, R2, R3, R5 and R6 each turn it red.

Settled: no disagreement under the cap, and none introduced by this change.

## 5. Allocation

The committed code builds no `Transform2`, since `identity()` is const, and
no `Vector2` per candidate or segment. It uses raw doubles and the existing
`_isect*` scratch.

The fixture drives transformed leaves through the pass. Its premises check
that all 48 leaves have a non-null `transformOfLeaf` and that an
intersection is found at the query point. On the original engine the
premise fails (M-P8: the case goes red at the premise), so the premise is
not vacuous.

The report's reason for the M-P9b and M-P9c survivors (a non-escaping
`Transform2`, scalar-replaced by the JIT) is plausible, and I-1 is direct
evidence for it: even a per-segment `Vector2` is invisible when the case
runs alone. Unmutated readings: `Vector2: 0.014` alone; `Transform2`
0.12–0.18 and `Aabb2` 0.07–0.13 in alone runs.

## 6. Mutants re-fired

Unless noted, each ran against `test/index/snap_intersection_group_test.dart`
plus `test/invariants/differential_test.dart` plus my probes. For each one:
`cp` to `scratchpad/p1r-backup-spatial_index.dart`, mutate, run, `cp` back.
Every restore gave `diff` exit 0 and a clean `git diff`.

| Mutant | Mutation | Result |
|---|---|---|
| M-P1 | Near filter maps; the stored coords written into `_nearSegmentWorld` | **Red**: all 9 unit regressions, the buffer-growth test, the aimed differential, both probes |
| M-P2 | Near filter measures stored coords; mapped coords written | **Red**: all 9 unit regressions, the aimed differential, both probes |
| M-P8 | Whole file restored from `7b6630c`; **differential alone** | **Red**, exit 1: `groupedCrossings snap matches brute force at and around every crossing and phantom [E] Expected: <22> Actual: <19> groupedCrossings aimed at [51.791098533573454,48.1849755595575], query [50.49109853357346,49.0849755595575] mask=128` (`differential_test.dart 307:17`). Also red: all 10 unit tests, both probes, the new allocation case (its premise), the app regression, and AM2 at the far placement |
| M-P9 | `_isectA1.setFrom(Vector2(x1, y1))` per segment | **Red in file order, 7 of 7** (0.95–4.05 per call). **Green alone, 3 of 3** (0.014). See I-1 |
| M-P9e (own) | `distanceToSegment(world, Vector2(x1, y1), Vector2(x2, y2))` | Red in file order (3.038); **green alone** (0.014). See I-1 |
| R1 (own) | Carried start point: only `x1` advanced, `y1` left at point 0 | **Red**: the polyline world-near unit test, both differential snap tests on `groupedCrossings` (random and aimed), the Q4 probe |
| R2 (own) | `final near = _nearSegmentWorld;` captured *before* `_collectNearSegments` (stale after growth) | **Red**: the buffer-growth unit test, the Q4 probe. The differential stays green |
| R3 (own) | `winningSlot` inverted | **Red**: the turned-group and grouped×ungrouped unit tests (entity names), the aimed differential, both probes |
| R4 (own) | `_nearSegmentStart[k]` written after the `points < 2` guard | **Survived** the committed suite; **red** on my one-point-polyline probe (`Expected: <20> Actual: <21>`). See M-1 |
| R5 (own) | End marker `_nearSegmentStart[count] = written` dropped | **Red**: 9 unit tests, the aimed differential, both probes |
| R6 (own) | Translation x and y swapped (`+ f` on x, `+ e` on y) | **Red**: 9 unit tests (all but the phantom test), the aimed differential, both probes |
| R7 (own) | Mask gate `if (mask.has(SnapKind.intersection))` becomes `if (true)` | **Red**: `groupedCrossings snap matches brute force over 200 random points` (pre-existing seam; the other snap test files were not run) |

## 7. Gates (review worktree, `c7e4ac3`, `CI=true` on every test command)

**Engine** (`packages/jet_cad_2d`):
- `dart test`: `00:19 +1077 -2: Some tests failed.`, exit 1. The two
  failures are the standing
  `test/testing/generate_document_test.dart: both text fractions default to
  zero and change nothing` and `... the default document is the one Plan 2
  measured, byte for byte`.
- `dart analyze`: `No issues found!`, exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 156 files
  (0 changed)`, exit 0.

**App** (`apps/floor_planner`):
- `flutter test`: `02:43 +491: All tests passed!`, exit 0.
- `flutter analyze`: `No issues found! (ran in 3.7s)`, exit 0.
- `dart format`: `Formatted 102 files (0 changed)`, exit 0.

**Render** (`packages/jet_cad_2d_flutter`), extra:
- `flutter test`: `00:57 +940 ~1 -7: Some tests failed.`, exit 1.
- The 7 failures are exactly the standing `text_ladder` rungs 1–5 and
  `text_lod_ladder` rungs 1–2 (`RenderBackend.canvas`).
- Analyze and format were not re-run.

**Not re-run:** the harness gate and `flutter build web`.

Both worktrees are clean. No `analysis_options.yaml` change appears in
`git status`.
