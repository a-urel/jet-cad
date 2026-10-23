# Task 4 report: the architecture demo on ShadApp

Status: done, committed on claude/shadcn-ui-75d8dc.

## Changes per file (apps/architecture_demo)
- pubspec.yaml: `shadcn_ui: ^0.57.1`, `lucide_icons_flutter: ^3.1.25` (the
  latter is not imported directly: shadcn_ui re-exports `LucideIcons`).
- lib/app_theme.dart (new): `appShadTheme(Brightness)` zinc + Roboto.
- lib/main.dart: `MaterialApp` -> `ShadApp` (navigatorKey, onGenerateTitle,
  delegates, locales, theme/darkTheme, themeMode, the consume-only chords
  builder, home). `kAppSeed` removed (nothing else read it).
- lib/document_host.dart: `DocumentHost` returns the `PlanEditor` with no
  Scaffold; `showShadDialog` everywhere; error = `ShadDialog.alert` (keys
  document-error, -title, -text, -ok on the `ShadButton`); save changes =
  `ShadDialog` with ghost "don't save", outline cancel, `ShadButton` save with
  `autofocus`, Escape binding kept, `barrierDismissible: false`; name prompt =
  `ShadDialog` with label `Text(fileName)` over a `ShadInput` keyed
  name-prompt-field (autofocus, `onSubmitted`); the title tooltip is a
  `ShadTooltip` (text wrapped in `ShadGestureDetector`, see concern 1); Open
  sample = `ShadTooltip` > `ShadIconButton.ghost(LucideIcons.house, 20)`.
  The 104 px title comment still holds: DC12/DC12c (800 px, no overflow) pass.
- tests: see rulings.md "Task 4" (each with file:line, old -> new, why).

## AD1-AD4 (test/app_root_test.dart)
- AD1 one ShadApp, no MaterialApp, no Scaffold above the PlanEditor,
  `toolbar-open-sample` is a ShadIconButton, hover shows 'Open sample', the
  ShadTheme is the zinc scheme.
- AD2 dark/light platform brightness flips the derived Material theme
  (brightness, surface == shadcn background) and the ShadTheme.
- AD3 failed open: `ShadDialog` keyed document-error, title/text/OK keys, OK
  closes it.
- AD4 dirty + New: `ShadDialog` replace-dialog, focus inside replace-save, a
  tap outside leaves it up, Escape closes it as Cancel (flow ends, document
  identical, still dirty); name prompt field is a `ShadInput`, focused, shows
  the suggestion, Enter (done action) returns the typed name.

## Mutations (run by me)
- save dialog `barrierDismissible: true` -> AD4 red.
- Save button without `autofocus` -> AD4 red.
- title tooltip without `ShadGestureDetector` -> DC11 red.
All restored (diff against backup empty).

## Gates (real last lines)
- flutter test: `00:42 +180: All tests passed!`
- flutter analyze: `No issues found!`
- dart format: `Formatted 46 files (0 changed)`, exit 0
- `grep -c "would not hit"` over the full test output: 0
- git status: no analysis_options.yaml.

## Material that remains in lib
- main.dart:1 `import 'package:flutter/material.dart' show ThemeMode;` --
  `ShadApp.themeMode` takes Material's `ThemeMode`. No `Icons.` anywhere.

## Concerns
1. A `ShadTooltip` around a bare `Text` never opens (shadcn passes its hover
   strategy through the ShadTheme and only buttons/`ShadGestureDetector` read
   it). Worked around in the demo by wrapping; the old Material `Tooltip` was
   hover- and long-press-aware by itself. Task 5's guard / the restaurant demo
   should know if they tooltip a plain Text.
2. Tests that pump the app under non-English locales need the shadcn preload
   and a 1 ms tick; done in `pumpApp` and two local switch helpers, not in a
   shared settle helper.
3. `lucide_icons_flutter` is declared per the brief but unused directly.
