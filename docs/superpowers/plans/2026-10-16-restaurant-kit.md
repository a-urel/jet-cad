# The restaurant kit and a POS-ready plan library (4a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `jet_cad_2d_kit_restaurant`, the plan library's POS gaps closed,
`apps/restaurant_demo` on the new packages, the parity table closed and
the host guide rewritten.

**Architecture:** The restaurant kit is a symbol-only kit built with the
contract's authoring toolkit, like the architecture kit's furniture
library; its 25 seated symbols carry `UnitComponent`s. The plan library
gains small host-facing pieces (H1-H4, O1-O4). The demo is rewritten in
place over two `PlanController`s with `[architectureKit, restaurantKit]`;
its sample plans are `PlanBuild`s in the app.

**Tech Stack:** Dart/Flutter workspace; `jet_cad_2d_kit` (authoring,
conformance), `jet_cad_2d_plan`, `jet_cad_2d_kit_architecture`.

**Spec:** [docs/superpowers/specs/2026-10-16-restaurant-kit-design.md](../specs/2026-10-16-restaurant-kit-design.md)
(decisions 1-15, R1-R5) with its companions
[parity](../specs/2026-10-16-restaurant-kit-parity.md) and
[test audit](../specs/2026-10-16-restaurant-kit-test-audit.md). Read all
three.

## Global Constraints

- The kit names neither `jet_cad_2d_plan` nor another kit nor an old
  package (pubspec, lib, test); `check_kit_deps` enforces it.
- The demo names neither `jet_cad_floor_plan` nor
  `jet_cad_restaurant_symbols` (a boundary test, as 3b's N1).
- `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`,
  `apps/floor_planner` and the engine packages (`jet_cad`, `jet_cad_2d`,
  `jet_cad_2d_flutter`, `jet_cad_2d_gpu`) are not modified (4b removes the
  old ones). `apps/architecture_demo` changes only in Task 5 (O3).
- Keys stay `restaurant.*` at `@1`; geometry equals the old catalog's.
- Units: exactly the 25 old seated symbols, `UnitKinds.table`, capacity =
  old `seats`, numbered.
- Porting rules (3a/3b): never weaken a ported assertion; never skip; an
  impossible premise splits into `<id>-open` and its intent with
  `// Decided: premise impossible (<why>)`; every ported file starts with
  a header naming its old file and audit section.
- Every new test and behaviour change names a mutation that turns it red;
  run on committed code, revert with `git checkout --`, show
  `git diff --quiet`.
- Never synthesize output. Code, comments, commits in English. Trailer:
  the implementer's own model name, `Co-Authored-By: … <noreply@anthropic.com>`.
- `analysis_options.yaml` is never committed, except the new kit's own
  copy once in Task 1.
- Every task ends green: each touched package's `flutter test` (plan and
  integration with `--enable-vmservice`; the kit with `dart test` if it is
  pure Dart, else `flutter test`), `analyze`, `dart format
  --output=none --set-exit-if-changed .`.
- No reviewer subagents (decision 8): the controller reviews each task.
- Never `dart pub publish` without `--dry-run`.

## Review Focus

1. **A table placed from the gallery and one placed by a sample build are
   the same definition** (capacity, outline, key). Task 2 pins it (U3).
2. **A POS host that relabels a merged table** loses the group on restore
   (2b rule): the guide warns, and Task 10's guide snippet shows saving
   the groups first.
3. **Two areas, two controllers**: an action in the Salon never reaches
   the Teras (statuses, selection, undo). Task 7 pins it (AR-isolated).
4. **A status caption longer than 12 graphemes** in de/tr is cut, never
   overflows the overlay. Task 7 pins it (ST-caption-de/tr).
5. **Export while the dialog is up and the area switched** writes the
   right area's page or nothing. Task 8 pins it (EX-area).

---

## File structure

```
packages/jet_cad_2d_kit_restaurant/        Tasks 1-2
  pubspec.yaml, analysis_options.yaml, README.md, CHANGELOG.md, LICENSE
  lib/jet_cad_2d_kit_restaurant.dart
  lib/src/catalog/*.dart                   (tables, booths, bar, kitchen, service, outdoor)
  lib/src/restaurant_names.dart
  lib/src/restaurant_source.dart
  lib/src/kit.dart, lib/src/keys.dart, lib/src/definitions.dart
  tool/generate_restaurant_library.dart
  assets/library/restaurant.jetlib, restaurant.snapshot.json
  test/fixtures/old_catalog_geometry.json  (exported once from the old package)
  test/...
packages/jet_cad_2d_plan/                  Tasks 3-5
apps/architecture_demo/                    Task 5 (O3 only)
apps/restaurant_demo/                      Tasks 6-9
docs/host-guide.md, tool/ci/check_guide.dart, tool/ci/host_probe/  Task 10
docs/superpowers/...                       Task 11
```

