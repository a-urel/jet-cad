# P1b re-review: ebdf819, the P1 review's fixes

Reviewer: independent. Everything below ran in the detached worktree
`.claude/worktrees/fix-phantom-snap-review` at `ebdf819`. Nothing was
committed or pushed. For every mutant and instrumented run, I copied the
file to `scratchpad/p1rr-backup-*`, mutated it, ran the tests, copied it
back and ran `diff` (exit 0 every time). `git diff --quiet` was clean after
each restore. No `git checkout --` was used. `git status --short` in the
review worktree is empty at the end.

## Verdict: **Approved**

- All four rulings (I-1, M-1, M-2, M-4) are carried out as ruled, and
  nothing else changed.
- The changed comments and the failure reason string are true: I
  re-measured every number I could.
- The new one-point-polyline test kills R4.
- AM2 C6's new premise is exact at the origin and 1e-8 at the far
  placement. Its comment is true, and it kills an offset that the old
  1e-5 premise let through.
- The engine diff is comment-only.
- Both gates match what was expected.

No Important findings. Two Minor observations, neither of which needs a
change.

## 1. The rulings are carried out as ruled, and nothing else changed

`git diff --name-only c7e4ac3 ebdf819` lists exactly four files:

| Ruling | File | Change |
|---|---|---|
| I-1 | `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` | The `_groupedCrossingDocument` doc comment and the case's failure `reason` string. Text only |
| M-1 | `packages/jet_cad_2d/test/index/snap_intersection_group_test.dart` | One new test (+38 lines), nothing else touched |
| M-2 | `apps/floor_planner/test/dimension_attach_test.dart` | C6's premise clause, its reason string and its comment. The checks at the resolved point are kept |
| M-4 | `packages/jet_cad_2d/lib/src/index/spatial_index.dart` | The first doc sentence of `_considerIntersections` |

- No spec, plan, notes or STATUS file changed. M-3 is the controller's, as
  ruled.
- No `analysis_options.yaml` change.
- The I-1 ruling covered the doc comment. The failure `reason` string also
  quoted the overclaimed "3.9 / 1.2". Changing it is within the spirit of
  the ruling, and it is text only.
- M-4's new wording ("the line and polyline leaves of the root container --
  a flattened group's included, an instance's never") matches the scope
  paragraph below it. That paragraph says a leaf inside an instance is
  never a candidate and a flattened group's leaf is one.

## 2. The I-1 doc comment and the reason string are true

### Method

I added a temporary `print('P1RR Vector2 ${counts['Vector2']! / iters}')`
after `accumulatedInstances` in the grouped case, then restored the file
(`diff` exit 0).

I fired **M-P9** at `spatial_index.dart:1702`: `_isectA1.setValues(x1, y1);`
becomes `_isectA1.setFrom(Vector2(x1, y1));`.

### Readings

| Configuration | `Vector2` per call | Result |
|---|---|---|
| M-P9, full file (`CI=true dart test test/invariants/query_allocation_test.dart`) | 2.534, 1.814, 1.166, 1.23, 0.95, 3.542 | **Red 6 of 6**, exit 1 |
| M-P9, alone (`--plain-name 'intersecting segments mapped'`) | 0.014 ×4 | **Green 4 of 4**, exit 0, `+1: All tests passed!` |
| M-P9, whole package (`CI=true dart test`) | 3.398, 4.55 | **Red 2 of 2**, exit 1. The failures are this case plus the 2 standing `generate_document_test.dart` failures |
| Unmutated, full file | 0.014, 0.014 | Green |
| Unmutated, alone | 0.014, 0.014 | Green |
| **M-P9d** (own version: `final pv = Transform2(a, b, c, d, e, f).transformPoint(Vector2(lx, ly)); x2 = pv.x; y2 = pv.y`, for points s ≥ 1), full file | 0.878, 10.238, 0.302, 1.454 | **Red 3 of 4**. The green run read 0.302 |
| M-P9d, alone | 0.014 ×2 | Green 2 of 2 |

A sample red failure from full-file run 6:
`Expected: a value less than <0.5> Actual: <3.542> Vector2: 3.542 per call
over 1000 calls, against 48 grouped intersection candidates and 72 mapped
segments -- a Vector2 per mapped segment measured 0.95-5.49 per call here
in file order (the profiler undercounts; run alone, the JIT hides it
entirely -- see the doc comment on _groupedCrossingDocument)`.

### What these readings establish

- **The per-segment mutant is red in file order and green alone.** Alone,
  it reads exactly the unmutated baseline (0.014). The comment's central
  claim holds: the kill depends on the file's order.
