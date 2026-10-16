# Task 11 report: wall geometry, bands and parameters

Status: DONE. Commit `543d1bf2 feat(architecture): the wall's parameters, geometry and band cache (3a C3.2)` on `feat/architecture-kit` (parent 711889c1).

## Implementation summary

Every file was produced by a small Python script that copied the old line's file and applied only the brief's named edits, asserting each anchor line first, then checked with `diff` against the source.

- `lib/src/wall/wall.dart` ← `jet_cad_floor_plan/lib/src/parametric/wall.dart:1-286`:
  - imports `:4-6` → `'../ids.dart'`, `'wall_geometry.dart'`;
  - `componentTypeId = ArchitectureTypes.wall`;
  - `:172-189` deleted (`contributesPlace`, `placeBox`, `placeInput`), along with the blank line `:190` so no double blank is left;
  - `generate`'s doc comment replaced with the brief's text;
  - `:203` (`_cut` call) and `:215-239` (`_cut`) deleted.
  - Everything else is byte-identical (checked with `diff`).
- `lib/src/wall/wall_geometry.dart` ← `wall_geometry.dart:1-623` unchanged except the import block (adds `../ids.dart`, `../live.dart show LiveTypeOf`). The brief's adapter section is appended verbatim:
  - `wallsInView` (opening_geometry.dart:600-616);
  - `wallsInDocument(doc, host, LiveTypeOf live, {moved})`, which asks `live(h) == ArchitectureTypes.wall` for the host and for every other holder.
- `lib/src/wall/wall_bands.dart` ← `wall_bands.dart:1-177`:
  - new imports, including the contract's `show Disposable, PlanServices`;
  - `wallBandsOf(services)` = `services.shared<WallBands>((s) => WallBands(liveTypesOf(s)))`;
  - the class doc line changed;
  - `WallBands(this._live)` with `final LiveTypeOf _live`, and `implements Disposable`;
  - the `_refresh` comment rewrapped, and its loop now calls `liveObjectsOf<WallParams>(doc, _live, ArchitectureTypes.wall)`;
  - `dispose`'s doc changed and `@override` added.
  - Stride, cache, `generation`, `invalidate`, `liveWalls`, `_indexAt`, `hostAt`, `joinInto` and the subscription are unchanged.
- `test/support/catalog.dart`: the wall's import, and `..register<WallParams>(...)` appended after the box's.
- `test/support/wall_fixture.dart` ← old fixture `:1-301`:
  - header added and imports changed as the brief gives;
  - `liveOf(doc, {frozen})` inserted after `wallDoc`;
  - `parametricCatalog` → `testCatalog()` in `driftOf`, `diagnosticsOf` and `reload`;
  - the three "floor planner's" doc comments reworded as the brief gives.
- Barrel untouched (Task 12 exports `WallParams`/`Justification`).

## TDD evidence

RED. The tests were written; `lib/src/wall/` was moved out of the package temporarily with `mv` (lossless, then moved back). Then I ran `flutter test test/wall/`. Every file failed to load (excerpt):

```
Compilation failed for testPath=.../test/wall/wall_params_test.dart: test/wall/wall_params_test.dart:2:8: Error: Error when reading 'lib/src/wall/wall.dart': No such file or directory
test/wall/wall_bands_test.dart:9:8: Error: Error when reading 'lib/src/wall/wall_bands.dart': No such file or directory
test/wall/wall_live_test.dart:12:8: Error: Error when reading 'lib/src/wall/wall_geometry.dart': No such file or directory
test/wall/wall_regen_test.dart:7:8: Error: Error when reading 'lib/src/wall/wall_geometry.dart': No such file or directory
```

Honesty note: I wrote the lib files before the tests in time, so this RED was produced by removing the lib, not by running before writing it.

GREEN. `dart format .` printed `Formatted 29 files (0 changed)`. Then `flutter test test/wall/`:
```
WG14 nodes 20000 with a hole 152 (0.76%); walls 49887 fell back 54 (0.11%)
00:00 +44: All tests passed!
```
That is 44 tests, as the brief expects.

## Gates

Kit `packages/jet_cad_2d_kit_architecture`:
- `flutter test` → `00:01 +58: All tests passed!` (also re-run at HEAD after the mutations).
- `flutter analyze` → `No issues found! (ran in 2.7s)`. No strict-analysis findings in the ported lines.
- `dart format --output=none --set-exit-if-changed .` → `Formatted 29 files (0 changed)`, exit 0.
- `dart pub publish --dry-run`:
  - before the commit: `Package has 1 warning.` The warning was only "1 checked-in file is modified in git: test/support/catalog.dart" (uncommitted state).
  - after the commit: `Package has 0 warnings.`

