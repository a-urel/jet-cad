# Plan 03 — final fix wave: report

Implementer: Claude Opus 5.5. Worktree `.claude/worktrees/plan-03-grips-and-transform`,
branch `plan-03/grips-and-transform`, from HEAD `136af89`.

## Commits

| sha | subject |
|---|---|
| `722904b` | test(selection_overlay): pin grip draw positions, the rotation disc and the circle reshape preview (M-03bh, M-03bi, M-03bj) |
| `0cac4f4` | fix(select_tool): shift pressed or released mid-drag re-targets at once (M-03bl) |
| `509b9f3` | docs(grips): qualify rigidTransformLeaf's theta = 0 claim for a height-only text |
| `fe432ba` | docs: Plan 03 final fix wave -- 68 mutants, branch map, fix branches |

Every commit carries `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
(checked with `git log --format=%(trailers:key=Co-Authored-By,valueonly) 136af89..HEAD`).
`git status --short` is empty at the end. No `analysis_options.yaml` was rewritten.
The ledger was not archived.

## A. Code and tests — what was done

**A1 (M-03bh).** P2 (`grips are one drawRawPoints per colour … each at its grip
(invariant 6, M-03v, M-03aq, M-03bh)`) now asserts every drawn pair in the
stretch list, then the move list, equals `screenOf(camera, g.x, g.y)` for the
corresponding `rig.grips.grips` entries (non-move in list order, then move),
within 1e-3 px, for 10 grips.

**Finding while doing it (important):** under `gripCamera` the mutant is
*exactly equivalent*. `rotation(0.35).multiply(scale(1.1, -1.1))` gives
`b = sin*1.1` and `c = (-sin)*(-1.1)`, bit-identical; a y-flipped rotation is a
reflection, whose linear part is symmetric. That is why the reviewer saw it
survive, and why a test at `gripCamera` alone cannot kill it. So
`gripCamera` gained `bool flipY = true` (default unchanged, no existing caller
touched), and the P2 check loops over `flipY: true` and `flipY: false`. The
RED below shows the flipped iteration passing and the unflipped one failing.

**A2 (M-03bi).** P4 (`… the rotation grip still is, at its centre (M-03ad,
M-03bi)`) asserts the single `drawCircle`'s centre equals
`rotationGripOf(box, m).centre` (1e-9) and its radius is `4.0` (spec D6: an
8 px disc).

**A3 (M-03bj).** New test `a circle reshape preview's centre is rebased by
origin too (M-03bj)`: radius-grip (q = 0) reshape of `s.circle` under
`gripCamera`; the preview path's bounds (a full oval's bounds are tight) have
centre `centre − origin` and width/height `2·newRadius`, within 1e-3; asserts
the origin is non-zero and the radius really changed.

**A4 (M-03bk).** New test `hovering from one grip to another of the same
object repaints once (spec D5; M-03bk)` in `select_tool_drag_test.dart`: a
selected line, hover its start grip, then its end grip; same cursor
(`precise`), same object hover (`k(s.line)`); `grips.hot` changes and the tool
notifies exactly once for the second move.

**A5 (M-03bl, production).** `SelectTool.onKey` now begins:

```dart
if (_drag != null &&
    event is! KeyRepeatEvent &&
    (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight)) {
  _lastShift = event is KeyDownEvent;
  _onCamera();
}
```

`_onCamera` is the existing "re-target from `_lastScreen` with `_lastShift`,
then notify" path, so a later camera change also sees the fresh shift. The
existing D5 branch still consumes the key-down; key-ups still return
`ignored`. `_drag != null` limits it to move/rotate/reshape (a band has no
drag and only reads shift at release). I chose the event type over
`HardwareKeyboard.instance.isShiftPressed`, because the unit tests pass
synthetic events straight to `onKey` and never reach `HardwareKeyboard`.
New test `shift pressed or released mid-drag re-targets at once, with no
pointer move (spec D8; M-03bl)`: body move 40 right / 7 up; shift key-down
with no move makes `f == 0.0` exactly, keeps `e`, notifies once; shift key-up
restores `f`, notifies again.

**A6.** `grips.dart` doc: "θ = 0 leaves every stored scalar bit for bit. The
exception is a height-only text: it gains a rotation scalar, so even a
translation writes a `0` it did not store."

**A7.** `SelectTool.onPointerExit` doc: "The host (`InteractionLayer`) never
forwards an exit while a pointer is captured, so this cancel is unreachable
mid-drag (02's amended rule)." Confirmed against `interaction_layer.dart`
`_onExit` (`if (_activePointer != -1) return;`).

## TDD and mutant evidence (real output)

Backups under `.superpowers/sdd/2026-09-23-grips-and-transform/mutation-backups/`
(`selection_overlay.dart.M-03bh`, `.M-03bi`, `select_tool.dart.M-03bj`,
`.M-03bk`, `.M-03bl`, `grip_drag.dart.read-peek`). Each restore was `cp` back
then `diff <backup> <file>`, which printed nothing (`restored: diff clean`).

GREEN, overlay file before any mutant: `CI=true flutter test test/selection_overlay_grips_test.dart`
→ `00:00 +9: All tests passed!`, exit 0.

**M-03bh** — `selection_overlay.dart:246` `final x = m.a * g.x + m.c * g.y + m.e;` → `… + m.b * g.y …`
```
00:00 +1 -1: grips are one drawRawPoints per colour at 10 grips and at 300, and the hot grip one more, each at its grip (invariant 6, M-03v, M-03aq, M-03bh) [E]
  Expected: a numeric value within <0.001> of <352.1063766754032>
    Actual: <2615.23193359375>
     Which:  differs by <2263.125556918347>
  flipY false, grip 0, x
  test/selection_overlay_grips_test.dart 161:9        main.<fn>
