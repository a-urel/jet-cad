# Kit contract (sub-project 1): results of record

Branch `feat/kit-architecture`, head at the exit gate: `b069a3f99fec1c512aa2df49bd455740b1560b81`
(the commit that adds this note sits on top of it). Plan: `docs/superpowers/plans/2026-10-13-kit-contract.md`.
All transcripts below were copied from the terminal on 2026-10-13, last lines only.

## Gates

### 1. Package gate, `packages/jet_cad_2d_kit`

`flutter test` printed 225 tests (`+225`):

```
00:01 +225: All tests passed!
```

`flutter analyze`:

```
Analyzing jet_cad_2d_kit...
No issues found! (ran in 2.3s)
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 47 files (0 changed) in 0.06 seconds.
```

### 2. Tools gate

`cd tool/ci && dart test`:

```
00:06 +106: All tests passed!
```

`dart run tool/ci/check_kit_deps.dart` (repository root):

```
kit dependencies: 1 package(s) checked, none names the plan library or another kit
```

### 3. The three CLAUDE.md gates

`packages/jet_cad_2d` (`dart test`): fails exactly the two known, environmental tests
(the same two fail on the clean main checkout, ledger ruling after Task 1):

```
00:06 +1289 -2: Some tests failed.

Failing tests:
  test/testing/generate_document_test.dart: both text fractions default to zero and change nothing
  test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte
```

`dart analyze`: `No issues found!`. `dart format --output=none --set-exit-if-changed .`:
`Formatted 177 files (0 changed) in 0.40 seconds.`

`packages/jet_cad_2d_flutter` (`flutter test`): fails exactly the known text-ladder goldens (rungs 1-5, `RenderBackend.canvas`):

```
00:22 +1450 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

`flutter analyze`: `No issues found! (ran in 2.9s)`. Format: `Formatted 234 files (0 changed) in 0.47 seconds.`

`packages/jet_cad_2d_gpu`:

```
00:00 +20: All tests passed!
No issues found! (ran in 2.6s)
Formatted 10 files (0 changed) in 0.01 seconds.
```

The two hash tests fail identically on the clean main checkout (ledger ruling after Task 1);
the text-ladder goldens were reported pre-existing. CI is the arbiter.
No file of either package is touched by this branch (see the hand checks).

Task 1's report also records one full `jet_cad_2d` run in which `query_allocation_test` failed;
it passed alone (reported as flaky). The exit-gate run above does not show it.

### 4. Publish dry run, `packages/jet_cad_2d_kit`

`dart pub publish --dry-run`: exit 0.

```
Total compressed archive size: 52 KB.
Validating package...
The server may enforce additional checks.

Package has 0 warnings.
```

The file list holds `CHANGELOG.md`, `LICENSE`, `README.md`, `analysis_options.yaml`,
`example/example.dart` (and the three further example files of the Task 10 fix round),
`lib/authoring.dart`, `lib/jet_cad_2d_kit.dart`, `lib/src/...`, `pubspec.yaml`, `test/...`.
`cmp LICENSE packages/jet_cad_2d_kit/LICENSE` printed nothing.

### 5. Hand checks

- `git status --short`: empty before and after every gate (also after the sample-kit regeneration).
- `git log --name-only main..HEAD | grep analysis_options`: only `packages/jet_cad_2d_kit/analysis_options.yaml`.
- `git diff --stat main...HEAD -- packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols packages/jet_cad_2d packages/jet_cad_2d_flutter packages/jet_cad_2d_gpu apps`: prints nothing.
- `grep -rn "dart:io" packages/jet_cad_2d_kit/lib`: matches only the comment line `// Pure Dart: no Flutter, no dart:io.` in 15 files; `grep -rn "import 'dart:io'" packages/jet_cad_2d_kit/lib` prints nothing. No import of `dart:io`.
- `grep -rln "package:flutter\|dart:ui"` over `lib/src/model`, `lib/src/authoring`, `lib/authoring.dart`: prints nothing.
- `grep -rn "jet_cad_2d_plan\|jet_cad_2d_kit_"` over the pubspec and `lib`: one line, the doc comment in `lib/src/kit/bundled_library.dart:4` (`packages/jet_cad_2d_kit_restaurant/assets/restaurant.jetlib`).
- `dart run test/fixtures/sample_kit/generate.dart` printed `sample kit: 4 symbols written`; `git diff --quiet -- test/fixtures/sample_kit/sample.jetlib test/fixtures/sample_kit/sample_snapshot.json` exited 0.

