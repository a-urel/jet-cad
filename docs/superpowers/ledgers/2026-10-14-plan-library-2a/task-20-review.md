# Task 20 review: PlanEditor, PlanEditorBar, example, README, barrel (826ee7e1..ce212b7c)

Reviewed in passes over the diff file (lib, then tests, then support). Ported tests were spot-checked against their sources (BC2's `kEditorEdges` = `jet_cad_floor_plan/test/host/bars_test.dart:154-172` verbatim; RV6's first half = `editor_tools_review_test.dart:343-354`, only the `W`/`wall` -> `L`/`plan.line` mapping changed).

### Spec Compliance

- ✅ Spec compliant (P2 "The widgets", P7, F6, the carried items, RV6 ruling), with one gap in test coverage (Important 1 below).
  - P2 `PlanEditor` options: every option of spec line 347 and the brief's constructor is present and used: `plan_editor.dart:487-513` (constructor), read in `build` (`:1012-1090`) or by the flows at call time (`_flowsFor`, `:609-620`).
  - P7 rows that land on the editor are all mapped: `selectionPanel` -> `propertyPanel`, `layerPanel`, `pagePanel`, `symbolPalette` -> `gallery`, `symbolFilter`, `rulers`, `grid`, `snapping`, `editorBar` -> `bar`, `onExportDialog`, `onPageFlowError`, `printer`, `exportName`, `shortcuts`, `autofocus`, `theme`. "The web's context menu" was a host call plus 2b's `onTableContextMenu` (`jet_cad_floor_plan/lib/src/host/floor_plan_view.dart:91-92`). Nothing is dropped.
  - File callbacks: `_fileCommands` (`:718-771`) offers New/Open/Save/Save As only when given. `_file` settles first (`:709-716`). All are enabled on `_idleFlag`. ED-3 pins the order and the settle.
  - Damaged warning: `:894-908`, ED-5.
  - Barrel (ED-9 + F6): every export has a `show` list (`lib/jet_cad_2d_plan.dart:197-275`). `SymbolThumbnails` is re-exported. `barrel_test.dart:1680-1713` holds the brief's set.
  - `PlanLocaleScope.push`: in `didChangeDependencies` and on a controller swap (`:629-646`).
  - README claims checked against the controller: `export(String, PlanExportChoice)` (`plan_controller.dart:273`), `print(PlanExportChoice)` (`:281`), `save()` (`:416`), `load(String)` (`:457`). The locked-missing-kit and contained-failure claims are Tasks 10 and 11. No over-claim found.
  - Carried items:
    - ED-L: the picker under `changeLayer` and lock is pinned (M-ED-L1, M-ED-L2). The swap half is weak (Minor 2).
    - Page-less export: `exportersFor` and `exportRunnable` (`editor_page_flows.dart:1325-1343`). ED-X1 and ED-X2 cover them, including the chord.
    - ED-U: the canUndo lag is real today. Checked `planner_shell.dart:728-731` (`DerivedFlag(... _document.commands.canUndo)`) and `:1045-1049` (updated from the asynchronous `commands.changes`). The port reads the history live the same way (`plan_editor.dart:684-685`).
    - ED-D: a positive control, which is reasonable.
  - RV6 ruling: ported. `plan_canvas.dart` `_mountedOf` and `_withdrawTool` are called from `dispose`. The test is at `editor_options_test.dart:2856-2867`, named M-RV6. The retired half is recorded in the file header (`:2218-2222`).
- ⚠️ Cannot verify from diff:
  - That every other ported `expect` is unchanged from its source (A12). Only BC2 and RV6 were spot-checked. Controller: diff `editor_options_test.dart` T5-g, R-2 and T4-f, and `editor_words_test.dart` SW1 and LK1, against their sources. The report lists premise changes there, e.g. LK1 now also allows the kits' English `names` words (`editor_words_test.dart:3792-3795`).
  - The mutation table (22 rows plus M-RV6): the red lines were not re-run.
  - `recording_plan_strings.dart` past its line 33 was not read line by line. `implements PlanStrings` makes a missing member a compile error. A member left unrecorded would not be caught.

### Strengths

- The editor is a close, readable port of the brief's design. Deviations are few and each is justified:
  - The shared `FrameSafeRelay` is reused rather than re-declared.
  - `PlanTextKeys` is not wrapped twice. Verified: `plan_shortcuts.dart:181` already wraps its child.
  - The undo flags read the history live, as today's `DerivedFlag` did.
- The page-less export is handled carefully. Export's button, its chord (`PlanShortcuts._run(can: exportRunnable)`) and the dialog's exporter list all follow one rule (`exportersFor`/`exportRunnable`). With only the built-in exporters the behaviour is unchanged (ED-X1).
- RV6's withdrawal:
  - It is deferred past the frame, with a per-controller mount counter that works in every build mode.
  - It is safe after the host disposes the controller (`c.isDisposed`). ED-D exercises that path after the RV6 commit.
  - It cancels select's own drag or band rather than re-arming select.
