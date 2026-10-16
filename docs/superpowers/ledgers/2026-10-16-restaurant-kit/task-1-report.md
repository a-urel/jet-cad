# Task 1 report: NEEDS_CONTEXT

Status: stopped before committing. Nothing is committed.

## The blocker
The contract refuses 8 of the 69 old keys. `SymbolComponent` (packages/jet_cad_2d_kit/lib/src/model/symbol_component.dart:37,
`isSymbolKey`) requires "a kit id, then two or more dot-separated segments". Eight old keys have one segment after `restaurant.`:
restaurant.cashier, restaurant.buffet, restaurant.highchair, restaurant.parasol, restaurant.heater, restaurant.partition,
restaurant.stage, restaurant.piano.
`dart run tool/generate_restaurant_library.dart` dies at the first: `Invalid argument (key): ... "restaurant.cashier"`.
Spec R1 says "Keys stay restaurant.* at version 1", which cannot hold for these 8. Precedent: the architecture kit renamed
`armchair` to `architecture.armchair.single` (spec 2026-10-15-architecture-kit-design.md:556).

Decision needed: the 8 new keys (a proposal: restaurant.cashier.desk, restaurant.buffet.counter, restaurant.highchair.child,
restaurant.parasol.round, restaurant.heater.patio, restaurant.partition.screen, restaurant.stage.platform, restaurant.piano.grand),
and that spec R1, the test audit, and the demo/names tasks use them. The geometry test would then carry a 8-entry old-key to
new-key table (the fixture keeps the old keys).

## State of the work (uncommitted, in the worktree)
- packages/jet_cad_2d_kit_restaurant/: pubspec, LICENSE, analysis_options, README, CHANGELOG, barrel, lib/src/catalog/* (all 69
  symbols ported, six files plus restaurant_catalog.dart), keys.dart (generated from the fixture), restaurant_source.dart,
  definitions.dart, tool/generate_restaurant_library.dart, test/catalog_geometry_test.dart, test/fixtures/old_catalog_geometry.json.
- Root pubspec.yaml: workspace entry added.
- Fixture command (script in scratchpad, old package untouched, `git status` shows it clean):
  `cd <scratchpad> && dart --packages=<worktree>/.dart_tool/package_config.json export_old_catalog.dart <worktree>/packages/jet_cad_2d_kit_restaurant/test/fixtures/old_catalog_geometry.json` -> "wrote 69 symbols".
- Not yet done: asset/snapshot generation, tests run, mutations, gates, check_kit_deps, commit.

---
# Update after the ruling: DONE

Status: DONE. Commit b40de57f `feat(restaurant): the restaurant kit's catalog, asset and generator` (includes the controller's spec R1 edit and the root workspace entry).

The 8 renames were applied as ruled (cashier.desk, buffet.counter, highchair.child, parasol.round, heater.patio, partition.screen, stage.platform, piano.grand). The test audit names none of them. The geometry test carries the 8-entry old-to-new table and asserts it equals exactly the fixture keys `isSymbolKey` refuses.

Gates (restaurant kit; no other package touched, `git status` clean after):
- `flutter test`: `00:00 +85: All tests passed!`
- `flutter analyze`: `No issues found!`
- `dart format --output=none --set-exit-if-changed .`: exit 0
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 3 package(s) checked, none names the plan library or another kit`

Catalog mapping: FurnitureSymbol -> CatalogSymbol (`base: (x, y)`; `seats` dropped until Task 2), LineShape/PolylineShape/CircleShape/ArcShape -> CatalogLine/Polyline/Circle/Arc, helpers rect/inset/poly/chairAt/chairsAround/stoolAt/stoolsAround from the authoring toolkit (the old local copies removed); booth/banquette seat arguments dropped. All 69 shapes equal the fixture exactly; no arc was inexpressible.

Mutations (each run on committed code, reverted with `git checkout -- .`, `git diff --quiet` passing):
- M1 cashier register rect x 900 -> 901: red `catalog_geometry_test` restaurant.cashier (and asset/snapshot tests)
- M2 one byte of the committed asset: red `restaurant_library_test` "committed bytes equal the built library" and the definitions test
- M3 definitions map skips the first entry: red "restaurantSymbolDefinitions holds every key@1" (first attempt via a non-matching sed survived; redone with a real diff, red)
- M4 delete the `restaurant.stage` rename entry: red key-order, rename-table-coverage and restaurant.stage tests
- M5 misspell `RestaurantSymbols.barBack`: red "RestaurantSymbols names every catalog key"
- M6 coat rack inner ring 40 -> 41 without regenerating: red restaurant.coat.rack geometry, asset bytes and snapshot tests

Tests added: test/catalog_geometry_test.dart (73), test/library/package_assets_test.dart (3), test/library/restaurant_library_test.dart (9).
Not done by design: conformance (needs the kit and units, Task 2). Step 6's "no round trip" variant: `restaurantSymbolDefinitions()` builds from the catalog via encodeLibrary+decode (the asset cannot be read synchronously); the drop-one-key mutation was used.
