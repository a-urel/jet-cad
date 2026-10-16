# Task 9 report: the scaffold (kit package, integration package, CI, words, prepare)

Status: DONE. One commit: `8102f8a4 feat(kit-architecture): the scaffold of the kit and the integration package`.

## Implementation summary

- Root `pubspec.yaml`: two workspace members after `packages/jet_cad_2d_plan`.
- `packages/jet_cad_2d_kit_architecture` (0.1.0): pubspec, README stub, CHANGELOG, LICENSE (`cmp LICENSE ...` exit 0), `analysis_options.yaml` (a copy of the plan library's, `cmp` identical, committed once by explicit path per the controller's ruling).
  - `lib/src/ids.dart`, `lib/src/live.dart`, `lib/src/kit.dart`, `lib/jet_cad_2d_kit_architecture.dart` and `example/main.dart`: verbatim from the brief.
  - `lib/src/separator_linetype.dart`: the brief's header and adapted doc, with `separator.dart:122-133` and `:144-149` spliced in unchanged by script, so they are not retyped.
  - `lib/src/words/en.dart` and `words.dart`: verbatim. `de.dart` and `tr.dart`: generated in en.dart's id order from the brief's lists, with the headers the brief names.
- `packages/jet_cad_2d_integration` (0.0.0, `publish_to: none`): pubspec, README, `analysis_options.yaml` (copy, committed once), `lib/jet_cad_2d_integration.dart` (`architectureController`, `planEditorApp`), `test/support/editor_rig.dart`, `test/scaffold/smoke_test.dart`, `test/scaffold/prepare_test.dart`. All are verbatim from the brief.
- CI: two `package` matrix entries after `jet_cad_2d_plan`. The integration entry carries `test_flags: --enable-vmservice` and sits before `jet_cad_floor_plan`. The kit joins the `publishable` matrix. `tool/ci/test/scripts_test.dart` gains SC20c after SC20b.
- Test files were taken from the brief by script, not retyped, then `dart format .` (short style) reflowed 3 kit tests, `prepare_test.dart` and SC20c. That is whitespace only.

## Step 1 (preconditions)

- `git log --oneline -9`: Tasks 1-8 present (HEAD dbaf4bd4). `git status --short` was empty.
- `dart run tool/ci/check_kit_deps.dart` printed `kit dependencies: 1 package(s) checked, none names the plan library or another kit`.
- Names verified in code:
  - `PlanKit.prepare` (`plan_kit.dart:26, :51`).
  - `PlanWords.text` and `decimalSeparator` (`plan_words.dart:19, :24`).
  - `KitNamesWords(names, locale, {String Function()? decimalSeparator})` (`plan_services.dart:30-31`).
  - `PlanServices.liveTypeIdOf` (`plan_services.dart:150`).
  - `placeholdersOf` (`kit_text.dart:56`, exported through `model.dart`).
  - `KitProblemCode.placeholderMismatch`.
  - `lib/testing.dart` exports `FakePlanServices({required document, catalog, frozen, ...})`.
  - `conformance(...)`'s parameters, and `Catalog`, `encodeLibrary`, `geometrySnapshot`, `encodeSnapshot`.
  - Plan side: `missingKits`, `permissions`, `newPlan({decimalSeparator, build})`, `canUndo`, `dirty`, `ensureManifest`, `planSupportedLocales`, `planLocalizationsDelegates`.
  - No name differs.
- The analysis_options precondition was given by the controller.

## TDD evidence

RED, kit (`cd packages/jet_cad_2d_kit_architecture && flutter test`, before any lib/example file existed):

```
test/example_test.dart:4:8: Error: Error when reading 'lib/jet_cad_2d_kit_architecture.dart': No such file or directory
test/example_test.dart:8:8: Error: Error when reading 'example/main.dart': No such file or directory
test/scaffold/kit_test.dart:6:8: Error: Error when reading 'lib/jet_cad_2d_kit_architecture.dart': No such file or directory
test/scaffold/kit_test.dart:7:8: Error: Error when reading 'lib/src/separator_linetype.dart': No such file or directory
test/scaffold/kit_test.dart:8:8: Error: Error when reading 'lib/src/words/words.dart': No such file or directory
test/scaffold/live_test.dart:8:8: Error: Error when reading 'lib/src/live.dart': No such file or directory
test/scaffold/words_test.dart:12:8: Error: Error when reading 'lib/jet_cad_2d_kit_architecture.dart': No such file or directory
test/scaffold/words_test.dart:13:8: Error: Error when reading 'lib/src/words/words.dart': No such file or directory
test/scaffold/live_test.dart:87:18: Error: Method not found: 'liveTypesOf'.
00:00 +0 -4: Some tests failed.
```

