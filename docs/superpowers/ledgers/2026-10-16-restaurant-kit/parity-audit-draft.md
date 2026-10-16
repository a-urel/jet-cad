# Parity audit: host guide (docs/host-guide.md) vs jet_cad_2d_plan / jet_cad_2d_kit

Paths: `P` = packages/jet_cad_2d_plan/lib/src, `T` = packages/jet_cad_2d_plan/test.
Test names are the id/prefix the test carries in its description (found by reading the files). Status: HAVE / PARTIAL / MISSING / RENAMED-ONLY (same behaviour, new name, test exists).
The 2b spec S5 (docs/superpowers/specs/2026-10-14-plan-library-service-mode-design.md:960-1045) already maps today's service/table API and says "Sub-project 4's parity table takes these rows over"; rows below reuse it and were re-checked against code. No new host guide exists yet (docs/host-guide.md is still the old one; tool/ci/check_guide.dart + tool/ci/host_probe still target it). Nothing named a restaurant kit exists.

## 1. Tables per guide section

### §1-§3 dependency, fonts, languages (context for §4-§11)
| old | new | test | status |
|---|---|---|---|
| depend on jet_cad_floor_plan + restaurant_symbols | jet_cad_2d_plan + a kit (`PlanController(kits:)`, P/controller/plan_controller.dart:261) | T/controller/plan_controller_test.dart C2 | HAVE (restaurant kit MISSING, see §4 of this file) |
| `ensureFloorPlanFonts`, `registerFontLicences` | `ensurePlanFonts` P/fonts/plan_fonts.dart:43, `registerFontLicences` :59 | T/fonts/fonts_register_test.dart FR1; export/export_font_test.dart | RENAMED-ONLY |
| `floorPlanLocalizationsDelegates`, `FloorPlanStrings` en/de/tr | `planLocalizationsDelegates` P/l10n/localizations.dart:20, `PlanStrings` (+En/De/Tr) | T/l10n/l10n_test.dart LB1, LB5 | RENAMED-ONLY |
| `SymbolNames` (symbol names de/tr) | `KitNames` (kit contract) + `PlanController(words:)` host words merge | T/controller/host_words_test.dart PB-words-1; l10n/unit_words_test.dart UW-host-word-first | RENAMED-ONLY |

