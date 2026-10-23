# Task 3 report: the chrome parts

## Red (before the parts existed)
`flutter test test/chrome/parts_test.dart test/l10n/shadcn_words_test.dart`:
- parts_test.dart: `Error: Error when reading 'lib/src/chrome/icon_button.dart': No such file or directory` (and menu_button, rows, segmented, select ...): the file does not load.
- shadcn_words_test.dart: `00:00 +1 -4: Some tests failed.` SW1, SW2, SW4 failed (SW4: "allowed but unused (a stale entry)"); SW3 passes vacuously.

## Green
- `flutter test test/chrome/parts_test.dart`: `00:02 +18: All tests passed!`; shadcn_words_test: 4 tests pass (together `00:01 +22: All tests passed!`).
- jet_cad_2d_plan: `02:24 +1682 ~7: ... All tests passed!`; `flutter analyze`: `No issues found!`; `dart format --output=none --set-exit-if-changed .`: `Formatted 337 files (0 changed)`.
- jet_cad_2d_integration: `01:26 +240: All tests passed!`
- tool/ci: `01:00 +122: All tests passed!`; check_api_boundary: `jet_cad_2d_plan: no exported type mentions shadcn_ui or lucide_icons_flutter`.

## Mutations (each reverted)
- M-CP1 (`groupId: EditableText` removed): `00:00 +0 -1: PlanTextField CP1 two PlanTextFields: tapping the second does not call the first's onTapOutside [E]`
- M-CP4 (no controller reset after onChanged): `00:00 +0 -1: PlanSelect CP4 a PlanSelect whose onChanged refuses shows the old option after the pick [E]`
- M-CP6 (`ShadContextMenuRegion`, trigger without toggle): `Expected: exactly one matching candidate / Actual: Found 0 widgets with text "Item one"` ... `PlanMenuButton CP6 ... [E]` (macOS mouse click)
- M-CP10 (`selected:` dropped from the semantics): `00:00 +0 -1: PlanIconButton CP10 selected: true exposes a selected semantics node ... [E]`
- M-SW (`contextMenuBuilder:` removed): `00:00 +1 -1: SW2 text_field.dart passes contextMenuBuilder and no keyboardToolbarBuilder [E]`

## Read-only technique
`ShadInput(readOnly: true)` was rejected: its `didUpdateWidget` sets `focusNode.canRequestFocus = !readOnly` when the flag changes, which unfocuses a focused field (CP3) and drops a read-only field from the Tab order. The input stays editable for the framework; a `TextInputFormatter` (`_KeepText`) refuses any change to the text and lets the selection through (typing, backspace, cut, paste are all reverted), `showCursor: false`, `keyboardType: TextInputType.none` (no soft keyboard), and a read-only toolbar builder offering copy and select all only. CP3 pins focus kept across both toggles, clipboard holds the selection, enterText/backspace change nothing, toolbar has Copy and no Cut/Paste.

## Beyond the brief (all internal, signatures kept)
- `PlanIconButton` is a `StatefulWidget` (same constructor), and `icon_button.dart` also holds `PlanTooltipSuppressor` (InheritedWidget). Reason: the button's tooltip opened under it and covered the menu's first entries (found by a failed hit test). `PlanMenuButton` suppresses the tooltip while open; a GlobalKey keeps the button's state across the tooltip coming and going.
- `PlanMenuButton`: Escape is a `HardwareKeyboard` handler registered while open (the menu is in an overlay, outside the trigger's focus subtree); focus returns to the trigger on Escape always, and on other closes only if the tap left nothing focused (does not steal focus from a text field the user tapped).
- Menu entries: `ShadContextMenuItem` with a `LucideIcons.check` leading for `selected`.
- `PlanSelect` uses `minWidth: 0` (ShadSelect's default min width would overflow narrow panels).
- Extra tests: pick-through-model for select, entry pick/selected mark, read-only field, segmented, rows.
- kAllowedShad (SW4) holds 19 names: ShadButton, ShadCheckbox, ShadColorScheme, ShadContextMenu, ShadContextMenuController, ShadContextMenuItem, ShadIconButton, ShadInput, ShadMouseAreaSurface, ShadMouseCursorProvider, ShadOption, ShadSelect, ShadSelectController, ShadSwitch, ShadTextTheme, ShadTheme, ShadThemeData, ShadTooltip, LucideIcons. (`ShadContextMenuController` is a typedef of ShadPopoverController.)

## Concerns
- Test helper for tests that set `debugDefaultTargetPlatformOverride`: the framework checks it before tearDown runs, so CP6 resets it in the body (tearDown kept as a safety net).
- Semantics: `PlanIconButton` and `PlanSegmented` use `excludeSemantics: true` with an explicit `onTap`; the inner ShadButton's own semantics are replaced (the focus semantic flag is set).
- `PlanListRow` / check / switch rows rely on ShadButton / ShadCheckbox / ShadSwitch for Enter/Space (tested).
- Flutter in this environment is the 3.47 line, so tests use `flagsCollection` (hasFlag is deprecated); an older Flutter would not compile those assertions.
- `PlanListRow.visibleWords` is empty (the title is a widget; its owner reports its words).
- No file over 300 lines (largest: text_field.dart 167).
