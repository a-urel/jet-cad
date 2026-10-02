# Task 6 review: attachToWall, neighbours, WallFaces (spec D4)

- **Reviewer:** an independent reviewer for plan 09c-1, Task 6.
- **Commit reviewed:** `e188ef1` on `wip/09c1-t6`, parent `54eab37`.
- **Diff:** `git diff 54eab37..e188ef1`, 3 files, +1136 −5.
- **Where it was checked:** a detached worktree at `.worktrees/plan-09c1-review-t6`, after `CI=true flutter pub get`.
- **Scratch:** `scratchpad/review6/`. It holds `mut.py`, the `mut_<id>.log` files, `gates.log` and `review6_property_test.dart`.
- **Clean-up:** the property test was copied into the worktree only for its own runs and then removed. `git status` shows only the `analysis_options.yaml` that pub get rewrote.

## Verdict: **Needs fixes**. All four findings are minor; nothing is blocking or major.

The attachment rule matches spec D4 rev 4 step by step. Every check below passed:
- all 15 named mutants are red when I re-fire them;
- my own differential/property check found 0 failures over 22,500 random queries and 75 scenes;
- the gates match the implementer's counts.

Two conditions of the neighbour rule have no test that kills them (findings 1 and 2). The spec states both explicitly, and each fix is a one-line fixture.

## 1. Spec conformance, line by line (`lib/symbols/wall_attach.dart`)

**D4 step 1, the candidates (:264-281).**
- `s` and `u` come from `p − a` dotted with `m` and `t`.
- A run is skipped when `s < −w/2` or `s > capture`, and when `u < −capture` or `u > L + capture`. The bounds are inclusive, as the spec says.
- The ranking in `_ranksBefore` (:338-347) has five keys, in the spec's order:
  1. `|s|`;
  2. the gap from `u` to `[0, L]`;
  3. the lower wall handle;
  4. the left face;
  5. the lower `a·t`.

**R-C6-2, the ties within `wallJoin.linear`.** I accept this ruling.
- Ranking is a geometric *decision*, so CLAUDE.md asks for a Tolerance here. `wallJoin.linear` is 1e-6, and it is the tolerance the spec names for D4's decisions.
- I confirmed the ruling is needed with my own mutant: exact `|s|` comparison (O16) turns my property test red. On random T scenes, the two pieces of one face line give `|s|` values that differ only by rounding.
- The edge snap compares exactly against `edgeCaptureWorld`, which is right: that value is the snap's own aperture.
- A side effect (the tolerant ranking is not transitive) is note N-a.

**D4 step 2 (:287).** `W > L + wallJoin.linear` returns null. Correct.

**D4 step 3.** The rotation is `(t.x, t.y)`.
- With `placementTransform`'s `Transform2(cos, sin, −sin, cos)`, local `+x` goes to `t` and local `+y` goes to `(−t.y, t.x) = −m`. Correct.
- `t` is a unit vector by construction (`d` is normalised, `m = ±(−d.y, d.x)`), as R-C5-3 requires.
- **R-C6-3 is accepted.** `placementTransform` cleans all six stored components (`symbol_placer.dart:63-65`), so a second normalisation in `attachToWall` would be dead code. M-09c-n fired at `clean` is red (WA14).

**D4 step 4 (:289-318).** Each target is where the centre goes when one side meets an edge:

| Side | Target edge | Centre goes to |
|---|---|---|
| left | the run's start `0` | `W/2` |
| right | the run's end `L` | `L − W/2` |
| left | a neighbour's right end `hi` | `hi + W/2` |
| right | a neighbour's left end `lo` | `lo − W/2` |

- The smallest `|shift|` wins. On a tie, `d < shift` picks the smaller resulting `u`.
- The clamp is `[W/2, L − W/2]` when `W < L`; otherwise the centre is `L/2`.
- `exclude` is checked at query time.

**D4 step 5 (:320-333).** The call is `placementTransform(at: q, basePoint: ((l+r)/2, back), rotation: (t.x, t.y), mirrored)`, with `q = a + t·u`. It does not call `backCentre`, as N-3 requires.

**Neighbours (:458-497).**
- Only root-level `InstanceNode`s are considered, and only when:
  - the definition carries a `SymbolComponent`;
  - `FilterEvaluator.acceptsNode(…, QueryFilter.picking())` accepts the instance (`visibleOnly` and `excludeLocked`);
  - the box is not null (R-C2-2);
  - `isOrthonormal` holds within `Tolerance.standard.linear`.
