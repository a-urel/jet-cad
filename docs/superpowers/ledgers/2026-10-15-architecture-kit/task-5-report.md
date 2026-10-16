# Task 5 report: `prepare` and `build` (spec 3a C1.3, C1.9)

Status: DONE. Commit `c91c046a feat(plan): kits prepare new plans; a host builds one (spec 3a C1.3, C1.9)` on `feat/architecture-kit`, parent `1672344b`.

## Implementation summary

- `jet_cad_2d_kit`:
  - `lib/src/kit/plan_build.dart` (new): `typedef PlanBuild = void Function(DraftDocument document, KitWords words);` with the brief's doc, exported from `lib/jet_cad_2d_kit.dart` (before `plan_kit.dart`).
  - `lib/src/kit/plan_kit.dart`: `final void Function(DraftDocument document)? prepare;` (constructor `this.prepare`, named, last), import `show Component, DraftDocument`.
- `jet_cad_2d_plan`, `lib/src/controller/plan_controller.dart`:
  - Factory: `PlanBuild? build` parameter, doc paragraph; passes `made: json == null` and `build: json == null ? build : null`.
  - Private constructor: `required bool made, required PlanBuild? build`; body `if (made) _prepare(document);` then `_open(document, measurer, loadDiagnostics, build: build);`.
  - `newPlan({String? decimalSeparator, PlanBuild? build})`: `newPlanDocument` → `_prepare(made)` → `_replace(made, ..., build: build)`.
  - New `_prepare` (per-kit try/catch → `KitDiagnostic(kitId, 'prepare', hookFailed, 'prepare: $error')`, then `clearHistory()`), `_buildWords` (one `KitNamesWords` over `kits.kits.fold(_hostWords, merge)`, `() => _locale.value`, `planStrings.decimalSeparator`), `_runBuild` (build under `_unrestricted`; on throw undo every step unrestricted and report `('plan', 'build', hookFailed)`; then `clearHistory()`).
  - `_open(..., {PlanBuild? build})`: `if (build != null) _runBuild(document, build);` right after `session.runKitFactories(...)`. `_replace(..., PlanBuild? build)` forwards it; its doc's step 3 amended. Task 4's notice wiring (`_rebindNotice()` at the end of `_open`, dispose order) untouched.
  - `lib/src/controller/new_plan.dart`: header comment lines 3-5 as the brief says.
- Tests: `test/support/throwing_kit.dart` gains the `prepare` hook (`boomHooks` + `prepare: (document) => check('prepare')`); new `test/controller/prepare_build_test.dart` (PB1-PB11) and `test/controller/new_plan_test.dart` (ND1, ND3, two ND4 cases), both verbatim from the brief (after `dart format`).
- Docs: `docs/kits.md` §10.1 paragraph appended, §10.8 table row added; contract spec 3a amendments bullet; design-mode spec `## Amendments` two bullets (P4 prepare, P2 build).

## TDD evidence

RED, contract (`cd packages/jet_cad_2d_kit && flutter test test/kit/plan_build_test.dart`):
```
test/kit/plan_build_test.dart:15:57: Error: No named parameter with the name 'prepare'.
test/kit/plan_build_test.dart:19:11: Error: 'PlanBuild' isn't a type.
test/kit/plan_build_test.dart:17:58: Error: The getter 'prepare' isn't defined for the type 'PlanKit'.
```
GREEN: `flutter test test/kit/plan_build_test.dart test/kit/plan_kit_test.dart` → `00:00 +13: All tests passed!`

RED, plan (`cd packages/jet_cad_2d_plan && flutter test test/controller/prepare_build_test.dart`):
```
test/controller/prepare_build_test.dart:182:9: Error: No named parameter with the name 'build'.
test/controller/prepare_build_test.dart:209:40: Error: No named parameter with the name 'build'.
... (6 such errors; 224:15 is newPlan's)
```
GREEN: `00:00 +11: All tests passed!` (PB1-PB11).
`flutter test test/controller/new_plan_test.dart` → `00:00 +4: All tests passed!` (ported, passes on first run as the brief expects).
`grep -n "Döşeme" test/controller/prepare_build_test.dart` → `232:    expect(seen.single.word('tool:test.slab'), 'Döşeme');` (literal, not an escape).
`flutter test test/invariants/doc_snippets_test.dart` (kit) → `00:00 +3: All tests passed!`

## Gates (run before the commit, on the committed content)

- `packages/jet_cad_2d_kit`: `flutter test` → `00:06 +394: All tests passed!`; `flutter analyze` → `No issues found! (ran in 3.7s)` (after the deviation below); `dart format --output=none --set-exit-if-changed .` → `Formatted 89 files (0 changed)`, exit 0.
- `packages/jet_cad_2d_plan`: `flutter test --enable-vmservice` → `01:59 +1530: All tests passed!`; `flutter analyze` → `No issues found! (ran in 5.1s)`; format → `Formatted 295 files (0 changed)`, exit 0.
- `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 1 package(s) checked, none names the plan library or another kit`, exit 0.
- `git status --short` after commit and after all mutations: empty (no `analysis_options.yaml` change appeared).

## Mutation results (all on committed code; each reverted with `git checkout -- <file>`, then `git diff --quiet -- <file>` exit 0)