- **My file-order readings (0.95 to 3.54) fall inside the comment's range
  of 0.95 to 5.49.** The lowest reading, 0.95, recurs for the third
  observer.
- **The per-point mutant is not a reliable kill even in file order.** It
  went green once in 4 runs, at 0.302, next to the comment's own green at
  0.30. The comment says exactly this ("red 12 times -- the one green run
  read 0.30").
- **The reason string is true.** "0.95-5.49 per call here in file order"
  and "run alone, the JIT hides it entirely" both match these readings.

The "does not catch in any order" paragraph on `Transform2` is unchanged
from `c7e4ac3` apart from its heading.

## 3. The one-point-polyline test is non-degenerate, and R4 turns it red

### The fixture is non-degenerate

The group transform is a rotation (0.8, 0.6) plus a translation (100, 50),
not the identity. I checked the geometry by hand:
- L1 maps to (100, 50)-(108, 56).
- L2 maps to (105, 50)-(100.2, 56.4).
- They cross at local (4, 0), which maps to world (103.2, 52.4), as the
  test asserts.
- P at (103, 52) lies on neither line (its cross product with L1's
  direction is -0.2).
- The query (103.5, 52.1) with radius 1 gives the square
  (102.5, 51.1)-(104.5, 53.1), as the comment says.
- The crossing is 0.42 from the query point, inside the radius.

The test also asserts its own premises:
- P's handle is greater than L2's.
- P is returned by `rootIndex.searchLeavesRaw` over that square.

"Drawn last" is what makes the test sharp. P sits at the last candidate
position k, so under R4 its start offset is never written. It then reads
the fresh, zero-initialised `Int32List` and claims every near segment.

### R4 fired

**R4:** in `_collectNearSegments`, `_nearSegmentStart[k] = written;` moved
after `if (points < 2) continue;`.

- `CI=true dart test test/index/snap_intersection_group_test.dart`: exit 1,
  `+11 -1`: `a one-point polyline among the candidates leaves the crossing
  pair and its name alone [E] Expected: <20> Actual: <21> the later-drawn
  line of the crossing pair names it, not the one-point polyline drawn
  after both`, at `test/index/snap_intersection_group_test.dart 367:5`.
- `CI=true dart test test/invariants/differential_test.dart`: `+100: All
  tests passed!`. So the new test is the only kill, which confirms the P1
  review's M-1.
- After the restore, the unit file reads `+12: All tests passed!`.

## 4. AM2 C6's new premise and comment are correct

### The premise

The premise loop is `for (final place in const [origin, corpusGroups])`
(`dimension_attach_test.dart:444`). So "elsewhere" is exactly one
placement: `corpusGroups`, whose name is "corpus far origin, 23 deg, own
groups" (`test/support/room_fixture.dart:71`).

The clause is `place == origin ? res.point == q : (res.point - q).length
< 1e-8`. `Vector2 ==` is exact per component.

### The comment

- **The 1.16e-9 offset.** The P1 review measured the far-placement snap at
  `[4501709.8861087095, 1200834.4396294742]` against q
  `[4501709.88610871, 1200834.439629475]`. The hypot of that difference is
  `1.1641532182693481e-09` (I recomputed it). That is 1.25 × 2^-30, so the
  comment's "1.16e-9" is right.
- **One ulp near 4.5e6.** `math.ulp(4.5e6)` = `9.313225746154785e-10`, so
  the comment's 9.3e-10 is right.
- **The spec bound.** Spec 11 line 2222 reads: "`AP3`'s bound … **1e-8 mm
  at the corpus far origin in own groups**, where the gap measured 1.04e-9
  mm, about one ulp of 4.5e6 (9.3e-10 mm) plus the round trip". The
  comment's "the bound spec 11 sets for AP3 at the same placement" is true.
- **The history.** The comment says the snap found nothing in own groups
  before the fix. The P1 review observed this (M-P8: `(null null, q …)`).

### Mutants fired

Each mutant is an engine edit at the `_considerSnapCandidate` call in the
pair loop. It adds an offset to `hit.x`. I ran each one against the new
AM2 and against the `c7e4ac3` AM2 (the old file swapped in, then
restored with `diff` exit 0):
`CI=true flutter test test/dimension_attach_test.dart --plain-name 'AM2 a jamb'`.

| Mutant | Offset added to `hit.x` | New AM2 (`ebdf819`) | Old AM2 (`c7e4ac3`, 1e-5) |
|---|---|---|---|
| **M-2a** (the report's) | `hit.x.abs() < 1e6 ? 1e-7 : 0.0` (origin only) | **Red** at `origin`, exit 1, at `dimension_attach_test.dart 541:9`: `Expected: true Actual: <false> premise: an intersection at the crossing, exactly at the origin, within 1e-8 elsewhere (SnapKind.intersection [1900.0000001,100.0], q [1900.0,100.0])` | **Green**, `+2: All tests passed!`, exit 0 |
| M-2b | `hit.x.abs() >= 1e6 ? 1e-7 : 0.0` (far only) | **Red** at `corpus far origin, 23 deg, own groups`, exit 1, `541:9` | **Green**, `+2`, exit 0 |
| M-2c (own) | `hit.x.abs() < 1e6 ? 1e-12 : 0.0` (origin only, about 4 ulp of 1900) | **Red** at `origin`, exit 1, `541:9` | **Green**, `+2`, exit 0 |

M-2c shows that the origin clause is genuinely exact, not merely tighter
than 1e-8. The unmutated AM2 passes in the app gate below, so the real far
offset is under 1e-8.

## 5. The engine diff is comment-only

`git diff c7e4ac3 ebdf819 -- packages/jet_cad_2d/lib` changes 5 lines, all
of them `///` lines of `_considerIntersections`' first paragraph. Filtering
out `///` lines leaves 0 changed lines.

## 6. Gates (review worktree, `ebdf819`, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

**Engine** (`packages/jet_cad_2d`):
- `dart test`: `00:16 +1078 -2: Some tests failed.`, exit 1. The two
  failures are exactly the standing
  `test/testing/generate_document_test.dart: the default document is the
  one Plan 2 measured, byte for byte` and `… both text fractions default to
  zero and change nothing`.
- `dart analyze`: `No issues found!`, exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 156 files
  (0 changed)`, exit 0.

**App** (`apps/floor_planner`):
- `flutter test`: `02:13 +491: All tests passed!`, exit 0.
- `flutter analyze`: `No issues found! (ran in 1.4s)`, exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 102 files
  (0 changed)`, exit 0.

Not re-run: render, harness, `flutter build web`. None of their files
changed.

## Important findings

None.

## Minor findings (no change required)

### m-1: a package-run reading fell outside the comment's package-run range

The doc comment says that under `dart test` over the package, the
per-segment mutant "read 1.02 to 3.76, red 3 runs of 3". One of my two
package runs read **4.55**. That is still red, and still inside the
file-order range of 0.95 to 5.49. The comment reports the implementer's
own sample, and that report is true. It is not a bound, and it does not
claim to be one.

No change needed. If the comment is ever touched again, it could quote
only the file-order range and the red count.

### m-2: the JIT explanation is an inference

The comment states the mechanism as fact: "the JIT scalar-replaces even
these `Vector2`s when the earlier tests in this file have not shaped its
state first". What was observed is the reading of 0.014 alone, identical
to the unmutated case. The mechanism was not observed. The unchanged
`Transform2` paragraph says "evidently" for the same inference.

The measured facts, which are the ones that matter for the ruling, are
stated correctly. Not blocking.

## Mutants fired (summary)

| Mutant | Where | Result |
|---|---|---|
| M-P9 | `spatial_index.dart:1702`, `setFrom(Vector2(x1, y1))` | Full file red 6/6 (0.95–3.54); alone green 4/4 (0.014); package red 2/2 (3.398, 4.55) |
| M-P9d (own version) | Each point for s ≥ 1 through `Transform2(..).transformPoint(Vector2(lx, ly))` | Full file red 3/4 (green at 0.302); alone green 2/2 (0.014) |
| R4 | `_nearSegmentStart[k] = written` after the `points < 2` guard | **Red** at `snap_intersection_group_test.dart 367:5` (Expected 20, Actual 21); `differential_test.dart` green |
| M-2a | +1e-7 on `hit.x` when `abs(x) < 1e6` | New AM2 red at `origin` (`541:9`); old AM2 green |
| M-2b | +1e-7 on `hit.x` when `abs(x) >= 1e6` | New AM2 red at `corpus far origin, 23 deg, own groups` (`541:9`); old AM2 green |
| M-2c (own) | +1e-12 on `hit.x` when `abs(x) < 1e6` | New AM2 red at `origin` (`541:9`); old AM2 green |

Backups are in `scratchpad/p1rr-backup-{spatial_index,query_allocation_test,dimension_attach_test}.dart`.
The old AM2 file is in `scratchpad/p1rr-old-dimension_attach_test.dart`.
