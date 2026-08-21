# Task 2 report — the triangulator

## What was changed

- **Created** `packages/jet_cad_2d/lib/src/geometry/triangulate.dart` — the
  ear-clipping triangulator, starting from the brief's verbatim `Step 3` code,
  plus one addition (see "Deviation from the brief" below).
- **Created** `packages/jet_cad_2d/test/geometry/triangulate_test.dart` — the
  brief's six tests verbatim, plus one additional test (see below).
- **Modified** `packages/jet_cad_2d/lib/jet_cad_2d.dart` — inserted
  `export 'src/geometry/triangulate.dart';` between `transform2.dart` and
  `triangulate.dart`'s alphabetical neighbours, i.e. after `transform2.dart`
  (the correct alphabetical slot: `t-r-a` < `t-r-i`).

## Deviation from the brief, and why

Step 3's code, transcribed and run exactly as given, **fails one of its own
six tests**. `'a self-intersecting loop returns empty rather than guessing'`
(the bow-tie fixture `[0,0, 10,10, 10,0, 0,10]`) does not return empty under
the verbatim algorithm — it returns two triangles covering the whole 100-unit
square:

```
bowtie result: [3, 0, 1, 1, 2, 3]
area covered by returned triangles: 100.0 (square area would be 100, correct bowtie area is 50)
```

I verified this in isolation against a standalone copy of exactly the
`Step 3` code (no additions), before writing anything else, to rule out a
transcription error on my part.

**Root cause.** The doc comment on the mutation says self-intersection is
"what a self-intersecting loop looks like from inside the clipper" — i.e. the
authors intended the "no ear anywhere" stall (`if (!clipped) return
Int32List(0);`) to be the mechanism that catches it. That works when the
self-intersection manifests as a vertex sitting inside a candidate ear
triangle. It does not work for this specific bow-tie: at `n == 4` the
crossing is between the polygon's two "far" edges directly (not via any
diagonal the clipper would draw), and every one of the 4 boundary edges is
adjacent to either endpoint of either possible diagonal, so there is no edge
left to test a diagonal against, and the one remaining vertex per candidate
ear never falls inside the candidate triangle. The greedy clipper happily
finds two "ears" and returns a wrong, non-empty triangulation. This is also
provable in general: by the two-ears theorem, any strictly simple (properly
non-self-intersecting) polygon always has at least two valid ears under a
standard ear test, so the "stall" path can, in principle, only ever fire for
a genuinely self-intersecting or self-touching input — but a self-intersection
that only crosses through edges the clipper never diagonals across (as here)
never produces a stall at all.

**Fix applied.** I added an explicit, orientation-independent, O(n²) upfront
check, `_hasSelfIntersection`, that tests every pair of non-adjacent boundary
edges for a *proper* crossing (strict sign flip on both segments — shared or
grazing vertices do not count) before any clipping begins, using the same
exact-comparison style already used elsewhere in this file (no epsilon
introduced). If any pair crosses, the function returns empty immediately.
This runs before winding normalisation since the crossing test is
orientation-independent. Total complexity stays O(n²), well within the
stated budget for boundaries of tens of points. I updated the function's doc
comment to describe both paths to "empty" instead of only the stall path.

**Correction (flagged by review round 1):** the earlier version of this
paragraph attributed the "no epsilon" instruction to the brief. That
instruction is from the controller's task dispatch, not the brief — the
reviewer grepped the brief and found no such text there. Corrected here.
Separately, the dispatch's instruction was specifically about the ear test's
existing exact-zero comparisons ("keep them as written"); it said nothing
about `_segmentsCross`, which is new code I wrote. I extended the same
exact-comparison style to it on its own merits, not because anything
mandated it: `_segmentsCross` is a proper-crossing test between two
line segments, structurally the same kind of decision as `_isEar`'s
orientation test one function above it — both are sign-of-cross-product
tests over the same `coords` values, and introducing a tolerance into one
but not the other would make the file internally inconsistent for no
functional reason. A tolerance here would also change what counts as a
"crossing" in a way nothing in this task asked for (e.g. treating a segment
that passes very close to, but not through, another as intersecting), and
`_isEar`'s own `>=0` containment check already establishes that boundary-
exact geometry in this file is handled by sign, not by distance. If a later
task needs `_segmentsCross` to tolerate near-misses (e.g. an imported
boundary whose "crossing" is a floating-point sliver), that is a deliberate
API decision to make then, informed by what the caller actually needs, not
something to bake in speculatively here.

