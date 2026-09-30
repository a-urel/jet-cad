# Review — spec 12a, the document lifecycle (revision 1)

**Spec:** `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md` at `e5a26d2`
(branch `spec-12a/document-lifecycle`, cut from `cac7765`).
**Reviewer:** independent, read-only. Nothing committed, nothing edited.
**Scope:** whether the spec implements the human's nine decisions correctly and
completely. The decisions themselves are not reviewed.

## Verdict: **Not ready (revision 1). Ready once amended.**

There are **2 blocking** findings. S-1: an opened file loses its page. S-2: the
save point can mark as clean a state that was never written. There are also
**11 major** findings. Every finding has a local fix inside the nine
decisions; none reopens a decision or needs a new brainstorm. Both open
questions are answered (S-14, S-15).

---

## Blocking

### S-1 (blocking): Open does not register `PageComponent`, so an opened document has no page

**Evidence**
- D8 decodes with `registerComponents: parametricCatalog.registerComponents`.
  That registers only the six parametric types (`apps/floor_planner/lib/parametric/catalog.dart:19-31`).
- `PageComponent` is not a built-in. `DraftDocument.empty` calls only
  `registerBuiltIns()` (`draft_document.dart:107`), which registers `OriginComponent` alone
  (`component.dart:87-93`). The sample registers the page by hand (`startup_plan.dart:193`).
- Every existing decode in the app's tests registers both. See
  `startup_plan_test.dart:735-738` (SP6) and `dimension_panel_test.dart:502-506`:
  `PageComponent.register(r); parametricCatalog.registerComponents(r);`.
- The result as specified: the page loads as preserve-unknown and
  `get<PageComponent>(root)` is null (`page_notifier.dart:12`). The consequences:
  - there is no sheet;
  - the zoom text is empty (`main.dart:346-348`);
  - the page panel hides;
  - rooms and dimensions read the fallback page (spec 10 D11);
  - the camera fits the extents, not the page.
- **None of the spec's tests catches it.** The byte round trip still passes,
  because preserve-unknown writes the page back untouched. The catalog test
  only looks at walls.

**Fix**
- Add one app function in `catalog.dart`, e.g. `registerAppComponents(ComponentRegistry r)`,
  that registers `PageComponent` and then the catalog. Use it for decode.
- New (D4) should use the same function. Note that `PageComponent.register`
  is "once per registry" (`page_component.dart:78-81`): a second call wipes a
  live page.
- Test: after Open of the sample's bytes, the page is live. Check
  `PageNotifier.value == startupPage(...)`, the zoom text reads `1:50 · …`,
  and the page panel shows.
- New mutant: **decode registers only the catalog → the page test goes red.**
- D8's sentence "Without the catalog … every object vanishes" also overclaims.
  The generated children stay drawn; what goes is that they are no longer
  live objects (no grips, no regeneration). Reword it.

### S-2 (blocking): D5 sets the save point to the id at *completion*; the canvas stays editable during the await

**Evidence**
- D5 says "A successful save sets `savedState` to the current id". D6's busy
  flag disables only the command table.
- The canvas, tools, grips and panels stay live while `saveLocation` / `write`
  await. This applies to macOS file I/O, to the web name dialog once it
  closes, and to the fake in tests.
- Failure sequence:
  1. The bytes are encoded at state A.
  2. The person drags a wall (state B) before `write` resolves.
  3. `savedState = B`.
  4. The document shows clean while the file holds A.
- The same hazard applies to the exit flow (D11) and to Save inside the
  replace flow (D10).

**Fix**
- Capture `final id = document.commands.stateId` in the same synchronous
  block as `encodeToString`. On success set `savedState = id`, not the id at
  that moment.
- Test: a titled, dirty document; the fake's `write` is held pending; an edit
  lands through a real tool (off-origin); the write completes; the document
  is **dirty**. On web, the same with `writesInPlace: false`.
- Mutant: **the save point is read after the await → that test goes red.**
  (M-12a-2 and M-12a-3 do not cover this.)

---

## Major

### S-3 (major): D4's "default page the startup plan attaches today" is NaN on an empty document, and the units are missing

