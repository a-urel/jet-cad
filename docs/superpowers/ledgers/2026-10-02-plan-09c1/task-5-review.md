# Task 5 review: the generalised placement transform (spec D5)

Reviewer: an independent agent, 2026-10-02. I worked in a detached worktree, `.worktrees/plan-09c1-review-t5`, at `bb39637`.
Diff reviewed: `git diff e73621f..bb39637`. It touches 6 app files only, and nothing under `packages/`.

## Verdict: Needs fixes (1 major, 0 blocking)

The code is correct. Specifically:
- The generalised transform matches spec D5 and is bitwise identical to the old quarter-turn body. My own differential checked this.
- `placeSymbol(transform:)` stores the transform verbatim.
- The ghost matrix compares exactly.
- No `Transform2` is built in a paint.

Every named mutant goes red. Two of the cache's six refresh sites are not covered by any test, and both mutants on them survive (finding 1). The fix is one tool test.

## Findings

1. **major: the press and the release recompute the cached placement, and no test checks either.**
   `apps/floor_planner/lib/symbols/symbol_place_tool.dart:182` (`_syncPlacement()` in `onPointerDown`) and `:207` (in `onPointerUp`).
   - **What the task changed.** Before Task 5, the paint read `_at.point` directly, so it could not go stale. Task 5 adds a cache, `_placement`, that has to be refreshed at each of six event sites. The new tool test covers hover, R, M and re-arm only.
   - **Evidence.** I deleted each call in turn and ran the tool test file:
     - press call deleted: `+31: All tests passed!`, exit 0;
     - release call deleted: `+31: All tests passed!`, exit 0.
   - **Effect of the press mutant.** A touch press with no hover leaves `_placement == null`, so `paintWorldOverlay` draws nothing. Meanwhile `ghostVisible` reports true, and so does 09b's "touch: … shown at the press" assertion. On touch, the ghost would not appear at the press, against 09b F-6.
   - **Effect of the release mutant.** After a release away from the last drag, the ghost stays at the drag point while the instance lands at the release point. On touch, with no further hover, it stays there.
   - **Fix.** Add one tool test:
     1. touch press at `pA` with no hover;
     2. assert `ghostPlacement` equals `placementTransform(at: gridOf(pA), …)`, and that a paint computes once;
     3. drag to `pMid`, release at `pB`;
     4. assert `ghostPlacement` equals the transform at `gridOf(pB)`.
   - **Proof that the fix works.** I wrote exactly this as a scratch test, then removed it.
     - It passes on `bb39637`: `+1: All tests passed!`.
     - With the press call deleted it goes red: `Expected: [1.0, 0.0, 0.0, 1.0, 79825.3, -35500.7]  Actual: <null>`.
     - With the release call deleted it goes red: `Expected: [1.0, 0.0, 0.0, 1.0, 81075.3, -37200.7]  Actual: [1.0, 0.0, 0.0, 1.0, 80450.3, -36325.7]`.
   - **Why it matters now.** Task 7 will compute the attached transform in these same sync sites, so this gap would widen.

2. **note: a doc comment claims camera events that do not exist yet.**
   `apps/floor_planner/lib/symbols/symbol_ghost.dart:101-102` says the tool "computes it on pointer, key and camera events". No camera listener exists until Task 8 (D12). The tool's own field comment (`symbol_place_tool.dart:77-78`) correctly says "pointer, key and arm events". No fix is needed if Task 8 lands as planned. Otherwise, say "arm" instead of "camera".

3. **note: the commit still builds its transform from the inputs, as the implementer reported.**
   `_place` (`symbol_place_tool.dart:292-296`) builds its transform from `at`, the turns and the mirror, not from `_placement`. The two use the same function on the same inputs, and the release now refreshes `_placement` too, so they agree today. Task 7 replaces this path with the attached transform.

## Spec and plan, line by line

