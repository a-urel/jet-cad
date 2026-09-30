# The document lifecycle (12a) — design

**Date:** 2026-09-30. **Status:** design, **revision 3**. Revision 1
(`e5a26d2`) was reviewed independently: "Not ready", 2 blocking, 11 major
and 15 minor findings (S-1 to S-28), every one with a local fix inside the
human's decisions. Revision 2 (`c54ca55`) applied all of them; its
independent re-review: "Ready with amendments", 2 major and 11 minor new
findings (T-1 to T-13), and a spot check suffices after them. Revision 3
applies those; see [Revision 2](#revision-2) and [Revision 3](#revision-3).
**Sub-project:** `roadmap/12-app-shell.md`, first slice (12a). **Size:** M:
application code, one small engine change (D3), one dependency and two
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
`selection_panel.dart`, `page_panel.dart`, `text_entry_overlay.dart`;
`packages/jet_cad_2d/lib/src/document/undo.dart`, `command.dart`,
`tables.dart`; `packages/jet_cad_2d/lib/src/codec/json_codec.dart`;
spec 10 D3 (the DASHED linetype record); `file_selector` 1.1.0,
`file_selector_web` 0.9.5 and `cross_file` 0.3.5+5 / 0.4.0 as published;
Flutter 3.47.2's framework and macOS embedder sources (the review's
S-14).

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

- The app opens on an empty, untitled, clean document with a default page.
- A toolbar at the left of the top bar: New, Open, Open sample, Save,
  Save As, then Undo and Redo. Each has a tooltip naming its shortcut; each
  is disabled when it cannot act.
- The top bar shows the document's name (`Untitled` until saved or opened)
  and a dirty mark; on web the tab title carries both.
- Open reads a `.jetplan` file and replaces the document; a file that cannot
  be read leaves the current document untouched and says why.
- Save writes the document to its file (macOS) or downloads it (web); Save
  As asks for a name first. Save → Open → Save is byte-identical, and the
  bytes written are exactly the codec's.
- Replacing or closing a dirty document asks first.

## Non-goals

- The menu bar, the layer panel, the diagnostics surface, `DraftPermissions`
  in the UI beyond what exists (later 12 slices; the permissions slice must
  make Undo/Redo's `enabled` read permissions: in 12a a read-only document
  is unreachable).
- Recent files, autosave, crash recovery (decision 8).
- A native macOS menu (`PlatformMenuBar`), document types registered with
  Finder, the native window title, multiple windows or tabs, drag-and-drop
  open.
- Writing back to the opened file on web (File System Access API).
- Migrating older schema versions: the codec's own versioning decides what
  opens (D8).

## Decisions

### D1 — Where the pieces live

- **Engine** (`packages/jet_cad_2d`): one change, the state identity of D3.
  **Render layer:** at most one getter, `Tool.isMidShape` (D6, T-2), if the
  plan finds no existing way to ask whether the active tool is part-way
  through a shape. Nothing else changes in either package.
- **App** (`apps/floor_planner/lib/`), new files:
  - `document_host.dart` — the host of D2: the current document, its
    measurer, its name, its file location, its save point, the busy flag,
    the replace and close flows (D10, D11).
  - `document_files.dart` — the `DocumentFiles` interface of D9 and its
    conditional-import selection; `document_files_io.dart` (macOS) and
    `document_files_web.dart` (web) implement it; tests use a fake.
  - `shell_commands.dart` — the `ShellCommand` type and the table of D6.
  - `document_toolbar.dart` — the toolbar widget of D7.
  - `new_document.dart` — the empty document of D4 and the shared set-up
    helper both it and the sample call.
  - `exit_guard.dart` (+ `_web` / `_stub` by conditional import) — the web
    `beforeunload` hook of D11.
- `parametric/catalog.dart` gains `registerAppComponents(ComponentRegistry)`
  (D8).
- **The shell's seam** (`main.dart`). `PlannerShell` keeps taking a
  `document` and gains optional parameters: the file commands
  (`List<ShellCommand>`), the busy listenable, the document name, the dirty
  listenable, the snap settings, and a `pendingInput` registration (D2).
  **Undo and Redo are per-document commands the shell builds for itself**
  (enabled = `canUndo`/`canRedo` and not busy), so a shell pumped bare, as
  about ten existing test files do (`wall_tool_test.dart`,
  `planner_draw_test.dart`, … pressing meta+Z), keeps undo, and gains redo.
  With no file commands passed, the shell shows Undo/Redo only.
- `FloorPlannerApp` builds the host; the host builds the shell.

### D2 — The document host, and swapping a document

Today `PlannerShell`'s state owns the document through
`late final _document = widget.document ?? startupPlan(_measurer)`, and
everything else (index, parametric system, tools, caches, selection,
camera) is `late final` over it. There is no path to swap the document.

- **The host owns the document; the shell is keyed by it.** A
  `DocumentHost` (a `StatefulWidget` above `PlannerShell`) holds the current
  `DraftDocument` and builds `PlannerShell(key: ObjectKey(document),
  document: document, …)`. Replacing the document is one `setState` on the
  host, which also resets the save point, the name and the location (S-28):
  Flutter disposes the old shell state (its `dispose` releases the tools,
  the caches, the parametric system's expander slot and the index's hooks,
  `main.dart:366-390`) and builds a fresh one over the new document.
- **The replacement is built before anything is torn down.** New builds its
  document, Open decodes its file, Open sample builds the flat, all before
  `setState`. A failure (D8) leaves the current document, shell, name, save
  point and history exactly as they were.
