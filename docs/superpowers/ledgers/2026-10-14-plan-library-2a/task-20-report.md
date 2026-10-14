# Task 20 report: PlanEditor, PlanEditorBar, the example, README, CHANGELOG

Status: DONE_WITH_CONCERNS (one ported test not ported: RV6, a finding; see Concerns).

Commits (BASE 826ee7e1):
- `112e734b` feat(plan): PlanEditor, PlanEditorBar, the example and the README
- `bda9859b` test(plan): the editor's ported bar, view, options, words and theme tests
- `1ed407b8` test(plan): ED-X2 presses Ctrl+E too; M-ED-13 named at its red line

## Implemented

- `lib/src/editor/plan_editor_bar.dart`: `PlanEditorAction`, `PlanEditorBar` (==, hashCode, toString), `validatePlanEditorBar` (brief verbatim).
- `lib/src/editor/plan_editor.dart`: `PlanFileCallback`, `PlanEditor` with every P2/P7 option of the brief (toolPalette, gallery, symbolFilter, propertyPanel, layerPanel, pagePanel, rulers, grid, snapping, bar, onNew/onOpen/onSave/onSaveAs, onExport, onExportDialog, onPageFlowError, printer, exportName, shortcuts, autofocus, theme). The bar (host file commands before Export/Print, Undo/Redo by `permissions`, the status line, the damaged warning, the read-outs, leading/trailing under the guard), the left column (palette, or Tools/Symbols tabs, or the gallery alone), the canvas, the right column (property, layer, page panels kept offstage when hidden), `PlanThemeScope(view: theme)`, `PlanShortcuts` fed by each bar command's `invoke`.
- `strings.dart` + en/de/tr: `newDocument`, `open`, `save`, `saveAs` (the app's words verbatim).
- `lib/jet_cad_2d_plan.dart`: every export through `show`; `SymbolThumbnails`, `PlanEditor`, `PlanFileCallback`, `PlanEditorAction`, `PlanEditorBar` added.
- `lib/src/export/editor_page_flows.dart`: `exportersFor` and `exportRunnable` (carried item 2); the dialog (Material or the host's) is handed only the exporters that can run.
- `lib/src/shortcuts/plan_shortcuts.dart`: the Export chord's rule is `exportRunnable` (Print's stays "a page"); `_run(needsPage:)` became `_run(can:)`.
- `example/main.dart`, `README.md` (its one Dart block is the example, whole), `CHANGELOG.md` (0.8.0 unreleased), verbatim from the brief.
- Tests (new): `test/editor/plan_editor_test.dart` (ED-1..ED-7, ED-L, ED-X1, ED-X2, ED-U, ED-D), `test/example_test.dart` (ED-8, ED-README), `test/barrel_test.dart` (ED-9 with the F6 names, ED-9b), ED-W in `test/l10n/value_words_test.dart`.
- Tests (ported): `test/editor/editor_bar_test.dart` (12), `editor_view_test.dart` (8), `editor_separator_test.dart` (3), `editor_options_test.dart` (19), `editor_words_test.dart` (9), `editor_theme_test.dart` (8), `test/invariants/theme_colours_test.dart` (3).
- Test support: `test/support/editor_host.dart` (with `editorPlanJson({lockedLayer})`, `slowSymbolsKit`), `test/support/recording_plan_strings.dart` (85 overrides, one per `PlanStrings` member, generated from strings.dart as the source's was).

## TDD evidence

RED (new tests written before the editor; `flutter test test/editor/plan_editor_test.dart test/example_test.dart test/barrel_test.dart`):
```
Compilation failed for testPath=.../test/editor/plan_editor_test.dart: test/editor/plan_editor_test.dart:15:8: Error: Error when reading 'lib/src/editor/plan_editor.dart': No such file or directory
Compilation failed for testPath=.../test/example_test.dart: test/example_test.dart:10:8: Error: Error when reading 'example/main.dart': No such file or directory
test/barrel_test.dart:73:19: Error: Method not found: 'PlanEditor'.
test/barrel_test.dart:77:28: Error: Couldn't find constructor 'PlanEditorBar'.
00:00 +0 -3: Some tests failed.
```
ED-W: the four words were added in the same step as ED-W (brief Step 5 bundles them), so ED-W was green on its first run (`00:00 +5: All tests passed!`); M-ED-W below shows it red.

After the editor: first run 14 pass, 2 red (ED-U and ED-D, both fixture issues: ED-U needed two pumps, see carried item 3; ED-D built its JSON inside a State initializer, and `save()` settles focus, which a build may not). Then `00:02 +16: All tests passed!`.

The ported tests were written after the editor compiled (deviation from the brief's step order: they port behaviour and could not compile earlier); each file's first run: editor_bar 12/12, editor_view 8/8, editor_separator 3/3, editor_options 19/19, editor_words 6/9 (OV-H's roots: the line is an entity, not a node; fixed by counting root entities), editor_theme 7/8 (R-4: one controller across keyed apps tripped the one-canvas rule; a controller per app), theme_colours 3/3.

GREEN, final: `cd packages/jet_cad_2d_plan && flutter test` -> `00:36 +714: All tests passed!`.

## Mutations (each on committed files; reverted with `git checkout -- <file>`, then `git diff --quiet -- <file>` -> `revert=0`)

| Mutation | Test | Red line |
|---|---|---|
| M-ED-1 layer/page `_kept` swapped | ED-1 | `Expected: a value less than <114.0> Actual: <718.0>` plan_editor_test.dart line 102 |
| M-ED-2 `_gallery` drops `widget.gallery &&` | ED-2 | `Expected: no matching candidates Actual: ... key [<'left-tabs'>]` line 124 |
| M-ED-3 `_file` without `settlePendingInput()` | ED-3 | `Expected: ['settle', 'new'] Actual: ['new']` line 166 |
| M-ED-4 `_editCommands` tests `true` | ED-4 | `... key [<'toolbar-undo'>]` found, line 200 |
| M-ED-5 damaged builder always shrinks | ED-5 | `Found 0 widgets with key [<'plan-damaged'>]` line 221 |
| M-ED-6 `didUpdateWidget` keeps the old flows | ED-6 | `Expected: false Actual: <true>` line 248 |
| M-ED-7 `PlanThemeScope` replaced by a `Builder` around its child | ED-7 | `Expected: PlanTheme(selectionWidth: 3.5, canvasBackground: ...) Actual: PlanTheme(canvasBackground: ...)` line 274 |
| M-ED-9 `export 'src/kits/guard.dart';` without show | ED-9 | `every export shows: export 'src/kits/guard.dart';` (`Expected: true Actual: <false>`) |
| M-ED-README a comment line appended to example/main.dart | ED-README | `Expected: contains '```dart\n'...` |
| M-ED-W tr `save => 'Save'` | ED-W | `Actual: Set:['Save', 'Speichern'] Which: has length of <2>` |
| M-ED-10 `validatePlanEditorBar` returns at once | BT2 | `Expected: <Instance of 'ArgumentError'> Actual: <null>` editor_bar_test.dart line 220 |
| M-ED-11 `if (lastFile == null) groups.add([])` | "[print, undo] ... 12 px" | `Expected: <64.0> Actual: <52.0>` line 258 |
| M-ED-12 `_leftShown` returns true | T4-j | `key [<'chrome-left'>]` found, editor_options_test.dart line 635 |
| M-ED-13 Export's `permissions.export` dropped | ED-4 and T4-e | ED-4 line 200 (`toolbar-export` found); T4-e line 604 (`toolbar-export` found) |
| M-ED-L1 property panel drops `c.permissions.changeLayer` | ED-L | `key [<'layer-picker'>]` found, line 307 |
| M-ED-L2 picker `isLocked: _never` | ED-L | `Expected: false Actual: <true>` line 315 |
| M-ED-X dialog handed `flows.exporters` | ED-X2 | `key [<'export-format-plan.pdf'>]` found, line 377 |
| M-ED-X `exportRunnable` = page only | ED-X2 | `Expected: not null Actual: <null>` line 369 |
| M-ED-X `exportRunnable` = true | ED-X1 | `Expected: null Actual: <Closure ... 'invoke'>` line 346 |
| M-ED-X3 PlanShortcuts' Export chord `can: _hasPage` | ED-X2 | `Found 0 widgets with key [<'export-dialog'>]` line 401 |
| M-ED-U command sources without `c.canUndo`, `c.canRedo` | ED-U | `Expected: not null Actual: <null>` line 425 |
| M-ED-LK `objectSnapOn` -> literal `'OSNAP!'` | LK1 | `Expected: empty Actual: ['OSNAP!']` editor_words_test.dart line 306 |

## Gates

- `dart format . && dart format --output=none --set-exit-if-changed .` -> `Formatted 177 files (0 changed)`, `format=0`.
- `flutter analyze` -> `No issues found! (ran in 3.2s)`.
- `flutter test` -> `00:36 +714: All tests passed!`.
- `dart pub publish --dry-run` (after the commits) -> `exit=0`, `Package has 0 warnings.` (example/, README.md, CHANGELOG.md in the archive).
- `cd tool/ci && dart test` -> `00:40 +116: All tests passed!`.
- `git status --short` clean after all pub operations (no analysis_options.yaml touched).

## Files

lib: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart`, `.../editor/plan_editor_bar.dart`, `.../l10n/strings.dart`, `strings_en.dart`, `strings_de.dart`, `strings_tr.dart`, `.../export/editor_page_flows.dart`, `.../shortcuts/plan_shortcuts.dart`, `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`; `example/main.dart`, `README.md`, `CHANGELOG.md`.
test: `test/editor/plan_editor_test.dart`, `editor_bar_test.dart`, `editor_view_test.dart`, `editor_separator_test.dart`, `editor_options_test.dart`, `editor_words_test.dart`, `editor_theme_test.dart`, `test/invariants/theme_colours_test.dart`, `test/example_test.dart`, `test/barrel_test.dart`, `test/l10n/value_words_test.dart`, `test/support/editor_host.dart`, `test/support/recording_plan_strings.dart`, `test/controller/symbols_controller_test.dart` (one import).

## Deviations from the brief

1. `_FrameSafeRelay` not re-declared: the editor uses `FrameSafeRelay` (`lib/src/panels/frame_safe_relay.dart`, Task 17's port of the same shell class). Same behaviour, one copy.
2. No outer `PlanTextKeys`: `PlanShortcuts` already wraps its child in `PlanTextKeys`.
3. `_pageFlag` split into `_exportFlag` (idle, flows ready, `exportRunnable`: a page or an exporter that needs none) and `_printFlag` (idle, ready, a page). With the built-in exporters only, identical to the brief's flag and today's `_fileEnabled` (carried item 2).
4. Undo/Redo flags compute `_idle && c.document.commands.canUndo` (live, as today's `DerivedFlag`, planner_shell.dart:728-731); `c.canUndo`/`c.canRedo` stay in the sources only as the "look again" signal (carried item 3).
5. The status relay also listens to `c.activeTool` (the label's source).
6. `toolPalette: false` with the gallery offered shows the gallery alone (no tabs); the brief's code would still have put the palette under a Tools tab.
7. `EditorPageFlows.export` offers the dialog (Material or the host's `onExportDialog`) only the exporters that can run (`exportersFor`); `exportRunnable` added; `PlanShortcuts`' Export chord uses it (Print keeps "a page"). Task 19's own early return (no page and only page exporters) is subsumed (`offered.isEmpty`).
8. M-ED-7 applied as "the scope replaced by a `Builder` around its child" (keeps the call well-formed; same effect: no scope).
9. `slowSymbolsKit` moved from plan_editor_test.dart into `editor_host.dart` (the words test reuses it); `editorPlanJson({bool lockedLayer = false})` adds layer `B` (locked) for the T5-g/R-2/R-3 ports (the brief's "kEmbeddingLocked → layer B ... added to editorPlanJson()'s scratch document").
10. `symbols_controller_test.dart`: its `jet_cad_2d_flutter` import became unnecessary once the barrel exports `SymbolThumbnails` (analyzer info); removed.
11. ED-U needs two pumps (async history stream; see carried item 3). ED-D builds its JSON before the host builds.
12. Extra tests beyond the brief for the carried items: ED-L, ED-X1, ED-X2, ED-U, ED-D.
13. Ported tests, fixture and premise changes (no assertion weakened):
    - BT2: one mode (the service mode is 2b's).
    - editor_options: surface 2400 x 1500 (the source's `kEditorSurface`); `workCamera` (0.2 px/mm, y flipped, the sheet's middle framed) because `embeddingCamera` frames the page's top-left corner and the marks sit around the sheet's centre; T4-f's grid step computed from the camera's scale (the source wrote 0.37, its camera's scale); the "column corner" is the first mark's generated line end `(s, s)` in its frame; the "Wall part-way" R-2 uses a polyline, which needs Enter to finish its last step (the final `depth + 1` unchanged); V-5's letters W, L, F -> P, L, F; `selection-panel` and `table-section` both map to `find.byType(PlanPropertyPanel)`; T4-j's tablesOnly -> `full.copyWith(editLayers: false)` (the brief's R-2 mapping); T4-g's camera and empty sheet band re-chosen for this page (the band above the drawing, under the page's top); the mode round trips (`expectKept`) dropped (2b).
    - editor_words: SW1 `Duvar, Kapı, Ölçü` -> `Çizgi, Daire, Metin`, `Wall` -> `Line`; SW2 `Wand` -> `Linie`, its service-bar lines dropped (its English step asserted only the service bar, so the switch remains with no assertion); OV-<code> over `editorPlanJson()` with `slowSymbolsKit` added for the tabs, its service sweep dropped; OV-H premise `roots > 20` -> `roots == kEditorMarks + 1` (fixture sanity; the line is a root entity, counted), TableSurvey premise dropped; LK1: symbol words from `PlanSymbolWords('tr')` over the loaded symbols, the kits' own `names` words allowed (as the source allowed the furniture names; the mark kit's "Cross"), premise `'Duvar'` -> `'Çizgi'`, service-bar step dropped; PW1's zoom over the editor fixture with its page set to 1:12.5.
    - editor_theme: only `selectionWidth` validation cases (the other fields are 2b's); R-4's `focusVeilOpacity` row dropped (2b); a controller per keyed app in R-4; T1-c's dependent in `PlanEditorBar(leading:)` (no table overlay in 2a).
    - theme_colours: roots `['lib']`; allowed literals `layer_row.dart` and `colour_row.dart`; no whole-file allowance; the scan's own mutants re-pointed at this package's files; premise `files > 100` -> `> 50` (75 files).
    - editor_separator: NS1 and NS6 re-run through the editor with their `panelShows`; NS2 whole. NS3, NS4, NS8 and NS9 have no `panelShows` in the source, so nothing to add (NS3's room label is sub-project 3's).
    - editor_view: "the status text follows the selection" selects the first mark (the source picked a wall).
14. Barrel vs earlier tasks: no difference. ED-9's set (with F6's 15 names) equals the union of what Tasks 6-19 exported; no previously exported public name was dropped by the new `show` lists (each whole-exported file's public top-level names were listed and match).

## Carried items

1. Layer picker (Task 18 cannot-verify): ED-L, through the editor: picker shown for a selection, gone under `changeLayer: false`, back under full; after `lockBroken` the picker is disabled with `lockedNoLayer` as its tooltip; after `load` the new plan's empty selection shows none, a new selection shows its layer, enabled. Red under M-ED-L1 and M-ED-L2. The swap half has no mutation of its own that turns it red alone (the editor's own rebuild and the panel's rebind both refresh it).
2. Page-less export: today's rule kept for the built-ins (Export and its chord disabled without a page, ED-X1); with a host exporter that needs no page, Export is enabled and the dialog lists only the exporters that can run (ED-X2, chord too). Chosen over a message: today never opened the dialog without a page, and the spec (P2) foresees an exporter that needs no page.
3. canUndo lag: today's `FloorPlanController._canUndo` is refreshed from the document's asynchronous change stream (floor_plan_controller.dart:2097-2121; only the table setters refresh synchronously), and today's shell bar re-read `commands.canUndo` on its own `_history` subscription (planner_shell.dart:1045-1049), equally asynchronous; today's A27 comment states it ("the first pump delivers it, the second rebuilds the line"). So today lags too: recorded and kept. The bar's flags read the history live as today's `DerivedFlag` did. ED-U pins it (an edit, two pumps, Undo enabled and undoing; M-ED-U red).
4. DiagnosticsLog after dispose: not reachable from a host that disposes its controller in `State.dispose`: Flutter unmounts an inactive subtree children first, so `PlanEditor.dispose` and every panel's run before the host's; post-frame reports check `isDisposed`. ED-D (positive control, no mutation named) mounts such a host, selects, sets `damaged`, unmounts it and pumps twice: `takeException()` is null. Task 17's spill is the test harness after a failing test (the body throws before the binding's own unmount; `addTearDown(c.dispose)` then runs with the tree still mounted).

## Self-review

- Each option of the brief's constructor is read in build or by the flows at call time; a runtime option change reuses the same element (ED-2, T5-g, T4-f, T4-g, R-2).
- A swapped controller: listener moved, flows replaced, relays and flags rebound, locale pushed (ED-6, NS2).
- The barrel test reads the show lists as text and the expected set is the brief's; ED-9b uses only the barrel.
- Not ported: RV6 (below). Everything else listed in the brief's Step 3 is ported.

## Concerns

- RV6 not ported (a finding, A12): "the view unmounted with Wall active: activeTool select, selectTool false". In the plan library the controller owns the tools, so neither half holds: a probe (temporary test, deleted) printed `before: plan.line`, `after unmount: plan.line`, `selectTool line: true`. Spec P2 lists `selectTool` among the controller's commands with no view requirement. Porting it would need either PlanCanvas cancelling the active tool on dispose (first half) and a "no view, no tools" rule (second half, against P2), or a ruling that RV6 is retired. Left for the controller.
- The Export chord rule in `PlanShortcuts` changed (Task 16's file) to match the editor's Export button; identical with only the built-in exporters.

## Controller ruling RV6

Ruling: split RV6. Commit `ce212b7c` feat(plan): the last canvas to go withdraws its controller's tool (RV6).

- First half ported (`test/editor/editor_options_test.dart`, "RV6 the view unmounted with Line active: activeTool select ..."). The assertion is unchanged; the source's W/Wall becomes L/`plan.line`. Implementation is in `lib/src/canvas/plan_canvas.dart`. `PlanCanvas.dispose` calls `_withdrawTool`, which after the frame cancels the shape in progress and arms `plan.select`. It does this only when no canvas shows the controller any more (a counter per controller, `_mountedOf`, kept in every build mode). If select is already active, it cancels select's own drag or band. Nothing happens once the controller is disposed. The work is deferred to after the frame, as today's `toolChanged` does (floor_plan_controller.dart:746-762). The reason: a canvas is disposed while the element tree is locked, and at that moment a host widget listening to `activeTool` may not rebuild. The source's extra `pump()` after unmounting covers the deferral.
- M-RV6: removing `_withdrawTool(_c);` from `dispose` turns the test red at editor_options_test.dart line 657: `Expected: 'plan.select' Actual: 'plan.line'`. Reverted, `revert=0`.
- Second half retired ("selectTool(wall) is false with no view"). The controller owns the tools and works without a canvas (spec P2). The retirement is noted in the test file's port comment (source: `editor_tools_review_test.dart` RV6, `:343-354`).
- Added to Deviations: a deliberate host-API difference for sub-project 4's parity table. `selectTool` answers true with no view mounted, where today's answered false.
- Gates after the change: `flutter analyze` -> `No issues found!`, `dart format --output=none --set-exit-if-changed .` -> `format=0`, `flutter test` -> `00:38 +715: All tests passed!`, Task 15's canvas tests (`flutter test test/canvas`) -> `00:02 +53: All tests passed!`.
- Not covered by a named mutation: the guard that skips the withdrawal when another canvas still shows the controller. No test swaps canvases in a way that needs it.
- The Concerns entry on RV6 above is superseded by this ruling.

## Fix round 1

Review: task-20-review.md. Commit `e1e577d5` fix(plan): editor options pinned; a swapped canvas withdraws the old tool.

### Changes and covering tests

1. **[Important] Options through PlanEditor.** New tests in `test/editor/plan_editor_test.dart`, group "the options a host passes through":
   - ED-P1: `toolPalette: false` with no symbols leaves no left column.
   - ED-P2: `toolPalette: false` with a kit's symbols shows the gallery alone (no tabs, no palette).
   - ED-F: `symbolFilter` reaches the gallery. A refused symbol has no cell; the others keep theirs.
   - ED-S: under `shortcuts: false`, L reaches a host `CallbackShortcuts` and arms nothing.
   - ED-A1: by default the canvas takes the focus (positive control).
   - ED-A2: `autofocus: false` leaves the canvas without the focus.
   - ED-E: `onPageFlowError` receives a failing printer's `StateError` once, and the flows are ready again.
2. **[Minor] RV6 on a controller swap.** In `PlanCanvas.didUpdateWidget`, `_withdrawTool(old)` follows `_leave(old)`. The `_mountedOf` check after the frame still spares a controller that another canvas shows. New test ED-6b: `one` has a polyline part-way when the editor is handed `two`; after a pump, `one` is not mid-shape and `plan.select` is armed.
3. **[Minor] ED-L's swap half.** The second plan (`layerPlan(more:)`) adds its own layer `D` (unlocked, which the first plan does not have) with a mark on it. After `load`, that mark is selected and the picker must show `D`, enabled. The comment is fixed.
4. **[Minor 5, included] One page rule.** `exportRunnable` is now `exportersFor(controller.document, controller.exporters).isNotEmpty`. Export's enabled state and the dialog's list read the same `exportPageOf` predicate.
5. **[Minor 4, included] Duplicated assertion.** The `findsNothing` that appeared twice in T5-g is now one line, with a comment naming both of the source's keys. In the source these are two different assertions (`selection-panel` and `table-section`); in the port they map to one finder.
6. Minor 3 (unnamed mutations in the ported files) is left for the controller's ruling, as the reviewer suggests.

### Mutations

Each was run on committed files and reverted with `git checkout -- <file>`; `git diff --quiet` gave `revert=0` every time.

| Mutation | Test | Red output |
|---|---|---|
| M-ED-P1: `if (!widget.toolPalette) return false;` removed from `_leftShown` | ED-P1 | `Found 1 widget with key [<'chrome-left'>]`, plan_editor_test.dart line 501 |
| M-ED-P2: `if (!widget.toolPalette) return _galleryOf(c);` removed | ED-P2 | `Found 1 widget with key [<'left-tabs'>]`, line 515 |
| M-ED-F: `filter: null` handed to the gallery | ED-F | `Found 1 widget with key [<'symbol-cell-demo.bed.double@1'>]`, line 545 |
| M-ED-S: `shortcuts: true` handed to PlanShortcuts | ED-S | `Expected: <1> Actual: <0>`, line 565 |
| M-ED-A: `autofocus: true` handed to the canvas | ED-A2 | `Expected: false Actual: <true>`, line 588 |
| M-ED-E: `onError: null` in the editor's hooks | ED-E | `Bad state: no printer` escapes; `Expected: an object with length of <1> Actual: []` (expect at line 609) |
| M-ED-6b: `_withdrawTool(old)` removed from didUpdateWidget | ED-6b | `Expected: 'plan.select' Actual: 'plan.polyline'`, line 636 |
| M-ED-L3: the panel never rebinds to the new document (both rebinds removed, in `_onController` and `build`) | ED-L | `Bad state: No element` at plan_editor_test.dart:354 (`layer-picker-value` absent) |
| M-ED-X re-run on the new `exportRunnable`, made "page only" | ED-X2 | `Expected: not null Actual: <null>`, line 390 |
| M-ED-X re-run on the new `exportRunnable`, made `true` | ED-X1 | `Expected: null Actual: <Closure ... 'invoke'>`, line 367 |

On ED-6b: under the mutation, the `isMidShape` assertion passes. Some other path already cancels the old controller's shape on a swap. What M-ED-6b removes is arming `plan.select`, and the `activeTool` assertion catches that.

### Gates

- `dart format --output=none --set-exit-if-changed .`: `format=0`
- `flutter analyze`: `No issues found!`
- `flutter test`: `00:40 +723: All tests passed!`
- `cd tool/ci && dart test`: `00:44 +116: All tests passed!`
- `git status --short`: clean.

### The expect comparison (the reviewer's cannot-verify)

A script (`expects.py`, kept in the session scratchpad) pairs each ported test with its source test by name. It extracts every `expect(...)` from both bodies, using a bracket matcher that skips string literals and `//` comments. Whitespace is normalised. The source side is renamed only by this list:

- `t.byKey(` -> `byKey(`, `s.encoded(` -> `encoded(`, `s.selected(c)` -> `{...c.selection.keys}`
- `activeDocument` -> `document`, `activeSelection` -> `selection`, `cameraController` -> `camera`
- `FloorPlanEditorBar/Action` -> `PlanEditorBar/Action`
- `FloorPlanView`, `PlannerShell` -> `PlanEditor`
- `FloorPlanTheme` -> `PlanTheme`, `FloorPlanStrings` -> `PlanStrings`
- `view.document/page/camera` -> `c.document/page/camera`
- `.fileName` -> `.name`, `c.pageFlowReady` -> `c.pageFlows.ready`
- `FloorPlanTool.select` -> `PlanToolIds.select`, `kEmbeddingLocked` -> `kEditorLocked`, `t.statusText(` -> `statusText(`

The comparison is order-insensitive multiset matching. Command: `python3 expects.py`. Output totals:

`TOTAL source 334, port 285, identical 235`. 57 test pairs: 23 identical; 34 differ, all listed below.

Every difference, by test, with its reason (each was a listed or brief-mandated fixture or move change; the ones the report did not yet name are marked NEW):

| Test (port <- source) | Source-only / port-only expects | Reason |
|---|---|---|
| BT1 <- bars_test BT1 | 16 service-bar expects absent | the service bar is 2b's; editor half only (brief) |
| BT2 | `reason: '$mode'` dropped from 2 expects | one mode (the service mode is 2b's); the expects are otherwise unchanged |
| "[print, undo]" | 6 `service-*` expects absent | its service half, 2b |
| T2-b | W/`'w'` -> L/`'l'` (3 expects) | brief: `keyW` -> `keyL` |
| R-5 [snap, zoom], O23 | `find.byType(DocumentToolbar)` -> no `toolbar-` key | brief-mandated finder |
| PF5 | reason `'$mode meta: $meta'` -> `'meta: $meta'` | design-mode half (brief); the mode loop removed |
| PF6 | `hook.initials` `[pdf150, png300 x5]` -> `[pdf150, png300 x2]` | NEW: design-mode half (brief); the three selection-mode exports are 2b's |
| V1, V2 | 6 + 1 selection-mode expects absent | design halves (brief) |
| "the status text" | `hitFound`, `key` premises absent | NEW: the source's wall pick is replaced by selecting the first mark directly (no pick, so no pick premises) |
| NS1 | 3 `layoutFired == 0` absent | NEW: `serviceLayoutChanges` is 2b's (brief: those lines stay out) |
| "no command reaches" (V-5) | `keyOf(c,'1')` -> `SelectionKey.root(mark)`; the column's `hasLength(1)` absent | fixture mapping; the column part is sub-project 3's (brief) |
| T5-g layerPanel | `selection-panel` and `table-section` -> `find.byType(PlanPropertyPanel)`; two `findsNothing` become one | brief mapping; review Minor 4 |
| R-4 Page panel alone | `selection-panel` -> `PlanPropertyPanel` | brief mapping |
| RV6 | `FloorPlanTool.wall` -> `PlanToolIds.line`; `selectTool(...) isFalse` absent | brief mapping; second half retired (controller ruling RV6) |
| T4-g | premises `17100`/`17700` -> `-27000`/`-25800` | fixture: this page's empty band (listed) |
| R-2 polyline part-way | `wall`/`'Wall'` -> `polyline`/`'Polyline'` | brief: a polyline in place of the wall |
| K3 | wall -> line; `c.tables` -> `marksOf(c)` | brief: tables -> the fixture's marks |
| SW1, SW2 | Wall/Wand/Duvar -> Line/Linie/Çizgi; 3 service-bar expects absent | listed (generic tools; service bar 2b) |
| OV-H | premises `roots > 20` and TableSurvey -> `roots == kEditorMarks + 1` | listed (fixture sanity) |
| LK1 | premise `'Duvar'` -> `'Çizgi'` | listed |
| PW1 | 8 panel expects absent, the zoom expect identical | Task 18 ported them; only the zoom was sent here (brief) |
| theme "the width" | `ServiceView` -> `PlanEditor`; `resolvedIn(tester, mode)` -> `resolvedIn(tester)`; refused count `4*3+4*5+3*6` -> `4` | the width-only cases (2b's fields out); one mode (listed) |
| theme P-6, M-H30, ambient switch | `resolvedIn(tester, mode)` -> `resolvedIn(tester)`; M-H30's `groupFrameColor` -> `canvasBackground` | NEW for M-H30: `groupFrameColor` is a 2b field, so the generic field stands in |
| theme "bare ... reads", R-4 | `resolvedIn(tester, design)` -> `PlanThemeScope.of(PlanCanvas element)` | brief: a PlanCanvas alone |
| theme "through the barrel" | the merged theme's fields are the generic four | NEW: `statusCaptionStyle` and `groupChipPadding` are 2b's |
| theme_colours (3 tests) | file paths and literals; premise `> 100` -> `> 50` | listed |

No difference changes what a remaining assertion checks. The NEW rows are all 2b fields and halves, or the selection-by-hand fixture, as above.
