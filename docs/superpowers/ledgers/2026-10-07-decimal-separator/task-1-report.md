# Task 1 report — the document and schema 8 (E1, E2)

Nothing is committed, pushed or staged. No `analysis_options.yaml` changed (`git status` shows none).

## Files changed (11)

Engine (`packages/jet_cad_2d`):
- `lib/src/document/page_component.dart`:
  - `enum DecimalSeparator { point, comma }` with `String get char` ('.' / ',').
  - `PageComponent.decimalSeparator`, default `point`, added to the constructor, `copyWith`, `==`, `hashCode`, `toString` and the class doc comment.
  - `toJson` writes `'decimalSeparator': name` right after `'background'`, which is its alphabetical place.
  - `fromJson`: `switch (json['decimalSeparator'] as String?) { null => point, final name => DecimalSeparator.values.byName(name) }`. A missing key gives `point`; an unknown name throws `ArgumentError`.
  - The barrel already exports the whole file (`export 'src/document/page_component.dart';`, line 28), so `DecimalSeparator` is public without a barrel change.
- `lib/src/codec/schema_version.dart`: `kSchemaVersion = 8`, with a history entry for 8 in the style of 6 and 7, following E2's text.
- `test/codec/json_codec_test.dart`, re-pinned:
  - the test at :513 is renamed "the schema version is 8, and a future document is refused by version" and pins 8;
  - QF3's pins at :588-589 now pin 8.
- `test/codec/instance_style_codec_test.dart`: the test at :80 is renamed "the schema this build writes is 8" and pins 8.
- `test/document/layer_header_test.dart`: the test at :100 is renamed "this build writes schema 8, reads 7, and refuses the next one".
  - It pins `kSchemaVersion` and the encoding's version at 8.
  - Its literal-7 decode is kept as a v7 read, as the brief asked.
- `test/document/page_component_test.dart`:
  - The key list now includes `decimalSeparator`.
  - A new fixture, `centimetreComma`: cm, 1:20, origin (-4180.5, 2645.25), `comma`.
  - New tests:
    - Q0-P1: the key is written by name in its alphabetical place and read back (value, `==`, `hashCode`).
    - Q0-P2: a v7 page with no key reads as `point`, and the rest of the fixture is unchanged.
    - Q0-P3: 'semicolon' makes `fromJson` throw `ArgumentError`.
    - Q0-P4: `==` and `hashCode` tell `point` and `comma` apart.
    - Q0-P5: `copyWith` sets the field, and keeps it through other changes and through `copyWith()`.
    - Q0-P6: `char`.
- `test/codec/page_component_roundtrip_test.dart`: a new group with the same fixture, attached to a document's root.
  - Q0-C1: `kSchemaVersion == 8`, and the encoded document says 8.
  - Q0-C2: a `comma` page round-trips through `encodeToString`/`decodeString`. The page JSON carries `"comma"`, the decoded page `==` the fixture, and re-encoding gives the same bytes.
  - Q0-C3: a v7 document is derived from this build's encoding by stripping the page key and setting `schemaVersion` to 7. Decoded through bytes, it gives `point`, with the rest of the fixture unchanged.

Regenerated assets:
- `packages/jet_cad_floor_plan/assets/library/furniture.jetlib`, by `dart run tool/generate_furniture_library.dart` from the package dir.
- `packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib`, by `dart run tool/generate_restaurant_library.dart` from the package dir.
- `apps/restaurant_demo/assets/plans/salon.json` and `teras.json`, by `UPDATE_SAMPLES=1 flutter test test/sample_plans_test.dart`.
  - I read the test first. It writes `assets/plans/$name.json` when `UPDATE_SAMPLES == '1'`, then compares.
- Not touched: both `furniture_pre_09c.jetlib` fixtures.

## Diffs of the regenerated files against HEAD

- `furniture.jetlib`: `git show HEAD:… | sed 's/"schemaVersion":7/"schemaVersion":8/' | cmp - file` found them identical.
  - So the only difference is `"schemaVersion":7` → `8`.
  - The file contains no `decimalSeparator`, because a library document has no page.
- `restaurant.jetlib`: the same check found them identical, and it has no `decimalSeparator` either.
- `salon.json`, from `git diff -U0`:
  - `- "schemaVersion": 7,` / `+ "schemaVersion": 8,`
  - `+    "decimalSeparator": "point",` (new line 1866, right after `"background"`)
- `teras.json`, from `git diff -U0`:
  - the same `schemaVersion` 7→8 line;
  - `+    "decimalSeparator": "point",` (new line 1101).

## Named mutants

Each mutant was applied, the five affected suites were run, and the file was then restored from a byte copy of the working version. `cmp` confirmed both files matched after all four.

