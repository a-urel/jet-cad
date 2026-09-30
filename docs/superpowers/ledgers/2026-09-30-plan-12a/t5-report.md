# Task 5 report: app, the session, the host, the swap, Open and Save (plan 12a, spec D2, D5, D8, D13)

**Commit:** `efb8700` `feat(app): the document session, Open and Save` on
`plan-12a/document-lifecycle` (parent `0b3bf76`). Not pushed. 8 files, +1616 −39:
- `lib/document_host.dart` (new)
- `lib/main.dart`, `lib/startup_plan.dart` (comment only)
- `test/planner_shell_test.dart` (migrated)
- `test/document_host_test.dart`, `test/document_open_test.dart`, `test/document_save_test.dart`, `test/support/document_rig.dart` (new)

`packages/jet_cad/analysis_options.yaml` is modified by `flutter pub get`. It is left unstaged and was not committed.

## The API as landed

**`lib/document_host.dart`**
- `kUntitledName = 'Untitled'`.
- `documentTitle(name, {required bool dirty})` returns `'• '` (when dirty) + `'$name — jet-cad'`.
- `documentNameOf(fileName)` strips a trailing `.jetplan` and keeps any other extension.

**`DocumentSession extends ChangeNotifier`** (P-3)
- Constructors: `DocumentSession(doc, FlutterTextMeasurer m)` and `DocumentSession.untitled()`, which builds `newDocument`.
- Getters: `document`, `measurer`, `fileName` (null while untitled), `name` (`Untitled`, or the file name without `.jetplan`), `location`, `savedState`.
- Notifiers: `ValueNotifier<bool> dirty` and `ValueNotifier<bool> busy`.
- It subscribes to `document.commands.changes`. Each change recomputes `dirty = stateId != savedState`.
- `replace(doc, m, {fileName, location})`:
  - cancels the old subscription and subscribes to the new document (S-23);
  - resets the save point to the new document's `stateId`, and resets the name and location (S-28);
  - calls `notifyListeners` once;
  - schedules a post-frame callback that runs `oldDocument.dispose()` and `oldMeasurer.clear()`. That callback runs after the old shell's `dispose` (S-11, S-24).
- `markSaved(int id, {fileName, location})` sets the save point and recomputes `dirty` at once (T-13). When given a file name, it also retitles and notifies.
- `dispose` cancels the subscription, disposes both notifiers, disposes the current document and clears its measurer.

**`DocumentHost`** (StatefulWidget) with public state `DocumentHostState`
- It owns `SnapSettings snap`, which survives a swap.
- It builds, under a `ListenableBuilder` over the session:
  `PlannerShell(key: ObjectKey(document), document, snap, documentName, dirty, busy, onSettle)`.
- `_flow` wraps every flow. It sets busy for the outermost flow only (T-8) and clears it in a `finally` (S-21). A flow called inside another runs without touching busy.
- The flows:
  - `newFlow()` and `openSampleFlow()`: settle, then build over a fresh measurer, then `replace`. Both are unconditional; the D10 dialog belongs to Task 8.
  - `openFlow()`:
    1. Settle, then `files.open()`. A throw from the picker also shows the error dialog.
    2. On null (cancel), nothing happens.
    3. Otherwise `utf8.decode`, then `decodeString(measurer: fresh, registerComponents: registerAppComponents, diagnostics: [])`.
    4. `catch (e)` catches any object: `measurer.clear()`, then an awaited error dialog titled `Could not open <file>`, with body `e.toString()`.
    5. On success, `replace` with the file's name and location. No DASHED record is added (R-3).
  - `Future<bool> saveStep()`:
    1. Settle.
    2. `_encode()`: `stateId` and `utf8.encode(encodeToString(doc))` are read in one synchronous block (S-2, D13).
    3. Then it picks where to write:

       | Document | Files object | What happens |
       |---|---|---|
       | Titled | `!writesInPlace` (web) | Writes to `location ?? fileName` under the file name, without asking |
       | Titled | `writesInPlace`, location known | Writes in place |
       | Otherwise | — | Save As |
  - `Future<bool> saveAsStep()`:
    1. Settle and encode.
    2. `saveLocation('<name>.jetplan')`. On null it returns false; a throw shows the dialog and returns false.
    3. Write.
  - The shared write path:
    - **Success:** `markSaved(capturedId, fileName, location)`, guarded by the document still being the encoded one.
    - **Failure:** the awaited error dialog `Could not save <file>`, returns false, and the save point is untouched.
