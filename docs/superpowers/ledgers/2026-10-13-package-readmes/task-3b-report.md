# Task 3b report

Status: DONE_WITH_CONCERNS (one concern, renderer standing-failure verdict; see below).
Commits: 5600f4f6 (library + test), second commit (design_light/design_dark PNGs; `git log -2`).

## TDD
RED: `flutter test test/ruler_frame_test.dart` -> compile failure: "No named parameter with the name 'fontFamily'" (ruler_frame_test.dart:86, 88) and "The getter 'fontFamily' isn't defined for the type 'RulerPainter'" / 'RulerCornerPainter' (54-56).
GREEN after implementing: `flutter test test/ruler_frame_test.dart test/ruler_painter_test.dart` -> "00:00 +15: All tests passed!".
Tests (ruler_frame_test.dart): RF-a (ambient 'Roboto' reaches top/left/corner: field and debugLastLabel style), RF-b (no ambient: label style == TextStyle(color: rulerInk, fontSize: kRulerLabelSize), fontFamily null), RF-c (shouldRepaint on fontFamily for bar and corner).

## Mutations (each restored from a copy in /private/tmp/claude-501/m, cmp clean)
- M-RF1 frame passes null: "RF-a ... [E]", "+7 -1: Some tests failed."
- M-RF2 label style drops fontFamily: RF-a [E], "+7 -1".
- M-RF3 shouldRepaint ignores fontFamily: "+2 -1: RF-c ... [E]", "+7 -1".
After restoring: "+8: All tests passed!".

## Gates
- Planner (`--enable-vmservice`, expect_failures --package packages/jet_cad_floor_plan): "2012 tests; the standing failures and skips, exactly". Analyze/format of floor_plan not touched (no change there).
- Renderer: flutter analyze "No issues found!"; dart format "0 changed"; expect_failures exits 1 with two lines: "standing failure passed or did not run: test/golden/text_lod_ladder_golden_test.dart :: text lod ladder rung 1 / rung 2 (RenderBackend.canvas)". Those two standing failures PASS on this machine (run alone: "+6: All tests passed!"); the golden test contains no ruler code (grep: no match in test/golden), so this is not caused by the change; it is the standing list being platform-specific. Not independently re-run at baseline.

## Screenshots
`UPDATE_SCREENSHOTS=1 flutter test test/planner_scenes_test.dart` -> 6 passed; only design_light.png and design_dark.png changed. Read both: ruler labels now real digits and units ("0 m", "2 m" ... along the top, rotated "2 m", "12 m" on the left, corner "m"); the PlannerShell's ambient family does reach the rulers, no scene patch needed.

## Files
packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart, lib/src/ruler_frame.dart (build is now a block body, reindented), test/ruler_frame_test.dart; PNGs design_light.png, design_dark.png. CHANGELOG untouched (no 0.7.2 section yet; Task 7).

## Self-review
No new public parameter on RulerFrame; null family gives exactly the old style (RF-b). Painters are rebuilt each frame build so a family change repaints via shouldRepaint. Doc comments state why.

## Concerns
Renderer expect_failures verdict is exit 1 on this machine due to two standing failures that pass locally (pre-existing, unrelated).
