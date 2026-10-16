### Task 5: The exit, the title and the language

**Files:**
- Modify: `lib/document_host.dart` (exit listener, exit guard, untitled
  name)
- Create (port): `test/document_exit_test.dart`
- Create: `test/document_title_test.dart` (N3, N5)

**Interfaces:**
- Consumes: Task 4's host, session, rig.
- Produces: `DocumentHostState` arms the `ExitGuard` exactly while
  `controller.dirty`; answers the app's exit request
  (`AppLifecycleListener.onExitRequested`) as the old
  `_onExitRequested` does.

- [ ] **Step 1:** Port the old `_onExitRequested`, `_armExitGuard`, the
  `AppLifecycleListener` and the `didChangeDependencies` untitled-name
  update (`document_host.dart:424-440, 649-679`), with `dirty` read from
  the controller and `_settlePendingInput()` removed (the controller's
  `save()` and `dirty` read settle; if the exit must settle a typed value
  before reading `dirty`, call the controller's public settle, as Task 4
  found).

- [ ] **Step 2: Port `document_exit_test.dart`** (8 PORT rows).

- [ ] **Step 3: N3, the title:** the `MaterialApp`'s title (read
  `tester.widget<Title>(find.byType(Title)).title`) is `Untitled — jet-cad`;
  after `rig.editOnce()` `• Untitled — jet-cad`; after a Save As
  `flat.jetplan`, `flat — jet-cad`; after an edit and an undo back to the
  save point, `flat — jet-cad`. Mutation M-N3: the title reads a session
  flag set only in `saveStep` (the undo case stays dotted → red).

- [ ] **Step 4: N5, the language (Review Focus 4):** pump with locale en;
  switch the `MaterialApp`'s locale to tr (through
  `tester.platformDispatcher.localesTestValue` and a pump, or the rig's
  locale seam): the title becomes `Adsız — jet-cad` within that pump
  sequence (one frame plus the post-frame callback), and an editor word
  (any `PlanStrings` label on screen) is Turkish in the same pump. Then
  name the plan by a Save As and switch to de: the title keeps the file's
  name. Mutation M-N5: `setUntitledName` called in `initState` only
  (title stays `Untitled` → red).

- [ ] **Step 5:** Gates. **Commit** `feat(demo): the exit request, the exit guard and the untitled name`, then `test(demo): exit, title and language`.

---