00:00 +8 -1: Some tests failed.
exit 1
```
restored: diff clean.

**M-03bi** — `selection_overlay.dart:275` `canvas.drawCircle(g.centre, …)` → `canvas.drawCircle(g.anchor, …)`
```
00:00 +3 -1: no leaf grips are drawn under a geometry denial; the rotation grip still is, at its centre (M-03ad, M-03bi) [E]
  Expected: a numeric value within <1e-9> of <60.13388887667952>
    Actual: <84.13388887667952>
     Which:  differs by <24.0>
  test/selection_overlay_grips_test.dart 234:5        main.<fn>
00:00 +8 -1: Some tests failed.
exit 1
```
restored: diff clean.

**M-03bj** — `select_tool.dart:767` `center: Offset(c[0] - ox, c[1] - oy)` → `center: Offset(c[0], c[1])`
```
00:00 +7 -1: a circle reshape preview's centre is rebased by origin too (M-03bj) [E]
  Expected: a numeric value within <0.001> of <132.0>
    Actual: <7300.0>
     Which:  differs by <7168.0>
  test/selection_overlay_grips_test.dart 378:5        main.<fn>
00:00 +8 -1: Some tests failed.
exit 1
```
restored: diff clean. GREEN after the three: `00:00 +9: All tests passed!`, exit 0.

**A5 RED before the fix** (test written first, production untouched):
`CI=true flutter test test/select_tool_drag_test.dart`
```
00:00 +2 -1: shift pressed or released mid-drag re-targets at once, with no pointer move (spec D8; M-03bl) [E]
  Expected: <0.0>
    Actual: <7.0>
  test/select_tool_drag_test.dart 147:5               main.<fn>
00:00 +22 -1: Some tests failed.
exit 1
```
Expected: the key-down was swallowed, so `f` stayed at the unconstrained 7.
GREEN with the fix: `00:00 +23: All tests passed!`, exit 0.

**M-03bk** — `select_tool.dart:199` `if (cursor == _cursor && !hotChanged) return;` → `if (cursor == _cursor) return;`
```
00:00 +1 -1: hovering from one grip to another of the same object repaints once (spec D5; M-03bk) [E]
  Expected: <1>
    Actual: <0>
  only the hot grip changed, and the overlay must repaint it
  test/select_tool_drag_test.dart 116:5               main.<fn>
