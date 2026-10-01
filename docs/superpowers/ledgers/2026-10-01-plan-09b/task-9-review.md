# Task 9 review (independent) — 7d3bff7
Status: in progress
- Diff af704cf..7d3bff7: main.dart, document_host.dart, new test/symbols/symbol_shell_test.dart; the test dir diff is the new file only (no bare-shell file touched); no packages/; shortcut_guard.dart (kShellLetterKeys) and shell_commands.dart unchanged.
- Wiring read: cell tap -> _armSymbol (main.dart:626-629) -> armed then _activate (:616-621: refuses when geometry denied, clears selection). Dispose (:679-697): _tools first, then entry tools, then _symbolTool (removes its _armed listener), _armed, _symbolSearch, own cache. Strip under ExcludeFocus (:756). Bare shell: _leftPanel returns the identical ToolPalette(...) (:736-751) — no extra widgets. Ownership: the app makes+disposes its own loader/cache (:87-95,:117), passes them through the host (document_host.dart:543); the shell disposes only its own fallback cache.
- _settlePendingInput (:601-607) hands back any focused PanelFieldFocusNode, so the symbol search is covered generically.
- App gate (real): `03:43 +884: All tests passed!`; `No issues found!`; `Formatted 152 files (0 changed)` fmt=0; `✓ Built build/web`.
- Key routing (SS4/SS5): R and M through tester.sendKeyEvent with the canvas focused keep the SymbolPlaceTool active and give a 1-turn mirrored placement compared exactly with placementTransform at the snap computed by the engine's resolveDragPoint (not the tool); W -> WallTool; Esc -> SelectTool; camera rotated 0.3 rad at 0.1 px/mm far from origin.
- M-09b6 (main:628 _tools.activate): RED SS3. M-09b11 (main:749): RED SS1 (Found 1 'left-tabs'). strip without ExcludeFocus (main:756): RED SS6. M-09b9 at shell (panel:159): RED SS5 (Expected null Actual 'dining.table.square.two@1'). restored diff=0 each
- shell does not dispose the tool (main:693): RED SS7. app does not pass thumbnails (main:149): RED SS9, SS10. hunt _armed not disposed (main:694): RED SS7. hunt cell tap does not arm (main:627): RED SS3, SS4. restored diff=0 each
- hunt dispose order swapped (_armed before the tool, a two-line move): RED SS1, SS2 ("A ValueNotifier<SymbolEntry?> was used after being disposed."). restored diff=0
- hunt host does not key the shell (host:534): RED SS7 (Expected SelectTool Actual SymbolPlaceTool: the swapped document would keep the armed tool). restored diff=0
- Mid-press 12a rule wired: SS8 (isMidShape disables toolbar Save during a press; implementer's M-09m-at-shell red). _armed resets on a swap because the host keys the shell by ObjectKey(document) (above).
- Final git status --short: empty.

## Verdict: Approved
Judgments: R-B9-1 (a bare shell with a loader makes and disposes its own cache) fine, a seam only. R-B9-2 (search text cleared on a tab switch) acceptable as is; keeping the panel alive via IndexedStack/Offstage would also keep its ListenableBuilder rebuilding on every hover while hidden; worth the human's look, not a defect. R-B9-3 (no document measurer to the panel: the cache outlives the shell, symbols hold no text) right. R-B9-4 (armed set before a refused _activate) harmless: no highlight (tool not active) and the gallery is disabled while geometry is denied.
