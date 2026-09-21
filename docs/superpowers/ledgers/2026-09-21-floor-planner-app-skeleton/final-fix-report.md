# Plan 01 — final fix wave: five review findings, five commits

**Branch:** `plan-01/app-skeleton`, worktree `.claude/worktrees/plan-01-app-skeleton`.
**Starting head:** `531998a`. **Ending head:** `29b75cd`, five commits,
`531998a..29b75cd`.

---

## Finding 1 (Important) — the gate row contradicted its evidence

**What changed:** Reworded criterion 11's verdict in two places from an
unqualified "all eleven gate commands exit 0" to "PASS with one recorded
exception": ten commands exit 0; `jet_cad_2d_flutter`'s `flutter test` exits
1 on the five pre-existing `text_ladder_golden_test.dart` failures, per the
baseline ruling (golden drift from 2026-08-24, SDK 3.47.2), and on nothing
else.

- `docs/superpowers/notes/2026-09-21-plan-01-results.md` — exit-gate row 11.
- `STATUS.md` — the "Exit gate: 11 of 12" paragraph (the "eleven green gate
  commands" phrase).

**Evidence:** a wording fix, no test to run red/green. Verified by re-reading
both files after the edit and confirming the phrase no longer claims all
eleven commands are green while the pasted Task 9 transcript (unchanged,
still in the ledger) shows `+702 ~1 -5: Some tests failed` for that one
command.

**Commit:** `89c6842` — `docs: criterion 11 names its one non-zero exit
instead of claiming none`.

---

## Finding 2 (Important) — a horizontal-only wheel notch zoomed out

**What changed:** `packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart`,
`_onSignal`'s `ScrollSignalAction.zoom` case: added
`if (event.scrollDelta.dy == 0) return;` before the `zoomAt` call, with the
two-line comment the finding specified. The pan arm was left unchanged (it
already pans correctly by `-scrollDelta` on a horizontal delta).

**Witness:** appended to `camera_gesture_signal_test.dart`'s
`'mouse-kind scroll, no modifier'` group —
`'wheelZooms: a horizontal-only notch does nothing'`, sending
`Offset(120, 0)` and asserting `camera.value.worldToScreenMatrix` stays
`same`.

**RED** (before the guard), `CI=true flutter test test/camera_gesture_signal_test.dart`:

```
Expected: same instance as Transform2:<Transform2(3.8, 0.0, 0.0, -3.8, -3790.0, 7845.0)>
  Actual: Transform2:<Transform2(3.454545454545454, 0.0, 0.0, -3.454545454545454,
-3439.090909090909, 7152.727272727273)>
...
00:00 +3 -1: mouse-kind scroll, no modifier wheelZooms: a horizontal-only notch does nothing [E]
```

**GREEN** (after the guard): `00:00 +13: All tests passed!`

**Mutant M-01r** (delete the guard) — `cp` backup, run, restore:

```
Expected: same instance as Transform2:<Transform2(3.8, 0.0, 0.0, -3.8, -3790.0, 7845.0)>
  Actual: Transform2:<Transform2(3.454545454545454, 0.0, 0.0, -3.454545454545454,
-3439.090909090909, 7152.727272727273)>
...
00:00 +3 -1: mouse-kind scroll, no modifier wheelZooms: a horizontal-only notch does nothing [E]
  Test failed. See exception logs above.
00:00 +12 -1: Some tests failed.
```

Restored with `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart`;
`git status --short` clean apart from the intended two-file diff.

**Docs:** mutation log gets a new `## M-01r` section (full row shape:
diff hunk, command, pasted tail, restore, verdict) and the summary is now
17 fired / 17 killed / 0 survived / 1 equivalent, with a header sentence
noting M-01r was added by the final review. Spec gets the D3 amendment
paragraph after "The scroll-signal rule, in order." and M-01r appended to
the Named mutants list after M-01q.

**Commit:** `1f11496` — `fix(gestures): a horizontal-only wheel notch does
nothing on the zoom arm`.

---

## Finding 3 (Important) — Ruling 01-2's `_fitted` latch had no witness

**What changed:** no production code — `apps/floor_planner/lib/planner_view.dart`
was untouched (it is correct as written); a witness test was added to
`apps/floor_planner/test/planner_shell_test.dart`:
`'a resize after the first layout does not re-fit the camera'`. It fits the
app at 800x600, moves the camera (`zoomAt` + `panBy`), resizes the test
surface to 1100x750, and asserts the camera matrix is unchanged while the
canvas really did get a new size.

**GREEN first** (guard present), `CI=true flutter test test/planner_shell_test.dart`
from `apps/floor_planner`: `00:00 +4: All tests passed!`.

**Mutant M-01s** (delete the `if (!_fitted && …)` guard, keep the
assignment) — `cp` backup, run, restore:

```
Expected: same instance as Transform2:<Transform2(0.032299999999999995, 0.0, 0.0,
-0.032299999999999995, -545.7, 711.35)>
  Actual: Transform2:<Transform2(0.039357142857142854, 0.0, 0.0, -0.039357142857142854,
-457.7857142857142, 844.9642857142857)>
...
00:00 +3 -1: a resize after the first layout does not re-fit the camera [E]
  Test failed. See exception logs above.
00:00 +3 -1: Some tests failed.
```

Restored with `cp /tmp/mut_planner.bak lib/planner_view.dart`;
`git status --short` clean apart from the intended test-file and
mutation-log changes.

**Docs:** mutation log gets `## M-01s — no _fitted latch (app)` (full row
shape) and the summary is now 18 fired / 18 killed / 0 survived /
1 equivalent.

**Commit:** `3573415` — `test(floor_planner): a resize after the first
layout does not re-fit the camera`.

---

## Finding 4 (Minor, folded in) — the unbounded lower early return fired at scale <= 1e-9

**What changed:** `packages/jet_cad_2d_flutter/lib/src/camera_controller.dart`,
`zoomAt`'s `else if (f < 1.0)` branch:
`if (_tolerance.compare(current, minScale) <= 0) return;` →
`if (minScale > 0.0 && _tolerance.compare(current, minScale) <= 0) return;`,
with the one-line comment "With no lower bound there is nothing to rest on."

**Witness:** appended to the `'CameraController bounds'` group in
`test/camera_controller_test.dart` — `'unbounded, a camera already below the
tolerance still zooms out'`, an unbounded camera at scale `1e-10`, `zoomAt`
by `0.5`, expects `5e-11`.

**RED** (before the fix), `CI=true flutter test test/camera_controller_test.dart`:

```
00:00 +17 -1: CameraController bounds unbounded, a camera already below the tolerance still zooms out [E]
  Expected: a numeric value within <1e-20> of <5e-11>
    Actual: <1e-10>
     Which:  differs by <5e-11>
```

**GREEN** (after the fix): `00:00 +18: All tests passed!`

**Commit:** `81b5223` — `fix(camera): an unbounded camera below the
tolerance still zooms out`.

---

## Finding 5 (Minor, folded in) — the button pan used the global delta

**What changed:** `camera_gesture_detector.dart`, `_onMove`:
`widget.camera.panBy(event.delta)` → `widget.camera.panBy(event.localDelta)`,
matching the trackpad path's `localPanDelta`.

**Evidence:** `CI=true flutter test test/camera_gesture_button_test.dart`
from `packages/jet_cad_2d_flutter`: `00:00 +7: All tests passed!` — green
unchanged, as expected under the test's untransformed ancestor (`event.delta`
and `event.localDelta` coincide there).

