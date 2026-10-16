# Pre-flight log: Tasks 1-6

Checked against the worktree at `c6bcce3e` (Flutter 3.47.6 on this machine; the Caskroom folder is named 3.27.3 but `flutter --version` reports 3.47.6). No repository file edited; only `plan-parts/task-0{1,2,4,5}.md` changed. The reconcile log has no fix-log row for Tasks 1-6; its "Unresolved 1" (skeleton predates R-P7) is already settled in the skeleton (`:167` reads `PlanWords get words`, `:200-202` take `PlanWords`).

## Task 1: The symbol box family moves into the contract

| Check | Result | Fix (before → after) |
|---|---|---|
| `jet_cad_2d_plan/lib/src/symbols/symbol_box.dart` 1-171: header 1-9, imports 10-14, body 16-151, stale doc 152-153, 154-171 | as claimed (`:152-153` names `WallFaces`) | — |
| `symbol_placer.dart:44-87` (`placementTransform` doc, body, `_quarterTurn`, blank) and its only other use `:183`, doc ref `:160` | as claimed | — |
| `move_resolver.dart:13` import, `:16-23` `isOrthonormal`; names it uses (`SymbolBox`, `boxOfDefinition`, `footprintOf`, `isOrthonormal`) | as claimed; new `show` list complete | — |
| `symbol_section.dart:14` import, `:132-142` `_isOrthonormal`, `:157` call; names used (`SymbolBox`, `boxOfDefinition`, `boxOfEntry`) | as claimed | — |
| `plan_symbol_tool.dart:26-27`, `:32`; `plan_property_panel.dart:22`, `:32`; `services.dart:8`, `:11`; `unit_index.dart`, `unit_label.dart` imports and show lists | as claimed (each file's uses grepped) | — |
| Test importers: `plan_symbol_tool_test:46,48`, `symbol_ghost_test:39` (only `placementTransform` used from the placer), `move_resolver_test:12`, `symbol_section_test:37`, `mode_test:10-11`, `service_record_test:12-13`, `service_plans:14-15`, `unit_fixtures:30-31` | all exist and say what is claimed; every other test importing `symbol_placer.dart` shows `placeSymbol`/`definitionForEntry` or uses none of the moved names | — |
| No other package imports the kit or the plan library (apps, floor_plan, restaurant_symbols): no new ambiguous import | confirmed (`tool/ci/test/kit_deps_test.dart` only) | — |
| Kit `test/support/placements.dart:17-39` copy, `:7` import; `unit_label_test.dart` imports both | as claimed; `Vector2` import unused after the delete | — |
| Purity: `import_walker.dart:21` allow-list (`jet_cad_2d`, `meta`, `vector_math`), `dart:math` allowed; P1 walks `lib/src/model` | as claimed | — |
| Kit test copy ranges from the plan's `symbol_box_test.dart` | `near` is at `:46`, `target` at `:48-53`: "21-45" drops `near`, "47-52" drops `target`'s closing brace | Step 3.1 and the file's comment: `lines 21-45 … and 47-52` → `lines 21-46 … and 48-53` |
| Groups `:66-98`, `:100-179`, `:181-262`, `:264-292`, `:319-341`; Step 5.10 keeps `:21-22`, `:47-63`, `:295-317` | as claimed | — |
| `symbol_placer_test.dart` helpers `:29-34`, `:101-116`, `:176-190`, group `:193-394` (P1-P4, P20-P23), names it uses | as claimed (no other helper used) | — |
| `symbol_fixtures.dart:25-140` needs only `dart:convert`, `dart:typed_data`, engine, kit, `Vector2` | as claimed | — |
| SB-ortho arithmetic (skew columns, 89.43°), SB-one-owner regex and probe lines | sound | — |
| Mutations M-SB-ortho/-export/-pure/-arc/-clean/-owner: committed files, named red tests (P3 and P23 assert no `-0.0`) | sound; Commit before Mutation | — |
| Contract spec `## Amendments from the PR review (2026-10-13)` `:397`, `## Inputs for sub-project 2` `:412` | exist | — |
| `find lib -name '*.dart' \| wc -l` = 101 | confirmed | — |
| Commit paths cover every created/modified/deleted file; gates incl. `--enable-vmservice`, check_kit_deps | yes | — |

## Task 2: Object views, hidden fields

| Check | Result | Fix (before → after) |
|---|---|---|
| `properties.dart` today (no imports; `_BoundField` `:349-389`; covariance note `:36-40`); full-file rewrite keeps every other line | matches today's text outside the named members | — |
| `plan_type.dart:22-25`, `:86-95`, `:132-146`, `:148-157`; imports `:11-20` | as claimed, **but** the new `fieldsOf`/`commitField` name `PlanWords`, which `plan_type.dart` cannot see (neither `plan_services.dart` nor `properties.dart` re-exports `plan_words.dart`): compile error | Step 3.3 gains a first bullet: add `import '../model/plan_words.dart';` after `kit_ids.dart` (`:17`) |
| Files list says `plan_type_fixtures.dart` "(doc only)", Step 3.5 says no change, commit omits it | inconsistent | Files: `…, test/support/plan_type_fixtures.dart (doc only)` → `…; test/support/plan_type_fixtures.dart is unchanged (Step 3.5)` |
| `plan_kit.dart` validate tools loop `:121-130`; `PlanTool.settings` is `PlanToolSettings<Object>?` | the new loop compiles; `needsObject` is covariance-safe | — |
| `kit_problem.dart` last code `unitKindWord`; no exhaustive switch over `KitProblemCode` anywhere | confirmed | — |
| `plan_services.dart:17-28` `KitWords`; no other `KitWords` implementer in the workspace | confirmed | — |
| Kit fixtures: `objectDocument`, `slabType`, `postType`, `hSlab/hPost/hBare`, `slabAt` (π/7 → `'26°'`), `LoggingType`, `Slab`/`Post` members; `KitNames.empty`; `FakeServices` in `plan_type_test.dart:32` | all exist as used | — |
| Callers of `fieldsOf`/`commitField`/`sectionFor`: kit `plan_type_test` (PT3-PT6, PT10), `example_code_test:37-41`, plan `covariance_test:33,40,43`, panel `:337`, `:547`, `:837-843` | complete list (grep) | — |
| Every `section:` builder: kit `plan_type_test:225`; plan `panel_kits.dart:462-468`, `test_kit.dart:426-432` (`slabSection`), `throwing_kit.dart:110` | all handled by Step 2/4 | — |
| Panel switches over `PropertySpec`: `_textOf`, `_parse`, `_row` only | three, all handled | — |
| Panel `_guarded` swallows `ArgumentError`, reports any other throw; `_commit` re-shows the stored value | PO-range and PO-G-range expectations hold | — |
| Engine APIs: `Aabb2.fromPoints`, `Generated(kind, payload)`, `Generated.text(payload, text)`, `textPayload`, `entities.textAt`, `ParametricView.paramsOf`, `RemoveNodeCommand`, `drawingLayer`, `ObjectLayer`, `handleSeed` | exist with the used signatures | — |
| Plan test support: `pumpDesign(right:)`, `boxController({kits})`, `boxKit`, `addObject<T>(d, c, {at})`, `BlockComponent.copyWith(size:)`, `BoomFailure.hook`, `PlanPermissions.copyWith(reshape:)`, `permissions.allows`, `c.kits.kits` | exist | — |
| TK2/TK3 (`test_kits_test.dart:25-42`) with the new boom hooks and words | stay green | — |
| docs/kits.md §10.2 `:355`, §10.3 table `:402-409`, bullet `:412` | as cited | — |
| 2a spec has no `## Amendments`; `## Risks` `:827` | Task 2 creates it before Risks | — |
| Mutations (21): each on a file committed in Step 9, each names a red test of this task | sound (M-PO-pure reddens P9 even though the lib stops compiling) | — |
| Panel line numbers shift after Task 1's import delete | off by one | Step 6 header gains "line numbers are at `c6bcce3e`; Task 1 deletes `:32`, so each place is one line higher: find it by the code quoted" |

## Task 3: Words with parameters

| Check | Result | Fix |
|---|---|---|
| `plan_kit.dart:84-86` namespace case, `host_words.dart:29` case and `:11-12` doc | as claimed | — |
| `conformance.dart` `_wordProblems` (`stored`, `english`, codeWords loop, locales loop), `conformance(...)` cascade | the new loop and `_placeholderProblems` fit; KW-conf / -placeholders / -complete expectations computed by hand: hold | — |
| Sample kit fixture: `sampleCatalog`, `sampleLocales`, `sampleSameAsEnglish` (Bar only), `sampleNames` (no `en`), files `sample.jetlib`, `sample_snapshot.json` | exist | — |
| `KitNames.word` falls back to English; `merge` keeps the receiver's word | confirmed (`kit_names.dart:35-52`) | — |
| Plan `numbered_names.dart` today, its only caller `plan_layer_panel.dart:47` (no kit barrel import there), its test imports only the plan barrel and the file | prefixed kit import avoids every ambiguity | — |
| `plan_controller.dart:355-359` `_services`; `planStrings` `:606-607`; `reportLocale(locale, {strings})`; `PlanStringsEn` const and extendable; built-in separators en `.`, de/tr `,` | as claimed | — |
| No other `KitWords`/`PlanWords` implementer | confirmed | — |
| Mutations (18) | each on a committed file with a red test | — |

## Task 4: Tool notices

| Check | Result | Fix (before → after) |
|---|---|---|
| `Tool`'s abstract members (`jet_cad_2d_flutter/lib/src/tool.dart:116-124`, `paintOverlay`) | the three test tools implement them all | — |
| `package:flutter/widgets.dart` exports `KeyEvent` (`src/widgets/keyboard_listener.dart:15`), `ValueNotifier`, `VoidCallback`, `Canvas`, `Size`, but **not** `ValueListenable` (`plan_editor.dart:12-13` imports it from foundation) | `import 'package:flutter/services.dart' show KeyEvent;` beside widgets/material is `unnecessary_import` (fails `flutter analyze`); `guarded_notice_test`'s foundation import is unnecessary too (it uses only `ValueNotifier`); `guard.dart` and `throwing_kit.dart` need `ValueListenable` and import no foundation | removed the services import from `tool_notice_test.dart`, `notice_kit.dart`; removed foundation and services imports from `guarded_notice_test.dart`; Step 2's hedge rewritten to say why; Step 3.2: throwing kit gains `import 'package:flutter/foundation.dart' show ValueListenable;`; Step 5's note ("`ValueListenable` … come with widgets") → guard gains the same import before `scheduler.dart` |
| `GuardedTool` ctor, `_getterFailed` (`guard.dart:253-300`), `DiagnosticsLog` (exported by `guard.dart:19`, `entries`, `dispose`) | as used | — |
| `BoomTool(this.kit)` `:442`, its `dispose` `:459-462` | as claimed | — |
| Controller: `_hostWords` `:480`, `_names` `:483-485`, `_activeTool` `:552`, `activeTool`/`_onTools` `:1976-1980`, `_replace` arms select first `:1574-1575`, `_open` ends with `_reportUnofferedKinds()` `:1550`, dispose `:2594`, `:2610`; `KitSet.kitOf` (M-TN-textOf-host) | exist | — |
| `PlanEditor` relay `:350-351`, `_statusLine` `:514-519`, key `status-text` `:595`; `planSupportedLocales`, `planLocalizationsDelegates`; `editorPlanJson` (2 marks), `markKit()`, `catalog.objectsOf`, `selectedCount` | exist | — |
| Line numbers in Step 6 shift by Task 3's two lines | off by two | Step 6 header gains a "find it by the code quoted" note |
| Mutations (11) | each on a committed file with a red test | — |

## Task 5: `prepare` and `build`

| Check | Result | Fix (before → after) |
|---|---|---|
| Factory and private ctor (`:253-367`), `_open(…)` `:360`, `_open` `:1481-1551` (permissions set first, `runKitFactories` `:1538`), `_replace` `:1571-1609`, `_unrestricted` `:1820-1828`, `load` `:671`, `save` `:621` | as claimed; the build sits after the permissions and the system, before the listeners, the tracker and the save point | — |
| `newPlan` (`:692-709`) ends with two statements (`final measurer = …;` then `_replace(newPlanDocument(…), …)`) | "its last statement becomes" would leave a duplicate `measurer` | Step 6.4: "its last statement becomes:" → "its last two statements (`final measurer = FlutterTextMeasurer();` and the `_replace(newPlanDocument(...), measurer, unsettled: ...)` call, `:704-709`) become:" |
| `new_plan.dart` header `:3-5`, `newPlanDocument`, `defaultPlanPage`, its `clearHistory` | as claimed (M-ND-1..3 bite ND1/ND3) | — |
| `jet_cad_floor_plan/test/new_document_test.dart` ND1 `:21-47` (DASHED `:35-38`), ND3 `:64-80` (`:77-78`), ND4 `:83-96`, `:105-111`, `:113-121` | line by line: assertions unchanged except the ruled count/reader lines (already listed for the human in the reconcile log) | — |
| Harness `planDocument(kits, {measurer})`, `installSystem`, `planText`, `catalogOf`, `registerPlanComponents`, `slabPlanText`, `slabsOf`, `leavesOf`; `testKit` words (`Width`, tr `Döşeme`) | exist as used | — |
| `LinetypeRecord`/`DashPattern` const ctors and `==`; `linetypes.contains/add/[]`; `UndoStack.clear` clears redo too; `PlanPermissions.readOnly`; `entities.liveCount`; `ParametricSystem.install` regenerates nothing (M-PB-7 bites) | confirmed | — |
| `hookFailed` not plan-scoped (`diagnostics_log.dart:14-20`) | confirmed | — |
| Line numbers shift after Tasks 3 and 4 | — | Step 6 header gains a "find each place by the code quoted" note |
| Mutations (19) | each on a committed file with a red test | — |

## Task 6: `liveTypeIdOf`, `FakePlanServices`

| Check | Result | Fix |
|---|---|---|
| `implements (PlanServices\|ServicesHost)`: `KitServices`, `_Host`, and four `noSuchMethod` fakes today (+ Task 2's `_Services` = the five named) | confirmed | — |
| `ServicesHost` `:17-32`, `KitServices` `:34-109`, `_Host` `:203-229`, `session.frozen` (`session.dart:115`, the system's `isFrozen`), `PlanController.catalog`, `typeOf`, `frozen`, `locked` (missing kit's objects locked, `locks.dart:109-111`) | as claimed | — |
| `ParametricCatalog.typeIdOf` (answers a frozen object's id), `SpatialIndex(document)`/`document`/`forEachLeafInBand`/`dispose` (a second index over one document is harmless), `BandMode.crossing`, `QueryFilter.picking()`, `CameraController(ViewportTransform(worldToScreenMatrix:))`, `scale`, `worldToScreen`, `AttachmentRegistry` (`kinds`, `attach`), `AttachmentQuery` named params, `addDrafted`, `entities.slotOf` | exist with the used signatures | — |
| Box kit: `Switches.failing`, `SquareParams(side, poisoned)`, `SquareType(sw)`, `DiscParams(radius)`, `ringKit`, `StampTool`, `addObject(d, at, params)`, `addLine`, `atSquare`, `nearSquare`; the frozen scene matches `frozen_write_test.dart:110-125` | exist | — |
| LS-fake-1..6 expectations (camera flip, shared order, settings live map, frozen null) computed by hand | hold | — |
| Mutations (13) | each on a committed file with a red test | — |

## Cross-task checks (Tasks 1-6)

- Spec C2's "every-hook-throws kit gains them": `display`, `range`, `visible` (Task 2), `notice`, `noticeValue` (Task 4), `prepare` (Task 5); `build` is the host's, pinned by PB9.
- Spec "Amendments to other specs": contract lines from Tasks 1, 2, 3 (K4 and surface), 4, 5, 6 cover every item of the contract bullet; 2a lines P3 (Task 2), P2 notice (Task 4), P4 prepare and the build (Task 5); C1.8/C1.10 rows are Task 7's.
- `boomHooks` insertion points are consistent in order (Task 2 after `'colourWrite', 'title',`; Task 4 after the tool line; Task 5 last).
- No `analysis_options.yaml` staged; no `git add -A`; every Commit precedes its Mutation step; no TBD/TODO/"similar to".

## Blocking issues not fixed

None.

## Edits made: 13

- Task 1: 1 (two line ranges, Step 3.1 text and file comment).
- Task 2: 3 (Files line; `plan_type.dart`'s `plan_words.dart` import; Step 6 line-number note).
- Task 3: 0.
- Task 4: 7 (services import out of `tool_notice_test`; out of `notice_kit`; foundation and services imports out of `guarded_notice_test`; Step 2's note; throwing kit's `ValueListenable` import; `guard.dart`'s `ValueListenable` import and its wrong note; Step 6 line-number note).
- Task 5: 2 (`newPlan`'s last two statements; Step 6 line-number note).
- Task 6: 0.
