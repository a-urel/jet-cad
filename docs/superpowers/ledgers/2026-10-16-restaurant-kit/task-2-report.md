# Task 2 report: DONE_WITH_CONCERNS

Commits: ec01ca6b `feat(restaurant): units, words and restaurantKit`; 1ba8ecf4 `test(restaurant): the old package's tests, ported`.

## Gates (restaurant kit, real last lines)
- flutter test: `00:01 +184: All tests passed!`
- flutter analyze: `No issues found!`
- dart format --output=none --set-exit-if-changed .: exit 0
- check_kit_deps: `kit dependencies: 3 package(s) checked, none names the plan library or another kit`
- dart pub publish --dry-run: `Package has 0 warnings.` (never published)

## What landed
- Units: `lib/src/catalog/units.dart` `tableUnit(n)`; `seats:` on _rectTable/_booth/_banquette, existing seats/stools count on round/high tables, `unit:` on the 6 literal symbols. 25 units, kind table, numbered. Asset regenerated; snapshot deleted and regenerated (unit is part of the snapshot entry; key@1 unpublished, so the K7 never-rewrite rule does not apply yet).
- Words: `lib/src/restaurant_names.dart` (de/tr generated from the old names.dart, 8 renamed keys carried over; `restaurantSameAsEnglish` = de Bar, Service; tr Bar). 'en' is an empty map (English is the stored text, no code-side words).
- `lib/src/kit.dart` `restaurantKit`; barrel exports `restaurantKit`, `restaurantNames`, `restaurantSymbolEntries`.
- README, CHANGELOG 0.1.0, dev dependency vector_math (place_entry copy, as the architecture kit).
- Tests: test/units_test.dart (U1, U2, U3 x2, SC1), test/restaurant_words_test.dart (kit, RL3 label, conformance, German-name-removed, SNL, SC3 premise), test/library/restaurant_symbols_port_test.dart (RL4-RL14, RL16-RL23), test/support/place_entry.dart (copy).

## Audit rows
restaurant_library_test (23):
- RL1 PORT: done in Task 1 (restaurant_library_test.dart "committed bytes equal built library") + conformance builtDiffers in restaurant_words_test SC-conformance.
- RL2 PORT: Task 1 ("building twice").
- RL3 PORT: Task 1 package_assets_test (key, bundle read, app key refused) + pubspec test; source label added in restaurant_words_test.
- RL4-RL14, RL16-RL23 PORT: restaurant_symbols_port_test.dart, hand tables kept, 8 keys renamed, RL16 `checked == 80` premise kept, RL13/14 through placeEntry copy.
- RL15 SPLIT: moved to Task 6/7 (demo `symbols_load_test`: both kits load, 41 + 69, categories 6+6, no diagnostic). The -open half (clash impossible by construction) is covered by K symbol_library_test V5a / conformance F4 per the audit.
symbol_section_catalog_test (3):
- SC1 COVERED, checked: packages/jet_cad_2d_kit/test/model/symbol_library_test.dart (V9a named by audit) plus new units_test SC1 (no unit has a family). I did not open the P panels/symbol_section_test.dart SW5 row.
- SC2 DROPPED (vacuous restaurant half, no attachTo; audit).
- SC3 PORT: premise pinned here (restaurant_words_test SC3 premise: corner booth base x != box centre x); the behaviour test moved to Task 6/7 (demo `corner_booth_test`).
symbol_names_test (2):
- SNL restaurant PORT: restaurant_words_test SNL + conformance (explicit per-category uniqueness loop kept).
- SNL source carries names: DROPPED (audit, premise gone).

Moved to Task 6/7: RL15, SC3 behaviour.

## Mutations (committed code, reverted with git checkout, `git diff --quiet` passing each time)
- M1 booths lose their unit (asset regenerated): red U1, U2, RL5, RL17.
- M2 coat rack gets a unit (regen): red U2, RL5, RL17.
- M3 unit kind seat (regen): red U1.
- M4 rect.eight capacity 9 (regen): red U1, RL5.
- M5 sync entries built from a catalog copy with booth.round capacity 5: red both U3 tests.
- M6 German name removed: red SC-conformance, SNL.
- M7 Turkish name left in English: red SC-conformance, SNL, wordMissing test.
- M8 two German names equal in one category: red SNL only (conformance does not catch it, as the audit says).
- M9 Turkish category word removed: red conformance, SNL.
- M10 symbol word under architecture.*: red conformance, SNL, kit validate test.
- M11 kit drops names: red SC-conformance, kit test.
- M12 _benchDepth 550 (regen): red geometry tests and 5 others.
Not mutation-run individually: the ported RL cases beyond M12 (they passed on first run and test unchanged geometry; Task 1's geometry mutations M1/M6 cover the same catalog).

## Decisions and concerns
1. **Review Focus 1 / U3 needed a new accessor.** `restaurantSymbolDefinitions()` returns `Definition`s, which carry no capacity, so "capacity, outline, key" cannot be compared through it. I added `restaurantSymbolEntries()` (key@1 -> SymbolEntry with symbol, unit, definition, leaves; cached) and derived the definitions map from it. A sample build that places a table needs the SymbolComponent and UnitComponent too, so Task 6 should place from the entries, not the bare definitions. Spec R1 names only `restaurantSymbolDefinitions()`; the controller may want to note the addition.
2. Snapshot regenerated, not appended (see above); after the first publish this would be a K7 violation.
3. 'en' words map is empty.
