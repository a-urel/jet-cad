# 4b removal inventory — every dependency on the old packages

Date: 2026-10-17 · Worktree `.claude/worktrees/4b-inventory`, branch
`chore/4b-inventory`, cut from `main` at `7f5110ab`.

**Change no code.** This note only maps what depends on
`packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols` and
`apps/floor_planner` (umbrella spec
`docs/superpowers/specs/2026-10-13-kit-architecture-design.md`, A10–A12;
`docs/superpowers/specs/2026-10-16-restaurant-kit-design.md`, "Out of
scope"), so 4b can delete them without breaking anything else.

## 1. Method

The one command, run from the repository root:

```sh
git grep -n -E "jet_cad_floor_plan|jet_cad_restaurant_symbols|floor_planner" \
  | grep -v -E "^(apps/floor_planner/|packages/jet_cad_floor_plan/|packages/jet_cad_restaurant_symbols/|docs/superpowers/)"
```

That excludes the three directories themselves and `docs/superpowers/`
(specs, plans, notes and archived ledgers — they are history, not code).

| | hits | files |
|---|---:|---:|
| every `git grep` hit | 11,482 | — |
| inside the three directories | 1,128 | — |
| under `docs/superpowers/` | 9,764 | — |
| **outside both — this inventory** | **590** | **434** |

The 590 split by the shape of the line:

| shape | hits | meaning |
|---|---:|---|
| a real code/dependency/config line (not a comment) | 163 | §3 — a real edge to the old code |
| `//`, `///` or `#` at the start of the content | 427 | §5 — a provenance comment, no edge |

`git grep` does not show `.pubignore`d or ignored files; nothing in the
removal set is git-ignored, so that is not a gap.

## 2. Classes

- **DEP** — a pubspec dependency/dev_dependency, a workspace member, or a
  font-asset path into the old package.
- **IMPORT** — a Dart `import` (the imported symbols named).
- **TEST-ORACLE** — a test that uses the old package (its code, or a
  fixture exported from it) as the reference the new code is compared
  against.
- **CI** — `.github/workflows/ci.yml`, `tool/ci/*` (scripts, libraries,
  fixtures and their tests).
- **DOC** — README, CHANGELOG, `STATUS*.md`, the host guide, `.vscode`.
- **OTHER** — a guard test or a non-comment code comment that neither
  imports nor depends.

## 3. Actionable hits, by file

One row per file; `Lines` are the hits of the §1 command in that file.

| File | Lines | Class | What it is | Action |
|---|---:|---|---|---|
| `pubspec.yaml` | 17, 18, 19 | DEP | the `workspace:` members `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`, `apps/floor_planner` | remove the three lines |
| `tool/ci/old_host_probe/pubspec.yaml.in` | 18, 25, 40, 43, 45, 48 | DEP | dependency `jet_cad_floor_plan: ^0.7.2`; font asset `packages/jet_cad_floor_plan/fonts/Roboto-Regular.ttf`; `dependency_overrides` on `jet_cad_floor_plan` and `jet_cad_restaurant_symbols` | delete the file with `tool/ci/old_host_probe/` |
| `tool/readme_probe/pubspec.yaml` | 19 | DEP | `jet_cad_floor_plan: ^0.7.2` | delete the dependency together with `lib/planner.dart` (after 4b no package README keeps a probe from the old barrel) |
| `tool/screenshots/pubspec.yaml` | 21, 22, 23, 33 | DEP | `jet_cad_floor_plan: ^0.7.2`; `jet_cad_restaurant_symbols: path: ../../packages/jet_cad_restaurant_symbols`; font asset `packages/jet_cad_floor_plan/fonts/Roboto-Regular.ttf` | re-point the font asset to `packages/jet_cad_2d_plan/fonts/Roboto-Regular.ttf` (exactly as `tool/ci/host_probe/pubspec.yaml.in` already does) and swap the two old deps for `jet_cad_2d_plan` plus the two kits |
| `tool/ci/old_host_probe/lib/main.dart` | 17 | IMPORT | `package:jet_cad_floor_plan/jet_cad_floor_plan.dart` (the probe's whole app) | delete with the probe |
| `tool/readme_probe/lib/planner.dart` | 1, 3 | IMPORT | `package:jet_cad_floor_plan/jet_cad_floor_plan.dart`; the file is `packages/jet_cad_floor_plan/README.md`'s Dart blocks | delete with the planner README case in `check_readmes.dart` |
| `tool/screenshots/test/planner_scenes_test.dart` | 11, 12, 16 | IMPORT · TEST-ORACLE | `jet_cad_floor_plan/jet_cad_floor_plan.dart` and `jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart`; uses `FloorPlanController`, `FloorPlanView`, `FloorPlanTheme`, `FloorPlanMode`, `FloorPlanFloorDrag`, `TableStatus`, `TableGroup`, `FloorPlanColor`, `floorPlanSupportedLocales`, `floorPlanLocalizationsDelegates`, `SymbolLibraryLoader`, `SymbolLibraryReady`, `furnitureSymbolSource`, `restaurantSymbolSource`, `ensureFloorPlanFonts`; writes into `packages/jet_cad_floor_plan/doc/screenshots` | port to `PlanController` / `PlanEditor` / `PlanTheme` / `PlanMode` / `PlanFloorDrag` / `UnitStatus` / `UnitGroup` / `PlanSwatch` / `planSupportedLocales` / `planLocalizationsDelegates` / `PlanSymbolLoader` / the architecture kit's furniture library / `restaurantKit` / `ensurePlanFonts`, and write into `packages/jet_cad_2d_plan/doc/screenshots`. **QUESTION** — that package has no `doc/screenshots` and no `screenshots:` entry yet |
| `tool/screenshots/test/renderer_scenes_test.dart` | 12, 14 | IMPORT · TEST-ORACLE | `jet_cad_floor_plan/editor.dart` (`startupPlan`, `symbolThumbnailDocument`, `searchSymbols`, `symbolIdOf`) and `jet_cad_floor_plan/jet_cad_floor_plan.dart` (`SymbolLibraryLoader`, `SymbolLibraryReady`, `furnitureSymbolSource`); the file writes into `packages/jet_cad_2d_flutter/doc/screenshots` (which stays) | port: `startupPlan` → `buildSampleFlat` (`jet_cad_2d_kit_architecture`); `SymbolLibraryLoader` → `PlanSymbolLoader`; `SymbolLibraryReady` → `SymbolsState.ready`; `furnitureSymbolSource` → the architecture kit's furniture library; `symbolThumbnailDocument(symbol)` exists in `jet_cad_2d_plan/src/symbols/thumbnail_document.dart`. **QUESTION** — `searchSymbols` and `symbolIdOf` have no barrel equivalent in `jet_cad_2d_plan` (the gallery searches through `gallery_model.dart`), so scene R5 has to be rewritten against the gallery widget |
| `tool/screenshots/test/harness_test.dart` | 68, 73 | TEST-ORACLE | `Directory('../../packages/jet_cad_floor_plan/doc/screenshots')` and `shoot(package: 'jet_cad_floor_plan', file: 'probe.png')` — SH3 proves nothing is written without `UPDATE_SCREENSHOTS` | point SH3 at a package that survives, e.g. `jet_cad_2d_flutter`. **QUESTION** — nothing decides which package the harness writes to; it is coupled to `planner_scenes_test.dart`'s `_package` |
| `packages/jet_cad_2d_kit_restaurant/test/catalog_geometry_test.dart` | 2 (comment) | TEST-ORACLE | reads `test/fixtures/old_catalog_geometry.json`, exported once by a one-off script from `jet_cad_restaurant_symbols`; every stored coordinate compared exactly | **keep the copied fixture** — the test names the old package only in its header comment and reads nothing under `packages/` |
| `.github/workflows/ci.yml` | 60, 67, 69, 122, 192, 235 | CI | matrix packages `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`, `apps/floor_planner`; the `web` job's "Build the floor planner"; the `publishable` matrix entry `packages/jet_cad_floor_plan`; a comment | delete those entries and the step (§4) |
| `tool/ci/check_readmes.dart` | 14–16, 20 | CI | reads `tool/ci/old_host_probe/pubspec.yaml.in` for its YAML blocks and `packages/jet_cad_floor_plan/README.md` | drop the `'jet_cad_floor_plan': 'planner'` case and the `yaml:` argument — `packages/jet_cad_floor_plan/README.md` is the *only* package README with a YAML block, so after 4b `readmeProblems` needs no `yaml` |
| `tool/ci/check_screenshots.dart` | 14 | CI | `for (final package in ['jet_cad_2d_flutter', 'jet_cad_floor_plan'])` | remove `jet_cad_floor_plan`. **QUESTION** — substituting `jet_cad_2d_plan` (or a kit) turns the check red on `no screenshots: entry` until the new packages get screenshots and README images, which the old planner's pictures are supposed to become |
| `tool/ci/lib/host_lock.dart` | 88, 89 | CI | `oldProbedFromCommit` (`jet_cad_floor_plan`, `jet_cad_restaurant_symbols`), the `--old` half of `check_host_lock.dart` | delete the list, the `--old` flag, and its `oldProbedFromCommit` use in `check_host_lock.dart` |
| `tool/ci/old_host_probe_resolve.sh` | 38 | CI | `package_root.dart … jet_cad_restaurant_symbols` — copies the restaurant library into the old probe | delete the script |
| `tool/ci/old_host_probe.sh` | (comment, 6) | CI | the old probe's runner | delete the script |
| `tool/ci/test/dependency_lines_test.dart` | 9, 16, 17, 18 | CI test | `published` contains `jet_cad_floor_plan`; `pubspecs` names the three old pubspecs | drop them; **restate DL2's premise** — the count `seen == 20` no longer holds |
| `tool/ci/test/fixtures/host_pre_split.lock.txt` | 204, 207, 213, 216 | CI fixture | a lock holding both old packages | delete (only the removed `--old` path reads it) |
| `tool/ci/test/fixtures/host_post_split.lock.txt` | 154, 157, 163, 166 | CI fixture | same | delete |
| `tool/ci/test/guide_test.dart` | 59, 60, 63, 64 | CI test | GD6 asserts no guide *code block* names the old packages or `FloorPlan*` | keep — it still passes and still guards the guide |
| `tool/ci/test/host_lock_test.dart` | 73, 74, 235, 236, 262, 269, 275, 279, 303, 304 | CI test | `oldProbedFromCommit` and `--old` expectations, over the two lock fixtures | delete those cases with the `--old` path |
| `tool/ci/test/readmes_test.dart` | 15, 55, 60, 62, 65 | CI test | the `jet_cad_floor_plan` case of RM1 and all of RM4 (the old planner's font block) | delete RM4 and the case; RM1 keeps `jet_cad_2d` and `jet_cad_2d_flutter` |
| `tool/ci/test/scripts_test.dart` | 172, 189, 274, 309, 454, 458 | CI test | SC21 (the `--old` lock at a ref), SC21b, SC14 (`old_host_probe_resolve.sh`), SC19 (`old_host_probe.sh`), SC20 (the `packages/jet_cad_floor_plan` matrix entry with `test_flags`) | delete those cases; SC17 and SC18 also break without a grep hit of their own — see §4 |
| `.vscode/launch.json` | 11, 12, 19, 20 | DOC | the `floor_planner: macOS` and `floor_planner: web` configurations with `cwd: apps/floor_planner` | delete both configurations |
| `README.md` | 11, 15 | DOC | the published-packages table lists `jet_cad_floor_plan`; "a host that embeds the planner adds only `jet_cad_floor_plan`" | update to the new line (plan library + kits) |
| `packages/jet_cad_2d/README.md` | 71, 75 | DOC | same table and sentence | update |
| `packages/jet_cad_2d_flutter/README.md` | 82, 86 | DOC | same table and sentence | update |
| `docs/host-guide.md` | 14, 15, 32, 333, 1112, 1114, 1120, 1149 | DOC | §12 "From `jet_cad_floor_plan`": the old-package name-mapping table, its cross-references, and the note that the old guide "stays at the tag `v0.7.2`" | update — keep or trim §12 (GD6 only guards code blocks, so prose is free) |
| `packages/jet_cad_2d_plan/assets/fonts/README.md` | 6, 9 | DOC | attributes `Roboto-Regular.ttf` to "Source: `packages/jet_cad_floor_plan/lib/fonts/Roboto-Regular.ttf`" | update the attribution — the cited source path disappears (keep the SHA-256 and the licence) |
| `STATUS.md` | 395, 517, 539, 663, 670, 686, 688, 711, 712, 740, 785, 787, 788, 800, 801, 804, 825, 828, 832, 856, 861, 1045, 1067, 1068 | DOC | the live status: package list, publish order, gates, the repository tree | update |
| `CHANGELOG.md` | 10, 11, 20, 144, 350, 389, 513, 524, 590, 644, 691, 714 | DOC | release history | keep (history) |
| `STATUS-HISTORY.md` | 316, 317, 341, 613, 1445, 1469, 1575, 1606, 1705, 1738, 1817, 1847, 1927, 1996, 2082, 2143, 2226, 2281, 2367, 2428, 2485, 2503, 2550, 2570, 2585, 2603, 2626 | DOC | archived status log | keep |
| `packages/jet_cad_2d/CHANGELOG.md` | 64 | DOC | release history | keep |
| `packages/jet_cad_2d_kit_architecture/CHANGELOG.md` | 4 | DOC | "leaves `jet_cad_floor_plan` unchanged in behaviour (sub-project 3a)" | keep |
| `packages/jet_cad_2d_kit_restaurant/CHANGELOG.md` | 4 | DOC | "the restaurant symbol catalog of `jet_cad_restaurant_symbols`" | keep |
| `apps/restaurant_demo/README.md` | 6, 7 | DOC | "It names neither `jet_cad_floor_plan` nor `jet_cad_restaurant_symbols`" | keep — still true |
| `apps/restaurant_demo/analysis_options.yaml` | 1 | DOC | comment: "the demo's lints: the app's (`apps/floor_planner`)" | repoint to an app that survives (`apps/architecture_demo`) |
| `apps/restaurant_demo/pubspec.yaml` | 13 | DOC | comment: "see `apps/floor_planner`'s pubspec" | repoint |
| `roadmap/01-app-skeleton.md` | 12, 61 | DOC | the roadmap's sub-project 01 targets `apps/floor_planner` | keep — a roadmap file is an input to brainstorming, never code |
| `apps/architecture_demo/test/boundary_test.dart` | 6 | OTHER (guard) | `const _banned = ['jet_cad_floor_plan', 'jet_cad_restaurant_symbols']` | keep — asserts the app's own pubspec and Dart stay clean; still passes |
| `apps/restaurant_demo/test/boundary_test.dart` | 7 | OTHER (guard) | the same guard | keep |
| `packages/jet_cad_2d_kit_architecture/test/dimension/dimension_live_test.dart` | 107 | OTHER (guard) | `expect(components.keys, isNot(contains('floor_planner.dimension')))` | keep — guards the new kit's type-id space against the old one |
| `packages/jet_cad_2d_integration/test/panels/colour_row_test.dart` | 78 | OTHER | a trailing code comment citing `jet_cad_floor_plan/lib/src/parametric/room.dart:125` | keep |
| `packages/jet_cad_2d_integration/test/panels/wall_section_test.dart` | 42 | OTHER | a trailing code comment citing `…/parametric/wall.dart:35` | keep |

Every `IMPORT` and `TEST-ORACLE` above is listed with one proposed action.
Two are **QUESTION** where the new home is not obvious and the decision is
not mine: the screenshot scenes (`planner_scenes_test.dart`,
`renderer_scenes_test.dart` R5) and the harness's target package. The
restaurant kit's `catalog_geometry_test.dart` keeps its copied fixture.

## 4. tool/ci checks that break, and why

| Check | Breaks because | Minimum fix |
|---|---|---|
| `dart run tool/ci/check_readmes.dart` | reads `tool/ci/old_host_probe/pubspec.yaml.in` (deleted) and `packages/jet_cad_floor_plan/README.md` (deleted) — a `FileSystemException` before any comparison | drop the `jet_cad_floor_plan` case and the `yaml:` input (it was the only package with a YAML block) |
| `dart run tool/ci/check_screenshots.dart` | iterates `['jet_cad_2d_flutter', 'jet_cad_floor_plan']` and reads the deleted package's `pubspec.yaml`, `README.md` and `.pubignore` | remove `jet_cad_floor_plan`; naming a new package instead needs its `screenshots:` entry and README images first (**QUESTION**) |
| `dart run tool/ci/check_host_lock.dart` (+ `lib/host_lock.dart`) | `oldProbedFromCommit` and the `--old` path are built for `old_host_probe_resolve.sh`, which goes; nothing can produce that lock afterwards | delete `oldProbedFromCommit`, the `--old` flag and `old_host_probe*` |
| **DL1** (`dependency_lines_test.dart`) | `published` still lists `jet_cad_floor_plan`: after 4b no live pubspec may name it, so the *guard* is moot but harmless; and `pubspecs` names three deleted files, read with `File(...).readAsStringSync()` | drop the three paths and the name |
| **DL2** | the premise asserts `seen == 20` hosted constraints over the listed pubspecs; deleting the old pubspecs and the old deps of `tool/screenshots` lowers it | re-derive and restate the number |
| **SC14** (`scripts_test.dart`) | enumerates both `host_probe.sh` and `old_host_probe_resolve.sh` in a loop; the deleted file cannot be read | drop the `old` arm of the loop |
| **SC16** | `live` is every directory under `packages/` with a pubspec (less the dormant `jet_cad`); with the two old packages gone from both the tree and the matrix it keeps passing | none (verify) |
| **SC17** | asserts `builds == 2` — "premise: the demo and the floor planner" — and one assertion per `flutter build web`; removing the floor-planner build leaves 1 | re-derive the premise (1 build) |
| **SC18** | asserts the `host-probe` job runs `tool/ci/host_probe.sh` and then `old_host_probe.sh v0.3.0` / `v0.4.0`; those steps go | delete the released-probe assertion, or move it to the new probe |
| **SC20** | requires the `packages/jet_cad_floor_plan` matrix entry with `test_flags: --enable-vmservice`; the entry goes (SC20b already carries the flag for `packages/jet_cad_2d_plan`) | delete SC20 |
| **SC21 / SC21b** | run `check_host_lock.dart --old` with `host_post_split.lock.txt` and assert `jet_cad_floor_plan` appears in the output | delete with the `--old` path and the fixture |
| **SC19** | runs `old_host_probe.sh` in a scratch repository and reads the current `lib/main.dart`; the script goes | delete |
| **RM1 / RM4** (`readmes_test.dart`) | the `jet_cad_floor_plan` case reads the deleted README and the `planner.dart` probe | delete RM4 and the case |
| **`host_lock_test.dart`** | `--old` and `oldProbedFromCommit` expectations, plus the two lock fixtures | delete those cases |
| **`.github/workflows/ci.yml` matrix** | three entries name deleted directories — the `package` job's `working-directory` and the `publishable` job's `cmp LICENSE` / `dart pub publish --dry-run` fail on a missing directory | delete the three entries (60, 67, 69) and 192, and the `web` step 121–125 |

**Not broken, checked deliberately:**

- `dart run tool/ci/check_guide.dart` — reads `docs/host-guide.md` and
  `tool/ci/host_probe/pubspec.yaml.in`, neither of which is removed.
- **GD6** (`guide_test.dart`) — asserts no guide code block names the old
  packages; removing the old code only keeps it green.
- `dart run tool/ci/check_kit_deps.dart` — no old-package reference.
- **SS1–SS13** (`screenshots_test.dart`) — synthetic pubspec/README
  fixtures under `_pkg = 'jet_cad_2d_flutter'`; no filesystem dependency.
- `tool/ci/expect_failures.dart` with `standing_failures.txt` /
  `standing_skips.txt` — neither standing list names the old packages; but
  removing the two matrix entries removes the packages whose results were
  compared, so both lists stay untouched.
- The `apps/architecture_demo` and `apps/restaurant_demo` `boundary_test`
  guards — they ban the names and scan only their own app.

## 5. Provenance comments (class OTHER) — no code edge

427 of the 590 hits (422 after the five footnoted below move into §3) are
`//`, `///` or `#` lines that name an old package or `floor_planner` as the
*origin* of code that has already been ported. They create no dependency:
after 4b they are a dangling citation, not a build break. One row per file;
`Lines` are the hits in that file.

Five of the 427 `#`-shaped lines carry the comment marker but belong to
files §3 already lists for a real reason — a markdown heading, a YAML
line, a shell line inside a fenced block, a CI comment — so they are
counted with those files in §3, not here:
`docs/host-guide.md:1112` (the `## 12.` heading),
`.github/workflows/ci.yml:235` (a CI comment),
`STATUS.md:1045` (a shell line in a fenced block),
`apps/restaurant_demo/pubspec.yaml:13` and
`tool/ci/old_host_probe/pubspec.yaml.in:1`.

| File | Hits | Lines |
|---|---:|---|
| `apps/architecture_demo/lib/document_host.dart` | 1 | 4 |
| `apps/architecture_demo/lib/document_session.dart` | 1 | 2 |
| `apps/architecture_demo/test/app_words_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_commands_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_exit_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_files_kind_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_files_sources_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_files_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_host_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_open_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_replace_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_save_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_separator_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/document_settle_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/export/export_end_to_end_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/export/export_flow_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/export/export_font_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/export/print_flow_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/layers/layers_end_to_end_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/symbols/symbol_library_loader_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/symbols/symbol_palette_end_to_end_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/symbols/symbol_section_end_to_end_test.dart` | 1 | 1 |
| `apps/architecture_demo/test/symbols/symbol_shell_test.dart` | 1 | 1 |
| `apps/restaurant_demo/analysis_options.yaml` | 1 | 1 |
| `packages/jet_cad_2d_flutter/test/support/export_fixture.dart` | 1 | 91 |
| `packages/jet_cad_2d_integration/test/attach/against_wall_rotate_test.dart` | 1 | 13 |
| `packages/jet_cad_2d_integration/test/attach/editor_tools_review_test.dart` | 1 | 9 |
| `packages/jet_cad_2d_integration/test/attach/symbol_shell_test.dart` | 1 | 9 |
| `packages/jet_cad_2d_integration/test/attach/wall_attach_end_to_end_test.dart` | 1 | 19 |
| `packages/jet_cad_2d_integration/test/attach/wall_attach_tool_test.dart` | 1 | 12 |
| `packages/jet_cad_2d_integration/test/box/planner_box_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/canvas/planner_grips_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/canvas/touch_tools_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/controller/delete_components_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/controller/zone_room_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_integration/test/dimension/dimension_paint_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/dimension/dimension_plans.dart` | 1 | 5 |
| `packages/jet_cad_2d_integration/test/dimension/dimension_shell_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/dimension/dimension_tool_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_integration/test/editor/architecture_palette_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/editor/editor_panels_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/export/room_export_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_integration/test/l10n/determinism_test.dart` | 1 | 12 |
| `packages/jet_cad_2d_integration/test/l10n/leak_test.dart` | 1 | 8 |
| `packages/jet_cad_2d_integration/test/l10n/locale_separator_test.dart` | 1 | 4 |
| `packages/jet_cad_2d_integration/test/l10n/numbered_names_test.dart` | 1 | 4 |
| `packages/jet_cad_2d_integration/test/l10n/overflow_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_integration/test/l10n/panel_words_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_integration/test/layers/layer_picker_types_test.dart` | 1 | 4 |
| `packages/jet_cad_2d_integration/test/layers/layer_picker_wall_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/layers/placer_layer_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/opening/opening_grips_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/opening/opening_kink_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/opening/opening_paint_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/opening/opening_symbol_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/opening/opening_tool_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/panels/decimal_separator_test.dart` | 1 | 17 |
| `packages/jet_cad_2d_integration/test/panels/selection_page_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/panels/wall_section_test.dart` | 1 | 4 |
| `packages/jet_cad_2d_integration/test/room/room_color_test.dart` | 1 | 14 |
| `packages/jet_cad_2d_integration/test/room/room_grips_test.dart` | 1 | 18 |
| `packages/jet_cad_2d_integration/test/room/room_paint_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/room/room_panel_test.dart` | 2 | 12,215 |
| `packages/jet_cad_2d_integration/test/room/room_tool_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_integration/test/sample/sample_flat_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_integration/test/scaffold/prepare_test.dart` | 1 | 11 |
| `packages/jet_cad_2d_integration/test/separator/separator_dashed_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/separator/separator_export_test.dart` | 2 | 2,6 |
| `packages/jet_cad_2d_integration/test/separator/separator_plans.dart` | 2 | 4,123 |
| `packages/jet_cad_2d_integration/test/separator/separator_shell_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/service/room_fill_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_integration/test/shell/planner_shell_test.dart` | 2 | 1,53 |
| `packages/jet_cad_2d_integration/test/shortcuts/keyboard_focus_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/support/attach_plans.dart` | 4 | 1,109,168,172 |
| `packages/jet_cad_2d_integration/test/support/editor_fixture.dart` | 2 | 1,63 |
| `packages/jet_cad_2d_integration/test/support/editor_rig.dart` | 1 | 144 |
| `packages/jet_cad_2d_integration/test/support/fill_plan.dart` | 1 | 4 |
| `packages/jet_cad_2d_integration/test/support/layer_plan.dart` | 2 | 1,239 |
| `packages/jet_cad_2d_integration/test/support/opening_support.dart` | 6 | 4,194,203,214,240,246 |
| `packages/jet_cad_2d_integration/test/support/plans.dart` | 1 | 5 |
| `packages/jet_cad_2d_integration/test/support/q0_plan.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/support/recording_plan_strings.dart` | 1 | 3 |
| `packages/jet_cad_2d_integration/test/support/room_plans.dart` | 1 | 2 |
| `packages/jet_cad_2d_integration/test/support/rooms_plan.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/support/wall_fixture.dart` | 2 | 1,20 |
| `packages/jet_cad_2d_integration/test/support/wall_shell.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/support/zone_plan.dart` | 1 | 4 |
| `packages/jet_cad_2d_integration/test/symbols/symbol_search_test.dart` | 1 | 14 |
| `packages/jet_cad_2d_integration/test/wall/wall_grips_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/wall/wall_paint_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_integration/test/wall/wall_tool_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit/lib/src/authoring/builder.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit/lib/src/authoring/catalog.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit/lib/src/authoring/shapes.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit/lib/src/kit/swatch.dart` | 1 | 4 |
| `packages/jet_cad_2d_kit/lib/src/kit/unit_label.dart` | 1 | 5 |
| `packages/jet_cad_2d_kit/lib/src/model/kit_names.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit/lib/src/model/symbol_box.dart` | 1 | 137 |
| `packages/jet_cad_2d_kit/lib/src/model/symbol_component.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit/lib/src/model/symbol_library.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit/lib/src/model/unit_component.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit/test/kit/swatch_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit/test/kit/unit_label_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit/test/model/merge_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit/test/model/register_test.dart` | 1 | 4 |
| `packages/jet_cad_2d_kit/test/model/symbol_box_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_kit/test/model/symbol_component_test.dart` | 1 | 4 |
| `packages/jet_cad_2d_kit/test/model/unit_component_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit/test/support/library_fixtures.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit/test/support/placements.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_attach.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_faces.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit_architecture/lib/src/box/box.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/box/box_plan.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit_architecture/lib/src/box/box_tool.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension.dart` | 2 | 9,13 |
| `packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_attach.dart` | 1 | 7 |
| `packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_geometry.dart` | 1 | 5 |
| `packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_grips.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_plan.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_tool.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_catalog.dart` | 2 | 2,8 |
| `packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_names.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_source.dart` | 1 | 4 |
| `packages/jet_cad_2d_kit_architecture/lib/src/ids.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/live.dart` | 1 | 4 |
| `packages/jet_cad_2d_kit_architecture/lib/src/opening/opening.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_geometry.dart` | 2 | 9,14 |
| `packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_grips.dart` | 1 | 42 |
| `packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_plan.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_tool.dart` | 1 | 99 |
| `packages/jet_cad_2d_kit_architecture/lib/src/room/room.dart` | 1 | 8 |
| `packages/jet_cad_2d_kit_architecture/lib/src/room/room_grips.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/lib/src/room/room_inputs.dart` | 1 | 5 |
| `packages/jet_cad_2d_kit_architecture/lib/src/room/room_label.dart` | 1 | 5 |
| `packages/jet_cad_2d_kit_architecture/lib/src/room/room_plan.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/room/room_tool.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/lib/src/room/room_trace.dart` | 1 | 11 |
| `packages/jet_cad_2d_kit_architecture/lib/src/sample/sample_flat.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/lib/src/separator/separator.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/lib/src/separator/separator_grips.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/separator/separator_plan.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit_architecture/lib/src/separator/separator_tool.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/separator_linetype.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/type_naming.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit_architecture/lib/src/words/de.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/words/en.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/lib/src/words/tr.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/test/box/box_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/dimension/dimension_plan_test.dart` | 1 | 7 |
| `packages/jet_cad_2d_kit_architecture/test/furniture/furniture_library_test.dart` | 2 | 1,584 |
| `packages/jet_cad_2d_kit_architecture/test/furniture/package_assets_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/furniture/symbol_box_asset_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/test/furniture/symbol_end_to_end_test.dart` | 1 | 74 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_cost_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_cut_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_end_drag_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_geometry_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_grips_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_kink_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_object_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_obstacle_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_params_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_plan_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_symbol_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/opening/opening_tool_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/room/decimal_separator_test.dart` | 1 | 14 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_color_test.dart` | 1 | 14 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_cost_test.dart` | 1 | 8 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_diagnostics_test.dart` | 1 | 11 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_dissolve_test.dart` | 1 | 13 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_follow_test.dart` | 1 | 17 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_grips_test.dart` | 1 | 17 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_inputs_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_label_test.dart` | 1 | 6 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_localise_test.dart` | 1 | 7 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_object_test.dart` | 1 | 14 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_tie_test.dart` | 1 | 14 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_tint_test.dart` | 1 | 6 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_tool_test.dart` | 1 | 15 |
| `packages/jet_cad_2d_kit_architecture/test/room/room_trace_test.dart` | 1 | 6 |
| `packages/jet_cad_2d_kit_architecture/test/sample/sample_flat_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/separator/separator_plan_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_kit_architecture/test/separator/separator_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit_architecture/test/separator/separator_tool_test.dart` | 1 | 14 |
| `packages/jet_cad_2d_kit_architecture/test/support/catalog.dart` | 1 | 3 |
| `packages/jet_cad_2d_kit_architecture/test/support/dimension_fixture.dart` | 1 | 8 |
| `packages/jet_cad_2d_kit_architecture/test/support/opening_fixture.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/support/room_fixture.dart` | 1 | 8 |
| `packages/jet_cad_2d_kit_architecture/test/support/select_rig.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/support/wall_fixture.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/support/wall_shell.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/wall/wall_bands_test.dart` | 1 | 7 |
| `packages/jet_cad_2d_kit_architecture/test/wall/wall_geometry_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/wall/wall_grips_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/wall/wall_joint_kinds_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_architecture/test/wall/wall_params_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/wall/wall_regen_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/wall/wall_tool_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_architecture/test/words/value_words_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_restaurant/lib/src/catalog/bar.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_restaurant/lib/src/catalog/booths.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_restaurant/lib/src/catalog/kitchen.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_restaurant/lib/src/catalog/outdoor.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_restaurant/lib/src/catalog/restaurant_catalog.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_restaurant/lib/src/catalog/service.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_restaurant/lib/src/catalog/tables.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_restaurant/lib/src/restaurant_names.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_restaurant/test/catalog_geometry_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_kit_restaurant/test/library/restaurant_symbols_port_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_kit_restaurant/test/restaurant_words_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart` | 1 | 6 |
| `packages/jet_cad_2d_plan/lib/src/controller/camera_bounds.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/controller/grip_dispatch.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/controller/new_plan.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/controller/plan_camera.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` | 2 | 4,860 |
| `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/editor/plan_editor_bar.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/editor/plan_tool_palette.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/editor/unit_inspector.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/export/builtin_exporters.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/export/editor_page_flows.dart` | 1 | 10 |
| `packages/jet_cad_2d_plan/lib/src/export/export_dialog.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/export/export_font.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/lib/src/export/page_flows.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/export/page_printer.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/lib/src/export/unit_colour_underlay.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/fonts/plan_fonts.dart` | 1 | 9 |
| `packages/jet_cad_2d_plan/lib/src/kits/locks.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/lib/src/l10n/document_separator.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/lib/src/l10n/localizations.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/l10n/number_text.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/lib/src/l10n/numbered_names.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/lib/src/l10n/panel_number.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/lib/src/l10n/search_fold.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/lib/src/l10n/strings.dart` | 1 | 6 |
| `packages/jet_cad_2d_plan/lib/src/l10n/strings_de.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/l10n/strings_en.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/l10n/strings_tr.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/panels/colour_row.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/panels/frame_safe_relay.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/lib/src/panels/layer_picker.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/panels/layer_row.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/lib/src/panels/panel_focus.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/lib/src/panels/plan_layer_panel.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/panels/plan_page_panel.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart` | 1 | 8 |
| `packages/jet_cad_2d_plan/lib/src/panels/plan_symbol_gallery.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/panels/unit_section.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/service/paint/unit_focus_painter.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/lib/src/service/paint/unit_group_painter.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/lib/src/service/paint/unit_status_painter.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/lib/src/service/service_record.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/lib/src/service/service_session.dart` | 1 | 7 |
| `packages/jet_cad_2d_plan/lib/src/service/service_state.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/service/service_tool.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/service/unit_picker.dart` | 1 | 6 |
| `packages/jet_cad_2d_plan/lib/src/service/view/plan_service_bar.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/service/view/plan_service_view.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/service/view/unit_overlays.dart` | 1 | 6 |
| `packages/jet_cad_2d_plan/lib/src/shortcuts/chords.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcut_guard.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcuts.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/symbols/gallery_model.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/symbols/symbol_placer.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/lib/src/theme/plan_theme.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/tools/move_resolver.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/units/unit_components.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/units/unit_detail.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/lib/src/units/unit_fit.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/lib/src/units/unit_index.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/lib/src/units/unit_label.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/units/unit_label_system.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/units/unit_numbers.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/lib/src/units/unit_problems.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/lib/src/units/unit_rotate.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/test/barrel_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/test/canvas/canvas_camera_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/canvas/canvas_draw_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/canvas/canvas_layout_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/canvas/canvas_palette_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/canvas/canvas_ui_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/canvas/dark_canvas_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/canvas/theme_canvas_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/canvas/touch_tools_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/canvas/view_palette_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/controller/camera_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/test/controller/locale_separator_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/test/controller/mode_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/controller/new_plan_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/controller/non_finite_unit_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/controller/permissions_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/test/controller/plan_change_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/test/controller/plan_controller_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/test/controller/service_record_controller_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/test/controller/service_state_controller_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/controller/unit_camera_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/controller/unit_changes_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/controller/unit_colour_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/controller/unit_data_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/controller/unit_detail_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/controller/unit_groups_controller_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/editor/editor_bar_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/test/editor/editor_modes_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/editor/editor_options_test.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/test/editor/editor_separator_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/test/editor/editor_service_view_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/editor/editor_theme_test.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/test/editor/editor_view_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/test/editor/editor_words_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/test/editor/palette_draw_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/editor/unit_inspector_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/editor/units_only_select_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/export/export_font_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/test/export/page_flows_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/test/export/unit_colour_export_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/fonts/fonts_register_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/test/fonts/plan_assets_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/test/invariants/band_allocation_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/invariants/pick_allocation_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/invariants/theme_colours_test.dart` | 1 | 8 |
| `packages/jet_cad_2d_plan/test/invariants/vm_allocation_meter.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/l10n/document_separator_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/test/l10n/l10n_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/test/l10n/layer_page_words_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/l10n/numbered_names_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/test/l10n/stale_error_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/l10n/value_words_test.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/test/panels/colour_row_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/panels/hover_removal_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/panels/layer_panel_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/panels/layer_picker_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/panels/page_panel_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/panels/page_panel_theme_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/panels/page_scale_field_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/panels/plan_symbol_gallery_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/panels/selection_page_test.dart` | 2 | 1,4 |
| `packages/jet_cad_2d_plan/test/panels/selection_panel_test.dart` | 2 | 1,4 |
| `packages/jet_cad_2d_plan/test/panels/symbol_section_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/panels/unit_section_test.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/test/service/paint/unit_fill_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/paint/unit_focus_painter_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/paint/unit_group_painter_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/paint/unit_status_painter_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/paint/unit_theme_painter_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/service_band_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/service_events_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/service_record_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/service_state_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/service_tool_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/unit_picker_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/band_view_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/service_bar_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/service_keys_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/service_options_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/status_caption_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/theme_service_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/unit_fill_view_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/unit_groups_context_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/unit_groups_gesture_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/unit_groups_look_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/unit_groups_toolbar_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/unit_overlay_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/service/view/view_events_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/shortcuts/host_text_keys_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/shortcuts/plan_shortcuts_test.dart` | 1 | 53 |
| `packages/jet_cad_2d_plan/test/support/canvas_fixture.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/support/editor_host.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/test/support/recording_plan_strings.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/test/support/service_paint.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/test/support/service_plans.dart` | 1 | 6 |
| `packages/jet_cad_2d_plan/test/support/symbol_fixtures.dart` | 1 | 3 |
| `packages/jet_cad_2d_plan/test/support/unit_editor_fixture.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/support/unit_embedding_fixture.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/support/unit_fixtures.dart` | 1 | 4 |
| `packages/jet_cad_2d_plan/test/support/unit_zone_fixture.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/symbols/symbol_box_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/test/symbols/symbol_ghost_test.dart` | 1 | 2 |
| `packages/jet_cad_2d_plan/test/symbols/unit_copy_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/theme/plan_theme_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/theme/theme_service_mode_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/tools/plan_symbol_tool_test.dart` | 1 | 5 |
| `packages/jet_cad_2d_plan/test/units/unit_components_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/units/unit_data_delete_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/units/unit_fit_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/units/unit_index_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/units/unit_label_system_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/units/unit_label_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/units/unit_numbers_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/units/unit_placement_test.dart` | 1 | 1 |
| `packages/jet_cad_2d_plan/test/units/unit_rotate_test.dart` | 1 | 1 |
| `tool/ci/lib/host_lock.dart` | 1 | 84 |
| `tool/ci/old_host_probe.sh` | 1 | 6 |
| `tool/ci/old_host_probe/lib/main.dart` | 1 | 2 |
| `tool/ci/old_host_probe_resolve.sh` | 2 | 3,6 |
| `tool/readme_probe/lib/planner.dart` | 1 | 1 |
| `tool/screenshots/test/planner_scenes_test.dart` | 1 | 3 |

## 6. Open questions (not decided here)

1. **Which package do the screenshot scenes write to?** The old planner's
   `doc/screenshots` is deleted with it; `Planner scenes` P1–P6 and the
   harness's SH3 must name a surviving package. Which one (presumably
   `jet_cad_2d_plan`), and does the new set get a `screenshots:` entry and
   README images so `check_screenshots.dart` can keep its second package?
2. **`renderer_scenes_test.dart` R5.** `searchSymbols(entries, q)` and
   `symbolIdOf(entry)` are old-barrel helpers with no equivalent exported
   from `jet_cad_2d_plan`; the new search lives inside
   `plan_symbol_gallery.dart`/`gallery_model.dart`. Is R5 rewritten over
   the gallery widget, or dropped?
3. **The old host probe.** `old_host_probe*`, `oldProbedFromCommit`, the
   `--old` flag, the two lock fixtures and SC14/SC19/SC20/SC21/SC21b go
   together. Does the released-host analysis (`old_host_probe.sh v0.3.0`…
   `v0.6.0`, SC18) move to the new `host_probe` against the old tags, or
   does the guard end with 4b?
4. **`docs/host-guide.md` §12.** Keep the old-name mapping table after the
   packages are gone (`GD6` only guards code blocks), or trim it to a
   pointer at the `v0.7.2` tag?

Nothing here changes code. Every §3 row is the whole of the dependency:
no hit is a symbol used from the old packages that has no new home, except
the two `QUESTION` rows above.
