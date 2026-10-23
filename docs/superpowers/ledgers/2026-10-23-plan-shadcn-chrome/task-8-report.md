# Task 8 report: the library's own symbol gallery

Status: DONE_WITH_CONCERNS (see concerns).

Files: lib/src/panels/gallery_grid.dart (new: PlanGalleryGrid/Group/Cell), lib/src/panels/plan_symbol_gallery.dart
(no renderer gallery type left), tests: test/panels/gallery_grid_test.dart (GG1-GG4, GG6), GG5 in
plan_symbol_gallery_test.dart (it needs the controller/loading states), rulings R-GAL, R-TextField in rulings.md.

Order caveat: I wrote the implementation before the tests, so there is no red run of the new tests against a missing
implementation. Evidence of the tests biting is the mutation below, plus GG6's first run going red on dark theme
(a pump issue in the test, fixed).

Mutation M-GG1 (collapse keyed by group index): GG1 first stayed GREEN (degenerate fixture: same order on rebuild).
Strengthened GG1 (rebuild reorders groups and inserts one before) -> with the mutation:
  `Expected: no matching candidates / Actual: _KeyWidgetFinder:<Found 1 widget with key [<'symbol-cell-a0'>]`
  `GG1 ... [E]`, `+4 -1: Some tests failed.` Reverted; green.

Icon pairs: chevron_right -> LucideIcons.chevronRight, expand_more -> LucideIcons.chevronDown, close -> LucideIcons.x.
The search glyph is dropped (PlanTextField takes a text prefix only).

Choices: cell fill = scope `card`, selected = `secondary` with a 2 px `primary` border, ink = foregroundFor(fill);
label colour cardForeground/secondaryForeground; loading indicator is CircularProgressIndicator(color: scope primary);
Retry -> ShadButton.secondary, no-match Clear -> ShadButton.ghost (both inside ExcludeFocus); the clear (x) button is a
compact PlanIconButton beside the field inside a TapRegion(groupId: EditableText), so a tap on it is not a "tap
outside" (it sat inside the Material field's decoration before) and the field keeps the focus. Whole grid under
ExcludeFocus as before; cells are GestureDetector + Semantics (button, selected, enabled, label) + PlanTooltip.
No new Shad identifier (kAllowedShad unchanged).

Gates (real last lines):
- plan: flutter test `+1722 ~7: All tests passed!`; flutter analyze `No issues found!`; format `(0 changed)`.
- integration: `+240: All tests passed!`
- architecture_demo: `+176: All tests passed!`; restaurant_demo: `+112: All tests passed!`
- tool/ci dart test: `+122: All tests passed!`; check_api_boundary: `no exported type mentions shadcn_ui or lucide_icons_flutter`
- tool/screenshots: analyze clean; `flutter test` fails in every file's setUpAll (shots.dart:34 loadManifestFonts:
  `Unable to load asset: "packages/shadcn_ui/fonts/Geist[wght].ttf"`), before any scene runs: the harness cannot load the
  shadcn font. Not caused by this task; Task 13 (screenshots) needs the font declared there.

Concerns: (1) screenshots harness above. (2) PlanTextField has no textInputAction, so the search field's soft-keyboard
action key is the default, not "search" (Enter still hands focus back). (3) restaurant_demo's host_chrome_test.dart
needed the R-TextField read (not in the brief's list).
