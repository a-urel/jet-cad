# Task 10b report: a touch double tap ends a chain

Status: DONE (one concern below).

Commits: e42a1307 (feature, tests, guide, changelog), plus a test-strengthening commit (DT4).

## Route
Enter ends a chain via `PlacementTool.onKey` (jet_cad_2d_flutter), which calls `finish`.
New `TouchDoubleTapFinish` (packages/jet_cad_2d_plan/lib/src/canvas/touch_double_tap.dart),
a raw `Listener` (no gesture arena) wrapped around the canvas in `PlanCanvasView`. It sends
the active tool a synthetic Enter KeyDownEvent when `tool.isMidShape`: the very same path, so
every chain tool (Wall, Polyline) is covered. No engine package touched.

## Rule (pinned in DT1, DT5; host-guide sentence)
Double tap = two touch taps within 300 ms and 40 px, each shorter than 300 ms, no second finger.
The first tap of the pair is a deliberate point and stays; the chain ends there, the second adds
nothing (result equals Enter after the first tap). Mechanism: the second tap's down ends the
chain before the layer routes it (so it cannot add a wall even 30 px away, DT5); the layer then
starts a lone first point, which the second tap's lift ends again.
Mouse/pen: unchanged (touch only; a desktop double click keeps meaning two clicks, DT4).
Two contacts less than 20 ms apart are not a double tap (settle): needed so existing tests
that tap twice with zero elapsed time (wall_tool_test WT5) stay green and unedited.

## Tests (packages/jet_cad_2d_integration/test/phone/double_tap_test.dart; off-origin, rotated camera)
DT1 A,B,C + double tap -> 2 walls, tool idle, new tap starts a new chain unconnected to C.
DT2 single tap after 350 ms pause does not end. DT3 Enter still ends. DT4 mouse double click
(80 ms apart) does not end. DT5 taps 30 px apart add no wall. PH1 now ends its wall by a double
tap at B (assertions kept, plus chain-ended assertion).

## Mutations (each run on committed code, reverted, git diff --quiet)
- M1 drop the down-time finish -> DT5 red.
- M2 drop the lift-time finish -> DT1 and DT5 red.
- M3 let mouse count -> DT4 red (first version of DT4 had no pause and stayed green; fixed).
- M4 drop the 20 ms settle -> existing WT5 (wall_tool_test) red.

## Gates (real last lines)
- plan: `flutter test --enable-vmservice`: +1630 All tests passed; analyze: No issues found; format 0 changed.
- integration: +240 All tests passed (incl. wall_tool_test, long press/pan tests untouched); analyze clean; format 0 changed.
- check_guide: all 35 code blocks are in the host probe. check_kit_deps: none names the plan library.

## Docs
host-guide.md section on drawers: the "wall chain ends by picking another tool" bullet replaced.
CHANGELOG line in jet_cad_2d_plan (integration has no changelog).

## Concerns
- The second tap's down ends the chain before knowing it is a clean tap: a double-tap-and-drag
  (second finger-down that then pans) has already ended the chain.
- Two tools: rapid taps (under 300 ms) within 40 px of each other while a chain is pending are
  read as a double tap, so a deliberately tiny wall placed that fast cannot be drawn.
