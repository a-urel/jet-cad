# 4a test audit: restaurant symbols + restaurant_demo -> jet_cad_2d_kit_restaurant + apps/restaurant_demo

Worktree: `.claude/worktrees/restaurant-kit` (HEAD 8caf8e00). Dispositions: PORT, COVERED (a test found by grep, named), SPLIT, DROPPED.
Path shorthands: **P** = `packages/jet_cad_2d_plan/test`, **K** = `packages/jet_cad_2d_kit/test`, **KA** = `packages/jet_cad_2d_kit_architecture/test`, **I** = `packages/jet_cad_2d_integration/test`, **KR** = the new `packages/jet_cad_2d_kit_restaurant/test`, **APP** = `apps/restaurant_demo/test`.
Case = one `test`/`testWidgets` body (a loop that makes several tests counts once, as the briefing counted: look_test 2, sample_plans_test 1, symbol_names_test 2).
Old-to-new vocabulary used below: table -> unit (label = the number), `FloorPlanController` -> `PlanController`, `FloorPlanMode.selection` -> `PlanMode.service`, `FloorPlanEditor`+`FloorPlanView` -> `PlanEditor` (it shows `PlanServiceView` in service), `tableDetails` -> `unitDetails` (`PlanUnitDetail`, `.unit.label`, `.unit.capacity`, `.center`, `.corners`, `.data`), `tableStatuses` -> `unitStatuses`, `tableGroups` -> `unitGroups`, `tableFocus` -> `unitFocus`, `selectedTables` -> `selectedUnits`, `designJson()` -> `save()`, `serviceLayout` -> `serviceJson()`/`restoreService()`/`resetService()`.

---

## 1. packages/jet_cad_restaurant_symbols/test/restaurant_library_test.dart (23)

All geometry cases keep the hand-written tables (`expected`, `drawnSeats`, `topSizes`, `roundTops`) and move to `KR/library/restaurant_library_test.dart`; the entries are `SymbolEntry` (`e.symbol.key`, `e.unit`, `e.leaves`) as in `KA/furniture/furniture_library_test.dart`. The authoring toolkit pins its helpers (`chairsAround`, `stoolAt`, `stoolsAround`, `rect`, `inset`) in K `authoring/shapes_test.dart` H1-H8; the catalog-level cases below still need porting because they pin which symbol uses which helper with which arguments.

