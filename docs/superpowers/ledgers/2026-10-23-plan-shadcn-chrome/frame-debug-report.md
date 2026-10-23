# Frame-scheduling diagnosis (TF8 `nextFrame` premise)

Probe: packages/jet_cad_2d_plan/test/zz_probe/frame_probe_test.dart. No lib/ edits remain (git status: only `?? test/zz_probe/`).

## Q1. What happens between pump1 and pump2
Correction to the premise: ONE pump already draws the new colour.
```
premise pixel=0xffffff
sync after set: sched=true needsPaint=false
  [stream] CommandApplied phase=idle sched=true needsPaint=true   <- fires INSIDE pump1's flushMicrotasks, before the frame
Frame 11 (begin/end banner)
after pump1: sched=false needsPaint=false
pixel after ONE pump: 0xa6d6d1 (teal@.35 on white = 0xa6d6d1)
```
Chain: `setUnitColour` -> document `commands.changes` (broadcast StreamController, async, jet_cad_2d/lib/src/document/undo.dart:104-105) -> microtask -> plan_canvas.dart:268 listener `_documentChanged.bump()` -> painter's `repaint` Listenable -> `markNeedsPaint` on the layer -> `ensureVisualUpdate`. In a test the microtask runs in pump1's `FakeAsync.flushMicrotasks` (phase idle, before begin-frame), so pump1's own frame paints the colour. Nothing is "forced" by pump2: pump2 just repaints nothing. (So "fails with one pump, pixel differs by 89" does not reproduce; only the premise `hasScheduledFrame` after pump1 fails, because pump1 already consumed the frame.)

Who scheduled the frame visible synchronously right after `setUnitColour` (debugPrintScheduleFrameStacks): NOT the colour. `_runHostEdit` -> `_refreshFlags` (plan_controller.dart:1561 -> :2223) -> `_Flag._update` (plan_editor.dart:1403, the undo-enabled flag flips false->true) -> `ValueListenableBuilder.setState` of the toolbar undo button -> `ensureVisualUpdate`. Incidental, and only when canUndo/canRedo flips.

## Q2. Real app, no forced pumps
Loop "while hasScheduledFrame pump, max 10", Q2 probe (two variants):
```
idleFirst=false (no microtask flush, test-only artifact)
 set : sched right after=true   frames=1 pixel=0xa6d6d1 ok
 undo: sched right after=false  frames=0 pixel=0xa6d6d1 want 0xffffff  (stale ONLY because the test never ran the microtask)
 redo: sched right after=true   frames=1 pixel=0xa6d6d1 ok (a flag flipped)
idleFirst=true (await tester.idle() = what the event loop does before the next vsync)
 set : frames=1 pixel=0xa6d6d1 ok
 undo: sched right after=false, frames=1 pixel=0xffffff ok
 redo: sched right after=false, frames=1 pixel=0xa6d6d1 ok
```
In a real app the stream microtask always runs right after the host callback returns, calls markNeedsPaint -> ensureVisualUpdate, so a frame is scheduled and the colour reaches the screen. NOT stale. The only "no frame scheduled" window is synchronously inside the same turn, before the microtask.

## Q3. Before the shadcn migration?
Quiet-loop probe (`setUnitColour`, pump once, then count pumps while hasScheduledFrame):
- HEAD: sched after pump1 = false, extra frames 0.
- HEAD with 160ea980 plan_tool_palette.dart swapped in (restored with git checkout, status clean): same, false / 0. So the OLD PALETTE is not what kept frames alive.
- Whole tree at 160ea980 (git archive into scratchpad .../scratchpad/old, pub get, probe copied): sched after pump1 = TRUE and still true after 50 extra pumps; Ticker.scheduleTick reschedules every frame (stack: Ticker._tick -> scheduleTick during transientCallbacks). TF8 passes there. So before the migration some Material widget elsewhere in the editor chrome had a ticker that never completed under zero-duration pumps (I did not pin which one; the ticker providers present are Scaffold/Material/AnimatedTheme/IconButton/Tooltip etc.; the palette alone is ruled out). The premise passed vacuously, not because of the colour change. The product behaviour (microtask -> markNeedsPaint -> frame) is the same in both trees: pre-existing, not a regression.

## Q4. Cause and smallest fix
Not a product defect. The test helper's premise is wrong: `nextFrame` (test/service/paint/unit_fill_test.dart:445-450) checks `hasScheduledFrame` after a pump that has already delivered the async change and drawn its frame.
- Smallest fix, test-side: `await tester.idle();` (flush the stream microtask) in place of the first `await tester.pump()`, then keep `expect(hasScheduledFrame, isTrue)` and one `pump()`. Verified: idleFirst=true variant shows frames=1 and correct pixels for set/undo/redo (the premise holds after idle for undo/redo too; for set it already held synchronously).
- If a product change were wanted so a change schedules its own frame synchronously: make the stream sync (`StreamController<DocChange>.broadcast(sync: true)` at jet_cad_2d/lib/src/document/undo.dart:105) or call `SchedulerBinding.instance.ensureVisualUpdate()` from the plan_canvas.dart:268 listener's source; not recommended (sync streams re-enter mid-mutation; the async delivery is by design).