- `showDocumentNamePrompt(context, suggested)` is the web name prompt (T-12). It is an `AlertDialog` whose `TextField` is seeded with the suggestion. Save and Enter return the text; Cancel returns null.
- Dialog keys:
  - error dialog: `document-error`, `-title`, `-text`, `-ok`;
  - name prompt: `name-prompt`, `-field`, `-save`, `-cancel`.

**`lib/main.dart`**
- **`FloorPlannerApp({key, DocumentFiles? files})` is now stateful:**
  - It owns the session and the files: the injected ones, or `createDocumentFiles(askName: …)`.
  - The name prompt is shown through a `navigatorKey`'s context.
  - It rebuilds `MaterialApp(onGenerateTitle: documentTitle(...))` from `ListenableBuilder(Listenable.merge([session, session.dirty]))` (U-4), with `home: DocumentHost`.
  - **Task 4 review n-2:** `main.dart` imports `document_files.dart` and calls `createDocumentFiles`. The web build therefore compiles `document_files_web.dart`, and it built.
- **`typedef ShellSettleRegistrar = VoidCallback Function(VoidCallback settle)`:**
  - The shell registers `_settlePendingInput` in `initState` and calls the returned release in `dispose`.
  - The release withdraws only its own callback, because a keyed swap runs the new shell's `initState` before the old shell's `dispose`.
  - `_settlePendingInput()` is an empty no-op until Task 7.
- **`PlannerShell` gains optional parameters:**
  - Signature: `PlannerShell({key, document, snap, documentName, dirty, busy, onSettle, initialCamera})`.
  - A bare shell builds `newDocument(FlutterTextMeasurer())`. That is the fix for Task 3 review m1: the fallback is no longer `startupPlan`. The shell clears its own measurer only in that case.
  - A passed document's measurer is the caller's; the shell no longer creates or clears one.
  - `snap` is taken from outside and not disposed when passed (`_ownsSnap`).
  - `documentName`, `dirty` and `busy` are accepted and stored but not shown yet. The top bar that shows them belongs to Task 6 (D7).
- `startup_plan.dart:26-29`: the "fixture a human looks at every session" line now reads "the drawing Open sample shows a human and the fixture many tests build".

## Tests (app 526 → 545: +19 new, none removed)

**`planner_shell_test.dart` (migrated, +1).** The 12 flat cases now call `pumpSample`, which pumps `MaterialApp(home: PlannerShell(document: startupPlan(m)))`. The new case "a bare shell opens on the empty document and its default page" pins that a bare shell has 0 entities, no undo, the literal page, millimetres and zoom text `1:50 · `.

**`document_host_test.dart`**