---

### Task 1: The kit's catalog, asset and generator

**Files:** create `packages/jet_cad_2d_kit_restaurant/**` (pubspec,
barrel, `lib/src/catalog/*`, `restaurant_source.dart`, `keys.dart`,
`definitions.dart`, `tool/generate_restaurant_library.dart`, the asset),
`test/fixtures/old_catalog_geometry.json`, `test/catalog_geometry_test.dart`;
modify the root `pubspec.yaml` workspace list (after
`packages/jet_cad_2d_kit_architecture`).

**Interfaces:**
- Produces: `restaurantSymbolSource` (a `SymbolLibrarySource` over the
  package asset, as `furnitureSource` in
  `packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_source.dart`);
  `abstract final class RestaurantSymbols` with one `static const String`
  per key; `Map<String, SymbolDefinition> restaurantSymbolDefinitions()`
  (synchronous: decodes the committed library once and caches; returns
  `key@1` → definition as the loader yields it).

- [ ] **Step 1:** Read the template: the architecture kit's furniture port
  (`lib/src/furniture/*`, `tool/generate_furniture_library.dart`,
  `test/furniture/*`, its pubspec's `flutter: assets:`), and the old
  restaurant package (`packages/jet_cad_restaurant_symbols/lib/src/*`,
  `tool/`). Write in the report how the old catalog maps onto the new
  authoring API (`CatalogSymbol`, `CatalogShape`, the shared chair
  helpers in `jet_cad_2d_kit`'s authoring library).
- [ ] **Step 2: The geometry fixture.** A one-off script (not committed;
  run from the old package's directory, since only it may import the old
  catalog) writes `test/fixtures/old_catalog_geometry.json`: for every
  old key, its shapes in drawing order (kind and every coordinate),
  bounds, category, seats. Commit only the JSON; name the script's
  command in the fixture's sibling `README` line or the report.
- [ ] **Step 3: The geometry test (red first)** `catalog_geometry_test.dart`:
  for every key in the fixture, the new catalog's symbol has the same
  shapes (exact `==` on stored coordinates), bounds, category; the key
  sets are equal (69). Mutation: shift one shape of one symbol by 1 mm.
- [ ] **Step 4: Port the catalog** into `lib/src/catalog/` (one file per
  old file), using the shared helpers where the old code duplicated a
  chair/stool (the result must still match the fixture). No units yet.
- [ ] **Step 5: The generator and asset**: `dart run
  tool/generate_restaurant_library.dart` writes the `.jetlib` and the
  snapshot; a test (as the architecture kit's `package_assets_test`)
  checks the committed asset equals the built one. Mutation: edit one
  byte of the committed asset.
- [ ] **Step 6:** `restaurantSymbolDefinitions()` and its test: every key
  present, each definition equal to the one decoded from the asset
  through the library code path the loader uses. Mutation: build the map
  from the catalog without the asset's encode/decode round trip if that
  changes anything; else drop one key.
- [ ] **Step 7:** Gates; `dart run tool/ci/check_kit_deps.dart` green and
  listing the new kit. Commit `feat(restaurant): the restaurant kit's catalog, asset and generator`.

### Task 2: Units, words, the kit and its tests

**Files:** modify the catalog (units), create `restaurant_names.dart`,
`kit.dart`, the barrel's exports; port the kit-side cases of
`restaurant_library_test`, `symbol_section_catalog_test`,
`symbol_names_test` per the test audit; create `test/units_test.dart`,
`test/conformance_test.dart`; README and CHANGELOG (0.1.0, unreleased).

**Interfaces:** Produces `restaurantKit` (`PlanKit(id: 'restaurant',
version: '0.1.0', symbols: [restaurantSymbolSource], names:
restaurantNames)`), `restaurantNames` (`KitNames`, en/de/tr).

- [ ] **Step 1: U1/U2 (red first):** exactly the 25 keys whose fixture
  `seats` is non-null are units, `kind == UnitKinds.table`, `capacity ==
  seats`, labelling numbered; no other key is a unit. Mutation: drop the
  unit from one booth; give the coat rack a unit.
- [ ] **Step 2:** Add the units in the catalog. Regenerate the asset; the
  geometry test stays green (units are not geometry). The library rules
  (closed outline first, no family, capacity ≥ 1) pass.
- [ ] **Step 3: U3 (Review Focus 1):** for three seated keys, the
  definition from `restaurantSymbolDefinitions()` equals the one the
  asset yields through `restaurantSymbolSource` (capacity, outline,
  key). Mutation: the sync map built from a catalog copy with one
  capacity changed.
- [ ] **Step 4: Words:** port the old `names.dart` to `restaurantNames`
  (69 symbols, 6 categories; `sameAsEnglish` for identical words);
  categories unique per locale (a test, as the old one).
- [ ] **Step 5: Conformance:** the contract's conformance test on the kit
  (`typeIds`, `toolIds`, `propertyIds` empty). Mutation: a German name
  removed.
- [ ] **Step 6: Port** the kit-side audit rows (PORT/SPLIT/COVERED
  checked/DROPPED with reason); cases the audit sends to the demo are
  listed in the report as "moved to Task 6/7".
- [ ] **Step 7:** Gates, `check_kit_deps`, `dart pub publish --dry-run`
  (0 warnings). Commit `feat(restaurant): units, words and restaurantKit`, `test(restaurant): the old package's tests, ported`.

### Task 3: Host gaps H1-H4

**Files:** `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export
`PlanToolIds`), `barrel_test.dart` (ED-9 name set), the controller's doc
comment on views; tests `test/host/tool_ids_test.dart` (H1),
`test/host/host_kit_test.dart` (H2: a test kit with one symbol loaded
beside another kit, placed from the gallery), `test/host/two_views_test.dart`
(H3), `test/service/view/user_camera_test.dart` (H4); CHANGELOG lines.

- [ ] Each: test red first (or a named mutation for behaviour that
  already holds), implement, gates. H3: mount two `PlanCanvas` on one
  controller; the last placed drives `camera`/`canvasRect`; unmount it;
  the first drives. Mutation: keep the first placed. H4: with
  `userCamera: false`, pinch, pan and wheel leave `camera` unchanged;
  `centerOn` moves it. Mutation: ignore the flag for the wheel.
- [ ] Commit `feat(plan): PlanToolIds public; host kits, two views and userCamera pinned`.

### Task 4: O1 drag snap, O2 orientation row

**Files:** `packages/jet_cad_2d_plan/lib/src/tools/` (the select tool's
drag snap), `lib/src/panels/plan_page_panel.dart`; tests beside the
existing select-drag and page-panel tests.

- [ ] **O1:** a test drags a unit (and a plain line) with `plan.select`
  by a small offset near its own old edge midpoint: the result is the
  pointer's offset (grid aside), not the old midpoint. If red on today's
  code, exclude the dragged objects from the snap candidates (find where
  the move resolver gathers candidates); if green, the item closes with
  the test as its pin and the report says the defect was not real.
  Mutation for the fix: include the dragged objects again.
- [ ] **O2:** the orientation row's labels lay out on one line each at
  the panel's width at 1440×900 and at its narrowest (measure the
  `Text`'s `RenderParagraph` line count or `didExceedMaxLines`); fix by
  the row's layout (e.g. `FittedBox`/smaller padding/an icon+label
  layout), not by changing the words. en/de/tr. Mutation: restore the
  old layout.
- [ ] Gates (plan, integration). Commit `fix(plan): a dragged unit does not snap to itself; the orientation row fits`.

### Task 5: O3 page-flow signal, O4 same-frame re-word

**Files:** `plan_controller.dart` (public `ValueListenable<bool>
pageFlowBusy`), its tests; `apps/architecture_demo/lib/busy_wrappers.dart`
and `document_host.dart` (busy follows `pageFlowBusy`), its
`test/export/busy_test.dart` (N6-gap → N6-closed); the notice re-word
path and the 3a test pinning the lag.

- [ ] **O3:** `pageFlowBusy` is true from an export's or print's start
  (dialog included) to its end, error or cancel included; tests for each
  path; mutation: clear it before `onExport`. The architecture demo's
  busy covers the gap: N6-closed asserts New does nothing between the
  dialog closing and the write. Mutation: the demo ignores the signal.
- [ ] **O4:** find the 3a test that pins the one-frame lag (grep
  "re-word" / "one frame" in `jet_cad_2d_plan/test` and the kit's
  tests), flip it to same-frame, and make the notice re-word in the
  locale change's frame. Mutation: defer it again.
- [ ] Gates (plan, integration, architecture_demo). Commit `feat(plan): pageFlowBusy; tool notices re-word in the same frame`.

### Task 6: The demo's new base and samples

**Files:** `apps/restaurant_demo/pubspec.yaml` (new deps, no old ones,
no `assets/plans`), delete `assets/plans/*.json` and `UPDATE_SAMPLES`;
`lib/samples/salon.dart`, `teras.dart`; `lib/main.dart` reduced to the
app shell (two areas, each a `PlanController(kits: [architectureKit,
restaurantKit], build: …)`, the area switch, `PlanTheme` look,
`demo_strings.dart` kept); `test/boundary_test.dart`;
`test/sample_plans_test.dart` (the audit's SPLIT row) and
`test/support/` (one rig and one unit finder for the whole demo's tests).

- [ ] Read the old `main.dart`, `demo_theme.dart`, `demo_strings.dart`
  and the two JSON plans; rebuild the Salon and Teras geometry as walls
  (`WallParams`), doors/windows where the old plans had them, and tables
  by key and transform, numbered in build order (Salon 1-3, 4-5, 6-7,
  8-11 as the audit says; Teras per its JSON). A test per sample: unit
  count, numbers, capacities, opens clean with nothing to undo.
  Mutation: two tables swapped in build order.
- [ ] Boundary test (mutation: an import of the old package).
- [ ] The shell pumps; both areas show their plans.
- [ ] Gates; commit `feat(restaurant_demo): the new base and the samples as builds`.

### Task 7: The demo's service features

**Files:** `lib/main.dart` (or split into `lib/area.dart`,
`lib/table_menu.dart`, `lib/statuses.dart` if the file passes ~800
lines); port `demo_test.dart`'s rows per the audit that cover: the
Design/Service toggle, editor profiles and permissions, selection and
find, the table menu, statuses (random), merge/split, POS id linking
(host data), zones and fade.

- [ ] Port per the audit; new: **AR-isolated** (Review Focus 3: a status,
  a selection and an undo in the Salon leave the Teras unchanged;
  mutation: share one controller) and **ST-caption-de/tr** (Review Focus
  4; mutation: no cut).
- [ ] Gates; commits `feat(restaurant_demo): service features on the new API`, `test(restaurant_demo): demo tests ported (service)`.

### Task 8: The demo's bars, export, layout and events

**Files:** the demo's own service bar (`PlanServiceBar(leading: [area
name])`, key `bar-area`), export/print (`showPlanExportDialog` +
`controller.export`/`print`, busy through `pageFlowBusy`), save / revert /
restore layout (decision 14), the events log; port the remaining rows of
`demo_test`, all of `events_test`, `badges_test`, `host_chrome_test`,
`look_test`.

- [ ] Port per the audit; new: **EX-area** (Review Focus 5; mutation:
  export reads the current area at write time instead of at start).
- [ ] Gates; commits as Task 7.

### Task 9: POS1 and the builds

**Files:** `apps/restaurant_demo/integration_test/pos_test.dart`.

- [ ] POS1 on macOS (`flutter test integration_test/pos_test.dart -d
  macos`): open the Salon; Service; statuses on three tables; merge two;
  link a POS id; save the layout, move a table, restore; export PNG
  through a temp-dir files/export hook; screenshot via `RepaintBoundary`
  to PNG; copy it to
  `docs/superpowers/notes/2026-10-16-restaurant-kit-pos.png`. Transcribe
  the run's last lines.
- [ ] Builds: `flutter build macos`, `flutter build web`, `flutter build
  ios --simulator --no-codesign`; `flutter build apk --debug` if `flutter
  doctor` shows an Android toolchain, else record why. Transcribe.
- [ ] Commit `test(restaurant_demo): POS1 on macOS; the builds`.

### Task 10: The host guide and its checks

**Files:** `docs/host-guide.md` (rewritten), `tool/ci/host_probe/**`,
`tool/ci/check_guide.dart` (if its paths/rules change),
`tool/ci/test/*` for the guide check.

- [ ] Rewrite per spec R4 (sections listed there), every code block
  compiled by the probe; the POS example uses `restaurantKit`, service
  mode, statuses, groups (with Review Focus 2's warning and snippet),
  host data, events; H1-H3 shown; "From `jet_cad_floor_plan`" maps every
  old barrel name (parity companion §2) to its new name or its decision-7
  drop.
- [ ] The probe builds against the new packages from outside the
  workspace (as today's does for the old); `check_guide` green; a
  mutation: a guide snippet edited without the probe → red.
- [ ] Commit `docs: the host guide for jet_cad_2d_plan and the kits; its probe and check`.

### Task 11: The exit gate (implementer part)

**Files:** the parity companion (a closing "Closed (4a)" column/section),
the test-audit companion ("Closed (4a)"),
`docs/superpowers/notes/2026-10-16-restaurant-kit-results.md`, the
umbrella and 3b specs' Amendments lines, `STATUS.md`.

- [ ] Close every parity row (HAVE/RENAMED with its test, R2 item,
  decision-7 drop) and every audit row, from the test files by grep, not
  memory; any open row is a defect.
- [ ] Run every gate fresh (R5) and transcribe; dry-runs of the kit and
  the plan library (0 warnings); `check_kit_deps`, `check_guide`, probe.
- [ ] Results note (gates, POS1 and its PNG, builds, rulings from the
  ledger, follow-ups, "For the human"); amendments; STATUS (4a done on
  the branch, not merged). Commit `docs: 4a parity and audit closed, results, amendments, STATUS`.
- [ ] (controller) Review the whole branch, one fix wave if needed,
  archive the ledger, tell the human the restaurant demo runs on the new
  packages, offer the merge menu.
