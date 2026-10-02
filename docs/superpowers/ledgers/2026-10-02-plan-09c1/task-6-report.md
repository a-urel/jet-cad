# Task 6 report: attachToWall, neighbours, WallFaces (spec D4)

Implementer, plan 09c-1, Task 6. Worktree `.worktrees/plan-09c1-t6`, branch `wip/09c1-t6` (cut from `54eab37`). **Status: DONE.** One commit, not pushed. The controller cherry-picks it.

## Commit
- `e188ef1037a1b279f2c503a2972accaf7322d505` `feat(app): attach a symbol to a wall face`. Its parent is `54eab37`.
- It carries the plan's message and both trailers.
- An earlier local commit, `de99feb`, was amended into it. That commit was never pushed, and this one replaces it.

## Files (3 files, +1136 −5)
- `apps/floor_planner/lib/symbols/wall_attach.dart`
  - New typedefs: `FaceNeighbour = ({double lo, double hi, Handle instance})` and `WallAttachment = ({Transform2 transform, Vector2 q, FaceRun run})`.
  - New functions: `attachToWall(...)`, the private `_ranksBefore` and the public `isOrthonormal(Transform2)`.
  - New class `WallFaces`.
  - New imports: `../parametric/wall_bands.dart`, `symbol_box.dart`, `symbol_component.dart` and `symbol_placer.dart` (`show placementTransform`).
  - P-4 check: the transitive import closure is 20 files, with no `package:flutter` and no `dart:ui` (checked by script).
- `apps/floor_planner/test/support/wall_attach_fixture.dart`
  - `teeScene` gains `double stemThickness = teeThickStem`. With the default, every existing scene is identical.
- `apps/floor_planner/test/symbols/wall_attach_test.dart` (new): 16 tests, WA1–WA16.

## What was built
- **`attachToWall(runs, box, p, captureWorld, {required mirrored, required neighbours, required edgeCaptureWorld, Handle? exclude})`** follows D4 steps 1–5:
  - **Step 1, candidates.** A run is a candidate when `−w/2 ≤ s ≤ capture` and `−capture ≤ u ≤ L + capture`. The winner is ranked by:
    1. `|s|`;
    2. the distance from `u` to `[0, L]`;
    3. the lower wall handle;
    4. the left face;
    5. the lower `a·t`.

    Keys 1 and 2 are compared within `wallJoin.linear` (R-C6-2).
  - **Step 2.** The winner must satisfy `W ≤ L + wallJoin.linear`; otherwise the result is null.
  - **Step 3.** The rotation is `(t.x, t.y)`.
  - **Step 4, edge snaps.** The left side can snap to `0` or to a neighbour's `hi`; the right side to `L` or to a neighbour's `lo`. Each must be within `edgeCaptureWorld`. The smallest shift wins, and a tie goes to the smaller `u`. The clamp is `[W/2, L − W/2]` when `W < L`; otherwise `u = L/2`.
  - **Step 5.** The transform is `placementTransform(at: q, basePoint: ((l+r)/2, back), rotation: (t.x, t.y), mirrored)`, with `q = a + u·t`.
  - The only allocations are the result, `q`, the base point and `placementTransform`'s own. Nothing is allocated per run, and `backCentre` is never called.