### §4 controller and view
| old | new | test | status |
|---|---|---|---|
| `FloorPlanController(symbols:, thumbnails:)` shared loader/cache, not disposed by controller | `PlanController(symbols: PlanSymbolLoader, thumbnails:)` plan_controller.dart:261; `PlanSymbolLoader` symbols/plan_symbol_loader.dart:39 | T/controller/symbols_controller_test.dart S-11 | HAVE |
| `FloorPlanController(symbolSources:)` owns its own | no `symbolSources`: libraries come from each kit; null `symbols` makes an own loader (plan_controller.dart:339) | S-11 ("its own are" disposed) | PARTIAL (no direct source list; host must put libraries in a kit) |
| `SymbolLibraryLoader/Source/State`, `furnitureSymbolSource` | `PlanSymbolLoader`, `SymbolsState` (kit), kit `furniture` source | T/symbols/plan_symbol_loader_test.dart S-1..S-8 | RENAMED-ONLY |
| `FloorPlanView` (all options) | `PlanEditor` (design + service in one widget) editor/plan_editor.dart:72; `PlanServiceView` service/view/plan_service_view.dart:59; `PlanCanvas` canvas/plan_canvas.dart:44 | T/editor/editor_service_mode_test.dart SV-8, SV-9; service/view/plan_service_view_test.dart SV-1 | HAVE |
| `FloorPlanMode.design/selection`, `setMode`, `mode` | `PlanMode.design/service` service/service_session.dart:27; `setMode` controller:1804; `mode` :1787 | T/controller/mode_test.dart MD-C3 | RENAMED-ONLY |
| mode switch keeps plan on screen, zoom included | same | T/editor/editor_service_view_test.dart V7a | HAVE |
| `fitToView()`, `load`/`newPlan` re-fit | `fitToView` :2700 | T/editor/editor_service_view_test.dart V12, VZ4 | HAVE |
| `fitToTables(numbers)` | `fitToUnits(labels)` :1405 | T/units/unit_api_test.dart UA-fit-seat; editor_service_view_test.dart VZ1-VZ12 | RENAMED-ONLY |
| public camera: `camera`, `panBy`, `zoomBy`, `centerOn` | `cameraValue` :1043 (`PlanCamera` controller/plan_camera.dart:24: `worldToCanvas`, `canvasToWorld`, `visibleWorld`), `panBy` :2727, `zoomBy` :2738, `centerOn` :2714 | T/controller/camera_test.dart CM5, CM6, C-cam1; unit_camera_test.dart CM1-CM3 | HAVE |
| `minScale/maxScale` ctor | `PlanController(minScale:, maxScale:)` | T/controller/camera_test.dart CM4, CM15 | HAVE |
| `canvasRect`, `worldToGlobal`, `globalToWorld` | same names :2604, :1046 | T/controller/camera_test.dart (canvasPlaced) | HAVE |
| `userCamera: false` | `PlanServiceView(userCamera:)` | T/service/view/band_view_test.dart RBV2; unit_camera_test.dart header only | PARTIAL (no test named for userCamera:false alone; PlanEditor forwards it, grep found no dedicated test) |
| `exportName`, `onExport`, `printer` | same options on PlanEditor/PlanServiceView (`PlanExport`, `PagePrinter`/`PrintingPagePrinter` export/page_printer.dart:11,19) | T/export/page_flows_test.dart PF2, export/page_printer_test.dart PP-1 | RENAMED-ONLY |
| one view per controller: second view throws StateError | not enforced; `canvasPlaced` keeps a map of canvases (controller:2608). Behaviour relaxed | T/canvas/view_palette_test.dart M-DT-11 (two views side by side) | PARTIAL (guide rule gone; undefined which view wins camera/canvasRect: `last`) |

### §5 storing the plan
| old | new | test | status |
|---|---|---|---|
| `designJson()` | `save()` :645 (the design whatever the mode) | T/controller/plan_controller_test.dart C4; file/plan_file_test.dart PF-6 | RENAMED-ONLY |
| `markSaved()`, `dirty` | `markSaved` :686, `dirty` :608 | plan_controller_test.dart C4, C5, C6 | HAVE |
| `load(json)` throws FormatException, changes nothing | `load` :695, `PlanFormatException` (is a FormatException) | plan_controller_test.dart C3; plan_file_test.dart PF-1 | HAVE |
| ctor `json:` | `PlanController(json:)` | plan_controller_test.dart C2 | HAVE |
| `newPlan()` takes view language's separator | `newPlan({decimalSeparator, build})` :718; `reportLocale` :2373 | T/controller/locale_separator_test.dart; new_plan_test.dart ND1; l10n/document_separator_test.dart | HAVE |
| service moves never make it dirty | same | T/controller/service_record_controller_test.dart SR-C2 | HAVE |
| plans of schema 7-10 (old) open | NOT read: format 1 (`kPlanFormat`, file/manifest.dart:14), no compatibility (umbrella decision 9); S5: saved numbers, data, colours are dropped | none | MISSING (by decision; a POS with stored floors has to recreate them or write its own converter) |

