# Task 11 report — the allocation invariants, and the greps

## What I implemented

This task produces no code. I ran the two allocation-invariant gates
unchanged, ran the seven prescribed greps from the worktree root, and
appended a "## Invariants and greps" section to
`docs/superpowers/notes/plan-03-mutation-log.md` recording every command and
its real output, then committed.

## Step 1 — the two allocation gates

```
$ cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
00:00 +0: loading test/invariants/query_allocation_test.dart
00:00 +0: (setUpAll)
00:00 +0: forEachInRect does not allocate in steady state
00:01 +1: forEachInstanceInRect does not allocate in steady state
00:01 +2: pickInto does not allocate in steady state, three instances deep
00:02 +3: snapInto does not allocate in steady state, three instances deep
00:02 +4: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +5: (tearDownAll)
00:02 +5: All tests passed!
```
Exit 0, 5 tests, all passed.

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
Resolving dependencies in `.../plan-03-grips-and-transform`...
Downloading packages...
  (version-outdated notices, no changes)
Got dependencies in `.../plan-03-grips-and-transform`!
10 packages have newer versions incompatible with dependency constraints.
00:00 +0: loading .../test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=64ms
00:00 +3: All tests passed!
```
Exit 0, 3 tests, all passed. `flutter pub get` ran implicitly (this worktree's
package cache needed resolving); `git status --short` immediately afterward
showed a clean tree, so no `analysis_options.yaml` was touched and nothing
needed to be checked out.

Both invariants pass unchanged, satisfying invariant 5.

## Step 2 — the greps (run from the worktree root)

1. Invariants' tests unedited:
   ```
   $ git diff --stat main..HEAD -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants
   ```
   No output. Matches expectation (empty).

2. Frame path untouched:
   ```
   $ git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d/lib/src/index/spatial_index.dart \
     packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart \
     packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
   ```
   No output. Matches expectation (empty). Per the dispatch note,
   `interaction_layer.dart` (changed in Task 7 for the cursor mirror) is
   intentionally not in this list — it is not a frame-path file for the
   canvas.

3. Engine pure Dart:
   ```
   $ grep -n "dart:ui\|package:flutter" packages/jet_cad_2d/lib/src/document/grips.dart packages/jet_cad_2d/lib/src/index/drag_snap.dart
   ```
   No matches (exit 1). Matches expectation (nothing).

4. `grip_drag.dart` never reads the root's transform:
   ```
   $ grep -n "rootHandle\|accumulatedTransform" packages/jet_cad_2d_flutter/lib/src/grip_drag.dart
   ```
   No matches (exit 1). Matches expectation (nothing).

5. `select_tool.dart` / `grip_cache.dart` never read `accumulatedTransform`:
   ```
   $ grep -n "accumulatedTransform" packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/lib/src/grip_cache.dart
   ```
   No matches (exit 1). Matches expectation (nothing).

6. Grip paint path — no per-grip `Rect`/`Offset`, `drawRawPoints` only:
   ```
   $ awk '/void _paintGrips/,/^  }$/' packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart | grep -n "drawRect\|Rect\.\|drawRawPoints"
   24:        canvas.drawRawPoints(PointMode.points, _stretchPoints, _gripPaint);
   27:        canvas.drawRawPoints(PointMode.points, _movePoints, _gripMovePaint);
   34:        canvas.drawRawPoints(PointMode.points, _hotPoint, _gripHotPaint);
   ```
   Three `drawRawPoints`, no `Rect`. Matches expectation exactly.

7. `SnapResult.point` never held except via `setFrom`:
   ```
   $ grep -n "scratch.point" packages/jet_cad_2d/lib/src/index/drag_snap.dart
   70:  //    because the next query rewrites `scratch.point` (invariant 7).
   74:      out.point.setFrom(scratch.point);
   ```
   **Deviation from the brief's annotation** ("one line:
   `out.point.setFrom(scratch.point)`"): two lines matched, not one. Line 70
   is a comment explaining the invariant (it names `scratch.point` in prose);
   line 74 is the only line of code that touches it, via `setFrom`. Read in
   context (`packages/jet_cad_2d/lib/src/index/drag_snap.dart:68-78`), the
   invariant holds — `scratch.point` is copied immediately into `out.point`
   and never retained past the next query. This is a grep-pattern false
   positive (the comment also contains the substring), not a code issue. No
   production code changed.

8. `Transform2` never compared with `==` in the new drag tests:
   ```
   $ grep -n "transform ==\|transform, same\|\.transform)\s*;\s*$" packages/jet_cad_2d_flutter/test/grip_drag_test.dart packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart
   packages/jet_cad_2d_flutter/test/grip_drag_test.dart:102:    final want = Transform2.translation(37.5, -18.75).multiply(g0.transform);
   ```
   **Deviation from the brief's annotation** ("nothing"): one line matched.
   It is a false positive of the text pattern, not an equality comparison.
   Line 102 (`packages/jet_cad_2d_flutter/test/grip_drag_test.dart:91-114`)
   builds the expected transform via `.multiply(g0.transform)`; the actual
   comparison two lines later destructures both transforms into their six
   components (`a`..`f`) and asserts each with `closeTo(..., 1e-9)` — a
   tolerance comparison, never `Transform2 ==`. No production code changed.

Neither deviation (7 or 8) is a real hit against the invariant the grep was
written to catch — both are artifacts of a text pattern also matching a
comment and a `.multiply(...)` call respectively. I read both files in
context to confirm compliance before writing this report. No production or
test code was changed as a result.

## Files changed

- `docs/superpowers/notes/plan-03-mutation-log.md` — appended the
  "## Invariants and greps" section with the full command transcript above.

## Deviations from the brief

- Commit trailer: the brief's literal commit message text says
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Per house rule 7
  (Ruling T2-a, attribution must be truthful) and the session's own
  attribution instructions, I used `Co-Authored-By: Claude Sonnet 5
  <noreply@anthropic.com>` instead, naming the model that actually wrote this
  commit. Everything else in the commit message and body is verbatim from
  the brief.
- Grep outputs for checks 7 and 8 differ from the brief's inline annotations
  (see above) but the underlying invariants hold; recorded in full rather
  than silently reconciled to match the brief's expected text.

## Self-review

- Confirmed `git status --short` was clean both before staging and that only
  the one intended file was staged/committed (`git status --short` output
  above; `git diff` for greps 1–2 also confirms no stray changes on the
  branch).
- No `analysis_options.yaml` was rewritten by `flutter pub get`.
- No code was written or modified in this task; nothing to run
  `dart format` or the four-line gate on beyond what's already green from
  prior tasks (this task's own two commands were run directly and are the
  content of the report, not a new gate).
- Verified both grep deviations by reading the surrounding source before
  concluding they are non-issues.

## Concerns

None that block. The two grep-text deviations (drag_snap.dart comment line,
grip_drag_test.dart `.multiply` line) are documented above and are, on
inspection, compliant with the invariants they were meant to check.
