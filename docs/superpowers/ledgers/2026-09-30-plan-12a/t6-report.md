# Task 6 report: app, the command table, the toolbar, the shortcuts (plan 12a, spec D6, D7)

**Commit:** `95bf923` `feat(app): the command table, toolbar and shortcuts` on
`plan-12a/document-lifecycle` (parent `efb8700`). Not pushed. It ends with the two trailers. 6 files, +1311 −25:
- `apps/floor_planner/lib/shell_commands.dart` (new)
- `apps/floor_planner/lib/document_toolbar.dart` (new)
- `apps/floor_planner/lib/main.dart`
- `apps/floor_planner/lib/document_host.dart`
- `apps/floor_planner/lib/shortcut_guard.dart`
- `apps/floor_planner/test/document_commands_test.dart` (new)

`packages/jet_cad/analysis_options.yaml` is modified by `flutter pub get`. It is left unstaged and was not committed.

## The API as landed

**`lib/shell_commands.dart`**

Chord constants. Each is a `List<SingleActivator>` and is defined once.

| Constant | Chords |
|---|---|
| `kNewChords` | Meta+N, Ctrl+N |
| `kOpenChords` | Meta+O, Ctrl+O |
| `kSaveChords` | Meta+S, Ctrl+S |
| `kSaveAsChords` | Meta+Shift+S, Ctrl+Shift+S |
| `kUndoChords` | Meta+Z, Ctrl+Z |
| `kRedoChords` | Meta+Shift+Z, Ctrl+Shift+Z, Ctrl+Y |
| `kFileChords` | New, Open, Save and Save As together |

Three places use these constants: the table, the guard and the binding above the Navigator.

`final class ShellCommand`:
- Fields: `id`, `label`, `icon`, `shortcuts` (`List<SingleActivator>`), `enabled` (`ValueListenable<bool>`), `run` (`Future<void> Function()`).
- `String get tooltip => tooltipFor(defaultTargetPlatform)`. On macOS it reads `Label (⌘S)` or `(⌘⇧S)`; elsewhere `Label (Ctrl+S)` or `(Ctrl+Shift+S)`. The glyph comes from the first chord. A command with no chord shows its label only.
- `void invoke()`: if `!enabled.value` it returns; otherwise `unawaited(run())`. **This is the only way a command runs**, for toolbar buttons and shortcuts alike.
- `ShellCommand withEnabled(ValueListenable<bool>)`.

`class DerivedFlag extends ChangeNotifier implements ValueListenable<bool>`:
- `DerivedFlag(List<Listenable> sources, bool Function() compute)`.
- `value` is computed live each time it is read.
- `update()` recomputes and notifies only when the answer changed. This matters because the `ToolController` notifies on every hover.
- `dispose` removes it from its sources.

**`lib/document_toolbar.dart`**
- `DocumentToolbar({fileCommands, editCommands})` is built as `TextFieldTapRegion(ExcludeFocus(Material(transparent, Row(...))))`.
- It shows one `IconButton` per command:
  - key `toolbar-<id>`
  - `tooltip: command.tooltip`, `iconSize: 20`, `VisualDensity.compact`
  - `onPressed: enabled ? command.invoke : null`, rebuilt through a `ValueListenableBuilder` on `enabled`
- A 12 px gap (`groupGap`) separates the file group from Undo/Redo. It appears only when both groups are present.

**`lib/document_host.dart`** (`DocumentHostState`)
- `late final List<ShellCommand> fileCommands`, in this order:

  | id | Label | Flow |
  |---|---|---|
  | `new` | New | `newFlow` |
  | `open` | Open… | `openFlow` |
  | `open-sample` | Open sample | `openSampleFlow` |
  | `save` | Save | `saveStep` |
  | `save-as` | Save As… | `saveAsStep` |

- Each command's `enabled` is `_notBusy = DerivedFlag([session.busy], () => !busy)`. The host disposes it.
- The list is passed to the shell as `fileCommands`.
- Busy stays the flows' own, from Task 5's `_flow`: outermost only, cleared in `finally`.

**`lib/main.dart`**

`FloorPlannerApp` adds `MaterialApp.builder`: a `CallbackShortcuts` binding every chord in `kFileChords` to a static no-op `_consume`. It marks the key handled and runs nothing (U-3, R-10).

