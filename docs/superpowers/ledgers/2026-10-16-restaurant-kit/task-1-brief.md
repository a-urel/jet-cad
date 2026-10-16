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