| Mutation | Red test | Red line |
|---|---|---|
| M-PB-1 delete `if (made) _prepare(document);` | PB1 (also PB2, PB4, PB5, PB6) | PB1 `Actual: <false>` (prepared) |
| M-PB-2 delete `_prepare(made);` in newPlan | PB1, PB2, PB3 | PB1 `Actual: <false>`; PB2 `Actual: ['prep', 'late:true'] ... shorter than expected`; PB3 `Actual: <false>` (`a new plan is prepared`) |
| M-PB-3 `kits.kits.reversed` in `_prepare` | PB2 | `Expected: ['prep', 'late:true'] Actual: ['late:false', 'prep']` (line 98) |
| M-PB-4 `_prepare(document);` first in `_open` | PB3-prepare-load (also PB2) | `Expected: false Actual: <true>` at line 118 (prepared after the constructor's load) |
| M-PB-5 bare `prepare(document);` | PB4 | `BoomFailure(prepare)` at `prepare_build_test.dart 139:15` |
| M-PB-6 delete `_prepare`'s `clearHistory()` | PB5 | `Expected: false Actual: <true>` at 166:5 (`canUndo`) |
| M-PB-7 `_runBuild` first in `_open` | PB6 | `Expected: an object with length of <1> Actual: []` at 190:5 (`leavesOf`) |
| M-PB-8 delete `_runBuild`'s `clearHistory()` | PB6, PB8, PB9 | PB6 `Expected: false Actual: <true>` at 193:5 |
| M-PB-9 host words folded last | PB6 | `Expected: 'Plate' Actual: 'Slab'` at 200:5 |
| M-PB-10 factory passes `build: build` | PB7 | `Expected: <0> Actual: <1>` at 212:5 |
| M-PB-11 newPlan drops `build: build` | PB8 | `Expected: an object with length of <1> Actual: []` at line 226 |
| M-PB-12 `() => const Locale('en')` | PB8 | `Expected: Locale:<tr> Actual: Locale:<en>` at line 231 |
| M-PB-13 delete the undo loop | PB9 | `Expected: empty Actual: [18]` at 250:5 |
| M-PB-14 try body alone | PB9 | `Bad state: the build broke` thrown from the constructor (`_runBuild` → `_unrestricted`) |
| M-PB-15 build without `_unrestricted` | PB10 | `Expected: an object with length of <1> Actual: []` at 272:5 |
| M-PB-16 `_runBuild` moved after `_unsettled` in the constructor | PB11 (also PB6, PB8, PB10) | PB11 `Expected: DecimalSeparator.comma Actual: DecimalSeparator.point` at 289:5; PB6/PB10 `dirty` `Actual: <true>` |
| M-ND-1 delete `doc.header.units = DrawingUnits.millimeters;` | ND1, ND3, C1 | `Expected: DrawingUnits.millimeters Actual: DrawingUnits.unitless` (new_plan_test 45:5, 68:5; plan_controller_test line 39) |
| M-ND-2 `originX: -7425.5` | ND1, ND3 | `Actual: PageComponent(... at (-7425.5, -5250.0) ...)` at 48:5 and 65:5 |
| M-ND-3 delete `doc.commands.clearHistory();` | ND1 | `Expected: <0> Actual: <1>` at 39:5 (`undoDepth`) |

All 19 named mutations red. M-PB-9's pattern was applied to the `dart format`ted form of `_buildWords` (`kits.kits\n .fold<KitNames>(_hostWords, ...)`), same meaning.

## Files changed

- `packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart`
- `packages/jet_cad_2d_kit/lib/src/kit/plan_build.dart` (new)
- `packages/jet_cad_2d_kit/lib/src/kit/plan_kit.dart`
- `packages/jet_cad_2d_kit/test/kit/plan_build_test.dart` (new)
- `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`
- `packages/jet_cad_2d_plan/lib/src/controller/new_plan.dart`
- `packages/jet_cad_2d_plan/test/support/throwing_kit.dart`
- `packages/jet_cad_2d_plan/test/controller/prepare_build_test.dart` (new)
- `packages/jet_cad_2d_plan/test/controller/new_plan_test.dart` (new)
- `docs/kits.md`
- `docs/superpowers/specs/2026-10-13-kit-contract-design.md`
- `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md`

## Deviations

1. **PB0 (kit test), lint fix.** The brief's `final PlanBuild build = (document, words) {};` trips `prefer_function_declarations_over_variables` (`flutter analyze`: `info • Use a function declaration rather than a variable assignment ... • test/kit/plan_build_test.dart:19:21`), failing the analyze gate. Rewritten as `void noop(DraftDocument document, KitWords words) {}` / `final PlanBuild build = noop;` — still names `PlanBuild` (so the file does not compile without the export) and keeps the `isA<void Function(DraftDocument, KitWords)>()` check. Same meaning; PB0 is a premise test exempt from the mutation rule.
2. **`_open`'s signature** is formatted by `dart format` with `{PlanBuild? build}` on its own line; `_replace`'s named parameters likewise split one per line. No behavioural difference.

## Concerns

- ND4's two ported cases (page-only and catalog-only registration) exercise the engine's codec and the catalog, not code this task adds; no named mutation in the brief covers them, and none in `new_plan.dart` would turn them red. They are ported tests (A12), carried for D-28; flagging only per the project bar.
- M-PB-4's first red assertion is `prepared` (line 118); the later `save()` byte-equality line is not reached under that mutant, so the "save() differs" half is not separately observed (the test stops at the first failure).
