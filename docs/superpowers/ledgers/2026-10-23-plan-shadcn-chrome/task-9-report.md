# Task 9 report: the service view and its bar

Status: DONE_WITH_CONCERNS (11 tests red, reported not changed; see below).

Changes (plan_service_view.dart): build wraps in PlanShadScope; transparent Material kept; canvas reads (Theme.of -> canvas background via _canvasColour, ChromePalette.of(theme.brightness), paper via _brightness/_surfaceArgb in didChangeDependencies) stay Material (SV3); bar colour/border and side-panel colour from planShadThemeOf (background+bottom border, card); serviceBarHeight still sizes the bar (SV2); _button, the tune button -> PlanIconButton (selected kept).
Icons: undo->LucideIcons.undo, redo->redo, straighten->ruler, merge_type->merge, call_split->split, ios_share_outlined->share, print_outlined->printer, tune->slidersHorizontal.
Kept Material reads: didChangeDependencies Theme.of (surface for paper, brightness), _canvasColour, ChromePalette.of(theme.brightness) in _canvasOf: canvas-owned.
Tests: new test/service/view/service_chrome_test.dart SV1-SV4. Red first: SV1 and SV4 (x2) red (IconButton not PlanIconButton); SV2/SV3 held before and after (they pin what must not move).
Mutation M-SV3 (_canvasColour reads ShadTheme background): SV3 red ("Actual: Color(... red 0.0627, green 0.1255, blue 0.1882)" vs Material surface); reverted.
Rulings: R-IconButton (service bar) in rulings.md.
Still red (not changed):
- service_bar_test.dart BC1 x8 and S-19 "the service bar: leading before the buttons...": the Material IconButton was 48 px wide, ShadIconButton is 40, so every left edge after the first moves (e.g. redo 60 -> 52, guides 108 -> 92). Geometry, not a type change; the editor bar's map already reads 40.
- apps/restaurant_demo look_test.dart DL1/DL2 (line 238): "premise: the bar is the seed scheme's" pins the bar colour as surfaceContainer; the bar is now the shadcn background (spec "Material as a surface"; the editor bar did the same).
Gates: plan flutter test 1828 pass, 13 skipped, 9 red (BC1 x8, S-19; the run before the guide/other test edits showed 18, the later run 9) + analyze clean + format clean; integration 240 pass; architecture_demo 176 pass; restaurant_demo 2 red (DL1, DL2); tool/ci 122 pass; api boundary ok.

## Fix round 1
R-BarGeometry: service_bar_test edges now computed from the measured button width (asserted 40) with the literal 8 px gaps; all 9 formerly red tests pass, no other edge differed. R-BarSurface: restaurant_demo look_test bar premise (DL1/DL2 standard at 216/238, POS at 305) now scheme.surface. Mutation: group gap 8 -> 13 makes 11 service_bar_test tests red; reverted.
Gates: plan 1837 pass (13 skipped), format clean; restaurant_demo 114 pass; architecture_demo 176; integration 240; tool/ci 122; API boundary ok.
