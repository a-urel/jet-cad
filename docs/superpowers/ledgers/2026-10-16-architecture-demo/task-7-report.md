# Task 7 report: symbols and layers through the app; the library gaps

Status: DONE (no LG case was red on today's library; nothing for a fix task).
One concern to read: the carried "remove `symbols:`" mutation is an equivalent mutant (see Concerns).

Commits:
- 486e19be test(demo): symbols and layers through the app
- 40ec1062 test(demo,plan): the library gaps pinned

Gates, real last lines (run after both commits, worktree clean):
- apps/architecture_demo: `flutter test` -> `00:32 +171: All tests passed!`; `flutter analyze` -> `No issues found! (ran in 3.5s)`; `dart format --output=none --set-exit-if-changed .` -> `Formatted 43 files (0 changed) in 0.08 seconds.` (exit 0)
- packages/jet_cad_2d_plan: `flutter test --enable-vmservice` -> `02:00 +1558: All tests passed!`; analyze `No issues found! (ran in 4.0s)`; format `Formatted 301 files (0 changed) in 0.75 seconds.`
- packages/jet_cad_2d_integration: `flutter test --enable-vmservice` -> `00:56 +228: All tests passed!`; analyze `No issues found! (ran in 3.8s)`; format `Formatted 80 files (0 changed) in 0.21 seconds.`
No library lib/ file changed (every library edit below was a scratch mutation, reverted by `git checkout -- <file>`, `git diff --quiet` exit 0 after each). No analysis_options.yaml touched.

## Files
App (apps/architecture_demo/test): support/symbol_rig.dart (helpers), symbols/symbol_library_loader_test.dart, symbols/symbol_shell_test.dart, symbols/symbol_palette_end_to_end_test.dart, symbols/symbol_section_end_to_end_test.dart, layers/layers_end_to_end_test.dart, library_gaps_test.dart.
Integration: packages/jet_cad_2d_integration/test/layers/layer_picker_types_test.dart.
Plan: packages/jet_cad_2d_plan/test/export/page_printer_test.dart (new, PP-1), export/export_dialog_test.dart (X-9b added).

## Audit rows

### symbols/symbol_library_loader_test.dart (15)
- premise (41 symbols, six categories): COVERED, checked: packages/jet_cad_2d_kit_architecture/test/furniture/furniture_library_test.dart:68
- SL1: COVERED, checked: packages/jet_cad_2d_plan/test/controller/symbols_controller_test.dart:44 (S-9), test/symbols/plan_symbol_loader_test.dart:161 (S-7)
- SL2, SL3, SL4, SL5: COVERED, checked: plan_symbol_loader_test.dart:110 (S-5: throwing read, undecodable bytes, Error as well as Exception; the tag rule is the kit decoder's)
- SL6: COVERED, checked: symbols_controller_test.dart:148 (S-12); panels/plan_symbol_gallery_test.dart:174 ("a failed load shows its message and Retry")
- SL7: COVERED, checked: symbols_controller_test.dart:148 (S-12, from ready; from loading unpinned, as the audit says)
- SL8: COVERED, checked: plan_symbol_loader_test.dart:192 (S-8), symbols_controller_test.dart:204 (S-13)
- SL9: COVERED, checked: jet_cad_2d_integration/test/furniture/furniture_load_test.dart:26 (FU-load); jet_cad_2d_kit_architecture/test/furniture/package_assets_test.dart:43 (PA2)
- SL9b: SPLIT. SL9b-open (app lists the kit's 41 symbols, six categories, kit-only, kit order, no diagnostics) and SL9b (the thumbnail cache holds at least every symbol: `kPlanThumbnailCapacity` 128 >= 41, was unpinned) in symbol_library_loader_test.dart.
- SL9c: DROPPED (audit). SL10, SL11: COVERED, checked: symbols_controller_test.dart:109 (S-11). SL12: DROPPED (audit).

### symbols/symbol_shell_test.dart
- SS1: COVERED, checked: packages/jet_cad_2d_plan/test/editor/plan_editor_test.dart:111 (ED-2), :72 (ED-1); added SS1-app (the app's editor has the strip, Tools first, 41 symbols).
- SS2: PORT, SS2.
- SS3: COVERED, checked: panels/plan_symbol_gallery_test.dart:426 (highlight follows tool and armed entry), controller/plan_controller_test.dart:196 (C9), controller/symbols_controller_test.dart:224 (S-14). Added F-2 (a cell tap in the app arms plan.symbol, clears the selection of a real wall, highlights the cell).
- SS4: COVERED, checked: tools/plan_symbol_tool_test.dart:844 and :945; jet_cad_2d_integration/test/attach/wall_attach_tool_test.dart:492.
- SS5: COVERED, checked: plan_symbol_gallery_test.dart:426 (another tool chosen clears the highlight); shortcuts/plan_shortcuts_test.dart:255 (KB-4).
- SS6: PORT, SS6 (strip nodes and cell nodes cannot take focus; canvas keeps it).
- SS7: SPLIT per decision 7. SS7-open (after New `armedSymbol` is still the armed bed, active tool plan.select) and SS7 (intent: active tool Select, no armed cell highlighted, Tools and Symbols tabs both show no armed cell). Intent also COVERED, checked: controller/lifetimes_test.dart:23 (C-life1).
- SS8: SPLIT. SS8-open (Save disabled between press and release of a symbol placement, enabled after). Intent COVERED, checked: plan_symbol_tool_test.dart:406.
- SS9, SS10, SS11: COVERED, checked: symbols_controller_test.dart:109 (S-11).
- SS12: PORT, SS12.
- SS13: SPLIT. SS13-open (New, then Open sample: same PlanEditor state, same search controller, text kept).
- SS14: SPLIT. SS14-open (controller usable with the gallery gone, goes with the editor, a new app starts empty). Intent COVERED, checked: plan_symbol_gallery_test.dart:289.
- SS15: DROPPED (audit).

### symbols/symbol_palette_end_to_end_test.dart: E2E PORT
`bed.double@1` is `architecture.bed.double@1`. Decided (in the file header): premise impossible for the recording thumbnail cache (the app injects none); the cell is checked to show a non-null image once rendered.
The snap oracle changed too: the old test computed the release point with `resolveDragPoint` over the shell's index; `PlanController.index/snap/page` are @internal, so the oracle is the line's end (premises: raw is > 50 mm away, the page grid alone would resolve elsewhere, the press is > 1000 mm away).

### symbols/symbol_section_end_to_end_test.dart: WE3 PORT
Decided (in the file header): premise impossible for the byte-for-byte `attachToWall` oracle (the plan's move resolver is internal and its query carries the drag's own keep/exclude; library: jet_cad_2d_integration attach/symbol_move_test.dart MV4). The committed transforms are checked for flushness against the face (drawn vertices on the face line, turned to it), one undo step, the slide along the face ("about 700 mm"), and the Size/Rotation/Mirror rows as before (corner stays, about the insertion point, footprint kept, undo four equals the document after the first move, redo four equals the edited bytes, Save As -> Open -> Save byte-identical). The seed assertion no longer hard-codes five copied handles: it asserts the seed does not rewind and differs from the pre-copy seed.

### layers/layer_panel_test.dart (26): all COVERED
25 of the 26 have an identically named test in packages/jet_cad_2d_plan/test/panels/layer_panel_test.dart (names compared by script: 25 OK, 1 missing, the app case below). Opened by hand, in addition: "rows: layer 0 first" (:152), "the current mark, the eye, the lock and the colour" (:194), "delete: one command, dirty, the row goes; undo brings it back" (:382), "read-only: every control is disabled" (:722), "the header collapses" (:805), "another document" (:819).
- the app case ("in the app: panel between the Selection and Page panels; Open shows the opened file's layers and current layer; a control makes the session dirty"): COVERED, checked: editor/plan_editor_test.dart:72 (ED-1, Layers section between the property panel and the page panel, asserted by the top coordinates), panels/layer_page_controller_test.dart:123 (LP-1, a load swaps the document under the panel, new rows show, the old document loses the listener), panels/layer_panel_test.dart:194/:382 (a control makes the session dirty: `session.dirty`).
And the app e2e covers Open showing the layers and the current layer (layers_end_to_end_test.dart: `isCurrentRow`, `nameOfRow` after Open).

### layers/layer_picker_test.dart (12 in scope)
Name comparison by script: 10 of the 13 old names are identical in packages/jet_cad_2d_plan/test/panels/layer_picker_test.dart (shown for a line-only selection :202, mixed selection :225, region boundary :269, the label :282, already on the target :305, hidden/locked target :342, read-only :362, plain group :398, needs components :462, no-op rule :493); the other three are the rows below.
- those ten: COVERED. Opened by hand: "a mixed selection ... moves in one undo step" (:225), "the no-op rule compares the stored ObjectLayer" (:493).
- "a move the document refuses ... is caught": COVERED, checked: panels/layer_page_controller_test.dart:319 (LP-7, a lock refuses the choice at commit; caught, nothing changes, nothing raised, lock hint), kits/failure_flow_test.dart:364 (F-9, `execute` answers false for a refused edit). (The audit's regeneration-throws premise is F-9's refused edit; LP-7 is the picker's own catch.)
- "every registered parametric type": SPLIT. -open: packages/jet_cad_2d_integration/test/layers/layer_picker_types_test.dart (box, wall, opening, separator, room, dimension alone enable the picker and show their layer; the separator moves to D with one step and its children follow). Intent COVERED, checked: panels/layer_picker_test.dart:423.
- "in the app: below the Selection section's type section for a wall": already 3a (jet_cad_2d_integration/test/layers/layer_picker_wall_test.dart).

### layers/layers_end_to_end_test.dart: E2E PORT
Palette keys are `tool-plan.line` and `tool-architecture.wall`; the painted frame is checked through `DraftCanvasState.painter.debugOnVisit` as before.

### Library gaps (spec decision 10), library_gaps_test.dart
LG1 (4 buttons disabled and Cmd+S, Ctrl+S inert with the Wall tool pressed, nothing written, nothing asked; after Escape both work), LG2 (Cmd and Ctrl forms of S, Shift+S, O, N, P; ten tests), LG3 (Cmd+Shift+Z, Ctrl+Shift+Z, Ctrl+Y each redo; Shift+Z alone does not), LG4 (Tab and Shift+Tab never land on a cell or the strip; tab switches change no tool, with the Wall tool and with an armed symbol), LG5 (search text survives a tab switch and a New), LG6 (Export and Print follow the page: detached, undone, redone). All green on today's library; none needed a fix task.
Per-platform tooltip glyphs: already DC1b (document_commands_test.dart).
Decided (file header): LG6's "page panel's off switch" does not exist (the panel has no control that detaches the page); the document command does it, as EX9b. LG4's "Tab moves from the search field to the first cell" differs: the gallery is in `ExcludeFocus` (Ruling 05-6), so Tab lands on the canvas; the case pins that.
Many of these were already pinned in part by Task 4's and Task 6's ports (DC2 redo chords, DC4 the Cmd and Ctrl file chords, DC5 mid-shape buttons, DC1b tooltips, PR6 Cmd+P, EX9b page follow, SS12/SS13-open search text): the table below says which tests each mutation reds. Not covered before: Cmd+S/Ctrl+S inert mid-shape (LG1) and the Tab/Shift+Tab focus walk (LG4); LG3 and LG5 are redundant with DC2 and SS13-open (both red under the same mutations).

### Library-side gaps (Step 3), packages/jet_cad_2d_plan/test
- PR8 `PrintingPagePrinter` hands `Printing.layoutPdf` the name and format: the `printing` package has no Dart-side platform mock, but it speaks a method channel (`net.nfet.printing`), so the library test PP-1 (export/page_printer_test.dart) drives it at the channel: name, width/height in pt, `dynamic: false`, `onLayout` returns the given bytes whatever paper the dialog asks for, and the call waits for `onCompleted`. PR8 is therefore not DROPPED. (Task 6 already ported the same case into the app, print_flow_test.dart PR8; both stay.)
- Escape in `PlanExportDialog` pops null: X-9b in export/export_dialog_test.dart (Escape after a choice was made answers null, nothing leaks).

## Mutations (each run on committed code, reverted with git checkout -- <file>, git diff --quiet exit 0)

| mutation (file) | red tests |
|---|---|
| M-SS7: host `newFlow` re-arms the symbol tool after `newPlan` (lib/document_host.dart) | SS7, SS7-open |
| M-SS2/LG4b: editor tab switch calls `selectTool('plan.select')` (plan_editor.dart `onSelectionChanged`) | SS2, LG4 (tabs arm no tool) |
| M-SS6a: `ExcludeFocus(excluding: false)` around the tab strip (plan_editor.dart) | SS6, LG4 (focus walk) |
| M-SS6b: `ExcludeFocus(excluding: false)` in the gallery (jet_cad_2d_flutter symbol_gallery.dart) | SS6, LG4 (focus walk) |
| M-LG1/SS8: `enabled: ValueNotifier(true)` in place of `_idleFlag!` in all four file buttons (plan_editor.dart) | LG1, SS8-open, DC5, DC6 |
| M-LG2: drop the meta half of `_chord` (shortcuts/chords.dart) | 48 app tests red; in library_gaps_test.dart alone: 8 red in library_gaps_test.dart alone: LG1, the five Cmd cases of LG2 (S, Shift+S, O, N, P), LG3 and LG6 (both use Cmd chords); also CH-consume Meta+S, DC2, DC10, DC11 ... |
| M-LG3a: drop Ctrl+Y from `kRedoChords` | LG3, DC2 |
| M-LG3b: replace `_chord(keyZ, shift)` by Ctrl+Shift+Z alone (drops Cmd+Shift+Z) | LG3, LG6, symbol palette E2E, WE3 (all redo with Cmd+Shift+Z), DC2 |
| M-LG5: `_symbolQuery.clear()` when the editor's document changes (plan_editor.dart `_onController`) | LG5, SS13-open |
| M-SS12: the gallery gets a fresh `TextEditingController()` at each build (plan_editor.dart `_galleryOf`) | SS12, SS13-open, SS14-open, LG5 |
| M-SS14: `_symbolQuery.dispose()` removed from the editor's dispose | SS14-open |
| M-LG6a: `_exportFlag` computed once at bind | LG6, EX9b, PR10-open |
| M-LG6b: `_printFlag` computed once at bind | LG6, EX9b, PR10-open |
| M-L3: the app's controller is given a disposed `PlanSymbolLoader` (lib/main.dart) | SL9b-open, SL9b, F-2, SS1-app ... (16+ red: the Symbols tab has no furniture) |
| M-SS1: `PlanEditor(gallery: false)` in the host | SS1-app, SL9b-open, palette E2E, WE3, 9 more |
| M-SL9b: `kPlanThumbnailCapacity = 16` | SL9b |
| M-F2: `selectTool` no longer clears the selection (plan_controller.dart) | F-2 |
| M-WE3a: `rotatedTo` about `t(0)` in place of the insertion point (symbol_section.dart) | WE3 (`about the insertion point`: actual 1345.36 >= 1e-6) |
| M-WE3b: `PlanMoveResolver.resolveMove` returns null at once (move_resolver.dart) | WE3 |
| M-E2E-R: R mid-press leaves `_quarterTurns` alone (plan_symbol_tool.dart) | palette E2E |
| M-E2E-snap: the tool's `resolveDragPoint` called with `objectSnap: false` | palette E2E |
| M-LE2E-picker: `LayerPicker._choose` returns at once | layers E2E |
| M-LE2E-current: the current mark makes layer 0 current (plan_layer_panel.dart) | layers E2E |
| M-LE2E-eye: the eye toggles to the same visibility | layers E2E |
| M-L1: `LayerPicker._isObject` always false | layer_picker_types_test.dart (integration) |
| M-PP1a: `dynamicLayout: true` (page_printer.dart) | PP-1 |
| M-PP1b: `format:` dropped | PP-1 |
| M-PP1c: `name:` dropped | PP-1 |
| M-X9b: `showDialog(barrierDismissible: false)` (export_dialog.dart) | X-9b |
| M-L2 (carried from Task 2): `symbols: _symbols` removed from the app's controller (lib/main.dart) | NONE: `00:31 +171: All tests passed!` |

## Concerns
1. M-L2 (carried from Task 2) is an equivalent mutant, not a test gap. A `PlanController` given no loader makes its own `PlanSymbolLoader`, reading the same kit sources and disposing it with itself (plan_controller.dart:339-340), so the Symbols tab shows the same 41 symbols. The furniture palette is pinned through the app (SL9b-open, SL9b, F-2, SS1-app, palette and section E2Es: M-L3 and M-SS1 turn 16+ tests red), but dropping the argument leaves the app's `_symbols` loader unused. Pinning "the app's loader is the controller's loader" would need a test accessor on `ArchitectureDemoAppState`, or removing the app's loader field (the simpler change: the app then never owns a loader). Controller's call.
2. WE3's byte-level `attachToWall` oracle is replaced by flushness (header). The resolver's exact answer is pinned by jet_cad_2d_integration attach/symbol_move_test.dart MV4 and the wall attach E2E.
3. The page panel has no switch that detaches the page (the brief's LG6 wording); the case uses the document command, as EX9b.
4. The palette E2E no longer compares the cell's image with the cache's futures (the app injects no cache).
