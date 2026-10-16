# Task 23 report: the furniture library (spec C4, C7; D-11, D-15, D-17, D-47)

Status: DONE. Commit `b10cf092 feat(architecture): the furniture library (3a C4)` on `feat/architecture-kit` (parent 2dbf27c1).

## Implementation summary

In `packages/jet_cad_2d_kit_architecture/`:
- `lib/src/furniture/furniture_catalog.dart`: `furnitureCatalog`, written as the brief has it (Step 6). Kit `architecture`, 41 symbols in today's order, all at `@1`. The 30 against-the-wall symbols carry `attachTo: ['wall-face']`: 14 inline symbols plus the five family helpers, so `grep -c "attachTo: _wallFace"` gives `19`. The 18 family members carry `family`. There is no unit. The dining sets keep today's `_chair`.
- `lib/src/furniture/furniture_names.dart`: `furnitureGerman` and `furnitureTurkish`, 47 entries each (41 `symbol:` and 6 `category:`). A script **generated** this file from today's `jet_cad_floor_plan/lib/src/symbols/furniture_names.dart`. No word was typed by hand. See "Words" below.
- `lib/src/furniture/furniture_source.dart`: `kFurnitureAsset`, `furnitureReader({bundle})` over `bundledLibrary`, and `furnitureSource`. It is **not** added to `architectureKit.symbols`; Task 24 does that (R-P2).
- `tool/generate_furniture_library.dart`: the generator. Its output: `wrote assets/library/furniture.jetlib: 67083 bytes, 41 symbols`.
- `assets/library/furniture.jetlib` (67083 bytes) and `assets/library/furniture.snapshot.json` (41 entries): generated and committed. The generator is deterministic. Two runs gave identical SHA-1s: `f66a4574…` for the jetlib and `0d3b4139…` for the snapshot.
- `lib/src/words/words.dart`: `architectureNames` is now `KitNames({'en': englishWords, 'de': {...germanWords, ...furnitureGerman}, 'tr': {...turkishWords, ...furnitureTurkish}})`. `kit.dart` is unchanged: `names: architectureNames` keeps `identical`, and `symbols` stays empty.
- `pubspec.yaml`: adds only `flutter: assets: - assets/library/furniture.jetlib`.
- `test/support/place_entry.dart`: `placeEntry` and `copyOfEntry`. This is the plan placer's no-unit path. The header cites the source lines.
- `test/furniture/furniture_library_test.dart`: ported, plus the C4 group (FU-keys, FU-tags, FU-plain-tables).
- `test/furniture/package_assets_test.dart`: PA2 and PA3 ported, plus FU-asset-key.
- `test/scaffold/words_test.dart`: SC-conformance now runs over `furnitureCatalog`, the committed jetlib and snapshot, and `architectureKit.names` (D-47).

## Geometry fidelity: how it was checked (exact ==, no tolerance)

1. **The oracle is today's code.** Today's committed asset equals today's built library. I ran the old line's own test, read-only:
   `cd packages/jet_cad_floor_plan && flutter test test/symbols/furniture_library_test.dart --plain-name "the committed bytes equal the built library"`
   It printed `00:00 +1: All tests passed!`.
2. **Mechanical leaf-for-leaf comparison.** A scratch Python script (`scratchpad/compare_geometry.py`, not committed) parses both `.jetlib` JSONs: today's `packages/jet_cad_floor_plan/assets/library/furniture.jetlib` and the kit's generated one. It walks both libraries' definitions in stored order and pairs them. For each pair it checks:
   - the key maps to `architecture.<key>` (`armchair` maps to `architecture.armchair.single`);
   - version 1, and the definition name `<key>@1`;
   - `basePoint ==`;
   - `name` and `category ==`;
   - tags == today's tags minus `against-wall` and `family:*`;
   - `attachTo == ['wall-face']` exactly when today has `against-wall`;
   - `family ==` today's `family:` suffix, or null;
   - leaf count;
   - for each leaf, ascending by handle, every record field except `handle` and `owner` is `==`. Today's `geomIndex`, layer, linetype, colour, lineweight, transparency, flags, text, tag, textStyle and textAttrs are equal too.
   - the geometry `{coords, scalars}` is `==` both as parsed doubles and as JSON text.

   Output:
   ```
   symbols compared: 41 leaves compared: 198
   against-wall: 30 family members: 18
   problems: 0
   ```
   Negative control: in a scratch copy of the kit's library I nudged one coordinate by 1e-9 and appended one tag. The script then reported 3 problems (`tags`, `geometry`, `geometry-text`) and exited 1.
3. In the committed state, the ported "committed bytes equal the built library" test and SC-conformance's `builtDiffers` and `snapshotChanged` checks hold the asset to the catalog. M-FU4 shows they go red.

## Words: byte-for-byte check