00:00 +22 -1: Some tests failed.
exit 1
```
restored: diff clean.

**M-03bl** — `select_tool.dart:551` delete `_onCamera();` in the shift branch (the `_lastShift` write stays)
```
00:00 +2 -1: shift pressed or released mid-drag re-targets at once, with no pointer move (spec D8; M-03bl) [E]
  Expected: <0.0>
    Actual: <7.0>
  ortho in world axes: the minor axis is pinned to the base
  test/select_tool_drag_test.dart 147:5               main.<fn>
00:00 +22 -1: Some tests failed.
exit 1
```
restored: diff clean.

**read → peek (equivalent)** — `grip_drag.dart:102` `document.geometry.read(…)` → `document.geometry.peek(…)`.
`CI=true flutter test test/grip_drag_test.dart test/select_tool_drag_test.dart` → `00:00 +34: All tests passed!`, exit 0.
Whole render suite under the mutant, `CI=true flutter test` → `00:12 +854 ~1 -5: Some tests failed.`, exit 1, the
five `[E]` lines being exactly `text ladder rung 1..5 (RenderBackend.canvas)`. SURVIVED, equivalent by construction
(`GeometryStore.replace` and `remove` install fresh buffers; nothing writes stored buffers in place).
restored: diff clean.

Final-review tally: 6 exercised, 5 killed, 1 equivalent. Overall 68 exercised: 65 killed, 1 survived (M-03e), 2 equivalent.

## Gate lines (on HEAD `509b9f3`, the last code commit; `fe432ba` is docs-only)

Run one package at a time, each command's exit code captured; `git status --short` empty before and after.

`packages/jet_cad_2d`:
```
00:03 +890: All tests passed!
[dart test exit 0]
Analyzing jet_cad_2d...
No issues found!
[dart analyze exit 0]
Formatted 130 files (0 changed) in 0.23 seconds.
[dart format exit 0]
```

`packages/jet_cad_2d_flutter`:
```
00:12 +854 ~1 -5: Some tests failed.
Failing tests:
  …/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  …/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  …/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  …/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  …/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