**Evidence**
- The sample attaches `startupPage(doc.extents)` (`startup_plan.dart:195-196`, `:244-251`).
  That page is centred on the extents.
- An empty document's extents are `Aabb2.empty()`, i.e. `(+inf, +inf, −inf, −inf)`
  (`aabb2.dart:30-35`). So `center` is `(inf + −inf) / 2 = NaN` (`aabb2.dart:50`).
- A NaN origin breaks the fit. Save then throws: I ran `jsonEncode({'originX': NaN})`
  in the container, and it throws `JsonUnsupportedObjectError: Converting object
  to an encodable object failed: NaN`.
- The sample also sets `doc.header.units = DrawingUnits.millimeters` outside
  history (`startup_plan.dart:194`). The header default is `unitless`
  (`header.dart:9`). D4 does not mention the units.
- No listed test saves a *New* document. The round trip starts from the
  sample, so this would reach the human's look.

**Fix**
- D4 states the New page explicitly: `PageComponent()` defaults except for an
  origin the spec names (e.g. `(0, 0)`, or a fixed off-origin value), plus
  `header.units = millimeters`.
- D4 also states that the page goes in outside history, or through `execute`
  followed by `clearHistory()`, before `savedState` is taken. Otherwise Undo
  is enabled on a fresh document.
- Factor the shared set-up (DASHED, page registration, units) into one helper
  that `startupPlan` and `newDocument` both call.
- Add a round trip that starts from New: an edit through a real tool, far
  from the origin → Save As → Open → Save, with the bytes `==`.

### S-4 (major): D2 says the text-tool entry "is committed the same way it is on focus loss today". Today it is **cancelled**

**Evidence**
- `text_entry_overlay.dart:22-24`: "Enter commits. Any other loss of focus cancels".
- `:72-78`: `_onFocus` → `cancelText`.
- So Cmd+S while a text entry is open would hand focus back and discard the
  typed text.
- The page panel's scale field **also does not commit on focus loss**, by
  design. See `page_panel.dart:58-85`: "Nothing is committed". Only the
  Selection panel's fields commit on focus loss (`selection_panel.dart:440-446`).
- D2's premise "a panel field … commits on focus loss today
  (`panel_focus.dart`)" therefore holds for one panel only. Also,
  `panel_focus.dart` only hands focus back; it does not commit.

