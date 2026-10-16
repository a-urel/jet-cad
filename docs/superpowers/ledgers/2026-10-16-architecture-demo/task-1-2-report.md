# Tasks 1 and 2 report

Status: DONE_WITH_CONCERNS (concerns: see end)

Commits: 42e3fa4c (Task 1), a66b3807 (Task 2 scaffold), 22611489 (AS-dispose strengthened)

## Task 1
- Barrel exports `showPlanExportDialog` and `kFileChords`. `barrel_test.dart` also pins the
  exact name set (ED-9), so the two names were added there too, plus the brief's new test.
- `kFileChords` already has a doc comment; CHANGELOG line added.
- Gates (jet_cad_2d_plan): `flutter test --enable-vmservice` -> "+1552: All tests passed!";
  `flutter analyze` -> "No issues found!"; format -> 0 changed.
- Mutations (on committed code, reverted, `git diff --quiet` clean): dropping
  `showPlanExportDialog` from the show list -> compile error "Undefined name 'showPlanExportDialog'";
  dropping the chords export line -> "Undefined name 'kFileChords'".

## Task 2
- Runners copied, renamed (`architecture_demo`, `dev.jetcad.architectureDemo`, names
  "jet-cad architecture demo"); `grep floor_planner|floorPlanner` prints nothing. Root workspace
  gained `apps/architecture_demo`. analysis_options.yaml committed (the one exception); no other
  analysis_options shows modified after `flutter pub get`.
- Version used: `jet_cad_2d_plan: ^0.8.0` (its pubspec says 0.8.0, not 0.1.0), kit `^0.1.0`.
- Font: no `flutter: fonts:` family declared. The plan README only calls `ensurePlanFonts()` and
  `registerFontLicences()`, and the library registers the bare Roboto itself.
- Symbol loader ownership: `PlanController` never disposes a loader it was given
  (`_ownsSymbolLoader`), so the app state owns a `PlanSymbolLoader` and disposes it after the
  controller. (The brief's snippet `PlanSymbolLoader()` passed inline would have leaked.)
- Only the `printer` seam, per the controller ruling.
- Tests: N1, AS1, CH-consume (Meta and Control), AS-dispose. App gates:
  `flutter test` "+5: All tests passed!", `flutter analyze` "No issues found!", format 0 changed.
- Mutations (all on committed code, reverted clean):
  - M-N1 (`// jet_cad_floor_plan` in main.dart) -> N1 red (+4 -1).
  - AS1 `kits: []` did not throw; the Symbols tab disappears -> AS1 red (+4 -1).
  - drop the `builder:` chord layer -> both CH-consume tests red (+3 -2).
  - dispose controller in `deactivate` -> first version of AS-dispose SURVIVED (all green), so I
    rewrote it (reparent via GlobalKey then unmount; `controller.dirty.addListener` throws only
    when disposed) -> now red (+4 -1). Removing `_controller.dispose()` entirely -> red too.
- Builds: `flutter build macos --debug` -> "Built build/macos/Build/Products/Debug/architecture_demo.app"
  (Swift deprecation warning only). `flutter build web` -> "Built build/web" (a cupertino_icons
  font notice only).

## Concerns
- AS-dispose differs from the brief's wording (reparent test) because the plain unmount test
  could not kill the deactivate mutation.
- Brief said plan version ^0.1.0 in places; real is 0.8.0.
