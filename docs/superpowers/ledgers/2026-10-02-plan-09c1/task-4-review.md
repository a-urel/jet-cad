# Task 4 review: wall faces (spec D3)

Independent reviewer, plan 09c-1. Reviewed `git diff a6ef0bc..e73621f` in a detached worktree
`.worktrees/plan-09c1-review-t4` at `e73621f`. Scratch and raw logs:
`/tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review4/`
(the mutant logs are `mut_<id>.log`, the mutant script is `mut.py`, and my temporary differential
tests are `zz_review_*.dart`. They were removed from the worktree afterwards, which is now clean
except for the `analysis_options.yaml` that pub rewrote).

## Verdict: Needs fixes (one major, one minor; both test-only, the code is correct)

## Findings

1. **Major (test gap, degenerate fixture on the S-3 line).** `apps/floor_planner/test/symbols/wall_faces_test.dart` WF3/WF5/WF8 with `test/support/wall_attach_fixture.dart:29-33,94-115`.
   - **Problem:** every T scene's host has handle 18. `teeScene(30, 70).walls` printed `[18, 19]`, so `attachGroup(18)` turns the host by 0.3 rad (17.2°) in every T test. That is too close to the identity to tell `toLocal` from `toWorld` in the side test. I applied this mutant at `wall_attach.dart:130`:
     `toLocal.transformDirection(End(b, k).a)` → `host.toWorld.transformDirection(End(b, k).a)`
     The whole of `wall_faces_test.dart` stays green (`+8: All tests passed!`). There are two reasons:
     - **Unmirrored (WF3):** the mutant rotates the stem direction by 2θ = 34°. That never flips the sign against `n` for stem turns of 70° and −110°.
     - **Mirrored (WF5):** the linear part of a uniform scale × rotation × reflection is its own inverse up to scale, so `toWorld` and `toLocal` agree in direction there. WF5 can only ever kill the world-normal variant (M-09c-as), never this one.
   - **Evidence:** my temporary check builds the same T with the host group at 0.3, 1.0, 1.7 and 2.4 rad. Under the mutant it goes red at `rot 1.0 turn 70.0` (`Expected: an object with length of <2>`), and it is green on the committed code.
   - **Fix:** in WF3, vary the host group's rotation so that 2θ moves the side. For example, add a host rotation of about 1.0 rad, through a `teeScene` parameter or by reserving handles so that the host's `h % 9 ≥ 1`. Assert the premise in the test: for at least one case, `toWorld.transformDirection(a)·frame.n` disagrees in sign with the local test. Then fire this mutant.

2. **Minor (unpinned branch).** `wall_attach.dart:187-192` (`_pieces`: the sort and merge of several cuts on one face).
   - **Problem:** no face in the suite has more than one cut. WF3, WF4, WF5 and WF8 each give at most one cut per face.
   - **Evidence:** the mutant `if (b > from) from = b;` → `from = b;` survives (`+8: All tests passed!`). Dropping the sort would survive too.
   - **Context:** my differential (below) shows the code is right on 248 faces with three or more runs.
   - **Fix:** add one face with two cuts where one cut is nested in, or overlaps, the other. For example, two stems on the same side, an oblique wide one and a narrow one whose cut lies inside the first. Assert the pieces, and fire the merge mutant.

## Notes (no action required for this task)