| Test | Pins |
|---|---|
| DH1 | The launch document: the session's document is the shell's; 0 entities; no undo or redo; millimetres; DASHED at handle 6; `Untitled` with no file name or location; clean and not busy; title `Untitled — jet-cad`; `PageNotifier.value == PageComponent(originX: -7425, originY: -5250)`; zoom `1:50 · …`; page panel and `page-scale` shown; no file calls. |
| DH2 | New after an edit (dirty) replaces the document with a fresh one: a new object, a new shell, empty, no undo, the literal page, untitled and clean, title reset. Open sample gives the flat (bytes equal to an independently built `startupPlan`), ≥ 500 entities, untitled, clean, not busy, no writes. |
| DH3 | Dirty on the launch document (helper `dirtyRun`):<br>• an edit through the Wall tool far off the origin (shape ended) → dirty and title `• …`<br>• Cmd+Z → clean<br>• redo → dirty<br>• Save (untitled, so Save As) → clean, title `run — jet-cad`<br>• undo past the save → dirty<br>• another edit cuts the branch → dirty<br>• undo → still dirty; redo → still dirty |
| DH4 | The same run after an Open of the flat, titled `flat` at `/plans/flat`. The launch document is edited first, and the save writes in place at `/plans/flat`. |
| DH5 | **Swap hygiene.** After New → Open sample, the launch document is disposed. The old sample shell is set up with F3 off, a wall selected and the Wall tool active, and the premises are checked: `expander` and `onAfterMutate` set, table listeners > 0.<br>After Open, on the old document: `isDisposed`, `expander`, `onAfterMutate` and `onBeforeMutate` null, `tables.debugListenerCount == 0`.<br>The new shell has an empty selection and Select active; `osnap off` survived, and `host.snap` is false. F3 twice gives `OSNAP` then `osnap off`. |

**`document_open_test.dart`**

| Test | Pins |
|---|---|
| DO1 | Sample → Save As → Open → Save (S-9):<br>• the suggested name is `Untitled.jetplan`<br>• the first bytes `== utf8.encode(encodeToString(freshly built sample))`<br>• location and name are `/plans/flat` and `flat.jetplan`; the document is named `flat`<br>• the opened document's walls, openings, rooms and dimensions (handle → params) `==` the saved ones; clean<br>• Save does not ask again; the second bytes `==` the first, at the same location |
| DO2 | From New, at (41000, 27000) (T-10):<br>• four walls closing a rectangle, a room placed with the Room tool, and a free wall<br>• the free wall is selected by a click, then turned through its rotation grip by a mouse drag (premise: non-identity, \|angle\| > 0.05)<br>• Save (Save As) writes `bytesOf(doc)`, then Open<br>• the opened group's transform entries `==` the saved ones; objects `==`; one room<br>• Save writes the same bytes |
| DO3 | A no-DASHED file: an empty document plus `registerAppComponents` plus one wall in a rotated, translated group, with a premise that it has no DASHED record. After Open the wall is live and there is still no DASHED; Save writes bytes `==` the file (S-20). |
| DO4 | The page after Open (S-1): `PageNotifier.value ==` the independently built sample's page, which is not the launch page (premise). Zoom `1:50 · `; `page-scale` shown. |
| DO5 | The catalog after Open: `liveObjectsOf<WallParams>` `==` the built sample's and is non-empty; the selected wall has 2 object grips. |
| DO6 | Failures from dirty with history (one Wall tool edit, depth 1). Six fixtures:<br>• bytes that are not UTF-8<br>• cut JSON<br>• `[]`<br>• `{"schemaVersion": 1}`<br>• the sample with its page's `scaleDenominator` = 0 (premise: exactly one field zeroed)<br>• the sample with `schemaVersion` = `kSchemaVersion + 1`<br>For each: the picker is called and the dialog shows the title `Could not open <name>` and the text `==` the `toString()` of the error that decode throws in the test. Busy is true under the dialog. After OK, the session and shell document are the same object, not disposed, same depth, still dirty, `Untitled`, no location, not busy.<br>Then a picker throw shows `Bad state: …` with the document unchanged. Then a cancel shows no dialog and changes nothing. `openCalls == 8`, `unscriptedCalls == 0`. |

**`document_save_test.dart`**