### §6 service layout
| old | new | test | status |
|---|---|---|---|
| `serviceLayoutChanges` | `serviceChanges` :2027 (now also fires on `setUnitGroups` in service) | T/controller/service_record_controller_test.dart SR-C18, SR-changes-timing | RENAMED-ONLY (difference documented) |
| `serviceLayoutJson()` null in design | `serviceJson()` :2031 (moves + groups) | SR-C16, SR-roundtrip | RENAMED-ONLY |
| `restoreServiceLayout` -> `ServiceLayoutRestore(applied, dropped)`; StateError in design; FormatException | `restoreService` :2047 -> `ServiceRestore` service/service_record.dart:282 (`appliedMoves`, `droppedMoves`, `appliedGroups`, `droppedGroups`) | SR-C19, SR-restore-revision, SR-design-edited, SR-locked-move-dropped | RENAMED-ONLY |
| `resetLayout()` | `resetService()` :2092 (also clears groups) | SR-reset | RENAMED-ONLY |
| `serviceEdited` | `serviceEdited` :2015 (moves or groups) | SR-C17, SR-edited-after-enter | HAVE |
| Undo in service only reaches service moves; restore is not a step | active document | T/controller/mode_test.dart MD-C4; unit_changes_test.dart DC7 | HAVE |
| old `jet_cad.service_layout` text | refused | SR-old-format-refused | MISSING (by decision) |
| save-before-switch protocol (store read, then `setMode`, then restore) | same calls | none end to end except SR-roundtrip | HAVE |