`PlannerShell` gains two parameters:
- `fileCommands` (default `const []`).
- `@visibleForTesting VoidCallback? debugOnSettle`, called at the end of `_settlePendingInput()`. It is the stubbed settle for U-2, see deviation 4.

The shell's state:
- **`_idle`** is `!(busy?.value ?? false) && !_tools.active.isMidShape`. `busy` is read once in `initState`, as `snap` is.
- **Undo and Redo enabled flags:** `_undoEnabled` and `_redoEnabled` are `DerivedFlag`s over `[_tools, busy?]`. They compute `_idle && canUndo` and `_idle && canRedo`. A `commands.changes` subscription calls their `update()`; it is cancelled in `dispose`.
- **File commands:** each host command is re-wrapped with `withEnabled(DerivedFlag([c.enabled, _tools, busy?], () => c.enabled.value && _idle))`. The host knows busy; only the shell knows mid-shape.
- **`_editCommands`:**
  - Undo: `run = _undo`, which settles, then returns if `!canUndo`, then calls `undo()`.
  - Redo: `run = _redo`, which settles, then **re-reads** `canRedo` and returns if false (U-2), then calls `redo()`.
- **Shortcuts:** the shell's `CallbackShortcuts` binds `chord: c.invoke` for every chord of every command in the table. It replaces the old `_undo` binding and its "There is no redo in 02" comment. F3, the tool letters, F and Escape are unchanged. A disabled command's binding stays and consumes the key (S-26).
- **Top bar**, left to right:
  1. `DocumentToolbar`
  2. 16 px gap
  3. the name, only when `documentName != null`: a `Flexible` holding `Text` key `document-name` with 1 line, ellipsis and no soft wrap. It reads `• name` while dirty, wrapped in `Tooltip('Edited')`.
  4. 16 px gap
  5. the status line (`status-text`), now `Flexible` with 1 line and ellipsis
  6. `Spacer`, then OSNAP and zoom as before

  A bare shell shows Undo/Redo only and no name.
- **`dispose`:** the history subscription and all flags go first, before `_tools.dispose()`.

**`lib/shortcut_guard.dart`**
- The guard now maps `[...kUndoChords, ...kRedoChords]` to `DoNothingAndStopPropagationTextIntent`. That is Meta+Z, Ctrl+Z, **Meta+Shift+Z, Ctrl+Shift+Z, Ctrl+Y**.
- The file chords are not guarded.
- The class dartdoc is updated.

## Tests: `test/document_commands_test.dart` (16 new; app 545 → 561)

**Helpers**
- `pressChord` presses metaLeft, controlLeft and shiftLeft as needed and returns whether the key-down was handled. The chords are spelled out literally in the test, never read from the table.
- `DispatcherSpy` wraps `commands.onBeforeMutate`, which `execute`, `undo` and `redo` call first. It counts every call into the dispatcher, even one the dispatcher would refuse.
- `historyOf` returns `(undoDepth, canRedo, stateId)`.
- `twoWalls` draws two walls through the Wall tool at (−43210.5, 31234.75) under a rotated camera, and ends the shape.
- `pumpBare` pumps a bare `PlannerShell` at 1440 × 900.