- **N1, differential check.** I wrote my own check over random scenes. Each scene is a host with 0–2 Ts, an optional X and an optional L. Each wall is in its own group with a random rotation in [0, 2π), placed near (1e5, −7e4). Scale is 1, 1.5 or 0.6, and a third of the scenes are mirrored, with centre justification. 800 scenes gave 6,228 runs, and a further 200 nodes of 3–4 spokes gave 1,406 runs. For every run, the check asks:
  - (a) Do both ends lie on one edge of the wall's **stored** outline, within 1e-6? **0 failures** (nodes included).
  - (b) Does `m` point out of the outline: is `mid + 1e-3·m` outside it and `mid − 1e-3·m` inside? **0 failures.**
  - (c) Is `w` the distance to the opposite face's run line? **0 failures.**
  - (d) Is no other wall's body in front of the run's interior, and is every gap between two runs under another wall?

  Check (d) does fail. Every failure falls into one of three inherited cases, none of them D3's own rule:
  - **Mirrored walls:** the frames fall back to the local free rectangle, so a stem's or an L leg's drawn face runs into the neighbour's body.
  - **07's drawn T:** one unmirrored T stem (scene 63) is stored untrimmed through a left-justified host's body.
  - **08's classification:**
    - **A free end that pokes into a band off the centreline** is not an obstacle (08's rule).
    - **A wall whose end stops inside the host's band past the centreline** is classified as an X. Both faces are then cut, including the one that wall's body never reaches (scene 170, an over-cut of about 85 mm).

  This is spec-faithful (D3 uses `obstaclesOf`'s classification and the drawn faces; D14 lists the classification limit). Possible look items for Task 6/11: a symbol can attach on the part of a stem's face that runs inside a mirrored host, and an X ending inside a band leaves an empty gap.
- **N2.** "Mirrored walls never draw joined corners" is confirmed and pre-existing. In my differential, 688 of 688 mirrored frames fell back and 0 were joined. `git diff --stat main..e73621f -- apps/floor_planner/lib/parametric/` shows only `wall_bands.dart` (+16), so `wall_geometry.dart` and `opening_geometry.dart` are byte-identical to `main` (`4d6b78f`). P-2's "mirrored, joined" fixture is therefore impossible today. WF5 exercises the side test on fallen-back frames, which is enough for M-09c-as, because the side test does not depend on the fallback (but see finding 1).
- **N3.** In `_pieces`, the `end < 0` branch (`:185-186`) survives a mutant (`hi = end; from = 0`). It is unreachable in practice: crossed caps make the ring non-simple, so the frame falls back. D3 says "the interval between the projections", so the symmetric handling is a faithful reading.
- **N4.** R-C4-4 (B's frame among `host + walls − B`, ascending) is unpinned: the mutant that drops `host` from that list survives. It is nearly equivalent: B's face *lines* do not depend on its joints, except when B's joined local ring would be non-simple and fall back. Acceptable.
- **N5.** All the pieces of one face share their `t`, `m` (and `d`) `Vector2` instances (`_pieces:169`). Task 6 must treat `FaceRun` vectors as read-only.
- **N6.** `wall_attach.dart` also imports `package:vector_math`, which is not in P-4's literal list. It is pure Dart, and `opening_geometry.dart` imports it too. That is fine.

## Spec and plan conformance (D3, rev 4), line by line

- **Face lines** (`:153-162`): left through `startCap.first`/`endCap.last`, right through `startCap.last`/`endCap.first`, mapped by `toWorld`. Direction is `transformDirection(frame.d).normalized()`. The extent is the projections of the cap points, `lOff`/`rOff` are never used, and interior cap points are never used. ✓
- **`m`** (`:97-98`): the world normal of `d` pointing from the right face line to the left one for the left face; the right face gets `−mLeft`. That is "away from the other face line". ✓ WF1 checks it against the hand normal, and the reviewer mutant `mLeft = nd` is red in WF1.
- **`t = (−m.y, m.x)`, and `a` the lower end along `t`** (`:169-176`). ✓ WF1 checks it exactly. The reviewer mutant that swaps `a` is red in WF1–WF6 and WF8.
- **`w = |(ls − rs)·m|`** (`:99`). The two face lines are parallel (both along the image of `frame.d` under an affine map), so the projection gives the line distance even when the two start-cap points are at different `u` (the start of a joined L leg). ✓ The reviewer mutant `(ls − rs).length` is red in WF2 (`240` vs `243.18…`) and WF6.
- **T** (`:126-133`): the side is decided by `toLocal.transformDirection(End(B,k).a)·frame.n > 0`, exactly as D3/S-3/T-7 word it. The cut is the range of B's two **drawn** face lines crossing the butted face line, with B's frame from R-C4-4, as T-2 requires. Only that face is cut, and the X branch is skipped. ✓
- **X** (`:135-137`): each face is cut by its own crossings (S-7). ✓
- **Sliver drop:** `!(y − x > wallJoin.linear)` drops a piece no longer than the tolerance. ✓ WF8 covers 5e-7 dropped and 3e-6 kept.
- **Elsewhere:** `obstaclesOf` is used for naming only, `Obstacle` is unchanged and `stretchesOf` is unused. Openings are ignored. `faceRunsOf` asks `accept` only for a live wall.
- **`liveWalls`:** refreshes first, and returns a cached `UnmodifiableListView` of the final `_handles` list, which is cleared and refilled in place, so it is a view rather than a copy, with no allocation per call. ✓
- **Exact vs tolerance:** decisions use `wallJoin.linear` (the sliver) and `strictlyInside` (the classification). No stored-value comparison is involved.
- **Unaffected areas:** no frame-path code changes, and no draw order, permissions or undo are involved.
- **Rulings:** I agree with R-C4-1 through R-C4-4.
  - **R-C4-1:** the plan's three-parameter signature was redundant. The adapter plus the pure function fit D3 and T-4.
  - **R-C4-2:** the order and `FaceSide`.
  - **R-C4-3:** recomputing T/X with `strictlyInside` reproduces `obstaclesOf`'s own decision.
  - **R-C4-4:** the same neighbour set as `wallsInDocument(doc, B)`.

## Gates (re-run by me at `e73621f`, `CI=true`, Flutter at /root/flutter)

| Gate | Result |
|---|---|
| App `flutter test` | `+1075: All tests passed!` (the same as the implementer's pre-commit run 2) |
| App `flutter analyze` | `No issues found!` |
| App `dart format --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 |
| App `flutter build web --release` | `✓ Built build/web`, exit 0 |
| Engine, render | Unchanged (the diff touches no file under `packages/`), so I did not re-run them |
| Allocation invariant tests | Unedited (`git diff --quiet` exit 0 on both) |
| `analysis_options.yaml` | Not committed (it is not in the diff) |
| Purity | The transitive import closures (my script) of `wall_attach.dart` (16 files), `symbol_box.dart` (17), `opening_geometry.dart` (15) and `wall_bands.dart` (16) contain no `package:flutter` and no `dart:ui` |

## Mutants (re-fired by me: cp backup, mutate, run the test file, cp back, `diff` exit 0 every time)

| Id | Change | Result | Red tests, first excerpt |
|---|---|---|---|
| M-09c-f | the host's extents set to the centreline ends projected on each face line (lines and `w` kept) | red | WF2, WF6: `within 0.000001 of 3778.33 / Actual: 3999.99` |
| M-09c-g1 | T cut never added | red | WF3, WF5, WF8 |
| M-09c-g2 | T also cuts the other face by its own crossings | red | WF3, WF5: `length of <1>` |
| M-09c-g3 | X cut on the left face only | red | WF4 |
| M-09c-ag (extent) | left extent starts at `startCap.last`'s projection | red | WF2, WF6: `of 2960.78 / Actual: 3000.0` |
| M-09c-ag (line) | left face through `startCap.last` | red | WF1–WF6, WF8 |
| M-09c-as | T side from the world left normal | red | WF5 |
| M-09c-at | face points from `frame.left/right` at the caps' `u` | red | WF6: `of 100.0 / Actual: 150.00000000000148` |
| M-09c-ay | X: both faces cut by the union | red | WF4: `less than 1e-7 / Actual: 115.47` |
| liveWalls without refresh | `_refresh(doc)` removed | red | WB2: `Expected: [18, 20] Actual: []` |
| R-1 (mine) | `w = (ls − rs).length` | red | WF2, WF6 |
| R-2 (mine) | `a` the other end | red | WF1–WF6, WF8 |
| R-3 (mine) | `mLeft = nd` | red | WF1 |
| R-4 (mine) | T side via `toWorld` instead of `toLocal` | **survives** | finding 1; my rotated-host check kills it |
| R-5 (mine) | merge `from = b` unconditionally | **survives** | finding 2 |
| R-6 (mine) | `end < 0` branch removed | survives | N3 (unreachable) |
| R-7 (mine) | B's frame without the host | survives | N4 (near-equivalent) |

The implementer's mutant claims reproduce: every named mutant is red with the same tests.

## Re-review of 4b (54eab37)

### Verdict: Approved

Both findings are closed. The change is test-only: `wall_attach.dart` at `54eab37` is byte-identical to `e73621f` (`git diff --quiet` exit 0). I reviewed only `git diff 54eab37~1..54eab37`, which touches `test/support/wall_attach_fixture.dart` and `test/symbols/wall_faces_test.dart`.

### Fixture change: existing scenes are unchanged

- **`attachGroup`:** the new line is `Transform2.rotation(rotation ?? 0.3 + 0.7 * (h % 9))`. In Dart, `??` binds more loosely than `+`, so this reads `rotation ?? (0.3 + 0.7·(h % 9))`. With `rotation` null, the group is the old one.
- **`attachScene`:** `rotations` defaults to `const []`, so each wall's rotation is null and its group is unchanged.
- **`teeScene`:** passes `[hostRotation]`, which is `[null]` by default. Host and stem groups are therefore unchanged.

No existing caller passes the new arguments. WF1, WF2 and WF4 through WF8 run on identical scenes, and WF3's `null` case is the old 0.3 rad scene.

### Tests

- **WF3 (finding 1).**
  - The host group is turned 0.3, 1.0 and 1.7 rad, giving 72 cases, and the rotation is asserted through `atan2`.
  - The premise is asserted as a count: the `toWorld` mapping disagrees with the local side test in exactly 48 cases, which are all the 1.0 and 1.7 rad cases and none at 0.3. That makes the premise self-checking.
  - The implementer notes the margin at 1.0 rad is thin (about ±0.08). The 1.7 rad cases carry a large margin, so that is fine.
- **WF9 (finding 2).** It has nested stems and a stem across an oblique X.
  - The X case is needed to kill the no-sort mutant, because `obstaclesOf` already returns the obstacles sorted by `a`. The test pins the obstacle order `[X, stem]` as a premise.
  - The expected pieces come from the Cramer oracle on the world face lines, not from the code under test.
  - The fixtures are at 30° and −112.5°, on both faces, and near (1e5, −7e4).

### Mutants (re-fired by me at `54eab37`: cp backup, mutate, run `wall_faces_test.dart`, cp back; `diff` exit 0 after each)

| Mutant | Result | Red test, excerpt |
|---|---|---|
| R-4: T side via `host.toWorld.transformDirection` (`:130`) | **red** (it survived at `e73621f`) | WF3: `Expected: an object with length of <2>` |
| R-5: merge `from = b` unconditional (`:191`) | **red** (it survived at `e73621f`) | WF9: `less than <1e-7> / Actual: <172.02841614876905>` |
| No sort: `[...cuts]` (`:187`) | **red** | WF9: `Actual: <33.20508075686758>` |
| M-09c-as: T side from the world left normal | **red** | WF5: `Expected: an object with length of <2>` |

These match the implementer's excerpts exactly.

### Gates (`CI=true`, at `54eab37`, which includes the other tasks' commits on the branch)

| Gate | Result |
|---|---|
| App `flutter test` | `+1097: All tests passed!` (the same count as the implementer's) |
| `flutter analyze` | `No issues found!` |
| `dart format --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 |
| Worktree | Clean apart from the `analysis_options.yaml` that pub rewrote (not committed) |
