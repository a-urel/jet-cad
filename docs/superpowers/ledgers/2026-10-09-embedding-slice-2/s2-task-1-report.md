# Slice 2, Task 1 report — schema 9 (E-9)

Commit `14e6c7f` on `claude/exciting-pasteur-9m22jv` (parent `8c3e877`), pushed.
No `analysis_options.yaml` staged or changed (`git status` clean after the commit).
Flutter: `/root/sdk/flutter/bin` on PATH, `CI=true`.

## What was built

- `packages/jet_cad_2d/lib/src/codec/schema_version.dart`
  - `kSchemaVersion = 9` (line 48).
  - A history entry for 9 at lines 38-47, in the style of 6-8. It says:
    - there is no new field and nothing to default; the v8->v9 migration is empty, so a v8 (or v7) document reads unchanged;
    - the bump is not for the reader's drawing. It exists so that no build silently carries the planner's `jetcad.table_data` host links;
    - a v8 build would keep that payload as preserve-unknown data, but would leave it orphaned when the table is deleted.
  - The engine's only edit.
- `packages/jet_cad_2d/test/codec/schema_9_test.dart` (new, 122 lines).
  - The fixture is `generateDocument(400, …)` with:
    - nested instances (depth 2), 30% mirrored and 30% non-uniformly scaled;
    - 2 groups, 3 layers, 20% dashed;
    - a comma page in cm at 1:20 with its origin at (-4180.5, 2645.25);
    - the current layer set to the last layer, not layer 0.
  - The 8 and 10 documents are derived from this build's encoding (version set, then through bytes).
  - S9-1: this build writes schema 9, as the first key, in every encoding (the fixture, and an empty document).
  - S9-2: an 8 document loads unchanged, drawing and all, and saves to the 9 bytes this build wrote.
    - It checks every entity's kind, layer and coordinates by handle, every node, and every instance's transform (by parts) and definition.
    - It also checks the extents, the typed page and `currentLayer`.
    - Re-encoding gives exactly the original 9 string.
  - S9-3: a 10 document is refused with a `SchemaVersionError` whose `found` is 10 and whose `toString` contains `unsupported schemaVersion 10` and `this build writes 9`.
- `packages/jet_cad_floor_plan/test/host/controller_test.dart`: a new group `schema 9 (E-9)`, appended at lines 958-1047 (+90 lines, additions only). It uses `embedding.embeddingPlanJson()`.
  - CS1 (M-H26a): `designJson()` of the fixture declares 9, and still does after a design edit.
  - CS2 (M-H26b): an 8 plan derived from the fixture's bytes opens unchanged through both the constructor and `load` (after `planJson()`).
    - `tableDetails` equal those of the 9 plan (10 tables).
    - `designJson()` equals the original 9 bytes, and equals the 9-loaded controller's.
  - CS3: a 10 plan is refused by `load` and by the constructor. Each throws a `FormatException` whose message starts with `Not a floor plan: ` and contains `unsupported schemaVersion 10` and `this build writes 9`.
    - The plan is left as it was: same `activeDocument`, `designJson()` byte-equal, `tableDetails` equal, and the prior design edit still undoable.
  - CS4: in the selection mode after a move, the service layout JSON still has `format` `jet_cad.service_layout`, `version` 1 (as a literal) and no `schemaVersion`.

## Forced test edits (exactly the plan's list)

- `test/codec/json_codec_test.dart`
  - In the test at :513, the name "8" becomes "9", a comment line is added ("Slice 2 Task 1: 9 so that no older build carries table data (E-9).") and the pin is now `expect(kSchemaVersion, 9)`.
  - QF3's closing pins get a comment line ("Slice 2 Task 1: to 9 with the host's table data (E-9).") and both pins now read 9.
- `test/codec/instance_style_codec_test.dart:80-84`: the name "8" becomes "9", one comment line is added and the pin is now 9.
- `test/codec/page_component_roundtrip_test.dart:83-89`: in Q0-C1 the name "8" becomes "9" and both pins are now 9. No comment was added.
- `test/document/layer_header_test.dart:99-108`: the name "8" becomes "9", one comment line is added and both pins are now 9. The literal-7 read is untouched.
- `test/testing/generate_document_test.dart`: comments only, one paragraph in each of the two fingerprint tests ("kSchemaVersion moved from 8 to 9 … owed on macOS"). The expected values are not touched.
- No other existing test changed. Nothing else was forced.