| Test | Pins |
|---|---|
| DC1 | Seven buttons in the order new, open, open-sample, save, save-as, undo, redo, with a gap of at least 12 px before Undo. States:<br>• fresh: 5 file commands on, Undo and Redo off<br>• after a Wall edit: Undo on<br>• after tapping Undo: Undo off, Redo on<br>• after tapping Redo: back to the edited state |
| DC1b ×3 (macOS, windows, linux via `TargetPlatformVariant`) | The exact tooltip of every button: `⌘N`, `⌘⇧S`, `⌘⇧Z` on macOS; `Ctrl+N`, `Ctrl+Shift+S`, `Ctrl+Shift+Z` elsewhere. `Open sample` has no chord. |
| DC2 | In the app, two edits. Taps on Undo and Redo, then the pairs (Cmd+Z, Cmd+Shift+Z), (Ctrl+Z, Ctrl+Shift+Z) and (Cmd+Z, Ctrl+Y): each moves exactly one step (depth 2 ↔ 1) and back to the same `stateId`. Every chord is handled. The tool stays Select. |
| DC3 | A bare shell has no file buttons and no `document-name`, only Undo and Redo. Its chords (Ctrl+Z/Ctrl+Y, Cmd+Z/Cmd+Shift+Z, Ctrl+Z/Ctrl+Shift+Z) and taps each move one step, and Redo's enabled state follows. |
| DC4 | Each file button and each Cmd/Ctrl chord runs its own flow:<br>• Open ×3 → `openCalls` 3<br>• Save As ×3 → 3 asks<br>• untitled Save button → asks and writes<br>• Cmd+S and Ctrl+S on the titled document → write in place at `/p/plan` without asking<br>• Open sample → the flat<br>• New ×3 (button, Cmd+N, Ctrl+N) → a new, empty document each time<br>No unscripted calls, not busy, and the tool is still Select: Cmd+N and Cmd+S are not the Window and Separator letters. |
| DC5 | **Mid-shape.** Starts from two edits and one undo, with all seven enabled (premise).<br>• W and one click: `isMidShape`, all seven disabled. Tapping all seven changes nothing: same history, 0 dispatcher calls, same document, no file calls.<br>• A second click puts a wall down (depth 2) and the shape is still mid-shape: all disabled. Tapping Undo and Save does nothing.<br>• Escape: the Wall tool stays active, it is no longer mid-shape, 6 enabled (Redo is off because the wall cut its stack), and a tap undoes. |
| DC6 | Starts from a four-wall enclosure.<br>• Wall, Separator, Dimension and Box: not mid-shape when fresh; one click makes them mid-shape, with Undo and Save disabled; Escape clears it and re-enables.<br>• Door, Window, Gap and Room: each click places the object (depth +1, premise), is never mid-shape, and Undo and Save stay on. Premise at the end: 3 openings and 1 room. |
| DC7 | **Disabled means no call.** The flat is opened as `flat.jetplan` at `/p/flat`; two edits, one Cmd+Z; dirty, `canRedo`, Select.<br>• With writes held, Cmd+S makes one write, and **a second Cmd+S makes no write**. Busy; all disabled.<br>• Under a spy: Cmd+Z, Ctrl+Z, Cmd+Shift+Z, Ctrl+Shift+Z, Ctrl+Y and all 8 file chords are each **handled** (consumed). Then taps on all seven.<br>• After: same history, 0 dispatcher calls, 1 write, `openCalls` 1, no save-location calls, same document.<br>• When the write completes: not busy, all enabled, and Cmd+Z undoes (1 call). |
| DC8 | **Text fields.** In a bare shell with a redo stack, the remaining wall is selected and `wall-thickness` is tapped (premise: primary focus is a `PanelFieldFocusNode`).<br>• Meta+Shift+Z, Ctrl+Shift+Z and Ctrl+Y each leave the history, the dispatcher (0 calls), the focus and the field's text unchanged.<br>• After a click on the canvas hands the focus back, each chord redoes (depth 2), and Cmd+Z restores it. |
| DC9 | **Above the dialogs.**<br>(a) A Cmd+O of the file `[]` leaves the error dialog up (busy). All 8 file chords are handled; no open, save-location or write call; same document. After OK, Cmd+O opens again.<br>(b) The flat is opened titled, then edited (dirty, idle, Save's button enabled), then the `page-preset` dropdown is opened. Cmd+S, Ctrl+S, Cmd+Shift+S, Ctrl+Shift+S, Cmd+O, Ctrl+O, Cmd+N and Ctrl+N (Save first) are each handled, and **after each** there is no write, no extra open or save-location call, and the same document. Escape closes the menu, then Cmd+S writes at `/p/flat` and the document is clean. |
| DC10 | **Redo re-reads after the settle** (stubbed through `debugOnSettle`). Two walls, one undo, Redo enabled. The stub executes the Selection panel's own command (`SetComponentCommand<WallParams>`, thickness 262.5). A tap on Redo leaves:<br>• the thickness committed<br>• depth 2, `canRedo` false<br>• **dispatcher calls == 1** (the settle's commit only)<br>• no `CommandRedone` and one `CommandApplied` on `changes`<br>• Redo disabled |
| DC10b | Undo settles first (R-9, stubbed): the stub commits thickness 90 on the last wall. Cmd+Z undoes that commit: the params are back to the originals, depth 2, the `stateId` of before, `canRedo`. |
| DC11 | The app's `Title` (WidgetsApp's, the first `Title` in the tree) and the top bar:<br>• start: `Untitled — jet-cad`, name `Untitled`, no Edited tooltip<br>• after an edit: `• Untitled — jet-cad`, name `• Untitled`, tooltip `Edited`<br>• after Cmd+S (Save As to `hall.jetplan`): `hall — jet-cad`, name `hall`, no tooltip<br>• after Cmd+Z past the save: `• hall — jet-cad` with the tooltip |
| DC12 | At 800 × 600:<br>• A long file name, dirty: no exception; the name is `• <long>`, its paragraph `didExceedMaxLines` (cut, not wrapped), its right edge ≤ the status line's left edge; OSNAP and zoom are inside the bar; Redo is inside the bar.<br>• Then a long status line: the first room is renamed to a long name, and a mouse hover with the Room tool over its seed gives `Room — Already a room: <name>`. No exception, the status paragraph is cut, and OSNAP and zoom are still inside the bar. |

