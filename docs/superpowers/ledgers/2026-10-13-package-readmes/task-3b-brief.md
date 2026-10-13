# Task 3b (inserted by the controller, Ruling R6): the rulers' labels take the ambient font family

Not in the plan file: inserted after Task 3 found that the rulers' labels in
P1/P2 draw as test-font boxes. The spec requires real fonts in every
screenshot (D4) and no public API reaches the rulers' label style.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart` (`RulerPainter`, `RulerCornerPainter`: an optional `fontFamily`, the label style, `shouldRepaint`)
- Modify: `packages/jet_cad_2d_flutter/lib/src/ruler_frame.dart` (pass `DefaultTextStyle.of(context).style.fontFamily` to all three painters)
- Test: `packages/jet_cad_2d_flutter/test/ruler_frame_test.dart` (or `ruler_painter_test.dart`, whichever already pumps a `RulerFrame`; follow its fixtures)
- Modify: `packages/jet_cad_2d_flutter/CHANGELOG.md` only if a `## 0.7.2` section exists (it does not yet; Task 7 writes it — leave the CHANGELOG alone and say so in the report)
- Regenerate: `packages/jet_cad_floor_plan/doc/screenshots/design_light.png`, `design_dark.png` (and the other four if the regeneration touches them; commit only what changed)

**Behaviour:**
- `RulerPainter({..., this.fontFamily})` and `RulerCornerPainter({..., this.fontFamily})`: `final String? fontFamily;`. The label style becomes `TextStyle(color: chrome.rulerInk, fontSize: kRulerLabelSize, fontFamily: fontFamily)`. With `fontFamily == null` the style is exactly today's (same fields, nothing else set).
- `shouldRepaint` returns true when `chrome` **or** `fontFamily` differs.
- `RulerFrame.build` reads `DefaultTextStyle.of(context).style.fontFamily` once and passes it to the corner and both bars. No new public parameter on `RulerFrame`: a host's own text style already decides its font, and the rulers follow it (on a device a Material app's ambient family is the app's font).
- Keep the doc comments in the files' style: say why (the rulers follow the host's text; a family-less label falls to the platform default, or to the test font under `flutter test`).

**Tests (TDD):**
1. RF-a: pump a `RulerFrame` (existing fixture) under `DefaultTextStyle(style: TextStyle(fontFamily: 'Roboto'), child: …)`; read the top bar's `RulerPainter` from its `CustomPaint` (key `ruler-top`), the left (`ruler-left`) and the corner (`ruler-corner`); after a pump that paints labels, each painter's `debugLastLabel?.style?.fontFamily` is `'Roboto'` (or, for a painter whose label is not laid out in that fixture, its `fontFamily` field is). Use a non-default family name so the test cannot pass on a default.
2. RF-b: with no ambient family (`DefaultTextStyle` without a family, as `Directionality` alone gives), the label style's `fontFamily` is null and the style equals `TextStyle(color: chrome.rulerInk, fontSize: kRulerLabelSize)`.
3. RF-c: `shouldRepaint` is true for two painters equal but for `fontFamily`, false when both match.
Named mutations, each must go red, each restored from a copy and `cmp`ed: M-RF1 the frame passes `null` instead of the ambient family (RF-a red); M-RF2 the label style drops `fontFamily:` (RF-a red); M-RF3 `shouldRepaint` ignores `fontFamily` (RF-c red).

**Then:**
- The renderer's gate (CLAUDE.md: `flutter test` compared with `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter <report>` from the root, since the package has standing failures and skips; `flutter analyze`; format), and the planner's gate the same way (`--enable-vmservice`, `--package packages/jet_cad_floor_plan`), since the planner hosts `RulerFrame`.
- `cd tool/screenshots && UPDATE_SCREENSHOTS=1 flutter test test/planner_scenes_test.dart`; open `design_light.png` and `design_dark.png` with the Read tool: the ruler numbers must be real digits now. If the scene's ambient `DefaultTextStyle` under the `PlannerShell` has no family, the fix does not reach it: report that instead of patching the scene.
- Commit the library change with its test first, then the regenerated PNGs in a second commit. Trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