## Re-encoding (the version line only)

Commands:
- in `packages/jet_cad_floor_plan`: `dart run tool/generate_furniture_library.dart`, which printed `wrote assets/library/furniture.jetlib: 65236 bytes`;
- in `packages/jet_cad_restaurant_symbols`: `dart run tool/generate_restaurant_library.dart`, which printed `wrote assets/restaurant.jetlib: 130777 bytes`;
- in `apps/restaurant_demo`: `UPDATE_SAMPLES=1 flutter test test/sample_plans_test.dart`, which ended `00:00 +2: All tests passed!`.

Evidence:
- The libraries: `git show HEAD:<f> | sed 's/"schemaVersion":8/"schemaVersion":9/' | cmp - <f>` printed "identical after 8->9" for both `furniture.jetlib` and `restaurant.jetlib`.
- The plans: `git diff -U0` shows, for each of `salon.json` and `teras.json`, exactly
  ```
  @@ -2 +2 @@
  - "schemaVersion": 8,
  + "schemaVersion": 9,
  ```
- Both `furniture_pre_09c.jetlib` fixtures are not touched.

## Mutants

Each mutant was applied by editing the file, after first copying it to the scratchpad. Each was restored from that copy, and `cmp` and `git diff --quiet HEAD` confirmed the restore.

**M-H26a: `kSchemaVersion` left at 8** (`const int kSchemaVersion = 8;`).
- Engine (`dart test test/codec test/document/layer_header_test.dart`): `00:00 +51 -8: Some tests failed.` The red tests:
  - `S9-1 this build writes schema 9, first, in every encoding`
  - `S9-2 an 8 document loads unchanged, …` (its premise: the "8" file equals the "9" file)
  - `S9-3 a 10 document is refused by its version, and the error names 10 and 9` (the message says "writes 8")
  - `the schema version is 9, and a future document is refused by version`
  - `QF3 save, load and save of a document holding not-pickable entities is byte-identical, and the bits come back`
  - `the schema this build writes is 9`
  - `the decimal separator through the codec (spec Q0 M-Q0-c) Q0-C1 this build writes schema 9`
  - `DocumentHeader.currentLayer this build writes schema 9, reads 7, and refuses the next one`
- Planner (`flutter test test/host/controller_test.dart test/symbols/furniture_library_test.dart`): `00:02 +41 -153: Some tests failed.`
  - The red tests include `schema 9 (E-9) CS1 M-H26a: designJson() of the fixture declares 9`, CS2 and CS3.
  - They include the byte pin `the asset the committed bytes equal the built library`.
  - Every other `furniture_library_test` test is red too, because an 8 build refuses the committed 9 asset.
- Restaurant symbols (`flutter test`): `00:02 +2 -93: Some tests failed.`
  - The red tests include the byte pin `the asset RL1 the committed bytes equal the built library`, RL4-RL15, SC2 and SC3.
  - `symbol_names_test.dart` fails at loading.
- Demo (`flutter test test/sample_plans_test.dart`): `00:00 +0 -2: Some tests failed.`
  - `the committed salon plan is the built one`
  - `the committed teras plan is the built one`

**M-H26b: the guard tightened to `if (version != kSchemaVersion)`**, in `json_codec.dart:106`.
- Engine (`dart test test/codec test/document/layer_header_test.dart`): `00:00 +51 -8: Some tests failed.` The red tests:
  - `S9-2 an 8 document loads unchanged, drawing and all, and saves to the 9 bytes this build wrote (the migration is empty)`
  - `the decimal separator through the codec (spec Q0 M-Q0-c) Q0-C3 a v7 document, whose page has no key, loads as point`
  - `DocumentHeader.currentLayer this build writes schema 9, reads 7, and refuses the next one`
  - `DocumentHeader.currentLayer a v6 document (no currentLayer key) loads with layer 0 current`
  - `a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer`
  - `a v5 document resolves bit-identically under a v6 build a v6 build refuses nothing it wrote and everything from the future`
  - `a version-3 document loads under the version-4 build`
  - `a version-3 document survives a round-trip unpadded`
- Planner (`flutter test test/host/controller_test.dart`): `00:01 +38 -1: Some tests failed.`
  - `schema 9 (E-9) CS2 M-H26b: an 8 plan opens unchanged through the constructor and load, and saves to the 9 bytes, tables and all`

## Gates (after the change; real tails)

