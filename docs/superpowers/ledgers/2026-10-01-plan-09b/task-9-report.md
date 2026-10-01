# Task 9 report — the shell's tabs and wiring

Commit: 7d3bff7 `feat(app): the Symbols tab in the shell` (on af704cf; amended
once before any review to fix the cache-disposal probe, see Mutants).
Files: apps/floor_planner/lib/main.dart, apps/floor_planner/lib/document_host.dart,
apps/floor_planner/test/symbols/symbol_shell_test.dart (new, 11 tests SS1-SS11).
`git diff af704cf HEAD --stat`: those 3 files only (no analysis_options.yaml, no packages/).

## Gates (app; engine and render untouched by this task, unchanged)
- `CI=true flutter test`: `03:17 +884: All tests passed!` (873 + 11)
- `CI=true flutter analyze`: `No issues found! (ran in 1.6s)`
- `CI=true dart format --output=none --set-exit-if-changed .`: `Formatted 152 files (0 changed) in 0.80 seconds.`
- `CI=true flutter build web --release`: `✓ Built build/web`
- The 24 bare-shell test files and the pumpApp-based ones are unchanged and green
  (pumpApp's app now has the tab strip, Tools default: nothing broke).

## What was built
- `FloorPlannerApp(thumbnails:)` (R-B3-1): optional; the app makes a
  `SymbolThumbnails` when null and disposes only that one. `DocumentHost(thumbnails:)`
  passes it to `PlannerShell(thumbnails:)`.
- `PlannerShell`: `_armed` (ValueNotifier<SymbolEntry?>), `_symbolTool =
  SymbolPlaceTool(_armed)`, `_symbolSearch` (PanelFieldFocusNode), `_leftTab`
  (enum, shell state). Disposed in the shell's dispose after the entries' tools:
  tool first (it removes its `_armed` listener), then `_armed`, the focus node,
  and the shell's own cache if any. The tool is not in `_entries` (no letter).
- `chrome-left` (240 px): with `symbols == null`, exactly today's `ToolPalette`;
  otherwise a Column: `ExcludeFocus(SegmentedButton<_LeftTab>(key 'left-tabs',
  showSelectedIcon: false))` with segments labelled `Text('Tools', key 'tab-tools')`
  and `Text('Symbols', key 'tab-symbols')` (ButtonSegment takes no key; the
  keys are on the labels, a tap on them hits the segment), then the chosen tab.
- `_armSymbol(entry)`: `_armed.value = entry; _activate(_symbolTool);` (SymbolPanel.onSelect).
- SymbolPanel gets `permissions: _document.commands.permissions` read at build,
  like `_geometryAllowed` for the palette.

## Decisions (reviewer to judge)
- R-B9-1: a shell given a loader but no cache makes a `SymbolThumbnails` of its own
  (lazily, on first Symbols tab build) and disposes it (SS11). The app always
  passes one, so this is only the bare-shell-with-loader seam. Cost if wrong: none.
- R-B9-2: the Symbols tab's panel is unmounted when the Tools tab is shown, so the
  search query is cleared by a tab switch (the panel owns its query, Task 8). Spec
  silent. Cost if wrong: an `IndexedStack`/`Offstage` later.
- R-B9-3: the measurer is not passed to SymbolPanel (default `InsertionPointMeasurer`,
  R-B8-1): the document's FlutterTextMeasurer is cleared on shell dispose while the
  app's cache outlives the shell, and symbols hold no text.
- R-B9-4: `armed` is set before `_activate`, as spec D8 says; if `_activate` refuses
  (geometry denied) `armed` holds the entry but the tool is not active, so no
  highlight (the gallery is disabled then anyway, M-09b22).

## Tests (test/symbols/symbol_shell_test.dart)
Fixtures: app over FakeDocumentFiles, loader over the real asset read by File,
a test-owned cache; camera rotated 0.3 rad at 0.1 px/mm centred at (41234.5, 27345.25);
the placed entry's base point off its origin (checked); placement turned AND mirrored
(R then M) and compared exactly to `placementTransform` at the snapped release point
(computed in the test by `resolveDragPoint` from the shell's index, page, camera
and the host's snap). No pixels read, so no `runAsync`. Keys go through
`tester.sendKeyEvent` (the canvas focus path, F-12); presses through a mouse
`TestGesture` on the InteractionLayer.
- SS1 bare shell: no strip/tabs/panel, ToolPalette in chrome-left; the app's shell has them.
- SS2 tabs switch content (ToolPalette <-> SymbolPanel); Wall stays active.
- SS3 a wall selected first; cell tap: active is the panel's SymbolPlaceTool, armed is the entry, selection empty, cell highlighted, status 'Symbol'.
- SS4 armed, R and M keep the tool (not Rectangle/Room), the drag-release places with 1 turn + mirror at the snapped point; then W -> WallTool.
- SS5 Esc -> Select, highlight null; re-arm, L -> LineTool, highlight null.
- SS6 canvas keeps focus after tab and cell taps, and when every focus node under the strip and the gallery is asked to `requestFocus()`.
- SS7 New (clean) through the host: Select active, Tools tab again; the new panel's tool is a different object, armed null, ghost hidden, no highlight; the old tool and its armed notifier are disposed.
- SS8 mouse down: isMidShape and toolbar-save disabled; during the move still disabled; after up: placed, Save enabled.
- SS9 a given cache reaches the host and the panel (same) and survives the app's unmount.
- SS10 no cache given: the app's own reaches host and panel, disposed on unmount.
- SS11 bare shell with a loader: its own cache, disposed with it.

## Mutants
Driver scratchpad/b9/mut.sh (cp backup, one-line python replace, run
test/symbols/symbol_shell_test.dart in the foreground, cp back; every restore printed
`restore diff exit=0`). Line numbers at 7d3bff7. All red.

| id | file:line | mutation | red (real output) |
|---|---|---|---|
| M-09b6 | main.dart:628 | `_activate(_symbolTool)` -> `_tools.activate(_symbolTool)` | `00:04 +2 -1: SS3 a cell tap arms the tool, clears the selection, ... (M-09b6) [E]` |
| M-09b11 | main.dart:749 | `widget.symbols` -> `widget.symbols ?? SymbolLibraryLoader()` | `00:01 +0 -1: SS1 a bare shell has no tabs ... (M-09b11) [E]` |
| strip without ExcludeFocus | main.dart:756 | `ExcludeFocus(` -> `KeyedSubtree(` | `00:06 +5 -1: SS6 the tab strip and the cells take no focus ... [E]` |
| M-09b9 (shell) | symbol_panel.dart:159 | active-tool check dropped | `00:06 +4 -1: SS5 Esc returns to Select and the highlight clears; ... (M-09b9 at the shell) [E]` |
| shell does not dispose the tool | main.dart:693 | `_symbolTool.dispose();` commented out | `00:07 +6 -1: SS7 a document swap (New, clean) leaves no armed tool: ... [E]` |
| app does not pass thumbnails | main.dart:149 | `thumbnails: _thumbnails` removed | `00:08 +8 -1: ... SS9 the app hands a given cache to the panel ... [E]` and `00:09 +8 -2: ... SS10 ... [E]` |
| host does not pass thumbnails | document_host.dart:543 | `thumbnails: widget.thumbnails,` removed | SS9 `[E]`, SS10 `[E]` (same lines as above) |
| app does not dispose its own cache | main.dart:117 | `_ownThumbnails?.dispose();` removed | `00:07 +9 -1: ... SS10 without a cache the app makes one, ... disposes it with itself [E]` |
| app disposes a given cache | main.dart:117 | -> `_thumbnails.dispose();` | `00:07 +8 -1: ... SS9 the app hands a given cache to the panel and does not dispose it [E]` |
| shell does not dispose its own cache | main.dart:696 | `_ownThumbnails?.dispose();` removed | `00:08 +10 -1: ... SS11 a shell given a loader and no cache makes a cache of its own and disposes it [E]` |
| cell tap does not activate | main.dart:628 | `_activate(_symbolTool);` removed | SS3, SS4, SS5, SS7, SS8 `[E]` (`00:06 +2 -2: SS4 armed, R and M ... [E]`) |
| tool consumes W armed idle | symbol_place_tool.dart:224 | `ignored` -> `handled` | `00:05 +3 -1: SS4 armed, R and M ... W then chooses Wall [E]` (+ SS5) |
| M-09m (shell, 12a rule) | symbol_place_tool.dart:94 | `isMidShape => false` | `00:07 +7 -1: SS8 the 12a mid-shape rule: ... [E]` |
| tabs ignore a tap | main.dart:769 | `setState(() {})` | `00:03 +1 -1: SS2 the tabs switch the panel's content and change no tool [E]` (+ SS3..SS9) |
| a tab switch changes the tool | main.dart:769 | also calls `_escape()` | `00:03 +1 -1: SS2 ... change no tool [E]` (only SS2) |
| host does not key the shell by document | document_host.dart:534 | `key: ObjectKey(...)` removed | `00:06 +6 -1: SS7 a document swap ... [E]` |

Note (honest record): on the first commit 641d3dd the two "own cache not disposed"
mutants SURVIVED: the disposal probe used `throwsStateError` on a closure returning
`imageFor`'s future, and the probe builder's own `StateError('probe')` arrived through
that future. Fixed with an `isDisposed` helper that only counts a synchronous
StateError (the builder throws UnsupportedError into an ignored future), with a
premise that it reads false while alive and true after a dispose; both mutants then
red (rows above). The commit was amended before any review: 7d3bff7.

## Open
- Nothing blocking. R-B9-1..4 above for the reviewer.
