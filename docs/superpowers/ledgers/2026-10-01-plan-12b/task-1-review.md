# Task 1 review — the header, the target, schema 7

Reviewer: independent agent. Detached worktree
`.claude/worktrees/plan-12b-review` at `a6cd4bb` (base `9ee2e60`). Scratch:
`.../scratchpad/r1/`. Tree left clean (`git status --short` empty; the
`packages/jet_cad/analysis_options.yaml` rewrite by `flutter pub get` was
restored, nothing staged or committed).

## Verdict: **Approved with notes**

No defects found. The two notes are bookkeeping for the controller, not
fixes to this commit.

## 1. The diff against spec D3, D4, F8 and plan Task 1

Read `git diff 9ee2e60 a6cd4bb` whole (16 files).

- **Header / codec (D3, F8).** `currentLayer` defaults to
  `ReservedHandles.layerZero`; `toJson` writes it immediately after
  `globalLinetypeScale` (fixed literal-map order, so the output is
  deterministic); `fromJson` reads it only when the key is present, else
  layer 0; `_loadHeader` copies it. `fromJson`/`_loadHeader` are symmetric:
  every field `fromJson` sets is copied (`units`, `scale`,
  `globalLinetypeScale`, `currentLayer`, `importedExtents`,
  `customVariables`).
- **Schema 7.** `kSchemaVersion = 7` with the v6->v7 paragraph naming both
  the header key and `jet_cad.object_layer`, in the file's pattern. The reader
  guard (`version > kSchemaVersion`) is unchanged.
- **CommandTarget.header.** Added; `DraftDocument` gains `@override`; both
  fakes implement it. No other implementer in the workspace (grep).
- **`LayerRecord.copyWith`.** All eight fields, `??` on each, no
  cross-wiring.
- **`layerNameError`.** Empty; `name != name.trim()`; `name.length > 255`
  (UTF-16 units); each of the 12 characters of the spec's set, exactly
  (`<>/\":;?*|=` and the backtick); duplicate via `byName`, which folds with
  `toLowerCase()` like `TableSection.add`; `self` excluded by handle, so a
  case-only rename and a no-op rename are valid while renaming B to `a` is
  still a duplicate. Matches D4.
- **`drawingLayer`.** Stored layer when the record exists and is visible,
  else layer 0; locked is allowed (decision 7). Matches D3/R-10.
- **P-7 test moves.** `json_codec_test` (both pins of 6 -> 7; the refused
  version is `kSchemaVersion + 1`), `instance_style_codec_test` (`:80` pin;
  `:191` to `kSchemaVersion + 1`; `v5Document()` also strips
  `header.currentLayer`, which keeps that helper's "what a v5 writer wrote"
  contract — correct), `header_test` key-order pin. Each carries a one-line
  comment.

## 2. Gates (re-run by me, `CI=true`, after `flutter pub get`)

| package | result (real tail line) |
|---|---|
| engine `dart test` | `00:17 +1138 -2: Some tests failed.` — the two: `the default document is the one Plan 2 measured, byte for byte [E]`, `both text fractions default to zero and change nothing [E]` (both `test/testing/generate_document_test.dart`; `Expected: <1593811103237081036> Actual: <-565808937189420354>`) |
| engine analyze / format | `No issues found!` / `Formatted 162 files (0 changed)`, exit 0 |
| render `flutter test` | `01:05 +1154 ~1 -7: Some tests failed.` — text ladder rungs 1-5 and text lod ladder rungs 1-2 (canvas), the standing seven |
| render analyze / format | `No issues found! (ran in 3.7s)` / `Formatted 200 files (0 changed)`, exit 0 |
| app `flutter test` | `03:24 +934: All tests passed!` |
| app analyze / format | `No issues found! (ran in 4.3s)` / `Formatted 165 files (0 changed)`, exit 0 |
| dev_harness_2d analyze | `No issues found! (ran in 2.0s)` |

All as expected (engine 1138 + 2 standing, render 1154 + 1 skip + 7
standing, app 934).

## 3. Mutants (re-fired; file `test/document/layer_header_test.dart`; cp backup, mutate, run in the foreground, cp back, diff 0 each; script `scratchpad/r1/mut.sh`)

