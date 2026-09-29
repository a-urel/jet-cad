# P1b report: the P1 review's fixes

**Commit:** `ebdf819` on `fix/phantom-intersection-snap`, parent `c7e4ac3`. Not pushed.

Files: 4 changed, +74 −14.
- `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` (I-1)
- `packages/jet_cad_2d/test/index/snap_intersection_group_test.dart` (M-1)
- `apps/floor_planner/test/dimension_attach_test.dart` (M-2)
- `packages/jet_cad_2d/lib/src/index/spatial_index.dart` (M-4, comment only)

No `analysis_options.yaml` change. The tree is clean after the commit.

## What changed

### I-1: the allocation case's doc comment (no logic change)

I re-measured with a temporary `print` of `counts['Vector2'] / iters` in the test. The test file was backed up to `scratchpad/p1b-backup-query_allocation_test.dart` and restored: `diff` exit 0, `git diff --quiet` exit 0.

| Configuration | Vector2 per call | Result |
|---|---|---|
| Unmutated, full file (`dart test test/invariants/query_allocation_test.dart`) | 0.014, 0.014, 0.014 | green 3/3 |
| Unmutated, alone (`--plain-name 'intersecting segments mapped'`) | 0.014 ×3 | green 3/3 |
| **M-P9** (`_isectA1.setFrom(Vector2(x1, y1))`), full file | 0.95, 1.526, 0.95, 5.486, 1.238, 1.238, 5.342, 1.166, 3.902, 5.486, 3.182, 1.4, 1.238, 1.382, 1.238 | **red 15/15** |
| M-P9, alone | 0.014 ×5 | **green 5/5** |
| M-P9, whole package (`dart test`, the gate) | 3.758, 1.598, 1.022 | red 3/3 (`+1077 -3`: this case plus the 2 standing failures) |
| **M-P9d** (each point through `Transform2(a, b, c, d, e, f).transformPoint(Vector2(lx, ly))`), full file | 0.302, 8.942, 13.262, 13.262, 6.784, 0.59, 10.094, 6.783, 1.31, 0.59, 1.454, 6.782, 10.526 | **red 12/13**. One green run read 0.302 |
| M-P9d, alone | 0.014 ×3 | **green 3/3** |

In file order my range for M-P9 is 0.95–5.49, not the review's 0.95–4.05, so the comment quotes my numbers. The review's finding holds: the kill depends on the file's order, and alone the mutant reads the unmutated baseline.

One thing the review did not measure: the per-point mutant (M-P9d, which P1 reported as killed at 1.166) is not a reliable kill even in file order. It went green once in 13 runs.

The doc comment now says, in substance:
- The case catches these mutants only when the file runs in order. It quotes both ranges and red counts, and notes the thin margin (lowest red readings 0.95 and 0.59).
- Run alone, the case passes both mutants at 0.014.
- The kill depends on file order. It held in the package gate 3 runs out of 3, at 1.02–3.76.
- Making the case order-independent is a harness question.

The "does not catch" paragraph on `Transform2` is unchanged, apart from its heading ("in any order").

The case's failure `reason` string also quoted "3.9 per call" and "1.2". It now quotes 0.95–5.49 in file order and points to the doc comment. This is text only.

### M-1: a one-point polyline test

Added to `snap_intersection_group_test.dart`: `a one-point polyline among the candidates leaves the crossing pair and its name alone`.

Fixture:
- A group at rotation (0.8, 0.6) and translation (100, 50).
- L1 local (0, 0)–(10, 0) and L2 local (4, −3)–(4, 5), crossing at world (103.2, 52.4).
- A root polyline P with the single point (103, 52), drawn last.

Premises checked:
- P's handle is greater than L2's.
- P is among `rootIndex.searchLeavesRaw` over the query square.

Asserts:
- An intersection at (103.2, 52.4) within 1e-9.
- `out.entity == l2`.

### M-2: the AM2 C6 premise

- The clause is now `res != null && res.kind == SnapKind.intersection && (place == origin ? res.point == q : (res.point - q).length < 1e-8)`.
- The reason string names both bounds.
- The checks at the resolved point (`bruteCandidates` and `through` both empty) are kept.
- The comment's "1.2e-9" is now "1.16e-9", measured with a temporary `print`, since removed:
  - `origin`: `[1900.0,100.0]` against q `[1900.0,100.0]`, offset 0.0.
  - `corpus far origin, 23 deg, own groups`: `[4501709.8861087095,1200834.4396294742]` against q `[4501709.88610871,1200834.439629475]`, offset `1.1641532182693481e-9`.
