# Slice 2, Task 1 review — schema 9 (E-9)

Commit under review: `14e6c7f` (parent `8c3e877`), branch
`claude/exciting-pasteur-9m22jv`. Reviewed in my own clones
(`/home/user/review-s2t1` for the gates, `/home/user/review-s2t1-mut` for the
mutants), both checked out at `14e6c7f`, `flutter pub get` from the root,
Flutter `/root/sdk/flutter/bin`, `CI=true`. Both clones are clean after the
review (`git status --short` empty); nothing was edited, committed or pushed in
`/home/user/jet-cad` except this file.

## Verdict: **Approve with fixes**

The diff is exactly Task 1, every gate is green with the standing sets exact,
both named mutants go red where the plan says, and the history comment is
accurate. One minor finding (R-1): the "8 loads unchanged" fixtures leave
several stored fields at their defaults, so a version-gated v8 read that drops
them survives both S9-2 and CS2 (four of my mutants). It does not block the
task, but it is a fixture fix, cheap to make now, and the testing bar asks for it.

## 1. The diff is exactly Task 1

`git diff --stat 8c3e877 14e6c7f`: 12 files, +250 −17.

- **Engine lib:** only `packages/jet_cad_2d/lib/src/codec/schema_version.dart`.
  The history entry for 9 is at `:39-47` and `kSchemaVersion = 9` is at `:48`.
  No other lib file in any package changed.
- **Forced test edits:** each one matches the plan's list (Global constraints, Task 1):
  - `json_codec_test.dart`: the test at `:512-518` changes its name to "9", adds one comment line and pins 9. QF3's closing pins (`:586-590`) add one comment line, and both pins now read 9.
  - `instance_style_codec_test.dart:79-84`: the name, one comment line, the pin.
  - `page_component_roundtrip_test.dart:83-89`: the name and both pins, with no comment.
  - `layer_header_test.dart:98-108`: the name, one comment line and both pins. The literal-7 read is untouched.
  - `generate_document_test.dart`: two comment paragraphs only (`:69-72`, `:261-263`). The expected values did not change.

  No other existing test changed. A grep found no literal schema-8 pin left in any Dart test:
  `git grep -nE "schemaVersion'?\]? ?[:=,] ?8\b|kSchemaVersion, 8" 14e6c7f -- '*.dart'`
  hits only `schema_9_test.dart:66`, which is the new test's own premise.
- **Re-encodings: only the version line differs.** For each of the four files I took
  `git show 8c3e877:<f>` and the committed `<f>`, replaced the
  `"schemaVersion": ?8` and `?9` occurrences with the same token, and ran `cmp`.
  All four printed "identical modulo version":
  - `furniture.jetlib`
  - `restaurant.jetlib`
  - `salon.json`
  - `teras.json`

  Each file declares exactly one `schemaVersion`. No non-doc file still
  declares a v8 encoding: `git grep -lE '"?schemaVersion"?[": ]+ ?8\b' 14e6c7f -- . ':!docs'`
  is empty.
- **New tests:**
  - `packages/jet_cad_2d/test/codec/schema_9_test.dart`: S9-1 to S9-3.
  - `packages/jet_cad_floor_plan/test/host/controller_test.dart:958-1047`: the group `schema 9 (E-9)`, CS1 to CS4, additions only.

  Both match the report's description.
- The commit touches no `analysis_options.yaml` (`git show --stat` has no match),
  and its trailer is correct.

## 2. Gates (rerun by me, real tails)

