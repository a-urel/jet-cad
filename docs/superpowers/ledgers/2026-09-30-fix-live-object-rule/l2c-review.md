# L2c review: independent review of 3ede604

**Verdict: Approved.** No findings. R1 from the L2b review is closed.

- **Worktree:** the detached review worktree `…/fix-live-object-rule-review`, at HEAD `3ede604`, parent `9a4df2a`.
- **Nothing committed or pushed.** `git status` before and after shows only the standing pub-get rewrite of `packages/jet_cad/analysis_options.yaml`.
- **Scratch files:** the driver is `…/scratchpad/l2cr-mut.py` (L2b's `l2br-mut.py`, retargeted to the `l2cr-` prefix, with the backup `cp` done inside the driver before each mutation). The logs are `l2cr-log-<M>.txt` and `l2cr-gate-*.txt`.

## The commit is test-only

- `git show --stat`: one file, `apps/floor_planner/test/wall_grips_test.dart`, +30 −4.
- No `lib`, no `packages/`.
- Both trailers are present.

## EG10's new premises are real

- **The moved fixture:** the dimension's fixed ends go from `plan(400, 2200)`–`plan(2600, 2200)` to `plan(4200, 1500)`–`plan(6600, 1500)`. They are still set in the rotated and translated group frame `at`. The stray, its premises and the group handle `0x1A2B` are unchanged.
- **`dimLines(doc, dim).first` is the dimension line:** `dimension.dart` l.203–207 emits `q0–q1` first, then the extension lines and the slashes.
- **The crossing:** `t` is asserted in (0.05, 0.95) of that segment, and `hit` is asserted within 1e-6 of the stray's offset-0 line.
- **The query point reaches the dimension's drawn children:** the premise runs the walk's own first query. It is the same `Aabb2` of `±dimAttach.linear` with `QueryFilter.rendering()` as `attachCandidates` l.119–125, and it asserts that the owners are exactly `{dim}`.
- **Proof that the owner check now decides the result:** under M-R-narrowAttach and M-R-attachOwner, the walk takes `dim` through `_onALine` into `_wallPointsOf` and throws there. Both runs below show this.
- **The kept assertion:** `isNot(contains(dim))` is kept.
- **The new control:** `attachCandidates` at A's corner contains `wa` and `wb`, and it passes on the clean tree.

## Nothing else in EG10 was weakened

- **The only thing that moved is the dimension's geometry.** No other assertion in EG10 depends on where the dimension sits:
  - the band point and the `aMid` control use the stray and A;
  - the drag is at the corner, to `plan(3500, −400)`;
  - the grips count is still 3 and `ObjectGrips` still equals it;
  - the panel is selected by key;
  - `canon` compares the whole document.
- **Every mutant L2b fired on `wall_grips_test` is still red on EG10, or redder.** See the table below.

## Mutants I fired (`CI=true flutter test --no-pub test/wall_grips_test.dart`)

- **Baseline:** exit 0, `00:04 +10: All tests passed!`.
- **Restores:** every restore diff exited 0.

"Narrowed" means a live root `GroupNode` carrying `WallParams` and not `OpeningParams`, sorted by handle.

| Mutant | Change | Result | Red test, line |
|---|---|---|---|
| **M-R-narrowAttach** | `dimension_attach.dart` l.124 owner check narrowed | `+9 -1` (survived at L2b) | EG10 `wall_grips_test.dart:845`: `Null check operator used on a null value` at `_wallPointsOf` (`dimension_attach.dart:159:37`), through `attachCandidates` (`:147:11`) |
| **M-RV-narrowBands** | `wall_bands` cache loop narrowed | `+9 -1` | EG10 `:818`: `Expected: null  Actual: <6699>` |
| M-RV-narrowAdapter | `wallsInDocument`'s walls narrowed | `+9 -1` | EG10 `:810`: `Expected: [2600, 3900]  Actual: [2600, 3900, 6699]` |
| M-R-attachOwner | l.124 becomes `get<WallParams>(owner) != null` | `+8 -2` | EG9 `:698` and **now also EG10 `:845`** (null check in `_wallPointsOf`). At L2b only EG9 was red |
| M-R-attachThick | `thickestWall` over every `withComponent<WallParams>` | `+8 -2` | EG9 `:695` and EG10 `:826`: `Actual: <400.0>` |
| M-R-hostCheck | `wallsInDocument` host check becomes `get<WallParams> != null` | `+7 -3` | EG6 `:553`, EG9 `:679` and EG10 `:809` |

The implementer's two named results reproduce exactly: narrowAttach is red at `:845` and narrowBands at `:818`.

## Gates (clean tree, `export PATH=/root/flutter/bin:$PATH`, `CI=true`, `apps/floor_planner`)

| Gate | Exit | Output |
|---|---|---|
| `flutter test --no-pub` | 0 | `02:30 +514: All tests passed!` |
| `flutter analyze` | 0 | `No issues found! (ran in 1.6s)` |
| `dart format --output=none --set-exit-if-changed .` | 0 | `Formatted 104 files (0 changed) in 0.75 seconds.` |

I did not re-run the packages, because the commit contains no `packages/` file.