| id | site | mutation | result |
|---|---|---|---|
| M-LP-12 | `json_codec.dart` `_loadHeader` | drop `..currentLayer = header.currentLayer` | RED `+13 -4`: `a non-zero current layer round-trips: save, load and save is byte-identical [E]` (+ schema, dangling, hidden) |
| M-LP-13 | `schema_version.dart` | `kSchemaVersion = 6` | RED `+16 -1`: `this build writes schema 7, reads 7, and refuses the next one [E]` |
| M-LP-21 | `drawingLayer` | `return stored;` | RED `+14 -3`: dangling, hidden (S-5), `falls back to layer 0 when the stored layer is removed [E]` |
| R-T1a | `layerNameError` | delete the empty check | RED: `refuses the empty name [E]` |
| R-T1b | `layerNameError` | `trim()` -> `trimLeft()` | RED: `refuses an untrimmed name, either end [E]` |
| R-T1c2 | `layerNameError` | `>` -> `>=` | RED: `allows 255 UTF-16 units and refuses 256 [E]` |
| R-T1f | `layerNameError` | `existing != null` only (no self exclusion) | RED: `excludes self: a case-only rename, or no change, is valid [E]` |
| O1 (mine) | `drawingLayer` | drop `&& record.visible` | RED: `a hidden stored current layer ... (S-5) [E]` |
| O2 (mine) | `DocumentHeader.fromJson` | key test on `'currentLayerX'` (key ignored) | RED `+13 -4`: round trip, schema, dangling, hidden |
| O3 (mine) | `copyWith` | `locked: locked ?? this.visible` | RED: `replaces exactly the named field and keeps every other [E]` |
| O4 (mine) | forbidden set | prepend `-` | RED: `accepts a fresh, well-formed name [E]` |
| O5 (mine) | length | `name.runes.length >` | RED: `allows 255 UTF-16 units and refuses 256 [E]` (the surrogate-pair case) |
| O6 (mine) | duplicate | `existing.handle != self` -> `existing.name != name` | RED `+15 -2`: `refuses another layer's name under toLowerCase() [E]`, `excludes self ... [E]` |
| O7 (mine) | `drawingLayer` | also require `!record.locked` | RED: `drawingLayer is the stored layer when it is visible, locked or not [E]` |
| O8 (mine) | header field default | `const Handle(2)` | RED: `defaults to layer 0 on a new document [E]` |
| O9 (mine) | `fromJson` absent default | `const Handle(2)` | RED: `a v6 document (no currentLayer key) loads with layer 0 current [E]` |
| O10 (mine) | `toJson` key order | `currentLayer` after `importedExtents` | RED: `the key follows globalLinetypeScale in the header [E]` |

17 fired, 17 red, 0 equivalent.

## 5. Degeneracy

Every one of the 17 new tests is turned red by a named mutant (mine above
plus the implementer's T1d/T1e for the forbidden-character and duplicate
tests). The fixture follows P-6: A ACI 1, B ACI 5 locked, C ACI 3 hidden,
no ACI 7, the hidden layer is not layer 0; the round trip uses a non-zero
current layer, the v6 test writes with A current before stripping the key
(so the default is the loader's, not the source's), the schema test uses B
(neither layer 0 nor the first added), the dangling handle sits above the
seed. Not degenerate.

## 4. Rulings on the implementer's points

**(a) Fingerprints left at macOS values (R-12b-1): accepted.** Verified: the
two standing Linux failures are exactly the two fingerprint tests P-7 names,
and their constants are macOS values (Ruling 07-7, walls plan `:90`).
Re-baselining to the Linux value would turn them green here and red on
macOS and change the standing count P-7 fixes at 2. The comments name the
header key and the version. Cost, now real: the human's macOS engine gate
fails these two until re-baselined. See Note 1.

**(b) `furniture.jetlib`: accepted, verified.** By script: the old bytes
with `"schemaVersion":6` -> `7` and `"globalLinetypeScale":1.0,` ->
`"globalLinetypeScale":1.0,"currentLayer":1,` (each occurring once) equal
the new bytes exactly (`True 44212 44229`). Regenerating the committed codec
output is the only way to keep `furniture_library_test` green; the plan
missed it.

**(c) Dangling stored `currentLayer` does not raise the handle seed: real,
narrow, not for Task 2.** On load the seed is raised to the declared
`handleSeed` and to every *owned* handle (`_loadTables`, `_loadTree`,
`_loadEntities`); no *reference* raises it — not `EntityRecord.layer`,
`InstanceNode.layer`, `LayerRecord.linetype`, nor now `currentLayer`. So
the gap exists only for a stored reference above the declared seed, which
this writer cannot produce: `currentLayer` only ever names a layer that was
issued (≤ seed), and handles are never reissued, so a layer removed later
stays dangling forever. Only a hand-edited or foreign file can carry it, and
the same file could equally carry an entity on such a handle, which a new
layer would adopt the same way. Raising the seed for one reference kind
would be inconsistent with the others and would rewrite `handleSeed` on the
first re-save of such a file. Ruling: leave it; Task 2's
`header.current_layer_unusable` warning is the spec's answer (diagnosed,
never repaired). If wanted, "references raise the seed on load" is one
cross-cutting fix for all reference kinds, a later `fix/` branch, not this
plan. See Note 2.

## Notes (no fix required in this commit)

1. **(Minor, bookkeeping)** The macOS fingerprint re-baseline is owed. The
   controller should carry it in progress.md (done as R-12b-1) **and** in
   Task 11's results note look-list / STATUS "owed" items with the exact
   step: on macOS, run `dart test test/testing/generate_document_test.dart`
   in `packages/jet_cad_2d` and replace the four constants at `:66, :68` and
   `:251, :253` with the reported actuals (both tests share them).
2. **(Info)** R-12b-3 ruled above: a known limitation, recorded in the
   results note; no Task 2 work.
