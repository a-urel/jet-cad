# Task 8 review (independent) — af704cf
Status: in progress
- Diff 76e5f8b..af704cf: 2 new app files (lib/symbols/symbol_panel.dart, test/symbols/symbol_panel_test.dart); main.dart untouched.
- Field structure (symbol_panel.dart:217-253): ShellShortcutGuard > CallbackShortcuts(Escape -> _handBack) > TextField(focusNode: searchFocus (PanelFieldFocusNode), onEditingComplete: _handBack, onTapOutside: _handBack). _handBack = PanelFieldFocusNode.handBack (panel_focus.dart:42-49: unfocus with previouslyFocusedChild, walking nested panel fields) -> the canvas, not a plain unfocus. The x (:242) and the empty-result Clear (:331) and Retry (:301) are under ExcludeFocus; the x is inside the field's decoration, so a tap on it is not "outside" and the field keeps focus.
- Listeners: ListenableBuilder over loader/tools/armed (:168-170) unsubscribes itself; _query listener removed in dispose (:127). No leak.
- Perf note: ToolController forwards every tool notification (tool.dart:131), and SymbolPlaceTool notifies on every hover move, so the whole panel (searchSymbols + gallery build) rebuilds per pointer move while the symbol tool is active. The tool palette has the same pattern (tool_palette.dart:53-54); Task 4b guarantees no thumbnail re-request on such rebuilds.
- App gate (real): `02:54 +873: All tests passed!`; `No issues found!`; `Formatted 151 files (0 changed)` fmt=0; `✓ Built build/web`.
- Permissions at runtime: no assignment to commands.permissions anywhere in apps/floor_planner/lib or the engine lib besides constructor defaults (grep); they are fixed per document (codec/constructor), and a document swap rebuilds the shell. A value parameter (R-B8-2) is enough.
- M-09b7 (:217): RED (Expected R/W/M 0, Actual 1/1/1). M-09b8 Esc (:222), Enter (:233), tap-outside (:234): RED each (+ M-09b22 test for tap-outside). restored diff=0 each
- M-09b9 (:159): RED (Expected null Actual 'bed.double@1'). M-09b10 (:174): RED (Expected 2 Actual 1). M-09b22 (:28): RED. thumbnail turned (:43): RED (Actual [0,1,-1,0,1800,200]). restored diff=0 each
- HUNT plain unfocus instead of handBack (:132): RED x2. foreground white (:209): RED (Expected 0 Actual 16777215). restored diff=0 each
- HUNT the x clear without ExcludeFocus (:242): SURVIVED `+14: All tests passed!`. empty-result Clear without ExcludeFocus (:331): SURVIVED +14. Retry without ExcludeFocus (:301): SURVIVED +14 — the Retry test's "Retry took no focus" assertion is vacuous (a button never requests focus on tap). restored diff=0 each -> finding 1
- Query handling: the panel passes `_query.text` raw to searchSymbols (:183); no double trim/lower-case.
- Final git status --short: empty.

## Verdict: Needs fixes (test-only, minor)
1. MINOR test/symbols/symbol_panel_test.dart (code symbol_panel.dart:242, :301, :331): the three ExcludeFocus wrappers (Ruling 05-6) are unguarded; removing any survives, and the Retry test's canvas-focus check cannot fail on tap. Fix as Task 4 did: for each button, `Focus.of(<button's descendant>).canRequestFocus` is false (and/or `canvas.nextFocus()` never lands on it); for the x, also assert the field keeps focus after tapping it.
2. NOTE (:168-170): the panel listens to ToolController, which forwards every tool notification; the symbol tool notifies per hover move, so the panel rebuilds per pointer move (tool_palette.dart:53-54 does the same; Task 4b guarantees no thumbnail re-request). Could listen to `active` changes only; not required.
3. NOTE: the empty-result Clear's focus outcome (handBack via onTapOutside) is not asserted; covered in effect by the tap-outside test.
Judgments: R-B8-1 (optional measurer) fine; R-B8-2 (permissions as a value) fine, permissions never change at runtime in this app; R-B8-3 (onSelect(SymbolEntry) via an id map; top-level symbolIdOf/symbolThumbnailDocument) fine. The sendKeyEvent note is correct: widget-test key events insert no text; the guard test proves no shortcut fires and the field keeps focus, filtering is proven by enterText.

## Re-review (8b) — 7693621, ebfd8bf, 5566da3 (on 7d3bff7)
- Diff 7d3bff7..5566da3: only symbol_panel_test.dart (+21 -1), symbol_library_loader_test.dart (+6 -1), symbol_thumbnails_test.dart (+1: hairlineSymbol joins the guard loop).
- App gate (real): `03:04 +884: All tests passed!`; `No issues found!`; `Formatted 152 files (0 changed)` fmt=0. Render: `00:56 +1001 ~1 -7`; the 7 [E] are exactly text_ladder rungs 1-5 and text_lod_ladder rungs 1-2 (RenderBackend.canvas); analyze `No issues found!`; `Formatted 182 files (0 changed)` fmt=0.
- Mutants (scratchpad/rb8b, restored diff=0 each):
  - x clear without ExcludeFocus (panel:242): RED "typing bed ... the clear button restores all" (`Expected: false Actual: <true>`)
  - Retry without ExcludeFocus (panel:301): RED "a failed load shows its message and Retry" (`Expected: false Actual: <true>`)
  - empty-result Clear without ExcludeFocus (panel:331): RED "an empty result says so ..." (`Expected: false Actual: <true>`)
  - app's own loader read throws (main:88): RED SL11 (`Expected: SymbolLibraryReady Actual: SymbolLibraryFailed(Bad state: x)`)
- canTakeFocus is real: Focus.of on a widget inside the button resolves the button's own (InkWell) focus node; canRequestFocus is false only under an ancestor ExcludeFocus (the mutants above flip it to true).
- Nit: the old "Taps the field and checks the premise" doc comment now sits above canTakeFocus's own doc (symbol_panel_test.dart:195-196), so focusField lost its comment. Cosmetic.
- git status --short: empty.
### Verdict (8b): Approved (one cosmetic nit)