- **After the swap, the host disposes the old document** (post-frame, after
  the old shell's `dispose` has run): `oldDocument.dispose()` closes its
  dispatcher's change stream, ending every subscription still on it — one
  is known: `DimensionGrips`' per-drag memo subscription survives a
  cancelled dimension-grip preview (`dimension_grips.dart:147-172`; no
  `dispose` reaches it) — and makes any stale use throw
  (`undo.dart:227-231`). Then it clears the old measurer.
- **What survives a swap:** the object-snap setting (F3). `SnapSettings`
  moves to the host, which passes it down; **the shell stops disposing it**
  (`main.dart:381` today). Everything else is per document and starts
  fresh: the active tool is Select, the selection is empty, the tool
  settings (wall thickness, opening widths) are their defaults, the camera
  fits the page. (Tool settings surviving a swap is a later preference,
  D14.)
- **The text measurer.** The host creates one `FlutterTextMeasurer` per
  document, builds or decodes that document with it, and clears it after
  the document is replaced (post-frame, after the old shell's dispose), or
  at once when a decode fails. The shell no longer creates or clears a
  measurer: it never used one except to build the startup plan. The
  invariant is: one measurer per document, the one it was built with,
  cleared once. (Not mutant-tested: nothing observable counts clears; the
  plan keeps the code in one place.)
- **Pending input is settled before a flow reads the document** (S-4, S-5).
  Every command of D6 that reads or replaces the document (Save, Save As,
  New, Open, Open sample, and the close flows of D10 and D11) first calls
  the shell's `settlePendingInput()`, which runs **synchronously** (T-4):
  it commits an open text entry, hands a panel field back, and then calls
  `FocusManager.instance.applyFocusChangesIfNeeded()` — public API meant for
  "making sure no focus changes are pending before executing an action",
  used by `MenuAnchor` for exactly this (`menu_anchor.dart:1312`) — so the
  focus-loss listeners that would otherwise run a microtask later
  (`focus_manager.dart:1943-1947`) have committed before the flow reads the
  state id or encodes. No timer, no await: a `Future.delayed(Duration.zero)`
  never fires under `tester.pump()` without a duration, and would make
  "nothing happened" tests pass for the wrong reason. The pending inputs
  and their rules:
  - **A Selection panel field** with typed, unsubmitted text: handed back
    (`PanelFieldFocusNode.handBack()`); its focus-loss listener commits the
    value as its own undo step (`selection_panel.dart:440-446`), before the
    save point is taken.
  - **The text entry** (`TextEntryOverlay`), open with typed text: the
    flow calls the Text tool's `finish(ctx)` (`text_tool.dart:53`, which
    commits `controller.text`) before focus moves; today a focus loss
    **cancels** it (`text_entry_overlay.dart:22-24, 72-78`), and that rule
    stays for every other focus loss.
  - **The page panel's scale field**: unsubmitted text is not saved — the
    field's existing rule (`page_panel.dart:58-85`: nothing commits on focus
    loss) — and the settle re-syncs the field to the stored scale, as its
    tap-outside does (`_syncScale`, `page_panel.dart:88-90`), so the panel
    never shows a scale the saved file does not have. Recorded (D14).
  - **A pointer on the toolbar** must not end the text entry before the
    flow runs (T-1): the overlay's `TextField` unfocuses on a tap outside
    it (EditableText's default, on macOS, Windows and Linux for every
    pointer kind, and for a mouse elsewhere, `editable_text.dart:6876-6906`),
    and its focus loss cancels the entry (`text_entry_overlay.dart:72-78`) on
    pointer down, before the button's `onPressed`. **The toolbar is wrapped
    in a `TextFieldTapRegion`**, so a press on it is not outside any field;
    the flow's settle then commits the entry for the button exactly as for
    the key. Undo and Redo settle too (a typed panel value lands as its own
    step before the undo, so Undo undoes that value first — the same as
    pressing Enter and then Undo).

### D3 — Engine: a state identity on the dispatcher (decision 5)

The shell needs "is the document where it was when it was saved?" in O(1),
across undo and redo. The top undo entry's identity does not work: a redo
pushes a new inverse object. So the stack numbers the states it moves
between.

