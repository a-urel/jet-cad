# Task 3 report: Words with parameters (spec 3a C1.6)

Status: DONE

Commit: `1eef1a22 feat(kit): words with parameters (spec 3a C1.6)` (on top of 31c2b976).

## What was implemented

Contract (`packages/jet_cad_2d_kit`):
- `lib/src/model/kit_text.dart` (new, pure): `KitText` (value equality on id + args, order-free hash), `fillText`, `placeholdersOf`, placeholder pattern `\{([A-Za-z][A-Za-z0-9]*)\}`. Verbatim from the brief.
- `lib/src/model/numbered_names.dart` (new, pure): `numberedNameIndex(name, patterns, {fold})`. Verbatim.
- `lib/src/model/model.dart`: exports `kit_text.dart` (after `kit_problem.dart`) and `numbered_names.dart` (after `manifest_component.dart`); both barrels carry them.
- `lib/src/model/kit_problem.dart`: `placeholderMismatch` after `settingsNeedObject`.
- `lib/src/model/plan_words.dart`: `PlanWords.text(id, [args])` and `PlanWords.decimalSeparator` (R-P7).
- `lib/src/kit/plan_services.dart`: `KitNamesWords(names, locale, {decimalSeparator})`, `text` = `fillText(word(id), args)`, `decimalSeparator` read live, `.` by default. `KitWords` unchanged (inherits both).
- `lib/src/kit/plan_kit.dart` / `host_words.dart`: the `text` namespace joins `symbol || tool || type || property`; docs updated.
- `lib/src/authoring/conformance.dart`: English `text:<this kit>.*` words added to the words every declared locale must have; new `_placeholderProblems` (one `placeholderMismatch` per locale's text whose placeholder set differs from English's); `conformance` doc paragraph.

Plan library (`packages/jet_cad_2d_plan`):
- `plan_controller.dart`: `KitNamesWords(..., decimalSeparator: () => planStrings.decimalSeparator)`.
- `l10n/numbered_names.dart`: same signature, now delegates to the contract's `numberedNameIndex` (imported `as kit show numberedNameIndex`) with patterns current, En, De, Tr.

Docs: `docs/kits.md` §5 table row + paragraph tail, §8 code-side paragraph tail; `docs/superpowers/specs/2026-10-13-kit-contract-design.md` two bullets ("K4, texts", "Words with parameters") appended to the "Amendments from sub-project 3a" section.

Implementers of `PlanWords`/`KitWords`: `grep -rn "implements.*PlanWords\|implements.*KitWords" packages/` finds only `KitWords` and `KitNamesWords` (plan_services.dart); no test fakes needed updating.

## TDD evidence

RED (kit), after Step 2:
`cd packages/jet_cad_2d_kit && flutter test test/model/kit_text_test.dart test/model/numbered_names_test.dart test/kit/kit_words_test.dart test/authoring/text_words_conformance_test.dart`
```
test/model/kit_text_test.dart:14:12: Error: Method not found: 'fillText'.
test/model/kit_text_test.dart:42:15: Error: Method not found: 'KitText'.
test/model/numbered_names_test.dart:16:12: Error: Method not found: 'numberedNameIndex'.
test/kit/kit_words_test.dart:30:14: Error: The method 'text' isn't defined for the type 'KitNamesWords'.
test/kit/kit_words_test.dart:45:9: Error: No named parameter with the name 'decimalSeparator'.
test/kit/kit_words_test.dart:65:62: Error: The getter 'decimalSeparator' isn't defined for the type 'PlanWords'.
test/authoring/text_words_conformance_test.dart:81:44: Error: Member not found: 'placeholderMismatch'.
```
Expected: none of the new names exist yet.

GREEN (kit), after Step 3: `flutter test` -> `00:05 +392: All tests passed!`

RED (plan), after Step 4: `cd packages/jet_cad_2d_plan && flutter test test/controller/kit_words_controller_test.dart`
```
00:00 +0 -1: KW-plan-separator ... (M-KW-plan-separator) [E]
  Expected: ','
    Actual: '.'
  test/controller/kit_words_controller_test.dart 32:5  main.<fn>
00:00 +1 -1: Some tests failed.
```
Line 32 is the expectation after `reportLocale(const Locale('tr'))`, as the brief predicted; KW-plan-host passed already (as predicted).

GREEN (plan), after Step 5: `flutter analyze` -> `No issues found! (ran in 4.2s)`; `flutter test test/controller/kit_words_controller_test.dart test/l10n/ test/panels/layer_panel_test.dart` -> `00:05 +60: All tests passed!` (NN2, W-NN4 unchanged).

Docs: `flutter test test/invariants/doc_snippets_test.dart` -> `00:00 +3: All tests passed!`

## Gates (run before commit)

- jet_cad_2d_kit: `flutter test` -> `00:06 +392: All tests passed!`; `flutter analyze` -> `No issues found! (ran in 3.6s)`; `dart format --output=none --set-exit-if-changed .` -> `Formatted 86 files (0 changed)`, exit 0.
- jet_cad_2d_plan: `flutter test --enable-vmservice` -> `01:57 +1505: All tests passed!`; `flutter analyze` -> `No issues found! (ran in 3.4s)`; format -> `Formatted 289 files (0 changed)`, exit 0.
- `dart run tool/ci/check_kit_deps.dart` -> `kit dependencies: 1 package(s) checked, none names the plan library or another kit`, exit 0.
- Non-ASCII grep: `Yatak odası`, `Zaten bir oda`, `tarafından alındı`, `Plätze`, `masası`, `kişilik`, `Boş` all found as literal characters in the four test files.
- `git status --short` after commit: empty (no analysis_options.yaml touched).