| Requirement | Code | Holds? |
|---|---|---|
| `rotation: (cos, sin)?`, mutually exclusive with `quarterTurns`, an error thrown in release too | `symbol_placer.dart:53-56`: a plain `if`/`throw ArgumentError` (not an `assert`), so it runs in every mode | yes |
| The quarter-turn form goes through the rotation form at the exact table | `:57` `rotation ?? _quarterTurn(quarterTurns ?? 0)`; the table at `:69-74`; one chain at `:58-61` | yes |
| `-0.0` normalised in both forms | `:62-64` is one `clean` applied to all six doubles, after the shared chain | yes |
| `placeSymbol(transform:)` is used verbatim | `:157-163` `transform ?? placementTransform(...)`. `Transform2` is immutable (all fields `final`, `transform2.dart:29`), so storing the caller's object cannot alias | yes |
| `GhostMatrix.update(placement:)` compares six doubles exactly; `computations` counts | `symbol_ghost.dart:124-138`: `==` on a–f; an equal placement returns early and keeps the earlier object; otherwise it stores, counts and writes the linear part | yes |
| No `Transform2` built in a paint (W-15) | `paintWorldOverlay` (`:318-338`) reads `_placement` and passes it on. `symbol_ghost.dart` no longer imports the placer | yes |
| The placement is computed on events | `_syncPlacement` runs at `:137` (arm/disarm), `:182` (down), `:194` (move, after the cancelled-press early return), `:207` (up), and `:251` (R, Shift+R, M, after the state change; a repeat does nothing). Cancel and pointer exit change only visibility, which is correct. No camera event yet (Task 8) | yes, but :182 and :207 are untested (finding 1) |
| 09b ghost tests on the new signature with the same counts (P-6) | Only the `update(...)` call lines differ. Every `expect(g.computations, N)` line is unchanged. The removed lines are all old argument lists: I grepped every `-` line in the test diff | yes |

## My own differential (the quarter-turn form against the old body)

I wrote a scratch test (`test/zz_review5_diff_test.dart`, removed afterwards). It copies the pre-Task-5 body from `git show e73621f` verbatim. It then compares the bit patterns (`ByteData.getInt64`) of three things:
- the old body;
- the new form with `quarterTurns`;
- the new form with `rotation: table[q mod 4]`.

The inputs were 300,000 random cases: q in −20..20; `at` and the base drawn from ±0.0, ±1e300, ±5e-324, the infinities, NaN, `maxFinite`, uniform ±1e5, log-uniform 1e±300, integers and small values; mirrored or not. I added 10,000 more cases with `quarterTurns` omitted, against the old default.

Result: `REVIEW5 compared 1860000 doubles, old-vs-new mismatches 0, quarter-vs-rotation-table mismatches 0`. The implementer's claim (1,200,000 doubles, 0 mismatches) holds.

## Gates (I re-ran them)

All commands ran in `apps/floor_planner` with `export PATH=/root/flutter/bin:$PATH` and the `CI=true` prefix, after `CI=true flutter pub get` at the worktree root.

| Gate | Mine | Implementer's |
|---|---|---|
| `flutter test` | `05:42 +1084: All tests passed!`, exit 0 | `+1084: All tests passed!` |
| `flutter analyze` | `No issues found! (ran in 5.9s)` | same |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 | same |
| `flutter build web --release` | `✓ Built build/web`, exit 0 | same |

- **New tests:** the diff adds exactly 9 `test(` calls and removes none (P20–P24, 3 ghost tests, 1 tool test).
- **Engine and render layer:** the diff contains no file under `packages/`, so I did not re-run them. This matches the brief.

## Mutants (I re-fired them)

For each mutant I made a `cp` backup, applied the mutation with a scripted exact-once replacement, ran the named files, copied the backup back and ran `diff`. `diff` exited 0 every time. Afterwards `git status` showed only `packages/jet_cad/analysis_options.yaml`, which pub get rewrites (uncommitted).