`scratchpad/verify_names.py` parses today's `furniture_names.dart` (names.de, names.tr, categories.de, categories.tr). It maps each key to `symbol:architecture.<key>` (armchair maps to `armchair.single`) and each category to `category:architecture/<English>`. Then it compares the UTF-8 bytes of every (id, word), in order, with the kit's file. Output:
```
de entries 47 expected 47
tr entries 47 expected 47
non-ASCII words compared: 45
OK
```
Negative control: in a scratch copy, NFD plus `ı`→`i` in `Gardırop 1200` gave `MISMATCH` and exit 1. The ported test has non-ASCII on one line only, the header's `…`, which is the brief's text. The source has none.

## TDD evidence

RED: I wrote the tests and `place_entry.dart` before any lib file. `flutter test test/furniture/`:
```
test/furniture/furniture_library_test.dart:19:8: Error: Error when reading 'lib/src/furniture/furniture_catalog.dart': No such file or directory
test/furniture/package_assets_test.dart:12:8: Error: Error when reading 'lib/src/furniture/furniture_source.dart': No such file or directory
00:00 +0 -2: Some tests failed.
```
GREEN, after the lib files, the generator, the words and the pubspec:
- `flutter test test/furniture/` printed `00:00 +153: All tests passed!`. That is 150 library tests plus 3 asset tests.
- `flutter test test/scaffold/words_test.dart` printed `00:00 +3: All tests passed!`.

## Gates

- Kit:
  - `flutter test`: `00:18 +566: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 3.4s)`
  - `dart format --output=none --set-exit-if-changed .`: `Formatted 116 files (0 changed)`, exit 0
  - `dart pub publish --dry-run`, after the commit: `Package has 0 warnings.`, `Total compressed archive size: 463 KB.` The listing includes `assets/library/furniture.jetlib (65 KB)`, `furniture.snapshot.json (17 KB)`, `lib/src/furniture/{furniture_catalog (16 KB), furniture_names (5 KB), furniture_source (1 KB)}`, `tool/generate_furniture_library.dart (1 KB)` and the two test files. Before the commit it reported only the "modified in git" warning.
- Integration:
  - `flutter test --enable-vmservice`: `00:14 +94: All tests passed!`
  - analyze: `No issues found!`
  - format: `Formatted 30 files (0 changed)`