**Fix**
- D2 names each pending-input case and its rule:
  - **Selection panel fields:** hand back and let the commit land (S-5).
  - **Text entry:** the flow calls `TextTool.commitText(controller.text, ctx)`
    explicitly before handing back. Or the spec rules that it is cancelled, and
    records that in D14.
  - **Page scale:** unsubmitted text is not saved (the field's existing rule),
    and D14 records that.
- Test: text entry with typed text + Cmd+S → the saved bytes contain the text
  entity. Mutant: the flow only hands focus back → red.

### S-5 (major): the hand-back commit lands a microtask later; the flow must await it

**Evidence**
- `FocusManager` applies focus changes in `scheduleMicrotask(applyFocusChangesIfNeeded)`
  (`/root/flutter/packages/flutter/lib/src/widgets/focus_manager.dart:1943-1947`).
- The Selection panel's commit runs in a focus listener (`selection_panel.dart:188`, `:440-446`).
- So a flow that calls `handBack()` and then reads `stateId` or encodes in the
  same synchronous block misses the commit. The commit then lands after the
  save point, and the document looks dirty after "Save".

**Fix**
- D2 says: hand back, then `await` a microtask turn (or `await null`) before
  capturing the id and encoding.
- The pending-text test (see also S-19) asserts **clean after the save**, as
  well as the bytes. That catches the "handed back but not awaited" variant
  of M-12a-11.

### S-6 (major): D3's failure paths must restore the popped entry *with its recorded id*; the listed test cannot see a wrong restore

**Evidence**
- A failed undo pops the entry and pushes the same command back through
  `pushUndoOnly(inverse)` (`undo.dart:136`, `:151`). A failed redo does the
  same through `pushRedo(inverse)` (`:167`, `:175`).
- Suppose entries become `(command, returnsTo)` records and the restore goes
  through a primitive that stamps the *current* id. The id is then
  "unchanged" right after the failure, which is the only thing D3's test
  checks. But the next successful undo moves the id to the pre-undo value.
- The document is then at A while the id says B. Save at B, edit, fail an
  undo, undo: the document reads clean with different content.
- `takeUndo`/`pushRedo`/`takeRedo`/`pushUndoOnly` are public API on an
  exported class (`jet_cad_2d.dart:38`). That makes this split easy to get wrong.

**Fix**
- D3 states that the restore puts back the original record. Better still,
  give `UndoStack` whole transitions: `recordExecute`, then `undo`/`redo`
  done as take → apply → commit or abort, so that no primitive stamps an id.
- Engine tests:
  - edit (A→B) → `permissions = readOnly` → undo throws → id is B →
    `permissions = all` → undo → id **== A**;
  - the same for redo.
- Mutant: **the restore stamps the current id → red.**

### S-7 (major): D6's text-field claim is wrong; the new redo chords would redo the *document* from a panel field

**Evidence**
- The spec says Cmd+Z and Cmd+Shift+Z in a field "stay the field's own undo
  and redo (the field handles them before they bubble)".
- Flutter's text editing shortcuts sit in `WidgetsApp`, above the Navigator
  and so above the shell. See `DefaultTextEditingShortcuts` at
  `/root/flutter/packages/flutter/lib/src/widgets/app.dart:1823`; the
  undo/redo intents are at `default_text_editing_shortcuts.dart:321-325`, `:728-731`.
- The shell's `CallbackShortcuts` therefore sees a field's keys first. That is
  exactly why `ShellShortcutGuard` exists (`shortcut_guard.dart:25-35`).
- The guard lists only Cmd+Z and Ctrl+Z (`:49-52`). It does not list
  Cmd+Shift+Z, Ctrl+Shift+Z or Ctrl+Y, because `SingleActivator` matches
  modifiers exactly.
- As specified, those chords typed in a Selection panel field, the page scale
  or the text entry (`text_entry_overlay.dart:100`) would redo the document.

**Fix**
- Add the three redo activators to the guard. Correct D6's wording: the guard
  stops them, not the field.
- Test: focus a panel field, press Cmd+Shift+Z → `undoDepth` and `canRedo`
  are unchanged.
- Mutant: the guard lacks a redo chord → red.

### S-8 (major): M-12a-9 is an equivalent mutant as described

**Evidence**
- `CommandDispatcher.undo()` with empty history calls `onBeforeMutate`, then
  returns (`undo.dart:133-135`). It emits no change and changes no state.
- "Disabled on a fresh document" means `canUndo == false`. So a shortcut that
  ignores `enabled` and calls `undo()` is unobservable. The test cannot go red.
- The only state where `enabled` differs from `canUndo` in 12a is the busy
  flag (D6).

**Fix**
- Pin M-12a-9 in the busy state: a titled, dirty document with
  `undoDepth > 0` and the fake's `write` held pending. Press Cmd+Z →
  `undoDepth` and `stateId` are unchanged. Do the same for Redo, and for a tap
  on the toolbar button.

### S-9 (major): M-12a-1 (re-ordered keys) does not make the round trip go red

**Evidence**
- A deterministic re-order (e.g. keys sorted) is applied to both saves in
  "sample → Save As → Open → Save". The second bytes then equal the first,
  and the test stays green.
- The roadmap's M-12b is about *non-deterministic* order. The spec's
  invariant "the bytes written are exactly `encodeToString`'s, UTF-8" has no
  test.

**Fix**
- The round-trip test also asserts that the first write's bytes
  `== utf8.encode(DraftDocumentCodec.encodeToString(sample))`, computed
  independently in the test.
- Keep a second mutant for true non-determinism if wanted.

### S-10 (major): existing tests the spec breaks, and the shell's parameters D1 leaves out

**Evidence**
- `planner_shell_test.dart` pumps `const FloorPlannerApp()` 12 times. It
  asserts the flat, e.g. `liveCount >= 500` and `extents.minX > 0` (lines
  ~80-90), and clicks a wall. D4's empty launch turns all of those red.
- Ten test files pump a bare `PlannerShell(document: doc)` and press meta+Z,
  e.g. `wall_tool_test.dart:69`, `:102-106` and `planner_draw_test.dart:40`
  (16 uses of `keyZ`). If Undo moves into a host-owned table, they lose undo.
- The toolbar and the document name live in the shell's top bar
  (`main.dart:415-443`). The shell's `CallbackShortcuts` are "built from the
  table". So `PlannerShell` must receive the table, the name and the dirty
  listenable. D1's `main.dart` row names only the snap settings and the
  measurer.

**Fix**
- D1/D6 fix the seam: Undo/Redo are per-document commands the shell can
  build for itself. When pumped bare, the shell binds them (enabled =
  `canUndo`/`canRedo`). The host passes the file commands, the busy flag,
  the name and the dirty mark in.
- `planner_shell_test` migrates, either to `PlannerShell(document: startupPlan(m))`
  or to "pump the app, then Open sample". The spec's file table lists it.

### S-11 (major): D2's "nothing stale can survive" is not quite true; the host should dispose the old document, and must not share-dispose the snap settings

**Evidence**
- `DimensionGrips` keeps a per-drag memo subscription on `d.changes`
  (`dimension_grips.dart:147-159`). Only `_dropMemo` cancels it (`:163-172`),
  and that runs on the next document change or on a drop.
- `ObjectGrips` has no `dispose` (`object_grips.dart`), and
  `GripCache.dispose` does not reach it (`grip_cache.dart:405-409`).
- So after a dimension-grip preview without a drop (drag cancelled), the
  subscription outlives the shell. It holds the old document (`_memoDoc`)
  and the old index for as long as the old dispatcher lives.
- The host never disposes the old `DraftDocument` (`draft_document.dart:212`
  closes the broadcast controller).
- Separately: D2 moves `SnapSettings` to the host, but the shell disposes it
  today (`main.dart:381`). Left as is, the first swap disposes the host's
  notifier. The spec's test only reads `objectSnap`, which still works after
  `dispose`, so it cannot catch this.

**Fix**
- After the old shell is gone (post-frame), the host calls
  `oldDocument.dispose()`. That ends every subscription on it and makes any
  stale use throw loudly (`undo.dart:227-231`).
- The shell stops disposing `_snap`.
- The swap-hygiene test adds these checks on the old document:
  - `commands.isDisposed`;
  - `commands.expander == null`;
  - `onAfterMutate == null`;
  - `onBeforeMutate == null`;
  - `tables.debugListenerCount == 0` (`tables.dart:581`).
- Then, on the new shell: press F3 twice and check that it toggles.
- Checked, no leak found:
  - the parametric system releases its expander slot (`parametric_system.dart:549-554`);
  - the index releases both hooks (`spatial_index.dart:3052-3074`);
  - every other `changes.listen` in the app is cancelled in a `dispose`;
  - the only module-level mutable state is weak `Expando`s keyed per view
    (`room_inputs.dart:126`, `:158`; `opening_geometry.dart:669`) and the
    stateless `parametricCatalog`.

### S-12 (major): D8's "any exception" must be *any thrown object*; malformed documents throw `Error`s

**Evidence**
- `decodeString` does `jsonDecode(source) as Map`, so a top-level `[]` gives a
  `TypeError`.
- The loaders use `json! as List` / `(json! as Map)`
  (`json_codec.dart:160-170`, `:224-266`), so a missing section gives a
  null-check or cast `Error`.
- Only `SchemaVersionError` and `FormatException` are `Exception`s
  (`schema_version.dart:24`).
- An implementation written `on Exception catch` lets a malformed file crash
  the flow. The busy flag then stays set (S-21).

**Fix**
- D8 says `catch (e)` (all objects), with the dialog showing
  `e.toString()`.
- Add failure fixtures `[]` and `{"schemaVersion": 1}`.
- Mutant: `on Exception` → red on those.

### S-13 (major): degenerate fixtures in the failure and save-point tests

**Evidence**
- The tests "each leaves … the same undo depth" (open failures) and M-12a-3
  ("save point moved on a failed/cancelled save") pass trivially when the
  document is clean at depth 0. The sample is exactly that
  (`startup_plan.dart:239`).
- For a clean document, moving the save point to the current id is a no-op,
  so M-12a-3 is equivalent there.

**Fix**
- Each of these tests starts from a document that is **dirty with
  `undoDepth > 0`**, from an edit through a real tool, off-origin.
- Open failure: dirty → **Don't Save** → the picker returns bad bytes → the
  same document object, the same depth, **still dirty**.
- Failed/cancelled save: still dirty.

---

## Minor

### S-14 (minor, open question 1): Cmd+Q needs no native code; the close button needs D11's edit; one engine quirk to record

**Evidence: Cmd+Q**
- `AppDelegate: FlutterAppDelegate` (`macos/Runner/AppDelegate.swift:5`).
- `FlutterEngine` installs a termination handler on a `FlutterAppLifecycleProvider`
  delegate (`/root/flutter/engine/src/flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine.mm:577-586`).
- `applicationShouldTerminate` sends `System.requestAppExit` and returns
  `NSTerminateCancel` (`FlutterAppDelegate.mm:77-93`).
- Requests are accepted after the framework sends `System.initializationComplete`.
  `ServicesBinding.initInstances` does that (`services/binding.dart:66`,
  `:587-589`; engine side `FlutterEngine.mm:1602-1604`).
- The reply goes through `WidgetsBinding.handleRequestAppExit` →
  `didRequestAppExit` observers (`widgets/binding.dart:895-918`), which is
  `AppLifecycleListener.onExitRequested`.
- **So D11's assumption holds for Cmd+Q and the app menu's Quit.**

**Evidence: the close button**
- The close button does not go through this path; D11's `windowShouldClose`
  edit is right.
- The nib window is `MainFlutterWindow`. Only windows created by
  `FlutterWindowController` get an engine delegate
  (`FlutterWindowController.mm:105`, `:309`), so a `windowShouldClose(_:)` on
  the window subclass is consulted.

**The quirk**
- `requestApplicationTermination` sets `_shouldTerminate = YES` *before*
  asking Dart (`FlutterEngine.mm:237`). It resets it only on a `cancel` reply
  (`:269-270`).
- While the Save / Don't Save dialog is up, a **second Cmd+Q**, or the close
  button (which D11 routes to `NSApp.terminate`), hits
  `shouldTerminate == YES` → `NSTerminateNow`. The app quits without saving.

**Fix**
- Record the quirk in D14 and in the human's macOS look.
- Optional mitigation (plan's call): `windowShouldClose` does not call
  `terminate` while a request is in flight. That needs a flag over a method
  channel.

### S-15 (minor, open question 2): `XFile.saveTo` downloads in the cross_file that file_selector resolves, but that API is gone upstream

**Evidence: 0.3.x**
- `file_selector` 1.1.0 → `file_selector_platform_interface` 2.7.0 →
  `cross_file: ^0.3.0`. That resolves 0.3.5+5.
- In 0.3.5+5, web `saveTo` calls `saveFileAs` (`lib/src/types/html.dart:185-187`),
  which clicks an `<a download=name>` on a blob object URL
  (`lib/src/web_helpers/web_helpers.dart:13-16`, `:50-63`). So it does
  download.
- The object URL is never revoked: one leaked blob per save.

**Evidence: re-export and 0.4.0**
- `XFile` **is** re-exported: `file_selector.dart:9-10`, `show FileSaveLocation, XFile, XTypeGroup`.
- The current `cross_file` is **0.4.0**. Its CHANGELOG says it "Removes
  `XFile.fromData`" and "Removes `XFile.saveTo()`".
- A direct `cross_file` dependency written against the latest would conflict
  with file_selector's `<0.4.0`. It would also bind 12a to an API that
  upstream has deleted.

**Fix**
- D9 drops the `cross_file` dependency.
- Web `write` is the spec's own fallback: `package:web` `Blob` → `URL.createObjectURL`
  → anchor `download = name` → `click()` → `URL.revokeObjectURL`, about ten lines.
- `web` is already a transitive dependency via `file_selector_web`
  (`pubspec.yaml`: `web: ">=0.5.1 <2.0.0"`). Declare it.
- Checked, and correct: `file_selector_web` 0.9.5's `getSaveLocation`
  returns `FileSaveLocation('')` (`file_selector_web.dart:64-70`), as D9 says.

### S-16 (minor): macOS Save As must not rewrite the panel's path

**Evidence**
- `file_selector_macos` sets `allowedContentTypes` from the `XTypeGroup`
  extensions (`FileSelectorPlugin.swift:107-127`). `NSSavePanel` then
  enforces and appends `.jetplan` itself.
- D9's "Save As appends `.jetplan` when the chosen name lacks it" would write
  to a URL the sandbox did not grant: `user-selected.read-write` covers the
  chosen URL.
- It would also skip the panel's "replace existing file?" confirmation.

**Fix**
- On macOS, write to the returned path unchanged.
- Append the extension only in the web name dialog.

### S-17 (minor): an exit request during a flow is unspecified

**Evidence**
- D11 does not say what happens when an exit request arrives while a flow is
  busy, e.g. D10's dialog is up or a native save panel is open. The host
  would open a second dialog over the first.

**Fix**
- While busy, `onExitRequested` returns `cancel`.
- Test it.

### S-18 (minor): the exit tests call the callback directly, so they cannot catch "listener not registered"

**Fix**
- Drive through `tester.binding.handleRequestAppExit()`
  (`widgets/binding.dart:895`). That exercises registration and disposal too.
- M-12d (roadmap) maps to "save, then exit → `exit`, no dialog". Add it to
  M-12a-2's red tests.

### S-19 (minor): the pending-text test must use a *selected wall*

**Evidence**
- With the Wall tool active, the thickness field edits the tool's settings,
  not the document (`selection_panel.dart:400-403`). The saved bytes would
  not change.

**Fix**
- Name the fixture: a wall drawn off-origin, selected, thickness typed
  without Enter, Cmd+S.

### S-20 (minor): the DASHED ruling (R-3) is untested, and its citation is off

**Evidence**
- The round trip starts from the sample, which already holds DASHED. A
  mutant "Open calls `ensureDashedLinetype`" is a no-op there.
- "Left to 12" is spec 10 **D3** (`2026-09-26-rooms-design.md:357-360`),
  not D17. D17 is the reserved handle (`:1533`).

**Fix**
- Fixture: a file without the record (encode an `empty` doc with a wall) →
  Open → Save → bytes `==`. Add that mutant.
- Correct the citation in the header, D4 and D8.

### S-21 (minor): the busy flag must clear on every exit path

**Evidence**
- No test fails a flow and then retries it. This covers a throw (S-12), a
  failed write and a cancel.
- On web, a cancel of the file picker relies on the input `cancel` event
  (`file_selector_web` `dom_helper.dart:59-65`). Where the browser does not
  deliver it, `open()` never completes and every command stays disabled.
  Current Chrome and Firefox do deliver it.

**Fix**
- Reset busy in a `finally`.
- Test: a failed save, then Cmd+S writes.
- Mutant: busy is not reset on failure.
- Record the web-picker limit in D14.

### S-22 (minor): D5 and D14 should say "clean" is not "byte-equal"

**Evidence**
- Tools reserve handles outside commands, e.g. `doc.handleSeed.next()` at
  `wall_tool.dart:221`, `room_tool.dart:200`, `opening_tool.dart:245`.
- Undo does not roll the seed back, and `handleSeed` is encoded
  (`json_codec.dart:81`).
- So edit → undo is clean per decision 5, but saving then writes a different
  `handleSeed`.

**Fix**
- One line in D14.
- No test asserts byte equality across an edit/undo.

### S-23 (minor): the host's `changes` subscription is per document

**Evidence**
- D5 does not say that the subscription is cancelled and re-made on a swap.
- A host that keeps the first document's subscription never shows dirty
  after an Open.

**Fix**
- State it in D5.
- The dirty test runs **after an Open**.
- Mutant: no re-subscription → red.

### S-24 (minor): measurer ownership

**Evidence**
- After D2 the shell never uses a measurer: the document carries it. The
  shell's own `_measurer` exists only for `startupPlan` (`main.dart:62-64`,
  `:388`).

**Fix**
- Do not pass the measurer to the shell; drop the shell's `_measurer`.
- The host clears the old measurer after the old shell's `dispose`
  (post-frame, the same order as today).
- The host also clears a measurer created for a decode that failed.
- Say that "cleared exactly once" has no mutant and why: no observable
  counter.

### S-25 (minor): factual references to correct

- The undo binding is `main.dart:398-399`; `396-412` is the whole bindings map.
- The commit on focus loss is `selection_panel.dart:440-446`, not `panel_focus.dart`.
- `DraftDocument.empty` takes a named `measurer:`.
- Verified correct:
  - `main.dart:366-390` (dispose);
  - `startup_plan.dart:57-59`;
  - D3's list of `clear()` callers (`undo.dart:188-204`, `json_codec.dart:148`,
    `draft_document.dart:209`);
  - nothing else pushes history: `UndoStack` is used only inside
    `CommandDispatcher`, and `ParametricSystem` only wraps through `expander`
    (`parametric_system.dart:546`).
  - D5/D6: after a document is built, the app makes no document change
    outside the dispatcher. No `tables.*.add/remove`, no `purge`, no direct
    component store writes in `apps/floor_planner/lib` or
    `jet_cad_2d_flutter/lib`. The page panel and the Selection panel go
    through `execute`. The only non-command writes are `handleSeed.next()`
    (S-22) and the sample's set-up.