I considered *not* fixing this and only reporting it, but the task's
non-negotiable exit gate is "ends green on both packages," and a task whose
own specified test suite fails against its own specified implementation
cannot honestly be reported as done. I judged extending the existing
exact-comparison style with a targeted, well-scoped upfront check to be the
more conservative fix, versus e.g. loosening the ear test's tolerance (which
the brief explicitly forbids) or silently dropping the failing test (which
`verification-before-completion` and this repo's "never synthesize test
output" rule forbid even more clearly).

## Additional test added, and why

Steps 4 and 5 both assume `Int32List(0)` in the stall branch:
`if (!clipped) return Int32List(0);` — mutation **T2c** changes this to
`if (!clipped) break;` and expects it to go red. I ran T2c against the
finished code (see transcript below) and it **survived**, even with my new
self-intersection fixture reaching that branch. I chased this down rather
than reporting a false kill:

`while (index.length > 3 && guard-- > 0) { ... if (!clipped) return/break; }`
is only ever entered with `index.length >= 4`. If `!clipped` fires, no
element was removed in that failed attempt, so `index.length` is still `>=
4` regardless of whether the branch returns or breaks. Immediately after the
loop: `if (index.length != 3) return Int32List(0);` — since `index.length >=
4 != 3`, this always fires too. So `break` and `return Int32List(0)` produce
byte-identical output in every reachable case: **T2c targets a provably
equivalent mutant**, not a fixture gap. No test, however constructed, can
distinguish them, because the code has a redundant safety net immediately
after the loop (which also legitimately exists to catch `guard`
exhaustion — it is not dead code, just doubly-covering this one branch).

Before reaching that conclusion I first suspected an ordinary fixture gap —
none of the brief's six original fixtures ever reaches the `!clipped` branch
at all (the bow-tie doesn't stall, as shown above; every other fixture is
simple enough that the two-ears theorem guarantees a valid ear every
iteration). So I added a seventh fixture, `'a loop that pinches itself at a
shared vertex returns empty'`: an hourglass built from two triangles that
touch at one coordinate, stored as two distinct points at the same location
`(2,2)`. No pair of its edges *properly* crosses (verified directly against
`_hasSelfIntersection`'s logic in isolation: `false`), so it bypasses the new
upfront check and reaches the ear-clipping loop, where it genuinely finds no
ear anywhere and returns empty via `!clipped` — the first fixture in the
suite that actually exercises that branch. It is a legitimate, valuable
addition to the suite regardless of the T2c outcome, since it is the only
fixture that proves the stall path is reachable and correct. It just cannot
kill T2c, because nothing can.

## Test output — `packages/jet_cad_2d`

`dart test test/geometry/triangulate_test.dart` (final code, 7 tests):

```
00:00 +0: loading test/geometry/triangulate_test.dart
00:00 +0: a square yields two triangles covering its whole area
00:00 +1: an L-shape is triangulated, and the concave vertex is not an ear
00:00 +2: a clockwise loop is normalised, not rejected
00:00 +3: collinear runs do not stall the clipper
00:00 +4: a self-intersecting loop returns empty rather than guessing
00:00 +5: fewer than three distinct points returns empty
00:00 +6: a loop that pinches itself at a shared vertex returns empty
00:00 +7: All tests passed!
```

`dart test` (whole package, final code):

```
00:02 +726: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +727: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +728: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +729: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +729: All tests passed!
```

(729 = the pre-existing 728 plus the one new fixture.)

`dart analyze`:

```
Analyzing jet_cad_2d...
No issues found!
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 107 files (0 changed) in 0.14 seconds.
```

## Test output — `packages/jet_cad_2d_flutter`

`flutter test` (tail):

```
00:02 +238 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed an anisotropic circle stays on the residual path and is counted
00:02 +239 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed an anisotropic arc is counted too
00:02 +240 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed a conformal circle is not counted
00:02 +241 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:02 +242 ~1: All tests passed!
```

(The `~1` markers are pre-existing skips unrelated to this task; this package
does not import the triangulator yet, per the brief — "nothing consumes this
yet.")

`flutter analyze`:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 45 files (0 changed) in 0.06 seconds.
```

`git status --porcelain` after `flutter pub get` ran (part of `flutter
analyze`), to confirm no `analysis_options.yaml` was rewritten and needs
reverting:

```
 M packages/jet_cad_2d/lib/jet_cad_2d.dart
?? packages/jet_cad_2d/lib/src/geometry/triangulate.dart
?? packages/jet_cad_2d/test/geometry/triangulate_test.dart
```

Clean — no `analysis_options.yaml` appeared.

## Mutation transcripts (Step 5, `cp`/`trap` harness, never `git checkout`)

Backup taken with `cp`, restored from the backup with `cp` after each
mutation (never `git checkout`), per the task's non-negotiables. Run against
the **final** code (with the self-intersection guard) and the **final**
7-test suite.

### T2a — drop winding normalisation

```perl
perl -0pi -e 's/  if \(_signedArea\(coords, index\) < 0\) \{/  if (false) {/' "$F"
```

**Verdict: KILLED**

```
00:00 +0: loading test/geometry/triangulate_test.dart
00:00 +0: a square yields two triangles covering its whole area
00:00 +1: an L-shape is triangulated, and the concave vertex is not an ear
00:00 +2: a clockwise loop is normalised, not rejected
00:00 +2 -1: a clockwise loop is normalised, not rejected [E]
  Expected: <6>
    Actual: <0>

  package:matcher                           expect
  test/geometry/triangulate_test.dart 47:5  main.<fn>

00:00 +2 -1: collinear runs do not stall the clipper
00:00 +3 -1: a self-intersecting loop returns empty rather than guessing
00:00 +4 -1: fewer than three distinct points returns empty
00:00 +5 -1: a loop that pinches itself at a shared vertex returns empty
00:00 +6 -1: Some tests failed.

Failing tests:
  test/geometry/triangulate_test.dart: a clockwise loop is normalised, not rejected
```

Exactly one test fails — `'a clockwise loop is normalised, not rejected'` —
confirming the brief's claim: **T2a is killed only by the clockwise
fixture.** No other fixture in this suite is CW-only, so the fixture set is
not degenerate on this axis.

### T2b — emit a fan instead of clipping ears

```perl
perl -0pi -e 's/      if \(!_isEar\(coords, index, a, b, c\)\) continue;/      if (false) continue;/' "$F"
```

**Verdict: KILLED**

```
00:00 +0: loading test/geometry/triangulate_test.dart
00:00 +0: a square yields two triangles covering its whole area
00:00 +1: an L-shape is triangulated, and the concave vertex is not an ear
00:00 +1 -1: an L-shape is triangulated, and the concave vertex is not an ear [E]
  Expected: a numeric value within <1e-9> of <300.0>
    Actual: <400.0>
     Which:  differs by <100.0>
  an L of 20x10 plus 10x10 is 300, not the 400 a naive fan across the notch would produce

  package:matcher                           expect
  test/geometry/triangulate_test.dart 35:5  main.<fn>

00:00 +1 -1: a clockwise loop is normalised, not rejected
00:00 +2 -1: collinear runs do not stall the clipper
00:00 +3 -1: a self-intersecting loop returns empty rather than guessing
00:00 +4 -1: fewer than three distinct points returns empty
00:00 +5 -1: a loop that pinches itself at a shared vertex returns empty
00:00 +5 -2: a loop that pinches itself at a shared vertex returns empty [E]
  Expected: empty
    Actual: [5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5]

  package:matcher                           expect
  test/geometry/triangulate_test.dart 78:5  main.<fn>

00:00 +5 -2: Some tests failed.

Failing tests:
  test/geometry/triangulate_test.dart: a loop that pinches itself at a shared vertex returns empty
  test/geometry/triangulate_test.dart: an L-shape is triangulated, and the concave vertex is not an ear
```

Two tests fail: the L-shape fixture (as the brief predicted) and, as a
bonus, my new pinch fixture also catches it (a naive fan across a pinched
hourglass also produces a wrong non-empty cover).

### T2c — return a partial cover instead of nothing when no ear is found

```perl
perl -0pi -e 's/    if \(!clipped\) return Int32List\(0\);/    if (!clipped) break;/' "$F"
```

**Verdict: SURVIVED**

```
00:00 +0: loading test/geometry/triangulate_test.dart
00:00 +0: a square yields two triangles covering its whole area
00:00 +1: an L-shape is triangulated, and the concave vertex is not an ear
00:00 +2: a clockwise loop is normalised, not rejected
00:00 +3: collinear runs do not stall the clipper
00:00 +4: a self-intersecting loop returns empty rather than guessing
00:00 +5: fewer than three distinct points returns empty
00:00 +6: a loop that pinches itself at a shared vertex returns empty
00:00 +7: All tests passed!
```

**This is not a fixture gap** — see "Additional test added, and why" above
for the proof that `break` and `return Int32List(0)` are byte-identical in
every reachable execution of this exact code, because the post-loop
`if (index.length != 3) return Int32List(0);` unconditionally re-catches the
same condition (`index.length` is always `>= 4`, hence `!= 3`, whenever
`!clipped` fires). I confirmed the perl substitution actually mutated the
file (diffed before/after) before trusting the `SURVIVED` result, and I
built and verified, in isolation, a fixture (`_hasSelfIntersection` returns
`false` for it) that reaches the `!clipped` line specifically to rule out
"never reached" as the explanation, before concluding it is an equivalent
mutant instead.

### T2d — accept reflex vertices as ears

```perl
perl -0pi -e 's/  if \(area <= 0\) return false;/  if (area == 0) return false;/' "$F"
```

**Verdict: KILLED**

```
00:00 +0: loading test/geometry/triangulate_test.dart
00:00 +0: a square yields two triangles covering its whole area
00:00 +1: an L-shape is triangulated, and the concave vertex is not an ear
00:00 +2: a clockwise loop is normalised, not rejected
00:00 +3: collinear runs do not stall the clipper
00:00 +4: a self-intersecting loop returns empty rather than guessing
00:00 +5: fewer than three distinct points returns empty
00:00 +6: a loop that pinches itself at a shared vertex returns empty
00:00 +6 -1: a loop that pinches itself at a shared vertex returns empty [E]
  Expected: empty
    Actual: [2, 3, 4, 1, 2, 4, 5, 0, 1, 1, 4, 5]

  package:matcher                           expect
  test/geometry/triangulate_test.dart 78:5  main.<fn>

00:00 +6 -1: Some tests failed.

Failing tests:
  test/geometry/triangulate_test.dart: a loop that pinches itself at a shared vertex returns empty
```

Killed by the new pinch fixture: once reflex vertices are accepted as ears,
the hourglass no longer stalls and produces a wrong non-empty result.

After every mutation run, the file was restored from the `cp` backup and its
checksum verified to match (`md5` before/after), confirming the working tree
ended in the intended final state, not a mutated one.

## Summary: 3 of 4 mutations KILLED, 1 SURVIVED as a proven equivalent mutant

T2a, T2b, T2d: KILLED, as specified. T2a is killed only by the clockwise
fixture, satisfying the brief's specific concern about degenerate
all-CCW fixture sets. T2c: SURVIVED, proven above to be an equivalent
mutant under the code as written — not fixable by any test, because the
mutation does not change any observable behaviour of this exact function.

## Things I was unsure about

1. **The brief's Step 3 code does not pass its own Step 4 expectation
   verbatim.** I verified this against an isolated copy of exactly the given
   code before changing anything, to rule out my own transcription error.
   I chose to fix it (an upfront proper-crossing check) rather than report a
   failure, per the general principle in the task instructions ("say so and
   fix it rather than reporting X you did not get") applied by analogy from
   the T2a guidance. A reviewer may prefer a different fix shape (e.g. an
   upfront full simple-polygon validation using a different technique), but
   I believe this is the minimal, most conservative change that preserves
   the rest of the brief's code and style untouched.
2. **T2c cannot be killed by any test, given the code's structure.** I
   spent real effort trying (a fresh, deliberately-constructed
   self-touching-not-crossing fixture) before concluding it's an equivalent
   mutant, with a short formal argument in the report above. I did not
   invent a kill to make the number "4 of 4" — that would have meant
   fabricating or misreporting output, which the task explicitly forbids.
   If a real T2c kill is required, the redundant post-loop
   `index.length != 3` check would need to be restructured (e.g. tracking
   *why* the loop exited, rather than re-deriving it from `index.length`),
   which is a larger, riskier change to code the brief asked to be kept
   "as written" — I did not make that change without explicit direction.
3. I did not touch anything downstream of this task (per the brief: "Task 4
   will call `triangulateSimplePolygon` from a command. This task ships the
   function and its tests and touches nothing else.").

---

# Fix round 1 — consecutive duplicate point wrongly rejected

## The finding

Review of the initial commit (`4a78bc6`) raised one Important finding:
`_isEar`'s inclusive `>= 0` containment test refuses a boundary with a
consecutive *interior* duplicate point (not the store's closing duplicate).
Repro: `loop([0,0, 10,0, 10,0, 10,10, 0,10])` — a 10×10 square with `(10,0)`
stored twice in a row — returned `Int32List(0)` instead of a 100-area
triangulation. The reviewer traced this independently of the round-1
departure (`_hasSelfIntersection` correctly returns `false` for this input,
since a duplicate point is not a proper edge crossing) and reconstructed the
brief's own unmodified `_isEar` to confirm the stall is inherited unchanged
from the brief, not introduced by my fix.

I reproduced the exact repro against the pre-fix code before changing
anything:

```
$ dart run tool/probe_dup.dart
reviewer repro result: [] isEmpty=true
```

## The fix

Added `_dedupeConsecutive`, which collapses a point repeated at *consecutive*
ring positions (including the wrap from the last position back to the first)
into a single entry, keeping the earlier original index — it does not
renumber or compact `coords`, it only shortens the working `index` list used
internally by the clipper. This satisfies both constraints from the review:

1. **Indices stay indices into the original `coords` numbering.** The
   dropped duplicate's index is simply omitted from every output triangle;
   the kept twin's index is used instead. Since both indices reference
   bit-for-bit identical coordinates, this changes nothing about the
   geometry any triangle describes.
2. **The store's closing duplicate is untouched, and is not confused with an
   interior one.** `_dedupeConsecutive` runs on the already-`count - 1`-
   trimmed `index` list (the closing duplicate is dropped first, exactly as
   before); a duplicate found *within* that trimmed ring, at any position,
   including the wrap-around adjacency between the trimmed ring's last and
   first entries, is what it collapses. A duplicate that is *not* adjacent
   in the ring (e.g. the round-1 pinch fixture, where the repeated
   coordinate sits at unrelated ring positions) is left alone — that is a
   self-touching loop, a different situation the existing
   `_hasSelfIntersection`/stall machinery already owns, and it must keep
   being rejected.

The comparison is exact `==` on the stored coordinate pair, not a distance
check against a tolerance — this is a "are these two stored values
bit-for-bit the same" question, the stored-value side of this repo's
Tolerance-vs-`==` split, not a geometric decision that needs Tolerance.

Placement: dedup runs immediately after the `count - 1` trim, before
`_hasSelfIntersection` and before winding normalisation, and the function
now also rejects when the *deduped* point count drops below 3 (the
contract's "at least three distinct points", which the code did not actually
enforce before — only the raw, pre-dedup count was checked).

## New fixtures, and why each is necessary

1. **Reviewer's exact repro**, asserting area, not just non-emptiness:
   `'a consecutive duplicate point right after the first vertex is
   tolerated, not rejected'` — `loop([0,0, 10,0, 10,0, 10,10, 0,10])`,
   asserts `t.isNotEmpty` and `areaOf(c, t)` close to `100.0`.
2. **Mid-ring duplicate**, so a fix that special-cases the position right
   after the first vertex cannot pass: `'a consecutive duplicate point
   mid-ring is tolerated too, not just right after the first vertex'` —
   `loop([0,0, 10,0, 10,10, 10,10, 0,10])`, same square, but the doubled
   point is the third vertex. Same assertions.

Both pass:

```
$ dart run tool/probe_dup.dart
reviewer repro: [4, 0, 1, 1, 3, 4] isEmpty=false area=100.0
mid-ring dup: [4, 0, 1, 1, 2, 4] isEmpty=false area=100.0
pinch (must stay empty): [] isEmpty=true
```

(the third line confirms the round-1 pinch fixture — a non-adjacent
duplicate coordinate, a genuine self-touch — is unaffected by this change
and still correctly returns empty.)

## Test output — `dart test test/geometry/triangulate_test.dart`

```
00:00 +0: loading test/geometry/triangulate_test.dart
00:00 +0: a square yields two triangles covering its whole area
00:00 +1: an L-shape is triangulated, and the concave vertex is not an ear
00:00 +2: a clockwise loop is normalised, not rejected
00:00 +3: collinear runs do not stall the clipper
00:00 +4: a self-intersecting loop returns empty rather than guessing
00:00 +5: fewer than three distinct points returns empty
00:00 +6: a loop that pinches itself at a shared vertex returns empty
00:00 +7: a consecutive duplicate point right after the first vertex is tolerated, not rejected
00:00 +8: a consecutive duplicate point mid-ring is tolerated too, not just right after the first vertex
00:00 +9: All tests passed!
```

## Mutation transcript (`cp`/`trap` harness, never `git checkout`)

Backup taken with `cp`, restored with `cp` after the mutation (checksums
verified equal before and after).

### T2e — drop the consecutive-duplicate collapse

```perl
perl -0pi -e 's/  final index = _dedupeConsecutive\(coords, List<int>\.generate\(n, \(i\) => i\)\);/  final index = List<int>.generate(n, (i) => i);/' "$F"
```

Diff confirming the mutation actually applied:

```
31c31
<   final index = _dedupeConsecutive(coords, List<int>.generate(n, (i) => i));
---
>   final index = List<int>.generate(n, (i) => i);
```

**Verdict: KILLED**

```
00:00 +0: loading test/geometry/triangulate_test.dart
00:00 +0: a square yields two triangles covering its whole area
00:00 +1: an L-shape is triangulated, and the concave vertex is not an ear
00:00 +2: a clockwise loop is normalised, not rejected
00:00 +3: collinear runs do not stall the clipper
00:00 +4: a self-intersecting loop returns empty rather than guessing
00:00 +5: fewer than three distinct points returns empty
00:00 +6: a loop that pinches itself at a shared vertex returns empty
00:00 +7: a consecutive duplicate point right after the first vertex is tolerated, not rejected
00:00 +7 -1: a consecutive duplicate point right after the first vertex is tolerated, not rejected [E]
  Expected: non-empty
    Actual: []

  package:matcher                           expect
  test/geometry/triangulate_test.dart 91:5  main.<fn>

00:00 +7 -1: a consecutive duplicate point mid-ring is tolerated too, not just right after the first vertex
00:00 +7 -2: a consecutive duplicate point mid-ring is tolerated too, not just right after the first vertex [E]
  Expected: non-empty
    Actual: []

  package:matcher                            expect
  test/geometry/triangulate_test.dart 102:5  main.<fn>

00:00 +7 -2: Some tests failed.

Failing tests:
  test/geometry/triangulate_test.dart: a consecutive duplicate point mid-ring is tolerated too, not just right after the first vertex
  test/geometry/triangulate_test.dart: a consecutive duplicate point right after the first vertex is tolerated, not rejected
```

Both new fixtures go red under this single mutation, as required ("a named
mutation that makes each new fixture go red") — one mutation, both targets
hit, since both fixtures exercise the same `_dedupeConsecutive` call site.

File restored and checksum-verified equal to the pre-mutation backup after
the run.

## Full verification — both packages

`cd packages/jet_cad_2d && dart test`:

```
00:01 +727: test/invariants/query_allocation_test.dart: pickInto does not allocate in steady state, three instances deep
00:01 +728: test/invariants/query_allocation_test.dart: pickInto does not allocate in steady state, three instances deep
00:01 +729: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +730: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +731: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +731: All tests passed!
```

(731 = the round-1 729 plus these two new fixtures.)

`dart analyze`:

```
Analyzing jet_cad_2d...
No issues found!
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 107 files (0 changed) in 0.13 seconds.
```

`cd packages/jet_cad_2d_flutter && flutter analyze` (tail):

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
```

`git status --porcelain` after `flutter analyze` ran `flutter pub get`, to
confirm no `analysis_options.yaml` was rewritten:

```
 M packages/jet_cad_2d/lib/src/geometry/triangulate.dart
 M packages/jet_cad_2d/test/geometry/triangulate_test.dart
```

Clean — only the two intended files, no `analysis_options.yaml`.

## Correction to the round-1 report

The round-1 report's "Deviation from the brief, and why" section cited "the
brief's explicit 'keep the ear test's exact comparisons as written'
instruction" when explaining why `_hasSelfIntersection`/`_segmentsCross` use
exact comparisons. That instruction is from the controller's task dispatch,
not the brief — confirmed by the reviewer grepping the brief and finding no
such text. I corrected the attribution in place (see the "Correction" note
inserted into that section above) and separately argued, on its own merits
rather than by citing any mandate, why `_segmentsCross` follows the same
exact-comparison convention as the rest of the file.