Repository root:
- `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0.
- `git status --short` after the commit and after the mutations: empty. No `analysis_options.yaml` change.

## Mutations

Each mutation was applied to a committed file. I ran the named test, saw it red, then reverted with `git checkout -- <file>`; `git diff --quiet -- <file>` exited 0 after each one.

| Id | File | Red test | Red line |
|---|---|---|---|
| M-WL-1 | `wall_bands.dart`, `_refresh` → `doc.components.withComponent<WallParams>()` | WL1 and WL3 | WL1 `Expected: [1300, 2600]` / `Actual: [1300, 2600, 3900, 5100]` (`wall_live_test.dart 69:5`); WL3 the same (`125:5`) |
| M-WL-2 | `wall_geometry.dart`, host guard deleted | WL2 | `Expected: null` / `Actual: ({WorldWall host, ...})` (`94:5`) |
| M-WL-3 | `wall_geometry.dart`, `if (h != host)` | WL2 | `Expected: [2600]` / `Actual: [2600, 3900, 5100]` (`98:5`) |
| M-WL-4 | `wallBandsOf` → `WallBands(liveTypesOf(services))` | WL3 | `Expected: true` / `Actual: <false>` (`124:5`, `identical`) |
| M-WL-5 | `WallBands` not `Disposable`, `@override` removed | WL3 | `Expected: <2>` / `Actual: <3>` (`137:5`, generation moved after dispose) |
| M-WL-6 | `wallBandsOf` ignores the services' live answer | WL3 | `Expected: [1300, 2600]` / `Actual: [1300, 2600, 3900, 5100]` (`125:5`) |
| M-WL-7 | `componentTypeId = 'floor_planner.wall'` | WP1 | `Expected: 'architecture.wall'` / `Actual: 'floor_planner.wall'` (`wall_params_test.dart 20:5`) |

All seven ran exactly as written.

## Ported-test accounting

Every assertion is unchanged except WP1's two id lines (C7 class 1). All four files carry the A11-imports change and a `// Ported from ...` line: the first line in three files, the last line of the existing header in `wall_bands_test`.

| Old file | Cases | New file | Change class |
|---|---|---|---|
| `wall_params_test.dart` | WP1-WP5 | `test/wall/wall_params_test.dart` | imports; WP1 `:19`, `:20` `'floor_planner.wall'` → `'architecture.wall'` (C7 class 1, ids) |
| `wall_geometry_test.dart` | WG1-WG21 | `test/wall/wall_geometry_test.dart` | imports only |
| `wall_bands_test.dart` | WB1, WB2 | `test/wall/wall_bands_test.dart` | imports; `WallBands()` → `WallBands(liveOf(doc))` twice (a fixture change the brief names) |
| `wall_regen_test.dart` | WR1-WR13 | `test/wall/wall_regen_test.dart` | imports (catalog, startup_plan and jet_cad_2d_flutter removed); WR9 `:497-501` replaced by the R11-1 comment, a line carried to Task 25 |

Non-ASCII check: `grep -c "°"` counts 15 in `wall_geometry_test.dart` and 12 in `wall_regen_test.dart`, the same as the sources. A full `diff` against each source shows only the lines listed above.

New: `test/wall/wall_live_test.dart` (WL1-WL3), copied verbatim from the brief by extracting the code block (no hand edits).

## Files changed (all under `packages/jet_cad_2d_kit_architecture/`)

- A `lib/src/wall/wall.dart`
- A `lib/src/wall/wall_geometry.dart`
- A `lib/src/wall/wall_bands.dart`
- M `test/support/catalog.dart`
- A `test/support/wall_fixture.dart`
- A `test/wall/wall_params_test.dart`
- A `test/wall/wall_geometry_test.dart`
- A `test/wall/wall_bands_test.dart`
- A `test/wall/wall_regen_test.dart`
- A `test/wall/wall_live_test.dart`

## Deviations

- `wall.dart`: besides `:172-189`, I also dropped the blank line `:190`, so deleting the hooks leaves one blank line, not two. Whitespace only; `dart format` would collapse it anyway.
- Not a code deviation: the RED step was demonstrated by moving the already-written lib aside (see the TDD note above).

## Concerns

- `test/support/catalog.dart`'s header comment still reads "(this task the box's)", which is Task 10's wording. The brief names no change to it, so I left it.
