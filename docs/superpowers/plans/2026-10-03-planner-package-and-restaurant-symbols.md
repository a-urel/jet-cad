# Plan 14b-1 + 14s — the planner package and the restaurant symbols

**Spec:** [2026-10-03-restaurant-embedding-design.md](../specs/2026-10-03-restaurant-embedding-design.md),
revision 3 (approved 2026-10-03): slice 14b-1 (V-7 to V-12) and slice 14s
(S1 to S6 as amended by V-1 to V-6a).
**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `4d6b78f`.
**Toolchain:** Flutter 3.47.6 / Dart 3.13.5 in the Linux container (the
repo's floor is 3.44.0; nothing here needs more).

## Global constraints

- `CLAUDE.md` non-negotiables. No `analysis_options.yaml` is committed.
- The engine (`packages/jet_cad_2d`) and render (`packages/jet_cad_2d_flutter`)
  packages are **not edited** by this plan; the two allocation invariant
  tests stay untouched and green.
- No golden PNG changes.
- New packages: `resolution: workspace`, `publish_to: none`, `sdk: ^3.5.0`
  (the language version: the tall formatter must not reformat moved code),
  `flutter: ">=3.44.0"`, added to the root `pubspec.yaml` workspace list.
- Every task ends with its package's gate green:
  `flutter test && flutter analyze && dart format --output=none
  --set-exit-if-changed .` in each touched Flutter package or app.

## File structure (after the plan)

```
packages/jet_cad_floor_plan/
  pubspec.yaml            assets: furniture.jetlib, Roboto + licence; fonts
  lib/editor.dart         barrel for apps/floor_planner (V-8)
  lib/symbols.dart        symbol authoring + library API (V-3)
  lib/jet_cad_floor_plan.dart   empty until 14b-2
  lib/src/...             today's apps/floor_planner/lib minus the frame
  tool/generate_furniture_library.dart
  test/...                the moved tests
packages/jet_cad_restaurant_symbols/
  pubspec.yaml            asset: assets/restaurant.jetlib
  lib/jet_cad_restaurant_symbols.dart
  lib/src/{shapes,tables,booths,bar,service,kitchen,outdoor,catalog,source}.dart
  tool/generate_restaurant_library.dart
  test/restaurant_library_test.dart
apps/floor_planner/
  lib/{main,planner_shell?,document_host,document_files*,exit_guard*}.dart
  lib/export/export_flow.dart
  test/...                the frame's tests
```

## Tasks

### Task 1 — `PlannerShell` out of `main.dart` (app only)

Move `ShellSettleRegistrar`, `PlannerShell` and its state from
`lib/main.dart` to `lib/planner_shell.dart`; `main.dart` and
`document_host.dart` import it; tests importing `main.dart` for the shell
import `planner_shell.dart`. Pure move, no edit to the moved code.
**Done:** app gate green, test count equal to the baseline.

### Task 2 — the package, the move, the barrels

Create `packages/jet_cad_floor_plan`; `git mv` every non-frame lib file
(V-7) to `lib/src/` keeping the layout; rewrite imports
(`package:floor_planner/x` → `package:jet_cad_floor_plan/src/x` in moved
tests, `package:jet_cad_floor_plan/editor.dart` in the app); move tests per
V-9 with their support files; move `tool/generate_furniture_library.dart`.
`editor.dart` exports exactly what the app's remaining files use.
**Done:** both gates green; app + package test counts sum to the baseline.

### Task 3 — assets and the font

Move `furniture.jetlib`, `Roboto-Regular.ttf`, `Roboto_LICENSE.txt` to the
package; asset keys `packages/jet_cad_floor_plan/...` at every read
(the loader, the export font, the licence registry); the app's `fonts:`
block removed and `ensureFloorPlanFonts()` (FontLoader, family `Roboto`,
once per process, idempotent) awaited in `main()`. Tests that read the
asset from disk (`File('assets/...')`) run from the package directory.
New tests: M-14b1-1 (loader against a bundle holding only the package key),
M-14b1-2 (font registration changes the measured width).
**Done:** both gates green; `flutter build web` of the app succeeds.

### Task 4 — seating metadata and `buildSymbolLibrary` (14s S1–S4, V-3)

`SeatingComponent` (`jetcad.seating`), registered in
`registerAppComponents`; `FurnitureSymbol.seats`; `buildFurnitureLibrary`
generalised to `buildSymbolLibrary(catalog)`; `SymbolEntry.seats` read by
`SymbolLibrary.decode` (seats < 1 refused); `placeSymbol` copies the
seating component; the five dining tables servable at version 2, the round
table with four chairs; the asset regenerated; `symbols.dart` barrel.
Tests: M-14s-1, -2, -3 (off-origin, quarter-turned, mirrored), -5.

### Task 5 — several libraries (V-4)

`SymbolLibrarySource` (name, reader); `SymbolLibraryLoader(sources:)`
merging in order, failing on any source, refusing a duplicate
`key@version` across sources with both names; `furnitureSymbolSource`
default. Tests: two sources merge in order and categories keep
first-appearance order; one failing source fails the load and Retry
re-reads every source; a duplicate across sources names both.

### Task 6 — the restaurant package scaffold and its helpers

`packages/jet_cad_restaurant_symbols`: pubspec, barrel, shape helpers
(rectangle, a chair at an angle about a centre as a closed 4-point
polyline with its back line, a stool, a bench with a back, a burner ring),
`restaurantSymbolSource` over its asset, the generator tool, the test
harness asserting V-6a's rules over every entry.

### Task 7 — the 69 symbols (V-6)

One file per category; the hand-written tables in the test (keys in order,
categories, seats, closed-polyline counts); the asset generated and
committed. M-14s-4, -6 fired against the package.

### Task 8 — the app shows both libraries (V-5)

`apps/floor_planner` depends on the restaurant package and passes
`[furnitureSymbolSource, restaurantSymbolSource]`; the palette test sees
the Restaurant categories after the furniture ones.

### Task 9 — results note, STATUS, final review

`docs/superpowers/notes/2026-10-03-plan-14b1-14s-results.md` with every
gate's output summary and the mutants fired; `STATUS.md` head entry;
`roadmap/00-README.md` status row for 14; an independent whole-branch
review, its fixes applied.