| Package | Test | Comparison / analyze / format |
|---|---|---|
| `jet_cad_2d` | `dart test --file-reporter json:…`: 1256 pass, 2 fail. The 2 are the standing fingerprint pair, "the default document is the one Plan 2 measured, byte for byte" and "both text fractions default to zero and change nothing" (from the JSON) | `expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d`: `packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly`, exit 0. `dart analyze --fatal-infos`: `No issues found!`. Format: `Formatted 170 files (0 changed)`, exit 0 |
| `jet_cad_2d_flutter` | `flutter test --file-reporter json:…`: 1366 pass, 7 errors, 1 skip (from the JSON) | `packages/jet_cad_2d_flutter: 1374 tests; the standing failures and skips, exactly`, exit 0 |
| `jet_cad_2d_gpu` | `00:02 +20: All tests passed!` | `packages/jet_cad_2d_gpu: 20 tests; the standing failures and skips, exactly`, exit 0 |
| `jet_cad_floor_plan` | `08:07 +1518: All tests passed!` | `No issues found! (ran in 11.9s)`. Format: `Formatted 250 files (0 changed)`, exit 0 |
| `jet_cad_restaurant_symbols` | `00:04 +97: All tests passed!` | `No issues found! (ran in 6.0s)`. Format: `Formatted 15 files (0 changed)`, exit 0 |
| `apps/restaurant_demo` | `00:46 +47: All tests passed!` | `No issues found! (ran in 6.5s)`. Format: `Formatted 5 files (0 changed)`, exit 0 |
| `apps/floor_planner` | `02:54 +212: All tests passed!` | `No issues found! (ran in 6.5s)`. Format: `Formatted 47 files (0 changed)`, exit 0 |

The counts agree with the report's (engine 1256/−2, render 1366/~1/−7, gpu 20,
planner 1518, symbols 97, demo 47, floor planner 212).

## 3. Mutants

Each mutant was applied in `/home/user/review-s2t1-mut`. I reverted each one with
`git show HEAD:<f> > <f>` and checked it with `git diff --quiet` ("reverted clean"
after every one).

- Engine runs are the whole `dart test`. The 2 standing fingerprint failures appear in every run and are not counted as kills.
- Planner runs are `flutter test test/host/controller_test.dart` unless noted.

### The named mutants

| Mutant | Engine | Planner and others | Result |
|---|---|---|---|
| **M-H26a**: `kSchemaVersion = 8` | `dart test test/codec test/document/layer_header_test.dart`: red. The failing tests:<br>- S9-1, S9-2, S9-3<br>- "the schema version is 9, …"<br>- QF3<br>- "the schema this build writes is 9"<br>- Q0-C1<br>- "this build writes schema 9, reads 7, …" | - Planner: CS1, CS2 and CS3 red.<br>- Furniture byte pin "the asset the committed bytes equal the built library": `00:00 +0 -1`.<br>- The restaurant symbols suite is red: `+0 -79`, `SymbolLibraryError: … unsupported schemaVersion 9 (this build writes 8)`.<br>- Demo `sample_plans_test`: `00:00 +0 -2` | **red** |
| **M-H26b**: the guard becomes `if (version != kSchemaVersion)` | Red:<br>- S9-2<br>- Q0-C3 (literal 7)<br>- layer_header "reads 7" and "a v6 document …"<br>- both v5/v6 tests in `instance_style_codec_test`<br>- both `schema_v3_fixture_test` tests | CS2 red (`+38 -1`) | **red** |

### My mutants

All but X6 and X10 are version-gated. Each adds `static int _v` to `DraftDocumentCodec`, set to `version` right after the guard, and acts only when `_v < 9`, so it simulates a v8→v9 "migration" that is not empty.

