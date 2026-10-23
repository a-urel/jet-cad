# Task 3 report

Commit: see `git log` (feat(restaurant_demo): shadcn side panel, menus and dialogs).

## Changes per file (apps/restaurant_demo)
- lib/side_panel.dart: ShadButton / .secondary / .outline, ShadInput (label Text above, onPressedOutside no-op as in the top pane), ShadTabs (zone-toggle, editor-profile; scrollable, flex 0 tabs), 8 ShadSwitch via `_toggle` (Align-start + vertical padding, key on the ShadSwitch), titles/error from ShadTheme. `_label` = Flexible(Text) for button labels.
- lib/editor_profiles.dart: RecordPicker = label Text + ShadSelect<String> keyed pos-id; options pos-id-none, pos-id-<id>, unknown-id option kept.
- lib/own_bar.dart: ColoredBox(muted) keyed own-bar-row, ShadButton.ghost per key.
- lib/export_flow.dart: showShadDialog + ShadDialog keyed demo-export-dialog, ShadButton.ghost per choice (LucideIcons.check on the current), cancel in actions.
- lib/table_menu.dart: root-overlay OverlayEntry: transparent barrier (swallows the dismissing tap) + ShadContextMenu(controller open, ShadGlobalAnchor(at)); title item disabled, separator, keyed items; Future completes with the choice, null on barrier tap / Escape / outside tap.
- lib/badges.dart: colours from ShadTheme colorScheme (card, border, primary, cardForeground), textTheme.small, LucideIcons.user.
- lib/main.dart: `_panel()` no longer wraps in Material; nothing needed it.

## Rulings
See rulings.md "Task 3".

## Mutations (all run, all restored)
1. menu-select always enabled -> statuses_test D20 red.
2. profile select without the unknown id: the brief's test did not exist (nothing covered an unknown id; all 123 passed). Added LK2b; the mutation (unknown id dropped) turns LK2b red.
3. (extra) table-menu barrier made IgnorePointer -> new D20b red.

## Gates
flutter test: "All tests passed!" (124); flutter analyze: "No issues found!"; dart format --set-exit-if-changed: exit 0 (0 changed).

## Material that remains in lib
- lib/main.dart:19 `import 'package:flutter/material.dart'` (non-widget/ShadApp-derived symbols; Task 5 to decide)
- lib/demo_theme.dart:17 import (ThemeData derivation for the canvas).
No `Icons.` left. No Material widget remains in the touched files.

## Concerns
- Test font (Ahem) is wide: ShadButton lays its child out unbounded in a Row, so long German/Turkish labels overflow ("Anordnung zurücksetzen"); fixed with Flexible(Text) labels. The own bar's ghost buttons and the export choices do not wrap (Row of unbounded width / dialog column); no test overflowed.
- ShadSwitch expands to full width (key's centre is empty space): hence the Align in `_toggle`, otherwise tester.tap on a switch key misses.
- ShadSelect: onChanged fires only on a real change; popover scrolls to the selected record with a chevron covering edge entries (see pickRecord ruling).
- `Warning: tap() find-table ... would not hit test` appears in some test output (top pane, Task 2 area); not touched here.

## Fix round 1 (find-table taps)
- Overlay found by printing the hit path and the ShadContextMenuItems: two items "Paste" / "Select All" at (491,30), i.e. ShadInput's own text-selection toolbar, opened by a second touch tap on the already-focused field. Not a tooltip, not the mouse hover.
- Not a product defect: a touch user tapping a focused text field gets the platform's selection toolbar (same as Material). No packages/ change.
- Test fix: mouse-kind taps on find-table, and the loop now starts from an unfocused field (premise strengthened, no vacuous focus). Ruling in rulings.md.
- `flutter test 2>&1 | grep -c "would not hit"` -> 0. flutter test: All tests passed (124); analyze: No issues found; format exit 0.

## Fix round 2 (macOS integration POS1)
- Reproduced: `flutter test integration_test -d macos` failed at pos_test.dart:101, tap at (1363.8, 688) missed; hit path ended in the side panel's list (blank area), so the entry was built but outside the viewport (lazy list cache extent). Root cause: the rig's `reveal` (scrollUntilVisible stops at "built"). Fixed with ensureVisible (ruling).
- Also found a genuine small dead zone in `_toggle`: the key's centre can fall in the 8 px gap between track and label for short labels (real Roboto), where a click does nothing. Fixed in lib/side_panel.dart: ShadSwitch padding zero and the label wrapped in an opaque MouseRegion(click cursor) with the 8 px start padding inside it, so the whole row toggles. All 8 keyed switches go through `_toggle`.
- Results: flutter test 126 passed, "would not hit" count 0; analyze clean; format exit 0; `flutter test integration_test -d macos`: "00:05 +1: All tests passed!".

## Fix round 3 (text style under a plain ShadApp)
- ShadApp's `builder` runs inside ShadAppBuilder, below the ShadTheme (checked in shadcn_ui app.dart). Both demos' ShadApp now install DefaultTextStyle(textTheme.p + foreground); the architecture demo composes it with its CallbackShortcuts.
- Found while testing: inside the side sheet the text is muted (some library surface sets a muted style nearer than the app's), so `DemoSidePanel` also wraps its list in the same DefaultTextStyle.
- Side button icon: LucideIcons.panelRight.
- Tests RD4 (restaurant) and AD5 (architecture), mutations red (app style dropped; panel style dropped). DZ2 retargeted (ruling).
- Gates: restaurant flutter test passed, 0 "would not hit", analyze clean, format 0; architecture 183 passed, same.