## Mutants

**Procedure:**
1. `cp` a backup to `…/scratchpad/p12t6-<tag>-<file>`.
2. Mutate.
3. Run `CI=true flutter test test/document_commands_test.dart`. For M-12a-31, `test/document_host_test.dart` is run too.
4. `cp` the backup back, then `diff` it (every diff exited 0).

After all runs, `cmp` of every backup against the committed files showed them identical.
- Runner: `…/scratchpad/p12t6-mutants.py`.
- Logs: `p12t6-mutants-final2.log` (DC1–DC8 line numbers) and `p12t6-mutants-final3.log` (DC9–DC12 line numbers, taken after the last test edit to DC9).
- Line numbers refer to the committed `document_commands_test.dart`. The first failing line of each red test is given.

| Mutant | Mutation | Red test : line |
|---|---|---|
| **M-12a-9** | The Undo chords are bound to `() => c.run()`, which skips `enabled` | DC7 : 549 (history unchanged) |
| **M-12a-12** | `_flow` never sets `busy.value = true` | DC7 : 528 (a second Cmd+S makes a write); DC9 : 629 (busy under the dialog) |
| **M-12a-15** a/b/c | The guard lacks Meta+Shift+Z / Ctrl+Shift+Z / Ctrl+Y (one run each) | DC8 : 592, each |
| **M-12a-23** | `_idle` ignores `isMidShape` | DC5 : 402; DC6 : 475 |
| **M-12a-24** | No file chords above the Navigator | DC9 : 631 (Cmd+S not handled with the dialog up) |
| **M-12a-29** | Redo does not re-read `canRedo` after the settle | DC10 : 716 (dispatcher calls 2, not 1). See note 1. |
| **M-12a-30** | The binding above the Navigator runs the host's matching command (through a `GlobalKey<DocumentHostState>`) | DC9 : 672 (Cmd+S with the dropdown up: a write lands) |
| **M-12a-31** | `FloorPlannerApp`'s `ListenableBuilder` listens to a never-notifying `Listenable`, so `onGenerateTitle` is never re-run | DC11 : 766; also DH3 (`document_host_test` 45, 164) and DH4 (38, 187) |
| X1 | The toolbar's `onPressed: command.run`, always | DC1 : 197, DC3 : 295, DC5 : 402, DC6 : 475, DC7 : 530, DC10 : 719 |
| X2 | `invoke` does not check `enabled` | DC7 : 528 |
| X3 | Undo does not settle | DC10b : 737 |
| X4 | Redo does not settle | DC10 : 713 |
| X5 | `_idle` ignores busy | DC7 : 530 |
| X6 | No history subscription: the flags are never updated on `changes` | DC1 : 208, DC2 : 262, DC3 : 304, DC5 : 394, DC10 : 698 |
| X7 | `_idleSources` without `_tools` | DC1 : 203, DC2 : 259, DC3 : 294, DC5 : 393, DC6 : 475 |
| X8 | `kRedoChords` without Ctrl+Y | DC2 : 273, DC3 : 306, DC7 : 542, DC8 : 606 |
| X9 | Save's and Save As's chords swapped in the host | DC1b ×3 : 239, DC4 : 356, DC7 : 526, DC9 : 683 |
| X10 | The name is not `Flexible` | DC12 : 804 (a RenderFlex overflow) |
| X11 | The glyph is always `Ctrl+` | DC1b (macOS) : 239 |
| X12 | No `•` on the dirty name | DC11 : 767, DC12 : 807 |
| X13 | No group gap | DC1 : 195 |
| X14 | The file commands are not gated by the shell's mid-shape (`withEnabled` dropped) | DC5 : 402, DC6 : 476 |
| X15 | The status line is not `Flexible` | DC12 : 843 (a RenderFlex overflow). This mutant survived the first run, whose DC12 had a short status only; DC12 then gained its long-status half. |

