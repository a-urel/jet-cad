# The document lifecycle (12a) — design

**Date:** 2026-09-30. **Status:** design, revision 1, for independent review.
**Sub-project:** `roadmap/12-app-shell.md`, first slice (12a). **Size:** M:
application code, one small engine change (D3), two dependencies and two
platform edits (D9, D12).
**Branch:** `spec-12a/document-lifecycle`, cut from `main` at `cac7765`.
**Depends on:** 01–08, 10, 11 (merged). **Blocks:** the later 12 slices,
which reuse this slice's command table (D6) and document host (D2).
**Brainstormed with the human on 2026-09-30**, on `main`, after a survey of
the shell as it stands (the roadmap file predates most of the app: its "What
does not exist" is stale; the facts below are from `main` at `cac7765`).

**Inputs read:** `CLAUDE.md`; `STATUS.md`; `roadmap/12-app-shell.md`,
`roadmap/00-README.md`; `apps/floor_planner/lib/main.dart`,
`startup_plan.dart`, `shortcut_guard.dart`, `panel_focus.dart`,
`selection_panel.dart`, `page_panel.dart`;
`packages/jet_cad_2d/lib/src/document/undo.dart`, `command.dart`,
`tables.dart`; `packages/jet_cad_2d/lib/src/codec/json_codec.dart`;
spec 10 D17 (the DASHED linetype record); `file_selector` 1.1.0 and
`file_selector_web` 0.9.5 as published (Flutter 3.47.2 in the container).

## Decisions the human made on 2026-09-30

1. **Slice 12, document lifecycle first.** 12 is split into slices, each
   with its own spec and plan. 12a: New / Open / Save / Save As, swapping
   the document at runtime, dirty state and the close prompt, undo and redo
   buttons and the redo shortcut. The layer panel, the menu bar, the
   diagnostics surface and permissions in the UI are later slices.
2. **macOS and web, behind one interface.** macOS: native open and save
   dialogs through the first-party `file_selector`; Save writes the same
   file; the sandbox gains the user-selected read-write entitlement. Web:
   Open through the file picker; Save and Save As download a file (the
   browser cannot write back to the opened file). Tests run against a fake.
3. **Launch and New give an empty document; the sample stays reachable.**
   The startup flat moves behind **Open sample**, which opens it untitled
   and clean.
4. **A toolbar in the top bar, plus shortcuts.** New, Open, Save, Save As,
   Open sample, Undo, Redo as icon buttons with tooltips and a disabled
   state; Cmd/Ctrl+N, O, S, Shift+S, Z, Shift+Z (and Ctrl+Y for redo). One
   command table feeds both; the later menu bar reuses it.
5. **Dirty means the undo position differs from the save point.** Save,
   edit, undo: clean again. A saved state that falls off the 200-step
   history, or whose redo branch is cut by a new edit, can never come back
   clean.
6. **The file extension is `.jetplan`.** The content is the existing JSON
   codec's output, unchanged.
7. **Every close path is guarded as far as the platform allows.** New, Open
   and Open sample ask Save / Don't Save / Cancel in the app. On macOS,
   Cmd+Q and the window's close button ask the same. On web, closing the tab
   raises the browser's own generic warning (`beforeunload`); the browser
   offers no Save there.
8. **Recent files and autosave/crash recovery are deliberately out of 12a**
   (a later slice): both need a persistent store (sandbox bookmarks, a file
   handle store, a recovery area).
9. **On web, Save marks the document clean when the download starts.** The
   browser does not report whether the download finished; a cancelled or
   failed download leaves a clean-looking document (a known limit, D14).

## What this delivers

- The app opens on an empty, untitled, clean document with the default page.
- A toolbar at the left of the top bar: New, Open, Open sample, Save,
  Save As, then Undo and Redo. Each has a tooltip naming its shortcut; each
  is disabled when it cannot act.
- The top bar shows the document's name (`Untitled` until saved or opened)
  and a dirty mark.
- Open reads a `.jetplan` file and replaces the document; a file that cannot
  be read leaves the current document untouched and says why.
- Save writes the document to its file (macOS) or downloads it (web); Save
  As asks for a name first. Save → Open → Save is byte-identical.
- Replacing or closing a dirty document asks first.

## Non-goals

- The menu bar, the layer panel, the diagnostics surface, `DraftPermissions`
  in the UI beyond what exists (later 12 slices).
- Recent files, autosave, crash recovery (decision 8).
- A native macOS menu (`PlatformMenuBar`), document types registered with
  Finder, multiple windows or tabs, drag-and-drop open.
- Writing back to the opened file on web (File System Access API).
- Migrating older schema versions: the codec's own versioning decides what
  opens (D8).

## Decisions

### D1 — Where the pieces live

- **Engine** (`packages/jet_cad_2d`): one addition, the state identity of
  D3. Nothing else changes in the engine or the render layer.
- **App** (`apps/floor_planner/lib/`), new files:
  - `document_host.dart` — the host of D2: the current document, its name,
    its file, its save point, the replace and close flows (D10, D11).
  - `document_files.dart` — the `DocumentFiles` interface of D9 and its
    conditional-import selection; `document_files_io.dart` (macOS) and
    `document_files_web.dart` (web) implement it; tests use a fake.
  - `shell_commands.dart` — the command table of D6.
  - `document_toolbar.dart` — the toolbar widget of D7.
  - `new_document.dart` — the empty document of D4 (`startup_plan.dart`
    stays, renamed in meaning to the sample: D4).
  - `exit_guard*.dart` — the web `beforeunload` hook (conditional import)
    and the macOS exit wiring of D12.
- `main.dart`: `FloorPlannerApp` builds the host; `PlannerShell` keeps
  taking a `document` and is rebuilt per document (D2).

### D2 — The document host, and swapping a document

Today `PlannerShell`'s state owns the document through
`late final _document = widget.document ?? startupPlan(_measurer)`, and
everything else (index, parametric system, tools, caches, selection,
camera) is `late final` over it. There is no path to swap the document.

- **The host owns the document; the shell is keyed by it.** A
  `DocumentHost` (a `StatefulWidget` above `PlannerShell`) holds the current
  `DraftDocument` and builds `PlannerShell(key: ObjectKey(document),
  document: document, …)`. Replacing the document is `setState` on the host:
  Flutter disposes the old shell state (its `dispose` already releases the
  tools, the caches, the parametric system and the index,
  `main.dart:366-390`) and builds a fresh one over the new document. No
  field of the shell learns to swap; nothing stale can survive.
- **The replacement is built before anything is torn down.** New builds its
  document, Open decodes its file, Open sample builds the flat, all before
  `setState`. A failure (D8) leaves the current document and shell exactly
  as they were.
- **What survives a swap:** the object-snap setting (F3) and the host's own
  state. The snap settings move from the shell to the host, which passes
  them down. Everything else is per document and starts fresh: the active
  tool is Select, the selection is empty, the tool settings (wall
  thickness, opening widths) are their defaults, the camera fits the page.
  (Tool settings surviving a swap is a later preference; recorded, D14.)
- **The text measurer.** The shell creates a `FlutterTextMeasurer` today
  and clears it in `dispose`; the document must be built with the measurer
  `DraftCanvas` accepts (`startup_plan.dart:57-59`). The host creates one
  measurer per document, builds or decodes the document with it, hands both
  to the shell, and clears it when that document is replaced. The plan
  fixes the ownership in code; the invariant is: one measurer per document,
  the one the document was built with, cleared exactly once.
- **Pending text is committed before a flow reads the document.** A panel
  field holding typed but uncommitted text commits on focus loss today
  (`panel_focus.dart`). Every command of D6 that reads or replaces the
  document (Save, Save As, New, Open, Open sample, and the close flows)
  first takes focus back to the canvas (the panels' existing hand-back), so
  the typed value lands as its own undo step before the save point is
  compared or the bytes are written. A text-tool entry in progress
  (`TextEntryOverlay`) is committed the same way it is on focus loss today.

### D3 — Engine: a state identity on the dispatcher (decision 5)

The shell needs "is the document where it was when it was saved?" in O(1),
across undo and redo. The top undo entry's identity does not work: a redo
pushes a new inverse object. So the stack numbers the states it moves
between.

- `UndoStack` keeps `int _state` (the current state's id) and a counter.
  Each undo entry records the state it returns to; each redo entry the
  state it returns to.
  - `push` (a new edit): the entry records the current id; the current id
    becomes a fresh one. The redo stack is cleared as today, so every state
    only its entries could reach is gone for good.
  - `undo`: the current id becomes the popped entry's recorded id; the redo
    entry records the id being left.
  - `redo`: symmetric.
  - A failed undo or redo (the existing `catch` paths) leaves the id
    unchanged.
  - Eviction at `limit` drops the oldest entry and with it the only way back
    to its recorded state.
  - `clear()` (`notifyLoaded`, `notifyPurged`, `clearHistory`) keeps the
    current id: the document did not change, only the way back did.
- `CommandDispatcher` exposes it read-only: `int get stateId`. It is opaque:
  only equality means anything, and ids are never reused within a
  dispatcher.
- **Mutations outside the dispatcher do not change it.** A table edit
  (`TableSection.add`/`remove`) and `DraftDocument.purge`'s compaction are
  not commands. 12a's app makes neither after a document is built (D4's
  table writes happen before the save point is set); the later layer slice
  must route table edits through commands or mark the document dirty
  itself. Recorded (D14).

Engine tests pin: push/undo/redo move the id and return it exactly; save,
edit, undo is equal; edit, undo, new edit never returns to the pre-undo
id; eviction past the limit never returns to an evicted state; a failing
undo leaves the id; `clear` keeps it.

### D4 — The empty document, and the sample (decision 3)

- **New and launch** build `DraftDocument.empty(measurer)`, add the DASHED
  linetype record (`ensureDashedLinetype`, spec 10 D17), and attach the
  default `PageComponent` the startup plan attaches today (its sheet, scale,
  unit, grid and paper, unchanged). Untitled, clean.
- **Open sample** builds today's `startupPlan` flat (unchanged in content),
  untitled and clean. Saving it asks for a name (it is untitled).
- The startup plan's first-line comment ("before sub-project 12 gives it a
  file") is corrected; the file stays `startup_plan.dart`, used only by Open
  sample and the tests that build the flat.

### D5 — Dirty, clean, and the save point (decisions 5, 9)

- The host keeps `int? savedState`. **Clean** iff
  `document.commands.stateId == savedState`. A new document, a sample and an
  opened file set `savedState` to the fresh document's id (clean).
- A successful save sets `savedState` to the current id. A failed save
  leaves it.
- On web, "successful" is "the download was handed to the browser"
  (decision 9).
- The host listens to `document.commands.changes` (the async stream; the
  synchronous `onAfterMutate` slot belongs to the index) and rebuilds the
  dirty mark, the toolbar's enabled states and the window title on each
  change. A `ValueListenable<bool> dirty` carries it to the widgets.
- The dirty mark: a `•` before the document name in the top bar, and
  `Edited` in the tooltip. On web the tab title is `name — jet-cad`, with
  `• ` prefixed when dirty (Flutter's `Title` widget).

### D6 — The command table (decision 4)

One list of `ShellCommand`s, each:
`id`, `label`, `icon`, `tooltip` (label and shortcut),
`List<ShortcutActivator> shortcuts`, `ValueListenable<bool> enabled`,
`Future<void> Function() run`.

| Command | Shortcuts (macOS / elsewhere) | Enabled |
|---|---|---|
| New | Cmd+N / Ctrl+N | always |
| Open… | Cmd+O / Ctrl+O | always |
| Open sample | — | always |
| Save | Cmd+S / Ctrl+S | always (an untitled document runs Save As) |
| Save As… | Cmd+Shift+S / Ctrl+Shift+S | always |
| Undo | Cmd+Z / Ctrl+Z | `canUndo` |
| Redo | Cmd+Shift+Z / Ctrl+Shift+Z, Ctrl+Y | `canRedo` |

- The toolbar (D7) and the shell's `CallbackShortcuts` are both built from
  the table: one definition per command. The existing undo binding
  (`main.dart:396-412`) moves into it; F3, the tool letters, F and Escape
  stay where they are.
- **Enabled is read, not assumed:** a shortcut on a disabled command does
  nothing (no dispatcher call). `canUndo`/`canRedo` are re-read on every
  document change.
- **One flow at a time.** While a flow awaits a dialog or a file, every
  command of the table is disabled and its shortcut ignored (a second
  Cmd+S during a save dialog does nothing).
- **Text fields.** `ShellShortcutGuard` stops the tool letters at a text
  field today. The table's modifier shortcuts are **not** stopped: Cmd+S
  in a panel field saves (after D2's commit). Cmd+Z and Cmd+Shift+Z in a
  focused text field stay the field's own undo and redo (the field handles
  them before they bubble); in the canvas they are the document's.
- **Web reserves some shortcuts.** Browsers keep Cmd/Ctrl+N (and W, T) for
  themselves; the page never sees them. New stays reachable by its button.
  Cmd/Ctrl+S and O reach the page; the handler must consume them so the
  browser's own Save Page and Open File do not also run (the plan verifies
  it in Chrome and Firefox; recorded for the human's look).

### D7 — The toolbar and the top bar (decision 4)

- The top bar (`chrome-top`, 44 px) gains, at its left: the toolbar (seven
  icon buttons, a gap between the file group and Undo/Redo), then the
  document name with its dirty mark, then today's status line, Spacer, OSNAP
  and zoom as now.
- Buttons are `IconButton`s with tooltips (`Save (⌘S)` on macOS, `Save
  (Ctrl+S)` elsewhere), keys `toolbar-<id>`, disabled per D6. They never
  take focus from the canvas (`ExcludeFocus`, as the tool palette does).

### D8 — Opening a file

- **Pick:** `DocumentFiles.open()` returns `(name, bytes)` or null
  (cancelled: nothing happens).
- **Decode:** UTF-8, then `DraftDocumentCodec.decodeString(text,
  measurer: FlutterTextMeasurer(…), registerComponents:
  parametricCatalog.registerComponents, diagnostics: list)`. Without the
  catalog the app's components load as preserve-unknown and every object
  vanishes; the test pins it.
- **Failure:** any exception while reading or decoding (not UTF-8, not JSON,
  a schema version the codec refuses, a malformed document) shows an error
  dialog naming the file and the exception's message; the current document
  is untouched (D2).
- **Success:** the host swaps to the decoded document, named after the file
  (its base name without `.jetplan`), clean. The shell installs its
  parametric system over it as it does today; nothing regenerates on load
  (06 D10). Decode diagnostics (tree repairs, fill rebuilds) are not shown
  in 12a (the diagnostics slice); they are counted in a debug log only.
- **The DASHED linetype record** (spec 10 D17 left this to 12): Open does
  **not** add it. Adding it would change the document outside history and
  break byte identity (a file saved without edits would differ from what
  was opened). Every document the app makes has it (D4); a foreign file
  without it draws its separators continuous (spec 10's fallback). Ruled
  here; revisit with the layer slice if needed.
- **Byte identity.** A file written by this app, opened and saved without
  an edit, is byte-identical to the file (the codec is deterministic). A
  file written by an older codec version is re-encoded in today's form.

### D9 — `DocumentFiles` (decision 2)

```dart
abstract interface class DocumentFiles {
  /// null when the person cancelled.
  Future<({String name, Uint8List bytes, Object? location})?> open();
  /// Where to save; null when cancelled. [suggestedName] ends in .jetplan.
  Future<Object?> saveLocation(String suggestedName);
  /// Writes [bytes] to [location]; throws on failure.
  Future<void> write(Object location, String name, Uint8List bytes);
  /// Whether [write] to the location an [open] returned overwrites that
  /// file (macOS) or downloads a copy (web).
  bool get writesInPlace;
}
```

The plan may reshape the signatures; the contract is: open returns bytes
and an optional location; a location is opaque to the host; cancel is null,
failure is a throw.

- **macOS** (`document_files_io.dart`): `file_selector`'s `openFile` and
  `getSaveLocation` with an `XTypeGroup(label: 'Jet plan', extensions:
  ['jetplan'])`; `write` is `File(path).writeAsBytes(bytes, flush: true)`
  (`dart:io`, never imported on web). Save As appends `.jetplan` when the
  chosen name lacks it. Location is the path.
- **web** (`document_files_web.dart`): `openFile` through `file_selector`
  (`file_selector_web` implements it); the location it returns is null.
  `saveLocation` asks for a name in an app dialog (the browser has no save
  dialog; `file_selector_web`'s `getSaveLocation` returns an empty dummy) and
  returns the name; `write` downloads the bytes under that name
  (`XFile.fromData(bytes, mimeType: 'application/json', name: …)
  .saveTo('')`, which triggers a download on web). `writesInPlace` is false.
- **Save** with a known in-place location writes there; otherwise (untitled,
  or web) Save behaves as Save As for the first save of an untitled
  document, and on web Save downloads under the current name without asking.
- **Dependencies:** `file_selector` (^1.1.0) in the app's pubspec, and
  `cross_file` if `XFile` is not re-exported. The web implementation is
  endorsed by `file_selector`; the macOS one too. Both are first-party
  (flutter.dev).
- **Tests** inject a `FakeDocumentFiles` (records writes, returns scripted
  opens, cancels and throws). No test touches a real dialog.

### D10 — Replacing a dirty document (decision 7)

New, Open and Open sample, when the document is dirty, first show an app
dialog: **Save**, **Don't Save**, **Cancel** (default Save; Escape is
Cancel).

- **Save:** runs Save (D9; Save As if untitled). If the save is cancelled
  or fails, the replacement does not happen.
- **Don't Save:** the replacement proceeds.
- **Cancel:** nothing happens.
- A clean document is replaced without a dialog.
- For Open, the dialog comes **before** the file picker (as macOS apps do).

### D11 — Closing the app (decision 7)

- **macOS:** the host registers an `AppLifecycleListener(onExitRequested:
  …)`. Clean: `AppExitResponse.exit`. Dirty: the D10 dialog; Save then exit
  if the save succeeds, Don't Save exits, Cancel returns
  `AppExitResponse.cancel`. Cmd+Q reaches it through `FlutterAppDelegate`'s
  `applicationShouldTerminate`. **The window's close button** does not by
  itself: with `applicationShouldTerminateAfterLastWindowClosed` true
  (`macos/Runner/AppDelegate.swift`), AppKit closes the window first and
  terminates after, so a cancel would leave a running app with no window.
  `MainFlutterWindow` therefore implements `windowShouldClose(_:)` to
  return false and call `NSApp.terminate(nil)`, which routes the close
  through the same exit request; an allowed exit terminates the app, a
  cancelled one leaves the window open. This is the one native edit; it is
  verified on the human's Mac (it cannot run in the Linux container).
- **Web:** while dirty, the host sets a `beforeunload` handler that calls
  `preventDefault()` (and sets `returnValue`), and removes it when clean.
  The browser shows its own generic warning. Implemented behind a
  conditional import (`package:web`, already a transitive dependency; the
  app's pubspec declares it if imported).

### D12 — Platform edits

- `macos/Runner/Release.entitlements` and `DebugProfile.entitlements`: add
  `com.apple.security.files.user-selected.read-write` (true). Without it the
  sandboxed app's open and save dialogs fail.
- `macos/Runner/MainFlutterWindow.swift`: `windowShouldClose` as D11.
- No web platform file changes.

### D13 — Draw order, undo, save and load

- Nothing here writes entities. Draw order, undo and redo of edits are
  unchanged.
- Opening clears history (the codec's `notifyLoaded`); New and Open sample
  start with an empty history (the sample's builder already clears it).
- Save writes `DraftDocumentCodec.encodeToString(document)` as UTF-8, and
  nothing else: no pretty-printing, no re-ordering (M-12b).

### D14 — Known limits

- Web: a cancelled or failed download leaves the document clean
  (decision 9); Cmd/Ctrl+N is the browser's (D6); the tab-close warning is
  the browser's generic one.
- A table edit or purge outside the dispatcher does not mark the document
  dirty (D3). 12a makes none after a document is built.
- Tool settings reset on every New/Open (D2).
- Opening a foreign file without the DASHED record draws its separators
  continuous (D8).
- Decode diagnostics are not shown (D8); the diagnostics slice shows them.
- A saved state evicted from the 200-step history cannot become clean by
  undoing (decision 5); this is correct, not a limit, and is pinned.

## Architecture

### Files

| File | Change |
|---|---|
| `packages/jet_cad_2d/lib/src/document/undo.dart` | D3 |
| `packages/jet_cad_2d/test/document/undo_state_test.dart` (new) | D3 |
| `apps/floor_planner/lib/main.dart` | the host at the root; undo binding moves to the table; snap settings passed in; measurer passed in |
| `apps/floor_planner/lib/{document_host,document_files,document_files_io,document_files_web,shell_commands,document_toolbar,new_document,exit_guard*}.dart` (new) | D2, D4–D11 |
| `apps/floor_planner/lib/startup_plan.dart` | comment (D4) |
| `apps/floor_planner/pubspec.yaml` | `file_selector` (and `cross_file`, `web` if imported) |
| `apps/floor_planner/macos/Runner/*.entitlements`, `MainFlutterWindow.swift` | D12 |
| `apps/floor_planner/test/` | the tests below; existing tests that pump `PlannerShell` directly keep doing so |

### Invariants

- One command definition per command; the toolbar and the shortcuts cannot
  disagree.
- The UI never relies on the dispatcher refusing: a disabled command makes
  no call.
- A failed open or save changes nothing but the dialog.
- The bytes written are exactly `encodeToString`'s, UTF-8.
- Frame path untouched: nothing here runs per frame; the dirty listener
  runs per document change.

## Testing

Widget tests pump the host with a `FakeDocumentFiles`. Fixtures are not
degenerate: the documents tested are the sample flat (walls, openings,
rooms, dimensions in rotated groups off the origin) and a New document
with an edit through a real tool, never an empty one alone.

### Tests by area

- **Engine (D3):** the state-id rules listed there, each its own case,
  including eviction at a small limit (e.g. `undoLimit: 3`) and a failing
  undo.
- **Launch and New (D4):** the launch document is empty, untitled, clean,
  with the default page and handle 6's DASHED record; New after edits
  (clean) replaces it with the same.
- **Round trip (exit criterion):** sample → Save As (fake records bytes) →
  Open those bytes → Save → the second bytes `==` the first, and the opened
  document's walls/openings/rooms/dimensions `==` the saved ones' components.
- **Open failures (D8):** not UTF-8, not JSON, a schema version the codec
  refuses, and a cancel: each leaves the same document object in the host,
  the same undo depth, no swap; the three failures show the dialog.
- **Catalog on decode (D8):** a file with walls opens with live walls
  (`liveObjectsOf<WallParams>` non-empty) — red if the catalog is not passed.
- **Dirty (D5):** edit → dirty; undo → clean; redo → dirty; save → clean;
  edit, undo, other edit → dirty and undo once more → dirty; the dirty mark
  and the tab title follow.
- **Undo/Redo buttons (D6, D7):** disabled on a fresh document; enabled
  after an edit (Undo) and after an undo (Redo); a tap undoes one step;
  shortcuts do the same; a disabled shortcut makes no dispatcher call.
- **Pending panel text (D2):** type a wall thickness without Enter, press
  Cmd+S: the saved bytes carry the typed thickness, and history has the
  commit as its own step before the save point.
- **Replace flows (D10):** dirty + New → dialog; Cancel keeps everything;
  Don't Save replaces; Save + fake cancel of the save dialog keeps
  everything; Save + success writes then replaces. Clean + New → no dialog.
  Open: dialog before the picker.
- **One flow at a time (D6):** while the fake's save future is pending, a
  second Cmd+S makes no second write.
- **Exit (D11):** the host's exit handler answers exit when clean, cancel on
  Cancel, exit after a successful Save, cancel after a failed one (driven
  by calling the listener's callback; the native wiring is the human's
  look).
- **Web specifics (D9, D11):** with a fake reporting `writesInPlace: false`,
  Save on a titled document writes without asking and marks clean; the
  `beforeunload` hook's state follows dirty (tested through the hook's
  Dart-side interface, not a browser).
- **Swap hygiene (D2):** after Open, the old shell's parametric system is
  disposed (its expander slot released on the old dispatcher), the new
  document's is installed, the selection is empty, Select is active, and
  the snap setting is what it was.

### Named mutants

- **M-12a-1:** save writes `jsonEncode` of a re-ordered map (keys sorted
  differently) — the round-trip test goes red. (Roadmap M-12b.)
- **M-12a-2:** the save point is not moved on a successful save — the
  dirty test after save goes red. (Roadmap M-12d.)
- **M-12a-3:** the save point is moved on a failed or cancelled save — the
  failure test goes red.
- **M-12a-4:** dirty as "any change since save" (never cleaned by undo) —
  edit/undo goes red.
- **M-12a-5:** the state id restored from the top entry's identity instead
  of the recorded id — redo after undo goes red (engine test).
- **M-12a-6:** eviction keeps the evicted state reachable (e.g. the id is
  recomputed from depth) — the eviction test goes red.
- **M-12a-7:** open decodes without `registerComponents` — the catalog test
  goes red.
- **M-12a-8:** the host swaps before decoding succeeds — the failure test
  goes red (the document changes).
- **M-12a-9:** Undo's shortcut ignores `enabled` and calls the dispatcher —
  the "no dispatcher call" test goes red (the UI must not rely on the
  dispatcher's own no-op; roadmap M-12a's principle).
- **M-12a-10:** the replace flow skips the dialog when dirty — the replace
  test goes red.
- **M-12a-11:** Save does not hand focus back first — the pending-text test
  goes red.
- **M-12a-12:** the busy flag is not set during a flow — the one-flow test
  goes red.

## Exit gate

- Engine, render layer, app: the standing gates green (CLAUDE.md), with
  `CI=true`; app `flutter build web --release` builds.
- Every named mutant fired and red, recorded in the results note.
- **The human's look on macOS:** New, Open, Save, Save As with the native
  dialogs in the sandboxed release build; Cmd+Q and the close button on a
  dirty document ask and Cancel keeps the window; a saved `.jetplan` opens
  back identically. **On web (Chrome, Firefox):** Open picks a file; Save
  downloads `name.jetplan`; Cmd/Ctrl+S does not also open the browser's
  Save Page; closing a dirty tab warns.

## Spec rulings

- **R-1 (D2):** keyed rebuild of the shell per document, over teaching the
  shell to swap: the shell's many `late final` fields over the document are
  correct as written, and a swap path would have to reset every one of
  them.
- **R-2 (D3):** a state id in the engine, over a save point in the app: the
  app cannot see eviction or redo-branch loss without it.
- **R-3 (D8):** Open does not add the DASHED record (byte identity).
- **R-4 (D11):** the macOS close button routes through the exit request.

## Open questions for the reviewer

- Whether `FlutterAppDelegate` in Flutter 3.47 routes
  `applicationShouldTerminate` to `onExitRequested` without further native
  code (D11 assumes it does).
- Whether `XFile.saveTo` on web in the current `cross_file` still downloads
  (D9 assumes it does); the fallback is an anchor download through
  `package:web`.
