# The example apps in shadcn — results

**Date:** 2026-10-24. **Branch:** `claude/shadcn-ui-75d8dc`, cut from local `main`
at `870661fa` (the spec and plan). Not merged into `main`, not pushed.
**Spec:** [2026-10-24-demos-shadcn-design.md](../specs/2026-10-24-demos-shadcn-design.md) (rev 2, approved).
**Plan:** [2026-10-24-demos-shadcn.md](../plans/2026-10-24-demos-shadcn.md).
**Ledger:** [docs/superpowers/ledgers/2026-10-24-demos-shadcn/](../ledgers/2026-10-24-demos-shadcn/)
(progress, every task's brief and report, `rulings.md` with every test change).

Executed with Sonnet implementers and no reviewer sessions (the human's rule):
the controller read each task's diff, ran its own mutation and re-ran the gates.

## What shipped

- Both demos root in a plain `ShadApp` (zinc, Roboto): no `MaterialApp`, no
  `Scaffold`, no Material widget and no `Icons.` in either `lib/` (the guards
  DKM1/DKM2 in each demo; one `material.dart` import per demo, `show ThemeMode`).
- Restaurant demo: the look toggle changes only the canvas side. The POS look is a
  `PlanTheme` (3 px selection, 52 px service bar) put on the derived Material theme
  by `ShadApp.materialThemeBuilder`; the Standard look keeps the library default.
  A shadcn top pane (scrollable tabs and controls), a side sheet for phone widths,
  the side panel, the table menu (`ShadContextMenu`) and the dialogs are shadcn;
  `posShadTheme`/the seed colour are gone.
- Architecture demo: a `ShadApp` root, shadcn dialogs (save, name prompt, error,
  open, export) with keyboard behaviour pinned (AD4), a `ShadTooltip` on the
  document title.
- Every visible word still comes from `DemoStrings`, `AppStrings` or `PlanStrings`.
- `docs/host-guide.md`: the introduction's demo sentence and §10's POS-look bullet
  describe the demos as they are. No CHANGELOG entry (the demos are `publish_to: none`).
- No change under `packages/`.

## Rulings (from the ledger, in order; each with its cost if wrong)

1. the rig preloads shadcn de/tr words (deferred imports) in runAsync and pumps 1 ms after a language switch (settleLocale/switchLanguage) — shadcn 0.57.3 loads non-English words on a timer — costs: a runtime first-use frame in the old language, to check in Task 6's real run.
2. docked controls scroll horizontally (reverse) beside the title instead of a fixed row — at 1300 px they overflowed by 54 px — costs: at desktop the left controls may sit off-screen at large text; wrapping is the alternative.
3. ShadTabs scrollable: true with flex-0 tabs, keys on the tab labels' Text — non-scrollable ShadTabs take infinite width in a Row — costs: none seen.
4. the keyed ShadSheet fills the route; RT2 and layouts_test measure DemoSidePanel (320) — costs: the key does not sit on the visible box.
5. ShadSwitch wrapped in Align (it expands full width, a tap at its centre misses), ShadButton labels Flexible in the side panel, pickRecord ensureVisible (ShadSelect's chevron covers edge options) — costs: none seen.
6. the table menu is a ShadContextMenu in a root OverlayEntry under a dismissing barrier (shadcn has no showMenu) — costs: no route, so no back-button dismissal on Android.
7. ShadTooltip around the document title needs a ShadGestureDetector child (a bare Text never reads the hover strategy) — costs: none seen.
8. test fixtures in document_save_test DS6 and document_open_test move from MaterialApp to ShadApp (showShadDialog needs a ShadTheme) — costs: none.
9. one material.dart import allowed per demo, `show ThemeMode` in lib/main.dart (ShadApp.themeMode takes Material's enum) — costs: none.
10. the switch's label gap is made hit-testable with an opaque MouseRegion (click cursor) instead of a transparent colour — theme_colours_test forbids colour literals — costs: none seen.

Every test change is in the ledger's `rulings.md`.

## Mutations (controller's own, each turned the named tests red, then reverted)

- Task 1: controller mutation: materialThemeBuilder always the Standard branch → RD3 red; restored. Gates rerun: +117 all passed, analyze clean, format 0.
- Task 2: controller mutation: side button onPressed no-op → layouts RS1 ×4 + RT2 red; restored. Gates rerun: +122, analyze clean.
- Task 3: controller mutation: export dialog never marks the current choice → DH4 red; restored. Gates rerun: +124, 0 "would not hit", analyze clean.
- Task 4: controller mutation: error dialog OK no-op → AD3, DC9, EX2, DO6 red (suite ran >10 min on the hangs); restored. Analyze clean.
- Task 5: implementer DONE at bcfc89aa. Controller mutation: 'Theme.of' appended to badges.dart → DKM1 stays green (Theme.of/ThemeData( missing from the list); bare material import in architecture main → DKM1 red. Fix round 1/5 dispatched.
- Task 5: controller mutations: Theme.of tear-off in restaurant badges → DKM1 red; Card() in architecture document_host → DKM1 red; restored.

## What the closing gates caught

`flutter test integration_test -d macos` in `restaurant_demo` failed at POS1
(`pos_test.dart:101`, `pressInPanel(tester, 'own-bar')`) although every widget test
passed: the real macOS window is taller and wider than the widget tests'. Two
causes: (1) the rig's `reveal` scrolled the side panel but left the entry in the
list's cache extent below the viewport, so the tap missed; (2) `_toggle` in
`side_panel.dart` made only the switch clickable, leaving an 8 px dead zone between
track and label for short labels. Fix `a6913fc0`: `reveal` now `ensureVisible`s the
entry after scrolling, and the whole switch row is clickable. Re-run: restaurant
`flutter test` `00:34 +126`, `integration_test` `00:05 +1: All tests passed!`.
Also: the first `tool/ci` run, in parallel with the demo suites, hit the 30 s timeout
in AB1/AB2; alone it is green.

## Gates (run at `4a129cb2`, restaurant re-run at `a6913fc0`; real last lines)

At `f3758596` (after fix round 3), re-run by the controller: restaurant
`00:29 +127: All tests passed!`, its `integration_test -d macos`
`00:05 +1: All tests passed!`; architecture `00:38 +183: All tests passed!`, its
`integration_test -d macos` `00:04 +1: All tests passed!`.

- `restaurant_demo`: `flutter test` `00:34 +126: All tests passed!`; analyze `No issues found! (ran in 3.7s)`;
  format `Formatted 45 files (0 changed)`.
- `architecture_demo`: `01:26 +182: All tests passed!`; analyze `No issues found! (ran in 4.7s)`;
  format `Formatted 47 files (0 changed)`.
- `jet_cad_2d_plan` `02:24 +1846 ~13: All tests passed!`;
  `jet_cad_2d_integration` `01:03 +240: All tests passed!`;
  `tool/screenshots` `00:08 +14: All tests passed!`; `tool/ci` `00:57 +122: All tests passed!`.
- `check_guide`: all 38 code blocks are in the host probe. `check_screenshots`: every rule holds.
- `flutter build macos --debug`: both demos built. `integration_test -d macos`:
  architecture `00:04 +1: All tests passed!`, restaurant `00:05 +1: All tests passed!` (after the fix).

## Looked at

Both demos were built and launched on macOS (`flutter build macos --debug`,
opened from `build/`). Screen access to them was declined by the human, so the
controller rendered both apps instead in a throwaway widget test (not committed)
with the bundle's real fonts (`FontManifest.json` through `FontLoader`): 1300 x 820
light and dark, and 400 x 820 (the restaurant demo with its side sheet open, dark).
The images were looked at by the controller, not by the human.

- Architecture demo, light and dark: the editor bar with the app's title and the
  Open sample button, the palette, the layer and page panels: zinc, Roboto, no
  Material left. Nothing to fix.
- Restaurant demo, first render: the side panel's bare `Text`s (the tables, groups,
  sections and log lines) had no default text style under a plain `ShadApp` (a
  Material `Scaffold` used to give it), so they drew without the theme's font;
  and on a phone the demo's side button and the library's panel button below it
  showed the same `slidersHorizontal` glyph. Fixed at `f3758596` (fix round 3 of
  Task 3): both demos' `ShadApp.builder` installs the theme's `p` style in the
  foreground colour, as the library's `PlanShadScope` does; `DemoSidePanel` wraps
  itself in the same style (the sheet's route set a muted one); the demo's button
  is `LucideIcons.panelRight`. Tests RD4 and AD5 pin the style; dropping the
  builder turns both red. Second render: the panel reads as the rest of the app,
  light and dark, docked and in the sheet.

Not looked at: the running apps themselves, the language switch at runtime, the
tablet width.

## Not done, open

Deferred minors:
- Task 1: settle() with the 1 ms tick made export_area_test find two export dialogs; settle left unchanged, cause not investigated.
- Task 2: the sheet shows shadcn's default close X and border.
- Task 3: own bar buttons and export choices do not wrap long labels.
- Language switch at runtime: shadcn 0.57.3 loads non-English words on a timer, so
  the first use of a language shows one frame or two of the old words (ruling 1).