- Engine `packages/jet_cad_2d`. This was re-run after the last comment-only edit.
  - `dart test --file-reporter json:<run.json>`: `00:23 +1256 -2: Some tests failed.` The two failures are the standing fingerprint pair.
  - The comparison, `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d <run.json>`, printed `packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly`, exit 0.
  - `dart analyze --fatal-infos`: `No issues found!`
  - format: `Formatted 170 files (0 changed)`, exit 0.
- Render `packages/jet_cad_2d_flutter`:
  - `flutter test --file-reporter json:…`: `01:19 +1366 ~1 -7: Some tests failed.` (exit 1, the standing 7 plus 1 skip).
  - The comparison printed `packages/jet_cad_2d_flutter: 1374 tests; the standing failures and skips, exactly`, exit 0.
  - `flutter analyze`: `No issues found! (ran in 13.2s)`
  - format: `Formatted 223 files (0 changed)`.
- `packages/jet_cad_2d_gpu`:
  - test: `00:01 +20: All tests passed!`
  - The comparison printed `packages/jet_cad_2d_gpu: 20 tests; the standing failures and skips, exactly`, exit 0.
  - analyze: `No issues found! (ran in 4.5s)`
  - format: `Formatted 10 files (0 changed)`.
- `packages/jet_cad_floor_plan`:
  - test: `05:07 +1518: All tests passed!`
  - analyze: `No issues found! (ran in 15.8s)`
  - format: `Formatted 250 files (0 changed)`.
- `packages/jet_cad_restaurant_symbols`:
  - test: `00:02 +97: All tests passed!`
  - analyze: `No issues found! (ran in 5.0s)`
  - format: `Formatted 15 files (0 changed)`.
- `apps/restaurant_demo`:
  - test: `00:33 +47: All tests passed!`
  - analyze: `No issues found! (ran in 5.4s)`
  - format: `Formatted 5 files (0 changed)`.
- `apps/floor_planner`:
  - test: `02:00 +212: All tests passed!`
  - analyze: `No issues found! (ran in 6.8s)`
  - format: `Formatted 47 files (0 changed)`.

The non-engine gates ran before two edits:
- a comment-only removal in `page_component_roundtrip_test.dart` (engine), which keeps that re-pin to the number only;
- a doc-comment reword in `schema_9_test.dart` (engine).

Both touch only the engine's tests, and the engine gate was re-run after them.

## Findings and deviations

- **M-H26a's blast radius.** Under the mutant, an 8 build refuses the committed 9 assets, so whole library suites go red (153 in the planner run, 93 in restaurant symbols), not just the byte pins. This is expected, not a defect.
- **`Transform2` has no `==`**, by design (`transform2.dart:124`). S9-2 therefore compares transforms by their six parts, exactly.
- **CS3 needs a pump before reading `canUndo`.** `canUndo` refreshes on a pump, so the test pumps after the edit and again after the refused load.
- **The 7 → 8 comment and S-1.** Q0's "7 → 8" comment in the fingerprint tests stays. A new paragraph records 8 → 9, and the standing set is unchanged, per S-1.
- No other literal schema-8 pins exist in any package's Dart tests (`git grep`). `document_open_test.dart:325` (`kSchemaVersion + 1`) and `controller_test.dart` C8 (9999) follow the constant and pass.

## Fixes

Commit `a148b51` on `claude/exciting-pasteur-9m22jv` (parent `2193fca`), pushed. Only
`packages/jet_cad_2d/test/codec/schema_9_test.dart` changed (+80 −13). No lib file and no
`analysis_options.yaml` changed.

### R-1 (accepted): S9-2's fixture is no longer degenerate for an 8 → 9 read

`fixture()` now takes a `TextMeasurer`. Every test passes a `MetricModelMeasurer`, and
S9-2 decodes with the same one, so the text has a size and the extents comparison covers it.
On top of the old fixture it adds:

- **The header:** `units` millimeters, `scale` 0.05, `globalLinetypeScale` 2.5,
  `importedExtents` (−1250.5, −730.25 .. 98000.75, 41000.5), and two `customVariables`
  (`$ZETA`, `$ALPHA`) inserted out of order.
- **The layers:** `layer_1` is hidden with transparency 60. `layer_2` (current) is locked
  with transparency 25. Both use `SetLayerCommand.restore`.
- **Raw data:** one `rawData` entry (`SourceKind.dxf`) on the first instance.
- **Labels and attributes:** `labelFraction: 0.05` and `attributedInstanceFraction: 0.5`,
  so `text` and `attrib` entities are present.