| Test | Pins |
|---|---|
| DS1 ×2 | The encoded state (S-2), with `writesInPlace` true and false. Setup: titled (the flat opened), dirty from one Wall edit, write held.<br>• the write is recorded with the pre-edit bytes, at location `/p/flat` (true) or `flat.jetplan` (false); no ask; busy<br>• a second wall is drawn while the write is held (depth 2)<br>• on completion: true, not busy, **dirty**, title `• flat — jet-cad`<br>• one undo → clean |
| DS2 | A failed write from dirty:<br>• the dialog appears: `Could not save flat.jetplan` / `Exception: the disk is full`<br>• busy under the dialog<br>• after OK: false, still dirty, busy cleared, depth 1<br>• then a save writes `bytesOf(doc)` and is clean and not busy |
| DS3 | A cancelled Save As on an untitled document: `Untitled.jetplan` asked; no write, no dialog; dirty, `Untitled`, not busy. Then titled as `a`, an edit, and a cancelled `saveAsStep`: dirty, name and location kept. |
| DS4 | Untitled Save asks, writes `bytesOf(doc)` at `/p/house`, and the session becomes `house` / `house.jetplan` / `/p/house`, clean, title `house — jet-cad`. The next Save does not ask. Save As asks with `house.jetplan`, moves to `/p/barn`, title `barn — jet-cad`. |
| DS5 | Web titled Save: the location is null (premise). No prompt and no dialog; the write goes to location `flat.jetplan` with name `flat.jetplan` and the document's bytes; clean. This covers the Task 4 review's n-1. |
| DS6 | The name prompt is seeded with `Untitled.jetplan`; Save returns the typed text, Cancel returns null, and Enter returns the text and closes. |

## Mutants

Procedure: `cp` backup to `…/scratchpad/p12t5-<tag>-<file>`, mutate, run the named test with `--plain-name`, `cp` back, `diff`. All 25 restore diffs exited 0. The runner is `…/scratchpad/p12t5-mutants.py` and the log is `p12t5-mutants-final.log`. Every mutant was re-fired on the committed tree `efb8700`; all went red. Line numbers are in the named test file. A second line in DH3/DH4 is the `dirtyRun(...)` call site.

