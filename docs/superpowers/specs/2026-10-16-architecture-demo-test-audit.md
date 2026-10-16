# 3b test audit: apps/floor_planner/test -> apps/architecture_demo

Worktree: `.claude/worktrees/architecture-demo`. Dispositions: PORT, COVERED (a test found by grep, named), DROPPED, SPLIT.
Path shorthands: **P** = `packages/jet_cad_2d_plan/test`, **K** = `packages/jet_cad_2d_kit_architecture/test`, **I** = `packages/jet_cad_2d_integration/test`.
Spec A.3 (`2026-10-15-architecture-kit-design.md`) and the results note ("Carried to sub-project 3b") list exactly these files as 3b; WE1, SS16, SS17 and the layer picker's wall case went to 3a (I `attach/wall_attach_end_to_end_test.dart`, I `attach/symbol_shell_test.dart`, I `layers/layer_picker_wall_test.dart`); WE2 is not ported at all (C7, decision 9).

## Library facts the dispositions lean on (checked in lib/)

1. `PlanEditor` offers New/Open/Save/Save As only as `onNew/onOpen/onSave/onSaveAs` callbacks (plan_editor.dart:409-440). Its file buttons are gated only by `_idleFlag` (no tool mid-shape); there is no host "enabled" hook. Export/Print/Undo/Redo can be switched off only through `PlanPermissions` (`export`, `print`, `undo`). So "disabled while busy" (old DC7, RN1, PR5, PR10, EX10) has to become "callbacks no-op while the app is busy" plus permissions; the buttons themselves cannot grey out.
2. `PlanController.pageFlows` is `@internal`; the app cannot observe an export/print in flight. The app can wrap `onExportDialog` and the `PagePrinter` to set its own busy flag.
3. `onExport` is `void Function(PlanExport)` (sync); the write (saveLocation + write) and its errors belong to the app. `onPageFlowError(Object)` carries no flow kind, so the old "Export failed" / "Print failed" titles need a decision.
4. `armedSymbol` lives on the controller and is not reset by `newPlan`/`load` (plan_controller.dart:2410); the active tool is (C-life1). Old SS7 expected the armed symbol to be null after a swap.
5. "Open sample" is not a `PlanEditorAction`; it can only be a `PlanEditorBar.leading/trailing` widget.
6. `PlanEditor.exportName` names exports and the print job (`<exportName>.<ext>`); the app passes the document name.
7. The `_idleFlag` gating of file buttons mid-shape, the Cmd (meta) variants of the file/print chords, the redo chords (Cmd/Ctrl+Shift+Z, Ctrl+Y) and the macOS tooltip glyphs are not pinned by any test in P (found by grep); these show as "library gap" in the PORT notes.

---

## document_commands_test.dart (16)

| case | disposition | destination / covering test / reason |
|---|---|---|
| DC1 toolbar: seven buttons in order, group gap, enabled states | SPLIT | -open: the app adds an "Open sample" button (key `toolbar-open-sample`) in `PlanEditorBar.leading/trailing`; position differs from the old order (fact 5). Intent (order, 12 px group gap, Undo/Redo enabled follow history): COVERED by P `editor/plan_editor_test.dart` ED-3 (order new, open, save, save-as, export, print, undo, redo) and ED-U |
| DC1b tooltips: first chord, glyphs on macOS, Ctrl elsewhere; Open sample none | PORT | tooltips now come from `PlanStrings`; only Turkish/German tooltips pinned (P `editor/editor_words_test.dart` SW1, SW2), the per-platform glyph is not (library gap); the Open sample tooltip is the app's |
| DC2 Undo/Redo tap and chords (Ctrl+Y too) move one step | PORT | through `PlanEditor`; library pins undo chords only (P `shortcuts/plan_shortcuts_test.dart` KB-3, I `shell/planner_shell_test.dart` "cmd+Z undoes a Delete through the command log"); redo chords unpinned. DocumentSession history -> `controller.document.commands` |
| DC3 bare shell: Undo/Redo only, no name | COVERED | P `editor/plan_editor_test.dart` ED-3 (second half: without callbacks no file button), P `editor/editor_view_test.dart` V1 ("the editor has Export and Print and no file commands"), ED-U; "no name" is the app's widget; redo chords go with DC2 |
| DC4 each file button and chord runs its own flow, tool stays Select | PORT | callbacks -> app flows. Library half: ED-3 (buttons settle then call host once), P KB-6 (Ctrl+N/O/S/Shift+S call the host callbacks); Cmd variants and Open sample are the app's |
| DC5 mid-shape: every button disabled, tap changes nothing, Escape re-enables | PORT | library gap: the `_idleFlag` toolbar gating has no test in P (only C8 "undo and redo ... do nothing while a tool is part-way", KB-4). Test through `PlanEditor` + kit Wall tool |
| DC6 app tools Wall/Separator/Dimension/Box mid-shape after one click; Door/Window/Gap/Room place on one click | PORT | tool half partly pinned: I `wall/wall_tool_test.dart` WT2, WT4, WT6 (chain mid-shape), I `separator/separator_shell_test.dart` ST1; Dimension, Box, openings, Room never mid-shape unpinned; toolbar flags unpinned. Tool ids now `architecture.*` |
| DC7 disabled means no call during a held write; chords still consumed | SPLIT | -open: buttons cannot be disabled by the app (fact 1): callbacks no-op while busy, `permissions(undo:false, export:false, print:false)` while busy is one mechanism, chords still handled. Intent (nothing reaches dispatcher/files while a write is held): PORT test with `FakeDocumentFiles.holdWrites`; chord consumption with no page is P KB-6 |
| DC8 focused Selection field keeps redo chords from the document | COVERED | P `panels/layer_panel_test.dart` "no shell shortcut fires while typing: letters, Undo, Redo and Escape stop at the field" (guards `kUndoChords + kRedoChords`) and P `panels/page_scale_field_test.dart` A9; canvas half = DC2 |
| DC9 above dialogs: error dialog up (busy), page-panel dropdown route open, every file chord handled, runs nothing | PORT | library gap: no test for chords vs a dialog/dropdown route; error dialog and busy are the app's |
| DC10 Redo after a settle (thickness typed, commit cuts redo branch) | PORT | wall field is `PlanPropertyPanel` + kit panel; library half P `controller/plan_controller_test.dart` C11 (settle before undo/redo) pins the call order only |
| DC10b Undo settles first (tap removes the commit, not the wall) | PORT | same as DC10 |
| DC11 tab title and top bar follow dirty (bullet, Edited tooltip) | PORT | `session.dirty` -> `controller.dirty`; `Title` and the name widget are the app's |
| DC12 800x600 long name + long status: ellipsis, OSNAP/zoom stay | SPLIT | -open: name+dirty widget in `PlanEditorBar.leading` with a bounded width, no overflow with a long name and notice. Intent: P `editor/editor_words_test.dart` OV-$code ("no overflow from 704 px down to 656 px") COVERS the library bar without host widgets |
| DC12b 1440x900 status takes the width the name leaves; name cut at half the shared width | DROPPED | the half-of-shared-width rule is the old bar's layout; the new name is a host leading widget (bounded width, fact 5). Intent folded into DC12/DC12c |
| DC12c 704 px down to 656 px titled long name + long status | SPLIT | as DC12; the floor moves by the leading widget's width (re-measure) |