- The tests are strong where they are new. ED-1..ED-7, ED-X1, ED-X2 and ED-U each name the mutation at their red line. Fixtures are off the origin with turned marks (`editor_host.dart:4869-4876`). The theme-colour scan keeps its own mutants and stale-entry check.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

1. **`PlanEditor(toolPalette:)` is untested, including the behaviour the implementer added (deviation 6). Neither are the editor's pass-throughs of `symbolFilter`, `shortcuts`, `autofocus` and `onPageFlowError`.**
   - Where: `plan_editor.dart:948-961` (`_leftShown`: `if (!widget.toolPalette) return false;`), `:970-973` (`if (!widget.toolPalette) return _galleryOf(c);`, the gallery alone), `:963-964` (`filter: widget.symbolFilter`), `:1024` (`shortcuts: widget.shortcuts`), `:1055` (`autofocus:`), `:618` (`onError: widget.onPageFlowError`).
   - Evidence: `grep -rn toolPalette test` and `grep -rn symbolFilter test` return nothing. No test under `test/` passes `shortcuts: false`, `autofocus: false` or `onPageFlowError:` to a `PlanEditor`.
   - Why it matters: `toolPalette` is new (P2's "which panels show"). Its gallery-alone branch is behaviour the brief's code did not have. Dropping either `toolPalette` line, or any of the four pass-throughs, survives the whole suite. That is the surviving-mutant pattern CLAUDE.md's testing bar targets. The components behind the pass-throughs are tested in their own tasks, but the editor's wiring is not.
   - Fix: add an ED test for `toolPalette: false`:
     - with a symbol kit: no `left-tabs`, the gallery shown, no palette;
     - without one: no `chrome-left`.
     - Name mutations on the two lines above.
   - Also add one test per pass-through (or a compact table test) through `PlanEditor`:
     - `shortcuts: false`: a letter reaches the host;
     - `symbolFilter`: a filtered symbol is absent in the Symbols tab;
     - `onPageFlowError`: a failing printer's error is delivered;
     - `autofocus: false`: the canvas has no focus after the pump.

#### Minor (Nice to Have)

1. **RV6 is not applied when a canvas is handed another controller.**
   - Where: `plan_canvas.dart` `didUpdateWidget` calls `_leave(old)` but not `_withdrawTool(old)`.
   - Why it matters: the doc comment at `plan_canvas.dart:304-306` says "When the last canvas showing it goes, any shape in progress is cancelled". An editor swapped to another controller (the ED-6 flow) leaves the old controller part-way through a shape. Its `undo()`/`redo()` then do nothing until something cancels the tool.
   - Fix: one line, `_withdrawTool(old)` after `_leave(old)`. Test: ED-6 with `one` mid-polyline. After the swap and a pump, `one` is no longer mid-shape. The post-frame `_mountedOf` check already protects a re-show.
2. **ED-L's swap half cannot tell the new plan from the old.**
   - Where: `plan_editor_test.dart:4357-4369`.
   - The comment says "a mark of it on layer B shows B", but the assertion is `'A'`. `other = layerPlan(objects: true)` is the same fixture as the first, so the value check passes whether the picker reads the old or the new plan. Only `enabled` distinguishes them (the old plan's lock). The report says the swap half has no mutation of its own.
   - Fix: give the second fixture's first mark layer B and assert `'B'`. Name a mutation, e.g. the picker caching the first document's lock set or layer table. Then fix the comment.
3. **Most ported tests carry no named mutation.**
   - Counts:
     - `editor_options_test.dart`: 18 tests, 3 named;
     - `editor_view_test.dart`: 8 tests, none named;
     - `editor_separator_test.dart`: 3 tests, none named;
     - `editor_theme_test.dart`: 8 tests, 2 named.
   - The constraint the controller passed says every test names its mutation (positive controls exempt). Earlier tasks' ported files show the same pattern, e.g. `test/panels/layer_panel_test.dart` has 25 tests and 4 named, so this follows precedent. Flag for the controller's ruling rather than as a regression of this task.
4. **A duplicated assertion.** `editor_options_test.dart:2617-2618` asserts `expect(find.byType(PlanPropertyPanel), findsNothing)` twice in a row. It comes from mapping both `selection-panel` and `table-section` to one finder. Harmless. One line, or a comment naming both sources, would read better.
5. **Two rules for "has a page".** `exportRunnable` decides on `controller.page.value != null` (`editor_page_flows.dart:1342`). `exportersFor` decides on `exportPageOf(document) != null` (`:1330`). They agree today, since the page notifier derives from the `PageComponent`. If they ever diverge, Export could be enabled while `offered` is empty, and the flow would return silently (`:1373`). Consider deriving both from one predicate.

### Assessment

**Task quality:** Needs fixes

**Reasoning:** The editor, bar, barrel, example and README match the brief, spec P2/P7, F6, the carried items and the RV6 ruling. The code is clean and the new tests have mutations. But the new `toolPalette` option (including the implementer's own gallery-alone branch) and four editor pass-throughs have no test, so their mutants survive. That gap should close before the task is trusted.