| case | disposition | destination / covering test / reason |
|---|---|---|
| RL1 committed bytes equal the built library | PORT | KR: `encodeLibrary(restaurantCatalog)` == `assets/library/restaurant.jetlib`; add the `conformance(...)` call as `KA/scaffold/words_test.dart` SC-conformance does (code `builtDiffers`). K `authoring/conformance_test.dart` F0b/F1 pin the check on the sample kit only |
| RL2 building twice gives identical bytes | PORT | KR, one line as `KA/furniture/furniture_library_test.dart` "building twice gives identical bytes". K `authoring/builder_test.dart` B1 is the generic builder property, blind to a catalog-side non-determinism |
| RL3 pubspec declares the asset; read under the package key; source name | PORT | KR, shape of `KA/furniture/package_assets_test.dart` (FU-asset-key, PA2, PA3) and `KA/furniture/furniture_library_test.dart` "is declared in the pubspec". Key `packages/jet_cad_2d_kit_restaurant/assets/library/restaurant.jetlib` (decision 2). `restaurantSymbolSource.name` becomes `SymbolLibrarySource(label: 'restaurant')` read through `bundledLibrary(...)` |
| RL4 69 symbols, every key once in order with its category; six categories | PORT | KR: keys stay `restaurant.*`, ids gain `@1` (pattern of `KA` FU-keys); `SymbolLibrary.categories` is first-appearance order (K `model/symbol_library_test.dart` V0c). The merged-categories half of RL15 is separate |
| RL5 the servable symbols and their seats (M-14s-1) | PORT | KR: `entry.seats` becomes `entry.unit` = `UnitComponent(kind: UnitKinds.table, capacity: seats, labelling: numbered)`; 25 units (the briefing's "11" is the 11 helper call sites in `tables.dart` 2, `booths.dart` 6, `bar.dart` 3 that build 25 symbols). Bar stool and the two high bar tables stay kind `table` (decision 3). Refusals of a bad kind/capacity are K `model/unit_component_test.dart` U1 and `symbol_library_test.dart` V1d, V8g |
| RL6 every polyline closed; each symbol its count | PORT | KR, as `KA` "every polyline is closed and each symbol has its closed count" |
| RL7 key lower-case dotted, two tags or more, version 1 | PORT | KR; the key shape and "key under the kit's id" are also conformance (K `conformance_test.dart` F15 notLowerCase, F4 keyOutsideKit), the two-tags and version-1 parts stay |
| RL8 every base point off the origin | PORT | KR, as `KA` "every base point is off the origin" |
| RL9 servable draws its served top first; base point = top centre | PORT | KR. The first-leaf rule for units is also library rule 11 (K `symbol_library_test.dart` V0g, V11a, V11b, V11f) and P `controller/symbol_definition_test.dart` PB-def-top reads the top; "base point is the top's centre" is catalog-specific and stays |
| RL10 each symbol draws its seats one by one where it says so | PORT | KR (`drawnSeats` table). Helper constants K `shapes_test.dart` H1, H3, H5 |
| RL11 no chair > 100, no stool > 40 under its top, no two seats overlap | PORT | KR. Helper level: K `shapes_test.dart` H4 (tucked 100), H6 (stools reach 40) |
| RL16 every chair faces its top (back line 165 away); 80 chairs seen | PORT | KR, keep the `checked == 80` premise. Helper level: K `shapes_test.dart` H3, H4 |
| RL12 a booth's benches stay outside the top beyond the 100 tuck | PORT | KR |
| RL13 each of 69 symbols, quarter-turned and mirrored, validates and covers `at` (off-origin) | PORT | KR through a placement copy: the kit may not import the plan library (`tool/ci/check_kit_deps.dart`) and `placeSymbol` is not exported, so use the `KA/support/place_entry.dart` pattern (no unit label). Plan-level half (a placed unit gets its number in the same step, upright): P `units/unit_placement_test.dart` TP1, P `units/unit_label_stack_test.dart` UL-place-number |
| RL14 each between 100 and 5000 mm on each axis | PORT | KR, same placement copy; `doc.extents` unchanged because the number label is added by the plan, not the copy |
| RL15 furniture and restaurant libraries merge without a clash | SPLIT | -open: a key clash is impossible by construction (a key must sit under its library's kit id: K `symbol_library_test.dart` V5a; conformance F4). Intent (both kits load together: 41 + 69 symbols, categories six + six in kit order, no diagnostic): PORT to APP (`symbols_load_test`): the kit may not name another kit, so not in KR. Library halves COVERED: P `symbols/plan_symbol_loader_test.dart` S-1 (kit order, then source order), S-2 (a duplicate key@N dropped, one symbolDuplicate), K `model/merge_test.dart` M1, M2 |
| RL17 each servable top has its V-6 size and shape | PORT | KR (`topSizes`, `roundTops`) |
| RL18 first seat around a round top sits straight below it (F-4) | PORT | KR. Helper level: K `shapes_test.dart` H4, H6 ("the first straight below", "the first below") |
| RL19 the round booth's bench runs 100 under its top (F-2) | PORT | KR |
| RL20 the corner booth's L bench overlaps its top by 100 per leg (F-2) | PORT | KR |
| RL21 a lounge set's seats stay clear of its low table (F-2) | PORT | KR |
| RL22 the walk-in's door opens out of a gap in its wall (F-7) | PORT | KR |
| RL23 the dessert display's glass bulges 200 in front of it (F-7) | PORT | KR |

Totals: PORT 22, SPLIT 1, COVERED 0, DROPPED 0 (23).

## 2. packages/jet_cad_restaurant_symbols/test/symbol_section_catalog_test.dart (3)

| case | disposition | destination / covering test / reason |
|---|---|---|
| SC1 no servable entry of either library has a size family (R5-3), 30 servable | COVERED | K `model/symbol_library_test.dart` V9a ("a unit whose symbol names a family" is refused by the library, so a restaurant unit cannot have one) and P `panels/symbol_section_test.dart` SW5 ("a table has no Size menu"), SS12. The restaurant count (25 units) is pinned in RL5; the furniture five are plain symbols now (`KA` FU-plain-tables). The hand-written "no restaurant entry has a family" is also true of the asset today (grep: 0 `"family"` in `restaurant.jetlib`) |
| SC2 every against-wall entry has its base point on its box's centre x (V-6) | DROPPED | The restaurant half is vacuous: no restaurant entry carries `against-wall` (0 in `restaurant.jetlib`; the `count > 20` came from the furniture library). The furniture half is `KA/furniture/furniture_library_test.dart` "every base point lies on its box's centre x, exactly (D4 step 5)". Wall attachment is `attachTo` now; the restaurant kit declares none (decision 4) |
| SC3 the real corner booth turned to 37 then mirrored: footprint stays, number upright, one undo each | PORT | The premise is asset-specific and uncovered: KR pins `restaurant.booth.corner@1`'s base point x is not its box's centre x. The behaviour needs the plan library, which a kit cannot import: run it in APP (`corner_booth_test`) through `PlanController` + the Symbol section (rotate/mirror) on the real asset. Intent COVERED on the test kit's corner unit: P `panels/symbol_section_test.dart` SW6 (37 then mirror, label upright, footprint stays, one undo each), SS10 (rotate about the insertion point), SS4 (mirror keeps the footprint) |

Totals: PORT 1, COVERED 1, DROPPED 1 (3).

## 3. packages/jet_cad_restaurant_symbols/test/symbol_names_test.dart (2)

| case | disposition | destination / covering test / reason |
|---|---|---|
| SNL (loop: furniture, restaurant) every key and category in de and tr, none empty, none shared in one category, none left in English | PORT (restaurant) | KR `restaurant_words_test.dart`: `restaurantKit.validate()` empty and `conformance(catalog: restaurantCatalog, committedLibrary:, committedSnapshot:, names: restaurantKit.names, locales: ['de','tr'], sameAsEnglish: {...Bar, Service, WC...})` as `KA/scaffold/words_test.dart` SC-conformance. Conformance pins missing word (K `conformance_test.dart` F11), word equal to English unless allowed (F12), a word for a key/category the catalog lacks (F13), undeclared locale (F14). It does NOT pin "no two entries of one category share a word in one language": keep that loop explicitly. The furniture instantiation is already `KA/scaffold/words_test.dart` SC-conformance (3a), not 4a's |
| SNL the restaurant source carries its names (`source.names same(restaurantSymbolNames)`) | DROPPED | Premise gone: `SymbolLibrarySource(label, read)` carries no names; names live on `PlanKit.names`. Intent (a symbol knows its kit's words in the locale, host words first) COVERED: P `symbols/plan_symbol_loader_test.dart` S-1 ("each symbol knows its kit and words"), P `controller/host_words_test.dart` PB-words-3, K `model/kit_names_test.dart` W2, W3 |

Totals: PORT 1, DROPPED 1 (2).

---

## 4. apps/restaurant_demo/test/demo_test.dart (38)

Every case below is app wiring (areas, log, side panel keys are the demo's own); the library half is named. The seeded fixtures (`salonPlan`, `salonDocument`, `lockedSalonPlan`, `groupPlan`) are rebuilt with a placement helper that adds the unit label (decision 6/11). Camera: `cameraController.value` -> `controller.camera.value` (`PlanCamera`: `.scale`, `.worldToCanvas`) and `centerOn`/`zoomBy`/`panBy`/`fitToView`; screen point of a unit: `controller.worldToGlobal(detail.center)`; hit test: `unitAt(canvasPoint)`.

| case | disposition | destination / covering test / reason |
|---|---|---|
| D1 two empty areas; the toggle switches the view | PORT | APP. Areas Salon/Teras = two `PlanController`s; toggle -> `setMode(PlanMode.service)`; `toolbar-print` is `PlanEditor`'s key (P `editor/plan_editor_test.dart` ED-3); `service-bar` is `PlanServiceView`'s (P `service/view/service_bar_test.dart`); P `editor/editor_service_mode_test.dart` SV-8 (editor in design, service view in service) |
| D2 a seeded plan's tables; selection by number | PORT | APP. `units` -> "1 (4), 2 (6)" from `PlanUnit.label/capacity`; `select({'2'})`/`selectedUnits`; key `table-section` -> `unit-section` (P `panels/unit_section_test.dart` TS1). Library: P `units/unit_api_test.dart` UA-select-design |
| D3 service layout kept across Design and back; only Reset layout drops it | PORT | APP. Demo saves `serviceJson()` on `serviceChanges`, calls `restoreService(json)` after entering service (a restore in design is a StateError), `resetService()` for Reset; `serviceEdited`. Library: P `controller/service_record_controller_test.dart` SR-C16, SR-C17, SR-C18, SR-C20, SR-C19, SR-roundtrip. The log line "layout restored, 1 moved, 0 dropped" from `ServiceRestore.appliedMoves/droppedMoves`; groups now ride the record (decision 8) |
| D4 Save stores the plan in memory; Revert reloads it | PORT | APP. `save()` + `markSaved()`, `load(stored)`; `dirty`; rename by `setUnitLabel('2','12')` (one Label step, P `units/unit_api_test.dart` UA-label-used). Library: P `controller/plan_controller_test.dart` C4, C5, C6 |
| D5 each area keeps its own plan and mode | PORT | APP (pure demo state; one controller per area) |
| D6 tables follow every edit (review F-1); Save disabled while clean | PORT | APP: `controller.revision`/`unitChanges` listener refreshes the line; Save = `!dirty`. Library: P `controller/service_record_controller_test.dart` SR-C14 ("revision moves on every change ... demo review F-1") |
| D7 every numbering warning has its line | PORT | APP: `labelWarnings` (`DuplicateLabel`, `Unlabelled`) worded by `PlanStrings.labelWarning`; English text unchanged ("Number 1 is used by 2 tables", "... has no number"), P `l10n/value_words_test.dart` VW3, VW4. Fixtures change (decision 11): a duplicate needs a raw `SetEntityTextCommand(label, '1', kUnitLabelTag)` because `setUnitLabel` refuses a used label (UA-label-used); there is no `numbered: false` placement, so the unlabelled stool is a stool whose label is removed by command (or a test unit with `UnitLabelling.assigned`, P `units/unit_label_stack_test.dart` UL-assigned) |
| D8 an export is logged with its name and size | PORT | APP: `PlanEditor.onExport(PlanExport)` -> `export.name` ("salon.png") and `bytes.length`; dialog keys are the library's (`export-format`, `export-dpi`, `export-ok`, P `export/export_dialog_test.dart`), the old `export-format-png`/`export-dpi-96` finders are re-derived. Library: P `export/page_flows_test.dart` PF13, PF14 |
| D9 Reset layout shows in the service only and undoes its moves; Fit refits | PORT | APP: Reset button is the demo's, shown only in `PlanMode.service`; `resetService()` also clears groups (decision 8); Fit = `fitToView()`. Library: SR-reset, SR-C17; P `editor/editor_service_view_test.dart` V12, VZ4 |
| D10 Revert with nothing stored empties the area; Teras keeps its own layout | PORT | APP: Revert with no `stored` = `newPlan()`; each area keeps its own `layout` string. Library: P `controller/locale_separator_test.dart` NS8 (newPlan separator), P `controller/plan_controller_test.dart` C5 |
| Dark theme (spec D9): dark platform, demo UI paints without exception; layout kept, no discard dialog | PORT | APP (demo screens, statuses, mode back and forth). Library dark paint: P `canvas/dark_canvas_test.dart`, P `service/view/theme_service_test.dart`, P `service/view/status_caption_test.dart` D6c |
| D11 two numbers, padded, by Enter: both selected, logged sorted | PORT | APP: parsing " 9,2 " and the sorted log are the demo's; `select({'2','9'})`. Rename fixture by `setUnitLabel('1','9')` |
| D12 status buttons set the selected tables' statuses; Free clears them | PORT | APP: `setUnitStatus({label: UnitStatus})`, `unitStatuses`. Library: P `controller/service_state_controller_test.dart` SS-C15 |
| D13 random statuses seeded, replace the previous ones | PORT | APP (the `Random` draw order is the demo's); `setUnitStatus` replaces the whole map (SS-C15) |
| D14 in the service, a tap and a drag are logged by number | PORT | APP: `onUnitTap`, `onLayoutChanged`, `onUnitsMoved`. Library: P `service/service_events_test.dart` SE10 (once per drag), P `service/view/view_events_test.dart` VE8, P `editor/editor_service_view_test.dart` V15 |
| D15 the demo opens on its sample plans: both assets load, every table numbered once | SPLIT | -open: no JSON assets to load (decision 6/7): DROPPED. Intent (Salon units 1..11, Teras 1..6, each numbered once, no label warning) PORT to APP `sample_plans_test` through `buildSalon`/`buildTeras`. Library: P `controller/prepare_build_test.dart` PB6, PB8 (a build fills the plan clean), P `units/unit_label_stack_test.dart` UL-place-number |
| D16 a Revert in the service, and the mode switches, keep the stored layout | PORT | APP: Revert = `load(stored)` then `restoreService(layout)`; log "layout restored, 1 moved, 0 dropped". Library: P `controller/service_record_controller_test.dart` SR-edited-after-load, SR-C16 |
| D17 a right click opens the table's menu; a status chosen there is set | PORT | APP: `onUnitContextMenu(label, globalPosition)` -> the demo's `showMenu`. Library: P `service/view/service_options_test.dart` SO2 |
| D18 with Moves off a drag from a table pans and changes no layout | PORT | APP: Moves toggle -> `PlanPermissions.serviceMove` (not a view parameter any more): `controller.permissions = profile.copyWith(serviceMove: moves)` (decision 9). Library: SO1, P `service/service_tool_units_test.dart` ST-move-gate |
| D19 language switch: demo, planner and a status caption speak Turkish, then German | PORT | APP: demo strings; planner words from `planLocalizationsDelegates`; "Duvar" now comes from the architecture kit's `tool:architecture.wall` tr word (`KA words/tr.dart`). Library: P `editor/editor_words_test.dart` SW1, SW2, LK1 |
| D20 a locked table's menu acts on that table, never on the selection | PORT | APP. Locked layer fixture by raw layer commands (the unit's instance handle is not in `unitDetails`, decision 11). Library: SO2 ("a locked one changes nothing"), P `service/service_tool_test.dart` ST7 |
| D21 a status caption is worded again when the language changes | PORT | APP: `UnitStatus.caption` is a plain string (max 12 graphemes) the library never re-words, so the demo re-applies `setUnitStatus` on a locale change; stays app logic |
| D22 with Long press: menu on, a finger's long press opens the menu, toggles nothing | PORT | APP: `PlanLongPress.contextMenu`. Library: SO4, P `service/view/unit_groups_context_test.dart` TG-CX2 |
| D23 the Floor drag switch flips the view's floorDrag pan to band and back | PORT | APP: `PlanFloorDrag.band`; read it from the `PlanEditor`/`PlanServiceView` widget. Plumbing COVERED by P `editor/editor_service_mode_test.dart` SV-9 (every service option of PlanEditor reaches PlanServiceView); the switch is the demo's |
| D16 G6 Merge makes G1, again grows it; member tap logged as the group's; Bill to the group; drag moves the group; Split drops group and status | PORT | APP: `onMergeRequested(Set<String>)`, `setUnitGroups`, `selectedGroup`, `groupStatuses`, `onGroupTap`; id counter is the demo's. Library: P `service/view/unit_groups_gesture_test.dart` TG-G1, TG-G5; `unit_groups_toolbar_test.dart` TB1, TB3; `controller/unit_groups_controller_test.dart` TG-C5, TG-C8 |
| D17b G6 the next id counts every id's trailing digits | PORT | APP, pure static `DemoHomeState.nextGroupId` test, unchanged |
| D17 G6 new group is G<largest suffix + 1> after a split; a merge across two groups makes a new one; emptied groups go with their statuses | PORT | APP. Library: TG-C4 (group status survives groups change), SS-mixed-group |
| D18 G6 POS-restored group with a locked and a hidden member grows and keeps its label | PORT | APP (`setUnitGroups({'G7': UnitGroup(members:, label:)})`; fixture 8 and 9 on locked/hidden layers by raw layer commands). Library: TG-C7, TG-C13 (`selectableMembers`) |
| D20 G6 R-C5-4: a new-group merge leaves what remains of a POS group under its id and label, drops an emptied one | PORT | APP. Demo's merge rule |
| D21 X2 M-TGF-4: groups set under a live selection holding part of a group make a new group | PORT | APP. Library: TG-C14, TG-C16 |
| D22 X2 M-TGF-6: a group with no selectable member never grows | PORT | APP. Library: TG-C13 |
| D23 X2 M-TGF-7: a grow takes a number from another group, which keeps id, label and status | PORT | APP |
| D24 X2 edge cases from a host: exactly one group's selectable members is a logged no-op grow; an empty request changes nothing | PORT | APP: calls `PlanServiceView.onMergeRequested`/`PlanEditor.onMergeRequested` directly. Library: P `service/view/service_bar_test.dart` M-H44, S-5 |
| D19 G6 under a dark platform: merge, a group status, split paint without exception | PORT | APP. Library: P `service/view/unit_groups_look_test.dart` TG-V1..V6 |
| DQ1 no samples, in German: the shown area's empty plan prints comma, clean, no undo step, no dirty line; Teras too once shown | PORT | APP (slim): the log has no `Salon:` line and Save is disabled. Library halves COVERED: P `controller/locale_separator_test.dart` NS1 (constructor's empty plan, comma, no step, clean), P `editor/editor_separator_test.dart` NS2 (second empty plan shown by the same view in German is comma) |
| DQ2 Revert after a switch to German: nothing stored gets a comma plan; a stored point plan reloads as point (N2) | PORT | APP: Revert = `newPlan()` or `load(stored)`. Library: NS8, NS3 ("a loaded plan is never settled") |
| DZ1 M-Z29: zone B frames 6 and 7, not 1; Fade the others focuses {6, 7}; All clears and fits the page; zone and switch kept per area; Teras has none | PORT | APP: `fitToUnits({'6','7'})`, `setUnitFocus`, zones A=1-5, B=6-7, C=8-11 by label are the demo's; screen corners from `unitDetails.corners` + `worldToGlobal`. Library: P `editor/editor_service_view_test.dart` VZ4, VZ5, VF4, P `controller/service_state_controller_test.dart` SS-CF1, P `controller/service_record_controller_test.dart` SR-CF3 |
| DZ2 the zones' three strings in German and Turkish | PORT | APP (demo strings) |

Totals: PORT 37, SPLIT 1 (D15), COVERED 0, DROPPED 0 (38). (Eight cases carry a COVERED library half; none is covered whole.)

## 5. apps/restaurant_demo/test/host_chrome_test.dart (8)

| case | disposition | destination / covering test / reason |
|---|---|---|
| DH1 Tables: no wall tool, no Layer or Page panel, the Symbols tab; inspector writes the POS id, other data kept; Full shows no inspector | PORT | APP. Tables = `PlanPermissions.unitsOnly` + `layerPanel: false, pagePanel: false` + `symbolFilter: isUnitSymbol`; inspector = `unitInspectorBuilder` writing `setUnitData`. Keys re-derived: `tool-plan.select`, `tool-architecture.wall`, `tab-symbols`, `layers-panel`, `page-preset`. Library: P `editor/unit_inspector_test.dart` M-H45, T6-d, T6-f; P `units/unit_api_test` / `controller/unit_data_test.dart` HD2, HD8; P `editor/editor_options_test.dart` T5-g, RV8 |
| DH2 Read only moves and deletes nothing; its bar shows Print, Export and the zoom; under Full the same drag moves | PORT | APP: `PlanPermissions.readOnly` + `PlanEditorBar(actions: [print, export, zoom])`. Library: P `editor/editor_options_test.dart` T4-j, O23, RV9; P `controller/permissions_controller_test.dart` PM-20 (`deleteSelection`), PM-14 (`selectTool`) |
| DH3 the service bar carries the area's name; Own bar hides it; the demo's Merge, Split, Undo, Redo send what the planner's would | PORT | APP: name in `PlanServiceBar(leading: [Text(..., key: 'bar-area')])`; own bar = `PlanServiceBar(visible: false)` plus a row above the view; own Merge enabled by `controller.mergeCandidate != null`, Split by `selectedGroup`. Library: P `service/view/service_bar_test.dart` M-H44, T2-d, "the service bar: leading before the buttons" |
| DH4 the own export dialog replaces the planner's at Export and its chord, both modes; PNG 300 equals the controller's export; remembered; Cancel exports nothing; own bar asks it too | PORT | APP: `onExportDialog` + `controller.export('plan.png', PlanExportChoice(dpi: d300), name: 'salon')`. `PlanExportChoice` is dpi only; the format is the exporter id (decision 12). Library: P `editor/editor_bar_test.dart` PF6 (dialog at every Export entry point), P `service/view/plan_service_view_test.dart` SV-2, P `export/page_flows_test.dart` PF14 (answer remembered). The own bar's Export cannot reach the remembered answer (`pageFlows` is internal) |
| DH5 a print that fails is logged, from the planner's Print and the own bar's | PORT | APP: `PlanEditor.printer` + `onPageFlowError(Object)` and `controller.print(choice, printer:)` from the own bar; log text "export or print failed (Bad state: jam)" unchanged (the error has no flow kind). Library: P `editor/plan_editor_test.dart` ED-E |
| DH6 the plan's keys off: Delete, Ctrl+Z, Ctrl+Y, Escape are the demo's and call the controller's commands; letters do nothing; a key in the inspector stays the field's | PORT | APP: `shortcuts: false`, demo binds Delete/Ctrl+Z/Ctrl+Y/Escape to `deleteSelection()/undo()/redo()`; `selectTool('architecture.wall')`. Library: P `shortcuts/plan_shortcuts_test.dart` KB-3, P `editor/plan_editor_test.dart` ED-S, P `editor/editor_service_mode_test.dart` SV-12, P `shortcuts/host_text_keys_test.dart` |
| DH7 the search field keeps the focus across a mode switch; with the plan's keys off the view does not take the focus when shown again; Enter selects and centres, field keeps focus | PORT | APP: `PlanEditor.autofocus` replaces "view takes focus only with the plan's keys" (decision 14); centre = `centerOn(detail.center)`, find = `select`. Library: P `shortcuts/plan_shortcuts_test.dart` KB-10, P `service/view/service_keys_test.dart` T6-a, P `controller/camera_test.dart` C-cam1 |
| DH8 the host choices' words in German and Turkish | PORT | APP (demo strings) |

Totals: PORT 8 (8).

## 6. apps/restaurant_demo/test/badges_test.dart (8)

Badges = `PlanEditor.unitOverlayBuilder` + `PlanOverlayLayout(anchor:, size: box?, detailBreakpoints:, hideBelowScale:, interactive: false)`; the builder gets `PlanUnitOverlay` (`detail.unit.capacity` for the seats, `selected`, `focused`, `status`, `detailLevel`). `kBadgeDetailScale` becomes `PlanCamera.scale` against the breakpoint.

| case | disposition | destination / covering test / reason |
|---|---|---|
| DB1 Badges switch: off by default, one badge per numbered table, worked figures by status, minute tick without a build, none again when off | PORT | APP. Library: P `service/view/unit_overlay_test.dart` TO1 (one per labelled unit with geometry), TO5 (status builds that table only), TO15 |
| DB2 badges ride with their tables across pan and zoom, built none; a dot below the breakpoint; a tap on a badge still selects its table | PORT | APP (anchor, dot level, build counters are the demo's). Library: TO1/TO2 (no build on camera change), TO4 (detail crossing builds once), TO7, TO8 (layer ignores pointers) |
| DB3 a zone focus fades the other tables' badges; their selection outlines them | PORT | APP (0.35 opacity and border widths are the demo's). Library: TO6 (`selected`/`focused` follow the controller) |
| DB4 Centre on table 7: canvas centre shows 7's centre, zoom kept | PORT | APP: `centerOn(detail.center)` and `unitAt(canvas centre) == '7'`. Library: P `controller/camera_test.dart` C-cam1, P `controller/unit_detail_test.dart` TA3 |
| DB5 the Teras and the design offer no badges; the switch is kept per area | PORT | APP. Library: P `editor/editor_modes_test.dart` TO13 (not shown in design by default), TO14 |
| DB6 the badges' strings in German and Turkish | PORT | APP (demo strings) |
| DB8 each badge is its own semantics node, named by its table, at its badge | PORT | APP (the `Semantics` label "Table n" is the demo's). Library: TO24 (semantics of the shown overlays) |
| DB7 the figures: free tables seat nobody; each status its minutes | PORT | APP, pure static `DemoHomeState.badgeFigures`, unchanged |

Totals: PORT 8 (8).

## 7. apps/restaurant_demo/test/events_test.dart (10)

Events = `onUnitTap`, `onUnitDoubleTap`, `onUnitsMoved(List<PlanUnitDetail>)`, `onUnitHover(String?)`, `onFloorTap(Offset world)`, `onLayoutChanged`, and the `controller.unitChanges` stream (`PlanUnitAdded/Removed/Changed/PlanUnitsReplaced`).

| case | disposition | destination / covering test / reason |
|---|---|---|
| DE1 Link tables gives each numbered table without an id `<area>-<n>` in one undo step; a shared number is left out; Unlinked counts the POS ids no visible table carries | PORT | APP: `setUnitsData` (one "Unit data" step) and `unitDetails.data['id']`. Fixtures (shared number, hidden layer) by raw commands (decision 11). Library: P `controller/unit_data_test.dart` HD7, HD8, HD11 |
| DE2 the Teras links as teras-<n>; Link tables and Unlinked in the design only | PORT | APP |
| DE3 a saved plan declares schema 10 and keeps its ids across Save and Revert | PORT | APP: `kSchemaVersion` is still 10; the data component is now `jetcad.unit_data` (was `jetcad.table_data`); `save() == stored` byte for byte. Library: P `controller/unit_data_test.dart` HD1 (round trip byte for byte), HD5 |
| DE4 a double click on 7 logs it with its id, after both taps; timed from the stamps; an unlinked table logs no id | PORT | APP: `onUnitDoubleTap(label)`; id from `unitDetails`. Library: P `service/service_events_test.dart` SE1-SE3, P `service/view/view_events_test.dart` VE1, VE3 |
| DE5 a drag logs the moved numbers once, after the layout line; Undo logs no move; an unnumbered table moves as the dash | PORT | APP: `onUnitsMoved` (an unlabelled unit has `label == null`). Library: SE10, VE8 (Undo, Redo, reset, restore never call it), VE9 (unnumbered reported), P `service/service_tool_units_test.dart` ST-unlabelled |
| DE6 the pointer line: over a table, over no table, a floor tap's point in metres; never the log; cleared by reset, mode switch, area switch | PORT | APP: `onUnitHover` (null = no unit; one null also covers leaving the canvas), `onFloorTap(world)`. Library: SE8, SE11, VE6, VE10, VE11 ("a remount sends no null") |
| DE7 designChanges: a table added and removed is logged, undo too; a renumbering is not; Revert logs the replaced plan; in service the kept layout goes back after it | PORT | APP: `unitChanges` listener. Library: P `controller/unit_changes_test.dart` DC3 (renumber is one Changed), DC5, DC8 (`PlanUnitsReplaced`), DC9. The demo decides to log Added/Removed only |
| DE8 the new words in German and Turkish | PORT | APP (demo strings: link, unlinked, pointer line, opened, moved, replaced) |
| DE9 final review F-5: Revert in the design after the service kept a layout logs the replaced plan and restores nothing then; entering the service puts the kept move back | PORT | APP. Library: SR-C19 (a restore in design is a StateError, so the demo restores on entering service) |
| DE10 final review F-3: a double tap on a number two tables carry logs no id on either table; a number on one table logs its id | PORT | APP. Library: SE5 ("another instance sharing the number ... reset the chain"), VE2 (no double tap for two instances sharing a number). The demo's "no id" rule is its own |

Totals: PORT 10 (10).

## 8. apps/restaurant_demo/test/look_test.dart (2)

| case | disposition | destination / covering test / reason |
|---|---|---|
| DL1/DL2 the POS look under a light/dark platform: extension of the app's theme, local Theme scheme on the bar, 52 px bar, surround, 3 px selection, fill at 0.8, 12 px bold Roboto caption; Standard again is today's, byte for byte | PORT | APP: `FloorPlanTheme` -> `PlanTheme` (same 17 fields: `statusCaptionStyle`, `selectionOnLight/OnDark`, `selectionWidth`, `canvasBackground`, `serviceBarHeight`, `statusFillOpacity` ...), `PlanEditor(theme: PlanTheme(selectionWidth: 3))` over `ThemeData(extensions: [...])`; the pixel assertions stay (still `SelectionOverlayPainter`, `PaperPalette` from `jet_cad_2d_flutter`). Library: P `theme/plan_theme_test.dart` TH1, TH13, P `editor/editor_theme_test.dart` ED-7, P `service/view/theme_service_test.dart` ("a full view theme removed at runtime restores today's pixels exactly", serviceBarHeight 60) |
| DL3 the look switch in German and Turkish | PORT | APP (demo strings) |

Totals: PORT 2 (2).

## 9. apps/restaurant_demo/test/sample_plans_test.dart (1)

| case | disposition | destination / covering test / reason |
|---|---|---|
| the committed `salon.json`/`teras.json` equal the built ones (loop over two names; `UPDATE_SAMPLES=1` rewrites) | SPLIT | -open: no committed JSON to compare (plans are code, old JSON unreadable): DROPPED, with `UPDATE_SAMPLES` and the pubspec `assets/plans/*.json`. Intent (the plans are exactly the hand-written placements; units numbered 1-3, 4-5, 6-7, 8-11 in build order; save/load/save byte-stable): PORT to APP `sample_plans_test` over `PlanController(build: buildSalon)`: the `_plan([...])` table of (key, x, y, turns) is written out in the test, not derived. Library: P `controller/prepare_build_test.dart` PB6 (clean, nothing to undo), PB8, KA `sample/sample_flat_test.dart` SP6 (saves, loads, saves again byte for byte) |

Totals: SPLIT 1 (1).

---

## Totals

| file | cases | PORT | COVERED | SPLIT | DROPPED |
|---|---|---|---|---|---|
| restaurant_library_test | 23 | 22 | 0 | 1 | 0 |
| symbol_section_catalog_test | 3 | 1 | 1 | 0 | 1 |
| symbol_names_test | 2 | 1 | 0 | 0 | 1 |
| demo_test | 38 | 37 | 0 | 1 | 0 |
| host_chrome_test | 8 | 8 | 0 | 0 | 0 |
| badges_test | 8 | 8 | 0 | 0 | 0 |
| events_test | 10 | 10 | 0 | 0 | 0 |
| look_test | 2 | 2 | 0 | 0 | 0 |
| sample_plans_test | 1 | 0 | 0 | 1 | 0 |
| **grand total** | **95** | **89** | **1** | **3** | **2** |

By destination: KR (kit) 22 + 1 (SC3 premise) + 1 (SNL) = 24 kit-side ports; APP 65 whole ports + the intent halves of RL15, SC3, D15, sample_plans = 69 app-side. Nothing is left unclassified.

---

## Library facts the dispositions lean on (checked in lib/ and test/)

1. **A kit may not name the plan library or another kit**, in pubspec or imports, tests included (`tool/ci/check_kit_deps.dart`, `kit_deps.dart`: `forbidden` = plan package or another kit package). So KR cannot load `architectureKit`, `PlanController` or `placeSymbol`. `placeSymbol` is not exported by `jet_cad_2d_plan` either (barrel checked): kit tests place through a copy (`KA/support/place_entry.dart`, no unit label); the plan-level placement is `PlanSymbolTool`/`armSymbol` or an app helper.
2. **`PlanBuild` is `void Function(DraftDocument, KitWords)`** (`jet_cad_2d_kit/lib/src/kit/plan_build.dart`); the plan runs every kit's `prepare`, then the build, then clears history and takes the save point (P PB6, PB8). It gets no `PlanServices`, so `symbolDefinition` (async libraries) is unavailable to it; a build that places library symbols must create the definitions itself, synchronously.
3. **Units**: `UnitComponent(kind, capacity, labelling)`; `UnitKinds.table/seat`; library rules: a unit draws a closed polyline or circle first (V11a-f), a unit's symbol has no family (V9a), capacity >= 1 (V1d). A numbered placed unit gets the next free number in the placement step, upright (P TP1, UL-place-number); `UnitLabelling.assigned` gets none (UL-assigned). `kUnitLabelTag = 'UNIT'` and `unitLabelAttrib` are exported by the kit.
4. **`PlanUnitDetail` carries no handle** ("never a handle", `unit_detail.dart`); `setUnitLabel` refuses a label another unit holds (UA-label-used) and a seat's (UA-label-seat). Duplicates, unlabelled units and per-instance layers in fixtures therefore need raw commands on `controller.document` (public).
5. **The service record now carries groups** (SR-roundtrip, SR-groups-replaced: `restoreService` replaces the host's groups; SR-reset: `resetService` clears them in service; SR-edited-after-enter: `serviceEdited` compares groups with those held on entering). `serviceChanges` fires on a move, Undo, Redo, reset, restore and `setUnitGroups` in service, never on `setMode`/`load`/`newPlan`; Undo-then-switch is heard before the switch (SR-C20). `restoreService` in design is a StateError (SR-C19). The old jet_cad.service_layout text is refused (SR-old-format-refused).
6. **Service options are permissions or view parameters**: `PlanPermissions.serviceMove`/`serviceMerge` (SO1, ST-move-gate, SV-4), `PlanLongPress`, `PlanFloorDrag`, `userCamera`, `shortcuts`, `autofocus`, `onUnitContextMenu`, `onUnitHover`, `onFloorTap`, `onUnitsMoved`, `onUnitDoubleTap`, `onGroupTap`, `onMergeRequested`, `onSplitRequested`; `PlanEditor` forwards every one (SV-9). Merge/Split buttons need their callbacks and `serviceMerge` (TB5, SV-4). `mergeCandidate` and `selectedGroup` are public `ValueListenable`s (M-H44, T2-d).
7. **Page flows**: `PlanExportChoice` is `dpi` only; exporters are registry entries by id (`plan.pdf`, `plan.png`, then the host's); `controller.export(id, choice, {name})` and `controller.print(choice, {printer, name})` are public and ungated by permissions; `PlanExport` is `(bytes, name, mimeType)`; `onPageFlowError(Object)` has no flow kind; `pageFlows` is `@internal` (so a host's own bar cannot reuse the flows' remembered dialog answer, PF14).
8. **`PlanServiceBar`**: `visible`, `actions` (undo, redo, merge, split, export, print), `leading`, `trailing` (bounded width; a host text field there keeps Undo/Redo, T2-b, R-5). No area-name concept. `PlanEditorBar` actions: export, print, undo, redo, snap, zoom.
9. **Keys**: the library's keys are `toolbar-<id>`, `service-undo|redo|merge|split|export|print`, `service-bar`, `tool-<toolId>` (`tool-plan.select`, `tool-architecture.wall`), `tab-tools`, `tab-symbols`, `layers-panel`, `page-preset`, `unit-section`, `unit-inspector`, `zoom-text`, `osnap-text`, `export-dialog|format|dpi|ok|cancel`. The demo's `tool-wall`, `tool-select`, `table-section`, `export-format-png`, `export-dpi-96` are renamed.
10. **Overlays**: `PlanUnitOverlay(detail, selected, focused, status, detailLevel)`, `PlanOverlayLayout(anchor, size, maxNaturalSize, hideBelowScale, detailBreakpoints, interactive)`, shown in `unitOverlayModes` (default service only; TO13).
11. **Camera**: `controller.camera` is a `ValueListenable<PlanCamera>` (`scale`, `worldToCanvas`, `screenToWorld`); `centerOn(world, {scale})`, `panBy`, `zoomBy`, `fitToView`, `fitToUnits(labels)`; `canvasRect`, `worldToGlobal`, `globalToWorld`, `unitAt(canvasPoint, {kind})`.
12. **Theme**: `PlanTheme` has the same seventeen fields as `FloorPlanTheme`; `theme:` on `PlanEditor`/`PlanServiceView` merges over `ThemeData(extensions:)` (TH1, ED-7).
13. **Unchanged under the new schema**: `kSchemaVersion` is 10 (`jet_cad_2d/lib/src/codec/schema_version.dart`); a saved plan now carries a `jetcad.manifest` component (`kPlanFormat` 1) and the host data component is `jetcad.unit_data`.
14. **Warning words survive**: "Number 1 is used by 2 tables", "A table with 4 seats has no number" (`PlanStringsEn.labelWarning`, VW3).
15. **Restaurant asset today**: 69 symbols, 25 with `seats`, 0 `against-wall` tags, 0 families (grep of `restaurant.jetlib`).

## Decisions the 4a spec must take

1. **Where the cross-kit and plan-level tests live.** KR can hold only pure-kit tests (catalog, asset, snapshot, words, conformance, placement via a copied helper). Merge-with-architecture (RL15), the corner-booth Symbol-section scenario (SC3) and anything that arms a symbol go to APP (or `I`). Also decide whether the placement helper is copied into KR (as `KA/support/place_entry.dart`) or exported from the kit's `testing.dart`.
2. **Kit and asset names**: kit id `restaurant`, package `jet_cad_2d_kit_restaurant`, asset key `packages/jet_cad_2d_kit_restaurant/assets/library/restaurant.jetlib` plus `restaurant.snapshot.json`; keys stay `restaurant.*`, version 1 (so ids `restaurant.x@1`); generator `tool/generate_restaurant_library.dart`. State that the old `restaurant.jetlib` bytes are not reused (handles/format).
3. **Unit kinds**: all 25 servable symbols become kind `table` (including `bar.stool`, `bar.table.high.*`, booths, banquettes, lounge sets), capacity = old `seats`, labelling numbered. The briefing's "11" is the 11 helper call sites, not 11 symbols: say so. Confirm the Salon sample keeps stools as numbered tables 8-11 (zone C).
4. **Wall attachment (`attachTo`)**: none of the 69 had `against-wall`; confirm the kit declares no `attachTo`. If kitchen equipment should later attach, the kit alone raises `attachmentKindUnoffered` unless the architecture kit is loaded (P AT-16).
5. **Names and conformance**: de/tr words for 69 symbols and 6 categories in `restaurantNames`, `sameAsEnglish` for `Bar`, `Service`, `WC`; keep the category-uniqueness loop (conformance does not check it); the restaurant kit has no types/tools, so `typeIds/toolIds/propertyIds` are empty in its conformance call.
6. **Sample plans as code**: `buildSalon`/`buildTeras` get only `(DraftDocument, KitWords)`. They must instantiate definitions synchronously (decode `encodeLibrary(restaurantCatalog)`), place turned instances and add the unit label (`unitLabelAttrib`) in build order so numbers run 1-3, 4-5, 6-7, 8-11 (handle order). Decide: build functions in the demo's `lib/` or exported by the kit (the architecture kit exports `buildSampleFlat`); positions relative to the default sheet; whether demo tests share one placement helper with these builds.
7. **Old data is dropped**: delete `assets/plans/*.json`, their pubspec entries and the `UPDATE_SAMPLES` path; `DemoHomeState.stored` holds `controller.save()` text (manifest included). No reader for old JSON or `jetcad.table_data`.
8. **Service layout and groups**: `serviceJson()` now includes groups and `restoreService` replaces the host's groups, `resetService` clears them, and merging in service counts as `serviceEdited`. Decide the demo's Reset layout semantics (it now also splits all groups), whether the "layout restored, N moved, M dropped" log mentions groups (`ServiceRestore.appliedGroups/droppedGroups`), and where the demo stores the layout (`serviceChanges` listener, restore after each entry to service).
9. **Permissions**: one `PlanPermissions` value composes the editor profile (Full/Tables = `unitsOnly` + `layerPanel/pagePanel: false` + `symbolFilter: isUnitSymbol` / Read only = `readOnly` with `PlanEditorBar(actions: [print, export, zoom])`) and the Moves switch (`serviceMove`). State the composition rule and that `readOnly` keeps the service flags.
10. **Kit set and gallery**: the demo loads `[architectureKit, restaurantKit]` (kit order = gallery order, S-1); the Full profile therefore shows the architecture tools (`tool-architecture.wall`) and furniture, Tables hides them. Confirm the Tables profile's gallery shows only restaurant units.
11. **Test fixtures without old helpers**: `numbered: false` placement and `TableSurvey` are gone; `unitDetails` has no handle. Specify the fixture route for duplicate numbers, unlabelled units, locked and hidden layers (raw commands on `controller.document` + a label/instance finder in test support, or an `assigned` unit kind in a test kit).
12. **Export**: choice is dpi only and the format is the exporter id; rewrite DH4/D8 expectations (`plan.png`, `salon.png`). Decide whether the demo's own bar reuses `showPlanExportDialog` + `controller.export` and whether it keeps its own remembered answer (the flows' one is internal).
13. **Area name in the service bar**: `PlanServiceBar(leading: [...])` with a bounded width, key `bar-area` kept; the planner no longer prints it.
14. **Keys and focus**: "Plan's keys" switch = `PlanEditor.shortcuts` (+ `autofocus`); with it off the demo binds Delete/Ctrl+Z/Ctrl+Y/Escape to `deleteSelection()/undo()/redo()`; confirm the search field focus behaviour (DH7) is expressed with `autofocus`.
15. **Status captions**: `UnitStatus.caption` is a plain string, cut to 12 graphemes; the library never re-words it, so the demo's re-apply on language change stays (D21). Confirm the German/Turkish captions fit 12.
16. **Look and strings**: `FloorPlanTheme` -> `PlanTheme` in `demo_theme.dart`; the POS look is unchanged in values. Demo strings (`demo_strings.dart`, ~900 lines) keep their own table; the planner's words now come from `PlanStrings` and the kits.
17. **Pointer line semantics**: `onUnitHover(null)` is both "over the floor" and "left the canvas"; the demo's "over no table" wording stays for both unless the spec asks otherwise (DE6 asserts only the floor case).
18. **Version/release**: `apps/restaurant_demo/pubspec.yaml` now depends on `jet_cad_floor_plan: ^0.7.2`; the new graph is `jet_cad_2d_plan` + `jet_cad_2d_kit_architecture` + `jet_cad_2d_kit_restaurant` (workspace). `jet_cad_restaurant_symbols` and `jet_cad_floor_plan` remain only as long as the floor_planner app and CI's host probe (`tool/ci/host_probe`, which copies `restaurant.jetlib`/`names.dart`) need them: decide whether 4a deletes the old package or only stops the demo using it.