### §7 tables, statuses, selection, colours
| old | new | test | status |
|---|---|---|---|
| `setTableStatus` / `tableStatuses` / `TableStatus` (caption cut to 12) | `setUnitStatus` :1257 / `unitStatuses` :1254 / `UnitStatus` service/service_state.dart:19 | T/controller/service_state_controller_test.dart SS-C15 | RENAMED-ONLY |
| statuses kept across modes/loads, not saved/undone | same | SS-C15; service_record_controller_test.dart SR-state-kept | HAVE |
| `select(numbers)`, `selectedTables` | `select(labels)` :1183, `selectedUnits` :1215 (`editorSelectedUnits` :1211) | T/controller/unit_groups_controller_test.dart TG-C5..C7; units/unit_api_test.dart UA-select-design | RENAMED-ONLY |
| `tables`, `revision`, `numberingWarnings`, `NumberingWarning` (`DuplicateNumber`, `Unnumbered`), `TableNumberProblem` | `units` :1062 (`PlanUnit` units/unit_detail.dart:17 adds kind, capacity, generatedBy), `revision` :1037, `labelWarnings` :1148 (`UnitLabelWarning` + `DuplicateLabel`, `Unlabelled`, `BadLabel`), `UnitLabelProblem` units/unit_label.dart:22; `PlanStrings.labelWarning/labelProblem/labelUsed` | T/units/unit_api_test.dart UA-units, UA-label-used; units/unit_numbers_test.dart TN7, TN8; barrel_test.dart (exhaustive switch) | RENAMED-ONLY |
| Colours: `FloorPlanColor` (8 hues), `setTableColor(s)`, `FloorPlanTableDetail.color` | `PlanSwatch` (kit, same 8 hues), `setUnitColour` :1453 / `setUnitsColour`, `PlanUnitDetail.colour` | T/controller/unit_colour_test.dart TC2-TC9 | RENAMED-ONLY |
| colour: one undo step, dirty, reported on change stream, refused in service | same | TC2, TC6, TC9 | HAVE |
| colour in export/print at `tableColorOpacity` (0.35), ArgumentError outside [0,1] | `PlanTheme.unitColourOpacity`; `kUnitColourOpacity` P/theme/plan_theme.dart:16; `export/print(unitColourOpacity)` via `PlanExportRequest` | T/export/unit_colour_export_test.dart EX2, EX3, EX3c; unit_colour_opacity_test.dart SP-opacity-arg | HAVE |
| status covers colour; group status covers members | same | T/service/view/unit_fill_view_test.dart TF6; service/paint/unit_fill_test.dart | HAVE |
| `setTableData`, `setTablesData` (limits, one undo step, hidden/locked layers ok, StateError in service) | `setUnitData` :1434, `setUnitsData` | T/controller/unit_data_test.dart HD1-HD12 | RENAMED-ONLY (difference: `false` under a locked object) |
| new: set a number from the host | `setUnitLabel` :1505, `setUnitsLabel` | T/units/unit_api_test.dart UA-labels-swap; unit_groups_controller_test.dart SS-relabel | HAVE (new) |
| `tableAt(point)` | `unitAt` :1158 | T/controller/unit_detail_test.dart TA1-TA3 | RENAMED-ONLY |
| `tableDetails` / `FloorPlanTableDetail` (center, size, rotation, mirrored, corners, layer, locked, data, color) | `unitDetails` :1083 / `PlanUnitDetail` units/unit_detail.dart:75 (same fields, `colour`) | T/controller/unit_detail_test.dart TD1-TD13 | RENAMED-ONLY |
| Band: `FloorPlanFloorDrag.band/pan`, window/crossing, Escape, Shift/Ctrl/Cmd add, locked never taken | `PlanFloorDrag` service/service_tool.dart:42 on PlanServiceView/PlanEditor | T/service/view/band_view_test.dart RBV1-RBV8; service/service_band_test.dart | RENAMED-ONLY |
| Groups: `setTableGroups`, `TableGroup` (label 24), `setGroupStatus`, `selectedGroup`, `selectableMembers`, `mergeCandidate`, `onGroupTap`, `onMergeRequested/onSplitRequested`, context click selects group | `setUnitGroups` :1273, `UnitGroup` service_state.dart:47, `setGroupStatus` :1287, `selectedGroup` :1314, `selectableMembers` :1325, `mergeCandidate` :1319, view callbacks same names | T/controller/unit_groups_controller_test.dart TG-C1..C16; service/view/unit_groups_gesture_test.dart TG-G1..G14; unit_groups_context_test.dart TG-CX1; unit_groups_toolbar_test.dart TB1-TB5 | RENAMED-ONLY |
| Zones: host's, `fitToTables`, `setTableFocus`/`tableFocus`, faded unit still works | `fitToUnits`, `setUnitFocus` :1301, `unitFocus` | service_state_controller_test.dart SS-CF1; editor_service_view_test.dart VZ1-VZ12, VF1-VF7 | RENAMED-ONLY |
| unplaced-table recipes (`unplacedTables`, `unplacedIds` over details) | `units`/`unitDetails` give `visible`, `data` | T/controller/unit_data_test.dart HD1 | HAVE (host code) |
| Overlays: `tableOverlayBuilder`, `FloorPlanTableOverlay`, `FloorPlanOverlayLayout/Size`, `tableOverlayModes`, detail breakpoints, interactive | `unitOverlayBuilder`, `PlanUnitOverlay` service/view/unit_overlays.dart:25, `PlanOverlayLayout` :111, `PlanOverlaySize`, `unitOverlayModes` | T/service/view/unit_overlay_test.dart TO1-TO33 | RENAMED-ONLY |
| Events: `onTableTap/DoubleTap/ContextMenu/Hover`, `onTablesMoved`, `onFloorTap`, `onLayoutChanged` | `onUnitTap/DoubleTap/ContextMenu/Hover`, `onUnitsMoved`, `onFloorTap`, `onLayoutChanged` (PlanServiceView ctor :60) | T/service/view/view_events_test.dart VE1-VE18; service_options_test.dart SO2 | RENAMED-ONLY |
| Host data: `designChanges` stream, `FloorPlanDesignChange` (Added/Changed/Removed/PlanReplaced) | `unitChanges` :1568, `PlanUnitChange` (`PlanUnitAdded/Changed/Removed/UnitsReplaced`) | T/controller/unit_changes_test.dart DC1-DC19 | RENAMED-ONLY |
| `longPress` (`toggleSelection`/`contextMenu`), `serviceMoves` | `PlanLongPress` service_tool.dart:33; `PlanPermissions.serviceMove` | service_options_test.dart SO1, SO4 | RENAMED-ONLY |