- Both transformed back-edge ends must be within `wallJoin.linear` of the run's line, and the front-centre must have `s > 0`.
- The interval is sorted, and the overlap with `[0, L]` is closed.
- **R-C6-1 and R-C6-5 are accepted.** The parallel per-run lists keep the query free of filtering.
  - The closed overlap lets a neighbour on a collinear wall at a straight joint serve both runs, which is the useful behaviour.
  - Picking through the engine's own filter is the rule the spec names.

**WallFaces (:358-497).**
- `_refresh` calls `bands.liveWalls` on every query: that returns a view, and rebuilds the bands only when they are stale.
- It rebuilds only when the document is not identical or `bands.generation` moved.
- `_boxes.clear()` runs *before* the neighbours are recomputed, so they read fresh boxes.
- `WallBands` bumps the generation on every `DocChange`, so a leaf edit or a placed symbol rebuilds too. WA9 sees both.
- **R-C6-6 is accepted.** One note: `builds` could carry `@visibleForTesting` from `package:meta`, which imports no Flutter. This is optional.

**R-C6-4, the extra import.** I checked the import closure with my own script:
- `wall_attach.dart` reaches 20 files and `symbol_box.dart` reaches 17;
- neither closure contains `package:flutter` or `dart:ui`.

## 2. Gates (my own runs, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

| Gate | Mine | Implementer's |
|---|---|---|
| App `flutter test` | `08:32 +1113: All tests passed!` | +1113 |
| App `flutter analyze` | `No issues found! (ran in 7.4s)` | same |
| App `dart format --output=none --set-exit-if-changed .` | `Formatted 181 files (0 changed)`, exit 0 | same |
| `flutter build web --release` | `✓ Built build/web`, exit 0 | same |
| Engine, render, dev_harness | Not re-run. `git diff --stat 54eab37..e188ef1 -- packages` is empty. | not re-run |
| Allocation invariant tests | `git diff --name-only 4d6b78f..e188ef1` over both `test/invariants` directories is empty | untouched |
| `analysis_options.yaml` | Not in the commit (`git diff --stat … -- '*analysis_options.yaml'` is empty) | not staged |

## 3. Mutants (re-fired by me)

**Method.** `mut.py` follows the same steps for each mutant:
1. Back up the file with `cp`.
2. Make a single exact-string replacement, asserted to match exactly once.
3. Run `flutter test test/symbols/wall_attach_test.dart`.
4. Restore the file with `cp` and confirm that `diff` exits 0.

Every row below printed `diff=0`, and the logs are `mut_<id>.log`.

### The plan's named mutants: all red

| Id | Change | Red tests |
|---|---|---|
| M-09c-b | `box.back` → `box.front` in `basePoint` | WA1, 2, 4, 6, 7, 11, 13 |
| M-09c-c | `rotation: (t.x, t.y)` → `quarterTurns: 0` | WA1, 2, 4, 6, 7, 11, 13 |
| M-09c-d | every non-left run skipped | WA1, 2, 3, 4, 11, 12, 13, 14, 15 |
| M-09c-h | the two neighbour `consider` calls removed | WA7 |
| M-09c-i | clamp removed | WA4, WA13 |
| M-09c-j | `mirrored: false` | WA1, WA6, WA7 |
| M-09c-m | the `W ≤ L + tol` test removed | WA11, WA12 |
| M-09c-n | `clean(v) => v` (`symbol_placer.dart`) | WA14 |
| M-09c-af | the gap key removed from `_ranksBefore` | WA4 |
| M-09c-ah (−w) | `s < −w` | WA5 (the stem's face expected, the host's far face won) |
| M-09c-ah (0) | `s < 0` | WA2, WA5, WA16 |
| M-09c-aq | overlap condition → `true` | WA8 |
| M-09c-au | `if (true)` clamp, without the `W ≥ L` case | WA12 (`103924.980021921` vs `103924.98002192109`: the hand clamp lands 1e-10 off, as T-6 predicted) |
| WallFaces not keyed on the generation | `identical(doc, _document)` only | WA9 |

### My own mutants