| Mutant | Change | Result | Red tests / excerpt |
|---|---|---|---|
| **M-09c-n** | `clean(v) => v` | **red** | P3, P14, P23 (`Expected: false Actual: <true>`) |
| **M-09c-o** | `if (false && p != null && …)` | **red** | ghost "P is computed only…", "equal placements…one ulp…", "-0.0 and 0.0…"; tool "computed on events…" (`Expected: <1> Actual: <4>`) |
| **`transform` ignored** | `transform: placementTransform(…)` | **red** | P24 (`Actual: [0.0, -1.0, -1.0, 0.0, 3733.5, -1322.25]`) |
| Transform2 built in the paint (implementer's) | `_matrix.update(placement: placementTransform(...))` | **red** | tool "computed on events…" (`identical`: `Expected: true Actual: <false>`) |
| Tolerance instead of `==` (implementer's) | `(placement.a - p.a).abs() <= 1e-12` | **red** | ghost "one ulp…" (`Expected: <2> Actual: <1>`) |
| Re-arm does not resync (implementer's) | `_syncPlacement()` dropped from `_onArmed` | **red** | tool "computed on events…" |
| *Mine:* M-09c-n on the rotation form only | `clean(v) => rotation != null ? v : (v == 0 ? 0.0 : v)` | **red** | P23 alone, which shows P23 is the test owed to the generalised form |
| *Mine:* `e` not compared | `placement.e == p.e &&` dropped | **red** | ghost "P is computed only…", "base point's x alone…", "one ulp…" |
| *Mine:* `assert` instead of `throw` | `assert(!(quarterTurns != null && rotation != null))` | **red** | P21 (`threw _AssertionError`, not `ArgumentError`) |
| *Mine:* transposed rotation | `Transform2(cos, -sin, sin, cos, 0, 0)` | **red** | P1, P4, P20 |
| *Mine:* press does not resync | `_syncPlacement()` dropped from `onPointerDown` | **survives** | `+31: All tests passed!` (finding 1) |
| *Mine:* release does not resync | `_syncPlacement()` dropped from `onPointerUp` | **survives** | `+31: All tests passed!` (finding 1) |

## Fixtures (P-2)

- **P20:** a 30° and a −112.5° vector, `far = (100000.25, −70000.75)`, the sofa's off-origin base, mirrored and not. The matrix is compared exactly, and the leaf endpoints against an independent formula. Not degenerate.
- **P22:** `far`, base (900, 400), q from −2 to 5, mirrored and not.
- **P23:** M-09c-n's named axis-aligned exception, with (±0.0, ±1) and (±1, −0.0).
- **P24:** a mirrored 30° transform with a different base point, built far from the origin. The `at`, turns and mirror passed alongside are shown to differ.
- **Ghost tests:** 30°, the toilet, `far` against a non-zero rebase origin, mirrored and not. The one-ulp test goes through `nextUp` via `ByteData`; it handles negative components correctly by decreasing the magnitude.
- **"-0.0 equals 0.0" test:** axis-aligned near the origin. It is stated as a rule, not a mutant test, which is acceptable. A bit-pattern comparison (for example `compareTo`) would still turn it red.
- **Tool test:** camera 0.05 px/mm, pointers far from the origin. It uses quarter turns only, which is the tool's only input before Task 7.

No degenerate fixture, apart from the missing press/release case (finding 1).

## Invariants and hygiene

- **Allocation invariant tests:** both `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and the render one are untouched; the diff has no `packages/` file.
- **`analysis_options.yaml`:** none is committed (`git show --stat bb39637` lists 6 app files).
- **Frame path:** a paint now calls `update` with the stored object. With equal doubles it returns early, so nothing is allocated. Draw order is unaffected.
- **Purity:**
  - `wall_attach.dart` imports `jet_cad_2d`, `vector_math` and `../parametric/*`.
  - `symbol_box.dart` imports `dart:math`, `jet_cad_2d`, `vector_math` and `symbol_library.dart`, which imports `dart:convert`, `dart:typed_data`, `jet_cad_2d`, `catalog.dart` and `symbol_component.dart`.
  - Neither file imports Flutter or `dart:ui`. Neither is touched by this diff.
  - `symbol_placer.dart` stays Flutter-free.
- **Exact versus tolerance:** the ghost's recompute test is `==`, which is right for stored values. `-0.0 == 0.0` is accepted, and the placer guarantees no `-0.0` anyway.

## Rulings

- **R-C5-1 (`at` stays required alongside `transform`): accept.** It is documented and pinned by P24.
- **R-C5-2 (an equal update keeps the earlier object): accept.** "Recomputes nothing" implies it, and the W-15 identity check depends on it.
- **R-C5-3 (no unit-length check): accept.** D4 step 3 says "exactly those doubles". A debug assert under `Tolerance` would be harmless but is not required. Task 6 must pass a normalised `t`.
- **R-C5-4 (`ghostPlacement` and `ghostMatrix` as `@visibleForTesting`): accept.**
- **R-C5-5 (P-6 moved to Task 5 after C-0): accept.**

## Scratch

`/tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review5/` holds `app_test.txt`, `mut.sh` and `mut_*.txt`, the raw output of every run above.

## Re-review of 5b (274c780)

Same reviewer. I ran this in the review worktree `.worktrees/plan-09c1-review-t5`, detached at `274c780`, after `CI=true flutter pub get`. I reviewed only that commit's own diff, `git diff 274c780~1..274c780`: `symbol_place_tool_test.dart` (+54) and the doc comment in `symbol_ghost.dart`.

### Verdict: Approved

- **Finding 1 (major): closed.** The new tool test is "touch: the press and the release each set the placement …".
  - Its fixture is not degenerate: camera 0.05 px/mm, pointers far from the origin, the chair's off-origin base point, and a rebase origin far from zero.
  - The placement is turned and mirrored (q=3, mirrored, set by Shift+R and M before any pointer event). It uses touch pointer 21 with no hover, and the release comes at a point no move reported.
  - It compares the six doubles exactly against `placementTransform`, at the press, the drag and the release.
  - It also checks the placed instance's transform, the paint counts 1/2/3, the `identical` check, and where the matrix puts the base point.
  - Every mutant on the press and release sites now goes red (table below).
- **Note 2: closed.** The comment now reads "on pointer and key events (Task 8 will add camera events)". It omits re-arm events, which is too minor to fix.

### Gates (rerun at 274c780, `apps/floor_planner`, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

| Gate | Result |
|---|---|
| `flutter test` | `07:32 +1096: All tests passed!`, exit 0 |
| `flutter analyze` | `No issues found! (ran in 4.6s)` |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 |

I counted 1096 at the commit. The implementer's 1097 came from a shared working tree that held other tasks' uncommitted edits, which the report itself says, so the two counts do not conflict.

### Mutants (run on `test/symbols/symbol_place_tool_test.dart`)

Each mutant was applied the same way: a `cp` backup, the change, the run, then the backup copied back and checked with `diff`. `diff` exited 0 every time. Afterwards `git status` showed only the `analysis_options.yaml` that pub get rewrites.

| Mutant | Result | Excerpt |
|---|---|---|
| `_syncPlacement()` deleted from `onPointerDown` (formerly surviving) | **red**, `+31 -1`, only the new test | `Expected: [0.0, 1.0, 1.0, 0.0, 79825.3, -35500.7]  Actual: [0.0, 1.0, 1.0, 0.0, -300.0, -300.0]` |
| `_syncPlacement()` deleted from `onPointerUp` (formerly surviving) | **red**, `+31 -1`, only the new test | `Expected: [0.0, 1.0, 1.0, 0.0, 81075.3, -37200.7]  Actual: [0.0, 1.0, 1.0, 0.0, 80450.3, -36325.7]` |
| *Mine:* in `onPointerUp`, `_syncPlacement()` moved before `_resolve` (a stale point) | **red**, `+31 -1`, only the new test | same as the line above |

Raw output is in `scratchpad/review5/app_test_5b.txt` and `mut_B_*.txt`.