### §8 callbacks, bars, capabilities, keyboard
| old | new | test | status |
|---|---|---|---|
| `onExport`, `printer`, `onExportDialog`, `onPageFlowError` | same on PlanEditor/PlanServiceView; `showPlanExportDialog`, `PlanExportDialog` export/export_dialog.dart:12 | T/export/page_flows_test.dart PF6, PF9, PF12, PF14; editor/editor_bar_test.dart PF5 | HAVE |
| `exportPlan(choice,{name})` / `printPlan` (no view needed, one flow at a time) | `export(exporterId, choice)` :461, `print(choice)` :477, exporters/importers registries (`PlanExporter/Importer`, export/registries.dart) | T/export/page_flows_test.dart PF4, PF7; registry_test.dart X-2..X-8 | RENAMED-ONLY (+ importers new) |
| `FloorPlanExport/Choice/Format/Dpi` | `PlanExport` registries.dart:160, `PlanExportChoice` :64, `PlanExportDpi` :48 (format = exporter id) | PF13 | RENAMED-ONLY |
| service bar `FloorPlanServiceBar/Action` (visible, actions order, leading, trailing; Merge/Split only with callbacks) | `PlanServiceBar` plan_service_bar.dart:34, `PlanServiceAction` | T/service/view/service_bar_test.dart BC1, BT1, BT2, M-H40 | RENAMED-ONLY |
| editor bar `FloorPlanEditorBar/Action` | `PlanEditorBar` editor/plan_editor_bar.dart:32, `PlanEditorAction` | T/editor/editor_bar_test.dart BC2, BT2, M-H40 | RENAMED-ONLY |
| bar of your own: `canUndo/canRedo/undo/redo/mergeCandidate/activeTool/selectTool` | controller :1945 `canUndo`, :1956 `undo`, :1319, :2128 `activeTool`, :2170 `selectTool` | service_bar_test.dart S-5, T2-d; plan_controller_test.dart C8, C9 | HAVE |
| host text field in a bar keeps its keys | same | service_bar_test.dart T2-b, R-5; shortcuts/host_text_keys_test.dart | HAVE |
| `FloorPlanEditorCapabilities` (`full`, `tablesOnly`, `readOnly`, `copyWith`) | `PlanPermissions` controller/permissions.dart:35 (`full`, `unitsOnly`, `readOnly`, `copyWith`, settable `controller.permissions` :2211) | T/controller/permissions_test.dart PM-1..PM-5; editor/units_only_select_test.dart | RENAMED-ONLY |
| `tools: Set<FloorPlanTool>` (16 enum values) | `PlanPermissions.tools: Set<String>` of tool ids; `PlanToolIds` (tools/generic_tools.dart:10) is NOT exported from the barrel | T/editor/editor_options_test.dart RV8 | PARTIAL (host must hard-code id strings; no typed enum) |
| `symbolPalette`, `symbolFilter(FloorPlanSymbol)` | `PlanEditor(gallery:, symbolFilter: bool Function(PlanSymbol))` plan_editor.dart:77-78; `isUnitSymbol` | T/editor/plan_editor_test.dart ED-F | RENAMED-ONLY |
| `selectionPanel/layerPanel/pagePanel`, `editLayers`, `editPage` | `PlanEditor(propertyPanel:, layerPanel:, pagePanel:)`; `PlanPermissions.editLayers/editPage` | T/editor/editor_options_test.dart T5-g, R-3, R-4 | RENAMED-ONLY |
| `selectTablesOnly` | `selectUnitsOnly` | T/editor/units_only_select_test.dart M-H42 | RENAMED-ONLY |
| `move,rotate,mirror,reshape,delete,renumber,changeLayer,recolor,undo,export,print` | `PlanPermissions` flags + `PlanGate` (kit); `relabel` replaces `renumber` | editor_options_test.dart (readOnly), T4-e; panels/colour_row_test.dart CP10 | RENAMED-ONLY |
| `rulers, grid, snapping` | `PlanEditor(rulers:, grid:, snapping:)` | editor_options_test.dart T4-f, T4-g | HAVE |
| `tableInspectorBuilder` | `PlanEditor(unitInspectorBuilder:)` plan_editor.dart:143 | T/editor/unit_inspector_test.dart M-H45, T6-d | RENAMED-ONLY |
| `activeTool`, `selectTool`, `editorSelectedTables` for own panels | `activeTool`, `selectTool`, `editorSelectedUnits` | plan_controller_test.dart C9 | HAVE |
| `shortcuts: false`, `autofocus`; commands stay callable; `deleteSelection()` | same options; `deleteSelection` :2265; `PlanShortcuts`, `PlanShortcutGuard`, `kFileChords` | T/shortcuts/plan_shortcuts_test.dart KB-3, KB-10, T6-c; service/view/service_keys_test.dart DS4 | HAVE |
| web context menu note | unchanged (docs) | n/a | HAVE |
| file chords / callbacks | new: `onNew/onOpen/onSave/onSaveAs` | plan_shortcuts_test.dart KB-6 | HAVE (new) |