| Id | Change | Result |
|---|---|---|
| O1 | edge-snap tie reversed (`d > shift`) | **survived** (finding 3) |
| O3 | `consider(n.hi − half)` (wrong side to the neighbour's right end) | red: WA7 |
| O4 | `u` window `u < 0` instead of `u < −capture` | red: WA3, WA12, WA13 |
| O5 | `W > L − tol` | red: WA12 |
| O6 | `isOrthonormal` without `|ac + bd| ≤ tol` (shear) | **survived** (finding 2) |
| O7 | only one back-edge end checked against the line | **survived** (finding 1) |
| O13 | the gap ignores `u > L` | red: WA4 |
| O14 | `_boxes.clear()` removed | red: WA9 |
| O15 | front-side test `> −1e9` | red: WA8 |
| O16 | `|s|` ranked exactly (no tolerance) | red: my R6-P1 only (WA passes) |

## 4. Differential / property check (mine)

The file is `scratchpad/review6/review6_property_test.dart`. It ran in the worktree and was then removed.

**The 75 scenes:**
- free walls at 30°, −112.5° and 47.3°, × every justification, × plain, mirrored and scaled-1.5 groups;
- L corners, plain and mirrored-and-scaled;
- Ts at 90° and 70°, in plain, mirrored, and mirrored-and-scaled groups;
- the short-base fallback, in the same three groups;
- an X at 60°.

**R6-P1** makes 22,500 random queries. Each picks a pointer within the run's `u ± 1.2·capture` and `s ∈ [−0.6w, 1.2·capture]`, the toilet or the off-centre box, and a mirrored or plain symbol. Each result is checked against:
- an independently computed candidate set (null when it is empty);
- the winner ranking first: smallest `|s|`, then smallest gap, within 1e-6;
- on a null result, every tied first-ranked run being too short;
- both transformed back-edge ends on the face line, within `1e-9 × |coords|`;
- the front-centre at `D` into the room;
- all four footprint corners with `u ∈ [0, L]` and `s ≥ 0`;
- the linear part being exactly `±t` and `−m`;
- the mirror leaving the footprint unmoved (the corners swap pairwise within 1e-8);
- `u` matching an independent snap-then-clamp.

`R6-P1 tried 22500 attached 20246 null 2254 maxBack 2.432898327242583e-11 maxRel 2.464350131644555e-16`. **0 failures.**

**R6-P2** is a loop-closure check, run in every scene that has a run longer than 2,000 mm:
1. Attach a toilet with `WallFaces`, mirrored or not at random.
2. Place it with `placeSymbol(transform:)` and pump the event queue.
3. Check that the instance is a neighbour of its own run in `WallFaces`, with `[lo, hi] = u ± 200`.
4. Check that a second `offBox` 30 mm to its right snaps flush to `hi + W/2`, and that it stays at the pointer when the first toilet is excluded.

`R6-P2 closed 75`. **0 failures.**

My first P2 run did fail once, on a guard in my own test: the run end's snap (27.6 mm) correctly beat the neighbour's (30 mm). I corrected the guard; the code was right.

**Discriminating power.** I re-fired five mutants against the property file:

| Mutant | Red tests |
|---|---|
| b | R6-P1 and R6-P2 |
| af | R6-P1 |
| i | R6-P1 |
| h | R6-P2 |
| O16 | R6-P1 |

## 5. Fixtures (P-2)

- Every attach fixture is at 30° and −112.5°, near (1e5, −7e4), with groups turned by a non-multiple of 90°. The camera scale is 0.2.
- The toilet's box is `(0, 400, 0, 700)`, with a side at 0. `offBox` balances it: it has no side at 0 and is off-centre in both axes; WA1 uses both boxes.
- WA1 and WA2 cover plain, mirrored and scaled groups, and every justification and face. Mirrored and unmirrored symbols are covered throughout.
- The one axis-aligned fixture is WA14, the M-09c-n exception the plan allows.
- **Thinner spots** (note only; my R6-P1 and R6-P2 cover each of them and pass):
  - The neighbour tests WA7 to WA9 use plain groups only.
  - The T tests WA4, WA5 and WA8 never use a mirrored group.
  - The spec's "neighbour rotated 180°" is realised as a *mirrored* neighbour (WA7). On the same face, a root-level neighbour cannot be turned 180° and keep its back on the face, so the mirror is the realisable form of "the interval ends reversed". Its sort is pinned: the unsorted interval turns WA7 red, per the report.

## Findings

1. **Minor.** The "both back-edge ends" neighbour condition is untested.
   - **Where:** `wall_attach.dart:485-486`; the gap is in `test/symbols/wall_attach_test.dart` WA8.
   - **Evidence:** O7, which drops the `e2` line (`((e2 - r.a).dot(r.m)).abs() <= tol &&`), survives: `+16: All tests passed!` (`mut_O7_one_end.log`).
   - **Why it matters:** spec D4 requires "both ends on the run's line". A symbol turned a few degrees about its back corner on the face would count as a neighbour, with a nonsense interval for the snap.
   - **Fix:** add to WA8 an orthonormal toilet, rotated 10° about its back-left corner on the face line with its front in the room, and assert it is not a neighbour.

2. **Minor.** `isOrthonormal`'s orthogonality clause is untested.
   - **Where:** `wall_attach.dart:356`.
   - **Evidence:** O6, which drops `|ac + bd| ≤ tol`, survives: `+16: All tests passed!` (`mut_O6_shear.log`).
   - **Why it matters:** a sheared instance with unit columns would count as a neighbour.
   - **Fix:** add to WA8 a sheared instance whose two columns are unit length but not orthogonal (first column `t`, second column `−m` turned 20°), placed with its back edge on the line, and assert it is not a neighbour. Alternatively, add a direct `isOrthonormal` test: `Transform2(1, 0, sin 20°, cos 20°, 0, 0)` must be false, and a mirror must be true.

3. **Minor.** The edge-snap tie rule ("a tie goes to the smaller resulting `u`") is untested.
   - **Where:** `wall_attach.dart:298`.
   - **Evidence:** O1 (`d > shift`) survives (`mut_O1_snap_tie.log`). The implementer already reported this.
   - **The implementer's reason does not hold.** They said an exact tie cannot be built at 1e5. It can, because `attachToWall` takes its `neighbours` as plain records:
     - read `u₀` back with the test's `uOf` (the same arithmetic as the code, so bitwise equal);
     - pass synthetic `FaceNeighbour`s whose targets are `u₀ − 16` and `u₀ + 16`, dyadic offsets from dyadic `lo`/`hi` chosen relative to `u₀`;
     - assert that the centre lands on `u₀ − 16`.
   - **Fix:** add that test, or record the tie as an accepted untested branch in the results note.

4. **Minor (an allocation note, from reading; not measured).** The edge-snap step allocates more than O(1) on the Dart VM.
   - **Where:** `wall_attach.dart:291-312`.
   - **The cause:** `consider` is a local closure that captures the mutable doubles `u` and `shift`.
     - Each call to `attachToWall` allocates a Context and a Closure.
     - Each write to a captured double boxes it. That is one allocation per *improving* candidate, up to `2 + 2·neighbours`, plus `u += shift`.
   - **Why it matters:** this is a pointer-event path, not the paint path, and in practice the count is small. But D3 and D4 promise "allocates O(1)". On web, doubles are not boxed.
   - **Fix:** inline the comparison so no closure is needed. For example, a static helper `_better(d, shift, snapped)` that returns a bool, with `shift` and `snapped` kept as plain locals.

### Notes (no action needed)
- **N-a.** The tolerant `_ranksBefore` is not transitive. If three runs' `|s|` values are pairwise within 1e-6 but span more than 1e-6, the winner can depend on the run order. The effect is bounded by 1e-6 mm and invisible. A one-line comment would explain it.
- **N-b.** `WallFaces` sees another tool's commit only after `DocChange` is delivered. Until then a stale neighbour is possible. Task 7's own commit calls `invalidate()` (M-09c-ap). An undo or a delete from another tool is delivered before the next pointer event, in practice.
- **N-c.** A rebuild costs O(walls²) through `wallsInDocument` per wall, and O(instances × runs) for the neighbours (the implementer's own note). It runs only on a document change, and lazily, on the next query.

## Re-review of 6b (e9b0a52)

**Verdict: Approved.** All four Task 6 findings are fixed. My earlier property test gives bitwise-identical numbers on the new code, and every mutant I re-fired is red.

**Scope.**
- **Commit:** `e9b0a52` on `wip/09c1-t6`, parent `e188ef1`, checked out detached in `.worktrees/plan-09c1-review-t6`.
- **Diff** (`git diff e188ef1..e9b0a52`): `wall_attach.dart` +34/−13, `wall_attach_test.dart` (WA8 extended, WA17 and WA18 new) and the new `wall_attach_property_test.dart` (WP1, WP2).
- The worktree's `apps/` matches `e9b0a52` after every run. The only uncommitted change is the `analysis_options.yaml` that pub get rewrote.

### Gates (my runs, `CI=true`)

| Gate | Result |
|---|---|
| App `flutter test` | `04:28 +1117: All tests passed!` (1113 + WA17, WA18, WP1, WP2), the same as the implementer |
| `flutter analyze` | `No issues found! (ran in 2.1s)` |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 182 files (0 changed)`, exit 0 |
| `flutter build web --release` | `✓ Built build/web`, exit 0 |

### Bitwise-identical behaviour
I copied my original, unmodified `review6_property_test.dart` (300 queries per scene) into the worktree at `e9b0a52` and ran it. I removed it afterwards. It printed:
`R6-P1 tried 22500 attached 20246 null 2254 maxBack 2.432898327242583e-11 maxRel 2.464350131644555e-16`, `R6-P2 closed 75`, `+2: All tests passed!`

Every figure is identical to my `e188ef1` run.

I also checked by reading that each shift is computed in the same order:

| Snap | Before | After |
|---|---|---|
| run start | `to = half; d = to − u` | `d = half − u` |
| run end | `to = length − half; d = to − u` | `d = (length − half) − u` |
| neighbour right end | `to = n.hi + half; d = to − u` | `d = (n.hi + half) − u` |
| neighbour left end | `to = n.lo − half; d = to − u` | `d = (n.lo − half) − u` |

Beyond that:
- The comparison in `_snapsBefore` is the old one, token for token.
- The candidates are still considered in the same order.

### O(1) allocation (by reading)
- `consider` is gone. `u`, `shift`, `snapped` and `d` are plain locals, and nothing captures them, so there is no Context and no boxed double written per candidate.
- `_snapsBefore` is a static top-level function of three doubles and a bool, which the VM can inline. Even when it is not inlined, the call allocates nothing on the heap per call.
- The neighbour loop is indexed (`ns[k]`), so no iterator is created. Reading a record's fields does not allocate.
- What remains per query is O(1): the result record, `q`, the base point, and `placementTransform`'s fixed intermediates. Nothing is allocated per run or per candidate.
- This is from reading only; I did not measure it with an allocation probe, and neither did the implementer.

### The adopted property test (`wall_attach_property_test.dart`)
I diffed it against my file with whitespace ignored. Every check is kept, with the same tolerances, the same seeds (60601, 60602) and the same 75 scenes. It differs only in:
- 100 queries per scene instead of 300;
- the scene count asserted at 75;
- `attached > 3/4` and `nulls > 1/20` of the queries, instead of `attached > 1/3`;
- the prints removed;
- `addTearDown(bands.dispose)`.

It has not been weakened.

### Mutants (re-fired with `cp` backup and restore; every run `diff=0`)

**Against `wall_attach_test.dart`:**

| Mutant | Result |
|---|---|
| O1 (tie reversed) | red: WA17 (`within 1e-9 of 1484.2500000000045`, actual `1516.2499999999995`) |
| O6 (no `\|ac+bd\|`) | red: WA8 (`Expected: [36] Actual: [36, 53]`, the neighbour list, not a premise) and WA18 |
| O7 (no `e2` check) | red: WA8 (`[36, 51]`) |
| O7b (no `e1` check) | red: WA8 |
| M-09c-h (both neighbour snap blocks of the new code removed) | red: WA7, WA17 |
| M-09c-b | red: WA1, 2, 4, 6, 7, 11, 13, 17 |
| M-09c-d | red: WA1–4, 11–15, 17 |
| M-09c-i | red: WA4, WA13 |
| M-09c-m | red: WA11, WA12 |
| M-09c-af | red: WA4 |
| M-09c-ah (−w) | red: WA5 |
| M-09c-aq | red: WA8 |
| M-09c-au | red: WA12 |
| WallFaces not keyed on the generation | red: WA9 |
| M-09c-n (`symbol_placer.dart`) | red: WA14 |

**Against `wall_attach_property_test.dart` as committed:**

| Mutant | Red tests |
|---|---|
| b | WP1, WP2 |
| af | WP1 |
| i | WP1 |
| h | WP2 |
| O16 (exact `\|s\|`) | WP1 |

### Findings resolved
1. **"Both back-edge ends on the line."** WA8 turns a toilet 10° about each back corner, with the premises checked by hand. O7 and O7b are red.
2. **The `|ac + bd|` clause.** WA8 adds a sheared instance with unit columns, its premises checked by hand without calling `isOrthonormal`. WA18 tests `isOrthonormal` directly. O6 is red.
3. **The edge-snap tie.** WA17 builds an exact ±16 tie from synthetic neighbours in one binade, and asserts the premises exactly in both list orders. O1 is red.
4. **The closure.** It is removed, as described above.

No new findings. N-a (the non-transitive tolerant ranking) is left as a note, which I accept.
