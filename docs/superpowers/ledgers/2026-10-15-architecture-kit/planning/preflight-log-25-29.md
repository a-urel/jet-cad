# Pre-flight log: Tasks 25-29

Checked against the worktree at `c6bcce3e` (packages `jet_cad_floor_plan`, `apps/floor_planner`, `jet_cad_2d_plan`, `jet_cad_2d_kit`, `jet_cad_2d`, `jet_cad_2d_flutter`), the plan skeleton, `task-scopes.md` (R-P1..R-P19), `reconcile-log.md` (not redone) and the earlier task parts by grep. No repository file touched; no state-changing git command run. Originals kept at `../preflight-backup-25-29/`. All edits applied by exact-match replacement (each string matched once).

Line references below are `file:line` of today's code.

## Task 25: The sample flat

| Check | Result | Fix (before → after) |
|---|---|---|
| `startup_plan.dart` citations (:47-51 clamp, :53-63 constants, :70-255 build, :76 prepare, :82/:252 system, :84-198 walls..separator, :207-210 page, :214-220 rooms, :222-247 dims, :253 clearHistory, :257-267 `startupPage`, :269-422 `_Pen`) | all exact | — |
| `_Pen` and the build use only `jet_cad_2d` names (`addDraftedRegion`, `rectanglePayload`, `polylinePayload`, `circlePayload` in `drafting.dart:69-123`, exported) | ok: `jet_cad_2d_flutter` import may be dropped | — |
| `sample_flat.dart` imports both `../dimension/dimension.dart` and `../dimension/dimension_geometry.dart` | **defect**: `dimension.dart` re-exports geometry (today's `dimension.dart:24`, Task 20 keeps it) → `unnecessary_import` warning fails `flutter analyze` | geometry import removed, reason added to the parenthetical |
| `startup_plan_test.dart` (811 lines): 14 cases; 12 to kit, :119-133 and :135-158 to integration; `wallExtents` :53-61; SP5 :429/:579; SP9 :680-682; SP6 :732-739 | exact | — |
| Kit test helper: `PlanType.registerInto` (`plan_type.dart:79`), `registerKitComponents` (barrel), `PlanKit.prepare` (Task 5), `KitNamesWords(names, locale, {decimalSeparator})` (Task 3), `PageComponent.register`, `ParametricSystem..install` | all exist / produced earlier | — |
| "Document made as the plan library makes one" | inexact: the plan also registers unit components (`plan_controller.dart:374-379`) and attaches the default page before build (`new_plan.dart:15-18, 29-30`) | Plan decision now names both differences (neither read by a ported case; SF-controller runs the real path) |
| Fixture helpers `probeView`, `labelsOf`, `anchorOf`, `labelStrings` (`room_fixture.dart:311, 582, 624, 700`), `dimText`, `dimLines`, `dimTextGeometry` (`dimension_fixture.dart:402, 408, 426`) ported by Tasks 16/18/20 | ok | — |
| `DimensionType` `const` (Task 21 `parametric: const DimensionType()`) | ok | — |
| SF-words values: German names `strings_de.dart:426-441` in handle order; '22,00 m²' (`room_label.dart:163-179` uses the page separator); '14,00' (`dimension_geometry.dart:463-473`) | consistent | — |
| Integration test: `kPlanMinScale/kPlanMaxScale` exported (`jet_cad_2d_plan.dart:11`, values = today's); `canUndo`, `dirty`, `diagnostics` exist (`plan_controller.dart:1793, 584, 2214`); local `kPlanOriginX` does not clash; `ViewportTransform` import needed (plan barrel re-exports only `SymbolThumbnails` from the Flutter layer) | ok | — |
| Step 3 "if the pubspec lacks jet_cad_2d…" | moot: Task 9's pubspec lists them | conditional → "already listed; if not, a Task 9 finding" |
| Step 9 "(add … the root `pubspec.lock` only if …)" | root `pubspec.lock` is not tracked (`git ls-files`) | → "(No pubspec changes in this task; the root pubspec.lock is not tracked.)" |
| WR9 Step 2b vs Task 11's placeholder (`task-11.md:111-112`) and today's `wall_regen_test.dart:497-501` | matches; assertion unchanged | — |
| Commit lists all 6 files; Commit before Mutation | ok | — |
| Mutations M-SF1..5: each targets a committed file, compiles (dead branch / unused private fn only warn), names a red test (SF-words, SP2, the page case, SF-controller) | ok | — |
| Gates: kit, integration `--enable-vmservice`, `check_kit_deps` | ok | — |
| Kit test names no `jet_cad_2d_plan` | ok | — |

## Task 26: Canvas, tools, layers, shell rows

| Check | Result | Fix (before → after) |
|---|---|---|
| `plans.dart` imports | **defect**: `flutter_test` unused (error); `editor_rig.dart show kitCatalog` and `wall_fixture.dart` unnecessary (room_plans re-exports them, `task-18.md` Step 9) → analyze fails | both removed with a comment; flutter_test removed |
| `dimension_fixture.dart` ranges `:36-41`/`:38-41`, `:101`, `:373-411`, `:408-440` | off (overlapping; `:408-440` would copy `dimTextGeometry` and the oracle header) | → `:34-40`, `:99-101`, `:368-403`, `:405-422` |
| `room_fixture.dart:165-194`, `:550-579` | off by a few lines | → `:162-192`, `:551-579` |
| `buildPlan` body vs `room_fixture.dart:124-160` | faithful (but `_groupFor`→`groupFor`) | — |
| `unit_fixtures.dart` (`entryOf :125-170`, `placeAt :273-283`, `addLayer :301-315`), `symbol_fixtures.dart:57-70`, `unit_label.dart:55-75, 134-186`, contract's `kUnitLabelTag`, `kUnitLabelTextAttrs`, `unitLabelHeight`, `unitLabelPayload` (public, `jet_cad_2d_kit/lib/src/kit/unit_label.dart`), `SymbolLibrarySource(label:, read:)`, `encodeLibrary(Catalog)` | ok | — |
| `unit_editor_fixture.dart`: `:184-226` copies `unitsIn`'s start; `:221-236`; `:238-263` includes `press` | off | → copy `:182-221`; drop `:223-235`; copy `:237-254` and `:262-263` |
| `editorColumnCorner` at `host/editor_fixture.dart:118-121` | wrong (it is `:109`) | → `:109` |
| `units_only_select_test.dart:28-124`, `:58`, `:69`; `plan_shortcuts_test.dart:58-133`, `:141-142` | exact | — |
| `layer_fixture.dart` ranges (LayerDoc, onLayer/addObjectOn, layerDoc, addWallsOn, layerFixture, addLineOn, addRegionOn, addSymbolOn, layerOf.., toolContextOf..) | all off by 1-5 lines, two overlapping | → `:30-48`, `:50-77`, `:79-109`, `:111-129`, `:131-161`, `:163-177`, `:179-209`, `:211-249`, `:251-262`, `:264-303` (both steps 6 and 7) |
| app `layer_picker_test.dart` `PickerDoc :34-61` | off | → `:33-65`; `:352-401`, `:179-181` ok |
| `tools_layer_test` placer case `:217-244` (both mentions), `onB :64-69` | wrong (`:230-256`, `:68-74`) | fixed |
| placer port (IT-R10) key order: R/M pressed with no canvas focus; M is the Room tool's letter | **risk**: keys may not reach the armed tool | focus the canvas first (with Select active), then arm, then R/M (armed `plan.symbol` takes R and M, `plan_symbol_tool.dart:383-410`); `entry.leaves.length` → `PlanSymbol.entry.leaves.length` |
| `opening_host_layer_test` `:18-19`, `:113/:120/:124` | off | → `:21-22`; `:103, :105, :111, :113` |
| `attach_layer_test` `:46-47`, `:121-122` | off | → `:40-41`, `:124-125` |
| `touch_tools_test` `finger, pinch (:37-62)` | off | → `:37-38`, `:51-66` |
| `planner_shell_test` cases `:335-357`, `:361-460`, `:462-478`; helpers `:19-82`; `dimensionsOn :47-55`; `pumpSample :86-92` | wrong (cases are `:263-285`, `:289-387`, `:389-478`) | fixed all |
| `planner_grips_test` ranges; `selectLine` (:102-106, used by 4 cases) not mentioned | off / missing helper | ranges fixed; `selectLine` added (view → c) |
| `editor_panels_test` R-3 case `:614-631` | **wrong case** (`:614-631` is the tablesOnly rotate case; R-3 changeLayer/reshape is `:633-653`) | → `:633-653`; `t.byKey` mapping added |
| `keyboard_focus_test` cases (`:436-465`, `:566-613`, `:659-681`, `:910-940`) | exact; `entitiesByHandle :206-213` wrong | → `:176-187` (with `jsonEncode`) |
| `table_data_test` (`rig :45-55`, `:68-70`, `hostData :24-28`) | ok; `opening_fixture.dart:57-67` wrong | → `:134-145`; `:149-154` → `:147-154` |
| `palette_draw_test` A12b `:220-276` (starts inside the previous case); `canvas_fixture.dart:400-424` | off | → `:234-276`; `:383-409` |
| `dimension_shell_test` helpers `:110-193` omit `pinCamera` (used 4 times) and the sample helpers; `pumpShell :86-95` | missing / off | → `pinCamera` … `:95-202`, `wallsOf`, `dimsOf`, `sampleValues`, `childrenOf` `:62-80`; `pumpShell :82-93` |
| `room_paint_test` (`outlines` is `@internal`, `plan_controller.dart:2117`; `debugWorldSegmentsOf` public on `OutlineCache`) | ok (R-P9 ignore present) | — |
| `PlanEditor(layerPanel:)`, `ToolController.context.grips` (`tool.dart:106, 165`), `InteractionLayer.tools` | exist | — |
| IT-letters/IT-ids/IT-guard: Escape → Select (`plan_shortcuts.dart:178-182`), `planLetterKeys`/`PlanToolEntry.kitId`, `.key` (`tool_letters.dart:19-49`) | ok | — |
| Step 10 imports: `drawPlanJson` needs `FlutterTextMeasurer` | missing | `show FlutterTextMeasurer, SelectionKey` |
| M-IT-7 (delete flip-hinge's `visible:`) | **would stay green**: C1.7 still hides the action under `reshape: false` by its gate | → delete flip-hinge's `gate: PlanGate.reshape` (T5-f red: found under `reshape: false`) |
| M-IT-8 edit vague | — | exact: Task 5's `if (made) _prepare(document);` → `_prepare(document);` |
| M-IT-1..6, 9: targets exist in Tasks 12, 15, 19 (`letter: 'W'`, `tools:` order, `gate: PlanGate.reshape` on thickness, ObjectLayer in room/opening creation `room_tool.dart:233`, `isUsableHost :447-450`) | ok | — |
| Analyzer: support files re-export one another (e.g. kit `layer_fixture.dart`'s `wall_fixture.dart show testCatalog, installParametric` beside `dimension_fixture.dart`) | **risk**: `unnecessary_import` warnings fail analyze | Step 13 gains a bullet: drop imports flagged `unnecessary_import` as `unused_import` |
| Commit list vs Files; Commit before Mutation; R-P9 ignore only in room_paint; no `src/` import in integration; kit tests name no plan | ok | — |
| D-48 table: every named test exists in some task part | ok | — |

## Task 27: Panels and words

| Check | Result | Fix (before → after) |
|---|---|---|
| IP-R2 lines `:383-384`, `:382`, `:386-389`, WS6 `:416-449` | wrong | → `:396-397` (and WS10 `:754`, `:776`), `:395`, `:399-403`, `:499-523` |
| IP-R3 lines `:187`, `:189`, `:191`, `:192` | off by 3 | → `:184`, `:186`, `:187`, `:188` |
| q0 fixture `:28-79`/`:28-49`/`:28-80` (28-36 are imports) | off | → `:37-80`, `:37-54`, `:37-80` |
| `rooms_plan.dart` imports `vector_math` unused | **defect** (`unused_import: error`) | removed; source range `:72-110` → `:76-113` |
| Step 3 "header comment `:1-26`" (the file has none; `:1-19` imports), paragraph `:43-46` | wrong | → paragraph `:45-47` as header |
| Step 3 WS ranges `:328-760` and "`:982-1035`'s WS11" (that is SE15/SE16; WS11 is `:847-873`), WS7 (Box) `:387-414` | **wrong** | → `:327-783` (WS1-WS10), WS11 `:847-873`, WS7 (Box) `:624-652` out |
| finders, `wa`.., `panelDoc`, `pumpPanel`, camera, `select`, `clickWorld`, `enterAndSubmit` ranges | off | fixed (`:26-43`, `:49-55`, `:57-89` with the exact dropped lines, `:91-109`, `:99-106`, `:111-115`, `:117-124`, `:134-139`) |
| SE13/15/16 W lines `:960-961`, `:1005-1006`, `:1032-1033`; 2a's `selection_page_test.dart` B lines | exact | `panel_kits.dart:510-524` → `:507-528`; `canvas_fixture.dart:439-450` → `:427-446` |
| colour picker helpers `:43-71`, `:73-79, :162-260` (would copy the table editor's `Caps`, `mountEditor` `:241-311`), Rig `:117-160`, camera `:146-154` | wrong | → `:45-72`; `:74`, `:178-239`; `:115-177`; `:145-151` |
| `kRoomTintTransparency = 229` source | `room.dart:125` (not `room_paint_test.dart:44`) | comment fixed |
| decimal_separator Q0-S `:207-266`, Q0-E `:268-336`, helpers `:81-205` | off by ~10 | → `:195-246`; `:248-276`, `:278-285`, `:287-303`, `:305-312`; `:82-193` |
| NS3 code: premise controller not disposed (text said it is); title not the source's | inconsistent | premise controller with `addTearDown`; title = `new_plan_separator_test.dart:286-287`'s |
| `overflow_test` `furnishedPlan :66-80`; `value_words_test` `expectWorded :27-38` | off | → `:70-80`; `:28-39` |
| `recording_plan_strings.dart` imports → barrel (`PlanStrings`, `UnitLabelProblem`, `UnitLabelWarning` exported, `jet_cad_2d_plan.dart:59, 95-97`); `PlanStrings.of` (`strings.dart:25`); `KitNames.words` (`kit_names.dart:25`); section title `Text` keyed `section-<type>` (`plan_property_panel.dart:827-828`) | ok | — |
| LK2 template RegExp escaping | correct (`RegExp.escape` → `\{name\}` matched by `\\\{[a-z]+\\\}`) | — |
| Mutations M-IP-1..7 (title hook, `_flipSwing`, `visible:`, strict write, `colour:`, notice separator, `tr.dart` template) | each red as named | — |
| Commit list vs Files; Commit before Mutation; R-P1 grep; non-ASCII grep | ok | — |

## Task 28: Wall attachment end to end, R-16, paint invariant

| Check | Result | Fix (before → after) |
|---|---|---|
| `attach_plans.dart` imports `kSnapAperturePixels` from `jet_cad_2d_flutter` | **defect**: it is the engine's (`jet_cad_2d/lib/src/index/drag_snap.dart:14`, exported by `jet_cad_2d.dart:55`), so the `show` names nothing → unused import error | Flutter import removed |
| `attach_plans.dart` uses `PlanController`, `PlanSymbol` (`armable`) with no plan import | **defect** (compile error) | `jet_cad_2d_plan.dart show PlanController, PlanSymbol` added |
| Files list omits `units.dart` and `editor_fixture.dart`, which Steps 5 and 7 modify and Step 13 commits | inconsistent | "Modify (Task 26's)" line added |
| D-02 "13 cases" while Step 6 drops one (premise impossible) | inconsistent | → "12 of its 13" (Files, Appendix rows, C7 table) |
| `notifications :1527`, `faces :1497` | off | → `:1518-1520`, `:1628-1636`; `:1499` |
| `symbol_move_test` (`:31-49`, `:51-118`, `:79-84`, `:72-75`, `:89-90`, `:167`, `:191-195`) | off | → `:33-54`, `:55-141` (with `scene`), `:82-84`, `:73-75`, `:86-87`, `:165`, `:194-197` |
| `gridSnapOff :84-89` | off | → `:78-83` |
| `wall_attach_test` (:32-33, :102-105, :117-121, 23 cases), `wall_attach_property_test :243`, `select_rig` 91 lines, `kAttachPixels = 16.0` (`plan_symbol_tool.dart:44`), `AttachmentQuery` fields, `WallBands(LiveTypeOf)` (Task 11), `placeEntry` (Task 23), `PlanSymbol.component`/`.entry` | ok | — |
| `editor_tools_review_test` `:199-231`, `:413-446`, `:448-475`; `symbol_search_test` groups; `symbol_box_test :321-339, :391-410`; CZ1 `:559-586`; `table_fill_test` `:86`, `:185`, `:209`, `:251`, `:542`, `:587`; `zone_fixture.dart:81-90` | exact | — |
| `framingFor`, `pageFlows` `@internal` / public (`plan_controller.dart:2474`, `:417`); `export`, `fitToUnits`, `setUnitColour` exist; `unit-colour-layer` key (`plan_canvas.dart:397`) | ok | — |
| IA-alloc vs 2a's CV-alloc (`canvas_paint_allocation_test.dart:40-128`) | same harness; `c.selection` → `c.activeSelection` | — |
| Mutations: IA-alloc (new test) has M-IA-alloc; M-IA-1..5 on ported cases | ok (M-IA-3's red on SS16 is the writer's reading of D-06; not provable statically) | — |
| Commit before Mutation; R-P9 ignore files named in Step 12 | ok | — |

## Task 29: Exit gate

| Check | Result | Fix (before → after) |
|---|---|---|
| CHANGELOG headings (`jet_cad_2d_kit` `## 0.1.0`; plan `## 0.8.0 (unreleased)`); versions 0.1.0 / 0.8.0 | exact | — |
| "Tasks 1-7's 'CHANGELOG: Task 29'" | true (`task-01..07.md`) | — |
| Contract spec heading `## Amendments from sub-project 3a` (Task 1 writes `(2026-10-15)` after it; the sed pattern matches); umbrella `## Amendments` at `:512`; 2a/2b spec filenames | exact | — |
| `check_kit_deps` output wording (`check_kit_deps.dart:39-42`) and count 2 (contract + `jet_cad_2d_kit_*`, `kit_deps.dart:9-15`) | exact | — |
| `ci.yml:117-163` for `ci-tools`; the step omits the job's Format, probe-format and readme-probe analyze steps while claiming "as CI runs it" | off / incomplete | → `:120-169`; the three commands added |
| "spec A.2's list, 58 files" | **wrong**: the list names 54 (2+7+13+2+16+14) | → 54 with the breakdown |
| `unit_fill_test.dart:535` keeps `hasLength(5)` | true (`:535`) | — |
| `STATUS.md` "In flight" `:388`, "Resume here" `:584`, the "Next: sub-project 3" sentence `:594` | exact | — |
| Commit list; no code; no Mutation step (no code) | ok | — |

## Blocking issues I could not fix

None blocking. For the controller:

1. **SE11 and SE12's Wall lines are owed by no task.** Today's `selection_panel_test.dart:923-924` (SE11) and `:938-939` (SE12) press W and expect `'Wall'`; 2a's port replaced them with B/`'Box'` (`jet_cad_2d_plan/test/panels/selection_panel_test.dart:396-397, :411-412`), exactly as it did for SE13/15/16. The spec's D-20 row (`2026-10-15-architecture-kit-design.md:776`) names only SE13, SE15, SE16, so Task 27 restores only those. Either the spec row is incomplete or SE11/SE12 were ruled differently; the same two-line restoration as Task 27 Step 4 would close them.
2. **Task 26's placer port (IT-R10)** places on layer B, which is **locked** (`layer_fixture.dart:105`). Today's case executed `placeSymbol` directly; through `plan.symbol` and the plan's `execute`, a refusal on a locked current layer is possible. I found no lock check on a new node in `plan_symbol_tool.dart`, but did not trace `execute`'s lock path end to end: if the click commits nothing, that is a finding for the controller (the case's assertions are not to change).
3. **Uncertain mutation reds (not provable by reading):** Task 26's M-IT-9 (TD1 red relies on a seed outside every wall dissolving the room, `room.dart:265`), Task 28's M-IA-3 (SS16 red relies on D-06's stateId being what catches the second placement). The implementer reports if either stays green.
4. **Spec C3.7 says `text:architecture.sample.*`** while the skeleton's word table (binding) and Tasks 9/25 use `sample-*`. Tasks follow the skeleton; the spec line may need the same spelling.

## Edits made

Task 25: 4. Task 26: 41 (38 + 2 range corrections + the Step 13 bullet). Task 27: 34. Task 28: 15. Task 29: 3. **Total: 97 replacements** across the five part files (each exact-match, once).

## Coordinator's decisions applied (after the first report)

| Decision | Edit (before → after) |
|---|---|
| (1) SE11, SE12's Wall lines restored in Task 27 | Files: `selection_page_test.dart` (SE13, SE15, SE16 …) → (SE11, SE12, SE13, SE15, SE16 …); D-20 row gains SE11's and SE12's lines (`selection_panel_test.dart:923-924`, `:938-939`; 2a's B stand-ins at `jet_cad_2d_plan/test/panels/selection_panel_test.dart:396-397, :411-412`); C7 table gains a row for 2a's `selection_panel_test.dart` SE11, SE12; Step 4 title and header comment name SE11, SE12; Step 4 gains a bullet: copy 2a's SE11 (`:384-398`) and SE12 (`:400-413`) with `panelTitle` (`:84-86`) into the integration file, same mapping as SE13 (its `pumpBoxes`, `typeWidthThenHeight`, `sizeOf`, canvas_rig's `press`, `status`, `canvasFocus`), assertions unchanged, then the source's W/`'Wall'` pair after each B/`'Box'` pair. 6 replacements. |
| (2) Placer case on locked layer B (Task 26 Step 9.7) | after the IT-R10 ruling line: "Layer B is locked (`layer_fixture.dart:105`). If `plan.symbol` or the controller's `execute` refuses the placement … that is a finding: stop and report it with the red line; do not change the assertion." 1 replacement. |
| (3) M-IT-9, M-IA-3 | each line ends "If it stays green, report it (do not change TD1 / SS16)." 2 replacements. |
| (4) `sample-*` spelling | none (the coordinator amends the spec). |

Edits after the first report: 9. **Running total: 106 replacements.**
