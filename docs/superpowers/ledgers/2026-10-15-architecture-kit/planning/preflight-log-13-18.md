# Pre-flight log, Tasks 13-18

Checked against the worktree at `c6bcce3e` (today's `packages/jet_cad_floor_plan`, `packages/jet_cad_2d_plan`, `packages/jet_cad_2d_kit`, `packages/jet_cad_2d`, `packages/jet_cad_2d_flutter`), the skeleton, `task-scopes.md` (R-P1..R-P19) and the parts of Tasks 2, 5, 6, 9, 10, 11, 12, 20, 21 these tasks consume. No repository file touched; no command run in the repository other than reads (`grep`, `sed`, `wc`). Originals of my six parts are kept at `../preflight-orig/task-1[3-8].md`.

Analyzer facts that drove several fixes (verified): `packages/jet_cad_2d_plan/analysis_options.yaml` (which Task 9 copies for the kit and the integration package) sets `unused_import: error` and enables `avoid_dynamic_calls`; today's `jet_cad_floor_plan` uses `flutter_lints` without those, so a file copied "unchanged" can pass there and fail here.

## Task 13 (opening geometry and cuts)

| Check | Result | Fix (before → after) |
|---|---|---|
| `opening.dart` lines 1-3 header, 4 import, 6-7 imports, 37 id, 8-36 / 38-270 | correct (270 lines; :37 is `componentTypeId`) | — |
| `opening_geometry.dart` 1-19, 20-23 imports, 24-599, 600-616 `wallsInView`, 617-698, 699-727 `wallsInDocument`, 729-756 | correct (756 lines) | — |
| Today's adapters use `isLiveObject`/`liveObjectsOf` (`:714, :720, :752`) | correct; replacement code compiles against Task 11's `wallsInDocument(doc, host, LiveTypeOf live, {moved})` | — |
| `wall.dart:191-213` generate, `:215-239` `_cut` (Task 11 deletes `:203`, `:215-239`) | correct, consistent with Task 11 Step 6 | — |
| `ComponentRegistry.withComponent`, `ParametricCatalog.typeIdOf/names/objectsOf` | exist (`parametric_system.dart:638-675`) | — |
| `HostFrame.uS/uE`, `stretchesOf` with no obstacle = `[(uS,uE)]` (OG-live) | correct | — |
| Fixture names OG-live uses (`oracleFrameOf`, `oracleAt`, `addOpening`, `wallDoc`, `addWall`, `plan`, `driftOf`, `liveOf`, `testCatalog`) | exist (opening_fixture :136,:158,:162; Task 11's wall_fixture + `liveOf`) | — |
| A13-live line numbers (`opening_geometry_test` :395,:409,:458-464,:471; kink :182,:215) | correct | — |
| Kink port: kept imports | **`dart:math` and `jet_cad_2d_flutter` are used only by the shell section** (`:85` `FlutterTextMeasurer`, `:156-158` `math.`) → unused import = error | Step 4.5: removal list gains `dart:math` and `package:jet_cad_2d_flutter/...` |
| Symbol port (OG7, OG10, OR7 + :26-62): kept imports | **`dart:math` and `jet_cad_2d_flutter` used only by OR8** (`:355`, `:460-461`) | Step 4.8: removal list gains both |
| R13-5 ("a test that called installParametric calls `ParametricSystem(doc, testCatalog)..install()`") | contradicts R-P13 (`installParametric` is catalog.dart's) | → "keeps the call, catalog.dart's over `testCatalog()`" |
| Interface problem | settled by R-P8/R-P17 but unmarked | added "(Resolved by R-P8 and R-P17 …)" |
| Mutations M-OG-1..8 | each targets a committed file and names a test that goes red (M-OG-5 also HF9: verified the strays enter `walls`) | — |
| Commit list / no `git add -A` / gates / check_kit_deps | complete | — |

## Task 14 (opening type, grips, properties)

| Check | Result | Fix (before → after) |
|---|---|---|
| R-P19 (binding): position range over a kit-internal raw-registration catalog, **not** `architectureKit.types` | part built `_kitCatalog` from `architectureKit.types` and imported `../kit.dart` | New file `lib/src/type_naming.dart` (`_naming` = box, wall, opening raw registrations, today's order; `String? kitTypeIdOf(CommandTarget, Handle)`); `openingPositionRange` calls `kitTypeIdOf`; `opening_plan.dart` no longer imports `kit.dart`; Files, Produces, R14-1, commit list, M-OT-5, Interface problem (marked resolved) updated; Tasks 16/18/20 append theirs |
| Task 12's `WallGrips` field | Task 12 declares `WallGrips({required LiveTypeOf live}) : _live = live; final LiveTypeOf _live;` | Step 9 `_keptPut`: `live(o)` → `_live(o)`, `layoutInDocument(d, h, live, …)` → `…, _live, …`; doc, note, M-OT-16, Step 1 grep and "Assumed" updated |
| `wall_grips.dart` line refs | compound is `:63-66` (part said `:67-70`); `_seated` is `:113-127` (part said `:113-131`) | corrected |
| `opening_grips.dart` 1-7, 9-39, 40-50, 52-101 (`_Slide.of` at :54,:65,:83), 103-125, 126-182 | correct | — |
| Contract APIs (`titleWordOf`, `gripsFor`, `PropertyField.spec/wordId/value/visible`, Task 2's `range` throwing `ArgumentError`, `commitField(…, words)`) | exist / per Task 2's code | — |
| `PlanController` members (`frozen`, `selection`, `grips`, `toolContext` @internal; `lockHint`, `execute`→bool, `deleteSelection`→bool, `diagnostics`) | exist (`plan_controller.dart:768, 798, 2082, 2107-2127, 2214`) | — |
| Load-time freeze of the poisoned door | `FailureBoundary.probeLoaded` runs `system.drift()` and freezes the failing type's objects (`guard.dart:668-700`) | — |
| `encodePlan`, `validateKitSet` public | yes (barrel) | — |
| Panel keys `property-<id>`, `section-<typeId>` on the `TextField`/`Text` | yes (`plan_property_panel.dart:700-703, 668-688, 826-828`) | — |
| Kit `opening_grips_test` kept imports | **`dart:typed_data` used only by SG4 (`:581-584`, C6)** | removal list gains `dart:typed_data` |
| `opening_support.dart` imports | **`dart:typed_data` unused** (no typed-data use in the copied oracles or helpers) | removed |
| `opening_object_test` copy range | file has 542 lines; part said `:1-563` | → `:1-542` (the whole file) |
| `wall_geometry.dart` `isSimpleCcw` range | doc+body `:600-623` (part `:599-624`); `signedArea` `:554-562` | corrected |
| KJ5 `worldWallOf(doc, hB)` lines | `:356`, `:367` (part `:359`) | corrected |
| A14-grips / A13-live line numbers (object :470; end_drag :143…:702, :578…:764; grips :184…:682) | correct | — |
| `kSnapAperturePixels` = 10 (OT-grips arithmetic: 10 px / 0.5 = 20 mm) | correct | — |
| Mutations M-OT-1..18 | each red-able as named; M-OT-14 targets Task 7's committed `locks.dart` | — |

## Task 15 (opening tools)

| Check | Result | Fix (before → after) |
|---|---|---|
| `opening_tool.dart` lines 1-12, 14-16, 17-39, 41-87, 88-101, `:203/:333/:341` width, `:308` `wallsInDocument`, `:316` `openingsInDocument`, 407-411 dispose, 412-450 | correct (450 lines; `_ownsBands` only at :93/:101/:409, all replaced) | — |
| `PlanTool`/`PlanToolSettings.fieldsOf(value, store, toolId:)`, `settingsOf`, `toolFor`/`servicesOf` (@internal) | exist | — |
| Kit test's kept imports (`dart:math` for HF7, `wall_shell` for `xy`/`walls`) | used | — |
| Test start lines (:346 … :1111) and settings write sites (:559, :759, :771, :824, :879) | correct | — |
| M-OL-6 (drop the band cache's live filter → OL-frozen red) | **would stay green**: the tool's `_frameFor` also asks `wallsInDocument(…, _live)`, so the frozen X still has no frame and the click places nothing; at the crossing `hostAt` returns A (lowest handle, `wall_bands.dart:93-102`) | → a named pair: the band filter dropped **and** `_frameFor`'s live answer forced to wall; red at "a frozen wall hosts nothing"; both files reverted |
| "Assumed": `boxPlanTool` last (W D N G M S I B) | wrong: Tasks 10/12 put `[boxPlanTool, wallPlanTool]` (today's palette order box first, `planner_shell.dart:547-601`) | corrected (OL-tools' `sublist` check holds either way) |

## Task 16 (room tracing, inputs, label; separator params)

| Check | Result | Fix (before → after) |
|---|---|---|
| `separator.dart` 1-120 / 121-149, :4 import, :17 id | correct | — |
| `room_inputs.dart` header :5-6, imports :9-17, class :199-221, `_refresh` :299-314, :327, dispose :358, class end :364, 483 lines | correct except the class block | "Lines 199-223 become …" while also saying :222-223 "follow unchanged" → "Lines 199-221 become" |
| `room_trace.dart` 1111 lines, `room_label.dart` 179 lines, relative imports | correct | — |
| `room_fixture.dart` ranges (imports :10-16, :21-24, addRoom/addSampleRooms/renameRoom, reloadWithPage/staleFile, faceAt :709, probeView) | correct; no other `RoomParams` use in kept lines | — |
| `room_inputs_test` port | **its `separator.dart` import serves only `ensureDashedLinetype` (:142)**, which the kit keeps in `separator_linetype.dart`: undefined name + unused import | row: `:9` import → `package:jet_cad_2d_kit_architecture/src/separator_linetype.dart` |
| Wall place hooks (R-P8) | Task 11 deletes them for sure; part made Step 2 and the commit conditional | Step 2 unconditional (a non-empty grep is a finding); `wall.dart` (with `show placeBoxInView, roomInputInView`) in Files and the commit list |
| R-P19 | the separator must join `type_naming.dart` | Step 7 appends its registration; Files, precondition (Tasks 9-15), commit list |
| RR-live / RR-shared fixture facts (twoRoomWalls partition index 4, areas 29,640,000 and 10,830,000, `placedIn`, `wallNeighboursOf`, `Traced.area`, `generation`) | correct | — |
| `kCertificateMargin = 1` (M-RR-8), `lineweight: 35` (M-RR-6) | exist | — |

## Task 17 (separator grips, tool, plan type)

| Check | Result | Fix (before → after) |
|---|---|---|
| `separator_grips.dart` (113 lines; :5 import, `kept` at :101), `separator_tool.dart` (138; :8 import, `inputs.invalidate()` :85/:115, `_objectSnap(ctx)` :87) | correct | — |
| `separator_tool_test` ranges (:141-194 tool half, :196-223 shell half, :225-349, :351-380 ST4, :381-484; helpers :32-138) | correct | — |
| Kit tests import both `../support/catalog.dart` and `../support/room_fixture.dart` | room_fixture re-exports `testCatalog` (Task 16) → `unnecessary_import` | catalog import removed from `separator_tool_test` and `separator_plan_test` (note added) |
| `SeparatorParams` export | Task 16 exports it definitely; part kept a conditional Step 4.5 and conditional commit path | Step 1 grep expects the hit; Step 4.5 is "unchanged"; Files and commit note cleaned |
| EG8-k copies `wall_grips_test.dart:626-639` | `:629` is `(m as dynamic).handle` → `avoid_dynamic_calls` fails `flutter analyze` in the kit | add `// ignore: avoid_dynamic_calls` above it (assertion unchanged) |
| Kit's tool order at Task 17 = box, wall, door, window, gap, separator (SP-order) | consistent with Tasks 10/12/15 | — |
| `dashed` literal = `kDashedLinetypeRecord` (`separator.dart:128-133`) | identical | — |
| Export APIs (`exportPagePng/Pdf` named params, `ExportDpi`, `PdfContent.parse(…, inflate:)`, `'plan.png'/'plan.pdf'`, `PlanExportChoice(dpi:)`, `omittedOf` early return, font asset key `packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf` declared under `assets:`) | exist | — |
| `PlanController.load` structure for M-SP-8 (`next = decodePlan(...)` in a `try`), `kits.kits` | exist (`plan_controller.dart:387, 671-686`) | — |
| Engine does not validate an entity's linetype handle (SP-dashed-open premise) | no linetype check in `validate.dart` | — |

## Task 18 (room type, grips, properties, colour)

| Check | Result | Fix (before → after) |
|---|---|---|
| `room.dart` imports :15-16, id :39, `colorValue` :51, 470 lines; `room_grips.dart` 176 lines, `RoomGrips({required aperture})` | correct; `PlanSwatch` has today's eight names and rgb values | — |
| `roomAreaText` engine calls (`liveSlots`, `ownerAt`, `kindAt`, `handleAt`, `textAt`, `commands.stateId`) | exist (`entity_store.dart:278-352`, `undo.dart:185`) | — |
| `TextProperty`, `ColourTarget(read:, write:)`, `RoomParams.copyWith(color: null)` clears (sentinel) | correct | — |
| `room_grips_test` copy ranges | **omitted the `for` loop's closing `}` (:615) and `main`'s (:689)** | → ":481-579 … and :615", ":617-689" |
| RN3 adaptation | **cannot pass at Task 18**: built from the plan's bound letters it holds 14 (no M before Task 19, no I before Task 22), failing `containsAll([keyM, keyS])` and `hasLength(16)` | rewritten: today's `kShellLetterKeys` (shortcut_guard.dart:8-25) copied as a test-local const, plus VLPRCAT, the kit's letters and F; both assertions stand unchanged and green from Task 18 on; `keyOf` via `LogicalKeyboardKey.findKeyByKeyId`; line refs fixed (`:234-280`, `:244-248`, fill at `:273`) |
| R-P19 | the room must join `type_naming.dart` | Step 7 appends its registration; Files and commit list |
| `room_cost_test` (imports 7, 9-12, 15 LZ3-only; `debugPlaceBoxCalls`/`debugReadBoxCalls` are the engine's) | correct | — |
| `room_color_test` imports, RC5 `FloorPlanColor` → `PlanSwatch`, RC6 :314 id | correct | — |
| `room_follow_test` (separator.dart still used: 8 `SeparatorParams`; `dragEnd` :139-143; :712-713) | correct | — |
| Mutations M-RM-1..12 | each red-able as named | — |

## Blocking issues I could not fix (outside Tasks 13-18)

1. **R-P19 needs Task 20.** The kit-internal naming list (`lib/src/type_naming.dart`, created in Task 14, appended in 16 and 18) must gain `..register<DimensionParams>(DimensionParams.componentTypeId, DimensionParams.fromJson, const DimensionType())` after the room's, with `import 'dimension/dimension.dart';`, and Task 20's commit list must include the file. Without it a file's group carrying `WallParams` and `DimensionParams` (EG10's shadow) is a wall to the opening's position range while the plan names it a dimension.
2. **Task 21's EG10-k** copies `wall_grips_test.dart:872-875`, whose `:874` is `(m as dynamic).handle as Handle`: `avoid_dynamic_calls` (enabled in the analysis options Task 9 copies) fails `flutter analyze` in the kit. It needs the same `// ignore: avoid_dynamic_calls` line I gave EG8-k.
3. **Name clashes waiting in integration support** (not blocking in 13-18; each file is imported alone there): `opening_support.dart` (Task 14), `room_plans.dart` (Task 18) and Task 12's `wall_shell.dart` each declare top-level `select`/`dragWorld`/`undoKey` (and `gridStep`/`gridOf`); Task 17's `separator_plans.dart` declares `addWall`/`boxWalls` that clash with Task 12's `wall_fixture.dart`/Task 18's `room_plans.dart`. Any later test (19, 26-28) importing two of them needs `hide`/`show`.
4. Not verified by reading (needs a run): SP-export-png's byte-equality between `exportPagePng(…, omitOwners:)` and the plan's PNG exporter; the paint-test camera turn (R14-6's RD1 now turned 0.35 rad by the rig). Both are flagged in the parts as findings-if-they-differ.

Edits made: 51 (Task 13: 4, Task 14: 24, Task 15: 2, Task 16: 8, Task 17: 7, Task 18: 6).