- **An unknown component:** `jetcad.table_data` on the first instance, attached with
  `attachUnknown`. The engine does not register it, so it is preserve-unknown.
- **An unknown top-level key:** `jetcad.hostNotes` in `unknownDocumentFields`. I verified
  that the codec preserves unknown top-level keys: `decode` copies every key not in
  `_knownKeys` into `unknownDocumentFields`, and `encode` spreads them back after
  `handleSeed` (`json_codec.dart:120-122, 83`). So I included it rather than skipping it.

S9-2 now opens with premise checks on the 9 bytes for each of these:
- linetype scale 2.5 and scale 0.05;
- two custom variables;
- one hidden, one locked and two translucent layers;
- one raw-data entry;
- `jetcad.page` and `jetcad.table_data` under `components`;
- the unknown key;
- `text` and `attrib` entities in the document.

A later edit cannot quietly make the fixture degenerate again.

The assertion is unchanged:
- the 8 document is derived through bytes;
- it is compared entity by entity, node by node, and on extents, page and current layer;
- saved again, it equals the original 9 bytes.

### R-2 (accepted)

S9-1 now also checks `encode(DraftDocument.empty()).keys.first == 'schemaVersion'`. The
test's name is unchanged.

### R-3

Report only, no code change. The history entry starts at `schema_version.dart:39`, not 38;
`:38` is the `///` separator. S9-1 now does check "first, in every encoding" for both
encodings it writes.

### The reviewer's mutants, re-applied against the engine suite alone

Each mutant is applied to `lib/src/codec/json_codec.dart` in the reviewer's form. A shared
`static int _v` is set to `version` right after the guard, and each mutant acts only when
`_v < 9`:

- **X2:** keeps only `jetcad.page` in the `components` map before `loadJson`.
- **X3a:** `record.copyWith(visible: true, locked: false)` for each layer.
- **X3b:** `record.copyWith(transparency: 0)` for each layer.
- **X4a:** `header.globalLinetypeScale = 1.0` after `_loadHeader`'s cascade.
- **X4b:** `header.customVariables.clear()` after `_loadHeader`'s cascade.
- **X5:** `rawData.loadJson` is skipped.

Each run was the whole `dart test` in `packages/jet_cad_2d`. The two standing fingerprint
failures appear in every run and are not counted as kills. Before each mutant, the file was
copied to the scratchpad. After each run it was restored from that copy, and `cmp` printed
nothing (identical) every time. At the end, `git diff --quiet HEAD -- packages/jet_cad_2d/lib`
was clean.

| Mutant | Engine tail | Killer (beyond the standing pair) | What the byte diff showed |
|---|---|---|---|
| X2 | `00:21 +1255 -3` | S9-2 (`schema_9_test.dart:170`, the byte comparison) | `jetcad.table_data` missing after the page |
| X3a | `00:25 +1255 -3` | S9-2 (`:170`) | `"visible":false` read back as `true` |
| X3b | `00:27 +1255 -3` | S9-2 (`:170`) | `"transparency":60` read back as `0` |
| X4a | `00:25 +1255 -3` | S9-2 (`:170`) | `"globalLinetypeScale":2.5` read back as `1.0` |
| X4b | `00:35 +1255 -3` | S9-2 (`:170`) | `"customVariables":{"$ALPHA"…` read back as `{}` |
| X5 | `00:27 +1255 -3` | S9-2 (`:170`) | `"rawData":{"123":{"dx…` read back as `{}` |

The four former survivors (X3b, X4a, X4b, X5) are now red. X2 and X3a no longer depend on
the planner's CS2: the engine's own S9-2 kills them.

### Gates (engine `packages/jet_cad_2d`, after the change; real tails)

- `dart test --file-reporter json:<run.json>` ran green against the standing set. A separate
  plain `dart test` run ended `00:38 +1256 -2: Some tests failed.`, and the 2 failures are the
  standing fingerprint pair.
- From the repo root, `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d
  --root packages/jet_cad_2d <run.json>` printed `packages/jet_cad_2d: 1258 tests; the
  standing failures and skips, exactly` and exited 0.
- `dart analyze --fatal-infos` printed `No issues found!` and exited 0.
- `dart format --output=none --set-exit-if-changed .` printed `Formatted 170 files (0 changed)`
  and exited 0.
