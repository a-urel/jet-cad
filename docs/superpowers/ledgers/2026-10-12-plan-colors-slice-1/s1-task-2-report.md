# Report: plan colours Slice 1, Task 2 (schema 10, PC-2)

Status: DONE. Commit `9ab32974` on `spec/plan-colors` (parent `73ad125`).
Trailer names Claude Sonnet 5.5 (the session's attribution rule), not the brief's Opus 5.5 text.

## Implemented

- `kSchemaVersion = 10` with a history entry after 9's (`packages/jet_cad_2d/lib/src/codec/schema_version.dart`). No codec change: there is no migration function, the empty 9 -> 10 migration is the constant alone.
- Fixture moved (pure move) from `schema_9_test.dart` to `test/codec/support/schema_fixture.dart` (`tableDataType`, `unknownKey`, `fixture`, `withVersion`, all already public; fixture body byte-identical). I added a header comment to the new file (the moved explanatory header comment text lives there now); `schema_9_test.dart` keeps a shorter header.
- New `test/codec/schema_10_test.dart` with S10-1 and S10-2 (as in the brief).
- All forced re-pins, the four encodings regenerated.

## TDD evidence

Step 1 (pure move), `cd packages/jet_cad_2d && dart test test/codec/schema_9_test.dart`:
```
00:00 +3: All tests passed!
```
Step 3 RED (before the bump), `dart test test/codec/schema_10_test.dart`:
```
00:00 +0 -1: S10-1 this build writes schema 10, first [E]
  Expected: <10>
    Actual: <9>
00:00 +1 -1: Some tests failed.
```
(S10-2 passed before the bump, as the brief predicted; it is red only under M-C10b.)
Step 4 GREEN after the bump:
```
00:00 +2: All tests passed!
```

## Files changed

Engine: `lib/src/codec/schema_version.dart`; tests `codec/instance_style_codec_test.dart`, `codec/json_codec_test.dart`, `codec/page_component_roundtrip_test.dart`, `codec/schema_9_test.dart`, `codec/schema_10_test.dart` (new), `codec/support/schema_fixture.dart` (new), `document/layer_header_test.dart`, `testing/generate_document_test.dart` (comments only).
Planner: `jet_cad_floor_plan/test/host/controller_test.dart`, `test/host/table_data_test.dart`. Demo: `apps/restaurant_demo/test/events_test.dart`.
Regenerated: `furniture.jetlib`, `restaurant.jetlib`, `salon.json`, `teras.json`.
No `analysis_options.yaml` touched (`git status` checked before commit).

## Re-pinned tests (old -> new), all within the named list

- `json_codec_test.dart:518` (now :518-520): test name "the schema version is 9..." -> "10"; `kSchemaVersion` 9 -> 10; added a history comment line. `:590-591` (QF3): `kSchemaVersion` and `['schemaVersion']` 9 -> 10, history comment line added.
- `instance_style_codec_test.dart:78-83`: name "...is 9" -> "is 10"; pin 9 -> 10; history comment line.
- `page_component_roundtrip_test.dart:83-88` Q0-C1: name "schema 9" -> "schema 10"; both pins -> 10.
- `layer_header_test.dart:98-107`: name -> "writes schema 10, reads 7, and refuses the next one"; both pins -> 10; comment "Plan colours Slice 1 Task 2: writes 10 (PC-2)"; the refused next is `kSchemaVersion + 1` (= 11, no literal to change); the literal-7 read untouched.
- `schema_9_test.dart`: header comment reworded ("reads an 8 document unchanged...; since schema 10 (PC-2) it writes 10, and refuses an 11"); S9-1 name/pins/empty-document pin -> 10; S9-2 name "saves to the 10 bytes this build wrote" and its comment "the 10 file this build writes" (its expected bytes are this build's own encoding, so the assertions did not move); S9-3 -> "an 11 document is refused ..., names 11 and 10" (document version 11, `found` 11, message contains `unsupported schemaVersion 11` and `this build writes 10`). Removed the now-unused `testing.dart` import (analyze found it).
- `generate_document_test.dart`: comments only: an added "Plan colours Slice 1 Task 2: kSchemaVersion moved from 9 to 10..." paragraph in the first fingerprint test and "(kSchemaVersion 8 to 9 to 10; owed on macOS)" in the second. Expected fingerprint values untouched.
- `controller_test.dart` group (:959-1031): group name "schema 9 (E-9), 10 since plan colours" and the lead comment; CS1 declares 10 (both pins); CS2 saves to the 10 bytes (local `nine` renamed `ten`, since it holds this build's encoding); CS3 "an 11 plan" (local `ten` -> `eleven`), message contains `unsupported schemaVersion 11` and `this build writes 10`. CS4 untouched.
- `table_data_test.dart:118`: 9 -> 10.
- `events_test.dart` DE3: name "declares schema 10", `['schemaVersion'], 10`.

## The four encodings: version-only check, file by file

Generators: `dart run tool/generate_furniture_library.dart` ("wrote assets/library/furniture.jetlib: 65237 bytes"), `dart run tool/generate_restaurant_library.dart` ("wrote assets/restaurant.jetlib: 130778 bytes"), `UPDATE_SAMPLES=1 flutter test test/sample_plans_test.dart` (+2 passed). `git diff --stat`: 4 files, 1 line each.

The brief's `for` loop mixing git with other tools is refused by this session's worktree guard, so each file was checked separately: `git show HEAD:<f> > /tmp/old_*`, `sed -E 's/"schemaVersion": ?9,/<spelling>/'`, then `cmp` against the working file. The spelling is the file's own (`"schemaVersion": 10,` with a space for the two `.json` plans; `"schemaVersion":10,` without for the two `.jetlib`).
```
SALON-ONLY-VERSION         (apps/restaurant_demo/assets/plans/salon.json)
TERAS-ONLY-VERSION         (apps/restaurant_demo/assets/plans/teras.json)
FURNITURE-ONLY-VERSION     (packages/jet_cad_floor_plan/assets/library/furniture.jetlib)
RESTAURANT-ONLY-VERSION    (packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib)
```
(each printed only because `cmp` exited 0). The two `furniture_pre_09c.jetlib` fixtures were not touched (declare 7).

## Gates (all run after the final edit, from each package directory)

- `jet_cad_2d`: `dart test --file-reporter json:/tmp/eng_run.json` exit 1, "-2: Some tests failed", the two standing fingerprints (`both text fractions default to zero...`, `the default document is the one Plan 2 measured...`). `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d /tmp/eng_run.json` -> `packages/jet_cad_2d: 1290 tests; the standing failures and skips, exactly`, exit 0. `dart analyze --fatal-infos`: "No issues found!"; `dart format --output=none --set-exit-if-changed .`: 0 changed.
- `jet_cad_2d_flutter`: `flutter test` exit 1; `expect_failures` exit 1 with exactly: "standing failure passed or did not run: test/golden/text_lod_ladder_golden_test.dart :: text lod ladder rung 1 / rung 2 (RenderBackend.canvas)". This is the recorded macOS standing difference (rungs 1-2 pass), not a finding; nothing else differs. analyze: no issues; format: 0 changed.
- `jet_cad_2d_gpu`: `flutter test` exit 0 (+20); `expect_failures` -> "20 tests; the standing failures and skips, exactly" exit 0; analyze/format clean.
- `jet_cad_floor_plan` (`--enable-vmservice`): "+1931: All tests passed!"; analyze: no issues; format clean.
- `jet_cad_restaurant_symbols`: "+97: All tests passed!"; analyze/format clean.
- `apps/restaurant_demo`: "+68: All tests passed!"; analyze/format clean.
- `apps/floor_planner` (`--enable-vmservice`): "+212: All tests passed!"; analyze/format clean.

## Mutants

Each applied, run, seen red, reverted exactly (the pre-mutation file copied to /tmp and copied back; `git diff --stat` after shows only the intended `schema_version.dart` change, `json_codec.dart` clean; `dart test test/codec test/document` then +518 all passed).

- **M-C10** (`const int kSchemaVersion = 9;` with tests re-pinned). Commands: `dart test test/codec test/document/layer_header_test.dart` (engine); `flutter test test/sample_plans_test.dart test/events_test.dart` (demo); `flutter test test/host/controller_test.dart test/host/table_data_test.dart` (planner). Red: S10-1 (`Expected: <10> Actual: <9>`), S9-1, `instance_style_codec_test` "the schema this build writes is 10", Q0-C1, json_codec "the schema version is 10..." and QF3, S9-3, layer_header "this build writes schema 10..." (engine "-8: Some tests failed"); demo: both sample plans "the committed ... plan is the built one", DE3 (plus DE1-DE8, the v10 assets being refused by a v9 build); planner: CS1, CS3, HD1 (table_data_test). Killers confirmed.
- **M-C10b** (`json_codec.dart:106`: `version > kSchemaVersion` -> `version != kSchemaVersion`). Same engine command. Red: S10-2 (`a 9 document reads unchanged...`), S9-2, the literal-7 reads (layer_header "a v6 document..." and "this build writes schema 10, reads 7...", Q0-C3, schema_v3_fixture_test x2, instance_style v5 tests); "-9: Some tests failed". Killers confirmed.

## Deviations

- Commit trailer is `Claude Sonnet 5.5` (session attribution rule) rather than the brief's `Claude Opus 5.5`.
- Step 6's loop run file by file (worktree guard), as pre-announced.
- Added a small header comment to `schema_fixture.dart` (and shortened `schema_9_test.dart`'s header); the fixture code itself is a verbatim move. `dart format` re-wrapped `schema_10_test.dart` S10-1's `jsonDecode(...)` call (formatter output, semantics identical to the brief's).
- Removed `schema_9_test.dart`'s now-unused `testing.dart` import (analyze flagged it).
- Renamed two local variables in the planner's CS2/CS3 (`nine`->`ten`, `ten`->`eleven`) so names match the values; wording otherwise kept.

## Self-review

- Every re-pin sits in the brief's named list; no test outside it had to change (no finding). The standing fingerprints' expected values are untouched and still fail only the two standing ones.
- Brief's `jet_cad_2d/test/codec` line numbers held (verified before editing).
- `apps/floor_planner` `document_open_test.dart` and `controller_test.dart:224` follow the constant and passed unedited.

## Concerns

None blocking. The engine's two fingerprints' true values moved again (macOS re-baseline still owed, as the brief says).
