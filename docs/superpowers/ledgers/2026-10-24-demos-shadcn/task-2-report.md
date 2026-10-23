# Task 2 report

Status: DONE. Gates: flutter test "+122: All tests passed!", flutter analyze "No issues found!", dart format exit 0.

## lib/main.dart
- `_scaffoldFor`: Scaffold/AppBar/endDrawer gone; ColoredBox(background) > Column: top pane (title in textTheme.large; docked: controls in a reversed horizontal scroller; undocked: ShadTooltip + ShadIconButton.ghost `side-panel-button`, then `app-controls` horizontal scroll row), ShadSeparator, `_body` (today's body Row). `_scaffold` GlobalKey removed.
- Controls: `find-table` ShadInput (placeholder, leading search, onSubmitted, onPressedOutside no-op — the ShadInput name for onTapOutside); the four SegmentedButtons are ShadTabs (keys on ShadTabs, label keys on the Text), look toggle in ShadTooltip.
- `_openSidePanel`: showShadSheet(right) with ShadSheet key `side-panel-drawer`, constraints width 320, scrollable:false, padding zero (the panel is its own ListView; the sheet handles the safe area itself).
- `_panel()`: DemoSidePanel on a transparent Material, a bridge for Task 3's remaining Material controls (TextField needs a Material ancestor once the Scaffold is gone). Task 3 can drop it.

## Library facts found (no change under packages/)
- ShadTabs non-scrollable gives tabs width infinity and Expanded, which breaks inside a Row; `scrollable: true` is used on each (no Expanded, natural width).
- The keyed ShadSheet fills the route; the visible 320 px is the panel inside.

## Tests
- New test/top_pane_test.dart: RT1 (no Scaffold/AppBar/Drawer/SegmentedButton/TextField/Tooltip/IconButton built by the page outside PlanEditor and DemoSidePanel; keys are ShadInput/ShadTabs; tabs' value), RT2 (375x812: ShadIconButton, sheet is a ShadSheet, DemoSidePanel inside, exactly 320 wide, on screen, barrier closes it, app-controls horizontal and wider than the window, no exception), RT3 (text scale 2.0 at 375 and 1300, sheet opened at 375), RT4 (DE then TR: literal words Entwurf/Tasarim/Servis/Standart/Tisch suchen/Masa bul, no stale English, language tabs value).
- Mutations run by me: sheet without its key -> RT2 red; Material Tooltip on the look toggle -> RT1 red.
- Changed: layouts_test.dart (drawer width -> panel width), look_test.dart (shoot boundary; DL3 tooltips via hover; helpers mouseInView/hover/unhover). Rulings appended to rulings.md.
- zones_test.dart:87 untouched (Task 3).

## Concerns
- At 1300 px the controls do not all fit beside the title (overflow of 54 px before I made the docked row scroll); they scroll in the docked row now. A design call for the human.
- The ShadSheet adds a default close X and a 1 px border; kept as shadcn's own.