**Note 1 (M-12a-29).** `CommandDispatcher.redo()` itself returns when `!canRedo`, so this mutant changes no document state, and no `CommandRedone` event would appear either way. The dispatcher does call `onBeforeMutate` first, so the spy observes the call the UI should not make. That is the test's "no redo call" (spec invariant: "the UI never relies on the dispatcher refusing"). With Task 7's real settle, the same assertion applies.

**Not fired here:**
- M-12a-22 (the toolbar outside `TextFieldTapRegion`) is Task 7's by the plan. The region is in place.
- `ExcludeFocus` removal is not mutant-tested. `IconButton` does not take focus on a tap, so only keyboard traversal would show it.
- Undo's re-read of `canUndo` after the settle is equivalent: a settle only adds history, so `canUndo` cannot become false.

## Gates (final tree `95bf923`, CI=true, PATH=/root/flutter/bin)

| Package | Command | Summary | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed`. The two standing `generate_document_test` failures ("both text fractions…", "the default document is the one Plan 2 measured…") | 1 (standing only, unchanged) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format …` | 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed`. The seven standing failures: text ladder rungs 1–5 and text lod ladder rungs 1–2 | 1 (standing only, unchanged) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format …` | 178 files (0 changed) | 0 |
| app | `flutter test` | `+561: All tests passed!` (545 + 16) | 0 |
| app | `flutter analyze` | No issues found! | 0 |
| app | `dart format …` | 120 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web` | 0 |

The engine and render gates ran on the working tree identical to `95bf923` (no engine or render file changed). The app gates and the web build ran after the last edit, before the commit, on the committed content. `git status` shows only ` M packages/jet_cad/analysis_options.yaml`.

## Deviations and precisions (for the reviewer)

1. **`ShellCommand.shortcuts` is `List<SingleActivator>`**, where spec D6 says `List<ShortcutActivator>`. The tooltip's glyph reads the first chord's key and Shift. Every chord in the table is a `SingleActivator`.
2. **`tooltip` is a getter** computed from `defaultTargetPlatform` at build time, with `tooltipFor(platform)` beside it.
3. **Idle is split between the host and the shell.**
   - The host's `enabled` is "not busy"; the host cannot see the tool.
   - The shell re-wraps each file command with `withEnabled`, so the effective enabled state is the host's `enabled && _idle`.
   - The toolbar and the shell's chords both use the wrapped commands.
   - The table stays one definition per command: id, label, icon, chords and run live once, in the host or the shell.
4. **`PlannerShell.debugOnSettle`** (`@visibleForTesting`) is a test seam for "the re-read with a stubbed settle". It runs at the end of `_settlePendingInput`. The settle is still a no-op without it. Task 7 may keep it or drop it once DC10/DC10b can use a real typed value.
5. **`DerivedFlag` is a new small helper** in `shell_commands.dart`. Its `value` is live, and it notifies only on change, so hover notifications from the `ToolController` do not rebuild the toolbar.
6. **The chord constants are shared** by the table, `ShellShortcutGuard` and the consume-only binding above the Navigator, so none of them can disagree with another. The tests spell the chords out literally.
7. **Undo and Redo do not set busy.** They are synchronous; `run` is `async` only to match the type. The key or tap acts within the same event.
8. **The name's tooltip exists only while dirty** (`Edited`). While clean there is no tooltip. The name's key is `document-name`.
9. **Button sizing:** `IconButton` with `iconSize: 20` and `VisualDensity.compact`, to sit in the 44 px bar.

## Found outside scope (reported, not fixed)

- **Consume-only binding and text fields in dialogs.** The binding above the Navigator sits below `DefaultTextEditingShortcuts`, so it also swallows the file chords inside dialog text fields, for example the web name prompt. This is intended by U-3 and noted here for the human's web look.
- **Focus on the route scope.** When the home route's scope itself holds the focus (no child focused), the shell's bindings are not in the chain. The file chords are then consumed by the outer binding and run nothing. This is the pre-existing focus concern that `PanelFieldFocusNode.handBack`'s dartdoc describes; this task does not make it worse.
- **M-12a-29 is visible only through `onBeforeMutate`.** The dispatcher's own guard hides the call otherwise (note 1). Task 9's sweep should re-fire it with DC10 or Task 7's real-settle test, and use the same spy.