## Mutations of Tasks 1-11

As the task reports record (`.superpowers/sdd/2026-10-13-kit-contract/task-N-report.md`), each
ran on a committed file and was reverted with `git checkout --`. One exception, from the ledger:
Task 9's session ended with a mutation (the `libraryKitMismatch` check deleted) still applied to
the committed `conformance.dart`; the controller reverted it with `git checkout`, and the
implementer resumed. "Red" is the test or tests the report names.

| ID | File | Change | Red |
|---|---|---|---|
| M-P1 | test probe | probe importing `flutter/foundation` | P1 |
| M-P2 | test/support/import_walker.dart | relative imports not followed | P2, P4 |
| M-P5 | import_walker.dart | first URI only | P5 |
| M-P3 | purity_test.dart | `io` allowed | P3 |
| M-I1 | kit_ids.dart | kit id pattern `[a-z0-9][a-z0-9]*` | I1 (I3) |
| M-I2 | kit_ids.dart | kind pattern `^[a-z0-9-]+$` | I2 |
| M-I3a | kit_ids.dart | key segments `{1,}` | I3 |
| M-I3b | kit_ids.dart | kit-id check dropped | I3 |
| M-C1 | symbol_component.dart | `attachTo` `listEquals` dropped | C1 (C2) |
| M-C5 | symbol_component.dart | repeated-tag check dropped | C5 |
| M-C6 | symbol_component.dart | tag pattern `^[a-z ]+$` | C6 (C5) |
| M-C7 | symbol_component.dart | `key`/`family` swapped in `toJson` | C7 |
| M-C9 | symbol_component.dart | `family` read as `String?` | C9 (C10) |
| M-C10 | symbol_component.dart | `version` read with `!` | C10 (C9) |
| M-U3 | unit_component.dart | labelling dropped from `==` | U3 |
| M-U5 | unit_component.dart | kind read `byName` | U5 |
| M-L1, M-L3 | library_component.dart | the report names the change by ID only | L1, L3 |
| M-MF2, M-MF3 | manifest_component.dart | MF2; `containsKey` only for MF3 | MF2 (MF3, R4); MF3 |
| M-R1, M-R2 | register.dart | `registerBuiltIns`; UnitComponent registration omitted | R1; R1-R4 |
| M-V0a | symbol_library.dart | `drafts` sorted by key | V0a |
| M-V0a2 | symbol_library.dart | `unit: null` | V0a |
| M-V0b | symbol_library.dart | leaves `..sort` dropped | V0b |
| M-V1b | symbol_library.dart | diagnostics check deleted | V1b |
| M-V1g | symbol_library.dart | `on FormatException catch (e)` | V1g |
| M-V2b | symbol_library.dart | `library.format < 1` | V2b |
| M-V4d | symbol_library.dart | `leaves.isEmpty` check deleted | V4d |
| M-V5a | symbol_library.dart | kit check deleted | V5a |
| M-V5b | symbol_library.dart | `'key' => 5` arm deleted | V5b-V5e |
| M-V7 | symbol_library.dart | name check deleted | V7a, V7b |
| M-V8 | symbol_library.dart | tags/attachTo/family arm deleted | V8a-V8f |
| M-V9 | symbol_library.dart | unit-and-family check deleted | V9a |
| M-V10 | symbol_library.dart | unit loop deleted | V10a, V10b |
| M-V11a | symbol_library.dart | `if (!closed)` -> `if (false)` | V11a, V11b |
| M-V11 | symbol_library.dart | `false \|\|` for the circle test | V0g |
| M-V13c | symbol_library.dart | `point` moved to the accepted cases | V13c |
| M-V14 (linetype) | symbol_library.dart | linetype check deleted | V14b-V14d |
| M-V14 (text) | symbol_library.dart | text check deleted | V14p |
| M-V15 | symbol_library.dart | `p.scalars[2] == 0` | V15p-V15r |
| M-M1 | symbol_library.dart | merge order | M1 |
| M-M2 | symbol_library.dart | merge duplicate naming | M2 |
| M-W2a, M-W2b, M-W3, M-W5a, M-W5b | kit_names.dart | locale/English/stored-name fallbacks, category lookup, merge | W2 (W4), W2, W1 + W3, W5, W5 |
| M-KP1 | kit_problem.dart | value equality | KP1 |
| M-S2 | bundled_library.dart | `asUint8List()` | S2 |
| M-S3 | bundled_library.dart | eager load | S3 |
| M-S4 | bundled_library.dart | `bundle!` | S4 |
| M-K3a, M-K3b | plan_kit.dart | id check removed; `version.isEmpty` | K3 |
| M-K4, M-K4b | plan_kit.dart | `case 'symbol':` only; category case `break` | K2 + K4; K4 |
| M-K6 | plan_kit.dart | English check dropped (the `if`, the brief's `else if` does not exist) | K6 |
| M-B1 | builder.dart | per-call handle start offset | B1 |
| M-B2 | builder.dart | all definitions allocated first | B2 |
| M-B3a, b, c | builder.dart | attachTo dropped; labelling dropped; arc start/sweep swapped | B3 |
| M-B5 | builder.dart | `SymbolLibrary.decode(bytes)` deleted | B5 |
| M-P1 (builder) | builder.dart | import `flutter/foundation.dart` | P1 |
| M-H2 | shapes.dart | rect swaps w/h | H2 (H7) |
| M-H3a, M-H3b | shapes.dart | `_chairBack` 70; back on the table side | H3 (H4) |
| M-H4a, b, c | shapes.dart | `_around` without -pi/2; r + 225 + 100; facing a not a+pi | H4 (H6) |
| M-H5 | shapes.dart | circles swapped | H5 |
| M-H6 | shapes.dart | `+ stoolTuck` | H6 |
| M-H7a, b, c | shapes.dart | `_p` uncleaned; `return r`; rect without `_p` | H7 (H8) |
| M-N7 | snapshot.dart | `SplayTreeMap.of({...committed, ...current})` | N7 |
| M-N1a | snapshot.dart | `'closed'` dropped | N1 |
| M-N2 | snapshot.dart | `_number` returns `v` | N2 |
| M-F1 | conformance.dart | `listEquals` comparison deleted | F1, F2, F3 |
| M-F3 | conformance.dart | kit comparison deleted | F3 |
| M-F4 | conformance.dart | `kitOfKey` check deleted | F4 |
| M-F5 | conformance.dart | `else if (false)` | F5, F6 |
| M-F8 | conformance.dart | `now == null` branch emptied | F8 |
| M-F11 | conformance.dart | `names.word(locale, id)` | F11 |
| M-F12a, M-F12b | conformance.dart | `word == en` branch deleted; allowed set empty | F12 (F19); F0 + F12 |
| M-F13 | conformance.dart | orphan check over `locales` | F13 |
| M-F15 | conformance.dart | `lower(s, 'family', family)` deleted | F15 (shadowed by K2) |
| M-F19 | conformance.dart | first version wins | F19 |
| M-F19b | conformance.dart | `if (true)`, last version wins | F19, case `v2 first` |
| M-E1 | example/example.dart | `chairsAround ... 2` -> 3 | E1 |
| M-D1a, M-D1b | tool/ci/lib/kit_deps.dart | `startsWith('jet_cad_2d_')`; drop `&& dep != name` | D1 |
| M-D3 | kit_deps.dart | sections = `['dependencies']` | D3, D4 |
| M-D5 | kit_deps.dart | `firstMatch` per directive | D5 |
| M-D6 | kit_deps.dart | scan whole text | D6, D8 |
| M-D10 | kit_deps.dart | `'build'` added to script subdirectories | D10 |

The Task 3 report quotes `[E]` markers rather than the red lines; the ledger records that as a
process minor.

## Plan decisions

- A symbol key must also carry a kit id as first segment, not only match K2's regex.
- A tag must not have outer white space.
- `family` is always written (null when absent); every field is required by `fromJson`; an unknown field is ignored.
- `LibraryComponent`/`ManifestComponent` accept any format >= 1; the validator refuses a library format other than 1.
- A manifest's versions are only required non-empty; `kits` is stored sorted by kit id.
- `registerKitComponents` is one line over `registerKitComponentsWrapped`, so decoder and registry cannot drift.
- `SymbolLibraryError` carries the K3 rule number.
- `decode` registers the kit components through guarded factories mapping a constructor refusal to its K3 rule (key -> 5; tags/attachTo/family/unit kind -> 8; `jetcad.library` -> 2; else 1); `ArgumentError` and `FormatException` mapped, anything else rule 1.
- A unit kind off K2's pattern is refused under rule 8; external-reference definitions, definitions with no leaf and a `SymbolComponent` on a non-definition handle under rule 4.
- Rule 14 lists layer 0, by-block linetype/colour/lineweight/transparency, linetype scale 1, flags 0, plus the text defaults.
- `SymbolLibrary.kits` is a list (merged libraries); merge's rule-6 refusal names libraries by position and kit.
- `KitNames.merge` keeps the earlier kit's word on a shared id; `categoryName(locale, kit, category)` takes the kit id.
- A locale is a language code; no region fallback.
- `KitProblem`/`KitProblemCode` live in the model, shared by `PlanKit.validate` and `conformance`; tests assert codes.
- `bundledLibrary` resolves the bundle when the reader runs.
- `PlanKit.validate` also reports `unknownWordId` and `missingEnglish`.
- Catalog points are records `(double, double)`; `encodeLibrary` decodes its own output; `buildLibraryDocument` does not validate.
- Every shape helper cleans every coordinate; `cleanCoordinate` is public; `inset` takes the outline's corner.
- The snapshot is one `"key@N": {entry}` per line, keys sorted, canonical numbers; `parseSnapshot` compares canonical texts.
- `locales` lists non-English locales and `'en'` is an `ArgumentError`; undeclared locales with words are `localeUndeclared`; `sameAsEnglish` is per locale; a catalog key missing from the snapshot is `snapshotMissing`; a locale word is compared with the newest version's English; checks 3 and 6 end the check on a finding, and an unbuildable catalog is one `catalogInvalid`.
- The code shown in `docs/kits.md` and the README is analysed example code (`example/`), and a test runs it through encode, decode and conformance.
- `check_kit_deps.dart` picks packages by directory name, reads all three dependency sections and every `import`/`export`/`part` URI under `lib/`, `test/`, `tool/`; `--packages <dir>` points it elsewhere; `jet_cad_2d_kit` joins the `publishable` CI matrix. (The final fix wave widens it: every Dart file, packages by pubspec name.)

## Rulings of the controller (ledger)

- Pre-flight F1-F13 (13 findings) taken as rulings; F1 later found wrong (`flutter/services.dart` provides `Uint8List`; the import was dropped in Task 6).
- The `jet_cad_2d` hash tests fail identically on the clean main checkout (`1b4670b`): environmental, CI is the arbiter. The `jet_cad_2d_flutter` text-ladder goldens were reported pre-existing.
- Implementers write the commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (the human's rule).
- Task 10: documentation snippets must be complete and analysed; they live in `example/` files that `flutter analyze` covers.
- Review rounds: Task 9 (F19 order-dependence, fixed in `5c29a55`), Task 10 (doc snippets, fixed in `3b19567`); every other task review clean.

## Deferred minors (from the ledger, unfixed)

- T1: import walker: a `package:` URI without `/` throws `RangeError`; its directive regex is not comment-aware (fails closed).
- T2: no blank-category test (dropping `.trim()` survives); `UnitComponent.fromJson` missing-field messages unasserted and no mistyped-kind/unknown-field case; no test proves `authoring.dart` re-exports the model; tags admit interior tabs/newlines.
- T3: reports quote `[E]` markers, not red lines.
- T4: rule 15 tolerance boundaries unpinned (`<= 0` for radius, exact equality for a zero-length line survive); `_guarded` `jetcad.library` `FormatException` -> rule 2 untested and V12a only makes x non-finite; V6a also breaks rule 7; many refusal tests name no mutation; `model.dart` export order not alphabetical.
- T5: merge's kits dedupe untested; `KitNames.words` and merge's inner maps mutable under `@immutable`.
- T6: `!rest.contains('.')` in `PlanKit`'s foreign-word check survives; `missingEnglish` reported once per non-English locale; a foreign tool word skips `missingEnglish`.
- T7: `buildLibraryDocument` leaks the document if a command throws after it exists; unawaited dispose in `finally`; B1 determinism only in-process.
- T8: rect/inset/poly/stoolAt now clean coordinates (intended); `chairsAround` cleans twice.
- T9: `parseSnapshot` doc claims canonical re-encoding (only whitespace); `_number` on arc start/sweep unpinned; `encodeSnapshot` `..sort()` unpinned; no end-to-end generated(moved) -> `snapshotChanged`; `catch (e)` around `encodeLibrary` also catches `Error`s.
- T10: docs/kits.md section 1 tree nests `jet_cad_2d_kit` under `jet_cad_2d_flutter` before sub-project 2 adds that dependency; section 5 "English required" sentence ambiguous; section 8 omits `ArgumentError` for `en` in `locales`.
- T11: `kit_deps` directive regex not comment-aware (fails safe); a pubspec name differing from its directory is skipped silently.

## Spec gaps found while planning (all taken into the specs in `1525dfe`)

1. K3 vs K2, rules 5 and 8: K2's constructors refuse a bad key, tag, target kind or family during decode, before any validator; Task 4 reads components through guarded factories that report them under rules 5 and 8.
2. K3, millimetres: no rule refused other units; Task 4 refuses them under rule 2.
3. K3 rule 14 vs today's allow-list: "by block" refuses the BYLAYER/CONTINUOUS values today's validator accepts (its L5); Task 4 follows K3 and inverts L5.
4. K3, "naming both kits": a `key@version` can only repeat between two libraries of one kit; Task 5 names the libraries by position as well.
5. K4: `category:<English category>` carried no kit id; amended to `category:<kit id>/<English category>`.
6. Umbrella A2 vs K5: names live on `PlanKit`, not on `SymbolLibrarySource`; a `bundledLibrary(...)` call makes the descriptor non-`const`; `docs/kits.md` shows a `final` descriptor.
7. K7 check 5: a locale's word is compared with the newest version's English.
8. K3 rule 9 ambiguity: amended to a unit definition whose `SymbolComponent` has a `family`.

## Final fix wave

After the final review (`.superpowers/sdd/2026-10-13-kit-contract/final-review.md`) and its
rulings (ledger, "Final review"). Commits on top of `fea46c3`:

- `f845bc7` test: rule 15's radius and line tolerance boundaries (FR2, deferred T4).
- `6dbf4c0` feat: rule 15 refuses a polyline whose points all lie within `Tolerance.standard.linear`
  of each other; rule 11 refuses a unit outline polyline enclosing at most linear² (FR8).
- `6a270b5` fix: `buildLibraryDocument` disposes its document when a payload throws after it
  exists (FR9, deferred T7). B8 pins the path (an empty closed `CatalogPolyline` throws its
  `StateError` through `buildLibraryDocument` and `encodeLibrary`); the disposal itself is not
  observable from outside, since the document never reaches the caller.
- `47af545` test: V2f (a `jetcad.library` `FormatException` is rule 2), V12b (a non-finite y),
  K4 `tool:sample`; `parseSnapshot`'s doc says it normalises white space only (deferred T4, T6, T9).
- `096d146` ci: `check_kit_deps` reads every Dart file of a package but `build/` and
  `.dart_tool/`, and picks packages by pubspec name (FR6, deferred T11). D13-D16.
- `d0a4349` test: every ```` ```dart ```` block of `docs/kits.md` (4) and the README (1) stands
  verbatim, as a run of whole lines, in one `example/*.dart` file (FR7).
- `4a2ce84` docs: `docs/kits.md` says the conformance test checks keys today, asks a kit to test
  `kit.validate()` is empty, no longer promises a retired symbol leaves the gallery, and follows
  FR6 and FR8 (FR4, FR5).
- `0dee1fb` docs: the spec's "Amendments from the final review" and "Inputs for sub-project 2"
  (R1-R6).

Mutations, as `final-fix-report.md` records each: on a committed file, reverted with
`git checkout --`, `git diff --quiet` exit 0.

| ID | File | Change | Red |
|---|---|---|---|
| M-V15t | symbol_library.dart | radius `<= 0` | V15t, V15u, V15v, V15w |
| M-V15u | symbol_library.dart | radius `< Tolerance.standard.linear` | V15v, V15w |
| M-V15y | symbol_library.dart | line `pointAt(0) == pointAt(1)` | V15y |
| M-V15aa | symbol_library.dart | polyline check `false &&`; points compared with `!=` | V15aa, V15ab; V15aa |
| M-V15ac | symbol_library.dart | each point compared with the first only | V15ac |
| M-V15ad | symbol_library.dart | the first two points only | V15ac, V15ad |
| M-V11c | symbol_library.dart | area check `false &&` | V11c, V11d |
| M-V11d | symbol_library.dart | `area == 0` | V11d |
| M-V11e | symbol_library.dart | `area <= linear` | V11e |
| M-V11f | symbol_library.dart | `.abs()` dropped | V11f |
| M-V2f | symbol_library.dart | every `FormatException` rule 1 | V2f |
| M-V12b | symbol_library.dart | `base.x` only | V12b |
| M-K4c | plan_kit.dart | `!rest.contains('.')` dropped | K4 (`tool:sample`) |
| M-D13 | tool/ci/lib/kit_deps.dart | `lib`/`test`/`tool` only | D13, D15 |
| M-D15 | tool/ci/check_kit_deps.dart | top-level `lib`/`test`/`tool` only | D15 |
| M-D16 | check_kit_deps.dart | packages by directory name | D16 |
| M-D10 | kit_deps.dart | `build` not excluded | D10, D13 |
| M-DOC1 | docs/kits.md; README.md | one character of a block | DOC1 (each document) |
| M-DOC1e | example/example.dart | one character of the catalog | DOC1 (both documents) |

Gates re-run after the fixes (last lines):

```
packages/jet_cad_2d_kit$ flutter test
00:01 +246: All tests passed!
packages/jet_cad_2d_kit$ flutter analyze
No issues found! (ran in 2.3s)
packages/jet_cad_2d_kit$ dart format --output=none --set-exit-if-changed .
Formatted 48 files (0 changed) in 0.07 seconds.
tool/ci$ dart test
00:06 +110: All tests passed!
$ dart run tool/ci/check_kit_deps.dart
kit dependencies: 1 package(s) checked, none names the plan library or another kit
packages/jet_cad_2d_kit$ dart pub publish --dry-run
Total compressed archive size: 56 KB.
Package has 0 warnings.
packages/jet_cad_2d_kit$ dart run test/fixtures/sample_kit/generate.dart
sample kit: 4 symbols written
```

`git diff --quiet` over the sample kit's two files exited 0, and `git status --short` was empty
after every gate. The three CLAUDE.md gates show only the failures recorded above:
`jet_cad_2d` `00:06 +1289 -2: Some tests failed.` (the two generate_document hash tests),
`No issues found!`, `Formatted 177 files (0 changed)`; `jet_cad_2d_flutter`
`00:23 +1450 ~1 -5: Some tests failed.` (text ladder rungs 1-5, `RenderBackend.canvas`),
`No issues found! (ran in 3.6s)`, `Formatted 234 files (0 changed)`; `jet_cad_2d_gpu`
`00:00 +20: All tests passed!`, `No issues found! (ran in 2.7s)`, `Formatted 10 files (0 changed)`.
