# Task 1 review — the document and schema 8 (E1, E2)

**Verdict: Approved with fixes.** One minor finding, nothing blocking.

The reviewer did the work in a copy, `/tmp/q0-t1-review`, and wrote nothing
else under `/home/user/jet-cad`. Every mutated file was restored there and
checked with `cmp` against the working tree.

## Verified

1. **E1/E2 diff.**
   - The field is in the constructor (default `point`), `copyWith`, `==`,
     `hashCode` and `toString`.
   - `toJson` writes `'decimalSeparator': name` immediately after
     `'background'`, which is its alphabetical place.
   - `fromJson` treats the key as optional: `null` gives `point`, and any
     other value goes through `values.byName`.
   - `DecimalSeparator { point, comma }` has a `char` getter. It is exported
     because the barrel exports the whole file. No other type uses the name
     anywhere in the repo.
   - `kSchemaVersion = 8`, with a history entry in the style of 6 and 7.
   - Nothing is out of scope. The doc comments are accurate.
2. **Encodings.**
   - `furniture.jetlib` and `restaurant.jetlib`: running
     `git show HEAD:… | sed 's/"schemaVersion":7/"schemaVersion":8/' | cmp - file`
     finds no difference, so the version is the only change. Neither file
     contains the new key, because a library has no page.
   - `salon.json` and `teras.json`: the diff is `schemaVersion` 7→8 plus one
     `"decimalSeparator": "point"` line each.
   - Both `pre_09c` fixtures are untouched.
   - The byte pins are live. With the HEAD (v7) `salon.json` or
     `furniture.jetlib` restored in the copy, `sample_plans_test` and
     `furniture_library_test` go red.
3. **Pins.**
   - Every F-8 version pin is now 8: `json_codec_test` (:517, :588-589),
     `instance_style_codec_test:82` and `layer_header_test:101,106`.
   - The test names were renamed. That includes `instance_style_codec_test`'s
     "the schema this build writes is 8", which also said 7 even though F-8
     did not list it.
   - The deliberate older reads remain:
     - v7: `layer_header_test:108` and `page_component_roundtrip_test:113`;
     - v6: `layer_header_test:91`;
     - v5: `instance_style_codec_test:159`.
   - `git grep` finds no other literal schema-7 pin in code or tests.
     `CHANGELOG.md:16` ("schema 7") sits under the released 0.1.0 heading and
     is correct as history.
4. **Mutants.** Each was run against the five affected test files.

   | Mutant | Red |
   |---|---|
   | M1 key not written | Q0-C2, Q0-P1, key-list test |
   | M2 key not read (always `point`) | Q0-C2, Q0-P1, Q0-P3 |
   | M3 `kSchemaVersion = 7` | Q0-C1, both renamed pins, QF3, layer_header |
   | M4 field out of `==` | Q0-P4 |
   | hashCode omits field | Q0-P4 |
   | copyWith ignores the argument | Q0-P2, Q0-P4, Q0-P5, Q0-C3 |
   | copyWith resets to `point` | Q0-P5 |
   | fromJson reads `'separator'` | Q0-C2, Q0-P1, Q0-P3 |
   | key written after `pageBreaks` | Q0-P1, key-list test |
   | absent key → `comma` | Q0-P2, Q0-C3 |
   | unknown name → `point` (no throw) | Q0-P3 |
   | toJson writes `char` | Q0-P1, Q0-C2 and 4 others |
   | toJson writes constant `'point'` | Q0-P1, Q0-C2 |
   | ctor default `comma` | Q0-P5 |
   | `char` swapped | Q0-P6 |
   | toString omits the field | **survives** (finding 2) |

   The fixtures are not degenerate. They use cm, 1:20, the origin
   (-4180.5, 2645.25) and `comma`.
5. **Gates, run in the copy.** These are the actual summary lines.
   - Engine:
     - `dart test`: `00:25 +1251 -2: Some tests failed.` The two failures are
       exactly the standing pair in `generate_document_test`.
     - `dart analyze`: `No issues found!`
     - `dart format`: `Formatted 169 files (0 changed)`, exit 0.
   - The demo's `sample_plans_test`: `00:00 +2: All tests passed!`
   - The floor planner package's `furniture_library_test`:
     `00:01 +155: All tests passed!`
   - The restaurant symbols' `flutter test` (which includes
     `restaurant_library_test`): `00:03 +97: All tests passed!`
   - The floor planner app's `wall_attach_end_to_end_test`, which reads a
     `pre_09c` fixture at v7: `00:07 +2: All tests passed!`
   - The render package, which the implementer did not run:
     - `flutter test`: `01:21 +1333 ~1 -7: Some tests failed.` The failures
       are the standing 7 text-ladder goldens, plus 1 skip.
     - `flutter analyze`: `No issues found!`

## Findings

1. **Minor: the fingerprint comments were not given the 7→8 move.**
   - Where: `packages/jet_cad_2d/test/testing/generate_document_test.dart`,
     :54-64 and :240-249.
   - Every earlier bump (3e, 3f.1, 12b) added a line to both comments saying
     the version moved and whether the values were re-baselined. The comments
     still end at "kSchemaVersion moved from 6 to 7 … Re-baseline owed on
     macOS".
   - Whoever re-baselines on macOS (spec E2, R-2) will not learn from the
     file that a second shift is folded in.
   - Fix: in each comment, add a "Plan Q0 Task 1: PageComponent gained
     `decimalSeparator` and kSchemaVersion moved from 7 to 8. Not
     re-baselined, owed on macOS." paragraph. Leave the expected values
     unchanged.
2. **Nit: `toString` is unpinned.** The toString-omits-field mutant survives.
   Under the testing bar no test is needed for a debug string, so no fix is
   required. It is recorded so that nobody counts it as covered.
3. **Note (spec): F-8 is incomplete.** F-8 names two test names containing
   "7". There were three: `instance_style_codec_test:79` also said 7. The
   implementer handled it correctly, and the spec need not change.
