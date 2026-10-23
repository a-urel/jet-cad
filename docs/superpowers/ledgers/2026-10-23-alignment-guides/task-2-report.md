# Task 2 report: MoveAdjuster seam

Status: DONE. Commit: see `git log -1` on claude/alignment-guides-50cacb ("feat(flutter): SelectTool.moveAdjuster seam").

## Implemented
- `MoveAdjuster` interface beside `MoveResolver`; `SelectTool({moveResolver, gates, moveAdjuster})` (exported via select_tool.dart's existing export).
- `_enter`: begin() before `_follow`, `changes.addListener(_onCamera)` (move drags only, tracked by `_adjusting`).
- `_follow` stores `_lastTouch`/`_lastAlt`; `_retarget` copies the chain point into reused `_adjusted`, calls `adjust(...)` (orthoBase = drag.base while Shift; objectSnapped = objectKind != null), then `drag.moveTo(_adjusted)`; `suppress()` when an attachment applies.
- `onKey`: Alt branch mirroring Shift (no repeat), sets `_lastAlt`, `_onCamera()`; key still consumed by the drag branch.
- `_endDrag`: removes listener and calls `end()` for move drags only. `paintOverlay`: adjuster.paint after `_paintGuide`, skipped when `_attached`.
- CHANGELOG line under Unreleased.

## TDD
RED: `flutter test test/select_tool_move_adjuster_test.dart` -> compile errors "Type 'MoveAdjuster' not found." and "No named parameter with the name 'moveAdjuster'."
GREEN: `+13: All tests passed!`

## Mutations (each reverted; real failing test names)
- moveTo(_dragPoint.point) kept -> `+3 -1: MA4 the committed move is the chain delta plus the adjustment [E]`
- orthoBase always passed -> `MA5 orthoBase is non-null only while Shift pins an axis [E]`
- suppress not called -> `MA11 a resolver that attaches suppresses the adjuster ... [E]`
- Alt key not re-targeting -> `MA8 Alt pressed or released with no pointer move re-adjusts [E]`
- end() skipped (covers cancel and release; both go through _endDrag) -> `MA1 ... [E]`, `MA2 end once on Escape-cancel ... [E]`
- paint not gated on _attached -> `MA11 [E]`
- _lastTouch not stored -> `MA7 [E]`, `MA10 [E]`
- changes listener never added -> `MA12 [E]`
- changes listener never removed: first survived (the leaked listener is inert, `_onCamera` guards on `_drag`); strengthened MA12 to assert `listened` false after release -> `MA12 ... [E] Expected: false Actual: <true>`

## Files
- packages/jet_cad_2d_flutter/lib/src/select_tool.dart
- packages/jet_cad_2d_flutter/test/select_tool_move_adjuster_test.dart (new)
- packages/jet_cad_2d_flutter/CHANGELOG.md

## Gate (packages/jet_cad_2d_flutter)
- flutter test: `+1470 ~1 -7` (baseline +1457 ~1 -7; +13 mine; the 7 are text_ladder_golden_test rungs)
- flutter analyze: `No issues found!`
- dart format: `Formatted 235 files (0 changed)`, exit 0
- No analysis_options.yaml staged; tree clean after commit.

## Concerns
- MA13's differential compares a null adjuster with a no-op adjuster (plus explicit expected values), not two plain SelectTools, which would be a tautology.
- Reshape/rotate tests run through GripRig with the tool swapped by `tools.activate`.
