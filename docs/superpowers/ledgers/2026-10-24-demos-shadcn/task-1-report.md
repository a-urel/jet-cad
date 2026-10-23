# Task 1 report: restaurant demo root

Status: DONE_WITH_CONCERNS (see Concerns).

## Changes
- pubspec.yaml: + lucide_icons_flutter ^3.1.25 (flutter pub get from root ran).
- lib/demo_theme.dart: posShadTheme -> demoShadTheme; comments reworded.
- lib/main.dart: MaterialApp -> ShadApp (zinc light/dark, ThemeMode.system,
  materialThemeBuilder adds posPlanTheme(theme.brightness) under DemoLook.pos);
  removed _seed, _theme, _viewTheme, _viewKey and the ShadTheme wrap (the
  Column is no longer keyed: no wrapper appears/disappears above the editor).
  Scaffold/AppBar/Drawer untouched (Task 2).
- test/app_root_test.dart (new): RD1 ShadApp present, no MaterialApp, ShadTheme
  colorScheme == demoShadTheme(b); RD2 dark then light platform: Theme
  brightness, colorScheme.surface == background, ShadTheme brightness follow;
  RD3 PlanTheme extension == posPlanTheme(b) under POS, null under Standard.
- test/look_test.dart, theme_colours_test.dart, demo_rig.dart and six
  language tests: see rulings.md (Task 1 section).

## Mutation
materialThemeBuilder returning the theme as is: RD3, DL1, DL2, DL3 red
(+2 -4); restored: green.

## Output (real)
flutter test: "00:29 +117: All tests passed!"
flutter analyze: "No issues found! (ran in 3.8s)"
dart format --output=none --set-exit-if-changed .: "Formatted 43 files (0 changed)", exit 0

## Concerns
- shadcn_ui loads non-English words through deferred imports; a bare two-frame
  pump after a language switch (or locale: start) does not show them. Handled
  in the test rig only (ruling). At runtime the app shows nothing for a frame or
  two on first use of a language; Task 2's RT4 (runtime language switch) will
  hit the same thing.
- A 1 ms tick inside settle() broke export_area_test (two export dialogs
  found); cause not investigated, avoided by keeping settle() unchanged.