- `UndoStack`'s entries become records `(DraftCommand command, int
  returnsTo)`; it keeps `int _state` (the current state's id) and a
  counter. **Transitions are whole operations of the stack**, so no
  primitive can stamp an id by accident (S-6):
  - `recordExecute(inverse)`: pushes `(inverse, _state)`; `_state` becomes a
    fresh id; the redo stack is cleared (as today), so every state only its
    entries reached is gone for good. Eviction at `limit` drops the oldest
    entry and with it the only way back to its recorded state.
  - Undo is **take → apply → commit or abort**: `beginUndo()` returns the
    top entry's command without popping it; after a successful apply,
    `commitUndo(redoInverse)` pops it, pushes `(redoInverse, _state)` on the
    redo stack and sets `_state` to the entry's `returnsTo`; after a failed
    apply, `abortUndo()` leaves both stacks and `_state` exactly as they
    were (the entry keeps its original `returnsTo`).
  - Redo symmetric: `beginRedo()`, `commitRedo(undoInverse)` (pushes
    `(undoInverse, _state)` on the undo stack without clearing redo, sets
    `_state` to the redo entry's `returnsTo`), `abortRedo()`.
  - `clear()` (`notifyLoaded`, `notifyPurged`, `clearHistory`) keeps
    `_state`: the document did not change, only the way back did.
  - The old primitives (`push`, `takeUndo`, `pushRedo`, `takeRedo`,
    `pushUndoOnly`) are public on an exported class today
    (`jet_cad_2d.dart:38`). They are replaced by the transitions above;
    nothing outside `CommandDispatcher` calls them (checked: `UndoStack` is
    used only there; `ParametricSystem` wraps through `expander` only). The
    plan records the API change in spec 02's history section.
- `CommandDispatcher` exposes it read-only: `int get stateId`. It is
  opaque: only equality within one dispatcher means anything; ids are never
  reused within a dispatcher, and two dispatchers' ids are unrelated (the
  host resets its save point with every swap, D2).
- **Mutations outside the dispatcher do not change it.** A table edit
  (`TableSection.add`/`remove`), `DraftDocument.purge`, and the handle seed
  (`handleSeed.next()`, which tools call outside commands and undo does not
  roll back, `wall_tool.dart:221`) are not commands. After a document is
  built, 12a's app makes no table edit or purge (checked by the review:
  none in `apps/floor_planner/lib` or `jet_cad_2d_flutter/lib`). The seed
  means **clean is not byte-equal**: edit, undo is clean, and a save then
  writes a later `handleSeed` (D14). The later layer slice must route table
  edits through commands or mark the document dirty itself.

Engine tests pin: execute/undo/redo move the id and return it exactly;
edit, undo is the pre-edit id; edit, undo, new edit never returns to the
undone id; eviction at `undoLimit: 3` never returns to an evicted state;
**a failed undo, then a successful one** (edit A→B; `permissions =
readOnly`; undo throws, id is B; `permissions = all`; undo; id `==` A), and
the same for redo; `clear` keeps the id.

### D4 — The empty document, and the sample (decision 3)

- **One set-up helper** (`new_document.dart`), called by New and by the
  sample: `DraftDocument.empty(measurer: m)`; `registerAppComponents`
  (D8: `PageComponent` then the catalog; `PageComponent.register` wipes a
  live page if called twice, so it is called exactly once per registry);
  `header.units = DrawingUnits.millimeters` (the header default is
  `unitless`, `header.dart:9`; the sample sets millimetres at
  `startup_plan.dart:194`); `ensureDashedLinetype`.
- **New and launch** then attach **a fixed default page** (S-3): today's
  sample page parameters (A4 landscape, 1:50, metres, grid and paper
  defaults) with a **fixed origin**, not one centred on the extents — an
  empty document's extents are infinite and their centre is NaN, which
  `PageComponent`'s own constructor refuses (`startupPage` on an empty
  document throws at `copyWith`, `page_component.dart:109-116`). The page
  is exactly **`PageComponent(originX: -7425, originY: -5250)`**, every
  other field at its default: the A4 landscape sheet at 1:50 is
  14,850 × 10,500 world mm (`sheetWorldRect`, `page_geometry.dart:7-12`),
  so it is centred on the world origin. The launch test compares against
  this literal (T-11). The page is attached through `execute` and
  the history is then cleared, before the host takes the save point, so a
  fresh document has Undo disabled. Untitled, clean.
- **Open sample** builds today's `startupPlan` flat through the same
  helper (content unchanged; its page stays centred on its extents),
  untitled and clean. Saving it asks for a name.
- The startup plan's first-line comment ("before sub-project 12 gives it a
  file") is corrected; the file stays `startup_plan.dart`, used by Open
  sample and the tests that build the flat.

### D5 — Dirty, clean, and the save point (decisions 5, 9)

- The host keeps `int? savedState`. **Clean** iff
  `document.commands.stateId == savedState`. A new document, a sample and an
  opened file set `savedState` to the fresh document's id (clean), in the
  same `setState` as the swap.
- **The save point is the id the bytes were encoded at** (S-2). A save
  captures `final id = document.commands.stateId` in the same synchronous
  block as `encodeToString`, after D2's settle step; on success it sets
  `savedState = id` — not the id when the write completes. The canvas stays
  editable while a write is pending, so an edit made then leaves the
  document dirty, as it should. A failed or cancelled save leaves
  `savedState`.
- On web, "successful" is "the download was handed to the browser"
  (decision 9).
- Writing `savedState` recomputes `dirty` at once (a save emits no document
  change).
- **The host subscribes to the current document's `commands.changes`**
  (the async stream; the synchronous `onAfterMutate` slot belongs to the
  index), and **cancels and re-makes the subscription with every swap**
  (S-23). Each change recomputes a `ValueNotifier<bool> dirty` and the
  shell re-reads `canUndo`/`canRedo`.
- The dirty mark: a `•` before the document name in the top bar, and
  `Edited` in its tooltip. On web the tab title is `name — jet-cad`, with
  `• ` prefixed when dirty. It is set through `MaterialApp.onGenerateTitle`
  fed from the host's state, not an inner `Title` widget: `WidgetsApp`
  wraps everything in its own `Title` (`app.dart:1810`), and a rebuild of
  the app would reset an inner one's value (T-13). It affects only the web
  tab (S-27).

### D6 — The command table (decision 4)

One type, `ShellCommand`: `id`, `label`, `icon`, `tooltip` (label and
shortcut glyph), `List<ShortcutActivator> shortcuts`,
`ValueListenable<bool> enabled`, `Future<void> Function() run`.

| Command | Shortcuts (bound on every platform) | Enabled |
|---|---|---|
| New | Meta+N, Ctrl+N | idle |
| Open… | Meta+O, Ctrl+O | idle |
| Open sample | — | idle |
| Save | Meta+S, Ctrl+S | idle (untitled runs Save As) |
| Save As… | Meta+Shift+S, Ctrl+Shift+S | idle |
| Undo | Meta+Z, Ctrl+Z | idle and `canUndo` |
| Redo | Meta+Shift+Z, Ctrl+Shift+Z, Ctrl+Y | idle and `canRedo` |

**Idle** means: no flow is busy, and the active tool is not part-way
through a shape (T-2).

- **Both modifiers are bound everywhere** (as Z is today,
  `main.dart:398-399`); only the tooltip's glyph follows
  `defaultTargetPlatform` (`⌘S` on macOS, which web on a Mac reports too;
  `Ctrl+S` elsewhere) (S-26).
- The toolbar (D7) and the shell's `CallbackShortcuts` are both built from
  the table: one definition per command. The existing undo binding
  (`main.dart:398-399`) becomes the table's Undo; F3, the tool letters, F
  and Escape stay where they are.
- **A disabled command still matches its shortcut and does nothing** (S-8,
  S-26): the binding stays present and its callback returns without calling
  the dispatcher or the flow. Keeping it bound is what consumes the key on
  web, where Flutter calls `preventDefault()` only for a handled key
  (`keyboard_binding.dart:596-599`), so Cmd/Ctrl+S never opens the browser's
  Save Page, even during a busy flow.
- **Mid-shape** (T-2). Specs 03 D5 and 05 D3 and Ruling 07-1 say an undo
  never lands on a half-placed shape; the mechanism is the pending tool
  swallowing every key-down (`placement_tool.dart:199-204`), so today's
  chords are already inert mid-shape. A toolbar click is a pointer event no
  tool sees, so **every command is disabled while the active tool is
  part-way through a shape** — a Wall chain with a wall down, a
  Polyline or Dimension between clicks — and the buttons and the keys
  agree. Escape (or finishing the shape) enables them again. The shell
  listens to the `ToolController` for it. The plan decides how to ask a
  tool: an existing per-tool pending getter (`PlacementTool.isPending`,
  `placement_tool.dart:70`) where every such tool has one, or a new
  `Tool.isMidShape` on the render layer's base class (default false). An
  open text entry is **not** mid-shape: a flow commits it (D2).
- **One flow at a time.** Busy belongs to the **outermost** flow (T-8):
  the command wrappers set `busy` before their first await and clear it in
  a `finally` (S-21), on success, cancel, failure and throw. Save and Save
  As are plain steps returning success, which the replace flow (D10) and
  the exit flow (D11) call inside their own busy span, never through the
  guarded command. While busy, every command is disabled (Undo and Redo
  too: an undo during a save would move the state under the flow). The
  canvas itself stays live (D5 handles an edit made during a write).
- **Bound above the dialogs too** (T-3). The shell's `CallbackShortcuts`
  is inside the home route, so a dialog (D10's, the error dialog, the web
  name prompt) is outside its focus chain, and a key it does not handle is
  not `preventDefault`ed on web. The file chords are therefore bound once
  more above the Navigator (a `CallbackShortcuts` in `MaterialApp.builder`,
  below `DefaultTextEditingShortcuts`, `app.dart:1818-1823`), calling the
  same table's `run`; disabled or busy, they match and do nothing. So
  Cmd/Ctrl+S never opens the browser's Save Page, even with a dialog up.
- **Text fields** (S-7). Flutter's text-editing shortcuts sit at the app
  root, above the shell (`app.dart:1823`), so the shell's bindings see a
  field's keys first; `ShellShortcutGuard` is what gives a field its own
  keys back. It lists Meta+Z and Ctrl+Z today (`shortcut_guard.dart:49-52`)
  and gains **Meta+Shift+Z, Ctrl+Shift+Z and Ctrl+Y** (a `SingleActivator`
  matches modifiers exactly). In a focused field they **never reach the
  document**; in the canvas they are the document's. (The guard maps them
  to a stop-propagation intent, so the field's own text undo does not run
  either — `DoNothingAction(consumesKey: false)`; unchanged since spec 05
  for Cmd+Z. Mapping them to `UndoTextIntent`/`RedoTextIntent` would give
  fields a real undo; left to a later slice, T-5.) The file shortcuts
  (Meta/Ctrl+N, O, S, Shift+S) are **not** guarded: Cmd+S in a panel field
  saves, after D2's settle step.
- **Web reserves some shortcuts.** Browsers keep Cmd/Ctrl+N (and W, T) for
  themselves; the page never sees them. New stays reachable by its button
  (D14).

### D7 — The toolbar and the top bar (decision 4)

- The top bar (`chrome-top`, 44 px) gains, at its left: the toolbar (seven
  icon buttons, a gap between the file group and Undo/Redo), then the
  document name with its dirty mark (`Flexible`, ellipsis: a long file name
  must not overflow the 44 px row, T-13), then today's status line (now
  `Flexible` with an ellipsis, so the bar does not overflow in a narrow
  window or `flutter test`'s 800 px surface, S-27), Spacer, OSNAP and zoom
  as now.
- Buttons are `IconButton`s with tooltips, keys `toolbar-<id>`, disabled
  per D6. They never take focus from the canvas (`ExcludeFocus`, as the tool
  palette does), and the toolbar sits inside a `TextFieldTapRegion` so a
  press does not end an open text entry first (D2, T-1).

### D8 — Opening a file

- **Pick:** `DocumentFiles.open()` returns `(name, bytes, location)` or null
  (cancelled: nothing happens).
- **Register** (S-1): `registerAppComponents(ComponentRegistry r)` in
  `catalog.dart` registers `PageComponent` and then the parametric catalog,
  once. It is passed as `registerComponents:` to the decode, and New uses it
  too (D4). Every existing test decode already registers both by hand
  (`startup_plan_test.dart:735-738`). Without `PageComponent` the page
  loads as preserve-unknown: no sheet, no zoom text, no page panel, rooms
  and dimensions on the fallback page. Without the catalog the parametric
  components load as preserve-unknown: the generated children still draw,
  but nothing is a live object (no grips, no regeneration).
- **Decode:** `utf8.decode(bytes)`, then
  `DraftDocumentCodec.decodeString(text, measurer: m, registerComponents:
  registerAppComponents, diagnostics: list)` with the fresh measurer of D2.
- **Failure** (S-12): **any thrown object** while reading or decoding is
  caught (`catch (e)`, not `on Exception`: a malformed document throws
  `TypeError`s and null-check errors from the loaders,
  `json_codec.dart:160-170, 224-266`; only `SchemaVersionError` and
  `FormatException` are exceptions). The host shows an error dialog naming
  the file and `e.toString()`, clears the fresh measurer, and changes
  nothing else (D2).
- **Success:** the host swaps to the decoded document, named after the file
  (its base name without `.jetplan`), with the returned location, clean.
  The shell installs its parametric system over it as it does today;
  nothing regenerates on load (06 D10). Decode diagnostics (tree repairs,
  fill rebuilds) are not shown in 12a (the diagnostics slice).
- **The DASHED linetype record** (spec 10 D3 left this to 12's file-open
  path): Open does **not** add it. Adding it would change the document
  outside history and break byte identity. Every document the app makes has
  it (D4); a foreign file without it draws its separators continuous
  (spec 10's fallback). Ruled here (R-3) and pinned by a test (below).
- **Byte identity.** A file written by this app, opened and saved without
  an edit, is byte-identical to the file (the codec is deterministic). A
  file written by an older codec version is re-encoded in today's form.
- **What a decode validates, and what not** (T-9): the page's own fields
  are range-checked on load — `PageComponent.fromJson` goes through the
  constructor, which refuses non-positive or non-finite sizes and scale and
  non-finite origins (`page_component.dart:109-116, 202-216`) — so such a
  file fails the Open cleanly (a fixture below). Unchecked: a positive but
  absurd scale or size, and the parametric types' parameters; a failure
  after the swap has no way back (D14).

### D9 — `DocumentFiles` (decision 2)

```dart
abstract interface class DocumentFiles {
  /// null when the person cancelled.
  Future<({String name, Uint8List bytes, Object? location})?> open();
  /// Where to save; null when cancelled. [suggestedName] ends in .jetplan.
  Future<({String name, Object location})?> saveLocation(String suggestedName);
  /// Writes [bytes] to [location]; throws on failure.
  Future<void> write(Object location, String name, Uint8List bytes);
  /// Whether [write] to the location an [open] or [saveLocation] returned
  /// overwrites that file (macOS) or downloads a copy (web).
  bool get writesInPlace;
}
```

The plan may reshape the signatures; the contract is: open returns bytes
and an optional location; a location is opaque to the host; cancel is null,
failure is a throw.

- **macOS** (`document_files_io.dart`): `file_selector`'s `openFile` and
  `getSaveLocation` with `XTypeGroup(label: 'Jet plan', extensions:
  ['jetplan'])`. The save panel enforces and appends the extension itself
  (`allowedContentTypes`), and the sandbox grants exactly the URL it
  returns, so **the returned path is written unchanged** (S-16);
  `write` is `File(path).writeAsBytes(bytes, flush: true)` (`dart:io`,
  never imported on web). Location is the path.
- **web** (`document_files_web.dart`): `openFile` through `file_selector`
  (`file_selector_web` implements it); the location it returns is null.
  `saveLocation` asks for a name through a prompt the host supplies at
  construction (`Future<String?> Function(String suggested)`, an app
  dialog; the interface carries no `BuildContext`, T-12; an empty name is a
  cancel; the browser has no save dialog; `file_selector_web`'s `getSaveLocation` returns a dummy
  `FileSaveLocation('')`), appends `.jetplan` when the typed name lacks it,
  and returns the name as the location. `write` downloads (S-15): a
  `package:web` `Blob` of the bytes (`application/json`),
  `URL.createObjectURL`, an anchor with `download = name`, `click()`, then
  `URL.revokeObjectURL`. **No `cross_file` dependency and no
  `XFile.saveTo`**: `cross_file` 0.4.0 removed both `XFile.fromData` and
  `saveTo`, and 0.3.x's `saveTo` leaks the object URL. `writesInPlace` is
  false.
- **Save** with a known location and `writesInPlace` writes there. An
  untitled document's Save is Save As. On web, a titled document's Save
  downloads under the current name without asking.
- **Dependencies:** `file_selector: ^1.1.0` and `web` (already a
  transitive dependency through `file_selector_web`; declared because the
  web implementation imports it). Both first-party.
- **Tests** inject a `FakeDocumentFiles`: scripted opens, cancels and
  throws; writes recorded; a write that can be **held pending** by the test
  (a `Completer`), for D5 and D6. No test touches a real dialog.

### D10 — Replacing a dirty document (decision 7)

New, Open and Open sample, when the document is dirty (after D2's settle
step), first show an app dialog: **Save**, **Don't Save**, **Cancel**
(default Save; Escape is Cancel).

- **Save:** runs the Save step (D9; Save As if untitled) inside this flow's
  busy span (D6). If the save is cancelled or fails, the replacement does
  not happen and the document stays dirty. If it succeeds but an edit
  landed while the write was pending (D5: the document is dirty again), the
  dialog is shown again rather than replacing unsaved work (T-8).
- **Don't Save:** the replacement proceeds.
- **Cancel:** nothing happens.
- A clean document is replaced without a dialog.
- For Open, the dialog comes **before** the file picker (as macOS apps do).

### D11 — Closing the app (decision 7)

- **macOS.** The host registers an `AppLifecycleListener(onExitRequested:
  …)` and disposes it with itself. **In this order** (T-7): busy (a flow
  in progress, a dialog or a panel up, a write in flight) →
  `AppExitResponse.cancel` (S-17); else settle (D2); then clean →
  `AppExitResponse.exit`; else the D10 dialog: Save then exit if the save
  succeeds and the document is still clean (else the dialog again, as
  D10), cancel if it is cancelled or fails; Don't Save exits; Cancel
  returns cancel. Settling before the clean check means a typed but
  unsubmitted panel value makes the document dirty and asks, rather than
  being lost.
  - **Cmd+Q and the app menu's Quit** reach it with no native code
    (verified in Flutter 3.47's sources, S-14):
    `FlutterAppDelegate.applicationShouldTerminate` sends
    `System.requestAppExit` and answers `NSTerminateCancel`
    (`FlutterAppDelegate.mm:77-93`); the framework's
    `handleRequestAppExit` asks the `didRequestAppExit` observers
    (`widgets/binding.dart:895-918`), which is `onExitRequested`.
  - **The window's close button** does not by itself: with
    `applicationShouldTerminateAfterLastWindowClosed` true
    (`AppDelegate.swift`), AppKit closes the window first and terminates
    after, so a cancel would leave a running app with no window.
    `MainFlutterWindow` (the nib window, whose own delegate methods AppKit
    consults) implements `@objc func windowShouldClose(_ sender: NSWindow)
    -> Bool` (the class does not adopt `NSWindowDelegate`, so the method is
    exposed to Objective-C only when marked `@objc`, T-13) to return false
    and call
    `NSApp.terminate(nil)`, routing the close through the same exit
    request; an allowed exit terminates, a cancelled one leaves the window
    open. The one native edit; verified on the human's Mac.
  - **An engine quirk** (S-14): `requestApplicationTermination` sets its
    "should terminate" flag before asking Dart and resets it only on a
    cancel reply (`FlutterEngine.mm:237, 269-270`). While the Save / Don't
    Save dialog is up, a **second** Cmd+Q or close-button click terminates
    at once, without saving. Recorded (D14) and in the human's look; the
    plan may mitigate it (e.g. the window ignores close while a request is
    in flight, through a method channel) if cheap, not required.
- **Web.** While dirty, the host installs a `beforeunload` listener that
  calls `preventDefault()` (and sets `returnValue`), and removes it when
  clean or disposed. The browser shows its own generic warning.
  Implemented behind a conditional import; the Dart side is an
  `ExitGuard` with `set armed(bool)`, which tests observe through a fake.

### D12 — Platform edits

- `macos/Runner/Release.entitlements` and `DebugProfile.entitlements`: add
  `com.apple.security.files.user-selected.read-write` (true). Without it the
  sandboxed app's open and save panels fail.
- `macos/Runner/MainFlutterWindow.swift`: `windowShouldClose` as D11.
- No web platform file changes.

### D13 — Draw order, undo, save and load

- Nothing here writes entities. Draw order, undo and redo of edits are
  unchanged.
- Opening clears history (the codec's `notifyLoaded`); New and Open sample
  start with an empty history.
- Save writes `utf8.encode(DraftDocumentCodec.encodeToString(document))`,
  and nothing else: no pretty-printing, no re-ordering.

### D14 — Known limits

- **Web:** a cancelled or failed download leaves the document clean
  (decision 9); Cmd/Ctrl+N is the browser's (D6); the tab-close warning is
  the browser's generic one; a file-picker cancel relies on the browser's
  input `cancel` event (`file_selector_web`'s `dom_helper.dart:59-65`) —
  current Chrome and Firefox deliver it; where one does not, `open()`
  never completes and the commands stay disabled until reload.
- **macOS:** a second Cmd+Q or close click while the exit dialog is up
  quits without saving (D11); `writeAsBytes` truncates in place, so a
  failure mid-write leaves a damaged file ("a failed save changes nothing"
  holds for the document, not the file).
- **Clean is not byte-equal:** the handle seed is outside history (D3); an
  edit then undo is clean and a save writes a later seed.
- A table edit or purge outside the dispatcher does not mark the document
  dirty (D3); 12a makes none after a document is built.
- Tool settings reset on every New/Open (D2).
- The page panel's unsubmitted scale text is not saved (D2).
- Opening a foreign file without the DASHED record draws its separators
  continuous (D8).
- Decode diagnostics are not shown (D8); a positive but absurd page scale or
  size, and parametric parameters, are not validated on load (D8).
- Mid-shape, every command waits for Escape or the end of the shape (D6).
- The chords in a guarded text field do nothing at all (D6, T-5).
- A saved state evicted from the 200-step history cannot become clean by
  undoing (decision 5); correct, not a limit, and pinned.

## Architecture

### Files

| File | Change |
|---|---|
| `packages/jet_cad_2d/lib/src/document/undo.dart` | D3 |
| `packages/jet_cad_2d/test/document/undo_state_test.dart` (new) | D3 |
| `apps/floor_planner/lib/main.dart` | the host at the root; the shell's seam (D1); Undo/Redo commands; snap settings passed in and not disposed; the shell's measurer removed; the top bar (D7) |
| `apps/floor_planner/lib/{document_host,document_files,document_files_io,document_files_web,shell_commands,document_toolbar,new_document,exit_guard*}.dart` (new) | D2, D4–D11 |
| `apps/floor_planner/lib/parametric/catalog.dart` | `registerAppComponents` (D8) |
| `apps/floor_planner/lib/shortcut_guard.dart` | the three redo activators (D6) |
| `apps/floor_planner/lib/startup_plan.dart` | the shared set-up helper; comment (D4) |
| `apps/floor_planner/pubspec.yaml` | `file_selector`, `web` |
| `apps/floor_planner/macos/Runner/*.entitlements`, `MainFlutterWindow.swift` | D12 |
| `apps/floor_planner/test/planner_shell_test.dart` | migrates (S-10): it pumps `const FloorPlannerApp()` twelve times and asserts the flat (`liveCount >= 500`, extents off the origin); those cases pump `PlannerShell(document: startupPlan(m))` or the app followed by Open sample (with a fake `DocumentFiles`), and one new case asserts the empty launch |
| `apps/floor_planner/test/` (new files) | the tests below; the ten files that pump a bare `PlannerShell` and press meta+Z keep working unchanged (D1) |

### Invariants

- One command definition per command; the toolbar and the shortcuts cannot
  disagree.
- The UI never relies on the dispatcher refusing: a disabled command makes
  no call.
- A failed open or save changes nothing in the document or the host but the
  dialog.
- The bytes written are exactly `utf8.encode(encodeToString(document))`.
- The save point is the id the bytes were encoded at.
- Frame path untouched: nothing here runs per frame; the dirty listener
  runs per document change.

## Testing

Widget tests pump the host with a `FakeDocumentFiles`. **No test starts
from a clean document at depth 0 when it asserts that something did not
change** (S-13): those start **dirty, with `undoDepth > 0`**, from an edit
through a real tool at an off-origin placement, **with the tool's shape
ended** (Escape, Select idle) before any chord is pressed — a pending tool
swallows the key and would make a "no call" test pass for the wrong reason
(T-6). A fixture that exercises Redo has a redo stack: two edits, one undo
(dirty, `undoDepth > 0`, `canRedo`). The documents are the sample flat
(walls, openings, rooms, dimensions; every object in a root-level group at
the identity, `startup_plan.dart:305-371`) and New documents edited
through real tools, one of which is **rotated** through the Select tool's
rotation grip (T-10). Flows are triggered with the repository's `press()`
(`sendKeyEvent` then `pump()`); D2's settle is synchronous, so no extra
pump is needed (T-4). Tests of the toolbar's pointer path run with
`debugDefaultTargetPlatformOverride = TargetPlatform.macOS` and
`PointerDeviceKind.mouse` — `flutter test`'s default touch on Android is
the one combination where a tap outside a field does not unfocus it
(T-1).

### Tests by area

- **Engine (D3):** the state-id rules listed there, each its own case,
  including eviction at `undoLimit: 3` and a failed undo then a successful
  one (and redo).
- **Launch and New (D4):** the launch document is empty, untitled, clean,
  Undo disabled, units millimetres, handle 6 holds the DASHED record, the
  page is live (`PageNotifier.value` is the fixed default, the zoom text
  reads `1:50 · …`, the page panel shows), and the page `==` the literal
  `PageComponent(originX: -7425, originY: -5250)` (T-11); New after an edit
  (dirty → Don't Save) replaces it with the same.
- **Round trips (exit criterion):**
  - sample → Save As (the fake records bytes) → Open those bytes → Save:
    the second bytes `==` the first, **and the first bytes `==`
    `utf8.encode(DraftDocumentCodec.encodeToString(sample))` computed
    independently in the test** (S-9); the opened document's
    walls/openings/rooms/dimensions `==` the saved ones';
  - **from New** (S-3, T-10): a wall and a room drawn through the tools far
    from the origin, the wall's group then **rotated** through the Select
    tool's rotation grip → Save As → Open → Save: bytes `==`, and the
    opened wall's group transform `==` the saved one's;
  - **without DASHED** (S-20): a file encoded from an `empty` document with
    a wall and no linetype record → Open → Save: bytes `==` the file.
- **The page after Open** (S-1): after Open of the sample's bytes, the page
  is live (`PageNotifier.value == startupPage(...)`, the zoom text, the
  page panel).
- **The catalog after Open (D8):** walls open as live objects
  (`liveObjectsOf<WallParams>` non-empty, a wall's grips present).
- **Open failures (D8, S-12, S-13):** from a dirty document with history →
  Open → Don't Save → the picker returns: bytes that are not UTF-8; not
  JSON; `[]`; `{"schemaVersion": 1}` (a missing section); the sample's
  bytes with the page's `scaleDenominator` set to 0 (T-9); a schema version
  the codec refuses; or a cancel. Each: the same document object in the
  host, the same undo depth, still dirty; the four failures show the
  dialog; after it, Cmd+O opens a picker again (busy was cleared).
- **Dirty (D5):** edit → dirty; undo → clean; redo → dirty; save → clean;
  edit, undo, other edit → dirty, and one more undo → still dirty; the
  dirty mark and the tab title follow. The same run **after an Open**
  (the subscription is the new document's, S-23).
- **The save point is the encoded state** (S-2): a titled, dirty document;
  the fake's `write` held pending; a wall drawn through the tool
  off-origin; the write completes → the document is **dirty**, and the
  written bytes are the pre-edit encoding. The same with
  `writesInPlace: false` (web).
- **Failed and cancelled saves** (S-13, S-21): from dirty with history,
  a failing `write` → still dirty, error dialog; then Cmd+S writes (busy
  was cleared); a cancelled Save As → still dirty.
- **Undo/Redo buttons (D6, D7):** disabled on a fresh document; enabled
  after an edit (Undo) and after an undo (Redo); a tap undoes one step;
  the shortcuts, including Ctrl+Y, do the same.
- **Mid-shape** (T-2): a Wall chain with one wall down → every toolbar
  button is disabled and a tap on Undo leaves `undoDepth`; after Escape
  they are enabled and a tap undoes.
- **Above the dialogs** (T-3): with the D10 dialog up, Cmd+S is handled
  (the key event result) and makes no write.
- **Disabled means no call** (S-8, T-6): a titled document after two
  edits and one undo (dirty, `undoDepth > 0`, `canRedo`), the tool's shape
  ended, a `write` held pending (busy): Cmd+Z, Cmd+Shift+Z and taps on Undo
  and Redo leave `undoDepth`, `canRedo` and `stateId` unchanged; a second
  Cmd+S makes no second write.
- **Nested flows** (T-8): dirty → New → Save with the write held → Cmd+O,
  Cmd+S and the buttons do nothing; the write completes → the document is
  replaced. With an edit made while the write was held → the dialog is
  shown again.
- **Text fields** (S-7, T-6): with a redo stack, a Selection panel field
  focused, each of Meta+Shift+Z, Ctrl+Shift+Z and Ctrl+Y → `undoDepth` and
  `canRedo` unchanged.
- **Pending input** (S-4, S-5, S-19): a wall drawn off-origin **and
  selected**, its thickness typed without Enter, Cmd+S → the saved bytes
  carry the typed thickness, history has the commit as its own step, and
  the document is **clean** after the save. A text entry with typed text,
  Cmd+S → the saved bytes contain the text entity, clean after. **The same
  through the toolbar** (T-1): macOS, mouse, a text entry with typed text,
  a tap on `toolbar-save` → the bytes contain the text entity, clean after.
  An unsubmitted page scale, Cmd+S → the field shows the stored scale
  after (T-13).
- **Replace flows (D10):** dirty + New → dialog; Cancel keeps everything;
  Don't Save replaces; Save + a cancelled save dialog keeps everything,
  dirty; Save + success writes then replaces. Clean + New → no dialog.
  Open: the dialog before the picker.
- **Exit (D11, S-18):** driven through
  `tester.binding.handleRequestAppExit()` (so registration and disposal
  are exercised): clean → exit with no dialog; **save, then exit → exit, no
  dialog** (roadmap M-12d); dirty → dialog: Cancel → cancel; Don't Save →
  exit; Save + success → exit; Save + failure → cancel; busy → cancel with
  no second dialog; **clean but a Selection panel value typed and not
  submitted → the dialog appears** (T-7).
- **Web specifics (D9, D11):** with `writesInPlace: false`, Save on a
  titled document writes without asking and marks clean; the fake
  `ExitGuard` is armed exactly while dirty, across a swap.
- **Swap hygiene (D2, S-11):** after Open, on the **old** document:
  `commands.isDisposed`, `commands.expander == null`,
  `commands.onAfterMutate == null`, `commands.onBeforeMutate == null`,
  `tables.debugListenerCount == 0`; on the new shell: selection empty,
  Select active, the snap setting what it was, and **F3 pressed twice
  toggles it** (the notifier was not disposed).

### Named mutants

- **M-12a-1:** save writes a re-ordered map (keys sorted) — the round
  trip's "first bytes `==` the codec's" assertion goes red (roadmap
  M-12b).
- **M-12a-2:** the save point is not moved on a successful save — the dirty
  test after save and "save, then exit → no dialog" go red (roadmap M-12d).
- **M-12a-3:** the save point is moved on a failed or cancelled save — the
  failed-save test (from dirty) goes red.
- **M-12a-4:** dirty as "any change since save" (never cleaned by undo) —
  edit/undo goes red.
- **M-12a-5:** the state id restored from the top entry's identity instead
  of the recorded id — redo after undo goes red (engine).
- **M-12a-6:** eviction keeps the evicted state reachable (the id recomputed
  from depth) — the eviction test goes red (engine).
- **M-12a-7:** decode registers only the catalog — the page-after-Open test
  goes red.
- **M-12a-7b:** decode registers only `PageComponent` — the catalog test
  goes red.
- **M-12a-8:** the host swaps before decoding succeeds — the open-failure
  tests go red.
- **M-12a-9:** a disabled Undo's shortcut calls the dispatcher — the busy
  "no call" test goes red (roadmap M-12a's principle: the UI must not rely
  on the dispatcher).
- **M-12a-10:** the replace flow skips the dialog when dirty — the replace
  test goes red.
- **M-12a-11:** a flow does not settle pending input (or settles without
  applying the pending focus change) — the pending-input test goes red
  (bytes, or clean after).
- **M-12a-12:** busy is not set during a flow — the second-Cmd+S test goes
  red.
- **M-12a-13:** the save point is read after the write's await — the
  encoded-state test goes red (S-2).
- **M-12a-14:** a failed undo restores the entry stamped with the current
  id — the failed-undo-then-undo engine test goes red (S-6).
- **M-12a-15:** the guard lacks a redo chord — the text-field test goes red
  (S-7).
- **M-12a-16:** Open catches `on Exception` only — the `[]` and
  `{"schemaVersion": 1}` failure tests go red (S-12).
- **M-12a-17:** busy is not reset on failure — the "then Cmd+S writes"
  test goes red (S-21).
- **M-12a-18:** Open calls `ensureDashedLinetype` — the no-DASHED round
  trip goes red (S-20).
- **M-12a-19:** the host keeps the first document's change subscription —
  the dirty-after-Open test goes red (S-23).
- **M-12a-20:** the shell still disposes the snap settings — the F3 test
  after a swap goes red (S-11).
- **M-12a-21:** the old document is not disposed after a swap — the swap
  hygiene test goes red (S-11).
- **M-12a-22:** the toolbar is outside the `TextFieldTapRegion` — the
  toolbar text-entry test (macOS, mouse) goes red (T-1).
- **M-12a-23:** `enabled` ignores mid-shape — the mid-shape test goes red
  (T-2).
- **M-12a-24:** the file chords are not bound above the Navigator — the
  dialog-up Cmd+S test goes red (T-3).
- **M-12a-25:** the exit flow checks clean before settling — the
  unsubmitted-value exit test goes red (T-7).
- **M-12a-26:** a nested Save clears busy — the nested-flow test goes red
  (T-8).
- **M-12a-27:** the default page's origin from the portrait size — the
  literal page test goes red (T-11).

## Exit gate

- Engine, render layer, app: the standing gates green (CLAUDE.md), with
  `CI=true`; app `flutter build web --release` builds.
- Every named mutant fired and red, recorded in the results note.
- **The human's look on macOS:** New, Open, Save, Save As with the native
  panels in the sandboxed release build; Cmd+Q and the close button on a
  dirty document ask, and Cancel keeps the window; a saved `.jetplan` opens
  back identically; (the known quirk: a second Cmd+Q during the dialog
  quits). **On web (Chrome, Firefox):** Open picks a file; Save downloads
  `name.jetplan`; Cmd/Ctrl+S never opens the browser's Save Page, even
  during a pending save or with the name prompt up; closing a dirty tab
  warns; a click on Save while typing a text entry saves the text.

## Spec rulings

- **R-1 (D2):** keyed rebuild of the shell per document, over teaching the
  shell to swap: the shell's many `late final` fields over the document are
  correct as written, and a swap path would have to reset every one.
- **R-2 (D3):** a state id in the engine, over a save point in the app: the
  app cannot see eviction or redo-branch loss without it.
- **R-3 (D8):** Open does not add the DASHED record (byte identity).
- **R-4 (D11):** the macOS close button routes through the exit request.
- **R-5 (D2, S-4):** a flow commits an open text entry (the tool's
  `finish`), over cancelling it: the person typed it and asked to save.
- **R-6 (D9, S-15):** web downloads through `package:web` directly, over
  `cross_file`'s `saveTo` (removed upstream in 0.4.0; leaks in 0.3.x).
- **R-7 (D6):** while busy, Undo and Redo are disabled too.
- **R-8 (D6, T-2):** mid-shape, every command is disabled, buttons and
  keys alike, over letting the buttons act: 05 D3's "undo never lands
  mid-shape" and the one-table invariant both hold. Cost if wrong: a person
  mid-chain presses Escape before Save.
- **R-9 (D2, T-1):** Undo and Redo settle pending input like the file
  commands, over being disabled while a field has focus: a typed value is
  then its own step, and Undo removes it first.

## Revision 2

Applies the independent review of revision 1
(`.superpowers/sdd/spec-12a-review.md`, archived with the plan's ledger):

| Finding | Where |
|---|---|
| S-1 (blocking) `PageComponent` not registered on Open | D8 register, D4, tests "page after Open", M-12a-7/7b |
| S-2 (blocking) save point at completion | D5, test "encoded state", M-12a-13 |
| S-3 New's page NaN, units | D4, test "from New" |
| S-4 text entry cancelled on focus loss; page scale | D2 pending input, R-5, D14 |
| S-5 hand-back commit a microtask later | D2 settle step, M-12a-11 |
| S-6 failure paths | D3 transitions, engine test, M-12a-14 |
| S-7 text-field claim | D6 text fields, test, M-12a-15 |
| S-8 M-12a-9 equivalent | D6 disabled binding, busy test |
| S-9 M-12a-1 green | round-trip assertion |
| S-10 existing tests, shell seam | D1 seam, Files (`planner_shell_test`) |
| S-11 stale subscription, snap disposal | D2 dispose old document, snap, hygiene test, M-12a-20/21 |
| S-12 non-`Exception` throws | D8 failure, fixtures, M-12a-16 |
| S-13 degenerate fixtures | Testing preamble, failure tests |
| S-14 open question 1; the quirk | D11, D14, exit gate |
| S-15 open question 2; `cross_file` | D9 web, R-6 |
| S-16 macOS path unchanged | D9 macOS |
| S-17 exit while busy | D11, exit test |
| S-18 exit tests through the binding | exit test, M-12a-2 |
| S-19 pending-text fixture | pending-input test |
| S-20 DASHED ruling untested; citation | D8, test, M-12a-18; spec 10 D3 |
| S-21 busy in `finally` | D6, test, M-12a-17, D14 web picker |
| S-22 clean is not byte-equal | D3, D14 |
| S-23 per-document subscription | D5, test, M-12a-19 |
| S-24 measurer ownership | D2 |
| S-25 references | D1, D2, D6 |
| S-26 both modifiers; consume disabled keys | D6 |
| S-27 known limits; overflow | D14, D7, D5 |
| S-28 ids per dispatcher | D2, D3 |

## Revision 3

Applies the independent re-review of revision 2
(`.superpowers/sdd/spec-12a-review-2.md`, archived with the plan's ledger;
its S-1 to S-28 table marks S-4, S-7, S-8, S-13, S-26 and S-27 "partly",
completed by the findings below):

| Finding | Where |
|---|---|
| T-1 (major) a toolbar click cancels the text entry | D2 toolbar paragraph, D7, R-9, Testing preamble, test, M-12a-22 |
| T-2 (major) the buttons act mid-shape | D6 idle and mid-shape, D1 render getter, R-8, D14, test, M-12a-23 |
| T-3 disabled keys under a dialog | D6 bound above the dialogs, test, M-12a-24, exit gate |
| T-4 the delayed settle never fires under `pump()` | D2 synchronous settle, Testing preamble, M-12a-11 |
| T-5 guarded fields do nothing | D6 text fields, D14 |
| T-6 three "no call" tests | Testing preamble, busy and text-field tests |
| T-7 exit order | D11 order, test, M-12a-25 |
| T-8 nested flows | D6 outermost busy, D10, D11, test, M-12a-26 |
| T-9 page validation facts | D4, D8, D14, fixture |
| T-10 no rotated fixture | Testing preamble, round trip from New |
| T-11 the page as a literal | D4, launch test, M-12a-27 |
| T-12 the web name prompt | D9 web |
| T-13 `@objc`; dirty on save; tab title; long names; page scale re-sync | D11, D5, D7, D2, test |