### §9 themes
| old | new | test | status |
|---|---|---|---|
| `FloorPlanTheme` 17 fields (ThemeExtension, per-view override, lerp) | `PlanTheme` theme/plan_theme.dart:29 (`unitColourOpacity` replaces `tableColorOpacity`), `PlanEditor/PlanServiceView(theme:)` | T/theme/plan_theme_test.dart TH0-TH21; service/view/theme_service_test.dart | RENAMED-ONLY |
| dark canvas re-toning, exports never re-toned | same | T/canvas/dark_canvas_test.dart M-DC-1; theme/theme_service_mode_test.dart | HAVE |
| status caption contrast | same | service/view/status_caption_test.dart | HAVE |

### §10 touch
| old | new | test | status |
|---|---|---|---|
| pinch/pan, second finger cancels drag, long press 500 ms, finger reach, band by finger | same | T/canvas/touch_tools_test.dart TD2; editor/editor_service_view_test.dart V18, V19; band_view_test.dart RBV1; service_options_test.dart SO4 | HAVE |

### §11 never assume
| old | new | test | status |
|---|---|---|---|
| handles are not API; tables known by number | units known by label (`select`, `setUnit*` take labels) | unit_api_test.dart UA-label-used | HAVE |
| capabilities are not a security boundary (host calls stay allowed) | same | T/editor/editor_options_test.dart "the host's own calls still work under readOnly" | HAVE |
| `shortcuts:false` => nothing deletes | same | T/shortcuts/plan_shortcuts_test.dart T6-c, RP1 | HAVE |
| service layout text opaque, one plan | `serviceJson` opaque; groups now inside | SR-roundtrip | HAVE |
| service Undo only undoes service moves | same | mode_test.dart MD-C4 | HAVE |
| stored name's language; plan separator | `KitNames`; plan separator | l10n/document_separator_test.dart; locale_separator_test.dart | HAVE |
| schema 8/9/10 notes | format 1 + manifest + missing-kit warnings (`checkManifest`, `ManifestCheck`) | T/file/manifest_test.dart PF-3, PF-4, PF-8; plan_controller_test.dart C7 | RENAMED-ONLY (new guide must rewrite) |
| new guide / host probe | docs/host-guide.md, tool/ci/host_probe still old | none | MISSING |