(The flutter compiler words it "Error when reading ...: No such file or directory", not the analyzer's "Target of URI doesn't exist".)

GREEN, kit: `dart format . && flutter test` gives `00:00 +6: All tests passed!` (SC-example, SC-live, SC-ids, SC-words, SC-text, SC-conformance).

RED, integration (`cd packages/jet_cad_2d_integration && flutter test --enable-vmservice`, with `lib/jet_cad_2d_integration.dart` absent; see Deviation 1):

```
test/scaffold/prepare_test.dart:7:8: Error: Error when reading 'lib/jet_cad_2d_integration.dart': No such file or directory
test/scaffold/prepare_test.dart:24:15: Error: Method not found: 'architectureController'.
test/scaffold/smoke_test.dart:5:8: Error: Error when reading 'lib/jet_cad_2d_integration.dart': No such file or directory
test/scaffold/smoke_test.dart:14:15: Error: Method not found: 'architectureController'.
test/support/editor_rig.dart:36:15: Error: Method not found: 'planEditorApp'.
00:00 +0 -2: Some tests failed.
```

GREEN, integration: `00:01 +2: All tests passed!` (SC-prepare, SC-smoke). No `settleHistory` or async change was needed.

## Words check

- Every word was checked against `strings_{en,de,tr}.dart` by a script. Each copied word (templates mapped `{x}` to `$x`) must occur byte for byte in its source. Result: `en 55 not found: []`, `de 55 not found: []`, `tr 55 not found: []`.
- The new words the brief lists were exempt: Opening/Wandöffnung/Açıklık, Justification/Ausrichtung/Hizalama, Kind/Art/Tür, Axes/Achsen/Eksenler, `{value}`.
- `grep -n "[^ -~]"` on the three word files shows literal characters (ü, Ö, ß, ä, ö, °, ı, ş, ğ, ç, Ç). No escapes.

## Gates

- `packages/jet_cad_2d_kit_architecture`: `flutter test` gives `+6: All tests passed!`; `flutter analyze` gives `No issues found!`; `dart format --output=none --set-exit-if-changed .` exits 0.
- `packages/jet_cad_2d_integration`: `flutter test --enable-vmservice` gives `+2: All tests passed!`; `flutter analyze` gives `No issues found!`; format exits 0.
- `tool/ci`:
  - `dart test` gives `00:41 +118: All tests passed!`.
  - `dart analyze --fatal-infos lib test expect_failures.dart ... check_kit_deps.dart` gives `No issues found!`.
  - `dart format --output=none --set-exit-if-changed lib test ... ../readme_probe/lib` gives `Formatted 24 files (0 changed)`, exit 0.
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 2 package(s) checked, none names the plan library or another kit`.
- Sanity: `packages/jet_cad_2d_kit` `flutter test` gives `+400: All tests passed!`, analyze `No issues found!`. `packages/jet_cad_2d_plan` `flutter test --enable-vmservice` gives `01:53 +1548: All tests passed!`, analyze `No issues found!`.
- `flutter pub get` rewrote no existing `analysis_options.yaml` (`git status --short` showed only `M pubspec.yaml` and the two new directories). Before the commit, `git status --short -uall` listed exactly the brief's 29 paths.
- Dry run (`cd packages/jet_cad_2d_kit_architecture && dart pub publish --dry-run`, after the commit): `Package has 0 warnings.`

## Mutation results

All were run on committed files. Each was reverted with `git checkout -- <file>`, and `git diff --quiet -- <file>` exited 0. The final `git diff --quiet` was clean.

| Mutation | Red test | Red line |
|---|---|---|
| M-SC-1 (delete `prepare:`) | SC-ids | `Expected: <Closure: (DraftDocument) => void from Function 'ensureDashedLinetype': static.>  Actual: <null>` |
| M-SC-1 | SC-example | `Expected: 'prepare: DASHED at handle 6'  Actual: 'prepare: no DASHED record'` |
| M-SC-1 | SC-prepare | `Expected: <Instance of 'LinetypeRecord'>  Actual: <null>` |
| M-SC-2 (`[200, -50]`) | SC-prepare | `Expected: <Instance of 'LinetypeRecord'>  Actual: <Instance of 'LinetypeRecord'>` (value inequality) |
| M-SC-ver (`0.1.1`) | SC-ids | `Expected: '0.1.0'  Actual: '0.1.1'` |
| M-SC-ver | SC-example | `Expected: 'architecture 0.1.0: 0 types, 0 tools'  Actual: 'architecture 0.1.1: ...'` |
| M-SC-ids (`architecture.gaps`) | SC-ids | `Which: at location [4] is 'architecture.gaps' instead of 'architecture.gap'` |
| M-SC-3 (tr gap word deleted) | SC-words | `Which: does not contain 'tool:architecture.gap'` |
| M-SC-3 | SC-conformance | `[KitProblem:wordMissing: tr: no word for "tool:architecture.gap"]` |
| M-SC-4 (de `{n}`) | SC-text | `Expected: Set:['name']  Actual: Set:['n']` |
| M-SC-4 | SC-conformance | `KitProblem:placeholderMismatch: de: "text:architecture.room-occupied" has the placeholders {n}, English {name}` |
| M-SC-5 (position removed from sameAsEnglish) | SC-conformance | `KitProblem:wordUntranslated: de: "property:architecture.opening.position" is its English, "Position"; ...` |
| M-SC-live-1 (no filter) | SC-live | `Expected: [4100, 4300]  Actual: [4050, 4100, 4300]` |
| M-SC-live-2 (`!= null`) | SC-live | `Expected: false  Actual: <true>` (`live_test.dart 95:5`) |
| M-SC-live-3 (`(handle) => null`) | SC-live | `Expected: 'architecture.peg'  Actual: <null>` (`live_test.dart 89:5`) |
| M-SC-10 (example without prepare call) | SC-example | `Expected: 'prepare: DASHED at handle 6'  Actual: 'prepare: no DASHED record'` |
| M-SC-7 (no `locale:`) | SC-smoke | `Expected: 'Seç'  Actual: 'Select'` |
| M-SC-perm (`PlanPermissions.full`) | SC-smoke | `Expected: PlanPermissions:<PlanPermissions(tools: {plan.select}, move: false, ...  Actual: PlanPermissions:<PlanPermissions()>` |
| M-SC-8 (no integration `test_flags`) | SC20c | `SC20c the integration package's tests run with --enable-vmservice [E]` (`Actual: '- package: packages/jet_cad_2d_integration\n' ... Which: does not contain ...`) |
| M-SC-9 (kit matrix entry deleted) | SC16 | `Which: has no match for 'packages/jet_cad_2d_kit_architecture' at index 6` |
| M-SC-deps (kit_test imports the plan) | check_kit_deps | `jet_cad_2d_kit_architecture: test/scaffold/kit_test.dart imports jet_cad_2d_plan`, `exit=1` |

## Files changed (commit 8102f8a4)

- Modified:
  - `pubspec.yaml`
  - `.github/workflows/ci.yml`
  - `tool/ci/test/scripts_test.dart`
- New in `packages/jet_cad_2d_kit_architecture/`:
  - `pubspec.yaml`, `analysis_options.yaml`, `LICENSE`, `README.md`, `CHANGELOG.md`
  - `lib/jet_cad_2d_kit_architecture.dart`
  - `lib/src/{kit,ids,live,separator_linetype}.dart`
  - `lib/src/words/{en,de,tr,words}.dart`
  - `example/main.dart`
  - `test/example_test.dart`, `test/scaffold/{kit,words,live}_test.dart`
- New in `packages/jet_cad_2d_integration/`:
  - `pubspec.yaml`, `analysis_options.yaml`, `README.md`
  - `lib/jet_cad_2d_integration.dart`
  - `test/support/editor_rig.dart`, `test/scaffold/{smoke,prepare}_test.dart`

## Deviations

1. **Integration RED run order.** I took the brief's code blocks out by script in one pass, so `lib/jet_cad_2d_integration.dart` was written before Step 8's RED run. To get a true RED, I moved the file to the session scratchpad, ran the tests (output above), and moved the same file back unchanged. No content changed.
2. **The flutter compiler's wording.** The RED text reads "Error when reading '...': No such file or directory" and "Method not found", not the analyzer's "Target of URI doesn't exist" or "Undefined name". It is the same failure.
3. **Formatting only.** `dart format .` reflowed the brief's tests and SC20c (short style). No code changed.

No other deviation. The brief had no defect that needed a fix.

## Concerns

- **Vacuous checks until Task 10.** `architectureKit.types` and `.tools` are empty at this task. SC-example's per-tool loop and the descriptor half of SC-conformance's id sets check nothing until Task 10 adds the first type and tool. The SC-example header reads `0 types, 0 tools`.
- **Untested rig helpers.** `editor_rig.dart` helpers other than `pumpEditor` (without `centre`) and `status` are compiled and analysed but run by no test yet: `globalOf`, `globalAt`, `press`, `activeTool`, `pagePlanJson`, `kitCatalog`, `liveOf`, and `pumpEditor`'s camera path. Their first users are Tasks 10 onward.