- **Neighbours** (built in `WallFaces._neighboursAlong`, once per generation). A neighbour must be:
  - a root-level instance (from the root's `childNodesOf`);
  - one whose definition carries a `SymbolComponent` and has a box;
  - accepted by `FilterEvaluator(doc).acceptsNode(h, const QueryFilter.picking())`. This is the engine's own picking rule: node visibility up the chain, plus the instance layer's visible and unlocked flags.
  - `isOrthonormal(accumulatedTransform)`, using `Tolerance.standard.linear`;
  - placed with both transformed back-edge ends within `wallJoin.linear` of the run's line;
  - placed with its transformed front-centre at `(f − a)·m > 0`;
  - overlapping `[0, L]` with its interval `[lo, hi]`, sorted from the two ends' `u`. The overlap test is closed: `hi ≥ 0 && lo ≤ L`.

  Each entry carries the instance's handle, so `exclude` (for 09c-2) is checked at query time.
- **`WallFaces(bands, {accept})`**
  - Public API: `runsOf(doc)`, `neighboursOf(doc)` (parallel to the runs), `boxOf(doc, definition)`, `attach(doc, box, p, capture, {mirrored, edgeCaptureWorld, exclude})` and `builds` (a rebuild counter).
  - Each call runs `bands.liveWalls(doc)`. It rebuilds only when the document is not the cached one or `bands.generation` moved.
  - A rebuild does three things: it computes the runs (`faceRunsOf(doc, h, accept:)` per live wall, ascending), clears the box memo, and recomputes the neighbours.
  - The box memo is a `Map<Handle, SymbolBox?>` over `boxOfDefinition`, and it keeps nulls.

## Tests (`test/symbols/wall_attach_test.dart`)
**Common setup.**
- Scale 0.2 px/mm: 1 px = 5 mm, capture = 80 mm, edge capture = 50 mm.
- Every scene is at 30° and −112.5° near (1e5, −7e4) unless noted.
- The two boxes are the toilet (0, 400, 0, 700) and `offBox` (37.5, 937.5, −120.25, 480.75).

**What `expectFlush` checks.** Each check is against the run's own `a`, `t` and `m`:
- both back-edge ends are within ≤ 1e-9 of the face line;
- the front is `D` into the room (to 1e-9);
- the back-centre lands on `q`, and `u` is correct;
- the linear part is exactly `[±t.x, ±t.y, −t.y, t.x]`;
- the local left side is at `u ∓ W/2`.

**The tests.**
- **WA1:** flush attach in 144 cases: 2 angles × 3 justifications × {plain, mirrored, scaled 1.5} groups × 2 faces × 2 boxes × mirrored or not.
- **WA2:** a pointer inside the body 5 mm short of the midline attaches to its own face; 5 mm past it attaches to the other face. This covers every justification and group.
- **WA3:** capture boundaries at `s = cap ± 1`, `u = −cap ± 1` and `u = L + cap ± 1`.
- **WA4 (the T tie):** a 60 mm stem (< 80 − 5), with stem turns 90, −90 and 70°.
  - The pointer is 1 px right of the stem and 2 mm off the host face. The premises are asserted: the lower piece is a candidate at the same `|s|`, and the stem's face is farther away. The upper piece wins.
  - A pointer in the middle of the cut gives the lower piece (the `a·t` key).
- **WA5 (M-09c-ah, −w variant):** a 300 mm stem, with capture 100 mm (0.16 px/mm).
  - The pointer is 90 mm into the host body on the butted half, 10 mm off the stem's centreline.
  - Premises: the far face lies in `[−w, −w/2)` and has a run at `p`'s `u`; both butted pieces are out of the `u` window; exactly one stem face is a candidate, with a larger `|s|` than the far face.
  - The stem's face wins. The test asserts the winning run, not null.
- **WA6:** edge snaps to the run's start and end on an L's inside face, and no snap 60 mm away. Mirrored and not.
- **WA7 (neighbour snaps).** The fixture is a toilet placed **mirrored** at u = 2000 (interval [1800, 2200], sort-dependent) and a toilet straddling the run start, [−360, 40].
  - The left side snaps to the neighbour's right end, and the right side to its left end.
  - `exclude` is passed over.
  - "Smallest shift wins": 15 to the corner toilet's 40 beats 25 to the run start.
  - The corner toilet, partly outside [0, L], is still a neighbour.
- **WA8 (neighbour membership).** A T scene; only the flush toilet on the lower piece is that piece's neighbour. Each of these is excluded:
  - a toilet on the upper piece, outside [0, L] (this one is the upper piece's only neighbour);
  - a back-to-back toilet on the far face (this one is the far face's only neighbour);
  - one turned to face the wall;
  - one 300 mm into the room;
  - one on a hidden layer;
  - one on a locked layer;
  - one scaled 1.25;
  - one nested in a group;
  - a plain block with no `SymbolComponent`.
- **WA9 (`WallFaces` keyed on the generation):**
  - Five `attach` calls and the repeated getters cause no rebuild, and the lists are identical.
  - Each of these rebuilds once and is seen: a new wall (after `pumpEventQueue`), a placed symbol as a neighbour, a removed cistern leaf (the box's back goes 700 → 500, so the memo was cleared), `bands.invalidate()`, and another document.
- **WA10:** the host predicate is asked for each live wall; a refused wall has no runs.
- **WA11:** a 700 mm wall gives null for the 900 box and attaches the 400 toilet.
- **WA12 (the niche, M-09c-au):**
  - A real run's copy with `L = W − 2e-10`. The test asserts `L < W` first, then `q == a + t·(L/2)` bitwise, for three pointers × mirrored or not.
  - `L = W − 2e-6` gives null.
- **WA13:** the clamp at both ends, beyond the edge capture (mirrored group).
- **WA14 (the M-09c-n exception):** axis-aligned walls in all four directions, with the group not turned. The premise is that all 8 runs have a zero in `t`. No component of the transform is `-0.0`.
- **WA15 (handle key):** two collinear walls joined straight. The premise is that the runs meet on one line at the joint. A pointer at the joint attaches to the lower handle.
- **WA16 (side key):** both faces are made candidates on the midline by widening each copied run by 1e-7. The left face wins, in either run order.

## Gates
| Gate | Result |
|---|---|
| App `flutter test` | `+1113: All tests passed!` (`06:29 +1113`). The plan-tip baseline was 1,097, plus 16 new tests. |
| App `flutter analyze` | `No issues found!` |
| App `dart format --output=none --set-exit-if-changed .` | `Formatted 181 files (0 changed)`, exit 0 |
| `flutter build web --release` | `✓ Built build/web`, exit 0 |
| Engine, render, dev_harness | Not re-run: `git diff 54eab37 -- packages` shows only the unstaged `analysis_options.yaml` that `pub get` rewrote, so they are unchanged. |
| `analysis_options.yaml` | Not staged. |
| Allocation invariant tests | Untouched. |

## Mutants
**Method.** Each mutant follows the same steps:
1. Back up the file with `cp` into `scratchpad/task6/`.
2. Mutate it and run `flutter test test/symbols/wall_attach_test.dart`.
3. Restore it with `cp` and check that `diff` exits 0.

The script is `scratchpad/task6/mut.py`. Logs are `mut_<id>.log`, and the summaries are `final1.out`, `final2.out` and `final3.out` (the final code). Every final run printed `exit=1 diff=0`. The file is `wall_attach.dart` unless noted. Line numbers are from before the dead `-0.0` lines were removed, so they are about −2 after line 288.

| Id | Site | Change | Red | Excerpt |
|---|---|---|---|---|
| M-09c-b | :326 basePoint | `box.back` → `box.front` | WA1,2,4,6,7,11,13 | `Expected: <= 1e-9 Actual: <700.0000000000041>` "30.0° … back end 0.0 on the face" |
| M-09c-c | :327 | `rotation: (t.x, t.y)` → `quarterTurns: 0` | WA1,2,4,6,7,11,13 | `Actual: <99.9999999999975>` "back end 0.0 on the face" |
| M-09c-d | :267 | skip every non-left run | WA1–4,11–15 | `Expected: not null Actual: <null>` "30.0° left plain group right W 400.0" |
| M-09c-h | :311-312 | neighbour snaps removed | WA7 | `within 1e-9 of 2650.0 Actual: 2684.9999999999923` "left side: u" |
| M-09c-i | :317 | clamp removed | WA4, WA13 | `within 1e-9 of 200.0 Actual: 5.000000000003168` |
| M-09c-j | :328 | `mirrored: false` | WA1, WA6, WA7 | the linear part, sign of `t` |
| M-09c-m | :286 | `W ≤ L` test removed | WA11, WA12 | `Expected: null Actual: (q: …, run: … L: 700.0000000000078 …)` |
| M-09c-n (at the function) | `symbol_placer.dart` `clean` | `clean(v) => v` | WA14 | `Expected: false Actual: <true>` `t [-1.0,-0.0]: Transform2(-1.0, -0.0, 0.0, -1.0, …)` |
| M-09c-n (attachToWall's own normalisation) | :288-289 | normalisation removed | **survived, equivalent** | `+14: All tests passed!`. The lines were removed (R-C6-3). |
| M-09c-af | :341-342 | distance-to-`[0, L]` key removed | WA4 | "30.0° stem 90.0 left: run FaceRun(… L: 2470…), want FaceRun(… L: 1670…)" |
| M-09c-ah (−w) | :267 | `s < -w` | WA5 | `Expected: true Actual: <false>` "30.0° stem 90.0: FaceRun(18 right …)" (the far host face won) |
| M-09c-ah (0) | :267 | `s < 0` | WA2, WA5, WA16 | `Expected: not null Actual: <null>` "near half" |
| M-09c-aq | :488 | overlap condition dropped | WA8 | `Expected: [36] Actual: [36, 37]` "the lower piece" |
| M-09c-au | :315 | `if (true)` (a hand clamp, no `W ≥ L` case) | WA12 | `Expected: [103924.98002192109, …] Actual: [103924.980021921, …]` "q at exactly L/2" |
| WallFaces not keyed on generation | :436 | `identical(doc, _document)` only | WA9 | `Expected: an object with length of <4>`, actual 2 runs |
| extra: rebuild on every query | :436 | `if (false) return;` | WA7, WA9 | identity of run / `builds` |
| extra: box memo not cleared | :440 | `_boxes.clear()` removed | WA9 | `Expected: <500> Actual: <700.0>` |
| extra: neighbour interval unsorted | :495 | `(lo: u1, hi: u2)` | WA7 | `within 1e-7 of 1800 Actual: 2200.0000000000073` |
| extra: picking filter dropped | :466 | removed | WA8 | `Actual: [36, 41, 42]` |
| extra: `rendering()` filter (locked counts) | :466 | `QueryFilter.rendering()` | WA8 | `Actual: [36, 42]` |
| extra: lock-only filter (hidden counts) | :466 | `QueryFilter(visibleOnly: false, excludeLocked: true)` | WA8 | `Actual: [36, 41]` |
| extra: orthonormal test dropped | :470 | removed | WA8 | `Actual: [36, 43]` |
| extra: `SymbolComponent` test dropped | :463 | `&& false` | WA8 | `Actual: [36, 50]` |
| extra: front-side test dropped | :486 | `true` | WA8 | `Actual: [36, 39]` |
| extra: back-on-line test dropped | :484-485 | `true &&` | WA8 | `Actual: [36, 40]` |
| extra: all nodes, not root-level | :460 | `doc.tree.nodes` | WA8 | `Actual: [36, 46]` |
| extra: overlap as containment | :488 | `lo ≥ 0 && hi ≤ L` | WA7 | `Expected: equals [30, 31] unordered Actual: [30]` |
| extra: `exclude` ignored | :310 | removed | WA7 | `within 1e-9 of 2685.0 Actual: 2650.0000000000155` |
| extra: first snap wins | :298-300 | `if (!snapped)` | WA7 | `within 1e-9 of 490.0 Actual: 449.9999999999952` |
| extra: run-end snaps removed | :307-308 | removed | WA6 | `within 1e-9 of 450.0 Actual: 479.99999999999784` |
| extra: `s ≤ capture` dropped | :267 | removed | WA3 | `Expected: null Actual: (…)` |
| extra: `u` window dropped | :269 | removed | WA3, WA5 | `Expected: null Actual: (…)` |
| extra: `accept` not passed | :442 | removed | WA10 | `Expected: [18, 19] Actual: []` |
| extra: exact `|s|`/gap ties (tol 0) | :273 | `_ranksBefore(…, 0.0)` | WA4, WA15, WA16 | WA4's piece: L 2470 instead of 1670 |
| extra: handle key reversed | :343 | `>` | WA15 | "the lower handle (18) wins, got 19" |
| extra: side key reversed | :344 | `FaceSide.right` | WA16 | `Expected: true Actual: <false>` "30.0° plain group" |
| extra: `a·t` key reversed | :345 | `>` | WA4 | "the middle of the cut" |

## Proposed rulings
- **R-C6-1: the neighbours' shape.** `neighbours` is `List<List<FaceNeighbour>>`, parallel to `runs`, and an `ArgumentError` is thrown when the lengths differ.
  - Why: the plan's signature has a single list, but the run is not known until step 1.
  - `FaceNeighbour` carries the instance handle, and `attachToWall` takes `Handle? exclude`. The cached lists then serve every query without filtering, which keeps the query O(1) in allocation. This is the "exclude handle for 09c-2".
  - Cost if wrong: one parameter's shape.
- **R-C6-2: tie keys within a tolerance.** Step 1's `|s|` and distance keys are compared within `wallJoin.linear`.
  - Why: the two pieces of one face line give `s` equal only within rounding at 1e5. With exact comparison the distance key is unreachable: the "exact tie" mutant turns WA4, WA15 and WA16 red, because the wrong piece wins on noise.
  - The edge snap's "smallest shift" and its tie are compared exactly.
  - Cost if wrong: a different tolerance value.
- **R-C6-3: `-0.0` normalised only in `placementTransform`.** D4 step 3 says normalise; `placementTransform` (D5, Task 5) already cleans every stored component. A second normalisation in `attachToWall` was a provably equivalent mutant (it survived), so it was removed and the doc comment says where the normalisation happens.
  - M-09c-n at the function is fired at `placementTransform`'s `clean` and is killed by WA14.
  - Cost if wrong: two lines.
- **R-C6-4: an extra import.** `wall_attach.dart` imports `symbol_placer.dart` (`show placementTransform`), which is not in P-4's list. D4 step 5 requires that function, and the closure has no Flutter (20 files).
  - Cost: none.
- **R-C6-5: neighbour details.**
  - The overlap with `[0, L]` is closed: a neighbour touching an end counts. Containment is not required, and a straddling neighbour counts (WA7).
  - "Front on the room side" means the transformed front-centre has `(f − a)·m > 0`.
  - The picking rule is the engine's `FilterEvaluator.acceptsNode(…, QueryFilter.picking())`, which the app did not use before.
  - Cost if wrong: one comparison each.
- **R-C6-6: `WallFaces` API.**
  - `runsOf`, `neighboursOf` and `boxOf` take the document, and `attach(doc, …)` wraps `attachToWall`.
  - `builds` is a public counter so tests can see when the cache rebuilds; it is plain public, not `@visibleForTesting`.
  - The runs are concatenated over `liveWalls` in ascending order, each wall's left face then its right.
  - Cost: renames in Task 7.

## Found, not fixed / notes
- The edge-snap tie ("a tie to the smaller `u`") has no test. An exact tie in `|shift|` cannot be built from geometry at 1e5, where the `u` values carry rounding. The tie code is three tokens, and no named mutant covers it.
- `WallFaces._refresh` costs O(walls²) per rebuild, because `faceRunsOf` → `wallsInDocument` lists all walls per wall. Neighbours cost O(instances × runs). Both run only on a document change, never per pointer move, but a large plan pays on every edit.
- WA8's fixture also places an instance at the identity (the nested toilet's definition source). It lies nowhere near the wall and does not affect the assertions.

## Look hardest at
- **WA5's premises.** The −w mutant is killed only there. The stem's runs, the 100 mm capture and the 90/10 mm offsets are asserted, not assumed.
- **WA4 and R-C6-2.** The tolerance on the `|s|` key is what makes the distance key reachable at all.
- **The picking rule.** It uses the engine's `FilterEvaluator` per rebuild. It allocates a few maps on rebuild, which is fine, and none per query.
- **WA9's generation flow.** `liveWalls` is called on every query; delivery happens through `pumpEventQueue`.