## 2. Old barrel (packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart) exports
| old name | new | status |
|---|---|---|
| FloorPlanColor | PlanSwatch (kit) | RENAMED-ONLY |
| registerFontLicences | registerFontLicences | HAVE |
| PagePrinter, PrintingPagePrinter | same | HAVE |
| ensureFloorPlanFonts | ensurePlanFonts | RENAMED-ONLY |
| FloorPlanEditorAction / FloorPlanEditorBar | PlanEditorAction / PlanEditorBar | RENAMED-ONLY |
| FloorPlanServiceAction / FloorPlanServiceBar | PlanServiceAction / PlanServiceBar | RENAMED-ONLY |
| FloorPlanDesignChange, FloorPlanTableAdded/Changed/Removed, FloorPlanPlanReplaced | PlanUnitChange, PlanUnitAdded/Changed/Removed, PlanUnitsReplaced | RENAMED-ONLY |
| FloorPlanEditorCapabilities | PlanPermissions | RENAMED-ONLY |
| FloorPlanSymbol | PlanSymbol | RENAMED-ONLY |
| FloorPlanTool | none (string ids; PlanToolIds unexported) | PARTIAL |
| FloorPlanCamera | PlanCamera | RENAMED-ONLY |
| FloorPlanController | PlanController | RENAMED-ONLY |
| DuplicateNumber, Unnumbered, NumberingWarning | DuplicateLabel, Unlabelled, UnitLabelWarning (+ BadLabel) | RENAMED-ONLY |
| FloorPlanExport / Choice / Dpi / Format | PlanExport / PlanExportChoice / PlanExportDpi / exporter ids | RENAMED-ONLY |
| FloorPlanFloorDrag, FloorPlanLongPress | PlanFloorDrag, PlanLongPress | RENAMED-ONLY |
| FloorPlanMode | PlanMode | RENAMED-ONLY |
| FloorPlanTable | PlanUnit | RENAMED-ONLY |
| ServiceLayoutRestore | ServiceRestore | RENAMED-ONLY |
| TableGroup, TableStatus | UnitGroup, UnitStatus | RENAMED-ONLY |
| FloorPlanTheme | PlanTheme | RENAMED-ONLY |
| FloorPlanView | PlanEditor / PlanServiceView / PlanCanvas | RENAMED-ONLY |
| FloorPlanTableDetail | PlanUnitDetail | RENAMED-ONLY |
| FloorPlanOverlayLayout/Size, FloorPlanTableOverlay(+Builder) | PlanOverlayLayout/Size, PlanUnitOverlay(+Builder) | RENAMED-ONLY |
| FloorPlanLocalizations, floorPlanLocalizationsDelegates, floorPlanSupportedLocales | PlanLocalizations, planLocalizationsDelegates, planSupportedLocales | RENAMED-ONLY |
| FloorPlanStrings / En / De / Tr | PlanStrings / En / De / Tr | RENAMED-ONLY |
| SymbolLibraryLoader, SymbolLibrarySource, furnitureSymbolSource | PlanSymbolLoader, kit symbol sources, architecture kit furniture | RENAMED-ONLY |
| SymbolLibraryState/Loading/Ready/Failed | SymbolsState (kit) | RENAMED-ONLY |
| SymbolNames | KitNames (kit) | RENAMED-ONLY |
| TableNumberProblem | UnitLabelProblem | RENAMED-ONLY |
| SymbolThumbnails | SymbolThumbnails (re-export) | HAVE |

## 3. restaurant_demo features (apps/restaurant_demo/lib/main.dart)
| demo feature | new API | status |
|---|---|---|
| two areas Salon/Teras, one controller each, shared loader+cache | two `PlanController`s with shared `PlanSymbolLoader`, `SymbolThumbnails` | HAVE |
| Design/Service toggle | `setMode`, `mode` | HAVE |
| sample plans (Salon, Teras) with restaurant symbols | no restaurant kit/library; `build:` hook exists | MISSING |
| POS id field in table inspector (`setTableData` on Enter, empty unlinks) | `unitInspectorBuilder` + `setUnitData` | HAVE |
| table context menu | `onUnitContextMenu`, `selectedUnits` | HAVE |
| statuses (Free/Ordered/Bill...), random statuses, captions re-worded by language | `setUnitStatus`, `UnitStatus` | HAVE |
| merge / split groups with ids, group statuses | `setUnitGroups`, `setGroupStatus`, `onMergeRequested/onSplitRequested`, `selectableMembers` | HAVE |
| find / select a table | `select(labels)`, `fitToUnits` | HAVE |
| own service bar | `PlanServiceBar(visible:false)` or `leading/trailing`; controller undo/redo/export | HAVE |
| link tables (data id in one undo step) | `setUnitsData` | HAVE |
| zones tabs + fade others | `fitToUnits` + `setUnitFocus` | HAVE |
| own export dialog / print / bar | `onExportDialog`, `controller.export/print`, `PagePrinter`, `onPageFlowError` | HAVE |
| save / revert | `save()`, `markSaved`, `load`, `dirty` | HAVE |
| layout restore on re-entering service | `serviceJson`, `restoreService`, `serviceChanges` | HAVE |
| events log (tap, double tap, hover, floor tap, moved, design changes) | `onUnit*`, `onFloorTap`, `onUnitsMoved`, `unitChanges` | HAVE |
| badges on tables (guests, minutes), dot below scale | `unitOverlayBuilder`, `PlanOverlayLayout(detailBreakpoints)` | HAVE |
| centre on table 7 | `unitDetails` + `centerOn` | HAVE |
| editor profiles (full, tables only, read only), own editor bar | `PlanPermissions.full/unitsOnly/readOnly`, `PlanEditorBar` | HAVE |
| band selection, long press modes | `PlanFloorDrag.band`, `PlanLongPress` | HAVE |
| POS theme look light/dark | `PlanTheme` extension per ThemeData | HAVE |
| language switch EN/DE/TR | `PlanStrings`, `planLocalizationsDelegates` | HAVE |
| `FloorPlanFonts` bootstrap | `ensurePlanFonts` | HAVE |
| keyboard to demo (`shortcuts:false`, `autofocus`) | same | HAVE |
| restaurant symbol catalog (`restaurantSymbolSource`) | none | MISSING |

