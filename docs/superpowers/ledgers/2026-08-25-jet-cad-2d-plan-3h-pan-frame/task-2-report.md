# Task 2 report: `fillingGrid`, the first fixture that fills the viewport

Status: DONE_WITH_CONCERNS (see "Step 5 finding" below — the deliverable
matches the brief verbatim; the brief's specific Step 5 verification
prediction does not hold for this fixture, and I found and recorded the
actual mutation that does prove non-vacuity).

Commit: `e23d912a0265d6f9ff9ffb42872b28be769a3223`

## Step 1: test added verbatim

Added to `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`, exactly the
code block given in the brief, inserted at the top level of `main()`
immediately before the `group('accepted gap: ...')` block (2-space indent,
matching every other top-level `test(...)` in this file).

## Step 2: run it and watch it fail — verbatim

Command:
```
cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter
CI=true flutter test test/tile_cache_test.dart --plain-name "fillingGrid covers"
```

Output (verbatim, pub-get banner elided below the divider):
```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
test/tile_cache_test.dart:855:19: Error: Method not found: 'fillingGrid'.
        document: fillingGrid(measurer));
                  ^^^^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: test/tile_cache_test.dart:855:19: Error: Method not found: 'fillingGrid'.
          document: fillingGrid(measurer));
                    ^^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
```

This is the expected first failure — a compile-time "not defined" error
(the DDC/frontend spelling of it is "Method not found", not literally "isn't
defined", but it is the same class of failure the brief describes: the symbol
does not exist yet).

## Step 3: fixture added verbatim

Appended to `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`,
exactly the `fillingGrid` function given in the brief, after `nearAxisDiagonals`.

## Step 4: run it and watch it pass — verbatim

Same command as Step 2. Output:
```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: fillingGrid covers every edge of the viewport
00:00 +1: All tests passed!
```

## Step 5: non-vacuity — the brief's exact mutation does not fail

I copied the fixture aside (`cp test/support/tile_fixture.dart
/tmp/tile_fixture.orig`) and applied exactly the mutation named in the brief:
`fillingGrid`'s first loop, `240.0` → `120.0` (the horizontal-line loop,
nothing else touched). Re-ran the same command.

**Verbatim result — it still passes, contradicting the brief's prediction:**
```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: fillingGrid covers every edge of the viewport
00:00 +1: All tests passed!
```

I did not stop at a surprising negative result — I instrumented it. A
throwaway diagnostic test (`test/_scratch_debug_test.dart`, deleted before
the final commit and never staged) ran the same rig with the same mutated
fixture and printed each edge's boolean directly instead of asserting on it:

```
left=true
right=true
top=true
bottom=true
```

**Why, worked out from the geometry and confirmed by the printout above.**
Under `tileCamera()` (`sx = 1.4x - 37`, `sy = -1.4y + 323`, no shear):

- Each **horizontal** line (`fillingGrid`'s first loop: fixed world `y`,
  `x` from 20 to 320) maps to a fixed-row, full-width screen line. If its row
  is on-screen at all, it necessarily crosses *both* the left and right bands,
  because its screen-`x` span (-9 to 411) already overruns the 400-wide
  viewport on both sides. It only lands in the *top* or *bottom* band
  incidentally, if its own row happens to fall there.
- Each **vertical** line (second loop: fixed world `x`, `y` from 10 to 240)
  maps to a fixed-column, full-height screen line, by the same argument
  always crossing *both* the top and bottom bands, and landing in the left or
  right band only incidentally.

Because neither loop's world extent was touched — only the *count* of
horizontal lines produced by the first loop — the second loop (unmutated)
still independently saturates top and bottom, and enough surviving
first-loop lines (`t = 26 … 106`) still saturate left and right. Concretely,
in the original fixture the first loop's own extreme values already supply a
*second*, independent source for top (`t≈218`, `sy≈17.8`) and bottom
(`t≈26`, `sy≈286.6`) beyond what the second loop supplies — so shrinking the
first loop's upper bound removes only its own top-adjacent lines, and the
top band assertion is still carried by the second loop alone. Each loop, at
its written range, already satisfies all four edge checks by itself; that is
a real redundancy in this fixture, not a flaw in the assertions.

**A mutation that does fail, found by extending the same idea.** Truncating
*both* loops together — the first loop's bound `240.0 → 120.0` (as the brief
says) *and* the second loop's line endpoint `240 → 120` (the vertical
lines' far endpoint, removing their reach toward world `y≈230`, screen
`sy≈0`) — removes both of the top edge's independent sources at once.
Command and verbatim result:
```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: fillingGrid covers every edge of the viewport
00:00 +0 -1: fillingGrid covers every edge of the viewport [E]
  Expected: true
    Actual: <false>
  top edge

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 875:5                     main.<fn>

00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: fillingGrid covers every edge of the viewport
```

This is a genuine, verified named mutation that turns the test red (the
`top edge` assertion), satisfying CLAUDE.md's testing bar even though it is
not the exact single-constant edit or the exact edge (`bottom`, not `top`)
the brief predicted.

**Restore.** In both experiments the file was restored with
`cp /tmp/tile_fixture.orig test/support/tile_fixture.dart` — never `git
checkout`. Confirmed green again afterward:
```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: fillingGrid covers every edge of the viewport
00:00 +1: All tests passed!
```
`git status --porcelain` after the restore showed only the two intended
files modified (Step 1's test, Step 3's fixture), confirming the working
tree matched the pre-mutation state exactly.

**Concern for the plan owner / reviewer.** `fillingGrid` is more robust
against single-loop edits than the brief's narrative assumes: because each
loop already independently satisfies all four edge checks over its full
written range, a one-constant "shorten it and watch an edge fail" mutation
on either loop in isolation is not, in general, guaranteed to fail. The test
and fixture as written are still sound and not vacuous — a two-constant
mutation demonstrates that concretely — but a reviewer revisiting Task 2's
brief or a later Plan 3h task that relies on "the crippled query loses ink
near an edge" reasoning should know the redundancy exists.

## Step 6: full suite, analyze, format — verbatim tails

`CI=true flutter test` (full suite, tail):
```
00:05 +362 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:05 +363 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:05 +364 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:05 +365 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the comparison is not vacuous
00:05 +366 ~1: All tests passed!
```
(366 passed, 1 skipped — `~1` — no failures.)

`flutter analyze`:
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```

`dart format --output=none --set-exit-if-changed .`:
```
Formatted 64 files (0 changed) in 0.12 seconds.
```
Exit code 0.

## `git status --porcelain` before staging

```
 M packages/jet_cad_2d_flutter/test/support/tile_fixture.dart
 M packages/jet_cad_2d_flutter/test/tile_cache_test.dart
```
No `analysis_options.yaml` and no `.png` in the diff. Staged and committed
exactly these two files.

## Commit message note

The brief's suggested commit message ends with "watching the bottom edge
fail," which is the same claim Step 5 disproved for the exact mutation
given. Since the commit had not been pushed, I amended it once (not the
project's normal git workflow, but the alternative was landing a
provably-false claim in permanent history) to describe what was actually
measured: a two-loop truncation that fails the top edge, with a pointer to
this report for detail. No other content of the commit changed.

## Files touched

- `/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`
  — added `fillingGrid`, verbatim per brief.
- `/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart`
  — added the `fillingGrid covers every edge of the viewport` test, verbatim
  per brief.
