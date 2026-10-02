# Task 6b report: review fixes for Task 6 (spec D4)

- **Commit:** `e9b0a52` on `wip/09c1-t6` (parent `e188ef1`), worktree `.worktrees/plan-09c1-t6`. Not pushed.
- **Message:** `fix(app): pin the neighbour and snap rules, no closure in the snap step`, with both trailers.
- **Files:** 3 files, +445 −17.
  - `apps/floor_planner/lib/symbols/wall_attach.dart`
  - `apps/floor_planner/test/symbols/wall_attach_test.dart`
  - `apps/floor_planner/test/symbols/wall_attach_property_test.dart` (new)
- `analysis_options.yaml` is not staged. It is still modified in the worktree by pub get.
- **Scratch:** `scratchpad/task6b/` holds `mut.py`, the `mut_<id>_<wa|prop>.log` files and `gates.log`.

## Changes

### 1. Neighbour rule "both back-edge ends on the line" (review finding 1)
WA8 now places two more toilets, each built from a flush `standing(r, toiletBox, 700)`:
- one turned −10° about its local back-left corner;
- one turned +10° about its local back-right corner.

In each case the pivot corner stays on the face line, the other back end lifts about 69 mm into the room, and the front stays in the room. The test checks these premises by hand arithmetic:
- columns orthonormal within 1e-12;
- min |s| of the back ends < 1e-9;
- max s > 60;
- front s > 500.

Neither toilet is a neighbour: `of(r)` is still `[ok]`. Both corners are covered, so the mutant is red whichever end check is dropped.

### 2. The |ac + bd| clause of `isOrthonormal` (finding 2)
- **WA8** places a sheared instance: first column `t`, second column `−m` turned 20°, back-centre at u = 1200 on the face line. The premises are checked by hand, never through `isOrthonormal`:
  - unit columns within 1e-12;
  - |ac + bd| > 0.3;
  - both back ends < 1e-9 from the line;
  - front s > 500.

  It is not a neighbour.
- **WA18** (new) tests `isOrthonormal` directly:
  - true for a rotation by 20° and for a mirror, both far from the origin;
  - false for `Transform2(1, 0, sin 20°, cos 20°, …)`, for `(c, s, 0, 1)` and for a 1.5 scale on either column.

### 3. Edge-snap tie (finding 3)
An exact tie can be built, so the branch is now tested rather than recorded as untested. **WA17** (new) runs over 30° and −112.5°, plain and mirrored groups, both faces of a free wall, and the symbol mirrored or not:
1. `u0 = uOf(r, p)` for `p = at(r, 1500.25, 20)`.
2. Synthetic neighbours `left = (hi: u0 − 16 − 200)` and `right = (lo: u0 + 16 + 200)`. Every value stays in [1024, 2048), the same binade as `u0`.
3. Premises asserted exactly: `(hi + half) − u0 == −16` and `(lo − half) − u0 == 16`. The run's ends are beyond the edge capture.
4. In both list orders the result is `expectFlush` at `u0 − 16`.

### 4. No closure in the snap step (finding 4)
- `consider` is gone. The four targets each compute `d` into a plain local and call a static `_snapsBefore(d, shift, snapped, capture)`; `shift` and `snapped` are updated inline.
- The neighbour loop is indexed, so no iterator is created.
- The comparison and its order are unchanged: `d = target − u`, with `target` computed first as before.
- **Bitwise identical.** The reviewer's unmodified property file, run against the new code, printed exactly the reviewer's numbers:
  `R6-P1 tried 22500 attached 20246 null 2254 maxBack 2.432898327242583e-11 maxRel 2.464350131644555e-16`, `R6-P2 closed 75`, `+2: All tests passed!`.
  All existing WA tests are green.
- The O(1) claim comes from reading the code; I did not measure it with an allocation probe.

### 5. The property test, adopted
`test/symbols/wall_attach_property_test.dart` has two tests:
- **WP1** is R6-P1 with all its checks, over 75 scenes × **100** queries (7,500 queries), seed 60601. It also asserts:
  - the scene count is 75;
  - `tried == 7500`;
  - attached > 3/4 of the queries;
  - nulls > 1/20 of the queries.