### S-26 (minor): shortcut platform split and consuming disabled shortcuts on web

**Evidence**
- Today both meta and control Z are bound on every platform (`main.dart:398-399`).
  D6's table reads as if Ctrl is not bound on macOS.
- On web, Flutter calls `preventDefault()` only when the framework reports
  the key as handled (`web_ui/lib/src/engine/keyboard_binding.dart:596-599`).
  A disabled Save must therefore still *match and consume* Cmd/Ctrl+S.
  Otherwise the browser's Save Page opens during a busy flow.

**Fix**
- Bind both modifiers everywhere.
- Choose only the tooltip glyph by `defaultTargetPlatform`. Web on a Mac
  reports macOS.
- Keep the binding present, with a no-op when disabled.

### S-27 (minor): known limits D14 should add

- macOS `writeAsBytes` truncates in place. A failure mid-write leaves a
  damaged file ("a failed save changes nothing" holds for the document, not
  the file).
- A decodable but out-of-range page (e.g. scale 0) has no validation in
  `PageComponent.fromJson` (`page_component.dart` ~221). Any failure after
  the swap has no way back.
- The `Title` widget only affects the web tab. D5's "window title" wording
  should say web only.
- In `flutter test`'s default 800 px surface, the top bar (toolbar + name +
  status + OSNAP + zoom) may overflow. Give the status line
  `Flexible`/ellipsis.

### S-28 (minor): the state ids restart per dispatcher

**Evidence**
- A save point left over from the previous document can equal the new
  document's first id. Both start at the same counter.

**Fix**
- Reset `savedState` in the same `setState` as the swap. The spec implies
  this; say it.
- Or keep the save point as `(dispatcher, id)`.

---

## Scope

- No scope creep: Open sample, the web tab title and the exit guard are all
  inside decisions 3, 5 and 7.
- The roadmap exit criteria 12a owns are all specified, subject to S-1, S-2
  and S-9:
  - New / Open / Save / Save As, and a byte-identical round trip;
  - Undo and Redo buttons that reflect the stacks;
  - closing with unsaved changes prompts, and closing clean does not.
- The roadmap's M-12a (read-only UI) belongs to a later slice, correctly.
  12a's Undo `enabled` ignores `permissions`; under `readOnly` a shortcut
  would throw from the dispatcher. That is unreachable in 12a, and the
  permissions slice should note it.