| # | Mutant (`json_codec.dart` unless noted) | Engine | Planner | Result |
|---|---|---|---|---|
| X1 | At v<9, `currentLayer` reset to the first layer | S9-2 red; layer_header "reads 7" red | `+39` all pass | **red** (engine) |
| X2 | At v<9, every component except `jetcad.page` dropped | **all pass** | CS2 red | **red** (planner only) |
| X3a | At v<9, each layer's `visible`/`locked` reset to `true`/`false` | **all pass** | CS2 red | **red** (planner only) |
| X3b | At v<9, each layer's `transparency` reset to 0 | **all pass** | **all pass** (`+39`) | **SURVIVED** |
| X3c | At v<9, each layer's `lineweight` set to −3 | S9-2 red | all pass | **red** (engine) |
| X4a | At v<9, `header.globalLinetypeScale = 1.0` | **all pass** | **all pass** | **SURVIVED** |
| X4b | At v<9, `header.customVariables.clear()` | **all pass** | **all pass** | **SURVIVED** |
| X5 | At v<9, `rawData` not loaded | **all pass** | **all pass** | **SURVIVED** |
| X6 | The guard becomes `version > kSchemaVersion + 1` (a 10 accepted) | Red:<br>- S9-3<br>- "refuses a schema version from the future"<br>- "the schema version is 9, …"<br>- the v6 "refuses … everything from the future" test<br>- layer_header "refuses the next one" | CS3 red | **red** |
| X7 | `floor_plan_controller.dart` `load`: `if (e is SchemaVersionError) return;` (swallows the version) | — | CS3 red; C8 red | **red** |
| X8 | `load`: `newPlan()` before the rethrow (the plan is replaced on refusal) | — | CS3 red; C8 red | **red** |
| X9 | The constructor's refusal message loses `$e` (`'Not a floor plan'`) | — | CS3 red (its constructor half) | **red** |
| X10 | `service_layout.dart`: the layout gains `'schemaVersion': kSchemaVersion` | — | `controller_test` + `service_layout_test`: only CS4 red (`+49 -1`) | **red** (CS4 is the sole killer) |

**Survivors: X3b, X4a, X4b, X5** (R-1). X2 and X3a are killed only by the
planner's CS2, not by the engine's own S9-2.

The brief's questions:
- **Would a `load` that swallows the version message survive CS3?** No: X7 and X9 are red.
- **Is the 10-refusal tested with the plan unchanged?** Yes. CS3 checks `designJson()` byte-equal (`controller_test.dart:1022`), `activeDocument` `same`, `tableDetails` and `canUndo`. X8 is red.
- **Does the "8 loads unchanged" test compare the drawing, not just counts?** Yes. Both S9-2 (`schema_9_test.dart:104`) and CS2 (`controller_test.dart:996, 1001-1002`) compare the re-encoding byte for byte with this build's 9 bytes. The weakness is not the comparison but what the fixtures hold (R-1).

## 4. The history comment (`schema_version.dart:39-47`)

The comment is accurate against E-9 and the code:

- **"No new field and nothing to default; the v8->v9 migration is empty."** True. The diff touches no codec or model code, and the codec has no migration function (`json_codec.dart:105-108` is the whole version gate).
- **"Not for the reader's drawing, as 6's to 8's did."** True. It matches E-9's wording and the 6–8 entries above it.
- **"A v8 build would keep that payload as preserve-unknown data."**
  - True: `ComponentRegistry.loadJson` (`component.dart:270-287`) keeps any type with no factory via `attachUnknown`.
  - Nothing in `jet_cad_floor_plan/lib` registers or detaches a `jetcad.table_data` type at this commit. `grep` for `SetComponentCommand<…>(… null` or component detaching finds nothing.
- **"Deleting the table would leave its data orphaned in the file."** True, and I checked it empirically:
  - The planner's Delete is `RemoveNodeCommand` (`jet_cad_2d_flutter/lib/src/select_tool.dart:713`).
  - `RemoveNodeCommand.apply` only removes the node (`commands.dart:421-431`).
  - `ComponentRegistry.toJson` writes every unknown payload, whether or not its handle is live (`component.dart:243-257`).
  - A throw-away probe test confirmed it (written in the mutant clone, run, deleted):
    - decode a document carrying `jetcad.table_data` on instance 70;
    - run `RemoveNodeCommand(70)`;
    - encode.

    The output still carried `{"70":{"data":{"id":"x"}}}` under `jetcad.table_data`, and `tree[70]` was null (`00:00 +1: All tests passed!`).
- **"(or v7) is read unchanged."** This is E-9's own wording ("a schema-8 (and 7) plan opens unchanged"). The v7 reads stay covered by Q0-C3 and layer_header's literal-7 read, both red under M-H26b.

