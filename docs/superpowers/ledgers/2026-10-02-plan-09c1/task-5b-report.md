# Task 5b report: review fixes for Task 5

Implementer: a fresh agent, 2026-10-02. Worktree `.worktrees/plan-09c1`, branch `plan-09c/wall-attach`.

## Commit
- `274c780` test(app): pin the ghost's placement at press and release
- Files: `apps/floor_planner/test/symbols/symbol_place_tool_test.dart` (+54) and `apps/floor_planner/lib/symbols/symbol_ghost.dart` (a doc comment only). Only these two paths were staged, both by explicit path. No `analysis_options.yaml` was staged.

## Changes
1. **Finding 1 (major).** I added one tool test in the "the ghost" group: "touch: the press and the release each set the placement (spec D5, F-6): with no hover the ghost is drawn at the press, and after a release away from the drag it sits at the release point".
   - The fixture is non-degenerate. It uses the rig's camera at 0.05 px/mm, pointers far from the origin, the chair's off-origin base point and a rebase origin far from zero. The placement is turned with Shift+R and mirrored with M (q=3, mirrored), armed idle before any pointer event. It uses touch pointer 21 and no hover.
   - After a press at `pA`, the test checks four things:
     - `ghostPlacement`'s six doubles equal `placementTransform(at: gridOf(pA), base, 3, true)` exactly.
     - One paint gives `computations == 1`, and `matrix.placement` is identical to `ghostPlacement`.
     - The matrix maps the base point to `gridOf(pA) - origin`.
     - The linear part is `[0, 1 | 1, 0]`.
   - After a drag to `pMid`, the placement is at `gridOf(pMid)`, and a paint gives `computations == 2`.
   - The release at `pB` comes at a point no move reported. The test then checks four things:
     - The placement equals the transform at `gridOf(pB)`.
     - The placed instance's transform equals the same transform.
     - A paint gives `computations == 3`, with the identity check.
     - The base point maps to `gridOf(pB) - origin`.
2. **Finding 2 (note).** `symbol_ghost.dart`'s `GhostMatrix` doc comment now says the tool computes `P` "on pointer and key events (Task 8 will add camera events)". The comment is rewrapped.

## Gates (app, `apps/floor_planner`, `CI=true`, PATH with /root/flutter/bin)
- `flutter test`: `09:50 +1097: All tests passed!`, exit 0. This run used the shared working tree, so it includes the concurrent Tasks 3b, 4b and 10's uncommitted edits.
- The tool test file alone: `+32: All tests passed!`. That is 31 tests before this task, plus 1.
- `flutter analyze`: `No issues found! (ran in 4.3s)`, exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 180 files (0 changed)`, exit 0.

## Mutants (fired on `test/symbols/symbol_place_tool_test.dart`)
Method: a `cp` backup, a scripted exact-once deletion, the run, a `cp` back, then `diff`. `diff` exited 0 both times.

| Mutant | Change | Result | Excerpt (real output) |
|---|---|---|---|
| The press does not resync | `_syncPlacement()` deleted from `onPointerDown` (symbol_place_tool.dart:182) | **red**, exit 1, `+31 -1` | `Expected: [0.0, 1.0, 1.0, 0.0, 79825.3, -35500.7]  Actual: [0.0, 1.0, 1.0, 0.0, -300.0, -300.0]`. The placement is stale from the key events, at the unresolved point. |
| The release does not resync | `_syncPlacement()` deleted from `onPointerUp` (:207) | **red**, exit 1, `+31 -1` | `Expected: [0.0, 1.0, 1.0, 0.0, 81075.3, -37200.7]  Actual: [0.0, 1.0, 1.0, 0.0, 80450.3, -36325.7]`. The ghost was left at the drag point. |

The only red test in each run was the new test.

## Scratch
`/tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task5b/` holds the raw output: `mut.py`, `mut_down.txt`, `mut_up.txt`, `app_test.txt`, `analyze.txt` and `format.txt`.