Totals: PORT 9, COVERED 2, DROPPED 1, SPLIT 4.

## document_exit_test.dart (8)

| case | disposition | destination / reason |
|---|---|---|
| EX1 clean document exits with no dialog (launch, saved as, saved in place) | PORT | `DocumentSession.dirty` -> `controller.dirty`; `handleRequestAppExit` path |
| EX2 dirty: Cancel/Escape/failed Save cancel; Don't Save exits; Save writes bytes and exits | PORT | bytes = `controller.save()` then `markSaved()` |
| EX3 untitled dirty: Save runs Save As; cancelled panel cancels | PORT | |
| EX4 busy cancels at once with no second dialog (New asking, save held, exit's own save held) | PORT | app busy flag (fact 2) |
| EX5 clean doc + Selection value typed: exit settles first, dialog appears | PORT | `controller.settlePendingInput()`; library half C11 |
| EX6 shape part-way does not block exit; wall chain with a wall down asks | PORT | kit Wall tool |
| EX7 listener goes with the host | PORT | |
| EG1 exit guard armed exactly while dirty (edit, undo, redo, web save, New, Open sample, dispose) | PORT | `controller.dirty` listener; exit_guard io/web/stub kept |

Totals: PORT 8.

## document_files_kind_test.dart (7)

| case | disposition | destination / reason |
|---|---|---|
| FK1 fileNameFor appends the kind's extension | PORT | document_files layer kept; test moves with it |
| FK2 blank/null typed name is a cancel | PORT | |
| FK3 jetplanFileName is the jetplan case | PORT | |
| FK4 each kind's extension, type group, MIME type | PORT | |
| FK5 native save panel offers the kind's group alone | PORT | |
| FK6 FakeDocumentFiles records the kind | PORT | test support fake |
| DK-L panels' groups named by the label given | PORT | |

Totals: PORT 7.

## document_files_sources_test.dart (3)

| case | disposition | destination / reason |
|---|---|---|
| DS1 io save panel offers kind groups, named in the app's language | PORT | source-pin test; paths of the new app's files |
| DS3 app names the panels' types through its strings | PORT | pins `createFiles(askName:, typeLabel:)` in main.dart; rewrite for the new main |
| DS2 web save names the file and types the blob by the kind | PORT | |

Totals: PORT 3.

## document_files_test.dart (8)

| case | disposition | destination / reason |
|---|---|---|
| DF1 typed save name: blank cancel, trim, `.jetplan` appended | PORT | extension to be fixed by the 3b spec (old format compatibility not required; the library has no file-extension constant, only `kPlanFormat`) |
| DF2 panels offer one type | PORT | |
| DF3 FakeDocumentFiles open script | PORT | |
| DF4 saveLocation script | PORT | |
| DF5 write records, failNextWrite, copy of bytes | PORT | |
| DF6 holdWrites | PORT | |
| DF7 failNextWrite wins over holdWrites | PORT | |
| DF8 platform selection on the VM picks the native implementation | PORT | |

Totals: PORT 8.

## document_host_test.dart (7)

| case | disposition | destination / reason |
|---|---|---|
| DH1 launch on the empty document: untitled, clean, no history, mm, DASHED, literal page live | SPLIT | -open: untitled name/fileName/location, title "Untitled - jet-cad", busy false, zoom text, page panel present. Intent COVERED: P `controller/plan_controller_test.dart` C1, P `controller/new_plan_test.dart` ND1, I `scaffold/prepare_test.dart` SC-prepare (DASHED at handle 6), P `editor/editor_view_test.dart` "a bare editor opens on the empty document and its default page" |
| DH2 New after edit (Don't Save) -> fresh untitled clean; Open sample -> flat untitled clean | PORT | `controller.newPlan()` / `newPlan(build: buildSampleFlat)`; library halves P C5, P `controller/prepare_build_test.dart` PB8, I `sample/sample_flat_test.dart` SF-controller |
| DH3 dirty follows undo position vs save point: edit, undo, redo, save, cut branch | PORT | `session.dirty` -> `controller.dirty` + `save()/markSaved()`; library half C4, P `controller/unit_data_test.dart` HD11; cut-branch case unpinned in P |
| DH4 the same after an Open | SPLIT | -open: Open via `controller.load(text)` then dirty/title follow. Intent COVERED: P `controller/plan_controller_test.dart` C6 ("a load forgets the last save's state") |
| DH5 swap hygiene: old document disposed, released by everything; fresh shell; object-snap survives and toggles | SPLIT | -open: one `PlanController` across New/Open (identity kept), old `document.commands.isDisposed` after the swap, `snapping`/F3 setting survives. Intent COVERED: P `controller/lifetimes_test.dart` C-life1 (products disposed on swap), P `panels/layer_page_controller_test.dart` LP-1 (old document loses the panel's listener); snap survival unpinned |
| DH6 New/Open sample from a titled document forget its file; next Save asks | PORT | app-level name/fileName/location state (was `DocumentSession`) |
| DH7 swap leaves busy with the listeners it had | DROPPED | premise gone: no per-swap shell rebuild; busy is an app notifier read by callbacks, controller identity kept. Behaviour after a swap is covered by the ported DC7/RN1 |

Totals: PORT 3, SPLIT 3, DROPPED 1.

## document_open_test.dart (6)

| case | disposition | destination / reason |
|---|---|---|
| DO1 sample -> Save As -> Open -> Save byte-identical | PORT | `encodePlan` bytes via `controller.save()`; library half K `sample/sample_flat_test.dart` SP6, P `file/plan_file_test.dart` PF-6 |
| DO2 New: room + free wall rotated through the grip, far from origin -> Save As -> Open -> Save | PORT | kit tools (`architecture.wall`, room) |
| DO3 file without the DASHED record opens without one, saves back byte-identical | COVERED | I `scaffold/prepare_test.dart` SC-prepare ("a loaded file without it opens and saves back without it", `opened.save() == file`), P `controller/prepare_build_test.dart` PB3-prepare-load. (Spec C1.3 keeps it green) |
| DO4 page after Open is live: notifier, zoom text, page panel | COVERED | P `panels/layer_page_controller_test.dart` LP-3 (load swaps the document under the Page panel); zoom read-out P `editor/editor_view_test.dart` "the zoom text reads the scale and the fitted zoom" |
| DO5 catalog after Open: walls live, selected wall shows grips | COVERED | K `sample/sample_flat_test.dart` SP6 (loaded plan: no drift, no diagnostic), I `wall/wall_grips_test.dart` EG2 (selected wall shows two grips), K `wall/wall_live_test.dart` WL1 |
| DO6 unreadable file from a dirty doc: dialog names file and error, nothing changes, busy cleared | PORT | error text now from `PlanFormatException`; fixtures (latin-1, cut, list, bare, scale 0, future schema) re-derived; library refusal codes P `file/plan_file_test.dart` PF-1 |

Totals: PORT 3, COVERED 3.

## document_replace_test.dart (11)

| case | disposition | destination / reason |
|---|---|---|
| RP1 dirty + New/Open sample/Open: dialog, busy; Cancel/Escape keep everything | PORT | |
| RP2 Don't Save replaces | PORT | |
| RP3 Save then not saved (cancelled Save As / failed write) replaces nothing | PORT | |
| RP4 Save (Enter) writes then replaces (titled in place, untitled through Save As) | PORT | |
| RP5 clean document with history replaced without a dialog | PORT | |
| RP6 Open asks before the picker | PORT | |
| RP7 clean + typed Selection value: replace settles first, dialog appears | PORT | `settlePendingInput` (C11) |
| RN1 nested flows: held Save, every other command does nothing | PORT | see DC7 (callbacks no-op while busy; Undo needs `permissions.undo=false` or a guard) |
| RN2 edit lands while Save held: dialog asks again | PORT | |
| RN3 swap while a write is held: later write marks neither new document saved | PORT | `markSaved()` must only follow a write of the current plan's `save()` text (C4 pins the controller half) |
| RP8 replace dialog up: Cmd/Ctrl with S, O, N, Shift+S handled, run nothing | PORT | |

Totals: PORT 11.

## document_save_test.dart (7)

| case | disposition | destination / reason |
|---|---|---|
| DS1 save point is the encoded state (in-place and web variants) | PORT | `save()` then `markSaved()`; library half P `controller/plan_controller_test.dart` C4 |
| DS2 failed write from dirty: dialog, still dirty, busy cleared | PORT | |
| DS3 cancelled Save As from dirty: no write, no dialog | PORT | |
| DS4 untitled Save asks, names the document; Save As asks again | PORT | |
| DS5 web: Save on a titled document downloads without asking, clean | PORT | |
| DS6 web name prompt (suggestion, Save/Enter, Cancel) | PORT | `showDocumentNamePrompt` |
| DS7 Save As whose panel throws: dialog, false, still dirty/titled | PORT | |

Totals: PORT 7.

## document_separator_test.dart (3)

| case | disposition | destination / reason |
|---|---|---|
| FS1 launch plan under system locales prints the separator of the resolved language (fr -> de, fr only -> en) | PORT | system-locale resolution is the app's `MaterialApp`; library half P `controller/locale_separator_test.dart` NS1, NS6, NS8; P `editor/editor_separator_test.dart` NS1, NS2 |
| FS2 New prints the separator of the language of the moment | PORT | `controller.newPlan()` reads the locale last reported (NS8, NS10) |
| FS3 Open sample in Turkish prints comma in every area and value | PORT | `newPlan(build: buildSampleFlat)`; library halves PB8, K `sample/sample_flat_test.dart` SF-words (German comma; Turkish exact strings "22,00 m2" unpinned) |

Totals: PORT 3.

## document_settle_test.dart (9)

| case | disposition | destination / reason |
|---|---|---|
| ST1 wall thickness typed without Enter, then Cmd+S: bytes carry it, own step, clean | PORT | library half P C11, ED-3 (settle then host call once), P `panels/property_panel_test.dart` P-swap-pending |
| ST1b the same with Cmd+Shift+S | PORT | |
| ST2 text entry with typed text, then Cmd+S | PORT | |
| ST3 toolbar Save on macOS with a mouse and an open entry | PORT | |
| ST4 page scale typed without Enter, then Cmd+S | SPLIT | -open: Cmd+S through the app, bytes carry the stored scale. Intent COVERED: P `panels/layer_page_controller_test.dart` LP-5 ("the controller's settle re-syncs a typed, unsubmitted scale") |
| ST5 text entry ended by a click on palette/panel (mouse, touch): cancelled, focus back, Cmd+S saves | PORT | library half partial: P `panels/page_scale_field_test.dart` A15 (click into page field cancels a pending text) |
| ST6 Android: touch outside keeps the entry; mouse click ends it | PORT | |
| ST7 page scale left by Tab; Cmd+S re-syncs | SPLIT | -open: Cmd+S through the app. Intent COVERED: LP-5 |
| ST8 open entry with nothing typed, Cmd+S | PORT | |

Totals: PORT 7, SPLIT 2.

## app_words_test.dart (4)

| case | disposition | destination / reason |
|---|---|---|
| AW1 Turkish system: app and planner speak Turkish | PORT | app words (untitled "Adsiz", open sample, file types) are the app's; library tooltips pinned by P `editor/editor_words_test.dart` SW1 |
| AW2 German system; French is English | PORT | |
| AW3 file types' names in each language | PORT | `AppStrings.fileTypeLabel` |
| AW4 files get the system language's type names, read at each call | PORT | |

Totals: PORT 4.

## export/export_flow_test.dart (16)

| case | disposition | destination / reason |
|---|---|---|
| EX1 Export -> PDF writes flat.pdf kind pdf: MediaBox, placement, overrides, no separator path | SPLIT | -open: `onExport(PlanExport)` -> `saveLocation(name, kind: pdf)` + `write(kind: pdf)` (name `flat.pdf`, location). Intent COVERED: P `export/page_flows_test.dart` PF13 (PDF magic and MediaBox per choice), I `separator/separator_export_test.dart` SP-export-pdf (no path at the separator, wall drawn); instance placement/overrides in jet_cad_2d_flutter `export/export_pdf_test.dart` |
| EX2 an edit after an export reaches the screen's index | COVERED | P `export/registry_test.dart` X-4 (exporter gets a copy, not the controller's document): the old hook-restoring premise is gone by construction |
| EX2b text typed in an entry, Cmd+E, Export: PDF and document both have it | COVERED | P `export/registry_test.dart` X-8 (export settles pending input before it copies the plan), P `export/page_flows_test.dart` PF17 |
| EX3 PNG at 300 dpi writes flat.png kind png, A4 size | SPLIT | -open: kind png written by the app's `onExport`. Intent COVERED: PF13 (PNG pixel size per dpi) |
| EX4 dialog opens on last choice of the app session, across a swap | COVERED | P `export/page_flows_test.dart` PF14 (answer remembered as next initial), PF21 (also when the plan is replaced while open), P `export/plan_export_types_test.dart` X-1 (initial pdf 150) |
| EX5 busy while dialog up; Cancel asks and writes nothing | SPLIT | -open: app busy flag set around `onExportDialog` (fact 2). Intent COVERED: PF12 (hook answering null cancels: nothing exported) |
| EX6 Escape cancels the dialog | PORT | library gap: P `export/export_dialog_test.dart` X-9 pins OK/Cancel only |
| EX7 cancelled save writes nothing | PORT | `saveLocation` returns null in the app's `onExport` |
| EX8 throwing write shows "Export failed" | PORT | write errors are the app's (onExport is sync void, fact 3) |
| EX9 disabled with no page: button, chord, flow does nothing | COVERED | P `editor/plan_editor_test.dart` ED-X1 (Export/Print disabled, chord opens no dialog), P `shortcuts/plan_shortcuts_test.dart` KB-6 (refused with no page), P `export/page_flows_test.dart` PF3 |
| EX9b Export/Print follow the page: attached, undone, redone | PORT | library gap: only page removal at runtime is pinned (KB-6); attach/undo/redo of a page unpinned |
| EX10 enabled with a page; disabled while a flow runs | SPLIT | -open: host write busy gates the callbacks only. Intent COVERED: PF7 (flows hold the bar's Print/Export buttons) |
| EX11 Cmd/Ctrl+E opens the dialog | COVERED | P `editor/editor_bar_test.dart` PF5 (Cmd+E and Ctrl+E open the Material dialog), PF6 |
| EX12 dialog open: Cmd/Ctrl+P and E consumed, no second dialog | PORT | library gap (chord consumption above a route) |
| EX13 file names and kinds (`exportFileName`, `exportFileKind`, initial choice) | SPLIT | -open: kind from `PlanExport.mimeType`/extension in the app. Intent COVERED: PF2 (`<name>.png`), X-1 (initial pdf 150 dpi) |
| EX14 bare host exports a PDF in the bundled font named Untitled.pdf | SPLIT | -open: `exportName` = document name ("Untitled"). Intent COVERED: PF13 (controller default fonts), P `export/export_font_test.dart` EF4 |

Totals: SPLIT 6, COVERED 5, PORT 5.

## export/print_flow_test.dart (10)

| case | disposition | destination / reason |
|---|---|---|
| PR1 Print hands the printer the export's content stream, name, A4 pt, no separator | SPLIT | -open: `PlanEditor(exportName: <document name>)` so the job is named `flat`. Intent COVERED: P `export/registry_test.dart` X-7, P `export/page_flows_test.dart` PF3 (name, page format in pt, `%PDF`), SP-export-pdf for the omitted separator |
| PR2 A3 portrait: format 297x420 mm, MediaBox agrees | COVERED | X-7 (format from the page's effective size); A3 portrait fixture itself in jet_cad_2d_flutter `export/export_pdf_test.dart` "another sheet: A3 portrait at 1:100" |
| PR3 throwing printer shows "Print failed" | SPLIT | -open: `onPageFlowError` -> app error dialog (no flow kind, fact 3). Intent COVERED: P `export/page_flows_test.dart` PF9, PF11 (error reported once, guard free) |
| PR4 disabled with no page: button, chord, flow prints nothing | COVERED | ED-X1 (Print disabled), KB-6, PF3 (print answers false) |
| PR5 enabled with a page; disabled while a flow runs | SPLIT | -open: host write busy gates callbacks only. Intent COVERED: PF7 |
| PR6 Cmd/Ctrl+P prints, once | PORT | library gap: KB-6 pins Ctrl+P only, not Cmd+P |
| PR7 Print follows Export in file commands/toolbar with icon and chords | COVERED | ED-3 (order export, print), P `editor/editor_words_test.dart` SW1 ("Yazdir... (Ctrl+P)") |
| PR8 production printer at printing's platform channel | PORT | `PrintingPagePrinter` is now in the library (`page_printer.dart`) but no test in P/I/K touches `net.nfet.printing`: port into P or the app (library gap) |
| PR9 text typed in an entry, Cmd+P: print and document both have it | COVERED | X-8 (shared `guarded` settle, `page_flows.dart:171`) |
| PR10 busy while print dialog up: Print, Save, Export disabled | SPLIT | -open: app wraps `PagePrinter` to set busy; Save/New/Open callbacks no-op. Intent COVERED: PF7 (host print holds the bar's Print and Export) |

Totals: SPLIT 4, COVERED 4, PORT 2.

## export/export_end_to_end_test.dart (1)

| case | disposition | destination / reason |
|---|---|---|
| E2E Open sample, Save, Export PDF, Export PNG 150 dpi, Print, Save: second Save byte-identical | PORT | app exit-gate test; document unchanged by exports (X-4), `controller.dirty` false afterwards |

Totals: PORT 1.

## export/export_font_test.dart (7 in scope; EF4-EF8 are not 3b)

| case | disposition | destination / reason |
|---|---|---|
| EF1 app font equals the vendored one | COVERED | P `fonts/plan_assets_test.dart` W-F1 (font is the vendored face byte for byte) |
| EF2 licence equals the vendored one | COVERED | W-F1 (same test also compares `Roboto_LICENSE.txt`) |
| EF3 README records the SHA-256 | DROPPED | the app owns no font copy or README; the plan package's `assets/fonts/README.md` records the digest but nothing asserts it |
| EF4-EF8 | not 3b | ported in 3a/2a: P `export/export_font_test.dart` (EF4, EF5, EF7, EF8) and P `fonts/plan_assets_test.dart` (W-F2 for EF6) |
| EF9 app hands its cache to the host, keeps it across a swap | SPLIT | -open: one `PlanController` kept across New/Open, so its font cache survives; intent (font read once, across swaps) pins EF7 only per cache |
| EF10 without a cache the app makes one over the bundled font | COVERED | EF4 and PF13 (controller default fonts); default-wiring itself unpinned |
| EF11 main() registers the licence before runApp | PORT | new main: `ensureInitialized`, `await ensurePlanFonts()`, `registerFontLicences()`, `runApp` (source pin) |
| EF12 pubspec declares bare family Roboto from the planner package's font | PORT | asset path becomes `packages/jet_cad_2d_plan/fonts/Roboto-Regular.ttf` (per P `assets/fonts/README.md`) |

Totals (7 in scope): COVERED 3, DROPPED 1, SPLIT 1, PORT 2. Not 3b: 5.

## symbols/symbol_library_loader_test.dart (15)

| case | disposition | destination / reason |
|---|---|---|
| premise: real asset holds many symbols | COVERED | K `furniture/furniture_library_test.dart` "ships 41 symbols in six categories" |
| SL1 loading -> ready, one notification, one read | COVERED | P `controller/symbols_controller_test.dart` S-9; P `symbols/plan_symbol_loader_test.dart` S-7 (read once) |
| SL2 missing asset (read throws) fails | COVERED | S-5 (a throwing read is skipped, one libraryUnreadable, error kept) |
| SL3 corrupt bytes -> SymbolLibraryError | COVERED | S-5 (bytes that do not decode) |
| SL4 decoder refuses an upper-case tag | COVERED | S-5 (error isA SymbolLibraryError); the tag rule itself belongs to jet_cad_2d_kit's decoder |
| SL5 any throw fails, Error as well as Exception | COVERED | S-5 (`StateError`) |
| SL6 retry reads again and reaches ready | COVERED | P `controller/symbols_controller_test.dart` S-12; P `panels/plan_symbol_gallery_test.dart` "a failed load shows its message and Retry; Retry reaches ready (M-09b10)" |
| SL7 retry from loading or ready does nothing | COVERED | S-12 (from ready); the from-loading half unpinned |
| SL8 load after dispose reads nothing; late load neither notifies nor throws | COVERED | P `symbols/plan_symbol_loader_test.dart` S-8; symbols_controller_test S-13 |
| SL9 default read loads the declared asset through rootBundle | COVERED | I `furniture/furniture_load_test.dart` FU-load; K `furniture/package_assets_test.dart` PA2 |
| SL9b app reads furniture, then restaurant | SPLIT | -open: only the architecture kit's furniture (41 symbols, six categories): COVERED by K `furniture_library_test` "ships 41 symbols in six categories" and FU-load. Intent (thumbnail capacity >= symbol count): `kPlanThumbnailCapacity` = 128, unpinned |
| SL9c app makes its own loader over both libraries | DROPPED | restaurant premise and `kAppSymbolSources` gone; controller owns loader and cache (S-11) |
| SL10 given loader loaded once, handed to shell before/after swap, not disposed | COVERED | symbols_controller_test S-11 (shared loader not disposed), plan_symbol_loader_test S-7 (read once across loads) |
| SL11 no loader: app makes one and disposes it with itself | COVERED | symbols_controller_test S-11 (its own are disposed), FU-load (production path through the bundle) |
| SL12 a bare shell has no loader | DROPPED | `PlannerShell` API gone; P `editor/plan_editor_test.dart` ED-1 pins "a kit without symbols offers no Symbols tab" |

Totals: COVERED 12, SPLIT 1, DROPPED 2.

## symbols/symbol_shell_test.dart (SS1-SS15; SS16 and SS17 already in 3a)

| case | disposition | destination / reason |
|---|---|---|
| SS1 bare shell no tabs; app shell has the strip, Tools first | COVERED | P `editor/plan_editor_test.dart` ED-2 (Tools and Symbols tabs, Tools first), ED-1 (kit without symbols: no tabs) |
| SS2 tabs switch the panel's content and change no tool | PORT | library gap: ED-2 pins the switch to Symbols; tab back to Tools and "no tool change" unpinned |
| SS3 cell tap arms the tool, clears selection, highlights the cell | COVERED | P `panels/plan_symbol_gallery_test.dart` "the highlight follows the active tool and the armed entry (M-09b9)", P `controller/plan_controller_test.dart` C9 (kit tool clears the selection), P `controller/symbols_controller_test.dart` S-14 |
| SS4 armed, R and M turn/mirror next placement; W chooses Wall | COVERED | P `tools/plan_symbol_tool_test.dart` "keys compose (R, R, M) and work mid-press; the tool keeps them", "armed, not pressed: every key but R and M bubbles"; I `attach/wall_attach_tool_test.dart` "R and Shift+R while attached change the turn count only" |
| SS5 Esc returns to Select, highlight clears; another tool clears it | COVERED | gallery "the highlight follows..." (another tool chosen clears the highlight), P `shortcuts/plan_shortcuts_test.dart` KB-4 (idle Escape arms plan.select) |
| SS6 tab strip and cells take no focus | PORT | library gap: only the search field/clear/Retry focus is pinned (`canTakeFocus` in plan_symbol_gallery_test); strip and cells unpinned |
| SS7 swap leaves no armed tool; old tool and armed symbol disposed | SPLIT | old premise impossible: `armedSymbol` is controller-level and survives `newPlan` (fact 4). -open: after New the active tool is Select and the gallery highlight clear. Intent COVERED: P `controller/lifetimes_test.dart` C-life1 (`activeTool == plan.select` after a swap); whether the armed symbol should reset is a 3b spec decision |
| SS8 mid-shape rule: Save disabled during a press | SPLIT | -open: `toolbar-save` disabled mid-press through `PlanEditor` (library `_idleFlag`, unpinned). Intent COVERED: P `tools/plan_symbol_tool_test.dart` "isMidShape is true between press and release, and notifies" |
| SS9 given thumbnail cache handed to the panel, not disposed | COVERED | symbols_controller_test S-11 (shared loader and cache not disposed by the controller) |
| SS10 no cache: app makes one, disposes it with itself | COVERED | S-11 (its own are disposed) |
| SS11 shell given a loader and no cache makes and disposes its own | COVERED | S-11 |
| SS12 "bed" typed, Tools and back: field and gallery keep it | PORT | library gap: `PlanEditor` owns `_symbolQuery` (plan_editor.dart:260); only the gallery half is pinned ("a gallery built over a controller that already reads \"bed\" opens filtered, the clear button showing (M-09c-t)") |
| SS13 document replacement keeps the search text | SPLIT | -open: same editor across New/Open sample (controller identity kept), text survives. Intent unpinned beyond the gallery tests |
| SS14 panel gone, controller usable; host's, goes with the app; new app starts empty | SPLIT | -open: the editor owns the query; a new editor starts empty, disposed with the editor (unpinned). Intent COVERED: P `panels/plan_symbol_gallery_test.dart` "the gallery gone, the controller stays usable: not disposed, and the gallery's listener removed (M-09c-t2, M-09c-t3)" |
| SS15 bare shell given a loader keeps its own query across a tab switch | DROPPED | `PlannerShell(symbols:)` gone; the intent is SS12's |

Totals: COVERED 7, PORT 3, SPLIT 4, DROPPED 1. Already 3a (not counted): SS16, SS17.

## symbols/symbol_palette_end_to_end_test.dart (1)

| case | disposition | destination / reason |
|---|---|---|
| E2E Symbols tab, search "bed", tap double bed, press, R mid-press, release near a line: one instance, one quarter turn; undo/redo; Save As -> Open -> Save | PORT | app e2e; the library halves exist (I `attach/wall_attach_end_to_end_test.dart` WE1 arms from the Symbols tab; plan_symbol_tool_test), the file round trip and the thumbnails from the cache do not; `bed.double@1` -> `architecture.bed.double@1` |

Totals: PORT 1.

## symbols/symbol_section_end_to_end_test.dart (1) [WE3]

| case | disposition | destination / reason |
|---|---|---|
| WE3 double bed on a 30 deg wall, dragged along it, onto a 120 deg wall; Size/Rotation/Mirror one step each; undo/redo four; Save As -> Open -> Save | PORT | app e2e; library halves I `attach/symbol_move_test.dart` MV4, P `panels/symbol_section_test.dart` SW2, SW3 |

Totals: PORT 1.

## symbols/wall_attach_end_to_end_test.dart (not 3b)

| case | disposition | destination / reason |
|---|---|---|
| WE1 | already 3a | I `attach/wall_attach_end_to_end_test.dart` WE1 |
| WE2 | not 3b | not ported (C7, decision 9) |

## layers/layer_panel_test.dart (26)

Every case below has a same-named test (name compared programmatically) in P `panels/layer_panel_test.dart`, "assertions unchanged", except the last one.

| case | disposition | covering test |
|---|---|---|
| rows: layer 0 first, then by name under toLowerCase | COVERED | P `panels/layer_panel_test.dart` same name |
| the current mark, the eye, the lock and the colour: each one command, dirty, undone | COVERED | same name |
| choosing a layer's own colour, or tapping the current mark of the current layer, dispatches nothing | COVERED | same name |
| swatches: ACI 7 in the paper's foreground | COVERED | same name |
| disabled: hiding the effective current layer ...; delete on layer 0 ... | COVERED | same name |
| delete: a stored current layer that is hidden and empty ... (D3, O3) | COVERED | same name |
| delete: one command, dirty, the row goes; undo brings it back | COVERED | same name |
| S-6: a file with hidden layer 0 and an unusable stored current layer | COVERED | same name |
| S-5: showing a hidden stored current layer makes it current again | COVERED | same name |
| rename: a double-click opens the field ... Enter commits the trimmed name | COVERED | same name |
| rename: Enter on B (ACI 5, locked) changes the name only | COVERED | same name |
| rename: a blur-rename then a tap on the same row's lock ... | COVERED | same name |
| rename: an invalid name on Enter keeps the field open with the reason | COVERED | same name |
| rename: a case-only rename is valid | COVERED | same name |
| rename: Escape with a valid new name reverts | COVERED | same name |
| rename: focus loss: an invalid name reverts, a valid one commits once | COVERED | same name |
| rename: layer 0 cannot be renamed | COVERED | same name |
| no shell shortcut fires while typing | COVERED | same name |
| + adds `Layer N` ... | COVERED | same name |
| read-only: every control is disabled and nothing is dispatched | COVERED | same name |
| the list follows a direct table write and a header change | COVERED | same name |
| the header collapses and reopens the list | COVERED | same name |
| another document: the panel moves its subscriptions | COVERED | same name; also P `panels/layer_page_controller_test.dart` LP-1 |
| in the app: panel between the Selection and Page panels; Open shows the opened file's layers and current layer; a control makes the session dirty | COVERED | P `editor/plan_editor_test.dart` ED-1 (Layers section between property panel and page panel), LP-1 (load shows the new rows), "the current mark, the eye, the lock and the colour: each one command, dirty ..." |
| a loaded layer whose stored name fails D4: its eye hides it | COVERED | same name |
| a command the document refuses is caught | COVERED | same name |

Totals: COVERED 26.

## layers/layer_picker_test.dart (12 in scope; the wall case "in the app: below the Selection section's type section for a wall" went to 3a)

| case | disposition | covering test / reason |
|---|---|---|
| shown for a line-only selection ...; choosing layer 0 is one command | COVERED | P `panels/layer_picker_test.dart` same name |
| a mixed selection moves in one undo step | COVERED | same name |
| a region picked on its boundary moves every fill of it | COVERED | same name |
| the label: "Mixed" ... | COVERED | same name |
| a selection already on the target dispatches nothing | COVERED | same name |
| moving to a hidden layer is allowed and empties the selection | COVERED | same name |
| read-only disables it with the reason | COVERED | same name |
| a plain (non-parametric) group disables it | COVERED | same name |
| every registered parametric type (box, wall, opening, separator, room, dimension) alone | SPLIT | -open: the six architecture types alone enable the picker and show their layer (no such test in I/K: add to I `layers/`). Intent COVERED: P `panels/layer_picker_test.dart` "every registered parametric type (the mark kit's one type, on four layers) alone ..." |
| the picker needs components, not transform | COVERED | same name |
| the no-op rule compares the stored ObjectLayer | COVERED | same name |
| a move the document refuses (regeneration throws on a broken file) is caught | COVERED | P `panels/layer_page_controller_test.dart` LP-7 (the picker's catch; the P port header names it), P `kits/failure_flow_test.dart` F-9 |

Totals: COVERED 11, SPLIT 1.

## layers/layers_end_to_end_test.dart (1)

| case | disposition | destination / reason |
|---|---|---|
| E2E make a layer, make it current, draw a line and a wall on it, hide/show, move the wall with the picker, Save, Open, Save | PORT | app e2e; palette keys `tool-line`, `tool-architecture.wall`; painted-frame check via the canvas painter |

Totals: PORT 1.

---

## Per-file totals

| file | cases | PORT | COVERED | DROPPED | SPLIT |
|---|---|---|---|---|---|
| document_commands | 16 | 9 | 2 | 1 | 4 |
| document_exit | 8 | 8 | 0 | 0 | 0 |
| document_files_kind | 7 | 7 | 0 | 0 | 0 |
| document_files_sources | 3 | 3 | 0 | 0 | 0 |
| document_files | 8 | 8 | 0 | 0 | 0 |
| document_host | 7 | 3 | 0 | 1 | 3 |
| document_open | 6 | 3 | 3 | 0 | 0 |
| document_replace | 11 | 11 | 0 | 0 | 0 |
| document_save | 7 | 7 | 0 | 0 | 0 |
| document_separator | 3 | 3 | 0 | 0 | 0 |
| document_settle | 9 | 7 | 0 | 0 | 2 |
| app_words | 4 | 4 | 0 | 0 | 0 |
| export_flow | 16 | 5 | 5 | 0 | 6 |
| print_flow | 10 | 2 | 4 | 0 | 4 |
| export_end_to_end | 1 | 1 | 0 | 0 | 0 |
| export_font (EF1-3, EF9-12) | 7 | 2 | 3 | 1 | 1 |
| symbol_library_loader | 15 | 0 | 12 | 2 | 1 |
| symbol_shell (SS1-15) | 15 | 3 | 7 | 1 | 4 |
| symbol_palette_end_to_end | 1 | 1 | 0 | 0 | 0 |
| symbol_section_end_to_end (WE3) | 1 | 1 | 0 | 0 | 0 |
| layer_panel | 26 | 0 | 26 | 0 | 0 |
| layer_picker (12 of 13) | 12 | 0 | 11 | 0 | 1 |
| layers_end_to_end | 1 | 1 | 0 | 0 | 0 |
| **Grand total** | **194** | **89** | **73** | **6** | **26** |

Not counted: EF4-EF8 (5, "not 3b"), WE2 (1, "not 3b"), SS16, SS17, WE1 and the layer picker's wall case (4, already 3a). Cases classified: 194 + 5 + 1 + 4 = 204 of the in-scope lists' test ids.

## Decisions the 3b spec has to take (surfaced by the audit)

1. How the app gates New/Open/Save/Save As/Undo/Redo/Export/Print while busy (facts 1, 2): callbacks no-op, permissions, an exit-request path that sees the export dialog and print job through wrapped `onExportDialog` and `PagePrinter`.
2. Where "Open sample" lives in the bar (fact 5) and what titles the error dialog carries for a failed export versus print (fact 3).
3. Whether `armedSymbol` should reset on `newPlan`/`load` (SS7).
4. The plan file extension and `FileKind.jetplan` (DF1, FK4): the library has no constant.
5. Library gaps found (candidate tests, in P or in the app): file-button mid-shape gating, redo chords and Cmd+P, per-platform tooltip glyphs, `PrintingPagePrinter` channel test (PR8), Escape in `PlanExportDialog`, tab strip/cell focus, search text surviving a tab switch in `PlanEditor`, Export/Print flags following a page attached/undone/redone.