- The comment cites spec 11's AP3 bound (1e-8 at the same placement).

### M-4: the first doc sentence of `_considerIntersections`

"among the root-level line and polyline entities" now reads "among the line and polyline leaves of the root container -- a flattened group's included, an instance's never". Comment only; the engine diff is those lines.

## Mutants

Procedure for every mutant:
1. `cp` to `scratchpad/p1b-backup-*`.
2. Mutate.
3. Run.
4. `cp` back and `diff` (exit 0 every time); `git diff --quiet` on the file was clean each time.

No `git checkout --` was used.

| Mutant | Mutation | Run | Result |
|---|---|---|---|
| R4 | In `_collectNearSegments`, `_nearSegmentStart[k] = written;` moved after `if (points < 2) continue;` | `CI=true dart test test/index/snap_intersection_group_test.dart` | **Red**, exit 1, `+11 -1`: `Expected: <20> Actual: <21> the later-drawn line of the crossing pair names it, not the one-point polyline drawn after both` at `snap_intersection_group_test.dart 367:5`. The other 11 tests stay green |
| M-P9 / M-P9d | See I-1 | See I-1 | See the table there |
| M-2a | `_considerSnapCandidate(SnapKind.intersection, hit.x + (hit.x.abs() < 1e6 ? 1e-7 : 0.0), hit.y, ...)`: a 1e-7 offset near the origin only | New AM2 (`--plain-name 'AM2 a jamb'`) | **Red** at `origin`, exit 1: `Expected: true Actual: <false> premise: an intersection at the crossing, exactly at the origin, within 1e-8 elsewhere (SnapKind.intersection [1900.0000001,100.0], q [1900.0,100.0])` at `dimension_attach_test.dart 541:9` |
| M-2a | Same mutant | Old AM2 (the HEAD `c7e4ac3` file swapped in) | **Green**: `+2: All tests passed!`, exit 0. The old 1e-5 premise misses it |
| M-2b | Same edit with `hit.x.abs() >= 1e6`: 1e-7 at the far placement only | New AM2 | **Red** at `corpus far origin, 23 deg, own groups`, exit 1: `(SnapKind.intersection [4501709.886108809,1200834.4396294742], q [4501709.88610871,1200834.439629475])` at `541:9` |
| M-2b | Same mutant | Old AM2 | **Green**, `+2`, exit 0. The 1e-8 bound kills it; 1e-5 did not |

## Gates (this worktree, `CI=true` on every command, `PATH=/root/flutter/bin:$PATH`)

**Engine** (`packages/jet_cad_2d`):
- `dart test`: `00:17 +1078 -2: Some tests failed.`, exit 1. The two failures are the standing `test/testing/generate_document_test.dart: both text fractions default to zero and change nothing` and `... the default document is the one Plan 2 measured, byte for byte`. This is +1 over `c7e4ac3`'s 1077, as the brief expects.
- `dart analyze`: `No issues found!`, exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 156 files (0 changed)`, exit 0.

**App** (`apps/floor_planner`):
- `flutter test`: `02:16 +491: All tests passed!`, exit 0.
- `flutter analyze`: `No issues found! (ran in 1.6s)`, exit 0.
- `dart format`: `Formatted 102 files (0 changed)`, exit 0.
- `flutter build web --release`: `✓ Built build/web`, exit 0.

Not run: the render and harness gates. No file of theirs changed.

## Deviations

1. **The I-1 numbers are mine, not the review's.** M-P9 in file order read 0.95–5.49 (review: 0.95–4.05). I also measured M-P9d and the package-gate configuration, and both are in the comment. Because M-P9d went green once in 13 runs in file order, the comment does not claim it is a reliable kill.
2. **The allocation case's failure `reason` string was updated** as well as the doc comment. It quoted the same overclaimed "3.9 / 1.2" numbers. This is text only.
3. **The M-2 mutants live in the engine, not in the app test.** The cheapest way to reach "offset the found point at the origin only" was an engine edit gated on `|hit.x| < 1e6`. I also fired the far-only variant (M-2b) to show that the 1e-8 bound is sharper than 1e-5.
4. **Report doc fixes (M-3) are left alone** as the brief directs: spec, plan, notes and STATUS are the controller's.