## 5. Plan requirements for Task 1

All present:

- the constant and its history entry;
- the forced re-pins, and nothing else;
- the four re-encodings by their generators;
- the M-H26a killers: the engine pins, the four byte pins and CS1;
- the M-H26b killers: an 8 document derived from this build's encoding, through the engine and through `load`, saving to the original 9 bytes, plus the literal-7 reads;
- a 10 refused by the engine (`found` 10) and by `load` (the message names 10 and 9), with the plan left as it was;
- the service layout format untouched (CS4);
- the S-1 comment in the fingerprint tests, with the standing set unchanged;
- every gate in the plan's list.

Nothing is missing.

## Findings

### R-1 (Minor): the "8 loads unchanged" fixtures hold defaults that a v8 read could drop unseen

- **Evidence:** mutants X3b, X4a, X4b and X5 (above) survive both the engine (`dart test`) and the planner (`controller_test.dart`).
  - X3b resets layer `transparency` at v<9.
  - X4a resets `header.globalLinetypeScale` at v<9.
  - X4b clears `header.customVariables` at v<9.
  - X5 skips `rawData` at v<9.
- **Cause:** S9-2's byte comparison is strong, but `fixture()` (`schema_9_test.dart:17-38`) leaves these fields at their defaults, so dropping them changes no byte:
  - `generateDocument`'s layers all have `transparency: 0` (`generate_document.dart:170-179`);
  - the header's scale, linetype scale, custom variables and imported extents are untouched;
  - there is no raw data;
  - there is no component except the page.

  The planner's embedding fixture is no better on these fields.
- **The engine test leans on the planner's:** X2 (every non-page component dropped at v<9) and X3a (layer `visible`/`locked` reset) are killed only by CS2. E-9's subject is a component unknown to an older build, so the engine's own "8 loads unchanged" test should hold one.
- **Fix:** in `schema_9_test.dart`'s `fixture()`, make the 8 document carry every stored field away from its default:
  - the header: `doc.header.globalLinetypeScale = 2.5`, a non-unit `scale`, a `customVariables` entry or two (keys out of order), and `importedExtents` if settable;
  - a layer added with `transparency` ≠ 0, `visible: false` and `locked: true` (or `copyWith` on `layer_1`);
  - a `rawData.set(…)` entry;
  - a `labelFraction`/`attributedInstanceFraction` > 0, so text, tags and attributes are present;
  - in `withVersion` or the fixture's JSON, an unknown component (for example `jetcad.table_data` on an instance handle) and an unknown top-level key, both of which S9-2's byte comparison must then carry through.

  Then re-run X2, X3a, X3b, X4a, X4b and X5 against S9-2 alone, and record them red in the report.

### R-2 (Nit): S9-1's name promises more than it checks

- **Evidence:** `schema_9_test.dart:49-57`. The name says "first, in every encoding", but `keys.first` is checked only for the fixture's encoding. The empty document's check is the value only (`:56`).
- **Fix:** add `expect(DraftDocumentCodec.encode(DraftDocument.empty()).keys.first, 'schemaVersion')`, or narrow the name.

### R-3 (Nit, report accuracy): two report details are slightly off

- **Evidence:** the report says the history entry is at "lines 38-47". It starts at `:39`; `:38` is the `///` separator. The report's S9-1 wording repeats R-2's over-claim ("as the first key, in every encoding").
- **Fix:** none needed in code; correct the report if it is revised for R-1.

## Mutant record

| Mutant | Result |
|---|---|
| M-H26a | red |
| M-H26b | red |
| X1 | red |
| X2 | red (planner CS2 only) |
| X3a | red (planner CS2 only) |
| **X3b** | **survived** |
| X3c | red |
| **X4a** | **survived** |
| **X4b** | **survived** |
| **X5** | **survived** |
| X6 | red |
| X7 | red |
| X8 | red |
| X9 | red |
| X10 | red |