## Mutations (each on the committed code, reverted with `git checkout -- <file>`, `git diff --quiet` exit 0 afterwards)

| Mutation | Test | Red line |
|---|---|---|
| M-KW-missing | kit_text_test KW-fill | `Expected: 'Bedroom 2 of {count}'  Actual: 'Bedroom 2 of '` |
| M-KW-first | KW-fill | `Expected: '7A start (left face), 7A'  Actual: '7A {end} ({side}), {wall}'` |
| M-KW-placeholders | KW-placeholders | `Expected: Set:['wall', 'end', 'side']  Actual: Set:[]` |
| M-KW-eq | KW-text | `Expected: KitText:<KitText(text:test.busy, {n: 2, name: Slab 1})>  Actual: KitText:<KitText(text:test.busy, {name: Slab 1, n: 2})>` |
| M-KW-export | kit_text_test (compile) | `test/model/kit_text_test.dart:14:12: Error: Method not found: 'fillText'.` |
| M-KW-pure | purity_test P1 | `Actual: ['lib/src/model/kit_text.dart: package:flutter/foundation.dart']` |
| M-KW-first-pattern | numbered_names_test KW-numbered; plan W-NN4 | `Expected: <12> Actual: <null>`; plan: `W-NN4 ... [E] Expected: <7> Actual: <null>` |
| M-KW-fold | KW-numbered | `Expected: <7>  Actual: <null>` |
| M-KW-args | kit_words_test KW-words | `Expected: 'Zaten bir oda: Oda 3'  Actual: 'Zaten bir oda: {name}'` |
| M-KW-separator (late final) | KW-separator | `Expected: '.'  Actual: ','` |
| M-KW-sep-object (`=> '.'`) | KW-separator and PO-words-separator | PO: `Expected: '12,5'  Actual: '12.5'` |
| M-KW-plan-words | kit_words_test (compile) | `test/kit/kit_words_test.dart:66:62: Error: The getter 'decimalSeparator' isn't defined for the type 'PlanWords'.` |
| M-KW-validate | KW-validate | `Expected: empty  Actual: [ KitProblem:unknownWordId: en: "text:test.busy" is in no known namespace, ...` |
| M-KW-validate-en | KW-validate | `Expected: [KitProblemCode:KitProblemCode.missingEnglish]  Actual: []` |
| M-KW-host | KW-host; plan KW-plan-host | `Expected: empty Actual: [`; plan: `Invalid argument (words): unknownWordId: en: "text:test.busy" is in no known namespace` |
| M-KW-conf-placeholders | KW-conf-placeholders | `Expected: [KitProblemCode:KitProblemCode.placeholderMismatch]  Actual: []` |
| M-KW-conf-complete | KW-conf-complete | `Expected: [KitProblemCode:KitProblemCode.wordMissing]  Actual: []` |
| M-KW-plan-separator | plan KW-plan-separator | `Expected: ','  Actual: '.'` |

All 18 red; final `git status --short` empty.

## Files changed

- packages/jet_cad_2d_kit/lib/src/model/kit_text.dart (new)
- packages/jet_cad_2d_kit/lib/src/model/numbered_names.dart (new)
- packages/jet_cad_2d_kit/lib/src/model/model.dart
- packages/jet_cad_2d_kit/lib/src/model/kit_problem.dart
- packages/jet_cad_2d_kit/lib/src/model/plan_words.dart
- packages/jet_cad_2d_kit/lib/src/kit/plan_services.dart
- packages/jet_cad_2d_kit/lib/src/kit/plan_kit.dart
- packages/jet_cad_2d_kit/lib/src/kit/host_words.dart
- packages/jet_cad_2d_kit/lib/src/authoring/conformance.dart
- packages/jet_cad_2d_kit/test/model/kit_text_test.dart (new)
- packages/jet_cad_2d_kit/test/model/numbered_names_test.dart (new)
- packages/jet_cad_2d_kit/test/kit/kit_words_test.dart (new)
- packages/jet_cad_2d_kit/test/authoring/text_words_conformance_test.dart (new)
- packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart
- packages/jet_cad_2d_plan/lib/src/l10n/numbered_names.dart
- packages/jet_cad_2d_plan/test/controller/kit_words_controller_test.dart (new)
- docs/kits.md
- docs/superpowers/specs/2026-10-13-kit-contract-design.md

## Deviations

1. `PlanKit.validate` doc: the brief says to insert "a `text:` word without English," after "in no known namespace", but that phrase is followed by a parenthetical belonging to it. I placed the clause after the parenthetical: "...in no known namespace (a `category:` or `unit:` word names the kit before its `/`), a `text:` word without English; a type or tool id...". Wording only.
2. Contract spec: the brief says "Task 1's section"; the 3a amendments live in "## Amendments from sub-project 3a (2026-10-15)", where Tasks 1 and 2 wrote their bullets. The two bullets were appended there. The brief's one over-long line ("`PlanWords.decimalSeparator`, inherited by `KitWords` (the UI language's separator, which the plan fills from") was rewrapped to the section's width; text unchanged.
3. Test files were run through `dart format` (the gate requires it); content and assertions are the brief's verbatim.
4. M-KW-plan-words: done as described (getter removed from `PlanWords`, added to `KitWords`); its doc comment was left dangling on `PlanWords` during the mutation, which does not affect the result (compile failure in the test, as intended).

## Concerns

None.