| Mutant | Change | Red tests | Failure line |
|---|---|---|---|
| M1, key not written | `toJson` without the `decimalSeparator` line | `toJson keys are alphabetical and fromJson round-trips by value` | `Expected: [` ... `Actual: [` (key list) |
| | | `Q0-P1 decimalSeparator is written by name in its alphabetical place and read back` | `Expected: 'comma'` / `Actual: <null>` |
| | | `… Q0-C2 a comma page round-trips, and the bytes are stable` | `Expected: 'comma'` / `Actual: <null>` |
| | | Summary | `+66 -3: Some tests failed.` |
| M2, key not read | `fromJson` always `point` (`final _ => DecimalSeparator.point`) | `Q0-P1` | `Expected: DecimalSeparator:<DecimalSeparator.comma>` / `Actual: DecimalSeparator:<DecimalSeparator.point>` |
| | | `Q0-P3 an unknown separator name is refused with an ArgumentError` | `Expected: throws <Instance of 'ArgumentError'>` / `Actual: <Closure: () => PageComponent>` |
| | | `Q0-C2` | `Expected: …comma>` / `Actual: …point>` |
| | | Summary | `+66 -3: Some tests failed.` |
| M3, `kSchemaVersion = 7` | the constant left at 7 | `Q0-C1 this build writes schema 8` | `Expected: <8>` / `Actual: <7>` |
| | | `the schema this build writes is 8` | same failure |
| | | `the schema version is 8, and a future document is refused by version` | same failure |
| | | `QF3 save, load and save …` | same failure |
| | | `DocumentHeader.currentLayer this build writes schema 8, reads 7, and refuses the next one` | same failure |
| | | Summary | `+64 -5: Some tests failed.` |
| M4, field out of `==` | the `other.decimalSeparator == decimalSeparator &&` line removed | `Q0-P4 == and hashCode distinguish the separator` | `Expected: false` / `Actual: <true>` |
| | | Summary | `+68 -1: Some tests failed.` |

## Gates (run after the regeneration; real output lines)

- `packages/jet_cad_2d`:
  - `dart test`: `00:25 +1251 -2: Some tests failed.` The 2 failures are exactly the standing pair in `test/testing/generate_document_test.dart`:
    - "the default document is the one Plan 2 measured, byte for byte"
    - "both text fractions default to zero and change nothing"

    Their expected values are unchanged.
  - `dart analyze`: `No issues found!`
  - format: `Formatted 169 files (0 changed)`, exit 0.
- `packages/jet_cad_floor_plan`:
  - `flutter test`: `04:42 +1359: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 8.7s)`
  - format: `Formatted 234 files (0 changed)`, exit 0.
- `packages/jet_cad_restaurant_symbols`:
  - `flutter test`: `00:02 +97: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 4.2s)`
  - format: `Formatted 15 files (0 changed)`, exit 0.
- `apps/restaurant_demo`:
  - `flutter test`: `00:23 +35: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 4.3s)`
  - format: `Formatted 4 files (0 changed)`, exit 0.
- `apps/floor_planner`:
  - `flutter test`: `01:43 +207: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 6.1s)`
  - format: `Formatted 46 files (0 changed)`, exit 0.

The byte pins (`furniture_library_test`, `restaurant_library_test`, `sample_plans_test`) and the `pre_09c` tests, which are now v7 reads, pass inside these runs.

## Decisions and notes

- `toString` now ends with `, <separator name>)`. No test anywhere pins `PageComponent`'s `toString`; I checked with grep.
- `fromJson` casts with `as String?` before `byName`. A non-string value throws a `TypeError`, as the sibling `displayUnit` / `orientation` reads do.
- The new tests carry ids (Q0-P*, Q0-C*), following the `QF3` style of `json_codec_test`. The two re-pinned test names keep their old wording, with 7 → 8 only where they describe the current version.
- The new codec tests live in `test/codec/page_component_roundtrip_test.dart`, the existing page-through-codec suite, rather than in `json_codec_test.dart`. The schema pins in `json_codec_test.dart` were re-pinned in place.
- Q0-C3, the v7 read, stays green under M3 by design: it declares 7 explicitly, and a build at 7 or 8 reads it.
- I found no other literal version pins outside the engine. `apps/floor_planner/test/document_open_test.dart:325` uses `kSchemaVersion + 1`, so it follows the constant.

## Surprises / could not do

- No surprises. The libraries contain no page, so their only change is the version.
- Not run: the render package `jet_cad_2d_flutter` and `tool/ci`. Neither is in this task's gate list, and nothing they read moved: the render package does not read the page codec's keys or the version literal. The controller may want to run them.
- Environment: `dart` / `flutter` are not on PATH here. I used `/root/sdk/flutter/bin`.
