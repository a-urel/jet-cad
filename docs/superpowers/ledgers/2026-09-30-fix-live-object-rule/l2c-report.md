# L2c report: the L2b review's R1

**Commit:** `3ede604` on `fix/live-object-rule`, on top of `9a4df2a`. Not pushed.
- It touches one file, `apps/floor_planner/test/wall_grips_test.dart` (+30 −4). `lib` is unchanged.
- The controller's uncommitted `docs/` edits and the pub-get rewrite of `packages/jet_cad/analysis_options.yaml` are left as they were. Neither is staged.

## The EG10 change

**The fixture:** the dimension's fixed ends moved from `plan(400, 2200)`–`plan(2600, 2200)` to `plan(4200, 1500)`–`plan(6600, 1500)`.
- The stray keeps its old values: from the L's corner at 40° in the plan frame, 1800 long, 400 thick, left-justified.
- The dimension line now crosses the stray's offset-0 line beyond the stray's far end.
- Every other part of EG10 is unchanged and still passes: the band, the corner drag to `plan(3500, −400)`, the grips and the panel.

**The attach query:**
- `hit` is where the stray's offset-0 line (`ws.s` along `ws.d`) crosses the dimension line, `dimLines(doc, dim).first`. `dimLines` is imported from `support/dimension_fixture.dart` with `show`.
- Premise: the crossing parameter `t` lies in (0.05, 0.95) of the dimension line segment.
- Premise: `hit` lies within 1e-6 of the stray's line.
- Premise: the rendering query over the index's tight box (`hit ± dimAttach.linear`) finds exactly the owner set `{dim}`. This is the walk's own query. It also serves as the control that the query finds something real: it reaches the dimension's drawn children, and no wall's.
- Kept: `attachCandidates(doc, index, hit, …)` has no `dim` entry.
- New control: `attachCandidates` at A's corner, which is on the stray's line, contains `wa` and `wb`.

## Mutants

**Procedure:**
- The driver is `…/scratchpad/l2c-mut.py`. It is the reviewer's `l2br-mut.py` with the same mutation text and helper, retargeted to this worktree, and it copies each file to `l2c-bak-*` before mutating it.
- It asserts that the replaced text occurs exactly once, then runs `CI=true flutter test --no-pub test/wall_grips_test.dart`, then `cp`s the backup back and `diff`s it.
- **Both restore diffs exited 0.**
- The logs are `…/scratchpad/l2c-log-<M>.txt`.

| Mutant | Change | Result | Red test, line |
|---|---|---|---|
| **M-R-narrowAttach** | `dimension_attach.dart` l.124 owner check becomes `_narrowWalls(doc).contains(owner)` | `+9 -1` (was surviving) | EG10 `wall_grips_test.dart:845`, the `attachCandidates(doc, index, hit, …)` call: `Null check operator used on a null value` at `_wallPointsOf` (`dimension_attach.dart:159`), which is `wallsInDocument(doc, dim)!` |
| **M-RV-narrowBands** (re-fired) | `wall_bands` cache loop over `_narrowWalls(doc)` | `+9 -1` | EG10 `:818` `Expected: null  Actual: <6699>` |

## Gates (`export PATH=/root/flutter/bin:$PATH`, `CI=true`, `apps/floor_planner`, final tree)

| Gate | Exit | Output |
|---|---|---|
| `flutter test --no-pub` | 0 | `02:29 +514: All tests passed!` |
| `flutter analyze` | 0 | `No issues found! (ran in 1.5s)` |
| `dart format --output=none --set-exit-if-changed .` | 0 | `Formatted 104 files (0 changed)` |

- The transcripts are `…/scratchpad/l2c-gate-*.txt`.
- No `packages/` file is in the commit, so the packages were not re-run.
