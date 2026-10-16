# Task 4 report: O1 drag snap, O2 orientation row

Status: DONE_WITH_CONCERNS (O2 fixed; O1 reproduced as a real defect, fix is out of scope, test landed skipped).
Commit: f7833d42.

## O1: real, red, fix lives in the engine
- Test: packages/jet_cad_2d_plan/test/tools/drag_self_snap_test.dart. Sloped line off the origin, turned camera,
  page grid snap off, press 1/5 along the line, release 30 mm from its own old midpoint along the old line.
  Without the skip it fails: second endpoint coordinate expected 4281.83, got 4275.0 (the line landed with its
  press point on its own old midpoint).
- Cause: SelectTool._resolve (jet_cad_2d_flutter/lib/src/select_tool.dart:478) calls resolveDragPoint
  (jet_cad_2d/lib/src/index/drag_snap.dart:72), which runs index.snapInto over the whole SpatialIndex; no
  exclusion of the dragged objects exists. Fix needs an engine change (exclude set on snapInto/resolveDragPoint,
  zero-allocation preserved) which dispatch-notes forbid me to touch. The plan library's PlanMoveResolver already
  excludes the node for attachment queries; that is a different path.
- Landed with `skip:` naming the cause; removing the skip is the engine fix's acceptance test. Mutation for that fix:
  pass no exclusion again -> this test red.
- Not separately run: a unit (symbol instance) variant; same code path.

## O2: fixed
- Fix: plan_page_panel.dart, the two segment labels wrapped in FittedBox(scaleDown) + maxLines 1 (_oneLine).
  Words unchanged. Under the test font (Ahem) the old layout wrapped even "Portrait"; with real fonts it was
  "Landscape" at 1440 px.
- Test: test/panels/orientation_row_test.dart, en/de/tr x {panel 280 px, panel 240 px, PlanEditor at 1440x900
  (right column asserted 280)}; line count = RenderParagraph height / one-line height.
- Mutation: FittedBox replaced by Container -> 7 of 9 red (en/de at all three; tr passes at 280/240/editor
  because "Dikey"/"Yatay" are short). Reverted (git diff clean before commit).

## Gates
- plan: flutter test --enable-vmservice: "All tests passed!" (+1573 ~1 skipped, the O1 pin); flutter analyze:
  No issues found; dart format: 0 changed.
- integration (untouched): flutter test --enable-vmservice "01:21 +228: All tests passed!"; analyze No issues found; format 0 changed.