- Repo root: `dart run tool/ci/check_kit_deps.dart` printed `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0.
- `git status --short` is clean after the commit and after every mutation. No `analysis_options.yaml` was rewritten.

## Mutations (on committed files; each reverted with `git checkout --` and `git diff --quiet` exit 0)

| Id | Mutation | Test | Red line |
|---|---|---|---|
| M-FU1 | the hob loses `attachTo: _wallFace`, then generator | against-wall set | `Which: does not contain 'architecture.kitchen.hob'` |
| M-FU2 | `_baseUnit` tags gain `'against-wall'`, then generator | FU-tags | `Actual: ['base unit', 'cabinet', 'cupboard', 'against-wall']` |
| M-FU3 | the round table gets `unit: const CatalogUnit(kind: UnitKinds.table, capacity: 4)` | FU-plain-tables | `Expected: empty / Actual: ['architecture.dining.table.round']` |
| M-FU4 | `_chair` bottom back line `y + 60` → `y + 50` | committed bytes; SC-conformance | `Which: at location [7057] is <53> instead of <54>`; `KitProblem:builtDiffers …`, `KitProblem:snapshotChanged: architecture.dining.table.rect.four@1 …` (and the other four tables) |
| M-FU5 | `architecture.armchair.single` → `architecture.armchair.one`, then generator | FU-keys | `Which: at location [29] is 'architecture.armchair.one@1' instead of 'architecture.armchair.single@1'` |
| M-FU6 | `kFurnitureAsset` → `'assets/library/furniture.jetlib'` | package_assets_test | FU-asset-key `Actual: 'assets/library/furniture.jetlib'`; PA2 `[E]`; PA3 `[E]` (`Expected: throws <Instance of 'FlutterError'>`); `+0 -3` |
| M-FU7 | `de` `symbol:architecture.bed.double` → `'Double bed'` | SC-conformance | `KitProblem:wordUntranslated: de: "symbol:architecture.bed.double" is its English, "Double bed"` |
| M-FU8 | as written: `de` → `germanWords` and the import removed. **It does not compile**: `tr` still spreads `furnitureTurkish`, so the result is `Undefined name 'furnitureTurkish'`. I ran the intended equivalent: `de` → `germanWords`, import kept | SC-conformance | `KitProblem:wordMissing: de: no word for "symbol:architecture.dining.table.square.two"`, and the rest (output truncated by the matcher) |
| M-FU9 | the pubspec line `- assets/library/furniture.jetlib` deleted | is declared in the pubspec | `Expected: true / Actual: <false>` |
| extra | `placeEntry` uses `at: Vector2.zero()` | every symbol placed | `00:00 +0 -82: Some tests failed.` |

## Ported-test accounting

Source: `jet_cad_floor_plan/test/symbols/furniture_library_test.dart`. Every case below keeps its assertions. Ids change through the perl rewrite (C7 class 1), and entry fields move to `e.symbol.*` (fixture).

- **the asset (5):** committed bytes; decodes (`furnitureCatalog.symbols.length`); building twice; the pubspec; 41 symbols in six categories. Classes: ids, fixture (`builtBytes` = `encodeLibrary(furnitureCatalog)`).
- **the decoded library (5):** catalog order (`.symbols`); lower-case dotted; base off the origin (`s.base.$1/$2`); category, tags, version, leaves (**class 1**: `version == 1` for all; the `version2` set removed); leaf handles ascend.
- **outline and category (4):** ids only.
- **families and the wall tag (5):**
  - against-wall set (**class 2**: `attachTo.contains('wall-face')`);
  - families (**class 2**: the `family` field; the per-entry `lessThanOrEqualTo(1)` count is gone because the field's type allows one family);
  - W-16; D9 W x D; base on centre x: ids only.
- **dining tables draw their chairs (5):** the four cases, plus "the round table draws its four chairs" moved in from the seating group. Assertions unchanged.
- **every symbol placed (82)** and **plausible size (41):** `placeSymbol` → `placeEntry`; `prepareDocument` → `placementDocument()`; `registerAppComponents` → `registerKitComponents`. All are fixture changes (R-P1).
- **Not ported:**
  - "the behaviour tags come last" (retired, class 2);
  - "the 14 new symbols carry their names; the old keys stay" (umbrella decision 9);
  - the group "the 27 symbols shipped before 09c", 4 tests (decision 9);
  - seating: "the decoded library carries each servable symbol's seats" and "the catalog says the same thing the file does" (dropped, decision 7).
- **package_assets_test:** PA2 and PA3 ported. Their assertions are unchanged; `readBundledLibrary(bundle)` → `furnitureReader(bundle: bundle)()`, and the key is the kit's. PA1's counterpart is FU-asset-key. PA4 stays sub-project 4's.
- **New:** FU-keys, FU-tags, FU-plain-tables, FU-asset-key.

## Deviations (all minor; meaning and mutation strength kept)

1. **`place_entry.dart` header.** The brief cited `symbol_placer.dart:103-219`. The actual lines are `definitionForEntry` 52-102 and `placeSymbol` 126-177, so I cited those. The header also names what is not copied: the leaf-equality and unit reuse checks, the `#n` name suffix, the instance style (the placer's default is InstanceNode's own) and the unit label. The code is the brief's.
2. **`placementDocument` comment** also names the DASHED record. Today's `prepareDocument` also calls `ensureDashedLinetype`, which no furniture leaf uses.
3. **SC-conformance title.** The brief said the title "gains" the D-47 suffix. Keeping "over the empty catalog" would contradict the new body, so the title reads: "SC-conformance the kit validates, and conformance holds German and Turkish complete for every code-side word, over the furniture catalog, its committed library and snapshot (D-47)". I also added `reason: problems.join('\n')` to the `expect`, so a red run names its problems.
4. **`furniture_names.dart`** is generated from today's source file by a script, not copied from the brief's text. The content is the same ids and words as the brief's; the script verified them against the source.
5. **`words.dart`'s header comment** now describes the furniture words as present, not as Task 23's future.
6. **M-FU8** does not compile as written (see the table). I ran its intended equivalent, and it is red.

## Concerns

- The commit subject uses the brief's `feat(architecture)` scope. Earlier kit commits use `feat(kit-architecture)`. This is cosmetic; tell me if you want it reworded.
- None functional.

## Files changed

- `packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_catalog.dart` (new)
- `packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_names.dart` (new)
- `packages/jet_cad_2d_kit_architecture/lib/src/furniture/furniture_source.dart` (new)
- `packages/jet_cad_2d_kit_architecture/tool/generate_furniture_library.dart` (new)
- `packages/jet_cad_2d_kit_architecture/assets/library/furniture.jetlib` (new, generated)
- `packages/jet_cad_2d_kit_architecture/assets/library/furniture.snapshot.json` (new, generated)
- `packages/jet_cad_2d_kit_architecture/lib/src/words/words.dart`
- `packages/jet_cad_2d_kit_architecture/pubspec.yaml`
- `packages/jet_cad_2d_kit_architecture/test/support/place_entry.dart` (new)
- `packages/jet_cad_2d_kit_architecture/test/furniture/furniture_library_test.dart` (new, ported)
- `packages/jet_cad_2d_kit_architecture/test/furniture/package_assets_test.dart` (new, ported)
- `packages/jet_cad_2d_kit_architecture/test/scaffold/words_test.dart`
