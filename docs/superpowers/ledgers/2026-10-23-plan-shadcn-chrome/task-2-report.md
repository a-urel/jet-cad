# Task 2 report: the scope

Commit: c0cf8312  (feat(plan): the shadcn scope and host slots)

## Red (before implementing)
shad_scope_test.dart did not compile:
test/chrome/shad_scope_test.dart:7:8: Error: Error when reading 'lib/src/chrome/shad_scope.dart': No such file or directory
test/chrome/shad_scope_test.dart:71:47: Error: Method not found: 'PlanShadScope'.
test/chrome/shad_scope_test.dart:100:38: Error: Method not found: 'PlanShadScope'.
test/chrome/shad_scope_test.dart:109:46: Error: Method not found: 'PlanShadScope'.
test/chrome/shad_scope_test.dart:113:47: Error: Method not found: 'PlanShadScope'.
host_slot_test.dart compiled and passed before implementing (11 cases): the editor's Scaffold and the service view's own transparent Material already sit above every slot (see Concerns).

## Gates (real last lines)
- plan: flutter test -> "+1660 ~7: All tests passed!"; flutter analyze -> "No issues found!"; dart format --set-exit-if-changed -> exit 0
- integration: "+240: All tests passed!"; restaurant_demo "+112: All tests passed!"; architecture_demo "+176: All tests passed!"
- tool/ci dart test "+122: All tests passed!"; check_api_boundary: "jet_cad_2d_plan: no exported type mentions shadcn_ui or lucide_icons_flutter"

## Mutations (each reverted)
- M-SC1 (scope ignores ancestor ShadTheme): SC2 red, also SC4, SC6, SC10 ("+1 -1 ... SC2 under an ancestor ShadTheme ... [E]")
- M-SC2 (scope never derives / provides): SC1 red, also SC3, SC7, SC9, SC10 ("+0 -1 ... SC1 under a bare MaterialApp ... [E]")
- M-SC3 (no DefaultTextStyle): SC4 red, also SC5, SC6 ("+3 -1 ... SC4 a plain Text below the scope ... [E]")
- M-HS (PlanHostSlot without Material): the editor/service-view cases stayed green (redundant Materials above); added "HS1 PlanHostSlot alone" which goes red ("No Material widget found.", "+4 -1 ... HS1 PlanHostSlot alone ... [E]").

## Ruling: default text style
None. No existing test failed because of the DefaultTextStyle.

## What ShadApp installs at 0.57.3 (app.dart build)
ScrollConfiguration, HeroControllerScope, ShadAnimatedTheme (the ShadTheme), ShadMouseAreaSurface, ShadMouseCursorProvider, then (in _buildApp) the Material app with a derived ThemeData, ShadToaster/ShadSonner. ShadMouseAreaSurface and ShadMouseCursorProvider are both exported from shadcn_ui.dart (no src/ import). The scope provides ShadTheme + those two.

## Notes
- Wrapping: each of the 7 public widgets' build is now PlanShadScope(child: _body(context)) (property panel, gallery, layer panel, page panel, tool palette, service view, editor).
- Host slots: PlanHostSlot wraps the editor bar row and service bar row when the host gave leading/trailing (one Material over the row keeps Expanded children legal), the service side panel (both desktop and drawer), unit/object inspector output, unit overlay output. "contextualPanels" holds no host widgets; nothing wrapped there.
- Contrast: planShadThemeFrom replaces a foreground below 4.5:1 on its surface with black or white (Material 2 default blue/white is 3.12:1). Black/white built by HSLColor, because test/invariants/theme_colours_test.dart forbids Color literals in lib.
- Memo: Expando keyed by ThemeData identity; counter debugPlanShadDerivations. MaterialApp animates theme changes, so each animation frame derives once.
- Font family: textTheme.bodyMedium.fontFamily; if null, shadcn's ShadTextTheme falls back to its bundled Geist.