## 4. packages/jet_cad_restaurant_symbols (lib/src)
- Catalog: 6 categories (Restaurant Tables, Booths and Lounge, Bar, Service, Commercial Kitchen, Outdoor and Decor). 69 named symbols (names.dart: 69 keys per locale). By file (symbol keys quoted): tables.dart 12, booths.dart 9, bar.dart 9, service.dart 14, kitchen.dart 17, outdoor.dart 8 (grep count; helper definitions may add a few lines).
- Capacities: the servable ones carry `seats` on the old `FurnitureSymbol` (tables rect/round/square, booths, banquettes, lounge, bar high tables and stools: `seats:` set in tables.dart, booths.dart, bar.dart). Service, kitchen, outdoor have none.
- Unit components: NONE. It depends on jet_cad_floor_plan (old `SeatingComponent`, `FurnitureSymbol`), asset `assets/restaurant.jetlib`, `restaurantSymbolSource`. The new contract wants `UnitComponent(kind, capacity, labelling)` (packages/jet_cad_2d_kit/lib/src/model/unit_component.dart) on a definition handle and a kit id prefix; this package cannot be used by `jet_cad_2d_kit` as is (a kit may not depend on the plan or another kit; it also still depends on jet_cad_floor_plan, version 0.7.0, publish_to none).
- Names locales: en (asset), de, tr for symbols and categories (names.dart:8, :79, categories :152, :160).
- Tests: restaurant_library_test, symbol_names_test, symbol_section_catalog_test.
- Symbol key rule changed (docs/kits.md section 2: kit id then two or more hyphen-joined segments); current keys use dots (`restaurant.table.rect.four`) and fit only if the segments rule allows `restaurant.table.rect.four` (it does) but keys like `restaurant.bar.table.high.two` need checking at port time (not verified).

## 5. Blockers for a real POS host (most important first)
1. No `jet_cad_2d_kit_restaurant` (symbols with `UnitComponent` table/seat capacity, de/tr names, categories) and no restaurant sample plans: nothing to place or serve.
2. No new host guide, and no parity test/CI probe for the new packages (docs/host-guide.md, tool/ci/check_guide.dart, host_probe still old): A14 cannot close.
3. Old stored plans/service layouts unreadable (decision 9): a POS with saved floors must rebuild them or get a converter; numbers, data, colours dropped.
4. `PlanPermissions.tools` takes raw tool id strings; `PlanToolIds` not exported, no typed `FloorPlanTool` equivalent.
5. `PlanController(symbolSources:)` convenience gone: libraries only via kits; a host cannot simply add one library source.
6. "One view per controller" rule/StateError dropped without a documented replacement (two views mounted share one canvasRect; last wins).
7. `userCamera:false` has no dedicated test in the plan package.
8. Group/finders: a restore drops a group whose label names no unit (documented difference) - POS merge state is lost on a relabel.
9. Restaurant demo itself still on old API (apps/restaurant_demo); needs a port to prove parity.
10. restaurant_symbols still depends on jet_cad_floor_plan.