[flutter test exit 1]
No issues found! (ran in 1.4s)
[flutter analyze exit 0]
Formatted 159 files (0 changed) in 0.30 seconds.
[dart format exit 0]
```
(Paths shortened here only; printed in full under the worktree.) 854 = 851 + 3 new tests; only the five standing goldens fail.

`apps/dev_harness_2d`:
```
00:19 +82: All tests passed!
[flutter test exit 0]
No issues found! (ran in 1.0s)
[flutter analyze exit 0]
Formatted 22 files (0 changed) in 0.05 seconds.
[dart format exit 0]
```

`apps/floor_planner`:
```
00:01 +26: All tests passed!
[flutter test exit 0]
No issues found! (ran in 0.9s)
[flutter analyze exit 0]
Formatted 8 files (0 changed) in 0.03 seconds.
[dart format exit 0]
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.1MB)
[build macos exit 0]
✓ Built build/web
[build web exit 0]
```

## B. Docs — what was done

- **B1** STATUS "Branch and worktree map": the three worktrees, verified by
  `git worktree list` (main `e376ced`; `focused-nightingale-510bd1` at `8385753`
  [fix/page-copywith-num]; `hungry-haibt-cf67c0` at `776f201`
  [fix/root-transform-identity]; this worktree) and `git log --oneline -1`
  of each branch; cut points by `git merge-base main <branch>` (`e376ced`,
  `c09b747`). Merge order is the human's; whichever merges second resolves
  the doc conflict. I also ran `git merge-tree --write-tree --name-only HEAD
  fix/root-transform-identity` (writes no refs): it reports a content
  conflict in `STATUS.md` only; the spec auto-merges. STATUS says so.
  `fix/page-copywith-num` touches only `page_component.dart` and its test,
  which this branch never touched.
- **B2** STATUS debt (both lines), STATUS "Resume here", and the results
  note's Debt now say "committed on `<branch>` at `<sha>`, not merged".
- **B3** STATUS Plan 04 paragraph: "The branch is NOT merged." → "The branch
  was merged afterwards, at `e4e3f80`." (`e4e3f80` = "Merge: Plan 04 -- page,
  grid and rulers", an ancestor of `main`.) Nothing else rewritten.
- **B4** Mutation log head: 68 exercised, 65 killed, 1 survived (M-03e), 2
  equivalent, with the arithmetic shown; the Task 10 account below it left as
  it was. The read → peek mutant was fired (above), so equivalent = 2 and
  exercised = 68.
- **B5** Results note: the barrel-order debt line dropped (verified: the
  engine barrel `lib/jet_cad_2d.dart` passes `sort -c`); the residual
  paragraph labelled "Derived reasoning, not pasted output"; the preview
  cross's four `Offset`s per selected point per frame added as named debt
  ("Named by the final review"), and in STATUS's debt list.
- **B6** Full per-mutant entries in the log (new section "Final-review
  mutants"); a spec Testing paragraph appended ("Amended at execution (Plan
  03, 2026-09-23), final fix wave", with a five-row table and the flipY
  rationale), nothing rewritten; results note tally, criterion 13 (and 11,
  12, 14, 15 witnesses/counts) match the log exactly.
- Also: results note gets the fix wave's gate run, Rulings F-a/F-b, and
  "Files the final fix wave touched"; the Task 6/7/8 deferred minors this
  wave closed are moved to "Closed by a later task"; STATUS header, Plan 03
  section, task table, measured table and resume point updated (854, 68).

## Files changed

- `packages/jet_cad_2d_flutter/test/selection_overlay_grips_test.dart`
- `packages/jet_cad_2d_flutter/test/support/grip_fixture.dart`
- `packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart`
- `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`
- `packages/jet_cad_2d/lib/src/document/grips.dart`
- `STATUS.md`, `docs/superpowers/notes/2026-09-23-plan-03-results.md`,
  `docs/superpowers/notes/plan-03-mutation-log.md`,
  `docs/superpowers/specs/2026-09-23-grips-and-transform-design.md`

## Deviations from the brief

- A1: the brief's assertion alone cannot kill M-03bh under `gripCamera`
  (exact equivalence, `b == c`). Smallest change: an optional `flipY`
  parameter on `gripCamera` (default `true`) and a second iteration of the P2
  check under `flipY: false`.
- A5: used the event type (`event is KeyDownEvent`) rather than
  `HardwareKeyboard.instance.isShiftPressed`, so the synthetic-event unit
  test exercises it; see concern 2.
- B5: "both barrels are alphabetical now" is true of the engine barrel (the
  one Task 1's debt line meant). The render barrel is **not** sorted as a
  whole (`vertices_draw_sink.dart` at line 8; the commented
  `gpu/gpu_facade.dart` `show` export heads the `gpu/` block), but that
  predates Plan 03, which only added four lines in sorted position. The
  note says this.

## Self-review

- Every new/extended assertion goes red under its named mutant (pasted);
  the flipY=false iteration is necessary, not decorative.
- No production change beyond A5 and two doc comments; `_onCamera` reused
  rather than a new helper (minimal).
- Formatting and analyzer clean; `unused_*` not triggered.

## Concerns

1. **Degenerate fixture, wider than M-03bh.** Because `gripCamera`'s linear
   part is symmetric (`b == c` bit for bit), *every* `m.b`/`m.c`
   transposition in render-layer projection code is invisible to tests that
   use only `gripCamera`: `GripCache.hitTest`, `rotationGripOf` /
   `hitsRotationGrip`, the overlay's `_hotPoint`, `_drawPointCross`, and the
   `_paintPreview` composition. I only fixed the one the brief named
   (the stretch/move projection in `_paintGrips`). Worth a follow-up sweep
   with `gripCamera(flipY: false)`.
2. A5 edge case: with both shift keys held, releasing one sets
   `_lastShift = false` until the next pointer move (which carries the true
   modifier state). Harmless and self-correcting; `HardwareKeyboard` would
   fix it but is not reachable from the unit tests as written.