| Mutant | Mutation | Red test | Line |
|---|---|---|---|
| M-12a-1 | Save encodes a key-sorted map | DO1 | 124 (first bytes == codec's) |
| M-12a-2 (save half) | `markSaved(_session.savedState, …)` | DH3 | 64 (save → clean) |
| M-12a-3 failure | `markSaved(encoded.stateId)` in the write's `catch` | DS2 | 106 |
| M-12a-3 cancel | `markSaved(encoded.stateId)` when `saveLocation` returns null | DS3 | 137 |
| M-12a-4 | Any change sets `dirty = true` | DH3 | 48 (undo → clean) |
| M-12a-7 | Decode registers `parametricCatalog.registerComponents` only | DO4 | 275 |
| M-12a-7b | Decode registers `PageComponent.register` only | DO5 | 294 |
| M-12a-8 | Open swaps to `newDocument` before decoding | DO6 | 357 (same document object) |
| M-12a-13 | Save point read after the write's await (`_session.document.commands.stateId`) | DS1 (both) | 74 |
| M-12a-16 | `on Exception catch` in decode | DO6 | 340. The `list.jetplan` `_TypeError` escapes and no dialog appears |
| M-12a-17 | Busy cleared only when the flow's result is not `false` (the `finally` removed) | DS2 | 107 (busy cleared) |
| M-12a-18 | `ensureDashedLinetype(document)` after decode | DO3 | 253 |
| M-12a-19 | `replace` keeps the first subscription (no cancel, no re-listen) | DH4 | 44 (edit → dirty after Open) |
| M-12a-20 | The shell disposes the snap unconditionally | DH5 | 207/208. See the note below |
| M-12a-21 | Old document not disposed after the swap | DH5 | 203 |
| X1 | Web titled Save falls through to Save As | DS5 | 206 |
| X2 | `documentNameOf` keeps `.jetplan` | DS4 | 175 |
| X3 | A retitle does not notify | DS4 | 193 (title) |
| X4 | Picker throw not caught | DO6 | 369/373 (a `StateError` escapes) |
| X5 | Bare shell falls back to `startupPlan` (Task 3 m1) | planner_shell_test | 99 |
| X6 | `replace` keeps the old save point | DH2 | 153 |
| X7 | `markSaved` does not recompute `dirty` | DH3 | 64 |
| X8 | Error dialog not awaited | DO6 | 352 (busy under the dialog) |
| X9 | Prompt Cancel returns the text | DS6 | 249 |
| X10 | Prompt not seeded | DS6 | 236 |

**Note on M-12a-20.** The mutant goes red at the first swap (launch → Open sample), not at the Open. The launch shell's dispose disposes the host's `SnapSettings`, so the first F3 in the sample shell (line 207) raises a used-after-dispose assertion in the key handler. The mechanism is the one the spec names, and the swap that exposes it is simply the earlier one in the same test.

**Not mutant-tested here:** the settle registration (release-only-own). The settle is a no-op until Task 7, so nothing observable depends on it; Task 7's tests will.

## Gates (final tree `efb8700`, CI=true, PATH=/root/flutter/bin)

| Package | Command | Summary | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed`. Both failures are standing: `generate_document_test` "both text fractions…" and "the default document is the one Plan 2 measured…" | 1 (standing only, unchanged) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format …` | 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed`. All seven are standing: text ladder rungs 1–5 and text lod ladder rungs 1–2 | 1 (standing only, unchanged) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format …` | 178 files (0 changed) | 0 |
| app | `flutter test` | `+545: All tests passed!` (526 + 19) | 0 |
| app | `flutter analyze` | No issues found! | 0 |
| app | `dart format …` | 117 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web` | 0 |

`git status` after the gates shows only ` M packages/jet_cad/analysis_options.yaml`.

## Deviations and precisions (for the reviewer)

1. **`fileCommands` and the `ShellCommand` type are not added in Task 5.** P-4 lists `fileCommands` on the shell, but `ShellCommand` is Task 6's new file (`shell_commands.dart`) and nothing would consume it yet. Task 6 adds the parameter together with its type and the toolbar. `documentName`, `dirty` and `busy` are on the shell now, but the top bar does not show them until Task 6.
2. **`ShellSettleRegistrar` returns a release function** (`VoidCallback Function(VoidCallback settle)`). P-4 only says "hands the host a void Function()". The release is needed because a keyed swap runs the new shell's `initState` before the old shell's `dispose`, and a plain `onSettle(null)` on dispose would erase the new registration.
3. **The session keeps `fileName` (with extension) and `name` separately.** The name shown and the name in the title drop `.jetplan`. Save As suggests `<name>.jetplan`, and web Save writes under `fileName`, with `location ?? fileName` as the location (Task 4 review n-1).
4. **A bare shell owns a measurer.** P-4 says the shell stops owning one. It does, for a passed document. A bare `PlannerShell()` still builds `newDocument` over a measurer it creates and clears on dispose, the only way a bare shell can have one.
5. **Flows await their error dialog**, so busy covers the dialog, which D11 relies on later. **A picker throw** from `open()` or `saveLocation()` is also caught and shown. The spec says "reading or decoding", and this is the reading side.
6. **`markSaved` is skipped if the document changed during the write.** Ids are per dispatcher (S-28). This cannot happen once commands are disabled while busy, which is Task 6's job.
7. **The session disposes the current document and clears its measurer on app dispose** (teardown hygiene). The spec does not mention this.
8. **Spec D4/D8's "`PageNotifier.value == startupPage(...)`"** is asserted as equality with the independently built sample's page (DO4). `startupPage(built.extents)` on the finished flat is **not** equal: the sample computes its page from the extents at an earlier point in its build, before the rooms and dimensions. So the spec's wording is loose, and Task 9 could amend it.
9. **The title string on non-web platforms changes** from `Floor planner` to `<name> — jet-cad`. `onGenerateTitle` is the spec's mechanism, and it only shows on the web tab.

## Found outside scope (reported, not fixed)

- **Spec D4/D8 wording on `startupPage(...)`:** see deviation 8.
- **Stale comment at `main.dart` `_undo`:** it says "There is no redo in 02". Task 6 replaces that binding.