**Commit:** `29b75cd` — `fix(gestures): the button pan uses the local delta
like the trackpad path`.

---

## Final gates (all six, pasted)

### `packages/jet_cad_2d_flutter`

**`CI=true flutter test`** — same five golden failures, no other (704 total,
+2 over the prior 702 for this package's two new witnesses, M-01r's
horizontal-notch test and the unbounded-zoom test):

```
00:13 +704 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

**`flutter analyze`:**

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.5s)
```

**`dart format --output=none --set-exit-if-changed .`:**

```
Formatted 122 files (0 changed) in 0.26 seconds.
```
(exit 0)

### `apps/floor_planner`

**`CI=true flutter test`:**

```
00:00 +8: All tests passed!
```

**`flutter analyze`:**

```
Analyzing floor_planner...
No issues found! (ran in 1.0s)
```

**`dart format --output=none --set-exit-if-changed .`:**

```
Formatted 5 files (0 changed) in 0.02 seconds.
```
(exit 0)

`git status --short` after the sixth gate: clean (empty output).

---

## Files changed (across all five commits)

- `STATUS.md`
- `docs/superpowers/notes/2026-09-21-plan-01-results.md`
- `docs/superpowers/notes/plan-01-mutation-log.md`
- `docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md`
- `packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart`
- `packages/jet_cad_2d_flutter/lib/src/camera_controller.dart`
- `packages/jet_cad_2d_flutter/test/camera_gesture_signal_test.dart`
- `packages/jet_cad_2d_flutter/test/camera_controller_test.dart`
- `apps/floor_planner/test/planner_shell_test.dart`

`apps/dev_harness_2d`, `packages/jet_cad_2d`, and `draft_canvas.dart` were
not touched, per instruction. No `analysis_options.yaml` was rewritten or
committed at any point; `git status --short` was checked and clean before
every commit.

## Concerns

- None found beyond what the review already flagged. Criterion 12 (a
  human's look on macOS and in two browser families) remains OWED, as
  recorded before this fix wave and unaffected by it — this task did not
  attempt to discharge it and has no display to do so from.
- This fix wave adds two more entries to the "Deferred" list's spirit (not
  literally appended, since the task did not ask for it): no test isolates
  the tolerance-tie boundary at `minScale == 0.0` exactly at the tolerance
  band edge beyond the one point (`1e-10`) the M-04 witness checks; left as
  the finding specified, not expanded.