- **WP2** is R6-P2 unchanged in substance, seed 60602, with `closed > 20`. Each scene's bands are disposed through `addTearDown`.

The prints are removed. The file's test time shows `00:00` for both tests; the whole run takes 6.4 s wall, compile included.

## Gates (worktree `plan-09c1-t6`, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

| Gate | Result |
|---|---|
| App `flutter test` | `06:04 +1117: All tests passed!` (1113 + WA17, WA18, WP1, WP2) |
| App `flutter analyze` | `No issues found! (ran in 2.1s)` |
| App `dart format --output=none --set-exit-if-changed .` | `Formatted 182 files (0 changed)`, exit 0 |
| `flutter build web --release` | `✓ Built build/web` |
| Engine, render, dev_harness | Not re-run: no file under `packages/` or `apps/dev_harness_2d` changed |

## Mutants (real runs)

**Method.** `scratchpad/task6b/mut.py`:
1. `cp` a backup of the file.
2. Make one exact-string replacement, asserted to match once.
3. Run `flutter test <file>`.
4. `cp` the backup back and check that `diff` exits 0.

### Against `test/symbols/wall_attach_test.dart`

```
O7_one_end [wa]: RED red=['WA8'] diff=0 | 00:00 +17 -1: Some tests failed.
O7b_other_end [wa]: RED red=['WA8'] diff=0 | 00:00 +17 -1: Some tests failed.
O6_shear [wa]: RED red=['WA18', 'WA8'] diff=0 | 00:00 +16 -2: Some tests failed.
O1_tie_reversed [wa]: RED red=['WA17'] diff=0 | 00:00 +17 -1: Some tests failed.
O1b_no_tie_clause [wa]: RED red=['WA17'] diff=0 | 00:00 +17 -1: Some tests failed.
h [wa]: RED red=['WA17', 'WA7'] diff=0 | 00:00 +16 -2: Some tests failed.
```

- **O7** drops the `e2` check, and **O7b** the `e1` check. WA8 fails on the neighbour list: `Expected: [36]  Actual: [36, 53]` (O7b showed `[36, 52]`), `30.0°: the lower piece`.
- **O6** drops `|ac + bd| ≤ tol`. WA8 fails on the neighbour list (line 538, `Actual: [36, 53]`) and WA18 fails directly.
  - My first draft had WA8's premise call `isOrthonormal`, so O6 went red only at that premise.
  - I replaced the premises with hand arithmetic, and the re-fire is shown above.
- **O1** is `d > shift`. **O1b** drops the tie clause entirely and keeps only `<`. Both fail with `Expected: within 1e-9 of 1484.2500000000045  Actual: 1516.2499999999995`.
  - O1 fails at `30.0° plain group left left first: u`.
  - O1b fails at `… right first`, which is why the test runs both orders.
- **h** removes both neighbour snap blocks in the new code.

### Against `test/symbols/wall_attach_property_test.dart` (100 queries per scene, as committed)

```
b [prop]: RED red=['WP1', 'WP2'] diff=0 | 00:00 +0 -2: Some tests failed.
af [prop]: RED red=['WP1'] diff=0 | 00:00 +1 -1: Some tests failed.
i [prop]: RED red=['WP1'] diff=0 | 00:00 +1 -1: Some tests failed.
h [prop]: RED red=['WP2'] diff=0 | 00:00 +1 -1: Some tests failed.
O16_exact_s [prop]: RED red=['WP1'] diff=0 | 00:00 +1 -1: Some tests failed.
```

- `af` and O16 fail on the winner-ranks-first check, at `T 30.0 mtrue s1.0 k33`.
- `i` fails on in-the-run, `Actual: 3770.08 > 3600.000001`.
- `h` fails in WP2, on the second-symbol snap.

**Margin check.** In a temporary copy with 30 queries per scene, `af`, O16 and `i` were all still RED. The file was restored with `cp` and `diff=0`, and the five mutants above were then re-fired at 100.

## Notes
- **N-a**, the tolerant ranking is not transitive: there is no code change. It is already covered by the doc comment's "compared within `wallJoin.linear`".
- `builds` is not marked `@visibleForTesting`. This was optional in the review and is left as it is.
