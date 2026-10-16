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

